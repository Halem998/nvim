# Implementation Summary: Task #941

- **Task**: 941 - Purge ephemeral task-management references from deliverables and enforce the rule going forward
- **Status**: [IN PROGRESS]
- **Started**: 2026-07-28
- **Completed**: (partial — Phases 1-3 of 15)
- **Effort**: ~4.5 hours of the estimated 18
- **Dependencies**: None
- **Artifacts**: plans/01_purge-and-enforce-task-references.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Completed the three-phase prevention foundation the rest of this plan depends on: a single
shared bash pattern/exemption library, a repo-wide lint script wired into every declared
integration point, and a corrected agent-contract/Enforcement-section surface. `git-workflow.md`
self-trip (its own commit-message examples matching the citation pattern it exists to explain)
is resolved as the taxonomy's first real test case. Twelve purge phases (4-14) and the blocking
hook flip (Phase 15) remain — all of them depend on this dispatch's output and are unblocked to
run next.

## What Changed

- `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` — new. Sole home of
  `TASK_SEP`/`TASK_PATTERN`/`PHASE_PATTERN` (copied byte-for-byte from the pre-existing hook),
  `is_exempt_path` (path-level `specs/**` exemption), and `strip_exempt_regions` (awk-based
  content-level exemption via the `task-ref-ok:begin/end` block marker and bare `task-ref-ok`
  inline marker).
- `agent-system/extensions/core/scripts/check-task-references.sh` — new. Repo-wide lint gate:
  sources the shared library (never defines patterns locally; exits 2 if the library cannot be
  found), enumerates `git ls-files` under `agent-system/extensions`, `.opencode`, `lua`, and
  `.memory`, skips `specs/**` via `is_exempt_path`, strips exempt regions, greps the remainder
  for `PHASE_PATTERN`/`TASK_PATTERN`, and reports `path:line:matched-text`. Exit 0 clean / 1
  findings / 2 environment error. `--quiet` suppresses per-finding lines. First live baseline:
  1,223 unexempted occurrences across the four trees (563 / 610 / 32 / 18) — exactly 5 below the
  research's pre-purge 1,228, matching the 5 occurrences this dispatch's own Phase 1 purged.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — added gate 4
  ("Task-reference lint (check-task-references.sh --quiet)"), mirroring gate 3's doc-lint
  structure exactly (source-store-only `[SKIP]` guard, not-deployed `fail`, quiet invocation).
- `agent-system/extensions/core/manifest.json` — declared `check-task-references.sh` and
  `lib/task-reference-patterns.sh` in `provides.scripts`, at their true alphabetical positions.
- `agent-system/extensions/core/root-files/settings.local.json` — three permission entries for
  `check-task-references.sh`, mirroring the existing `check-extension-docs.sh` trio.
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` — added an
  `## Exemption Taxonomy` section (marker convention plus the five-category table: `specs/**`
  path exemption, commit-message convention examples, command-usage examples, quoted historical
  anti-patterns, placeholder-bearing prose); wrapped its own **Before** anti-pattern block in a
  marked exempt region; rewrote `## Enforcement` to three accurate, verified-true layers (lint
  gate, write-time gate stated as presently advisory, and the four agent-contract files that
  actually carry the bullet), stated the four-tree deliverable boundary unambiguously, and
  recorded the known extension-implementation-agent coverage gap as a named, out-of-scope
  follow-up.
- `agent-system/extensions/core/rules/git-workflow.md` — converted its own commit-message
  examples to the placeholder form its Standard Actions table already uses (Single-Task
  Operations example, and the first/third Examples-block entries), retaining exactly one
  concretely-rendered example (`task 259 phase 2: implement modal semantics evaluator`) wrapped
  in a `task-ref-ok:begin/end` region with reason `canonical rendered commit-message example` —
  this is the taxonomy's named self-trip test case.
- `agent-system/extensions/core/agents/general-implementation-agent.md` and
  `general-implementation-hard-agent.md` — each gained a MUST-NOT bullet against citing task
  numbers outside `specs/**`, reusing the pre-existing cslib wording verbatim.

