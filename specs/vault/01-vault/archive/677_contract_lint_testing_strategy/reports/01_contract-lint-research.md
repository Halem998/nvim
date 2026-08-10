# Research Report: Task #677

**Task**: 677 - contract_lint_testing_strategy
**Started**: 2026-06-12T18:00:00Z
**Completed**: 2026-06-12T18:28:20Z
**Effort**: 2 hours
**Dependencies**: Task 669 (hard_mode_agent_system)
**Sources/Inputs**:
  - `specs/669_hard_mode_agent_system/reports/01_hard-mode-orchestration-approach.md`
  - `specs/669_hard_mode_agent_system/reports/02_team-research.md`
  - `.claude/context/contracts/` (all 5 contract files)
  - `.claude/agents/*-hard-agent.md` (all 3 hard-mode agent files)
  - `.claude/skills/skill-*-hard/SKILL.md` (all 4 hard-mode skill files)
  - `.claude/scripts/lint/lint-postflight-boundary.sh` (existing lint pattern)
  - `.claude/scripts/validate-wiring.sh` (existing validation pattern)
  - `.claude/scripts/validate-artifact.sh` (existing artifact validation)
**Artifacts**: - `specs/677_contract_lint_testing_strategy/reports/01_contract-lint-research.md`
**Standards**: report-format.md, artifact-formats.md

## Executive Summary

- The hard-mode behavioral contracts (anti-analysis, reference-grounding, convergence, territory,
  wrap-up) are primarily prompt-level specifications living in `.claude/context/contracts/`. Static
  analysis can verify structural contract compliance (file existence, @-reference wiring,
  frontmatter fields, index.json entries) with high confidence, covering roughly 40% of
  the testable property space.
- Runtime contract compliance (e.g., whether an agent actually reads files before writing, or
  whether a churn counter triggers at exactly 3 strikes) cannot be verified without executing
  agents against live prompts. This is feasible but expensive and brittle; a lightweight
  alternative (structured trace parsing) is the recommended approach.
- The existing project already has `validate-wiring.sh`, `validate-artifact.sh`, and
  `lint-postflight-boundary.sh` as proven patterns. The highest-value first deliverable is a
  new lint script (`lint-contract-compliance.sh`) that checks static contract properties.
- Recommended phasing: (1) static contract lint in `.claude/scripts/lint/` (highest value, low
  cost), (2) hard-mode wiring validation extension to `validate-wiring.sh` (medium value, low
  cost), (3) structured handoff validation (medium value, medium cost), (4) runtime trace
  harness (low value for cost; defer or skip).

## Context & Scope

The task asks for a testing strategy targeting hard-mode behavioral correctness, specifically:
contract lint rules that verify agents honor anti-analysis budgets, reference grounding
requirements, and convergence policing thresholds. The scope includes both static analysis
(checking agent files, skills, and the context index for structural compliance) and runtime
harnesses (replaying known deflection-prone prompts to check for contract violations).

Task 669 implemented the hard-mode system. Task 677 designs how to verify that it was
implemented correctly and remains correct as it evolves.

### What Was Already Built (669)

Five contract files in `.claude/context/contracts/`:
- `anti-analysis.md` -- H2 contract: read budget (15-20%), forbidden conclusions, defect bar,
  settled-design preamble. 68 lines.
- `reference-grounding.md` -- H3 contract: three-tier grounding (literature, docs, code). 75 lines.
- `convergence.md` -- H6 contract: churn detection, three-strikes rule, user-authorization. 73 lines.
- `territory.md` -- H7 contract: file ownership, commit protocol, handoff merge. 82 lines.
- `wrap-up.md` -- H9 contract: handoff JSON schema, continuation markdown, incremental commits. 94 lines.

Three hard-mode agents: `general-research-hard-agent.md`, `planner-hard-agent.md`,
`general-implementation-hard-agent.md`.

Four hard-mode skills: `skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard`,
`skill-orchestrate-hard`.

Routing infrastructure: `command-route-skill.sh` with `effort_flag` 4th argument;
`skill-orchestrate-hard/SKILL.md` with full churn-detection state machine.

## Findings

### Codebase Patterns: What's Already Testable

#### Existing Lint Scripts (Pattern Reference)

The project already has three lint/validation scripts that establish the coding pattern:

1. **`lint-postflight-boundary.sh`** (170 lines): Checks skills for prohibited patterns in
   postflight sections (build commands, grep on source files, MCP tool references). Uses `awk`
   to extract sections, `grep` for pattern matching. Exit code 0/1. This is the most relevant
   pattern for new contract lint rules.

