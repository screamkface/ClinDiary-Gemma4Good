def test_devices_overview_lists_wave1_catalog(client, free_auth_headers):
    response = client.get("/api/v1/devices/overview", headers=free_auth_headers)

    assert response.status_code == 200
    payload = response.json()
    provider_codes = [item["code"] for item in payload["providers"]]
    assert provider_codes == ["omron", "withings", "ihealth", "ad_medical", "dexcom"]
    assert payload["connections"] == []
    assert payload["recent_measurements"] == []


def test_link_ad_medical_and_ingest_measurement(client, free_auth_headers):
    link_response = client.post(
        "/api/v1/devices/providers/ad_medical/link",
        headers=free_auth_headers,
        json={
            "account_label": "Misuratore pressione studio",
            "api_key": "test-ad-key",
        },
    )
    assert link_response.status_code == 200
    connection = link_response.json()["connection"]
    assert connection["status"] == "connected"

    ingest_response = client.post(
        f"/api/v1/devices/connections/{connection['id']}/measurements",
        headers=free_auth_headers,
        json={
            "items": [
                {
                    "metric_type": "blood_pressure",
                    "measured_at": "2026-04-01T08:30:00Z",
                    "unit": "mmHg",
                    "primary_value": 122,
                    "secondary_value": 78,
                    "tertiary_value": 66,
                    "source_device_model": "UA-767",
                }
            ]
        },
    )

    assert ingest_response.status_code == 200
    payload = ingest_response.json()
    assert payload["created_count"] == 1
    assert payload["items"][0]["display_value"] == "122/78 mmHg · FC 66 bpm"

    overview_response = client.get("/api/v1/devices/overview", headers=free_auth_headers)
    assert overview_response.status_code == 200
    overview = overview_response.json()
    assert len(overview["connections"]) == 1
    assert overview["connections"][0]["measurement_count"] == 1
    assert overview["recent_measurements"][0]["metric_type"] == "blood_pressure"


def test_link_omron_returns_partner_setup_guidance(client, free_auth_headers):
    response = client.post(
        "/api/v1/devices/providers/omron/link",
        headers=free_auth_headers,
        json={"account_label": "OMRON familiare"},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["next_step"] == "follow_partner_setup"
    assert payload["connection"]["status"] == "pending"
    assert "OMRON" in payload["message"]
