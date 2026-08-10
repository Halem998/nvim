# Research Report: Task #617

**Task**: 617 - lean_lsp_first_verification
**Started**: 2026-05-25T00:00:00Z
**Completed**: 2026-05-25T00:00:00Z
**Effort**: ~30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase (three lean extension files), lean-lsp MCP server system reminder
**Artifacts**: specs/617_lean_lsp_first_verification/reports/01_lsp-first-verification.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- Three lean extension files need targeted edits to implement the LSP-first verification policy
- `lean_verify` is completely absent from all three files and must be added to the agent's Allowed Tools table and to the rules Essential MCP Tools table
- The main workflow antipattern is per-step `lake build` calls; these should be replaced by `lean_goal` (already mentioned but not enforced as primary) and `lean_verify` for axiom/sorry checks
- `lean_multi_attempt` is already documented but not positioned explicitly as a pre-edit trial step; the flow document needs a clear placement rule
- Build command guidance should be promoted from `lake build` (full project) to `lake build Module.Name` (scoped) as the preferred per-step form, with full `lake build` reserved for phase-end and final verification
- Changes are low-risk: they clarify and tighten an already-sensible toolchain without removing any existing capability

---

## Context & Scope

The lean extension governs how the `lean-implementation-agent` verifies proof progress during development. The current policy conflates two different verification cadences:

1. **Per-step verification** (after each tactic application): currently says "lean_goal and lake build" -- lake build is slow and full-project; lean_goal alone plus lean_verify are the right tools here.
2. **Phase-end verification** (after all steps in a phase): appropriate for a scoped `lake build Module.Name`.
3. **Final verification** (after all phases): appropriate for full `lake build`.

The task is to encode this three-tier cadence clearly across the three files.

---

## Findings

### File 1: `.claude/extensions/lean/rules/lean4.md`

**Current state (lines 40-54)**:

```markdown
## Workflow Pattern

1. After finding name: `lean_local_search` -> verify, `lean_hover_info` -> signature
2. During proof: `lean_goal` constantly, `lean_multi_attempt` test tactics, `lake build`
3. After editing: `lake build`, `lean_goal`

## Build Commands

`lake build` | `lake build Module.Name` | `lake clean && lake build`
```

**Gaps**:
- `lean_verify` is not listed in the Essential MCP Tools table (lines 14-20)
- Workflow Pattern line 2 lists `lake build` as part of the inner proof loop -- this is the slow full build being called per-tactic, which is wrong
- Workflow Pattern line 3 has `lake build` before `lean_goal` -- the order implies lake build is the primary per-step check; it should be the other way around
- Build Commands line shows `lake build` first with no guidance on when to prefer the scoped form
- `lean_multi_attempt` appears in line 43 but without explicit "test before editing" framing

**What needs to change**:
- Add `lean_verify` to the Essential MCP Tools table with its purpose ("axiom check + source scan")
- Rewrite Workflow Pattern to encode the three tiers: inner loop = lean_goal + lean_multi_attempt (pre-edit) + lean_verify; phase-end = lake build Module.Name; final = lake build
- In Build Commands section, reorder to show scoped form first and add when-to-use guidance

---

### File 2: `.claude/extensions/lean/agents/lean-implementation-agent.md`

**Current state**:

**Allowed Tools -- Lean MCP Tools section (lines 50-61)**:
```markdown
**Core Tools (No Rate Limit)**:
- `mcp__lean-lsp__lean_goal` - Proof state at position (MOST IMPORTANT - use constantly!)
- `mcp__lean-lsp__lean_hover_info` - Type signature and docs for symbols
- `mcp__lean-lsp__lean_completions` - IDE autocompletions
- `mcp__lean-lsp__lean_multi_attempt` - Try multiple tactics without editing file
- `mcp__lean-lsp__lean_local_search` - Fast local declaration search (verify lemmas exist)
- `mcp__lean-lsp__lean_term_goal` - Expected type at position
- `mcp__lean-lsp__lean_declaration_file` - Get file where symbol is declared
- `mcp__lean-lsp__lean_run_code` - Run standalone snippet
- `mcp__lean-lsp__lean_build` - Build project and restart LSP (SLOW - use sparingly)
```

**lean_verify is absent**. The tool `mcp__lean-lsp__lean_verify` does not appear anywhere in the file.

**Critical Requirements section (lines 393-419)**:
```markdown
**MUST DO**:
...
4. Always use `lean_goal` before and after each tactic application
5. Always run `lake build` before returning implemented status
...
**MUST NOT**:
...
3. Skip `lake build` verification
```

