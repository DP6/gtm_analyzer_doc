---
title: "Frontend"
description: "Stack, folder structure, routes, workspace tabs, payload state, autosave and the HTTP client of the DS30 frontend."
sidebar_position: 3
---

# Frontend

:::warning Outdated CLAUDE.md
The app repository's `CLAUDE.md` still describes a single-page SPA with `TABS` in `App.jsx`. The current code uses routes (`react-router-dom`) and the tabs live in `ReportWorkspace.jsx`. This page reflects the code.
:::

## Stack

React 18, Vite 5, Tailwind 3, `react-router-dom` 6 and `lucide-react` (`frontend/package.json`). No formatter/linter: 2-space indentation, `PascalCase` for components, `camelCase` for everything else.

## Folders (`frontend/src/`)

| Folder | Contents |
|---|---|
| `components/` | screens and UI blocks (`ProjectGrid`, `ReportWorkspace`, `CrawlerScanner`, `GoogleAdsAnalyzer`, `DriveReportGenerator`, ...) |
| `context/` | `AuthContext.jsx` |
| `services/` | `api.js`, the only HTTP client |
| `utils/` | `payloadHelpers.js`, `crawlerUrls.js`, `reportFieldConfig.js`, `tags.js` and tests |

## Routes (`App.jsx`)

Without an authenticated user, the "Autenticação Requerida" (Authentication Required) screen appears. With a user:

| Route | Component |
|---|---|
| `/` | `ProjectGrid` |
| `/projects/:projectId` | `ProjectShell` (layout) |
| `/projects/:projectId` (index) | `ReportList` |
| `.../settings` | `ProjectSettings` |
| `.../reports/new` | `ReportCreate` |
| `.../reports/:reportId` | `ReportWorkspace` |
| anything else | redirects to `/` |

## Workspace tabs

`TABS` in `ReportWorkspace.jsx:16`: `transcripts` (Transcrições), `overview` (Visão Geral / GTG), `gtm` (Auditoria GTM), `ga` (Google Analytics), `google_ads`, `oci` (OCI / ECL), `eco`, `report` (Diagnóstico) and `history` (Histórico). The active tab comes from the `tab` URL parameter when valid; default `overview` (or `google_ads` if the URL has `google_ads`).

## Payload state and autosave

All tabs share a single `payload`, merged progressively with `mergePayload` (`utils/payloadHelpers.js`). That object is the contract sent to the backend (see [Payload v3](../geracao-do-documento/payload-v3.md)).

Autosave (`ReportWorkspace.jsx:22,81-85`):

- Each `payload` change schedules `updateReport(project.id, reportId, { payload })` after `AUTOSAVE_DELAY_MS = 1500` ms (debounce).
- `skipNextAutosave` (ref) avoids rewriting right after loading the report from the server.
- Failures are swallowed (`.catch(() => {})`): the user sees no error if saving fails.

## HTTP client (`services/api.js`)

One function per endpoint, all under `/api`. `getAuthHeaders()` reads `localStorage` and sets **one** header, in priority order: `gtm_auth_google_token` (`Authorization: Bearer`), `gtm_auth_email_session` (`X-Email-Session`), `gtm_auth_access_token` (`X-Access-Token`), `gtm_auth_dev_email` (`X-Dev-User-Email`). Login tokens live in `localStorage` (not in a cookie). Backend: [Authentication](../visao-geral-e-arquitetura/autenticacao.md).

## Crawler

`CrawlerScanner.jsx` stores the active scan in `localStorage` per report (`scanKey(reportId)`) and calls `pollWebsiteScan` every 5 s; on completion or failure, it removes the key. This way the scan survives a page reload. API: [Crawler](../api/crawler.md).

## Dev and production

- Dev: Vite on `:5173` with `/api` proxied to `http://localhost:8000` (`vite.config.js`).
- Production: `npm run build` in stage 1 of the Dockerfile; `dist` is copied to `backend/static` and served by FastAPI as an SPA ([Deploy](./deploy.md)).
