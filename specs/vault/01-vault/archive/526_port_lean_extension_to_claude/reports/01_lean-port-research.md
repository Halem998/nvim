# Research Report: Task #526

**Task**: 526 - Port lean extension to `.claude/` for parity
**Started**: 2026-05-04T12:00:00Z
**Completed**: 2026-05-04T12:45:00Z
**Effort**: 2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase inventory, manifest comparison, file diff analysis
**Artifacts**: - `specs/526_port_lean_extension_to_claude/reports/01_lean-port-research.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **`.claude/extensions/lean/` already exists** and is largely feature-complete — it actually contains **more** files than `.opencode/extensions/lean/`
- The primary porting work is **fixing incorrect path references** and reconciling structural differences between the two extension systems
- **Critical bug found**: `.claude/extensions/lean/opencode-agents.json` references `.opencode/agent/subagents/` paths, which are wrong for the Claude Code system
- **No files need to be created from scratch** — the extension already has agents, skills, commands, rules, context, and manifests
- **Minimal changes needed**: Fix `opencode-agents.json` paths, reconcile manifest `scripts` array, and optionally backport two context files from `.claude/` to `.opencode/`

## Context & Scope

The task requested creating `.claude/extensions/lean/` mirroring `.opencode/extensions/lean/` for feature parity. During research, we discovered that `.claude/extensions/lean/` already exists and is approximately 95% complete. The work is therefore not a "port from scratch" but rather a **parity audit and reconciliation**.

## Findings

### 1. Complete File Inventory

#### `.opencode/extensions/lean/` (Source)
```
.opencode/extensions/lean/
├── manifest.json                          (70 lines)
├── EXTENSION.md                           (31 lines)
├── README.md                              (22 lines)
├── index-entries.json                     (220 lines, 23 entries)
├── settings-fragment.json                 (33 lines)
├── agents/
│   ├── lean-research-agent.md             (183 lines)
│   └── lean-implementation-agent.md       (231 lines)
├── commands/
│   ├── lean.md                            (353 lines)
│   └── lake.md                            (321 lines)
├── context/project/lean4/
│   ├── README.md
│   ├── agents/lean-implementation-flow.md
│   ├── agents/lean-research-flow.md
│   ├── domain/dependent-types.md
│   ├── domain/key-mathematical-concepts.md
│   ├── domain/lean4-syntax.md
│   ├── domain/mathlib-overview.md
│   ├── operations/multi-instance-optimization.md
│   ├── patterns/tactic-patterns.md
│   ├── processes/end-to-end-proof-workflow.md
│   ├── processes/project-structure-best-practices.md
│   ├── standards/lean4-style-guide.md
│   ├── standards/proof-conventions.md
│   ├── standards/proof-conventions-lean.md
│   ├── standards/proof-debt-policy.md
│   ├── standards/proof-readability-criteria.md
│   ├── templates/definition-template.md
│   ├── templates/new-file-template.md
│   ├── templates/proof-structure-templates.md
│   ├── tools/aesop-integration.md
│   ├── tools/loogle-api.md
│   ├── tools/lsp-integration.md
│   ├── tools/leansearch-api.md
│   └── tools/mcp-tools-guide.md
├── rules/
│   └── lean4.md                           (54 lines)
└── skills/
    ├── skill-lean-research/SKILL.md       (231 lines)
    ├── skill-lean-implementation/SKILL.md (263 lines)
    ├── skill-lake-repair/SKILL.md         (153 lines)
    └── skill-lean-version/SKILL.md        (146 lines)
