---
title: "Router Transcripts"
description: "Rotas /api/transcripts: listar pastas de transcrições no Drive e analisar reuniões com Gemini."
sidebar_position: 9
---

# Router Transcripts

Prefixo `/api/transcripts`, autenticado pelo `Depends` do registro (as rotas não recebem `user`). Router: `backend/routers/transcripts.py` (36 linhas); serviços: `backend/services/drive_service.py` e `backend/services/transcript_insights_service.py`.

## Rotas

| Método | Caminho | Entrada | Resposta | Erros |
|---|---|---|---|---|
| GET | `/api/transcripts/folders` (`:18`) | query `parent_id` (padrão: pasta raiz fixa) | `{"folders":[{"id","name"}]}` | 502 |
| POST | `/api/transcripts/analyze` (`:27`) | `{"folder_id"}` | JSON mesclado dos tópicos analisados | 422, 502, 503 |

## Implementação

- `folders`: `drive_service.list_folder` (`drive_service.py:54`) lista a pasta com a **conta publicadora** (mesma do relatório), paginando de 200 em 200 e incluindo Shared Drives; o router filtra só `application/vnd.google-apps.folder`.
- `analyze`: `analyze_transcripts` (`transcript_insights_service.py:85`) exige `GEMINI_API_KEY`, lista a pasta, separa Google Docs (422 se nenhum), exporta o texto de todos em paralelo (`export_doc_text`) e roda uma análise Gemini por tópico, também em paralelo (`asyncio.gather`). Os resultados dos tópicos são mesclados em um dict.
- Mapeamento de erros (`transcripts.py:30-36`): `ValueError` (sem chave) vira 503; `HTTPException` do serviço passa intacta (422/502); o resto vira 502 `Erro ao analisar transcrições com IA: ...`. Ver [IA Gemini](../integracoes/ia-gemini.md).

## Exemplo

```bash
curl -H "Authorization: Bearer <id_token>" \
  "http://localhost:8000/api/transcripts/folders"
# {"folders":[{"id":"<folder_id>","name":"Cliente Exemplo"}]}

curl -X POST http://localhost:8000/api/transcripts/analyze \
  -H "Authorization: Bearer <id_token>" -H "Content-Type: application/json" \
  -d '{"folder_id":"<folder_id>"}'
```

## Pontos de atenção

- O ID da pasta raiz está hard-coded em `transcripts.py:10` (Shared Drive "06. Transcrições", alimentado por automação de notas de reunião). Mudar de pasta exige alterar o código.
- Qualquer usuário autenticado pode listar/analisar qualquer pasta que a conta publicadora enxergue: não há checagem de projeto ou de papel.
- Falha parcial é tolerada: tópicos que falham são ignorados (só log); apenas se **todos** falharem a primeira exceção é propagada.
- O conteúdo de todas as transcrições vai em um único bloco de prompt; pastas grandes podem estourar o contexto do modelo e virar 502.
- Sem timeout explícito no Gemini; o limite prático é o da plataforma (Cloud Run).
