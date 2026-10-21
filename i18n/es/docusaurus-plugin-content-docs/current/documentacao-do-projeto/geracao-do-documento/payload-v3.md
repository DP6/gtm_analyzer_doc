---
title: "Payload v3"
description: "Estructura del payload consolidado (schema 3.0.0), cómo lo arma el frontend, las decisiones derivadas y las fuentes que lo alimentan."
sidebar_position: 2
---

# Payload v3

El payload es el contrato único entre backend, frontend y Apps Script. El ejemplo de referencia es `Docs/DS30_Diagnostico_Tecnico_payload_example_v3.json` (`schema_version` `3.0.0`). Todos los campos del ejemplo son `null` o listas vacías, excepto el bloque `cdns` de demostración. El diccionario campo por campo está en [Diccionario de datos](../referencia/dicionario-de-dados.md).

## Estructura

| Grupo | Campos | Observación |
|---|---|---|
| Metadatos | `_meta`, `schema_version`, `document_version`, `audit_run_id`, `project_id`, `snapshot_date` | `_meta` solo existe en el ejemplo (`example_only`) |
| Documento | `document_owner_email`, `document_month`, `document_year` | El backend sobrescribe los tres en la generación (ver [Flujo](./fluxo-de-geracao.md)) |
| Cliente | `client_name`, `business_unit`, `client_url`, `client_tag_manager`, `client_cookie_manager`, `client_paas`, `client_server`, `client_reverse_proxy`, `client_logo`, `project_description`, `analyzed_domains_urls` | `analyzed_domains_urls` se deriva de `analyzed_urls` (abajo) |
| CDN | `cdn_analysis_status`, `cdns[]` | Cada CDN trae `cdn_name`, `roles`, `pages`, `hosts`, `confidence_status`, `detection_methods`, `evidence[]` |
| GTG / GTM | `tms_name`, `gtg_*`, `server_side_gtm_*`, `client_side_gtm_container_id/name`, `gtm_general_considerations` | Pares valor + `*_decision` |
| UPD | `upd_gtm_container_*`, `upd_variables_identified`, `ga_upd_*` | Ídem |
| Enhanced Conversions | `google_ads_ec_*`, `google_ads_gtag_upd_capability*`, `google_ads_conversion_origin*` | Ídem |
| OCI / ECL | `oci_*`, `ecl_enabled*` | Señales en `oci_gclid_signal`, `oci_email_signal`, `oci_phone_signal` |
| ECO | `eco_*` | Ídem |
| Consideraciones | `gtg_general_considerations`, `gtm_general_considerations`, `upd_general_considerations`, `ga_upd_considerations`, `google_ads_ec_considerations`, `oci_ecl_considerations`, `eco_considerations` | Texto libre; la sección solo aparece en el documento si está completada |
| Colecciones | `analyzed_urls`, `gtm_containers`, `gtm_observations`, `platform_accounts`, `gtm_variables`, `gtm_tags`, `upd_form_urls`, `conversion_actions`, `matching_signals`, `changelog_entries` | Aceptan cero o más ítems |
| Control | `decision_overrides`, `decision_suggestions`, `field_provenance` | Ver abajo |
| Alcance | `scope` | Opcional |

### Campos `*_decision`

Son frases listas que entran en el texto del documento (por ejemplo "O cliente `{{gtg_implemented_decision}}` o Google Tag Gateway implementado", es decir, "El cliente ... el Google Tag Gateway implementado"). Los valores desconocidos (`não identificado`, `não avaliado`; no identificado, no evaluado) hacen que Apps Script omita el hecho (`addFacts`, `Docs/ds30_appscript/ReportSections.js`). La lista de los 20 campos está en `DECISION_FIELDS` (`frontend/src/utils/payloadHelpers.js:5`).

### Campos de control

- `decision_suggestions`: última derivación automática de todas las decisiones.
- `decision_overrides`: valores elegidos por el usuario; vencen a la sugerencia (`recomputeDecisions`).
- `field_provenance`: fuente del último valor escalar escrito (`user`, `gtm`, `observepoint`, etc.).

### Alcance

