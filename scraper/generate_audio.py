#!/usr/bin/env python3
"""Gera áudios neurais MP3 (pt-BR) da Liturgia Diária e da Homilia usando Piper TTS.

Usa a voz neural open-source Piper `pt_BR-cadu-medium` (CC0 Domínio Público,
22.05 kHz, português brasileiro claro e natural) rodando 100% em CPU no GitHub
Actions, comprimindo em MP3 mono 48 kbps (~0,7–1,2 MB/dia) via ffmpeg.

Os arquivos são gravados em `<dir>/audio/AAAA-MM-DD.mp3` (Liturgia completa) e
`<dir>/audio/AAAA-MM-DD-homilia.mp3` (Homilia do dia), publicados no branch
`data` e referenciados em `audio.liturgia_audio_url` e `audio.homilia_audio_url`
no JSON do dia.

Uso:
    python generate_audio.py --dir ../data-branch --model-dir /tmp/piper-models
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
import tempfile
import urllib.request
import wave
from pathlib import Path

VOICE_ID = "pt_BR-cadu-medium"
MODEL_BASE_URL = (
    "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/pt/pt_BR/cadu/medium"
)
MODEL_FILES = (
    f"{VOICE_ID}.onnx",
    f"{VOICE_ID}.onnx.json",
)
CDN_BASE = "https://cdn.jsdelivr.net/gh/julia-flima/ViaSacra@data/audio"
KEEP_DAYS = 14


def download_models(model_dir: Path) -> Path:
    model_dir.mkdir(parents=True, exist_ok=True)
    for fname in MODEL_FILES:
        dst = model_dir / fname
        if dst.exists() and dst.stat().st_size > 1_000:
            continue
        url = f"{MODEL_BASE_URL}/{fname}"
        print(f"Baixando {fname}...", flush=True)
        req = urllib.request.Request(url, headers={"User-Agent": "ViaSacra-Audio/1.0"})
        with urllib.request.urlopen(req, timeout=180) as resp:
            dst.write_bytes(resp.read())
    return model_dir / f"{VOICE_ID}.onnx"


def clean_speech_text(text: str) -> str:
    text = re.sub(r"[✝✦•▪▸►]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def build_liturgy_script(doc: dict) -> str:
    parts: list[str] = []
    celebracao = (doc.get("celebracao") or "").strip()
    if celebracao:
        parts.append(f"Liturgia Diária. {celebracao}.")

    leituras = doc.get("leituras") or {}
    order = [
        ("primeira_leitura", "Primeira Leitura"),
        ("salmo", "Salmo Responsorial"),
        ("segunda_leitura", "Segunda Leitura"),
        ("evangelho", "Evangelho"),
    ]
    for key, label in order:
        r = leituras.get(key)
        if not isinstance(r, dict):
            continue
        texto = (r.get("texto") or "").strip()
        refrao = (r.get("refrao") or "").strip()
        estrofes = r.get("estrofes") or []
        if not texto and not refrao and not estrofes:
            continue
        intro = (r.get("introducao") or "").strip()
        aclamacao = (r.get("aclamacao") or "").strip()

        seg = [f"{label}."]
        if intro:
            seg.append(intro)
        if key == "salmo":
            if refrao:
                seg.append(f"Refrão: {refrao}.")
            for est in estrofes:
                est_clean = str(est).strip()
                if est_clean:
                    seg.append(est_clean)
                    if refrao:
                        seg.append(refrao)
            if not estrofes and texto:
                seg.append(texto)
        else:
            if aclamacao:
                seg.append(aclamacao)
            if texto:
                seg.append(texto)
        parts.append(" ".join(seg))

    return clean_speech_text("\n\n".join(parts))


def build_homily_script(doc: dict) -> str:
    homilias = doc.get("homilias") or {}
    vat = homilias.get("vaticano") or homilias.get("vatican_news")
    if not isinstance(vat, dict):
        return ""
    texto = (vat.get("texto") or "").strip()
    if not texto:
        return ""
    titulo = (vat.get("titulo") or "Homilia do Dia").strip()
    autor = (vat.get("autor") or "").strip()
    header = f"{titulo}."
    if autor:
        header += f" {autor}."
    return clean_speech_text(f"{header} {texto}")


def synthesize_to_mp3(voice, text: str, mp3_out: Path) -> None:
    from piper.config import SynthesisConfig

    syn_cfg = SynthesisConfig(length_scale=1.06, noise_scale=0.667, noise_w_scale=0.8)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = Path(tmp) / "speech.wav"
        with wave.open(str(wav_path), "wb") as wf:
            voice.synthesize_wav(text, wf, syn_config=syn_cfg)

        mp3_out.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-i",
                str(wav_path),
                "-ac",
                "1",
                "-b:a",
                "48k",
                str(mp3_out),
            ],
            check=True,
        )


def upsert_credit(audio: dict, field: str) -> None:
    credits_list = audio.get("creditos")
    if not isinstance(credits_list, list):
        credits_list = []
    credits_list = [c for c in credits_list if isinstance(c, dict) and c.get("campo") != field]
    credits_list.append(
        {
            "campo": field,
            "canal": f"Via Sacra — Voz Neural Piper ({VOICE_ID}, pt-BR)",
            "licenca": "CC0 / Domínio Público (Piper TTS)",
        }
    )
    audio["creditos"] = credits_list


def prune_old_audio(audio_dir: Path, today: dt.date) -> None:
    if not audio_dir.exists():
        return
    cutoff = today - dt.timedelta(days=KEEP_DAYS)
    for mp3 in audio_dir.glob("*.mp3"):
        m = re.match(r"^(\d{4}-\d{2}-\d{2})", mp3.stem)
        if not m:
            continue
        try:
            d = dt.date.fromisoformat(m.group(1))
        except ValueError:
            continue
        if d < cutoff:
            mp3.unlink()
            print(f"Removido áudio antigo: {mp3.name}", flush=True)


def main() -> int:
    ap = argparse.ArgumentParser(description="Gera áudios MP3 neurais pt-BR (Piper TTS) da Liturgia e Homilia.")
    ap.add_argument("--dir", type=Path, required=True, help="Diretório raiz do branch data (contém liturgia/)")
    ap.add_argument("--model-dir", type=Path, default=Path("/tmp/piper-models"), help="Pasta de cache dos modelos")
    ap.add_argument("--force", action="store_true", help="Regera MP3 mesmo se já existir")
    args = ap.parse_args()

    lit_dir = args.dir / "liturgia"
    audio_dir = args.dir / "audio"
    if not lit_dir.exists():
        print(f"Diretório não encontrado: {lit_dir}", file=sys.stderr)
        return 1

    today = dt.datetime.now(dt.timezone(dt.timedelta(hours=-3))).date()
    prune_old_audio(audio_dir, today)

    # Gera apenas para a janela ativa (hoje até +7 dias)
    targets: list[Path] = []
    for offset in range(0, 8):
        iso = (today + dt.timedelta(days=offset)).isoformat()
        p = lit_dir / f"{iso}.json"
        if p.exists():
            targets.append(p)

    if not targets:
        print("Nenhum JSON de liturgia encontrado para a janela ativa.")
        return 0

    from piper import PiperVoice

    model_path = download_models(args.model_dir)
    voice = PiperVoice.load(str(model_path))

    for json_path in targets:
        iso = json_path.stem
        doc = json.loads(json_path.read_text(encoding="utf-8"))
        audio = doc.setdefault("audio", {})
        changed = False

        # 1. Liturgia completa
        lit_mp3 = audio_dir / f"{iso}.mp3"
        lit_url = f"{CDN_BASE}/{iso}.mp3"
        lit_script = build_liturgy_script(doc)
        if len(lit_script) >= 80:
            if args.force or not lit_mp3.exists():
                print(f"Sintetizando Liturgia {iso} ({len(lit_script)} chars)...", flush=True)
                synthesize_to_mp3(voice, lit_script, lit_mp3)
                print(f"  -> {lit_mp3.name}: {lit_mp3.stat().st_size / 1024:.0f} KB", flush=True)
            if audio.get("liturgia_audio_url") != lit_url or args.force:
                audio["liturgia_audio_url"] = lit_url
                upsert_credit(audio, "liturgia_audio_url")
                changed = True

        # 2. Homilia do dia (Vatican News)
        hom_mp3 = audio_dir / f"{iso}-homilia.mp3"
        hom_url = f"{CDN_BASE}/{iso}-homilia.mp3"
        hom_script = build_homily_script(doc)
        if len(hom_script) >= 80:
            if args.force or not hom_mp3.exists():
                print(f"Sintetizando Homilia {iso} ({len(hom_script)} chars)...", flush=True)
                synthesize_to_mp3(voice, hom_script, hom_mp3)
                print(f"  -> {hom_mp3.name}: {hom_mp3.stat().st_size / 1024:.0f} KB", flush=True)
            if audio.get("homilia_audio_url") != hom_url or args.force:
                audio["homilia_audio_url"] = hom_url
                upsert_credit(audio, "homilia_audio_url")
                changed = True

        if changed:
            json_path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
