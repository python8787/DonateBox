"""
DonateBox - Health Check Endpoint

Quick status check for monitoring and deployment verification.
"""

import logging
from datetime import datetime, timezone

from fastapi import APIRouter
from sqlalchemy import text

from app.database import async_session

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Health"])


@router.get("/health")
async def health_check():
    """
    Health check endpoint.

    Returns app status and database connectivity.
    Used by Render/hosting providers to verify the service is running.
    """
    db_status = "disconnected"
    try:
        async with async_session() as session:
            await session.execute(text("SELECT 1"))
            db_status = "connected"
    except Exception as e:
        logger.warning(f"Database health check failed: {e}")
        db_status = "disconnected"

    return {
        "status": "ok",
        "db": db_status,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
