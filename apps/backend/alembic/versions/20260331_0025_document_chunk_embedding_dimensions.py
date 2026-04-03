"""add embedding dimensions to document chunks

Revision ID: 20260331_0025_document_chunk_embedding_dimensions
Revises: 20260331_0024_document_rag_search_indexes
Create Date: 2026-03-31 17:05:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260331_0025_document_chunk_embedding_dimensions"
down_revision = "20260331_0024_document_rag_search_indexes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "document_chunks",
        sa.Column("embedding_dimensions", sa.Integer(), nullable=True),
    )
    op.create_index(
        "ix_document_chunks_embedding_dimensions",
        "document_chunks",
        ["embedding_dimensions"],
    )


def downgrade() -> None:
    op.drop_index("ix_document_chunks_embedding_dimensions", table_name="document_chunks")
    op.drop_column("document_chunks", "embedding_dimensions")
