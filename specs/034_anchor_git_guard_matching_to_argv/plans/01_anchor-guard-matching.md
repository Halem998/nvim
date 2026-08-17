# Implementation Plan: anchor_git_guard_matching_to_argv

- **Task**: 34 - anchor_git_guard_matching_to_argv
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None (explicitly independent of the orchestrator run-state work)
- **Research Inputs**: `specs/034_anchor_git_guard_matching_to_argv/reports/01_anchor-guard-matching.md`
- **Artifacts**: plans/01_anchor-guard-matching.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`guard-destructive-git.sh` false-positives on ordinary, non-destructive `git commit` calls whose
free-text `-m` message merely *mentions* destructive git wording. Research confirmed two
independently-necessary root causes and one additional live defect, and verified a fix
architecture end-to-end by reproduction: strip quoted spans from the entire (possibly multi-line)
`$COMMAND` **once, up front**, in slurp mode, then point all seven detectors at that single
stripped string. The definition of done is that fix, plus a `#`-comment strip closing the
`--staged` false-exemption inverse, plus the repository's first regression suite for this hook —
proven non-vacuous by a mutation check and passing in both source-store and deployed modes.

### Research Integration

The plan is built directly on the verified findings in `reports/01_anchor-guard-matching.md`; it
does not re-derive them. Load-bearing findings carried forward:

- **Cause 1 (confirmed, reproduced)**: the `seg_scan` quote-strip at lines 80 and 99 is
  line-based. `grep -oE` never matches across a newline, so a multi-line `-m` message yields a
  segment whose opening `"` is never closed on any single line, and `sed -e 's/"[^"]*"/""/g'`
  strips nothing. The first line of the message — i.e. the commit subject — is then flag-scanned
  as if it were argv.
- **Cause 2 (confirmed, reproduced)**: `(^|[^-])-[a-zA-Z]*a[a-zA-Z]*([[:space:]]|$)` matches any
  hyphenated word with an `a` after the hyphen. `essential-refactor`, `auto-repair`, `multi-task`
  all match; `un-edged`, `repo-wide` do not — which is why the failure looked intermittent.
- **Fix architecture (verified by reproduction, not proposed)**: one upfront slurp-mode strip
  applied to the whole `$COMMAND`, all seven detectors repointed at it, the two now-redundant
  per-segment strips deleted. Reproduction confirmed this simultaneously (a) closes the multi-line
  false positive, (b) preserves every true positive — real flags are never inside quotes, and
  (c) keeps the `--staged` inverse-hazard closed rather than opening a bypass.
- **Cause 2 is deliberately NOT tightened** in this change. Every reproduced trigger lived inside
  a quoted `-m` argument, so the upfront strip removes it before the flag regex ever runs.
  Tightening the regex is a separate problem with its own false-negative surface.
- **Additional live defect (found during research, in scope)**: a bash `#` comment sharing a
  segment with a real `git restore <path>` — e.g. `git restore foo.txt # use --staged next time`
  — is not quote-delimited, so its literal `--staged` falsely exempts a genuinely destructive
  restore today, and would continue to after the quote-strip alone. Closed here by one additional
  per-line comment-strip clause, ordered strictly after the quote-strip.
- **`run-all.sh` needs zero code changes** — it glob-discovers `test-*.sh` in both modes. The one
  real registration step is `manifest.json`'s `provides.scripts` array.
- **Suite conventions**: model on `test-validate-no-task-references.sh` — subprocess + JSON on
  stdin + assert on **exit code** (2 = blocked, 0 = allowed), never stdout.
- **Vacuity hazard**: line 63 exits 0 whenever `git status --porcelain` is empty *or errors*
  (stderr discarded), so a suite run outside a git repo or against a clean tree passes every case
  for the wrong reason. Every BLOCK-expecting case must run inside a freshly created, genuinely
  dirty git repo.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- Anchor destructive-pattern matching to argv flags and subcommands, not free-text message
  content, by stripping quoted spans from the whole multi-line command once, before any
  segment extraction or flag scan.
- Extend that protection to all seven detectors, including the five in the destructive chain that
  currently grep entirely raw text.
