# Implementation Plan: Fix Duplication Gate Scope and EXTENSIONS_ROOT

- **Task**: 84 - fix_duplication_gate_scope_and_extensions_root
- **Status**: [NOT STARTED]
- **Effort**: 7.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/084_fix_duplication_gate_scope_and_extensions_root/reports/01_duplication-gate-scope-and-extensions-root.md`
- **Artifacts**: plans/01_duplication-gate-scope-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The single duplication gate in this codebase (the single-source assertion in
`agent-system/extensions/core/scripts/tests/test-common-lib.sh`) has two independent, compounding
defects: it scans only `*.sh`, so it is structurally blind to the 37 `.md` sites that carry the
duplicated session-ID generator, and it resolves `EXTENSIONS_ROOT` by a fixed `../../..` walk from
`SCRIPT_DIR`, which is correct only in the source-store layout and silently resolves to the repo
root when run from the deployed `.claude/scripts/tests/` copy. This plan repairs the gate first
(root resolution, then scan scope, then regression fixtures), then migrates all 38 real offenders
onto the already-existing `common_session_id()` helper, and finally closes
`errors.json` entry `err_1787022038113_c3VPTR` with evidence.

Definition of done: the gate resolves its root correctly and identically in both run locations,
sees `.md` executable surfaces (`commands/`, `skills/`, `agents/`) while ignoring illustrative
prose (`context/`, `docs/`, `rules/`), fails on a deliberately reintroduced inline generator under
`commands/`, and reports zero live offenders outside `lib/common.sh` from both the source store and
a freshly redeployed tree.

### Research Integration

Findings integrated from the research report:
- Both defects reproduce today by direct execution; the deployed run's apparent success is
  incidental (it scans the whole repository and happens to catch the one `.sh` offender).
- Live inventory (2026-08-24): 52 matching sites — 1 canonical (`lib/common.sh`), 1 self-referential
  test comment, 1 real `.sh` offender (`core/scripts/validate-state.sh`), 37 real `.md` offenders
  under `commands/`/`skills/` across 7 extensions, 12 correctly-excludable illustrative-prose `.md`
  sites under `context/` (11) and `rules/` (1).
- `run-all.sh` in the same `tests/` directory already implements the needed dual-mode resolution
  (probe for `core/manifest.json` at the candidate `../../..` root). Reuse it; do not invent a new
  heuristic. Note its deployed-mode fallback lands on `.claude/scripts`, one level below what this
  gate needs — the `.md` scan needs `.claude/` itself.
- The `.sh` scan must keep its whole-tree reach (only its root is wrong); narrowing it to
  `commands/`/`skills/`/`agents/` would regress detection of `validate-state.sh`.
- `common_session_id()` already exists in `lib/common.sh` with 8 proven `.sh` adopter files
  (9 call sites). No new helper code is needed — the migration target already exists. The task
  description's "10 adopters" figure is superseded by these grep-verified numbers.
- `rules/*.md` is treated the same as `context/*.md` (excluded), confirming the research's open
  question: `rules/git-workflow.md`'s occurrence is a portable-command illustration, not an
  executed surface.

### Prior Plan Reference

No prior plan. `specs/084_fix_duplication_gate_scope_and_extensions_root/plans/` was empty at
planning time.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no roadmap flag was set; roadmap
consultation was skipped.

## Goals & Non-Goals

**Goals**:
- Resolve the gate's scan root deterministically and identically in both the source-store and
  deployed layouts, reusing `run-all.sh`'s `core/manifest.json`-probe pattern.
- Extend the gate to see `.md` executable surfaces (`commands/`, `skills/`, `agents/`) while
  leaving illustrative prose (`context/`, `docs/`, `rules/`) out of scope by construction.
- Add regression fixtures that specifically exercise deployed-mode detection and the
  prose-exclusion boundary, since both are invisible when testing only from the source store.
- Establish one documented replacement idiom for `.md` bash blocks and migrate all 38 real
  offenders (1 `.sh` + 37 `.md`) onto `common_session_id()`.
- Close `errors.json` `err_1787022038113_c3VPTR` with closing evidence.

**Non-Goals**:
- Cloning this gate's pattern to other duplication classes. This task fixes the template; using it
  elsewhere is separate work.
- Adding new helper functions to `lib/common.sh`. `common_session_id()` already exists and suffices.
- Touching the 12 illustrative-prose sites under `context/` and `rules/`. They are documentation
  and stay as they are.
- Changing `run-all.sh` itself. It is the reference pattern, not a target.
- Narrowing or otherwise altering the `.sh` scan's whole-tree reach.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Narrowing scan scope regresses `validate-state.sh` detection | H | M | Keep the `.sh` scan whole-tree over the corrected root (explicit Non-Goal); Phase 3 verification asserts `validate-state.sh` still appears pre-migration |
| 37 `.md` files across 7 extensions is a wide blast radius for one phase | M | H | Migration split across four phases with disjoint per-extension territory (Phases 5-8); each file is independently verifiable and committed per green sub-step |
| `.md` bash blocks execute in varying shell contexts, so a sourcing idiom may not work everywhere | H | M | Phase 5 decides and pilots the idiom on one file before any bulk migration; the chosen idiom reuses the CWD-relative `.claude/scripts/...` convention already used by 138 `.md` files |
| Gate goes red mid-plan (correct behavior) and is mistaken for breakage | M | H | Phases 3 and 4 explicitly declare the expected red state and its exact offender count; the gate is only expected green after Phase 9 |
| Deployed-mode root resolution regresses again on a future `.claude/` layout change | M | L | Probe-based detection fails loudly (empty/no match) rather than silently resolving to the wrong root; Phase 4's fixture pins the deployed-mode behavior |
| Redeploy overwrites source-store edits, or stale deploy masks the fix | M | M | Phase 9 redeploys from source before the deployed-mode verification run; all edits target `agent-system/extensions/**`, never `.claude/**` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4, 5 | 3 |
| 4 | 6, 7, 8 | 5 |
| 5 | 9 | 2, 4, 6, 7, 8 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Repair Dual-Mode Root Resolution [NOT STARTED]

**Goal**: `test-common-lib.sh` resolves its scan root correctly and identically whether run from
`agent-system/extensions/core/scripts/tests/` or from the deployed `.claude/scripts/tests/`.

**Tasks**:
- [ ] Read `agent-system/extensions/core/scripts/tests/run-all.sh`'s layout-detection block (the
      `CANDIDATE_EXT_ROOT` / `core/manifest.json` probe) and reuse its shape verbatim.
- [ ] In `test-common-lib.sh`, replace `EXTENSIONS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"` with
      probe-based detection setting a `SCAN_MODE` variable:
      - source-store (probe hits `$CANDIDATE/core/manifest.json`): `SCAN_ROOT="$CANDIDATE"`
        (`agent-system/extensions/`)
      - deployed (probe misses): `SCAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"` (`.claude/`) — note
        this is one level ABOVE `run-all.sh`'s `DEPLOY_SCRIPTS_ROOT`, because `commands/`,
        `skills/`, and `agents/` live at the `.claude/` top level, not under `.claude/scripts/`.
- [ ] Keep the existing `*.sh` scan unchanged in reach — whole-tree over `SCAN_ROOT`, same
      `--include="*.sh"`, same two exclusion filters.
- [ ] Update the block's leading comment, which currently asserts the source-store-only depth
      assumption, to describe the two modes.
- [ ] Echo the detected mode and resolved root (matching `run-all.sh`'s `say` convention) so a
      failing run is diagnosable.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` - replace fixed-depth
  `EXTENSIONS_ROOT` with the probe-based `SCAN_MODE`/`SCAN_ROOT` pair; update the block comment

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-common-lib.sh` reports mode `source-store`
  and a root ending in `agent-system/extensions`.
- `bash .claude/scripts/tests/test-common-lib.sh` reports mode `deployed` and a root ending in
  `.claude`.
- The deployed run's offender list no longer contains any `agent-system/extensions/...` path —
  proving the whole-repo scan has stopped. It should now list only
  `.claude/scripts/validate-state.sh`.
- Both runs still report exactly one `.sh` offender each (the gate stays red on
  `validate-state.sh`, which Phase 2 fixes).

---

### Phase 2: Migrate the `.sh` Offender [NOT STARTED]

**Goal**: `core/scripts/validate-state.sh` uses `common_session_id()` instead of an inline
generator, removing the last `.sh` offender.

**Tasks**:
- [ ] Confirm whether `validate-state.sh` already sources `lib/common.sh`; if not, add the standard
      `SCRIPT_DIR` bootstrap + `source "${SCRIPT_DIR}/lib/common.sh"` following the idiom used by
      `errors-append.sh`, `generate-todo.sh`, and the other listed adopters.
- [ ] Replace the inline `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')` in the
      `_fix_session` assignment with `"${FIX_SESSION_ID:-$(common_session_id)}"`, preserving the
      existing `FIX_SESSION_ID` env override semantics exactly.
- [ ] Add `scripts/validate-state.sh` to `lib/common.sh`'s "Session-ID generation
      (common_session_id)" consumer list comment.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: exactly one inline generator site exists in `.sh` files across the source
store (`core/scripts/validate-state.sh`, in the `--fix` session-id assignment). Confirm at
implementation time with
`grep -rn 'sess_\$(date' agent-system/extensions/ --include="*.sh"`, expecting exactly three hits:
`lib/common.sh` (canonical), `tests/test-common-lib.sh` (self-referential comment), and this one
offender. If the count differs, migrate every additional real offender found before closing the
phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-state.sh` - source `lib/common.sh` if needed;
  call `common_session_id`
- `agent-system/extensions/core/scripts/lib/common.sh` - append to the consumer-list comment

**Verification**:
- `bash -n agent-system/extensions/core/scripts/validate-state.sh` parses clean.
- `grep -rn 'sess_\$(date' agent-system/extensions/ --include="*.sh"` returns only `lib/common.sh`
  and `tests/test-common-lib.sh`.
- `bash agent-system/extensions/core/scripts/validate-state.sh --fix` (or its dry equivalent) still
  produces a well-formed `sess_<epoch>_<6hex>` session id, and `FIX_SESSION_ID=xyz` still overrides
  it.

---

### Phase 3: Add the `.md`-Scoped Scan [NOT STARTED]

**Goal**: The gate additionally scans `.md` executable surfaces — `commands/`, `skills/`, `agents/`
— in both modes, while leaving `context/`, `docs/`, and `rules/` out of scope by construction
rather than by exclusion list.

**Tasks**:
- [ ] Extract the offender collection into a helper function in `test-common-lib.sh` (e.g.
      `collect_session_id_offenders <mode> <root>`) that emits a newline-separated path list on
      stdout, so both the live assertion and Phase 4's fixtures can call it. Keep the helper
      side-effect-free and never `exit`.
- [ ] Inside the helper: run the existing whole-tree `--include="*.sh"` scan over `<root>`
      unchanged.
- [ ] Add a second `--include="*.md"` scan, scoped per mode:
      - source-store: iterate `<root>/*/{commands,skills,agents}`, skipping directories that do not
        exist (confirmed necessary — `formal` has no `commands/`, `slidev` has none of the three).
      - deployed: scan `<root>/{commands,skills,agents}` directly, no per-extension loop.
- [ ] Merge both scans' results, then apply the existing exclusion filters (`/lib/common.sh`,
      `/tests/test-common-lib.sh`) once, to the merged list, before the pass/fail decision.
- [ ] Record in the block comment that `context/`, `docs/`, and `rules/` are deliberately excluded
      as illustrative prose, and that this exclusion is achieved by positive scoping rather than by
      a growing deny-list.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: the corrected gate should report 38 real offenders in source-store mode —
1 `.sh` (`validate-state.sh`, unless Phase 2 already landed) plus 37 `.md` under
`commands/`/`skills/`, distributed core 11, founder 10, filetypes 5, present 5, cslib 3,
literature 2, epidemiology 1; and the 12 illustrative-prose sites (11 under `core/context/`, 1 in
`core/rules/git-workflow.md`) must be absent from the report. Confirm at implementation time by
diffing the gate's offender list against
`grep -rl 'sess_\$(date' agent-system/extensions/ --include="*.md" | grep -E '/(commands|skills|agents)/'`.
Both figures are hypotheses from a 2026-08-24 count and the class is actively growing — if the live
count differs, use the live count and carry the revised per-extension distribution into Phases 6-8
rather than treating the numbers here as fixed.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` - add
  `collect_session_id_offenders`; add the `.md` scan; merge before filtering

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-common-lib.sh` now FAILS the single-source
  assertion (expected — the gate is correctly red until migration completes) and lists the full
  offender set.
- The reported set matches the Scope Hypothesis diff exactly: no `context/`, `docs/`, or `rules/`
  path appears, and `validate-state.sh` still appears if Phase 2 has not yet landed.
- `bash .claude/scripts/tests/test-common-lib.sh` (running against the not-yet-redeployed tree)
  also reports `.md` offenders under `.claude/commands/` and `.claude/skills/`, proving the
  deployed-mode `.md` scan path is live.
- All other cases in the suite still pass (`Passed: 23` or higher, `Failed: 1`).

---

### Phase 4: Add Dual-Mode and Exclusion Regression Fixtures [NOT STARTED]

**Goal**: Fixture-driven cases pin the two behaviors that were invisible before this task —
deployed-mode `.md` detection, and the prose-exclusion boundary — so neither can silently regress.

**Tasks**:
- [ ] In the suite's existing `mktemp -d` workdir, build a synthetic deployed-layout tree:
      `$WORKDIR/deployed/{commands,skills,agents,context,scripts/lib}`.
- [ ] Plant a positive fixture: `$WORKDIR/deployed/commands/planted.md` containing an inline
      `sess_$(date +%s)_...` generator. Assert `collect_session_id_offenders deployed
      "$WORKDIR/deployed"` returns it.
- [ ] Plant a negative fixture: `$WORKDIR/deployed/context/illustrative.md` containing the same
      string. Assert it is NOT returned — this is the prose-exclusion boundary case.
- [ ] Build a matching synthetic source-store tree (`$WORKDIR/source/core/manifest.json` present,
      plus `$WORKDIR/source/someext/commands/planted.md`) and assert the source-store branch finds
      the planted file and skips extensions lacking `commands/`/`skills/`/`agents/`.
- [ ] Assert the mode probe itself: the source tree resolves `source-store`, the deployed tree
      resolves `deployed`.
- [ ] Use the suite's existing `pass`/`fail`/`info` helpers and PASSED/FAILED counters; do not
      introduce a parallel reporting convention.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` - add the fixture cases

