"""
DonateBox - Health endpoint tests.
"""

import pytest
from httpx import AsyncClient, ASGITransport

from app.main import app


@pytest.mark.asyncio
async def test_root():
    """Test root endpoint returns app info."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["app"] == "DonateBox"
    assert data["status"] == "running"


@pytest.mark.asyncio
async def test_health():
    """Test health endpoint returns ok status."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "timestamp" in data


@pytest.mark.asyncio
async def test_donation_config():
    """Test donation config endpoint returns currencies and terms."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/api/v1/donations/config")
    assert response.status_code == 200
    data = response.json()
    assert "INR" in data["currencies"]
    assert "USD" in data["currencies"]
    assert data["currencies"]["INR"]["min_amount"] == 1
    assert data["currencies"]["USD"]["min_amount"] == 1
    assert data["terms_version"] == "1.0"
    assert data["recipient_name"] == "Vignesh"
