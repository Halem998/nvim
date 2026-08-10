# Implementation Plan: Task #1016

- **Task**: 1016 - Fix the register-bare/acquire-suffixed session-id pattern in research.md, plan.md, implement.md
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None (the reference fix in `skill-orchestrate/SKILL.md` Stage MT-4 has already landed)
- **Research Inputs**: specs/1016_fix_command_register_acquire_session_id_parity/reports/01_register-acquire-session-id-parity.md
- **Artifacts**: plans/01_register-acquire-parity-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

All three multi-task command files (`commands/research.md`, `commands/plan.md`,
`commands/implement.md`) register their batch session under the bare `$batch_session_id` but
acquire and release each per-task lock under `"${batch_session_id}_${task_num}"`. Because
`session_contention()`'s self-exclusion is an exact string match on `session_id`, the mismatch
makes each batch's own union-`file_scope` registration read as a foreign live session and refuses
every acquire in the batch. This plan unifies the lock/registry session-id across all six call
sites, corrects the inline prose in all three files that currently rationalizes the defect as
intentional, closes the downstream heartbeat gap that is specific to `implement.md`, reconciles
the contradictory passage in `context/patterns/task-lock.md`, and extends the existing
`test-conflict-predicate.sh` Group 9 static-guard coverage to the three command files.

Definition of done: no lock-touching `task-lock.sh` call in any of the three command files carries
a per-task suffix; the surrounding prose states the correct invariant; `implement.md` explicitly
threads the bare batch id into its per-task skill dispatch; `task-lock.md` no longer contains two
passages that instruct opposite things; and Group 9 fails loudly if any of this regresses.

### Research Integration

Every finding in the research report is mechanically traced, not pattern-matched, and is adopted
as-is:

- The exact defect sites are known: `research.md` lines 234/238, `plan.md` lines 241/245,
  `implement.md` lines 155/159 (acquire-retry and release respectively). A fixed-string sweep
  confirms these six are the complete set — Step 3.5's second pass in all three files refers to
  "the IDENTICAL per-task bracket" by reference and contains no literal suffixed string.
- The mechanism is `cmd_acquire()` -> `session_contention()`'s `own_sid` exact-match
  self-exclusion; `scripts/task-lock.sh` itself is correct and is NOT touched by this plan.
- The reference fix (`skill-orchestrate/SKILL.md` Stage MT-4, bare `$session_id` plus an explicit
  inline invariant comment) is ported, near-verbatim, into each command file.
- The `implement.md`-only downstream risk is resolved rather than left open: see Phase 2, which
  fixes it at the one place the value actually originates — the per-task skill dispatch args.
- The `task-lock.md` doc tension is reconciled in Phase 3 rather than deferred.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and `roadmap_flag` is absent, so no
roadmap consultation was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Make the `session_id` presented to `task-lock.sh acquire-retry`/`release` byte-identical to the
  one presented to `session-register` in all three multi-task command files.
- Replace the inline prose that defends the suffixed pattern with prose stating the real
  invariant and the failure mode it prevents.
- Make explicit, in `implement.md`, which `session_id` value is threaded into the per-task
  implementation-skill dispatch, so `general-implementation-agent.md` Stage 4D's dual heartbeat
  (task-lock + session-registry) resolves against live, matching records.
- Reconcile `context/patterns/task-lock.md`'s "Same-session bypass" bullet with its
  "Register/acquire parity invariant" paragraph.
- Extend `scripts/test-conflict-predicate.sh` Group 9 with sibling static guards covering the
  three command files.

**Non-Goals**:
- Any change to `scripts/task-lock.sh` or `scripts/lib/file-scope-overlap.sh` — both are correct;
  the defect is entirely in caller argument construction.
- Any new test harness, new test file, or new fixture. Group 9's existing dynamic cases (9.1-9.4)
  already prove the underlying CLI behavior generically and are not modified.
- Changing per-task-unique identifiers that are NOT lock/registry keys (e.g. `.return-meta.json`
  provenance, commit trailers, `skill_preflight_update`'s bookkeeping id in
  `skill-orchestrate/SKILL.md`). Those stay suffixed by design.
