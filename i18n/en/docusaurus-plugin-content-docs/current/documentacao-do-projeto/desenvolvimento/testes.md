---
title: "Tests"
description: "How to run and organize DS30's backend (pytest) and frontend (node:test) tests."
sidebar_position: 2
---

# Tests

## Commands

| Target | Command |
|---|---|
| Backend (all) | `cd backend && .venv/bin/python -m pytest tests` |
| One file | `cd backend && .venv/bin/python -m pytest tests/test_audit_service.py` |
| One test | `... pytest tests/test_audit_service.py::test_name` |
| Frontend | `cd frontend && npm test` (`node --test src/utils/*.test.js`) |
| Frontend build | `cd frontend && npm run build` |

`pytest` is not in `backend/requirements.txt`; install it in the venv if needed. `tests/conftest.py` only puts `backend/` on `sys.path`.

## Backend organization

20 `test_*.py` files in `backend/tests/`, plus `conftest.py`, grouped by area:

| Area | Files |
|---|---|
| GTM audit | `test_audit_service.py`, `test_considerations_service.py`, `test_gtm_request_analyzer.py` |
| Google Ads | `test_google_ads_service.py`, `test_google_ads_api_service.py`, `test_google_ads_oauth_service.py` |
| GTM/GA4 and accounts | `test_google_platform_service.py`, `test_project_google_accounts.py` |
| Crawler / ObservePoint / CDN | `test_crawler_service.py`, `test_observepoint_service.py`, `test_cdn_analyzer.py` |
| Report and payload | `test_report_contract_v2.py`, `test_payload_helpers.py`, `test_docx_generation_with_observepoint_payload.py` |
| Persistence / Drive | `test_firestore_service.py`, `test_drive_service.py` |
| Transcripts | `test_transcript_insights_service.py` |
| Deploy and tooling | `test_makefile_deploy.py`, `test_render_cloudrun_env.py`, `test_generate_google_refresh_token.py` |

Notes:

- Despite the name, `test_report_contract_v2.py` tests the current `POST /api/report/google-docs` flow (Apps Script), not the v2 payload.
- `test_docx_generation_with_observepoint_payload.py` and `test_cdn_analyzer.py` depend on `backend/doc_generator.py`, legacy code (see [Legacy](../ia-e-agentes/legado-e-documentos-obsoletos.md)).
- The `backend/modules/*/tests` directories exist but contain no `.py` files.

## Frontend

Utilities only: `src/utils/payloadHelpers.test.js`, `crawlerUrls.test.js`, `appsScript.test.js`, with `node:test` and `node:assert/strict`. There are no React component tests.

## What the tests cover (and what they do not)

The tests target **services** and helpers, not the routers: business logic lives in `services/` and `audits/`, and the handlers are thin. A few exceptions import functions from `routers.report` (`test_report_contract_v2.py`).

There is no CI in the repository (no `.github/`) and no coverage threshold. Running both suites and the build before integrating is the developer's responsibility.

## Conventions

- `test_*.py` files, `test_<behavior>` functions.
- Frontend: `*.test.js` next to the utility.
- Add a regression test when touching: payload merging (`payloadHelpers`), API contracts, audit rules (`backend/audits/`), Google Ads classification and report generation.
- Changes to the deploy `Makefile` must keep `test_makefile_deploy.py` green (see [Deploy](./deploy.md)).
