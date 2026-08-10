# Implementation Plan: Task #838

- **Task**: 838 - Fix planner clobbering researcher .return-meta.json (merge not overwrite)
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_planner-return-meta-clobber.md
- **Artifacts**: plans/01_planner-return-meta-fix.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`skill-planner/SKILL.md` (the non-`--hard` planner used by plain `/plan N`) is the sole core
lifecycle skill missing the two-part `memory_candidates` propagation pattern that
`skill-researcher`, `skill-researcher-hard`, `skill-implementer`, `skill-implementer-hard`, and
`skill-planner-hard` all already implement: a Stage 6 read of `.memory_candidates` and a Stage 7a
append into `state.json` before the unconditional Stage 10 `rm -f .return-meta.json` destroys the
scratch file. This plan applies a targeted field-extraction fix (copy the verbatim jq block from
`skill-researcher/SKILL.md:438-444`), corrects the now-valid dangling reference in
`skill-planner-hard/SKILL.md:475`, and tightens the `return-metadata-file.md` contract to document
the propagate-before-cleanup requirement. Definition of done: `/plan N` preserves any
`memory_candidates` present in `.return-meta.json` into `state.json` with append semantics, and the
contract explicitly mandates the read+append pattern for all lifecycle skills.

### Research Integration

The research report (`reports/01_planner-return-meta-clobber.md`) established the precise defect and
fix: `.return-meta.json` is *correctly* a per-phase scratch file (written fresh, read once, deleted)
— no cross-phase JSON-file merge is needed or desired. The "merge" belongs at the `state.json`
extraction step, field by field. `memory_candidates` is the one accumulate-type field
`skill-planner` currently ignores; `artifacts` (also accumulate-by-type) is already handled
correctly in `skill-planner` Stage 8 and must not be disturbed. `orchestrator-postflight.sh` is dead
code (zero call sites) and is out of scope. The three team-mode skills' missing propagation is a
distinct, broader gap not implicated in the #831 incident and is deferred as a follow-up.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (none provided in delegation context).

## Goals & Non-Goals

**Goals**:
- Add a `memory_candidates` read to `skill-planner/SKILL.md` Stage 6, mirroring
  `skill-researcher/SKILL.md:385`.
- Insert a new "Stage 7a: Propagate Memory Candidates" into `skill-planner/SKILL.md` between the
  existing Stage 7 and Stage 8, using the verbatim append-semantics jq block from
  `skill-researcher/SKILL.md:438-444`.
- Make `skill-planner-hard/SKILL.md:475` ("Same as `skill-planner` Stage 7a pattern") a valid
  reference (it becomes accurate once the base skill has Stage 7a) or self-contained.
- Document the propagate-before-cleanup requirement and the accumulate-vs-phase-owned field
  distinction in `.claude/context/formats/return-metadata-file.md`.

**Non-Goals**:
- Changing `.return-meta.json` into a cross-phase-merged document (the scratch-file design is sound;
  the bug is a missing read, not wrong overwrite semantics).
- Modifying or wiring in `.claude/scripts/orchestrator-postflight.sh` (dead code, out of scope).
- Adding `memory_candidates` propagation to `skill-team-{research,plan,implement}` (deferred as a
  separate follow-up task to keep this diff matched to the confirmed defect).
- Disturbing the existing, correct `artifacts` accumulate-by-type logic in `skill-planner` Stage 8.
- Renumbering any existing stage (the fix uses a letter-suffixed "Stage 7a" exactly as
  `skill-researcher` does, so no downstream stage numbers shift).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Re-typing the jq append block reintroduces a jq Issue #1132 escaping bug | H | M | Copy verbatim from `skill-researcher/SKILL.md:438-444` (uses `--argjson` and `// []`); do not hand-retype |
| Stage renumbering breaks references (e.g. the skill-planner-hard reference, test fixtures) | M | L | Insert as letter-suffixed "Stage 7a"; no existing stage numbers shift |
| Fix accidentally alters the working `artifacts` accumulate-by-type block in Stage 8 | M | L | Insert Stage 7a strictly before Stage 8; leave Stage 8 untouched; verify with diff |
| Fixing only base skill leaves team-mode gap for a future `--team` incident | L | M | Documented as explicit follow-up in Non-Goals; contract update flags the required pattern for all skills |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Add memory_candidates read + Stage 7a propagate to skill-planner [COMPLETED]

