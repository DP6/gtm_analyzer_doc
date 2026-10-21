---
title: "IA (Gemini)"
description: "Consideraciones generadas por IA y extracción de insights de transcripciones con Gemini, modelos usados, errores y cómo agregar plataformas y temas."
sidebar_position: 5
---

# IA (Gemini)

Dos servicios usan Gemini, ambos con la variable `GEMINI_API_KEY` (solo el nombre; ver [Variables de entorno](../referencia/variaveis-de-ambiente.md)). Sin ella, los dos fallan con `ValueError`, que las rutas convierten en 503. Las convenciones generales de agentes e IA del proyecto están en [AGENTS.md](../ia-e-agentes/agents-md.md).

| Servicio | Archivo | Biblioteca | Modelo |
|---|---|---|---|
| Consideraciones | `backend/services/considerations_service.py` | `google-adk` (`Agent` + `InMemoryRunner`) | `gemini-3.5-flash-lite` (`:150`) |
| Insights de transcripciones | `backend/services/transcript_insights_service.py` | `google-genai` (`generate_content`) | `gemini-3.5-flash-lite` (`MODEL_NAME`, `:19`) |

El nombre del modelo está fijo en el código en los dos lugares; cambiarlo exige editar ambos.

## Consideraciones por plataforma

`generate_considerations(platform, payload, user_id)` (`considerations_service.py:136`) escribe el texto libre de cada campo `*_considerations` a partir de lo que ya está en el payload. Ruta: `POST /api/audit/considerations` (`backend/routers/audit.py:17`), ver [API audit](../api/audit.md).

- **`PLATFORM_CONFIG`** (`:6`): un ítem por plataforma (`overview`, `gtm`, `ga`, `google_ads`, `oci`, `eco`) con `prefixes` (campos escalares enviados), `collections` (listas enviadas, con filtro opcional) e `instruction` (prompt de sistema).
- **`_evidence`** (`:128`): arma el objeto enviado al modelo. Solo entran campos cuyo nombre empieza con uno de los `prefixes`, más las colecciones filtradas. El resto del payload nunca se envía. Ejemplo: `ga` envía campos `ga_*`, `platform_accounts` y `conversion_actions` de `google_analytics`.
- **Ejecución**: crea un `Agent` con la instrucción de la plataforma, una sesión en memoria y envía `Auditoria:\n<json>`; devuelve el texto final. Una respuesta vacía se convierte en `RuntimeError`.
- **Reglas de los prompts**: portugués brasileño, hasta 3 párrafos, solo evidencias suministradas, `null` no significa ausencia, diferenciar "no configurado" de "no analizado", sin títulos, Markdown ni nombres de campos técnicos.
- **Errores**: plataforma desconocida y clave ausente son `ValueError` y la ruta responde 503; cualquier otra falla responde 502 con el mensaje. Una plataforma desconocida también retorna 503 (no 4xx).

### Cómo agregar una plataforma

1. Agregue una clave en `PLATFORM_CONFIG` con `prefixes`, `collections` e `instruction` siguiendo las reglas anteriores.
2. Garantice que el campo `*_considerations` correspondiente exista en el payload ([Payload v3](../geracao-do-documento/payload-v3.md)) y se renderice en Apps Script ([Apps Script por dentro](../geracao-do-documento/apps-script-por-dentro.md)).
3. Llame a la ruta con `platform` igual a la nueva clave desde el frontend.
4. Agregue un caso en `backend/tests/test_considerations_service.py` verificando `_evidence`.

## Insights de transcripciones

`analyze_transcripts(folder_id)` (`transcript_insights_service.py`) extrae campos del payload a partir de reuniones grabadas como Google Docs. Rutas en `backend/routers/transcripts.py` (ver [API transcripciones](../api/transcripts.md)): `GET /folders` lista subcarpetas de la carpeta raíz de transcripciones, `POST /analyze` procesa una carpeta.

Flujo:

1. `drive_service.list_folder` lista la carpeta con la cuenta publicadora (`backend/services/drive_service.py:54`); solo entran archivos de tipo Google Doc. Ningún doc: 422.
2. `drive_service.export_doc_text` exporta cada doc como texto, en paralelo; los textos se concatenan con el nombre del archivo.
3. **Cuatro temas** en paralelo (`TOPIC_CONFIG`): `gtg_infra`, `upd_ga4`, `enhanced_conversions`, `offline`. Cada uno tiene un schema Pydantic en `backend/models/transcript_insights.py` y una instrucción enfocada (`COMMON_INSTRUCTION` más el foco del tema).
4. `_analyze_topic` llama a `generate_content` con `response_mime_type="application/json"` y `response_schema` del tema; el resultado es `model_dump(exclude_none=True)`. Los campos con valores permitidos usan `Literal`; sin evidencia clara, el campo queda nulo.
5. Los resultados de los temas se combinan en un único diccionario. La falla de un tema se registra y se ignora; solo si todos fallan se relanza la primera excepción.

**Errores de la ruta** (`transcripts.py:28`): `ValueError` (clave ausente) pasa a 503, el `HTTPException` de Drive pasa directo (por ejemplo 502 por carpeta inaccesible), el resto pasa a 502. En el frontend, el resultado entra en el payload con la fuente `ai_transcript` y las sugerencias automáticas siguen sujetas a edición del usuario.

### Cómo agregar un tema

1. Cree un modelo Pydantic con campos `Optional` en `backend/models/transcript_insights.py`; use `Literal` para valores fijos y nombres iguales a los campos del payload.
2. Agregue la entrada en `TOPIC_CONFIG` con el schema y la instrucción (`COMMON_INSTRUCTION` + foco).
3. Confirme que el frontend sepa mostrar los nuevos campos y que `recomputeDecisions` los use cuando hay decisión derivada.
4. Agregue una prueba en `backend/tests/test_transcript_insights_service.py`.

## Cuidados

- El prompt de consideraciones recibe datos del cliente (URLs, IDs de cuentas, nombres de containers); trátelo como tráfico hacia un servicio externo.
- Las dos instrucciones prohíben inventar datos, pero no hay validación posterior del texto: el usuario revisa antes de generar el documento.
