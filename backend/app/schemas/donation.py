"""
DonateBox - Donation Schemas

Pydantic models for request/response validation.
"""

import re
from datetime import datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class CurrencyConfig(BaseModel):
    """Configuration for a single currency."""
    min_amount: float = Field(ge=0)
    max_amount: float = Field(gt=0)
    presets: List[int]


class DonationConfigResponse(BaseModel):
    """Response for GET /api/v1/donations/config"""
    currencies: dict[str, CurrencyConfig]
    terms_version: str
    recipient_name: str


class CreateDonationRequest(BaseModel):
    """Request for POST /api/v1/donations"""
    name: Optional[str] = Field(
        default=None,
        max_length=100,
        description="Donor name (optional, for anonymous donations)"
    )
    amount: float = Field(
        gt=0,
        description="Donation amount"
    )
    currency: str = Field(
        pattern="^(INR|USD)$",
        description="Currency code: INR or USD"
    )
    terms_version: str = Field(
        min_length=1,
        description="Version of terms accepted"
    )
    terms_accepted: bool = Field(
        description="Must be true to proceed"
    )

    @field_validator("name")
    @classmethod
    def clean_name(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            v = v.strip()
            # Strip HTML tags to prevent XSS
            v = re.sub(r"<[^>]*>", "", v)
            v = v.strip()
            if len(v) == 0:
                return None
        return v

    @field_validator("terms_accepted")
    @classmethod
    def must_accept_terms(cls, v: bool) -> bool:
        if not v:
            raise ValueError("Terms must be accepted before proceeding")
        return v


class DonationResponse(BaseModel):
    """Response after creating a donation."""
    id: UUID
    status: str
    amount: float
    currency: str
    name: Optional[str] = None
    terms_version: str
    created_at: str
    message: str = "Donation created successfully"

    model_config = {"from_attributes": True}


class DonationDetailResponse(BaseModel):
    """Detailed donation response for admin."""
    id: UUID
    donor_name: Optional[str]
    amount: float
    currency: str
    status: str
    terms_version: str
    terms_accepted_at: datetime
    payment_provider: Optional[str]
    created_at: datetime
    updated_at: datetime
    paid_at: Optional[datetime]

    model_config = {"from_attributes": True}
