"""add profile region code

Revision ID: 20260325_0016
Revises: 20260325_0015
Create Date: 2026-03-25 15:40:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260325_0016"
down_revision = "20260325_0015"
branch_labels = None
depends_on = None


italian_region_code = postgresql.ENUM(
    "IT",
    "IT-ABR",
    "IT-BAS",
    "IT-CAL",
    "IT-CAM",
    "IT-EMR",
    "IT-FVG",
    "IT-LAZ",
    "IT-LIG",
    "IT-LOM",
    "IT-MAR",
    "IT-MOL",
    "IT-PIE",
    "IT-PUG",
    "IT-SAR",
    "IT-SIC",
    "IT-TOS",
    "IT-TAA",
    "IT-UMB",
    "IT-VDA",
    "IT-VEN",
    name="italian_region_code",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    italian_region_code.create(bind, checkfirst=True)
    op.add_column("patient_profiles", sa.Column("region_code", italian_region_code, nullable=True))


def downgrade() -> None:
    op.drop_column("patient_profiles", "region_code")
    bind = op.get_bind()
    italian_region_code.drop(bind, checkfirst=True)
