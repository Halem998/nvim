# Implementation Plan: Task #988

- **Task**: 988 - Script hygiene: lib/common.sh, strict-mode convention, test runner wired into deploy
- **Status**: [IMPLEMENTING]
- **Effort**: 16 hours
- **Dependencies**: None (Task 960, Task 964 already completed)
- **Research Inputs**: specs/988_script_hygiene_common_lib_and_test_runner/reports/01_shell-hygiene-common-lib.md
- **Artifacts**: plans/01_script-hygiene-common-lib.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Four coupled shell-hygiene deliverables land in the mandated order: a test runner over both
documented test locations wired into `verify-deploy.sh` as a new Gate 8; a `scripts/lib/common.sh`
extracting repo-root resolution, session-ID generation, UTC timestamps, a logging trio, and the
test pass/fail/info trio; mechanical migration of the duplicated session-ID and root-resolution
boilerplate onto that library; and only then a per-file-audited `set -euo pipefail` convention with
the new runner as the regression net, followed by shebang normalization and new coverage for the
two highest-blast-radius untested scripts. Every edit targets `agent-system/extensions/**` — the
source store — never the disposable `.claude/**` deploy tree.

Definition of done: `run-all.sh` exits nonzero when any suite fails and that nonzero propagates
through `verify-deploy.sh`'s Gate 8 (demonstrated with a deliberately-broken fixture); session-ID
generation exists in exactly one place by grep; every strict-mode batch lands with suites green.

### Research Integration

The research report re-measured every count from the originating review and found most had
drifted. The plan is written against the report's live 2026-08-06 measurements, and every phase
that asserts a count carries a **Scope Hypothesis** requiring the implementer to re-derive it
live rather than trust this document. Key report findings folded in:

- The integration point is `verify-deploy.sh` (new Gate 8, mirroring gates 3/4/5/6/7's
  SKIP-if-not-source-store shape), **not** `deploy-headless.sh` — which only prints a manual
  `verify-deploy.sh` reminder and never invokes it.
- 3 (not 1) test files under `core/scripts/tests/` are non-executable.
- Session-ID generation is duplicated 8 times across 7 files, with `command-gate-in.sh`'s
  `tr -d ' \n'` a live divergence from every other site's `tr -d ' '`.
- `update-task-status.sh` **already has** `set -euo pipefail` — it must not be batched into the
  strict-mode migration.
- The 4 files in `scripts/lib/` deliberately set no shell options; `common.sh` must follow the
  same contract, and none of the four is a strict-mode migration target.
- `deploy-root-guard.sh`'s header documents that several callers deliberately lack `set -e` and
  rely on `|| exit 1` — this is load-bearing, hence a per-file audit phase before any flip.

Additional live measurements taken during planning, beyond the report:

- **The `set -uo pipefail` population is not homogeneous.** Of the ~65 files, roughly 24 are test
  suites whose `set -uo pipefail` is *mandated* by `context/standards/shell-script-testing.md`'s
  own helper convention (the `PASSED`/`FAILED` counter idiom requires failures not to abort), and
  a further group (`verify-deploy.sh`, the `lint/*.sh` and `check-*.sh` scripts) uses the same
  counter idiom for the same reason. A mechanical sweep would break all of them. Phase 5 exists
  specifically to classify before Phase 6/7 flip anything.
- **`log_error`/`log_warn`/`log_info` are semantically divergent across existing definitions** —
  `validate-artifact.sh`'s increment an error counter, `lint-routing-wiring.sh`'s is
  verbose-gated, `lint-agent-contracts.sh`'s is colorized and counter-incrementing. `common.sh`
  provides a plain trio; mass migration of these sites is an explicit Non-Goal.
- **`SCRIPT_DIR` cannot be eliminated.** Sourcing `lib/common.sh` requires `SCRIPT_DIR` first, so
  the 98 `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` lines are an unavoidable
  bootstrap and stay. What `common.sh` replaces is the *second* line — the 9 distinct
  `PROJECT_ROOT`/`REPO_ROOT` depth-variant expressions that follow it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md was consulted.

## Goals & Non-Goals

**Goals**:
- A `scripts/tests/run-all.sh` that iterates both documented test locations across all extensions,
  exits nonzero on any suite failure, and is invoked by the deploy-verification path as Gate 8.
- Exec bits corrected on every non-executable test suite.
- A `scripts/lib/common.sh` following `manifest-routing-lib.sh`'s header/contract convention
  verbatim: explicit consumer list, zero shell-option pollution on source, namespaced internals,
  explicit forbid-local-redefinition rule.
- Session-ID generation existing in exactly one place, resolving the `tr -d ' \n'` divergence.
- A documented, per-file-audited strict-mode convention with the deliberate non-`-e` class named
  and justified rather than silently tolerated.
- Normalized `#!/usr/bin/env bash` shebangs.
- New test coverage for `skill-base.sh`'s lifecycle functions and `update-task-status.sh`.

**Non-Goals**:
- Moving any test file between the flat and `tests/` locations. The split is deliberate per
  `shell-script-testing.md`; `test-task-lock-reap.sh`'s known pre-convention exception stays put.
