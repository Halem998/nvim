# Implementation Plan: Task #6

- **Task**: 6 - guard_against_nonadditive_artifact_rewrites
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None (task 5 is adjacent but shares no code surface)
- **Research Inputs**: `specs/006_guard_against_nonadditive_artifact_rewrites/reports/01_guard-nonadditive-artifact-rewrites.md`
- **Artifacts**: plans/01_guard-nonadditive-artifact-rewrites.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`specs/state.json`'s `.artifacts` array is append-only by intent but unenforced: an agent
composing its own `jq` assignment can replace the array wholesale and silently destroy artifact
links (observed: 11 entries -> 8, five phase summaries dropped). This plan adds a
writer-agnostic, content-inspecting invariant as a new FAIL-level `--deep` check in
`validate-state.sh` — per `project_number` and per artifact `type`, the number of paths removed
relative to the prior git-committed state must not exceed the number added — plus a named CLI
opt-in for genuine deletions, an explicit append-only rule in `rules/state-management.md`, an
explanatory comment at the `skill_link_artifacts` choke point, and a `MUST NOT` bullet on the
implementation agent. Done when a fixture write that drops artifacts is rejected, the same write
with the opt-in flag is accepted, and every existing sanctioned link path still passes unchanged.

### Research Integration

The research report materially narrowed the design space and its conclusions are adopted whole:

- **The four sanctioned writers are NOT literally append-only.** `skill_link_artifacts`
  (`skill-base.sh`), `orchestrator-postflight.sh` Stage 8, `link_artifact`
  (`reconcile-task-status.sh`), and `skill-reviser/SKILL.md` Stage 8 all run a documented two-step
  *remove-all-of-same-type, then add one* idiom — the reference pattern taught in
  `context/patterns/inline-status-update.md`. A naive global path-superset invariant would break
  every routine report/plan/summary re-link, directly violating the verification bar's "existing
  call sites are unaffected."
- **Therefore the invariant is per-type counts, not per-path presence**: for each `type` T,
  `removed(T) <= added(T)`. This is a no-op for a first link (0 removed, 1 added), permits the
  routine 1-for-1 supersession (1 removed, 1 added), and rejects the observed incident's shape
  (5 removed, 2 added).
- **The check lives in `validate-state.sh --deep`, not `state-write.sh`.** Content inspection is
  writer-agnostic by construction, so it fires identically on `state-write.sh` traffic and on a
  hand-composed `jq ... > tmp && mv` — which is the exact observed failure mode. `state-write.sh`
  is additionally outside this task's declared file scope.
- **Existing `--deep` Check D4 (terminal-status immutability) is the reusable mechanism**: it
  already resolves the state file's git history and reads the prior committed JSON into
  `prior_json`. The new check reuses that same variable rather than issuing a second `git show`.
- **The opt-in is a CLI flag on the validator**, not a schema field, because the validator and the
  writer are architecturally decoupled (periodic, not synchronous) and the schema file is out of
  scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:

- Add a machine-checkable, FAIL-level invariant that detects net artifact-link loss in
  `specs/state.json` regardless of which writer produced the file.
- Keep legitimate deletion expressible via an explicit, named opt-in
  (`--allow-artifact-removal`).
- Leave all four sanctioned writers and their call sites functionally untouched.
- State the append-only contract explicitly in `rules/state-management.md`, which today documents
  artifact link *formats* without ever stating the list is append-only.
- Add a preventive `MUST NOT` to `general-implementation-agent.md` against wholesale
  `.artifacts = [...]` assignment.
- Execute both directions of the fixture test (drop rejected; drop-with-flag accepted), and prove
  the check triggers on a directly `jq`-composed write.

**Non-Goals**:

- Converting any writer to `state-write.sh` (that is the adjacent state-write conversion work; its
  `mv`-grep bar cannot catch this defect and is not this deliverable).
- Modifying `state-write.sh`, `context/schemas/state-schema.json`, or any of the four sanctioned
  call sites.
- Adding a synchronous (write-time / PreToolUse hook) enforcement path. The trade-off of periodic
  enforcement is named explicitly under Risks and is accepted for this task.
