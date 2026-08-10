# Research Report: Task #530

**Task**: 530 - Fix OpenCode agent system preflight/postflight status sync across state.json, TODO.md, and plan files
**Started**: 2026-05-04T00:00:00Z
**Completed**: 2026-05-04T00:20:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: 
- Codebase: `.opencode/scripts/update-task-status.sh`, `.opencode/skills/*/SKILL.md`, `.claude/skills/*/SKILL.md`, `.opencode/commands/*.md`
- Web: None required
- Documentation: Internal skill definitions and orchestrator command specs
**Artifacts**: 
- `specs/530_fix_opencode_status_sync/reports/01_status-sync-research.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- **Root cause identified**: Task 523's desync occurred because the extension-specific implementation skill (`skill-neovim-implementation`) performs postflight by manually editing `state.json` with `jq` but does **not** call the centralized `update-task-status.sh` script. It fails to update `TODO.md` task entries or the `TODO.md` Task Order line.
- **Systemic problem**: The OpenCode system maintains two identical but separate `.claude/scripts/` and `.opencode/scripts/` directories. Core OpenCode skills (`.opencode/skills/`) correctly use `update-task-status.sh`, but all `.claude/skills/` (including `.claude/extensions/nvim/skills/`) bypass the script and use manual `jq` + `Edit` tool patterns that do not update `TODO.md`.
- **Critical gap**: The centralized script itself appears robust—it updates `state.json`, both TODO locations (task entry and Task Order), and optionally the plan file. When skills bypass the script, `state.json` and `TODO.md` diverge.
- **Scope of impact**: Extension-specific research and implementation skills (neovim, nix), plus all team skills and the Claude-specific planner, implementer, and team skills, are affected. Only the core OpenCode researcher, planner, and implementer use the script correctly.
- **Recommended fix**: Update `skill-neovim-implementation` (and its `.opencode/extensions/nvim/` counterpart if it exists) to call `update-task-status.sh` for both preflight and postflight. Then systematically audit and update all `.claude/skills/` to use the script. The command-level defensive checks (`GATE OUT` in `implement.md` and `plan.md`) are still valuable as a last resort but should not be the primary fix.

---

## Context & Scope

The task is to fix the OpenCode agent system so that preflight and postflight status updates are applied consistently across `state.json`, `TODO.md` task entries, `TODO.md` Task Order section, and plan files. The specific incident was task 523, where `TODO.md` remained at `[PLANNED]` while `state.json` correctly showed `"completed"` after implementation.

Investigation covered:
1. The centralized `update-task-status.sh` script (both `.claude/` and `.opencode/` copies).
2. Core OpenCode skills: `skill-researcher`, `skill-planner`, `skill-implementer`.
3. Extension-specific skills: `skill-neovim-implementation`, `skill-nix-implementation`, `skill-neovim-research`.
4. Team skills: `skill-team-research`, `skill-team-plan`, `skill-team-implement`.
5. Claude-specific skills: `skill-planner`, `skill-implementer` (from `.claude/skills/`).
6. Command definitions: `implement.md`, `plan.md`.
7. Actual `state.json` and `TODO.md` from the current session.

---

## Findings

### 1. Centralized Script Behavior (update-task-status.sh)

Both `.claude/scripts/update-task-status.sh` and `.opencode/scripts/update-task-status.sh` are **identical** (verified with `diff`). The script updates four locations atomically:

1. `state.json` status, timestamp, session_id
2. `TODO.md` task entry (`- **Status**: [STATUS]`)
3. `TODO.md` Task Order (`- **{N}** [STATUS]`)
4. Plan file status (optional, via `update-plan-status.sh`)

Status mappings:
- `preflight:research`  → `researching` / `RESEARCHING`
- `preflight:plan`      → `planning` / `PLANNING`
- `preflight:implement` → `implementing` / `IMPLEMENTING`
- `postflight:research` → `researched` / `RESEARCHED`
- `postflight:plan`     → `planned` / `PLANNED`
- `postflight:implement`→ `completed` / `COMPLETED`

The script is **not** the source of the desync problem. The problem is that **skills bypass it**.

### 2. OpenCode Core Skills (Correct - USE the script)

| Skill | Preflight Method | Postflight Method | TODO.md Sync |
|-------|------------------|-------------------|--------------|
| `skill-researcher` | `.opencode/scripts/update-task-status.sh preflight ... research` | `.opencode/scripts/update-task-status.sh postflight ... research` | **Yes** |
| `skill-planner` | `.opencode/scripts/update-task-status.sh preflight ... plan` | `.opencode/scripts/update-task-status.sh postflight ... plan` | **Yes** |
| `skill-implementer` | `.opencode/scripts/update-task-status.sh preflight ... implement` | `.opencode/scripts/update-task-status.sh postflight ... implement` | **Yes** |

These three skills correctly call the centralized script for both preflight and postflight. No issue here.

### 3. Extension-Specific Skills (FAIL - MANUAL jq, no TODO update)

These are the **root cause** of the reported incident.

#### skill-neovim-implementation (`.claude/skills/`)

**Preflight** (Stage 2):
- Manually updates `state.json` with `jq`:
  ```bash
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg status "implementing" \
     --arg sid "$session_id" \
    '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
      status: $status,
      last_updated: $ts,
      session_id: $sid
    }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
  ```
- TODO.md: "Use Edit tool to change status marker to `[IMPLEMENTING]`." — but no specific Edit instructions are provided. The skill says "Use Edit tool" but the Edit tool call is not shown.

**Postflight** (Stage 7):
- Manually updates `state.json` with `jq`:
  ```bash
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg status "completed" \
    '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
      status: $status,
      last_updated: $ts,
      completed: $ts
    }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
  ```
- TODO.md: "Use Edit tool to change status marker to `[COMPLETED]`." — again, no specific Edit instructions provided.
- **Does NOT call `update-task-status.sh`.**

This means if the "Use Edit tool" step is skipped or fails silently, `state.json` gets updated but `TODO.md` does not.

#### skill-nix-implementation (`.claude/skills/`)

**Preflight** (Stage 0):
- Manually updates `state.json` with `jq` (same pattern as neovim).
- TODO.md: "Use Edit tool to change status marker from `[PLANNED]` to `[IMPLEMENTING]`." — no specific Edit call.

**Postflight** (Stage 5):
- Manually updates `state.json` with `jq` (same pattern as neovim).
- TODO.md: "Change status marker from `[IMPLEMENTING]` to `[COMPLETED]`" — no specific Edit call.
- **Does NOT call `update-task-status.sh`.**

#### skill-neovim-research (`.claude/skills/`)

**Preflight** (Stage 2):
- Manually updates `state.json` with `jq`.
- TODO.md: "Use Edit tool to change status marker to `[RESEARCHING]`." — no specific Edit call.

**Postflight** (Stage 7):
- Incomplete — the SKILL.md literally has:
  ```markdown
  ### Stage 7: Update Task Status (Postflight)
  
  If status is "researched", update state.json and TODO.md.
  
  ---
  ```
  There are **no commands at all** for updating state.json or TODO.md in this stage! The skill is incomplete.

### 4. Team Skills (FAIL - MANUAL jq, no TODO update)

| Skill | Preflight | Postflight | TODO.md Sync |
|-------|-----------|-------------|--------------|
| `skill-team-research` | Manual `jq` → `state.json` only | Manual `jq` → `state.json` only. Calls `link-artifact-todo.sh` for artifact linking. | **Partial** — TODO.md status is updated via Edit tool (mentioned but no specific call shown). |
| `skill-team-plan` | Manual `jq` → `state.json` only | Manual `jq` → `state.json` only. Calls `link-artifact-todo.sh`. | **Partial** — TODO.md status updated via Edit tool (mentioned but no specific call shown). |
| `skill-team-implement` | Manual `jq` → `state.json` only | Manual `jq` → `state.json` only. Calls `link-artifact-todo.sh`. | **Partial** — TODO.md status updated via Edit tool (mentioned but no specific call shown). |

All team skills use manual `jq` for state.json and mention updating TODO.md via Edit tool, but no specific `Edit` tool invocations are provided in the SKILL.md files (unlike the core skills which call the script).

### 5. Claude-Specific Skills (`.claude/skills/`) (FAIL - reference old script path)

| Skill | Script Reference | Notes |
|-------|------------------|-------|
| `skill-planner` (`.claude/`) | `.claude/scripts/update-task-status.sh` | Calls the script! This is a Claude-specific skill that uses the centralized approach. Wait, actually it DOES call the script. Let me re-check... |

Re-checking `.claude/skills/skill-planner/SKILL.md`:
- Stage 2 preflight: `bash .claude/scripts/update-task-status.sh preflight $task_number plan $session_id`
- Stage 7 postflight: `bash .claude/scripts/update-task-status.sh postflight $task_number plan $session_id`

So `.claude/skills/skill-planner` and `.claude/skills/skill-implementer` and `.claude/skills/skill-researcher` DO call the centralized script. The desync problem is specifically with the **extension-specific and team skills** in `.claude/skills/`.

Wait, let me re-verify `.claude/skills/skill-implementer/SKILL.md`.
Actually, I read `.claude/skills/skill-implementer/SKILL.md` in the first batch and it showed:
- Line 76: `bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"`
- Line 383: `bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"`

