# Implementation Summary: Task #135

- **Task**: 135 - Sweep for and remove artifacts orphaned by the orchestrate-engine consolidation
- **Status**: [COMPLETED]
- **Started**: 2026-09-01T19:56:00Z
- **Completed**: 2026-09-01T20:55:00Z
- **Effort**: ~1 hour
- **Dependencies**: 114, 120, 123, 126, 128, 130, 133 (all complete)
- **Artifacts**: plans/01_orphan-sweep-removal.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Executed the 8-phase orphan-removal sweep bounded by the research report to the single
team-mode-skill deletion event: removed the one confirmed dead reference file and its index row,
repaired four stale-prose sites asserting `--team` is a flag on `/research`/`/plan`/`/implement`,
corrected the inverted Dispatch Model Comparison table row, restored `index-entries.json`
internal consistency, and left behind a reusable `audit-deletion-references.sh` detector so the
next artifact deletion (the hard-engine skill removal) can re-run this sweep's method instead of
re-deriving it. All 8 phases closed `[COMPLETED]`.

## Search Method

Three passes, each catching a **disjoint** defect class:

1. **Literal-name grep** — the deleted names verbatim, across `agent-system/extensions/`. Catches
   direct textual references. Found 0 hits (the team-mode deletion left no literal-name
   references anywhere in the tree — consistent with the prior team-mode-skill removal task's own
   19-file inventory already having caught every literal reference).
2. **Wildcard-expanded grep** — stem variants (`{name}-*`, `*-{name}`, common-prefix stem),
   case-insensitive, restricted to `*.md`/`*.sh`/`*.json`. This is the pass a literal-name grep
   structurally cannot perform, and it is the pass that found all three real candidates in the
   research phase: `team-wave-helpers.md`'s dangling glob, and the prose defects in
   `skill-lifecycle.md` and `multi-task-operations.md`.
3. **Reachability delegation** — `check-extension-docs.sh` / `generate-context-line-counts.sh
   --check`, invoked rather than reimplemented. Confirmed the tree was otherwise structurally
   clean (0 dangling index rows, 0 undeclared files) both before and after, and caught the one
   pre-existing `line_count` drift folded into Phase 6.

**Passes 1-2 and Pass 3 catch disjoint classes**: `team-wave-helpers.md` was reachable by every
structural test (valid index row, live `load_when.agents` binding) while dead by every semantic
one (no design-time consumer ever cited it) — reachability could not have found it; only reading
prose for a glob reference could.

## Dispositions Table

All 11 candidates from the research report, accounted for with no gaps:

| # | Candidate | Disposition | Reason |
|---|-----------|--------------|--------|
| 1 | `context/reference/team-wave-helpers.md` | **Removed** (+ its index row) | Sole remaining `skill-team` hit in the tree; own closing line globs a now-empty pattern; `load_when.agents: [synthesis-agent]` made it mechanically injected but `synthesis-agent.md` never cited it — reachable, never consumed |
| 2 | `context/patterns/skill-lifecycle.md` | **Repaired** | Dropped "the team skills" from the lifecycle-skill roster (line 6); rewrote the multi-task-vs-team-mode paragraph to state `--team` is `/orchestrate`-only |
| 3 | `context/patterns/multi-task-operations.md` | **Repaired** | Fixed 4 example/table sites and rewrote Section 7 in place (kept its number — cross-referenced by name); corrected the inverted Dispatch Model Comparison row; lines 636-662 (the already-correct `/orchestrate`-scoped `--team` content) verified byte-identical before/after |
| 4 | `README.md` | **Repaired** | Dropped `--team` from the multi-task flag list |
| 5 | `rules/artifact-formats.md` | **Repaired** | Retargeted the Team Mode Example from `/research 309 --team` to `/orchestrate 309 --team` |
| 6 | `context/formats/team-metadata-extension.md` | Kept — false positive | Already self-describes as historical design reference (task 123 provenance note) |
| 7 | `context/patterns/team-orchestration.md` | Kept — false positive | Generic, implementation-agnostic; describes concepts `skill-orchestrate`'s fan-out still implements; no reference to any deleted skill |
| 8 | `file-footprint-overlap.md`, `skill-self-execution-fallback.md`, `context-protective-lead.md` | Kept — false positive | All three already carry explicit "(retired)"/"(historical)" annotations |
| 9 | `agents/synthesis-agent.md:3` (frontmatter) | Kept — false positive, low-priority reword candidate | "Multi-output synthesis for team skills" reads naturally as "skills/modes that run in team mode," which is still true; ambiguous but not clearly false |
| 10 | `docs/fork-patterns.md`, `docs/templates/command-template.md`, `docs/guides/creating-commands.md`, `context/standards/git-staging-scope.md` | Kept — false positive | Generic "team mode"/`--team` mentions that remain accurate for `/orchestrate` |
| 11 | `scripts/parse-command-args.sh` | Kept — false positive | Still-live shared parser for `/orchestrate`'s own `--team` support; not dead code |

