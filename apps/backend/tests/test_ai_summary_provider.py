from datetime import date

from app.ai.local_runtime_adapter import LocalAiRuntimeUnavailableError
from app.ai.summary_provider import (
    ResilientSummaryProvider,
    RuleBasedSummaryProvider,
    SummaryGenerationInput,
    SummaryGenerationResult,
    SummaryProviderOverride,
    build_summary_provider,
)
from app.core.config import Settings
from app.core.metrics import get_metrics_registry


def _payload() -> SummaryGenerationInput:
    return SummaryGenerationInput(
        summary_type="weekly",
        summary_label="riassunto settimanale",
        period_start=date(2026, 3, 14),
        period_end=date(2026, 3, 21),
        data_considered=["7 check-up", "2 documenti recenti"],
        patient_snapshot=["Anna Bianchi, 33 anni, sesso biologico female"],
        active_conditions=["asma (active)"],
        allergies=["penicillina (moderate)"],
        family_history=["madre: tumore mammario"],
        medications=["Atorvastatina 20 mg"],
        medication_adherence=["2026-03-20 08:00 - Atorvastatina: taken"],
        wearable_daily_summaries=[
            "2026-03-20 (android): 8421 passi, sonno 7.3h, FC media 76 bpm"
        ],
        device_measurement_summaries=[
            "OMRON Connect · pressione arteriosa: 4 misure, media 126/79 mmHg, ultima 128/80 mmHg FC 67 bpm il 2026-03-20 08:10 UTC."
        ],
        journal_entries=[
            {
                "date": "2026-03-20",
                "energy_level": 4,
                "mood_level": 5,
                "symptoms": ["chest_pain sev 8/10"],
                "vitals": ["spo2 89 %"],
            }
        ],
        observations=["Energia media 5.4/10."],
        recent_lab_results=["2026-03-19 - Emocromo: emoglobina 11.2 g/dL range 12-16 fuori range"],
        recent_imaging_reports=["2026-03-18 - RX torace: nessun versamento pleurico"],
        recent_documents=["Esami sangue del 2026-03-19"],
        prior_daily_summaries=[
            "2026-03-19 (generato 2026-03-19): andamento stabile con lieve cefalea serale."
        ],
        open_alerts=["attention: dolore toracico"],
        follow_up_reasons=["Sono presenti alert aperti da discutere con il medico."],
        missing_data=["Nessun peso recente disponibile."],
    )


def test_build_summary_provider_uses_local_gemma_runtime(monkeypatch):
    captured: dict[str, object] = {}

    class _Adapter:
        def generate_summary(self, *, model_name, system_prompt, user_prompt, max_output_tokens):
            captured["model_name"] = model_name
            captured["system_prompt"] = system_prompt
            captured["user_prompt"] = user_prompt
            captured["max_output_tokens"] = max_output_tokens
            return "Sintesi locale Gemma.\nNessuna diagnosi automatica."

    monkeypatch.setattr(
        "app.ai.summary_provider.build_local_summary_runtime_adapter",
        lambda settings: _Adapter(),
    )

    settings = Settings(
        ai_provider="gemma",
        summary_ai_runtime_mode="local",
        local_llm_model_name="gemma-4-e2b",
        ai_max_output_tokens=400,
    )

    provider = build_summary_provider(settings)
    result = provider.generate_result(_payload())

    assert provider.provider_name == "gemma"
    assert provider.model_name == "gemma-4-e2b"
    assert result.provider_name == "gemma"
    assert result.model_name == "gemma-4-e2b"
    assert "Sintesi locale Gemma" in result.content
    assert captured["model_name"] == "gemma-4-e2b"
    assert captured["max_output_tokens"] == 2048
    assert "Usa esclusivamente i dati presenti nel payload JSON" in captured["system_prompt"]
    assert "prior_daily_summaries" in captured["user_prompt"]


def test_build_summary_provider_allows_local_runtime_without_external_consent(monkeypatch):
    class _Adapter:
        def generate_summary(self, *, model_name, system_prompt, user_prompt, max_output_tokens):
            return "Sintesi locale disponibile anche senza consenso cloud."

    monkeypatch.setattr(
        "app.ai.summary_provider.build_local_summary_runtime_adapter",
        lambda settings: _Adapter(),
    )

    settings = Settings(
        ai_provider="gemma",
        summary_ai_runtime_mode="local",
        local_llm_model_name="gemma-4-e2b",
    )

    provider = build_summary_provider(settings, allow_external_provider=False)
    result = provider.generate_result(_payload())

    assert provider.provider_name == "gemma"
    assert result.provider_name == "gemma"
    assert result.used_fallback is False


def test_build_summary_provider_falls_back_to_rule_based_when_runtime_missing(monkeypatch):
    monkeypatch.setattr(
        "app.ai.summary_provider.build_local_summary_runtime_adapter",
        lambda settings: (_ for _ in ()).throw(LocalAiRuntimeUnavailableError("runtime offline")),
    )

    settings = Settings(
        ai_provider="gemma",
        summary_ai_runtime_mode="local",
        local_llm_model_name="gemma-4-e2b",
    )

    provider = build_summary_provider(settings)

    assert isinstance(provider, RuleBasedSummaryProvider)


