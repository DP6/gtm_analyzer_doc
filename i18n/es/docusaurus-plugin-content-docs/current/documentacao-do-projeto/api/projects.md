---
title: "Router Projects"
description: "CRUD de proyectos, miembros, informes y ejecuciones (runs) en Firestore, con reglas de acceso."
sidebar_position: 4
---

# Router Projects

Prefijo `/api/projects`, todas las rutas autenticadas. Router: `backend/routers/projects.py`; persistencia: `backend/services/firestore_service.py`. Cada ruta ejecuta el código de Firestore (bloqueante) dentro de `run_in_threadpool`. Modelo de datos en [Diccionario de datos](../referencia/dicionario-de-dados.md) y [Firebase](../integracoes/firebase.md).

## Rutas

Acceso: **miembro** = dueño o miembro; **dueño** = solo `owner_email`.

| Método | Ruta | Acceso | Entrada | Respuesta | Errores |
|---|---|---|---|---|---|
| POST | `/api/projects` (`:85`) | autenticado | `ProjectFields`: `client_name`, `project_name?`, `description?`, `project_metadata?`, `logo_base64?` (máx. 5 MB) | proyecto creado | 422 |
| GET | `/api/projects` (`:104`) | autenticado | n/d | lista (propios + compartidos), más recientes primero | n/d |
| GET | `/api/projects/{project_id}` (`:118`) | miembro | n/d | proyecto + `is_owner` | 404 |
| PUT | `/api/projects/{project_id}` (`:128`) | dueño | `ProjectUpdate` (campos opcionales, merge) | proyecto | 403, 404 |
| DELETE | `/api/projects/{project_id}` (`:141`) | dueño | n/d | `{"deleted":true}` | 403, 404 |
| POST | `/api/projects/{project_id}/members` (`:151`) | dueño | `{"email"}` | proyecto | 403, 404 |
| DELETE | `/api/projects/{project_id}/members/{email}` (`:167`) | dueño | n/d | proyecto | 403, 404 |
| GET | `/api/projects/{project_id}/reports` (`:181`) | miembro | n/d | informes por `updated_at` desc | 404 |
| POST | `/api/projects/{project_id}/reports` (`:193`) | miembro | `{"report_type":"gtm_analyzer","title?"}` | informe (`status:"draft"`) | 404, 422 |
| GET | `/api/projects/{project_id}/reports/{report_id}` (`:217`) | miembro | n/d | informe | 404 |
| PUT | `/api/projects/{project_id}/reports/{report_id}` (`:226`) | miembro | `{"title?","payload?"}` | informe | 404 |
| DELETE | `/api/projects/{project_id}/reports/{report_id}` (`:240`) | miembro | n/d | `{"deleted":true}` | 404 |
| GET | `/api/projects/{project_id}/reports/{report_id}/runs` (`:251`) | miembro | n/d | runs por `created_at` desc | 404 |
| GET | `/api/projects/{project_id}/reports/{report_id}/runs/{run_id}` (`:264`) | miembro | n/d | run | 404 |

## Reglas de acceso

Helpers en `projects.py:56-83`: `_require_access` (404 si no existe **o** sin acceso), `_require_owner` (403 `Apenas o dono do projeto pode fazer isso.`, es decir, solo el dueño del proyecto puede hacer esto) y `_require_report` (404 `Relatório não encontrado.`, informe no encontrado). `has_access` e `is_owner` vienen de `firestore_service.py:65-69`.

## Detalles de implementación

- **Crear**: llama a `ensure_user`, completa `owner_email`, `member_emails=[]`, `google_accounts={}`, `created_at`/`updated_at` y `last_report_at=None` (`projects.py:87-99`).
- **Listar**: dos consultas (`owner_email == email` y `member_emails array_contains email`), combinadas por id (`:107-113`).
- **`_serialize`** (`:46`): inyecta `id`, hace fallback de `project_name` a `client_name` en proyectos antiguos y normaliza `google_accounts` a `{}` si no es un dict.
- **Miembros**: `ArrayUnion`/`ArrayRemove`. Agregar al propio dueño es no-op (`:155`). El correo no se valida ni se normaliza.
- **Informes**: solo `report_type == "gtm_analyzer"` (`ALLOWED_REPORT_TYPES`, `:13`). Título predeterminado `Relatório dd/mm/aaaa`.
- **Runs** son creados por los otros routers mediante `save_run`, nunca por esta API (aquí solo lectura). `save_run` también actualiza `updated_at` del informe y `last_report_at` del proyecto (`firestore_service.py:87-113`).
- **Eliminación** en cascada: `delete_project` / `delete_report` (`firestore_service.py:166-173`).

## Ejemplo

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

## Puntos de atención

- Sin acceso = 404, nunca 403, para no filtrar la existencia (ver [Visión general](./visao-geral-da-api.md)).
- `PUT` usa `model_dump(exclude_unset=True)` con `merge=True`: enviar `null` explícito borra el campo; omitirlo lo mantiene.
- `PUT` de informe usa `set(..., merge=True)`: los mapas anidados como `payload` se combinan por clave, no se reemplazan (semántica de Firestore; no cubierta por pruebas).
- `remove_member` no verifica si el correo estaba en la lista y no impide eliminar al dueño.
- `logo_base64` de hasta 5 MB viaja en el JSON; Apps Script lo valida de nuevo (PNG/JPEG/GIF).
