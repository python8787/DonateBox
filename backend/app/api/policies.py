"""
DonateBox - Legal / Policy Pages

Public, server-rendered pages: privacy policy, terms of service, refund policy.
Linked from the Flutter app and the donation flow.
"""

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from app.config import settings

router = APIRouter(tags=["Policies"])

templates = Jinja2Templates(directory="templates")


@router.get("/policy/privacy", response_class=HTMLResponse)
async def privacy_policy(request: Request):
    """Privacy policy page."""
    return templates.TemplateResponse(
        request, "policy/privacy.html",
        {"request": request, "recipient": settings.recipient_name, "contact_email": settings.contact_email},
    )


@router.get("/policy/terms", response_class=HTMLResponse)
async def terms_of_service(request: Request):
    """Terms of service page."""
    return templates.TemplateResponse(
        request, "policy/terms.html",
        {"request": request, "recipient": settings.recipient_name, "contact_email": settings.contact_email,
         "terms_version": settings.terms_version},
    )


@router.get("/policy/refund", response_class=HTMLResponse)
async def refund_policy(request: Request):
    """Refund / cancellation policy page."""
    return templates.TemplateResponse(
        request, "policy/refund.html",
        {"request": request, "recipient": settings.recipient_name, "contact_email": settings.contact_email},
    )
