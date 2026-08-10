# Implementation Plan: Task #902

- **Task**: 902 - Flag tasks that modify orchestrator machinery and force them to run alone
- **Status**: [COMPLETED]
- **Effort**: 7 hours
- **Dependencies**: 901 (dry-run admission report surface — completed), 900 (cross-batch admission predicate — completed)
- **Research Inputs**: specs/902_self_modification_hazard_gate/reports/01_self-modification-hazard-gate.md
- **Artifacts**: plans/01_self-modification-hazard-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Extend `/orchestrate`'s admission analysis with a `self_modifying` dimension: a candidate whose
declared `file_scope` intersects a fixed, data-declared set of orchestrator-critical paths is
flagged, and — whenever the invocation carries more than one validated candidate — that candidate
(never its siblings) is deferred out of the invocation entirely, so orchestrator-machinery work
only ever runs solo. The critical set is declared once as a JSON data file consumed by
`orchestrate-batch-admit.sh` (live decision) and surfaced by `orchestrate-dry-run-report.sh` (human
visibility); the argument for each inclusion and each exclusion is recorded in
`batch-orchestration-guardrails.md`.

**SOURCE-STORE RULE (binding for every phase)**: every edit targets
`agent-system/extensions/core/**`. The `.claude/` tree is a gitignored, disposable deploy artifact
and is NEVER edited. Nothing in this plan becomes live until a human redeploys via the loader
(`<leader>al` / "Load Core"); all verification here therefore runs against scratch deploy trees.

### Research Integration

Three research findings shape this plan directly:

1. **The critical set is narrowed to nine files** by two conjunctive tests — *reachability* from
   MULTI-TASK batch dispatch (the only mode where siblings exist at all) and *decision-relevance*
   (a defect yields a silent wrong admission/wave/lock/completion decision, not a loud or cosmetic
   one). `command-gate-in.sh` and `command-gate-out.sh` are excluded on the skill's own explicit
   statement that MT dispatch never sources them; `orchestrator-postflight.sh` is excluded because
   it has zero references anywhere in `skill-orchestrate/SKILL.md`. This plan adopts the
   recommended set unchanged (see Decision D1 for the one refinement).
2. **The deferral trigger is the whole-invocation candidate count, not the wave/cycle subset.** A
   self-modifying task in Wave 0 and an unrelated task in Wave 1 are still "in the same pass". Both
   live call sites currently pass only a *subset* (`wave_tasks` / `eligible_tasks`) to
   `orchestrate-batch-admit.sh`, so the invocation size must be threaded in explicitly — this is
   Decision D3 and the single highest-risk correctness detail in the task.
3. **The self-modifying predicate is a pure single-candidate check** — the candidate's own
   `file_scope` against the critical-path list, using the *existing* overlap test from
   `file-footprint-overlap.md`, not a new algorithm.

The research's headline reversal (manual-only regeneration means a source-store edit cannot alter
the running session) does **not** cancel the gate; it redefines what the gate protects:
verification-gap risk (fixes verified only against scratch copies), rollback/commit-granularity
risk (a batch commit mixes N tasks' index rows), and the bootstrapping shape (the old deployed copy
of the admission script decides admission for the task rewriting it). That reframing is what
Phase 1 must record, because it is the only thing that lets a future reader judge a *new* candidate
file rather than pattern-match on names.

### Prior Plan Reference

No prior plan. The immediately preceding task in this batch landed the surfaces this task extends
(`orchestrate-triage-classify.sh`, `orchestrate-dry-run-report.sh`, the `--dry-run` flag) and
established the scratch-deploy-tree test pattern this plan reuses; its effort calibration
(one session, two test suites, 20 assertions) informs the phase sizing below.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no roadmap phases were requested; no
ROADMAP.md was consulted or modified.

## Goals & Non-Goals

**Goals**:
- Declare the orchestrator-critical path set exactly once, as data, with a documented rationale
  that states the *tests* (reachability, decision-relevance) and not merely today's conclusions.
- Add a `self_modifying` dimension to the admission verdict that is visible on every verdict, and
  a defer path that removes the self-modifying candidate from the whole invocation.
- Preserve defer-not-fail: never a failure, never a `blocked` mark, never a mutation of
  `specs/state.json` by the predicate.
- Make the flag visible in the `--dry-run` report with a plain-language reason.
- Exercise the gate by tests using the scratch-deploy-tree pattern, and keep the two existing
  suites green.