**Verification**:
- All new fixture cases PASS. The suite's total `Passed:` count rises by the number of cases added.
- The suite's only remaining failure is the live single-source assertion (still red until
  migration completes).
- Deliberately breaking the deployed branch (e.g. temporarily pointing it at
  `$SCRIPT_DIR/..`) makes the deployed fixture case FAIL — confirming the fixture actually
  exercises the repaired code path rather than passing vacuously.
- `rm -rf` cleanup still happens via the existing `trap ... EXIT`; no fixture leaks outside
  `$WORKDIR`.

---

### Phase 5: Establish and Pilot the `.md` Replacement Idiom [NOT STARTED]

**Goal**: One documented, verified replacement idiom for inline session-ID generation inside `.md`
bash blocks, proven on a single pilot file before any bulk migration.

**Tasks**:
- [ ] Adopt the CWD-relative deployed-path idiom, consistent with the `bash .claude/scripts/...`
      convention already used by 138 `.md` files in this codebase:
      ```bash
      source .claude/scripts/lib/common.sh
      session_id="$(common_session_id)"
      ```
      Preserve each site's existing variable name (`session_id`, `batch_session_id`,
      `todo_session_id`, ...) — do not rename variables while migrating.
- [ ] Pilot on `agent-system/extensions/core/commands/research.md` (the `Generate Batch Session ID`
      step), preserving the surrounding prose and the bare-`batch_session_id` guidance that follows
      it.
