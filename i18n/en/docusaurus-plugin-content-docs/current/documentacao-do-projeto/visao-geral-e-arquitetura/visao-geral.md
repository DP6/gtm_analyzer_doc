---
title: "Overview"
description: "What DS30 is, the stack in use and the repository map."
sidebar_position: 1
---

# Overview

**DS30 (GTM Architecture & UPD Analyzer)** audits Google Tag Manager containers (Web, server-side and mobile), checks the User-Provided Data (UPD) configuration and generates the technical diagnostic as a Google Doc. The API presents itself as "DS30 - GTM Architecture & UPD Analyzer API" (`backend/main.py:24`).

## Stack

| Layer | Technology |
|---|---|
| Backend | FastAPI + Uvicorn (Python 3.11 in the Docker image) |
| Frontend | React 18, Vite 5, Tailwind 3, react-router-dom 6 (`frontend/package.json`) |
| Persistence | Firestore via `firebase-admin`, named database `gtm-analyzer` (`backend/services/firestore_service.py:32`) |
| Document generation | Google Apps Script (Web App) called by the backend |
| AI | Gemini (diagnostic considerations and transcript insights) |
| Deploy | Multi-stage Docker + Cloud Run (via `Makefile`) |

## Repository map

```text
gtm_analyzer_app/
├── backend/
│   ├── main.py            # FastAPI app, CORS, routers, SPA
│   ├── config.py          # Settings (pydantic-settings)
│   ├── deps.py            # get_current_user / get_optional_user
│   ├── routers/           # /api/* endpoints (auth, audit, projects, report, crawler, google_ads, google_platforms, transcripts)
│   ├── services/          # business logic and integrations (Firestore, GTM/GA4, ObservePoint, Gemini, Apps Script...)
│   ├── audits/            # web, server and mobile container audits
│   ├── models/            # Pydantic models (transcript_insights)
│   ├── scripts/           # render_cloudrun_env.py (validates/generates Cloud Run env)
│   └── tests/             # pytest
├── frontend/src/          # components, context (AuthContext), services/api.js, utils
├── Docs/                  # JSON contracts, .docx template, Apps Script, runbooks
├── Makefile               # build, run-local, deploy (dev/prod)
└── Dockerfile             # frontend build + backend runtime
```

## Where to go next

- How the pieces connect: [Architecture](./arquitetura.md).
- Who can call what: [Authentication and authorization](./autenticacao.md).
- Endpoints: [API overview](../api/visao-geral-da-api.md).
- Running locally: [Getting started](../desenvolvimento/primeiros-passos.md).
