# Implementation Plan: Task #617

- **Task**: 617 - lean_lsp_first_verification
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/617_lean_lsp_first_verification/reports/01_lsp-first-verification.md
- **Artifacts**: plans/01_lsp-first-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update three lean extension files to implement an LSP-first verification policy. The current policy conflates per-step, phase-end, and final verification tiers, causing agents to run slow full `lake build` commands after every tactic application. The fix introduces a three-tier cadence: per-step uses `lean_goal` + `lean_verify`, phase-end uses scoped `lake build Module.Name`, and final verification uses full `lake build`. Additionally, `lean_verify` (currently undocumented) is added to tool tables, and `lean_multi_attempt` is explicitly positioned as a pre-edit trial step.

### Research Integration

The research report (01_lsp-first-verification.md) provides 8 specific proposed changes (A-H) with exact before/after text for all 3 files. Key findings:

- `lean_verify` is confirmed present in the lean-lsp MCP server but completely absent from all three extension files
- The main antipattern is per-step `lake build` calls; `lean_goal` + `lean_verify` are the correct per-step tools
- `lean_multi_attempt` is documented but not positioned as pre-edit trial
- Build command guidance lacks when-to-use scoped vs full build

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Add `lean_verify` to Essential MCP Tools table (lean4.md) and Allowed Tools (lean-implementation-agent.md)
- Replace per-step `lake build` with `lean_goal` + `lean_verify` across all three files
- Position `lean_multi_attempt` explicitly as a pre-edit trial step
- Establish `lake build Module.Name` as preferred phase-end verification, with full `lake build` reserved for final verification only
- Rewrite Workflow Pattern and Build Commands sections to encode the three-tier verification cadence

**Non-Goals**:
- Modifying any Lean source code or proofs
- Changing the lean-lsp MCP server itself
- Altering blocked tools policy (lean_diagnostic_messages, lean_file_outline remain blocked)
- Changing search tool documentation or rate limits

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent ignores new MUST DO items because list is long | L | L | New items follow existing lean_goal item at positions 5-8; clear grouping |
| lean_verify unavailable in some environments | M | L | Tool confirmed present in lean-lsp MCP server system reminder |
| Phase-end scoped build misses cross-module errors | M | M | 4C clause: fall back to full `lake build` if module name unknown or spans multiple modules |
| Renumbering MUST DO items 6-12 breaks agent behavior | L | L | MUST DO is human-readable checklist; renumbering is semantic-neutral |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Update lean4.md rules [COMPLETED]

**Goal**: Add `lean_verify` and `lean_multi_attempt` to the Essential MCP Tools table, rewrite the Workflow Pattern to encode the three-tier verification cadence, and rewrite Build Commands with when-to-use guidance.

**Tasks**:
- [x] **Change A**: Add `lean_verify` and `lean_multi_attempt` rows to the Essential MCP Tools table (after `lean_local_search` row) *(completed)*
  - old_string:
    ```
    | `lean_local_search` | Fast local declaration search |
    ```
  - new_string:
    ```
    | `lean_local_search` | Fast local declaration search |
    | `lean_verify` | Axiom check + source scan (use fully qualified name) |
    | `lean_multi_attempt` | Test tactics without editing - use BEFORE applying edits |
    ```

- [x] **Change B**: Rewrite Workflow Pattern and Build Commands sections *(completed)*
  - old_string:
    ```
    ## Workflow Pattern

    1. After finding name: `lean_local_search` -> verify, `lean_hover_info` -> signature
    2. During proof: `lean_goal` constantly, `lean_multi_attempt` test tactics, `lake build`
    3. After editing: `lake build`, `lean_goal`
    ```
  - new_string:
    ```
    ## Workflow Pattern

    1. After finding name: `lean_local_search` -> verify, `lean_hover_info` -> signature
    2. During proof (inner loop): `lean_goal` constantly; `lean_multi_attempt` BEFORE editing; `lean_verify` for axiom/sorry check
    3. After editing a step: `lean_goal` to confirm; `lean_verify` if axiom safety needed
    4. Phase-end: `lake build Module.Name` (scoped); fall back to `lake build` if module name unknown
    5. Final verification only: `lake build` (full project)
    ```

