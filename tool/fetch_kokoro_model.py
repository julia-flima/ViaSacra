"""Prepara as vozes que vão dentro do APK/IPA: Kokoro-82M (Apache-2.0) e Piper Faber (CC0), do sherpa-onnx.

Baixa o pacote oficial, confere o SHA-256 e grava em app/assets/voice/kokoro/:
  - partes de até 16 MB, com nomes simples (o Flutter só empacota a pasta, não subpastas);
  - manifest.json, que diz como remontar cada arquivo no aparelho.

Fica só o necessário para a leitura: modelo int8, vozes, tokens e o espeak-ng-data
sem os dicionários de outros idiomas (mantém pt, en, it e es). O Piper Faber (reserva do modo
Automático em aparelhos lentos) entra em piper_faber/ e usa o mesmo espeak-ng-data.

Uso (na raiz do repositório):  python3 tool/fetch_kokoro_model.py [--archive arquivo.tar.bz2]
"""

import argparse
import hashlib
import json
import shutil
import tarfile
import tempfile
import urllib.request
from pathlib import Path

URL = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-multi-lang-v1_0.tar.bz2"
SHA256 = "72c347230107ef8a31098ec4d468a605244beef5f1ed00db97efa13518800653"
# Mude junto com os pacotes: o app reinstala as vozes quando a versão muda.
VERSION = "kokoro-int8-multi-lang-v1_0+piper-faber+2"
PIPER_URL = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-pt_BR-faber-medium-int8.tar.bz2"
PIPER_SHA256 = "dbc8b1d7d729fd417ea78a350ed35696c928770ac93513d3f507bd4e88eee3fd"
PIPER_ROOT = "vits-piper-pt_BR-faber-medium-int8/"
PIPER_FILES = {"pt_BR-faber-medium.onnx", "tokens.txt", "MODEL_CARD"}
ROOT = "kokoro-int8-multi-lang-v1_0/"
KEEP_DICTS = {"pt_dict", "en_dict", "it_dict", "es_dict"}
PART_SIZE = 16 * 1024 * 1024

OUT = Path(__file__).resolve().parent.parent / "app" / "assets" / "voice" / "kokoro"


def wanted(name: str) -> bool:
    rel = name.removeprefix(ROOT)
    if rel in {"model.int8.onnx", "voices.bin", "tokens.txt", "LICENSE"}:
        return True
    if rel.startswith("espeak-ng-data/"):
        base = rel.rsplit("/", 1)[-1]
        return not base.endswith("_dict") or base in KEEP_DICTS
    return False


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def fetch(url: str, sha: str, given: Path | None, tmp: str, name: str) -> Path:
    archive = given
    if archive is None:
        archive = Path(tmp) / name
        print(f"Baixando {url}")
        with urllib.request.urlopen(url) as resp, archive.open("wb") as f:
            shutil.copyfileobj(resp, f)
    got = sha256(archive)
    if got != sha:
        raise SystemExit(f"SHA-256 de {name} não confere: esperado {sha}, obtido {got}")
    print(f"SHA-256 de {name} conferido.")
    return archive


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=Path, help="pacote do Kokoro já baixado (pula o download)")
    parser.add_argument("--piper-archive", type=Path, help="pacote do Piper Faber já baixado")
    args = parser.parse_args()

    manifest = OUT / "manifest.json"
    if manifest.exists() and json.loads(manifest.read_text())["version"] == VERSION:
        print(f"Voz Kokoro já preparada em {OUT}")
        return

    with tempfile.TemporaryDirectory() as tmp:
        kokoro = fetch(URL, SHA256, args.archive, tmp, "kokoro.tar.bz2")
        piper = fetch(PIPER_URL, PIPER_SHA256, args.piper_archive, tmp, "piper-faber.tar.bz2")

        shutil.rmtree(OUT, ignore_errors=True)
        OUT.mkdir(parents=True)
        files = []
        part_no = 0
        for archive, root, keep, prefix in (
            (kokoro, ROOT, wanted, ""),
            (piper, PIPER_ROOT, lambda n: n.removeprefix(PIPER_ROOT) in PIPER_FILES, "piper_faber/"),
        ):
            with tarfile.open(archive, "r:bz2") as tar:
                for member in tar:
                    if not member.isfile() or not keep(member.name):
                        continue
                    src = tar.extractfile(member)
                    parts = []
                    while True:
                        chunk = src.read(PART_SIZE)
                        if not chunk and parts:
                            break
                        name = f"p{part_no:04d}"
                        (OUT / name).write_bytes(chunk)
                        parts.append(name)
                        part_no += 1
                        if len(chunk) < PART_SIZE:
                            break
                    files.append({"path": prefix + member.name.removeprefix(root), "size": member.size, "parts": parts})

    manifest.write_text(json.dumps({"version": VERSION, "files": files}, indent=1))
    total = sum(f["size"] for f in files)
    print(f"{len(files)} arquivos ({total / 1e6:.1f} MB) em {part_no} partes → {OUT}")


if __name__ == "__main__":
    main()