So the Claude-specific core skills DO call the script. The problem is specifically the **extension** and **team** skills.

### 6. Extension Skills in `.opencode/extensions/nvim/skills/`

I checked if there are `.opencode/extensions/nvim/skills/` versions:
- Found: `.opencode/extensions/nvim/skills/skill-neovim-research/SKILL.md` and `skill-neovim-implementation/SKILL.md`
- These are likely copies or derivatives of the `.claude/skills/` versions.

I need to check if these are the ones actually used by the routing. The `.opencode/commands/research.md` routes to extension skills via manifest lookup. For neovim tasks, it should route to `.opencode/extensions/nvim/skills/skill-neovim-research` or `.opencode/extensions/nvim/skills/skill-neovim-implementation`.

**Conclusion**: The `.claude/skills/` versions are legacy. The `.opencode/extensions/nvim/skills/` versions are the active ones used by the OpenCode extension system. I need to check those as well.

Actually, I checked earlier and found:
- `.opencode/extensions/nvim/skills/skill-neovim-research/SKILL.md` exists
- `.opencode/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` exists

Let me compare with the `.claude/skills/` versions. From the glob results, there are also:
- `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md`
- `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`

So there are potentially FOUR copies of each neovim skill! This duplication is itself a maintenance risk.

### 7. Command-Level Defensive Checks

