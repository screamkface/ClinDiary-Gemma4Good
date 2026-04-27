from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from app.core.config import Settings
from app.core.logging import logger
from app.ai.local_runtime_adapter import (
    LocalAiRuntimeUnavailableError,
    LocalDocumentAnswerRuntimeAdapter,
    LocalDocumentEmbeddingRuntimeAdapter,
    build_local_document_answer_runtime_adapter,
    build_local_document_embedding_runtime_adapter,
)
from app.ai.provider_capabilities import (
    provider_plans_runtime,
    provider_supports_runtime,
)


@dataclass(slots=True)
class DocumentRerankItem:
    index: int
    score: float


@dataclass(slots=True)
class DocumentAnswerResult:
    answer: str
    provider_name: str
    model_name: str
    embedding_model_name: str | None = None
    reranker_model_name: str | None = None
    used_fallback: bool = False


class DocumentAnswerProvider(Protocol):
    provider_name: str
    model_name: str

    def answer_question(
        self,
        *,
        question: str,
        context_blocks: list[str],
    ) -> DocumentAnswerResult: ...


class DocumentEmbeddingProvider(Protocol):
    provider_name: str
    model_name: str | None

    def embed_texts(self, texts: list[str]) -> list[list[float] | None]: ...


class DocumentRerankProvider(Protocol):
    provider_name: str
    model_name: str | None

    def rerank(
        self,
        *,
        query: str,
        documents: list[str],
        top_n: int,
    ) -> list[DocumentRerankItem]: ...


class DocumentRagProvider(Protocol):
    provider_name: str
    answer_model_name: str
    embedding_model_name: str | None
    reranker_model_name: str | None

    def embed_texts(self, texts: list[str]) -> list[list[float] | None]: ...

    def rerank(
        self,
        *,
        query: str,
        documents: list[str],
        top_n: int,
    ) -> list[DocumentRerankItem]: ...

    def answer_question(
        self,
        *,
        question: str,
        context_blocks: list[str],
    ) -> DocumentAnswerResult: ...


class RuleBasedDocumentRagProvider:
    provider_name = "rule_based"
    answer_model_name = "clindiary-document-rules"
    embedding_model_name = None
    reranker_model_name = None

    def embed_texts(self, texts: list[str]) -> list[list[float] | None]:
        return [None for _ in texts]

    def rerank(
        self,
        *,
        query: str,
        documents: list[str],
        top_n: int,
    ) -> list[DocumentRerankItem]:
        return [
            DocumentRerankItem(index=index, score=float(max(len(documents) - index, 1)))
            for index in range(min(len(documents), top_n))
        ]

    def answer_question(
        self,
        *,
        question: str,
        context_blocks: list[str],
    ) -> DocumentAnswerResult:
        if not context_blocks:
            answer = (
                "Non ho trovato passaggi documentali sufficienti per rispondere in modo affidabile. "
                "Prova a riformulare la domanda o processa i documenti piu recenti."
            )
        else:
            preview = "\n".join(f"- {block.splitlines()[0]}" for block in context_blocks[:4])
            answer = (
                "Ho organizzato i passaggi documentali piu rilevanti per la tua domanda.\n\n"
                "Passaggi considerati:\n"
                f"{preview}\n\n"
                "Questa risposta e organizzativa e non costituisce diagnosi o prescrizione."
            )
        return DocumentAnswerResult(
            answer=answer,
            provider_name=self.provider_name,
            model_name=self.answer_model_name,
            used_fallback=True,
        )


class RuleBasedDocumentAnswerProvider:
    provider_name = "rule_based"
    model_name = "clindiary-document-rules"

    def answer_question(
        self,
        *,
        question: str,
        context_blocks: list[str],
    ) -> DocumentAnswerResult:
        return RuleBasedDocumentRagProvider().answer_question(
            question=question,
            context_blocks=context_blocks,
        )


class RuleBasedDocumentRerankProvider:
    provider_name = "rule_based"
    model_name = None

    def rerank(
        self,
        *,
        query: str,
        documents: list[str],
        top_n: int,
    ) -> list[DocumentRerankItem]:
        return RuleBasedDocumentRagProvider().rerank(
            query=query,
            documents=documents,
            top_n=top_n,
        )


class RuleBasedDocumentEmbeddingProvider:
    provider_name = "rule_based"
    model_name = None

    def embed_texts(self, texts: list[str]) -> list[list[float] | None]:
        return [None for _ in texts]


class LocalRuntimeDocumentAnswerProvider:
    provider_name = "gemma"

    def __init__(
        self,
        *,
        model_name: str,
        adapter: LocalDocumentAnswerRuntimeAdapter,
        max_output_tokens: int,
    ) -> None:
        self.model_name = model_name
        self.adapter = adapter
        self.max_output_tokens = max_output_tokens

    def answer_question(
        self,
        *,
        question: str,
        context_blocks: list[str],
    ) -> DocumentAnswerResult:
        answer = self.adapter.answer_question(
            model_name=self.model_name,
            system_prompt=_document_answer_system_prompt(),
            user_prompt=_document_answer_user_prompt(
                question=question,
                context_blocks=context_blocks,
            ),
            max_output_tokens=max(self.max_output_tokens, 1536),
        )
        if not answer:
            raise ValueError("Local runtime returned an empty document answer")
        return DocumentAnswerResult(
            answer=answer.strip(),
            provider_name=self.provider_name,
            model_name=self.model_name,
        )


