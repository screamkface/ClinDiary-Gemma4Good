from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass
from threading import Lock


@dataclass(slots=True)
class LatencyAggregate:
    count: int = 0
    total_ms: float = 0.0


class MetricsRegistry:
    def __init__(self) -> None:
        self._lock = Lock()
        self._http_requests = Counter()
        self._http_failures = Counter()
        self._http_rate_limits = Counter()
        self._http_latency = defaultdict(LatencyAggregate)
        self._ocr_runs = Counter()
        self._document_scans = Counter()
        self._ai_summary_runs = Counter()
        self._ai_summary_fallbacks = Counter()

    def record_http_request(
        self,
        *,
        method: str,
        path: str,
        status_code: int,
        duration_ms: float,
    ) -> None:
        key = (method.upper(), path, str(status_code))
        latency_key = (method.upper(), path)
        with self._lock:
            self._http_requests[key] += 1
            aggregate = self._http_latency[latency_key]
            aggregate.count += 1
            aggregate.total_ms += duration_ms
            if status_code >= 500:
                self._http_failures[latency_key] += 1

    def record_rate_limited(self, *, method: str, path: str) -> None:
        with self._lock:
            self._http_rate_limits[(method.upper(), path)] += 1

    def record_ocr(self, *, provider: str, outcome: str) -> None:
        with self._lock:
            self._ocr_runs[(provider or "unknown", outcome)] += 1

    def record_document_scan(self, *, provider: str, outcome: str) -> None:
        with self._lock:
            self._document_scans[(provider or "unknown", outcome)] += 1

    def record_ai_summary(
        self,
        *,
        provider: str,
        model_name: str,
        outcome: str,
        used_fallback: bool = False,
    ) -> None:
        with self._lock:
            self._ai_summary_runs[
                (provider or "unknown", model_name or "unknown", outcome, str(bool(used_fallback)).lower())
            ] += 1

    def record_ai_summary_fallback(
        self,
        *,
        from_provider: str,
        to_provider: str,
    ) -> None:
        with self._lock:
            self._ai_summary_fallbacks[(from_provider or "unknown", to_provider or "unknown")] += 1

    def reset(self) -> None:
        with self._lock:
            self._http_requests.clear()
            self._http_failures.clear()
            self._http_rate_limits.clear()
            self._http_latency.clear()
            self._ocr_runs.clear()
            self._document_scans.clear()
            self._ai_summary_runs.clear()
            self._ai_summary_fallbacks.clear()

    def render_prometheus(self) -> str:
        lines = [
            "# HELP clindiary_http_requests_total Total HTTP requests handled by ClinDiary.",
            "# TYPE clindiary_http_requests_total counter",
        ]
        with self._lock:
            for (method, path, status_code), value in sorted(self._http_requests.items()):
                lines.append(
                    'clindiary_http_requests_total{method="%s",path="%s",status_code="%s"} %s'
                    % (method, _escape(path), status_code, value)
                )

            lines.extend(
                [
                    "# HELP clindiary_http_failures_total Total HTTP requests that ended with 5xx.",
                    "# TYPE clindiary_http_failures_total counter",
                ]
            )
            for (method, path), value in sorted(self._http_failures.items()):
                lines.append(
                    'clindiary_http_failures_total{method="%s",path="%s"} %s'
                    % (method, _escape(path), value)
                )

            lines.extend(
                [
                    "# HELP clindiary_http_rate_limited_total Total rate-limited HTTP requests.",
                    "# TYPE clindiary_http_rate_limited_total counter",
                ]
            )
            for (method, path), value in sorted(self._http_rate_limits.items()):
                lines.append(
                    'clindiary_http_rate_limited_total{method="%s",path="%s"} %s'
                    % (method, _escape(path), value)
                )

            lines.extend(
                [
                    "# HELP clindiary_http_response_time_ms_sum Total response time in milliseconds.",
                    "# TYPE clindiary_http_response_time_ms_sum counter",
                ]
            )
            for (method, path), aggregate in sorted(self._http_latency.items()):
                lines.append(
                    'clindiary_http_response_time_ms_sum{method="%s",path="%s"} %.3f'
                    % (method, _escape(path), aggregate.total_ms)
                )

            lines.extend(
                [
                    "# HELP clindiary_http_response_time_ms_count Number of timed HTTP responses.",
                    "# TYPE clindiary_http_response_time_ms_count counter",
                ]
            )
            for (method, path), aggregate in sorted(self._http_latency.items()):
                lines.append(
                    'clindiary_http_response_time_ms_count{method="%s",path="%s"} %s'
                    % (method, _escape(path), aggregate.count)
                )

            lines.extend(
                [
                    "# HELP clindiary_ocr_runs_total Total OCR attempts by provider/outcome.",
                    "# TYPE clindiary_ocr_runs_total counter",
                ]
            )
            for (provider, outcome), value in sorted(self._ocr_runs.items()):
                lines.append(
                    'clindiary_ocr_runs_total{provider="%s",outcome="%s"} %s'
                    % (_escape(provider), _escape(outcome), value)
                )

            lines.extend(
                [
                    "# HELP clindiary_document_scans_total Total document scan attempts by provider/outcome.",
                    "# TYPE clindiary_document_scans_total counter",
                ]
            )
            for (provider, outcome), value in sorted(self._document_scans.items()):
                lines.append(
                    'clindiary_document_scans_total{provider="%s",outcome="%s"} %s'
                    % (_escape(provider), _escape(outcome), value)
                )

            lines.extend(
                [
                    "# HELP clindiary_ai_summary_runs_total Total AI summary generation outcomes.",
                    "# TYPE clindiary_ai_summary_runs_total counter",
                ]
            )
            for (provider, model_name, outcome, used_fallback), value in sorted(
                self._ai_summary_runs.items()
            ):
                lines.append(
                    'clindiary_ai_summary_runs_total{provider="%s",model_name="%s",outcome="%s",used_fallback="%s"} %s'
                    % (
                        _escape(provider),
                        _escape(model_name),
                        _escape(outcome),
                        _escape(used_fallback),
                        value,
                    )
                )

            lines.extend(
                [
                    "# HELP clindiary_ai_summary_fallbacks_total Total fallback transitions during AI summary generation.",
                    "# TYPE clindiary_ai_summary_fallbacks_total counter",
                ]
            )
            for (from_provider, to_provider), value in sorted(self._ai_summary_fallbacks.items()):
                lines.append(
                    'clindiary_ai_summary_fallbacks_total{from_provider="%s",to_provider="%s"} %s'
                    % (_escape(from_provider), _escape(to_provider), value)
                )

        return "\n".join(lines) + "\n"


def _escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


_metrics_registry = MetricsRegistry()


def get_metrics_registry() -> MetricsRegistry:
    return _metrics_registry