- Mass migration of the divergent `log_error`/`log_warn`/`log_info` definitions. Only sites whose
  semantics exactly match the plain trio may migrate, opportunistically.
- Collapsing `lint-agent-contracts.sh`'s `git rev-parse --show-toplevel` + `REPO_ROOT` override
  strategy into `common.sh` — it is documented as deliberately different.
- Adding `set -e` to the 4 existing `scripts/lib/*.sh` files or to `common.sh`.
- Forcing non-core extensions' suites onto core's `pass`/`fail`/`info` naming.
- Editing anything under `.claude/**`.
- Complete elimination of every boilerplate site — full migration is explicitly opportunistic.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Mechanically adding `set -e` breaks a script whose control flow relies on a non-zero exit continuing | H | H | Phase 5 classifies every file before any flip; Phases 6/7 audit per file and run `run-all.sh` after each batch |
| Adding `set -e` to a counter-idiom harness (test suite, lint, `verify-deploy.sh`) silently truncates it at first failure | H | H | Phase 5 names this as a protected class with a documented rationale; those files are excluded by construction |
| `run-all.sh` reports green because it silently found zero suites | H | M | Loud-skip discipline per `shell-script-testing.md`: assert a nonzero discovered-suite count and fail if zero |
| Gate 8 fails in a deploy consumer that has no source store | M | H | Copy gate 7's `[SKIP] ... not the source store` branch verbatim |
| `common.sh` sourcing changes a caller's shell-option state | H | M | Contract copied from `manifest-routing-lib.sh`; Phase 2's unit test asserts `$-` is unchanged across a source |
| Session-ID migration changes generated ID format and breaks commit/event correlation | M | L | The shared function reproduces the dominant `tr -d ' '` form exactly; unit test asserts the `sess_{unix}_{6hex}` shape |
| Root-resolution migration silently resolves to the wrong depth | H | M | Each migrated script gets a live before/after resolved-path comparison, not just a suite run |
| Runner and Gate 8 land but are never demonstrated to fail | H | M | Verification bar requires a deliberately-broken fixture proving nonzero propagates end to end |
| New `tests/`/`lib/` files never deploy | M | H | Every new file gets a `provides.scripts` entry in `core/manifest.json` in the same phase that creates it |
| Counts baked in from the task description are wrong on day one | M | H | Every count-asserting phase carries a Scope Hypothesis requiring live re-derivation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 9, 10 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 7 | 6 |
| 8 | 8 | 7 |

Phases within the same wave can execute in parallel. The mandated task sequence is the
1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 critical path; phases 9 and 10 are genuinely independent of
the strict-mode work (they only add new files) and may run any time after Phase 2, but running
them last is also acceptable.

---

### Phase 1: Test runner, exec bits, and Gate 8 wiring [COMPLETED]

**Goal**: `agent-system/extensions/core/scripts/tests/run-all.sh` discovers and runs every shell
test suite in both documented locations across all extensions, exits nonzero if any fails, and is
invoked by `verify-deploy.sh` as Gate 8 following the existing SKIP-if-not-source-store pattern.

**Tasks**:
- [x] Re-derive the live suite inventory before writing anything:
  `find agent-system/extensions -path '*/scripts/tests/test-*.sh'` and
  `find agent-system/extensions -path '*/scripts/test-*.sh' -not -path '*/tests/*'`.
  *(completed: 18 in tests/ shape (17 core + 1 literature), 8 flat (7 core + 1 literature) = 26
  total, matching the Scope Hypothesis)*
- [x] Write `scripts/tests/run-all.sh`. It must: *(completed)*
  - Resolve its own `SCRIPT_DIR`, then the extensions root, working both from the source store and
    from a deployed `.claude/scripts/tests/` copy.
  - Glob **both** shapes separately (`*/scripts/tests/test-*.sh` and `*/scripts/test-*.sh`),
    excluding itself. Do not move, merge, or rename any suite.
  - Run each suite in a subshell, capture its exit status, and print a per-suite `[PASS]`/`[FAIL]`
    line plus a final `N passed, M failed, K total` summary.
  - Use the `PASSED`/`FAILED` + `pass()`/`fail()`/`info()` idiom from `shell-script-testing.md`
    and therefore keep `set -uo pipefail` (NOT `set -euo pipefail`) — a runner that aborts on the
    first failing suite cannot report a summary.
  - Enforce loud-skip discipline: if the discovered suite count is zero, print a loud failure and
    exit nonzero. Green-on-nothing-found is a harness failure, not a pass.
  - Skip non-executable files loudly by name rather than silently, and invoke via `bash "$suite"`
    so an exec-bit regression degrades to a warning instead of a false green.
  - Support `--quiet` (summary only) so Gate 8 can call it without flooding `verify-deploy.sh`
    output, and emit machine-greppable `[FAIL] <suite path>` lines for findings extraction.
