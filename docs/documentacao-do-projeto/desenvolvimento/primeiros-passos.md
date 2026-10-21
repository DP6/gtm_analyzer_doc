---
title: "Primeiros passos"
description: "Como preparar o ambiente local do DS30, subir backend e frontend e autenticar em desenvolvimento."
sidebar_position: 1
---

# Primeiros passos

O DS30 tem dois processos locais: backend FastAPI (`:8000`) e frontend React/Vite (`:5173`).

## Pré-requisitos

| Item | Uso |
|---|---|
| Python 3 (a imagem Docker usa 3.11, `Dockerfile:19`) | backend |
| Node 20 + npm (`Dockerfile:4`) | frontend |
| `backend/.env` | configuração local (copiada de `backend/.env.example`) |

## Setup manual

```bash
# backend
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env        # depois preencha os valores

# frontend
cd ../frontend
npm ci
```

`pytest` não consta em `backend/requirements.txt`; instale à parte para rodar os testes (veja [Testes](./testes.md)).

## Subir tudo com `run_app.sh`

`./run_app.sh` (na raiz) faz apenas:

1. Escolhe o interpretador em `backend/`: `.venv/bin/python3` se `.venv` existir; senão `$HOME/anaconda3/bin/python3`; senão `python3` (`run_app.sh:13-19`).
2. Sobe `uvicorn main:app --host 0.0.0.0 --port 8000` em background.
3. Espera 2 s e sobe `npm run dev -- --port 5173 --host`.
4. Ctrl+C encerra os dois processos.

O script **não cria o venv, não instala dependências e não roda `npm ci`**: faça o setup manual antes. Também não usa `--reload` (o `CLAUDE.md` do app mostra o comando com `--reload` para rodar o backend à mão).

## Variáveis do `backend/.env`

Só os nomes (valores nunca entram no repositório; `.env` é ignorado pelo git):

- Ambiente e auth: `ENVIRONMENT`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `ALLOWED_ORIGINS`, `ALLOWED_DOMAINS`, `MASTER_ACCESS_TOKEN`, `DEV_USER_EMAIL`, `DEV_USER_NAME`
- OTP por e-mail: `EMAIL_OTP_ENABLED`, `EMAIL_OTP_TTL_SECONDS`, `EMAIL_SESSION_TTL_HOURS`, `SENDGRID_API_KEY`, `EMAIL_FROM_ADDRESS`, `EMAIL_FROM_NAME`
- Google Ads: `GOOGLE_ADS_DEVELOPER_TOKEN`, `GOOGLE_ADS_OAUTH_REDIRECT_URI`, `GOOGLE_ADS_OAUTH_REDIRECT_URI_DEV`, `GOOGLE_ADS_OAUTH_REDIRECT_URI_PROD`, `GOOGLE_ADS_SESSION_ENCRYPTION_KEY`
- Firestore (comentadas no exemplo): `GOOGLE_APPLICATION_CREDENTIALS`, `FIRESTORE_EMULATOR_HOST`

O `.env.example` não lista todas as variáveis que `backend/config.py` lê (por exemplo `DS30_APPS_SCRIPT_URL`, `DS30_APPS_SCRIPT_SECRET`, `GOOGLE_REFRESH_TOKEN`, `OBSERVEPOINT_API_KEY`, `GEMINI_API_KEY`). A lista completa está em [Variáveis de ambiente](../referencia/variaveis-de-ambiente.md).

## Autenticação em desenvolvimento

Com `ENVIRONMENT=development`, o backend aceita o cabeçalho `X-Dev-User-Email` como identidade (`backend/services/auth_service.py:238-239`; em qualquer outro valor de `ENVIRONMENT` o bypass é recusado). O frontend envia esse cabeçalho quando `gtm_auth_dev_email` está no `localStorage`. Detalhes e prioridade dos métodos: [Autenticação](../visao-geral-e-arquitetura/autenticacao.md).

## Endereços

| O quê | URL |
|---|---|
| Frontend | http://localhost:5173 |
| API | http://localhost:8000 |
| OpenAPI (Swagger) | http://localhost:8000/docs |

No dev, o Vite faz proxy de `/api` para `localhost:8000` (`frontend/vite.config.js`). Visão geral das rotas: [Visão geral da API](../api/visao-geral-da-api.md).
