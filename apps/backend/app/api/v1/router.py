from fastapi import APIRouter

from app.api.v1 import (
    alerts,
    auth,
    billing,
    daily_entries,
    devices,
    dossier,
    documents,
    history,
    insights,
    medications,
    notifications,
    prevention_center,
    profile,
    reports,
    screenings,
    symptoms,
    timeline,
    vitals,
    wearables,
)


api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(billing.router)
api_router.include_router(devices.router)
api_router.include_router(profile.router)
api_router.include_router(daily_entries.router)
api_router.include_router(symptoms.router)
api_router.include_router(vitals.router)
api_router.include_router(documents.router)
api_router.include_router(history.router)
api_router.include_router(timeline.router)
api_router.include_router(insights.router)
api_router.include_router(alerts.router)
api_router.include_router(prevention_center.router)
api_router.include_router(screenings.router)
api_router.include_router(medications.router)
api_router.include_router(notifications.router)
api_router.include_router(wearables.router)
api_router.include_router(reports.router)
api_router.include_router(dossier.router)
