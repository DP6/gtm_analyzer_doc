---
title: "Google Ads"
description: "Análisis de cuentas de Google Ads por la API (GAQL), fan-out de cuentas MCC, caché de cuentas y el camino alternativo por CSV."
sidebar_position: 2
---

# Google Ads

Dos caminos producen el mismo formato de acción de conversión y pasan por la misma regla de inclusión (`finalize_report_inclusion`, `backend/services/google_ads_service.py:7`):

| Camino | Entrada | Código |
|---|---|---|
| En vivo | Conexión OAuth del usuario ([Google OAuth](./google-oauth.md)) | `backend/services/google_ads_api_service.py` |
| CSV | Exports de Google Ads enviados por carga | `backend/services/google_ads_service.py:212` (`analyze_google_ads_csvs`) |

Rutas en `backend/routers/google_ads.py`: `GET /accounts`, `POST /analyze-live`, `POST /analyze` (CSV). Ver [API Google Ads](../api/google-ads.md).

## Cliente y consultas

- `_client` (`google_ads_api_service.py:35`) arma el `GoogleAdsClient` con el developer token, el cliente OAuth y el refresh token de la cookie. `login_customer_id` se normaliza a 10 dígitos (`normalize_customer_id`, `:28`).
- `_rows` (`:99`) ejecuta GAQL con `search_stream` y traduce `GoogleAdsException`: permiso denegado o cuenta deshabilitada pasa a 403, cuota a 429, autenticación a 401, el resto 502. El `request_id` de Google acompaña al error (`GoogleAdsApiError`, `:21`).
- Una falla de renovación del token pasa a 401 "Conexão Google Ads expirada ou revogada" (Conexión de Google Ads expirada o revocada) (`:47`).

## Cuentas accesibles y jerarquía de MCC

`list_accessible_accounts` (`:126`):

1. Lista los customers accesibles al usuario (`CustomerService.list_accessible_customers`).
2. Para cada raíz, recorre `customer_client` con `level <= 1` en anchura, apilando los nuevos MCCs encontrados (cada MCC visitado una vez). Las consultas de cada nivel corren en paralelo (hasta 10 threads, `_ACCOUNTS_FETCH_MAX_WORKERS`).
3. Cada cuenta recibe `login_customer_id` (la raíz por la cual se alcanzó; `None` para la propia raíz), `manager`, `level`, `status`, moneda y zona horaria. Los caminos duplicados se descartan.
4. Las fallas por raíz o subcuenta se convierten en `warnings`, sin abortar.

**Caché.** El resultado queda en memoria por 300 s (`_ACCOUNTS_CACHE_TTL_SECONDS`, `:54`), con clave SHA-256 del refresh token (`:60`). Es por instancia: se pierde en el reinicio y no se comparte entre instancias de Cloud Run (el código ya lo marca como `ponytail`).

## `analyze_live_account`

`analyze_live_account` (`:441`) recibe cuenta, `login_customer_id` opcional y período.

**Reglas de fecha** (`:466` a `:473`):

- El "hoy" se calcula en la zona horaria de la propia cuenta (si la zona es inválida, usa la fecha local).
- Sin fechas: `end_date` = ayer, `start_date` = `end_date - 29 días` (30 días completos).
- Error 422 (`ValueError`) si el inicio es mayor que el fin, si `end_date` es hoy o futuro, o si el intervalo pasa de 365 días de diferencia (366 días inclusivos).

**Consultas en secuencia** para una cuenta no MCC: datos de la cuenta (`customer`, incluido `conversion_tracking_setting`; 404 si está vacío), `conversion_action`, métricas por período (`all_conversions` y valor; la ausencia de fila significa volumen cero), `campaign_conversion_goal` (campañas habilitadas), `customer_conversion_goal`, `conversion_goal_campaign_config` (custom goals) y `offline_conversion_upload_client_summary`. Una falla en la última solo genera el aviso `offline_diagnostics_unavailable`.

**Clasificación.** `resolve_optimization` (`:308`) vincula cada acción a `campaign_goal`, `account_goal` y/o `custom_goal`; `_canonical_action` (`:263`) arma el ítem canónico; `_source_fields` (`:211`) define el origen (las acciones `GOOGLE_ANALYTICS_4_*` pasan a `ga4_event` antes de la verificación por `origin`, porque la API no tiene origen GA4). `finalize_report_inclusion` marca `included_in_report` solo si la acción tiene volumen, al menos una fuente de meta, origen `WEBSITE` y es primaria o secundaria con al menos 25% del volumen primario web. `conversion_actions` es el subconjunto incluido; `all_conversion_actions` guarda todas.

**Findings** (`severity`, `code`, `message`): términos de datos no aceptados, ninguna acción de optimización, acciones sin volumen. **Derivados**: `ecl_enabled`, `oci_implemented` (hay cargas offline), `oci_integration_method` (cliente con más eventos), `google_ads_gtag_upd_capability` y `google_ads_ec_eligible_actions_identified` (hay acciones elegibles). Estos campos alimentan el [payload](../geracao-do-documento/payload-v3.md).

## MCC (fan-out)

Si la cuenta es gerente, `_analyze_manager_account` (`:419`) lista los descendientes no gerentes (`_list_descendant_client_ids`, `:337`), analiza cada uno con `analyze_live_account` usando el MCC como `login_customer_id` (en paralelo, hasta 10 threads) y agrega en `_merge_live_account_results` (`:374`): `coverage: "aggregated_mcc"`, `child_account_ids`, findings con prefijo del nombre de la cuenta, `account_tracking` nulo. Las subcuentas que fallan se convierten en `warnings`; 404 si el MCC no tiene clientes accesibles y 502 si ninguna subcuenta pudo consultarse.

## Persistencia

Con `project_id` y `report_id`, la ruta guarda la ejecución (`source="live"`), registra los IDs usados en `google_accounts` del proyecto y guarda el análisis del informe (`backend/routers/google_ads.py:136`), todo en modo best-effort.

## Camino CSV

`analyze_google_ads_csvs` exige el CSV de acciones con las columnas `Account`, `ID`, `Resource_Name`, `Name`, `Status`, `Type`, `Category`, `Origin`, `Primary`, `Conversions`. Acepta opcionalmente el CSV de metas personalizadas (`Custom_Goal_Conversion_Actions`, `Custom_Goal_Status`, `Custom_Goal_Name` opcional) y el de metas estándar (`Biddable`, `Category`, `Origin`). Diferencias respecto al modo en vivo: la fuente de meta estándar es `standard_goal` (no hay equivalente a `customer_conversion_goal`, así que nunca aparece "Account-default goal"), `warnings` y `findings` vienen vacíos, no hay diagnóstico de cargas offline y el error HTTP es siempre 400 (`backend/routers/google_ads.py:190`).

## Sobre `Docs/google_ads_backend_flow.md`

Verificado contra el código: período, fuentes de meta, regla de inclusión y jerarquía de cuentas coinciden. Divergencia: el documento describe el camino CSV como con "la misma lógica" de origen GA4; confirmado en `_derive_origin_and_source`, pero la cobertura CSV es menor (sin findings, sin métricas por período). Nada del estado "implementado/pendiente" en él se usó como hecho.

Relacionados: [Contrato de estado UPD](../referencia/contrato-status-upd.md), [Diccionario de datos](../referencia/dicionario-de-dados.md).
