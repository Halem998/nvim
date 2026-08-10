# Implementation Plan: Task #541 - Design opencode.json Agent Registration Mechanism

- **Task**: 541 - design_opencode_json_agent_registration
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: 540 (completed)
- **Research Inputs**: specs/541_design_opencode_json_agent_registration/reports/01_opencode-json-agent-registration-design.md
- **Artifacts**: plans/01_opencode-json-agent-registration-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan documents the design decisions and specifications for the opencode.json agent registration mechanism in the OpenCode extension system. Task 540 implemented the core infrastructure (fragments, manifests, merge/unmerge, validation, sync integration, cleanup). Task 541 focuses on formalizing the remaining design gaps: conflict resolution strategy, validation pipeline extensions, sync lifecycle policies, and the managed/unmanaged distinction. The definition of done is a set of design documents, reference specifications, and design-level code annotations that implementation agents can follow to close the identified gaps.

### Research Integration

The research report (8 findings, 5 design decisions, 6 recommendations) directly informs this plan:

- **Finding 1**: Manifest schema already supports `opencode_json` registration; no schema changes needed.
- **Finding 2**: Merge/unmerge uses key-based tracking with no-overwrite semantics; functional but has edge cases.
- **Finding 3**: Validation pipeline has three gaps: fragment-to-manifest consistency, cross-extension conflict detection, and tool assignment validation.
- **Finding 4**: Agent definition format is standardized but informally; no formal schema document exists.
- **Finding 5**: Conflict resolution strategy is undefined; first-loaded wins silently, causing orphaning on unload.
- **Finding 6**: Sync strategy has ordering dependencies; transient state window exists during full sync + re-injection.
- **Finding 7**: Startup cleanup exists (`cleanup_stale_opencode_agents`) but is not triggered automatically.
- **Finding 8**: Managed/unmanaged distinction (`.managed` sidecar) should govern sync behavior and user customization boundaries.

**Design decisions adopted**:
1. First-loaded wins with conflict warning
2. Extend validation to cover fragment-to-manifest consistency
3. Trigger startup cleanup on Neovim startup and after each load/unload
4. Use managed flag to govern sync overwrite behavior
5. Maintain current agent definition format (no schema changes)

### Prior Plan Reference

No prior plan exists for this task. Task 540's plan can be referenced for the infrastructure implementation approach.

### Roadmap Alignment

No ROADMAP.md items directly address this task. However, the reference documentation produced by this task (agent name registry, manifest schema reference, lifecycle documentation) advances the Documentation Infrastructure and Agent System Quality themes in Phase 1 of the roadmap.

## Goals & Non-Goals

**Goals**:
- Formalize the 5 design decisions from the research report into actionable specifications
- Document conflict resolution policy, validation rules, sync lifecycle, and managed/unmanaged policies
- Create reference documentation for agent names, manifest schema, and JSON merge tracking
- Add design-level TODO/FIXME annotations to code files to guide future implementation

**Non-Goals**:
- Implement the actual code changes (conflict detection, validation functions, cleanup triggers, managed flag logic)
- Modify the JSON schema for `opencode-agents.json` or `manifest.json`
- Create automated tests for the design policies
- Refactor the merge/unmerge implementation

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Design documents drift from actual code behavior | Medium | Medium | Reference specific line numbers and file paths from the research report; include code excerpts |
| Design decisions are too abstract for implementation agents | Medium | Low | Include concrete examples, pseudo-code, and explicit file paths in design docs |
| Missing edge cases in conflict resolution policy | Medium | Medium | Document known edge cases (orphaning on unload, transient state window) explicitly |
| Reference docs become stale as extension ecosystem grows | Low | Medium | Include version/date markers and instructions for updating |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Document Core Design Decisions and Policies [COMPLETED]

**Goal**: Formalize the 5 design decisions into a single authoritative design specification document.

**Tasks**:
- [x] **Task 1.1**: Write `specs/541_design_opencode_json_agent_registration/designs/01_agent-registration-design-spec.md` *(completed)*
  - Summarize the problem scope and Task 540 infrastructure context
  - Document Decision 1: First-loaded wins with conflict warning strategy
    - Define conflict detection algorithm (read `extensions.json`, map agent names to extensions)
    - Define warning message format and notification mechanism
    - Document orphaning edge case and why lazy re-merge is deferred
  - Document Decision 2: Fragment-to-manifest consistency validation
    - Define verification rules: every `manifest.provides.agents` entry must have matching fragment entry, and vice versa
    - Define naming convention validation (agent name = filename without `-agent.md` suffix)
  - Document Decision 3: Startup cleanup triggers
    - Specify trigger points: Neovim startup (`opencode.lua` `config()`), post-load, post-unload
    - Document idempotency requirement and performance constraints
  - Document Decision 4: Managed flag governing sync overwrite behavior
    - Define policy: unmanaged files are never overwritten; managed files can be replaced during sync-all
    - Document `.managed` sidecar format and backup behavior
  - Document Decision 5: Maintain current agent definition format
    - Reference existing `opencode-agents.json` format rules from Task 540
    - Note that no schema changes are needed
- [x] **Task 1.2**: Document transient state window mitigation (Finding 6) *(completed)*
  - Specify that sync must re-inject extension agents atomically after any full replace
  - Document that `on_load_all` callback ordering must run after re-injection completes
- [x] **Task 1.3**: Review and validate the design spec against the research report *(completed)*
  - Ensure all 8 findings, 5 decisions, and 6 recommendations are addressed or explicitly deferred

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `specs/541_design_opencode_json_agent_registration/designs/01_agent-registration-design-spec.md` - create

