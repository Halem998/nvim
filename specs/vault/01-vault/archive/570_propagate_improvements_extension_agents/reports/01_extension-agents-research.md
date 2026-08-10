# Research Report: Task #570

**Task**: 570 - propagate_improvements_extension_agents
**Started**: 2026-05-14T00:00:00Z
**Completed**: 2026-05-14T00:15:00Z
**Effort**: ~20 minutes
**Dependencies**: Task 569 (completed)
**Sources/Inputs**: Direct file reads of all 11 agent files
**Artifacts**: This report
**Standards**: report-format.md

---

## Executive Summary

- All 11 agents were read and classified. Two agents are verbatim copies of the general-implementation-agent (cores/general and .claude/agents/neovim and nix) or near-verbatim copies; the remaining are full domain agents with their own Phase execution loops.
- The four changes from task 569 (4B-ii Step 4 deviation annotation, 4D-ii post-phase self-review, 4D-iii progressive handoff, 4E Step 1.5 plan annotation, Stage 6 `## Plan Deviations` section, Phase Checkpoint Protocol step 4 update) are absent from **all** 11 agents.
- The core extension copy (`extensions/core/agents/general-implementation-agent.md`) is a pre-569 snapshot that needs an **identical** update to the main agent. The remaining 10 agents are domain-specialized but share the same phase loop skeleton and need the same changes adapted to their domain.

---

## Agent Inventory Table

| # | Agent Path | Type | Phase Loop | Summary Template | Phase Checkpoint | Classification |
|---|------------|------|-----------|-----------------|-----------------|----------------|
| 1 | `.claude/extensions/core/agents/general-implementation-agent.md` | General | Full (pre-569 snapshot) | Old template (no `## Plan Deviations`, no `## What Changed`) | Has step 4 as `[COMPLETED]` or `[BLOCKED]` — no 4D-ii/4D-iii reference | **A** — identical update |
| 2 | `.claude/extensions/lean/agents/lean-implementation-agent.md` | Lean4/proof | Minimal loop (no B-ii/4D-ii/4D-iii/4E-1.5) | No summary template in body | Has step 4 as git commit only — no 4D-ii/4D-iii | **B** — full agent, adapted |
| 3 | `.claude/extensions/nix/agents/nix-implementation-agent.md` | Nix config | Full loop (no 4B-ii/4D-ii/4D-iii/4E-1.5) | Old template (`## Changes Made`, no deviations) | No Phase Checkpoint Protocol section | **B** — full agent, adapted |
| 4 | `.claude/extensions/nvim/agents/neovim-implementation-agent.md` | Neovim/Lua | Full loop (no 4B-ii/4D-ii/4D-iii/4E-1.5) | Old template (`## Changes Made`, no deviations) | No Phase Checkpoint Protocol section | **B** — full agent, adapted |
| 5 | `.claude/extensions/latex/agents/latex-implementation-agent.md` | LaTeX | Thin loop (stages collapsed, E. Git Commit present) | No template shown (delegated to summary-format.md) | No Phase Checkpoint Protocol section | **C** — thin wrapper, minimal |
| 6 | `.claude/extensions/python/agents/python-implementation-agent.md` | Python | Thin loop (stages collapsed, git in D) | No template shown | No Phase Checkpoint Protocol section | **C** — thin wrapper, minimal |
| 7 | `.claude/extensions/typst/agents/typst-implementation-agent.md` | Typst | Thin loop (stages collapsed, E. Git Commit present) | No template shown | No Phase Checkpoint Protocol section | **C** — thin wrapper, minimal |
| 8 | `.claude/extensions/web/agents/web-implementation-agent.md` | Web/Astro | Full loop (no 4B-ii/4D-ii/4D-iii/4E-1.5) | Old template (`## Changes Made`, no deviations) | No Phase Checkpoint Protocol section | **B** — full agent, adapted |
| 9 | `.claude/extensions/z3/agents/z3-implementation-agent.md` | Z3/SMT | Thin loop (stages collapsed, git in D) | No template shown | No Phase Checkpoint Protocol section | **C** — thin wrapper, minimal |
| 10 | `.claude/agents/neovim-implementation-agent.md` | Neovim/Lua | Full loop (identical to extensions/nvim) | Old template (`## Changes Made`, no deviations) | No Phase Checkpoint Protocol section | **B** — full agent, adapted |
| 11 | `.claude/agents/nix-implementation-agent.md` | Nix config | Full loop (identical to extensions/nix) | Old template (`## Changes Made`, no deviations) | No Phase Checkpoint Protocol section | **B** — full agent, adapted |

