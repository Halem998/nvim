# Research Report: Task #171

**Task**: 171 - Re-audit agent systems after core reload and extension re-load
**Started**: 2026-03-10T00:00:00Z
**Completed**: 2026-03-10T01:00:00Z
**Effort**: 30 minutes
**Dependencies**: Task 170 (repairs)
**Sources/Inputs**: Direct filesystem analysis of 4 agent systems in /home/benjamin/Projects/Logos/Vision/
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

- **Two gaps found** after reload - the same two issues fixed in task 170 have regressed:
  1. `project-overview.md` is MISSING in both `.claude/` and `.opencode/`
  2. `OPENCODE.md` is missing core content (starts directly with extension sections)
- Core systems (`.claude_core/`, `.opencode_core/`) are **clean** with no extension contamination
- Extended systems have correct component counts (all core + extension content present)
- All 187 context index entries match files on disk (0 missing)
- Extension index entries in nvim config preserved from task 170 (32 files still indexed)
- validate-wiring.sh passes 18/18 for core checks (extension checks skipped - different project root)

## Context & Scope

Audited 4 directories in `/home/benjamin/Projects/Logos/Vision/` after user reloaded:
- `.claude_core/` - Core-only .claude system (fresh reload)
- `.opencode_core/` - Core-only .opencode system (fresh reload)
- `.claude/` - Core + all 11 extensions loaded
- `.opencode/` - Core + all 11 extensions loaded

## Findings

### Area 1: Core System Completeness

#### .claude_core (PASS - Clean)

| Component | Count | Expected | Status |
|-----------|-------|----------|--------|
| Agents | 4 | 4 | PASS |
| Skills | 10 | ~10 | PASS |
| Rules | 5 | 5 | PASS |
| Index entries | 10 | 10 | PASS |
| Extension contamination | 0 | 0 | PASS |

Agents: general-implementation-agent, general-research-agent, meta-builder-agent, planner-agent

#### .opencode_core (PASS - Clean)

| Component | Count | Expected | Status |
|-----------|-------|----------|--------|
| Agents | 6 | 5-6 | PASS |
| Skills | 13 | ~12 | PASS |
| Rules | 6 | 5-6 | PASS |
| Index entries | 10 | 10 | PASS |
| Extension contamination | 0 | 0 | PASS |

Agents: Same as claude_core + code-reviewer-agent

### Area 2: Extended System Component Counts

#### .claude extended (PASS)

| Component | Count | Expected | Status |
|-----------|-------|----------|--------|
| Agents | 31 | 31 (4 core + 27 ext) | PASS |
| Skills | 38 | ~38 | PASS |
| Commands | 18 | 18 | PASS |
| Rules | 10 | 10 (5 core + 5 ext) | PASS |
| Index entries | 187 | ~155-190 | PASS |
| Core agents present | 4/4 | 4 | PASS |

#### .opencode extended (PASS)

| Component | Count | Expected | Status |
|-----------|-------|----------|--------|
| Agents | 33 | 32+ (5 core + 27 ext) | PASS |
| Skills | 41 | ~40 | PASS |
| Commands | 20 | 20 | PASS |
| Scripts | 16 | 16 | PASS |
| Rules | 11 | 10-11 | PASS |
| Index entries | 187 | ~155-190 | PASS |
| Core agents present | 5/5 | 5 | PASS |
| Core skills present | 4/4 | 4 | PASS |

### Area 3: Configuration File Issues

#### OPENCODE.md (FAIL - Missing Core Content)

| Check | Status | Details |
|-------|--------|---------|
| Starts with core content | **FAIL** | Starts with `<!-- SECTION: extension_oc_epidemiology -->` |
| Has Quick Start section | **FAIL** | Missing |
| Has System Overview | **FAIL** | Missing |
| Has Command Reference | **FAIL** | Missing |
| Extension sections present | PASS | All 11 sections (22 markers) |

**Root cause**: Extension loader only injects extension sections - it does not preserve or merge core content from README.md.

#### CLAUDE.md (PASS)

| Check | Status | Details |
|-------|--------|---------|
| Has core content | PASS | Starts with "# Agent System" |
| Has Quick Reference | PASS | Present |
| Has Project Structure | PASS | Present |
| Extension sections | PASS | 22 markers (11 sections) |

### Area 4: Missing project-overview.md

| Location | Status | Details |
|----------|--------|---------|
| `.claude/context/project/repo/project-overview.md` | **MISSING** | Created in task 170, lost on reload |
| `.opencode/context/project/repo/project-overview.md` | **MISSING** | Created in task 170, lost on reload |

**Root cause**: Extension loader doesn't copy project-overview.md because:
1. It's not in `.claude_core/context/project/repo/` (it's project-specific)
2. It was created manually in task 170 in the target directory
3. The reload likely replaced the target directories entirely

### Area 5: Context Index Integrity

| System | Entries | Files on Disk | Missing |
|--------|---------|---------------|---------|
| .claude extended | 187 | 187 | 0 |
| .opencode extended | 187 | 187 | 0 |

All indexed files exist on disk.

### Area 6: Extension Index Preservation (nvim config)

The 32 context files added in task 170 are still in the nvim config extension indices:

| Extension | Entries | Status |
|-----------|---------|--------|
| typst | 26 | Preserved |
| formal | 45 | Preserved |
| lean | 24 | Preserved |
| web | 22 | Preserved |
| epidemiology | 4 | Preserved |
| latex | 10 | Preserved |
| python | 6 | Preserved |
| z3 | 5 | Preserved |

## Recommendations

### Priority 1: Fix OPENCODE.md (Same as Task 170)

Merge core README.md content into OPENCODE.md before extension sections:
```bash
cd /home/benjamin/Projects/Logos/Vision
cat .opencode_core/README.md > /tmp/new_opencode.md
echo "" >> /tmp/new_opencode.md
echo "## Extension Sections" >> /tmp/new_opencode.md
echo "" >> /tmp/new_opencode.md
cat .opencode/OPENCODE.md >> /tmp/new_opencode.md
mv /tmp/new_opencode.md .opencode/OPENCODE.md
```

### Priority 2: Recreate project-overview.md

Copy from nvim config or recreate the Vision project overview:
```bash
# Option A: Copy from previous location if still exists in nvim config
# Option B: Recreate manually (same content as task 170)
```

### Priority 3: Investigate Extension Loader

The extension loader should be enhanced to:
1. Preserve existing project-overview.md when reloading
2. Merge core README content into OPENCODE.md (not just inject extension sections)

This may be out of scope for immediate fix but should be noted.

## Decisions

- Classified OPENCODE.md missing core content as HIGH priority (broken documentation)
- Classified missing project-overview.md as MEDIUM priority (documented workaround exists)
- Extension loader fix deferred to separate task (architectural change)

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| OPENCODE.md unusable without core content | HIGH | Merge core README immediately |
| project-overview.md reference broken | MEDIUM | Recreate file or keep reference as documentation |
| Future reloads will regress | LOW | Document workaround, consider loader fix |

## Summary

The reload preserved most of the task 170 fixes but lost two specific changes that were made to the target directories (not source):
1. OPENCODE.md core content merge
2. project-overview.md creation

These need to be re-applied. The fix is quick (~15 minutes) and identical to the task 170 fix.

## Next Steps

Create an implementation plan to:
1. Re-merge core README.md into OPENCODE.md
2. Re-create project-overview.md in both extended systems
3. Verify all systems pass validation
