from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path
import sys

from app.ai.summary_provider import SummaryGenerationInput, build_summary_provider
from app.core.config import get_settings


def sample_payload(profile: str = "default") -> SummaryGenerationInput:
    if profile == "gemma_summary":
        return SummaryGenerationInput(
            summary_type="pre_visit",
            summary_label="riepilogo pre-visita",
            period_start=date(2026, 3, 1),
            period_end=date(2026, 3, 24),
            data_considered=[
                "12 check-up",
                "5 sintomi registrati",
                "3 documenti recenti",
                "2 misure da dispositivi clinici",
            ],
            patient_snapshot=[
                "Anna Bianchi, 33 anni, sesso biologico female",
                "Regione screening/prevenzione: Campania",
                "Attivita fisica: moderata",
            ],
            active_conditions=["asma (active)"],
            allergies=["penicillina (moderate)"],
            family_history=["madre: tumore mammario"],
            medications=["Atorvastatina 20 mg", "Vitamina D 1000 UI"],
            medication_adherence=["2026-03-24 08:00 - Atorvastatina: taken"],
            wearable_daily_summaries=[
                "2026-03-24 (android): 8421 passi, sonno 7.3h, FC media 76 bpm",
                "2026-03-23 (android): 6120 passi, sonno 6.4h, FC media 80 bpm",
            ],
            device_measurement_summaries=[
                "pressione arteriosa: A&D Medical: 2 misure, media 127/80 mmHg, ultima 128/80 mmHg · FC 68 bpm.",
                "peso: Withings: ultimo 69.4 kg · variazione +0.8 kg.",
            ],
            journal_entries=[
                {
                    "date": "2026-03-24",
                    "energy_level": 4,
                    "mood_level": 5,
                    "symptoms": ["cefalea", "stanchezza serale"],
                    "vitals": ["spo2 97 %"],
                    "general_notes": "Stanchezza serale dopo giornata intensa.",
                }
            ],
            observations=["Sonno irregolare nei tre giorni precedenti."],
            recent_lab_results=["2026-03-23 - Emocromo: emoglobina 11.2 g/dL range 12-16 fuori range"],
            recent_imaging_reports=["2026-03-22 - Ecografia addome: nessun reperto acuto"],
            recent_documents=["Esami sangue del 2026-03-23", "Ecografia addome del 2026-03-22"],
            prior_daily_summaries=[
                "2026-03-23 (generato 2026-03-23): lieve cefalea serale con sonno ridotto.",
                "2026-03-22 (generato 2026-03-22): giornata stabile con energia bassa.",
            ],
            open_alerts=[],
            follow_up_reasons=["Portare in visita il trend pressorio e l'emoglobina fuori range."],
            missing_data=["Nessuna saturazione notturna disponibile."],
        )

    return SummaryGenerationInput(
        summary_type="daily",
        summary_label="riepilogo giornaliero",
        period_start=date(2026, 3, 24),
        period_end=date(2026, 3, 24),
        data_considered=[
            "1 check-up",
            "2 sintomi",
            "1 documento recente",
            "1 recap giornaliero precedente",
        ],
        patient_snapshot=[
            "Anna Bianchi, 33 anni, sesso biologico female",
            "Fumatore: no",
            "Attivita fisica: moderata",
        ],
        active_conditions=["asma (active)"],
        allergies=["penicillina (moderate)"],
        family_history=["madre: tumore mammario"],
        medications=["Atorvastatina 20 mg"],
        medication_adherence=["2026-03-24 08:00 - Atorvastatina: taken"],
        wearable_daily_summaries=[
            "2026-03-24 (android): 8421 passi, sonno 7.3h, FC media 76 bpm",
        ],
        device_measurement_summaries=[
            "OMRON Connect · pressione arteriosa: 4 misure, media 126/79 mmHg, ultima 128/80 mmHg FC 67 bpm il 2026-03-24 08:10 UTC."
        ],
        journal_entries=[
            {
                "date": "2026-03-24",
                "energy_level": 4,
                "mood_level": 5,
                "symptoms": ["cefalea"], 
                "vitals": ["spo2 97 %"],
                "general_notes": "Giornata stabile, lieve stanchezza serale.",
            }
        ],
        observations=["Energia media 5/10."],
        recent_lab_results=["2026-03-23 - Emocromo: emoglobina 11.2 g/dL range 12-16 fuori range"],
        recent_imaging_reports=["2026-03-23 - RX torace: nessun versamento pleurico"],
        recent_documents=["Esami sangue del 2026-03-23"],
        prior_daily_summaries=[
            "2026-03-23 (generato 2026-03-23): andamento stabile con lieve cefalea serale.",
        ],
        open_alerts=["attention: dolore toracico"],
        follow_up_reasons=["Sono presenti alert aperti da discutere con il medico."],
        missing_data=["Nessun peso recente disponibile."],
    )


