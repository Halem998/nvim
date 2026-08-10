# Research Report: Task #578

**Task**: 578 - fix_opencode_tmp_file_usage_root_cause
**Started**: 2026-05-15T01:00:00Z
**Completed**: 2026-05-15T01:45:00Z
**Effort**: Medium (1.5 hours)
**Dependencies**: task 574 (prior fix)
**Sources/Inputs**:
- Codebase: `/home/benjamin/.dotfiles/.opencode/` (dotfiles OpenCode agent system)
- Codebase: `/home/benjamin/.config/nvim/.opencode/` (nvim OpenCode agent system)
- Codebase: `/home/benjamin/.config/nvim/.claude/` (reference Claude Code implementation)
- Task 574 artifacts: `specs/574_fix_temp_file_usage_opencode_agent_system/`
- Git history of affected skill and command files
**Artifacts**: - `specs/578_fix_opencode_tmp_file_usage_root_cause/reports/01_tmp-file-root-cause.md`
**Standards**: report-format.md, artifact-management.md

---

## Executive Summary

- The root cause of `/tmp/state.json.tmp` generation is **LLM-generated ad-hoc bash code** — not hardcoded paths in scripts. When agents compose jq commands outside the explicit SKILL.md patterns, they default to `/tmp/` because no context file prohibits it.
- Two inconsistent temp file patterns in the agent system create ambiguity: `specs/tmp/state.json` (canonical) vs. `specs/state.json.tmp` (in-place, used in review.md, todo.md, skill-todo, skill-project-overview). This inconsistency likely confuses the LLM.
- A third wrong pattern exists in `docs/examples/research-flow-example.md`: bare `state.json > state.json.tmp` with no `specs/` prefix at all — the worst example.
- Task 574 fixed `mktemp` calls in shell scripts (correct) but missed the documentation/skill inconsistencies that continue to teach LLMs incorrect patterns.
- The fix requires: (1) fixing all `specs/state.json.tmp` in-place patterns to use `specs/tmp/state.json`, (2) fixing bare `state.json.tmp` in examples to use `specs/tmp/state.json`, and (3) adding explicit prohibition text to AGENTS.md in both repos.
- **17 files total** need changes across two repositories (`~/.config/nvim/.opencode/` and `~/.dotfiles/.opencode/`).

---

## Context & Scope

**Task background**: After task 574 fixed `mktemp` calls in shell scripts, the `/tmp/` permission prompt continued to appear when running `/research 575` in OpenCode. The screenshot shows the pattern `jq ... > /tmp/state.json.tmp && mv /tmp/state.json.tmp specs/state.json`.

**Why task 574 did not fully fix the issue**: Task 574 correctly identified and fixed bare `mktemp` calls (no template) in `update-recommended-order.sh` and `setup-lean-mcp.sh`. These were shell script bugs. The current issue is different: it is the LLM *agent* generating jq commands with `/tmp/` paths. No shell script hardcodes `/tmp/state.json.tmp` — this path is generated dynamically by the LLM.

**Two separate OpenCode directories**: There are two `.opencode/` directories:
- `/home/benjamin/.config/nvim/.opencode/` — the nvim project's OpenCode agent system (where `/research 575` runs)
- `/home/benjamin/.dotfiles/.opencode/` — the dotfiles OpenCode agent system

Both have the same inconsistency patterns and both need to be fixed.

**What OpenCode's permission model does**: `external_directory: "ask"` in `opencode.json` causes OpenCode to prompt the user whenever an agent tries to access a path outside the project workspace. The system `/tmp/` is outside the workspace, so any write to `/tmp/` triggers the prompt. The project convention is `specs/tmp/` (inside workspace) to avoid these prompts.

---

## Findings

### 1. Task 574 Status — Partially Fixed

Task 574 fixed all bare `mktemp` calls in shell scripts. Current state of scripts:

- `update-recommended-order.sh` (both repos): All 8 calls are `mktemp -p specs/tmp tmp.XXXXXXXXXX` ✓
- `setup-lean-mcp.sh` (both repos): All 3 calls are `mktemp -p specs/tmp tmp.XXXXXXXXXX` ✓
- `update-task-status.sh` (both repos): Uses `TMP_DIR="$PROJECT_ROOT/specs/tmp"` and writes to `"$TMP_DIR/state.json.tmp"` ✓ (correct)
- All postflight scripts (`postflight-research.sh`, `postflight-plan.sh`, `postflight-implement.sh`): Use `specs/tmp/state.json` ✓

