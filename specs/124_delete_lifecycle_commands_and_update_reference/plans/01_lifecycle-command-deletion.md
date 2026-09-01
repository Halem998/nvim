# Implementation Plan: Task #124

- **Task**: 124 - Delete /research, /plan, /implement commands and update the CLAUDE.md command reference
- **Status**: [IMPLEMENTING]
- **Effort**: 5.25 hours
- **Dependencies**: Task 117, Task 68, Task 81, Task 126 (all `[COMPLETED]`)
- **Research Inputs**: `specs/124_delete_lifecycle_commands_and_update_reference/reports/01_lifecycle-command-deletion-preconditions.md`
- **Artifacts**: plans/01_lifecycle-command-deletion.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Delete `commands/research.md` (615 lines), `commands/plan.md` (645 lines), and
`commands/implement.md` (506 lines) from the core extension source store, de-register them from
`manifest.json`, and reconcile every reference that the deletion would otherwise leave dangling
inside the two files this task owns end-to-end: `merge-sources/claudemd.md` (the Command
Reference table plus the six prose sites in the same file that name the three commands as live
entry points) and `index-entries.json` (six context-index `load_when.commands` bindings, three of
which would become permanently unreachable). `commands/revise.md` is not touched. Done means: the
three files are gone, no lint or test regresses, no context file loses its only load trigger, and
the shipped command reference documents `/orchestrate NNN --research/--plan/--implement` with the
same semantics the flags actually have.

### Research Integration

The research report's three preconditions were re-verified against current state at plan time,
and **its central finding is now stale**:

- (a) Stage 3.5 Dispatch Prep rehome — LANDED (unchanged from the report).
- (b) The two blocking defects (Task 68, Task 81) — RESOLVED (unchanged from the report).
- (c) `/orchestrate` phase-forcing flags — **NOW SATISFIED**, contrary to the report's
  "NOT IMPLEMENTED" verdict. Task 126 (`implement_orchestrate_phase_forcing_flags`) is
  `[COMPLETED]`. Verified at plan time in the source store: `parse-command-args.sh` accumulates
  the flags (lines ~164-196), `orchestrate.md` documents all three in its Options table and its
  Constraints section, and `skill-orchestrate/SKILL.md` consumes `force_phases` in a Stage 2b
  forced-phase queue. Also verified present in the deployed `.claude/` tree, so the replacement
  spelling is live, not merely committed to source.

The report's recommendation to block this task is therefore superseded — this is recorded in the
git history as `task 124: clear stale blocked status (blocking precondition resolved)`. The
report's recommendation 3 (add Task 126 as a formal dependency) is honored in this plan's
Dependencies field. Its recommendation 4 (leave `commands/revise.md` untouched) is carried as a
Non-Goal. Its Risk 2 (flag spelling may differ from what was assumed) is discharged by Phase 1,
which re-reads the shipped flag semantics rather than trusting either the report or this plan's
own summary of them.

**Findings this plan adds beyond the report**, discovered while sizing the blast radius:

1. `manifest.json`'s `provides.commands` array names all three files. `check-extension-docs.sh`
   fails on "manifest entry missing on disk", so the manifest edit and the file deletion are one
   indivisible change, not two.
2. `index-entries.json` carries six `load_when.commands` bindings on the three command names.
   Three context files would lose their **only** trigger: `patterns/multi-task-operations.md`
   (`/research`, `/plan`, `/implement`), `standards/git-workflow-narrative.md` (`/implement`), and
   `standards/error-recovery-strategies.md` (`/implement`). This is a silent reachability
   regression the report did not surface.
3. `test-conflict-predicate.sh` cases 9.6/9.7/9.8 are static guards over the three command files.
   They degrade to a SKIPPED branch rather than failing, so they become permanently vacuous test
   cases that still report as run.
4. `merge-sources/claudemd.md` names the three commands at six sites outside the Command
   Reference table. The task's own wording ("so the reference table is never briefly wrong")
   applies to the file, not the table in isolation.
