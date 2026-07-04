# Implementation Summary: Task #785

**Completed**: 2026-07-04
**Duration**: ~70 minutes

## Overview

Replaced the repo-wide `git add -A` in the core single-agent commit pipeline (~6-item scope:
`orchestrator-postflight.sh`, `skill-implementer/SKILL.md`, `general-implementation-agent.md`,
`git-workflow.md`, `skill-git-workflow/SKILL.md`, plus the new `git-staging-scope.md` standard)
with targeted, work-scoped staging. Introduced an agent self-reported `modified_files` /
`files_touched` mechanism so the `implement` operation stages exactly the files it touched
instead of the entire working tree. All 7 planned phases were executed in full, following the
plan's dependency waves (1 → {2,5} → {3,4} → 6 → 7).

## What Changed

- `.claude/context/standards/git-staging-scope.md` — New canonical standard defining the
  per-operation (`research`/`plan`/`implement`) commit-scope contract, the proven `--team`
  staging template, forbidden operations, and the fail-safe under-stage direction.
- `.claude/extensions/core/context/standards/git-staging-scope.md` — Byte-identical dual copy.
- `.claude/context/formats/return-metadata-file.md` — Added optional `modified_files:
  string[]` field with `// []` jq-fallback semantics, documented like `completion_data`/
  `memory_candidates`.
- `.claude/context/formats/progress-file.md` — Added additive per-objective `files_touched: []`
  field.
- `.claude/agents/general-implementation-agent.md` — Stage 4 now tracks every `Write`/`Edit`
  path into the current objective's `files_touched`; a new "Stage 6-modified-files" section
  sums `files_touched` across all phases into `modified_files` for Stage 7's return-meta; the
  Phase Checkpoint Protocol's per-phase commit converted to targeted staging.
- `.claude/extensions/core/agents/general-implementation-agent.md` — Byte-identical dual copy.
- `.claude/scripts/orchestrator-postflight.sh` — Stage 9 rewritten to branch on
  `operation_type`: `plan` stages the task directory + `specs/TODO.md` + `specs/state.json`;
  `implement` additionally stages the plan file and each `modified_files` entry. A non-silent
  warning fires when `modified_files` is absent/empty, and `git status --porcelain` is checked
  post-commit to surface any residual uncommitted changes. `research`'s `do_git_commit=false`
  is unchanged.
- `.claude/skills/skill-implementer/SKILL.md` — Stage 6b (per-phase progress commit) and Stage
  9 (final "complete implementation" commit) both converted to targeted staging; Stage 9's
  malformed code fence (missing closing fence/quote) was also repaired; a reconciliation note
  clarifies this skill runs its own inline postflight rather than delegating to
  `orchestrator-postflight.sh`.
- `.claude/extensions/core/skills/skill-implementer/SKILL.md` — Byte-identical dual copy
  (syncing also incidentally fixed unrelated pre-existing drift in the `--lit` section's
  script-name reference — see Plan Deviations).
- `.claude/rules/git-workflow.md` — Added `git add -A` and `git commit -am` to the "Never Run"
  list; referenced `git-staging-scope.md` from "Commit Scope" and "Always Check Before Commit".
- `.claude/extensions/core/rules/git-workflow.md` — Byte-identical dual copy.
- `.claude/skills/skill-git-workflow/SKILL.md` — Added a "Relationship to
  `orchestrator-postflight.sh`" section clarifying this skill is a documentation front, not a
  literal execution path; "Commit Scope Rules" now points at `git-staging-scope.md`; "Never
  Run" list hardened.
- `.claude/extensions/core/skills/skill-git-workflow/SKILL.md` — Byte-identical dual copy.

`skill-team-research/SKILL.md`'s dangling reference at line 563 was NOT edited — it already
resolves now that `git-staging-scope.md` exists (created in Phase 1); confirmed both copies
remain byte-identical.

## Decisions

- Reused the proven `--team` staging template verbatim (per-plan requirement) rather than
  inventing a new pattern.
- `modified_files` is agent self-report, not git-diff derivation, matching the plan's explicit
  rationale (diffing cannot distinguish this task's changes from concurrent stray edits).
- Removed every literal `git add -A` occurrence — including in comments/prose — from the 3
  actual execution sites (`orchestrator-postflight.sh`, `skill-implementer/SKILL.md`,
  `general-implementation-agent.md`) so a blind grep returns zero hits there. The 3
  policy/documentation files (`git-workflow.md`, `skill-git-workflow/SKILL.md`, and
  `git-staging-scope.md` itself) intentionally retain the literal string, since Phase 5/6
  explicitly require their "Never Run" / "Forbidden Operations" lists to name the forbidden
  command. This reconciles an apparent tension in the plan's Phase 7 wording ("grep across the
  6 core files; confirm zero residual hits") — read as targeting the execution surface where
  the actual bug lived, not the policy prose that must describe it.
- `skill-implementer/SKILL.md`'s inline "Stage 9: Git Commit" was confirmed NOT vestigial: it
  is this skill's own final commit, executed inline rather than via delegation to
  `orchestrator-postflight.sh` (the script's own header comment claims delegation happens, but
  no such call exists in the skill file — a pre-existing architecture note left for future
  follow-up, out of scope here). Fixed its staging and repaired its malformed code fence rather
  than removing it.

## Plan Deviations

- **Incidental dual-copy drift fix** (Phase 4): The `extensions/core` copy of
  `skill-implementer/SKILL.md` had pre-existing drift unrelated to git staging (a stale
  `literature-briefing.sh` vs `literature-briefing-invoke.sh` script-name reference in the
  `--lit` section). Syncing the whole file — required anyway to satisfy Phase 7's diff-empty
  check for this pair — incidentally corrected this unrelated drift to match the canonical
  (non-extension) version. Recorded in `progress/phase-4-progress.json` `deviations`.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: N/A (documentation/script task; verification was the Phase 7 checks below)
- Files verified: Yes
- `diff -q` on all 5 dual-copy pairs (`git-staging-scope.md`, `git-workflow.md`,
  `skill-implementer/SKILL.md`, `general-implementation-agent.md`, `skill-git-workflow/SKILL.md`):
  all identical.
- `grep -n "git add -A"` on the 3 execution sites (`orchestrator-postflight.sh`,
  `skill-implementer/SKILL.md`, `general-implementation-agent.md`): zero hits each.
- `bash -n .claude/scripts/orchestrator-postflight.sh`: parses clean.
- `research` operation: `do_git_commit="false"` confirmed unchanged.
- `grep -rn "git-staging-scope.md" .claude/`: every reference resolves to an existing file.
- Informational: 92 files outside the 6-item core pipeline still contain `git add -A` —
  confirmed as task 786's scope; `.claude/scripts/git-snapshot.sh` line 150 confirmed
  untouched/exempt (full-tree WIP snapshot, intentionally out of scope).

## Notes

- This implementation was performed by the general-implementation-agent under orchestrator
  delegation. Per the delegating orchestrator's explicit instruction, this run does NOT stage
  or commit any changes — that is the orchestrator's responsibility. A separate
  `.orchestrator-handoff.json` file was written alongside the normal `.return-meta.json` to
  hand off the complete list of modified files for the orchestrator's own commit.
- Follow-up (out of scope for 785, task 786's territory): the ~80 other extension-level `git
  add -A` sites, and the pre-existing architectural note that `orchestrator-postflight.sh`'s
  header comment claims `skill-implementer/SKILL.md` delegates Stages 8-10 to it, when in fact
  the skill file implements all of Stages 6-10 inline.
