#!/usr/bin/env python3
"""Gera `app/assets/data/imitacao_de_cristo.json` (4 Livros, 114 capítulos) a partir
da edição de 'A Imitação de Cristo' (Tomás de Kempis) no Internet Archive.

Créditos e licença da fonte (folha de rosto da edição):
  Tradução de E. L. de Souza Campos a partir da edição francesa do Pe. Marcel Bouix SJ
  (Paris, Henri Oudin, 1864). © 2023 Valdemar Teodoro Editor (Niterói – RJ).
  "Toda cópia e divulgação são permitidas, desde que citada a fonte."
  A obra original é de domínio público; esta tradução não. É uma permissão de cópia
  com citação, não uma licença livre (decisão do projeto: manter, com atribuição).

Uso: python scripts/build_imitacao.py [arquivo.txt]
"""

from __future__ import annotations

import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
SAIDA = RAIZ / "app/assets/data/imitacao_de_cristo.json"
TXT_URL = (
    "https://archive.org/download/tomas-de-kempis-imitacao-de-cristo/"
    + urllib.parse.quote("Tomás de Kempis - Imitação de Cristo.txt")
)


def parse_imitacao(texto: str) -> list[dict[str, object]]:
    linhas = [ln.strip() for ln in texto.replace("\ufeff", "").splitlines()]
    livros: list[dict[str, object]] = []
    livro_atual: dict[str, object] | None = None
    cap_atual: dict[str, object] | None = None
    esperando_subtitulo_livro = False
    esperando_titulo_cap = False
    paragrafo_buf: list[str] = []

    def fechar_paragrafo() -> None:
        nonlocal paragrafo_buf
        if cap_atual is not None and paragrafo_buf:
            bloco = re.sub(r"\s+", " ", " ".join(paragrafo_buf)).strip()
            bloco = re.sub(r"\[\d+\]", "", bloco)
            bloco = re.sub(r"\s*__\s*", " — ", bloco)  # travessões vieram como "__" no TXT
            bloco = re.sub(r"\s+([.,;:!?])", r"\1", bloco).strip()
            if bloco:
                cap_atual["paragrafos"].append(bloco)
        paragrafo_buf = []

    for ln in linhas:
        if not ln or set(ln) <= {"_", "-", "="}:
            continue
        if re.match(r"^Notas\b", ln, re.IGNORECASE):
            fechar_paragrafo()
            break
        if m := re.match(r"^Livro\s+([IVX]+)$", ln):
            fechar_paragrafo()
            livro_atual = {"numero": m.group(1), "titulo": f"Livro {m.group(1)}", "subtitulo": "", "capitulos": []}
            livros.append(livro_atual)
            cap_atual = None
            esperando_subtitulo_livro = True
            esperando_titulo_cap = False
            continue
        if esperando_subtitulo_livro and livro_atual is not None:
            livro_atual["subtitulo"] = ln
            esperando_subtitulo_livro = False
            continue
        if m := re.match(r"^Cap[íi]tulo\s+(\d+)$", ln, re.IGNORECASE):
            fechar_paragrafo()
            if livro_atual is None:
                continue
            cap_atual = {"numero": int(m.group(1)), "titulo": "", "paragrafos": []}
            livro_atual["capitulos"].append(cap_atual)
            esperando_titulo_cap = True
            continue
        if esperando_titulo_cap and cap_atual is not None:
            if re.fullmatch(r"\d{1,2}", ln):  # Livro I, Cap. 11: o "01" vem antes do título
                continue
            cap_atual["titulo"] = ln.rstrip(".")
            esperando_titulo_cap = False
            continue
        if cap_atual is None:
            continue
        if re.fullmatch(r"\d{1,2}", ln):
            fechar_paragrafo()
            continue
        paragrafo_buf.append(ln)

    fechar_paragrafo()
    return [lv for lv in livros if lv["capitulos"]]


def main() -> int:
    if len(sys.argv) > 1:
        texto = Path(sys.argv[1]).read_text(encoding="utf-8")
    else:
        print("Baixando 'A Imitação de Cristo' do Internet Archive…")
        req = urllib.request.Request(TXT_URL, headers={"User-Agent": "ViaSacraBot/1.0"})
        texto = urllib.request.urlopen(req, timeout=45).read().decode("utf-8", "replace")
    livros = parse_imitacao(texto)
    total_caps = sum(len(lv["capitulos"]) for lv in livros)
    if total_caps != 114:
        raise RuntimeError(f"Esperados 114 capítulos; encontrados {total_caps}.")
    sem_titulo = [f"{lv['numero']},{c['numero']}" for lv in livros for c in lv["capitulos"]
                  if not c["titulo"] or re.fullmatch(r"\d+", c["titulo"])]
    if sem_titulo:
        raise RuntimeError(f"Capítulos sem título: {sem_titulo}")
    doc = {
        "versao": 2,
        "titulo": "A Imitação de Cristo",
        "autor": "Tomás de Kempis",
        "fonte": (
            "Tomás de Kempis — A Imitação de Cristo. Tradução de E. L. de Souza Campos (a partir da "
            "edição francesa do Pe. Marcel Bouix SJ, 1864). © 2023 Valdemar Teodoro Editor, Niterói – RJ."
        ),
        "licenca": (
            "Original em domínio público. Tradução © 2023 Valdemar Teodoro Editor — "
            "\"Toda cópia e divulgação são permitidas, desde que citada a fonte.\""
        ),
        "livros": livros,
    }
    SAIDA.write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"✔ Gerado {SAIDA.relative_to(RAIZ)}: {len(livros)} livros, {total_caps} capítulos!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
