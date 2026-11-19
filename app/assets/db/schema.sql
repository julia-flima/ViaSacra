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
CREATE TABLE IF NOT EXISTS catechism_paragraph (
  number   INTEGER PRIMARY KEY,                -- § 1 a 2865
  part     INTEGER NOT NULL CHECK (part BETWEEN 0 AND 4),  -- 0 = Prólogo
  section  INTEGER,
  chapter  INTEGER,
  article  INTEGER,
  heading  TEXT,                               -- título do artigo/parágrafo
  text     TEXT NOT NULL
);

-- Índice de busca de texto completo (FTS5), sincronizado por triggers.
-- remove_diacritics 2: "graca" encontra "graça"; "eucaristia" encontra "Eucaristia".
CREATE VIRTUAL TABLE IF NOT EXISTS catechism_fts USING fts5(
  text,
  heading,
  content = 'catechism_paragraph',
  content_rowid = 'number',
  tokenize = 'unicode61 remove_diacritics 2'
);

CREATE TRIGGER IF NOT EXISTS catechism_ai AFTER INSERT ON catechism_paragraph BEGIN
  INSERT INTO catechism_fts(rowid, text, heading) VALUES (new.number, new.text, new.heading);
END;
CREATE TRIGGER IF NOT EXISTS catechism_ad AFTER DELETE ON catechism_paragraph BEGIN
  INSERT INTO catechism_fts(catechism_fts, rowid, text, heading) VALUES ('delete', old.number, old.text, old.heading);
END;
CREATE TRIGGER IF NOT EXISTS catechism_au AFTER UPDATE ON catechism_paragraph BEGIN
  INSERT INTO catechism_fts(catechism_fts, rowid, text, heading) VALUES ('delete', old.number, old.text, old.heading);
  INSERT INTO catechism_fts(rowid, text, heading) VALUES (new.number, new.text, new.heading);
END;

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

-- Temas (ex.: "Eucaristia" → §§ 1322-1419)
CREATE TABLE IF NOT EXISTS catechism_topic (
  topic   TEXT NOT NULL,
  number  INTEGER NOT NULL,
  PRIMARY KEY (topic, number)
);

-- ---------------------------------------------------------------------
-- Favoritos e anotações (Catecismo, orações, leituras)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS favorite (
  kind        TEXT NOT NULL CHECK (kind IN ('catechism', 'prayer', 'reading', 'homily')),
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
