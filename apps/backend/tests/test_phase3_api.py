from datetime import date, timedelta

from sqlalchemy import select

from app.models.ai_summary import AiSummary
from app.models.enums import AiSummaryType
from app.ai.summary_provider import SummaryGenerationResult
from app.services.insight_service import InsightService
from app.models.user import User
from app.workers.summary_tasks import sync_daily_summaries_task


def _create_entry(client, auth_headers, entry_date: date):
    response = client.post(
        "/api/v1/daily-entries",
        headers=auth_headers,
        json={
            "entry_date": entry_date.isoformat(),
            "energy_level": 4,
            "mood_level": 5,
            "stress_level": 7,
            "general_pain": 7,
            "general_notes": "Sintomi in peggioramento rapido nelle ultime ore.",
        },
    )
    assert response.status_code == 201
    return response.json()["id"]


def test_alerts_insights_and_report_flow(client, auth_headers):
    today = date(2026, 3, 20)
    yesterday = today - timedelta(days=1)

    entry_id = _create_entry(client, auth_headers, today)
    fever_entry_id = _create_entry(client, auth_headers, yesterday)

    symptom_response = client.post(
        f"/api/v1/daily-entries/{entry_id}/symptoms",
        headers=auth_headers,
        json={
            "symptom_code": "chest_pain",
            "severity": 8,
            "body_location": "torace",
        },
    )
    assert symptom_response.status_code == 201

    vital_response = client.post(
        f"/api/v1/daily-entries/{entry_id}/vitals",
        headers=auth_headers,
        json={"type": "spo2", "value": "89", "unit": "%"},
    )
    assert vital_response.status_code == 201

    fever_yesterday = client.post(
        f"/api/v1/daily-entries/{fever_entry_id}/vitals",
        headers=auth_headers,
        json={"type": "temperature", "value": "38.8", "unit": "C"},
    )
    assert fever_yesterday.status_code == 201

    fever_today = client.post(
        f"/api/v1/daily-entries/{entry_id}/vitals",
        headers=auth_headers,
        json={"type": "temperature", "value": "39.1", "unit": "C"},
    )
    assert fever_today.status_code == 201

    alerts_response = client.get("/api/v1/alerts", headers=auth_headers)
    assert alerts_response.status_code == 200
    alerts = alerts_response.json()
    assert any(alert["alert_type"] == "chest_pain" for alert in alerts)
    assert any(alert["alert_type"] == "low_oxygen_saturation" for alert in alerts)

    weekly_insight = client.get("/api/v1/insights/weekly", headers=auth_headers)
    assert weekly_insight.status_code == 200
    weekly_body = weekly_insight.json()
    assert weekly_body["summary_type"] == "weekly"
    assert weekly_body["provider_name"] == "rule_based"
    assert weekly_body["model_name"] == "clindiary-safe-summary"
    assert "Periodo analizzato" in weekly_body["content"]
    assert "Questa sintesi ha finalita organizzativa" in weekly_body["content"]

    monthly_insight = client.get("/api/v1/insights/monthly", headers=auth_headers)
    assert monthly_insight.status_code == 200
    assert monthly_insight.json()["summary_type"] == "monthly"

    pre_visit_insight = client.get("/api/v1/insights/pre-visit", headers=auth_headers)
    assert pre_visit_insight.status_code == 200
    assert pre_visit_insight.json()["summary_type"] == "pre_visit"

    history_response = client.get(
        f"/api/v1/history/day?target_date={today.isoformat()}",
        headers=auth_headers,
    )
    assert history_response.status_code == 200
    history_body = history_response.json()
    assert history_body["daily_entry"]["entry_date"] == today.isoformat()
    assert history_body["daily_summary"]["summary_type"] == "daily"
    assert "Periodo analizzato" in history_body["daily_summary"]["content"]

    activity_days_response = client.get(
        f"/api/v1/history/activity-days?start_date={yesterday.isoformat()}&end_date={today.isoformat()}",
        headers=auth_headers,
    )
    assert activity_days_response.status_code == 200
    assert today.isoformat() in activity_days_response.json()["activity_dates"]

    report_response = client.post(
        "/api/v1/reports/generate",
        headers=auth_headers,
        json={"report_type": "weekly_summary", "reference_date": today.isoformat()},
    )
    assert report_response.status_code == 201
    report_body = report_response.json()
    assert report_body["report_type"] == "weekly_summary"
    assert report_body["download_url"].startswith("/api/v1/reports/")
    assert "Riassunto AI prudente" in report_body["content_text"]

    report_download = client.get(report_body["download_url"])
    assert report_download.status_code == 200
    assert report_download.headers["content-type"].startswith("application/pdf")

    timeline_response = client.get("/api/v1/timeline", headers=auth_headers)
    assert timeline_response.status_code == 200
    timeline_types = [item["event_type"] for item in timeline_response.json()]
    assert "ai_alert" in timeline_types
    assert "report_generated" in timeline_types

    open_alert = alerts[0]
    resolve_response = client.post(
        f"/api/v1/alerts/{open_alert['id']}/resolve",
        headers=auth_headers,
        json={"resolution_notes": "Preso in carico durante follow-up"},
    )
    assert resolve_response.status_code == 200
    assert resolve_response.json()["status"] == "resolved"


