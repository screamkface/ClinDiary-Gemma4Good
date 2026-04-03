"""add ai external consent to onboarding

Revision ID: 20260325_0020_ai_external_consent
Revises: 20260325_0019_clinical_episodes_and_dossier_share_links
Create Date: 2026-03-25 20:10:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260325_0020_ai_external_consent"
down_revision = "20260325_0019_clinical_episodes_and_dossier_share_links"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "user_onboarding_statuses",
        sa.Column("ai_external_consent", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "user_onboarding_statuses",
        sa.Column("ai_external_consented_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("user_onboarding_statuses", "ai_external_consented_at")
    op.drop_column("user_onboarding_statuses", "ai_external_consent")