5. Deploy prunes stale files only under `deploy-headless.sh --wipe`; a default resync copies
   without pruning, so the three deployed `.claude/commands/*.md` copies would linger and trip
   `check-extension-docs.sh` Rule K (deployed command with no `provides.commands` source).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and `roadmap_flag` was not set; no
roadmap phases are included. This task advances the A1/A7 ledger of
`specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` (commands row:
-1,766 measured lines against the ledger's -1,835 estimate, which was taken against a slightly
larger earlier revision of the three files).

## Goals & Non-Goals

**Goals**:

- Delete `commands/research.md`, `commands/plan.md`, `commands/implement.md` from
  `agent-system/extensions/core/`, with `manifest.json` de-registration in the same change.
- Leave `merge-sources/claudemd.md` internally consistent: no row, sentence, or pointer in that
  file names a command that no longer exists, and the `/orchestrate` row states the phase-forcing
  flags' real semantics including their single-task-only constraint.
- Leave `index-entries.json` free of dead load triggers, with no context file losing its only
  route to being loaded.
- Retire the three now-vacuous static guard cases in `test-conflict-predicate.sh`.
- Leave the deployed `.claude/` tree free of orphaned command files, with
  `check-extension-docs.sh` no worse than its pre-change baseline.
- Produce a triaged inventory of the wider (out-of-scope) reference surface so the follow-up work
  is scoped rather than discovered later.

**Non-Goals**:

- `commands/revise.md` is not touched, renamed, or folded into `/orchestrate`.
- The three lifecycle skills (`skill-researcher`, `skill-planner`, `skill-implementer`) are not
  deleted — that is Task 125's scope, and its precondition is this task landing.
- The `-hard` lifecycle files are not touched — Task 121's scope.
- The ~76 files across `context/`, `docs/`, `skills/`, and `agents/` that mention `/research`,
  `/plan`, or `/implement` in prose are **not** edited. They are inventoried in Phase 7 and left
  for a follow-up. Editing them here would turn a bounded deletion into an unbounded doc sweep.
- No PR, push, or `/merge`. No new task is created by this plan's execution.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Manifest and file deletion land as separate commits, leaving a red intermediate state that fails `check-extension-docs.sh` | M | H | Phase 4 is declared `Commit Mode: atomic-batch`; manifest edit and the three deletions are one commit |
| A context file silently loses its only load trigger and becomes unreachable | H | H (certain without the fix) | Phase 3 enumerates all six bindings and asserts, per entry, that a surviving trigger remains; three named files require `/orchestrate` to be added |
| Documented replacement spelling drifts from the shipped flag semantics | M | M | Phase 1 re-reads `orchestrate.md`'s Options table and Constraints section as the source of truth; Phase 2 copies from that reading, not from this plan's prose |
| Stale deployed copies linger and trip Rule K orphan detection | M | H | Phase 6 removes the three deployed files explicitly, then re-runs the lint; `--wipe` is the documented fallback, not the first move |
| Guard-case removal renumbers or breaks the surrounding test file | M | L | Phase 5 runs the full suite before and after; case numbering is left intact (9.6-9.8 removed, later cases not renumbered) |
| Scope creep into the ~76 prose references | M | M | Explicit Non-Goal; Phase 7 inventories without editing |
| An edit lands in `.claude/**` instead of the source store and is silently wiped | H | L | Every phase names `agent-system/extensions/core/**` targets; the one deliberate `.claude/` action (Phase 6) is a deletion of a deploy artifact, not an authored edit |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5, 6 | 4 |
| 5 | 7 | 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Precondition re-verification and baseline capture [COMPLETED]

**Goal**: Confirm the replacement spelling is live before anything is deleted, and capture the
pre-change lint/test baseline so later phases can prove "no worse than before" rather than assert
it.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/commands/orchestrate.md`'s `## Options` table rows
      for `--research`/`--plan`/`--implement` and its Constraints bullet on the same flags.
      Record the exact shipped semantics: composable, canonical lifecycle ordering regardless of
      typed order, stop-after-last-named-phase, opens a new `MM_` artifact round, never regresses
      status, and **single-task only** (accepted and ignored with a loud notice in multi-task
      mode). This recorded wording is the input to Phase 2 — do not paraphrase from this plan.
      *(completed)*
