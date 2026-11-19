#!/usr/bin/env python3
"""Importa o texto integral do Catecismo para app/assets/db/catechism.json.

⚠️ O texto do CIC é protegido por direitos autorais (© Libreria Editrice
Vaticana; edição brasileira: CNBB / Edições Loyola / Vozes / Paulinas / Ave-Maria).
Use este script SOMENTE com uma fonte para a qual o projeto tenha obtido
autorização por escrito, e registre a autorização em docs/COPYRIGHT.md.

Entrada: CSV ou JSON Lines com as colunas/chaves
    n, parte, secao, capitulo, artigo, titulo, texto

Uso:
    python tool/import_catechism.py cic_autorizado.jsonl --autorizacao "LEV prot. nº ..."
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
DESTINO = RAIZ / "app/assets/db/catechism.json"


def ler(caminho: Path) -> list[dict]:
    if caminho.suffix == ".csv":
        with caminho.open(encoding="utf-8") as f:
            return list(csv.DictReader(f))
    return [json.loads(linha) for linha in caminho.read_text(encoding="utf-8").splitlines() if linha.strip()]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("entrada", type=Path)
    ap.add_argument("--autorizacao", required=True, help="Referência da autorização de uso do texto")
    args = ap.parse_args()

    atual = json.loads(DESTINO.read_text(encoding="utf-8"))
    paragrafos = []
    for r in ler(args.entrada):
        n = int(r["n"])
        if not 1 <= n <= 2865:
            print(f"Parágrafo inválido: {n}", file=sys.stderr)
            return 1
        paragrafos.append({
            "n": n,
            "parte": int(r.get("parte") or 0),
            "secao": int(r["secao"]) if r.get("secao") else None,
            "capitulo": int(r["capitulo"]) if r.get("capitulo") else None,
            "artigo": int(r["artigo"]) if r.get("artigo") else None,
            "titulo": r.get("titulo") or None,
            "texto": r["texto"].strip(),
        })
    paragrafos.sort(key=lambda p: p["n"])
    atual["paragrafos"] = paragrafos
    atual["versao"] = int(atual.get("versao", 1)) + 1
    atual["autorizacao"] = args.autorizacao
    DESTINO.write_text(json.dumps(atual, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{len(paragrafos)} parágrafos importados (versão {atual['versao']}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
