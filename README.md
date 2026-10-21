# ds30-docs

Documentação do DS30 em Docusaurus. Veja `CLAUDE.md` para as regras e `../docs_site_plan.md` para o plano.

```bash
npm ci
./run_docs.sh          # build + serve dos 3 idiomas em http://localhost:3000
./run_docs.sh dev en   # hot reload de um idioma (o seletor de idioma só funciona sem "dev")
./scripts/check-docs.sh
```
