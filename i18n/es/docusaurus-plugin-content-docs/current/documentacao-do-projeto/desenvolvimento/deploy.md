---
title: "Despliegue"
description: "Cómo funciona el make deploy de DS30 (guarda de branch, Cloud Run, Docker) y las reglas de despliegue solo humano."
sidebar_position: 5
---

# Despliegue

:::warning El despliegue es solo humano
La IA nunca ejecuta `make deploy` ni publica en producción. Cualquier cambio en `Makefile`, `Dockerfile`, `.env`, `backend/scripts/render_cloudrun_env.py` o variables de Cloud Run exige consentimiento explícito del desarrollador.
:::

## Único comando

`make deploy`, **sin argumento de entorno**. Dev y prod comparten el mismo `Makefile`; los alias `deploy-dev`/`deploy-prod` no existen y no deben volver. Antes de ejecutarlo, el humano confirma que el working tree esté limpio.

## Guarda de branch (`Makefile:8-20`)

| Situación | Resultado |
|---|---|
| branch `dev` | despliegue en `gtm-analyzer-dev` (`APP_ENVIRONMENT=development`) |
| branch `prod` | despliegue en `gtm-analyzer-prod` (`APP_ENVIRONMENT=production`) |
| otra branch, HEAD desacoplado | error "Deploy permitido apenas nas branches dev e prod" (Despliegue permitido solo en las branches dev y prod) |
| `ENV=` distinto de la branch | error "não corresponde à branch" (no corresponde a la branch) |

`ENV` se sobrescribe con la branch. Todo esto falla antes de cualquier build/`gcloud`. Probado en `backend/tests/test_makefile_deploy.py` (usa un `git` falso y `make -n`, y verifica que `deploy-dev`/`deploy-prod` no existen).

## Etapas (`Makefile:129-151`)

1. `check-project`: exige `GCP_PROJECT` (predeterminado `dp6-ins-datastrength`; región `us-east1`; repositorio `gtm-analyzer-repo`).
2. `check-cloudrun-env`: exige `backend/.env` y valida con `backend/scripts/render_cloudrun_env.py --validate` (por ejemplo, el redirect OAuth de Google Ads del entorno debe ser HTTPS absoluto y no apuntar a localhost).
3. Build y push: con Docker local, `docker build` + `docker push` de las tags `<env>-<sha>` y `<env>-latest`; sin Docker, `gcloud builds submit` (Cloud Build) y marcado de la tag latest.
4. `gcloud run deploy` con la imagen inmutable `<env>-<sha>`, `--allow-unauthenticated`, `--port=8080` y `--env-vars-file` generado en un archivo temporal por el renderizador (borrado al final).

## Dimensionamiento de Cloud Run

| | dev | prod |
|---|---|---|
| mín. instancias | 0 | 1 |
| máx. instancias | 3 | 10 |
| CPU | 1 | 1 |
| memoria | 1Gi | 2Gi |

## Dockerfile

- Etapa 1 `frontend-builder` (node:20-alpine): `npm ci`, `npm run build`.
- Etapa 2 `runner` (python:3.11-slim): instala `backend/requirements.txt`, copia `backend/`, copia el `dist` a `backend/static` y ejecuta `uvicorn main:app` en el puerto `$PORT` (8080).
- Heredado: `Dockerfile:31-32` todavía copia `Docs/DS30_..._Template_v3_5_variable_names_preenchidos.docx` y `Docs/DS30_..._variable_mapping_v2_arrays.json`, restos del flujo `.docx` eliminado. El `.dockerignore` mantiene una excepción solo para ese `.docx`. No los lee el flujo actual; eliminarlos exige consentimiento (regla anterior).

## `.dockerignore` y `.gcloudignore`

Ambos excluyen `.git`, `.venv`, `node_modules`, `frontend/dist`, `__pycache__`, `client_secret*.json`, `google-ads.yaml`, CSVs de datos y todo `.env`/`.env.*`. Los secretos nunca entran en la imagen ni en la carga a Cloud Build; viven en `backend/.env` (ignorado por git) o en variables de Cloud Run. Nunca haga commit de credenciales OAuth, claves, tokens, informes generados ni datos de clientes.

## Otros targets útiles

`make build`, `make run-local` (puerto 8080), `make init-gcp`, `make auth`, `make push`, `make logs ENV=dev|prod`, `make status`.

## Apps Script no forma parte del despliegue

El script que genera el Google Doc se publica **aparte y manualmente** (`clasp`, sin CI/CD). Subir Cloud Run no actualiza Apps Script. Vea [Apps Script por dentro](../geracao-do-documento/apps-script-por-dentro.md).
