# Research Report: Task #5

**Task**: 5 - roadmap_items is never derived by any implement path, so /todo's ROADMAP sync is dead in practice
**Started**: 2026-08-10T00:00:00Z
**Completed**: 2026-08-10T00:00:00Z
**Effort**: Medium (2-3 files, one behavioral contract change, no new machinery)
**Dependencies**: 1004 (now vaulted as completed -- "Fix /todo repository-metrics sync"; unrelated to roadmap_items, satisfied)
**Sources/Inputs**: Codebase (agent-system/extensions/core/{commands,scripts,skills,agents,context}), git log, specs/state.json, specs/vault/01-vault/state.json
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The task description is significantly stale. Since it was written, tasks 910/911/914/969/985/21
  (visible in `git log`) rewrote `roadmap-integration.sh` and `todo.md`'s Roadmap Updates section.
  Two of the five described gaps (Priority 3 matcher, Priority 2 vs. the no-task-references rule)
  are **already resolved**, and a third (silent-0 visibility) is **partially** resolved by a
  different, narrower signal than the one the task needs.
- The one gap that is genuinely still live and matches the measured symptom (24 tasks, 0
  roadmap annotations): **the implementation agents are never given ROADMAP.md to read**, so
  `general-implementation-agent.md`'s existing "optionally generate `roadmap_items`" instruction
  (Stage 6a, line 547) has nothing to check candidate matches against and is trivially skipped
  every time. The fix is additive to an already-correct call chain, not new machinery.
- Recommended fix: mirror the `roadmap_path` pattern already used by `planner-agent.md` (Stage
  2.5, read-only) and `general-research-agent.md` (Stage 1.5) -- thread `roadmap_path` through
  `skill-implementer`/`skill-implementer-hard`'s delegation context, add a "Load Roadmap Context"
  read step to `general-implementation-agent.md`/`general-implementation-hard-agent.md` before
  Stage 6a, and tighten the Stage 6a instruction from "optionally... only include if the task
  clearly maps" to a directive check against the loaded roadmap text. No new matcher, no new
  write path -- `skill_propagate_completion_summary` and `roadmap-integration.sh`'s Priority-1
  (`explicit_roadmap_item`) tier already do the rest correctly once `roadmap_items` is non-empty.
- A second, still-real gap independent of the above: `/todo`'s "three-way branch" for the
  Roadmap section (todo.md lines 402-414, 970-988) treats "`roadmap_eligible_matches[]` is
  empty and roadmap parses fine" as **always** "legitimately nothing to do" and omits the section
  entirely -- even when there were eligible completed tasks and open roadmap checkboxes, and the
  reason for zero matches is that no task ever populated `roadmap_items`. This is exactly the
  silent-0 failure mode the task describes, and it is not the same condition as
  `roadmap_silent_noop` (which only fires when a *high-confidence* match existed but 0 were
  applied). This needs a distinct signal.

## Context & Scope

Researched: the full `/implement` -> `state.json` -> `/todo` -> `roadmap-integration.sh` chain,
`planner-agent.md`'s separate opt-in `--roadmap` mechanism, the no-task-references rule's
applicability to `specs/ROADMAP.md`, and the current content/state of `specs/ROADMAP.md` and
`specs/state.json` to confirm the mechanism is dead in the live repo (not just in theory).

## Findings

### What already exists and works correctly (do not rebuild -- confirmed by reading, not by trusting the task description)

1. **The write path is correct and already wired**, exactly as the task description says:
   `skill_propagate_completion_summary` (`scripts/skill-base.sh:526-551`) is called from all four
   producer call sites (`skill-implementer/SKILL.md:480`, `skill-implementer-hard/SKILL.md:423`,
   `skill-orchestrate/SKILL.md:1014,2254`, `skill-orchestrate-hard/SKILL.md:802`,
   `orchestrator-postflight.sh:368`), reading `roadmap_items` from
   `.completion_data.roadmap_items // []` in the agent's own `.return-meta.json`. It guards
   `task_type != "meta"` and non-empty/non-`"[]"` correctly.

2. **The matcher (`roadmap-integration.sh`) is fully implemented, not a placeholder.**
   `find_match()` (lines 407-451) has four tiers, not the "three-priority, with an unimplemented
   third" shape the task describes:
   - `explicit_task_ref` (high): `(Task N)` / `(task N)` regex in the roadmap item text
   - `explicit_roadmap_item` (high): exact/substring match of a completed task's
     `roadmap_items[]` entries against the item text
   - `exact_title_match` (high) / `title_match` (medium): task title vs. item text
   - `keyword_match` (low): 60%+ keyword overlap

   Only `high`-confidence matches auto-annotate (`todo.md` line 379-380 and the annotation logic);
   medium/low surface as report-only. This is a deliberate, already-documented design, not a
   missing "Priority 3" -- the task's claim of an "explicit unimplemented placeholder ('not
   currently implemented')" does not match current `todo.md` text (grepped for that string,
   found no match; the actual text is "Title match, keyword match (medium/low confidence,
   report-only)").

