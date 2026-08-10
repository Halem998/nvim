# Design Guidance: Task 599 — Update CLAUDE.md, Extension Integration, and Documentation

**Source**: Task 592 architecture design
**Authoritative Reference**: `.claude/docs/architecture/architecture-spec.md` Component 6
**Depends on**: Tasks 594, 595, 596, 597, 598 (all upstream refactoring complete)
**Blocks**: Task 600 (docs revision)

---

## Overview

Task 599 is the final integration and documentation pass. It assumes all 7 architecture components
are implemented (tasks 593-598). Its deliverables are:
1. Extension lifecycle hooks: manifest.json `hooks` schema + skill-base.sh invocations
2. Thin extension skills (30-50 lines each)
3. CLAUDE.md regeneration
4. Documentation updates (.claude/docs/)

---

## Extension Lifecycle Hooks

### manifest.json `hooks` Schema

Add to every extension's `manifest.json`:

```json
{
  "name": "nix",
  "version": "1.0.0",
  "task_types": [...],
  "skills": [...],
  "agents": [...],
  "hooks": {
    "preflight": "scripts/nix-preflight.sh",
    "context_injection": "scripts/nix-context.sh",
    "postflight": "scripts/nix-postflight.sh",
    "verification": "scripts/nix-verify.sh"
  }
}
```

All `hooks` fields are **optional**. Absent hooks are silently skipped (no error, no log).

### Hook Script Convention

Each hook script lives in `extensions/{ext-name}/scripts/` and receives:

```bash
#!/usr/bin/env bash
# Extension hook script
# Arguments:
#   $1 = task_number (integer)
#   $2 = task_type (string, e.g. "nix")
#   $3 = task_dir (path, e.g. "specs/242_configure_nixos")
#   $4 = session_id (string)
#   $5 = operation (string: "research" | "plan" | "implement")

# Example: nix-preflight.sh
task_number="$1"
task_type="$2"
task_dir="$3"
session_id="$4"
operation="$5"

# Hooks MUST:
# - Exit 0 on success
# - Exit 1 on fatal failure (skill aborts)
# - Write to stdout for logging

# Hooks MAY:
# - Write files to $task_dir/ (for context injection)
# - Set environment variables (for downstream subagent)
# - NOT modify state.json directly (skill-base.sh owns state)
```

### Hook Invocation Points in `skill-base.sh`

After task 594 creates `skill-base.sh`, task 599 adds hook invocations at 4 points:

```bash
# In skill_preflight_update() — Stage 2
call_hook "preflight" "$task_number" "$task_type" "$task_dir" "$session_id" "$operation"

# In skill_prepare_delegation() — Stage 4
call_hook "context_injection" "$task_number" "$task_type" "$task_dir" "$session_id" "$operation"

# In skill_validate_artifact() — Stage 6a
call_hook "verification" "$task_number" "$task_type" "$task_dir" "$session_id" "$operation"

# In skill_postflight_update() — Stage 7
call_hook "postflight" "$task_number" "$task_type" "$task_dir" "$session_id" "$operation"

# Helper function to call hooks
call_hook() {
  local hook_name="$1"
  shift
  local hook_script=$(get_extension_hook "$TASK_TYPE" "$hook_name")
  if [ -n "$hook_script" ] && [ -f "$hook_script" ]; then
    echo "[skill-base] calling hook: $hook_name ($hook_script)"
    bash "$hook_script" "$@" || {
      if [ "$hook_name" = "preflight" ]; then
        echo "ABORT: preflight hook failed for $TASK_TYPE" >&2
        exit 1
      else
        echo "WARNING: $hook_name hook failed (non-fatal)" >&2
      fi
    }
  fi
}

get_extension_hook() {
  local task_type="$1"
  local hook_name="$2"
  # Read hook path from extension manifest.json
  local manifest=$(find .claude/extensions -name manifest.json | \
    xargs jq -r "select(.name == \"$task_type\") | .hooks.$hook_name // empty" 2>/dev/null | head -1)
  echo "$manifest"
}
```

**Note**: Only `preflight` hook failure is fatal. `context_injection`, `verification`, and
`postflight` hook failures are logged but non-blocking.

---

## Extension Skill Thinning

### Target: 30-50 Lines Per Extension Skill

Before (current state, ~400-600 lines):
```markdown
# skill-nix-implementation/SKILL.md
[Full 11-stage lifecycle replicated here — 400-600 lines]
```

