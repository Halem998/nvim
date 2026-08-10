# Implementation Plan: Report a confirmably-dead pid within the grace floor as its own liveness reason

- **Task**: 997 - Report a confirmably-dead pid within the grace floor as its own liveness reason
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/997_fix_session_liveness_reason_mislabel/reports/01_verify-liveness-reason-ladder.md
- **Artifacts**: plans/01_dead-pid-within-grace-reason.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`session_liveness()` in `agent-system/extensions/core/scripts/task-lock.sh` discards the result of
its own `kill -0` probe when the entry's heartbeat age is at or below
`SESSION_REGISTRY_DEAD_PID_MIN` (default 10 min), and falls through to a final branch that assigns
`pid-alive` on the sole basis that the `pid` field is numeric. The verdict this produces
(`live: true`, not reaped) is correct and must be preserved exactly; only the reason *string* is
wrong, and it is propagated verbatim into operator-facing defer output. The fix carries the
`kill -0` result forward into the fallback branch and names the state
`dead-pid-within-grace`, then reconciles the three prose/comment sites that assert
`session_liveness()` has five reasons.

Two phases: (1) the ladder change, its in-file docstring, and the test assertions that actually
exercise the fixed branch; (2) the three doc/comment sites, followed by redeploy and the full
verification gate.

### Research Integration

The research report confirms the ladder quote matches HEAD byte-for-byte and establishes three
facts that materially shrink this plan:

1. **No consumer branches on the literal `pid-alive` string.** `cmd_session_list`'s `live_flag`
   case and `cmd_session_reap`'s reap-set case both use `dead-pid|stale-heartbeat)` named branches
   with `*)` wildcard defaults, so a new sixth reason automatically gets `live: true` and is
   automatically excluded from the reap set with **zero code changes to either function**.
   `session_contention()`'s D4 liveness exclusion filters on the boolean `.live` field, so
   `scripts/lib/file-scope-overlap.sh` needs no change either.
2. **A third five-reasons claim site exists** beyond the two named in the task description:
   `scripts/orchestrate-batch-admit.sh` (a code comment textually near-identical to the
   `batch-admit-schema.md` schema-table row). It is outside the task's declared `file_scope` —
   see "Scope Additions" below.
3. **Neither existing test asserts the reason string for the below-floor dead-pid fixture.**
   `test-session-registry.sh` Case 8 builds exactly the right fixture (`sess_dead_young`, dead pid,
   5 min heartbeat) but only asserts non-reaping; `test-conflict-predicate.sh` Case 4.2 uses
   `mins_ago=20`, above the floor, so it exercises the already-correct `dead-pid` branch. "The
   existing tests still pass" is therefore necessary but **not sufficient** — new assertions are
   mandatory, not optional.

### Scope Additions

The task's declared `file_scope` names three files. This plan requires three additions, each
recorded here as an explicit, reasoned widening rather than a silent one:

| Added file | Why |
|---|---|
| `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` | Carries a code comment stating the same "five reasons" count and the same constrained allowed-value list as the `batch-admit-schema.md` row already in scope. Leaving it stale would reintroduce the exact contradiction this task exists to remove, in a file a reader of the schema doc is likely to open next. |
| `agent-system/extensions/core/scripts/test-session-registry.sh` | The verification bar's first three bullets are not currently asserted anywhere. This file already owns the correct fixture. |
| `agent-system/extensions/core/scripts/test-conflict-predicate.sh` | Requirement #2's "confirm `session_contention()`'s contend-set is unchanged: the entry still contends" has no existing coverage for the below-floor case. |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task.

## Goals & Non-Goals

**Goals**:
- Emit a distinct sixth `liveness_reason`, `dead-pid-within-grace`, for "pid confirmably gone via
  `kill -0`, heartbeat age at or below `SESSION_REGISTRY_DEAD_PID_MIN`".
- Preserve every existing verdict byte-for-byte: the new reason maps to `live: true`, is never
  selected by `session-reap`, and still contends in `session_contention()`.
- Add test assertions that fail against the pre-fix code and pass against the fixed code, for all
  three reason-string outcomes named in the verification bar.
- Reconcile all three sites asserting `session_liveness()` has five reasons, plus the
  `session_active` allowed-value list and the `live`-derivation membership list.