2. **`validate-wiring.sh`** (306 lines): Validates agent/skill existence, skill-to-agent
   references, index.json entries. Covers core agents but has NO checks for hard-mode agents
   (the three hard agents are not checked). No checks for contract files at all.

3. **`validate-artifact.sh`** (164 lines): Validates research reports, plans, and summaries
   against required metadata fields and section headings. Does NOT check hard-mode plan
   sections (no check for `## Postmortem Constraints`, wave maps, phase sizing estimates).

#### What Contract Files Actually Specify

From reading all five contracts, the **statically-checkable properties** are:

**Anti-analysis contract (H2)** -- checkable statically:
- Agent file MUST have Context References section listing `@.claude/context/contracts/anti-analysis.md`
- Agent file MUST mention "Forbidden Conclusions" and "Defect Bar" in execution flow
- Skill file MUST dispatch to a hard-mode agent (not the base agent)
- Hard-mode implementation agent MUST have "Single-Phase Focus" behavior described

**Reference grounding (H3)** -- partially checkable:
- Research agent MUST reference `contracts/reference-grounding.md` in Context References
- Planner agent MUST reference `contracts/reference-grounding.md`
- Plans from `planner-hard-agent` MUST include a source-to-implementation mapping table
  (checkable post-hoc on plan artifacts via `validate-artifact.sh` extension)

**Convergence policing (H6)** -- partially checkable:
- `skill-orchestrate-hard/SKILL.md` MUST contain `churn_file` and `churn_state` variable definitions
- `skill-orchestrate-hard/SKILL.md` MUST reference `contracts/convergence.md`
- The churn JSON schema MUST include `total_churn`, `target_churn`, `adversarial_triggers`
  (checkable against the actual file via `grep`)

**Territory contract (H7)** -- partially checkable:
- Implementation agent MUST reference `contracts/territory.md` in Context References
- Skill MUST pass territory parameters when dispatching (checkable via grep for "territory" in
  the delegation context assembly)
- `skill-orchestrate-hard` MUST include territory parameter construction logic

**Wrap-up contract (H9)** -- checkable statically and partially at runtime:
- Implementation agent MUST reference `contracts/wrap-up.md` in Context References
- Skill MUST check for `.orchestrator-handoff.json` in postflight
- Handoff JSON schema MUST contain the required fields: `status`, `phases_completed`,
  `phases_total`, `sorry_inventory`, `blockers`, `continuation_path`
  (checkable via grep on the agent/skill files for schema documentation)

#### Index.json Coverage Gaps

Current index.json `load_when.agents` for contracts:
- `anti-analysis.md`: loaded for `general-implementation-hard-agent`, `general-research-hard-agent`
- `reference-grounding.md`: loaded for `general-research-hard-agent`, `planner-hard-agent`
- `convergence.md`: loaded for NO agents (empty load_when.agents array)
- `territory.md`: loaded for `general-implementation-hard-agent`
- `wrap-up.md`: loaded for `general-implementation-hard-agent`

Gap: `convergence.md` is not auto-loaded for any agent. It should be loaded for
`skill-orchestrate-hard` (which is direct execution, not an agent) -- but the skill reads it
as a reference file, not via the index. However, if a downstream agent needs convergence
knowledge, there is no auto-loading path. This may be intentional (skill reads it directly).

#### validate-wiring.sh Hard-Mode Gap

The current `validate-wiring.sh` checks:
- Core agents: `general-research-agent`, `general-implementation-agent`, `planner-agent`, `meta-builder-agent`
- Core skills: `skill-researcher`, `skill-implementer`, `skill-planner`, `skill-meta`

It does NOT check:
- Hard-mode agents: `general-research-hard-agent`, `planner-hard-agent`, `general-implementation-hard-agent`
- Hard-mode skills: `skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard`, `skill-orchestrate-hard`
- Contract files in `.claude/context/contracts/`
- Index.json entries for hard-mode agents

### Contract Violation Patterns (from Research Reports)

From Report 01 (`01_hard-mode-orchestration-approach.md`), the specific observable signatures
of contract violations are:

**Anti-analysis (H2) violations**:
- `"the approach is wrong"` -- forbidden conclusion per contract, detectable in agent output
- `"a different representation is needed"` -- forbidden conclusion
- `"estimated N lines"` as the final answer -- forbidden conclusion
- 15+ tool calls with no Write or Edit -- measurable from execution traces
- Agent output contains only analysis without any file creation/modification

