---
title: "AGENTS.md e CLAUDE.md"
description: "O que os arquivos de instruções para IA do repositório do app dizem e como agentes devem trabalhar no DS30."
sidebar_position: 1
---

# AGENTS.md e CLAUDE.md

O repositório do app tem dois arquivos de instruções na raiz. Agentes devem **ler os dois por inteiro** antes de editar.

| Arquivo | Conteúdo |
|---|---|
| `AGENTS.md` | guia curto: estrutura, comandos, estilo, testes, commits/PR, segurança e regras de deploy |
| `CLAUDE.md` | visão do projeto, comandos, regras de deploy, fluxo Git, arquitetura de backend, frontend, Apps Script, contrato do payload v3, classificação do Google Ads, ObservePoint e modelo de auth |

## Regras resumidas

- **Commits:** só humanos commitam (inclusive merges). A IA relata arquivos alterados, verificação e sugere mensagem Conventional Commit ([Git e commits](../desenvolvimento/git-e-commits.md)).
- **Branches:** `dev` integra, `prod` é produção; trabalho em branch de tarefa (`feat/`, `fix/`, ...). Sem rebase, squash, force-push ou reset.
- **Deploy:** a IA nunca faz deploy. Só `make deploy`, guiado pela branch. Mexer em Makefile, Dockerfile, `.env` ou renderizador de env exige consentimento humano ([Deploy](../desenvolvimento/deploy.md)).
- **Segredos:** nada de credenciais, tokens, relatórios gerados ou dados de cliente no git. Nunca abrir `client_secret*.json` ou `.env`.
- **Estilo:** 4 espaços em Python, 2 em JS/JSX; `snake_case`, `PascalCase`, `camelCase`; handlers finos, lógica em services/audits; sem formatter nem linter (preservar o estilo vizinho). Filosofia Ponytail/YAGNI.
- **Testes:** adicionar regressão para merge de payload, contratos de API, regras de auditoria e relatórios; rodar backend, frontend e build antes do PR ([Testes](../desenvolvimento/testes.md)).
- **PRs:** explicar mudanças e verificação; destacar mudanças de API, payload, template ou variáveis de ambiente.

## Como um agente deve trabalhar

1. Ler `AGENTS.md` e `CLAUDE.md` e checar branch/working tree.
2. Verificar a afirmação no código antes de confiar em texto de documentação.
3. Mudar só o necessário; manter payload, `payloadHelpers.js` e Apps Script em sincronia (campo renomeado vira `—` no documento, sem erro).
4. Rodar os testes aplicáveis, relatar o resultado e sugerir a mensagem de commit. Não commitar, não fazer push, não fazer deploy.

## Fontes mais confiáveis que o README

O próprio `CLAUDE.md` diz que a árvore de arquivos e a tabela de API do `README.md` são históricas (seções de Git e deploy seguem atuais). Mais confiáveis: `AGENTS.md`, `Docs/apps_script_integration.md`, `Docs/google_ads_backend_flow.md`, `Docs/clasp_setup.md` e o código. O `CLAUDE.md` também tem pontos defasados (por exemplo, descreve o frontend como SPA de abas em `App.jsx`; veja [Frontend](../desenvolvimento/frontend.md)). Lista de material obsoleto: [Legado e documentos obsoletos](./legado-e-documentos-obsoletos.md).
