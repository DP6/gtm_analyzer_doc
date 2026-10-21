---
title: "UPD status contract"
description: "Values of upd_configuration_status, how they are computed and where they are consumed."
sidebar_position: 2
---

# UPD status contract

Contract v2.1.0 in `Docs/DS30_UPD_audit_status_contract_v2_1.json`, scope `gtm_web_json`: validates the presence of **email** and **phone** in GTM Web variables of type `awec`.

## Validation rule

- Required keys: `email` and `phone_number` (`REQUIRED_UPD_PARAMETER_KEYS`, `backend/audits/audit_web_container.py:5`).
- The search is recursive over lists and maps, by key, case-insensitive.
- The key counts as configured even with an empty or null `value`.
- No global inheritance is assumed: a tag without an explicit `user_data` is `not_configured`.
- Links considered: `userDataVariable`, `cssProvidedEnhancedConversionValue`, `eventSettingsTable`, `configSettingsTable`, `eventSettingsVariable`, `configSettingsVariable`.

## Values

| Status | Meaning |
|---|---|
| `correct` | Email and phone declared |
| `incomplete: missing email` | Email missing |
| `incomplete: missing phone_number` | Phone missing |
| `incomplete: missing email and phone_number` | Both missing |
| `not_configured` | No linked UPD variable |
| `incorrect` | Reference to a variable that is not a valid UPD |
| `unknown` | Could not be classified |

The computation is in `_upd_configuration_status` (`audit_web_container.py:47`); `incorrect` and `not_configured` come from the same module (only one of the two link conditions satisfied, or neither). The server and mobile auditors emit only `correct` or `not_configured` (`audit_server_container.py:139`, `audit_mobile_container.py:97`). `unknown` appears as the default value when the web audit does not return `Status` (`audit_web_container.py:275`).

## Where it is used

| Location | Use |
|---|---|
| `backend/services/payload_helpers.py:52` (`_gtm_upd_signal`) | Considers a tag "configured" when its status starts with `correct` or `incomplete` (`_CONFIGURED_STATUS_PREFIXES`) to derive the GA4 and Google Ads UPD signals |
| `Docs/ds30_appscript/ReportSections.js` (`renderContainers`) | Translates the status into a label in the document's tag table |
| `backend/doc_generator.py:156` | Same translation for the local `.docx` generator; `{{upd_tag_status}}` is filled from `upd_configuration_status` |
| `backend/services/considerations_service.py:38` | The Gemini prompt explains each value and instructs not to confuse it with `gtm_tag_status` (operational status) |

## Attention: outdated `report_target`

The contract declares `canonical_target: gtm_tags[].upd_configuration_status` (live field) and `report_target: upd_tags[].upd_tag_status`. The report target is **outdated**: the current flow reads `gtm_tags[].upd_configuration_status`. `upd_tag_status`, in turn, only exists as a scalar field of the ObservePoint payload, filled with `gtm_tag_status` (operational status, not UPD) (`backend/services/observepoint_service.py:904`). Do not use `upd_tags[]` as a source.

See also [Payload v3](../geracao-do-documento/payload-v3.md) and [Google Tag Manager and GA4](../integracoes/google-tag-manager-e-ga4.md).
