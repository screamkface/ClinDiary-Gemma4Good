from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.enums import NotificationPriority, NotificationType


class NotificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    patient_id: UUID
    notification_type: NotificationType
    title: str
    body: str
    priority: NotificationPriority
    read_status: bool
    read_at: datetime | None
    source_type: str | None
    source_id: UUID | None
    created_at: datetime


class NotificationMarkReadResponse(NotificationResponse):
    pass


class NotificationPreferencesResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    in_app_enabled: bool
    daily_checkin_enabled: bool
    medication_reminders_enabled: bool
    screening_reminders_enabled: bool
    document_follow_up_enabled: bool
    report_ready_enabled: bool
    clinical_alerts_enabled: bool
    prevention_tips_enabled: bool
    push_enabled: bool
    email_enabled: bool
    email_address: str | None


class NotificationPreferencesUpdateRequest(BaseModel):
    in_app_enabled: bool | None = None
    daily_checkin_enabled: bool | None = None
    medication_reminders_enabled: bool | None = None
    screening_reminders_enabled: bool | None = None
    document_follow_up_enabled: bool | None = None
    report_ready_enabled: bool | None = None
    clinical_alerts_enabled: bool | None = None
    prevention_tips_enabled: bool | None = None
    push_enabled: bool | None = None
    email_enabled: bool | None = None
    email_address: str | None = None


class NotificationDeviceRegistrationRequest(BaseModel):
    platform: str
    device_token: str
    device_label: str | None = None


class NotificationDeviceRegistrationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    platform: str
    device_token: str
    device_label: str | None
    active: bool
    last_seen_at: datetime


class NotificationDeliveryChannelResultResponse(BaseModel):
    channel: str
    provider: str
    attempted: bool
    delivered: bool
    target_count: int = 0
    delivered_count: int = 0
    error: str | None = None


class NotificationDeliveryReportResponse(BaseModel):
    push: NotificationDeliveryChannelResultResponse | None = None
    email: NotificationDeliveryChannelResultResponse | None = None
    attempted: bool
    delivered: bool
    has_errors: bool


class NotificationTestDeliveryRequest(BaseModel):
    title: str = "ClinDiary: notifica di test"
    body: str = "Messaggio di verifica delivery."
    notification_type: NotificationType = NotificationType.REPORT_READY
    priority: NotificationPriority = NotificationPriority.NORMAL
    include_push: bool = True
    include_email: bool = True
    email_address: str | None = None
