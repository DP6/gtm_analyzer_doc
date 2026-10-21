---
title: "AGENTS.md and CLAUDE.md"
description: "What the app repository's AI instruction files say and how agents should work on DS30."
sidebar_position: 1
---

# AGENTS.md and CLAUDE.md

The app repository has two instruction files at the root. Agents must **read both in full** before editing.

| File | Contents |
|---|---|
| `AGENTS.md` | short guide: structure, commands, style, tests, commits/PR, security and deploy rules |
| `CLAUDE.md` | project overview, commands, deploy rules, Git flow, backend architecture, frontend, Apps Script, payload v3 contract, Google Ads classification, ObservePoint and auth model |

## Summarized rules

- **Commits:** only humans commit (including merges). AI reports changed files, verification and suggests a Conventional Commit message ([Git and commits](../desenvolvimento/git-e-commits.md)).
- **Branches:** `dev` integrates, `prod` is production; work on a task branch (`feat/`, `fix/`, ...). No rebase, squash, force-push or reset.
- **Deploy:** AI never deploys. Only `make deploy`, guided by the branch. Touching the Makefile, Dockerfile, `.env` or the env renderer requires human consent ([Deploy](../desenvolvimento/deploy.md)).
- **Secrets:** no credentials, tokens, generated reports or client data in git. Never open `client_secret*.json` or `.env`.
- **Style:** 4 spaces in Python, 2 in JS/JSX; `snake_case`, `PascalCase`, `camelCase`; thin handlers, logic in services/audits; no formatter or linter (preserve neighboring style). Ponytail/YAGNI philosophy.
- **Tests:** add regression tests for payload merging, API contracts, audit rules and reports; run backend, frontend and build before the PR ([Tests](../desenvolvimento/testes.md)).
- **PRs:** explain changes and verification; highlight changes to the API, payload, template or environment variables.

## How an agent should work

1. Read `AGENTS.md` and `CLAUDE.md` and check the branch/working tree.
2. Verify the claim in the code before trusting documentation text.
3. Change only what is necessary; keep the payload, `payloadHelpers.js` and Apps Script in sync (a renamed field becomes `—` in the document, with no error).
4. Run the applicable tests, report the result and suggest the commit message. Do not commit, push or deploy.

## Sources more reliable than the README

`CLAUDE.md` itself says that the file tree and the API table in `README.md` are historical (the Git and deploy sections remain current). More reliable: `AGENTS.md`, `Docs/apps_script_integration.md`, `Docs/google_ads_backend_flow.md`, `Docs/clasp_setup.md` and the code. `CLAUDE.md` also has outdated points (for example, it describes the frontend as a tabbed SPA in `App.jsx`; see [Frontend](../desenvolvimento/frontend.md)). List of obsolete material: [Legacy and obsolete documents](./legado-e-documentos-obsoletos.md).
