"""add screening completion records

Revision ID: 20260324_0014
Revises: 20260324_0013
Create Date: 2026-03-24 18:30:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from datetime import datetime, timezone
import uuid


revision = "20260324_0014"
down_revision = "20260324_0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "screening_completion_records",
        sa.Column("patient_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("screening_program_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("completed_on", sa.Date(), nullable=False),
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["patient_id"],
            ["patient_profiles.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["screening_program_id"],
            ["screening_programs.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "patient_id",
            "screening_program_id",
            "completed_on",
            name="uq_screening_completion_patient_program_date",
        ),
    )

    bind = op.get_bind()
    rows = bind.execute(
        sa.text(
            """
            SELECT patient_id, screening_program_id, last_done_date
            FROM patient_screening_status
            WHERE last_done_date IS NOT NULL
            """
        )
    ).mappings()
    now = datetime.now(timezone.utc)
    payload = [
        {
            "id": uuid.uuid4(),
            "patient_id": row["patient_id"],
            "screening_program_id": row["screening_program_id"],
            "completed_on": row["last_done_date"],
            "created_at": now,
            "updated_at": now,
        }
        for row in rows
    ]
    if payload:
        completion_table = sa.table(
            "screening_completion_records",
            sa.column("id", postgresql.UUID(as_uuid=True)),
            sa.column("patient_id", postgresql.UUID(as_uuid=True)),
            sa.column("screening_program_id", postgresql.UUID(as_uuid=True)),
            sa.column("completed_on", sa.Date()),
            sa.column("created_at", sa.DateTime(timezone=True)),
            sa.column("updated_at", sa.DateTime(timezone=True)),
        )
        op.bulk_insert(completion_table, payload)


def downgrade() -> None:
    op.drop_table("screening_completion_records")
