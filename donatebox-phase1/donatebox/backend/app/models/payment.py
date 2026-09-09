"""
DonateBox - Payment Model

Tracks payment attempts and gateway responses.
Separated from Donation for cleaner payment lifecycle tracking.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Column, String, Numeric, DateTime, Text, ForeignKey,
    UniqueConstraint, Index
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class Payment(Base):
    __tablename__ = "payments"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    donation_id = Column(
        UUID(as_uuid=True),
        ForeignKey("donations.id"),
        nullable=False,
    )
    provider = Column(String(20), nullable=False)  # 'razorpay' or 'stripe'
    provider_order_id = Column(String(255), nullable=True)
    provider_payment_id = Column(String(255), nullable=True)
    amount = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(3), nullable=False)
    status = Column(String(20), nullable=False, default="CREATED")
    payment_method = Column(String(50), nullable=True)  # 'upi', 'card', 'netbanking'
    raw_reference = Column(Text, nullable=True)  # sanitized gateway response
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    paid_at = Column(DateTime(timezone=True), nullable=True)

    # Relationship back to donation
    donation = relationship("Donation", back_populates="payments")

    __table_args__ = (
        UniqueConstraint("provider", "provider_order_id", name="unique_provider_order"),
        Index("idx_payments_donation_id", "donation_id"),
        Index("idx_payments_provider_order", "provider_order_id"),
    )

    def __repr__(self) -> str:
        return (
            f"<Payment(id={self.id}, donation_id={self.donation_id}, "
            f"provider={self.provider}, status={self.status})>"
        )
