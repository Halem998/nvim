# Implementation Plan: Task #965

- **Task**: 965 - Make check_undeclared_scripts skip untracked build artifacts
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/965_skip_untracked_artifacts_in_undeclared_scripts_check/reports/01_git-ls-files-enumeration.md
- **Artifacts**: plans/01_git-ls-files-enumeration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`check_undeclared_scripts()` (Rule Q) in `agent-system/extensions/core/scripts/check-extension-docs.sh`
enumerates candidate files with `find "$ext_path_norm/scripts" -type f`, which walks the working
tree and therefore flags gitignored, never-tracked build artifacts (two live CPython
`__pycache__/*.pyc` files under the `literature` extension) as permanent, unfixable hard FAILs.
The fix is already chosen and already in use by the sibling check `check_flat_category_orphans()`
via its `_git_deployed_files()` helper: enumerate with `git ls-files` instead of `find`. This plan
applies that enumeration method to Rule Q, re-derives the prefix-strip for `git ls-files`'
REPO_ROOT-relative output shape, updates the now-stale header comment, and proves via a
positive-detection fixture that the check still catches a tracked-but-undeclared script.
Definition of done: the two `__pycache__` FAILs are gone, a tracked-but-undeclared fixture is
still caught, no false positives appear, and the doc-lint gate exits 0.

### Research Integration

The research report supplies a fully-specified, empirically-verified replacement body and three
load-bearing findings integrated directly into the phases below:

1. **`git ls-files` output is always REPO_ROOT-relative**, regardless of whether the pathspec is
   absolute or relative. This is a *different path shape* than `find` returned (absolute). Reusing
   the existing absolute-prefix strip unchanged would silently produce a no-op strip, degrading the
   check into reporting every script in every extension as undeclared. The prefix must be
   re-derived as `ext_rel="${ext_path_norm#"$REPO_ROOT"/}"`.
2. **The existence guard must become `[[ -f "$REPO_ROOT/$script_file" ]]`** because `$script_file`
   is now REPO_ROOT-relative, matching `check_flat_category_orphans`'s own `full="$REPO_ROOT/$rel"`
   idiom.
3. **Regression-checked across every extension with a `scripts/` tree**: only `literature` differs
   between old and new logic, and the diff is exactly the removal of the two known-bad `.pyc`
   entries — zero new findings, zero legitimate findings lost.

The research also decided against extracting a shared helper with `_git_deployed_files()` (the two
checks enumerate structurally different roots: `.claude/$category` vs. an extension's own source
`scripts/` tree), and against adding a `__pycache__/*` case exemption (symptom patch). Both
decisions are carried into the Non-Goals below unchanged.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation was requested for this task (`roadmap_flag` not set).

## Goals & Non-Goals

**Goals**:
- Replace `find`-based enumeration in `check_undeclared_scripts()` with `git ls-files`, scoped to
  the extension's `scripts/` directory.
- Re-derive the prefix-strip and existence guard for `git ls-files`' REPO_ROOT-relative output
  shape (not a blind copy of the absolute-prefix logic).
- Update the Rule Q header comment block, which currently asserts `find -type f` as the
  enumeration method, so the documentation and the code do not diverge.
- Prove by positive-detection fixture that a tracked-but-undeclared script under an extension's
  `scripts/` is STILL caught (hard acceptance criterion — the entire risk of this change is
  silently converting a working check into a no-op).
- Leave the doc-lint gate exiting 0.

**Non-Goals**:
- Do NOT add a `__pycache__/*` (or `.venv/`, `node_modules/`, `*.pyc`) case to the existing
  `case` statement. That is a symptom patch that leaves the next gitignored artifact class to
  reproduce the identical failure mode.
- Do NOT extract a shared enumeration helper between `check_undeclared_scripts` and
  `_git_deployed_files` / `check_flat_category_orphans` in this change.