- Close the `--staged` false-exemption inverse in both its quoted form and its `#`-comment form.
- Preserve every currently-detected destructive form; open no bypass. Test both directions.
- Create the repository's first regression suite for this hook, prove it non-vacuous via a
  mutation check, and have it pass in both source-store and deployed modes.
- Update the hook's header comments to describe the actual post-fix matching contract.

**Non-Goals**:
- **Tightening the Cause-2 flag regex.** Explicitly out of scope per the research decision: the
  architectural fix already satisfies every stated acceptance criterion for Cause 2's symptoms,
  and tightening it correctly is a separate, riskier regex-design problem.
- **Making `[^;&|]*` segment splitting quote-aware.** Explicitly out of scope and to be recorded
  as such in the implementation summary. Neither live firing traces to it; a correct fix needs a
  real tokenizer applied consistently across all seven detectors, which is a materially larger and
  separately-reviewable change; and no acceptance criterion names it.
- Any change to `run-all.sh` (none is needed).
- Any change to the snapshot-marker exemption mechanism or the over-staging no-exemption policy.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Moving the strip upstream silently changes over-staging detector behavior for cases the per-segment strip handled differently | H | M | Phase 1 pins the existing over-staging true/false-positive behavior as green cases against the *unmodified* hook, before Phase 3 deletes the per-segment `sed` calls. Any drift shows up as a Phase 3 regression, not a silent change. |
| Suite constructs its git fixture wrongly and every case passes vacuously via the clean-tree/non-repo early exit | H | M | Phase 1 includes an explicit fixture self-check meta-case asserting the fixture repo reports a non-empty `git status --porcelain` before any hook case runs; a broken fixture fails loudly. |
| Suite is written to pass and never proven capable of failing | H | M | Two independent proofs: Phase 2 runs the defect cases against the unmodified hook and records the RED set; Phase 6 performs the formal revert/restore mutation cycle. |
| The comment-strip clause over-strips a legitimate unquoted `#` (branch or path name) | M | L | Anchor the clause to `#` preceded by start-of-line or whitespace, run it strictly after the quote-strip (so quoted `#` is already neutralized), and add a Phase 2 case asserting a real destructive command containing an unquoted `#`-in-path is still blocked. |
| **Self-referential hazard**: this task's own commits, plans, and fixtures discuss destructive git and can trip the very guard being fixed, before the fix lands | M | H | For Phases 1-2 (pre-fix), use single-line commit subjects and avoid hyphenated words with an `a` after the hyphen in the subject. If blocked anyway, record the exact trigger command verbatim as additional evidence in the summary rather than treating it as an obstacle. |
| Deployed-mode verification requires regenerating `.claude/` | M | L | `.claude/` is a gitignored, disposable deploy artifact by design; regenerating it via the sanctioned `scripts/deploy-headless.sh` is not a boundary violation. A flat-tree simulation under `mktemp -d` is the fallback if the deploy is not runnable non-interactively. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Suite scaffold, dirty-repo fixture, and baseline green cases [COMPLETED]

