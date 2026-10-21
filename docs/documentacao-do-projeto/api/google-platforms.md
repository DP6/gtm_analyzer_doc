---
title: "Router Google Platforms"
description: "Rotas de GTM e GA4 via API do Google, usando a conexão OAuth compartilhada com o Google Ads."
sidebar_position: 8
---

# Router Google Platforms

Router único sem prefixo (`router = APIRouter(tags=["Google Platforms"])`), com caminhos completos nas rotas. Autenticado. Router: `backend/routers/google_platforms.py`; serviço: `backend/services/google_platform_service.py`. Ver [GTM e GA4](../integracoes/google-tag-manager-e-ga4.md) e [Google OAuth](../integracoes/google-oauth.md).

## Rotas

Todas exigem usuário autenticado **e** o cookie de conexão Google (`gtm_google_ads_session`, o mesmo do [Google Ads](./google-ads.md)).

| Método | Caminho | Entrada | Resposta | Erros |
|---|---|---|---|---|
| GET | `/api/gtm/accounts` (`:62`) | n/d | contas GTM | 401, 502, Google |
| GET | `/api/gtm/accounts/{account_id}/containers` (`:70`) | path | containers | 422, 401, Google |
| GET | `/api/gtm/accounts/{account_id}/containers/{container_id}/versions` (`:79`) | path | versões | 422, 401, Google |
| POST | `/api/gtm/analyze-live` (`:89`) | `{"version_path","project_id?","report_id?"}` | payload canônico GTM | 422, 401, Google |
| GET | `/api/google-analytics/properties` (`:109`) | n/d | propriedades GA4 | 401, Google |
| POST | `/api/google-analytics/analyze-live` (`:117`) | `{"property","start_date?","end_date?","project_id?","report_id?"}` | análise GA4 | 422, 401, Google |

`version_path` tem o formato `accounts/{a}/containers/{c}/versions/{v}`. `property` é `properties/{id}`.

## Implementação

- `_token` (`:44-51`): lê a conexão do cookie (`read_connection`) e troca o refresh token por um access token (`access_token`). Falha de conexão vira 401; qualquer outro erro, 502 `Não foi possível renovar a autorização do Google.`
- `_run` (`:54-59`): executa o serviço e converte `ValueError` em `HTTPException`. `GooglePlatformApiError` (subclasse de `ValueError`) mantém o `status_code` do Google (400, 401, 403, 404, 429; outros viram 502 em `google_platform_service.py:30`); `ValueError` comum vira 422.
- Chamadas ao Google usam `httpx` síncrono com timeout 30 s e paginação por `nextPageToken` com `pageSize=200` (`google_platform_service.py:17-45`).
- As rotas de listagem são `def` (rodam no threadpool do FastAPI); as `analyze-live` são `async`, mas chamam o serviço bloqueante direto (`_run`), só a gravação no Firestore usa `run_in_threadpool`.
- Persistência opcional: com `project_id` e `report_id`, `save_run_safe` grava run `live`. Se salvou, `record_google_accounts` registra `gtm_account_ids`/`gtm_container_ids` (extraídos de `version_path`) ou `ga4_property_ids` (`property` após a última `/`).

## Exemplo

```bash
curl -b "<cookie_da_sessao>" -H "Authorization: Bearer <id_token>" \
  http://localhost:8000/api/gtm/accounts

curl -b "<cookie_da_sessao>" -X POST http://localhost:8000/api/gtm/analyze-live \
  -H "Authorization: Bearer <id_token>" -H "Content-Type: application/json" \
  -d '{"version_path":"accounts/111/containers/222/versions/3"}'

curl -b "<cookie_da_sessao>" -X POST http://localhost:8000/api/google-analytics/analyze-live \
  -H "Authorization: Bearer <id_token>" -H "Content-Type: application/json" \
  -d '{"property":"properties/123456","start_date":"2026-01-01","end_date":"2026-01-31"}'
```

## Pontos de atenção

- Sem cookie: 401 `Conta Google Ads não conectada.` (mensagem herdada do serviço de OAuth). Cookie antigo sem escopos de GTM/GA4: 401 pedindo renovação.
- Diferente do Google Ads, aqui o `detail` é uma string, não um objeto com `request_id`.
- As rotas `analyze-live` bloqueiam o event loop durante a chamada ao Google (até 30 s por requisição). Ponto de atenção se houver muita concorrência.
- Período GA4: dias completos, em ordem, até 366 dias (`google_platform_service.py:129`).
- Se a análise GTM retornar `error`, vira 422 (`google_platform_service.py:98`).
