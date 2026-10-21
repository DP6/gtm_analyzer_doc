---
title: "Visión general"
description: "Qué es DS30, el stack utilizado y el mapa del repositorio."
sidebar_position: 1
---

# Visión general

**DS30 (GTM Architecture & UPD Analyzer)** audita contenedores de Google Tag Manager (Web, server-side y mobile), verifica la configuración de User-Provided Data (UPD) y genera el diagnóstico técnico en Google Docs. La API se presenta como "DS30 - GTM Architecture & UPD Analyzer API" (`backend/main.py:24`).

## Stack

| Capa | Tecnología |
|---|---|
| Backend | FastAPI + Uvicorn (Python 3.11 en la imagen Docker) |
| Frontend | React 18, Vite 5, Tailwind 3, react-router-dom 6 (`frontend/package.json`) |
| Persistencia | Firestore vía `firebase-admin`, base de datos nombrada `gtm-analyzer` (`backend/services/firestore_service.py:32`) |
| Generación del documento | Google Apps Script (Web App) llamado por el backend |
| IA | Gemini (consideraciones del diagnóstico e insights de transcripciones) |
| Despliegue | Docker multi-stage + Cloud Run (vía `Makefile`) |

## Mapa del repositorio

```text
gtm_analyzer_app/
├── backend/
│   ├── main.py            # app FastAPI, CORS, routers, SPA
│   ├── config.py          # Settings (pydantic-settings)
│   ├── deps.py            # get_current_user / get_optional_user
│   ├── routers/           # endpoints /api/* (auth, audit, projects, report, crawler, google_ads, google_platforms, transcripts)
│   ├── services/          # regla de negocio e integraciones (Firestore, GTM/GA4, ObservePoint, Gemini, Apps Script...)
│   ├── audits/            # auditorías de contenedor web, server y mobile
│   ├── models/            # modelos Pydantic (transcript_insights)
│   ├── scripts/           # render_cloudrun_env.py (valida/genera env de Cloud Run)
│   └── tests/             # pytest
├── frontend/src/          # components, context (AuthContext), services/api.js, utils
├── Docs/                  # contratos JSON, plantilla .docx, Apps Script, runbooks
├── Makefile               # build, run-local, deploy (dev/prod)
└── Dockerfile             # build del frontend + runtime del backend
```

## Para continuar

- Cómo se conectan las piezas: [Arquitectura](./arquitetura.md).
- Quién puede llamar a qué: [Autenticación y autorización](./autenticacao.md).
- Endpoints: [Visión general de la API](../api/visao-geral-da-api.md).
- Ejecutar localmente: [Primeros pasos](../desenvolvimento/primeiros-passos.md).
