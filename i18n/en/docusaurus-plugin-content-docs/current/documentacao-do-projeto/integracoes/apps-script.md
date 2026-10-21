---
title: "Apps Script"
description: "Where Apps Script fits in the architecture, the environment variables involved and how to generate the publisher account token."
sidebar_position: 7
---

# Apps Script

The final Google Doc is assembled by a Google Apps Script Web App, called by the backend. This page only situates the integration; the internals, the templates, publishing with clasp and the authentication layers are in [Apps Script internals](../geracao-do-documento/apps-script-por-dentro.md), and the call sequence in [Generation flow](../geracao-do-documento/fluxo-de-geracao.md).

## Where it fits

`POST /api/report/google-docs` (`backend/routers/report.py:31`) calls `generate_drive_report` (`backend/services/apps_script_service.py:18`), which makes a POST to the Web App's `/exec` URL with the payload, the logo and the shared secret. The script code lives in `Docs/ds30_appscript/`.

## Environment variables (names only)

| Variable | Use |
|---|---|
| `DS30_APPS_SCRIPT_URL` | The deployment's `/exec` URL (validated by regex; `/dev` is rejected) |
| `DS30_APPS_SCRIPT_SECRET` | Same value as the `DS30_SHARED_SECRET` Script Property in Apps Script |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | OAuth client that issued the refresh token (shared with login and Google Ads) |
| `GOOGLE_REFRESH_TOKEN` | Publisher account refresh token, used to obtain the Bearer for each call |

Values never go into the code, the frontend or the documentation. The full list is in [Environment variables](../referencia/variaveis-de-ambiente.md); without any one of the first four, the backend responds 503 before calling Google (see [Timeout and errors](../geracao-do-documento/timeout-e-erros.md)).

## Publisher account token

The utility `backend/generate_google_refresh_token.py` authorizes the publisher account locally:

1. Uses the already configured OAuth client (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`) and requests the `drive` and `documents` scopes with offline access and forced consent.
2. Opens a listener at `http://localhost:8080/` (that URI must be registered in the OAuth client; the port must be free) and waits up to 300 s.
3. Prints only the line `GOOGLE_REFRESH_TOKEN=...` for you to copy manually into the protected environment. It does not change files, publish the script or generate a report.

Treat the terminal output as a secret. If the token is revoked, run it again and replace the value. Utility test: `backend/tests/test_generate_google_refresh_token.py`. The step-by-step in the GCP console is in `Docs/apps_script_integration.md`.

The account's health can be queried at `GET /api/report/publisher-status` (`backend/routers/report.py:50`), which just tries to renew the token.

## Notes

- The publisher account is the same one used to list and export Drive transcripts (`backend/services/drive_service.py`), see [AI (Gemini)](./ia-gemini.md).
- Publishing a new version of the Web App is a human action; see the flow in [Apps Script internals](../geracao-do-documento/apps-script-por-dentro.md).
