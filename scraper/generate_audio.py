#!/usr/bin/env python3
"""Gera áudios neurais MP3 (pt-BR) da Liturgia Diária e da Homilia usando Kokoro-82M.

Usa o modelo neural open-source Kokoro-82M v1.0 com a voz `pf_dora` (Dora,
Apache-2.0, 24 kHz, português brasileiro natural), alinhado ao motor neural do
app Web e Mobile, comprimindo em MP3 mono 64 kbps via ffmpeg.

Os arquivos são gravados em `<dir>/audio/AAAA-MM-DD.mp3` (Liturgia completa) e
`<dir>/audio/AAAA-MM-DD-homilia.mp3` (Homilia do dia), publicados no branch
`data` e referenciados em `audio.liturgia_audio_url` e `audio.homilia_audio_url`
no JSON do dia, junto com hashes (`*_audio_hash`) para detectar edições.

Uso:
    python generate_audio.py --dir ../data-branch --model-dir /tmp/kokoro-models
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import unicodedata
import urllib.request
import wave
from collections.abc import Callable
from pathlib import Path
from typing import Any

VOICE_ID = "pf_dora"
VOICE_LABEL = "Dora"
VOICE_SPEED = 1.0
LANG_CODE = "pt-br"
SAMPLE_RATE = 24000
MODEL_BASE_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
MODEL_FILES = ("kokoro-v1.0.onnx", "voices-v1.0.bin")
CDN_BASE = "https://cdn.jsdelivr.net/gh/julia-flima/ViaSacra@data/audio"
KEEP_DAYS = 14


def download_models(model_dir: Path) -> tuple[Path, Path]:
    model_dir.mkdir(parents=True, exist_ok=True)
    for fname in MODEL_FILES:
        dst = model_dir / fname
        if dst.exists() and dst.stat().st_size > 1_000_000:
            continue
        part = model_dir / f".{fname}.part"
        url = f"{MODEL_BASE_URL}/{fname}"
        print(f"Baixando {fname}...", flush=True)
        req = urllib.request.Request(url, headers={"User-Agent": "ViaSacra-Audio/2.0"})
        try:
            with urllib.request.urlopen(req, timeout=300) as resp, part.open("wb") as out:
                shutil.copyfileobj(resp, out, length=1024 * 1024)
            part.replace(dst)
        finally:
            if part.exists():
                part.unlink(missing_ok=True)
    return model_dir / MODEL_FILES[0], model_dir / MODEL_FILES[1]


def normalize_text_for_speech(text: str) -> str:
    t = re.sub(r"[«»“”]", '"', text)
    t = re.sub(r"[‘’]", "'", t)
    t = re.sub(r"[—–]", ", ", t)
    t = re.sub(r"§\s*", "parágrafo ", t)
    t = re.sub(r"[✝✦•▪▸►]", " ", t)
    return re.sub(r"\s+", " ", t).strip()


def _ensure_punct(text: str) -> str:
    t = text.strip()
    if not t:
        return ""
    return t if t[-1] in ".!?:;" else f"{t}."


def build_liturgy_script(doc: dict[str, Any]) -> str:
    parts: list[str] = []
    cal = doc.get("calendario") if isinstance(doc.get("calendario"), dict) else {}
    celebracao = (cal.get("celebracao") or doc.get("celebracao") or "").strip()
    if celebracao:
        parts.append(f"Liturgia Diária. {_ensure_punct(celebracao)}")

    leituras = doc.get("leituras") or {}
    order = (
        ("primeira_leitura", "Primeira Leitura"),
        ("salmo", "Salmo Responsorial"),
        ("segunda_leitura", "Segunda Leitura"),
        ("evangelho", "Evangelho"),
    )
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

        seg: list[str] = []
        if key == "salmo":
            seg.append("Salmo Responsorial.")
            if refrao:
                seg.append(f"Refrão: {_ensure_punct(refrao)}")
            wrote_stanza = False
            for est in estrofes:
                est_clean = str(est).strip()
                if est_clean:
                    wrote_stanza = True
                    seg.append(_ensure_punct(est_clean))
                    if refrao:
                        seg.append(_ensure_punct(refrao))
            if not wrote_stanza and texto:
                seg.append(_ensure_punct(texto))
        elif key == "evangelho":
            if aclamacao:
                seg.append(_ensure_punct(aclamacao))
            seg.append(_ensure_punct(intro or "Proclamação do Evangelho."))
            if texto:
                seg.append(_ensure_punct(texto))
            if not texto.rstrip(".! ").lower().endswith("palavra da salvação"):
                seg.append("Palavra da Salvação.")
        else:
            seg.append(_ensure_punct(intro or f"{label}."))
            if texto:
                seg.append(_ensure_punct(texto))
            if not texto.rstrip(".! ").lower().endswith("palavra do senhor"):
                seg.append("Palavra do Senhor.")

        parts.append(" ".join(seg))

    return normalize_text_for_speech("\n\n".join(parts))


def build_homily_script(doc: dict[str, Any]) -> str:
    homilias = doc.get("homilias") or {}
    vat = homilias.get("vaticano") or homilias.get("vatican_news")
    if not isinstance(vat, dict):
        return ""
    texto = (vat.get("texto") or "").strip()
    if not texto:
        return ""
    titulo = (vat.get("titulo") or "Homilia do Dia").strip()
    autor = (vat.get("autor") or "").strip()
    segs = [_ensure_punct(titulo)]
    if autor:
        segs.append(_ensure_punct(autor))
    segs.append(_ensure_punct(texto))
    return normalize_text_for_speech(" ".join(segs))


def map_ipa_to_kokoro(ipa: str) -> str:
    s = unicodedata.normalize("NFD", ipa)
    for src, dst in (
        ("dʒ", "ʤ"),
        ("tʃ", "ʧ"),
        ("dz", "ʣ"),
        ("ts", "ʦ"),
        ("aɪ", "I"),
        ("aʊ", "W"),
        ("eɪ", "A"),
        ("oʊ", "O"),
        ("əʊ", "Q"),
        ("ɔɪ", "Y"),
        ("g", "ɡ"),
    ):
        s = s.replace(src, dst)
    s = re.sub(r"(\S)\u0329", r"ᵊ\1", s)
    return s.replace("\u0329", "").replace("-", "").strip()


def split_text_for_kokoro(text: str, max_len: int = 350) -> list[str]:
    clean = normalize_text_for_speech(text)
    if not clean:
        return []
    sentences = [m.group(0).strip() for m in re.finditer(r"[^.!?;:\n]+[.!?;:\n]*", clean) if m.group(0).strip()]
    chunks: list[str] = []
    buf: list[str] = []
    buf_len = 0

    for sent in sentences:
        if len(sent) > max_len:
            if buf:
                chunks.append(" ".join(buf))
                buf.clear()
                buf_len = 0
            words = sent.split(" ")
            part: list[str] = []
            part_len = 0
            for word in words:
                add = len(word) + (1 if part else 0)
                if part and part_len + add > max_len:
                    chunks.append(" ".join(part))
                    part = []
                    part_len = 0
                if len(word) > max_len:
                    for i in range(0, len(word), max_len):
                        chunks.append(word[i : i + max_len])
                else:
                    part.append(word)
                    part_len += add
            if part:
                chunks.append(" ".join(part))
            continue

        add = len(sent) + (1 if buf else 0)
        if buf and buf_len + add > max_len:
            chunks.append(" ".join(buf))
            buf.clear()
            buf_len = 0
        buf.append(sent)
        buf_len += add

    if buf:
        chunks.append(" ".join(buf))
    return chunks


def script_hash(script: str, voice_id: str = VOICE_ID) -> str:
    return hashlib.sha256(f"{voice_id}:{script}".encode()).hexdigest()[:16]


def synthesize_to_mp3(kokoro: Any, text: str, mp3_out: Path) -> None:
    import numpy as np
    import phonemizer

    chunks = split_text_for_kokoro(text)
    if not chunks:
        raise ValueError("Nenhum texto para sintetizar")

    segments: list[Any] = []
    sample_rate = SAMPLE_RATE
    pause = np.zeros(int(SAMPLE_RATE * 0.18), dtype=np.float32)

    for idx, chunk in enumerate(chunks):
        raw_ipa = phonemizer.phonemize(
            chunk,
            language=LANG_CODE,
            preserve_punctuation=True,
            with_stress=True,
        )
        mapped = map_ipa_to_kokoro(raw_ipa)
        vocab = getattr(kokoro.tokenizer, "vocab", {})
        known = "".join(ch for ch in mapped if ch in vocab).strip()
        if known:
            samples, sr = kokoro.create(
                known,
                voice=VOICE_ID,
                speed=VOICE_SPEED,
                lang=LANG_CODE,
                is_phonemes=True,
            )
        else:
            samples, sr = kokoro.create(chunk, voice=VOICE_ID, speed=VOICE_SPEED, lang=LANG_CODE)
        sample_rate = int(sr)
        segments.append(np.asarray(samples, dtype=np.float32))
        if idx < len(chunks) - 1:
            if len(pause) != int(sample_rate * 0.18):
                pause = np.zeros(int(sample_rate * 0.18), dtype=np.float32)
            segments.append(pause)

    full = np.concatenate(segments) if len(segments) > 1 else segments[0]
    pcm16 = (np.clip(full, -1.0, 1.0) * 32767.0).astype("<i2")

    mp3_out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        tmp_dir = Path(tmp)
        wav_path = tmp_dir / "speech.wav"
        mp3_tmp = tmp_dir / "speech.mp3"
        with wave.open(str(wav_path), "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(pcm16.tobytes())

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
                "64k",
                str(mp3_tmp),
            ],
            check=True,
        )
        shutil.move(str(mp3_tmp), str(mp3_out))


def upsert_credit(audio: dict[str, Any], field: str) -> None:
    credits_list = audio.get("creditos")
    if not isinstance(credits_list, list):
        credits_list = []
    credits_list = [c for c in credits_list if isinstance(c, dict) and c.get("campo") != field]
    credits_list.append(
        {
            "campo": field,
            "interprete": f"Voz {VOICE_LABEL} ({VOICE_ID})",
            "canal": f"Via Sacra — Voz Neural Kokoro-82M ({VOICE_LABEL}, pt-BR)",
            "licenca": "Apache-2.0 (Kokoro-82M)",
        }
    )
    audio["creditos"] = credits_list


def _clear_audio_slot(audio: dict[str, Any], url_key: str, hash_key: str) -> bool:
    changed = False
    for key in (url_key, hash_key):
        if key in audio and audio.pop(key, None) is not None:
            changed = True
    credits_list = audio.get("creditos")
    if isinstance(credits_list, list):
        filtered = [c for c in credits_list if not (isinstance(c, dict) and c.get("campo") == url_key)]
        if len(filtered) != len(credits_list):
            audio["creditos"] = filtered
            changed = True
    return changed


def prune_old_audio(audio_dir: Path, lit_dir: Path, today: dt.date) -> int:
    cutoff = today - dt.timedelta(days=KEEP_DAYS)
    expired_dates: set[str] = set()

    if audio_dir.exists():
        for mp3 in sorted(audio_dir.glob("*.mp3")):
            m = re.match(r"^(\d{4}-\d{2}-\d{2})(?:-homilia)?$", mp3.stem)
            if not m:
                continue
            try:
                d = dt.date.fromisoformat(m.group(1))
            except ValueError:
                continue
            if d < cutoff:
                mp3.unlink()
                expired_dates.add(m.group(1))
                print(f"Removido áudio antigo: {mp3.name}", flush=True)

    updated = 0
    if lit_dir.exists():
        for json_path in sorted(lit_dir.glob("*.json")):
            if not re.match(r"^\d{4}-\d{2}-\d{2}$", json_path.stem):
                continue
            iso = json_path.stem
            try:
                d = dt.date.fromisoformat(iso)
            except ValueError:
                continue
            if d >= cutoff and iso not in expired_dates:
                continue

            doc = json.loads(json_path.read_text(encoding="utf-8"))
            audio = doc.get("audio")
            if not isinstance(audio, dict):
                continue

            changed = False
            if not (audio_dir / f"{iso}.mp3").exists():
                changed = _clear_audio_slot(audio, "liturgia_audio_url", "liturgia_audio_hash") or changed
            if not (audio_dir / f"{iso}-homilia.mp3").exists():
                changed = _clear_audio_slot(audio, "homilia_audio_url", "homilia_audio_hash") or changed

            if changed:
                json_path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
                updated += 1

    return updated


def process_day(
    json_path: Path,
    audio_dir: Path,
    synthesize_fn: Callable[[str, Path], None],
    *,
    force: bool = False,
) -> bool:
    iso = json_path.stem
    doc = json.loads(json_path.read_text(encoding="utf-8"))
    audio = doc.setdefault("audio", {})
    changed = False

    slots = (
        (
            build_liturgy_script(doc),
            audio_dir / f"{iso}.mp3",
            f"{CDN_BASE}/{iso}.mp3",
            "liturgia_audio_url",
            "liturgia_audio_hash",
            "Liturgia",
        ),
        (
            build_homily_script(doc),
            audio_dir / f"{iso}-homilia.mp3",
            f"{CDN_BASE}/{iso}-homilia.mp3",
            "homilia_audio_url",
            "homilia_audio_hash",
            "Homilia",
        ),
    )

    for script, mp3_path, url, url_key, hash_key, kind_label in slots:
        if len(script) < 80:
            if mp3_path.exists():
                mp3_path.unlink()
            changed = _clear_audio_slot(audio, url_key, hash_key) or changed
            continue

        expected_hash = script_hash(script)
        needs_synth = force or not mp3_path.exists() or audio.get(hash_key) != expected_hash
        if needs_synth:
            print(f"Sintetizando {kind_label} {iso} ({len(script)} chars)...", flush=True)
            synthesize_fn(script, mp3_path)
            print(f"  -> {mp3_path.name}: {mp3_path.stat().st_size / 1024:.0f} KB", flush=True)

        has_kokoro_credit = any(
            isinstance(c, dict) and c.get("campo") == url_key and "Kokoro" in str(c.get("canal", ""))
            for c in (audio.get("creditos") or [])
        )
        if audio.get(url_key) != url or audio.get(hash_key) != expected_hash or not has_kokoro_credit or force:
            audio[url_key] = url
            audio[hash_key] = expected_hash
            upsert_credit(audio, url_key)
            changed = True

    if changed:
        json_path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return changed


def main() -> int:
    ap = argparse.ArgumentParser(description="Gera áudios MP3 neurais pt-BR (Kokoro-82M) da Liturgia e Homilia.")
    ap.add_argument("--dir", type=Path, required=True, help="Diretório raiz do branch data (contém liturgia/)")
    ap.add_argument("--model-dir", type=Path, default=Path("/tmp/kokoro-models"), help="Pasta de cache dos modelos")
    ap.add_argument("--force", action="store_true", help="Regera MP3 mesmo se já existir")
    args = ap.parse_args()

    lit_dir = args.dir / "liturgia"
    audio_dir = args.dir / "audio"
    if not lit_dir.exists():
        print(f"Diretório não encontrado: {lit_dir}", file=sys.stderr)
        return 1

    today = dt.datetime.now(dt.timezone(dt.timedelta(hours=-3))).date()
    prune_old_audio(audio_dir, lit_dir, today)

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

    from kokoro_onnx import Kokoro

    model_path, voices_path = download_models(args.model_dir)
    kokoro = Kokoro(str(model_path), str(voices_path))

    for json_path in targets:
        process_day(
            json_path,
            audio_dir,
            lambda script, out: synthesize_to_mp3(kokoro, script, out),
            force=args.force,
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
