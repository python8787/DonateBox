# DonateBox — Deployment Guide

Deploy the DonateBox backend to **Render** (free tier) with **Neon** PostgreSQL (free tier).

Total cost: **$0/month** — you only pay Razorpay/Stripe per-transaction fees.

---

## Step 1: Set Up Neon PostgreSQL

1. Go to [neon.tech](https://neon.tech) and sign up (free).
2. Create a new project named `donatebox`.
3. Copy the **connection string** — it looks like:
   ```
   postgresql://user:password@ep-xxx.region.aws.neon.tech/donatebox?sslmode=require
   ```
4. For async SQLAlchemy, change `postgresql://` to `postgresql+asyncpg://`:
   ```
   postgresql+asyncpg://user:password@ep-xxx.region.aws.neon.tech/donatebox?ssl=require
   ```
   > Note: asyncpg uses `ssl=require` not `sslmode=require`.

---

## Step 2: Deploy to Render

1. Go to [render.com](https://render.com) and sign up (free).
2. Click **New → Blueprint** and connect your GitHub repo (`python8787/DonateBox`).
3. Render will detect `render.yaml` and set up the service.
4. Set the **environment variables** that are marked `sync: false`:

   | Variable | Value |
   |----------|-------|
   | `DATABASE_URL` | Your Neon async connection string from Step 1 |
   | `RAZORPAY_KEY_ID` | Your Razorpay key (test or live) |
   | `RAZORPAY_KEY_SECRET` | Your Razorpay secret |
   | `RAZORPAY_WEBHOOK_SECRET` | Set after configuring webhook in Step 4 |
   | `ADMIN_USERNAME` | Your admin username |
   | `ADMIN_PASSWORD_HASH` | BCrypt hash (see below) |
   | `CONTACT_EMAIL` | Your contact email |

5. Click **Apply** — Render will build and deploy.

### Generate Admin Password Hash

Run this Python one-liner to generate a BCrypt hash:
```bash
python -c "from passlib.hash import bcrypt; print(bcrypt.hash('YOUR_PASSWORD_HERE'))"
```

---

## Step 3: Verify Deployment

Once deployed, visit:
- `https://your-app.onrender.com/` — should show `{"app":"DonateBox","version":"1.0.0","status":"running"}`
- `https://your-app.onrender.com/api/v1/health` — should show `{"status":"ok","db":"connected"}`
- `https://your-app.onrender.com/admin/login` — admin dashboard login

---

## Step 4: Configure Razorpay Webhook

1. Go to [Razorpay Dashboard → Webhooks](https://dashboard.razorpay.com/app/webhooks).
2. Add a new webhook:
   - **URL:** `https://your-app.onrender.com/api/v1/webhooks/razorpay`
   - **Events:** `payment.captured`, `payment.failed`
   - **Secret:** Generate a random string, save it.
3. Set `RAZORPAY_WEBHOOK_SECRET` in Render env vars to that secret.

---

## Step 5: Update Flutter App Config

Update `mobile/donatebox/lib/config/app_config.dart`:

```dart
static const String apiBaseUrl = 'https://your-app.onrender.com/api/v1';
static const String apiBaseUrlIos = 'https://your-app.onrender.com/api/v1';

// If using live Razorpay keys:
static const String razorpayKeyId = 'rzp_live_xxxxxxxxxxxx';

// Update policy URLs
static const String privacyPolicyUrl = 'https://your-app.onrender.com/policy/privacy';
static const String termsOfServiceUrl = 'https://your-app.onrender.com/policy/terms';
static const String refundPolicyUrl = 'https://your-app.onrender.com/policy/refund';
```

---

## Step 6: Database Keepalive (Prevent Neon Suspension)

Neon free tier suspends after 5 minutes of inactivity. Set up a daily keepalive:

### Option A: cron-job.org (Free)
1. Go to [cron-job.org](https://cron-job.org) and sign up.
2. Create a new cron job:
   - **URL:** `https://your-app.onrender.com/api/v1/keepalive`
   - **Method:** POST
   - **Schedule:** Every 4 hours (`0 */4 * * *`)

### Option B: UptimeRobot (Free)
1. Go to [uptimerobot.com](https://uptimerobot.com) and sign up.
2. Add a new monitor:
   - **URL:** `https://your-app.onrender.com/api/v1/health`
   - **Interval:** Every 5 minutes
   - This also keeps Render from sleeping the free-tier web service.

### Option C: GitHub Actions
Add `.github/workflows/keepalive.yml` to your repo:
```yaml
name: DB Keepalive
on:
  schedule:
    - cron: '0 */4 * * *'  # Every 4 hours
jobs:
  keepalive:
    runs-on: ubuntu-latest
    steps:
      - run: curl -X POST https://your-app.onrender.com/api/v1/keepalive
```

---

## Step 7: Go Live with Razorpay

When ready for real payments:

1. Complete KYC on [Razorpay Dashboard](https://dashboard.razorpay.com).
2. Switch from test to live keys:
   - Update `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` in Render env vars.
   - Update `razorpayKeyId` in Flutter's `app_config.dart`.
3. Rebuild and release the Flutter app.

---

## Render Free Tier Notes

- **Cold starts:** The free tier spins down after 15 minutes of inactivity. First request takes ~30 seconds to wake up.
- **Webhooks:** Razorpay retries webhooks 3-5 times over 24 hours, so cold-start delays are fine.
- **750 hours/month:** Free tier gives 750 hours — enough for one always-on service.
- **Upgrade:** If cold starts bother users, upgrade to the Starter plan ($7/month) for always-on.

---

## Architecture (Production)

```
Flutter App
    │
    ▼ HTTPS
Render (FastAPI)  ←── Razorpay Webhooks
    │
    ▼ SSL
Neon PostgreSQL
```

All traffic is encrypted. Payment credentials never touch the app — Razorpay's SDK handles them directly.
