---
title: "Contrato de estado UPD"
description: "Valores de upd_configuration_status, cómo se calculan y dónde se consumen."
sidebar_position: 2
---

# Contrato de estado UPD

Contrato v2.1.0 en `Docs/DS30_UPD_audit_status_contract_v2_1.json`, alcance `gtm_web_json`: valida la presencia de **correo** y **teléfono** en las variables GTM Web de tipo `awec`.

## Regla de validación

- Claves obligatorias: `email` y `phone_number` (`REQUIRED_UPD_PARAMETER_KEYS`, `backend/audits/audit_web_container.py:5`).
- La búsqueda es recursiva en listas y mapas, por clave, sin distinguir mayúsculas.
- La clave cuenta como configurada incluso con `value` vacío o nulo.
- No se presume herencia global: una tag sin `user_data` explícito es `not_configured`.
- Vínculos considerados: `userDataVariable`, `cssProvidedEnhancedConversionValue`, `eventSettingsTable`, `configSettingsTable`, `eventSettingsVariable`, `configSettingsVariable`.

## Valores

| Estado | Significado |
|---|---|
| `correct` | Correo y teléfono declarados |
| `incomplete: missing email` | Falta el correo |
| `incomplete: missing phone_number` | Falta el teléfono |
| `incomplete: missing email and phone_number` | Faltan ambos |
| `not_configured` | Sin variable UPD vinculada |
| `incorrect` | Referencia a una variable que no es UPD válida |
| `unknown` | No fue posible clasificar |

El cálculo está en `_upd_configuration_status` (`audit_web_container.py:47`); `incorrect` y `not_configured` vienen del mismo módulo (solo una de las dos condiciones de vínculo satisfecha, o ninguna). Los auditores server y mobile emiten solo `correct` o `not_configured` (`audit_server_container.py:139`, `audit_mobile_container.py:97`). `unknown` aparece como valor predeterminado cuando la auditoría web no devuelve `Status` (`audit_web_container.py:275`).

## Dónde se usa

| Lugar | Uso |
|---|---|
| `backend/services/payload_helpers.py:52` (`_gtm_upd_signal`) | Considera "configurada" la tag cuyo estado empieza con `correct` o `incomplete` (`_CONFIGURED_STATUS_PREFIXES`) para derivar las señales de UPD de GA4 y Google Ads |
| `Docs/ds30_appscript/ReportSections.js` (`renderContainers`) | Traduce el estado a una etiqueta en la tabla de tags del documento |
| `backend/doc_generator.py:156` | Misma traducción para el generador `.docx` local; `{{upd_tag_status}}` se completa a partir de `upd_configuration_status` |
| `backend/services/considerations_service.py:38` | El prompt de Gemini explica cada valor y orienta a no confundirlo con `gtm_tag_status` (estado operativo) |

## Atención: `report_target` desactualizado

El contrato declara `canonical_target: gtm_tags[].upd_configuration_status` (campo vivo) y `report_target: upd_tags[].upd_tag_status`. El destino de informe está **desfasado**: el flujo actual lee `gtm_tags[].upd_configuration_status`. En cambio, `upd_tag_status` solo existe como campo escalar del payload de ObservePoint, completado con `gtm_tag_status` (estado operativo, no de UPD) (`backend/services/observepoint_service.py:904`). No use `upd_tags[]` como fuente.

Vea también [Payload v3](../geracao-do-documento/payload-v3.md) y [Google Tag Manager y GA4](../integracoes/google-tag-manager-e-ga4.md).
