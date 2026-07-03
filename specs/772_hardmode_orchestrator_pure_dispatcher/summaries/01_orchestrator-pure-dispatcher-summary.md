# Implementation Summary: Task #772

**Completed**: 2026-07-03
**Duration**: ~1 hour

## Overview

Made `skill-orchestrate-hard` a pure dispatcher, structurally incapable of doing implementation
work itself. All six plan phases landed against `.claude/skills/skill-orchestrate-hard/SKILL.md`
and its byte-identical mirror `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`.
`Edit` was removed from `allowed-tools`, a prose "Tool Constraints (Pure Dispatcher)" section
documents the Bash forbid-list and four-category Read allowlist, Parallel Wave Dispatch (H7) was
disabled in favor of unambiguous single-phase blocking dispatch, phase selection now uses a
heading-scan (mirroring task 774's `skill-implementer-hard` fix) with skeleton-exhaustion routing
to `pr_ready`, and Stage 5's postflight `implemented` transition is gated on
`phases_completed >= phases_total` so a single per-phase handoff never prematurely completes the
whole task.

## What Changed

- `.claude/skills/skill-orchestrate-hard/SKILL.md` — six regions edited: frontmatter
  `allowed-tools` (line 4), new `## Tool Constraints (Pure Dispatcher)` section, H7 overview
  bullet reworded, Parallel Wave Dispatch section replaced with a "DISABLED" prose note, Key
  Differences table row updated, Per-Phase Dispatch handler's `next_phase` selection replaced
  with a heading-scan plus a new skeleton-exhaustion branch, and Stage 5 rewritten as an explicit
  hard-mode block with a gated `implemented` postflight transition and extended
  `sorry_inventory`/`skeleton`/`follow_up_task` logging.
- `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — mirrored copy of the
  deployed file (Phase 6); `diff -q` between the two copies returns empty.

## Decisions

- **Frontmatter tool scoping (Item 1/2/4)**: Took the plan's documented fallback path
  (`allowed-tools: Agent, Bash, Read`, `Edit` removed) rather than the multi-pattern
  `Bash(cmd:*), Read(path/*)` scoped form. No in-repo precedent exists for multi-pattern-per-line
  `allowed-tools` frontmatter (only `skill-git-workflow`'s single `Bash(git:*)` pattern was
  found), and this implementation agent has no sandboxed harness to runtime-verify Claude Code's
  frontmatter tool-scope enforcement independent of a live invocation. The Phase 2 prose
  "Tool Constraints (Pure Dispatcher)" section — Permitted Bash, Forbidden Bash Operations, and
  the four-category Read allowlist/forbidden-reads — is therefore the primary behavioral gate,
  as the plan's own risk mitigation anticipated.
- **Parallel Wave Dispatch removal**: Removed the `#### State:` heading entirely (not just its
  code block), replacing it with a short prose "DISABLED" note with no heading of its own, so
  exactly one `#### State: \`planned\` or \`implementing\`` handler remains in the file — this
  more strictly satisfies the plan's own verification criterion ("only one handler remains")
  than "keep the heading, mark it disabled."
- **Skeleton-exhaustion routing target**: Routes to `pr_ready` via the centralized
  `.claude/scripts/update-task-status.sh postflight ... pr_ready ...` script rather than a raw
  `jq` write to `state.json`, per `state-management.md`'s rule against hand-rolled state writes.
  The follow-up task list is logged to the transcript via `echo`, not persisted as a new,
  unschematized `state.json` field.
- **Stage 5 rewrite scope**: Also preserved the base skill's drift-detection logic
  (`DRIFT_COMPLETION_THRESHOLD`/`invoke_drift_inspection`), which was previously inherited only
  by reference ("Same as base Stage 5, plus:"). Since the plan required rewriting Stage 5 as an
  explicit, self-contained block, silently dropping drift detection would have been an
  undocumented regression; carrying it forward keeps the rewrite a strict superset of the
  original behavior.

## Plan Deviations

- **Task 1.1** altered: landed the frontmatter as the plan's own documented prose-fallback
  (`Agent, Bash, Read`) instead of the multi-pattern scoped form, because no in-repo precedent
  or runtime-verification harness exists for that syntax (see Decisions).
- **Task 3.1** altered: removed the Parallel Wave Dispatch `####` heading entirely (not just its
  code block) to strictly satisfy the "only one handler remains" verification criterion.
- **Task 4.2** altered: routes skeleton-exhaustion to `pr_ready` via the centralized
  `update-task-status.sh` script rather than a raw `jq` write to `state.json`.
- **Task 5.2** altered: also preserved drift-detection logic during the Stage 5 rewrite, beyond
  the plan's literally-named researched/planned/artifact-linking preservation list, to avoid a
  silent regression.

## Verification

- Build: N/A (markdown skill-definition file; no build step)
- Tests: N/A (no automated test suite for skill prose files)
- Files verified: Yes — `allowed-tools` line confirmed `Edit`-free on both copies; zero remaining
  `next_phase=$((phases_completed + 1))` occurrences; exactly one Per-Phase Dispatch handler
  heading; Stage 5 `implemented` transition gate present; `diff -q` between deployed and core
  copies returns empty; YAML frontmatter parses via `yaml.safe_load`; reserved regions
  (`build_hard_mode_prompt_context()` body and the Stage 1b-3b loop-top region reserved for
  tasks 779 and 773 respectively) are byte-identical to the pre-772 git baseline modulo line
  offset from earlier insertions.

## Notes

- Base `skill-orchestrate` was not touched, per the plan's explicit out-of-scope declaration.
- `wrap-up.md` (task 778's skeleton/`sorry_inventory` schema) was read and used as the ground
  truth for the `follow_up_task` field name and the `skeleton` boolean's semantics — confirming
  the plan's flagged divergence from `skill-implementer-hard`'s unpopulated top-level
  `.follow_up_tasks` field.
- Territory boundaries for tasks 779 (`build_hard_mode_prompt_context()` body,
  now at lines ~385-397) and 773 (Stage 1b through Stage 3b loop-top region, now shifted ~42
  lines later due to the new Tool Constraints section) were left untouched and are delimited by
  the new HTML-comment markers this task introduced around its own additions, so both sibling
  tasks can compose cleanly around them.