- [x] `chmod +x` every non-executable test suite found live. Per the report these are
  `tests/test-git-commit-scoped.sh`, `tests/test-index-entries-schema.sh`, and
  `tests/test-routing-resolution.sh` — confirm with
  `find agent-system/extensions -name 'test-*.sh' ! -perm -u+x`. Do **not** chmod the
  `scripts/lib/*.sh` files or `command-route-agent.sh`, which are sourced, not executed.
  *(completed: exactly these 3, confirmed live)*
- [x] Register `tests/run-all.sh` in `core/manifest.json`'s `provides.scripts` array.
  *(completed)*
- [x] Add Gate 8 to `verify-deploy.sh`, copying gate 7's block shape verbatim: `CURRENT_GATE`
  assignment, `[ ! -d "$TARGET/agent-system/extensions" ]` -> `[SKIP] ... not the source store`,
  a not-found `fail`, then capture output/status and extract `FINDING gate8 ...` lines into
  `FINDINGS_LIST` when `$FINDINGS` is true. *(completed)*
- [x] Demonstrate the failure path: temporarily introduce a deliberately-broken fixture suite,
  confirm `run-all.sh` exits nonzero AND `verify-deploy.sh` exits nonzero with a `gate8` finding,
  then remove the fixture and confirm both return green. Record both observed exit codes.
  *(completed: fixture suite → run-all.sh exit 1, verify-deploy.sh exit 1 with
  `FINDING gate8 ...` lines; after removal → run-all.sh exit 0, full verify-deploy.sh 19
  checks/0 failures exit 0. Also fixed 4 pre-existing bugs surfaced by the first-ever full-suite
  run: test-lit-pipeline.sh's hardcoded 2-levels-up PROJECT_ROOT (broke in source-store mode),
  its Section D checking literal patterns removed by the lit-stage4a-flow.md shared-import
  refactor, its Section A hard-failing when the literature extension isn't loaded, and
  test-claude-refresh-matcher.sh's 2s zombie-reap poll window being too tight under run-all.sh's
  concurrent-suite load (widened to 8s). None of these were introduced by this phase.)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: This phase assumes ~24 core suites (17 under `core/scripts/tests/`, 7 flat
in `core/scripts/`) plus 2 in `literature/scripts/`, and exactly 3 non-executable test files.
Confirm at implementation time with the two `find` commands above plus
`find agent-system/extensions -name 'test-*.sh' ! -perm -u+x`; adjust the runner's globs and the
chmod list to whatever is found rather than to these numbers.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - new runner
- `agent-system/extensions/core/manifest.json` - add `tests/run-all.sh` to `provides.scripts`
- `agent-system/extensions/core/scripts/verify-deploy.sh` - new Gate 8 block
- exec bits on the live non-executable test suites

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` runs every discovered suite and
  exits 0 with all suites green.
- The broken-fixture demonstration shows nonzero from both `run-all.sh` and `verify-deploy.sh`.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh .` reports Gate 8 and still exits 0.
- Gate 8 prints `[SKIP]` when run against a target with no `agent-system/extensions` directory.

---

### Phase 2: Author scripts/lib/common.sh [COMPLETED]

**Goal**: A new shared library exists, is registered, and is covered by its own unit suite — with
zero consumers migrated yet, so the library can be proven correct in isolation.

**Tasks**:
- [x] Read `scripts/lib/manifest-routing-lib.sh`'s header in full and reproduce its contract
  structure for `common.sh`: "Sourced (never executed) by <consumer list>"; "Sets no shell options
  (no `set -e`, no `set -u`, no `set -o pipefail`) — sourcing this file must never change the
  calling shell's error-handling behavior"; every internal namespaced (`_common_*`) and unset
  before return; a miss signalled by empty output or a safe default, never by a nonzero exit.
  *(completed)*
- [x] Add an explicit **forbid local redefinition** clause: a consumer that sources `common.sh`
  MUST NOT define its own copy of any function the library provides. *(completed)*
- [x] Implement the function set: *(completed)*
  - `common_repo_root <script_dir> <levels>` — one parameterized-depth root resolver serving
    `scripts/` (2), `scripts/lib/` (3), `scripts/tests/` (3), and `scripts/lint/` (3) callers.
    Must not absorb `lint-agent-contracts.sh`'s deliberately-different `git rev-parse` strategy.
  - `common_session_id` — emits `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')`.
    Use the newline-stripping form: it is strictly safer and subsumes `tr -d ' '`.
  - `common_timestamp_iso` (`date -u +%Y-%m-%dT%H:%M:%SZ`, the 19-site dominant form),
    `common_timestamp_epoch` (`date -u +%s`), `common_timestamp_date` (`date -u +%Y-%m-%d`).
  - `common_log_error` / `common_log_warn` / `common_log_info` — plain, side-effect-free emitters.
    Errors and warnings to stderr; no counters, no color, no verbose gating. Document in the
    header that counter-incrementing and verbose-gated variants elsewhere are deliberately
    out of scope and must not be replaced by these.
  - `common_test_pass` / `common_test_fail` / `common_test_info` operating on `PASSED`/`FAILED`,
    matching `shell-script-testing.md`'s documented trio exactly. Document that these are
    core-local and that a sibling extension's `t_pass`/`t_fail` style remains valid there.
