def test_daily_entries_and_timeline_flow(client, auth_headers):
    create_entry = client.post(
        "/api/v1/daily-entries",
        headers=auth_headers,
        json={
            "entry_date": "2026-03-20",
            "sleep_hours": 7.0,
            "energy_level": 6,
            "mood_level": 7,
            "hydration_level": 5,
            "general_pain": 2,
            "general_notes": "Lieve cefalea pomeridiana",
        },
    )
    assert create_entry.status_code == 201
    entry_id = create_entry.json()["id"]

    add_symptom = client.post(
        f"/api/v1/daily-entries/{entry_id}/symptoms",
        headers=auth_headers,
        json={
            "symptom_code": "headache",
            "severity": 4,
            "duration_minutes": 120,
            "body_location": "frontale",
            "metadata_json": {"with_nausea": False},
        },
    )
    assert add_symptom.status_code == 201

    add_vital = client.post(
        f"/api/v1/daily-entries/{entry_id}/vitals",
        headers=auth_headers,
        json={"type": "blood_pressure", "value": "120/80", "unit": "mmHg"},
    )
    assert add_vital.status_code == 201

    entry_response = client.get(f"/api/v1/daily-entries/{entry_id}", headers=auth_headers)
    assert entry_response.status_code == 200
    body = entry_response.json()
    assert len(body["symptoms"]) == 1
    assert len(body["vitals"]) == 1

    timeline_response = client.get("/api/v1/timeline", headers=auth_headers)
    assert timeline_response.status_code == 200
    titles = [event["title"] for event in timeline_response.json()]
    assert any("Onboarding" in title for title in titles)
    assert any("Check-up" in title for title in titles)
    assert any("Sintomo" in title for title in titles)
    assert any("Parametro" in title for title in titles)


def test_daily_entries_accept_free_text_symptoms(client, auth_headers):
    create_entry = client.post(
        "/api/v1/daily-entries",
        headers=auth_headers,
        json={
            "entry_date": "2026-03-21",
            "energy_level": 5,
            "general_notes": "Test sintomo libero",
        },
    )
    assert create_entry.status_code == 201
    entry_id = create_entry.json()["id"]

    add_symptom = client.post(
        f"/api/v1/daily-entries/{entry_id}/symptoms",
        headers=auth_headers,
        json={
            "symptom_code": "dolore addominale dopo i pasti",
            "severity": 6,
            "metadata_json": {"entry_mode": "custom"},
        },
    )
    assert add_symptom.status_code == 201
    assert add_symptom.json()["symptom_code"] == "dolore addominale dopo i pasti"

    entry_response = client.get(f"/api/v1/daily-entries/{entry_id}", headers=auth_headers)
    assert entry_response.status_code == 200
    symptoms = entry_response.json()["symptoms"]
    assert any(item["symptom_code"] == "dolore addominale dopo i pasti" for item in symptoms)