- Do NOT reintroduce a `*.sh` glob or otherwise narrow the file-type scope.
- Do NOT change the `deprecated/*` exemption or make `tests/` exempt.
- Do NOT change any other check in `check-extension-docs.sh`.
- Do NOT hand-author or hand-edit any file under `.claude/**` — that tree is a gitignored,
  disposable deploy artifact. The sole edit target is
  `agent-system/extensions/core/scripts/check-extension-docs.sh`.
- Do NOT cite task numbers in any file outside `specs/**` (comments in the script must reference
  durable anchors: function names, script names, section headings).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Prefix-strip copied blindly from the absolute form; strip silently no-ops and EVERY script in EVERY extension is reported undeclared | H | M | Phase 1 mandates the re-derived `ext_rel`; Phase 3's fixture run asserts the *total* finding count for a clean tree is zero, which this failure mode would blow up loudly |
| Silent conversion of the check into a no-op (enumeration returns nothing, everything passes) | H | M | Phase 3's positive-detection fixture is a HARD gate: a tracked-but-undeclared script MUST still produce a `fail` |
| Trailing-slash normalization dropped during the edit, producing a `ext//scripts/` prefix that matches nothing | H | L | `ext_path_norm` line and its comment are explicitly preserved verbatim in Phase 1; Phase 3 fixture catches the resulting mass-report |
| Header comment left asserting `find -type f`, so a future reader trusts stale documentation | M | M | Phase 2 updates the comment as a dedicated, separately-verified step |
| Deployed `.claude/scripts/check-extension-docs.sh` not refreshed, so the runtime gate stays red despite a correct source-store fix | M | M | Phase 4 runs the deploy path and re-checks; if propagation does not land, the plan requires reporting it explicitly rather than hand-editing `.claude/**` |
| Fixture file accidentally left tracked/committed in the repo | M | L | Phase 3 uses `git add -N` (intent-to-add) + `git restore --staged` + plain `rm`; no commit of the fixture, and cleanup is a checklist item |
| `git ls-files` returns empty outside a git working tree, silently passing the check | L | L | Accepted: identical to `_git_deployed_files`'s already-accepted behavior elsewhere in the same script; no new failure mode introduced (per research Risks section) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is fully sequential: all four
phases edit or verify the same single file region.

---

### Phase 1: Replace enumeration and re-derive prefix-strip [COMPLETED]

**Goal**: `check_undeclared_scripts()` enumerates via `git ls-files` with a correctly re-derived
REPO_ROOT-relative prefix-strip and existence guard, and every non-enumeration behavior is
byte-for-byte preserved.

**Tasks**:
- [x] Open `agent-system/extensions/core/scripts/check-extension-docs.sh` and locate the
      `check_undeclared_scripts()` function body (Rule Q). *(completed)*
- [x] Add a new local after the existing `ext_path_norm` line:
      `local ext_rel="${ext_path_norm#"$REPO_ROOT"/}"`, with a comment explaining that
      `git ls-files` (run via `-C "$REPO_ROOT"`) always returns REPO_ROOT-relative paths
      regardless of the pathspec's own form — a different shape than `find` returned — so the
      prefix-strip must be re-derived against `ext_path_norm`'s REPO_ROOT-relative form.
      *(completed)*
- [x] Change the existence guard from `[[ -f "$script_file" ]]` to
      `[[ -f "$REPO_ROOT/$script_file" ]]` (matches `check_flat_category_orphans`'s
      `full="$REPO_ROOT/$rel"` idiom). *(completed)*
- [x] Change the prefix-strip from `rel_path="${script_file#"$ext_path_norm"/scripts/}"` to
      `rel_path="${script_file#"$ext_rel"/scripts/}"`. *(completed)*
- [x] Change the process substitution from `< <(find "$ext_path_norm/scripts" -type f | sort)` to
      `< <(git -C "$REPO_ROOT" ls-files "$ext_path_norm/scripts" | sort)`. *(completed)*
