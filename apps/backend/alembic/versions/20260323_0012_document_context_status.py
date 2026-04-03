"""add document context status

Revision ID: 20260323_0012
Revises: 20260323_0011
Create Date: 2026-03-23 17:40:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260323_0012"
down_revision = "20260323_0011"
branch_labels = None
depends_on = None


document_context_status = postgresql.ENUM(
    "active",
    "old",
    name="document_context_status",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    document_context_status.create(bind, checkfirst=True)
    op.add_column(
        "clinical_documents",
        sa.Column(
            "context_status",
            document_context_status,
            nullable=False,
            server_default="active",
        ),
    )
    op.execute("UPDATE clinical_documents SET context_status = 'active' WHERE context_status IS NULL")
    op.alter_column("clinical_documents", "context_status", server_default=None)


def downgrade() -> None:
    op.drop_column("clinical_documents", "context_status")
    bind = op.get_bind()
    document_context_status.drop(bind, checkfirst=True)
