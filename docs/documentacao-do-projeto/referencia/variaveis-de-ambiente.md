---
title: "Variáveis de ambiente"
description: "Todas as variáveis de configuração do backend, agrupadas, com finalidade e obrigatoriedade."
sidebar_position: 3
---

# Variáveis de ambiente

Definidas em `backend/config.py` (classe `Settings`, pydantic-settings), lidas de `backend/.env` ou do ambiente; variáveis desconhecidas são ignoradas. O modelo está em `backend/.env.example`. **Nunca registre valores reais** em docs, commits ou chats.

Coluna "Obrigatória": **Cloud Run** = exigida por `backend/scripts/render_cloudrun_env.py` (`REQUIRED_KEYS`) no deploy; **Recurso** = só é necessária para a funcionalidade citada; **Não** = opcional.

## Ambiente e CORS

| Variável | Finalidade | Obrigatória |
|---|---|---|
| `ENVIRONMENT` | `development` habilita modo dev; `prod`/`production` desativa OTP e marca cookies como `secure`. O deploy a define (`Makefile`) | Não (padrão `development`) |
| `ALLOWED_ORIGINS` | Origens do CORS, separadas por vírgula | Não |
| `PORT` | Porta do Uvicorn na imagem Docker (não é do `Settings`) | Não (padrão 8080) |

## Google (login, Drive e Ads)

| Variável | Finalidade | Obrigatória |
|---|---|---|
| `GOOGLE_CLIENT_ID` | Audiência do Google Sign-In; cliente OAuth do Drive e do Ads | Cloud Run |
| `GOOGLE_CLIENT_SECRET` | Segredo do cliente OAuth | Cloud Run |
| `GOOGLE_REFRESH_TOKEN` | Conta que publica documentos no Drive (`drive_service.py:16`) | Recurso (geração no Drive); não consta no `.env.example` |
| `GOOGLE_ADS_DEVELOPER_TOKEN` | Developer token da Google Ads API | Cloud Run |
| `GOOGLE_ADS_OAUTH_REDIRECT_URI` | Callback OAuth do Ads; no deploy vem de `_DEV`/`_PROD` | Recurso (Ads) |
| `GOOGLE_ADS_OAUTH_REDIRECT_URI_DEV`, `_PROD` | Só no `.env`; o renderizador escolhe uma e a grava como `GOOGLE_ADS_OAUTH_REDIRECT_URI` (HTTPS, caminho `/api/google-ads/oauth/callback`, sem localhost) | Cloud Run (a do ambiente) |
| `GOOGLE_ADS_SESSION_ENCRYPTION_KEY` | Segredo aleatório longo que cifra a sessão do Ads | Cloud Run |

## Autenticação

| Variável | Finalidade | Obrigatória |
|---|---|---|
| `ALLOWED_DOMAINS` | Domínios extras de e-mail (`@dp6.com.br` é sempre aceito); padrão `dp6.com.br` | Cloud Run |
| `EMAIL_OTP_ENABLED` | Liga o login por OTP (ignorado em produção) | Cloud Run |
| `EMAIL_OTP_TTL_SECONDS` | Validade do código (padrão 600) | Não |
| `EMAIL_SESSION_TTL_HOURS` | Validade da sessão (padrão 24) | Não |
| `SENDGRID_API_KEY` | Envio do OTP; vazio = código no log | Cloud Run |
| `EMAIL_FROM_ADDRESS`, `EMAIL_FROM_NAME` | Remetente do OTP | Não |
| `DEV_USER_EMAIL`, `DEV_USER_NAME` | Usuário do modo dev; o nome é usado no perfil, e o e-mail só é exigido pelo renderizador | Cloud Run (`DEV_USER_EMAIL`) |
| `MASTER_ACCESS_TOKEN` | Token de acesso direto. **Padrão inseguro**: sobrescreva em produção | Cloud Run |

Ver [Autenticação](../visao-geral-e-arquitetura/autenticacao.md).

## Integrações

| Variável | Finalidade | Obrigatória |
|---|---|---|
| `OBSERVEPOINT_API_KEY` | Chave da API ObservePoint | Cloud Run |
| `OBSERVEPOINT_BASE_URL` | URL base (padrão `https://api.observepoint.com`) | Não |
| `GEMINI_API_KEY` | Considerações e insights de transcrições; o serviço copia o valor para o ambiente do processo | Recurso (IA); fora do `.env.example` |
| `DS30_APPS_SCRIPT_URL` | URL `/exec` do Web App do Apps Script (validada por regex) | Recurso (gerar documento) |
| `DS30_APPS_SCRIPT_SECRET` | Segredo enviado como `Bearer` ao Apps Script | Recurso (gerar documento) |

Ver [Apps Script](../integracoes/apps-script.md), [ObservePoint](../integracoes/observepoint.md) e [IA Gemini](../integracoes/ia-gemini.md).

## Firestore (fora do `Settings`)

Comentadas no `.env.example`, lidas pelas bibliotecas Google:

| Variável | Finalidade |
|---|---|
| `GOOGLE_APPLICATION_CREDENTIALS` | Chave de service account no desenvolvimento local (no Cloud Run vale a ADC da instância) |
| `FIRESTORE_EMULATOR_HOST` | Aponta para o emulador do Firestore |

Ver [Firebase](../integracoes/firebase.md).
