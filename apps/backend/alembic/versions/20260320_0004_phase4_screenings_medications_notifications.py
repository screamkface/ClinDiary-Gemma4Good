"""phase 4 screenings medications notifications

Revision ID: 20260320_0004
Revises: 20260320_0003
Create Date: 2026-03-20 18:30:00
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260320_0004"
down_revision = "20260320_0003"
branch_labels = None
depends_on = None


screening_status = postgresql.ENUM(
    "never_done",
    "recommended",
    "scheduled",
    "completed",
    "overdue",
    "skipped",
    name="screening_status",
    create_type=False,
)
medication_log_status = postgresql.ENUM(
    "taken",
    "skipped",
    "missed",
    name="medication_log_status",
    create_type=False,
)
notification_type = postgresql.ENUM(
    "daily_checkin_reminder",
    "medication_reminder",
    "screening_reminder",
    "document_follow_up",
    "report_ready",
    "clinical_alert",
    "prevention_tip",
    name="notification_type",
    create_type=False,
)
notification_priority = postgresql.ENUM(
    "low",
    "normal",
    "high",
    "urgent",
    name="notification_priority",
    create_type=False,
)
biological_sex = postgresql.ENUM(
    "female",
    "male",
    "intersex",
    "unknown",
    name="biological_sex",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    screening_status.create(bind, checkfirst=True)
    medication_log_status.create(bind, checkfirst=True)
    notification_type.create(bind, checkfirst=True)
    notification_priority.create(bind, checkfirst=True)

    op.execute("ALTER TYPE timeline_event_type ADD VALUE IF NOT EXISTS 'medication_logged'")
    op.execute("ALTER TYPE timeline_event_type ADD VALUE IF NOT EXISTS 'screening_due'")
    op.execute("ALTER TYPE timeline_event_type ADD VALUE IF NOT EXISTS 'screening_completed'")

    op.create_table(
        "screening_programs",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("code", sa.String(length=100), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("min_age", sa.Integer(), nullable=True),
        sa.Column("max_age", sa.Integer(), nullable=True),
        sa.Column("target_sex", biological_sex, nullable=True),
        sa.Column("interval_months", sa.Integer(), nullable=True),
        sa.Column("public_coverage_flag", sa.Boolean(), nullable=False),
        sa.Column("category", sa.String(length=100), nullable=False),
        sa.Column("explanation", sa.Text(), nullable=True),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code"),
    )

    op.create_table(
        "screening_rules",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("screening_program_id", sa.Uuid(), nullable=False),
        sa.Column("rule_code", sa.String(length=100), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("min_age", sa.Integer(), nullable=True),
        sa.Column("max_age", sa.Integer(), nullable=True),
        sa.Column("target_sex", biological_sex, nullable=True),
        sa.Column("smoker_required", sa.Boolean(), nullable=True),
        sa.Column("family_history_keyword", sa.String(length=255), nullable=True),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["screening_program_id"], ["screening_programs.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "patient_screening_status",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("screening_program_id", sa.Uuid(), nullable=False),
        sa.Column("last_done_date", sa.Date(), nullable=True),
        sa.Column("next_due_date", sa.Date(), nullable=True),
        sa.Column("status", screening_status, nullable=False),
        sa.Column("recommendation_reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["screening_program_id"], ["screening_programs.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("patient_id", "screening_program_id", name="uq_patient_screening_program"),
    )

    op.create_table(
        "regional_screening_availability",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("screening_program_id", sa.Uuid(), nullable=False),
        sa.Column("region_code", sa.String(length=50), nullable=False),
        sa.Column("region_name", sa.String(length=255), nullable=False),
        sa.Column("booking_url", sa.String(length=512), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["screening_program_id"], ["screening_programs.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "notifications",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("notification_type", notification_type, nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("priority", notification_priority, nullable=False),
        sa.Column("read_status", sa.Boolean(), nullable=False),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("source_type", sa.String(length=100), nullable=True),
        sa.Column("source_id", sa.Uuid(), nullable=True),
        sa.Column("dedupe_key", sa.String(length=255), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("patient_id", "dedupe_key", name="uq_notification_patient_dedupe"),
    )

    op.create_table(
        "screening_notifications",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("screening_program_id", sa.Uuid(), nullable=False),
        sa.Column("patient_screening_status_id", sa.Uuid(), nullable=False),
        sa.Column("notification_id", sa.Uuid(), nullable=True),
        sa.Column("scheduled_for", sa.DateTime(timezone=True), nullable=True),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["screening_program_id"], ["screening_programs.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["patient_screening_status_id"], ["patient_screening_status.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["notification_id"], ["notifications.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "medication_schedules",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("medication_id", sa.Uuid(), nullable=False),
        sa.Column("scheduled_time", sa.Time(), nullable=False),
        sa.Column("instructions", sa.String(length=255), nullable=True),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["medication_id"], ["medications.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "medication_logs",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("medication_id", sa.Uuid(), nullable=False),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("taken_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("status", medication_log_status, nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["medication_id"], ["medications.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade() -> None:
    op.drop_table("medication_logs")
    op.drop_table("medication_schedules")
    op.drop_table("screening_notifications")
    op.drop_table("notifications")
    op.drop_table("regional_screening_availability")
    op.drop_table("patient_screening_status")
    op.drop_table("screening_rules")
    op.drop_table("screening_programs")

    bind = op.get_bind()
    notification_priority.drop(bind, checkfirst=True)
    notification_type.drop(bind, checkfirst=True)
    medication_log_status.drop(bind, checkfirst=True)
    screening_status.drop(bind, checkfirst=True)
