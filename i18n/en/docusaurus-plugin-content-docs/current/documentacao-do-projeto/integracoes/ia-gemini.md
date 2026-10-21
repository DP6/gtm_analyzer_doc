---
title: "AI (Gemini)"
description: "AI-generated considerations and transcript insight extraction with Gemini, models used, errors and how to add platforms and topics."
sidebar_position: 5
---

# AI (Gemini)

Two services use Gemini, both with the `GEMINI_API_KEY` variable (name only; see [Environment variables](../referencia/variaveis-de-ambiente.md)). Without it, both fail with `ValueError`, which the routes convert to 503. The project's general conventions for agents and AI are in [AGENTS.md](../ia-e-agentes/agents-md.md).

| Service | File | Library | Model |
|---|---|---|---|
| Considerations | `backend/services/considerations_service.py` | `google-adk` (`Agent` + `InMemoryRunner`) | `gemini-3.5-flash-lite` (`:150`) |
| Transcript insights | `backend/services/transcript_insights_service.py` | `google-genai` (`generate_content`) | `gemini-3.5-flash-lite` (`MODEL_NAME`, `:19`) |

The model name is hard-coded in both places; changing it requires editing both.

## Considerations per platform

`generate_considerations(platform, payload, user_id)` (`considerations_service.py:136`) writes the free text of each `*_considerations` field from what is already in the payload. Route: `POST /api/audit/considerations` (`backend/routers/audit.py:17`), see [Audit API](../api/audit.md).

- **`PLATFORM_CONFIG`** (`:6`): one item per platform (`overview`, `gtm`, `ga`, `google_ads`, `oci`, `eco`) with `prefixes` (scalar fields sent), `collections` (lists sent, with optional filter) and `instruction` (system prompt).
- **`_evidence`** (`:128`): builds the object sent to the model. Only fields whose name starts with one of the `prefixes` are included, plus the filtered collections. The rest of the payload is never sent. Example: `ga` sends `ga_*` fields, `platform_accounts` and `conversion_actions` from `google_analytics`.
- **Execution**: creates an `Agent` with the platform's instruction, an in-memory session and sends `Auditoria:\n<json>` (Audit); returns the final text. An empty response becomes `RuntimeError`.
- **Prompt rules**: Brazilian Portuguese, up to 3 paragraphs, only the evidence provided, `null` does not mean absence, distinguish "not configured" from "not analyzed", no headings, Markdown or technical field names.
- **Errors**: unknown platform and missing key are `ValueError` and the route responds 503; any other failure responds 502 with the message. An unknown platform also returns 503 (not 4xx).

### How to add a platform

1. Add a key to `PLATFORM_CONFIG` with `prefixes`, `collections` and `instruction` following the rules above.
2. Make sure the corresponding `*_considerations` field exists in the payload ([Payload v3](../geracao-do-documento/payload-v3.md)) and is rendered in Apps Script ([Apps Script internals](../geracao-do-documento/apps-script-por-dentro.md)).
3. Call the route with `platform` equal to the new key from the frontend.
4. Add a case in `backend/tests/test_considerations_service.py` verifying `_evidence`.

## Transcript insights

`analyze_transcripts(folder_id)` (`transcript_insights_service.py`) extracts payload fields from meetings recorded as Google Docs. Routes in `backend/routers/transcripts.py` (see [Transcripts API](../api/transcripts.md)): `GET /folders` lists subfolders of the transcripts root folder, `POST /analyze` processes a folder.

Flow:

1. `drive_service.list_folder` lists the folder with the publisher account (`backend/services/drive_service.py:54`); only Google Doc files are included. No docs: 422.
2. `drive_service.export_doc_text` exports each doc as text, in parallel; the texts are concatenated with the file name.
3. **Four topics** in parallel (`TOPIC_CONFIG`): `gtg_infra`, `upd_ga4`, `enhanced_conversions`, `offline`. Each has a Pydantic schema in `backend/models/transcript_insights.py` and a focused instruction (`COMMON_INSTRUCTION` plus the topic's focus).
4. `_analyze_topic` calls `generate_content` with `response_mime_type="application/json"` and the topic's `response_schema`; the result is `model_dump(exclude_none=True)`. Fields with allowed values use `Literal`; without clear evidence, the field stays null.
5. The topic results are merged into a single dictionary. A topic's failure is logged and ignored; only if all fail is the first exception rethrown.

**Route errors** (`transcripts.py:28`): `ValueError` (missing key) becomes 503, Drive's `HTTPException` passes straight through (for example 502 for an inaccessible folder), the rest becomes 502. In the frontend, the result enters the payload with the `ai_transcript` source and the automatic suggestions remain subject to user editing.

### How to add a topic

1. Create a Pydantic model with `Optional` fields in `backend/models/transcript_insights.py`; use `Literal` for fixed values and names identical to the payload fields.
2. Add the entry in `TOPIC_CONFIG` with the schema and the instruction (`COMMON_INSTRUCTION` + focus).
3. Confirm that the frontend knows how to display the new fields and that `recomputeDecisions` uses them when there is a derived decision.
4. Add a test in `backend/tests/test_transcript_insights_service.py`.

## Cautions

- The considerations prompt receives client data (URLs, account IDs, container names); treat it as traffic to an external service.
- Both instructions forbid inventing data, but there is no later validation of the text: the user reviews it before generating the document.
