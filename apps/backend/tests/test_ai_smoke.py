import json

from app import ai_smoke
from app.ai.summary_provider import SummaryGenerationResult


def test_ai_smoke_runs_with_payload_file(tmp_path, monkeypatch, capsys):
    payload_file = tmp_path / "payload.json"
    payload_file.write_text(
        json.dumps(
            {
                "summary_type": "daily",
                "summary_label": "riepilogo giornaliero",
                "period_start": "2026-03-24",
                "period_end": "2026-03-24",
                "data_considered": ["1 check-up", "1 documento recente"],
                "patient_snapshot": ["Anna Bianchi, 33 anni"],
                "active_conditions": ["asma (active)"],
                "allergies": ["penicillina (moderate)"],
                "family_history": ["madre: tumore mammario"],
                "medications": ["Atorvastatina 20 mg"],
                "medication_adherence": ["2026-03-24 08:00 - Atorvastatina: taken"],
                "wearable_daily_summaries": ["2026-03-24 (android): 8421 passi"],
                "journal_entries": [
                    {
                        "date": "2026-03-24",
                        "energy_level": 4,
                        "mood_level": 5,
                        "symptoms": ["cefalea"],
                        "vitals": ["spo2 97 %"],
                    }
                ],
                "observations": ["Energia media 5/10."],
                "recent_lab_results": ["2026-03-23 - Emocromo: emoglobina 11.2 g/dL fuori range"],
                "recent_imaging_reports": ["2026-03-23 - RX torace: nessun versamento pleurico"],
                "recent_documents": ["Esami sangue del 2026-03-23"],
                "prior_daily_summaries": [
                    "2026-03-23 (generato 2026-03-23): andamento stabile."
                ],
                "open_alerts": ["attention: dolore toracico"],
                "follow_up_reasons": ["Sono presenti alert aperti da discutere con il medico."],
                "missing_data": ["Nessun peso recente disponibile."],
            }
        ),
        encoding="utf-8",
    )

    class _FakeProvider:
        provider_name = "gemini_ai_studio"
        model_name = "gemini-2.5-flash"

        def generate_result(self, payload):
            assert payload.summary_type == "daily"
            assert payload.period_start.isoformat() == "2026-03-24"
            assert "1 check-up" in payload.data_considered
            return SummaryGenerationResult(
                content="Sintesi prudente. " * 40,
                provider_name=self.provider_name,
                model_name=self.model_name,
            )

    monkeypatch.setattr(ai_smoke, "build_summary_provider", lambda settings: _FakeProvider())

    exit_code = ai_smoke.main(["--payload", str(payload_file)])

    assert exit_code == 0
    output = capsys.readouterr().out
    assert "provider=gemini_ai_studio" in output
    assert "used_fallback=false" in output
    assert "summary_length=" in output


def test_ai_smoke_requires_external_provider(monkeypatch, capsys):
    class _FakeProvider:
        provider_name = "rule_based"
        model_name = "clindiary-safe-summary"

        def generate_result(self, payload):
            return SummaryGenerationResult(
                content="Sintesi prudente. " * 40,
                provider_name=self.provider_name,
                model_name=self.model_name,
            )

    monkeypatch.setattr(ai_smoke, "build_summary_provider", lambda settings: _FakeProvider())

    exit_code = ai_smoke.main(["--require-external-provider"])

    assert exit_code == 4
    output = capsys.readouterr().out
    assert "provider=rule_based" in output
    assert "external_provider_required=true" in output


def test_ai_smoke_supports_gemma_summary_profile(monkeypatch, capsys):
    class _FakeProvider:
        provider_name = "gemma"
        model_name = "gemma-4"

        def generate_result(self, payload):
            assert payload.summary_type == "pre_visit"
            assert "2 misure da dispositivi clinici" in payload.data_considered
            return SummaryGenerationResult(
                content="Sintesi Gemma prudente. " * 40,
                provider_name=self.provider_name,
                model_name=self.model_name,
            )

    monkeypatch.setattr(ai_smoke, "build_summary_provider", lambda settings: _FakeProvider())

    exit_code = ai_smoke.main(["--profile", "gemma_summary"])

    assert exit_code == 0
    output = capsys.readouterr().out
    assert "provider=gemma" in output
    assert "model=gemma-4" in output
