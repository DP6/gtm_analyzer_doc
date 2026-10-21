---
title: "Autenticação e autorização"
description: "Os quatro métodos de autenticação em ordem de prioridade, papéis, OTP, rotas públicas e autorização por projeto."
sidebar_position: 3
---

# Autenticação e autorização

`get_current_user` (`backend/deps.py`) delega a `AuthService.authenticate_request` (`backend/services/auth_service.py:259`), que testa os métodos abaixo **nesta ordem**; o primeiro que validar vence. Sem nenhum válido, a API responde **401**.

| # | Método | Como é enviado | Papel resultante |
|---|---|---|---|
| 1 | Google Sign-In | `Authorization: Bearer <id_token>` | `admin` se `@dp6.com.br`, senão `user` |
| 2 | Sessão por e-mail OTP | `X-Email-Session: <token>` | `admin` se `@dp6.com.br`, senão `user` |
| 3 | Token de acesso | `X-Access-Token` ou `?token=` | `viewer` (e-mail fixo `access-token@dp6.com.br`, `is_dp6=true`) |
| 4 | Modo dev | `X-Dev-User-Email` | `admin`; só com `ENVIRONMENT=development` |

Regras de cada método:

1. **Google**: valida o JWT com a audiência `GOOGLE_CLIENT_ID`, exige `email_verified` e domínio permitido (`auth_service.py:55`). `@dp6.com.br` é sempre permitido; outros precisam estar em `ALLOWED_DOMAINS` (`auth_service.py:29`).
2. **OTP**: ver abaixo.
3. **Token de acesso**: compara com `MASTER_ACCESS_TOKEN` via `secrets.compare_digest` (`auth_service.py:216`).
4. **Dev**: exige o cabeçalho; `DEV_USER_EMAIL` não é usado como fallback na prática, apesar do docstring (`auth_service.py:237-257`).

O frontend envia o método disponível a partir do `localStorage` (`frontend/src/services/api.js:8-25`).

## E-mail OTP

- Código de **4 dígitos**, guardado como SHA-256, validade `EMAIL_OTP_TTL_SECONDS` (padrão 600 s).
- Rate limit: 3 pedidos por e-mail em 10 min. Até 3 tentativas erradas por código.
- Sucesso gera sessão de 256 bits (`secrets.token_hex(32)`) com validade `EMAIL_SESSION_TTL_HOURS` (padrão 24 h).
- Envio via SendGrid; sem `SENDGRID_API_KEY` o código vai para o log. Em `development` sem SendGrid, a resposta de `/api/auth/otp/request` inclui `dev_code` (`backend/routers/auth.py:55-58`).
- Em produção (`ENVIRONMENT` = `prod`/`production`) o OTP é **desativado**: `/otp/request` responde 400 e `/api/auth/config` devolve `email_otp_enabled: false` (`routers/auth.py:21-28,42-47`).

## Rotas públicas

`/api/auth/config`, `/api/auth/otp/request`, `/api/auth/otp/verify`, `/api/auth/logout`, o callback `GET /api/google-ads/oauth/callback`, `/health`, `/api/health` e os arquivos da SPA. `/api/auth/me` exige autenticação. Todos os demais routers são protegidos (`backend/main.py:39-49`).

## Autorização por projeto

Feita nos routers com `has_access`/`is_owner` (`backend/services/firestore_service.py:65-70`), não por regras do Firestore.

| Situação | Resposta |
|---|---|
| Projeto inexistente | 404 |
| Usuário sem acesso (não é dono nem membro) | **404** (não revela que o projeto existe) (`routers/projects.py:63-68`) |
| Membro tentando ação exclusiva do dono (editar, excluir, gerenciar membros) | **403** "Apenas o dono do projeto pode fazer isso." (`routers/projects.py:71-75`) |

`save_run` também levanta `PermissionError` se o usuário não tiver acesso.

## Cuidados

- OTP, sessões e rate limit ficam **em memória** por instância: reiniciar ou escalar derruba as sessões (ver [Arquitetura](./arquitetura.md)).
- `MASTER_ACCESS_TOKEN` tem **valor padrão inseguro** em `backend/config.py`; sobrescreva em produção. O renderizador do Cloud Run exige a variável preenchida (`backend/scripts/render_cloudrun_env.py`).
- O token de acesso é aceito em query string, que pode vazar em logs e histórico.

Veja também [API de autenticação](../api/auth.md) e [Google OAuth](../integracoes/google-oauth.md).
