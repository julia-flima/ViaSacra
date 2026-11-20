#!/usr/bin/env python3
"""Gera o módulo da Bíblia em português (Domínio Público, 73 livros católicos).

Fonte: Bíblia Portuguesa Mundial (porbrbsl — eBible.org, Domínio Público),
contendo o Cânon Católico completo de 73 livros (46 do Antigo Testamento,
incluindo os 7 deuterocanônicos + Ester e Daniel gregos, e 27 do Novo
Testamento).

Saída: `app/assets/bible/bpm.json` no formato `viasacra-biblia` v1.

Uso:
  python scripts/build_ptbr_bible.py
  python scripts/build_ptbr_bible.py --zip /caminho/para/porbrbsl_usfm.zip
"""

from __future__ import annotations

import argparse
import io
import json
import re
import sys
import urllib.request
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ / "tool/bible"))
from canon import LIVROS  # noqa: E402 — depende do sys.path acima

URL_PADRAO = "https://ebible.org/Scriptures/porbrbsl_usfm.zip"
SAIDA_PADRAO = RAIZ / "app/assets/bible/bpm.json"

# Mapeamento canônico: id em tool/bible/canon.py -> código USFM em porbrbsl.
# Usa ESG (Ester grego, 205 versículos) e DAG (Daniel grego, 14 capítulos)
# para preservar integralmente as partes deuterocanônicas do cânon católico.
CANON_PARA_USFM: dict[str, str] = {
    "gn": "GEN",
    "ex": "EXO",
    "lv": "LEV",
    "nm": "NUM",
    "dt": "DEU",
    "js": "JOS",
    "jz": "JDG",
    "rt": "RUT",
    "1sm": "1SA",
    "2sm": "2SA",
    "1rs": "1KI",
    "2rs": "2KI",
    "1cr": "1CH",
    "2cr": "2CH",
    "esd": "EZR",
    "ne": "NEH",
    "tb": "TOB",
    "jt": "JDT",
    "est": "ESG",
    "1mc": "1MA",
    "2mc": "2MA",
    "jb": "JOB",
    "sl": "PSA",
    "pr": "PRO",
    "ecl": "ECC",
    "ct": "SNG",
    "sb": "WIS",
    "eclo": "SIR",
    "is": "ISA",
    "jr": "JER",
    "lm": "LAM",
    "br": "BAR",
    "ez": "EZK",
    "dn": "DAG",
    "os": "HOS",
    "jl": "JOL",
    "am": "AMO",
    "ab": "OBA",
    "jn": "JON",
    "mq": "MIC",
    "na": "NAM",
    "hab": "HAB",
    "sf": "ZEP",
    "ag": "HAG",
    "zc": "ZEC",
    "ml": "MAL",
    "mt": "MAT",
    "mc": "MRK",
    "lc": "LUK",
    "jo": "JHN",
    "at": "ACT",
    "rm": "ROM",
    "1cor": "1CO",
    "2cor": "2CO",
    "gl": "GAL",
    "ef": "EPH",
    "fl": "PHP",
    "cl": "COL",
    "1ts": "1TH",
    "2ts": "2TH",
    "1tm": "1TI",
    "2tm": "2TI",
    "tt": "TIT",
    "fm": "PHM",
    "hb": "HEB",
    "tg": "JAS",
    "1pd": "1PE",
    "2pd": "2PE",
    "1jo": "1JN",
    "2jo": "2JN",
    "3jo": "3JN",
    "jd": "JUD",
    "ap": "REV",
}

# Linhas estruturais/editoriais que não pertencem ao texto de um versículo.
LINHAS_IGNORADAS = re.compile(
    r"^\\(?:id|ide|h|toc\d|mt\d?|ip|is\d?|ms\d?|mr|s\d?|r|cl|cp|d|sp)\b"
)
# Marcadores de parágrafo/poesia que apenas iniciam linha dentro de um versículo.
MARCADOR_PARAGRAFO = re.compile(r"^\\(?:p|q\d?|m|mi|nb|pc|pi\d?|li\d?|b)\b\s*")
NOTAS_RODAPE = re.compile(r"\\(?:f|x)\b.*?\\(?:f|x)\*", re.DOTALL)
MARCADOR_INLINE = re.compile(r"\\\+?[a-zA-Z0-9]+\*?\s*")
ESPACOS = re.compile(r"\s+")
ESPACO_ANTES_PONTUACAO = re.compile(r"\s+([,.;:!?])")


def limpar_texto(texto: str) -> str:
    texto = NOTAS_RODAPE.sub("", texto)
    texto = MARCADOR_INLINE.sub("", texto)
    texto = ESPACOS.sub(" ", texto).strip()
    texto = ESPACO_ANTES_PONTUACAO.sub(r"\1", texto)
    return texto