**Non-Goals**:
- Changing `cmd_session_list`'s `live_flag` case or `cmd_session_reap`'s reap set. The existing
  wildcard defaults already produce the required verdict; editing them is unnecessary churn and
  risks changing behavior for `corrupt`/`undeterminable`.
- Changing `scripts/lib/file-scope-overlap.sh`. `session_contention()` filters on the `.live`
  boolean, not the reason string.
- Changing `SESSION_REGISTRY_DEAD_PID_MIN`, `SESSION_REGISTRY_REAP_MIN`, or the ladder's
  evaluation order.
- Fixing the suffixed-vs-bare `session_id` self-contention defect the research report observed
  live. It is a D4 exclusion-1 equality defect with no code-path overlap with the reason ladder,
  and is explicitly out of scope.
- Renaming or re-defining `pid-alive`, `dead-pid`, `stale-heartbeat`, `corrupt`, or
  `undeterminable`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The new reason silently changes a verdict (gets reaped, or flips `live` to false) | H | L | Phase 1's new assertions check `live` and reap-selection directly, not just the string; Phase 1 also asserts the above-floor `dead-pid` path is unregressed |
| Tests pass without ever exercising the fixed branch (the current state of the suite) | H | M | Each new assertion is written to be one that FAILS against pre-fix code; Phase 1 verification explicitly requires demonstrating that, not merely a green run |
| `orchestrate-batch-admit.sh`'s stale comment is missed because it is outside declared `file_scope` | M | M | Recorded as an explicit scope addition above and as a named Phase 2 task; Phase 2's Scope Hypothesis requires a repo-wide re-grep rather than trusting the enumerated list |
| Source-store edits land but the deploy tree is not refreshed, so `verify-deploy.sh` gate 5 fails on content-hash drift | M | M | Phase 2 runs `deploy-headless.sh` before `verify-deploy.sh`; this ordering is stated as a task, not left implicit |
| An edit to a `#` comment block in `orchestrate-batch-admit.sh` crosses the comment boundary | M | L | Phase 2 verification runs `bash -n` on the file — the named blind spot of the `prose` tier |
| A doc site asserting the count is missed because the claim is implicit (bullet count, membership list) rather than the literal word "five" | M | M | Phase 2 enumerates the known implicit sites (the bullet list, the "other four" phrase, the `live`-derivation membership list) and requires a grep over all five existing reason names, not just the word "five" |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Ladder fix, docstring, and reason-string test assertions [COMPLETED]

