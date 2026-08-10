# Research Report: CLAUDE.md Documentation Updates for Multi-Task Support

**Task**: 354 - Update CLAUDE.md argument-hints and documentation
**Date**: 2026-04-02
**Session**: sess_1743552000_r354mt

## Summary

The command frontmatter `argument-hint` fields have already been updated to `TASK_NUMBERS` by tasks 351-353. The remaining work is updating the `.claude/CLAUDE.md` command reference table and adding a brief note about multi-task dispatch.

## Findings

### 1. Primary Update Target: `.claude/CLAUDE.md` Command Reference Table (lines 87-89)

Current (outdated):
```
| `/research` | `/research N [focus] [--team]` | Research task, route by language |
| `/plan` | `/plan N [--team]` | Create implementation plan |
| `/implement` | `/implement N [--team]` | Execute plan, resume from incomplete phase |
```

Should become:
```
| `/research` | `/research N[,N-N] [focus] [--team]` | Research task(s), route by language |
| `/plan` | `/plan N[,N-N] [--team]` | Create implementation plan(s) |
| `/implement` | `/implement N[,N-N] [--team] [--force]` | Execute plan(s), resume from incomplete phase |
```

### 2. Command Frontmatter (Already Done)

All three command files already have `TASK_NUMBERS` in their `argument-hint`:
- `research.md`: `TASK_NUMBERS [FOCUS] [--team [--team-size N]]`
- `plan.md`: `TASK_NUMBERS [--team [--team-size N]]`
- `implement.md`: `TASK_NUMBERS [--team [--team-size N]] [--force]`

No changes needed here.

### 3. Other References Using `N` Syntax (No Changes Needed)

The following locations use `/research N`, `/plan N`, `/implement N` in context where `N` refers to a *specific single task* (e.g., "Run /plan 350" or "Next: /implement {N}"). These are correct as-is because they refer to the next step for a specific task, not the argument format:

- Command output sections ("Next: /plan {N}")
- Agent metadata next_steps fields
- Skill documentation referencing single-task workflows
- Hook scripts that parse task numbers from prompts (wezterm-task-number.sh)
- Meta-builder, spawn-agent, error command guidance

These do NOT need updating -- they correctly reference single-task usage.

### 4. Optional: Add Multi-Task Note to CLAUDE.md

A brief note could be added near the command reference table explaining multi-task syntax. This is lightweight -- one sentence or a small subsection.

## Recommended Changes

| File | Change | Priority |
|------|--------|----------|
| `.claude/CLAUDE.md` lines 87-89 | Update command reference table usage column | Required |
| `.claude/CLAUDE.md` near line 89 | Add brief multi-task syntax note | Optional |

## Scope Assessment

This is a minimal documentation task: 3 lines updated in the command reference table, plus an optional brief note. Estimated effort: 15 minutes.
