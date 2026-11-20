-- =====================================================================
-- Via Sacra — esquema do banco SQLite local (versão 1)
-- Tudo fica 100% no aparelho. Nenhum dado é enviado a servidores.
-- Ver docs/DATABASE.md
-- =====================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- Cache litúrgico: JSON diário baixado da CDN (offline-first)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS liturgy_cache (
  date            TEXT PRIMARY KEY,            -- AAAA-MM-DD
  json            TEXT NOT NULL,               -- documento completo (schema_version 1)
  schema_version  INTEGER NOT NULL DEFAULT 1,
  source_url      TEXT,
  fetched_at      INTEGER NOT NULL             -- epoch ms
);
CREATE INDEX IF NOT EXISTS idx_liturgy_cache_fetched ON liturgy_cache(fetched_at);

-- ---------------------------------------------------------------------
-- Catecismo da Igreja Católica
-- ---------------------------------------------------------------------
-- Estrutura v1 (texto e temas do CIC) removida na issue #12: o app só traz o
-- índice e abre o texto oficial no portal da Santa Sé. Apaga das instalações antigas.
DROP TRIGGER IF EXISTS catechism_ai;
DROP TRIGGER IF EXISTS catechism_ad;
DROP TRIGGER IF EXISTS catechism_au;
DROP TABLE IF EXISTS catechism_fts;
DROP TABLE IF EXISTS catechism_topic;
DROP TABLE IF EXISTS catechism_paragraph;

