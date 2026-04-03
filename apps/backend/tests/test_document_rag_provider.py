import json

import httpx

from app.ai.document_rag_provider import (
    GemmaDocumentAnswerProvider,
    GemmaDocumentEmbeddingProvider,
    LocalRuntimeDocumentAnswerProvider,
    LocalRuntimeDocumentEmbeddingProvider,
    RegoloDocumentRagProvider,
    RegoloDocumentRerankProvider,
    RuleBasedDocumentRerankProvider,
    build_document_answer_provider,
    build_document_embedding_provider,
    build_document_rag_provider,
    build_document_rerank_provider,
)
from app.core.config import Settings


def test_regolo_document_rag_provider_sends_configured_embedding_dimensions():
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["json"] = json.loads(request.content.decode())
        return httpx.Response(
            200,
            json={
                "data": [
                    {
                        "index": 0,
                        "embedding": [0.1, 0.2, 0.3],
                    }
                ]
            },
        )

    provider = RegoloDocumentRagProvider(
        base_url="https://api.regolo.ai/v1",
        api_key="secret",
        answer_model_name="qwen3-8b",
        embedding_model_name="qwen3-embedding-8b",
        embedding_dimensions=1024,
        reranker_model_name="qwen3-reranker-4b",
        timeout_seconds=5,
        temperature=0.1,
        max_output_tokens=1200,
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )

    result = provider.embed_texts(["ciao"])

    assert result == [[0.1, 0.2, 0.3]]
    assert captured["json"]["dimensions"] == 1024


def test_regolo_document_rag_provider_retries_without_dimensions_when_unsupported():
    requests: list[dict[str, object]] = []

    def handler(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content.decode())
        requests.append(payload)
        if len(requests) == 1:
            return httpx.Response(
                422,
                json={"detail": "dimensions not supported for this model"},
            )
        return httpx.Response(
            200,
            json={
                "data": [
                    {
                        "index": 0,
                        "embedding": [0.5, 0.6],
                    }
                ]
            },
        )

    provider = RegoloDocumentRagProvider(
        base_url="https://api.regolo.ai/v1",
        api_key="secret",
        answer_model_name="qwen3-8b",
        embedding_model_name="qwen3-embedding-8b",
        embedding_dimensions=1024,
        reranker_model_name="qwen3-reranker-4b",
        timeout_seconds=5,
        temperature=0.1,
        max_output_tokens=1200,
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )

    result = provider.embed_texts(["ciao"])

    assert result == [[0.5, 0.6]]
    assert requests[0]["dimensions"] == 1024
    assert "dimensions" not in requests[1]
    assert provider._embedding_dimensions_enabled is False


def test_settings_default_document_embedding_dimensions():
    settings = Settings()

    assert settings.document_embedding_dimensions == 1024


def test_build_document_embedding_provider_supports_gemma():
    settings = Settings(
        document_embedding_provider="gemma",
        gemma_api_key="gemma-secret",
        gemma_base_url="https://gemma.example.com/v1",
    )

    provider = build_document_embedding_provider(settings)

    assert isinstance(provider, GemmaDocumentEmbeddingProvider)
    assert provider.model_name == "embeddinggemma"


def test_gemma_document_embedding_provider_uses_remote_embeddings_contract():
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["json"] = json.loads(request.content.decode())
        return httpx.Response(
            200,
            json={
                "data": [
                    {
                        "index": 0,
                        "embedding": [0.3, 0.4],
                    }
                ]
            },
        )

    provider = GemmaDocumentEmbeddingProvider(
        base_url="https://gemma.example.com/v1",
        api_key="secret",
        model_name="embeddinggemma",
        embedding_dimensions=768,
        timeout_seconds=5,
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )

    result = provider.embed_texts(["ciao"])

    assert result == [[0.3, 0.4]]
    assert captured["json"]["model"] == "embeddinggemma"
    assert captured["json"]["dimensions"] == 768


def test_build_document_embedding_provider_supports_local_gemma_runtime():
    settings = Settings(
        document_embedding_provider="gemma",
        document_embedding_runtime_mode="local",
        local_llm_backend="ollama",
        local_embedding_model_name="embeddinggemma-local",
        local_embedding_dimensions=768,
    )

    provider = build_document_embedding_provider(settings)

    assert isinstance(provider, LocalRuntimeDocumentEmbeddingProvider)
    assert provider.model_name == "embeddinggemma-local"
    assert provider.embedding_dimensions == 768


def test_build_document_answer_provider_supports_gemma():
    settings = Settings(
        document_answer_provider="gemma",
        gemma_api_key="gemma-secret",
        gemma_base_url="https://gemma.example.com/v1",
    )

    provider = build_document_answer_provider(settings)

    assert isinstance(provider, GemmaDocumentAnswerProvider)
    assert provider.model_name == "gemma-4"


def test_gemma_document_answer_provider_uses_remote_chat_contract():
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["json"] = json.loads(request.content.decode())
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": "Sintesi documentale Gemma [1]. Questa risposta non sostituisce il medico.",
                        }
                    }
                ]
            },
        )

    provider = GemmaDocumentAnswerProvider(
        base_url="https://gemma.example.com/v1",
        api_key="secret",
        model_name="gemma-4",
        timeout_seconds=5,
        temperature=0.1,
        max_output_tokens=1200,
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )

    result = provider.answer_question(
        question="Cosa emerge dal documento?",
        context_blocks=["[1] Documento: Referto | Tipo: lab_panel\nCreatinina 1.4 mg/dL"],
    )

    assert "Gemma" in result.answer
    assert captured["json"]["model"] == "gemma-4"
    assert captured["json"]["messages"][0]["content"].startswith("Sei ClinDiary.")


def test_build_document_answer_provider_supports_local_gemma_runtime():
    settings = Settings(
        document_answer_provider="gemma",
        document_answer_runtime_mode="local",
        local_llm_backend="ollama",
        local_llm_model_name="gemma-local",
    )

    provider = build_document_answer_provider(settings)

    assert isinstance(provider, LocalRuntimeDocumentAnswerProvider)
    assert provider.model_name == "gemma-local"


def test_build_document_rerank_provider_supports_regolo():
    settings = Settings(
        document_reranker_provider="regolo_ai",
        regolo_api_key="regolo-secret",
        regolo_base_url="https://api.regolo.ai/v1",
    )

    provider = build_document_rerank_provider(settings)

    assert isinstance(provider, RegoloDocumentRerankProvider)
    assert provider.model_name == "qwen3-reranker-4b"


def test_build_document_rerank_provider_falls_back_when_unsupported():
    settings = Settings(
        document_reranker_provider="gemma",
        gemma_api_key="gemma-secret",
        gemma_base_url="https://gemma.example.com/v1",
    )

    provider = build_document_rerank_provider(settings)

    assert isinstance(provider, RuleBasedDocumentRerankProvider)


def test_build_document_rag_provider_supports_gemma_answer_with_rule_based_rerank_fallback():
    settings = Settings(
        document_answer_provider="gemma",
        gemma_api_key="gemma-secret",
        gemma_base_url="https://gemma.example.com/v1",
    )

    provider = build_document_rag_provider(settings)

    assert provider.provider_name == "gemma"
    assert provider.answer_model_name == "gemma-4"
    assert provider.reranker_model_name is None
