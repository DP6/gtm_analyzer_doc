---
title: "Apps Script"
description: "Dónde encaja Apps Script en la arquitectura, variables de entorno involucradas y cómo generar el token de la cuenta publicadora."
sidebar_position: 7
---

# Apps Script

El Google Doc final lo arma un Web App de Google Apps Script, llamado por el backend. Esta página solo ubica la integración; el funcionamiento interno, las plantillas, la publicación con clasp y las capas de autenticación están en [Apps Script por dentro](../geracao-do-documento/apps-script-por-dentro.md), y la secuencia de llamadas en [Flujo de generación](../geracao-do-documento/fluxo-de-geracao.md).

## Dónde encaja

`POST /api/report/google-docs` (`backend/routers/report.py:31`) llama a `generate_drive_report` (`backend/services/apps_script_service.py:18`), que hace un POST a la URL `/exec` del Web App con el payload, el logo y el secreto compartido. El código del script queda en `Docs/ds30_appscript/`.

## Variables de entorno (solo nombres)

| Variable | Uso |
|---|---|
| `DS30_APPS_SCRIPT_URL` | URL `/exec` del despliegue (validada por regex; `/dev` se rechaza) |
| `DS30_APPS_SCRIPT_SECRET` | Mismo valor de la Script Property `DS30_SHARED_SECRET` en Apps Script |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Cliente OAuth que emitió el refresh token (compartido con el login y Google Ads) |
| `GOOGLE_REFRESH_TOKEN` | Refresh token de la cuenta publicadora, usado para obtener el Bearer de cada llamada |

Los valores nunca entran en el código, el frontend ni la documentación. La lista completa está en [Variables de entorno](../referencia/variaveis-de-ambiente.md); sin cualquiera de las cuatro primeras, el backend responde 503 antes de llamar a Google (ver [Timeout y errores](../geracao-do-documento/timeout-e-erros.md)).

## Token de la cuenta publicadora

La utilidad `backend/generate_google_refresh_token.py` autoriza la cuenta publicadora localmente:

1. Usa el cliente OAuth ya configurado (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`) y pide los scopes `drive` y `documents` con acceso offline y consentimiento forzado.
2. Abre un listener en `http://localhost:8080/` (esa URI debe estar registrada en el cliente OAuth; el puerto debe estar libre) y espera hasta 300 s.
3. Imprime solo la línea `GOOGLE_REFRESH_TOKEN=...` para que la copie manualmente al entorno protegido. No altera archivos, no publica el script y no genera informe.

Trate la salida de la terminal como secreto. Si el token es revocado, ejecútela de nuevo y reemplace el valor. Prueba de la utilidad: `backend/tests/test_generate_google_refresh_token.py`. El paso a paso en la consola de GCP está en `Docs/apps_script_integration.md`.

El estado de la cuenta puede consultarse en `GET /api/report/publisher-status` (`backend/routers/report.py:50`), que solo intenta renovar el token.

## Observaciones

- La cuenta publicadora es la misma usada para listar y exportar transcripciones de Drive (`backend/services/drive_service.py`), ver [IA (Gemini)](./ia-gemini.md).
- Publicar una nueva versión del Web App es una acción humana; ver el flujo en [Apps Script por dentro](../geracao-do-documento/apps-script-por-dentro.md).
