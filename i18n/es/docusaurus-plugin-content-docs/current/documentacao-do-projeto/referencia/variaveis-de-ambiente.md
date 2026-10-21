---
title: "Variables de entorno"
description: "Todas las variables de configuración del backend, agrupadas, con finalidad y obligatoriedad."
sidebar_position: 3
---

# Variables de entorno

Definidas en `backend/config.py` (clase `Settings`, pydantic-settings), leídas de `backend/.env` o del entorno; las variables desconocidas se ignoran. El modelo está en `backend/.env.example`. **Nunca registre valores reales** en docs, commits ni chats.

Columna "Obligatoria": **Cloud Run** = exigida por `backend/scripts/render_cloudrun_env.py` (`REQUIRED_KEYS`) en el despliegue; **Funcionalidad** = solo es necesaria para la funcionalidad citada; **No** = opcional.

## Entorno y CORS

| Variable | Finalidad | Obligatoria |
|---|---|---|
| `ENVIRONMENT` | `development` habilita el modo dev; `prod`/`production` desactiva OTP y marca las cookies como `secure`. El despliegue la define (`Makefile`) | No (predeterminado `development`) |
| `ALLOWED_ORIGINS` | Orígenes de CORS, separados por coma | No |
| `PORT` | Puerto de Uvicorn en la imagen Docker (no es de `Settings`) | No (predeterminado 8080) |

## Google (login, Drive y Ads)

| Variable | Finalidad | Obligatoria |
|---|---|---|
| `GOOGLE_CLIENT_ID` | Audiencia de Google Sign-In; cliente OAuth de Drive y Ads | Cloud Run |
| `GOOGLE_CLIENT_SECRET` | Secreto del cliente OAuth | Cloud Run |
| `GOOGLE_REFRESH_TOKEN` | Cuenta que publica documentos en Drive (`drive_service.py:16`) | Funcionalidad (generación en Drive); no consta en `.env.example` |
| `GOOGLE_ADS_DEVELOPER_TOKEN` | Developer token de la Google Ads API | Cloud Run |
| `GOOGLE_ADS_OAUTH_REDIRECT_URI` | Callback OAuth de Ads; en el despliegue viene de `_DEV`/`_PROD` | Funcionalidad (Ads) |
| `GOOGLE_ADS_OAUTH_REDIRECT_URI_DEV`, `_PROD` | Solo en el `.env`; el renderizador elige una y la escribe como `GOOGLE_ADS_OAUTH_REDIRECT_URI` (HTTPS, ruta `/api/google-ads/oauth/callback`, sin localhost) | Cloud Run (la del entorno) |
| `GOOGLE_ADS_SESSION_ENCRYPTION_KEY` | Secreto aleatorio largo que cifra la sesión de Ads | Cloud Run |

## Autenticación

| Variable | Finalidad | Obligatoria |
|---|---|---|
| `ALLOWED_DOMAINS` | Dominios de correo adicionales (`@dp6.com.br` siempre se acepta); predeterminado `dp6.com.br` | Cloud Run |
| `EMAIL_OTP_ENABLED` | Activa el inicio de sesión por OTP (ignorado en producción) | Cloud Run |
| `EMAIL_OTP_TTL_SECONDS` | Vigencia del código (predeterminado 600) | No |
| `EMAIL_SESSION_TTL_HOURS` | Vigencia de la sesión (predeterminado 24) | No |
| `SENDGRID_API_KEY` | Envío del OTP; vacío = código en el log | Cloud Run |
| `EMAIL_FROM_ADDRESS`, `EMAIL_FROM_NAME` | Remitente del OTP | No |
| `DEV_USER_EMAIL`, `DEV_USER_NAME` | Usuario del modo dev; el nombre se usa en el perfil, y el correo solo lo exige el renderizador | Cloud Run (`DEV_USER_EMAIL`) |
| `MASTER_ACCESS_TOKEN` | Token de acceso directo. **Valor predeterminado inseguro**: sobrescríbalo en producción | Cloud Run |

Ver [Autenticación](../visao-geral-e-arquitetura/autenticacao.md).

## Integraciones

| Variable | Finalidad | Obligatoria |
|---|---|---|
| `OBSERVEPOINT_API_KEY` | Clave de la API de ObservePoint | Cloud Run |
| `OBSERVEPOINT_BASE_URL` | URL base (predeterminado `https://api.observepoint.com`) | No |
| `GEMINI_API_KEY` | Consideraciones e insights de transcripciones; el servicio copia el valor al entorno del proceso | Funcionalidad (IA); fuera de `.env.example` |
| `DS30_APPS_SCRIPT_URL` | URL `/exec` del Web App de Apps Script (validada por regex) | Funcionalidad (generar documento) |
| `DS30_APPS_SCRIPT_SECRET` | Secreto enviado como `Bearer` a Apps Script | Funcionalidad (generar documento) |

Ver [Apps Script](../integracoes/apps-script.md), [ObservePoint](../integracoes/observepoint.md) e [IA Gemini](../integracoes/ia-gemini.md).

## Firestore (fuera de `Settings`)

Comentadas en `.env.example`, leídas por las bibliotecas de Google:

| Variable | Finalidad |
|---|---|
| `GOOGLE_APPLICATION_CREDENTIALS` | Clave de service account en el desarrollo local (en Cloud Run vale la ADC de la instancia) |
| `FIRESTORE_EMULATOR_HOST` | Apunta al emulador de Firestore |

Ver [Firebase](../integracoes/firebase.md).
