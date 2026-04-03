def test_profile_bundle_and_subresources(client, auth_headers):
    add_allergy = client.post(
        "/api/v1/profile/allergies",
        headers=auth_headers,
        json={"allergen": "Nocciola", "severity": "moderate"},
    )
    assert add_allergy.status_code == 201

    add_condition = client.post(
        "/api/v1/profile/conditions",
        headers=auth_headers,
        json={"name": "Asma", "status": "active"},
    )
    assert add_condition.status_code == 201

    add_medication = client.post(
        "/api/v1/profile/medications",
        headers=auth_headers,
        json={"name": "Salbutamolo", "dosage": "100 mcg", "frequency": "PRN"},
    )
    assert add_medication.status_code == 201

    add_family_history = client.post(
        "/api/v1/profile/family-history",
        headers=auth_headers,
        json={"relation": "padre", "condition_name": "diabete tipo 2"},
    )
    assert add_family_history.status_code == 201

    add_vaccination = client.post(
        "/api/v1/profile/vaccinations",
        headers=auth_headers,
        json={
            "vaccine_name": "Influenza stagionale",
            "administered_on": "2026-10-10",
            "dose_number": 1,
            "next_due_date": "2027-10-10",
            "provider_name": "Farmacia locale",
        },
    )
    assert add_vaccination.status_code == 201

    profile_response = client.get("/api/v1/profile/me", headers=auth_headers)
    assert profile_response.status_code == 200
    body = profile_response.json()
    assert body["profile"]["first_name"] == "Anna"
    assert body["onboarding"]["health_data_consent"] is True
    assert body["onboarding"]["ai_external_consent"] is False
    assert len(body["allergies"]) == 1
    assert len(body["medical_conditions"]) == 1
    assert len(body["medications"]) == 1
    assert len(body["family_history"]) == 1
    assert len(body["vaccinations"]) == 1


def test_ai_privacy_toggle_updates_onboarding(client, auth_headers):
    enable_response = client.patch(
        "/api/v1/profile/privacy/ai",
        headers=auth_headers,
        json={"ai_external_consent": True},
    )
    assert enable_response.status_code == 200
    enable_body = enable_response.json()
    assert enable_body["onboarding"]["ai_external_consent"] is True
    assert enable_body["onboarding"]["ai_external_consented_at"] is not None

    disable_response = client.patch(
        "/api/v1/profile/privacy/ai",
        headers=auth_headers,
        json={"ai_external_consent": False},
    )
    assert disable_response.status_code == 200
    disable_body = disable_response.json()
    assert disable_body["onboarding"]["ai_external_consent"] is False


def test_profile_update_triggers_profile_dependent_rule_refresh(
    client,
    auth_headers,
    db_session,
    monkeypatch,
):
    calls: list[str] = []

    class _FakeNotificationService:
        def __init__(self, db):
            self.db = db

        def sync_patient_notifications(self, patient_id):
            calls.append(str(patient_id))

    monkeypatch.setattr(
        "app.services.profile_service.NotificationService",
        _FakeNotificationService,
    )

    user = db_session.scalar(select(User).where(User.email == "patient@example.com"))
    assert user is not None
    assert user.profile is not None

    update_response = client.put(
        "/api/v1/profile/me",
        headers=auth_headers,
        json={
            "birth_date": "1960-04-10",
            "biological_sex": "male",
            "smoker": True,
        },
    )
    assert update_response.status_code == 200
    assert calls == [str(user.profile.id)]


def test_profile_subresources_can_be_deleted(client, auth_headers):
    allergy = client.post(
        "/api/v1/profile/allergies",
        headers=auth_headers,
        json={"allergen": "Polline", "severity": "mild"},
    ).json()
    condition = client.post(
        "/api/v1/profile/conditions",
        headers=auth_headers,
        json={"name": "Emicrania", "status": "monitoring"},
    ).json()
    medication = client.post(
        "/api/v1/profile/medications",
        headers=auth_headers,
        json={"name": "Ibuprofene", "dosage": "200 mg"},
    ).json()
    family_history = client.post(
        "/api/v1/profile/family-history",
        headers=auth_headers,
        json={"relation": "madre", "condition_name": "ipertensione"},
    ).json()

    assert client.delete(
        f"/api/v1/profile/allergies/{allergy['id']}",
        headers=auth_headers,
    ).status_code == 204
    assert client.delete(
        f"/api/v1/profile/conditions/{condition['id']}",
        headers=auth_headers,
    ).status_code == 204
    assert client.delete(
        f"/api/v1/profile/medications/{medication['id']}",
        headers=auth_headers,
    ).status_code == 204
    assert client.delete(
        f"/api/v1/profile/family-history/{family_history['id']}",
        headers=auth_headers,
    ).status_code == 204

    profile_response = client.get("/api/v1/profile/me", headers=auth_headers)
    assert profile_response.status_code == 200
    body = profile_response.json()
    assert body["allergies"] == []
    assert body["medical_conditions"] == []
    assert body["medications"] == []
    assert body["family_history"] == []