Point 5 (MUST DO) and point 3 (MUST NOT) enforce `lake build` for every verification. This is fine for final verification but over-broad: per-step verification should use lean-lsp tools, not lake build.

**Gaps**:
- `lean_verify` missing from Allowed Tools
- No description of `lean_multi_attempt` as pre-edit trial (just "Try multiple tactics without editing file" with no workflow positioning)
- "Always run `lake build` before returning implemented status" is correct but conflated with per-step verification
- No guidance that scoped `lake build Module.Name` should be preferred for per-step/phase checks over full `lake build`

**What needs to change**:
- Add `mcp__lean-lsp__lean_verify` to the Core Tools (No Rate Limit) table with description "Axiom check + source scan. Use fully qualified name (e.g., Ns.thm)"
- Add description clarifying `lean_multi_attempt` should be used BEFORE editing to trial tactics
- In Critical Requirements MUST DO: replace "Always run `lake build` before returning implemented status" with two-part requirement: prefer `lake build Module.Name` for per-step/phase verification; reserve full `lake build` for final verification
- In Critical Requirements MUST NOT: narrow point 3 to clarify it means "don't skip final lake build" not "must lake build after every tactic"

---

### File 3: `.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`

**Current state**:

**Stage 4B, step 5 (line 106)**:
```markdown
5. **Verify step completion** with `lean_goal` and `lake build`
```

**Stage 4C (lines 109-111)**:
```markdown
### 4C. Verify Phase Completion

- Run `lake build` to verify full project builds
- Check verification criteria from plan
```

**Stage 5 (lines 120-124)**:
```markdown
## Stage 5: Run Final Build Verification

After all phases complete:
```bash
lake build
```
```

**Gaps**:
- Stage 4B step 5: `lake build` is inappropriate at the per-step level; should be `lean_goal` + optionally `lean_verify` for axiom/sorry check
- Stage 4C: bare `lake build` is the right category here (phase-end) but should be the scoped `lake build Module.Name` form with fallback to full build if module name unknown
- Stage 5 is correct (full `lake build` at final stage) but the prose in stage 4B and 4C create confusion about when each level of build is appropriate
- `lean_multi_attempt` appears in the inner loop (step 4B.4.b) correctly, but its pre-edit trial role is not named explicitly

**What needs to change**:
- Stage 4B step 5: change to use `lean_goal` (primary) + `lean_verify` (axiom check) only; remove `lake build` from per-step verification
- Stage 4B step 4 (inner loop): explicitly name `lean_multi_attempt` as "pre-edit trial" step
- Stage 4C: change to `lake build Module.Name` as preferred form, with note to fall back to `lake build` if module name is unavailable
- Stage 5: keep as-is (full `lake build`) but add a clarifying note that this is the only mandatory full-project build

---

## lean-lsp MCP Tool Verification (from system reminder)

From the MCP server instructions available at runtime, the following is confirmed:

| Tool | Description |
|------|-------------|
| `lean_verify` | "Axiom check + source scan. Use fully qualified name (e.g. `Ns.thm`)." |
| `lean_multi_attempt` | "Test tactics without editing at a proof position. Use `column` for exact source position; omit it for fast line-based REPL attempts." |
| `lean_goal` | "Proof state at position. Omit `column` for before/after. 'no goals' = done!" |
| `lean_build` | "Rebuild + restart LSP. Only if needed (new imports). SLOW!" |

Note: `lean_build` (the MCP tool) is distinct from `lake build` (the shell command). The MCP tool is for LSP restart; the shell command is for build verification. This distinction is already correctly maintained in the agent file.

Performance characteristics:
- `lean_goal`: Instant (LSP query)
- `lean_verify`: Fast (axiom/sorry scan, no compilation)
- `lean_multi_attempt`: Fast (REPL-based, no file edit needed)
- `lake build Module.Name`: Moderate (scoped compilation)
- `lake build`: Slow (full project compilation)

---

## Decisions

- The "per-step verification" tier should use `lean_goal` + `lean_verify`; NOT `lake build`
- The "phase-end verification" tier should use `lake build Module.Name`; fall back to `lake build` only if module name is not known
- The "final verification" tier uses `lake build` (full project) -- this is the only mandatory full build
- `lean_multi_attempt` should be explicitly labeled as the pre-edit trial step in the inner loop description
- `lean_verify` must be added to both the rules file's Essential MCP Tools table and the agent's Allowed Tools table

---

## Proposed Changes (Exact Sections)

### Change A: lean4.md -- Add lean_verify to Essential MCP Tools table

**File**: `.claude/extensions/lean/rules/lean4.md` (lines 14-20)

