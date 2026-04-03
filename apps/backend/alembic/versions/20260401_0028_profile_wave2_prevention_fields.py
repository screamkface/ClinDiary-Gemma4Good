"""add wave 2 prevention profile fields

Revision ID: 20260401_0028
Revises: 20260401_0027
Create Date: 2026-04-01 11:15:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260401_0028"
down_revision = "20260401_0027"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "patient_profiles",
        sa.Column("former_smoker", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column("patient_profiles", sa.Column("smoking_pack_years", sa.Float(), nullable=True))
    op.add_column("patient_profiles", sa.Column("years_since_quitting", sa.Integer(), nullable=True))
    op.add_column(
        "patient_profiles",
        sa.Column("postmenopausal", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "patient_profiles",
        sa.Column(
            "fragility_fracture_history",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column("patient_profiles", sa.Column("falls_last_year", sa.Integer(), nullable=True))
    op.add_column(
        "patient_profiles",
        sa.Column("feels_unsteady", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column("patient_profiles", sa.Column("sexually_active", sa.Boolean(), nullable=True))
    op.add_column(
        "patient_profiles",
        sa.Column(
            "new_or_multiple_partners",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "patient_profiles",
        sa.Column("partner_with_sti", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "patient_profiles",
        sa.Column("sex_with_men", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "patient_profiles",
        sa.Column(
            "sti_or_exposure_concerns",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )

    op.alter_column("patient_profiles", "former_smoker", server_default=None)
    op.alter_column("patient_profiles", "postmenopausal", server_default=None)
    op.alter_column("patient_profiles", "fragility_fracture_history", server_default=None)
    op.alter_column("patient_profiles", "feels_unsteady", server_default=None)
    op.alter_column("patient_profiles", "new_or_multiple_partners", server_default=None)
    op.alter_column("patient_profiles", "partner_with_sti", server_default=None)
    op.alter_column("patient_profiles", "sex_with_men", server_default=None)
    op.alter_column("patient_profiles", "sti_or_exposure_concerns", server_default=None)


def downgrade() -> None:
    op.drop_column("patient_profiles", "sti_or_exposure_concerns")
    op.drop_column("patient_profiles", "sex_with_men")
    op.drop_column("patient_profiles", "partner_with_sti")
    op.drop_column("patient_profiles", "new_or_multiple_partners")
    op.drop_column("patient_profiles", "sexually_active")
    op.drop_column("patient_profiles", "feels_unsteady")
    op.drop_column("patient_profiles", "falls_last_year")
    op.drop_column("patient_profiles", "fragility_fracture_history")
    op.drop_column("patient_profiles", "postmenopausal")
    op.drop_column("patient_profiles", "years_since_quitting")
    op.drop_column("patient_profiles", "smoking_pack_years")
    op.drop_column("patient_profiles", "former_smoker")
