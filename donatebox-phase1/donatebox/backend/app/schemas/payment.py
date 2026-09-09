"""
DonateBox - Payment Schemas

Pydantic models for payment request/response validation.
"""

from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class CreatePaymentRequest(BaseModel):
    """Request for POST /api/v1/donations/{donation_id}/payment"""
    # No body needed — donation_id comes from path
    pass


class PaymentInitResponse(BaseModel):
    """Response with payment gateway initialization data."""
    provider: str
    order_id: str
    payment_init_data: dict[str, Any]
    message: str = "Payment order created"


class VerifyPaymentRequest(BaseModel):
    """Request for POST /api/v1/payments/verify"""
    donation_id: UUID
    payment_data: dict[str, Any] = Field(
        description="Provider-specific payment result data"
    )


class PaymentVerifyResponse(BaseModel):
    """Response after payment verification."""
    status: str
    message: str
    donation_id: UUID


class PaymentStatusResponse(BaseModel):
    """Simple payment status check."""
    donation_id: UUID
    status: str
    payment_method: Optional[str] = None
