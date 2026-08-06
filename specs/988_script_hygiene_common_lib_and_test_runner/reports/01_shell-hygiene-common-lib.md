# Research Report: Task #988

**Task**: 988 - Script hygiene: lib/common.sh, strict-mode convention, test runner wired into deploy
**Started**: 2026-08-06
**Completed**: 2026-08-06
**Effort**: large (multi-phase; sequence-dependent per task description)
**Dependencies**: Task 960 (completed), Task 964 (completed) — no blockers
**Sources/Inputs**: Codebase exploration (`agent-system/extensions/**`), `specs/reviews/review-2026-07-29-agent-system.md`, `agent-system/extensions/core/context/standards/shell-script-testing.md`, `agent-system/extensions/core/scripts/verify-deploy.sh`, `agent-system/extensions/core/scripts/lib/*.sh`, `agent-system/extensions/core/manifest.json`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The source-of-truth review's counts have already drifted (source store keeps changing under
  ongoing meta work); this report re-measured everything live on 2026-08-06 and flags every
  discrepancy so the planner sizes phases against current reality, not the July snapshot.
- `agent-system/extensions/core/scripts/lib/` already has a working, well-documented convention
  for shared libraries (4 files, not the review's "3 libs" — see Findings). `lib/common.sh`
  should follow this convention exactly: header naming its consumers, an explicit "forbid local
  redefinition" contract, and (critically) **no shell-option pollution when sourced** —
  `manifest-routing-lib.sh`'s header states this as an explicit, load-bearing rule.
- There is a real, live tension between task WORK item 4 (settle `set -euo pipefail`) and an
  existing, documented compensating mechanism: `deploy-root-guard.sh`'s header says several
  callers deliberately do NOT have `set -e` and instead use `|| exit 1` around the guard's
  sourcing. A blind `-e` migration on those callers needs an audit pass, not a mechanical `sed`.
- `verify-deploy.sh` already has a clean, precedented "Gate N, SKIP if not source-store" pattern
  (gates 3/4/5/6/7) that a new "Gate 8: script test suites" should mirror exactly — this is the
  natural integration point for `scripts/tests/run-all.sh`, not `deploy-headless.sh` (which only
  prints a manual `verify-deploy.sh` reminder and never invokes it).
- Root-resolution boilerplate is actually **more** varied than the review's "6 divergent
  `../..` depth variants, 3 variable names" — a 4th pattern exists (`lint-agent-contracts.sh`
  uses `git rev-parse --show-toplevel` with a `REPO_ROOT` env-var override, deliberately
  different from the `scripts/`-depth convention because it lives one level deeper at
  `scripts/lint/`). `common.sh`'s root-resolution function must be parameterized by depth
  (as the task description already specifies) to serve `scripts/`, `scripts/lib/`,
  `scripts/tests/`, and `scripts/lint/` callers uniformly.

## Context & Scope

Task 988 asks for four coupled deliverables, in the WORK-block's stated order:
1. `scripts/tests/run-all.sh` — a runner over both existing test locations, wired into the
   deploy-verification path, with the exec bit fixed on scripts that need it.
2. `scripts/lib/common.sh` — extracted repo-root resolution, session-ID generation, UTC
   timestamp helpers, `log_error`/`log_warn`/`log_info`, and the test pass/fail/info trio.
3. Migration of the worst boilerplate sites (mechanical; full 75-file sweep is opportunistic).
4. Settling `set -euo pipefail` as the convention, using the new runner as regression net.
5. Shebang normalization (`#!/bin/bash` → `#!/usr/bin/env bash`).
6. New test coverage for the highest-blast-radius, currently-untested scripts.

This report re-verifies every quantitative claim in the task description against the current
source tree (`agent-system/extensions/**`, the source store — per the binding source-store rule,
`.claude/**` is a disposable deploy artifact and is never the edit target) and locates the exact
integration points the implementer will touch.

## Findings

### Codebase Patterns

**Existing shared-library convention (the model to extend, not replace).**
`agent-system/extensions/core/scripts/lib/` currently holds 4 files — `manifest-routing-lib.sh`,
`task-reference-patterns.sh`, `phase-heading-patterns.sh`, `file-scope-overlap.sh` — not the
review's "3 libs, all genuinely single-source." All 4 are still genuinely single-source (each
names its exact consumer set in its header comment). `manifest-routing-lib.sh`'s header states
the contract explicitly and should be treated as the template for `common.sh`'s own header:
- "Sourced (never executed) by \<consumer list\>."
- "Sets no shell options (no `set -e`, no `set -u`, no `set -o pipefail`) — sourcing this file
  must never change the calling shell's error-handling behavior."
