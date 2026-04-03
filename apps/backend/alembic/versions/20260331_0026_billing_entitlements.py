"""add billing plans, features and subscriptions

Revision ID: 20260331_0026_billing_entitlements
Revises: 20260331_0025_document_chunk_embedding_dimensions
Create Date: 2026-03-31 22:00:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260331_0026_billing_entitlements"
down_revision = "20260331_0025_document_chunk_embedding_dimensions"
branch_labels = None
depends_on = None


billing_interval = postgresql.ENUM(
    "free",
    "monthly",
    "yearly",
    name="billing_interval",
    create_type=False,
)
subscription_status = postgresql.ENUM(
    "active",
    "canceled",
    "expired",
    "trialing",
    name="subscription_status",
    create_type=False,
)
subscription_provider = postgresql.ENUM(
    "manual",
    "app_store",
    "google_play",
    "web",
    name="subscription_provider",
    create_type=False,
)


def upgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'billing_interval') THEN
                CREATE TYPE billing_interval AS ENUM ('free', 'monthly', 'yearly');
            END IF;
        END
        $$;
        """
    )
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status') THEN
                CREATE TYPE subscription_status AS ENUM ('active', 'canceled', 'expired', 'trialing');
            END IF;
        END
        $$;
        """
    )
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_provider') THEN
                CREATE TYPE subscription_provider AS ENUM ('manual', 'app_store', 'google_play', 'web');
            END IF;
        END
        $$;
        """
    )

    op.create_table(
        "billing_features",
        sa.Column("code", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("is_ai_feature", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("code"),
    )
    op.create_table(
        "billing_plans",
        sa.Column("code", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("billing_interval", billing_interval, nullable=False),
        sa.Column("price_cents", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("currency", sa.String(length=8), nullable=False, server_default="EUR"),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("highlight_label", sa.String(length=255), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_public", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_recommended", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_billing_plans_code", "billing_plans", ["code"], unique=True)
    op.create_table(
        "billing_plan_features",
        sa.Column("plan_id", sa.Uuid(), nullable=False),
        sa.Column("feature_code", sa.String(length=64), nullable=False),
        sa.ForeignKeyConstraint(["feature_code"], ["billing_features.code"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["plan_id"], ["billing_plans.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("plan_id", "feature_code"),
    )
    op.create_table(
        "user_subscriptions",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("plan_id", sa.Uuid(), nullable=False),
        sa.Column("provider", subscription_provider, nullable=False),
        sa.Column("status", subscription_status, nullable=False),
        sa.Column("provider_reference", sa.String(length=255), nullable=True),
        sa.Column("auto_renew", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("current_period_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("current_period_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column("canceled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("trial_ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["plan_id"], ["billing_plans.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_user_subscriptions_plan_id", "user_subscriptions", ["plan_id"])
    op.create_index("ix_user_subscriptions_status", "user_subscriptions", ["status"])
    op.create_index("ix_user_subscriptions_user_id", "user_subscriptions", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_user_subscriptions_user_id", table_name="user_subscriptions")
    op.drop_index("ix_user_subscriptions_status", table_name="user_subscriptions")
    op.drop_index("ix_user_subscriptions_plan_id", table_name="user_subscriptions")
    op.drop_table("user_subscriptions")
    op.drop_table("billing_plan_features")
    op.drop_index("ix_billing_plans_code", table_name="billing_plans")
    op.drop_table("billing_plans")
    op.drop_table("billing_features")

    op.execute("DROP TYPE IF EXISTS subscription_provider")
    op.execute("DROP TYPE IF EXISTS subscription_status")
    op.execute("DROP TYPE IF EXISTS billing_interval")
