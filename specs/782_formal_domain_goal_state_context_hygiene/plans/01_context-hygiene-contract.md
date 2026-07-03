# Implementation Plan: Task #782 - Formal-domain context hygiene

- **Task**: 782 - Formal-domain context hygiene: reduce per-step context lean4/formal agents consume
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None (complementary to task 781; not blocking)
- **Research Inputs**: reports/01_formal-domain-context-hygiene.md
- **Artifacts**: plans/01_context-hygiene-contract.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta

## Overview

Author a new standalone context-hygiene contract for the Lean/CSLib formal domains and wire it
into the four hard agents that consume Lean goal states, so enormous goal-state dumps stop
overflowing context. The contract packages four discipline clauses (targeted goal-state queries,
bounded file reads, hypothesis pruning, and transcript summarization) as MUST/SHOULD rules, and it
introduces usage guidance for two under-documented tools: `lean_minimal_hypotheses` (live but
undocumented) and `Read` with `offset`/`limit` as the mandated substitute for the currently BLOCKED
`lean_file_outline`. The task also closes a wiring gap (research hard agents lack the
`context-exhaustion-detection.md` reference their implementation counterparts have) and flags a
manual cross-repo re-install step, since the Lean/CSLib extensions are consumed by
`/home/benjamin/Projects/cslib` via `source_dir` pointers. Definition of done: contract file
authored, registered in `index-entries.json`, referenced + summarized inline in all four hard
agents, `lean_minimal_hypotheses` documented, exhaustion-detection gap closed, and the sync step
surfaced in the summary/handoff.

### Research Integration

Report `reports/01_formal-domain-context-hygiene.md` established: (1) the contract belongs at
`.claude/extensions/lean/context/contracts/context-hygiene.md` as a NEW standalone contract (no core
baseline to override); (2) the four consumers are `lean-research-hard-agent`,
`lean-implementation-hard-agent`, `cslib-research-hard-agent`, `cslib-implementation-hard-agent`,
each self-contained and requiring a `## Context References` bullet plus an inline internalization
section matching the `anti-analysis.md` two-touch pattern; (3) `lean_file_outline` is BLOCKED
repo-wide so the contract must prescribe `Read` with `offset`/`limit`, pointing at
`blocked-mcp-tools.md` as the single source of truth for block status; (4) `lean_minimal_hypotheses`
is a live MCP tool absent from all `.claude/` docs; (5) the two research hard agents lack the
`context-exhaustion-detection.md` reference; (6) the extensions are installed into a separate repo
by file-copy, so a re-install flag must be surfaced manually.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- Create `.claude/extensions/lean/context/contracts/context-hygiene.md` as a short standalone
  contract (target ~70 lines, matching `anti-analysis.md`) with the four discipline clauses and an
  Enforcement paragraph.
- Register the contract in `.claude/extensions/lean/index-entries.json` with `load_when.agents`
  listing exactly the four hard-agent consumers.
- Wire all four hard agents: `## Context References` bullet marked MANDATORY + a 5-8 line inline
  internalization section, using identical shared text across all four to prevent drift.
- Add `lean_minimal_hypotheses` to each hard agent's Allowed Tools list and document it in
  `mcp-tools-guide.md`.
- Close the wiring gap: add `context-exhaustion-detection.md` to `lean-research-hard-agent` and
  `cslib-research-hard-agent`.
- Cross-reference `context-exhaustion-detection.md` from the new contract (preventive vs. reactive).
- Surface the cross-repo re-install step in the implementation summary and handoff.

