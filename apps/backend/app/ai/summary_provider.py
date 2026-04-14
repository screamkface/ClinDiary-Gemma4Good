from __future__ import annotations

from dataclasses import dataclass
from datetime import date
import json
from typing import Any, Protocol

import httpx

from app.core.config import Settings
from app.core.logging import logger
from app.core.metrics import get_metrics_registry
from app.ai.local_runtime_adapter import (
    LocalAiRuntimeUnavailableError,
    LocalSummaryRuntimeAdapter,
    build_local_summary_runtime_adapter,
)


@dataclass(slots=True)
class SummaryGenerationInput:
    summary_type: str
    summary_label: str
    period_start: date
    period_end: date
    data_considered: list[str]
    patient_snapshot: list[str]
    active_conditions: list[str]
    allergies: list[str]
    family_history: list[str]
    medications: list[str]
    medication_adherence: list[str]
    wearable_daily_summaries: list[str]
    journal_entries: list[dict[str, Any]]
    observations: list[str]
    recent_lab_results: list[str]
    recent_imaging_reports: list[str]
    recent_documents: list[str]
    prior_daily_summaries: list[str]
    open_alerts: list[str]
    follow_up_reasons: list[str]
    missing_data: list[str]
    device_measurement_summaries: list[str] | None = None
    clinical_episodes: list[str] | None = None


@dataclass(slots=True)
class SummaryGenerationResult:
    content: str
    provider_name: str
    model_name: str
    used_fallback: bool = False


@dataclass(slots=True)
class SummaryProviderOverride:
    provider_name: str | None = None
    runtime_mode: str | None = None
    model_name: str | None = None
    response_provider_name: str | None = None


class SummaryProvider(Protocol):
    provider_name: str
    model_name: str

    def generate_result(self, payload: SummaryGenerationInput) -> SummaryGenerationResult: ...

    def generate(self, payload: SummaryGenerationInput) -> str: ...


class RuleBasedSummaryProvider:
    provider_name = "rule_based"
    model_name = "clindiary-safe-summary"

    def generate_result(self, payload: SummaryGenerationInput) -> SummaryGenerationResult:
        lines = [
            f"Periodo analizzato: dal {payload.period_start.isoformat()} al {payload.period_end.isoformat()}.",
            (
                "Dati considerati: "
                + (
                    ", ".join(payload.data_considered)
                    if payload.data_considered
                    else "nessun dato clinico disponibile nel periodo."
                )
            ),
        ]

        if payload.patient_snapshot:
            lines.append("Contesto paziente:")
            lines.extend(f"- {item}" for item in payload.patient_snapshot)

        if payload.active_conditions:
            lines.append("Condizioni attive/familiarita rilevate:")
            lines.extend(f"- {item}" for item in [*payload.active_conditions, *payload.family_history][:6])

        if payload.allergies:
            lines.append("Allergie note:")
            lines.extend(f"- {item}" for item in payload.allergies[:4])

        if payload.observations:
            lines.append("Elementi principali osservati:")
            lines.extend(f"- {item}" for item in payload.observations[:8])
        else:
            lines.append("Elementi principali osservati:")
            lines.append("- Nel periodo selezionato i dati sono limitati e il riepilogo resta soprattutto organizzativo.")

        journal_preview = payload.journal_entries[-3:]
        if journal_preview:
            lines.append("Storico giornaliero recente considerato:")
            lines.extend(f"- {_journal_entry_line(item)}" for item in journal_preview)

        if payload.medications:
            lines.append("Terapie attive:")
            lines.extend(f"- {item}" for item in payload.medications[:6])

        if payload.medication_adherence:
            lines.append("Aderenza registrata nel periodo:")
            lines.extend(f"- {item}" for item in payload.medication_adherence[:5])

        if payload.wearable_daily_summaries:
            lines.append("Dati wearable recenti considerati:")
            lines.extend(f"- {item}" for item in payload.wearable_daily_summaries[:7])

        if payload.device_measurement_summaries:
            lines.append("Misure recenti da dispositivi clinici collegati:")
            lines.extend(f"- {item}" for item in payload.device_measurement_summaries[:8])

        if payload.prior_daily_summaries:
            lines.append("Contesto da recap giornalieri precedenti:")
            lines.extend(f"- {item}" for item in payload.prior_daily_summaries[:4])

        if payload.clinical_episodes:
            lines.append("Problemi/episodi clinici:")
            lines.extend(f"- {item}" for item in payload.clinical_episodes[:6])

        if payload.recent_lab_results or payload.recent_imaging_reports or payload.recent_documents:
            lines.append("Documenti ed esami recenti considerati:")
            lines.extend(f"- {item}" for item in payload.recent_lab_results[:5])
            lines.extend(f"- {item}" for item in payload.recent_imaging_reports[:3])
            lines.extend(f"- {item}" for item in payload.recent_documents[:4])

        if _is_pre_visit_summary(payload):
            lines.append("Preparazione visita:")
            lines.append("- Porta i documenti ed esami recenti piu rilevanti.")
            if payload.follow_up_reasons:
                lines.append("Domande utili da portare in visita:")
                lines.extend(f"- {item}" for item in payload.follow_up_reasons[:4])
            if payload.open_alerts:
                lines.append("Segnali da ricordare prima della visita:")
                lines.extend(
                    f"- Alert deterministico aperto: {item}"
                    for item in payload.open_alerts[:4]
                )
            lines.append(
                "Porta il riepilogo, i referti recenti e segnala eventuali peggioramenti o nuovi sintomi prima dell'appuntamento."
            )

        if payload.open_alerts or payload.follow_up_reasons:
            lines.append("Quando parlarne con il medico:")
            if payload.open_alerts:
                lines.extend(f"- Alert deterministico aperto: {item}" for item in payload.open_alerts[:4])
            lines.extend(f"- {item}" for item in payload.follow_up_reasons[:6])
        else:
            lines.append("Quando parlarne con il medico:")
            lines.append(
                "- Porta questo riepilogo al medico se i sintomi persistono, peggiorano o compaiono nuovi segnali rilevanti."
            )

        if payload.missing_data:
            lines.append("Dati mancanti o limitati:")
            lines.extend(f"- {item}" for item in payload.missing_data[:4])

        lines.append(
            "Questa sintesi ha finalita organizzativa: non e una diagnosi, non prescrive terapie e non sostituisce una valutazione medica."
        )
        return SummaryGenerationResult(
            content="\n".join(lines),
            provider_name=self.provider_name,
            model_name=self.model_name,
        )

    def generate(self, payload: SummaryGenerationInput) -> str:
        return self.generate_result(payload).content


