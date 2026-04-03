"""phase 4 notification preferences

Revision ID: 20260320_0005
Revises: 20260320_0004
Create Date: 2026-03-20 20:15:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260320_0005"
down_revision = "20260320_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "notification_preferences",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("in_app_enabled", sa.Boolean(), nullable=False),
        sa.Column("daily_checkin_enabled", sa.Boolean(), nullable=False),
        sa.Column("medication_reminders_enabled", sa.Boolean(), nullable=False),
        sa.Column("screening_reminders_enabled", sa.Boolean(), nullable=False),
        sa.Column("document_follow_up_enabled", sa.Boolean(), nullable=False),
        sa.Column("report_ready_enabled", sa.Boolean(), nullable=False),
        sa.Column("clinical_alerts_enabled", sa.Boolean(), nullable=False),
        sa.Column("prevention_tips_enabled", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("patient_id"),
    )


def downgrade() -> None:
    op.drop_table("notification_preferences")
