from uuid import UUID

from sqlalchemy import bindparam, case, desc, func, literal, or_, select
from sqlalchemy.orm import Session, joinedload

from app.models.clinical_document import ClinicalDocument
from app.models.document_chunk import DocumentChunk
from app.models.document_folder import DocumentFolder
from app.models.enums import DocumentContextStatus
from app.models.imaging_report import ImagingReport
from app.models.lab_panel import LabPanel


class DocumentRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def add(self, document: ClinicalDocument) -> ClinicalDocument:
        self.db.add(document)
        return document

    def add_folder(self, folder: DocumentFolder) -> DocumentFolder:
        self.db.add(folder)
        return folder

    def add_chunk(self, chunk: DocumentChunk) -> DocumentChunk:
        self.db.add(chunk)
        return chunk

    def list_for_patient(
        self,
        patient_id: UUID,
        *,
        context_status: DocumentContextStatus | None = None,
        folder_id: UUID | None = None,
        root_only: bool = False,
    ) -> list[ClinicalDocument]:
        stmt = (
            select(ClinicalDocument)
            .options(joinedload(ClinicalDocument.folder))
            .where(ClinicalDocument.patient_id == patient_id)
            .order_by(ClinicalDocument.upload_date.desc(), ClinicalDocument.created_at.desc())
        )
        if context_status is not None:
            stmt = stmt.where(ClinicalDocument.context_status == context_status)
        if root_only:
            stmt = stmt.where(ClinicalDocument.folder_id.is_(None))
        elif folder_id is not None:
            stmt = stmt.where(ClinicalDocument.folder_id == folder_id)
        return list(self.db.scalars(stmt))

    def list_for_patient_with_details(
        self,
        patient_id: UUID,
        *,
        context_status: DocumentContextStatus | None = None,
        folder_id: UUID | None = None,
        root_only: bool = False,
    ) -> list[ClinicalDocument]:
        stmt = (
            select(ClinicalDocument)
            .options(
                joinedload(ClinicalDocument.folder),
                joinedload(ClinicalDocument.lab_panels).joinedload(LabPanel.results),
                joinedload(ClinicalDocument.imaging_reports),
            )
            .where(ClinicalDocument.patient_id == patient_id)
            .order_by(ClinicalDocument.upload_date.desc(), ClinicalDocument.created_at.desc())
        )
        if context_status is not None:
            stmt = stmt.where(ClinicalDocument.context_status == context_status)
        if root_only:
            stmt = stmt.where(ClinicalDocument.folder_id.is_(None))
        elif folder_id is not None:
            stmt = stmt.where(ClinicalDocument.folder_id == folder_id)
        return list(self.db.execute(stmt).unique().scalars())

    def search_for_patient(self, patient_id: UUID, query: str) -> list[ClinicalDocument]:
        pattern = f"%{query.strip()}%"
        stmt = (
            select(ClinicalDocument)
            .options(joinedload(ClinicalDocument.folder))
            .where(
                ClinicalDocument.patient_id == patient_id,
                or_(
                    ClinicalDocument.title.ilike(pattern),
                    ClinicalDocument.original_filename.ilike(pattern),
                    ClinicalDocument.source.ilike(pattern),
                    ClinicalDocument.ocr_text.ilike(pattern),
                ),
            )
            .order_by(ClinicalDocument.upload_date.desc(), ClinicalDocument.created_at.desc())
        )
        return list(self.db.scalars(stmt))

    def list_folders_for_patient(
        self,
        patient_id: UUID,
        *,
        parent_folder_id: UUID | None = None,
    ) -> list[DocumentFolder]:
        stmt = (
            select(DocumentFolder)
            .where(DocumentFolder.patient_id == patient_id)
            .order_by(DocumentFolder.name.asc(), DocumentFolder.created_at.asc())
        )
        if parent_folder_id is None:
            stmt = stmt.where(DocumentFolder.parent_folder_id.is_(None))
        else:
            stmt = stmt.where(DocumentFolder.parent_folder_id == parent_folder_id)
        return list(self.db.scalars(stmt))

    def list_all_folders_for_patient(self, patient_id: UUID) -> list[DocumentFolder]:
        stmt = (
            select(DocumentFolder)
            .where(DocumentFolder.patient_id == patient_id)
            .order_by(DocumentFolder.name.asc(), DocumentFolder.created_at.asc())
        )
        return list(self.db.scalars(stmt))

    def get_folder_for_patient(self, patient_id: UUID, folder_id: UUID) -> DocumentFolder | None:
        stmt = select(DocumentFolder).where(
            DocumentFolder.patient_id == patient_id,
            DocumentFolder.id == folder_id,
        )
        return self.db.scalar(stmt)

    def get_for_patient(self, patient_id: UUID, document_id: UUID) -> ClinicalDocument | None:
        stmt = (
            select(ClinicalDocument)
            .options(
                joinedload(ClinicalDocument.folder),
                joinedload(ClinicalDocument.lab_panels).joinedload(LabPanel.results),
                joinedload(ClinicalDocument.imaging_reports),
            )
            .where(ClinicalDocument.patient_id == patient_id, ClinicalDocument.id == document_id)
        )
        return self.db.execute(stmt).unique().scalar_one_or_none()

    def get_by_id(self, document_id: UUID) -> ClinicalDocument | None:
        stmt = (
            select(ClinicalDocument)
            .options(
                joinedload(ClinicalDocument.folder),
                joinedload(ClinicalDocument.chunks),
                joinedload(ClinicalDocument.lab_panels).joinedload(LabPanel.results),
                joinedload(ClinicalDocument.imaging_reports),
            )
            .where(ClinicalDocument.id == document_id)
        )
        return self.db.execute(stmt).unique().scalar_one_or_none()

    def list_chunks_for_patient(
        self,
        patient_id: UUID,
        *,
        folder_id: UUID | None = None,
        include_old: bool = False,
    ) -> list[DocumentChunk]:
        stmt = (
            select(DocumentChunk)
            .where(DocumentChunk.patient_id == patient_id)
            .order_by(DocumentChunk.updated_at.desc(), DocumentChunk.chunk_index.asc())
        )
        if folder_id is not None:
            stmt = stmt.where(DocumentChunk.folder_id == folder_id)
        if not include_old:
            stmt = stmt.where(DocumentChunk.context_status == DocumentContextStatus.ACTIVE)
        return list(self.db.scalars(stmt))

    def list_chunks_for_document(self, document_id: UUID) -> list[DocumentChunk]:
        stmt = (
            select(DocumentChunk)
            .where(DocumentChunk.document_id == document_id)
            .order_by(DocumentChunk.chunk_index.asc())
        )
        return list(self.db.scalars(stmt))

    def search_chunks_hybrid_postgres(
        self,
        patient_id: UUID,
        *,
        question: str,
        query_embedding: list[float] | None,
        query_embedding_dimensions: int | None,
        folder_id: UUID | None = None,
        include_old: bool = False,
        limit: int = 48,
    ) -> list[tuple[DocumentChunk, float, float, float]]:
        if self.db.bind is None or self.db.bind.dialect.name != "postgresql":
            return []

        normalized_question = question.strip()
        if not normalized_question:
            return []

        searchable_text = (
            func.coalesce(DocumentChunk.document_title, "")
            + literal(" ")
            + func.coalesce(DocumentChunk.folder_name, "")
            + literal(" ")
            + func.coalesce(DocumentChunk.source, "")
            + literal(" ")
            + func.coalesce(DocumentChunk.chunk_label, "")
            + literal(" ")
            + func.coalesce(DocumentChunk.content, "")
        )
        search_vector = func.to_tsvector("simple", searchable_text)
        ts_query = func.websearch_to_tsquery("simple", normalized_question)
        lexical_score = func.ts_rank_cd(search_vector, ts_query)

        if query_embedding is not None and query_embedding_dimensions is not None:
            embedding_param = bindparam(
                "query_embedding",
                value=query_embedding,
                type_=DocumentChunk.embedding.type,
            )
            semantic_score = case(
                (
                    (DocumentChunk.embedding.is_not(None))
                    & (DocumentChunk.embedding_dimensions == query_embedding_dimensions),
                    1 - DocumentChunk.embedding.op("<=>")(embedding_param),
                ),
                else_=literal(0.0),
            )
        else:
            semantic_score = literal(0.0)

        combined_score = (lexical_score * 0.45) + (semantic_score * 0.55)
        stmt = (
            select(
                DocumentChunk,
                lexical_score.label("lexical_score"),
                semantic_score.label("semantic_score"),
                combined_score.label("combined_score"),
            )
            .where(
                DocumentChunk.patient_id == patient_id,
                search_vector.op("@@")(ts_query),
            )
            .order_by(
                desc(combined_score),
                desc(lexical_score),
                desc(DocumentChunk.updated_at),
            )
            .limit(limit)
        )
        if folder_id is not None:
            stmt = stmt.where(DocumentChunk.folder_id == folder_id)
        if not include_old:
            stmt = stmt.where(DocumentChunk.context_status == DocumentContextStatus.ACTIVE)

        rows = self.db.execute(stmt).all()
        return [
            (
                row[0],
                float(row[1] or 0.0),
                float(row[2] or 0.0),
                float(row[3] or 0.0),
            )
            for row in rows
        ]

    def delete_chunks_for_document(self, document_id: UUID) -> None:
        for chunk in self.list_chunks_for_document(document_id):
            self.db.delete(chunk)

    def clear_structured_data(self, document: ClinicalDocument) -> None:
        document.lab_panels.clear()
        document.imaging_reports.clear()

    def delete(self, document: ClinicalDocument) -> None:
        self.db.delete(document)