- [x] Confirm `force_phases` is consumed, not merely parsed: grep
      `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` for `force_phases` and
      confirm the Stage 2b forced-phase queue exists. *(completed: Stage 2b builds an ordered
      force_queue consumed by Stage 3's 3c ahead of status-derived dispatch)*
- [x] Confirm the flags are present in the deployed tree
      (`.claude/commands/orchestrate.md`, `.claude/skills/skill-orchestrate/SKILL.md`), so the
      documented spelling works for the user today and not only after the next redeploy.
      *(completed)*
- [x] Capture baseline: `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`
      — save full output to `/tmp/claude-1000/-home-benjamin--config-nvim/9ecff4ae-c031-4975-a1dc-9ecaa7a76fe2/scratchpad/baseline-extension-docs.txt`.
      A pre-existing failure is a baseline, not a blocker; record it so Phase 6 compares like for
      like. *(completed: 3 pre-existing FAILs, all unrelated missing-script-registration issues
      for test-state-write-large-payload.sh, tests/test-force-phases.sh,
      tests/test-roadmap-argv-ceiling.sh)*
- [x] Capture baseline: `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh`
      — save pass/fail counts, including the 9.6/9.7/9.8 lines, to the same scratchpad directory.
      *(completed: 36 passed, 0 failed)*
- [x] Capture baseline reference inventory:
      `grep -rl -- "\`/research\|\`/implement\|\`/plan\b" agent-system/extensions/core/`
      — save the file list (expected ~76 files) for Phase 7's triage. *(completed: exactly 76
      files, matching hypothesis)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The baseline reference inventory is expected to be ~76 files under
`agent-system/extensions/core/`, and the deleted-file line counts are expected to be 615/645/506.
Both were measured at plan time and may have drifted. Confirm both by running the commands above;
if the counts differ materially, note the actual figures in the summary rather than repeating the
planned ones.

**Files to modify**: none (read-only phase; scratchpad writes only)

**Verification**:

- All three flags confirmed documented in `orchestrate.md` and consumed in `skill-orchestrate`.
- Baseline lint and test output files exist and are non-empty.
- If any flag is found absent, STOP and report — do not proceed to deletion.

---

### Phase 2: Reconcile merge-sources/claudemd.md end to end [COMPLETED]

**Goal**: Make the shipped command reference correct for a world without `/research`, `/plan`,
and `/implement` — the table and the prose in the same file, so the file is never internally
self-contradictory.

**Tasks**:

- [x] Remove the three Command Reference table rows for `/research`, `/plan`, `/implement`
      (currently lines ~99-101). *(completed)*
- [x] Verify the surviving `/orchestrate` row (currently line ~111) against Phase 1's recorded
      semantics, and amend it if it understates them — in particular it must state that the
      phase-forcing flags are single-task only, which the current row omits. *(completed: row
      strengthened to state all six load-bearing points word-for-word — composability, canonical
      ordering, stop-after-last, new artifact round, no status regression, single-task only)*
- [x] Reconcile the six prose sites in the same file that name the deleted commands as live
      entry points. Located at plan time near lines 115, 169, 177-178, 231, 241, 295; re-locate
      by grep rather than by line number. Specifically:
      - the **Multi-task syntax** paragraph (multi-task numbers/ranges now belong to
        `/orchestrate` alone);
      - the **Model Enforcement** paragraph's "orchestrator commands (`/research`, `/plan`,
        `/implement`)" list and its "These flags work on `/research`, `/plan`, and `/implement`"
        sentence;
      - the **Team Mode** paragraph's "`/research`, `/plan`, and `/implement` no longer accept
        `--team`" sentence, which becomes vacuous once the commands are gone;
      - the **Routing Mechanism** paragraph's consumer list;
      - the `--hard` and `--lit` **Per-Invocation Only** sentences enumerating the four commands;
      - the **Error Handling** bullet "next /implement resumes".
      *(completed: all six sites reconciled; the `--lit` Per-Invocation Only sentence lives in
      the literature extension's own merge-source file, out of this file's scope, and was left
      untouched)*
