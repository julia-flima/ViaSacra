#!/usr/bin/env bash
# Baixa as fontes opcionais (SIL Open Font License) para empacotar no app:
#   EB Garamond (serifada clássica) e Inter (sem serifa).
# Depois, descomente o bloco `fonts:` em app/pubspec.yaml.
set -euo pipefail
DEST="$(dirname "$0")/../app/assets/fonts"
mkdir -p "$DEST"
curl -fsSL -o "$DEST/EBGaramond-Variable.ttf" \
  "https://github.com/google/fonts/raw/main/ofl/ebgaramond/EBGaramond%5Bwght%5D.ttf"
curl -fsSL -o "$DEST/Inter-Variable.ttf" \
  "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf"
curl -fsSL -o "$DEST/OFL.txt" "https://github.com/google/fonts/raw/main/ofl/ebgaramond/OFL.txt"
echo "Fontes salvas em $DEST (licença: SIL OFL 1.1)."
