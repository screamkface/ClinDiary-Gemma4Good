"""add device wave 1 connection and measurement tables

Revision ID: 20260401_0030
Revises: 20260401_0029
Create Date: 2026-04-01 18:30:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260401_0030"
down_revision = "20260401_0029"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "device_connections",
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("provider_code", sa.String(length=64), nullable=False),
        sa.Column("provider_name", sa.String(length=120), nullable=False),
        sa.Column("integration_kind", sa.String(length=32), nullable=False),
        sa.Column("connection_flow", sa.String(length=32), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False, server_default="pending"),
        sa.Column("account_label", sa.String(length=255), nullable=True),
        sa.Column("external_user_id", sa.String(length=255), nullable=True),
        sa.Column("access_token", sa.Text(), nullable=True),
        sa.Column("refresh_token", sa.Text(), nullable=True),
        sa.Column("api_key", sa.Text(), nullable=True),
        sa.Column("token_expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("scopes_csv", sa.Text(), nullable=True),
        sa.Column("metadata_json", sa.Text(), nullable=True),
        sa.Column("last_synced_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("patient_id", "provider_code", name="uq_device_connection_patient_provider"),
    )
    op.create_table(
        "device_import_jobs",
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("connection_id", sa.Uuid(), nullable=True),
        sa.Column("provider_code", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False, server_default="pending"),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("item_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["connection_id"], ["device_connections.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "device_measurements",
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("connection_id", sa.Uuid(), nullable=True),
        sa.Column("provider_code", sa.String(length=64), nullable=False),
        sa.Column("metric_type", sa.String(length=64), nullable=False),
        sa.Column("measured_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("source_record_id", sa.String(length=255), nullable=True),
        sa.Column("source_device_model", sa.String(length=255), nullable=True),
        sa.Column("unit", sa.String(length=64), nullable=True),
        sa.Column("primary_value", sa.Float(), nullable=True),
        sa.Column("secondary_value", sa.Float(), nullable=True),
        sa.Column("tertiary_value", sa.Float(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("raw_payload_json", sa.Text(), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["connection_id"], ["device_connections.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_device_measurements_patient_measured_at",
        "device_measurements",
        ["patient_id", "measured_at"],
        unique=False,
    )
    op.create_index(
        "ix_device_measurements_connection_id",
        "device_measurements",
        ["connection_id"],
        unique=False,
    )
    op.create_index(
        "ix_device_measurements_metric_type",
        "device_measurements",
        ["metric_type"],
        unique=False,
    )

    op.alter_column("device_connections", "status", server_default=None)
    op.alter_column("device_import_jobs", "status", server_default=None)
    op.alter_column("device_import_jobs", "item_count", server_default=None)


def downgrade() -> None:
    op.drop_index("ix_device_measurements_metric_type", table_name="device_measurements")
    op.drop_index("ix_device_measurements_connection_id", table_name="device_measurements")
    op.drop_index("ix_device_measurements_patient_measured_at", table_name="device_measurements")
    op.drop_table("device_measurements")
    op.drop_table("device_import_jobs")
    op.drop_table("device_connections")