```

#### `.claude/extensions/lean/` (Target — Already Exists)
```
.claude/extensions/lean/
├── manifest.json                          (78 lines)
├── EXTENSION.md                           (31 lines, identical)
├── README.md                              (192 lines, much more detailed)
├── index-entries.json                     (533 lines, 25 entries)
├── settings-fragment.json                 (33 lines, identical)
├── opencode-agents.json                   (32 lines) ← BUGGY PATHS
├── agents/
│   ├── lean-research-agent.md             (184 lines, +model: opus)
│   └── lean-implementation-agent.md       (268 lines, +model: opus, +verification stage)
├── commands/
│   ├── lean.md                            (353 lines, identical)
│   └── lake.md                            (321 lines, identical)
├── context/project/lean4/
│   ├── README.md
│   ├── agents/lean-implementation-flow.md
│   ├── agents/lean-research-flow.md
│   ├── domain/dependent-types.md
│   ├── domain/key-mathematical-concepts.md
│   ├── domain/lean4-syntax.md
│   ├── domain/mathlib-overview.md
│   ├── operations/multi-instance-optimization.md
│   ├── patterns/tactic-patterns.md
│   ├── patterns/mcp-fallback-table.md      ← EXTRA in .claude
│   ├── processes/end-to-end-proof-workflow.md
│   ├── processes/project-structure-best-practices.md
│   ├── standards/lean4-style-guide.md
│   ├── standards/proof-conventions.md
│   ├── standards/proof-conventions-lean.md
│   ├── standards/proof-debt-policy.md
│   ├── standards/proof-readability-criteria.md
│   ├── templates/definition-template.md
│   ├── templates/new-file-template.md
│   ├── templates/proof-structure-templates.md
│   ├── tools/aesop-integration.md
│   ├── tools/blocked-mcp-tools.md          ← EXTRA in .claude
│   ├── tools/loogle-api.md
│   ├── tools/lsp-integration.md
│   ├── tools/leansearch-api.md
│   └── tools/mcp-tools-guide.md
├── rules/
│   └── lean4.md                           (54 lines, identical)
└── skills/
    ├── skill-lean-research/SKILL.md       (247 lines, +postflight, +self-exec fallback)
    ├── skill-lean-implementation/SKILL.md (286 lines, +postflight, +MUST NOT section)
    ├── skill-lake-repair/SKILL.md         (153 lines, identical)
    └── skill-lean-version/SKILL.md        (146 lines, identical)