def test_summary_sync_task_generates_daily_rollups(client, auth_headers):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)

    result = sync_daily_summaries_task(target_date.isoformat())

    assert result["summary_type"] == "daily"
    assert result["generated"] >= 1


def test_daily_insight_is_reused_without_regeneration(client, auth_headers):
    target_date = date(2026, 3, 20)
    entry_id = _create_entry(client, auth_headers, target_date)

    first_response = client.get(
        f"/api/v1/insights/daily?reference_date={target_date.isoformat()}",
        headers=auth_headers,
    )
    assert first_response.status_code == 200
    first_body = first_response.json()

    symptom_response = client.post(
        f"/api/v1/daily-entries/{entry_id}/symptoms",
        headers=auth_headers,
        json={
            "symptom_code": "headache",
            "severity": 5,
        },
    )
    assert symptom_response.status_code == 201

    second_response = client.get(
        f"/api/v1/insights/daily?reference_date={target_date.isoformat()}",
        headers=auth_headers,
    )
    assert second_response.status_code == 200
    second_body = second_response.json()

    assert second_body["id"] == first_body["id"]
    assert second_body["content"] == first_body["content"]
    assert second_body["generated_at"] == first_body["generated_at"]


def test_existing_daily_insight_is_reused_even_if_brief(client, auth_headers, db_session):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)
    user = db_session.scalar(select(User).where(User.email == "patient@example.com"))
    assert user is not None

    broken_summary = AiSummary(
        patient_id=user.profile.id,
        summary_type=AiSummaryType.DAILY,
        period_start=target_date,
        period_end=target_date,
        content="Di seguito un riepilogo clinico prudente basato sui dati disponibili.",
        provider_name="local_gemma4",
        model_name="gemma-4-e2b",
    )
    db_session.add(broken_summary)
    db_session.commit()
    db_session.refresh(broken_summary)
    original_content = broken_summary.content

    response = client.get(
        f"/api/v1/insights/daily?reference_date={target_date.isoformat()}",
        headers=auth_headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == str(broken_summary.id)
    assert body["content"] == original_content
    assert body["provider_name"] == "local_gemma4"


def test_daily_insight_regenerate_endpoint_forces_new_generation(client, auth_headers):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)

    first_response = client.get(
        f"/api/v1/insights/daily?reference_date={target_date.isoformat()}",
        headers=auth_headers,
    )
    assert first_response.status_code == 200
    first_body = first_response.json()

    regenerate_response = client.post(
        f"/api/v1/insights/daily/regenerate?reference_date={target_date.isoformat()}",
        headers=auth_headers,
    )
    assert regenerate_response.status_code == 200
    regenerate_body = regenerate_response.json()

    assert regenerate_body["id"] == first_body["id"]
    assert regenerate_body["generated_at"] != first_body["generated_at"]


def test_private_local_daily_insight_is_transient_and_does_not_overwrite_persisted_summary(
    client,
    auth_headers,
    db_session,
    monkeypatch,
):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)

    standard_response = client.get(
        f"/api/v1/insights/daily?reference_date={target_date.isoformat()}",
        headers=auth_headers,
    )
    assert standard_response.status_code == 200
    standard_body = standard_response.json()

    class _Adapter:
        def generate_summary(self, *, model_name, system_prompt, user_prompt, max_output_tokens):
            return "Sintesi privata locale Gemma 4."

    monkeypatch.setattr(
        "app.ai.summary_provider.build_local_summary_runtime_adapter",
        lambda settings: _Adapter(),
    )

    local_response = client.get(
        f"/api/v1/insights/daily/private-local?reference_date={target_date.isoformat()}",
        headers=auth_headers,
    )
    assert local_response.status_code == 200
    local_body = local_response.json()

    assert local_body["summary_type"] == "daily"
    assert local_body["provider_name"] == "local_gemma4"
    assert local_body["id"] != standard_body["id"]
    assert "Sintesi privata locale Gemma 4." in local_body["content"]

    user = db_session.scalar(select(User).where(User.email == "patient@example.com"))
    assert user is not None
    stored_summary = db_session.scalar(
        select(AiSummary).where(
            AiSummary.patient_id == user.profile.id,
            AiSummary.summary_type == AiSummaryType.DAILY,
            AiSummary.period_start == target_date,
            AiSummary.period_end == target_date,
        )
    )
    assert stored_summary is not None
    assert str(stored_summary.id) == standard_body["id"]
    assert stored_summary.content == standard_body["content"]


