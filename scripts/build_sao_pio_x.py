#!/usr/bin/env python3
"""Gera `app/assets/db/sao_pio_x.json` completo a partir do EPUB em Domínio Público
do Catecismo Maior de São Pio X (1905) hospedado no Internet Archive.

Fonte (Public Domain Mark 1.0):
  https://archive.org/details/catecismo-maior-de-sc3a3o-pio-x
"""

from __future__ import annotations

import html
import io
import json
import re
import sys
import urllib.request
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
SAIDA = RAIZ / "app/assets/db/sao_pio_x.json"
EPUB_URL = "https://archive.org/download/catecismo-maior-de-sc3a3o-pio-x/catecismo-maior-de-sc3a3o-pio-x.epub"


def parte_por_numero(n: int) -> str:
    if n <= 19:
        return "Lição Preliminar — Da Doutrina Cristã"
    if n <= 248:
        return "Primeira Parte — Do Símbolo dos Apóstolos (Credo)"
    if n <= 323:
        return "Segunda Parte — Da Oração"
    if n <= 510:
        return "Terceira Parte — Dos Mandamentos de Deus e da Igreja"
    if n <= 815:
        return "Quarta Parte — Dos Sacramentos"
    return "Quinta Parte — Das Virtudes Principais e Outras Coisas Necessárias"


def limpar(texto: str) -> str:
    texto = re.sub(r"\s+", " ", texto).strip()
    texto = re.sub(r"-\s+", "", texto)
    return texto


def extrair_epub(dados: bytes) -> list[dict[str, object]]:
    zf = zipfile.ZipFile(io.BytesIO(dados))
    pages = sorted(
        [n for n in zf.namelist() if re.match(r"EPUB/page_\d+\.html$", n)],
        key=lambda s: int(re.search(r"(\d+)", s).group(1)),
    )
    linhas_globais: list[str] = []
    for p in pages:
        raw = zf.read(p).decode("utf-8", "replace")
        txt = html.unescape(re.sub(r"<[^>]+>", "\n", raw))
        for ln in txt.splitlines():
            ln = re.sub(r"\s+", " ", ln).strip()
            if not ln:
                continue
            if re.match(r"^Page\s+\d+$", ln, re.IGNORECASE):
                continue
            if len(ln) < 42 and re.match(
                r"^(?:CATECISMO MAIOR|PAPA\s*S\.?\s*Pio|S\.\s*Pio\s*X|\d{1,3})$", ln, re.IGNORECASE
            ):
                continue
            linhas_globais.append(ln)

    corpo = " ".join(linhas_globais)
    inicio = corpo.find("1) Sois cristão?")
    if inicio < 0:
        raise RuntimeError("Não foi possível localizar a pergunta 1 ('1) Sois cristão?') no EPUB.")
    corpo = corpo[inicio:]

    # Encontra todos os candidatos "N) Pergunta?" e mantém sequência monotônica (1..994)
    pat = re.compile(r"(?<!\d)(\d{1,3})\)\s+([^?]{4,280}\?)")
    candidatos = list(pat.finditer(corpo))
    selecionados: list[re.Match[str]] = []
    ultimo = 0
    for m in candidatos:
        n = int(m.group(1))
        if ultimo < n <= ultimo + 8:
            selecionados.append(m)
            ultimo = n

    entradas: list[dict[str, object]] = []
    for i, m in enumerate(selecionados):
        n = int(m.group(1))
        pergunta = limpar(m.group(2))
        ini_resp = m.end()
        fim_resp = selecionados[i + 1].start() if i + 1 < len(selecionados) else len(corpo)
        resposta = limpar(corpo[ini_resp:fim_resp])
        # Limpa cabeçalhos de capítulo/parte que aparecem colados ao fim da resposta anterior
        resposta = re.sub(
            r"\s+(?:CAP[ÍI]TULO\s+[IVXLCDM]+|PARTE\s+[A-ZÁÉÍÓÚ]+|ARTIGO\s+[IVXLCDM]+|LI[ÇC][ÃA]O\s+).*$",
            "",
            resposta,
        ).strip()
        if not resposta:
            continue
        entradas.append(
            {
                "numero": n,
                "parte": parte_por_numero(n),
                "pergunta": pergunta,
                "resposta": resposta,
            }
        )
    return entradas


def main() -> int:
    print("Baixando EPUB em Domínio Público do Internet Archive…")
    req = urllib.request.Request(EPUB_URL, headers={"User-Agent": "ViaSacraBot/1.0"})
    dados = urllib.request.urlopen(req, timeout=45).read()
    entradas = extrair_epub(dados)
    doc = {
        "formato": "viasacra-catecismo",
        "versao": 1,
        "id": "sao_pio_x",
        "nome": "Catecismo Maior de São Pio X",
        "nome_curto": "São Pio X (1905)",
        "sigla": "SPX",
        "ano": 1905,
        "idioma": "pt-BR",
        "licenca": "Domínio público (1905 — Public Domain Mark 1.0)",
        "fonte": "Papa São Pio X — Catecismo Maior da Doutrina Cristã (1905), via Internet Archive",
        "descricao": (
            "Exposição completa e fiel da doutrina católica em perguntas e respostas, "
            "promulgada por São Pio X em 1905."
        ),
        "rotulo_entrada": "P.",
        "versao_modulo": 2,
        "entradas": entradas,
    }
    SAIDA.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"✔ Gerado {SAIDA.relative_to(RAIZ)} com {len(entradas)} perguntas e respostas!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
