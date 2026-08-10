# Research Report: Task #676

**Task**: 676 - cslib_extension_hard_mode_variants
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:00:00Z
**Effort**: 1.5h research
**Dependencies**: Task 669 (hard_mode_agent_system) — completed; hard-mode infrastructure exists
**Sources/Inputs**: Codebase (cslib extension, lean extension, core hard-mode skills/agents/contracts)
**Artifacts**: - specs/676_cslib_extension_hard_mode_variants/reports/01_cslib-hard-mode-research.md
**Standards**: report-format.md

---

## Executive Summary

- The cslib extension is a specialization of lean4 for formal computer-science library
  (CSLib) development; it already depends on the lean extension and inherits all lean-lsp
  MCP tooling
- The full hard-mode infrastructure from task 669 is **complete and in place**: 5 contract
  files, 4 core hard-mode skills, 3 hard-mode agents, and the `routing_hard` manifest key
  documented in extension-development.md
- **No extension currently declares `routing_hard`** — cslib will be the first to do so
- cslib hard-mode needs **exactly 2 new agent files** (research + implementation) and
  **2 new skill directories** plus **manifest.json modifications**; the contract files and
  core wrappers are fully reusable
- The key cslib-specific override is in **H3 (reference grounding)**: CSLib already mandates
  a literature extraction protocol and citation-conventions system; the hard-mode agent must
  enforce these at the prompt-contract level, not just as advisory guidance
- H2 (anti-analysis) requires a **cslib-specific read-budget bar**: first sorry-free lemma
  within 20 tool calls (same as lean4) — already documented in `contracts/anti-analysis.md`
  as a domain specialization
- The verification pipeline (CSLib CI: 7 steps including `checkInitImports`, `lint-style`,
  `lake shake`) and zero-debt policy are already enforced by the base cslib agents;
  hard-mode agents must **strengthen** these with wrap-up discipline (H9) and per-phase
  incremental commits

---

## Context and Scope

Task 676 adds hard-mode routing to the cslib extension following the same pattern the
architecture calls for in extension-development.md, section "Hard-Mode Routing". The cslib
extension is a CS formal-library specialization of the lean4 extension and already declares
`"dependencies": ["core", "lean"]`. The target artifact is:

- `manifest.json` additions: `routing_hard` block
- 2 new hard-mode skill directories in `extensions/cslib/skills/`
- 2 new hard-mode agent files in `extensions/cslib/agents/`
- `EXTENSION.md` updates: hard-mode rows in Skill-Agent Mapping table
- `index-entries.json` updates: load conditions for hard agents

The lean4 extension does NOT yet have hard-mode variants either — cslib will be the first
extension to use `routing_hard`. The lean4 extension can follow the same pattern afterward.

---

## Findings

### 1. Current CSLib Extension Anatomy

**Files**:
```
extensions/cslib/
├── manifest.json                               -- routing (2 task types: cslib, pr)
├── EXTENSION.md                                -- CLAUDE.md merge source
├── index-entries.json                          -- context load conditions
├── README.md
├── agents/
│   ├── cslib-research-agent.md                 -- opus; 275 lines
│   └── cslib-implementation-agent.md           -- sonnet; 396 lines
├── skills/
│   ├── skill-cslib-research/SKILL.md           -- thin wrapper; 84 lines
│   ├── skill-cslib-implementation/SKILL.md     -- thin wrapper; 108 lines
│   └── skill-pr-implementation/SKILL.md        -- PR branch preparation
├── context/project/cslib/
│   ├── domain/
│   │   ├── contributing-standards.md
│   │   ├── notation-conventions.md
│   │   └── project-organization.md
│   ├── patterns/
│   │   ├── proof-structure.md
│   │   └── reuse-first.md
│   ├── standards/
│   │   ├── ci-pipeline.md
│   │   ├── citation-conventions.md
│   │   ├── mathlib-style.md
│   │   ├── pr-conventions.md
│   │   └── pr-description-format.md
│   └── tools/
│       ├── lake-commands.md
│       └── linters.md
└── rules/cslib.md
```

