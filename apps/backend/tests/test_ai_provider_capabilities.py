from app.ai.provider_capabilities import (
    capability_matrix,
    get_provider_capability,
    provider_plans_runtime,
    provider_supports_runtime,
)


def test_capability_matrix_contains_gemma_paths():
    entries = capability_matrix()

    assert any(item.role == "summary" and item.provider_name == "gemma" for item in entries)
    assert any(item.role == "document_answer" and item.provider_name == "gemma" for item in entries)
    assert any(item.role == "document_embedding" and item.provider_name == "gemma" for item in entries)


def test_gemma_runtime_support_includes_local_paths():
    assert provider_supports_runtime("summary", "gemma", "remote") is False
    assert provider_supports_runtime("summary", "gemma", "local") is True
    assert provider_plans_runtime("summary", "gemma", "local") is False

    assert provider_supports_runtime("document_answer", "gemma", "remote") is False
    assert provider_supports_runtime("document_answer", "gemma", "local") is True
    assert provider_plans_runtime("document_answer", "gemma", "local") is False

    assert provider_supports_runtime("document_embedding", "gemma", "remote") is False
    assert provider_supports_runtime("document_embedding", "gemma", "local") is True
    assert provider_plans_runtime("document_embedding", "gemma", "local") is False


def test_rule_based_reranker_capability_is_explicit():
    capability = get_provider_capability("document_reranker", "rule_based")

    assert capability is not None
    assert capability.supported_runtime_modes == ("remote", "local")
