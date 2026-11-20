"""Calendário litúrgico: casos multi-ano (2023–2031) e paridade com o app Dart.

O fixture ``app/test/fixtures/liturgical_calendar_parity.json`` é lido também por
``app/test/liturgical_calendar_test.dart``: se Python e Dart divergirem em
qualquer dia, um dos dois testes falha. Para regenerá-lo após uma mudança
intencional nas regras: ``python scraper/tests/test_liturgical_calendar.py``.
"""

from __future__ import annotations

import json
import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import liturgical_calendar as cal  # noqa: E402

FIXTURE = Path(__file__).resolve().parents[2] / "app/test/fixtures/liturgical_calendar_parity.json"
ANOS = range(2023, 2032)


def linha(d: date) -> str:
    x = cal.calcular(d)
    semana = "" if x.semana is None else x.semana
    return (
        f"{x.data}|{x.tempo}|{semana}|{x.cor}|{x.celebracao}|{x.grau}|"
        f"{x.ciclo_dominical}|{x.ciclo_ferial}|{x.misterios_do_dia}"
    )


def fnv1a(texto: str) -> str:
    """FNV-1a de 32 bits (mesma implementação no teste Dart)."""
    h = 0x811C9DC5
    for b in texto.encode("utf-8"):
        h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
    return f"{h:08x}"


def impressao_digital(ano: int) -> str:
    d, linhas = date(ano, 1, 1), []
    while d.year == ano:
        linhas.append(linha(d))
        d += timedelta(days=1)
    return fnv1a("\n".join(linhas))


def test_paridade_com_fixture_compartilhado():
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    assert {str(a): impressao_digital(a) for a in ANOS} == fixture["anos"]
    for caso in fixture["casos"]:
        x = cal.calcular(date.fromisoformat(caso["data"]))
        assert x.celebracao == caso["celebracao"], caso
        assert x.semana == caso.get("semana"), caso


def test_semana_do_tempo_comum_com_batismo_na_segunda():
    # 2024: Epifania 7/1, Batismo segunda 8/1, 2º Domingo 14/1.
    assert cal.batismo_do_senhor(2024) == date(2024, 1, 8)
    assert cal.calcular(date(2024, 1, 9)).semana == 1
    assert cal.calcular(date(2024, 1, 14)).celebracao == "2º Domingo do Tempo Comum"
    assert cal.calcular(date(2024, 1, 15)).celebracao == "Segunda-feira da 2ª Semana do Tempo Comum"
    # Anos com Batismo no domingo continuam iguais.
    assert cal.calcular(date(2026, 1, 12)).celebracao == "Segunda-feira da 1ª Semana do Tempo Comum"


def test_todos_os_santos_num_sabado_nao_apaga_finados():
    assert cal.calcular(date(2025, 11, 1)).celebracao == "Todos os Santos"
    assert cal.calcular(date(2025, 11, 2)).celebracao == "Comemoração de Todos os Fiéis Defuntos"
    assert cal.calcular(date(2026, 11, 1)).celebracao == "Todos os Santos"  # domingo
    assert cal.calcular(date(2027, 11, 7)).celebracao == "Todos os Santos"  # transferida


def test_sagrada_familia():
    assert cal.sagrada_familia(2025) == date(2025, 12, 28)  # prevalece sobre os Inocentes
    assert cal.sagrada_familia(2022) == date(2022, 12, 30)  # Natal num domingo
    assert cal.calcular(date(2025, 12, 28)).cor == "branco"


def test_transferencias_das_normas_universais():
    assert cal.sao_jose(2023) == date(2023, 3, 20)  # domingo da Quaresma
    assert cal.sao_jose(2008) == date(2008, 3, 15)  # Semana Santa → sábado antes de Ramos
    assert cal.anunciacao(2024) == date(2024, 4, 8)  # Segunda-feira Santa
    assert cal.anunciacao(2026) == date(2026, 3, 25)
    assert cal.imaculada_conceicao(2024) == date(2024, 12, 9)
    assert cal.calcular(date(2023, 3, 19)).celebracao == "4º Domingo da Quaresma"


def test_calendario_continuo_2023_2031():
    for ano in ANOS:
        d = date(ano, 1, 1)
        while d.year == ano:
            x = cal.calcular(d)
            if x.tempo == "comum":
                assert 1 <= x.semana <= 34, x
            d += timedelta(days=1)


CASOS = [
    "2023-01-16", "2024-01-15", "2029-01-15", "2030-01-14",
    "2024-01-09", "2026-01-12", "2025-11-01", "2025-11-02", "2031-11-01",
    "2031-11-02", "2025-12-28", "2022-12-30", "2023-03-20", "2024-04-08",
    "2027-04-05", "2024-12-09", "2026-11-19", "2026-11-22",
]

if __name__ == "__main__":  # regenera o fixture compartilhado
    dados = {
        "_comentario": "Gerado por scraper/tests/test_liturgical_calendar.py — não editar à mão.",
        "anos": {str(a): impressao_digital(a) for a in ANOS},
        "casos": [
            {"data": c, "celebracao": cal.calcular(date.fromisoformat(c)).celebracao,
             "semana": cal.calcular(date.fromisoformat(c)).semana}
            for c in CASOS
        ],
    }
    FIXTURE.write_text(json.dumps(dados, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Fixture atualizado: {FIXTURE}")
