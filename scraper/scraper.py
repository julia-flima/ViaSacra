#!/usr/bin/env python3
"""Via Sacra — coletor diário de Liturgia, Homilias e áudios.

Gera arquivos JSON estáticos (um por dia) consumidos pelo app, servidos via
jsDelivr / GitHub Pages. Executado diariamente pelo workflow
``.github/workflows/update-liturgy.yml`` às 00:05 (horário de Brasília).

Princípios:
- **Atribuição explícita** de cada fonte (nome, URL original, licença/nota).
- **Uso não comercial / devocional**. Nenhum conteúdo é alterado, apenas
  estruturado.
- **Educação com os servidores**: respeita ``robots.txt``, User-Agent
  identificável, *rate limiting* e poucas requisições por execução.
- **Tolerância a falhas**: se uma fonte falha, o JSON é gerado mesmo assim
  com o calendário calculado localmente e o campo ``status`` explica o erro;
  um arquivo anterior válido nunca é sobrescrito por um pior.

Uso:
    python scraper.py                    # hoje (America/Sao_Paulo)
    python scraper.py --date 2026-11-19  # data específica
    python scraper.py --days 7           # hoje + 6 dias
    python scraper.py --offline-html cnbb=tests/fixtures/cnbb_sample.html
"""

from __future__ import annotations

import argparse
import json
import logging
import re
import ssl
import sys
import time
import unicodedata
import xml.etree.ElementTree as ET
from collections.abc import Callable, Iterable
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any
from urllib import robotparser
from urllib.parse import urljoin, urlparse
from zoneinfo import ZoneInfo

import requests
from bs4 import BeautifulSoup, NavigableString, Tag
from requests.adapters import HTTPAdapter

import generate_audio as gerador_audio
import liturgical_calendar as calendario

SCHEMA_VERSION = 1
TZ = ZoneInfo("America/Sao_Paulo")
BASE_DIR = Path(__file__).resolve().parent
USER_AGENT = (
    "ViaSacraBot/1.0 (+https://github.com/julia-flima/ViaSacra; "
    "app devocional open source, sem fins lucrativos)"
)
REQUEST_TIMEOUT = 25
MIN_INTERVALO_ENTRE_REQUISICOES = 2.0  # segundos, por host

log = logging.getLogger("viasacra")

# ---------------------------------------------------------------------------
# Fontes e atribuições
# ---------------------------------------------------------------------------

FONTE_CNBB = {
    "id": "cnbb",
    "nome": "CNBB — Conferência Nacional dos Bispos do Brasil",
    "url": "https://liturgiadiaria.edicoescnbb.com.br",
    "nota": "Textos litúrgicos reproduzidos para uso devocional e não comercial. Fonte: CNBB / Edições CNBB.",
}
FONTE_VATICANO = {
    "id": "vaticannews",
    "nome": "Vatican News (Português) — Dicastério para a Comunicação",
    "url": "https://www.vaticannews.va/pt.html",
    "nota": (
        "© Libreria Editrice Vaticana / Dicastério para a Comunicação. "
        "Reprodução para fins pastorais e não comerciais, com citação da fonte e link para o original."
    ),
}
FONTE_PATRISTICA = {
    "id": "patristica",
    "nome": "Santos Padres e Doutores da Igreja (domínio público)",
    "url": "https://www.newadvent.org/fathers/",
    "nota": "Obras em domínio público; traduções do projeto Via Sacra (GPL-3.0 / CC0 para o texto).",
}

CNBB_SITE_ORIGIN = "https://liturgiadiaria.edicoescnbb.com.br"
CNBB_API_URL = "https://api-liturgia.edicoescnbb.com.br/contents/in/date/{iso}"
CNBB_API_HEADERS = {
    "Accept": "application/json",
    "Origin": CNBB_SITE_ORIGIN,
    "Referer": f"{CNBB_SITE_ORIGIN}/",
}
CNBB_URLS = [
    # Padrões legados do portal (fallback caso a API mude).
    "https://liturgiadiaria.cnbb.org.br/?data={iso}",
    "https://liturgiadiaria.cnbb.org.br/app/user/user/UserView.php?ano={ano}&mes={mes}&dia={dia}",
    "https://liturgiadiaria.cnbb.org.br/liturgia/{dia:02d}-{mes:02d}-{ano}",
]
# Página "Palavra do dia": leituras + "As palavras dos Papas" (estrutura verificada em nov/2026)
VATICAN_GOSPEL_URL = "https://www.vaticannews.va/pt/palavra-do-dia/{ano}/{mes:02d}/{dia:02d}.html"
VATICAN_RSS_URLS = [
    "https://www.vaticannews.va/pt.rss.xml",
    "https://www.vaticannews.va/pt/papa.rss.xml",
]

# ---------------------------------------------------------------------------
# HTTP educado
# ---------------------------------------------------------------------------


# Servidores com configuração TLS antiga (o da CNBB recusa o handshake padrão do
# OpenSSL 3 com "SSLV3_ALERT_HANDSHAKE_FAILURE", inclusive no GitHub Actions).
HOSTS_TLS_LEGADO = ("https://liturgiadiaria.cnbb.org.br",)


class AdaptadorTLSLegado(HTTPAdapter):
    """Aceita cifras/renegociação legadas SÓ nos hosts listados, mantendo a
    verificação de certificado e de nome do servidor ligadas."""

    def _contexto(self) -> ssl.SSLContext:
        ctx = ssl.create_default_context()
        ctx.set_ciphers("DEFAULT:@SECLEVEL=1")
        ctx.options |= getattr(ssl, "OP_LEGACY_SERVER_CONNECT", 0x4)
        ctx.minimum_version = ssl.TLSVersion.TLSv1_2
        return ctx

    def init_poolmanager(self, *args: Any, **kwargs: Any) -> None:
        kwargs["ssl_context"] = self._contexto()
        super().init_poolmanager(*args, **kwargs)

    def proxy_manager_for(self, *args: Any, **kwargs: Any) -> Any:
        kwargs["ssl_context"] = self._contexto()
        return super().proxy_manager_for(*args, **kwargs)


class FonteIndisponivel(RuntimeError):
    """Erro recuperável de uma fonte específica."""


