#!/usr/bin/env python3
"""Resolve, valida e baixa as obras de arte sacra do catálogo no Wikimedia Commons.

Para cada entrada de ``tool/sacred_art_catalog.json``:
1. pesquisa no Commons (namespace File) com os termos ``busca``;
2. escolhe o melhor arquivo bitmap (JPG/PNG/TIF) com maior resolução;
3. **exige** licença de domínio público / CC0 (extmetadata LicenseShortName);
4. baixa uma miniatura de ``--width`` px para ``app/assets/art/<id>.jpg``;
5. grava ``app/assets/data/sacred_art.json`` com título, artista, ano, acervo,
   arquivo do Commons, URL da página e licença — exibidos como legenda no app.

Uso: python tool/fetch_sacred_art.py [--width 900] [--dry-run]
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import time
from pathlib import Path

import requests

RAIZ = Path(__file__).resolve().parents[1]
API = "https://commons.wikimedia.org/w/api.php"
UA = "ViaSacraBot/1.0 (+https://github.com/julia-flima/ViaSacra; open source devotional app)"
LICENCAS_OK = re.compile(r"public domain|^pd|cc0|domínio público", re.I)
EXTENSOES_OK = (".jpg", ".jpeg", ".png", ".tif", ".tiff")
PALAVRAS_RUINS = (
    "detail", "detalle", "dettaglio", "detalhe", "frame", "google earth", "cropped", "sketch", "x-ray",
    "copy", "after ", "workshop", "museum interior", "exhibition", "stamp", "postcard", "cadre", "with frame", "framed",
)

sessao = requests.Session()
sessao.headers["User-Agent"] = UA


def api(**params):
    params |= {"format": "json", "formatversion": 2}
    for tentativa in range(8):
        r = sessao.get(API, params=params, timeout=30)
        if r.status_code == 429:
            espera = int(r.headers.get("Retry-After", 0) or 0) or 20 * (tentativa + 1)
            print(f"  … limite da API (429), aguardando {espera}s", file=sys.stderr, flush=True)
            time.sleep(espera)
            continue
        r.raise_for_status()
        return r.json()
    raise RuntimeError("Commons API indisponível (429)")


def candidatos(busca: str) -> list[dict]:
    dados = api(action="query", generator="search", gsrsearch=f"{busca} filetype:bitmap", gsrnamespace=6,
                gsrlimit=15, prop="imageinfo", iiprop="url|size|extmetadata|mime", iiurlwidth=900)
    paginas = dados.get("query", {}).get("pages", [])
    return sorted(paginas, key=lambda p: p.get("index", 99))


def limpar_html(valor: str | None) -> str:
    return html.unescape(re.sub(r"<[^>]+>", "", valor or "")).strip()


def pontuar(pagina: dict, item: dict) -> float:
    titulo = pagina["title"].lower()
    info = (pagina.get("imageinfo") or [{}])[0]
    if not titulo.endswith(EXTENSOES_OK):
        return -1
    licenca = limpar_html(info.get("extmetadata", {}).get("LicenseShortName", {}).get("value"))
    if not LICENCAS_OK.search(licenca):
        return -1
    pontos = 100 - pagina.get("index", 50) * 3
    if any(p in titulo for p in PALAVRAS_RUINS):
        pontos -= 60
    sobrenome = item["artista"].split()[-1].lower()
    if sobrenome[:5] in titulo or item["artista"].split()[0].lower()[:5] in titulo:
        pontos += 25
    largura, altura = info.get("width", 0), info.get("height", 0)
    pontos += min(largura * altura / 1_000_000, 20)
    return pontos


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--width", type=int, default=900)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only", help="processar apenas este id")
    args = ap.parse_args()

    catalogo = json.loads((RAIZ / "tool/sacred_art_catalog.json").read_text(encoding="utf-8"))
    saida_json = RAIZ / "app/assets/data/sacred_art.json"
    anteriores = {}
    if saida_json.exists():
        anteriores = {o["id"]: o for o in json.loads(saida_json.read_text(encoding="utf-8"))}
    pasta = RAIZ / "app/assets/art"
    pasta.mkdir(parents=True, exist_ok=True)
    resultado = []
    for item in catalogo:
        anterior = anteriores.get(item["id"])
        ja_baixado = anterior and anterior.get("imagem") and (RAIZ / "app" / anterior["imagem"]).exists()
        if (args.only and item["id"] != args.only) or (ja_baixado and not args.only):
            resultado.append(anterior | {k: v for k, v in item.items() if k != "busca"} if anterior else item)
            continue
        if item.get("arquivo_commons"):
            dados = api(action="query", titles=item["arquivo_commons"], prop="imageinfo",
                        iiprop="url|size|extmetadata|mime", iiurlwidth=args.width)
            melhores = [(1.0, dados["query"]["pages"][0])]
        else:
            melhores = sorted(((pontuar(p, item), p) for p in candidatos(item["busca"])),
                              key=lambda x: x[0], reverse=True)
        if not melhores or melhores[0][0] < 0:
            print(f"✗ {item['id']}: nenhum arquivo em domínio público encontrado", file=sys.stderr)
            resultado.append(item | {"arquivo_commons": None, "imagem": None})
            continue
        pagina = melhores[0][1]
        info = pagina["imageinfo"][0]
        meta = info.get("extmetadata", {})
        licenca = limpar_html(meta.get("LicenseShortName", {}).get("value"))
        destino = pasta / f"{item['id']}.jpg"
        if not args.dry_run:
            img = sessao.get(info.get("thumburl") or info["url"], timeout=60)
            img.raise_for_status()
            destino.write_bytes(img.content)
            time.sleep(1)
        registro = item | {
            "arquivo_commons": pagina["title"],
            "pagina_commons": info.get("descriptionurl"),
            "licenca": "Domínio público" if "cc0" not in licenca.lower() else "CC0",
            "licenca_original": licenca,
            "imagem": f"assets/art/{item['id']}.jpg",
            "credito": f"{item['titulo']} — {item['artista']} ({item['ano']}). {item['acervo']}. "
                       f"Domínio público, via Wikimedia Commons.",
        }
        resultado.append(registro)
        print(f"✓ {item['id']}: {pagina['title']} [{licenca}]", flush=True)
        if not args.dry_run:  # grava a cada item: execução retomável
            parcial = resultado + [anteriores[c["id"]] for c in catalogo[len(resultado):] if c["id"] in anteriores]
            saida_json.write_text(json.dumps(parcial, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        time.sleep(4)  # gentileza com a API do Commons
    if not args.dry_run:
        saida_json.write_text(json.dumps(resultado, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
