---
title: "Visão geral"
description: "O que é o DS30, a stack utilizada e o mapa do repositório."
sidebar_position: 1
---

# Visão geral

O **DS30 (GTM Architecture & UPD Analyzer)** audita contêineres do Google Tag Manager (Web, server-side e mobile), verifica a configuração de User-Provided Data (UPD) e gera o diagnóstico técnico em Google Docs. A API se apresenta como "DS30 - GTM Architecture & UPD Analyzer API" (`backend/main.py:24`).

## Stack

| Camada | Tecnologia |
|---|---|
| Backend | FastAPI + Uvicorn (Python 3.11 na imagem Docker) |
| Frontend | React 18, Vite 5, Tailwind 3, react-router-dom 6 (`frontend/package.json`) |
| Persistência | Firestore via `firebase-admin`, banco nomeado `gtm-analyzer` (`backend/services/firestore_service.py:32`) |
| Geração do documento | Google Apps Script (Web App) chamado pelo backend |
| IA | Gemini (considerações do diagnóstico e insights de transcrições) |
| Deploy | Docker multi-stage + Cloud Run (via `Makefile`) |

## Mapa do repositório

```text
gtm_analyzer_app/
├── backend/
│   ├── main.py            # app FastAPI, CORS, routers, SPA
│   ├── config.py          # Settings (pydantic-settings)
│   ├── deps.py            # get_current_user / get_optional_user
│   ├── routers/           # endpoints /api/* (auth, audit, projects, report, crawler, google_ads, google_platforms, transcripts)
│   ├── services/          # regra de negócio e integrações (Firestore, GTM/GA4, ObservePoint, Gemini, Apps Script...)
│   ├── audits/            # auditorias de contêiner web, server e mobile
│   ├── models/            # modelos Pydantic (transcript_insights)
│   ├── scripts/           # render_cloudrun_env.py (valida/gera env do Cloud Run)
│   └── tests/             # pytest
├── frontend/src/          # components, context (AuthContext), services/api.js, utils
├── Docs/                  # contratos JSON, template .docx, Apps Script, runbooks
├── Makefile               # build, run-local, deploy (dev/prod)
└── Dockerfile             # build do frontend + runtime do backend
```

## Para continuar

- Como as peças se conectam: [Arquitetura](./arquitetura.md).
- Quem pode chamar o quê: [Autenticação e autorização](./autenticacao.md).
- Endpoints: [Visão geral da API](../api/visao-geral-da-api.md).
- Rodar localmente: [Primeiros passos](../desenvolvimento/primeiros-passos.md).
