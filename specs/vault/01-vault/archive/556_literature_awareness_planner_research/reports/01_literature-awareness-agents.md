# Research Report: Task #556

**Task**: 556 - Add literature awareness to planner, research agents, and lean4 rule
**Started**: 2026-05-12T17:50:00Z
**Completed**: 2026-05-12T18:00:00Z
**Effort**: 1-2 hours
**Dependencies**: Task #553 (completed), Task #554 (completed)
**Sources/Inputs**: Codebase exploration of agent definitions, rules, index files, and literature fidelity policies
**Artifacts**: specs/556_literature_awareness_planner_research/reports/01_literature-awareness-agents.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All four target files have been analyzed; exact insertion points and draft content are provided below
- Task 553's index entry for `literature-fidelity-policy.md` is already in place (loads for `lean-implementation-agent` and `lean-research-agent`)
- The planner-agent needs a new section between Stage 4 (Decompose into Phases) and Stage 5 (Create Plan File) for literature-mirroring guidance
- The lean-research-agent needs a new stage (Stage 1: Literature Extraction) inserted after Stage 0 and before the existing execution flow
- The lean4.md rule needs a new "Literature Fidelity" section appended after the existing content
- Formal research agents (formal-research-agent, logic-research-agent) are noted as potential scope extensions but are NOT included in this task

## Context & Scope

### What was researched

Four files need modification to propagate literature fidelity awareness from the policy documents (created in tasks 553 and 554) into the active agent definitions and auto-applied rules that agents actually read during execution. The policy documents exist but are only loaded as context -- the agents themselves have no instructions on how to use them.

### Constraints

- Changes must be additive (no removal of existing content)
- Must reference the existing literature-fidelity-policy.md rather than duplicating its content
- Planner-agent is a core agent shared across all task types, so literature guidance must be conditional on task type (lean4, formal)

## Findings

### 1. planner-agent.md

**Current Structure** (366 lines):

| Section | Lines | Content |
|---------|-------|---------|
| Frontmatter | 1-5 | name, description, model |
| Overview | 7-11 | Purpose description |
| Context References | 13-21 | @-references for lazy loading |
| Stage 0 | 25-27 | Early metadata |
| Stage 1 | 29-35 | Parse delegation context |
| Stage 2 | 37-56 | Load research report |
| Stage 2a | 50-63 | Load prior plan |
| Stage 2.5 | 65-76 | Load roadmap context |
| Stage 2.6 | 78-114 | Evaluate roadmap flag |
| Stage 3 | 116-130 | Analyze task scope/complexity |
| **Stage 4** | **132-170** | **Decompose into phases** |
| **Stage 5** | **172-278** | **Create plan file** |
| Stage 5a | 280-301 | Emit memory candidates |
| Stage 6 | 303-333 | Verify and write metadata |
| Stage 7 | 335-337 | Return summary |
| Error Handling | 339-344 | Error patterns |
| Critical Requirements | 346-366 | Must/Must-not lists |

**Insertion Point**: After Stage 4 item 7 ("Roadmap Alignment") at line 170, add a new item 8 ("Literature Mirroring"). This keeps the guidance within the existing phase decomposition stage rather than adding a new top-level stage.

Alternatively, add a new **Stage 4.5: Literature-Guided Phase Structuring** between Stage 4 and Stage 5. This is the recommended approach because:
- It is a distinct decision point (not just one consideration among many)
- It needs to fire conditionally based on task type
- It has clear pre-conditions (research report loaded, task type identified)

**Draft Content for Stage 4.5**:

