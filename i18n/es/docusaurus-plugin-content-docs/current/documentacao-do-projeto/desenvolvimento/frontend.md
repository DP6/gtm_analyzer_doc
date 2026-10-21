---
title: "Frontend"
description: "Stack, estructura de carpetas, rutas, pestañas del workspace, estado del payload, autosave y cliente HTTP del frontend DS30."
sidebar_position: 3
---

# Frontend

:::warning CLAUDE.md desactualizado
El `CLAUDE.md` del repositorio de la app todavía describe una SPA de página única con `TABS` en `App.jsx`. El código actual usa rutas (`react-router-dom`) y las pestañas están en `ReportWorkspace.jsx`. Esta página refleja el código.
:::

## Stack

React 18, Vite 5, Tailwind 3, `react-router-dom` 6 y `lucide-react` (`frontend/package.json`). Sin formatter/linter: indentación de 2 espacios, `PascalCase` para componentes, `camelCase` para el resto.

## Carpetas (`frontend/src/`)

| Carpeta | Contenido |
|---|---|
| `components/` | pantallas y bloques de UI (`ProjectGrid`, `ReportWorkspace`, `CrawlerScanner`, `GoogleAdsAnalyzer`, `DriveReportGenerator`, ...) |
| `context/` | `AuthContext.jsx` |
| `services/` | `api.js`, único cliente HTTP |
| `utils/` | `payloadHelpers.js`, `crawlerUrls.js`, `reportFieldConfig.js`, `tags.js` y pruebas |

## Rutas (`App.jsx`)

Sin usuario autenticado, aparece la pantalla "Autenticação Requerida" (Autenticación requerida). Con usuario:

| Ruta | Componente |
|---|---|
| `/` | `ProjectGrid` |
| `/projects/:projectId` | `ProjectShell` (layout) |
| `/projects/:projectId` (index) | `ReportList` |
| `.../settings` | `ProjectSettings` |
| `.../reports/new` | `ReportCreate` |
| `.../reports/:reportId` | `ReportWorkspace` |
| cualquier otra | redirige a `/` |

## Pestañas del workspace

`TABS` en `ReportWorkspace.jsx:16`: `transcripts` (Transcrições), `overview` (Visão Geral / GTG), `gtm` (Auditoria GTM), `ga` (Google Analytics), `google_ads`, `oci` (OCI / ECL), `eco`, `report` (Diagnóstico) e `history` (Histórico). Las etiquetas entre paréntesis son los textos de la UI, que están en portugués (transcripciones, visión general, auditoría, diagnóstico, historial). La pestaña activa viene del parámetro de URL `tab` cuando es válido; predeterminado `overview` (o `google_ads` si la URL tiene `google_ads`).

## Estado del payload y autosave

Todas las pestañas comparten un único `payload`, combinado progresivamente con `mergePayload` (`utils/payloadHelpers.js`). Ese objeto es el contrato enviado al backend (vea [Payload v3](../geracao-do-documento/payload-v3.md)).

Autosave (`ReportWorkspace.jsx:22,81-85`):

- Cada cambio de `payload` agenda `updateReport(project.id, reportId, { payload })` tras `AUTOSAVE_DELAY_MS = 1500` ms (debounce).
- `skipNextAutosave` (ref) evita volver a guardar justo después de cargar el informe desde el servidor.
- Las fallas se tragan (`.catch(() => {})`): el usuario no ve error si el guardado falla.

## Cliente HTTP (`services/api.js`)

Una función por endpoint, todas bajo `/api`. `getAuthHeaders()` lee `localStorage` y define **un** encabezado, en esta prioridad: `gtm_auth_google_token` (`Authorization: Bearer`), `gtm_auth_email_session` (`X-Email-Session`), `gtm_auth_access_token` (`X-Access-Token`), `gtm_auth_dev_email` (`X-Dev-User-Email`). Los tokens de inicio de sesión quedan en `localStorage` (no en cookie). Backend: [Autenticación](../visao-geral-e-arquitetura/autenticacao.md).

## Crawler

`CrawlerScanner.jsx` guarda el scan activo en `localStorage` por informe (`scanKey(reportId)`) y consulta `pollWebsiteScan` cada 5 s; al concluir o fallar, elimina la clave. Así el scan sobrevive a recargar la página. API: [Crawler](../api/crawler.md).

## Dev y producción

- Dev: Vite en `:5173` con proxy `/api` hacia `http://localhost:8000` (`vite.config.js`).
- Producción: `npm run build` en la etapa 1 del Dockerfile; el `dist` se copia a `backend/static` y lo sirve FastAPI como SPA ([Despliegue](./deploy.md)).