class OpenAICompatibleSummaryProvider:
    provider_name = "openai_compatible"

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
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.model_name = model_name
        self.temperature = temperature
        self.max_output_tokens = max_output_tokens
        self._client = client or httpx.Client(timeout=timeout_seconds)

    def generate_result(self, payload: SummaryGenerationInput) -> SummaryGenerationResult:
        max_output_tokens = _effective_output_token_budget(
            payload.summary_type,
            self.max_output_tokens,
        )
        response = self._client.post(
            f"{self.base_url}/chat/completions",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": self.model_name,
                "temperature": self.temperature,
                "max_tokens": max_output_tokens,
                "messages": [
                    {
                        "role": "system",
                        "content": _system_prompt(),
                    },
                    {
                        "role": "user",
                        "content": _user_prompt(payload),
                    },
                ],
            },
        )
        response.raise_for_status()
        content = _extract_openai_message_content(response.json())
        if not content:
            raise ValueError("AI provider returned an empty summary")
        return SummaryGenerationResult(
            content=content.strip(),
            provider_name=self.provider_name,
            model_name=self.model_name,
        )

    def generate(self, payload: SummaryGenerationInput) -> str:
        return self.generate_result(payload).content


class RegoloAiSummaryProvider(OpenAICompatibleSummaryProvider):
    provider_name = "regolo_ai"


class GemmaSummaryProvider(OpenAICompatibleSummaryProvider):
    provider_name = "gemma"


class LocalRuntimeSummaryProvider:
    def __init__(
        self,
        *,
        model_name: str,
        adapter: LocalSummaryRuntimeAdapter,
        max_output_tokens: int,
        provider_name: str = "gemma",
    ) -> None:
        self.provider_name = provider_name
        self.model_name = model_name
        self._adapter = adapter
        self.max_output_tokens = max_output_tokens

    def generate_result(self, payload: SummaryGenerationInput) -> SummaryGenerationResult:
        max_output_tokens = _effective_output_token_budget(
            payload.summary_type,
            self.max_output_tokens,
        )
        content = self._adapter.generate_summary(
            model_name=self.model_name,
            system_prompt=_system_prompt(),
            user_prompt=_user_prompt(payload),
            max_output_tokens=max_output_tokens,
        )
        if not content:
            raise ValueError("Local runtime returned an empty summary")
        return SummaryGenerationResult(
            content=content.strip(),
            provider_name=self.provider_name,
            model_name=self.model_name,
        )

    def generate(self, payload: SummaryGenerationInput) -> str:
        return self.generate_result(payload).content


