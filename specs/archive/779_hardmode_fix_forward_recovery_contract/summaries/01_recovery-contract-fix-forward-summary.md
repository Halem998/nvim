# Implementation Summary: Task #779

**Completed**: 2026-07-03
**Duration**: ~1 hour

## Overview

Created the canonical fix-forward recovery contract (`.claude/context/contracts/recovery.md`)
that permanently disambiguates "reach green" / "restore green" as FIX FORWARD ONLY — never a
revert/reset/checkout to a prior commit — and defines the 3-rung Recovery Ladder (fix forward,
documented strategic-sorry skeleton, snapshot-then-smallest-scope-rollback). Wired this contract
into all four hard-mode consumer files across both deployed and core copies, and reworded
error-handling.md's ambiguous "Keep source unchanged" line.

## What Changed

- `.claude/context/contracts/recovery.md` — New single-copy contract: fix-forward disambiguation
  statement, 3-rung Recovery Ladder citing real task-778 (`anti-analysis.md` five-condition test,
  `wrap-up.md` `sorry_inventory` schema) and task-780 (`git-snapshot.sh`,
  `guard-destructive-git.sh`, git-workflow.md "No Destructive Git" rule) mechanisms verbatim by
  path, plus a Domain Specialization section.
- `.claude/context/index.json` — Added `contracts/recovery.md` entry (subdomain `contracts`,
  domain `core`, `load_when.agents: ["general-implementation-hard-agent"]`) directly after the
  `wrap-up.md` entry.
- `.claude/skills/skill-orchestrate-hard/SKILL.md` + `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  — Added a 5th "Recovery Discipline" slot to the CONTRACT SLOTS block inside
  `build_hard_mode_prompt_context()`.
- `.claude/skills/skill-implementer-hard/SKILL.md` + `.claude/extensions/core/skills/skill-implementer-hard/SKILL.md`
  — Added recovery.md to the Context References list and mentioned it in the Stage 4 dispatch-prompt
  text.
- `.claude/agents/general-implementation-hard-agent.md` + `.claude/extensions/core/agents/general-implementation-hard-agent.md`
  — Added recovery.md to MANDATORY Context References; added a new "Recovery Ladder (Hard Mode)"
  section (distinct from and adjacent to the existing "Strategic-Sorry Skeleton (Hard Mode)"
  section, before the pre-existing Checkpoint Sub-Section further down).
- `.claude/rules/error-handling.md` + `.claude/extensions/core/rules/error-handling.md` —
  Reworded "Build Error Recovery" step 3 from "Keep source unchanged" to explicit fix-forward +
  no-discard language cross-referencing recovery.md and git-workflow.md.

## Decisions

- Scoped the `--hard`-only disclaimer in recovery.md to rungs (b)/(c) only; the rung (a)
  fix-forward statement is explicitly marked safe to quote in standard-mode contexts too.
- Left the skill-implementer-hard deployed/core pre-existing drift (literature-briefing.sh vs
  literature-briefing-invoke.sh script name, 3 locations) untouched — mirrored, not "fixed", per
  the plan's explicit Risk guidance.

## Plan Deviations

- **Task 2** (Phase 2, slot placement): The plan referenced a parallel-wave dispatch call site at
  "line 339" consuming `build_hard_mode_prompt_context()`. Task 772 had already disabled Parallel
  Wave Dispatch entirely before this task ran, so slot 5 now only appears at the single
  remaining Per-Phase Dispatch call site. Plan intent ("every dispatch emits the phrasing") is
  still fully satisfied since there is only one dispatch path.
- **Task 3** (Phase 3, pre-existing drift): Confirmed and mirrored (did not reconcile) the
  skill-implementer-hard deployed/core drift, as the plan's Risk section explicitly instructed.

## Verification

- Build: N/A (documentation/prompt-only changes, no runtime code paths)
- Tests: N/A
- Files verified: Yes — `diff -q` clean for skill-orchestrate-hard, general-implementation-hard-agent,
  and error-handling.md dual pairs; skill-implementer-hard shows only the pre-existing
  literature-briefing drift; `grep -rn "contracts/recovery.md" .claude/` shows references from all
  four consumer files (both copies each) plus the index.json entry; index.json parses cleanly
  with `python3 -c "import json; json.load(...)"`.

## Notes

Task 773 is expected to edit skill-orchestrate-hard's burnout-breaker loop-top region next; that
region does not yet exist in the file (grep for "burnout" returned no hits), confirming this
task's CONTRACT SLOTS edit did not collide with or preempt it.