@dataclass
class ClienteHttp:
    respeitar_robots: bool = True
    offline_html: dict[str, str] = field(default_factory=dict)
    _sessao: requests.Session = field(default_factory=requests.Session, init=False)
    _robots: dict[str, robotparser.RobotFileParser | None] = field(default_factory=dict, init=False)
    _ultimo_acesso: dict[str, float] = field(default_factory=dict, init=False)
    _cache: dict[str, str] = field(default_factory=dict, init=False)

    def __post_init__(self) -> None:
        for host in HOSTS_TLS_LEGADO:
            self._sessao.mount(host, AdaptadorTLSLegado())
        self._sessao.headers.update(
            {
                "User-Agent": USER_AGENT,
                "Accept-Language": "pt-BR,pt;q=0.9",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            }
        )

    def _permitido(self, url: str) -> bool:
        if not self.respeitar_robots:
            return True
        host = urlparse(url)
        raiz = f"{host.scheme}://{host.netloc}"
        if raiz not in self._robots:
            rp = robotparser.RobotFileParser()
            try:
                resp = self._sessao.get(urljoin(raiz, "/robots.txt"), timeout=REQUEST_TIMEOUT)
                if resp.status_code >= 400:
                    self._robots[raiz] = None  # sem robots.txt → permitido
                else:
                    rp.parse(resp.text.splitlines())
                    self._robots[raiz] = rp
            except requests.RequestException:
                self._robots[raiz] = None
        rp = self._robots[raiz]
        return True if rp is None else rp.can_fetch(USER_AGENT, url)

    def _aguardar(self, url: str) -> None:
        host = urlparse(url).netloc
        decorrido = time.monotonic() - self._ultimo_acesso.get(host, 0.0)
        if decorrido < MIN_INTERVALO_ENTRE_REQUISICOES:
            time.sleep(MIN_INTERVALO_ENTRE_REQUISICOES - decorrido)
        self._ultimo_acesso[host] = time.monotonic()

    def get(
        self,
        url: str,
        *,
        tentativas: int = 3,
        chave_offline: str | None = None,
        headers: dict[str, str] | None = None,
        respeitar_robots: bool = True,
    ) -> str:
        """Baixa ``url`` com cache, intervalo mínimo por host, timeout e novas tentativas.

        ``respeitar_robots=False`` só deve ser usado em exceções documentadas na
        chamada (hoje: o feed Atom público do YouTube, ver ``_buscar_feed_youtube``).
        """
        if chave_offline and chave_offline in self.offline_html:
            return Path(self.offline_html[chave_offline]).read_text(encoding="utf-8")
        if url in self._cache:  # a mesma página serve à homilia e às leituras
            return self._cache[url]
        if respeitar_robots and not self._permitido(url):
            raise FonteIndisponivel(f"robots.txt não permite acessar {url}")
        ultimo_erro: Exception | None = None
        for tentativa in range(1, tentativas + 1):
            self._aguardar(url)
            try:
                resp = self._sessao.get(url, timeout=REQUEST_TIMEOUT, headers=headers)
                if resp.status_code == 404:
                    raise FonteIndisponivel(f"404 em {url}")
                resp.raise_for_status()
                resp.encoding = resp.apparent_encoding if resp.encoding in (None, "ISO-8859-1") else resp.encoding
                self._cache[url] = resp.text
                return resp.text
            except FonteIndisponivel:
                raise
            except requests.RequestException as exc:
                ultimo_erro = exc
                espera = 2**tentativa
                log.warning("Falha ao acessar %s (tentativa %d/%d): %s", url, tentativa, tentativas, exc)
                if tentativa < tentativas:
                    time.sleep(espera)
        raise FonteIndisponivel(f"Não foi possível acessar {url}: {ultimo_erro}")


# ---------------------------------------------------------------------------
# Utilidades de texto
# ---------------------------------------------------------------------------

RE_ESPACOS = re.compile(r"[ \t ]+")
RE_LINHAS = re.compile(r"\n{3,}")
# Ex.: "Lc 19,41-44", "1Cor 15,20-26.28", "Sl 121(122)", "Is 2,1-5"
RE_REFERENCIA = re.compile(
    r"\b((?:[1-3]\s?)?[A-ZÁÉÍÓÚ][a-zçãõáéíóúê]{0,3}\.?\s?\d{1,3}(?:\(\d{1,3}\))?"
    r"(?:\s?[,:]\s?\d{1,3}[a-z]?(?:\s?[-–.]\s?\d{1,3}[a-z]?)*)*)"
)
SECOES = {
    "primeira_leitura": ("primeira leitura", "1ª leitura", "1a leitura", "leitura i"),
    "salmo": ("salmo responsorial", "salmo"),
    "segunda_leitura": ("segunda leitura", "2ª leitura", "2a leitura", "leitura ii"),
    "aclamacao": ("aclamacao ao evangelho", "aclamacao"),
    "evangelho": ("evangelho",),
    "reflexao": ("reflexão", "reflexao", "comentário", "comentario", "homilia"),
}
CORES = {
    "verde": "verde",
    "roxo": "roxo",
    "roxa": "roxo",
    "violeta": "roxo",
    "branco": "branco",
    "branca": "branco",
    "dourado": "branco",
    "vermelho": "vermelho",
    "vermelha": "vermelho",
    "rosa": "rosa",
    "rósea": "rosa",
}


def normalizar(texto: str) -> str:
    sem_acentos = unicodedata.normalize("NFKD", texto)
    return "".join(c for c in sem_acentos if not unicodedata.combining(c)).lower().strip()


def limpar(texto: str) -> str:
    linhas = [RE_ESPACOS.sub(" ", linha).strip() for linha in texto.replace("\r", "").split("\n")]
    return RE_LINHAS.sub("\n\n", "\n".join(linhas)).strip()


def texto_de(no: Tag | NavigableString) -> str:
    """Extrai texto preservando quebras de parágrafo e <br>."""
    if isinstance(no, NavigableString):
        return str(no)
    for br in no.find_all("br"):
        br.replace_with("\n")
    partes: list[str] = []
    for filho in no.descendants:
        if isinstance(filho, NavigableString) and filho.parent and filho.parent.name not in {"script", "style"}:
            partes.append(str(filho))
        elif isinstance(filho, Tag) and filho.name in {"p", "div", "li", "h1", "h2", "h3", "h4", "h5"}:
            partes.append("\n")
    return limpar("".join(partes))


def extrair_referencia(texto: str) -> str | None:
    for candidato in RE_REFERENCIA.findall(texto):
        if re.search(r"\d", candidato) and len(candidato) <= 40:
            return candidato.strip()
    return None


def identificar_secao(titulo: str) -> str | None:
    t = normalizar(titulo)
    if len(t) > 60:
        return None
    for chave, termos in SECOES.items():
        if any(t.startswith(normalizar(termo)) for termo in termos):
            return chave
    return None


# ---------------------------------------------------------------------------
# CNBB — Liturgia Diária
# ---------------------------------------------------------------------------


def parse_salmo(texto: str, titulo_secao: str = "") -> dict[str, Any]:
    """Separa refrão e estrofes do Salmo Responsorial.

    Convenções encontradas nas fontes brasileiras:
    - linha iniciada por "R." / "— " / "Refrão:" marca o refrão;
    - estrofes separadas por linha em branco; o refrão repetido é removido.
    """
    linhas = [linha.strip() for linha in texto.split("\n")]
    referencia = extrair_referencia(titulo_secao)
    refrao = None
    corpo: list[str] = []
    for linha in linhas:
        if not linha:
            corpo.append("")
            continue
        if referencia is None and (ref := extrair_referencia(linha)) and len(linha) < 50:
            referencia = ref
            continue
        marcador = re.match(r"^(?:R\.|R\/|Refr[ãa]o:?|—|–|-)\s*(.+)$", linha)
        if marcador:
            if refrao is None:
                refrao = marcador.group(1).strip()
            continue
        if refrao and normalizar(linha) == normalizar(refrao):
            continue
        corpo.append(linha)
    if refrao is None:
        # Sem marcador: a primeira linha não vazia costuma ser o refrão
        nao_vazias = [i for i, linha in enumerate(corpo) if linha]
        if nao_vazias:
            refrao = corpo.pop(nao_vazias[0])
    estrofes = [e.strip() for e in "\n".join(corpo).split("\n\n") if e.strip()]
    return {
        "referencia": referencia,
        "refrao": refrao,
        "estrofes": estrofes,
        "texto": limpar("\n\n".join(estrofes)),
    }


