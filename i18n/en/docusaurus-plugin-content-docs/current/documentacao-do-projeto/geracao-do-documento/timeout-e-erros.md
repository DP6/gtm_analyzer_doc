---
title: "Timeout and errors"
description: "Table of Drive generation errors (503, 422, 502, 504), causes, actions and the risk of duplicate documents after a timeout."
sidebar_position: 4
---

# Timeout and errors

All errors come out of `generate_drive_report` (`backend/services/apps_script_service.py`). The messages are generic on purpose: Apps Script details do not go to the user, only to the logs (`logger.warning`).

## Error table

| HTTP | Message (summary) | Cause | What to do |
|---|---|---|---|
| 503 | "Geração no Drive não configurada: informe ..." (Drive generation not configured: provide ...) (`:24`) | `DS30_APPS_SCRIPT_URL`, `DS30_APPS_SCRIPT_SECRET`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` or `GOOGLE_REFRESH_TOKEN` is missing | Configure the named variable (the message lists only the names) and restart the backend |
| 503 | "DS30_APPS_SCRIPT_URL deve ser a URL /exec" (must be the /exec URL) (`:26`) | URL outside the pattern (for example `/dev`) | Use the deployment's `/exec` URL |
| 422 | "Coleção inválida: `<chave>`" (Invalid collection: `<key>`) (`:31`) | Collection is not a list of objects | Fix the payload in the source tab |
| 422 | "Logo inválido. Use PNG, JPEG ou GIF de até 5 MB." (Invalid logo. Use PNG, JPEG or GIF up to 5 MB.) (`:45`) | Project logo in the wrong format, corrupted or too large | Replace the logo in the project settings |
| 502 | "Não foi possível renovar o token Google ..." (Could not renew the Google token ...) (`:58`) | Publisher account refresh token revoked or OAuth client mismatch | Generate a new token (see [Apps Script](../integracoes/apps-script.md)); no POST was made |
| 502 | "O endpoint do Apps Script retornou HTTP 401/403" (The Apps Script endpoint returned HTTP 401/403) (`:70`) | Publisher account without access to the Web App or deployment rejecting the Bearer | Review `DOMAIN` access and the publisher account |
| 502 | "retornou HTTP `<código>`" (returned HTTP `<code>`) (`:71`) | Another HTTP error from the deployment | Review the publication and the Web App permissions |
| 502 | "Falha de comunicação com o Apps Script" (Communication failure with Apps Script) (`:74`) | Transport error (DNS, connection) | Check network and URL; try again |
| 502 | "Resposta inválida do Apps Script" (Invalid Apps Script response) (`:81`) | Body was not JSON (for example the Google login page) | Review publication and access; the log has the redirect chain |
| 502 | "O Apps Script não conseguiu gerar o documento" (Apps Script could not generate the document) (`:84`) | JSON with `ok` other than `true`: mismatched secret, incomplete `CONFIG`, inaccessible template, render error | Check the `doPost` executions in Apps Script |
| 502 | "identificador de documento inválido" (invalid document identifier) (`:88`) | `documentId` missing or outside `[A-Za-z0-9_-]+` | Check the execution in Apps Script |
| 504 | "O Apps Script não respondeu a tempo ..." (Apps Script did not respond in time ...) (`:66`) | 360 s timeout (`httpx.Timeout(360, connect=10)`, `:60`) | **Check the client folder in Drive before generating again** |

Evaluation order and lines: see [Generation flow](./fluxo-de-geracao.md).

## 504 and duplicate documents

There is no automatic retry. A 504 means the backend gave up waiting, not that the script stopped: Apps Script may finish and create the document later. Each completed generation creates a new copy, and the name (`[DS30] Diagnóstico Técnico - <cliente> (<data>)`) has no uniqueness suffix, so a new attempt generates a second file with the same name. Check the client subfolder and delete the duplicate if needed. When the error happens during assembly, the script moves the incomplete copy to the trash (`Docs/ds30_appscript/Main.js:64`).

## NOT VERIFIED: Cloud Run timeout

The HTTP client waits up to 360 s, but Cloud Run's default request timeout is 300 s. The `Makefile`'s `gcloud run deploy` (lines 139 to 151) does not set `--timeout`, and the `Dockerfile` and `backend/config.py` have no reference to a timeout. If the service is on the default, Cloud Run may terminate the user's request before the backend reaches 360 s, and the frontend would receive an error that is not the documented 504. A human needs to confirm the real value with `gcloud run services describe <service> --region=<region>` (field `timeoutSeconds`). This page does not claim what the production value is.

## Tests

`backend/tests/test_report_contract_v2.py` covers: forwarding the payload and session email (`:42`), `client_name` coming from the project without overwriting an existing one (`:75`), remote errors without leaking details, including 401/403/500, non-JSON, `ok: false`, malicious `documentId` and 504 timeout (`:117`), invalid configuration and inputs failing before the network (`:157`), refresh failing before the POST (`:181`), redirect without Bearer and renewal on every generation (`:201`) and logging of the redirect chain (`:224`). See [Tests](../desenvolvimento/testes.md).
