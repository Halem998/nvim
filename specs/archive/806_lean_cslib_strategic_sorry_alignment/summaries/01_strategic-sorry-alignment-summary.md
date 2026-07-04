# Implementation Summary: Task #806

**Completed**: 2026-07-03
**Duration**: ~1 hour

## Overview

Reconciled the lean/cslib `--hard`-mode contracts with core task 778's relaxed zero-debt policy.
Task 778 introduced a domain-agnostic 5-condition strategic-sorry test (deliberate division
boundary, tightly scoped, documented, tracked, build-green) and a canonical 7-field
`sorry_inventory` schema `{file, line, statement, strategic, assumption, why_deferred,
follow_up_task}`, but the lean/cslib hard-mode overrides still forbade main-target sorries
unconditionally at 6 anchor points across 3 files, directly contradicting the new core policy.
All 6 anchor points are now corrected, the `next_dispatch` -> `follow_up_task` rename is complete
repo-wide, and standard-mode lean/cslib agents remain untouched.

## What Changed

- `.claude/extensions/lean/context/contracts/anti-analysis.md` — Removed the categorical
  "Non-leaf sorries ... are NEVER acceptable as final output" ban and its escalation sentence;
  kept the leaf-sorry criteria (items 1-3) unchanged; added a new
  `### Strategic main-target sorries (Lean4 skeleton division points)` subsection mirroring core
  `anti-analysis.md`'s five-condition test, specialized for Lean4 (`sorry` as the canonical
  build-green placeholder; track via `#print axioms <decl>` showing `sorryAx` and/or
  `declaration uses 'sorry'` warnings); updated the H9 Sorry Inventory field list to the canonical
  `{file, line, statement, strategic, assumption, why_deferred, follow_up_task}`. The
  proof-line-bar and forbidden-conclusions sections were left unchanged.
- `.claude/extensions/lean/agents/lean-implementation-hard-agent.md` — Fixed all 5 planned anchor
  points: (a) Stage 5 handoff JSON example now includes `"skeleton": false` (with usage note) and
  the `sorry_inventory` entry uses `strategic`/`follow_up_task` instead of `next_dispatch`;
  (b) the "Leaf sub-sorry vs. main-target sorry" section now has an explicit strategic-sorry
  branch (main-target sorry meeting all five conditions -> `sorry_inventory` with
  `strategic: true` + `follow_up_task`, NOT `blockers`, `status: "implemented"` with
  `skeleton: true`) and the unconditional "set `status: partial` if any main-target sorries
  remain" was removed; (c) Stage 6 Final Verification item 1 now reads `sorry_count` must be 0 OR
  every remaining sorry is tracked+strategic, otherwise `status` cannot be `"implemented"`;
  (d) the Zero-Debt Policy section gained a second exception (strategic main-target sorries
  meeting the five-condition test) alongside the existing leaf-sub-sorry exception, with
  `next_dispatch` renamed to `follow_up_task`; (e) MUST-NOT item 4 now carries the
  strategic-sorry/skeleton exception. An additional, previously unlisted `next_dispatch`
  occurrence was found and fixed in Stage 4 step C ("Sorry Inventory Update") — see Plan
  Deviations.
- `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` — Fixed both planned anchor
  points: (a) the Stage 5 handoff JSON example gained `"skeleton": false`, and the
  `sorry_inventory` prose now states the canonical 7-field schema and explains that a tracked
  strategic main-target sorry (`strategic: true`, non-null `follow_up_task`) is permissible with
  `skeleton: true`, not only an empty `sorry_inventory`; (b) MUST-NOT item 5 gained the same
  strategic-sorry/skeleton exception as the lean file's item 4. The Escalation Protocol section
  (governs `[BLOCKED]` phases) and the cslib Context-References path were both left untouched, as
  specified.

## Decisions

- **cslib Context-References open question (explicit no-change decision)**: The cslib hard agent's
  `## Context References` section (line 40) still points at CORE
  `@.claude/context/contracts/anti-analysis.md`, not the lean override. This is deliberately left
  unchanged in task 806: switching it to the lean override would also import the lean
  proof-line-bar and lean-specific forbidden conclusions, altering H2 behavior for cslib beyond
  this task's sorry-policy scope. **Recommendation**: spawn a dedicated follow-up task to decide,
  deliberately, whether cslib should adopt the lean H2 override wholesale, adopt a cslib-specific
  H2 specialization, or continue pointing at core — this ambiguity pre-dates task 806 and is not
  resolved by it.
- The additional `next_dispatch` occurrence found in the lean agent's Stage 4 step C ("Sorry
  Inventory Update" bullet list) was renamed even though the plan's task-level anchor description
  named only the Stage 5 JSON example and its line-291 field description — leaving it would have
  failed the Phase 4 repo-wide `next_dispatch` grep.

## Plan Deviations

- **Task 2.a** altered: In addition to the two named `next_dispatch` occurrences (Stage 5 JSON
  entry field and its schema description), a third occurrence was discovered in Stage 4 step C
  ("Sorry Inventory Update") of `lean-implementation-hard-agent.md` and renamed to
  `follow_up_task` (with `strategic` added to the field list) to satisfy the Phase 4 zero-residual
  verification. No other deviations occurred; all other tasks were completed exactly as scoped.

## Verification

- Build: N/A (documentation-only task; no Lean/build system involved)
- Tests: N/A
- Files verified: Yes — all three edited files re-read/grepped after edits

**Grep verification results** (Phase 4):
- `grep -rn "next_dispatch" .claude/` -> 0 occurrences (repo-wide rename complete)
- `grep -rn "NEVER acceptable" .claude/extensions/lean .claude/extensions/cslib` -> 0 occurrences
- `sorry_inventory` field list `{file, line, statement, strategic, assumption, why_deferred,
  follow_up_task}` confirmed identical across all three edited files and core `wrap-up.md`
- `git status`/`git diff --name-only` confirms only the 3 target hard-mode files were modified;
  `lean-implementation-agent.md` and `cslib-implementation-agent.md` (standard-mode) are untouched

> **NOTE (downstream re-sync)**: `~/Projects/cslib` contains a flattened, stale copy of these
> `.claude/` contracts and agents (per the task 806 research report). That repository was **not**
> edited by this task. After 806 lands, manually re-copy the following files from this repo into
> `~/Projects/cslib/.claude/` to keep the two copies consistent:
> - `.claude/extensions/lean/context/contracts/anti-analysis.md`
> - `.claude/extensions/lean/agents/lean-implementation-hard-agent.md`
> - `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md`
> - Also re-check core `.claude/context/contracts/anti-analysis.md` and
>   `.claude/context/contracts/wrap-up.md` — these were already flattened/stale in
>   `~/Projects/cslib` from task 778 and remain unsynced independent of task 806.
> Do not edit `~/Projects/cslib` from within this repository; the re-sync is a manual step for the
> user (or a dedicated follow-up task) to perform in that repository's own working copy.

## Notes

- Standard-mode agents (`lean-implementation-agent.md`, `cslib-implementation-agent.md`) were
  confirmed unchanged, per the task's non-goals.
- No build/runtime verification applies — this is a pure markdown/contract-documentation change.
- Follow-up recommended: a dedicated task to resolve the cslib Context-References path ambiguity
  (see Decisions above).
