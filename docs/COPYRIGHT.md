# Direitos autorais e política de conteúdo

O **código** do Via Sacra é GPL-3.0. Os **conteúdos** pertencem a seus titulares e não são
cobertos pela GPL. O projeto não tem fins lucrativos e atribui todas as fontes na interface.

| Conteúdo | Situação | Como o projeto usa |
|---|---|---|
| Leituras (CNBB) | © CNBB / tradução oficial | Coletadas diariamente, sem alteração, com "Fonte: CNBB" e link. Uso devocional não comercial. **Recomenda-se obter autorização formal da CNBB** antes da publicação em lojas. |
| Homilias do Papa (Vatican News) | © Libreria Editrice Vaticana / Dicastério para a Comunicação | Reprodução pastoral não comercial com citação e link para o original; quando apenas o RSS está disponível, só o resumo é exibido. |
| Santos Padres | Domínio público | Traduções livres do projeto (`scraper/patristic.json`), revisáveis pela comunidade. |
| Arte sacra | Domínio público / CC0 | Somente obras de artistas falecidos há mais de 70 anos, com licença verificada automaticamente no Commons (`tool/fetch_sacred_art.py`). |
| Catecismo (CIC) | © Libreria Editrice Vaticana | O repositório inclui apenas o **índice** (dado factual) e 5 trechos breves de exemplo (citação, Lei 9.610/98, art. 46, III). O texto integral só entra com autorização por escrito, via `tool/import_catechism.py`. |
| Orações tradicionais | Domínio público | Textos litúrgicos tradicionais. |
| Citações bíblicas nos mistérios | Tradução livre breve do projeto | — |

## Boas práticas do scraper

User-Agent identificável com link para o projeto, respeito a `robots.txt`, intervalo mínimo de 2 s
por host, no máximo ~15 requisições por dia, sem contornar bloqueios.

## Solicitação de remoção

Titulares podem pedir ajuste ou remoção abrindo uma issue ou contatando a mantenedora. O
atendimento é imediato: basta remover a fonte de `scraper.py` e o conteúdo some no dia seguinte.

## Autorizações obtidas

_(registre aqui: titular, data, escopo, referência do documento)_
