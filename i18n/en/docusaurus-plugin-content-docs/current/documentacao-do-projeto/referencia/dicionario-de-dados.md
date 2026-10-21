---
title: "Data dictionary"
description: "Firestore collections and fields used by DS30."
sidebar_position: 1
---

# Data dictionary

Source: `backend/services/firestore_service.py` and `backend/routers/projects.py`. Firestore database `gtm-analyzer`, accessed only by the backend (Admin SDK).

:::note
`Docs/schema.sql` is an old PostgreSQL proposal and is **not used** by the app. Do not treat it as the real model.
:::

Dates are UTC `datetime`.

## `users/{email}`

Profile mirror, written by `ensure_user` on project creation (`firestore_service.py:73`).

| Field | Type | Description |
|---|---|---|
| `email` | string | Also the document id |
| `name`, `picture` | string | From the login method |
| `role` | string | `admin`, `user` or `viewer` |
| `auth_method` | string | `google`, `email_otp`, `access_token` or `dev_mode` |
| `last_login_at` | date | Updated on every upsert |
| `created_at` | date | Only on the first write |

## `projects/{id}`

Top-level collection, to allow sharing.

| Field | Type | Description |
|---|---|---|
| `client_name` | string | Required |
| `project_name` | string | Optional; old projects get `client_name` on read |
| `description` | string | Optional |
| `project_metadata` | map | Free-form |
| `logo_base64` | string | Up to 5 MB |
| `owner_email` | string | Owner (whoever created it) |
| `member_emails` | list of string | Members (ArrayUnion/ArrayRemove) |
| `google_accounts` | map of lists | Keys: `ads_customer_ids`, `ga4_property_ids`, `gtm_account_ids`, `gtm_container_ids`, `login_customer_ids`; fed by `record_google_accounts` |
| `created_at`, `updated_at` | date | |
| `last_report_at` | date or null | Updated on every saved `run` |

## `projects/{id}/reports/{id}`

| Field | Type | Description |
|---|---|---|
| `report_type` | string | Only `gtm_analyzer` is accepted |
| `title` | string | Default `Relatório dd/mm/aaaa` (Report dd/mm/yyyy) |
| `status` | string | `draft`; becomes `generated` after the document is generated |
| `payload` | map | Canonical payload being edited |
| `document_id`, `document_url` | string or null | Generated Google Docs document |
| `google_ads_analysis` | map | Latest Google Ads analysis result (overwritten on every run) |
| `created_by` | string | Email |
| `created_at`, `updated_at` | date | |

## `projects/{id}/reports/{rid}/runs/{id}`

Immutable history, created by `save_run`.

| Field | Type | Description |
|---|---|---|
| `source` | string | Origin (e.g. `report`; also upload, live analysis and crawler) |
| `payload` | map | Payload snapshot |
| `triggered_by` | string | Email |
| `created_at` | date | |
| `document_id`, `document_url` | string | Only when `source="report"` |

## Integrity rules

- Deleting a report or project cascades to the subcollections (`recursive_delete`).
- `save_run_safe` and `save_google_ads_analysis_safe` never interrupt the main flow; errors are only logged.
- Access: see [Authentication](../visao-geral-e-arquitetura/autenticacao.md). More about Firestore in [Firebase](../integracoes/firebase.md).
