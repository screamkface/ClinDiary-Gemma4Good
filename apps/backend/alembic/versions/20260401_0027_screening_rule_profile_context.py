"""extend screening rules with profile context fields

Revision ID: 20260401_0027
Revises: 20260331_0026
Create Date: 2026-04-01 10:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260401_0027"
down_revision = "20260331_0026_billing_entitlements"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "screening_rules",
        sa.Column("condition_keyword", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "screening_rules",
        sa.Column(
            "alcohol_use_required",
            sa.Enum(
                "none",
                "occasional",
                "moderate",
                "high",
                name="alcohol_use",
                create_type=False,
            ),
            nullable=True,
        ),
    )
    op.add_column(
        "screening_rules",
        sa.Column(
            "activity_level_required",
            sa.Enum(
                "sedentary",
                "light",
                "moderate",
                "active",
                "very_active",
                name="activity_level",
                create_type=False,
            ),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("screening_rules", "activity_level_required")
    op.drop_column("screening_rules", "alcohol_use_required")
    op.drop_column("screening_rules", "condition_keyword")
