"""allow multiple managed profiles per user

Revision ID: 20260325_0021_managed_profiles
Revises: 20260325_0020_ai_external_consent
Create Date: 2026-03-25 21:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260325_0021_managed_profiles"
down_revision = "20260325_0020_ai_external_consent"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "patient_profiles",
        sa.Column("is_primary", sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    op.add_column("patient_profiles", sa.Column("relationship_label", sa.Text(), nullable=True))

    op.execute(sa.text("UPDATE patient_profiles SET is_primary = true WHERE is_primary IS NULL"))
    op.execute(sa.text("ALTER TABLE patient_profiles DROP CONSTRAINT IF EXISTS patient_profiles_user_id_key"))
    op.create_index("ix_patient_profiles_user_id", "patient_profiles", ["user_id"])
    op.execute(
        sa.text(
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_patient_profiles_primary_per_user "
            "ON patient_profiles (user_id) WHERE is_primary = true"
        )
    )
    op.alter_column("patient_profiles", "is_primary", server_default=None)


def downgrade() -> None:
    op.execute(sa.text("DROP INDEX IF EXISTS uq_patient_profiles_primary_per_user"))
    op.drop_index("ix_patient_profiles_user_id", table_name="patient_profiles")
    op.execute(
        sa.text(
            "ALTER TABLE patient_profiles ADD CONSTRAINT patient_profiles_user_id_key UNIQUE (user_id)"
        )
    )
    op.drop_column("patient_profiles", "relationship_label")
    op.drop_column("patient_profiles", "is_primary")
