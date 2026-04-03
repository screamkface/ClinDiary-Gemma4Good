from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass(slots=True)
class DeviceMeasurementSummaryItem:
    provider_code: str
    provider_name: str
    metric_type: str
    metric_label: str
    measurement_count: int
    latest_measured_at: datetime
    latest_value: str
    trend_label: str | None
    concern_level: str | None
    concern_note: str | None
    summary: str
    ai_summary: str


def summarize_device_measurements(measurements, *, limit: int | None = None) -> list[DeviceMeasurementSummaryItem]:
    if not measurements:
        return []

    grouped: dict[tuple[str, str], list] = {}
    for measurement in sorted(measurements, key=lambda item: item.measured_at):
        key = (measurement.provider_code, measurement.metric_type)
        grouped.setdefault(key, []).append(measurement)

    items: list[DeviceMeasurementSummaryItem] = []
    for provider_code, metric_type in sorted(
        grouped.keys(),
        key=lambda item: (
            grouped[item][-1].measured_at,
            item[1],
            item[0],
        ),
        reverse=True,
    ):
        summary = _summarize_group(
            provider_code=provider_code,
            metric_type=metric_type,
            measurements=grouped[(provider_code, metric_type)],
        )
        if summary is not None:
            items.append(summary)

    if limit is not None:
        return items[:limit]
    return items


