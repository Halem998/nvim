# Research Report: Task #664

**Task**: 664 - Create cslib agents
**Started**: 2026-06-11T00:00:00Z
**Completed**: 2026-06-11T00:05:00Z
**Effort**: ~30 minutes
**Dependencies**: lean extension (lean-research-agent.md, lean-implementation-agent.md)
**Sources/Inputs**:
- `/home/benjamin/.config/nvim/.claude/extensions/lean/agents/lean-research-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/agents/lean-implementation-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/core/docs/guides/creating-agents.md`
- `/home/benjamin/Projects/cslib/CONTRIBUTING.md`
- `/home/benjamin/Projects/cslib/ORGANISATION.md`
- `/home/benjamin/Projects/cslib/NOTATION.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/agents/cslib-research-agent.md` (stub)
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/agents/cslib-implementation-agent.md` (stub)
**Artifacts**: `specs/664_create_cslib_agents/reports/01_cslib-agents-research.md`
**Standards**: report-format.md

---

## Executive Summary

- The cslib agents should be specialized variants of the lean agents, inheriting their MCP tool set and blocked-tool list, but layered with CSLib-specific domain knowledge
- The research agent (opus) needs search strategies oriented toward CSLib's reuse-first philosophy: checking if CSLib already has the abstraction before implementing
- The implementation agent (sonnet) must encode the full CI pipeline with seven ordered verification steps, including the `checkInitImports` requirement and `lake shake` for minimized imports
- Both agents share the lean agents' blocked tool list (`lean_diagnostic_messages`, `lean_file_outline`) and the zero-sorry policy
- CSLib-specific style differences from plain Lean: proof readability over golfing is explicitly required, typeclass-based notation reuse is expected, and domain-appropriate variable names are encouraged

---

## Context and Scope

This research gathered the complete content needed to replace the two stub agent files at:
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/agents/cslib-research-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/agents/cslib-implementation-agent.md`

The stubs contain only frontmatter and a placeholder line. The goal is to produce complete agent definitions that:
1. Inherit appropriate content from the lean agents (same MCP tools, same blocked-tool policy)
2. Add CSLib-specific domain knowledge (CI pipeline, project structure, notation, style)
3. Follow the agent creation guide's 8-stage workflow pattern

---

## Findings

### 1. Lean Agent Structure (Reference Template)

Both lean agents follow the same high-level structure:
- YAML frontmatter with `name`, `description`, `model`
- BLOCKED TOOLS section (critical, first section after overview)
- Allowed Tools section listing all MCP tools with rate-limit annotations
- Search Decision Tree
- Domain-specific constraints (zero-debt for lean, CI pipeline for cslib)
- Stage 0: Initialize Early Metadata (BEFORE any work)
- Error Handling (MCP error recovery, rate limit handling)
- Critical Requirements (MUST DO / MUST NOT lists)

The lean-research-agent uses **opus** and the lean-implementation-agent uses **opus** as well. However, for cslib, the task specifies research=opus, implementation=sonnet. This matches the design intent (implementation is a worker agent; opus for research/planning reasoning depth).

### 2. Blocked Tools (Inherited from Lean)

Both cslib agents must block the same two tools as the lean agents:
- `lean_diagnostic_messages` -- lean-lsp-mcp bug #118; use `lean_goal` or `lake build` instead
- `lean_file_outline` -- lean-lsp-mcp bug #115; use `Read` + `lean_hover_info` instead

### 3. MCP Tool Set

**Research agent** uses the full search tool set:
- Core (no rate limit): `lean_goal`, `lean_hover_info`, `lean_completions`, `lean_multi_attempt`, `lean_local_search`, `lean_term_goal`, `lean_declaration_file`, `lean_run_code`, `lean_build`
- Rate limited: `lean_leansearch` (3/30s), `lean_loogle` (3/30s), `lean_leanfinder` (10/30s), `lean_state_search` (3/30s), `lean_hammer_premise` (3/30s)

**Implementation agent** uses the same core tools plus `lean_verify` for axiom checks, and the same rate-limited tools.

### 4. CSLib Search Strategy for Research Agent

The reuse-first philosophy means the search priority should be:
1. `lean_local_search` first -- "does CSLib already have this?"
2. `lean_leansearch` -- "does Mathlib have a version we can instantiate?"
3. `lean_loogle` -- find type-pattern matches in Mathlib
4. `lean_leanfinder` -- identify the Lean name for a CS concept

