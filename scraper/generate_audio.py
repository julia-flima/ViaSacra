#!/usr/bin/env python3
"""Via Sacra — gerador de áudio neural em Português do Brasil (Kokoro-82M / ONNX).

Gera arquivos MP3 leves (48 kbps mono, ~2,5 MB por dia) para os JSONs da
Liturgia Diária usando o modelo open-source **Kokoro-82M** (Apache-2.0) com a
voz brasileira `pf_dora`, e atualiza `doc["audio"]["liturgia_audio_url"]` para
reprodução imediata no app (Android, iOS e Web/PWA), mantendo o TTS do aparelho
como fallback offline.

Dependências (instaladas no workflow `update-liturgy.yml`):
  - Sistema: `espeak-ng`, `ffmpeg`
  - Python: `kokoro-onnx`, `soundfile`, `numpy`
  - Modelo: `kokoro-v1.0.onnx` e `voices-v1.0.bin` (releases de thewh1teagle/kokoro-onnx)
"""

from __future__ import annotations

import argparse
import json
import logging
import re
import subprocess
import sys
import tempfile
from datetime import date, timedelta
from pathlib import Path
from typing import Any

log = logging.getLogger("viasacra.audio")

DEFAULT_CDN_BASE = "https://cdn.jsdelivr.net/gh/julia-flima/ViaSacra@data"
DEFAULT_VOICE = "pf_dora"
SAMPLE_RATE = 24000


def _quebrar_frases(texto: str, limite: int = 260) -> list[str]:
    texto = re.sub(r"\s+", " ", texto).strip()
    if not texto:
        return []
    partes = re.findall(r"[^.!?;:]+[.!?;:]*", texto)
    chunks: list[str] = []
    atual = ""
    for p in (x.strip() for x in partes if x.strip()):
        if atual and len(atual) + len(p) + 1 > limite:
            chunks.append(atual)
            atual = p
        else:
            atual = f"{atual} {p}".strip() if atual else p
    if atual:
        chunks.append(atual)
    return chunks


def montar_roteiro(doc: dict[str, Any]) -> list[str]:
    """Constrói os blocos falados da Liturgia do Dia em ordem litúrgica."""
    leituras = doc.get("leituras")
    if not isinstance(leituras, dict):
        return []

    blocos: list[str] = []
    cal = doc.get("calendario") or {}
    if celeb := cal.get("celebracao"):
        blocos.append(f"Liturgia Diária. {celeb}.")

    p1 = leituras.get("primeira_leitura")
    if isinstance(p1, dict) and p1.get("texto"):
        intro = p1.get("introducao") or "Primeira Leitura."
        blocos.append(f"{intro}. {p1['texto']} Palavra do Senhor.")

    salmo = leituras.get("salmo")
    if isinstance(salmo, dict) and (salmo.get("texto") or salmo.get("estrofes")):
        refrao = salmo.get("refrao")
        estrofes = salmo.get("estrofes") or [salmo.get("texto", "")]
        partes_sl = ["Salmo Responsorial."]
        if refrao:
            partes_sl.append(f"Refrão: {refrao}")
        for est in estrofes:
            partes_sl.append(str(est))
            if refrao:
                partes_sl.append(refrao)
        blocos.append(" ".join(partes_sl))

    p2 = leituras.get("segunda_leitura")
    if isinstance(p2, dict) and p2.get("texto"):
        intro = p2.get("introducao") or "Segunda Leitura."
        blocos.append(f"{intro}. {p2['texto']} Palavra do Senhor.")

    ev = leituras.get("evangelho")
    if isinstance(ev, dict) and ev.get("texto"):
        partes_ev: list[str] = []
        if acl := ev.get("aclamacao"):
            partes_ev.append(acl)
        partes_ev.append(ev.get("introducao") or "Proclamação do Evangelho.")
        partes_ev.append(ev["texto"])
        partes_ev.append("Palavra da Salvação.")
        blocos.append(" ".join(partes_ev))

    return blocos


