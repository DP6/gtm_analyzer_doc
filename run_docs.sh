#!/usr/bin/env bash
# Sobe o site local.
#   ./run_docs.sh            build dos 3 idiomas + serve (o seletor de idioma funciona), http://localhost:3000
#   ./run_docs.sh dev [loc]  hot reload de UM idioma (pt-BR|en|es); o seletor de idioma NÃO funciona nesse modo
set -euo pipefail
cd "$(dirname "$0")"
[ -d node_modules ] || npm ci
# --host 0.0.0.0: acessível do Windows (WSL).
if [ "${1:-}" = "dev" ]; then
  exec npm run start -- --locale "${2:-pt-BR}" --host 0.0.0.0 --no-open
fi
npm run build
exec npm run serve -- --host 0.0.0.0 --no-open
