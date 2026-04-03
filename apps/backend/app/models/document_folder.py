from __future__ import annotations

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class DocumentFolder(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "document_folders"

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    parent_folder_id: Mapped[str | None] = mapped_column(
        ForeignKey("document_folders.id", ondelete="CASCADE")
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)

    patient = relationship("PatientProfile", back_populates="document_folders")
    parent_folder = relationship(
        "DocumentFolder",
        remote_side="DocumentFolder.id",
        back_populates="child_folders",
    )
    child_folders = relationship(
        "DocumentFolder",
        back_populates="parent_folder",
        cascade="all, delete-orphan",
    )
    documents = relationship(
        "ClinicalDocument",
        back_populates="folder",
        cascade="save-update",
    )