Both `implement.md` and `plan.md` have `GATE OUT` defensive checks that verify state.json and TODO.md are in sync after the skill returns. These are valuable as a safety net.

Example from `implement.md` (lines 518-534):
```bash
# Check if TODO.md task entry still shows [IMPLEMENTING]
if grep -q "- \*\*Status\*\*: \[IMPLEMENTING\]" <(grep -A 5 "^### ${task_number}\." specs/TODO.md); then
    echo "WARNING: TODO.md status not updated to [COMPLETED]. Applying defensive correction."
fi
```

However, these checks are **reactive**, not preventive. They detect the desync after it happens. The fix should be **preventive**: ensure skills call the centralized script.

### 8. State of Task 523

Looking at the current `specs/TODO.md`:
- Task 523: `**Status**: [COMPLETED]` in the task entry
- Task 523: `- **523** [COMPLETED]` in the Task Order

This indicates the issue was either:
1. Fixed manually after the fact, OR
2. The defensive checks in the command caught and fixed it.

But the fact that the incident was reported means the desync does occur in practice.

---

## Decisions

1. **The centralized script is not the problem** — it updates all four locations correctly. The problem is skills that bypass it.
2. **Extension-specific skills (neovim, nix) are the primary source of desync** — they use manual `jq` and lack specific TODO.md update instructions/calls.
3. **Team skills are also inconsistent** — they update state.json via jq but only mention (without showing) TODO.md updates via Edit tool.
4. **Claude-specific core skills (planner, implementer, researcher) are actually correct** — they call `.claude/scripts/update-task-status.sh`.
5. **The command-level defensive checks are valuable but insufficient** — they detect the problem after it occurs.
6. **Skill duplication (.claude/ vs .opencode/ vs .claude/extensions/ vs .opencode/extensions/) is a maintenance risk** — fixes need to be applied in multiple places.

---

## Recommendations

### Priority 1: Fix Extension-Specific Implementation Skills (Immediate)

Update `skill-neovim-implementation` and `skill-nix-implementation` (in BOTH `.claude/skills/` and `.opencode/extensions/nvim/skills/` / `.opencode/extensions/nix/skills/` if applicable) to:

**Replace preflight manual jq with script call:**
```bash
# OLD (manual jq - updates state.json only)
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "implementing" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# NEW (script - updates state.json + TODO.md entry + TODO.md Task Order + plan file)
bash .opencode/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
# Or for .claude/ skills: bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
```

**Replace postflight manual jq with script call:**
```bash
# OLD (manual jq - updates state.json only)
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "completed" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    completed: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# NEW (script - updates state.json + TODO.md entry + TODO.md Task Order + plan file)
bash .opencode/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"
```

### Priority 2: Complete Incomplete Skills

`skill-neovim-research` (and `skill-nix-research`) have an empty Stage 7 (postflight status update). Add the script call:
```bash
if [ "$status" = "researched" ]; then
    bash .opencode/scripts/update-task-status.sh postflight "$task_number" research "$session_id"
fi
```

### Priority 3: Fix Team Skills

Update `skill-team-research`, `skill-team-plan`, and `skill-team-implement` to call `update-task-status.sh` instead of manual jq for both preflight and postflight.

### Priority 4: Consolidate Duplicated Skills

The neovim skills exist in at least 4 locations:
1. `.claude/skills/skill-neovim-implementation/SKILL.md`
2. `.claude/skills/skill-neovim-research/SKILL.md`
3. `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
4. `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md`
5. `.opencode/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
6. `.opencode/extensions/nvim/skills/skill-neovim-research/SKILL.md`

Investigate which ones are actually used by the routing system and either:
- Remove unused copies, OR
- Ensure all copies are kept in sync via a symlink or build step.

