---
title: "Transcripts router"
description: "/api/transcripts routes: listing transcript folders in Drive and analyzing meetings with Gemini."
sidebar_position: 9
---

# Transcripts router

Prefix `/api/transcripts`, authenticated by the registration's `Depends` (the routes do not receive `user`). Router: `backend/routers/transcripts.py` (36 lines); services: `backend/services/drive_service.py` and `backend/services/transcript_insights_service.py`.

## Routes

| Method | Path | Input | Response | Errors |
|---|---|---|---|---|
| GET | `/api/transcripts/folders` (`:18`) | query `parent_id` (default: fixed root folder) | `{"folders":[{"id","name"}]}` | 502 |
| POST | `/api/transcripts/analyze` (`:27`) | `{"folder_id"}` | merged JSON of the analyzed topics | 422, 502, 503 |

## Implementation

- `folders`: `drive_service.list_folder` (`drive_service.py:54`) lists the folder with the **publisher account** (the same one used for the report), paginating 200 at a time and including Shared Drives; the router filters only `application/vnd.google-apps.folder`.
- `analyze`: `analyze_transcripts` (`transcript_insights_service.py:85`) requires `GEMINI_API_KEY`, lists the folder, separates Google Docs (422 if none), exports the text of all of them in parallel (`export_doc_text`) and runs one Gemini analysis per topic, also in parallel (`asyncio.gather`). The topic results are merged into a dict.
- Error mapping (`transcripts.py:30-36`): `ValueError` (no key) becomes 503; the service's `HTTPException` passes through intact (422/502); everything else becomes 502 `Erro ao analisar transcrições com IA: ...` (Error analyzing transcripts with AI: ...). See [Gemini AI](../integracoes/ia-gemini.md).

## Example

```bash
curl -H "Authorization: Bearer <id_token>" \
  "http://localhost:8000/api/transcripts/folders"
# {"folders":[{"id":"<folder_id>","name":"Cliente Exemplo"}]}

curl -X POST http://localhost:8000/api/transcripts/analyze \
  -H "Authorization: Bearer <id_token>" -H "Content-Type: application/json" \
  -d '{"folder_id":"<folder_id>"}'
```

## Caveats

- The root folder ID is hard-coded in `transcripts.py:10` (Shared Drive "06. Transcrições", fed by a meeting-notes automation). Changing folders requires changing the code.
- Any authenticated user can list/analyze any folder the publisher account can see: there is no project or role check.
- Partial failure is tolerated: topics that fail are ignored (log only); only if **all** fail is the first exception propagated.
- The content of all transcripts goes into a single prompt block; large folders can overflow the model's context and become 502.
- No explicit timeout on Gemini; the practical limit is the platform's (Cloud Run).
