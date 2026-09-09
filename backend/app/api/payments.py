"""
DonateBox - Payment API Endpoints

Payment creation, verification, and webhook handling.
Fully implemented in Phase 4.
"""

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.payment import (
    PaymentInitResponse,
    VerifyPaymentRequest,
    PaymentVerifyResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Payments"])


@router.post(
    "/donations/{donation_id}/payment",
    response_model=PaymentInitResponse,
)
async def create_payment(
    donation_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    """
    Create a payment order for a donation.

    Routes to the correct payment gateway based on the donation's currency.
    Fully implemented in Phase 4.
    """
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Payment integration coming in Phase 4",
    )


@router.post(
    "/payments/verify",
    response_model=PaymentVerifyResponse,
)
async def verify_payment(
    request: VerifyPaymentRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Verify a payment after the user completes it.

    The backend verifies with the payment gateway — NEVER trust
    the Flutter client's claim of success.
    Fully implemented in Phase 4.
    """
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Payment verification coming in Phase 4",
    )
