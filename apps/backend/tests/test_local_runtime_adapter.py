import json

import httpx

from app.ai.local_runtime_adapter import (
    OllamaLocalDocumentAnswerRuntimeAdapter,
    OllamaLocalDocumentEmbeddingRuntimeAdapter,
    OllamaLocalSummaryRuntimeAdapter,
    OpenAICompatibleLocalDocumentEmbeddingRuntimeAdapter,
    OpenAICompatibleLocalSummaryRuntimeAdapter,
    build_local_document_answer_runtime_adapter,
    build_local_document_embedding_runtime_adapter,
    build_local_summary_runtime_adapter,
)
from app.core.config import Settings


def test_ollama_local_summary_runtime_adapter_extracts_content():
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["json"] = json.loads(request.content.decode())
        return httpx.Response(
            200,
            json={
                "message": {
                    "content": "Sintesi locale Ollama prudente.",
                }
            },
        )

    adapter = OllamaLocalSummaryRuntimeAdapter(
        base_url="http://127.0.0.1:11434",
        timeout_seconds=5,
        temperature=0.1,
        max_context_tokens=8192,
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )

    result = adapter.generate_summary(
        model_name="gemma-local",
        system_prompt="Prompt di sistema",
        user_prompt="Prompt utente",
        max_output_tokens=1200,
    )

    assert result == "Sintesi locale Ollama prudente."
    assert captured["json"]["model"] == "gemma-local"
    assert captured["json"]["options"]["num_ctx"] == 8192


def test_openai_compatible_local_summary_runtime_adapter_extracts_content():
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["json"] = json.loads(request.content.decode())
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": "Sintesi locale compatibile OpenAI prudente.",
                        }
                    }
                ]
            },
        )

    adapter = OpenAICompatibleLocalSummaryRuntimeAdapter(
        base_url="http://127.0.0.1:8000/v1",
        timeout_seconds=5,
        temperature=0.1,
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )

    result = adapter.generate_summary(
        model_name="gemma-local",
        system_prompt="Prompt di sistema",
        user_prompt="Prompt utente",
        max_output_tokens=1200,
    )

    assert result == "Sintesi locale compatibile OpenAI prudente."
    assert captured["json"]["messages"][0]["content"] == "Prompt di sistema"


def test_build_local_summary_runtime_adapter_supports_ollama_defaults():
    settings = Settings(
        local_llm_backend="ollama",
    )

    adapter = build_local_summary_runtime_adapter(settings)

    assert isinstance(adapter, OllamaLocalSummaryRuntimeAdapter)


def test_build_local_summary_runtime_adapter_supports_llama_cpp_alias():
    settings = Settings(
        local_llm_backend="llama_cpp",
    )

    adapter = build_local_summary_runtime_adapter(settings)

    assert isinstance(adapter, OpenAICompatibleLocalSummaryRuntimeAdapter)


def test_ollama_local_document_answer_runtime_adapter_extracts_content():
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["json"] = json.loads(request.content.decode())
        return httpx.Response(
            200,
            json={
                "message": {
                    "content": "Risposta documentale locale Ollama prudente.",
                }
            },
        )

    adapter = OllamaLocalDocumentAnswerRuntimeAdapter(
        base_url="http://127.0.0.1:11434",
        timeout_seconds=5,
        temperature=0.1,
        max_context_tokens=8192,
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )

    result = adapter.answer_question(
        model_name="gemma-local",
        system_prompt="Sistema",
        user_prompt="Utente",
        max_output_tokens=1200,
    )

    assert result == "Risposta documentale locale Ollama prudente."
    assert captured["json"]["messages"][1]["content"] == "Utente"


def test_ollama_local_document_embedding_runtime_adapter_extracts_embeddings():
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["json"] = json.loads(request.content.decode())
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
        base_url="http://127.0.0.1:11434",
        timeout_seconds=5,
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )

    result = adapter.embed_texts(
        model_name="embeddinggemma-local",
        texts=["a", "b"],
        dimensions=768,
    )

    assert result == [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]]
    assert captured["json"]["model"] == "embeddinggemma-local"
    assert "dimensions" not in captured["json"]


def test_openai_compatible_local_document_embedding_runtime_adapter_retries_without_dimensions():
    requests: list[dict[str, object]] = []

    def handler(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content.decode())
        requests.append(payload)
        if len(requests) == 1:
            return httpx.Response(422, json={"detail": "dimensions not supported"})
        return httpx.Response(
            200,
            json={
                "data": [
                    {"index": 0, "embedding": [0.7, 0.8]},
                ]
            },
        )

    adapter = OpenAICompatibleLocalDocumentEmbeddingRuntimeAdapter(
        base_url="http://127.0.0.1:8000/v1",
        timeout_seconds=5,
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )

    result = adapter.embed_texts(
        model_name="embeddinggemma-local",
        texts=["ciao"],
        dimensions=512,
    )

    assert result == [[0.7, 0.8]]
    assert requests[0]["dimensions"] == 512
    assert "dimensions" not in requests[1]


def test_build_local_document_answer_runtime_adapter_supports_ollama_defaults():
    settings = Settings(
        local_llm_backend="ollama",
    )

    adapter = build_local_document_answer_runtime_adapter(settings)

    assert isinstance(adapter, OllamaLocalDocumentAnswerRuntimeAdapter)


def test_build_local_document_embedding_runtime_adapter_supports_llama_cpp_alias():
    settings = Settings(
        local_llm_backend="llama_cpp",
    )

    adapter = build_local_document_embedding_runtime_adapter(settings)

    assert isinstance(adapter, OpenAICompatibleLocalDocumentEmbeddingRuntimeAdapter)
