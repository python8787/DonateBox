"""
DonateBox - Health Check & Keepalive Endpoints

Quick status check for monitoring and deployment verification.
Keepalive writes a heartbeat to prevent free-tier DB suspension.
"""

import logging
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import text, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session, get_db
from app.models.heartbeat import SystemHeartbeat

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


@router.post("/keepalive")
async def keepalive(db: AsyncSession = Depends(get_db)):
    """
    Database keepalive endpoint.

    Writes a heartbeat row to prevent free-tier databases (Neon, Supabase)
    from suspending due to inactivity. Call this daily via an external
    cron service (e.g., cron-job.org, GitHub Actions, UptimeRobot).

    Also cleans up heartbeat rows older than 7 days to avoid storage bloat.
    """
    try:
        # Write heartbeat
        heartbeat = SystemHeartbeat(
            heartbeat_at=datetime.now(timezone.utc),
            source="keepalive_api",
        )
        db.add(heartbeat)

        # Clean up old heartbeats (older than 7 days)
        cutoff = datetime.now(timezone.utc) - timedelta(days=7)
        await db.execute(
            delete(SystemHeartbeat).where(SystemHeartbeat.heartbeat_at < cutoff)
        )

        await db.flush()

        logger.info("Keepalive heartbeat recorded, old entries cleaned")
        return {
            "status": "ok",
            "heartbeat_at": heartbeat.heartbeat_at.isoformat(),
            "message": "Heartbeat recorded",
        }
    except Exception as e:
        logger.error(f"Keepalive failed: {e}")
        return {
            "status": "error",
            "message": "Keepalive failed — database may be unreachable",
        }