def test_private_local_daily_insight_regenerate_endpoint_returns_transient_summary(
    client,
    auth_headers,
    monkeypatch,
):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)

    class _Adapter:
        def generate_summary(self, *, model_name, system_prompt, user_prompt, max_output_tokens):
            return "Rigenerazione privata locale."

    monkeypatch.setattr(
        "app.ai.summary_provider.build_local_summary_runtime_adapter",
        lambda settings: _Adapter(),
    )

    regenerate_response = client.post(
        f"/api/v1/insights/daily/private-local/regenerate?reference_date={target_date.isoformat()}",
        headers=auth_headers,
    )
    assert regenerate_response.status_code == 200
    regenerate_body = regenerate_response.json()

    assert regenerate_body["summary_type"] == "daily"
    assert regenerate_body["provider_name"] == "local_gemma4"
    assert "Rigenerazione privata locale." in regenerate_body["content"]


def test_private_local_status_endpoint_reports_sanitized_metadata(
    client,
    auth_headers,
    monkeypatch,
):
    class _Adapter:
        def generate_summary(self, *, model_name, system_prompt, user_prompt, max_output_tokens):
            return "ok"

    monkeypatch.setattr(
        "app.ai.summary_provider.build_local_summary_runtime_adapter",
        lambda settings: _Adapter(),
    )

    response = client.get(
        "/api/v1/insights/local-status",
        headers=auth_headers,
    )
    assert response.status_code == 200
    body = response.json()

    assert body["enabled"] is True
    assert body["provider"] == "local_gemma4"
    assert body["runtime_mode"] == "local"
    assert body["fallback_provider"] == "rule_based"
    assert body["is_cloud_bypassed_for_this_request"] is True
    assert body["active_provider_label"] in {"Gemma 4 Local", "Modalita privata locale"}


def test_on_device_daily_prompt_endpoint_returns_minimized_prompt(
    client,
    auth_headers,
):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)

    response = client.get(
        f"/api/v1/insights/daily/on-device-prompt?reference_date={target_date.isoformat()}",
        headers=auth_headers,
    )
    assert response.status_code == 200
    body = response.json()

    assert body["summary_type"] == "daily"
    assert body["period_start"] == target_date.isoformat()
    assert body["period_end"] == target_date.isoformat()
    assert body["provider_name"] == "on_device_litertlm"
    assert body["suggested_model_family"] == "Gemma 4"
    assert body["is_cloud_bypassed_for_this_request"] is True
    assert "Usa esclusivamente i dati presenti nel payload JSON" in body["system_prompt"]
    assert "Genera un riepilogo clinico prudente usando ESCLUSIVAMENTE" in body["user_prompt"]


def test_daily_insight_payload_includes_previous_15_day_recaps(client, auth_headers, db_session):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)
    user = db_session.scalar(select(User).where(User.email == "patient@example.com"))
    assert user is not None

    recent_summary = AiSummary(
        patient_id=user.profile.id,
        summary_type=AiSummaryType.DAILY,
        period_start=date(2026, 3, 18),
        period_end=date(2026, 3, 18),
        content="Recap recente con energia bassa e sonno frammentato.",
        provider_name="local_gemma4",
        model_name="gemma-4-e2b",
    )
    old_summary = AiSummary(
        patient_id=user.profile.id,
        summary_type=AiSummaryType.DAILY,
        period_start=date(2026, 3, 1),
        period_end=date(2026, 3, 1),
        content="Recap troppo lontano nel tempo.",
        provider_name="local_gemma4",
        model_name="gemma-4-e2b",
    )
    db_session.add_all([recent_summary, old_summary])
    db_session.commit()

    payload = InsightService(db_session)._build_summary_payload(
        patient_id=user.profile.id,
        summary_type="daily",
        summary_label="riassunto giornaliero",
        period_start=target_date,
        period_end=target_date,
    )

    assert any("2026-03-18" in item for item in payload.prior_daily_summaries)
    assert any("energia bassa" in item for item in payload.prior_daily_summaries)
    assert all("2026-03-01" not in item for item in payload.prior_daily_summaries)


