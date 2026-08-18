# Implementation Plan: Task #17

- **Task**: 17 - fix_return_meta_lifecycle_ordering
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: specs/017_fix_return_meta_lifecycle_ordering/reports/01_return-meta-lifecycle-ordering.md
- **Artifacts**: plans/01_return-meta-lifecycle-ordering.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`skill_cleanup()` deletes `.return-meta.json` at the skill's own Stage 9, which always runs
before the calling command's `command-gate-out.sh` (CHECKPOINT 2) ever opens the file. The whole
body of `command-gate-out.sh` past its "not found" early-exit — defensive status correction and
`skill_validate_task_artifacts` — is therefore structurally unreachable, and its warning fires
identically on every successful run and every genuine crash. This plan implements the research
report's recommended direction (b) refined: `skill_cleanup` stops deleting the file, deletion
moves to each calling command's own true last step, the gate-out warning becomes a truthful
failure signal, and both currently-dead gate-out mechanisms are retained rather than removed.

### Research Integration

The research report is the authoritative input and its Decisions section supplies the per-file
change list this plan phases. Findings carried directly into the plan:

- The defect is confirmed exactly as described; `skill_cleanup` (`scripts/skill-base.sh`) is the
  single shared deletion site reached by all eleven effective callers (the nine skills that call
  it literally, plus `skill-researcher` and `skill-researcher-hard`, which reach the identical
  call through their `skill-postflight-flow.md` import rather than a literal call line).
- `/orchestrate` is **not** broken by this mechanism: `skill-orchestrate` never calls
  `skill_cleanup` and its Stage 8 merges onto `.return-meta.json` instead of deleting it. The fix
  must not regress it — in particular `command-gate-out.sh` must not become the deleter.
- Blast radius extends past gate-out into command-level CHECKPOINT 3 commit stages.
  `research.md`'s CHECKPOINT 3 is the *sole* commit site for a standalone `/research` run
  (`skill-researcher` commits nothing of its own), and its multi-pathspec `git add` fails
  atomically when `.return-meta.json` is absent — staging nothing at all, not even the report.
  Fixing the file's lifetime therefore also repairs a silent total-commit-loss bug.
- Defensive status correction and `skill_validate_task_artifacts` are both retained, with the
  report's reasoning recorded: the correction is a genuinely independent second reader guarding a
  non-`set -e` Stage 7 call, and the validation sweep is whole-directory, strictly broader than
  each skill's own single-artifact Stage 6a check.

Two extensions this plan adds beyond the report's enumerated change list, both verified against
the source store during planning:

1. **Multi-task loop deletion sites.** `research.md`, `plan.md`, and `implement.md` each contain
   a multi-task batch loop (Step 3/Step 4) that dispatches skills but deliberately bypasses
   `command-gate-in.sh`/`command-gate-out.sh` and never reaches CHECKPOINT 3. Once
   `skill_cleanup` stops deleting, those paths have no deleter at all and would leak one
   `.return-meta.json` per task per batch. Phase 4 closes this.
2. **`/orchestrate` deletes only on the completion outcome.** `orchestrate.md`'s CHECKPOINT 3
   also runs on the paused/partial outcome of a still-running orchestration; deleting the file
   there would discard the outcome record that `orchestrate-stage5-gates.sh` recovers from on the
   next invocation. Phase 3 scopes the deletion to the completion branch only. (Lingering files
   are independently safe for that recovery path, which gates on an mtime freshness window
   against `dispatch_start_ts` — a stale file is ignored, never mistaken for a fresh outcome.)

### Prior Plan Reference

No prior plan. A previous planner dispatch for this task was interrupted by a connection error
before writing any artifact; the `plans/` directory did not exist at the start of this dispatch.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no ROADMAP.md was consulted.

## Goals & Non-Goals

**Goals**:
- Make `command-gate-out.sh`'s defensive status correction and `skill_validate_task_artifacts`
  sweep reachable on the success path of all five commands that call it.
- Repair `research.md`'s CHECKPOINT 3 atomic `git add` failure so a standalone `/research` run
  actually commits its report, `TODO.md`, and `state.json`.
- Make the "not found" message a truthful, diagnostic failure signal rather than a message that
  fires identically on every run.
- Give `.return-meta.json` exactly one deletion site per execution path, with no path left
  leaking the file indefinitely.