3. **Priority 2 does not conflict with the no-task-references-in-deliverables rule.**
   `.claude/rules/no-task-references-in-deliverables.md`'s own scope line: "Applies to: the
   entire repository EXCEPT `specs/**/*`". `ROADMAP.md` lives at `specs/ROADMAP.md`, which is
   Category 1 of that rule's own exemption taxonomy ("`specs/**` artifacts: Path-level exemption,
   no marker, unchanged"). The current live `specs/ROADMAP.md` already contains informal
   task-number prose ("Task 396 fixed...", "per task 821's...", "task 710") with no rule
   violation. The task's premise that Priority 2 is "structurally unreliable" because of this
   rule is incorrect and should not be carried into a plan -- no reconciliation work (item 5) is
   needed. (`(Task N)` markers ARE permitted in ROADMAP.md; they are simply rare in practice
   because nothing currently writes them outside the annotation suffix itself.)

4. **`general-implementation-agent.md` already has half of a derivation instruction.** Stage 6a
   (line 536-564) already reads: "For NON-META tasks: 2. Optionally generate `roadmap_items`:
   Array of explicit ROADMAP.md item texts this task addresses -- Only include if the task
   clearly maps to specific roadmap items." `general-implementation-hard-agent.md` (line 451-452)
   has the equivalent one-line pointer into the same shared format doc. So "nothing anywhere
   derives the value" (the task's framing) is too strong: an instruction exists, wired into the
   correct output field, read by the correct call sites.

### The actual remaining gap (confirmed root cause of "24 tasks, 0 roadmap annotations")

5. **Neither implementation agent is ever given ROADMAP.md's content.** Grepped
   `general-implementation-agent.md`, `general-implementation-hard-agent.md`,
   `skill-implementer/SKILL.md`, `skill-implementer-hard/SKILL.md` for `roadmap_path`/`ROADMAP` --
   found only the one Stage 6a instruction line above. No stage ever does `Read specs/ROADMAP.md`.
   Contrast with `planner-agent.md`, which already has a working pattern for this: Stage 2.5
   ("Load Roadmap Context") reads `roadmap_path` from the delegation context (set unconditionally
   by `skill-planner/SKILL.md:207`, `"roadmap_path": "specs/ROADMAP.md"`) and
   `general-research-agent.md` has an equivalent Stage 1.5. The implementer contracts have no
   analogous stage, so "only include if the task clearly maps to specific roadmap items" is asking
   an agent to judge a match against a document it has never seen. That is why the instruction is
   uniformly skipped in practice -- not because it's phrased as "optionally," but because there is
   nothing to check against.

   **This is the actual, still-needed producer fix**, and it is small: thread `roadmap_path`
   through the implementer delegation contexts the same way the planner already does, add a
   read-only "Load Roadmap Context" stage before Stage 6a in both implementation agents, and
   change Stage 6a's language from "optionally... only include if" to a directive: "check the
   loaded roadmap text for open (`- [ ]`) items this task's work closes; if one clearly matches,
   copy its item text verbatim into `roadmap_items`; if none matches, omit the field (not `[]` --
   both are treated identically by the guard, but omission is clearer intent)."

### A second, independent gap: silent-0 visibility is not actually fixed for this scenario

6. `todo.md`'s "three-way branch" (lines 402-414 for dry-run, 970-988 for the final summary)
   treats `roadmap_structure.parseable == true && roadmap_eligible_matches[] empty` as always
   "legitimately nothing to do" and omits the Roadmap section entirely. `roadmap_silent_noop`
   (the one loud warning that does exist) only fires when `high_confidence_matches > 0 &&
   annotations_made == 0` -- i.e. matches were found but skipped (already-annotated, stale
   line_index, etc.), not when zero matches were found at *any* confidence tier despite eligible
   completed tasks and open roadmap checkboxes existing. That second condition is exactly the
   24-task measured scenario, and it is currently indistinguishable from "there was truly nothing
   to compare" in `/todo`'s output. Fixing item 5 above (populating `roadmap_items`) will reduce
   how often this triggers, but does not make the reporting honest for tasks whose completion
   summary genuinely didn't match anything -- which the task's own verification bar requires
   ("A task whose work matches no roadmap item produces an explicit 'no match' report").

   Minimal fix: compute (at Step 3.5, where `roadmap_eligible_tasks[]` and
   `roadmap_eligible_matches[]` are both already in scope) a new boolean, e.g. `roadmap_no_match`
   = `roadmap_eligible_tasks[] non-empty AND roadmap_eligible_matches[] empty AND
   roadmap_structure.checkboxes-not-yet-checked > 0`, and add a fourth branch alongside the
   existing three that prints something like: `No roadmap items matched this run's {N} eligible
   completed task(s) -- see roadmap_items in each task's completion_data`. This reuses data
   `/todo` already computes; it does not require a new script call or new matcher tier.

