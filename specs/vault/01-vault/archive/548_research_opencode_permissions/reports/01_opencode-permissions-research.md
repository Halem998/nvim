# Research Report: Task #548

**Task**: 548 - research_opencode_permissions
**Started**: 2026-05-07T00:00:00Z
**Completed**: 2026-05-07T00:15:00Z
**Effort**: Low
**Dependencies**: None
**Sources/Inputs**:
  - Codebase: `.opencode/settings.json`, `.opencode/templates/opencode.json`, `.opencode/context/schemas/frontmatter-schema.json`, `.opencode/docs/guides/permission-configuration.md`
  - External: `opencode.ai` config schema (JSON schema at `https://opencode.ai/config.json`)
  - External: OpenCode documentation at `https://opencode.ai/docs/permissions/`, `https://opencode.ai/docs/agents/`
  - External: OpenCode GitHub repo (`github.com/opencode-ai/opencode`, now archived; continues as `github.com/charmbracelet/crush`)
**Artifacts**: `specs/548_research_opencode_permissions/reports/01_opencode-permissions-research.md`
**Standards**: report-format.md

## Executive Summary

- OpenCode has a comprehensive permission system defined in `opencode.json` with per-tool controls (`read`, `edit`, `bash`, `external_directory`, etc.) each settable to `allow`, `ask`, or `deny`
- The `external_directory` permission is the key mechanism for distinguishing workspace-internal writes from external writes -- defaults to `ask`, meaning writes outside the project root will prompt by default
- The current Neovim config project has **no `opencode.json` at the project root** -- the existing `.opencode/settings.json` is a Claude Code settings file, not an OpenCode config
- The project already uses `specs/tmp/` internally for temp files (350+ references in scripts), not `/tmp/opencode/`. Moving temp operations entirely under `specs/tmp/` is already the established convention
- To accomplish the user's goal: create an `opencode.json` at the project root with `permission.edit: "allow"` and `permission.external_directory: "ask"`, then move any remaining `/tmp/opencode/` references into `specs/tmp/`

## Context & Scope

The user wants two things:
1. Auto-approve write operations within the workspace root (`~/.config/nvim`) without being prompted, while still requiring permission prompts for writes outside the root
2. Investigate moving temp file operations from `/tmp/opencode/` into the project's `specs/tmp/` directory

This research examines the OpenCode permission system architecture, the available configuration options, the current state of the project's configuration, and the security implications of auto-approving workspace-internal writes.

## Findings

### OpenCode Permission System Architecture

OpenCode's permission model is defined in the `opencode.json` config file under the `permission` key. The system follows these principles:

1. **Default Deny** for `external_directory` and `doom_loop` -- the rest default to `allow`
2. **Last matching rule wins** -- more specific rules override earlier patterns
3. **Deny overrides Allow** -- explicit denies take precedence
4. **Wildcard matching** with `*` (zero or more chars) and `?` (one char)
5. **Home directory expansion** with `~` or `$HOME` prefix

#### Available Permission Keys

| Key | Gates | Granular? | Default |
|-----|-------|-----------|---------|
| `read` | Read tool | Object syntax (glob paths) | `allow` |
| `edit` | Write, Edit, Patch | Object syntax (glob paths) | `allow` |
| `glob` | Glob tool | Object syntax (glob patterns) | `allow` |
| `grep` | Grep tool | Object syntax (regex) | `allow` |
| `bash` | Bash tool | Object syntax (command) | `allow` |
| `task` | Task tool | Object syntax (subagent type) | `allow` |
| `skill` | Skill tool | Object syntax (skill name) | `allow` |
| `lsp` | LSP queries | Non-granular | `allow` |
| `external_directory` | Any tool touching paths outside workspace | Object syntax (glob paths) | **`ask`** |
| `doom_loop` | Recovery prompts (3 repeated calls) | Non-granular | **`ask`** |
| `question` | Questions asked during execution | Non-granular | `allow` |
| `webfetch` | WebFetch tool | Object syntax (URL) | `allow` |
| `websearch` | WebSearch tool | Object syntax (query) | `allow` |

#### The `external_directory` Permission

This is the key mechanism for path-based permission scoping. It triggers when any tool (read, edit, bash, glob, grep) touches a path outside the project's working directory (the directory where OpenCode was started, or the path passed via `-c` flag).

**Critical behavior**: `external_directory` is a separate check that runs in addition to the tool-specific check. Even if `edit` is set to `allow`, writes outside the workspace require `external_directory` to also be `allow`. The default for `external_directory` is `ask`.

