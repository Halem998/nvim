# Research Report: Task #172 (Supplemental)

**Task**: Investigate OPENCODE.md core content loss on <leader>ao reload
**Date**: 2026-03-10
**Focus**: AGENTS.md vs OPENCODE.md - OpenCode best practices for project instructions

## Summary

Research confirms that **AGENTS.md** (not OPENCODE.md) is the standard, preferred file name for OpenCode project instructions. This aligns with the user's intuition and requires updating the implementation plan.

## Key Findings

### Finding 1: AGENTS.md is the Standard

OpenCode uses `AGENTS.md` as its primary project-level instruction file, mirroring how Claude Code uses `CLAUDE.md`. The naming follows a pattern where each AI coding tool has its own instruction file:

| Tool | Project Instructions File |
|------|--------------------------|
| Claude Code | `CLAUDE.md` |
| OpenCode | `AGENTS.md` |

### Finding 2: File Precedence

If both `AGENTS.md` and `CLAUDE.md` exist in a project, **only AGENTS.md is used**. OpenCode supports CLAUDE.md for backward compatibility with Claude Code users migrating to OpenCode.

### Finding 3: File Locations

| Location | Purpose |
|----------|---------|
| `./AGENTS.md` (project root) | Project-specific rules, committed to Git |
| `~/.config/opencode/AGENTS.md` | Global rules across all OpenCode sessions |

### Finding 4: Content Structure

AGENTS.md provides:
- Custom instructions included in the LLM's context
- Project-specific behavior customization
- Always-on guidance injected into agent context
- Concrete rules for orchestrator behavior and subagent delegation

## Implications for Task 172

### Plan Adaptation Required

**Original Plan (Phase 1)**: Create global `~/.config/nvim/.opencode/OPENCODE.md`

**Revised Approach**: Create global `~/.config/nvim/.opencode/AGENTS.md`

The fix should:
1. Create `~/.config/nvim/.opencode/AGENTS.md` containing core system documentation
2. Update extension merge logic to target `AGENTS.md` instead of `OPENCODE.md`
3. Verify the "Load Core Agent System" sync copies `AGENTS.md` correctly

### Benefits of Using AGENTS.md

1. **Standard Compliance**: Follows OpenCode's official naming conventions
2. **Future Compatibility**: Won't conflict with any official OPENCODE.md file OpenCode might introduce
3. **Consistency**: Mirrors the CLAUDE.md pattern that already works correctly in `.claude/`
4. **Precedence**: AGENTS.md takes priority over any existing CLAUDE.md fallback

## Recommendations

1. **Rename target file**: Change from `OPENCODE.md` to `AGENTS.md` throughout the plan
2. **Update extension manifests**: Ensure `section_target_file` points to `AGENTS.md`
3. **Update merge.lua**: Modify `inject_section` to work with `AGENTS.md`
4. **Mirror in both systems**:
   - `.claude/CLAUDE.md` (already exists)
   - `.opencode/AGENTS.md` (new - replaces OPENCODE.md)

## Sources

- [Rules | OpenCode](https://opencode.ai/docs/rules/)
- [Agents | OpenCode](https://opencode.ai/docs/agents/)
- [Config | OpenCode](https://opencode.ai/docs/config/)
- [AGENTS.md specification](https://agents.md/)
- [OpenCode AGENTS.md example](https://github.com/anomalyco/opencode/blob/dev/AGENTS.md)
- [oh-my-opencode AGENTS.md](https://github.com/code-yeongyu/oh-my-opencode/blob/dev/AGENTS.md)
- [AGENTS.md Global Rules | DeepWiki](https://deepwiki.com/julianromli/opencode-template/3.2-agents.md-global-rules)

## Next Steps

1. Update implementation plan Phase 1 to use `AGENTS.md`
2. Audit existing code for `OPENCODE.md` references that need updating
3. Proceed with implementation using corrected file name
