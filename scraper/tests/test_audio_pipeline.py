"""Pipeline diário de áudio (issue #11): preservação dos MP3 gerados e feed do YouTube."""

from __future__ import annotations

import copy
import json
from pathlib import Path

import pytest

import generate_audio as ga
import scraper
from tests.test_generate_audio import _sample_doc

URL_LIT = f"{ga.CDN_BASE}/2026-11-19.mp3"
URL_HOM = f"{ga.CDN_BASE}/2026-11-19-homilia.mp3"


def _doc_com_audio_gerado() -> dict:
    """Simula o JSON do dia depois de ``generate_audio.process_day``."""
    doc = _sample_doc()
    doc["audio"] = {
        "salmo_video_id": "abc",
        "liturgia_audio_url": URL_LIT,
        "liturgia_audio_hash": ga.script_hash(ga.build_liturgy_script(doc)),
        "liturgia_audio_marcas": {"primeira_leitura": 0.0, "salmo": 61.2, "evangelho": 120.5},
        "homilia_audio_url": URL_HOM,
        "homilia_audio_hash": ga.script_hash(ga.build_homily_script(doc)),
        "creditos": [{"campo": "salmo_video_id", "canal": "Canal X"}],
        "fallback": "tts_local_pt_BR",
    }
    ga.upsert_credit(doc["audio"], "liturgia_audio_url")
    ga.upsert_credit(doc["audio"], "homilia_audio_url")
    lit, hom = ga.build_liturgy_script(doc), ga.build_homily_script(doc)
    marcas = doc["audio"]["liturgia_audio_marcas"]
    doc["audio"]["liturgia_vozes"] = {
        "pf_dora": {"url": URL_LIT, "hash": ga.script_hash(lit), "marcas": marcas},
        "pm_alex": {"url": "alex.mp3", "hash": ga.script_hash(lit, "pm_alex"), "marcas": marcas},
    }
    doc["audio"]["homilia_vozes"] = {
        "pf_dora": {"url": URL_HOM, "hash": ga.script_hash(hom)},
        "pm_alex": {"url": "alex-h.mp3", "hash": ga.script_hash(hom, "pm_alex")},
    }
    return doc


def _doc_recem_coletado(base: dict) -> dict:
    """O que ``montar_dia`` produz: mesmo texto, bloco de áudio recriado do zero."""
    doc = copy.deepcopy(base)
    doc["audio"] = {
        "salmo_video_id": "abc",
        "creditos": [{"campo": "salmo_video_id", "canal": "Canal X"}],
        "fallback": "tts_local_pt_BR",
    }
    return doc


def _campos(audio: dict) -> set[str]:
    return {c["campo"] for c in audio["creditos"]}


def test_preserva_audio_quando_o_texto_nao_mudou():
    anterior = _doc_com_audio_gerado()
    novo = _doc_recem_coletado(anterior)

    copiados = scraper.preservar_audio_gerado(novo, anterior)

    assert copiados == ["liturgia_audio_url", "homilia_audio_url", "liturgia_vozes", "homilia_vozes"]
    for chave in (
        "liturgia_audio_url",
        "liturgia_audio_hash",
        "liturgia_audio_marcas",
        "homilia_audio_url",
        "homilia_audio_hash",
    ):
        assert novo["audio"][chave] == anterior["audio"][chave]
    assert _campos(novo["audio"]) == {"salmo_video_id", "liturgia_audio_url", "homilia_audio_url"}


def test_descarta_audio_quando_o_texto_mudou():
    anterior = _doc_com_audio_gerado()
    novo = _doc_recem_coletado(anterior)
    novo["leituras"]["evangelho"]["texto"] += " Correção da CNBB."

    # Mudou a liturgia: só a homilia (nas duas vozes) continua valendo.
    assert scraper.preservar_audio_gerado(novo, anterior) == ["homilia_audio_url", "homilia_vozes"]
    assert "liturgia_audio_url" not in novo["audio"]  # será regerado; o app usa a voz local
    assert "liturgia_audio_url" not in _campos(novo["audio"])


def test_nao_sobrescreve_audio_novo():
    anterior = _doc_com_audio_gerado()
    novo = _doc_recem_coletado(anterior)
    novo["audio"]["liturgia_audio_url"] = "https://exemplo/novo.mp3"

    assert "liturgia_audio_url" not in scraper.preservar_audio_gerado(novo, anterior)
    assert novo["audio"]["liturgia_audio_url"] == "https://exemplo/novo.mp3"