- Every internal variable/function is namespaced and explicitly unset/scoped so sourcing never
  leaks state.
- A miss/no-op is signalled by empty output or a safe default, never by changing the caller's
  exit behavior unexpectedly.

Consumers source it as `source "${SCRIPT_DIR}/lib/manifest-routing-lib.sh"` (see
`command-route-agent.sh:44`, `command-route-skill.sh:39`) after resolving their own
`SCRIPT_DIR`. `common.sh` should be sourced the same way, and its root-resolution helper should
take over the very `SCRIPT_DIR` computation that currently precedes each `source` line, using a
depth parameter rather than a fixed `../..`.

**Registration convention.** Every lib file and every test file is registered as an ordinary
entry in `core/manifest.json`'s `provides.scripts` array (subdirectory-qualified:
`lib/manifest-routing-lib.sh`, `tests/test-census-count.sh`). `common.sh` and `tests/run-all.sh`
must both get entries there or they will not deploy — confirmed by cross-checking `manifest.json`
against the filesystem (99 `provides.scripts` entries currently, including all 4 lib files, 4
lint scripts, 17 `tests/` suites, and 7 flat `test-*.sh` suites).

**The "two test locations" split is deliberate and documented, not accidental.**
`context/standards/shell-script-testing.md` codifies a scope-based split: narrow, single-script
suites go in `scripts/tests/test-<script-under-test>.sh`; broad end-to-end/pipeline suites stay
flat in `scripts/test-<name>.sh`. Currently: 17 files in `core/scripts/tests/`, 7 flat
`core/scripts/test-*.sh` files (concurrency/session/conflict suites), plus
`literature/scripts/tests/` and a flat `literature/scripts/test-lit-pipeline.sh` in a sibling
extension. `run-all.sh` must iterate **both** shapes and must not attempt to collapse them — the
standards doc explicitly calls this "a scope-based split, not 'core always does X'" and flags one
known, intentionally-tolerated pre-convention exception (`test-task-lock-reap.sh`, flat despite
being narrow) that should NOT be silently migrated as a side effect of adding the runner.

