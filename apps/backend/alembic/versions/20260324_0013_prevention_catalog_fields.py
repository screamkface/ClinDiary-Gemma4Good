"""add prevention catalog fields

Revision ID: 20260324_0013
Revises: 20260323_0012
Create Date: 2026-03-24 12:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260324_0013"
down_revision = "20260323_0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "screening_programs",
        sa.Column(
            "recommendation_level",
            sa.String(length=32),
            nullable=False,
            server_default="routine",
        ),
    )
    op.add_column(
        "screening_programs",
        sa.Column("cadence_label", sa.String(length=120), nullable=True),
    )
    op.add_column(
        "screening_programs",
        sa.Column(
            "catalog_only",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "screening_rules",
        sa.Column("min_bmi", sa.Float(), nullable=True),
    )

    op.execute(
        "UPDATE screening_programs "
        "SET recommendation_level = 'routine', catalog_only = FALSE "
        "WHERE recommendation_level IS NULL OR catalog_only IS NULL"
    )

    op.alter_column("screening_programs", "recommendation_level", server_default=None)
    op.alter_column("screening_programs", "catalog_only", server_default=None)


def downgrade() -> None:
    op.drop_column("screening_rules", "min_bmi")
    op.drop_column("screening_programs", "catalog_only")
    op.drop_column("screening_programs", "cadence_label")
    op.drop_column("screening_programs", "recommendation_level")
