---
title: "Autenticación y autorización"
description: "Los cuatro métodos de autenticación en orden de prioridad, roles, OTP, rutas públicas y autorización por proyecto."
sidebar_position: 3
---

# Autenticación y autorización

`get_current_user` (`backend/deps.py`) delega en `AuthService.authenticate_request` (`backend/services/auth_service.py:259`), que prueba los métodos siguientes **en este orden**; gana el primero que valide. Si ninguno es válido, la API responde **401**.

| # | Método | Cómo se envía | Rol resultante |
|---|---|---|---|
| 1 | Google Sign-In | `Authorization: Bearer <id_token>` | `admin` si es `@dp6.com.br`, de lo contrario `user` |
| 2 | Sesión por correo OTP | `X-Email-Session: <token>` | `admin` si es `@dp6.com.br`, de lo contrario `user` |
| 3 | Token de acceso | `X-Access-Token` o `?token=` | `viewer` (correo fijo `access-token@dp6.com.br`, `is_dp6=true`) |
| 4 | Modo dev | `X-Dev-User-Email` | `admin`; solo con `ENVIRONMENT=development` |

Reglas de cada método:

1. **Google**: valida el JWT con la audiencia `GOOGLE_CLIENT_ID`, exige `email_verified` y un dominio permitido (`auth_service.py:55`). `@dp6.com.br` siempre está permitido; los demás deben estar en `ALLOWED_DOMAINS` (`auth_service.py:29`).
2. **OTP**: ver más abajo.
3. **Token de acceso**: se compara con `MASTER_ACCESS_TOKEN` mediante `secrets.compare_digest` (`auth_service.py:216`).
4. **Dev**: exige el encabezado; `DEV_USER_EMAIL` no se usa como fallback en la práctica, a pesar del docstring (`auth_service.py:237-257`).

El frontend envía el método disponible a partir de `localStorage` (`frontend/src/services/api.js:8-25`).

## Correo OTP

- Código de **4 dígitos**, almacenado como SHA-256, con vigencia `EMAIL_OTP_TTL_SECONDS` (predeterminado 600 s).
- Rate limit: 3 solicitudes por correo en 10 min. Hasta 3 intentos erróneos por código.
- El éxito genera una sesión de 256 bits (`secrets.token_hex(32)`) con vigencia `EMAIL_SESSION_TTL_HOURS` (predeterminado 24 h).
- Envío vía SendGrid; sin `SENDGRID_API_KEY` el código va al log. En `development` sin SendGrid, la respuesta de `/api/auth/otp/request` incluye `dev_code` (`backend/routers/auth.py:55-58`).
- En producción (`ENVIRONMENT` = `prod`/`production`) el OTP está **desactivado**: `/otp/request` responde 400 y `/api/auth/config` devuelve `email_otp_enabled: false` (`routers/auth.py:21-28,42-47`).

## Rutas públicas

`/api/auth/config`, `/api/auth/otp/request`, `/api/auth/otp/verify`, `/api/auth/logout`, el callback `GET /api/google-ads/oauth/callback`, `/health`, `/api/health` y los archivos de la SPA. `/api/auth/me` exige autenticación. Todos los demás routers están protegidos (`backend/main.py:39-49`).

## Autorización por proyecto

Se hace en los routers con `has_access`/`is_owner` (`backend/services/firestore_service.py:65-70`), no mediante reglas de Firestore.

| Situación | Respuesta |
|---|---|
| Proyecto inexistente | 404 |
| Usuario sin acceso (no es dueño ni miembro) | **404** (no revela que el proyecto existe) (`routers/projects.py:63-68`) |
| Miembro que intenta una acción exclusiva del dueño (editar, eliminar, gestionar miembros) | **403** "Apenas o dono do projeto pode fazer isso." (Solo el dueño del proyecto puede hacer esto.) (`routers/projects.py:71-75`) |

`save_run` también lanza `PermissionError` si el usuario no tiene acceso.

## Cuidados

- OTP, sesiones y rate limit se guardan **en memoria** por instancia: reiniciar o escalar tumba las sesiones (ver [Arquitectura](./arquitetura.md)).
- `MASTER_ACCESS_TOKEN` tiene un **valor predeterminado inseguro** en `backend/config.py`; sobrescríbalo en producción. El renderizador de Cloud Run exige la variable completa (`backend/scripts/render_cloudrun_env.py`).
- El token de acceso se acepta en query string, que puede filtrarse en logs e historial.

Vea también [API de autenticación](../api/auth.md) y [Google OAuth](../integracoes/google-oauth.md).