The same doc also defines the pass/fail/info helper trio and its exact shape (counters
`PASSED`/`FAILED`, `pass()`/`fail()`/`info()`, `mktemp -d` + `trap ... EXIT`, "loud-skip
discipline" — a skipped prerequisite must print a visible warning, never silently exit 0). This
is precisely the trio task WORK item 2 asks `common.sh` to extract. Note the doc's own caveat:
"a different extension's `t_pass`/`t_fail` style ... remains valid there — location is the
shared rule across extensions; helper naming is extension-local and does not need to be
unified." Extracting the trio into `common.sh` should therefore target core's own suites first
(all of which already use this exact naming) rather than forcing non-core extensions to adopt it.

**Deploy-verification integration point.** `verify-deploy.sh` (405 lines) already runs 7 gates
(event/error-store presence, hook registration, doc-lint, task-reference lint, manifest-driven
parity via `verify.lua`, agent-contracts lint, routing-wiring lint), gates 3/4/5/6/7 all sharing
one pattern: `if [ ! -d "$TARGET/agent-system/extensions" ]; then say "[SKIP] ... not the source
store"` else run the check and extract `FINDING gateN ...` lines into `FINDINGS_LIST`. A new
"Gate 8: script test suites" following this exact shape is the natural, precedented home for
`run-all.sh` invocation — it should SKIP (not fail) when not in the source-store repo, exactly
like gates 3/4/5/6/7, since `run-all.sh` only makes sense against the source-store copies (or a
deployed copy that mirrors them 1:1). **`deploy-headless.sh` itself never invokes
`verify-deploy.sh`** — it only prints `"[deploy-headless] Verify with: bash
$TARGET/.claude/scripts/verify-deploy.sh"` as an instruction. So "wired into the deploy path"
concretely means: add Gate 8 to `verify-deploy.sh`, not modify `deploy-headless.sh`.

**Exec-bit state (re-verified, worse than the task description implies).** The task description
says only `tests/test-git-commit-scoped.sh` is non-executable "while its five siblings are."
Live count in `core/scripts/tests/`: **3 of 17** files are non-executable —
`test-git-commit-scoped.sh`, `test-index-entries-schema.sh`, and `test-routing-resolution.sh`.
The exec-bit fix in WORK item 1 needs to cover all three, not just the one named.

### Quantitative re-verification (drift since the July 29 review)

| Claim (review / task description) | Live measurement (2026-08-06) | Note |
|---|---|---|
| 123 shell scripts total | 161 `.sh` files under `agent-system/extensions/**` | Grown; review's count is stale, plan against current total |
| SCRIPT_DIR duplicated 75x | 98 occurrences of the `SCRIPT_DIR="$(cd "$(dirname ...` pattern (95 depth-0, 2 depth-1 `/..`, 1 test-relative variant) | Same shape, higher count |
| PROJECT_ROOT/REPO_ROOT/SKILL_REPO_ROOT duplicated 30x, 3 names | 64 files declare one of the three; 9 distinct depth-variant literal expressions found (not "at least 6") | Task's "at least 6" undercounts; a 4th naming/resolution strategy (`git rev-parse --show-toplevel` + `REPO_ROOT` env override, `lint-agent-contracts.sh`) also exists outside this count entirely |
| Session-ID generation copied 5x | 8 occurrences across 7 files: `archive-task.sh`, `command-gate-in.sh` (the `tr -d ' \n'` divergent one), `reconcile-artifacts.sh`, `orchestrate-predispatch-review.sh`, `vault-operation.sh`, `manage-topics.sh`, `skill-base.sh` (×2 call sites) | One more file than stated; the `command-gate-in.sh` divergence (`tr -d ' \n'` vs `tr -d ' '` everywhere else) is confirmed live |
| `date -u` ISO calls: 17x | 38 files match `date -u \+` | Higher; review's 17 likely counted call sites not files, or a narrower pattern |
| BSD `date -u -j -f` in 2 files | Confirmed: `reconcile-task-status.sh`, `task-lock.sh` | Matches |
| GNU `date -u -d` in 6 files | 8 files match (`date -u -d` or `date -d`) | Slightly higher |
| `set -euo pipefail`: 73 / `set -uo pipefail`: 45 | 80 / 65 respectively | Both grown; ratio (roughly 55%/45%) is materially unchanged |
| 5 scripts with no `set` line at all | 17 files match with no `^set -` line, but 4 are the `lib/*.sh` files (deliberately unset, per contract above) and 13 are hooks (`core/hooks/*.sh`) or dispatch-layer scripts (`command-gate-in.sh`, `parse-command-args.sh`, `command-route-agent.sh`, `command-route-skill.sh`, `skill-base.sh`, `validate-wiring.sh`, `deploy-root-guard.sh`) | The task's "5" undercounts; more importantly, 4 of these are **intentionally** unset (libs) and should stay that way — do not treat "no set line" as uniformly a defect |
| `update-task-status.sh` named among highest-risk `-e`-lacking scripts | **Already has `set -euo pipefail`** (line 48) | Contradicts the task description as currently written — verify before batching; do not assume it needs migration |
| `state-write.sh`, `task-lock.sh`, `git-commit-scoped.sh`, `orchestrate-batch-admit.sh`, `orchestrate-predispatch-review.sh` lacking `-e` | Confirmed: all 5 use `set -uo pipefail` only | Matches; these remain the real highest-risk migration targets |
| skill-base.sh: 858 lines, 18 functions, 1 tested | Live: 738 lines, 16 top-level `skill_*` functions, 1 tested (`skill_corroborate_phase_counts`, via `tests/test-corroborate-phase-counts.sh`) | Shrunk somewhat (recent routing-consolidation work); coverage gap (15/16 untested) is unchanged in kind |
| 5 `#!/bin/bash` shebangs vs 118 `#!/usr/bin/env bash` | 25 vs 136 | Materially more `#!/bin/bash` files than stated; `verify-deploy.sh` itself is one of them |
| "Twelve good test suites exist" | 17 files in `scripts/tests/` + 7 flat `scripts/test-*.sh` = 24 core suites (plus 2 in `literature/scripts/`) | Undercounted; more suites exist than the review states, all still unrun by any runner |

**Implication for planning**: none of this drift changes the shape of the fix, but a phase-count
or file-list baked into a plan directly from the task description's numbers will be measurably
wrong on day one. The plan should either re-derive counts at implementation time via the same
`grep`/`find` commands used here, or explicitly caveat that the numbers are approximate and
re-verified per-phase.

### The `set -e` migration risk (WORK item 4) — a concrete blocking precedent

`deploy-root-guard.sh`'s own header (sourced by root-resolution-performing scripts) states:

> "Callers MUST use `. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1` — several callers do not
> set -e, so the `|| exit 1` is what makes a missing helper fail closed rather than continue."

This is a **documented, load-bearing assumption that `set -e` is absent** in some callers. Any
mechanical migration of those callers to `set -euo pipefail` must first confirm this guard
pattern (and any other `|| exit`/`&&`-chained error handling that assumes non-`-e` semantics)
still behaves correctly once `-e` is added — under `-e`, a command whose failure is already
being tested in an `if`/`&&`/`||`/`while` condition does NOT trigger the `-e` trap, so the
pattern above is actually `-e`-safe by construction, but other bespoke non-`if`-guarded chains
in the same files may not be. This is exactly the audit the task description already calls for
("per-file audit, run suites after each batch") — this report confirms a concrete example of why
that audit is necessary rather than optional.

### Recommendations

1. **Build `common.sh` before touching any consumer.** Model its header on
   `manifest-routing-lib.sh`'s contract verbatim (no shell-option pollution on source, consumer
   list, explicit non-redefinition rule). Root-resolution function signature should take a depth
   parameter (e.g. `_common_repo_root <levels-above-scripts-dir>`) so `scripts/`, `scripts/lib/`,
   `scripts/tests/`, and `scripts/lint/` callers all resolve correctly from one function, matching
   WORK item 2's own phrasing ("one function, parameterized depth"). Do not attempt to also
   collapse the `lint-agent-contracts.sh` `git rev-parse --show-toplevel` pattern into the same
   function unless its authors intend to abandon that intentionally-different strategy — it's
   documented as deliberate.