def test_build_summary_provider_resolves_local_gemma4_override(monkeypatch):
    class _Adapter:
        def generate_summary(self, *, model_name, system_prompt, user_prompt, max_output_tokens):
            return "Sintesi locale Gemma 4."

    monkeypatch.setattr(
        "app.ai.summary_provider.build_local_summary_runtime_adapter",
        lambda settings: _Adapter(),
    )

    settings = Settings(local_llm_model_name="gemma-4-e2b")

    provider = build_summary_provider(
        settings,
        override=SummaryProviderOverride(
            provider_name="local_gemma4",
            runtime_mode="local",
            response_provider_name="local_gemma4",
        ),
    )

    assert provider.provider_name == "local_gemma4"
    assert provider.model_name == "gemma-4-e2b"
    result = provider.generate_result(_payload())
    assert result.provider_name == "local_gemma4"
    assert result.model_name == "gemma-4-e2b"
    assert "Sintesi locale Gemma 4." in result.content


def test_build_summary_provider_unknown_remote_provider_falls_back_to_rule_based():
    provider = build_summary_provider(Settings(ai_provider="legacy_remote_provider"))

    assert isinstance(provider, RuleBasedSummaryProvider)


def test_local_runtime_provider_increases_budget_for_monthly_summary(monkeypatch):
    captured: dict[str, object] = {}

    class _Adapter:
        def generate_summary(self, *, model_name, system_prompt, user_prompt, max_output_tokens):
            captured["max_output_tokens"] = max_output_tokens
            return "Sintesi mensile prudente."

    monkeypatch.setattr(
        "app.ai.summary_provider.build_local_summary_runtime_adapter",
        lambda settings: _Adapter(),
    )

    provider = build_summary_provider(
        Settings(
            ai_provider="gemma",
            summary_ai_runtime_mode="local",
            local_llm_model_name="gemma-4-e2b",
            ai_max_output_tokens=1200,
        )
    )

    payload = _payload()
    payload.summary_type = "monthly"
    provider.generate_result(payload)

    assert captured["max_output_tokens"] == 3072


def test_rule_based_provider_mentions_medical_follow_up_without_diagnosis():
    provider = RuleBasedSummaryProvider()

    result = provider.generate(_payload())

    assert "Quando parlarne con il medico" in result
    assert "diagnosi" in result
    assert "emoglobina 11.2" in result


def test_rule_based_provider_prefers_tagged_note_digests_over_raw_notes():
    payload = _payload()
    payload.journal_entries[0]["general_note_tags"] = ["sonno_scarso", "stress_lavoro"]
    payload.journal_entries[0]["general_notes"] = "Lavoro intenso e sonno ridotto nelle ultime notti."

    result = RuleBasedSummaryProvider().generate(payload)

    assert "tag sonno_scarso, stress_lavoro" in result
    assert "Lavoro intenso e sonno ridotto" not in result


def test_resilient_provider_records_fallback_metrics_without_logging_payload(monkeypatch):
    metrics = get_metrics_registry()
    metrics.reset()
    log_events: list[tuple[str, dict[str, object]]] = []

    class _FailingProvider:
        provider_name = "gemma"
        model_name = "gemma-4"

        def generate_result(self, payload):
            raise RuntimeError("provider timeout")

        def generate(self, payload):
            return self.generate_result(payload).content

    class _FallbackProvider:
        provider_name = "rule_based"
        model_name = "clindiary-safe-summary"

        def generate_result(self, payload):
            return SummaryGenerationResult(
                content="Sintesi fallback.",
                provider_name=self.provider_name,
                model_name=self.model_name,
            )

        def generate(self, payload):
            return self.generate_result(payload).content

    monkeypatch.setattr(
        "app.ai.summary_provider.logger.warning",
        lambda event, **kwargs: log_events.append((event, kwargs)),
    )
    monkeypatch.setattr(
        "app.ai.summary_provider.logger.info",
        lambda event, **kwargs: log_events.append((event, kwargs)),
    )

    provider = ResilientSummaryProvider(
        primary=_FailingProvider(),
        fallback=_FallbackProvider(),
    )

    result = provider.generate_result(_payload())

    assert result.used_fallback is True
    rendered = metrics.render_prometheus()
    assert 'clindiary_ai_summary_runs_total{provider="gemma",model_name="gemma-4",outcome="fallback_triggered",used_fallback="true"} 1' in rendered
    assert 'clindiary_ai_summary_fallbacks_total{from_provider="gemma",to_provider="rule_based"} 1' in rendered
    assert all("journal_entries" not in str(kwargs) for _, kwargs in log_events)
    assert all("patient_snapshot" not in str(kwargs) for _, kwargs in log_events)
