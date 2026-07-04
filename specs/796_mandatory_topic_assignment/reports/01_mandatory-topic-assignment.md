# Research Report: Task #796

**Task**: 796 - mandatory_topic_assignment
**Started**: 2026-07-04
**Completed**: 2026-07-04
**Effort**: Medium (single coherent .claude/ system-doc + 7 caller edits, no new components)
**Dependencies**: None (787 is COMPLETE; no line/section conflicts found — see Compatibility with Task 787 below)
**Sources/Inputs**: Codebase read of pattern doc, meta-builder-agent.md, commands/task.md, commands/review.md, skill-fix-it/SKILL.md, skill-spawn/SKILL.md, skill-project-overview/SKILL.md, spawn-agent.md, generate-task-order.sh, manage-topics.sh, errors.md, task 787's summary
**Artifacts**: This report; orchestrator handoff at `specs/796_mandatory_topic_assignment/.orchestrator-handoff.json`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The canonical doc (`topic-assignment-pattern.md`) and the actual implementations have
  **diverged**: the doc says Mode B has "no fallback picker" (line 113), but `/task --expand`
  and `/spawn` **already implement** a full Mode A-style fallback picker (with a "Skip (no
  topic)" option) when the parent has no topic. The doc needs to catch up to the
  implementation's intent, then both need Skip removed.