def test_daily_insight_payload_includes_triggers_and_functional_limitations(
    client,
    auth_headers,
    db_session,
):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)
    user = db_session.scalar(select(User).where(User.email == "patient@example.com"))
    assert user is not None
    assert user.profile is not None

    user.profile.symptom_triggers = "Stress, poco sonno e sforzo intenso."
    user.profile.functional_limitations = (
        "Nei giorni peggiori evita attivita fisica intensa e riduce le scale."
    )
    db_session.commit()

    payload = InsightService(db_session)._build_summary_payload(
        patient_id=user.profile.id,
        summary_type="daily",
        summary_label="riassunto giornaliero",
        period_start=target_date,
        period_end=target_date,
    )

    assert any("Trigger noti dei sintomi" in item for item in payload.patient_snapshot)
    assert any("Limitazioni funzionali riferite" in item for item in payload.patient_snapshot)


def test_daily_insight_payload_includes_vaccination_history(client, auth_headers, db_session):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)
    vaccination_response = client.post(
        "/api/v1/profile/vaccinations",
        headers=auth_headers,
        json={
            "vaccine_name": "HPV",
            "administered_on": "2025-11-01",
            "dose_number": 2,
        },
    )
    assert vaccination_response.status_code == 201
    user = db_session.scalar(select(User).where(User.email == "patient@example.com"))
    assert user is not None
    assert user.profile is not None

    payload = InsightService(db_session)._build_summary_payload(
        patient_id=user.profile.id,
        summary_type="daily",
        summary_label="riassunto giornaliero",
        period_start=target_date,
        period_end=target_date,
    )

    assert any("Storico vaccinale" in item for item in payload.patient_snapshot)


def test_daily_insight_payload_includes_region_context(client, auth_headers, db_session):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)
    user = db_session.scalar(select(User).where(User.email == "patient@example.com"))
    assert user is not None
    assert user.profile is not None

    user.profile.region_code = "IT-LOM"
    db_session.commit()

    payload = InsightService(db_session)._build_summary_payload(
        patient_id=user.profile.id,
        summary_type="daily",
        summary_label="riassunto giornaliero",
        period_start=target_date,
        period_end=target_date,
    )

    assert any("Regione screening/prevenzione" in item for item in payload.patient_snapshot)
    assert any("Lombardia" in item for item in payload.patient_snapshot)


def test_daily_insight_payload_includes_device_measurement_summaries(
    client,
    auth_headers,
    db_session,
):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)

    link_response = client.post(
        "/api/v1/devices/providers/ad_medical/link",
        headers=auth_headers,
        json={
            "account_label": "Sfigmomanometro casa",
            "api_key": "debug-ad-key",
        },
    )
    assert link_response.status_code == 200
    connection_id = link_response.json()["connection"]["id"]

    ingest_response = client.post(
        f"/api/v1/devices/connections/{connection_id}/measurements",
        headers=auth_headers,
        json={
            "items": [
                {
                    "metric_type": "blood_pressure",
                    "measured_at": "2026-03-20T08:10:00Z",
                    "unit": "mmHg",
                    "primary_value": 126,
                    "secondary_value": 79,
                    "tertiary_value": 67,
                    "source_device_model": "UA-767",
                },
                {
                    "metric_type": "blood_pressure",
                    "measured_at": "2026-03-20T20:15:00Z",
                    "unit": "mmHg",
                    "primary_value": 128,
                    "secondary_value": 80,
                    "tertiary_value": 68,
                    "source_device_model": "UA-767",
                },
            ]
        },
    )
    assert ingest_response.status_code == 200

    user = db_session.scalar(select(User).where(User.email == "patient@example.com"))
    assert user is not None

    payload = InsightService(db_session)._build_summary_payload(
        patient_id=user.profile.id,
        summary_type="daily",
        summary_label="riassunto giornaliero",
        period_start=target_date,
        period_end=target_date,
    )

    assert payload.device_measurement_summaries
    assert any("A&D Medical" in item for item in payload.device_measurement_summaries)
    assert any("pressione arteriosa" in item for item in payload.device_measurement_summaries)
    assert any("misure da dispositivi clinici" in item for item in payload.data_considered)


