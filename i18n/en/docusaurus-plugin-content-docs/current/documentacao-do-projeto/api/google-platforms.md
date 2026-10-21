---
title: "Google Platforms router"
description: "GTM and GA4 routes via the Google API, using the OAuth connection shared with Google Ads."
sidebar_position: 8
---

# Google Platforms router

Single router without a prefix (`router = APIRouter(tags=["Google Platforms"])`), with full paths on the routes. Authenticated. Router: `backend/routers/google_platforms.py`; service: `backend/services/google_platform_service.py`. See [GTM and GA4](../integracoes/google-tag-manager-e-ga4.md) and [Google OAuth](../integracoes/google-oauth.md).

## Routes

All require an authenticated user **and** the Google connection cookie (`gtm_google_ads_session`, the same as [Google Ads](./google-ads.md)).

| Method | Path | Input | Response | Errors |
|---|---|---|---|---|
| GET | `/api/gtm/accounts` (`:62`) | n/a | GTM accounts | 401, 502, Google |
| GET | `/api/gtm/accounts/{account_id}/containers` (`:70`) | path | containers | 422, 401, Google |
| GET | `/api/gtm/accounts/{account_id}/containers/{container_id}/versions` (`:79`) | path | versions | 422, 401, Google |
| POST | `/api/gtm/analyze-live` (`:89`) | `{"version_path","project_id?","report_id?"}` | GTM canonical payload | 422, 401, Google |
| GET | `/api/google-analytics/properties` (`:109`) | n/a | GA4 properties | 401, Google |
| POST | `/api/google-analytics/analyze-live` (`:117`) | `{"property","start_date?","end_date?","project_id?","report_id?"}` | GA4 analysis | 422, 401, Google |

`version_path` has the format `accounts/{a}/containers/{c}/versions/{v}`. `property` is `properties/{id}`.

## Implementation

- `_token` (`:44-51`): reads the connection from the cookie (`read_connection`) and exchanges the refresh token for an access token (`access_token`). A connection failure becomes 401; any other error, 502 `Não foi possível renovar a autorização do Google.` (Could not renew Google authorization.)
- `_run` (`:54-59`): runs the service and converts `ValueError` into `HTTPException`. `GooglePlatformApiError` (a subclass of `ValueError`) keeps Google's `status_code` (400, 401, 403, 404, 429; others become 502 in `google_platform_service.py:30`); a plain `ValueError` becomes 422.
- Calls to Google use synchronous `httpx` with a 30 s timeout and `nextPageToken` pagination with `pageSize=200` (`google_platform_service.py:17-45`).
- The listing routes are `def` (they run in FastAPI's threadpool); the `analyze-live` routes are `async` but call the blocking service directly (`_run`); only the Firestore write uses `run_in_threadpool`.
- Optional persistence: with `project_id` and `report_id`, `save_run_safe` writes a `live` run. If saved, `record_google_accounts` records `gtm_account_ids`/`gtm_container_ids` (extracted from `version_path`) or `ga4_property_ids` (`property` after the last `/`).

## Example

```bash
curl -b "<cookie_da_sessao>" -H "Authorization: Bearer <id_token>" \
  http://localhost:8000/api/gtm/accounts

curl -b "<cookie_da_sessao>" -X POST http://localhost:8000/api/gtm/analyze-live \
  -H "Authorization: Bearer <id_token>" -H "Content-Type: application/json" \
  -d '{"version_path":"accounts/111/containers/222/versions/3"}'

curl -b "<cookie_da_sessao>" -X POST http://localhost:8000/api/google-analytics/analyze-live \
  -H "Authorization: Bearer <id_token>" -H "Content-Type: application/json" \
  -d '{"property":"properties/123456","start_date":"2026-01-01","end_date":"2026-01-31"}'
```

## Caveats

- No cookie: 401 `Conta Google Ads não conectada.` (Google Ads account not connected.) (message inherited from the OAuth service). Old cookie without GTM/GA4 scopes: 401 asking for renewal.
- Unlike Google Ads, here `detail` is a string, not an object with `request_id`.
- The `analyze-live` routes block the event loop during the call to Google (up to 30 s per request). Something to watch if there is heavy concurrency.
- GA4 period: complete days, in order, up to 366 days (`google_platform_service.py:129`).
- If the GTM analysis returns `error`, it becomes 422 (`google_platform_service.py:98`).
