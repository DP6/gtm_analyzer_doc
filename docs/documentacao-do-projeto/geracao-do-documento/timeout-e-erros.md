---
title: "Timeout e erros"
description: "Tabela de erros da geração no Drive (503, 422, 502, 504), causas, ações e o risco de documentos duplicados após timeout."
sidebar_position: 4
---

# Timeout e erros

Todos os erros saem de `generate_drive_report` (`backend/services/apps_script_service.py`). As mensagens são genéricas de propósito: detalhes do Apps Script não vão ao usuário, apenas aos logs (`logger.warning`).

## Tabela de erros

| HTTP | Mensagem (resumo) | Causa | O que fazer |
|---|---|---|---|
| 503 | "Geração no Drive não configurada: informe ..." (`:24`) | Falta `DS30_APPS_SCRIPT_URL`, `DS30_APPS_SCRIPT_SECRET`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` ou `GOOGLE_REFRESH_TOKEN` | Configurar a variável citada (a mensagem lista só os nomes) e reiniciar o backend |
| 503 | "DS30_APPS_SCRIPT_URL deve ser a URL /exec" (`:26`) | URL fora do padrão (por exemplo `/dev`) | Usar a URL `/exec` da implantação |
| 422 | "Coleção inválida: `<chave>`" (`:31`) | Coleção não é lista de objetos | Corrigir o payload na aba de origem |
| 422 | "Logo inválido. Use PNG, JPEG ou GIF de até 5 MB." (`:45`) | Logo do projeto fora do formato, corrompido ou grande demais | Trocar o logo nas configurações do projeto |
| 502 | "Não foi possível renovar o token Google ..." (`:58`) | Refresh token da conta publicadora revogado ou cliente OAuth divergente | Gerar novo token (ver [Apps Script](../integracoes/apps-script.md)); nenhum POST foi feito |
| 502 | "O endpoint do Apps Script retornou HTTP 401/403" (`:70`) | Conta publicadora sem acesso ao Web App ou implantação recusando o Bearer | Rever acesso `DOMAIN` e a conta publicadora |
| 502 | "retornou HTTP `<código>`" (`:71`) | Outro erro HTTP da publicação | Rever a publicação e as permissões do Web App |
| 502 | "Falha de comunicação com o Apps Script" (`:74`) | Erro de transporte (DNS, conexão) | Verificar rede e URL; tentar novamente |
| 502 | "Resposta inválida do Apps Script" (`:81`) | Corpo não era JSON (por exemplo página de login do Google) | Rever publicação e acesso; o log traz a cadeia de redirecionamentos |
| 502 | "O Apps Script não conseguiu gerar o documento" (`:84`) | JSON com `ok` diferente de `true`: segredo divergente, `CONFIG` incompleto, template inacessível, erro de render | Ver as execuções de `doPost` no Apps Script |
| 502 | "identificador de documento inválido" (`:88`) | `documentId` ausente ou fora de `[A-Za-z0-9_-]+` | Ver a execução no Apps Script |
| 504 | "O Apps Script não respondeu a tempo ..." (`:66`) | Timeout de 360 s (`httpx.Timeout(360, connect=10)`, `:60`) | **Conferir a pasta do cliente no Drive antes de gerar de novo** |

Ordem de avaliação e linhas: ver [Fluxo de geração](./fluxo-de-geracao.md).

## 504 e documentos duplicados

Não há retry automático. Um 504 significa que o backend desistiu de esperar, não que o script parou: o Apps Script pode terminar e criar o documento depois. Cada geração concluída cria uma nova cópia, e o nome (`[DS30] Diagnóstico Técnico - <cliente> (<data>)`) não tem sufixo de unicidade, então uma nova tentativa gera um segundo arquivo com o mesmo nome. Confira a subpasta do cliente e apague o duplicado se necessário. Quando o erro acontece durante a montagem, o script move a cópia incompleta para a lixeira (`Docs/ds30_appscript/Main.js:64`).

## NÃO VERIFICADO: timeout do Cloud Run

O cliente HTTP espera até 360 s, mas o timeout padrão de requisição do Cloud Run é 300 s. O `gcloud run deploy` do `Makefile` (linhas 139 a 151) não define `--timeout`, e o `Dockerfile` e `backend/config.py` não têm referência a timeout. Se o serviço estiver com o padrão, o Cloud Run pode encerrar a requisição do usuário antes de o backend chegar aos 360 s, e o frontend receberia um erro que não é o 504 documentado. Um humano precisa confirmar o valor real com `gcloud run services describe <serviço> --region=<região>` (campo `timeoutSeconds`). Esta página não afirma qual é o valor em produção.

## Testes

`backend/tests/test_report_contract_v2.py` cobre: encaminhamento do payload e e-mail da sessão (`:42`), `client_name` vindo do projeto sem sobrescrever o existente (`:75`), erros remotos sem vazar detalhes, incluindo 401/403/500, não-JSON, `ok: false`, `documentId` malicioso e timeout 504 (`:117`), configuração e entradas inválidas falhando antes da rede (`:157`), refresh falhando antes do POST (`:181`), redirecionamento sem Bearer e renovação a cada geração (`:201`) e o log da cadeia de redirecionamentos (`:224`). Ver [Testes](../desenvolvimento/testes.md).