class LocalRuntimeDocumentEmbeddingProvider:
    provider_name = "gemma"

    def __init__(
        self,
        *,
        model_name: str,
        embedding_dimensions: int | None,
        adapter: LocalDocumentEmbeddingRuntimeAdapter,
    ) -> None:
        self.model_name = model_name
        self.embedding_dimensions = embedding_dimensions
        self.adapter = adapter

    def embed_texts(self, texts: list[str]) -> list[list[float] | None]:
        return self.adapter.embed_texts(
            model_name=self.model_name,
            texts=texts,
            dimensions=self.embedding_dimensions,
        )


class CompositeDocumentRagProvider:
    def __init__(
        self,
        *,
        answer_provider: DocumentAnswerProvider,
        embedding_provider: DocumentEmbeddingProvider,
        rerank_provider: DocumentRerankProvider,
    ) -> None:
        self.answer_provider = answer_provider
        self.embedding_provider = embedding_provider
        self.rerank_provider = rerank_provider
        self.provider_name = answer_provider.provider_name
        self.answer_model_name = answer_provider.model_name
        self.embedding_model_name = embedding_provider.model_name
        self.reranker_model_name = rerank_provider.model_name

    def embed_texts(self, texts: list[str]) -> list[list[float] | None]:
        return self.embedding_provider.embed_texts(texts)

    def rerank(
        self,
        *,
        query: str,
        documents: list[str],
        top_n: int,
    ) -> list[DocumentRerankItem]:
        return self.rerank_provider.rerank(
            query=query,
            documents=documents,
            top_n=top_n,
        )

    def answer_question(
        self,
        *,
        question: str,
        context_blocks: list[str],
    ) -> DocumentAnswerResult:
        answer = self.answer_provider.answer_question(
            question=question,
            context_blocks=context_blocks,
        )
        return DocumentAnswerResult(
            answer=answer.answer,
            provider_name=answer.provider_name,
            model_name=answer.model_name,
            embedding_model_name=self.embedding_model_name or answer.embedding_model_name,
            reranker_model_name=self.reranker_model_name or answer.reranker_model_name,
            used_fallback=answer.used_fallback,
        )


def build_document_rag_provider(settings: Settings) -> DocumentRagProvider:
    answer_provider = build_document_answer_provider(settings)
    embedding_provider = build_document_embedding_provider(settings)
    rerank_provider = build_document_rerank_provider(settings)

    if (
        answer_provider.provider_name == "rule_based"
        and embedding_provider.provider_name == "rule_based"
        and rerank_provider.provider_name == "rule_based"
    ):
        return RuleBasedDocumentRagProvider()

    return CompositeDocumentRagProvider(
        answer_provider=answer_provider,
        embedding_provider=embedding_provider,
        rerank_provider=rerank_provider,
    )


def build_document_answer_provider(settings: Settings) -> DocumentAnswerProvider:
    fallback = RuleBasedDocumentAnswerProvider()
    provider = _resolve_document_answer_provider_name(settings)
    runtime_mode = _normalize_runtime_mode(settings.document_answer_runtime_mode)

    if not provider_supports_runtime("document_answer", provider, runtime_mode):
        logger.warning(
            "documents.answer_provider_runtime_unsupported",
            provider=provider,
            runtime_mode=runtime_mode,
            planned_local=provider_plans_runtime("document_answer", provider, runtime_mode),
        )
        return fallback

    if provider == "gemma":
        if runtime_mode == "local":
            try:
                adapter = build_local_document_answer_runtime_adapter(settings)
            except LocalAiRuntimeUnavailableError as exc:
                logger.warning(
                    "documents.answer_provider_config_missing",
                    provider=provider,
                    runtime_mode=runtime_mode,
                    error=str(exc),
                )
                return fallback
            return LocalRuntimeDocumentAnswerProvider(
                model_name=_resolve_document_answer_model_name(
                    settings,
                    provider,
                    runtime_mode=runtime_mode,
                ),
                adapter=adapter,
                max_output_tokens=settings.ai_max_output_tokens,
            )

        logger.info(
            "documents.answer_remote_disabled",
            provider=provider,
            runtime_mode=runtime_mode,
        )
        return fallback

    if provider not in {"", "rule_based"}:
        logger.warning(
            "documents.answer_provider_unsupported",
            provider=provider,
        )
    return fallback


def build_document_rerank_provider(settings: Settings) -> DocumentRerankProvider:
    fallback = RuleBasedDocumentRerankProvider()
    provider = _resolve_document_reranker_provider_name(settings)

    if not provider:
        return fallback

    if provider != "rule_based":
        logger.info(
            "documents.reranker_remote_disabled",
            provider=provider,
        )

    return fallback


