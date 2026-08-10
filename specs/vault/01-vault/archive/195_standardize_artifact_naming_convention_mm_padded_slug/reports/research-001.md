# Research Report: Task #195

**Task**: 195 - Standardize artifact naming convention with MM_padded_slug format  
**Started**: 2026-03-13T15:30:00Z  
**Completed**: 2026-03-13T16:00:00Z  
**Effort**: 2 hours  
**Dependencies**: None  
**Sources/Inputs**: OpenCode codebase, AGENTS.md, skill definitions, agent definitions, command definitions, context files  
**Artifacts**: specs/195_standardize_artifact_naming_convention_mm_padded_slug/reports/research-001.md (this file)  
**Standards**: report-format.md, artifact-formats.md, state-management.md  

## Executive Summary

This research identifies **53 files** across the OpenCode agent system that require modification to implement the MM_padded_slug artifact naming convention. The current naming scheme uses patterns like `research-NNN.md`, `implementation-NNN.md`, and `implementation-summary-{DATE}.md`, which lacks semantic meaning and makes artifact organization difficult.

**Key Finding**: The desired format `MM_{short-slug}.md` (e.g., `01_n-place-predicates.md`) requires changes to:
- 8 core agent definition files
- 6 core skill definition files  
- 3 command definition files
- 4 postflight shell scripts
- 8 extension agent files
- 6 extension skill files
- 18 context/documentation files

**Recommended Approach**: Implement changes in three phases: (1) core system files, (2) extension files, (3) documentation updates.

## Current vs Desired Naming Patterns

### Current Convention (to be replaced)

| Artifact Type | Current Pattern | Example |
|---------------|-----------------|---------|
| Research reports | `research-{NNN}.md` | `research-001.md` |
| Implementation plans | `implementation-{NNN}.md` | `implementation-002.md` |
| Implementation summaries | `implementation-summary-{YYYYMMDD}.md` | `implementation-summary-20260305.md` |

### Desired Convention (target)

| Artifact Type | Desired Pattern | Example |
|---------------|-----------------|---------|
| Research reports | `MM_{short-slug}.md` | `01_n-place-predicates.md` |
| Implementation plans | `MM_{short-slug}.md` | `02_design-core-api.md` |
| Implementation summaries | `MM_{short-slug}.md` | `03_implementation-summary.md` |

Where:
- `MM` = Zero-padded sequence number (01, 02, 03...)
- `{short-slug}` = Brief descriptive slug (3-5 words, kebab-case)

## Files Requiring Changes

### Category 1: Core Agent Definitions (8 files)

These agents directly construct artifact paths when creating reports/plans/summaries:

1. **`.opencode/agent/subagents/general-research-agent.md`**
   - Lines 140, 188, 229, 290, 318, 401, 411: Hardcodes `research-{NNN}.md`
   - **Action**: Change to `01_{short-slug}.md` format with dynamic slug generation

2. **`.opencode/agent/subagents/planner-agent.md`**
   - Lines 115, 189, 201, 301, 330, 379, 390: Hardcodes `implementation-{NNN}.md`
   - **Action**: Change to `MM_{short-slug}.md` with incrementing MM

3. **`.opencode/agent/subagents/general-implementation-agent.md`**
   - Lines 108, 185, 246, 311, 450, 461: References `implementation-summary-{DATE}.md`
   - Lines 311, 450, 461: Also references `implementation-001.md`
   - **Action**: Change summary to `MM_{short-slug}-summary.md`, plan to `MM_{short-slug}.md`

4. **`.opencode/agent/subagents/neovim-research-agent.md`**
   - Lines 231, 299, 326: `research-{NNN}.md`
   - **Action**: Change to `MM_{short-slug}.md`

5. **`.opencode/agent/subagents/neovim-implementation-agent.md`**
   - Lines 99, 181, 246, 282: `implementation-summary-{DATE}.md` and `implementation-001.md`
   - **Action**: Apply MM_slug format

6. **`.opencode/agent/subagents/nix-research-agent.md`**
   - Lines 321, 382, 409: `research-{NNN}.md`
   - **Action**: Change to `MM_{short-slug}.md`

