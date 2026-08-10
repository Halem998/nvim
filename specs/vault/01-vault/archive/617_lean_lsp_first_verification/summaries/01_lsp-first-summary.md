# Implementation Summary: Task #617

**Completed**: 2026-05-25
**Duration**: ~30 minutes

## Overview

Updated three lean extension files to implement an LSP-first verification policy. The main change introduces a three-tier verification cadence: per-step uses `lean_goal` + `lean_verify`, phase-end uses scoped `lake build Module.Name`, and final verification uses full `lake build`. Additionally, `lean_verify` (previously undocumented) was added to all tool tables, and `lean_multi_attempt` was explicitly positioned as a pre-edit trial step.

## What Changed

- `.claude/extensions/lean/rules/lean4.md` - Added `lean_verify` and `lean_multi_attempt` rows to Essential MCP Tools table; rewrote Workflow Pattern to 5-step cadence; rewrote Build Commands with when-to-use guidance
- `.claude/extensions/lean/agents/lean-implementation-agent.md` - Added `lean_verify` to Core Tools list; updated `lean_multi_attempt` description; expanded MUST DO items 5-9 to encode three-tier cadence; renumbered subsequent items to 10-15; narrowed MUST NOT item 3 to "final lake build"
- `.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` - Updated Stage 4B inner loop (step b: "WITHOUT editing (pre-edit trial)", new step d: post-edit lean_goal + lean_verify); updated Stage 4B step 5 to lean_goal + lean_verify with "do NOT run lake build per-step"; updated Stage 4C to use scoped build with fallback; added clarifying note to Stage 5

## Decisions

- Positioned `lean_verify` as the per-step axiom/sorry check tool, replacing the antipattern of running `lake build` after every tactic
- The "do NOT run lake build per-step" language in Stage 4B step 5 is explicit, making the antipattern clearly named and prohibited
- MUST NOT item 3 narrowed to "final lake build" to allow scoped builds without triggering the "skip verification" prohibition

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (meta task, no code files modified)
- Tests: N/A
- Files verified: Yes - all three target files confirmed modified with correct content

## Notes

All changes are purely documentation edits to .claude/ infrastructure markdown files. No Lean source files were touched. The three-tier cadence is now consistently described across all three extension files.