def build_document_embedding_provider(settings: Settings) -> DocumentEmbeddingProvider:
    fallback = RuleBasedDocumentEmbeddingProvider()
    provider = _resolve_document_embedding_provider_name(settings)
    runtime_mode = _normalize_runtime_mode(settings.document_embedding_runtime_mode)

    if not provider_supports_runtime("document_embedding", provider, runtime_mode):
        logger.warning(
            "documents.embedding_provider_runtime_unsupported",
            provider=provider,
            runtime_mode=runtime_mode,
            planned_local=provider_plans_runtime("document_embedding", provider, runtime_mode),
        )
        return fallback

    if provider == "gemma":
        if runtime_mode == "local":
            try:
                adapter = build_local_document_embedding_runtime_adapter(settings)
            except LocalAiRuntimeUnavailableError as exc:
                logger.warning(
                    "documents.embedding_provider_config_missing",
                    provider=provider,
                    runtime_mode=runtime_mode,
                    error=str(exc),
                )
                return fallback
            return LocalRuntimeDocumentEmbeddingProvider(
                model_name=_resolve_document_embedding_model_name(
                    settings,
                    provider,
                    runtime_mode=runtime_mode,
                ),
                embedding_dimensions=_resolve_document_embedding_dimensions(
                    settings,
                    runtime_mode=runtime_mode,
                ),
                adapter=adapter,
            )

        logger.info(
            "documents.embedding_remote_disabled",
            provider=provider,
            runtime_mode=runtime_mode,
        )
        return fallback

    return fallback


def _resolve_document_answer_provider_name(settings: Settings) -> str:
    configured = settings.document_answer_provider or settings.ai_provider or "rule_based"
    return _normalize_provider_name(configured)


def _resolve_document_embedding_provider_name(settings: Settings) -> str:
    configured = (
        settings.document_embedding_provider
        or settings.document_answer_provider
        or settings.ai_provider
        or "rule_based"
    )
    return _normalize_provider_name(configured)


def _resolve_document_reranker_provider_name(settings: Settings) -> str:
    if settings.document_reranker_provider:
        normalized = _normalize_provider_name(settings.document_reranker_provider)
        return normalized if normalized == "rule_based" else "rule_based"

    return "rule_based"


def _resolve_document_answer_model_name(
    settings: Settings,
    provider: str,
    *,
    runtime_mode: str = "remote",
) -> str:
    configured = (settings.document_answer_model_name or "").strip()
    if provider == "gemma":
        if runtime_mode == "local":
            local_configured = (settings.local_llm_model_name or "").strip()
            if local_configured:
                return local_configured
        if not configured or configured == "qwen3-8b":
            return "gemma-4"
        return configured
    return configured or "clindiary-document-rules"


def _resolve_document_embedding_model_name(
    settings: Settings,
    provider: str,
    *,
    runtime_mode: str = "remote",
) -> str:
    configured = (settings.document_embedding_model_name or "").strip()
    if provider == "gemma":
        if runtime_mode == "local":
            local_configured = (settings.local_embedding_model_name or "").strip()
            if local_configured:
                return local_configured
        if not configured or configured == "qwen3-embedding-8b":
            return "embeddinggemma"
        return configured
    return configured or "embeddinggemma"


def _resolve_document_embedding_dimensions(settings: Settings, *, runtime_mode: str = "remote") -> int | None:
    if runtime_mode == "local":
        return settings.local_embedding_dimensions
    return settings.document_embedding_dimensions


def _resolve_document_reranker_model_name(settings: Settings, provider: str) -> str:
    configured = (settings.document_reranker_model_name or "").strip()
    return configured or "rule_based"


def _normalize_provider_name(raw_value: str | None) -> str:
    normalized = (raw_value or "").strip().lower()
    aliases = {
        "gemma_remote": "gemma",
        "local_gemma4": "gemma",
    }
    normalized = aliases.get(normalized, normalized)
    if normalized in {"gemma", "rule_based"}:
        return normalized
    return "rule_based"


def _normalize_runtime_mode(raw_value: str | None) -> str:
    normalized = (raw_value or "remote").strip().lower()
    aliases = {
        "remote_api": "remote",
        "server": "remote",
        "cloud": "remote",
        "on_device": "local",
    }
    return aliases.get(normalized, normalized or "remote")


def _document_answer_system_prompt() -> str:
    return (
        "Sei ClinDiary. Rispondi solo usando i passaggi documentali forniti. "
        "Non inventare dati, non formulare diagnosi, non prescrivere terapie. "
        "Se i documenti non bastano, dillo esplicitamente. "
        "Usa citazioni inline come [1], [2] che corrispondono ai passaggi forniti."
    )


def _document_answer_user_prompt(*, question: str, context_blocks: list[str]) -> str:
    return (
        "DOMANDA UTENTE:\n"
        f"{question.strip()}\n\n"
        "PASSAGGI DOCUMENTALI DISPONIBILI:\n"
        f"{'\n\n'.join(context_blocks)}\n\n"
        "ISTRUZIONI:\n"
        "- rispondi in italiano\n"
        "- sii chiaro e prudente\n"
        "- se citi un fatto, aggiungi la citazione [n]\n"
        "- chiudi ricordando che la risposta non sostituisce il medico\n"
    )
