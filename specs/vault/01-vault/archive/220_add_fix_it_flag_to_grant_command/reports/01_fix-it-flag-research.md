# Research Report: Task #220

**Task**: 220 - Add --fix-it flag to /grant command
**Started**: 2026-03-16T00:00:00Z
**Completed**: 2026-03-16T00:01:00Z
**Effort**: 2-4 hours (implementation estimate)
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of /fix-it command, /grant command, skill-fix-it, skill-grant
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `/fix-it` command uses a 1006-line skill-fix-it/SKILL.md with direct execution pattern (no subagent)
- The `/grant` command is in present extension, routes to skill-grant which delegates to grant-agent
- The `--fix-it N` flag should scan grant task directories for embedded FIX:/TODO: tags in .tex, .md, .bib files
- Recommended approach: Add new workflow_type "fix_it_scan" to skill-grant, reusing tag scanning logic
- The interactive AskUserQuestion flow is available in skill-fix-it and can be adapted

## Context and Scope

This research investigates adding a `--fix-it N` flag to the `/grant` command that:
1. Scans grant project directory (`specs/{NNN}_{SLUG}/` or `grants/{N}_{slug}/`) for embedded tags
2. Presents findings interactively to the user
3. Creates structured tasks for selected items
4. Follows the same pattern as the `/fix-it` command

### Research Questions Addressed

1. How does `/fix-it` implement tag scanning and interactive selection?
2. How does `/grant` currently handle modes/flags (--draft, --budget, --revise)?
3. What is the present extension skill structure?
4. How can fix-it scanning logic be reused or adapted?

## Findings

### 1. /fix-it Command Implementation

**Location**: `.claude/commands/fix-it.md` (305 lines) + `.claude/skills/skill-fix-it/SKILL.md` (1006 lines)

**Execution Pattern**: Direct execution skill (no subagent delegation)
- Allowed tools: `Bash, Grep, Read, Write, Edit, AskUserQuestion`
- Synchronous execution with interactive prompts

**Tag Types Supported**:
| Tag | Task Type | Description |
|-----|-----------|-------------|
| `FIX:` | fix-it-task | Combined into single task |
| `NOTE:` | fix-it-task + learn-it-task | Creates both with dependency |
| `TODO:` | todo-task | Individual tasks per item |
| `QUESTION:` | research-task | Research tasks |

**Interactive Flow** (11 steps):
1. Parse arguments (paths)
2. Generate session ID
3. Execute tag extraction (grep for FIX:, NOTE:, TODO:, QUESTION:)
4. Display tag summary
5. Handle edge cases (no tags)
6. Task type selection (AskUserQuestion multiSelect)
7. Individual TODO selection (if selected)
7.5. Topic grouping for TODOs (if 2+ selected)
7.6. Individual QUESTION selection (if selected)
7.7. Topic grouping for QUESTIONs (if 2+ selected)
8. Create selected tasks (with dependency awareness)
9. Update state files (state.json + TODO.md)
10. Display results
11. Git commit

**File Type Support**:
| File Type | Comment Prefix | grep Pattern |
|-----------|----------------|--------------|
| `.lua` | `--` | `-- FIX:` |
| `.tex` | `%` | `% FIX:` |
| `.md` | `<!--` | `<!-- FIX:` |
| `.py/.sh/.yaml` | `#` | `# FIX:` |

**Language Detection for Tasks**:
- `.lua` in nvim/ -> "neovim"
- `.tex` -> "latex"
- `.md` -> "markdown"
- `.py/.sh` -> "general"
- `.claude/*` -> "meta"

**Topic Grouping Algorithm**:
1. Extract key terms, file section, action type
2. Cluster items sharing 2+ terms OR (file_section AND action_type)
3. Generate labels from shared terms
4. Offer three options: Accept groups, Keep separate, Combine all

### 2. /grant Command Structure

**Location**: `.claude/extensions/present/commands/grant.md` (476 lines)

**Current Modes**:
| Mode | Syntax | Description |
|------|--------|-------------|
| Task Creation | `/grant "Description"` | Create task with language="grant" |
| Draft | `/grant N --draft ["prompt"]` | Draft narrative sections |
| Budget | `/grant N --budget ["prompt"]` | Develop budget |
| Revise | `/grant --revise N "description"` | Create revision task |
| Legacy | `/grant N workflow_type [focus]` | Deprecated |

**Flag Parsing Pattern**:
```
1. Check for description (no leading number) -> Task Creation
2. Check for flags (N --draft, N --budget, --revise N) -> Mode dispatch
3. Check for legacy workflow_type -> Legacy Mode (deprecated)
```

**Mode Detection Location**: Command file handles mode detection, delegates to skill-grant

