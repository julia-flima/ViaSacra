#!/usr/bin/env bash
# Baixa o sqlite3.wasm compatível com a versão do package:sqlite3 travada no
# pubspec.lock (necessário para o banco offline da versão Web/PWA).
# Uso (a partir da raiz do repositório): bash tool/fetch_sqlite_wasm.sh
set -euo pipefail
cd "$(dirname "$0")/.."   # funciona a partir de qualquer pasta
LOCK="app/pubspec.lock"
VER=$(awk '/^  sqlite3:/{f=1} f && /version:/{gsub(/"/,"",$2); print $2; exit}' "$LOCK")
[ -n "$VER" ] || { echo "Versão do sqlite3 não encontrada em $LOCK" >&2; exit 1; }
URL="https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${VER}/sqlite3.wasm"
echo "Baixando $URL"
curl -fsSL -o app/web/sqlite3.wasm "$URL"
ls -l app/web/sqlite3.wasm