- Leave `/orchestrate`'s currently-working behavior unchanged, including its resume path.
- Update every doc that describes the old lifecycle so the ambiguity that produced this defect is
  not re-seeded.

**Non-Goals**:
- Deleting the defensive status correction or `skill_validate_task_artifacts` (explicitly
  rejected by the research; both are retained).
- Reviving the orphaned `orchestrator-postflight.sh` (zero live call sites; noted by the research
  as a possible future cleanup, out of scope here).
- Changing `.return-meta.json`'s git-tracked "durable provenance" disposition, its schema, or its
  writers.
- Restructuring the DELEGATE-before-GATE-OUT command shape (no seam exists to intervene mid-skill).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A deletion site is missed, leaving `.return-meta.json` lingering and later surfacing as a stray diff | M | M | Phase 6 runs an exhaustive sweep: every `skill_cleanup` call site, every `command-gate-out.sh` call site, and every multi-task loop must map to exactly one deletion owner |
| `/orchestrate`'s resume path loses its outcome-recovery fallback if CHECKPOINT 3 deletes on the paused outcome | H | M | Phase 3 scopes orchestrate's deletion to the completion branch only; the partial/paused branch keeps the file |
| `implement.md`/`plan.md` CHECKPOINT 3 blocks become genuinely reachable and start staging work they previously skipped, on top of what the skill already committed inline | M | M | Expected to be idempotent (nothing new to stage the second time); Phase 6 spot-checks with a real run rather than assuming |
| Edits land in `.claude/**` instead of the source store and are wiped by the next regeneration | H | M | Binding constraint restated in every phase; Phase 6 asserts `git status` shows changes only under `agent-system/extensions/core/**` and `specs/**` |
| Phases 3 and 4 touch the same three command files and conflict if run in parallel | M | M | Wave map serializes them (Phase 4 depends on Phase 3) |
| Docs describing the old three-file `skill_cleanup` removal list go stale and re-seed the confusion | M | H | Phase 5 updates all of them in the same pass, including the new per-command reader table the research recommended |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 1, 2, 3, 4 |
| 5 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

**Binding constraint for every phase**: all edits go to `agent-system/extensions/core/**`. Never
write to `.claude/**` — it is a gitignored, disposable deploy artifact regenerated from the
source store (see `.claude/rules/source-store-deploy-boundary.md`). No edit in any phase may
embed a task number in a deliverable file (see
`.claude/rules/no-task-references-in-deliverables.md`); cite durable anchors instead.

---

### Phase 1: Stop `skill_cleanup` deleting `.return-meta.json` [COMPLETED]

**Goal**: Remove the single shared deletion that makes gate-out's body unreachable, and give
`skill-spawn` — the one caller with no downstream consumer — its own inline deletion so the file
does not accumulate for that path.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/skill-base.sh`, edit `skill_cleanup()` to `rm -f`
      only `.postflight-pending` and `.postflight-loop-guard`; drop the `.return-meta.json`
      pathspec. *(completed)*
- [x] Update the function's own header comment block (which currently enumerates all three files)
      to state the new two-file removal list and to name the calling command as the owner of
      `.return-meta.json`'s deletion. *(completed)*
- [x] In `agent-system/extensions/core/skills/skill-spawn/SKILL.md` Stage 16, add
      `rm -f "specs/${padded_num}_${project_name}/.return-meta.json"` immediately after the
      `skill_cleanup` call, alongside the existing `.spawn-return.json` removal, with a one-line
      comment explaining that `/spawn` has no `command-gate-out.sh` consumer so the skill owns
      this deletion itself. *(completed)*
- [x] Confirm no other `skill_cleanup` caller needs a compensating inline `rm` (every other
      caller's command reaches either a CHECKPOINT 3 or a gate-out that Phase 3 gives a deleter).
      *(completed: confirmed 9 literal callers + 2 skill-postflight-flow importers = 11, matching
      research; only skill-spawn has no downstream command consumer)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The research asserts eleven effective `skill_cleanup` callers — nine
literal (`skill-implementer`, `skill-implementer-hard`, `skill-planner`, `skill-planner-hard`,
`skill-reviser`, `skill-spawn`, `skill-team-implement`, `skill-team-plan`, `skill-team-research`)
plus `skill-researcher` and `skill-researcher-hard` reaching it through the
`skill-postflight-flow.md` import. Confirm at implementation time with
`grep -rn 'skill_cleanup' agent-system/extensions/core/skills/` **and** a second grep for
`skill-postflight-flow` importers, since the two researcher skills do not appear in the first
grep. If the count differs, reconcile before proceeding — an unlisted caller means an unowned
deletion.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - `skill_cleanup()` body and header comment
- `agent-system/extensions/core/skills/skill-spawn/SKILL.md` - Stage 16 inline `rm -f`

**Verification**:
- `grep -n 'return-meta' agent-system/extensions/core/scripts/skill-base.sh` shows no `rm -f`
  of the file inside `skill_cleanup`.
- `bash -n agent-system/extensions/core/scripts/skill-base.sh` parses clean.
- `skill-spawn`'s Stage 16 block contains both `rm -f` lines.

---

### Phase 2: Truthful gate-out warning; retain both mechanisms [COMPLETED]

**Goal**: Make `command-gate-out.sh`'s missing-metadata branch an accurate diagnostic now that
absence is a real signal, without adding any deletion to this script.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/command-gate-out.sh`, rewrite the "not found"
      message to name the real cause and the real consequence — that the skill completed without
      writing return metadata (crash before postflight, or a Stage 0 contract bug), and that
      defensive status correction and artifact validation cannot run for this dispatch.
      *(completed)*