- [x] Re-read the whole file once after editing and confirm zero remaining occurrences of
      `/research`, `/implement`, or `/plan` used as a *command name*. Occurrences of the words
      research/plan/implement as ordinary nouns (e.g. "the normal research/plan/implement/postflight
      lifecycle", "plan-format.md", "Report/plan formats") are correct and must be left alone —
      this is a semantic pass, not a blind substitution. *(completed: 4 legitimate noun/filename
      uses remain, zero command-name uses)*
- [x] Confirm no task-number reference is introduced (this file is a deliverable outside
      `specs/**`). *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Six prose sites plus three table rows were counted at plan time by
`grep -n -- "/research\|/plan\b\|/implement" agent-system/extensions/core/merge-sources/claudemd.md`
(13 hits, of which 4 are legitimate non-command uses). Re-run that grep and reconcile against the
actual hit list before declaring the phase done; do not assume the count still holds.

**Files to modify**:

- `agent-system/extensions/core/merge-sources/claudemd.md` — remove three table rows, amend the
  `/orchestrate` row, reconcile six prose sites.

**Verification**:

- `grep -n -- "/research\|/implement" agent-system/extensions/core/merge-sources/claudemd.md`
  returns only non-command-name uses, each individually justified.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the deployed
  equivalent) reports no new violation for this file.
- The `/orchestrate` row's flag description matches Phase 1's recorded semantics word for word on
  the load-bearing points (composability, ordering, stop-after-last, new artifact round, no status
  regression, single-task only).

---

### Phase 3: Retarget the index-entries.json load triggers [COMPLETED]

**Goal**: Ensure no context file loses its route to being loaded when the three command names stop
existing as load triggers.

**Tasks**:

- [x] Enumerate every `load_when.commands` array in
      `agent-system/extensions/core/index-entries.json` containing `/research`, `/plan`, or
      `/implement`. Six were found at plan time:
      - `patterns/multi-task-operations.md` — `["/research","/plan","/implement"]`
      - `standards/status-markers.md` — `["/task","/plan","/implement"]`
      - `patterns/task-lock.md` — `["/research","/refresh","/plan","/implement","/orchestrate"]`
      - `standards/git-staging-scope.md` — `["/orchestrate","/research","/errors","/implement","/plan"]`
      - `standards/git-workflow-narrative.md` — `["/implement"]`
      - `standards/error-recovery-strategies.md` — `["/implement"]`
      *(completed: re-enumeration via jq confirmed exactly these six, no seventh)*
- [x] For each entry, remove the three dead command names. *(completed)*
- [x] For each entry whose surviving array would be **empty or would no longer include the
      command that now performs that work**, add `/orchestrate`. This is required for
      `patterns/multi-task-operations.md`, `standards/git-workflow-narrative.md`, and
      `standards/error-recovery-strategies.md` (each would otherwise be left with an empty
      trigger list and become unreachable), and for `standards/status-markers.md` (which would
      keep only `/task`, losing its lifecycle-phase trigger entirely). *(completed)*
- [x] `patterns/task-lock.md` and `standards/git-staging-scope.md` already list `/orchestrate`;
      prune only. *(completed)*
- [x] Validate JSON well-formedness (`jq . index-entries.json > /dev/null`) and run
      `bash agent-system/extensions/core/scripts/validate-context-index.sh` if it accepts a
      source-store invocation; otherwise defer that check to Phase 6's post-deploy run and say so.
      *(completed: jq parses cleanly; validate-context-index.sh refuses source-store invocation
      by design (documented contingency), deferred to Phase 6)*
- [x] Note in the summary that `patterns/multi-task-operations.md`'s *content* still describes
      multi-task syntax for the three deleted commands. Retargeting its trigger is in scope;
      rewriting its body is not — record it as the highest-priority item in Phase 7's inventory.
      *(completed: noted in progress file, to be carried into the Phase 7 inventory and summary)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Exactly six entries carry these triggers, of which four need `/orchestrate`