- [x] Confirm untouched: the `[[ -d "$ext_path/scripts" ]] || return 0` early return; the
      `ext_path_norm="${ext_path%/}"` line and its trailing-slash comment; the `deprecated/*`
      case (and the absence of any `tests/` case); the `jq -e --arg s "$rel_path"` full-relative-path
      match; the `fail "script file on disk NOT in provides.scripts: scripts/$rel_path"` message.
      *(completed: verified via git diff, all listed elements unchanged)*
- [x] Run `bash -n agent-system/extensions/core/scripts/check-extension-docs.sh`. *(completed: exit 0)*

**Timing**: 25 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly four line-level changes plus one added local
(`ext_rel`), all confined to the `check_undeclared_scripts()` body in one file. Confirm at
implementation time with `git diff --stat` (expect 1 file changed) and by reading
`git diff` in full to verify no hunk falls outside that function body. If the diff touches any
other function, stop and re-scope.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — `check_undeclared_scripts()`
  body only: add `ext_rel` local, change existence guard, change prefix-strip, change the
  process-substitution enumeration source.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0.
- `git diff` shows changes confined to the `check_undeclared_scripts()` body.
- No `find` call remains inside `check_undeclared_scripts()`.
- No `*.sh` glob was introduced anywhere in the function.

---

### Phase 2: Update the Rule Q header comment [COMPLETED]

**Goal**: The Rule Q header comment block no longer asserts `find -type f` as the enumeration
method, and records why the git-index enumeration is used — matching the justification already
carried verbatim above `_git_deployed_files()`.

**Tasks**:
- [x] In the header comment block above `check_undeclared_scripts()`, rewrite the sentence that
      currently reads "...so this uses `find -type f`, not a `*.sh` glob" so that it states the
      enumeration is `git ls-files` (not `find`), while preserving the surrounding claim that ALL
      regular file types are in scope and no `*.sh` glob is used. *(completed)*
- [x] Add the rationale, mirroring the existing `_git_deployed_files()` comment: enumerating from
      the git index naturally excludes gitignored runtime artifacts (`__pycache__/`, virtualenvs,
      build caches) without extra path filtering, since they were never tracked. *(completed)*
- [x] Confirm the rest of the header block is unchanged: the Rule Q-vs-Rule E-vs-Rule M
      distinction, the full-relative-path matching rationale, the `deprecated/` exempt /
      `tests/` NOT exempt statement. *(completed: verified via git diff, unchanged)*
- [x] Verify no task number appears anywhere in the added or edited comment text; reference only
      durable anchors (`check_undeclared_scripts`, `check_flat_category_orphans`,
      `_git_deployed_files`, `provides.scripts`). *(completed: grep found no citation)*
- [x] Run `bash -n agent-system/extensions/core/scripts/check-extension-docs.sh`. *(completed: exit 0)*

**Timing**: 15 minutes

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — comment block immediately
  preceding `check_undeclared_scripts()`.

**Verification**:
- Diff read-through confirms every changed hunk in this phase lies inside a `#` comment region.
- `grep -n 'find -type f' ` over the Rule Q comment block returns nothing.
- `bash -n` still exits 0 (guards against an edit that crossed out of the comment region).
- No digits-bearing task citation (`task N`, `tasks N-M`, `Task #N`) in the edited text.

---

### Phase 3: Positive-detection fixture and regression verification [COMPLETED]

**Goal**: Empirically prove all three behavioral properties — untracked artifacts skipped,
tracked-but-undeclared scripts STILL caught, declared-and-tracked scripts produce no finding —
against the source-store copy of the script.

