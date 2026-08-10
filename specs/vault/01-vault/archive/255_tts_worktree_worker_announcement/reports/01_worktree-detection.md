# Research Report: Task #255

**Task**: 255 - tts_worktree_worker_announcement
**Started**: 2026-03-21T00:00:00Z
**Completed**: 2026-03-21T00:15:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase analysis, git documentation
**Artifacts**: specs/255_tts_worktree_worker_announcement/reports/01_worktree-detection.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Git worktree detection is reliable using `git rev-parse --git-dir` comparison
- In linked worktrees, `--git-dir` returns a path containing `/worktrees/` or differs from `--git-common-dir`
- Implementation requires adding 5-10 lines to tts-notify.sh to detect worktree context
- No external dependencies needed - uses built-in git commands

## Context and Scope

The task requires modifying `.claude/hooks/tts-notify.sh` to announce "Tab N worker" when the Stop hook fires inside a git worktree (sub-agent session), while maintaining "Tab N" for the main session. This auditory distinction helps users identify sub-agent completions vs final parent completions.

### Current Implementation

The current `tts-notify.sh` implementation (145 lines):
- Gets WezTerm tab number via `wezterm cli list --format=json`
- Constructs message as `TAB_PREFIX="Tab $TAB_NUM"`
- Speaks using piper TTS with paplay/aplay
- Has cooldown mechanism and extensive logging

The message construction is at lines 118-124:
```bash
TAB_PREFIX="${TAB_LABEL%: }"  # Strip ": " suffix if present
if [[ -z "$TAB_PREFIX" ]]; then
    TAB_PREFIX="Tab"  # Fallback if tab detection failed
fi

MESSAGE="$TAB_PREFIX"
```

## Findings

### Git Worktree Detection Methods

#### Method 1: Compare git-dir with git-common-dir (Recommended)

```bash
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
GIT_COMMON=$(git rev-parse --git-common-dir 2>/dev/null)

if [[ "$GIT_DIR" != "$GIT_COMMON" ]]; then
    # This is a linked worktree
    IS_WORKTREE=true
fi
```

**Rationale**:
- In main worktree: both return `.git`
- In linked worktree: `--git-dir` returns `.git/worktrees/<name>`, `--git-common-dir` returns path to main `.git`
- Most reliable method, handles edge cases

#### Method 2: Check for /worktrees/ in path

```bash
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
if [[ "$GIT_DIR" == *"/worktrees/"* ]]; then
    IS_WORKTREE=true
fi
```

**Rationale**:
- Simple string match
- Works for Claude Code worktrees created in `.claude/worktrees/`
- May not handle all edge cases (e.g., repo named "worktrees")

#### Method 3: Check if .git is a file (not directory)

```bash
if [[ -f ".git" ]]; then
    IS_WORKTREE=true
fi
```

**Rationale**:
- In main worktree: `.git` is a directory
- In linked worktree: `.git` is a file containing `gitdir: /path/to/.git/worktrees/<name>`
- Simple check but requires being at worktree root

### Claude Code Worktree Integration

Based on the EnterWorktree tool documentation:
- Claude Code creates worktrees inside `.claude/worktrees/` directory
- Each worktree gets a unique name (user-specified or random)
- Sub-agents running in worktrees have different `pwd` than main session

### Environment Variables Available

From hook context analysis:
- `WEZTERM_PANE` - WezTerm pane ID (available in both main and worktree)
- `CLAUDECODE=1` - Indicates running in Claude Code environment
- No specific `CLAUDE_WORKTREE` variable currently set

### Existing Hook Patterns

The codebase shows related patterns:
- `subagent-postflight.sh` - Uses marker files in `specs/` for state
- `wezterm-notify.sh` - Sets user variables via OSC 1337 for tab highlighting
- Both hooks handle the sub-agent context gracefully

## Recommendations

### Implementation Approach

Add worktree detection after line 116 (after TAB_NUM calculation), before message construction:

```bash
# Detect if running in a git worktree (sub-agent session)
IS_WORKTREE=false
if command -v git &>/dev/null; then
    GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo "")
    GIT_COMMON=$(git rev-parse --git-common-dir 2>/dev/null || echo "")
    if [[ -n "$GIT_DIR" ]] && [[ -n "$GIT_COMMON" ]] && [[ "$GIT_DIR" != "$GIT_COMMON" ]]; then
        IS_WORKTREE=true
    fi
fi

# Build message based on event type and worktree status
TAB_PREFIX="${TAB_LABEL%: }"
if [[ -z "$TAB_PREFIX" ]]; then
    TAB_PREFIX="Tab"
fi

if [[ "$IS_WORKTREE" == "true" ]]; then
    MESSAGE="$TAB_PREFIX worker"
else
    MESSAGE="$TAB_PREFIX"
fi
```

### Alternative: Environment Variable Approach

If future Claude Code versions provide a `CLAUDE_IN_WORKTREE` variable, the detection could be simplified:

```bash
if [[ "${CLAUDE_IN_WORKTREE:-0}" == "1" ]]; then
    MESSAGE="$TAB_PREFIX worker"
else
    MESSAGE="$TAB_PREFIX"
fi
```

### Testing Strategy

1. **Main session test**: Run hook in main nvim directory, expect "Tab N"
2. **Worktree test**: Create worktree with `git worktree add`, run hook, expect "Tab N worker"
3. **Edge case**: Run outside git repo, expect "Tab" fallback

## Decisions

- Use Method 1 (compare git-dir with git-common-dir) for maximum reliability
- Add detection code before message construction (minimal change footprint)
- Maintain existing fallback behavior when git is unavailable
- Use "worker" suffix (single word, clear pronunciation by TTS)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| git command not available | Low - most systems have git | Graceful fallback to non-worktree message |
| git rev-parse fails in non-repo | Low | Wrapped in conditional with error suppression |
| TTS pronunciation of "worker" | Low | Simple word, tested with piper TTS |
| Performance impact | Very Low | Two fast git commands, <10ms |

## Appendix

### Search Queries Used

- Codebase: `grep "worktree"` in .claude directory
- Codebase: `grep "git rev-parse"` for existing patterns
- Git documentation: `man git-worktree`

### Git Worktree Commands Reference

```bash
# List worktrees
git worktree list

# Create linked worktree
git worktree add <path> [<branch>]

# Check if in worktree (returns path to main .git)
git rev-parse --git-common-dir

# Get current .git path (different in worktree)
git rev-parse --git-dir
```

### Files to Modify

- `.claude/hooks/tts-notify.sh` (primary change)

### Related Files (no changes needed)

- `.claude/settings.json` - Hook configuration (unchanged)
- `.claude/hooks/wezterm-notify.sh` - Similar pattern but no audio
- `.claude/hooks/subagent-postflight.sh` - Sub-agent state handling