**GATE IN/GATE OUT Pattern**:
- CHECKPOINT 1: GATE IN (validate task, generate session, update status)
- STAGE 2: DELEGATE (invoke Skill tool with workflow_type)
- CHECKPOINT 2: GATE OUT (verify artifacts, verify status, output results)

### 3. Present Extension Skill Structure

**Manifest** (`.claude/extensions/present/manifest.json`):
```json
{
  "name": "present",
  "provides": {
    "skills": ["skill-grant", "skill-deck"],
    "commands": ["grant.md", "deck.md"],
    "agents": ["grant-agent.md", "deck-agent.md"]
  },
  "routing": {
    "implement": {
      "grant": "skill-grant:assemble"
    }
  }
}
```

**skill-grant Structure** (`.claude/extensions/present/skills/skill-grant/SKILL.md`, 649 lines):
- Thin wrapper pattern: validates input, delegates to grant-agent via Task tool
- Handles postflight internally (status update, artifact linking, git commit)
- Workflow types: funder_research, proposal_draft, budget_develop, progress_track, assemble

**Skill-Internal Postflight Pattern**:
1. Stage 1: Input Validation
2. Stage 2: Preflight Status Update
3. Stage 3: Create Postflight Marker
4. Stage 4: Prepare Delegation Context
5. Stage 5: Invoke Subagent (Task tool)
6. Stage 5a: Validate Return Format
7. Stage 6: Parse Subagent Return (read metadata file)
8. Stage 7: Update Task Status (postflight)
9. Stage 8: Link Artifacts
10. Stage 9: Git Commit
11. Stage 10: Cleanup
12. Stage 11: Return Brief Summary

### 4. Implementation Patterns Comparison

| Aspect | /fix-it (skill-fix-it) | /grant (skill-grant) |
|--------|------------------------|----------------------|
| Execution | Direct (no subagent) | Delegates to grant-agent |
| AskUserQuestion | Yes, used directly | Not currently used |
| Postflight | Handled in skill | Internal to skill |
| Tools | Bash, Grep, Read, Write, Edit, AskUserQuestion | Task, Bash, Edit, Read, Write |
| Workflow Types | N/A (single purpose) | 5 types (funder_research, etc.) |

## Recommendations

### Approach 1: Add fix_it_scan Workflow to skill-grant (RECOMMENDED)

**Rationale**: Keeps grant-related functionality together, leverages existing skill structure.

**Implementation Steps**:

1. **Update /grant command** (`grant.md`):
   - Add `--fix-it N` mode detection
   - Pass `workflow_type=fix_it_scan` to skill-grant
   - Display scan results and task creation summary

2. **Update skill-grant** (`SKILL.md`):
   - Add `fix_it_scan` to workflow_type validation
   - Add new execution path that:
     - Locates grant directory (specs/{NNN}_{SLUG}/ or grants/{N}_{slug}/)
     - Scans for tags in .tex, .md, .bib files
     - Uses AskUserQuestion for interactive selection (add to allowed-tools)
     - Creates tasks with language="grant"
     - No subagent delegation needed (direct execution like skill-fix-it)

3. **File Types for Grant Scanning**:
   | File Type | Comment Prefix | Purpose |
   |-----------|----------------|---------|
   | `.tex` | `%` | LaTeX proposal content |
   | `.md` | `<!--` | Markdown drafts/notes |
   | `.bib` | `%` | Bibliography entries |

4. **Grant-Specific Language Detection**:
   - All tasks created from grant scan get `language="grant"`
   - Keeps tasks within grant workflow context

**Advantages**:
- Minimal code duplication
- Extension-contained changes
- Consistent grant workflow experience
- Reuses existing postflight pattern

### Approach 2: Create New skill-grant-fix-it Skill

**Rationale**: Complete isolation of fix-it functionality.

**Implementation**: Copy skill-fix-it pattern into new skill in present extension.

**Disadvantages**:
- Code duplication (~1000 lines)
- Separate maintenance burden
- May diverge from core skill-fix-it over time

**Not recommended** unless skill-grant complexity becomes prohibitive.

### Approach 3: Share skill-fix-it via Extension Import

**Rationale**: Direct code reuse.

**Challenge**: skill-fix-it is not designed for extension reuse; would require:
- Parameterizing search paths
- Parameterizing file types
- Parameterizing language detection
- Adding extension hook points

**Not recommended** due to complexity of modifying core skill.

## Implementation Details for Recommended Approach

### Command Changes (grant.md)

Add mode detection for `--fix-it`:
```
3. Check for `N --fix-it` or `--fix-it N`:
   - Extract task_number
   - Mode: Fix-It Scan
```