RE_INTRODUCAO = re.compile(
    r"^(Leitura d[aoe]s?|Proclamação do Evangelho|Início d[ao]|Evangelho de Jesus Cristo|"
    r"Anúncio do Evangelho)", re.I)
RE_ACLAMACAO = re.compile(r"^(Aleluia|Louvor a vós|Louvor e honra|Glória a vós|Honra, glória|Salve, ó Cristo)", re.I)
RE_CONCLUSAO = re.compile(r"\s*(Palavra do Senhor\.?|Palavra da Salvação\.?)\s*$")


def parse_leitura(texto: str, titulo_secao: str = "") -> dict[str, Any]:
    """Estrutura uma leitura: referência, aclamação (Evangelho), introdução e corpo."""
    paragrafos = [p.strip() for p in re.split(r"\n\s*\n", texto) if p.strip()]
    referencia = extrair_referencia(titulo_secao)
    if (
        referencia is None
        and paragrafos
        and len(paragrafos[0]) < 50
        and not RE_INTRODUCAO.match(paragrafos[0])
        and (ref := extrair_referencia(paragrafos[0]))
    ):
        referencia = ref
        paragrafos.pop(0)

    aclamacao: list[str] = []
    if paragrafos and RE_ACLAMACAO.match(paragrafos[0]):
        while paragrafos and not RE_INTRODUCAO.match(paragrafos[0]) and len(aclamacao) < 3:
            aclamacao.append(paragrafos.pop(0))

    introducao = None
    for i, p in enumerate(paragrafos[:3]):
        if RE_INTRODUCAO.match(p) and len(p) < 160:
            introducao = paragrafos.pop(i)
            break

    while paragrafos and RE_CONCLUSAO.fullmatch(paragrafos[-1]):
        paragrafos.pop()
    corpo = RE_CONCLUSAO.sub("", "\n\n".join(paragrafos))
    return {
        "referencia": referencia,
        "introducao": introducao,
        "aclamacao": limpar("\n".join(aclamacao)) or None,
        "texto": limpar(corpo),
    }


def _blocos_por_titulo(soup: BeautifulSoup) -> list[tuple[str, str, str]]:
    """Retorna [(chave_secao, titulo, texto)] varrendo títulos e o conteúdo seguinte.

    Abordagem heurística e resiliente a mudanças de layout: qualquer título
    (h1-h5, strong, b, .titulo) que corresponda a uma seção conhecida inicia
    um bloco que vai até o próximo título de seção.
    """
    conteudo = (
        soup.select_one("#corpo_leituras")
        or soup.select_one("article")
        or soup.select_one("main")
        or soup.body
        or soup
    )
    candidatos = conteudo.find_all(["h1", "h2", "h3", "h4", "h5", "strong", "b", "span", "div", "p", "font", "center"])
    marcadores: list[tuple[Tag, str]] = []
    vistos: set[int] = set()
    for el in candidatos:
        titulo = el.get_text(" ", strip=True)
        chave = identificar_secao(titulo)
        if not chave:
            continue
        # Evita contar o mesmo título duas vezes (ex.: <h3><strong>…</strong></h3>)
        if any(id(p) in vistos for p in el.parents):
            continue
        vistos.add(id(el))
        marcadores.append((el, chave))

    blocos: list[tuple[str, str, str]] = []
    for idx, (el, chave) in enumerate(marcadores):
        proximo = marcadores[idx + 1][0] if idx + 1 < len(marcadores) else None
        partes: list[str] = []
        for irmao in el.next_elements:
            if irmao is proximo:
                break
            if isinstance(irmao, Tag) and proximo is not None and proximo in irmao.descendants:
                continue
            pai = irmao.parent if isinstance(irmao, NavigableString) else None
            if pai is not None and pai.name in {"script", "style"}:
                continue
            if isinstance(irmao, NavigableString) and el not in irmao.parents:
                partes.append(str(irmao))
            elif isinstance(irmao, Tag) and irmao.name in {"br", "p", "div", "li"}:
                partes.append("\n")
        blocos.append((chave, el.get_text(" ", strip=True), limpar("".join(partes))))
    return blocos


def _limpar_html_cnbb_api(html: str) -> BeautifulSoup:
    """Remove elementos ocultos, epígrafes e números de versículo do HTML da API Edições CNBB."""
    soup = BeautifulSoup(html, "html.parser")
    for lixo in soup(["script", "style", "nav", "footer", "header", "form", "noscript", "iframe", "img"]):
        lixo.decompose()
    for el in list(soup.find_all(style=True)):
        st = normalizar(str(el.get("style", "")))
        if "display: none" in st or "display:none" in st:
            el.decompose()
            continue
        # Coluna lateral com número do versículo (min-width: 30px; color: #FF0000)
        if "min-width: 30px" in st and "#ff0000" in st:
            txt = el.get_text(strip=True)
            if not txt or re.fullmatch(r"\d+[a-z]?", txt):
                el.decompose()
    for p in list(soup.find_all("p", attrs={"align": "right"})):
        p.decompose()
    return soup


def _referencias_cnbb_api(leituras_html: str) -> dict[str, str | None]:
    """Extrai as referências do campo `leituras` da API (ordem: 1ª, Salmo, 2ª, Evangelho)."""
    refs: dict[str, str | None] = {
        "primeira_leitura": None,
        "salmo": None,
        "segunda_leitura": None,
        "evangelho": None,
    }
    if not leituras_html:
        return refs
    soup = BeautifulSoup(leituras_html, "html.parser")
    itens = [
        d.get_text(" ", strip=True)
        for d in soup.find_all("div")
        if normalizar(d.get_text(" ", strip=True)) != "leituras:"
    ]
    chaves = ("primeira_leitura", "salmo", "segunda_leitura", "evangelho")
    for chave, texto in zip(chaves, itens, strict=False):
        if texto:
            refs[chave] = extrair_referencia(texto) or texto
    return refs


def _celebracao_cnbb_api(details_html: str, fallback_title: str | None) -> str | None:
    if details_html:
        soup = BeautifulSoup(details_html, "html.parser")
        for div in soup.find_all("div", style=True):
            if "font-size: 26px" in str(div.get("style", "")).lower():
                texto = limpar(div.get_text(" ", strip=True))
                texto = re.sub(r"\s*,\s*Ano\s+[ABC]\b", "", texto, flags=re.I)
                texto = re.sub(r"\s+,", ",", texto)
                if texto:
                    return texto
    return fallback_title.strip() if isinstance(fallback_title, str) and fallback_title.strip() else None


def _limpar_aclamacao(texto: str) -> str | None:
    linhas = [linha.strip() for linha in texto.split("\n") if linha.strip()]
    # Remove a primeira linha se for apenas a referência bíblica (ex.: "Jo 14,6")
    if linhas and len(linhas[0]) < 40 and extrair_referencia(linhas[0]) and not RE_ACLAMACAO.match(linhas[0]):
        linhas.pop(0)
    limpo = limpar("\n".join(linhas))
    return limpo or None


