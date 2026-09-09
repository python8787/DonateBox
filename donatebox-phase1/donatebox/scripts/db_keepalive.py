"""
DonateBox - Database Keepalive Script

Run daily via cron/scheduled task to prevent free-tier
database providers from suspending the database.

Usage:
    python scripts/db_keepalive.py

Requires DATABASE_URL environment variable.
"""

import os
import sys
from datetime import datetime, timezone, timedelta

# Simple synchronous version for cron jobs
try:
    import psycopg2
except ImportError:
    print("Installing psycopg2-binary...")
    os.system(f"{sys.executable} -m pip install psycopg2-binary -q")
    import psycopg2


def keepalive():
    """Write a heartbeat row and clean up old ones."""
    database_url = os.environ.get("DATABASE_URL", "")

    # Convert async URL to sync format
    db_url = database_url.replace("postgresql+asyncpg://", "postgresql://")

    if not db_url:
        print("ERROR: DATABASE_URL not set")
        sys.exit(1)

    try:
        conn = psycopg2.connect(db_url)
        cur = conn.cursor()

        # Ensure table exists
        cur.execute("""
            CREATE TABLE IF NOT EXISTS system_heartbeat (
                id SERIAL PRIMARY KEY,
                heartbeat_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                source VARCHAR(50) DEFAULT 'keepalive_cron'
            )
        """)

        # Write heartbeat
        cur.execute(
            "INSERT INTO system_heartbeat (heartbeat_at, source) VALUES (%s, %s)",
            (datetime.now(timezone.utc), "keepalive_cron"),
        )

        # Clean up rows older than 7 days
        cutoff = datetime.now(timezone.utc) - timedelta(days=7)
        cur.execute(
            "DELETE FROM system_heartbeat WHERE heartbeat_at < %s",
            (cutoff,),
        )

        conn.commit()
        print(f"Heartbeat written at {datetime.now(timezone.utc).isoformat()}")

        cur.close()
        conn.close()

    except Exception as e:
        print(f"ERROR: Keepalive failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    keepalive()
