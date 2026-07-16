# Implementation Summary: Task #889

**Completed**: 2026-07-16
**Duration**: ~1 hour

## Overview

Added `deploy-root-guard.sh`, a ~25-line self-locating guard sourced immediately after the
`SCRIPT_DIR`/root computation in all 24 core scripts under
`agent-system/extensions/core/scripts/`. It structurally validates its own `BASH_SOURCE[0]`
location against the two accepted deploy-tree grandparents (`.claude`, `.opencode`) and exits 1
with an actionable message when run from the agent-system source store, where
`${SCRIPT_DIR}/../..` previously resolved silently to a bogus root
(`agent-system/extensions/`) and produced stray artifacts before failing later on a missing
`state.json`. Also de-anchored the `.agent-logs/` `.gitignore` entry so nested log dirs are
ignored at any depth, and reconciled `check-extension-docs.sh`'s stale "known latent bug,
flagged not fixed" comment now that the bug is fixed there too (gated on its `REPO_ROOT`
override being unset, preserving that file's deliberate source-store override for verification
callers).

## What Changed

- `agent-system/extensions/core/scripts/deploy-root-guard.sh` — new file. Validates its own
  location via a `case` on `${__guard_dir%/*}` (parameter expansion, no `dirname`/`basename`
  fork); accepts `*/.claude` and `*/.opencode`; exits 1 with a message naming the offending path
  and pointing at `<leader>al` otherwise.
- `agent-system/extensions/core/manifest.json` — registered `"deploy-root-guard.sh"` in
  `.provides.scripts`.
- `.gitignore` — line 10 changed from `/.agent-logs/` to `**/.agent-logs/`.
- 23 uniform core scripts (`archive-task.sh`, `events-append.sh`, `events-query.sh`,
  `export-to-markdown.sh`, `generate-task-order.sh`, `generate-todo.sh`,
  `install-extension.sh`, `literature-retrieve.sh`, `manage-topics.sh`, `memory-harvest.sh`,
  `memory-retrieve.sh`, `reconcile-artifacts.sh`, `reconcile-task-status.sh`,
  `roadmap-sync.sh`, `task-lock.sh`, `uninstall-extension.sh`, `update-phase-status.sh`,
  `update-task-status.sh`, `validate-context-budgets.sh`, `validate-context-index.sh`,
  `validate-extension-index.sh`, `validate-wiring.sh`, `vault-operation.sh`) — one inserted
  line each, immediately after the existing root-var computation:
  `. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1` (`update-phase-status.sh` uses its
  lowercase `${script_dir}`).
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — a gated guard line inserted
  immediately before the existing `REPO_ROOT=` default computation
  (`[[ -n "${REPO_ROOT:-}" ]] || . "$(dirname "${BASH_SOURCE[0]}")/deploy-root-guard.sh" || exit 1`),
  plus the stale "flagged not fixed" NOTE block replaced with a comment stating current reality
  and explaining the intentional `REPO_ROOT` override bypass.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — 14-line
  addendum ("Root-Resolution Guard for Core Scripts") documenting the sourcing rule, the two
  accepted deploy-tree names,
  and why `git rev-parse --show-toplevel` is rejected as a substitute.

## Decisions

- Used a single shared helper (~25 lines) instead of 24 inline guard blocks, reversing the
  research report's inline recommendation — net new code is ~37 lines vs. ~120, matching the
  user's "minimal code" focus. `skill-base.sh` already established the sourced-library
  convention in this directory's `provides.scripts`, so this is not a new pattern.
- `check-extension-docs.sh` is the one file where the guard is gated (`REPO_ROOT` unset) rather
  than unconditional, preserving the deliberate `REPO_ROOT=$(pwd)` override that verification
  callers depend on to run this specific doc-lint script from the source store on purpose.
- `validate-extension-index.sh` needed no special-casing despite its unresolved
  `PROJECT_DIR="${SCRIPT_DIR}/../.."` string (no `cd`/`pwd`): the guard validates its own
  `BASH_SOURCE[0]` location, never the caller's root variable, so it drops in identically.