def parse_cnbb_api(payload: str, url: str) -> dict[str, Any]:
    """Interpreta o JSON retornado por `api-liturgia.edicoescnbb.com.br/contents/in/date/AAAA-MM-DD`."""
    try:
        dados = json.loads(payload)
    except json.JSONDecodeError as exc:
        raise FonteIndisponivel(f"Resposta da API CNBB não é JSON válido: {exc}") from exc

    content = dados.get("content") if isinstance(dados, dict) else None
    if not isinstance(content, dict) or not content.get("body"):
        raise FonteIndisponivel("Resposta da API CNBB sem conteúdo (campo content.body ausente)")

    cor_bruta = normalizar(str(content.get("color") or ""))
    refs = _referencias_cnbb_api(str(content.get("leituras") or ""))

    resultado: dict[str, Any] = {
        "celebracao": _celebracao_cnbb_api(str(content.get("details") or ""), content.get("title")),
        "cor": CORES.get(cor_bruta) if cor_bruta else None,
        "primeira_leitura": None,
        "salmo": None,
        "segunda_leitura": None,
        "evangelho": None,
        "reflexao": None,
        "url": FONTE_CNBB["url"],
    }

    soup = _limpar_html_cnbb_api(str(content["body"]))
    aclamacao_texto: str | None = None

    for chave, titulo_secao, texto in _blocos_por_titulo(soup):
        if not texto:
            continue
        if chave == "aclamacao":
            if aclamacao_texto is None:
                aclamacao_texto = _limpar_aclamacao(texto)
            continue
        if resultado.get(chave):
            continue
        if chave == "salmo":
            salmo = parse_salmo(texto, titulo_secao)
            # Remove marcador "R." solto no fim das estrofes e linhas "Ou: Aleluia..."
            estrofes_limpas: list[str] = []
            for e in salmo["estrofes"]:
                linhas_e = [
                    re.sub(r"\s*\bR\.\s*$", "", ln).strip()
                    for ln in e.split("\n")
                    if not re.match(r"^Ou:\s*", ln.strip(), re.I)
                ]
                bloco = "\n".join(ln for ln in linhas_e if ln).strip()
                if bloco:
                    estrofes_limpas.append(bloco)
            salmo["estrofes"] = estrofes_limpas
            salmo["texto"] = limpar("\n\n".join(estrofes_limpas))
            if refs["salmo"]:
                salmo["referencia"] = refs["salmo"]
            resultado["salmo"] = salmo
        elif chave == "reflexao":
            resultado["reflexao"] = {
                "titulo": titulo_secao,
                "texto": texto,
                "autor": None,
                "url": FONTE_CNBB["url"],
                "fonte": FONTE_CNBB["nome"],
            }
        else:
            leitura = parse_leitura(texto, titulo_secao)
            if refs.get(chave):
                leitura["referencia"] = refs[chave]
            resultado[chave] = leitura

    if resultado["evangelho"] and aclamacao_texto and not resultado["evangelho"].get("aclamacao"):
        resultado["evangelho"]["aclamacao"] = aclamacao_texto

    if not resultado["evangelho"] or not resultado["primeira_leitura"]:
        raise FonteIndisponivel("Estrutura do JSON da API CNBB não reconhecida (leituras não encontradas)")
    return resultado


def parse_cnbb(html: str, url: str) -> dict[str, Any]:
    soup = BeautifulSoup(html, "html.parser")
    for lixo in soup(["script", "style", "nav", "footer", "header", "form", "noscript", "iframe"]):
        lixo.decompose()

    resultado: dict[str, Any] = {
        "celebracao": None,
        "cor": None,
        "primeira_leitura": None,
        "salmo": None,
        "segunda_leitura": None,
        "evangelho": None,
        "reflexao": None,
        "url": url,
    }

    titulo = soup.select_one("h1, .titulo-liturgia, .entry-title, h2")
    if titulo:
        resultado["celebracao"] = titulo.get_text(" ", strip=True) or None

    texto_pagina = normalizar(soup.get_text(" ", strip=True))
    if m := re.search(r"cor\s*(?:liturgica)?\s*[:\-]?\s*(verde|roxa?|violeta|branca?|vermelha?|rosa|rosea|dourado)",
                      texto_pagina):
        resultado["cor"] = CORES.get(m.group(1), m.group(1))

    aclamacao_texto: str | None = None
    for chave, titulo_secao, texto in _blocos_por_titulo(soup):
        if not texto:
            continue
        if chave == "aclamacao":
            if aclamacao_texto is None:
                aclamacao_texto = _limpar_aclamacao(texto)
            continue
        if resultado.get(chave):
            continue
        if chave == "salmo":
            resultado["salmo"] = parse_salmo(texto, titulo_secao)
        elif chave == "reflexao":
            resultado["reflexao"] = {
                "titulo": titulo_secao,
                "texto": texto,
                "autor": None,
                "url": url,
                "fonte": FONTE_CNBB["nome"],
            }
        else:
            resultado[chave] = parse_leitura(texto, titulo_secao)

    if resultado["evangelho"] and aclamacao_texto and not resultado["evangelho"].get("aclamacao"):
        resultado["evangelho"]["aclamacao"] = aclamacao_texto

    if not resultado["evangelho"] or not resultado["primeira_leitura"]:
        raise FonteIndisponivel("Estrutura da página da CNBB não reconhecida (leituras não encontradas)")
    return resultado


def coletar_cnbb(cliente: ClienteHttp, d: date) -> dict[str, Any]:
    erros: list[str] = []
    if "cnbb" in cliente.offline_html:
        bruto = cliente.get(CNBB_API_URL.format(iso=d.isoformat()), chave_offline="cnbb")
        if bruto.lstrip().startswith("{"):
            return parse_cnbb_api(bruto, CNBB_API_URL.format(iso=d.isoformat()))
        return parse_cnbb(bruto, CNBB_URLS[0].format(iso=d.isoformat(), ano=d.year, mes=d.month, dia=d.day))

    api_url = CNBB_API_URL.format(iso=d.isoformat())
    try:
        payload = cliente.get(api_url, headers=CNBB_API_HEADERS)
        return parse_cnbb_api(payload, api_url)
    except FonteIndisponivel as exc:
        erros.append(f"API Edições CNBB: {exc}")

    for modelo in CNBB_URLS:
        url = modelo.format(iso=d.isoformat(), ano=d.year, mes=d.month, dia=d.day)
        try:
            html = cliente.get(url)
            return parse_cnbb(html, url)
        except FonteIndisponivel as exc:
            erros.append(str(exc))
    raise FonteIndisponivel("; ".join(erros))


# ---------------------------------------------------------------------------
# Vatican News — Homilia / Palavras do Santo Padre
# ---------------------------------------------------------------------------


def _secoes_vatican(soup: BeautifulSoup) -> dict[str, list[str]]:
    """Seções da página "Palavra do dia": título normalizado → linhas (<p>)."""
    secoes: dict[str, list[str]] = {}
    for titulo in soup.find_all(["h2", "h3"]):
        secao = titulo.find_parent("section")
        if secao is None:
            continue
        conteudo = secao.find(class_="section__content") or secao
        linhas = [p.get_text(" ", strip=True) for p in conteudo.find_all("p")]
        linhas = [linha for linha in linhas if linha]
        if linhas:
            secoes.setdefault(normalizar(titulo.get_text(" ", strip=True)), linhas)
    return secoes


