from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

import httpx

from app.core.config import Settings


class LocalAiRuntimeUnavailableError(RuntimeError):
    pass


class LocalSummaryRuntimeAdapter(Protocol):
    def generate_summary(
        self,
        *,
        model_name: str,
        system_prompt: str,
        user_prompt: str,
        max_output_tokens: int,
    ) -> str: ...


class LocalDocumentAnswerRuntimeAdapter(Protocol):
    def answer_question(
        self,
        *,
        model_name: str,
        system_prompt: str,
        user_prompt: str,
        max_output_tokens: int,
    ) -> str: ...


class LocalDocumentEmbeddingRuntimeAdapter(Protocol):
    def embed_texts(
        self,
        *,
        model_name: str,
        texts: list[str],
        dimensions: int | None = None,
    ) -> list[list[float] | None]: ...


@dataclass(slots=True)
class UnavailableLocalAiRuntimeAdapter:
    reason: str = "Local AI runtime adapter not configured"

    def generate_summary(
        self,
        *,
        model_name: str,
        system_prompt: str,
        user_prompt: str,
        max_output_tokens: int,
    ) -> str:
        raise LocalAiRuntimeUnavailableError(self.reason)

    def answer_question(
        self,
        *,
        model_name: str,
        system_prompt: str,
        user_prompt: str,
        max_output_tokens: int,
    ) -> str:
        raise LocalAiRuntimeUnavailableError(self.reason)

    def embed_texts(
        self,
        *,
        model_name: str,
        texts: list[str],
        dimensions: int | None = None,
    ) -> list[list[float] | None]:
        raise LocalAiRuntimeUnavailableError(self.reason)