7. **`.opencode/agent/subagents/nix-implementation-agent.md`**
   - Lines 120, 215, 271, 302: `implementation-summary-{DATE}.md` and `implementation-001.md`
   - **Action**: Apply MM_slug format

8. **`.opencode/agent/subagents/web-research-agent.md`**
   - Lines 230, 299, 326: `research-{NNN}.md`
   - **Action**: Change to `MM_{short-slug}.md`

9. **`.opencode/agent/subagents/web-implementation-agent.md`**
   - Lines 139, 236, 311, 347, 791, 802: `implementation-summary-{DATE}.md` and `implementation-001.md`
   - **Action**: Apply MM_slug format

### Category 2: Core Skill Definitions (6 files)

Skills orchestrate agent invocation and handle postflight artifact linking:

1. **`.opencode/skills/skill-researcher/SKILL.md`**
   - Lines 221, 223, 299, 309: References `research-{NNN}.md` in TODO.md updates and examples
   - **Action**: Update to `MM_{short-slug}.md` pattern

2. **`.opencode/skills/skill-planner/SKILL.md`**
   - Lines 228, 230, 327, 336: References `implementation-{NNN}.md`
   - **Action**: Update to `MM_{short-slug}.md` pattern

3. **`.opencode/skills/skill-implementer/SKILL.md`**
   - Lines 312, 314, 390, 400: References `implementation-summary-{DATE}.md`
   - **Action**: Update to `MM_{short-slug}-summary.md` pattern

4. **`.opencode/skills/skill-status-sync/SKILL.md`**
   - Lines 156, 179, 248: Generic artifact path handling
   - **Action**: Update examples to show MM_slug format

5. **`.opencode/skills/skill-web-research/SKILL.md`** (extension)
   - Lines 185, 187, 253, 263: References `research-{NNN}.md`
   - **Action**: Update to `MM_{short-slug}.md`

6. **`.opencode/skills/skill-web-implementation/SKILL.md`** (extension)
   - Lines 57, 134, 263, 268, 290, 336, 346: References `implementation-{NNN}.md` and `implementation-summary-{DATE}.md`
   - **Action**: Apply MM_slug format

### Category 3: Command Definitions (3 files)

Commands are the user-facing entry points that trigger skill/agent workflows:

1. **`.opencode/commands/research.md`**
   - Line 69: References `research-001.md`
   - **Action**: Update example to `01_{short-slug}.md`

2. **`.opencode/commands/plan.md`**
   - Lines 69, 196: References `research-001.md` and `implementation-002.md`
   - **Action**: Update examples to MM_slug format

3. **`.opencode/commands/implement.md`**
   - Line 45: References `implementation-*.md`
   - Line 228: Artifact linking
   - **Action**: Update path patterns and examples

### Category 4: Postflight Shell Scripts (4 files)

These scripts update state.json and link artifacts after completion:

1. **`.opencode/scripts/postflight-research.sh`**
   - Line 24: Takes `artifact_path` as argument
   - **Action**: No changes needed (generic path handling)

2. **`.opencode/scripts/postflight-plan.sh`**
   - Line 24: Takes `artifact_path` as argument
   - **Action**: No changes needed (generic path handling)

3. **`.opencode/scripts/postflight-implement.sh`**
   - Line 24: Takes `artifact_path` as argument
   - **Action**: No changes needed (generic path handling)

4. **`.opencode/scripts/execute-command.sh`** (if exists)
   - **Action**: Verify artifact path handling

### Category 5: Extension Agent Files (8 files)

Extension agents follow the same patterns as core agents:

1. **`.opencode/extensions/formal/agents/formal-research-agent.md`**
   - Lines 140, 188, 218: `research-{NNN}.md`

2. **`.opencode/extensions/formal/agents/logic-research-agent.md`**
   - Lines 216, 274, 302: `research-{NNN}.md`

3. **`.opencode/extensions/formal/agents/math-research-agent.md`**
   - Lines 205, 263, 291: `research-{NNN}.md`

4. **`.opencode/extensions/formal/agents/physics-research-agent.md`**
   - Lines 199, 255, 284: `research-{NNN}.md`

