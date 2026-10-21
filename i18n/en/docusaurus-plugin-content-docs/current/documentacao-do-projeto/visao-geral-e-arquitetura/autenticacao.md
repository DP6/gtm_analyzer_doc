---
title: "Authentication and authorization"
description: "The four authentication methods in priority order, roles, OTP, public routes and per-project authorization."
sidebar_position: 3
---

# Authentication and authorization

`get_current_user` (`backend/deps.py`) delegates to `AuthService.authenticate_request` (`backend/services/auth_service.py:259`), which tries the methods below **in this order**; the first one that validates wins. With none valid, the API responds **401**.

| # | Method | How it is sent | Resulting role |
|---|---|---|---|
| 1 | Google Sign-In | `Authorization: Bearer <id_token>` | `admin` if `@dp6.com.br`, otherwise `user` |
| 2 | Email OTP session | `X-Email-Session: <token>` | `admin` if `@dp6.com.br`, otherwise `user` |
| 3 | Access token | `X-Access-Token` or `?token=` | `viewer` (fixed email `access-token@dp6.com.br`, `is_dp6=true`) |
| 4 | Dev mode | `X-Dev-User-Email` | `admin`; only with `ENVIRONMENT=development` |

Rules for each method:

1. **Google**: validates the JWT with the `GOOGLE_CLIENT_ID` audience, requires `email_verified` and an allowed domain (`auth_service.py:55`). `@dp6.com.br` is always allowed; others must be in `ALLOWED_DOMAINS` (`auth_service.py:29`).
2. **OTP**: see below.
3. **Access token**: compared with `MASTER_ACCESS_TOKEN` via `secrets.compare_digest` (`auth_service.py:216`).
4. **Dev**: requires the header; `DEV_USER_EMAIL` is not used as a fallback in practice, despite the docstring (`auth_service.py:237-257`).

The frontend sends whichever method is available from `localStorage` (`frontend/src/services/api.js:8-25`).

## Email OTP

- **4-digit** code, stored as SHA-256, valid for `EMAIL_OTP_TTL_SECONDS` (default 600 s).
- Rate limit: 3 requests per email in 10 min. Up to 3 wrong attempts per code.
- Success creates a 256-bit session (`secrets.token_hex(32)`) valid for `EMAIL_SESSION_TTL_HOURS` (default 24 h).
- Sent via SendGrid; without `SENDGRID_API_KEY` the code goes to the log. In `development` without SendGrid, the `/api/auth/otp/request` response includes `dev_code` (`backend/routers/auth.py:55-58`).
- In production (`ENVIRONMENT` = `prod`/`production`) OTP is **disabled**: `/otp/request` responds 400 and `/api/auth/config` returns `email_otp_enabled: false` (`routers/auth.py:21-28,42-47`).

## Public routes

`/api/auth/config`, `/api/auth/otp/request`, `/api/auth/otp/verify`, `/api/auth/logout`, the callback `GET /api/google-ads/oauth/callback`, `/health`, `/api/health` and the SPA files. `/api/auth/me` requires authentication. All other routers are protected (`backend/main.py:39-49`).

## Per-project authorization

Done in the routers with `has_access`/`is_owner` (`backend/services/firestore_service.py:65-70`), not by Firestore rules.

| Situation | Response |
|---|---|
| Project does not exist | 404 |
| User without access (neither owner nor member) | **404** (does not reveal that the project exists) (`routers/projects.py:63-68`) |
| Member attempting an owner-only action (edit, delete, manage members) | **403** "Apenas o dono do projeto pode fazer isso." (Only the project owner can do that.) (`routers/projects.py:71-75`) |

`save_run` also raises `PermissionError` if the user has no access.

## Caveats

- OTP, sessions and rate limit are kept **in memory** per instance: restarting or scaling drops the sessions (see [Architecture](./arquitetura.md)).
- `MASTER_ACCESS_TOKEN` has an **insecure default value** in `backend/config.py`; override it in production. The Cloud Run renderer requires the variable to be set (`backend/scripts/render_cloudrun_env.py`).
- The access token is accepted in the query string, which can leak into logs and history.

See also [Authentication API](../api/auth.md) and [Google OAuth](../integracoes/google-oauth.md).
