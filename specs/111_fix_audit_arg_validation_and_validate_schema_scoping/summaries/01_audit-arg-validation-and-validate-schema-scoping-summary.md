# Implementation Summary: Fix literature-audit.sh arg validation and /literature --validate schema scoping

- **Task**: 111 - Fix literature-audit.sh arg validation and /literature --validate schema scoping
- **Status**: [COMPLETED]
- **Started**: 2026-09-02T06:00:00Z
- **Completed**: 2026-09-02T06:39:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_audit-arg-validation-and-validate-schema-scoping.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Two independent correctness fixes landed in the literature extension source store
(`agent-system/extensions/literature/`). Phase 1 gave `literature-audit.sh` proper usage/help
handling and loud argument rejection, matching the convention already used by
`literature-ingest-online.sh`. Phase 2 scoped `/literature --validate`'s required-schema-field
check to top-level document entries only, eliminating ~11k false-positive warnings on
section/chunk entries and reconciling the Step 2 prose with what the check actually enforces.

## What Changed

- `agent-system/extensions/literature/scripts/literature-audit.sh` — added a `usage()` function
  (heredoc mirroring `literature-ingest-online.sh:153-163`, body reproducing the script header's
  three documented invocation forms verbatim, plus `-h, --help`); added a `-h|--help) usage;
  exit 0 ;;` case arm before the catch-all; replaced the silent `*) shift ;;` catch-all with
  `*) echo "literature-audit.sh: unknown argument: $1" >&2; usage; exit 64 ;;`; hardened the
  `--pdf` arm to reject a missing or flag-shaped operand with a stderr message and `exit 64`,
  landed as a separate hunk/commit from the usage/unknown-arg change.
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` — gated the
  `missing_fields` jq block (Validate Step 2) on `.parent_doc == null or .parent_doc == ""`
  (literature-coverage-delta.sh:212's predicate, reused verbatim), so section/chunk entries no
  longer populate `schema_warnings[]`; rewrote Step 2 prose point 3 to state the top-level-only
  scope and the actual 4-field list enforced (`doc_type`, `source_format`, `authors`, `title`),
  closing the pre-existing 7-fields-documented/4-fields-checked gap; clarified which checks
  section entries remain subject to (existence, token-count drift, authors-shape; schema-shape
  bucket for `id`/`path`); adjusted the Step 4 report heading to
  "top-level document entries missing required v2 fields" for accuracy, keeping the per-entry
  line format unchanged.

## Decisions

- Landed the Phase 1 `-h|--help`/usage-and-unknown-arg hunk and the `--pdf` operand-guard hunk as
  two separate commits, per the plan's contingency design — the enumeration below found no
  in-repo programmatic caller, so both hunks were kept, but they remain independently revertible.
- Kept the existing `authors`-shape check (point 4) untouched and unscoped, as instructed — it is
  a no-op for section entries in practice (their `.authors` is `null`), so it required no
  special-casing to remain correct under the new scoping.
- Left the book/parent `doc_type: "book"` note (SKILL.md ~line 431) unchanged: that record is
  itself top-level (`parent_doc` unset) and is covered by the new predicate without any separate
  carve-out.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (shell script + markdown, no build step)
- Tests: Passed — see below
- Files verified: Yes

**Phase 1**:
- `bash -n literature-audit.sh` parses clean.
- `shellcheck` not installed in this environment; noted rather than skipped silently — no
  shellcheck-based comparison was possible.
- `literature-audit.sh --help` prints usage to stderr, exits 0, and produces **zero side
  effects** (confirmed via `ls /tmp` diff before/after — no new files written, no conversion run).
- `literature-audit.sh --bogus` prints `literature-audit.sh: unknown argument: --bogus` plus
  usage, exits 64.
- `literature-audit.sh --pdf` (no operand) prints `literature-audit.sh: --pdf requires a path
  argument`, exits 64.
- The usage heredoc text agrees line-for-line with the script header's documented invocation
  forms (lines 9-11).
- Caller enumeration (`grep -rn 'literature-audit' agent-system/ .claude/`): the script is
  referenced only in `manifest.json` (file listing) and two documentation files
  (`format-decision.md`, `corpus-directory-conventions.md`) — no in-repo programmatic invocation
  with arguments exists, so the `--pdf` hardening hunk was kept.
- All four documented invocation shapes (`--pdf <path>`, `--xref <path>`, `--all`, bare
  `*.pdf`/`*.djvu` positional) still dispatch to the same mode/pdf-list behavior as before,
  confirmed via an isolated harness reproducing the case block.

**Phase 2** (before/after counts against the real global index, `~/Projects/Literature/index.json`,
11,545 total entries — this repo has no local `specs/literature-index.json`):
- **Before** (unscoped): 11,093 entries would populate `schema_warnings[]` (11,078 missing
  `doc_type`, 11,043 missing `authors` — essentially all of them section-level chunks).
- Top-level population (`parent_doc` null/empty): 292 entries — confirms the predicate does not
  leave a "still in the thousands" population, per the Scope Hypothesis stop condition.
- **After** (scoped): 50 entries populate `schema_warnings[]` — all verified top-level.
- Spot-check: `blackburn_2002_book` (well-formed top-level book/parent entry, `token_count: 0`)
  does **not** appear in the post-fix warnings.
- Spot-check: `henkin_1949` (genuine top-level defect, missing `source_format`) is **still**
  reported — the fix does not suppress real findings. (One book-typed top-level entry,
  `schultz-spivak-temporal-type-theory`, also still legitimately appears — missing
  `source_format` — confirming the book carve-out needed no special-casing.)
- The edited jq expression was verified in isolation on representative synthetic top-level and
  section-entry JSON: the section entry yields empty output, a deficient top-level entry yields
  its field list, a complete top-level entry yields empty output.
- Step 2 prose field list (`doc_type`, `source_format`, `authors`, `title`) now matches the jq
  block's field list exactly.
- `git status --short` in `~/Projects/Literature` shows no change caused by this task's read-only
  `jq` queries against `index.json` (only pre-existing, unrelated repo state); no index data was
  written by this task in either repository.

## Impacts

- `literature-audit.sh --help` (and any future scripted use of `-h`/`--help`) now returns
  immediately with usage text instead of silently launching a live audit.
- Any future caller of `literature-audit.sh` gets a loud, actionable error (exit 64 + message)
  instead of a silently-ignored flag or a mis-parsed `--pdf` invocation.
- `/literature --validate` schema-warning output drops from ~11k noise entries to ~50 genuine,
  actionable top-level defects, making the real corpus data issues (out of scope for this task)
  far easier to see and triage in a future pass.

## Follow-ups

- The ~137 genuine corpus data defects (75 missing `keywords`, 62 missing `summary`, 2
  comma-joined author strings) remain unfixed by design — this task changed the check, not the
  data. A future task could fix these now that they are no longer buried in noise.
- `keywords` and `summary` are still not enforced by any check (the prose now states this
  honestly rather than implying otherwise); adding real checks for them, if desired, would be a
  separate, scoped follow-up.

## References

- Plan: `specs/111_fix_audit_arg_validation_and_validate_schema_scoping/plans/01_audit-arg-validation-and-validate-schema-scoping.md`
- Research: `specs/111_fix_audit_arg_validation_and_validate_schema_scoping/reports/01_audit-arg-validation-and-validate-schema-scoping.md`