## Plan Deviations

- None (implementation followed the plan). One minor documentation nuance is recorded inline in
  the plan's Phase 5 checklist: the plan's "Override" verification step text ("still exits 0")
  is superseded by its own very next step, which correctly expects Rule F drift and a non-zero
  overall exit once Phases 3-4 land — the override's actual job (bypass the guard itself, not
  the doc-lint content) was verified directly and holds.

## Verification

- Build: N/A (bash scripts, no build step)
- Tests: N/A (no test suite for these scripts)
- **Negative branch (source store)**: `bash agent-system/extensions/core/scripts/generate-todo.sh`
  and `update-phase-status.sh` (the two `.agent-logs/` writers) both exit 1 with the actionable
  guard message; `agent-system/extensions/.agent-logs/` was confirmed NOT created either time.
- **Positive branch (simulated deploy tree)**: a throwaway `.claude/scripts/` tree with
  `deploy-root-guard.sh` + `generate-todo.sh` copied in did NOT trip the guard; it failed later
  for an unrelated reason (a sibling script it wasn't given), which is the expected/acceptable
  outcome per the plan. `.opencode/scripts/` acceptance was also verified directly by sourcing
  the guard from a throwaway `.opencode` tree (exit 0).
- **Uniformity**: `grep -l 'deploy-root-guard.sh' agent-system/extensions/core/scripts/*.sh | wc -l`
  == 25 (24 callers + the helper itself). All 23 uniform scripts carry exactly one guard-line
  hit; `check-extension-docs.sh` has one guard *invocation* line plus one textual mention in its
  reconciled comment (mandated by Phase 4), confirmed by direct inspection, not a duplicate
  guard.
- **Syntax**: `bash -n` clean across all 24 guarded scripts, the helper, and the rest of the
  `scripts/` directory.
- **Doc-lint override**: `REPO_ROOT=$(pwd) bash check-extension-docs.sh --quiet` bypasses the
  guard (no guard-message failure) and runs the full check suite.
- **Expected drift (recorded, not chased)**: `REPO_ROOT=$(pwd) bash check-extension-docs.sh`
  reports exactly 24 Rule F (`check_deployed_script_drift`) FAILs — one per edited script,
  including itself — with overall verdict FAIL, "24 issue(s) found". This is the correct,
  unavoidable consequence of editing 24 previously-byte-identical deployed scripts; baseline
  before this task was a clean PASS.
- **Gitignore**: `git check-ignore -v` confirms both `agent-system/extensions/.agent-logs/x` and
  the root-level `.agent-logs/x` now match `**/.agent-logs/`; `git status --short` showed no
  untracked stray dirs during testing.
- `git status --short` after all phases shows only the intended task-889 files changed (plus
  pre-existing, unrelated modifications from other in-flight tasks in this session).

## Required Follow-Up (Not Automatable)

**The deployed `.claude/scripts/` tree still holds the 24 unguarded copies.** This task edits
only the source store (`agent-system/extensions/core/scripts/`); there is no headless/CI path to
regenerate `.claude/` (see `.claude/context/patterns/regeneration-is-manual-only.md`). To make
the guard live in the deployed tree:

1. Run `<leader>al` in Neovim and choose **"Sync all (replace existing)"**.
2. After syncing, `check-extension-docs.sh` should return to a clean PASS (Rule F drift
   resolved). The post-regeneration assertion is
   `STRICT_CORE_DEPLOY=1 bash .claude/scripts/check-extension-docs.sh`.

Until that sync happens, Rule F will correctly keep reporting drift for these 24 scripts — this
is expected, not a regression, and must not be silenced by hand-editing `.claude/scripts/`.

## Notes

**Recommended follow-up (not implemented, out of scope)**: mirror the guard into the ~15
overlapping `.opencode/scripts/` copies. `.opencode/scripts/` is git-tracked and independently
maintained; the guard already *accepts* `.opencode` as a valid deploy-tree grandparent, but
porting the actual sourcing wiring into that tree's scripts is separate scope per the plan's
Non-Goals.
