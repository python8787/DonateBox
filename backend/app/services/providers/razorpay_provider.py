"""
DonateBox - Razorpay Payment Provider (INR)

Handles Indian Rupee payments via Razorpay.
Will be fully implemented in Phase 4.
"""

import logging
from typing import Any

from app.services.providers.base import (
    PaymentService, OrderResult, VerificationResult, WebhookResult
)

logger = logging.getLogger(__name__)


class RazorpayPaymentService(PaymentService):
    """Razorpay implementation for INR payments."""

    def __init__(self, key_id: str, key_secret: str, webhook_secret: str):
        self.key_id = key_id
        self.key_secret = key_secret
        self.webhook_secret = webhook_secret
        # Razorpay client will be initialized in Phase 4
        logger.info("RazorpayPaymentService initialized (stub)")

    async def create_order(
        self,
        amount: float,
        currency: str,
        metadata: dict[str, Any],
    ) -> OrderResult:
        """Create a Razorpay order. Implemented in Phase 4."""
        raise NotImplementedError("Razorpay integration coming in Phase 4")

    async def verify_payment(
        self,
        payment_data: dict[str, Any],
    ) -> VerificationResult:
        """Verify Razorpay payment signature. Implemented in Phase 4."""
        raise NotImplementedError("Razorpay integration coming in Phase 4")

    async def handle_webhook(
        self,
        headers: dict[str, str],
        body: bytes,
    ) -> WebhookResult:
        """Process Razorpay webhook. Implemented in Phase 4."""
        raise NotImplementedError("Razorpay integration coming in Phase 4")

    async def get_payment_status(
        self,
        order_id: str,
    ) -> str:
        """Check Razorpay order status. Implemented in Phase 4."""
        raise NotImplementedError("Razorpay integration coming in Phase 4")
