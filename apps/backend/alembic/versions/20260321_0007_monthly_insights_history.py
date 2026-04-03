"""monthly insights history

Revision ID: 20260321_0007
Revises: 20260321_0006
Create Date: 2026-03-21 18:10:00
"""

from alembic import op


revision = "20260321_0007"
down_revision = "20260321_0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE ai_summary_type ADD VALUE IF NOT EXISTS 'monthly'")


def downgrade() -> None:
    # PostgreSQL enum value removal is intentionally omitted.
    pass
