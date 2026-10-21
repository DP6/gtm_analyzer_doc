---
title: "Testes"
description: "Como rodar e organizar os testes do backend (pytest) e do frontend (node:test) do DS30."
sidebar_position: 2
---

# Testes

## Comandos

| Alvo | Comando |
|---|---|
| Backend (tudo) | `cd backend && .venv/bin/python -m pytest tests` |
| Um arquivo | `cd backend && .venv/bin/python -m pytest tests/test_audit_service.py` |
| Um teste | `... pytest tests/test_audit_service.py::test_name` |
| Frontend | `cd frontend && npm test` (`node --test src/utils/*.test.js`) |
| Build do frontend | `cd frontend && npm run build` |

`pytest` não está em `backend/requirements.txt`; instale no venv se necessário. `tests/conftest.py` só coloca `backend/` no `sys.path`.

## Organização do backend

20 arquivos `test_*.py` em `backend/tests/`, mais `conftest.py`, agrupados por área:

| Área | Arquivos |
|---|---|
| Auditoria GTM | `test_audit_service.py`, `test_considerations_service.py`, `test_gtm_request_analyzer.py` |
| Google Ads | `test_google_ads_service.py`, `test_google_ads_api_service.py`, `test_google_ads_oauth_service.py` |
| GTM/GA4 e contas | `test_google_platform_service.py`, `test_project_google_accounts.py` |
| Crawler / ObservePoint / CDN | `test_crawler_service.py`, `test_observepoint_service.py`, `test_cdn_analyzer.py` |
| Relatório e payload | `test_report_contract_v2.py`, `test_payload_helpers.py`, `test_docx_generation_with_observepoint_payload.py` |
| Persistência / Drive | `test_firestore_service.py`, `test_drive_service.py` |
| Transcrições | `test_transcript_insights_service.py` |
| Deploy e tooling | `test_makefile_deploy.py`, `test_render_cloudrun_env.py`, `test_generate_google_refresh_token.py` |

Observações:

- Apesar do nome, `test_report_contract_v2.py` testa o fluxo atual `POST /api/report/google-docs` (Apps Script), não o payload v2.
- `test_docx_generation_with_observepoint_payload.py` e `test_cdn_analyzer.py` dependem de `backend/doc_generator.py`, código legado (veja [Legado](../ia-e-agentes/legado-e-documentos-obsoletos.md)).
- Os diretórios `backend/modules/*/tests` existem, mas não contêm arquivos `.py`.

## Frontend

Apenas utilitários: `src/utils/payloadHelpers.test.js`, `crawlerUrls.test.js`, `appsScript.test.js`, com `node:test` e `node:assert/strict`. Não há teste de componentes React.

## O que os testes cobrem (e o que não)

Os testes miram **services** e helpers, não os routers: lógica de negócio vive em `services/` e `audits/`, e os handlers são finos. Exceções pontuais importam funções de `routers.report` (`test_report_contract_v2.py`).

Não há CI no repositório (sem `.github/`) e nenhum limite de cobertura. Rodar as duas suítes e o build antes de integrar é responsabilidade de quem desenvolve.

## Convenções

- Arquivos `test_*.py`, funções `test_<comportamento>`.
- Frontend: `*.test.js` ao lado do utilitário.
- Adicione teste de regressão ao mexer em: merge de payload (`payloadHelpers`), contratos de API, regras de auditoria (`backend/audits/`), classificação do Google Ads e geração do relatório.
- Alterações no `Makefile` de deploy devem manter `test_makefile_deploy.py` verde (veja [Deploy](./deploy.md)).
