---
title: "Apps Script por dentro"
description: "Arquivos do projeto Apps Script, templates, substituição de placeholders, escopo, publicação com clasp e as três camadas de autenticação."
sidebar_position: 3
---

# Apps Script por dentro

O código vive em `Docs/ds30_appscript/` e roda como Web App (`executeAs: USER_DEPLOYING`, `access: DOMAIN`, em `appsscript.json`). Os arquivos compartilham o mesmo escopo global; não há import/export. `Docs/ds30_appscript.js` é a versão histórica de arquivo único.

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| `Config.js` | `CONFIG` (IDs de `BLANK_TEMPLATE_ID`, `COVER_TEMPLATE_ID`, `CLIENTS_FOLDER_ID`, fuso, rodapé, `PREVIEW_MODE`) e `validateConfig` |
| `Main.js` | `doPost`, `generateDs30`, pasta do cliente, nome do arquivo, rodapé, `validatePayload`, `testGenerateDs30` |
| `DocStyle.js` | Estilos: `addH1` a `addH4`, `addParagraph`, `addListItem`, `addBullets`, `addCallout`, tabelas |
| `DocHelpers.js` | Cópia da capa, `getDriveId`, `getValue`, substituição de placeholders, logo |
| `ReportSections.js` | `resolveScope` e as funções `render*` com o texto de cada seção |

Os IDs dos templates e da pasta ficam em `Config.js` e não são repetidos aqui.

## Execução de `generateDs30` (`Main.js:27`)

1. `validatePayload` e `validateConfig` (falha se algum `*_ID` ainda começa com `COLOQUE_`).
2. `resolveClientFolder` (`Main.js:6`): procura subpasta com o nome exato do cliente em `CLIENTS_FOLDER_ID`; cria se não existe.
3. Copia `DS30_BLANK` para a subpasta com o nome `[DS30] Diagnóstico Técnico - <cliente> (<yyyy-MM-dd>)` (`outputFileName`, `Main.js:13`). A data vem de `snapshot_date`. Não há sufixo de unicidade: gerar duas vezes no mesmo dia cria dois arquivos de mesmo nome.
4. A partir daqui, dentro de `try`: limpa o corpo, copia o corpo de `DS30_COVER` (`appendTemplateBody`), insere o logo, substitui placeholders.
5. `renderIntroduction`, depois as seções conforme `resolveScope`, depois `renderChangelog`.
6. `addInstitutionalFooter` (`Main.js:20`) acrescenta ao rodapé do BLANK (que já traz a numeração) a linha "Documento produzido pela DP6 | ...", omitindo e-mail e site vazios.
7. `saveAndClose` e retorno de `documentId` e `documentUrl`.

Em erro depois da cópia, o `catch` move o arquivo incompleto para a lixeira e relança (`Main.js:64`). A pasta do cliente já pode ter sido criada e não é desfeita.

## Templates e placeholders

- **DS30_BLANK**: margens e rodapé com paginação automática. O corpo é apagado.
- **DS30_COVER**: capa com `{{document_month}}`, `{{document_year}}` e `{{client_logo}}`. Só parágrafos, listas e tabelas são copiados; cabeçalho e rodapé devem ficar no BLANK.
- `replaceScalarPlaceholders` (`DocHelpers.js:55`): cada chave escalar do payload substitui `{{chave}}` no corpo. Objetos e listas são ignorados. Fora do `PREVIEW_MODE`, valores nulos viram vazio e placeholders restantes são removidos.
- `insertClientLogo` (`DocHelpers.js:76`): aceita data URL PNG/JPEG/GIF de até 5 MB, exige `{{client_logo}}` em parágrafo exclusivo e limita a imagem a 220 x 110 px. Sem logo, o placeholder é removido.
- `fillText` resolve `{{campo}}` nos textos das seções com `getValue`, que mostra `—` quando falta valor (ou `[campo: x]` em `PREVIEW_MODE`).

## Escopo e seções

