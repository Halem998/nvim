# Research Report: Task #524

**Task**: 524 - Fix lean extension manifest routing
**Started**: 2026-05-04T00:00:00Z
**Completed**: 2026-05-04T00:00:00Z
**Effort**: ~30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of `.opencode/extensions/lean/manifest.json`, `.opencode/extensions/founder/manifest.json`, `.opencode/extensions/nvim/manifest.json`, `.opencode/extensions/typst/manifest.json`, command files (`research.md`, `plan.md`, `implement.md`), and lean skill definitions.
**Artifacts**: - `specs/524_fix_lean_extension_manifest_routing/reports/01_manifest-routing-research.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary
- The lean extension manifest (`lean/manifest.json`) is **missing a `routing` section entirely**
- The command files (`/research`, `/plan`, `/implement`) look up `.routing.{phase}[$task_type]` from all extension manifests using jq
- Without routing, lean tasks with `task_type: "lean"` or `"lean4"` fall through to defaults (`skill-researcher`, `skill-planner`, `skill-implementer`)
- A working `routing` example exists in the `founder` extension manifest
- The lean extension provides `skill-lean-research` and `skill-lean-implementation` skills that should be routed to
- **Recommendation**: Add a `routing` section mapping `lean` and `lean4` task types to `skill-lean-research` (research) and `skill-lean-implementation` (implement)

## Context & Scope

The OpenCode command system routes tasks to specialized skills based on `task_type` stored in `state.json`. Each extension manifest can declare a `routing` section that maps task types to skills for each phase (research, plan, implement). The lean extension has dedicated skills for research and implementation but lacks the routing configuration, causing all lean tasks to use generic agents instead of Lean-aware ones with MCP tool access.

## Findings

### 1. Current Lean Manifest (No Routing)

File: `.opencode/extensions/lean/manifest.json`

```json
{
  "name": "lean",
  "version": "1.0.0",
  "description": "Lean 4 theorem prover support with MCP integration for proof assistance",
  "language": "lean4",
  "dependencies": [
    "core"
  ],
  "provides": {
    "agents": [
      "lean-research-agent.md",
      "lean-implementation-agent.md"
    ],
    "skills": [
      "skill-lean-research",
      "skill-lean-implementation",
      "skill-lake-repair",
      "skill-lean-version"
    ],
    "commands": [
      "lake.md",
      "lean.md"
    ],
    "rules": [
      "lean4.md"
    ],
    "context": [
      "project/lean4"
    ],
    "scripts": [
      "setup-lean-mcp.sh",
      "verify-lean-mcp.sh"
    ],
    "hooks": []
  },
  "merge_targets": {
    "opencode_md": {
      "source": "EXTENSION.md",
      "target": ".opencode/AGENTS.md",
      "section_id": "extension_oc_lean"
    },
    "settings": {
      "source": "settings-fragment.json",
      "target": ".opencode/settings.local.json"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".opencode/context/index.json"
    }
  },
  "mcp_servers": {
    "lean-lsp": {
      "command": "npx",
      "args": [
        "-y",
        "lean-lsp-mcp@latest"
      ]
    }
  }
}
```

**Observation**: The manifest has `provides.skills` listing the available skills, but **no `routing` key** at the top level.

### 2. Working Routing Example (Founder Extension)

File: `.opencode/extensions/founder/manifest.json`

The founder extension provides the canonical working example of a `routing` section:

```json
  "routing": {
    "research": {
      "founder": "skill-market",
      "founder:market": "skill-market",
      "founder:analyze": "skill-analyze",
      "founder:strategy": "skill-strategy",
      "founder:legal": "skill-legal",
      "founder:project": "skill-project",
      "founder:sheet": "skill-founder-spreadsheet",
      "founder:finance": "skill-finance",
      "founder:financial-analysis": "skill-financial-analysis",
      "founder:deck": "skill-deck-research",
      "founder:meeting": "skill-meeting",
      "founder:consult": "skill-consult"
    },
    "plan": {
      "founder": "skill-founder-plan",
      "founder:market": "skill-founder-plan",
      ...
    },
    "implement": {
      "founder": "skill-founder-implement",
      "founder:market": "skill-founder-implement",
      ...
    }
  }
