"""
DonateBox - Payment API Endpoints

Payment creation and verification.
Routes through PaymentRouter to the correct provider (Razorpay/Stripe).
"""

import json
import logging
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.payment import Payment
from app.schemas.payment import (
    PaymentInitResponse,
    VerifyPaymentRequest,
    PaymentVerifyResponse,
)
from app.services.donation_service import DonationService
from app.services.payment_service import PaymentRouter

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

    1. Looks up the donation
    2. Routes to the correct payment gateway (INR→Razorpay, USD→Stripe)
    3. Creates an order with the gateway
    4. Stores a Payment record
    5. Returns data Flutter needs to launch the payment UI
    """
    # Get donation
    donation = await DonationService.get_donation(db, donation_id)
    if not donation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Donation not found",
        )

    if donation.status not in ("CREATED", "FAILED"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot create payment for donation in '{donation.status}' status",
        )

    # Get the right payment provider
    provider_name = PaymentRouter.get_provider_name(donation.currency)
    provider = PaymentRouter.get_provider(donation.currency)

    # Create order with gateway
    try:
        order_result = await provider.create_order(
            amount=float(donation.amount),
            currency=donation.currency,
            metadata={
                "donation_id": str(donation.id),
                "donor_name": donation.donor_name or "Anonymous",
            },
        )
    except Exception as e:
        logger.error(f"Payment order creation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to create payment order with payment provider",
        )

    # Create payment record in DB
    payment = Payment(
        donation_id=donation.id,
        provider=provider_name,
        provider_order_id=order_result.order_id,
        amount=donation.amount,
        currency=donation.currency,
        status="PENDING",
    )
    db.add(payment)

    # Update donation status to PENDING
    await DonationService.update_status(
        db, donation, "PENDING", payment_provider=provider_name
    )

    await db.flush()

    logger.info(
        f"Payment created: payment_id={payment.id}, "
        f"order_id={order_result.order_id}, provider={provider_name}"
    )

    return PaymentInitResponse(
        provider=provider_name,
        order_id=order_result.order_id,
        payment_init_data=order_result.payment_init_data,
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

    1. Looks up the donation and its pending payment
    2. Verifies with the payment provider (signature check for Razorpay,
       status check for Stripe)
    3. Updates both payment and donation records
    """
    # Get donation
    donation = await DonationService.get_donation(db, request.donation_id)
    if not donation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Donation not found",
        )

    if not donation.payment_provider:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No payment initiated for this donation",
        )

    # Get the provider that was used
    provider = PaymentRouter.get_provider(donation.currency)

    # Verify with the gateway
    try:
        result = await provider.verify_payment(request.payment_data)
    except Exception as e:
        logger.error(f"Payment verification error: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to verify payment with provider",
        )

    # Find the payment record (most recent for this donation)
    from sqlalchemy import select
    stmt = (
        select(Payment)
        .where(Payment.donation_id == donation.id)
        .order_by(Payment.created_at.desc())
        .limit(1)
    )
    db_result = await db.execute(stmt)
    payment = db_result.scalar_one_or_none()

    if payment:
        payment.status = result.status
        payment.provider_payment_id = result.payment_id
        payment.payment_method = result.payment_method
        payment.updated_at = datetime.now(timezone.utc)
        if result.verified:
            payment.paid_at = datetime.now(timezone.utc)
        # Store sanitized reference (no secrets)
        payment.raw_reference = json.dumps({
            "verified": result.verified,
            "status": result.status,
            "payment_method": result.payment_method,
        })

    # Update donation status
    new_status = result.status  # SUCCESS, FAILED, PENDING, etc.
    await DonationService.update_status(db, donation, new_status)

    await db.flush()

    if result.verified:
        message = "Payment verified successfully. Thank you for your donation!"
    else:
        message = result.error or "Payment verification failed"

    logger.info(
        f"Payment verification complete: donation_id={donation.id}, "
        f"verified={result.verified}, status={result.status}"
    )

    return PaymentVerifyResponse(
        status=result.status,
        message=message,
        donation_id=donation.id,
    )
