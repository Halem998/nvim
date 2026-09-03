# Research Report: Task #111

- **Task**: 111 - Fix literature-audit.sh arg validation and /literature --validate schema scoping
- **Started**: 2026-09-02T06:00:00Z
- **Completed**: 2026-09-02T06:15:53Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Sources/Inputs**: Codebase (agent-system/extensions/literature/scripts/literature-audit.sh, agent-system/extensions/literature/scripts/literature-ingest-online.sh, agent-system/extensions/literature/scripts/literature-coverage-delta.sh, agent-system/extensions/literature/skills/skill-literature/SKILL.md)
- **Artifacts**: This report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Edit target confirmed**: `agent-system/extensions/literature/` is the source store; `diff` against the deployed `.claude/scripts/literature-audit.sh` copy confirms it is byte-identical, so no drift reconciliation is needed. `.claude/` copies must never be hand-edited (`.claude/rules/source-store-deploy-boundary.md`).
- **Defect 1 confirmed as described**: `literature-audit.sh`'s arg-parsing loop (`agent-system/extensions/literature/scripts/literature-audit.sh:381-388`) has a catch-all `*) shift ;;` that silently swallows any unrecognized argument (including `-h`/`--help`) and falls through to running the default `--all` audit. There is no `usage()`/`show_usage()` function in this script today.
- **Sibling convention identified for the fix**: `literature-ingest-online.sh` already implements the exact pattern to mirror — a `show_usage()` heredoc (lines 153-163), `-h|--help)` exiting 0, and an unknown-argument branch that prints an error plus usage to stderr and exits 64 (lines 190-202, 196-202). Task 111 should reuse this exit-64/stderr convention rather than invent a new one.
- **Defect 2 confirmed and quantified**: `SKILL.md`'s Validate Step 2 prose (line 380) states 7 required fields apply to "each indexed entry," and the implementing `missing_fields` jq check (lines 457-464) checks `doc_type`, `source_format`, `authors`, `title` against every entry regardless of level. This does not scope by document vs. section, so it fires on the ~11k section-level entries that legitimately lack those document-level fields.
- **Reuse target for the fix confirmed**: `literature-coverage-delta.sh:212`'s `select(.parent_doc == null or .parent_doc == "")` is the existing top-level-document predicate; task 111 should reuse it verbatim rather than inventing a `path` trailing-slash predicate (the trailing-slash check already exists nearby for a different purpose — directory-vs-file existence handling, lines 413-422 — and is not the same distinction).
- **No conflict with the existing book/parent exception**: the `doc_type: "book"` / `token_count: 0` parent-record carve-out documented at `SKILL.md:426-427` is itself a top-level document entry (a directory-path parent with `parent_doc` unset), so it already satisfies a `doc_type`-present check under the corrected scoping — no additional special-casing is needed beyond adopting the shared top-level predicate.

## Context & Scope

Task 111 asks for two small, independent, verified-still-present correctness fixes in the literature extension's tooling, both observed during a live `/research --lit` run and re-verified against the source store at task-creation time. This research re-verifies both defects directly in the source store (not the deploy copy), locates the exact lines to change, and identifies the existing in-repo conventions each fix should reuse rather than reinvent. No implementation was performed; this report hands a concrete, line-numbered fix plan to the planning/implementation phase.

## Findings

### Defect 1 — `literature-audit.sh` swallows unknown arguments

**File**: `agent-system/extensions/literature/scripts/literature-audit.sh`

Current arg-parsing loop (lines 379-389, inside `main()`):

```
  local mode="all"
  local explicit_pdfs=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pdf) shift; explicit_pdfs+=("$1"); shift ;;
      --xref) mode="xref"; shift ;;
      --all) mode="all"; shift ;;
      *.pdf|*.djvu) explicit_pdfs+=("$1"); shift ;;
      *) shift ;;
    esac
  done
```

Confirmed behaviors:
- `-h` / `--help` (or any other unrecognized token) falls into the final `*) shift ;;` arm, is silently discarded, and `mode` stays at its default `"all"` — so `literature-audit.sh --help` runs the full audit (which includes live PDF conversion against a Zotero-storage PDF via `audit_conversion`/`check_tools`), instead of printing usage and exiting.
- `--pdf) shift; explicit_pdfs+=("$1"); shift ;;` unconditionally appends `$1` after the first `shift`, with no check that a following token exists or is non-flag. A trailing bare `--pdf` (nothing after it) appends an empty string to `explicit_pdfs`, and `--pdf --xref` would append the literal string `--xref` as a "PDF path" while also consuming the token `--xref` was supposed to set as a mode flag.
- The script's own header (lines 8-11) documents exactly three legitimate invocation forms:
  ```
  literature-audit.sh [--pdf <path>...]       # Audit conversion quality
  literature-audit.sh --xref [<pdf>...]        # Audit cross-reference extraction
  literature-audit.sh --all [<pdf>...]         # Run both audits
  ```
  There is no `usage()`/`show_usage()` function anywhere in the file (`grep -n "usage\(\)"` returns nothing) — the header comment is documentation only, never surfaced to a user who passes an unrecognized flag.