- Any edit under `.claude/**`. That tree is a disposable deploy artifact; all edits target
  `agent-system/extensions/core/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A blanket search-and-replace touches a suffixed id that is legitimately per-task | M | L | Phase 1 edits only the two enumerated lock-family call sites per file; a fixed-string sweep before and after confirms the exact occurrence set (see Phase 1 Scope Hypothesis) |
| Code fixed but prose left contradicting it, re-teaching the defect to the next reader | M | M | The prose rewrite is inside the same phase as the call-site fix, not a follow-up; Phase 1 does not close until both are done in all three files |
| `implement.md`'s downstream gap gets "fixed" in the wrong layer (editing the agent instead of the caller that owns the value) | M | M | Phase 2 fixes it at the dispatch args in `implement.md`, mirroring the single-task path's existing `session_id={SESSION_ID}` arg shape; the agent's Stage 4D is left unchanged |
| New Group 9 guards are vacuous (grep never triggers), passing regardless of regression | H | L | Phase 4 includes a negative-control check against a scratch copy carrying the bad string before accepting the guards |
| Edits land in the source store but the running system still reads the stale deployed tree | M | M | Phase 5 records explicitly that the fix reaches `.claude/**` only via the normal deploy/reload; the implementer must NOT hand-edit the deployed tree to shortcut this |
| New prose accidentally cites a task number in a deliverable outside `specs/**` | L | M | Phase 5 runs `check-task-references.sh`; all new prose references durable anchors (file + section names) only |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Unify the lock/registry session-id in all three command files [COMPLETED]

**Goal**: Every `task-lock.sh` lock-family call in the three multi-task command files presents the
same bare `$batch_session_id` the batch registered, and the surrounding prose states why.

**Tasks**:
- [x] Confirm the occurrence set first: `grep -rnF '${batch_session_id}_${task_num}' agent-system/extensions/core/` — expect exactly six hits, two per command file (`acquire-retry`, `release`). Record the actual count; if it differs from six, stop and reconcile before editing. *(completed: confirmed exactly 6 hits, 2 per file)*
- [x] In `agent-system/extensions/core/commands/research.md` Step 3: change the `acquire-retry` argument (line ~234) and the `release` argument (line ~238) from `"${batch_session_id}_${task_num}"` to `"$batch_session_id"`. *(completed)*
- [x] In `agent-system/extensions/core/commands/plan.md` Step 3: same change at lines ~241 and ~245. *(completed)*
- [x] In `agent-system/extensions/core/commands/implement.md` Step 3: same change at lines ~155 and ~159. *(completed)*
- [x] In each of the three files, add an inline invariant note immediately after the `acquire-retry` bullet, ported from `skill-orchestrate/SKILL.md` Stage MT-4's already-landed comment. Suggested wording (identical in all three, varying only the command name): *"**Invariant**: the bare `$batch_session_id` is used here deliberately — it MUST be byte-identical to the value Step 2 passed to `session-register` and Step 2.5 passed as `--session-id`, because `session_contention()`'s self-exclusion is an exact string match on `session_id`. A per-task-suffixed value (`${batch_session_id}_${task_num}`) would make this batch's own union-`file_scope` registration read as a foreign live session and refuse every lock acquire in the batch against its own registration. See `.claude/context/patterns/task-lock.md`'s 'Register/acquire parity invariant'."* *(completed)*
- [x] In each of the three files, rewrite the Step 2 rationalization sentence (`research.md` ~158-161, `plan.md` ~165-168, `implement.md` ~82-85). Delete the clause "Step 3 below suffixes the same variable per-task for its own task-lock acquire/release calls; the registry entry is batch-scoped, not per-task, so it stays keyed on the unsuffixed value" and replace it with: *"Step 3 below uses this SAME bare value for every per-task `acquire-retry`/`release` call — register and acquire must present byte-identical session ids or the batch contends against its own registration."* Keep the surrounding "Use the bare `batch_session_id` here" bolded sentence and the "best-effort and non-blocking" clause intact. *(completed)*
- [x] Re-run the fixed-string sweep; expect zero hits across the whole source store. *(completed: the naive flat `grep -rnF` now shows 3 hits, one per file — these are the newly-added invariant notes' own descriptive mention of the bad pattern as an illustrative example, exactly mirroring `skill-orchestrate/SKILL.md`'s own reference invariant note at its line 1966, which contains the identical self-referential mention and is not itself a lock-family call site. The actual guard — `grep -nE 'task-lock\.sh[[:space:]]+(acquire|release|heartbeat)' | grep -F '...'`, i.e. Group 9's real mechanism — correctly returns zero for all three files since the invariant-note lines never match the ERE for an actual `task-lock.sh acquire/release/heartbeat` call line. Confirmed directly: `grep -nF 'task-lock.sh acquire-retry'` and `grep -nF 'task-lock.sh release'` across all three files show only the bare `"$batch_session_id"` form.)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The suffixed pattern occurs exactly six times, twice per command file, and
all six are lock-family calls (`acquire-retry`, `release`). Confirm at implementation time with
`grep -rnF '${batch_session_id}_${task_num}' agent-system/extensions/core/` before the first edit
and again after the last; the before-count must be 6 and the after-count 0. If the before-count is
not 6, enumerate the extra sites and classify each as lock-family (fix) or non-lock-family (leave,
and record why) before proceeding.

**Files to modify**:
- `agent-system/extensions/core/commands/research.md` - Step 2 prose; Step 3 acquire-retry/release args + invariant note
- `agent-system/extensions/core/commands/plan.md` - same
- `agent-system/extensions/core/commands/implement.md` - same

**Verification**:
- `grep -rnF '${batch_session_id}_${task_num}' agent-system/extensions/core/` returns nothing.
- `grep -nF 'task-lock.sh acquire-retry' agent-system/extensions/core/commands/{research,plan,implement}.md` shows `"$batch_session_id"` in every hit; same for `release`.
- The phrase "suffixes the same variable per-task" no longer appears in any of the three files.
- Each of the three files contains exactly one new invariant note naming `session_contention()`.

---

### Phase 2: Close the downstream heartbeat gap in implement.md [NOT STARTED]

**Goal**: `implement.md`'s multi-task Step 3 states explicitly which `session_id` it passes to each
per-task implementation skill, and that value is the bare `$batch_session_id`, so
`general-implementation-agent.md` Stage 4D's two heartbeat calls both land on live, matching
records.

**Resolution decided here (do not re-open)**: the fix belongs in the caller that owns the value.
`implement.md`'s single-task path already passes `session_id={SESSION_ID}` in its Skill args
(`commands/implement.md`, the "Invoke the Skill tool NOW" block); the multi-task loop currently
says nothing, so the dispatched skill supplies its own unrelated id and both Stage 4D heartbeats
degrade to silent no-ops. The multi-task loop must pass the bare batch id in the same arg shape.
`general-implementation-agent.md` Stage 4D is NOT edited — its single `{session_id}` context value
becomes correct once the caller threads the right value in.

**Tasks**:
- [ ] In `agent-system/extensions/core/commands/implement.md` Step 3, add an explicit dispatch-args bullet directly after the `acquire-retry` bullet: *"Invoke each task's implementation skill with `session_id={batch_session_id}` — the bare batch id, byte-identical to the value used for `session-register` (Step 2), the batch-admission `--session-id` (Step 2.5), and this loop's `acquire-retry`/`release`. This mirrors the single-task path's `session_id={SESSION_ID}` arg shape."*
- [ ] Add a short rationale note beneath it: *"This is what makes `general-implementation-agent.md`'s Stage 4D dual heartbeat resolve — `task-lock.sh heartbeat` matches the per-task lock holder written by this loop's `acquire-retry`, and `task-lock.sh session-heartbeat` matches the batch registry entry written by Step 2. Any per-task-unique identifier needed downstream (`.return-meta.json` provenance, commit trailers) must be a separate field, never this one."*
- [ ] Confirm the existing "No intra-batch session-registry heartbeat" note in Step 3 remains accurate and does not now read as contradicting the new bullet; if it does, add a one-clause caveat that the omission concerns the command-level loop only, while the per-phase heartbeat lives one layer down in the agent.
- [ ] Read `agent-system/extensions/core/skills/skill-implementer/SKILL.md` Stage 4 ("Prepare Delegation Context"). Its `session_id` field is written as the literal template `"sess_{timestamp}_{random}"`. Decide by inspection: if the surrounding text already makes clear this is the session_id received from the caller, leave it alone and record that finding; if it reads as an instruction to generate a fresh id, add a one-line clarification — *"`session_id` is the value received in this skill's args, passed through verbatim; never regenerated here."* — and nothing more. Do not restructure the stage.
- [ ] Apply the same one-line clarification to `skill-team-implement` only if `implement.md`'s `--team` multi-task branch also dispatches without a `session_id` arg; otherwise skip and record why.

**Timing**: 40 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase touches at most two files — `commands/implement.md` (certain) and
`skills/skill-implementer/SKILL.md` (conditional, one line). Confirm at implementation time by
reading `skill-implementer/SKILL.md` Stage 4 before editing; if no clarification is warranted,
record that as a reasoned exclusion rather than editing to satisfy the estimate.

**Files to modify**:
- `agent-system/extensions/core/commands/implement.md` - Step 3 dispatch-args bullet + rationale
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` - conditional one-line clarification

**Verification**:
- `grep -nF 'session_id={batch_session_id}' agent-system/extensions/core/commands/implement.md` returns the new bullet.
- The new text names both `heartbeat` and `session-heartbeat` and attributes them to Stage 4D.
- No edit was made to `agents/general-implementation-agent.md` (`git diff --name-only` confirms).

---

### Phase 3: Reconcile the contradictory passages in task-lock.md [NOT STARTED]

**Goal**: `context/patterns/task-lock.md` no longer contains one passage instructing per-task
suffixing and another forbidding it, and a reader arriving at either passage is routed to the
other.

**Tasks**:
- [ ] Rewrite the "Same-session bypass" bullet in the "Cross-Task `file_scope` Overlap Check" section. Its current second half — "Multi-task dispatch sessions are suffixed per-task (`sess_..._${task_num}`) and are therefore distinct sessions for this purpose — they ARE enforced against each other" — is now factually wrong and must be replaced with the reconciliation: multi-task dispatch batches share ONE bare `session_id` across every per-task acquire (required by the parity invariant), so a same-batch sibling's held lock IS bypassed by this rule; that is not a hole, because in-batch `file_scope` collisions are detected and deferred earlier by the batch-admission pre-check (`orchestrate-batch-admit.sh`, Step 2.5 of each multi-task command, which reports `defer_reason: file_scope_collision` with `collision_scope: in_batch`) before the acquire loop ever runs.
- [ ] Add a forward cross-reference from that bullet to the "Register/acquire parity invariant" paragraph (Consumers item 2), and a matching back-reference from the parity paragraph to the "Cross-Task `file_scope` Overlap Check" section, so neither can be read in isolation to the wrong conclusion again.
- [ ] While in Consumers item 2: its heartbeat-wiring sentence names "`skill-implementer/SKILL.md`'s phase-transition point", but item 5 of the same list states that `skill-implementer/SKILL.md` has no such point and that the heartbeat lives in `agents/general-implementation-agent.md`'s Stage 4D. Correct item 2 to match item 5. This is a one-sentence pointer fix in the same paragraph family, not a scope expansion.
- [ ] Verify no task numbers were introduced; cite file and section names only.

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: Exactly two passages in `task-lock.md` are in conflict (the "Same-session
bypass" bullet and the "Register/acquire parity invariant" paragraph), plus one stale pointer in
Consumers item 2. Confirm at implementation time with
`grep -n 'suffixed per-task\|Register/acquire parity\|phase-transition point' agent-system/extensions/core/context/patterns/task-lock.md`;
if the grep surfaces additional conflicting passages, enumerate them and extend this phase rather
than leaving them.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-lock.md` - Cross-Task section bullet; Consumers item 2 cross-reference and heartbeat pointer

**Verification**:
- `grep -n 'they ARE enforced against each other' agent-system/extensions/core/context/patterns/task-lock.md` returns nothing.
- The Cross-Task section names `orchestrate-batch-admit.sh` and the in-batch defer path.
- Both passages cross-reference each other by section name.
- Every section name cited in the new text exists in the file (check each anchor by grep).

---

### Phase 4: Extend test-conflict-predicate.sh Group 9 with sibling static guards [NOT STARTED]

**Goal**: Group 9 fails loudly if any of the three command files ever reintroduces a
per-task-suffixed session id on a lock-touching call.

**Tasks**:
- [ ] In `agent-system/extensions/core/scripts/test-conflict-predicate.sh`, add cases 9.6, 9.7, 9.8 immediately after case 9.5, as three explicit sibling blocks copying 9.5's structure line for line.
- [ ] Vary only two things per block: the file path (`$SCRIPT_DIR/../commands/research.md`, `.../plan.md`, `.../implement.md`) and the `grep -F` bad-pattern substring (`${batch_session_id}_${task_num}` instead of `${session_id}_${task_num}`). Keep 9.5's ERE (`task-lock\.sh[[:space:]]+(acquire|release|heartbeat)`) verbatim — it matches `acquire-retry` by prefix, which is intended.
- [ ] Keep 9.5's info-and-skip branch verbatim for unreachable files (the `SCRIPT_DIR` ambiguity stance Group 8 established); a missing file must never fail the suite.
- [ ] Extend the Group 9 header comment with one sentence noting that the group now covers both the orchestrate skill and the three multi-task command files.
- [ ] Negative control: copy one command file to the scratch directory, reinsert the bad substring into an `acquire-retry` line, and run the new grep expression against that copy to confirm it triggers. Do not mutate anything in the repo to do this.
- [ ] Do not touch cases 9.1-9.4 or add fixtures.

**Timing**: 45 minutes

**Depends on**: 1, 2

**Verification Tier**: local

**Scope Hypothesis**: Three new cases (9.6-9.8), one per command file, and one header-comment
sentence — no other change to the file. Confirm at implementation time with
`git diff --stat agent-system/extensions/core/scripts/test-conflict-predicate.sh` (expect additions
only, clustered after case 9.5) and by re-reading cases 9.1-9.5 to confirm they are byte-unchanged.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` - Group 9: cases 9.6-9.8, header comment

**Verification**:
- `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` runs to completion; 9.6, 9.7, 9.8 each report PASS (or a named SKIP if a file is genuinely unreachable from that invocation).
- No previously passing case regresses to FAIL.
- The negative-control run against the scratch copy reports the guard triggering.

---

### Phase 5: Full verification and gate sweep [NOT STARTED]

**Goal**: The complete change set passes the repository's own gates, and the deploy boundary is
respected and documented.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` in full and record the summary counts.
- [ ] Run `bash .claude/scripts/check-task-references.sh` (repo-wide lint gate) and confirm zero new findings from the edited files.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and confirm no new failures attributable to this change.
- [ ] Run `bash .claude/scripts/lint/lint-routing-wiring.sh` and `bash .claude/scripts/lint/lint-agent-contracts.sh` as a regression sweep; both should be unaffected.
- [ ] Confirm `git status --short` shows changes ONLY under `agent-system/extensions/core/**` and `specs/**` — no `.claude/**` path appears. If any does, revert it; the deployed tree is regenerated, never hand-edited.
- [ ] Cross-check the final state against the reference: `grep -n 'task-lock.sh acquire' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and the three command files now show the same bare-id shape and the same class of inline invariant note.
- [ ] Record in the implementation summary that the fix becomes live in `.claude/**` only after the next deploy/reload, and that this plan deliberately does not perform or simulate that deploy.

**Timing**: 30 minutes

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Files to modify**:
- None (verification only; summary artifact is written by the implementer's normal postflight)

**Verification**:
- All gate commands above exit zero, or any non-zero exit is demonstrably pre-existing (confirmed by running the same gate on a clean checkout of the same file set).
- `git status --short` contains no `.claude/` path.

---

## Testing & Validation

- [ ] `grep -rnF '${batch_session_id}_${task_num}' agent-system/extensions/core/` returns zero hits.
- [ ] All six lock-family call sites in the three command files present `"$batch_session_id"`.
- [ ] `commands/implement.md` Step 3 names the `session_id` it dispatches with, and it is the bare batch id.
- [ ] `context/patterns/task-lock.md` contains no passage instructing per-task suffixing for lock/registry calls, and its two relevant sections cross-reference each other.
- [ ] `test-conflict-predicate.sh` passes, including new cases 9.6-9.8, with cases 9.1-9.5 unchanged.
- [ ] The new guards are proven non-vacuous by the Phase 4 negative control.
- [ ] `check-task-references.sh` reports no new findings.
- [ ] No file under `.claude/**` was modified.

## Artifacts & Outputs

- `agent-system/extensions/core/commands/research.md` (modified)
- `agent-system/extensions/core/commands/plan.md` (modified)
- `agent-system/extensions/core/commands/implement.md` (modified)
- `agent-system/extensions/core/context/patterns/task-lock.md` (modified)
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` (modified)
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` (conditionally modified, one line)
- `specs/1016_fix_command_register_acquire_session_id_parity/summaries/01_register-acquire-parity-fix-summary.md`

## Rollback/Contingency

Every change is a text edit to markdown or a shell test script, with no data migration and no
state mutation. Each phase commits separately per the commit-per-green-substep mandate, so
reverting is `git revert` of the offending phase commit.

Contingency by phase:
- If Phase 1's before-count is not 6, stop and reconcile the occurrence set before any edit — an
  unexpected site means the research's audit was incomplete and a blanket replace would be unsafe.
- If Phase 2's inspection shows `skill-implementer/SKILL.md` already threads the received
  `session_id` correctly, record it as a reasoned exclusion; do not edit to match the estimate.
- If Phase 4's negative control shows the guard does not trigger, the guard is wrong, not the
  control — fix the grep expression before accepting the phase.
- If a gate in Phase 5 fails for a reason predating this change, record it as pre-existing with
  the evidence rather than expanding scope to fix it.
