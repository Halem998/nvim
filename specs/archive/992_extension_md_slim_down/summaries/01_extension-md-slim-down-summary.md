# Implementation Summary: Task #992

- **Task**: 992 - Trim the 6 over-length live EXTENSION.md files; resolve the 2 dead ones
- **Status**: [COMPLETED]
- **Started**: 2026-08-09T00:00:00Z
- **Completed**: 2026-08-09T17:30:00Z
- **Effort**: ~8.5 hours (across two dispatch sessions)
- **Dependencies**: 987, 990, 991
- **Artifacts**: plans/01_extension-md-slim-down.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, extension-slim-standard.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Brought every live `EXTENSION.md` in `agent-system/extensions/**` into conformance with
`extension-slim-standard.md` (four required sections, 60-line ceiling, per-section budgets) and
resolved the two dead `EXTENSION.md` files, so the follow-on gate promotion can flip
`SCHEMA_CONFORMANCE_GATE_MODE` to `hard` with no standing Rule U failures. Six over-length live
files (literature, email, lean, cslib, present, nix) were trimmed by relocating detail content
into each extension's existing `context/project/{ext}/{domain,patterns,tools}/` tree, and two dead
files (core, slidev) were deleted after making `check-extension-docs.sh`'s required-file check and
Rule U manifest-authoritative on `merge_targets.claudemd.source`.

## What Changed

### Sub-scope A: 6 live files trimmed

| Extension | Before | After | New/merged context files |
|-----------|-------:|------:|---------------------------|
| `literature/EXTENSION.md` | 169 | 33 | domain/{literature-index,format-decision,extension-dependencies,sparse-coverage,zotero-integration}.md; patterns/{agent-exploration,cite-workflow,literature-command-modes,zotero-item-creation,zotero-pdf-resolution}.md; tools/{zotero-scripts,literature-dir-config}.md |
| `email/EXTENSION.md` | 106 | 37 | domain/index-architecture.md (new, resolves prior dangling reference); domain/safety-invariants.md (new); README.md (Key Technologies folded in) |
| `lean/EXTENSION.md` | 73 | 35 | domain/hard-mode.md (new); tools/mcp-tools-guide.md (merged); README.md (pointer added) |
| `cslib/EXTENSION.md` | 71 | 33 | domain/hard-mode-selection.md (new); MCP Integration and CI pipeline content merged into existing tools/standards files, no near-duplicate created |
| `present/EXTENSION.md` | 64 | 35 | domain/talk-modes-and-library.md (new); Language Routing folded into a single Routing table |
| `nix/EXTENSION.md` | 62 | 31 | tools/mcp-nixos-integration.md (new); domain/flakes.md (Build Verification merged in); README.md (Key Technologies added, Context Categories section dropped) |

Every new/merged file carries a schema-conformant `index-entries.json` entry (`path`, `domain`,
`subdomain`, `summary`, `line_count`, `load_when`; no `description`/`tags`). During the final gate
phase, 3 overlong `summary` fields (>200 chars, across 2 literature entries and 1 email entry)
discovered by `jsonschema` validation were shortened in place.

### Sub-scope B: 2 dead files resolved (deleted, not trimmed)

- `agent-system/extensions/core/EXTENSION.md` (62L) — deleted. `core` points
  `merge_targets.claudemd.source` at `merge-sources/claudemd.md`, so `EXTENSION.md` was never
  reachable from `generate_claudemd()`'s merge path and was a 100% content subset of `core/README.md`.
- `agent-system/extensions/slidev/EXTENSION.md` (12L) — deleted. `slidev` is a resource-only
  extension (no `provides.skills`/`provides.commands`) with no `merge_targets.claudemd` at all.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — made manifest-authoritative on
  `merge_targets.claudemd.source` for both the required-file check and Rule U, with a
  never-silent accidental-omission advisory for a non-resource-only extension missing the key.
- `agent-system/extensions/core/README.md`,
  `agent-system/extensions/core/docs/architecture/extension-system.md`,
  `agent-system/extensions/core/docs/guides/adding-domains.md`,
  `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md` — repointed
  stale cross-references and recorded the delete-vs-redefine-authority rationale durably.

## Decisions

- Both dead files were **deleted**, not trimmed, per the plan's decision and the research
  finding that each was a 100% content subset of its own `README.md` — trimming a dead file
  would have been the one explicitly-named wrong outcome.
