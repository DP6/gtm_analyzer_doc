---
title: "Firebase (Firestore)"
description: "Cómo el backend usa Firestore para proyectos, informes y ejecuciones, credenciales (ADC), base de datos nombrada y permisos necesarios."
sidebar_position: 6
---

# Firebase (Firestore)

Firestore guarda proyectos, informes y el historial de ejecuciones. Solo el backend accede a él, vía Admin SDK (`firebase-admin`); no hay Firestore Rules ni acceso directo desde el frontend. Código: `backend/services/firestore_service.py`.

## Conexión y credenciales

- `_ensure_app` (`firestore_service.py:25`) llama a `firebase_admin.initialize_app()` sin argumentos, es decir, usa **Application Default Credentials (ADC)**: en desarrollo, `gcloud auth application-default login`; en Cloud Run, la service account del servicio. No hay archivo de clave en el código.
- `client()` (`:32`) abre la base de datos **nombrada `gtm-analyzer`** (`firestore.client(database_id="gtm-analyzer")`), no la `(default)`.

## Modelo de datos

| Ruta | Contenido |
|---|---|
| `users/{email}` | Espejo del perfil (`ensure_user`, `:73`) |
| `projects/{id}` | Dueño (`owner_email`), `member_emails`, datos del cliente, logo, `google_accounts`, `last_report_at` |
| `projects/{id}/reports/{id}` | Estado (`draft` o `generated`), documento generado, snapshot del último análisis de Google Ads |
| `projects/{id}/reports/{id}/runs/{id}` | Ejecución inmutable: `source`, `payload`, `triggered_by`, `created_at`, y `document_id`/`document_url` cuando hubo generación |

`projects` es una colección de nivel superior para permitir el uso compartido entre usuarios. El acceso se impone en el código (`has_access`, `is_owner`, `:65`), no por Firestore. El diccionario completo está en [Diccionario de datos](../referencia/dicionario-de-dados.md) y las rutas en [API de proyectos](../api/projects.md).

`save_run` (`:87`) verifica el acceso, agrega el run, actualiza el informe y el proyecto y, cuando `source == "report"`, marca el informe como `generated`. `save_run_safe` (`:116`) traga las excepciones para que el historial nunca tumbe la operación principal (se usa tras la carga, el análisis en vivo, el crawler y la generación del documento; ver [Flujo de generación](../geracao-do-documento/fluxo-de-geracao.md)).

## Permisos

- **Cloud Run.** La service account del servicio necesita permiso de datos de Firestore. Según el relevamiento en `Docs/firebase_gcp_permissions.md`, los dos despliegues usan la service account predeterminada de Compute Engine con `roles/editor`, que ya cubre Firestore. Si algún día esa cuenta se restringe, agregue `roles/datastore.user` explícitamente; de lo contrario la app falla al guardar runs y proyectos. Esto se relevó en una fecha pasada y no se volvió a verificar ahora: confirme con `gcloud` antes de depender de ello.
- **Desarrollador local.** Necesita un rol `datastore.*` (el relevamiento recomienda `roles/datastore.owner`, otorgado por quien administra el IAM del proyecto) y el ADC configurado. Ver [Primeros pasos](../desenvolvimento/primeiros-passos.md).
- Los cambios de IAM en producción son una acción humana.

## Redirect del OAuth

`GOOGLE_ADS_OAUTH_REDIRECT_URI` debe ser la ruta fija de callback del backend (`/api/google-ads/oauth/callback`), registrada en el cliente OAuth en la consola de GCP. El destino final del usuario (`return_to`, por ejemplo `/projects/<id>/reports/<id>?tab=...`) viaja en el `state` firmado, no es redirect URI, por lo que cambiar la pantalla de retorno no exige alterar GCP. Solo verifique que el valor de la variable en cada entorno sea idéntico al registrado. Detalles del flujo en [Google OAuth](./google-oauth.md).

## Documentos de apoyo: qué está desactualizado

- `Docs/firebase_setup_runbook.md` habla de "branch `feat/firebase-persistence`, staged, no commiteado" y de un paso opcional para cambiar a una base de datos nombrada, diciendo que eso exigiría modificar el código a `firestore.client(database_id="gtm-analyzer")`. Ese cambio **ya está en el código**; los verbos en futuro y el estado de branch del runbook son históricos.
- `Docs/firebase_gcp_permissions.md` describe hallazgos del 2026-09-15 (modo de la base `(default)` abierto, roles de personas específicas). Trátelo como una fotografía de una fecha, no como el estado actual. La pregunta sobre compartir la `(default)` perdió relevancia porque la app usa la base nombrada.
- El paso 5 del runbook (guion manual de prueba: proyecto, uso compartido, informes, reanudación, eliminación) sigue siendo útil como checklist de validación.
- Los dos documentos listan una falla preexistente en `frontend/src/utils/appsScript.test.js`; no verificada aquí.

## No verificado

- Si la base `gtm-analyzer` existe, en qué región y en qué modo, en los proyectos de dev y prod: solo `gcloud firestore databases list` lo confirma.
- Índices compuestos necesarios: el código no los declara; Firestore los pide en tiempo de ejecución.