### Classification Legend

- **A** — Verbatim copy of the general agent (pre-569 snapshot). Needs **identical** changes as task 569.
- **B** — Full domain agent with its own phase execution loop. Needs the same 4 insertions plus summary template update, adapted slightly to the agent's domain vocabulary (no structural changes to domain sections).
- **C** — Thin wrapper agent. Loop body is compressed to 2-4 bullet lines; no room for or benefit from 4B-ii/4D-ii/4D-iii/4E-1.5. Needs only the `## Plan Deviations` section added to the summary template (since the summary template delegates to summary-format.md, the change may only be needed if that file is updated separately).

---

## Per-Agent Findings

### Agent 1: `extensions/core/agents/general-implementation-agent.md` (Type A)

**Structure**: Exact copy of the general-implementation-agent.md before task 569 was applied.

**What it currently has**:
- Stage 4B-ii: Has items 1–3 (check off completed, in-progress note) but **missing Step 4** (deviation annotation for skipped/altered/deferred steps)
- Stage 4D: Has `[COMPLETED]` marker update but **no 4D-ii or 4D-iii**
- Stage 4E: Has the handoff protocol but **missing Step 1.5** (plan annotation before writing handoff)
- Stage 6 template: `## Changes Made` + `## Files Modified` — **missing `## Plan Deviations`**, `## Decisions`, and the new `## What Changed` flattened structure
- Phase Checkpoint Protocol step 4: `[COMPLETED]` or `[BLOCKED]` only — no reference to 4D-ii/4D-iii

**Exact insertion points** (line references from the file read):
- Line 171 (`**Note**: If the plan file does not use...`): Insert Step 4 deviation annotation block between line 170 and 171
- After line 187 (the `**D. Mark Phase Complete**` heading close): Insert `#### 4D-ii. Post-Phase Self-Review` block
- After 4D-ii block: Insert `#### 4D-iii. Progressive Handoff Update` block
- Line 193–194 (Step 1 in the handoff section `E.`): Insert Step 1.5 between Step 1 and Step 2
- Lines 230–254 (Stage 6 template): Replace old template with updated version including `## Plan Deviations`
- Line 348 (Phase Checkpoint Protocol step 4): Replace `**Update phase status** to `[COMPLETED]` or `[BLOCKED]` or `[PARTIAL]`` with the reference to 4D-ii and 4D-iii

---

### Agent 2: `extensions/lean/agents/lean-implementation-agent.md` (Type B)

**Structure**: Full domain agent, but the execution loop is distributed differently. The lean agent does NOT have a numbered stage/sub-stage structure like the general agent. Instead, it has:
- A "Phase Status Updates (MANDATORY)" section at the top (lines 66–89)
- A "Phase Checkpoint Protocol" near the bottom (lines 328–350)
- A "Context Management / Handoff Protocol" section (lines 353–373)
- No Stage 4B-ii, 4D-ii, 4D-iii, or 4E sections

**Lean-specific differences**:
- Has no progress file tracking (uses lean-lsp MCP tools instead)
- Has an "Escalation Protocol" for [BLOCKED] phases (no equivalent in general agent)
- Uses `git add <modified-files>` (specific files) vs `git add -A`
- Has a "Final Verification Stage (MANDATORY)" that is domain-specific (sorry_count, axiom_count, build)
- The handoff protocol is in "Context Management" section, not "Stage 4E"

