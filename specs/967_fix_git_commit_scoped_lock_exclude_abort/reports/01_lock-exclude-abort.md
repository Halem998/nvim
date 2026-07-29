# Research Report: fix_git_commit_scoped_lock_exclude_abort

**Task**: 967 - fix_git_commit_scoped_lock_exclude_abort
**Started**: 2026-07-29
**Completed**: 2026-07-29
**Effort**: research only
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/git-commit-scoped.sh`,
  `agent-system/extensions/core/context/standards/git-staging-scope.md`,
  `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`,
  `agent-system/extensions/core/context/standards/shell-script-testing.md`, `.gitignore`
- Empirical reproduction: scratch git repository under the session scratchpad (deleted after use)
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The task description's core repro is **confirmed exactly**: `git add "<task_dir>/"
  ":(exclude)<task_dir>/.lock/"` fails with rc=1 ("paths are ignored by one of your .gitignore
  files") whenever `<task_dir>/.lock/` currently exists on disk, **regardless of whether the
  positive pathspec has a trailing slash**. The trailing-slash workaround already circulating in
  memory candidates is confirmed false and should be corrected/purged, exactly as the task states.
- **The task's stated scoping premise is empirically false and the fix must not be scoped as
  narrowly as the task assumes.** The task claims "the other three injected excludes name paths
  that are NOT gitignored, so they do not have this problem." All three of the other injected
  entries (`.orchestrator-loop-guard`, `.orchestrator-churn-state.json`, `.drift-inspection.json`)
  **are** gitignored (`.gitignore` lines 33/35/38) and were empirically reproduced to trigger the
  **identical** rc=1 abort when the named path exists on disk at commit time. Per
  `orchestrator-runtime-files.md`'s Class Table, none of these three are cleaned up until full-loop
  termination (Stage 8), so — by the same MT-4-step-5.5-before-step-6 ordering argument the task
  makes for `.lock/` — they are just as likely to be present at a live per-task commit.
- The project's own standard already states the resolution direction: `orchestrator-runtime-files.md`
  says gitignore coverage "is the primary, sufficient control" and the `git-staging-scope.md`
  exclude pathspecs are "defense-in-depth for a repo that has not yet applied this block... A repo
  with full coverage above is protected purely by gitignore, regardless of what any automated `git
  add` stages." This repo has full coverage (verified) and none of the four ephemeral names are
  ever git-tracked (verified via `git ls-files`), so the exclude injection is currently pure
  downside for this repo: redundant when the path doesn't exist, and abort-triggering when it does.
- Recommended fix direction: make exclude injection conditional on `git check-ignore -q` for each
  candidate path (verified to work without requiring the path to exist), rather than either (a)
  dropping only `.lock/` (leaves the identical hazard on the other three) or (b) dropping the whole
  injection unconditionally (removes defense-in-depth for a consumer repo that has not applied the
  `.gitignore` block documented in `orchestrator-runtime-files.md`'s "Consumer Repo Setup"). This
  directly conflicts with the task's literal VERIFICATION BAR wording ("still excludes the other
  three ephemeral runtime files") for a fully-gitignore-covered repo like this one — flagged below
  for the planner to resolve explicitly rather than silently pick one reading.
- No committed regression test for `git-commit-scoped.sh` exists today. `shell-script-testing.md`
  gives an exact, settled location/naming/registration convention for the new test:
  `scripts/tests/test-git-commit-scoped.sh`, registered in `manifest.json`'s `provides.scripts` as
  `tests/test-git-commit-scoped.sh`.

## Context & Scope

Researched the actual current state of `git-commit-scoped.sh` (the injection block and the `git
add` failure path), the mirrored `ephemeral_excludes` array in `git-staging-scope.md`, empirically
reproduced the pathspec-abort behavior described in the task (including the claimed trailing-slash
workaround, which was verified false), and additionally checked whether the task's premise that
only `.lock/` has this problem holds up — it does not. Also surveyed the project's own
`orchestrator-runtime-files.md` standard (which the task did not cite) for guidance already agreed
upon regarding gitignore-vs-staging-narrowing tradeoffs, and the `shell-script-testing.md`
convention for where/how the required regression test should be added. Implementation is out of
scope for this report.

## Findings

### Codebase Patterns

**`git-commit-scoped.sh` injection site** (lines 120-139, current source-store copy):

```bash
# --- Inject the canonical ephemeral-runtime-file exclusion set for any task-directory entry ---
expanded_pathspecs=()
for p in "${pathspecs[@]}"; do
  expanded_pathspecs+=("$p")
  case "$p" in
    specs/[0-9][0-9][0-9]_*/)
      task_dir="${p%/}"
      expanded_pathspecs+=(
        ":(exclude)${task_dir}/.orchestrator-loop-guard"
        ":(exclude)${task_dir}/.orchestrator-churn-state.json"
        ":(exclude)${task_dir}/.drift-inspection.json"
        ":(exclude)${task_dir}/.lock/"
      )
      ;;
  esac