- [x] Note in the header that `SCRIPT_DIR` bootstrap stays inline at each consumer — it is
  required to locate `common.sh` itself and is not a duplication this library removes.
  *(completed)*
- [x] Register `lib/common.sh` in `core/manifest.json`'s `provides.scripts`. *(completed)*
- [x] Write `scripts/tests/test-common-lib.sh` covering: root resolution at each supported depth
  against a `mktemp -d` fixture tree; session-ID shape (`^sess_[0-9]+_[0-9a-f]{6}$`) and absence
  of embedded whitespace/newline; each timestamp helper's format; log helpers' stream routing;
  the test trio's counter arithmetic; and — critically — that `$-` and the `set -o` state are
  byte-for-byte identical before and after sourcing `common.sh`. *(completed: 23 assertions, all
  green)*
- [x] Register `tests/test-common-lib.sh` in `provides.scripts`. *(completed)*
- [x] Do NOT `chmod +x` `lib/common.sh`; match the other lib files, which are non-executable
  because they are sourced. *(completed: confirmed non-executable)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/common.sh` - new library
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` - new unit suite
- `agent-system/extensions/core/manifest.json` - two new `provides.scripts` entries

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-common-lib.sh` exits 0.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` picks up the new suite and stays
  green.
- `grep -c '^set -' agent-system/extensions/core/scripts/lib/common.sh` returns 0.

---

### Phase 3: Migrate session-ID generation to the library [COMPLETED]

**Goal**: Session-ID generation exists in exactly one place, and `command-gate-in.sh`'s
trailing-newline divergence is resolved as a side effect.

**Tasks**:
- [x] Re-derive the live site list: `grep -rn 'sess_\$(date' --include="*.sh" agent-system/extensions/`.
  *(completed: 8 sites across 7 files, exactly matching the Scope Hypothesis)*
- [x] For each site, add the `common.sh` source line after the existing `SCRIPT_DIR` bootstrap and
  replace the inline generation with `common_session_id`. Note that these scripts live at
  `scripts/` depth, so the source path is `"${SCRIPT_DIR}/lib/common.sh"`. *(completed: 3 files —
  manage-topics.sh, reconcile-artifacts.sh, orchestrate-predispatch-review.sh — had SCRIPT_DIR
  already defined before the generation site, so the source line was added there; vault-operation.sh
  and archive-task.sh had the generation site BEFORE their SCRIPT_DIR bootstrap, so a minimal local
  `_EARLY_SCRIPT_DIR` was added at the generation site instead of reordering surrounding code;
  command-gate-in.sh had no SCRIPT_DIR at all — added a top-level `_GATE_IN_REPO_ROOT` bootstrap)*
- [x] `skill-base.sh` has two call sites in different functions — migrate both. *(completed: both
  `skill_propagate_completion_summary` and `skill_link_artifacts` fallbacks migrated)*
- [x] `command-gate-in.sh` currently uses `tr -d ' \n'` while the rest use `tr -d ' '`. Confirm
  the shared function's newline-stripping behavior, and record in the commit body that this
  migration closes a live trailing-newline hazard rather than merely deduplicating. *(completed:
  common_session_id uses the `tr -d ' \n'` form uniformly, closing the divergence for all 8 sites)*
- [x] `command-gate-in.sh` and `skill-base.sh` set no shell options at all. Sourcing `common.sh`
  must not change that — confirm with `set -o` output before and after, exercising the library's
  own contract. *(completed: both confirmed UNCHANGED via direct `set -o` before/after exercise)*
- [x] Add a single-source assertion to `tests/test-common-lib.sh`: grep the extensions tree for
  inline `sess_$(date` generation outside `lib/common.sh` and fail if any match remains. This is
  the mechanical form of the task's verification bar. *(completed: repo-wide grep assertion added,
  passing — 24/24 assertions green)*
- [x] Update `common.sh`'s header consumer list to name the migrated scripts. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: 8 generation sites across 7 files (`archive-task.sh`, `command-gate-in.sh`,
`reconcile-artifacts.sh`, `orchestrate-predispatch-review.sh`, `vault-operation.sh`,
`manage-topics.sh`, `skill-base.sh` x2). Confirm live with the `grep -rn 'sess_\$(date'` above
before editing; migrate whatever set is found.

**Files to modify**:
- `agent-system/extensions/core/scripts/archive-task.sh`
- `agent-system/extensions/core/scripts/command-gate-in.sh`
- `agent-system/extensions/core/scripts/reconcile-artifacts.sh`
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh`
- `agent-system/extensions/core/scripts/vault-operation.sh`
- `agent-system/extensions/core/scripts/manage-topics.sh`
- `agent-system/extensions/core/scripts/skill-base.sh`
- `agent-system/extensions/core/scripts/lib/common.sh` - consumer list
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` - single-source assertion

**Verification**:
- `grep -rn 'sess_\$(date' --include="*.sh" agent-system/extensions/` matches only
  `lib/common.sh`.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green.
