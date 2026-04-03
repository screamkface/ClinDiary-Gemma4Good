from datetime import date
import json

import httpx

from app.ai.summary_provider import (
    GeminiAiStudioSummaryProvider,
    OpenAICompatibleSummaryProvider,
    RuleBasedSummaryProvider,
    RegoloAiSummaryProvider,
    SummaryGenerationInput,
    SummaryGenerationResult,
    ResilientSummaryProvider,
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


def test_openai_compatible_provider_extracts_summary():
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["json"] = json.loads(request.content.decode())
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": "Sintesi prudente.\nNessuna diagnosi automatica.",
                        }
                    }
                ]
            },
        )

    transport = httpx.MockTransport(
        handler
    )
    provider = OpenAICompatibleSummaryProvider(
        base_url="https://llm.example.com/v1",
        api_key="secret",
        model_name="safe-model",
        timeout_seconds=5,
        temperature=0.1,
        max_output_tokens=400,
        client=httpx.Client(transport=transport),
    )

    result = provider.generate(_payload())

    assert "Sintesi prudente" in result
    assert "diagnosi automatica" in result
    messages = captured["json"]["messages"]
    assert "Usa esclusivamente i dati presenti nel payload JSON" in messages[0]["content"]
    assert "Genera un riepilogo clinico prudente usando ESCLUSIVAMENTE" in messages[1]["content"]
    assert "patient_snapshot" in messages[1]["content"]
    assert "prior_daily_summaries" in messages[1]["content"]
    assert "recent_lab_results" in messages[1]["content"]
    assert "device_measurement_summaries" in messages[1]["content"]
    assert captured["json"]["max_tokens"] == 2048


def test_build_summary_provider_falls_back_to_rule_based_when_config_missing():
    settings = Settings(
        ai_provider="openai_compatible",
        ai_model_name="safe-model",
        ai_base_url=None,
        ai_api_key=None,
    )

    provider = build_summary_provider(settings)

    assert isinstance(provider, RuleBasedSummaryProvider)


def test_gemini_ai_studio_provider_extracts_summary():
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["json"] = json.loads(request.content.decode())
        return httpx.Response(
            200,
            json={
                "candidates": [
                    {
                        "finishReason": "STOP",
                        "content": {
                            "parts": [
                                {
                                    "text": "Sintesi Gemini prudente.\nNessuna diagnosi automatica.",
                                }
                            ]
                        },
                    }
                ]
            },
        )

    transport = httpx.MockTransport(
        handler
    )
    provider = GeminiAiStudioSummaryProvider(
        api_key="secret",
        model_name="gemini-2.5-flash",
        timeout_seconds=5,
        temperature=0.1,
        max_output_tokens=400,
        client=httpx.Client(transport=transport),
    )

    result = provider.generate(_payload())

    assert "Sintesi Gemini prudente" in result
    assert "diagnosi automatica" in result
    assert captured["json"]["generationConfig"]["thinkingConfig"]["thinkingBudget"] == 0
    assert captured["json"]["generationConfig"]["maxOutputTokens"] == 2048
    prompt = captured["json"]["contents"][0]["parts"][0]["text"]
    assert "Usa esclusivamente i dati presenti nel payload JSON" in prompt
    assert "DATI STRUTTURATI" in prompt
    assert "prior_daily_summaries" in prompt


def test_gemini_ai_studio_provider_rejects_truncated_summary():
    transport = httpx.MockTransport(
        lambda request: httpx.Response(
            200,
            json={
                "candidates": [
                    {
                        "finishReason": "MAX_TOKENS",
                        "content": {
                            "parts": [
                                {
                                    "text": "Gentile utente,\n\nDi seguito un riepilogo clinico prudente",
                                }
                            ]
                        },
                    }
                ]
            },
        )
    )
    provider = GeminiAiStudioSummaryProvider(
        api_key="secret",
        model_name="gemini-2.5-flash",
        timeout_seconds=5,
        temperature=0.1,
        max_output_tokens=400,
        client=httpx.Client(transport=transport),
    )

    try:
        provider.generate(_payload())
    except ValueError as exc:
        assert "truncated" in str(exc)
    else:
        raise AssertionError("Expected a truncated Gemini response to raise")


