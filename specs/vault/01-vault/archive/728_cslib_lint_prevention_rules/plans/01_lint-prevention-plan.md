# Implementation Plan: CSLib Lint Prevention Rules

- **Task**: 728 - cslib_lint_prevention_rules
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/728_cslib_lint_prevention_rules/reports/01_lint-prevention-research.md
- **Artifacts**: plans/01_lint-prevention-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add 7 lint prevention rules to the cslib extension agents to close a CI pipeline gap where environment linters (docBlame, defLemma, defsWithUnderscore, simpNF, unusedSectionVars, topNamespace, dupNamespace) only run in a weekly cron but not in PR CI. The implementation creates a new context file with the rules, updates the implementation agent to require compliance, adds a targeted lint verification step, and adds awareness to the research agent. All changes are additive within `.claude/extensions/cslib/`.

### Research Integration

The research report (01_lint-prevention-research.md) documents the CI pipeline gap in detail: PR CI runs `lake build` and `lake exe lint-style` but not `lake lint` for environment linters. The report defines all 7 rules with examples and violation patterns drawn from the tasks 208-213 cleanup of 850+ accumulated lint errors.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly addressed by this task. This is an agent quality improvement that aligns with the "Agent System Quality" section's theme of enforcement and validation.

## Goals & Non-Goals

**Goals**:
- Create a comprehensive lint prevention rules reference document for cslib agents
- Make lint prevention mandatory in the implementation agent's workflow
- Add targeted lint verification after `lake build` passes
- Add research agent awareness so plans account for lint requirements early

**Non-Goals**:
- Modifying the CSLib project's CI pipeline itself (upstream concern)
- Creating automated pre-commit hooks or scripts
- Changing the lean or core extensions

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Rules file too verbose for agent context budget | M | L | Keep to ~120 lines; concise examples only |
| Agent ignores lint section in long prompt | M | L | Place after existing CI section for natural flow; use MANDATORY heading |
| Targeted lint grep misses new linter categories | L | L | Grep pattern covers all 7 known categories; update if new ones added |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create Lint Prevention Rules Context File [COMPLETED]

**Goal**: Create the reference document containing all 7 lint prevention rules with examples.

**Tasks**:
- [ ] Create `.claude/extensions/cslib/context/project/cslib/standards/lint-prevention-rules.md` with the 7 rules from the research report
- [ ] Register the new file in `.claude/extensions/cslib/index-entries.json` with `load_when` targeting `cslib-implementation-agent`, `cslib-implementation-hard-agent`, and task type `cslib`

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/lint-prevention-rules.md` - New file with 7 rules
- `.claude/extensions/cslib/index-entries.json` - Add new entry

**Content specification for lint-prevention-rules.md**:

The file should contain:
1. Title and overview explaining the CI pipeline gap (environment linters not in PR CI, only weekly cron)
2. Each of the 7 rules as a subsection with:
   - Rule name and which linter it prevents
   - The requirement stated clearly
   - One concise code example showing correct vs incorrect
3. Keep total length under 120 lines for context budget efficiency

The 7 rules (from research report):
1. Mandatory Docstrings (prevents docBlame)
2. Correct Declaration Keywords (prevents defLemma)
3. CamelCase Names (prevents defsWithUnderscore)
4. Verify @[simp] Before Adding (prevents simpNF)
5. Minimal Section Variables (prevents unusedSectionVars)
6. Namespace Instances (prevents topNamespace)
7. No Redundant Qualified Names (prevents dupNamespace)

**Index entry to add**:
```json
{
  "path": "project/cslib/standards/lint-prevention-rules.md",
  "description": "CSLib lint prevention rules: 7 rules for environment linters not caught by PR CI",
  "tags": ["cslib", "lint", "prevention", "environment-linters"],
  "load_when": {
    "languages": ["cslib"],
    "agents": ["cslib-implementation-agent", "cslib-implementation-hard-agent"]
  },
  "domain": "project",
  "subdomain": "cslib",
  "summary": "7 lint prevention rules (docBlame, defLemma, defsWithUnderscore, simpNF, unusedSectionVars, topNamespace, dupNamespace) for agent enforcement"
}
```

**Verification**:
- File exists and is under 120 lines
- All 7 rules present with examples
- Index entry added with correct path and agents

---

### Phase 2: Update Implementation Agent Instructions [COMPLETED]

**Goal**: Add a mandatory lint prevention section to cslib-implementation-agent.md.

**Tasks**:
- [ ] Add a `## Lint Prevention (Mandatory)` section to `cslib-implementation-agent.md` after the "CSLib Style Compliance" section and before "Pull Request Standards"
- [ ] Reference the new context file via `@` notation
- [ ] Add lint prevention items to the MUST DO and MUST NOT lists

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` - Add lint prevention section and update critical requirements

**Insertion point**: After the "### Variable Names" / "### Documentation" / "### Init Import" block (end of CSLib Style Compliance section, around line 279), before "## Pull Request Standards" (line 283).

**Content to insert**:
```markdown
## Lint Prevention (Mandatory)

