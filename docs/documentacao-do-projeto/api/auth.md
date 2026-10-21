---
title: "Router Auth"
description: "Rotas /api/auth: configuração pública, usuário atual, OTP por e-mail e logout."
sidebar_position: 2
---

# Router Auth

Prefixo `/api/auth`, registrado **sem** `Depends` de router (`backend/main.py:39`). Só `/me` exige autenticação. Roteador: `backend/routers/auth.py`; serviço: `backend/services/auth_service.py` (`auth_service`). Modelo geral em [Autenticação](../visao-geral-e-arquitetura/autenticacao.md).

## Rotas

| Método | Caminho | Auth | Entrada | Resposta | Erros |
|---|---|---|---|---|---|
| GET | `/api/auth/config` | não | n/d | `google_client_id`, `email_otp_enabled`, `environment`, `allowed_domains` | n/d |
| GET | `/api/auth/me` | sim | n/d | `{"authenticated":true,"user":{...}}` | 401 |
| POST | `/api/auth/otp/request` | não | `{"email"}` | `{"ok":true,"message"}` (+ `dev_code` só em dev sem SendGrid) | 400 |
| POST | `/api/auth/otp/verify` | não | `{"email","code"}` | `{"ok","message","session_token","user"}` | 400 |
| POST | `/api/auth/logout` | não | header `X-Email-Session` opcional | `{"ok":true,"message"}` | n/d |

Linhas: config `auth.py:20`, me `:31`, otp/request `:39`, otp/verify `:62`, logout `:84`.

## Implementação

- `config`: `email_otp_enabled` é forçado a `false` quando `ENVIRONMENT` é `prod`/`production` (`auth.py:22-24`).
- `otp/request`: em produção ou com `EMAIL_OTP_ENABLED` falso devolve 400. Delega a `auth_service.request_otp` (`auth_service.py:93`); o envio usa SendGrid (`:132`, timeout 5 s). Se `ENVIRONMENT == "development"` e não há `SENDGRID_API_KEY`, a resposta inclui `dev_code` (`auth.py:54-59`).
- `otp/verify`: bloqueado em produção; `auth_service.verify_otp` (`:154`) devolve o token de sessão, e `verify_email_session` (`:189`) monta o `user`.
- `logout`: invalida a sessão em memória via `logout_session` (`:301`); sem header, retorna ok mesmo assim.

## Exemplo

```bash
curl -X POST http://localhost:8000/api/auth/otp/request \
  -H "Content-Type: application/json" -d '{"email":"voce@exemplo.com"}'
# {"ok": true, "message": "...", "dev_code": "123456"}

curl -X POST http://localhost:8000/api/auth/otp/verify \
  -H "Content-Type: application/json" -d '{"email":"voce@exemplo.com","code":"123456"}'
# {"ok": true, "session_token": "<token>", "user": {"email": "voce@exemplo.com", ...}}

curl -H "X-Email-Session: <token>" http://localhost:8000/api/auth/me
```

## Pontos de atenção

- OTP é só para dev/homologação: em produção as duas rotas respondem 400 mesmo com credenciais corretas.
- `dev_code` só existe fora de produção sem SendGrid; nunca dependa dele em testes de ambiente com SendGrid.
- `RequestOtpBody.email` é `str` (não `EmailStr`, apesar do import em `auth.py:2`); a validação de domínio fica no serviço.
- `logout` não exige auth e não afeta login Google (token do Google não é invalidado pelo backend).
