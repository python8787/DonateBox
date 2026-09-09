"""
DonateBox - Application Configuration

Loads all settings from environment variables.
Never hard-code secrets here.
"""

from typing import List
from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # App
    app_env: str = Field(default="development")
    app_name: str = Field(default="DonateBox")
    app_version: str = Field(default="1.0.0")
    debug: bool = Field(default=False)

    # Database (SQLite default for easy local dev; use PostgreSQL in production)
    database_url: str = Field(default="sqlite+aiosqlite:///./donatebox.db")

    # Razorpay (INR)
    razorpay_key_id: str = Field(default="")
    razorpay_key_secret: str = Field(default="")
    razorpay_webhook_secret: str = Field(default="")

    # Stripe (USD)
    stripe_publishable_key: str = Field(default="")
    stripe_secret_key: str = Field(default="")
    stripe_webhook_secret: str = Field(default="")

    # Admin
    admin_username: str = Field(default="admin")
    admin_password_hash: str = Field(default="")
    jwt_secret: str = Field(default="change-me-in-production")
    jwt_algorithm: str = Field(default="HS256")
    jwt_expiry_hours: int = Field(default=24)

    # Donation config
    terms_version: str = Field(default="1.0")
    inr_min_amount: float = Field(default=1)
    inr_max_amount: float = Field(default=10000)
    inr_presets: str = Field(default="50,100,500,1000")
    usd_min_amount: float = Field(default=1)
    usd_max_amount: float = Field(default=500)
    usd_presets: str = Field(default="5,10,25,50")

    # Recipient
    recipient_name: str = Field(default="Vignesh")
    contact_email: str = Field(default="")

    # CORS
    cors_origins: str = Field(default="*")

    # Rate Limiting
    rate_limit: str = Field(default="100/minute")

    @property
    def inr_preset_list(self) -> List[int]:
        return [int(x.strip()) for x in self.inr_presets.split(",")]

    @property
    def usd_preset_list(self) -> List[int]:
        return [int(x.strip()) for x in self.usd_presets.split(",")]

    @property
    def cors_origin_list(self) -> List[str]:
        return [x.strip() for x in self.cors_origins.split(",")]

    @property
    def is_development(self) -> bool:
        return self.app_env == "development"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


# Singleton settings instance
settings = Settings()