def test_vaccination_records_support_crud(client, auth_headers):
    vaccination = client.post(
        "/api/v1/profile/vaccinations",
        headers=auth_headers,
        json={
            "vaccine_name": "COVID aggiornato",
            "administered_on": "2026-01-15",
            "dose_number": 4,
            "provider_name": "Centro vaccinale",
        },
    ).json()

    update_response = client.put(
        f"/api/v1/profile/vaccinations/{vaccination['id']}",
        headers=auth_headers,
        json={
            "next_due_date": "2027-01-15",
            "notes": "Richiamo annuale da rivedere.",
        },
    )
    assert update_response.status_code == 200
    updated = update_response.json()
    assert updated["next_due_date"] == "2027-01-15"
    assert updated["notes"] == "Richiamo annuale da rivedere."

    profile_response = client.get("/api/v1/profile/me", headers=auth_headers)
    assert profile_response.status_code == 200
    assert len(profile_response.json()["vaccinations"]) == 1

    delete_response = client.delete(
        f"/api/v1/profile/vaccinations/{vaccination['id']}",
        headers=auth_headers,
    )
    assert delete_response.status_code == 204

    profile_response = client.get("/api/v1/profile/me", headers=auth_headers)
    assert profile_response.status_code == 200
    assert profile_response.json()["vaccinations"] == []


def test_clinical_episodes_support_crud(client, auth_headers):
    episode = client.post(
        "/api/v1/profile/problems",
        headers=auth_headers,
        json={
            "title": "Asma allergica",
            "status": "active",
            "onset_date": "2024-09-01",
            "summary": "Sintomi stagionali con broncospasmo lieve.",
        },
    ).json()

    update_response = client.put(
        f"/api/v1/profile/problems/{episode['id']}",
        headers=auth_headers,
        json={
            "next_review_date": "2026-04-01",
            "notes": "Da rivedere in primavera.",
        },
    )
    assert update_response.status_code == 200
    updated = update_response.json()
    assert updated["next_review_date"] == "2026-04-01"
    assert updated["notes"] == "Da rivedere in primavera."

    profile_response = client.get("/api/v1/profile/me", headers=auth_headers)
    assert profile_response.status_code == 200
    assert len(profile_response.json()["clinical_episodes"]) == 1

    delete_response = client.delete(
        f"/api/v1/profile/problems/{episode['id']}",
        headers=auth_headers,
    )
    assert delete_response.status_code == 204

    profile_response = client.get("/api/v1/profile/me", headers=auth_headers)
    assert profile_response.status_code == 200
    assert profile_response.json()["clinical_episodes"] == []


def test_profile_supports_extended_lifestyle_context_fields(client, auth_headers):
    response = client.put(
        "/api/v1/profile/me",
        headers=auth_headers,
        json={
            "activity_level": "active",
            "alcohol_use": "occasional",
            "occupation": "Infermiera con turni notturni.",
            "exercise_habits": "Nuoto 2 volte a settimana e palestra nel weekend.",
            "sleep_pattern": "Sonno irregolare nei giorni di turno.",
            "symptom_triggers": "Stress, poco sonno e pasti saltati.",
            "functional_limitations": "Nelle giornate peggiori limita scale e attivita fisica intensa.",
        },
    )
    assert response.status_code == 200

    profile = response.json()["profile"]
    assert profile["activity_level"] == "active"
    assert profile["alcohol_use"] == "occasional"
    assert profile["occupation"] == "Infermiera con turni notturni."
    assert profile["exercise_habits"] == "Nuoto 2 volte a settimana e palestra nel weekend."
    assert profile["sleep_pattern"] == "Sonno irregolare nei giorni di turno."
    assert profile["symptom_triggers"] == "Stress, poco sonno e pasti saltati."
    assert (
        profile["functional_limitations"]
        == "Nelle giornate peggiori limita scale e attivita fisica intensa."
    )


def test_profile_supports_region_code(client, auth_headers):
    response = client.put(
        "/api/v1/profile/me",
        headers=auth_headers,
        json={
            "region_code": "IT-LOM",
        },
    )
    assert response.status_code == 200
    assert response.json()["profile"]["region_code"] == "IT-LOM"


def test_managed_profiles_are_listed_and_accessible_via_header(client, auth_headers):
    created = client.post(
        "/api/v1/profile/profiles",
        headers=auth_headers,
        json={
            "first_name": "Luca",
            "relationship_label": "figlio",
            "birth_date": "2015-01-01",
            "biological_sex": "male",
            "region_code": "IT-LOM",
        },
    )
    assert created.status_code == 201
    child_profile = created.json()
    assert child_profile["is_primary"] is False
    assert child_profile["relationship_label"] == "figlio"

    profiles_response = client.get("/api/v1/profile/profiles", headers=auth_headers)
    assert profiles_response.status_code == 200
    profiles = profiles_response.json()
    assert len(profiles) == 2
    assert any(profile["is_primary"] is True for profile in profiles)
    assert any(profile["first_name"] == "Luca" for profile in profiles)

    child_headers = {
        **auth_headers,
        "X-Patient-Id": child_profile["id"],
    }
    child_bundle_response = client.get("/api/v1/profile/me", headers=child_headers)
    assert child_bundle_response.status_code == 200
    child_bundle = child_bundle_response.json()
    assert child_bundle["profile"]["id"] == child_profile["id"]
    assert child_bundle["profile"]["first_name"] == "Luca"
from sqlalchemy import select

from app.models.user import User
