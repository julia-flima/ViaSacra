from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import generate_audio as ga


def _sample_doc(*, celebration: str = "Quinta-feira da 33ª Semana do Tempo Comum") -> dict:
    return {
        "schema_version": 1,
        "data": "2026-11-19",
        "calendario": {
            "celebracao": celebration,
        },
        "leituras": {
            "primeira_leitura": {
                "introducao": "Leitura do Livro do Apocalipse.",
                "texto": "Eu, João, vi um Cordeiro de pé junto ao trono. " * 4,
            },
            "salmo": {
                "refrao": "O Senhor é bom para sempre!",
                "estrofes": [
                    "Cantai ao Senhor um canto novo.",
                    "Aclamai o Senhor, terra inteira!",
                ],
                "texto": "Cantai ao Senhor um canto novo.",
            },
            "evangelho": {
                "aclamacao": "Aleluia, aleluia, aleluia.",
                "introducao": "Proclamação do Evangelho segundo Lucas.",
                "texto": "Naquele tempo, Jesus entrou em Jerusalém e chorou sobre ela. " * 3,
            },
        },
        "homilias": {
            "vaticano": {
                "titulo": "Palavras do Santo Padre",
                "autor": "Papa Francisco",
                "texto": "Jesus chora porque ama a cidade com ternura de Pai. " * 3,
            }
        },
        "audio": {"creditos": [], "fallback": "tts_local_pt_BR"},
    }


def test_build_liturgy_script_ordem_e_celebracao():
    doc = _sample_doc()
    script = ga.build_liturgy_script(doc)

    assert script.startswith("Liturgia Diária. Quinta-feira da 33ª Semana do Tempo Comum.")
    assert "Refrão: O Senhor é bom para sempre!" in script
    assert "O Senhor é bom para sempre!." not in script
    assert "Palavra do Senhor." in script
    assert "Palavra da Salvação." in script

    idx_aclam = script.index("Aleluia, aleluia, aleluia.")
    idx_intro = script.index("Proclamação do Evangelho segundo Lucas.")
    idx_end = script.index("Palavra da Salvação.")
    assert idx_aclam < idx_intro < idx_end


def test_build_homily_script():
    assert ga.build_homily_script({}) == ""
    script = ga.build_homily_script(_sample_doc())
    assert script.startswith("Palavras do Santo Padre. Papa Francisco. Jesus chora")


def test_normalize_ipa_e_split():
    assert ga.normalize_text_for_speech("✝ «Paz» — § 2 • ‘Ide’!") == '"Paz" , parágrafo 2 \'Ide\'!'
    assert ga.map_ipa_to_kokoro("ga-tʃo dʒa aɪ") == "ɡaʧo ʤa I"
    chunks = ga.split_text_for_kokoro(" ".join(f"Frase número {i}." for i in range(40)), max_len=120)
    assert len(chunks) > 2
    assert all(len(c) <= 120 for c in chunks)


