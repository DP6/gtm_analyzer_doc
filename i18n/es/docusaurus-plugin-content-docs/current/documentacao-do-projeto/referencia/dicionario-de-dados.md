---
title: "Diccionario de datos"
description: "Colecciones y campos de Firestore usados por DS30."
sidebar_position: 1
---

# Diccionario de datos

Fuente: `backend/services/firestore_service.py` y `backend/routers/projects.py`. Base de datos Firestore `gtm-analyzer`, accedida solo por el backend (Admin SDK).

:::note
`Docs/schema.sql` es una propuesta antigua en PostgreSQL y **no la usa** la app. No la trate como el modelo real.
:::

Las fechas son `datetime` UTC.

## `users/{email}`

Espejo del perfil, escrito por `ensure_user` en la creación de proyecto (`firestore_service.py:73`).

| Campo | Tipo | Descripción |
|---|---|---|
| `email` | string | También es el id del documento |
| `name`, `picture` | string | Del método de inicio de sesión |
| `role` | string | `admin`, `user` o `viewer` |
| `auth_method` | string | `google`, `email_otp`, `access_token` o `dev_mode` |
| `last_login_at` | fecha | Se actualiza en cada upsert |
| `created_at` | fecha | Solo en la primera escritura |

## `projects/{id}`

Colección de nivel superior, para permitir el uso compartido.

| Campo | Tipo | Descripción |
|---|---|---|
| `client_name` | string | Obligatorio |
| `project_name` | string | Opcional; los proyectos antiguos reciben `client_name` en la lectura |
| `description` | string | Opcional |
| `project_metadata` | mapa | Libre |
| `logo_base64` | string | Hasta 5 MB |
| `owner_email` | string | Dueño (quien creó) |
| `member_emails` | lista de string | Miembros (ArrayUnion/ArrayRemove) |
| `google_accounts` | mapa de listas | Claves: `ads_customer_ids`, `ga4_property_ids`, `gtm_account_ids`, `gtm_container_ids`, `login_customer_ids`; alimentado por `record_google_accounts` |
| `created_at`, `updated_at` | fecha | |
| `last_report_at` | fecha o null | Se actualiza en cada `run` guardada |

## `projects/{id}/reports/{id}`

| Campo | Tipo | Descripción |
|---|---|---|
| `report_type` | string | Solo se acepta `gtm_analyzer` |
| `title` | string | Predeterminado `Relatório dd/mm/aaaa` |
| `status` | string | `draft`; pasa a `generated` tras generar el documento |
| `payload` | mapa | Payload canónico en edición |
| `document_id`, `document_url` | string o null | Documento de Google Docs generado |
| `google_ads_analysis` | mapa | Último resultado del análisis de Google Ads (se sobrescribe en cada ejecución) |
| `created_by` | string | Correo |
| `created_at`, `updated_at` | fecha | |

## `projects/{id}/reports/{rid}/runs/{id}`

Historial inmutable, creado por `save_run`.

| Campo | Tipo | Descripción |
|---|---|---|
| `source` | string | Origen (ej.: `report`; también carga, análisis en vivo y crawler) |
| `payload` | mapa | Snapshot del payload |
| `triggered_by` | string | Correo |
| `created_at` | fecha | |
| `document_id`, `document_url` | string | Solo cuando `source="report"` |

## Reglas de integridad

- Eliminar un informe o proyecto borra en cascada las subcolecciones (`recursive_delete`).
- `save_run_safe` y `save_google_ads_analysis_safe` nunca interrumpen el flujo principal; los errores solo se registran en el log.
- Acceso: ver [Autenticación](../visao-geral-e-arquitetura/autenticacao.md). Más sobre Firestore en [Firebase](../integracoes/firebase.md).