def _autor_papa(texto: str) -> str:
    if m := re.search(r"\((?:Papa\s+)?(Leão XIV|Francisco|Bento XVI|João Paulo II)[^)]*\)", texto):
        return f"Papa {m.group(1)}"
    return "Papa Leão XIV"


def parse_vatican_evangelho_do_dia(html: str, url: str) -> dict[str, Any] | None:
    """"As palavras dos Papas" (antes: "Palavras do Santo Padre") da página "Palavra do dia"."""
    soup = BeautifulSoup(html, "html.parser")
    for lixo in soup(["script", "style", "nav", "footer", "header", "form", "noscript"]):
        lixo.decompose()
    partes: list[str] = []
    for titulo, linhas in _secoes_vatican(soup).items():
        if any(k in titulo for k in ("palavras dos papas", "palavras do santo padre", "palavras do papa")):
            partes = linhas
            break
    if not partes:  # layout antigo: título seguido de parágrafos soltos
        for titulo in soup.find_all(["h2", "h3", "h4", "strong"]):
            t = normalizar(titulo.get_text(" ", strip=True))
            if "palavras do santo padre" in t or "palavras do papa" in t or t.startswith("reflexao"):
                for irmao in titulo.find_all_next(["p", "h2", "h3"]):
                    if irmao.name in {"h2", "h3"} and partes:
                        break
                    if texto := irmao.get_text(" ", strip=True):
                        partes.append(texto)
                break
    texto = limpar("\n\n".join(partes))
    if len(texto) < 80:
        return None
    return {
        "titulo": "As palavras dos Papas",
        "autor": _autor_papa(texto),
        "texto": texto,
        "resumo": texto[:280].rsplit(" ", 1)[0] + "…" if len(texto) > 280 else texto,
        "url": url,
        "fonte": FONTE_VATICANO["nome"],
        "licenca": FONTE_VATICANO["nota"],
    }


# Livros: nome normalizado → abreviação (ordinal tratado à parte)
_LIVROS_POR_NOME = [
    ("apocalipse", "Ap"), ("atos dos apostolos", "At"), ("eclesiastico", "Eclo"), ("siracida", "Eclo"),
    ("eclesiastes", "Ecl"), ("genesis", "Gn"), ("exodo", "Ex"), ("levitico", "Lv"), ("numeros", "Nm"),
    ("deuteronomio", "Dt"), ("josue", "Js"), ("juizes", "Jz"), ("rute", "Rt"), ("esdras", "Esd"),
    ("neemias", "Ne"), ("tobias", "Tb"), ("judite", "Jt"), ("ester", "Est"), ("jo ", "Jó"),
    ("salmo", "Sl"), ("proverbios", "Pr"), ("cantico dos canticos", "Ct"), ("sabedoria", "Sb"),
    ("isaias", "Is"), ("jeremias", "Jr"), ("lamentacoes", "Lm"), ("baruc", "Br"), ("ezequiel", "Ez"),
    ("daniel", "Dn"), ("oseias", "Os"), ("joel", "Jl"), ("amos", "Am"), ("abdias", "Ab"), ("jonas", "Jn"),
    ("miqueias", "Mq"), ("naum", "Na"), ("habacuc", "Hab"), ("sofonias", "Sf"), ("ageu", "Ag"),
    ("zacarias", "Zc"), ("malaquias", "Ml"), ("romanos", "Rm"), ("galatas", "Gl"), ("efesios", "Ef"),
    ("filipenses", "Fl"), ("colossenses", "Cl"), ("tito", "Tt"), ("filemon", "Fm"), ("hebreus", "Hb"),
    ("tiago", "Tg"), ("judas", "Jd"), ("mateus", "Mt"), ("marcos", "Mc"), ("lucas", "Lc"),
]
_LIVROS_NUMERADOS = {
    "samuel": "Sm", "reis": "Rs", "cronicas": "Cr", "macabeus": "Mc", "corintios": "Cor",
    "tessalonicenses": "Ts", "timoteo": "Tm", "pedro": "Pd", "joao": "Jo",
}
_ORDINAIS = {"primeira": "1", "primeiro": "1", "segunda": "2", "segundo": "2", "terceira": "3"}


def livro_por_introducao(intro: str) -> str | None:
    """"Leitura da Primeira Carta de São Paulo aos Coríntios" → "1Cor"; "…segundo João" → "Jo"."""
    t = normalizar(intro) + " "
    ordinal = next((n for palavra, n in _ORDINAIS.items() if f" {palavra} " in f" {t}"), None)
    for nome, abrev in _LIVROS_POR_NOME:  # nomes inequívocos primeiro ("Apocalipse de São João")
        if nome in t:
            return abrev
    for nome, abrev in _LIVROS_NUMERADOS.items():
        if nome in t:
            if nome == "joao" and (ordinal is None or "evangelho" in t):
                return "Jo"
            return f"{ordinal or '1'}{abrev}"
    return None


def _leitura_vatican(linhas: list[str]) -> dict[str, Any] | None:
    # Domingos/solenidades: a seção começa com um rótulo ("Primeira Leitura").
    if linhas and normalizar(linhas[0]) in {"primeira leitura", "segunda leitura", "leitura", "evangelho"}:
        linhas = linhas[1:]
    if len(linhas) < 3:
        return None
    intro, numeros = linhas[0], linhas[1]
    corpo = linhas[2:]
    if not re.match(r"^\d{1,3}[,:]", numeros):  # sem linha de referência
        numeros, corpo = "", linhas[1:]
    livro = livro_por_introducao(intro)
    referencia = f"{livro} {numeros}".strip() if livro and numeros else None
    corpo = [linha for linha in corpo if not RE_CONCLUSAO.fullmatch(linha)]
    return {"referencia": referencia, "introducao": intro, "aclamacao": None, "texto": limpar("\n".join(corpo))}


def parse_vatican_leituras(html: str, url: str) -> dict[str, Any] | None:
    """Leituras da página "Palavra do dia" — fonte de reserva quando a CNBB falha (sem Salmo)."""
    soup = BeautifulSoup(html, "html.parser")
    secoes = _secoes_vatican(soup)
    primeira = next((_leitura_vatican(v) for k, v in secoes.items() if k.startswith("leitura do dia")), None)
    evangelho = next((_leitura_vatican(v) for k, v in secoes.items() if k.startswith("evangelho do dia")), None)
    if not evangelho:
        return None
    return {"primeira_leitura": primeira, "salmo": None, "segunda_leitura": None, "evangelho": evangelho, "url": url}


def _texto_tag(item: Tag, nome: str) -> str:
    filho = item.find(nome)
    return filho.get_text(strip=True) if filho else ""


