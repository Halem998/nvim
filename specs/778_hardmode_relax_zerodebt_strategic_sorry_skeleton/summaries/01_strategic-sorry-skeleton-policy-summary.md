# Implementation Summary: Task #778

**Completed**: 2026-07-03
**Duration**: ~1 hour

## Overview

Task 778 relaxes the hard-mode zero-debt / build-green completeness bar so that a documented,
tracked "strategic sorry" skeleton is an acceptable `--hard` dispatch outcome, while STANDARD
mode and the build-green (must-typecheck) invariant remain unchanged. All 5 plan phases
completed: the H2 anti-analysis contract now defines a domain-agnostic 5-condition
strategic-sorry acceptance test; the H9 wrap-up contract adds a `skeleton` boolean to the
handoff schema and extends `sorry_inventory` to the canonical 7-field shape; the hard
implementer skill parses and logs skeleton dispatches; the hard implementation agent has an
explicit "implemented (skeleton)" reporting path with a worked handoff example. This is the
foundational leg that tasks 772 (implementation) and 774 (planning) depend on.

## What Changed

- `.claude/context/contracts/anti-analysis.md` — retitled "Sub-Sorry Policy" (dropped the
  "(for formal verification domains)" qualifier), added a `--hard`-only note, and added a new
  "Strategic sorries (skeleton division points)" subsection with the five acceptance conditions
  (deliberate division boundary, tightly scoped, documented, tracked with non-null
  `follow_up_task`, build-green). The three original leaf-sorry bullets are preserved verbatim.
- `.claude/context/contracts/wrap-up.md` — added `"skeleton": false` to the handoff JSON schema
  example; documented the `skeleton` field semantics; extended `sorry_inventory` field semantics
  to the canonical `{file, line, statement, strategic, assumption, why_deferred,
  follow_up_task}` schema; added a status/skeleton interaction table; amended Build-Green
  Invariant bullet 3 with the `--hard`-only strategic-sorry exception (STANDARD mode stated as
  unchanged/absolute); added a `--hard`-only note; extended the lean4 Domain Specialization
  bullet. `status` still lists exactly `implemented | partial | blocked` — no 4th enum value.
- `.claude/skills/skill-implementer-hard/SKILL.md` (deployed) — Stage 6 now parses `skeleton`
  and `sorry_inventory` from `.return-meta.json` (defaulting to `false`/`[]`), emits a
  `[hard-mode] Skeleton dispatch: N strategic sorries -> follow-up tasks {...}` log line when
  `skeleton == true`, and Stage 7 carries a comment confirming skeleton dispatches flow through
  the existing `status == "implemented"` postflight gate unchanged.
- `.claude/extensions/core/skills/skill-implementer-hard/SKILL.md` (source) — identical Stage
  6/7 edit applied.
- `.claude/agents/general-implementation-hard-agent.md` (deployed) — added a "Strategic-Sorry
  Skeleton (Hard Mode)" subsection near the Anti-Analysis Contract section; added a third worked
  handoff example under Stage 5 Step 1 ("implemented with strategic sorries (skeleton)") with a
  populated canonical 7-field `sorry_inventory` entry; added a MUST-DO line requiring a non-null
  `follow_up_task` for every strategic sorry.
- `.claude/extensions/core/agents/general-implementation-hard-agent.md` (source) — identical
  edit applied; confirmed byte-identical to the deployed copy via `diff`.
- `specs/778_hardmode_relax_zerodebt_strategic_sorry_skeleton/plans/01_strategic-sorry-skeleton-policy.md`
  — all 5 phases marked `[COMPLETED]`, Testing & Validation checklist checked off, and a `NOTE:`
  block added to Phase 5 recording the two downstream items below.

## Decisions

- Kept `status ∈ {implemented, partial, blocked}` unchanged; added `skeleton` as a separate
  boolean field rather than a 4th status enum value, per the plan's explicit design decision
  (minimizes blast radius on `validate-handoff.sh` and every status-gated consumer).