The shell script layer is now clean. The problem is in the agent instruction documents.

### 2. Root Cause: LLM-Generated Ad-Hoc Bash Commands

When `skill-researcher` or other skills run, they pass SKILL.md content as LLM context. The LLM reads these instructions and *generates* bash commands. The commands in SKILL.md serve as examples, but the LLM may deviate when:

- The SKILL.md examples show one pattern (`specs/tmp/state.json`) but other loaded context files show different patterns (`specs/state.json.tmp`, `state.json.tmp`)
- The LLM has no explicit prohibition: "NEVER use /tmp/ for temporary files"
- LLM training data strongly associates temp files with `/tmp/`

The specific command `> /tmp/state.json.tmp && mv /tmp/state.json.tmp` appears to be the LLM combining:
- The `.tmp` suffix naming convention (from `state.json.tmp` usage in review.md, todo.md, etc.)
- The `/tmp/` location (from LLM training data about temp file conventions)
- The `state.json` base name (from the atomic write pattern it needs to implement)

### 3. Pattern 1 (Critical): Bare `state.json.tmp` in Examples — 3 files

The file `docs/examples/research-flow-example.md` shows:

```bash
jq '.active_projects |= map(...)' state.json > state.json.tmp && mv state.json.tmp state.json
```

This uses `state.json > state.json.tmp` with **no `specs/` prefix at all**. The LLM reading this example might:
- Decide the `.tmp` naming convention is canonical
- Add an absolute path prefix, resulting in `/tmp/state.json.tmp`

**Files affected** (3 total):
1. `/home/benjamin/.config/nvim/.opencode/docs/examples/research-flow-example.md` (line 237)
2. `/home/benjamin/.config/nvim/.opencode/extensions/core/docs/examples/research-flow-example.md` (line 237)
3. `/home/benjamin/.dotfiles/.opencode/docs/examples/research-flow-example.md` (line 237)

### 4. Pattern 2 (Significant): In-Place `specs/state.json.tmp` — 13 files

The following files use `specs/state.json > specs/state.json.tmp && mv specs/state.json.tmp specs/state.json`. This creates a temp file ADJACENT to `state.json` rather than in `specs/tmp/`. While technically safe (stays in workspace), it is inconsistent with the canonical `specs/tmp/state.json` pattern used everywhere else, and creates confusion.

**Files affected** (13 total):

*nvim `.opencode/` (6 files):*
- `/home/benjamin/.config/nvim/.opencode/commands/review.md` (lines 801, 812, 818)
- `/home/benjamin/.config/nvim/.opencode/commands/todo.md` (lines 400, 487, 638, 781-782)
- `/home/benjamin/.config/nvim/.opencode/skills/skill-project-overview/SKILL.md` (line 373)
- `/home/benjamin/.config/nvim/.opencode/skills/skill-todo/SKILL.md` (lines 500, 519, 582, 585, 591, 612)

*nvim extensions/core (4 files):*
- `/home/benjamin/.config/nvim/.opencode/extensions/core/commands/review.md` (same pattern)
- `/home/benjamin/.config/nvim/.opencode/extensions/core/commands/todo.md` (same pattern)
- `/home/benjamin/.config/nvim/.opencode/extensions/core/skills/skill-project-overview/SKILL.md` (same pattern)
- `/home/benjamin/.config/nvim/.opencode/extensions/core/skills/skill-todo/SKILL.md` (same pattern)

*dotfiles `.opencode/` (4 files):*
- `/home/benjamin/.dotfiles/.opencode/commands/review.md` (same pattern)
- `/home/benjamin/.dotfiles/.opencode/commands/todo.md` (same pattern)
- `/home/benjamin/.dotfiles/.opencode/skills/skill-project-overview/SKILL.md` (same pattern)
- `/home/benjamin/.dotfiles/.opencode/skills/skill-todo/SKILL.md` (same pattern)

Note: `skill-tag/SKILL.md` uses `${state_file}.tmp` (variable expansion). When `state_file="specs/state.json"`, this resolves to `specs/state.json.tmp` — the same in-place pattern. There are two copies (nvim, dotfiles).

### 5. Pattern 3 (Gap): No `/tmp/` Prohibition in AGENTS.md or SKILL Files