**Non-Goals**:
- Editing any file under `/home/benjamin/Projects/cslib` or running the re-install there (flag only).
- Wiring the four base (non-hard) agents (deferred follow-up; task scope is hard agents).
- Implementing task 781's checkpoint-before-overflow mechanism (cross-reference only).
- Un-blocking `lean_file_outline` or modifying `blocked-mcp-tools.md` block status.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Wording drifts across the four self-contained agent files | M | M | Phase 1 defines the exact shared Context-References bullet + inline block; Phases 3-4 paste verbatim |
| New contract inflates hard-agent context budget, working against the goal | M | M | Keep contract ~70 lines and inline summary 5-8 lines, matching anti-analysis sizing |
| `lean_file_outline` gets unblocked upstream and contract goes stale | L | L | Contract points at `blocked-mcp-tools.md` as single source of truth; does not hardcode block status |
| Cross-repo sync step forgotten; contract never reaches consuming repo | H | M | Explicit checked item in final phase + surfaced in summary and `.orchestrator-handoff.json` |
| `index-entries.json` malformed after edit breaks context loading | H | L | Phase 6 validates JSON with `jq empty` and confirms the new entry resolves |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 5 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel. Phases 3 and 4 edit disjoint agent files
(lean vs. cslib); Phase 2 edits `index-entries.json`; Phase 5 edits `mcp-tools-guide.md` — no
territory overlap within a wave.

### Phase 1: Author the context-hygiene contract [COMPLETED]

- **Goal:** Create the standalone contract file and lock the exact shared wiring text that Phases
  3-4 will paste into the four agents.
- **Tasks:**
  - [x] Create `.claude/extensions/lean/context/contracts/context-hygiene.md` titled
    "Goal-State Context Hygiene Contract — Lean4/CSLib" (standalone identity, does NOT claim to
    override a core file).
  - [x] Clause 1 (Goal-state query discipline): prefer `lean_goal` at a specific line/column over
    broad queries; use `lean_minimal_hypotheses` for only-relevant hypotheses; use `lean_term_goal`
    for expected-type-only checks; summarize returned goals in <=3 transcript lines rather than
    pasting raw MCP output every step; re-query precisely by exact line/column.
  - [x] Clause 2 (File-read discipline): `Read` with explicit `offset`/`limit` bounding the active
    proof's enclosing declaration plus small margin; no whole-file reads of large `Theories/`/
    `Cslib/` files; no re-reading a region already read in the same dispatch; note
    `lean_file_outline` remains BLOCKED and point at `blocked-mcp-tools.md` as the single source of
    truth for block status (do not hardcode the block).
  - [x] Clause 3 (Hypothesis pruning): prefer `lean_minimal_hypotheses` over the full hypothesis
    list from a raw `lean_goal`; do not carry forward hypotheses irrelevant to the current tactic;
    when summarizing, list only hypotheses the planned tactic references.
  - [x] Clause 4 (Packaging): express clauses 1-3 as MUST/SHOULD rules with a short "Enforcement"
    paragraph mirroring `anti-analysis.md` style; add explicit cross-reference to
    `@.claude/context/patterns/context-exhaustion-detection.md` (preventive hygiene here vs.
    reactive checkpointing there / task 781).
  - [x] At the bottom of this plan's working notes, record the EXACT `## Context References` bullet
    string and the EXACT 5-8 line inline internalization block to be pasted verbatim in Phases 3-4.
- **Timing:** ~45 min
- **Depends on:** none
- **Files to create:**
  - `.claude/extensions/lean/context/contracts/context-hygiene.md` - new contract (~70 lines)
- **Verification:** File exists; length within ~60-80 lines; contains four labeled clauses, an
  Enforcement paragraph, and the exhaustion-detection cross-reference; block status is referenced
  (not hardcoded) via `blocked-mcp-tools.md`.

### Phase 2: Register the contract in the lean extension index [COMPLETED]

- **Goal:** Make the new contract auto-load for exactly the four hard-agent consumers.
- **Tasks:**
  - [x] Add an entry to `.claude/extensions/lean/index-entries.json` with `path`
    `contracts/context-hygiene.md`, appropriate `description`/`tags`/`summary`, and
    `load_when.agents` = `["lean-research-hard-agent", "lean-implementation-hard-agent",
    "cslib-research-hard-agent", "cslib-implementation-hard-agent"]` (mirroring the existing
    `contracts/anti-analysis.md` entry structure, but with all four agents).
  - [x] Confirm no `manifest.json` edit is needed (the `contracts` directory is already declared at
    directory level in `provides.context`).
- **Timing:** ~20 min
- **Depends on:** 1
- **Files to modify:**
  - `.claude/extensions/lean/index-entries.json` - append one entry
- **Verification:** `jq empty` passes; new entry present with all four agents in `load_when.agents`.