- `check-extension-docs.sh` was made manifest-authoritative on `merge_targets.claudemd.source`
  (narrowing scope, not disabling the gate) rather than hardcoding an `EXTENSION.md`-must-exist
  assumption, so future resource-only or alternate-claudemd-source extensions are handled
  correctly without a special case.
- Where an existing context file already covered a section's material (literature's
  `literature-index.md`/`format-decision.md`, cslib's `lake-commands.md`/`ci-pipeline.md`, nix's
  `nixos-rebuild-guide.md`/`home-manager-guide.md`, present's `presentation-types.md`), content was
  merged into the existing file rather than creating a near-duplicate sibling.
- `email` and `lean`'s Context Pointers use a `.claude/`-prefixed `@`-pointer form, matching the
  pre-existing (untouched) `nvim` extension's established convention, rather than the bare
  `context/...` form used by literature/present/cslib/nix. Both conventions already coexist in the
  repo; every referenced file exists under either interpretation, satisfying the plan's stated
  pointer-resolution bar. Not changed, since it mirrors a pre-existing pattern rather than
  introducing a new one.

## Plan Deviations

- **Phase 8, task "Validate every new/modified index-entries.json against the schema"** altered:
  jsonschema validation surfaced 3 pre-existing overlong `summary` fields (>200 chars) in
  literature (2) and email (1) `index-entries.json`, introduced during Phases 2-3 before this gate
  phase ran. Fixed in place by shortening the summaries below 200 characters while preserving
  their meaning; all 6 touched extensions' `index-entries.json` files now validate cleanly against
  `core/context/index.schema.json`.
- **Phase 1, task 1.6** (recorded previously in `progress/phase-1-progress.json`): initial
  verification used narrower criteria than a full exit-0 run because of a transient, self-resolving
  Rule F script-drift signal; the final state is a full clean PASS.

## Verification

- Build: N/A (documentation/config task)
- Tests: N/A
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`: exit 0,
  zero `Rule U` lines, all 19 extensions + project-wide report PASS.
- Same command with `SCHEMA_CONFORMANCE_GATE_MODE=hard`: exit 0, all 19 extensions PASS (dry proof
  the follow-on gate-mode flip is unblocked; the script's default was left untouched).
- `bash .claude/scripts/generate-context-line-counts.sh --check`: "CHECK PASSED: all line_count
  values are exact" — 480/480 entries across all 19 extensions.
- `bash .claude/scripts/check-task-references.sh`: "PASS: 0 unexempted task-reference occurrences
  across 4 tree(s)".
- `bash .claude/scripts/lint/lint-routing-wiring.sh`: "ROUTING WIRING LINT PASSED" — 323 passed, 0 failed.
- `jsonschema` validation of all 6 touched extensions' `index-entries.json` against
  `core/context/index.schema.json`: all VALID (after the 3-summary fix above).
- `git status --short -- .claude/`: empty — no file under `.claude/**` was modified by this task.
- All 27 `@`-pointers across the 6 trimmed `EXTENSION.md` files resolve to an existing file on disk.
- 17 `EXTENSION.md` files exist across 19 extension directories (core, slidev deleted); the largest
  surviving file (`formal`, untouched by this task) is exactly 60 lines, at but not over the ceiling.
- Files verified: Yes

## Impacts

- The follow-on task to flip `SCHEMA_CONFORMANCE_GATE_MODE` from `advisory` to `hard` is now
  unblocked: a live hard-mode dry run already reports zero failures.
- Agents consuming `email-implementation-agent`/`task_types: email` continue to auto-load the
  full safety-invariants content via `load_when`, even though it no longer appears inline in
  generated CLAUDE.md.
- `core` and `slidev` no longer carry a dead, unreachable `EXTENSION.md`; any future extension in
  either situation (alternate claudemd source, or resource-only with no claudemd target) is
  handled correctly by the checker without needing a bespoke exception.

## Follow-ups

- Flip `SCHEMA_CONFORMANCE_GATE_MODE` to `hard` in `check-extension-docs.sh` (explicitly named
  as this task's non-goal / the next task).
- Consider normalizing the `@`-pointer convention (`context/...` vs `.claude/context/...`) across
  `nvim`, `email`, and `lean` in a future pass — out of scope here since every referenced file
  exists under either interpretation and this task's verification bar did not require unifying
  the convention.

## References

- Plan: `specs/992_extension_md_slim_down/plans/01_extension-md-slim-down.md`
- Research: `specs/992_extension_md_slim_down/reports/01_extension_md_slim_down.md`
- Progress: `specs/992_extension_md_slim_down/progress/phase-{1..8}-progress.json`
- Standard: `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md`
