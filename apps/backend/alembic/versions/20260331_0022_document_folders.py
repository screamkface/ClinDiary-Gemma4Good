"""add document folders and archive metadata

Revision ID: 20260331_0022_document_folders
Revises: 20260325_0021_managed_profiles
Create Date: 2026-03-31 10:30:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260331_0022_document_folders"
down_revision = "20260325_0021_managed_profiles"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "document_folders",
        sa.Column("patient_id", sa.UUID(), nullable=False),
        sa.Column("parent_folder_id", sa.UUID(), nullable=True),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["parent_folder_id"], ["document_folders.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["patient_id"], ["patient_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_document_folders_patient_id", "document_folders", ["patient_id"])
    op.create_index(
        "ix_document_folders_parent_folder_id",
        "document_folders",
        ["parent_folder_id"],
    )

    op.add_column("clinical_documents", sa.Column("folder_id", sa.UUID(), nullable=True))
    op.create_index("ix_clinical_documents_folder_id", "clinical_documents", ["folder_id"])
    op.create_foreign_key(
        "fk_clinical_documents_folder_id_document_folders",
        "clinical_documents",
        "document_folders",
        ["folder_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_clinical_documents_folder_id_document_folders",
        "clinical_documents",
        type_="foreignkey",
    )
    op.drop_index("ix_clinical_documents_folder_id", table_name="clinical_documents")
    op.drop_column("clinical_documents", "folder_id")

    op.drop_index("ix_document_folders_parent_folder_id", table_name="document_folders")
    op.drop_index("ix_document_folders_patient_id", table_name="document_folders")
    op.drop_table("document_folders")
