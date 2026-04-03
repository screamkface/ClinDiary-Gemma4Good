"""add profile triggers and functional limitations

Revision ID: 20260323_0011
Revises: 20260323_0010
Create Date: 2026-03-23 16:45:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260323_0011"
down_revision = "20260323_0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("patient_profiles", sa.Column("symptom_triggers", sa.Text(), nullable=True))
    op.add_column("patient_profiles", sa.Column("functional_limitations", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("patient_profiles", "functional_limitations")
    op.drop_column("patient_profiles", "symptom_triggers")
