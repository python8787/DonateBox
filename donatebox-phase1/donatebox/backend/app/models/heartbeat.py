"""
DonateBox - System Heartbeat Model

Keeps the free-tier database alive by writing periodic heartbeats.
Prevents Neon/Supabase from suspending the DB due to inactivity.
"""

from datetime import datetime, timezone

from sqlalchemy import Column, Integer, String, DateTime

from app.database import Base


class SystemHeartbeat(Base):
    __tablename__ = "system_heartbeat"

    id = Column(Integer, primary_key=True, autoincrement=True)
    heartbeat_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    source = Column(String(50), nullable=False, default="keepalive_cron")

    def __repr__(self) -> str:
        return f"<SystemHeartbeat(id={self.id}, at={self.heartbeat_at})>"