**Manifest routing** (current):
```json
"routing": {
  "research": { "cslib": "skill-cslib-research", "pr": "skill-researcher" },
  "plan":     { "cslib": "skill-planner",         "pr": "skill-planner" },
  "implement": { "cslib": "skill-cslib-implementation", "pr": "skill-pr-implementation" }
}
```

**Current agent models**:
- `cslib-research-agent`: `model: opus`
- `cslib-implementation-agent`: `model: sonnet`

**What the base cslib agents already do** (relevant to hard mode):
- Literature Extraction Protocol (research agent): mandatory when task references papers —
  creates step-map from theorem to major proof steps
- Zero-Debt Policy: explicitly forbids sorry deferral and new axioms — already hard-mode
  grade constraints
- Reuse Check Protocol: mandatory CSLib namespace scan before recommending new definitions
- Phase Checkpoint Protocol (implementation agent): commits after each phase, writes handoffs
- 7-step CI pipeline (implementation agent): all steps mandatory before returning "implemented"
- Escalation Protocol: marks phases [BLOCKED] rather than using sorry — structurally similar
  to H5 deflection handling

### 2. Existing Hard-Mode Infrastructure (Reusable As-Is)

All of the following are complete and need NO modification:

**Contract files** (`.claude/context/contracts/`):
| File | H-technique | Status |
|------|------------|--------|
| `anti-analysis.md` | H2 | Complete; includes lean4 domain specialization note |
| `reference-grounding.md` | H3 | Complete; includes lean4 Tier 1 note |
| `convergence.md` | H6 | Complete |
| `territory.md` | H7 | Complete |
| `wrap-up.md` | H9 | Complete |

**Core hard-mode skills** (`.claude/skills/`):
| Skill | Purpose |
|-------|---------|
| `skill-researcher-hard/` | Delegates to `general-research-hard-agent`; postflight mirrors `skill-researcher` |
| `skill-implementer-hard/` | Delegates to `general-implementation-hard-agent`; per-phase dispatch (H1) |
| `skill-planner-hard/` | Delegates to `planner-hard-agent`; phase-sizing + postmortem constraints (H8) |
| `skill-orchestrate-hard/` | Per-phase loop, churn detection, adversarial verify gate (H1+H4+H5+H6) |

**Core hard-mode agents** (`.claude/agents/`):
| Agent | H-techniques |
|-------|-------------|
| `general-research-hard-agent.md` | H2+H3+H4 (adversarial self-verification) |
| `general-implementation-hard-agent.md` | H2+H7+H9 (anti-analysis, territory, wrap-up) |
| `planner-hard-agent.md` | H8 (phase sizing, postmortem constraints) |

**Extension-development.md**: `routing_hard` key is fully documented with fallback behavior.

### 3. What cslib Hard-Mode Needs to Add

The fallback behavior of `command-route-skill.sh` (without `routing_hard`) would be:
- `/research cslib --hard` → tries `skill-cslib-research-hard` → falls back to `skill-researcher-hard`
- `/implement cslib --hard` → tries `skill-cslib-implementation-hard` → falls back to `skill-implementer-hard`

The core fallback skills work — they enforce H2/H3/H4/H7/H9. However, they delegate to
**general-purpose** hard agents that lack cslib domain knowledge:

1. They don't know about the CSLib Reuse Check Protocol
2. They don't know about the zero-debt completion gate (no-sorry rule)
3. They don't know about `lean_local_search` as the primary search tool
4. They don't invoke the 7-step CI pipeline
5. They don't enforce CSLib citation conventions (BibKey format, `references.bib`)
6. They don't check that all files import `Cslib.Init`
7. They don't block `lean_diagnostic_messages` and `lean_file_outline` (buggy tools)

**Therefore, cslib-specific hard-mode agents ARE justified**: the domain gap between a
generic hard-mode agent and a cslib-aware hard-mode agent is substantial (7 behavioral
differences), matching the justification threshold from task 669 team research.

### 4. H-Technique Analysis for CSLib

**Domain classification** (from task 669 team research three-category model):

