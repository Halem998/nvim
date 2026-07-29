# Implementation Plan: Task #967

- **Task**: 967 - fix_git_commit_scoped_lock_exclude_abort
- **Status**: [COMPLETED]
- **Effort**: 4.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/967_fix_git_commit_scoped_lock_exclude_abort/reports/01_lock-exclude-abort.md
- **Artifacts**: plans/01_lock-exclude-abort-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md, git-staging-scope.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`git-commit-scoped.sh` unconditionally injects four `:(exclude)<task_dir>/<ephemeral>` pathspec
entries for any task-directory positional pathspec. Naming an already-gitignored path in an
explicit `:(exclude)` entry makes `git add` treat it as an explicitly-named ignored path and abort
the entire add with rc=1 whenever that path currently exists on disk. The script's `if ! git add`
branch then exits 2 without attempting a commit, and because every caller treats that as
non-blocking, the dropped commit is silent. The fix makes exclude injection **conditional on
`git check-ignore`**: a candidate that `.gitignore` already covers is never named (git skips
ignored paths swept up implicitly by a directory pathspec anyway, so the entry was pure downside);
a candidate not covered is injected exactly as today. The change is confined to the injection loop;
the V2/V3 safety gates and the `specs/.commit-lock/` mutex are untouched. The plan is test-first:
the regression suite is authored and proven RED against the unmodified script before the fix lands.

### Research Integration

The research report supplied four load-bearing empirical findings that shape this plan:

1. The task's repro is confirmed, and the circulating "omit the trailing slash" workaround is
   confirmed **false** — the trailing slash on the positive entry is irrelevant to the abort.
2. **The task's scoping premise is false.** All four injected excludes (`.orchestrator-loop-guard`,
   `.orchestrator-churn-state.json`, `.drift-inspection.json`, `.lock/`) are gitignored in this
   repo and all four reproduce the identical abort. Fixing only `.lock/` leaves three live hazards.
3. With **no** exclude entries injected and all four ephemeral paths present, `git add
   "specs/NNN_probe/"` returns rc=0 and stages only the tracked file — none of the four get staged.
   Gitignore alone is sufficient to keep them out.
4. `git check-ignore -q` correctly reports all four as ignored **even when the path does not exist
   on disk**, making a pre-injection conditional check viable.

The report also surfaced `orchestrator-runtime-files.md`'s settled position — gitignore coverage
"is the primary, sufficient control", the staging-narrowing is "defense-in-depth for a repo that
has not yet applied this block" — which is the authority this plan's chosen option implements
mechanically rather than by deletion.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap consultation was performed
and no roadmap phases are included.

## Conflict Reconciliation: Chosen Fix vs. the Task's Literal VERIFICATION BAR

This section exists because the task text and the empirical evidence disagree, and the delegation
explicitly requires the disagreement be resolved in the open rather than papered over.

### The conflict, stated precisely

The task's VERIFICATION BAR reads: *"Existing callers unaffected: a commit with no `.lock` present
still succeeds and still excludes the other three ephemeral runtime files."* Read literally as
"three `:(exclude)...` entries must still appear in the pathspec list", this is only satisfiable by
Option A (drop `.lock/` alone). Read as an outcome requirement — "the other three ephemeral runtime
files must still not end up in the commit" — it is satisfiable by any of Options A/B/C.

The task's own justification for the literal reading is its premise that *"the other three
ephemeral excludes name paths that are NOT gitignored, so they do not have this problem."* The
research disproved that premise empirically (report Findings, item 3): all three are gitignored
(`.gitignore` lines 33/35/38) and all three reproduce the byte-identical rc=1 abort when present on
disk. The literal reading therefore rests on a factual claim that does not hold, and Option A would
ship a fix that provably leaves three instances of the same defect live — `.orchestrator-loop-guard`
and `.orchestrator-churn-state.json` in particular are per-batch scratch files not cleaned up until
full-loop termination, so the same "present by construction at the per-task commit" argument the
task makes for `.lock/` applies to them directly.

### Decision

**Implement Option C — conditional injection gated on `git check-ignore -q`.**

Rationale, in order of weight:

1. **It provably restores rc=0 for all four paths, not one.** The delegation says "prefer the fix
   that provably restores rc=0"; Option A restores it only for the specific path that happened to
   reproduce first in a live run.
2. **It preserves the exclude entries in the only configuration where they ever did anything.** In
   an under-configured consumer repo — one that has not applied the manual "Consumer Repo Setup"
   `.gitignore` block from `orchestrator-runtime-files.md`, which deployment cannot push
   automatically — `check-ignore` reports the candidates as not-ignored and all four entries are
   injected verbatim, byte-identical to today's behavior. Option B (delete the injection outright)
   would silently regress exactly that repo.
3. **It is the mechanical expression of the project's own settled standard**, which already says
   gitignore is the primary and sufficient control and the exclude set is defense-in-depth for
   repos lacking it. Option C makes the script apply that standard per-repo instead of assuming
   the worst case unconditionally.

### How the VERIFICATION BAR is satisfied

The bar is satisfied on the outcome reading, and the literal reading is preserved wherever it has
any effect. Concretely, the regression suite (Phase 1) discharges the bar in two directions:

| VERIFICATION BAR clause | How it is discharged |
|---|---|
| Commit actually lands with `.lock/` present (verified via `git log`, not exit code) | T1 — asserts `git log`/`git show --name-only` shows the commit and its file, in a fully-gitignore-covered repo |
| `.lock` still not staged | T2 — asserts `.lock` absent from `git show --name-only HEAD` |
| Commit with no `.lock` present still succeeds and still excludes the other three | T4 — outcome reading, in a fully-covered repo: commit lands, none of the other three appear in the commit |
| ...and the literal pathspec-presence reading | T5 — under-configured repo with no ephemeral `.gitignore` block: all four `:(exclude)` entries ARE injected and all four files are absent from the commit |
| `bash -n` clean | Phase 2 verification |

### Stated deviation, named rather than hidden

**Deviation**: in a fully-gitignore-covered repo (including this one), the post-fix `git add` call
carries **zero** injected `:(exclude)` entries. Anyone reading the pathspec list expecting to see
three exclude entries will not find them. This is a deliberate, documented behavior change, not an
oversight. It is safe because the exclusion outcome is delivered by `.gitignore` instead — which
the research verified directly (report Findings, item 4) and which T3/T4 re-verify per-run — and
because `check-ignore` returning anything other than exit 0 (not-ignored, or an error) falls
through to injecting the entry, so the failure direction is toward today's behavior, never away
from it. Phase 3 records this behavior change in `git-staging-scope.md` in prose, so the standard
does not keep asserting unconditional injection.

**Not chosen and why**: Option A (drop `.lock/` only) — provably incomplete, leaves three identical
hazards live. Option B (delete the injection) — regresses under-configured consumer repos. Option D
(parse `git add` stderr for the advisory string and treat it as non-fatal) — depends on
git-version- and config-dependent message text (`advice.addIgnoredFile` can suppress it) and would
swallow legitimate `git add` failures through the same code path.

## Goals & Non-Goals

**Goals**:
- Make a held task lock (or any present, gitignored ephemeral runtime file) unable to abort the
  `git add` inside `git-commit-scoped.sh`, so scoped commits actually land.
- Keep all four ephemeral paths out of every commit, in both fully-covered and under-configured
  repos.
- Ship a committed regression suite that is proven to fail against the pre-fix script.
- Keep `git-staging-scope.md` and the script in sync, including the behavioral difference.
- Correct or purge the false "omit the trailing slash" workaround wherever it has been recorded.
- Get the fix deployed so the live defect is actually closed for in-flight orchestration.

**Non-Goals**:
- Changing the V2 unmatched-pathspec filter, the V3 exclude-only refusal, or the
  `specs/.commit-lock/` mutex behavior (explicitly prohibited by the task).
- Changing which paths are *candidates* for exclusion — the four-name candidate set is unchanged.
- Migrating `scripts/test-task-lock-reap.sh` under `scripts/tests/` (tolerated exception per
  `shell-script-testing.md`; unrelated cleanup).
