# Direitos autorais e política de conteúdo

O **código** do Via Sacra é GPL-3.0. Os **conteúdos** pertencem a seus titulares e não são
cobertos pela GPL. O projeto não tem fins lucrativos e atribui todas as fontes na interface.

| Conteúdo | Situação | Como o projeto usa |
|---|---|---|
| Leituras (CNBB) | © CNBB / tradução oficial | Coletadas diariamente, sem alteração, com "Fonte: CNBB" e link. Uso devocional não comercial. **Recomenda-se obter autorização formal da CNBB** antes da publicação em lojas. |
| Homilias do Papa (Vatican News) | © Libreria Editrice Vaticana / Dicastério para a Comunicação | Reprodução pastoral não comercial com citação e link para o original; quando apenas o RSS está disponível, só o resumo é exibido. |
| Santos Padres | Domínio público | Traduções livres do projeto (`scraper/patristic.json`), revisáveis pela comunidade. |
| Arte sacra | Domínio público / CC0 | Somente obras de artistas falecidos há mais de 70 anos, com licença verificada automaticamente no Commons (`tool/fetch_sacred_art.py`). |
| Catecismo (CIC) | © Libreria Editrice Vaticana | O repositório inclui apenas o **índice** (dado factual); o app abre o texto oficial no vatican.va. O usuário pode importar no aparelho um `.json` próprio (importador modular). |
| Catecismo Maior de São Pio X | Original (1905) em domínio público; **tradução portuguesa não oficial** (Internet Archive), licença em verificação | Embutido provisoriamente, sem as notas do tradutor, até encontrarmos uma tradução comprovadamente em domínio público (ver [#29](https://github.com/julia-flima/ViaSacra/issues/29)). Gerado por `scripts/build_sao_pio_x.py`. |
| Orações tradicionais | Domínio público | Textos litúrgicos tradicionais. |
| Bíblia — Vulgata Clementina, Douay-Rheims | Domínio público | Embutidas (texto via github.com/mborders/vulgata, código MIT). |
| Bíblia — Figueiredo | Domínio público | Pode ser embutida assim que houver texto-fonte digitalizado confiável. |
| Bíblia — Matos Soares | © até 31/12/2027 (autor †1957) | Domínio público a partir de 01/01/2028. |
| Bíblia — CNBB, Ave-Maria, Jerusalém, Pastoral | © das editoras | **Nunca** embutidas nem indicadas; apenas importação local pelo usuário. Pedidos de autorização em `docs/autorizacoes/`. Cópias não autorizadas encontradas na internet (por exemplo, repositórios com "Ave-Maria em JSON") **não** devem ser usadas. |
| Fontes tipográficas | SIL OFL / Apache-2.0 / Bitstream Vera | Ver `app/assets/fonts/README.md`. |
| Citações bíblicas nos mistérios | Tradução livre breve do projeto | — |

## Boas práticas do scraper

User-Agent identificável com link para o projeto, respeito a `robots.txt`, intervalo mínimo de 2 s
por host, no máximo ~15 requisições por dia, sem contornar bloqueios.

## Solicitação de remoção

Titulares podem pedir ajuste ou remoção abrindo uma issue ou contatando a mantenedora. O
atendimento é imediato: basta remover a fonte de `scraper.py` e o conteúdo some no dia seguinte.

## Autorizações obtidas

_(registre aqui: titular, data, escopo, referência do documento)_
