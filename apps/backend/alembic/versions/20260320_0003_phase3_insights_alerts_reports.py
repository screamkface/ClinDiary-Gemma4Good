"""phase 3 insights alerts reports

Revision ID: 20260320_0003
Revises: 20260320_0002
Create Date: 2026-03-20 16:00:00
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260320_0003"
down_revision = "20260320_0002"
branch_labels = None
depends_on = None


ai_summary_type = postgresql.ENUM("daily", "weekly", "pre_visit", name="ai_summary_type", create_type=False)
alert_severity = postgresql.ENUM(
    "info",
    "attention",
    "contact_doctor",
    "urgency",
    name="alert_severity",
    create_type=False,
)
alert_status = postgresql.ENUM("open", "resolved", name="alert_status", create_type=False)
report_type = postgresql.ENUM(
    "weekly_summary",
    "monthly_summary",
    "pre_visit_report",
    "screening_status_report",
    name="report_type",
    create_type=False,
)
report_status = postgresql.ENUM("generated", "failed", name="report_status", create_type=False)


def upgrade() -> None:
    bind = op.get_bind()
    ai_summary_type.create(bind, checkfirst=True)
    alert_severity.create(bind, checkfirst=True)
    alert_status.create(bind, checkfirst=True)
    report_type.create(bind, checkfirst=True)
    report_status.create(bind, checkfirst=True)

    op.execute("ALTER TYPE timeline_event_type ADD VALUE IF NOT EXISTS 'ai_alert'")
    op.execute("ALTER TYPE timeline_event_type ADD VALUE IF NOT EXISTS 'report_generated'")

    op.create_table(
        "ai_summaries",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("summary_type", ai_summary_type, nullable=False),
        sa.Column("period_start", sa.Date(), nullable=False),
        sa.Column("period_end", sa.Date(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "patient_id",
            "summary_type",
            "period_start",
            "period_end",
            name="uq_ai_summary_patient_type_period",
        ),
    )

    op.create_table(
        "alerts",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("severity", alert_severity, nullable=False),
        sa.Column("alert_type", sa.String(length=100), nullable=False),
        sa.Column("rule_code", sa.String(length=100), nullable=True),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("status", alert_status, nullable=False),
        sa.Column("source_type", sa.String(length=100), nullable=True),
        sa.Column("source_id", sa.Uuid(), nullable=True),
        sa.Column("triggered_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("resolution_notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "reports",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("report_type", report_type, nullable=False),
        sa.Column("status", report_status, nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("period_start", sa.Date(), nullable=False),
        sa.Column("period_end", sa.Date(), nullable=False),
        sa.Column("summary_excerpt", sa.Text(), nullable=True),
        sa.Column("content_text", sa.Text(), nullable=False),
        sa.Column("file_url", sa.String(length=512), nullable=False),
        sa.Column("processing_error", sa.Text(), nullable=True),
        sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade() -> None:
    op.drop_table("reports")
    op.drop_table("alerts")
    op.drop_table("ai_summaries")

    bind = op.get_bind()
    report_status.drop(bind, checkfirst=True)
    report_type.drop(bind, checkfirst=True)
    alert_status.drop(bind, checkfirst=True)
    alert_severity.drop(bind, checkfirst=True)
    ai_summary_type.drop(bind, checkfirst=True)
