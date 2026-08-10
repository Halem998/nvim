# Implementation Summary: Task #782

**Completed**: 2026-07-03
**Duration**: ~1 hour

## Overview

Authored a new standalone context-hygiene contract for the Lean4/CSLib formal domains and
wired it into the four hard agents that consume Lean goal states (`lean-research-hard-agent`,
`lean-implementation-hard-agent`, `cslib-research-hard-agent`, `cslib-implementation-hard-agent`),
so large goal-state/hypothesis/file dumps stop overflowing context on every step. Also
documented the previously-undocumented `lean_minimal_hypotheses` tool and closed a wiring gap
(the two research hard agents lacked a `context-exhaustion-detection.md` reference that their
implementation counterparts already had).

## What Changed

- `.claude/extensions/lean/context/contracts/context-hygiene.md` — Created (75 lines). New
  standalone contract with four clauses: (1) goal-state query discipline (prefer targeted
  `lean_goal` at line/column, `lean_minimal_hypotheses`, `lean_term_goal` over broad/raw dumps;
  summarize in <=3 transcript lines), (2) file-read discipline (`Read` with `offset`/`limit`
  bounded to the active declaration; no whole-file reads; no re-reads; points at
  `blocked-mcp-tools.md` as the single source of truth for `lean_file_outline`'s block status
  rather than hardcoding it), (3) hypothesis pruning (carry forward only tactic-relevant
  hypotheses), and (4) an Enforcement paragraph mirroring `anti-analysis.md` style, with an
  explicit cross-reference distinguishing this contract's preventive hygiene from
  `context-exhaustion-detection.md`'s reactive checkpointing (task 781).
- `.claude/extensions/lean/index-entries.json` — Added one entry for
  `contracts/context-hygiene.md` with `load_when.agents` listing exactly the four hard-agent
  consumers, mirroring the existing `contracts/anti-analysis.md` entry structure.
- `.claude/extensions/lean/agents/lean-research-hard-agent.md` — Added the `## Context
  References` bullet (MANDATORY) for `context-hygiene.md`, added the shared `## Context Hygiene
  Contract Enforcement` inline block, added `lean_minimal_hypotheses` to the Core Tools list,
  and added the missing `@.claude/context/patterns/context-exhaustion-detection.md` reference
  (companion wiring-gap fix). Task 777's Stage 4.5 Claim Verification Table section was
  re-verified intact and untouched.
- `.claude/extensions/lean/agents/lean-implementation-hard-agent.md` — Added the `## Context
  References` bullet, the shared inline block, and `lean_minimal_hypotheses` to the Core Tools
  list. Already had `context-exhaustion-detection.md`, so no companion fix was needed. Task
  783's sorry-census grep (`lean-sorry-census.sh Theories/ --cross-check`) was re-verified
  intact and untouched.
