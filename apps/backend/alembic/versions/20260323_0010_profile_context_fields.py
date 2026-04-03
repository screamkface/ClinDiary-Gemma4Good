"""add profile context fields

Revision ID: 20260323_0010
Revises: 20260321_0009
Create Date: 2026-03-23 16:05:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260323_0010"
down_revision = "20260321_0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("patient_profiles", sa.Column("occupation", sa.Text(), nullable=True))
    op.add_column("patient_profiles", sa.Column("exercise_habits", sa.Text(), nullable=True))
    op.add_column("patient_profiles", sa.Column("sleep_pattern", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("patient_profiles", "sleep_pattern")
    op.drop_column("patient_profiles", "exercise_habits")
    op.drop_column("patient_profiles", "occupation")
