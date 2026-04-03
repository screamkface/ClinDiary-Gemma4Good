"""widen alembic version table for long revision ids

Revision ID: 20260325_0017a_vtbl
Revises: 20260325_0017
Create Date: 2026-03-25 17:26:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260325_0017a_vtbl"
down_revision = "20260325_0017"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "alembic_version",
        "version_num",
        existing_type=sa.String(length=32),
        type_=sa.String(length=128),
        existing_nullable=False,
    )


def downgrade() -> None:
    op.alter_column(
        "alembic_version",
        "version_num",
        existing_type=sa.String(length=128),
        type_=sa.String(length=32),
        existing_nullable=False,
    )
