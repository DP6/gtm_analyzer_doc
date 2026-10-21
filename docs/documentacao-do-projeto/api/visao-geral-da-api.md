---
title: "Visão geral da API"
description: "Como o backend FastAPI do DS30 monta os routers, autentica, trata erros e expõe a API HTTP."
sidebar_position: 1
---

# Visão geral da API

O backend é um app FastAPI (`backend/main.py`). Cada área funcional tem um router em `backend/routers/*.py`; a lógica pesada fica em `backend/services/*.py`.

## Montagem do app

| Item | Onde | Comportamento |
|---|---|---|
| Registro de routers | `backend/main.py:39-49` | `auth` e o callback OAuth do Google Ads são públicos; os outros 7 routers recebem `dependencies=[Depends(get_current_user)]` |
| CORS | `backend/main.py:30-36` | `allow_origins=settings.ALLOWED_ORIGINS`, `allow_credentials=True`, métodos e headers `*` |
| Health | `backend/main.py:51-54` | `GET /health` e `GET /api/health` retornam `{"status":"ok","service":"gtm-analyzer-backend"}` (sem auth) |
| SPA fallback | `backend/main.py:57-69` | Se existir `backend/static/`, monta `/assets` e serve qualquer outro caminho como arquivo estático ou `index.html` |
| Raiz sem build | `backend/main.py:71-77` | Sem `static/`, `GET /` devolve `{"ok":true,...}` |

A autenticação (`get_current_user`, `backend/deps.py:5`) é aplicada no registro do router, não rota a rota. Rotas que precisam do usuário também declaram `Depends(get_current_user)` para receber o dict `user` (a dependência é resolvida uma vez por requisição).

:::warning
Como o fallback SPA é `GET /{full_path:path}`, um `GET` em rota inexistente sob `/api` em produção devolve o `index.html` (200), não 404.
:::

## Autenticação

`get_current_user` lê `Authorization: Bearer`, `X-Email-Session`, `X-Access-Token` (ou `?token=`) e `X-Dev-User-Email`, nessa ordem de prioridade (`backend/services/auth_service.py:259-299`). Sem usuário válido: `401` com `WWW-Authenticate: Bearer`. Detalhes em [Autenticação](../visao-geral-e-arquitetura/autenticacao.md).

## Convenções

- **Routers finos**: validam entrada (Pydantic), chamam um serviço e traduzem erros.
- **Erros de serviço**: serviços lançam `ValueError` ou erros de domínio (`GoogleAdsApiError`, `GooglePlatformApiError`, `GoogleAdsConnectionError`) e o router converte em `HTTPException`. Alguns serviços lançam `HTTPException` direto (`apps_script_service.py`, `drive_service.py`).
- **Mensagens em português** no campo `detail`. Em erros do Google Ads, `detail` é um objeto `{"message", "request_id"}`.
- **SDKs bloqueantes** (Firestore, Google Ads) rodam em `run_in_threadpool` dentro de rotas `async`; rotas `def` sem `async` já rodam no threadpool do FastAPI.
- **Persistência `*_safe`**: `save_run_safe`, `record_google_accounts` e `save_google_ads_analysis_safe` (`backend/services/firestore_service.py:116-165`) engolem exceções e só logam. Uma falha ao gravar histórico nunca derruba a análise; a resposta volta normalmente.
- **404 vs 403**: sem acesso a um projeto, a API responde `404 Projeto não encontrado.` para não revelar que ele existe. `403` só aparece quando o usuário tem acesso mas não é dono (`backend/routers/projects.py:63-75`).

## Mapa de status

| Status | Uso típico |
|---|---|
| 200 | Sucesso |
| 202 | `POST /api/crawler/crawl` (execução enfileirada) |
| 400 | Arquivo inválido, OTP desativado/inválido, CSV Google Ads inválido, ObservePoint sem chave |
| 401 | Sem autenticação; conexão Google ausente/expirada |
| 403 | Não é dono do projeto; ObservePoint negou |
| 404 | Projeto/relatório/execução inexistente ou sem acesso |
| 409 | Cota do ObservePoint atingida |
| 422 | Validação Pydantic ou `ValueError` de serviço |
| 502 | Falha em API externa (Google, Drive, Apps Script, ObservePoint, Gemini) |
| 503 | Integração não configurada (Gemini, Google OAuth, Apps Script) |
| 504 | Apps Script estourou o tempo |

## Timeouts

Todos fixos no código; não há variável de ambiente para ajustá-los.

| Chamada | Timeout | Arquivo |
|---|---|---|
| APIs Google (GTM, GA4) | 30 s | `backend/services/google_platform_service.py:20` |
| Google Drive (listar/exportar) | 30 s | `backend/services/drive_service.py:72,94` |
| ObservePoint | 10 a 30 s, conforme a chamada | `backend/services/observepoint_service.py:118-443` |
| Apps Script | 360 s total, 10 s de conexão | `backend/services/apps_script_service.py:60` |
| SendGrid (OTP) | 5 s | `backend/services/auth_service.py:150` |
| Revogação OAuth Google | 10 s | `backend/services/google_ads_oauth_service.py:212` |
| Gemini | sem timeout explícito | `backend/services/considerations_service.py` |

Veja também [Timeout e erros](../geracao-do-documento/timeout-e-erros.md).

## Chamar localmente

1. Suba o backend na porta 8000 (`python main.py` roda `uvicorn` com reload, `backend/main.py:79-81`).
2. O Vite faz proxy de `/api` para `http://localhost:8000` (`frontend/vite.config.js:9-14`); o frontend chama caminhos relativos.
3. OpenAPI interativo em `http://localhost:8000/docs`.
4. Em desenvolvimento, o modo dev aceita `X-Dev-User-Email` (ver autenticação).

```bash
curl http://localhost:8000/api/health
curl -H "X-Dev-User-Email: dev@exemplo.com" http://localhost:8000/api/auth/me
```

Mais em [Primeiros passos](../desenvolvimento/primeiros-passos.md).

## Páginas

[Auth](./auth.md), [Audit](./audit.md), [Projects](./projects.md), [Report](./report.md), [Crawler](./crawler.md), [Google Ads](./google-ads.md), [Google Platforms](./google-platforms.md), [Transcripts](./transcripts.md).
