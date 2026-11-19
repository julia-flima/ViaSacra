#!/usr/bin/env python3
"""Gera `app/assets/data/imitacao_de_cristo.json` (4 Livros, 114 capítulos) a partir
da edição livre de 'A Imitação de Cristo' (Tomás de Kempis) no Internet Archive.

Créditos da fonte:
  Tomás de Kempis — A Imitação de Cristo (tradução de E. L. de Souza Campos,
  Valdemar Teodoro Editor, 2023 — cópia e divulgação permitidas com citação da fonte).
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
    print("Baixando 'A Imitação de Cristo' do Internet Archive…")
    req = urllib.request.Request(TXT_URL, headers={"User-Agent": "ViaSacraBot/1.0"})
    texto = urllib.request.urlopen(req, timeout=45).read().decode("utf-8", "replace")
    livros = parse_imitacao(texto)
    total_caps = sum(len(lv["capitulos"]) for lv in livros)
    doc = {
        "versao": 1,
        "titulo": "A Imitação de Cristo",
        "autor": "Tomás de Kempis",
        "fonte": "Tomás de Kempis — A Imitação de Cristo (trad. E. L. de Souza Campos, Valdemar Teodoro Editor, 2023)",
        "licenca": "Obra em domínio público; edição com cópia e divulgação permitidas com citação da fonte.",
        "livros": livros,
    }
    SAIDA.write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"✔ Gerado {SAIDA.relative_to(RAIZ)}: {len(livros)} livros, {total_caps} capítulos!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
