#!/usr/bin/env bash
# Baixa o sqlite3.wasm compatível com a versão do package:sqlite3 travada no
# pubspec.lock (necessário para o banco offline da versão Web/PWA).
# Uso (a partir da raiz do repositório): bash tool/fetch_sqlite_wasm.sh
set -euo pipefail
cd "$(dirname "$0")/.."   # funciona a partir de qualquer pasta
LOCK="app/pubspec.lock"
VER=$(awk '/^  sqlite3:/{f=1} f && /version:/{gsub(/"/,"",$2); print $2; exit}' "$LOCK")
[ -n "$VER" ] || { echo "Versão do sqlite3 não encontrada em $LOCK" >&2; exit 1; }

# SHA-256 oficial do sqlite3.wasm por versão do package:sqlite3. Ao atualizar o
# pacote, acrescente a versão nova com o digest publicado na release:
#   gh api repos/simolus3/sqlite3.dart/releases/tags/sqlite3-<versão> \
#     --jq '.assets[] | select(.name=="sqlite3.wasm") | .digest'
case "$VER" in
  3.9.1) SHA256="e7451780e78c56ff864fe9317a0fbcd6aeb2e8de3beba7f5efd963202f7ec3d9" ;;
  *)
    echo "Sem SHA-256 conhecido para sqlite3.wasm $VER: adicione-o em tool/fetch_sqlite_wasm.sh" >&2
    exit 1
    ;;
esac

URL="https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${VER}/sqlite3.wasm"
echo "Baixando $URL"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
curl -fsSL -o "$tmp" "$URL"
echo "${SHA256}  ${tmp}" | sha256sum -c --status || {
  echo "SHA-256 do sqlite3.wasm não confere (esperado ${SHA256}, obtido $(sha256sum "$tmp" | cut -d' ' -f1))" >&2
  exit 1
}
mv "$tmp" app/web/sqlite3.wasm
chmod 644 app/web/sqlite3.wasm
trap - EXIT
echo "SHA-256 do sqlite3.wasm conferido."
ls -l app/web/sqlite3.wasm