def test_process_day_hash_regera_e_creditos(tmp_path: Path):
    lit_dir = tmp_path / "liturgia"
    audio_dir = tmp_path / "audio"
    lit_dir.mkdir()
    json_path = lit_dir / "2026-11-19.json"

    doc = _sample_doc()
    # Simula JSON legado ainda com crédito do Piper e sem *_audio_hash
    doc["audio"] = {
        "liturgia_audio_url": "https://cdn.jsdelivr.net/gh/julia-flima/ViaSacra@data/audio/2026-11-19.mp3",
        "creditos": [{"campo": "liturgia_audio_url", "canal": "Piper", "licenca": "CC0"}],
    }
    json_path.write_text(json.dumps(doc), encoding="utf-8")

    synth_calls: list[str] = []

    def fake_synth(parts: list[str], out: Path, voice: str = ga.VOICE_ID) -> list[float]:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(b"ID3fake")
        synth_calls.append(out.name)
        return [10.0 * i for i in range(len(parts))]

    # 1. Ausência de hash dispara migração Kokoro
    changed1 = ga.process_day(json_path, audio_dir, fake_synth)
    assert changed1 is True
    assert set(synth_calls) == {
        "2026-11-19.mp3",
        "2026-11-19-homilia.mp3",
        "2026-11-19-pm_alex.mp3",
        "2026-11-19-homilia-pm_alex.mp3",
    }

    saved = json.loads(json_path.read_text(encoding="utf-8"))
    assert saved["audio"]["liturgia_audio_hash"] == ga.script_hash(ga.build_liturgy_script(saved))
    assert saved["audio"]["homilia_audio_hash"] == ga.script_hash(ga.build_homily_script(saved))
    # Marca do início de cada leitura no MP3 (o app usa para avançar/voltar entre leituras).
    keys = [k for k, _ in ga.build_liturgy_parts(saved)]
    assert saved["audio"]["liturgia_audio_marcas"] == {k: 10.0 * i for i, k in enumerate(keys)}
    assert keys[0] == "primeira_leitura" and "Liturgia Diária" in ga.build_liturgy_parts(saved)[0][1]
    # Um MP3 por voz, cada um com as próprias marcas (o app toca o da voz escolhida).
    vozes = saved["audio"]["liturgia_vozes"]
    assert set(vozes) == {"pf_dora", "pm_alex"}
    assert vozes["pf_dora"]["url"] == saved["audio"]["liturgia_audio_url"]
    assert vozes["pm_alex"]["url"].endswith("2026-11-19-pm_alex.mp3")
    assert vozes["pm_alex"]["hash"] == ga.script_hash(ga.build_liturgy_script(saved), "pm_alex")
    assert set(saved["audio"]["homilia_vozes"]) == {"pf_dora", "pm_alex"}
    credit = next(c for c in saved["audio"]["creditos"] if c["campo"] == "liturgia_audio_url")
    assert "Kokoro-82M" in credit["canal"]
    assert "Apache-2.0" in credit["licenca"]

    # 2. Segunda execução com mesmo texto não resintetiza
    synth_calls.clear()
    changed2 = ga.process_day(json_path, audio_dir, fake_synth)
    assert changed2 is False
    assert synth_calls == []

    # 3. Alteração no texto invalida apenas o slot modificado
    doc2 = json.loads(json_path.read_text(encoding="utf-8"))
    doc2["calendario"]["celebracao"] = "Memória de São Roque González"
    json_path.write_text(json.dumps(doc2), encoding="utf-8")
    changed3 = ga.process_day(json_path, audio_dir, fake_synth)
    assert changed3 is True
    assert synth_calls == ["2026-11-19.mp3", "2026-11-19-pm_alex.mp3"]


def test_prune_old_audio_limpa_mp3s_e_urls_expiradas(tmp_path: Path):
    lit_dir = tmp_path / "liturgia"
    audio_dir = tmp_path / "audio"
    lit_dir.mkdir()
    audio_dir.mkdir()

    today = dt.date(2026, 11, 20)
    old_iso = "2026-10-01"
    orphan_iso = "2026-10-02"
    fresh_iso = "2026-11-18"

    (audio_dir / f"{old_iso}.mp3").write_bytes(b"old")
    (audio_dir / f"{old_iso}-homilia.mp3").write_bytes(b"old-h")
    (audio_dir / f"{fresh_iso}.mp3").write_bytes(b"fresh")

    for iso in (old_iso, orphan_iso, fresh_iso):
        (lit_dir / f"{iso}.json").write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "data": iso,
                    "audio": {
                        "salmo_audio_url": "https://salmo.example/ok.mp3",
                        "liturgia_audio_url": f"https://cdn/audio/{iso}.mp3",
                        "liturgia_audio_hash": "deadbeef",
                        "homilia_audio_url": f"https://cdn/audio/{iso}-homilia.mp3",
                        "homilia_audio_hash": "cafebabe",
                        "creditos": [
                            {"campo": "salmo_audio_url", "canal": "Salmo"},
                            {"campo": "liturgia_audio_url", "canal": "Kokoro-82M"},
                            {"campo": "homilia_audio_url", "canal": "Kokoro-82M"},
                        ],
                    },
                }
            ),
            encoding="utf-8",
        )

    cleaned = ga.prune_old_audio(audio_dir, lit_dir, today)
    assert cleaned == 2
    assert not (audio_dir / f"{old_iso}.mp3").exists()
    assert not (audio_dir / f"{old_iso}-homilia.mp3").exists()
    assert (audio_dir / f"{fresh_iso}.mp3").exists()

    for iso in (old_iso, orphan_iso):
        d = json.loads((lit_dir / f"{iso}.json").read_text(encoding="utf-8"))
        assert "liturgia_audio_url" not in d["audio"]
        assert "liturgia_audio_hash" not in d["audio"]
        assert "homilia_audio_url" not in d["audio"]
        assert "homilia_audio_hash" not in d["audio"]
        assert d["audio"]["salmo_audio_url"] == "https://salmo.example/ok.mp3"
        assert [c["campo"] for c in d["audio"]["creditos"]] == ["salmo_audio_url"]

    fresh = json.loads((lit_dir / f"{fresh_iso}.json").read_text(encoding="utf-8"))
    assert fresh["audio"]["liturgia_audio_url"] == f"https://cdn/audio/{fresh_iso}.mp3"
    assert len(fresh["audio"]["creditos"]) == 3


