"""
DonateBox - Donation Model

Stores donation records with status tracking and terms versioning.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Column, String, Numeric, DateTime, CheckConstraint, Index
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class Donation(Base):
    __tablename__ = "donations"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    donor_name = Column(String(100), nullable=True)
    amount = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(3), nullable=False)  # 'INR' or 'USD'
    status = Column(String(20), nullable=False, default="CREATED")
    terms_version = Column(String(10), nullable=False)
    terms_accepted_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    payment_provider = Column(String(20), nullable=True)  # 'razorpay' or 'stripe'
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

    # Relationship to payments
    payments = relationship("Payment", back_populates="donation", lazy="selectin")

    # Constraints
    __table_args__ = (
        CheckConstraint("currency IN ('INR', 'USD')", name="valid_currency"),
        CheckConstraint(
            "status IN ('CREATED', 'PENDING', 'SUCCESS', 'FAILED', 'CANCELLED', 'EXPIRED')",
            name="valid_status",
        ),
        CheckConstraint("amount > 0", name="positive_amount"),
        Index("idx_donations_status", "status"),
        Index("idx_donations_created_at", "created_at"),
    )

    def __repr__(self) -> str:
        return (
            f"<Donation(id={self.id}, donor={self.donor_name}, "
            f"amount={self.amount} {self.currency}, status={self.status})>"
        )
