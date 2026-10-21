---
title: "Audit router"
description: "/api/audit routes: uploading GTM JSONs for auditing and generating AI considerations."
sidebar_position: 3
---

# Audit router

Prefix `/api/audit`, protected by the registration's `Depends(get_current_user)`. Router: `backend/routers/audit.py`. Services: `backend/services/audit_service.py`, `backend/services/considerations_service.py`.

## Routes

| Method | Path | Input | Response | Errors |
|---|---|---|---|---|
| POST | `/api/audit/upload` (`audit.py:29`) | multipart: `files` (1+ GTM JSON), `project_id?`, `report_id?` | consolidated payload (`process_multiple_containers`) | 400 |
| POST | `/api/audit/considerations` (`audit.py:19`) | JSON `{"payload": {...}, "platform": "gtm"}` | `{"considerations": "<text>"}` | 503, 502 |

## Upload flow

1. Each file is read, decoded as UTF-8 and parsed (`audit.py:40-44`).
2. `process_single_container` (`audit_service.py:5`) calls `analyze_gtm_json` and tags each item with `source_json_file`.
3. `process_multiple_containers` (`audit_service.py:20`) consolidates everything into a canonical payload.
4. If both `project_id` **and** `report_id` were sent, it writes a `gtm_json` run with `save_run_safe` in a threadpool (`audit.py:56-58`).

## Considerations (AI)

`generate_considerations` (`considerations_service.py:136`) picks the platform config, requires `GEMINI_API_KEY` and runs an ADK agent with the `gemini-3.5-flash-lite` model in `InMemoryRunner`. Error mapping in the router (`audit.py:22-27`): `ValueError` (unknown platform or missing key) becomes 503; any other exception becomes 502. See [Gemini AI](../integracoes/ia-gemini.md).

## Example

```bash
curl -X POST http://localhost:8000/api/audit/upload \
  -H "Authorization: Bearer <id_token>" \
  -F "files=@container_web.json" -F "files=@container_server.json" \
  -F "project_id=<project_id>" -F "report_id=<report_id>"
```

```bash
curl -X POST http://localhost:8000/api/audit/considerations \
  -H "Authorization: Bearer <id_token>" -H "Content-Type: application/json" \
  -d '{"platform":"gtm","payload":{"gtm_containers":[]}}'
# {"considerations": "texto gerado pela IA"}
```

## Caveats

- The loop's `except Exception` (`audit.py:49-50`) also catches the inner `HTTPException` from `audit.py:47`, so the final message comes nested: `Erro ao ler arquivo X: 400: Erro ao processar X: ...` (Error reading file X: 400: Error processing X: ...). The status is still 400.
- One invalid file aborts the whole batch; nothing is partially saved.
- Without `project_id` or without `report_id`, nothing is persisted. A failure to write the run does not affect the response (`*_safe`).
- The `if not files` validation (`audit.py:37`) is rarely reached: `File(...)` already returns 422 when files are missing.
