from __future__ import annotations

import json
from datetime import date
from pathlib import Path

import liturgical_calendar as cal
import scraper

FIX = Path(__file__).parent / "fixtures"


def test_parse_cnbb_estrutura():
    html = (FIX / "cnbb_sample.html").read_text(encoding="utf-8")
    r = scraper.parse_cnbb(html, "https://liturgiadiaria.cnbb.org.br/?data=2026-11-19")
    assert r["cor"] == "verde"
    assert r["celebracao"].startswith("Quinta-feira da 33ª Semana")
    assert r["primeira_leitura"]["referencia"] == "Ap 5,1-10"
    assert r["primeira_leitura"]["introducao"].startswith("Leitura do Livro do Apocalipse")
    assert "Cordeiro" in r["primeira_leitura"]["texto"]
    assert "Palavra do Senhor" not in r["primeira_leitura"]["texto"]
    assert r["segunda_leitura"] is None
    assert r["salmo"]["referencia"] == "Sl 149"
    assert r["salmo"]["refrao"] == "Fizestes de nós, para Deus, sacerdotes e povo de reis."
    assert len(r["salmo"]["estrofes"]) == 2
    assert all("Fizestes" not in e for e in r["salmo"]["estrofes"])
    ev = r["evangelho"]
    assert ev["referencia"] == "Lc 19,41-44"
    assert ev["aclamacao"] and "Aleluia" in ev["aclamacao"]
    assert ev["texto"].startswith("Naquele tempo")
    assert "Palavra da Salvação" not in ev["texto"]
    assert "tracking" not in json.dumps(r)
    assert r["reflexao"]["texto"].startswith("Jesus chora")


def test_parse_salmo_sem_marcador():
    s = scraper.parse_salmo("O Senhor é o meu pastor.\n\nEle me faz repousar.\n\nGuia-me pelo caminho.")
    assert s["refrao"] == "O Senhor é o meu pastor."
    assert s["estrofes"] == ["Ele me faz repousar.", "Guia-me pelo caminho."]


def test_vatican_evangelho_do_dia():
    html = (FIX / "vatican_gospel_sample.html").read_text(encoding="utf-8")
    h = scraper.parse_vatican_evangelho_do_dia(html, "https://www.vaticannews.va/pt/evangelho-do-dia/2026/11/19.html")
    assert h is not None
    assert h["autor"] == "Papa Francisco"
    assert "visitada" in h["texto"]
    assert "Libreria Editrice Vaticana" in h["licenca"]


def test_vatican_rss():
    xml = (FIX / "vatican_rss_sample.xml").read_text(encoding="utf-8")
    h = scraper.parse_vatican_rss(xml, date(2026, 11, 19))
    assert h is not None and "homilia" in h["titulo"].lower()
    assert h["url"].endswith("homilia.html")


def test_patristica_cruzada_com_evangelho():
    acervo = json.loads((scraper.BASE_DIR / "patristic.json").read_text(encoding="utf-8"))
    sel = scraper.selecionar_patristica("Jo 6,51-58", "pascoa", acervo)
    assert sel and sel[0]["autor"] == "Santo Agostinho"
    assert all(s["licenca"] == "Domínio público" for s in sel)
    assert scraper.selecionar_patristica(None, "advento", acervo)  # fallback por tempo


def test_montar_dia_offline(tmp_path: Path):
    cliente = scraper.ClienteHttp(
        respeitar_robots=False,
        offline_html={"cnbb": str(FIX / "cnbb_sample.html"), "vatican": str(FIX / "vatican_gospel_sample.html")},
    )
    doc = scraper.montar_dia(date(2026, 11, 19), cliente, {"cnbb", "vaticano"})
    assert doc["status"]["cnbb"] == "ok" and doc["status"]["vaticano"] == "ok"
    assert doc["calendario"]["cor"] == "verde"
    assert doc["calendario"]["misterios_do_dia"] == "luminosos"
    assert doc["leituras"]["evangelho"]["fonte"] == "CNBB"
    assert doc["audio"]["fallback"] == "tts_local_pt_BR"
    assert {f["id"] for f in doc["fontes"]} >= {"cnbb", "vaticannews"}

    destino = tmp_path / "liturgia" / "2026-11-19.json"
    assert scraper.salvar(doc, destino)
    pior = dict(doc, leituras=None, homilias={"vaticano": None, "cnbb": None, "patristica": []})
    assert not scraper.salvar(pior, destino)  # não sobrescreve versão melhor
    indice = scraper.atualizar_indice(destino.parent, manter_dias=100000)
    assert indice["ultima_data"] == "2026-11-19"


def test_fonte_falha_nao_derruba(tmp_path: Path):
    cliente = scraper.ClienteHttp(respeitar_robots=False, offline_html={"cnbb": str(FIX / "vatican_rss_sample.xml")})
    doc = scraper.montar_dia(date(2026, 11, 19), cliente, {"cnbb"})
    assert doc["status"]["cnbb"].startswith("indisponivel")
    assert doc["leituras"] is None
    assert doc["calendario"]["cor_origem"] == "calculada"


def test_calendario_liturgico():
    d = cal.calcular(date(2026, 11, 19))
    assert (d.tempo, d.semana, d.cor) == ("comum", 33, "verde")
    assert d.celebracao == "Quinta-feira da 33ª Semana do Tempo Comum"
    assert cal.pascoa(2027) == date(2027, 3, 28)
    assert cal.calcular(date(2026, 11, 22)).celebracao.startswith("Nosso Senhor Jesus Cristo")
    assert cal.calcular(date(2026, 11, 29)).tempo == "advento"
    assert cal.calcular(date(2026, 12, 13)).cor == "rosa"
    assert cal.calcular(date(2027, 1, 17)).celebracao == "2º Domingo do Tempo Comum"
    assert cal.calcular(date(2027, 2, 10)).celebracao == "Quarta-feira de Cinzas"
    assert cal.ciclos(date(2026, 11, 19)) == ("A", "II")
    assert cal.ciclos(date(2026, 12, 1)) == ("B", "I")
