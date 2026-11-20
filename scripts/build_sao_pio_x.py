#!/usr/bin/env python3
"""Gera `app/assets/db/sao_pio_x.json` (993 perguntas) a partir de
`scripts/data/sao_pio_x_1905.json`.

Fonte e licença:
  - Original: *Compendio della Dottrina Cristiana prescritto da Sua Santità Papa Pio X
    alle Diocesi della Provincia di Roma* (Tipografia Vaticana, 1905) — domínio público.
    Texto italiano a partir de duas transcrições idênticas da edição de 1905
    (lucianogianazza.it e gianfrancobertagni.it), conferidas pergunta a pergunta.
  - Tradução portuguesa: feita pelo projeto Via Sacra diretamente do italiano e dedicada
    ao domínio público (CC0 1.0). Fiel ao original, sem notas nem atualizações posteriores.
    Orações citadas nas respostas seguem o texto do Devocionário do app.

Para revisar a tradução, edite `pergunta`/`resposta` em `scripts/data/sao_pio_x_1905.json`
(o italiano está ao lado, em `pergunta_it`/`resposta_it`) e rode:
    python scripts/build_sao_pio_x.py

Para reconstituir o italiano a partir da transcrição em PDF (pdftotext -layout):
    python scripts/build_sao_pio_x.py --extrair-italiano catechismo.txt
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
DADOS = RAIZ / "scripts/data/sao_pio_x_1905.json"
SAIDA = RAIZ / "app/assets/db/sao_pio_x.json"
TOTAL_PERGUNTAS = 993


def extrair_italiano(texto: str) -> list[dict[str, object]]:
    """Perguntas ("N D. …") e respostas ("R. …") da transcrição de 1905, até a Istruzione sulle feste."""
    texto = texto.replace("‘", "'").replace("’", "'").replace("‟", "'")
    corpo = texto[texto.find("1 D. Siete voi cristiano?") : texto.find("ISTRUZIONE SOPRA LE FESTE")]
    entradas: list[dict[str, object]] = []
    atual: dict[str, object] | None = None
    campo = None
    for linha in (ln.strip() for ln in corpo.splitlines()):
        if not linha or re.fullmatch(r"\d{1,3}", linha):  # vazia ou número de página
            continue
        if m := re.match(r"^(\d{1,3})\.?\s*D\.\s*(.*)$", linha):
            atual = {"numero": len(entradas) + 1, "d": m.group(2), "r": ""}  # numeração pela sequência
            entradas.append(atual)
            campo = "d"
        elif m := re.match(r"^R\.\s*(.*)$", linha):
            if atual is not None:
                atual["r"], campo = m.group(1), "r"
        elif linha.isupper() or linha.startswith(("CAPO", "§")):
            campo = None  # títulos de parte/capítulo
        elif atual is not None and campo:
            atual[campo] = f"{atual[campo]} {linha}"
    for e in entradas:
        if not str(e["r"]).strip() and (m := re.search(r"\s*(?:\(\*\))?\s*\bR\.\s+", str(e["d"]))):
            e["d"], e["r"] = str(e["d"])[: m.start()], str(e["d"])[m.end() :]  # "(*) R." na mesma linha
        for k in ("d", "r"):
            e[k] = re.sub(r"\s+", " ", re.sub(r"(\w)-\s+(\w)", r"\1\2", str(e[k]).replace("(*)", ""))).strip()
    return entradas


def main() -> int:
    if len(sys.argv) == 3 and sys.argv[1] == "--extrair-italiano":
        entradas = extrair_italiano(Path(sys.argv[2]).read_text(encoding="utf-8"))
        print(json.dumps(entradas, ensure_ascii=False, indent=1))
        print(f"{len(entradas)} perguntas extraídas.", file=sys.stderr)
        return 0

    dados = json.loads(DADOS.read_text(encoding="utf-8"))["entradas"]
    numeros = [e["numero"] for e in dados]
    if numeros != list(range(1, TOTAL_PERGUNTAS + 1)):
        raise SystemExit(f"Esperadas as perguntas 1…{TOTAL_PERGUNTAS} em sequência.")
    vazias = [e["numero"] for e in dados if not e["pergunta"].strip() or not e["resposta"].strip()]
    if vazias:
        raise SystemExit(f"Perguntas sem tradução: {vazias}")

    doc = {
        "formato": "viasacra-catecismo",
        "versao": 1,
        "id": "sao_pio_x",
        "nome": "Catecismo Maior de São Pio X",
        "nome_curto": "São Pio X (1905)",
        "sigla": "SPX",
        "ano": 1905,
        "idioma": "pt-BR",
        "licenca": "Original de 1905 em domínio público. Tradução do projeto Via Sacra, em domínio público (CC0).",
        "fonte": (
            "Papa São Pio X — Compendio della Dottrina Cristiana (Tipografia Vaticana, 1905). "
            "Tradução do italiano pelo projeto Via Sacra."
        ),
        "descricao": (
            "Exposição completa da doutrina católica em 993 perguntas e respostas, "
            "promulgada por São Pio X em 1905."
        ),
        "rotulo_entrada": "P.",
        "versao_modulo": 4,
        "entradas": [
            {"numero": e["numero"], "parte": e["parte"], "pergunta": e["pergunta"], "resposta": e["resposta"]}
            for e in dados
        ],
    }
    SAIDA.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"✔ Gerado {SAIDA.relative_to(RAIZ)} com {len(dados)} perguntas e respostas.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
