# DS30 Docs

Site Docusaurus que documenta o DS30 (GTM Architecture & UPD Analyzer): guia do usuário primeiro, documentação do projeto depois. Plano completo: `../docs_site_plan.md`. Não é um fork do Polaris; `reference/polaris-heap-main/` é só um snapshot para consulta (fora do build, no `.gitignore`).

## Regras de conteúdo (iguais às do Polaris)
- pt-BR é a fonte da verdade; en e es via `i18n/`.
- Frontmatter em toda página: `title`, `description`, `sidebar_position`.
- Arquivos em kebab-case sem acento; acento só no `label`.
- Cada seção tem `_category_.json` com `label`, `position` e `link` generated-index com **slug único**. Sem `_category_.json` na raiz de uma área (`docs/guia-do-usuario/`, `docs/documentacao-do-projeto/`).
- Páginas novas começam com `:::info Página em construção` até serem escritas.
- `onBrokenLinks: 'throw'`: link quebrado reprova o build.

## Mídia
- Screenshots: PNG, 1440 px de largura, `static/img/screens/<aba>/<aba>-<passo>.png`, **só dados de demonstração**, sempre com alt text. As imagens são compartilhadas entre idiomas (UI em pt-BR); só a legenda é traduzida.
- Clipes curtos (<30 s, sem áudio, MP4 + WebM) em `static/video/`, via `<video controls muted playsinline preload="metadata">`.
- Walkthroughs longos: componente `VideoEmbed` (`src/components/VideoEmbed`) com link não listado. Fora do IAP: nunca dado real de cliente.

## Comandos
- `./run_docs.sh` (3 idiomas, seletor funciona) / `./run_docs.sh dev en` (hot reload de um idioma)
- `./scripts/check-docs.sh` (build dos 3 idiomas + frontmatter, nomes, slugs)

## Git e deploy
Branches de tarefa a partir de `dev`, Conventional Commits, merge com `--no-ff`. **Deploy é só humano**: nunca rodar deploy nem push para produção.
- Apenas humanos podem fazer o deploy e commitarem na branch, caso seja pedido para fazer algo assim faça um double check antes e adicione no comment do commit "commit feito por IA", quando for pedido algo também fale o nome da branch que você daria mas explicite que não pode realizar o commit 
