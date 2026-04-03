"""add wave 3 pregnancy and preconception profile fields

Revision ID: 20260401_0029
Revises: 20260401_0028
Create Date: 2026-04-01 12:10:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260401_0029"
down_revision = "20260401_0028"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "patient_profiles",
        sa.Column(
            "trying_to_conceive",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "patient_profiles",
        sa.Column(
            "currently_pregnant",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "patient_profiles",
        sa.Column(
            "taking_folic_acid",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )

    op.alter_column("patient_profiles", "trying_to_conceive", server_default=None)
    op.alter_column("patient_profiles", "currently_pregnant", server_default=None)
    op.alter_column("patient_profiles", "taking_folic_acid", server_default=None)


def downgrade() -> None:
    op.drop_column("patient_profiles", "taking_folic_acid")
    op.drop_column("patient_profiles", "currently_pregnant")
    op.drop_column("patient_profiles", "trying_to_conceive")