The AGENTS.md files (the primary context loaded by OpenCode at session start) contain **no mention** of `specs/tmp/` or any prohibition against using `/tmp/`. The general-research-agent.md and other subagent files also have no such guidance.

The only places where `specs/tmp/` is explained are:
- `context/patterns/computed-artifacts.md` (inside a JSON template `"prompt"` field — not prominent)
- `docs/guides/opencode-permission-configuration.md` (in troubleshooting section)
- SKILL.md files (in code block examples, but not as explicit prohibitions)

**AGENTS.md files that need the prohibition added** (2):
- `/home/benjamin/.config/nvim/.opencode/AGENTS.md`
- `/home/benjamin/.dotfiles/.opencode/AGENTS.md`

### 6. Relationship Between the Two Repos

The nvim `.opencode/` system is more advanced (has Stage 4c in skill-researcher, more files) but both systems share the same inconsistent patterns. The nvim repo is the source of truth that gets backported to the dotfiles.

### 7. Claude Code System Has the Same Pattern Issues

For reference, the `.claude/` system also has the in-place `specs/state.json.tmp` pattern in `todo.md`, `review.md`, `skill-todo`, and `skill-project-overview`. However, Claude Code does not have the `external_directory: "ask"` permission model so these do not trigger user-visible prompts. The `.claude/` system does not need to be fixed for the stated problem, but could be standardized for consistency.

---

## Decisions

- **Fix approach**: Change all `specs/state.json.tmp` in-place patterns to `specs/tmp/state.json`. Add `mkdir -p specs/tmp` guards where needed.
- **Also fix research-flow-example.md**: Change bare `state.json > state.json.tmp` to use `specs/tmp/state.json`.
- **Add prohibition to AGENTS.md**: Add a brief note in both AGENTS.md files: "When creating temporary files, ALWAYS use `specs/tmp/` instead of system `/tmp/`. Run `mkdir -p specs/tmp` before writing."
- **Scope**: Fix nvim `.opencode/`, nvim `.opencode/extensions/core/` (duplicates), and dotfiles `.opencode/`. Do NOT fix `.claude/` system (out of scope; different permission model).
- **skill-tag**: Fix the `${state_file}.tmp` variable expansion pattern to use a proper `specs/tmp/` path.

---

## Recommendations

### Priority 1: Fix research-flow-example.md (3 files) — Root Cause #1

Change line 237 in each copy from:
```bash
)' state.json > state.json.tmp && mv state.json.tmp state.json
```
To:
```bash
)' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

This is the highest priority fix because it is the most misleading pattern — no `specs/` prefix at all, and it appears in an "example flow" document that agents and developers read to understand how the system works.

### Priority 2: Fix in-place `specs/state.json.tmp` pattern (13 files) — Root Cause #2

For each occurrence of:
```bash
specs/state.json > specs/state.json.tmp && mv specs/state.json.tmp specs/state.json
```
Change to:
```bash
specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

Add `mkdir -p specs/tmp` before the first jq write in each file if not already present.

Also fix `skill-tag/SKILL.md` (2 copies): change `"${state_file}.tmp"` to `"specs/tmp/state.json"` (or use a local variable `TMP_FILE="specs/tmp/state.json"`).

### Priority 3: Add Explicit Prohibition to AGENTS.md (2 files) — Root Cause #3

Add to the Quick Reference or Standards section of both AGENTS.md files:

```
**Temp File Convention**: Always use `specs/tmp/` for temporary files. NEVER use system `/tmp/`. Run `mkdir -p specs/tmp` before writing temp files.
```

This ensures the LLM receives the prohibition at session start, before any SKILL.md or command files are loaded.

### Priority 4 (Optional): Add Lint Check for `/tmp/` in Skill Files

Add to `validate-wiring.sh` or a new script:
```bash
if grep -r '> /tmp/' .opencode/skills/ .opencode/commands/ .opencode/agent/ 2>/dev/null | grep -v specs/tmp; then
  echo "WARNING: Found /tmp/ references outside specs/tmp/ in agent files"
fi
```

This would catch future regressions.

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `specs/tmp/` directory not existing at runtime | High | Add `mkdir -p specs/tmp` before each jq write in fixed files |
| Missing some duplicate files | Medium | Use grep to verify after changes: `grep -r 'specs/state.json.tmp' .opencode/ \| grep -v specs/tmp` should return nothing |
| skill-tag fix breaks tag creation flow | Low | Test with `bash -n` and dry-run after change |
| LLM still generates /tmp/ from training data | Medium | AGENTS.md prohibition is the main mitigation; cannot fully prevent LLM hallucination but reduces probability significantly |

