"""
DonateBox - FastAPI Application Entry Point

Main application setup with CORS, rate limiting, and route registration.
"""

import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from app.config import settings
from app.database import create_tables
from app.logging_config import setup_logging
from app.api import health, donations, payments, webhooks, admin, policies

# Configure structured logging
setup_logging(
    debug=settings.debug,
    json_logs=not settings.is_development,  # JSON in production, colored in dev
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown events."""
    logger.info(f"Starting {settings.app_name} v{settings.app_version}")
    logger.info(f"Environment: {settings.app_env}")
    logger.info(f"Debug: {settings.debug}")

    # Auto-create tables (safe for both dev and production — idempotent)
    try:
        await create_tables()
        logger.info("Database tables created/verified")
    except Exception as e:
        logger.warning(f"Could not create tables (DB may be unavailable): {e}")

    yield
    logger.info(f"Shutting down {settings.app_name}")


# Rate limiter
limiter = Limiter(key_func=get_remote_address)

# Create FastAPI app
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="A simple, premium donation application",
    docs_url="/docs" if settings.is_development else None,
    redoc_url="/redoc" if settings.is_development else None,
    lifespan=lifespan,
)

# Rate limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)

# Static files for admin dashboard (only if directory exists)
static_dir = os.path.join(os.path.dirname(__file__), "..", "static")
if os.path.isdir(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")

# Register API routes
app.include_router(health.router, prefix="/api/v1")
app.include_router(donations.router, prefix="/api/v1")
app.include_router(payments.router, prefix="/api/v1")
app.include_router(webhooks.router, prefix="/api/v1")

# Admin dashboard — mounted at root (serves /admin/* HTML pages + /api/v1/admin/* JSON)
app.include_router(admin.router)

# Public policy pages — /policy/privacy, /policy/terms, /policy/refund
app.include_router(policies.router)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Catch unhandled exceptions — never expose stack traces in production."""
    logger.error(
        f"Unhandled exception: {exc}",
        extra={"method": request.method, "path": request.url.path, "status_code": 500},
        exc_info=exc,
    )
    if settings.is_development:
        detail = str(exc)
    else:
        detail = "An internal error occurred. Please try again later."
    return JSONResponse(
        status_code=500,
        content={"detail": detail},
    )


@app.get("/")
async def root():
    """Root endpoint — redirect to docs in dev, show basic info in prod."""
    return {
        "app": settings.app_name,
        "version": settings.app_version,
        "status": "running",
    }