Add GATE IN logic:
```markdown
## Fix-It Scan Mode (--fix-it)

Scan grant directory for embedded tags and create tasks.

### CHECKPOINT 1: GATE IN

1. Generate Session ID
2. Lookup Task (must exist, language must be "grant")
3. Find grant directory:
   - Primary: specs/{NNN}_{SLUG}/
   - Secondary: grants/{N}_{slug}/

### STAGE 2: DELEGATE

Invoke Skill tool:
skill: "skill-grant"
args: "task_number={N} workflow_type=fix_it_scan session_id={session_id}"

### CHECKPOINT 2: GATE OUT

1. Parse skill return for task creation summary
2. Display results to user
```

### Skill Changes (skill-grant/SKILL.md)

1. **Add AskUserQuestion to allowed-tools**:
   ```yaml
   allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
   ```

2. **Add workflow_type validation**:
   ```bash
   case "$workflow_type" in
     funder_research|proposal_draft|budget_develop|progress_track|assemble|fix_it_scan)
       ;;
   ```

3. **Add fix_it_scan execution path** (new section):
   - Locate grant directory
   - Scan for tags (grep patterns for .tex, .md, .bib)
   - Display findings
   - Interactive selection (AskUserQuestion)
   - Create tasks with language="grant"
   - Update state files
   - Commit changes
   - Return summary

4. **Status transitions for fix_it_scan**:
   - No preflight status change (non-destructive scan)
   - No postflight status change (tasks created are separate)

### Tag Extraction Patterns for Grants

```bash
# LaTeX files
grep -rn --include="*.tex" "% FIX:" "$grant_dir" 2>/dev/null || true
grep -rn --include="*.tex" "% TODO:" "$grant_dir" 2>/dev/null || true
grep -rn --include="*.tex" "% NOTE:" "$grant_dir" 2>/dev/null || true
grep -rn --include="*.tex" "% QUESTION:" "$grant_dir" 2>/dev/null || true

# Markdown files (drafts, notes)
grep -rn --include="*.md" "<!-- FIX:" "$grant_dir" 2>/dev/null || true
grep -rn --include="*.md" "<!-- TODO:" "$grant_dir" 2>/dev/null || true
grep -rn --include="*.md" "<!-- NOTE:" "$grant_dir" 2>/dev/null || true
grep -rn --include="*.md" "<!-- QUESTION:" "$grant_dir" 2>/dev/null || true

# BibTeX files
grep -rn --include="*.bib" "% FIX:" "$grant_dir" 2>/dev/null || true
grep -rn --include="*.bib" "% TODO:" "$grant_dir" 2>/dev/null || true
```

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Skill-grant becomes too complex | Keep fix_it_scan as isolated section, consider extraction later |
| AskUserQuestion compatibility | Test interactive flow in skill context |
| Grant directory location | Check both specs/{NNN}_{SLUG}/ and grants/{N}_{slug}/, fail clearly if neither exists |
| Language override confusion | Document that --fix-it creates grant-language tasks, not source-file-language |

## Decisions Made

1. **Recommended Approach 1**: Add fix_it_scan workflow to existing skill-grant
2. **File types**: .tex, .md, .bib (grant-relevant formats)
3. **Tag types**: Same as /fix-it (FIX:, NOTE:, TODO:, QUESTION:)
4. **Language for created tasks**: Always "grant" (not detected from file type)
5. **No status change**: fix_it_scan does not modify parent task status

## Appendix

### Search Queries Used

- Glob patterns: `.claude/skills/skill-fix-it*`, `.claude/skills/*/SKILL.md`, `.claude/extensions/present/skills/**/*`
- File reads: fix-it.md, grant.md, manifest.json, skill-fix-it/SKILL.md, skill-grant/SKILL.md

### References

- `/fix-it` command: `.claude/commands/fix-it.md`
- skill-fix-it: `.claude/skills/skill-fix-it/SKILL.md`
- `/grant` command: `.claude/extensions/present/commands/grant.md`
- skill-grant: `.claude/extensions/present/skills/skill-grant/SKILL.md`
- Multi-task creation standard: `.claude/docs/reference/standards/multi-task-creation-standard.md`
- Present extension manifest: `.claude/extensions/present/manifest.json`

### Key Code Locations for Implementation

| File | Lines | Change Type |
|------|-------|-------------|
| `.claude/extensions/present/commands/grant.md` | 1-20 | Add --fix-it to argument-hint |
| `.claude/extensions/present/commands/grant.md` | 50-60 | Add mode detection |
| `.claude/extensions/present/commands/grant.md` | 410-476 | Add Fix-It Scan Mode section |
| `.claude/extensions/present/skills/skill-grant/SKILL.md` | 1-10 | Add AskUserQuestion to tools |
| `.claude/extensions/present/skills/skill-grant/SKILL.md` | 107-114 | Add fix_it_scan to validation |
| `.claude/extensions/present/skills/skill-grant/SKILL.md` | 649+ | Add fix_it_scan execution section |
