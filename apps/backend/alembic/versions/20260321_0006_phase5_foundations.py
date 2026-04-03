"""phase 5 foundations

Revision ID: 20260321_0006
Revises: 20260320_0005
Create Date: 2026-03-21 11:30:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260321_0006"
down_revision = "20260320_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("medication_schedules", sa.Column("days_of_week", sa.String(length=32), nullable=True))
    op.add_column("medication_schedules", sa.Column("start_date", sa.Date(), nullable=True))
    op.add_column("medication_schedules", sa.Column("end_date", sa.Date(), nullable=True))
    op.add_column("medication_schedules", sa.Column("cycle_days_on", sa.Integer(), nullable=True))
    op.add_column("medication_schedules", sa.Column("cycle_days_off", sa.Integer(), nullable=True))
    op.add_column("medication_schedules", sa.Column("paused_until", sa.Date(), nullable=True))

    op.add_column(
        "notification_preferences",
        sa.Column("push_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "notification_preferences",
        sa.Column("email_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "notification_preferences",
        sa.Column("email_address", sa.String(length=255), nullable=True),
    )

    op.create_table(
        "notification_device_tokens",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("platform", sa.String(length=50), nullable=False),
        sa.Column("device_token", sa.String(length=512), nullable=False),
        sa.Column("device_label", sa.String(length=255), nullable=True),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("patient_id", "device_token", name="uq_notification_device_token_patient_token"),
    )


def downgrade() -> None:
    op.drop_table("notification_device_tokens")
    op.drop_column("notification_preferences", "email_address")
    op.drop_column("notification_preferences", "email_enabled")
    op.drop_column("notification_preferences", "push_enabled")
    op.drop_column("medication_schedules", "paused_until")
    op.drop_column("medication_schedules", "cycle_days_off")
    op.drop_column("medication_schedules", "cycle_days_on")
    op.drop_column("medication_schedules", "end_date")
    op.drop_column("medication_schedules", "start_date")
    op.drop_column("medication_schedules", "days_of_week")
