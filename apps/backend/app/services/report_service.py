from __future__ import annotations

from datetime import date, timedelta
from pathlib import PurePosixPath
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import create_report_download_token, decode_token
from app.core.storage import get_storage_service
from app.models.enums import (
    AlertStatus,
    DocumentContextStatus,
    ReportStatus,
    ReportType,
    TimelineEventType,
)
from app.models.report import Report
from app.models.user import User
from app.repositories.alert_repository import AlertRepository
from app.repositories.daily_entry_repository import DailyEntryRepository
from app.repositories.document_repository import DocumentRepository
from app.repositories.report_repository import ReportRepository
from app.repositories.screening_repository import ScreeningRepository
from app.repositories.timeline_repository import TimelineRepository
from app.schemas.reports import ReportResponse
from app.services.billing_service import BillingService
from app.services.insight_service import InsightService
from app.services.report_pdf_builder import ReportPdfBuilder
from app.services.profile_context import resolve_user_profile
from app.core.security import utcnow


class ReportService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.report_repository = ReportRepository(db)
        self.alert_repository = AlertRepository(db)
        self.daily_entry_repository = DailyEntryRepository(db)
        self.document_repository = DocumentRepository(db)
        self.timeline_repository = TimelineRepository(db)
        self.screening_repository = ScreeningRepository(db)
        self.storage_service = get_storage_service()
        self.insight_service = InsightService(db)
        self.billing_service = BillingService(db)
        self.pdf_builder = ReportPdfBuilder()

    def generate_report(self, user: User, *, report_type: ReportType, reference_date: date | None = None) -> Report:
        feature_code = self.billing_service.report_feature_code(report_type)
        if feature_code is not None:
            self.billing_service.require_feature(user, feature_code)
        profile = self._require_profile(user)
        period_start, period_end = self._compute_period(report_type, reference_date)
        entries = self.daily_entry_repository.list_for_patient_between(profile.id, period_start, period_end)
        alerts = self.alert_repository.list_for_patient(profile.id, status=AlertStatus.OPEN)
        documents = [
            document
            for document in self.document_repository.list_for_patient(
                profile.id,
                context_status=DocumentContextStatus.ACTIVE,
            )
            if period_start <= (document.exam_date or document.upload_date.date()) <= period_end
        ][:5]
        medications = [medication for medication in profile.medications if medication.active]

        screening_lines = self._build_screening_lines(profile.id)

        if report_type == ReportType.SCREENING_STATUS_REPORT:
            ai_summary = (
                "Riepilogo prudente dello stato screening generato da regole deterministiche e dati clinici disponibili."
            )
        else:
            ai_summary = self.insight_service.build_transient_summary(
                user,
                summary_label=self._report_label(report_type),
                period_start=period_start,
                period_end=period_end,
            )

        symptom_lines = [
            f"{entry.entry_date.isoformat()}: "
            + ", ".join(symptom.symptom_code for symptom in entry.symptoms)
            for entry in entries
            if entry.symptoms
        ][:8]
        trend_lines = self._build_trend_lines(entries)
        medication_lines = [
            f"{medication.name} {medication.dosage or ''} {medication.frequency or ''}".strip()
            for medication in medications
        ]
        document_lines = [
            f"{document.title} ({document.document_type.value}) del {(document.exam_date or document.upload_date.date()).isoformat()}"
            for document in documents
        ]
        alert_lines = [f"{alert.severity.value}: {alert.title}" for alert in alerts[:5]]
        title = f"ClinDiary - {self._report_label(report_type).capitalize()}"
        sections = [
            ("Sintomi recenti", symptom_lines),
            ("Trend principali", trend_lines),
            ("Farmaci", medication_lines),
            ("Documenti recenti", document_lines),
            ("Screening", screening_lines),
            ("Alert rilevanti", alert_lines),
            ("Riassunto AI prudente", [ai_summary]),
        ]
        pdf_bytes = self.pdf_builder.build(
            title=title,
            subtitle=f"Periodo: {period_start.isoformat()} - {period_end.isoformat()}",
            sections=sections,
        )

        object_key = self._build_object_key(profile.id, report_type)
        stored = self.storage_service.save_bytes(
            object_key=object_key,
            data=pdf_bytes,
            content_type="application/pdf",
        )
        content_text = "\n\n".join(
            [f"{heading}\n" + ("\n".join(items) if items else "Nessun dato disponibile.") for heading, items in sections]
        )
        report = Report(
            patient_id=profile.id,
            report_type=report_type,
            status=ReportStatus.GENERATED,
            title=title,
            period_start=period_start,
            period_end=period_end,
            summary_excerpt=ai_summary[:400],
            content_text=content_text,
            file_url=stored.object_key,
        )
        self.report_repository.add(report)
        self.db.flush()
        self.timeline_repository.upsert_source_event(
            patient_id=profile.id,
            source_type="report",
            source_id=report.id,
            event_type=TimelineEventType.REPORT_GENERATED,
            title=f"Report generato: {self._report_label(report_type)}",
            description=f"Report PDF disponibile per il periodo {period_start.isoformat()} - {period_end.isoformat()}.",
            event_date=utcnow(),
        )
        self.db.commit()
        self.db.refresh(report)
        return report

    def get_report(self, user: User, report_id: UUID) -> Report:
        profile = self._require_profile(user)
        report = self.report_repository.get_for_patient(profile.id, report_id)
        if report is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Report not found")
        return report

    def build_detail_response(self, user: User, report: Report) -> ReportResponse:
        download_token, _ = create_report_download_token(report_id=report.id, user_id=user.id)
        payload = ReportResponse.model_validate(report)
        return payload.model_copy(
            update={"download_url": f"/api/v1/reports/{report.id}/content?token={download_token}"}
        )

    def verify_download_token(self, report_id: UUID, token: str) -> None:
        try:
            payload = decode_token(token)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid report token") from exc

        if payload.get("type") != "report_download" or payload.get("report_id") != str(report_id):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid report token")

    def get_report_content(self, report_id: UUID) -> tuple[Report, bytes]:
        report = self.report_repository.get_by_id(report_id)
        if report is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Report not found")
        return report, self.storage_service.read_bytes(report.file_url)

    @staticmethod
    def _build_object_key(patient_id: UUID, report_type: ReportType) -> str:
        suffix = PurePosixPath(f"{report_type.value}.pdf").suffix
        return f"patients/{patient_id}/reports/{uuid4()}{suffix}"

    @staticmethod
    def _report_label(report_type: ReportType) -> str:
        return report_type.value.replace("_", " ")

    @staticmethod
    def _compute_period(report_type: ReportType, reference_date: date | None) -> tuple[date, date]:
        period_end = reference_date or date.today()
        if report_type == ReportType.WEEKLY_SUMMARY:
            return period_end - timedelta(days=6), period_end
        if report_type == ReportType.MONTHLY_SUMMARY:
            return period_end - timedelta(days=29), period_end
        if report_type == ReportType.PRE_VISIT_REPORT:
            return period_end - timedelta(days=29), period_end
        return period_end, period_end

    @staticmethod
    def _build_trend_lines(entries) -> list[str]:
        if not entries:
            return []

        energy_values = [entry.energy_level for entry in entries if entry.energy_level is not None]
        mood_values = [entry.mood_level for entry in entries if entry.mood_level is not None]
        pain_values = [entry.general_pain for entry in entries if entry.general_pain is not None]
        lines: list[str] = []
        if energy_values:
            lines.append(f"Energia media {sum(energy_values) / len(energy_values):.1f}/10.")
        if mood_values:
            lines.append(f"Umore medio {sum(mood_values) / len(mood_values):.1f}/10.")
        if pain_values:
            lines.append(f"Dolore medio {sum(pain_values) / len(pain_values):.1f}/10.")
        return lines

    def _build_screening_lines(self, patient_id: UUID) -> list[str]:
        try:
            from app.services.screening_service import ScreeningService

            ScreeningService(self.db)._recompute_for_profile(patient_id, emit_notifications=False)
        except Exception:
            pass

        statuses = self.screening_repository.list_statuses_for_patient(patient_id)
        if not statuses:
            return ["Nessun programma screening eleggibile disponibile con i dati correnti del profilo."]

        return [
            (
                f"{item.screening_program.name}: stato {item.status.value}, "
                f"prossima data {(item.next_due_date or item.last_done_date or date.today()).isoformat()}."
            )
            for item in statuses[:8]
        ]

    @staticmethod
    def _require_profile(user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile
