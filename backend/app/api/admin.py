"""
DonateBox - Admin API & Web Dashboard

Authentication, dashboard data, and server-rendered admin pages.
Admin can view/filter — cannot modify payment statuses.
"""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
from sqlalchemy import func, select, and_, case
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.donation import Donation
from app.models.payment import Payment
from app.security.auth import authenticate_admin, create_access_token, verify_token

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Admin"])

templates = Jinja2Templates(directory="templates")


# --- Pydantic models ---

class LoginRequest(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


# --- Helper: get admin from cookie ---

def get_admin_from_cookie(request: Request) -> Optional[str]:
    """Extract admin username from JWT cookie."""
    token = request.cookies.get("admin_token")
    if not token:
        return None
    try:
        return verify_token(token)
    except Exception:
        return None


# --- API endpoint (JSON) ---

@router.post("/api/v1/admin/auth/login", response_model=LoginResponse)
async def admin_login_api(request: LoginRequest):
    """API login — returns JWT token."""
    if not authenticate_admin(request.username, request.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )
    token = create_access_token(request.username)
    return LoginResponse(access_token=token)


# --- Web dashboard routes (HTML) ---

@router.get("/admin/login", response_class=HTMLResponse)
async def admin_login_page(request: Request):
    """Render login page."""
    admin = get_admin_from_cookie(request)
    if admin:
        return RedirectResponse(url="/admin", status_code=302)
    return templates.TemplateResponse(
        name="admin/login.html",
        context={"request": request, "error": None},
        request=request,
    )


@router.post("/admin/login", response_class=HTMLResponse)
async def admin_login_submit(request: Request):
    """Handle login form submission."""
    form = await request.form()
    username = form.get("username", "")
    password = form.get("password", "")

    if not authenticate_admin(username, password):
        return templates.TemplateResponse(
            name="admin/login.html",
            context={"request": request, "error": "Invalid username or password"},
            request=request,
        )

    token = create_access_token(username)
    response = RedirectResponse(url="/admin", status_code=302)
    response.set_cookie(
        key="admin_token",
        value=token,
        httponly=True,
        max_age=settings.jwt_expiry_hours * 3600,
        samesite="lax",
    )
    return response


@router.get("/admin/logout")
async def admin_logout():
    """Clear auth cookie and redirect to login."""
    response = RedirectResponse(url="/admin/login", status_code=302)
    response.delete_cookie("admin_token")
    return response


@router.get("/admin", response_class=HTMLResponse)
async def admin_dashboard(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Main dashboard page with stats."""
    admin = get_admin_from_cookie(request)
    if not admin:
        return RedirectResponse(url="/admin/login", status_code=302)

    stats = await _get_statistics(db)

    return templates.TemplateResponse(
        name="admin/dashboard.html",
        context={"request": request, "admin": admin, "stats": stats},
        request=request,
    )


@router.get("/admin/donations", response_class=HTMLResponse)
async def admin_donations_page(
    request: Request,
    db: AsyncSession = Depends(get_db),
    status_filter: Optional[str] = None,
    currency: Optional[str] = None,
    page: int = 1,
):
    """Donations list with filtering."""
    admin = get_admin_from_cookie(request)
    if not admin:
        return RedirectResponse(url="/admin/login", status_code=302)

    per_page = 20
    offset = (page - 1) * per_page

    query = select(Donation).order_by(Donation.created_at.desc())
    count_query = select(func.count(Donation.id))

    filters = []
    if status_filter:
        filters.append(Donation.status == status_filter)
    if currency:
        filters.append(Donation.currency == currency)

    if filters:
        query = query.where(and_(*filters))
        count_query = count_query.where(and_(*filters))

    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    total_pages = max(1, (total + per_page - 1) // per_page)

    query = query.offset(offset).limit(per_page)
    result = await db.execute(query)
    donations = result.scalars().all()

    return templates.TemplateResponse(
        name="admin/donations.html",
        context={
            "request": request,
            "admin": admin,
            "donations": donations,
            "status_filter": status_filter or "",
            "currency": currency or "",
            "page": page,
            "total_pages": total_pages,
            "total": total,
        },
        request=request,
    )


@router.get("/admin/donations/{donation_id}", response_class=HTMLResponse)
async def admin_donation_detail(
    request: Request,
    donation_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Single donation detail with payment history."""
    admin = get_admin_from_cookie(request)
    if not admin:
        return RedirectResponse(url="/admin/login", status_code=302)

    result = await db.execute(
        select(Donation).where(Donation.id == donation_id)
    )
    donation = result.scalar_one_or_none()

    if not donation:
        raise HTTPException(status_code=404, detail="Donation not found")

    payments_result = await db.execute(
        select(Payment)
        .where(Payment.donation_id == donation.id)
        .order_by(Payment.created_at.desc())
    )
    payments = payments_result.scalars().all()

    return templates.TemplateResponse(
        name="admin/donation_detail.html",
        context={"request": request, "admin": admin, "donation": donation, "payments": payments},
        request=request,
    )


# --- Statistics helper ---

async def _get_statistics(db: AsyncSession) -> dict:
    """Gather dashboard statistics."""
    stats_query = select(
        func.count(Donation.id).label("total_count"),
        func.coalesce(func.sum(Donation.amount), 0).label("total_amount"),
        func.sum(case((Donation.status == "SUCCESS", 1), else_=0)).label("success_count"),
        func.coalesce(
            func.sum(case((Donation.status == "SUCCESS", Donation.amount), else_=0)), 0
        ).label("success_amount"),
        func.sum(case((Donation.status == "PENDING", 1), else_=0)).label("pending_count"),
        func.sum(case((Donation.status == "FAILED", 1), else_=0)).label("failed_count"),
        func.sum(case((Donation.status == "CREATED", 1), else_=0)).label("created_count"),
    ).select_from(Donation)

    result = await db.execute(stats_query)
    row = result.one()

    # Per-currency breakdown (successful only)
    currency_query = select(
        Donation.currency,
        func.count(Donation.id).label("count"),
        func.coalesce(func.sum(Donation.amount), 0).label("amount"),
    ).where(Donation.status == "SUCCESS").group_by(Donation.currency)

    currency_result = await db.execute(currency_query)
    currency_rows = currency_result.all()
    by_currency = {r.currency: {"count": r.count, "amount": float(r.amount)} for r in currency_rows}

    # Recent donations (last 5)
    recent_query = select(Donation).order_by(Donation.created_at.desc()).limit(5)
    recent_result = await db.execute(recent_query)
    recent = recent_result.scalars().all()

    total_count = row.total_count or 0
    success_count = row.success_count or 0
    success_rate = round((success_count / total_count * 100), 1) if total_count > 0 else 0

    return {
        "total_count": total_count,
        "total_amount": float(row.total_amount),
        "success_count": success_count,
        "success_amount": float(row.success_amount),
        "pending_count": row.pending_count or 0,
        "failed_count": row.failed_count or 0,
        "created_count": row.created_count or 0,
        "success_rate": success_rate,
        "by_currency": by_currency,
        "recent": recent,
    }