| Technique | Category | CSLib Application |
|-----------|----------|------------------|
| H1 per-phase dispatch | Dispatch geometry | Reuse `skill-implementer-hard`; each proof phase is naturally a single lean file or module |
| H2 anti-analysis | Prompt contract | Override: first sorry-free lemma within 20 tool calls (same bar as lean4) |
| H3 reference grounding | Prompt contract | Override: Tier 1 mandatory (literature) + CSLib citation conventions (BibKey format) |
| H4 adversarial verification | Feedback loop | Reuse from `general-research-hard-agent`; promote to hard research skill postflight |
| H5 divergence audit | Feedback loop | Reuse from `skill-orchestrate-hard`; cslib adds `sorry_inventory` tracking |
| H6 convergence policing | Feedback loop | Reuse from `skill-orchestrate-hard` |
| H7 territory contracts | Dispatch geometry | Reuse; file territory maps to Cslib module files |
| H8 phase sizing | Dispatch geometry | Reuse `skill-planner-hard`; phases sized to single Lean files |
| H9 wrap-up discipline | Prompt contract | Override: sorry_inventory in handoff JSON (same as lean4 formulation); incremental commits at each `lake build` green |

**Techniques needing cslib-specific override** (3 of 9):
- H2: domain specialization bar (first sorry-free lemma) — already in base contract, just needs
  the cslib hard agent to reference the contract and inherit the lean4 bar
- H3: CSLib citation convention enforcement (BibKey, `references.bib`) added on top of
  the base reference-grounding Tier 1 protocol
- H9: sorry_inventory in handoff JSON — same lean4 formulation applies; the base wrap-up
  contract's "partial implementation inventory" maps directly to CSLib's sorry tracking

**Techniques fully reusable without override** (6 of 9):
- H1 (skill-implementer-hard), H4 (agent-level), H5 (orchestrate-hard), H6 (orchestrate-hard),
  H7 (territory contract file), H8 (skill-planner-hard)

### 5. File Inventory

**New files to create** (4 files total):

```
extensions/cslib/
├── agents/
│   ├── cslib-research-hard-agent.md      [NEW] ~200 lines
│   └── cslib-implementation-hard-agent.md [NEW] ~280 lines
└── skills/
    ├── skill-cslib-research-hard/
    │   └── SKILL.md                      [NEW] ~90 lines
    └── skill-cslib-implementation-hard/
        └── SKILL.md                      [NEW] ~110 lines
```

**Files to modify** (3 files):

```
extensions/cslib/manifest.json            [MODIFY] add routing_hard block
extensions/cslib/EXTENSION.md            [MODIFY] add hard-mode rows to Skill-Agent Mapping
extensions/cslib/index-entries.json      [MODIFY] add hard agent load conditions
```

**Files NOT needed** (already exist in core):
- Contract files (5 files in `.claude/context/contracts/`) — no cslib overrides needed,
  just @-references in the new agents
- `skill-planner-hard` — no cslib variant needed; hard planning for cslib uses core planner-hard
  since the phase-sizing requirement is domain-agnostic

**Total: 4 new files + 3 modifications = 7 artifacts**

### 6. Agent Design Specifications

#### cslib-research-hard-agent.md (~200 lines)

Extends `cslib-research-agent` with:
- `@.claude/context/contracts/anti-analysis.md` — H2 (with lean4/formal bar)
- `@.claude/context/contracts/reference-grounding.md` — H3 (Tier 1 mandatory for literature tasks)
- Adversarial self-verification pass (H4): after writing research report, re-examine the 3
  most load-bearing claims against primary sources; append `## Adversarial Verification`
  section with verdict per claim
- cslib-specific H3 enrichment: if task references papers, verify BibKeys exist in
  `references.bib`; flag missing entries as explicit gap in report
- All cslib-research-agent constraints carried forward: blocked tools, reuse check protocol,
  zero-debt recommendations, Lean MCP tools, rate limits
- Model: `opus` (same as base cslib-research-agent; formal research benefits from deep reasoning)

#### cslib-implementation-hard-agent.md (~280 lines)

Extends `cslib-implementation-agent` with:
- `@.claude/context/contracts/anti-analysis.md` — H2 (first sorry-free lemma within 20 calls)
- `@.claude/context/contracts/wrap-up.md` — H9 (orchestrator handoff JSON + sorry_inventory)
- `@.claude/context/contracts/territory.md` — H7 (file territory when parallel dispatch)
- Per-phase focus: expects `phase_number` in delegation context; implements exactly one phase
  per dispatch; does NOT scan or plan unrelated phases
