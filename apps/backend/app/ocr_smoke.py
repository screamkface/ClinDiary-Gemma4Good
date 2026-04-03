from __future__ import annotations

import argparse
import mimetypes
from pathlib import Path
import sys

from app.services.ocr_service import get_ocr_service


def main() -> int:
    parser = argparse.ArgumentParser(description="ClinDiary OCR smoke check")
    parser.add_argument("--file", help="Percorso file da provare con OCR", default=None)
    parser.add_argument("--mime-type", help="Mime type opzionale", default=None)
    args = parser.parse_args()

    service = get_ocr_service()
    status = service.runtime_status()

    print(f"provider={status.provider or 'n/a'} ready={status.ready}")
    if status.error:
        print(f"runtime_error={status.error}")

    if args.file is None:
        return 0 if status.ready else 1

    file_path = Path(args.file)
    if not file_path.exists():
        print(f"file_not_found={file_path}")
        return 2

    mime_type = args.mime_type or mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    result = service.extract_text(
        content=file_path.read_bytes(),
        mime_type=mime_type,
        filename_hint=file_path.name,
    )
    print(f"ocr_provider={result.provider or 'n/a'}")
    print(f"ocr_confidence={result.confidence}")
    if result.error:
        print(f"ocr_error={result.error}")
        return 3

    text = (result.text or "").strip()
    if not text:
        print("ocr_text=")
        return 4

    preview = text[:400].replace("\n", " ")
    print(f"ocr_text_preview={preview}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
