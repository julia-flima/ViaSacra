"""Prepara a voz Kokoro-82M (sherpa-onnx, Apache-2.0) para ir dentro do APK/IPA.

Baixa o pacote oficial, confere o SHA-256 e grava em app/assets/voice/kokoro/:
  - partes de até 16 MB, com nomes simples (o Flutter só empacota a pasta, não subpastas);
  - manifest.json, que diz como remontar cada arquivo no aparelho.

Fica só o necessário para a leitura: modelo int8, vozes, tokens e o espeak-ng-data
sem os dicionários de outros idiomas (mantém pt, en, it e es).

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
# Mude junto com o pacote: o app reinstala a voz quando a versão muda.
VERSION = "kokoro-int8-multi-lang-v1_0+1"
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=Path, help="pacote .tar.bz2 já baixado (pula o download)")
    args = parser.parse_args()

    manifest = OUT / "manifest.json"
    if manifest.exists() and json.loads(manifest.read_text())["version"] == VERSION:
        print(f"Voz Kokoro já preparada em {OUT}")
        return

    with tempfile.TemporaryDirectory() as tmp:
        archive = args.archive
        if archive is None:
            archive = Path(tmp) / "kokoro.tar.bz2"
            print(f"Baixando {URL}")
            with urllib.request.urlopen(URL) as resp, archive.open("wb") as f:
                shutil.copyfileobj(resp, f)
        got = sha256(archive)
        if got != SHA256:
            raise SystemExit(f"SHA-256 do pacote Kokoro não confere: esperado {SHA256}, obtido {got}")
        print("SHA-256 do pacote Kokoro conferido.")

        shutil.rmtree(OUT, ignore_errors=True)
        OUT.mkdir(parents=True)
        files = []
        part_no = 0
        with tarfile.open(archive, "r:bz2") as tar:
            for member in tar:
                if not member.isfile() or not wanted(member.name):
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
                files.append({"path": member.name.removeprefix(ROOT), "size": member.size, "parts": parts})

    manifest.write_text(json.dumps({"version": VERSION, "files": files}, indent=1))
    total = sum(f["size"] for f in files)
    print(f"{len(files)} arquivos ({total / 1e6:.1f} MB) em {part_no} partes → {OUT}")


if __name__ == "__main__":
    main()
