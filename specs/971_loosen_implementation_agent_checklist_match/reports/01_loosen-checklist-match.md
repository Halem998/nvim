# Research Report: Loosen implementation agents' plan-checklist match off the literal `**Task {P}.{N}**:` prefix

- **Task**: 971 - Loosen implementation agents' plan-checklist match off the literal `**Task {P}.{N}**:` prefix
- **Started**: 2026-07-30T01:10:52Z
- **Completed**: 2026-07-30T01:13:00Z
- **Effort**: ~30 minutes
- **Dependencies**: None
- **Sources/Inputs**: Direct inspection of `agent-system/extensions/core/agents/general-implementation-agent.md`, `agent-system/extensions/lean/agents/lean-implementation-agent.md`, `agent-system/extensions/nix/agents/nix-implementation-agent.md`, `agent-system/extensions/core/agents/planner-agent.md`, `.claude/context/formats/return-metadata-file.md`, `.claude/docs/architecture/handoff-schema.md`
- **Artifacts**: this report
- **Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- Confirmed the exact shape mismatch: `planner-agent.md` emits free-form prose checklist items (`- [ ] {Step 1}`, `- [ ] {Test criterion 1}`, lines 237-238 and 267-268) with no `**Task {P}.{N}**:` prefix anywhere, while all three implementation agents instruct matching/annotating on that literal prefix.
- Counted occurrences exactly as the task description states: general-implementation-agent.md has 12, lean-implementation-agent.md has 3, nix-implementation-agent.md has 5 — all consistent with a single shared idiom, not independent inventions.
- The three files use the literal prefix in two distinct instruction roles that must both be loosened: (1) general-implementation-agent.md's dedicated "Check Off Completed Items" Edit instruction (Stage 4B-ii, its own section), and (2) all three files' "deviation annotation" example lines (skipped/altered/deferred), which illustrate the annotation suffix syntax but wrongly assume the same literal prefix as the matchable line shape.
- The task's own scoping is precise on what to preserve: the annotation *suffix* wording (`*(deviation: skipped — {reason})*`, `*(deviation: altered — {what changed})*`, `*(deviation: deferred to task {N})*`, `*(completed)*`, `*(completed: {brief note})*`, `*(in progress)*`) is correct and unrelated to the shape-matching bug — only the assumed leading `- [ ] **Task {P}.{N}**: {description}` line shape needs to be genericized to "the item's existing text."
- Recommend one canonical instruction block (below) that both replaces general-implementation-agent.md's Stage 4B-ii check-off instruction and replaces the leading-shape assumption in all three files' deviation-annotation examples, while leaving the annotation-suffix vocabulary byte-for-byte unchanged.
- planner-agent.md is confirmed out of scope per the task's chosen resolution — it is not edited by this task.

## Context & Scope

The task asks for research into how to reword the plan-checklist "mark completed" / "annotate deviation" instructions in three implementation agents so they no longer depend on matching a literal `**Task {P}.{N}**:` prefix that planner-agent.md never actually emits. The three in-scope files (all under the source store, `agent-system/extensions/**`, never the disposable `.claude/**` deploy tree) are:

- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/lean/agents/lean-implementation-agent.md`
- `agent-system/extensions/nix/agents/nix-implementation-agent.md`

This is a research-only pass (task_type `meta`, `/research` phase of an `/orchestrate` run); no files are edited here. The deliverable is the canonical wording two downstream tasks (which extend the same contract to cslib and hard-mode implementation agents) can copy verbatim, plus a per-file mapping of exactly which lines in the three in-scope files need the change.

## Findings

### Confirmed root cause (planner-agent.md checklist shape)

`agent-system/extensions/core/agents/planner-agent.md`:
- Line 237-238: `- [ ] {Step 1}` / `- [ ] {Step 2}`
- Line 267-268: `- [ ] {Test criterion 1}` / `- [ ] {Test criterion 2}`

No `**Task {P}.{N}**:` prefix template exists anywhere in planner-agent.md's checklist-emission guidance. This confirms the task description's claim that plans are emitted as free-form prose checklist items, and that the three implementation agents' literal-prefix match can never fire against a real plan.

### general-implementation-agent.md (12 occurrences)

Two distinct instruction sites, both needing the loosened wording:

1. **Stage 4B-ii, "Check Off Completed Items in Plan File"** (lines 181-204) — the dedicated mark-completed instruction. Currently an explicit Edit `old_string`/`new_string` pair keyed on the literal prefix:
   - Line 187-188: completed-item Edit (`- [ ] **Task {P}.{N}**: {description}` -> `- [x] **Task {P}.{N}**: {description} *(completed)*`)
   - Line 191: completed-with-note variant
   - Line 194: in-progress annotation variant
   - Lines 199-201: the three deviation variants (skipped/altered/deferred)
   - Line 204's "Note" (about skipping the step entirely if the plan doesn't use `- [ ]` syntax) becomes unnecessary once matching is text-based rather than shape-based, since prose `- [ ]` items are still `- [ ]` checklist syntax — only the exact template between the brackets differs.

2. **Stage 4D-ii, "Post-Phase Self-Review"** (lines 278-306) — repeats the same three deviation-variant example lines at lines 300-302 as a cross-reference back to Stage 4B-ii's format.

3. **Summary-template appendix** (lines 483-488) — the `## Plan Deviations` summary section template uses `**Task {P}.{N}**` prose (not checklist syntax) at lines 485-486; this is a different, non-checklist context (free prose bullets in the implementation summary document, not an Edit match against the plan file) and is not part of the checklist-matching bug — no change needed here beyond optional wording harmony, which is out of scope.

