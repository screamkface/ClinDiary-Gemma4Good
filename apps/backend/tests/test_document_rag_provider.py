import json

import httpx

from app.ai.document_rag_provider import (
    build_document_answer_provider,
    build_document_embedding_provider,
    build_document_rag_provider,
    build_document_rerank_provider,
)
from app.ai.local_runtime_adapter import (
    LocalAiRuntimeUnavailableError,
    OllamaLocalDocumentEmbeddingRuntimeAdapter,
)
from app.core.config import Settings


def test_build_document_answer_provider_uses_local_gemma_runtime(monkeypatch):
    captured: dict[str, object] = {}

    class _Adapter:
        def answer_question(self, *, model_name, system_prompt, user_prompt, max_output_tokens):
            captured["model_name"] = model_name
            captured["system_prompt"] = system_prompt
            captured["user_prompt"] = user_prompt
            captured["max_output_tokens"] = max_output_tokens
            return "Risposta locale prudente [1]. Non sostituisce il medico."

    monkeypatch.setattr(
        "app.ai.document_rag_provider.build_local_document_answer_runtime_adapter",
        lambda settings: _Adapter(),
    )

    settings = Settings(
        ai_provider="gemma",
        document_answer_provider="gemma",
        document_answer_runtime_mode="local",
        local_llm_model_name="gemma-4-e2b",
        ai_max_output_tokens=400,
    )

    provider = build_document_answer_provider(settings)
    result = provider.answer_question(
        question="Cosa emerge dagli esami recenti?",
        context_blocks=["[1] Creatinina 1.4 mg/dL."],
    )

    assert provider.provider_name == "gemma"
    assert provider.model_name == "gemma-4-e2b"
    assert result.provider_name == "gemma"
    assert result.model_name == "gemma-4-e2b"
    assert "Risposta locale prudente" in result.answer
    assert captured["model_name"] == "gemma-4-e2b"
    assert captured["max_output_tokens"] == 1536
    assert "Non inventare dati" in captured["system_prompt"]


def test_build_document_answer_provider_falls_back_when_runtime_missing(monkeypatch):
    monkeypatch.setattr(
        "app.ai.document_rag_provider.build_local_document_answer_runtime_adapter",
        lambda settings: (_ for _ in ()).throw(LocalAiRuntimeUnavailableError("runtime offline")),
    )

    provider = build_document_answer_provider(
        Settings(
            ai_provider="gemma",
            document_answer_provider="gemma",
            document_answer_runtime_mode="local",
        )
    )

    assert provider.provider_name == "rule_based"


def test_build_document_embedding_provider_uses_local_gemma_runtime(monkeypatch):
    captured: dict[str, object] = {}

    class _Adapter:
        def embed_texts(self, *, model_name, texts, dimensions):
            captured["model_name"] = model_name
            captured["texts"] = texts
            captured["dimensions"] = dimensions
            return [[0.1, 0.2], [0.3, 0.4]]

    monkeypatch.setattr(
        "app.ai.document_rag_provider.build_local_document_embedding_runtime_adapter",
        lambda settings: _Adapter(),
    )

    settings = Settings(
        ai_provider="gemma",
        document_embedding_provider="gemma",
        document_embedding_runtime_mode="local",
        local_embedding_model_name="embeddinggemma",
        local_embedding_dimensions=768,
    )

    provider = build_document_embedding_provider(settings)
    result = provider.embed_texts(["nota 1", "nota 2"])

    assert provider.provider_name == "gemma"
    assert provider.model_name == "embeddinggemma"
    assert result == [[0.1, 0.2], [0.3, 0.4]]
    assert captured["model_name"] == "embeddinggemma"
    assert captured["texts"] == ["nota 1", "nota 2"]
    assert captured["dimensions"] == 768