def parse_vatican_rss(xml: str, d: date) -> dict[str, Any] | None:
    """Fallback: item mais recente do RSS cujo título indique homilia/meditação do Papa."""
    soup = BeautifulSoup(xml, "xml")
    melhores: list[tuple[int, dict[str, Any]]] = []
    for item in soup.find_all("item"):
        titulo = _texto_tag(item, "title")
        descricao = BeautifulSoup(_texto_tag(item, "description"), "html.parser").get_text(" ", strip=True)
        link = _texto_tag(item, "link")
        t = normalizar(titulo + " " + descricao)
        pontos = sum(
            peso
            for termo, peso in (("homilia", 5), ("angelus", 4), ("regina", 3), ("audiencia", 3),
                                ("santa marta", 4), ("papa", 1), ("evangelho", 2))
            if termo in t
        )
        if pontos < 3:
            continue
        publicado = _texto_tag(item, "pubDate")
        melhores.append((pontos, {
            "titulo": limpar(titulo),
            "autor": "Papa Leão XIV",
            "texto": limpar(descricao),
            "resumo": limpar(descricao)[:280],
            "url": link,
            "publicado_em": publicado,
            "fonte": FONTE_VATICANO["nome"],
            "licenca": FONTE_VATICANO["nota"],
            "observacao": "Resumo do feed RSS — leia o texto completo no link original.",
        }))
    if not melhores:
        return None
    melhores.sort(key=lambda x: x[0], reverse=True)
    return melhores[0][1]


def coletar_vaticano_leituras(cliente: ClienteHttp, d: date) -> dict[str, Any]:
    url = VATICAN_GOSPEL_URL.format(ano=d.year, mes=d.month, dia=d.day)
    if resultado := parse_vatican_leituras(cliente.get(url, chave_offline="vatican"), url):
        return resultado
    raise FonteIndisponivel("Leituras não encontradas na página do Vatican News")


def coletar_vaticano(cliente: ClienteHttp, d: date) -> dict[str, Any]:
    url = VATICAN_GOSPEL_URL.format(ano=d.year, mes=d.month, dia=d.day)
    try:
        html = cliente.get(url, chave_offline="vatican")
        if resultado := parse_vatican_evangelho_do_dia(html, url):
            return resultado
    except FonteIndisponivel as exc:
        log.info("Evangelho do dia (Vatican News) indisponível: %s", exc)
    if d != datetime.now(TZ).date():
        raise FonteIndisponivel("RSS só é útil para o dia corrente")
    for rss in VATICAN_RSS_URLS:
        try:
            if resultado := parse_vatican_rss(cliente.get(rss, chave_offline="vatican_rss"), d):
                return resultado
        except FonteIndisponivel as exc:
            log.info("RSS %s indisponível: %s", rss, exc)
    raise FonteIndisponivel("Nenhuma homilia/meditação encontrada no Vatican News")


# ---------------------------------------------------------------------------
# Santos Padres (domínio público, offline)
# ---------------------------------------------------------------------------

RE_REF_EVANGELHO = re.compile(r"^(Mt|Mc|Lc|Jo)\s*(\d{1,2})")


def carregar_json(caminho: Path) -> Any:
    return json.loads(caminho.read_text(encoding="utf-8"))


def selecionar_patristica(referencia_evangelho: str | None, tempo: str,
                          acervo: list[dict[str, Any]], limite: int = 2) -> list[dict[str, Any]]:
    """Cruza o Evangelho do dia com comentários patrísticos por livro/capítulo.

    Prioridade: (1) mesmo livro e capítulo; (2) mesmo capítulo em passagem
    paralela listada; (3) comentário associado ao Tempo Litúrgico.
    """
    livro = capitulo = None
    if referencia_evangelho and (m := RE_REF_EVANGELHO.match(referencia_evangelho.strip())):
        livro, capitulo = m.group(1), int(m.group(2))

    def pontua(item: dict[str, Any]) -> int:
        pontos = 0
        for ref in item.get("passagens", []):
            if livro and ref.get("livro") == livro and capitulo in ref.get("capitulos", []):
                pontos = max(pontos, 10)
            elif capitulo and capitulo in ref.get("capitulos", []) and ref.get("livro") in {"Mt", "Mc", "Lc"} \
                    and livro in {"Mt", "Mc", "Lc"}:
                pontos = max(pontos, 4)
        if tempo in item.get("tempos", []):
            pontos += 2
        return pontos

    ordenados = sorted(((pontua(i), i) for i in acervo), key=lambda x: x[0], reverse=True)
    escolhidos = [i for p, i in ordenados if p > 0][:limite]
    if not escolhidos:
        escolhidos = [i for i in acervo if "geral" in i.get("tempos", [])][:1]
    return [
        {
            "autor": i["autor"],
            "obra": i["obra"],
            "texto": i["texto"],
            "url": i.get("url"),
            "fonte": FONTE_PATRISTICA["nome"],
            "licenca": "Domínio público",
            "nota": i.get("nota"),
        }
        for i in escolhidos
    ]


# ---------------------------------------------------------------------------
# Áudio aberto (salmo cantado / liturgia narrada)
# ---------------------------------------------------------------------------


_YT_FEED_CACHE: dict[str, list[dict[str, str]]] = {}
_YT_ATOM_NS = {
    "atom": "http://www.w3.org/2005/Atom",
    "yt": "http://www.youtube.com/xml/schemas/2015",
}


def _normalizar_busca(texto: str) -> str:
    sem_acento = "".join(c for c in unicodedata.normalize("NFD", texto) if unicodedata.category(c) != "Mn")
    return re.sub(r"[^a-z0-9]+", " ", sem_acento.lower()).strip()


def _extrair_numeros_salmo(salmo_ref: str | None) -> set[str]:
    if not salmo_ref:
        return set()
    # Antes da vírgula ficam os números do salmo (ex.: "Sl 118(119), 103" → {"118", "119"}).
    cabeca = salmo_ref.split(",", 1)[0]
    nums = set(re.findall(r"\b\d{1,3}\b", cabeca))
    return nums


def _buscar_feed_youtube(channel_id: str, cliente: ClienteHttp | None) -> list[dict[str, str]]:
    if channel_id in _YT_FEED_CACHE:
        return _YT_FEED_CACHE[channel_id]
    if cliente is None or cliente.offline_html:
        return []
    url = f"https://www.youtube.com/feeds/videos.xml?channel_id={channel_id}"
    try:
        # Exceção ao robots.txt (decisão do projeto, issue #11): o YouTube marca
        # /feeds/videos.xml como Disallow, mas é o feed Atom público e documentado
        # do canal, lido 1x por canal por execução (cache), com o intervalo
        # mínimo por host e sem novas tentativas. Só metadados (id e título) são
        # usados, para o embed oficial youtube-nocookie no app.
        xml = cliente.get(
            url,
            tentativas=1,
            headers={"Accept": "application/atom+xml, application/xml;q=0.9"},
            respeitar_robots=False,
        )
        root = ET.fromstring(xml)
    except Exception as exc:  # noqa: BLE001 — feed externo opcional
        log.warning("Feed YouTube %s indisponível: %s", channel_id, exc)
        _YT_FEED_CACHE[channel_id] = []
        return []

    entradas: list[dict[str, str]] = []
    for entry in root.findall("atom:entry", _YT_ATOM_NS):
        vid = (entry.findtext("yt:videoId", "", _YT_ATOM_NS) or "").strip()
        titulo = (entry.findtext("atom:title", "", _YT_ATOM_NS) or "").strip()
        autor = (entry.findtext("atom:author/atom:name", "", _YT_ATOM_NS) or "").strip()
        if vid and titulo:
            entradas.append({"video_id": vid, "title": titulo, "author": autor})
    _YT_FEED_CACHE[channel_id] = entradas
    return entradas