## Baseline Diff (Phase 1 -> Phase 8)

Gate-level: `verify-deploy.sh` moved from 3 to 6 of 27 checks failing. Finding-level
(`--findings` mode): 7 new, 1 gone, 10 unchanged.

**All 7 new findings are explained and are not regressions** — they are the expected,
self-resolving byproduct of correctly editing `agent-system/extensions/**` (the binding
source-store rule) without an accompanying redeploy of `.claude/`, plus one recurrence of an
already-documented pre-existing flake:

| Finding | Cause |
|---|---|
| gate3: deployed rule content drift, `rules/artifact-formats.md` | Phase 3 edited the source; `.claude/` is intentionally not redeployed by this task |
| gate5 (×4): content-differs on `multi-task-operations.md`, `skill-lifecycle.md`, `artifact-formats.md`; missing script `audit-deletion-references.sh` | Same cause — these are exactly the 4 source files Phases 2/3/5/7 legitimately touched |
| gate13 (×2): ghost index row + orphan file, `team-wave-helpers.md` | Phase 4 removed both the source file and its source index row; the deployed `.claude/` copies persist until the next redeploy — exactly what Phase 4's own Scope Hypothesis anticipated in writing |
| gate8: nested `run-all.sh` FAIL | The already-documented concurrency flake (noted in the Phase 1 baseline header and this plan's Testing & Validation section) recurred as anticipated; the standalone run is authoritative and passed both times (58 passed, 0 failed) |

**1 finding gone** — `index-entries.json` `line_count` mismatch on
`system-defect-discrimination.md` (409 -> 420) — fixed by Phase 6, an improvement.

`check-task-references.sh`: 0 findings, unchanged. `generate-context-line-counts.sh --check`: now
exits 0 (CHECK PASSED), improved from the Phase 1 baseline's exit 1.

Full command-by-command output: `baseline-pre-sweep.txt`, `baseline-post-sweep.txt`, and their
`--findings` companions.

## Reusable Detector

`agent-system/extensions/core/scripts/audit-deletion-references.sh` (declared in
`manifest.json`'s `provides.scripts`, alphabetical position) reproduces this sweep's three-pass
method for the next artifact deletion (the hard-engine skill removal, on exactly this pattern):
`bash audit-deletion-references.sh <deleted-name> [<deleted-name> ...]`. Prints a triage
checklist and always exits 0 on hits — only a usage error or missing dependency is non-zero — per
the report's recommendation that the glob/pattern-prose axis needs judgment and would be too
noisy as an auto-fail gate if wired into the standing lint suite. Post-sweep run with the three
deleted skill names confirms it now reports zero hits under `agent-system/` for both passes,
closing the loop between the detector and the sweep it encodes.

## Deferred Items

Carried forward explicitly, not fixed in this sweep:

- **`scripts/tests/test-force-phases.sh` undeclared in `manifest.json` `provides.scripts`**. Not
  an orphan — nothing was deleted that created it; it is an omission in a sibling task's output.
  A Phase 1 baseline captured at implementation time already contains it, so it does not block
  this sweep's acceptance.
- **4 `lint-state-writer-boundary.sh` violations in `scripts/tests/test-force-phases.sh`** (lines
  261, 307, 317, 327). Deferred for the same reason, plus: routing four hand-rolled
  `jq ... > state.json.tmp && mv` writes through `state-write.sh` is a behavioural change to a
  test file that must still pass afterward — code work with its own verification profile, which
  would have blurred this otherwise `prose`-dominant documentation sweep's scope.
- **Missing "multi-task" scope qualifier on `multi-task-operations.md` line 662**. That line
  reads `` `/orchestrate` does not support the `--team` flag `` without the qualifier line 636
  carries, and read standalone is now mildly misleading since single-task `/orchestrate --team`
  is the sanctioned team path. Left untouched per the binding instruction that lines 636-662
  survive byte-identical, and per the research report's own recommendation. A future editor can
  decide whether the one-line qualifier is worth adding.

## Plan Deviations

- **Phase 7**: the detector script's own internal usage example and comments were written using a
  generic placeholder (`old-artifact-a`, etc.) rather than the literal `skill-team-research`/
  `skill-team-plan`/`skill-team-implement` names the plan's task text illustrated. Discovered
  mid-phase to be necessary: with the literal names in its own source, the script became a
  permanent 4-hit Pass-2 self-reference against itself, which would have made Phase 8's "confirm
  it now reports zero hits" closing check permanently fail. Behavior is unaffected.
- **Phase 8**: the raw captures of both baseline files suffered a self-inflicted concurrent-write
  interleaving defect (verify-deploy.sh's slow background process output got scrambled together
  with several sequential foreground command appends writing to the same file). No content was
  lost; both files were corrected by reassembling the scattered fragments into one contiguous,
  correctly-ordered `verify-deploy.sh` section. See the plan's Phase 8 task annotations and each
  baseline file's own header CORRECTION NOTE for the full account.

## Verification

- Build: N/A (documentation/meta sweep)
- Tests: `run-all.sh` standalone — 58 passed, 0 failed, 0 skipped (both pre- and post-sweep)
- Lints: all six lint scripts unchanged pre/post (5 clean, `lint-state-writer-boundary.sh`
  carrying the same 4 pre-existing, deferred violations)
- `check-task-references.sh`: 0 findings
- `jq . index-entries.json` / `manifest.json`: parse cleanly
- `grep -rn "skill-team" agent-system/`: 0 hits
- `multi-task-operations.md` lines 636-662: verified byte-identical via `diff` (exit 0)
- Files verified: yes

## Impacts

- `context/patterns/multi-task-operations.md` and `context/patterns/skill-lifecycle.md` are
  actively injected into `/research`, `/plan`, `/implement` context (`load_when.commands`) — the
  repair removes a live, wrong claim from that injected context, not just dormant documentation.
- `index-entries.json` is now internally consistent (`generate-context-line-counts.sh --check`
  exits 0), closing the acceptance criterion stated absolutely rather than as a baseline diff.
- The next artifact deletion (the hard-engine skill removal) has a re-runnable detector instead
  of needing to re-derive this sweep's method.

## Follow-ups

- A future redeploy (`<leader>al` / `bash scripts/deploy-headless.sh`, outside this task's remit
  per the source-store-deploy-boundary rule) will resolve the 7 expected pre-redeploy drift
  findings documented in the Baseline Diff section above.
- The three items in Deferred Items above remain open for a future task to pick up.

## References

- `specs/135_remove_refactor_orphans/reports/01_orphan-sweep-findings.md` — research report
- `specs/135_remove_refactor_orphans/plans/01_orphan-sweep-removal.md` — implementation plan
- `specs/135_remove_refactor_orphans/baseline-pre-sweep.txt`,
  `baseline-pre-sweep-findings.txt` — Phase 1 baseline
- `specs/135_remove_refactor_orphans/baseline-post-sweep.txt`,
  `baseline-post-sweep-findings.txt` — Phase 8 baseline
