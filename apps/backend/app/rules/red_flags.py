from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
import re
from uuid import UUID

from app.core.security import utcnow
from app.models.daily_entry import DailyEntry
from app.models.enums import AlertSeverity


_NUMBER_RE = re.compile(r"-?\d+(?:[.,]\d+)?")

CHEST_PAIN_KEYWORDS = ("chest_pain", "dolore_toracico", "thoracic_pain")
DYSPNEA_KEYWORDS = ("dyspnea", "dispnea", "shortness_of_breath", "breathlessness")
NEURO_KEYWORDS = (
    "weakness",
    "numbness",
    "speech_difficulty",
    "confusion",
    "vision_loss",
    "facial_droop",
    "seizure",
    "neurologic",
)
BLEEDING_KEYWORDS = ("bleeding", "sanguinamento", "emorrhage", "hematemesis", "melena", "rectal_bleeding")
FEVER_KEYWORDS = ("fever", "febbre")
RAPID_WORSENING_KEYWORDS = ("peggior", "aggrava", "worsen", "rapid")
LOW_SAT_TYPES = ("oxygen_saturation", "spo2", "saturation")
TEMPERATURE_TYPES = ("temperature", "body_temperature", "temp")


@dataclass(slots=True)
class RedFlagMatch:
    rule_code: str
    alert_type: str
    severity: AlertSeverity
    title: str
    description: str
    source_type: str
    source_id: UUID
    triggered_at: datetime


