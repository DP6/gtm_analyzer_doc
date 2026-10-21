---
title: "Apps Script por dentro"
description: "Archivos del proyecto Apps Script, plantillas, sustitución de placeholders, alcance, publicación con clasp y las tres capas de autenticación."
sidebar_position: 3
---

# Apps Script por dentro

El código vive en `Docs/ds30_appscript/` y corre como Web App (`executeAs: USER_DEPLOYING`, `access: DOMAIN`, en `appsscript.json`). Los archivos comparten el mismo alcance global; no hay import/export. `Docs/ds30_appscript.js` es la versión histórica de un solo archivo.

## Archivos

| Archivo | Contenido |
|---|---|
| `Config.js` | `CONFIG` (IDs de `BLANK_TEMPLATE_ID`, `COVER_TEMPLATE_ID`, `CLIENTS_FOLDER_ID`, zona horaria, pie de página, `PREVIEW_MODE`) y `validateConfig` |
| `Main.js` | `doPost`, `generateDs30`, carpeta del cliente, nombre del archivo, pie de página, `validatePayload`, `testGenerateDs30` |
| `DocStyle.js` | Estilos: `addH1` a `addH4`, `addParagraph`, `addListItem`, `addBullets`, `addCallout`, tablas |
| `DocHelpers.js` | Copia de la portada, `getDriveId`, `getValue`, sustitución de placeholders, logo |
| `ReportSections.js` | `resolveScope` y las funciones `render*` con el texto de cada sección |

Los IDs de las plantillas y de la carpeta quedan en `Config.js` y no se repiten aquí.

## Ejecución de `generateDs30` (`Main.js:27`)

1. `validatePayload` y `validateConfig` (falla si algún `*_ID` todavía empieza con `COLOQUE_`).
2. `resolveClientFolder` (`Main.js:6`): busca una subcarpeta con el nombre exacto del cliente en `CLIENTS_FOLDER_ID`; la crea si no existe.
3. Copia `DS30_BLANK` a la subcarpeta con el nombre `[DS30] Diagnóstico Técnico - <cliente> (<yyyy-MM-dd>)` (`outputFileName`, `Main.js:13`). La fecha viene de `snapshot_date`. No hay sufijo de unicidad: generar dos veces el mismo día crea dos archivos con el mismo nombre.
4. A partir de aquí, dentro de `try`: limpia el cuerpo, copia el cuerpo de `DS30_COVER` (`appendTemplateBody`), inserta el logo, sustituye los placeholders.
5. `renderIntroduction`, luego las secciones según `resolveScope`, luego `renderChangelog`.
6. `addInstitutionalFooter` (`Main.js:20`) agrega al pie de BLANK (que ya trae la numeración) la línea "Documento produzido pela DP6 | ..." (Documento producido por DP6), omitiendo correo y sitio vacíos.
7. `saveAndClose` y retorno de `documentId` y `documentUrl`.

Ante un error después de la copia, el `catch` mueve el archivo incompleto a la papelera y relanza (`Main.js:64`). La carpeta del cliente ya pudo haberse creado y no se deshace.

## Plantillas y placeholders

- **DS30_BLANK**: márgenes y pie de página con paginación automática. El cuerpo se borra.
- **DS30_COVER**: portada con `{{document_month}}`, `{{document_year}}` y `{{client_logo}}`. Solo se copian párrafos, listas y tablas; el encabezado y el pie deben quedar en BLANK.
- `replaceScalarPlaceholders` (`DocHelpers.js:55`): cada clave escalar del payload sustituye `{{clave}}` en el cuerpo. Los objetos y las listas se ignoran. Fuera de `PREVIEW_MODE`, los valores nulos pasan a vacío y los placeholders restantes se eliminan.
- `insertClientLogo` (`DocHelpers.js:76`): acepta data URL PNG/JPEG/GIF de hasta 5 MB, exige `{{client_logo}}` en un párrafo exclusivo y limita la imagen a 220 x 110 px. Sin logo, se elimina el placeholder.
- `fillText` resuelve `{{campo}}` en los textos de las secciones con `getValue`, que muestra `—` cuando falta el valor (o `[campo: x]` en `PREVIEW_MODE`).