**Verification**:
- Design spec exists and references all 5 decisions
- Each decision includes concrete rules, examples, and file references
- Orphaning edge case and transient state window are documented

---

### Phase 2: Create Reference Documentation [COMPLETED]

**Goal**: Produce reusable reference documents for the extension ecosystem.

**Tasks**:
- [x] **Task 2.1**: Create `.opencode/context/reference/agent-name-registry.md` *(completed)*
  - List reserved core agent names (build, plan, task-planner, etc.)
  - Document extension agent naming conventions (descriptive, non-conflicting)
  - Document the process for proposing new agent names to avoid collisions
  - Reference the conflict resolution policy from Phase 1
- [x] **Task 2.2**: Create `.opencode/context/reference/extension-manifest-schema.md` *(completed)*
  - Document the `merge_targets.opencode_json` field structure
  - Include JSON examples from `core/manifest.json` and `present/manifest.json`
  - Document relationship between `manifest.provides.agents` and `opencode-agents.json`
- [x] **Task 2.3**: Create `.opencode/context/patterns/json-merge-tracking.md` *(completed)*
  - Document the key-based tracking pattern used in `merge.lua`
  - Explain how `{keys = {...}}` enables idempotent unmerge
  - Include pseudocode for merge and unmerge operations
  - Note this pattern is reusable for other JSON merge targets
- [x] **Task 2.4**: Create `.opencode/context/reference/opencode-json-lifecycle.md` *(completed)*
  - Document the full lifecycle: template installation -> extension registration -> cleanup -> unload
  - Explain managed/unmanaged distinction and user customization boundaries
  - Document sync behavior for managed vs unmanaged files
  - Include state diagram or flow description

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.opencode/context/reference/agent-name-registry.md` - create
- `.opencode/context/reference/extension-manifest-schema.md` - create
- `.opencode/context/patterns/json-merge-tracking.md` - create
- `.opencode/context/reference/opencode-json-lifecycle.md` - create

**Verification**:
- All 4 reference documents exist and follow project documentation standards
- Documents cross-reference each other and the design spec
- Examples use real paths and data from the codebase

---

### Phase 3: Design-Level Code Annotations [COMPLETED]

**Goal**: Add structured TODO/FIXME comments to key code files to guide future implementation agents.

**Tasks**:
- [x] **Task 3.1**: Annotate `lua/neotex/plugins/ai/shared/extensions/merge.lua` *(completed)*
  - Add TODO near line 733: implement conflict detection before skipping existing agent key
  - Reference Decision 1 and the warning message format from the design spec
  - Add NOTE near line 745: document that tracked keys are stored for unmerge
- [x] **Task 3.2**: Annotate `lua/neotex/plugins/ai/shared/extensions/init.lua` *(completed)*
  - Add TODO near line 834: wire `cleanup_stale_opencode_agents()` to `manager.load()` and `manager.unload()`
  - Add TODO near `manager.load()` exit path: call cleanup after successful load
  - Reference Decision 3 and trigger points from the design spec
- [x] **Task 3.3**: Annotate `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` *(completed)*
  - Add TODO near line 340: respect `.managed` sidecar before deciding sync action for `opencode.json`
  - Add NOTE near line 872: document that re-injection must run atomically after full replace
  - Reference Decision 4 and transient state mitigation from the design spec
- [x] **Task 3.4**: Annotate `lua/neotex/plugins/ai/shared/extensions/verify.lua` *(completed)*
  - Add TODO near line 284: implement `verify_opencode_json_merge()` for fragment-to-manifest consistency
  - Reference Decision 2 and validation rules from the design spec
- [x] **Task 3.5**: Annotate `lua/neotex/plugins/ai/opencode/core/init.lua` *(completed)*
  - Add NOTE near line 54: document that `is_managed()` should be checked by sync before overwrite
  - Reference Decision 4 and managed/unmanaged policy from the design spec

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - add TODO/FIXME/NOTE comments
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - add TODO/FIXME/NOTE comments
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - add TODO/FIXME/NOTE comments
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - add TODO/FIXME/NOTE comments
- `lua/neotex/plugins/ai/opencode/core/init.lua` - add TODO/FIXME/NOTE comments

**Verification**:
- All TODO/FIXME comments reference the design spec by path
- Comments include specific line references and decision numbers
- No functional code changes are made (only comments)

## Testing & Validation

- [ ] Design spec covers all 5 decisions from the research report
- [ ] All 4 reference documents are created and cross-referenced
- [ ] Code annotations reference specific design decisions and file paths
- [ ] No functional code changes introduced (only comments and documentation)
- [ ] Documentation follows project standards (no emojis, consistent formatting)

## Artifacts & Outputs

- `specs/541_design_opencode_json_agent_registration/designs/01_agent-registration-design-spec.md` - Core design specification
- `.opencode/context/reference/agent-name-registry.md` - Agent name registry
- `.opencode/context/reference/extension-manifest-schema.md` - Manifest schema reference
- `.opencode/context/patterns/json-merge-tracking.md` - JSON merge tracking pattern
- `.opencode/context/reference/opencode-json-lifecycle.md` - opencode.json lifecycle reference
- Updated code comments in:
  - `lua/neotex/plugins/ai/shared/extensions/merge.lua`
  - `lua/neotex/plugins/ai/shared/extensions/init.lua`
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
  - `lua/neotex/plugins/ai/shared/extensions/verify.lua`
  - `lua/neotex/plugins/ai/opencode/core/init.lua`

## Rollback/Contingency

Since this is a design task producing documentation and comments only, rollback is straightforward:
- Delete the created design and reference documents
- Revert comment-only changes in the 5 Lua files using git
- No functional code is modified, so there is no runtime risk
