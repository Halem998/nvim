# Implementation Plan: Task #65

- **Task**: 65 - Fix skill_orchestrate_mint_dispatch_seq to increment from the persisted counter
- **Status**: [NOT STARTED]
- **Effort**: 1.75 hours
- **Dependencies**: None
- **Research Inputs**: `specs/065_fix_mint_dispatch_seq_persisted_counter/reports/01_mint-dispatch-seq-fresh-shell-fix.md`
- **Artifacts**: plans/01_mint-dispatch-seq-persisted-counter-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, shell-script-testing.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace the ambient-shell-variable increment inside `skill_orchestrate_mint_dispatch_seq()`
(`agent-system/extensions/core/scripts/skill-base.sh`) with a read-modify-write against the loop
guard file, using the `jq -r '(.dispatch_seq_counter // 0) + 1'` idiom already proven at the
multi-task engine's Stage MT-4. Because both orchestrate engines reach this function through
byte-identical named shims, the single function edit fixes both. The fix is paired with a new
regression suite that exercises the mint function itself under a genuinely fresh shell and a
genuinely fresh subprocess — coverage no existing suite provides — and closed out by manifest
registration, deploy propagation, and a full suite run.

### Research Integration

The research report is the authoritative input and its conclusions are adopted without
re-derivation:

- Defect confirmed at `skill-base.sh:947-955`: `dispatch_seq_counter=$((dispatch_seq_counter + 1))`
  reads an ambient global that is unset in a fresh shell, so every mint returns `1`.
- The replacement idiom (`jq -r '(.dispatch_seq_counter // 0) + 1' "$loop_guard_file"`) is already
  battle-tested in-repo at `skill-orchestrate/SKILL.md` Stage MT-4.
- Both engines delegate through an identical one-line shim, so no SKILL.md edit is warranted; the
  report's recommendation to leave the now-redundant Stage 2 ambient assignments untouched (to
  protect the byte-identical-twin invariant established by the orchestrate-body dedup work) is
  adopted.
- No other reader depends on the ambient variable being mutated as a side effect.
- Test gap confirmed: `test-handoff-dispatch-identity.sh` injects `dispatch_seq` as a fixture and
  exercises only the downstream Stage 5 comparison; `test-loop-guard-budget-override.sh` asserts
  counter survival across a budget re-init. Neither calls the mint function. A new suite is
  required.

Two facts established during planning that the report did not cover, and that the plan therefore
adds work for:

1. **The deployed copy is stale until a deploy runs.** `.claude/scripts/skill-base.sh` currently
   carries the identical defective body. The established test harness pattern
   (`test-skill-base-lifecycle.sh`, `test-corroborate-phase-counts.sh`) resolves its
   subject-under-test **deploy-tree-first**, source-store-second. A new suite run immediately
   after a source-store-only fix would therefore source the *unfixed* deployed copy and report a
   false red. A deploy step is mandatory before the suite can give a meaningful verdict.
2. **New test files must be manifest-registered.** `agent-system/extensions/core/manifest.json`
   enumerates every deployed script by path (`tests/run-all.sh`, `tests/test-handoff-dispatch-identity.sh`,
   `tests/test-skill-base-lifecycle.sh`, ...). A new suite that is not added there is never
   deployed and never discovered by the deployed-mode `run-all.sh`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no roadmap flag was set; ROADMAP.md
was not consulted and must not be modified by this task.

## Goals & Non-Goals

**Goals**:
- Make `skill_orchestrate_mint_dispatch_seq()` derive the new sequence value exclusively from the
  persisted `.dispatch_seq_counter` in the loop guard file, with no dependence on any ambient
  shell variable.
- Preserve the function's existing external contract exactly: `$1` is the loop guard path; the
  incremented counter and a refreshed `last_updated` are persisted atomically; the new value is
  echoed on stdout for `dispatch_seq=$(mint_dispatch_seq)` capture.
- Preserve the never-repeats-within-a-task invariant, including across the budget-continuation
  override path that deliberately carries `dispatch_seq_counter` forward through a guard re-init.