done
pathspecs=("${expanded_pathspecs[@]}")
```

Note the `case` pattern `specs/[0-9][0-9][0-9]_*/` requires a **trailing slash** on the positive
entry to match at all — the injection itself only fires for a directory-style positional pathspec.
This is unrelated to the (debunked) trailing-slash workaround claim; it governs whether the
injection block runs, not whether the resulting `git add` succeeds.

The failing `git add` call (line 199):

```bash
if ! git add "${pathspecs[@]}"; then
  echo "WARNING: git add failed for one or more staged paths (non-blocking); no commit was attempted." >&2
  exit 2
fi
```

The V2 safety-gate comment (lines 141-144) explicitly documents that exclude pathspecs are passed
through **unvalidated**: "Exclude pathspecs pass through unvalidated (git itself never resolves
them against the working tree the way it does a positive entry, and validating them would require
reimplementing git's own pathspec-exclusion matching)." This is the actual gap — the script
validates positive entries against disk/`git ls-files` but never checks whether an exclude entry
names an already-gitignored, currently-existing path, which is exactly the condition that aborts
`git add`.

**`git-staging-scope.md`'s mirrored array** (lines 25-31 and again at 137-142, the "Reference
Template" copy) is byte-identical to the script's injected list. Both copies must be updated
together if the fix changes which entries are unconditionally injected — the script's own comment
(line 121-123) explicitly claims to mirror this file "exactly."

### Empirical Verification (reproduced in an isolated scratch git repo, not code review)

All four commands below were run against a real git repository (not `--dry-run` unless noted), with
a `.gitignore` matching the four `ephemeral_excludes` patterns exactly as they appear in
`git-staging-scope.md` and this repo's actual root `.gitignore`.

1. **Task's exact repro, confirmed**:
   ```
   git add "specs/999_probe/" ":(exclude)specs/999_probe/.lock/"   # .lock/ exists -> rc=1
   git add "specs/999_probe/"                                       # (no exclude)   -> rc=0
   ```
2. **Trailing-slash workaround, confirmed FALSE** (matches the task's own debunking):
   ```
   git add "specs/999_probe" ":(exclude)specs/999_probe/.lock/"    # no trailing slash -> rc=1, identical error
   ```
3. **New finding — same abort reproduces for the other three canonical excludes**, when the named
   file actually exists on disk at commit time:
   ```
   git add "specs/999_probe/" \
     ":(exclude)specs/999_probe/.orchestrator-loop-guard" \
     ":(exclude)specs/999_probe/.orchestrator-churn-state.json" \
     ":(exclude)specs/999_probe/.drift-inspection.json" \
     ":(exclude)specs/999_probe/.lock/"
   # -> rc=1, "The following paths are ignored by one of your .gitignore files:" listing all three
   #    existing entries (drift-inspection.json, orchestrator-churn-state.json, orchestrator-loop-guard)
   ```
   `git ls-files | grep -E '\.orchestrator-loop-guard|\.orchestrator-churn-state\.json|\.drift-inspection\.json|/\.lock/'`
   against the real repo returns **zero** matches — none of the four names are, or ever were,
   git-tracked, so there is no "already-tracked-then-ignored" scenario motivating a special case
   for any one of the four over the others.
4. **Dropping the exclude(s) entirely is safe and sufficient when `.gitignore` covers the path**:
   with **no** exclude entries injected at all, and all four ephemeral files/dirs present on disk,
   `git add "specs/999_probe/"` succeeds (rc=0) and stages **only** the tracked file — none of the
   four gitignored ephemeral paths get staged. This confirms git's own behavior: an ignored path
   swept up implicitly by a directory pathspec is silently skipped; the abort only fires when an
   ignored path is **explicitly named** in the pathspec (as every `:(exclude)...` entry does).
   `git add --ignore-errors` does not change this: it still returns rc=1 on the ignored-path
   warning, but (like the plain non-`--ignore-errors` call) still stages the other paths it can —
   confirming the abort is purely an exit-code/gate issue in the calling script, not evidence that
   nothing gets staged.
5. **`git check-ignore` correctly identifies all four ephemeral patterns without the path needing
   to exist** — useful for a conditional-injection fix (see Decisions below):
   ```
   git check-ignore -q "specs/999_probe/.lock/"                              # -> ignored (exit 0)
   git check-ignore -q "specs/999_probe/.orchestrator-loop-guard"            # -> ignored
   git check-ignore -q "specs/999_probe/.orchestrator-churn-state.json"      # -> ignored
   git check-ignore -q "specs/999_probe/.drift-inspection.json"              # -> ignored
   # all four still report "ignored" even when the file/dir does not exist on disk
   ```

### Cross-Reference: `orchestrator-runtime-files.md` (not cited by the task, directly relevant)

This standard is the authority `git-staging-scope.md` itself points back to for the ephemeral/
durable split, and it already states the resolution direction for this exact tension (lines
134-137):

> "**This gitignore coverage is the primary, sufficient control.** The staging-narrowing described
> in `git-staging-scope.md` is defense-in-depth for a repo that has not yet applied this block —
> it does not replace it. A repo with full coverage above is protected purely by gitignore,
> regardless of what any automated `git add` stages."

This repo's root `.gitignore` (lines 32-38) already carries the full documented block (`.lock/`,
`.orchestrator-loop-guard`, `.orchestrator-churn-state.json`, `.drift-inspection.json`, plus
several more not in the `ephemeral_excludes` array at all — `.continuation-loop-guard`,
`.postflight-loop-guard`, `.orchestrator-multi-state*.json`, `.return-meta-*.json`, `.events.lock`,
`.sessions/`). Per the standard's own words, this repo is "protected purely by gitignore" already
— the `ephemeral_excludes` injection buys this repo nothing it doesn't already have, while costing
it the abort defect.

The standard also documents the **only** legitimate reason the exclude entries exist at all: a
consumer repo that has **not yet** applied the manual "Consumer Repo Setup" `.gitignore` block
(deployment cannot push root-`.gitignore` contributions automatically — see that section's
explanation of why `specs/.sessions/` in particular can only be covered by the consumer's own root
`.gitignore`). This is the tradeoff any fix must weigh: dropping the injection unconditionally is
safe for a fully-configured repo (this one) but is a real regression for an under-configured
consumer repo, in which `.lock/`/the other three would start getting silently staged and committed
by a bare directory-pathspec `git add` the moment a task lock (or churn/drift state) happens to be
present at commit time.

### External Resources

Not applicable — this is a pure git pathspec-semantics question, fully resolved by empirical
reproduction against the actual git binary in this environment; no external documentation lookup
was needed or performed.

## Decisions

Framed as options for the planner to choose between, since the task's own scoping premise
(disproven above) and its VERIFICATION BAR wording pull in different directions:

**Option A — Literal reading of the task: drop only the `.lock/` exclude entry.**
Satisfies the task's literal repro and its VERIFICATION BAR line "a commit with no `.lock` present
still succeeds and still excludes the other three ephemeral runtime files" verbatim. **Known gap**:
leaves the byte-identical abort hazard live for `.orchestrator-loop-guard`,
`.orchestrator-churn-state.json`, and `.drift-inspection.json` — all three are gitignored, none are
cleaned up until full-loop termination (Stage 8, per `orchestrator-runtime-files.md`'s Class
Table), and the same "commit runs before lock release, so the ephemeral file is present by
construction" argument the task makes for `.lock/` applies to at least the loop guard and churn
state (both are per-batch, multi-cycle scratch files, not per-commit). This is provably an
incomplete fix, not a defect in the task author's judgment — it is a premise that was asserted but
not verified before being handed off.

**Option B — Drop the entire `ephemeral_excludes` injection unconditionally.**
Matches `orchestrator-runtime-files.md`'s own stated position that gitignore coverage is
"primary, sufficient" and the exclude pathspecs are redundant defense-in-depth. Provably restores
rc=0 for every one of the four ephemeral paths in *this* repo (empirically verified, finding 4
above) while never staging any of them (also verified). **Known gap**: silently removes
defense-in-depth for a consumer repo that has not applied the `.gitignore` block — in such a repo,
`git-commit-scoped.sh` is shared/deployed code, so a pre-migration repo would start actually
committing `.lock/`/loop-guard/churn-state/drift-inspection files. Also directly and permanently
falsifies the task's VERIFICATION BAR wording ("still excludes the other three ephemeral runtime
files") for this repo, since post-fix `git add` calls here would carry zero injected exclude
entries at all.

**Option C — Conditional injection: only append a `:(exclude)...` entry for a candidate path that
`git check-ignore -q` reports is NOT already covered by `.gitignore`.**
Combines A and B's benefits: in a fully-covered repo (this one), all four candidates are detected
as already-ignored, so **zero** exclude entries get injected — reproduces Option B's rc=0 outcome
for all four paths with no abort risk, ever, regardless of which one currently exists on disk. In
an under-configured consumer repo, the exclude entries are injected exactly as today, preserving
current defense-in-depth behavior unchanged. `git check-ignore -q` was verified to work correctly
without requiring the candidate path to exist (finding 5 above), so this check can run
unconditionally before the path is created. **Cost**: up to 4 extra `git check-ignore` subprocess
calls per task-directory pathspec match (negligible), and it means the injected pathspec list is no
longer a static function of the task directory name alone — a minor increase in script complexity
over Option A/B. Also conflicts with the VERIFICATION BAR's literal wording in the same way Option
B does, for a fully-covered repo.

**Option D — Keep exclude entries unconditionally; treat `git add`'s failure as non-fatal when
it is solely the known "ignored by .gitignore" advisory.**
Not recommended. Requires parsing `git add`'s stderr text for the advisory string (git-version-
dependent, already observed to include a config-toggleable hint line —
`git config set advice.addIgnoredFile false` — meaning the message text itself is not guaranteed
stable across git versions/configs). Also does not remove the risk that a *legitimate* `git add`
error (a genuinely broken pathspec, a corrupted index) gets silently swallowed alongside the
advisory one, since both currently produce rc=1 through the same code path. Empirically, `git add`
already stages every non-problematic path even when it returns rc=1 for the ignored-path warning
(finding 4), so the "non-fatal" reclassification is mechanically sound, but it is a strictly worse
approach than A/B/C on robustness-to-git-version grounds.

**Recommendation for the planner**: Option C is the technically strongest general-purpose fix and
is the one this report recommends, but the planner MUST explicitly reconcile it against the task's
literal VERIFICATION BAR wording before proceeding — either (1) implement Option C and treat the
VERIFICATION BAR's "still excludes the other three ephemeral runtime files" as satisfied in
*outcome* (never staged) rather than literal pathspec presence, updating the regression test's
assertion accordingly, or (2) get explicit sign-off to implement the narrower Option A instead and
accept the known, documented gap for the other three entries as an out-of-scope follow-up. Do not
silently pick one without surfacing this tension, since the task text and the empirical evidence
disagree.

Whichever option is chosen, `git-staging-scope.md`'s two copies of the `ephemeral_excludes` array
(lines 25-31 and 137-142) MUST be kept in sync with whatever the script now does — if Option C is
chosen, the standard's prose needs a note explaining the conditional-on-check-ignore behavior, not
just a code diff, since the standard's current text asserts these are unconditionally injected.

## Risks & Mitigations

- **Risk**: any fix that changes which pathspec entries get passed to `git add` could interact with
  the V2/V3 safety gates (lines 102-118, 141-167) if implemented carelessly (e.g. accidentally
  producing a pathspec list with zero positive entries, or accidentally validating an exclude entry
  as if it were positive). **Mitigation**: the fix should only touch the injection loop (lines
  124-139); it must not alter `has_positive_pathspec()`, the V2 filter loop, or the V3 gates, and
  the regression test must assert those gates are unaffected (e.g. a positive task-dir entry is
  still required and still present after the fix).
- **Risk**: `git-staging-scope.md`'s two array copies drifting from the script again, repeating the
  exact staleness gap the script's own comment (lines 121-123) says it was written to close ("nine
  of eleven [call sites] never received the canonical exclusion set after it was added to this
  document"). **Mitigation**: update both copies in the same change, and note in the standard why
  they may differ in *behavior* (conditional vs. unconditional) even if the *set of candidate
  names* stays identical.
- **Risk**: weakening the commit-mutex or V2/V3 gates while touching this code (explicitly
  prohibited by the task). **Mitigation**: none of the options above touch the
  `specs/.commit-lock/` mutex block (lines 169-196) or the V2/V3 gates; this report found no reason
  any option would need to.
- **Risk**: a regression test that merely asserts rc=0 could pass without actually exercising the
  original bug (per `shell-script-testing.md`'s "Mutation checks" guidance) if it doesn't first
  fail against the pre-fix script. **Mitigation**: the planner should require the new test to be
  run once against the unmodified (pre-fix) `git-commit-scoped.sh` to confirm it goes red before
  the fix lands, then re-run green after — mirroring the standard's explicit guidance for
  regex/pattern-shaped fixes, which this qualifies as (a pathspec-construction fix).

## Context Extension Recommendations

- **Topic**: `git-staging-scope.md`'s "Canonical Runtime-File Exclusion Set" section does not
  currently cross-reference `orchestrator-runtime-files.md`'s "gitignore is primary, sufficient
  control" statement, even though the two documents describe the same four (well, `.lock/` plus
  three others; `orchestrator-runtime-files.md`'s ephemeral class has more entries not covered by
  `ephemeral_excludes` at all) paths from complementary angles.
  **Gap**: a future reader of `git-staging-scope.md` alone would not learn that the exclusion set
  is *defense-in-depth*, not the primary control, and could be misled into treating any future
  abort here (as this task did) as scoped to whichever single entry happened to reproduce first.
  **Recommendation**: add a short cross-reference note in `git-staging-scope.md`'s "Canonical
  Runtime-File Exclusion Set" section pointing at `orchestrator-runtime-files.md`'s "primary,
  sufficient control" language, so the redundancy (and its abort-hazard cost when an exclude entry
  names an existing ignored path) is visible from both documents. This is a documentation gap
  discovered as a side effect of this research, not itself part of the requested fix; note it for
  the planner to decide whether to fold into this task's diff or leave as a follow-up.

## Appendix

### Reproduction commands (representative; full sequence run and cleaned up in session scratchpad)

```bash
git init && git config user.email t@t.com && git config user.name t
mkdir -p specs/999_probe && echo hello > specs/999_probe/file.txt
git add specs/999_probe/file.txt && git commit -q -m init
printf '**/.lock/\n**/.orchestrator-loop-guard\n**/.orchestrator-churn-state.json\n**/.drift-inspection.json\n' > .gitignore
git add .gitignore && git commit -q -m gitignore
mkdir -p specs/999_probe/.lock && echo x > specs/999_probe/.lock/holder.json
echo more >> specs/999_probe/file.txt

