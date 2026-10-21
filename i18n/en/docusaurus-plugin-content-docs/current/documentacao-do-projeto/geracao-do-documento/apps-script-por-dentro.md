---
title: "Apps Script internals"
description: "Apps Script project files, templates, placeholder replacement, scope, publishing with clasp and the three authentication layers."
sidebar_position: 3
---

# Apps Script internals

The code lives in `Docs/ds30_appscript/` and runs as a Web App (`executeAs: USER_DEPLOYING`, `access: DOMAIN`, in `appsscript.json`). The files share the same global scope; there is no import/export. `Docs/ds30_appscript.js` is the historical single-file version.

## Files

| File | Contents |
|---|---|
| `Config.js` | `CONFIG` (IDs `BLANK_TEMPLATE_ID`, `COVER_TEMPLATE_ID`, `CLIENTS_FOLDER_ID`, time zone, footer, `PREVIEW_MODE`) and `validateConfig` |
| `Main.js` | `doPost`, `generateDs30`, client folder, file name, footer, `validatePayload`, `testGenerateDs30` |
| `DocStyle.js` | Styles: `addH1` to `addH4`, `addParagraph`, `addListItem`, `addBullets`, `addCallout`, tables |
| `DocHelpers.js` | Cover copy, `getDriveId`, `getValue`, placeholder replacement, logo |
| `ReportSections.js` | `resolveScope` and the `render*` functions with each section's text |

The template and folder IDs live in `Config.js` and are not repeated here.

## `generateDs30` execution (`Main.js:27`)

1. `validatePayload` and `validateConfig` (fails if any `*_ID` still starts with `COLOQUE_`).
2. `resolveClientFolder` (`Main.js:6`): looks for a subfolder with the exact client name in `CLIENTS_FOLDER_ID`; creates it if it does not exist.
3. Copies `DS30_BLANK` into the subfolder with the name `[DS30] Diagnóstico Técnico - <client> (<yyyy-MM-dd>)` (`outputFileName`, `Main.js:13`). The date comes from `snapshot_date`. There is no uniqueness suffix: generating twice on the same day creates two files with the same name.
4. From here on, inside a `try`: clears the body, copies the body of `DS30_COVER` (`appendTemplateBody`), inserts the logo, replaces placeholders.
5. `renderIntroduction`, then the sections according to `resolveScope`, then `renderChangelog`.
6. `addInstitutionalFooter` (`Main.js:20`) appends to the BLANK footer (which already carries the numbering) the line "Documento produzido pela DP6 | ..." (Document produced by DP6 | ...), omitting empty email and site.
7. `saveAndClose` and returns `documentId` and `documentUrl`.

On an error after the copy, the `catch` moves the incomplete file to the trash and rethrows (`Main.js:64`). The client folder may already have been created and is not undone.

## Templates and placeholders

- **DS30_BLANK**: margins and footer with automatic pagination. The body is erased.
- **DS30_COVER**: cover with `{{document_month}}`, `{{document_year}}` and `{{client_logo}}`. Only paragraphs, lists and tables are copied; header and footer must stay in the BLANK.
- `replaceScalarPlaceholders` (`DocHelpers.js:55`): each scalar key of the payload replaces `{{key}}` in the body. Objects and lists are ignored. Outside `PREVIEW_MODE`, null values become empty and remaining placeholders are removed.
- `insertClientLogo` (`DocHelpers.js:76`): accepts a PNG/JPEG/GIF data URL up to 5 MB, requires `{{client_logo}}` in its own paragraph and limits the image to 220 x 110 px. Without a logo, the placeholder is removed.
- `fillText` resolves `{{field}}` in the section texts with `getValue`, which shows `—` when a value is missing (or `[campo: x]` in `PREVIEW_MODE`).

## Scope and sections

`resolveScope` (`ReportSections.js:120`) returns five flags. Only an explicit `false` turns one off.

| Flag | Function | Note |
|---|---|---|
| `gtg` | `renderGTG` | Facts omitted when the `*_decision` is unknown; an unused server-side container becomes "Ponto de atenção" (Point of attention) |
| `upd` | `renderUPD` | Tables of platforms, containers, UPD variables and tags (`renderContainers`) |
| `enhancedConversions` | `renderEnhancedConversions` (uses `renderGoogleAdsEC`) | |
| `offlineConversions` | `renderOfflineConversions` | OCI and ECL together, no separate flag for ECL |
| `eco` | `renderECO` | Requires `offline_conversions.enabled` |

`renderChangelog` always runs and creates a "Criação do documento" (Document creation) entry if `changelog_entries` is empty. Considerations sections only appear when the field has a value.

## Three authentication layers

| Layer | Where | Role |
|---|---|---|
| Publisher account OAuth token | `Authorization: Bearer` sent by `apps_script_service.py:61` | Passes the Web App policy; generated from the refresh token (`backend/services/drive_service.py:37`) |
| `DOMAIN` Web App access | `appsscript.json` | Only accounts in the domain can call the URL |
| Shared secret | `doPost` compares `request.secret` with the Script Property `DS30_SHARED_SECRET` (`Main.js:74`) | Rejects before creating any file |

The document is created with the identity of whoever published the Web App. The user's email goes only as text (`document_owner_email`), not as a permission. The script does not change sharing: the user must already have access to the parent folder.

## Publishing flow with clasp

Commands run in `Docs/ds30_appscript/`. Login, push and publishing are human steps.

| Command | Effect |
|---|---|
| `clasp status` | Lists what would be sent |
| `clasp push` | Replaces the remote code (HEAD). **Does not change the version published at `/exec`** |
| `clasp redeploy <deploymentId>` | Publishes the newest version to the existing deployment, keeping the URL |
| `clasp deploy` (without `-i`) | Creates a new deployment with a different URL and **breaks `DS30_APPS_SCRIPT_URL`** |

`publish.sh` automates login, `clasp status`, `clasp push --force` and `clasp redeploy`, extracting the `deploymentId` from the `DS30_APPS_SCRIPT_URL` configured in the backend environment, with confirmation before the push and before the redeploy. Validate afterwards on the `/exec` URL, not `/dev`. The Apps Script project ID is in `Docs/clasp_setup.md` and is omitted here.

## Manual test

Run `testGenerateDs30` (`Main.js:94`) in the Apps Script editor (via `clasp open`): it generates a test document with a minimal payload and logs the URL. It creates the "Cliente" subfolder in the parent folder. Apps Script has no local runtime; the repository's Python tests use stubs and generate nothing in Drive.

## Discrepancies between the old documents and the code

- `Docs/clasp_setup.md` says `testGenerateDs30` uses `CONFIG.OUTPUT_FOLDER_ID`. The current code uses `CLIENTS_FOLDER_ID` (one subfolder per client).
- `Docs/apps_script_integration.md` describes the input as `{payload, client_logo_base64}`. The real endpoint receives `{payload, project_id, report_id}`; the logo comes from the project in Firestore and the backend is what builds the body sent to the script (`{secret, payload, client_logo_base64}`, `apps_script_service.py:61`).
- The same document cites `frontend/utils/payloadHelpers.js`; the real path is `frontend/src/utils/payloadHelpers.js`.

See also: [Generation flow](./fluxo-de-geracao.md), [Timeout and errors](./timeout-e-erros.md), [Apps Script integration](../integracoes/apps-script.md).