**Convention to mirror**: `agent-system/extensions/literature/scripts/literature-ingest-online.sh` already implements the target pattern for this codebase:
- `show_usage()` (lines 153-163) — a `cat >&2 << 'USAGE' ... USAGE` heredoc.
- `-h|--help)` case arm (lines 190-193): `show_usage; exit 0`.
- Unknown-argument case arm (lines 196-202, the `*)` default): prints `"literature-ingest-online.sh: unknown argument: $1"` to stderr, calls `show_usage`, and `exit 64`.
- The exit code 64 is documented codebase-wide as the usage-error convention (lines 107-108: `64  Argument/usage error or malformed/unsupported input record`), and is echoed in `literature-audit.sh`'s companion task description as "matching the usage-error convention literature-ingest-online.sh already uses."

**Fix shape** (for the implementation phase): add a `usage()` function to `literature-audit.sh` (heredoc built from the existing header lines 9-11, `>&2`), add a `-h|--help)` arm that calls it and `exit 0`, and change the final catch-all from `*) shift ;;` to print an "unknown argument: $1" message plus usage to stderr and `exit 64`. Additionally harden `--pdf)` to fail loudly (rather than silently append an empty/wrong path) when `$2` is missing or itself looks like another recognized flag.

### Defect 2 — `/literature --validate` applies document-level schema rules to section entries

**File**: `agent-system/extensions/literature/skills/skill-literature/SKILL.md`

Prose statement (Validate Step 2, point 3, line 380):
> 3. Required schema fields present: `id`, `path`, `token_count`, `keywords`, `summary`, `doc_type`, `source_format`