**Goal**: Stand up `test-guard-destructive-git.sh` with a correct, self-checking dirty-git-repo
fixture, and pin the hook's *current* correct behavior (the two over-staging detectors and the
plainly-destructive true positives) as passing cases against the unmodified hook.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`, modeled
      on `test-validate-no-task-references.sh`: `pass()`/`fail()`/`info()` helpers, integer
      `PASSED`/`FAILED` counters, `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`,
      `mktemp -d` workdir with `trap '...' EXIT` cleanup, exit 0 iff `FAILED` is 0 else exit 1.
      *(completed)*
- [x] Resolve the hook under test as `$SCRIPT_DIR/../../hooks/guard-destructive-git.sh`. This
      single relative path is what makes acceptance criterion 5 work: it resolves to
      `agent-system/extensions/core/hooks/` in source-store mode and to `.claude/hooks/` in
      deployed mode with no branching. Fail loudly if the resolved path does not exist.
      *(completed)*
- [x] Implement the fixture helper: create a fresh `git init` repo under the workdir, configure
      `user.email`/`user.name` locally, create and commit one file, then modify it so the tree is
      genuinely dirty. Ensure no `.git-snapshot-marker` exists anywhere under a `specs/` path
      reachable from the fixture cwd. *(completed: make_dirty_repo/make_clean_repo, each own mktemp -d under WORKDIR)*
- [x] Implement the case runner: build the payload with `jq -n --arg c "$cmd"
      '{tool_input:{command:$c}}'`, pipe it on stdin to `bash "$HOOK"` executed with cwd inside
      the fixture repo, capture the exit code, and assert on the **exit code only**
      (2 = blocked, 0 = allowed). Never assert on stdout. *(completed: run_hook_in)*
- [x] Add the fixture self-check meta-case FIRST: assert `git status --porcelain` inside the
      fixture is non-empty. A broken fixture must fail loudly rather than let every later case
      pass via the clean-tree exemption. *(completed)*
- [x] Add the two complementary exemption meta-cases: the same destructive command run against a
      *clean* fixture repo must exit 0, and an empty command must exit 0. *(completed)*
- [x] Add baseline green cases against the unmodified hook: over-staging true positives
      (`git add -A`, `git add --all`, `git add .`, `git commit -am "msg"`, `git commit -a`),
      the already-working single-line over-staging false-positive exemption
      (`git commit -m "fix -a bug"` must be allowed), and one true positive per destructive
      detector (`git reset --hard`, `git checkout -- foo.txt`, `git restore foo.txt`,
      `git clean -fd`, `git stash drop`, `git stash clear`, `git switch -f other`).
      *(completed)*
- [x] Add the safe-form allow cases: `git restore --staged foo.txt`, `git stash`, `git stash pop`,
      `git checkout other-branch` (non-forced), plain `git commit -m "msg"`. *(completed)*
- [x] `chmod +x` the suite. Run it against the unmodified hook and confirm every case in this
      phase is GREEN — this phase adds no failing cases. *(completed: 20/20 baseline + 3 meta
      cases green against the unmodified hook)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts a fixture-correctness precondition (the hook's line-63
early exit makes an incorrectly-built fixture pass every case vacuously) and a baseline case set
covering seven destructive detectors plus two over-staging detectors. Confirm at implementation
time by running the completed suite against the unmodified hook and observing a non-zero PASSED
count with FAILED == 0, and by temporarily commenting out the fixture's dirtying step to check
that the self-check meta-case goes RED (restore immediately after).

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` - new file

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` exits 0 with all
  cases passing against the unmodified hook.
- The fixture self-check case is the first case reported.

---

### Phase 2: Defect-exposing cases, run RED against the unmodified hook [COMPLETED]

**Goal**: Add every case the fix must turn green, run them against the still-unmodified hook, and
record the observed RED set as the pre-fix half of the mutation evidence.

**Tasks**:
- [x] Add the observed false positive verbatim: a multi-line `git commit -m "..."` whose subject
      line contains `essential-refactor`, followed by blank line and body paragraphs. Expect
      ALLOWED (exit 0). *(completed)*
- [x] Add the single-line control for the same text (currently passes) so the multi-line/single-line
      asymmetry is visible in the suite output. *(completed)*
- [x] Add hyphenated-prose cases, single-line AND multi-line, for `essential-refactor`,
      `auto-repair`, `multi-task`. Expect ALLOWED. Add `un-edged` and `repo-wide` as
      already-passing controls. *(completed)*
- [x] Add one message-text false-positive case per vulnerable destructive detector, expecting
      ALLOWED. *(completed: deviation — original literal phrasing from this checklist,
      `-m "revert the git reset --hard fallout"` etc., reproduced GREEN pre-fix, not RED — these
      five raw-`$COMMAND` detectors anchor on `(^|[;&|][[:space:]]*)`, start-of-string or a
      literal `;`/`&`/`|` character, not arbitrary preceding prose. Replaced with
      semicolon-punctuated message text, e.g. `-m "See the notes below; git reset --hard discards
      local changes"`, which reproduces RED for all five detectors; see progress file
      `approaches_tried`.)* Included a multi-line variant of the `git clean` and forced-switch
      cases. *(completed)*
- [x] Add the `--staged` quoted false-exemption case: `git restore foo.txt; echo "note: use
      --staged next time"`. Expect BLOCKED — the quoted `--staged` must not exempt the real
      restore. *(completed — confirmed already GREEN/blocked pre-fix, a no-bypass regression
      guard rather than a RED defect case)*
