---
title: "Router Google Platforms"
description: "Rutas de GTM y GA4 vía API de Google, usando la conexión OAuth compartida con Google Ads."
sidebar_position: 8
---

# Router Google Platforms

Router único sin prefijo (`router = APIRouter(tags=["Google Platforms"])`), con rutas completas en cada endpoint. Autenticado. Router: `backend/routers/google_platforms.py`; servicio: `backend/services/google_platform_service.py`. Ver [GTM y GA4](../integracoes/google-tag-manager-e-ga4.md) y [Google OAuth](../integracoes/google-oauth.md).

## Rutas

Todas exigen usuario autenticado **y** la cookie de conexión de Google (`gtm_google_ads_session`, la misma de [Google Ads](./google-ads.md)).

| Método | Ruta | Entrada | Respuesta | Errores |
|---|---|---|---|---|
| GET | `/api/gtm/accounts` (`:62`) | n/d | cuentas GTM | 401, 502, Google |
| GET | `/api/gtm/accounts/{account_id}/containers` (`:70`) | path | containers | 422, 401, Google |
| GET | `/api/gtm/accounts/{account_id}/containers/{container_id}/versions` (`:79`) | path | versiones | 422, 401, Google |
| POST | `/api/gtm/analyze-live` (`:89`) | `{"version_path","project_id?","report_id?"}` | payload canónico GTM | 422, 401, Google |
| GET | `/api/google-analytics/properties` (`:109`) | n/d | propiedades GA4 | 401, Google |
| POST | `/api/google-analytics/analyze-live` (`:117`) | `{"property","start_date?","end_date?","project_id?","report_id?"}` | análisis GA4 | 422, 401, Google |

`version_path` tiene el formato `accounts/{a}/containers/{c}/versions/{v}`. `property` es `properties/{id}`.

## Implementación

- `_token` (`:44-51`): lee la conexión de la cookie (`read_connection`) y cambia el refresh token por un access token (`access_token`). Una falla de conexión se convierte en 401; cualquier otro error, en 502 `Não foi possível renovar a autorização do Google.` (No fue posible renovar la autorización de Google.)
- `_run` (`:54-59`): ejecuta el servicio y convierte `ValueError` en `HTTPException`. `GooglePlatformApiError` (subclase de `ValueError`) mantiene el `status_code` de Google (400, 401, 403, 404, 429; otros se convierten en 502 en `google_platform_service.py:30`); un `ValueError` común se convierte en 422.
- Las llamadas a Google usan `httpx` síncrono con timeout 30 s y paginación por `nextPageToken` con `pageSize=200` (`google_platform_service.py:17-45`).
- Las rutas de listado son `def` (corren en el threadpool de FastAPI); las `analyze-live` son `async`, pero llaman al servicio bloqueante directamente (`_run`), solo la escritura en Firestore usa `run_in_threadpool`.
- Persistencia opcional: con `project_id` y `report_id`, `save_run_safe` guarda un run `live`. Si se guardó, `record_google_accounts` registra `gtm_account_ids`/`gtm_container_ids` (extraídos de `version_path`) o `ga4_property_ids` (`property` después de la última `/`).

## Ejemplo

```bash
curl -b "<cookie_da_sessao>" -H "Authorization: Bearer <id_token>" \
  http://localhost:8000/api/gtm/accounts

curl -b "<cookie_da_sessao>" -X POST http://localhost:8000/api/gtm/analyze-live \
  -H "Authorization: Bearer <id_token>" -H "Content-Type: application/json" \
  -d '{"version_path":"accounts/111/containers/222/versions/3"}'

curl -b "<cookie_da_sessao>" -X POST http://localhost:8000/api/google-analytics/analyze-live \
  -H "Authorization: Bearer <id_token>" -H "Content-Type: application/json" \
  -d '{"property":"properties/123456","start_date":"2026-01-01","end_date":"2026-01-31"}'
```

## Puntos de atención

- Sin cookie: 401 `Conta Google Ads não conectada.` (Cuenta de Google Ads no conectada.; mensaje heredado del servicio de OAuth). Cookie antigua sin scopes de GTM/GA4: 401 pidiendo renovación.
- A diferencia de Google Ads, aquí el `detail` es una string, no un objeto con `request_id`.
- Las rutas `analyze-live` bloquean el event loop durante la llamada a Google (hasta 30 s por solicitud). Punto de atención si hay mucha concurrencia.
- Período GA4: días completos, en orden, hasta 366 días (`google_platform_service.py:129`).
- Si el análisis GTM retorna `error`, se convierte en 422 (`google_platform_service.py:98`).
