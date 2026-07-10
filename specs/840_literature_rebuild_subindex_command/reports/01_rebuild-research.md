# Research Report: Task #840

**Task**: 840 - Add `--rebuild` flag to `/literature` for per-repo sub-index conformance
**Started**: 2026-07-10
**Completed**: 2026-07-10
**Effort**: Medium (mostly wiring + AskUserQuestion flows; job 1/2/4 logic is largely reusable)
**Dependencies**: #841 (complete — extension source now matches deployed scripts; drift guard installed)
**Sources/Inputs**: Codebase (`.claude/extensions/literature/`), live corpora (`~/Projects/Literature`, `~/Projects/BimodalLogic`, `~/Projects/cslib`, this repo), SQLite `.literature.db`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The command-layer insertion point is clear and cheap: `.claude/extensions/literature/commands/literature.md` step 1 mode-detection table (add `--rebuild` as priority-0, before `--validate`) and a new `<step_X>` in `<workflow_execution>` delegating to `skill-literature` with `mode=rebuild`.
- **Job 1 (dangling-ref lint) and most of the "List" resolution logic already exist, unwired**, in `skill-literature/SKILL.md`'s "Sub-Index Management" section (`### Validate: Check All doc_ids Exist in Global Index`, lines ~1719-1753). It references a `--subindex` flag in its own echoed help text, but **no such flag is parsed anywhere in `literature.md`** — this whole section is dead documentation today. `--rebuild` Job 1 should adopt/generalize this exact bash block rather than write new dangling-ref logic.
- **Measured baseline (re-run 2026-07-10, values have shifted from the #841/#840 task description's 2026-07-09 snapshot)**: global index is now **282 entries** (was 273); nvim sub-index still **ABSENT**; BimodalLogic sub-index **2 entries, 0 dangling**; cslib sub-index **11 entries, 0 dangling**. Dangling-ref lint still currently passes everywhere — it remains a regression guard, not a fix for a live defect.
- **Schema conformance is currently VIOLATED, live, in a load-bearing way** — this is the most important finding of this research and changes how Job 2 must be designed. See "Schema Conformance Reality" below.
- **Job 4's premise is independently confirmed as a live, current gap, not a hypothetical.** 25 of 97 `sources/<dir>/` directories have zero rows in the global `.literature.db`'s `chunks_data` table (no FTS5 coverage at all), including non-quarantined, actively-cited documents: `girard_1989`, `rabinovich_2014`, `burgess_1982_i`, `hodkinson_2006`, `tarjan_1972`, `thomas_1997`, `baier_katoen_2008`, and 18 others. Root cause identified: `/literature --convert` (Mode B `handle_convert`) writes markdown + local `index.json` only and **never invokes `literature-chunk.sh` or `literature-build-index.sh`** — only the separate `literature-ingest.sh` pipeline (`--ingest`) does convert+chunk+index. Any document that entered the corpus via `--convert` (or manual placement, as task #832's `girard_1989`/`rabinovich_2014` reconversions appear to have) is present in `sources/` and in the global `index.json` with a `provenance_fidelity` stamp, but is invisible to search. `document_metadata` (the SQL table meant to hold one row per document) has **0 rows** — also worth flagging to the planner as a possibly-dead table.
- Hazard (a) from the task description (`literature-ingest.sh` writing outside `sources/<dir>/`) is also confirmed live: **11 directories exist directly under `~/Projects/Literature/`** (not under `sources/`), each with its own `chunks.json`, e.g. `bonakdarpour_sheinvald_2023_finite_word_hyperlanguages`. These 9-11 legacy entries use a `doc_id`/`chunks_dir` schema in `index.json` with **no `path` field at all** (9 confirmed). Any Job 4 audit keyed off `.path starting with "sources/"` will silently skip auditing these — it must also handle the legacy `chunks_dir`-keyed schema.
- Hazard (b) (quarantine artifacts polluting the chunker) is currently **not manifesting**: `gabbay_2000` and `troelstra_schwichtenberg_2000` both carry `.md.rejected` files but have **no `chunks.json`** in their directories — rejected docs never produced a valid canonical `.md`, so they were never chunked. This is incidental (chunking never ran on them at all, not because the chunker's glob specifically excludes `.md.rejected`/`.md.bak-*`), so the hazard should still be asserted defensively in Job 4 rather than assumed permanently safe.

## Context & Scope

Researched the existing `/literature` command/skill architecture to find the exact insertion point for a new `--rebuild` flag, confirmed the current schema/state of both the per-repo sub-indexes (`specs/literature-index.json`) and the global corpus (`~/Projects/Literature/index.json` + `.literature.db`), and re-verified every numeric claim in the task description against live data rather than trusting the #841-era snapshot.

## Findings

### Codebase Patterns

**Command dispatch** (`.claude/extensions/literature/commands/literature.md`):
- Mode detection is a first-match-wins priority list (step_1, lines 23-92): `--validate` > `--index FILE` > `--convert [FILE]` > no-args/path-like (integrate) > numeric/text (discover).
- `--rebuild` should be inserted as a new top priority (before `--validate`, since both are flag-triggered and mutually exclusive) — add `sub_mode = "rebuild"` branch, add a row to the sub-mode summary table, add a row to the Sub-Mode/FILE/QUERY validation table (`FILE Required: No`, `QUERY/TASK Required: No`), and a new `<step_X>` under `<workflow_execution>` that delegates to `skill-literature` with `mode=rebuild`. Update `argument-hint` frontmatter and the "Unknown flag" error message to list `--rebuild`.
- Delegation pattern for flag-only modes (validate/index/convert) is uniform: `skill: "skill-literature"`, `args: "mode={sub_mode} file={file}"`. `--rebuild` follows the same shape; `file` is unused (no FILE arg), `--dry-run` should be parsed alongside `--rebuild` the same way `--index`'s FILE arg is extracted, and passed through as e.g. `args: "mode=rebuild dry_run={true|false}"`.

**Skill dispatch** (`.claude/extensions/literature/skills/skill-literature/SKILL.md`):
- Step 4 dispatch is a bash `case "$mode" in status|scan|convert|validate|index|search|ingest|*)`. Add `rebuild) handle_rebuild ;;` alongside the existing cases, and update the `Unknown mode` error message's "Available:" list.
- **The skill file already contains a full "Sub-Index Management" section (lines 1596-1753)** — Init / Add / Remove / List / Validate — operating on `specs/literature-index.json` against `${LITERATURE_DIR:-$HOME/Projects/Literature}/index.json`. This is currently **unreachable dead code**: no flag in `literature.md` routes to it, and its own embedded help text (`Run: /literature --subindex add <doc_id>`) refers to a flag that doesn't exist. Its "Validate" block (lines 1719-1753) is Job 1's dangling-ref lint almost verbatim — same technique (`jq -e --arg id "$doc_id" '.entries[] | select(.id == $id)'` against the global index for every sub-index `doc_id`), just needs to be lifted into a `handle_rebuild()` function and its output shaped for the multi-job report rather than a standalone command.
- **Do NOT reuse the "Init"/"Add"/"Remove" blocks uncritically** — see Schema Conformance Reality below; they write the nominal `{doc_id, relevance, added, source}` shape, which does not match either live sub-index in this corpus.

**`literature-create-setup-task.sh`** (already read in full): creates a `meta`-type task in `state.json` to populate a missing sub-index; used when the sub-index is absent. `--rebuild` must defer to this exact script (already the documented behavior for the sub-index-MISSING case) rather than duplicating its state.json-mutation logic — when `specs/literature-index.json` does not exist, `--rebuild` should detect that first and either invoke this script directly or print the same guidance it already uses elsewhere in the `--lit` flow (see `literature-lit-flag-resolve.sh` / CLAUDE.md "Interactive Sub-Index Setup Detection" for the precedent of a directive-classifier + AskUserQuestion pattern worth mirroring for `--rebuild`'s own job picker).

### Schema Conformance Reality (critical — changes Job 2's design)

The task description states the sub-index schema is `{"entries": [{"doc_id", "relevance", "source"}]}`. Live data contradicts this in two different, non-toy ways:

- **`~/Projects/cslib/specs/literature-index.json`** (11 entries): top-level has `version: "2.0"`, `description`. Entries are `{doc_id, relevance}` only — **no `source` field on any entry**, ever.
- **`~/Projects/BimodalLogic/specs/literature-index.json`** (2 entries): top-level has `version: 1`, `updated`. Entries use **`reason` instead of `relevance`**, plus rich, load-bearing extra fields not in the nominal schema at all: `citation_rule`, `hazard`, `known_corrections` (array), `audits` (array of report paths). This is not junk — it is exactly the kind of citation-fidelity annotation infrastructure that tasks #835/#839 exist to protect (the `hazard` field on `rabinovich_2014` documents a real, still-live citation-fidelity defect: a paraphrase `.md` was replaced by a raw PDF extract that drops every displayed equation and semantically inverts one inequality).
- Only `literature-create-setup-task.sh`'s generated task description and the (dead) SKILL.md "Add" block write the nominal `{doc_id, relevance, added, source}` shape — no live sub-index currently matches it.

**Implication for Job 2**: schema conformance checking must not naively flag BimodalLogic's `reason`/`citation_rule`/`hazard`/`known_corrections`/`audits` fields as violations to be silently normalized away — that would destroy load-bearing curation data der text, directly contradicting the task's own constraint ("never delete or rewrite a human-curated sub-index entry"). Job 2 should check only for the **structural minimum** (`doc_id` present and non-empty, and *either* `relevance` *or* `reason` present as a human-readable annotation) and report entries missing even that minimum, rather than enforcing the single nominal shape verbatim. This is a plan-level design decision to flag explicitly, not something research should silently resolve.

### Global / Sub-Index Schema (verified by reading live files)

**Global `~/Projects/Literature/index.json`** — `entries[]`, union of fields across two co-existing schemas:
- Primary (273/282 entries, `sources/`-rooted): `id, bib_key, title, authors[], year, section, path, page_range, token_count, keywords[], summary, doc_type, source_format, zotero_key, zotero_path, project_tags[], provenance_fidelity, word_ratio, parent_doc, ingested_at`.
- Legacy (9/282 entries, non-`sources/`-rooted, from a different repo's `literature-ingest.sh` run): `doc_id, title, authors[], year, source_path, chunks_dir, chunk_count, ingested_at` — **no `id`, `path`, or `provenance_fidelity` field**. `chunks_dir` points directly under `~/Projects/Literature/`, not `sources/<dir>/`.
- `provenance_fidelity` enum values present: `null, "no_source_pdf", "not_yet_converted", "unadjudicated", "verified_conversion"`. 108 entries currently carry `"verified_conversion"`.

**Global `.literature.db`** (SQLite, `literature-schema.sql`, task #833's 3-table + trigram-fallback architecture): `chunks_data` (canonical, 3942 rows, 83 distinct `doc_id`), `chunks_fts` (FTS5 over `chunks_data`), `chunks_trigram` (substring fallback), `chunk_relations`, `document_metadata` (schema declares one row per document; **currently 0 rows** — worth a one-line flag to the planner, likely a separate pre-existing gap, not in `--rebuild`'s scope to fix but worth noting since Job 4's per-directory audit might naturally want to query this table and find it empty).

**Per-repo sub-index** — see Schema Conformance Reality above; no single live shape to normalize toward without user input.

### Job-by-Job Implementation Mapping

1. **Dangling-ref lint** — read-only, mechanical. Reuse SKILL.md's dead "Validate" sub-index block (lines 1719-1753) almost verbatim: for each `doc_id` in `specs/literature-index.json`, assert `jq -e --arg id "$doc_id" '.entries[] | select(.id == $id)'` against `$LITERATURE_DIR/index.json` succeeds. Note: because of the legacy `chunks_dir` schema, some global-index entries have no `id` field at all under a different key layout — but they still key on `id` for those that have it (`doc_id` in the legacy schema is a *different* concept, the local project's own id, not a cross-reference target), so no special-casing needed here specifically; the legacy-schema concern is Job 4's problem, not Job 1's.
2. **Schema conformance check** — read-only, mechanical. Structural-minimum check (see above) plus a `chunk-file-conventions.md` conformance check: grep sub-index doc_ids against directory names under `sources/` to ensure none of them accidentally reference a `chunk_NNNN` id directly (chunk files are index-only re-splits and must never be independently referenced as a sub-index `doc_id` — verify no sub-index `doc_id` matches the `^chunk_\d+$` pattern or points at a `chunk_*.md` path).
3. **Coverage refresh** — the only writer, and only after user confirmation. Reuse the SKILL.md "Add" block's *validation* half (confirm `doc_id` exists in global index before appending) but drive candidate generation from `project_tags`/`keywords`/`summary` matching against this repo's domain — same signal set `literature-create-setup-task.sh`'s task description already documents as the intended approach, but that script only *creates a task*, it does not perform the matching itself; `--rebuild`'s coverage-refresh job needs new LLM-driven matching logic (no existing script does this), followed by an `AskUserQuestion`-gated diff/confirm before any write, then append via the existing jq append pattern (adapted to write `relevance`, not blindly overwrite the sub-index's existing per-file shape).
4. **Chunk/search-index coverage audit** — read-only, mechanical, and (per this research) auditing a **currently-real gap**: iterate every `sources/<dir>/` (97 dirs) plus every legacy top-level `chunks_dir`-schema entry (9-11 dirs) and check for a non-zero `SELECT count(*) FROM chunks_data WHERE doc_id = ...` (join through `parent_doc`-fan-out where a directory maps to multiple child doc_ids, as documented in `literature-fidelity-audit.sh`'s "Target entry resolution" comment for `thomas_2003_reactive`, `doets_1987`, `venema_1991`, `thomason_1984`). Also assert no directory's chunk set includes a chunked `.md.bak-*`/`.md.rejected` file (defensive; not currently triggered, see Hazard (b) above). This job needs either direct `sqlite3` queries or a new small read-only script — no existing script currently answers "does directory X have chunk coverage" per-directory; `literature-build-index.sh` only rebuilds the whole DB from whatever `chunks.json` manifests exist on disk, it does not report *absence*.

### AskUserQuestion multiSelect Job-Picker Design

Precedent for `multiSelect: true` interactive pickers is well-established throughout this same SKILL.md (discover-mode source selection, search-mode result selection, convert-mode keyword/summary editing) — same `{"question", "header", "multiSelect": true, "options": [{"label", "description"}]}` shape applies directly. Suggested options for `--rebuild`:
```json
{
  "question": "Which sub-index rebuild checks should run?",
  "header": "Sub-Index Rebuild Jobs",
  "multiSelect": true,
  "options": [
    {"label": "Dangling-ref lint (default on)", "description": "Mechanical, read-only. Flags doc_ids that no longer resolve in the global index."},
    {"label": "Schema conformance check (default on)", "description": "Mechanical, read-only. Flags entries missing doc_id or a relevance/reason annotation."},
    {"label": "Coverage refresh", "description": "Requires judgment. Proposes newly-relevant docs from the global corpus; nothing is written without a follow-up confirmation."},
    {"label": "Chunk/search-index coverage audit", "description": "Mechanical, read-only. Checks that every converted document in your sub-index (and the global corpus at large) has FTS5 search coverage."}
  ]
}
```
Two mechanical, always-safe jobs (1, 2) pre-checked by default per the task description; job 3 (the only writer) and job 4 (global-corpus-scope, not just this repo's sub-index) left unchecked by default since they are heavier / broader in scope than "check my sub-index."

### Constraints Confirmed / Elaborated

- Jobs 1, 2, 4 are read-only and idempotent — confirmed feasible with existing jq/sqlite3 patterns already used elsewhere in this extension; no new mutation risk.
- Job 3 is the only writer, gated by an explicit confirm-after-diff `AskUserQuestion`, using the same append-only jq pattern as the existing (dead) "Add" block, never the "Remove" block (removals of dangling refs must themselves be a separate, explicitly confirmed action per the task description — no job in the four automatically removes anything).
- `--dry-run` should be supported uniformly: since jobs 1/2/4 never write regardless, `--dry-run` only meaningfully changes Job 3's behavior (skip the confirm-and-write step, only print the proposed diff) — plan should make this explicit rather than treating `--dry-run` as a fifth independent flag per job.
- Sub-index-absent case: detect `! -f specs/literature-index.json` before presenting the job picker at all, and route straight to the existing `literature-create-setup-task.sh` (or the interactive `PROMPT_NEEDED`/`AUTONOMOUS_GLOBAL` flow already used by `--lit`, if the planner decides consistency with that UX is more valuable than a bespoke message) rather than presenting a job picker with nothing to check.

## Decisions

- `--rebuild` inserted as a new top-priority flag branch in `literature.md`'s mode-detection step, mutually exclusive with `--validate`/`--index`/`--convert`.
- Job 1's dangling-ref lint and Job 2's structural-minimum schema check reuse/adapt the existing dead "Sub-Index Management > Validate" block in `skill-literature/SKILL.md` rather than being written from scratch.
- Job 2 must NOT enforce the task description's nominal `{doc_id, relevance, source}` shape verbatim — live sub-indexes diverge from it in load-bearing ways (BimodalLogic's `reason`/`hazard`/`citation_rule`/`known_corrections`/`audits`). Structural-minimum check only; full-shape normalization is out of scope and would be destructive.
- Job 4 needs a new per-directory audit (no existing script currently reports per-directory chunk/search-index absence) — direct `sqlite3` queries against `chunks_data`/`document_metadata`, joined against both the `sources/`-rooted and legacy `chunks_dir`-rooted global-index entries.
- Sub-index-absent case defers to `literature-create-setup-task.sh` before presenting any job picker.

## Risks & Mitigations

- **Risk**: Job 4's directory→doc_id resolution is non-trivial (parent/child fan-out, legacy schema, 25/97 directories currently show zero coverage which may include both true gaps and id-mapping false positives). **Mitigation**: mirror `literature-fidelity-audit.sh`'s already-solved "Target entry resolution" logic (root-vs-child fallback) rather than re-deriving it; treat the 25-directory list in this report as a starting point for the planner to spot-check, not a final ground truth.
- **Risk**: Job 3 (coverage refresh) requires genuine LLM judgment over `project_tags`/`keywords`/`summary` — no existing script performs this matching; it must be new agent-driven logic (not purely mechanical bash), which is a bigger implementation lift than jobs 1/2/4. **Mitigation**: plan should size Job 3 as its own phase, distinct from the mechanical jobs.
- **Risk**: `document_metadata` table is unexpectedly empty (0 rows) — if the planner's Job 4 design leans on it, results will be uniformly wrong. **Mitigation**: this report flags it explicitly; Job 4 should query `chunks_data`, not `document_metadata`, unless the planner separately decides to fix the table's population first (out of scope for #840 unless the planner chooses to fold it in).
- **Risk**: Repeating the mistake `literature-ingest.sh` writing outside `sources/<dir>/`, or `--convert` never chunking, is a pre-existing pipeline gap, not something `--rebuild` itself introduces — `--rebuild` is read-only-by-default and audits this, it does not fix the underlying pipeline. **Mitigation**: report should make clear to the planner that Job 4 is a detector, not a repair tool; whether to also propose an auto-chunk repair action is a planner decision, not implied by the task description.

## Context Extension Recommendations

- **Topic**: `document_metadata` table population.
- **Gap**: The SQL schema declares `document_metadata` as a one-row-per-document table, but the live global `.literature.db` has 0 rows in it. No existing context file documents whether this is intentional (table unused/vestigial) or a defect.
- **Recommendation**: Not urgent for this task; if the planner's Job 4 design touches this table, a short note in `.claude/context/project/literature/domain/literature-index.md` about `document_metadata`'s actual (non-)usage would prevent future confusion.

## Appendix

### Search queries / commands used

- `jq` reads against `~/Projects/Literature/index.json`, `~/Projects/cslib/specs/literature-index.json`, `~/Projects/BimodalLogic/specs/literature-index.json`, this repo's absent `specs/literature-index.json`.
- `sqlite3 ~/Projects/Literature/.literature.db ".tables"`, row counts on `chunks_data`, `document_metadata`, distinct `doc_id` counts.
- `comm -23` between `sources/` directory listing and `chunks_data` distinct doc_ids to find the 25-directory coverage gap.
- `find ~/Projects/Literature -iname "*.md.bak-*" -o -iname "*.md.rejected"` — 6 quarantine artifacts confirmed live (4 `.bak`, 2 `.rejected`, including a `troelstra_schwichtenberg_2000` rejection not mentioned in the #841/#840 baseline text).

### Files read in full

- `.claude/extensions/literature/commands/literature.md`
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` (both halves, ~1782 lines)
- `.claude/extensions/literature/scripts/literature-create-setup-task.sh`
- `.claude/extensions/literature/scripts/literature-schema.sql` (schema portion)
- `.claude/context/project/literature/patterns/chunk-file-conventions.md`
- `specs/841_reconcile_literature_extension_source_drift/summaries/01_reconciliation-summary.md`