- Editing the root `.gitignore`.
- Any edit under `.claude/**` as a source target (deploy artifact only — see Phase 5).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Test asserts rc=0 only and passes against the pre-fix script, providing no regression protection | H | M | Phase 1 requires the suite be run against the **unmodified** script and observed RED on T1/T3 before Phase 2 begins; Phase 1 cannot close otherwise. Assertions use `git log`/`git show --name-only`, never exit code alone. |
| `check-ignore` conditional accidentally alters the V2/V3 gates or the positive-entry list | H | L | The diff touches only the injection loop between the pre-filter V3 gate and the V2 filter loop. T6 (V3 exclude-only refusal) and T7 (V2 unmatched-path drop) assert both gates still behave identically. |
| Test harness cannot run the script — `deploy-root-guard.sh` rejects a source-store invocation | M | H | Known and designed for: the suite copies the script under test plus `deploy-root-guard.sh` and `task-lock.sh` into `<scratch>/.claude/scripts/`, so `PROJECT_ROOT` resolves to the scratch repo and the guard's `*/.claude` case matches. Spelled out in Phase 1. |
| `git check-ignore` semantics differ from assumed for tracked paths | M | L | Phase 2 requires empirical confirmation (not assumption) that a tracked path reports exit 1, so the exclude is still injected for it. Falls in the safe direction either way: any non-zero exit injects. |
| Script and standard drift again — the exact staleness gap the script's own comment says it closed | M | M | Phase 3 updates both array copies in `git-staging-scope.md` in the same change, plus prose describing the conditional behavior, and is gated on a grep confirming the candidate names match the script byte-for-byte. |
| The write-time `validate-no-task-references.sh` hook blocks an edit to the script (its existing header cites a task-directory report path) | M | L | New content must use durable anchors only. The pre-existing citation in the script header is untouched — do not rewrite it; if the hook blocks on unrelated pre-existing content, note it and edit around it rather than folding an unrelated purge into this diff. |
| Fix lands in the source store but never reaches the running `.claude/` deploy, so the live defect persists | H | M | Phase 5 deploys and re-verifies against the deployed copy. `.claude/scripts/tests/` already exists with four suites, so the tests subdirectory deploy path is live. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Author the Regression Suite and Prove It RED Pre-Fix [COMPLETED]

