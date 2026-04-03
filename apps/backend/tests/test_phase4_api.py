from datetime import date

from sqlalchemy import select

from app.models.enums import BiologicalSex, NotificationPriority, NotificationType
from app.models.notification import Notification
from app.models.patient_profile import PatientProfile
from app.models.user import User
from app.rules.screenings import ScreeningRuleEngine
from app.services.screening_service import ITALIAN_SCREENING_REGIONS
from app.workers.notification_tasks import sync_notifications_task


def test_screenings_medications_and_notifications_flow(client, auth_headers):
    today = date.today()

    update_profile = client.put(
        "/api/v1/profile/me",
        headers=auth_headers,
        json={
            "birth_date": "1970-04-10",
            "biological_sex": "female",
            "smoker": False,
            "former_smoker": True,
            "smoking_pack_years": 24,
            "years_since_quitting": 10,
            "height_cm": 165,
            "weight_kg": 90,
            "alcohol_use": "high",
            "activity_level": "sedentary",
            "postmenopausal": True,
            "fragility_fracture_history": True,
            "falls_last_year": 2,
            "feels_unsteady": True,
            "sexually_active": True,
            "new_or_multiple_partners": True,
            "region_code": "IT-LOM",
        },
    )
    assert update_profile.status_code == 200

    catalog_response = client.get(
        "/api/v1/screenings/catalog?region_code=IT-LOM",
        headers=auth_headers,
    )
    assert catalog_response.status_code == 200
    catalog_items = catalog_response.json()
    assert len(catalog_items) >= 20
    assert all(
        availability["region_code"] == "IT-LOM"
        for item in catalog_items
        for availability in item["regional_availability"]
    )
    catalog_codes = {item["code"] for item in catalog_items}
    assert "preventive_annual_visit" in catalog_codes
    assert "blood_pressure_adults" in catalog_codes
    assert "tobacco_use_review" in catalog_codes
    assert "alcohol_use_review" in catalog_codes
    assert "cardiometabolic_lifestyle_counseling" in catalog_codes
    assert "osteoporosis_screening" in catalog_codes
    assert "lung_cancer_screening" in catalog_codes
    assert "falls_prevention_review" in catalog_codes
    assert "testicular_cancer_routine_screening" in catalog_codes
    assert any(item["catalog_only"] is True for item in catalog_items if item["code"] == "testicular_cancer_routine_screening")
    assert next(item for item in catalog_items if item["code"] == "preventive_annual_visit")["care_pathway"] == "annual_visit"
    assert next(item for item in catalog_items if item["code"] == "blood_pressure_adults")["care_pathway"] == "discuss_with_doctor"
    assert next(item for item in catalog_items if item["code"] == "testicular_cancer_routine_screening")["care_pathway"] == "not_routine"

    recompute_response = client.post("/api/v1/screenings/recompute", headers=auth_headers, json={})
    assert recompute_response.status_code == 200
    items = recompute_response.json()["items"]
    codes = {item["screening_code"] for item in items}
    assert "preventive_annual_visit" in codes
    assert "blood_pressure_adults" in codes
    assert "tobacco_use_review" in codes
    assert "alcohol_use_review" in codes
    assert "alcohol_risk_counseling" in codes
    assert "obesity_behavioral_support" in codes
    assert "cardiometabolic_lifestyle_counseling" in codes
    assert "osteoporosis_screening" in codes
    assert "lung_cancer_screening" in codes
    assert "sti_risk_assessment" in codes
    assert "cervical_cancer_it" in codes
    assert "mammography_it" in codes
    assert "colorectal_it" in codes
    assert "testicular_cancer_routine_screening" not in codes
    assert next(item for item in items if item["screening_code"] == "preventive_annual_visit")["care_pathway"] == "annual_visit"
    assert next(item for item in items if item["screening_code"] == "blood_pressure_adults")["care_pathway"] == "discuss_with_doctor"
    assert (
        next(item for item in items if item["screening_code"] == "tobacco_use_review")[
            "recommendation_level"
        ]
        == "routine"
    )
    assert (
        next(item for item in items if item["screening_code"] == "cervical_cancer_it")[
            "regional_availability"
        ][0]["region_code"]
        == "IT-LOM"
    )

    prevention_center_response = client.get(
        "/api/v1/prevention-center",
        headers=auth_headers,
    )
    assert prevention_center_response.status_code == 200
    prevention_center_body = prevention_center_response.json()
    assert prevention_center_body["region_code"] == "IT-LOM"
    assert prevention_center_body["region_name"] == "Lombardia"
    prevention_codes = {item["code"] for item in prevention_center_body["visits_and_controls"]}
    assert "tobacco_use_review" in prevention_codes
    assert "alcohol_use_review" in prevention_codes
    assert "alcohol_risk_counseling" in prevention_codes
    assert "obesity_behavioral_support" in prevention_codes
    assert "osteoporosis_screening" in prevention_codes
    assert "lung_cancer_screening" in prevention_codes
    assert "sti_risk_assessment" in prevention_codes
    lombardia_catalog_item = next(item for item in catalog_items if item["code"] == "cervical_cancer_it")
    assert "prenotasalute.regione.lombardia.it" in lombardia_catalog_item["regional_availability"][0]["booking_url"]

    actionable_item = next(item for item in items if item["status"] in {"recommended", "overdue"})
    mark_done_response = client.post(
        f"/api/v1/screenings/{actionable_item['id']}/mark-done",
        headers=auth_headers,
        json={"done_date": today.isoformat()},
    )
    assert mark_done_response.status_code == 200
    assert mark_done_response.json()["status"] == "completed"
    assert mark_done_response.json()["completed_this_year"] is True

    medication_response = client.post(
        "/api/v1/profile/medications",
        headers=auth_headers,
        json={
            "name": "Atorvastatina",
            "dosage": "20 mg",
            "frequency": "1/die",
            "active": True,
            "schedules": [
                {
                    "scheduled_time": "08:00:00",
                    "days_of_week": [0, 2, 4],
                    "start_date": today.isoformat(),
                    "cycle_days_on": 5,
                    "cycle_days_off": 2,
                    "instructions": "Dopo colazione",
                    "active": True,
                }
            ],
        },
    )
    assert medication_response.status_code == 201
    medication_body = medication_response.json()
    assert medication_body["schedules"][0]["scheduled_time"].startswith("08:00")
    assert medication_body["schedules"][0]["days_of_week"] == [0, 2, 4]
    assert medication_body["schedules"][0]["cycle_days_on"] == 5

    schedule_id = medication_body["schedules"][0]["id"]
    schedule_update = client.put(
        f"/api/v1/medications/{medication_body['id']}/schedules/{schedule_id}",
        headers=auth_headers,
        json={
            "scheduled_time": "21:00:00",
            "instructions": "Dopo cena",
        },
    )
    assert schedule_update.status_code == 200
    assert schedule_update.json()["schedules"][0]["scheduled_time"].startswith("21:00")
    assert schedule_update.json()["schedules"][0]["instructions"] == "Dopo cena"

    pause_schedule = client.post(
        f"/api/v1/medications/{medication_body['id']}/schedules/{schedule_id}/pause",
        headers=auth_headers,
        json={"paused_until": today.isoformat()},
    )
    assert pause_schedule.status_code == 200
    assert pause_schedule.json()["schedules"][0]["paused_until"] == today.isoformat()

    resume_schedule = client.post(
        f"/api/v1/medications/{medication_body['id']}/schedules/{schedule_id}/resume",
        headers=auth_headers,
        json={},
    )
    assert resume_schedule.status_code == 200
    assert resume_schedule.json()["schedules"][0]["paused_until"] is None

    log_response = client.post(
        f"/api/v1/medications/{medication_body['id']}/log",
        headers=auth_headers,
        json={"status": "taken", "notes": "Dose confermata"},
    )
    assert log_response.status_code == 201
    assert log_response.json()["status"] == "taken"

    logs_response = client.get("/api/v1/medications/logs", headers=auth_headers)
    assert logs_response.status_code == 200
    assert any(log["medication_name"] == "Atorvastatina" for log in logs_response.json())

    notifications_response = client.get("/api/v1/notifications", headers=auth_headers)
    assert notifications_response.status_code == 200
    notifications = notifications_response.json()
    types = {item["notification_type"] for item in notifications}
    assert "daily_checkin_reminder" in types
    assert "screening_reminder" in types or "prevention_tip" in types
    assert "medication_reminder" not in types
    assert any(
        item["notification_type"] == "prevention_tip" and "Lombardia" in item["body"]
        for item in notifications
    )

    preferences_response = client.get("/api/v1/notifications/preferences", headers=auth_headers)
    assert preferences_response.status_code == 200
    assert preferences_response.json()["in_app_enabled"] is True
    assert preferences_response.json()["push_enabled"] is False

    update_preferences = client.put(
        "/api/v1/notifications/preferences",
        headers=auth_headers,
        json={
            "screening_reminders_enabled": False,
            "prevention_tips_enabled": False,
            "push_enabled": True,
            "email_enabled": True,
            "email_address": "patient@example.com",
        },
    )
    assert update_preferences.status_code == 200
    assert update_preferences.json()["screening_reminders_enabled"] is False
    assert update_preferences.json()["push_enabled"] is True
    assert update_preferences.json()["email_address"] == "patient@example.com"

    register_device = client.post(
        "/api/v1/notifications/devices",
        headers=auth_headers,
        json={
            "platform": "android",
            "device_token": "demo-device-token",
            "device_label": "Pixel test",
        },
    )
    assert register_device.status_code == 200
    assert register_device.json()["platform"] == "android"

    unread = notifications[0]
    mark_read_response = client.post(
        f"/api/v1/notifications/{unread['id']}/read",
        headers=auth_headers,
        json={},
    )
    assert mark_read_response.status_code == 200
    assert mark_read_response.json()["read_status"] is True

    filtered_notifications = client.get("/api/v1/notifications", headers=auth_headers)
    assert filtered_notifications.status_code == 200
    filtered_types = {item["notification_type"] for item in filtered_notifications.json()}
    assert "screening_reminder" not in filtered_types
    assert "prevention_tip" not in filtered_types

    timeline_response = client.get("/api/v1/timeline", headers=auth_headers)
    assert timeline_response.status_code == 200
    timeline_types = [item["event_type"] for item in timeline_response.json()]
    assert "screening_due" in timeline_types or "screening_completed" in timeline_types
    assert "medication_logged" in timeline_types

    sync_result = sync_notifications_task.run()
    assert sync_result["synced_patients"] >= 1

    clear_done_response = client.delete(
        f"/api/v1/screenings/{actionable_item['id']}/current-year-completion",
        headers=auth_headers,
    )
    assert clear_done_response.status_code == 200
    assert clear_done_response.json()["completed_this_year"] is False


