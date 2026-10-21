---
title: "Dicionário de dados"
description: "Coleções e campos do Firestore usados pelo DS30."
sidebar_position: 1
---

# Dicionário de dados

Fonte: `backend/services/firestore_service.py` e `backend/routers/projects.py`. Banco Firestore `gtm-analyzer`, acessado somente pelo backend (Admin SDK).

:::note
`Docs/schema.sql` é uma proposta antiga em PostgreSQL e **não é usada** pelo app. Não a trate como o modelo real.
:::

Datas são `datetime` UTC.

## `users/{email}`

Espelho do perfil, gravado por `ensure_user` na criação de projeto (`firestore_service.py:73`).

| Campo | Tipo | Descrição |
|---|---|---|
| `email` | string | Também é o id do documento |
| `name`, `picture` | string | Do método de login |
| `role` | string | `admin`, `user` ou `viewer` |
| `auth_method` | string | `google`, `email_otp`, `access_token` ou `dev_mode` |
| `last_login_at` | data | Atualizado a cada upsert |
| `created_at` | data | Só na primeira gravação |

## `projects/{id}`

Coleção de topo, para permitir compartilhamento.

| Campo | Tipo | Descrição |
|---|---|---|
| `client_name` | string | Obrigatório |
| `project_name` | string | Opcional; projetos antigos recebem `client_name` na leitura |
| `description` | string | Opcional |
| `project_metadata` | mapa | Livre |
| `logo_base64` | string | Até 5 MB |
| `owner_email` | string | Dono (quem criou) |
| `member_emails` | lista de string | Membros (ArrayUnion/ArrayRemove) |
| `google_accounts` | mapa de listas | Chaves: `ads_customer_ids`, `ga4_property_ids`, `gtm_account_ids`, `gtm_container_ids`, `login_customer_ids`; alimentado por `record_google_accounts` |
| `created_at`, `updated_at` | data | |
| `last_report_at` | data ou null | Atualizado a cada `run` salva |

## `projects/{id}/reports/{id}`

| Campo | Tipo | Descrição |
|---|---|---|
| `report_type` | string | Somente `gtm_analyzer` é aceito |
| `title` | string | Padrão `Relatório dd/mm/aaaa` |
| `status` | string | `draft`; vira `generated` após gerar o documento |
| `payload` | mapa | Payload canônico em edição |
| `document_id`, `document_url` | string ou null | Documento do Google Docs gerado |
| `google_ads_analysis` | mapa | Último resultado da análise Google Ads (sobrescrito a cada execução) |
| `created_by` | string | E-mail |
| `created_at`, `updated_at` | data | |

## `projects/{id}/reports/{rid}/runs/{id}`

Histórico imutável, criado por `save_run`.

| Campo | Tipo | Descrição |
|---|---|---|
| `source` | string | Origem (ex.: `report`; também upload, análise ao vivo e crawler) |
| `payload` | mapa | Snapshot do payload |
| `triggered_by` | string | E-mail |
| `created_at` | data | |
| `document_id`, `document_url` | string | Só quando `source="report"` |

## Regras de integridade

- Excluir relatório ou projeto apaga em cascata as subcoleções (`recursive_delete`).
- `save_run_safe` e `save_google_ads_analysis_safe` nunca interrompem o fluxo principal; erros só são logados.
- Acesso: ver [Autenticação](../visao-geral-e-arquitetura/autenticacao.md). Mais sobre o Firestore em [Firebase](../integracoes/firebase.md).