**Reference grounding (H3) violations**:
- Claims without citations in research output -- post-hoc checkable in report text
- Plans without source-to-implementation mapping table when Tier 1 task -- plan lint
- `## Adversarial Self-Verification` section missing from hard research reports

**Convergence policing (H6) violations**:
- Three-strikes rule not triggered despite same target appearing in 3+ churn cycles --
  observable in the churn state JSON file (`churn_file`) contents
- Architectural pivot implemented without AskUserQuestion -- only observable in execution logs
- `total_churn` counter not incremented despite churn signatures detected

**Territory (H7) violations**:
- Agent modifies files outside declared `owned_files` territory -- detectable in git diff
- Handoff JSON clobbered instead of merged -- detectable in handoff file contents

**Wrap-up (H9) violations**:
- `.orchestrator-handoff.json` not written after dispatch -- file existence check
- Handoff missing required fields (`status`, `blockers`, `continuation_path`) -- JSON schema check
- All changes committed in one final commit instead of incrementally -- git log analysis
- No `## Adversarial Self-Verification` in hard research report -- section presence check

### Taxonomy of Testable Contract Properties

#### Tier 1: Fully Static (File Content Checks)

These can be checked purely by reading files, with no execution required.

| Property | What to Check | Where | Confidence |
|----------|---------------|-------|------------|
| Contract @-reference in hard agents | `@.claude/context/contracts/*.md` in Context References | Agent .md files | High |
| Hard agent frontmatter | `name:`, `model:`, correct agent name | Agent .md files | High |
| Contract files exist on disk | All 5 contract files in `contracts/` | Filesystem | High |
| Skill dispatches to hard agent | Agent name appears in SKILL.md | Skill SKILL.md files | High |
| Skill frontmatter | `name:`, `allowed-tools:` correctness | Skill SKILL.md files | High |
| Churn state fields in orchestrate-hard | `total_churn`, `target_churn` appear | skill-orchestrate-hard/SKILL.md | High |
| H2 vocabulary in implementation agent | "forbidden conclusions", "defect bar", "single-phase" | Agent .md | Medium |
| H9 handoff schema in implementation agent | `status`, `blockers`, `continuation_path` | Agent .md | Medium |
| Index.json coverage | Hard agents appear in `load_when.agents` of relevant contracts | index.json | High |
| Hard-mode wiring completeness | validate-wiring.sh extended to check hard agents/skills | Both | High |

#### Tier 2: Artifact-Level Static (Post-Hoc on Task Outputs)

These check artifacts after hard-mode tasks have run, not the configuration files themselves.

| Property | What to Check | Where | Confidence |
|----------|---------------|-------|------------|
| Adversarial verification section present | `## Adversarial Self-Verification` heading | Research reports | High |
| Hard plan postmortem section | `## Postmortem Constraints` heading | Plan files | High |
| Hard plan phase sizing | Each `### Phase N:` has "Estimated output" and "Done when" | Plan files | Medium |
| Hard plan wave map | Dependency Analysis table with Wave column | Plan files | Medium |
| Handoff file schema | Required fields in `.orchestrator-handoff.json` | Handoff JSON | High |
| Handoff written on partial | File exists when `phases_completed < phases_total` | Handoff JSON | High |
| Continuation path valid | `continuation_path` not null for partial status | Handoff JSON | High |

#### Tier 3: Dynamic/Behavioral (Runtime Traces)

These require observing agent execution, which is expensive and only possible with trace access.

| Property | What to Check | Method | Confidence | Cost |
|----------|---------------|--------|------------|------|
| Read budget compliance | First Write/Edit within 20% of tool calls | Tool call trace | High | Very High |
| No forbidden conclusions in output | No F1-F6 violation phrases in response text | Response grep | Medium | High |
| Churn counter increments | `churn_file` state changes across cycles | State file monitoring | High | Medium |
| Three-strikes fires at correct count | Audit dispatch triggered after 3 churn events | Orchestration log | High | Very High |
| Territory boundary respected | No writes outside `owned_files` | Git diff + territory | Medium | Medium |
| Incremental commits | Multiple commits per dispatch vs one final | `git log --oneline` | High | Low |
| Handoff not clobbered | Handoff merge protocol followed | Handoff diff | Medium | Low |

### Existing Test Infrastructure Assessment

**What exists**:
- No test directory or test runner for the `.claude/` system
- No CI integration for `.claude/` correctness (ci-workflow.md explicitly states that
  skills/agents/context files skip CI by default)