```

**Key pattern**: Each phase (`research`, `plan`, `implement`) is an object where keys are task types and values are skill names.

### 3. Command File Routing Logic

All three command files use identical patterns to look up routing from manifests.

#### `/research` command (`.opencode/commands/research.md`, lines 338-365):

```bash
# Check extension routing for research (skill_name starts empty)
skill_name=""
for manifest in .opencode/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_skill=$(jq -r --arg tt "$task_type" \
      '.routing.research[$tt] // empty' "$manifest")
    if [ -n "$ext_skill" ]; then
      skill_name="$ext_skill"
      break
    fi
  fi
done

# Fallback: if compound key (contains ":"), try base task_type
if [ -z "$skill_name" ] && echo "$task_type" | grep -q ":"; then
  base_type=$(echo "$task_type" | cut -d: -f1)
  for manifest in .opencode/extensions/*/manifest.json; do
    if [ -f "$manifest" ]; then
      ext_skill=$(jq -r --arg tt "$base_type" \
        '.routing.research[$tt] // empty' "$manifest")
      if [ -n "$ext_skill" ]; then
        skill_name="$ext_skill"
        break
      fi
    fi
  done
fi

# Fallback to default researcher if no extension routing found
skill_name=${skill_name:-"skill-researcher"}
```

#### `/plan` command (`.opencode/commands/plan.md`, lines 341-369):

Identical pattern but queries `.routing.plan[$tt]` and falls back to `skill-planner`.

#### `/implement` command (`.opencode/commands/implement.md`, lines 373-400):

Identical pattern but queries `.routing.implement[$tt]` and falls back to `skill-implementer`.

**Critical insight**: The jq query is `.routing.{phase}[$task_type]`. If `routing` is missing, jq returns `null` which becomes empty string after `-r`, so the fallback is used.

### 4. Lean Skills Available

The lean extension provides 4 skills in `.opencode/extensions/lean/skills/`:

| Skill | File | Purpose | Delegates To |
|-------|------|---------|-------------|
| `skill-lean-research` | `skill-lean-research/SKILL.md` | Research Lean 4/Mathlib theorems | `lean-research-agent` subagent |
| `skill-lean-implementation` | `skill-lean-implementation/SKILL.md` | Implement Lean 4 proofs | `lean-implementation-agent` subagent |
| `skill-lake-repair` | `skill-lake-repair/SKILL.md` | Automated `lake build` repair | Direct execution (no subagent) |
| `skill-lean-version` | `skill-lean-version/SKILL.md` | Lean toolchain management | Direct execution (no subagent) |

**Relevant for routing**: Only `skill-lean-research` and `skill-lean-implementation` are meant for the `/research` and `/implement` command flows. The other two are command-specific skills (`lake.md`, `lean.md`).

### 5. Task Type Values

From the lean skill files, the accepted task languages/types are:
- `"lean"` (from `skill-lean-research/SKILL.md`: "Task language is 'lean4' or 'lean'")
- `"lean4"` (from `skill-lean-implementation/SKILL.md`: same acceptance logic)

The manifest's own `language` field is `"lean4"`.

Both should be mapped to ensure compatibility regardless of which task type string is used.

### 6. Other Extensions Also Lack Routing

For comparison, these extensions also have **no `routing` section**:
- `.opencode/extensions/nvim/manifest.json`
- `.opencode/extensions/typst/manifest.json`
- `.opencode/extensions/nix/manifest.json`

This means they also fall through to defaults. However, the current task scope is specifically the **lean** extension.

## Decisions

1. **Which phases need routing?**
   - `research` -> `skill-lean-research` (extension-specific skill exists)
   - `implement` -> `skill-lean-implementation` (extension-specific skill exists)
   - `plan` -> **NO routing needed** (no extension-specific plan skill exists; default `skill-planner` is appropriate)

2. **Which task type keys?**
   - `"lean"` and `"lean4"` (both accepted by the skills, so both should be mapped)

3. **Where to insert `routing`?**
   - At the top level of the manifest JSON, after `provides` and before `merge_targets` (following the founder extension structure)

## Recommendations

### Exact JSON to Add

Insert this section into `.opencode/extensions/lean/manifest.json`, between the closing `}` of `provides` and the opening `"merge_targets"`:

```json
  "routing": {
    "research": {
      "lean": "skill-lean-research",
      "lean4": "skill-lean-research"
    },
    "implement": {
      "lean": "skill-lean-implementation",
      "lean4": "skill-lean-implementation"
    }
  },
```

### Full Updated Manifest (for reference)

```json
{
  "name": "lean",
  "version": "1.0.0",
  "description": "Lean 4 theorem prover support with MCP integration for proof assistance",
  "language": "lean4",
  "dependencies": [
    "core"
  ],
  "provides": {
    "agents": [
      "lean-research-agent.md",
      "lean-implementation-agent.md"
    ],
    "skills": [
      "skill-lean-research",
      "skill-lean-implementation",
      "skill-lake-repair",
      "skill-lean-version"
    ],
    "commands": [
      "lake.md",
      "lean.md"
    ],
    "rules": [
      "lean4.md"
    ],
    "context": [
      "project/lean4"
    ],
    "scripts": [
      "setup-lean-mcp.sh",
      "verify-lean-mcp.sh"
    ],
    "hooks": []
  },
  "routing": {
    "research": {
      "lean": "skill-lean-research",
      "lean4": "skill-lean-research"
    },
    "implement": {
      "lean": "skill-lean-implementation",
      "lean4": "skill-lean-implementation"
    }
  },
  "merge_targets": {
    "opencode_md": {
      "source": "EXTENSION.md",
      "target": ".opencode/AGENTS.md",
      "section_id": "extension_oc_lean"
    },
    "settings": {
      "source": "settings-fragment.json",
      "target": ".opencode/settings.local.json"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".opencode/context/index.json"
    }
  },
  "mcp_servers": {
    "lean-lsp": {
      "command": "npx",
      "args": [
        "-y",
        "lean-lsp-mcp@latest"
      ]
    }
  }
}
```

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Invalid JSON after edit | Low | Validate with `jq empty .opencode/extensions/lean/manifest.json` after editing |
| Skill names don't match actual skill directory names | Low | Verified: directories are `skill-lean-research/` and `skill-lean-implementation/` |
| `plan` routing omission causes confusion | Low | Documented explicitly in report; no lean-specific planner exists |
| Other task types (e.g., `lean:proof`) not covered | Low | Command files already have compound-key fallback to base type |

## Context Extension Recommendations

- **Topic**: Extension manifest routing documentation
- **Gap**: No centralized documentation explaining the `routing` section schema for extension manifests
- **Recommendation**: Add a context file at `.opencode/context/technical/extension-manifest-routing.md` documenting the `routing` object structure and providing a template

- **Topic**: Missing routing in other extensions
- **Gap**: The `nvim`, `typst`, and `nix` extensions also lack `routing` sections and would benefit from similar fixes
- **Recommendation**: Create follow-up tasks to add routing to `nvim` (skill-neovim-research, skill-neovim-implementation), `typst` (skill-typst-research, skill-typst-implementation), and `nix` (skill-nix-research, skill-nix-implementation) extensions

## Appendix

### Search Queries Used
- `glob: .opencode/extensions/**/manifest.json`
- `read: .opencode/extensions/lean/manifest.json`
- `read: .opencode/extensions/founder/manifest.json`
- `read: .opencode/extensions/nvim/manifest.json`
- `read: .opencode/extensions/typst/manifest.json`
- `read: .opencode/commands/implement.md`
- `read: .opencode/commands/research.md`
- `read: .opencode/commands/plan.md`
- `glob: .opencode/extensions/lean/skills/**/SKILL.md`

### References
- `.opencode/extensions/founder/manifest.json` - Working routing example
- `.opencode/commands/implement.md` lines 365-400 - Implement routing lookup
- `.opencode/commands/research.md` lines 338-365 - Research routing lookup
- `.opencode/commands/plan.md` lines 341-369 - Plan routing lookup
- `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md` - Research skill definition
- `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md` - Implementation skill definition
