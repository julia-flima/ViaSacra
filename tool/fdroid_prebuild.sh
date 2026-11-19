#!/usr/bin/env bash
# Prepara um build 100% a partir do código-fonte para o F-Droid:
#  • baixa o amalgamation do SQLite (domínio público) com verificação SHA3-256
#  • ativa no pubspec.yaml a compilação do SQLite a partir do fonte (sem binários pré-compilados)
# Uso (a partir de app/): bash ../tool/fdroid_prebuild.sh
set -euo pipefail

SQLITE_YEAR="2025"
SQLITE_VERSION="3500400"   # 3.50.4 — atualize junto com o hash abaixo
SQLITE_SHA3=""             # preencha com o SHA3-256 publicado em https://sqlite.org/download.html

APP_DIR="$(pwd)"
DEST="$APP_DIR/third_party/sqlite"
mkdir -p "$DEST"

if [ ! -f "$DEST/sqlite3.c" ]; then
  url="https://www.sqlite.org/${SQLITE_YEAR}/sqlite-amalgamation-${SQLITE_VERSION}.zip"
  echo "Baixando $url"
  curl -fsSL -o /tmp/sqlite.zip "$url"
  if [ -n "$SQLITE_SHA3" ]; then
    echo "$SQLITE_SHA3  /tmp/sqlite.zip" | python3 -c "
import hashlib,sys
exp,f=sys.stdin.read().split()
h=hashlib.sha3_256(open(f,'rb').read()).hexdigest()
sys.exit(0 if h==exp else print('SHA3 inválido',h) or 1)"
  fi
  unzip -j -o /tmp/sqlite.zip "*/sqlite3.c" "*/sqlite3.h" -d "$DEST"
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
