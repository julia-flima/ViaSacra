# Banco de dados local (SQLite)

Esquema completo: [`app/assets/db/schema.sql`](../app/assets/db/schema.sql) — versionado por
`PRAGMA user_version` (atual: 1). Tudo fica no aparelho; nada é sincronizado.

Usamos `package:sqlite3`, que embarca um SQLite com **FTS5** (o SQLite do sistema Android nem
sempre o inclui). Para F-Droid, `tool/fdroid_prebuild.sh` compila o SQLite a partir do código-fonte.

| Tabela | Finalidade | Chave |
|---|---|---|
| `liturgy_cache` | JSON diário baixado (offline-first) | `date` (AAAA-MM-DD) |
| `catechism_paragraph` | Parágrafos do CIC (§1–2865) | `number` |
| `catechism_fts` | Índice FTS5 (`unicode61 remove_diacritics 2`), sincronizado por triggers | `rowid = number` |
| `catechism_toc` | Índice Partes → Seções → Capítulos → Artigos | `id` (ex.: `p2.s2.c1.a3`) |
| `catechism_topic` | Índice temático (ex.: Eucaristia → 1322–1419) | (`topic`, `number`) |
| `favorite` | Favoritos (`catechism`, `prayer`, `reading`, `homily`) | (`kind`, `ref`) |
| `note` | Anotações pessoais | `id` |
| `prayer_log` | Constância: um registro por dia/tipo (`terco`, `rosario`, `liturgia`) | único (`day`, `kind`, `mystery_set`) |
| `rosary_progress` | Retomar o terço do dia de onde parou | `id = 1` |
| `meta` | Versões de conteúdo importado | `key` |

## Busca no Catecismo

- Número: `1324`, `§ 1324` → `SELECT … WHERE number = ?`
- Palavras: cada termo vira prefixo entre aspas (`"graca"* "maria"*`) → `MATCH`, ordenado por
  `bm25` (título pesa 2×), com `snippet()` destacando «termos».
- Sem resultado no texto → tenta o índice temático.

## Constância (streak)

`UserDataRepository.streak()` conta dias consecutivos com qualquer registro em `prayer_log`. Se
hoje ainda não houve oração, a sequência de ontem continua valendo — **sem punição**. O recurso
pode ser ocultado em Ajustes (os registros permanecem, apenas não são exibidos).

## Modelos Dart

`data/models/`: `DailyLiturgy`, `Reading`, `Homily`, `LiturgyAudio`, `SourceInfo` (liturgia);
`Prayer`, `PrayerCategory`; `Mystery`, `SacredArt`; `CatechismParagraph`, `CatechismTocNode`.