@pytest.mark.parametrize("forcar", [False, True])
def test_salvar_mantem_audio_do_arquivo_existente(tmp_path: Path, forcar: bool):
    destino = tmp_path / "liturgia" / "2026-11-19.json"
    destino.parent.mkdir()
    anterior = _doc_com_audio_gerado()
    destino.write_text(json.dumps(anterior, ensure_ascii=False), encoding="utf-8")

    assert scraper.salvar(_doc_recem_coletado(anterior), destino, forcar=forcar)

    salvo = json.loads(destino.read_text(encoding="utf-8"))
    assert salvo["audio"]["liturgia_audio_url"] == URL_LIT
    assert salvo["audio"]["homilia_audio_url"] == URL_HOM
    # E o generate_audio.py seguinte não precisa sintetizar de novo nem mexer no JSON.
    (tmp_path / "audio").mkdir()
    nomes = ("2026-11-19.mp3", "2026-11-19-homilia.mp3", "2026-11-19-pm_alex.mp3", "2026-11-19-homilia-pm_alex.mp3")
    for nome in nomes:
        (tmp_path / "audio" / nome).write_bytes(b"mp3")
    sintetizados: list[str] = []
    mudou = ga.process_day(destino, tmp_path / "audio", lambda _t, p, _v=None: sintetizados.append(p.name))
    assert (mudou, sintetizados) == (False, [])


def test_salvar_tolera_arquivo_anterior_corrompido(tmp_path: Path):
    destino = tmp_path / "2026-11-19.json"
    destino.write_text("{ quebrado", encoding="utf-8")
    assert scraper.salvar(_sample_doc(), destino)
    assert json.loads(destino.read_text(encoding="utf-8"))["data"] == "2026-11-19"


def test_salvar_mantem_versao_mais_completa(tmp_path: Path):
    destino = tmp_path / "2026-11-19.json"
    completo = _doc_com_audio_gerado()
    destino.write_text(json.dumps(completo), encoding="utf-8")
    pior = _doc_recem_coletado(completo)
    pior["leituras"] = {}

    assert not scraper.salvar(pior, destino)
    assert json.loads(destino.read_text(encoding="utf-8")) == completo


# ---------------------------------------------------------------------------
# Feed do YouTube
# ---------------------------------------------------------------------------

FEED = """<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <yt:videoId>vid123</yt:videoId>
    <title>Salmo 149 - 19/11/2026 - Fizestes de nós sacerdotes</title>
    <author><name>Canal Salmos</name></author>
  </entry>
</feed>"""


@pytest.fixture(autouse=True)
def _limpar_cache_feed():
    scraper._YT_FEED_CACHE.clear()
    yield
    scraper._YT_FEED_CACHE.clear()


def test_feed_youtube_passa_pelo_cliente_http(monkeypatch: pytest.MonkeyPatch):
    cliente = scraper.ClienteHttp()
    chamadas: list[tuple[str, dict]] = []

    def get_falso(url: str, **kw):
        chamadas.append((url, kw))
        return FEED

    monkeypatch.setattr(cliente, "get", get_falso)
    monkeypatch.setattr(cliente._sessao, "get", lambda *a, **k: pytest.fail("acesso direto à sessão"))

    entradas = scraper._buscar_feed_youtube("UC1", cliente)
    assert entradas == [{"video_id": "vid123", "title": entradas[0]["title"], "author": "Canal Salmos"}]
    url, kw = chamadas[0]
    assert url.endswith("channel_id=UC1")
    assert kw["tentativas"] == 1
    assert kw["respeitar_robots"] is False  # exceção documentada

    scraper._buscar_feed_youtube("UC1", cliente)  # segunda vez: cache
    assert len(chamadas) == 1


def test_feed_youtube_indisponivel_nao_quebra(monkeypatch: pytest.MonkeyPatch):
    cliente = scraper.ClienteHttp()

    def falha(url: str, **kw):
        raise scraper.FonteIndisponivel("offline")

    monkeypatch.setattr(cliente, "get", falha)
    assert scraper._buscar_feed_youtube("UC2", cliente) == []
    assert scraper._buscar_feed_youtube("UC3", scraper.ClienteHttp(offline_html={"cnbb": "x"})) == []


def test_cliente_http_respeita_robots_por_padrao(monkeypatch: pytest.MonkeyPatch):
    cliente = scraper.ClienteHttp()
    monkeypatch.setattr(cliente, "_permitido", lambda url: False)
    monkeypatch.setattr(cliente, "_aguardar", lambda url: None)

    with pytest.raises(scraper.FonteIndisponivel, match="robots"):
        cliente.get("https://exemplo.org/x")

    class Resp:
        status_code = 200
        encoding = "utf-8"
        apparent_encoding = "utf-8"
        text = "ok"

        def raise_for_status(self):
            return None

    monkeypatch.setattr(cliente._sessao, "get", lambda *a, **k: Resp())
    assert cliente.get("https://exemplo.org/y", respeitar_robots=False) == "ok"
