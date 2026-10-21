---
title: "Getting started"
description: "How to prepare the DS30 local environment, start the backend and frontend and authenticate in development."
sidebar_position: 1
---

# Getting started

DS30 has two local processes: the FastAPI backend (`:8000`) and the React/Vite frontend (`:5173`).

## Prerequisites

| Item | Use |
|---|---|
| Python 3 (the Docker image uses 3.11, `Dockerfile:19`) | backend |
| Node 20 + npm (`Dockerfile:4`) | frontend |
| `backend/.env` | local configuration (copied from `backend/.env.example`) |

## Manual setup

```bash
# backend
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env        # then fill in the values

# frontend
cd ../frontend
npm ci
```

`pytest` is not in `backend/requirements.txt`; install it separately to run the tests (see [Tests](./testes.md)).

## Start everything with `run_app.sh`

`./run_app.sh` (at the root) only does:

1. Picks the interpreter in `backend/`: `.venv/bin/python3` if `.venv` exists; otherwise `$HOME/anaconda3/bin/python3`; otherwise `python3` (`run_app.sh:13-19`).
2. Starts `uvicorn main:app --host 0.0.0.0 --port 8000` in the background.
3. Waits 2 s and starts `npm run dev -- --port 5173 --host`.
4. Ctrl+C stops both processes.

The script **does not create the venv, does not install dependencies and does not run `npm ci`**: do the manual setup first. It also does not use `--reload` (the app's `CLAUDE.md` shows the command with `--reload` for running the backend by hand).

## `backend/.env` variables

Names only (values never enter the repository; `.env` is ignored by git):

- Environment and auth: `ENVIRONMENT`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `ALLOWED_ORIGINS`, `ALLOWED_DOMAINS`, `MASTER_ACCESS_TOKEN`, `DEV_USER_EMAIL`, `DEV_USER_NAME`
- Email OTP: `EMAIL_OTP_ENABLED`, `EMAIL_OTP_TTL_SECONDS`, `EMAIL_SESSION_TTL_HOURS`, `SENDGRID_API_KEY`, `EMAIL_FROM_ADDRESS`, `EMAIL_FROM_NAME`
- Google Ads: `GOOGLE_ADS_DEVELOPER_TOKEN`, `GOOGLE_ADS_OAUTH_REDIRECT_URI`, `GOOGLE_ADS_OAUTH_REDIRECT_URI_DEV`, `GOOGLE_ADS_OAUTH_REDIRECT_URI_PROD`, `GOOGLE_ADS_SESSION_ENCRYPTION_KEY`
- Firestore (commented out in the example): `GOOGLE_APPLICATION_CREDENTIALS`, `FIRESTORE_EMULATOR_HOST`

`.env.example` does not list all the variables that `backend/config.py` reads (for example `DS30_APPS_SCRIPT_URL`, `DS30_APPS_SCRIPT_SECRET`, `GOOGLE_REFRESH_TOKEN`, `OBSERVEPOINT_API_KEY`, `GEMINI_API_KEY`). The full list is in [Environment variables](../referencia/variaveis-de-ambiente.md).

## Authentication in development

With `ENVIRONMENT=development`, the backend accepts the `X-Dev-User-Email` header as identity (`backend/services/auth_service.py:238-239`; with any other `ENVIRONMENT` value the bypass is refused). The frontend sends that header when `gtm_auth_dev_email` is in `localStorage`. Details and method priority: [Authentication](../visao-geral-e-arquitetura/autenticacao.md).

## Addresses

| What | URL |
|---|---|
| Frontend | http://localhost:5173 |
| API | http://localhost:8000 |
| OpenAPI (Swagger) | http://localhost:8000/docs |

In dev, Vite proxies `/api` to `localhost:8000` (`frontend/vite.config.js`). Route overview: [API overview](../api/visao-geral-da-api.md).