---

## Complete File Change List

The following 17 files across both repositories need to be modified:

**Group A — Fix bare `state.json.tmp` example (3 files)**:
1. `/home/benjamin/.config/nvim/.opencode/docs/examples/research-flow-example.md`
2. `/home/benjamin/.config/nvim/.opencode/extensions/core/docs/examples/research-flow-example.md`
3. `/home/benjamin/.dotfiles/.opencode/docs/examples/research-flow-example.md`

**Group B — Fix in-place `specs/state.json.tmp` pattern (13 files)**:
4. `/home/benjamin/.config/nvim/.opencode/commands/review.md`
5. `/home/benjamin/.config/nvim/.opencode/commands/todo.md`
6. `/home/benjamin/.config/nvim/.opencode/extensions/core/commands/review.md`
7. `/home/benjamin/.config/nvim/.opencode/extensions/core/commands/todo.md`
8. `/home/benjamin/.config/nvim/.opencode/extensions/core/skills/skill-project-overview/SKILL.md`
9. `/home/benjamin/.config/nvim/.opencode/extensions/core/skills/skill-todo/SKILL.md`
10. `/home/benjamin/.config/nvim/.opencode/skills/skill-project-overview/SKILL.md`
11. `/home/benjamin/.config/nvim/.opencode/skills/skill-todo/SKILL.md`
12. `/home/benjamin/.config/nvim/.opencode/skills/skill-tag/SKILL.md`
13. `/home/benjamin/.dotfiles/.opencode/commands/review.md`
14. `/home/benjamin/.dotfiles/.opencode/commands/todo.md`
15. `/home/benjamin/.dotfiles/.opencode/skills/skill-project-overview/SKILL.md`
16. `/home/benjamin/.dotfiles/.opencode/skills/skill-todo/SKILL.md`
17. `/home/benjamin/.dotfiles/.opencode/skills/skill-tag/SKILL.md`

**Group C — Add explicit prohibition to AGENTS.md (2 files)**:
18. `/home/benjamin/.config/nvim/.opencode/AGENTS.md`
19. `/home/benjamin/.dotfiles/.opencode/AGENTS.md`

**Total: 19 files** (re-counted from initial estimate of 17 after including both skill-tag files separately).

---

## Context Extension Recommendations

- **Topic**: Temp file convention enforcement in OpenCode agent system
- **Gap**: No automated check in `validate-wiring.sh` to detect `/tmp/` usage in skill or command files
- **Recommendation**: Add a lint rule that greps for `> /tmp/` in `.opencode/skills/`, `.opencode/commands/`, and `.opencode/agent/` directories (excluding `specs/tmp/` matches), emitting an error on non-zero matches. This would catch regressions automatically.

---

## Appendix

### Prior Task 574 Context

Task 574 fixed the `mktemp` calls in shell scripts. Summary of what was fixed:
- `update-recommended-order.sh` (4 copies): 8 bare `mktemp` → `mktemp -p specs/tmp tmp.XXXXXXXXXX`
- `setup-lean-mcp.sh` (4 copies): 3 bare `mktemp` → `mktemp -p specs/tmp tmp.XXXXXXXXXX`

Those fixes remain in place and should not be reverted.

### Why the Issue Persists After Task 574

Task 574's research report (line 19) stated: "99% of the scripts/skills/hooks follow this convention correctly." This was accurate for shell scripts. However, the documentation/example files (`research-flow-example.md`) and skill instruction files (`skill-todo`, `skill-project-overview`) were not audited because they were seen as "documentation" rather than code. In OpenCode's LLM-driven system, documentation IS effectively code — the LLM reads these files and generates executable bash commands based on the patterns it sees.

### Verification Commands (Post-Fix)

```bash
# Verify no bare state.json.tmp patterns remain
grep -r 'state\.json\.tmp\b' .opencode/ --include="*.md" --include="*.sh" | grep -v "specs/tmp"
# Should return: ZERO results

# Verify no system /tmp/ writes remain
grep -r '> /tmp/' .opencode/ --include="*.md" --include="*.sh" | grep -v "specs/tmp"
# Should return: ZERO results

# Verify prohibition exists in AGENTS.md
grep -n "specs/tmp\|/tmp/" .opencode/AGENTS.md
# Should return: lines with the prohibition text
```