class OllamaLocalSummaryRuntimeAdapter:
    def __init__(
        self,
        *,
        base_url: str,
        timeout_seconds: int,
        temperature: float,
        max_context_tokens: int,
        client: httpx.Client | None = None,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.temperature = temperature
        self.max_context_tokens = max_context_tokens
        self._client = client or httpx.Client(timeout=timeout_seconds)

    def generate_summary(
        self,
        *,
        model_name: str,
        system_prompt: str,
        user_prompt: str,
        max_output_tokens: int,
    ) -> str:
        response = self._client.post(
            f"{self.base_url}/api/chat",
            json={
                "model": model_name,
                "stream": False,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                "options": {
                    "temperature": self.temperature,
                    "num_predict": max_output_tokens,
                    "num_ctx": self.max_context_tokens,
                },
            },
        )
        response.raise_for_status()
        payload = response.json()
        message = payload.get("message")
        if isinstance(message, dict) and isinstance(message.get("content"), str):
            return message["content"].strip()
        content = payload.get("response")
        if isinstance(content, str):
            return content.strip()
        raise ValueError("Local Ollama runtime returned an empty summary")


class OpenAICompatibleLocalSummaryRuntimeAdapter:
    def __init__(
        self,
        *,
        base_url: str,
        timeout_seconds: int,
        temperature: float,
        client: httpx.Client | None = None,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.temperature = temperature
        self._client = client or httpx.Client(timeout=timeout_seconds)

    def generate_summary(
        self,
        *,
        model_name: str,
        system_prompt: str,
        user_prompt: str,
        max_output_tokens: int,
    ) -> str:
        response = self._client.post(
            f"{self.base_url}/chat/completions",
            json={
                "model": model_name,
                "temperature": self.temperature,
                "max_tokens": max_output_tokens,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
            },
        )
        response.raise_for_status()
        payload = response.json()
        choices = payload.get("choices") or []
        if not choices:
            raise ValueError("Local OpenAI-compatible runtime returned no choices")
        first = choices[0]
        if not isinstance(first, dict):
            raise ValueError("Local OpenAI-compatible runtime returned an invalid choice")
        message = first.get("message") or {}
        content = message.get("content")
        if isinstance(content, str):
            return content.strip()
        if isinstance(content, list):
            text_parts = []
            for item in content:
                if isinstance(item, dict) and item.get("type") == "text":
                    text_parts.append(str(item.get("text", "")))
            if text_parts:
                return "\n".join(part for part in text_parts if part).strip()
        raise ValueError("Local OpenAI-compatible runtime returned an empty summary")


class OllamaLocalDocumentAnswerRuntimeAdapter(OllamaLocalSummaryRuntimeAdapter):
    def answer_question(
        self,
        *,
        model_name: str,
        system_prompt: str,
        user_prompt: str,
        max_output_tokens: int,
    ) -> str:
        return self.generate_summary(
            model_name=model_name,
            system_prompt=system_prompt,
            user_prompt=user_prompt,
            max_output_tokens=max_output_tokens,
        )


class OpenAICompatibleLocalDocumentAnswerRuntimeAdapter(OpenAICompatibleLocalSummaryRuntimeAdapter):
    def answer_question(
        self,
        *,
        model_name: str,
        system_prompt: str,
        user_prompt: str,
        max_output_tokens: int,
    ) -> str:
        return self.generate_summary(
            model_name=model_name,
            system_prompt=system_prompt,
            user_prompt=user_prompt,
            max_output_tokens=max_output_tokens,
        )


class OllamaLocalDocumentEmbeddingRuntimeAdapter:
    def __init__(
        self,
        *,
        base_url: str,
        timeout_seconds: int,
        client: httpx.Client | None = None,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self._client = client or httpx.Client(timeout=timeout_seconds)

    def embed_texts(
        self,
        *,
        model_name: str,
        texts: list[str],
        dimensions: int | None = None,
    ) -> list[list[float] | None]:
        payload: dict[str, object] = {
            "model": model_name,
            "input": texts,
        }
        if dimensions is not None:
            payload["dimensions"] = dimensions

        response = self._client.post(
            f"{self.base_url}/api/embed",
            json=payload,
        )
        if dimensions is not None and _should_retry_embedding_without_dimensions(response):
            response = self._client.post(
                f"{self.base_url}/api/embed",
                json={
                    "model": model_name,
                    "input": texts,
                },
            )
        elif response.status_code == 404:
            return self._embed_texts_legacy(
                model_name=model_name,
                texts=texts,
                dimensions=dimensions,
            )

        response.raise_for_status()
        return _normalize_ollama_embeddings_response(
            response.json(),
            expected_count=len(texts),
        )

    def _embed_texts_legacy(
        self,
        *,
        model_name: str,
        texts: list[str],
        dimensions: int | None = None,
    ) -> list[list[float] | None]:
        embeddings: list[list[float] | None] = []
        for text in texts:
            payload: dict[str, object] = {
                "model": model_name,
                "prompt": text,
            }
            if dimensions is not None:
                payload["dimensions"] = dimensions
            response = self._client.post(
                f"{self.base_url}/api/embeddings",
                json=payload,
            )
            if dimensions is not None and _should_retry_embedding_without_dimensions(response):
                response = self._client.post(
                    f"{self.base_url}/api/embeddings",
                    json={
                        "model": model_name,
                        "prompt": text,
                    },
                )
            response.raise_for_status()
            embeddings.append(_normalize_embedding(response.json().get("embedding")))
        return embeddings


class OpenAICompatibleLocalDocumentEmbeddingRuntimeAdapter:
    def __init__(
        self,
        *,
        base_url: str,
        timeout_seconds: int,
        client: httpx.Client | None = None,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self._client = client or httpx.Client(timeout=timeout_seconds)

    def embed_texts(
        self,
        *,
        model_name: str,
        texts: list[str],
        dimensions: int | None = None,
    ) -> list[list[float] | None]:
        payload: dict[str, object] = {
            "model": model_name,
            "input": texts,
        }
        if dimensions is not None:
            payload["dimensions"] = dimensions
        with self._client as client:
            response = client.post(
                f"{self.base_url}/embeddings",
                json=payload,
            )
            if dimensions is not None and _should_retry_embedding_without_dimensions(response):
                response = client.post(
                    f"{self.base_url}/embeddings",
                    json={
                        "model": model_name,
                        "input": texts,
                    },
                )
        response.raise_for_status()
        response_payload = response.json()
        items = response_payload.get("data") or []
        embeddings_by_index: dict[int, list[float]] = {}
        for item in items:
            index = int(item.get("index", 0))
            embedding = item.get("embedding")
            if isinstance(embedding, list):
                embeddings_by_index[index] = [float(value) for value in embedding]
        return [embeddings_by_index.get(index) for index in range(len(texts))]


def build_local_summary_runtime_adapter(settings: Settings) -> LocalSummaryRuntimeAdapter:
    backend = (settings.local_llm_backend or "ollama").strip().lower()
    base_url = _resolve_local_llm_base_url(settings, backend)
    if not base_url:
        raise LocalAiRuntimeUnavailableError(
            "Local runtime selected but LOCAL_LLM_BASE_URL is missing for the chosen backend."
        )

    if backend == "ollama":
        return OllamaLocalSummaryRuntimeAdapter(
            base_url=base_url,
            timeout_seconds=settings.ai_timeout_seconds,
            temperature=settings.ai_temperature,
            max_context_tokens=settings.local_max_context_tokens,
        )

    if backend in {"openai_compatible", "llama_cpp", "vllm"}:
        return OpenAICompatibleLocalSummaryRuntimeAdapter(
            base_url=base_url,
            timeout_seconds=settings.ai_timeout_seconds,
            temperature=settings.ai_temperature,
        )

    raise LocalAiRuntimeUnavailableError(
        f"Unsupported local LLM backend: {backend}. Supported values: ollama, llama_cpp, vllm, openai_compatible."
    )


def build_local_document_answer_runtime_adapter(settings: Settings) -> LocalDocumentAnswerRuntimeAdapter:
    backend = (settings.local_llm_backend or "ollama").strip().lower()
    base_url = _resolve_local_llm_base_url(settings, backend)
    if not base_url:
        raise LocalAiRuntimeUnavailableError(
            "Local runtime selected but LOCAL_LLM_BASE_URL is missing for the chosen backend."
        )

    if backend == "ollama":
        return OllamaLocalDocumentAnswerRuntimeAdapter(
            base_url=base_url,
            timeout_seconds=settings.ai_timeout_seconds,
            temperature=settings.ai_temperature,
            max_context_tokens=settings.local_max_context_tokens,
        )

    if backend in {"openai_compatible", "llama_cpp", "vllm"}:
        return OpenAICompatibleLocalDocumentAnswerRuntimeAdapter(
            base_url=base_url,
            timeout_seconds=settings.ai_timeout_seconds,
            temperature=settings.ai_temperature,
        )

    raise LocalAiRuntimeUnavailableError(
        f"Unsupported local LLM backend: {backend}. Supported values: ollama, llama_cpp, vllm, openai_compatible."
    )


def build_local_document_embedding_runtime_adapter(
    settings: Settings,
) -> LocalDocumentEmbeddingRuntimeAdapter:
    backend = (settings.local_llm_backend or "ollama").strip().lower()
    base_url = _resolve_local_embedding_base_url(settings, backend)
    if not base_url:
        raise LocalAiRuntimeUnavailableError(
            "Local embedding runtime selected but LOCAL_LLM_BASE_URL is missing for the chosen backend."
        )

    if backend == "ollama":
        return OllamaLocalDocumentEmbeddingRuntimeAdapter(
            base_url=base_url,
            timeout_seconds=settings.ai_timeout_seconds,
        )

    if backend in {"openai_compatible", "llama_cpp", "vllm"}:
        return OpenAICompatibleLocalDocumentEmbeddingRuntimeAdapter(
            base_url=base_url,
            timeout_seconds=settings.ai_timeout_seconds,
        )

    raise LocalAiRuntimeUnavailableError(
        f"Unsupported local embedding backend: {backend}. Supported values: ollama, llama_cpp, vllm, openai_compatible."
    )


def _resolve_local_llm_base_url(settings: Settings, backend: str) -> str | None:
    configured = (settings.local_llm_base_url or "").strip()
    if configured:
        return configured
    if backend == "ollama":
        return "http://127.0.0.1:11434"
    if backend in {"openai_compatible", "llama_cpp", "vllm"}:
        return "http://127.0.0.1:8000/v1"
    return None


def _resolve_local_embedding_base_url(settings: Settings, backend: str) -> str | None:
    return _resolve_local_llm_base_url(settings, backend)


def _normalize_embedding(value: object) -> list[float] | None:
    if not isinstance(value, list):
        return None
    return [float(item) for item in value]


def _normalize_ollama_embeddings_response(
    payload: dict[str, object],
    *,
    expected_count: int,
) -> list[list[float] | None]:
    raw_embeddings = payload.get("embeddings")
    if isinstance(raw_embeddings, list):
        normalized: list[list[float] | None] = []
        for item in raw_embeddings:
            normalized.append(_normalize_embedding(item))
        if len(normalized) < expected_count:
            normalized.extend([None] * (expected_count - len(normalized)))
        return normalized[:expected_count]

    single_embedding = _normalize_embedding(payload.get("embedding"))
    if expected_count <= 1:
        return [single_embedding]
    return [single_embedding, *([None] * (expected_count - 1))]


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
