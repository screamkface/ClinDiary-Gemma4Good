"""add document rag chunk index

Revision ID: 20260331_0023_document_rag_chunks
Revises: 20260331_0022_document_folders
Create Date: 2026-03-31 12:00:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from app.models.vector_type import VectorListType


revision = "20260331_0023_document_rag_chunks"
down_revision = "20260331_0022_document_folders"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute("CREATE EXTENSION IF NOT EXISTS vector")
        document_type_enum = postgresql.ENUM(
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
        context_status_enum = postgresql.ENUM(
            "active",
            "old",
            name="document_context_status",
            create_type=False,
        )
    else:
        document_type_enum = sa.Enum(
            "lab_report",
            "imaging_report",
            "discharge_letter",
            "specialist_visit",
            "prescription",
            "medical_certificate",
            "generic_document",
            name="clinical_document_type",
        )
        context_status_enum = sa.Enum(
            "active",
            "old",
            name="document_context_status",
        )

    op.create_table(
        "document_chunks",
        sa.Column("patient_id", sa.UUID(), nullable=False),
        sa.Column("document_id", sa.UUID(), nullable=False),
        sa.Column("folder_id", sa.UUID(), nullable=True),
        sa.Column("document_title", sa.String(length=255), nullable=False),
        sa.Column("folder_name", sa.String(length=255), nullable=True),
        sa.Column("document_type", document_type_enum, nullable=False),
        sa.Column("context_status", context_status_enum, nullable=False),
        sa.Column("source", sa.String(length=255), nullable=True),
        sa.Column("upload_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("exam_date", sa.Date(), nullable=True),
        sa.Column("chunk_index", sa.Integer(), nullable=False),
        sa.Column("chunk_kind", sa.String(length=64), nullable=False),
        sa.Column("chunk_label", sa.String(length=255), nullable=True),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("embedding_model_name", sa.String(length=128), nullable=True),
        sa.Column("embedding", VectorListType(), nullable=True),
        sa.Column("embedded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["document_id"], ["clinical_documents.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["folder_id"], ["document_folders.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_document_chunks_patient_id", "document_chunks", ["patient_id"])
    op.create_index("ix_document_chunks_document_id", "document_chunks", ["document_id"])
    op.create_index("ix_document_chunks_folder_id", "document_chunks", ["folder_id"])


def downgrade() -> None:
    op.drop_index("ix_document_chunks_folder_id", table_name="document_chunks")
    op.drop_index("ix_document_chunks_document_id", table_name="document_chunks")
    op.drop_index("ix_document_chunks_patient_id", table_name="document_chunks")
    op.drop_table("document_chunks")
