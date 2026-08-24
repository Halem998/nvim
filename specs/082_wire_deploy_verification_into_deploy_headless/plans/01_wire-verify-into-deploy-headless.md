# Implementation Plan: Wire Deploy Verification Into deploy-headless.sh

- **Task**: 82 - wire_deploy_verification_into_deploy_headless
- **Status**: [NOT STARTED]
- **Effort**: 3.75 hours
- **Dependencies**: 32 (completed; not a live blocker)
- **Research Inputs**: specs/082_wire_deploy_verification_into_deploy_headless/reports/01_wire-verify-into-deploy-headless.md
- **Artifacts**: plans/01_wire-verify-into-deploy-headless.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`deploy-headless.sh`'s final line echoes the verify-deploy command instead of running it, so
twelve gates (five contract lints, doc-lint, task-reference lint, verify.lua parity, the shell
test suite, `validate-state --deep`, and two store/hook presence checks) are reachable only by a
human who types the command by hand. This plan adds a `--skip-slow` flag to `verify-deploy.sh`
that skips gate 8 (the 117.9s shell test suite) only, has `deploy-headless.sh` invoke
`verify-deploy.sh --skip-slow "$TARGET"` inline after a successful deploy, and exits with a new,
distinct code `3` when that verification fails — never overloading exit `2` ("the headless nvim
invocation failed"). `--dry-run` is excluded for free by the existing early `exit 0`. The plan
also records, in `regeneration-is-manual-only.md`, the collision this creates with
`skill-orchestrate` Stage MT-3 step 7's baseline-comparison contract, which this task's
`file_scope` cannot itself fix.

Definition of done: introducing a deliberate source-store drift, running `deploy-headless.sh`
with no flags, and observing the failure named in its own output with a non-zero exit — no human
invocation of `verify-deploy.sh` involved.

### Research Integration

All six research decisions are adopted:

1. The call goes **inside `main()`**, in the shared trailing block after the `DEPLOY_COUNT`
   success check (currently the `echo "[deploy-headless] Verify with: ..."` line). Both the
   default and `--wipe` branches converge there, and `--dry-run` already returned at the earlier
   `exit 0`. Moving any logic to top level would reinstate the SELF-OVERWRITE HAZARD the file's
   own header comment exists to prevent.
2. `"$TARGET"` is passed explicitly as verify-deploy's positional argument; `main`'s own cwd is
   never changed by the `$( cd "$TARGET" && nvim ... )` subshell, so ambient `pwd` is wrong.
3. `--skip-slow` gates gate 8 only, matching the measured cost split: gate 8 alone is 117.9s of
   the ~2.8min total; the remaining eleven gates cost roughly 50-70s combined.
4. Verification failure exits `3`, a code no current caller uses, leaving `0`/`1`/`2` semantics
   byte-identical for every existing caller.
5. The Stage MT-3 step 7 interaction is documented in `regeneration-is-manual-only.md`.
6. The pre-existing-red-gate consequence is disclosed rather than discovered in production.

**Measured this session, and material to sequencing**: `check-extension-docs.sh --quiet` (gate 3)
currently reports `FAIL: 12 issue(s) found` in this repo. Gate 3 is a *fast* gate, so
`--skip-slow` does not hide it. The moment this task lands, every `deploy-headless.sh` invocation
exits 3 until doc-lint is green. That is the intended behavior — surfacing a truth that was
previously invisible is the whole point of the task — but it makes the orchestrator interaction
in Phase 4 immediately live rather than theoretical, and Phase 5 must confirm it deliberately
rather than trip over it.

**Verified against the consumer's actual text**: `skill-orchestrate/SKILL.md`'s deploy-failure
branch reads "Non-zero exit (1 or 2) -> defer unconditionally ... with NO baseline consultation
whatsoever". Exit 3 is outside that parenthetical enumeration but inside the leading "Non-zero
exit" phrase — an ambiguity an LLM-executed step will resolve unpredictably. This is precisely
why the distinct exit code matters: it gives a follow-up task a clean discriminator to route exit
3 through the existing branch (b)/(c) baseline logic instead of the unconditional branch (a).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in the delegation context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Replace the echoed verify command in `deploy-headless.sh` with a real, inline invocation that
  runs on every non-dry-run deploy, in both the default and `--wipe` branches.
- Give `verify-deploy.sh` a `--skip-slow` flag that skips gate 8 only, keeping the inline cost to
  roughly 50-70s instead of ~2.8min.
- Establish and document the failure contract: deploy succeeded but the tree fails verification
  exits `3`, distinct from `1` (usage) and `2` (nvim invocation failed).
- Keep `--dry-run` from invoking verification (by construction, not by a new guard).
- Add a fixture-driven regression test so the new flag and the new exit path are themselves
  covered by the suite they gate.
- Record the `skill-orchestrate` Stage MT-3 step 7 collision, and the pre-existing-red-gate
  consequence, in `regeneration-is-manual-only.md`.

**Non-Goals**:
- Fixing `skill-orchestrate/SKILL.md` or `batch-orchestration-guardrails.md` to special-case exit
  3. Both are outside `file_scope`; this plan only ensures the discriminator exists and the gap is
  written down.
- Fixing the currently-red gates (doc-lint's 12 issues, or gate 8's three failing suites:
  `test-common-lib.sh`, `test-skill-base-lifecycle.sh`, `test-validate-return-meta.sh`). They are
  pre-existing and unrelated to this change.
- Wiring `check-runtime-file-tracking.sh` (confirmed orphaned, but not a verify-deploy gate and
  not in `file_scope`).
- Adding a `--no-verify` escape hatch to `deploy-headless.sh`. **Deliberate rejection**: the
  deploy itself has already landed by the time verification runs, so exit 3 costs a caller
  nothing but an exit code it can inspect; a documented bypass flag would become the default way
  to dodge the very gate this task installs, defeating the ACCEPTANCE criterion. A caller that
  wants deploy-only semantics checks for exit 3 specifically.
- Having `deploy-headless.sh` do its own pre/post baseline comparison to tolerate pre-existing
  findings. **Deliberate rejection**: the ACCEPTANCE test introduces its drift in the source store
  *before* the deploy, so a pre-deploy baseline would already contain that finding and classify it
  as pre-existing — the mechanism would fail the exact scenario it must pass. It also doubles the
  inline cost and duplicates logic that belongs in the orchestrator.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Every deploy exits 3 immediately, because doc-lint (gate 3) is red today with 12 issues | H | H (measured, certain) | Phase 4 documents it as intended-and-disclosed; Phase 5 confirms it deliberately. Not treated as a bug in this change |
| Orchestrator Stage MT-3 step 7 reads exit 3 as branch (a) and defers on pre-existing conditions, destroying branch (c) | H | H | Distinct exit code 3 (Phase 2) + explicit documentation (Phase 4) so a follow-up task can close it cheaply; disclosed, not silent |
| New code placed outside `main()` reintroduces the self-overwrite hazard | H | L | Phase 2 pins the insertion point inside `main()`, after the `DEPLOY_COUNT` check; verification includes a grep confirming nothing follows `main "$@"` |
| `set -euo pipefail` aborts `main` when verify-deploy exits non-zero, before the exit-3 branch runs | H | M | Phase 2 mandates the `-e`-safe `if bash ...; then ... else ... fi` form, never a bare call followed by `$?` |
| The new regression test invokes `verify-deploy.sh`, which gate 8 runs via `run-all.sh`, recursing | M | L | The test targets a throwaway *consumer* fixture with no `agent-system/extensions` directory, where gate 8 SKIPs — recursion is structurally impossible. Stated in the test's own header |
| `--help`'s `sed -n '2,43p' "$0"` range goes stale when header lines are added | L | H | Phase 1 explicitly updates the range and verifies `--help` renders the new flag |
| Deployed `verify-deploy.sh` predates `--skip-slow` and rejects the flag with exit 2 | L | L | The resync that just ran rewrote the deployed copy from the source store, so the deployed copy is always current by the time the call is made. No code needed; noted for a reader |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add `--skip-slow` to verify-deploy.sh [NOT STARTED]

**Goal**: `verify-deploy.sh --skip-slow` runs eleven gates and reports gate 8 as skipped, with
default-mode behavior (no flag) byte-for-byte unchanged.

**Tasks**:
- [ ] Add `SKIP_SLOW=false` beside the existing `QUIET`/`FINDINGS` declarations.
- [ ] Add `--skip-slow) SKIP_SLOW=true; shift ;;` to the `while [ $# -gt 0 ]` case block, above
      the `-*)` unknown-flag arm.
- [ ] In gate 8's block, add a `SKIP_SLOW` branch as the FIRST condition of the existing
      `if`-chain, before the `[ ! -d "$TARGET/agent-system/extensions" ]` test, emitting
      `say "  [SKIP] --skip-slow: shell test suite deferred (run without --skip-slow for the full gate)"`.
      Use the same `say`/`[SKIP]` shape the source-store-vs-consumer skips already use — a skip
      must never increment `CHECKS` or `FAILURES`, and must never append to `FINDINGS_LIST`.
- [ ] Update the header comment: add `[--skip-slow]` to the `Usage:` line, and add a short
      `Slow-gate selection (--skip-slow)` paragraph stating that it skips gate 8 ONLY, why (gate 8
      measured at 117.9s of the ~2.8min total), and that it is additive — findings, exit codes,
      and every other gate are unchanged.
- [ ] Update the `-h|--help` handler's `sed -n '2,43p' "$0"` line-range to the new last line of
      the header comment block.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the gate-8 block is the *only* site needing a
`SKIP_SLOW` branch, and that gate 8 is the sole gate above ~20s. Confirm at implementation time
by `grep -n 'run-all.sh' agent-system/extensions/core/scripts/verify-deploy.sh` (expect hits
inside gate 8's block only) and by timing a `--skip-slow` run against the unflagged run — the
delta should be ~115-120s, not materially more or less.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - flag declaration, arg-parse arm,
  gate 8 skip branch, header usage/`--help` range

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --help` renders the new flag and
  does not truncate mid-sentence.
- `time bash .claude/scripts/verify-deploy.sh --skip-slow .` reports `8. Shell test suite ... [SKIP]`
  and completes in roughly 50-70s.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --findings --quiet .` emits no `FINDING gate8`
  line.
- `bash .claude/scripts/verify-deploy.sh --bogus-flag` still exits 2 with the unknown-flag message
  (the `-*)` arm is unshadowed).
- Direct dependents enumerated for this tier: `deploy-headless.sh` (does not yet call it — Phase 2)
  and `skill-orchestrate/SKILL.md`'s two `--findings --quiet` call sites, which pass no new flag
  and are therefore unaffected. Confirm the unflagged path is unchanged by diffing a
  `--findings --quiet` capture against one taken before the edit.

---

### Phase 2: Invoke verify-deploy inline from deploy-headless.sh with exit 3 [NOT STARTED]

**Goal**: A non-dry-run `deploy-headless.sh` runs `verify-deploy.sh --skip-slow "$TARGET"` after
a successful deploy and exits 3 if it fails, with the failure text visible in the deploy's own
output.

**Tasks**:
- [ ] Replace the `echo "[deploy-headless] Verify with: bash $TARGET/.claude/scripts/verify-deploy.sh"`
      line — the last statement before `exit 0` inside `main()` — with the real invocation. Do not
      add any code after `main "$@"`.
- [ ] Use the `-e`-safe conditional form, letting output stream to the caller's stdout/stderr
      rather than capturing it:
      `if bash "$TARGET/.claude/scripts/verify-deploy.sh" --skip-slow "$TARGET"; then ... else ... fi`.
      A bare call followed by `$?` would abort `main` under `set -e` before the exit-3 branch runs.
- [ ] Precede the call with a one-line announcement naming what runs and what is deferred, e.g.
      `[deploy-headless] Verifying deploy (fast gates; shell test suite deferred) ...`.
- [ ] On the failure branch, print to stderr that the deploy itself landed but the tree fails
      verification, name the full-gate re-run command
      (`bash $TARGET/.claude/scripts/verify-deploy.sh`), and `exit 3`.
- [ ] On the success branch, print a short pass line and `exit 0` (preserving today's exit-0
      terminus).
- [ ] Update the header `Exit codes:` block: add
      `3  the deploy completed, but verify-deploy.sh (fast gates) reported one or more failures`,
      and add a sentence noting that exit 3 means the tree WAS modified, unlike 1 and 2.
- [ ] Add `--skip-slow` context to the header `Usage:` block only if a usage line changes;
      otherwise leave `Usage:` untouched (no new deploy-headless flag is introduced).

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts a single insertion point serves both the default and
`--wipe` branches. Confirm at implementation time by reading the trailing block and checking that
both branch bodies fall through to it (the `if [ "$WIPE" = "true" ]` reporting block is the last
divergence before the shared echo), and by running `--wipe --dry-run` and the plain `--dry-run`
and observing neither reaches the verify call.

**Files to modify**:
- `agent-system/extensions/core/scripts/deploy-headless.sh` - trailing block inside `main()`,
  header exit-code documentation

**Verification**:
- `bash agent-system/extensions/core/scripts/deploy-headless.sh --dry-run .` prints the DRY RUN
  block, does NOT print the new verification announcement, and exits 0.
- `bash agent-system/extensions/core/scripts/deploy-headless.sh --wipe --dry-run .` likewise.
- `tail -5 agent-system/extensions/core/scripts/deploy-headless.sh` shows `main "$@"` as the last
  statement with nothing executable after it.
- `bash -n agent-system/extensions/core/scripts/deploy-headless.sh` parses clean.
- A real `bash .claude/scripts/deploy-headless.sh` run in this repo prints the deploy count, then
  verification output including doc-lint's current failures, and exits 3 (`echo $?`). Given the
  measured red gate 3, exit 3 is the expected result today, not a regression.
- Direct dependents enumerated for this tier: `skill-orchestrate/SKILL.md` Stage MT-3 step 7 (the
  one sanctioned automated caller). Do not edit it; confirm only that exits 0/1/2 retain their
  existing meanings so the step's current text stays correct for those codes.

---

### Phase 3: Fixture-driven regression test [NOT STARTED]

**Goal**: The `--skip-slow` flag and the `--dry-run`-does-not-verify invariant are covered by the
shell suite, so a future edit that breaks either fails a gate rather than a production deploy.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh`, following
      `test-deploy-freshness.sh`'s structure: `pass()`/`fail()`/`info()` helpers, PASSED/FAILED
      counters, trap-based scratch WORKDIR, `git rev-parse --show-toplevel` REPO_ROOT resolution
      that works from both the source-store and deployed copies, exit 0 all-pass / 1 any-fail /
      2 environment error.
- [ ] Write a header paragraph stating the anti-recursion invariant explicitly: the fixture target
      is a throwaway *consumer* directory containing only a minimal `.claude/` tree and NO
      `agent-system/extensions` directory, so gate 8 SKIPs there and `run-all.sh` can never invoke
      itself through this suite.
- [ ] Case: `verify-deploy.sh --skip-slow <fixture>` exits with the same code as
      `verify-deploy.sh <fixture>` on the fixture (both reach the same gate set there) and its
      output contains a gate-8 `[SKIP]` line.
- [ ] Case: `verify-deploy.sh --skip-slow --findings --quiet <fixture>` emits no `FINDING gate8`
      line.
- [ ] Case: `verify-deploy.sh --bogus <fixture>` still exits 2 (unknown-flag arm unshadowed).
- [ ] Case: `deploy-headless.sh --dry-run <fixture>` output contains `DRY RUN` and does NOT
      contain the verification announcement string, and exits 0. Do not run a non-dry-run deploy
      against a fixture — that would launch nvim and write files.
- [ ] Case: static assertion that `deploy-headless.sh`'s source contains `exit 3` and that its
      header documents code 3, guarding against the exit-code contract being silently dropped.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts five cases suffice and that a consumer fixture reaches
gates 1, 2, and 10's skip paths without needing a `specs/state.json`. Confirm at implementation
time by running the new suite standalone and reading its per-case output; add a case rather than
assume coverage if the fixture turns out to exercise fewer gates than expected.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` - new file

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` exits 0 with all
  cases passing.
- The suite completes in well under 20s (it must not become a second slow gate).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet 2>&1 | tail -3` discovers
  the new suite (total count increases by one) and the three known pre-existing failures are
  unchanged at three — this new suite must not add a fourth.
- Scope note: this file is outside the task's declared `file_scope`, which named only the three
  files above. Recorded here deliberately as a disclosed expansion, not an omission — the added
  file is a new test with no production call site.

---

### Phase 4: Document the contract and the orchestrator collision [NOT STARTED]

**Goal**: A reader of `regeneration-is-manual-only.md` finds the new exit-3 contract, the
fast-vs-full gate split, and the Stage MT-3 step 7 interaction, without having to read either
script.

**Tasks**:
- [ ] Add a subsection under `## Automated Exception: The Inter-Cycle Self-Modification
      Checkpoint` (the section that already narrates what the automated caller is and is not
      licensed to do), matching that section's existing "narrow, don't silently rewrite" voice.
- [ ] Record the exit-code contract: `deploy-headless.sh` now exits `3` when the deploy landed but
      `verify-deploy.sh --skip-slow` failed, distinct from `1` (usage) and `2` (nvim invocation
      failed / snapshot refused). State that exit 3 means the tree WAS modified.
- [ ] Record the gate split: the inline call runs eleven fast gates (~50-70s) and defers gate 8,
      the shell test suite (measured 117.9s); the full gate set remains available by running
      `verify-deploy.sh` with no flag.
- [ ] Record the collision, precisely: Stage MT-3 step 7's deploy-failure branch is written as
      "Non-zero exit (1 or 2) -> defer unconditionally ... with NO baseline consultation
      whatsoever". Exit 3 sits outside that enumeration but inside the leading "Non-zero exit"
      phrase, so the step's behavior on exit 3 is currently ambiguous, and the most likely reading
      routes it through branch (a) — bypassing the pre/post `--findings` baseline that branches
      (b) and (c) exist to consult. The consequence: a pre-existing failure that branch (c) is
      designed to tolerate would instead defer every remaining task, every cycle.
- [ ] Record the recommended follow-up, without doing it: a separately-scoped task should teach
      Stage MT-3 step 7 to treat exit 3 as "deploy succeeded, verification failed" and route it
      through the same baseline comparison branches (b)/(c) already use. Name both out-of-scope
      files (`skills/skill-orchestrate/SKILL.md`, `context/patterns/batch-orchestration-guardrails.md`)
      so the follow-up has its file scope ready.
- [ ] Record the live consequence: doc-lint (gate 3, a fast gate) reports 12 issues in this repo as
      of this change, and gate 8 has three failing suites, so deploys report failure until those
      are fixed. State that this is the intended surfacing of a previously-invisible condition.
- [ ] Add cross-references from the two scripts' header comments to this subsection, so a reader
      arriving at either file finds the narrative.
- [ ] Cite durable anchors only — file names and section headings, never task numbers (this file
      lives outside `specs/**`).

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - new subsection
  under `## Automated Exception`
- `agent-system/extensions/core/scripts/deploy-headless.sh` - header cross-reference line (comment only)
- `agent-system/extensions/core/scripts/verify-deploy.sh` - header cross-reference line (comment only)

**Verification**:
- Diff read-through confirming every changed hunk in the two `.sh` files lies inside a `#` comment
  region (the `prose` tier's stated obligation), and that neither file's executable body changed.
- `bash -n` on both scripts still parses clean (guards the comment-boundary blind spot).
- `grep -nE '\b[Tt]ask [0-9]+' agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
  returns nothing (no task-number references outside `specs/**`).
- `bash .claude/scripts/check-extension-docs.sh --quiet` issue count does not increase above the
  12 measured before this phase.

---

### Phase 5: Acceptance verification and timing measurement [NOT STARTED]

**Goal**: Demonstrate the ACCEPTANCE criterion end to end — a deliberately introduced drift
surfaces through a plain `deploy-headless.sh` run, non-zero, with no human verify-deploy
invocation — and record the real inline cost.

**Tasks**:
- [ ] Record the pre-change baseline: run `bash .claude/scripts/verify-deploy.sh --findings --quiet .`
      and save the sorted findings set, so a newly introduced finding is distinguishable from the
      12 doc-lint issues and 3 test-suite failures already present.
- [ ] Introduce a deliberate `index-entries` `line_count` mismatch in a single source-store doc
      (the drift class named in the ACCEPTANCE criterion), in a file that is easy to restore.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` with no flags. Capture stdout, stderr, and
      `echo $?`.
- [ ] Confirm: exit code is 3; the deploy count line printed (the deploy itself landed); the
      injected mismatch appears by name in the output; and no human `verify-deploy.sh` invocation
      was involved.
- [ ] Revert the injected mismatch; re-run `deploy-headless.sh`; confirm the injected finding is
      gone from the output and that the remaining findings match the Phase 5 baseline exactly
      (exit stays 3 because doc-lint is red — expected, and the reason the baseline capture in
      step 1 is mandatory).
- [ ] Measure and record: `time bash .claude/scripts/verify-deploy.sh --skip-slow .` versus
      `time bash .claude/scripts/verify-deploy.sh .`, confirming the ~115-120s delta the plan
      assumed. If the fast-gate path exceeds ~90s, record it as a finding for a follow-up rather
      than expanding scope here.
- [ ] Confirm the deploy tree is clean and consistent after the injection/revert cycle:
      `git status --short` shows no unintended residue under `.claude/` or the source store.

**Timing**: 0.75 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: This phase assumes the injected `line_count` mismatch produces a *new*
`FINDING gate3` line distinguishable from the 12 pre-existing doc-lint issues. Confirm by
set-diffing the post-injection findings against the step-1 baseline with
`comm -13`; if the injection produces no new finding line, choose a different drift class
(e.g. deleting a file gate 1 checks for) rather than declaring the acceptance criterion met.

**Files to modify**:
- None permanently. The injected mismatch is introduced and reverted within this phase.

**Verification**:
- The full gate set runs at this tier: `bash .claude/scripts/verify-deploy.sh .` (no `--skip-slow`)
  after the revert, with its findings set compared against the Phase 5 step-1 baseline. Nothing is
  deferred past this phase.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` failure count is 3 (the
  known pre-existing suites), not 4.
- `git status --short` clean of injection residue.

---

## Testing & Validation

- [ ] `bash -n` parses clean on both modified scripts.
- [ ] `verify-deploy.sh --help` renders the new flag with no truncation.
- [ ] `verify-deploy.sh --skip-slow` skips gate 8 and emits no `FINDING gate8` line.
- [ ] `verify-deploy.sh` with no flag is byte-for-byte unchanged in behavior (findings diff against
      a pre-change capture).
- [ ] `deploy-headless.sh --dry-run` and `--wipe --dry-run` do not invoke verification and exit 0.
- [ ] `deploy-headless.sh` (real run) exits 3 while any fast gate is red, and prints the failure.
- [ ] `test-deploy-verify-wiring.sh` passes standalone and is discovered by `run-all.sh`.
- [ ] `run-all.sh` failure count stays at the pre-existing 3.
- [ ] The ACCEPTANCE scenario (inject drift -> deploy -> observe non-zero + named failure ->
      revert) is demonstrated with captured output.
- [ ] No task-number references land outside `specs/**`.
- [ ] All edits target `agent-system/extensions/**`; `.claude/**` is touched only by the deploy
      itself.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/verify-deploy.sh` (modified: `--skip-slow` flag, gate 8
  skip branch, header docs, `--help` range)
- `agent-system/extensions/core/scripts/deploy-headless.sh` (modified: inline verify invocation,
  exit code 3, header exit-code docs)
- `agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` (new)
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (modified: new
  subsection under `## Automated Exception`)
- `specs/082_wire_deploy_verification_into_deploy_headless/summaries/01_wire-verify-into-deploy-headless-summary.md`
- A recommended follow-up task, named in the summary's deferred-decisions section: teach
  `skill-orchestrate` Stage MT-3 step 7 to route exit 3 through its existing baseline comparison
  instead of the unconditional defer branch.

## Rollback/Contingency

Each phase is independently revertible, and the phases are ordered so that the riskiest change
(Phase 2, on an orchestrator-critical path) lands after its dependency and before the
documentation and acceptance phases that describe it.

- **Phase 1 alone is inert**: `--skip-slow` has no caller until Phase 2. If Phase 2 must be
  reverted, Phase 1 can stay — the flag is purely additive and every unflagged invocation is
  unchanged.
- **Phase 2 revert**: restore the single `echo` line and the header exit-code block. This returns
  `deploy-headless.sh` to exactly today's behavior. This is the escape hatch if the exit-3 defer
  behavior proves operationally intolerable before the follow-up lands.
- **If the orchestrator starts deferring every cycle** and the follow-up is not yet available, the
  sanctioned interim response is to fix the red fast gates (doc-lint's 12 issues), not to revert
  Phase 2 — the deferrals are reporting a real condition.
- **Phase 5 injection must always be reverted** before the phase closes; the phase's own
  verification includes a `git status --short` check for residue.
- The implementation phase runs under a redeploy checkpoint. Because Phase 2 modifies
  `deploy-headless.sh` itself, the implementer must confirm after each edit that the deployed copy
  and the source-store copy agree (`diff .claude/scripts/deploy-headless.sh
  agent-system/extensions/core/scripts/deploy-headless.sh`), and must never hand-edit `.claude/**`.
