"""
DonateBox - Razorpay Payment Provider (INR)

Handles Indian Rupee payments via Razorpay.
Flow: create_order → Flutter opens Razorpay checkout → verify_payment (signature check)
"""

import hashlib
import hmac
import json
import logging
from typing import Any

import razorpay

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
        self.client = razorpay.Client(auth=(key_id, key_secret))
        logger.info("RazorpayPaymentService initialized")

    async def create_order(
        self,
        amount: float,
        currency: str,
        metadata: dict[str, Any],
    ) -> OrderResult:
        """
        Create a Razorpay order.

        Razorpay expects amount in paise (INR * 100).
        Returns data the Flutter app needs to launch the Razorpay checkout.
        """
        amount_paise = int(round(amount * 100))

        order_data = {
            "amount": amount_paise,
            "currency": currency,
            "notes": {
                "donation_id": str(metadata.get("donation_id", "")),
                "donor_name": metadata.get("donor_name", "Anonymous"),
            },
        }

        try:
            order = self.client.order.create(data=order_data)
        except Exception as e:
            logger.error(f"Razorpay order creation failed: {e}")
            raise RuntimeError(f"Failed to create Razorpay order: {e}")

        logger.info(
            f"Razorpay order created: order_id={order['id']}, "
            f"amount={amount} {currency}"
        )

        return OrderResult(
            order_id=order["id"],
            provider="razorpay",
            payment_init_data={
                "key": self.key_id,
                "order_id": order["id"],
                "amount": amount_paise,
                "currency": currency,
                "name": "DonateBox",
                "description": f"Donation of ₹{amount:.0f}",
                "prefill": {
                    "name": metadata.get("donor_name", ""),
                },
            },
        )

    async def verify_payment(
        self,
        payment_data: dict[str, Any],
    ) -> VerificationResult:
        """
        Verify Razorpay payment using signature verification.

        After user completes payment, Flutter sends:
        - razorpay_order_id
        - razorpay_payment_id
        - razorpay_signature

        We verify the signature = HMAC-SHA256(order_id|payment_id, key_secret)
        """
        order_id = payment_data.get("razorpay_order_id", "")
        payment_id = payment_data.get("razorpay_payment_id", "")
        signature = payment_data.get("razorpay_signature", "")

        if not all([order_id, payment_id, signature]):
            return VerificationResult(
                verified=False,
                status="FAILED",
                error="Missing required payment data (order_id, payment_id, signature)",
            )

        # Verify signature: HMAC-SHA256 of "order_id|payment_id" with key_secret
        message = f"{order_id}|{payment_id}"
        expected_signature = hmac.new(
            self.key_secret.encode("utf-8"),
            message.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()

        if not hmac.compare_digest(expected_signature, signature):
            logger.warning(
                f"Razorpay signature mismatch for order {order_id}"
            )
            return VerificationResult(
                verified=False,
                status="FAILED",
                error="Payment signature verification failed",
            )

        # Fetch payment details from Razorpay to get method info
        payment_method = None
        try:
            payment_info = self.client.payment.fetch(payment_id)
            payment_method = payment_info.get("method", "unknown")
        except Exception as e:
            logger.warning(f"Could not fetch payment details: {e}")

        logger.info(
            f"Razorpay payment verified: order_id={order_id}, "
            f"payment_id={payment_id}, method={payment_method}"
        )

        return VerificationResult(
            verified=True,
            status="SUCCESS",
            payment_id=payment_id,
            payment_method=payment_method,
        )

    async def handle_webhook(
        self,
        headers: dict[str, str],
        body: bytes,
    ) -> WebhookResult:
        """
        Process and validate a Razorpay webhook.

        Razorpay sends a X-Razorpay-Signature header.
        Signature = HMAC-SHA256(body, webhook_secret)
        """
        signature = headers.get("x-razorpay-signature", "")

        if not signature:
            return WebhookResult(
                valid=False,
                event_type="unknown",
                error="Missing X-Razorpay-Signature header",
            )

        # Verify webhook signature
        expected = hmac.new(
            self.webhook_secret.encode("utf-8"),
            body,
            hashlib.sha256,
        ).hexdigest()

        if not hmac.compare_digest(expected, signature):
            logger.warning("Razorpay webhook signature verification failed")
            return WebhookResult(
                valid=False,
                event_type="unknown",
                error="Webhook signature verification failed",
            )

        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            return WebhookResult(
                valid=False,
                event_type="unknown",
                error="Invalid JSON body",
            )

        event_type = payload.get("event", "unknown")
        payment_entity = (
            payload.get("payload", {})
            .get("payment", {})
            .get("entity", {})
        )

        order_id = payment_entity.get("order_id")
        payment_id = payment_entity.get("id")

        # Map Razorpay events to our status
        status_map = {
            "payment.captured": "SUCCESS",
            "payment.failed": "FAILED",
            "payment.authorized": "PENDING",
        }
        status = status_map.get(event_type)

        logger.info(
            f"Razorpay webhook: event={event_type}, order_id={order_id}, "
            f"payment_id={payment_id}, status={status}"
        )

        return WebhookResult(
            valid=True,
            event_type=event_type,
            order_id=order_id,
            payment_id=payment_id,
            status=status,
        )

    async def get_payment_status(
        self,
        order_id: str,
    ) -> str:
        """Check the current status of a Razorpay order."""
        try:
            order = self.client.order.fetch(order_id)
            razorpay_status = order.get("status", "created")
            status_map = {
                "created": "CREATED",
                "attempted": "PENDING",
                "paid": "SUCCESS",
            }
            return status_map.get(razorpay_status, "PENDING")
        except Exception as e:
            logger.error(f"Failed to fetch Razorpay order status: {e}")
            return "UNKNOWN"