**Current**:
```markdown
## Essential MCP Tools

| Tool | Purpose |
|------|---------|
| `lean_goal` | Proof state at position - MOST IMPORTANT |
| `lean_hover_info` | Type signatures + docs |
| `lean_completions` | IDE autocomplete |
| `lean_local_search` | Fast local declaration search |
```

**Proposed**:
```markdown
## Essential MCP Tools

| Tool | Purpose |
|------|---------|
| `lean_goal` | Proof state at position - MOST IMPORTANT |
| `lean_hover_info` | Type signatures + docs |
| `lean_completions` | IDE autocomplete |
| `lean_local_search` | Fast local declaration search |
| `lean_verify` | Axiom check + source scan (use fully qualified name) |
| `lean_multi_attempt` | Test tactics without editing - use BEFORE applying edits |
```

---

### Change B: lean4.md -- Rewrite Workflow Pattern and Build Commands

**File**: `.claude/extensions/lean/rules/lean4.md` (lines 40-54)

**Current**:
```markdown
## Workflow Pattern

1. After finding name: `lean_local_search` -> verify, `lean_hover_info` -> signature
2. During proof: `lean_goal` constantly, `lean_multi_attempt` test tactics, `lake build`
3. After editing: `lake build`, `lean_goal`

## Build Commands

`lake build` | `lake build Module.Name` | `lake clean && lake build`
```

**Proposed**:
```markdown
## Workflow Pattern

1. After finding name: `lean_local_search` -> verify, `lean_hover_info` -> signature
2. During proof (inner loop): `lean_goal` constantly; `lean_multi_attempt` BEFORE editing; `lean_verify` for axiom/sorry check
3. After editing a step: `lean_goal` to confirm; `lean_verify` if axiom safety needed
4. Phase-end: `lake build Module.Name` (scoped); fall back to `lake build` if module name unknown
5. Final verification only: `lake build` (full project)

## Build Commands

Prefer scoped: `lake build Module.Name` | Full project: `lake build` | Clean: `lake clean && lake build`

**When to use each**:
- `lake build Module.Name` -- phase-end verification (preferred; faster)
- `lake build` -- final verification only (after all phases complete)
```

---

### Change C: lean-implementation-agent.md -- Add lean_verify to Allowed Tools

**File**: `.claude/extensions/lean/agents/lean-implementation-agent.md` (lines 50-61)

**Current**:
```markdown
**Core Tools (No Rate Limit)**:
- `mcp__lean-lsp__lean_goal` - Proof state at position (MOST IMPORTANT - use constantly!)
- `mcp__lean-lsp__lean_hover_info` - Type signature and docs for symbols
- `mcp__lean-lsp__lean_completions` - IDE autocompletions
- `mcp__lean-lsp__lean_multi_attempt` - Try multiple tactics without editing file
- `mcp__lean-lsp__lean_local_search` - Fast local declaration search (verify lemmas exist)
- `mcp__lean-lsp__lean_term_goal` - Expected type at position
- `mcp__lean-lsp__lean_declaration_file` - Get file where symbol is declared
- `mcp__lean-lsp__lean_run_code` - Run standalone snippet
- `mcp__lean-lsp__lean_build` - Build project and restart LSP (SLOW - use sparingly)
```

**Proposed**:
```markdown
**Core Tools (No Rate Limit)**:
- `mcp__lean-lsp__lean_goal` - Proof state at position (MOST IMPORTANT - use constantly!)
- `mcp__lean-lsp__lean_hover_info` - Type signature and docs for symbols
- `mcp__lean-lsp__lean_completions` - IDE autocompletions
- `mcp__lean-lsp__lean_multi_attempt` - Test tactics without editing (use BEFORE applying edits)
- `mcp__lean-lsp__lean_local_search` - Fast local declaration search (verify lemmas exist)
- `mcp__lean-lsp__lean_verify` - Axiom check + source scan; use fully qualified name e.g. `Ns.thm`
- `mcp__lean-lsp__lean_term_goal` - Expected type at position
- `mcp__lean-lsp__lean_declaration_file` - Get file where symbol is declared
- `mcp__lean-lsp__lean_run_code` - Run standalone snippet
- `mcp__lean-lsp__lean_build` - Build project and restart LSP (SLOW - use sparingly)
```

---

### Change D: lean-implementation-agent.md -- Update Critical Requirements

**File**: `.claude/extensions/lean/agents/lean-implementation-agent.md` (lines 393-419)

**Current MUST DO items 4-5**:
```markdown
4. Always use `lean_goal` before and after each tactic application
5. Always run `lake build` before returning implemented status
```

