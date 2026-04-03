from __future__ import annotations

from dataclasses import dataclass

import httpx

from app.core.config import Settings, get_settings
from app.core.metrics import get_metrics_registry


@dataclass(slots=True)
class DocumentScanResult:
    status: str
    provider: str
    error: str | None = None


class DocumentScanService:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()
        self.provider_name = (self.settings.document_scan_provider or "none").strip().lower()
        self.metrics = get_metrics_registry()

    def scan(
        self,
        *,
        filename: str,
        content: bytes,
        mime_type: str,
        sha256_hash: str,
    ) -> DocumentScanResult:
        if self.provider_name in {"", "none", "disabled"}:
            self.metrics.record_document_scan(provider="none", outcome="skipped")
            return DocumentScanResult(status="skipped", provider="none")

        if self.provider_name == "webhook":
            return self._scan_via_webhook(
                filename=filename,
                content=content,
                mime_type=mime_type,
                sha256_hash=sha256_hash,
            )

        self.metrics.record_document_scan(provider=self.provider_name, outcome="failed")
        return DocumentScanResult(
            status="failed",
            provider=self.provider_name,
            error="Provider di scanning documento non supportato.",
        )

    def _scan_via_webhook(
        self,
        *,
        filename: str,
        content: bytes,
        mime_type: str,
        sha256_hash: str,
    ) -> DocumentScanResult:
        if not self.settings.document_scan_webhook_url:
            self.metrics.record_document_scan(provider="webhook", outcome="failed")
            return DocumentScanResult(
                status="failed",
                provider="webhook",
                error="Webhook di scanning non configurato.",
            )

        try:
            response = httpx.post(
                self.settings.document_scan_webhook_url,
                data={
                    "filename": filename,
                    "mime_type": mime_type,
                    "sha256": sha256_hash,
                    "size_bytes": str(len(content)),
                },
                files={"file": (filename, content, mime_type)},
                timeout=20,
            )
            response.raise_for_status()
            payload = response.json() if response.headers.get("content-type", "").startswith("application/json") else {}
            verdict = str(payload.get("verdict", "clean")).strip().lower()
            if verdict in {"clean", "passed", "ok"}:
                self.metrics.record_document_scan(provider="webhook", outcome="passed")
                return DocumentScanResult(status="passed", provider="webhook")
            error = str(payload.get("message") or "Documento non superato al controllo di sicurezza.")
            self.metrics.record_document_scan(provider="webhook", outcome="failed")
            return DocumentScanResult(status="failed", provider="webhook", error=error)
        except Exception as exc:
            self.metrics.record_document_scan(provider="webhook", outcome="failed")
            return DocumentScanResult(
                status="failed",
                provider="webhook",
                error=f"Scanning documento fallito: {exc}",
            )