5. **`.opencode/extensions/lean/agents/lean-research-flow.md`**
   - Lines 83, 132: `research-{NNN}.md`

6. **`.opencode/extensions/lean/agents/lean-implementation-flow.md`**
   - Lines 28, 107: `implementation-001.md` and `implementation-summary-{DATE}.md`

7. **`.opencode/extensions/z3/agents/z3-research-agent.md`**
   - Line 92: `research-{NNN}.md`

8. **`.opencode/extensions/z3/agents/z3-implementation-agent.md`**
   - Line 91: `implementation-summary-{DATE}.md`

### Category 6: Extension Skill Files (6 files)

1. **`.opencode/extensions/nix/skills/skill-nix-research/SKILL.md`**
   - Line 198: `research-{NNN}.md`

2. **`.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md`**
   - Lines 58, 134, 267, 289, 335, 345: `implementation-{NNN}.md` and `implementation-summary-{DATE}.md`

3. **`.opencode/extensions/neovim/skills/skill-neovim-research/SKILL.md`**
   - Line 198: `research-{NNN}.md`

4. **`.opencode/extensions/neovim/skills/skill-neovim-implementation/SKILL.md`**
   - Lines 56, 122, 290: `implementation-001.md` and `implementation-summary-{DATE}.md`

5. **`.opencode/extensions/lean/skills/skill-lean-research/SKILL.md`**
   - Line 205: `research-{NNN}.md`

6. **`.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`**
   - Lines 93, 237: `implementation-{NNN}.md` and `implementation-summary-{DATE}.md`

### Category 7: Context and Documentation Files (18 files)

These files document the conventions and need updating:

1. **`.opencode/AGENTS.md`**
   - Lines 42-44: Artifact path examples
   - Lines 157-159: Directory structure examples

2. **`.opencode/README.md`**
   - Lines 157-159: Directory structure

3. **`.opencode/rules/artifact-formats.md`**
   - Artifact format definitions and examples

4. **`.opencode/rules/state-management.md`**
   - Line 186: Artifact linking examples

5. **`.opencode/context/core/formats/return-metadata-file.md`**
   - Lines 27, 161, 196, 225, 259, 293, 327, 360: Example paths

6. **`.opencode/context/core/formats/plan-format.md`**
   - Lines 20, 42, 59, 103, 131: Plan format examples

7. **`.opencode/context/core/formats/report-format.md`**
   - Report format examples

8. **`.opencode/context/core/formats/summary-format.md`**
   - Summary format examples

9. **`.opencode/context/core/formats/subagent-return.md`**
   - Line 165, 38: Example artifact paths

10. **`.opencode/context/core/formats/command-output.md`**
    - Lines 33, 101, 111, 128, 129, 166, 167: Example outputs

11. **`.opencode/context/core/standards/status-markers.md`**
    - Line 301: Example artifact path

12. **`.opencode/context/core/orchestration/delegation.md`**
    - Lines 437, 585: Example artifact paths

13. **`.opencode/context/core/orchestration/routing.md`**
    - Line 330: Example artifact path

14. **`.opencode/context/core/orchestration/orchestration-reference.md`**
    - Lines 73, 297: Example artifact paths

15. **`.opencode/context/core/orchestration/orchestrator.md`**
    - Line 842: Example artifact reference

16. **`.opencode/context/core/patterns/inline-status-update.md`**
    - Lines 186, 191: Example artifact links

17. **`.opencode/context/core/patterns/metadata-file-return.md`**
    - Line 41: Example artifact path

18. **`.opencode/context/core/patterns/jq-escaping-workarounds.md`**
    - Lines 189, 221: Example artifact paths

19. **`.opencode/context/project/processes/research-workflow.md`**
    - Lines 166, 412, 536, 635: Research artifact paths

20. **`.opencode/context/project/processes/planning-workflow.md`**
    - Lines 21, 31, 145, 342-344, 489, 541: Plan artifact paths

21. **`.opencode/context/project/processes/implementation-workflow.md`**
    - Lines 181, 256, 415, 509, 528, 574: Summary artifact paths