- [x] **Change B (continued)**: Rewrite Build Commands section with when-to-use guidance *(completed)*
  - old_string:
    ```
    ## Build Commands

    `lake build` | `lake build Module.Name` | `lake clean && lake build`
    ```
  - new_string:
    ```
    ## Build Commands

    Prefer scoped: `lake build Module.Name` | Full project: `lake build` | Clean: `lake clean && lake build`

    **When to use each**:
    - `lake build Module.Name` -- phase-end verification (preferred; faster)
    - `lake build` -- final verification only (after all phases complete)
    ```

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/lean/rules/lean4.md` - Add tool rows, rewrite workflow and build sections

**Verification**:
- `lean_verify` appears in the Essential MCP Tools table
- `lean_multi_attempt` appears in the Essential MCP Tools table with "BEFORE" positioning
- Workflow Pattern has 5 steps encoding three-tier cadence
- Build Commands section has when-to-use guidance

---

### Phase 2: Update lean-implementation-agent.md [COMPLETED]

**Goal**: Add `lean_verify` to the Allowed Tools table, update `lean_multi_attempt` description, and rewrite Critical Requirements MUST DO/MUST NOT items to encode the three-tier verification cadence.

**Tasks**:
- [x] **Change C**: Add `lean_verify` to Core Tools list and update `lean_multi_attempt` description *(completed)*
  - old_string:
    ```
    - `mcp__lean-lsp__lean_multi_attempt` - Try multiple tactics without editing file
    - `mcp__lean-lsp__lean_local_search` - Fast local declaration search (verify lemmas exist)
    ```
  - new_string:
    ```
    - `mcp__lean-lsp__lean_multi_attempt` - Test tactics without editing (use BEFORE applying edits)
    - `mcp__lean-lsp__lean_local_search` - Fast local declaration search (verify lemmas exist)
    - `mcp__lean-lsp__lean_verify` - Axiom check + source scan; use fully qualified name e.g. `Ns.thm`
    ```

- [x] **Change D (MUST DO)**: Replace MUST DO item 5 with items 5-8 encoding the three-tier cadence *(completed)*
  - old_string:
    ```
    4. Always use `lean_goal` before and after each tactic application
    5. Always run `lake build` before returning implemented status
    6. Always verify proofs are actually complete ("no goals")
    ```
  - new_string:
    ```
    4. Always use `lean_goal` before and after each tactic application
    5. Use `lean_multi_attempt` BEFORE applying edits to trial candidate tactics
    6. Use `lean_verify` for axiom/sorry checks at the per-step level
    7. Prefer `lake build Module.Name` for phase-end verification (scoped, faster)
    8. Always run full `lake build` before returning implemented status (final verification only)
    9. Always verify proofs are actually complete ("no goals")
    ```

- [x] **Change D (MUST DO continued)**: Renumber remaining MUST DO items 7-12 to 10-15 *(completed)*
  - Renumber items sequentially after the new items 5-9

- [x] **Change D (MUST NOT)**: Update MUST NOT item 3 to narrow scope *(completed)*
  - old_string:
    ```
    3. Skip `lake build` verification
    ```
  - new_string:
    ```
    3. Skip final `lake build` verification (scoped `lake build Module.Name` is acceptable for phase-end; only full `lake build` is mandatory at the final stage)
    ```

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/lean/agents/lean-implementation-agent.md` - Add lean_verify tool, update multi_attempt description, rewrite critical requirements

**Verification**:
- `lean_verify` appears in Core Tools (No Rate Limit) list
- `lean_multi_attempt` description includes "BEFORE applying edits"
- MUST DO items 5-8 encode: multi_attempt before editing, lean_verify per-step, scoped build phase-end, full build final only
- MUST NOT item 3 specifies "final lake build" not all lake build
- All MUST DO items are renumbered correctly (no gaps, no duplicates)

---

### Phase 3: Update lean-implementation-flow.md [COMPLETED]

**Goal**: Replace per-step `lake build` with LSP tools in Stage 4B, position `lean_multi_attempt` as pre-edit trial in the inner loop, update Stage 4C to use scoped build, and add clarifying note to Stage 5.

