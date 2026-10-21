---
title: "Apps Script"
description: "Onde o Apps Script se encaixa na arquitetura, variáveis de ambiente envolvidas e como gerar o token da conta publicadora."
sidebar_position: 7
---

# Apps Script

O Google Doc final é montado por um Web App do Google Apps Script, chamado pelo backend. Esta página só situa a integração; o funcionamento interno, os templates, a publicação com clasp e as camadas de autenticação estão em [Apps Script por dentro](../geracao-do-documento/apps-script-por-dentro.md), e a sequência de chamadas em [Fluxo de geração](../geracao-do-documento/fluxo-de-geracao.md).

## Onde se encaixa

`POST /api/report/google-docs` (`backend/routers/report.py:31`) chama `generate_drive_report` (`backend/services/apps_script_service.py:18`), que faz um POST à URL `/exec` do Web App com o payload, o logo e o segredo compartilhado. O código do script fica em `Docs/ds30_appscript/`.

## Variáveis de ambiente (apenas nomes)

| Variável | Uso |
|---|---|
| `DS30_APPS_SCRIPT_URL` | URL `/exec` da implantação (validada por regex; `/dev` é rejeitada) |
| `DS30_APPS_SCRIPT_SECRET` | Mesmo valor da Script Property `DS30_SHARED_SECRET` no Apps Script |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Cliente OAuth que emitiu o refresh token (compartilhado com o login e o Google Ads) |
| `GOOGLE_REFRESH_TOKEN` | Refresh token da conta publicadora, usado para obter o Bearer de cada chamada |

Valores nunca entram no código, no frontend nem na documentação. A lista completa está em [Variáveis de ambiente](../referencia/variaveis-de-ambiente.md); sem qualquer uma das quatro primeiras, o backend responde 503 antes de chamar o Google (ver [Timeout e erros](../geracao-do-documento/timeout-e-erros.md)).

## Token da conta publicadora

O utilitário `backend/generate_google_refresh_token.py` autoriza a conta publicadora localmente:

1. Usa o cliente OAuth já configurado (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`) e pede os escopos `drive` e `documents` com acesso offline e consentimento forçado.
2. Abre um listener em `http://localhost:8080/` (essa URI precisa estar cadastrada no cliente OAuth; a porta deve estar livre) e espera até 300 s.
3. Imprime apenas a linha `GOOGLE_REFRESH_TOKEN=...` para você copiar manualmente para o ambiente protegido. Não altera arquivos, não publica o script e não gera relatório.

Trate a saída do terminal como segredo. Se o token for revogado, rode de novo e substitua o valor. Teste do utilitário: `backend/tests/test_generate_google_refresh_token.py`. O passo a passo no console do GCP está em `Docs/apps_script_integration.md`.

A saúde da conta pode ser consultada em `GET /api/report/publisher-status` (`backend/routers/report.py:50`), que apenas tenta renovar o token.

## Observações

- A conta publicadora é a mesma usada para listar e exportar transcrições do Drive (`backend/services/drive_service.py`), ver [IA (Gemini)](./ia-gemini.md).
- Publicar uma nova versão do Web App é ação humana; ver o fluxo em [Apps Script por dentro](../geracao-do-documento/apps-script-por-dentro.md).