2. **`run-all.sh` in `scripts/tests/`**, iterating `scripts/tests/*.sh` (excluding itself) and
   `scripts/test-*.sh` at the parent level, exactly matching `shell-script-testing.md`'s two
   documented shapes. Use `verify-deploy.sh`'s `pass()`/`fail()`/`FINDINGS_LIST` idiom for
   internal consistency with the gate it will be wired into, and its own PASSED/FAILED counters
   per `shell-script-testing.md`'s trio contract. Fix the exec bit on the 3 currently-non-executable
   suites identified above as part of this same phase (WORK item 1 already calls for "the" exec
   bit fix; scope it to all 3, not 1).
3. **Wire in as Gate 8 of `verify-deploy.sh`**, copying the SKIP-if-not-source-store shape from
   gates 3/4/5/6/7 verbatim. Do not modify `deploy-headless.sh` — it is not the actual deploy-time
   verification path; `verify-deploy.sh` is.
4. **Session-ID migration (WORK item 3) covers 7 files, not 5** — `archive-task.sh`,
   `command-gate-in.sh`, `reconcile-artifacts.sh`, `orchestrate-predispatch-review.sh`,
   `vault-operation.sh`, `manage-topics.sh`, `skill-base.sh` (2 call sites). Migrating
   `command-gate-in.sh` resolves the real `tr -d ' \n'` vs `tr -d ' '` divergence as a side effect
   of using the shared function — this is the single highest-value mechanical fix in the whole
   task, since it is a live, reproducible bug (trailing-newline hazard) not just duplication.
5. **`set -e` migration (WORK item 4): treat `update-task-status.sh` as already done** — do not
   include it in the 45-file (now ~65-file) migration batch; re-run the `grep -rl "^set -uo
   pipefail"` query at implementation time rather than trusting the task description's file list.
   Prioritize `state-write.sh`, `task-lock.sh`, `git-commit-scoped.sh`, `orchestrate-batch-admit.sh`,
   `orchestrate-predispatch-review.sh` as the genuinely-highest-risk confirmed-missing-`-e` files,
   auditing each against `deploy-root-guard.sh`'s guard pattern and any bespoke non-`if`-guarded
   command chains before flipping `-e` on.
6. **Do not "fix" the 4 lib files' missing `set` line** — it is intentional per their own headers
   and per the general convention that sourced files must not change caller shell-option state.
   `common.sh` itself must follow the same rule.