- Add regression coverage that exercises the mint function itself under both a fresh-shell and a
  fresh-subprocess precondition, and that is demonstrably capable of failing against the pre-fix
  body.
- Propagate the fix to the deployed tree and leave the full shell suite green.

**Non-Goals**:
- Editing either `skill-orchestrate/SKILL.md` or `skill-orchestrate-hard/SKILL.md`. Their Stage 2
  ambient `dispatch_seq_counter` reads become dead with respect to the mint path but remain
  harmless and are still referenced by the fresh-start `jq -n` init payload and its surrounding
  comments; touching two deliberately byte-identical bodies is higher risk than the cleanup is
  worth.
- Adding read-write locking or any other concurrency mitigation to the mint path. The read-then-write
  race is real but out of scope: single-task guard access is already serialized by the
  orchestrator's single-threaded cycle loop, and the multi-task engine has its own per-task lock.
- Changing `test-handoff-dispatch-identity.sh`'s or `test-loop-guard-budget-override.sh`'s
  existing cases. New coverage goes in a new suite so the existing sentinel-region extraction
  contracts stay untouched.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New suite silently tests the stale deployed copy and reports a false green/red | H | H | Phase 3 runs the deploy before the suite; Phase 2 additionally asserts which path was resolved and echoes it as an `[INFO]` line so a future stale-deploy run is visible, not silent |
| New suite is authored but never deployed or discovered (missing manifest entry) | M | M | Phase 3 adds the `provides.scripts` entry and verifies discovery by confirming the suite appears in the deployed-mode `run-all.sh` run |
| The new test passes for the wrong reason (would also pass against the defective body) | H | M | Phase 2 mandates a red-demonstration against a scratch copy of the pre-fix function body before the phase may close |
| A caller silently relied on the ambient `dispatch_seq_counter` mutation as a side effect | M | L | Research grep confirms no such reader; Phase 1 re-confirms with a fresh grep across both SKILL.md files and `skill-base.sh` before editing |
| jq read failure on a missing/corrupt guard file now hard-fails where the arithmetic path degraded silently | L | L | Every call site is downstream of Stage 2's unconditional guard creation + `jq empty` validation; this is the same precondition Stage MT-4's identical idiom already relies on |
| Budget-continuation path regresses (counter reset to 1 after a re-init) | H | L | Phase 2 includes an explicit case seeding a post-re-init guard that carries a nonzero counter and asserting the next mint continues from it |
| Deploy overwrites unrelated `.claude/` state | M | L | Use the non-destructive default mode of `deploy-headless.sh` (never `--wipe`); review `git status` on `.claude/` is not applicable (gitignored deploy artifact), so verify by diffing the deployed function body against the source-store body |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is fully sequential: the test
needs the fix in place to go green, and the deploy/suite gate needs the test to exist.

---

### Phase 1: Confirm single-point-of-fix and apply the persisted-counter mint [NOT STARTED]

**Goal**: Re-confirm that one function edit covers both engines and breaks no ambient consumer,
then replace the ambient-variable increment with a read from the loop guard file.

