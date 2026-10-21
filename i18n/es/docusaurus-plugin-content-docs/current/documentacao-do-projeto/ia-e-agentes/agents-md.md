---
title: "AGENTS.md y CLAUDE.md"
description: "Qué dicen los archivos de instrucciones para IA del repositorio de la app y cómo deben trabajar los agentes en DS30."
sidebar_position: 1
---

# AGENTS.md y CLAUDE.md

El repositorio de la app tiene dos archivos de instrucciones en la raíz. Los agentes deben **leer los dos por completo** antes de editar.

| Archivo | Contenido |
|---|---|
| `AGENTS.md` | guía corta: estructura, comandos, estilo, pruebas, commits/PR, seguridad y reglas de despliegue |
| `CLAUDE.md` | visión del proyecto, comandos, reglas de despliegue, flujo Git, arquitectura de backend, frontend, Apps Script, contrato del payload v3, clasificación de Google Ads, ObservePoint y modelo de auth |

## Reglas resumidas

- **Commits:** solo los humanos hacen commit (incluidos los merges). La IA informa los archivos modificados, la verificación y sugiere un mensaje Conventional Commit ([Git y commits](../desenvolvimento/git-e-commits.md)).
- **Branches:** `dev` integra, `prod` es producción; el trabajo va en una branch de tarea (`feat/`, `fix/`, ...). Sin rebase, squash, force-push ni reset.
- **Despliegue:** la IA nunca hace despliegue. Solo `make deploy`, guiado por la branch. Tocar Makefile, Dockerfile, `.env` o el renderizador de env exige consentimiento humano ([Despliegue](../desenvolvimento/deploy.md)).
- **Secretos:** nada de credenciales, tokens, informes generados ni datos de clientes en git. Nunca abrir `client_secret*.json` ni `.env`.
- **Estilo:** 4 espacios en Python, 2 en JS/JSX; `snake_case`, `PascalCase`, `camelCase`; handlers delgados, lógica en services/audits; sin formatter ni linter (preservar el estilo vecino). Filosofía Ponytail/YAGNI.
- **Pruebas:** agregar regresión para merge de payload, contratos de API, reglas de auditoría e informes; ejecutar backend, frontend y build antes del PR ([Pruebas](../desenvolvimento/testes.md)).
- **PRs:** explicar los cambios y la verificación; destacar cambios de API, payload, plantilla o variables de entorno.

## Cómo debe trabajar un agente

1. Leer `AGENTS.md` y `CLAUDE.md` y verificar branch/working tree.
2. Verificar la afirmación en el código antes de confiar en el texto de la documentación.
3. Cambiar solo lo necesario; mantener sincronizados payload, `payloadHelpers.js` y Apps Script (un campo renombrado pasa a `—` en el documento, sin error).
4. Ejecutar las pruebas aplicables, informar el resultado y sugerir el mensaje de commit. No hacer commit, no hacer push, no hacer despliegue.

## Fuentes más confiables que el README

El propio `CLAUDE.md` dice que el árbol de archivos y la tabla de API del `README.md` son históricos (las secciones de Git y despliegue siguen vigentes). Más confiables: `AGENTS.md`, `Docs/apps_script_integration.md`, `Docs/google_ads_backend_flow.md`, `Docs/clasp_setup.md` y el código. El `CLAUDE.md` también tiene puntos desfasados (por ejemplo, describe el frontend como SPA de pestañas en `App.jsx`; vea [Frontend](../desenvolvimento/frontend.md)). Lista de material obsoleto: [Heredado y documentos obsoletos](./legado-e-documentos-obsoletos.md).
