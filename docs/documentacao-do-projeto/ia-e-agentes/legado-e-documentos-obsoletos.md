---
title: "Legado e documentos obsoletos"
description: "Inventário de código, arquivos e branches legados ou desatualizados no repositório do DS30, com status de cada um."
sidebar_position: 2
---

# Legado e documentos obsoletos

Inventário verificado contra o repositório do app. Não use estes itens como fonte da verdade.

## Documentação

| Item | Status |
|---|---|
| `README.md`: árvore de arquivos e tabela de API (`/api/report/docx`, `/api/report/template-fields`) | obsoleto; seções de Git e deploy seguem atuais |
| `CLAUDE.md`: descrição do frontend como SPA com `TABS` em `App.jsx` | desatualizado (hoje há rotas e `ReportWorkspace.jsx`) |
| `mudancas_doc.md` (raiz) | notas de trabalho, não é documentação; sem uso no código |
| `Alteração_config.md` (raiz) | plano de reorganização da aba de configurações; não é referência |
| `GTG-CDN-Detector_and_Decompiler_integrationplan.md` (raiz) | plano de integração; não é referência do estado atual |

## Código e arquivos do fluxo `.docx`

| Item | Status |
|---|---|
| `/api/report/docx` e `/api/report/template-fields` | removidos (commit `7ee559a`, breaking) |
| `backend/doc_generator.py` | sem rota; importado só por `backend/tests/test_docx_generation_with_observepoint_payload.py` e `test_cdn_analyzer.py` |
| `backend/DS30_Diagnostico_Tecnico_Template*.docx` e `Docs/DS30_..._Template_v3_5_...docx` | templates do fluxo antigo |
| `Docs/DS30_Diagnostico_Tecnico_variable_mapping_v2_arrays.json` | mapeamento v2, sem leitura pelo código atual |
| `Docs/DS30_Diagnostico_Tecnico_payload_example_v2.json` | schema 2.0.0 superado; usar o v3 ([Payload v3](../geracao-do-documento/payload-v3.md)) |
| `Dockerfile:31-32` | ainda copia o `.docx` e o mapping v2 para a imagem ([Deploy](../desenvolvimento/deploy.md)) |
| `Docs/ds30_appscript.js` | versão de arquivo único; o que vale é `Docs/ds30_appscript/` ([Apps Script por dentro](../geracao-do-documento/apps-script-por-dentro.md)) |
| `Docs/schema.sql` | esquema SQL de referência (a persistência atual é Firestore); só `Docs/example.py` o referencia |
| `backend/modules/*` | só `__pycache__` e pastas `tests` sem `.py`; nenhum código |
| `backend/modules/**/__pycache__` | cache ignorado pelo git; pode ser apagado localmente |

## Lixo de ambiente

| Item | Status |
|---|---|
| Arquivos `*:Zone.Identifier` (um para quase cada arquivo, ex. `AGENTS.md:Zone.Identifier`) | metadados do Windows/WSL; aparecem como não rastreados no `git status` e geram avisos "ignoring ref with broken name". Podem ser apagados |

## Branches

| Branch | Status |
|---|---|
| `master`, `Database_integration`, `app-scripts-integration`, `new_template_and_application_changes` | legadas; não retomar nem mesclar sem revisão |
| `refator/documentation-and-ai-use` | nome com erro de digitação (`refator`); tem 1 commit que `dev` não tem; tratar como legada |

Regras de branches: [Git e commits](../desenvolvimento/git-e-commits.md).