- Settled-Design Preamble Protocol (from H2 contract): at start of Stage 4, state decided
  design + ruled-out alternatives + preserved assets
- All cslib-implementation-agent constraints carried forward: blocked tools, zero-debt policy,
  phase checkpoint protocol, 7-step CI pipeline, escalation protocol
- Model: `sonnet` (same as base cslib-implementation-agent)

#### skill-cslib-research-hard/SKILL.md (~90 lines)

Extends `skill-cslib-research` with:
- Dispatches to `cslib-research-hard-agent` instead of `cslib-research-agent`
- Passes `effort_flag: "hard"` in delegation context
- Postflight: logs `adversarial_verification_triggered: true` to metadata (same as
  `skill-researcher-hard` pattern)
- Maintenance note: mirror postflight changes from `skill-cslib-research`

#### skill-cslib-implementation-hard/SKILL.md (~110 lines)

Extends `skill-cslib-implementation` with:
- Dispatches to `cslib-implementation-hard-agent` instead of `cslib-implementation-agent`
- Passes `effort_flag: "hard"` and `phase_number` (from handoff JSON) in delegation context
- Single-phase dispatch context (H1): reads `.orchestrator-handoff.json` to determine
  `next_phase` before delegation
- Includes territory params in prompt when `territory` is non-null
- Maintenance note: mirror postflight changes from `skill-cslib-implementation`

#### manifest.json routing_hard block

```json
"routing_hard": {
  "research": {
    "cslib": "skill-cslib-research-hard",
    "pr": "skill-researcher-hard"
  },
  "plan": {
    "cslib": "skill-planner-hard",
    "pr": "skill-planner-hard"
  },
  "implement": {
    "cslib": "skill-cslib-implementation-hard",
    "pr": "skill-implementer-hard"
  }
}
```

Note: `pr` task-type routes to core hard-mode skills (no domain gap for PR preparation
tasks; the PR workflow is documentation/git, not formal proof).

#### EXTENSION.md additions

Add hard-mode rows to the Skill-Agent Mapping table:

```markdown
| skill-cslib-research-hard | cslib-research-hard-agent | opus | Hard-mode CSLib research: adversarial verification (H4), cslib-specific H3 citation grounding |
| skill-cslib-implementation-hard | cslib-implementation-hard-agent | sonnet | Hard-mode CSLib implementation: anti-analysis (H2), per-phase dispatch (H1), sorry tracking (H9) |
```

Also add a brief "When to use --hard for CSLib tasks" note analogous to the core CLAUDE.md
`--hard` decision framework, scoped to CSLib:
- Prior cslib dispatch produced analysis of proof strategies without any lemma implementations
- Task involves formalizing a literature result (Tier 1 H3 is mandatory)
- Same sorry survived 2+ implementation phases (divergence audit trigger)
- Task has `cslib` type AND any of the core `--hard` criteria from CLAUDE.md apply

#### index-entries.json additions

Add load conditions for the two new hard agents:

```json
{
  "path": "extensions/cslib/agents/cslib-research-hard-agent.md",
  "domain": "agents",
  "subdomain": "cslib-research-hard",
  "load_when": {
    "agents": ["cslib-research-hard-agent"],
    "task_types": ["cslib"]
  }
},
{
  "path": "extensions/cslib/agents/cslib-implementation-hard-agent.md",
  "domain": "agents",
  "subdomain": "cslib-implementation-hard",
  "load_when": {
    "agents": ["cslib-implementation-hard-agent"],
    "task_types": ["cslib"]
  }
}
```

### 7. Pattern Consistency with Lean4 Extension

The lean4 extension does NOT yet have hard-mode variants. The cslib pattern being established
here will serve as the reference for lean4 hard-mode (a likely follow-up task). Key consistency
constraints to preserve:

- Both cslib and lean4 hard agents should reference the same base contracts (no divergence)
- The `routing_hard` block structure in both manifests should be identical in schema
- CSLib's sorry_inventory tracking (H9) uses the same field name as lean4's H9 formulation
- The H2 domain bar ("first sorry-free lemma within 20 tool calls") is shared; do NOT
  introduce a cslib-specific variant that diverges from the lean4 formulation in
  `anti-analysis.md`'s Domain Specialization section

