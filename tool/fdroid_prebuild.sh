#!/usr/bin/env bash
# Prepara um build 100% a partir do código-fonte para o F-Droid:
#  • baixa o amalgamation do SQLite (domínio público) com verificação SHA3-256
#  • ativa no pubspec.yaml a compilação do SQLite a partir do fonte (sem binários pré-compilados)
# Uso (a partir de app/): bash ../tool/fdroid_prebuild.sh
set -euo pipefail

# Atualize os três juntos, copiando a linha "PRODUCT,…amalgamation…" de
# https://www.sqlite.org/download.html (versão, caminho e SHA3-256 oficiais).
SQLITE_YEAR="2026"
SQLITE_VERSION="3540100"   # 3.54.1
SQLITE_SHA3="92281c86e2957f9b9305890f9ac04204caa7b677cc868dc326d942689df28e30"

APP_DIR="$(pwd)"
DEST="$APP_DIR/third_party/sqlite"
mkdir -p "$DEST"

if [ ! -f "$DEST/sqlite3.c" ]; then
  url="https://www.sqlite.org/${SQLITE_YEAR}/sqlite-amalgamation-${SQLITE_VERSION}.zip"
  echo "Baixando $url"
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  curl -fsSL -o "$tmp" "$url"
  # Verificação obrigatória: sem hash conferido, o build para.
  python3 - "$tmp" "$SQLITE_SHA3" <<'PY'
import hashlib, sys
arquivo, esperado = sys.argv[1], sys.argv[2]
obtido = hashlib.sha3_256(open(arquivo, "rb").read()).hexdigest()
if len(esperado) != 64 or obtido != esperado:
    sys.exit(f"SHA3-256 do SQLite não confere: esperado {esperado!r}, obtido {obtido}")
print("SHA3-256 do SQLite conferido.")
PY
  unzip -j -o "$tmp" "*/sqlite3.c" "*/sqlite3.h" -d "$DEST"
fi

if ! grep -q "^hooks:" pubspec.yaml; then
  cat >> pubspec.yaml <<'YAML'

hooks:
  user_defines:
    sqlite3:
      source: source
      path: third_party/sqlite/sqlite3.c
      defines:
        defines:
          - SQLITE_ENABLE_FTS5
          - SQLITE_DQS=0
          - SQLITE_THREADSAFE=1
YAML
  echo "pubspec.yaml: SQLite será compilado a partir do código-fonte."
fi
