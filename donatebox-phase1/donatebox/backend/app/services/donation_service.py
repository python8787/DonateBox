"""
DonateBox - Donation Service

Business logic for creating and managing donations.
Amount validation happens here — never trust the client.
"""

import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.donation import Donation
from app.schemas.donation import CreateDonationRequest

logger = logging.getLogger(__name__)


class DonationService:
    """Handles donation business logic."""

    @staticmethod
    def validate_amount(amount: float, currency: str) -> tuple[bool, str]:
        """
        Validate donation amount against backend-configured limits.
        The client CANNOT determine the allowed amount range.
        """
        if currency == "INR":
            min_amt, max_amt = settings.inr_min_amount, settings.inr_max_amount
        elif currency == "USD":
            min_amt, max_amt = settings.usd_min_amount, settings.usd_max_amount
        else:
            return False, f"Unsupported currency: {currency}"

        if amount < min_amt:
            return False, f"Minimum donation is {min_amt} {currency}"
        if amount > max_amt:
            return False, f"Maximum donation is {max_amt} {currency}"

        return True, "Valid"

    @staticmethod
    async def create_donation(
        db: AsyncSession,
        request: CreateDonationRequest,
    ) -> Donation:
        """Create a new donation record."""

        # Validate amount on the backend (Rule #1: client can't decide amount)
        valid, message = DonationService.validate_amount(
            request.amount, request.currency
        )
        if not valid:
            raise ValueError(message)

        # Validate terms version matches current
        if request.terms_version != settings.terms_version:
            raise ValueError(
                f"Terms version mismatch. Current version: {settings.terms_version}"
            )

        donation = Donation(
            donor_name=request.name,
            amount=request.amount,
            currency=request.currency,
            status="CREATED",
            terms_version=request.terms_version,
            terms_accepted_at=datetime.now(timezone.utc),
        )

        db.add(donation)
        await db.flush()

        logger.info(
            f"Donation created: donation_id={donation.id}, "
            f"amount={donation.amount} {donation.currency}"
        )

        return donation

    @staticmethod
    async def get_donation(db: AsyncSession, donation_id: UUID) -> Optional[Donation]:
        """Get a donation by ID."""
        result = await db.execute(
            select(Donation).where(Donation.id == donation_id)
        )
        return result.scalar_one_or_none()

    @staticmethod
    async def update_status(
        db: AsyncSession,
        donation: Donation,
        new_status: str,
        payment_provider: Optional[str] = None,
    ) -> Donation:
        """Update donation status."""
        old_status = donation.status
        donation.status = new_status
        donation.updated_at = datetime.now(timezone.utc)

        if payment_provider:
            donation.payment_provider = payment_provider

        if new_status == "SUCCESS":
            donation.paid_at = datetime.now(timezone.utc)

        await db.flush()

        logger.info(
            f"Donation status updated: donation_id={donation.id}, "
            f"{old_status} -> {new_status}"
        )

        return donation

    @staticmethod
    async def get_statistics(db: AsyncSession) -> dict:
        """Get donation statistics for admin dashboard."""
        # Total counts by status
        result = await db.execute(
            select(
                Donation.status,
                func.count(Donation.id),
                func.sum(Donation.amount),
            ).group_by(Donation.status)
        )
        stats = {
            "total_donations": 0,
            "total_amount_inr": 0,
            "total_amount_usd": 0,
            "by_status": {},
        }
        for row in result.all():
            status, count, amount = row
            stats["by_status"][status] = {
                "count": count,
                "amount": float(amount) if amount else 0,
            }
            stats["total_donations"] += count

        # Totals by currency for successful donations
        currency_result = await db.execute(
            select(
                Donation.currency,
                func.sum(Donation.amount),
            )
            .where(Donation.status == "SUCCESS")
            .group_by(Donation.currency)
        )
        for row in currency_result.all():
            currency, amount = row
            if currency == "INR":
                stats["total_amount_inr"] = float(amount) if amount else 0
            elif currency == "USD":
                stats["total_amount_usd"] = float(amount) if amount else 0

        return stats