**Goal**: Bring `skill-planner/SKILL.md` postflight in line with its five sibling skills so
`memory_candidates` present in `.return-meta.json` are appended to `state.json` before cleanup.

**Tasks**:
- [x] In Stage 6 (`skill-planner/SKILL.md`, the `if [ -f "$metadata_file" ] ...` block), add
      `memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")` after the
      `artifact_summary=...` line, mirroring `skill-researcher/SKILL.md:385`. *(completed)*
- [x] Insert a new `### Stage 7a: Propagate Memory Candidates` section immediately after Stage 7
      (Update Task Status) and before Stage 8 (Link Artifacts). *(completed)*
- [x] Populate Stage 7a with the verbatim append-semantics jq block from
      `skill-researcher/SKILL.md:438-444` (guard `[ "$memory_candidates" != "[]" ] && [ -n ... ]`,
      then `--argjson new_candidates` append with `// []` fallback), plus the accompanying note.
      *(completed)*
- [x] Confirm Stage 8 (artifacts accumulate-by-type) and Stage 10 (cleanup) remain unchanged.
      *(completed: only insertion between Stage 7 and Stage 8, no other lines touched)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-planner/SKILL.md` - add Stage 6 read line (~after line 408) and new Stage 7a
  section (~between lines 445 and 448).

**Verification**:
- `grep -n "memory_candidates" .claude/skills/skill-planner/SKILL.md` shows both the Stage 6 read
  and the Stage 7a append block.
- The Stage 7a jq block is byte-identical (modulo surrounding prose) to
  `skill-researcher/SKILL.md:438-444`.
- No existing stage heading numbers changed (Stage 8, 8a, 9, 10, 11 intact).

---

### Phase 2: Correct the dangling reference in skill-planner-hard [COMPLETED]

**Goal**: Ensure `skill-planner-hard/SKILL.md:475` ("Same as `skill-planner` Stage 7a pattern")
resolves to a real stage now that the base skill has Stage 7a.

**Tasks**:
- [x] Verify the reference at `skill-planner-hard/SKILL.md:475` now points to the real Stage 7a
      added in Phase 1. *(completed: confirmed valid — Stage 6 already reads `memory_candidates`
      at line 303, and the base skill's Stage 7a now exists)*
- [x] If a cross-skill "Same as ..." pointer is judged too fragile, replace it with the explicit
      guarded `--argjson` append block (matching `skill-planner-hard`'s own inline style) so the
      hard skill is self-contained; otherwise leave the now-valid reference in place. *(completed:
      left in place — identical terse "Same as X Stage 7a" convention is used by
      `skill-implementer-hard` and `skill-researcher-hard` for their own Stage 7a/Stage 8
      sections, so this is the established house style, not fragility)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-planner-hard/SKILL.md` - line ~473-475 (Stage 7a reference).

**Verification**:
- The reference is either valid (Phase 1 created the target) or replaced with an inline block.
- `grep -n "memory_candidates\|Stage 7a" .claude/skills/skill-planner-hard/SKILL.md` confirms the
  stage still reads and appends candidates.

---

### Phase 3: Document propagate-before-cleanup in return-metadata-file.md [COMPLETED]

**Goal**: Tighten the contract so `memory_candidates` propagation is a stated, enumerable
requirement for every lifecycle skill, closing the loophole that let `skill-planner` diverge.

**Tasks**:
- [x] Under the `memory_candidates` section (or as a short new "Merge Semantics" subsection near
      the Cleanup section), state explicitly that `.return-meta.json` is a single-phase scratch file
      that MUST be fully read and its accumulate-type fields extracted into `state.json` by every
      lifecycle skill's postflight BEFORE the file is deleted. *(completed: new "Merge Semantics:
      Propagate Before Cleanup" subsection added directly after the `memory_candidates` Notes)*
