#!/usr/bin/env python3
"""Gera `app/assets/db/sao_pio_x.json` (994 perguntas) a partir do EPUB do
Catecismo Maior de São Pio X hospedado no Internet Archive:
  https://archive.org/details/catecismo-maior-de-sc3a3o-pio-x

Atenção à licença: o original italiano (Tipografia Vaticana, 1905) é de domínio
público, mas este EPUB é uma "tradução não oficial" em português, posterior a 2007,
"para distribuição gratuita" — sem licença livre comprovada para a tradução (o
selo Public Domain Mark do Internet Archive foi aplicado por quem enviou o
arquivo). Mantida provisoriamente até encontrarmos uma tradução comprovadamente
em domínio público (issue #29).

O extrator remove o que não é texto de São Pio X: cabeçalhos/números de página,
notas do tradutor, subtítulos e epígrafes de capítulo. Exige a sequência 1…994
e informa cada número de pergunta corrigido do OCR.

Uso: python scripts/build_sao_pio_x.py [arquivo.epub]
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
    texto = re.sub(r"(\w)-\s+(\w)", r"\1\2", texto)  # hifenização de fim de linha
    return texto


TOTAL_PERGUNTAS = 994

# Cabeçalho corrido no topo de cada página (variações do OCR).
_CABECALHO = r"(?:CATECISMO MAIOR DE\s*S(?:ÃO)?\.?\s*Pio X|PAPA\s*S\.?\s*Pio X)"
RE_CABECALHO = re.compile(rf"^\(?\s*{_CABECALHO}\s*", re.IGNORECASE)
# Quebra de página no meio do texto: "… 212 PAPAS. Pio X 3º …".
RE_CABECALHO_MEIO = re.compile(rf"\s+\d{{1,3}}\s+{_CABECALHO}\s+", re.IGNORECASE)
# Rodapé: notas do tradutor desta edição (não fazem parte do texto de São Pio X).
RE_NOTAS = re.compile(r"\s+\d{1,2}\s+Nota d[oa] Tradutor\b.*$", re.IGNORECASE)
# Número da página no fim do texto da página.
RE_NUM_PAGINA = re.compile(r"\s+\d{1,3}$")
# Cabeçalhos de parte/capítulo (com a epígrafe bíblica) colados ao fim de uma resposta.
RE_TITULO_SECAO = re.compile(
    r"\s+(?:"
    r"CAP[ÍI]TULO\b"  # o algarismo romano às vezes vem errado no OCR ("VIH")
    r"|(?:PRIMEIRA|SEGUNDA|TERCEIRA|QUARTA|QUINTA)\s+PARTE\b|PARTE\s+[A-ZÁÉÍÓÚ]+\b"
    r"|ARTIGO\s+[IVXLCDM]+\b|LI[ÇC][ÃA]O\s+PRELIMINAR\b"
    r"|(?:[8S§$]\s*)?\d{1,2}º\s*-\s*D[aoe]"  # subtítulo "§ 2º - Dos Anjos" ("§" lido como 8/S/$)
    r"|[8S§$]\s*\d{1,2}(?:º|\.0)\s*-"  # "§ 2º - Ministro…", "§ 3.0 - Das…" (exige a marca "§")
    r").*$"
)
# Erros de OCR inequívocos (palavra inteira), conferidos no contexto.
CORRECOES_OCR = {
    "camino": "caminho",
}
# Trechos embaralhados pelo OCR, corrigidos pela própria leitura duplicada na página.
# (pergunta, trecho do OCR, texto correto) — cada correção fica explícita para revisão.
CORRECOES_TEXTO = [
    (
        224,
        "em sufrágio elas, Missas, esmolas, indulgências e outras boas obras. delas, Missa la dul a tras boas obra",
        "em sufrágio delas, Missas, esmolas, indulgências e outras boas obras.",
    ),
]


def texto_da_pagina(raw_html: str) -> str:
    """Texto de uma página do EPUB sem cabeçalho, rodapé de notas e número."""
    txt = html.unescape(re.sub(r"<[^>]+>", "\n", raw_html))
    linhas = [re.sub(r"\s+", " ", ln).strip() for ln in txt.splitlines()]
    linhas = [ln for ln in linhas if ln and not re.fullmatch(r"Page\s+\d+", ln, re.IGNORECASE)]
    texto = " ".join(linhas)
    texto = RE_CABECALHO.sub("", texto)
    texto = RE_NOTAS.sub("", texto)
    return RE_NUM_PAGINA.sub("", texto).strip()


def separar_pergunta(trecho: str) -> tuple[str, str]:
    """Separa "Pergunta? Resposta" ou, nas perguntas imperativas ("Dizei-os.",
    "Rezai o Padre-Nosso."), "Ordem. Resposta"."""
    q = trecho.find("?")
    if 0 < q <= 300:
        return trecho[: q + 1], trecho[q + 1 :]
    m = re.search(r"[.](?=\s+(?:[A-ZÁÉÍÓÚÂÊÔÃÕÇ\d“\"«]|1º))", trecho)
    if m and m.start() <= 300:
        return trecho[: m.start() + 1], trecho[m.end() :]
    raise RuntimeError(f"Pergunta sem fim reconhecível: {trecho[:120]!r}")


def corrigir_ocr(texto: str) -> str:
    for errado, certo in CORRECOES_OCR.items():
        texto = re.sub(rf"\b{errado}\b", certo, texto)
    # Marcas de nota de rodapé lidas como pontuação: "excelência.?" / "alma” .!!" / "bebida.º"
    texto = re.sub(r"\s*\.\s*[?!º]+$", ".", texto)
    # Letras soltas de fim de página após o ponto final: "eterna. A", "suicídio. Ml"
    texto = re.sub(r"([.!?])\s+[A-Z][a-z]?$", r"\1", texto)
    return texto


def extrair_epub(dados: bytes) -> list[dict[str, object]]:
    zf = zipfile.ZipFile(io.BytesIO(dados))
    pages = sorted(
        [n for n in zf.namelist() if re.match(r"EPUB/page_\d+\.html$", n)],
        key=lambda s: int(re.search(r"(\d+)", s).group(1)),
    )
    corpo = " ".join(texto_da_pagina(zf.read(p).decode("utf-8", "replace")) for p in pages)

    inicio = corpo.find("1) Sois cristão?")
    if inicio < 0:
        raise RuntimeError("Não foi possível localizar a pergunta 1 ('1) Sois cristão?') no EPUB.")
    fim = corpo.find("INSTRUÇÃO SOBRE AS FESTAS", inicio)  # apêndice posterior à pergunta 994
    corpo = corpo[inicio : fim if fim > 0 else len(corpo)]
    corpo = RE_CABECALHO_MEIO.sub(" ", corpo)

    # Marcadores "N) " em sequência estrita 1, 2, 3… — um número faltando é erro, não silêncio.
    # Tolera só o erro típico de OCR num dígito ("629)" no lugar de 829) quando o
    # marcador seguinte confirma a sequência; cada correção é informada.
    def um_digito(lido: str, esperado: int) -> bool:
        alvo = str(esperado)
        return len(lido) == len(alvo) and sum(a != b for a, b in zip(lido, alvo, strict=True)) == 1

    candidatos = list(re.finditer(r"(?<![\d,])(\d{1,3})\)\s", corpo))
    marcadores: list[re.Match[str]] = []
    for i, m in enumerate(candidatos):
        esperado, lido = len(marcadores) + 1, m.group(1)
        if int(lido) == esperado:
            marcadores.append(m)
        elif um_digito(lido, esperado) and i + 1 < len(candidatos):
            seguinte = candidatos[i + 1].group(1)
            if int(seguinte) == esperado + 1 or um_digito(seguinte, esperado + 1):
                print(f"  OCR: marcador '{lido})' lido como {esperado})", file=sys.stderr)
                marcadores.append(m)
    if len(marcadores) != TOTAL_PERGUNTAS:
        raise RuntimeError(f"Encontradas {len(marcadores)} perguntas em sequência; esperado {TOTAL_PERGUNTAS}.")

    entradas: list[dict[str, object]] = []
    for i, m in enumerate(marcadores):
        n = i + 1
        fim_trecho = marcadores[i + 1].start() if i + 1 < len(marcadores) else len(corpo)
        pergunta, resposta = separar_pergunta(corpo[m.end() : fim_trecho].strip())
        resposta = RE_TITULO_SECAO.sub("", limpar(resposta)).strip()
        if not resposta:
            raise RuntimeError(f"Resposta vazia na pergunta {n}.")
        for num, errado, certo in CORRECOES_TEXTO:
            if num == n:
                if errado not in resposta:
                    raise RuntimeError(f"Correção da pergunta {n} não se aplica mais; revise CORRECOES_TEXTO.")
                resposta = resposta.replace(errado, certo)
        entradas.append(
            {
                "numero": n,
                "parte": parte_por_numero(n),
                "pergunta": corrigir_ocr(limpar(pergunta)),
                "resposta": corrigir_ocr(resposta),
            }
        )
    return entradas


def main() -> int:
    if len(sys.argv) > 1:  # EPUB já baixado: python scripts/build_sao_pio_x.py arquivo.epub
        dados = Path(sys.argv[1]).read_bytes()
    else:
        print("Baixando o EPUB do Internet Archive…")
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
        "licenca": (
            "Original de 1905 em domínio público. Tradução portuguesa não oficial, de distribuição "
            "gratuita (Internet Archive), sem as notas do tradutor — licença da tradução em verificação."
        ),
        "fonte": (
            "Papa São Pio X — Catecismo Maior da Doutrina Cristã (Tipografia Vaticana, 1905), "
            "via Internet Archive"
        ),
        "descricao": (
            "Exposição completa e fiel da doutrina católica em perguntas e respostas, "
            "promulgada por São Pio X em 1905."
        ),
        "rotulo_entrada": "P.",
        "versao_modulo": 3,
        "entradas": entradas,
    }
    SAIDA.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"✔ Gerado {SAIDA.relative_to(RAIZ)} com {len(entradas)} perguntas e respostas!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
