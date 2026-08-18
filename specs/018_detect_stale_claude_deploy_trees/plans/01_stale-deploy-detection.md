# Implementation Plan: Detect stale .claude/ deploy trees and root-cause the silent staleness

- **Task**: 18 - Detect stale .claude/ deploy trees and root-cause the silent staleness
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: specs/018_detect_stale_claude_deploy_trees/reports/01_stale-deploy-detection.md
- **Artifacts**: plans/01_stale-deploy-detection.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research established that there is no loader or copy-engine defect: `loader.copy_category`
force-overwrites every declared file on every load, `installed_files` is write-only bookkeeping
never consulted as a copy gate, and `manager.resync_all` calls `manager.load(force=true)` with
zero diffing. The staleness is structural and by design -- regeneration is deliberately pull-only,
so a consuming repo's `.claude/` tree freezes at its last manual reload with no ambient signal
when the source store moves on. This plan therefore implements detection only, in two halves: a
Lua write side that stamps each extension's source-store git revision (`source_git_head`, a
sibling to the `source_dir` field `state.lua` already records) into `.claude-extensions.json` at
load time, and a bash read side -- a small standalone `check-deploy-freshness.sh` invoked
non-blockingly from `command-gate-in.sh` (CHECKPOINT 1, crossed by every ordinary command) that
recomputes the current path-scoped revision and WARNs, naming regeneration as the remedy, on
mismatch. Done means: a stale tree warns on an ordinary command, a fresh tree does not, and both
directions are demonstrated.

### Research Integration

Findings carried forward without re-litigation:
- All four loader-defect hypotheses (skip-on-exists, `installed_files`-gates-copy, diff-only
  resync, partial-operation revert) were directly falsified by reading `loader.lua`/`init.lua`.
  No copy-engine patch is owed; Part 1's deliverable is the stated root cause, not a code fix.
- `state.lua`'s `mark_loaded` (the single writer of every `.claude-extensions.json` entry, called
  from `init.lua`'s `manager.load`) already records `source_dir = manifest._source_dir`, an
  absolute path into the source store. This is the hook the write side extends.
- A path-scoped `git log -1 --format=%H -- <source_dir>` measured 0.002-0.004s on this machine,
  confirming preflight-cheap cost. Scoping to the extension's own subpath (not the source-store
  repo's whole HEAD) is what prevents unrelated source-store churn from firing false warnings.
- `verify-deploy.sh` (563 lines, 11 content-diffing gates) is deliberately not preflight-cheap
  and is deployed by the same pull-only mechanism it would diagnose. It stays the deep-dive
  companion; this plan does not extend or replace it.
- Entries lacking `source_git_head` (every pre-fix deploy) must be skipped in silence, not
  flagged -- "unknown" must not read as either "confirmed fresh" or an alarm.

### Prior Plan Reference