class GeminiAiStudioSummaryProvider:
    provider_name = "gemini_ai_studio"

    def __init__(
        self,
        *,
        api_key: str,
        model_name: str,
        timeout_seconds: int,
        temperature: float,
        max_output_tokens: int,
        thinking_budget: int | None = 0,
        base_url: str = "https://generativelanguage.googleapis.com/v1beta",
        client: httpx.Client | None = None,
    ) -> None:
        self.api_key = api_key
        self.model_name = model_name
        self.temperature = temperature
        self.max_output_tokens = max_output_tokens
        self.thinking_budget = thinking_budget
        self.base_url = base_url.rstrip("/")
        self._client = client or httpx.Client(timeout=timeout_seconds)

    def generate_result(self, payload: SummaryGenerationInput) -> SummaryGenerationResult:
        max_output_tokens = _effective_output_token_budget(
            payload.summary_type,
            self.max_output_tokens,
        )
        generation_config: dict[str, Any] = {
            "temperature": self.temperature,
            "maxOutputTokens": max_output_tokens,
        }
        if self.thinking_budget is not None:
            generation_config["thinkingConfig"] = {
                "thinkingBudget": self.thinking_budget,
            }

        response = self._client.post(
            f"{self.base_url}/models/{self.model_name}:generateContent",
            headers={
                "x-goog-api-key": self.api_key,
                "Content-Type": "application/json",
            },
            json={
                "contents": [
                    {
                        "parts": [
                            {
                                "text": f"{_system_prompt()}\n\n{_user_prompt(payload)}",
                            }
                        ]
                    }
                ],
                "generationConfig": generation_config,
            },
        )
        response.raise_for_status()
        response_payload = response.json()
        finish_reason = _extract_gemini_finish_reason(response_payload)
        content = _extract_gemini_message_content(response_payload)
        if not content:
            raise ValueError("Gemini provider returned an empty summary")
        if finish_reason == "MAX_TOKENS":
            raise ValueError("Gemini provider response was truncated by max tokens")
        return SummaryGenerationResult(
            content=content.strip(),
            provider_name=self.provider_name,
            model_name=self.model_name,
        )

    def generate(self, payload: SummaryGenerationInput) -> str:
        return self.generate_result(payload).content


class ResilientSummaryProvider:
    def __init__(
        self,
        *,
        primary: SummaryProvider,
        fallback: SummaryProvider,
    ) -> None:
        self.primary = primary
        self.fallback = fallback
        self.provider_name = primary.provider_name
        self.model_name = primary.model_name

    def generate_result(self, payload: SummaryGenerationInput) -> SummaryGenerationResult:
        metrics = get_metrics_registry()
        try:
            result = self.primary.generate_result(payload)
            logger.info(
                "ai.summary_provider_success",
                provider=self.primary.provider_name,
                model_name=self.primary.model_name,
            )
            metrics.record_ai_summary(
                provider=result.provider_name,
                model_name=result.model_name,
                outcome="success",
                used_fallback=False,
            )
            return result
        except Exception as exc:
            logger.warning(
                "ai.summary_provider_fallback",
                provider=self.primary.provider_name,
                model_name=self.primary.model_name,
                error=str(exc),
            )
            logger.info(
                "ai.summary_provider_success",
                provider=self.fallback.provider_name,
                model_name=self.fallback.model_name,
                fallback_from=self.primary.provider_name,
            )
            metrics.record_ai_summary(
                provider=self.primary.provider_name,
                model_name=self.primary.model_name,
                outcome="fallback_triggered",
                used_fallback=True,
            )
            metrics.record_ai_summary_fallback(
                from_provider=self.primary.provider_name,
                to_provider=self.fallback.provider_name,
            )
            fallback_result = self.fallback.generate_result(payload)
            metrics.record_ai_summary(
                provider=fallback_result.provider_name,
                model_name=fallback_result.model_name,
                outcome="success",
                used_fallback=True,
            )
            return SummaryGenerationResult(
                content=fallback_result.content,
                provider_name=fallback_result.provider_name,
                model_name=fallback_result.model_name,
                used_fallback=True,
            )

    def generate(self, payload: SummaryGenerationInput) -> str:
        return self.generate_result(payload).content


