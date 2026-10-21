---
title: "Payload v3"
description: "Estrutura do payload consolidado (schema 3.0.0), como o frontend o monta, as decisões derivadas e as fontes que o alimentam."
sidebar_position: 2
---

# Payload v3

O payload é o contrato único entre backend, frontend e Apps Script. O exemplo de referência é `Docs/DS30_Diagnostico_Tecnico_payload_example_v3.json` (`schema_version` `3.0.0`). Todos os campos do exemplo são `null` ou listas vazias, exceto o bloco `cdns` de demonstração. O dicionário campo a campo está em [Dicionário de dados](../referencia/dicionario-de-dados.md).

## Estrutura

| Grupo | Campos | Observação |
|---|---|---|
| Metadados | `_meta`, `schema_version`, `document_version`, `audit_run_id`, `project_id`, `snapshot_date` | `_meta` só existe no exemplo (`example_only`) |
| Documento | `document_owner_email`, `document_month`, `document_year` | O backend sobrescreve os três na geração (ver [Fluxo](./fluxo-de-geracao.md)) |
| Cliente | `client_name`, `business_unit`, `client_url`, `client_tag_manager`, `client_cookie_manager`, `client_paas`, `client_server`, `client_reverse_proxy`, `client_logo`, `project_description`, `analyzed_domains_urls` | `analyzed_domains_urls` é derivado de `analyzed_urls` (abaixo) |
| CDN | `cdn_analysis_status`, `cdns[]` | Cada CDN traz `cdn_name`, `roles`, `pages`, `hosts`, `confidence_status`, `detection_methods`, `evidence[]` |
| GTG / GTM | `tms_name`, `gtg_*`, `server_side_gtm_*`, `client_side_gtm_container_id/name`, `gtm_general_considerations` | Pares valor + `*_decision` |
| UPD | `upd_gtm_container_*`, `upd_variables_identified`, `ga_upd_*` | Idem |
| Enhanced Conversions | `google_ads_ec_*`, `google_ads_gtag_upd_capability*`, `google_ads_conversion_origin*` | Idem |
| OCI / ECL | `oci_*`, `ecl_enabled*` | Sinais em `oci_gclid_signal`, `oci_email_signal`, `oci_phone_signal` |
| ECO | `eco_*` | Idem |
| Considerações | `gtg_general_considerations`, `gtm_general_considerations`, `upd_general_considerations`, `ga_upd_considerations`, `google_ads_ec_considerations`, `oci_ecl_considerations`, `eco_considerations` | Texto livre; a seção só aparece no documento se preenchida |
| Coleções | `analyzed_urls`, `gtm_containers`, `gtm_observations`, `platform_accounts`, `gtm_variables`, `gtm_tags`, `upd_form_urls`, `conversion_actions`, `matching_signals`, `changelog_entries` | Aceitam zero ou mais itens |
| Controle | `decision_overrides`, `decision_suggestions`, `field_provenance` | Ver abaixo |
| Escopo | `scope` | Opcional |

### Campos `*_decision`

São frases prontas que entram no texto do documento (por exemplo "O cliente `{{gtg_implemented_decision}}` o Google Tag Gateway implementado"). Valores desconhecidos (`não identificado`, `não avaliado`) fazem o Apps Script omitir o fato (`addFacts`, `Docs/ds30_appscript/ReportSections.js`). A lista dos 20 campos está em `DECISION_FIELDS` (`frontend/src/utils/payloadHelpers.js:5`).

### Campos de controle

- `decision_suggestions`: última derivação automática de todas as decisões.
- `decision_overrides`: valores escolhidos pelo usuário; vencem a sugestão (`recomputeDecisions`).
- `field_provenance`: fonte do último valor escalar gravado (`user`, `gtm`, `observepoint`, etc.).

### Escopo

```json
{"scope": {"gtg": true, "upd": true,
  "enhanced_conversions": {"enabled": true},
  "offline_conversions": {"enabled": true, "eco": true}}}
```