- Three distinct kinds of "topicless task" escape hatches exist today, matching the task's
  root-problem framing exactly:
  1. **Mode A pickers** (`/task` create step 4.5, `meta-builder-agent.md` Stage 4.5 delegates to
     the pattern doc, `skill-project-overview` Step 5.2.5) all present a literal
     `"Skip (no topic)"` option per the pattern doc's Step 1/Step 2 template — one click and the
     task is topicless.
  2. **Mode B "Inherit"**: `/task --expand` (task.md:329-347) and `/spawn`
     (skill-spawn/SKILL.md:61-83) both implement fallback pickers with Skip — contradicting the
     doc. **`/task --recover` has zero topic handling of any kind** (task.md:248-306): a
     recovered task keeps whatever `topic` field it had before archiving (jq copies `$task`
     verbatim), so a task that was topicless when archived stays topicless with no
     prompt/backfill on recovery.
  3. **Mode C "Suggest"**: `/review` (review.md:519-553) and `/fix-it`
     (skill-fix-it/SKILL.md:469-503) both auto-infer a topic from file path, then show a
     confirm-wrap picker (Accept / Override / **Skip**) — Skip escape hatch #1 again, PLUS a
     silent no-op when `inferred_topic` is empty (the path heuristic's "other" branch): "If
     `inferred_topic` is empty, skip confirm entirely and set `topic=""`" — this is the silent
     no-op described in the task's problem (3), matching the pattern doc's own line 134
     `other -> (no topic assigned)`.
- `generate-task-order.sh` already has a benign "Uncategorized" fallback section (lines
  490-515) for topicless tasks in TODO.md rendering — no warning/validation exists today. This
  is the natural anchor point for the optional defense-in-depth gate (decision (b)).
- All 8 files in scope (except `topic-assignment-pattern.md`, which has no `extensions/core/`
  mirror) are dual-copy files, currently byte-identical between the project copy and
  `extensions/core/`. Task 787 touched several of the same files (`meta-builder-agent.md`,
  `spawn-agent.md`, `skill-fix-it/SKILL.md`, `skill-spawn/SKILL.md`) but in **non-overlapping
  sections** (Stage 3 file-scope/dependency logic, not topic assignment) — confirmed no
  line-range collision with 796's target sections.

## Context & Scope

Task 796 makes topic assignment mandatory everywhere a task can be created, closing three
escape hatches: the Mode A Skip option, the Mode B silent no-op (doc) vs. actual Skip-picker
(impl) divergence, and the Mode C silent no-op on heuristic miss. Recovery mode (`--recover`)
has no topic handling at all and needs some. A defense-in-depth gate is optional and left as an
explicit decision for planning. Backfilling *existing* topicless tasks is out of scope (handled
by `/task --sync`, which already exists at task.md:379-435 with its own Mode A backfill loop —
this is unaffected by 796's changes, since --sync's own picker already forces the user to
choose per outstanding task; whether that picker's own Skip option should also be removed is a
question for planning, since --sync's job is explicitly to fix existing gaps, but leaving `Skip`
there would let a user re-introduce the exact gap /sync is meant to close).

## Findings

### Codebase Patterns — Canonical Pattern Doc

`.claude/context/patterns/topic-assignment-pattern.md` (183 lines, no `extensions/core/`
mirror — registered in `.claude/context/index.json` only) defines three modes:

| Mode | Doc-stated picker | Doc-stated fallback | Callers per doc |
|------|-------------------|---------------------|------------------|
| A: Interactive | Full AskUserQuestion picker: existing topics + "New topic..." + **"Skip (no topic)"** | N/A (is itself the picker) | `/task` create, `/task --sync` backfill, `/meta` interview Stage 4.5 |
| B: Inherit | None (parent topic silently propagated) | **"If parent has no topic, no topic is assigned (no fallback picker in current implementation)"** (line 113) | `/task --expand`, `/task --recover`, `/spawn` |
| C: Suggest | None (heuristic-only; doc shows no confirm step at all) | Path-prefix heuristic; `other -> (no topic assigned)` (line 134, silent) | `/review`, `/fix-it` |

Key structural elements worth preserving in the rewrite:
- `manage-topics.sh` subcommands (`list`, `add`, `set`, `validate`) are the sole state-mutation
  path — any fix must continue routing through these, never inline jq.
- The three-mode table (lines 17-24) is the organizing structure most callers `@`-reference by
  section name ("Mode A: Interactive", "Mode B: Inherit batch variant", etc.) — renaming modes
  would require updating every caller's cross-reference, so the rewrite should keep mode names
  A/B/C stable and change only their *content* (drop Skip, make Mode A the universal fallback).

### Codebase Patterns — Per-Caller Current State

**1. `/task` create (Mode A)** — `commands/task.md:189-197`. Delegates entirely to the pattern
doc ("Follow @.claude/context/patterns/topic-assignment-pattern.md (Mode A: Interactive)").
Since the doc's Mode A picker includes Skip, this is escape hatch (1) verbatim. Fixing the doc
fixes this caller with no separate edit needed beyond the `@`-reference still resolving to the
same section name.

**2. `/task --expand` (Mode B, line 322-359)** — Reads `parent_topic` from state.json
(task.md:322-327); **if empty, shows a full inline Mode A-style picker WITH Skip**
(task.md:329-347), inline-duplicated rather than delegating to the pattern doc's Mode A
section. This is the doc/impl divergence: the doc says no fallback exists; the code has one.
Fix: replace the inline duplicate with an explicit reference to the (rewritten) Mode A
universal-fallback section, and remove its Skip option.

**3. `/task --recover` (Mode B, no topic handling, lines 248-306)** — Archive lookup
(`.completed_projects[]`) copies the full `$task_data` object verbatim into `active_projects`
(task.md:281-282: `.active_projects = [$task | .status = "not_started" | ...] + .active_projects`).
No topic read, no fallback, no Mode A picker call at all. A task archived without a topic comes
back without one, silently. This needs the same Mode A universal-fallback treatment as
`--expand`'s empty-parent-topic case — recover mode should check `.topic == null or == ""` on
the recovered `$task_data` and, if so, invoke the same fallback picker used by `--expand`/`--recover`.

**4. `/task --sync` topic backfill (Mode A variant, lines 413-433)** — Already loops over
`missing_topics` and shows a Mode A per-task picker. This is the one caller whose *purpose* is
fixing existing gaps, so whether its own picker keeps a Skip option is a planning decision (see
Decisions below) — removing Skip here would make `--sync` fully close every existing gap over
time, but could get a user stuck re-running `--sync` against an old backlog they don't want to
categorize yet.

**5. `meta-builder-agent.md` Stage 4.5 (Mode A batch variant, lines 577-585)** — Thin
delegation: "Follow @.claude/context/patterns/topic-assignment-pattern.md (Mode A: Interactive,
batch variant). Note: question wording is plural." No inline Skip text to remove here — fixed
by the pattern-doc rewrite, same as `/task` create. Stage 6's `4b. Update active_topics`
(lines 1345-1360) and the state.json write in Stage 6 (line 734: "Include `topic` field only if
inferred or assigned; omit if null/skipped") reference `batch_topic` as nullable — once Skip is
gone, `batch_topic` becomes non-null by construction and this comment/guard can be simplified
(though leaving the defensive `if null then del` is harmless).

**6. `commands/review.md` Mode C (lines 505-580)** — Infers topic from path
(agent-system/neovim/nix-config/other), THEN shows a **confirm-wrap** picker (not a pure
Suggest — it already asks the user): Accept / Override / **Skip (no topic)**
(review.md:538-545). When `inferred_topic` is empty (the "other" branch), it "skip[s] confirm
entirely and set[s] `topic=""`" (review.md:553) — this is the silent no-op for problem (3). Fix
needs two parts: (a) drop the Skip option from the confirm-wrap picker itself (still allow
Override to type any topic), (b) when `inferred_topic` is empty, invoke the Mode A universal
fallback picker instead of silently setting `topic=""`.

**7. `skill-fix-it/SKILL.md` Mode C (lines 469-536)** — Structurally identical to review.md's
Mode C: infer -> confirm-wrap (Accept/Override/Skip) -> if `inferred_topic` empty, "skip
confirm entirely and set `topic=""`" (line 503). Same two-part fix as review.md. Note: this
runs per `topic_groups[]` entry (Step 7.5 grouping happens earlier, at line ~200-240), so the
Mode A fallback here should use the same "batch variant" plural wording meta-builder-agent uses
when a group's inferred topic is empty.

**8. `skill-spawn/SKILL.md` Mode B (lines 55-83)** — Reads `parent_topic` from the blocked
task's `.topic` field (line 58); **if empty, shows a full Mode A-style picker WITH Skip**
(lines 61-83) — same doc/impl divergence as `/task --expand`. Fix: same as `/task --expand`
(reference universal Mode A fallback, remove Skip).

**9. `skill-project-overview/SKILL.md` Step 5.2.5 (Mode A, lines 360-387)** — Inline picker
(existing topics + "New topic..." + "Skip (no topic)"), not delegated to the pattern doc by
reference (doesn't say "Follow @...topic-assignment-pattern.md", just duplicates the picker
inline). Needs its Skip option removed directly since it doesn't `@`-reference the doc.

**10. `.claude/commands/errors.md` (line 131)** — Confirmed **no separate topic handling
needed**: "Tasks are created via the `/task` command, which handles topic detection... Step 4.5
of Create Mode. No separate `active_topics` update is needed here." Fixing `/task` create's
Mode A (item 1 above) automatically closes this path too — no direct edit to errors.md required
by this task. The task description's phrase "skill-project-overview (errors.md inherits via
/task)" appears to be a minor mis-grouping in the task text — errors.md inherits via `/task`,
independent of skill-project-overview; both should be confirmed clean but only
skill-project-overview needs its own edit.

