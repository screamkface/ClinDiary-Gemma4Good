from enum import StrEnum


class UserRole(StrEnum):
    PATIENT = "patient"
    ADMIN = "admin"
    DOCTOR = "doctor"
    CAREGIVER = "caregiver"


class BiologicalSex(StrEnum):
    FEMALE = "female"
    MALE = "male"
    INTERSEX = "intersex"
    UNKNOWN = "unknown"


class AlcoholUse(StrEnum):
    NONE = "none"
    OCCASIONAL = "occasional"
    MODERATE = "moderate"
    HIGH = "high"


class ActivityLevel(StrEnum):
    SEDENTARY = "sedentary"
    LIGHT = "light"
    MODERATE = "moderate"
    ACTIVE = "active"
    VERY_ACTIVE = "very_active"


class ItalianRegionCode(StrEnum):
    IT = "IT"
    ABR = "IT-ABR"
    BAS = "IT-BAS"
    CAL = "IT-CAL"
    CAM = "IT-CAM"
    EMR = "IT-EMR"
    FVG = "IT-FVG"
    LAZ = "IT-LAZ"
    LIG = "IT-LIG"
    LOM = "IT-LOM"
    MAR = "IT-MAR"
    MOL = "IT-MOL"
    PIE = "IT-PIE"
    PUG = "IT-PUG"
    SAR = "IT-SAR"
    SIC = "IT-SIC"
    TOS = "IT-TOS"
    TAA = "IT-TAA"
    UMB = "IT-UMB"
    VDA = "IT-VDA"
    VEN = "IT-VEN"


class AllergySeverity(StrEnum):
    MILD = "mild"
    MODERATE = "moderate"
    SEVERE = "severe"


class ConditionStatus(StrEnum):
    ACTIVE = "active"
    RESOLVED = "resolved"
    MONITORING = "monitoring"


class TimelineEventType(StrEnum):
    DAILY_ENTRY = "daily_entry"
    SYMPTOM_EVENT = "symptom_event"
    VITAL_EVENT = "vital_event"
    PROFILE_UPDATED = "profile_updated"
    MEDICATION_STARTED = "medication_started"
    MEDICATION_STOPPED = "medication_stopped"
    MEDICATION_LOGGED = "medication_logged"
    DOCUMENT_UPLOADED = "document_uploaded"
    LAB_RESULT_SUMMARY = "lab_result_summary"
    IMAGING_SUMMARY = "imaging_summary"
    AI_ALERT = "ai_alert"
    REPORT_GENERATED = "report_generated"
    SCREENING_DUE = "screening_due"
    SCREENING_COMPLETED = "screening_completed"


class TimelineSeverity(StrEnum):
    INFO = "info"
    ATTENTION = "attention"
    IMPORTANT = "important"


class ClinicalDocumentType(StrEnum):
    LAB_REPORT = "lab_report"
    IMAGING_REPORT = "imaging_report"
    DISCHARGE_LETTER = "discharge_letter"
    SPECIALIST_VISIT = "specialist_visit"
    PRESCRIPTION = "prescription"
    MEDICAL_CERTIFICATE = "medical_certificate"
    GENERIC_DOCUMENT = "generic_document"


class DocumentParsedStatus(StrEnum):
    PENDING = "pending"
    PROCESSING = "processing"
    PARSED = "parsed"
    OCR_PENDING = "ocr_pending"
    REVIEW_REQUIRED = "review_required"
    REVIEWED = "reviewed"
    FAILED = "failed"


class DocumentScanStatus(StrEnum):
    SKIPPED = "skipped"
    PASSED = "passed"
    FAILED = "failed"


class DocumentContextStatus(StrEnum):
    ACTIVE = "active"
    OLD = "old"


class AiSummaryType(StrEnum):
    DAILY = "daily"
    WEEKLY = "weekly"
    MONTHLY = "monthly"
    PRE_VISIT = "pre_visit"


class AlertSeverity(StrEnum):
    INFO = "info"
    ATTENTION = "attention"
    CONTACT_DOCTOR = "contact_doctor"
    URGENCY = "urgency"


class AlertStatus(StrEnum):
    OPEN = "open"
    RESOLVED = "resolved"


class ReportType(StrEnum):
    WEEKLY_SUMMARY = "weekly_summary"
    MONTHLY_SUMMARY = "monthly_summary"
    PRE_VISIT_REPORT = "pre_visit_report"
    SCREENING_STATUS_REPORT = "screening_status_report"


class ReportStatus(StrEnum):
    GENERATED = "generated"
    FAILED = "failed"


class DossierShareScope(StrEnum):
    EMERGENCY = "emergency"
    FULL = "full"


class ScreeningStatus(StrEnum):
    NEVER_DONE = "never_done"
    RECOMMENDED = "recommended"
    SCHEDULED = "scheduled"
    COMPLETED = "completed"
    OVERDUE = "overdue"
    SKIPPED = "skipped"


class MedicationLogStatus(StrEnum):
    TAKEN = "taken"
    SKIPPED = "skipped"
    MISSED = "missed"


class NotificationType(StrEnum):
    DAILY_CHECKIN_REMINDER = "daily_checkin_reminder"
    MEDICATION_REMINDER = "medication_reminder"
    SCREENING_REMINDER = "screening_reminder"
    DOCUMENT_FOLLOW_UP = "document_follow_up"
    REPORT_READY = "report_ready"
    CLINICAL_ALERT = "clinical_alert"
    PREVENTION_TIP = "prevention_tip"


class NotificationPriority(StrEnum):
    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"
    URGENT = "urgent"


class BillingInterval(StrEnum):
    FREE = "free"
    MONTHLY = "monthly"
    YEARLY = "yearly"


class SubscriptionStatus(StrEnum):
    ACTIVE = "active"
    CANCELED = "canceled"
    EXPIRED = "expired"
    TRIALING = "trialing"


class SubscriptionProvider(StrEnum):
    MANUAL = "manual"
    APP_STORE = "app_store"
    GOOGLE_PLAY = "google_play"
    WEB = "web"
