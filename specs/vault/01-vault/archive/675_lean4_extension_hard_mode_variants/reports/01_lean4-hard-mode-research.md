# Research Report: Task #675

**Task**: 675 - lean4_extension_hard_mode_variants
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:30:00Z
**Effort**: ~1.5 hours
**Dependencies**: Task 669 (hard_mode_agent_system) - COMPLETED
**Sources/Inputs**: Codebase (lean extension, hard-mode agents/skills/contracts), task 669 reports
**Artifacts**: specs/675_lean4_extension_hard_mode_variants/reports/01_lean4-hard-mode-research.md

---

## Executive Summary

- Core hard-mode infrastructure from task 669 is fully implemented: 4 contracts, 4 hard skills, 3 hard agents, all in place. Task 675 is a lean4-specific overlay, not a ground-up build.
- The lean extension is named `lean` (not `lean4`) and lives at `.claude/extensions/lean/`. It uses `task_type: "lean4"` in its manifest. Its manifest has no `routing_hard` key yet.
- Lean4 needs lean-specific overrides for **H3** (strict transcription with lemma-to-source table), **H5** (sorry inventory as divergence audit output), and **H9** (sorry_inventory field is already in the core wrap-up contract but unused by the lean implementation agent's hard variant).
- **File inventory**: 4 new files (2 agents, 2 skills) + 1 modified file (manifest.json) + 2 new context contracts in the lean extension.
- The existing `lean-research-agent` and `lean-implementation-agent` are already more opinionated than their general counterparts — they have MCP tool restrictions, literature fidelity policy, zero-debt policy, and phase checkpoint protocols. The hard variants must layer hard-mode contracts on top without duplicating these lean-specific rules.

---

## Context & Scope

### What Was Researched

1. Full anatomy of the `lean` extension (manifest, agents, skills, context files)
2. All core hard-mode infrastructure from task 669 (agents, skills, contracts)
3. What lean-specific H-technique overrides are needed vs. what can be reused from core
4. Exact file paths and naming conventions for the new artifacts
5. Integration path: how `routing_hard` works in manifests and is consumed by `command-route-skill.sh`

### Constraints

- The task asks for `lean4` in skill/agent names (`skill-lean-research-hard`, `skill-lean-implementation-hard`, `lean-research-hard-agent`, `lean-implementation-hard-agent`)
- Extension source files live in `.claude/extensions/lean/` — runtime copies go to `.claude/agents/` and `.claude/skills/`
- Must not duplicate lean-specific rules already in the base agents (blocked tools, phase checkpoint, zero-debt policy, MCP fallback table)
- Hard variants reference shared contracts from `.claude/context/contracts/` plus lean-specific extensions in `.claude/extensions/lean/context/contracts/`

---

## Findings

### 1. Current Lean Extension Anatomy

**Extension directory**: `/home/benjamin/.config/nvim/.claude/extensions/lean/`

**Manifest** (`manifest.json`):
- `name: "lean"`, `task_type: "lean4"`, `dependencies: ["core"]`
- Provides: 2 agents (`lean-research-agent.md`, `lean-implementation-agent.md`), 4 skills (`skill-lean-research`, `skill-lean-implementation`, `skill-lake-repair`, `skill-lean-version`), 2 commands, 1 rule
- `routing` keys: research/plan/implement for `lean4`, `lean4:lake`, `lean4:version`
- **No `routing_hard` key** — this is what task 675 must add

**Agents** (both in `.claude/extensions/lean/agents/`):
- `lean-research-agent.md` — Lean4-specific research: MCP tools (blocked list), LeanSearch/Loogle, literature extraction protocol, tactic survey protocol, zero-debt policy for recommendations. Model: **opus**.
- `lean-implementation-agent.md` — Lean4-specific implementation: MCP tools (blocked list), phase checkpoint protocol, progressive handoff, sorry/axiom/vacuous check in final verification, escalation protocol. Model: **opus**.

**Key lean-specific context files** (in `context/project/lean4/standards/`):
- `literature-fidelity-policy.md` — Two modes (literature-guided vs. first-principles); strict step-by-step translation protocol; escalation for untranslatable steps
- `proof-debt-policy.md` — Zero-sorry, zero-axiom completion gate; sorry categories; forbidden sorry-deferral patterns
- `lean4-style-guide.md`, `proof-conventions-lean.md`, `proof-readability-criteria.md` — Style conventions

**Skills** (in `.claude/extensions/lean/skills/`):
- `skill-lean-research/SKILL.md` — Thin wrapper to `lean-research-agent`; postflight: status update, artifact linking, git commit
- `skill-lean-implementation/SKILL.md` — Thin wrapper to `lean-implementation-agent`; postflight: reads verification results from metadata (agent does all verification), plan compliance check from metadata, status update, artifact linking, git commit
- Both skills include explicit MUST NOT lists preventing the skill from re-doing agent work in postflight

### 2. Core Hard-Mode Infrastructure (Already Implemented)

All of the following exist at the `.claude/` runtime level from task 669:

**Contracts** (`.claude/context/contracts/`):
- `anti-analysis.md` — H2: read budget (≤15-20% tool calls), forbidden analysis-only conclusions, defect bar (4-element), sub-sorry policy with lean4 note, settled-design preamble. Has lean4 domain-specialization note pointing to `.claude/extensions/{domain}/context/contracts/anti-analysis.md`
- `reference-grounding.md` — H3: 3 tiers (literature, docs, implementation-backed). Has lean4 domain-specialization note pointing to extension override. **This is where the lean4 strict transcription mandate lives**.
- `wrap-up.md` — H9: orchestrator handoff JSON schema including `sorry_inventory`, continuation handoff markdown, incremental commit discipline. Already has lean4 specialization note for `sorry_inventory`.
- `territory.md` — H7: file territory, plan-section territory, commit protocol, handoff merge rule.
- `convergence.md` — H6: progress criterion declaration, churn-signature definition, three-strikes trigger.

**Hard Agents** (`.claude/agents/`):
- `general-research-hard-agent.md` — H2 + H3 + H4 (adversarial self-verification). Model: sonnet.
- `general-implementation-hard-agent.md` — H2 + H9 + H7 + single-phase focus. Model: sonnet.
- `planner-hard-agent.md` — H8: phase sizing, postmortem constraints, preserved-assets accounting, reference-grounding table.

**Hard Skills** (`.claude/skills/`):
- `skill-researcher-hard/SKILL.md` — Delegates to `general-research-hard-agent`
- `skill-implementer-hard/SKILL.md` — Delegates to `general-implementation-hard-agent` with per-phase dispatch
- `skill-planner-hard/SKILL.md` — Delegates to `planner-hard-agent`
- `skill-orchestrate-hard/SKILL.md` — Full structural variant with per-phase loop, churn detection, audit trigger

**Routing infrastructure**: `command-route-skill.sh` already supports `routing_hard` manifest keys and `-hard` skill suffix fallback. The `--hard` flag is plumbed through all 4 commands (research, plan, implement, orchestrate).

### 3. What Lean4 Overrides are Needed

#### H3: Strict Transcription Mandate (lean4-specific)

**Core reference-grounding.md** defines Tier 1 (literature-backed) as: source-to-implementation mapping table, transcription discipline (source wins over instinct), PDF-level citation. It points to extension overrides for lean4.

**Lean4 needs stricter H3**:
- The mapping table format must be **lemma-level** (not just plan-level): every new Lean lemma names its literature counterpart (source, proposition/lemma number, page).
- The `lean-research-agent` already has a "Literature Extraction Protocol" that creates a "Step Map" section — the hard variant should produce a full lemma-to-source table instead (more granular).
- `literature-fidelity-policy.md` already enforces translation faithfulness during implementation; the hard variant bakes this more explicitly into the research output format.
- **Contract location**: `.claude/extensions/lean/context/contracts/reference-grounding.md` (new file, overrides core for lean4 agents)

#### H5: Formal Divergence Audit (lean4-specific)

**Core convergence.md** describes the three-strikes audit trigger at the orchestrator level. The audit content (what to output) is left to the research agent.

**Lean4 needs a sorry-specific divergence audit format**:
- When `focus_prompt` contains "divergence" or "audit", the agent must output:
  1. Sorry inventory table: every sorry with `{file, line, statement, what_was_tried, why_stuck}`
  2. Type-mismatch analysis: where our formalization diverges from the literature's type structure
  3. Divergence table: our statement vs literature statement per object (MATCHES / STRONGER / WEAKER / DIFFERENT with consequence)
  4. Corrected targets: Lean-ready statement with all indices explicit
  5. Postmortem: specific mistakes causing the deflections
- The `general-research-hard-agent` already has divergence audit mode triggered by `focus_prompt`; lean4 needs the same but with sorry-inventory output and type-mismatch analysis.
- **This is handled in the agent prompt**, not a separate contract file.

#### H8: Lemma-to-Source Mapping (lean4-specific plan requirement)

**Core `planner-hard-agent.md`** includes a reference-grounding table requirement in H8.

**Lean4 plan format requires**:
- The mapping table in the plan must be **lemma-level**: each phase lists the new Lean definitions/theorems and their literature source (author, proposition number, page).
- This is enforced via the lean4-specific reference-grounding contract, not a separate plan rule.
- The `planner-hard-agent` is general; for lean4 tasks, the lean4 research hard agent's output (which includes the lemma-to-source table) feeds the planner. The planner then preserves it.
- **No separate lean4 planner hard agent needed** — the planner-hard-agent's H8 requirement + a lemma-to-source table from the research report is sufficient. However, the lean4 research hard agent must produce this table in the correct format.

#### H9: Sorry Inventory in Handoff (lean4-specific)

**Core wrap-up.md** already includes `sorry_inventory` in the handoff JSON schema with a lean4 note: "sorry_inventory is mandatory and must be populated. Each sorry includes the statement (verbatim from source), the location (file:line), and the justification."

**The general-implementation-hard-agent** has wrap-up contract enforcement; its `sorry_inventory` field is written as empty `[]` (since general tasks have no sorries). The **lean4 hard implementation agent** must:
- Populate `sorry_inventory` with actual sorry tracking
- Each entry: `{file, line, statement, assumption, why_deferred, next_dispatch}`
- Integrate with the existing lean agent's zero-debt policy: sorries in the inventory should be **only leaf sub-sorries** (anti-analysis.md sub-sorry policy), not main theorem stubs
- The `sorry_inventory` in the handoff enables the orchestrator to detect sorry relocation (the H5 churn signature)

### 4. File Inventory: What to Create

**New files in `.claude/extensions/lean/`** (4 total):

| File | Type | Size Est. | Description |
|------|------|-----------|-------------|
| `agents/lean-research-hard-agent.md` | Agent | ~200 lines | Extends lean-research-agent with H2, H3 (lean4 strict), H4 (adversarial self-verify), H5 (divergence audit mode with sorry inventory) |
| `agents/lean-implementation-hard-agent.md` | Agent | ~250 lines | Extends lean-implementation-agent with H2 (formal proof line bar), H9 (sorry inventory tracking), single-phase focus |
| `skills/skill-lean-research-hard/SKILL.md` | Skill | ~150 lines | Thin wrapper to lean-research-hard-agent; same postflight as skill-lean-research; logs adversarial_verification_triggered |
| `skills/skill-lean-implementation-hard/SKILL.md` | Skill | ~180 lines | Thin wrapper to lean-implementation-hard-agent with per-phase dispatch context; same postflight as skill-lean-implementation |

**New lean4 contract files** (in `context/contracts/` of the lean extension, 2 total):

| File | Size Est. | Description |
|------|-----------|-------------|
| `context/contracts/reference-grounding.md` | ~80 lines | Lean4 Tier 1 override: lemma-level mapping table format, strict transcription discipline, sorry-inventory cross-reference, PDF section citation requirement |
| `context/contracts/anti-analysis.md` | ~50 lines | Lean4 H2 override: adds formal proof line bar (first sorry-free lemma within 20 tool calls), tightens forbidden conclusions for proof contexts |

**Modified files**:

| File | Change |
|------|--------|
| `manifest.json` | Add `routing_hard` key with `lean4: "skill-lean-research-hard"` (research) and `lean4: "skill-lean-implementation-hard"` (implement) |
| `EXTENSION.md` | Add Lean Hard Mode section to the extension's CLAUDE.md contribution (skill-agent mapping rows for hard agents) |
| `index-entries.json` | Add entries for the 2 new context contract files with `load_when.agents` pointing to hard agents |

**Total: 6 new files, 3 modified files.**

*(Note: The task description mentions "lean hard agents" plural — both research and implementation hard agents are created. The `skill-lean-version` and `skill-lake-repair` skills do not need hard variants since they are utility/repair skills, not research/implementation skills for the H-technique use case.)*

### 5. Agent Structure: What to Inherit vs. Override

**`lean-research-hard-agent.md`** must:
- Inherit from `lean-research-agent`: blocked tool list (lean_diagnostic_messages, lean_file_outline), all lean-lsp tool descriptions, search decision tree, rate limit handling, zero-debt policy for recommendations
- **Add** (hard mode additions):
  - Context @-references: `contracts/anti-analysis.md` (lean4 override), `contracts/reference-grounding.md` (lean4 override)
  - H2 enforcement: read budget; first MCP search or file read must yield a concrete lemma candidate within 20 tool calls
  - H3: Tier 1 mandatory for literature-backed tasks; output format is **lemma-level mapping table** (columns: Source | Prop/Location | Lean Identifier | Type Signature | Status)
  - H4: Mandatory adversarial self-verification pass; `## Adversarial Self-Verification` section in report
  - H5: Divergence audit mode (triggered by `focus_prompt` containing "divergence" or "audit"): sorry inventory table, type-mismatch analysis, divergence table with MATCHES/STRONGER/WEAKER/DIFFERENT verdict per object, corrected Lean-ready targets, postmortem

**`lean-implementation-hard-agent.md`** must:
- Inherit from `lean-implementation-agent`: blocked tool list, phase checkpoint protocol, progressive handoff, sorry/axiom/vacuous verification in final verification stage, escalation protocol, zero-debt policy (NO sorry in implemented status)
- **Add** (hard mode additions):
  - Context @-references: `contracts/anti-analysis.md` (lean4 override), `contracts/wrap-up.md` (core H9)
  - H2 lean4 bar: first sorry-free lemma (not just any file write) within 20 tool calls
  - Settled-design preamble at start of each phase
  - H9 sorry inventory: populate `sorry_inventory` in `.orchestrator-handoff.json` with all leaf sub-sorries introduced; each entry: `{file, line, statement, assumption, why_deferred, next_dispatch}`
  - Single-phase focus: when `phase_number` is set in delegation context, implement only that phase
  - H9 incremental commits: commit at each green-build milestone (this aligns with the existing lean agent's phase-granular commit protocol — it already does this)

### 6. Routing Integration

The `manifest.json` will get a `routing_hard` section:

```json
"routing_hard": {
  "research": {
    "lean4": "skill-lean-research-hard"
  },
  "implement": {
    "lean4": "skill-lean-implementation-hard"
  }
}
```

Plan routing for lean4 hard mode: the core `skill-planner-hard` handles lean4 tasks without a lean4-specific planner (the lemma-to-source table is produced by the research agent and consumed by the planner; the planner-hard-agent's H8 requirements already cover it). The manifest does not need a `routing_hard.plan` entry — the core planner hard variant handles it.

`command-route-skill.sh` already checks `routing_hard.$operation.$task_type` before falling back to the `-hard` suffix heuristic. Adding the `routing_hard` key to the lean manifest is sufficient for routing to work.

---

## Decisions

1. **6 new files, not 4**: In addition to the 4 skill/agent files, 2 lean4-specific contract overrides are needed (reference-grounding and anti-analysis). This matches the architecture established in task 669 where domain extensions override contracts in their extension context directory.

2. **No lean4 planner hard agent**: The core `planner-hard-agent` + the lemma-to-source table output from the lean4 research hard agent is sufficient. Adding a lean4-specific planner would duplicate ~200 lines with no lean4-specific behavioral change. Decision: do not create `lean-planner-hard-agent.md`.

3. **Sorry inventory is in the handoff, not a new file**: H9 sorry inventory is a field in `.orchestrator-handoff.json`, not a separate tracking file. This keeps the handoff self-contained for orchestrator consumption.

4. **Lean4 hard agents inherit lean-specific rules from base agents, not via @-references**: The hard agent files should include the full lean-specific rule sections (blocked tools, zero-debt policy, escalation protocol) rather than using @-references to the base agents. This prevents agent loading issues and keeps each agent fully self-contained. The @-references are only for contracts (anti-analysis, reference-grounding, wrap-up).

5. **Model choice**: Following task 669's recommendation and the existing lean agent precedent (model: opus), both lean4 hard agents use **opus**. This is consistent: lean4 work requires deep reasoning for formal proofs, and hard mode adds behavioral contracts that benefit from the more capable model.

6. **Extension context contracts location**: New contract overrides go in `context/contracts/` within the lean extension source (`.claude/extensions/lean/context/contracts/`). The `provides.context` array in the manifest gets a new entry: `"contracts"` (or the individual file paths). The `index-entries.json` adds `load_when.agents` entries so they're loaded when lean4 hard agents run.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Agent self-containment: hard agents may duplicate lean-specific rules from base agents | Medium | Explicitly include full lean-specific sections (blocked tools, zero-debt, escalation) in hard agent files rather than @-referencing base agent |
| Sorry inventory pollution: orchestrator misreads leaf sub-sorries as blockers | Medium | H9 handoff schema: distinguish `sorry_inventory` (leaf sub-sorries, not blockers) from `blockers` (phases that couldn't complete). Document in contracts. |
| Contract override path: lean4 contract files need to be discoverable by agents | Medium | Add `load_when.agents: ["lean-research-hard-agent", "lean-implementation-hard-agent"]` to index-entries.json for the new contract files |
| `provides.context` vs `index-entries.json` mismatch | Low | Add both: `provides.context` entry for the `contracts` directory, and explicit `index-entries.json` entries for load conditions |
| H2 formal proof line bar (first sorry-free lemma in 20 tool calls): lean4 goals may need 30+ tool calls for type-checking alone | Medium | The bar is guidance, not a hard count. The anti-analysis.md lean4 override should state: "first committed lemma (sorry-free) within the first 30% of tool calls" rather than "20 tool calls" |
| Routing: `routing_hard` key adds lean4 research/implement but not plan — user may pass `--hard` to `/plan` for lean4 tasks and get the core planner hard agent | Low | This is correct behavior; document explicitly in EXTENSION.md |
| Manifest `provides.skills` must list new skill directories | Low | Add `"skill-lean-research-hard"` and `"skill-lean-implementation-hard"` to `provides.skills` array |

---

## Context Extension Recommendations

- **Topic**: Lean4 hard-mode contract overrides directory
- **Gap**: The lean extension has no `context/contracts/` directory yet; a new subdirectory needs to be created as part of this task
- **Recommendation**: Create `.claude/extensions/lean/context/contracts/` and add it to `provides.context` in the manifest. Add entries to `index-entries.json` for both contract files.

- **Topic**: EXTENSION.md Lean Hard Mode section
- **Gap**: The current `EXTENSION.md` in the lean extension has no mention of hard-mode routing
- **Recommendation**: Add a "Lean Hard Mode" subsection in EXTENSION.md with the routing table and skill-agent mapping rows for the two new hard agents. This content appears in CLAUDE.md when the extension is loaded.

---

## Appendix

### Files Examined

- `/home/benjamin/.config/nvim/.claude/extensions/lean/manifest.json`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/agents/lean-research-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/agents/lean-implementation-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/skills/skill-lean-research/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/context/project/lean4/standards/literature-fidelity-policy.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/context/project/lean4/standards/proof-debt-policy.md`
- `/home/benjamin/.config/nvim/.claude/agents/general-research-hard-agent.md`
- `/home/benjamin/.config/nvim/.claude/agents/general-implementation-hard-agent.md`
- `/home/benjamin/.config/nvim/.claude/agents/planner-hard-agent.md`
- `/home/benjamin/.config/nvim/.claude/context/contracts/anti-analysis.md`
- `/home/benjamin/.config/nvim/.claude/context/contracts/reference-grounding.md`
- `/home/benjamin/.config/nvim/.claude/context/contracts/wrap-up.md`
- `/home/benjamin/.config/nvim/.claude/context/guides/extension-development.md`
- `/home/benjamin/.config/nvim/specs/669_hard_mode_agent_system/reports/01_hard-mode-orchestration-approach.md`
- `/home/benjamin/.config/nvim/specs/669_hard_mode_agent_system/reports/02_team-research.md`

### Key Naming Note

The extension is named `lean` (directory, manifest name), but uses `task_type: "lean4"` and the agents/skills are named with `lean-` prefix. New hard variants follow the same `lean-` prefix convention: `lean-research-hard-agent`, `lean-implementation-hard-agent`, `skill-lean-research-hard`, `skill-lean-implementation-hard`. The task description uses `lean4` in skill names (`skill-lean-research-hard` — this is already the conventional naming since the extension's task_type is `lean4`).

### Sorry Inventory Entry Schema (for implementation)

```json
{
  "file": "Theories/MyTheory.lean",
  "line": 142,
  "statement": "theorem convergence_bound : ∀ n, bound n ≤ limit",
  "assumption": "Requires Rabinovich 3.2.2 instantiation not yet formalized",
  "why_deferred": "Leaf sub-sorry: depends on Phase 4 output which is in progress",
  "next_dispatch": "Phase 4: formalize Rabinovich instantiation"
}
```

### Divergence Audit Output Format (for lean4 hard research agent H5 mode)

```markdown
## Divergence Audit

### Sorry Inventory
| File | Line | Statement | Attempted Tactics | Failure Reason |
|------|------|-----------|-------------------|----------------|
| Theories/X.lean | 142 | theorem X : P → Q | simp, aesop, omega | type mismatch on Q |

### Divergence Table
| Object | Our Statement | Literature Statement | Verdict | Consequence |
|--------|--------------|---------------------|---------|-------------|
| `main_thm` | ∀ n m, ... | ∀ n, ∃ m, ... | WEAKER | Missing witness construction |

### Corrected Targets
- `main_thm` Lean-ready: `theorem main_thm (n : ℕ) : ∃ m, bound n m := ...`
  - Indices: n is the depth parameter (explicit), m is the witness (existential)
  - Downstream consumers: `corollary_A` uses `m` value directly

### Postmortem
- Mistake 1: ...
- Mistake 2: ...
```
