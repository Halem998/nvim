# Research Report: OpenCode Seed Lean Agent Integrity

- **Task**: 567 - opencode_seed_lean_agent_integrity
- **Started**: 2026-05-13T00:00:00Z
- **Completed**: 2026-05-13T01:00:00Z
- **Effort**: 1 hour
- **Dependencies**: Task 564 (escalation protocol applied to ProofChecker + .claude/ agents), Task 565 (plan compliance gate + checkpoint-gate-out applied to ProofChecker)
- **Sources/Inputs**:
  - `.opencode/extensions/lean/agents/lean-implementation-agent.md` — current state (231 lines, missing escalation, vacuous check, Phase Checkpoint)
  - `.opencode/extensions/lean/rules/lean4.md` — current state (missing Vacuous Definitions section)
  - `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md` — current state (263 lines, has Stage 6 Zero-Debt Gate but no Stage 6b, no complexity warning, no conditional Stage 9)
  - `.opencode/context/checkpoints/checkpoint-gate-out.md` — current state (no section 2b)
  - `.claude/extensions/lean/agents/lean-implementation-agent.md` — reference (364 lines, task 564 complete)
  - `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` — reference (Stage 6b, conditional Stage 9, complexity warning)
  - `/home/benjamin/Projects/ProofChecker/.opencode/context/checkpoints/checkpoint-gate-out.md` — reference (section 2b)
  - `specs/564_*/summaries/01_escalation-protocol-summary.md`
  - `specs/565_*/summaries/01_compliance-gate-summary.md`
