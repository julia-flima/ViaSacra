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


def test_vatican_palavra_do_dia_layout_atual():
    html = (FIX / "vatican_palavra_dia_sample.html").read_text(encoding="utf-8")
    url = "https://www.vaticannews.va/pt/palavra-do-dia/2026/11/19.html"
    h = scraper.parse_vatican_evangelho_do_dia(html, url)
    assert h is not None and h["autor"] == "Papa Francisco"
    assert h["titulo"] == "As palavras dos Papas"
    leituras = scraper.parse_vatican_leituras(html, url)
    assert leituras["primeira_leitura"]["referencia"] == "Ap 5,1-10"
    assert "Palavra do Senhor" not in leituras["primeira_leitura"]["texto"]
    assert leituras["evangelho"]["referencia"] == "Lc 19,41-44"
    assert leituras["salmo"] is None


def test_livro_por_introducao():
    casos = {
        "Leitura do Livro do Apocalipse de São João": "Ap",
        "Proclamação do Evangelho de Jesus Cristo segundo João": "Jo",
        "Leitura da Primeira Carta de São João": "1Jo",
        "Leitura da Segunda Carta de São Paulo aos Coríntios": "2Cor",
        "Leitura do Livro do Eclesiástico": "Eclo",
        "Leitura do Livro de Jó": "Jó",
        "Leitura do Primeiro Livro dos Reis": "1Rs",
    }
    for intro, abrev in casos.items():
        assert scraper.livro_por_introducao(intro) == abrev, intro


def test_reserva_vatican_quando_cnbb_falha():
    cliente = scraper.ClienteHttp(
        respeitar_robots=False,
        offline_html={
            "cnbb": str(FIX / "vatican_rss_sample.xml"),  # força falha de parse da CNBB
            "vatican": str(FIX / "vatican_palavra_dia_sample.html"),
        },
    )
    doc = scraper.montar_dia(date(2026, 11, 19), cliente, {"cnbb", "vaticano"})
    assert doc["status"]["leituras_vaticano"] == "ok"
    assert doc["leituras"]["evangelho"]["fonte"] == "Vatican News"
    assert doc["homilias"]["vaticano"]["autor"] == "Papa Francisco"


def test_adaptador_tls_legado_so_na_cnbb():
    c = scraper.ClienteHttp()
    assert isinstance(c._sessao.get_adapter("https://liturgiadiaria.cnbb.org.br/x"), scraper.AdaptadorTLSLegado)
    assert not isinstance(c._sessao.get_adapter("https://www.vaticannews.va/"), scraper.AdaptadorTLSLegado)


def test_parse_cnbb_api():
    payload = (FIX / "cnbb_api_sample.json").read_text(encoding="utf-8")
    r = scraper.parse_cnbb_api(payload, "https://api-liturgia.edicoescnbb.com.br/contents/in/date/2026-11-19")
    assert r["cor"] == "vermelho"
    assert "Santos Roque González" in r["celebracao"]
    assert r["primeira_leitura"]["referencia"] == "Ap 5,1-10"
    assert r["primeira_leitura"]["introducao"].startswith("Leitura do Livro do Apocalipse")
    assert r["primeira_leitura"]["texto"].startswith("Eu, João")
    assert "Palavra do Senhor" not in r["primeira_leitura"]["texto"]
    assert r["salmo"]["referencia"] == "Sl 149,1-2.3-4.5-6a"
    assert r["salmo"]["refrao"] == "Fizestes de nós, para Deus, sacerdotes e povo de reis."
    assert len(r["salmo"]["estrofes"]) == 1
    assert not r["salmo"]["estrofes"][0].endswith("R.")
    assert r["segunda_leitura"] is None
    assert r["evangelho"]["referencia"] == "Lc 19,41-44"
    assert r["evangelho"]["aclamacao"] and "Aleluia" in r["evangelho"]["aclamacao"]
    assert r["evangelho"]["texto"].startswith("Naquele tempo")
    assert "Palavra da Salvação" not in r["evangelho"]["texto"]


def test_casar_salmo_youtube():
    entradas = [
        {"video_id": "aaa11111111", "title": "Cantos para Missa - 19/11/2026", "author": "Canal X"},
        {
            "video_id": "NHUXSd2fdhI",
            "title": "Salmo 149 - 19/11/2026: Fizestes de nós, para Deus, sacerdotes e povo de reis.",
            "author": "Salmos para rezar...",
        },
        {
            "video_id": "IyrY6iezvQQ",
            "title": "Salmo 118 (119) | Como é doce ao paladar vossa palavra, ó Senhor | Cifra",
            "author": "Salmodia Hoje",
        },
    ]
    # 1. Casa por data exata (ignorando vídeo que não é salmo)
    m1 = scraper._casar_salmo_youtube(
        date(2026, 11, 19),
        "Sl 149,1-2",
        "Fizestes de nós, para Deus, sacerdotes e povo de reis.",
        entradas,
    )
    assert m1 is not None and m1["video_id"] == "NHUXSd2fdhI"

    # 2. Casa por número do salmo + palavras do refrão (sem data no título)
    m2 = scraper._casar_salmo_youtube(
        date(2026, 11, 20),
        "Sl 118(119), 103",
        "Como é doce ao paladar vossa palavra, ó Senhor!",
        entradas,
    )
    assert m2 is not None and m2["video_id"] == "IyrY6iezvQQ"

    # 3. Não casa se nem data nem salmo+refrão baterem
    m3 = scraper._casar_salmo_youtube(
        date(2026, 11, 25),
        "Sl 22(23)",
        "O Senhor é o pastor que me conduz.",
        entradas,
    )
    assert m3 is None


