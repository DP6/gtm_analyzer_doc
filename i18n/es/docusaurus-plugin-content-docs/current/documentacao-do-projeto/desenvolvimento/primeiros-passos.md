---
title: "Primeros pasos"
description: "Cómo preparar el entorno local de DS30, levantar backend y frontend y autenticarse en desarrollo."
sidebar_position: 1
---

# Primeros pasos

DS30 tiene dos procesos locales: backend FastAPI (`:8000`) y frontend React/Vite (`:5173`).

## Prerrequisitos

| Ítem | Uso |
|---|---|
| Python 3 (la imagen Docker usa 3.11, `Dockerfile:19`) | backend |
| Node 20 + npm (`Dockerfile:4`) | frontend |
| `backend/.env` | configuración local (copiada de `backend/.env.example`) |

## Setup manual

```bash
# backend
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env        # depois preencha os valores

# frontend
cd ../frontend
npm ci
```

`pytest` no figura en `backend/requirements.txt`; instálelo aparte para ejecutar las pruebas (vea [Pruebas](./testes.md)).

## Levantar todo con `run_app.sh`

`./run_app.sh` (en la raíz) solo hace:

1. Elige el intérprete en `backend/`: `.venv/bin/python3` si existe `.venv`; si no, `$HOME/anaconda3/bin/python3`; si no, `python3` (`run_app.sh:13-19`).
2. Levanta `uvicorn main:app --host 0.0.0.0 --port 8000` en background.
3. Espera 2 s y levanta `npm run dev -- --port 5173 --host`.
4. Ctrl+C termina los dos procesos.

El script **no crea el venv, no instala dependencias y no ejecuta `npm ci`**: haga antes el setup manual. Tampoco usa `--reload` (el `CLAUDE.md` de la app muestra el comando con `--reload` para ejecutar el backend a mano).

## Variables de `backend/.env`

Solo los nombres (los valores nunca entran en el repositorio; `.env` es ignorado por git):

- Entorno y auth: `ENVIRONMENT`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `ALLOWED_ORIGINS`, `ALLOWED_DOMAINS`, `MASTER_ACCESS_TOKEN`, `DEV_USER_EMAIL`, `DEV_USER_NAME`
- OTP por correo: `EMAIL_OTP_ENABLED`, `EMAIL_OTP_TTL_SECONDS`, `EMAIL_SESSION_TTL_HOURS`, `SENDGRID_API_KEY`, `EMAIL_FROM_ADDRESS`, `EMAIL_FROM_NAME`
- Google Ads: `GOOGLE_ADS_DEVELOPER_TOKEN`, `GOOGLE_ADS_OAUTH_REDIRECT_URI`, `GOOGLE_ADS_OAUTH_REDIRECT_URI_DEV`, `GOOGLE_ADS_OAUTH_REDIRECT_URI_PROD`, `GOOGLE_ADS_SESSION_ENCRYPTION_KEY`
- Firestore (comentadas en el ejemplo): `GOOGLE_APPLICATION_CREDENTIALS`, `FIRESTORE_EMULATOR_HOST`

El `.env.example` no lista todas las variables que lee `backend/config.py` (por ejemplo `DS30_APPS_SCRIPT_URL`, `DS30_APPS_SCRIPT_SECRET`, `GOOGLE_REFRESH_TOKEN`, `OBSERVEPOINT_API_KEY`, `GEMINI_API_KEY`). La lista completa está en [Variables de entorno](../referencia/variaveis-de-ambiente.md).

## Autenticación en desarrollo

Con `ENVIRONMENT=development`, el backend acepta el encabezado `X-Dev-User-Email` como identidad (`backend/services/auth_service.py:238-239`; con cualquier otro valor de `ENVIRONMENT` el bypass se rechaza). El frontend envía ese encabezado cuando `gtm_auth_dev_email` está en `localStorage`. Detalles y prioridad de los métodos: [Autenticación](../visao-geral-e-arquitetura/autenticacao.md).

## Direcciones

| Qué | URL |
|---|---|
| Frontend | http://localhost:5173 |
| API | http://localhost:8000 |
| OpenAPI (Swagger) | http://localhost:8000/docs |

En dev, Vite hace proxy de `/api` hacia `localhost:8000` (`frontend/vite.config.js`). Visión general de las rutas: [Visión general de la API](../api/visao-geral-da-api.md).