def test_screenings_pilot_regions_use_verified_portals(client, auth_headers):
    pilot_regions = {
        "IT-LOM": ("Lombardia", "prenotasalute.regione.lombardia.it"),
        "IT-EMR": ("Emilia-Romagna", "salute.regione.emilia-romagna.it/screening/prevenzione-tumori"),
        "IT-LAZ": ("Lazio", "salutelazio.it/screening-prenota-smart"),
    }

    for region_code, (region_name, booking_snippet) in pilot_regions.items():
        catalog_response = client.get(
            f"/api/v1/screenings/catalog?region_code={region_code}",
            headers=auth_headers,
        )
        assert catalog_response.status_code == 200
        catalog_items = catalog_response.json()
        public_item = next(item for item in catalog_items if item["code"] == "cervical_cancer_it")
        regional_availability = public_item["regional_availability"]
        assert len(regional_availability) == 1
        assert regional_availability[0]["region_code"] == region_code
        assert regional_availability[0]["region_name"] == region_name
        assert booking_snippet in regional_availability[0]["booking_url"]
        assert "Portale" in regional_availability[0]["notes"] or "screening" in regional_availability[0]["notes"].lower()

        prevention_center_response = client.get(
            f"/api/v1/prevention-center?region_code={region_code}",
            headers=auth_headers,
        )
        assert prevention_center_response.status_code == 200
        center_body = prevention_center_response.json()
        assert center_body["region_code"] == region_code
        assert center_body["region_name"] == region_name


