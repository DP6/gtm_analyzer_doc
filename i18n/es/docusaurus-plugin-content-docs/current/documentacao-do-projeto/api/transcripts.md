---
title: "Router Transcripts"
description: "Rutas /api/transcripts: listar carpetas de transcripciones en Drive y analizar reuniones con Gemini."
sidebar_position: 9
---

# Router Transcripts

Prefijo `/api/transcripts`, autenticado por el `Depends` del registro (las rutas no reciben `user`). Router: `backend/routers/transcripts.py` (36 líneas); servicios: `backend/services/drive_service.py` y `backend/services/transcript_insights_service.py`.

## Rutas

| Método | Ruta | Entrada | Respuesta | Errores |
|---|---|---|---|---|
| GET | `/api/transcripts/folders` (`:18`) | query `parent_id` (predeterminado: carpeta raíz fija) | `{"folders":[{"id","name"}]}` | 502 |
| POST | `/api/transcripts/analyze` (`:27`) | `{"folder_id"}` | JSON combinado de los temas analizados | 422, 502, 503 |

## Implementación

- `folders`: `drive_service.list_folder` (`drive_service.py:54`) lista la carpeta con la **cuenta publicadora** (la misma del informe), paginando de 200 en 200 e incluyendo Shared Drives; el router filtra solo `application/vnd.google-apps.folder`.
- `analyze`: `analyze_transcripts` (`transcript_insights_service.py:85`) exige `GEMINI_API_KEY`, lista la carpeta, separa los Google Docs (422 si no hay ninguno), exporta el texto de todos en paralelo (`export_doc_text`) y ejecuta un análisis Gemini por tema, también en paralelo (`asyncio.gather`). Los resultados de los temas se combinan en un dict.
- Mapeo de errores (`transcripts.py:30-36`): `ValueError` (sin clave) se convierte en 503; el `HTTPException` del servicio pasa intacto (422/502); el resto se convierte en 502 `Erro ao analisar transcrições com IA: ...` (Error al analizar transcripciones con IA). Ver [IA Gemini](../integracoes/ia-gemini.md).

## Ejemplo

```bash
curl -H "Authorization: Bearer <id_token>" \
  "http://localhost:8000/api/transcripts/folders"
# {"folders":[{"id":"<folder_id>","name":"Cliente Exemplo"}]}

curl -X POST http://localhost:8000/api/transcripts/analyze \
  -H "Authorization: Bearer <id_token>" -H "Content-Type: application/json" \
  -d '{"folder_id":"<folder_id>"}'
```

## Puntos de atención

- El ID de la carpeta raíz está hard-coded en `transcripts.py:10` (Shared Drive "06. Transcrições", alimentado por automatización de notas de reunión). Cambiar de carpeta exige modificar el código.
- Cualquier usuario autenticado puede listar/analizar cualquier carpeta que la cuenta publicadora vea: no hay verificación de proyecto ni de rol.
- Se tolera la falla parcial: los temas que fallan se ignoran (solo log); únicamente si **todos** fallan se propaga la primera excepción.
- El contenido de todas las transcripciones va en un único bloque de prompt; las carpetas grandes pueden desbordar el contexto del modelo y terminar en 502.
- Sin timeout explícito en Gemini; el límite práctico es el de la plataforma (Cloud Run).
