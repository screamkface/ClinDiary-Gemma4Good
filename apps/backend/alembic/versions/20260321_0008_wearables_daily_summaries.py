"""wearables daily summaries

Revision ID: 20260321_0008
Revises: 20260321_0007
Create Date: 2026-03-21 20:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260321_0008"
down_revision = "20260321_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "wearable_daily_summaries",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("summary_date", sa.Date(), nullable=False),
        sa.Column("source_platform", sa.String(length=64), nullable=False),
        sa.Column("source_name", sa.String(length=255), nullable=True),
        sa.Column("source_device_model", sa.String(length=255), nullable=True),
        sa.Column("steps_count", sa.Integer(), nullable=True),
        sa.Column("active_energy_kcal", sa.Float(), nullable=True),
        sa.Column("exercise_minutes", sa.Float(), nullable=True),
        sa.Column("distance_meters", sa.Float(), nullable=True),
        sa.Column("sleep_minutes", sa.Float(), nullable=True),
        sa.Column("sleep_deep_minutes", sa.Float(), nullable=True),
        sa.Column("sleep_rem_minutes", sa.Float(), nullable=True),
        sa.Column("heart_rate_avg_bpm", sa.Float(), nullable=True),
        sa.Column("heart_rate_min_bpm", sa.Float(), nullable=True),
        sa.Column("heart_rate_max_bpm", sa.Float(), nullable=True),
        sa.Column("resting_heart_rate_bpm", sa.Float(), nullable=True),
        sa.Column("blood_oxygen_avg_pct", sa.Float(), nullable=True),
        sa.Column("hrv_sdnn_ms", sa.Float(), nullable=True),
        sa.Column("record_count", sa.Integer(), nullable=False),
        sa.Column("synced_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("patient_id", "summary_date", name="uq_wearable_daily_summary_patient_date"),
    )


def downgrade() -> None:
    op.drop_table("wearable_daily_summaries")
