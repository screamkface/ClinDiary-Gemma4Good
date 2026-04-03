"""add google subject to users

Revision ID: 20260325_0017
Revises: 20260325_0016
Create Date: 2026-03-25 17:25:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260325_0017"
down_revision = "20260325_0016"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("google_subject", sa.String(length=255), nullable=True),
    )
    op.create_index(
        "ix_users_google_subject",
        "users",
        ["google_subject"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("ix_users_google_subject", table_name="users")
    op.drop_column("users", "google_subject")
