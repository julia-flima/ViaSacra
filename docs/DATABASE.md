# Banco de dados local (SQLite)

Esquema completo: [`app/assets/db/schema.sql`](../app/assets/db/schema.sql) — versionado por
`PRAGMA user_version` (atual: **5**). O esquema é idempotente (`CREATE … IF NOT EXISTS`): a migração reaplica o arquivo e cria só o que falta, sem tocar nos dados. Tudo fica no aparelho; nada é sincronizado (para trocar de aparelho, use o backup em Ajustes).

Versões: 2 = Bíblia · 3 = catecismos em perguntas e respostas + importador · 4 = remove as tabelas
antigas de texto do CIC · 5 = `favorite.kind` sem lista fixa (favoritos da Imitação). Migrações
que o SQL idempotente não resolve ficam em `AppDatabase._migrate` (`lib/data/database.dart`).

### Uma base, três plataformas

| Plataforma | Abertura (`lib/data/platform/`) | Persistência |
|---|---|---|
| Android / iOS | `db_opener_native.dart` → `sqlite3.open()` | arquivo `via_sacra.db` no diretório de suporte do app |
| Web / PWA | `db_opener_web.dart` → `WasmSqlite3` (`web/sqlite3.wasm`) + `IndexedDbFileSystem` | IndexedDB do navegador (`via_sacra`) |

Escolhemos `package:sqlite3` em vez do `drift` porque é exatamente o motor que o drift usa por baixo
(inclusive o `sqlite3.wasm` na web), mas sem geração de código. O mesmo SQL e o mesmo FTS5 rodam
nas três plataformas, e o import condicional (`dart.library.js_interop`) escolhe a implementação.

Usamos `package:sqlite3`, que embarca um SQLite com **FTS5** (o SQLite do sistema Android nem
sempre o inclui). Para F-Droid, `tool/fdroid_prebuild.sh` compila o SQLite a partir do código-fonte.

| Tabela | Finalidade | Chave |
|---|---|---|
| `liturgy_cache` | JSON diário baixado (offline-first) | `date` (AAAA-MM-DD) |
| `catechism_toc` | Índice do CIC: Partes → Seções → Capítulos → Artigos (o texto abre no vatican.va) | `id` (ex.: `p2.s2.c1.a3`) |
| `catechisms` | Obras em perguntas e respostas (São Pio X embutido; outras importadas) | `id` |
| `catechism_entries` | Perguntas/respostas das obras | `id` · (`catechism_id`, `number`) |
| `catechism_entries_fts` | FTS5 sobre as entradas (`remove_diacritics 2`), sincronizado por triggers | `rowid = id` |
| `favorite` | Favoritos (`catechism`, `prayer`, `reading`, `homily`, `imitacao`, …) | (`kind`, `ref`) |
| `note` | Anotações pessoais (catecismo, Lectio Divina…); uma por (`kind`, `ref`) | `id` |
| `prayer_log` | Constância: um registro por dia/tipo (`terco`, `rosario`, `liturgia`) | único (`day`, `kind`, `mystery_set`) |
| `rosary_progress` | Retomar o terço do dia de onde parou | `id = 1` |
| `meta` | Versões de conteúdo importado, última leitura da Bíblia | `key` |
| `bible_translations` | Módulos de tradução instalados (licença, idioma, numeração dos Salmos, embutida/importada) | `id` |
| `bible_books` | Cânon católico (73 livros, ordem brasileira) | `id` |
| `bible_chapters` | Nº de versículos por capítulo/tradução (navegação rápida) | (`translation_id`, `book_id`, `chapter`) |
| `bible_verses` | Texto dos versículos | `id` (rowid) · único (`translation_id`, `book_id`, `chapter`, `verse`) |
| `bible_fts` | FTS5 sobre `bible_verses.text`, sincronizado por triggers | `rowid = id` |
| `bible_highlights_notes` | Marcação (cor), favorito e anotação por versículo — independe da tradução | (`book_id`, `chapter`, `verse`) |

## Busca no Catecismo

`CatechismRepository.searchEntries(obra, consulta)`: um número (`1324`, `§1324`, `P. 18`) busca a
entrada exata; palavras viram prefixos entre aspas (`"graca"* "maria"*`) no FTS5, sem acentos.

## Constância (streak)

`UserDataRepository.streak()` conta dias consecutivos com qualquer registro em `prayer_log`. Se
hoje ainda não houve oração, a sequência de ontem continua valendo — **sem punição**. O recurso
pode ser ocultado em Ajustes (os registros permanecem, apenas não são exibidos).

## Modelos Dart

`data/models/`: `DailyLiturgy`, `Reading`, `Homily`, `LiturgyAudio`, `SourceInfo` (liturgia);
`Prayer`, `PrayerCategory`; `Mystery`, `SacredArt`; `CatechismTocNode`, `CatechismWork`,
`CatechismEntry`; `ImitationOfChrist`.