- Policy (the five-condition test) lives in `anti-analysis.md`; schema/reporting mechanics
  (`skeleton`, extended `sorry_inventory`) live in `wrap-up.md`; the two files cross-reference
  rather than duplicate field definitions.
- Made the `--hard`-only gate explicit with a one-line note at the top of both contract files,
  converting the existing structural gate (these files are loaded only by hard-mode
  skills/agents) into a stated invariant.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (markdown/contract files only)
- Tests: N/A
- `grep -n "strategic"` in `anti-analysis.md`: 5-condition subsection present; original three
  leaf-sorry bullets unchanged — PASS
- `grep -n "skeleton"` in `wrap-up.md`: field present in schema example, field semantics, and
  interaction table; `sorry_inventory` semantics names all seven fields — PASS
- `status` in `wrap-up.md` still lists exactly `implemented | partial | blocked` — PASS (no 4th
  value introduced)
- Dual-copy diffs:
  - `.claude/agents/general-implementation-hard-agent.md` vs
    `.claude/extensions/core/agents/general-implementation-hard-agent.md`: **byte-identical**
  - `.claude/skills/skill-implementer-hard/SKILL.md` vs
    `.claude/extensions/core/skills/skill-implementer-hard/SKILL.md`: identical except a
    **pre-existing, task-778-unrelated** 3-line divergence in the Stage 4a literature-briefing
    script invocation (`literature-briefing-invoke.sh` deployed vs `literature-briefing.sh`
    source), present before this task started (confirmed via `git log` — the deployed copy was
    last touched by an unrelated orchestration commit `065df0890`, the source copy by
    `7f160b428`). Out of task-778 scope to fix; not touched.
- `bash .claude/scripts/validate-handoff.sh` on a sample skeleton handoff
  (`status: "implemented"`, `skeleton: true`, one populated `sorry_inventory` entry) — **PASSED
  WITH WARNINGS** (8 passed, 1 unrelated warning about optional `continuation_path` being
  `null`, 0 failed). Confirms the script needs no changes for this task (Non-Goal respected).
- `grep -rl "contracts/anti-analysis.md\|contracts/wrap-up.md" .claude`: only `-hard`/
  `orchestrate-hard` skills and agents plus the lean extension override matched — no
  standard-mode skill references either contract — PASS
- Files verified: Yes (all 6 target files present and non-empty, content confirmed via grep)

## Downstream Notes (out of scope for task 778 — surfaced for tasks 772/774)

1. **Lean/cslib override contradiction**: `.claude/extensions/lean/context/contracts/anti-analysis.md`,
   `.claude/extensions/lean/agents/lean-implementation-hard-agent.md`, and
   `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` currently forbid
   main-target sorries unconditionally. This now **contradicts** the relaxed core policy defined
   by task 778 for the exact Lean4 domain that motivated 772/774. These files were deliberately
   NOT edited here (explicit Non-Goal). **Recommendation**: a follow-up task, surfaced via task
   772, should reconcile the lean/cslib overrides with the new core strategic-sorry policy and
   rename the lean override's `next_dispatch` field to `follow_up_task` for schema consistency.
2. **`validate-handoff.sh` structural gap**: the script validates JSON structure and
   status/continuation consistency but does not yet fail when a `sorry_inventory` entry has
   `strategic: true` with a missing/null `follow_up_task`, `assumption`, or `why_deferred`. A
   sample skeleton handoff passed unmodified validation (see Verification above), confirming
   task 778's Non-Goal of not modifying this script is satisfied for now. **Recommendation**: a
   follow-up task should extend `validate-handoff.sh` with this structural check so the
   non-null `follow_up_task` requirement (anti-analysis.md condition 4) is enforced
   automatically rather than resting on self-attestation alone.

## Notes

During implementation, an external process (likely a concurrent parallel dispatch or repo sync
mechanism, per the multi-agent orchestration context) transiently reverted the four core-file
edits mid-task; this was detected via `<system-reminder>` file-change notices and confirmed via
`grep`/`git diff`. All edits were re-applied and finally re-verified stable via `grep -c` counts
and `diff` immediately before writing this summary — no data was lost, and the final on-disk
state matches the plan's Definition of Done in full.