- [ ] Verify the pilot by executing the replacement snippet from the repo root and confirming it
      emits a well-formed `sess_<epoch>_<6hex>` id.
- [ ] Record the idiom in `lib/common.sh`'s header (a short `.md` consumers note alongside the
      existing usage block), so future `.md` authors reach for it instead of re-inlining.
- [ ] Note explicitly, in that same header note, that `context/`, `docs/`, and `rules/` prose sites
      are out of scope and should keep showing the literal generator as documentation.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/commands/research.md` - pilot migration
- `agent-system/extensions/core/scripts/lib/common.sh` - document the `.md` idiom

**Verification**:
- `source .claude/scripts/lib/common.sh && common_session_id` run from the repo root emits a
  matching `^sess_[0-9]+_[0-9a-f]{6}$` id.
- `grep -c 'sess_\$(date' agent-system/extensions/core/commands/research.md` returns 0.
- The gate's offender list shrinks by exactly one entry (`research.md` gone, everything else
  unchanged).

---

### Phase 6: Migrate Core's Remaining `.md` Sites [NOT STARTED]

**Goal**: Every remaining core `commands/` and `skills/` offender uses the Phase 5 idiom.

**Tasks**:
- [ ] Migrate the 7 remaining core commands: `implement.md`, `orchestrate.md`, `plan.md`,
      `review.md`, `spawn.md`, `task.md`, `todo.md`.
- [ ] Migrate the 3 core skills: `skill-fix-it/SKILL.md`, `skill-project-overview/SKILL.md`,
      `skill-todo/SKILL.md`. Note `skill-todo/SKILL.md` documents in prose that it "does not source
      `command-gate-in.sh` and has none of its own" — update that prose to reflect the new
      `lib/common.sh` sourcing rather than leaving a now-false statement.
- [ ] Preserve each site's existing variable name and surrounding prose exactly.
- [ ] Commit per file (each file is independently green).

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: local

**Scope Hypothesis**: 10 remaining core `.md` offenders (7 `commands/*.md` + 3 `skills/*/SKILL.md`),
`research.md` already handled in Phase 5. Confirm at implementation time with
`grep -rl 'sess_\$(date' agent-system/extensions/core/{commands,skills,agents}`, and migrate
whatever that returns rather than the enumerated list if they differ.

**Files to modify**:
- `agent-system/extensions/core/commands/{implement,orchestrate,plan,review,spawn,task,todo}.md`
- `agent-system/extensions/core/skills/{skill-fix-it,skill-project-overview,skill-todo}/SKILL.md`

**Verification**:
- `grep -rl 'sess_\$(date' agent-system/extensions/core/{commands,skills,agents}` returns nothing.
- Each migrated snippet, executed standalone from the repo root, emits a well-formed id.
- The gate's offender list contains no `core/commands/` or `core/skills/` path.

---

### Phase 7: Migrate Founder and Present Extensions [NOT STARTED]

**Goal**: The 15 `.md` offenders in the `founder` and `present` extensions use the Phase 5 idiom.

**Tasks**:
- [ ] Migrate founder's 10 commands: `analyze.md`, `consult.md`, `deck.md`, `finance.md`,
      `legal.md`, `market.md`, `meeting.md`, `project.md`, `sheet.md`, `strategy.md`.
- [ ] Migrate present's 5 commands: `budget.md`, `funds.md`, `grant.md`, `slides.md`,
      `timeline.md`.
- [ ] Preserve each site's existing variable name and surrounding prose exactly.
- [ ] Commit per file.

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: local

**Scope Hypothesis**: 15 offenders (founder 10, present 5), all `commands/*.md`, all matching the
same one-line `session_id="sess_$(date ..."` shape as `founder/commands/deck.md`. Confirm with
`grep -rn 'sess_\$(date' agent-system/extensions/{founder,present}/` before starting; if any site
has a materially different shape (multi-line, conditional, or inside a non-bash fence), handle it
individually and note the deviation rather than applying a blind substitution.

**Files to modify**:
- `agent-system/extensions/founder/commands/*.md` (10 files)
- `agent-system/extensions/present/commands/*.md` (5 files)

**Verification**:
- `grep -rl 'sess_\$(date' agent-system/extensions/{founder,present}/` returns nothing.
- Spot-check two migrated snippets by executing them from the repo root.
- The gate's offender list contains no `founder/` or `present/` path.

---

### Phase 8: Migrate Filetypes, CSLib, Literature, and Epidemiology [NOT STARTED]

**Goal**: The remaining 11 `.md` offenders across the four smaller extensions use the Phase 5 idiom.

**Tasks**:
- [ ] Migrate filetypes' 5 commands: `convert.md`, `edit.md`, `scrape.md`, `sheet.md`, `table.md`.
- [ ] Migrate cslib's 3 sites: `commands/pr.md`, `commands/vet.md`,
      `skills/skill-cslib-vet/SKILL.md`.
- [ ] Migrate literature's 2 skills: `skill-cite/SKILL.md`, `skill-literature/SKILL.md`.
- [ ] Migrate epidemiology's 1 command: `epi.md`.
- [ ] Preserve each site's existing variable name and surrounding prose exactly.
- [ ] Commit per file.

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: local

**Scope Hypothesis**: 11 offenders (filetypes 5, cslib 3, literature 2, epidemiology 1). Confirm
with `grep -rn 'sess_\$(date' agent-system/extensions/{filetypes,cslib,literature,epidemiology}/`
before starting; migrate what that returns.

**Files to modify**:
- `agent-system/extensions/filetypes/commands/*.md` (5 files)
- `agent-system/extensions/cslib/commands/{pr,vet}.md`,
  `agent-system/extensions/cslib/skills/skill-cslib-vet/SKILL.md`
- `agent-system/extensions/literature/skills/{skill-cite,skill-literature}/SKILL.md`
- `agent-system/extensions/epidemiology/commands/epi.md`

**Verification**:
- `grep -rl 'sess_\$(date' agent-system/extensions/{filetypes,cslib,literature,epidemiology}/`
  returns nothing.
- Spot-check two migrated snippets by executing them from the repo root.
- The gate's offender list is now empty in source-store mode.

---

### Phase 9: Green-Gate Verification, Acceptance Test, and Error Closure [NOT STARTED]

**Goal**: The gate passes identically from both run locations, provably fails on a reintroduced
offender, and `err_1787022038113_c3VPTR` is closed with evidence.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-common-lib.sh` — expect
      `Failed: 0`.
- [ ] Redeploy from source (`bash .claude/scripts/deploy-headless.sh` or the project's standard
      deploy path) so `.claude/` reflects the migrated source store.
- [ ] Run `bash .claude/scripts/tests/test-common-lib.sh` — expect `Failed: 0` and an offender set
      identical (empty) to the source-store run.
- [ ] Acceptance test: temporarily plant an inline
      `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')` into a real
      `agent-system/extensions/core/commands/*.md`, confirm the gate FAILS and names that file,
      then revert the plant and confirm the gate returns to green. Record the failing output as
      closing evidence. Do not commit the planted state.
- [ ] Run the full suite runner `bash agent-system/extensions/core/scripts/tests/run-all.sh` to
      confirm no sibling suite regressed.
- [ ] Confirm the 12 illustrative-prose sites are still present and untouched
      (`grep -rl 'sess_\$(date' agent-system/extensions/core/{context,rules}` returns 12 files).
- [ ] Update `specs/errors.json` entry `err_1787022038113_c3VPTR`: set `fix_status` to `"fixed"`,
      add `fixed_date` (ISO8601 UTC) and `fix_task` (84), matching the schema used by the five
      already-closed entries. Append a short closing-evidence note recording that both run
      locations now resolve to their intended roots and report an identical empty offender set.
- [ ] Verify `specs/errors.json` remains valid JSON (`jq . specs/errors.json > /dev/null`).

**Timing**: 1.25 hours

**Depends on**: 2, 4, 6, 7, 8

**Verification Tier**: full

**Files to modify**:
- `specs/errors.json` - close `err_1787022038113_c3VPTR`

**Verification**:
- Both `test-common-lib.sh` invocations report `Failed: 0`.
- `run-all.sh` reports no new failures relative to its pre-task baseline.
- The reintroduction acceptance test produced a recorded FAIL naming the planted file, and the
  working tree is clean of the plant afterwards.
- `grep -rl 'sess_\$(date' agent-system/extensions/` returns exactly 13 files: `lib/common.sh`,
  `tests/test-common-lib.sh`, and the 12 illustrative-prose sites.
- `jq '.errors[]|select(.id=="err_1787022038113_c3VPTR")' specs/errors.json` shows
  `fix_status: "fixed"` with `fixed_date` and `fix_task` populated.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-common-lib.sh` exits 0.
- [ ] `bash .claude/scripts/tests/test-common-lib.sh` exits 0 after redeploy, with an offender set
      identical to the source-store run.
- [ ] Both runs print their detected mode and resolved root, and the two roots differ correctly
      (`agent-system/extensions` vs `.claude`).
- [ ] New fixture cases cover: deployed-mode `.md` positive detection, prose-exclusion negative,
      source-store `.md` positive detection, missing-subdirectory skip, and mode-probe correctness.
- [ ] Reintroduction acceptance test fails the gate and names the offending file.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` shows no regression in sibling
      suites.
- [ ] `bash -n` parses clean for every modified `.sh` file.
- [ ] `grep -rl 'sess_\$(date' agent-system/extensions/` returns only the canonical definition, the
      suite's self-referential comment, and the 12 intentional prose sites.
- [ ] `jq . specs/errors.json` succeeds.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` — dual-mode root resolution,
  `collect_session_id_offenders` helper, `.md`-scoped scan, new regression fixtures
- `agent-system/extensions/core/scripts/validate-state.sh` — migrated to `common_session_id()`
- `agent-system/extensions/core/scripts/lib/common.sh` — updated consumer list and documented
  `.md` replacement idiom
- 37 migrated `.md` files under `commands/` and `skills/` across core, founder, present,
  filetypes, cslib, literature, and epidemiology
- `specs/errors.json` — `err_1787022038113_c3VPTR` closed with evidence
- `specs/084_fix_duplication_gate_scope_and_extensions_root/summaries/01_*-summary.md` —
  implementation summary

## Rollback/Contingency

- Every phase is independently revertible by `git revert` of its own commits; phases are committed
  per green sub-step, so no partial state is ever committed.
- If the `.md` sourcing idiom proves unworkable in some shell context discovered during Phases 6-8,
  stop the affected migration, revert only that file, and record the site as a documented exception
  with an explicit gate exclusion — do not weaken the scan for the whole class.
- If the gate's `.md` scan proves too noisy in practice, the fallback is to keep Phases 1-2 (root
  resolution and the `.sh` migration, both strict improvements) and revert Phases 3-4, leaving the
  gate correct-but-narrow rather than incorrect-and-narrow.
- `errors.json` closure is the last edit and is trivially revertible by restoring `fix_status` to
  `"unfixed"` and removing `fixed_date`/`fix_task`.
- No `.claude/**` files are hand-edited at any point; a redeploy from `agent-system/extensions/**`
  always restores the deployed tree to match source.
