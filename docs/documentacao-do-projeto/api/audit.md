---
title: "Router Audit"
description: "Rotas /api/audit: upload de JSONs do GTM para auditoria e geração de considerações com IA."
sidebar_position: 3
---

# Router Audit

Prefixo `/api/audit`, protegido pelo `Depends(get_current_user)` do registro. Router: `backend/routers/audit.py`. Serviços: `backend/services/audit_service.py`, `backend/services/considerations_service.py`.

## Rotas

| Método | Caminho | Entrada | Resposta | Erros |
|---|---|---|---|---|
| POST | `/api/audit/upload` (`audit.py:29`) | multipart: `files` (1+ JSON do GTM), `project_id?`, `report_id?` | payload consolidado (`process_multiple_containers`) | 400 |
| POST | `/api/audit/considerations` (`audit.py:19`) | JSON `{"payload": {...}, "platform": "gtm"}` | `{"considerations": "<texto>"}` | 503, 502 |

## Fluxo do upload

1. Cada arquivo é lido, decodificado como UTF-8 e parseado (`audit.py:40-44`).
2. `process_single_container` (`audit_service.py:5`) chama `analyze_gtm_json` e marca cada item com `source_json_file`.
3. `process_multiple_containers` (`audit_service.py:20`) consolida tudo em um payload canônico.
4. Se vieram `project_id` **e** `report_id`, grava um run `gtm_json` com `save_run_safe` em threadpool (`audit.py:56-58`).

## Considerações (IA)

`generate_considerations` (`considerations_service.py:136`) escolhe a config da plataforma, exige `GEMINI_API_KEY` e roda um agente ADK com o modelo `gemini-3.5-flash-lite` em `InMemoryRunner`. Mapeamento de erros no router (`audit.py:22-27`): `ValueError` (plataforma desconhecida ou chave ausente) vira 503; qualquer outra exceção vira 502. Ver [IA Gemini](../integracoes/ia-gemini.md).

## Exemplo

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

## Pontos de atenção

- O `except Exception` do loop (`audit.py:49-50`) também captura o `HTTPException` interno de `audit.py:47`, então a mensagem final vem aninhada: `Erro ao ler arquivo X: 400: Erro ao processar X: ...`. O status continua 400.
- Um arquivo inválido aborta o lote inteiro; nada é parcialmente salvo.
- Sem `project_id` ou sem `report_id` nada é persistido. Falha ao gravar o run não afeta a resposta (`*_safe`).
- A validação `if not files` (`audit.py:37`) raramente é atingida: `File(...)` já devolve 422 quando faltam arquivos.
