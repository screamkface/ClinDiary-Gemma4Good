from datetime import date

from app.core.config import get_settings


def test_billing_status_lists_free_and_paid_catalog(client, free_auth_headers):
    status_response = client.get("/api/v1/billing/me", headers=free_auth_headers)

    assert status_response.status_code == 200
    body = status_response.json()
    assert body["current_plan"]["code"] == "free"
    assert body["has_active_paid_subscription"] is False
    assert any(plan["code"] == "ai_plus_monthly" for plan in body["available_plans"])
    assert any(plan["code"] == "ai_plus_yearly" for plan in body["available_plans"])


def test_free_user_gets_feature_locked_for_ai_endpoints(client, free_auth_headers):
    insight_response = client.get("/api/v1/insights/daily", headers=free_auth_headers)
    assert insight_response.status_code == 402
    insight_detail = insight_response.json()["detail"]
    assert insight_detail["code"] == "feature_locked"
    assert insight_detail["feature_code"] == "ai_daily_summary"

    document_query_response = client.post(
        "/api/v1/documents/query",
        headers=free_auth_headers,
        json={"question": "Riassumi i miei referti recenti"},
    )
    assert document_query_response.status_code == 402
    assert document_query_response.json()["detail"]["feature_code"] == "ai_document_query"

    report_response = client.post(
        "/api/v1/reports/generate",
        headers=free_auth_headers,
        json={"report_type": "weekly_summary"},
    )
    assert report_response.status_code == 402
    assert report_response.json()["detail"]["feature_code"] == "ai_report_generation"


def test_free_history_remains_available_without_ai_rollups(client, free_auth_headers):
    target_date = date(2026, 3, 20)
    entry_response = client.post(
        "/api/v1/daily-entries",
        headers=free_auth_headers,
        json={
            "entry_date": target_date.isoformat(),
            "energy_level": 7,
            "mood_level": 7,
            "stress_level": 4,
        },
    )
    assert entry_response.status_code == 201

    history_response = client.get(
        f"/api/v1/history/day?target_date={target_date.isoformat()}",
        headers=free_auth_headers,
    )
    assert history_response.status_code == 200
    body = history_response.json()
    assert body["daily_entry"]["entry_date"] == target_date.isoformat()
    assert body["daily_summary"] is None
    assert body["weekly_summary"] is None
    assert body["monthly_summary"] is None


def test_debug_plan_activation_unlocks_ai_endpoints(client, free_auth_headers):
    activation_response = client.post(
        "/api/v1/billing/dev/activate",
        headers=free_auth_headers,
        json={"plan_code": "ai_plus_monthly"},
    )
    assert activation_response.status_code == 200
    activation_body = activation_response.json()["status"]
    assert activation_body["current_plan"]["code"] == "ai_plus_monthly"
    assert activation_body["has_active_paid_subscription"] is True

    insight_response = client.get("/api/v1/insights/daily", headers=free_auth_headers)
    assert insight_response.status_code == 200

    cancel_response = client.post("/api/v1/billing/dev/cancel", headers=free_auth_headers)
    assert cancel_response.status_code == 200
    assert cancel_response.json()["status"]["current_plan"]["code"] == "free"


def test_hackathon_demo_mode_unlocks_ai_for_demo_user(client, monkeypatch):
    monkeypatch.setenv("HACKATHON_DEMO_MODE", "true")
    get_settings.cache_clear()

    try:
        auth_response = client.post(
            "/api/v1/auth/register",
            json={"email": "demo@clindiary.app", "password": "StrongPass123!"},
        )
        assert auth_response.status_code == 201
        access_token = auth_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {access_token}"}
        onboarding_response = client.post(
            "/api/v1/profile/onboarding/complete",
            headers=headers,
            json={
                "health_data_consent": True,
                "ai_external_consent": False,
                "first_name": "Demo",
                "last_name": "User",
                "birth_date": "1992-04-10",
                "biological_sex": "female",
                "smoker": False,
            },
        )
        assert onboarding_response.status_code == 200

        status_response = client.get("/api/v1/billing/me", headers=headers)
        assert status_response.status_code == 200
        body = status_response.json()
        assert body["hackathon_demo_mode"] is True
        assert body["current_plan"]["code"] == "ai_plus_yearly"
        assert body["has_active_paid_subscription"] is True
        assert body["active_subscription"]["plan"]["code"] == "ai_plus_yearly"
        assert "ai_daily_summary" in body["entitlement_codes"]

        insight_response = client.get("/api/v1/insights/daily", headers=headers)
        assert insight_response.status_code == 200
    finally:
        monkeypatch.delenv("HACKATHON_DEMO_MODE", raising=False)
        get_settings.cache_clear()