-- Índice temático (Partes → Seções → Capítulos → Artigos)
CREATE TABLE IF NOT EXISTS catechism_toc (
  id               TEXT PRIMARY KEY,           -- ex.: "p2.s2.c1.a3"
  parent_id        TEXT REFERENCES catechism_toc(id) ON DELETE CASCADE,
  level            INTEGER NOT NULL,           -- 1 parte, 2 seção, 3 capítulo, 4 artigo
  title            TEXT NOT NULL,
  first_paragraph  INTEGER NOT NULL,
  last_paragraph   INTEGER NOT NULL,
  sort_order       INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_toc_parent ON catechism_toc(parent_id, sort_order);

-- ---------------------------------------------------------------------
-- Favoritos e anotações (Catecismo, orações, leituras)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS favorite (
  kind        TEXT NOT NULL,                   -- catechism | prayer | reading | homily | imitacao…
  ref         TEXT NOT NULL,                   -- nº do parágrafo, id da oração, "2026-11-19#evangelho"
  label       TEXT,
  created_at  INTEGER NOT NULL,
  PRIMARY KEY (kind, ref)
);

CREATE TABLE IF NOT EXISTS note (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  kind        TEXT NOT NULL,
  ref         TEXT NOT NULL,
  body        TEXT NOT NULL,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_note_ref ON note(kind, ref);

-- ---------------------------------------------------------------------
-- Constância espiritual (streak) — opcional, nunca sai do aparelho
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS prayer_log (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  day           TEXT NOT NULL,                 -- AAAA-MM-DD (data local)
  kind          TEXT NOT NULL CHECK (kind IN ('terco', 'rosario', 'liturgia')),
  mystery_set   TEXT,                          -- gozosos | luminosos | dolorosos | gloriosos | completo
  decades       INTEGER,                       -- dezenas concluídas
  completed_at  INTEGER NOT NULL               -- epoch ms
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_prayer_log_unique ON prayer_log(day, kind, IFNULL(mystery_set, ''));
CREATE INDEX IF NOT EXISTS idx_prayer_log_day ON prayer_log(day);

-- Progresso do terço em andamento (retomar de onde parou)
CREATE TABLE IF NOT EXISTS rosary_progress (
  id           INTEGER PRIMARY KEY CHECK (id = 1),
  day          TEXT NOT NULL,
  mode         TEXT NOT NULL,                  -- terco | rosario
  mystery_set  TEXT NOT NULL,
  decade       INTEGER NOT NULL,               -- 0..19
  bead         INTEGER NOT NULL,               -- 0..10
  updated_at   INTEGER NOT NULL
);

-- ---------------------------------------------------------------------
-- Metadados (versões de conteúdo importado)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS meta (
  key    TEXT PRIMARY KEY,
  value  TEXT NOT NULL
);

-- =====================================================================
-- Versão 2 — Bíblia Sagrada (cânon católico, 73 livros)
-- Traduções são MÓDULOS: as de domínio público vêm embutidas; as protegidas
-- (CNBB, Ave-Maria, Jerusalém, Pastoral…) só entram por importação local
-- feita pelo próprio usuário. Ver docs/BIBLE.md.
-- =====================================================================

CREATE TABLE IF NOT EXISTS bible_translations (
  id                TEXT PRIMARY KEY,          -- ex.: "vulgata", "figueiredo", "cnbb"
  name              TEXT NOT NULL,
  abbreviation      TEXT NOT NULL,             -- ex.: "VUL"
  language          TEXT NOT NULL,             -- BCP-47: pt-BR, la, en
  license           TEXT NOT NULL,
  source            TEXT,
  description       TEXT,
  psalm_numbering   TEXT NOT NULL DEFAULT 'grega' CHECK (psalm_numbering IN ('grega', 'hebraica')),
  bundled           INTEGER NOT NULL DEFAULT 0, -- 1 = embutida no app (domínio público)
  verse_count       INTEGER NOT NULL DEFAULT 0,
  module_version    INTEGER NOT NULL DEFAULT 1,
  installed_at      INTEGER NOT NULL
);

-- Livros do cânon (independente da tradução)
CREATE TABLE IF NOT EXISTS bible_books (
  id              TEXT PRIMARY KEY,            -- ex.: "gn", "jo", "1cor"
  position        INTEGER NOT NULL UNIQUE,     -- 1..73 (ordem das Bíblias católicas brasileiras)
  abbreviation    TEXT NOT NULL,               -- "Gn", "Jo", "1Cor"
  name            TEXT NOT NULL,               -- "Gênesis"
  latin_name      TEXT NOT NULL,
  testament       TEXT NOT NULL CHECK (testament IN ('AT', 'NT')),
  deuterocanonical INTEGER NOT NULL DEFAULT 0
);

-- Contagem de capítulos por tradução/livro (navegação rápida)
CREATE TABLE IF NOT EXISTS bible_chapters (
  translation_id  TEXT NOT NULL REFERENCES bible_translations(id) ON DELETE CASCADE,
  book_id         TEXT NOT NULL REFERENCES bible_books(id),
  chapter         INTEGER NOT NULL,
  verse_count     INTEGER NOT NULL,
  PRIMARY KEY (translation_id, book_id, chapter)
);

CREATE TABLE IF NOT EXISTS bible_verses (
  id              INTEGER PRIMARY KEY,         -- rowid (ligado ao FTS5)
  translation_id  TEXT NOT NULL REFERENCES bible_translations(id) ON DELETE CASCADE,
  book_id         TEXT NOT NULL REFERENCES bible_books(id),
  chapter         INTEGER NOT NULL,
  verse           INTEGER NOT NULL,
  text            TEXT NOT NULL,
  UNIQUE (translation_id, book_id, chapter, verse)
);

CREATE VIRTUAL TABLE IF NOT EXISTS bible_fts USING fts5(
  text,
  content = 'bible_verses',
  content_rowid = 'id',
  tokenize = 'unicode61 remove_diacritics 2'
);

CREATE TRIGGER IF NOT EXISTS bible_verses_ai AFTER INSERT ON bible_verses BEGIN
  INSERT INTO bible_fts(rowid, text) VALUES (new.id, new.text);
END;
CREATE TRIGGER IF NOT EXISTS bible_verses_ad AFTER DELETE ON bible_verses BEGIN
  INSERT INTO bible_fts(bible_fts, rowid, text) VALUES ('delete', old.id, old.text);
END;
CREATE TRIGGER IF NOT EXISTS bible_verses_au AFTER UPDATE ON bible_verses BEGIN
  INSERT INTO bible_fts(bible_fts, rowid, text) VALUES ('delete', old.id, old.text);
  INSERT INTO bible_fts(rowid, text) VALUES (new.id, new.text);
END;

-- Marcações, favoritos e anotações por versículo — independem da tradução,
-- então aparecem em qualquer tradução que o usuário estiver lendo.
CREATE TABLE IF NOT EXISTS bible_highlights_notes (
  book_id     TEXT NOT NULL REFERENCES bible_books(id),
  chapter     INTEGER NOT NULL,
  verse       INTEGER NOT NULL,
  color       TEXT CHECK (color IN ('ouro', 'oliva', 'rosa', 'azul', 'lilas')),
  favorite    INTEGER NOT NULL DEFAULT 0,
  note        TEXT,
  updated_at  INTEGER NOT NULL,
  PRIMARY KEY (book_id, chapter, verse)
);
CREATE INDEX IF NOT EXISTS idx_bible_hn_fav ON bible_highlights_notes(favorite, updated_at);

-- =====================================================================
-- Versão 3 — Múltiplos Catecismos (100% FOSS + Importador Modular JSON)
-- Embutidos (domínio público): Catecismo Maior de São Pio X (1905) e
-- Catecismo Romano (Concílio de Trento, 1566).
-- Importados localmente pelo usuário: CIC (1992), Compêndio do CIC, etc.
-- =====================================================================

CREATE TABLE IF NOT EXISTS catechisms (
  id              TEXT PRIMARY KEY,            -- ex.: "sao_pio_x", "romano_trento", "cic_1992"
  name            TEXT NOT NULL,
  short_name      TEXT NOT NULL,               -- ex.: "São Pio X", "Trento", "CIC 1992"
  year            INTEGER,
  language        TEXT NOT NULL DEFAULT 'pt-BR',
  license         TEXT NOT NULL,
  source          TEXT,
  description     TEXT,
  entry_label     TEXT NOT NULL DEFAULT '§',   -- "Pergunta" ou "§"
  bundled         INTEGER NOT NULL DEFAULT 0,  -- 1 = embutido (domínio público)
  entry_count     INTEGER NOT NULL DEFAULT 0,
  module_version  INTEGER NOT NULL DEFAULT 1,
  installed_at    INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS catechism_entries (
  id              INTEGER PRIMARY KEY,         -- rowid (ligado ao FTS5)
  catechism_id    TEXT NOT NULL REFERENCES catechisms(id) ON DELETE CASCADE,
  number          INTEGER NOT NULL,            -- nº da pergunta ou parágrafo
  part            TEXT NOT NULL,               -- ex.: "Primeira Parte — Do Símbolo dos Apóstolos"
  chapter         TEXT,                        -- ex.: "Capítulo I — De Deus e da Criação"
  question        TEXT,                        -- pergunta ou título do parágrafo
  answer          TEXT NOT NULL,               -- resposta ou texto integral
  UNIQUE (catechism_id, number)
);
CREATE INDEX IF NOT EXISTS idx_catechism_entries_cat ON catechism_entries(catechism_id, number);

CREATE VIRTUAL TABLE IF NOT EXISTS catechism_entries_fts USING fts5(
  question,
  answer,
  part,
  chapter,
  content = 'catechism_entries',
  content_rowid = 'id',
  tokenize = 'unicode61 remove_diacritics 2'
);

CREATE TRIGGER IF NOT EXISTS catechism_entries_ai AFTER INSERT ON catechism_entries BEGIN
  INSERT INTO catechism_entries_fts(rowid, question, answer, part, chapter)
  VALUES (new.id, new.question, new.answer, new.part, new.chapter);
END;
CREATE TRIGGER IF NOT EXISTS catechism_entries_ad AFTER DELETE ON catechism_entries BEGIN
  INSERT INTO catechism_entries_fts(catechism_entries_fts, rowid, question, answer, part, chapter)
  VALUES ('delete', old.id, old.question, old.answer, old.part, old.chapter);
END;
CREATE TRIGGER IF NOT EXISTS catechism_entries_au AFTER UPDATE ON catechism_entries BEGIN
  INSERT INTO catechism_entries_fts(catechism_entries_fts, rowid, question, answer, part, chapter)
  VALUES ('delete', old.id, old.question, old.answer, old.part, old.chapter);
  INSERT INTO catechism_entries_fts(rowid, question, answer, part, chapter)
  VALUES (new.id, new.question, new.answer, new.part, new.chapter);
END;
