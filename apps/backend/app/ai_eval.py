from __future__ import annotations

import argparse
import unicodedata
from dataclasses import dataclass
from pathlib import Path
import sys

from app.ai.summary_provider import build_summary_provider
from app.ai_smoke import load_payload
from app.core.config import get_settings


_DEFAULT_FIXTURES_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "ai_eval"


@dataclass(slots=True)
class EvalCaseResult:
    case_name: str
    provider_name: str
    model_name: str
    summary_length: int
    checks: dict[str, bool]
    failures: list[str]

    @property
    def passed(self) -> bool:
        return not self.failures


def _normalize(text: str) -> str:
    normalized = unicodedata.normalize("NFKD", text)
    stripped = "".join(char for char in normalized if not unicodedata.combining(char))
    return stripped.lower()


def _load_case_paths(raw_inputs: list[str] | None) -> list[Path]:
    inputs = raw_inputs or []
    if not inputs:
        inputs = [str(_DEFAULT_FIXTURES_DIR)]

    case_paths: list[Path] = []
    for raw_input in inputs:
        path = Path(raw_input)
        if not path.exists():
            raise FileNotFoundError(path)
        if path.is_dir():
            case_paths.extend(sorted(path.glob("*.json")))
        else:
            case_paths.append(path)

    unique_paths = list(dict.fromkeys(case_paths))
    if not unique_paths:
        raise FileNotFoundError("No JSON payloads found for AI evaluation")
    return unique_paths


def _evaluate_checks(content: str, min_length: int) -> dict[str, bool]:
    normalized = _normalize(content)
    return {
        "length": len(content) >= min_length,
        "period": any(token in normalized for token in ("periodo considerato", "periodo analizzato")),
        "context": any(
            token in normalized for token in ("contesto del paziente", "contesto paziente")
        ),
        "trend": any(
            token in normalized for token in ("andamento osservato", "elementi principali osservati")
        ),
        "documents": any(
            token in normalized for token in ("esami/documenti recenti", "documenti ed esami recenti")
        ),
        "medical_follow_up": any(
            token in normalized for token in ("quando e perche parlare con il medico", "quando parlarne con il medico")
        ),
        "disclaimer": any(
            token in normalized
            for token in (
                "non e una diagnosi",
                "non e una diagnosi o prescrizione",
                "non sostituisce il medico",
                "non costituisce diagnosi",
            )
        ),
        "markdown_clean": "**" not in content and "```" not in content,
    }


def _evaluate_case(case_path: Path, provider, min_length: int) -> EvalCaseResult:
    payload = load_payload(case_path)
    result = provider.generate_result(payload)
    content = result.content.strip()
    checks = _evaluate_checks(content, min_length)
    failures = [name for name, ok in checks.items() if not ok]
    return EvalCaseResult(
        case_name=case_path.stem,
        provider_name=result.provider_name,
        model_name=result.model_name,
        summary_length=len(content),
        checks=checks,
        failures=failures,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="ClinDiary AI evaluation for curated cases")
    parser.add_argument(
        "--inputs",
        nargs="*",
        default=None,
        help="JSON payload file(s) or directories with curated AI evaluation cases",
    )
    parser.add_argument(
        "--min-length",
        type=int,
        default=700,
        help="Minimum accepted summary length for each case",
    )
    parser.add_argument(
        "--require-local-runtime",
        action="store_true",
        help="Fail if the local runtime is unavailable and the backend falls back to rule_based",
    )
    args = parser.parse_args(argv)

    try:
        case_paths = _load_case_paths(args.inputs)
    except FileNotFoundError as exc:
        print(f"cases_not_found={exc}")
        return 2

    provider = build_summary_provider(get_settings())
    print(f"cases={len(case_paths)}")
    print(f"provider={provider.provider_name}")
    print(f"model={getattr(provider, 'model_name', 'unknown')}")

    if args.require_local_runtime and provider.provider_name == "rule_based":
        print("local_runtime_required=true")
        return 4

    results: list[EvalCaseResult] = []
    for case_path in case_paths:
        try:
            result = _evaluate_case(case_path, provider, args.min_length)
        except Exception as exc:
            print(f"case={case_path.stem} status=error error={exc}")
            return 3

        results.append(result)
        status = "pass" if result.passed else "fail"
        failed_checks = ",".join(result.failures) if result.failures else "-"
        print(
            "case="
            f"{result.case_name} status={status} provider={result.provider_name} "
            f"model={result.model_name} length={result.summary_length} "
            f"checks={sum(result.checks.values())}/{len(result.checks)} "
            f"failed={failed_checks}"
        )

    failures = [result for result in results if not result.passed]
    if failures:
        print(f"failed_cases={len(failures)}")
        return 5

    print("evaluation=pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