- [x] Keep the branch non-blocking (`exit 0`), matching the script's existing non-fatal posture
      toward its callers. *(completed)*
- [x] Leave the defensive correction block and the `skill_validate_task_artifacts` call unchanged
      in substance. *(completed)*
- [x] Add a short comment above the branch recording *why* absence is now meaningful (the skill
      no longer deletes the file; the calling command deletes it after this script runs) so a
      future reader does not restore the old assumption. *(completed)*
- [x] Add a comment at the end of the script explicitly stating that this script must NOT delete
      `.return-meta.json`, naming the two reasons: it would regress `/orchestrate`'s CHECKPOINT 3,
      and it would not help `research.md`/`plan.md`'s CHECKPOINT 3, which run afterward.
      *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/scripts/command-gate-out.sh` - missing-metadata message, two
  explanatory comments

**Verification**:
- `bash -n agent-system/extensions/core/scripts/command-gate-out.sh` parses clean.
- The script contains no `rm` of `.return-meta.json`.
- The new message text distinguishes a genuine failure from a normal run.

---

### Phase 3: Per-command deletion sites (single-task paths) [COMPLETED]

**Goal**: Give each of the five commands exactly one deletion of `.return-meta.json`, positioned
after the last of its own steps that consumes the file.

**Tasks**:
- [x] `commands/research.md` CHECKPOINT 3: add `rm -f
      "specs/${padded_num}_${project_name}/.return-meta.json"` as the final line of the commit
      block, after `git commit`. Note in a comment that the preceding `git add` lists this file
      explicitly and fails atomically if it is absent — which is precisely the bug being fixed.
      *(completed)*
- [x] `commands/plan.md` CHECKPOINT 3: add the same deletion as the final line, after
      `git commit` (its `git add "${task_dir}/"` includes the file recursively). *(completed)*
- [x] `commands/implement.md` CHECKPOINT 3: add the same deletion after the `git commit` on both
      the completion and partial branches — the `modified_files` read at the top of the block
      still needs the file present. *(completed)*
- [x] `commands/orchestrate.md` CHECKPOINT 3: add the deletion **only** on the completion branch,
      after the `git-commit-scoped.sh` call. Add a comment stating that the partial/paused branch
      deliberately keeps the file so the next invocation's Stage 5 outcome recovery
      (`orchestrate-stage5-gates.sh`, freshness-windowed against `dispatch_start_ts`) still has
      its fallback. *(completed)*
- [x] `commands/revise.md`: add the deletion immediately after the `command-gate-out.sh` call and
      after the revise-specific plan-file existence check, since `/revise` has no CHECKPOINT 3.
      *(completed)*
- [x] In each site, make the deletion non-blocking and unconditional on commit success
      (commit failure is already non-blocking in all five commands). *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly five single-task deletion sites across five
command files. Confirm at implementation time with
`grep -rn 'command-gate-out.sh' agent-system/extensions/core/commands/` — every command that
calls gate-out must end up with a deletion owner, and no command outside that set may acquire
one. If a sixth caller appears, it needs a site too.

**Files to modify**:
- `agent-system/extensions/core/commands/research.md` - CHECKPOINT 3 final line
- `agent-system/extensions/core/commands/plan.md` - CHECKPOINT 3 final line
- `agent-system/extensions/core/commands/implement.md` - CHECKPOINT 3, both commit branches
- `agent-system/extensions/core/commands/orchestrate.md` - CHECKPOINT 3, completion branch only
- `agent-system/extensions/core/commands/revise.md` - after GATE OUT

**Verification**:
- Each of the five files contains exactly one `.return-meta.json` deletion region.
- `orchestrate.md`'s partial branch demonstrably has no deletion.
- In each file, the deletion appears textually after every read of the file in that command.

---

### Phase 4: Multi-task batch loop deletion sites [COMPLETED]

**Goal**: Close the leak on the three multi-task batch loops, which bypass gate-out and
CHECKPOINT 3 entirely and would otherwise have no deleter at all.

**Tasks**:
- [x] `commands/research.md` Step 4 (Batch Git Commit): after the batch commit, delete
      `.return-meta.json` for each task in the batch, iterating the same task list the batch
      dispatched. Non-blocking. *(completed)*
- [x] `commands/plan.md` Step 4 (Batch Git Commit): same addition. *(completed)*
- [x] `commands/implement.md` Step 4 (Batch Git Commit and Consolidated Output): same addition.
      *(completed)*
- [x] In each, add a one-line note that this loop deliberately bypasses
      `command-gate-in.sh`/`command-gate-out.sh`, so the batch step — not gate-out and not the
      skill — owns the deletion for these paths. *(completed)*
- [x] Ensure the deletion runs after the batch commit, so the file is still staged as durable
      provenance by that commit. *(completed)*
- [x] **Investigation: `orchestrate.md`'s own multi-task batch.** Recorded as explicitly out of
      scope, per the Scope Hypothesis instruction below. Reason: `commands/orchestrate.md`'s
      multi-task path delegates its entire wave-by-wave dispatch to a single `skill-orchestrate`
      invocation, which dispatches directly to `research_agents[task_num]`/`planner-agent`/
      `implement_agents[task_num]` via the Agent tool (Stage MT-4) — bypassing the skill layer
      (`skill-implementer`, etc.) entirely, so `skill_cleanup` was never called on this path
      either before or after this plan's Phase 1 change; Phase 1 is a no-op here. Grepping
      `skill-orchestrate/SKILL.md` for `rm -f`/`rm "` (3 hits, all `$loop_guard_file` or
      `.drift-inspection.json`) confirms per-task `.return-meta.json` is never deleted anywhere
      in the MT lifecycle-cycling loop — it is read repeatedly for outcome recovery
      (`orchestrate-recover-outcome.sh`, gated on `window_start`/`dispatch_start_ts` freshness,
      the same mtime-freshness mechanism Phase 3 relies on for the single-task completion-only
      scoping) across however many cycles a task's dispatch spans. Adding a deletion site here
      would risk exactly the regression the binding constraint prohibits: a task recovered via
      return-meta fallback on cycle N+1 would lose that fallback if cycle N deleted the file.
      This is pre-existing behavior, unrelated to the defect this plan fixes, and is left
      unchanged.

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly three multi-task loops needing a deletion site.
Confirm at implementation time by grepping the command files for the multi-task bypass note
(`bypasses .command-gate-in.sh./.command-gate-out.sh.`) and checking each hit reaches a Step 4
batch-commit block. `revise.md` and `orchestrate.md`'s single-task path are expected not to
appear; `orchestrate.md`'s own multi-task batch (`specs/.orchestrator-multi-state-*`) must be
inspected and either given a site or explicitly recorded as out of scope with its reason.

