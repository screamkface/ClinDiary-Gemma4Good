from datetime import date, datetime, timedelta, timezone
from io import BytesIO
from uuid import UUID

from reportlab.pdfgen import canvas
from sqlalchemy import select

from app.models.dossier_share_link import DossierShareLink


def _pdf_bytes(lines: list[str]) -> bytes:
    buffer = BytesIO()
    pdf = canvas.Canvas(buffer)
    y = 800
    for line in lines:
        pdf.drawString(72, y, line)
        y -= 20
    pdf.save()
    return buffer.getvalue()


def test_prevention_center_and_dossier_expose_structured_health_context(client, auth_headers):
    today = date.today()

    update_profile = client.put(
        "/api/v1/profile/me",
        headers=auth_headers,
        json={
            "birth_date": "1971-03-15",
            "biological_sex": "male",
            "height_cm": 180,
            "weight_kg": 85,
            "smoker": False,
            "symptom_triggers": "Pollini e polvere",
            "activity_level": "moderate",
        },
    )
    assert update_profile.status_code == 200

    create_entry = client.post(
        "/api/v1/daily-entries",
        headers=auth_headers,
        json={
            "entry_date": today.isoformat(),
            "sleep_hours": 6.5,
            "sleep_quality": 6,
            "energy_level": 6,
            "mood_level": 7,
            "stress_level": 4,
            "general_notes": "Giornata abbastanza stabile.",
        },
    )
    assert create_entry.status_code == 201

    insight_response = client.get(
        f"/api/v1/insights/daily?reference_date={today.isoformat()}",
        headers=auth_headers,
    )
    assert insight_response.status_code == 200

    report_response = client.post(
        "/api/v1/reports/generate",
        headers=auth_headers,
        json={"report_type": "weekly_summary", "reference_date": today.isoformat()},
    )
    assert report_response.status_code == 201

    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={"title": "Esami sangue annuali", "source": "Laboratorio locale"},
        files={
            "file": (
                "esami-lab.pdf",
                _pdf_bytes(
                    [
                        "Esami del sangue",
                        "Glucosio 95 mg/dL 70-99",
                        "Creatinina 1.4 mg/dL 0.7-1.2",
                    ]
                ),
                "application/pdf",
            )
        },
    )
    assert upload_response.status_code == 201
    document_id = upload_response.json()["id"]

    vaccination_response = client.post(
        "/api/v1/profile/vaccinations",
        headers=auth_headers,
        json={
            "vaccine_name": "Influenza stagionale",
            "administered_on": today.isoformat(),
            "provider_name": "Farmacia locale",
        },
    )
    assert vaccination_response.status_code == 201

    episode_response = client.post(
        "/api/v1/profile/problems",
        headers=auth_headers,
        json={
            "title": "Asma allergica",
            "status": "monitoring",
            "summary": "Sintomi ricorrenti nei cambi di stagione.",
        },
    )
    assert episode_response.status_code == 201

    process_response = client.post(
        f"/api/v1/documents/{document_id}/process",
        headers=auth_headers,
    )
    assert process_response.status_code == 200

    device_link_response = client.post(
        "/api/v1/devices/providers/ad_medical/link",
        headers=auth_headers,
        json={
            "account_label": "Sfigmomanometro casa",
            "api_key": "debug-ad-key",
        },
    )
    assert device_link_response.status_code == 200
    device_connection_id = device_link_response.json()["connection"]["id"]

    device_ingest_response = client.post(
        f"/api/v1/devices/connections/{device_connection_id}/measurements",
        headers=auth_headers,
        json={
            "items": [
                {
                    "metric_type": "blood_pressure",
                    "measured_at": f"{today.isoformat()}T08:15:00Z",
                    "unit": "mmHg",
                    "primary_value": 126,
                    "secondary_value": 79,
                    "tertiary_value": 67,
                    "source_device_model": "UA-767",
                },
                {
                    "metric_type": "blood_pressure",
                    "measured_at": f"{today.isoformat()}T20:05:00Z",
                    "unit": "mmHg",
                    "primary_value": 128,
                    "secondary_value": 80,
                    "tertiary_value": 68,
                    "source_device_model": "UA-767",
                },
            ]
        },
    )
    assert device_ingest_response.status_code == 200

    prevention_response = client.get("/api/v1/prevention-center", headers=auth_headers)
    assert prevention_response.status_code == 200
    prevention_body = prevention_response.json()
    assert prevention_body["annual_visit"]["code"] == "preventive_annual_visit"
    assert prevention_body["overview"]["actionable_screenings"] >= 1
    visit_codes = {item["code"] for item in prevention_body["visits_and_controls"]}
    assert "cardiometabolic_lifestyle_counseling" in visit_codes
    vaccine_codes = {item["code"] for item in prevention_body["vaccines"]}
    assert "covid_updated_review" in vaccine_codes
    assert "zoster_review" in vaccine_codes
    assert "influenza_annual_review" not in vaccine_codes
    assert any(item["code"] == "spring_allergy_review" for item in prevention_body["seasonal_checks"])
    assert any(
        item["kind"] == "follow_up" and "Report pronto" in item["title"]
        for item in prevention_body["follow_up_reminders"]
    )

    dossier_response = client.get("/api/v1/dossier", headers=auth_headers)
    assert dossier_response.status_code == 200
    dossier_body = dossier_response.json()
    fact_labels = {item["label"] for item in dossier_body["profile_facts"]}
    assert "BMI" in fact_labels
    assert "Attivita" in fact_labels
    provenance_labels = {item["label"] for item in dossier_body["provenance_facts"]}
    assert "Profilo" in provenance_labels
    assert "Documenti" in provenance_labels
    assert "Device clinici" in provenance_labels
    assert dossier_body["emergency_summary"]["headline"] == "Scheda emergenza ClinDiary"
    assert "Asma allergica" in dossier_body["emergency_summary"]["active_problems"]
    assert dossier_body["emergency_summary"]["key_points"]
    assert any(item["vaccine_name"] == "Influenza stagionale" for item in dossier_body["vaccinations"])
    assert any(item["title"] == "Asma allergica" for item in dossier_body["clinical_episodes"])
    assert dossier_body["recent_daily_entries"][0]["entry_date"] == today.isoformat()
    assert any(item["title"] == "Esami sangue annuali" for item in dossier_body["recent_documents"])
    assert dossier_body["recent_lab_panels"][0]["document_title"] == "Esami sangue annuali"
    assert dossier_body["device_measurement_summaries"]
    assert dossier_body["device_measurement_summaries"][0]["metric_type"] == "blood_pressure"
    assert "A&D Medical" in dossier_body["device_measurement_summaries"][0]["summary"]
    assert dossier_body["device_measurement_summaries"][0]["latest_value"] == "128/80 mmHg · FC 68 bpm"
    assert dossier_body["device_measurement_summaries"][0]["trend_label"] == "Media 127/80 mmHg"
    assert dossier_body["recent_insights"][0]["summary_type"] == "daily"
    assert dossier_body["recent_reports"][0]["report_type"] == "weekly_summary"

    export_response = client.get("/api/v1/dossier/export", headers=auth_headers)
    assert export_response.status_code == 200
    assert export_response.headers["content-type"].startswith("application/pdf")

    emergency_export_response = client.get("/api/v1/dossier/export/emergency", headers=auth_headers)
    assert emergency_export_response.status_code == 200
    assert emergency_export_response.headers["content-type"].startswith("application/pdf")

    json_export_response = client.get("/api/v1/dossier/export/json", headers=auth_headers)
    assert json_export_response.status_code == 200
    assert json_export_response.headers["content-type"].startswith("application/json")
    json_body = json_export_response.json()
    assert json_body["emergency_summary"]["headline"] == "Scheda emergenza ClinDiary"

    import_response = client.post(
        "/api/v1/dossier/import",
        headers=auth_headers,
        json={"snapshot": json_body, "replace_existing": True},
    )
    assert import_response.status_code == 200
    assert import_response.json()["emergency_summary"]["headline"] == "Scheda emergenza ClinDiary"

    share_link_response = client.post(
        "/api/v1/dossier/share-links",
        headers=auth_headers,
        json={"scope": "emergency", "label": "Condivisione medico"},
    )
    assert share_link_response.status_code == 201
    share_link_body = share_link_response.json()
    assert share_link_body["share_url"]
    assert share_link_body["filename"] == "scheda-emergenza.pdf"
    assert share_link_body["mime_type"] == "application/pdf"

    shared_pdf_response = client.get(share_link_body["share_url"])
    assert shared_pdf_response.status_code == 200
    assert shared_pdf_response.headers["content-type"].startswith("application/pdf")

    share_links_response = client.get("/api/v1/dossier/share-links", headers=auth_headers)
    assert share_links_response.status_code == 200
    share_links_body = share_links_response.json()
    assert share_links_body[0]["filename"] == "scheda-emergenza.pdf"
    assert share_links_body[0]["mime_type"] == "application/pdf"

    revoke_response = client.delete(
        f"/api/v1/dossier/share-links/{share_link_body['id']}",
        headers=auth_headers,
    )
    assert revoke_response.status_code == 204

    revoked_shared_pdf_response = client.get(share_link_body["share_url"])
    assert revoked_shared_pdf_response.status_code == 410


def test_expired_share_links_are_cleaned_up_and_max_ttl_is_limited(client, auth_headers, db_session):
    create_response = client.post(
        "/api/v1/dossier/share-links",
        headers=auth_headers,
        json={"scope": "emergency", "label": "Scadenza breve", "expires_in_days": 30},
    )
    assert create_response.status_code == 201
    share_link_id = create_response.json()["id"]
    share_url = create_response.json()["share_url"]

    share_link = db_session.scalar(
        select(DossierShareLink).where(DossierShareLink.id == UUID(share_link_id))
    )
    assert share_link is not None
    share_link.expires_at = datetime.now(timezone.utc) - timedelta(days=1)
    db_session.commit()

    shared_response = client.get(share_url)
    assert shared_response.status_code == 410

    listed_response = client.get("/api/v1/dossier/share-links", headers=auth_headers)
    assert listed_response.status_code == 200
    assert all(item["id"] != share_link_id for item in listed_response.json())

    invalid_ttl_response = client.post(
        "/api/v1/dossier/share-links",
        headers=auth_headers,
        json={"scope": "full", "expires_in_days": 31},
    )
    assert invalid_ttl_response.status_code == 422