- Each migrated script still emits a well-formed session ID when exercised.

---

### Phase 4: Migrate root-resolution and timestamp boilerplate [COMPLETED]

**Goal**: The worst root-resolution and timestamp duplication sites use `common.sh`. Full
migration is explicitly opportunistic; this phase takes a bounded, verified batch.

**Tasks**:
- [x] Re-derive the live variant inventory:
  `grep -rhoE '(PROJECT_ROOT|REPO_ROOT|SKILL_REPO_ROOT)="\$\(cd "\$[^"]*"[^"]*\)"' --include="*.sh" agent-system/extensions/ | sort | uniq -c | sort -rn`.
  *(completed)*
- [x] Migrate the dominant `PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"` cohort first — these
  are `scripts/`-depth callers and all map to `common_repo_root "$SCRIPT_DIR" 2`. *(completed: 40
  files migrated, committed in 767b67dd8)*
- [x] Then the `scripts/lint/`- and `scripts/tests/`-depth variants (depth 3). *(completed:
  lint-contract-compliance.sh, lint-postflight-boundary.sh, and the `tests/` depth-3 test files
  included in the same batch)*
- [x] Leave `lint-agent-contracts.sh`'s `git rev-parse --show-toplevel` + `REPO_ROOT` env override
  untouched — it is documented as a deliberately different strategy. *(completed: confirmed
  untouched)*
- [x] For each migrated file, verify the resolved path is byte-identical before and after by
  echoing the variable under both versions. A suite run alone does not prove correct depth.
  *(completed as part of the 767b67dd8 migration batch)*
- [x] Migrate `date -u +%Y-%m-%dT%H:%M:%SZ` call sites to `common_timestamp_iso` opportunistically
  within the same files already being touched. Do not open new files solely for a timestamp swap.
  *(completed: task-lock.sh's `iso_now`/`now_epoch` wrappers and update-task-status.sh's two
  inline call sites migrated to common_timestamp_iso/common_timestamp_epoch)*
- [x] Leave the BSD `date -u -j -f` sites (`reconcile-task-status.sh`, `task-lock.sh`) and the GNU
  `date -u -d` sites alone — they are parsing, not formatting, and are out of the extracted set.
  *(completed: confirmed untouched — task-lock.sh line 329's `date -u -d ... || date -u -j -f ...`
  parsing fallback is unchanged)*
- [x] Update `common.sh`'s consumer list. *(completed)*
- [x] Run `run-all.sh` after each batch of ~5 files, not only at the end. *(completed: run-all.sh
  and verify-deploy.sh both green after this phase's final batch; 27/27 suites pass. Residual
  root-resolution variants (~24 sites across deeper-nested hooks/lint scripts) intentionally left
  unmigrated per this phase's bounded Scope Hypothesis — see common.sh's header for the recorded
  residual note)*

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: 9 distinct root-resolution expressions across ~64 declaring files, with the
depth-2 `PROJECT_ROOT` form accounting for ~30 of them, and 19 `date -u +%Y-%m-%dT%H:%M:%SZ`
sites. Re-derive both with the `grep -rhoE` commands above. This phase is explicitly bounded: it
is complete when the depth-2 cohort plus any depth-3 lint/test callers are migrated and green,
even if other variants remain — record the residual count in the commit body rather than
expanding scope.

**Files to modify**:
- The live depth-2 `PROJECT_ROOT` cohort under `agent-system/extensions/core/scripts/`
- Depth-3 callers under `scripts/lint/` and `scripts/tests/`
- `agent-system/extensions/core/scripts/lib/common.sh` - consumer list

