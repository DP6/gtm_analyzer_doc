---
title: "Firebase (Firestore)"
description: "How the backend uses Firestore for projects, reports and runs, credentials (ADC), the named database and required permissions."
sidebar_position: 6
---

# Firebase (Firestore)

Firestore stores projects, reports and the run history. Only the backend accesses it, via the Admin SDK (`firebase-admin`); there are no Firestore Rules and no direct access from the frontend. Code: `backend/services/firestore_service.py`.

## Connection and credentials

- `_ensure_app` (`firestore_service.py:25`) calls `firebase_admin.initialize_app()` with no arguments, i.e. it uses **Application Default Credentials (ADC)**: in development, `gcloud auth application-default login`; on Cloud Run, the service's service account. There is no key file in the code.
- `client()` (`:32`) opens the **named database `gtm-analyzer`** (`firestore.client(database_id="gtm-analyzer")`), not `(default)`.

## Data model

| Path | Contents |
|---|---|
| `users/{email}` | Profile mirror (`ensure_user`, `:73`) |
| `projects/{id}` | Owner (`owner_email`), `member_emails`, client data, logo, `google_accounts`, `last_report_at` |
| `projects/{id}/reports/{id}` | Status (`draft` or `generated`), generated document, snapshot of the latest Google Ads analysis |
| `projects/{id}/reports/{id}/runs/{id}` | Immutable run: `source`, `payload`, `triggered_by`, `created_at`, and `document_id`/`document_url` when a generation took place |

`projects` is a top-level collection to allow sharing between users. Access is enforced in code (`has_access`, `is_owner`, `:65`), not by Firestore. The full dictionary is in [Data dictionary](../referencia/dicionario-de-dados.md) and the routes in [Projects API](../api/projects.md).

`save_run` (`:87`) checks access, adds the run, updates the report and the project and, when `source == "report"`, marks the report as `generated`. `save_run_safe` (`:116`) swallows exceptions so that history never brings down the main operation (used after upload, live analysis, crawler and document generation; see [Generation flow](../geracao-do-documento/fluxo-de-geracao.md)).

## Permissions

- **Cloud Run.** The service's service account needs Firestore data permission. According to the survey in `Docs/firebase_gcp_permissions.md`, both deployments use the default Compute Engine service account with `roles/editor`, which already covers Firestore. If that account is ever restricted, add `roles/datastore.user` explicitly, otherwise the app fails to save runs and projects. This was surveyed on a past date and has not been rechecked now: confirm with `gcloud` before relying on it.
- **Local developer.** Needs a `datastore.*` role (the survey recommends `roles/datastore.owner`, granted by whoever administers the project's IAM) and ADC configured. See [Getting started](../desenvolvimento/primeiros-passos.md).
- IAM changes in production are a human action.

## OAuth redirect

`GOOGLE_ADS_OAUTH_REDIRECT_URI` must be the backend's fixed callback route (`/api/google-ads/oauth/callback`), registered in the OAuth client in the GCP console. The user's final destination (`return_to`, for example `/projects/<id>/reports/<id>?tab=...`) travels in the signed `state`, it is not a redirect URI, so changing the return screen does not require changing GCP. Just check that the variable's value in each environment is identical to the registered one. Flow details in [Google OAuth](./google-oauth.md).

## Supporting documents: what is outdated

- `Docs/firebase_setup_runbook.md` talks about "branch `feat/firebase-persistence`, staged, not committed" and an optional step to switch to a named database, saying it would require changing the code to `firestore.client(database_id="gtm-analyzer")`. That change **is already in the code**; the runbook's future-tense verbs and branch state are historical.
- `Docs/firebase_gcp_permissions.md` describes findings from 2026-09-15 (the `(default)` database mode open, roles of specific people). Treat it as a snapshot of a date, not the current state. The question about sharing `(default)` lost relevance because the app uses the named database.
- Step 5 of the runbook (manual test script: project, sharing, reports, resuming, deletion) is still useful as a validation checklist.
- Both documents list a pre-existing failure in `frontend/src/utils/appsScript.test.js`; not verified here.

## Not verified

- Whether the `gtm-analyzer` database exists, in which region and in which mode, in the dev and prod projects: only `gcloud firestore databases list` confirms.
- Required composite indexes: the code does not declare them; Firestore asks for them at runtime.
