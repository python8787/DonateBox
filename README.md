# DonateBox

A simple, premium donation application built with Flutter + FastAPI.

> ⚠️ **This is a personal donation platform** — not affiliated with any charity or nonprofit. No tax benefits apply.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Android first, iOS ready) |
| Backend | Python + FastAPI |
| Database | PostgreSQL (free tier) |
| INR Payments | Razorpay |
| USD Payments | Stripe |
| Admin | FastAPI + Jinja2 (server-rendered) |
| Hosting | Render (free tier) |
| Container | Docker |

## Project Structure

```
donatebox/
├── backend/          # FastAPI backend + admin dashboard
├── mobile/           # Flutter mobile app
├── docs/             # Legal docs (privacy, terms, refund)
├── scripts/          # Utility scripts (DB keepalive)
├── docker-compose.yml
└── README.md
```

## Quick Start

### Backend (Local Development)

```bash
# Start PostgreSQL + Backend with Docker
docker-compose up -d

# Or run manually:
cd backend
pip install -r requirements.txt
cp .env.example .env  # Edit with your values
uvicorn app.main:app --reload
```

API docs: http://localhost:8000/docs

### Flutter App

```bash
cd mobile/donatebox
flutter pub get
flutter run
```

### API Endpoints

| Method | Endpoint | Description |
|--------|---------|-------------|
| GET | `/api/v1/health` | Health check |
| GET | `/api/v1/donations/config` | Get donation config |
| POST | `/api/v1/donations` | Create donation |
| POST | `/api/v1/donations/{id}/payment` | Create payment |
| POST | `/api/v1/payments/verify` | Verify payment |
| POST | `/api/v1/payments/webhook/{provider}` | Payment webhook |
| POST | `/api/v1/admin/auth/login` | Admin login |
| GET | `/api/v1/admin/donations` | List donations (auth) |
| GET | `/api/v1/admin/statistics` | Dashboard stats (auth) |

## Development Phases

- [x] Phase 1 — Architecture & Setup
- [ ] Phase 2 — Flutter UI (all screens)
- [ ] Phase 3 — Backend + Database
- [ ] Phase 4 — Payment Gateway Integration
- [ ] Phase 5 — Admin Dashboard
- [ ] Phase 6 — Security & Legal
- [ ] Phase 7 — Deployment
- [ ] Phase 8 — Production Testing

## Security

- Payment secrets are backend-only — never in Flutter code
- All payment verification happens server-side
- Webhook signatures are validated
- Admin endpoints require JWT authentication
- No card/UPI credentials are ever stored

## License

Private project. All rights reserved.