**Insertion strategy for lean agent**:
- **4B-ii Step 4**: The lean agent has no 4B-ii section at all. The deviation annotation step should be added as a new note in the "Phase Status Updates" section, after the existing "After Completing a Phase" block (after line 88), as a brief mention: "If a step is deviated from (skipped/altered/deferred), annotate the plan checklist item inline per `.claude/context/formats/progress-file.md`."
- **4D-ii Post-Phase Self-Review**: Add after the "Phase Checkpoint Protocol step 3" block (line 333), before step 4 (git commit). The lean agent's self-review needs to account for Lean-specific items (no unchecked tactics, sorries not introduced).
- **4D-iii Progressive Handoff Update**: Add after 4D-ii, before the git commit step in Phase Checkpoint Protocol. Use the same condensed template but note the lean agent already has a fuller handoff protocol in "Context Management."
- **4E Step 1.5**: The lean agent's handoff protocol is in "Context Management / Handoff Protocol" (lines 364–373). Step 1.5 should be inserted between "Write progress file" (step 1) and "Write handoff document" (step 2).
- **Stage 6 `## Plan Deviations`**: The lean agent has no Stage 6 summary template visible in the file — the summary creation is implicit. No inline template to update. The implementer will write to `summaries/` per convention. Given the minimal nature of Stage 6 in this agent, add a brief note that the summary should include `## Plan Deviations` populated from the progress file.
- **Phase Checkpoint Protocol step 4**: Currently step 4 is the git commit. Step 4 should become "Perform post-phase self-review (4D-ii) and write progressive handoff (4D-iii)" and step 5 becomes the git commit.

---

### Agent 3: `extensions/nix/agents/nix-implementation-agent.md` (Type B)

**Structure**: Full implementation loop. Stage 4 has steps A through E (Mark In Progress, Check MCP, Execute Steps, Verify Phase, Mark Complete). Has explicit Stage 6 template.

**Missing insertions**:
- Stage 4 Step C sub-item 4: Add deviation annotation step (currently step 4 is "Verify changes: Run `nix flake check`"). The deviation step should be listed as step 4 and `nix flake check` moved to step 5 (or kept as its own `**Verify changes**` block).
- After Stage 4 step E (Mark Phase Complete): Add `#### 4D-ii. Post-Phase Self-Review` and `#### 4D-iii. Progressive Handoff Update`.
- The nix agent has no Stage 4E handoff section at all. Add a new `#### 4E. Handoff on Context Pressure` section adapted from the general agent.
- Stage 6 template: Replace `## Changes Made` / `## Files Modified` with the updated template that includes `## What Changed`, `## Decisions`, and `## Plan Deviations`.
- No Phase Checkpoint Protocol section. Add one (or note that the Phase Checkpoint Protocol from the general agent applies).

**Nix-specific adaptation**: The deviation annotation notes should reference `nix flake check` as verification that deferred steps won't break the configuration.

---

### Agent 4: `extensions/nvim/agents/neovim-implementation-agent.md` (Type B)

**Structure**: Full loop. Stage 4 has A (Mark In Progress), B (Execute Steps with 3 sub-items), C (Verify Phase), D (Mark Complete). Has Stage 6 template.

**Missing insertions**:
- Stage 4B Step 3 is "Verify changes: Test module loading with nvim --headless". Add Step 4 (deviation annotation) after step 3.
- After Stage 4D (Mark Phase Complete): Add 4D-ii and 4D-iii sections.
- No Stage 4E handoff section. Add it (adapted from general agent, replacing build commands with `nvim --headless` verification).
- Stage 6 template: Upgrade from `## Changes Made` / `## Files Modified` to the updated format with `## What Changed`, `## Decisions`, `## Plan Deviations`.
- No Phase Checkpoint Protocol section. Add one.

**Note**: This agent is essentially identical to `.claude/agents/neovim-implementation-agent.md` (agent 10). Both files need the same edits.

---

### Agent 5: `extensions/latex/agents/latex-implementation-agent.md` (Type C)

**Structure**: Thin wrapper. Stage 4 has A/B/C/D/E steps but each is 1-3 lines with no sub-items. Stage 6 says "Write to `specs/.../summaries/`" with no template body. No Stage 4E handoff section.

**Minimal changes needed**:
- **4B-ii Step 4**: Not applicable — no checklist sub-items to annotate. Skip.
- **4D-ii Post-Phase Self-Review**: Could add a brief 1-sentence note after step D: "After marking a phase COMPLETED, review any unchecked plan items and record deviations in the progress file."
- **4D-iii Progressive Handoff Update**: Could add a 1-sentence note: "At phase end, write a condensed handoff to `specs/.../handoffs/phase-{P}-handoff-{TIMESTAMP}.md`."
- **4E Step 1.5**: The thin agent has no Stage 4E section; skip or add a brief note about plan annotation before handoff.
- **Stage 6 `## Plan Deviations`**: The Stage 6 entry just says "Write to `specs/.../summaries/`" with no template. Since summary-format.md is the authoritative template, the best approach is to add a note: "Include `## Plan Deviations` section in summary (see general agent for format)."