```markdown
### Stage 4.5: Literature-Guided Phase Structuring

When the task type is `lean4` or `formal` AND the research report or task description references a literature source (paper, textbook, proof sketch):

1. **Extract the literature's proof structure** from the research report
   - The lean-research-agent or formal-research-agent should have documented this in a "Literature Proof Structure" section
   - If the research report includes a step-by-step map, use it directly
   - If no structured extraction exists, read the relevant source and identify major proof steps

2. **Mirror the literature's decomposition in plan phases**
   - Each major literature step or proof section should correspond to a plan phase
   - Do NOT reorganize the literature's structure into a "more efficient" ordering
   - Do NOT merge multiple literature steps into one phase unless they are genuinely trivial
   - Preserve the literature's lemma boundaries: if the source proves Lemma A then Lemma B then combines them, create separate phases for each

3. **Label phases with literature references**
   - Phase names should reference the source: "Phase 2: Prove completeness (Theorem 3.2 in [source])"
   - Include the literature step number or section in each phase description
   - This enables the implementation agent to trace each phase back to its source

4. **Handle gaps between literature and formalization**
   - If a literature step requires infrastructure not in the source (e.g., Lean type definitions, Mathlib imports), add a setup phase BEFORE the literature-mirroring phases
   - If the literature omits "obvious" steps, add explicit phases for them with a note: "Implicit in [source], Step N"

**When no literature source is referenced**, skip this stage entirely. Standard phase decomposition from Stage 4 applies.

**Cross-references**:
- Lean extension: `literature-fidelity-policy.md` (anti-patterns, escalation protocol)
- Formal extension: `literature-fidelity-policy.md` (step translation protocol, domain-specific guidance)
```

**Context Reference Addition**: Add to the Context References section:
```markdown
- `@.claude/extensions/lean/context/project/lean4/standards/literature-fidelity-policy.md` - Literature fidelity for Lean tasks (when task_type is lean4)
- `@.claude/extensions/formal/context/project/logic/standards/literature-fidelity-policy.md` - Literature fidelity for formal tasks (when task_type is formal)
```

**Plan Template Addition**: In Stage 5's plan template (the markdown template), add a new subsection under "### Research Integration":
```markdown
### Literature Source Mapping

{If literature-guided: table mapping each plan phase to its literature step/theorem/section. If not literature-guided: "No literature source referenced."}
```

---

### 2. lean-research-agent.md

**Current Structure** (185 lines):

| Section | Lines | Content |
|---------|-------|---------|
| Frontmatter | 1-5 | name, description, model |
| Overview | 7-14 | Purpose, invocation pattern |
| Agent Metadata | 16-20 | Name, purpose, return format |
| BLOCKED TOOLS | 22-33 | lean_diagnostic_messages, lean_file_outline |
| Allowed Tools | 35-68 | File ops, build, MCP tools |
| Search Decision Tree | 70-79 | Tool selection guide |
| Research Constraints | 81-101 | Zero-debt policy compliance |
| **Stage 0** | **103-128** | **Initialize early metadata** |
| Error Handling | 130-155 | MCP tool recovery, rate limits |
| Critical Requirements | 157-185 | MUST/MUST NOT lists |

**Key Observation**: The lean-research-agent currently has NO execution stages beyond Stage 0. It has a Research Constraints section (zero-debt policy) but no structured research execution flow (Stages 1-5 are absent, unlike the general-research-agent or logic-research-agent). The actual research flow is documented in a separate context file: `lean-research-flow.md` (loaded via index-entries.json for lean-research-agent).

**Insertion Strategy**: Add a new section "Literature Extraction Protocol" between the "Research Constraints for Lean Tasks" section (line 101) and "Stage 0" (line 103). This parallels how the zero-debt policy is already documented as a constraint section.

**Draft Content**:

```markdown
### Literature Extraction Protocol

When the task description or focus prompt references a literature source (paper, textbook, proof sketch, or formalization from another proof assistant):

1. **Identify the literature source** from task description, user instructions, or attached files
2. **Extract the proof structure** by documenting:
   - The main theorem/claim being proved
   - The sequence of major proof steps (numbered)
   - Key lemmas or sub-results used
   - The proof strategy (direct, indirect, induction, construction, etc.)
   - Any dependencies between steps
3. **Create a "Literature Proof Structure" section** in the research report with:
   ```markdown
   ## Literature Proof Structure
   
   **Source**: {title, author, section/theorem reference}
   **Strategy**: {proof strategy used in the source}
   
   ### Step Map
   1. {Step 1 description} -- [Source] Section X.Y / Theorem Z
   2. {Step 2 description} -- [Source] Lemma A
   3. ...
   
   ### Dependencies
   - Step 3 depends on Step 1 and Step 2
   - Step 5 depends on Step 4
   
   ### Potential Formalization Challenges
   - {Step N}: {why this step may be hard to translate to Lean}
   ```
4. **Note Lean-specific translation considerations** for each step:
   - Does the step have a direct Lean/Mathlib counterpart?
   - Does the notation need encoding differently?
   - Are there implicit assumptions that need to be made explicit?
5. **Pass the step map to downstream agents** by including it prominently in the research report so the planner-agent can use it for phase decomposition

When no literature source is referenced, skip this protocol. Standard research proceeds per the lean-research-flow.md execution stages.

**Cross-reference**: `literature-fidelity-policy.md` -- Defines the two modes (literature-guided vs. first-principles), anti-patterns, and escalation protocol.
```

**MUST NOT Addition**: Add to the MUST NOT list:
```markdown
14. **Ignore literature sources referenced in the task** -- if a paper or proof is cited, extraction is mandatory
```

---

### 3. lean4.md (Auto-Applied Rule)

**Current Structure** (55 lines):

| Section | Lines | Content |
|---------|-------|---------|
| Frontmatter | 1-3 | paths: "**/*.lean" |
| Title | 5 | "Lean 4 Development Rules" |
| CRITICAL: Blocked MCP Tools | 7-9 | Blocked tools warning |
| Essential MCP Tools | 11-18 | Tool table |
| Search Tools | 20-30 | Rate-limited tools table |
| Search Decision Tree | 32-38 | Tool selection |
| Workflow Pattern | 40-43 | Standard workflow |
| Common Tactics | 45-48 | Tactic categories |
| Build Commands | 50-51 | lake build variants |

This is a compact, reference-card-style rule file. It fires on every `*.lean` file edit and is meant to be terse.

**Insertion Point**: Append a new section after "Build Commands" (line 51). Keep it compact to match the file's style.

**Draft Content**:

```markdown
## Literature Fidelity

When a literature source (paper, textbook, proof sketch) is referenced in the task or plan:

- **Follow the source step-by-step** -- do not seek shortcuts or alternative proofs
- **FORBIDDEN**: Using `simp`/`omega`/`aesop` to bypass steps the literature handles explicitly
- **FORBIDDEN**: Abandoning the literature's approach after a single tactic failure
- **FORBIDDEN**: Mixing literature steps with novel steps without flagging the deviation
- **Escalation**: Re-read source -> try alternative Lean encodings -> check for unstated lemmas -> flag gap to user
- **No literature referenced?** First-principles mode: all tactics and strategies permitted freely

See `literature-fidelity-policy.md` for full policy, anti-pattern catalog, and escalation protocol.
```

---

### 4. lean/index-entries.json

**Verification Result**: Task 553 **already added** the literature-fidelity-policy.md entry (lines 187-207). The entry loads for both `lean-implementation-agent` and `lean-research-agent` when the language is `lean4`.

```json
{
  "path": "project/lean4/standards/literature-fidelity-policy.md",
  "description": "Policy for following literature sources vs. deriving from first principles",
  "tags": ["lean4", "literature", "fidelity", "policy"],
  "load_when": {
    "languages": ["lean4"],
    "agents": ["lean-implementation-agent", "lean-research-agent"]
  },
  "domain": "project",
  "subdomain": "lean",
  "summary": "When to follow provided literature step-by-step vs. derive from first principles"
}
```