Environment linters (`lake lint`) are NOT in PR CI -- they only run in a weekly cron. You MUST prevent lint errors proactively. Load and follow @.claude/extensions/cslib/context/project/cslib/standards/lint-prevention-rules.md for every declaration you write.

Key rules:
- Every `def`, `theorem`, `lemma`, `instance`, `structure`, `inductive` MUST have a `/-- ... -/` docstring
- Prop-valued declarations MUST use `lemma` or `theorem`, not `def`
- Declaration names MUST use lowerCamelCase (no underscores)
- Verify `@[simp]` lemmas do not have redundant LHS
- Use `omit` for unused section variables
- Wrap `instance` declarations in explicit namespaces
- Do not repeat namespace prefix in declaration names
```

**MUST DO addition** (append to existing list):
```
17. **Follow all 7 lint prevention rules** from lint-prevention-rules.md for every new declaration
```

**MUST NOT addition** (append to existing list):
```
17. **Write declarations without docstrings** -- mandatory per docBlame linter
18. **Use `def` for Prop-valued declarations** -- use `lemma` or `theorem` per defLemma linter
19. **Use underscores in declaration names** -- use lowerCamelCase per defsWithUnderscore linter
```

**Verification**:
- Lint Prevention section present between Style Compliance and PR Standards
- MUST DO / MUST NOT lists updated
- `@` reference to context file included

---

### Phase 3: Add Targeted Lint Verification Step [COMPLETED]

**Goal**: Add a targeted lint check to the CI verification pipeline in the implementation agent.

**Tasks**:
- [ ] Add a new step 3a after step 3 (Environment linters) in the "CSLib CI Pipeline (Ordered)" section that filters `lake lint` output for the 7 specific lint categories on modified files
- [ ] Add guidance text explaining this targeted check catches the weekly-only linters

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` - Add targeted lint check after step 3

**Insertion point**: After step 3 (Environment linters, `lake lint` at line 175-176), before step 4 (Text linters at line 178).

**Content to insert after step 3**:
```markdown

   **Post-lint check**: If `lake lint` reports warnings in files you modified, grep for the 7 prevention categories:
   ```bash
   lake lint 2>&1 | grep -E "docBlame|defLemma|defsWithUnderscore|simpNF|unusedSectionVars|topNamespace|dupNamespace"
   ```
   Fix any matches before proceeding. These categories are NOT in PR CI and accumulate silently.
```

**Verification**:
- Post-lint check text present after step 3
- Grep pattern includes all 7 categories
- Guidance explains these are not in PR CI

---

### Phase 4: Add Research Agent Awareness [COMPLETED]

**Goal**: Add lint prevention awareness to cslib-research-agent.md so research reports and plan recommendations account for lint requirements.

**Tasks**:
- [ ] Add a "### Lint Prevention Awareness" subsection to the "Research Constraints for CSLib Tasks" section in cslib-research-agent.md
- [ ] Reference the lint prevention rules file

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/agents/cslib-research-agent.md` - Add lint awareness section

**Insertion point**: After the "### Zero-Debt Policy Compliance" section (around line 130), before "### Literature Extraction Protocol" (line 147).

**Content to insert**:
```markdown
### Lint Prevention Awareness

Environment linters (`lake lint`) are NOT in PR CI -- only in a weekly cron. When recommending implementation approaches, account for these lint requirements:

- All new declarations need docstrings (docBlame)
- Prop-valued declarations must use `lemma`/`theorem` not `def` (defLemma)
- Names must use lowerCamelCase, no underscores (defsWithUnderscore)
- `@[simp]` requires LHS verification (simpNF)
- Section variables should be minimal; use `omit` where needed (unusedSectionVars)
- Instance declarations need explicit namespace wrapping (topNamespace)
- No namespace-prefix repetition in declaration names (dupNamespace)

See @.claude/extensions/cslib/context/project/cslib/standards/lint-prevention-rules.md for full rules.
```

**Verification**:
- Lint Prevention Awareness section present in research agent
- All 7 categories mentioned
- `@` reference to context file included

## Testing & Validation

- [ ] Verify lint-prevention-rules.md exists and contains all 7 rules
- [ ] Verify index-entries.json has the new entry with correct path and load_when
- [ ] Verify cslib-implementation-agent.md has Lint Prevention section with mandatory heading
- [ ] Verify cslib-implementation-agent.md has post-lint check in CI pipeline section
- [ ] Verify cslib-implementation-agent.md MUST DO and MUST NOT lists are updated
- [ ] Verify cslib-research-agent.md has Lint Prevention Awareness section
- [ ] Confirm all file paths are within `.claude/extensions/cslib/`

## Artifacts & Outputs

- `.claude/extensions/cslib/context/project/cslib/standards/lint-prevention-rules.md` (new)
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` (modified)
- `.claude/extensions/cslib/agents/cslib-research-agent.md` (modified)
- `.claude/extensions/cslib/index-entries.json` (modified)
- `specs/728_cslib_lint_prevention_rules/plans/01_lint-prevention-plan.md` (this file)

## Rollback/Contingency

All changes are additive. Rollback by reverting the git commit. No existing behavior is modified -- only new sections and files are added.