def build_summary_prompts(payload: SummaryGenerationInput) -> tuple[str, str]:
    return _system_prompt(), _user_prompt(payload)


def build_summary_provider(
    settings: Settings,
    *,
    allow_external_provider: bool = True,
    override: SummaryProviderOverride | None = None,
) -> SummaryProvider:
    provider = _resolve_summary_provider_name(settings, override)
    fallback = RuleBasedSummaryProvider()
    metrics = get_metrics_registry()
    runtime_mode = _normalize_runtime_mode(
        override.runtime_mode if override is not None else settings.summary_ai_runtime_mode
    )
    resolved_model_name = _resolve_summary_model_name(settings, provider, fallback, override)
    response_provider_name = _resolve_response_provider_name(
        settings,
        provider,
        override,
    )

    if not allow_external_provider:
        logger.info(
            "ai.external_provider_disabled_by_user",
            provider=provider,
        )
        metrics.record_ai_summary(
            provider=provider or fallback.provider_name,
            model_name=getattr(fallback, "model_name", "unknown"),
            outcome="external_provider_disabled",
            used_fallback=True,
        )
        return fallback

    if provider == "gemma" and runtime_mode == "local":
        try:
            adapter = build_local_summary_runtime_adapter(settings)
        except LocalAiRuntimeUnavailableError as exc:
            logger.warning(
                "ai.provider_config_missing",
                provider=response_provider_name,
                runtime_mode=runtime_mode,
                error=str(exc),
            )
            metrics.record_ai_summary(
                provider=response_provider_name,
                model_name=resolved_model_name,
                outcome="config_missing",
                used_fallback=True,
            )
            return fallback

        return ResilientSummaryProvider(
            primary=LocalRuntimeSummaryProvider(
                model_name=resolved_model_name,
                adapter=adapter,
                max_output_tokens=settings.ai_max_output_tokens,
                provider_name=response_provider_name,
            ),
            fallback=fallback,
        )

    if provider in {"openai", "openai_compatible"}:
        base_url = settings.summary_ai_base_url or settings.ai_base_url
        api_key = settings.summary_ai_api_key or settings.ai_api_key
        if not base_url or not api_key:
            logger.warning(
                "ai.provider_config_missing",
                provider=provider,
                ai_base_url=bool(base_url),
                ai_api_key=bool(api_key),
            )
            metrics.record_ai_summary(
                provider=provider,
                model_name=resolved_model_name,
                outcome="config_missing",
                used_fallback=True,
            )
            return fallback

        return ResilientSummaryProvider(
            primary=OpenAICompatibleSummaryProvider(
                base_url=base_url,
                api_key=api_key,
                model_name=resolved_model_name,
                timeout_seconds=settings.ai_timeout_seconds,
                temperature=settings.ai_temperature,
                max_output_tokens=settings.ai_max_output_tokens,
            ),
            fallback=fallback,
        )

    if provider in {"regolo", "regolo_ai"}:
        api_key = settings.summary_ai_api_key or settings.regolo_api_key or settings.ai_api_key
        if not api_key:
            logger.warning(
                "ai.provider_config_missing",
                provider=provider,
                regolo_api_key=bool(settings.regolo_api_key),
                ai_api_key=bool(settings.ai_api_key),
                summary_ai_api_key=bool(settings.summary_ai_api_key),
            )
            metrics.record_ai_summary(
                provider=provider,
                model_name=resolved_model_name,
                outcome="config_missing",
                used_fallback=True,
            )
            return fallback

        base_url = (
            settings.summary_ai_base_url
            or settings.regolo_base_url
            or settings.ai_base_url
            or "https://api.regolo.ai/v1"
        )
        return ResilientSummaryProvider(
            primary=RegoloAiSummaryProvider(
                base_url=base_url,
                api_key=api_key,
                model_name=resolved_model_name,
                timeout_seconds=settings.ai_timeout_seconds,
                temperature=settings.ai_temperature,
                max_output_tokens=settings.ai_max_output_tokens,
            ),
            fallback=fallback,
        )

    if provider == "gemma":
        api_key = settings.summary_ai_api_key or settings.gemma_api_key or settings.ai_api_key
        base_url = settings.summary_ai_base_url or settings.gemma_base_url or settings.ai_base_url
        if not api_key or not base_url:
            logger.warning(
                "ai.provider_config_missing",
                provider=provider,
                gemma_api_key=bool(settings.gemma_api_key),
                ai_api_key=bool(settings.ai_api_key),
                summary_ai_api_key=bool(settings.summary_ai_api_key),
                gemma_base_url=bool(settings.gemma_base_url),
                ai_base_url=bool(settings.ai_base_url),
                summary_ai_base_url=bool(settings.summary_ai_base_url),
            )
            metrics.record_ai_summary(
                provider=provider,
                model_name=resolved_model_name,
                outcome="config_missing",
                used_fallback=True,
            )
            return fallback

        return ResilientSummaryProvider(
            primary=GemmaSummaryProvider(
                base_url=base_url,
                api_key=api_key,
                model_name=resolved_model_name,
                timeout_seconds=settings.ai_timeout_seconds,
                temperature=settings.ai_temperature,
                max_output_tokens=settings.ai_max_output_tokens,
            ),
            fallback=fallback,
        )

    if provider in {"gemini", "gemini_ai_studio", "google_ai_studio"}:
        api_key = settings.gemini_api_key or settings.ai_api_key
        if not api_key:
            logger.warning(
                "ai.provider_config_missing",
                provider=provider,
                gemini_api_key=bool(settings.gemini_api_key),
                ai_api_key=bool(settings.ai_api_key),
            )
            metrics.record_ai_summary(
                provider=provider,
                model_name=resolved_model_name,
                outcome="config_missing",
                used_fallback=True,
            )
            return fallback

        base_url = (
            settings.summary_ai_base_url
            or settings.ai_base_url
            or "https://generativelanguage.googleapis.com/v1beta"
        )
        return ResilientSummaryProvider(
            primary=GeminiAiStudioSummaryProvider(
                api_key=api_key,
                model_name=resolved_model_name,
                base_url=base_url,
                timeout_seconds=settings.ai_timeout_seconds,
                temperature=settings.ai_temperature,
                max_output_tokens=settings.ai_max_output_tokens,
                thinking_budget=settings.gemini_thinking_budget,
            ),
            fallback=fallback,
        )

    return fallback


