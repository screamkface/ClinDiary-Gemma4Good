"""add vaccination records

Revision ID: 20260325_0015
Revises: 20260324_0014
Create Date: 2026-03-25 10:00:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260325_0015"
down_revision = "20260324_0014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "vaccination_records",
        sa.Column("patient_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("vaccine_name", sa.String(length=255), nullable=False),
        sa.Column("administered_on", sa.Date(), nullable=True),
        sa.Column("dose_number", sa.Integer(), nullable=True),
        sa.Column("next_due_date", sa.Date(), nullable=True),
        sa.Column("provider_name", sa.String(length=255), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["patient_id"],
            ["patient_profiles.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_vaccination_records_patient_administered_on",
        "vaccination_records",
        ["patient_id", "administered_on"],
    )


def downgrade() -> None:
    op.drop_index("ix_vaccination_records_patient_administered_on", table_name="vaccination_records")
    op.drop_table("vaccination_records")
