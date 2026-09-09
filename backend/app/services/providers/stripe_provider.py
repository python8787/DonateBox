"""
DonateBox - Stripe Payment Provider (USD)

Handles US Dollar payments via Stripe PaymentIntents.
Flow: create PaymentIntent → Flutter uses client_secret with Stripe SDK → verify via webhook/API
"""

import json
import logging
from typing import Any

import stripe

from app.services.providers.base import (
    PaymentService, OrderResult, VerificationResult, WebhookResult
)

logger = logging.getLogger(__name__)


class StripePaymentService(PaymentService):
    """Stripe implementation for USD payments."""

    def __init__(self, secret_key: str, webhook_secret: str):
        self.secret_key = secret_key
        self.webhook_secret = webhook_secret
        stripe.api_key = secret_key
        logger.info("StripePaymentService initialized")

    async def create_order(
        self,
        amount: float,
        currency: str,
        metadata: dict[str, Any],
    ) -> OrderResult:
        """
        Create a Stripe PaymentIntent.

        Stripe expects amount in cents (USD * 100).
        Returns client_secret for Flutter to complete the payment.
        """
        amount_cents = int(round(amount * 100))

        try:
            intent = stripe.PaymentIntent.create(
                amount=amount_cents,
                currency=currency.lower(),
                metadata={
                    "donation_id": str(metadata.get("donation_id", "")),
                    "donor_name": metadata.get("donor_name", "Anonymous"),
                },
                description=f"DonateBox donation of ${amount:.2f}",
                automatic_payment_methods={"enabled": True},
            )
        except stripe.error.StripeError as e:
            logger.error(f"Stripe PaymentIntent creation failed: {e}")
            raise RuntimeError(f"Failed to create Stripe payment: {e.user_message}")

        logger.info(
            f"Stripe PaymentIntent created: id={intent.id}, "
            f"amount={amount} {currency}"
        )

        return OrderResult(
            order_id=intent.id,
            provider="stripe",
            payment_init_data={
                "client_secret": intent.client_secret,
                "payment_intent_id": intent.id,
                "amount": amount_cents,
                "currency": currency.lower(),
                "publishable_key": self._get_publishable_key(),
            },
        )

    def _get_publishable_key(self) -> str:
        """
        Derive publishable key from settings.
        """
        from app.config import settings
        return settings.stripe_publishable_key

    async def verify_payment(
        self,
        payment_data: dict[str, Any],
    ) -> VerificationResult:
        """
        Verify a Stripe payment by checking the PaymentIntent status.

        After Flutter completes payment, it sends:
        - payment_intent_id
        We fetch the intent from Stripe to confirm its status.
        """
        payment_intent_id = payment_data.get("payment_intent_id", "")

        if not payment_intent_id:
            return VerificationResult(
                verified=False,
                status="FAILED",
                error="Missing payment_intent_id",
            )

        try:
            intent = stripe.PaymentIntent.retrieve(payment_intent_id)
        except stripe.error.StripeError as e:
            logger.error(f"Failed to retrieve PaymentIntent: {e}")
            return VerificationResult(
                verified=False,
                status="FAILED",
                error=f"Could not verify payment: {e.user_message}",
            )

        # Map Stripe status to our status
        status_map = {
            "succeeded": "SUCCESS",
            "requires_payment_method": "FAILED",
            "requires_action": "PENDING",
            "processing": "PENDING",
            "canceled": "CANCELLED",
            "requires_confirmation": "PENDING",
            "requires_capture": "PENDING",
        }

        our_status = status_map.get(intent.status, "PENDING")
        verified = intent.status == "succeeded"

        # Get payment method details
        payment_method = None
        if intent.payment_method:
            try:
                pm = stripe.PaymentMethod.retrieve(intent.payment_method)
                payment_method = pm.type
            except Exception:
                pass

        logger.info(
            f"Stripe payment verification: intent={payment_intent_id}, "
            f"stripe_status={intent.status}, our_status={our_status}"
        )

        return VerificationResult(
            verified=verified,
            status=our_status,
            payment_id=payment_intent_id,
            payment_method=payment_method,
            error=None if verified else f"Payment status: {intent.status}",
        )

    async def handle_webhook(
        self,
        headers: dict[str, str],
        body: bytes,
    ) -> WebhookResult:
        """
        Process and validate a Stripe webhook.

        Stripe sends a Stripe-Signature header. We verify using
        stripe.Webhook.construct_event() which checks the signature.
        """
        sig_header = headers.get("stripe-signature", "")

        if not sig_header:
            return WebhookResult(
                valid=False,
                event_type="unknown",
                error="Missing Stripe-Signature header",
            )

        try:
            event = stripe.Webhook.construct_event(
                body, sig_header, self.webhook_secret
            )
        except stripe.error.SignatureVerificationError:
            logger.warning("Stripe webhook signature verification failed")
            return WebhookResult(
                valid=False,
                event_type="unknown",
                error="Webhook signature verification failed",
            )
        except ValueError:
            return WebhookResult(
                valid=False,
                event_type="unknown",
                error="Invalid webhook payload",
            )

        event_type = event["type"]
        payment_intent = event["data"]["object"]

        # Map Stripe events to our status
        status_map = {
            "payment_intent.succeeded": "SUCCESS",
            "payment_intent.payment_failed": "FAILED",
            "payment_intent.canceled": "CANCELLED",
            "payment_intent.processing": "PENDING",
        }

        order_id = payment_intent.get("id")
        status = status_map.get(event_type)

        logger.info(
            f"Stripe webhook: event={event_type}, intent_id={order_id}, "
            f"status={status}"
        )

        return WebhookResult(
            valid=True,
            event_type=event_type,
            order_id=order_id,
            payment_id=order_id,
            status=status,
        )

    async def get_payment_status(
        self,
        order_id: str,
    ) -> str:
        """Check the current status of a Stripe PaymentIntent."""
        try:
            intent = stripe.PaymentIntent.retrieve(order_id)
            status_map = {
                "succeeded": "SUCCESS",
                "requires_payment_method": "CREATED",
                "requires_action": "PENDING",
                "processing": "PENDING",
                "canceled": "CANCELLED",
            }
            return status_map.get(intent.status, "PENDING")
        except Exception as e:
            logger.error(f"Failed to fetch Stripe PaymentIntent status: {e}")
            return "UNKNOWN"
