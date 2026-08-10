# Implementation Summary: Task #838

**Completed**: 2026-07-12
**Duration**: ~30 minutes

## Overview

Fixed `skill-planner/SKILL.md` — the sole core lifecycle skill missing the two-part
`memory_candidates` propagation pattern — by adding a Stage 6 read and a new Stage 7a
"Propagate Memory Candidates" section (copied verbatim from `skill-researcher/SKILL.md:438-444`)
before the unconditional Stage 10 cleanup deletes `.return-meta.json`. Also verified the
now-valid `skill-planner-hard/SKILL.md:475` reference and tightened
`.claude/context/formats/return-metadata-file.md` to explicitly document the
propagate-before-cleanup requirement and the accumulate-vs-phase-owned field distinction.

## What Changed

- `.claude/skills/skill-planner/SKILL.md` — Added `memory_candidates=$(jq -c '.memory_candidates
  // []' "$metadata_file")` to Stage 6 (line 409), and inserted a new
  `### Stage 7a: Propagate Memory Candidates` section (lines 449-464) between Stage 7 (Update
  Task Status) and Stage 8 (Link Artifacts), using the verbatim guarded `--argjson`
  append-semantics jq block from `skill-researcher/SKILL.md`. No existing stage was renumbered;
  Stage 8/8a/9/10/11 headings and content are byte-identical to before (`git diff --stat`: 19
  insertions, 0 deletions).
- `.claude/skills/skill-planner-hard/SKILL.md` — No edit required. Verified that Stage 6 (line
  303) already reads `memory_candidates`, and the Stage 7a reference at line 475 ("Same as
  `skill-planner` Stage 7a pattern") now resolves to a real section created in Phase 1. Left the
  terse cross-reference in place rather than inlining a duplicate block, since this is the
  established house style also used by `skill-researcher-hard` (Stage 7a/Stage 8) and
  `skill-implementer-hard` (Stage 7a) for their own base-skill references — not a fragility
  issue unique to this file.
- `.claude/context/formats/return-metadata-file.md` — Added a new "Merge Semantics: Propagate
  Before Cleanup" subsection directly after the `memory_candidates` field's Notes, stating that
  `.return-meta.json` is a single-phase scratch file (no cross-phase JSON merge is needed or
  desired) and enumerating accumulate-type fields (`memory_candidates`, `artifacts`) versus
  phase-owned fields (`status`, `next_steps`, `partial_progress`, `metadata`, `completion_data`,
  `errors`). Added a cross-referencing "Ordering requirement" note to the Cleanup section making
  the propagate-then-`rm -f` ordering explicit. Purely additive documentation; no schema field
  removed or renamed.

## Decisions

- Left `skill-planner-hard/SKILL.md:475`'s "Same as ..." pointer in place rather than inlining an
  explicit block, since the identical terse-reference convention is already used by the other two
  hard-mode skills for their own Stage 7a/Stage 8 sections — inlining would have made
  `skill-planner-hard` inconsistent with its siblings rather than more self-contained.
- Verified the Stage 7a jq append block against a sample `state.json` fixture (not just visual
  comparison) to confirm both syntactic validity and append-semantics correctness (existing
  `memory_candidates` entries are preserved and new ones appended, not overwritten).

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (documentation/skill Markdown files only)
- Tests: N/A
- `jq` syntax/semantics check on the inserted Stage 7a filter against a fixture `state.json`:
  Passed (append semantics confirmed)
- `git diff --stat .claude/skills/skill-planner/SKILL.md`: 19 insertions, 0 deletions (Stage 8
  and Stage 10 untouched)
- Stage heading grep on `skill-planner/SKILL.md`: Stage 1 through Stage 11 all intact, with new
  Stage 7a inserted between Stage 7 and Stage 8
- `grep -n "memory_candidates"` across all six core lifecycle skills
  (`skill-researcher`, `skill-researcher-hard`, `skill-planner`, `skill-planner-hard`,
  `skill-implementer`, `skill-implementer-hard`): all six now show a Stage 6 read; the three
  `-hard` skills use the "Same as `skill-{base}`" terse-reference convention for the append step
  rather than inline duplication
- Files verified: Yes

## Notes

**Deferred follow-up (explicit non-goal of this task)**: `skill-team-research`,
`skill-team-plan`, and `skill-team-implement` still lack `memory_candidates` propagation
entirely — they have no Stage 6 read and no Stage 7a append step. This is a distinct, broader
gap (affecting three additional skills, not just the one incident-implicated skill) and was
explicitly out of scope per the plan's Non-Goals. Recommend a follow-up task to audit and fix
`memory_candidates` propagation across the three team-mode skills, since a `--team` run
currently discards any memory candidates its synthesis or teammate agents emit.

`.claude/scripts/orchestrator-postflight.sh` remains dead code (zero call sites) and was
correctly left untouched per the plan's Non-Goals.