**Recommendation**: Apply only the `## Plan Deviations` mention and a brief 1-sentence note for 4D-ii and 4D-iii. Full protocol insertion is out of proportion for a thin agent.

---

### Agent 6: `extensions/python/agents/python-implementation-agent.md` (Type C)

**Structure**: Thin wrapper. Stage 4 has A/B/C/D/E (D = Mark Complete, E = Git Commit). Each step is 1-3 lines. No Stage 6 template. Similar to latex agent.

**Minimal changes needed**: Same as latex agent — brief 1-sentence notes for 4D-ii/4D-iii, `## Plan Deviations` mention in Stage 6.

---

### Agent 7: `extensions/typst/agents/typst-implementation-agent.md` (Type C)

**Structure**: Thin wrapper. Essentially the same structure as latex. Stage 4 has A/B/C/D/E with E as git commit. Stage 6 delegated.

**Minimal changes needed**: Same as latex/python.

---

### Agent 8: `extensions/web/agents/web-implementation-agent.md` (Type B)

**Structure**: Full loop with rich domain content. Stage 4 has A (Mark In Progress), B (Execute Steps with 4 sub-items including build verification), C (Verify Phase), D (Mark Complete). Has extensive Stage 6 template with `## Changes Made` / `## Files Modified`.

**Missing insertions**:
- Stage 4B Step 4 is "Handle build errors (if any)". Add Step 5 as deviation annotation (or restructure as a new named step after step 4). Alternatively, add Step 4 before the existing step 3 (build verification).
- After Stage 4D: Add 4D-ii and 4D-iii sections.
- The web agent has a `### Timeout/Interruption` section in Error Handling but no Stage 4E inline handoff. Add Stage 4E section.
- Stage 6 template: Upgrade to include `## What Changed`, `## Decisions`, `## Plan Deviations`.
- No Phase Checkpoint Protocol section. Add one.

**Web-specific adaptation**: Deviation annotation should note that deferred tasks affecting TypeScript types or build require `pnpm check` before proceeding.

---

### Agent 9: `extensions/z3/agents/z3-implementation-agent.md` (Type C)

**Structure**: Thin wrapper. Stage 4 has A/B/C/D (no separate verify step — B is execute+test). No Stage 6 template. No handoff protocol.

**Minimal changes needed**: Same as python/typst/latex.

---

### Agent 10: `.claude/agents/neovim-implementation-agent.md` (Type B)

**Structure**: Identical to `extensions/nvim/agents/neovim-implementation-agent.md` (agent 4). Same Stage 4 structure, same Stage 6 template, same missing sections.

**Insertion points**: Identical to agent 4. These two files should receive the exact same edits.

---

### Agent 11: `.claude/agents/nix-implementation-agent.md` (Type B)

**Structure**: Identical to `extensions/nix/agents/nix-implementation-agent.md` (agent 3). Same Stage 4 structure, same Stage 6 template, same missing sections.

**Insertion points**: Identical to agent 3. These two files should receive the exact same edits.

---

## Summary: What Each Agent Is Missing

| Change from Task 569 | Agent 1 (A) | Agents 3,4,8,10,11 (B-full) | Agent 2 (B-lean) | Agents 5,6,7,9 (C-thin) |
|---------------------|-------------|------------------------------|------------------|--------------------------|
| 4B-ii Step 4: deviation annotation | Missing | Missing | Needs adapted form | N/A (no sub-items) |
| 4D-ii: Post-phase self-review | Missing | Missing | Needs adapted form | 1-sentence note |
| 4D-iii: Progressive handoff | Missing | Missing | Needs adapted form | 1-sentence note |
| 4E Step 1.5: plan annotation before handoff | Missing | Missing (no 4E section) | Needs adapted form | N/A |
| Stage 6: `## Plan Deviations` section | Missing | Missing | Missing (no template) | Add mention |
| Phase Checkpoint Protocol step 4 | Stale (no 4D-ii/4D-iii ref) | Missing (no section) | Step numbering shift | N/A |

---

## Grouping Recommendation