```

### 2. Comparison with Ported Extension (nvim)

We examined `.claude/extensions/nvim/` as a successfully ported extension. Key porting patterns observed:

| Pattern | nvim Extension | lean Extension (Current State) |
|---------|---------------|-------------------------------|
| `manifest.json` | Uses `"task_type"`, `"merge_targets.claudemd"`, `"opencode_json"` | ✅ Same structure |
| `opencode-agents.json` | References `.opencode/agent/subagents/` | ⚠️ **Same (but likely wrong for nvim too)** |
| Agent frontmatter | Includes `model: opus` | ✅ lean agents have this |
| Skills | Have Stage 4b self-exec fallback, postflight sections | ✅ lean skills have this |
| Context files | Domain, patterns, standards, tools, templates | ✅ lean has all categories |
| README.md | Detailed with architecture, workflow, commands | ✅ lean has this |

**Key insight**: The lean extension in `.claude/` already follows the same structural patterns as the nvim extension. The porting work was largely done previously.

### 3. Files Requiring Changes

#### Critical (Must Fix)

| File | Issue | Fix |
|------|-------|-----|
| `.claude/extensions/lean/opencode-agents.json` | References `.opencode/agent/subagents/lean-research-agent.md` and `.opencode/agent/subagents/lean-implementation-agent.md` — these paths do not exist in the Claude Code system | Change to `.claude/extensions/lean/agents/lean-research-agent.md` and `.claude/extensions/lean/agents/lean-implementation-agent.md`, OR verify if the `opencode.json` merge target expects these paths |
| `.claude/extensions/lean/manifest.json` | `"scripts": []` is empty, but `.opencode/` version lists `setup-lean-mcp.sh` and `verify-lean-mcp.sh` | Decide: either add scripts to lean manifest (if they belong here) or keep in core (where they currently exist in `.claude/extensions/core/manifest.json`) |

#### Recommended (Should Fix for Parity)

| File | Issue | Fix |
|------|-------|-----|
| `.claude/extensions/lean/manifest.json` | Routing has `"lean4:lake"` and `"lean4:version"` sub-routes that `.opencode/` lacks | These are Claude Code enhancements. Keep them — they add value without breaking parity |
| `.claude/extensions/lean/index-entries.json` | Has 2 extra entries (`blocked-mcp-tools.md`, `mcp-fallback-table.md`) and extra metadata fields (`domain`, `subdomain`, `summary`) | The extra entries are valuable. The extra fields are Claude Code index format enhancements. Keep all — they are forward-compatible |
| `.opencode/extensions/lean/index-entries.json` | Missing the 2 context files that exist in `.claude/` | **Backport** `blocked-mcp-tools.md` and `mcp-fallback-table.md` entries to `.opencode/` for true parity |

#### Optional (Nice to Have)

| File | Issue | Fix |
|------|-------|-----|
| `.opencode/extensions/lean/README.md` | Only 22 lines (barebones) vs 192 lines in `.claude/` | Backport the comprehensive README to `.opencode/` |
| `.opencode/extensions/lean/agents/*.md` | Missing `model: opus` frontmatter field | Add `model: opus` to match Claude Code convention (harmless in OpenCode) |
| `.opencode/extensions/lean/skills/*.md` | Missing Stage 4b (Self-Execution Fallback) and structured Postflight sections | Backport these structural improvements from `.claude/` |

### 4. Detailed Change Analysis

#### `opencode-agents.json` (CRITICAL BUG)

Current content:
```json
{
  "agent": {
    "lean-research": {
      "prompt": "{file:.opencode/agent/subagents/lean-research-agent.md}"
    },
    "lean-implementation": {
      "prompt": "{file:.opencode/agent/subagents/lean-implementation-agent.md}"
    }
  }
}
```

**Problem**: These `.opencode/agent/subagents/` paths do not exist. The actual agent files are at `.claude/extensions/lean/agents/`.

**Recommended fix**: Update paths to point to the correct location within the extension:
```json
{
  "agent": {
    "lean-research": {
      "prompt": "{file:.claude/extensions/lean/agents/lean-research-agent.md}"
    },
    "lean-implementation": {
      "prompt": "{file:.claude/extensions/lean/agents/lean-implementation-agent.md}"
    }
  }
}
```

> **Note**: The nvim extension has the same bug pattern. This may be a systematic issue with how `opencode-agents.json` is generated during porting. Consider checking other extensions (typst, latex, nix) for the same issue.

#### `manifest.json` Differences

| Field | `.opencode/` | `.claude/` | Assessment |
|-------|-------------|-----------|------------|
| `language` / `task_type` | `"language": "lean4"` | `"task_type": "lean4"` | Different key names per system convention — correct as-is |
| `provides.scripts` | `["setup-lean-mcp.sh", "verify-lean-mcp.sh"]` | `[]` | Scripts exist in `core/scripts/` in both systems. The lean extension manifest probably shouldn't claim them. `.claude/` is more correct here. |
| `routing.research` | `lean`, `lean4` → skill-lean-research | `lean4`, `lean4:lake`, `lean4:version` | `.claude/` has richer routing. Keep as-is. |
| `routing.plan` | (not present) | `lean4`, `lean4:lake`, `lean4:version` → skill-planner | Claude Code addition. Keep. |
| `routing.implement` | `lean`, `lean4` → skill-lean-implementation | `lean4`, `lean4:lake`, `lean4:version` | `.claude/` has sub-routing. Keep. |
| `merge_targets` | `opencode_md` → `.opencode/AGENTS.md` | `claudemd` → `.claude/CLAUDE.md` | Correct per system. |
| `merge_targets.opencode_json` | (not present) | `opencode-agents.json` → `opencode.json` | Claude Code-specific merge. Keep. |

**Verdict**: `manifest.json` in `.claude/` is correctly adapted. No changes needed except possibly documenting the `scripts` discrepancy.

#### Skills Comparison

| Aspect | `.opencode/` | `.claude/` | Assessment |
|--------|-------------|-----------|------------|
| `skill-lean-research` | 231 lines | 247 lines | `.claude/` has Stage 4b (Self-Execution Fallback) and explicit Postflight header. These are Claude Code skill architecture improvements. |
| `skill-lean-implementation` | 263 lines | 286 lines | `.claude/` has Stage 4b, Postflight header, explicit "MUST NOT (Postflight Boundary)" section referencing `@.claude/context/standards/postflight-tool-restrictions.md`, and reads `verification.verification_passed` from metadata. |
| `skill-lake-repair` | 153 lines | 153 lines | Identical. |
| `skill-lean-version` | 146 lines | 146 lines | Identical. |

**Key differences in `.claude/` skills**:
1. **Self-Execution Fallback (Stage 4b)**: Added to handle cases where the agent does work inline instead of spawning a subagent
2. **Postflight restructuring**: Explicit "Postflight (ALWAYS EXECUTE)" header with clear boundary
3. **Tool restriction references**: Links to `.claude/context/standards/postflight-tool-restrictions.md`
4. **Artifact linking patterns**: References `@.claude/context/patterns/artifact-linking-todo.md`
5. **Path conventions**: Uses `specs/tmp/state.json` instead of `/tmp/state.json` for atomic writes

These are all **Claude Code system improvements** that don't need to be backported unless maintaining strict bidirectional parity.

#### Agents Comparison

| Aspect | `.opencode/` | `.claude/` | Assessment |
|--------|-------------|-----------|------------|
| Frontmatter | `name`, `description` | `name`, `description`, `model: opus` | Claude Code uses model frontmatter for agent model selection |
| lean-research-agent | 183 lines | 184 lines | Effectively identical except frontmatter |
| lean-implementation-agent | 231 lines | 268 lines | `.claude/` has expanded "Final Verification Stage" with structured JSON metadata for verification results (`verification_passed`, `sorry_count`, `axiom_count`, `build_passed`) |

**Verdict**: Agent content is functionally equivalent. The `.claude/` implementation agent has a more rigorous verification recording system.

### 5. Files Already Correct (No Changes Needed)

The following files are **identical or functionally equivalent** between the two systems and require no porting work:

- `EXTENSION.md`
- `settings-fragment.json`
- `commands/lean.md`
- `commands/lake.md`
- `rules/lean4.md`
- `skills/skill-lake-repair/SKILL.md`
- `skills/skill-lean-version/SKILL.md`
- All context files under `context/project/lean4/` (except the 2 extras in `.claude/`)

### 6. `.claude/extensions/core/` Lean References

The core extension in `.claude/` already has lean awareness:

- `.claude/extensions/core/manifest.json` includes `setup-lean-mcp.sh` and `verify-lean-mcp.sh` in its `scripts` array (lines 89, 99)
- `.claude/extensions/core/skills/skill-git-workflow/SKILL.md` references `.lean` files and Mathlib dependencies (lines 85, 134, 137)
- `.claude/extensions/core/skills/skill-fix-it/SKILL.md` has language detection for `.lean` files → "lean" (line 315)
- `.claude/extensions/core/context/patterns/thin-wrapper-skill.md` references `skill-lean-research` as an example (line 199)
- `.claude/extensions/core/docs/guides/creating-skills.md` shows `skill-lean-research/` in directory tree (line 68)

**No updates needed** — the core extension is already lean-aware.

## Decisions

1. **The extension is already ported**: `.claude/extensions/lean/` exists and is functional. The task is actually a parity audit, not a from-scratch port.

2. **Critical bug priority**: The `opencode-agents.json` path bug is the highest priority fix. Without it, the `opencode.json` merge target will reference non-existent files.

3. **Direction of parity**: Since `.claude/extensions/lean/` has **more** content and features than `.opencode/extensions/lean/`, true parity requires either:
   - **Option A**: Backport `.claude/` enhancements to `.opencode/` (up-leveling the source)
   - **Option B**: Accept that `.claude/` is the more mature version and treat it as the new source of truth

   **Recommendation**: Option B — the `.claude/` version has structural improvements (postflight boundaries, verification stages, richer routing) that represent learnings from operating the system. The `.opencode/` version is effectively a snapshot from an earlier iteration.

4. **Scripts ownership**: The `setup-lean-mcp.sh` and `verify-lean-mcp.sh` scripts exist in both `core/scripts/` directories. The lean extension manifest in `.opencode/` claims them, but they are more appropriately owned by `core`. **Keep `.claude/` manifest's empty scripts array** — it's more architecturally correct.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `opencode-agents.json` bug breaks agent loading | High | Fix immediately as part of this task |
| Other extensions have same `opencode-agents.json` bug | Medium | Audit `.claude/extensions/*/opencode-agents.json` for all extensions |
| `.opencode/` and `.claude/` versions diverge further over time | Low | Document which is source of truth; consider automated sync if needed |
| `specs/tmp/` directory used in `.claude/` skills doesn't exist | Low | The skills reference `specs/tmp/state.json` — ensure this directory exists or change to `/tmp/` |

## Context Extension Recommendations

- **Topic**: Extension porting patterns
- **Gap**: No documented checklist for porting an extension from `.opencode/` to `.claude/`
- **Recommendation**: Create `.claude/context/guides/extension-porting-checklist.md` with steps: manifest adaptation, merge_targets conversion, opencode-agents.json creation, skill postflight boundary additions, agent model frontmatter

- **Topic**: `opencode-agents.json` path conventions
- **Gap**: Unclear whether `opencode-agents.json` prompt paths should be absolute extension paths or reference a centralized agent directory
- **Recommendation**: Document the expected path format in `.claude/context/guides/extension-development.md`

## Appendix

### Search Queries Used

1. `glob .opencode/extensions/lean/**/*`
2. `glob .claude/extensions/lean/**/*`
3. `glob .claude/extensions/nvim/**/*`
4. `grep lean .claude/extensions/core/`
5. `find setup-lean-mcp.sh verify-lean-mcp.sh`

### File Comparison Method

Files were compared using direct Read tool inspection. For each file pair:
1. Read `.opencode/` version
2. Read `.claude/` version
3. Note line count differences
4. Identify semantic differences (path references, system-specific conventions, structural additions)
5. Classify as: identical, adapted (correct for target system), or buggy

### References

- `.claude/extensions/nvim/manifest.json` — reference ported extension
- `.claude/extensions/lean/manifest.json` — target extension manifest
- `.opencode/extensions/lean/manifest.json` — source extension manifest
- `.claude/extensions/lean/opencode-agents.json` — contains the critical path bug
- `.claude/extensions/core/manifest.json` — shows core's ownership of lean scripts