CSLib-specific search targets:
- Check `Cslib.Foundations/` before defining new abstractions
- Check existing typeclass hierarchy (`LTS`, `HasImp`, `HasBox`, `HasBot`, etc.) before creating new ones
- Search for existing notation typeclasses before introducing locally-scoped notation

### 5. CSLib CI Verification Pipeline (Implementation Agent)

From `CONTRIBUTING.md`, the complete ordered pipeline is:

1. `lake build Module.Name` -- scoped build for the modified module
2. `lake exe checkInitImports` -- verify all files import `Cslib.Init`
3. `lake lint` -- environment linters (from Batteries/Mathlib)
4. `lake exe lint-style` -- text linters (can use `--fix` option)
5. `lake shake --add-public --keep-implied --keep-prefix` -- minimized imports
6. `lake exe mk_all --module` -- ensure all files are listed in `Cslib.lean`
7. `lake test` -- full test suite (runs `CslibTests/`)

**Critical**: `lake exe checkInitImports` verifies that all files import `Cslib/Init.lean`, which sets up default linting and tactics. Missing this import causes CI failure.

**Critical**: `lake shake` checks minimized imports. Special comment syntax exists in `lake shake --help` for preserving imports needed for tactics or typeclasses.

### 6. CSLib Code Style (from CONTRIBUTING.md)

**Proof style**:
- Readability over golfing: "Please try to make proofs easy to follow"
- Golfing and automation are welcome IF proofs remain reasonably readable AND compilation does not noticeably slow down

**Notation**:
- Prefer existing typeclasses for common concepts (reductions, transitions, etc.)
- If notation can apply to different types, keep it locally scoped OR create a new typeclass
- Do not use `notation` or `infix` for concepts that should be typeclass-polymorphic

**Variable names**:
- Domain-appropriate names encouraged: in `Lts`, `State` for state types and `μ` for transition labels
- Not required to follow strict mathlib variable-name conventions when domain context is clearer

**Documentation**:
- Document all definitions and theorems
- When formalizing published results, reference the source in doc comments

**AI Usage Disclosure**:
- If AI tools are used, the PR description MUST explain which tools and how they were used
- This is mandatory per CSLib's adoption of the Mathlib AI policy

### 7. Pull Request Title Format

PR titles MUST begin with one of: `feat`, `fix`, `doc`, `style`, `refactor`, `test`, `chore`, `perf`, followed by a colon. An optional parenthetical can indicate the area: e.g., `feat(Logics/Modal): add S4 completeness`.

### 8. CSLib Project Structure (for Research Agent)

Key namespaces to know:
- `Cslib.Foundations.*` -- shared abstractions (LTS, Syntax, Logic axioms, Data)
- `Cslib.Logics.*` -- specific logics (Propositional, Modal, Temporal, Bimodal, HML, LinearLogic)
- `Cslib.Languages.*` -- language models (Boole, CCS, Lambda, Pi, etc.)
- `Cslib.Computability.*` -- automata, Turing machines
- `Cslib.Algorithms.*` -- algorithm formalizations
- `Cslib.Init` -- root initialization, sets up linting and tactics

The `Cslib.Logic` namespace spans both `Foundations/Logic/` and `Logics/`, so namespace lookups must account for this.

### 9. Notation Overview (from NOTATION.md)

