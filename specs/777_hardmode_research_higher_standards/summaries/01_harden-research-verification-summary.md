# Implementation Summary: Task #777

**Completed**: 2026-07-03
**Duration**: ~1 session

## Overview

Hardened `--hard` research verification by creating the missing H4 contract
(`adversarial-verification.md`), adding per-tier source-coverage minimums to the H3
`reference-grounding.md` contract, and replacing the duplicated Stage 4.5 prose in all
three research-hard agents (general, cslib, lean) with a contract pointer plus a required
Claim Verification Table and Contradiction Log. All 7 phases completed, including the
optional Phase 6 orchestrate-hard gate strengthening.

## What Changed

- `.claude/context/contracts/adversarial-verification.md` — New H4 contract: Claim
  Verification Bar, Confidence Level Taxonomy, Contradiction Resolution Protocol,
  Forbidden Verification Outputs, Domain Specialization (cslib BibKey, lean4
  `lean_hover_info`).
- `.claude/extensions/lean/context/contracts/adversarial-verification.md` — New lean
  parity copy of the H4 contract (inlined domain note) so lean-only deployments retain it.
- `.claude/context/contracts/reference-grounding.md` — Added `## Source-Coverage
  Minimums` subsection (no single-source conclusions, per-tier rules + codebase-pattern
  rule).
- `.claude/extensions/lean/context/contracts/reference-grounding.md` — Added `##
  Source-Coverage Minimums (Lean4)` subsection adapted to the 5-column mapping table
  structure.
- `.claude/context/index.json` — Registered `contracts/adversarial-verification.md` entry
  (`load_when.agents`: general/cslib/lean research-hard agents); refreshed the
  `reference-grounding.md` entry's `line_count` and summary.
- `.claude/extensions/lean/index-entries.json` — Mirrored the adversarial-verification.md
  entry so it survives an index rebuild from extension sources.
- `.claude/agents/general-research-hard-agent.md` + `.claude/extensions/core/agents/general-research-hard-agent.md`
  — Added H4 contract to Context References (MANDATORY), added a no-single-source-conclusion
  rule to Stage 3, rewrote Stage 4.5 to require the Claim Verification Table + Contradiction
  Log (kept byte-identical via `cp`).
- `.claude/extensions/cslib/agents/cslib-research-hard-agent.md` (deployed
  `.claude/agents/cslib-research-hard-agent.md` symlink updates automatically) — Same
  rewrite, preserving BibKey verification / Reuse Check Protocol / Zero-Debt Policy as
  domain-specific `Verification Method` values.
- `.claude/extensions/lean/agents/lean-research-hard-agent.md` — Same rewrite, preserving
  `lean_hover_info`-confirmed type signatures and `lean_local_search` as domain-specific
  `Verification Method` values.
- `.claude/skills/skill-researcher-hard/SKILL.md` + `.claude/extensions/core/skills/skill-researcher-hard/SKILL.md`
  — Added the H4 contract to Context References as MANDATORY (both copies, which differ
  elsewhere but matched here).
- `.claude/skills/skill-orchestrate-hard/SKILL.md` + `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  (Phase 6, optional — implemented) — Extended the `researched` state's structural grep
  gate to also require the Claim Verification Table header before skipping re-dispatch.

## Decisions

- Used `cp` to guarantee byte-identity for the two `general-research-hard-agent.md` copies
  after editing one, rather than three separate parallel Edit calls.
- Implemented the optional Phase 6 (orchestrate-hard gate strengthening) since it was
  low-risk, in-scope per the plan, and not on the forbidden-territory list.
- Kept the H3→H4 cross-reference anchor text as `#source-coverage-minimums` (core) and
  `#source-coverage-minimums-lean4` (lean) matching the finalized Phase 1 headings.

## Plan Deviations

- None (implementation followed plan). Phase 6 was completed rather than abandoned, which
  the plan explicitly allowed as a judgment call ("implement or mark [ABANDONED]").

## Verification

- Build: N/A (markdown/JSON only)
- Tests: N/A
- `jq empty` on `.claude/context/index.json` and `.claude/extensions/lean/index-entries.json`: both valid
- `diff` on both `general-research-hard-agent.md` copies and both `skill-orchestrate-hard/SKILL.md` copies: identical
- `readlink .claude/agents/cslib-research-hard-agent.md` still resolves into the edited extension file
- `bash .claude/scripts/validate-index.sh`: exit 0 (1 pre-existing warning, unrelated to this task)
- `bash .claude/scripts/validate-context-index.sh`: 2 pre-existing errors (domain `null` on
  `patterns/topic-assignment-pattern.md`), confirmed via git-stash comparison to predate this
  task's changes; no errors/warnings on any file touched by this task
- `git status`: confirmed no standard-mode files (`general-research-agent.md`,
  `skill-researcher/`, `skill-researcher/SKILL.md`) were touched
- `bash .claude/scripts/check-extension-docs.sh`: pre-existing `cslib`/`lean` FAILs
  reference `lean-sorry-census.sh` and undeployed `routing_hard` skill targets — both
  explicitly out of this task's territory and unrelated to the content-only contract/agent
  edits made here

## Notes

Two files owned by other in-flight tasks (`.claude/context/contracts/anti-analysis.md`,
various `general-implementation-hard-agent.md` / `skill-implementer-hard` files) were
observed modified in the working tree by parallel agents during this session but were not
touched by this implementation, per the H7 territory constraint.