22. **`.opencode/context/core/workflows/status-transitions.md`**
    - Lines 73, 81: Example artifact paths

23. **`.opencode/context/core/workflows/preflight-postflight.md`**
    - Lines 220, 229, 270, 291: Example artifact paths

24. **`.opencode/docs/guides/user-guide.md`**
    - Line 615: Example plan path

25. **`.opencode/docs/guides/creating-agents.md`**
    - Line 622: Example artifact creation

26. **`.opencode/docs/guides/documentation-audit-checklist.md`**
    - Line 280: Example research path

27. **`.opencode/docs/architecture/system-overview.md`**
    - Artifact path examples

## Implementation Complexity Assessment

### Complexity: HIGH

**Rationale**:
1. **53 files** across multiple directories require coordinated changes
2. **Multiple naming patterns** to standardize (research, plan, summary)
3. **Dynamic slug generation** requires new logic (short-slug from task description)
4. **Sequential numbering** (MM) requires state tracking per task
5. **Backward compatibility** - existing artifacts must remain accessible
6. **Extension ecosystem** - all extensions must be updated

### Key Challenges

1. **Slug Generation**: Need algorithm to generate `{short-slug}` from task description
   - Extract 3-5 key words
   - Convert to kebab-case
   - Ensure uniqueness within task

2. **Sequence Numbering**: MM must be sequential per task
   - 01 for first research
   - 02 for first plan (or continue from research?)
   - Requires scanning existing artifacts

3. **Version Tracking**: For plan revisions
   - Current: `implementation-001.md`, `implementation-002.md`
   - New: `02_design-core-api.md`, `03_design-core-api-v2.md`?
   - Or keep MM sequential regardless of version?

4. **Cross-file Consistency**: All files must use same convention
   - Risk of partial updates causing inconsistency
   - Need atomic update approach

## Recommended Implementation Approach

### Phase 1: Design and Prototype (Task 195 follow-up)

1. **Create naming utility specification**:
   - Define slug generation algorithm
   - Define MM sequencing rules
   - Define version handling for plan revisions

2. **Update format documentation**:
   - `.opencode/context/core/formats/report-format.md`
   - `.opencode/context/core/formats/plan-format.md`
   - `.opencode/context/core/formats/summary-format.md`
   - `.opencode/rules/artifact-formats.md`

3. **Create helper script**:
   - Generate next artifact name given task context
   - Parse existing artifacts to determine next MM
   - Generate slug from description

### Phase 2: Core System Updates

1. **Update core agents**:
   - `general-research-agent.md`
   - `planner-agent.md`
   - `general-implementation-agent.md`

2. **Update core skills**:
   - `skill-researcher/SKILL.md`
   - `skill-planner/SKILL.md`
   - `skill-implementer/SKILL.md`

3. **Update commands**:
   - `research.md`
   - `plan.md`
   - `implement.md`

### Phase 3: Extension Updates

1. **Update all extension agents** (8 files)
2. **Update all extension skills** (6 files)

### Phase 4: Documentation Updates

1. **Update all context files** (18 files)
2. **Update README and guides**
3. **Update AGENTS.md**

### Phase 5: Migration and Testing

1. **Create migration guide** for existing tasks
2. **Update existing tasks** (optional - could grandfather)
3. **Test all commands** end-to-end
4. **Verify all extensions** work correctly

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Partial update leaves inconsistency | High | Medium | Phased approach with verification gates |
| Extension breakage | High | High | Test all extensions after changes |
| Existing task artifacts become unreachable | Medium | Low | Maintain backward compatibility or migrate |
| Slug collision (duplicate names) | Medium | Low | Append -v2, -v3 for collisions |
| User confusion during transition | Low | Medium | Clear documentation and examples |

## Context Extension Recommendations

- **Topic**: Artifact naming conventions
- **Gap**: No documented algorithm for generating short-slugs from task descriptions
- **Recommendation**: Create `.opencode/context/core/standards/artifact-naming.md` with:
  - Slug generation algorithm
  - MM sequencing rules
  - Version handling for revisions
  - Examples for all artifact types

## Appendix: Detailed File Locations

### Complete list of files requiring changes (53 total):