def _summarize_group(
    *,
    provider_code: str,
    metric_type: str,
    measurements: list,
) -> DeviceMeasurementSummaryItem | None:
    latest = measurements[-1]
    provider_name = device_provider_label(provider_code)
    metric_label = device_metric_label(metric_type)
    primary_values = [float(item.primary_value) for item in measurements if item.primary_value is not None]
    secondary_values = [float(item.secondary_value) for item in measurements if item.secondary_value is not None]

    if metric_type == "blood_pressure" and primary_values and secondary_values:
        avg_sys = sum(primary_values) / len(primary_values)
        avg_dia = sum(secondary_values) / len(secondary_values)
        latest_value = (
            f"{_format_number(latest.primary_value)}/{_format_number(latest.secondary_value)} mmHg"
        )
        if latest.tertiary_value is not None:
            latest_value += f" · FC {_format_number(latest.tertiary_value)} bpm"
        concern_level, concern_note = _blood_pressure_concern(
            latest_systolic=latest.primary_value,
            latest_diastolic=latest.secondary_value,
            avg_systolic=avg_sys,
            avg_diastolic=avg_dia,
        )
        trend_label = f"Media {_format_number(avg_sys)}/{_format_number(avg_dia)} mmHg"
        summary = (
            f"{provider_name}: {len(measurements)} misure, {trend_label.lower()}, ultima {latest_value}."
        )
        return DeviceMeasurementSummaryItem(
            provider_code=provider_code,
            provider_name=provider_name,
            metric_type=metric_type,
            metric_label=metric_label,
            measurement_count=len(measurements),
            latest_measured_at=latest.measured_at,
            latest_value=latest_value,
            trend_label=trend_label,
            concern_level=concern_level,
            concern_note=concern_note,
            summary=summary,
            ai_summary=_ai_summary_line(summary, concern_note),
        )

    if metric_type in {"blood_glucose_bgm", "blood_glucose_cgm"} and primary_values:
        unit = latest.unit or "mg/dL"
        avg_glucose = sum(primary_values) / len(primary_values)
        range_text = f"{_format_number(min(primary_values))}-{_format_number(max(primary_values))} {unit}"
        latest_value = f"{_format_number(latest.primary_value)} {unit}"
        concern_level, concern_note = _glucose_concern(primary_values)
        trend_label = f"Range {range_text}"
        summary = (
            f"{provider_name}: {len(measurements)} misure, media {_format_number(avg_glucose)} {unit}, "
            f"{trend_label.lower()}, ultima {latest_value}."
        )
        return DeviceMeasurementSummaryItem(
            provider_code=provider_code,
            provider_name=provider_name,
            metric_type=metric_type,
            metric_label=metric_label,
            measurement_count=len(measurements),
            latest_measured_at=latest.measured_at,
            latest_value=latest_value,
            trend_label=trend_label,
            concern_level=concern_level,
            concern_note=concern_note,
            summary=summary,
            ai_summary=_ai_summary_line(summary, concern_note),
        )

    if metric_type == "body_weight" and primary_values:
        unit = latest.unit or "kg"
        latest_value = f"{_format_number(latest.primary_value, 1)} {unit}"
        delta = primary_values[-1] - primary_values[0] if len(primary_values) >= 2 else None
        trend_label = None
        concern_level = None
        concern_note = None
        if delta is not None:
            sign = "+" if delta > 0 else ""
            trend_label = f"Variazione {sign}{_format_number(delta, 1)} {unit}"
            if abs(delta) >= 3:
                concern_level = "attention"
                concern_note = (
                    "Nel periodo il peso mostra una variazione evidente: utile contestualizzarla con il medico se non attesa."
                )
        summary = f"{provider_name}: ultimo {latest_value}."
        if trend_label:
            summary = f"{summary[:-1]} · {trend_label.lower()}."
        return DeviceMeasurementSummaryItem(
            provider_code=provider_code,
            provider_name=provider_name,
            metric_type=metric_type,
            metric_label=metric_label,
            measurement_count=len(measurements),
            latest_measured_at=latest.measured_at,
            latest_value=latest_value,
            trend_label=trend_label,
            concern_level=concern_level,
            concern_note=concern_note,
            summary=summary,
            ai_summary=_ai_summary_line(summary, concern_note),
        )

    if metric_type == "spo2" and primary_values:
        unit = latest.unit or "%"
        avg_value = sum(primary_values) / len(primary_values)
        min_value = min(primary_values)
        latest_value = f"{_format_number(latest.primary_value)} {unit}"
        trend_label = f"Minima {_format_number(min_value)} {unit}"
        concern_level, concern_note = _spo2_concern(min_value)
        summary = (
            f"{provider_name}: {len(measurements)} misure, media {_format_number(avg_value)} {unit}, "
            f"{trend_label.lower()}, ultima {latest_value}."
        )
        return DeviceMeasurementSummaryItem(
            provider_code=provider_code,
            provider_name=provider_name,
            metric_type=metric_type,
            metric_label=metric_label,
            measurement_count=len(measurements),
            latest_measured_at=latest.measured_at,
            latest_value=latest_value,
            trend_label=trend_label,
            concern_level=concern_level,
            concern_note=concern_note,
            summary=summary,
            ai_summary=_ai_summary_line(summary, concern_note),
        )

    if metric_type == "temperature" and primary_values:
        unit = latest.unit or "°C"
        max_value = max(primary_values)
        avg_value = sum(primary_values) / len(primary_values)
        latest_value = f"{_format_number(latest.primary_value, 1)} {unit}"
        trend_label = f"Massima {_format_number(max_value, 1)} {unit}"
        concern_level, concern_note = _temperature_concern(max_value)
        summary = (
            f"{provider_name}: {len(measurements)} misure, media {_format_number(avg_value, 1)} {unit}, "
            f"{trend_label.lower()}, ultima {latest_value}."
        )
        return DeviceMeasurementSummaryItem(
            provider_code=provider_code,
            provider_name=provider_name,
            metric_type=metric_type,
            metric_label=metric_label,
            measurement_count=len(measurements),
            latest_measured_at=latest.measured_at,
            latest_value=latest_value,
            trend_label=trend_label,
            concern_level=concern_level,
            concern_note=concern_note,
            summary=summary,
            ai_summary=_ai_summary_line(summary, concern_note),
        )

    if metric_type == "heart_rate" and primary_values:
        unit = latest.unit or "bpm"
        avg_value = sum(primary_values) / len(primary_values)
        latest_value = f"{_format_number(latest.primary_value)} {unit}"
        trend_label = f"Media {_format_number(avg_value)} {unit}"
        summary = (
            f"{provider_name}: {len(measurements)} misure, {trend_label.lower()}, ultima {latest_value}."
        )
        return DeviceMeasurementSummaryItem(
            provider_code=provider_code,
            provider_name=provider_name,
            metric_type=metric_type,
            metric_label=metric_label,
            measurement_count=len(measurements),
            latest_measured_at=latest.measured_at,
            latest_value=latest_value,
            trend_label=trend_label,
            concern_level=None,
            concern_note=None,
            summary=summary,
            ai_summary=summary,
        )

    if primary_values:
        unit = latest.unit or ""
        avg_value = sum(primary_values) / len(primary_values)
        latest_value = f"{_format_number(latest.primary_value, 1)} {unit}".strip()
        trend_label = f"Media {_format_number(avg_value, 1)} {unit}".strip()
        summary = (
            f"{provider_name}: {len(measurements)} misure, {trend_label.lower()}, ultima {latest_value}."
        )
        return DeviceMeasurementSummaryItem(
            provider_code=provider_code,
            provider_name=provider_name,
            metric_type=metric_type,
            metric_label=metric_label,
            measurement_count=len(measurements),
            latest_measured_at=latest.measured_at,
            latest_value=latest_value,
            trend_label=trend_label,
            concern_level=None,
            concern_note=None,
            summary=summary,
            ai_summary=summary,
        )

    return None