def test_daily_insight_respects_ai_privacy_consent(client, auth_headers, db_session, monkeypatch):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)
    user = db_session.scalar(select(User).where(User.email == "patient@example.com"))
    assert user is not None

    call_flags: list[bool] = []

    class _FakeProvider:
        provider_name = "fake_provider"
        model_name = "fake-model"

        def generate_result(self, payload):
            return SummaryGenerationResult(
                content="Riepilogo AI di prova.",
                provider_name=self.provider_name,
                model_name=self.model_name,
            )

        def generate(self, payload):
            return self.generate_result(payload).content

    def _fake_build_summary_provider(settings, *, allow_external_provider=True):
        call_flags.append(allow_external_provider)
        return _FakeProvider()

    monkeypatch.setattr(
        "app.services.insight_service.build_summary_provider",
        _fake_build_summary_provider,
    )

    first_summary = InsightService(db_session).regenerate_daily_summary(
        user,
        reference_date=target_date,
    )
    assert first_summary.content == "Riepilogo AI di prova."
    assert call_flags == [False]

    privacy_response = client.patch(
        "/api/v1/profile/privacy/ai",
        headers=auth_headers,
        json={"ai_external_consent": True},
    )
    assert privacy_response.status_code == 200

    second_summary = InsightService(db_session).regenerate_daily_summary(
        user,
        reference_date=target_date,
    )
    assert second_summary.content == "Riepilogo AI di prova."
    assert call_flags == [False, True]


def test_minor_profile_forces_local_ai_even_with_external_consent(
    client,
    auth_headers,
    db_session,
    monkeypatch,
):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)
    user = db_session.scalar(select(User).where(User.email == "patient@example.com"))
    assert user is not None
    assert user.profile is not None

    user.profile.birth_date = date.today().replace(year=date.today().year - 12)
    user.onboarding_status.ai_external_consent = True
    db_session.commit()

    call_flags: list[bool] = []

    class _FakeProvider:
        provider_name = "fake_provider"
        model_name = "fake-model"

        def generate_result(self, payload):
            return SummaryGenerationResult(
                content="Riepilogo AI di prova.",
                provider_name=self.provider_name,
                model_name=self.model_name,
            )

        def generate(self, payload):
            return self.generate_result(payload).content

    def _fake_build_summary_provider(settings, *, allow_external_provider=True):
        call_flags.append(allow_external_provider)
        return _FakeProvider()

    monkeypatch.setattr(
        "app.services.insight_service.build_summary_provider",
        _fake_build_summary_provider,
    )

    summary = InsightService(db_session).regenerate_daily_summary(
        user,
        reference_date=target_date,
    )

    assert summary.content == "Riepilogo AI di prova."
    assert call_flags == [False]


def test_old_documents_are_excluded_from_ai_context(client, auth_headers, db_session):
    target_date = date(2026, 3, 20)
    _create_entry(client, auth_headers, target_date)
    user = db_session.scalar(select(User).where(User.email == "patient@example.com"))
    assert user is not None
    assert user.profile is not None

    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={"title": "Esami vecchi", "exam_date": target_date.isoformat()},
        files={
            "file": (
                "esami-old.pdf",
                b"%PDF-1.4\n% fake content",
                "application/pdf",
            )
        },
    )
    assert upload_response.status_code == 201
    document_id = upload_response.json()["id"]

    review_response = client.post(
        f"/api/v1/documents/{document_id}/review",
        headers=auth_headers,
        json={
            "document_type": "lab_report",
            "ocr_text": "Esami del sangue\nGlucosio 145 mg/dL 70-99",
            "lab_panel": {
                "panel_name": "Esami del sangue",
                "panel_date": target_date.isoformat(),
                "results": [
                    {
                        "analyte_name": "Glucosio",
                        "value": "145",
                        "unit": "mg/dL",
                        "ref_min": 70,
                        "ref_max": 99,
                    }
                ],
            },
        },
    )
    assert review_response.status_code == 200

    update_response = client.put(
        f"/api/v1/documents/{document_id}/status",
        headers=auth_headers,
        json={"context_status": "old"},
    )
    assert update_response.status_code == 200

    payload = InsightService(db_session)._build_summary_payload(
        patient_id=user.profile.id,
        summary_type="daily",
        summary_label="riassunto giornaliero",
        period_start=target_date,
        period_end=target_date,
    )

    assert all("Esami vecchi" not in item for item in payload.recent_documents)
    assert all("Glucosio 145" not in item for item in payload.recent_lab_results)
