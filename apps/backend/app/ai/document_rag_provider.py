from __future__ import annotations

from dataclasses import dataclass
import json
from typing import Any, Protocol

import httpx

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


class OpenAICompatibleDocumentAnswerProvider:
    provider_name = "openai_compatible"

    def __init__(
        self,
        *,
        provider_name: str,
        base_url: str,
        api_key: str,
        model_name: str,
        timeout_seconds: int,
        temperature: float,
        max_output_tokens: int,
        client: httpx.Client | None = None,
    ) -> None:
        self.provider_name = provider_name
        self.model_name = model_name
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.temperature = temperature
        self.max_output_tokens = max_output_tokens
        self._client = client or httpx.Client(timeout=timeout_seconds)

    def answer_question(
        self,
        *,
        question: str,
        context_blocks: list[str],
    ) -> DocumentAnswerResult:
        response = self._client.post(
            f"{self.base_url}/chat/completions",
            headers=_auth_headers(self.api_key),
            json={
                "model": self.model_name,
                "temperature": self.temperature,
                "max_tokens": max(self.max_output_tokens, 1536),
                "messages": [
                    {"role": "system", "content": _document_answer_system_prompt()},
                    {
                        "role": "user",
                        "content": _document_answer_user_prompt(
                            question=question,
                            context_blocks=context_blocks,
                        ),
                    },
                ],
            },
        )
        response.raise_for_status()
        payload = response.json()
        answer = _extract_openai_message_content(payload)
        if not answer:
            raise ValueError(f"{self.provider_name} document QA returned an empty answer")
        return DocumentAnswerResult(
            answer=answer.strip(),
            provider_name=self.provider_name,
            model_name=self.model_name,
        )


class RegoloDocumentAnswerProvider(OpenAICompatibleDocumentAnswerProvider):
    def __init__(
        self,
        *,
        base_url: str,
        api_key: str,
        model_name: str,
        timeout_seconds: int,
        temperature: float,
        max_output_tokens: int,
        client: httpx.Client | None = None,
    ) -> None:
        super().__init__(
            provider_name="regolo_ai",
            base_url=base_url,
            api_key=api_key,
            model_name=_normalize_regolo_model_name(model_name),
            timeout_seconds=timeout_seconds,
            temperature=temperature,
            max_output_tokens=max_output_tokens,
            client=client,
        )


class GemmaDocumentAnswerProvider(OpenAICompatibleDocumentAnswerProvider):
    def __init__(
        self,
        *,
        base_url: str,
        api_key: str,
        model_name: str,
        timeout_seconds: int,
        temperature: float,
        max_output_tokens: int,
        client: httpx.Client | None = None,
    ) -> None:
        super().__init__(
            provider_name="gemma",
            base_url=base_url,
            api_key=api_key,
            model_name=model_name.strip(),
            timeout_seconds=timeout_seconds,
            temperature=temperature,
            max_output_tokens=max_output_tokens,
            client=client,
        )


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


class OpenAICompatibleDocumentEmbeddingProvider:
    provider_name = "openai_compatible"

    def __init__(
        self,
        *,
        provider_name: str,
        base_url: str,
        api_key: str,
        model_name: str,
        embedding_dimensions: int | None,
        timeout_seconds: int,
        client: httpx.Client | None = None,
    ) -> None:
        self.provider_name = provider_name
        self.model_name = model_name
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.embedding_dimensions = embedding_dimensions
        self._embedding_dimensions_enabled = embedding_dimensions is not None
        self._client = client or httpx.Client(timeout=timeout_seconds)

    def embed_texts(self, texts: list[str]) -> list[list[float] | None]:
        if not texts:
            return []
        payload = {
            "model": self.model_name,
            "input": texts,
        }
        if self._embedding_dimensions_enabled and self.embedding_dimensions is not None:
            payload["dimensions"] = self.embedding_dimensions

        response = self._client.post(
            f"{self.base_url}/embeddings",
            headers=_auth_headers(self.api_key),
            json=payload,
        )
        if (
            payload.get("dimensions") is not None
            and _should_retry_embedding_without_dimensions(response)
        ):
            logger.warning(
                "documents.embedding_dimensions_unsupported",
                provider=self.provider_name,
                model=self.model_name,
                requested_dimensions=self.embedding_dimensions,
                status_code=response.status_code,
            )
            self._embedding_dimensions_enabled = False
            payload.pop("dimensions", None)
            response = self._client.post(
                f"{self.base_url}/embeddings",
                headers=_auth_headers(self.api_key),
                json=payload,
            )
        response.raise_for_status()
        response_payload = response.json()
        items = response_payload.get("data") or []
        embeddings_by_index: dict[int, list[float]] = {}
        for item in items:
            index = int(item.get("index", 0))
            embedding = item.get("embedding")
            if isinstance(embedding, list):
                normalized = [float(value) for value in embedding]
                if (
                    self.embedding_dimensions is not None
                    and self._embedding_dimensions_enabled
                    and len(normalized) != self.embedding_dimensions
                ):
                    logger.warning(
                        "documents.embedding_dimensions_mismatch",
                        provider=self.provider_name,
                        model=self.model_name,
                        requested_dimensions=self.embedding_dimensions,
                        returned_dimensions=len(normalized),
                    )
                    self._embedding_dimensions_enabled = False
                embeddings_by_index[index] = normalized
        return [embeddings_by_index.get(index) for index in range(len(texts))]


