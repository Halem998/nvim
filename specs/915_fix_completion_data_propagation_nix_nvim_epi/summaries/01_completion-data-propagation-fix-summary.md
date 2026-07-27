# Implementation Summary: Task #915

**Completed**: 2026-07-27
**Duration**: ~0.5 hours

## Overview

Closed the mirror-image `completion_data` propagation gap in the `nix`, `nvim`, and
`epidemiology` implementer skills: each generated `completion_data` on the agent side but never
read it back out of `.return-meta.json` in its postflight, so `completion_summary` and
`roadmap_items` were silently dropped before reaching `state.json`. Applied the established
`core` fix shape — extend the metadata-read step to pull the two fields, then call the existing
shared writer `skill_propagate_completion_summary` from `scripts/skill-base.sh` — as a purely
additive change to each of the three files.

## What Changed

- `agent-system/extensions/nix/skills/skill-nix-implementation/SKILL.md` — added a
  self-contained bash block under Stage 5 (binds `padded_num`/`project_name`/`metadata_file`,
  reads `status`, the three artifact fields, and the two `completion_data` fields) and a gated
  bash block under Stage 6 (`source .claude/scripts/skill-base.sh` +
  `skill_propagate_completion_summary` with literal task_type `"nix"`).
- `agent-system/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` — identical
  insertion, literal task_type `"neovim"` (matches this skill's Trigger Conditions string).
- `agent-system/extensions/epidemiology/skills/skill-epi-implement/SKILL.md` — extended the
  existing Stage 6 metadata-read bash block with the two `completion_data` assignments (inside
  the existing `if`/`else` guard, unchanged otherwise), and added a new gated bash block after
  the Stage 7 table calling the shared writer with the in-scope `$task_type` variable.

## Decisions

- Gated all three call sites on `implemented`, accepting `completed` as well — the research
  report's suggested gate value (`completed` alone, matching the epidemiology Stage 7 table's
  existing row) would have made the fix dead code, since all three agent files
  (`nix-implementation-agent.md`, `neovim-implementation-agent.md`, `epi-implement-agent.md`)
  write `"status": "implemented"` at their terminal metadata write, never `"completed"`.
- Made the nix/nvim insertions fully self-contained: both files contain no bash anywhere and
  never bind `task_number`, `project_name`, `padded_num`, or `session_id`, so the inserted Stage
  5 block binds `padded_num` (via `printf "%03d"`) and `project_name` (via a `jq` lookup against
  `specs/state.json`) itself, mirroring the idiom `core` and `epidemiology` already use in their
  own Stage 1/Stage 6 blocks. `skill-base.sh` needed no caller-side setup beyond sourcing — it
  self-defaults `SKILL_REPO_ROOT` at source time.
- Used the literal `"nix"` / `"neovim"` task_type strings for those two skills (verified against
  each skill's own Trigger Conditions section before writing) rather than introducing an unused
  `task_type` binding solely for this call; epidemiology already had an in-scope `$task_type`
  variable from its Stage 1, so used that directly instead of a literal.
- Did not duplicate the shared writer's guard logic (non-empty `completion_summary`;
  `task_type != "meta"` AND non-empty/non-`"[]"` `roadmap_items`) at any call site — all three
  call sites are a thin status gate plus the single function call, with a one-line comment
  pointing at `context/formats/return-metadata-file.md` instead of restating the schema.

## Plan Deviations

- None (implementation followed plan). The one item the plan explicitly called out as
  deliberately *not* to fix — epidemiology's Stage 7 table row mapping a `completed` meta status
  the agent never emits — was left untouched exactly as directed; see Notes below rather than
  Deviations, since leaving it alone was the plan's instruction, not a departure from it.

## Verification

- Build: N/A (markdown-only change)
- Tests: N/A
- Each added/modified fenced bash block passes `bash -n` (2 blocks in nix, 2 in nvim, 3
  touched/added in epidemiology — all pass).
- All three call sites match `skill_propagate_completion_summary`'s four-positional-argument
  signature (`task_number`, `completion_summary`, `roadmap_items`, `task_type`) in
  `agent-system/extensions/core/scripts/skill-base.sh`.
- All three gates were cross-checked against the terminal `status` value each corresponding
  agent file actually emits (`implemented` in all three) and accept it.
- `git diff` for each of the three files is insertion-only: no existing prose line, stage
  heading, stage number, table, or trigger condition was altered or removed.
- `git status --short` shows modifications confined to `agent-system/extensions/**` and this
  task's own `specs/915_.../` directory — zero `.claude/` paths (that tree is a gitignored,
  disposable deploy artifact regenerated from this source store, per the task's binding
  source-store rule).
- No task-number citation pattern (`task 915`, `task N`, `(task ...)`) found in any of the three
  changed files.
- Files verified: Yes

## Notes

Three follow-up items recorded per Phase 4, none acted on in this task:

1. **Deferred shared-script/postflight-hook extraction.** The two-line
   `source .claude/scripts/skill-base.sh` + `skill_propagate_completion_summary` boilerplate is
   now duplicated across eight call sites (`core`, `core-hard`, `lean`, `lean-hard`, `web`, and
   now `nix`, `nvim`, `epidemiology`). Extracting it into a further shared script or a
   manifest-declared `postflight` lifecycle hook was explicitly out of scope for this task — it
   would have to touch the five already-fixed skills as well and merits its own design pass on
   whether a lifecycle hook is the right shape.
2. **Epidemiology Stage 7 table row observation.** The Stage 7 table in
   `skill-epi-implement/SKILL.md` still lists `completed` as the meta-status row that maps to a
   final `completed` state.json value, but the agent's terminal metadata write emits
   `"status": "implemented"` — a pre-existing latent mismatch predating this task. This task's
   new bash block gates on `implemented` (accepting `completed`) to make the fix reachable, but
   deliberately did not edit the table itself, since doing so would alter status-mapping
   semantics beyond this fix's scope. Left as a follow-up.
3. **`return-metadata-file.md` "Known callers" documentation gap.** The schema doc names
   `skill_propagate_completion_summary` as (per `core`'s own comment) "one of six call sites that
   converge on that single function," but no context file enumerates which implementer skills
   currently call it. Now that this task brings the total to eight call sites (`core`,
   `core-hard`, `lean`, `lean-hard`, `web` inline-duplicated, plus `nix`, `nvim`, `epidemiology`),
   a short "Known callers" list in `return-metadata-file.md`'s `completion_data` section would
   let a future extension author see the converged pattern at a glance instead of rediscovering
   it by grepping every implementer skill. Not added here — recorded as a documentation
   follow-up only.