**Goal**: A committed, registered regression suite that exercises the real `git-commit-scoped.sh`
against real git, asserts commits actually land via `git log`, and is demonstrated to fail against
the unmodified script.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` following
      `shell-script-testing.md`: `set -uo pipefail`, `SCRIPT_DIR` via
      `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`, `PASSED`/`FAILED` counters with
      `pass()`/`fail()`/`info()`, inline-heredoc fixtures into a `mktemp -d` workdir with a
      `trap ... EXIT` cleanup, exit 0 only when `FAILED` is 0. *(completed)*
- [x] Implement the harness helper that builds a scratch repo: `git init`, local `user.email`/
      `user.name`, then `mkdir -p <scratch>/.claude/scripts` and copy `git-commit-scoped.sh`,
      `deploy-root-guard.sh`, and `task-lock.sh` from `$SCRIPT_DIR/..` into it. Invoking
      `<scratch>/.claude/scripts/git-commit-scoped.sh` makes `PROJECT_ROOT` resolve to `<scratch>`
      and satisfies `deploy-root-guard.sh`'s `*/.claude` case. Parameterize the helper on whether
      the ephemeral `.gitignore` block is written, so T5 can build an under-configured repo.
      *(completed: `build_repo covered|uncovered` in the suite; the three copied scripts were
      sufficient to run the script standalone in a scratch tree, confirming Scope Hypothesis (b))*
- [x] Loud-skip discipline: if any required script is missing from the source store, emit a visible
      skip naming exactly what was missing — never silently exit 0. *(completed: top-of-file
      `REQUIRED_SCRIPTS` presence check, `exit 1` with a named list on any miss)*
- [x] **T1 (the regression)**: fully-covered repo; task dir `specs/999_probe/` with a tracked,
      modified ordinary file AND a present `.lock/` directory containing a holder file. Invoke the
      script with `-- specs/999_probe/`. Assert exit 0 AND `git log --oneline` gained a commit AND
      `git show --name-only HEAD` lists the ordinary file. *(completed)*
- [x] **T2**: same commit as T1 — assert no path containing `/.lock/` appears in
      `git show --name-only HEAD`. *(completed)*
- [x] **T3**: fully-covered repo with all four ephemeral paths present on disk; assert the commit
      lands and none of the four appear in `git show --name-only HEAD`. *(completed)*
- [x] **T4**: fully-covered repo with **no** `.lock/` present but the other three present; assert
      the commit lands and none of the three appear in the commit (the outcome reading of the
      VERIFICATION BAR's "existing callers unaffected" clause). *(completed)*
- [x] **T5**: under-configured repo (`.gitignore` **without** the ephemeral block) with all four
      paths present; assert the commit lands and none of the four appear in the commit. This is the
      literal-pathspec-presence case — the injected excludes are what keep them out here.
      *(completed)*
- [x] **T6 (V3 gate intact)**: invoke with an exclude-only pathspec list; assert exit 2 and that
      `git log` gained no commit. *(completed)*
- [x] **T7 (V2 gate intact)**: invoke with one valid positive task-dir pathspec plus one
      nonexistent positive pathspec; assert the commit still lands, contains the valid path, and a
      `WARN:` line naming the dropped pathspec was emitted. *(completed)*
- [x] Register the suite in `agent-system/extensions/core/manifest.json` `provides.scripts` as
      `tests/test-git-commit-scoped.sh`, subdirectory-qualified, alongside the four existing
      `tests/...` entries. *(completed)*
- [x] **Mutation check (blocking)**: run the suite against the **unmodified**
      `git-commit-scoped.sh`. T1 and T3 MUST fail. Record the observed failure output in the phase
      notes. If they pass pre-fix, the suite is not testing the defect — fix the suite before
      proceeding. *(completed: observed pre-fix run — T1 [FAIL] rc=2 "paths are ignored:
      specs/999_probe/.lock"; T3 [FAIL] rc=2 same message plus the other three names; T4 [FAIL]
      too (same defect via the other three ephemeral excludes, not required but consistent with
      the systemic-not-incidental framing); T2/T5/T6/T7 [PASS] pre-fix, unaffected by the defect.
      Required RED baseline (T1, T3) confirmed. Full output recorded in
      `specs/967_fix_git_commit_scoped_lock_exclude_abort/progress/phase-1-progress.json`.)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts (a) exactly two files are touched —
`scripts/tests/test-git-commit-scoped.sh` (new) and `manifest.json` (one array entry) — and (b)
copying `git-commit-scoped.sh` + `deploy-root-guard.sh` + `task-lock.sh` is sufficient for the
script to run in a scratch tree. Confirm (b) by actually running the harness before writing the
assertions; if `git-commit-scoped.sh` turns out to source or invoke a helper not in that list, add
it and record the correction rather than silently widening the copy set. Confirm (a) by
`git status --short` at phase close.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - new regression suite
- `agent-system/extensions/core/manifest.json` - add `tests/test-git-commit-scoped.sh` to
  `provides.scripts`

**Verification**:
- `bash -n agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` exits 0
- The suite runs to completion against the unmodified script and reports T1 and T3 as `[FAIL]`
  (the required RED baseline), with the other cases reporting their expected results
- `jq -e '.provides.scripts | index("tests/test-git-commit-scoped.sh")'` on the manifest exits 0
- No task-number citations introduced in either file (both are outside `specs/**`)

---

### Phase 2: Make Exclude Injection Conditional on `git check-ignore` [COMPLETED]

**Goal**: The injection loop in `git-commit-scoped.sh` skips any candidate `.gitignore` already
covers, so a present ephemeral path can never abort `git add`, while an uncovered candidate is
still excluded exactly as today.

**Tasks**:
- [x] Empirically confirm, before editing, that `git check-ignore -q -- <path>` returns 0 for an
      ignored path (existing or not), 1 for a non-ignored path, and 1 for a **tracked** path.
      Record the observed exit codes. Do not assume the tracked-path behavior. *(completed:
      verified in a scratch repo — ignored+nonexistent=0, ignored+existing=0, non-ignored=1,
      tracked=1, exactly as assumed)*
- [x] Replace the unconditional `expanded_pathspecs+=(...)` block inside the
      `specs/[0-9][0-9][0-9]_*/)` case arm with a loop over the same four candidate paths that
      appends `":(exclude)${eph}"` only when `git check-ignore -q -- "$eph"` exits **non-zero**.
      The candidate name set and their order are unchanged. *(completed)*
- [x] Ensure the fall-through direction is safe: only exit code 0 (definitively ignored) skips
      injection. Exit 1 and exit 128 (error) both inject, preserving current behavior. Add an
      inline comment stating this explicitly so a later reader does not "simplify" it into
      `if ! git check-ignore ...; then continue`. *(completed)*
- [x] Update the block's leading comment: it currently claims to mirror `git-staging-scope.md`'s
      `ephemeral_excludes` array "exactly". Restate it as mirroring the **candidate** array
      exactly, with injection conditional on gitignore coverage, and explain the abort mechanism
      (explicitly naming an ignored path in a pathspec makes `git add` refuse the whole add;
      an ignored path swept up implicitly by a directory pathspec is silently skipped).
      *(completed)*
- [x] Update the file-header comment paragraph describing automatic injection (the "the canonical
      ephemeral-runtime-file exclusion set ... is injected automatically" sentence) to state the
      conditional behavior. *(completed)*
- [x] Do **not** touch `has_positive_pathspec`, either V3 gate, the V2 filter loop, the
      `specs/.commit-lock/` mutex block, the honest-index-rows addendum, or the commit retry.
      *(completed: confirmed via `git diff` — both hunks confined to the file-header comment and
      the injection block; no hunk touches those regions)*
- [x] Run the Phase 1 suite; all cases must pass. *(completed: 7 passed, 0 failed post-fix)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the fix is confined to one file and one contiguous block
(the injection loop plus two comment paragraphs). Confirm with `git diff --stat` showing exactly
one changed file, and by reading the diff to verify no hunk falls inside the V2/V3/mutex regions.
If the change turns out to require touching a gate, stop and re-plan rather than proceeding — the
task explicitly prohibits weakening those gates.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - conditional injection loop; two
  comment paragraphs updated

**Verification**:
- `bash -n agent-system/extensions/core/scripts/git-commit-scoped.sh` exits 0
- The Phase 1 suite reports 0 failures — in particular T1 and T3, which were RED at Phase 1 close,
  are now `[PASS]`, and T5/T6/T7 remain `[PASS]`
- `git diff` shows no hunk inside `has_positive_pathspec`, either V3 gate, the V2 filter loop, or
  the commit-mutex block
- No task-number citations introduced

---

### Phase 3: Sync `git-staging-scope.md` with the Script [COMPLETED]

**Goal**: The standard's two `ephemeral_excludes` copies and its prose describe what the script now
actually does, including the conditional behavior and why it exists.

**Tasks**:
- [x] Update the "Canonical Runtime-File Exclusion Set" section: keep the four-entry array (the
      candidate set is unchanged) but rename/reframe it as the **candidate** set and add prose
      stating that `git-commit-scoped.sh` injects each entry only when `git check-ignore` reports
      the path is not already covered by `.gitignore`, because naming an already-ignored path in an
      explicit exclude pathspec aborts the whole `git add` whenever that path exists on disk.
      *(completed)*
- [x] Add the cross-reference the research recommended: point at
      `orchestrator-runtime-files.md`'s "gitignore coverage is the primary, sufficient control"
      statement, so a reader of this document alone learns the exclusion set is defense-in-depth
      rather than the primary control. *(completed)*
- [x] Update the second copy of the array in the "Reference Template" section (the `implement`
      template) consistently — either mirror the conditional logic or add an explicit note that the
      inline template is illustrative and that `git-commit-scoped.sh` is the sanctioned
      implementation which applies the conditional. Pick one and state it; do not leave the two
      copies asserting different behavior. *(completed: chose the explicit-note approach — the
      template array is unchanged/illustrative, with prose stating `git-commit-scoped.sh` is the
      sanctioned implementation and applies the conditional)*
- [x] Verify the candidate name set in both copies matches the script's loop byte-for-byte.
      *(completed: same four basenames, same order, in both standard copies and the script's
      `candidate_excludes` array)*

**Timing**: 45 minutes

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the standard publishes the array in exactly two places
(the research located them in the "Canonical Runtime-File Exclusion Set" and "Reference Template"
sections). Confirm by grepping for `.orchestrator-loop-guard` across the file and checking the hit
count matches the number of blocks edited — if a third copy exists, update it too rather than
leaving the asserted count unchallenged.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - both array copies plus
  conditional-behavior prose and the `orchestrator-runtime-files.md` cross-reference

**Verification**:
- Grep for `.orchestrator-loop-guard` in the standard; every hit sits in a block whose surrounding
  prose is consistent with the script's conditional behavior
- The four candidate names in the standard match those in the script's injection loop exactly
- No task-number citations introduced (this file is outside `specs/**`)

---

### Phase 4: Correct the False Trailing-Slash Workaround in Recorded Memory [COMPLETED]

**Goal**: No recorded memory or memory candidate keeps telling future agents that omitting the
trailing slash works, or proposes a workaround now superseded by the shipped fix.

**Tasks**:
- [x] Search for the false claim and for now-superseded workarounds across both memory surfaces:
      `.memory/**` (harvested vault memories) and `specs/state.json`'s `memory_candidates` arrays
      (unharvested candidates). Search on durable anchors — `trailing slash`, `:(exclude)`,
      `.lock/`, `paths are ignored`, `git-commit-scoped` — not on task numbers. *(completed:
      re-ran independently, see phase notes for the full result set)*
- [x] For each hit, decide correct-vs-purge and act:
      - A memory asserting the trailing-slash workaround **works** is factually false — purge it or
        rewrite the claim to state that the trailing slash is irrelevant and the trigger is the
        `:(exclude)` entry naming a gitignored path.
      - A memory proposing "stage individual subpaths instead of the directory glob" is a correct
        observation with a workaround that is now unnecessary — rewrite it to record the diagnosis
        (accurate and durable) and point at the shipped conditional-injection fix instead of the
        workaround. *(completed: rewrote `specs/state.json`'s project 967's sibling — project
        965's `memory_candidates[0]` — see phase notes)*
- [x] When editing `.memory/**` frontmatter, respect the category-7 exemption in
      `no-task-references-in-deliverables.md`: `topic`/`source` provenance fields keep their
      concrete values with an inline `# task-ref-ok` marker; only the prose body is purged of
      citations. *(not applicable: zero `.memory/**` hits found; the single correction was in
      `specs/state.json`, which is path-level exempt under category 1)*
- [x] Record in the phase notes exactly which entries were found, and which were corrected vs.
      purged. *(completed, see phase notes below)*

**Phase notes**: independent re-search (not the pre-plan grep) confirmed the Scope Hypothesis
exactly: **zero** `.memory/**` hits for `git-commit-scoped`, `trailing.slash`, or `:(exclude)`;
**zero** standalone recorded assertion anywhere in the repo that omitting the trailing slash
avoids the abort — the only hits for that phrase are inside this task's own problem-statement
text (`specs/state.json`/`specs/TODO.md`'s description field and this plan's own prose), which
*describes* the false claim as something to correct, never asserts it as fact; and **one**
unharvested `memory_candidates` entry (project 965, index 0, sourced from
`specs/965_skip_untracked_artifacts_in_undeclared_scripts_check/summaries/01_git-ls-files-enumeration-summary.md`)
whose diagnosis (the `:(exclude)`-names-a-gitignored-path abort mechanism) was accurate but whose
"Workaround: stage the task directory's specific subpaths … individually" sentence is now
superseded. Rewrote that entry's `content` field in place to keep the accurate diagnosis, state
plainly that the trigger was never a trailing slash, and point at the shipped
conditional-injection fix rather than the workaround. No `.memory/**` file was touched (none
existed on this topic) and no purge was needed (correct-in-place was sufficient for the one hit
found).

**Timing**: 30 minutes

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: A pre-plan scan found **one** relevant unharvested candidate (a
`git-commit-scoped.sh` `.lock/` exclude candidate whose diagnosis is accurate but whose proposed
workaround is "stage individual subpaths") and **zero** `.memory/**` vault hits and **zero**
recorded instances of the literal trailing-slash claim — even though the task description asserts
two agents recorded it. Treat all three counts as hypotheses, not facts: the claim may live in a
task artifact, a reflection field, or a vault memory the pre-plan grep did not reach. Re-run the
search independently across both surfaces before concluding, and if the trailing-slash claim
genuinely is not recorded anywhere, say so explicitly in the phase notes rather than silently
closing the phase as a no-op.

**Files to modify**:
- `specs/state.json` - correct or remove affected `memory_candidates` entries (path under
  `specs/**`, so task numbers are permitted here)
- `.memory/**` - any vault memory carrying the false or superseded claim (count unknown; see
  Scope Hypothesis)

**Verification**:
- A re-run of the same searches returns no surviving assertion that omitting the trailing slash
  avoids the abort
- Any surviving memory on this topic names the correct trigger (an `:(exclude)` entry naming a
  gitignored path) and the shipped fix, not the workaround
- `jq -e . specs/state.json` exits 0 (file still parses) if it was edited

---

### Phase 5: Deploy and Verify the Fix Is Live [COMPLETED]

**Goal**: The corrected script and the new suite reach the deployed `.claude/scripts/` tree, and
the defect is confirmed closed against the deployed copy — not just the source store.

**Tasks**:
- [x] Deploy the source store to `.claude/` using the sanctioned deploy path (do not hand-author
      any file under `.claude/**` — it is a regenerated artifact). *(completed:
      `bash .claude/scripts/deploy-headless.sh` — 303 artifacts deployed)*
- [x] Confirm `.claude/scripts/git-commit-scoped.sh` now contains the conditional injection loop
      and `.claude/scripts/tests/test-git-commit-scoped.sh` exists. *(completed: script updated by
      the headless deploy; test file required the documented workaround, see next task)*
- [x] If the known deploy-mechanism gap prevents either file from landing (already-loaded
      extensions can skip `copy_scripts`), report it loudly and use the documented workaround
      rather than editing `.claude/**` by hand as a substitute. If neither works, mark this phase
      `[BLOCKED]` with the specific failure — do not close it as done. *(completed: the gap DID
      fire — `deploy-headless.sh` updated the existing script but did not copy the brand-new
      `tests/test-git-commit-scoped.sh`, exactly the documented "already-loaded extensions skip
      copy_scripts for new files" gap. Worked around with a direct one-off invocation of the
      loader's copy primitives (`loader_mod.copy_scripts` + `loader_mod.copy_manifest` via
      `nvim --headless -u NONE -c "luafile ..."`), the same class of remedy already documented in
      `no-task-references-in-deliverables.md`'s "Discovered deploy-mechanism gap" section. No
      `.claude/**` file was hand-authored — both copies came from the loader's own copy
      functions reading the source store.)*
- [x] Run `bash .claude/scripts/tests/test-git-commit-scoped.sh` — the deployed copy of the suite
      exercising the deployed copy of the script. All cases must pass. *(completed: 7 passed, 0
      failed against the deployed copy)*
- [x] End-to-end live confirmation: with a `.lock/` present under a real task directory, run the
      deployed `git-commit-scoped.sh` for this task's own plan/implementation commit and confirm
      via `git log` that the commit actually landed (this task's research-phase commit already
      failed this way, so a successful commit here is direct evidence the defect is closed).
      *(completed: this task's own `specs/967_.../.lock/holder.json` was present and held for the
      entire implementation. An identical commit attempt against the PRE-fix deployed script
      failed with the exact documented abort (rc=2, "paths are ignored:
      specs/967_.../.lock"). After this phase's deploy, the SAME commit (accumulated Phases 1-4
      plus this phase's own progress files) landed successfully — `git log --oneline -1` shows
      commit `2e70e0114`, `git show --name-only HEAD` lists the task's tracked files with zero
      ephemeral runtime paths (`.lock/`, `.orchestrator-loop-guard`,
      `.orchestrator-churn-state.json`, `.drift-inspection.json`) present, and `.lock/holder.json`
      remains on disk untouched. Direct evidence the live defect is closed.)*

**Timing**: 30 minutes

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: This phase assumes the standard deploy path copies both an updated existing
script and a brand-new `scripts/tests/*.sh` file. `.claude/scripts/tests/` already holds four
suites, so the subdirectory path is live; but a documented loader gap exists for new files under
already-loaded extensions. Confirm both files' post-deploy content by reading them — do not infer
success from the deploy command's exit code alone.

**Files to modify**:
- None authored directly. `.claude/scripts/git-commit-scoped.sh` and
  `.claude/scripts/tests/test-git-commit-scoped.sh` are regenerated by the deploy process.

**Verification**:
- `.claude/scripts/git-commit-scoped.sh` contains `check-ignore` (deployed copy carries the fix)
- `.claude/scripts/tests/test-git-commit-scoped.sh` exists and `bash -n` clean
- `bash .claude/scripts/tests/test-git-commit-scoped.sh` exits 0 with zero `[FAIL]` lines
- A real scoped commit for this task lands (confirmed via `git log`) with a `.lock/` present

---

## Testing & Validation

- [x] `bash -n` clean on `git-commit-scoped.sh` and on the new test suite
- [x] The regression suite was observed RED (T1, T3) against the pre-fix script and GREEN after the
      fix — the mutation check `shell-script-testing.md` requires for a pattern-shaped fix
- [x] A commit lands with `.lock/` present, verified via `git log`/`git show --name-only`, not exit
      code alone
- [x] `.lock` is absent from that commit's file list
- [x] All four ephemeral paths stay out of the commit in a fully-covered repo (T3)
- [x] All four ephemeral paths stay out of the commit in an under-configured repo, via injected
      exclude entries (T5) — the literal VERIFICATION BAR reading
- [x] V3 exclude-only refusal still exits 2 with no commit (T6)
- [x] V2 unmatched-pathspec drop still warns and still commits the valid path (T7)
- [x] `specs/.commit-lock/` mutex code path untouched (verified by diff inspection)
- [x] Script and standard agree on the candidate name set
- [x] Deployed copy verified live (commit `2e70e0114`, this task's own `.lock/` present)

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (modified — conditional injection)
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` (new — regression suite)
- `agent-system/extensions/core/manifest.json` (modified — one `provides.scripts` entry)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` (modified — both array
  copies, conditional-behavior prose, cross-reference)
- `specs/state.json` and/or `.memory/**` (corrected memory records)
- Deployed `.claude/scripts/git-commit-scoped.sh` and `.claude/scripts/tests/test-git-commit-scoped.sh`
- `specs/967_fix_git_commit_scoped_lock_exclude_abort/summaries/01_*-summary.md` (implementation)

## Rollback/Contingency

Each phase is independently revertable and the changes are additive-or-local:

- **Phase 2 fix misbehaves**: revert the single injection-loop hunk in `git-commit-scoped.sh`. The
  script returns to today's behavior exactly — including the defect, but no new failure mode. The
  Phase 1 suite stays committed and simply goes RED again, which is a correct and informative
  state, not a broken one.
- **Phase 1 suite is flaky in CI/other environments**: the suite is a standalone file; unregister
  it from `manifest.json` while it is repaired. It has no runtime coupling to the pipeline.
- **Phase 3 doc edits**: pure documentation, revert freely.
- **Phase 4 memory edits**: `specs/state.json` is git-tracked; revert restores prior candidates.
- **Phase 5 deploy fails**: `.claude/**` is a disposable, regenerated artifact — re-running the
  deploy is the recovery path. Never hand-patch `.claude/**` as a rollback.
- **Escape hatch if the whole approach proves wrong**: Option A (drop the `.lock/` entry only)
  remains implementable as a one-line change and would close the specific live symptom while
  leaving the three documented hazards — take it only with explicit sign-off, and record the
  accepted gap as a follow-up task.
