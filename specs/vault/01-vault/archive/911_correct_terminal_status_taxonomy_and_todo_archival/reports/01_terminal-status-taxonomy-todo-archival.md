# Research Report: Task #911

**Task**: 911 - correct_terminal_status_taxonomy_and_todo_archival
**Started**: 2026-07-27T01:40:00Z
**Completed**: 2026-07-27T01:54:00Z
**Effort**: small-medium (2-3 targeted edits, no new scripts)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/), grep across specs/ for live cross-task references
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `/todo` archival filter bug is real and confirmed at both cited sites: `commands/todo.md:400` and (implicitly, via its own separate but consistent scan at) `skills/skill-todo/SKILL.md` Stage "ScanTasks" both scan **only** `status == "completed"` and `status == "abandoned"`. Neither ever matches `status == "expanded"`, so expanded tasks are permanently unarchivable through `/todo`.
- The taxonomy is **not** wrong at its authoritative source. `agent-system/extensions/core/context/standards/status-markers.md` (the single source of truth referenced by state-management.md) correctly lists exactly three terminal states — `[COMPLETED]`, `[ABANDONED]`, `[EXPANDED]` — and explicitly documents `[PARTIAL]` and `[BLOCKED]` as non-terminal ("Valid Transitions: Any command ... can run from this status"). Every executable status-gate in the codebase (`skill-base.sh`, `command-gate-in.sh`, `orchestrate-batch-admit.sh`, `orchestrate-triage-classify.sh`, `spawn.md`, `research.md`, `plan.md`, `implement.md`, `orchestrate.md`, `generate-todo.sh`, `generate-task-order.sh`, skill-planner/-implementer/-hard SKILL.md preflights, etc.) agrees: terminal = `{completed, abandoned, expanded}` only, never `partial`/`blocked`.
- The actual defect is narrower and lives in exactly one place: **`agent-system/extensions/core/merge-sources/claudemd.md` line 39**, which reads `` `[BLOCKED]`, `[ABANDONED]`, `[PARTIAL]`, `[EXPANDED]` - Terminal/exception states ``. This single bullet conflates two different things under one ambiguous label ("Terminal/exception") and is the sole place in the entire source tree where `BLOCKED`/`PARTIAL` are grouped with genuinely terminal states. It is a documentation/summary defect, not a taxonomy defect in the enforced system — but it is exactly the sentence that misled `/todo`'s original author into a filter that (correctly, per the *real* taxonomy) still excludes `PARTIAL`/`BLOCKED` but (incorrectly) also excludes `EXPANDED`.
- Recommended fix has two independent parts, both in scope:
  1. **Widen the archival filter** in `commands/todo.md` and `skills/skill-todo/SKILL.md` to include `status == "expanded"` (state.json) / `[EXPANDED]` (TODO.md), routing expanded tasks to `archive/state.json`'s `completed_projects` array (not `archived_projects`, which the codebase's convention reserves for `abandoned`).
  2. **Repair the summary line** in `merge-sources/claudemd.md` so `PARTIAL`/`BLOCKED` are no longer grouped with `ABANDONED`/`EXPANDED` under one "terminal" label — split into a genuinely-terminal bullet and a separate non-terminal "exception status" bullet.
- Archival reachability (parent-artifact references from still-active sibling/child tasks) is a **real, observed** pattern in this very repository (concrete examples below), but it is a **pre-existing, system-wide gap** that already affects `completed`/`abandoned` archival today — adding `expanded` to the filter does not create a new category of risk, it only extends an existing unaddressed limitation to one more status. A narrow, cheap, `expanded`-specific mitigation is available and recommended (defer archiving an expanded parent while any of its `subtasks[]` are still non-terminal); a general reachability fix (e.g., leaving a symlink pointer) is undermined by the existing vault-renumbering feature and is out of proportion to this task's file scope.

## Context & Scope

Investigated whether `/todo`'s archival scan should be widened to include `status == "expanded"`, and whether the CLAUDE.md status-marker table's grouping of `[BLOCKED]`, `[ABANDONED]`, `[PARTIAL]`, `[EXPANDED]` under "Terminal/exception states" reflects a genuine taxonomy defect that needs correcting at its source (rather than papering over a wrong table by blindly widening the filter). Also investigated whether archiving an expanded task's directory can break references held by its child/successor tasks.

File scope for the eventual fix, per delegation: `agent-system/extensions/core/commands/todo.md`, `agent-system/extensions/core/skills/skill-todo/SKILL.md`, `agent-system/extensions/core/merge-sources/claudemd.md`.

