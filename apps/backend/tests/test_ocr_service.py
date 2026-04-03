import types

from app.core.config import Settings
from app.services.ocr_service import OcrService


def test_ocr_service_rejects_unknown_provider():
    service = OcrService(Settings(ocr_provider="unknown-provider"))

    result = service.extract_text(content=b"abc", mime_type="image/png")

    assert result.text is None
    assert result.provider == "unknown-provider"
    assert result.error is not None
    assert "provider configurato non supportato" in result.error


def test_ocr_service_returns_fallback_when_paddle_not_available():
    service = OcrService(Settings(ocr_provider="paddleocr", ocr_fallback_provider=None))
    service._paddle_init_error = "module not found"

    result = service.extract_text(content=b"abc", mime_type="image/png")

    assert result.text is None
    assert result.provider == "paddleocr"
    assert result.error is not None
    assert "OCR completo non disponibile" in result.error


def test_ocr_runtime_status_exposes_init_error():
    service = OcrService(Settings(ocr_provider="paddleocr", ocr_fallback_provider=None))
    service._paddle_init_error = "module not found"

    status = service.runtime_status()

    assert status.provider == "paddleocr"
    assert status.ready is False
    assert status.error == "module not found"


def test_ocr_service_initializes_paddleocr_with_device_argument(monkeypatch):
    captured: dict[str, object] = {}

    class _FakePaddleOCR:
        def __init__(self, **kwargs):
            captured["kwargs"] = kwargs

        def ocr(self, *args, **kwargs):
            return []

    monkeypatch.setitem(
        __import__("sys").modules,
        "paddleocr",
        types.SimpleNamespace(PaddleOCR=_FakePaddleOCR),
    )

    service = OcrService(Settings(ocr_provider="paddleocr", ocr_fallback_provider=None))
    service._paddle_init_error = None

    engine = service._get_or_init_paddleocr()

    assert engine is not None
    assert captured["kwargs"]["device"] == "cpu"