**Proposed MUST DO items 4-5 (replace)**:
```markdown
4. Always use `lean_goal` before and after each tactic application
5. Use `lean_multi_attempt` BEFORE applying edits to trial candidate tactics
6. Use `lean_verify` for axiom/sorry checks at the per-step level
7. Prefer `lake build Module.Name` for phase-end verification (scoped, faster)
8. Always run full `lake build` before returning implemented status (final verification only)
```

Note: existing items 6-12 shift by 3 in numbering.

**Current MUST NOT item 3**:
```markdown
3. Skip `lake build` verification
```

**Proposed MUST NOT item 3 (replace)**:
```markdown
3. Skip final `lake build` verification (scoped `lake build Module.Name` is acceptable for phase-end; only full `lake build` is mandatory at the final stage)
```

---

### Change E: lean-implementation-flow.md -- Update Stage 4B step 5

**File**: `.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` (line 106)

**Current**:
```markdown
5. **Verify step completion** with `lean_goal` and `lake build`
```

**Proposed**:
```markdown
5. **Verify step completion** with `lean_goal` (proof state) and `lean_verify` (axiom/sorry check); do NOT run `lake build` per-step
```

---

### Change F: lean-implementation-flow.md -- Update Stage 4B inner loop (lean_multi_attempt positioning)

**File**: `.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` (lines 99-105)

**Current**:
```markdown
   REPEAT until goals closed or stuck:
     a. Use lean_goal to see current state
     b. Use lean_multi_attempt to try candidate tactics
     c. If promising tactic found, apply via Edit
     d. If stuck, use lean_state_search, lean_hammer_premise
     e. If still stuck, log state and return partial
```

**Proposed**:
```markdown
   REPEAT until goals closed or stuck:
     a. Use lean_goal to see current state
     b. Use lean_multi_attempt to trial candidate tactics WITHOUT editing (pre-edit trial)
     c. If promising tactic found, apply via Edit
     d. After editing, use lean_goal to confirm goal progress; use lean_verify for axiom/sorry check
     e. If stuck, use lean_state_search, lean_hammer_premise
     f. If still stuck, log state and return partial
```

---

### Change G: lean-implementation-flow.md -- Update Stage 4C

**File**: `.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` (lines 109-112)

**Current**:
```markdown
### 4C. Verify Phase Completion

- Run `lake build` to verify full project builds
- Check verification criteria from plan
```

**Proposed**:
```markdown
### 4C. Verify Phase Completion

- Run `lake build Module.Name` to verify the module compiles (preferred; faster than full build)
- Fall back to `lake build` only if the module name is unknown or the phase spans multiple modules
- Check verification criteria from plan
```

---

### Change H: lean-implementation-flow.md -- Update Stage 5 with clarifying note

**File**: `.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` (lines 119-124)

**Current**:
```markdown
## Stage 5: Run Final Build Verification

After all phases complete:
```bash
lake build
```
```

**Proposed**:
```markdown
## Stage 5: Run Final Build Verification

After all phases complete, run the full project build (mandatory -- this is the only required full build):
```bash
lake build
```

Note: Per-step verification uses `lean_goal` + `lean_verify`. Phase-end uses `lake build Module.Name`. Only this final stage requires full `lake build`.
```

---

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Agent ignores the new MUST DO items because list is long | Low | New items are added at positions 5-8 where they follow the existing lean_goal item; clear grouping |
| lean_verify tool not available in all environments | Low | The tool is listed in the lean-lsp MCP server system reminder and confirmed present |
| Phase-end using scoped build misses cross-module errors | Medium | The "fall back to lake build if module name unknown or spans multiple modules" clause in Stage 4C covers this |
| Renumbering MUST DO items breaks agent behavior | Low | MUST DO is a human-readable checklist; renumbering does not affect semantics |
| lean_multi_attempt REPL mode doesn't match file context exactly | Low | The MCP docs note that omitting `column` gives "fast line-based REPL attempts" -- agents should use `column` for exact position matching when precision needed |

---

## Context Extension Recommendations

This is a meta task (lean extension infrastructure changes). No external context extension is needed. The changes themselves are the authoritative documentation of the new policy once implemented.

---

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/extensions/lean/rules/lean4.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/agents/lean-implementation-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`

### MCP Tool Reference Consulted
- lean-lsp MCP server system reminder (available at agent runtime)

### Key Confirmation
`lean_verify` is confirmed present in the lean-lsp MCP server with description: "Axiom check + source scan. Use fully qualified name (e.g. `Ns.thm`)."
