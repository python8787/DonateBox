"""
DonateBox - Payment Service Router

Routes payments to the correct provider based on currency.
INR → Razorpay, USD → Stripe.
"""

import logging
from typing import Optional

from app.config import settings
from app.services.providers.base import PaymentService
from app.services.providers.razorpay_provider import RazorpayPaymentService
from app.services.providers.stripe_provider import StripePaymentService

logger = logging.getLogger(__name__)


class PaymentRouter:
    """
    Routes payment requests to the correct provider based on currency.
    Maintains singleton instances of each provider.
    """

    _razorpay: Optional[RazorpayPaymentService] = None
    _stripe: Optional[StripePaymentService] = None

    @classmethod
    def get_provider(cls, currency: str) -> PaymentService:
        """Get the payment provider for a given currency."""
        if currency == "INR":
            return cls._get_razorpay()
        elif currency == "USD":
            return cls._get_stripe()
        else:
            raise ValueError(f"No payment provider configured for currency: {currency}")

    @classmethod
    def _get_razorpay(cls) -> RazorpayPaymentService:
        if cls._razorpay is None:
            cls._razorpay = RazorpayPaymentService(
                key_id=settings.razorpay_key_id,
                key_secret=settings.razorpay_key_secret,
                webhook_secret=settings.razorpay_webhook_secret,
            )
            logger.info("Razorpay provider initialized")
        return cls._razorpay

    @classmethod
    def _get_stripe(cls) -> StripePaymentService:
        if cls._stripe is None:
            cls._stripe = StripePaymentService(
                secret_key=settings.stripe_secret_key,
                webhook_secret=settings.stripe_webhook_secret,
            )
            logger.info("Stripe provider initialized")
        return cls._stripe

    @classmethod
    def get_provider_name(cls, currency: str) -> str:
        """Get the provider name for a currency."""
        providers = {"INR": "razorpay", "USD": "stripe"}
        return providers.get(currency, "unknown")
