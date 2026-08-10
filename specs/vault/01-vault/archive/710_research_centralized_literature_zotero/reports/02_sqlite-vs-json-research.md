# Research Report: Task #710

**Task**: 710 - research_centralized_literature_zotero
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:30:00Z
**Effort**: ~1 hour (codebase reading + web research)
**Dependencies**: 01_team-research.md (prior team research findings)
**Sources/Inputs**:
- Codebase: `skill-literature/SKILL.md`, `literature-organization.md`, `literature-retrieve.sh`
- Team research: `specs/710_research_centralized_literature_zotero/reports/01_team-research.md`
- Lectic project: `https://github.com/gleachkr/Lectic` (src/tools/sqlite.ts)
- Web: SQLite application file format docs, SQLite vs JSON comparisons, git-sqlite tooling
**Artifacts**:
- `specs/710_research_centralized_literature_zotero/reports/02_sqlite-vs-json-research.md`
**Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

---

## Executive Summary

- **Lectic's SQLite role is a tool interface, not an index**: Lectic exposes SQLite as an optional LLM-queryable tool (read-only SQL queries by a conversational agent), not as its own data storage. Lectic stores its own data as plaintext `.lec` markdown files. The SQLite integration is an external capability — agents can query a user's existing SQLite database — not an architectural core. The lesson for this project is different from what was expected.

- **SQLite is not the right fit for this 200-entry index**: For the current scale (~200 entries, ~50KB JSON), SQLite adds meaningful complexity with no commensurate benefit. The agent toolchain is bash/jq-native; SQLite requires a different CLI (`sqlite3`) and different query syntax. The `git` story is worse: SQLite is a binary file, so diffs are opaque, merge conflicts are unresolvable without specialized tooling (`cannadayr/git-sqlite`), and the file is not human-inspectable.

- **Recommended path: JSON remains the correct format.** The team research recommendation stands. The user's intuition about SQLite is worth taking seriously, but the specific case here — a small, infrequently written, frequently read, human-reviewed, git-tracked index — is exactly the case where JSON wins.

- **If SQLite is desired later, a specific threshold applies**: When the corpus exceeds ~500-1000 entries, full-text search (FTS5 in SQLite) or complex multi-field queries would provide real value over jq. At that scale, a hybrid approach (SQLite as optional query cache alongside canonical JSON) is worth revisiting.

---

## Context & Scope

The team research (01_team-research.md) recommended a JSON `index.json` file as the centralized literature index for `~/Projects/Literature/`. The user's follow-up focus prompt asks specifically about SQLite as an alternative. This report researches:

1. Lectic's actual SQLite usage pattern (the inspiration)
2. SQLite vs JSON tradeoffs for a ~200-entry literature index
3. The complexity cost to the existing bash/jq agent system
4. What SQLite would enable that JSON cannot
5. Hybrid approaches (middle ground options)
6. A clear recommendation

This report does NOT revisit the broader architecture decisions from the team research (LITERATURE_DIR env var, CSL-JSON vs BibTeX, migration sequencing). Those findings stand.

---

## Findings

### 1. Lectic's SQLite Usage — What It Actually Does

Lectic (`gleachkr/Lectic`) is a CLI tool that stores LLM conversations as plaintext markdown files (`.lec` extension). Its own data architecture is **entirely flat files** — Lectic does not use SQLite for its own storage.

SQLite in Lectic is a **tool integration capability**: users can declare `sqlite: ./analytics.db` in their conversation specification, and this exposes a read-only (or read-write) query interface that the LLM can call during the conversation. The `src/tools/sqlite.ts` module:

- Accepts a SQL query as input
- Executes it against a pre-existing user database
- Returns results as YAML (to avoid JSON escaping issues)
- Blocks dangerous operations: `ATTACH`, `DETACH`, `PRAGMA`, `VACUUM`
- Auto-provides schema context to the LLM

**The lesson from Lectic**: SQLite shines when an agent needs to **query an existing, external, arbitrarily-complex database** owned by someone else. The LLM issues ad-hoc SQL against real business data. That is qualitatively different from managing a ~200-entry index file that the agent system itself owns and controls.

Lectic's design confirms the Unix approach: store your own data as plain text, use SQLite for external data sources that have relational structure. This is the **opposite** of what switching the literature index to SQLite would do.

### 2. SQLite vs JSON: The Core Tradeoffs

#### When SQLite wins

| Criterion | SQLite advantage |
|-----------|-----------------|
| Dataset size | Outperforms JSON at ~10,000+ entries; measurable gains at ~1,000+ |
| Query complexity | Multi-field joins, aggregations, GROUP BY are native; jq equivalents are verbose |
| Full-text search | SQLite FTS5 is excellent for document search across title, summary, keywords |
| Concurrent writes | Multiple processes writing simultaneously — SQLite handles this with locking |
| Incremental updates | Only changed rows rewritten; large JSON must be fully rewritten |
| Schema evolution | Adding columns is backward-compatible; old queries still work |

#### When JSON wins

