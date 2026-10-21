---
title: "Router Auth"
description: "Rutas /api/auth: configuración pública, usuario actual, OTP por correo y logout."
sidebar_position: 2
---

# Router Auth

Prefijo `/api/auth`, registrado **sin** `Depends` de router (`backend/main.py:39`). Solo `/me` exige autenticación. Router: `backend/routers/auth.py`; servicio: `backend/services/auth_service.py` (`auth_service`). Modelo general en [Autenticación](../visao-geral-e-arquitetura/autenticacao.md).

## Rutas

| Método | Ruta | Auth | Entrada | Respuesta | Errores |
|---|---|---|---|---|---|
| GET | `/api/auth/config` | no | n/d | `google_client_id`, `email_otp_enabled`, `environment`, `allowed_domains` | n/d |
| GET | `/api/auth/me` | sí | n/d | `{"authenticated":true,"user":{...}}` | 401 |
| POST | `/api/auth/otp/request` | no | `{"email"}` | `{"ok":true,"message"}` (+ `dev_code` solo en dev sin SendGrid) | 400 |
| POST | `/api/auth/otp/verify` | no | `{"email","code"}` | `{"ok","message","session_token","user"}` | 400 |
| POST | `/api/auth/logout` | no | header `X-Email-Session` opcional | `{"ok":true,"message"}` | n/d |

Líneas: config `auth.py:20`, me `:31`, otp/request `:39`, otp/verify `:62`, logout `:84`.

## Implementación

- `config`: `email_otp_enabled` se fuerza a `false` cuando `ENVIRONMENT` es `prod`/`production` (`auth.py:22-24`).
- `otp/request`: en producción o con `EMAIL_OTP_ENABLED` falso devuelve 400. Delega en `auth_service.request_otp` (`auth_service.py:93`); el envío usa SendGrid (`:132`, timeout 5 s). Si `ENVIRONMENT == "development"` y no hay `SENDGRID_API_KEY`, la respuesta incluye `dev_code` (`auth.py:54-59`).
- `otp/verify`: bloqueado en producción; `auth_service.verify_otp` (`:154`) devuelve el token de sesión, y `verify_email_session` (`:189`) arma el `user`.
- `logout`: invalida la sesión en memoria mediante `logout_session` (`:301`); sin header, retorna ok de todos modos.

## Ejemplo

```bash
curl -X POST http://localhost:8000/api/auth/otp/request \
  -H "Content-Type: application/json" -d '{"email":"voce@exemplo.com"}'
# {"ok": true, "message": "...", "dev_code": "123456"}

curl -X POST http://localhost:8000/api/auth/otp/verify \
  -H "Content-Type: application/json" -d '{"email":"voce@exemplo.com","code":"123456"}'
# {"ok": true, "session_token": "<token>", "user": {"email": "voce@exemplo.com", ...}}

curl -H "X-Email-Session: <token>" http://localhost:8000/api/auth/me
```

## Puntos de atención

- OTP es solo para dev/homologación: en producción las dos rutas responden 400 incluso con credenciales correctas.
- `dev_code` solo existe fuera de producción sin SendGrid; nunca dependa de él en pruebas de entornos con SendGrid.
- `RequestOtpBody.email` es `str` (no `EmailStr`, a pesar del import en `auth.py:2`); la validación de dominio queda en el servicio.
- `logout` no exige auth y no afecta el inicio de sesión de Google (el backend no invalida el token de Google).