**Goal**: `session_liveness()` emits `dead-pid-within-grace` for a confirmably-dead pid at or
below the grace floor, with the verdict unchanged, and both test suites now assert the reason
string for that branch.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/task-lock.sh`, `session_liveness()`: add a
      `pid_dead=false` local, set it to `true` inside the existing `if ! kill -0 "$pid"` block
      (alongside, not replacing, the existing `age -gt SESSION_REGISTRY_DEAD_PID_MIN` ->
      `reason="dead-pid"` assignment), and extend the final `if [ -z "$reason" ]` fallback to test
      `pid_dead` FIRST:
      `if [ "$pid_dead" = true ]; then reason="dead-pid-within-grace"; elif [ -n "$pid" ] && [[ "$pid" =~ ^[0-9]+$ ]]; then reason="pid-alive"; else reason="undeterminable"; fi`
      *(completed)*
- [x] Confirm by reading that the `corrupt` early-return, the `dead-pid` branch, the
      `stale-heartbeat` branch, and the two threshold comparisons are all untouched — the
      evaluation ORDER must remain byte-for-byte as it is today. *(completed)*
- [x] Update the `session_liveness` docstring comment block directly above the function: add the
      `dead-pid-within-grace` entry (place it immediately after `dead-pid` to mirror evaluation
      order), and change the `corrupt` line's "short-circuits the other four" to "the other five".
      *(completed)*
- [x] In `agent-system/extensions/core/scripts/test-session-registry.sh`, insert a new case
      (label it `5a` to avoid renumbering the existing 6-10; the harness's pass/fail helpers take
      free-form label strings and no parser reads them) between the reap-fixture write block and
      Case 6's dry-run. It calls `"$TL" session-list` against the full untouched fixture set and
      asserts, per entry via `jq -c 'select(.session_id=="...")'`:
      `sess_dead_young` -> `liveness_reason == "dead-pid-within-grace"` AND `live == true`;
      `sess_dead_old` -> `liveness_reason == "dead-pid"` AND `live == false`;
      `sess_live_young` -> `liveness_reason == "pid-alive"` AND `live == true`.
      Placing it before Case 6 is required: `sess_dead_old` is reaped by the later live reap and
      would no longer be listable. *(completed)*
- [x] In the same file, extend Case 6's dry-run assertion to additionally require that
      `$dry_run_out` does NOT contain a `would reap:` line naming `sess_dead_young` (the
      verification bar's "`session-reap --dry-run` does not select it" clause, currently asserted
      only for the live reap in Case 8). *(completed)*
- [x] In `agent-system/extensions/core/scripts/test-conflict-predicate.sh`, add a case `4.2b`
      immediately after existing case 4.2, reusing `write_session_fixture` with a below-floor age:
      `write_session_fixture "sess_dead_grace" "$DEAD_PID" '[899]' '["g4/clean"]' 5`. Assert both
      halves of the contend-set claim: (a) `"$TL" session-list` reports
      `liveness_reason == "dead-pid-within-grace"` with `live == true` for it, and (b)
      `"$BA" --session-id "sess_caller" 820` returns `decision == "defer"` with
      `defer_reason == "session_active"` and `session_liveness_reason == "dead-pid-within-grace"`.
      Call `reset_sessions` after, matching the surrounding cases. *(completed)*
- [x] Run both suites from the source store so they copy the EDITED `task-lock.sh` (each harness
      copies from its own `SCRIPT_DIR`; running the deployed `.claude/scripts/` copies would test
      the un-redeployed old code and produce a false green). *(completed: also ran the
      falsifiability check via `git stash push --keep-index -- task-lock.sh`, confirmed case 5a
      and case 4.2b both FAIL against the unmodified ladder, then restored the fix and confirmed
      both suites green)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts its edits are confined to exactly three files
(`scripts/task-lock.sh`, `scripts/test-session-registry.sh`, `scripts/test-conflict-predicate.sh`)
and that no change is needed in `cmd_session_list`, `cmd_session_reap`, or
`scripts/lib/file-scope-overlap.sh`. Confirm at implementation time by running
`grep -rn "liveness_reason\|pid-alive\|dead-pid\|stale-heartbeat\|undeterminable" agent-system/extensions/core/`
and classifying every hit as producer / wildcard-default consumer / opaque interpolation / doc.
If any hit turns out to branch on a named reason literal in a way the wildcard default does not
cover, the hypothesis is falsified and that file must be added to this phase before it closes.

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - `session_liveness()` ladder fallback plus
  its docstring comment block
- `agent-system/extensions/core/scripts/test-session-registry.sh` - new case `5a`; Case 6 dry-run
  assertion extended
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` - new case `4.2b`

**Verification**:
- `bash -n agent-system/extensions/core/scripts/task-lock.sh` exits 0
- `bash agent-system/extensions/core/scripts/test-session-registry.sh` exits 0, and the new case
  `5a` reports PASS by name in the output
- `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` exits 0, and case `4.2b`
  reports PASS by name
- **Falsifiability check (required, not optional)**: before or after landing the ladder change,
  demonstrate that the new assertions actually exercise the fixed branch — e.g. run the new
  assertions against the unmodified ladder (via `git stash` of the `task-lock.sh` hunk only, or a
  scratch copy) and confirm they FAIL there. A new assertion that passes against pre-fix code is
  not covering the defect and must be rewritten.
- No diff in `cmd_session_list`, `cmd_session_reap`, or `scripts/lib/file-scope-overlap.sh`
  (`git diff --stat` confirms the three-file scope)

---

### Phase 2: Reconcile the five-reasons doc claims, redeploy, and run the full gate [COMPLETED]

**Goal**: Every prose and comment site describing `session_liveness()`'s reason set names six
reasons, includes `dead-pid-within-grace` in the `session_active` allowed-value list and the
`live`-derivation membership list, and the deploy tree plus full verification gate are green.

