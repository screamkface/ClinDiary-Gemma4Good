import json

from app import ai_eval
from app.ai.summary_provider import SummaryGenerationResult


def _write_payload(path, summary_type: str) -> None:
    path.write_text(
        json.dumps(
            {
                "summary_type": summary_type,
                "summary_label": f"riepilogo {summary_type}",
                "period_start": "2026-03-24",
                "period_end": "2026-03-24",
                "data_considered": ["1 check-up", "1 documento recente"],
                "patient_snapshot": ["Anna Bianchi, 33 anni", "Regione: Lombardia"],
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
                "prior_daily_summaries": ["2026-03-23 (generato 2026-03-23): andamento stabile."],
                "open_alerts": ["attention: dolore toracico"],
                "follow_up_reasons": ["Sono presenti alert aperti da discutere con il medico."],
                "missing_data": ["Nessun peso recente disponibile."],
            }
        ),
        encoding="utf-8",
    )


def test_ai_eval_runs_multiple_curated_cases(tmp_path, monkeypatch, capsys):
    _write_payload(tmp_path / "daily.json", "daily")
    _write_payload(tmp_path / "weekly.json", "weekly")

    class _FakeProvider:
        provider_name = "gemma"
        model_name = "gemma-4"

        def generate_result(self, payload):
            return SummaryGenerationResult(
                content=(
                    "1. Periodo considerato e contesto del paziente\n"
                    "Contesto del paziente presente.\n\n"
                    "2. Andamento osservato nel diario e nei dati registrati\n"
                    "Andamento osservato stabile con segnali da monitorare.\n\n"
                    "3. Esami/documenti recenti rilevanti\n"
                    "Esami/documenti recenti disponibili e da discutere.\n\n"
                    "4. Quando e perche parlare con il medico\n"
                    "Quando e perche parlare con il medico: confronto utile.\n\n"
                    "5. Chiusura che ricorda esplicitamente che il testo non e una diagnosi o prescrizione\n"
                    "Questo riepilogo non sostituisce il medico e non costituisce diagnosi o prescrizione."
                ),
                provider_name=self.provider_name,
                model_name=self.model_name,
            )

    monkeypatch.setattr(ai_eval, "build_summary_provider", lambda settings: _FakeProvider())

    exit_code = ai_eval.main(["--inputs", str(tmp_path), "--min-length", "100"])

    assert exit_code == 0
    output = capsys.readouterr().out
    assert "cases=2" in output
    assert "evaluation=pass" in output
    assert "case=daily" in output
    assert "case=weekly" in output


def test_ai_eval_requires_local_runtime(tmp_path, monkeypatch, capsys):
    _write_payload(tmp_path / "daily.json", "daily")

    class _FakeProvider:
        provider_name = "rule_based"
        model_name = "clindiary-safe-summary"

        def generate_result(self, payload):
            return SummaryGenerationResult(
                content="Sintesi prudente. " * 50,
                provider_name=self.provider_name,
                model_name=self.model_name,
            )

    monkeypatch.setattr(ai_eval, "build_summary_provider", lambda settings: _FakeProvider())

    exit_code = ai_eval.main(["--inputs", str(tmp_path), "--require-local-runtime"])

    assert exit_code == 4
    output = capsys.readouterr().out
    assert "local_runtime_required=true" in output
