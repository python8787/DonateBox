"""
DonateBox - Payment Service Abstraction

All payment providers implement this interface.
The donation logic never depends on a specific gateway.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any, Optional


@dataclass
class OrderResult:
    """Result from creating a payment order."""
    order_id: str
    provider: str
    payment_init_data: dict[str, Any]  # Data the Flutter app needs to launch payment


@dataclass
class VerificationResult:
    """Result from verifying a payment."""
    verified: bool
    status: str  # 'SUCCESS', 'FAILED', etc.
    payment_id: Optional[str] = None
    payment_method: Optional[str] = None
    error: Optional[str] = None


@dataclass
class WebhookResult:
    """Result from processing a webhook."""
    valid: bool
    event_type: str
    order_id: Optional[str] = None
    payment_id: Optional[str] = None
    status: Optional[str] = None
    error: Optional[str] = None


class PaymentService(ABC):
    """
    Abstract base for payment providers.

    Implement this interface for each gateway (Razorpay, Stripe, etc.).
    The donation business logic only talks to this interface.
    """

    @abstractmethod
    async def create_order(
        self,
        amount: float,
        currency: str,
        metadata: dict[str, Any],
    ) -> OrderResult:
        """Create a payment order with the gateway."""
        ...

    @abstractmethod
    async def verify_payment(
        self,
        payment_data: dict[str, Any],
    ) -> VerificationResult:
        """Verify a payment after the user completes it."""
        ...

    @abstractmethod
    async def handle_webhook(
        self,
        headers: dict[str, str],
        body: bytes,
    ) -> WebhookResult:
        """Process and validate a webhook from the gateway."""
        ...

    @abstractmethod
    async def get_payment_status(
        self,
        order_id: str,
    ) -> str:
        """Check the current status of a payment order."""
        ...
