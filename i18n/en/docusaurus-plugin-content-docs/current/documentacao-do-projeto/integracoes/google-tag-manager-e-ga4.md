---
title: "Google Tag Manager and GA4"
description: "Reading GTM containers and GA4 properties through Google APIs, reusing the same audit pipeline as the JSON upload."
sidebar_position: 3
---

# Google Tag Manager and GA4

`backend/services/google_platform_service.py` queries GTM (API v2), GA4 Admin and GA4 Data with the user's access token, obtained from the connection described in [Google OAuth](./google-oauth.md). The routes are in `backend/routers/google_platforms.py` (see [Google platforms API](../api/google-platforms.md)); `_token` (`:46`) reads the cookie, validates owner and scopes and renews the access token (401 if the connection is invalid, 502 if renewal fails).

## HTTP client

`_request` (`google_platform_service.py:17`) uses `httpx` with a 30 s timeout and converts errors: statuses 400, 401, 403, 404 and 429 are kept; the rest becomes 502, with Google's error message when there is one. `_list` (`:34`) paginates with `pageSize=200` and `nextPageToken` until done.

## GTM

| Function | Line | Does |
|---|---|---|
| `list_gtm_accounts` | 48 | Accounts (`path`, `name`) |
| `list_gtm_containers` | 53 | Containers of an account (validates numeric `account_id`); returns `public_id`, `usage_context` |
| `list_gtm_versions` | 69 | `version_headers` sorted from newest to oldest version |
| `analyze_gtm_container_version` | 88 | Downloads the version and runs the audit |

`analyze_gtm_container_version` validates the path with `accounts/<n>/containers/<n>/versions/<n>`, fetches the version and calls `process_single_container({"containerVersion": version}, file_name="<publicId> v<version> (GTM API)")`. This is **the same pipeline as the JSON upload**: `process_single_container` (`backend/services/audit_service.py:5`) calls `analyze_gtm_json` (`backend/analyze_gtm_json.py:6`), which chooses the auditor and appends `source_json_file` to each item. If the result carries `error`, the API responds 422.

### Container type classification

`analyze_gtm_json` reads the container's `usageContext` (`analyze_gtm_json.py:21`):

| Context | Internal type | Auditor | `gtm_container_type` in the payload |
|---|---|---|---|
| contains `SERVER` | server | `backend/audits/audit_server_container.py` | `server` |
| contains `ANDROID_SDK_5` or `IOS_SDK_5` | mobile | `backend/audits/audit_mobile_container.py` | `unknown` |
| others (default `WEB`) | web | `backend/audits/audit_web_container.py` | `web` |

### UPD detection (web container)

`audit_web_container` (`audit_web_container.py:58`) treats every variable of type `awec` (User-Provided Data) as a UPD variable; the method comes from the `mode` parameter (`automatic`, `manual`, `partial`, `not_configured` or `unknown`). It then links tags (`awct`, `flc`, `fls`, `gaawc`, `gaawe`, `awud`, ignoring paused ones) to the variable in two ways: a `user_data` parameter in the tag's own `eventSettingsTable`/`configSettingsTable`, or via configuration/event variables (`gtes`, `gtcs`). The status of each tag (`upd_configuration_status`) is one of `correct`, `incomplete: missing email`, `incomplete: missing phone_number`, `incomplete: missing email and phone_number`, `incorrect` or `not_configured`; the check of `email` and `phone_number` is done on the keys declared inside the variable (`:47`). The same auditor extracts `G-...` and `AW-...` IDs from active tags (resolving Constant variables) and returns them as `platform_accounts`. The status values are part of the contract described in [UPD status contract](../referencia/contrato-status-upd.md).

Server and mobile containers use simpler heuristics: `event_data` variables (server) or SDK variables (mobile) count as UPD and the tag is `correct` if it references one of them.

### Persistence

`POST /api/gtm/analyze-live` writes the run (`source="live"`) and records the account and container in the project's `google_accounts`, only if `project_id` and `report_id` were sent (`backend/routers/google_platforms.py:89`). The result is merged into the payload with the `gtm_api` source (see [Payload v3](../geracao-do-documento/payload-v3.md)).

## GA4

- `list_ga4_properties` (`google_platform_service.py:102`): `accountSummaries` from the Admin API, flattened into properties with the account name.
- `analyze_ga4_property` (`:118`): validates `properties/<n>`, applies the same date rules (end = yesterday, start = 29 days before, maximum interval of 366 inclusive days, 422 if invalid) using the server's local date (UTC on Cloud Run), and queries the property, `dataStreams`, `keyEvents` and a Data API `runReport` with `eventName` x `eventCount`.
- Output: `platform_accounts` (one per data stream, with `measurement_id` from web streams; one item without a stream if there are none) and `conversion_actions` with one item per key event (`conversion_goal: key_event`, `conversion_origin: ga4_event`, count and `has_recent_activity` for the period).

## Notes

- The GA4 scope is read-only (`analytics.readonly`) and so is GTM's (`tagmanager.readonly`).
- Unlike Google Ads, there is no in-memory cache in these services.
- The auditors have tests in `backend/tests/test_audit_service.py` and `backend/tests/test_google_platform_service.py`. See [Tests](../desenvolvimento/testes.md).