- `.claude/extensions/cslib/agents/cslib-research-hard-agent.md` — Added the `## Context
  References` bullet (using the full `@.claude/extensions/lean/context/contracts/...` path per
  this file's existing cross-extension reference convention), the shared inline block,
  `lean_minimal_hypotheses` in Core Tools, and the missing `context-exhaustion-detection.md`
  reference (companion wiring-gap fix). Task 777's Stage 4.5 Claim Verification Table section
  was re-verified intact and untouched.
- `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` — Added the `## Context
  References` bullet, the shared inline block, and `lean_minimal_hypotheses` in Core Tools.
  Already had `context-exhaustion-detection.md`. Task 783's sorry-census step (`lean-sorry-census.sh
  Cslib/ --cross-check`) was re-verified intact and untouched.
- `.claude/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md` — Added a
  `lean_minimal_hypotheses` entry to the Core Tools section: what it returns, when to prefer it
  over a raw `lean_goal` local-context dump, its role in hypothesis pruning, and a cross-link to
  `context-hygiene.md`.
- `specs/782_formal_domain_goal_state_context_hygiene/plans/01_context-hygiene-contract.md` —
  All six phases marked `[COMPLETED]`, all checklist items checked off, top-level plan Status
  set to `[COMPLETED]`, and a `## Working Notes: Shared Wiring Text` section added recording the
  exact Context References bullet and inline internalization block pasted verbatim into all
  four agents (drift prevention).

## Decisions

- Deployment model verified before editing: `.claude/agents/cslib-*-hard-agent.md` are symlinks
  to `.claude/extensions/cslib/agents/*.md`, so the canonical extension-source files were edited
  directly (correct target). `.claude/agents/` currently has no `lean-*-hard-agent.md`
  files/symlinks at all (pre-existing repo installation state, unrelated to this task) — the
  canonical files under `.claude/extensions/lean/agents/` were edited, which is the single
  source of truth regardless of local `.claude/agents/` deployment state.
- Used the identical shared bullet + inline block text across all four self-contained agents
  (byte-identical, confirmed via `md5sum` on extracted blocks) to prevent wording drift, per the
  plan's Risk mitigation for Phase 1/3/4.
- The cslib agents reference the contract via its full cross-extension path
  (`@.claude/extensions/lean/context/contracts/context-hygiene.md`), matching their existing
  convention for cross-extension references (e.g., `citation-conventions.md`, `ci-pipeline.md`).
- `context-hygiene.md` intentionally does not hardcode `lean_file_outline`'s block status;
  it points at `blocked-mcp-tools.md` as the single source of truth, per the plan's Non-Goals
  (do not modify block status here) and Risk mitigation (contract must not go stale if the tool
  is unblocked upstream).
- Re-read all four hard-agent files fresh immediately before editing (per explicit task
  instruction) to confirm tasks 777 (Stage 4.5 Claim Verification Table in the two research
  agents) and 783 (sorry-census grep in the two implementation agents) had not been disturbed;
  confirmed both remain intact after this task's edits.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (meta task, no build system)
- Tests: N/A (no test suite for `.claude/` markdown/JSON)
- `jq empty .claude/extensions/lean/index-entries.json`: passed, new entry has
  `load_when.agents` = all four hard-agent names.
- `grep -l context-hygiene.md`: found in all four hard-agent files.
- `grep -l lean_minimal_hypotheses`: found in all four hard-agent files plus
  `mcp-tools-guide.md`.
- `grep -l context-exhaustion-detection`: found in all four hard-agent files (previously only
  the two implementation agents).
- Inline internalization block: confirmed byte-identical across all four agents via `md5sum` on
  the extracted `## Context Hygiene Contract Enforcement` section (same hash in all four).
- Files verified: Yes — all six touched/created files confirmed present with expected content.

## Cross-Repo Sync — FLAGGED (manual action required)

The Lean/CSLib extensions are consumed by a separate repository,
`/home/benjamin/Projects/cslib` (confirmed present, with its own `.claude/` directory), via
`source_dir`-based file-copy installation (`.claude/scripts/install-extension.sh`), not a live
symlink or git-submodule link. **This task did NOT edit anything under
`/home/benjamin/Projects/cslib`** (out of scope per the plan's Non-Goals).

**Required manual step for the user**: to propagate the new contract, the updated
`index-entries.json`, the four wired agent files, and the updated `mcp-tools-guide.md` into the
consuming repo, re-run:

```bash
.claude/scripts/install-extension.sh .claude/extensions/lean
.claude/scripts/install-extension.sh .claude/extensions/cslib
```

from inside `/home/benjamin/Projects/cslib` (or point the script at that repo's `.claude/`, per
its usage convention). Until this re-install is run there, `/home/benjamin/Projects/cslib`'s
hard agents will continue operating without the context-hygiene contract, the
`lean_minimal_hypotheses` tool documentation, and the `context-exhaustion-detection.md`
wiring-gap fix.

## Notes

- Task 781 (checkpoint-before-overflow / `context-exhaustion-detection.md`) is complementary,
  not implemented here — this task's contract is cross-referenced from it and vice versa, but
  task 781's reactive checkpointing mechanism itself was out of scope (Non-Goal).
- Wiring the four *base* (non-hard) lean/cslib agents to this contract was explicitly deferred
  per the plan's Non-Goals; only the four hard agents were wired in this task.