def test_speakable_text_igual_ao_app():
    # Mesmos casos de app/test/speech_text_test.dart (issue #55).
    casos = {
        "Salmos 4,7-9": "Salmo 4, versículos 7 a 9",
        "Lc 19,41-44": "Lucas 19, versículos 41 a 44",
        "Jo 3,16": "João 3, versículo 16",
        "Sl 22(23),1-2a.2b-3.5-6": "Salmo 22, versículos 1 a 2, 2 a 3 e 5 a 6",
        "Sl 149,1-2.3-4.5-6a e 9b": "Salmo 149, versículos 1 a 2, 3 a 4, 5 a 6 e 9",
        "1Cor 15,20-26.28": "Primeira Coríntios 15, versículos 20 a 26 e 28",
        "1 Rs 19,4": "Primeiro Reis 19, versículo 4",
        "1Mc 2,15": "Primeiro Macabeus 2, versículo 15",
        "Mc 1,15": "Marcos 1, versículo 15",
        "Is 52,13-53,12": "Isaías 52, versículo 13 ao capítulo 53, versículo 12",
        "Ap 20,1-4.11-21,2": "Apocalipse 20, versículos 1 a 4 e 11 ao capítulo 21, versículo 2",
        "Leitura da Profecia de Ezequiel 34,11-12.15-17": (
            "Leitura da Profecia de Ezequiel 34, versículos 11 a 12 e 15 a 17"
        ),
        "(cf. Jo 14,6)": "(conforme João 14, versículo 6)",
        "No ano 2026, 1 de janeiro": "No ano 2026, 1 de janeiro",
        "na 3,5 do texto": "na 3,5 do texto",
        "Mt 5": "Mt 5",
        "Pelos prados verdejantes *\nele me leva a descansar. R.": "Pelos prados verdejantes\nele me leva a descansar.",
        "V. Nós vos adoramos.\nR. Porque pela vossa santa cruz": "Nós vos adoramos.\nPorque pela vossa santa cruz",
        "S. José e N. Sra. com Sto. Antônio e Sta. Teresa": "São José e Nossa Senhora com Santo Antônio e Santa Teresa",
    }
    for entrada, falado in casos.items():
        assert ga.speakable_text(entrada) == falado, entrada


def test_roteiro_da_liturgia_sem_asteriscos():
    doc = _sample_doc()
    doc["leituras"]["salmo"] = {"refrao": "O Senhor é o meu pastor.", "estrofes": ["Pelos prados *\nele me leva."]}
    roteiro = ga.build_liturgy_script(doc)
    assert "*" not in roteiro
    assert "Pelos prados ele me leva." in roteiro