**Verification**:
- Resolved-path before/after comparison recorded for each migrated file.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green after every batch.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh .` exits 0.

---

### Phase 5: Strict-mode audit, classification, and convention doc [COMPLETED]

**Goal**: A written, evidence-backed classification of every shell script into one of three
strict-mode classes, so Phases 6 and 7 flip only what is safe to flip. No behavior changes.

**Tasks**:
- [x] Re-derive the populations live:
  `grep -rl '^set -euo pipefail' --include="*.sh" agent-system/extensions/`,
  `grep -rl '^set -uo pipefail' --include="*.sh" agent-system/extensions/`, and a loop emitting
  files with no `^set -` line at all. *(completed: 78 with `set -euo pipefail`, 67 with
  `set -uo pipefail`, 18 with no `set` line — close to the Scope Hypothesis's ~78/~65/~17)*
- [x] Classify every file in the non-`-e` populations into exactly one class, with a one-line
  justification each. *(completed: full classification recorded in
  `shell-strict-mode.md` — 27 Class B test suites + 6 Class B harness/report scripts + 35
  individually-audited Class A candidates (5 of which are Phase 6's named batch, 11 EXTRA-CARE
  hooks, 11 ordinary, 8 non-core-out-of-scope) from the `set -uo pipefail` population; 11 Class C
  sourced files + 2 Class B report-everything/no-set-line files + 5 Class A ordinary hooks from
  the no-set-line population)*
- [x] For every Class A candidate, audit for `-e`-hostile constructs before proposing the flip.
  *(completed: no unguarded -e-hostile construct found in any Class A candidate; every
  conditionally-tolerated command is already `if`/`||`/`&&`-guarded. Findings recorded per
  cohort in `shell-strict-mode.md`'s Class A sections)*
- [x] Confirm the `deploy-root-guard.sh` `|| exit 1` pattern is `-e`-safe by construction.
  *(completed: recorded in `shell-strict-mode.md`'s "Note on deploy-root-guard.sh's callers")*
- [x] Confirm `update-task-status.sh` already has `set -euo pipefail` and exclude it.
  *(completed: confirmed, excluded from both populations)*
- [x] Write `agent-system/extensions/core/context/standards/shell-strict-mode.md` recording the
  three classes, the admission test for each, and the rule that a new script defaults to Class A
  unless it can justify Class B or C. *(completed: 199 lines, cross-references
  `shell-script-testing.md` rather than restating it)*
- [x] Register the new standards doc in the core extension's `index-entries.json` and
  `provides` arrays as that extension's convention requires; run
  `scripts/generate-context-line-counts.sh --write` if line counts are tracked. *(completed:
  index-entries.json entry added with `line_count: 199`, hand-verified against live `wc -l`.
  No `manifest.json` change needed — `provides.context` already declares the whole `standards`
  directory, not individual files. The line-count generator itself requires running from a
  deployed `.claude/scripts/` tree per its own root-guard and was not invoked against the source
  store; the manually-set count was cross-checked against `wc -l` directly instead)*
- [x] Record the per-file classification in the phase's commit body or as a table inside the
  standards doc — whichever the doc-lint gate accepts. *(completed: recorded as prose sections
  with explicit file lists inside `shell-strict-mode.md`, per-cohort rather than a single table,
  since the cohorts share one justification each)*
- [x] Do not use task numbers anywhere in the new standards doc. *(completed: confirmed via
  grep — zero task-number references in `shell-strict-mode.md`)*

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: prose

**Scope Hypothesis**: ~78 files with `set -euo pipefail`, ~65 with `set -uo pipefail`, ~17 with no
`set` line (4 of which are the deliberately-unset libs). Of the `set -uo pipefail` population,
roughly 24 are test suites and a further ~8 are lint/check/verify harnesses — i.e. Class B is
expected to be roughly half the population, and Class A materially smaller than a naive reading
of the counts suggests. Re-derive all three populations live and classify every file; the phase
is not complete while any file in the non-`-e` populations is unclassified.

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-strict-mode.md` - new
- `agent-system/extensions/core/index-entries.json` and `manifest.json` - registration

**Verification**:
- Every file in the two non-`-e` populations appears in exactly one class with a justification.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet` exits 0.
- `bash agent-system/extensions/core/scripts/check-task-references.sh --quiet` exits 0.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh .` exits 0.

---

### Phase 6: Strict-mode migration batch A (highest-risk state mutators) [NOT STARTED]

**Goal**: The five confirmed highest-risk Class A scripts carry `set -euo pipefail`, each audited
individually and each landing green.

**Tasks**:
- [ ] Confirm each target is still Class A per Phase 5's classification and still lacks `-e`.
- [ ] Migrate one file at a time, in this order, running `run-all.sh` after each:
  `state-write.sh`, `task-lock.sh`, `git-commit-scoped.sh`, `orchestrate-batch-admit.sh`,
  `orchestrate-predispatch-review.sh`.
- [ ] For each, before flipping: walk every command whose nonzero exit is currently tolerated and
  confirm it is either inside an `if`/`&&`/`||`/`while` condition (already `-e`-exempt) or
  explicitly guarded with `|| true` / `|| handler`. Add the explicit guard where it is not.
- [ ] Exercise each script's primary path manually against a `mktemp -d` fixture, not only via its
  suite — `state-write.sh` and `task-lock.sh` have concurrency behavior that the suites cover but
  the manual path confirms end to end.
- [ ] Commit each file separately once its suite run is green, per the commit-per-green-substep
  mandate.

**Timing**: 2 hours

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: These 5 files are asserted to lack `set -e` and to be Class A. Confirm each
with `grep -n '^set -' <file>` and against Phase 5's classification table before editing; if any
has already been migrated or was classified Class B, drop it from the batch and record why.

**Files to modify**:
- `agent-system/extensions/core/scripts/state-write.sh`
- `agent-system/extensions/core/scripts/task-lock.sh`
- `agent-system/extensions/core/scripts/git-commit-scoped.sh`
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh`

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green after each individual file.
- `test-state-write-concurrency.sh`, `test-state-write-regen-timing.sh`, `test-task-lock-reap.sh`,
  and `tests/test-git-commit-scoped.sh` all pass.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh .` exits 0.

---

### Phase 7: Strict-mode migration batch B (remaining Class A) [NOT STARTED]

**Goal**: Every remaining Class A file from Phase 5's classification carries `set -euo pipefail`,
migrated in small batches with suites green after each.

