"""
DonateBox - Donation API Endpoints

Public endpoints for creating donations and getting config.
"""

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.schemas.donation import (
    CurrencyConfig,
    DonationConfigResponse,
    CreateDonationRequest,
    DonationResponse,
)
from app.services.donation_service import DonationService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/donations", tags=["Donations"])


@router.get("/config", response_model=DonationConfigResponse)
async def get_donation_config():
    """
    Get donation configuration.

    Returns allowed currencies, amount ranges, presets, and terms version.
    The Flutter app uses this to configure the UI — amounts are
    backend-controlled, never hardcoded in the client.
    """
    return DonationConfigResponse(
        currencies={
            "INR": CurrencyConfig(
                min_amount=settings.inr_min_amount,
                max_amount=settings.inr_max_amount,
                presets=settings.inr_preset_list,
            ),
            "USD": CurrencyConfig(
                min_amount=settings.usd_min_amount,
                max_amount=settings.usd_max_amount,
                presets=settings.usd_preset_list,
            ),
        },
        terms_version=settings.terms_version,
        recipient_name=settings.recipient_name,
    )


@router.post(
    "",
    response_model=DonationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_donation(
    request: CreateDonationRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Create a new donation.

    Validates amount against backend-configured limits.
    Terms must be accepted. Amount is verified server-side.
    """
    try:
        donation = await DonationService.create_donation(db, request)
        return DonationResponse(
            donation_id=donation.id,
            status=donation.status,
            amount=float(donation.amount),
            currency=donation.currency,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        logger.error(f"Error creating donation: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An error occurred while processing your donation.",
        )