def device_provider_label(provider_code: str) -> str:
    mapping = {
        "omron": "OMRON Connect",
        "withings": "Withings",
        "ihealth": "iHealth",
        "ad_medical": "A&D Medical",
        "dexcom": "Dexcom",
    }
    return mapping.get(provider_code, provider_code.replace("_", " ").title())


def device_metric_label(metric_type: str) -> str:
    mapping = {
        "blood_pressure": "Pressione arteriosa",
        "heart_rate": "Frequenza cardiaca",
        "spo2": "Saturazione ossigeno",
        "temperature": "Temperatura",
        "body_weight": "Peso",
        "body_composition": "Composizione corporea",
        "blood_glucose_bgm": "Glicemia capillare",
        "blood_glucose_cgm": "Glicemia continua",
    }
    return mapping.get(metric_type, metric_type.replace("_", " ").capitalize())


def _blood_pressure_concern(
    *,
    latest_systolic: float | None,
    latest_diastolic: float | None,
    avg_systolic: float,
    avg_diastolic: float,
) -> tuple[str | None, str | None]:
    if (
        (latest_systolic is not None and latest_diastolic is not None and latest_systolic >= 180 and latest_diastolic >= 120)
        or avg_systolic >= 160
        or avg_diastolic >= 100
    ):
        return (
            "high",
            "Nel periodo compaiono valori pressori molto alti: non interpretarli da soli e portali rapidamente all'attenzione del medico.",
        )
    if (
        (latest_systolic is not None and latest_diastolic is not None and (latest_systolic >= 140 or latest_diastolic >= 90))
        or avg_systolic >= 140
        or avg_diastolic >= 90
    ):
        return (
            "attention",
            "Le misure pressorie risultano alte nel periodo: utile confermarle e discuterle con il medico se il pattern continua.",
        )
    return None, None


def _spo2_concern(min_value: float) -> tuple[str | None, str | None]:
    if min_value < 90:
        return (
            "high",
            "Nel periodo compaiono saturazioni molto basse: serve un confronto medico se i dati sono affidabili o si ripetono.",
        )
    if min_value < 92:
        return (
            "attention",
            "Sono presenti misure di saturazione basse nel periodo: utile verificarle e contestualizzarle con il medico.",
        )
    return None, None


def _temperature_concern(max_value: float) -> tuple[str | None, str | None]:
    if max_value >= 39:
        return (
            "high",
            "Nel periodo compaiono temperature molto elevate: se persistono o si associano a sintomi, non ignorarle.",
        )
    if max_value >= 38:
        return (
            "attention",
            "Nel periodo compaiono temperature elevate: puo essere utile segnalarle al medico se persistono o ritornano.",
        )
    return None, None


def _glucose_concern(values: list[float]) -> tuple[str | None, str | None]:
    if not values:
        return None, None
    if min(values) < 54 or max(values) >= 250:
        return (
            "high",
            "Le misure glicemiche mostrano valori molto bassi o molto alti nel periodo: serve contestualizzazione clinica.",
        )
    if min(values) < 70 or max(values) >= 200:
        return (
            "attention",
            "Le misure glicemiche mostrano oscillazioni fuori target nel periodo: utile portarle al medico o al team che segue il diabete.",
        )
    return None, None


def _ai_summary_line(summary: str, concern_note: str | None) -> str:
    if not concern_note:
        return summary
    return f"{summary} Punto da discutere: {concern_note}"


def _format_number(value: float | None, decimals: int = 0) -> str:
    if value is None:
        return "-"
    if decimals == 0:
        return str(int(round(value)))
    return f"{value:.{decimals}f}"
