from __future__ import annotations

from dataclasses import dataclass

from app.models.clinical_document import ClinicalDocument
from app.models.enums import ClinicalDocumentType


LAB_KEYWORDS = ("lab", "analisi", "emocromo", "glucosio", "colesterolo", "creatinina", "ematochimico")
IMAGING_KEYWORDS = ("rx", "radiografia", "ecografia", "rm", "rmn", "tac", "tc", "imaging", "torace")


@dataclass(slots=True)
class ClassificationResult:
    document_type: ClinicalDocumentType
    confidence: float


class DocumentClassifier:
    def classify(self, document: ClinicalDocument, text: str | None) -> ClassificationResult:
        if document.document_type != ClinicalDocumentType.GENERIC_DOCUMENT:
            return ClassificationResult(document_type=document.document_type, confidence=0.98)

        haystack = " ".join(
            [
                document.original_filename.lower(),
                document.title.lower(),
                (text or "").lower(),
            ]
        )
        if any(keyword in haystack for keyword in LAB_KEYWORDS):
            return ClassificationResult(document_type=ClinicalDocumentType.LAB_REPORT, confidence=0.91)
        if any(keyword in haystack for keyword in IMAGING_KEYWORDS):
            return ClassificationResult(document_type=ClinicalDocumentType.IMAGING_REPORT, confidence=0.9)
        return ClassificationResult(
            document_type=ClinicalDocumentType.GENERIC_DOCUMENT,
            confidence=0.55,
        )

