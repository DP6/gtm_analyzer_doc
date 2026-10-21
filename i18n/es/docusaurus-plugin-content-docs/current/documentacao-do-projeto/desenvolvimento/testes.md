---
title: "Pruebas"
description: "Cómo ejecutar y organizar las pruebas del backend (pytest) y del frontend (node:test) de DS30."
sidebar_position: 2
---

# Pruebas

## Comandos

| Objetivo | Comando |
|---|---|
| Backend (todo) | `cd backend && .venv/bin/python -m pytest tests` |
| Un archivo | `cd backend && .venv/bin/python -m pytest tests/test_audit_service.py` |
| Una prueba | `... pytest tests/test_audit_service.py::test_name` |
| Frontend | `cd frontend && npm test` (`node --test src/utils/*.test.js`) |
| Build del frontend | `cd frontend && npm run build` |

`pytest` no está en `backend/requirements.txt`; instálelo en el venv si es necesario. `tests/conftest.py` solo pone `backend/` en el `sys.path`.

## Organización del backend

20 archivos `test_*.py` en `backend/tests/`, más `conftest.py`, agrupados por área:

| Área | Archivos |
|---|---|
| Auditoría GTM | `test_audit_service.py`, `test_considerations_service.py`, `test_gtm_request_analyzer.py` |
| Google Ads | `test_google_ads_service.py`, `test_google_ads_api_service.py`, `test_google_ads_oauth_service.py` |
| GTM/GA4 y cuentas | `test_google_platform_service.py`, `test_project_google_accounts.py` |
| Crawler / ObservePoint / CDN | `test_crawler_service.py`, `test_observepoint_service.py`, `test_cdn_analyzer.py` |
| Informe y payload | `test_report_contract_v2.py`, `test_payload_helpers.py`, `test_docx_generation_with_observepoint_payload.py` |
| Persistencia / Drive | `test_firestore_service.py`, `test_drive_service.py` |
| Transcripciones | `test_transcript_insights_service.py` |
| Despliegue y tooling | `test_makefile_deploy.py`, `test_render_cloudrun_env.py`, `test_generate_google_refresh_token.py` |

Observaciones:

- A pesar del nombre, `test_report_contract_v2.py` prueba el flujo actual `POST /api/report/google-docs` (Apps Script), no el payload v2.
- `test_docx_generation_with_observepoint_payload.py` y `test_cdn_analyzer.py` dependen de `backend/doc_generator.py`, código heredado (vea [Heredado](../ia-e-agentes/legado-e-documentos-obsoletos.md)).
- Los directorios `backend/modules/*/tests` existen, pero no contienen archivos `.py`.

## Frontend

Solo utilidades: `src/utils/payloadHelpers.test.js`, `crawlerUrls.test.js`, `appsScript.test.js`, con `node:test` y `node:assert/strict`. No hay pruebas de componentes React.

## Qué cubren las pruebas (y qué no)

Las pruebas apuntan a **services** y helpers, no a los routers: la lógica de negocio vive en `services/` y `audits/`, y los handlers son delgados. Excepciones puntuales importan funciones de `routers.report` (`test_report_contract_v2.py`).

No hay CI en el repositorio (sin `.github/`) ni ningún umbral de cobertura. Ejecutar las dos suites y el build antes de integrar es responsabilidad de quien desarrolla.

## Convenciones

- Archivos `test_*.py`, funciones `test_<comportamiento>`.
- Frontend: `*.test.js` junto a la utilidad.
- Agregue una prueba de regresión al tocar: merge de payload (`payloadHelpers`), contratos de API, reglas de auditoría (`backend/audits/`), clasificación de Google Ads y generación del informe.
- Los cambios en el `Makefile` de despliegue deben mantener en verde `test_makefile_deploy.py` (vea [Despliegue](./deploy.md)).