---

## Decisions

1. **cslib-specific hard agents are justified**: 7 behavioral differences from generic
   hard agents exceed the threshold; create 2 new agent files rather than relying on fallback
2. **No cslib contract override files**: The base contracts are adequate for cslib; the cslib
   hard agents will @-reference base contracts and add cslib-specific guidance in their own
   system prompts, rather than creating `extensions/cslib/context/contracts/` overrides
3. **No hard variant for skill-planner for cslib**: `skill-planner-hard` handles phase sizing
   (H8) generically; CSLib proof phases (one module per phase) fit the standard phase-sizing
   model without domain-specific modification
4. **`pr` task type routes to core hard skills**: PR preparation tasks don't involve formal
   proofs; the domain gap is not present for `pr` type; core `skill-researcher-hard` and
   `skill-implementer-hard` suffice
5. **Lean4 extension is NOT in scope for this task**: This task creates cslib hard mode.
   Lean4 hard mode is a separate follow-up task to be created after cslib is complete.
6. **Model preservation**: Hard research agent keeps `opus` (same as base cslib-research-agent);
   hard implementation agent keeps `sonnet` (same as base). The hard mode increases behavioral
   constraints, not model size.

---

## Risks and Mitigations

| Risk | Severity | Mitigation |
|------|---------|------------|
| `provides.skills` and `provides.agents` arrays not updated in manifest.json | High | Include these arrays in the modification spec; the loader copies files only from manifest entries |
| EXTENSION.md hard-mode rows out of sync with agent files | Medium | Write both files together in the same implementation phase |
| index-entries.json format mismatch (extension vs core index) | Medium | Copy exact schema from existing cslib index-entries.json entries |
| Hard agents grow stale relative to base agents (maintenance drift) | Medium | Add maintenance note to each hard skill: "mirror postflight changes from base skill"; this is documented in core hard skills already |
| `routing_hard` not picked up by loader (new manifest key) | Low | extension-development.md explicitly documents `routing_hard`; `command-route-skill.sh` handles it |
| cslib hard agents accidentally call blocked tools (lean_diagnostic_messages, lean_file_outline) | High | Carry forward the BLOCKED TOOLS section verbatim from base cslib agents |

---

## Appendix

### Search Queries Used

- `find /home/benjamin/.config/nvim/.claude/extensions/cslib -type f | sort`
- `find /home/benjamin/.config/nvim/.claude/extensions/lean -type f | sort`
- `find /home/benjamin/.config/nvim/.claude/skills -type d -name "*hard*" | sort`
- `find /home/benjamin/.config/nvim/.claude/agents -name "*hard*" | sort`
- `find /home/benjamin/.config/nvim/.claude/context/contracts -type f | sort`
- `grep -l "routing_hard" /home/benjamin/.config/nvim/.claude/extensions/*/manifest.json`

### Files Examined

- `.claude/extensions/cslib/manifest.json`
- `.claude/extensions/cslib/agents/cslib-research-agent.md`
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md`
- `.claude/extensions/cslib/skills/skill-cslib-research/SKILL.md`
- `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`
- `.claude/extensions/cslib/EXTENSION.md`
- `.claude/extensions/cslib/context/project/cslib/standards/citation-conventions.md`
- `.claude/extensions/cslib/context/project/cslib/domain/project-organization.md`
- `.claude/extensions/cslib/context/project/cslib/patterns/proof-structure.md`
- `.claude/extensions/lean/manifest.json`
- `.claude/context/guides/extension-development.md` (routing_hard section)
- `.claude/context/contracts/anti-analysis.md`
- `.claude/context/contracts/reference-grounding.md`
- `.claude/skills/skill-implementer-hard/SKILL.md`
- `.claude/skills/skill-researcher-hard/SKILL.md`
- `.claude/agents/general-implementation-hard-agent.md`
- `.claude/agents/general-research-hard-agent.md`
- `specs/669_hard_mode_agent_system/reports/01_hard-mode-orchestration-approach.md`
- `specs/669_hard_mode_agent_system/reports/02_team-research.md`