- Detecting adversarial 1-for-1 substitution (removing one artifact while adding an unrelated one
  of the same type). This is a known, bounded blind spot of the count-based rule.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| FAIL-level check surfaces pre-existing, already-committed artifact drift and blocks `verify-deploy.sh` gate 10 | H | M | Phase 1 measures the live state empirically *before* any code lands, and applies a pre-declared decision rule: clean -> land FAIL-level; drift found -> repair it in the same phase, or (if repair is not safe) land WARN-level with a recorded promotion criterion, mirroring the advisory-first precedent already used for verification-tier enforcement in `validate-artifact.sh` |
| Enforcement is periodic (only via `verify-deploy.sh` gate 10), so a lossy direct-`jq` write followed by another committed write moves the `prior_json` baseline forward and hides the loss | M | M | Accept and name explicitly in both the plan and the new rules subsection; the check still catches the dominant case (loss present at next validation). A synchronous variant would require expanding file scope and is deliberately deferred |
| `--help` output breaks: `validate-state.sh`'s `--help` is a hardcoded `sed -n '2,57p' "$0"` range over its own header comment, so adding header lines silently truncates or over-runs help text | M | H | Phase 2 treats the `sed` range bump as a required, separately-verified sub-step, confirmed by diffing `--help` output against the actual header block |
| The test suite prefers the *deployed* validator (`$REPO_ROOT/.claude/scripts/validate-state.sh`) over the source-store copy, so new tests could silently exercise stale code and appear to pass | H | H | Phase 3 and Phase 5 both require invoking the source-store copy explicitly (or deploying first) and asserting the new check's identifier actually appears in the validator being run |
| Per-type counting mis-handles entries with absent/null `.type`, silently excluding them from the invariant | M | M | Group untyped entries under an explicit sentinel key so they are counted, not dropped; assert this with a dedicated fixture |
| A project present in `prior_json` but absent from the live file (archival) is misread as total artifact loss | M | M | Skip project numbers absent from the live `active_projects`; archival is already covered by other checks. Assert with a fixture |
| Doc/agent edits accidentally introduce task-number citations into deliverables outside `specs/**` | M | M | All four edited files live outside `specs/**`; Phase 4 verification runs `check-task-references.sh` |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Baseline Drift Triage and Enforcement-Level Decision [COMPLETED]

**Goal**: Determine empirically whether the live `specs/state.json` already contains net per-type
artifact loss relative to its prior committed version, and record the resulting binding decision
on whether the new check lands FAIL-level or WARN-level. This must happen before any code is
written, because it is the single input that decides the check's severity.

**Tasks**:

- [x] Run the current validator as a control and record the result:
      `bash .claude/scripts/validate-state.sh --deep specs/state.json` (capture exit code and the
      PASS/WARN/FAIL summary counts). *(completed: exit 1, 13 PASS / 0 WARN / 1 FAIL — the sole
      FAIL is a pre-existing, unrelated D3 dangling-dependency finding on project 9 -> 1015, not
      an artifact-loss issue)*
- [x] Write a throwaway probe (not committed) that reproduces the intended D5 arithmetic against
      the live file: read the prior committed `specs/state.json` via
      `git show "$(git log -1 --format=%H -- specs/state.json)":./specs/state.json`, and for every
      `project_number` present in BOTH the prior and live `active_projects`, compute per-`type`
      `removed = |prior_paths(T) \ cur_paths(T)|` and `added = |cur_paths(T) \ prior_paths(T)|`.
      *(completed)*
- [x] Record every `(project_number, type)` pair where `removed > added`, with the concrete
      dropped paths. *(completed: 0 violating pairs across 14 (project_number, type) pairs
      checked)*