**Core Agents (8)**:
1. `.opencode/agent/subagents/general-research-agent.md`
2. `.opencode/agent/subagents/planner-agent.md`
3. `.opencode/agent/subagents/general-implementation-agent.md`
4. `.opencode/extensions/neovim/agents/neovim-research-agent.md`
5. `.opencode/extensions/neovim/agents/neovim-implementation-agent.md`
6. `.opencode/extensions/nix/agents/nix-research-agent.md`
7. `.opencode/extensions/nix/agents/nix-implementation-agent.md`
8. `.opencode/extensions/web/agents/web-research-agent.md`
9. `.opencode/extensions/web/agents/web-implementation-agent.md`

**Core Skills (6)**:
1. `.opencode/skills/skill-researcher/SKILL.md`
2. `.opencode/skills/skill-planner/SKILL.md`
3. `.opencode/skills/skill-implementer/SKILL.md`
4. `.opencode/skills/skill-status-sync/SKILL.md`
5. `.opencode/extensions/web/skills/skill-web-research/SKILL.md`
6. `.opencode/extensions/web/skills/skill-web-implementation/SKILL.md`

**Commands (3)**:
1. `.opencode/commands/research.md`
2. `.opencode/commands/plan.md`
3. `.opencode/commands/implement.md`

**Scripts (3)**:
1. `.opencode/scripts/postflight-research.sh`
2. `.opencode/scripts/postflight-plan.sh`
3. `.opencode/scripts/postflight-implement.sh`

**Extension Agents (8)**:
1. `.opencode/extensions/formal/agents/formal-research-agent.md`
2. `.opencode/extensions/formal/agents/logic-research-agent.md`
3. `.opencode/extensions/formal/agents/math-research-agent.md`
4. `.opencode/extensions/formal/agents/physics-research-agent.md`
5. `.opencode/extensions/lean/agents/lean-research-flow.md`
6. `.opencode/extensions/lean/agents/lean-implementation-flow.md`
7. `.opencode/extensions/z3/agents/z3-research-agent.md`
8. `.opencode/extensions/z3/agents/z3-implementation-agent.md`

**Extension Skills (6)**:
1. `.opencode/extensions/nix/skills/skill-nix-research/SKILL.md`
2. `.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md`
3. `.opencode/extensions/neovim/skills/skill-neovim-research/SKILL.md`
4. `.opencode/extensions/neovim/skills/skill-neovim-implementation/SKILL.md`
5. `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md`
6. `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`

**Documentation/Context (18)**:
1. `.opencode/AGENTS.md`
2. `.opencode/README.md`
3. `.opencode/rules/artifact-formats.md`
4. `.opencode/rules/state-management.md`
5. `.opencode/context/core/formats/return-metadata-file.md`
6. `.opencode/context/core/formats/plan-format.md`
7. `.opencode/context/core/formats/report-format.md`
8. `.opencode/context/core/formats/summary-format.md`
9. `.opencode/context/core/formats/subagent-return.md`
10. `.opencode/context/core/formats/command-output.md`
11. `.opencode/context/core/standards/status-markers.md`
12. `.opencode/context/core/orchestration/delegation.md`
13. `.opencode/context/core/orchestration/routing.md`
14. `.opencode/context/core/orchestration/orchestration-reference.md`
15. `.opencode/context/core/orchestration/orchestrator.md`
16. `.opencode/context/core/patterns/inline-status-update.md`
17. `.opencode/context/core/patterns/metadata-file-return.md`
18. `.opencode/context/core/patterns/jq-escaping-workarounds.md`
19. `.opencode/context/project/processes/research-workflow.md`
20. `.opencode/context/project/processes/planning-workflow.md`
21. `.opencode/context/project/processes/implementation-workflow.md`
22. `.opencode/context/core/workflows/status-transitions.md`
23. `.opencode/context/core/workflows/preflight-postflight.md`
24. `.opencode/docs/guides/user-guide.md`
25. `.opencode/docs/guides/creating-agents.md`
26. `.opencode/docs/guides/documentation-audit-checklist.md`
27. `.opencode/docs/architecture/system-overview.md`
