# Implementation Summary: Task #884

**Completed**: 2026-07-16
**Duration**: ~1 hour

## Overview

Extended the existing `guard-destructive-git.sh` PreToolUse Bash hook with three independent
over-staging detectors (`git add -A`/`--all`, `git add .`, `git commit -a`/`-am`/`--all`) and
fixed two prose locations that previously instructed agents to run commands the hook now blocks.
All edits landed in the tracked source tree (`agent-system/extensions/core/`), never the
gitignored `.claude/` deploy tree, and the live `.claude/hooks/guard-destructive-git.sh` copy
was never overwritten or invoked during this run — all verification drove the tracked source
file directly.

## What Changed

- `agent-system/extensions/core/hooks/guard-destructive-git.sh` — added a header comment section
  documenting the three over-staging patterns and the no-exemption rationale, plus an independent
  detector block (own `exit 2`, own remediation text) inserted after the clean-tree gate and
  before the existing `MATCHED=0` destructive-command chain. Detectors strip quoted spans before
  flag-scanning to avoid false-positiving on commit messages like `-m "fix -a regression"`.
- `agent-system/extensions/core/context/orchestration/postflight-pattern.md` — reworded the two
  `Manual fix: git add . && git commit -m ...` fallback instructions (lines 228, 247) to point at
  scoped staging instead, avoiding the literal blocked-command text.
- `agent-system/extensions/core/skills/skill-project-overview/SKILL.md` — narrowed the Step 5.6
  git commit template from `git add specs/ .claude/` (over-broad and actively broken, since
  `.claude/` is gitignored) to `git add "$task_dir" specs/TODO.md specs/state.json`, reusing the
  step's existing `task_dir` variable.
- `specs/884_extend_git_guard_hook_to_block_overstaging/summaries/01_extend-git-guard-overstaging-summary.md`
  — this summary.

## Decisions

- New detectors placed **before** the `MATCHED=0` destructive-command chain and exit
  independently, so a fresh snapshot marker can never exempt over-staging (scope pollution is not
  made acceptable by a recoverable snapshot, unlike data-loss-preventing destructive commands).
- Quote-stripping (`sed -e 's/"[^"]*"/""/g' -e "s/'[^']*'/''/g"`) applied to both the `git add`
  and `git commit` detectors before flag-scanning, mitigating a false positive the plan's research
  phase missed by hand-tracing: `git commit -m "fix -a regression"` would otherwise block.
- No exemption mechanism was built for `git-snapshot.sh`'s own internal `git add -A` — verified
  empirically that the hook only ever observes the literal top-level `tool_input.command` string,
  and the opaque `bash .claude/scripts/git-snapshot.sh --branch ...` call contains none of the
  scanned substrings.

## Plan Deviations

- **Phase 2, prose wording**: The plan's own suggested `Manual fix: ... (do not use git add -A /
  git add . / git commit -am)` example text contains the literal substring `git add .`, which
  would fail the plan's own Phase 2 verification grep for that substring. Reworded to describe
  forbidden flags (`-A`/`--all`, bare dot pathspec, `-a`/`-am`) without the literal three-token
  command string, preserving the same guidance intent.
- **Phase 3, marker-independence check**: Constructed the snapshot marker file directly
  (`TIMESTAMP=$(date +%s)` under the task's `.git-snapshot-marker`) rather than invoking the real
  `scripts/git-snapshot.sh`, to avoid a real `git stash`/branch operation touching the shared
  working tree's concurrent-session uncommitted changes (task 882 was running in parallel per the
  plan's Territory note). The marker contract consumed by the hook is identical either way.
- **Phase 3, tracked-edits check**: Verified via `git show --stat` on the phase commits instead of
  `git status --short`, since edits were already committed per the mandatory
  commit-per-green-substep cadence by the time this check ran.
- **Mid-implementation git-scope correction**: a `git add specs/884_.../` + commit accidentally
  swept in an unrelated task's file (`specs/880_.../summaries/...`) that was staged in the shared
  index by a concurrent session at commit time. Caught immediately, fixed via a non-destructive
  `git reset` (mixed, not `--hard`) that unstaged without discarding any content, then re-staged
  and re-committed scoped precisely to task 884's files only. Task 880's changes were left exactly
  as they were (uncommitted) for that task's own workflow to commit. This incident is itself a
  live illustration of the over-staging problem this task's hook now guards against, though the
  hook could not have prevented it (it guards `git add`/`git commit` *arguments*, not
  concurrently-staged index contents from other sessions).

## Verification

- Build: N/A (bash hook, not a compiled artifact)
- Tests: 26/26 manual cases passed against the tracked source hook
  (`bash agent-system/extensions/core/hooks/guard-destructive-git.sh`), driven via JSON payloads
  on stdin, on a confirmed-dirty tree:
  - 9/9 MUST BLOCK cases exit 2 (`git add -A`, `--all`, bare `.`, both, `-am`, `-a -m`, bare `-a`,
    `--all -m`, flag-after-message)
  - 14/14 MUST NOT BLOCK cases exit 0 (the sanctioned `git-snapshot.sh --branch` call, `--amend`,
    `--author=`, `--allow-empty`, `.env`, `.gitignore`, relative-path pathspecs, canonical scoped
    staging, plain commits, and the four quoted-message false-positive cases)
  - 3/3 existing destructive detectors unchanged (`reset --hard` still blocks; `stash pop` and
    `restore --staged` still pass)
  - Marker independence confirmed: a fresh snapshot marker does not exempt `git add -A` but still
    exempts and consumes on `git reset --hard`
- Files verified: Yes — `bash -n` parses the hook clean; all three tracked-source edits confirmed
  present via `git show --stat`; no `.claude/` path in any commit; no new task-number citation
  introduced by this task's diffs (pre-existing "task 796"/"Task 326" references in the touched
  files predate and are untouched by these edits).

## Notes

Follow-up (out of scope, recommended by the plan): no durable automated test harness exists for
`guard-destructive-git.sh` (`hooks/` has no `tests/` subdirectory). A future task should add one
covering both the existing destructive cases and the over-staging cases, including the
quoted-message false-positive class identified during this task's planning phase.