`resolveScope` (`ReportSections.js:120`) devolve cinco flags. Só `false` explícito desliga.

| Flag | Função | Observação |
|---|---|---|
| `gtg` | `renderGTG` | Fatos omitidos quando o `*_decision` é desconhecido; container server-side fora de uso vira "Ponto de atenção" |
| `upd` | `renderUPD` | Tabelas de plataformas, containers, variáveis UPD e tags (`renderContainers`) |
| `enhancedConversions` | `renderEnhancedConversions` (usa `renderGoogleAdsEC`) | |
| `offlineConversions` | `renderOfflineConversions` | OCI e ECL juntos, sem flag separada para ECL |
| `eco` | `renderECO` | Exige `offline_conversions.enabled` |

`renderChangelog` sempre roda e cria uma entrada "Criação do documento" se `changelog_entries` estiver vazio. Seções de considerações só aparecem quando o campo tem valor.

## Três camadas de autenticação

| Camada | Onde | Papel |
|---|---|---|
| Token OAuth da conta publicadora | `Authorization: Bearer` enviado por `apps_script_service.py:61` | Passa pela política do Web App; gerado a partir do refresh token (`backend/services/drive_service.py:37`) |
| Acesso do Web App `DOMAIN` | `appsscript.json` | Só contas do domínio chamam a URL |
| Segredo compartilhado | `doPost` compara `request.secret` com a Script Property `DS30_SHARED_SECRET` (`Main.js:74`) | Rejeita antes de criar qualquer arquivo |

O documento é criado com a identidade de quem publicou o Web App. O e-mail do usuário vai só como texto (`document_owner_email`), não como permissão. O script não altera compartilhamento: o usuário precisa já ter acesso à pasta-mãe.

## Fluxo de publicação com clasp

Comandos rodam em `Docs/ds30_appscript/`. Login, push e publicação são passos humanos.

| Comando | Efeito |
|---|---|
| `clasp status` | Lista o que seria enviado |
| `clasp push` | Substitui o código remoto (HEAD). **Não muda a versão publicada em `/exec`** |
| `clasp redeploy <deploymentId>` | Publica a versão mais nova no deployment existente, mantendo a URL |
| `clasp deploy` (sem `-i`) | Cria deployment novo com outra URL e **quebra `DS30_APPS_SCRIPT_URL`** |

`publish.sh` automatiza login, `clasp status`, `clasp push --force` e `clasp redeploy`, extraindo o `deploymentId` da `DS30_APPS_SCRIPT_URL` configurada no ambiente do backend, com confirmação antes do push e antes do redeploy. Valide depois na URL `/exec`, não em `/dev`. O ID do projeto Apps Script está em `Docs/clasp_setup.md` e é omitido aqui.

## Teste manual

Rode `testGenerateDs30` (`Main.js:94`) no editor do Apps Script (por `clasp open`): gera um documento de teste com payload mínimo e registra a URL. Cria a subpasta "Cliente" na pasta-mãe. O Apps Script não tem runtime local; os testes Python do repositório usam stubs e não geram nada no Drive.

## Desvios entre os documentos antigos e o código

- `Docs/clasp_setup.md` diz que `testGenerateDs30` usa `CONFIG.OUTPUT_FOLDER_ID`. O código atual usa `CLIENTS_FOLDER_ID` (subpasta por cliente).
- `Docs/apps_script_integration.md` descreve a entrada como `{payload, client_logo_base64}`. O endpoint real recebe `{payload, project_id, report_id}`; o logo vem do projeto no Firestore e o backend é quem monta o corpo enviado ao script (`{secret, payload, client_logo_base64}`, `apps_script_service.py:61`).
- O mesmo documento cita `frontend/utils/payloadHelpers.js`; o caminho real é `frontend/src/utils/payloadHelpers.js`.

Ver também: [Fluxo de geração](./fluxo-de-geracao.md), [Timeout e erros](./timeout-e-erros.md), [Integração Apps Script](../integracoes/apps-script.md).
