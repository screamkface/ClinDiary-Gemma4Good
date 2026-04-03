"""documents phase 2

Revision ID: 20260320_0002
Revises: 20260320_0001
Create Date: 2026-03-20 14:00:00
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260320_0002"
down_revision = "20260320_0001"
branch_labels = None
depends_on = None


clinical_document_type = postgresql.ENUM(
    "lab_report",
    "imaging_report",
    "discharge_letter",
    "specialist_visit",
    "prescription",
    "medical_certificate",
    "generic_document",
    name="clinical_document_type",
    create_type=False,
)
document_parsed_status = postgresql.ENUM(
    "pending",
    "processing",
    "parsed",
    "ocr_pending",
    "review_required",
    "reviewed",
    "failed",
    name="document_parsed_status",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    clinical_document_type.create(bind, checkfirst=True)
    document_parsed_status.create(bind, checkfirst=True)

    op.execute("ALTER TYPE timeline_event_type ADD VALUE IF NOT EXISTS 'document_uploaded'")
    op.execute("ALTER TYPE timeline_event_type ADD VALUE IF NOT EXISTS 'lab_result_summary'")
    op.execute("ALTER TYPE timeline_event_type ADD VALUE IF NOT EXISTS 'imaging_summary'")

    op.create_table(
        "clinical_documents",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("document_type", clinical_document_type, nullable=False),
        sa.Column("upload_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("exam_date", sa.Date(), nullable=True),
        sa.Column("source", sa.String(length=255), nullable=True),
        sa.Column("file_url", sa.String(length=512), nullable=False),
        sa.Column("original_filename", sa.String(length=255), nullable=False),
        sa.Column("mime_type", sa.String(length=128), nullable=False),
        sa.Column("file_size_bytes", sa.Integer(), nullable=False),
        sa.Column("ocr_text", sa.Text(), nullable=True),
        sa.Column("parsed_status", document_parsed_status, nullable=False),
        sa.Column("classification_confidence", sa.Float(), nullable=True),
        sa.Column("parsing_confidence", sa.Float(), nullable=True),
        sa.Column("processing_error", sa.Text(), nullable=True),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "lab_panels",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("document_id", sa.Uuid(), nullable=False),
        sa.Column("panel_name", sa.String(length=255), nullable=False),
        sa.Column("panel_date", sa.Date(), nullable=True),
        sa.Column("confidence_score", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["document_id"], ["clinical_documents.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "lab_results",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("lab_panel_id", sa.Uuid(), nullable=False),
        sa.Column("analyte_name", sa.String(length=255), nullable=False),
        sa.Column("value", sa.String(length=255), nullable=False),
        sa.Column("unit", sa.String(length=64), nullable=True),
        sa.Column("ref_min", sa.Float(), nullable=True),
        sa.Column("ref_max", sa.Float(), nullable=True),
        sa.Column("abnormal_flag", sa.Boolean(), nullable=True),
        sa.Column("confidence_score", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["lab_panel_id"], ["lab_panels.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "imaging_reports",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("document_id", sa.Uuid(), nullable=False),
        sa.Column("exam_type", sa.String(length=255), nullable=True),
        sa.Column("body_part", sa.String(length=255), nullable=True),
        sa.Column("report_text", sa.Text(), nullable=False),
        sa.Column("impression", sa.Text(), nullable=True),
        sa.Column("confidence_score", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["document_id"], ["clinical_documents.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade() -> None:
    op.drop_table("imaging_reports")
    op.drop_table("lab_results")
    op.drop_table("lab_panels")
    op.drop_table("clinical_documents")

    bind = op.get_bind()
    document_parsed_status.drop(bind, checkfirst=True)
    clinical_document_type.drop(bind, checkfirst=True)