### Phase 3: Wire the two Lean hard agents [COMPLETED]

- **Goal:** Reference + internalize the contract in the Lean hard agents and close the exhaustion
  gap for lean research.
- **Tasks:**
  - [x] `lean-research-hard-agent.md`: add the shared `## Context References` bullet (MANDATORY) for
    `context-hygiene.md`; add the shared inline internalization section (5-8 lines); add
    `lean_minimal_hypotheses` to the Lean MCP Tools allowed list; ADD the missing
    `@.claude/context/patterns/context-exhaustion-detection.md` reference to Context References
    (companion wiring-gap fix).
  - [x] `lean-implementation-hard-agent.md`: add the shared `## Context References` bullet
    (MANDATORY) for `context-hygiene.md`; add the shared inline internalization section; add
    `lean_minimal_hypotheses` to the allowed list. (Already references exhaustion-detection — no
    companion fix needed here.)
  - [x] Paste the Context-References bullet and inline block VERBATIM from Phase 1 to avoid drift.
- **Timing:** ~35 min
- **Depends on:** 1
- **Files to modify:**
  - `.claude/extensions/lean/agents/lean-research-hard-agent.md`
  - `.claude/extensions/lean/agents/lean-implementation-hard-agent.md`
- **Verification:** Both files reference `context-hygiene.md` in Context References and contain the
  inline block; both list `lean_minimal_hypotheses`; `lean-research-hard-agent` now references
  `context-exhaustion-detection.md`.

### Phase 4: Wire the two CSLib hard agents [COMPLETED]

- **Goal:** Reference + internalize the contract in the CSLib hard agents and close the exhaustion
  gap for cslib research.
- **Tasks:**
  - [x] `cslib-research-hard-agent.md`: add the shared `## Context References` bullet (MANDATORY) for
    `context-hygiene.md`; add the shared inline internalization section; add
    `lean_minimal_hypotheses` to the allowed list; ADD the missing
    `@.claude/context/patterns/context-exhaustion-detection.md` reference (companion wiring-gap fix).
  - [x] `cslib-implementation-hard-agent.md`: add the shared `## Context References` bullet
    (MANDATORY) for `context-hygiene.md`; add the shared inline internalization section; add
    `lean_minimal_hypotheses` to the allowed list. (Already references exhaustion-detection.)
  - [x] Use the reference form consistent with these files' existing convention
    (`@.claude/extensions/lean/context/contracts/context-hygiene.md`), pasting the inline block
    VERBATIM from Phase 1.
- **Timing:** ~35 min
- **Depends on:** 1
- **Files to modify:**
  - `.claude/extensions/cslib/agents/cslib-research-hard-agent.md`
  - `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md`
- **Verification:** Both files reference `context-hygiene.md` and contain the inline block; both list
  `lean_minimal_hypotheses`; `cslib-research-hard-agent` now references
  `context-exhaustion-detection.md`.

### Phase 5: Document lean_minimal_hypotheses in the MCP tools guide [COMPLETED]

- **Goal:** Give `lean_minimal_hypotheses` a documented home in the shared tools reference.
- **Tasks:**
  - [x] Add a `lean_minimal_hypotheses` entry to
    `.claude/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md` (Core Tools section):
    what it returns (minimal relevant hypotheses at a position), when to prefer it over a raw
    `lean_goal` local-context dump, and its role in hypothesis pruning per the new contract.
  - [x] Cross-link the entry to `context-hygiene.md`.
- **Timing:** ~20 min
- **Depends on:** none
- **Files to modify:**
  - `.claude/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md`
- **Verification:** Guide contains a `lean_minimal_hypotheses` entry with usage guidance and a link
  to the contract.

### Phase 6: Validate wiring and flag cross-repo sync [COMPLETED]

