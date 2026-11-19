#!/usr/bin/env python3
"""Via Sacra — construtor do banco de dados local da Bíblia Sagrada (73 livros).

Padroniza arquivos de texto ou JSON das duas traduções católicas clássicas em
Domínio Público (100% compatíveis com o F-Droid):
  1. Pe. Antônio Pereira de Figueiredo (Português — 73 livros, Domínio Público)
  2. Vulgata Clementina                (Latim — 73 livros, Domínio Público, já disponível em app/assets/bible/vulgata.json)

Mapeia os 73 livros do cânon católico (46 AT com deuterocanônicos + 27 NT) com
as abreviações católicas padrão (`tool/bible/canon.py`) e gera:
  - Módulos JSON padronizados no formato `viasacra-biblia` v1 (`app/assets/bible/<id>.json`);
  - Banco SQLite otimizado com índice FTS5 (`bible_fts`), compatível com Drift / `package:sqlite3`
    (`app/assets/db/bible.db` por padrão).

Formatos de entrada aceitos para cada tradução:
  - Módulo `viasacra-biblia` v1 (`.json`, ex.: `app/assets/bible/vulgata.json`)
  - Pasta `mborders/vulgata` contendo `old_testament.json` e `new_testament.json`
  - JSON de dicionário: `{"Gênesis": {"1": {"1": "No princípio..."}}}` ou `{"gn": [["v1", "v2"]]}`
  - JSON de lista de livros: `[{"abbrev": "gn", "chapters": [["v1", "v2"]]}]`
  - Texto puro (`.txt`): linhas `Gn 1,1 Texto` / `Gn 1:1 Texto` ou blocos `# Livro` / `Capítulo N`

Exemplos de uso:
  # Gera o banco SQLite a partir da Vulgata já presente no repositório:
  python3 scripts/build_bible_db.py

  # Consolida Figueiredo e Vulgata (Domínio Público) no banco SQLite e gera os módulos JSON:
  python3 scripts/build_bible_db.py \
      --figueiredo fontes/figueiredo.json \
      --vulgata app/assets/bible/vulgata.json \
      --db-out app/assets/db/bible.db \
      --write-json \
      --update-bundled
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
import time
import unicodedata
from pathlib import Path
from typing import Any

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ / "tool/bible"))
from canon import LIVROS  # noqa: E402

SCHEMA_PATH = RAIZ / "app/assets/db/schema.sql"
ASSETS_BIBLE_DIR = RAIZ / "app/assets/bible"
DEFAULT_VULGATA_JSON = ASSETS_BIBLE_DIR / "vulgata.json"
DEFAULT_DB_OUT = RAIZ / "app/assets/db/bible.db"

# Metadados padrão das 2 traduções nativas em Domínio Público (100% F-Droid)
PRESETS: dict[str, dict[str, Any]] = {
    "figueiredo": {
        "id": "figueiredo",
        "nome": "Bíblia Sagrada — Pe. Antônio Pereira de Figueiredo",
        "sigla": "FIG",
        "abreviacao": "FIG",
        "idioma": "pt-BR",
        "licenca": "Domínio público",
        "fonte": "Tradução da Vulgata Latina pelo Pe. Antônio Pereira de Figueiredo (1778–1790)",
        "descricao": "Tradução clássica portuguesa da Vulgata Latina (73 livros, domínio público).",
        "numeracao_salmos": "grega",
    },
    "vulgata": {
        "id": "vulgata",
        "nome": "Vulgata Clementina",
        "sigla": "VUL",
        "abreviacao": "VUL",
        "idioma": "la",
        "licenca": "Domínio público",
        "fonte": "Clementine Vulgate Project, via github.com/mborders/vulgata (código MIT)",
        "descricao": "Texto latino oficial da Igreja Católica (edição Clementina, 1592/1598).",
        "numeracao_salmos": "grega",
    },
}

# Apelidos adicionais comuns em edições antigas (Figueiredo / Matos Soares / latim)
APELIDOS_EXTRAS: dict[str, list[str]] = {
    "gn": ["gên", "livro do gênesis"],
    "ex": ["êx", "livro do êxodo"],
    "1sm": ["1 samuel", "i samuel", "1º samuel", "1 reis vulgata", "i reis vulgata"],
    "2sm": ["2 samuel", "ii samuel", "2º samuel", "2 reis vulgata", "ii reis vulgata"],
    "1rs": ["1 reis", "i reis", "1º reis", "3 reis", "iii reis", "3º reis"],
    "2rs": ["2 reis", "ii reis", "2º reis", "4 reis", "iv reis", "4º reis"],
    "1cr": ["1 crônicas", "i crônicas", "1 paralipômenos", "i paralipomenos", "1paralipomenos"],
    "2cr": ["2 crônicas", "ii crônicas", "2 paralipômenos", "ii paralipomenos", "2paralipomenos"],
    "esd": ["1 esdras", "i esdras", "esd"],
    "ne": ["2 esdras", "ii esdras", "nehemias"],
    "tb": ["tobias", "tob"],
    "jt": ["judith", "judite"],
    "est": ["esther", "ester"],
    "1mc": ["1 macabeus", "i macabeus", "1 machabeus", "i machabeus"],
    "2mc": ["2 macabeus", "ii macabeus", "2 machabeus", "ii machabeus"],
    "jb": ["jó", "job", "iob"],
    "sl": ["salmos", "livro dos salmos", "psalmos", "ps"],
    "pr": ["provérbios", "proverbios", "pv"],
    "ecl": ["eclesiastes", "ec", "qohelet", "coélet"],
    "ct": ["cântico dos cânticos", "cantares", "cânticos", "cant"],
    "sb": ["sabedoria", "livro da sabedoria"],
    "eclo": ["eclesiástico", "eclesiastico", "sirácida", "siracida", "sirá", "ecclesiasticus"],
    "is": ["isaías", "isaias"],
    "jr": ["jeremias"],
    "lm": ["lamentações", "lamentações de jeremias"],
    "br": ["baruc", "baruch"],
    "ez": ["ezequiel"],
    "dn": ["daniel"],
    "os": ["oséias", "oseias"],
    "ab": ["abdias", "obadias", "ob"],
    "mq": ["miquéias", "miqueias"],
    "na": ["naum", "nahum"],
    "hab": ["habacuc", "habacuque", "hc"],
    "sf": ["sofonias"],
    "ag": ["ageu", "aggeu"],
    "zc": ["zacarias"],
    "ml": ["malaquias"],
    "mt": ["são mateus", "s mateus", "evangelho segundo são mateus", "evangelho de mateus"],
    "mc": ["são marcos", "s marcos", "evangelho segundo são marcos", "evangelho de marcos"],
    "lc": ["são lucas", "s lucas", "evangelho segundo são lucas", "evangelho de lucas"],
    "jo": ["são joão", "s joao", "evangelho segundo são joão", "evangelho de joão"],
    "at": ["atos", "actos", "atos dos apóstolos", "actos dos apostolos"],
    "rm": ["romanos", "epístola aos romanos"],
    "1cor": ["1 coríntios", "i coríntios", "1ª coríntios", "1 corintios"],
    "2cor": ["2 coríntios", "ii coríntios", "2ª coríntios", "2 corintios"],
    "gl": ["gálatas", "galatas"],
    "ef": ["efésios", "efesios"],
    "fl": ["filipenses", "fp"],
    "cl": ["colossenses", "col"],
    "1ts": ["1 tessalonicenses", "i tessalonicenses", "1ª tessalonicenses"],
    "2ts": ["2 tessalonicenses", "ii tessalonicenses", "2ª tessalonicenses"],
    "1tm": ["1 timóteo", "i timóteo", "1ª timóteo"],
    "2tm": ["2 timóteo", "ii timóteo", "2ª timóteo"],
    "tt": ["tito"],
    "fm": ["filêmon", "filemon", "filémon"],
    "hb": ["hebreus"],
    "tg": ["são tiago", "tiago", "epístola de são tiago"],
    "1pd": ["1 pedro", "i pedro", "1ª pedro", "1 são pedro", "1pe"],
    "2pd": ["2 pedro", "ii pedro", "2ª pedro", "2 são pedro", "2pe"],
    "1jo": ["1 joão", "i joão", "1ª joão", "1 são joão"],
    "2jo": ["2 joão", "ii joão", "2ª joão", "2 são joão"],
    "3jo": ["3 joão", "iii joão", "3ª joão", "3 são joão"],
    "jd": ["são judas", "judas"],
    "ap": ["apocalipse", "apocalipse de são joão"],
}

ORDEM_CANON = [x[0] for x in LIVROS]


def normalizar(s: str) -> str:
    s = unicodedata.normalize("NFKD", s)
    sem_acentos = "".join(c for c in s if not unicodedata.combining(c)).lower()
    return re.sub(r"[^a-z0-9]", "", sem_acentos)


def limpar(texto: str) -> str:
    return re.sub(r"\s+", " ", texto).strip()


def construir_indice_livros() -> dict[str, str]:
    indice: dict[str, str] = {}
    # 1ª passagem: IDs canônicos têm prioridade absoluta (evita colisão "Jó" vs "jo" = João)
    for livro in LIVROS:
        indice[livro[0]] = livro[0]
    # 2ª passagem: abreviações, nomes e apelidos (sem sobrescrever IDs canônicos)
    for livro in LIVROS:
        bid = livro[0]
        chaves = [livro[1], livro[2], livro[3], livro[6], *livro[7], *APELIDOS_EXTRAS.get(bid, [])]
        for chave in chaves:
            norm = normalizar(chave)
            if norm and norm not in indice:
                indice[norm] = bid
    return indice


INDICE_LIVROS = construir_indice_livros()


def resolver_livro(nome: str) -> str | None:
    bruto = nome.strip()
    # "Jó" (com acento) é Jó (`jb`), enquanto "Jo" (sem acento) é João (`jo`)
    if bruto.lower() in {"jó", "livro de jó"}:
        return "jb"
    chave = normalizar(bruto)
    if chave in INDICE_LIVROS:
        return INDICE_LIVROS[chave]
    # Remove prefixos comuns ("livro de ", "profecia de ", "epistola de ", "santo ", "sao ")
    prefixos = ("livrodo", "livroda", "livrode", "livrodos", "epistolaaos", "epistolade", "evangelhode", "sao", "s")
    for prefixo in prefixos:
        if chave.startswith(prefixo) and chave[len(prefixo) :] in INDICE_LIVROS:
            return INDICE_LIVROS[chave[len(prefixo) :]]
    return None


def compactar_capitulo(versos: list[tuple[int, str]]) -> list[Any]:
    versos_limpos = [(n, limpar(t)) for n, t in versos if limpar(t)]
    seq = [n for n, _ in versos_limpos] == list(range(1, len(versos_limpos) + 1))
    return [t for _, t in versos_limpos] if seq else [[n, t] for n, t in versos_limpos]


def expandir_capitulo(cap: Any) -> list[tuple[int, str]]:
    out: list[tuple[int, str]] = []
    if isinstance(cap, list):
        n = 0
        for item in cap:
            if isinstance(item, str):
                n += 1
                if limpar(item):
                    out.append((n, limpar(item)))
            elif isinstance(item, list) and len(item) == 2:
                n = int(item[0])
                if limpar(str(item[1])):
                    out.append((n, limpar(str(item[1]))))
    elif isinstance(cap, dict):
        for k, v in sorted(((int(k), str(v)) for k, v in cap.items()), key=lambda x: x[0]):
            if limpar(v):
                out.append((k, limpar(v)))
    return out


def parse_capitulos(raw_caps: Any) -> list[list[tuple[int, str]]]:
    if isinstance(raw_caps, list):
        return [expandir_capitulo(c) for c in raw_caps]
    if isinstance(raw_caps, dict):
        por_num = {int(k): expandir_capitulo(v) for k, v in raw_caps.items()}
        if not por_num:
            return []
        return [por_num.get(c, []) for c in range(1, max(por_num) + 1)]
    raise ValueError(f"Formato de capítulos não suportado: {type(raw_caps).__name__}")


def carregar_fonte_vulgata_dir(pasta: Path, campo: str = "textLatin") -> dict[str, list[list[tuple[int, str]]]]:
    por_titulo = {x[6]: x[0] for x in LIVROS}
    bruto = json.loads((pasta / "old_testament.json").read_text(encoding="utf-8")) + json.loads(
        (pasta / "new_testament.json").read_text(encoding="utf-8")
    )
    livros: dict[str, list[list[tuple[int, str]]]] = {}
    for b in bruto:
        bid = por_titulo.get(b["title"]) or resolver_livro(b["title"])
        if not bid:
            raise ValueError(f"Livro não reconhecido na Vulgata: {b['title']!r}")
        livros[bid] = [
            [(int(v["verseNumber"]), limpar(v[campo])) for v in c["verses"] if limpar(v.get(campo, ""))]
            for c in b["chapters"]
        ]
    return livros


RE_LINHA_VERSICULO = re.compile(
    r"^\s*((?:[1-3]\s*)?[A-Za-zÀ-ÿ\.]{1,25})\s+(\d{1,3})\s*[,:]\s*(\d{1,3})\s+(.+?)\s*$"
)
RE_CABECALHO_LIVRO = re.compile(r"^\s*(?:#{1,2}\s+|===\s*|LIVRO:\s*)(.+?)(?:\s*===)?\s*$", re.I)
RE_CABECALHO_CAP = re.compile(r"^\s*(?:###\s+|cap[ií]tulo\s+|cap\.?\s+)(\d{1,3})\b", re.I)
RE_VERSICULO_SOLTO = re.compile(r"^\s*(\d{1,3})[\.\)\-:\s]+(.+?)\s*$")


def carregar_txt(caminho: Path) -> dict[str, list[list[tuple[int, str]]]]:
    """Lê arquivos `.txt` no formato `Gn 1,1 Texto` ou hierárquico (`# Livro` / `Capítulo N`)."""
    temp: dict[str, dict[int, list[tuple[int, str]]]] = {}
    livro_atual: str | None = None
    cap_atual: int | None = None

    for linha in caminho.read_text(encoding="utf-8").splitlines():
        linha = linha.strip()
        if not linha:
            continue
        if m := RE_LINHA_VERSICULO.match(linha):
            bid = resolver_livro(m.group(1))
            if bid:
                cap, vers, texto = int(m.group(2)), int(m.group(3)), limpar(m.group(4))
                temp.setdefault(bid, {}).setdefault(cap, []).append((vers, texto))
                continue
        if m := RE_CABECALHO_LIVRO.match(linha):
            bid = resolver_livro(m.group(1))
            if bid:
                livro_atual = bid
                cap_atual = None
                continue
        if m := RE_CABECALHO_CAP.match(linha):
            cap_atual = int(m.group(1))
            continue
        if livro_atual and cap_atual and (m := RE_VERSICULO_SOLTO.match(linha)):
            temp.setdefault(livro_atual, {}).setdefault(cap_atual, []).append((int(m.group(1)), limpar(m.group(2))))

    livros: dict[str, list[list[tuple[int, str]]]] = {}
    for bid, caps in temp.items():
        max_cap = max(caps)
        livros[bid] = [sorted(caps.get(c, []), key=lambda x: x[0]) for c in range(1, max_cap + 1)]
    return livros


def carregar_json(caminho: Path) -> tuple[dict[str, Any], dict[str, list[list[tuple[int, str]]]]]:
    dados = json.loads(caminho.read_text(encoding="utf-8"))
    meta: dict[str, Any] = {}
    livros: dict[str, list[list[tuple[int, str]]]] = {}

    if isinstance(dados, dict) and isinstance(dados.get("livros"), list):
        meta = {k: v for k, v in dados.items() if k != "livros"}
        for item in dados["livros"]:
            chave_livro = item.get("id") or item.get("sigla") or item.get("abreviacao") or item.get("nome") or ""
            bid = resolver_livro(str(chave_livro))
            if not bid:
                raise ValueError(f"Livro não reconhecido no cânon católico: {chave_livro!r}")
            livros[bid] = parse_capitulos(item.get("capitulos") or item.get("chapters"))
        return meta, livros

    if isinstance(dados, list):
        for item in dados:
            if not isinstance(item, dict):
                continue
            chave_livro = (
                item.get("id")
                or item.get("abbrev")
                or item.get("sigla")
                or item.get("name")
                or item.get("nome")
                or ""
            )
            bid = resolver_livro(str(chave_livro))
            if not bid:
                raise ValueError(f"Livro não reconhecido no cânon católico: {chave_livro!r}")
            livros[bid] = parse_capitulos(item.get("chapters") or item.get("capitulos"))
        return meta, livros

    if isinstance(dados, dict):
        for chave_livro, caps in dados.items():
            bid = resolver_livro(str(chave_livro))
            if not bid:
                raise ValueError(f"Livro não reconhecido no cânon católico: {chave_livro!r}")
            livros[bid] = parse_capitulos(caps)
        return meta, livros

    raise ValueError(f"Estrutura JSON não suportada em {caminho}")


def carregar_traducao(
    tid: str,
    origem: Path,
    *,
    strict_73: bool = False,
) -> tuple[dict[str, Any], dict[str, list[list[tuple[int, str]]]]]:
    if not origem.exists():
        raise FileNotFoundError(f"Arquivo/pasta não encontrado para '{tid}': {origem}")

    meta_base = dict(PRESETS.get(tid, {
        "id": tid,
        "nome": tid.replace("_", " ").title(),
        "sigla": tid[:4].upper(),
        "abreviacao": tid[:4].upper(),
        "idioma": "pt-BR",
        "licenca": "Importada localmente",
        "fonte": str(origem.name),
        "descricao": "",
        "numeracao_salmos": "grega",
    }))

    if origem.is_dir():
        livros = carregar_fonte_vulgata_dir(origem)
        meta_arq: dict[str, Any] = {}
    elif origem.suffix.lower() == ".json":
        meta_arq, livros = carregar_json(origem)
    else:
        meta_arq = {}
        livros = carregar_txt(origem)

    meta = {**meta_base, **{k: v for k, v in meta_arq.items() if v not in (None, "")}}
    meta["id"] = meta_base["id"]
    sigla = meta.get("abreviacao") or meta.get("sigla") or meta_base["abreviacao"]
    meta["abreviacao"] = sigla
    meta["sigla"] = sigla

    faltando = [bid for bid in ORDEM_CANON if bid not in livros]
    if faltando:
        msg = f"[{tid}] {len(livros)}/73 livros encontrados. Ausentes: {', '.join(faltando)}"
        if strict_73:
            raise SystemExit(f"ERRO: {msg}")
        print(f"Aviso: {msg}", file=sys.stderr)
    return meta, livros


def exportar_modulo_json(
    meta: dict[str, Any],
    livros: dict[str, list[list[tuple[int, str]]]],
    destino: Path,
) -> Path:
    destino.mkdir(parents=True, exist_ok=True)
    livros_ordenados = [
        {"id": bid, "capitulos": [compactar_capitulo(cap) for cap in livros[bid]]}
        for bid in ORDEM_CANON
        if bid in livros
    ]
    total_versiculos = sum(len(v) for caps in livros.values() for v in caps)
    modulo = {
        "formato": "viasacra-biblia",
        "versao": 1,
        "id": meta["id"],
        "nome": meta["nome"],
        "sigla": meta["abreviacao"],
        "abreviacao": meta["abreviacao"],
        "idioma": meta["idioma"],
        "descricao": meta.get("descricao", ""),
        "licenca": meta["licenca"],
        "fonte": meta.get("fonte", ""),
        "numeracao_salmos": meta.get("numeracao_salmos", "grega"),
        "versao_modulo": int(meta.get("versao_modulo", 1)),
        "total_versiculos": total_versiculos,
        "livros": livros_ordenados,
    }
    arq = destino / f"{meta['id']}.json"
    arq.write_text(json.dumps(modulo, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    return arq


def construir_banco_sqlite(
    traducoes: list[tuple[dict[str, Any], dict[str, list[list[tuple[int, str]]]]]],
    db_out: Path,
) -> None:
    db_out.parent.mkdir(parents=True, exist_ok=True)
    if db_out.exists():
        db_out.unlink()

    schema = SCHEMA_PATH.read_text(encoding="utf-8")
    conn = sqlite3.connect(str(db_out))
    try:
        conn.executescript(schema)
        conn.execute("PRAGMA journal_mode = OFF;")
        conn.execute("PRAGMA synchronous = OFF;")
        conn.execute("PRAGMA foreign_keys = ON;")

        with conn:
            # 1. Cânon dos 73 livros
            conn.executemany(
                "INSERT OR REPLACE INTO bible_books "
                "(id, position, abbreviation, name, latin_name, testament, deuterocanonical) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                [
                    (b[0], idx + 1, b[1], b[2], b[3], b[4], 1 if b[5] else 0)
                    for idx, b in enumerate(LIVROS)
                ],
            )

            agora = int(time.time() * 1000)
            for meta, livros in traducoes:
                tid = meta["id"]
                total_versos = sum(len(cap) for caps in livros.values() for cap in caps)
                conn.execute(
                    """INSERT OR REPLACE INTO bible_translations
                       (id, name, abbreviation, language, license, source, description,
                        psalm_numbering, bundled, verse_count, module_version, installed_at)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)""",
                    (
                        tid,
                        meta["nome"],
                        meta["abreviacao"],
                        meta["idioma"],
                        meta["licenca"],
                        meta.get("fonte", ""),
                        meta.get("descricao", ""),
                        "hebraica" if meta.get("numeracao_salmos") == "hebraica" else "grega",
                        total_versos,
                        int(meta.get("versao_modulo", 1)),
                        agora,
                    ),
                )

                rows_caps: list[tuple[str, str, int, int]] = []
                rows_verses: list[tuple[str, str, int, int, str]] = []
                for bid in ORDEM_CANON:
                    if bid not in livros:
                        continue
                    for ci, cap in enumerate(livros[bid], start=1):
                        rows_caps.append((tid, bid, ci, len(cap)))
                        for num_vers, texto in cap:
                            rows_verses.append((tid, bid, ci, num_vers, texto))

                conn.executemany(
                    "INSERT INTO bible_chapters (translation_id, book_id, chapter, verse_count) "
                    "VALUES (?, ?, ?, ?)",
                    rows_caps,
                )
                conn.executemany(
                    "INSERT INTO bible_verses (translation_id, book_id, chapter, verse, text) "
                    "VALUES (?, ?, ?, ?, ?)",
                    rows_verses,
                )

            conn.execute("PRAGMA user_version = 2;")

        conn.commit()
        conn.isolation_level = None
        conn.execute("INSERT INTO bible_fts(bible_fts) VALUES ('optimize');")
        conn.execute("ANALYZE;")
        conn.execute("VACUUM;")
        conn.execute("PRAGMA optimize;")
    finally:
        conn.close()


def atualizar_bundled(ids: list[str], pasta_assets: Path) -> None:
    manifest_path = pasta_assets / "bundled.json"
    atuais: list[str] = []
    if manifest_path.exists():
        atuais = list(json.loads(manifest_path.read_text(encoding="utf-8")).get("modulos", []))
    # Prioriza português (Figueiredo) antes do latim/inglês (somente domínio público)
    prioridade = ["figueiredo", "vulgata"]
    combinados = list(dict.fromkeys([*prioridade, *ids, *atuais]))
    finais = [i for i in combinados if (pasta_assets / f"{i}.json").exists()]
    payload = {
        "_comentario": (
            "Traduções embutidas no app — SOMENTE Domínio Público (100% F-Droid). "
            "Use scripts/build_bible_db.py para gerar Figueiredo e Vulgata e o banco SQLite otimizado."
        ),
        "modulos": finais,
    }
    manifest_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Manifesto atualizado: {manifest_path.relative_to(RAIZ)} → {finais}")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=(
            "Padroniza Figueiredo e Vulgata (73 livros, Domínio Público) "
            "e gera o banco SQLite/FTS5 do Via Sacra."
        )
    )
    ap.add_argument("--figueiredo", type=Path, help="Arquivo JSON/TXT da tradução Pe. Antônio Pereira de Figueiredo")
    ap.add_argument(
        "--vulgata",
        type=Path,
        default=DEFAULT_VULGATA_JSON if DEFAULT_VULGATA_JSON.exists() else None,
        help=f"Arquivo JSON ou pasta da Vulgata Latina (padrão: {DEFAULT_VULGATA_JSON.relative_to(RAIZ)})",
    )
    ap.add_argument(
        "--extra",
        action="append",
        default=[],
        metavar="ID=CAMINHO",
        help="Tradução adicional no formato id=caminho (pode ser repetido)",
    )
    ap.add_argument(
        "--db-out",
        type=Path,
        default=DEFAULT_DB_OUT,
        help=f"Caminho do banco SQLite otimizado de saída (padrão: {DEFAULT_DB_OUT.relative_to(RAIZ)})",
    )
    ap.add_argument("--no-db", action="store_true", help="Não gera o arquivo SQLite (.db), apenas módulos JSON")
    ap.add_argument(
        "--write-json",
        action="store_true",
        help="Grava módulos padronizados em app/assets/bible/<id>.json",
    )
    ap.add_argument("--json-dir", type=Path, default=ASSETS_BIBLE_DIR, help="Diretório de saída dos módulos JSON")
    ap.add_argument("--update-bundled", action="store_true", help="Atualiza app/assets/bible/bundled.json")
    ap.add_argument("--strict-73", action="store_true", help="Falha se alguma tradução não tiver todos os 73 livros")
    args = ap.parse_args(argv)

    entradas: list[tuple[str, Path]] = []
    if args.figueiredo:
        entradas.append(("figueiredo", args.figueiredo))
    if args.vulgata and args.vulgata.exists():
        entradas.append(("vulgata", args.vulgata))
    for item in args.extra:
        if "=" not in item:
            ap.error(f"--extra deve seguir o formato ID=CAMINHO (recebido: {item!r})")
        eid, epath = item.split("=", 1)
        entradas.append((eid.strip(), Path(epath.strip())))

    if not entradas:
        ap.error("Nenhuma tradução encontrada. Informe --figueiredo, --matos-soares, --vulgata ou --extra.")

    traducoes: list[tuple[dict[str, Any], dict[str, list[list[tuple[int, str]]]]]] = []
    for tid, origem in entradas:
        meta, livros = carregar_traducao(tid, origem, strict_73=args.strict_73)
        total_v = sum(len(c) for caps in livros.values() for c in caps)
        print(f"✔ {tid}: {len(livros)} livros, {total_v} versículos ({meta['nome']})")
        traducoes.append((meta, livros))
        if args.write_json:
            # Evita reescrever o próprio arquivo de entrada se já estiver no destino
            destino_arq = args.json_dir / f"{tid}.json"
            if origem.resolve() != destino_arq.resolve():
                exportar_modulo_json(meta, livros, args.json_dir)
                print(f"  → JSON padronizado: {destino_arq}")

    if not args.no_db:
        construir_banco_sqlite(traducoes, args.db_out)
        tamanho_mb = args.db_out.stat().st_size / (1024 * 1024)
        print(f"✔ Banco SQLite/FTS5 gerado: {args.db_out} ({tamanho_mb:.2f} MiB)")

    if args.update_bundled:
        atualizar_bundled([m["id"] for m, _ in traducoes], args.json_dir)

    return 0


if __name__ == "__main__":
    sys.exit(main())