**Tasks**:
- [x] **Change F**: Update Stage 4B inner loop to explicitly position lean_multi_attempt and add post-edit verification step *(completed)*
  - old_string:
    ```
       REPEAT until goals closed or stuck:
         a. Use lean_goal to see current state
         b. Use lean_multi_attempt to try candidate tactics
         c. If promising tactic found, apply via Edit
         d. If stuck, use lean_state_search, lean_hammer_premise
         e. If still stuck, log state and return partial
    ```
  - new_string:
    ```
       REPEAT until goals closed or stuck:
         a. Use lean_goal to see current state
         b. Use lean_multi_attempt to trial candidate tactics WITHOUT editing (pre-edit trial)
         c. If promising tactic found, apply via Edit
         d. After editing, use lean_goal to confirm goal progress; use lean_verify for axiom/sorry check
         e. If stuck, use lean_state_search, lean_hammer_premise
         f. If still stuck, log state and return partial
    ```

- [x] **Change E**: Update Stage 4B step 5 to remove lake build from per-step verification *(completed)*
  - old_string:
    ```
    5. **Verify step completion** with `lean_goal` and `lake build`
    ```
  - new_string:
    ```
    5. **Verify step completion** with `lean_goal` (proof state) and `lean_verify` (axiom/sorry check); do NOT run `lake build` per-step
    ```

- [x] **Change G**: Update Stage 4C to use scoped build *(completed)*
  - old_string:
    ```
    ### 4C. Verify Phase Completion

    - Run `lake build` to verify full project builds
    - Check verification criteria from plan
    ```
  - new_string:
    ```
    ### 4C. Verify Phase Completion

    - Run `lake build Module.Name` to verify the module compiles (preferred; faster than full build)
    - Fall back to `lake build` only if the module name is unknown or the phase spans multiple modules
    - Check verification criteria from plan
    ```

- [x] **Change H**: Update Stage 5 with clarifying note *(completed)*
  - old_string:
    ```
    ## Stage 5: Run Final Build Verification

    After all phases complete:
    ```bash
    lake build
    ```
    ```
  - new_string:
    ```
    ## Stage 5: Run Final Build Verification

    After all phases complete, run the full project build (mandatory -- this is the only required full build):
    ```bash
    lake build
    ```

    Note: Per-step verification uses `lean_goal` + `lean_verify`. Phase-end uses `lake build Module.Name`. Only this final stage requires full `lake build`.
    ```

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` - Update stages 4B, 4C, and 5

**Verification**:
- Stage 4B inner loop step b says "WITHOUT editing (pre-edit trial)"
- Stage 4B inner loop has new step d for post-edit verification with lean_goal + lean_verify
- Stage 4B step 5 uses lean_goal + lean_verify, explicitly says "do NOT run lake build per-step"
- Stage 4C uses `lake build Module.Name` as primary, with fallback clause
- Stage 5 has clarifying note about three-tier cadence

## Testing & Validation

- [ ] All three files parse correctly as valid Markdown
- [ ] `lean_verify` appears in both lean4.md Essential MCP Tools table and lean-implementation-agent.md Core Tools list
- [ ] No remaining references to per-step `lake build` in any of the three files (except in blocked tools context and the "do NOT" admonition)
- [ ] The three-tier cadence (per-step: lean_goal+lean_verify, phase-end: scoped build, final: full build) is consistently described across all three files
- [ ] MUST DO items in lean-implementation-agent.md are numbered sequentially without gaps
- [ ] `lean_multi_attempt` is described as pre-edit trial in all three files

## Artifacts & Outputs

- `specs/617_lean_lsp_first_verification/plans/01_lsp-first-plan.md` (this file)
- `.claude/extensions/lean/rules/lean4.md` (modified)
- `.claude/extensions/lean/agents/lean-implementation-agent.md` (modified)
- `.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` (modified)

## Rollback/Contingency

All three files are under git version control. If changes cause agent behavior regressions, revert with:
```bash
git checkout HEAD -- .claude/extensions/lean/rules/lean4.md .claude/extensions/lean/agents/lean-implementation-agent.md .claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md
```