## Findings

### Codebase Patterns

**1. The archival filter bug — confirmed, both sites.**

`agent-system/extensions/core/commands/todo.md`:
- Lines 27-28 (documented scan): "Tasks with status = `completed`" / "Tasks with status = `abandoned`" — no mention of `expanded`.
- Line 400 (actual jq executed): `jq 'del(.active_projects[] | select(.status == "completed" or .status == "abandoned"))'`.

`agent-system/extensions/core/skills/skill-todo/SKILL.md`:
- Stage "ScanTasks" (lines 78-87) identifies only `status = "completed"` and `status = "abandoned"`, tracking `completed_count`/`abandoned_count` — same omission.
- Notably, this same file's Stage "TopicRevision" (lines 94-97) *already* excludes `expanded` alongside `completed`/`abandoned` when computing which active tasks still need a topic backfill:
  ```jq
  select(.status == "completed" | not) |
  select(.status == "abandoned" | not) |
  select(.status == "expanded" | not) |
  ```
  This is direct in-file evidence that the author of `skill-todo/SKILL.md` already understood `expanded` belongs in the same "no longer actionable" bucket as `completed`/`abandoned` — the archival Stage 2 scan simply never got the same update. This is a strong signal the fix is a straightforward oversight-correction, not a design question.

**2. The authoritative taxonomy is correct; only one summary line is wrong.**

`agent-system/extensions/core/context/standards/status-markers.md` (marked "Status: Active", "Single source of truth for status markers") states, per-marker:
- `[PARTIAL]` (line 106-111): "Meaning: Implementation partially completed (can resume)." / "Valid Transitions: Any command (research, plan, implement, revise) can run from this status."
- `[BLOCKED]` (line 113-122): "Meaning: Task is blocked by dependencies or issues." / "Valid Transitions: Any command ... can run from this status."
- `[ABANDONED]` (line 124-133): "Valid Transitions: Terminal state. No further transitions."
- `[EXPANDED]` (line 156-167): "Valid Transitions: Terminal state. No further transitions (work continues in subtasks)."
- The explicit "Validation Rules" section (lines 279-289) states plainly: **"Terminal States (block all transitions): `[COMPLETED]`, `[ABANDONED]`, `[EXPANDED]`"** — `PARTIAL` and `BLOCKED` are pointedly absent.
- The ASCII transition diagram (lines 211-237) places `PARTIAL` and `BLOCKED` inside the "Any Non-Terminal Status" box that can enter `/research`, `/plan`, `/implement` again, and lists `Terminal states (no further transitions): [COMPLETED], [ABANDONED], [EXPANDED]` separately.

Every executable enforcement point in the codebase agrees with this three-state terminal set (confirmed by grep across `agent-system/extensions/core/`):
- `scripts/skill-base.sh:189` — `if status = completed || abandoned || expanded`
- `scripts/command-gate-in.sh:63` — same three-way case
- `scripts/orchestrate-batch-admit.sh:306` / `scripts/orchestrate-triage-classify.sh:203` — `def is_terminal: ... completed or abandoned or expanded`
- `commands/spawn.md:62,65`, `commands/research.md:144`, `commands/implement.md:69`, `commands/plan.md:138`, `commands/orchestrate.md:102,444`, `commands/task.md:501`
- `skills/skill-planner/SKILL.md:65`, `skills/skill-implementer/SKILL.md:62`, `skills/skill-planner-hard/SKILL.md:50`, `skills/skill-implementer-hard/SKILL.md:58`, `skills/skill-orchestrator/SKILL.md:55`, `skills/skill-spawn/SKILL.md:25`
- `scripts/generate-todo.sh:382`, `scripts/generate-task-order.sh:113,153,292`, `context/formats/task-order-format.md:314`
- `rules/state-management.md:42` — "Cannot transition from terminal states (completed, abandoned, expanded)"

This is a unanimous, ~25-site consensus that the *enforced* taxonomy is `{completed, abandoned, expanded}` = terminal, `{partial, blocked}` = non-terminal/resumable. Nothing in the executable system treats `PARTIAL` or `BLOCKED` as terminal.

**3. The one place the wrong grouping actually lives.**

