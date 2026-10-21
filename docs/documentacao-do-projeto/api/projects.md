---
title: "Router Projects"
description: "CRUD de projetos, membros, relatórios e execuções (runs) no Firestore, com regras de acesso."
sidebar_position: 4
---

# Router Projects

Prefixo `/api/projects`, todas as rotas autenticadas. Router: `backend/routers/projects.py`; persistência: `backend/services/firestore_service.py`. Cada rota roda o código Firestore (bloqueante) dentro de `run_in_threadpool`. Modelo de dados em [Dicionário de dados](../referencia/dicionario-de-dados.md) e [Firebase](../integracoes/firebase.md).

## Rotas

Acesso: **membro** = dono ou membro; **dono** = só `owner_email`.

| Método | Caminho | Acesso | Entrada | Resposta | Erros |
|---|---|---|---|---|---|
| POST | `/api/projects` (`:85`) | autenticado | `ProjectFields`: `client_name`, `project_name?`, `description?`, `project_metadata?`, `logo_base64?` (máx. 5 MB) | projeto criado | 422 |
| GET | `/api/projects` (`:104`) | autenticado | n/d | lista (próprios + compartilhados), mais recentes primeiro | n/d |
| GET | `/api/projects/{project_id}` (`:118`) | membro | n/d | projeto + `is_owner` | 404 |
| PUT | `/api/projects/{project_id}` (`:128`) | dono | `ProjectUpdate` (campos opcionais, merge) | projeto | 403, 404 |
| DELETE | `/api/projects/{project_id}` (`:141`) | dono | n/d | `{"deleted":true}` | 403, 404 |
| POST | `/api/projects/{project_id}/members` (`:151`) | dono | `{"email"}` | projeto | 403, 404 |
| DELETE | `/api/projects/{project_id}/members/{email}` (`:167`) | dono | n/d | projeto | 403, 404 |
| GET | `/api/projects/{project_id}/reports` (`:181`) | membro | n/d | relatórios por `updated_at` desc | 404 |
| POST | `/api/projects/{project_id}/reports` (`:193`) | membro | `{"report_type":"gtm_analyzer","title?"}` | relatório (`status:"draft"`) | 404, 422 |
| GET | `/api/projects/{project_id}/reports/{report_id}` (`:217`) | membro | n/d | relatório | 404 |
| PUT | `/api/projects/{project_id}/reports/{report_id}` (`:226`) | membro | `{"title?","payload?"}` | relatório | 404 |
| DELETE | `/api/projects/{project_id}/reports/{report_id}` (`:240`) | membro | n/d | `{"deleted":true}` | 404 |
| GET | `/api/projects/{project_id}/reports/{report_id}/runs` (`:251`) | membro | n/d | runs por `created_at` desc | 404 |
| GET | `/api/projects/{project_id}/reports/{report_id}/runs/{run_id}` (`:264`) | membro | n/d | run | 404 |

## Regras de acesso

Helpers em `projects.py:56-83`: `_require_access` (404 se não existe **ou** sem acesso), `_require_owner` (403 `Apenas o dono do projeto pode fazer isso.`) e `_require_report` (404 `Relatório não encontrado.`). `has_access` e `is_owner` vêm de `firestore_service.py:65-69`.

## Detalhes de implementação

- **Criar**: chama `ensure_user`, preenche `owner_email`, `member_emails=[]`, `google_accounts={}`, `created_at`/`updated_at` e `last_report_at=None` (`projects.py:87-99`).
- **Listar**: duas consultas (`owner_email == email` e `member_emails array_contains email`), mescladas por id (`:107-113`).
- **`_serialize`** (`:46`): injeta `id`, faz fallback de `project_name` para `client_name` em projetos antigos e normaliza `google_accounts` para `{}` se não for dict.
- **Membros**: `ArrayUnion`/`ArrayRemove`. Adicionar o próprio dono é no-op (`:155`). O e-mail não é validado nem normalizado.
- **Relatórios**: só `report_type == "gtm_analyzer"` (`ALLOWED_REPORT_TYPES`, `:13`). Título padrão `Relatório dd/mm/aaaa`.
- **Runs** são criados pelos outros routers via `save_run`, nunca por esta API (somente leitura aqui). `save_run` também atualiza `updated_at` do relatório e `last_report_at` do projeto (`firestore_service.py:87-113`).
- **Exclusão** em cascata: `delete_project` / `delete_report` (`firestore_service.py:166-173`).

## Exemplo

```bash
curl -X POST http://localhost:8000/api/projects \
  -H "Authorization: Bearer <id_token>" -H "Content-Type: application/json" \
  -d '{"client_name":"Cliente Exemplo","project_name":"Auditoria 2026"}'
# {"id":"<project_id>","client_name":"Cliente Exemplo","owner_email":"voce@exemplo.com",
#  "member_emails":[],"google_accounts":{},"last_report_at":null,...}

curl -X POST http://localhost:8000/api/projects/<project_id>/reports \
  -H "Authorization: Bearer <id_token>" -H "Content-Type: application/json" \
  -d '{"title":"Relatório inicial"}'
```

## Pontos de atenção

- Sem acesso = 404, nunca 403, para não vazar existência (ver [Visão geral](./visao-geral-da-api.md)).
- `PUT` usa `model_dump(exclude_unset=True)` com `merge=True`: enviar `null` explícito apaga o campo; omitir mantém.
- `PUT` de relatório usa `set(..., merge=True)`: mapas aninhados como `payload` são mesclados por chave, não substituídos (semântica do Firestore; não coberta por teste).
- `remove_member` não checa se o e-mail estava na lista e não bloqueia remover o dono.
- `logo_base64` até 5 MB trafega no JSON; o Apps Script valida de novo (PNG/JPEG/GIF).