### Group 1: Core Copy (1 agent) — Identical update to main agent
- `extensions/core/agents/general-implementation-agent.md`
- **Action**: Apply the same diffs from task 569 verbatim (copy from `.claude/agents/general-implementation-agent.md`).

### Group 2: Paired domain mirrors (2 pairs — 4 agents) — Same edits within each pair
- **Nix pair**: `extensions/nix/` + `.claude/agents/nix-implementation-agent.md` (identical files)
- **Neovim pair**: `extensions/nvim/` + `.claude/agents/neovim-implementation-agent.md` (identical files)
- **Action**: Apply the same edits to both files in each pair simultaneously.

### Group 3: Web agent (1 agent) — Full agent, standalone
- `extensions/web/agents/web-implementation-agent.md`
- **Action**: Similar to nix/neovim but with web-specific build references in deviation notes.

### Group 4: Lean agent (1 agent) — Full agent, unique structure
- `extensions/lean/agents/lean-implementation-agent.md`
- **Action**: Adapted insertions respecting the lean agent's unique structure (no progress file tracking, no Stage 4B-ii section, escalation protocol).

### Group 5: Thin wrappers (4 agents) — Minimal changes
- `extensions/latex/agents/latex-implementation-agent.md`
- `extensions/python/agents/python-implementation-agent.md`
- `extensions/typst/agents/typst-implementation-agent.md`
- `extensions/z3/agents/z3-implementation-agent.md`
- **Action**: Add `## Plan Deviations` mention to Stage 6, add 1-sentence 4D-ii and 4D-iii notes after the Mark Complete step.

---

## Implementation Strategy

### Recommended Order

**Phase 1 — Core Copy (Group 1)**
Update `extensions/core/agents/general-implementation-agent.md` first. This is a verbatim copy; the simplest change and a good smoke test that the diff applies cleanly.

**Phase 2 — Paired Mirrors (Group 2, both pairs)**
Update the two nix files together, then the two neovim files together. Within each pair the files are identical so the same edits can be applied to both with a single review. This handles 4 agents efficiently.

**Phase 3 — Web Agent (Group 3)**
Update `extensions/web/agents/web-implementation-agent.md`. This is the most feature-rich Type B agent; updating it separately allows domain-specific adaptation (pnpm build references in handoff notes).

**Phase 4 — Lean Agent (Group 4)**
Update `extensions/lean/agents/lean-implementation-agent.md` last among the full agents. Its unique structure (no progress files, escalation protocol, different handoff section location) requires the most careful adaptation.

**Phase 5 — Thin Wrappers (Group 5)**
Update all four thin wrappers together. The changes are uniform and minimal; all four can be done in a single phase with a consistent pattern.

### Total Files: 11
- Phase 1: 1 file
- Phase 2: 4 files (2 pairs)
- Phase 3: 1 file
- Phase 4: 1 file
- Phase 5: 4 files

### Key Decision: Scope for Thin Wrappers
For the Type C agents (latex, python, typst, z3), the full 4D-ii/4D-iii/4E-1.5 protocol is disproportionate to the current agent size. The recommendation is:
1. Add a 1-sentence post-phase self-review note after the Mark Complete step ("After marking COMPLETED, review unchecked plan items and record any deviations.")
2. Add a 1-sentence progressive handoff note ("Write a condensed phase-end handoff to `specs/.../handoffs/` after each phase completion.")
3. Add `## Plan Deviations` to Stage 6 or note its inclusion requirement.

This keeps thin agents thin while establishing the behavioral contract. If any thin agent is later expanded into a full agent, the full protocol can be inserted at that time.

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Lean agent's unique structure makes verbatim insertion incorrect | Use adapted insertion that respects lean-specific sections; add deviation note to "Phase Status Updates" rather than non-existent 4B-ii |
| Nix/neovim pairs diverging after this task | Apply identical edits to both files in each pair; verify with diff after |
| Summary template format conflicts (old vs new) | Full B agents get the complete updated template (what changed + decisions + plan deviations); thin C agents get only a mention |
| Missing Phase Checkpoint Protocol in most agents | Add the Protocol section to Type B agents (nix, neovim, web) since they lack it entirely; the lean agent has a similar section already |

---

## Context Extension Recommendations

- None for this meta task (documentation of agent parity patterns belongs in task implementation summaries, not context files).