def test_screenings_all_regions_use_region_specific_portals(client, auth_headers):
    update_profile = client.put(
        "/api/v1/profile/me",
        headers=auth_headers,
        json={
            "birth_date": "1970-04-10",
            "biological_sex": "female",
            "smoker": False,
        },
    )
    assert update_profile.status_code == 200

    for region_code, region_name in ITALIAN_SCREENING_REGIONS:
        if region_code == "IT":
            continue
        catalog_response = client.get(
            f"/api/v1/screenings/catalog?region_code={region_code}",
            headers=auth_headers,
        )
        assert catalog_response.status_code == 200
        catalog_items = catalog_response.json()
        public_item = next(item for item in catalog_items if item["code"] == "cervical_cancer_it")
        regional_availability = public_item["regional_availability"]
        assert len(regional_availability) == 1
        assert regional_availability[0]["region_code"] == region_code
        assert regional_availability[0]["region_name"] == region_name
        assert regional_availability[0]["booking_url"]
        assert "screening" in regional_availability[0]["notes"].lower()


def test_risk_based_prevention_rules_use_profile_context(client, auth_headers):
    update_profile = client.put(
        "/api/v1/profile/me",
        headers=auth_headers,
        json={
            "birth_date": "1990-04-10",
            "biological_sex": "female",
            "smoker": True,
            "height_cm": 165,
            "weight_kg": 82,
        },
    )
    assert update_profile.status_code == 200

    family_history_response = client.post(
        "/api/v1/profile/family-history",
        headers=auth_headers,
        json={
            "relation": "padre",
            "condition_name": "diabete tipo 2",
        },
    )
    assert family_history_response.status_code == 201

    recompute_response = client.post("/api/v1/screenings/recompute", headers=auth_headers, json={})
    assert recompute_response.status_code == 200
    items = recompute_response.json()["items"]
    codes = {item["screening_code"] for item in items}

    assert "lipid_profile_risk_based" in codes
    assert "prediabetes_diabetes_risk" in codes

    diabetes_item = next(item for item in items if item["screening_code"] == "prediabetes_diabetes_risk")
    assert diabetes_item["recommendation_level"] == "risk_based"
    assert diabetes_item["status"] in {"recommended", "overdue", "completed"}


