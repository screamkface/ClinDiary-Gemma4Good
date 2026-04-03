import json

import httpx

from app.ai.document_rag_provider import RegoloDocumentRagProvider
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
