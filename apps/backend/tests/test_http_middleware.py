from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.http_middleware import RedisFixedWindowLimiter
from app.core.config import get_settings
from app.core.database import get_db
from app.main import create_app


def test_health_exposes_request_headers(client: TestClient):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.headers.get("X-Request-ID")
    assert response.headers.get("X-Response-Time-Ms")

    metrics_response = client.get("/metrics")
    assert metrics_response.status_code == 200
    assert "clindiary_http_requests_total" in metrics_response.text
    assert 'path="/health"' in metrics_response.text


def test_auth_rate_limit_returns_429(db_session: Session, monkeypatch):
    monkeypatch.setenv("RATE_LIMIT_ENABLED", "true")
    monkeypatch.setenv("RATE_LIMIT_AUTH_REQUESTS", "2")
    monkeypatch.setenv("RATE_LIMIT_WINDOW_SECONDS", "60")
    get_settings.cache_clear()

    app = create_app()

    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db

    try:
        with TestClient(app) as test_client:
            register_response = test_client.post(
                "/api/v1/auth/register",
                json={"email": "rate-limit@example.com", "password": "StrongPass123!"},
            )
            assert register_response.status_code == 201

            for _ in range(2):
                login_response = test_client.post(
                    "/api/v1/auth/login",
                    json={"email": "rate-limit@example.com", "password": "WrongPass999!"},
                )
                assert login_response.status_code != 429

            blocked_response = test_client.post(
                "/api/v1/auth/login",
                json={"email": "rate-limit@example.com", "password": "WrongPass999!"},
            )
            assert blocked_response.status_code == 429
            assert "retry" in blocked_response.json()["detail"].lower()
            assert blocked_response.headers["X-RateLimit-Limit"] == "2"
            assert blocked_response.headers["X-RateLimit-Remaining"] == "0"
            assert int(blocked_response.headers["Retry-After"]) >= 1
    finally:
        app.dependency_overrides.clear()
        get_settings.cache_clear()


class _FakeRedisPipeline:
    def __init__(self, store):
        self.store = store
        self.key = None

    def incr(self, key):
        self.key = key
        self.store[key] = self.store.get(key, 0) + 1

    def ttl(self, key):
        self.key = key

    def execute(self):
        return [self.store[self.key], 60]

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


class _FakeRedisClient:
    def __init__(self):
        self.store = {}

    def pipeline(self):
        return _FakeRedisPipeline(self.store)

    def expire(self, key, seconds):
        return True


def test_redis_fixed_window_limiter_counts_requests():
    limiter = RedisFixedWindowLimiter(
        redis_url="redis://unused",
        max_requests=2,
        window_seconds=60,
        prefix="test",
        client=_FakeRedisClient(),
    )

    first = limiter.consume("127.0.0.1:/api/v1/auth/login")
    second = limiter.consume("127.0.0.1:/api/v1/auth/login")
    third = limiter.consume("127.0.0.1:/api/v1/auth/login")

    assert first.allowed is True
    assert second.allowed is True
    assert third.allowed is False
    assert third.remaining == 0
