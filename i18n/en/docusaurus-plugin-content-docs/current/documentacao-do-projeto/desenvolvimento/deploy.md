---
title: "Deploy"
description: "How DS30's make deploy works (branch guard, Cloud Run, Docker) and the human-only deploy rules."
sidebar_position: 5
---

# Deploy

:::warning Deploy is human-only
AI never runs `make deploy` nor publishes to production. Any change to `Makefile`, `Dockerfile`, `.env`, `backend/scripts/render_cloudrun_env.py` or Cloud Run variables requires the developer's explicit consent.
:::

## Single command

`make deploy`, **with no environment argument**. Dev and prod share the same `Makefile`; `deploy-dev`/`deploy-prod` aliases do not exist and must not come back. Before running, the human confirms a clean working tree.

## Branch guard (`Makefile:8-20`)

| Situation | Result |
|---|---|
| branch `dev` | deploy to `gtm-analyzer-dev` (`APP_ENVIRONMENT=development`) |
| branch `prod` | deploy to `gtm-analyzer-prod` (`APP_ENVIRONMENT=production`) |
| another branch, detached HEAD | error "Deploy permitido apenas nas branches dev e prod" (Deploy allowed only on the dev and prod branches) |
| `ENV=` different from the branch | error "não corresponde à branch" (does not match the branch) |

`ENV` is overridden by the branch. All of this fails before any build/`gcloud`. Tested in `backend/tests/test_makefile_deploy.py` (uses a fake `git` and `make -n`, and checks that `deploy-dev`/`deploy-prod` do not exist).

## Steps (`Makefile:129-151`)

1. `check-project`: requires `GCP_PROJECT` (default `dp6-ins-datastrength`; region `us-east1`; repository `gtm-analyzer-repo`).
2. `check-cloudrun-env`: requires `backend/.env` and validates with `backend/scripts/render_cloudrun_env.py --validate` (for example, the environment's Google Ads OAuth redirect must be an absolute HTTPS URL and not point to localhost).
3. Build and push: with local Docker, `docker build` + `docker push` of the tags `<env>-<sha>` and `<env>-latest`; without Docker, `gcloud builds submit` (Cloud Build) and tagging latest.
4. `gcloud run deploy` with the immutable image `<env>-<sha>`, `--allow-unauthenticated`, `--port=8080` and `--env-vars-file` generated in a temporary file by the renderer (deleted at the end).

## Cloud Run sizing

| | dev | prod |
|---|---|---|
| min instances | 0 | 1 |
| max instances | 3 | 10 |
| CPU | 1 | 1 |
| memory | 1Gi | 2Gi |

## Dockerfile

- Stage 1 `frontend-builder` (node:20-alpine): `npm ci`, `npm run build`.
- Stage 2 `runner` (python:3.11-slim): installs `backend/requirements.txt`, copies `backend/`, copies `dist` to `backend/static` and runs `uvicorn main:app` on port `$PORT` (8080).
- Legacy: `Dockerfile:31-32` still copies `Docs/DS30_..._Template_v3_5_variable_names_preenchidos.docx` and `Docs/DS30_..._variable_mapping_v2_arrays.json`, remnants of the removed `.docx` flow. `.dockerignore` keeps an exception only for that `.docx`. They are not read by the current flow; removing them requires consent (rule above).

## `.dockerignore` and `.gcloudignore`

Both exclude `.git`, `.venv`, `node_modules`, `frontend/dist`, `__pycache__`, `client_secret*.json`, `google-ads.yaml`, data CSVs and every `.env`/`.env.*`. Secrets never enter the image nor the Cloud Build upload; they live in `backend/.env` (ignored by git) or in Cloud Run variables. Never commit OAuth credentials, keys, tokens, generated reports or client data.

## Other useful targets

`make build`, `make run-local` (port 8080), `make init-gcp`, `make auth`, `make push`, `make logs ENV=dev|prod`, `make status`.

## Apps Script is not part of the deploy

The script that generates the Google Doc is published **separately and manually** (`clasp`, no CI/CD). Deploying Cloud Run does not update Apps Script. See [Apps Script internals](../geracao-do-documento/apps-script-por-dentro.md).