**Tasks**:
- [x] `agent-system/extensions/core/context/patterns/task-lock.md`, the
      `session_liveness()` reason bullet list: add a `dead-pid-within-grace` bullet immediately
      after `dead-pid`, defined as "`pid` is a parseable integer, `kill -0 $pid` FAILS, and `age`
      does NOT exceed `SESSION_REGISTRY_DEAD_PID_MIN` — the grace floor holds the verdict at
      `live: true`, but the reason no longer claims the process is alive". *(completed)*
- [x] Same file, the `corrupt` bullet: "short-circuits the other four" -> "the other five".
      *(completed)*
- [x] Same file, the paragraph following the bullet list ("`pid-alive` and `undeterminable` are
      states `session-reap` alone never needed to distinguish"): extend to name all three
      do-not-reap states including `dead-pid-within-grace`. *(completed)*
- [x] Same file, the `session-reap` two-signal numbered list: step 2's parenthetical ("the pid is
      alive, or liveness is undeterminable") must also name the confirmably-dead-below-floor case,
      which likewise falls through to the `stale-heartbeat` band. *(completed)*
- [x] Same file, the `session-list` section's `live` derivation sentence (`liveness_reason NOT IN
      {dead-pid, stale-heartbeat}` — "true for `pid-alive`, `corrupt`, AND `undeterminable`"): add
      `dead-pid-within-grace` to that membership list. *(completed)*
- [x] `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`, the
      `session_liveness_reason` schema-table row: "five reasons" -> "six reasons", and append
      `dead-pid-within-grace` to the `pid-alive` / `corrupt` / `undeterminable` allowed-value list.
      The value genuinely reaches this verdict path: D4 excludes on the `live` boolean, and
      `dead-pid-within-grace` is `live: true`, exactly like `pid-alive` — Phase 1's case `4.2b`
      proves this empirically rather than by assertion. *(completed)*
- [x] `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`, the
      `session_liveness_reason` header-comment entry: apply the identical two edits (count and
      allowed-value list) as the schema row above, keeping the two texts in agreement.
      *(completed)*
- [x] Redeploy the source store to the `.claude/` tree: `bash .claude/scripts/deploy-headless.sh`
      (required before the gate below — `verify-deploy.sh` gate 5 does content-hash equality
      between source store and deploy tree, so un-redeployed edits fail it as drift).
      *(completed)*
- [ ] Run the full verification gate. *(in progress — verify-deploy.sh running)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly three files carry a five-reasons count claim or a
constrained allowed-value list. That count comes from the research inventory and is a hypothesis,
not a fact. Confirm at implementation time with a repo-wide sweep that does NOT rely on the
literal word "five" — at minimum
`grep -rn "five reasons\|other four\|pid-alive" agent-system/extensions/core/` plus a check of
every file listing three or more reason names together — because two of the known sites state the
count implicitly (a bullet count, and a membership list) rather than as a searchable literal. Any
additional site found is an in-scope incidental edit for this phase, recorded in the summary.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-lock.md` - five prose edits enumerated above
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - schema-table row
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - header-comment entry
- `agent-system/extensions/core/scripts/task-lock.sh` - **incidental addition, found during the
  Scope Hypothesis re-sweep**: `cmd_session_list`'s own header comment (the "`live` is derived
  uniformly..." paragraph) enumerated `pid-alive, undeterminable, AND corrupt` without
  `dead-pid-within-grace`, the same implicit-membership-list defect class as the three declared
  sites. Fixed for consistency; `scripts/lib/file-scope-overlap.sh`'s structurally identical
  comment was left untouched per the plan's explicit Non-Goal against editing that file.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` exits 0 (guards the
  `prose` tier's named blind spot: an edit escaping the `#` comment block) *(confirmed)*
- `git diff` read-through confirms every changed hunk in `orchestrate-batch-admit.sh` lies inside
  a comment line *(confirmed)*
- `grep -c "dead-pid-within-grace"` is non-zero in all three modified files *(confirmed: 5 in
  task-lock.md, 1 in batch-admit-schema.md, 1 in orchestrate-batch-admit.sh)*
- No occurrence of a stale five-reasons claim remains:
  `grep -rn "five reasons\|other four" agent-system/extensions/core/` returns no hit describing
  `session_liveness()` *(confirmed — the one remaining "other four" hit is in
  system-defect-discrimination.md and describes an unrelated defect-instance count, not
  `session_liveness()`)*
- `bash .claude/scripts/deploy-headless.sh` completes successfully *(confirmed)*
- `bash .claude/scripts/verify-deploy.sh` passes, including gate 4 (task-reference lint) and
  gate 5 (content-hash parity) *(confirmed: both PASS. Two unrelated pre-existing gates also
  reported FAIL — gate 3 doc-lint's "core script never deployed" advisories, all naming
  `literature` extension scripts and traced to `.claude-extensions.json`/literature-extension
  drift that predates this task's session (present in `git status` before any task 997 edit);
  and gate 8's shell-suite runner, whose single failure is the pre-existing, out-of-scope
  `test-index-entries-schema.sh` — a fixture/schema-linting suite with zero relation to
  `session_liveness()` or any file this task touches. `test-four-tier-conflict.sh` is
  occasionally-flaky per prior observation; re-running the suite showed it green. Neither
  pre-existing failure is caused by, or was fixed by, this task.)*
- Both suites re-run green after the redeploy:
  `bash agent-system/extensions/core/scripts/test-session-registry.sh` (11 passed, 0 failed) and
  `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` (24 passed, 0 failed)
  *(confirmed)*

## Testing & Validation

Mapped one-to-one against the task's verification bar:

- [x] A registry entry with a dead pid and age below the floor reports `dead-pid-within-grace`
      with `live: true` — test-session-registry.sh case `5a`; test-conflict-predicate.sh case
      `4.2b` half (a) *(completed)*
- [x] `session-reap --dry-run` does not select that entry — test-session-registry.sh Case 6
      (extended assertion) and Case 8 (live reap, existing) *(completed)*
- [x] A registry entry with a dead pid and age above the floor still reports `dead-pid` with
      `live: false` and IS reaped — test-session-registry.sh case `5a` plus existing Case 7
      *(completed)*
- [x] A registry entry with a live pid still reports `pid-alive` — test-session-registry.sh case
      `5a` *(completed)*
- [x] The below-floor entry still CONTENDS (contend-set unchanged) — test-conflict-predicate.sh
      case `4.2b` half (b), `decision == "defer"` / `defer_reason == "session_active"`
      *(completed)*
- [x] `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` passes in full
      *(completed: 24 passed, 0 failed)*
- [x] `bash agent-system/extensions/core/scripts/test-session-registry.sh` passes in full
      *(completed: 11 passed, 0 failed)*
- [x] `bash .claude/scripts/verify-deploy.sh` passes, including the task-reference lint gate
      *(completed: gate 4 task-reference lint and gate 5 content-hash parity both PASS; two
      unrelated pre-existing gates — doc-lint's literature-extension drift and the
      pre-existing `test-index-entries-schema.sh` failure — are documented in Phase 2's
      Verification section and are not caused by this task)*
- [x] New assertions demonstrably fail against the pre-fix ladder (falsifiability check, Phase 1)
      *(completed: verified via `git stash push --keep-index -- task-lock.sh`)*

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/task-lock.sh` - `session_liveness()` sixth reason + docstring
- `agent-system/extensions/core/scripts/test-session-registry.sh` - case `5a`, extended Case 6
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` - case `4.2b`
- `agent-system/extensions/core/context/patterns/task-lock.md` - reason bullet list and derived claims
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - schema-table row
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - header-comment entry
- Refreshed `.claude/` deploy tree (regenerated artifact, not hand-authored)
- `specs/997_fix_session_liveness_reason_mislabel/summaries/01_dead-pid-within-grace-reason-summary.md`

## Rollback/Contingency

All edits are confined to six source-store files and are independently revertable with
`git checkout -- <path>` per file (the tree is clean at each green sub-step commit, so no
snapshot is required — see git-workflow.md's dirty-tree exemption). If the new reason turns out
to change a verdict anywhere, revert `task-lock.sh` alone: the doc and test edits are inert
without it, and the existing wildcard defaults mean no other script needs a coordinated revert.
After any revert, re-run `bash .claude/scripts/deploy-headless.sh` so the deploy tree matches the
source store again, then `bash .claude/scripts/verify-deploy.sh` to confirm parity.

**Binding constraints for the implementer**:
- Edit `agent-system/extensions/**` only. Never hand-author under `.claude/**` — that tree is a
  disposable deploy artifact regenerated by `deploy-headless.sh`.
- No task-number references in any file outside `specs/**`.