**Non-Goals**:
- Covering plain multi-task `/implement N,M` / `/research N,M` / `/plan N,M`. Those never call
  `orchestrate-batch-admit.sh`; this gate is `/orchestrate`-only and that residual risk is
  documented, not silently absorbed.
- Fixing the batch-commit staging gap (multi-task `/orchestrate` never stages an implementation
  agent's `modified_files`). Flagged by research for a follow-up task; out of file scope here.
- Blocking, failing, or auto-splitting anything. The gate defers exactly one candidate.
- Editing `.claude/**` or triggering a redeploy.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Existing consumers branch on `collision_scope` when `decision == "defer"`; a self-mod defer without that field falls into their `else` (in_batch) branch, meaning "retry next cycle" — and since the condition never clears, an infinite defer loop | H | H | Decision D2: bump the verdict to `orchestrate-batch-admit-v2` with a REQUIRED `defer_reason` discriminator on every defer, and update every consumer in the same task (Phases 3-4). Phase 5 asserts the new branch is terminal-for-the-invocation, not per-cycle |
| Invocation-size threading forgotten at one call site, so the gate under-fires for a Wave-0/Wave-1 pair | H | M | Decision D3 makes `--invocation-count` an explicit flag defaulting to the positional-arg count (safe, backward-compatible); Phase 4 updates both live call sites and Phase 5 has a dedicated wave-spanning assertion |
| Critical set too broad — nearly every meta task becomes solo-only, destroying batching for exactly the work that needs it | M | M | The two-test argument is recorded in guardrails.md with the excluded files named as prominently as the included ones; three named candidates are deliberately excluded, plus three reachable-but-not-decision-relevant files |
| Critical set too narrow — a genuinely hazardous file slips through | M | L | Rationale records the *tests*, so a new file is judged by re-deriving reachability + decision-relevance; guardrails.md states explicitly that the list is a conclusion of the tests, not a fixed enumeration |
| Missing/unparseable data file silently disables the gate | M | L | Degradation is visible, never silent: `self_modifying: null` on verdicts plus a loud stderr line, and a `SKIPPED (degraded: ...)` line in the dry-run report's existing "Checks run" section |
| Task 900's test suite pins whole verdict objects as exact strings including `$schema` | M | H (certain) | Phase 5 explicitly updates those expectations as part of the regression pass; this is anticipated work, not a surprise |
| A "self-modifying" flag reads as an accusation and a future maintainer relaxes it | L | L | guardrails.md states the three surviving hazards (verification gap, rollback granularity, bootstrapping) so the gate's purpose is not mistaken for the disproven live-corruption story |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Decisions Fixed Before Implementation

**D1 — Critical set contents and path expression.** Adopt the research's nine files unchanged:

| # | Path (relative to `agent-system/extensions/core/`) | Short label (used in report text) |
|---|---|---|
| 1 | `skills/skill-orchestrate/SKILL.md` | multi-task dispatch state machine |
| 2 | `skills/skill-orchestrate-hard/SKILL.md` | hard-mode dispatch contracts |
| 3 | `commands/orchestrate.md` | wave/admission/commit logic |
| 4 | `scripts/skill-base.sh` | preflight/postflight/completion-claim gate |
| 5 | `scripts/task-lock.sh` | concurrency lock |
| 6 | `scripts/update-task-status.sh` | status-transition gatekeeper |
| 7 | `scripts/orchestrate-batch-admit.sh` | admission predicate |
| 8 | `scripts/orchestrate-triage-classify.sh` | phase-routing classifier |
| 9 | `scripts/orchestrate-dry-run-report.sh` | admission report surface |

One refinement to the research's data-file shape: entries are stored relative to the core
extension root and **expanded at load time against a declared list of scope roots**
(`agent-system/extensions/core`, `.claude`, `.opencode`), so a `file_scope` naming either the
source-store path or a deploy-tree path matches the same single declaration. Rationale: a task
declaring `.claude/scripts/task-lock.sh` is a *more* alarming candidate, not a less alarming one,
and duplicating nine paths across three roots in the data file would defeat the "declared in ONE
place" constraint.

**D2 — Verdict schema bumps to `orchestrate-batch-admit-v2`.** Every verdict gains
`self_modifying` (`true` / `false` / `null` when the check degraded), and every `defer` verdict
gains a required `defer_reason` discriminator with exactly two values:
`"file_scope_collision"` and `"self_modifying"`. A version bump rather than optional-field
addition, because existing consumers' `defer` handling genuinely changes meaning: an unrecognized
defer must not fall through to their in-batch "retry next wave" branch.

**D3 — Invocation size is passed explicitly.** New optional flag
`--invocation-count <N>` on `orchestrate-batch-admit.sh`, defaulting to the number of positional
task arguments when absent (backward-compatible, and correct for any caller that already passes its
whole set). Callers that pass a subset (`wave_tasks`, `eligible_tasks`) MUST pass the invocation's
full validated-candidate count.

**D4 — Precedence and determinism.** The self-modifying check runs FIRST, before the collision
scan, and short-circuits it. Rationale: it is a pure single-candidate predicate whose consequence
is strictly larger (excluded from the whole invocation vs. deferred one wave), and first-match
determinism matches the existing "first hit wins, no exhaustive collection" convention.

**D5 — Degradation is visible, never silent.** A missing, unreadable, or unparseable critical-path
data file does not exit non-zero: verdicts carry `self_modifying: null`, one loud line goes to
stderr, and the dry-run report prints `self-modification: SKIPPED (degraded: ...)` in its existing
"Checks run" section. Rationale: the alternative (exit 2) would take down the whole admission pass
for a data-file typo, and silently returning `false` is precisely the "gate silently off" failure
this document's own non-negotiables warn against.

---

### Phase 1: Declare the Critical Set as Data and Record Its Rationale [COMPLETED]

**Goal**: The critical set exists in exactly one machine-readable place, and a future reader can
determine whether a newly added file belongs in it by re-deriving the tests rather than guessing.

**Tasks**:
- [x] Create `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
      with `$schema: "orchestrator-critical-paths-v1"`, a `scope_roots` array
      (`agent-system/extensions/core`, `.claude`, `.opencode`), and a `critical_paths` array of
      `{path, label}` objects holding exactly the nine entries in D1. Short `label` values only —
      the *rationale* is prose and lives in guardrails.md, never duplicated here. *(completed)*
- [x] Add a new "Self-Modification Hazard: The Fourth Admission Dimension" section to
      `context/patterns/batch-orchestration-guardrails.md` containing: (a) the two conjunctive
      tests stated as tests, not as their current answers; (b) the inclusion table with per-file
      reachability and decision-relevance evidence; (c) the exclusion table naming
      `command-gate-in.sh`, `command-gate-out.sh`, `orchestrator-postflight.sh` with the grep/citation
      evidence, plus the reachable-but-not-decision-relevant exclusions (`generate-todo.sh`,
      `validate-artifact.sh`, `lifecycle-notify.sh`); (d) the deploy-manual analysis and the three
      hazards that survive it (verification gap, rollback granularity, bootstrapping); (e) the
      explicit `/orchestrate`-only scope limitation and the uncommitted-`modified_files` residual
      risk; (f) a note that the reachability conclusion flips if MT dispatch is ever rerouted
      through the Skill tool. *(completed)*
- [x] Add a row to the guardrails Classification Table: self-modification hazard -> BLOCKING (both
      halves of the criterion hold: computable from on-disk `file_scope` alone; the harm — an
      unverifiable orchestrator fix bundled into a multi-task batch commit — is silent and hard to
      attribute later), and extend the "Three Existing Admission Layers" framing to name this as a
      distinct dimension layered on the batch-admission layer rather than a fourth scan scope.
      *(completed)*
- [x] Add the critical-path check to `context/patterns/file-footprint-overlap.md`'s Consumers
      section as a further application of the same predicate (candidate `file_scope` vs. a static
      declared list), explicitly noting it reuses the predicate and introduces no new matching rule.
      *(completed)*
- [x] Add a row for the new data file to `context/reference/README.md`'s Contents table. *(completed)*
- [x] Verify no task-number citations were introduced in any of these files (all are outside
      `specs/**`); cite durable anchors (document names, section headings) instead. *(completed:
      grep confirmed only pre-existing "task 809" citations in file-footprint-overlap.md, none
      introduced by this phase's edits)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` - new; the single declaration
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - new section + classification row
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` - consumers entry
- `agent-system/extensions/core/context/reference/README.md` - contents row

**Verification**:
- `jq -e '.critical_paths | length == 9' <data file>` succeeds and `jq -e '.scope_roots | length == 3'` succeeds.
- Every `critical_paths[].path` resolves to a real file under `agent-system/extensions/core/`.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no new failures
  (context files deploy via the `reference` directory entry, so no manifest change is expected —
  confirm this rather than assume it).
- guardrails.md names all three explicitly-excluded candidates and states the tests before the
  conclusions.

---

### Phase 2: Implement the Gate in orchestrate-batch-admit.sh [COMPLETED]

**Goal**: The admission predicate emits a `self_modifying` dimension on every verdict and defers
the self-modifying candidate — and only it — when the invocation carries more than one candidate.

**Tasks**:
- [x] Add `--invocation-count <N>` argument parsing ahead of the existing positional integer
      validation (preserve the existing usage-error behavior for zero args and non-integer task
      numbers; reject a non-integer `--invocation-count` the same way). Default to the positional
      argument count when absent. *(completed)*
- [x] Load `$SCRIPT_DIR/../context/reference/orchestrator-critical-paths.json` (this relative path
      resolves identically in the source store and in a deploy tree). On missing/unparseable file:
      set a degraded flag, print one loud stderr line, and continue. *(completed)*
- [x] Expand each `critical_paths[].path` against each `scope_roots[]` entry into a flat list of
      full repo-relative prefixes, carrying the entry's `label` alongside each expansion.
      *(completed)*
- [x] Inside the existing jq program, reuse `scopes_overlap_first` (unchanged) to test the
      candidate's own `file_scope` against the expanded critical list; capture the first matching
      path and its label. *(completed: implemented as a sibling def `self_mod_match`, same
      predicate rules, deliberately using `first` not `first // empty` — see the fix note below)*
- [x] Emit `self_modifying` on EVERY verdict — `true`, `false`, or `null` when degraded — including
      `admit` verdicts, so a solo self-modifying run is still visible. *(completed)*
- [x] When `self_modifying` is true AND the invocation count is > 1: emit
      `decision: "defer"`, `defer_reason: "self_modifying"`, `critical_path` (the matched
      declared path), `critical_label`, and a plain-language `reason` naming the file, the label,
      and the solo-only rule. Skip the collision scan entirely (D4). *(completed)*
- [x] When `self_modifying` is true and the invocation count is 1: `admit` (solo is the desired
      outcome), with `self_modifying: true` still present. *(completed)*
- [x] Add `defer_reason: "file_scope_collision"` to the existing collision defer verdict and bump
      the `$schema` literal to `orchestrate-batch-admit-v2` on all verdicts. *(completed)*
- [x] Update the script's header comment block: new flag, new fields, the two `defer_reason`
      values, the precedence rule (D4), the degradation rule (D5), and a by-path reference to
      the data file and to guardrails.md for the rationale (never restating either). *(completed)*

**Deviation (bug found and fixed during manual verification, not in the original task list)**:
the first implementation of `self_mod_match` copied `scopes_overlap_first`'s `first // empty`
tail verbatim. That is correct for `scopes_overlap_first` (used inside an array comprehension,
where `empty` means "this iteration contributes nothing to the array"), but `self_mod_match`'s
result is bound via `as $sm_hit |` OUTSIDE any array comprehension — an `empty` result there
made jq's `as` binding iterate zero times, silently dropping the ENTIRE verdict for any
non-self-modifying candidate from stdout (verified: a plain ordinary candidate produced no
output at all, exit 0). Fixed by changing the tail to plain `first` (which returns `null`, not
`empty`, for an empty match array), restoring one verdict line per candidate. Also fixed two
apostrophes accidentally introduced into comments/strings inside the single-quoted bash-to-jq
program (`bash -n` caught both as syntax errors). All fixes verified via a scratch-deploy-tree
manual run before Phase 2 was marked complete.

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - gate implementation + header contract

**Verification**:
- `bash -n` clean.
- Manual scratch-tree run: a candidate whose `file_scope` names a critical path, passed with
  `--invocation-count 2`, yields `decision=defer` and `defer_reason=self_modifying`; the same
  candidate with `--invocation-count 1` yields `decision=admit` with `self_modifying=true`.
- A non-critical candidate yields `self_modifying=false` and behavior byte-identical to the
  current script apart from the `$schema` and `defer_reason`/`self_modifying` fields.
- Renaming the data file aside reproduces `self_modifying: null` plus the stderr warning, and
  exit code 0.

---

### Phase 3: Surface the Flag in the Dry-Run Report [COMPLETED]

**Goal**: `/orchestrate --dry-run` shows the self-modifying flag with a plain-language reason, and
the report cannot drift from the live decision because it composes the same predicate.

**Tasks**:
- [x] Pass `--invocation-count "${#validated_tasks[@]}"` on the existing single
      `orchestrate-batch-admit.sh` call in Step 4 of the report composer. *(completed)*
- [x] Branch on `defer_reason`: `self_modifying` becomes an **exclusion** with a plain-language
      reason naming the matched critical path, its label, and the solo-only rule (explicitly
      "deferred out of this invocation — re-run it alone", so a reader does not mistake it for a
      wave deferral); `file_scope_collision` retains today's exact in_batch/cross_batch behavior.
      *(completed)*
- [x] When a candidate is admitted with `self_modifying: true` (solo invocation), add a Note line
      stating it is orchestrator-critical and admitted only because this invocation carries one
      candidate. *(completed)*
- [x] Add a `self-modification: ran | SKIPPED (degraded: ...)` line to the "Checks run" section,
      driven by `self_modifying == null` on any verdict (D5), keeping the section's existing
      one-line-per-check shape. *(completed: fixed a `// "null"` jq pitfall found during manual
      verification — see deviation note below)*
- [x] Update the script header's Composition list (step 4) to name the new dimension and the
      exclusion semantics; do not restate the schema (reference the schema doc by path).
      *(completed)*

**Deviation (bug found and fixed during manual verification, not in the original task list)**:
the first implementation read `self_mod=$(echo "$verdict" | jq -r '.self_modifying // "null"')`.
jq's `//` operator treats a literal `false` as falsy, so a valid, non-degraded
`self_modifying: false` verdict was misread as the degraded "null" case, making the
"self-modification" Checks-run line print `SKIPPED (degraded: ...)` on every ordinary
(non-self-modifying) run even though the check had actually run correctly. Fixed by switching to
`jq -c '.self_modifying'` (compact, no `//` fallback), which passes through the literal
`true`/`false`/`null` token unchanged. Verified via a scratch-deploy-tree manual run confirming
`self-modification: ran` for an ordinary candidate and `SKIPPED (degraded: ...)` only when the
critical-paths data file is actually absent.

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` - invocation count, exclusion branch, note, checks-run line, header

**Verification**:
- `bash -n` clean.
- Scratch-tree run over a fixture batch containing one self-modifying candidate and one ordinary
  candidate: the report's Excluded section names the self-modifying task with the plain-language
  reason and the ordinary task is admitted.
- The same fixture with only the self-modifying candidate: admitted, with the solo Note present
  and nothing in Excluded.
- All six report sections still print unconditionally, in order.

---

### Phase 4: Wire the Live Dispatch Paths and the Schema Document [COMPLETED]

**Goal**: Both live call sites honor the new defer reason with invocation-scoped (not wave-scoped)
exclusion, and the published verdict schema matches the implementation.

**Tasks**:
- [x] `commands/orchestrate.md` MULTI-TASK DISPATCH Step 3: pass
      `--invocation-count "${#validated_tasks[@]}"` on the `orchestrate-batch-admit.sh` call, and
      add a third branch for `defer_reason == "self_modifying"` that excludes the candidate from
      the invocation (not the wave) with a distinct warning naming the matched critical path and
      instructing a solo re-run. Keep the existing two collision warnings byte-identical.
      *(completed)*
- [x] `commands/orchestrate.md`: state in the same section that the deferral is evaluated against
      the invocation's validated-candidate count, never the wave's size, and that the excluded task
      is neither failed nor marked blocked. *(completed)*
- [x] `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5: same `--invocation-count` argument
      (using the invocation's full `task_numbers` count, NOT `eligible_tasks`), same third branch —
      and, critically, record the deferred task in an invocation-scoped
      `deferred_self_modifying` set that Stage MT-3 step 3 excludes from eligibility for the
      REMAINDER of the invocation. Without this the task re-enters every subsequent cycle and the
      loop never converges. *(completed: also updated MT-1 to initialize the set and MT-3 step 2
      All-terminal check plus step 4 circuit-breaker framing to recognize deferred_self_modifying
      as an intentional exclusion rather than a "stuck" task — see deviation note below)*
- [x] `skills/skill-orchestrate/SKILL.md` Stage MT-5: report `deferred_self_modifying` tasks in the
      multi-task postflight summary as deferred-for-solo-run — distinct from `failed_tasks`, never
      added to it, and never status-mutated. *(completed: also adjusted the exit_status
      determination so a non-empty deferred_self_modifying set with zero failed_tasks yields
      "partial", never "completed" — see deviation note below)*
- [x] Verify by grep whether `skills/skill-orchestrate-hard/SKILL.md` restates the wave-split
      branch; it currently inherits MT-1..MT-5 by reference and contains no
      `orchestrate-batch-admit` reference, so the expected outcome is **no edit** — record the
      grep result rather than editing speculatively. *(completed: `grep -c "orchestrate-batch-admit"
      skills/skill-orchestrate-hard/SKILL.md` = 0. No edit made, confirming the predicted outcome.)*
- [x] `docs/architecture/batch-admit-schema.md`: bump to `orchestrate-batch-admit-v2`, document
      `self_modifying` (with its three-valued semantics), `defer_reason` and its two values,
      `critical_path`, `critical_label`, the `--invocation-count` flag, the precedence rule, and
      the degradation behavior. Add the data file to See Also by path. *(completed: full rewrite,
      including a Version History section explaining why v2 was a version bump, not an additive
      field)*
- [x] Confirm no task-number citations were added to any of these files. *(completed: grep clean)*

**Deviations (necessary correctness additions beyond the literal task list, both required for
the convergence property the plan itself demands — not scope creep)**:
1. **Stage MT-3 step 2 (All-terminal check) and step 4 (no-eligible circuit breaker)**: updated
   to recognize `deferred_self_modifying` membership as equivalent to terminal/failed for the
   purpose of deciding whether the cycling loop has anything left to do. Without this, a deferred
   self-modifying task with no other remaining siblings would fall through to the "stuck tasks"
   circuit-breaker warning every cycle, misdescribing a deliberate, by-design exclusion as an
   unexpected stall.
2. **Stage MT-5 exit_status determination**: changed from `failed_count == 0 -> "completed"` to
   `failed_count == 0 AND deferred_self_modifying is empty -> "completed"`. Without this, an
   invocation that successfully excluded a self-modifying task (zero `failed_tasks`) would
   report `"completed"` even though one task was never actually dispatched — silently
   misrepresenting an intentionally incomplete invocation as fully finished, which is precisely
   the class of silent-wrong-decision this whole gate exists to prevent elsewhere.

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - Step 3 branch + invocation-count semantics
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - MT-3 step 4.5 branch, invocation-scoped exclusion set, MT-5 reporting
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - v2 schema

**Verification**:
- Every `orchestrate-batch-admit.sh` invocation in the source store passes `--invocation-count`
  (grep for the script name and inspect each hit).
- The schema document's field table matches the script's emitted keys exactly (compare against a
  live scratch-tree verdict, both an admit and each defer flavor).
- `grep -c "orchestrate-batch-admit" skills/skill-orchestrate-hard/SKILL.md` is recorded in the
  summary as evidence for the no-edit decision.

---

### Phase 5: Tests and Regression [COMPLETED]

**Goal**: The gate is exercised by deterministic fixture tests, and the two existing suites stay
green against the v2 verdict.

**Tasks**:
- [x] Create `specs/902_self_modification_hazard_gate/fixtures/state-self-mod.json` covering: a
      candidate whose `file_scope` names a source-store critical path; one naming a deploy-tree
      (`.claude/...`) path for the same declared entry; one naming a directory that is a prefix
      ancestor of a critical path; one naming an *excluded* file (`command-gate-in.sh`) that must
      NOT be flagged; an ordinary non-critical candidate; and a self-modifying candidate placed in
      a different wave from an unrelated sibling (via `dependencies[]`) for the wave-spanning
      assertion. *(completed: 950-960, 11 entries — see deviation note below for the 3 additional
      entries beyond the plan's literal list)*
- [x] Create `specs/902_self_modification_hazard_gate/tests/test-self-modifying-gate.sh` using the
      scratch-deploy-tree pattern (`mktemp -d`, copy the scripts plus `deploy-root-guard.sh`, copy
      the critical-paths data file into `.claude/context/reference/`, seed `specs/state.json` from
      the fixture, `trap cleanup EXIT`). Assertions: defer with `defer_reason=self_modifying` at
      invocation count > 1; admit with `self_modifying=true` at count 1; deploy-tree path matches;
      directory-prefix ancestor matches; excluded file does NOT match; ordinary candidate carries
      `self_modifying=false`; only the self-modifying candidate is deferred (siblings unaffected);
      self-mod precedence over a simultaneous collision (D4); `self_modifying: null` plus exit 0
      when the data file is absent. *(completed: 14 assertions, all passing)*
- [x] Add a dry-run report assertion (either in the same suite or as a second scratch tree)
      confirming the plain-language exclusion line and the solo Note. *(completed: assertions
      12a/12b)*
- [x] Add a wave-spanning assertion: a self-modifying task and an unrelated task in different waves
      still trigger the gate, proving the trigger is invocation-scoped, not wave-scoped.
      *(completed: assertion 10, contrasting `--invocation-count 2` (correctly defers) against
      the naive omitted-flag call (incorrectly admits) to make the invocation-scoping property
      observable)*
- [x] Run `specs/900_cross_batch_file_scope_admission/tests/test-batch-admit.sh` and update its
      exact-string expectations for the v2 `$schema` and the new `self_modifying` /
      `defer_reason` fields (these are pinned whole-object comparisons and will fail otherwise).
      *(completed: see the substantial deviation note below — this fixture's real candidates
      900/902/906/907 are themselves genuinely self-modifying, which changes what tests 1 and 2
      actually demonstrate, not merely their string literals)*
- [x] Run both predecessor suites (`test-triage-classify.sh`, `test-dry-run-report.sh`) and update
      any assertions the new report lines disturb. *(completed: both suites pass unchanged, 6/6
      and 14/14 — neither suite's assertions pin the new self-modification "Checks run" line or
      the new verdict fields closely enough to be disturbed)*
- [x] Confirm the real repository `.claude/` tree and `specs/state.json` are untouched by the test
      run. *(completed: `git status --short .claude/` empty; the `specs/state.json` diff present
      in the working tree predates this session entirely — unrelated task-completion backfills,
      confirmed via `git diff` inspection, not written by any test run here)*

**Deviations (both substantial, both fully documented inline in the affected test files rather
than silently worked around)**:

1. **Fixture `state-self-mod.json` grew from the plan's ~6 implied entries to 11** (950-960).
   Three entries beyond the literal list were added, and one existing plan-implied entry
   (`954`, "ordinary candidate") was split into two (`954`+`959` for in-batch-direction pairing,
   `960` newly added as the truly isolated ordinary candidate) after discovering that giving 959
   the SAME `file_scope` as 954 for the in-batch-direction test (item 3 below) made 954
   incidentally collide with 959 across every OTHER assertion that used 954 in isolation —
   because `orchestrate-batch-admit.sh` always compares a candidate against every non-terminal
   task in the WHOLE state file, not just the CLI arguments passed. Splitting the "ordinary,
   fully isolated" role (960) from the "in-batch-direction pairing" role (954+959) fixed this
   without weakening either assertion. Entries `957`/`958` were added to test D4 precedence
   (a candidate that is BOTH self-modifying AND would otherwise collide on a separate,
   non-critical shared file) — required by the task prompt's explicit hazard flag and not
   achievable with the other fixture entries without conflating concerns.
2. **`test-batch-admit.sh` tests 1 and 2 changed IN MEANING, not just in string literals.**
   Discovered by actually running the v2 script against the frozen fixture (not by predicting):
   tasks 900, 902, 906, and 907 are real orchestrator-lifecycle tasks whose `file_scope`
   legitimately names orchestrator-critical files, so they are now genuinely `self_modifying:
   true`. Per D4 (self-modification precedence, checked first, short-circuiting the collision
   scan entirely), this means: candidate 900 alone now ADMITS solo (not the previously-asserted
   cross-batch defer); candidates 900+902 together now BOTH defer via `self_modifying` (not the
   previously-asserted in-batch-direction collision). This is the new, correct, intended
   behavior — not a bug — but it retires this suite's incidental coverage of the plain
   in-batch-direction rule (lower `project_number` wins) for a pair with NO self-modification
   involved. That coverage is restored via a NEW assertion (test 13) in
   `specs/902_self_modification_hazard_gate/tests/test-self-modifying-gate.sh`, using two
   synthetic, deliberately non-critical candidates (954, 959) so the underlying, UNCHANGED
   direction-rule code stays under test independent of the new gate. The live smoke check at the
   bottom of `test-batch-admit.sh` was also softened from a pinned decision/`collision_scope`
   assertion to a schema/shape-only assertion, because the specific real task (900) it pinned
   has independently reached `completed` status since the suite was first written (unrelated
   timing drift, not caused by this gate) — re-pinning a new specific value would only defer the
   same fragility to the next time a referenced live task completes.

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Files to modify**:
- `specs/902_self_modification_hazard_gate/fixtures/state-self-mod.json` - new fixture
- `specs/902_self_modification_hazard_gate/tests/test-self-modifying-gate.sh` - new suite
- `specs/900_cross_batch_file_scope_admission/tests/test-batch-admit.sh` - v2 expectation updates
- `specs/901_orchestrate_dry_run_admission_report/tests/test-dry-run-report.sh` - updates if disturbed

**Verification**:
- New suite passes 100%; both predecessor suites pass 100%.
- `git status --short` shows no modification to `.claude/**` or to the repository's live
  `specs/state.json`.

---

## Testing & Validation

- [x] `bash -n` clean on both modified scripts. *(verified: orchestrate-batch-admit.sh,
      orchestrate-dry-run-report.sh)*
- [x] The nine declared paths all exist; the data file parses and matches its declared `$schema`.
      *(verified in Phase 1)*
- [x] Self-modifying candidate + sibling: candidate deferred, sibling admitted and dispatched.
      *(verified: test-self-modifying-gate.sh assertion 7, test-dry-run-report assertion 12a)*
- [x] Self-modifying candidate alone: admitted, flagged, solo Note present. *(verified: assertions
      2, 12b)*
- [x] Different-wave sibling still triggers the gate (invocation-scoped trigger). *(verified:
      assertion 10)*
- [x] An excluded candidate file (`command-gate-in.sh`) is not flagged. *(verified: assertion 5)*
- [x] Absent data file degrades visibly (`self_modifying: null`, stderr line, exit 0, report
      "SKIPPED (degraded: ...)"). *(verified: assertion 9, and a direct dry-run-report degraded
      run in Phase 3)*
- [x] Existing collision behavior unchanged apart from the two additive fields and the `$schema`.
      *(verified TRUE for non-self-modifying candidates — e.g. fixture 991/992/993/991 in
      test-batch-admit.sh, all fixture 950-960 collision-only paths in the new suite. NOT true,
      by design, for a candidate that is ALSO self-modifying: D4 precedence means such a
      candidate's collision fields are never computed at all, which is the new, correct behavior
      — see the substantial Phase 5 deviation note for why this affected test-batch-admit.sh's
      real-data tests 1 and 2.)*
- [x] No task-number citations introduced outside `specs/**`; no edits under `.claude/**`. *(both
      verified throughout via grep after every phase; confirmed again at the end of Phase 5)*

## Artifacts & Outputs

- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` (new)
- Updated `orchestrate-batch-admit.sh`, `orchestrate-dry-run-report.sh`
- Updated `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`
- Updated `context/patterns/batch-orchestration-guardrails.md`,
  `context/patterns/file-footprint-overlap.md`, `context/reference/README.md`
- Updated `docs/architecture/batch-admit-schema.md`
- New fixture + test suite under `specs/902_self_modification_hazard_gate/`
- `specs/902_self_modification_hazard_gate/summaries/01_*-summary.md`

## Rollback/Contingency

The gate is additive and lives behind one data file. Three graduated rollback levers, in
increasing order of severity:

1. **Narrow the set**: remove entries from `orchestrator-critical-paths.json`. No code change; the
   predicate degrades toward never firing as the array empties.
2. **Disable the gate entirely**: delete or rename the data file. Per D5 this is a *visible*
   degradation (`self_modifying: null` plus a loud stderr line and a report `SKIPPED` line), not a
   silent one — chosen deliberately so an accidental deletion cannot masquerade as "no candidates
   are self-modifying".
3. **Full revert**: revert the phase commits. The `$schema` bump to v2 is the only non-additive
   change, and its consumers are all edited within this task, so a revert restores a consistent v1
   world with no partial-upgrade state.

Because nothing here is live until a human redeploys the core extension from the source store, a
defect found after implementation but before redeploy costs a revert only — no running session is
affected. That property is itself part of the rationale recorded in Phase 1.
