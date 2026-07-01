# Implementation Summary: Task #775

**Completed**: 2026-07-01
**Duration**: ~1.5 hours (6 phases)

## Overview

Removed the silent-empty fallback behavior of `--lit` when no per-repo literature sub-index
exists, and added a live global-corpus briefing option. All six `--lit`-aware skills
(skill-researcher, skill-planner, skill-implementer, and their `--hard` variants) now route
through a shared classification helper and present a non-silent three-option decision
(use global corpus now / create curation task / explicit skip), with a deterministic,
visibly-announced default for autonomous (`/orchestrate`) contexts.

## What Changed

- `.claude/extensions/literature/scripts/literature-briefing.sh` (+ mirror
  `.claude/scripts/literature-briefing.sh`) — added `--global "<query>" [--top-n N]` mode that
  runs a project-scoped `literature-search.sh` query (which internally retries unfiltered on zero
  results) and builds a briefing from the top-N (default 8) ranked chunks; refactored so both the
  per-repo and global-corpus modes share one output section that always appends the "How to Use"
  footer; per-repo no-arg silent-exit regression preserved.
- `.claude/extensions/literature/scripts/literature-lit-flag-resolve.sh` (new, + mirror
  `.claude/scripts/literature-lit-flag-resolve.sh`) — shared helper implementing the D1 directive
  contract: classifies `--lit-flag`/`--orchestrator-mode`/sub-index/global-index state into one
  of five directives (`LIT_DISABLED`, `SUBINDEX_PRESENT`, `GLOBAL_MISSING`, `PROMPT_NEEDED`,
  `AUTONOMOUS_GLOBAL`) printed as a single stdout token, with rationale on stderr.
- `.claude/skills/skill-researcher/SKILL.md`, `skill-planner/SKILL.md`,
  `skill-implementer/SKILL.md` — Stage 4a rewritten to call the shared helper and branch on the
  directive; `PROMPT_NEEDED` issues an `AskUserQuestion` with "Use global corpus now" / "Create
  curation task" / "Skip this run"; `AUTONOMOUS_GLOBAL` takes the "Use global corpus now" default
  with a visible `[lit:auto]` notice; `GLOBAL_MISSING` emits a visible notice; no branch defaults
  to an empty briefing silently.
- `.claude/skills/skill-researcher-hard/SKILL.md`, `skill-planner-hard/SKILL.md`,
  `skill-implementer-hard/SKILL.md` — identical Stage 4a rewrite applied (case/esac block is
  byte-identical across all six skill files).
- `.claude/extensions/core/merge-sources/claudemd.md` — rewrote the "Interactive Sub-Index Setup
  Detection" section to describe the new flow, the shared helper, the global-corpus briefing mode,
  and the `AUTONOMOUS_GLOBAL`/`[lit:auto]` default; added an inline scoping note pointing the
  broader `--lit` model rewrite to task 776; left the "What `--lit` Does" subsection untouched.

## Decisions

- Followed D1/D2/D3 from the plan verbatim: shared helper prints a directive token only
  (AskUserQuestion stays with the calling skill); three-option interactive flow with two live
  outcomes plus an explicit skip; `orchestrator_mode`-gated deterministic autonomous default.
- `literature-search.sh`'s own project-filter zero-result fallback (confirmed by source read) is
  relied upon rather than re-implemented in `literature-briefing.sh --global`.
- "Create curation task" was implemented as a single combined live outcome (create task +
  attempt inline fork-population + inject once populated) rather than a further nested choice,
  consistent with the plan's "exactly three options" constraint.

## Plan Deviations

- **Task 5.4** altered: no merge-source-to-`.claude/CLAUDE.md` generator script was found on disk
  (searched `.claude/scripts/` and the repo for "merge-sources" references). Per the plan's own
  Rollback/Contingency note, `claudemd.md` was left edited and regeneration was deferred to
  next extension load; `.claude/CLAUDE.md` was not manually edited.
- **Task 6.1** skipped: `check-extension-docs.sh` reports `FAIL: 2 issues`, but both are on the
  unrelated `lean` extension (`routing_hard` targets not deployed). Confirmed via `git stash` that
  this identical failure exists on `master` before any task-775 changes. The `literature`
  extension itself reports `OK`.

## Verification

- Build: N/A (bash scripts + markdown)
- Tests: Passed — `bash -n` on all 4 script copies; directive matrix (5/5 fixtures) verified;
  `--global` mode footer-terminated output verified live against the real global corpus;
  no-arg per-repo silent-exit regression verified; mirror pairs byte-identical (`diff -q`);
  cross-file Stage 4a case/esac block byte-identical across all six skills; autonomous-path
  simulation (`AUTONOMOUS_GLOBAL` -> footer-terminated global briefing) verified end-to-end.
- Files verified: Yes

## Notes

The pre-existing `lean` extension doc-lint failure (routing_hard targets `skill-lean-research-hard`
/ `skill-lean-implementation-hard` not deployed) is unrelated to this task and was not touched.
Task 776 owns the broader `--lit` model rewrite ("What `--lit` Does" / `literature-retrieve.sh`
narrative) in `claudemd.md`, intentionally left untouched here.
