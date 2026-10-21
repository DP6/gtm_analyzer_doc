---
title: "Google Tag Manager y GA4"
description: "Lectura de containers GTM y propiedades GA4 mediante las APIs de Google, reutilizando el mismo pipeline de auditoría de la carga de JSON."
sidebar_position: 3
---

# Google Tag Manager y GA4

`backend/services/google_platform_service.py` consulta GTM (API v2), GA4 Admin y GA4 Data con el access token del usuario, obtenido de la conexión descrita en [Google OAuth](./google-oauth.md). Las rutas están en `backend/routers/google_platforms.py` (ver [API plataformas Google](../api/google-platforms.md)); `_token` (`:46`) lee la cookie, valida dueño y scopes y renueva el access token (401 si la conexión es inválida, 502 si la renovación falla).

## Cliente HTTP

`_request` (`google_platform_service.py:17`) usa `httpx` con timeout de 30 s y convierte errores: los estados 400, 401, 403, 404 y 429 se mantienen; el resto pasa a 502, con el mensaje de error de Google cuando existe. `_list` (`:34`) pagina con `pageSize=200` y `nextPageToken` hasta terminar.

## GTM

| Función | Línea | Hace |
|---|---|---|
| `list_gtm_accounts` | 48 | Cuentas (`path`, `name`) |
| `list_gtm_containers` | 53 | Containers de una cuenta (valida `account_id` numérico); devuelve `public_id`, `usage_context` |
| `list_gtm_versions` | 69 | `version_headers` ordenados de la versión más nueva a la más antigua |
| `analyze_gtm_container_version` | 88 | Descarga la versión y ejecuta la auditoría |

`analyze_gtm_container_version` valida la ruta con `accounts/<n>/containers/<n>/versions/<n>`, busca la versión y llama a `process_single_container({"containerVersion": version}, file_name="<publicId> v<versão> (GTM API)")`. Ese es **el mismo pipeline de la carga de JSON**: `process_single_container` (`backend/services/audit_service.py:5`) llama a `analyze_gtm_json` (`backend/analyze_gtm_json.py:6`), que elige el auditor y agrega `source_json_file` a cada ítem. Si el resultado trae `error`, la API responde 422.

### Clasificación del tipo de container

`analyze_gtm_json` lee `usageContext` del container (`analyze_gtm_json.py:21`):

| Contexto | Tipo interno | Auditor | `gtm_container_type` en el payload |
|---|---|---|---|
| contiene `SERVER` | server | `backend/audits/audit_server_container.py` | `server` |
| contiene `ANDROID_SDK_5` o `IOS_SDK_5` | mobile | `backend/audits/audit_mobile_container.py` | `unknown` |
| demás (predeterminado `WEB`) | web | `backend/audits/audit_web_container.py` | `web` |

### Detección de UPD (container web)

`audit_web_container` (`audit_web_container.py:58`) trata como variable UPD toda variable de tipo `awec` (User-Provided Data); el método viene del parámetro `mode` (`automatic`, `manual`, `partial`, `not_configured` o `unknown`). Después vincula tags (`awct`, `flc`, `fls`, `gaawc`, `gaawe`, `awud`, ignorando las pausadas) a la variable de dos formas: parámetro `user_data` en `eventSettingsTable`/`configSettingsTable` de la propia tag, o mediante variables de configuración/eventos (`gtes`, `gtcs`). El estado de cada tag (`upd_configuration_status`) sigue `correct`, `incomplete: missing email`, `incomplete: missing phone_number`, `incomplete: missing email and phone_number`, `incorrect` o `not_configured`; la verificación de `email` y `phone_number` se hace en las claves declaradas dentro de la variable (`:47`). El mismo auditor extrae IDs `G-...` y `AW-...` de las tags activas (resolviendo variables Constant) y los devuelve como `platform_accounts`. Los valores de estado son parte del contrato descrito en [Contrato de estado UPD](../referencia/contrato-status-upd.md).

Los containers server y mobile usan heurísticas más simples: las variables de `event_data` (server) o de SDK (mobile) cuentan como UPD y la tag queda `correct` si referencia una de ellas.

### Persistencia

`POST /api/gtm/analyze-live` guarda la ejecución (`source="live"`) y registra cuenta y container en `google_accounts` del proyecto, solo si llegaron `project_id` y `report_id` (`backend/routers/google_platforms.py:89`). El resultado se combina en el payload con la fuente `gtm_api` (ver [Payload v3](../geracao-do-documento/payload-v3.md)).

## GA4

- `list_ga4_properties` (`google_platform_service.py:102`): `accountSummaries` de la Admin API, aplanado en propiedades con el nombre de la cuenta.
- `analyze_ga4_property` (`:118`): valida `properties/<n>`, aplica las mismas reglas de fecha (fin = ayer, inicio = 29 días antes, intervalo máximo de 366 días inclusivos, 422 si es inválido) usando la fecha local del servidor (UTC en Cloud Run), y consulta la propiedad, `dataStreams`, `keyEvents` y un `runReport` de Data API con `eventName` x `eventCount`.
- Salida: `platform_accounts` (uno por data stream, con `measurement_id` de web streams; un ítem sin stream si no hay) y `conversion_actions` con un ítem por key event (`conversion_goal: key_event`, `conversion_origin: ga4_event`, conteo y `has_recent_activity` del período).

## Observaciones

- El scope de GA4 es de solo lectura (`analytics.readonly`) y el de GTM también (`tagmanager.readonly`).
- A diferencia de Google Ads, no hay caché en memoria en estos servicios.
- Los auditores tienen pruebas en `backend/tests/test_audit_service.py` y `backend/tests/test_google_platform_service.py`. Ver [Pruebas](../desenvolvimento/testes.md).
