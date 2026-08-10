# Research Report: Task #914

**Task**: 914 - converge_todo_roadmap_annotation_with_script
**Started**: 2026-07-27
**Completed**: 2026-07-27
**Effort**: Medium (investigation-heavy; the fix itself is bounded but touches two documents)
**Dependencies**: None (builds on the prior `roadmap-integration.sh` fix, already merged)
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` (the shared script, already fixed)
- `agent-system/extensions/core/commands/todo.md` (full-detail `/todo` command spec)
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` (prose `/todo` skill spec)
- `agent-system/extensions/core/commands/review.md` (the script's only current consumer)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md, no-task-references-in-deliverables.md

## Executive Summary

- Confirmed: `/todo` has **two** independently-maintained full specifications —
  `commands/todo.md` (1132 lines, real bash/grep matching logic) and `skill-todo/SKILL.md`
  (996 lines, pure prose with no matching algorithm at all) — and **neither** calls
  `roadmap-integration.sh`. Both are structurally consistent with each other in *intent*
  (both exclude meta/expanded tasks from roadmap matching, both handle an "abandoned" annotation
  branch the script does not have), but both independently reimplement matching and both can
  silently report a clean archival pass while annotating zero roadmap items.
- The requirements genuinely differ from `/review`'s in two load-bearing ways, not just
  "different scan scope": (1) `/todo` annotates **abandoned** tasks (checkbox stays unchecked,
  `*(Task N abandoned: reason)*` suffix) — a capability `roadmap-integration.sh` has **zero**
  code for; (2) `/todo` deliberately **excludes meta and expanded tasks** from roadmap matching
  — `roadmap-integration.sh` has no `task_type` filter at all and would happily match a meta
  task if its title/summary fuzzy-matched a roadmap item.
- **Decision: Option (b)** — keep the two annotation paths distinct (their scopes are legitimately
  different) but port the script's already-built signal machinery
  (`roadmap_structure`/`parseable`/`warnings`/`silent_noop`) into `/todo`, and additionally reuse
  the script itself, in **parse-only mode**, as `/todo`'s parser so it stops missing every
  table-row roadmap entirely. Full rationale and a concrete design in Recommendations.
- The binding acceptance criterion (a roadmap that parses to zero phases and zero checkboxes must
  never be reportable as a successful annotation pass) is satisfied by wiring the parse-only call's
  `roadmap_structure.parseable` flag into both `/todo` specs' dry-run and final-output sections,
  replacing the current silent "if no matches were found, omit the section" behavior.

## Context & Scope

A prior task fixed `roadmap-integration.sh` so it can locate and safely rewrite a matched
**table row** in place (not just checkbox lines), and made it always emit a
`roadmap_structure`/`warnings`/`silent_noop` signal so a caller can never mistake "found nothing"
for "nothing to do." `/review` was updated to consume that signal. `/todo` was not touched and
does not call the script at all — its own Stage 5/Stage 11 (skill) and Step 3.5/Step 5.5 (command)
sections reimplement roadmap matching independently, in two different levels of detail, in two
different files.

This report characterizes exactly what those two `/todo` specs do, determines whether their
requirements are actually the same as `/review`'s (they are not, in two specific ways), and
recommends one of the three options the task poses, with a concrete design.

## Findings

### 1. What `/todo`'s two specs actually do

**`commands/todo.md`** (`Step 3.5` "Scan Roadmap for Task References (Structured Matching)",
lines 204-334; `Step 5.5` "Update Roadmap for Archived Tasks", lines 627-703; matching notes,
lines 1043-1104):

- Matching is **grep-based over checkbox lines only**. Two match types:
  - `explicit`: `grep -n "^\s*- \[ \].*${escaped_item}"` against a task's `roadmap_items[]` text.
  - `exact`: `grep -n "(Task ${project_num})"` for a literal `(Task N)` reference.
  - A third type, `summary` (fuzzy match from `completion_summary`), is explicitly a no-op
    placeholder: `# Implementation note: Summary-based matching is optional enhancement ... :`
    (line ~318, the bare `:` is bash's null command).
- **Zero table-row support.** `roadmap-integration.sh`'s own comments (script lines 463-468) note
  that the live `ROADMAP.md` format is now table-based with **zero checkboxes** — meaning this
  matcher's `annotations_made` is structurally guaranteed to be 0 against the actual roadmap file,
  every single run.
- **No unparseable/no-op detection at all.** Step 4 (Dry Run Output) and the final Output section
  literally say: *"If no roadmap matches were found ... omit the 'Roadmap updates' section"*
  (line 396, mirrored at line 968). Omitting the section is indistinguishable from "nothing needed
  updating" — this is precisely the silent-success bug the task's acceptance criterion targets.
- **Does exclude meta and expanded tasks from matching**, by design (`roadmap_excluded_tasks[]`
  vs. `roadmap_eligible_tasks[]` partition, Step 3.5.1, lines 226-241): *"Meta tasks ... are
  excluded from ROADMAP.md matching since they modify system infrastructure rather than project
  deliverables. Expanded tasks are excluded ... since they have no `completion_summary` of their
  own by construction."*
- **Does handle abandoned-task annotation** (Step 5.5 step 4, lines 668-674): checkbox line stays
  `- [ ]`, gets `*(Task {N} abandoned: {short_reason})*` appended. This is a real, documented
  requirement with no equivalent anywhere in `roadmap-integration.sh`.

**`skill-todo/SKILL.md`** (`Stage 5` "ScanRoadmap", lines 257-282; `Stage 11` "UpdateRoadmap",
lines 842-852):

- Even thinner than `commands/todo.md`: no matching algorithm at all is specified — "3. Match
  against ROADMAP.md items / 4. Track roadmap_matches array with confidence levels" is the entire
  spec. Whatever an executing agent does here is unconstrained; there is nothing to converge with
  the script because there is no committed algorithm to converge.
- Same *intent* as `commands/todo.md` on scope: excludes meta and expanded tasks (line 273, same
  wording), and documents the same abandoned-task annotation format (Stage 11, lines 847-850:
  `- [ ] item *(Task {N} abandoned: reason)*`).
- Same silent-omission failure mode: Stage 11 has no unparseable/no-op signal of any kind.

**Architecture note (adjacent, not in scope to fix here)**: `commands/todo.md` and
`skill-todo/SKILL.md` are not "command delegates to skill" — `commands/todo.md`'s
`allowed-tools` frontmatter has no `Skill` tool at all (unlike `research.md`/`plan.md`/
`implement.md`/`meta.md`, which are thin `Skill`-only dispatchers). `commands/todo.md` is a
fully self-contained legacy command; nothing in the source tree invokes `skill-todo` via the
`Skill` tool (verified: no hit for `Skill(skill-todo)`/`skill-todo` as an invocation target
anywhere outside `skill-todo/SKILL.md` itself and doc cross-references). Both are treated as
live, authoritative specs by this task's framing, so both need the same fix, but this dual-spec
situation is itself a latent drift risk worth a separate future task.

### 2. Does `/todo` genuinely need something different from `/review`?

Yes, in two specific, load-bearing ways — not merely "different batch of tasks to scan":

1. **Abandoned-task annotation.** `roadmap-integration.sh`'s `COMPLETED_TASKS`/`ARCHIVED_TASKS`
   jq queries both hard-filter to `select(.status == "completed")` (script lines 315-324 and
   330-340), and its only annotation-suffix construction is
   `ANNOTATION_SUFFIX="*(Completed: Task $TASK_NUM ...)*"` (script line 559/561) — there is no
   branch anywhere in the script for an abandoned-task suffix, and no code path that would ever
   look at a `status == "abandoned"` task in the first place. Confirmed by grep: the string
   `abandoned` does not appear anywhere in `roadmap-integration.sh`. `/review` itself has no
   abandoned-task concept either — it is a whole-repo code/doc review sweep, not an archival
   step, so this was never a gap in `/review`'s own requirements.
2. **Meta/expanded exclusion.** Confirmed by grep: the string `task_type` does not appear
   anywhere in `roadmap-integration.sh`. Its `COMPLETED_TASKS` query pulls `title`/
   `completion_summary`/`roadmap_items` from *every* `status == "completed"` task regardless of
   `task_type`, and its keyword/title/`(Task N)` matcher (`find_match`, script lines 388-432)
   would happily match a meta task if its title or summary fuzzy-overlapped a roadmap item's text.
   `/todo`'s own design principle is explicit and deliberate: meta tasks modify system
   infrastructure, not project deliverables, and must never pollute `ROADMAP.md`. Expanded tasks
   are excluded because they carry no `completion_summary` of their own by construction. Note:
   expanded tasks already can't leak into the script's matches today by accident, because
   `completed_projects` entries for expanded tasks keep `status: "expanded"` (Stage 10 of
   `skill-todo/SKILL.md`, "Include all task fields"), which the script's `select(.status ==
   "completed")` filter already excludes — so only the **meta-task** gap is a live risk if the
   script were called unmodified against the full task population.

Given this, collapsing straight to "make `/todo` call `roadmap-integration.sh`" (option a) would
either (i) silently drop the abandoned-task annotation feature and the meta-exclusion guarantee,
or (ii) require extending the shared script with two new branches (`abandoned` status handling
with a non-destructive-to-checkbox-state annotation path, plus a `task_type` filter) that `/review`
will never use — increasing the blast radius and regression risk on a call site that was just
fixed and verified, for zero benefit to that call site.

### 3. Extracting a fully shared matcher (option c) is more than the acceptance criterion needs

A "shared matching library both consume" refactor is architecturally clean but is a heavier lift
than the actual defect calls for: the acceptance criterion is specifically about the
*unparseable-roadmap / silent-no-op* signal, not about unifying the matching algorithm itself.
`roadmap-integration.sh` already computes exactly that signal correctly (`roadmap_structure`,
`warnings`, `annotation_summary.silent_noop`) for the completed-task/table-row/checkbox path. The
missing piece for `/todo` is *exposure of that signal*, not a from-scratch reimplementation of the
matcher in prose a third time.

## Decisions

**Decision: Option (b)**, refined with one concrete mechanism — reuse the script in **parse-only
mode** as `/todo`'s parser (eliminating `/todo`'s own duplicate, checkbox-only, table-blind
grep matcher) while keeping `/todo`'s annotation-application logic separate for the two things it
does that `roadmap-integration.sh` structurally cannot: abandoned-task annotation, and meta/
expanded exclusion.

Concrete shape for `/plan` to work from:

1. **Call `roadmap-integration.sh --roadmap specs/ROADMAP.md --state specs/state.json`
   (no `--annotate`) from both `/todo` specs**, in the same place `commands/todo.md`'s Step 3.5
   and `skill-todo/SKILL.md`'s Stage 5 run today. This replaces the checkbox-only
   grep matcher entirely — `/todo` gets full table-row-aware parsing, `roadmap_state`,
   `roadmap_matches[]` (with `confidence`, `match_type`, and for table rows `line_index`/
   `raw_line`/`status_index`), and the always-on `roadmap_structure`/`parseable`/`warnings`
   diagnostics, for free, with zero duplicate parsing code.
2. **Filter `roadmap_matches[]` to `roadmap_eligible_tasks[]`** (the existing
   meta/expanded-exclusion partition both specs already compute) by cross-referencing
   `matched_task` against that set, *before* treating anything as a candidate for annotation.
   This preserves the meta-exclusion guarantee without touching the shared script.
3. **For the completed-task subset of the filtered matches**, apply the annotation using the
   *same* line-targeted rewrite the script already implements safely (stale-line guard via
   `line_index`/`raw_line`, checkbox vs. table-row branch). The lowest-risk way to do this without
   a third hand-written rewrite implementation: build a temporary, filtered copy of
   `state.json` with meta/expanded entries removed (a `jq` one-liner), then invoke
   `roadmap-integration.sh --annotate` a second time against that filtered snapshot. This means
   `/todo` never re-implements the table-row/checkbox write logic at all — it only ever
   constructs an input, never a parser or a writer.
4. **Keep `/todo`'s own abandoned-task annotation step as-is**, since the script has no equivalent
   and extending it would be out of proportion to this fix — but gate it on the same
   `roadmap_structure.parseable` flag from step 1's parse-only call, so an abandoned annotation
   attempt against an unparseable roadmap also surfaces the warning rather than silently
   no-op'ing.
5. **Wire the acceptance criterion directly**: replace both specs' "if no roadmap matches were
   found, omit the section" line (`commands/todo.md` line 396 and its Output-section mirror at
   line 968-969; `skill-todo/SKILL.md` Stage 8/16's roadmap-count lines) with a
   branch on `roadmap_structure.parseable`:
   - `parseable == true` and zero matches: omit the section as today (legitimately nothing to do).
   - `parseable == false` (phases == 0 AND checkboxes == 0 AND table_rows == 0 — the exact
     `unparseable_roadmap` condition the script already computes at script lines 291-304):
     **always** print a visible warning line (mirroring `/review`'s wording at
     `review.md` line 135: *"Warning: roadmap structure unrecognized (0 phases, 0 checkboxes, 0
     table rows) -- see roadmap_structure in the payload"*), both in `--dry-run` output and in the
     final Output section, so this case can never be indistinguishable from "0 items needed
     updating." This is the literal binding acceptance criterion, satisfied without depending on
     whether any high-confidence match existed at all.
   - Additionally surface `annotation_noop` (script's `silent_noop` field) the same way `/review`
     does (`review.md` lines 137-139), for the case where matches existed but nothing got applied.

This design converges the *parsing and signal* half of the duplication completely (one parser,
one source of truth for "did this roadmap actually have any structure"), while leaving the two
specs' *annotation-scope* logic (abandoned handling, meta/expanded exclusion) as legitimately
separate, matching the genuine difference in requirements found above.

## Risks & Mitigations

- **Risk**: Calling `roadmap-integration.sh` twice (parse-only, then `--annotate` against a
  filtered temp state file) doubles the script's runtime cost for `/todo`.
  **Mitigation**: The script's own work (parsing + jq queries) is small relative to `/todo`'s
  other archival work (directory moves, memory harvest, vault checks); this is not a meaningful
  cost in practice, and it is strictly cheaper than maintaining a third bespoke parser.
- **Risk**: A filtered temp `state.json` snapshot passed to the second `--annotate` call must
  never itself be written back over the real `specs/state.json` — it is a `--state` argument
  pointing at a scratch file, never the live file being read elsewhere by `/todo`'s other stages.
  **Mitigation**: Use `mktemp`, per the same pattern `roadmap-integration.sh` itself already uses
  internally for its own oversized-argv workaround (script lines 348-352), and delete via `trap`.
- **Risk**: The two `/todo` specs (`commands/todo.md`, `skill-todo/SKILL.md`) must receive the
  *same* fix in parallel prose, at their differing levels of detail, or the divergence this task
  exists to close simply reappears one level down (script vs. `commands/todo.md` fixed,
  `skill-todo/SKILL.md` left stale). Both files are explicitly in scope per the task description
  and must be edited together.
- **Observation, not in scope**: `skill-todo/SKILL.md` does not appear to be invoked by anything
  (`commands/todo.md` is the actual self-contained executor and has no `Skill` tool access). This
  dual-spec situation is a standing drift risk independent of the roadmap-annotation defect;
  worth a follow-up task to determine whether `skill-todo/SKILL.md` is dead code, but is out of
  scope to resolve here since the task frames both files as things to converge, not to prune.

## Context Extension Recommendations

- **Topic**: `/todo`'s roadmap-matching relationship to `roadmap-integration.sh`.
  **Gap**: `context/patterns/roadmap-update.md` (referenced by both `/todo` specs, e.g.
  `commands/todo.md` line 629) documents matching strategy in prose but does not mention
  `roadmap-integration.sh` at all, and predates the table-row/structure-signal fix.
  **Recommendation**: Once the plan/implementation phase lands the design above, update
  `roadmap-update.md` to describe the parse-only + filtered-annotate call pattern as the
  canonical `/todo` matching strategy, so future readers of that pattern file are not pointed at
  the now-obsolete checkbox-only description.

## Appendix

### Key line references

- `agent-system/extensions/core/scripts/roadmap-integration.sh`:
  - Lines 24-29, 291-304: always-on `roadmap-structure` marker + unparseable banner.
  - Lines 315-324, 330-340: `COMPLETED_TASKS`/`ARCHIVED_TASKS` — both filtered to
    `status == "completed"` only, no `task_type` filter.
  - Lines 386, 469-508: `STATUS_ALLOWLIST_RE` and the table-row matcher (additive to the
    checkbox matcher).
  - Lines 717-728, 753-761: `silent_noop`/`annotation_noop` warning construction.
  - Confirmed via `grep`: no occurrence of `task_type` or `abandoned` anywhere in the file.
- `agent-system/extensions/core/commands/todo.md`:
  - Lines 204-334 (Step 3.5, matching), 396 (silent omission), 627-703 (Step 5.5, annotation),
    668-674 (abandoned branch), 968-969 (Output section silent omission),
    1043-1104 (Notes: matching strategy + annotation formats).
- `agent-system/extensions/core/skills/skill-todo/SKILL.md`:
  - Lines 257-282 (Stage 5 ScanRoadmap), 842-852 (Stage 11 UpdateRoadmap).
- `agent-system/extensions/core/commands/review.md`:
  - Lines 69-95 (script invocation with `--annotate`), 97-146 (error handling + warning
    surfacing) — the reference pattern this design's step 5 mirrors.

### Search queries / commands used

- `find`/`grep` to locate `roadmap-integration.sh`, `skill-todo`, and `commands/todo.md` across
  `agent-system/extensions/core/`, `.claude/`, and `.opencode/` deploy trees, confirming
  identical source-to-deploy copies (no drift between source and either deploy target for these
  specific files).
- `grep -n "task_type\|abandoned" roadmap-integration.sh` — zero hits, confirming both gaps.
- `diff` between `commands/todo.md`/`skill-todo/SKILL.md` `allowed-tools` frontmatter and thin
  `Skill`-only commands (`meta.md`, `orchestrate.md`, `research.md`) to establish that `/todo` is
  self-contained rather than skill-delegating.
