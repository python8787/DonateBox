"""Initial tables: donations, payments, system_heartbeat

Revision ID: 001_initial
Revises:
Create Date: 2026-09-09
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = "001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ─── Donations ─────────────────────────────────────
    op.create_table(
        "donations",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("donor_name", sa.String(100), nullable=True),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="CREATED"),
        sa.Column("terms_version", sa.String(10), nullable=False),
        sa.Column("terms_accepted_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("payment_provider", sa.String(20), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint("currency IN ('INR', 'USD')", name="valid_currency"),
        sa.CheckConstraint(
            "status IN ('CREATED', 'PENDING', 'SUCCESS', 'FAILED', 'CANCELLED', 'EXPIRED')",
            name="valid_status",
        ),
        sa.CheckConstraint("amount > 0", name="positive_amount"),
    )
    op.create_index("idx_donations_status", "donations", ["status"])
    op.create_index("idx_donations_created_at", "donations", ["created_at"])

    # ─── Payments ──────────────────────────────────────
    op.create_table(
        "payments",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("donation_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("provider", sa.String(20), nullable=False),
        sa.Column("provider_order_id", sa.String(255), nullable=True),
        sa.Column("provider_payment_id", sa.String(255), nullable=True),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="CREATED"),
        sa.Column("payment_method", sa.String(50), nullable=True),
        sa.Column("raw_reference", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["donation_id"], ["donations.id"]),
        sa.UniqueConstraint("provider", "provider_order_id", name="unique_provider_order"),
    )
    op.create_index("idx_payments_donation_id", "payments", ["donation_id"])
    op.create_index("idx_payments_provider_order", "payments", ["provider_order_id"])

    # ─── System Heartbeat ──────────────────────────────
    op.create_table(
        "system_heartbeat",
        sa.Column("id", sa.Integer, autoincrement=True, nullable=False),
        sa.Column("heartbeat_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("source", sa.String(50), nullable=False, server_default="keepalive_cron"),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade() -> None:
    op.drop_table("system_heartbeat")
    op.drop_table("payments")
    op.drop_table("donations")
