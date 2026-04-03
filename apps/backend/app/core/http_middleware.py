from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from hashlib import sha256
from threading import Lock
from time import monotonic, perf_counter
from typing import Callable, Protocol
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response
from redis import Redis
from structlog.contextvars import bind_contextvars, clear_contextvars

from app.core.config import Settings
from app.core.logging import logger
from app.core.metrics import get_metrics_registry


@dataclass(frozen=True)
class RateLimitDecision:
    allowed: bool
    limit: int
    remaining: int
    reset_after_seconds: int


class RateLimiter(Protocol):
    def consume(self, key: str) -> RateLimitDecision: ...


class InMemorySlidingWindowLimiter:
    """Thread-safe sliding window limiter for local/dev and single-process usage."""

    def __init__(
        self,
        *,
        max_requests: int,
        window_seconds: int,
        now_fn: Callable[[], float] = monotonic,
    ) -> None:
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.now_fn = now_fn
        self._buckets: dict[str, deque[float]] = {}
        self._lock = Lock()

    def consume(self, key: str) -> RateLimitDecision:
        now = self.now_fn()
        cutoff = now - self.window_seconds
        with self._lock:
            bucket = self._buckets.setdefault(key, deque())

            while bucket and bucket[0] <= cutoff:
                bucket.popleft()

            if len(bucket) >= self.max_requests:
                reset_after = max(1, int(self.window_seconds - (now - bucket[0])))
                return RateLimitDecision(
                    allowed=False,
                    limit=self.max_requests,
                    remaining=0,
                    reset_after_seconds=reset_after,
                )

            bucket.append(now)
            remaining = max(0, self.max_requests - len(bucket))
            reset_after = max(1, int(self.window_seconds - (now - bucket[0])))
            return RateLimitDecision(
                allowed=True,
                limit=self.max_requests,
                remaining=remaining,
                reset_after_seconds=reset_after,
            )


class RedisFixedWindowLimiter:
    """Redis-backed limiter suitable for multi-process deployments."""

    def __init__(
        self,
        *,
        redis_url: str,
        max_requests: int,
        window_seconds: int,
        prefix: str,
        client: Redis | None = None,
    ) -> None:
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.prefix = prefix
        self.client = client or Redis.from_url(redis_url, decode_responses=True)

    def consume(self, key: str) -> RateLimitDecision:
        bucket_key = f"{self.prefix}:{sha256(key.encode('utf-8')).hexdigest()}"
        with self.client.pipeline() as pipe:
            pipe.incr(bucket_key)
            pipe.ttl(bucket_key)
            current_count, ttl = pipe.execute()

        current_count = int(current_count)
        ttl = int(ttl)
        if current_count == 1 or ttl < 0:
            self.client.expire(bucket_key, self.window_seconds)
            ttl = self.window_seconds

        remaining = max(0, self.max_requests - min(current_count, self.max_requests))
        decision = RateLimitDecision(
            allowed=current_count <= self.max_requests,
            limit=self.max_requests,
            remaining=remaining,
            reset_after_seconds=max(1, ttl),
        )
        return decision


class FailSafeRateLimiter:
    def __init__(self, *, primary: RateLimiter, fallback: RateLimiter) -> None:
        self.primary = primary
        self.fallback = fallback

    def consume(self, key: str) -> RateLimitDecision:
        try:
            return self.primary.consume(key)
        except Exception as exc:
            logger.warning("http.rate_limit_backend_fallback", error=str(exc))
            return self.fallback.consume(key)