def sintetizar_mp3(
    blocos: list[str],
    destino_mp3: Path,
    *,
    kokoro: Any,
    voice: str,
    speed: float,
) -> None:
    import numpy as np
    import soundfile as sf

    pausa_frase = np.zeros(int(SAMPLE_RATE * 0.45), dtype=np.float32)
    pausa_leitura = np.zeros(int(SAMPLE_RATE * 1.15), dtype=np.float32)
    trilhas: list[Any] = []

    for bi, bloco in enumerate(blocos):
        for frase in _quebrar_frases(bloco):
            samples, sr = kokoro.create(frase, voice=voice, speed=speed, lang="pt-br")
            if sr != SAMPLE_RATE:
                log.warning("Sample rate inesperado (%d Hz); esperado %d Hz", sr, SAMPLE_RATE)
            trilhas.append(np.asarray(samples, dtype=np.float32))
            trilhas.append(pausa_frase)
        if bi < len(blocos) - 1:
            trilhas.append(pausa_leitura)

    if not trilhas:
        raise RuntimeError("Roteiro vazio — nada para sintetizar.")

    audio_completo = np.concatenate(trilhas)
    destino_mp3.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp_wav:
        sf.write(tmp_wav.name, audio_completo, SAMPLE_RATE)
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-i",
                tmp_wav.name,
                "-ac",
                "1",
                "-ar",
                "24000",
                "-b:a",
                "48k",
                str(destino_mp3),
            ],
            check=True,
        )


def podar_antigos(pasta_audio: Path, manter_dias: int = 14) -> None:
    if not pasta_audio.exists():
        return
    limite = (date.today() - timedelta(days=manter_dias)).isoformat()
    for arq in pasta_audio.glob("*.mp3"):
        if arq.stem < limite:
            arq.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    ap = argparse.ArgumentParser(description="Gera áudios MP3 neurais (Kokoro-82M pt-BR) da Liturgia Diária.")
    ap.add_argument("--dir", type=Path, required=True, help="Raiz do branch `data` (contendo `liturgia/`)")
    ap.add_argument("--model", type=Path, required=True, help="Caminho para `kokoro-v1.0.onnx`")
    ap.add_argument("--voices", type=Path, required=True, help="Caminho para `voices-v1.0.bin`")
    ap.add_argument("--voice", default=DEFAULT_VOICE, help=f"Voz pt-BR do Kokoro (padrão: {DEFAULT_VOICE})")
    ap.add_argument("--speed", type=float, default=0.96, help="Velocidade da narração (padrão: 0.96, pausada)")
    ap.add_argument("--days", type=int, default=7, help="Quantos dias a partir de hoje/data mais recente processar")
    ap.add_argument("--cdn-base", default=DEFAULT_CDN_BASE, help="Base pública da CDN para `liturgia_audio_url`")
    ap.add_argument("--force", action="store_true", help="Regera o MP3 mesmo se já existir")
    args = ap.parse_args(argv)

    pasta_lit = args.dir / "liturgia"
    pasta_audio = args.dir / "audio"
    arquivos = sorted(
        [p for p in pasta_lit.glob("????-??-??.json")],
        key=lambda p: p.stem,
    )[-args.days :]

    if not arquivos:
        log.info("Nenhum JSON de liturgia encontrado em %s", pasta_lit)
        return 0

    from kokoro_onnx import Kokoro

    kokoro = Kokoro(str(args.model), str(args.voices))
    gerados = 0

    for arq in arquivos:
        doc = json.loads(arq.read_text(encoding="utf-8"))
        blocos = montar_roteiro(doc)
        if not blocos:
            continue

        iso = arq.stem
        destino_mp3 = pasta_audio / f"{iso}.mp3"
        if args.force or not destino_mp3.exists():
            log.info("Sintetizando %s (%d blocos, voz %s)…", iso, len(blocos), args.voice)
            sintetizar_mp3(blocos, destino_mp3, kokoro=kokoro, voice=args.voice, speed=args.speed)
            gerados += 1

        url_publica = f"{args.cdn_base.rstrip('/')}/audio/{iso}.mp3"
        audio = doc.setdefault("audio", {})
        audio["liturgia_audio_url"] = url_publica
        audio["fallback"] = "tts_local_pt_BR"
        creditos = [c for c in audio.get("creditos", []) if c.get("campo") != "liturgia_audio_url"]
        creditos.append(
            {
                "campo": "liturgia_audio_url",
                "canal": f"Via Sacra — Voz Neural Kokoro ({args.voice}, pt-BR)",
                "licenca": "Apache-2.0 (Kokoro-82M)",
            }
        )
        audio["creditos"] = creditos
        arq.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    podar_antigos(pasta_audio)
    log.info("Concluído: %d áudio(s) neural(is) gerado(s).", gerados)
    return 0


if __name__ == "__main__":
    sys.exit(main())
