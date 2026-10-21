---
title: "Visión general de la API"
description: "Cómo el backend FastAPI de DS30 monta los routers, autentica, trata errores y expone la API HTTP."
sidebar_position: 1
---

# Visión general de la API

El backend es una app FastAPI (`backend/main.py`). Cada área funcional tiene un router en `backend/routers/*.py`; la lógica pesada queda en `backend/services/*.py`.

## Montaje de la app

| Ítem | Dónde | Comportamiento |
|---|---|---|
| Registro de routers | `backend/main.py:39-49` | `auth` y el callback OAuth de Google Ads son públicos; los otros 7 routers reciben `dependencies=[Depends(get_current_user)]` |
| CORS | `backend/main.py:30-36` | `allow_origins=settings.ALLOWED_ORIGINS`, `allow_credentials=True`, métodos y headers `*` |
| Health | `backend/main.py:51-54` | `GET /health` y `GET /api/health` retornan `{"status":"ok","service":"gtm-analyzer-backend"}` (sin auth) |
| SPA fallback | `backend/main.py:57-69` | Si existe `backend/static/`, monta `/assets` y sirve cualquier otra ruta como archivo estático o `index.html` |
| Raíz sin build | `backend/main.py:71-77` | Sin `static/`, `GET /` devuelve `{"ok":true,...}` |

La autenticación (`get_current_user`, `backend/deps.py:5`) se aplica en el registro del router, no ruta por ruta. Las rutas que necesitan al usuario también declaran `Depends(get_current_user)` para recibir el dict `user` (la dependencia se resuelve una vez por solicitud).

:::warning
Como el fallback SPA es `GET /{full_path:path}`, un `GET` a una ruta inexistente bajo `/api` en producción devuelve el `index.html` (200), no 404.
:::

## Autenticación

`get_current_user` lee `Authorization: Bearer`, `X-Email-Session`, `X-Access-Token` (o `?token=`) y `X-Dev-User-Email`, en ese orden de prioridad (`backend/services/auth_service.py:259-299`). Sin usuario válido: `401` con `WWW-Authenticate: Bearer`. Detalles en [Autenticación](../visao-geral-e-arquitetura/autenticacao.md).

## Convenciones

- **Routers delgados**: validan la entrada (Pydantic), llaman a un servicio y traducen errores.
- **Errores de servicio**: los servicios lanzan `ValueError` o errores de dominio (`GoogleAdsApiError`, `GooglePlatformApiError`, `GoogleAdsConnectionError`) y el router los convierte en `HTTPException`. Algunos servicios lanzan `HTTPException` directamente (`apps_script_service.py`, `drive_service.py`).
- **Mensajes en portugués** en el campo `detail`. En errores de Google Ads, `detail` es un objeto `{"message", "request_id"}`.
- **SDKs bloqueantes** (Firestore, Google Ads) corren en `run_in_threadpool` dentro de rutas `async`; las rutas `def` sin `async` ya corren en el threadpool de FastAPI.
- **Persistencia `*_safe`**: `save_run_safe`, `record_google_accounts` y `save_google_ads_analysis_safe` (`backend/services/firestore_service.py:116-165`) tragan las excepciones y solo registran en el log. Una falla al guardar el historial nunca tumba el análisis; la respuesta vuelve normalmente.
- **404 vs 403**: sin acceso a un proyecto, la API responde `404 Projeto não encontrado.` (Proyecto no encontrado.) para no revelar que existe. `403` solo aparece cuando el usuario tiene acceso pero no es dueño (`backend/routers/projects.py:63-75`).

## Mapa de estados

| Estado | Uso típico |
|---|---|
| 200 | Éxito |
| 202 | `POST /api/crawler/crawl` (ejecución encolada) |
| 400 | Archivo inválido, OTP desactivado/inválido, CSV de Google Ads inválido, ObservePoint sin clave |
| 401 | Sin autenticación; conexión de Google ausente/expirada |
| 403 | No es dueño del proyecto; ObservePoint denegó |
| 404 | Proyecto/informe/ejecución inexistente o sin acceso |
| 409 | Cuota de ObservePoint alcanzada |
| 422 | Validación Pydantic o `ValueError` de servicio |
| 502 | Falla en API externa (Google, Drive, Apps Script, ObservePoint, Gemini) |
| 503 | Integración no configurada (Gemini, Google OAuth, Apps Script) |
| 504 | Apps Script agotó el tiempo |

## Timeouts

Todos fijos en el código; no hay variable de entorno para ajustarlos.

| Llamada | Timeout | Archivo |
|---|---|---|
| APIs de Google (GTM, GA4) | 30 s | `backend/services/google_platform_service.py:20` |
| Google Drive (listar/exportar) | 30 s | `backend/services/drive_service.py:72,94` |
| ObservePoint | 10 a 30 s, según la llamada | `backend/services/observepoint_service.py:118-443` |
| Apps Script | 360 s total, 10 s de conexión | `backend/services/apps_script_service.py:60` |
| SendGrid (OTP) | 5 s | `backend/services/auth_service.py:150` |
| Revocación OAuth de Google | 10 s | `backend/services/google_ads_oauth_service.py:212` |
| Gemini | sin timeout explícito | `backend/services/considerations_service.py` |

Vea también [Timeout y errores](../geracao-do-documento/timeout-e-erros.md).

## Llamar localmente

1. Levante el backend en el puerto 8000 (`python main.py` ejecuta `uvicorn` con reload, `backend/main.py:79-81`).
2. Vite hace proxy de `/api` hacia `http://localhost:8000` (`frontend/vite.config.js:9-14`); el frontend llama a rutas relativas.
3. OpenAPI interactivo en `http://localhost:8000/docs`.
4. En desarrollo, el modo dev acepta `X-Dev-User-Email` (ver autenticación).

```bash
curl http://localhost:8000/api/health
curl -H "X-Dev-User-Email: dev@exemplo.com" http://localhost:8000/api/auth/me
```

Más en [Primeros pasos](../desenvolvimento/primeiros-passos.md).

## Páginas

[Auth](./auth.md), [Audit](./audit.md), [Projects](./projects.md), [Report](./report.md), [Crawler](./crawler.md), [Google Ads](./google-ads.md), [Google Platforms](./google-platforms.md), [Transcripts](./transcripts.md).
