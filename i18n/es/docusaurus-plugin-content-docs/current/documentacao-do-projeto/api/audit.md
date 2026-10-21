---
title: "Router Audit"
description: "Rutas /api/audit: carga de JSONs de GTM para auditoría y generación de consideraciones con IA."
sidebar_position: 3
---

# Router Audit

Prefijo `/api/audit`, protegido por el `Depends(get_current_user)` del registro. Router: `backend/routers/audit.py`. Servicios: `backend/services/audit_service.py`, `backend/services/considerations_service.py`.

## Rutas

| Método | Ruta | Entrada | Respuesta | Errores |
|---|---|---|---|---|
| POST | `/api/audit/upload` (`audit.py:29`) | multipart: `files` (1+ JSON de GTM), `project_id?`, `report_id?` | payload consolidado (`process_multiple_containers`) | 400 |
| POST | `/api/audit/considerations` (`audit.py:19`) | JSON `{"payload": {...}, "platform": "gtm"}` | `{"considerations": "<texto>"}` | 503, 502 |

## Flujo de la carga

1. Cada archivo se lee, se decodifica como UTF-8 y se parsea (`audit.py:40-44`).
2. `process_single_container` (`audit_service.py:5`) llama a `analyze_gtm_json` y marca cada ítem con `source_json_file`.
3. `process_multiple_containers` (`audit_service.py:20`) consolida todo en un payload canónico.
4. Si llegaron `project_id` **y** `report_id`, guarda un run `gtm_json` con `save_run_safe` en threadpool (`audit.py:56-58`).

## Consideraciones (IA)

`generate_considerations` (`considerations_service.py:136`) elige la config de la plataforma, exige `GEMINI_API_KEY` y ejecuta un agente ADK con el modelo `gemini-3.5-flash-lite` en `InMemoryRunner`. Mapeo de errores en el router (`audit.py:22-27`): `ValueError` (plataforma desconocida o clave ausente) se convierte en 503; cualquier otra excepción se convierte en 502. Ver [IA Gemini](../integracoes/ia-gemini.md).

## Ejemplo

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

## Puntos de atención

- El `except Exception` del bucle (`audit.py:49-50`) también captura el `HTTPException` interno de `audit.py:47`, por lo que el mensaje final llega anidado: `Erro ao ler arquivo X: 400: Erro ao processar X: ...` (Error al leer el archivo X: 400: Error al procesar X: ...). El estado sigue siendo 400.
- Un archivo inválido aborta todo el lote; nada se guarda parcialmente.
- Sin `project_id` o sin `report_id` no se persiste nada. Una falla al guardar el run no afecta la respuesta (`*_safe`).
- La validación `if not files` (`audit.py:37`) rara vez se alcanza: `File(...)` ya devuelve 422 cuando faltan archivos.
