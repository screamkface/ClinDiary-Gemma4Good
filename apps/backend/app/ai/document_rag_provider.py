from __future__ import annotations

from dataclasses import dataclass
import json
from typing import Any, Protocol

import httpx

from app.core.config import Settings
from app.core.logging import logger


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
        if not texts:
            return []
        payload = {
            "model": self.embedding_model_name,
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
                model=self.embedding_model_name,
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
        payload = response.json()
        items = payload.get("data") or []
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
                        model=self.embedding_model_name,
                        requested_dimensions=self.embedding_dimensions,
                        returned_dimensions=len(normalized),
                    )
                    self._embedding_dimensions_enabled = False
                embeddings_by_index[index] = normalized
        return [embeddings_by_index.get(index) for index in range(len(texts))]

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


def build_document_rag_provider(settings: Settings) -> DocumentRagProvider:
    fallback = RuleBasedDocumentRagProvider()
    provider = (settings.ai_provider or "").strip().lower()
    if provider not in {"regolo", "regolo_ai"}:
        return fallback

    api_key = settings.regolo_api_key or settings.ai_api_key
    if not api_key:
        logger.warning(
            "documents.rag_provider_config_missing",
            provider=provider,
            regolo_api_key=bool(settings.regolo_api_key),
            ai_api_key=bool(settings.ai_api_key),
        )
        return fallback

    return RegoloDocumentRagProvider(
        base_url=settings.regolo_base_url or "https://api.regolo.ai/v1",
        api_key=api_key,
        answer_model_name=settings.document_answer_model_name,
        embedding_model_name=settings.document_embedding_model_name,
        embedding_dimensions=settings.document_embedding_dimensions,
        reranker_model_name=settings.document_reranker_model_name,
        timeout_seconds=settings.ai_timeout_seconds,
        temperature=settings.ai_temperature,
        max_output_tokens=settings.ai_max_output_tokens,
    )


def _auth_headers(api_key: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }


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