- **Goal:** Confirm consistency across all touched files and surface the manual re-install step.
- **Tasks:**
  - [x] Run `jq empty` on `index-entries.json`; confirm the new entry loads for the four agents.
  - [x] Grep all four hard agents to confirm each references `context-hygiene.md`, contains the
    inline block, lists `lean_minimal_hypotheses`, and (both research agents) references
    `context-exhaustion-detection.md`.
  - [x] Confirm the inline block text is byte-identical across all four agents (drift check).
  - [x] Record the FLAGGED manual sync step in the implementation summary: re-run
    `.claude/scripts/install-extension.sh .claude/extensions/lean` (and `.../extensions/cslib` if
    cslib context files were touched) inside every consuming repo — at minimum
    `/home/benjamin/Projects/cslib` — to copy the new contract over. Do NOT edit or run anything in
    the other repo.
- **Timing:** ~25 min
- **Depends on:** 2, 3, 4, 5
- **Files to modify:**
  - `specs/782_formal_domain_goal_state_context_hygiene/summaries/01_*-summary.md` (created at
    implementation time)
- **Verification:** All greps pass; inline blocks identical; JSON valid; summary contains the
  flagged sync step.

## Working Notes: Shared Wiring Text (Phase 1 output, pasted verbatim in Phases 3-4)

**Context References bullet** (identical in all four hard agents):

```
- `@.claude/extensions/lean/context/contracts/context-hygiene.md` - Goal-state query discipline, bounded file reads, hypothesis pruning (MANDATORY)
```

**Inline internalization block** (identical in all four hard agents, inserted as its own
`##`-level section near the other contract-enforcement sections):

```
## Context Hygiene Contract Enforcement

Before querying Lean goal state or reading Lean source, internalize from
`@.claude/extensions/lean/context/contracts/context-hygiene.md`:

- **Targeted goal queries**: prefer `lean_goal` at a specific line/column,
  `lean_minimal_hypotheses` for relevant-only hypotheses, `lean_term_goal` for
  expected-type-only checks; summarize results in <=3 transcript lines instead of pasting
  raw MCP output every step
- **Bounded file reads**: `Read` with `offset`/`limit` around the active declaration; no
  whole-file reads of large `Theories/`/`Cslib/` files; no re-reading an already-read region
- **Hypothesis pruning**: carry forward only hypotheses the planned tactic references

**Enforcement**: a raw unsummarized goal dump repeated for the same position, a whole-file
read when only one declaration was needed, or irrelevant hypotheses left in a summary is a
violation — correct the next step immediately.
```

## Testing & Validation

- [x] `jq empty .claude/extensions/lean/index-entries.json` exits 0 and the new entry lists all four
  hard agents in `load_when.agents`.
- [x] `grep -l context-hygiene` finds all four hard-agent files.
- [x] `grep -l lean_minimal_hypotheses` finds all four hard-agent files and `mcp-tools-guide.md`.
- [x] `lean-research-hard-agent.md` and `cslib-research-hard-agent.md` now contain
  `context-exhaustion-detection`.
- [x] The inline internalization block is byte-identical across the four agents.
- [x] `context-hygiene.md` references `blocked-mcp-tools.md` for `lean_file_outline` block status
  (not hardcoded) and cross-references `context-exhaustion-detection.md`.

## Artifacts & Outputs

- `.claude/extensions/lean/context/contracts/context-hygiene.md` (new)
- `.claude/extensions/lean/index-entries.json` (modified: +1 entry)
- `.claude/extensions/lean/agents/lean-research-hard-agent.md` (modified)
- `.claude/extensions/lean/agents/lean-implementation-hard-agent.md` (modified)
- `.claude/extensions/cslib/agents/cslib-research-hard-agent.md` (modified)
- `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` (modified)
- `.claude/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md` (modified)
- `specs/782_formal_domain_goal_state_context_hygiene/summaries/01_*-summary.md` (created at
  implement time; must contain the flagged cross-repo sync step)

## Rollback/Contingency

All changes are confined to this repo's `.claude/` tree and are additive. To revert: delete
`context-hygiene.md`, remove its `index-entries.json` entry, and `git checkout` the four agent files
and `mcp-tools-guide.md`. Because the change is additive and the contract only loads for the four
hard agents, a partial landing (e.g., contract authored but not yet wired) is non-breaking — the
unreferenced file simply goes unused until wiring completes. The cross-repo consuming copy is
untouched until the user re-runs `install-extension.sh`, so no external repo can be left in a broken
state by this task.