def test_build_summary_provider_supports_gemini_ai_studio():
    settings = Settings(
        ai_provider="gemini_ai_studio",
        ai_model_name="gemini-2.5-flash",
        gemini_api_key="gemini-secret",
    )

    provider = build_summary_provider(settings)

    assert provider.provider_name == "gemini_ai_studio"


def test_regolo_ai_provider_extracts_summary():
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["json"] = json.loads(request.content.decode())
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": "Sintesi Regolo prudente.\nNessuna diagnosi automatica.",
                        }
                    }
                ]
            },
        )

    transport = httpx.MockTransport(handler)
    provider = RegoloAiSummaryProvider(
        base_url="https://api.regolo.ai/v1",
        api_key="secret",
        model_name="minimax-m2.5",
        timeout_seconds=5,
        temperature=0.1,
        max_output_tokens=400,
        client=httpx.Client(transport=transport),
    )

    result = provider.generate(_payload())

    assert "Sintesi Regolo prudente" in result
    assert "diagnosi automatica" in result
    assert captured["json"]["model"] == "minimax-m2.5"
    assert captured["json"]["messages"][0]["content"].startswith("Segui rigorosamente")


def test_build_summary_provider_supports_regolo_ai():
    settings = Settings(
        ai_provider="regolo_ai",
        regolo_api_key="regolo-secret",
        regolo_model_name="minimax-m2.5",
    )

    provider = build_summary_provider(settings)

    assert provider.provider_name == "regolo_ai"


def test_build_summary_provider_prefers_regolo_model_name_over_generic_ai_model_name():
    settings = Settings(
        ai_provider="regolo_ai",
        ai_model_name="wrong-model",
        regolo_api_key="regolo-secret",
        regolo_model_name="MiniMax-M2.5-D",
    )

    provider = build_summary_provider(settings)

    assert provider.model_name == "minimax-m2.5"


def test_rule_based_provider_mentions_medical_follow_up_without_diagnosis():
    provider = RuleBasedSummaryProvider()

    result = provider.generate(_payload())

    assert "Quando parlarne con il medico" in result
    assert "diagnosi" in result
    assert "emoglobina 11.2" in result


def test_openai_compatible_provider_increases_budget_for_monthly_summary():
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["json"] = json.loads(request.content.decode())
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": "Sintesi mensile prudente.",
                        }
                    }
                ]
            },
        )

    transport = httpx.MockTransport(handler)
    provider = OpenAICompatibleSummaryProvider(
        base_url="https://llm.example.com/v1",
        api_key="secret",
        model_name="safe-model",
        timeout_seconds=5,
        temperature=0.1,
        max_output_tokens=1200,
        client=httpx.Client(transport=transport),
    )

    payload = _payload()
    payload.summary_type = "monthly"

    provider.generate(payload)

    assert captured["json"]["max_tokens"] == 3072


def test_resilient_provider_records_fallback_metrics_without_logging_payload(monkeypatch):
    metrics = get_metrics_registry()
    metrics.reset()
    log_events: list[tuple[str, dict[str, object]]] = []

    class _FailingProvider:
        provider_name = "regolo_ai"
        model_name = "minimax-m2.5"

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
    assert 'clindiary_ai_summary_runs_total{provider="regolo_ai",model_name="minimax-m2.5",outcome="fallback_triggered",used_fallback="true"} 1' in rendered
    assert 'clindiary_ai_summary_fallbacks_total{from_provider="regolo_ai",to_provider="rule_based"} 1' in rendered
    assert all("journal_entries" not in str(kwargs) for _, kwargs in log_events)
    assert all("patient_snapshot" not in str(kwargs) for _, kwargs in log_events)
