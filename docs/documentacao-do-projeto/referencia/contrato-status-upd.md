---
title: "Contrato de status UPD"
description: "Valores de upd_configuration_status, como são calculados e onde são consumidos."
sidebar_position: 2
---

# Contrato de status UPD

Contrato v2.1.0 em `Docs/DS30_UPD_audit_status_contract_v2_1.json`, escopo `gtm_web_json`: valida a presença de **e-mail** e **telefone** nas variáveis GTM Web do tipo `awec`.

## Regra de validação

- Chaves obrigatórias: `email` e `phone_number` (`REQUIRED_UPD_PARAMETER_KEYS`, `backend/audits/audit_web_container.py:5`).
- A busca é recursiva em listas e mapas, pela chave, sem diferenciar maiúsculas.
- A chave conta como configurada mesmo com `value` vazio ou nulo.
- Não há herança global presumida: tag sem `user_data` explícito é `not_configured`.
- Vínculos considerados: `userDataVariable`, `cssProvidedEnhancedConversionValue`, `eventSettingsTable`, `configSettingsTable`, `eventSettingsVariable`, `configSettingsVariable`.

## Valores

| Status | Significado |
|---|---|
| `correct` | E-mail e telefone declarados |
| `incomplete: missing email` | Falta e-mail |
| `incomplete: missing phone_number` | Falta telefone |
| `incomplete: missing email and phone_number` | Faltam ambos |
| `not_configured` | Sem variável UPD vinculada |
| `incorrect` | Referência a variável que não é UPD válida |
| `unknown` | Não foi possível classificar |

O cálculo está em `_upd_configuration_status` (`audit_web_container.py:47`); `incorrect` e `not_configured` vêm do mesmo módulo (apenas uma das duas condições de vínculo satisfeita, ou nenhuma). Os auditores server e mobile emitem só `correct` ou `not_configured` (`audit_server_container.py:139`, `audit_mobile_container.py:97`). O `unknown` aparece como valor padrão quando a auditoria web não devolve `Status` (`audit_web_container.py:275`).

## Onde é usado

| Local | Uso |
|---|---|
| `backend/services/payload_helpers.py:52` (`_gtm_upd_signal`) | Considera "configurada" a tag cujo status começa com `correct` ou `incomplete` (`_CONFIGURED_STATUS_PREFIXES`) para derivar os sinais de UPD do GA4 e do Google Ads |
| `Docs/ds30_appscript/ReportSections.js` (`renderContainers`) | Traduz o status em rótulo na tabela de tags do documento |
| `backend/doc_generator.py:156` | Mesma tradução para o gerador `.docx` local; `{{upd_tag_status}}` é preenchido a partir de `upd_configuration_status` |
| `backend/services/considerations_service.py:38` | O prompt do Gemini explica cada valor e orienta a não confundir com `gtm_tag_status` (status operacional) |

## Atenção: `report_target` desatualizado

O contrato declara `canonical_target: gtm_tags[].upd_configuration_status` (campo vivo) e `report_target: upd_tags[].upd_tag_status`. O alvo de relatório está **defasado**: o fluxo atual lê `gtm_tags[].upd_configuration_status`. Já `upd_tag_status` só existe como campo escalar do payload do ObservePoint, preenchido com `gtm_tag_status` (status operacional, não de UPD) (`backend/services/observepoint_service.py:904`). Não use `upd_tags[]` como fonte.

Veja também [Payload v3](../geracao-do-documento/payload-v3.md) e [Google Tag Manager e GA4](../integracoes/google-tag-manager-e-ga4.md).
