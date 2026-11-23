# Direitos autorais e política de conteúdo

O **código** do Via Sacra é GPL-3.0. Os **conteúdos** pertencem a seus titulares e não são
cobertos pela GPL. O projeto não tem fins lucrativos e atribui todas as fontes na interface.

| Conteúdo | Situação | Como o projeto usa |
|---|---|---|
| Leituras (CNBB) | © CNBB / tradução oficial | Coletadas diariamente, sem alteração, com "Fonte: CNBB" e link. Uso devocional não comercial. **Recomenda-se obter autorização formal da CNBB** antes da publicação em lojas. |
| Ordinário da Missa (Missal Romano, 3ª ed.) | © CNBB / tradução oficial | Só as respostas do povo e deixas curtas do padre, em `app/assets/data/ordinario_missa.json`, com "© CNBB" na tela. Embutido por decisão do projeto enquanto o app não é distribuído; autorização pedida em `docs/autorizacoes/carta-cnbb.md`. Trechos marcados com `conferir` ainda precisam ser checados no Missal impresso. |
| Homilias do Papa (Vatican News) | © Libreria Editrice Vaticana / Dicastério para a Comunicação | Reprodução pastoral não comercial com citação e link para o original; quando apenas o RSS está disponível, só o resumo é exibido. |
| Santos Padres | Domínio público | Traduções livres do projeto (`scraper/patristic.json`), revisáveis pela comunidade. |
| Arte sacra | Domínio público / CC0 | Somente obras de artistas falecidos há mais de 70 anos, com licença verificada automaticamente no Commons (`tool/fetch_sacred_art.py`). |
| Catecismo (CIC) | © Libreria Editrice Vaticana | O repositório inclui apenas o **índice** (dado factual); o app abre o texto oficial no vatican.va. O usuário pode importar no aparelho um `.json` próprio (importador modular). |
| Catecismo Maior de São Pio X | Original (Tipografia Vaticana, 1905) em domínio público | Tradução do italiano feita pelo projeto e dedicada ao domínio público (CC0), revisável pela comunidade em `scripts/data/sao_pio_x_1905.json` (italiano ao lado). Gerado por `scripts/build_sao_pio_x.py`. |
| Orações tradicionais | Domínio público | Textos litúrgicos tradicionais (fonte única: `tool/build_prayers.py`). Latim de São Tomás, São Boaventura e das ladainhas conferido com edições publicadas; trechos em português que faltavam traduzidos pelo projeto. |
| A Imitação de Cristo | Original em domínio público; tradução © 2023 Valdemar Teodoro Editor | "Toda cópia e divulgação são permitidas, desde que citada a fonte." Permissão de cópia com citação (não é licença livre), mantida por decisão do projeto, com a fonte citada no app. Gerado por `scripts/build_imitacao.py`. |
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