class RedFlagRuleEngine:
    def evaluate(self, entry: DailyEntry, recent_entries: list[DailyEntry]) -> list[RedFlagMatch]:
        matches: dict[str, RedFlagMatch] = {}
        triggered_at = utcnow()

        if self._has_symptom(entry, CHEST_PAIN_KEYWORDS) or self._has_body_location(entry, ("torace", "chest")):
            matches["chest_pain"] = self._build_match(
                entry=entry,
                rule_code="chest_pain",
                alert_type="chest_pain",
                severity=AlertSeverity.URGENCY,
                title="Urgenza: dolore toracico riportato",
                description="Si osserva un sintomo compatibile con dolore toracico. Non e una diagnosi, ma e prudente valutare rapidamente un supporto medico.",
                triggered_at=triggered_at,
            )

        if self._has_symptom(entry, DYSPNEA_KEYWORDS):
            matches["dyspnea"] = self._build_match(
                entry=entry,
                rule_code="dyspnea",
                alert_type="dyspnea",
                severity=AlertSeverity.URGENCY,
                title="Urgenza: dispnea o fiato corto segnalati",
                description="E presente un sintomo compatibile con dispnea. E prudente considerare un contatto medico urgente o una valutazione rapida.",
                triggered_at=triggered_at,
            )

        saturation = self._latest_numeric_vital(entry, LOW_SAT_TYPES)
        if saturation is not None:
            if saturation < 90:
                matches["low_oxygen_saturation"] = self._build_match(
                    entry=entry,
                    rule_code="low_oxygen_saturation",
                    alert_type="low_oxygen_saturation",
                    severity=AlertSeverity.URGENCY,
                    title="Urgenza: saturazione molto bassa",
                    description=f"Si osserva una saturazione riportata di {saturation:.0f}%, valore compatibile con urgenza clinica.",
                    triggered_at=triggered_at,
                )
            elif saturation < 92:
                matches["low_oxygen_saturation"] = self._build_match(
                    entry=entry,
                    rule_code="low_oxygen_saturation",
                    alert_type="low_oxygen_saturation",
                    severity=AlertSeverity.CONTACT_DOCTOR,
                    title="Contatta il medico: saturazione bassa",
                    description=f"Si osserva una saturazione riportata di {saturation:.0f}%, utile un confronto medico tempestivo.",
                    triggered_at=triggered_at,
                )

        if self._has_symptom(entry, NEURO_KEYWORDS):
            matches["neurologic_symptoms"] = self._build_match(
                entry=entry,
                rule_code="neurologic_symptoms",
                alert_type="neurologic_symptoms",
                severity=AlertSeverity.URGENCY,
                title="Urgenza: sintomi neurologici improvvisi",
                description="Sono presenti sintomi compatibili con un disturbo neurologico improvviso. E prudente richiedere rapidamente assistenza medica.",
                triggered_at=triggered_at,
            )

        if self._has_symptom(entry, BLEEDING_KEYWORDS):
            matches["important_bleeding"] = self._build_match(
                entry=entry,
                rule_code="important_bleeding",
                alert_type="important_bleeding",
                severity=AlertSeverity.URGENCY,
                title="Urgenza: sanguinamento importante segnalato",
                description="Si osserva un sintomo compatibile con sanguinamento importante. E prudente una valutazione medica urgente.",
                triggered_at=triggered_at,
            )

        temperature = self._latest_numeric_vital(entry, TEMPERATURE_TYPES)
        if temperature is not None:
            all_recent_temperatures = [
                value
                for recent_entry in recent_entries
                for value in [self._latest_numeric_vital(recent_entry, TEMPERATURE_TYPES)]
                if value is not None
            ]
            max_recent_temperature = max(all_recent_temperatures) if all_recent_temperatures else temperature
            if max_recent_temperature >= 40:
                matches["persistent_high_fever"] = self._build_match(
                    entry=entry,
                    rule_code="persistent_high_fever",
                    alert_type="persistent_high_fever",
                    severity=AlertSeverity.URGENCY,
                    title="Urgenza: febbre molto alta",
                    description=f"Si osservano temperature recenti fino a {max_recent_temperature:.1f}. In presenza di febbre molto alta e prudente una valutazione rapida.",
                    triggered_at=triggered_at,
                )
            elif max_recent_temperature >= 39 and sum(value >= 38.5 for value in all_recent_temperatures) >= 2:
                matches["persistent_high_fever"] = self._build_match(
                    entry=entry,
                    rule_code="persistent_high_fever",
                    alert_type="persistent_high_fever",
                    severity=AlertSeverity.CONTACT_DOCTOR,
                    title="Contatta il medico: febbre alta persistente",
                    description="Si osserva una febbre alta in piu rilevazioni recenti. Potrebbe essere utile un confronto medico tempestivo.",
                    triggered_at=triggered_at,
                )

        if self._is_rapid_worsening(entry):
            severity = AlertSeverity.CONTACT_DOCTOR if (entry.general_pain or 0) >= 8 else AlertSeverity.ATTENTION
            matches["rapid_worsening"] = self._build_match(
                entry=entry,
                rule_code="rapid_worsening",
                alert_type="rapid_worsening",
                severity=severity,
                title="Attenzione: possibile peggioramento rapido",
                description="Sono presenti elementi descrittivi compatibili con un peggioramento rapido. Monitorare con attenzione e valutare un contatto medico se il quadro continua a peggiorare.",
                triggered_at=triggered_at,
            )

        return list(matches.values())

    def _build_match(
        self,
        *,
        entry: DailyEntry,
        rule_code: str,
        alert_type: str,
        severity: AlertSeverity,
        title: str,
        description: str,
        triggered_at: datetime,
    ) -> RedFlagMatch:
        return RedFlagMatch(
            rule_code=rule_code,
            alert_type=alert_type,
            severity=severity,
            title=title,
            description=description,
            source_type="daily_entry",
            source_id=entry.id,
            triggered_at=triggered_at,
        )

    @staticmethod
    def _has_symptom(entry: DailyEntry, keywords: tuple[str, ...]) -> bool:
        for symptom in entry.symptoms:
            text = f"{symptom.symptom_code} {symptom.body_location or ''}".lower()
            if any(keyword in text for keyword in keywords):
                return True
        return False

    @staticmethod
    def _has_body_location(entry: DailyEntry, keywords: tuple[str, ...]) -> bool:
        for symptom in entry.symptoms:
            text = (symptom.body_location or "").lower()
            if any(keyword in text for keyword in keywords):
                return True
        return False

    @staticmethod
    def _latest_numeric_vital(entry: DailyEntry, types: tuple[str, ...]) -> float | None:
        matching = [
            vital
            for vital in entry.vitals
            if any(candidate in vital.type.lower() for candidate in types)
        ]
        if not matching:
            return None
        matching.sort(key=lambda item: item.measured_at, reverse=True)
        return RedFlagRuleEngine._parse_numeric(matching[0].value)

    @staticmethod
    def _parse_numeric(value: str) -> float | None:
        match = _NUMBER_RE.search(value.replace(",", "."))
        if match is None:
            return None
        try:
            return float(match.group(0))
        except ValueError:
            return None

    @staticmethod
    def _is_rapid_worsening(entry: DailyEntry) -> bool:
        notes = (entry.general_notes or "").lower()
        if any(keyword in notes for keyword in RAPID_WORSENING_KEYWORDS):
            return True
        high_severity_symptoms = [symptom for symptom in entry.symptoms if (symptom.severity or 0) >= 8]
        if len(high_severity_symptoms) >= 2:
            return True
        return (entry.general_pain or 0) >= 8 and (entry.energy_level or 10) <= 3
