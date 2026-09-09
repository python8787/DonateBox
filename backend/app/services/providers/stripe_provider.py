"""
DonateBox - Stripe Payment Provider (USD)

Handles US Dollar payments via Stripe.
Will be fully implemented in Phase 4.
"""

import logging
from typing import Any

from app.services.providers.base import (
    PaymentService, OrderResult, VerificationResult, WebhookResult
)

logger = logging.getLogger(__name__)


class StripePaymentService(PaymentService):
    """Stripe implementation for USD payments."""

    def __init__(self, secret_key: str, webhook_secret: str):
        self.secret_key = secret_key
        self.webhook_secret = webhook_secret
        # Stripe client will be initialized in Phase 4
        logger.info("StripePaymentService initialized (stub)")

    async def create_order(
        self,
        amount: float,
        currency: str,
        metadata: dict[str, Any],
    ) -> OrderResult:
        """Create a Stripe PaymentIntent. Implemented in Phase 4."""
        raise NotImplementedError("Stripe integration coming in Phase 4")

    async def verify_payment(
        self,
        payment_data: dict[str, Any],
    ) -> VerificationResult:
        """Verify Stripe payment. Implemented in Phase 4."""
        raise NotImplementedError("Stripe integration coming in Phase 4")

    async def handle_webhook(
        self,
        headers: dict[str, str],
        body: bytes,
    ) -> WebhookResult:
        """Process Stripe webhook. Implemented in Phase 4."""
        raise NotImplementedError("Stripe integration coming in Phase 4")

    async def get_payment_status(
        self,
        order_id: str,
    ) -> str:
        """Check Stripe PaymentIntent status. Implemented in Phase 4."""
        raise NotImplementedError("Stripe integration coming in Phase 4")
