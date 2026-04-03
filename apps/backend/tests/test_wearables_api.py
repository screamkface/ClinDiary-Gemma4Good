from datetime import date


def test_wearables_sync_populates_history_and_insights(client, auth_headers):
    sync_response = client.post(
        "/api/v1/wearables/sync-daily",
        headers=auth_headers,
        json={
            "items": [
                {
                    "summary_date": "2026-03-20",
                    "source_platform": "android",
                    "source_name": "Health Connect",
                    "source_device_model": "Pixel Watch",
                    "steps_count": 8421,
                    "active_energy_kcal": 512.4,
                    "exercise_minutes": 48,
                    "sleep_minutes": 436,
                    "heart_rate_avg_bpm": 76,
                    "resting_heart_rate_bpm": 63,
                    "blood_oxygen_avg_pct": 97,
                    "record_count": 18,
                },
                {
                    "summary_date": "2026-03-19",
                    "source_platform": "android",
                    "source_name": "Health Connect",
                    "steps_count": 5302,
                    "sleep_minutes": 410,
                    "heart_rate_avg_bpm": 79,
                    "record_count": 9,
                },
            ]
        },
    )
    assert sync_response.status_code == 200
    assert sync_response.json()["synced_count"] == 2

    list_response = client.get(
        "/api/v1/wearables/daily-summaries?days=30",
        headers=auth_headers,
    )
    assert list_response.status_code == 200
    summaries = list_response.json()
    assert len(summaries) == 2
    assert summaries[0]["summary_date"] == "2026-03-20"
    assert summaries[0]["steps_count"] == 8421

    history_response = client.get(
        f"/api/v1/history/day?target_date={date(2026, 3, 20).isoformat()}",
        headers=auth_headers,
    )
    assert history_response.status_code == 200
    history_body = history_response.json()
    assert history_body["wearable_summary"]["steps_count"] == 8421
    assert history_body["wearable_summary"]["source_device_model"] == "Pixel Watch"

    weekly_insight = client.get(
        "/api/v1/insights/weekly?reference_date=2026-03-20",
        headers=auth_headers,
    )
    assert weekly_insight.status_code == 200
    content = weekly_insight.json()["content"]
    assert "Dati wearable recenti considerati" in content
    assert "8421 passi" in content
    assert "media passi" in content


def test_wearables_sync_ignores_empty_metric_payloads(client, auth_headers):
    sync_response = client.post(
        "/api/v1/wearables/sync-daily",
        headers=auth_headers,
        json={
            "items": [
                {
                    "summary_date": "2026-03-20",
                    "source_platform": "ios",
                    "source_name": "Apple Health",
                    "record_count": 0,
                }
            ]
        },
    )

    assert sync_response.status_code == 200
    assert sync_response.json()["synced_count"] == 0

    list_response = client.get(
        "/api/v1/wearables/daily-summaries?days=30",
        headers=auth_headers,
    )
    assert list_response.status_code == 200
    assert list_response.json() == []


def test_wearables_sync_merges_duplicate_days_in_same_payload(client, auth_headers):
    sync_response = client.post(
        "/api/v1/wearables/sync-daily",
        headers=auth_headers,
        json={
            "items": [
                {
                    "summary_date": "2026-03-20",
                    "source_platform": "android",
                    "source_name": "Xiaomi Fitness",
                    "steps_count": 8421,
                    "record_count": 10,
                },
                {
                    "summary_date": "2026-03-20",
                    "source_platform": "android",
                    "source_name": "Xiaomi Fitness",
                    "sleep_minutes": 436,
                    "heart_rate_avg_bpm": 76,
                    "record_count": 8,
                },
            ]
        },
    )

    assert sync_response.status_code == 200
    body = sync_response.json()
    assert body["synced_count"] == 1
    assert len(body["items"]) == 1
    assert body["items"][0]["steps_count"] == 8421
    assert body["items"][0]["sleep_minutes"] == 436
    assert body["items"][0]["heart_rate_avg_bpm"] == 76
    assert body["items"][0]["record_count"] == 18