added and two need pruning only. Confirm by re-running the enumeration (a `jq`/python walk over
every `load_when.commands` array) before editing; if a seventh entry appears, apply the same
empty-array test to it rather than treating the list above as closed.

**Files to modify**:

- `agent-system/extensions/core/index-entries.json` — prune three command names from six
  `load_when.commands` arrays; add `/orchestrate` to four of them.

**Verification**:

- `jq -r '.. | objects | select(.load_when?.commands?) | .load_when.commands[]' index-entries.json | sort -u`
  contains no `/research`, `/plan`, or `/implement`.
- No `load_when.commands` array in the file is empty.
- `jq .` parses the file cleanly.

---

### Phase 4: Delete the three command files and de-register them [COMPLETED]

**Goal**: Remove the 1,766 lines of duplicated lifecycle-command surface in a single change that
never leaves the manifest pointing at a missing file.

**Tasks**:

- [x] Delete `agent-system/extensions/core/commands/research.md`. *(completed: 615 lines)*
- [x] Delete `agent-system/extensions/core/commands/plan.md`. *(completed: 645 lines)*
- [x] Delete `agent-system/extensions/core/commands/implement.md`. *(completed: 506 lines)*
- [x] Remove the `"implement.md"`, `"plan.md"`, and `"research.md"` entries from
      `provides.commands` in `agent-system/extensions/core/manifest.json`, preserving the array's
      existing ordering and JSON formatting for the surviving entries. *(completed)*
- [x] Confirm `agent-system/extensions/core/commands/revise.md` is untouched and still listed in
      the manifest. *(completed)*
- [x] Confirm `agent-system/extensions/core/commands/README.md` needs no change — it describes
      the directory's deploy contract and does not enumerate individual commands (verified at
      plan time). If that has changed, update it. *(completed: no change needed, confirmed)*
- [x] Commit all four file changes together as one commit. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Three files totalling 1,766 lines (615 + 645 + 506, measured at plan time)
and exactly three manifest array entries. Re-measure with `wc -l` before deletion and record the
actual figure in the summary; the A7 ledger's -1,835 estimate was taken against an earlier
revision and the summary should state the measured number, not the ledger's.

**Files to modify**:

- `agent-system/extensions/core/commands/research.md` — deleted
- `agent-system/extensions/core/commands/plan.md` — deleted
- `agent-system/extensions/core/commands/implement.md` — deleted
- `agent-system/extensions/core/manifest.json` — three `provides.commands` entries removed

**Verification**:

- The three files do not exist; `revise.md` and `orchestrate.md` do.
- `jq -r '.provides.commands[]' agent-system/extensions/core/manifest.json` lists neither
  `research.md`, `plan.md`, nor `implement.md`, and lists `revise.md`.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no
  "manifest command entry missing on disk" failure. Deployed-orphan (Rule K) failures for the
  three now-stale `.claude/commands/*.md` copies are **expected at this point** and are cleared by
  Phase 6 — record them, do not chase them here.
- Exactly one commit contains all four changes.

---

### Phase 5: Retire the vacuous static guard cases [COMPLETED]

**Goal**: Remove test cases that can no longer test anything, so the suite's pass count stops
including three permanently-skipped guards.

**Tasks**:

- [x] In `agent-system/extensions/core/scripts/test-conflict-predicate.sh`, remove cases 9.6,
      9.7, and 9.8 in full (the `research_md`/`plan_md`/`implement_md` static guards over the
      deleted command files, plus their SKIPPED fallback branches). *(completed)*
- [x] Do **not** renumber the surrounding cases — case numbers are referenced in output and
      possibly elsewhere; leaving a gap at 9.6-9.8 is the lower-risk change. *(completed: 9.1-9.5
      unchanged, no renumbering)*