def test_build_document_embedding_provider_falls_back_when_runtime_missing(monkeypatch):
    monkeypatch.setattr(
        "app.ai.document_rag_provider.build_local_document_embedding_runtime_adapter",
        lambda settings: (_ for _ in ()).throw(LocalAiRuntimeUnavailableError("runtime offline")),
    )

    provider = build_document_embedding_provider(
        Settings(
            ai_provider="gemma",
            document_embedding_provider="gemma",
            document_embedding_runtime_mode="local",
        )
    )

    assert provider.provider_name == "rule_based"


def test_build_document_rag_provider_uses_local_answer_and_embedding(monkeypatch):
    class _AnswerAdapter:
        def answer_question(self, *, model_name, system_prompt, user_prompt, max_output_tokens):
            return "Risposta locale prudente [1]."

    class _EmbeddingAdapter:
        def embed_texts(self, *, model_name, texts, dimensions):
            return [[1.0, 0.0], [0.0, 1.0]]

    monkeypatch.setattr(
        "app.ai.document_rag_provider.build_local_document_answer_runtime_adapter",
        lambda settings: _AnswerAdapter(),
    )
    monkeypatch.setattr(
        "app.ai.document_rag_provider.build_local_document_embedding_runtime_adapter",
        lambda settings: _EmbeddingAdapter(),
    )

    provider = build_document_rag_provider(
        Settings(
            ai_provider="gemma",
            document_answer_provider="gemma",
            document_answer_runtime_mode="local",
            document_embedding_provider="gemma",
            document_embedding_runtime_mode="local",
            local_llm_model_name="gemma-4-e2b",
            local_embedding_model_name="embeddinggemma",
        )
    )

    answer = provider.answer_question(
        question="Che cosa c e nei documenti?",
        context_blocks=["[1] Creatinina 1.4 mg/dL."],
    )

    assert provider.provider_name == "gemma"
    assert provider.answer_model_name == "gemma-4-e2b"
    assert provider.embedding_model_name == "embeddinggemma"
    assert provider.reranker_model_name is None
    assert answer.provider_name == "gemma"
    assert answer.embedding_model_name == "embeddinggemma"
    assert answer.reranker_model_name is None


def test_build_document_rerank_provider_forces_rule_based_when_remote_requested():
    provider = build_document_rerank_provider(
        Settings(
            document_reranker_provider="legacy_remote_reranker",
            document_reranker_base_url="https://example.invalid/v1",
            document_reranker_api_key="secret",
            document_reranker_model_name="remote-reranker-model",
        )
    )

    ranked = provider.rerank(
        query="funzione renale",
        documents=["doc A", "doc B"],
        top_n=2,
    )

    assert provider.provider_name == "rule_based"
    assert provider.model_name is None
    assert [item.index for item in ranked] == [0, 1]


def test_settings_default_document_embedding_dimensions():
    settings = Settings()

    assert settings.document_embedding_dimensions == 1024


def test_ollama_local_embedding_adapter_uses_embed_endpoint_and_retries_without_dimensions():
    requests: list[tuple[str, dict[str, object]]] = []

    def handler(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content.decode())
        requests.append((request.url.path, payload))
        if len(requests) == 1:
            return httpx.Response(
                422,
                json={"error": "dimensions not supported"},
            )
        return httpx.Response(
            200,
            json={
                "embeddings": [
                    [0.1, 0.2, 0.3],
                    [0.4, 0.5, 0.6],
                ]
            },
        )

    adapter = OllamaLocalDocumentEmbeddingRuntimeAdapter(
        base_url="http://127.0.0.1:11435",
        timeout_seconds=5,
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )

    result = adapter.embed_texts(
        model_name="embeddinggemma",
        texts=["nota 1", "nota 2"],
        dimensions=768,
    )

    assert result == [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]]
    assert requests[0][0] == "/api/embed"
    assert requests[0][1]["input"] == ["nota 1", "nota 2"]
    assert requests[0][1]["dimensions"] == 768
    assert requests[1][0] == "/api/embed"
    assert "dimensions" not in requests[1][1]
