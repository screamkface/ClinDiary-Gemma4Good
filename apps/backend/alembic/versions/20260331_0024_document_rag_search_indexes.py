"""add document rag search indexes

Revision ID: 20260331_0024_document_rag_search_indexes
Revises: 20260331_0023_document_rag_chunks
Create Date: 2026-03-31 16:10:00.000000
"""

from alembic import op


revision = "20260331_0024_document_rag_search_indexes"
down_revision = "20260331_0023_document_rag_chunks"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        return

    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_document_chunks_search_text
        ON document_chunks
        USING GIN (
          to_tsvector(
            'simple',
            coalesce(document_title, '') || ' ' ||
            coalesce(folder_name, '') || ' ' ||
            coalesce(source, '') || ' ' ||
            coalesce(chunk_label, '') || ' ' ||
            coalesce(content, '')
          )
        )
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_document_chunks_patient_context_updated
        ON document_chunks (patient_id, context_status, updated_at DESC)
        """
    )


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        return

    op.execute("DROP INDEX IF EXISTS ix_document_chunks_patient_context_updated")
    op.execute("DROP INDEX IF EXISTS ix_document_chunks_search_text")
