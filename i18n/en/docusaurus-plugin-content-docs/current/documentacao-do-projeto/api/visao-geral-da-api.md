---
title: "API overview"
description: "How the DS30 FastAPI backend assembles routers, authenticates, handles errors and exposes the HTTP API."
sidebar_position: 1
---

# API overview

The backend is a FastAPI app (`backend/main.py`). Each functional area has a router in `backend/routers/*.py`; the heavy logic lives in `backend/services/*.py`.

## App assembly

| Item | Where | Behavior |
|---|---|---|
| Router registration | `backend/main.py:39-49` | `auth` and the Google Ads OAuth callback are public; the other 7 routers get `dependencies=[Depends(get_current_user)]` |
| CORS | `backend/main.py:30-36` | `allow_origins=settings.ALLOWED_ORIGINS`, `allow_credentials=True`, methods and headers `*` |
| Health | `backend/main.py:51-54` | `GET /health` and `GET /api/health` return `{"status":"ok","service":"gtm-analyzer-backend"}` (no auth) |
| SPA fallback | `backend/main.py:57-69` | If `backend/static/` exists, mounts `/assets` and serves any other path as a static file or `index.html` |
| Root without build | `backend/main.py:71-77` | Without `static/`, `GET /` returns `{"ok":true,...}` |

Authentication (`get_current_user`, `backend/deps.py:5`) is applied at router registration, not route by route. Routes that need the user also declare `Depends(get_current_user)` to receive the `user` dict (the dependency is resolved once per request).

:::warning
Since the SPA fallback is `GET /{full_path:path}`, a `GET` on a nonexistent route under `/api` in production returns `index.html` (200), not 404.
:::

## Authentication

`get_current_user` reads `Authorization: Bearer`, `X-Email-Session`, `X-Access-Token` (or `?token=`) and `X-Dev-User-Email`, in that priority order (`backend/services/auth_service.py:259-299`). Without a valid user: `401` with `WWW-Authenticate: Bearer`. Details in [Authentication](../visao-geral-e-arquitetura/autenticacao.md).

## Conventions

- **Thin routers**: they validate input (Pydantic), call a service and translate errors.
- **Service errors**: services raise `ValueError` or domain errors (`GoogleAdsApiError`, `GooglePlatformApiError`, `GoogleAdsConnectionError`) and the router converts them into `HTTPException`. Some services raise `HTTPException` directly (`apps_script_service.py`, `drive_service.py`).
- **Messages in Portuguese** in the `detail` field. In Google Ads errors, `detail` is an object `{"message", "request_id"}`.
- **Blocking SDKs** (Firestore, Google Ads) run in `run_in_threadpool` inside `async` routes; plain `def` routes already run in FastAPI's threadpool.
- **`*_safe` persistence**: `save_run_safe`, `record_google_accounts` and `save_google_ads_analysis_safe` (`backend/services/firestore_service.py:116-165`) swallow exceptions and only log. A failure to write history never brings down the analysis; the response returns normally.
- **404 vs 403**: without access to a project, the API responds `404 Projeto não encontrado.` (Project not found.) so as not to reveal that it exists. `403` only appears when the user has access but is not the owner (`backend/routers/projects.py:63-75`).

## Status map

| Status | Typical use |
|---|---|
| 200 | Success |
| 202 | `POST /api/crawler/crawl` (run queued) |
| 400 | Invalid file, OTP disabled/invalid, invalid Google Ads CSV, ObservePoint without key |
| 401 | Not authenticated; Google connection missing/expired |
| 403 | Not the project owner; ObservePoint denied |
| 404 | Project/report/run does not exist or no access |
| 409 | ObservePoint quota reached |
| 422 | Pydantic validation or service `ValueError` |
| 502 | Failure in an external API (Google, Drive, Apps Script, ObservePoint, Gemini) |
| 503 | Integration not configured (Gemini, Google OAuth, Apps Script) |
| 504 | Apps Script timed out |

## Timeouts

All fixed in code; there is no environment variable to adjust them.

| Call | Timeout | File |
|---|---|---|
| Google APIs (GTM, GA4) | 30 s | `backend/services/google_platform_service.py:20` |
| Google Drive (list/export) | 30 s | `backend/services/drive_service.py:72,94` |
| ObservePoint | 10 to 30 s, depending on the call | `backend/services/observepoint_service.py:118-443` |
| Apps Script | 360 s total, 10 s connect | `backend/services/apps_script_service.py:60` |
| SendGrid (OTP) | 5 s | `backend/services/auth_service.py:150` |
| Google OAuth revocation | 10 s | `backend/services/google_ads_oauth_service.py:212` |
| Gemini | no explicit timeout | `backend/services/considerations_service.py` |

See also [Timeout and errors](../geracao-do-documento/timeout-e-erros.md).

## Calling locally

1. Start the backend on port 8000 (`python main.py` runs `uvicorn` with reload, `backend/main.py:79-81`).
2. Vite proxies `/api` to `http://localhost:8000` (`frontend/vite.config.js:9-14`); the frontend calls relative paths.
3. Interactive OpenAPI at `http://localhost:8000/docs`.
4. In development, dev mode accepts `X-Dev-User-Email` (see authentication).

```bash
curl http://localhost:8000/api/health
curl -H "X-Dev-User-Email: dev@exemplo.com" http://localhost:8000/api/auth/me
```

More in [Getting started](../desenvolvimento/primeiros-passos.md).

## Pages

[Auth](./auth.md), [Audit](./audit.md), [Projects](./projects.md), [Report](./report.md), [Crawler](./crawler.md), [Google Ads](./google-ads.md), [Google Platforms](./google-platforms.md), [Transcripts](./transcripts.md).