`agent-system/extensions/core/merge-sources/claudemd.md`, line 39 (inside the "Status Markers" subsection under "Task Management"):
```
- `[BLOCKED]`, `[ABANDONED]`, `[PARTIAL]`, `[EXPANDED]` - Terminal/exception states
```
This is the merge source that generates the deployed CLAUDE.md status table the task description quotes. No other file in the repository groups `BLOCKED`/`PARTIAL` with `ABANDONED`/`EXPANDED` under a "terminal" label — this is an isolated documentation defect, not a systemic taxonomy error. The label "Terminal/exception states" is itself the tell: it is trying to name two different categories (genuinely terminal: `ABANDONED`, `EXPANDED`; exceptional-but-resumable: `BLOCKED`, `PARTIAL`) with one ambiguous slash-joined phrase, and a reader (or an agent) skimming just this line — as `/todo`'s filter logic evidently did — has no way to tell that `EXPANDED` was the one omission that mattered while `BLOCKED`/`PARTIAL` correctly stayed excluded.

**4. `archive/state.json` array convention — confirms `expanded` should join `completed_projects`, not `archived_projects`.**

`commands/todo.md` line 392 states the existing convention: "Move each task from state.json `active_projects` to archive/state.json `completed_projects` (for completed tasks) or `archived_projects` (for abandoned tasks)." Line 88-92 of `scripts/archive-task.sh` (an apparently orphaned/unused helper — see Risks below) encodes the same binary split (`abandoned` → `archived_projects`, everything else → `completed_projects`). There is no third array for `expanded`. The natural, minimal-surface-area fix is to route `expanded` tasks into `completed_projects` alongside `completed` (both represent "no further work will happen under this task number"), which matches how the rest of the archival/reporting logic (roadmap matching, CHANGE_LOG entries) already branches only on `completed` vs. `abandoned` — an `expanded` task should behave like `completed` in those downstream branches (it should NOT be treated as `abandoned`, and it should almost certainly be *excluded* from ROADMAP.md matching and completion_summary requirements the way meta tasks already are, since an expanded task by definition has no `completion_summary` of its own — its subtasks do).

**5. Archival reachability — real, but pre-existing and system-wide, not novel to `expanded`.**