**Tasks**:
- [x] Baseline: run the source-store script with an explicit REPO_ROOT override (required — the
      computed default only resolves inside a deploy tree, and the explicit override deliberately
      bypasses `deploy-root-guard.sh`):
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`.
      Capture full output. *(completed: exit 1, sole FAIL is the expected pre-Phase-4 deploy
      drift on scripts/check-extension-docs.sh itself)*
- [x] Assert property 1 (untracked artifacts skipped): neither
      `literature/scripts/__pycache__/literature-decode-font-offset.cpython-313.pyc` nor
      `literature/scripts/tests/__pycache__/generate-test-fixtures.cpython-313.pyc` appears in the
      output as a `provides.scripts` finding. *(completed: confirmed via diff against the
      pre-change script body run through the same command — the only delta is the removal of
      those exact two FAIL lines)*
- [x] Assert property 3 (no false-positive regression): no `script file on disk NOT in
      provides.scripts` finding is reported for any currently-declared, tracked script. Confirm
      the Rule Q finding count for the clean tree is zero. *(completed: 0 Rule Q findings in the
      baseline run)*
- [x] Build the positive-detection fixture: create a temporary file at
      `agent-system/extensions/core/scripts/__undeclared-fixture-probe.sh` (any extension with a
      `scripts/` tree works; core is convenient), containing only a shebang and a comment. Make it
      visible to `git ls-files` WITHOUT committing it: `git add -N <path>` (intent-to-add).
      *(completed)*
- [x] Assert property 2 (HARD acceptance criterion): re-run
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` and
      confirm it now reports exactly one new finding naming
      `scripts/__undeclared-fixture-probe.sh`. If it does NOT, the change has silently converted
      the check into a no-op — STOP, mark this phase `[BLOCKED]`, and do not proceed to Phase 4.
      *(completed: PASSED — exactly one new FAIL line added, naming
      `scripts/__undeclared-fixture-probe.sh`; finding count rose from 1 to 2, nothing else
      changed)*
- [x] Clean up the fixture: `git restore --staged agent-system/extensions/core/scripts/__undeclared-fixture-probe.sh`
      then `rm agent-system/extensions/core/scripts/__undeclared-fixture-probe.sh`. Confirm
      `git status --short` shows no residue of the probe file. *(completed: no residue)*
- [x] Re-run the source-store check post-cleanup and confirm the output matches the baseline
      exactly (fixture fully removed, no lingering finding). *(completed: post-cleanup output
      byte-for-byte identical to baseline)*
- [x] Record the three assertion results (with the actual command output excerpts) for the
      implementation summary.

**Timing**: 30 minutes

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that (a) exactly two findings disappear relative to the
pre-change behavior, (b) zero other findings change, and (c) the fixture produces exactly one new
finding. Confirm at implementation time by diffing the captured baseline output against the
pre-change output (re-derivable via `git stash`-free means: `git show HEAD:agent-system/extensions/core/scripts/check-extension-docs.sh`
into a temp file and running that copy with the same REPO_ROOT override). If the diff contains
anything beyond the two `__pycache__` lines, the change has collateral impact and must be
re-scoped before proceeding.

**Files to modify**:
- None permanently. One temporary fixture file is created and removed within this phase.

