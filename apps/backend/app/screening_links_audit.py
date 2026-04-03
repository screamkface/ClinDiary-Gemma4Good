from __future__ import annotations

import argparse
from dataclasses import dataclass
from typing import Callable
from urllib.error import URLError
from urllib.request import Request, urlopen

from app.services.screening_service import VERIFIED_REGIONAL_SCREENING_PORTALS


@dataclass(slots=True)
class PortalAuditResult:
    region_code: str
    url: str
    ok: bool
    status_code: int | None
    error: str | None = None


def audit_screening_portals(
    portals: dict[str, str] | None = None,
    *,
    timeout_seconds: float = 10.0,
    opener: Callable[[Request, float], object] = urlopen,
) -> list[PortalAuditResult]:
    portal_map = portals or VERIFIED_REGIONAL_SCREENING_PORTALS
    results: list[PortalAuditResult] = []

    for region_code, url in sorted(portal_map.items()):
        request = Request(url, method="GET", headers={"User-Agent": "ClinDiary-ScreeningAudit/1.0"})
        try:
            with opener(request, timeout_seconds) as response:  # type: ignore[arg-type]
                status_code = getattr(response, "status", None) or response.getcode()
                ok = status_code is not None and 200 <= int(status_code) < 400
                results.append(
                    PortalAuditResult(
                        region_code=region_code,
                        url=url,
                        ok=ok,
                        status_code=int(status_code) if status_code is not None else None,
                    )
                )
        except URLError as error:
            results.append(
                PortalAuditResult(
                    region_code=region_code,
                    url=url,
                    ok=False,
                    status_code=None,
                    error=str(error.reason) if getattr(error, "reason", None) else str(error),
                )
            )
        except Exception as error:  # pragma: no cover - defensive network guard
            results.append(
                PortalAuditResult(
                    region_code=region_code,
                    url=url,
                    ok=False,
                    status_code=None,
                    error=str(error),
                )
            )

    return results


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Audit dei portali regionali screening configurati in ClinDiary.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=10.0,
        help="Timeout in secondi per ogni richiesta HTTP.",
    )
    args = parser.parse_args(argv)

    results = audit_screening_portals(timeout_seconds=args.timeout)
    failures = [result for result in results if not result.ok]

    for result in results:
        if result.ok:
            print(f"{result.region_code}: OK {result.status_code} {result.url}")
        else:
            print(f"{result.region_code}: FAIL {result.error or 'unknown error'} {result.url}")

    print(f"checked={len(results)} failures={len(failures)}")
    return 0 if not failures else 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
