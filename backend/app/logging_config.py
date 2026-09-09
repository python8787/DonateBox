"""
DonateBox - Structured Logging Configuration

JSON-formatted logs for production, human-readable for development.
"""

import json
import logging
import sys
from datetime import datetime, timezone


class JsonFormatter(logging.Formatter):
    """Structured JSON log formatter for production."""

    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        # Add module and function for traceability
        if record.funcName and record.funcName != "<module>":
            log_entry["function"] = f"{record.module}.{record.funcName}"

        # Add exception info if present
        if record.exc_info and record.exc_info[1] is not None:
            log_entry["exception"] = {
                "type": record.exc_info[0].__name__ if record.exc_info[0] else None,
                "message": str(record.exc_info[1]),
            }

        # Add any extra fields passed via `extra={}` on the log call
        for key in ("donation_id", "payment_id", "provider", "status", "amount",
                     "currency", "method", "path", "status_code", "ip"):
            if hasattr(record, key):
                log_entry[key] = getattr(record, key)

        return json.dumps(log_entry, default=str)


class DevFormatter(logging.Formatter):
    """Colored, human-readable formatter for development."""

    COLORS = {
        "DEBUG": "\033[36m",    # cyan
        "INFO": "\033[32m",     # green
        "WARNING": "\033[33m",  # yellow
        "ERROR": "\033[31m",    # red
        "CRITICAL": "\033[35m", # magenta
    }
    RESET = "\033[0m"

    def format(self, record: logging.LogRecord) -> str:
        color = self.COLORS.get(record.levelname, "")
        timestamp = datetime.now().strftime("%H:%M:%S")
        name = record.name.replace("app.", "")

        # Collect any structured extras
        extras = []
        for key in ("donation_id", "payment_id", "provider", "status",
                     "amount", "currency", "method", "path", "status_code"):
            if hasattr(record, key):
                extras.append(f"{key}={getattr(record, key)}")
        extra_str = f" [{', '.join(extras)}]" if extras else ""

        msg = f"{color}{timestamp} {record.levelname:8s}{self.RESET} {name}: {record.getMessage()}{extra_str}"

        if record.exc_info and record.exc_info[1] is not None:
            msg += f"\n  {record.exc_info[0].__name__}: {record.exc_info[1]}"

        return msg


def setup_logging(*, debug: bool = False, json_logs: bool = False) -> None:
    """Configure application logging.

    Args:
        debug: Enable DEBUG level (default INFO).
        json_logs: Use JSON formatter (production). Default: dev formatter.
    """
    level = logging.DEBUG if debug else logging.INFO

    # Choose formatter
    if json_logs:
        formatter = JsonFormatter()
    else:
        formatter = DevFormatter()

    # Configure root handler
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)

    root = logging.getLogger()
    root.setLevel(level)
    root.handlers.clear()
    root.addHandler(handler)

    # Quiet down noisy libraries
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
    logging.getLogger("aiosqlite").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