```json
{"scope": {"gtg": true, "upd": true,
  "enhanced_conversions": {"enabled": true},
  "offline_conversions": {"enabled": true, "eco": true}}}
```

Ausente o solo con `true` equivale a incluir todo. Solo `false` explícito desactiva una sección; desactivar `offline_conversions.enabled` desactiva también ECO (`resolveScope`, `Docs/ds30_appscript/ReportSections.js:120`).

## Cómo el frontend arma el payload

Todo en `frontend/src/utils/payloadHelpers.js`:

| Función | Línea | Papel |
|---|---|---|
| `createEmptyPayload` | 17 | Payload vacío con ids nuevos, `snapshot_date` actual y decisiones calculadas |
| `recomputeDecisions` | 130 | Elige el container web como `client_side_gtm_container_*` (salvo que lo haya editado el usuario), deriva `analyzed_domains_urls` de `analyzed_urls`, calcula sugerencias y aplica `decision_overrides` |
| `mergePayload` | 201 | Combina un resultado de análisis: los escalares sobrescriben y registran `field_provenance`; las listas pasan por `mergeCollection`; después recalcula las decisiones |
| `updatePayloadField`, `setDecisionOverride`, `restoreAutomaticDecision` | 212 a 220 | Edición manual, override y regreso a lo automático |
| `updatePayloadList`, `addPayloadListItem`, `removePayloadListItem` | 226 a 236 | Edición de colecciones; los ítems editados ganan `_data_source: 'user'` y `_user_modified` |
| `getSectionToggles`, `withSectionToggle` | 261, 266 | Checkboxes de sección para `scope` |

`mergeCollection` (línea 171) identifica ítems por clave de negocio (`identity`, línea 147: por ejemplo `source_json_file` + `gtm_container_id` para containers). Los ítems de una fuente se reemplazan cuando esa fuente se vuelve a ejecutar; los ítems editados por el usuario se preservan; los campos vacíos se completan con la otra fuente. Cada ítem guarda `_data_source` y `_data_sources`.

El gemelo en el backend es `derive_decision_fields` (`backend/services/payload_helpers.py:80`), usado al armar el payload del crawler (`backend/services/observepoint_service.py:906`) junto con `create_initial_payload` (`payload_helpers.py:232`). La lógica existe dos veces (JS y Python): al cambiar una regla de decisión, modifique las dos y ejecute las pruebas de ambos extremos. Ver [Pruebas](../desenvolvimento/testes.md).

## Fuentes que alimentan el payload

| Fuente | Origen en el frontend (`ReportWorkspace.jsx`) | Alimenta |
|---|---|---|
| JSON de container GTM (carga) | `mergePayload(..., 'gtm')` | `gtm_containers`, `gtm_variables`, `gtm_tags`, `platform_accounts` |
| API GTM / GA4 | `'gtm_api'`, `'ga4_api'` | Ídem, más cuentas GA4 |
| ObservePoint (crawler) | `'observepoint'` | `analyzed_urls`, `cdns`, `gtm_observations`, containers y cuentas observados |
| Google Ads | `'google_ads'` | `platform_accounts`, `conversion_actions`, `matching_signals` |
| Transcripciones (IA) | `'ai_transcript'` | Escalares y consideraciones |
| Usuario | `'user'` | Cualquier campo |

Vea [Google Tag Manager y GA4](../integracoes/google-tag-manager-e-ga4.md), [ObservePoint](../integracoes/observepoint.md), [Google Ads](../integracoes/google-ads.md) e [IA y Gemini](../integracoes/ia-gemini.md).

## `source_json_file`: ejemplo versus uso real

El ejemplo v3 no lista `source_json_file`, pero existe en la práctica. `process_single_container` (`backend/services/audit_service.py:16`) lo escribe en containers, cuentas, variables y tags para que dos exports del mismo container sigan siendo distintos. El frontend lo usa en la identidad de combinación (`payloadHelpers.js:158`) y Apps Script lo usa para vincular variables y tags al container correcto (`buildContainerSections`, `Docs/ds30_appscript/ReportSections.js:304`); sin él, el ítem cae en la sección "Origem não identificada" (Origen no identificado). Trátelo como un campo opcional con función de vinculación, ausente cuando los datos vienen de API o crawler.