def test_backend_sync_deactivates_medication_reminders_in_favor_of_local_scheduling(
    client,
    auth_headers,
    db_session,
):
    user = db_session.scalar(select(User).where(User.email == "patient@example.com"))
    assert user is not None
    assert user.profile is not None

    stale_notification = Notification(
        patient_id=user.profile.id,
        notification_type=NotificationType.MEDICATION_REMINDER,
        title="Promemoria terapia: Test",
        body="Dose prevista alle 21:00.",
        priority=NotificationPriority.NORMAL,
        source_type="medication",
        source_id=None,
        dedupe_key="medication-reminder-test",
        is_active=True,
    )
    db_session.add(stale_notification)
    db_session.commit()

    sync_result = sync_notifications_task.run()
    assert sync_result["synced_patients"] >= 1

    db_session.expire_all()
    refreshed = db_session.get(Notification, stale_notification.id)
    assert refreshed is not None
    assert refreshed.is_active is False

    notifications_response = client.get("/api/v1/notifications", headers=auth_headers)
    assert notifications_response.status_code == 200
    assert all(
        item["notification_type"] != "medication_reminder"
        for item in notifications_response.json()
    )


def test_screening_rule_engine_respects_age_and_sex(db_session):
    profile = PatientProfile(
        user_id="00000000-0000-0000-0000-000000000001",
        birth_date=date(1998, 6, 10),
        biological_sex=BiologicalSex.MALE,
        smoker=False,
    )
    program = type("Program", (), {"rules": [], "target_sex": BiologicalSex.FEMALE, "min_age": 25, "max_age": 64, "explanation": "test", "description": "test"})()
    result = ScreeningRuleEngine().evaluate(profile, program)
    assert result.eligible is False