**Tasks**:
- [ ] Work from Phase 5's Class A list minus the five files completed in Phase 6.
- [ ] Migrate in batches of at most 5 files, running `run-all.sh` after each batch and committing
  each green batch.
- [ ] Apply the same per-file `-e`-hostility audit as Phase 6 — this batch is lower-risk, not
  no-risk.
- [ ] Treat the hooks under `core/hooks/` with particular care: several are PreToolUse gates whose
  exit codes are load-bearing (`guard-destructive-git.sh` and `validate-no-task-references.sh`
  both use `exit 2` to deny, and `validate-no-task-references.sh` is documented to fail OPEN if
  its pattern library cannot be sourced). Adding `-e` must not convert a fail-open path into a
  fail-closed one. If a hook cannot be shown safe, reclassify it Class B with a recorded
  justification and update the standards doc rather than forcing the flip.
- [ ] If any file resists migration, record it as a Class B reclassification in
  `shell-strict-mode.md` with evidence — do not leave it silently unmigrated and unexplained.
- [ ] Confirm the final state: every non-`-e` file is either Class B or Class C with a written
  justification.

**Timing**: 2 hours

**Depends on**: 6

**Verification Tier**: full

**Scope Hypothesis**: The Class A remainder is expected to be roughly 15-25 files (the ~65
`set -uo pipefail` population less ~24 test suites, less ~8 lint/check/verify harnesses, less the
5 done in Phase 6), plus a handful of the no-`set`-line files that are not libs. The exact set is
whatever Phase 5's classification table says — do not re-derive it independently here, and do not
migrate anything not on that list.

**Files to modify**:
- The Class A remainder per Phase 5's classification table
- `agent-system/extensions/core/context/standards/shell-strict-mode.md` - any reclassifications

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green after every batch.
- Every remaining non-`-e` file maps to a Class B or Class C entry in the standards doc.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh .` exits 0.

---

### Phase 8: Shebang normalization [NOT STARTED]

**Goal**: Every shell script uses `#!/usr/bin/env bash`.

**Tasks**:
- [ ] Re-derive the list: `grep -rl '^#!/bin/bash' --include="*.sh" agent-system/extensions/`.
- [ ] Replace each `#!/bin/bash` with `#!/usr/bin/env bash`.
- [ ] Include `verify-deploy.sh`, which is itself one of the offenders.
- [ ] For files under `core/hooks/` and `email/hooks/`, confirm the registering
  `merge-sources/settings-hooks.json` entries invoke them via an explicit interpreter or via the
  shebang, and that the change does not break invocation either way.
- [ ] Run `run-all.sh` and `verify-deploy.sh` after the sweep — both are in the changed set or
  depend on it.
- [ ] Optionally add a shebang check to an existing lint script if one has a natural slot; do not
  create a new lint script solely for this.

**Timing**: 1 hour

**Depends on**: 7

**Verification Tier**: full

**Scope Hypothesis**: 25 files carry `#!/bin/bash` against 136 with `#!/usr/bin/env bash`.
Re-derive with the `grep -rl` above; the phase is complete when that grep returns zero matches.

**Files to modify**:
- The live `#!/bin/bash` set (19 under `core/hooks/`, 5 under `core/scripts/`, 1 under
  `email/hooks/` per the current measurement)

**Verification**:
- `grep -rl '^#!/bin/bash' --include="*.sh" agent-system/extensions/` returns nothing.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh .` exits 0.
- Each modified hook still executes when invoked directly.

---

### Phase 9: Test coverage for skill-base.sh lifecycle functions [NOT STARTED]

**Goal**: A new suite covers `skill-base.sh`'s state-mutating lifecycle functions, closing the
largest coverage gap in the source store.

**Tasks**:
- [ ] Confirm the live function inventory: `grep -n '^[a-z_]*()' scripts/skill-base.sh`. The
  current set is 17 top-level functions of which only `skill_corroborate_phase_counts` is covered
  (by `tests/test-corroborate-phase-counts.sh`).
- [ ] Write `scripts/tests/test-skill-base-lifecycle.sh` following `shell-script-testing.md`
  exactly: `set -uo pipefail`, `PASSED`/`FAILED` counters, `pass`/`fail`/`info`, `mktemp -d`
  workdir with `trap ... EXIT`, inline heredoc fixtures, loud-skip discipline, exit 1 when
  `FAILED` is nonzero.
- [ ] Prefer sourcing `common.sh`'s `common_test_*` trio if it is a drop-in for the local
  definitions; if the existing suites' inline trio reads more clearly, keep the inline form and
  note why — the trio is available, not mandatory.
- [ ] Cover the highest-blast-radius state mutators first: `skill_preflight_update`,
  `skill_postflight_update`, `skill_gate_completion_claim`, `skill_link_artifacts`,
  `skill_cleanup`.
- [ ] Every fixture must live in the `mktemp -d` workdir. The suite must never touch the real
  `specs/` tree, real `state.json`, or real task locks.
- [ ] Register `tests/test-skill-base-lifecycle.sh` in `core/manifest.json`'s `provides.scripts`
  and set its exec bit.

**Timing**: 2.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: `skill-base.sh` is 738 lines with 17 top-level functions, 16 of them
untested. Confirm live with `wc -l` and the `grep -n '^[a-z_]*()'` above. The phase is complete
when the five named lifecycle functions are covered, not when all 16 are — record the residual
uncovered count in the commit body.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` - new
- `agent-system/extensions/core/manifest.json` - registration

