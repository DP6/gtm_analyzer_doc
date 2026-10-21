---
title: "IA (Gemini)"
description: "Considerações geradas por IA e extração de insights de transcrições com Gemini, modelos usados, erros e como acrescentar plataformas e tópicos."
sidebar_position: 5
---

# IA (Gemini)

Dois serviços usam Gemini, ambos com a variável `GEMINI_API_KEY` (nome apenas; ver [Variáveis de ambiente](../referencia/variaveis-de-ambiente.md)). Sem ela, os dois falham com `ValueError`, que as rotas convertem em 503. Convenções gerais de agentes e IA do projeto estão em [AGENTS.md](../ia-e-agentes/agents-md.md).

| Serviço | Arquivo | Biblioteca | Modelo |
|---|---|---|---|
| Considerações | `backend/services/considerations_service.py` | `google-adk` (`Agent` + `InMemoryRunner`) | `gemini-3.5-flash-lite` (`:150`) |
| Insights de transcrições | `backend/services/transcript_insights_service.py` | `google-genai` (`generate_content`) | `gemini-3.5-flash-lite` (`MODEL_NAME`, `:19`) |

O nome do modelo está fixo no código nos dois lugares; trocar exige editar ambos.

## Considerações por plataforma

`generate_considerations(platform, payload, user_id)` (`considerations_service.py:136`) escreve o texto livre de cada campo `*_considerations` a partir do que já está no payload. Rota: `POST /api/audit/considerations` (`backend/routers/audit.py:17`), ver [API audit](../api/audit.md).

- **`PLATFORM_CONFIG`** (`:6`): um item por plataforma (`overview`, `gtm`, `ga`, `google_ads`, `oci`, `eco`) com `prefixes` (campos escalares enviados), `collections` (listas enviadas, com filtro opcional) e `instruction` (prompt de sistema).
- **`_evidence`** (`:128`): monta o objeto enviado ao modelo. Só entram campos cujo nome começa com um dos `prefixes`, mais as coleções filtradas. O restante do payload nunca é enviado. Exemplo: `ga` envia campos `ga_*`, `platform_accounts` e `conversion_actions` do `google_analytics`.
- **Execução**: cria um `Agent` com a instrução da plataforma, uma sessão em memória e envia `Auditoria:\n<json>`; devolve o texto final. Resposta vazia vira `RuntimeError`.
- **Regras dos prompts**: português brasileiro, até 3 parágrafos, só evidências fornecidas, `null` não significa ausência, diferenciar "não configurado" de "não analisado", sem títulos, Markdown ou nomes de campos técnicos.
- **Erros**: plataforma desconhecida e chave ausente são `ValueError` e a rota responde 503; qualquer outra falha responde 502 com a mensagem. Uma plataforma desconhecida também retorna 503 (não 4xx).

### Como adicionar uma plataforma

1. Acrescente uma chave em `PLATFORM_CONFIG` com `prefixes`, `collections` e `instruction` seguindo as regras acima.
2. Garanta que o campo `*_considerations` correspondente exista no payload ([Payload v3](../geracao-do-documento/payload-v3.md)) e seja renderizado no Apps Script ([Apps Script por dentro](../geracao-do-documento/apps-script-por-dentro.md)).
3. Chame a rota com `platform` igual à nova chave pelo frontend.
4. Acrescente um caso em `backend/tests/test_considerations_service.py` verificando `_evidence`.

## Insights de transcrições

`analyze_transcripts(folder_id)` (`transcript_insights_service.py`) extrai campos do payload a partir de reuniões gravadas como Google Docs. Rotas em `backend/routers/transcripts.py` (ver [API transcrições](../api/transcripts.md)): `GET /folders` lista subpastas da pasta raiz de transcrições, `POST /analyze` processa uma pasta.

Fluxo:

1. `drive_service.list_folder` lista a pasta com a conta publicadora (`backend/services/drive_service.py:54`); só entram arquivos do tipo Google Doc. Nenhum doc: 422.
2. `drive_service.export_doc_text` exporta cada doc como texto, em paralelo; os textos são concatenados com o nome do arquivo.
3. **Quatro tópicos** em paralelo (`TOPIC_CONFIG`): `gtg_infra`, `upd_ga4`, `enhanced_conversions`, `offline`. Cada um tem um schema Pydantic em `backend/models/transcript_insights.py` e uma instrução focada (`COMMON_INSTRUCTION` mais o foco do tópico).
4. `_analyze_topic` chama `generate_content` com `response_mime_type="application/json"` e `response_schema` do tópico; o resultado é `model_dump(exclude_none=True)`. Campos com valores permitidos usam `Literal`; sem evidência clara, o campo fica nulo.
5. Os resultados dos tópicos são mesclados em um único dicionário. Falha de um tópico é registrada e ignorada; só se todos falharem a primeira exceção é relançada.

**Erros da rota** (`transcripts.py:28`): `ValueError` (chave ausente) vira 503, `HTTPException` do Drive passa direto (por exemplo 502 por pasta inacessível), o resto vira 502. No frontend, o resultado entra no payload com a fonte `ai_transcript` e as sugestões automáticas continuam sujeitas a edição do usuário.

### Como adicionar um tópico

1. Crie um modelo Pydantic com campos `Optional` em `backend/models/transcript_insights.py`; use `Literal` para valores fixos e nomes iguais aos campos do payload.
2. Acrescente a entrada em `TOPIC_CONFIG` com o schema e a instrução (`COMMON_INSTRUCTION` + foco).
3. Confirme que o frontend sabe exibir os novos campos e que `recomputeDecisions` os usa quando há decisão derivada.
4. Acrescente teste em `backend/tests/test_transcript_insights_service.py`.

## Cuidados

- O prompt de considerações recebe dados do cliente (URLs, IDs de contas, nomes de containers); trate como tráfego para um serviço externo.
- As duas instruções proíbem inventar dados, mas não há validação posterior do texto: o usuário revisa antes de gerar o documento.