7. **Test coverage additions (WORK item 6)**: `skill-base.sh` has 16 functions, 15 uncovered;
   start with the ones task 988's own description names (lifecycle functions) — `skill_preflight_update`,
   `skill_postflight_update`, `skill_gate_completion_claim`, `skill_link_artifacts`,
   `skill_cleanup` are the state-mutating, highest-blast-radius candidates among the 15.
   `update-task-status.sh` (563 lines) has no dedicated file in `scripts/tests/` either — confirm
   this before assuming coverage exists.

## Decisions

- Treat the task description's quantitative claims as a starting orientation, not a checklist to
  match exactly — the codebase has moved since the July 29 review; the plan should re-derive
  file lists live rather than hardcode the (now-stale) counts from the task description.
- The integration point for the test runner is `verify-deploy.sh` (new Gate 8), not
  `deploy-headless.sh`.
- `common.sh`'s header/sourcing contract should be modeled on `manifest-routing-lib.sh`, the
  most fully-specified existing lib file.

## Risks & Mitigations

- **Risk**: mechanically adding `set -e` to a script whose control flow relies on a command's
  non-zero exit continuing execution silently breaks it in a way the existing (currently unrun)
  test suites may not catch if that code path isn't exercised. **Mitigation**: per-file audit
  before each `-e` flip, run `run-all.sh` immediately after each batch (task description already
  specifies this — this report just confirms a concrete precedent, `deploy-root-guard.sh`'s
  documented `|| exit 1` compensation, that makes the risk non-hypothetical).
- **Risk**: collapsing the two test-suite *locations* (flat vs `tests/`) into one directory as
  part of "wiring in a runner" would violate the explicitly documented, deliberate split.
  **Mitigation**: `run-all.sh` must glob both locations separately; do not move files.
- **Risk**: `common.sh`'s pass/fail/info trio, if imported by non-core extensions' suites,
  could be read as forcing a naming convention `shell-script-testing.md` explicitly says is
  extension-local. **Mitigation**: scope migration to core's own suites (all of which already use
  this exact naming) unless a non-core extension opts in.

## Context Extension Recommendations

- **Topic**: shared shell-library conventions beyond `lib/manifest-routing-lib.sh`'s inline
  header contract.
  **Gap**: `shell-script-testing.md` documents the test-file convention well, but there is no
  equivalent standards doc for general-purpose libraries (root resolution, session IDs,
  timestamps, logging) — the convention currently lives only inside each lib file's own header
  comment.
  **Recommendation**: once `common.sh` exists, consider a short
  `context/standards/shell-lib-conventions.md` cross-referencing `shell-script-testing.md`
  (mirroring that doc's own "Related" section pattern) so the next lib author has one doc to
  read instead of reverse-engineering the convention from `manifest-routing-lib.sh`'s comments.
  This is optional polish, not required by task 988's verification bar.

## Appendix

### Search queries used

```bash
find agent-system/extensions -name "*.sh" | wc -l
grep -rhoE 'SCRIPT_DIR="\$\(cd[^)]*\)[^"]*"' --include="*.sh" .
grep -rhoE '(PROJECT_ROOT|REPO_ROOT|SKILL_REPO_ROOT)="\$\(cd[^)]*\)+[^"]*"' --include="*.sh" .
grep -rn 'session_id=\"sess_\$(date\|SESSION_ID=\"sess_\$(date' --include="*.sh" .
grep -rlE "date -u \+" --include="*.sh" .
grep -rlE "date -u -j -f|date -j -f" --include="*.sh" .
grep -rl "set -euo pipefail" --include="*.sh" .
grep -rl "^set -uo pipefail" --include="*.sh" .
grep -rlE "^#!/bin/bash" --include="*.sh" .
```

### References

- `agent-system/extensions/core/context/standards/shell-script-testing.md` (test location split,
  helper-naming convention, fixture convention, loud-skip discipline)
- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` (lib header/contract model)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (gate pattern to extend for Gate 8)
- `agent-system/extensions/core/scripts/deploy-root-guard.sh` (documented non-`-e` caller
  compensation, relevant to WORK item 4's risk)
- `agent-system/extensions/core/manifest.json` (`provides.scripts` registration requirement)
- `specs/reviews/review-2026-07-29-agent-system.md` (originating review; source of the task's
  quantitative claims, several of which have drifted — see table above)
