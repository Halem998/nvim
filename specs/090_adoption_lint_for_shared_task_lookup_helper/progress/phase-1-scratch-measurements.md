# Phase 1 scratch: live re-measurement (not a deliverable; consumed by Phases 3 and 7)

## Commands run (from repo root)

Narrow pattern (.sh, whole scripts/ tree per extension):
```
grep -rnP '\.active_projects\[\]\s*\|\s*select\(\.project_number\s*==[^)]*\)\s*[\x27"]' --include="*.sh" agent-system/extensions/*/scripts | grep -v 'del('
```
-> 5 files / 6 occurrences:
- agent-system/extensions/core/scripts/reconcile-task-status.sh (1)
- agent-system/extensions/core/scripts/command-gate-in.sh (1)
- agent-system/extensions/core/scripts/skill-base.sh (1) [canonical definition]
- agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh (2)
- agent-system/extensions/core/scripts/deprecated/archive-task.sh (1) [deprecated, excluded]

Narrow pattern (.md, scoped to commands/ skills/ agents/ per extension):
```
for sub in commands skills agents; do
  for d in agent-system/extensions/*/$sub; do
    [ -d "$d" ] || continue
    grep -rnP '\.active_projects\[\]\s*\|\s*select\(\.project_number\s*==[^)]*\)\s*[\x27"]' --include="*.md" "$d" 2>/dev/null
  done
done | grep -v 'del('
```
-> 58 files / 63 occurrences.

**TOTAL: 63 files / 69 occurrences** (matches the research report exactly). Excluding skill-base.sh:
62 files / 68 occurrences.

Broad pattern (candidate line present anywhere):
- Repo-wide, any file: 120 files (report said 122 -- within a couple, consistent with the plan's
  Scope Hypothesis)
- Executable surfaces only: 94 files (report said 96 -- within a couple)

## Grouped offender list (narrow pattern, executable surfaces)

### scripts/ (.sh) -- 5 files, 6 occurrences
- core/scripts/skill-base.sh -- CANONICAL (skill_validate_input definition)
- core/scripts/command-gate-in.sh -- CANONICAL (gate_in definition)
- core/scripts/reconcile-task-status.sh
- core/scripts/orchestrate-dry-run-report.sh (2 occurrences)
- core/scripts/deprecated/archive-task.sh -- deprecated/, structurally excluded

### commands/ (.md) -- 19 occurrences across these files
- core/commands/orchestrate.md
- core/commands/spawn.md
- core/commands/task.md
- epidemiology/commands/epi.md
- founder/commands/{analyze,consult,deck,finance,legal,market,meeting,project,sheet,strategy}.md
- present/commands/{budget,funds,grant,slides,timeline}.md

### skills/ (SKILL.md) -- 39 occurrences across these files
- core: skill-implementer, skill-implementer-hard, skill-orchestrate, skill-orchestrate-hard,
  skill-planner, skill-planner-hard, skill-researcher, skill-researcher-hard, skill-reviser,
  skill-spawn
- cslib: skill-cslib-implementation-hard, skill-cslib-research-hard, skill-cslib-vet
- epidemiology: skill-epi-implement, skill-epi-research
- formal: skill-logic-research
- founder: skill-analyze, skill-consult, skill-deck-research, skill-finance,
  skill-financial-analysis, skill-founder-spreadsheet, skill-legal, skill-market, skill-meeting,
  skill-project, skill-strategy
- lean: skill-lean-implementation, skill-lean-implementation-hard, skill-lean-research,
  skill-lean-research-hard
- present: skill-budget, skill-funds, skill-grant, skill-slide-critic, skill-slide-planning,
  skill-slides, skill-timeline
- web: skill-web-research

None fall under deprecated/ except core/scripts/deprecated/archive-task.sh.

## Canonical implementations confirmed present

- `skill_validate_input()` in core/scripts/skill-base.sh:189 (body contains narrow pattern) -- confirmed.
- `gate_in()` in core/scripts/command-gate-in.sh:64 (body contains narrow pattern) -- confirmed.

## skill_validate_input() caller count: ZERO real callers (confirmed)
```
grep -rn 'skill_validate_input' agent-system/extensions --include="*.sh" --include="*.md" | grep -v 'scripts/skill-base.sh'
```
Hits: test-skill-base-lifecycle.sh (prints the function name in a list, not a call),
docs/architecture/system-overview.md (prose), docs/guides/creating-skills.md (example, 3x),
docs/examples/research-flow-example.md (example), context/patterns/skill-lifecycle.md (prose).
No real call site outside skill-base.sh's own definition.

## gate_in() adopters: 8 (confirmed, matches report)
core/commands/task.md, todo.md, review.md, orchestrate.md, revise.md;
core/skills/skill-orchestrate-hard/SKILL.md, skill-todo/SKILL.md, skill-orchestrate/SKILL.md.

## Deleted lifecycle commands confirmed absent
core/commands/research.md, plan.md, implement.md: all absent (ls confirms "No such file").
No offender-list entries reference them.

## test-common-lib.sh status
`bash agent-system/extensions/core/scripts/tests/test-common-lib.sh` -> 30 passed, 0 failed.
`collect_session_id_offenders()` dual-mode probe present and reusable (verified by reading source,
lines ~235-296).

## Numbers for later phases
- Narrow-pattern total: 63 files / 69 occurrences (62 files / 68 occurrences excluding skill-base.sh)
- Allowlist entries expected: 63 (both canonical files exempted by definition, plus ~60
  migration-pending sites), close to the plan's ~60 estimate. deprecated/archive-task.sh is
  expected to be handled by Phase 2's structural directory exclusion, not a Layer 2 entry.