def _resolve_summary_provider_name(
    settings: Settings,
    override: SummaryProviderOverride | None = None,
) -> str:
    configured = (
        (override.provider_name if override is not None else None)
        or settings.summary_ai_provider
        or settings.ai_provider
        or "rule_based"
    )
    normalized = configured.strip().lower()
    aliases = {
        "openai": "openai_compatible",
        "regolo": "regolo_ai",
        "google_ai_studio": "gemini_ai_studio",
        "gemma_remote": "gemma",
        "local_gemma4": "gemma",
    }
    return aliases.get(normalized, normalized or "rule_based")


def _resolve_response_provider_name(
    settings: Settings,
    provider: str,
    override: SummaryProviderOverride | None = None,
) -> str:
    if override is not None and override.response_provider_name:
        return override.response_provider_name.strip()

    configured = override.provider_name if override is not None else None
    configured = configured or settings.summary_ai_provider or settings.ai_provider or provider
    normalized = configured.strip().lower()
    if normalized == "local_gemma4":
        return "local_gemma4"
    return provider


def _resolve_summary_model_name(
    settings: Settings,
    provider: str,
    fallback: RuleBasedSummaryProvider,
    override: SummaryProviderOverride | None = None,
) -> str:
    if override is not None and override.model_name and override.model_name.strip():
        return override.model_name.strip()

    if settings.summary_ai_model_name and settings.summary_ai_model_name.strip():
        return settings.summary_ai_model_name.strip()

    if provider in {"regolo", "regolo_ai"}:
        configured_model = (settings.regolo_model_name or "").strip()
        if not configured_model:
            configured_model = (settings.ai_model_name or "").strip()
        return _normalize_regolo_model_name(configured_model)

    if provider == "gemma":
        configured_local_model = (settings.local_llm_model_name or "").strip()
        runtime_mode = _normalize_runtime_mode(
            override.runtime_mode if override is not None else settings.summary_ai_runtime_mode
        )
        if runtime_mode == "local" and configured_local_model:
            return configured_local_model
        configured_model = (settings.ai_model_name or "").strip()
        if configured_model and configured_model != fallback.model_name:
            return configured_model
        return "gemma-4"

    if provider in {"gemini", "gemini_ai_studio", "google_ai_studio"}:
        configured_model = (settings.ai_model_name or "").strip()
        if configured_model and configured_model != fallback.model_name:
            return configured_model
        return "gemini-2.5-flash"

    configured_model = (settings.ai_model_name or "").strip()
    return configured_model or fallback.model_name


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
    normalized = model_name.strip()
    aliases = {
        "minimax-m2.5-d": "minimax-m2.5",
        "minimax-m2.5-draft": "minimax-m2.5",
    }
    return aliases.get(normalized.lower(), normalized or "minimax-m2.5")