- [x] Update the stale comment in
      `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` (near line 306) that
      describes the call convention as "exactly as commands/research.md's, commands/plan.md's,
      and commands/implement.md's Step 2.5 / Step 3.5 blocks call it" — retarget it to the
      surviving caller in `skill-orchestrate`, or state plainly that the former callers are
      deleted, whichever the actual code supports. *(completed: retargeted to
      skill-orchestrate/SKILL.md's Stage MT-3 step 4.5, phrased without the literal deleted paths
      to satisfy the zero-grep-hit verification below)*
- [x] Update the stale comment reference in
      `agent-system/extensions/core/scripts/update-task-status.sh` (near line 420) naming
      `commands/implement.md` Step 4 as the multi-task batch path anchor; retarget to the
      surviving anchor in `skill-orchestrate`. *(completed: retargeted to
      skill-orchestrate/SKILL.md's Stage MT-3 step 7 inter-cycle redeploy checkpoint)*
- [x] Confirm no task-number reference is introduced into any of these three scripts.
      *(completed)*

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: Three test cases in one file, plus one stale comment in each of two other
scripts (four files' worth of change in three files). Confirm by re-running
`grep -rn "commands/research\.md\|commands/plan\.md\|commands/implement\.md" agent-system/extensions/core/scripts/`
after editing — it must return zero hits.

**Files to modify**:

- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` — remove cases 9.6-9.8
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` — retarget stale comment
- `agent-system/extensions/core/scripts/update-task-status.sh` — retarget stale comment

**Verification**:

- `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` passes, with a pass count
  equal to Phase 1's baseline minus exactly the three removed cases and zero new failures.
- `bash agent-system/extensions/core/scripts/test-four-tier-conflict.sh` passes.
- Zero grep hits for the three deleted command paths anywhere under `scripts/`.

---

### Phase 6: Prune stale deployed copies and re-verify the deploy tree [COMPLETED]

**Goal**: Bring the gitignored `.claude/` deploy tree into agreement with the source store, and
prove the lint is no worse than Phase 1's baseline.

**Tasks**:

- [x] Remove the three now-orphaned deployed command files: `.claude/commands/research.md`,
      `.claude/commands/plan.md`, `.claude/commands/implement.md`. These are deploy artifacts, not
      authored files — deleting them is not a `source-store-deploy-boundary.md` violation, and
      they are regenerable in the sense that nothing regenerates them any more. *(completed)*
- [x] Run the non-destructive deploy:
      `bash agent-system/extensions/core/scripts/deploy-headless.sh` — this refreshes
      `claudemd.md`-derived `CLAUDE.md` and the merged `index.json` from the Phase 2/3 edits.
      *(completed: deploy landed; its fast-gate verify-deploy.sh sub-step FAILed on 3 checks, all
      confirmed pre-existing and unrelated to this task -- see progress notes)*
- [x] Confirm the deployed `CLAUDE.md` Command Reference table no longer lists the three commands
      and that the `/orchestrate` row carries the amended description. *(completed)*
- [x] Confirm the deployed `.claude/index.json` carries the retargeted `load_when.commands`
      arrays. *(completed: deployed path is .claude/context/index.json; all six entries verified)*
- [x] Re-run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`
      and diff against Phase 1's baseline. The Rule K orphan failures observed at Phase 4 must be
      gone; no new failure class may appear. *(completed with a correction: no Rule K orphan
      failure was ever observed at Phase 4 -- Rule K is structurally blind to .claude/, which is
      entirely gitignored, so it can never fire there; see the Phase 4 handoff. Re-run here is
      byte-identical to the Phase 1 baseline via diff -- zero delta, no new failure class)*
- [x] Run `bash agent-system/extensions/core/scripts/validate-context-index.sh` (or its deployed
      counterpart) now that the merged index exists. *(completed: deployed counterpart
      `.claude/scripts/validate-context-index.sh` -- 215 entries checked, 0 errors, 0 warnings,
      PASSED)*
- [x] If the default resync leaves any stale artifact behind that a targeted removal cannot fix,
      escalate to `bash agent-system/extensions/core/scripts/deploy-headless.sh --wipe` — this is
      destructive to `.claude/` (snapshot, `rm -rf`, regenerate, restore) and is the documented
      fallback, so state explicitly in the summary if it was used and why. *(completed: not
      needed -- targeted removal + non-destructive deploy-headless.sh sufficed)*

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: Exactly three orphaned deployed command files are expected under
`.claude/commands/`, matching the three source files deleted in Phase 4. Confirm by listing
`.claude/commands/` and by reading `check-extension-docs.sh`'s Rule K output rather than assuming
the set — if the lint names a deployed orphan outside this trio, triage it before removing
anything.

**Files to modify**:

- `.claude/commands/research.md`, `.claude/commands/plan.md`, `.claude/commands/implement.md` —
  deleted (deploy artifacts)
- `.claude/**` — regenerated by the deploy (not hand-edited)

**Verification**:

- `ls .claude/commands/` shows no `research.md`, `plan.md`, or `implement.md`, and does show
  `revise.md` and `orchestrate.md`.
- `check-extension-docs.sh` output diffed against the Phase 1 baseline shows no new failures and
  the orphan failures cleared.
- Deployed `CLAUDE.md` and `.claude/index.json` reflect the Phase 2 and Phase 3 edits.

---

### Phase 7: Deletion-reference audit, out-of-scope inventory, and final gate [COMPLETED]

**Goal**: Find references the literal-name greps structurally cannot (glob, path-pattern, and
prose-without-the-name), and hand the follow-up work over scoped rather than leaving it to be
rediscovered.

**Tasks**:

- [x] Run the purpose-built auditor:
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/audit-deletion-references.sh research.md plan.md implement.md`.
      Its hits are triage candidates, not failures — read them. Note that the bare words
      `research`/`plan`/`implement` are too generic to audit usefully; use the `.md` filenames so
      the literal-name pass stays signal-bearing, and rely on the wildcard and reachability passes
      for the rest. *(completed: Pass 1 = 0 hits, Pass 2 = 146 hits (all confirmed unrelated
      artifact-naming convention), Pass 3 = same 3 pre-existing baseline FAILs plus a clean
      generate-context-line-counts.sh --check)*
- [x] Triage Phase 1's ~76-file reference inventory into three named buckets, and write the
      result into this task's summary artifact (not into a deliverable file):
      1. **Operational** — text that instructs an agent or user to *invoke* `/research N`,
         `/plan N`, or `/implement N` as a step. Highest priority follow-up; these are now
         instructions to run a nonexistent command.
      2. **Descriptive** — prose describing the historical three-command lifecycle. Lower
         priority; wrong but not actionable-wrong.
      3. **Legitimate** — the words used as ordinary nouns or as artifact-type names
         (`plan-format.md`, "research report", "the research/plan/implement lifecycle" as a phase
         sequence rather than a command list). No action.
      *(completed: 12 Operational files, ~58 Descriptive files (of 73 total, post-deletion),
      1 Legitimate; full detail in progress/phase-7-progress.json and the summary. Highest-priority
      finding: skill-orchestrate/SKILL.md:2708 is a LIVE skill, not deprecated docs, whose
      blocker-escalation message still suggests running two now-deleted commands manually)*
- [x] Name explicitly in the summary the files that are wholesale orphaned rather than merely
      stale, so the follow-up scope is unambiguous. Known at plan time:
      `docs/examples/research-flow-example.md` (an end-to-end walkthrough of a deleted command),
      `context/processes/research-workflow.md`, `context/processes/planning-workflow.md`,
      `context/processes/implementation-workflow.md`, and
      `context/patterns/multi-task-operations.md` (body still describes multi-task syntax for the
      three deleted commands; its trigger was retargeted in Phase 3 but its content was not).
      *(completed: all 5 confirmed still present and still wholesale about the deleted commands;
      the three processes/*-workflow.md files confirmed to already carry on_demand:true with an
      empty load_when.commands array, a pre-existing condition unrelated to this task)*
- [x] Recommend the follow-up as a single scoped task in the summary. Do **not** create it —
      task creation is not this plan's scope. *(completed: recommendation written into the
      summary artifact; no task created)*
- [x] Run the final gate set: `check-extension-docs.sh`, `check-task-references.sh`,
      `test-conflict-predicate.sh`, `test-four-tier-conflict.sh`, plus any repo-standard postflight
      validators. All must pass or be explained against the Phase 1 baseline. *(completed: all
      pass or are byte-identical to the Phase 1 baseline; see progress/phase-7-progress.json)*
- [x] Confirm the full change set introduces zero task-number references outside `specs/**`.
      *(completed: check-task-references.sh (deployed) PASS, 0 occurrences across 4 trees)*

**Timing**: 0.75 hours

**Depends on**: 5, 6

**Verification Tier**: full

**Scope Hypothesis**: The out-of-scope inventory is expected to be ~76 files, with the operational
bucket a small minority (the five named orphan files plus a handful of skill/agent instruction
sites). The bucket sizes are a hypothesis — report the measured counts, and if the operational
bucket turns out large enough that leaving it unfixed breaks a live workflow, say so plainly in
the summary rather than silently expanding this task to cover it.

**Files to modify**: none (audit and reporting only; summary artifact is under `specs/**`)

**Verification**:

- `audit-deletion-references.sh` ran to completion and every hit is accounted for in the triage.
- All four gate scripts pass, or each deviation is explained against the Phase 1 baseline.
- The summary names the three buckets with counts and lists the wholesale-orphaned files.
- `check-task-references.sh` reports no new violation.

---

## Testing & Validation

- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` — no
      new failures versus the Phase 1 baseline; the manifest-missing-file and deployed-orphan
      classes both absent at the end.
- [ ] `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` — passes, pass count
      = baseline minus exactly three.
- [ ] `bash agent-system/extensions/core/scripts/test-four-tier-conflict.sh` — passes.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh` — no new violation.
- [ ] `jq .` parses `manifest.json` and `index-entries.json`.
- [ ] No `load_when.commands` array in `index-entries.json` is empty.
- [ ] `grep -rn "commands/research\.md\|commands/plan\.md\|commands/implement\.md" agent-system/extensions/core/scripts/`
      returns zero hits.
- [ ] `merge-sources/claudemd.md` contains no command-name use of `/research`, `/plan`, or
      `/implement`.
- [ ] Manual smoke: `/orchestrate` still resolves, and its Options table documents the three
      phase-forcing flags.

## Artifacts & Outputs

- `agent-system/extensions/core/commands/research.md` — deleted
- `agent-system/extensions/core/commands/plan.md` — deleted
- `agent-system/extensions/core/commands/implement.md` — deleted
- `agent-system/extensions/core/manifest.json` — three `provides.commands` entries removed
- `agent-system/extensions/core/merge-sources/claudemd.md` — table rows removed, `/orchestrate`
  row amended, six prose sites reconciled
- `agent-system/extensions/core/index-entries.json` — six `load_when.commands` arrays retargeted
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` — cases 9.6-9.8 removed
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` — stale comment retargeted
- `agent-system/extensions/core/scripts/update-task-status.sh` — stale comment retargeted
- `.claude/` — redeployed; three orphaned command files removed
- `specs/124_delete_lifecycle_commands_and_update_reference/summaries/01_lifecycle-command-deletion-summary.md`
  — includes the measured line-count reduction and the three-bucket follow-up inventory

## Rollback/Contingency

All source-store changes are in git and are recoverable per phase. Phase 4 is a single atomic
commit, so `git revert` of that one commit restores both the three command files and their
manifest entries together — the manifest and files can never be restored out of step. Phases 2,
3, and 5 are independent single-file commits, each revertible without disturbing the others.

The `.claude/` tree is gitignored and fully regenerable: if Phase 6 leaves it in a bad state,
`bash agent-system/extensions/core/scripts/deploy-headless.sh --wipe` rebuilds it from whatever
the source store currently holds, and `settings.local.json` plus `.syncprotect`-listed paths
survive that wipe.

If Phase 1 finds the phase-forcing flags absent or non-functional despite Task 126 being
`[COMPLETED]`, stop before Phase 4 and report — the deletion must not proceed without a working
replacement spelling, which is the research report's original and still-binding constraint.