### Defense-in-Depth Options (`generate-task-order.sh`)

`generate-task-order.sh` (927 lines) already has a benign, silent "Uncategorized" fallback
(lines 490-515) used purely for TODO.md rendering grouping — it does not warn or block. Two
candidate anchor points for an optional gate, to present to planning:
- **Generation-time warning**: in the "Uncategorized fallback" block (line 490), if
  `${#uncategorized_tasks[@]} -gt 0`, emit a `stderr` warning (non-blocking, matching the
  codebase's existing "Warning: ... (non-fatal)" convention used throughout task.md/skill-fix-it)
  listing the topicless task numbers, so any bypass surfaces loudly on every `/todo`,
  `/task --sync`, or any command that calls `generate-todo.sh`.
- **Validation check script**: a small new script/subcommand (e.g.
  `manage-topics.sh validate-all` or a `check-topics.sh`) that scans `active_projects` for
  missing `topic` fields and exits non-zero — could be wired into `/todo` or a CI-style
  check-extension-docs.sh-like validator. Heavier than the warning option but gives a hard
  signal rather than a log line.

Both are compatible with keeping `manage-topics.sh`'s existing `validate` subcommand
(topic-string validity, not task-coverage) unchanged — a coverage check would be a new
subcommand or script, not a repurposing of the existing one.

## Decisions

(To be made explicit by /plan, per the task's stated research/plan decision points — findings
here characterize the trade-offs, not the final choice.)

- **(a) Remove Skip entirely vs. keep a hard-to-reach explicit skip**: Findings show 3 distinct
  Skip sites (Mode A picker in pattern doc + 3 direct callers; Mode B fallback pickers in
  `--expand`/`--recover`-to-be/`--spawn`; Mode C confirm-wraps in review.md/skill-fix-it) plus
  `--sync`'s backfill picker (which has a legitimate reason to possibly retain Skip, see item 4
  above). A clean design: remove Skip from the *canonical* Mode A picker template and from Mode
  B/C, but leave `--sync`'s backfill loop's own Skip semantics as a planning call — since
  `--sync` is the designated remediation path for pre-existing gaps, an explicit "leave for
  later" affordance there is arguably not a bypass of *this* task's guarantee (which is about
  *new* task creation), whereas Skip anywhere else is exactly the bypass in scope.