def _effective_output_token_budget(summary_type: str, configured_max_tokens: int) -> int:
    normalized = (summary_type or "").strip().lower()
    minimum_by_type = {
        "daily": 1024,
        "weekly": 2048,
        "monthly": 3072,
        "pre_visit": 3072,
        "pre-visit": 3072,
    }
    minimum = minimum_by_type.get(normalized, 1536)
    return max(configured_max_tokens, minimum)


def _is_pre_visit_summary(payload: SummaryGenerationInput) -> bool:
    normalized_type = payload.summary_type.strip().lower()
    normalized_label = payload.summary_label.strip().lower()
    return (
        normalized_type in {"pre_visit", "pre-visit"}
        or "pre-visita" in normalized_label
        or "pre visit" in normalized_label
    )


def _system_prompt() -> str:
    return (
        "Segui rigorosamente le istruzioni dell'utente. "
        "Usa esclusivamente i dati presenti nel payload JSON senza aggiungere informazioni esterne."
    )


def _user_prompt(payload: SummaryGenerationInput) -> str:
    serialized = json.dumps(
        {
            "summary_type": payload.summary_type,
            "summary_label": payload.summary_label,
            "period_start": payload.period_start.isoformat(),
            "period_end": payload.period_end.isoformat(),
            "data_considered": payload.data_considered,
            "patient_snapshot": payload.patient_snapshot,
            "active_conditions": payload.active_conditions,
            "allergies": payload.allergies,
            "family_history": payload.family_history,
            "medications": payload.medications,
            "medication_adherence": payload.medication_adherence,
            "wearable_daily_summaries": payload.wearable_daily_summaries,
            "device_measurement_summaries": payload.device_measurement_summaries,
            "journal_entries": payload.journal_entries,
            "observations": payload.observations,
            "recent_lab_results": payload.recent_lab_results,
            "recent_imaging_reports": payload.recent_imaging_reports,
            "recent_documents": payload.recent_documents,
            "prior_daily_summaries": payload.prior_daily_summaries,
            "clinical_episodes": payload.clinical_episodes,
            "open_alerts": payload.open_alerts,
            "follow_up_reasons": payload.follow_up_reasons,
            "missing_data": payload.missing_data,
        },
        ensure_ascii=True,
        separators=(",", ":"),
    )
    return (
        "Genera un riepilogo clinico prudente usando ESCLUSIVAMENTE i dati presenti nel payload JSON.\n\n"
        "OBIETTIVO\n"
        "Produrre un riepilogo chiaro, prudente e utile per il paziente e per il medico, evidenziando:\n"
        "- andamento temporale dei sintomi e dei parametri\n"
        "- eventuali pattern o correlazioni osservabili nei dati\n"
        "- esami o documenti recenti rilevanti\n"
        "- condizioni in cui e opportuno parlare con il medico\n\n"
        "VINCOLI GENERALI\n"
        "- Non inventare dati mancanti\n"
        "- Non formulare diagnosi\n"
        "- Non formulare prescrizioni\n"
        "- Non attribuire cause certe\n"
        "- Non usare linguaggio allarmistico\n"
        "- Se un dato non e presente o non e sufficiente, dichiararlo esplicitamente\n"
        "- Se esistono alert aperti, riportali fedelmente senza reinterpretarli\n"
        "- Se esistono valori di laboratorio fuori range, riportali come dati da discutere con il medico, senza spiegazioni diagnostiche\n"
        "- Le correlazioni devono essere descritte solo come osservazioni nei dati, non come causalita\n\n"
        "ISTRUZIONI DI ANALISI\n"
        "Prima di scrivere il riepilogo:\n"
        "1. identifica il periodo coperto dai dati\n"
        "2. identifica il contesto del paziente disponibile nel payload:\n"
        "   - eta\n"
        "   - sesso\n"
        "   - patologie note\n"
        "   - farmaci attivi\n"
        "   - anamnesi rilevante\n"
        "3. analizza l'andamento temporale dei sintomi:\n"
        "   - frequenza\n"
        "   - intensita\n"
        "   - persistenza\n"
        "   - miglioramento o peggioramento\n"
        "4. analizza i parametri registrati:\n"
        "   - sonno\n"
        "   - temperatura\n"
        "   - pressione\n"
        "   - glicemia\n"
        "   - saturazione\n"
        "   - battito\n"
        "   - peso\n"
        "   - misure da dispositivi clinici collegati quando presenti\n"
        "   - altri valori presenti\n"
        "5. verifica se nei dati sono osservabili associazioni temporali deboli o pattern ricorrenti, ad esempio:\n"
        "   - sintomi piu frequenti nei giorni con poco sonno\n"
        "   - peggioramento in presenza di febbre\n"
        "   - sintomi ricorrenti in certi orari o periodi\n"
        "   - cambiamenti dopo inizio/sospensione farmaci\n"
        "   - variazioni concomitanti tra sintomi e parametri\n"
        "6. considera esami e documenti recenti\n"
        "7. considera eventuali recap giornalieri gia disponibili dei 15 giorni precedenti\n"
        "8. considera alert aperti\n"
        "9. valuta se il quadro suggerisce opportunita di confronto medico, senza fare triage aggressivo se i dati non lo supportano\n\n"
        + (
            "ISTRUZIONI AGGIUNTIVE PER PRE-VISITA\n"
            "- Scrivi una scheda pronta da portare alla visita medica\n"
            "- Evidenzia i punti da discutere e i documenti utili\n"
            "- Includi domande pratiche da fare al medico\n"
            "- Termina con una breve checklist di cose da monitorare prima dell'appuntamento\n\n"
            if _is_pre_visit_summary(payload)
            else ""
        )
        + "REGOLE SULLE CORRELAZIONI\n"
        "- Riporta una correlazione solo se emerge da dati ripetuti o chiaramente osservabili nel periodo\n"
        "- Se il pattern e debole o incerto, usa formule come:\n"
        "  - \"si osserva una possibile associazione temporale\"\n"
        "  - \"nei dati disponibili sembra comparire piu spesso\"\n"
        "  - \"il pattern non e sufficiente per trarre conclusioni\"\n"
        "- Non usare formule causali come:\n"
        "  - \"e causato da\"\n"
        "  - \"dipende da\"\n"
        "  - \"indica che ha\"\n\n"
        "STRUTTURA OBBLIGATORIA DEL RISULTATO\n\n"
        "1. Periodo considerato e contesto del paziente\n"
        "- specifica intervallo temporale analizzato\n"
        "- riporta solo il contesto clinico presente nel payload\n\n"
        "2. Andamento osservato nel diario e nei dati registrati\n"
        "- descrivi sintomi principali\n"
        "- descrivi andamento nel tempo\n"
        "- evidenzia eventuali pattern o correlazioni osservabili\n"
        "- separa chiaramente:\n"
        "  - osservazioni solide\n"
        "  - possibili associazioni\n"
        "  - limiti dei dati\n\n"
        "3. Esami/documenti recenti rilevanti\n"
        "- riporta esami e documenti recenti\n"
        "- se ci sono valori fuori range, riportali in modo neutro come elementi da discutere con il medico\n"
        "- non interpretarli in chiave diagnostica\n\n"
        "4. Quando e perche parlare con il medico\n"
        "- indica in modo calmo ma esplicito quando e utile un confronto medico\n"
        "- usa il contenuto dei dati disponibili\n"
        "- se sono presenti alert aperti, riportali fedelmente qui o in una sottosezione dedicata\n"
        "- se i dati mostrano persistenza, peggioramento, ricorrenza o combinazioni meritevoli di attenzione, dillo con prudenza\n\n"
        "5. Chiusura che ricorda esplicitamente che il testo non e una diagnosi o prescrizione\n"
        "- chiudi sempre con una frase esplicita che dica che il riepilogo non sostituisce il medico e non costituisce diagnosi o prescrizione\n\n"
        "STILE\n"
        "- tono calmo, chiaro, professionale\n"
        "- frasi concise\n"
        "- lessico comprensibile\n"
        "- prudenza clinica alta\n\n"
        "OUTPUT\n"
        "Restituisci solo il riepilogo finale, in italiano, seguendo esattamente la struttura obbligatoria.\n\n"
        f"DATI STRUTTURATI:\n{serialized}"
    )