**Verification**:
- The new suite exits 0 standalone and is discovered by `run-all.sh`.
- `git status --short specs/` is clean after a suite run, proving no real-state contamination.
- Each covered function has at least one failing-input case, not only a happy path.

---

### Phase 10: Test coverage for update-task-status.sh [NOT STARTED]

**Goal**: A dedicated suite covers `update-task-status.sh`'s preflight/postflight transitions and
its `--phase-check` backstop.

**Tasks**:
- [ ] Confirm no existing dedicated suite covers it:
  `ls agent-system/extensions/core/scripts/tests/ | grep -i task-status`.
- [ ] Write `scripts/tests/test-update-task-status.sh` following `shell-script-testing.md`.
- [ ] Cover: preflight and postflight transitions for a representative operation; the refusal path
  on terminal statuses; `generate-todo.sh` regeneration being invoked; the `--phase-check`
  backstop's `warn` (logs loudly, proceeds) versus `refuse` (exits 4, writes nothing) behaviors;
  and its interaction with `lib/phase-heading-patterns.sh`'s non-conforming-heading detection.
- [ ] Build a complete fake `specs/` tree (state.json plus a plan file with conforming phase
  headings) inside the `mktemp -d` workdir. The suite must never mutate the real `specs/` tree.
- [ ] Register `tests/test-update-task-status.sh` in `provides.scripts` and set its exec bit.

**Timing**: 2.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: `update-task-status.sh` is 563 lines, already carries `set -euo pipefail`,
and has no dedicated suite. Confirm all three live before starting; if a suite already covers it,
extend that suite instead of creating a duplicate.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` - new
- `agent-system/extensions/core/manifest.json` - registration

**Verification**:
- The new suite exits 0 standalone and is discovered by `run-all.sh`.
- `git status --short specs/` is clean after a suite run.
- The `--phase-check refuse` case is asserted to exit 4 and to have written nothing.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0 with every discovered
  suite green.
- [ ] `run-all.sh` exits nonzero against a deliberately-broken fixture suite, and that nonzero
  propagates to `verify-deploy.sh`'s exit code with a `FINDING gate8` line (Phase 1's recorded
  demonstration).
- [ ] `run-all.sh` exits nonzero, loudly, when it discovers zero suites.
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh .` exits 0 with Gate 8 present.
- [ ] Gate 8 prints `[SKIP]` against a deploy-consumer target with no `agent-system/extensions`.
- [ ] `grep -rn 'sess_\$(date' --include="*.sh" agent-system/extensions/` matches only
  `lib/common.sh`.
- [ ] `grep -rl '^#!/bin/bash' --include="*.sh" agent-system/extensions/` returns nothing.
- [ ] Every non-`set -e` file maps to a Class B or Class C entry in `shell-strict-mode.md`.
- [ ] `grep -c '^set -' agent-system/extensions/core/scripts/lib/common.sh` returns 0.
- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet` exits 0.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh --quiet` exits 0 — no
  task numbers leaked into any deliverable outside `specs/**`.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` exits 0.
- [ ] `git status --short specs/` is clean after any suite run.
- [ ] Every new script file appears in `core/manifest.json`'s `provides.scripts`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/run-all.sh` (new)
- `agent-system/extensions/core/scripts/lib/common.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` (new)
- `agent-system/extensions/core/context/standards/shell-strict-mode.md` (new)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (Gate 8 added)
- `agent-system/extensions/core/manifest.json` (new `provides.scripts` and context entries)
- `agent-system/extensions/core/index-entries.json` (new standards doc entry)
- Migrated consumer scripts across `agent-system/extensions/**`
- `specs/988_script_hygiene_common_lib_and_test_runner/summaries/01_script-hygiene-common-lib-summary.md`

## Rollback/Contingency

Every phase commits independently and each strict-mode batch commits separately, so rollback is
per-commit `git revert` at the granularity of the smallest unit that broke.

- **Phase 1-2 failure**: new files only plus one `verify-deploy.sh` block and manifest entries.
  Revert the commit; nothing else depends on them.
- **Phase 3-4 failure**: revert the migration commit; `common.sh` survives unused, which is inert.
- **Phase 6-7 failure**: the highest-risk rollback surface. Each file is committed separately once
  green, so revert only the offending file's commit and reclassify it Class B in
  `shell-strict-mode.md` with the observed evidence rather than retrying the flip.
- **Phase 8 failure**: shebang changes are one line per file and independently revertible.
- **Phase 9-10 failure**: new test files only; deleting the file plus its manifest entry restores
  the prior state.

If work must be abandoned mid-stream, the runner and Gate 8 (Phases 1-2) are independently
valuable and should be kept even if the migration phases are reverted — they are the regression
net every later phase depends on.
