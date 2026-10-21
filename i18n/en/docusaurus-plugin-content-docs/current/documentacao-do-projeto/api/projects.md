---
title: "Projects router"
description: "CRUD for projects, members, reports and runs in Firestore, with access rules."
sidebar_position: 4
---

# Projects router

Prefix `/api/projects`, all routes authenticated. Router: `backend/routers/projects.py`; persistence: `backend/services/firestore_service.py`. Each route runs the (blocking) Firestore code inside `run_in_threadpool`. Data model in [Data dictionary](../referencia/dicionario-de-dados.md) and [Firebase](../integracoes/firebase.md).

## Routes

Access: **member** = owner or member; **owner** = `owner_email` only.

| Method | Path | Access | Input | Response | Errors |
|---|---|---|---|---|---|
| POST | `/api/projects` (`:85`) | authenticated | `ProjectFields`: `client_name`, `project_name?`, `description?`, `project_metadata?`, `logo_base64?` (max 5 MB) | created project | 422 |
| GET | `/api/projects` (`:104`) | authenticated | n/a | list (own + shared), newest first | n/a |
| GET | `/api/projects/{project_id}` (`:118`) | member | n/a | project + `is_owner` | 404 |
| PUT | `/api/projects/{project_id}` (`:128`) | owner | `ProjectUpdate` (optional fields, merge) | project | 403, 404 |
| DELETE | `/api/projects/{project_id}` (`:141`) | owner | n/a | `{"deleted":true}` | 403, 404 |
| POST | `/api/projects/{project_id}/members` (`:151`) | owner | `{"email"}` | project | 403, 404 |
| DELETE | `/api/projects/{project_id}/members/{email}` (`:167`) | owner | n/a | project | 403, 404 |
| GET | `/api/projects/{project_id}/reports` (`:181`) | member | n/a | reports by `updated_at` desc | 404 |
| POST | `/api/projects/{project_id}/reports` (`:193`) | member | `{"report_type":"gtm_analyzer","title?"}` | report (`status:"draft"`) | 404, 422 |
| GET | `/api/projects/{project_id}/reports/{report_id}` (`:217`) | member | n/a | report | 404 |
| PUT | `/api/projects/{project_id}/reports/{report_id}` (`:226`) | member | `{"title?","payload?"}` | report | 404 |
| DELETE | `/api/projects/{project_id}/reports/{report_id}` (`:240`) | member | n/a | `{"deleted":true}` | 404 |
| GET | `/api/projects/{project_id}/reports/{report_id}/runs` (`:251`) | member | n/a | runs by `created_at` desc | 404 |
| GET | `/api/projects/{project_id}/reports/{report_id}/runs/{run_id}` (`:264`) | member | n/a | run | 404 |

## Access rules

Helpers in `projects.py:56-83`: `_require_access` (404 if it does not exist **or** no access), `_require_owner` (403 `Apenas o dono do projeto pode fazer isso.` (Only the project owner can do that.)) and `_require_report` (404 `Relatório não encontrado.` (Report not found.)). `has_access` and `is_owner` come from `firestore_service.py:65-69`.

## Implementation details

- **Create**: calls `ensure_user`, fills `owner_email`, `member_emails=[]`, `google_accounts={}`, `created_at`/`updated_at` and `last_report_at=None` (`projects.py:87-99`).
- **List**: two queries (`owner_email == email` and `member_emails array_contains email`), merged by id (`:107-113`).
- **`_serialize`** (`:46`): injects `id`, falls back `project_name` to `client_name` for old projects and normalizes `google_accounts` to `{}` if it is not a dict.
- **Members**: `ArrayUnion`/`ArrayRemove`. Adding the owner themselves is a no-op (`:155`). The email is neither validated nor normalized.
- **Reports**: only `report_type == "gtm_analyzer"` (`ALLOWED_REPORT_TYPES`, `:13`). Default title `Relatório dd/mm/aaaa` (Report dd/mm/yyyy).
- **Runs** are created by the other routers via `save_run`, never by this API (read-only here). `save_run` also updates the report's `updated_at` and the project's `last_report_at` (`firestore_service.py:87-113`).
- **Deletion** cascades: `delete_project` / `delete_report` (`firestore_service.py:166-173`).

## Example

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

## Caveats

- No access = 404, never 403, so as not to leak existence (see [Overview](./visao-geral-da-api.md)).
- `PUT` uses `model_dump(exclude_unset=True)` with `merge=True`: sending an explicit `null` erases the field; omitting keeps it.
- Report `PUT` uses `set(..., merge=True)`: nested maps such as `payload` are merged by key, not replaced (Firestore semantics; not covered by a test).
- `remove_member` does not check whether the email was in the list and does not block removing the owner.
- `logo_base64` up to 5 MB travels in the JSON; Apps Script validates it again (PNG/JPEG/GIF).
