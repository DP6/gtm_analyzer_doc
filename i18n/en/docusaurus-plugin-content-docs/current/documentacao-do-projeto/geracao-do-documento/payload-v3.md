---
title: "Payload v3"
description: "Structure of the consolidated payload (schema 3.0.0), how the frontend builds it, the derived decisions and the sources that feed it."
sidebar_position: 2
---

# Payload v3

The payload is the single contract between backend, frontend and Apps Script. The reference example is `Docs/DS30_Diagnostico_Tecnico_payload_example_v3.json` (`schema_version` `3.0.0`). All fields in the example are `null` or empty lists, except the demonstration `cdns` block. The field-by-field dictionary is in [Data dictionary](../referencia/dicionario-de-dados.md).

## Structure

| Group | Fields | Note |
|---|---|---|
| Metadata | `_meta`, `schema_version`, `document_version`, `audit_run_id`, `project_id`, `snapshot_date` | `_meta` only exists in the example (`example_only`) |
| Document | `document_owner_email`, `document_month`, `document_year` | The backend overwrites all three at generation (see [Flow](./fluxo-de-geracao.md)) |
| Client | `client_name`, `business_unit`, `client_url`, `client_tag_manager`, `client_cookie_manager`, `client_paas`, `client_server`, `client_reverse_proxy`, `client_logo`, `project_description`, `analyzed_domains_urls` | `analyzed_domains_urls` is derived from `analyzed_urls` (below) |
| CDN | `cdn_analysis_status`, `cdns[]` | Each CDN carries `cdn_name`, `roles`, `pages`, `hosts`, `confidence_status`, `detection_methods`, `evidence[]` |
| GTG / GTM | `tms_name`, `gtg_*`, `server_side_gtm_*`, `client_side_gtm_container_id/name`, `gtm_general_considerations` | Value + `*_decision` pairs |
| UPD | `upd_gtm_container_*`, `upd_variables_identified`, `ga_upd_*` | Same |
| Enhanced Conversions | `google_ads_ec_*`, `google_ads_gtag_upd_capability*`, `google_ads_conversion_origin*` | Same |
| OCI / ECL | `oci_*`, `ecl_enabled*` | Signals in `oci_gclid_signal`, `oci_email_signal`, `oci_phone_signal` |
| ECO | `eco_*` | Same |
| Considerations | `gtg_general_considerations`, `gtm_general_considerations`, `upd_general_considerations`, `ga_upd_considerations`, `google_ads_ec_considerations`, `oci_ecl_considerations`, `eco_considerations` | Free text; the section only appears in the document if filled in |
| Collections | `analyzed_urls`, `gtm_containers`, `gtm_observations`, `platform_accounts`, `gtm_variables`, `gtm_tags`, `upd_form_urls`, `conversion_actions`, `matching_signals`, `changelog_entries` | Accept zero or more items |
| Control | `decision_overrides`, `decision_suggestions`, `field_provenance` | See below |
| Scope | `scope` | Optional |

### `*_decision` fields

These are ready-made phrases that go into the document text (for example "O cliente `{{gtg_implemented_decision}}` o Google Tag Gateway implementado"). Unknown values (`não identificado`, `não avaliado`) make Apps Script omit the fact (`addFacts`, `Docs/ds30_appscript/ReportSections.js`). The list of the 20 fields is in `DECISION_FIELDS` (`frontend/src/utils/payloadHelpers.js:5`).

### Control fields

- `decision_suggestions`: the latest automatic derivation of all decisions.
- `decision_overrides`: values chosen by the user; they win over the suggestion (`recomputeDecisions`).
- `field_provenance`: source of the last scalar value written (`user`, `gtm`, `observepoint`, etc.).

### Scope

```json
{"scope": {"gtg": true, "upd": true,
  "enhanced_conversions": {"enabled": true},
  "offline_conversions": {"enabled": true, "eco": true}}}
```

Absent or with only `true` is equivalent to including everything. Only an explicit `false` turns a section off; turning off `offline_conversions.enabled` also turns off ECO (`resolveScope`, `Docs/ds30_appscript/ReportSections.js:120`).

## How the frontend builds the payload

All in `frontend/src/utils/payloadHelpers.js`:

| Function | Line | Role |
|---|---|---|
| `createEmptyPayload` | 17 | Empty payload with new ids, current `snapshot_date` and computed decisions |
| `recomputeDecisions` | 130 | Picks the web container as `client_side_gtm_container_*` (unless edited by the user), derives `analyzed_domains_urls` from `analyzed_urls`, computes suggestions and applies `decision_overrides` |
| `mergePayload` | 201 | Merges an analysis result: scalars overwrite and record `field_provenance`; lists go through `mergeCollection`; then recomputes decisions |
| `updatePayloadField`, `setDecisionOverride`, `restoreAutomaticDecision` | 212 to 220 | Manual editing, override and return to automatic |
| `updatePayloadList`, `addPayloadListItem`, `removePayloadListItem` | 226 to 236 | Collection editing; edited items get `_data_source: 'user'` and `_user_modified` |
| `getSectionToggles`, `withSectionToggle` | 261, 266 | Section checkboxes for `scope` |

`mergeCollection` (line 171) identifies items by a business key (`identity`, line 147: for example `source_json_file` + `gtm_container_id` for containers). Items from a source are replaced when that source re-runs; items edited by the user are preserved; empty fields are filled in by the other source. Each item keeps `_data_source` and `_data_sources`.

The backend twin is `derive_decision_fields` (`backend/services/payload_helpers.py:80`), used when building the crawler payload (`backend/services/observepoint_service.py:906`) together with `create_initial_payload` (`payload_helpers.py:232`). The logic exists twice (JS and Python): when changing a decision rule, change both and run the tests on both ends. See [Tests](../desenvolvimento/testes.md).

## Sources that feed the payload

| Source | Origin in the frontend (`ReportWorkspace.jsx`) | Feeds |
|---|---|---|
| GTM container JSON (upload) | `mergePayload(..., 'gtm')` | `gtm_containers`, `gtm_variables`, `gtm_tags`, `platform_accounts` |
| GTM / GA4 API | `'gtm_api'`, `'ga4_api'` | Same, plus GA4 accounts |
| ObservePoint (crawler) | `'observepoint'` | `analyzed_urls`, `cdns`, `gtm_observations`, observed containers and accounts |
| Google Ads | `'google_ads'` | `platform_accounts`, `conversion_actions`, `matching_signals` |
| Transcripts (AI) | `'ai_transcript'` | Scalars and considerations |
| User | `'user'` | Any field |

See [Google Tag Manager and GA4](../integracoes/google-tag-manager-e-ga4.md), [ObservePoint](../integracoes/observepoint.md), [Google Ads](../integracoes/google-ads.md) and [AI and Gemini](../integracoes/ia-gemini.md).

## `source_json_file`: example versus real use

The v3 example does not list `source_json_file`, but it exists in practice. `process_single_container` (`backend/services/audit_service.py:16`) writes it on containers, accounts, variables and tags so that two exports of the same container remain distinct. The frontend uses it in the merge identity (`payloadHelpers.js:158`) and Apps Script uses it to link variables and tags to the right container (`buildContainerSections`, `Docs/ds30_appscript/ReportSections.js:304`); without it, the item falls into the "Origem não identificada" (Unidentified origin) section. Treat it as an optional field with a linking role, absent when the data comes from the API or crawler.
