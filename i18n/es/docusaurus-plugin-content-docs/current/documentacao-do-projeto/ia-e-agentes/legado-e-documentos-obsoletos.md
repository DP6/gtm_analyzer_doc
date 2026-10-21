---
title: "Heredado y documentos obsoletos"
description: "Inventario de código, archivos y branches heredados o desactualizados en el repositorio de DS30, con el estado de cada uno."
sidebar_position: 2
---

# Heredado y documentos obsoletos

Inventario verificado contra el repositorio de la app. No use estos ítems como fuente de verdad.

## Documentación

| Ítem | Estado |
|---|---|
| `README.md`: árbol de archivos y tabla de API (`/api/report/docx`, `/api/report/template-fields`) | obsoleto; las secciones de Git y despliegue siguen vigentes |
| `CLAUDE.md`: descripción del frontend como SPA con `TABS` en `App.jsx` | desactualizado (hoy hay rutas y `ReportWorkspace.jsx`) |
| `mudancas_doc.md` (raíz) | notas de trabajo, no es documentación; sin uso en el código |
| `Alteração_config.md` (raíz) | plan de reorganización de la pestaña de configuraciones; no es referencia |
| `GTG-CDN-Detector_and_Decompiler_integrationplan.md` (raíz) | plan de integración; no es referencia del estado actual |

## Código y archivos del flujo `.docx`

| Ítem | Estado |
|---|---|
| `/api/report/docx` y `/api/report/template-fields` | eliminados (commit `7ee559a`, breaking) |
| `backend/doc_generator.py` | sin ruta; importado solo por `backend/tests/test_docx_generation_with_observepoint_payload.py` y `test_cdn_analyzer.py` |
| `backend/DS30_Diagnostico_Tecnico_Template*.docx` y `Docs/DS30_..._Template_v3_5_...docx` | plantillas del flujo antiguo |
| `Docs/DS30_Diagnostico_Tecnico_variable_mapping_v2_arrays.json` | mapeo v2, sin lectura por el código actual |
| `Docs/DS30_Diagnostico_Tecnico_payload_example_v2.json` | schema 2.0.0 superado; usar el v3 ([Payload v3](../geracao-do-documento/payload-v3.md)) |
| `Dockerfile:31-32` | todavía copia el `.docx` y el mapping v2 a la imagen ([Despliegue](../desenvolvimento/deploy.md)) |
| `Docs/ds30_appscript.js` | versión de un solo archivo; lo que vale es `Docs/ds30_appscript/` ([Apps Script por dentro](../geracao-do-documento/apps-script-por-dentro.md)) |
| `Docs/schema.sql` | esquema SQL de referencia (la persistencia actual es Firestore); solo `Docs/example.py` lo referencia |
| `backend/modules/*` | solo `__pycache__` y carpetas `tests` sin `.py`; ningún código |
| `backend/modules/**/__pycache__` | caché ignorada por git; puede borrarse localmente |

## Basura de entorno

| Ítem | Estado |
|---|---|
| Archivos `*:Zone.Identifier` (uno para casi cada archivo, ej. `AGENTS.md:Zone.Identifier`) | metadatos de Windows/WSL; aparecen como no rastreados en `git status` y generan avisos "ignoring ref with broken name". Pueden borrarse |

## Branches

| Branch | Estado |
|---|---|
| `master`, `Database_integration`, `app-scripts-integration`, `new_template_and_application_changes` | heredadas; no retomar ni combinar sin revisión |
| `refator/documentation-and-ai-use` | nombre con error de tipeo (`refator`); tiene 1 commit que `dev` no tiene; tratar como heredada |

Reglas de branches: [Git y commits](../desenvolvimento/git-e-commits.md).
