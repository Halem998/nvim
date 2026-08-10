# Research Report: Task #261

**Task**: 261 - project_manifest_update
**Started**: 2026-03-23T00:00:00Z
**Completed**: 2026-03-23T00:05:00Z
**Effort**: 30 minutes
**Dependencies**: Task #260 (COMPLETED)
**Sources/Inputs**: manifest.json, EXTENSION.md, index-entries.json, Task #260 artifacts
**Artifacts**: specs/261_project_manifest_update/reports/01_manifest-update-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- manifest.json requires updates to register project-agent.md, skill-project, and project.md
- Routing entries needed for "founder:project" in research, plan, and implement sections
- Task #260 created all required files but did NOT update manifest.json
- index-entries.json also needs project-timeline.typ template entry

## Context and Scope

Task #261 requires updating the founder extension manifest.json to register the project timeline components created in Task #260. The research examines the current manifest structure and identifies the exact changes needed.

## Findings

### Current manifest.json Structure

The manifest at `.claude/extensions/founder/manifest.json` has the following relevant sections:

```json
{
  "provides": {
    "agents": [
      "market-agent.md",
      "analyze-agent.md",
      "strategy-agent.md",
      "founder-plan-agent.md",
      "founder-implement-agent.md",
      "legal-council-agent.md"
    ],
    "skills": [
      "skill-market",
      "skill-analyze",
      "skill-strategy",
      "skill-founder-plan",
      "skill-founder-implement",
      "skill-legal"
    ],
    "commands": ["market.md", "analyze.md", "strategy.md", "legal.md"],
    ...
  },
  "routing": {
    "research": {
      "founder": "skill-market",
      "founder:market": "skill-market",
      "founder:analyze": "skill-analyze",
      "founder:strategy": "skill-strategy",
      "founder:legal": "skill-legal"
    },
    "plan": {
      "founder": "skill-founder-plan"
    },
    "implement": {
      "founder": "skill-founder-implement"
    }
  },
  ...
}
```

### Files Created by Task #260

Task #260 created the following files that need registration:

| File | Type | Path | Status |
|------|------|------|--------|
| project-agent.md | Agent | `.claude/extensions/founder/agents/project-agent.md` | Exists (24280 bytes) |
| skill-project | Skill | `.claude/extensions/founder/skills/skill-project/SKILL.md` | Exists (10814 bytes) |
| project.md | Command | `.claude/extensions/founder/commands/project.md` | Exists (18590 bytes) |
| project-timeline.typ | Template | `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` | Exists (833 lines) |

### Required manifest.json Changes

**1. Add to provides.agents array:**
```json
"project-agent.md"
```

**2. Add to provides.skills array:**
```json
"skill-project"
```

**3. Add to provides.commands array:**
```json
"project.md"
```

**4. Add to routing.research section:**
```json
"founder:project": "skill-project"
```

**5. No changes needed for routing.plan** - The generic "founder" routing to skill-founder-plan handles project tasks.

**6. No changes needed for routing.implement** - The generic "founder" routing to skill-founder-implement handles project tasks.

### Required index-entries.json Update

The `project-timeline.typ` template needs an entry for context discovery:

```json
{
  "path": "project/founder/templates/typst/project-timeline.typ",
  "summary": "Typst template for project timeline PDF reports with WBS, Gantt charts, PERT diagrams, and risk matrices",
  "line_count": 833,
  "load_when": {
    "agents": ["project-agent", "founder-implement-agent"],
    "languages": ["founder"],
    "commands": ["/project", "/implement"]
  }
}
```

### Verification from EXTENSION.md

The EXTENSION.md file already documents the complete routing (updated by Task #260):
- Commands table includes /project with 3 usage entries
- task_type routing table includes project -> skill-project
- Skill-to-Agent Mapping includes skill-project -> project-agent
- Language-Based Routing includes founder:project -> skill-project

This confirms the expected routing pattern.

## Recommendations

### Implementation Plan

1. **Phase 1: Update manifest.json provides section**
   - Add "project-agent.md" to agents array
   - Add "skill-project" to skills array
   - Add "project.md" to commands array

2. **Phase 2: Update manifest.json routing section**
   - Add "founder:project": "skill-project" to routing.research

3. **Phase 3: Update index-entries.json**
   - Add project-timeline.typ template entry

4. **Phase 4: Verification**
   - Validate JSON syntax for both files
   - Verify extension loads correctly

### Exact Changes Summary

| File | Section | Action | Value |
|------|---------|--------|-------|
| manifest.json | provides.agents | Add | "project-agent.md" |
| manifest.json | provides.skills | Add | "skill-project" |
| manifest.json | provides.commands | Add | "project.md" |
| manifest.json | routing.research | Add | "founder:project": "skill-project" |
| index-entries.json | entries | Add | project-timeline.typ entry |

## Decisions

- No changes needed for routing.plan and routing.implement - the generic "founder" routing suffices since project tasks follow the standard plan/implement workflow
- index-entries.json update included because project-timeline.typ was created but not registered

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| JSON syntax error | Extension fails to load | Low | Validate with jq after editing |
| Missing routing entry | /research N for project tasks fails | Medium | Verify founder:project entry exists |
| Inconsistent array ordering | None (functional) | Low | Maintain alphabetical order for consistency |

## Appendix

### Search Queries Used
- Glob: `.claude/extensions/founder/**/*`
- Read: manifest.json, EXTENSION.md, index-entries.json, Task #260 plans/summaries
- Bash: File existence and line count verification

### References
- manifest.json schema from existing founder extension
- EXTENSION.md routing documentation
- Task #260 implementation summary
