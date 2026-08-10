# Research Report: Task #407

**Task**: 407 - update_present_manifest_and_metadata
**Started**: 2026-04-13T07:02:30Z
**Completed**: 2026-04-13T07:03:45Z
**Effort**: 0.5 hours
**Dependencies**: 403 (completed), 405 (completed)
**Sources/Inputs**:
- Codebase: `.claude/extensions/present/manifest.json`
- Codebase: `.claude/extensions/present/EXTENSION.md`
- Codebase: `.claude/extensions/present/index-entries.json`
- Codebase: `.claude/extensions/present/agents/` directory listing
- Codebase: `.claude/extensions/present/context/` directory tree
- Codebase: `specs/state.json` (tasks 403, 405 completion state)
**Artifacts**:
- `specs/407_update_present_manifest_and_metadata/reports/01_present-manifest-metadata.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- Tasks 403 and 405 are both completed. Task 403 replaced `slides-agent.md` with 3 new agents (`slides-research-agent.md`, `pptx-assembly-agent.md`, `slidev-assembly-agent.md`). Task 405 rewrote `skill-slides/SKILL.md` with multi-agent dispatch routing.
- The manifest.json still lists `slides-agent.md` in `provides.agents` and lacks the 3 new agents. The `routing.plan` section already has `present:slides` entries but routes to `skill-slides`/`skill-planner`, which is correct for the skill layer.
- EXTENSION.md skill-agent table still shows a single `slides-agent` row instead of the 3-agent dispatch.
- `index-entries.json` already contains entries for `pptx-generation.md`, `slidev-pitfalls.md`, `talk/index.json`, and template files, but two older entries still reference `slides-agent` in their `load_when.agents` arrays. The `ucsf-institutional.json` theme file exists on disk but has no index entry.

## Context & Scope

This task updates the present extension's metadata files to reflect the agent split performed in task 403 and the skill rewrite in task 405. Four files need changes:

1. **manifest.json** - Agent declarations in `provides.agents`
2. **EXTENSION.md** - Skill-agent mapping table
3. **index-entries.json** - Context index entries for new/updated files
4. No new context files need to be created (they already exist from tasks 403/405)

## Findings

### 1. manifest.json - Agent Declarations

**Current state** (line 8):
```json
"agents": ["grant-agent.md", "budget-agent.md", "timeline-agent.md", "funds-agent.md", "slides-agent.md"]
```

**Required change**: Remove `slides-agent.md`, add `slides-research-agent.md`, `pptx-assembly-agent.md`, `slidev-assembly-agent.md`.

**Target**:
```json
"agents": ["grant-agent.md", "budget-agent.md", "timeline-agent.md", "funds-agent.md", "slides-research-agent.md", "pptx-assembly-agent.md", "slidev-assembly-agent.md"]
```

**Verification**: The agents directory confirms all 3 new files exist and `slides-agent.md` is already deleted:
- `slides-research-agent.md` (9340 bytes)
- `pptx-assembly-agent.md` (16040 bytes)
- `slidev-assembly-agent.md` (15843 bytes)

### 2. manifest.json - Routing Entries

**Current routing analysis**:

| Route | Key | Current Value | Status |
|-------|-----|---------------|--------|
| research | `present:slides` | `skill-slides` | Correct (skill dispatches to agent) |
| plan | `present:slides` | `skill-slides` | Correct (skill dispatches to planner-agent) |
| plan | `slides` | `skill-slides` | Correct (shorthand alias) |
| implement | `present:slides` | `skill-slides:assemble` | Correct (skill dispatches to assembly agent) |

The routing section is already correct. The skill-slides SKILL.md (rewritten in task 405) handles the internal dispatch to the 3 agents. No routing changes are needed since routing is at the skill level, not agent level.

### 3. EXTENSION.md - Skill-Agent Table

**Current state** (line 13):
```
| skill-slides | slides-agent | opus | Research talk material synthesis and presentation assembly |
```

**Required change**: Replace single row with 3-agent dispatch showing the routing from skill-slides to the 3 specialized agents.

**Target** (replace single slides row):
```
| skill-slides | slides-research-agent | opus | Research talk material synthesis |
| skill-slides | pptx-assembly-agent | opus | PowerPoint presentation assembly |
| skill-slides | slidev-assembly-agent | opus | Slidev presentation assembly |
```

### 4. index-entries.json - Stale Agent References

Two existing entries reference `slides-agent` in their `load_when.agents` arrays:

1. **`project/present/domain/presentation-types.md`** (line 349): `"agents": ["slides-agent"]`
   - Should be: `"agents": ["slides-research-agent", "pptx-assembly-agent", "slidev-assembly-agent"]`

2. **`project/present/patterns/talk-structure.md`** (line 363): `"agents": ["slides-agent"]`
   - Should be: `"agents": ["slides-research-agent", "pptx-assembly-agent", "slidev-assembly-agent"]`

### 5. index-entries.json - Already-Present New Entries

These entries were already added (likely by task 403 or 405):
- `project/present/talk/patterns/pptx-generation.md` - routes to `pptx-assembly-agent`
- `project/present/talk/patterns/slidev-pitfalls.md` - routes to `slides-research-agent`, `slidev-assembly-agent`
- `project/present/talk/index.json` - routes to all 3 new agents
- `project/present/talk/templates/playwright-verify.mjs` - routes to `slidev-assembly-agent`
- `project/present/talk/templates/pptx-project/theme_mappings.json` - routes to `pptx-assembly-agent`
- `project/present/talk/templates/pptx-project/generate_deck.py` - routes to `pptx-assembly-agent`
- `project/present/talk/templates/pptx-project/README.md` - routes to `pptx-assembly-agent`
- `project/present/talk/templates/slidev-project/README.md` - routes to `slidev-assembly-agent`

### 6. index-entries.json - Missing Entry: ucsf-institutional.json

The file `project/present/talk/themes/ucsf-institutional.json` (50 lines) exists on disk but has no index entry. The other two theme files (`academic-clean.json`, `clinical-teal.json`) also lack index entries, but they pre-date this task. Since the task description specifically calls out `ucsf-institutional.json`, an entry should be added.

**Proposed entry**:
```json
{
  "path": "project/present/talk/themes/ucsf-institutional.json",
  "domain": "project",
  "subdomain": "present",
  "topics": ["theme", "ucsf", "institutional", "colors", "fonts"],
  "keywords": ["ucsf", "theme", "institutional", "navy"],
  "summary": "UCSF institutional theme palette: navy/blue colors, Garamond headings",
  "line_count": 50,
  "load_when": {
    "task_types": ["present"],
    "agents": ["pptx-assembly-agent", "slidev-assembly-agent"],
    "commands": ["/slides"]
  }
}
```

### 7. index-entries.json - Template Directory Entries

The `templates/pptx-project/` and `templates/slidev-project/` already have entries for their individual files. The `UCSF_ZSFG_Template_16x9.pptx` binary file (3MB) should NOT have an index entry (binary files are not readable by agents via context loading).

## Decisions

1. **No routing changes needed** - The manifest routing already points to `skill-slides` which handles internal dispatch. The plan routing entry `present:slides -> skill-slides` is already present and correct.
2. **Replace slides-agent references in 2 existing index entries** rather than leaving stale agent names.
3. **Add ucsf-institutional.json entry** to index-entries.json as specified in task description.
4. **Do not add entries for academic-clean.json or clinical-teal.json** themes -- those pre-date this task and are out of scope.

## Recommendations

1. **Phase 1**: Update `manifest.json` provides.agents array (single line change)
2. **Phase 2**: Update `EXTENSION.md` skill-agent table (replace 1 row with 3 rows)
3. **Phase 3**: Update `index-entries.json`:
   - Fix 2 stale `slides-agent` references in existing entries
   - Add 1 new entry for `ucsf-institutional.json`
4. **Validation**: Run `jq . manifest.json` and `jq . index-entries.json` to verify valid JSON after edits

## Risks & Mitigations

- **Risk**: Stale `slides-agent` references in index entries could cause context loading failures for slides tasks.
  - **Mitigation**: This task fixes the 2 known stale references. A grep for `slides-agent` across the extension should confirm no others remain.
- **Risk**: JSON syntax errors from manual editing.
  - **Mitigation**: Validate all JSON files with `jq` after editing.

## Appendix

### Files Modified by Dependencies

**Task 403** (completed):
- Created: `agents/slides-research-agent.md`, `agents/pptx-assembly-agent.md`, `agents/slidev-assembly-agent.md`
- Deleted: `agents/slides-agent.md`

**Task 405** (completed):
- Rewrote: `skills/skill-slides/SKILL.md` with 3-workflow/4-agent dispatch model

### Current Agent File Inventory
```
agents/budget-agent.md
agents/funds-agent.md
agents/grant-agent.md
agents/pptx-assembly-agent.md      (NEW from task 403)
agents/slides-research-agent.md    (NEW from task 403)
agents/slidev-assembly-agent.md    (NEW from task 403)
agents/timeline-agent.md
```
Note: `slides-agent.md` no longer exists.