Example configuration:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "edit": "allow",
    "external_directory": {
      "*": "ask",
      "~/projects/personal/**": "allow"
    }
  }
}
```

This allows editing anywhere within the project root (default `allow` behavior), prompts for external writes to most paths, and auto-approves writes under `~/projects/personal/`.

### Workspace Root Detection

OpenCode determines the workspace root (project root) from:
1. The `-c` flag passed at startup (`opencode -c /path/to/project`)
2. If no `-c` flag, the current working directory

Any file path outside this root directory is considered "external" and triggers the `external_directory` permission check. The workspace root is also the base for all relative paths in tools.

**For this project**: The user runs OpenCode from `~/.config/nvim`, which is the git root. This means all paths under `~/.config/nvim` are within the workspace root by default.

### Current Project Configuration State

The Neovim config project has **no `opencode.json` at the project root** (`/home/benjamin/.config/nvim/opencode.json` -- does not exist). Here is the current configuration landscape:

#### `.opencode/settings.json` (Claude Code, NOT OpenCode)
This is a Claude Code settings file containing:
```json
{
  "permissions": {
    "allow": ["Bash(git:*)", "Bash(nvim *)", ...],
    "deny": ["Bash(rm -rf /)", ...]
  },
  "hooks": {
    "PreToolUse": [{ "matcher": "Write", ... }],
    "PostToolUse": [...],
    "Notification": [{ "matcher": "permission_prompt|idle_prompt|elicitation_dialog", ... }]
  }
}
```

This uses the Claude Code permission format (flat string lists with `Tool(args)` syntax), which is **different from** the OpenCode permission format (JSON object with `allow`/`ask`/`deny` actions). The `hooks` section (PreToolUse, PostToolUse, Notification) is also Claude Code-specific.

The PreToolUse hook on `Write` currently returns `permissionDecision: "allow"` for all writes, effectively bypassing Claude Code's write permission prompts. This works in the current Claude Code environment but does **not** apply to OpenCode's permission model.

#### `.opencode/templates/opencode.json` (OpenCode template)
The template at `.opencode/templates/opencode.json` defines agents but has **no `permission` section**. It specifies which tools each agent has access to (via the legacy `tools` boolean pattern), but does not use OpenCode's newer `permission` field.

#### Extension Settings Fragments
Extensions under `.opencode/extensions/*/settings-fragment.json` use the Claude Code format:
```json
{
  "permissions": {
    "allow": ["mcp__nixos__nix", "mcp__nixos__nix_versions"]
  }
}
```
These are merged into the Claude Code settings, not used for OpenCode. They do not exist in OpenCode permission format.

#### `.opencode/docs/guides/permission-configuration.md` (Internal Guide)
This is the project's internal documentation on the Claude Code permission system. It covers:
- Agent frontmatter YAML permissions (Claude Code format: `allow`/`deny` arrays of `read:`/`write:`/`edit:`/`bash:` glob patterns)
- Safety boundaries (destructive operations to deny)
- Debugging permission denials
- Common permission patterns

This guide documents the Claude Code agent frontmatter permission system, **not** the OpenCode `opencode.json` permission system. The two use different syntax and structures.

**Key gap**: There is no documentation in this project about OpenCode's JSON-based permission configuration. The existing docs only cover the Claude Code frontmatter format.

### How Permissions Currently Work (What the User Experiences)

The user's reported behavior ("routinely asked for permission when running OpenCode in Neovim") suggests one of:

1. **Currently running OpenCode through Claude Code**: The prompt might be the Claude Code permission dialog (even though the PreToolUse hook on Write should auto-approve it -- possibly the hook isn't matching properly, or the prompt is for external_directory access)
2. **`external_directory` defaults to `ask`**: If OpenCode sees `/tmp/opencode/` paths as external to the project root, writes there would trigger an `external_directory` prompt even if general `edit` is allowed
3. **No `opencode.json` at root**: OpenCode uses its defaults, meaning `external_directory` is `ask`

### Temporary File Conventions

The project already has an extensive convention for temp files:

1. **specs/tmp/ is heavily used**: Over 350 references across `.opencode/` scripts and commands use `specs/tmp/` for atomic state updates, jq filters, and temporary files (e.g., `specs/tmp/state.json`, `specs/tmp/merged-index.json`)
2. **Postflight standards document** `specs/tmp/` as the preferred temp location for atomic writes (`mkdir -p specs/tmp`, then `mv specs/tmp/state.json specs/state.json`)
3. **Some `/tmp/opencode/` references remain**: The tts-notify hook currently uses `/tmp/opencode-tts-*` paths -- these could be migrated to `specs/tmp/opencode-tts-*` to keep all temp operations within the project
4. **The agent instructions reference `/tmp/opencode/`**: In the general-research-agent prompt (visible in this session): "Use `/tmp/opencode` for temporary work outside the workspace" -- but the actual scripts in the project all use `specs/tmp/`

### Hooks and Permission Decision Integration

The project's `.opencode/settings.json` uses Claude Code's hook system:
- **PreToolUse hook on Write**: Returns `permissionDecision: "allow"` for all files (with special handling for `specs/state.json` to add a reason)
- **Notification hook**: Matches `permission_prompt|idle_prompt|elicitation_dialog` for TTS integration

In OpenCode, the equivalent would be setting `permission.edit: "allow"` in `opencode.json`. OpenCode's hook system (if supported) has a different interface from Claude Code's.

### Security Considerations

Auto-approving workspace-internal writes is **safe** when combined with:
1. **Git safety**: All changes are tracked by git and can be rolled back (`git reset --hard HEAD`)
2. **`.syncprotect`**: Critical files can be protected from automated modification
3. **Explicit denies for dangerous paths**: `.git/`, `.env`, credential files should remain denied

**Recommendation**: Auto-approve writes within the project root (default `edit: "allow"`), keep `external_directory: "ask"`, and deny destructive bash commands (`rm -rf`, `sudo`, etc.). This is the pattern recommended by the OpenCode permission documentation.

### OpenCode vs. Claude Code Permission Systems

The project uses TWO different permission systems:

| Aspect | Claude Code | OpenCode |
|--------|-------------|----------|
| Config location | `.opencode/settings.json` | `opencode.json` (project root) |
| Permission format | Flat arrays: `["Bash(git:*)", ...]` | Object with `allow`/`ask`/`deny` |
| External path control | Via deny rules on paths | `external_directory` key |
| Hooks | PreToolUse/PostToolUse | Not documented for OpenCode |
| Agent frontmatter | `permissions.allow`/`.deny` arrays | `permission` object in `opencode.json` |

The project's scripts and hooks are all written for the Claude Code format. An `opencode.json` for OpenCode would need to be separate from the existing `.opencode/settings.json`.

### Agent Permissions Override

OpenCode allows per-agent permission overrides. Agents defined in `opencode.json` can have their own `permission` block:

```json
{
  "agent": {
    "build": {
      "mode": "primary",
      "permission": {
        "edit": "allow",
        "external_directory": "ask"
      }
    },
    "plan": {
      "mode": "primary",
      "permission": {
        "edit": "deny",
        "bash": "deny"
      }
    }
  }
}
```

Agent-specific permissions override global permissions for that agent. This means different agents can have different permission levels.

## Decisions

1. **Create `opencode.json` at the project root** with OpenCode-formatted permissions (not merging with the existing `.opencode/settings.json` which is Claude Code)
2. **Set `edit: "allow"`** to auto-approve writes within the workspace root -- this is the default behavior but should be explicit for clarity
3. **Set `external_directory: "ask"`** (default) to require prompts for writes outside the project root -- keep this explicit
4. **Deny dangerous bash commands**: `rm -rf`, `sudo`, `chmod 777` at minimum
5. **Migrate remaining /tmp/opencode/ references to specs/tmp/**: Only the tts-notify hook needs updating
6. **Do NOT modify `.opencode/settings.json`**: It serves a different purpose (Claude Code compatibility)

## Recommendations

### Priority 1: Create opencode.json with Permission Configuration

Create `/home/benjamin/.config/nvim/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "default_agent": "build",
  "permission": {
    "edit": "allow",
    "external_directory": {
      "*": "ask",
      "/tmp/opencode/**": "allow"
    },
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",
      "sudo *": "deny",
      "chmod 777 *": "deny",
      "chmod -R *": "deny"
    }
  }
}
```

**Rationale**:
- `edit: "allow"` enables auto-approval for all in-root writes
- `external_directory: "ask"` ensures writes outside root require permission
- Allowing `/tmp/opencode/**` as an external directory means temp operations there are permitted without prompts
- Destructive bash commands are denied

### Priority 2: Migrate tts-notify.sh from /tmp/ to specs/tmp/

Update `.opencode/hooks/tts-notify.sh` (and `.opencode/extensions/core/hooks/tts-notify.sh`) to use `specs/tmp/` paths instead of `/tmp/` paths:

```
LAST_NOTIFY_FILE="specs/tmp/opencode-tts-last-notify"
LOG_FILE="specs/tmp/opencode-tts-notify.log"
TEMP_WAV="specs/tmp/opencode-tts-$$.wav"
```

This eliminates the last remaining `/tmp/` dependency in the project hooks and ensures all temp file operations are within the project root, avoiding external_directory permission prompts entirely.

### Priority 3: Update Agent Instructions

Update the agent instructions in `general-research-agent.md` to reference `specs/tmp/` instead of `/tmp/opencode/`:

Current: "Use `/tmp/opencode` for temporary work outside the workspace"
Change to: "Use `specs/tmp/` for temporary work within the project"

This aligns the documented convention with the actual practice (scripts already use `specs/tmp/`).

### Priority 4: Create Permission Documentation

Create `.opencode/docs/guides/opencode-permission-configuration.md` documenting how the OpenCode permission system is configured for this project, including:
- The two permission systems (Claude Code .opencode/settings.json vs. OpenCode opencode.json)
- How external_directory controls out-of-root writes
- The /tmp/opencode/ fallback pattern for operations that need external access
- How to add new allowed external paths

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `opencode.json` conflicts with Claude Code config | OpenCode might read both and produce unexpected behavior | Verify OpenCode only reads opencode.json, not .opencode/settings.json |
| Auto-approving all in-root edits includes .git/ | Accidental git corruption | Add explicit `edit: { ".git/**": "deny" }` rule |
| /tmp/opencode/ permission exposes writes outside project | Files in /tmp/ could be modified by OpenCode | Keep /tmp/opencode/ in external_directory allow since it's OpenCode's own temp space |
| Removing /tmp/opencode/ allowance breaks sessions | Agents might expect /tmp/opencode/ to exist | Keep the external_directory allow for /tmp/opencode/ as a fallback until all references are migrated |

## Context Extension Recommendations

- **Topic**: OpenCode permission configuration (openpencode.json format)
- **Gap**: Existing documentation in `.opencode/docs/guides/permission-configuration.md` covers only the Claude Code agent frontmatter format, not the OpenCode `opencode.json` permission system
- **Recommendation**: Either extend the existing guide with an OpenCode section, or create a new guide at `.opencode/docs/guides/opencode-permission-configuration.md` specifically for the OpenCode config format

- **Topic**: Two-system permission architecture (Claude Code + OpenCode)
- **Gap**: The project uses both Claude Code (`.opencode/settings.json`) and OpenCode (`opencode.json`) config files, but there is no documentation explaining how they interact, which one takes precedence, or why both exist
- **Recommendation**: Add a section to the system overview or a dedicated guide explaining the dual-system architecture

## Appendix

### Configuration File Locations Searched
- `/home/benjamin/.config/nvim/opencode.json` -- **Does not exist**
- `/home/benjamin/.config/nvim/.opencode/settings.json` -- Exists, Claude Code format
- `/home/benjamin/.config/nvim/.opencode/templates/opencode.json` -- Template only
- `~/.opencode.json` -- Not checked (global user config)
- `$XDG_CONFIG_HOME/opencode/.opencode.json` -- Not checked

### OpenCode Schema Reference URLs
- Config schema: `https://opencode.ai/config.json`
- Permissions docs: `https://opencode.ai/docs/permissions/`
- Agents docs: `https://opencode.ai/docs/agents/`
- OpenCode GitHub: `https://github.com/opencode-ai/opencode` (archived Sep 2025, continues as `https://github.com/charmbracelet/crush`)

### Codebase Files Examined
- `.opencode/settings.json` -- Full contents reviewed
- `.opencode/templates/opencode.json` -- Full contents reviewed
- `.opencode/docs/guides/permission-configuration.md` -- Full contents reviewed
- `.opencode/context/schemas/frontmatter-schema.json` -- Full contents reviewed
- `.opencode/extensions/*/settings-fragment.json` -- Reviewed nix, lean, memory, epidemiology
- `.opencode/hooks/validate-plan-write.sh` -- Reviewed hook logic
- `.opencode/agent/subagents/general-research-agent.md` -- Reviewed for /tmp/ references

### Stats
- `specs/tmp/` references in `.opencode/`: **350+** (in scripts, commands, skills)
- `/tmp/opencode/` references in `.opencode/`: **3** (tts-notify.sh × 2, archive report)
- Extensions with settings fragments: **4** (nix, lean, memory, epidemiology -- all Claude Code format)
