# Bíblia Sagrada — cânon católico e traduções modulares

## Cânon (73 livros)

46 livros do Antigo Testamento, incluindo os **deuterocanônicos** (Tobias, Judite, 1–2 Macabeus,
Sabedoria, Eclesiástico e Baruc, além das partes gregas de Ester e Daniel), e 27 do Novo Testamento.
A ordem segue as Bíblias católicas brasileiras. A fonte única dos ids e abreviações é
[`tool/bible/canon.py`](../tool/bible/canon.py), que gera `app/assets/bible/canon.json` e
`app/lib/data/bible/bible_canon.dart` (um teste confere que os dois estão iguais).

| id | Abrev. | id | Abrev. | id | Abrev. |
|---|---|---|---|---|---|
| gn | Gn | jb | Jó (≠ `jo`, João) | sl | Sl |
| 1sm | 1Sm | eclo | Eclo | 1cor | 1Cor |

## Traduções

| Tradução | Idioma | Situação | No app |
|---|---|---|---|
| Vulgata Clementina | latim | Domínio público | **Embutida** |
| Douay-Rheims (Challoner) | inglês | Domínio público | **Embutida** |
| Pe. Antônio Pereira de Figueiredo | português | Domínio público (†1797) | Conversor pronto (`--generic`); falta o texto-fonte digitalizado |
| Pe. Matos Soares | português | Domínio público a partir de **1º/01/2028** (†1957; regra de vida + 70 anos) | Importação local até lá |
| CNBB · Ave-Maria · Jerusalém · Pastoral | português | © das editoras | Só importação local, com autorização do titular |

Os pedidos de autorização às editoras estão em [`docs/autorizacoes/`](autorizacoes/).

**Por que as traduções modernas não vêm no app:** distribuir texto protegido, mesmo de graça, exige
autorização do titular. Sem ela, o F-Droid recusa o app e o repositório fica sujeito a remoção. O
Via Sacra **não fornece, não hospeda e não indica** arquivos dessas traduções. O app apenas lê um
módulo que o próprio usuário escolhe e guarda tudo no aparelho dele.

## Formato do módulo (`viasacra-biblia`, versão 1)

```json
{
  "formato": "viasacra-biblia",
  "versao": 1,
  "id": "vulgata",
  "nome": "Vulgata Clementina",
  "abreviacao": "VUL",
  "idioma": "la",
  "licenca": "Domínio público",
  "fonte": "Clementine Vulgate Project",
  "descricao": "Texto latino oficial da Igreja (edição Clementina).",
  "numeracao_salmos": "grega",
  "versao_modulo": 1,
  "livros": [
    { "id": "gn", "capitulos": [ ["In principio creavit Deus cælum et terram.", "…"], ["…"] ] }
  ]
}
```

Regras de validação (`app/lib/data/bible/bible_module.dart`):

- `id`: de 2 a 32 caracteres `[a-z0-9_-]`. Reimportar um módulo com o mesmo id substitui a versão instalada.
- `livros[].id`: precisa existir no cânon católico (por exemplo, livros apócrifos são recusados).
- Capítulo: lista de textos (versículos 1, 2, 3…); pares `[número, "texto"]` quando a numeração
  não é sequencial; ou o objeto `{"1": "…", "2": "…"}`.
- `numeracao_salmos`: `grega` (Vulgata e lecionários brasileiros, por exemplo Sl 22 = "O Senhor é
  meu pastor") ou `hebraica`. Referências da Liturgia como `Sl 22(23)` abrem o salmo certo nas
  duas numerações.

Para gerar um módulo:

```bash
python tool/bible/build_modules.py --vulgata /pasta/extraída        # Vulgata + Douay-Rheims
```

```bash
python tool/bible/build_modules.py --generic texto.json --id figueiredo \
  --nome "Bíblia Sagrada — Pe. Antônio Pereira de Figueiredo" --abreviacao FIG --idioma pt-BR
```

Para **embutir** um módulo de domínio público, gere `app/assets/bible/<id>.json` e acrescente o id
em `app/assets/bible/bundled.json`.

## Armazenamento

As tabelas ficam no SQLite (ver [`DATABASE.md`](DATABASE.md)):

- `bible_translations`, `bible_books`, `bible_chapters`, `bible_verses`;
- `bible_fts`, índice FTS5 com `remove_diacritics`; buscas em latim casam "caelum" com "cælum";
- `bible_highlights_notes`, com marcações, favoritos e anotações.

As marcações são gravadas por livro, capítulo e versículo, **independentemente da tradução**: uma
anotação feita na Vulgata aparece também em outro módulo importado. A última leitura fica em
`meta.bible_last_position` ("Continuar lendo").

## Áudio

"Ouvir capítulo" usa o mesmo motor de leitura da Liturgia (`flutter_tts`, offline). O idioma da
voz segue o da tradução: pt-BR, en-US ou it-IT para o latim, já que os sistemas não têm voz em
latim e a pronúncia italiana se aproxima da eclesiástica.
