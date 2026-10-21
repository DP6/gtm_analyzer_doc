#!/usr/bin/env bash
# Verificação da documentação (derivada do check-docs.sh do Polaris, sem as checagens de dado de cliente).
# Uso: ./scripts/check-docs.sh
set -uo pipefail
falhas=0

mapfile -t AREAS < <(find docs -mindepth 1 -maxdepth 1 -type d -not -name "_*" | sort)
[ "${#AREAS[@]}" -eq 0 ] && { echo "FALHA: nenhuma área em docs/"; exit 1; }
mapfile -t TODAS < <(find "${AREAS[@]}" \( -name "*.md" -o -name "*.mdx" \) -not -path "*/_*" | sort)
[ "${#TODAS[@]}" -eq 0 ] && { echo "FALHA: nenhuma página nas áreas"; exit 1; }

echo "== 0. Cobertura =="
for a in "${AREAS[@]}"; do echo "   $a: $(printf '%s\n' "${TODAS[@]}" | grep -c "^$a/") página(s)"; done

echo "== 1. Build (3 idiomas, onBrokenLinks: throw) =="
saida=$(npm run build 2>&1)
if ! grep -q "\[SUCCESS\]" <<<"$saida"; then
  echo "FALHA: build não completou"; grep -E "Error|error" <<<"$saida" | head -5; exit 1
fi
echo "   ok"

echo "== 2. Frontmatter obrigatório =="
faltando=0
for arq in "${TODAS[@]}"; do
  for campo in title description sidebar_position; do
    grep -q "^$campo:" "$arq" || { echo "FALHA: $arq sem '$campo'"; faltando=$((faltando+1)); }
  done
done
[ "$faltando" -eq 0 ] && echo "   ok" || falhas=$((falhas+1))

echo "== 3. Nomes de arquivo em kebab-case sem acento =="
ruins=$(printf '%s\n' "${TODAS[@]}" | xargs -n1 basename | grep -vE '^[a-z0-9]+(-[a-z0-9]+)*\.mdx?$' || true)
[ -n "$ruins" ] && { echo "FALHA: $ruins"; falhas=$((falhas+1)); } || echo "   ok"

echo "== 4. Slugs de _category_.json únicos =="
dups=$(find docs -name _category_.json -exec grep -h '"slug"' {} + | sort | uniq -d)
[ -n "$dups" ] && { echo "FALHA: $dups"; falhas=$((falhas+1)); } || echo "   ok"

echo "== 5. Páginas ainda em construção =="
emcons=$(grep -l ":::info Página em construção" "${TODAS[@]}" || true)
[ -n "$emcons" ] && echo "   pendentes: $(wc -l <<<"$emcons")" || echo "   nenhuma"

echo
[ "$falhas" -eq 0 ] && echo "✅ OK" || echo "❌ $falhas falha(s)"
exit $((falhas > 0))