- [x] Enumerate accumulate-type fields (currently: `memory_candidates`; note `artifacts` accumulates
      by type) versus phase-owned fields (`status`, `next_steps`, `partial_progress`, `metadata`,
      etc.) so future skills/extensions do not repeat the omission. *(completed)*
- [x] Cross-reference the Cleanup section so the ordering (propagate, then `rm -f`) is unambiguous.
      *(completed: "Ordering requirement" note added to the Cleanup section)*

**Timing**: 25 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/formats/return-metadata-file.md` - `memory_candidates` section (~lines 159-192)
  and/or the Cleanup section (~lines 251-257).

**Verification**:
- The contract text names the propagate-before-cleanup ordering and lists accumulate-vs-phase-owned
  fields.
- No schema field removed or renamed; change is additive documentation only.

---

### Phase 4: Verification and follow-up note [COMPLETED]

**Goal**: Confirm the fix is internally consistent across all three edited files and record the
deferred team-mode scope as a follow-up recommendation.

**Tasks**:
- [x] Run `jq -n` / shell syntax sanity on the inserted Stage 7a jq block (e.g. paste into a scratch
      file and confirm `jq` parses the filter) to catch escaping regressions. *(completed: verified
      against a sample state.json fixture -- append semantics confirmed, no jq errors)*
- [x] Diff-review that `skill-planner` Stage 8 artifacts logic and Stage 10 cleanup are byte-identical
      to before the change. *(completed: `git diff --stat` shows 19 insertions, 0 deletions;
      Stage 8/Stage 10 content confirmed unchanged by direct read)*
- [x] Confirm the six lifecycle skills now uniformly implement the read+append pattern via
      `grep -n "memory_candidates" .claude/skills/skill-{researcher,researcher-hard,planner,planner-hard,implementer,implementer-hard}/SKILL.md`.
      *(completed: all six show a Stage 6 read; the three `-hard` skills use the established
      "Same as `skill-{base}` Stage 7a" terse-reference convention rather than inline duplication)*
- [x] Record in the implementation summary that `skill-team-{research,plan,implement}` still lack
      `memory_candidates` propagation and recommend a follow-up task (do not fix here). *(completed
      -- see summary)*

**Timing**: 20 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- None (verification only; findings captured in the implementation summary).

**Verification**:
- All six lifecycle skills show a `memory_candidates` read and append.
- The inserted jq block parses without error.
- Follow-up note for team-mode gap is present in the summary.

---

## Testing & Validation

- [x] `grep -n "memory_candidates" .claude/skills/skill-planner/SKILL.md` returns both a Stage 6
      read and a Stage 7a append block.
- [x] The Stage 7a jq block matches `skill-researcher/SKILL.md:438-444` semantics (guard, `--argjson
      new_candidates`, `// []` fallback, append).
- [x] No stage heading numbers in `skill-planner/SKILL.md` were renumbered (Stage 8/8a/9/10/11 intact).
- [x] `skill-planner-hard/SKILL.md:475` reference resolves or is replaced with an inline block.
- [x] `return-metadata-file.md` documents propagate-before-cleanup and the accumulate-vs-phase-owned
      field split.
- [x] `skill-planner` Stage 8 (`artifacts`) and Stage 10 (cleanup) are unchanged.

## Artifacts & Outputs

- plans/01_planner-return-meta-fix.md (this plan)
- Edited `.claude/skills/skill-planner/SKILL.md`
- Edited `.claude/skills/skill-planner-hard/SKILL.md`
- Edited `.claude/context/formats/return-metadata-file.md`
- summaries/01_planner-return-meta-fix-summary.md (produced at /implement)

## Rollback/Contingency

All changes are confined to three documentation/skill Markdown files and are purely additive (one
read line, one new stage section, one reference correction, one contract clarification). If the fix
misbehaves, `git checkout -- .claude/skills/skill-planner/SKILL.md
.claude/skills/skill-planner-hard/SKILL.md .claude/context/formats/return-metadata-file.md` reverts
to the prior state with no data-migration concerns, since no runtime state or `state.json` schema is
altered by the edits themselves.