After (target state, ~30-50 lines):
```markdown
---
name: skill-nix-implementation
description: Implement Nix configuration changes from plans.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Nix Implementation Skill

Source `.claude/scripts/skill-base.sh` for the shared lifecycle.

## Stage 4: Context Injection

The `hooks.context_injection` script (`scripts/nix-context.sh`) gathers Nix-specific context:
- Available NixOS options via mcp__nixos query
- Current flake.nix structure
- Home Manager configuration patterns

This context is written to `$task_dir/.nix-context.md` for the agent to read.

## Stage 5: Invoke Nix Implementation Agent

Invoke with `subagent_type: "nix-implementation-agent"`.

Delegation context includes:
- `task_number`, `task_type`, `task_dir`, `session_id`
- `nix_context_path` (path to .nix-context.md from Stage 4)
- Standard orchestrator fields

## Shared Lifecycle

All other stages (validate, preflight, postflight, artifact linking, cleanup)
are provided by sourcing `.claude/scripts/skill-base.sh`.
```

### Migration Steps Per Extension

For each of the 16 extensions:
1. Read current `skill-{ext}-implementation/SKILL.md` (full lifecycle)
2. Extract Stage 4 context collection logic → `scripts/{ext}-context.sh`
3. Extract preflight/postflight logic → `scripts/{ext}-preflight.sh`, `scripts/{ext}-postflight.sh`
4. Add `hooks` section to `manifest.json`
5. Replace SKILL.md with 30-50 line wrapper
6. Validate: run /implement on an extension task, verify same behavior

---

## CLAUDE.md Regeneration

### Sections Requiring Update

1. **Command Reference table**: Add `/orchestrate` row
   ```
   | `/orchestrate` | `/orchestrate N` | Autonomous lifecycle: research → plan → implement |
   ```

2. **Skill-to-Agent Mapping table**: Add skill-orchestrate row
   ```
   | skill-orchestrate | (direct execution) | - | Orchestration state machine |
   ```

3. **Shared Utilities section** (NEW): Document new scripts
   ```markdown
   ## Shared Infrastructure

   Scripts in `.claude/scripts/` provide reusable lifecycle logic:
   - `parse-command-args.sh` — Arg parsing for commands
   - `command-gate-in.sh` — CHECKPOINT 1: session + task lookup
   - `command-gate-out.sh` — CHECKPOINT 2: artifact verification
   - `skill-base.sh` — Shared skill lifecycle (11 functions)
   - `dispatch-agent.sh` — Fork-vs-subagent decision function
   ```

4. **Extension Task Types table**: Verify all 16 extensions still listed correctly

### Auto-Generated Content

CLAUDE.md is auto-generated from merge-sources. The regeneration process should:
1. Run the merge-sources script
2. Verify new /orchestrate section appears
3. Verify shared utilities section appears
4. Verify extension routing table is complete

---

## Documentation Files Requiring Update

### `.claude/docs/guides/creating-commands.md`

Add section: **Using Shared Infrastructure**
- How to source `parse-command-args.sh`
- How to source `command-gate-in.sh` and `command-gate-out.sh`
- Target: commands should be 150-200 lines, routing-only

### `.claude/docs/guides/creating-skills.md`

Add section: **Using skill-base.sh**
- How to source skill-base.sh
- Which functions to call at each stage
- What remains skill-specific (Stages 4-5)
- How to add orchestrator_mode support

### `.claude/docs/guides/creating-agents.md`

Add section: **orchestrator_mode flag**
- When agents receive this flag
- How to write `.orchestrator-handoff.json`
- Token budget constraints for handoff

### `.claude/docs/guides/extension-development.md`

Add section: **Lifecycle Hooks** (referencing `manifest.json` `hooks` schema)
- Available hook points
- Hook script contract
- How to write a `context_injection` hook

### `system-overview.md`

Update to reflect completed refactored architecture:
- Remove "current state" label (system is now the refactored state)
- Add new components: skill-base.sh, dispatch-agent.sh, skill-orchestrate
- Update file layout diagrams

---

## Verification

```bash
# Verify all extensions have hooks section in manifest.json
for manifest in .claude/extensions/*/manifest.json; do
  ext=$(jq -r '.name' "$manifest")
  has_hooks=$(jq '.hooks != null' "$manifest")
  echo "$ext: hooks=$has_hooks"
done

# Verify extension skills are thin
wc -l .claude/extensions/*/skills/*/SKILL.md
# Each: 30-50 lines

# Verify CLAUDE.md has /orchestrate
grep -n "orchestrate" .claude/CLAUDE.md

# Verify documentation guides updated
ls .claude/docs/guides/creating-commands.md \
   .claude/docs/guides/creating-skills.md \
   .claude/docs/guides/creating-agents.md \
   .claude/docs/guides/extension-development.md

# Functional test: verify extension still works after refactoring
# 1. /research a neovim task → hook invoked, nvim context collected
# 2. /implement a nix task → nix-context.sh invoked, agent has nix context
```