Cross-task artifact-path citations (a later/child task's report or plan literally containing a `specs/{other_N}_{slug}/(reports|plans|summaries)/` path pointing at a *different* task number) are a genuine, currently-occurring pattern in this repository. Confirmed via grep of `specs/*/{reports,plans,summaries}/*.md` for paths whose task number differs from the containing task's own number:
- `specs/885_.../reports/01_....md` → references `specs/874_.../...` and `specs/887_.../...`
- `specs/897_.../reports/01_....md` → references `specs/891_.../...`
- `specs/900_.../reports/01_....md` → references `specs/899_.../...`
- `specs/903_.../reports/01_....md` → references `specs/873_.../...`

`commands/todo.md`'s "D. Move Project Directories to Archive" step (lines 408-441) and the equivalent in `skill-todo/SKILL.md` perform a plain `mv "$src" "$dst"` with **no reference rewriting, no reachability check, and no pointer/stub left behind**. This means: **the moment any cited task (874, 887, 891, 899, 873 in the examples above) is archived while the citing report/plan remains active, that citation silently breaks** — and this is already true today for ordinary `completed`/`abandoned` archival, independent of the `expanded` bug. No task-type-specific handling, redirect stub, or link-check exists anywhere in `agent-system/extensions/core/` for this (confirmed by grep for "reachab", "dangling", "broken link", "stale link" — no hits describing this scenario).

A structurally sound "leave a pointer" fix (e.g., replace the moved `specs/{N}_{slug}/` with a symlink into `specs/archive/{N}_{slug}/`) is further undermined by the existing **vault operation** (`scripts/vault-operation.sh`, triggered by `/todo` when `next_project_number > 1000`): vault operations *renumber* archived tasks (subtracting 1000) and relocate the entire `specs/archive/` tree into `specs/vault/{NN-vault}/`. Any symlink or path reference captured before a vault operation would be invalidated by the renumbering regardless of the archival step's own care — the system already accepts that long-lived cross-task path citations have a bounded, not-permanently-guaranteed lifetime. General reachability preservation is therefore an architecture-level question well beyond this task's three-file scope, not a narrow todo.md fix.

**6. A narrower, in-scope mitigation exists that IS specific to `expanded` (unlike the general problem above).**

Unlike arbitrary sibling-to-sibling citations, `expanded` tasks carry a structural, machine-checkable parent→children relationship already present in state.json: `commands/task.md` line 395-402 (`--expand` mode) writes `subtasks: [list_of_subtask_numbers]` onto the parent when it transitions to `status: "expanded"`. This makes it cheap to add a genuinely low-risk guard, entirely within `commands/todo.md` / `skill-todo/SKILL.md`'s existing Stage 2 scan: before treating an `expanded` task as archivable, look up its `subtasks[]` entries in `active_projects`, and skip archiving that parent (leaving it as an active `[EXPANDED]` entry for one more `/todo` run) if any subtask is still present in `active_projects` with a non-terminal status. Once every subtask has itself gone terminal (or been archived), the parent is safe to archive under this narrower guard. This does not solve the general path-citation problem (see Finding 5), but it does specifically address the scenario the task description raises — a subtask actively being researched/planned/implemented while still needing to read its parent's original analysis — without requiring any new script or architecture change, and stays within file scope.

### External Resources

Not applicable — this is a closed-repository documentation/logic-consistency task with no external dependency.

### Recommendations

1. **`agent-system/extensions/core/commands/todo.md`**:
   - Line 27-28: add a third bullet "Tasks with status = `expanded`" to the documented scan.
   - Line 400: widen the jq filter to `select(.status == "completed" or .status == "abandoned" or .status == "expanded")`.
   - Line 392 / the "Move each task..." prose and the archive-array routing logic (wherever `completed_projects` vs `archived_projects` is chosen — this appears inline near line 392 and in the per-task loop that follows): route `expanded` tasks to `completed_projects` (same array as `completed`), not `archived_projects`.
   - Step 3.5 (ROADMAP.md matching, lines 134-260): `expanded` tasks should be excluded from ROADMAP.md item-completion matching the same way `meta` tasks already are (line 151, Step 3.5.1's meta/non-meta split) — an expanded task has no `completion_summary` of its own by construction (task.md's expand-mode jq at lines 395-403 never sets `completion_summary`), so summary-based/explicit-item matching would simply no-op for it; explicit exclusion is still worth stating for clarity and to avoid a future reader assuming expanded tasks need a completion_summary requirement they structurally cannot satisfy.
   - Recommended (in-scope, low-cost) addition to Stage 2/"Prepare Archive List": the subtasks-non-terminal defer guard described in Finding 6.

2. **`agent-system/extensions/core/skills/skill-todo/SKILL.md`**:
   - Stage "ScanTasks" (lines 78-87): add `expanded` scanning identical in spirit to `commands/todo.md`'s fix, tracking an `expanded_count` alongside `completed_count`/`abandoned_count`.
   - Wherever this file performs the actual `del()`/archive-array move (mirror of `todo.md` lines 392-401 — locate the corresponding stage further down in the file, likely under a stage named "Archive"/"UpdateState"), apply the same three-way filter and `completed_projects` routing as recommended above.
   - Same subtasks-non-terminal defer guard as Finding 6, applied at the equivalent scan stage.
   - No change needed to the existing `expanded`-aware exclusion at lines 94-97 (TopicRevision) — it is already correct and can serve as the in-file precedent/reference for the Stage 2 fix.

3. **`agent-system/extensions/core/merge-sources/claudemd.md`**, line 39:
   - Replace the single conflated bullet with two bullets that separate genuinely-terminal from exception/resumable states, e.g.:
     ```
     - `[ABANDONED]`, `[EXPANDED]` - Terminal states (no further transitions)
     - `[BLOCKED]`, `[PARTIAL]` - Exception states (any command can resume from these)
     ```
   - This is the only edit needed to correct the taxonomy at its documented source; do not touch any generated `.claude/CLAUDE.md` (per the SOURCE-STORE RULE) — the deployed copy will pick this up on next regeneration.

## Decisions

- **Widen the filter; do not leave `expanded` tasks permanently unarchivable.** The authoritative taxonomy (`status-markers.md`, and ~25 independent enforcement sites) is unanimous that `expanded` is terminal; the fix is to correct `/todo`'s two scan sites to match the taxonomy that already governs the rest of the system, not to change the taxonomy itself.
- **Do not add `PARTIAL`/`BLOCKED` to the archival filter.** They are correctly non-terminal everywhere except the one mis-worded `claudemd.md` line; archiving them would be a genuine new bug (silently hiding resumable work), and no evidence anywhere suggests they should ever be archivable while still `partial`/`blocked`.
- **Fix `claudemd.md` line 39 taxonomy wording**, since it is the demonstrable root cause of the ambiguity the task raises, even though it did not directly cause the `/todo` bug (the `/todo` filter was simply never updated when `expanded` was introduced as a status — `skill-todo/SKILL.md`'s own inconsistent internal state, correct in TopicRevision but wrong in ScanTasks, shows this was an incremental-maintenance gap rather than a taxonomy misunderstanding).
- **Route `expanded` archival into `completed_projects`**, not a new array, matching the existing binary convention and minimizing downstream branching changes.
- **Recommend, but scope as optional/lightweight, the subtasks-non-terminal defer guard** (Finding 6) as the correct-sized answer to the reachability question, rather than either (a) ignoring reachability entirely or (b) attempting a general symlink/pointer mechanism that the existing vault-renumbering feature would undermine anyway.

## Risks & Mitigations

- **Risk**: Widening the filter without the subtasks guard could archive a parent task whose subtask is still actively being implemented and still needs to re-read the parent's research/plan. **Mitigation**: implement the Finding 6 guard (cheap, in-scope, uses the existing `subtasks[]` field).
- **Risk**: General cross-task path citations (Finding 5) will continue to silently break on archival, for `expanded` exactly as they already do for `completed`/`abandoned` today. **Mitigation**: none in this task's scope; flag as a known, pre-existing, system-wide limitation. If the user wants it addressed, it should be a separate task scoped around `commands/todo.md`'s directory-move step plus `scripts/vault-operation.sh` (symlink-and-renumber interaction), not bundled into this taxonomy/filter fix.
- **Risk**: `scripts/archive-task.sh` is a dead/orphaned helper (grep confirms it is never invoked from `commands/todo.md`, `skills/skill-todo/SKILL.md`, or `commands/task.md`) that independently has the same `completed`-vs-`abandoned` binary split with no `expanded` awareness. It is out of this task's file scope (not listed in file_scope) and appears unused, so no action is proposed, but noting it here in case a future maintainer wires it up and reintroduces the same gap.
- **Risk**: Editing the generated `.claude/CLAUDE.md` directly instead of `merge-sources/claudemd.md` would violate the SOURCE-STORE RULE and be overwritten on next deploy. **Mitigation**: the fix target is confirmed to be `agent-system/extensions/core/merge-sources/claudemd.md` only.

## Context Extension Recommendations

- **Topic**: Archival reachability / cross-task artifact citation lifetime.
- **Gap**: No existing context file documents that `specs/{N}_{slug}/...` paths cited from other tasks' artifacts are not permanently stable (archival is a plain `mv`; vault operations additionally renumber). A future reader/agent citing another task's artifact path has no warning this reference has a bounded lifetime.
- **Recommendation**: A short note in `agent-system/extensions/core/context/patterns/` (or alongside `state-management.md`'s archival section) documenting this as an accepted, known limitation would help future agents avoid over-relying on cross-task path citations for anything that must remain valid long-term — out of scope to create here, but flagged per Stage 4.5 gap detection.

## Appendix

### Search queries / commands used

- `grep -rn "expanded\|EXPANDED" agent-system/extensions/core/ --include="*.md" --include="*.sh"` — surfaced ~25 enforcement sites agreeing on the terminal set.
- Manual read of `agent-system/extensions/core/context/standards/status-markers.md` in full (authoritative source).
- `grep -n "BLOCKED\|PARTIAL\|ABANDONED\|EXPANDED\|Terminal" agent-system/extensions/core/merge-sources/claudemd.md` — isolated the single defective line (39).
- Custom loop diffing each `specs/*/{description,reports/*,plans/*,summaries/*}.md` file's own task number against any `specs/{N}_.../...` paths embedded in its text, to find genuine cross-task citations (Finding 5 evidence: 885→874, 885→887, 897→891, 900→899, 903→873).
- `grep -rn "archive-task.sh" agent-system/extensions/core/` — confirmed `scripts/archive-task.sh` is defined but never invoked (dead code, out of scope note).

### Files examined

- `agent-system/extensions/core/commands/todo.md` (full)
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` (lines 1-510)
- `agent-system/extensions/core/merge-sources/claudemd.md` (Status Markers section + surrounding)
- `agent-system/extensions/core/context/standards/status-markers.md` (full)
- `agent-system/extensions/core/commands/task.md` (`--expand` mode, lines 340-411)
- `agent-system/extensions/core/scripts/archive-task.sh` (full)
- `agent-system/extensions/core/rules/state-management.md` (relevant excerpt)
