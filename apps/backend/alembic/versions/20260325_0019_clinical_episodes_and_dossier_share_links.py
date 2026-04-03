"""add clinical episodes and dossier share links

Revision ID: 20260325_0019_clinical_episodes_and_dossier_share_links
Revises: 20260325_0018_refresh_token_auth_provider
Create Date: 2026-03-25 17:30:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260325_0019_clinical_episodes_and_dossier_share_links"
down_revision = "20260325_0018_refresh_token_auth_provider"
branch_labels = None
depends_on = None


clinical_episode_status = postgresql.ENUM(
    "active",
    "resolved",
    "monitoring",
    name="clinical_episode_status",
    create_type=False,
)

dossier_share_scope = postgresql.ENUM(
    "emergency",
    "full",
    name="dossier_share_scope",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    clinical_episode_status.create(bind, checkfirst=True)
    dossier_share_scope.create(bind, checkfirst=True)

    op.create_table(
        "clinical_episodes",
        sa.Column("patient_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.Column("status", clinical_episode_status, nullable=True),
        sa.Column("onset_date", sa.Date(), nullable=True),
        sa.Column("resolved_date", sa.Date(), nullable=True),
        sa.Column("next_review_date", sa.Date(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["patient_id"],
            ["patient_profiles.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_clinical_episodes_patient_created_at",
        "clinical_episodes",
        ["patient_id", "created_at"],
    )

    op.create_table(
        "dossier_share_links",
        sa.Column("patient_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("scope", dossier_share_scope, nullable=False),
        sa.Column("label", sa.String(length=255), nullable=True),
        sa.Column("filename", sa.String(length=255), nullable=False),
        sa.Column("mime_type", sa.String(length=128), nullable=False),
        sa.Column("object_key", sa.String(length=512), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_accessed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["patient_id"],
            ["patient_profiles.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token_hash"),
    )
    op.create_index(
        "ix_dossier_share_links_patient_created_at",
        "dossier_share_links",
        ["patient_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_dossier_share_links_patient_created_at", table_name="dossier_share_links")
    op.drop_table("dossier_share_links")
    op.drop_index("ix_clinical_episodes_patient_created_at", table_name="clinical_episodes")
    op.drop_table("clinical_episodes")

    bind = op.get_bind()
    dossier_share_scope.drop(bind, checkfirst=True)
    clinical_episode_status.drop(bind, checkfirst=True)