| Criterion | JSON advantage |
|-----------|----------------|
| Human readability | Directly inspectable with any editor; SQLite is binary |
| Git integration | Text diffs, merge conflict resolution, PR reviews of schema changes |
| Tooling ecosystem | `jq` is universal in bash; `sqlite3` requires separate install |
| Simplicity at small scale | 200 entries in jq is trivial; SQL is overkill |
| No binary overhead | JSON is directly readable after `git clone`; SQLite requires sqlite3 CLI |
| Current toolchain | All existing scripts (`literature-retrieve.sh`, `skill-literature/SKILL.md`) use `jq` |

#### The specific case: ~200-entry literature index

The current index has:
- ~141 entries in two repos (113 + 76, with 3 overlapping)
- Target: ~200 entries in the centralized repo after migration
- File size: ~50KB estimated (the BimodalLogic index.json is likely 30-50KB)
- Write frequency: low (only when `/literature --index` or `/literature --convert` runs)
- Read frequency: moderate (every `--lit` invocation queries the index for scoring)
- Query pattern: keyword intersection scoring — computable with `jq` in a single pass

The read pattern (`literature-retrieve.sh`) is: load all entries, score each by keyword overlap, sort descending, take top 10 within budget. This is a linear scan with no joins, no aggregation, and no full-text search. `jq` handles this in milliseconds for 200 entries. SQLite provides no measurable benefit here.

### 3. The Git Story for SQLite

This is the most important practical concern for a version-controlled index.

**SQLite in git**:
- Binary file: `git diff` shows `Binary files differ` — no useful human-readable diff
- Merge conflicts: unresolvable without specialized tooling; git cannot auto-merge binary files
- PR review: reviewers cannot see what changed without checking out the branch and querying sqlite3
- History: `git log -p` shows nothing meaningful

**Workaround**: `cannadayr/git-sqlite` is a custom git diff and merge driver. It works by serializing SQLite to SQL statements for diff/merge purposes. This is a real tool, but it requires:
1. Installing `git-sqlite`
2. Configuring `.gitattributes` for the sqlite file
3. Every collaborator (or agent session) having it configured

For a personal single-developer project on a single machine, this is manageable. For a shared tool system that must be reproducible across fresh clones (which is the premise of `~/Projects/Literature/` as a git repo), it is an unnecessary burden.

**Contrast**: The current `index.json` in git gives:
- Human-readable diffs showing exactly which entries changed
- Merge-resolvable conflicts (jq-formatted JSON is line-oriented)
- Browsable history of literature additions

### 4. Complexity Cost to the Agent System

The current literature system is entirely bash + jq:

```bash
# Current scoring in literature-retrieve.sh (representative)
scores=$(jq -r --argjson task_kws "$task_keywords" '
  .entries[] | ...keyword scoring...
' "$INDEX_FILE")
```

Switching to SQLite would require:
- Rewriting `literature-retrieve.sh` to use `sqlite3` CLI with SQL queries
- Rewriting `skill-literature/SKILL.md` index management (all `jq` operations become SQL INSERT/UPDATE)
- Adding `sqlite3` as a system dependency (it is not always present; jq is more universally available)
- Handling WAL mode, locking, and connection management in bash
- Losing the human-readable index for debugging

The rewrite scope is non-trivial. The current SKILL.md is 1046 lines of bash that use `jq` heavily for index manipulation. Every `jq --arg` / `jq --argjson` invocation in the create/update paths would become `sqlite3 ... "INSERT OR REPLACE INTO ..."`. This is a full rewrite, not an incremental change.

### 5. What SQLite Would Enable That JSON Cannot

Being honest about the genuine benefits at some future scale:

**Full-text search (FTS5)**: If the corpus grows to 500+ entries and keyword overlap scoring becomes imprecise, SQLite FTS5 enables proper full-text search over title, summary, and content. This is the single most compelling future benefit.

```sql
-- Example: FTS5 query for modal logic papers
SELECT id, title, year FROM literature_fts WHERE literature_fts MATCH 'modal AND completeness';
```

**Complex multi-field queries**: Filtering by `year > 2010 AND doc_type = 'paper' AND project_tags LIKE '%BimodalLogic%'` is natural SQL but verbose in jq.

**Concurrent access**: If multiple Claude Code sessions write to the same index simultaneously (identified as Gap G1 in the team research), SQLite's built-in locking prevents data corruption. With JSON, the current `mv`-based atomic write approach gives last-write-wins.

**Zotero integration queries**: If the `zotero-library.json` were imported into SQLite, cross-referencing Zotero metadata against the literature index would be a natural SQL join.

None of these benefits apply at the current scale (200 entries, single-user, low write frequency).

### 6. Hybrid Approaches

Three hybrid options merit consideration:

**Option A: JSON primary, SQLite query cache (on-demand)**
- Canonical format remains `index.json` (git-friendly, jq-native)
- Optional: `index.db` generated from `index.json` on demand for complex queries
- Build: `jq -r '...' index.json | sqlite3 index.db`
- `.gitignore`: `index.db` (not tracked)
- Use case: Advanced queries by power users; regenerated automatically when needed
- Complexity: Low — the SQLite file is ephemeral and disposable