**Verification**:
- Property 1, 2, and 3 assertions all hold as stated above.
- `bash -n agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0.
- `git status --short` shows only the intended source-store script modification plus `specs/**`
  artifacts — no fixture residue.

---

### Phase 4: Deploy propagation and final gate [COMPLETED]

**Goal**: The runtime doc-lint gate at `.claude/scripts/check-extension-docs.sh` carries the fix
via the normal deploy path (never a hand-edit) and exits 0.

**Tasks**:
- [x] Propagate the source-store change to the deploy tree using the existing deploy path
      (`bash .claude/scripts/deploy-headless.sh`, or the repo's standard "Load Core" sync). Do NOT
      hand-author or hand-edit `.claude/scripts/check-extension-docs.sh`. *(completed: ran
      `bash .claude/scripts/deploy-headless.sh`, 303 artifacts deployed)*
- [x] Confirm propagation landed: diff the deployed copy against the source-store copy and confirm
      the `check_undeclared_scripts()` bodies are identical. *(completed: `diff` exit 0, bodies
      byte-for-byte identical — no propagation gap encountered this run)*
- [x] If propagation did NOT land (a known, documented gap exists in the headless sync path for
      already-loaded extensions), report that explicitly in the implementation summary as an open
      deploy-mechanism issue and mark this phase `[PARTIAL]`. Do NOT work around it by editing
      `.claude/**` directly. *(not applicable — propagation landed cleanly)*
- [x] Run the runtime gate: `bash .claude/scripts/check-extension-docs.sh`; confirm exit status 0.
      *(completed: exit 0, "PASS: all extensions OK")*
- [x] Run `bash .claude/scripts/verify-deploy.sh` (or its source-store equivalent with an explicit
      REPO_ROOT override) and confirm no new failures, including its task-reference lint gate.
      *(completed: exit 0, "PASS -- 12 check(s), 0 failure(s)"; the one WARN present is a
      pre-existing, unrelated duplicate Stop-hook registration)*
- [x] Commit the source-store change with a scoped commit (source-store script + `specs/**`
      artifacts only; never `git add -A`). *(completed: the source-store script edit was already
      committed incrementally in the Phase 1 and Phase 2 per-substep commits; this phase's own
      plan/progress-file updates are committed as the Phase 4 closing commit)*

**Timing**: 20 minutes

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- None directly. `.claude/scripts/check-extension-docs.sh` is regenerated by the deploy path, not
  edited.

**Verification**:
- `bash .claude/scripts/check-extension-docs.sh` exits 0.
- Deployed and source-store `check_undeclared_scripts()` bodies are identical (or the divergence
  is explicitly reported as a deploy-mechanism gap).
- `verify-deploy.sh` reports no new failures.
- `git status --short` review before commit shows only intended files staged.

---

## Testing & Validation

- [ ] `bash -n agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0.
- [ ] The two `literature/scripts/**/__pycache__/*.pyc` FAILs no longer appear.
- [ ] A tracked-but-undeclared script under an extension's `scripts/` is STILL reported (hard
      acceptance criterion, proven by the Phase 3 fixture).
- [ ] A declared-and-tracked script produces no finding (no false-positive regression).
- [ ] Full-relative-path matching preserved (no basename matching introduced).
- [ ] All regular file types still in scope (no `*.sh` glob reintroduced).
- [ ] `deprecated/*` still exempt; `tests/` still NOT exempt.
- [ ] `ext_path_norm="${ext_path%/}"` trailing-slash normalization survives.
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0.
- [ ] No task-number citation appears in the modified script.
- [ ] No file under `.claude/**` was hand-edited.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/check-extension-docs.sh` (modified —
  `check_undeclared_scripts()` body and its header comment)
- `specs/965_skip_untracked_artifacts_in_undeclared_scripts_check/plans/01_git-ls-files-enumeration.md`
  (this file)
- `specs/965_skip_untracked_artifacts_in_undeclared_scripts_check/summaries/01_git-ls-files-enumeration-summary.md`
  (implementation summary, including the three Phase 3 assertion results and any deploy-propagation
  gap encountered)

## Rollback/Contingency

The change is confined to one function in one tracked file, with no schema, state, or data
migration. To revert: `git checkout HEAD~1 -- agent-system/extensions/core/scripts/check-extension-docs.sh`
(or revert the scoped commit), then re-run the deploy path to restore the deployed copy. Reverting
restores the prior `find`-based behavior, which means the two `__pycache__` FAILs return and the
doc-lint gate goes red again — that is the known pre-existing state, not a new failure.

If Phase 3's positive-detection fixture fails (a tracked-but-undeclared script is NOT caught), do
NOT proceed to Phase 4 and do NOT commit. The most likely cause is a prefix-strip that was copied
rather than re-derived, or a `git ls-files` pathspec that resolves to nothing; re-examine
`ext_rel` and the pathspec form before any further change.
