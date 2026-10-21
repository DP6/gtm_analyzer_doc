---
title: "Legacy and obsolete documents"
description: "Inventory of legacy or outdated code, files and branches in the DS30 repository, with the status of each."
sidebar_position: 2
---

# Legacy and obsolete documents

Inventory verified against the app repository. Do not use these items as a source of truth.

## Documentation

| Item | Status |
|---|---|
| `README.md`: file tree and API table (`/api/report/docx`, `/api/report/template-fields`) | obsolete; the Git and deploy sections remain current |
| `CLAUDE.md`: description of the frontend as an SPA with `TABS` in `App.jsx` | outdated (today there are routes and `ReportWorkspace.jsx`) |
| `mudancas_doc.md` (root) | working notes, not documentation; unused in the code |
| `Alteração_config.md` (root) | plan for reorganizing the settings tab; not a reference |
| `GTG-CDN-Detector_and_Decompiler_integrationplan.md` (root) | integration plan; not a reference for the current state |

## Code and files from the `.docx` flow

| Item | Status |
|---|---|
| `/api/report/docx` and `/api/report/template-fields` | removed (commit `7ee559a`, breaking) |
| `backend/doc_generator.py` | no route; imported only by `backend/tests/test_docx_generation_with_observepoint_payload.py` and `test_cdn_analyzer.py` |
| `backend/DS30_Diagnostico_Tecnico_Template*.docx` and `Docs/DS30_..._Template_v3_5_...docx` | templates from the old flow |
| `Docs/DS30_Diagnostico_Tecnico_variable_mapping_v2_arrays.json` | v2 mapping, not read by the current code |
| `Docs/DS30_Diagnostico_Tecnico_payload_example_v2.json` | superseded schema 2.0.0; use v3 ([Payload v3](../geracao-do-documento/payload-v3.md)) |
| `Dockerfile:31-32` | still copies the `.docx` and the v2 mapping into the image ([Deploy](../desenvolvimento/deploy.md)) |
| `Docs/ds30_appscript.js` | single-file version; what counts is `Docs/ds30_appscript/` ([Apps Script internals](../geracao-do-documento/apps-script-por-dentro.md)) |
| `Docs/schema.sql` | reference SQL schema (current persistence is Firestore); only `Docs/example.py` references it |
| `backend/modules/*` | only `__pycache__` and `tests` folders without `.py`; no code |
| `backend/modules/**/__pycache__` | cache ignored by git; can be deleted locally |

## Environment junk

| Item | Status |
|---|---|
| `*:Zone.Identifier` files (one for almost every file, e.g. `AGENTS.md:Zone.Identifier`) | Windows/WSL metadata; they show up as untracked in `git status` and generate "ignoring ref with broken name" warnings. They can be deleted |

## Branches

| Branch | Status |
|---|---|
| `master`, `Database_integration`, `app-scripts-integration`, `new_template_and_application_changes` | legacy; do not resume or merge without review |
| `refator/documentation-and-ai-use` | name with a typo (`refator`); has 1 commit that `dev` does not have; treat as legacy |

Branch rules: [Git and commits](../desenvolvimento/git-e-commits.md).