**Option B: SQLite primary with JSON export for per-project consumption**
- SQLite at `~/Projects/Literature/index.db` (not git-tracked as primary)
- Snapshot JSON exported to `~/Projects/Literature/index.json` after each write
- `literature-retrieve.sh` continues to read JSON (no change to per-project tooling)
- Complexity: Medium — two authoritative copies creates consistency risk

**Option C: FTS-augmented JSON (no SQLite)**
- Keep JSON, but add a `content_preview` field to each index entry (first ~200 words of the markdown file)
- Scoring algorithm in `literature-retrieve.sh` gains substring search over content_preview
- Mimics the benefit of FTS without SQLite dependency
- Complexity: Low — a `jq` addition to scoring; larger index.json file

**Recommendation**: Option A (JSON primary, SQLite on-demand cache) is the best forward path if SQLite is desired at all. It preserves all current tooling and git behavior while enabling future SQLite queries when needed. However, at the current scale, even this is unnecessary.

---

## Decisions

1. **Lectic's SQLite pattern is not applicable to the literature index.** Lectic uses SQLite as a tool for LLM access to external data, not as its own storage format. The literature index is agent-owned metadata — a different use case.

2. **JSON is the correct format for the current scale.** ~200 entries, ~50KB, jq-native toolchain, git-tracked. All three selection criteria point to JSON.

3. **The git story is disqualifying for SQLite as primary format.** Binary diffs and merge conflicts without specialized git-sqlite tooling are unacceptable for a version-controlled index in a multi-project setup.

4. **SQLite is the right answer at ~500-1000 entries, primarily for FTS5.** The current keyword-overlap scoring will degrade at scale; FTS5 is the natural upgrade path.

5. **If SQLite is introduced, Option A (JSON primary + ephemeral SQLite cache) is the right architecture.** This preserves backward compatibility and git friendliness while enabling advanced queries.

---

## Recommendations

**Immediate (task 710 implementation)**:
1. Proceed with the JSON `index.json` design from the team research. The v2 schema with `zotero_key`, `zotero_path`, and `project_tags` fields is correct. No change needed here.
2. Document the SQLite deferral decision explicitly in the central repo README: "Index format is JSON. SQLite index.db may be generated on demand for complex queries when corpus exceeds ~500 entries."

**Future threshold (corpus >500 entries)**:
3. Introduce SQLite FTS5 as an opt-in query layer (Option A above).
4. Consider importing `zotero-library.json` into SQLite for cross-reference queries.
5. Evaluate `cannadayr/git-sqlite` for diff/merge support at that point.

**Not recommended**:
- SQLite as the primary/canonical index format at current scale
- Full rewrite of bash/jq tooling to sqlite3 queries
- Committing `index.db` to git without specialized diff/merge driver

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| JSON index grows unwieldy past 500 entries | Medium (2-3 years) | Low (still functional, just slower) | Document SQLite upgrade threshold; Option A is ready to implement |
| Concurrent write corruption (G1 from team research) | Low (single-user) | Medium | `flock`-based locking in bash scripts; or git-based write workflow |
| jq scoring becomes imprecise as corpus grows | Medium | Medium | Add `content_preview` field (Option C) as interim FTS improvement |
| SQLite introduced prematurely by future contributor | Low | Medium | README documents the deliberate deferral decision with rationale |

---

## Appendix

### Search Queries Used
- "sqlite vs json metadata index best practices 2025 2026"
- "sqlite application file format academic literature management agent 2025"
- "sqlite git merge conflict binary file workaround strategy 2024 2025"
- "jq bash shell SQLite query json alternative small dataset 200 entries 2024"

### Key References
- [SQLite As An Application File Format](https://sqlite.org/appfileformat.html) — SQLite's own documentation on when to use SQLite as a file format
- [git-sqlite: custom diff and merge driver](https://github.com/cannadayr/git-sqlite) — the workaround for SQLite in git
- [Lectic src/tools/sqlite.ts](https://github.com/gleachkr/Lectic/blob/main/src/tools/sqlite.ts) — Lectic's actual SQLite integration
- [Lectic README](https://github.com/gleachkr/Lectic/blob/main/README.md) — confirms Lectic stores its own data as plaintext, not SQLite
- [pnpm SQLite RFC](https://github.com/pnpm/pnpm/issues/10826) — example of a real project considering SQLite for package metadata (1000s of entries use case)
- [YU Zongmin's SQLite Literature Manager (2025)](https://skywork.ai/skypage/en/yu-zongmin-sqlite-manager/1978324727067484160) — MCP-based SQLite literature manager, shows the pattern at scale

### Scale Reference Points from the pnpm RFC
The pnpm discussion about switching package metadata to SQLite (10,826 packages) is instructive. The motivations were: better concurrency, complex queries, and reduced I/O for large metadata sets. **None of those motivations apply at 200 entries.** The pnpm use case starts at tens of thousands of packages; the literature index starts at ~200.