def load_payload(path: Path | None) -> SummaryGenerationInput:
    if path is None:
        return sample_payload()

    data = json.loads(path.read_text(encoding="utf-8"))
    return SummaryGenerationInput(
        summary_type=str(data.get("summary_type", "daily")),
        summary_label=str(data.get("summary_label", "riepilogo giornaliero")),
        period_start=date.fromisoformat(str(data["period_start"])),
        period_end=date.fromisoformat(str(data["period_end"])),
        data_considered=_string_list(data.get("data_considered")),
        patient_snapshot=_string_list(data.get("patient_snapshot")),
        active_conditions=_string_list(data.get("active_conditions")),
        allergies=_string_list(data.get("allergies")),
        family_history=_string_list(data.get("family_history")),
        medications=_string_list(data.get("medications")),
        medication_adherence=_string_list(data.get("medication_adherence")),
        wearable_daily_summaries=_string_list(data.get("wearable_daily_summaries")),
        device_measurement_summaries=_string_list(data.get("device_measurement_summaries")),
        journal_entries=_dict_list(data.get("journal_entries")),
        observations=_string_list(data.get("observations")),
        recent_lab_results=_string_list(data.get("recent_lab_results")),
        recent_imaging_reports=_string_list(data.get("recent_imaging_reports")),
        recent_documents=_string_list(data.get("recent_documents")),
        prior_daily_summaries=_string_list(data.get("prior_daily_summaries")),
        open_alerts=_string_list(data.get("open_alerts")),
        follow_up_reasons=_string_list(data.get("follow_up_reasons")),
        missing_data=_string_list(data.get("missing_data")),
    )


def _string_list(value: object) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item) for item in value if item is not None]


def _dict_list(value: object) -> list[dict[str, object]]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="ClinDiary AI smoke check")
    parser.add_argument(
        "--payload",
        help="Percorso a un JSON con il payload sintetico da usare per la prova",
        default=None,
    )
    parser.add_argument(
        "--profile",
        choices=("default", "gemma_summary"),
        default="default",
        help="Profilo payload predefinito da usare quando --payload non e specificato",
    )
    parser.add_argument(
        "--min-length",
        type=int,
        default=400,
        help="Lunghezza minima accettata per il riepilogo generato",
    )
    parser.add_argument(
        "--require-external-provider",
        action="store_true",
        help="Fallisce se il provider configurato manca o se viene usato il fallback rule-based",
    )
    args = parser.parse_args(argv)

    payload_path = Path(args.payload) if args.payload else None
    if payload_path is not None and not payload_path.exists():
        print(f"payload_not_found={payload_path}")
        return 2

    try:
        payload = load_payload(payload_path) if payload_path else sample_payload(args.profile)
    except Exception as exc:
        print(f"payload_error={exc}")
        return 2

    provider = build_summary_provider(get_settings())
    try:
        result = provider.generate_result(payload)
    except Exception as exc:
        print(f"ai_error={exc}")
        return 3

    content = result.content.strip()
    preview = content.replace("\n", " ")[:400]
    print(f"provider={result.provider_name}")
    print(f"model={result.model_name}")
    print(f"used_fallback={str(result.used_fallback).lower()}")
    print(f"summary_length={len(content)}")
    print(f"summary_preview={preview}")

    if args.require_external_provider and (
        provider.provider_name == "rule_based" or result.used_fallback
    ):
        print("external_provider_required=true")
        return 4

    if len(content) < args.min_length:
        print("summary_too_short=true")
        return 5

    return 0


if __name__ == "__main__":
    sys.exit(main())
