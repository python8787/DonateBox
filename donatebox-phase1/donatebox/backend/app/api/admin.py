"""
DonateBox - Admin API Endpoints

Authentication and dashboard data.
Admin can view/filter/export — cannot modify payment statuses.
"""

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.security.auth import authenticate_admin, create_access_token, get_current_admin

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["Admin"])


class LoginRequest(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


@router.post("/auth/login", response_model=LoginResponse)
async def admin_login(request: LoginRequest):
    """
    Admin login endpoint.

    Returns a JWT token on successful authentication.
    Rate-limited to prevent brute force (configured in main app).
    """
    if not authenticate_admin(request.username, request.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    token = create_access_token(request.username)
    return LoginResponse(access_token=token)


@router.get("/donations")
async def list_donations(
    admin: str = Depends(get_current_admin),
):
    """
    List all donations with filtering.
    Fully implemented in Phase 5.
    """
    return {"message": "Admin donations list coming in Phase 5", "admin": admin}


@router.get("/statistics")
async def get_statistics(
    admin: str = Depends(get_current_admin),
):
    """
    Get donation statistics.
    Fully implemented in Phase 5.
    """
    return {"message": "Statistics coming in Phase 5", "admin": admin}
