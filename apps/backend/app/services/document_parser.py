from __future__ import annotations

from dataclasses import dataclass
from datetime import date
import re


_NUMBER_RE = re.compile(r"^-?\d+(?:[.,]\d+)?$")
_RANGE_RE = re.compile(r"(?P<min>-?\d+(?:[.,]\d+)?)\s*-\s*(?P<max>-?\d+(?:[.,]\d+)?)")
_THRESHOLD_RE = re.compile(r"(?P<op><=?|>=?)\s*(?P<value>-?\d+(?:[.,]\d+)?)")
_FLAG_RE = re.compile(r"^(H|L|N)$", re.IGNORECASE)
_STANDALONE_UNIT_TOKENS = {"fl", "pg", "kg", "mg", "ng", "g", "dl", "ml", "ul"}


@dataclass(slots=True)
class ParsedLabResult:
    analyte_name: str
    value: str
    unit: str | None
    ref_min: float | None
    ref_max: float | None
    abnormal_flag: bool | None
    confidence_score: float


@dataclass(slots=True)
class ParsedLabPanel:
    panel_name: str
    panel_date: date | None
    confidence_score: float
    results: list[ParsedLabResult]


@dataclass(slots=True)
class ParsedImagingReport:
    exam_type: str | None
    body_part: str | None
    report_text: str
    impression: str | None
    confidence_score: float


