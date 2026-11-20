#!/usr/bin/env bash
# Confere, antes de compilar uma release, que a tag bate com app/pubspec.yaml e
# que o versionCode subiu em relação à release estável anterior (sem isso o
# Android, o Obtainium e o F-Droid não instalam a atualização por cima).
# Uso (raiz do repositório, com as tags baixadas): bash tool/check_release_version.sh v1.3.0
set -euo pipefail
TAG="${1:?informe a tag, ex.: v1.3.0}"
[[ "$TAG" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)(-[0-9A-Za-z.]+)?$ ]] || { echo "::error::Tag inválida: '$TAG'"; exit 1; }
want="${BASH_REMATCH[1]}"

pubspec_version() { sed -n 's/^version:[[:space:]]*//p' | head -1; }
atual="$(pubspec_version < app/pubspec.yaml)"
nome="${atual%%+*}"
codigo="${atual#*+}"
[[ "$codigo" =~ ^[0-9]+$ ]] || { echo "::error::pubspec.yaml sem versionCode (+N): '$atual'"; exit 1; }
if [ "$nome" != "$want" ]; then
  echo "::error::A tag $TAG pede a versão $want, mas app/pubspec.yaml diz $nome"
  exit 1
fi

# Release estável anterior: a versão imediatamente antes de v$want entre as tags sem "-…".
anterior="$({ git tag --list 'v[0-9]*' | grep -v -- '-'; echo "v$want"; } | sort -uV | grep -B1 -x -- "v$want" | head -1)"
[ "$anterior" = "v$want" ] && anterior=""
if [ -n "$anterior" ]; then
  cod_ant="$(git show "$anterior:app/pubspec.yaml" | pubspec_version)"
  cod_ant="${cod_ant#*+}"
  if [ "$codigo" -le "$cod_ant" ]; then
    echo "::error::versionCode $codigo não é maior que o de $anterior ($cod_ant): suba o +N em app/pubspec.yaml"
    exit 1
  fi
  echo "Release anterior: $anterior (versionCode $cod_ant)."
fi
echo "Versão conferida: $TAG ↔ pubspec $atual."