- [x] Add the `#`-comment false-exemption case: `git restore foo.txt # use --staged next time`.
      Expect BLOCKED. This is the additional in-scope defect. *(completed)*
- [x] Add the comment-strip over-reach guard: a genuinely destructive command containing an
      unquoted `#` outside a comment position (e.g. a path or ref containing `#`) must still be
      BLOCKED. *(completed)*
- [x] Add the no-bypass-opened direction explicitly: a real `git clean -fd` and a real
      `git commit -am "msg"` must remain BLOCKED when the message spans multiple lines; a real
      destructive command must not become allowed by adding a quoted argument alongside it
      (e.g. `git reset --hard HEAD~1 && echo "done"` stays BLOCKED). *(completed)*
- [x] Run the suite. Record, in the phase notes and later in the summary, the exact list of cases
      that are RED against the unmodified hook. A case expected to expose the defect but observed
      GREEN pre-fix is a defective case, not evidence — fix the case before proceeding.
      *(completed: RED set is exactly 11 cases — multi-line essential-refactor/auto-repair/
      multi-task (3), the five semicolon-punctuated per-detector message cases plus their 2
      multi-line variants (7), and the #-comment --staged false-exemption case (1). All 32
      remaining cases (Phase 1 baseline + no-bypass guards) GREEN. No defective case found.)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts that each of the five vulnerable destructive detectors
plus the over-staging commit detector has at least one reproducible message-text false positive,
and that the two false-exemption forms both currently fire. Confirm at implementation time by the
recorded RED set: every defect case listed above must be observed RED (or, if any is observed
GREEN pre-fix, investigate and either correct the case or record why that specific detector is not
in fact reachable — do not silently drop it).

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` - add defect cases

**Verification**:
- Suite exits 1 against the unmodified hook, with the RED set matching the defect cases and every
  Phase 1 baseline case still GREEN.
- The recorded RED set is written into the phase notes for reuse in Phase 6.

---

### Phase 3: Upfront multi-line quote-strip plus comment-strip; repoint all seven detectors [COMPLETED]

**Goal**: Land the verified fix architecture in `guard-destructive-git.sh` and turn the Phase 2
RED set green without regressing any Phase 1 baseline case.

**Tasks**:
- [x] Immediately after the clean-tree early exit (currently ending at line 65) and before the
      over-staging detectors, construct the single stripped scan string.
      *(deviation: altered — the plan's literal `:a;N;$!ba` N-loop idiom was implemented first,
      verbatim, and then disproved by direct reproduction: GNU sed's `N` command, invoked on a
      line that is already the LAST line of input (true of any genuinely single-line command —
      the common case), finds no next line to append, auto-prints the pattern space unmodified,
      and terminates the script without ever reaching the substitution. This left ordinary
      single-line commands like `git commit -m "fix -a bug"` completely unstripped, regressing a
      Phase 1 baseline case. Replaced with `sed -z` (NUL-delimited "lines"): with no NUL byte in
      the input, the whole command — single- or multi-line alike — is one record, and the
      substitution runs exactly once over all of it in a single pass, with no last-line special
      case. Re-verified against the full Phase 1 + Phase 2 case set after the substitution:
      43/43 green, matching the architecture's intended behavior exactly.)*
      ```bash
      COMMAND_SCAN=$(printf '%s' "$COMMAND" \
        | sed -z -e 's/"[^"]*"/""/g' -e "s/'[^']*'/''/g" \
        | sed -e 's/\(^\|[[:space:]]\)#.*$//')
      ```
      The first `sed` (`-z`) treats the whole command as one record, so a quoted span containing
      newlines is treated as one logical span regardless of line count. The second runs per-line
      — correct, because a bash comment runs to end of line — and is ordered strictly AFTER the
      quote-strip so a `#` inside a quoted string has already been neutralized and cannot be
      mistaken for a comment marker.
- [x] Repoint the two over-staging detectors: `ADD_SEGMENTS` and `COMMIT_SEGMENTS` extract from
      `$COMMAND_SCAN` instead of `$COMMAND`. *(completed)*
