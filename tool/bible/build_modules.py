#!/usr/bin/env python3
"""Gera módulos de tradução da Bíblia no formato "viasacra-biblia" v1.

Formato do módulo (também aceito pelo importador do app):
{
  "formato": "viasacra-biblia", "versao": 1,
  "id": "vulgata", "nome": "Vulgata Clementina", "abreviacao": "VUL",
  "idioma": "la", "licenca": "Domínio público", "fonte": "...", "numeracao_salmos": "grega",
  "livros": [ {"id": "gn", "capitulos": [ ["v1", "v2", ...], ... ]}, ... ]
}
Cada capítulo é uma lista; um item é o texto (versículos sequenciais) ou
[numero, texto] quando a numeração não é sequencial. Ids de livro: tool/bible/canon.py.

Fontes suportadas:
  --vulgata DIR     pasta com old_testament.json/new_testament.json (mborders/vulgata,
                    bible.tar.gz — Vulgata Clementina + Douay-Rheims, domínio público)
  --generic ARQ     JSON genérico {livro: {capitulo: {versiculo: texto}}} com nomes/abreviações
                    em português (ex.: digitalizações de Figueiredo) — use com --id/--nome/...

Uso:
  python tool/bible/build_modules.py --vulgata /caminho/extraido
  python tool/bible/build_modules.py --generic figueiredo.json --id figueiredo \
      --nome "Bíblia Sagrada — Pe. Antônio Pereira de Figueiredo" --abreviacao FIG --idioma pt-BR
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from canon import LIVROS  # noqa: E402

RAIZ = Path(__file__).resolve().parents[2]
DESTINO = RAIZ / "app/assets/bible"


def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s)
    return re.sub(r"[^a-z0-9]", "", "".join(c for c in s if not unicodedata.combining(c)).lower())


def limpar(t: str) -> str:
    return re.sub(r"\s+", " ", t).strip()


def capitulo(versos: list[tuple[int, str]]) -> list:
    seq = [n for n, _ in versos] == list(range(1, len(versos) + 1))
    return [t for _, t in versos] if seq else [[n, t] for n, t in versos]


def gravar(modulo: dict, nome_arquivo: str) -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    total = sum(len(c) for l in modulo["livros"] for c in l["capitulos"])
    modulo["total_versiculos"] = total
    caminho = DESTINO / nome_arquivo
    caminho.write_text(json.dumps(modulo, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"{modulo['id']}: {len(modulo['livros'])} livros, {total} versículos → {caminho.relative_to(RAIZ)}")


def de_vulgata(pasta: Path) -> None:
    por_titulo = {x[6]: x[0] for x in LIVROS}
    livros_fonte = json.loads((pasta / "old_testament.json").read_text(encoding="utf-8")) + json.loads(
        (pasta / "new_testament.json").read_text(encoding="utf-8"))
    for campo, meta in (
        ("textLatin", {
            "id": "vulgata", "nome": "Vulgata Clementina", "abreviacao": "VUL", "idioma": "la",
            "descricao": "Texto latino oficial da Igreja (edição Clementina, 1592/1598).",
            "licenca": "Domínio público",
            "fonte": "Clementine Vulgate Project, via github.com/mborders/vulgata (código MIT)",
            "numeracao_salmos": "grega",
        }),
        ("text", {
            "id": "douay_rheims", "nome": "Douay-Rheims (Challoner)", "abreviacao": "DRB", "idioma": "en",
            "descricao": "Tradução católica inglesa da Vulgata (revisão de Challoner, 1749–1752).",
            "licenca": "Domínio público",
            "fonte": "github.com/mborders/vulgata (código MIT)",
            "numeracao_salmos": "grega",
        }),
    ):
        livros = {}
        for b in livros_fonte:
            bid = por_titulo[b["title"]]
            livros[bid] = [capitulo([(v["verseNumber"], limpar(v[campo])) for v in c["verses"]])
                           for c in b["chapters"]]
        ordem = [x[0] for x in LIVROS]
        assert set(livros) == set(ordem), set(ordem) ^ set(livros)
        modulo = {"formato": "viasacra-biblia", "versao": 1, **meta,
                  "livros": [{"id": i, "capitulos": livros[i]} for i in ordem]}
        gravar(modulo, f"{meta['id']}.json")


def de_generico(arquivo: Path, args: argparse.Namespace) -> None:
    dados = json.loads(arquivo.read_text(encoding="utf-8"))
    indice = {}
    for x in LIVROS:
        for chave in [x[0], x[1], x[2], x[3], x[6], *x[7]]:
            indice[norm(chave)] = x[0]
    livros = {}
    for nome, caps in dados.items():
        bid = indice.get(norm(nome))
        if not bid:
            raise SystemExit(f"Livro não reconhecido: {nome!r}")
        livros[bid] = [capitulo(sorted((int(v), limpar(t)) for v, t in caps[c].items()))
                       for c in sorted(caps, key=int)]
    faltando = [x[0] for x in LIVROS if x[0] not in livros]
    if faltando:
        print(f"Aviso: livros ausentes: {faltando}", file=sys.stderr)
    modulo = {"formato": "viasacra-biblia", "versao": 1, "id": args.id, "nome": args.nome,
              "abreviacao": args.abreviacao, "idioma": args.idioma, "licenca": args.licenca,
              "fonte": args.fonte, "numeracao_salmos": args.numeracao_salmos,
              "livros": [{"id": x[0], "capitulos": livros[x[0]]} for x in LIVROS if x[0] in livros]}
    gravar(modulo, f"{args.id}.json")


def gerar_canon() -> None:
    canon = [{"id": i, "abreviacao": a, "nome": n, "nome_latino": la, "testamento": t, "deuterocanonico": d,
              "apelidos": ap} for i, a, n, la, t, d, _, ap in LIVROS]
    (DESTINO / "canon.json").write_text(json.dumps(canon, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--vulgata", type=Path)
    ap.add_argument("--generic", type=Path)
    ap.add_argument("--id")
    ap.add_argument("--nome")
    ap.add_argument("--abreviacao")
    ap.add_argument("--idioma", default="pt-BR")
    ap.add_argument("--licenca", default="Domínio público")
    ap.add_argument("--fonte", default="")
    ap.add_argument("--numeracao-salmos", default="grega", choices=["grega", "hebraica"])
    args = ap.parse_args()
    DESTINO.mkdir(parents=True, exist_ok=True)
    gerar_canon()
    if args.vulgata:
        de_vulgata(args.vulgata)
    if args.generic:
        if not (args.id and args.nome and args.abreviacao):
            ap.error("--generic exige --id, --nome e --abreviacao")
        de_generico(args.generic, args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