Three options exist for operational semantics notation (A, B, C), all typeclass-backed:
- Option A: `m → n`, `m ↠ n`, `p [μ]→ q` (extra arrowhead for closures)
- Option B: `m → n`, `m →* n`, `p [μ]→* q` (asterisk for closures)
- Option C: `m ⭢ n`, `m ⯮ n` (triangle heads to distinguish from Lean's `→`)

Research agents should identify which option a module uses when suggesting extensions.

### 10. Agent Creation Guide Compliance

Per `creating-agents.md`:
- Both agents follow the lean agent pattern rather than the generic guide's return-JSON pattern
- The lean agents use a **metadata file** pattern (write to `.return-meta.json`) rather than returning JSON to console
- This is appropriate for cslib agents too, since they are invoked by skills that read the metadata file
- The `MUST NOT: Return JSON to the console` requirement is the same as the lean agents

### 11. Stub Files Status

Both stub files have correct frontmatter:
- `cslib-research-agent.md`: `name: cslib-research-agent`, `description: Research CSLib formalization patterns and Mathlib API for CSLib contributions`, `model: opus`
- `cslib-implementation-agent.md`: `name: cslib-implementation-agent`, `description: Implement CSLib proofs following Lean 4 and CSLib contribution standards`, `model: sonnet`

These are correct and should be preserved as the frontmatter of the completed files.

---

## Decisions

1. **Both agents inherit the lean agent metadata-file pattern** rather than the generic agent guide's JSON-to-console pattern. This is consistent with how they will be invoked by cslib skills.

2. **Research agent uses opus, implementation agent uses sonnet**. This matches the task specification and the general model tier policy (opus for reasoning-heavy tasks, sonnet for worker tasks).

3. **The implementation agent's verification pipeline has 7 ordered steps** matching the CONTRIBUTING.md exactly. The order matters: scoped build first, then `checkInitImports`, then linters, then shake, then `mk_all`, then full test.

4. **Zero-sorry policy applies** to the cslib implementation agent the same as the lean agent. The escalation protocol (mark phase BLOCKED, document blocker, return partial) applies.

5. **The cslib research agent adds a "Reuse Check" step** before any recommendation: check if CSLib already has the abstraction in `Foundations/`, check if an existing typeclass covers the need, check Mathlib for a version that can be instantiated.

6. **The AI disclosure requirement is unique to CSLib** (vs. plain lean). The implementation agent must remind contributors to document AI tool usage in PR descriptions.

---

## Risks and Mitigations

- **Risk**: CSLib's `Cslib.Logic` namespace spans two directories; naive `lean_local_search` might miss definitions. **Mitigation**: Document this in the research agent's search strategy.
- **Risk**: `lake shake` may suggest removing imports that are needed for typeclass resolution or tactics. **Mitigation**: Document the `lake shake --help` special comment syntax in the implementation agent's CI pipeline section.
- **Risk**: The agents must not reinvent the lean agent infrastructure. **Mitigation**: Explicitly model the cslib agents as "lean agents + CSLib layer" so future maintainers understand the inheritance structure.

---

## Implementation Blueprint

### cslib-research-agent.md Structure

```
---
name: cslib-research-agent
description: Research CSLib formalization patterns and Mathlib API for CSLib contributions
model: opus
---

# CSLib Research Agent

## Overview
[specialist on top of lean-research-agent, CSLib-specific search strategies]

## Agent Metadata
[same pattern as lean-research-agent]

## BLOCKED TOOLS (NEVER USE)
[inherited from lean: lean_diagnostic_messages, lean_file_outline]

## Allowed Tools
[identical MCP tool set to lean-research-agent]

## CSLib-Specific Search Strategy
[reuse-first: check Foundations/, check typeclasses, check Mathlib]

## CSLib Project Structure Reference
[namespaces: Foundations, Logics, Languages, Computability, Algorithms]

## Zero-Debt Policy Compliance
[same as lean: no sorry deferral]

## Stage 0: Initialize Early Metadata
[same pattern as lean]

## Error Handling
[same MCP recovery pattern as lean]

## Critical Requirements
[MUST DO / MUST NOT lists]
```

### cslib-implementation-agent.md Structure

```
---
name: cslib-implementation-agent
description: Implement CSLib proofs following Lean 4 and CSLib contribution standards
model: sonnet
---

# CSLib Implementation Agent

## Overview
[specialist for CSLib CI pipeline and contribution standards]

## Agent Metadata

## BLOCKED TOOLS (NEVER USE)
[inherited from lean]

## Allowed Tools
[same as lean-implementation-agent]

## Phase Status Updates (MANDATORY)
[same as lean]

## Stage 0: Initialize Early Metadata

## Final Verification Stage (MANDATORY)
[CSLib-specific pipeline replacing lean's verification steps]

### CSLib CI Pipeline (ordered)
1. lake build Module.Name
2. lake exe checkInitImports
3. lake lint
4. lake exe lint-style
5. lake shake --add-public --keep-implied --keep-prefix
6. lake exe mk_all --module
7. lake test

## CSLib Style Compliance
[proof readability, notation typeclass reuse, documentation, AI disclosure]

## Pull Request Standards
[conventional commit titles, AI usage disclosure requirement]

## Error Handling / Escalation Protocol
[same as lean]

## Phase Checkpoint Protocol
[same as lean]

## Context Management
[same as lean]

## Critical Requirements
```

---

## Context Extension Recommendations

- **Topic**: CSLib extension context files
- **Gap**: The cslib extension likely needs `context/` files for domain knowledge (project structure, namespace map, typeclass hierarchy). These are not yet created.
- **Recommendation**: After creating agents, consider adding a `cslib-project-structure.md` context file that maps the namespace hierarchy and common typeclasses.