Also present at line 345 (Stage 4E, context-pressure handoff path): "For each completed task in the current phase: ensure `- [x]` with `*(completed)*` annotation if not already annotated" — this line is already text-agnostic (no literal prefix assumed) and needs no change; it is evidence the codebase already has both a brittle and a loose idiom coexisting.

### lean-implementation-agent.md (3 occurrences)

Lines 100-107, "When a plan step is skipped, altered, or deferred during implementation" — the lean agent has no separate literal-prefix "mark completed" Edit instruction; its only literal-prefix occurrences are the three deviation-variant example lines (103-105), mirroring general-implementation-agent.md's Stage 4B-ii step 4. Line 399 already uses the loose, prefix-agnostic phrasing ("ensure `- [x]` with `*(completed)*` annotation if not already annotated"), same pattern as general-implementation-agent.md line 345.

### nix-implementation-agent.md (5 occurrences)

Lines 214-217 ("Annotate deviations in plan file") — the three deviation-variant example lines (215-217), same pattern as the other two files. Lines 330-331 are the prose `## Plan Deviations` summary-template bullets (same non-checklist context as general-implementation-agent.md lines 485-486, not part of the bug). Line 276 already uses the loose phrasing ("ensure `- [x]` with `*(completed)*` annotation"), consistent with the other two files.

### Pattern across all three files

Every file already contains, elsewhere, an alternate phrasing that is loose/text-agnostic ("ensure `- [x]` with `*(completed)*` annotation if not already annotated" — general-implementation-agent.md:345, lean-implementation-agent.md:399, nix-implementation-agent.md:276). This is strong evidence the codebase's own idiom for "mark this item done regardless of its exact text" already exists and is sound; the fix is to make the *other* (literal-prefix) instruction sites consistent with it, not to invent new wording.

## Decisions

- **Preserve, do not touch, the annotation-suffix vocabulary.** The bracketed annotation text — `*(completed)*`, `*(completed: {brief note})*`, `*(in progress)*`, `*(deviation: skipped — {reason})*`, `*(deviation: altered — {what changed})*`, `*(deviation: deferred to task {N})*` — is a separate, already-correct concern per the task description and must be reused byte-for-byte.
- **Genericize only the leading-shape assumption.** Replace every `- [ ] **Task {P}.{N}**: {description}` / `- [x] **Task {P}.{N}**: {description}` template that appears as the *matchable line shape* with a placeholder that denotes "this item's existing text, whatever form it takes" — never assuming a `**Task {P}.{N}**:` prefix, bold markup, or any other specific title format.
- **Recommended canonical instruction wording** (for general-implementation-agent.md's Stage 4B-ii, and to replace the deviation-variant example blocks in all three files):

  > Locate the checklist item by its existing item text — do not assume a `**Task {P}.{N}**:` prefix or any other particular title format; plans commonly use free-form prose items like `- [ ] {Step 1}`. To mark an item complete, rewrite the leading `- [ ]` to `- [x]` and append `*(completed)*` (or `*(completed: {brief note})*` for a note-bearing variant), preserving the item's existing text unchanged. For an in-progress item, leave `- [ ]` and append `*(in progress)*`. For a deviation, keep the existing deviation-annotation formats unchanged:
  > - Skipped: `- [ ] {existing item text} *(deviation: skipped — {reason})*`
  > - Altered: `- [x] {existing item text} *(deviation: altered — {what changed})*`
  > - Deferred: `- [ ] {existing item text} *(deviation: deferred to task {N})*`

  Here `{existing item text}` is a placeholder standing for whatever text already follows `- [ ]` in the plan file — it is not new template syntax to inject into plans, only a description in the *instruction* of what the agent must locate and preserve verbatim.

- **The Stage 4B-ii "Note" about skipping the step when the plan doesn't use `- [ ]` syntax (general-implementation-agent.md:204) should be dropped or reworded**, since once matching is by text rather than by prefix shape, any `- [ ]` checklist syntax (prose or otherwise) is matchable; the only remaining escape hatch is a plan with no checklist syntax at all, which is a much narrower and already-implied case.
- **planner-agent.md is out of scope** — confirmed by the task's chosen resolution; no changes recommended there. Free-form prose items are the accepted, more-readable format going forward.

## Risks & Mitigations

- **Risk**: A reworded instruction that is too vague ("match by text") could itself fail silently again if the agent can't find an exact substring match (e.g., plan text was slightly reformatted between planning and implementation). **Mitigation**: this is an implementation-plan concern, not a research concern — leave a note for the planner-agent (972/974) that the instruction should tell the agent to match on the item's core text/intent, tolerating minor formatting drift, rather than requiring byte-exact match; the downstream plan should specify this explicitly since it affects agent behavior precision.
- **Risk**: The two downstream tasks (972, 974) need this exact wording; if it drifts between files it creates the same inconsistency this task is fixing. **Mitigation**: the canonical block above is written to be pasted verbatim, with only the deviation-suffix lines reused unmodified from the existing files (so a diff-based reviewer can confirm no accidental change to that already-correct text).

## Appendix

- Line references (as inspected, source store): general-implementation-agent.md:181-204, 278-306, 345, 483-488; lean-implementation-agent.md:100-107, 399; nix-implementation-agent.md:214-217, 239-241, 276, 330-331; planner-agent.md:237-238, 267-268.
- Occurrence counts verified via `grep -n` against literal `Task {P}.{N}` / `- [ ] **Task` / `- [x]` / `- [ ]` patterns in each of the three in-scope files, matching the task description's stated counts (12/3/5) exactly.
