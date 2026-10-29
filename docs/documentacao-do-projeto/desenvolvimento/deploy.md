---
title: "Deploy"
description: "Como funciona o make deploy do DS30 (guarda de branch, Cloud Run, Docker) e as regras de deploy só humano."
sidebar_position: 5
---

# Deploy

:::warning Deploy é só humano
A IA nunca roda `make deploy` nem publica em produção. Qualquer mudança em `Makefile`, `Dockerfile`, `.env`, `backend/scripts/render_cloudrun_env.py` ou variáveis do Cloud Run exige consentimento explícito do desenvolvedor.
:::

## Único comando

`make deploy`, **sem argumento de ambiente**. Dev e prod compartilham o mesmo `Makefile`; aliases `deploy-dev`/`deploy-prod` não existem e não devem voltar. Antes de rodar, o humano confirma working tree limpa.

## Guarda de branch (`Makefile:8-20`)

| Situação | Resultado |
|---|---|
| branch `dev` | deploy em `gtm-analyzer-dev` (`APP_ENVIRONMENT=development`) |
| branch `prod` | deploy em `gtm-analyzer-prod` (`APP_ENVIRONMENT=production`) |
| outra branch, HEAD destacado | erro "Deploy permitido apenas nas branches dev e prod" |
| `ENV=` diferente da branch | erro "não corresponde à branch" |

O `ENV` é sobrescrito com a branch. Tudo isso falha antes de qualquer build/`gcloud`. Testado em `backend/tests/test_makefile_deploy.py` (usa um `git` falso e `make -n`, e confere que `deploy-dev`/`deploy-prod` não existem).

## Etapas (`Makefile:129-151`)

1. `check-project`: exige `GCP_PROJECT` (padrão `dp6-ins-datastrength`; região `us-east1`; repositório `gtm-analyzer-repo`).
2. `check-cloudrun-env`: exige `backend/.env` e valida com `backend/scripts/render_cloudrun_env.py --validate` (por exemplo, o redirect OAuth do Google Ads do ambiente deve ser HTTPS absoluto e não apontar para localhost).
3. Build e push: com Docker local, `docker build` + `docker push` das tags `<env>-<sha>` e `<env>-latest`; sem Docker, `gcloud builds submit` (Cloud Build) e marcação da tag latest.
4. `gcloud run deploy` com a imagem imutável `<env>-<sha>`, `--allow-unauthenticated`, `--port=8080` e `--env-vars-file` gerado em arquivo temporário pelo renderizador (apagado ao fim).

## Dimensionamento do Cloud Run

| | dev | prod |
|---|---|---|
| min instâncias | 0 | 1 |
| max instâncias | 3 | 10 |
| CPU | 1 | 1 |
| memória | 1Gi | 2Gi |

## Dockerfile

- Estágio 1 `frontend-builder` (node:20-alpine): `npm ci`, `npm run build`.
- Estágio 2 `runner` (python:3.11-slim): instala `backend/requirements.txt`, copia `backend/`, copia o `dist` para `backend/static` e roda `uvicorn main:app` na porta `$PORT` (8080).
- Legado: `Dockerfile:31-32` ainda copia `Docs/DS30_..._Template_v3_5_variable_names_preenchidos.docx` e `Docs/DS30_..._variable_mapping_v2_arrays.json`, resquícios do fluxo `.docx` removido. O `.dockerignore` mantém uma exceção só para esse `.docx`. Não são lidos pelo fluxo atual; remover exige consentimento (regra acima).

## `.dockerignore` e `.gcloudignore`

Ambos excluem `.git`, `.venv`, `node_modules`, `frontend/dist`, `__pycache__`, `client_secret*.json`, `google-ads.yaml`, CSVs de dados e todo `.env`/`.env.*`. Segredos nunca entram na imagem nem no upload do Cloud Build; vivem em `backend/.env` (ignorado pelo git) ou em variáveis do Cloud Run. Nunca commitar credenciais OAuth, chaves, tokens, relatórios gerados ou dados de cliente.

## Outros alvos úteis

`make build`, `make run-local` (porta 8080), `make init-gcp`, `make auth`, `make push`, `make logs ENV=dev|prod`, `make status`.

## Apps Script não faz parte do deploy

O script que gera o Google Doc é publicado **à parte e manualmente** (`clasp`, sem CI/CD). Subir o Cloud Run não atualiza o Apps Script. Veja [Apps Script por dentro](../geracao-do-documento/apps-script-por-dentro.md).