- [x] Apply the decision rule and record the outcome in the implementation summary:
      - Zero violating pairs -> the check lands **FAIL-level** (the researched recommendation).
      - Violating pairs found AND every dropped path still exists on disk -> re-link the dropped
        artifacts (append-only, via `state-write.sh` or an additive `jq` `+=`), re-run the probe to
        confirm zero violations, then land **FAIL-level**.
      - Violating pairs found that cannot be safely repaired -> land **WARN-level** and record an
        explicit promotion criterion ("promote to FAIL once `specs/state.json` shows zero violating
        pairs") in both the script's header comment and the new rules subsection.
      *(completed: zero violating pairs -> FAIL-level is the recorded, binding decision carried
      into Phase 2)*
- [x] Do NOT edit `validate-state.sh` in this phase. The only permitted mutation is an artifact
      re-link repair under the second branch above. *(completed: no repair needed, no code
      edited)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts that the live `specs/state.json` has **zero** violating
`(project_number, type)` pairs and that FAIL-level is therefore safe. This is a hypothesis, not a
fact — confirm it by running the probe above and reporting the actual violating-pair count
(including zero) as an explicit number in the phase's completion note. If the count is nonzero,
the plan's downstream phases are unchanged except that "FAIL-level" is replaced by the branch
outcome recorded here, and that substitution must be stated in the summary.

**Files to modify**:

- None (read-only probe). Exception: `specs/state.json` may receive an additive re-link repair
  under the second decision branch, which is a `specs/**` write and thus outside the source-store
  rule's scope.

**Verification**:

- The probe's violating-pair count is reported as an explicit integer (zero is a valid, reportable
  result), not as a prose claim that "nothing was found."
- If a repair was made, a re-run of the probe reports zero violating pairs and
  `git diff specs/state.json` shows only additions to `.artifacts` arrays, no removals.
- The chosen enforcement level (FAIL or WARN) is stated verbatim and carried into Phase 2.

---

### Phase 2: Implement the D5 Artifact-Loss Check and `--allow-artifact-removal` Flag [NOT STARTED]

**Goal**: Add the per-type artifact-loss invariant as a new `--deep` check in
`validate-state.sh`, reusing D4's already-fetched `prior_json`, together with a repeatable CLI
opt-in flag that makes genuine deletion expressible.

**Tasks**:

- [ ] Add flag parsing for `--allow-artifact-removal <project_number>[:<type>]` to the existing
      `while [[ $# -gt 0 ]]` argument loop. The flag is **repeatable**; accumulate values into an
      array. Semantics:
      - `--allow-artifact-removal 6` — permits net removal of any type for project 6.
      - `--allow-artifact-removal 6:summary` — permits net removal only of `summary` artifacts for
        project 6.
      - A malformed value (non-integer project number, empty type after `:`) is a hard error exit
        2, consistent with the script's existing environment-error convention — never a silent
        ignore.
- [ ] Implement the check inside the existing `--deep` D4 git block, **after** the D4 loop and
      reusing the same `prior_json` variable (do not issue a second `git show`). Guard it so it
      runs only when `prior_json` is non-empty; when D4 skipped for lack of git history or a
      prior commit, emit the same style of skip warning naming this check.
- [ ] Compute, for each `project_number` present in BOTH `prior_json` and the live file: per-`type`
      path sets, then `removed(T)` and `added(T)` as set differences (counts of distinct paths, not
      raw array lengths).
      - Entries whose `.type` is absent or null group under an explicit sentinel key
        (e.g. `(untyped)`) so they participate in the invariant rather than being dropped.
      - Project numbers present in `prior_json` but absent from the live `active_projects` are
        skipped (archival is covered elsewhere); note this in a comment.