**Assessment**: No additional index entries are needed for the lean extension. The existing entry covers both agents that need the policy. The planner-agent does not load from lean/index-entries.json (it uses core context discovery), so the planner's cross-reference will use an @-reference in its Context References section instead.

**One consideration**: Should the planner-agent also be added to the `agents` array in this index entry? No -- the planner-agent is a core agent that operates across all task types. Loading lean-specific context into the planner for every task would be wasteful. Instead, the planner should have a conditional @-reference (as drafted above).

---

### 5. Scope Decisions

**Formal research agents**: The formal extension's `formal-research-agent.md` and `logic-research-agent.md` do NOT currently have literature extraction guidance. However:
- Task 554 already created the formal literature-fidelity-policy.md and registered it in formal/index-entries.json for all 4 research agents plus general-implementation-agent
- The formal agents will load the policy via context discovery
- Adding explicit extraction protocol to formal research agents would be a parallel change to what we are doing for lean-research-agent, but it is NOT in scope for task 556

**Recommendation**: Consider a follow-up task to add Literature Extraction Protocol sections to `formal-research-agent.md` and `logic-research-agent.md`, mirroring what is being added to `lean-research-agent.md`. This would ensure formal research agents also produce structured step maps for downstream planner consumption.

---

## Decisions

1. **Stage 4.5 approach for planner-agent** (rather than adding item 8 to Stage 4): A distinct stage is clearer because literature-guided phase structuring is a conditional decision point, not just another consideration in the decomposition checklist.

2. **Constraint section approach for lean-research-agent** (rather than a new execution stage): The lean-research-agent already has its execution flow in a separate context file (lean-research-flow.md). Adding a "Literature Extraction Protocol" as a constraints section parallels the existing "Zero-Debt Policy Compliance" pattern.

3. **Compact format for lean4.md**: The rule file is a reference card. The Literature Fidelity section should be similarly terse (bullet-point format, no paragraphs) with a cross-reference to the full policy.

4. **No index-entries.json changes needed**: Task 553 already completed this work correctly.

5. **Formal agents out of scope**: Task 556 focuses on the three files explicitly listed. Formal agent updates can be a follow-up.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Planner-agent Stage 4.5 makes plan files longer for non-literature tasks | L | L | Stage is conditional -- skipped when no literature is referenced |
| lean-research-agent protocol creates overhead for simple Lean tasks | L | L | Protocol only activates when a literature source is cited |
| lean4.md rule adds cognitive load on every *.lean edit | M | M | Kept compact (8 lines); "no literature? skip" is the first thing agents read |
| Planner references lean/formal policies but those extensions may not be loaded | M | L | Use conditional @-references ("when task_type is lean4/formal") |

## Appendix

### Files Read
- `.claude/agents/planner-agent.md` (366 lines)
- `.claude/extensions/lean/agents/lean-research-agent.md` (185 lines)
- `.claude/extensions/lean/rules/lean4.md` (55 lines)
- `.claude/extensions/lean/index-entries.json` (555 lines)
- `.claude/extensions/lean/context/project/lean4/standards/literature-fidelity-policy.md` (127 lines)
- `.claude/extensions/formal/agents/formal-research-agent.md` (245 lines)
- `.claude/extensions/formal/agents/logic-research-agent.md` (359 lines)
- `.claude/extensions/formal/context/project/logic/standards/literature-fidelity-policy.md` (258 lines)
- `.claude/extensions/formal/index-entries.json` (1080 lines)

### Key Cross-References
- Lean literature fidelity policy: `.claude/extensions/lean/context/project/lean4/standards/literature-fidelity-policy.md`
- Formal literature fidelity policy: `.claude/extensions/formal/context/project/logic/standards/literature-fidelity-policy.md`
- Lean research flow (separate context): `lean-research-flow.md` (loaded for lean-research-agent)
- Task breakdown guidelines: `.claude/context/workflows/task-breakdown.md`