- [x] Delete the now-redundant per-segment `seg_scan` `sed` calls (currently lines 80 and 99) and
      have the flag regexes scan `$seg` directly. Do not leave a dead `seg_scan` variable.
      *(completed: `grep -c seg_scan` returns 0)*
- [x] Repoint all five destructive-chain detectors at `$COMMAND_SCAN`: `git reset --hard`,
      `git checkout -- <path>`, `RESTORE_SEGMENTS`, `CLEAN_SEGMENTS`, `git stash drop|clear`,
      `FORCED_SEGMENTS`. Every `echo "$COMMAND" | grep` in the matching chain becomes
      `echo "$COMMAND_SCAN" | grep`. *(completed)*
- [x] Leave the raw `$COMMAND` in use only where it must stay raw: the empty-command early exit at
      line 57. Do not change the snapshot-marker logic, the freshness window, the exit codes, or
      any stderr message text. *(completed: confirmed by `grep -n '\$COMMAND\b'` — only line 57
      and the `COMMAND_SCAN` construction itself reference raw `$COMMAND`)*
- [x] Leave the Cause-2 flag regexes textually unchanged. Tightening them is a declared non-goal.
      *(completed)*
- [x] Run the suite. Every Phase 2 case must be GREEN and every Phase 1 baseline case must remain
      GREEN. A Phase 1 case going red is a real behavioral regression from moving the strip
      upstream — investigate rather than adjusting the case. *(completed: 43/43 green — see the
      N-loop-to-`sed -z` deviation above for the one regression found and fixed mid-phase)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts that exactly seven detectors read the command string and
that exactly two per-segment `sed` strips become redundant. Confirm at implementation time by
`grep -n 'COMMAND' agent-system/extensions/core/hooks/guard-destructive-git.sh` after the edit:
every remaining bare `$COMMAND` read must be either the `COMMAND_SCAN` construction itself or the
line-57 empty check, and `grep -c seg_scan` must return 0.

**Files to modify**:
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` - add `COMMAND_SCAN`, repoint all
  detectors, delete both per-segment strips

**Verification**:
- `bash -n agent-system/extensions/core/hooks/guard-destructive-git.sh` parses clean.
- `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` exits 0 with
  every Phase 1 and Phase 2 case green.
- `grep -n 'echo "\$COMMAND"' ` returns no matches inside the detector chain.

---

### Phase 4: Update the header comments to the post-fix matching contract [COMPLETED]

**Goal**: Make the file's own documentation describe what the code now actually does, per
acceptance criterion 6.

**Tasks**:
- [x] Update the "Over-staging patterns" comment block (currently lines 67-72). It presently
      claims the quote-strip belongs to, and is scoped to, the two over-staging detectors, stated
      as an already-complete guarantee. Replace with a description of the real contract: the strip
      now happens once, upstream, against the whole possibly-multi-line command, before any
      segment extraction; it protects all seven detectors, not two; and `#`-comment text is
      stripped for the same reason. *(completed: written during Phase 3 when the strip landed —
      the "Over-staging detectors" block now reads $COMMAND_SCAN and states the shared upstream
      strip explicitly; confirmed still accurate, no rewrite needed)*
