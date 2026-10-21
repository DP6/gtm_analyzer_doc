---
title: "Firebase (Firestore)"
description: "Como o backend usa o Firestore para projetos, relatórios e execuções, credenciais (ADC), banco nomeado e permissões necessárias."
sidebar_position: 6
---

# Firebase (Firestore)

O Firestore guarda projetos, relatórios e o histórico de execuções. Só o backend o acessa, via Admin SDK (`firebase-admin`); não há Firestore Rules nem acesso direto do frontend. Código: `backend/services/firestore_service.py`.

## Conexão e credenciais

- `_ensure_app` (`firestore_service.py:25`) chama `firebase_admin.initialize_app()` sem argumentos, ou seja, usa **Application Default Credentials (ADC)**: em desenvolvimento, `gcloud auth application-default login`; no Cloud Run, a service account do serviço. Não há arquivo de chave no código.
- `client()` (`:32`) abre o banco **nomeado `gtm-analyzer`** (`firestore.client(database_id="gtm-analyzer")`), não o `(default)`.

## Modelo de dados

| Caminho | Conteúdo |
|---|---|
| `users/{email}` | Espelho do perfil (`ensure_user`, `:73`) |
| `projects/{id}` | Dono (`owner_email`), `member_emails`, dados do cliente, logo, `google_accounts`, `last_report_at` |
| `projects/{id}/reports/{id}` | Status (`draft` ou `generated`), documento gerado, snapshot da última análise Google Ads |
| `projects/{id}/reports/{id}/runs/{id}` | Execução imutável: `source`, `payload`, `triggered_by`, `created_at`, e `document_id`/`document_url` quando houve geração |

`projects` é coleção de topo para permitir compartilhamento entre usuários. O acesso é imposto no código (`has_access`, `is_owner`, `:65`), não por Firestore. O dicionário completo está em [Dicionário de dados](../referencia/dicionario-de-dados.md) e as rotas em [API projetos](../api/projects.md).

`save_run` (`:87`) confere acesso, adiciona o run, atualiza o relatório e o projeto e, quando `source == "report"`, marca o relatório como `generated`. `save_run_safe` (`:116`) engole exceções para que histórico nunca derrube a operação principal (usado após upload, análise ao vivo, crawler e geração do documento; ver [Fluxo de geração](../geracao-do-documento/fluxo-de-geracao.md)).

## Permissões

- **Cloud Run.** A service account do serviço precisa de permissão de dados do Firestore. Segundo o levantamento em `Docs/firebase_gcp_permissions.md`, as duas implantações usam a service account padrão do Compute Engine com `roles/editor`, que já cobre Firestore. Se um dia essa conta for restringida, acrescente `roles/datastore.user` explicitamente, senão o app falha ao salvar runs e projetos. Isso foi levantado em uma data passada e não foi reconferido agora: confirme com `gcloud` antes de depender dele.
- **Desenvolvedor local.** Precisa de um papel `datastore.*` (o levantamento recomenda `roles/datastore.owner`, concedido por quem administra o IAM do projeto) e do ADC configurado. Ver [Primeiros passos](../desenvolvimento/primeiros-passos.md).
- Mudanças de IAM em produção são ação humana.

## Redirect do OAuth

O `GOOGLE_ADS_OAUTH_REDIRECT_URI` deve ser a rota fixa de callback do backend (`/api/google-ads/oauth/callback`), cadastrada no cliente OAuth no console do GCP. O destino final do usuário (`return_to`, por exemplo `/projects/<id>/reports/<id>?tab=...`) viaja no `state` assinado, não é redirect URI, então mudar a tela de retorno não exige alterar o GCP. Só confira que o valor da variável em cada ambiente é idêntico ao cadastrado. Detalhes do fluxo em [Google OAuth](./google-oauth.md).

## Documentos de apoio: o que está defasado

- `Docs/firebase_setup_runbook.md` fala em "branch `feat/firebase-persistence`, staged, não commitado" e em um passo opcional para trocar para um banco nomeado, dizendo que isso exigiria alterar o código para `firestore.client(database_id="gtm-analyzer")`. Essa alteração **já está no código**; os verbos no futuro e o estado de branch do runbook são históricos.
- `Docs/firebase_gcp_permissions.md` descreve achados de 2026-09-15 (modo do banco `(default)` em aberto, papéis de pessoas específicas). Trate como fotografia de uma data, não como estado atual. A pergunta sobre compartilhar o `(default)` perdeu relevância porque o app usa o banco nomeado.
- O passo 5 do runbook (roteiro manual de teste: projeto, compartilhamento, relatórios, retomada, exclusão) segue útil como checklist de validação.
- Os dois documentos listam uma falha pré-existente em `frontend/src/utils/appsScript.test.js`; não verificada aqui.

## Não verificado

- Se o banco `gtm-analyzer` existe, em qual região e em qual modo, nos projetos de dev e prod: só `gcloud firestore databases list` confirma.
- Índices compostos necessários: o código não declara; o Firestore os pede em tempo de execução.
