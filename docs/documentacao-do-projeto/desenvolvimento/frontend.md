---
title: "Frontend"
description: "Stack, estrutura de pastas, rotas, abas do workspace, estado do payload, autosave e cliente HTTP do frontend DS30."
sidebar_position: 3
---

# Frontend

:::warning CLAUDE.md desatualizado
O `CLAUDE.md` do repositório do app ainda descreve um SPA de página única com `TABS` em `App.jsx`. O código atual usa rotas (`react-router-dom`) e as abas ficam em `ReportWorkspace.jsx`. Esta página reflete o código.
:::

## Stack

React 18, Vite 5, Tailwind 3, `react-router-dom` 6 e `lucide-react` (`frontend/package.json`). Sem formatter/linter: indentação de 2 espaços, `PascalCase` para componentes, `camelCase` para o resto.

## Pastas (`frontend/src/`)

| Pasta | Conteúdo |
|---|---|
| `components/` | telas e blocos de UI (`ProjectGrid`, `ReportWorkspace`, `CrawlerScanner`, `GoogleAdsAnalyzer`, `DriveReportGenerator`, ...) |
| `context/` | `AuthContext.jsx` |
| `services/` | `api.js`, único cliente HTTP |
| `utils/` | `payloadHelpers.js`, `crawlerUrls.js`, `reportFieldConfig.js`, `tags.js` e testes |

## Rotas (`App.jsx`)

Sem usuário autenticado, aparece a tela "Autenticação Requerida". Com usuário:

| Rota | Componente |
|---|---|
| `/` | `ProjectGrid` |
| `/projects/:projectId` | `ProjectShell` (layout) |
| `/projects/:projectId` (index) | `ReportList` |
| `.../settings` | `ProjectSettings` |
| `.../reports/new` | `ReportCreate` |
| `.../reports/:reportId` | `ReportWorkspace` |
| qualquer outra | redireciona para `/` |

## Abas do workspace

`TABS` em `ReportWorkspace.jsx:16`: `transcripts` (Transcrições), `overview` (Visão Geral / GTG), `gtm` (Auditoria GTM), `ga` (Google Analytics), `google_ads`, `oci` (OCI / ECL), `eco`, `report` (Diagnóstico) e `history` (Histórico). A aba ativa vem do parâmetro de URL `tab` quando válido; padrão `overview` (ou `google_ads` se a URL tiver `google_ads`).

## Estado do payload e autosave

Todas as abas compartilham um único `payload`, mesclado progressivamente com `mergePayload` (`utils/payloadHelpers.js`). Esse objeto é o contrato enviado ao backend (veja [Payload v3](../geracao-do-documento/payload-v3.md)).

Autosave (`ReportWorkspace.jsx:22,81-85`):

- Cada mudança de `payload` agenda `updateReport(project.id, reportId, { payload })` após `AUTOSAVE_DELAY_MS = 1500` ms (debounce).
- `skipNextAutosave` (ref) evita regravar logo após carregar o relatório do servidor.
- Falhas são engolidas (`.catch(() => {})`): o usuário não vê erro se o salvamento falhar.

## Cliente HTTP (`services/api.js`)

Uma função por endpoint, todas sob `/api`. `getAuthHeaders()` lê o `localStorage` e define **um** cabeçalho, na prioridade: `gtm_auth_google_token` (`Authorization: Bearer`), `gtm_auth_email_session` (`X-Email-Session`), `gtm_auth_access_token` (`X-Access-Token`), `gtm_auth_dev_email` (`X-Dev-User-Email`). Os tokens de login ficam em `localStorage` (não em cookie). Backend: [Autenticação](../visao-geral-e-arquitetura/autenticacao.md).

## Crawler

`CrawlerScanner.jsx` guarda o scan ativo no `localStorage` por relatório (`scanKey(reportId)`) e consulta `pollWebsiteScan` a cada 5 s; ao concluir ou falhar, remove a chave. Assim o scan sobrevive a recarregar a página. API: [Crawler](../api/crawler.md).

## Dev e produção

- Dev: Vite em `:5173` com proxy `/api` para `http://localhost:8000` (`vite.config.js`).
- Produção: `npm run build` no estágio 1 do Dockerfile; o `dist` é copiado para `backend/static` e servido pelo FastAPI como SPA ([Deploy](./deploy.md)).