def _journal_entry_line(entry: dict[str, Any]) -> str:
    parts = [str(entry.get("date", ""))]
    symptom_count = len(entry.get("symptoms", []))
    vital_count = len(entry.get("vitals", []))
    metrics: list[str] = []
    for key, label in (
        ("energy_level", "energia"),
        ("mood_level", "umore"),
        ("stress_level", "stress"),
        ("general_pain", "dolore"),
    ):
        value = entry.get(key)
        if value is not None:
            metrics.append(f"{label} {value}/10")
    if symptom_count:
        metrics.append(f"{symptom_count} sintomi")
    if vital_count:
        metrics.append(f"{vital_count} parametri")
    note_tags = entry.get("general_note_tags")
    if isinstance(note_tags, list) and note_tags:
        cleaned_tags = [str(item).strip() for item in note_tags if str(item).strip()]
        if cleaned_tags:
            metrics.append(f"tag {', '.join(cleaned_tags[:3])}")
    else:
        notes = entry.get("general_notes")
        if notes:
            metrics.append(str(notes))

    symptom_signals: list[str] = []
    for symptom in entry.get("symptoms", []):
        if not isinstance(symptom, dict):
            continue
        metadata_flags = symptom.get("metadata_flags")
        if isinstance(metadata_flags, list):
            for flag in metadata_flags:
                cleaned_flag = str(flag).strip()
                if cleaned_flag and cleaned_flag not in symptom_signals:
                    symptom_signals.append(cleaned_flag)
                if len(symptom_signals) >= 3:
                    break
        tags = symptom.get("note_tags")
        if not isinstance(tags, list):
            continue
        for tag in tags:
            cleaned_tag = str(tag).strip()
            if cleaned_tag and cleaned_tag not in symptom_signals:
                symptom_signals.append(cleaned_tag)
            if len(symptom_signals) >= 3:
                break
        if len(symptom_signals) >= 3:
            break
    if symptom_signals:
        metrics.append(f"sintomi taggati {', '.join(symptom_signals)}")
    if metrics:
        parts.append(" - ".join(metrics))
    return ": ".join(parts)


