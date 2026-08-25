# Implementation Summary: Task #66

- **Task**: 66 - Mandate run_in_background for Lean builds and add long-builds anchor
- **Status**: [COMPLETED]
- **Started**: 2026-08-25T00:00:00Z
- **Completed**: 2026-08-25T01:45:00Z
- **Effort**: ~2 hours
- **Dependencies**: core build-guard task (DELIVERED: `agent-system/extensions/core/scripts/lake-build-guard.sh`)
- **Artifacts**: plans/01_background-lake-builds.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Landed a single contract-text pass over the lean extension's source store mandating that every
`lake build` invocation be both detached (`Bash(run_in_background: true)`) and routed through the
shared `lake-build-guard.sh` wrapper with an explicit `--timeout 1800`. Created one new canonical
anchor, `long-builds.md`, that owns all explanatory prose; the eight existing contract files gain
pointers and mandate text rather than restating it.

## What Changed

- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` — new file
  (153 lines). Owns the foreground-cap explanation, the per-module-caching livelock mechanism, the
  detachment and guard obligations, the canonical invocation string, the scoped-builds-are-covered
  decision, the four passive progress checks with the liveness-not-termination caveat, completion
  discipline, known gaps, and a cross-reference to `multi-instance-optimization.md`.
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` — anchor reference added to
  `## Context References`; step-4 build-verification fence rewritten to the guarded, detached
  invocation; MUST DO items 7-8 revised (scoped reframed as "less work" not "safe"; run-via-guard
  note added); MUST NOT item 3 revised to drop the scoped exemption; new MUST NOT item 13 added
  prohibiting foreground `lake build`; three additional descriptive `lake build` mentions
  (BLOCKED-tools fallback table, Build Tools bullet) given light-touch pointers.
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` — same treatment,
  located by content (not by mirrored line numbers): anchor reference, Stage 4.D and Stage 6
  build fences rewritten, MUST DO item 7 revised, new MUST NOT item 13 added equivalent in content
  to the base agent's, sorry-census cross-check note annotated as out-of-scope-script, plus
  fallback-table and Build Tools pointers.
- `agent-system/extensions/lean/rules/lean4.md` — Workflow Pattern items 4-5 rewritten to the
  guarded/detached form; Build Commands section rewritten to remove the "scoped = safe" framing,
  add the canonical invocation shape, and point at the anchor; a pointer added to the Blocked
  MCP Tools alternative line.
- `agent-system/extensions/lean/skills/skill-lake-repair/SKILL.md` — Step 4's two command-
  substitution build sites rewritten to route through the guard while staying synchronous
  (Option (c)); an inline decision note added recording the detachment carve-out, its reason, and
  the residual cap exposure; the `build_exit_code=$?` capture preserved; MCP-failure fallback
  pointer added.
- `agent-system/extensions/lean/agents/lean-research-agent.md`,
  `agent-system/extensions/lean/agents/lean-research-hard-agent.md` — Build Tools bullets, APOLLO
  decomposition step (base agent only), and fallback-table rows given anchor pointers.
- `agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md`,
  `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` — build-mention
  lines and MUST NOT postflight-boundary item 2 given anchor pointers; prohibitions left intact.

## Decisions

- **Scoped builds are covered, not exempt.** A single module can already exceed the foreground
  cap, and the guard's lock is project-granular regardless of invocation scope. The named cost:
  phase-end scoped builds from concurrent sessions on the same package that could previously run
  in parallel against different modules now serialize project-wide. Recorded in the anchor's
  "Scoped builds are covered too" section as a deliberate tradeoff, not a hidden regression.
- **`skill-lake-repair` takes Option (c).** Its two `build_output=$(...)` sites are incompatible
  with `run_in_background` (a detached call returns no stdout to a shell variable) but fully
  compatible with the guard. Both sites now route through the guard, stay synchronous, and are
  carved out of the *detachment* mandate only — never the guard mandate. The residual exposure (a
  heavy build in this loop can still hit the foreground cap, but the failure surfaces as a failed
  command substitution the existing `build_exit_code` handling already covers) is documented
  inline at the call site and cross-referenced from the anchor's "Known gaps" section.
- **`mcp__lean-lsp__lean_build` is a documented gap, not a fix target.** `run_in_background`
  cannot wrap an MCP tool call; this is recorded in the anchor rather than silently omitted.

## Plan Deviations

- None (implementation followed plan). Several descriptive `lake build` mentions not explicitly
  enumerated in the plan's per-file task lists (e.g. fallback-table rows, a `SKILL.md` verification
  note) were given the same light-touch anchor pointer as the enumerated sites, for consistency
  with the Phase 2/Phase 5 Scope Hypothesis requirement that every remaining occurrence be
  consciously accounted for rather than silently skipped. This is treated as in-spirit completion
  of the enumerated task list, not a deviation from it.

## Verification

- Build: N/A (all nine files are markdown; no build or runtime surface)
- Tests: N/A
- Files verified: Yes — `long-builds.md` exists (153 lines) with every required section; both
  implementation agents carry an equivalent foreground-build MUST NOT item (verified by content
  grep); every `lake-build-guard.sh build` invocation across all touched files passes an explicit
  `--timeout` (verified — zero occurrences found relying on the default); the generic normative
  sentence "Any single module may exceed the foreground cap" appears with the ~11-minute figure
  only in an explicitly illustrative note; `grep -in "task [0-9]+"` over all nine files returns
  nothing; `git status --porcelain .claude/` is empty; `scripts/**`, `manifest.json`,
  `index-entries.json`, and `opencode-agents.json` under the lean extension are unmodified by this
  task; `multi-instance-optimization.md` is unmodified by this task (it carries an uncommitted
  modification from the concurrently running task that owns it, observed but not touched);
  `agent-system/extensions/core/scripts/lake-build-guard.sh` exists in the source store and the
  deploy path cited in all contract text (`.claude/scripts/lake-build-guard.sh`) matches the flat
  deploy convention already used for `lean-sorry-census.sh`.

## Impacts

- Every documented `lake build` call site across the lean extension's implementation and research
  agents, its two `skill-lean-implementation` twins, its build-repair skill, and its core Lean 4
  rules file now instructs detached, guarded invocation with an explicit lock-wait timeout,
  closing the foreground-cap livelock this task set out to fix.
- Files outside the declared file_scope that also mention `lake build` (`README.md`,
  `context/project/lean4/agents/lean-implementation-flow.md`,
  `context/project/lean4/standards/proof-conventions-lean.md`, `commands/lake.md`,
  `context/project/lean4/standards/proof-debt-policy.md`,
  `context/project/lean4/patterns/mcp-fallback-table.md`,
  `context/project/lean4/tools/mcp-tools-guide.md`,
  `context/project/lean4/tools/blocked-mcp-tools.md`, `.claude/context/contracts/anti-analysis.md`)
  were deliberately left untouched: the plan's research phase enumerated exactly eight existing
  contract files as the mandate's instruction sites, and these were not among them. They remain a
  residual inconsistency an eventual follow-up pass could close.

## Follow-ups

- Add an `index-entries.json` entry for `long-builds.md` (outside this task's file_scope;
  `index-entries.json` is owned by the concurrently running task).
- Add a reciprocal pointer from `multi-instance-optimization.md` back to `long-builds.md` when the
  owning task next rewrites that file (out of scope here; that file is owned by a concurrent
  task).
- Consider extending the mandate to the files enumerated under Impacts above
  (`lean-implementation-flow.md`, `commands/lake.md`, etc.) in a future pass, if those are
  confirmed as genuine agent instruction sites rather than historical/illustrative documentation.

## References

- Plan: `specs/066_mandate_background_lake_builds/plans/01_background-lake-builds.md`
- Research: `specs/066_mandate_background_lake_builds/reports/01_mandate-background-lake-builds.md`
- New anchor: `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md`
