---
title: "Google Ads"
description: "Google Ads account analysis via the API (GAQL), MCC account fan-out, account caching and the alternative CSV path."
sidebar_position: 2
---

# Google Ads

Two paths produce the same conversion action format and go through the same inclusion rule (`finalize_report_inclusion`, `backend/services/google_ads_service.py:7`):

| Path | Input | Code |
|---|---|---|
| Live | The user's OAuth connection ([Google OAuth](./google-oauth.md)) | `backend/services/google_ads_api_service.py` |
| CSV | Google Ads exports sent by upload | `backend/services/google_ads_service.py:212` (`analyze_google_ads_csvs`) |

Routes in `backend/routers/google_ads.py`: `GET /accounts`, `POST /analyze-live`, `POST /analyze` (CSV). See [Google Ads API](../api/google-ads.md).

## Client and queries

- `_client` (`google_ads_api_service.py:35`) builds the `GoogleAdsClient` with the developer token, the OAuth client and the refresh token from the cookie. `login_customer_id` is normalized to 10 digits (`normalize_customer_id`, `:28`).
- `_rows` (`:99`) runs GAQL with `search_stream` and translates `GoogleAdsException`: permission denied or disabled account becomes 403, quota becomes 429, authentication becomes 401, the rest 502. Google's `request_id` accompanies the error (`GoogleAdsApiError`, `:21`).
- Token renewal failure becomes 401 "Conexão Google Ads expirada ou revogada" (Google Ads connection expired or revoked) (`:47`).

## Accessible accounts and MCC hierarchy

`list_accessible_accounts` (`:126`):

1. Lists the customers accessible to the user (`CustomerService.list_accessible_customers`).
2. For each root, walks `customer_client` with `level <= 1` breadth-first, stacking newly found MCCs (each MCC visited once). The queries at each level run in parallel (up to 10 threads, `_ACCOUNTS_FETCH_MAX_WORKERS`).
3. Each account gets `login_customer_id` (the root through which it was reached; `None` for the root itself), `manager`, `level`, `status`, currency and time zone. Duplicate paths are discarded.
4. Failures per root or sub-account become `warnings`, without aborting.

**Cache.** The result is kept in memory for 300 s (`_ACCOUNTS_CACHE_TTL_SECONDS`, `:54`), keyed by the SHA-256 of the refresh token (`:60`). It is per instance: lost on restart and not shared between Cloud Run instances (the code already marks this as `ponytail`).

## `analyze_live_account`

`analyze_live_account` (`:441`) receives the account, an optional `login_customer_id` and the period.

**Date rules** (`:466` to `:473`):

- "Today" is computed in the account's own time zone (if the time zone is invalid, it uses the local date).
- Without dates: `end_date` = yesterday, `start_date` = `end_date - 29 days` (30 complete days).
- 422 error (`ValueError`) if start is greater than end, if `end_date` is today or in the future, or if the interval exceeds 365 days of difference (366 inclusive days).

**Sequential queries** for a non-MCC account: account data (`customer`, including `conversion_tracking_setting`; 404 if empty), `conversion_action`, metrics per period (`all_conversions` and value; absence of a row means zero volume), `campaign_conversion_goal` (enabled campaigns), `customer_conversion_goal`, `conversion_goal_campaign_config` (custom goals) and `offline_conversion_upload_client_summary`. Failure in the last one only produces the warning `offline_diagnostics_unavailable`.

**Classification.** `resolve_optimization` (`:308`) links each action to `campaign_goal`, `account_goal` and/or `custom_goal`; `_canonical_action` (`:263`) builds the canonical item; `_source_fields` (`:211`) defines the origin (`GOOGLE_ANALYTICS_4_*` actions become `ga4_event` before the `origin` check, because the API has no GA4 origin). `finalize_report_inclusion` marks `included_in_report` only if the action has volume, at least one goal source, `WEBSITE` origin and is primary or secondary with at least 25% of the primary web volume. `conversion_actions` is the included subset; `all_conversion_actions` keeps all of them.

**Findings** (`severity`, `code`, `message`): data terms not accepted, no optimization action, actions without volume. **Derived**: `ecl_enabled`, `oci_implemented` (there are offline uploads), `oci_integration_method` (client with the most events), `google_ads_gtag_upd_capability` and `google_ads_ec_eligible_actions_identified` (there are eligible actions). These fields feed the [payload](../geracao-do-documento/payload-v3.md).

## MCC (fan-out)

If the account is a manager, `_analyze_manager_account` (`:419`) lists the non-manager descendants (`_list_descendant_client_ids`, `:337`), analyzes each one with `analyze_live_account` using the MCC as `login_customer_id` (parallel, up to 10 threads) and aggregates in `_merge_live_account_results` (`:374`): `coverage: "aggregated_mcc"`, `child_account_ids`, findings prefixed with the account name, `account_tracking` null. Sub-accounts that fail become `warnings`; 404 if the MCC has no accessible clients and 502 if no sub-account could be queried.

## Persistence

With `project_id` and `report_id`, the route writes the run (`source="live"`), records the IDs used in the project's `google_accounts` and saves the report's analysis (`backend/routers/google_ads.py:136`), all in best-effort mode.

## CSV path

`analyze_google_ads_csvs` requires the actions CSV with the columns `Account`, `ID`, `Resource_Name`, `Name`, `Status`, `Type`, `Category`, `Origin`, `Primary`, `Conversions`. It optionally accepts the custom goals CSV (`Custom_Goal_Conversion_Actions`, `Custom_Goal_Status`, `Custom_Goal_Name` optional) and the standard goals CSV (`Biddable`, `Category`, `Origin`). Differences from live: the default goal source is `standard_goal` (there is no equivalent of `customer_conversion_goal`, so "Account-default goal" never appears), `warnings` and `findings` come empty, there is no offline upload diagnostic and the HTTP error is always 400 (`backend/routers/google_ads.py:190`).

## About `Docs/google_ads_backend_flow.md`

Checked against the code: period, goal sources, inclusion rule and account hierarchy match. Discrepancy: the document describes the CSV path as having "the same logic" for GA4 origin; confirmed in `_derive_origin_and_source`, but CSV coverage is smaller (no findings, no per-period metrics). Nothing in it about "implemented/pending" status was used as fact.

Related: [UPD status contract](../referencia/contrato-status-upd.md), [Data dictionary](../referencia/dicionario-de-dados.md).