def _extract_openai_message_content(payload: dict[str, object]) -> str:
    choices = payload.get("choices")
    if not isinstance(choices, list) or not choices:
        raise ValueError("AI provider response does not contain choices")

    first = choices[0]
    if not isinstance(first, dict):
        raise ValueError("AI provider returned an invalid choice payload")

    message = first.get("message")
    if not isinstance(message, dict):
        raise ValueError("AI provider response does not contain a message")

    content = message.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, dict) and item.get("type") == "text" and isinstance(item.get("text"), str):
                parts.append(item["text"])
        return "\n".join(parts)
    raise ValueError("AI provider returned an unsupported content payload")


def _extract_gemini_message_content(payload: dict[str, object]) -> str:
    candidates = payload.get("candidates")
    if not isinstance(candidates, list) or not candidates:
        raise ValueError("Gemini provider response does not contain candidates")

    first = candidates[0]
    if not isinstance(first, dict):
        raise ValueError("Gemini provider returned an invalid candidate payload")

    content = first.get("content")
    if not isinstance(content, dict):
        raise ValueError("Gemini provider response does not contain content")

    parts = content.get("parts")
    if not isinstance(parts, list):
        raise ValueError("Gemini provider response does not contain parts")

    text_parts: list[str] = []
    for item in parts:
        if isinstance(item, dict) and isinstance(item.get("text"), str):
            text_parts.append(item["text"])
    return "\n".join(text_parts)


def _extract_gemini_finish_reason(payload: dict[str, object]) -> str | None:
    candidates = payload.get("candidates")
    if not isinstance(candidates, list) or not candidates:
        return None

    first = candidates[0]
    if not isinstance(first, dict):
        return None
    finish_reason = first.get("finishReason")
    return finish_reason if isinstance(finish_reason, str) else None
