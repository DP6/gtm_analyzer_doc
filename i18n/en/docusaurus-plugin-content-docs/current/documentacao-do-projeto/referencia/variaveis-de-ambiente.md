---
title: "Environment variables"
description: "All backend configuration variables, grouped, with purpose and whether they are required."
sidebar_position: 3
---

# Environment variables

Defined in `backend/config.py` (class `Settings`, pydantic-settings), read from `backend/.env` or the environment; unknown variables are ignored. The template is in `backend/.env.example`. **Never record real values** in docs, commits or chats.

"Required" column: **Cloud Run** = required by `backend/scripts/render_cloudrun_env.py` (`REQUIRED_KEYS`) at deploy; **Feature** = only needed for the cited functionality; **No** = optional.

## Environment and CORS

| Variable | Purpose | Required |
|---|---|---|
| `ENVIRONMENT` | `development` enables dev mode; `prod`/`production` disables OTP and marks cookies `secure`. The deploy sets it (`Makefile`) | No (default `development`) |
| `ALLOWED_ORIGINS` | CORS origins, comma-separated | No |
| `PORT` | Uvicorn port in the Docker image (not part of `Settings`) | No (default 8080) |

## Google (login, Drive and Ads)

| Variable | Purpose | Required |
|---|---|---|
| `GOOGLE_CLIENT_ID` | Google Sign-In audience; OAuth client for Drive and Ads | Cloud Run |
| `GOOGLE_CLIENT_SECRET` | OAuth client secret | Cloud Run |
| `GOOGLE_REFRESH_TOKEN` | Account that publishes documents to Drive (`drive_service.py:16`) | Feature (Drive generation); not in `.env.example` |
| `GOOGLE_ADS_DEVELOPER_TOKEN` | Google Ads API developer token | Cloud Run |
| `GOOGLE_ADS_OAUTH_REDIRECT_URI` | Ads OAuth callback; at deploy it comes from `_DEV`/`_PROD` | Feature (Ads) |
| `GOOGLE_ADS_OAUTH_REDIRECT_URI_DEV`, `_PROD` | Only in `.env`; the renderer picks one and writes it as `GOOGLE_ADS_OAUTH_REDIRECT_URI` (HTTPS, path `/api/google-ads/oauth/callback`, no localhost) | Cloud Run (the environment's one) |
| `GOOGLE_ADS_SESSION_ENCRYPTION_KEY` | Long random secret that encrypts the Ads session | Cloud Run |

## Authentication

| Variable | Purpose | Required |
|---|---|---|
| `ALLOWED_DOMAINS` | Extra email domains (`@dp6.com.br` is always accepted); default `dp6.com.br` | Cloud Run |
| `EMAIL_OTP_ENABLED` | Enables OTP login (ignored in production) | Cloud Run |
| `EMAIL_OTP_TTL_SECONDS` | Code validity (default 600) | No |
| `EMAIL_SESSION_TTL_HOURS` | Session validity (default 24) | No |
| `SENDGRID_API_KEY` | OTP sending; empty = code in the log | Cloud Run |
| `EMAIL_FROM_ADDRESS`, `EMAIL_FROM_NAME` | OTP sender | No |
| `DEV_USER_EMAIL`, `DEV_USER_NAME` | Dev mode user; the name is used in the profile, and the email is only required by the renderer | Cloud Run (`DEV_USER_EMAIL`) |
| `MASTER_ACCESS_TOKEN` | Direct access token. **Insecure default**: override in production | Cloud Run |

See [Authentication](../visao-geral-e-arquitetura/autenticacao.md).

## Integrations

| Variable | Purpose | Required |
|---|---|---|
| `OBSERVEPOINT_API_KEY` | ObservePoint API key | Cloud Run |
| `OBSERVEPOINT_BASE_URL` | Base URL (default `https://api.observepoint.com`) | No |
| `GEMINI_API_KEY` | Considerations and transcript insights; the service copies the value into the process environment | Feature (AI); not in `.env.example` |
| `DS30_APPS_SCRIPT_URL` | `/exec` URL of the Apps Script Web App (validated by regex) | Feature (generate document) |
| `DS30_APPS_SCRIPT_SECRET` | Secret sent as `Bearer` to Apps Script | Feature (generate document) |

See [Apps Script](../integracoes/apps-script.md), [ObservePoint](../integracoes/observepoint.md) and [Gemini AI](../integracoes/ia-gemini.md).

## Firestore (outside `Settings`)

Commented out in `.env.example`, read by the Google libraries:

| Variable | Purpose |
|---|---|
| `GOOGLE_APPLICATION_CREDENTIALS` | Service account key in local development (on Cloud Run the instance's ADC applies) |
| `FIRESTORE_EMULATOR_HOST` | Points to the Firestore emulator |

See [Firebase](../integracoes/firebase.md).