**Tasks**:
- [ ] Re-confirm the shim claim: grep both `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
      and `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` for the
      `mint_dispatch_seq() {` definition and verify each body is the single line
      `skill_orchestrate_mint_dispatch_seq "$loop_guard_file"`. If either differs, STOP and
      re-scope — the no-SKILL.md-edit conclusion no longer holds.
- [ ] Re-confirm no ambient consumer: grep both SKILL.md files and `skill-base.sh` for
      `dispatch_seq_counter` and verify every occurrence is either (a) a Stage 2 init/resume
      assignment, (b) a `jq -n` init payload literal, (c) inside the mint function itself, or
      (d) a comment. Any read of the bare variable *after* a `mint_dispatch_seq` call is a
      blocker.
- [ ] Enumerate the `mint_dispatch_seq` call sites in both engines and record the counts actually
      observed (see Scope Hypothesis below).
- [ ] Edit `skill_orchestrate_mint_dispatch_seq()` in
      `agent-system/extensions/core/scripts/skill-base.sh` to compute the new value with
      `new_seq=$(jq -r '(.dispatch_seq_counter // 0) + 1' "$loop_guard_file")` held in a `local`,
      persist `$new_seq` through the existing tmp-file + `mv` write, and echo `$new_seq`. Do not
      assign to the ambient `dispatch_seq_counter` at all.
- [ ] Update the function's docblock to state that the value is derived from the persisted counter
      and is therefore correct under a caller that runs each stage in its own shell — the exact
      precondition the old body assumed and did not hold. Do not reference task numbers.
- [ ] `bash -n agent-system/extensions/core/scripts/skill-base.sh` and, if available,
      `shellcheck` the file to confirm no new findings on the edited region.
- [ ] Manual smoke check against a scratch guard fixture under the scratchpad directory: source
      the edited file in a shell with `dispatch_seq_counter` explicitly unset, seed a fixture with
      `{"dispatch_seq_counter": 4}`, call the function, and confirm stdout is `5` and the file now
      reads `5`.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The research report asserts 8 `mint_dispatch_seq` call sites in
`skill-orchestrate/SKILL.md` (lines 339, 383, 422, 465, 502, 574, 631, 1151), 5 in
`skill-orchestrate-hard/SKILL.md` (lines 582, 617, 669, 706, 835), 2 byte-identical shim
definitions, and 0 post-mint ambient readers. Confirm at implementation time with
`grep -n 'mint_dispatch_seq' <both SKILL.md>` and `grep -n 'dispatch_seq_counter' <both SKILL.md>
agent-system/extensions/core/scripts/skill-base.sh`; record the observed counts in the progress
file. Line numbers in particular are a hypothesis, not a fact — locate by pattern, never by line
number.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - replace the ambient-variable increment in
  `skill_orchestrate_mint_dispatch_seq()` with a `jq` read-increment from `$1`; refresh the
  docblock accordingly.

**Verification**:
- Both shim bodies confirmed identical and single-line; finding recorded.
- No post-mint ambient reader of `dispatch_seq_counter` exists in either engine; finding recorded.
- `bash -n` clean on the edited file.
- Scratch smoke check returns the seeded counter + 1 on stdout AND persists the same value.
- The function body contains no assignment to the ambient `dispatch_seq_counter`.

---

### Phase 2: Author the fresh-shell / fresh-subprocess mint regression suite [NOT STARTED]

**Goal**: Create a new test suite that calls `skill_orchestrate_mint_dispatch_seq` directly and
would fail against the pre-fix body — coverage neither existing dispatch-identity nor
budget-override suite provides.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-mint-dispatch-seq.sh`, modelled
      structurally on `test-skill-base-lifecycle.sh`: `set -uo pipefail`, `SCRIPT_DIR` +
      git-root-first `REPO_ROOT` resolution with the fixed-depth fallback, `resolve_candidate`
      (deploy-tree-first, source-store fallback), a `mktemp -d` WORKDIR with an EXIT-trap cleanup,
      `pass()`/`fail()`/`info()` helpers with integer counters, and exit codes 0 all-pass /
      1 any-fail / 2 environment error.
- [ ] Emit an `[INFO]` line naming the resolved `skill-base.sh` path, so a run against a stale
      deployed copy is visibly attributable rather than a mystery red.
- [ ] Case A (fresh shell): `unset dispatch_seq_counter` before sourcing; seed a guard fixture with
      `dispatch_seq_counter: 1`; call the function once; assert stdout is `2` and the persisted
      `.dispatch_seq_counter` is `2`.
- [ ] Case B (repeat call, same shell): call again immediately; assert stdout is `3` and the
      persisted value is `3` — proving no double-increment and no skipped increment when the
      ambient variable is stale rather than unset.
- [ ] Case C (poisoned ambient value): set `dispatch_seq_counter=99` in the calling shell, then
      call against a guard holding `5`; assert the result is `6`, not `100` — this is the case
      that pins the fix's actual intent (file wins, ambient is ignored).
- [ ] Case D (genuinely separate subprocess): invoke the function twice via two independent
      `bash -c '...'` calls that each source `skill-base.sh` afresh, against the same guard file;
      assert the two returned values are consecutive and strictly increasing. This is the faithful
      reproduction of the reported multi-Bash-tool-call execution shape.
- [ ] Case E (budget-continuation continuity): seed a guard shaped like a post-re-init guard that
      preserved a nonzero `dispatch_seq_counter`; assert the next mint continues from it rather
      than restarting at 1, pinning the never-repeats-within-a-task invariant across the override
      path.
- [ ] Case F (missing-field tolerance): seed a guard with no `dispatch_seq_counter` key at all;
      assert the mint returns `1` and writes `1` (the `// 0` default), so a guard written before
      the field existed self-heals rather than erroring.
- [ ] Red-demonstration (required before the phase may close): copy the pre-fix function body into
      a scratch shim file under the scratchpad directory, run the new suite's Case A/C logic
      against that scratch body, and confirm it FAILS. Record the observed failure output in the
      progress file. Do not commit the scratch shim and do not revert the repo to the pre-fix
      state to do this.
- [ ] `bash -n` the new suite; make it executable (`chmod +x`) — `run-all.sh` reports a lost exec
      bit as a loud `[SKIP]`, so the bit must be set at creation.
- [ ] Run the new suite directly; confirm all cases pass and the exit code is 0.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Six cases (A-F) are asserted as the coverage set. Confirm at implementation
time that each case is genuinely distinct in what it would catch; if any two collapse to the same
assertion in practice, drop the redundant one and record the reduction rather than padding the
count.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-mint-dispatch-seq.sh` - new regression suite
  (created).

**Verification**:
- Suite exits 0 with every case passing against the fixed function.
- Red-demonstration output captured showing the suite fails against the pre-fix body — a suite that
  passes against both bodies is not a regression test and the phase does not close.
- Suite has the executable bit set and `bash -n` is clean.
- Suite never writes outside its `mktemp -d` WORKDIR (confirm the real `specs/` tree and
  `.claude/` are untouched by the run).

---

### Phase 3: Register, deploy, and gate on the full shell suite [NOT STARTED]

**Goal**: Make the new suite a first-class deployed artifact, propagate the fix into `.claude/`,
and confirm nothing else regressed.

**Tasks**:
- [ ] Add `"tests/test-mint-dispatch-seq.sh"` to `provides.scripts` in
      `agent-system/extensions/core/manifest.json`, placed to match the existing ordering
      convention of the surrounding `tests/test-*.sh` entries.
- [ ] Validate the manifest still parses: `jq empty agent-system/extensions/core/manifest.json`.
- [ ] Run the non-destructive deploy (`bash .claude/scripts/deploy-headless.sh`, default mode —
      never `--wipe`) to propagate both the `skill-base.sh` fix and the new suite into `.claude/`.
- [ ] Confirm propagation: diff the deployed `skill_orchestrate_mint_dispatch_seq` body against the
      source-store body and confirm they match, and confirm
      `.claude/scripts/tests/test-mint-dispatch-seq.sh` exists and is executable.
- [ ] Re-run the new suite post-deploy; its `[INFO]` line must now name the deployed path and all
      cases must still pass.
- [ ] Run the two suites the research report named as adjacent:
      `test-handoff-dispatch-identity.sh` and `test-loop-guard-budget-override.sh`. Both must stay
      green — they extract sentinel regions from the SKILL.md files this plan deliberately does
      not touch, so any red here means an unintended edit leaked in.
- [ ] Run `test-skill-base-lifecycle.sh` and `test-deploy-propagation.sh` — the two suites most
      likely to notice a bad edit to `skill-base.sh` or a bad manifest entry respectively.
- [ ] Run the full discovery harness: `bash agent-system/extensions/core/scripts/tests/run-all.sh`.
      Confirm exit 0, confirm zero `[SKIP]` lines naming the new suite, and confirm the new suite
      actually appears in the run (a suite that is never discovered is not covered).
- [ ] If any pre-existing suite was already failing before this task's changes, record that
      baseline explicitly rather than attributing it to this work — and do not close the phase on
      an unexplained red.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The manifest is assumed to require exactly one new `provides.scripts` entry
and no other change (no separate test-registry file, no hook registration). Confirm by grepping
the manifest for how `tests/test-skill-base-lifecycle.sh` is registered and mirroring exactly that
single-entry shape; if that suite appears in more than one place, mirror all of them.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - add the new suite to `provides.scripts`.
- `.claude/**` - regenerated by the deploy engine only. Never hand-edited (see
  `.claude/rules/source-store-deploy-boundary.md`).

**Verification**:
- `jq empty` clean on the manifest.
- Deployed and source-store `skill_orchestrate_mint_dispatch_seq` bodies are byte-identical and
  both contain the `jq` read.
- `.claude/scripts/tests/test-mint-dispatch-seq.sh` present and executable.
- `run-all.sh` exits 0, discovers the new suite, and skips nothing.
- `test-handoff-dispatch-identity.sh`, `test-loop-guard-budget-override.sh`,
  `test-skill-base-lifecycle.sh`, `test-deploy-propagation.sh` all green.

---

## Testing & Validation

- [ ] `skill_orchestrate_mint_dispatch_seq` returns `persisted + 1` when the ambient
      `dispatch_seq_counter` is unset (fresh shell).
- [ ] It returns `persisted + 1` when the ambient variable holds a wrong, stale, or poisoned value
      (file wins).
- [ ] Two independent `bash -c` subprocesses minting against the same guard file produce strictly
      increasing consecutive values.
- [ ] The persisted `.dispatch_seq_counter` matches the value echoed on stdout after every mint.
- [ ] `last_updated` is refreshed on every mint (unchanged behavior).
- [ ] A guard file lacking the `dispatch_seq_counter` key mints `1` rather than erroring.
- [ ] A guard carrying a nonzero counter through a budget-continuation re-init continues from it.
- [ ] The new suite demonstrably fails against the pre-fix function body.
- [ ] `run-all.sh` exits 0 across both the source-store and deployed trees.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/scripts/skill-base.sh` (one function body + docblock)
- Created: `agent-system/extensions/core/scripts/tests/test-mint-dispatch-seq.sh`
- Modified: `agent-system/extensions/core/manifest.json` (one `provides.scripts` entry)
- Regenerated: `.claude/` deploy tree (gitignored artifact; not a reviewable output)
- Implementation summary: `specs/065_fix_mint_dispatch_seq_persisted_counter/summaries/01_*-summary.md`

## Rollback/Contingency

The change surface is three source-store files and a regenerated deploy tree, all under git except
`.claude/`.

- **Revert the code**: `git revert` (or `git checkout` from HEAD) the `skill-base.sh`,
  `manifest.json`, and new-test-file changes, then re-run `bash .claude/scripts/deploy-headless.sh`
  to restore the deployed tree to the reverted source state. The deploy tree is disposable and is
  always rebuildable from the source store, so it needs no separate rollback.
- **If Phase 1's re-confirmation fails** (shims differ, or a post-mint ambient reader exists): stop
  before editing, mark the phase `[BLOCKED]` with the specific finding, and re-scope — the fix may
  then require coordinated SKILL.md edits that this plan explicitly excludes.
- **If the red-demonstration in Phase 2 shows the new suite passes against the pre-fix body**: the
  suite is not discriminating. Do not commit it as-is; strengthen the assertions (Case C is the
  one most likely to be too weak) until it fails against the old body.
- **If a pre-existing suite is red in Phase 3 for reasons unrelated to this work**: record the
  baseline, keep this task's phases closeable on their own evidence, and raise the unrelated red
  separately rather than folding an unrelated fix into this change.
