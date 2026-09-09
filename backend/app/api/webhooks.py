"""
DonateBox - Webhook Endpoints

Receives payment event notifications from Razorpay and Stripe.
Signature verification + idempotent processing.
"""

import json
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Request, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from fastapi import Depends
from app.models.payment import Payment
from app.models.donation import Donation
from app.services.payment_service import PaymentRouter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/payments", tags=["Webhooks"])


@router.post("/webhook/{provider}")
async def payment_webhook(
    provider: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Receive webhook from payment provider.

    - Validates the provider's signature
    - Processes payment status updates idempotently
    - A duplicate webhook does NOT create duplicate records
    """
    if provider not in ("razorpay", "stripe"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unknown payment provider: {provider}",
        )

    # Read raw body for signature verification
    body = await request.body()
    headers = dict(request.headers)

    # Get the provider's service and handle the webhook
    currency = "INR" if provider == "razorpay" else "USD"
    try:
        payment_service = PaymentRouter.get_provider(currency)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Payment provider not configured: {provider}",
        )

    result = await payment_service.handle_webhook(headers, body)

    if not result.valid:
        logger.warning(
            f"Invalid webhook from {provider}: {result.error}"
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result.error or "Invalid webhook",
        )

    # Only process payment status events we care about
    if not result.status or not result.order_id:
        logger.info(
            f"Webhook event {result.event_type} from {provider} — "
            f"no action needed"
        )
        return {"status": "ok", "message": "Event acknowledged"}

    # Find the payment by provider_order_id
    stmt = select(Payment).where(
        Payment.provider == provider,
        Payment.provider_order_id == result.order_id,
    )
    db_result = await db.execute(stmt)
    payment = db_result.scalar_one_or_none()

    if not payment:
        logger.warning(
            f"Webhook for unknown order: provider={provider}, "
            f"order_id={result.order_id}"
        )
        # Return 200 so the provider doesn't retry — order might
        # have been created by a different system or is stale
        return {"status": "ok", "message": "Order not found, acknowledged"}

    # Idempotent check: if payment is already in a terminal state,
    # don't update it again
    terminal_states = {"SUCCESS", "FAILED", "CANCELLED"}
    if payment.status in terminal_states:
        logger.info(
            f"Webhook for already-settled payment: payment_id={payment.id}, "
            f"current_status={payment.status}, webhook_status={result.status}"
        )
        return {"status": "ok", "message": "Already processed"}

    # Update payment record
    payment.status = result.status
    if result.payment_id:
        payment.provider_payment_id = result.payment_id
    payment.updated_at = datetime.now(timezone.utc)

    if result.status == "SUCCESS":
        payment.paid_at = datetime.now(timezone.utc)

    payment.raw_reference = json.dumps({
        "webhook_event": result.event_type,
        "webhook_status": result.status,
        "payment_id": result.payment_id,
    })

    # Update the parent donation
    donation_result = await db.execute(
        select(Donation).where(Donation.id == payment.donation_id)
    )
    donation = donation_result.scalar_one_or_none()

    if donation and donation.status not in terminal_states:
        donation.status = result.status
        donation.updated_at = datetime.now(timezone.utc)
        if result.status == "SUCCESS":
            donation.paid_at = datetime.now(timezone.utc)

    await db.flush()

    logger.info(
        f"Webhook processed: provider={provider}, order_id={result.order_id}, "
        f"payment_id={payment.id}, new_status={result.status}"
    )

    return {"status": "ok", "message": f"Payment updated to {result.status}"}
