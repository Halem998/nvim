# Research Report: Task #529

**Task**: 529 - Fix 'Model not found: opus/' error in .opencode/ agent system
**Started**: 2026-05-04T00:00:00Z
**Completed**: 2026-05-04T00:30:00Z
**Effort**: Low (straightforward fix, many files affected)
**Dependencies**: None
**Sources/Inputs**:
- Codebase exploration of `.opencode/` directory structure
- Binary analysis of OpenCode CLI v1.14.33 (Nix store)
- `opencode models` output for valid model identifiers
- OpenCode TUI source code (bundled JS in binary)
- `.opencode/docs/guides/creating-commands.md` documentation
**Artifacts**:
- `specs/529_fix_opencode_model_not_found_opus_error/reports/01_model-not-found-research.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The `model: opus` frontmatter in `.opencode/` command files causes "Model not found: opus/" errors because OpenCode CLI expects `provider/model` format (e.g., `opencode/claude-opus-4-7`)
- OpenCode's `parseModel()` splits by `/`, so `"opus"` becomes `{ providerID: "opus", modelID: "" }`, which fails lookup
- 33 files are affected across `.opencode/commands/`, `.opencode/extensions/core/commands/`, and `.opencode/agent/`
- The recommended fix is to **remove the `model:` field entirely** from command frontmatter, allowing the session's active model to be used
- The `model: sonnet` in `orchestrator.md` has the same issue but may not trigger because the orchestrator is a "primary" agent whose model comes from the session

## Context and Scope

The `.opencode/` agent system was ported from `.claude/` which uses short model aliases (`opus`, `sonnet`, `haiku`) that Claude Code maps internally to full API model identifiers. OpenCode CLI has a fundamentally different model reference system using `provider/model` format where providers include `opencode`, `google`, `opencode-go`, etc.

## Findings

### Root Cause: parseModel() Implementation

OpenCode's model parser (decompiled from binary):

```javascript
function parseModel(H) {
  let [L, ...E] = H.split("/");
  return { providerID: L, modelID: E.join("/") }
}
```

When `model: opus` is parsed:
- Input: `"opus"`
- Split by `/`: `["opus"]`
- Result: `{ providerID: "opus", modelID: "" }`
- Error: `"Model not found: opus/"` (providerID + "/" + empty modelID)

### Model Resolution Priority in Command Execution

The server resolves models in this order for slash commands:

1. **Command frontmatter `model:`** - HIGHEST PRIORITY (this is the bug)
2. **Agent's configured model** - if command specifies `agent:` field
3. **Client's current session model** - passed from TUI as `provider/model`
4. **Session default model** - fallback

Because command frontmatter has highest priority, `model: opus` always overrides the session model, immediately triggering the error.

### Why This Worked in Claude Code but Fails in OpenCode

| Aspect | Claude Code | OpenCode |
|--------|-------------|----------|
| Model format | Short alias (`opus`, `sonnet`) | `provider/model` (e.g., `opencode/claude-opus-4-7`) |
| Model field purpose | Tells Claude Code which internal model to use | Tells OpenCode which external provider+model to call |
| Alias resolution | Built-in mapping of `opus` -> `claude-opus-4-6[1m]` | No alias system; raw `split("/")` parsing |
| Valid values | `opus`, `sonnet`, `haiku` | `opencode/claude-opus-4-7`, `google/gemini-2.5-flash`, etc. |

### Valid OpenCode Models (Claude Family)

From `opencode models`:
- `opencode/claude-haiku-4-5`
- `opencode/claude-opus-4-1`
- `opencode/claude-opus-4-5`
- `opencode/claude-opus-4-6`
- `opencode/claude-opus-4-7`
- `opencode/claude-sonnet-4`
- `opencode/claude-sonnet-4-5`
- `opencode/claude-sonnet-4-6`

### Complete List of Affected Files

**`.opencode/commands/` (17 files):**

| File | Line | Current Value |
|------|------|---------------|
| `commands/distill.md` | 3 | `model: opus` |
| `commands/errors.md` | 3 | `model: opus` |
| `commands/fix-it.md` | 3 | `model: opus` |
| `commands/implement.md` | 3 | `model: opus` |
| `commands/learn.md` | 3 | `model: opus` |
| `commands/merge.md` | 3 | `model: opus` |
| `commands/meta.md` | 3 | `model: opus` |
| `commands/plan.md` | 3 | `model: opus` |
| `commands/project-overview.md` | 3 | `model: opus` |
| `commands/refresh.md` | 3 | `model: opus` |
| `commands/research.md` | 3 | `model: opus` |
| `commands/review.md` | 3 | `model: opus` |
| `commands/revise.md` | 3 | `model: opus` |
| `commands/spawn.md` | 3 | `model: opus` |
| `commands/tag.md` | 3 | `model: opus` |
| `commands/task.md` | 3 | `model: opus` |
| `commands/todo.md` | 3 | `model: opus` |

**`.opencode/extensions/core/commands/` (15 files):**

| File | Line | Current Value |
|------|------|---------------|
| `extensions/core/commands/errors.md` | 3 | `model: opus` |
| `extensions/core/commands/fix-it.md` | 3 | `model: opus` |
| `extensions/core/commands/implement.md` | 3 | `model: opus` |
| `extensions/core/commands/merge.md` | 3 | `model: opus` |
| `extensions/core/commands/meta.md` | 3 | `model: opus` |
| `extensions/core/commands/plan.md` | 3 | `model: opus` |
| `extensions/core/commands/project-overview.md` | 3 | `model: opus` |
| `extensions/core/commands/refresh.md` | 3 | `model: opus` |
| `extensions/core/commands/research.md` | 3 | `model: opus` |
| `extensions/core/commands/review.md` | 3 | `model: opus` |
| `extensions/core/commands/revise.md` | 3 | `model: opus` |
| `extensions/core/commands/spawn.md` | 3 | `model: opus` |
| `extensions/core/commands/tag.md` | 3 | `model: opus` |
| `extensions/core/commands/task.md` | 3 | `model: opus` |
| `extensions/core/commands/todo.md` | 3 | `model: opus` |

**`.opencode/agent/` (1 file):**

| File | Line | Current Value |
|------|------|---------------|
| `agent/orchestrator.md` | 4 | `model: sonnet` |

**`.opencode/context/templates/` (1 file - documentation):**

| File | Line | Current Value |
|------|------|---------------|
| `context/templates/command-template.md` | 11 | `model: opus` |

**Total: 34 files** (33 operational + 1 template)

**Also affected in other projects (synced from nvim .opencode):**
- `~/Projects/ProofChecker/.opencode/commands/` (15 files with `model: opus`)

## Decisions

- The `model:` field should be **removed entirely** from `.opencode/` command frontmatter rather than being converted to `opencode/claude-opus-4-7`
- Rationale: OpenCode is provider-agnostic; hard-coding a specific provider defeats the design. The session model (user's current choice) should be respected for commands.
- The orchestrator's `model: sonnet` should also be removed for the same reason
- Documentation files (`creating-commands.md`, `command-template.md`, `agent-frontmatter-standard.md`) should be updated to reflect that `model:` is NOT a valid frontmatter field in the `.opencode/` system

## Recommendations

1. **Remove `model:` line from all 33 operational files** - simple `sed` operation removing line 3 (or line 4 for orchestrator) from each file
2. **Update command template** - remove `model: opus` from the template frontmatter
3. **Update documentation** - modify `docs/guides/creating-commands.md` and `docs/reference/standards/agent-frontmatter-standard.md` to document that `model:` is not used in OpenCode (or document the correct `provider/model` format if model pinning is desired)
4. **Update the Neovim extension loader** - if `on_load_all` installs command files to target projects, ensure the template used also lacks `model:` lines
5. **Propagate fix to synced projects** - ProofChecker and other projects need re-sync after the template is fixed

## Risks and Mitigations

- **Risk**: Removing `model:` means commands will use whatever model the user has selected; complex commands might perform poorly on cheap models
  - **Mitigation**: This matches OpenCode's design philosophy. Users who want Opus can select it in the model picker. The session model persists.
- **Risk**: Other projects with synced `.opencode/` dirs still have the broken `model:` field
  - **Mitigation**: Fix the template/source in nvim config first, then re-sync to projects via the extension loader
- **Risk**: The `model:` field in command frontmatter might serve a documentation purpose even if removed from OpenCode
  - **Mitigation**: Add a comment in the creating-commands guide explaining the difference from Claude Code

## Appendix

### Search Queries Used
- `grep -rn "^model:" .opencode/` - Find all model frontmatter
- `grep -rn "opus/" .opencode/` - Search for trailing slash model references
- `opencode models` - List valid model identifiers
- `strings .opencode-wrapped | grep "Model not found"` - Find error message source
- `strings .opencode-wrapped | grep "parseModel"` - Find model parsing logic

### Key Code References
- OpenCode binary: `/nix/store/3h5ibp54w8kc576bcgxzd5vj30ad8pnn-opencode-1.14.33/bin/.opencode-wrapped`
- Error message template: `"error.chain.modelNotFound": "Model not found: {{provider}}/{{model}}"`
- parseModel function: splits input on `/` into providerID and modelID
- Command model resolution: frontmatter > agent config > session model > default