- **Artifacts**: `specs/567_opencode_seed_lean_agent_integrity/reports/01_opencode-seed-integrity-research.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Project Context

- **Upstream Dependencies**: Task 564 (establishes all content to mirror), Task 565 (Stage 6b, compliance hook, conditional commit content)
- **Downstream Dependents**: New projects created via `<leader>al` picker will inherit the .opencode/ seed; all future ProofChecker-style lean projects depend on this template
- **Alternative Paths**: None — mirror existing changes from task 564/565 reference implementations
- **Potential Extensions**: Once both architectures are updated, extract shared goal-name parser into `.opencode/scripts/` or `.opencode/skills/` shared utility

## Executive Summary

- The nvim `.opencode/` seed at `~/.config/nvim/.opencode/` is used by `<leader>al` to initialize new OpenCode projects; it is NOT the ProofChecker instance
- Four files need updating: `lean-implementation-agent.md`, `lean4.md`, `SKILL.md`, and `checkpoint-gate-out.md`
- All changes mirror what tasks 564–565 did to ProofChecker, using the ProofChecker files as exact reference
- The `.opencode/` seed SKILL.md already has a Zero-Debt Verification Gate (Stage 6) but lacks vacuous_count check, Stage 6b plan compliance gate, complexity warning, and conditional Stage 9
- The `lean-implementation-agent.md` seed has Zero-Debt Gate but lacks escalation protocol, vacuous prohibition, and Phase Checkpoint Protocol
- All changes are backward compatible; the ProofChecker instance in `/home/benjamin/Projects/ProofChecker/.opencode/` is NOT modified by this task

## Context & Scope

### What Is the nvim .opencode/ Seed?

`~/.config/nvim/.opencode/` is a template directory. When the user runs `<leader>al` in Neovim, a picker copies this seed into a new project directory, providing a pre-configured OpenCode agent system (skills, agents, rules, context, extensions). The lean extension in the seed provides lean-implementation-agent.md, lean4.md, SKILL.md, and other lean-specific artifacts.

The ProofChecker at `/home/benjamin/Projects/ProofChecker/` is one project that was initialized from an older version of this seed and has since been individually updated (tasks 564–565). This task ensures future projects seeded from nvim get all the same improvements.

### File-by-File Analysis

**File 1: `.opencode/extensions/lean/agents/lean-implementation-agent.md` (231 lines)**

Current sections:
- BLOCKED TOOLS, Allowed Tools
- Phase Status Updates (MANDATORY)
- Stage 0: Initialize Early Metadata
- **Zero-Debt Completion Gate** (line 117) — has sorry, axiom, build checks but NO vacuous_count check
- Error Handling (MCP, Build Failure, Proof Stuck)
- Context Management (Handoff Triggers, Handoff Protocol)
- **Critical Requirements** (line 204) — MUST DO (11 items), MUST NOT (12 items)

Missing vs. `.claude/` reference (364 lines):
1. **vacuous_count** check step 2 in Zero-Debt Gate
2. **Escalation Protocol (MANDATORY)** section (3 steps: mark [BLOCKED], document blocker, return partial)
3. **Phase Checkpoint Protocol** section (per-phase git commits)
4. **MUST NOT item 13** (vacuous prohibition with all prohibited patterns)
5. The Zero-Debt Gate also needs to be renamed from "Zero-Debt Completion Gate" to "Zero-Debt Completion Gate" — same name, but it needs the vacuous_count check added. Actually the name differs: .opencode/ seed says "Zero-Debt Completion Gate" while .claude/ says "Final Verification Stage". The .opencode/ ProofChecker instance uses "Zero-Debt Verification Gate". Keep .opencode/ seed naming consistent with ProofChecker: "Zero-Debt Completion Gate" (already correct in seed).

**File 2: `.opencode/extensions/lean/rules/lean4.md`**

Identical to `.claude/extensions/lean/rules/lean4.md` (both verified by reading — same content, same missing section). Need to add "Vacuous Definitions (PROHIBITED)" section after the existing "Literature Fidelity" section.

**File 3: `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md` (263 lines)**

Current stages:
- Stage 1: Input Validation
- Stage 2: Preflight Status Update
- Stage 3: Prepare Delegation Context
- Stage 4: Invoke Subagent
- Stage 5: Parse Subagent Return
- **Stage 6: Zero-Debt Verification Gate** (line 146) — has sorry_count, build check but NO vacuous_count check
- Stage 7: Update Task Status
- Stage 8: Link Artifacts
- Stage 9: Git Commit (line 209) — unconditional batch commit (no conditional per-phase detection)
- Stage 10: Return Brief Summary

Missing vs. ProofChecker SKILL.md:
1. **Task Complexity Warning** in Stage 1 (GATE IN) — extract effort_hours from plan, warn if >20h
2. **vacuous_count** check in Stage 6 Zero-Debt Verification Gate
3. **Stage 6b: Plan Compliance Spot-Check** — deliverable existence + integrity check (insert after Stage 6)
4. **Conditional Stage 9** — check for per-phase commits, skip batch commit if they exist

**File 4: `.opencode/context/checkpoints/checkpoint-gate-out.md`**

Currently identical to `.claude/context/checkpoints/checkpoint-gate-out.md` (no lean4 section 2b). Add section 2b verbatim from ProofChecker's checkpoint-gate-out.md.

## Findings

### Gap Summary

| File | Lines Now | Lines Target | Key Gaps |
|------|-----------|--------------|----------|
| lean-implementation-agent.md | 231 | ~330 | vacuous check, escalation protocol, phase checkpoint, item 13 |
| lean4.md | ~70 | ~110 | Vacuous Definitions (PROHIBITED) section |
| SKILL.md | 263 | ~350 | complexity warning, vacuous check, Stage 6b, conditional Stage 9 |
| checkpoint-gate-out.md | ~65 | ~90 | Section 2b lean4 compliance hook |

### Source of Truth for Each Change

| Change | Source File |
|--------|------------|
| vacuous_count grep in Zero-Debt Gate | `.claude/extensions/lean/agents/lean-implementation-agent.md` lines 131-137 |
| Escalation Protocol | `.claude/extensions/lean/agents/lean-implementation-agent.md` lines 228-277 |
| Phase Checkpoint Protocol | `.claude/extensions/lean/agents/lean-implementation-agent.md` lines 283-307 |
| MUST NOT item 13 (vacuous prohibition) | `.claude/extensions/lean/agents/lean-implementation-agent.md` lines 357-364 |
| Vacuous Definitions section (lean4.md) | `/home/benjamin/Projects/ProofChecker/.opencode/rules/lean4.md` lines 56-98 |
| Task Complexity Warning | `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` lines 56-73 |
| vacuous_count check in Stage 6 | `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` lines 179-191 |
| Stage 6b plan compliance gate | `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` lines 198-268 |
| Conditional Stage 9 | `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` lines 309-345 |
| Checkpoint section 2b | `/home/benjamin/Projects/ProofChecker/.opencode/context/checkpoints/checkpoint-gate-out.md` lines 30-52 |

### Architecture: No Adaptation Needed

Unlike task 566 (which must adapt postflight-tool-restrictions.md to avoid grep in postflight), the `.opencode/` seed SKILL.md runs in an OpenCode context where the skill CAN run shell commands directly in postflight. The ProofChecker SKILL.md Stage 6b (which runs grep in the skill) is the correct reference — no adaptation needed. Copy verbatim.

## Decisions

1. **All changes mirror ProofChecker verbatim** — no adaptation needed (OpenCode skill can run grep in postflight)
2. **Source of truth**: Use `.claude/` agent as reference for agent changes; use ProofChecker SKILL.md as reference for skill changes
3. **Insert Stage 6b** between Stage 6 and Stage 7 (do not renumber Stage 7–10)
4. **complexity warning in Stage 1** uses same grep pattern as ProofChecker
5. **Conditional Stage 9** uses `git log --oneline -10 | grep -q "phase [0-9]+:"` pattern
6. **lean4.md**: copy Vacuous Definitions section from ProofChecker lean4.md verbatim

## Recommendations

### Implementation Order

1. `.opencode/extensions/lean/rules/lean4.md` — append Vacuous Definitions section (simplest)
2. `.opencode/extensions/lean/agents/lean-implementation-agent.md` — add vacuous_count, escalation protocol, phase checkpoint, item 13
3. `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md` — add complexity warning, vacuous_count, Stage 6b, conditional Stage 9
4. `.opencode/context/checkpoints/checkpoint-gate-out.md` — add section 2b

### Change Details

**lean-implementation-agent.md changes**:
- Zero-Debt Gate: add step 2 (vacuous_count grep) after sorry_count step; update "On Verification Failure" to mention vacuous definitions; add `vacuous_count` to verification JSON
- After Context Management section: add Escalation Protocol section (3 steps)
- After Escalation Protocol: add Phase Checkpoint Protocol section
- Critical Requirements MUST NOT: add item 13 vacuous prohibition

**lean4.md change**:
- Append full "Vacuous Definitions (PROHIBITED)" section at end of file

**SKILL.md changes**:
- Stage 1 GATE IN: add "Task Complexity Warning" subsection after plan_file lookup
- Stage 6: add vacuous_count check after sorry_count check
- After Stage 6: insert Stage 6b (Plan Compliance Spot-Check) with Step 1–4
- Stage 9: replace unconditional git commit with conditional (skip if per-phase commits exist)

**checkpoint-gate-out.md change**:
- Insert section "2b. Lean4-Specific: Plan Compliance Verification" between sections 2 and 3

## Risks & Mitigations

- **Risk**: Escalation Protocol references ProofChecker-specific paths like `Theories/` — OK, this is a Lean 4 seed and Theories/ is the standard directory
- **Risk**: Stage 6b grep patterns may be fragile if copied without testing → **Mitigated**: patterns are identical to ProofChecker which is in use
- **Risk**: Conditional Stage 9 regex `"phase [0-9]+:"` could match non-phase commits → **Mitigated**: same risk exists in ProofChecker; low probability
- **Risk**: vacuous_count grep uses extended regex requiring bash grep → **Mitigated**: grep -P or grep -E pattern consistent with ProofChecker

## Appendix

### Key File Paths

| File | Path |
|------|------|
| lean-implementation-agent.md (seed) | `.opencode/extensions/lean/agents/lean-implementation-agent.md` |
| lean4.md (seed) | `.opencode/extensions/lean/rules/lean4.md` |
| SKILL.md (seed) | `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md` |
| checkpoint-gate-out.md (seed) | `.opencode/context/checkpoints/checkpoint-gate-out.md` |
| .claude/ agent (reference for agent changes) | `.claude/extensions/lean/agents/lean-implementation-agent.md` |
| ProofChecker SKILL.md (reference for skill changes) | `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` |
| ProofChecker checkpoint (reference for section 2b) | `/home/benjamin/Projects/ProofChecker/.opencode/context/checkpoints/checkpoint-gate-out.md` |
| ProofChecker lean4.md (reference for vacuous section) | `/home/benjamin/Projects/ProofChecker/.opencode/rules/lean4.md` |