This is stated as applying to "each indexed entry" (Step 2's heading, line 372) with no document/section distinction, even though the file already documents the two-tier index shape immediately above (point 1, line 377: "directory-path entries (book/parent-level records whose `path` ends in `/`)").

Implementing check (`missing_fields`, lines 457-464):

```bash
  missing_fields=$(echo "$entry_json" | jq -r '
    [
      (if .doc_type == null or .doc_type == "" then "doc_type" else empty end),
      (if .source_format == null or .source_format == "" then "source_format" else empty end),
      (if .authors == null then "authors" else empty end),
      (if .title == null or .title == "" then "title" else empty end)
    ] | join(", ")
  ' 2>/dev/null || echo "")
  if [ -n "$missing_fields" ]; then
    schema_warnings+=("$entry_path (missing fields: $missing_fields)")
  fi
```

Note the implementation only actually checks 4 fields (`doc_type`, `source_format`, `authors`, `title`) — not the 7 the prose lists (`id`/`path`/`token_count`/`keywords`/`summary` are absent from the jq check; `id`/`path` are separately covered earlier by the schema-shape-defects bucket at lines 397-411, and `keywords`/`summary` are not checked by this script at all). This mismatch between prose and implementation is pre-existing; task 111's directive ("Keep the Step 4 report section... coherent with whatever scoping is chosen") means the fix should reconcile the prose wording with whatever the corrected jq check actually enforces, not silently leave them further apart.

This `missing_fields` check runs unconditionally for every entry that reaches it (both file-path and directory-path entries alike — the comment at lines 453-455 confirms "this runs for every entry that resolves on disk — directory-path entries included"), which is the direct cause of the ~11k false positives task 111 reports (11,078 lacking `doc_type`, 11,043 lacking `authors` — both are genuinely absent on section-level chunk entries by design, since those fields live only on the parent/document record).

**Reuse target for the top-level-document predicate**: `agent-system/extensions/literature/scripts/literature-coverage-delta.sh:212` already draws exactly this distinction:

```bash
done < <(jq -r '.entries[] | select(.parent_doc == null or .parent_doc == "") | ...' "$GLOBAL_INDEX" 2>/dev/null)
```

This is the "same predicate" task 111 asks to reuse rather than inventing a second one (e.g. a `path`-ends-with-`/` check, which SKILL.md already uses nearby for a *different* purpose — see below — and is not equivalent: a directory-path parent record for a multi-chunk book has a trailing-slash `path` AND `parent_doc == null`, but the trailing-slash test alone would not by itself distinguish "top-level document" from "any directory," and per the task's own instruction, `literature-coverage-delta.sh`'s `parent_doc`-based predicate is the one to standardize on).

**No conflict with the existing book/parent exception**: `SKILL.md:426-427` already documents a directory-path parent-record variant ("legitimate second schema variant: parent-level records for a book split into many semantic chunks (`doc_type: "book"`, `token_count: 0` by design)"). This parent record is itself a top-level document entry (it has no `parent_doc`, since it's the root of the book's own entry tree) and already carries `doc_type: "book"` by construction — so scoping the `missing_fields` check to top-level entries via the `parent_doc` predicate does not need a second, parallel special case for this book variant; it is already covered by (and consistent with) the corrected scoping.

**Report section to reconcile** (Validate Step 4, line 653):
> `### Schema Warnings ({count}) — entries missing required v2 fields`

This header text and the per-entry line format immediately below it (`- {entry_path}: {missing_fields}`) do not themselves need structural changes, but the fix should make sure whatever entries populate `schema_warnings[]` after the scoping change are consistent with this heading's "required v2 fields" framing (i.e., the heading continues to describe document-level v2 fields correctly once section entries are excluded from firing it).

**Fix shape** (for the implementation phase):
1. Update Validate Step 2 prose (line 380) to state that the 7-field list applies to top-level document entries only, and that section entries are checked only for `id`, `path`, `token_count` (already covered by existing checks — see below).
2. Gate the `missing_fields` jq check (lines 457-464) on the same top-level-document predicate as `literature-coverage-delta.sh:212` (`.parent_doc == null or .parent_doc == ""`) — read from the already-parsed `entry_json`, no new file read required — so it only evaluates `doc_type`/`source_format`/`authors`/`title` for top-level entries and is skipped for section entries.
3. Confirm (or make explicit in the prose) that section entries' `id`/`path`/`token_count` obligations are already satisfied by the pre-existing checks that run for every entry regardless of level: the schema-shape-defects bucket (lines 397-411, covers `id`/`path`) and the token-count recount/drift check (lines 413-448, covers `token_count` presence implicitly via the file-path/directory-path branches). No new code path is needed for this part — only the prose should be corrected to say so, since it currently implies a separate 3-field check that doesn't exist in the script.
4. Leave the Step 4 report heading (line 653) as-is; verify post-fix that its "count" and per-entry lines only ever populate from genuine top-level-document defects, not section noise.

## Decisions

- Treat `.parent_doc == null or .parent_doc == ""` (from `literature-coverage-delta.sh:212`) as the single canonical top-level-document predicate for this fix, per the task's explicit instruction not to invent a second one.
- Treat `literature-ingest-online.sh`'s `show_usage()` / `-h|--help` / unknown-arg-exit-64 pattern (lines 153-163, 190-202) as the template for `literature-audit.sh`'s new usage handling, per the task's explicit instruction to match that existing convention.
- Scope of Defect 2 is the CHECK only (Validate Step 2 prose + the `missing_fields` jq block), not the underlying corpus data — the ~137 genuine data defects (75 missing keywords, 62 missing summary, 2 comma-joined authors) mentioned in the task are explicitly out of scope and are being handled by a separate, already-in-flight effort.

## Risks & Mitigations

- **Risk**: A parallel not-started task restructures this same SKILL.md into mode-gated sections. If that restructure lands first, the line numbers in this report (372-464, 653) will have moved.
  - **Mitigation**: task 111 was deliberately not made dependent on that restructure. If it has landed by the time this is implemented, re-locate "Validate Step 2" content by heading/anchor text (e.g. "Required schema fields present", "missing_fields=") rather than by the line numbers recorded here.
- **Risk**: Changing the `--pdf` arg-consumption behavior (checking `$2` exists/is non-flag) could change behavior for any existing caller that relies on the current lenient parsing.
  - **Mitigation**: task's own description frames this as a "cheap follow-on worth doing while here," not a hard requirement — implementation can choose to land the primary usage/unknown-arg fix first and treat the `--pdf` hardening as a small additional hunk in the same script, guarded by the same exit-64 convention.

## Context Extension Recommendations

None — both fixes are narrowly scoped, existing-convention-driven corrections to files already covered by `context/project/literature/domain/literature-index.md` (index schema) and the literature extension's own script/skill documentation. No new context file is warranted.

## Appendix

- Files read: `agent-system/extensions/literature/scripts/literature-audit.sh` (full), `agent-system/extensions/literature/scripts/literature-ingest-online.sh` (lines 1-245), `agent-system/extensions/literature/scripts/literature-coverage-delta.sh` (lines 190-225), `agent-system/extensions/literature/skills/skill-literature/SKILL.md` (lines 360-530, 640-665).
- Verification: `diff .claude/scripts/literature-audit.sh agent-system/extensions/literature/scripts/literature-audit.sh` — no output (byte-identical), confirming no drift between source store and deploy copy for this script.
