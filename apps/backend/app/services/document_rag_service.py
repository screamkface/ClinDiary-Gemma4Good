from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
import math
import re
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.ai.document_rag_provider import (
    DocumentAnswerResult,
    DocumentRagProvider,
    RuleBasedDocumentRagProvider,
    build_document_rag_provider,
)
from app.core.config import get_settings
from app.core.logging import logger
from app.core.security import create_document_view_token, utcnow
from app.models.clinical_document import ClinicalDocument
from app.models.document_chunk import DocumentChunk
from app.models.enums import DocumentContextStatus
from app.models.user import User
from app.repositories.document_repository import DocumentRepository
from app.schemas.documents import (
    DocumentQueryCitationResponse,
    DocumentQueryRequest,
    DocumentQueryResponse,
)
from app.services.billing_service import BillingFeatureCode, BillingService
from app.services.profile_context import resolve_user_profile


settings = get_settings()


@dataclass(slots=True)
class _ChunkDraft:
    chunk_index: int
    chunk_kind: str
    chunk_label: str | None
    content: str


@dataclass(slots=True)
class _ScoredChunk:
    chunk: DocumentChunk
    lexical_score: float
    semantic_score: float
    combined_score: float
    rerank_score: float | None = None


class DocumentRagService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.document_repository = DocumentRepository(db)
        self.billing_service = BillingService(db)

    def reindex_document(
        self,
        document_id: UUID,
        *,
        provider: DocumentRagProvider | None = None,
    ) -> int:
        document = self.document_repository.get_by_id(document_id)
        if document is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

        active_provider = provider or build_document_rag_provider(settings)
        drafts = self._build_chunk_drafts(document)
        try:
            embeddings = active_provider.embed_texts([item.content for item in drafts]) if drafts else []
        except Exception as exc:
            logger.warning(
                "documents.embedding_failed",
                document_id=str(document.id),
                provider=active_provider.provider_name,
                error=str(exc),
            )
            embeddings = [None for _ in drafts]

        self.document_repository.delete_chunks_for_document(document.id)
        self.db.flush()
        embedded_at = utcnow()
        for index, draft in enumerate(drafts):
            self.document_repository.add_chunk(
                DocumentChunk(
                    patient_id=document.patient_id,
                    document_id=document.id,
                    folder_id=document.folder_id,
                    document_title=document.title,
                    folder_name=document.folder.name if document.folder is not None else None,
                    document_type=document.document_type,
                    context_status=document.context_status,
                    source=document.source,
                    upload_date=document.upload_date,
                    exam_date=document.exam_date,
                    chunk_index=draft.chunk_index,
                    chunk_kind=draft.chunk_kind,
                    chunk_label=draft.chunk_label,
                    content=draft.content,
                    embedding_model_name=active_provider.embedding_model_name,
                    embedding_dimensions=(
                        len(embeddings[index])
                        if index < len(embeddings) and embeddings[index] is not None
                        else None
                    ),
                    embedding=embeddings[index] if index < len(embeddings) else None,
                    embedded_at=embedded_at if index < len(embeddings) and embeddings[index] is not None else None,
                )
            )
        self.db.flush()
        logger.info(
            "documents.indexed",
            document_id=str(document.id),
            chunks=len(drafts),
            provider=active_provider.provider_name,
            embedding_model=active_provider.embedding_model_name,
        )
        return len(drafts)

    def reindex_patient_documents(self, user: User) -> int:
        profile = self._require_profile(user)
        documents = self.document_repository.list_for_patient_with_details(profile.id)
        provider = build_document_rag_provider(settings)
        total_chunks = 0
        for document in documents:
            total_chunks += self.reindex_document(document.id, provider=provider)
        self.db.commit()
        return total_chunks

    def answer_question(
        self,
        user: User,
        *,
        payload: DocumentQueryRequest,
    ) -> DocumentQueryResponse:
        self.billing_service.require_feature(user, BillingFeatureCode.AI_DOCUMENT_QUERY)
        profile = self._require_profile(user)
        provider = build_document_rag_provider(settings)
        scope_label = self._scope_label(profile.id, payload.folder_id)
        query_embedding = self._embed_query(provider=provider, question=payload.question)
        query_embedding_dimensions = len(query_embedding) if query_embedding is not None else None
        scored = self._retrieve_scored_chunks(
            provider=provider,
            patient_id=profile.id,
            folder_id=payload.folder_id,
            question=payload.question,
            query_embedding=query_embedding,
            query_embedding_dimensions=query_embedding_dimensions,
        )
        if not scored:
            fallback = provider.answer_question(question=payload.question, context_blocks=[])
            return DocumentQueryResponse(
                answer=fallback.answer,
                citations=[],
                provider_name=fallback.provider_name,
                model_name=fallback.model_name,
                embedding_model_name=fallback.embedding_model_name,
                reranker_model_name=fallback.reranker_model_name,
                retrieved_chunks=0,
                retrieved_documents=0,
                search_scope_label=scope_label,
                coverage_note="Nessun passaggio indicizzato rilevante trovato nell'ambito selezionato.",
                used_fallback=fallback.used_fallback,
            )

        ranked = self._rerank_chunks(
            provider=provider,
            question=payload.question,
            chunks=scored,
            top_n=payload.top_k or settings.document_answer_top_n,
        )
        context_blocks = [
            self._context_block(index + 1, item.chunk)
            for index, item in enumerate(ranked)
        ]
        answer_result = self._answer_with_fallback(
            provider=provider,
            question=payload.question,
            context_blocks=context_blocks,
        )
        citations = [
            self._build_citation_response(user, item)
            for item in ranked
        ]
        retrieved_documents = len({item.chunk.document_id for item in ranked})
        coverage_note = (
            f"{retrieved_documents} {'documento' if retrieved_documents == 1 else 'documenti'} e "
            f"{len(ranked)} {'passaggio' if len(ranked) == 1 else 'passaggi'} usati per la risposta."
            if ranked
            else "Nessun passaggio usato per la risposta."
        )
        return DocumentQueryResponse(
            answer=answer_result.answer,
            citations=citations,
            provider_name=answer_result.provider_name,
            model_name=answer_result.model_name,
            embedding_model_name=answer_result.embedding_model_name,
            reranker_model_name=answer_result.reranker_model_name,
            retrieved_chunks=len(ranked),
            retrieved_documents=retrieved_documents,
            search_scope_label=scope_label,
            coverage_note=coverage_note,
            used_fallback=answer_result.used_fallback,
        )

    def delete_document_index(self, document_id: UUID) -> None:
        self.document_repository.delete_chunks_for_document(document_id)

    def _scope_label(self, patient_id: UUID, folder_id: UUID | None) -> str:
        if folder_id is None:
            return "Tutto l'archivio"
        folder = self.document_repository.get_folder_for_patient(patient_id, folder_id)
        if folder is None:
            return "Cartella selezionata"
        return f"Cartella: {folder.name}"

    def _retrieve_scored_chunks(
        self,
        *,
        provider: DocumentRagProvider,
        patient_id: UUID,
        folder_id: UUID | None,
        question: str,
        query_embedding: list[float] | None,
        query_embedding_dimensions: int | None,
    ) -> list[_ScoredChunk]:
        if self.db.bind is not None and self.db.bind.dialect.name == "postgresql":
            try:
                rows = self.document_repository.search_chunks_hybrid_postgres(
                    patient_id,
                    question=question,
                    query_embedding=query_embedding,
                    query_embedding_dimensions=query_embedding_dimensions,
                    folder_id=folder_id,
                    include_old=False,
                    limit=settings.document_candidate_limit,
                )
                if rows:
                    logger.info(
                        "documents.hybrid_search_postgres",
                        patient_id=str(patient_id),
                        folder_id=str(folder_id) if folder_id else None,
                        candidates=len(rows),
                    )
                    return [
                        _ScoredChunk(
                            chunk=chunk,
                            lexical_score=lexical_score,
                            semantic_score=semantic_score,
                            combined_score=combined_score,
                        )
                        for chunk, lexical_score, semantic_score, combined_score in rows
                    ]
            except Exception as exc:
                logger.warning(
                    "documents.hybrid_search_postgres_failed",
                    patient_id=str(patient_id),
                    provider=provider.provider_name,
                    error=str(exc),
                )

        chunks = self.document_repository.list_chunks_for_patient(
            patient_id,
            folder_id=folder_id,
            include_old=False,
        )
        if not chunks:
            return []
        return self._score_chunks(
            question=question,
            chunks=chunks,
            query_embedding=query_embedding,
        )

    def _embed_query(
        self,
        *,
        provider: DocumentRagProvider,
        question: str,
    ) -> list[float] | None:
        try:
            embeddings = provider.embed_texts([question.strip()])
            if embeddings and embeddings[0] is not None:
                return embeddings[0]
        except Exception as exc:
            logger.warning(
                "documents.query_embedding_failed",
                provider=provider.provider_name,
                error=str(exc),
            )
        return None

    def _score_chunks(
        self,
        *,
        question: str,
        chunks: list[DocumentChunk],
        query_embedding: list[float] | None,
    ) -> list[_ScoredChunk]:
        scored: list[_ScoredChunk] = []
        for chunk in chunks:
            lexical = _lexical_score(question, chunk)
            semantic = _cosine_similarity(query_embedding, chunk.embedding) if query_embedding else 0.0
            combined = (lexical * 0.45) + (semantic * 0.55)
            if lexical <= 0 and semantic <= 0:
                continue
            scored.append(
                _ScoredChunk(
                    chunk=chunk,
                    lexical_score=lexical,
                    semantic_score=semantic,
                    combined_score=combined,
                )
            )

        scored.sort(key=lambda item: item.combined_score, reverse=True)
        return scored[: settings.document_candidate_limit]

    def _rerank_chunks(
        self,
        *,
        provider: DocumentRagProvider,
        question: str,
        chunks: list[_ScoredChunk],
        top_n: int,
    ) -> list[_ScoredChunk]:
        top_candidates = chunks[: settings.document_rerank_top_n]
        try:
            reranked = provider.rerank(
                query=question,
                documents=[item.chunk.content for item in top_candidates],
                top_n=min(top_n, len(top_candidates)),
            )
        except Exception as exc:
            logger.warning(
                "documents.rerank_failed",
                provider=provider.provider_name,
                error=str(exc),
            )
            reranked = []
        if not reranked:
            return top_candidates[:top_n]

        final: list[_ScoredChunk] = []
        seen_indexes: set[int] = set()
        for item in reranked:
            if 0 <= item.index < len(top_candidates):
                candidate = top_candidates[item.index]
                candidate.rerank_score = item.score
                final.append(candidate)
                seen_indexes.add(item.index)

        if len(final) < top_n:
            for index, candidate in enumerate(top_candidates):
                if index in seen_indexes:
                    continue
                final.append(candidate)
                if len(final) >= top_n:
                    break
        return final[:top_n]

    def _build_chunk_drafts(self, document: ClinicalDocument) -> list[_ChunkDraft]:
        drafts: list[_ChunkDraft] = []
        metadata_lines = [
            f"Documento: {document.title}",
            f"Tipo: {document.document_type.value}",
            f"Nome file: {document.original_filename}",
        ]
        if document.source:
            metadata_lines.append(f"Fonte: {document.source}")
        if document.exam_date:
            metadata_lines.append(f"Data esame: {document.exam_date.isoformat()}")
        if document.folder is not None:
            metadata_lines.append(f"Cartella: {document.folder.name}")
        drafts.append(
            _ChunkDraft(
                chunk_index=0,
                chunk_kind="metadata",
                chunk_label="Metadati documento",
                content="\n".join(metadata_lines),
            )
        )

        next_index = 1
        for panel in document.lab_panels:
            lines = [f"Pannello laboratorio: {panel.panel_name}"]
            if panel.panel_date:
                lines.append(f"Data pannello: {panel.panel_date.isoformat()}")
            for result in panel.results:
                range_label = ""
                if result.ref_min is not None or result.ref_max is not None:
                    range_label = (
                        f" range {result.ref_min if result.ref_min is not None else '-'}"
                        f"-{result.ref_max if result.ref_max is not None else '-'}"
                    )
                abnormal_label = " fuori range" if result.abnormal_flag else ""
                lines.append(
                    f"{result.analyte_name}: {result.value} {result.unit or ''}{range_label}{abnormal_label}".strip()
                )
            drafts.append(
                _ChunkDraft(
                    chunk_index=next_index,
                    chunk_kind="lab_panel",
                    chunk_label=panel.panel_name,
                    content="\n".join(lines),
                )
            )
            next_index += 1

        for report in document.imaging_reports:
            lines = [
                f"Referto imaging: {report.exam_type or document.title}",
            ]
            if report.body_part:
                lines.append(f"Distretto: {report.body_part}")
            lines.append(report.report_text)
            if report.impression:
                lines.append(f"Conclusioni: {report.impression}")
            drafts.append(
                _ChunkDraft(
                    chunk_index=next_index,
                    chunk_kind="imaging_report",
                    chunk_label=report.exam_type or "Imaging",
                    content="\n".join(lines),
                )
            )
            next_index += 1

        if document.ocr_text and document.ocr_text.strip():
            for segment in _split_text(
                document.ocr_text,
                chunk_size=settings.document_chunk_size_chars,
                overlap=settings.document_chunk_overlap_chars,
            ):
                drafts.append(
                    _ChunkDraft(
                        chunk_index=next_index,
                        chunk_kind="ocr_text",
                        chunk_label=f"Testo estratto {next_index}",
                        content=segment,
                    )
                )
                next_index += 1

        return drafts

    def _build_citation_response(
        self,
        user: User,
        chunk: _ScoredChunk,
    ) -> DocumentQueryCitationResponse:
        viewer_token, _ = create_document_view_token(
            document_id=chunk.chunk.document_id,
            user_id=user.id,
        )
        excerpt = chunk.chunk.content.strip()
        if len(excerpt) > 320:
            excerpt = f"{excerpt[:317].rstrip()}..."
        return DocumentQueryCitationResponse(
            document_id=chunk.chunk.document_id,
            document_title=chunk.chunk.document_title,
            document_type=chunk.chunk.document_type,
            folder_name=chunk.chunk.folder_name,
            exam_date=chunk.chunk.exam_date,
            chunk_kind=chunk.chunk.chunk_kind,
            chunk_label=chunk.chunk.chunk_label,
            excerpt=excerpt,
            score=round(chunk.rerank_score or chunk.combined_score, 4),
            viewer_url=f"{settings.api_v1_prefix}/documents/{chunk.chunk.document_id}/content?token={viewer_token}",
        )

    def _context_block(self, index: int, chunk: DocumentChunk) -> str:
        header = (
            f"[{index}] Documento: {chunk.document_title} | "
            f"Tipo: {chunk.document_type.value} | "
            f"Chunk: {chunk.chunk_kind}"
        )
        if chunk.exam_date:
            header += f" | Data esame: {chunk.exam_date.isoformat()}"
        if chunk.folder_name:
            header += f" | Cartella: {chunk.folder_name}"
        return f"{header}\n{chunk.content.strip()}"

    def _answer_with_fallback(
        self,
        *,
        provider: DocumentRagProvider,
        question: str,
        context_blocks: list[str],
    ) -> DocumentAnswerResult:
        try:
            return provider.answer_question(
                question=question,
                context_blocks=context_blocks,
            )
        except Exception as exc:
            logger.warning(
                "documents.answer_generation_failed",
                provider=provider.provider_name,
                error=str(exc),
            )
            return RuleBasedDocumentRagProvider().answer_question(
                question=question,
                context_blocks=context_blocks,
            )

    @staticmethod
    def _require_profile(user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile


def _split_text(text: str, *, chunk_size: int, overlap: int) -> list[str]:
    normalized = re.sub(r"\n{3,}", "\n\n", text.strip())
    if not normalized:
        return []
    segments: list[str] = []
    start = 0
    while start < len(normalized):
        end = min(start + chunk_size, len(normalized))
        if end < len(normalized):
            last_break = normalized.rfind("\n", start, end)
            if last_break > start + int(chunk_size * 0.6):
                end = last_break
        segment = normalized[start:end].strip()
        if segment:
            segments.append(segment)
        if end >= len(normalized):
            break
        start = max(end - overlap, start + 1)
    return segments


def _lexical_score(question: str, chunk: DocumentChunk) -> float:
    haystack = f"{chunk.document_title}\n{chunk.content}".lower()
    normalized_query = question.strip().lower()
    if not normalized_query:
        return 0.0
    tokens = [token for token in re.split(r"[^a-z0-9]+", normalized_query) if len(token) >= 3]
    if not tokens:
        return 0.0
    score = 0.0
    if normalized_query in haystack:
        score += 2.5
    unique_tokens = set(tokens)
    for token in unique_tokens:
        if token in haystack:
            score += 1.0
    return score / max(len(unique_tokens), 1)


def _cosine_similarity(left: list[float] | None, right: list[float] | None) -> float:
    if left is None or right is None or len(left) != len(right) or not left:
        return 0.0
    numerator = sum(a * b for a, b in zip(left, right, strict=False))
    left_norm = math.sqrt(sum(a * a for a in left))
    right_norm = math.sqrt(sum(b * b for b in right))
    if left_norm == 0 or right_norm == 0:
        return 0.0
    return numerator / (left_norm * right_norm)