## Alcance y secciones

`resolveScope` (`ReportSections.js:120`) devuelve cinco flags. Solo `false` explícito desactiva.

| Flag | Función | Observación |
|---|---|---|
| `gtg` | `renderGTG` | Hechos omitidos cuando el `*_decision` es desconocido; un container server-side fuera de uso se convierte en "Ponto de atenção" (Punto de atención) |
| `upd` | `renderUPD` | Tablas de plataformas, containers, variables UPD y tags (`renderContainers`) |
| `enhancedConversions` | `renderEnhancedConversions` (usa `renderGoogleAdsEC`) | |
| `offlineConversions` | `renderOfflineConversions` | OCI y ECL juntos, sin flag separada para ECL |
| `eco` | `renderECO` | Exige `offline_conversions.enabled` |

`renderChangelog` siempre corre y crea una entrada "Criação do documento" (Creación del documento) si `changelog_entries` está vacío. Las secciones de consideraciones solo aparecen cuando el campo tiene valor.

## Tres capas de autenticación

| Capa | Dónde | Papel |
|---|---|---|
| Token OAuth de la cuenta publicadora | `Authorization: Bearer` enviado por `apps_script_service.py:61` | Pasa por la política del Web App; generado a partir del refresh token (`backend/services/drive_service.py:37`) |
| Acceso del Web App `DOMAIN` | `appsscript.json` | Solo las cuentas del dominio llaman a la URL |
| Secreto compartido | `doPost` compara `request.secret` con la Script Property `DS30_SHARED_SECRET` (`Main.js:74`) | Rechaza antes de crear cualquier archivo |

El documento se crea con la identidad de quien publicó el Web App. El correo del usuario va solo como texto (`document_owner_email`), no como permiso. El script no altera el uso compartido: el usuario ya debe tener acceso a la carpeta madre.

## Flujo de publicación con clasp

Los comandos se ejecutan en `Docs/ds30_appscript/`. Login, push y publicación son pasos humanos.

| Comando | Efecto |
|---|---|
| `clasp status` | Lista lo que se enviaría |
| `clasp push` | Reemplaza el código remoto (HEAD). **No cambia la versión publicada en `/exec`** |
| `clasp redeploy <deploymentId>` | Publica la versión más nueva en el deployment existente, manteniendo la URL |
| `clasp deploy` (sin `-i`) | Crea un deployment nuevo con otra URL y **rompe `DS30_APPS_SCRIPT_URL`** |

`publish.sh` automatiza login, `clasp status`, `clasp push --force` y `clasp redeploy`, extrayendo el `deploymentId` de la `DS30_APPS_SCRIPT_URL` configurada en el entorno del backend, con confirmación antes del push y antes del redeploy. Valide después en la URL `/exec`, no en `/dev`. El ID del proyecto Apps Script está en `Docs/clasp_setup.md` y se omite aquí.

## Prueba manual

Ejecute `testGenerateDs30` (`Main.js:94`) en el editor de Apps Script (por `clasp open`): genera un documento de prueba con un payload mínimo y registra la URL. Crea la subcarpeta "Cliente" en la carpeta madre. Apps Script no tiene runtime local; las pruebas Python del repositorio usan stubs y no generan nada en Drive.

## Desvíos entre los documentos antiguos y el código

- `Docs/clasp_setup.md` dice que `testGenerateDs30` usa `CONFIG.OUTPUT_FOLDER_ID`. El código actual usa `CLIENTS_FOLDER_ID` (subcarpeta por cliente).
- `Docs/apps_script_integration.md` describe la entrada como `{payload, client_logo_base64}`. El endpoint real recibe `{payload, project_id, report_id}`; el logo viene del proyecto en Firestore y el backend es quien arma el cuerpo enviado al script (`{secret, payload, client_logo_base64}`, `apps_script_service.py:61`).
- El mismo documento cita `frontend/utils/payloadHelpers.js`; la ruta real es `frontend/src/utils/payloadHelpers.js`.

Vea también: [Flujo de generación](./fluxo-de-geracao.md), [Timeout y errores](./timeout-e-erros.md), [Integración Apps Script](../integracoes/apps-script.md).