def parse_usfm(conteudo: str) -> list[list]:
    """Extrai capítulos e versículos de um arquivo USFM no formato viasacra-biblia."""
    # Remove notas de rodapé/referências cruzadas antes do parsing por linha
    # (algumas podem conter marcadores internos).
    conteudo = NOTAS_RODAPE.sub("", conteudo)

    capitulos: dict[int, list[tuple[int, str]]] = {}
    cap_atual: int | None = None
    verso_atual: int | None = None
    buffer: list[str] = []

    def fechar_verso() -> None:
        nonlocal verso_atual, buffer
        if cap_atual is None or verso_atual is None:
            buffer = []
            return
        texto = limpar_texto(" ".join(buffer))
        if texto:
            lista = capitulos.setdefault(cap_atual, [])
            if lista and lista[-1][0] == verso_atual:
                lista[-1] = (verso_atual, f"{lista[-1][1]} {texto}")
            else:
                lista.append((verso_atual, texto))
        verso_atual = None
        buffer = []

    for linha in conteudo.splitlines():
        linha = linha.strip()
        if not linha:
            continue

        m_cap = re.match(r"^\\c\s+(\d+)\b", linha)
        if m_cap:
            fechar_verso()
            cap_atual = int(m_cap.group(1))
            capitulos.setdefault(cap_atual, [])
            continue

        if LINHAS_IGNORADAS.match(linha):
            fechar_verso()
            continue

        m_verso = re.match(r"^\\v\s+(\d+)(?:-\d+)?[a-z]?\s*(.*)$", linha)
        if m_verso:
            fechar_verso()
            verso_atual = int(m_verso.group(1))
            resto = m_verso.group(2).strip()
            if resto:
                buffer.append(resto)
            continue

        if verso_atual is not None:
            sem_tag = MARCADOR_PARAGRAFO.sub("", linha).strip()
            if sem_tag:
                buffer.append(sem_tag)

    fechar_verso()

    resultado: list[list] = []
    for num_cap in sorted(capitulos):
        versos = capitulos[num_cap]
        if not versos:
            continue
        sequencial = [n for n, _ in versos] == list(range(1, len(versos) + 1))
        resultado.append([t for _, t in versos] if sequencial else [[n, t] for n, t in versos])
    return resultado


def abrir_zip(caminho_zip: Path | None) -> zipfile.ZipFile:
    if caminho_zip is not None:
        return zipfile.ZipFile(caminho_zip)
    print(f"Baixando {URL_PADRAO}...")
    req = urllib.request.Request(URL_PADRAO, headers={"User-Agent": "ViaSacra-Builder/1.0"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return zipfile.ZipFile(io.BytesIO(resp.read()))


def construir(caminho_zip: Path | None, saida: Path) -> None:
    assert len(CANON_PARA_USFM) == 73
    ordem_canon = [x[0] for x in LIVROS]
    assert set(CANON_PARA_USFM) == set(ordem_canon)

    with abrir_zip(caminho_zip) as zf:
        por_codigo: dict[str, str] = {}
        for nome in zf.namelist():
            if not nome.endswith(".usfm"):
                continue
            m = re.match(r"^\d+-([A-Z0-9]{3})", Path(nome).name)
            if m:
                por_codigo[m.group(1)] = nome

        livros_saida: list[dict] = []
        total_versiculos = 0

        for bid in ordem_canon:
            cod = CANON_PARA_USFM[bid]
            arquivo = por_codigo.get(cod)
            if not arquivo:
                raise SystemExit(f"Livro ausente no ZIP: {bid} ({cod})")
            caps = parse_usfm(zf.read(arquivo).decode("utf-8-sig"))
            if not caps:
                raise SystemExit(f"Nenhum capítulo extraído de {bid} ({arquivo})")
            for ci, cap in enumerate(caps, 1):
                for item in cap:
                    texto = item[1] if isinstance(item, list) else item
                    if not texto or "\\" in texto:
                        raise SystemExit(f"Texto inválido em {bid} {ci}: {texto!r}")
            total_versiculos += sum(len(c) for c in caps)
            livros_saida.append({"id": bid, "capitulos": caps})

    modulo = {
        "formato": "viasacra-biblia",
        "versao": 1,
        "id": "bpm",
        "nome": "Bíblia Portuguesa Mundial",
        "abreviacao": "BPM",
        "idioma": "pt-BR",
        "descricao": (
            "Tradução em português brasileiro de domínio público (eBible.org), "
            "com o cânon católico completo de 73 livros."
        ),
        "licenca": "Domínio público",
        "fonte": "eBible.org — Bíblia Portuguesa Mundial (porbrbsl, Domínio Público)",
        "numeracao_salmos": "hebraica",
        "total_versiculos": total_versiculos,
        "livros": livros_saida,
    }

    saida.parent.mkdir(parents=True, exist_ok=True)
    saida.write_text(json.dumps(modulo, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    tam_mb = saida.stat().st_size / (1024 * 1024)
    print(f"bpm: {len(livros_saida)} livros, {total_versiculos} versículos ({tam_mb:.2f} MB) → {saida}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Gera app/assets/bible/bpm.json (Domínio Público, pt-BR, 73 livros)")
    ap.add_argument("--zip", type=Path, help="Caminho local do arquivo porbrbsl_usfm.zip")
    ap.add_argument("--saida", type=Path, default=SAIDA_PADRAO, help="Arquivo JSON de saída")
    args = ap.parse_args()
    construir(args.zip, args.saida)
    return 0


if __name__ == "__main__":
    sys.exit(main())