git add --dry-run "specs/999_probe/"  ":(exclude)specs/999_probe/.lock/"   # rc=1 (ignored)
git add --dry-run "specs/999_probe"   ":(exclude)specs/999_probe/.lock/"   # rc=1 (identical -- trailing slash irrelevant)
git add --dry-run "specs/999_probe/"                                       # rc=0 (no exclude entry)
git check-ignore -q "specs/999_probe/.lock/"                               # exit 0 (ignored), works even if path absent
```

### Files examined

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (injection block: lines 120-139;
  `git add` call: line 199; V2/V3 gates: lines 102-167; commit-mutex block: lines 169-196)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` (`ephemeral_excludes`
  array: lines 25-31 and 137-142)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (Class Table:
  lines 24-39; "primary, sufficient control" statement: lines 134-137; Consumer Repo Setup: lines
  101-130)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (location/naming/
  registration/mutation-check conventions for the required new test)
- `.gitignore` (repo root; lines 32-38 confirm all four `ephemeral_excludes` paths are covered)
- `agent-system/extensions/core/manifest.json` (`provides.scripts` array — registration point for
  a new `tests/test-git-commit-scoped.sh`; `git-commit-scoped.sh` already registered at line 114)
- Callers of `git-commit-scoped.sh` surveyed for blast radius (not modified/read in depth):
  `agents/general-implementation-agent.md`, `agents/general-implementation-hard-agent.md`,
  `commands/orchestrate.md`, `context/patterns/batch-orchestration-guardrails.md`,
  `context/patterns/task-lock.md`, `docs/architecture/orchestrate-state-machine.md`,
  `scripts/deploy-headless.sh`, `scripts/orchestrator-postflight.sh`, `scripts/task-lock.sh`,
  `skills/skill-implementer/SKILL.md`, `skills/skill-orchestrate/SKILL.md`,
  `skills/skill-planner/SKILL.md`, `skills/skill-team-implement/SKILL.md`