## Decisions

- Category 2 (commit-message convention examples) converts to placeholders rather than granting
  `git-workflow.md` a blanket path exemption — a path allowlist would immunize real future
  violations elsewhere in the same file. This was explicitly considered and rejected, per the
  plan's own instruction.
- The exemption marker's required reason is carried on the begin marker (block form) or the
  inline marker line (inline form); the end marker may be bare. This keeps the convention
  implementable as a single small `awk` pass in `strip_exempt_regions` without needing a
  reason-matching contract on the closing token.
- `check-task-references.sh` looks for the shared library at the deployed path first, falling
  back to the source-store path, so a `REPO_ROOT=$(pwd)` source-store invocation works before any
  deploy has run (this task's own Phase 1-2 verification depended on this).

## Plan Deviations

- **Task 1.4** (git-workflow.md taxonomy application) altered: the plan's task text named
  `todo: archive 3 completed tasks (336, 337, 338)` as one of git-workflow.md's 3
  `TASK_PATTERN` occurrences, but that string does not actually match the pattern (a `(` follows
  the separator where a digit is required). The real 3rd match was `task 334: complete research`
  in the Single-Task Operations example — a different section than the named `Examples` block.
  Converted the actual matching occurrence to placeholder form; also genericized the
  named-but-non-matching archive line for consistency with the Standard Actions table above it.
  The asserted occurrence *count* (3) was correct; only the narrative description of which three
  strings matched was off, and this was reconciled against the live file per the Scope
  Hypothesis's own instruction.
- **Task 2 manifest-ordering note** altered: the plan's parenthetical claimed
  `check-task-references.sh` "sorts immediately before `check-extension-docs.sh`" — true
  alphabetical order in the already-sorted `provides.scripts` array instead places it between
  `check-runtime-file-tracking.sh` and `check-vault-threshold.sh`. Inserted at the correct
  position, consistent with the array's existing strict ordering; the "declare it, alphabetical"
  intent was preserved even though the plan's own example position was wrong.

## Verification

- Build: N/A (bash scripts + markdown only)
- Tests: `bash -n` passed on all three new/modified `.sh` files
  (`check-task-references.sh`, `verify-deploy.sh`, `lib/task-reference-patterns.sh`).
  `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh --quiet`
  runs correctly end-to-end (exit 1, expected — the tree is still dirty pending Phases 4-14);
  unknown-flag and missing-library cases both correctly exit 2.
  `jq -e '.provides.scripts | index(...)'` confirms both manifest entries;
  `grep -c` confirms the 3 `settings.local.json` permission entries.
  Phase 1's shared-library `TASK_SEP`/`TASK_PATTERN`/`PHASE_PATTERN` assignments diff
  byte-for-byte against the pre-existing hook's copies. `strip_exempt_regions` verified 0
  residual matches on both edited rule files and both edited agent files.
- Files verified: Yes — all new/modified files read back and content-checked after each edit.

## Notes

- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports 5
  FAILs, all expected: 3 are deployed-vs-source drift on files this dispatch edited
  (`verify-deploy.sh`, `git-workflow.md`, `no-task-references-in-deliverables.md` — normal until a
  deploy runs, per this plan's own "Redeploy checkpoints" section) and 2 predate this session
  entirely (`orchestrate-recover-outcome.sh`, `validate-artifact.sh`, from a prior unrelated
  task). None of these five block Phases 4-14, which verify against the source-store script with
  `REPO_ROOT=$(pwd)` exactly as this dispatch did.
- Phase 15 (the blocking PreToolUse flip) was NOT touched, per the binding constraint that it must
  land strictly last, gated on `check-task-references.sh` exiting 0 across all four trees — which
  it does not yet do (1,223 occurrences remain, all in Phases 4-14's territory).
- Next dispatch resumes at Phase 4 (`agent-system/extensions/core/context/`), which is unblocked:
  Wave 2 (Phase 2) is complete, so all twelve Wave-3 purge phases (4-14) can now proceed, in any
  order, each within its own disjoint file territory as declared in the plan.
