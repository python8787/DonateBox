"""
DonateBox - Webhook Endpoints

Receives payment event notifications from gateways.
Signature verification + idempotent processing.
Fully implemented in Phase 4.
"""

import logging

from fastapi import APIRouter, Request, HTTPException, status

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/payments", tags=["Webhooks"])


@router.post("/webhook/{provider}")
async def payment_webhook(
    provider: str,
    request: Request,
):
    """
    Receive webhook from payment provider.

    - Validates the provider's signature
    - Processes payment status updates idempotently
    - A duplicate webhook must NOT create duplicate records

    Fully implemented in Phase 4.
    """
    logger.info(f"Webhook received from provider: {provider}")

    if provider not in ("razorpay", "stripe"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unknown payment provider: {provider}",
        )

    # Stub — will be implemented in Phase 4
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Webhook handling coming in Phase 4",
    )
