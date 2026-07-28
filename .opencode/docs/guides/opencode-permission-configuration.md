# OpenCode Permission Architecture

**Version**: 1.0.0
**Last Updated**: 2026-05-07
**Audience**: End users and system maintainers managing OpenCode permission configuration

---

## Table of Contents

1. [Overview](#overview)
2. [Dual-System Architecture](#dual-system-architecture)
3. [external_directory Behavior Patterns](#external_directory-behavior-patterns)
4. [Managing External Path Allowlists](#managing-external-path-allowlists)
5. [Internal-Only Temp File Convention](#internal-only-temp-file-convention)
6. [Troubleshooting](#troubleshooting)
7. [References](#references)

---

## Overview

This project uses two parallel permission systems that serve different roles:
- **Claude Code** permissions control what agents can do at the frontmatter level (file patterns, bash commands)
- **OpenCode** permissions control runtime tool access and workspace boundary enforcement through `opencode.json`

This guide focuses on the OpenCode side: how `external_directory` enforcement works, how to manage external path allowlists, and the project's convention for avoiding external directory prompts entirely.

---

## Dual-System Architecture

### Claude Code Permission System

Defined in agent frontmatter (`.opencode/agent/`, `.claude/agents/`) using YAML with `allow`/`deny` lists:

```yaml
permissions:
  allow:
    - read: ["**/*.md", ".opencode/**/*"]
    - write: ["specs/**/*"]
    - bash: ["git", "grep", "find"]
  deny:
    - bash: ["rm -rf", "sudo"]
    - write: [".git/**/*"]
```

**Role**: Static agent capability control. Determines what each agent type can read, write, edit, and execute. Managed in agent definition files.

**Documentation**: See [permission-configuration.md](permission-configuration.md) for the full Claude Code frontmatter permission guide.

### OpenCode Permission System

Defined in the project root `opencode.json` using JSON with per-tool permission values (`allow`, `ask`, `deny`):

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

**Role**: Runtime tool gating. Controls whether operations trigger permission prompts at execution time. The `external_directory` permission is the key mechanism for workspace boundary enforcement.

**Configuration**: The authoritative `opencode.json` was created and configured as part of the OpenCode permission-configuration work. Refer to that work's artifacts for structural details of the permission block.

### How They Interact

Both systems must approve an operation independently:

1. **Claude Code frontmatter** checks first: is the agent allowed to use this tool on this path pattern?
2. **OpenCode runtime** checks second: is the tool allowed at runtime? Is the path within the workspace?

An operation fails if _either_ system denies it. For example:
- `edit` set to `"allow"` in `opencode.json` but agent frontmatter denies write to `*.lua` → operation blocked by Claude Code
- Agent frontmatter allows write to `**/*` but `external_directory` is `"ask"` for `/tmp/` → user prompted by OpenCode

---

## external_directory Behavior Patterns

### How It Works

The `external_directory` permission triggers when any tool (read, edit, bash, glob, grep) accesses a path **outside the workspace root** (the directory where OpenCode was started, typically `~/.config/nvim` for this project).

It is a **separate check** layered on top of tool-specific permissions. Even if `edit` is set to `"allow"`, writes outside the workspace require `external_directory` to also pass.

### Default Behavior

The default for `external_directory` is `"ask"`, meaning:
- Any file operation touching a path outside `~/.config/nvim` opens a permission prompt
- The user sees: "This operation accesses a file outside your workspace. Allow?"
- User must explicitly approve or deny each prompt

### Common Scenarios

| Scenario | Path Example | external_directory Trigger? | Behavior |
|----------|-------------|---------------------------|----------|
| Edit file in workspace | `lua/neotex/init.lua` | No | Allowed (if `edit: "allow"`) |
| Write to specs/ | `specs/548_.../summary.md` | No | Allowed (if `edit: "allow"`) |
| Read system file | `/etc/hosts` | Yes | Prompted (default `"ask"`) |
| Write to /tmp/ | `/tmp/output.log` | Yes | Prompted (default `"ask"`) |
| Write to home dir | `~/Documents/file.md` | Yes | Prompted (default `"ask"`) |
| Write to allowed external path | `~/projects/personal/file.md` | Yes, but allowed | Allowed (glob match) |
| Read file in workspace | `.opencode/AGENTS.md` | No | Allowed (if `read: "allow"`) |

### Why the Project Uses specs/tmp/

Historically, some hook scripts and agent instructions referenced `/tmp/opencode/` for temporary files. This triggered `external_directory: "ask"` prompts at runtime, interrupting automated workflows.

The project now uses `specs/tmp/` for **all** temporary file operations. Since `specs/` is within the workspace root, these operations never trigger `external_directory` prompts and run without user intervention.

---

## Managing External Path Allowlists

### Adding an Allowed External Path

If you need an agent to access files outside the workspace, add an allow rule to `opencode.json` under `permission.external_directory`:

```json
{
  "permission": {
    "external_directory": {
      "*": "ask",
      "~/projects/personal/**": "allow",
      "~/Documents/notes/**": "allow"
    }
  }
}
```

**Pattern Rules**:
- `*` matches zero or more characters within a path segment (not `/`)
- `**` matches zero or more characters across path segments (including `/`)
- `~` and `$HOME` are expanded to your home directory
- Last matching rule wins
- Deny overrides allow (if a path matches both, deny wins)

### Best Practices for External Paths

1. **Be specific**: Use `~/projects/personal/**` instead of `~/**` to limit exposure
2. **Default to ask**: Keep the catch-all `"*": "ask"` rule to maintain safety
3. **Test with small scopes**: Start with a narrow allow rule and expand if needed
4. **Avoid system directories**: Never allow `/etc/`, `/usr/`, or `/` — these are dangerous
5. **Consider symlinks**: If a program needs `/tmp/` access, consider using a symlink or wrapper instead of allowing the path globally

### Alternative: Symlink Approach

Instead of adding `/tmp/` to the allowlist, create a symlink within the workspace:

```bash
ln -s /tmp/opencode-tmp specs/tmp/external
```

This lets agents access external temp files through the workspace path, avoiding `external_directory` prompts entirely while maintaining workspace containment.

---

## Internal-Only Temp File Convention

This project follows a strict convention of keeping all temporary file operations within the workspace:

| Purpose | Old Path (external) | Current Path (internal) |
|---------|-------------------|------------------------|
| TTS notify scripts | `/tmp/opencode-tts-*` | `specs/tmp/claude-tts-*` |
| Agent temp work | `/tmp/opencode/` | `specs/tmp/` |
| Other temp files | `/tmp/opencode-*` | `specs/tmp/` |

**Verification**:
```bash
# Verify no /tmp/ references in hook scripts
grep -r '/tmp/' .opencode/hooks/*.sh .claude/hooks/*.sh

# Verify no /tmp/opencode references in agent instructions
grep -r '/tmp/opencode' .opencode/extensions/core/agents/ .claude/agents/

# Verify specs/tmp/ is being used
grep -r 'specs/tmp/' .opencode/hooks/*.sh .claude/hooks/*.sh
```

---

## Troubleshooting

### "Permission denied: external_directory" Prompt

**Symptom**: Agent operation triggers a permission prompt for an external path.

**Common causes**:
- Agent is writing to a path outside the workspace root
- A script or hook tries to access a path in `/tmp/` or another external directory
- The `opencode.json` external_directory allowlist doesn't cover the path

**Solutions**:
1. **Check the path**: Is the operation accessing a file outside `~/.config/nvim`?
2. **Move to specs/tmp/**: If it's a temp file, update the script to use `specs/tmp/` instead
3. **Add to allowlist**: If external access is truly necessary, add the path to `external_directory` in `opencode.json`
4. **Use symlink**: Create a workspace-internal symlink to the external path

### Too Many Prompts

**Symptom**: Many operations trigger `external_directory` prompts, interrupting workflow.

**Solution**: Audit which paths are being accessed externally and move operations into the workspace. Check for scripts referencing `/tmp/` — these commonly cause repeated prompts.

### Denied Operation on Workspace File

**Symptom**: Operation on a workspace-internal file is denied.

**Solution**: This is likely a Claude Code frontmatter issue, not `external_directory`. Check the agent's frontmatter permissions in the relevant agent definition file. See [permission-configuration.md](permission-configuration.md) for debugging frontmatter denials.

---

## References

- [permission-configuration.md](permission-configuration.md) — Claude Code frontmatter permission system (agent-level file and command access)
- `opencode.json` — Authoritative source for the current OpenCode permission block configuration
- [OpenCode configuration schema](https://opencode.ai/config.json) — Official JSON schema for `opencode.json`
- [OpenCode permissions documentation](https://opencode.ai/docs/permissions/) — Official documentation on permission system behavior
- `<leader>ao` extension picker — Load extensions (including memory extension) for additional capability