- **(b) Defense-in-depth gate**: two candidate anchors identified above (stderr warning in
  `generate-task-order.sh`'s existing Uncategorized block vs. a new validation
  script/subcommand). The warning option is lower-effort and consistent with existing
  "non-fatal" logging conventions; the validation-script option is more visible/enforceable but
  is new surface area. Given task 796's own framing ("bypasses surface loudly"), the warning
  option alone may satisfy the requirement without new script surface, but planning should weigh
  whether a hard validation check (invoked from `/todo` or `/task --sync`) is warranted given
  that the meta-builder Component-4a-style "never silent" precedent (see 787) favors visible
  loud signals over purely passive stderr lines.

## Risks & Mitigations

- **Doc rewrite breaks caller `@`-references**: Multiple callers reference the pattern doc by
  mode name ("Mode A: Interactive", "Mode A: Interactive, batch variant", "Mode B: Inherit").
  Mitigation: keep mode letter/name headings stable; only change picker content and the
  Mode B "no fallback" line into a "call Mode A as universal fallback" instruction.
- **Dual-copy drift**: All 8 caller files (all but the pattern doc itself) have
  byte-identical `extensions/core/` mirrors today. Any edit must be mirrored to both copies (as
  787 did via `cp` + `diff -q` verification) or the mirrors will silently diverge.
- **`--sync` special case overlooked**: If planning blanket-removes Skip everywhere without
  considering `--sync`'s backfill-loop purpose, existing topicless-task remediation could become
  either redundant-safe (fine) or awkward (if a legitimately-uncategorized existing task can no
  longer be deferred). Flagged explicitly above as decision (a)'s carve-out.
- **`--recover`'s missing check is easy to under-scope**: Since `--recover` currently has *zero*
  topic-related code (not even a fallback stub), it's easy for an implementer to assume "no
  change needed here" — the report explicitly calls out that a `.topic == null or ""` check must
  be *added*, not fixed.

## Context Extension Recommendations

- **Topic**: doc/impl divergence detection. **Gap**: nothing today cross-checks that
  `topic-assignment-pattern.md`'s stated behavior matches the actual caller implementations —
  this task discovered the Mode B divergence purely through manual reading. **Recommendation**:
  consider (as a distinct, out-of-scope-for-796 follow-up) a lightweight doc-lint check
  (extending `check-extension-docs.sh`'s existing pattern) that greps caller files for
  "Skip (no topic)" and cross-references the pattern doc's stated Skip policy, so future drift
  is caught automatically rather than by a dedicated /meta task.

## Appendix

**Search queries / commands used**:
- `grep -n -i "topic\|Skip"` over task.md, review.md, skill-fix-it/SKILL.md,
  skill-spawn/SKILL.md, skill-project-overview/SKILL.md, spawn-agent.md
- `grep -n -i "uncategorized\|topic" generate-task-order.sh`
- `diff -q` between project and `extensions/core/` copies of all 8 in-scope caller files, to
  confirm dual-copy status and byte-identity as of task start
- Read of `specs/787_file_footprint_aware_dependencies/summaries/01_*.md` to confirm 787's
  edits (Stage 3 `file_scope`/Component 4a additions) do not overlap 796's target sections
  (Stage 4.5 topic assignment, Mode B/C picker code) in any of the 4 files both tasks touch
  (`meta-builder-agent.md`, `spawn-agent.md`, `skill-fix-it/SKILL.md`, `skill-spawn/SKILL.md`)

**References**:
- `.claude/context/patterns/topic-assignment-pattern.md` (lines 17-24 mode table, 27-86 Mode A,
  89-114 Mode B, 118-158 Mode C)
- `.claude/agents/meta-builder-agent.md` (Stage 4.5, lines 577-585; Stage 6 topic write, lines
  715, 734, 1345-1360)
- `.claude/commands/task.md` (create step 4.5: 189-225; --recover: 248-306; --expand Mode B:
  322-359; --sync backfill: 413-433)
- `.claude/commands/review.md` (Mode C: 505-580)
- `.claude/skills/skill-fix-it/SKILL.md` (Mode C: 469-536)
- `.claude/skills/skill-spawn/SKILL.md` (Mode B: 55-83)
- `.claude/skills/skill-project-overview/SKILL.md` (Mode A: 355-420)
- `.claude/commands/errors.md` (line 131, confirmed no direct edit needed)
- `.claude/scripts/generate-task-order.sh` (Uncategorized fallback: 490-515)
- `.claude/scripts/manage-topics.sh` (full file — `list`/`add`/`set`/`validate` subcommands)
