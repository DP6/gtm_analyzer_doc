---
title: "Auth router"
description: "/api/auth routes: public configuration, current user, email OTP and logout."
sidebar_position: 2
---

# Auth router

Prefix `/api/auth`, registered **without** a router-level `Depends` (`backend/main.py:39`). Only `/me` requires authentication. Router: `backend/routers/auth.py`; service: `backend/services/auth_service.py` (`auth_service`). General model in [Authentication](../visao-geral-e-arquitetura/autenticacao.md).

## Routes

| Method | Path | Auth | Input | Response | Errors |
|---|---|---|---|---|---|
| GET | `/api/auth/config` | no | n/a | `google_client_id`, `email_otp_enabled`, `environment`, `allowed_domains` | n/a |
| GET | `/api/auth/me` | yes | n/a | `{"authenticated":true,"user":{...}}` | 401 |
| POST | `/api/auth/otp/request` | no | `{"email"}` | `{"ok":true,"message"}` (+ `dev_code` only in dev without SendGrid) | 400 |
| POST | `/api/auth/otp/verify` | no | `{"email","code"}` | `{"ok","message","session_token","user"}` | 400 |
| POST | `/api/auth/logout` | no | optional `X-Email-Session` header | `{"ok":true,"message"}` | n/a |

Lines: config `auth.py:20`, me `:31`, otp/request `:39`, otp/verify `:62`, logout `:84`.

## Implementation

- `config`: `email_otp_enabled` is forced to `false` when `ENVIRONMENT` is `prod`/`production` (`auth.py:22-24`).
- `otp/request`: in production or with `EMAIL_OTP_ENABLED` false it returns 400. Delegates to `auth_service.request_otp` (`auth_service.py:93`); sending uses SendGrid (`:132`, 5 s timeout). If `ENVIRONMENT == "development"` and there is no `SENDGRID_API_KEY`, the response includes `dev_code` (`auth.py:54-59`).
- `otp/verify`: blocked in production; `auth_service.verify_otp` (`:154`) returns the session token, and `verify_email_session` (`:189`) builds the `user`.
- `logout`: invalidates the in-memory session via `logout_session` (`:301`); without the header, it returns ok anyway.

## Example

```bash
curl -X POST http://localhost:8000/api/auth/otp/request \
  -H "Content-Type: application/json" -d '{"email":"voce@exemplo.com"}'
# {"ok": true, "message": "...", "dev_code": "123456"}

curl -X POST http://localhost:8000/api/auth/otp/verify \
  -H "Content-Type: application/json" -d '{"email":"voce@exemplo.com","code":"123456"}'
# {"ok": true, "session_token": "<token>", "user": {"email": "voce@exemplo.com", ...}}

curl -H "X-Email-Session: <token>" http://localhost:8000/api/auth/me
```

## Caveats

- OTP is for dev/staging only: in production both routes respond 400 even with correct credentials.
- `dev_code` only exists outside production without SendGrid; never rely on it in tests for environments with SendGrid.
- `RequestOtpBody.email` is `str` (not `EmailStr`, despite the import in `auth.py:2`); domain validation lives in the service.
- `logout` does not require auth and does not affect Google login (the Google token is not invalidated by the backend).
