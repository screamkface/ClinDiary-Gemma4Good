from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
import os
import subprocess
from tempfile import NamedTemporaryFile
from typing import Any

from app.core.config import Settings, get_settings
from app.core.logging import logger
from app.core.metrics import get_metrics_registry


@dataclass(slots=True)
class OcrResult:
    text: str | None
    confidence: float | None
    provider: str | None
    error: str | None


@dataclass(slots=True)
class OcrRuntimeStatus:
    provider: str | None
    ready: bool
    error: str | None


class OcrService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.provider_name = (settings.ocr_provider or "").strip().lower()
        self.fallback_provider_name = (settings.ocr_fallback_provider or "").strip().lower() or None
        self.retry_attempts = max(1, settings.ocr_retry_attempts)
        self._paddle_engine: Any | None = None
        self._paddle_init_error: str | None = None
        self.metrics = get_metrics_registry()

    def extract_text(
        self,
        *,
        content: bytes,
        mime_type: str,
        filename_hint: str | None = None,
    ) -> OcrResult:
        if self.provider_name not in {"paddleocr", "tesseract"}:
            return OcrResult(
                text=None,
                confidence=None,
                provider=self.provider_name or None,
                error=(
                    "OCR completo non disponibile: provider configurato non supportato. "
                    "Imposta OCR_PROVIDER=paddleocr oppure OCR_PROVIDER=tesseract."
                ),
            )

        errors: list[str] = []
        for provider_name in self._ordered_providers():
            last_result: OcrResult | None = None
            for attempt in range(1, self.retry_attempts + 1):
                last_result = self._extract_with_provider(
                    provider_name,
                    content=content,
                    mime_type=mime_type,
                    filename_hint=filename_hint,
                )
                if last_result.text:
                    self.metrics.record_ocr(provider=provider_name, outcome="success")
                    logger.info(
                        "ocr.extract_success",
                        provider=provider_name,
                        attempt=attempt,
                        mime_type=mime_type,
                    )
                    return last_result
                if last_result.error:
                    errors.append(f"{provider_name} attempt {attempt}: {last_result.error}")

            self.metrics.record_ocr(provider=provider_name, outcome="failed")
            logger.warning(
                "ocr.extract_failed",
                provider=provider_name,
                attempts=self.retry_attempts,
                mime_type=mime_type,
                error=last_result.error if last_result else "n/d",
            )

        combined_error = " | ".join(errors) if errors else "OCR completo non disponibile."
        return OcrResult(
            text=None,
            confidence=None,
            provider=self._ordered_providers()[-1] if self._ordered_providers() else None,
            error=combined_error,
        )

    def runtime_status(self) -> OcrRuntimeStatus:
        if self.provider_name not in {"paddleocr", "tesseract"}:
            return OcrRuntimeStatus(
                provider=self.provider_name or None,
                ready=False,
                error="OCR provider configurato non supportato per il runtime check.",
            )

        primary = self._provider_runtime_status(self.provider_name)
        if primary.ready or not self.fallback_provider_name or self.fallback_provider_name == self.provider_name:
            return primary

        fallback = self._provider_runtime_status(self.fallback_provider_name)
        if fallback.ready:
            return OcrRuntimeStatus(
                provider=self.provider_name,
                ready=True,
                error=f"Primary non pronto; fallback {fallback.provider} disponibile.",
            )
        return OcrRuntimeStatus(
            provider=self.provider_name,
            ready=False,
            error="; ".join(
                item
                for item in [primary.error, f"fallback {fallback.provider}: {fallback.error}"]
                if item
            ),
        )

    def _ordered_providers(self) -> list[str]:
        providers = [self.provider_name]
        if (
            self.provider_name in {"paddleocr", "tesseract"}
            and self.fallback_provider_name
            and self.fallback_provider_name != self.provider_name
        ):
            providers.append(self.fallback_provider_name)
        return providers

    def _provider_runtime_status(self, provider_name: str) -> OcrRuntimeStatus:
        if provider_name == "paddleocr":
            engine = self._get_or_init_paddleocr()
            return OcrRuntimeStatus(
                provider="paddleocr",
                ready=engine is not None,
                error=None if engine is not None else self._paddle_init_error,
            )
        if provider_name == "tesseract":
            try:
                completed = subprocess.run(
                    [self.settings.ocr_tesseract_command, "--version"],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                if completed.returncode == 0:
                    return OcrRuntimeStatus(provider="tesseract", ready=True, error=None)
                return OcrRuntimeStatus(
                    provider="tesseract",
                    ready=False,
                    error=(completed.stderr or completed.stdout or "Comando tesseract non disponibile.").strip(),
                )
            except Exception as exc:
                return OcrRuntimeStatus(provider="tesseract", ready=False, error=str(exc))
        return OcrRuntimeStatus(provider=provider_name, ready=False, error="Provider OCR non supportato.")

    def _extract_with_provider(
        self,
        provider_name: str,
        *,
        content: bytes,
        mime_type: str,
        filename_hint: str | None,
    ) -> OcrResult:
        if provider_name == "paddleocr":
            return self._extract_with_paddleocr(
                content=content,
                mime_type=mime_type,
                filename_hint=filename_hint,
            )
        if provider_name == "tesseract":
            return self._extract_with_tesseract(
                content=content,
                mime_type=mime_type,
                filename_hint=filename_hint,
            )
        return OcrResult(
            text=None,
            confidence=None,
            provider=provider_name,
            error="Provider OCR non supportato.",
        )

    def _extract_with_paddleocr(
        self,
        *,
        content: bytes,
        mime_type: str,
        filename_hint: str | None,
    ) -> OcrResult:
        engine = self._get_or_init_paddleocr()
        if engine is None:
            return OcrResult(
                text=None,
                confidence=None,
                provider="paddleocr",
                error=(
                    "OCR completo non disponibile: PaddleOCR non installato o inizializzazione fallita. "
                    f"Dettaglio: {self._paddle_init_error or 'n/d'}"
                ),
            )

        suffix = _suffix_for_mime_type(mime_type, filename_hint)
        try:
            with NamedTemporaryFile(suffix=suffix) as temp_file:
                temp_file.write(content)
                temp_file.flush()
                raw = engine.ocr(temp_file.name, cls=True)

            lines: list[str] = []
            confidences: list[float] = []
            _collect_paddle_lines(raw, lines, confidences)

            if not lines:
                return OcrResult(
                    text=None,
                    confidence=None,
                    provider="paddleocr",
                    error=(
                        "OCR completo non disponibile: nessun testo estratto dal documento "
                        "con PaddleOCR."
                    ),
                )

            confidence = round(sum(confidences) / len(confidences), 3) if confidences else None
            return OcrResult(
                text="\n".join(lines).strip(),
                confidence=confidence,
                provider="paddleocr",
                error=None,
            )
        except Exception as exc:  # pragma: no cover - depends on runtime OCR backend
            return OcrResult(
                text=None,
                confidence=None,
                provider="paddleocr",
                error=f"OCR completo non disponibile: errore PaddleOCR ({exc}).",
            )

    def _get_or_init_paddleocr(self) -> Any | None:
        if self._paddle_engine is not None:
            return self._paddle_engine
        if self._paddle_init_error is not None:
            return None

        try:
            os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")
            from paddleocr import PaddleOCR  # type: ignore[import-not-found]

            device = "gpu" if self.settings.ocr_use_gpu else "cpu"
            try:
                self._paddle_engine = PaddleOCR(
                    use_angle_cls=True,
                    lang=self.settings.ocr_language,
                    device=device,
                )
            except TypeError:
                self._paddle_engine = PaddleOCR(
                    use_angle_cls=True,
                    lang=self.settings.ocr_language,
                    device=device,
                )
            return self._paddle_engine
        except Exception as exc:  # pragma: no cover - depends on runtime OCR backend
            self._paddle_init_error = str(exc)
            return None

    def _extract_with_tesseract(
        self,
        *,
        content: bytes,
        mime_type: str,
        filename_hint: str | None,
    ) -> OcrResult:
        if mime_type == "application/pdf":
            return OcrResult(
                text=None,
                confidence=None,
                provider="tesseract",
                error="Fallback Tesseract non abilitato per PDF in questa fase.",
            )

        suffix = _suffix_for_mime_type(mime_type, filename_hint)
        try:
            with NamedTemporaryFile(suffix=suffix) as temp_file:
                temp_file.write(content)
                temp_file.flush()
                completed = subprocess.run(
                    [
                        self.settings.ocr_tesseract_command,
                        temp_file.name,
                        "stdout",
                        "-l",
                        self.settings.ocr_language,
                    ],
                    capture_output=True,
                    text=True,
                    check=False,
                )
            if completed.returncode != 0:
                return OcrResult(
                    text=None,
                    confidence=None,
                    provider="tesseract",
                    error=(completed.stderr or completed.stdout or "Tesseract ha restituito errore.").strip(),
                )
            text = completed.stdout.strip()
            if not text:
                return OcrResult(
                    text=None,
                    confidence=None,
                    provider="tesseract",
                    error="OCR completo non disponibile: nessun testo estratto con Tesseract.",
                )
            return OcrResult(
                text=text,
                confidence=None,
                provider="tesseract",
                error=None,
            )
        except Exception as exc:
            return OcrResult(
                text=None,
                confidence=None,
                provider="tesseract",
                error=f"OCR completo non disponibile: errore Tesseract ({exc}).",
            )


def _collect_paddle_lines(payload: Any, lines: list[str], confidences: list[float]) -> None:
    if payload is None:
        return

    if isinstance(payload, dict):
        if "rec_texts" in payload and isinstance(payload["rec_texts"], list):
            rec_texts = payload.get("rec_texts") or []
            rec_scores = payload.get("rec_scores") or []
            for index, text in enumerate(rec_texts):
                if isinstance(text, str) and text.strip():
                    lines.append(text.strip())
                if isinstance(rec_scores, list) and index < len(rec_scores):
                    score = rec_scores[index]
                    if isinstance(score, (int, float)):
                        confidences.append(float(score))
            return

        for value in payload.values():
            _collect_paddle_lines(value, lines, confidences)
        return

    if isinstance(payload, (list, tuple)):
        if len(payload) == 2 and isinstance(payload[0], str) and isinstance(payload[1], (int, float)):
            if payload[0].strip():
                lines.append(payload[0].strip())
            confidences.append(float(payload[1]))
            return

        for item in payload:
            _collect_paddle_lines(item, lines, confidences)


def _suffix_for_mime_type(mime_type: str, filename_hint: str | None) -> str:
    if mime_type == "application/pdf":
        return ".pdf"
    if mime_type == "image/jpeg":
        return ".jpg"
    if mime_type == "image/png":
        return ".png"
    if filename_hint and "." in filename_hint:
        return "." + filename_hint.rsplit(".", 1)[1]
    return ".bin"


@lru_cache
def get_ocr_service() -> OcrService:
    return OcrService(get_settings())