- Three lint/validate scripts covering postflight boundaries, wiring, and artifact format
- `check-extension-docs.sh` for extension documentation completeness

**What's missing**:
- No contract-aware lint rules
- No hard-mode-specific wiring checks
- No plan artifact checks for hard-mode sections (postmortem, phase sizing, wave map)
- No handoff schema validation
- No runtime testing of any kind for agent behavioral compliance

**Assessment**: The project uses bash-based lint scripts as the validation paradigm. This is
the right approach for the agent system -- it keeps validation within the existing toolchain,
requires no additional language runtimes, and can be integrated into the CI workflow when
needed. A new contract lint script should follow the same pattern as `lint-postflight-boundary.sh`.

## Recommendations

### 1. Static Contract Lint Script (`lint-contract-compliance.sh`)

**Location**: `.claude/scripts/lint/lint-contract-compliance.sh`  
**Size**: ~200-250 lines  
**Pattern**: Follows `lint-postflight-boundary.sh` (grep-based, section-aware, colored output)

Checks to implement (in priority order):

**A. Hard-agent contract @-references** (highest value):
```bash
# For each hard agent, verify required contracts are @-referenced
check_agent_contracts() {
  local agent="$1"
  local required_contracts=("${@:2}")
  for contract in "${required_contracts[@]}"; do
    grep -q "@.claude/context/contracts/$contract" "$agent" || \
      VIOLATION "$agent: missing @-reference to contracts/$contract"
  }
}
check_agent_contracts "general-implementation-hard-agent.md" \
  "anti-analysis.md" "wrap-up.md" "territory.md"
check_agent_contracts "general-research-hard-agent.md" \
  "anti-analysis.md" "reference-grounding.md"
check_agent_contracts "planner-hard-agent.md" \
  "reference-grounding.md"
```

**B. Contract file existence and H-technique references**:
```bash
for contract in anti-analysis reference-grounding convergence territory wrap-up; do
  [ -f ".claude/context/contracts/$contract.md" ] || VIOLATION "contracts/$contract.md missing"
  grep -q "This contract implements H" ".claude/context/contracts/$contract.md" || \
    VIOLATION "contracts/$contract.md: missing H-technique reference"
done
```

**C. Skill-to-hard-agent dispatch**:
```bash
grep -q "general-implementation-hard-agent" skill-implementer-hard/SKILL.md || \
  VIOLATION "skill-implementer-hard does not dispatch to hard agent"
grep -q "general-research-hard-agent" skill-researcher-hard/SKILL.md || \
  VIOLATION "skill-researcher-hard does not dispatch to hard agent"
grep -q "planner-hard-agent" skill-planner-hard/SKILL.md || \
  VIOLATION "skill-planner-hard does not dispatch to hard agent"
```

**D. Convergence policing fields in skill-orchestrate-hard**:
```bash
for field in "total_churn" "target_churn" "adversarial_triggers" "audit_dispatches"; do
  grep -q "$field" skill-orchestrate-hard/SKILL.md || \
    VIOLATION "skill-orchestrate-hard: missing churn field $field"
done
grep -q "contracts/convergence.md" skill-orchestrate-hard/SKILL.md || \
  VIOLATION "skill-orchestrate-hard: missing convergence.md reference"
```

**E. H2 vocabulary in implementation agent**:
```bash
for phrase in "Forbidden Conclusions" "Defect Bar" "single-phase" "settled-design"; do
  grep -qi "$phrase" general-implementation-hard-agent.md || \
    VIOLATION "implementation-hard-agent: missing H2 vocabulary: $phrase"
done
```

**F. Index.json contract coverage**:
```bash
for agent in "general-implementation-hard-agent" "general-research-hard-agent"; do
  jq -r ".entries[] | select(.load_when.agents[]? == \"$agent\") | .path" \
    .claude/context/index.json | grep -q "contracts/" || \
    VIOLATION "index.json: no contract entries loaded for $agent"
done
```

### 2. Hard-Mode Wiring Extension to `validate-wiring.sh`

Add a `validate_hard_mode_system()` function called from `main()`:

```bash
validate_hard_mode_system() {
  echo ""
  log_info "Validating hard-mode system wiring..."
  
  # Hard agents
  for agent in general-research-hard-agent planner-hard-agent \
               general-implementation-hard-agent; do
    validate_agent_exists "$CLAUDE_DIR/agents" "$agent"
  done
  
  # Hard skills
  for skill in skill-researcher-hard skill-planner-hard \
               skill-implementer-hard skill-orchestrate-hard; do
    [ -d "$CLAUDE_DIR/skills/$skill" ] && log_pass "Hard skill: $skill" || \
      log_fail "Hard skill missing: $skill"
  done
  
  # Contract files
  for contract in anti-analysis reference-grounding convergence territory wrap-up; do
    [ -f "$CLAUDE_DIR/context/contracts/$contract.md" ] && \
      log_pass "Contract: $contract.md" || \
      log_fail "Contract missing: $contract.md"
  done
  
  # Index entries for hard agents
  validate_index_entries "$CLAUDE_DIR" "general-implementation-hard-agent"
  validate_index_entries "$CLAUDE_DIR" "general-research-hard-agent"
  validate_index_entries "$CLAUDE_DIR" "planner-hard-agent"
}
```

### 3. Hard-Mode Plan Artifact Checks in `validate-artifact.sh`

Extend the `plan` type checks for hard-mode plans:

```bash
# When plan file contains "planner-hard-agent" in metadata or "hard-mode" in title
if grep -qiE "hard.mode|planner-hard" "$artifact_path"; then
  # Check Postmortem Constraints section
  grep -qE "^## Postmortem Constraints" "$artifact_path" || \
    log_error "Hard-mode plan: missing ## Postmortem Constraints section"
  
  # Check at least one phase has "Estimated output" and "Done when"
  grep -qE "Estimated output:.*lines|Done when:" "$artifact_path" || \
    log_warn "Hard-mode plan: missing phase sizing annotations"
  
  # Check dependency wave map
  grep -qE "^\| Wave \|" "$artifact_path" || \
    log_warn "Hard-mode plan: missing Dependency Analysis wave map"
fi
```

### 4. Handoff Schema Validation Script (`validate-handoff.sh`)

**Location**: `.claude/scripts/validate-handoff.sh`  
**Size**: ~80 lines  
**Trigger**: Can be called from `skill-orchestrate-hard` postflight, or run manually

```bash
validate_handoff() {
  local file="$1"
  [ -f "$file" ] || { echo "[FAIL] Handoff file not found: $file"; exit 1; }
  jq empty "$file" 2>/dev/null || { echo "[FAIL] Invalid JSON: $file"; exit 1; }
  
  for field in status phases_completed phases_total sorry_inventory \
               blockers continuation_path; do
    jq -e "has(\"$field\")" "$file" > /dev/null 2>&1 || \
      echo "[WARN] Missing field: $field in $file"
  done
  
  # Validate status value
  status=$(jq -r '.status' "$file")
  case "$status" in
    "implemented"|"partial"|"blocked") ;;
    *) echo "[FAIL] Invalid status: $status (expected: implemented|partial|blocked)" ;;
  esac
  
  # If partial/blocked, continuation_path must be non-null
  if [ "$status" != "implemented" ]; then
    cont=$(jq -r '.continuation_path // "null"' "$file")
    [ "$cont" = "null" ] && echo "[WARN] Status is $status but continuation_path is null"
  fi
}
```

### 5. Runtime Trace Harness (Deferred)

A full runtime harness is **not recommended for v1** due to:
- Requires live agent invocations (expensive: ~$2-5 per test run)
- Agent outputs are non-deterministic; behavioral assertions need fuzzy matching
- No existing test runner or fixture system in the project

**If pursued later**, the pattern would be:
1. Create `specs/test-fixtures/hard-mode/` with known deflection-prone prompts
2. Execute with `--hard` and capture the resulting agent output
3. Check for absence of forbidden conclusion phrases in implementation output
4. Check for presence of `## Adversarial Self-Verification` in research output
5. Check that handoff JSON exists and passes `validate-handoff.sh`

This is essentially an end-to-end behavioral regression test. It is valuable but belongs in
a v2 phase after the static checks prove insufficient.

## Decisions

1. **Static lint first**: The highest ROI is a bash-based static lint script following the
   existing `lint-postflight-boundary.sh` pattern. This is implementable in 1-2 hours with
   no new infrastructure.

2. **Extend existing validators, not replace**: `validate-wiring.sh` and `validate-artifact.sh`
   are the right homes for hard-mode wiring checks and plan format checks respectively.
   New hard-mode checks add to existing patterns rather than creating parallel validators.

3. **Runtime harness is v2**: The cost and complexity of runtime behavioral testing is not
   justified until static checks reveal gaps that cannot be addressed statically.

