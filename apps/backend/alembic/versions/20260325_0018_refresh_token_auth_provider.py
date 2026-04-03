"""add refresh token auth provider

Revision ID: 20260325_0018_refresh_token_auth_provider
Revises: 20260325_0017a_vtbl
Create Date: 2026-03-25 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260325_0018_refresh_token_auth_provider"
down_revision = "20260325_0017a_vtbl"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "refresh_tokens",
        sa.Column(
            "auth_provider",
            sa.String(length=32),
            nullable=False,
            server_default="password",
        ),
    )


def downgrade() -> None:
    op.drop_column("refresh_tokens", "auth_provider")