- [ ] Emit a `log_fail` (or `log_warn`, per Phase 1's recorded decision) for every
      `(project_number, type)` pair where `removed(T) > added(T)`, naming the project number, the
      type, both counts, and the concrete dropped path(s) — the message must be actionable enough
      to repair by hand.
- [ ] Suppress the finding for any pair matched by an `--allow-artifact-removal` entry, and when
      suppressed emit an explicit informational line recording that the removal was allowed by
      operator opt-in. A silent suppression would defeat the audit purpose.
- [ ] Emit a single `log_pass` when the check ran and found zero unsuppressed violations, matching
      D4's existing pass-line style.
- [ ] Update the script's header comment block: extend the `--deep mode additionally checks:`
      list with the new check, and document the new flag under `Usage:`.
- [ ] **Bump the `--help` line range.** `--help` is implemented as `sed -n '2,57p' "$0"`; adding
      header lines makes this range stale. Recompute the correct end line and update it.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the change is confined to one file
(`agent-system/extensions/core/scripts/validate-state.sh`) and that its only external consumers
are `verify-deploy.sh` gate 10 and `scripts/tests/test-validate-state.sh`. Confirm at
implementation time with `grep -rln "validate-state.sh" agent-system/extensions/` and reconcile
the result against that two-consumer claim before closing the phase; report the actual consumer
list.

**Files to modify**:

- `agent-system/extensions/core/scripts/validate-state.sh` - new `--allow-artifact-removal` flag
  parsing, new per-type artifact-loss check inside the `--deep` git block, header comment and
  `--help` range updates.

**Verification**:

- `bash -n agent-system/extensions/core/scripts/validate-state.sh` passes.
- `bash agent-system/extensions/core/scripts/validate-state.sh --help` prints the complete header
  block with no truncation and no leakage of code past the comment block — verified by comparing
  the last line of `--help` output against the last line of the header comment.
- `bash agent-system/extensions/core/scripts/validate-state.sh --deep specs/state.json` reports
  the new check's pass line and exits consistently with Phase 1's recorded baseline.
- `--allow-artifact-removal notanumber` exits 2 with a named error, not silently.
- Both enumerated consumers still invoke the script successfully with their existing argument
  forms (no positional-argument regression).

---

### Phase 3: Bidirectional Fixture Tests [NOT STARTED]

**Goal**: Extend `test-validate-state.sh` with fixtures that execute **both directions** of the
verification bar and prove the check fires on a directly `jq`-composed write, not only on
`state-write.sh` traffic.

**Tasks**:

- [ ] Build a fixture helper that creates a temporary git repository containing a `specs/`
      directory, commits a baseline `state.json` with a known multi-type `.artifacts` array, then
      mutates the working-tree copy. This is required because the check reads the *prior committed*
      version — a non-git fixture cannot exercise it.
- [ ] **Negative fixture (rejection)**: mutate the working copy using a literal, hand-composed
      `jq '... .artifacts = [...]' > tmp && mv tmp state.json` sequence that drops more paths of one
      type than it adds (mirroring the observed 5-dropped/2-added shape). Assert the validator
      reports the new check's FAIL line naming the project number and type, and exits nonzero.
      Using a raw `jq` assignment here — rather than a helper call — is what satisfies the
      "triggers on a direct jq-composed write" bar; do not substitute a helper invocation.
- [ ] **Positive fixture (opt-in accepted)**: re-run the *identical* mutated fixture with
      `--allow-artifact-removal <project_number>` and assert exit 0 with the suppression/opt-in
      line present. Both directions must run against the same mutation so the flag is the only
      variable.
- [ ] **Regression fixture (sanctioned supersession)**: a 1-for-1 same-type replacement
      (one `report` path removed, one added) asserted to PASS with no finding — the guard that
      existing `link_artifact` / `skill_link_artifacts` call sites remain unaffected.
- [ ] **Pure-append fixture**: adding one artifact with nothing removed, asserted PASS.
- [ ] **Untyped-entry fixture**: dropping two entries with absent `.type` while adding none,
      asserted FAIL under the sentinel grouping.
- [ ] **Scoped-flag fixture**: a `summary`-type loss with `--allow-artifact-removal <n>:report`
      asserted to still FAIL (proving the type-scoped form does not over-permit).
- [ ] Follow the suite's existing structural idiom exactly: `pass()`/`fail()`/`info()` helpers,
      `PASSED`/`FAILED` counters, exit 0 on all-pass.
- [ ] Resolve the validator under test explicitly. The suite's existing `VALIDATOR_CANDIDATES`
      prefers the deployed copy; the new cases must assert they are running a validator that
      actually contains the new check (e.g. grep the resolved `$VALIDATOR` for the check's
      identifier and `info()`-skip with a loud message if absent) so a stale deployed copy cannot
      produce a false green.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts seven new fixture cases in one file. Confirm at
implementation time by reporting the actual delta in the suite's `PASSED` total before and after,
and reconcile it against seven; if the real count differs, report the real number rather than
restating this estimate.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - new git-backed fixture
  helper and seven artifact-invariant cases.

**Verification**:

- `bash -n agent-system/extensions/core/scripts/tests/test-validate-state.sh` passes.
- `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` exits 0 with all cases
  passing, and the pre-existing five cases still pass (no regression).
- Both directions of the verification bar are visibly executed: the run output contains a passing
  assertion for the rejection case AND a passing assertion for the same write accepted under
  `--allow-artifact-removal`.
- The rejection case's fixture mutation is a raw `jq` assignment, confirmed by reading the test
  source, not a helper call.
- Temporary git fixtures are created under a `mktemp -d` path and cleaned up on exit.

---

### Phase 4: State the Append-Only Rule and Add the Agent Contract [NOT STARTED]

**Goal**: Make the invariant discoverable and binding in prose: state the append-only contract in
`rules/state-management.md`, explain at the `skill_link_artifacts` choke point why its same-type
removal is exempt by construction, and add the preventive `MUST NOT` to the implementation agent.

**Tasks**:

- [ ] `agent-system/extensions/core/rules/state-management.md`: add an
      **"Artifacts Are Append-Only (With Same-Type Supersession)"** subsection near the existing
      "File Synchronization" section. It must state: (a) `.artifacts` is append-only during the
      task lifecycle; (b) the one sanctioned exception is same-type 1-for-1 supersession as
      practiced by every current writer; (c) wholesale `.artifacts = [...]` assignment is
      prohibited — append via `+=` or call the helper; (d) the enforcement mechanism is
      `validate-state.sh --deep` with its `--allow-artifact-removal` opt-in for genuine deletions;
      and (e) the honest limitation that enforcement is periodic (via `verify-deploy.sh`), not
      write-time. Mirror the schema's existing `memory_candidates` "append-only during the task
      lifecycle" phrasing so the two read as one concept.
- [ ] `agent-system/extensions/core/scripts/skill-base.sh`: add an explanatory comment immediately
      above `skill_link_artifacts`'s two-step block. **No functional change to any line of code.**
      The comment must explain that the Step 1 same-type removal is 1-for-1 and therefore exempt by
      construction under the per-type invariant, cross-reference the new rules subsection, and warn
      against generalizing the pattern into a wholesale array assignment.
- [ ] `agent-system/extensions/core/agents/general-implementation-agent.md`: append a new numbered
      bullet to the existing **MUST NOT** list (currently ending at bullet 7): never assign
      `.artifacts` wholesale when updating `specs/state.json` directly — append via `+=`, or call
      the sanctioned helper — with a pointer to the new rule. Match the surrounding numbered-bullet
      style exactly.
- [ ] Cite durable anchors only. All three files are outside `specs/**`, so no task numbers may
      appear in any added text; reference filenames and section headings instead.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly three files change and that `skill-base.sh`'s
change is comment-only. Confirm with `git diff --stat` (expect three paths) and by reading
`git diff agent-system/extensions/core/scripts/skill-base.sh` to verify every added line begins
with `#` and no existing line was altered. Report both results.

**Files to modify**:

- `agent-system/extensions/core/rules/state-management.md` - new append-only subsection.
- `agent-system/extensions/core/scripts/skill-base.sh` - explanatory comment only, above
  `skill_link_artifacts`'s two-step block.
- `agent-system/extensions/core/agents/general-implementation-agent.md` - new MUST NOT bullet 8.

**Verification**:

- `bash -n agent-system/extensions/core/scripts/skill-base.sh` passes (guards the `prose` tier's
  named blind spot: an edit crossing out of the comment boundary).
- `git diff agent-system/extensions/core/scripts/skill-base.sh` shows only added `#` lines.
- `bash .claude/scripts/check-task-references.sh` exits 0 (no task-number citations introduced in
  any of the three deliverable files).
- `bash .claude/scripts/lint/lint-agent-contracts.sh` exits 0 (the new bullet did not disturb the
  canonical no-task-references bullet coverage check).
- The new rules subsection explicitly names both the `--allow-artifact-removal` opt-in and the
  periodic-enforcement limitation — grep for both.

---

### Phase 5: Integration Verification Against the Live Pipeline [NOT STARTED]

**Goal**: Confirm the invariant is genuinely wired end to end — deployed, exercised by the real
test suite and the real deploy gate — and that no sanctioned link path regressed.

**Tasks**:

- [ ] Deploy the source store so `.claude/` reflects the new source (the test suite and
      `verify-deploy.sh` gate 10 both invoke the *deployed* copy). Confirm the deployed
      `validate-state.sh` contains the new check by grepping it for the check's identifier.
- [ ] Run the full test suite: `bash .claude/scripts/tests/test-validate-state.sh` — all cases
      pass, and the new cases are executed against the deployed validator (not skipped).
- [ ] Run `bash .claude/scripts/validate-state.sh --deep specs/state.json` against the live state
      and confirm the outcome matches Phase 1's recorded baseline decision.
- [ ] Run `verify-deploy.sh` and confirm gate 10 passes (or, under the WARN-level branch, that it
      still passes with the new warning present and no new FAIL).
- [ ] Exercise a real sanctioned link end to end: invoke `skill_link_artifacts` (or its equivalent
      additive path) against a scratch fixture, then re-run the validator and confirm the new check
      reports no finding — the concrete proof that "existing call sites are unaffected."
- [ ] Re-state the accepted limitation in the implementation summary: enforcement is periodic, so a
      lossy write can still land between validation runs.

**Timing**: 0.75 hours

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Files to modify**:

- None (verification only). Any defect found here is fixed in its originating phase's file.

**Verification**:

- The deployed `validate-state.sh` demonstrably contains the new check (grep hit reported).
- Full `test-validate-state.sh` run exits 0 with zero skipped artifact-invariant cases.
- `verify-deploy.sh` gate 10 result is reported explicitly (PASS, or PASS-with-warning under the
  WARN branch).
- The sanctioned-link round trip produces no finding from the new check.

---

## Testing & Validation

- [ ] `bash -n` clean on `validate-state.sh`, `test-validate-state.sh`, and `skill-base.sh`.
- [ ] Rejection direction: a fixture write dropping more paths of a type than it adds produces a
      FAIL-level finding naming the project number, the type, both counts, and the dropped paths.
- [ ] Acceptance direction: the identical write with `--allow-artifact-removal` exits 0 and logs an
      explicit opt-in line.
- [ ] The rejection fixture's mutation is a hand-composed `jq` assignment, proving writer-agnostic
      detection.
- [ ] Sanctioned 1-for-1 same-type supersession and pure-append writes both pass with no finding.
- [ ] Type-scoped opt-in does not over-permit a different type's loss.
- [ ] Untyped entries participate in the invariant rather than being silently dropped.
- [ ] `--help` output is complete and untruncated after the header grew.
- [ ] `check-task-references.sh` and `lint-agent-contracts.sh` both exit 0.
- [ ] `verify-deploy.sh` gate 10 passes against the live `specs/state.json`.

## Artifacts & Outputs

- `specs/006_guard_against_nonadditive_artifact_rewrites/plans/01_guard-nonadditive-artifact-rewrites.md` (this plan)
- `specs/006_guard_against_nonadditive_artifact_rewrites/summaries/01_guard-nonadditive-artifact-rewrites-summary.md`
- Modified: `agent-system/extensions/core/scripts/validate-state.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-validate-state.sh`
- Modified: `agent-system/extensions/core/rules/state-management.md`
- Modified: `agent-system/extensions/core/scripts/skill-base.sh`
- Modified: `agent-system/extensions/core/agents/general-implementation-agent.md`

## Rollback/Contingency

Every change is additive and confined to five source-store files, with no call-site or schema
changes, so rollback is a straight `git revert` of the phase commits followed by a redeploy.

Graduated contingencies, in order of preference:

1. **The check fires on legitimate traffic during Phase 5.** Do not weaken the invariant to
   silence it — first confirm whether the traffic is genuinely 1-for-1 same-type. If it is, the
   defect is in the set-difference arithmetic (likely counting array length rather than distinct
   paths); fix the arithmetic.
2. **Pre-existing drift makes FAIL-level unlandable.** Fall back to the WARN-level branch recorded
   in Phase 1 with an explicit promotion criterion. The check still emits the finding; only its
   severity changes, so no detection capability is lost.
3. **Full revert.** Revert the `validate-state.sh` and `test-validate-state.sh` commits; the
   documentation and agent-contract changes from Phase 4 are independently valuable and may be
   retained even without the mechanical check, since they state the rule that was previously
   unwritten.