- [x] Add a short note at the `COMMAND_SCAN` construction site stating why slurp mode is required
      (a line-based strip silently fails on any quoted span containing a newline, because `grep`
      and line-mode `sed` never match across a newline) and why the comment-strip must be ordered
      after the quote-strip. *(completed: written during Phase 3, also documents the `sed -z`
      deviation from the plan's literal N-loop idiom and the reason for it)*
- [x] Review the top-of-file header block (currently lines 41-47). Its claim that the hook only
      ever observes the literal top-level `tool_input.command` string remains true and unaffected;
      confirm and leave it, or adjust only if the wording now reads as contradicting the
      `COMMAND_SCAN` indirection. *(completed: reviewed, left unchanged — COMMAND_SCAN is a
      derived local variable, not a second input boundary, so the claim still holds verbatim)*
- [x] Record the out-of-scope decision in a brief comment: `[^;&|]*` segment splitting is not
      quote-aware, is now confined to *unquoted* metacharacters by the upfront strip, and is
      deliberately not addressed here. *(completed: added at the end of the COMMAND_SCAN comment
      block)*
- [x] Verify no task-number references were introduced. `agent-system/**` is outside `specs/**`,
      so `task 34`-style citations are prohibited; cite the mechanism, not the task.
      *(completed: `grep -niE 'task[ _-]?[0-9]' guard-destructive-git.sh` returns no matches)*

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` - comment blocks only

**Verification**:
- Diff read-through confirms every changed hunk lies inside a `#` comment region.
- `bash -n` still parses clean and the suite still exits 0 (no accidental crossing out of the
  comment boundary).
- `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the repo's equivalent
  lint) reports no new hits.

---

### Phase 5: Register the suite and verify it passes in both modes [NOT STARTED]

**Goal**: Wire the suite into the manifest and demonstrate it runs and passes under both the
source-store and deployed directory shapes, satisfying acceptance criterion 5.

**Tasks**:
- [ ] Add `"tests/test-guard-destructive-git.sh"` to `provides.scripts` in
      `agent-system/extensions/core/manifest.json`, matching the existing subdirectory-qualified
      `"tests/test-..."` entries and preserving the surrounding ordering convention.
- [ ] Validate the manifest still parses: `jq -e . agent-system/extensions/core/manifest.json`.
- [ ] Confirm `run-all.sh` requires no edit — it glob-discovers `test-*.sh` in both modes. Verify
      by observation, not assumption: run
      `bash agent-system/extensions/core/scripts/tests/run-all.sh` and confirm the new suite
      appears in the per-suite narration and the summary count increases by one.
- [ ] Confirm the suite file carries its exec bit — `run-all.sh` reports a non-executable suite as
      a loud `[SKIP]`, which is a false green for this task's purposes.
- [ ] Verify deployed mode. Primary path: regenerate the deploy via
      `bash agent-system/extensions/core/scripts/deploy-headless.sh` (inspect its `--help`/usage
      first for required arguments), then run `.claude/scripts/tests/run-all.sh` and confirm the
      suite is discovered and passes against `.claude/hooks/guard-destructive-git.sh`. Fallback if
      the deploy cannot be run non-interactively: construct a flat `scripts/tests/` + `hooks/`
      tree under `mktemp -d`, copy the suite and the fixed hook into it, and run the suite there —
      this exercises the same `$SCRIPT_DIR/../../hooks/` resolution the deployed tree uses.
- [ ] Do not hand-author anything under `.claude/**`. Regenerating the tree via the sanctioned
      deploy script is the only permitted way that tree changes.
- [ ] Note that `file_scope` for this task does not currently list `manifest.json`; the field is
      descriptive and not filesystem-validated, so extend it rather than skipping the required
      registration.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts that `run-all.sh` needs zero code changes and that
`manifest.json` registration is the only wiring step. Confirm at implementation time by running
`run-all.sh` before and after adding the suite file and observing the discovered-suite count
increase by exactly one with no edit to `run-all.sh`.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - one entry appended to `provides.scripts`

**Verification**:
- `jq -e '.provides.scripts | index("tests/test-guard-destructive-git.sh")'` returns a non-null
  index.
- `run-all.sh` in source-store mode: new suite discovered, `[PASS]`, overall exit 0.
- `run-all.sh` (or the flat-tree fallback) in deployed mode: same result.

---

### Phase 6: Mutation check and full regression sweep [NOT STARTED]

**Goal**: Prove the suite is capable of failing, then confirm the whole repository's test surface
is green with the fix in place.

**Tasks**:
- [ ] Perform the formal mutation cycle required by the house standard: revert the Phase 3 fix in
      `guard-destructive-git.sh` (restore the raw-`$COMMAND` detectors and the two per-segment
      `seg_scan` strips), run the suite, confirm it goes RED, then restore the fix and confirm it
      goes GREEN again. Use `git stash`/`git stash pop` or an explicit copy — never a destructive
      git operation on uncommitted work.
- [ ] Record the mutation result concretely: the exact set of case names that went red under the
      reverted hook. Cross-check it against the RED set recorded in Phase 2; a case that was red
      pre-fix but green under the revert (or vice versa) indicates the revert was incomplete.
- [ ] Run the second, narrower mutation: revert only the comment-strip `sed` clause (keeping the
      quote-strip) and confirm the `#`-comment false-exemption case is the one that goes red. This
      proves that clause is load-bearing rather than incidental.
- [ ] Restore the full fix and confirm `bash agent-system/extensions/core/scripts/tests/run-all.sh`
      is green across every discovered suite — the fix touches a hook that gates every Bash call,
      so a repo-wide sweep is the correct final gate, not just this one suite.
- [ ] Confirm the file is left in the fixed state, with no leftover stash entry, backup copy, or
      partially-reverted hunk.
- [ ] In the implementation summary, record: the mutation-check evidence; the explicitly out-of-scope
      `[^;&|]*` segment-splitting defect with a recommendation to file it as follow-up work; and the
      out-of-scope decision on tightening the Cause-2 flag regex.

**Timing**: 1 hour

**Depends on**: 4, 5

**Verification Tier**: full

**Verification**:
- Reverted hook: suite exits 1 with a recorded, non-empty RED set consistent with Phase 2.
- Restored hook: suite exits 0.
- `run-all.sh` exits 0 across all suites in source-store mode.
- `git status --short` shows only the three intended files changed.

---

## Testing & Validation

- [ ] The fixture self-check meta-case confirms a genuinely dirty git repo before any hook case
      runs; a clean-tree case and an empty-command case confirm the two exemptions still fire.
- [ ] Every case asserts on exit code (2 = blocked, 0 = allowed), never on stdout.
- [ ] The observed false positive (multi-line `-m` with `essential-refactor` in the subject) is
      allowed, and its single-line control is allowed.
- [ ] `essential-refactor`, `auto-repair`, `multi-task` are never blocked, single- or multi-line;
      `un-edged` and `repo-wide` controls remain allowed.
- [ ] Each of the five vulnerable destructive detectors has a message-text false-positive case
      (allowed) and a true-positive case (blocked).
- [ ] The two over-staging detectors retain their true positives (`git add -A`, `git add --all`,
      `git add .`, `git commit -a`, `git commit -am`), including multi-line message forms.
- [ ] Both false-exemption forms are closed: a quoted `--staged` and a `#`-commented `--staged`
      each fail to exempt a real `git restore`.
- [ ] No bypass opened: a real destructive command adjacent to quoted text stays blocked.
- [ ] Mutation check: the suite is RED against the reverted hook and GREEN against the fixed hook,
      with the comment-strip clause independently proven load-bearing.
- [ ] The suite passes under `run-all.sh` in both source-store and deployed modes.
- [ ] No task-number references introduced anywhere outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/hooks/guard-destructive-git.sh` (modified: `COMMAND_SCAN`
  construction, seven detectors repointed, two per-segment strips deleted, header comments updated)
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` (new, executable)
- `agent-system/extensions/core/manifest.json` (modified: one `provides.scripts` entry)
- `specs/034_anchor_git_guard_matching_to_argv/summaries/01_anchor-guard-matching-summary.md`
  (implementation summary, including the mutation-check evidence and the two recorded out-of-scope
  decisions)

## Rollback/Contingency

- All three changed files are tracked and committed per phase, so `git revert` of the phase commits
  restores the prior behavior cleanly. Never use a destructive git operation on uncommitted work to
  roll back — take `bash .claude/scripts/git-snapshot.sh 34` first if a rollback becomes necessary.
- If Phase 3 causes a Phase 1 baseline case to regress and the cause cannot be identified within
  the phase, revert only the destructive-chain repointing (keeping the over-staging repointing and
  the upfront strip), which closes the reproduced false positive while leaving detectors 3-7 at
  their current behavior. Mark the phase `[PARTIAL]`, record which detectors were left raw, and do
  not adjust test cases to match.
- If deployed-mode verification cannot be completed (deploy not runnable non-interactively and the
  flat-tree fallback also blocked), land Phases 1-4 and 6, mark Phase 5 `[PARTIAL]` with the
  manifest registration done and the deployed-mode run outstanding, and state the gap explicitly
  in the summary rather than claiming criterion 5 satisfied.