**Files to modify**:
- `agent-system/extensions/core/commands/research.md` - Step 4 batch commit
- `agent-system/extensions/core/commands/plan.md` - Step 4 batch commit
- `agent-system/extensions/core/commands/implement.md` - Step 4 batch commit

**Verification**:
- Every multi-task loop has a deletion after its batch commit.
- No single-task CHECKPOINT 3 deletion was duplicated or displaced by these edits.

---

### Phase 5: Documentation and lifecycle-record updates [COMPLETED]

**Goal**: Update every doc that describes the old lifecycle, and add the per-command reader table
the research identified as the missing artifact that let this defect's blast radius go
undiscovered.

**Tasks**:
- [x] `context/patterns/skill-postflight-flow.md` Stage 9: change the "Removes
      `.postflight-pending`, `.postflight-loop-guard`, and `.return-meta.json`" sentence to the
      new two-file list, and state that `.return-meta.json` is now deleted by the calling command
      after its own last consumer. *(completed)*
- [x] Same file, the "Ordering" section: update the rationale sentence about not deleting
      `.return-meta.json` before every stage that reads it — the constraint now extends past the
      skill boundary into the calling command. *(completed)*
- [x] Same file: add the recommended reader table listing, per command, every consumer of
      `.return-meta.json` downstream of DELEGATE (gate-out's defensive correction and artifact
      sweep; each command's CHECKPOINT 3; each multi-task Step 4) and which step owns the
      deletion. Reference sites by file and section name, never by line number. *(completed)*
- [x] `context/standards/orchestrator-runtime-files.md`: update the `.return-meta.json` row's
      "Cleanup site" cell to name the calling command's own last step instead of `skill_cleanup()`,
      and keep the `orchestrator-postflight.sh` Stage 10 mention correctly scoped to that
      (orphaned) script. *(completed)*
- [x] `context/patterns/skill-lifecycle.md`: check its Stage 9/Stage 10 cleanup descriptions and
      update any that enumerate `.return-meta.json`. *(completed: no enumeration found — this
      file describes skill_cleanup() generically without naming files, so no edit was needed)*
- [x] `context/standards/postflight-tool-restrictions.md`: check and update its `skill_cleanup()`
      one-line description if it enumerates the removed files. *(completed)*
- [x] Record the retention decisions (defensive correction kept; artifact validation kept) and
      their reasoning in the gate-out-adjacent documentation, so a future reader encountering the
      now-live code does not re-propose deleting it. *(completed: added a "Why command-gate-out.sh's
      two mechanisms are retained, not removed" subsection to
      context/patterns/skill-postflight-flow.md, immediately after the reader table)*
- [x] **Extra finding beyond the enumerated list**: `context/patterns/file-metadata-exchange.md`'s
      "Cleanup Patterns" section presented "remove metadata file after postflight completes" as
      the sanctioned pattern — directly restating the pre-fix assumption. Updated with an
      ownership note and retitled the first pattern to "After the Calling Command's Last
      Consumer". *(completed)*

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts four to six doc files carry stale descriptions. Confirm
at implementation time with `grep -rn 'return-meta' agent-system/extensions/core/context/` and
`grep -rn 'skill_cleanup' agent-system/extensions/core/context/`; every hit that describes the
deletion must be reconciled or explicitly judged accurate as-is.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/skill-postflight-flow.md` - Stage 9, Ordering,
  new reader table
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` -
  `.return-meta.json` row
- `agent-system/extensions/core/context/patterns/skill-lifecycle.md` - cleanup stage descriptions
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` -
  `skill_cleanup()` description

**Verification**:
- No remaining doc claims `skill_cleanup` removes `.return-meta.json`.
- The reader table names every consumer identified in Phases 2, 3, and 4.

---

### Phase 6: Uniformity sweep and behavioral demonstration [NOT STARTED]

**Goal**: Prove the three acceptance criteria and prove the fix is uniform — no skill or command
path left without exactly one deletion owner, and no regression to `/orchestrate`.

**Tasks**:
- [ ] **Uniformity sweep**: enumerate every `skill_cleanup` call site, every
      `command-gate-out.sh` call site, and every multi-task batch loop; map each to exactly one
      deletion owner. Any path with zero owners or two owners is a defect to fix before closing.
- [ ] **Source-store boundary check**: `git status --short` shows changes only under
      `agent-system/extensions/core/**` and `specs/**` — nothing hand-written into `.claude/**`.
- [ ] **No task references**: run the repo's task-reference lint
      (`scripts/check-task-references.sh`) and confirm no new occurrences outside `specs/**`.
- [ ] **Build a fixture harness** in the scratch directory (not committed): a temp directory
      containing a copy of `.claude/scripts/` with the Phase 1 and Phase 2 edited files copied in
      from the source store, plus a synthetic `specs/state.json` holding one task. Run
      `command-gate-out.sh` from that directory. If any invoked script escapes the fixture by
      resolving the real git root, record that and fall back to instrumenting the two branches
      with echo probes to prove reachability.
- [ ] **Acceptance 1 — no false warning on success**: with a well-formed `.return-meta.json`
      present, gate-out emits no missing-metadata warning and reaches the artifact-validation
      call at the end of the script.
- [ ] **Acceptance 2 — distinguishable genuine-failure warning**: with `.return-meta.json`
      absent, gate-out emits the new message and exits 0, and the message is textually distinct
      from anything a successful run produces.
- [ ] **Acceptance 3 — defensive correction demonstrated**: with `.return-meta.json` reporting a
      success status and the fixture's `state.json` deliberately stale, confirm the
      `[gate-out] Defensive correction: ...` line is emitted and the status is corrected — the
      first time this code path has been observed to run.
- [ ] **Regression check on `/orchestrate`**: confirm by reading (and, if a safe target exists, by
      a real run) that the paused/partial branch still leaves `.return-meta.json` on disk and that
      the completion branch removes it only after `git-commit-scoped.sh`.
- [ ] **Real-run spot-check**: run a real `/plan` or `/implement` on a low-risk task and confirm
      the now-reachable CHECKPOINT 3 block stages nothing surprising on top of what the skill
      already committed inline, and that no `.return-meta.json` is left behind.
- [ ] Record any gap found here as a fix within this phase, not as a deferred item.

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- Fixture harness lives in the session scratchpad directory and is not committed; any defect it
  surfaces is fixed in the phase's own file of origin.

**Verification**:
- All three acceptance criteria demonstrated with captured output.
- The uniformity mapping shows exactly one deletion owner per path.
- `/orchestrate` behavior confirmed unchanged.

---

## Testing & Validation

- [ ] `bash -n` parses clean for `skill-base.sh` and `command-gate-out.sh`.
- [ ] A normal successful run of each of the five commands emits no false silent-failure warning.
- [ ] A genuinely failed skill run (no metadata written) emits a distinguishable, diagnostic
      warning and does not block.
- [ ] The defensive status correction path is observed to execute at least once.
- [ ] `skill_validate_task_artifacts` is reached at the end of `command-gate-out.sh` on a
      successful run.
- [ ] `research.md`'s CHECKPOINT 3 `git add` succeeds — report, `TODO.md`, and `state.json` are
      all staged (the atomic-failure bug is gone).
- [ ] No `.return-meta.json` lingers after any single-task or multi-task command path completes,
      except deliberately on `/orchestrate`'s paused outcome.
- [ ] `/orchestrate` completion and resume paths both behave as before the change.
- [ ] `git status --short` shows no hand-authored files under `.claude/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/skill-base.sh` (modified `skill_cleanup`)
- `agent-system/extensions/core/scripts/command-gate-out.sh` (truthful warning, retention comments)
- `agent-system/extensions/core/skills/skill-spawn/SKILL.md` (inline deletion)
- `agent-system/extensions/core/commands/{research,plan,implement,revise,orchestrate}.md`
  (deletion sites, single-task and multi-task)
- `agent-system/extensions/core/context/patterns/skill-postflight-flow.md` (Stage 9, Ordering,
  new per-command reader table)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (lifecycle row)
- `agent-system/extensions/core/context/patterns/skill-lifecycle.md`,
  `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` (descriptions)
- `specs/017_fix_return_meta_lifecycle_ordering/summaries/01_*-summary.md` (implementation summary)

## Rollback/Contingency

Every change is a source-store text edit with no data migration and no schema change, so
`git revert` of the phase commits restores the prior behavior exactly. Because the phases are
committed per green sub-step, a partial rollback is possible: reverting Phase 1 alone restores
`skill_cleanup`'s deletion and makes the Phase 3/4 deletions harmless no-ops (`rm -f` on an
already-absent file), so the system remains coherent at that intermediate point. If Phase 6
uncovers a regression in `/orchestrate`, revert Phase 3's `orchestrate.md` hunk only — that file
is independent of the other four command edits.
