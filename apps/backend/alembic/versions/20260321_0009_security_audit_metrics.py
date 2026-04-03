"""security audit metrics foundations

Revision ID: 20260321_0009
Revises: 20260321_0008
Create Date: 2026-03-21 22:40:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260321_0009"
down_revision = "20260321_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    document_scan_status = sa.Enum(
        "skipped",
        "passed",
        "failed",
        name="document_scan_status",
    )
    document_scan_status.create(bind, checkfirst=True)

    op.create_table(
        "audit_logs",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("actor_user_id", sa.Uuid(), nullable=True),
        sa.Column("patient_id", sa.Uuid(), nullable=True),
        sa.Column("actor_email", sa.String(length=255), nullable=True),
        sa.Column("request_id", sa.String(length=64), nullable=True),
        sa.Column("event_type", sa.String(length=80), nullable=False),
        sa.Column("entity_type", sa.String(length=80), nullable=False),
        sa.Column("entity_id", sa.Uuid(), nullable=True),
        sa.Column("outcome", sa.String(length=32), nullable=False),
        sa.Column("summary", sa.String(length=255), nullable=False),
        sa.Column("metadata_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.add_column("ai_summaries", sa.Column("provider_name", sa.String(length=64), nullable=True))
    op.add_column("ai_summaries", sa.Column("model_name", sa.String(length=128), nullable=True))

    op.add_column("clinical_documents", sa.Column("content_sha256", sa.String(length=64), nullable=True))
    op.add_column(
        "clinical_documents",
        sa.Column(
            "file_signature_valid",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )
    op.add_column(
        "clinical_documents",
        sa.Column(
            "scan_status",
            document_scan_status,
            nullable=False,
            server_default="skipped",
        ),
    )
    op.add_column("clinical_documents", sa.Column("scan_provider", sa.String(length=64), nullable=True))
    op.add_column("clinical_documents", sa.Column("scan_error", sa.Text(), nullable=True))

    op.alter_column("clinical_documents", "file_signature_valid", server_default=None)
    op.alter_column("clinical_documents", "scan_status", server_default=None)


def downgrade() -> None:
    bind = op.get_bind()
    document_scan_status = sa.Enum(
        "skipped",
        "passed",
        "failed",
        name="document_scan_status",
    )

    op.drop_column("clinical_documents", "scan_error")
    op.drop_column("clinical_documents", "scan_provider")
    op.drop_column("clinical_documents", "scan_status")
    op.drop_column("clinical_documents", "file_signature_valid")
    op.drop_column("clinical_documents", "content_sha256")
    op.drop_column("ai_summaries", "model_name")
    op.drop_column("ai_summaries", "provider_name")
    op.drop_table("audit_logs")
    document_scan_status.drop(bind, checkfirst=True)
