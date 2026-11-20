"""Calendário litúrgico (Rito Romano, adaptações do Brasil) calculado localmente.

Serve como *fallback* determinístico quando a fonte (CNBB) não informa o
Tempo Litúrgico, a semana ou a cor do dia, e é espelhado no app em
``app/lib/core/liturgical_calendar.dart`` para funcionar 100% offline.

Regras do Brasil consideradas:
- Epifania: domingo entre 2 e 8 de janeiro.
- Ascensão: transferida para o 7º Domingo da Páscoa.
- São Pedro e São Paulo, Assunção de Nossa Senhora e Todos os Santos:
  transferidos para o domingo seguinte quando não caem em domingo — exceto
  Todos os Santos num sábado, que fica no dia 1º (domingo 2/11 é Finados).
- São José, Anunciação e Imaculada Conceição transferidos conforme as Normas
  Universais do Ano Litúrgico (n. 60) quando coincidem com domingos/Semana Santa.
- Nossa Senhora Aparecida (12/10): Solenidade.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import date, timedelta

DIAS_SEMANA = [
    "Segunda-feira",
    "Terça-feira",
    "Quarta-feira",
    "Quinta-feira",
    "Sexta-feira",
    "Sábado",
    "Domingo",
]

# Mistérios do Rosário por dia da semana (date.weekday(): 0 = segunda)
MISTERIOS_POR_DIA = [
    "gozosos",  # segunda
    "dolorosos",  # terça
    "gloriosos",  # quarta
    "luminosos",  # quinta
    "dolorosos",  # sexta
    "gozosos",  # sábado
    "gloriosos",  # domingo
]

ORDINAIS = {
    1: "1º", 2: "2º", 3: "3º", 4: "4º", 5: "5º", 6: "6º", 7: "7º",
}


@dataclass(frozen=True)
class DiaLiturgico:
    data: str
    dia_semana: str
    tempo: str  # advento | natal | quaresma | triduo | pascoa | comum
    tempo_nome: str
    semana: int | None
    cor: str  # verde | roxo | branco | vermelho | rosa
    celebracao: str
    grau: str  # solenidade | festa | memoria | domingo | feria
    ciclo_dominical: str  # A | B | C
    ciclo_ferial: str  # I | II
    misterios_do_dia: str

    def to_dict(self) -> dict:
        return asdict(self)


def pascoa(ano: int) -> date:
    """Domingo de Páscoa (algoritmo gregoriano anônimo / Meeus-Jones-Butcher)."""
    a = ano % 19
    b, c = divmod(ano, 100)
    d, e = divmod(b, 4)
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = divmod(c, 4)
    ell = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * ell) // 451
    mes = (h + ell - 7 * m + 114) // 31
    dia = ((h + ell - 7 * m + 114) % 31) + 1
    return date(ano, mes, dia)


def _domingo_em_ou_apos(d: date) -> date:
    return d + timedelta(days=(6 - d.weekday()) % 7)


def inicio_advento(ano: int) -> date:
    """1º Domingo do Advento: 4 domingos antes do Natal."""
    natal = date(ano, 12, 25)
    domingo_antes_natal = natal - timedelta(days=(natal.weekday() + 1) % 7 or 7)
    return domingo_antes_natal - timedelta(weeks=3)


def epifania(ano: int) -> date:
    return _domingo_em_ou_apos(date(ano, 1, 2))


def batismo_do_senhor(ano: int) -> date:
    ep = epifania(ano)
    if ep.day >= 7:  # Epifania em 7 ou 8 de janeiro → Batismo na segunda-feira
        return ep + timedelta(days=1)
    return ep + timedelta(days=7)


def _transferida_para_domingo(d: date) -> date:
    return _domingo_em_ou_apos(d)


def sao_jose(ano: int) -> date:
    """19/3; domingo da Quaresma → segunda; Semana Santa → sábado antes de Ramos."""
    d, p = date(ano, 3, 19), pascoa(ano)
    ramos = p - timedelta(days=7)
    if ramos <= d < p:
        return ramos - timedelta(days=1)
    return d + timedelta(days=1) if d.weekday() == 6 else d


def anunciacao(ano: int) -> date:
    """25/3; Semana Santa/Oitava da Páscoa → segunda após o 2º Domingo da Páscoa."""
    d, p = date(ano, 3, 25), pascoa(ano)
    if p - timedelta(days=7) <= d <= p + timedelta(days=7):
        return p + timedelta(days=8)
    return d + timedelta(days=1) if d.weekday() == 6 else d


def imaculada_conceicao(ano: int) -> date:
    """8/12; num domingo do Advento → segunda-feira."""
    d = date(ano, 12, 8)
    return d + timedelta(days=1) if d.weekday() == 6 else d


def todos_os_santos(ano: int) -> date:
    """Domingo seguinte a 1º/11, exceto se 1º/11 for sábado (Diretório Litúrgico CNBB 2025)."""
    d = date(ano, 11, 1)
    return d if d.weekday() == 5 else _domingo_em_ou_apos(d)


def sagrada_familia(ano: int) -> date:
    """Domingo na Oitava do Natal ou, se não houver, 30/12."""
    domingo = _domingo_em_ou_apos(date(ano, 12, 26))
    return domingo if domingo.year == ano else date(ano, 12, 30)


def ciclos(d: date) -> tuple[str, str]:
    """Retorna (ciclo dominical A/B/C, ciclo ferial I/II) do ano litúrgico de ``d``."""
    ano_fim = d.year + 1 if d >= inicio_advento(d.year) else d.year
    dominical = {1: "A", 2: "B", 0: "C"}[ano_fim % 3]
    ferial = "I" if ano_fim % 2 == 1 else "II"
    return dominical, ferial


def _celebracoes_fixas(d: date) -> tuple[str, str, str] | None:
    """(nome, cor, grau) para solenidades/festas de data fixa ou transferidas no Brasil."""
    ano = d.year
    fixas: dict[date, tuple[str, str, str]] = {
        date(ano, 1, 1): ("Santa Maria, Mãe de Deus", "branco", "solenidade"),
        date(ano, 2, 2): ("Apresentação do Senhor", "branco", "festa"),
        date(ano, 2, 22): ("Cátedra de São Pedro", "branco", "festa"),
        sao_jose(ano): ("São José, Esposo da Virgem Maria", "branco", "solenidade"),
        anunciacao(ano): ("Anunciação do Senhor", "branco", "solenidade"),
        date(ano, 6, 24): ("Natividade de São João Batista", "branco", "solenidade"),
        date(ano, 8, 6): ("Transfiguração do Senhor", "branco", "festa"),
        date(ano, 9, 14): ("Exaltação da Santa Cruz", "vermelho", "festa"),
        date(ano, 10, 12): ("Nossa Senhora da Conceição Aparecida, Padroeira do Brasil", "branco", "solenidade"),
        date(ano, 11, 2): ("Comemoração de Todos os Fiéis Defuntos", "roxo", "solenidade"),
        imaculada_conceicao(ano): ("Imaculada Conceição de Nossa Senhora", "branco", "solenidade"),
        date(ano, 12, 25): ("Natal do Senhor", "branco", "solenidade"),
        date(ano, 12, 26): ("Santo Estêvão, primeiro mártir", "vermelho", "festa"),
        date(ano, 12, 27): ("São João, Apóstolo e Evangelista", "branco", "festa"),
        date(ano, 12, 28): ("Santos Inocentes, mártires", "vermelho", "festa"),
        _transferida_para_domingo(date(ano, 6, 29)): ("São Pedro e São Paulo, Apóstolos", "vermelho", "solenidade"),
        _transferida_para_domingo(date(ano, 8, 15)): ("Assunção de Nossa Senhora", "branco", "solenidade"),
        todos_os_santos(ano): ("Todos os Santos", "branco", "solenidade"),
        epifania(ano): ("Epifania do Senhor", "branco", "solenidade"),
        batismo_do_senhor(ano): ("Batismo do Senhor", "branco", "festa"),
    }
    # Festa do Senhor: prevalece sobre Santo Estêvão, São João e Inocentes.
    fixas[sagrada_familia(ano)] = ("Sagrada Família de Jesus, Maria e José", "branco", "festa")
    return fixas.get(d)


def _celebracoes_moveis(d: date) -> tuple[str, str, str] | None:
    p = pascoa(d.year)
    moveis: dict[date, tuple[str, str, str]] = {
        p - timedelta(days=46): ("Quarta-feira de Cinzas", "roxo", "feria"),
        p - timedelta(days=7): ("Domingo de Ramos e da Paixão do Senhor", "vermelho", "domingo"),
        p - timedelta(days=3): ("Quinta-feira Santa — Ceia do Senhor", "branco", "solenidade"),
        p - timedelta(days=2): ("Sexta-feira Santa — Paixão do Senhor", "vermelho", "solenidade"),
        p - timedelta(days=1): ("Sábado Santo — Vigília Pascal", "branco", "solenidade"),
        p: ("Domingo de Páscoa da Ressurreição do Senhor", "branco", "solenidade"),
        p + timedelta(days=7): ("2º Domingo da Páscoa — Divina Misericórdia", "branco", "solenidade"),
        p + timedelta(days=42): ("Ascensão do Senhor", "branco", "solenidade"),
        p + timedelta(days=49): ("Domingo de Pentecostes", "vermelho", "solenidade"),
        p + timedelta(days=56): ("Santíssima Trindade", "branco", "solenidade"),
        p + timedelta(days=60): ("Santíssimo Corpo e Sangue de Cristo", "branco", "solenidade"),
        p + timedelta(days=68): ("Sagrado Coração de Jesus", "branco", "solenidade"),
        inicio_advento(d.year) - timedelta(days=7): (
            "Nosso Senhor Jesus Cristo, Rei do Universo", "branco", "solenidade"),
    }
    return moveis.get(d)


def calcular(d: date) -> DiaLiturgico:
    ano = d.year
    p = pascoa(ano)
    cinzas = p - timedelta(days=46)
    pentecostes = p + timedelta(days=49)
    advento = inicio_advento(ano)
    batismo_ano = batismo_do_senhor(ano)
    domingo = d.weekday() == 6
    dominical, ferial = ciclos(d)

    # ---- Tempo e semana -------------------------------------------------
    if d >= advento:
        tempo = "advento" if d < date(ano, 12, 25) else "natal"
    elif d <= batismo_ano:
        tempo = "natal"
    elif d < cinzas:
        tempo = "comum"
    elif d < p - timedelta(days=3):
        tempo = "quaresma"
    elif d < p:
        tempo = "triduo"
    elif d <= pentecostes:
        tempo = "pascoa"
    else:
        tempo = "comum"

    semana: int | None = None
    if tempo == "advento":
        semana = (d - advento).days // 7 + 1
    elif tempo == "quaresma":
        if d < cinzas + timedelta(days=4):
            semana = 0  # quarta a sábado depois das Cinzas
        else:
            semana = (d - (cinzas + timedelta(days=4))).days // 7 + 1
    elif tempo == "pascoa":
        semana = (d - p).days // 7 + 1
    elif tempo == "comum":
        if d < cinzas:
            # O 2º Domingo é o primeiro depois do Batismo; cada semana começa no domingo.
            segundo_domingo = _domingo_em_ou_apos(batismo_ano + timedelta(days=1))
            domingo_da_semana = d - timedelta(days=(d.weekday() + 1) % 7)
            semana = 1 if d < segundo_domingo else (domingo_da_semana - segundo_domingo).days // 7 + 2
        else:
            cristo_rei = advento - timedelta(days=7)
            # 34ª semana começa no domingo de Cristo Rei
            semana = 34 - (cristo_rei - d + timedelta(days=6)).days // 7

    nomes_tempo = {
        "advento": "Tempo do Advento",
        "natal": "Tempo do Natal",
        "quaresma": "Tempo da Quaresma",
        "triduo": "Tríduo Pascal",
        "pascoa": "Tempo Pascal",
        "comum": "Tempo Comum",
    }

    # ---- Cor --------------------------------------------------------------
    cor = {
        "advento": "roxo",
        "natal": "branco",
        "quaresma": "roxo",
        "triduo": "branco",
        "pascoa": "branco",
        "comum": "verde",
    }[tempo]
    if tempo == "advento" and domingo and semana == 3:
        cor = "rosa"  # Gaudete
    if tempo == "quaresma" and domingo and semana == 4:
        cor = "rosa"  # Laetare

    # ---- Celebração -------------------------------------------------------
    dia_semana = DIAS_SEMANA[d.weekday()]
    celebracao = _descricao_padrao(tempo, semana, dia_semana, domingo)
    grau = "domingo" if domingo else "feria"

    movel = _celebracoes_moveis(d)
    fixa = _celebracoes_fixas(d)
    if movel:
        celebracao, cor, grau = movel
    elif fixa and _fixa_prevalece(fixa, tempo, domingo, d, p):
        celebracao, cor, grau = fixa

    return DiaLiturgico(
        data=d.isoformat(),
        dia_semana=dia_semana,
        tempo=tempo,
        tempo_nome=nomes_tempo[tempo],
        semana=semana,
        cor=cor,
        celebracao=celebracao,
        grau=grau,
        ciclo_dominical=dominical,
        ciclo_ferial=ferial,
        misterios_do_dia=MISTERIOS_POR_DIA[d.weekday()],
    )


FESTAS_DO_SENHOR = {"Apresentação do Senhor", "Transfiguração do Senhor", "Exaltação da Santa Cruz"}


def _fixa_prevalece(fixa: tuple[str, str, str], tempo: str, domingo: bool, d: date, p: date) -> bool:
    """Tabela simplificada de precedência (Normas Universais do Ano Litúrgico, n. 59-60)."""
    nome, _cor, grau = fixa
    if tempo == "triduo" or (p - timedelta(days=7)) <= d <= (p + timedelta(days=7)):
        return False  # Semana Santa e Oitava da Páscoa
    if domingo and tempo in {"advento", "quaresma", "pascoa"}:
        return False  # domingos desses tempos prevalecem (simplificação)
    if domingo and tempo == "comum":
        return grau == "solenidade" or nome in FESTAS_DO_SENHOR
    return True


def _descricao_padrao(tempo: str, semana: int | None, dia_semana: str, domingo: bool) -> str:
    if tempo == "triduo":
        return "Tríduo Pascal"
    if tempo == "natal":
        return "Domingo do Tempo do Natal" if domingo else f"{dia_semana} do Tempo do Natal"
    if tempo == "quaresma" and semana == 0:
        return f"{dia_semana} depois das Cinzas"
    nome = {
        "advento": "do Advento",
        "quaresma": "da Quaresma",
        "pascoa": "da Páscoa",
        "comum": "do Tempo Comum",
    }[tempo]
    if domingo:
        return f"{semana}º Domingo {nome}"
    return f"{dia_semana} da {semana}ª Semana {nome}"


if __name__ == "__main__":  # pragma: no cover - utilitário manual
    import json
    import sys

    alvo = date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 else date.today()
    print(json.dumps(calcular(alvo).to_dict(), ensure_ascii=False, indent=2))
