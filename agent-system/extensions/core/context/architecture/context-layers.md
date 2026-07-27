# Context Layer Architecture

**Created**: 2026-03-25
**Purpose**: Define the three independent context layers and their management boundaries
**Audience**: Agents, extension loader, system developers

---

## Overview

The system uses three independent context layers. Each has a distinct owner, lifecycle, and query mechanism. They are loaded in parallel when agents need comprehensive knowledge.

## Layer Definitions

| Aspect | Agent Context | Project Context | Project Memory |
|--------|--------------|-----------------|----------------|
| **Location** | `.claude/context/` | `.context/` | `.memory/` |
| **Managed by** | Extension loader | User (via index.json) | Agents over time |
| **Contains** | Core patterns + extension domain knowledge | Project-specific conventions | Learned facts and observations |
| **Lifecycle** | Rebuilt each time extensions are loaded | Persistent, user-edited | Persistent, agent-appended |
| **Query** | `.claude/context/index.json` | `.context/index.json` | Direct file reads |
| **Touched by loader** | Yes (copy + merge) | No | No |

## Layer Details

### 1. Agent Context (.claude/context/)

The extension loader assembles this directory during extension loading:

- **Core files**: Agent system patterns, templates, reference docs (always present)
- **Extension files**: Language-specific context copied from `agent-system/extensions/*/context/` during load

The loader calls `copy_context_dirs()` to copy extension context into `.claude/context/` and `append_index_entries()` to merge extension entries into the single `index.json`. After loading, all agent context (core + extensions) is queryable from one index.

All write operations use `target_dir` derived from `config.base_dir` (which is `.claude/`). The loader has no code path that references or writes to `.context/` or `.memory/`.

### 2. Project Context (.context/)

User-managed directory for project-specific conventions not covered by any extension. Governed by its own `index.json` with the same schema as the agent context index.

Starts empty. The user populates it with project conventions (coding style, naming rules, domain terminology) as needed. The extension loader does not touch this directory.

### 3. Project Memory (.memory/)

Agent-managed directory for persistent learned information. Independent from `.context/` -- neither manages nor references the other. Both are loaded in parallel when agents need project knowledge.

### Contracts directory: convention vs. load path

`context/contracts/` is the "Full details" companion referenced by the top-level
"Where to store new content" decision tree for the "Agent system pattern (orchestration, format,
workflow)?" branch. Two findings about that directory are recorded here so future work does not
have to re-derive them.

**Finding (i) — where a contract must live to be loaded by both standard and hard mode.**
Directory placement is not a load mechanism in this codebase. `context/contracts/` is a naming
and genre convention only; historically every occupant of the directory has been loaded
exclusively by `*-hard` agents and skills. What actually causes a contract to load is an
explicit `@`-reference bullet in the consuming agent's or skill's `## Context References`
section. A contract intended for both standard and hard mode may live in `context/contracts/`
provided it is explicitly referenced from both agents' (and both skills') Context References
sections, and its own header should say so plainly so a future reader does not assume
hard-mode-only applicability from placement alone. `contracts/phase-closure.md` and
`contracts/pre-edit-gate.md` are the first two contracts to do this: both are referenced from
`agents/general-implementation-agent.md`, `agents/general-implementation-hard-agent.md`,
`skills/skill-implementer/SKILL.md`, and `skills/skill-implementer-hard/SKILL.md` alike.

**Finding (ii) — no central injection point exists.** Only core's standard implementation agent
(`agents/general-implementation-agent.md`) runs the adaptive `context-discovery.md` index query
that pulls in matching context by `load_when` criteria; no extension implementation agent and no
hard-mode implementation agent runs that query. `scripts/skill-base.sh`'s `context_injection`
lifecycle stage (`skill_context_injection`, which calls `skill_run_extension_hook
"context_injection" ...`) runs in the opposite direction from what a "central injection point"
would need: it lets an *extension* inject its own domain-specific content into a *core* skill's
dispatch prompt, not the other way around. There is no shared dispatch-prompt builder that a core
contract could hook into once to reach every consumer — each `SKILL.md` and each agent file
constructs its own dispatch prompt and its own Context References section inline.

**Consequence.** Propagating any core `context/contracts/` file to extension implementation
agents is manual, per-file work with no shortcut through either the adaptive query or the
`context_injection` hook. The durable in-repo precedent for how this propagation is actually done
is `extensions/cslib/agents/cslib-implementation-hard-agent.md`, which hand-copies core's
`anti-analysis.md`, `wrap-up.md`, and `territory.md` as individually listed
`@.claude/context/contracts/...` bullets in its own `## Context References` section. Any future
task that adds a core contract and assumes it now reaches extension implementers "for free"
because a central hook exists is working from a false premise; this file is where that premise
gets checked.

## Verification Summary

Confirmed by code review (2026-03-25) of the extension loader source:

- `loader.lua`: All target paths derive from `target_dir` parameter (the `.claude/` base directory). Functions `copy_context_dirs`, `copy_simple_files`, `copy_skill_dirs`, `copy_scripts` all write within this base. `copy_data_dirs` writes to `project_dir` but only for declared data directories, not `.context/`.
- `merge.lua`: `append_index_entries` operates on a `target_path` parameter pointing to `.claude/context/index.json`. No `.context/` references.
- `config.lua`: `base_dir` is set to `.claude` (or `.opencode`). No `.context/` configuration.
- Grep for `.context/` across all 8 files in the extensions module: zero matches.