4. **Handoff schema validation is medium priority**: Validating the handoff JSON schema is
   useful for debugging incomplete `skill-orchestrate-hard` runs, but is not a correctness
   gate for the contracts themselves.

5. **No test runner required**: All checks should be executable as standalone bash scripts.
   Integration into CI (via `[ci]` commit marker) is optional since meta tasks skip CI by default.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Static checks give false confidence | H | M | Document clearly what is NOT checked (runtime behavior) |
| Lint script becomes stale as contracts evolve | M | M | Lint script reads the contract files themselves for vocabulary checks, not hardcoded strings |
| Hard-mode plan checks produce false positives | M | L | Gate checks on detection of "hard-mode" marker in plan metadata or title |
| Runtime harness is too expensive to maintain | H | H | Defer; rely on manual review of execution outputs instead |
| convergence.md not loaded for any agent | M | M | Consider adding to `load_when` for orchestrate-hard postflight (currently direct-execution skill reads it directly) |

## Recommended Phasing

### Phase 1 (Immediate, ~2 hours): Static Contract Lint

Create `.claude/scripts/lint/lint-contract-compliance.sh` with checks:
- Contract @-references in hard agent files (Tier 1A)
- H-technique reference in each contract file (Tier 1B)
- Skill-to-hard-agent dispatch wiring (Tier 1C)
- Convergence field coverage in skill-orchestrate-hard (Tier 1D)
- H2 vocabulary in implementation agent (Tier 1E)
- Index.json contract coverage for hard agents (Tier 1F)

**Expected output**: A script that exits 0/1, runs in <5 seconds, covers the most common
contract integrity failures. Integrates with existing lint/ directory.

### Phase 2 (Short-term, ~1 hour): Wiring Validation Extension

Extend `validate-wiring.sh` with `validate_hard_mode_system()` covering:
- Hard agent existence checks
- Hard skill existence checks
- Contract file existence checks
- Index.json entry count for hard agents

**Expected output**: `validate-wiring.sh --hard` or auto-detection runs hard-mode checks.

### Phase 3 (Short-term, ~1 hour): Plan Artifact Extension

Extend `validate-artifact.sh` to detect and check hard-mode plan properties:
- `## Postmortem Constraints` section presence
- Phase sizing annotations
- Dependency wave map

**Expected output**: `validate-artifact.sh specs/.../plans/01_hard-plan.md plan` reports
missing hard-mode sections.

### Phase 4 (Medium-term, ~1.5 hours): Handoff Schema Validation

Create `.claude/scripts/validate-handoff.sh` for post-run handoff correctness:
- JSON parsability
- Required field presence
- Status/continuation_path consistency

**Expected output**: Called from `skill-orchestrate-hard` postflight or run manually to
diagnose incomplete orchestration runs.

### Phase 5 (Deferred): Runtime Trace Harness

Create end-to-end behavioral test fixtures if static checks prove insufficient.

## Appendix

### Files Examined

- `/home/benjamin/.config/nvim/.claude/context/contracts/anti-analysis.md`
- `/home/benjamin/.config/nvim/.claude/context/contracts/reference-grounding.md`
- `/home/benjamin/.config/nvim/.claude/context/contracts/convergence.md`
- `/home/benjamin/.config/nvim/.claude/context/contracts/territory.md`
- `/home/benjamin/.config/nvim/.claude/context/contracts/wrap-up.md`
- `/home/benjamin/.config/nvim/.claude/agents/general-implementation-hard-agent.md`
- `/home/benjamin/.config/nvim/.claude/agents/general-research-hard-agent.md`
- `/home/benjamin/.config/nvim/.claude/agents/planner-hard-agent.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer-hard/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher-hard/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner-hard/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate-hard/SKILL.md` (partial)
- `/home/benjamin/.config/nvim/.claude/scripts/lint/lint-postflight-boundary.sh`
- `/home/benjamin/.config/nvim/.claude/scripts/validate-wiring.sh`
- `/home/benjamin/.config/nvim/.claude/scripts/validate-artifact.sh`
- `/home/benjamin/.config/nvim/.claude/context/index.json` (contract entries)
- `/home/benjamin/.config/nvim/specs/669_hard_mode_agent_system/reports/01_hard-mode-orchestration-approach.md`
- `/home/benjamin/.config/nvim/specs/669_hard_mode_agent_system/reports/02_team-research.md`
- `/home/benjamin/.config/nvim/specs/669_hard_mode_agent_system/plans/02_hard-mode-implementation.md`