def install_http_middleware(app: FastAPI, settings: Settings) -> None:
    limiter = _build_rate_limiter(settings) if settings.rate_limit_enabled else None
    auth_path_prefix = f"{settings.api_v1_prefix}/auth/"
    metrics = get_metrics_registry()

    @app.middleware("http")
    async def request_context_and_rate_limit(request: Request, call_next) -> Response:
        clear_contextvars()
        request_id = request.headers.get("x-request-id") or uuid4().hex
        bind_contextvars(request_id=request_id)
        started = perf_counter()

        client_ip = _extract_client_ip(request)
        rate_headers: dict[str, str] = {}

        try:
            if limiter and request.method != "OPTIONS" and request.url.path.startswith(auth_path_prefix):
                decision = limiter.consume(f"{client_ip}:{request.url.path}")
                rate_headers = _build_rate_limit_headers(decision)
                if not decision.allowed:
                    response = JSONResponse(
                        status_code=429,
                        content={
                            "detail": "Too many auth requests. Please retry later.",
                        },
                    )
                    response.headers["Retry-After"] = str(decision.reset_after_seconds)
                    _apply_common_headers(
                        response=response,
                        request_id=request_id,
                        started=started,
                        rate_headers=rate_headers,
                    )
                    logger.warning(
                        "http.rate_limited",
                        method=request.method,
                        path=request.url.path,
                        client_ip=client_ip,
                        reset_after_seconds=decision.reset_after_seconds,
                    )
                    metrics.record_rate_limited(method=request.method, path=request.url.path)
                    metrics.record_http_request(
                        method=request.method,
                        path=request.url.path,
                        status_code=response.status_code,
                        duration_ms=float(response.headers.get("X-Response-Time-Ms", "0")),
                    )
                    return response

            response = await call_next(request)
            _apply_common_headers(
                response=response,
                request_id=request_id,
                started=started,
                rate_headers=rate_headers,
            )
            logger.info(
                "http.request_completed",
                method=request.method,
                path=request.url.path,
                status_code=response.status_code,
                client_ip=client_ip,
                response_time_ms=float(response.headers.get("X-Response-Time-Ms", "0")),
            )
            metrics.record_http_request(
                method=request.method,
                path=request.url.path,
                status_code=response.status_code,
                duration_ms=float(response.headers.get("X-Response-Time-Ms", "0")),
            )
            return response
        except Exception:
            elapsed_ms = round((perf_counter() - started) * 1000, 2)
            logger.exception(
                "http.request_failed",
                method=request.method,
                path=request.url.path,
                client_ip=client_ip,
                response_time_ms=elapsed_ms,
            )
            metrics.record_http_request(
                method=request.method,
                path=request.url.path,
                status_code=500,
                duration_ms=elapsed_ms,
            )
            raise
        finally:
            clear_contextvars()


def _build_rate_limiter(settings: Settings) -> RateLimiter:
    memory_limiter = InMemorySlidingWindowLimiter(
        max_requests=settings.rate_limit_auth_requests,
        window_seconds=settings.rate_limit_window_seconds,
    )
    prefix = settings.rate_limit_prefix
    if settings.environment == "test":
        prefix = f"{prefix}:{uuid4().hex}"
    backend = settings.rate_limit_backend.strip().lower()
    if backend == "memory":
        return memory_limiter

    redis_limiter = RedisFixedWindowLimiter(
        redis_url=settings.redis_url,
        max_requests=settings.rate_limit_auth_requests,
        window_seconds=settings.rate_limit_window_seconds,
        prefix=prefix,
    )
    if backend == "redis":
        return FailSafeRateLimiter(primary=redis_limiter, fallback=memory_limiter)
    return FailSafeRateLimiter(primary=redis_limiter, fallback=memory_limiter)


def _apply_common_headers(
    *,
    response: Response,
    request_id: str,
    started: float,
    rate_headers: dict[str, str],
) -> None:
    elapsed_ms = round((perf_counter() - started) * 1000, 2)
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Response-Time-Ms"] = str(elapsed_ms)
    for key, value in rate_headers.items():
        response.headers[key] = value


def _extract_client_ip(request: Request) -> str:
    forwarded_for = request.headers.get("x-forwarded-for", "")
    if forwarded_for:
        first_ip = forwarded_for.split(",")[0].strip()
        if first_ip:
            return first_ip
    if request.client and request.client.host:
        return request.client.host
    return "unknown"


def _build_rate_limit_headers(decision: RateLimitDecision) -> dict[str, str]:
    return {
        "X-RateLimit-Limit": str(decision.limit),
        "X-RateLimit-Remaining": str(decision.remaining),
        "X-RateLimit-Reset": str(decision.reset_after_seconds),
    }
