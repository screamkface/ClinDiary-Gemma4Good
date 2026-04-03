from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


ProviderRole = Literal[
    "summary",
    "document_answer",
    "document_embedding",
    "document_reranker",
]
RuntimeMode = Literal["remote", "local"]


@dataclass(frozen=True, slots=True)
class ProviderCapability:
    role: ProviderRole
    provider_name: str
    supported_runtime_modes: tuple[RuntimeMode, ...] = ("remote",)
    planned_runtime_modes: tuple[RuntimeMode, ...] = ()
    notes: str | None = None


_CAPABILITIES: tuple[ProviderCapability, ...] = (
    ProviderCapability("summary", "rule_based", supported_runtime_modes=("remote", "local")),
    ProviderCapability("summary", "openai_compatible", supported_runtime_modes=("remote",)),
    ProviderCapability("summary", "regolo_ai", supported_runtime_modes=("remote",)),
    ProviderCapability("summary", "gemini_ai_studio", supported_runtime_modes=("remote",)),
    ProviderCapability(
        "summary",
        "gemma",
        supported_runtime_modes=("remote", "local"),
        notes="Gemma supports remote providers and backend-host local runtime adapters.",
    ),
    ProviderCapability("document_answer", "rule_based", supported_runtime_modes=("remote", "local")),
    ProviderCapability("document_answer", "regolo_ai", supported_runtime_modes=("remote",)),
    ProviderCapability(
        "document_answer",
        "gemma",
        supported_runtime_modes=("remote", "local"),
        notes="Gemma supports remote providers and backend-host local runtime adapters.",
    ),
    ProviderCapability("document_embedding", "rule_based", supported_runtime_modes=("remote", "local")),
    ProviderCapability("document_embedding", "regolo_ai", supported_runtime_modes=("remote",)),
    ProviderCapability(
        "document_embedding",
        "gemma",
        supported_runtime_modes=("remote", "local"),
        notes="EmbeddingGemma supports remote providers and backend-host local runtime adapters.",
    ),
    ProviderCapability("document_reranker", "rule_based", supported_runtime_modes=("remote", "local")),
    ProviderCapability("document_reranker", "regolo_ai", supported_runtime_modes=("remote",)),
)


def capability_matrix() -> tuple[ProviderCapability, ...]:
    return _CAPABILITIES


def get_provider_capability(role: ProviderRole, provider_name: str) -> ProviderCapability | None:
    normalized_provider = (provider_name or "").strip().lower()
    for item in _CAPABILITIES:
        if item.role == role and item.provider_name == normalized_provider:
            return item
    return None


def provider_supports_runtime(role: ProviderRole, provider_name: str, runtime_mode: str) -> bool:
    capability = get_provider_capability(role, provider_name)
    if capability is None:
        return False
    return runtime_mode in capability.supported_runtime_modes


def provider_plans_runtime(role: ProviderRole, provider_name: str, runtime_mode: str) -> bool:
    capability = get_provider_capability(role, provider_name)
    if capability is None:
        return False
    return runtime_mode in capability.planned_runtime_modes
