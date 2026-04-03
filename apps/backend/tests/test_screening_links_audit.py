from __future__ import annotations

from app.screening_links_audit import audit_screening_portals, main


class _FakeResponse:
    def __init__(self, status: int) -> None:
        self.status = status

    def __enter__(self) -> "_FakeResponse":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        return None

    def getcode(self) -> int:
        return self.status


def test_audit_screening_portals_marks_success_and_failure() -> None:
    portals = {
        "IT-LOM": "https://example.org/lombardia",
        "IT-LAZ": "https://example.org/lazio",
    }

    def fake_opener(request, timeout_seconds):
        if request.full_url.endswith("/lombardia"):
            return _FakeResponse(200)
        raise OSError("network down")

    results = audit_screening_portals(portals, opener=fake_opener)

    assert len(results) == 2
    result_map = {result.region_code: result for result in results}
    assert result_map["IT-LOM"].ok is True
    assert result_map["IT-LOM"].status_code == 200
    assert result_map["IT-LAZ"].ok is False
    assert result_map["IT-LAZ"].error is not None


def test_audit_screening_portals_main_returns_nonzero_on_failures(capsys) -> None:
    from app import screening_links_audit

    original = screening_links_audit.audit_screening_portals
    try:
        screening_links_audit.audit_screening_portals = lambda timeout_seconds=10.0: [
            type(
                "Result",
                (),
                {
                    "region_code": "IT-LOM",
                    "url": "https://example.org",
                    "ok": False,
                    "status_code": 503,
                    "error": None,
                },
            )()
        ]
        exit_code = main([])
    finally:
        screening_links_audit.audit_screening_portals = original

    captured = capsys.readouterr()
    assert exit_code == 1
    assert "FAIL" in captured.out
