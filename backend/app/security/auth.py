"""
DonateBox - Admin Authentication

JWT-based authentication for the admin dashboard.
Passwords hashed with bcrypt. Secrets from environment only.
"""

import logging
from datetime import datetime, timedelta, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from passlib.hash import bcrypt

from app.config import settings

logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=False)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its bcrypt hash."""
    try:
        return bcrypt.verify(plain_password, hashed_password)
    except Exception:
        return False


def hash_password(password: str) -> str:
    """Hash a password with bcrypt."""
    return bcrypt.hash(password)


def create_access_token(username: str) -> str:
    """Create a JWT access token."""
    expire = datetime.now(timezone.utc) + timedelta(hours=settings.jwt_expiry_hours)
    payload = {
        "sub": username,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def verify_token(token: str) -> str:
    """Verify a JWT token and return the username."""
    try:
        payload = jwt.decode(
            token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token",
            )
        return username
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )


async def get_current_admin(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> str:
    """Dependency: verify admin authentication."""
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )
    return verify_token(credentials.credentials)


def authenticate_admin(username: str, password: str) -> bool:
    """Check admin credentials against environment config."""
    if username != settings.admin_username:
        logger.warning(f"Failed login attempt: unknown user '{username}'")
        return False

    if not settings.admin_password_hash:
        logger.error("Admin password hash not configured!")
        return False

    if not verify_password(password, settings.admin_password_hash):
        logger.warning(f"Failed login attempt: wrong password for '{username}'")
        return False

    logger.info(f"Admin login successful: {username}")
    return True