### Adjacent mechanism found, not in scope but relevant context for the planner

7. `planner-agent.md` Stage 2.6 / `commands/plan.md:459` already implements an **alternate,
   opt-in, direct-write** path: `/plan N --roadmap` injects "Review and Snapshot ROADMAP.md" and
   "Update ROADMAP.md" phases into the plan itself, which the implementer then executes as
   ordinary plan phases -- editing `ROADMAP.md` directly, not through `/todo`. This flag is not
   listed in the top-level CLAUDE.md `/plan` usage line and defaults to `false`
   (`roadmap_flag = false` unless `--roadmap` is passed), so it does not run in the default flow
   the task is fixing, and it is compatible with the `/todo` path by construction:
   `roadmap-integration.sh` already skips items containing `*(Completed:`, so a `--roadmap`-phase
   annotation cannot be double-annotated by a later `/todo` run. This is worth naming in the plan
   only so the planner does not mistake it for "a second write path added by this task" -- it
   already exists, is orthogonal, and should be left alone.

## Decisions

- **Derivation belongs in the implementation agent's own judgment (task's Candidate A), not a
  postflight fuzzy matcher (Candidate B)** -- confirming the task's own stated preference. This
  requires no new matching machinery: `roadmap-integration.sh`'s Priority-1 tier already consumes
  exactly this shape of data correctly.
- **No new write path** is needed; `skill_propagate_completion_summary` is the sole writer to
  keep.
- **Priority 3 (title/keyword match) and Priority 2 (`(Task N)` ref) both stay** -- they are
  correctly implemented and correctly scoped as report-only below `high` confidence. No deletion
  work (task work item 4) is warranted; that item in the task description is based on a stale
  read of `todo.md`.
- **Priority 2 vs. no-task-references**: no reconciliation edit needed (task work item 5 is moot)
  -- `specs/ROADMAP.md` is already rule-exempt.

## Risks & Mitigations

- **Risk**: instructing agents to always check ROADMAP.md adds a Read call to every non-meta
  implementation run, including tasks with no plausible roadmap connection. Mitigate by keeping
  the check cheap (one `Read` of a ~40-line file, per the current `specs/ROADMAP.md`) and by
  keeping `roadmap_items` population conditional/omittable, not mandatory.
- **Risk**: an agent could over-eagerly claim a roadmap match not intended by the task. Mitigate
  by requiring the copied text be a verbatim substring/match of an actual open (`- [ ]`) item
  (this is also what `explicit_roadmap_item` matching requires to fire at `high` confidence, so
  sloppy paraphrase will silently fail to match rather than mis-annotating).
- **Risk touching item 6**: adding a fourth "no match" branch could itself become noisy if fired
  on every run with zero roadmap-related work. The proposed gate
  (`roadmap_eligible_tasks[] non-empty AND roadmap_eligible_matches[] empty AND` at least one
  open checkbox remains) scopes it to the genuinely-informative case.

## Context Extension Recommendations

- None required for this task type (meta). The relevant context already lives in
  `context/patterns/roadmap-update.md` and `context/formats/roadmap-format.md`; no new context
  file is warranted -- this is a behavioral-contract fix in existing agent/skill files.

## Appendix

- Confirmed via `git log --oneline` that `roadmap-integration.sh`/`todo.md` were substantially
  rewritten by tasks 910, 911, 914, 969, 985, and 21 (all newer than task 5's creation).
- Confirmed task 5's stated dependency (1004) is satisfied: vaulted as task 1004 "Fix /todo
  repository-metrics sync" in `specs/vault/01-vault/state.json`, status `completed`, unrelated in
  substance to roadmap_items.
- Confirmed `specs/state.json` currently has zero tasks (active or archived) carrying a non-empty
  `roadmap_items` field, and `specs/ROADMAP.md` has zero items annotated via the
  `*(Completed: Task {N}, {DATE})*` suffix -- both consistent with the task's "0 roadmap items
  updated across 24 tasks" measurement still holding today.
- Grep commands used: `grep -rn "skill_propagate_completion_summary"`,
  `grep -n "roadmap_items\|completion_data" agents/*.md`, `grep -n "roadmap_path\|ROADMAP"` across
  `skill-implementer*/SKILL.md` and both implementation agent files, `grep -n "explicit_task_ref\|priority"
  roadmap-integration.sh`.