No prior plan. An earlier planner dispatch for this task was interrupted before producing any
artifact and left nothing usable behind.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` supplied in the delegation context).

## Goals & Non-Goals

**Goals**:
- Stamp a per-extension source-store git revision into `.claude-extensions.json` at load time,
  degrading silently to omitting the field whenever it cannot be computed.
- Provide a standalone, independently testable, non-blocking freshness check that names the
  regeneration remedy on drift.
- Put that check on the one path every ordinary command already crosses
  (`command-gate-in.sh`, CHECKPOINT 1) without changing any admission decision.
- Demonstrate the acceptance criterion in both directions: stale warns, fresh stays silent.
- Record the root-cause finding where a future reader of the pull-only regeneration pattern will
  see both halves.

**Non-Goals**:
- Any change to the copy engine (`loader.copy_category`, `manager.load`, `manager.resync_all`) --
  research falsified every defect hypothesis there.
- Any change to `install-extension.sh` (a separate, older symlink-based mechanism not implicated
  in the root cause or the detection design), despite its presence in the task's `file_scope`.
- A per-file hash manifest, or any per-file drift reporting at the preflight gate. That finer
  grain is already `verify-deploy.sh --findings`' job.
- Making the check blocking, or having it abort, retry, or auto-redeploy anything.
- Cross-machine detection. `source_dir` is an absolute machine-local path; a relocated or
  foreign-machine source store falls into the same "cannot verify, stay silent" branch.
- Re-adjudicating the sibling orphan-file parity finding measured against a stale tree.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `command-gate-in.sh` is *sourced*, not executed; a stray `exit`, `set -e`, or non-zero return from the new call aborts every command's calling shell | H | M | Invoke the checker as `bash .claude/scripts/check-deploy-freshness.sh ... 2>/dev/null \|\| true`, never source it; the checker itself always exits 0; add no shell options to gate-in (its header contract already forbids this) |
| Chicken-and-egg: a tree stale enough to need the warning may not have the checker deployed | M | H | Guard the call on `[ -f ... ]` so its absence is a silent no-op; the gap closes itself on that repo's next resync, exactly as the research scoped it |
| Preflight cost grows with extension count | M | L | One path-scoped `git log -1` per extension (measured 0.002-0.004s each); measure total wall time in Phase 5 and record it; skip any entry lacking the required fields before spending a git call |
| False positive after deploying from a dirty source-store working tree (HEAD moves when that edit is later committed, though the deployed bytes already match) | L | M | Accepted and documented: the signal is commit-granular by design, the warning is non-blocking, and the suggested remedy (a redeploy) is harmless when already fresh |
| Detection becomes noisy enough that users learn to ignore it | M | L | One WARN line per stale extension, printed once per command at gate-in, never repeated within a command; silence in every "cannot verify" case |
| Editing the deployed `.claude/` tree instead of the source store, silently losing the work on next regeneration | H | M | Binding source-store rule: every edit lands in `agent-system/extensions/core/**` or `lua/**`; the deployed tree is only ever read, or written by running the deploy script |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 1, 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Stamp source_git_head at load time (Lua write side) [COMPLETED]

**Goal**: Every `.claude-extensions.json` entry written from this point forward carries a
`source_git_head` sibling to its existing `source_dir`, or omits the field entirely when the
revision cannot be resolved.

**Tasks**:
- [x] In `lua/neotex/plugins/ai/shared/extensions/state.lua`, add a resolver that takes an
      absolute `source_dir` and returns the path-scoped source-store revision, or `nil`:
      resolve the enclosing repo root (`git -C <source_dir> rev-parse --show-toplevel`), then
      `git -C <root> log -1 --format=%H -- <source_dir>`. Trim trailing newline; return `nil` on
      empty output.
- [x] Wrap every git invocation so that a missing `git` binary, a non-repo `source_dir`, an
      unreadable or nonexistent `source_dir`, or a non-zero exit yields `nil` rather than an
      error. Loading an extension must never fail because of this field.
- [x] Expose the resolver as a public function on the module (additive only -- do not change
      `M.mark_loaded`'s signature or any existing function's behavior) so it is reachable from a
      test without duplicating its logic.
- [x] In `M.mark_loaded`, set `source_git_head` on the written entry from that resolver, keyed off
      the same `manifest._source_dir` value `source_dir` already uses. Omit the key when the
      resolver returns `nil` -- do not write `nil`, `""`, or a placeholder string.
- [x] Confirm no other writer of `.claude-extensions.json` entries exists that would need the same
      treatment (`grep -rn "mark_loaded" lua/`).

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts `state.lua`'s `M.mark_loaded` is the single writer of
per-extension state entries, with exactly one call site (`init.lua`, in `manager.load`). Confirm
at implementation time with `grep -rn "mark_loaded\|source_dir" lua/neotex/plugins/ai/shared/extensions/`
before editing; if a second writer or call site exists, extend this phase's task list to cover it
rather than proceeding on the assumption.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/state.lua` - add the git-revision resolver; stamp
  `source_git_head` in `mark_loaded` alongside `source_dir`

**Verification**:
- Deploy into a throwaway scratch repo:
  `bash agent-system/extensions/core/scripts/deploy-headless.sh <scratch-repo>`, then
  `jq '.extensions | to_entries[] | {k: .key, head: .value.source_git_head}' <scratch-repo>/.claude-extensions.json`
  shows a 40-hex revision for every extension.
- The stamped value equals `git log -1 --format=%H -- agent-system/extensions/<name>` run in the
  source store, per extension checked.
- Point the resolver at a directory outside any git repository (e.g. a `mktemp -d`) and confirm it
  returns `nil` and raises no error.

---

### Phase 2: Standalone check-deploy-freshness.sh (bash read side) [NOT STARTED]

**Goal**: A small, self-contained, always-exit-0 script that reads a repo's
`.claude-extensions.json` and prints one WARN line per demonstrably stale extension, naming the
regeneration remedy -- and prints nothing at all in every other case.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/check-deploy-freshness.sh` with a header
      documenting: its always-non-blocking contract, its always-exit-0 guarantee, that it must be
      run with `bash` (never sourced), and the silent-skip cases it deliberately treats as
      "cannot verify."
- [ ] Accept an optional repo root argument, defaulting to the current directory; read
      `<root>/.claude-extensions.json`. Missing or unparseable file: exit 0 silently.
- [ ] For each entry under `.extensions`, skip silently unless BOTH `source_dir` and
      `source_git_head` are present and non-empty. Skip silently when `source_dir` does not exist
      on disk, is not inside a git repository, or when `git` is unavailable.
- [ ] For surviving entries, recompute the path-scoped revision exactly as the Lua write side does
      (repo root resolution, then `git log -1 --format=%H -- <source_dir>`) and compare against the
      recorded value. Skip silently if the recomputed value is empty.
- [ ] On mismatch, print one WARN line to stderr per stale extension naming the extension and the
      remedy (`bash .claude/scripts/deploy-headless.sh`, or the picker's `[Reload All]`), plus a
      pointer to `verify-deploy.sh` for per-file detail. Do not print a summary line when nothing
      is stale.
- [ ] Ensure the script never writes files, never mutates state, and ends with an explicit
      `exit 0` on every path.
- [ ] Register the new script in `agent-system/extensions/core/manifest.json` under
      `provides.scripts`, matching the existing entry format.
- [ ] Add no task numbers to the script, its header, or the manifest (deliverable rule).

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly two files change (the new script plus one
`provides.scripts` entry in core's manifest). Confirm at implementation time with
`git status --short` before committing; if registration requires touching an additional index or
manifest, record that in the summary rather than silently widening the phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-deploy-freshness.sh` - new standalone checker
- `agent-system/extensions/core/manifest.json` - register the script under `provides.scripts`

**Verification**:
- `bash agent-system/extensions/core/scripts/check-deploy-freshness.sh .` exits 0 in this repo.
- `bash -n` parses clean; `shellcheck` (if available) reports no errors.
- Manual smoke: hand-edit a copy of `.claude-extensions.json` in a temp directory to carry a bogus
  `source_git_head`, run the checker against it, observe exactly one WARN line and exit code 0.
- Running against a `.claude-extensions.json` with no `source_git_head` fields anywhere produces
  no output and exit code 0.

---

### Phase 3: Isolated test suite for the freshness checker [NOT STARTED]

**Goal**: A repeatable, temp-root suite pinning both acceptance directions and every silent-skip
branch, so the behavior cannot regress unobserved.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` following the
      established convention in that directory (`set -uo pipefail`, pass/fail/info helpers,
      PASSED/FAILED counters, `mktemp -d` root, `trap cleanup EXIT`, exit 0 on all-pass and 1 on
      any failure). Never touch the real `specs/` tree or the real `.claude-extensions.json`.
- [ ] Build the fixture: a throwaway git repository standing in for the source store (with a
      committed extension subdirectory), plus a throwaway consuming repo holding a fabricated
      `.claude-extensions.json` pointing at it, copying the real `check-deploy-freshness.sh`
      byte-for-byte into place.
- [ ] Case STALE: recorded `source_git_head` is an older commit than the fixture source
      subdirectory's current revision -- assert exactly one WARN line naming the extension, that
      the output names the regeneration remedy, and that exit code is 0.
- [ ] Case FRESH: recorded `source_git_head` equals the current revision -- assert no output and
      exit code 0.
- [ ] Case MISSING FIELD: entry has `source_dir` but no `source_git_head` -- assert no output and
      exit code 0.
- [ ] Case UNVERIFIABLE: `source_dir` points outside any git repository (and, separately, at a
      nonexistent path) -- assert no output and exit code 0 for each.
- [ ] Case SCOPING: commit a change elsewhere in the fixture source repo, outside the extension's
      own subdirectory -- assert no output (path-scoped comparison, not whole-repo HEAD).
- [ ] Register the suite in `agent-system/extensions/core/manifest.json` under `provides.scripts`
      alongside the existing `tests/` entries, and confirm it is picked up by
      `scripts/tests/run-all.sh`.

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts six test cases (stale, fresh, missing-field, two
unverifiable variants, scoping). Confirm at implementation time that each case is actually
distinguishable in the fixture; if a case collapses into another, record the merge in the summary
rather than silently dropping coverage.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` - new suite
- `agent-system/extensions/core/manifest.json` - register the suite

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` exits 0 with every
  case reported PASS.
- Deliberately break the checker (e.g. invert the comparison), re-run, and confirm the suite fails
  -- proving the cases are load-bearing rather than vacuous. Restore afterward.
- No files remain under `${TMPDIR:-/tmp}` after the run.

---

### Phase 4: Wire the check into command-gate-in.sh [NOT STARTED]

**Goal**: Every ordinary command's CHECKPOINT 1 emits the warning when the deploy is stale,
without changing any admission decision, exit code, or exported variable.

**Tasks**:
- [ ] In `agent-system/extensions/core/scripts/command-gate-in.sh`, add the freshness call at the
      end of `gate_in`, after the operation header echo and after lock acquisition, so a lock
      refusal never pays the cost and the warning is the last thing printed before real work.
- [ ] Guard the call on the deployed script's existence
      (`[ -f .claude/scripts/check-deploy-freshness.sh ]`) so a tree too stale to have it is a
      silent no-op rather than an error.
- [ ] Invoke it as `bash ... 2>&1 || true` (or equivalent) -- never source it, never let its status
      propagate. `gate_in`'s return value and all six exported variables must be unchanged.
- [ ] Add no shell options to `command-gate-in.sh` -- its module docstring's sourced-into-caller
      contract already forbids this; preserve that invariant.
- [ ] Update the script's header comment to name the new non-blocking check among its
      responsibilities, without task-number references.

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/command-gate-in.sh` - non-blocking freshness call at the
  end of `gate_in`

**Verification**:
- `bash -n agent-system/extensions/core/scripts/command-gate-in.sh` parses clean.
- Source the gate-in script directly in a subshell against a real task number and confirm all of
  `SESSION_ID`, `TASK_TYPE`, `TASK_STATUS`, `PROJECT_NAME`, `DESCRIPTION`, `PADDED_NUM` are still
  exported and the return code is unchanged from before the edit (release any lock acquired).
- Confirm the terminal-status ABORT path and the task-not-found path still return 1 and do not
  reach the freshness call.
- Run the full core test suite (`bash agent-system/extensions/core/scripts/tests/run-all.sh`) and
  confirm no regression versus a pre-edit baseline run.

---

### Phase 5: End-to-end acceptance demonstration, both directions [NOT STARTED]

**Goal**: Evidence, captured in the implementation summary, that an ordinary command against a
stale deploy warns and against a fresh deploy does not -- through the real gate-in path, not a
test fixture.

**Tasks**:
- [ ] Regenerate this repo's deployed tree from source
      (`bash agent-system/extensions/core/scripts/deploy-headless.sh`) so `.claude/` carries the
      new checker and `.claude-extensions.json` carries `source_git_head` for every extension.
- [ ] FRESH direction: run an ordinary command's gate-in against a real non-terminal task and
      capture the output -- no freshness warning appears. Release any lock acquired.
- [ ] STALE direction: in a scratch clone or a temp copy of the consuming-repo layout, deploy,
      then advance the source store's committed revision for one extension (or rewrite that
      entry's recorded `source_git_head` to an older real commit), re-run gate-in, and capture the
      WARN naming that extension and the regeneration remedy.
- [ ] Confirm the warning is non-blocking end-to-end: the command proceeds normally with the
      warning present.
- [ ] Measure and record the added preflight wall time across all active extensions (compare
      gate-in timing with and without the check).
- [ ] Record both captured outputs verbatim in the implementation summary as the acceptance
      evidence, together with the stated root cause (structural pull-only regeneration; no loader
      defect).

**Timing**: 0.75 hours

**Depends on**: 1, 3, 4

**Verification Tier**: full

**Files to modify**:
- None (verification and evidence capture only; the summary artifact is written at wrap-up)

**Verification**:
- Both captured outputs exist and differ exactly as the acceptance criterion requires.
- Measured added preflight cost is recorded as a concrete number, not an estimate.
- The scratch/temp repo used for the stale direction is removed afterward, and this repo's own
  `.claude/` tree is left in a freshly deployed state.

---

### Phase 6: Document the detection half of the pull-only pattern [NOT STARTED]

**Goal**: A future reader of the manual-only regeneration pattern immediately sees both halves --
that regeneration is pull-only, and how a stale repo now finds out.

**Tasks**:
- [ ] Add a "Detecting When You're Stale" section to
      `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` covering: the
      `source_git_head` stamp and where it is written, the gate-in check and its non-blocking
      contract, the deliberate silent-skip cases (missing field, non-git or absent `source_dir`,
      git unavailable) and why silence rather than a "cannot verify" notice is correct, the
      commit-granular and single-machine limitations, and the pointer to `verify-deploy.sh` for
      per-file detail.
- [ ] State the root-cause finding plainly in that section: the staleness was never a loader
      defect; the copy engine force-overwrites unconditionally and `installed_files` is never a
      copy gate.
- [ ] Cite durable anchors only -- filenames, function names, section headings. No task numbers
      anywhere in this documentation (deliverable rule).

**Timing**: 0.5 hours

**Depends on**: 5

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - new
  "Detecting When You're Stale" section

**Verification**:
- Every changed hunk lies inside prose; no executable content is touched.
- `bash .claude/scripts/check-task-references.sh` (or the equivalent repo-wide lint) reports no
  new task-number references.
- Every file, function, and script named in the new section exists at the path given.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` passes, with the
      deliberate-break check confirming the cases are load-bearing.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` shows no regression against a
      pre-change baseline.
- [ ] `bash -n` clean on `check-deploy-freshness.sh` and `command-gate-in.sh`.
- [ ] A headless deploy into a scratch repo yields a 40-hex `source_git_head` for every extension
      in that repo's `.claude-extensions.json`.
- [ ] Gate-in against a real task still exports all six variables and preserves its return codes
      on the success, not-found, and terminal-status paths.
- [ ] Acceptance demonstrated in both directions with captured output (Phase 5).
- [ ] Added preflight cost measured and recorded.
- [ ] No file under `.claude/` was hand-edited (`git status` plus a review of every changed path
      confirms edits landed only in `agent-system/extensions/**` and `lua/**`).

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/extensions/state.lua` (modified) - `source_git_head` stamping
- `agent-system/extensions/core/scripts/check-deploy-freshness.sh` (new) - standalone checker
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` (new) - test suite
- `agent-system/extensions/core/scripts/command-gate-in.sh` (modified) - non-blocking call
- `agent-system/extensions/core/manifest.json` (modified) - two `provides.scripts` registrations
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (modified) -
  detection documentation
- `specs/018_detect_stale_claude_deploy_trees/summaries/01_stale-deploy-detection-summary.md` -
  implementation summary carrying the both-directions acceptance evidence

## Rollback/Contingency

Every change is additive and independently revertible:
- Reverting the `command-gate-in.sh` hunk (Phase 4) alone disables all user-visible behavior
  change while leaving the stamp and checker in place, harmless and unread.
- Reverting the `state.lua` hunk (Phase 1) stops new stamps; existing entries become
  indistinguishable from pre-fix deploys and are skipped silently by the checker's own
  missing-field branch -- no error, no noise.
- The new script and test suite can be deleted and their `provides.scripts` entries removed; the
  guard in `command-gate-in.sh` treats an absent checker as a silent no-op, so removal order does
  not matter.
- No data migration, no state schema break: the field is optional by construction, and every
  reader of `.claude-extensions.json` other than the new checker ignores unknown keys.
- After any revert, run `bash agent-system/extensions/core/scripts/deploy-headless.sh` to bring
  the deployed tree back in line with the reverted source.