class DocumentParser:
    def parse_lab_text(self, title: str, text: str) -> ParsedLabPanel | None:
        lines = self._normalize_lines(text)
        inline_results = [parsed for line in lines if (parsed := self._parse_lab_line(line)) is not None]
        columnar_results = self._parse_columnar_lab_results(lines)
        results = self._deduplicate_results([*inline_results, *columnar_results])

        if not lines or not results:
            return None

        panel_name = title.strip() or self._derive_panel_name(lines)
        confidence_score = 0.88 if columnar_results else 0.84
        return ParsedLabPanel(
            panel_name=panel_name,
            panel_date=None,
            confidence_score=confidence_score,
            results=results,
        )

    def parse_imaging_text(self, title: str, text: str) -> ParsedImagingReport | None:
        lines = [line.strip() for line in text.splitlines() if line.strip()]
        if not lines:
            return None

        text_lower = text.lower()
        exam_type = self._match_first(title + "\n" + text, ("RX", "TC", "RM", "RMN", "Ecografia"))
        body_part = self._match_first(
            text_lower,
            ("torace", "addome", "cranio", "spalla", "rachide", "ginocchio"),
        )

        impression = None
        for line in lines:
            lowered = line.lower()
            if lowered.startswith("impression:") or lowered.startswith("conclusioni:"):
                impression = line.split(":", 1)[1].strip()
                break

        return ParsedImagingReport(
            exam_type=exam_type,
            body_part=body_part.capitalize() if body_part else None,
            report_text=text.strip(),
            impression=impression,
            confidence_score=0.8,
        )

    def _parse_lab_line(self, line: str) -> ParsedLabResult | None:
        tokens = line.split()
        value_index = next(
            (index for index, token in enumerate(tokens) if _NUMBER_RE.match(token.replace(",", "."))),
            None,
        )
        if value_index is None or value_index == 0 or value_index >= len(tokens):
            return None

        name = " ".join(tokens[:value_index]).strip(":-")
        if not self._looks_like_analyte_name(name):
            return None

        value = tokens[value_index].replace(",", ".")
        unit = tokens[value_index + 1] if value_index + 1 < len(tokens) else None
        if unit is not None and not self._looks_like_unit(unit):
            return None

        trailing = tokens[value_index + 2 :] if value_index + 2 < len(tokens) else []
        trailing_text = " ".join(trailing).strip()
        ref_min, ref_max = self._parse_reference_bounds(trailing_text)
        abnormal_flag = self._resolve_abnormal_flag(
            flag_token=self._extract_flag_token(trailing),
            value=value,
            ref_min=ref_min,
            ref_max=ref_max,
        )

        if not name or unit is None:
            return None

        return ParsedLabResult(
            analyte_name=name,
            value=value,
            unit=unit,
            ref_min=ref_min,
            ref_max=ref_max,
            abnormal_flag=abnormal_flag,
            confidence_score=0.84,
        )

    def _parse_columnar_lab_results(self, lines: list[str]) -> list[ParsedLabResult]:
        if not lines:
            return []

        start_index = self._find_lab_table_start(lines)
        cursor = start_index if start_index is not None else 0
        results: list[ParsedLabResult] = []

        while cursor < len(lines):
            parsed, consumed = self._parse_columnar_lab_row(lines, cursor)
            if parsed is not None:
                results.append(parsed)
                cursor += consumed
                continue
            cursor += 1

        return results

    def _parse_columnar_lab_row(
        self,
        lines: list[str],
        start_index: int,
    ) -> tuple[ParsedLabResult | None, int]:
        analyte = lines[start_index]
        if not self._looks_like_analyte_name(analyte):
            return None, 1

        cursor = start_index + 1
        if cursor >= len(lines) or not self._looks_like_numeric_value(lines[cursor]):
            return None, 1
        value = lines[cursor].replace(",", ".")
        cursor += 1

        if cursor >= len(lines) or not self._looks_like_unit(lines[cursor]):
            return None, 1
        unit = lines[cursor]
        cursor += 1

        ref_min = None
        ref_max = None
        if cursor < len(lines):
            ref_min, ref_max = self._parse_reference_bounds(lines[cursor])
            if ref_min is not None or ref_max is not None:
                cursor += 1

        flag_token = None
        if cursor < len(lines) and _FLAG_RE.match(lines[cursor]):
            flag_token = lines[cursor]
            cursor += 1

        if ref_min is None and ref_max is None and flag_token is None:
            return None, 1

        return (
            ParsedLabResult(
                analyte_name=analyte,
                value=value,
                unit=unit,
                ref_min=ref_min,
                ref_max=ref_max,
                abnormal_flag=self._resolve_abnormal_flag(
                    flag_token=flag_token,
                    value=value,
                    ref_min=ref_min,
                    ref_max=ref_max,
                ),
                confidence_score=0.9,
            ),
            cursor - start_index,
        )

    def _find_lab_table_start(self, lines: list[str]) -> int | None:
        for index, line in enumerate(lines):
            if line.lower() != "esame":
                continue

            window = {entry.lower() for entry in lines[index : index + 5]}
            if "risultato" in window and "unita" in window and "valori di riferimento" in window:
                return min(index + 5, len(lines))

        return None

    @staticmethod
    def _normalize_lines(text: str) -> list[str]:
        return [re.sub(r"\s+", " ", line).strip() for line in text.splitlines() if line.strip()]

    @staticmethod
    def _deduplicate_results(results: list[ParsedLabResult]) -> list[ParsedLabResult]:
        deduplicated: list[ParsedLabResult] = []
        seen: set[tuple[str, str, str | None, float | None, float | None]] = set()

        for result in results:
            key = (
                result.analyte_name.casefold(),
                result.value,
                result.unit.casefold() if result.unit else None,
                result.ref_min,
                result.ref_max,
            )
            if key in seen:
                continue
            seen.add(key)
            deduplicated.append(result)

        return deduplicated

    def _derive_panel_name(self, lines: list[str]) -> str:
        for line in lines:
            if self._looks_like_analyte_name(line):
                continue
            if self._is_ignored_line(line) or self._is_header_line(line):
                continue
            return line
        return "Referto laboratorio"

    @staticmethod
    def _looks_like_numeric_value(line: str) -> bool:
        return bool(_NUMBER_RE.match(line.replace(" ", "").replace(",", ".")))

    def _looks_like_unit(self, line: str) -> bool:
        normalized = line.strip()
        if not normalized or " " in normalized:
            return False
        if self._looks_like_numeric_value(normalized):
            return False
        if _FLAG_RE.match(normalized):
            return False
        ref_min, ref_max = self._parse_reference_bounds(normalized)
        if ref_min is not None or ref_max is not None:
            return False
        if re.fullmatch(r"[A-Za-z]+", normalized):
            return normalized.casefold() in _STANDALONE_UNIT_TOKENS
        return (
            any(character.isalpha() for character in normalized)
            and any(character.isdigit() or character in "/%^" for character in normalized)
        ) or "%" in normalized

    def _looks_like_analyte_name(self, line: str) -> bool:
        normalized = line.strip()
        if not normalized:
            return False
        if self._looks_like_numeric_value(normalized) or self._looks_like_unit(normalized):
            return False
        if self._is_header_line(normalized) or self._is_ignored_line(normalized):
            return False
        ref_min, ref_max = self._parse_reference_bounds(normalized)
        if ref_min is not None or ref_max is not None:
            return False
        if _FLAG_RE.match(normalized):
            return False
        return any(character.isalpha() for character in normalized)

    @staticmethod
    def _extract_flag_token(tokens: list[str]) -> str | None:
        for token in tokens:
            if _FLAG_RE.match(token):
                return token
        return None

    @staticmethod
    def _parse_reference_bounds(text: str) -> tuple[float | None, float | None]:
        normalized = text.replace(",", ".").strip()
        if not normalized:
            return None, None

        range_match = _RANGE_RE.search(normalized)
        if range_match is not None:
            return float(range_match.group("min")), float(range_match.group("max"))

        threshold_match = _THRESHOLD_RE.search(normalized)
        if threshold_match is None:
            return None, None

        threshold_value = float(threshold_match.group("value"))
        operator = threshold_match.group("op")
        if operator.startswith("<"):
            return None, threshold_value
        return threshold_value, None

    def _resolve_abnormal_flag(
        self,
        *,
        flag_token: str | None,
        value: str,
        ref_min: float | None,
        ref_max: float | None,
    ) -> bool | None:
        if flag_token is not None:
            normalized = flag_token.upper()
            if normalized == "N":
                return False
            return normalized in {"H", "L"}

        try:
            numeric_value = float(value.replace(",", "."))
        except ValueError:
            return None

        if ref_min is not None and numeric_value < ref_min:
            return True
        if ref_max is not None and numeric_value > ref_max:
            return True
        if ref_min is not None or ref_max is not None:
            return False
        return None

    @staticmethod
    def _is_header_line(line: str) -> bool:
        normalized = line.casefold()
        return normalized in {
            "esame",
            "risultato",
            "unita",
            "valori di riferimento",
            "flag",
        }

    @staticmethod
    def _is_ignored_line(line: str) -> bool:
        normalized = line.casefold()
        ignored_prefixes = (
            "facsimile",
            "documento dimostrativo",
            "pagina ",
            "laboratorio analisi",
            "referto di laboratorio",
            "paziente",
            "data di nascita",
            "sesso",
            "id referto",
            "data prelievo",
            "data refertazione",
            "avvertenza",
            "risultati principali",
            "commenti automatici",
            "legenda flag",
            "valore superiore al range",
            "valore inferiore al range",
            "firma digitale",
            "nota:",
        )
        return normalized.startswith(ignored_prefixes)

    @staticmethod
    def _match_first(text: str, candidates: tuple[str, ...]) -> str | None:
        lowered = text.lower()
        for candidate in candidates:
            if candidate.lower() in lowered:
                return candidate
        return None