def _casar_salmo_youtube(
    d: date,
    salmo_ref: str | None,
    salmo_refrao: str | None,
    entradas: list[dict[str, str]],
) -> dict[str, str] | None:
    """Encontra o vídeo do salmo responsorial do dia em um feed RSS do YouTube."""
    if not entradas:
        return None
    padrao_data = re.compile(
        rf"(?<!\d)0?{d.day}/0?{d.month}(?:/(?:{d.year}|{d.year % 100:02d}))?(?!\d)"
    )
    # 1. Casamento exato por data no título (ex.: "Salmo 149 - 19/11/2026: ...")
    for e in entradas:
        titulo_norm = _normalizar_busca(e["title"])
        eh_salmo = bool(re.search(r"\b(salmo|sl)\b", titulo_norm))
        if eh_salmo and padrao_data.search(e["title"]):
            return e

    # 2. Casamento por número do salmo + palavras significativas do refrão
    nums = _extrair_numeros_salmo(salmo_ref)
    if not nums or not salmo_refrao:
        return None
    palavras_refrao = {w for w in _normalizar_busca(salmo_refrao).split() if len(w) >= 4}
    if not palavras_refrao:
        return None
    minimo = min(3, max(1, (len(palavras_refrao) + 1) // 2))
    for e in entradas:
        titulo_norm = _normalizar_busca(e["title"])
        if not re.search(r"\b(salmo|sl)\b", titulo_norm):
            continue
        nums_titulo = set(re.findall(r"\b\d{1,3}\b", titulo_norm))
        if not (nums & nums_titulo):
            continue
        palavras_titulo = set(titulo_norm.split())
        if len(palavras_refrao & palavras_titulo) >= minimo:
            return e
    return None


def resolver_audio(
    d: date,
    cal: calendario.DiaLiturgico,
    salmo_ref: str | None,
    config: dict[str, Any],
    salmo_refrao: str | None = None,
    cliente: ClienteHttp | None = None,
) -> dict[str, Any]:
    """Resolve URLs de áudio e embed oficial de salmo a partir de ``audio_sources.json``.

    Apenas fontes pastorais **abertas/públicas e autorizadas** ou **YouTube RSS**
    (embed oficial sem hospedar arquivos de terceiros) devem ser cadastradas lá.
    Suporta três tipos de provedor:
    - ``por_data``: modelo de URL com {ano},{mes},{dia},{iso}
    - ``por_salmo``: mapa "Sl 23" → {url, cifra, interprete}
    - ``youtube_rss``: feed Atom público do YouTube casado por data ou salmo+refrão
    O app usa áudio neural / TTS local (pt-BR) quando os campos são nulos.
    """
    audio: dict[str, Any] = {
        "salmo_audio_url": None,
        "salmo_cifra_ou_melodia": None,
        "salmo_video_id": None,
        "salmo_video_titulo": None,
        "liturgia_audio_url": None,
        "creditos": [],
        "fallback": "tts_local_pt_BR",
    }
    for prov in config.get("provedores", []):
        if not prov.get("ativo", False):
            continue
        campo = prov.get("campo")
        tipo = prov.get("tipo")
        if tipo == "por_data" and campo in audio and audio[campo] is None:
            audio[campo] = prov["modelo_url"].format(ano=d.year, mes=f"{d.month:02d}", dia=f"{d.day:02d}",
                                                     iso=d.isoformat(), ciclo=cal.ciclo_dominical)
            audio["creditos"].append({"campo": campo, "interprete": prov.get("interprete"),
                                      "canal": prov.get("canal"), "url_fonte": prov.get("url_fonte"),
                                      "licenca": prov.get("licenca")})
        elif tipo == "por_salmo" and salmo_ref:
            chave = re.sub(r"[,(].*$", "", salmo_ref).strip()
            if (entrada := prov.get("salmos", {}).get(chave)) and audio["salmo_audio_url"] is None:
                audio["salmo_audio_url"] = entrada.get("url")
                audio["salmo_cifra_ou_melodia"] = entrada.get("cifra")
                audio["creditos"].append({"campo": "salmo_audio_url", "interprete": entrada.get("interprete"),
                                          "canal": prov.get("canal"), "url_fonte": entrada.get("url_fonte"),
                                          "licenca": prov.get("licenca")})
        elif tipo == "youtube_rss" and audio["salmo_video_id"] is None and prov.get("channel_id"):
            entradas = _buscar_feed_youtube(prov["channel_id"], cliente)
            if match := _casar_salmo_youtube(d, salmo_ref, salmo_refrao, entradas):
                audio["salmo_video_id"] = match["video_id"]
                audio["salmo_video_titulo"] = match["title"]
                audio["creditos"].append({
                    "campo": "salmo_video_id",
                    "interprete": match.get("author") or prov.get("canal"),
                    "canal": prov.get("canal"),
                    "url_fonte": f"https://www.youtube.com/watch?v={match['video_id']}",
                    "licenca": prov.get("licenca"),
                })
    return audio


# ---------------------------------------------------------------------------
# Montagem do JSON diário
# ---------------------------------------------------------------------------


def _executar(nome: str, status: dict[str, str], fn: Callable[[], Any]) -> Any:
    try:
        resultado = fn()
        status[nome] = "ok"
        return resultado
    except FonteIndisponivel as exc:
        status[nome] = f"indisponivel: {exc}"
        log.warning("[%s] %s", nome, exc)
    except Exception as exc:  # noqa: BLE001 — uma fonte nunca derruba as demais
        status[nome] = f"erro: {type(exc).__name__}: {exc}"
        log.exception("[%s] erro inesperado", nome)
    return None


def montar_dia(d: date, cliente: ClienteHttp, fontes: set[str]) -> dict[str, Any]:
    cal = calendario.calcular(d)
    status: dict[str, str] = {}

    cnbb = _executar("cnbb", status, lambda: coletar_cnbb(cliente, d)) if "cnbb" in fontes else None
    vaticano = _executar("vaticano", status, lambda: coletar_vaticano(cliente, d)) if "vaticano" in fontes else None
    # Reserva: se a CNBB falhar, usa as leituras da página do Vatican News (sem o Salmo).
    leituras_vatican = None
    if cnbb is None and "vaticano" in fontes:
        leituras_vatican = _executar("leituras_vaticano", status, lambda: coletar_vaticano_leituras(cliente, d))
    leituras_fonte = cnbb or leituras_vatican

    acervo_patristico = carregar_json(BASE_DIR / "patristic.json")
    ref_evangelho = ((leituras_fonte or {}).get("evangelho") or {}).get("referencia")
    patristica = selecionar_patristica(ref_evangelho, cal.tempo, acervo_patristico)
    status["patristica"] = "ok" if patristica else "vazio"

    config_audio = carregar_json(BASE_DIR / "audio_sources.json")
    salmo_obj = (cnbb or {}).get("salmo") or {}
    audio = resolver_audio(
        d,
        cal,
        salmo_obj.get("referencia"),
        config_audio,
        salmo_refrao=salmo_obj.get("refrao"),
        cliente=cliente,
    )

    calendario_dict = cal.to_dict()
    if cnbb and cnbb.get("cor"):
        calendario_dict["cor"] = cnbb["cor"]
        calendario_dict["cor_origem"] = "cnbb"
    else:
        calendario_dict["cor_origem"] = "calculada"
    if cnbb and cnbb.get("celebracao") and len(cnbb["celebracao"]) < 160:
        calendario_dict["celebracao"] = cnbb["celebracao"]

    leituras = None
    if leituras_fonte:
        nome_fonte = "CNBB" if cnbb else "Vatican News"
        leituras = {k: leituras_fonte.get(k) for k in ("primeira_leitura", "salmo", "segunda_leitura", "evangelho")}
        for leitura in leituras.values():
            if leitura:
                leitura["fonte"] = nome_fonte

    fontes_usadas = [f for f, usado in ((FONTE_CNBB, cnbb), (FONTE_VATICANO, vaticano or leituras_vatican),
                                         (FONTE_PATRISTICA, patristica)) if usado]
    return {
        "schema_version": SCHEMA_VERSION,
        "data": d.isoformat(),
        "gerado_em": datetime.now(TZ).isoformat(timespec="seconds"),
        "calendario": calendario_dict,
        "leituras": leituras,
        "audio": audio,
        "homilias": {
            "vaticano": vaticano,
            "cnbb": (cnbb or {}).get("reflexao"),
            "patristica": patristica,
        },
        "fontes": fontes_usadas,
        "url_original": (leituras_fonte or {}).get("url"),
        "status": status,
    }


def qualidade(doc: dict[str, Any]) -> int:
    """Pontuação simples para não sobrescrever um JSON bom por um pior."""
    pontos = 0
    if doc.get("leituras"):
        pontos += sum(10 for v in doc["leituras"].values() if v)
    homilias = doc.get("homilias") or {}
    pontos += 5 if homilias.get("vaticano") else 0
    pontos += 3 if homilias.get("cnbb") else 0
    pontos += 1 if homilias.get("patristica") else 0
    return pontos


# Áudios neurais gravados por ``generate_audio.py`` no JSON do dia: (url, hash, roteiro).
AUDIO_GERADO = (
    ("liturgia_audio_url", "liturgia_audio_hash", gerador_audio.build_liturgy_script),
    ("homilia_audio_url", "homilia_audio_hash", gerador_audio.build_homily_script),
)


def preservar_audio_gerado(doc: dict[str, Any], anterior: dict[str, Any]) -> list[str]:
    """Copia de ``anterior`` os áudios neurais cujo roteiro não mudou.

    ``montar_dia`` recria o bloco ``audio`` do zero; sem isto, se o passo
    ``generate_audio.py`` falhar (``continue-on-error``), os dias reprocessados
    perderiam as URLs de áudio. O hash do roteiro garante que o MP3 antigo ainda
    corresponde ao texto novo — se o texto mudou, o slot fica vazio para ser
    regerado (e o app usa a voz local enquanto isso). Retorna os campos copiados.
    """
    audio_ant = anterior.get("audio") or {}
    audio = doc.setdefault("audio", {})
    copiados: list[str] = []
    for url_key, hash_key, roteiro in AUDIO_GERADO:
        url, hash_ant = audio_ant.get(url_key), audio_ant.get(hash_key)
        if not url or not hash_ant or audio.get(url_key):
            continue
        if gerador_audio.script_hash(roteiro(doc)) != hash_ant:
            continue
        audio[url_key], audio[hash_key] = url, hash_ant
        creditos = [c for c in audio.get("creditos") or [] if isinstance(c, dict) and c.get("campo") != url_key]
        creditos += [c for c in audio_ant.get("creditos") or [] if isinstance(c, dict) and c.get("campo") == url_key]
        audio["creditos"] = creditos
        copiados.append(url_key)
    return copiados


def salvar(doc: dict[str, Any], destino: Path, forcar: bool = False) -> bool:
    destino.parent.mkdir(parents=True, exist_ok=True)
    if destino.exists():
        try:
            anterior = json.loads(destino.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            anterior = None
        if isinstance(anterior, dict):
            if not forcar and qualidade(anterior) > qualidade(doc):
                log.info("Mantendo %s (versão existente é mais completa)", destino.name)
                return False
            if copiados := preservar_audio_gerado(doc, anterior):
                log.info("%s: áudio gerado preservado (%s)", destino.name, ", ".join(copiados))
    tmp = destino.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tmp.replace(destino)
    return True


def atualizar_indice(pasta: Path, manter_dias: int = 400) -> dict[str, Any]:
    """Gera ``index.json`` e remove arquivos muito antigos."""
    hoje = datetime.now(TZ).date()
    datas: list[str] = []
    for arquivo in sorted(pasta.glob("????-??-??.json")):
        try:
            d = date.fromisoformat(arquivo.stem)
        except ValueError:
            continue
        if (hoje - d).days > manter_dias:
            arquivo.unlink()
            continue
        datas.append(arquivo.stem)
    indice = {
        "schema_version": SCHEMA_VERSION,
        "atualizado_em": datetime.now(TZ).isoformat(timespec="seconds"),
        "ultima_data": datas[-1] if datas else None,
        "datas": datas,
        "fontes": [FONTE_CNBB, FONTE_VATICANO, FONTE_PATRISTICA],
    }
    (pasta / "index.json").write_text(json.dumps(indice, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return indice


def datas_alvo(inicio: date, dias: int) -> Iterable[date]:
    return (inicio + timedelta(days=i) for i in range(dias))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Coletor diário do Via Sacra")
    parser.add_argument("--date", type=date.fromisoformat, help="Data inicial (AAAA-MM-DD). Padrão: hoje (BRT)")
    parser.add_argument("--days", type=int, default=1, help="Quantidade de dias a partir da data inicial")
    parser.add_argument("--out", type=Path, default=BASE_DIR.parent / "data", help="Pasta de saída")
    parser.add_argument("--sources", default="cnbb,vaticano", help="Fontes online: cnbb,vaticano")
    parser.add_argument("--force", action="store_true", help="Sobrescrever mesmo se a versão existente for melhor")
    parser.add_argument("--ignore-robots", action="store_true", help="NÃO respeitar robots.txt (apenas testes)")
    parser.add_argument("--offline-html", action="append", default=[], metavar="FONTE=ARQUIVO",
                        help="Usa HTML local em vez da rede (cnbb, vatican, vatican_rss)")
    parser.add_argument("--strict", action="store_true", help="Sair com erro se a CNBB falhar")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format="%(asctime)s %(levelname)s %(name)s: %(message)s")

    offline = dict(item.split("=", 1) for item in args.offline_html)
    cliente = ClienteHttp(respeitar_robots=not args.ignore_robots, offline_html=offline)
    fontes = {f.strip() for f in args.sources.split(",") if f.strip()}
    inicio = args.date or datetime.now(TZ).date()
    pasta = args.out / "liturgia"

    falhas_cnbb = 0
    for d in datas_alvo(inicio, args.days):
        log.info("Coletando %s…", d.isoformat())
        doc = montar_dia(d, cliente, fontes)
        if doc["status"].get("cnbb") != "ok":
            falhas_cnbb += 1
        gravado = salvar(doc, pasta / f"{d.isoformat()}.json", forcar=args.force)
        log.info("%s %s — status: %s", "Salvo" if gravado else "Ignorado", d.isoformat(), doc["status"])

    indice = atualizar_indice(pasta)
    log.info("Índice atualizado: %d datas (última: %s)", len(indice["datas"]), indice["ultima_data"])
    if args.strict and falhas_cnbb:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