class RegoloDocumentEmbeddingProvider(OpenAICompatibleDocumentEmbeddingProvider):
    def __init__(
        self,
        *,
        base_url: str,
        api_key: str,
        model_name: str,
        embedding_dimensions: int | None,
        timeout_seconds: int,
        client: httpx.Client | None = None,
    ) -> None:
        super().__init__(
            provider_name="regolo_ai",
            base_url=base_url,
            api_key=api_key,
            model_name=_normalize_regolo_model_name(model_name),
            embedding_dimensions=embedding_dimensions,
            timeout_seconds=timeout_seconds,
            client=client,
        )


class GemmaDocumentEmbeddingProvider(OpenAICompatibleDocumentEmbeddingProvider):
    def __init__(
        self,
        *,
        base_url: str,
        api_key: str,
        model_name: str,
        embedding_dimensions: int | None,
        timeout_seconds: int,
        client: httpx.Client | None = None,
    ) -> None:
        super().__init__(
            provider_name="gemma",
            base_url=base_url,
            api_key=api_key,
            model_name=model_name.strip(),
            embedding_dimensions=embedding_dimensions,
            timeout_seconds=timeout_seconds,
            client=client,
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


class RegoloDocumentRagProvider:
    provider_name = "regolo_ai"

    def __init__(
        self,
        *,
        base_url: str,
        api_key: str,
        answer_model_name: str,
        embedding_model_name: str,
        embedding_dimensions: int | None,
        reranker_model_name: str,
        timeout_seconds: int,
        temperature: float,
        max_output_tokens: int,
        client: httpx.Client | None = None,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.answer_model_name = _normalize_regolo_model_name(answer_model_name)
        self.embedding_model_name = _normalize_regolo_model_name(embedding_model_name)
        self.embedding_dimensions = embedding_dimensions
        self.reranker_model_name = _normalize_regolo_model_name(reranker_model_name)
        self.temperature = temperature
        self.max_output_tokens = max_output_tokens
        self._embedding_dimensions_enabled = embedding_dimensions is not None
        self._client = client or httpx.Client(timeout=timeout_seconds)

    def embed_texts(self, texts: list[str]) -> list[list[float] | None]:
        provider = RegoloDocumentEmbeddingProvider(
            base_url=self.base_url,
            api_key=self.api_key,
            model_name=self.embedding_model_name,
            embedding_dimensions=self.embedding_dimensions,
            timeout_seconds=int(self._client.timeout.connect or 60),
            client=self._client,
        )
        result = provider.embed_texts(texts)
        self._embedding_dimensions_enabled = provider._embedding_dimensions_enabled
        return result

    def rerank(
        self,
        *,
        query: str,
        documents: list[str],
        top_n: int,
    ) -> list[DocumentRerankItem]:
        if not documents:
            return []
        response = self._client.post(
            f"{self.base_url}/rerank",
            headers=_auth_headers(self.api_key),
            json={
                "model": self.reranker_model_name,
                "query": query,
                "documents": documents,
                "top_n": min(max(top_n, 1), len(documents)),
            },
        )
        response.raise_for_status()
        payload = response.json()
        items = payload.get("results") or payload.get("data") or []
        ranked: list[DocumentRerankItem] = []
        for item in items:
            ranked.append(
                DocumentRerankItem(
                    index=int(item.get("index", 0)),
                    score=float(item.get("relevance_score", item.get("score", 0.0))),
                )
            )
        if ranked:
            return ranked
        return [
            DocumentRerankItem(index=index, score=float(len(documents) - index))
            for index in range(min(len(documents), top_n))
        ]

    def answer_question(
        self,
        *,
        question: str,
        context_blocks: list[str],
    ) -> DocumentAnswerResult:
        response = self._client.post(
            f"{self.base_url}/chat/completions",
            headers=_auth_headers(self.api_key),
            json={
                "model": self.answer_model_name,
                "temperature": self.temperature,
                "max_tokens": max(self.max_output_tokens, 1536),
                "messages": [
                    {"role": "system", "content": _document_answer_system_prompt()},
                    {
                        "role": "user",
                        "content": _document_answer_user_prompt(
                            question=question,
                            context_blocks=context_blocks,
                        ),
                    },
                ],
            },
        )
        response.raise_for_status()
        payload = response.json()
        answer = _extract_openai_message_content(payload)
        if not answer:
            raise ValueError("Regolo document QA returned an empty answer")
        return DocumentAnswerResult(
            answer=answer.strip(),
            provider_name=self.provider_name,
            model_name=self.answer_model_name,
            embedding_model_name=self.embedding_model_name,
            reranker_model_name=self.reranker_model_name,
        )


class RegoloDocumentRerankProvider:
    provider_name = "regolo_ai"

    def __init__(
        self,
        *,
        base_url: str,
        api_key: str,
        model_name: str,
        timeout_seconds: int,
        client: httpx.Client | None = None,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.model_name = _normalize_regolo_model_name(model_name)
        self._client = client or httpx.Client(timeout=timeout_seconds)

    def rerank(
        self,
        *,
        query: str,
        documents: list[str],
        top_n: int,
    ) -> list[DocumentRerankItem]:
        if not documents:
            return []
        response = self._client.post(
            f"{self.base_url}/rerank",
            headers=_auth_headers(self.api_key),
            json={
                "model": self.model_name,
                "query": query,
                "documents": documents,
                "top_n": min(max(top_n, 1), len(documents)),
            },
        )
        response.raise_for_status()
        payload = response.json()
        items = payload.get("results") or payload.get("data") or []
        ranked: list[DocumentRerankItem] = []
        for item in items:
            ranked.append(
                DocumentRerankItem(
                    index=int(item.get("index", 0)),
                    score=float(item.get("relevance_score", item.get("score", 0.0))),
                )
            )
        if ranked:
            return ranked
        return [
            DocumentRerankItem(index=index, score=float(len(documents) - index))
            for index in range(min(len(documents), top_n))
        ]


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

    if provider in {"regolo", "regolo_ai"}:
        api_key = settings.document_answer_api_key or settings.regolo_api_key or settings.ai_api_key
        if not api_key:
            logger.warning(
                "documents.answer_provider_config_missing",
                provider=provider,
                regolo_api_key=bool(settings.regolo_api_key),
                ai_api_key=bool(settings.ai_api_key),
            )
            return fallback
        return RegoloDocumentAnswerProvider(
            base_url=(
                settings.document_answer_base_url
                or settings.regolo_base_url
                or settings.ai_base_url
                or "https://api.regolo.ai/v1"
            ),
            api_key=api_key,
            model_name=_resolve_document_answer_model_name(settings, provider),
            timeout_seconds=settings.ai_timeout_seconds,
            temperature=settings.ai_temperature,
            max_output_tokens=settings.ai_max_output_tokens,
        )

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

        api_key = settings.document_answer_api_key or settings.gemma_api_key or settings.ai_api_key
        base_url = settings.document_answer_base_url or settings.gemma_base_url or settings.ai_base_url
        if not api_key or not base_url:
            logger.warning(
                "documents.answer_provider_config_missing",
                provider=provider,
                gemma_api_key=bool(settings.gemma_api_key),
                ai_api_key=bool(settings.ai_api_key),
                gemma_base_url=bool(settings.gemma_base_url),
                ai_base_url=bool(settings.ai_base_url),
            )
            return fallback
        return GemmaDocumentAnswerProvider(
            base_url=base_url,
            api_key=api_key,
            model_name=_resolve_document_answer_model_name(
                settings,
                provider,
                runtime_mode=runtime_mode,
            ),
            timeout_seconds=settings.ai_timeout_seconds,
            temperature=settings.ai_temperature,
            max_output_tokens=settings.ai_max_output_tokens,
        )

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

    if not provider_supports_runtime("document_reranker", provider, "remote"):
        logger.warning(
            "documents.reranker_provider_unsupported",
            provider=provider,
        )
        return fallback

    if provider in {"regolo", "regolo_ai"}:
        api_key = settings.document_reranker_api_key or settings.regolo_api_key or settings.ai_api_key
        if not api_key:
            logger.warning(
                "documents.reranker_provider_config_missing",
                provider=provider,
                regolo_api_key=bool(settings.regolo_api_key),
                ai_api_key=bool(settings.ai_api_key),
            )
            return fallback
        return RegoloDocumentRerankProvider(
            base_url=(
                settings.document_reranker_base_url
                or settings.document_answer_base_url
                or settings.regolo_base_url
                or settings.ai_base_url
                or "https://api.regolo.ai/v1"
            ),
            api_key=api_key,
            model_name=_resolve_document_reranker_model_name(settings, provider),
            timeout_seconds=settings.ai_timeout_seconds,
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

    if provider in {"regolo", "regolo_ai"}:
        api_key = settings.document_embedding_api_key or settings.regolo_api_key or settings.ai_api_key
        if not api_key:
            logger.warning(
                "documents.embedding_provider_config_missing",
                provider=provider,
                regolo_api_key=bool(settings.regolo_api_key),
                ai_api_key=bool(settings.ai_api_key),
            )
            return fallback
        return RegoloDocumentEmbeddingProvider(
            base_url=(
                settings.document_embedding_base_url
                or settings.regolo_base_url
                or settings.ai_base_url
                or "https://api.regolo.ai/v1"
            ),
            api_key=api_key,
            model_name=_resolve_document_embedding_model_name(settings, provider),
            embedding_dimensions=settings.document_embedding_dimensions,
            timeout_seconds=settings.ai_timeout_seconds,
        )

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

        api_key = settings.document_embedding_api_key or settings.gemma_api_key or settings.ai_api_key
        base_url = settings.document_embedding_base_url or settings.gemma_base_url or settings.ai_base_url
        if not api_key or not base_url:
            logger.warning(
                "documents.embedding_provider_config_missing",
                provider=provider,
                gemma_api_key=bool(settings.gemma_api_key),
                ai_api_key=bool(settings.ai_api_key),
                gemma_base_url=bool(settings.gemma_base_url),
                ai_base_url=bool(settings.ai_base_url),
            )
            return fallback
        return GemmaDocumentEmbeddingProvider(
            base_url=base_url,
            api_key=api_key,
            model_name=_resolve_document_embedding_model_name(
                settings,
                provider,
                runtime_mode=runtime_mode,
            ),
            embedding_dimensions=_resolve_document_embedding_dimensions(
                settings,
                runtime_mode=runtime_mode,
            ),
            timeout_seconds=settings.ai_timeout_seconds,
        )

    return fallback


def _auth_headers(api_key: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }


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
        return _normalize_provider_name(settings.document_reranker_provider)

    answer_provider = _normalize_provider_name(settings.document_answer_provider)
    if answer_provider in {"regolo", "regolo_ai"}:
        return "regolo_ai"

    legacy_provider = _normalize_provider_name(settings.ai_provider)
    if legacy_provider in {"regolo", "regolo_ai"}:
        return "regolo_ai"

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
    return _normalize_regolo_model_name(configured or "qwen3-8b")


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
    return _normalize_regolo_model_name(configured or "qwen3-embedding-8b")


def _resolve_document_embedding_dimensions(settings: Settings, *, runtime_mode: str = "remote") -> int | None:
    if runtime_mode == "local":
        return settings.local_embedding_dimensions
    return settings.document_embedding_dimensions


def _resolve_document_reranker_model_name(settings: Settings, provider: str) -> str:
    configured = (settings.document_reranker_model_name or "").strip()
    if provider in {"regolo", "regolo_ai"}:
        return _normalize_regolo_model_name(configured or "qwen3-reranker-4b")
    return configured or "rule_based"


def _normalize_provider_name(raw_value: str | None) -> str:
    normalized = (raw_value or "").strip().lower()
    aliases = {
        "regolo": "regolo_ai",
        "openai": "openai_compatible",
        "gemma_remote": "gemma",
    }
    return aliases.get(normalized, normalized)


def _normalize_runtime_mode(raw_value: str | None) -> str:
    normalized = (raw_value or "remote").strip().lower()
    aliases = {
        "remote_api": "remote",
        "server": "remote",
        "cloud": "remote",
        "on_device": "local",
    }
    return aliases.get(normalized, normalized or "remote")


def _normalize_regolo_model_name(model_name: str) -> str:
    normalized = (model_name or "").strip().lower()
    aliases = {
        "minimax-m2.5-d": "minimax-m2.5",
        "minimax-m2.5-draft": "minimax-m2.5",
    }
    return aliases.get(normalized, normalized)


def _extract_openai_message_content(payload: dict[str, Any]) -> str:
    choices = payload.get("choices") or []
    if not choices:
        return ""
    message = choices[0].get("message", {})
    content = message.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        text_parts = []
        for item in content:
            if isinstance(item, dict) and item.get("type") == "text":
                text_parts.append(item.get("text", ""))
        return "\n".join(part for part in text_parts if part).strip()
    return ""


def _should_retry_embedding_without_dimensions(response: httpx.Response) -> bool:
    if response.status_code not in {400, 404, 422}:
        return False
    body = response.text.lower()
    keywords = (
        "dimension",
        "dimensions",
        "unknown field",
        "unsupported",
        "not supported",
        "extra_forbidden",
    )
    return any(keyword in body for keyword in keywords)


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
