-- literature-schema.sql — SQLite FTS5 schema for literature retrieval
--
-- Three-table architecture:
--   chunks_data:    regular table storing all chunk metadata (canonical)
--   chunks_fts:     FTS5 virtual table pointing to chunks_data for primary full-text search
--   chunks_trigram: FTS5 virtual table (trigram tokenizer) — fallback-only substring index,
--                   used when chunks_fts finds zero results. NEVER the primary ranking tier
--                   (chunks_fts/BM25 keeps that role); never modified or dropped except by the
--                   clean-rebuild path below. Populated LAZILY by literature-search.sh, not by
--                   this schema file or by literature-build-index.sh -- that indexer only
--                   rebuilds chunks_fts, so chunks_trigram starts (or goes back to) empty after
--                   any full reindex until literature-search.sh's do_search() next needs the
--                   trigram rung, at which point it ensures the table exists and repopulates it
--                   if empty (see task #833).
--
-- BM25 column weights at query time (apply to chunks_fts columns):
--   Pos 0: title    weight 10
--   Pos 1: keywords weight 5
--   Pos 2: summary  weight 3
--   Pos 3: content  weight 1
--
-- Search query pattern:
--   SELECT d.*, bm25(chunks_fts, 10, 5, 3, 1) AS rank
--   FROM chunks_fts
--   JOIN chunks_data d ON d.id = chunks_fts.rowid
--   WHERE chunks_fts MATCH ?
--   ORDER BY rank;
--
-- Usage:
--   sqlite3 /path/to/.literature.db < literature-schema.sql
--   After inserts: INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild');
--
-- WARNING (task #833): this file DROPs and recreates all tables below -- it is a clean-rebuild
-- script, NOT an idempotent migration. Never pipe this file into a database that already holds
-- corpus data; doing so deletes every chunk row. Adding chunks_trigram to an already-populated
-- DB is instead done via an idempotent `CREATE VIRTUAL TABLE IF NOT EXISTS` executed from
-- literature-search.sh (see do_search()'s ensure_trigram() helper), never by re-applying this
-- schema file.

-- Drop existing tables to allow clean rebuild
DROP TABLE IF EXISTS chunks_fts;
DROP TABLE IF EXISTS chunks_trigram;
DROP TABLE IF EXISTS chunks_data;
DROP TABLE IF EXISTS chunk_relations;
DROP TABLE IF EXISTS document_metadata;

-- Canonical metadata table (all chunk fields)
CREATE TABLE chunks_data (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  chunk_id        TEXT NOT NULL UNIQUE,  -- sha256(doc_id+section_path+content_hash)[:16]
  doc_id          TEXT NOT NULL,         -- Parent document identifier (e.g., blackburn2001)
  parent_chunk_id TEXT,                  -- Chunk ID of containing section (NULL for top-level)
  level           INTEGER DEFAULT 1,     -- 0=document, 1=chapter, 2=section, 3=subsection
  section_path    TEXT DEFAULT '',       -- Breadcrumb: "Ch3 > Frame Definability > Theorem 3.4"
  title           TEXT DEFAULT '',       -- Section or chunk title
  keywords        TEXT DEFAULT '',       -- Space-separated terms for FTS tokenization
  summary         TEXT DEFAULT '',       -- Brief description (heuristic: first sentence, <=100 chars)
  token_count     INTEGER DEFAULT 0,     -- Approximate token count (chars/4) for context budgeting
  source_path     TEXT DEFAULT '',       -- Relative path to chunk .md file on disk
  prev_chunk_id   TEXT,                  -- Previous chunk in document sequence (NULL if first)
  next_chunk_id   TEXT,                  -- Next chunk in document sequence (NULL if last)
  cross_refs      TEXT DEFAULT '[]',     -- JSON array: ["Definition 2.1", "Lemma 3.4"]
  content         TEXT DEFAULT ''        -- Full/partial chunk text (task #833: repairs drift --
                                          -- chunks_fts already declared this column; a
                                          -- schema-fresh rebuild failed with "no such column:
                                          -- T.content" before this was added). Guarded by a
                                          -- `SELECT content FROM chunks_data LIMIT 0` probe in
                                          -- literature-build-index.sh, which becomes a no-op now.
);

-- Index for fast per-document chunk retrieval
CREATE INDEX idx_chunks_doc_id ON chunks_data(doc_id);
CREATE INDEX idx_chunks_chunk_id ON chunks_data(chunk_id);

-- FTS5 virtual table pointing to chunks_data for full-text search
-- content='chunks_data' means FTS reads content from chunks_data.{title,keywords,summary,content}
-- After bulk inserts: INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild');
CREATE VIRTUAL TABLE chunks_fts USING fts5(
  title,        -- Weight 10 in bm25()
  keywords,     -- Weight 5 in bm25()
  summary,      -- Weight 3 in bm25()
  content,      -- Weight 1 in bm25() - first ~500 words (full content lives on disk)
  content='chunks_data',
  content_rowid='id',
  tokenize='porter unicode61 remove_diacritics 2'
);

-- Fallback-only substring index (task #833). Additive: does not replace, rewrite, or reweight
-- chunks_fts. Used only when a syntactically valid chunks_fts MATCH returns zero rows -- the
-- trigram tokenizer matches on any 3-character substring run, so punctuation-glued content
-- still matches a plain-text query with no query-grammar sensitivity at all (it's a data
-- representation choice, not a query parser). Populated lazily by literature-search.sh, not by
-- literature-build-index.sh (see header note above). After bulk inserts/rebuild:
-- INSERT INTO chunks_trigram(chunks_trigram) VALUES('rebuild');
CREATE VIRTUAL TABLE chunks_trigram USING fts5(
  content,
  content='chunks_data',
  content_rowid='id',
  tokenize='trigram'
);

-- Relation graph between chunks
CREATE TABLE chunk_relations (
  from_chunk_id TEXT NOT NULL,
  to_chunk_id   TEXT NOT NULL,
  relation_type TEXT NOT NULL,  -- 'parent', 'child', 'sibling', 'cross_ref'
  weight        REAL DEFAULT 1.0,
  PRIMARY KEY (from_chunk_id, to_chunk_id, relation_type)
);

-- Index for fast lookup by either endpoint
CREATE INDEX idx_chunk_relations_from ON chunk_relations(from_chunk_id);
CREATE INDEX idx_chunk_relations_to   ON chunk_relations(to_chunk_id);

-- Document-level metadata
CREATE TABLE document_metadata (
  doc_id       TEXT PRIMARY KEY,
  title        TEXT,
  authors      TEXT,    -- JSON array of author strings
  year         INTEGER,
  source_path  TEXT,    -- Original PDF/DJVU path
  chunks_dir   TEXT,    -- Directory containing chunk files
  chunk_count  INTEGER DEFAULT 0,
  ingested_at  TEXT     -- ISO8601 timestamp
);