Ausente ou só com `true` equivale a incluir tudo. Só `false` explícito desliga uma seção; desligar `offline_conversions.enabled` desliga também ECO (`resolveScope`, `Docs/ds30_appscript/ReportSections.js:120`).

## Como o frontend monta o payload

Tudo em `frontend/src/utils/payloadHelpers.js`:

| Função | Linha | Papel |
|---|---|---|
| `createEmptyPayload` | 17 | Payload vazio com ids novos, `snapshot_date` atual e decisões calculadas |
| `recomputeDecisions` | 130 | Escolhe o container web como `client_side_gtm_container_*` (exceto se editado pelo usuário), deriva `analyzed_domains_urls` de `analyzed_urls`, calcula sugestões e aplica `decision_overrides` |
| `mergePayload` | 201 | Mescla um resultado de análise: escalares sobrescrevem e registram `field_provenance`; listas passam por `mergeCollection`; depois recalcula decisões |
| `updatePayloadField`, `setDecisionOverride`, `restoreAutomaticDecision` | 212 a 220 | Edição manual, override e retorno ao automático |
| `updatePayloadList`, `addPayloadListItem`, `removePayloadListItem` | 226 a 236 | Edição de coleções; itens editados ganham `_data_source: 'user'` e `_user_modified` |
| `getSectionToggles`, `withSectionToggle` | 261, 266 | Checkboxes de seção para `scope` |

`mergeCollection` (linha 171) identifica itens por chave de negócio (`identity`, linha 147: por exemplo `source_json_file` + `gtm_container_id` para containers). Itens de uma fonte são substituídos quando essa fonte reexecuta; itens editados pelo usuário são preservados; campos vazios são completados pela outra fonte. Cada item guarda `_data_source` e `_data_sources`.

O gêmeo no backend é `derive_decision_fields` (`backend/services/payload_helpers.py:80`), usado ao montar o payload do crawler (`backend/services/observepoint_service.py:906`) junto com `create_initial_payload` (`payload_helpers.py:232`). A lógica existe duas vezes (JS e Python): ao mudar uma regra de decisão, altere as duas e rode os testes de ambas as pontas. Ver [Testes](../desenvolvimento/testes.md).

## Fontes que alimentam o payload

| Fonte | Origem no frontend (`ReportWorkspace.jsx`) | Alimenta |
|---|---|---|
| JSON de container GTM (upload) | `mergePayload(..., 'gtm')` | `gtm_containers`, `gtm_variables`, `gtm_tags`, `platform_accounts` |
| API GTM / GA4 | `'gtm_api'`, `'ga4_api'` | Idem, mais contas GA4 |
| ObservePoint (crawler) | `'observepoint'` | `analyzed_urls`, `cdns`, `gtm_observations`, containers e contas observados |
| Google Ads | `'google_ads'` | `platform_accounts`, `conversion_actions`, `matching_signals` |
| Transcrições (IA) | `'ai_transcript'` | Escalares e considerações |
| Usuário | `'user'` | Qualquer campo |

Ver [Google Tag Manager e GA4](../integracoes/google-tag-manager-e-ga4.md), [ObservePoint](../integracoes/observepoint.md), [Google Ads](../integracoes/google-ads.md) e [IA e Gemini](../integracoes/ia-gemini.md).

## `source_json_file`: exemplo versus uso real

O exemplo v3 não lista `source_json_file`, mas ele existe na prática. `process_single_container` (`backend/services/audit_service.py:16`) o grava em containers, contas, variáveis e tags para que dois exports do mesmo container continuem distintos. O frontend o usa na identidade de mesclagem (`payloadHelpers.js:158`) e o Apps Script o usa para ligar variáveis e tags ao container certo (`buildContainerSections`, `Docs/ds30_appscript/ReportSections.js:304`); sem ele, o item cai na seção "Origem não identificada". Trate-o como campo opcional com função de ligação, ausente quando os dados vêm de API ou crawler.