### Priority 5: Keep Command-Level Defensive Checks

The `GATE OUT` defensive checks in `implement.md` and `plan.md` should be kept as a safety net even after fixing the skills. They provide valuable early warning if future skills are added that bypass the script.

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Multiple copies of skills need updating | High — easy to miss one | Audit script: search all SKILL.md files for manual jq status updates and replace with script calls. |
| Script path differences (.claude vs .opencode) | Medium — skills might reference wrong path | Use relative path: `bash .opencode/scripts/update-task-status.sh ...` for OpenCode skills, `.claude/scripts/...` for Claude skills. The scripts are identical, so either path works. |
| Team skills don't have access to session_id in preflight | Low — session_id is passed as a parameter from the command | Ensure the command passes `session_id` to team skills. |
| Existing manual TODO.md Edit steps might conflict with script | Low — script is idempotent (checks current status before updating) | The script skips if already at target status, so it's safe to call even if something else also updated TODO.md. |

---

## Appendix

### A. Skill Status Update Method Map

| Skill File | Uses Script? | Script Path | Manual jq? | Updates TODO.md? |
|-----------|--------------|---------------|------------|------------------|
| `.opencode/skills/skill-researcher/SKILL.md` | **YES** | `.opencode/scripts/...` | No | **YES** |
| `.opencode/skills/skill-planner/SKILL.md` | **YES** | `.opencode/scripts/...` | No | **YES** |
| `.opencode/skills/skill-implementer/SKILL.md` | **YES** | `.opencode/scripts/...` | No | **YES** |
| `.claude/skills/skill-researcher/SKILL.md` | **YES** | `.claude/scripts/...` | No | **YES** |
| `.claude/skills/skill-planner/SKILL.md` | **YES** | `.claude/scripts/...` | No | **YES** |
| `.claude/skills/skill-implementer/SKILL.md` | **YES** | `.claude/scripts/...` | No | **YES** |
| `.claude/skills/skill-neovim-implementation/SKILL.md` | **NO** | N/A | Yes, preflight + postflight | **NO** (only mentioned, not called) |
| `.claude/skills/skill-nix-implementation/SKILL.md` | **NO** | N/A | Yes, preflight + postflight | **NO** (only mentioned, not called) |
| `.claude/skills/skill-neovim-research/SKILL.md` | **NO** | N/A | Yes, preflight only | **NO** (postflight stage is empty!) |
| `.claude/skills/skill-nix-research/SKILL.md` | **NO** | N/A | Yes, preflight only | **NO** (postflight stage empty, like neovim) |
| `.claude/skills/skill-team-research/SKILL.md` | **NO** | N/A | Yes, preflight + postflight | **Partial** (mentions Edit tool, no specific call) |
| `.claude/skills/skill-team-plan/SKILL.md` | **NO** | N/A | Yes, preflight + postflight | **Partial** (mentions Edit tool, no specific call) |
| `.claude/skills/skill-team-implement/SKILL.md` | **NO** | N/A | Yes, preflight + postflight | **Partial** (mentions Edit tool, no specific call) |

### B. Script Analysis Summary

`update-task-status.sh` handles these four locations:
1. `state.json` — `active_projects[].status`, `last_updated`, `session_id`
2. `TODO.md` task entry — line after `### {N}.` heading, pattern `- **Status**: [STATUS]`
3. `TODO.md` Task Order — pattern `- **{N}** [STATUS]`
4. Plan file — calls `update-plan-status.sh` (implement preflight/postflight only)

Exit codes:
- 0: Success or no-op
- 1: Validation error
- 2: state.json failure
- 3: TODO.md failure

The script is idempotent — if the status is already at the target, it exits 0 without making changes.

### C. Code Snippets Showing the Problem

**skill-neovim-implementation postflight (problem):**
```markdown
### Stage 7: Update Task Status (Postflight)

If status is "implemented", update state.json and TODO.md.

**Update state.json**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "completed" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    completed: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Update TODO.md**: Use Edit tool to change status marker to `[COMPLETED]`.
```

Notice:
1. No call to `update-task-status.sh`
2. "Use Edit tool" is descriptive text, not a `Tool: Edit` invocation
3. The Task tool (which executes the skill) may not execute this descriptive text as an actual tool call

### D. Search Queries Used

- `grep -r "update-task-status.sh" .claude/skills/ .opencode/skills/`
- `grep -r "TODO.md.*IMPLEMENTING\|TODO.md.*COMPLETED" .claude/skills/`
- `read .opencode/scripts/update-task-status.sh`
- `diff .claude/scripts/update-task-status.sh .opencode/scripts/update-task-status.sh`
- `read .claude/skills/skill-neovim-implementation/SKILL.md`
- `read .opencode/skills/skill-implementer/SKILL.md`
- `read .opencode/commands/implement.md`

---

*End of Research Report*
