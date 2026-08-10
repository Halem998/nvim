# Implementation Summary: Task #641

**Completed**: 2026-06-08
**Duration**: ~30 minutes

## Overview

Replaced a nonexistent "keyword heuristic" topic inference reference in `meta-builder-agent.md` with a real interactive topic picker (new Stage 4.5: AssignTopic). Also renamed Stage 3.5 from "AnalyzeTopics (Topic Clustering)" to "AnalyzeConsolidation (Task Consolidation)" to eliminate naming confusion between task consolidation and topic assignment. Updated all cross-references across 6 files to reflect the new naming.

## What Changed

- `.claude/agents/meta-builder-agent.md` — Renamed Stage 3.5 heading and AskUserQuestion header; added new Stage 4.5 (AssignTopic) between Stage 4 and Stage 5; updated Stage 5 table note to reference Stage 4.5; replaced "Topic Auto-Inference" / "keyword heuristic" paragraph in Stage 6 with correct `batch_topic` assignment logic
- `.claude/extensions/core/agents/meta-builder-agent.md` — Same changes as main agent file (extension mirror): Stage 3.5 rename, new Stage 4.5 section, Stage 5 table with Topic column and Stage 4.5 note, Stage 6 Topic Assignment note with state.json entry example
- `.claude/docs/reference/standards/multi-task-creation-standard.md` — 4 text substitutions: "Automatic Topic Clustering" -> "Automatic Task Consolidation", "AnalyzeTopics" -> "AnalyzeConsolidation", "Topic Clustering" -> "Task Consolidation"
- `.claude/extensions/core/docs/reference/standards/multi-task-creation-standard.md` — Same 4 substitutions (extension mirror)
- `.claude/context/meta/meta-guide.md` — Stage 3.5 heading renamed from "AnalyzeTopics (Topic Clustering)" to "AnalyzeConsolidation (Task Consolidation)"
- `.claude/extensions/core/context/meta/meta-guide.md` — Same heading rename (extension mirror)

## Decisions

- The extension copies of meta-builder-agent.md (`.claude/extensions/core/agents/`) also needed the Stage 4.5 section added, even though they lacked the "keyword heuristic" text — keeping them in sync is the correct approach since they serve as mirrors
- The `keyword heuristic` references in `skill-fix-it/SKILL.md` and `todo.md` were left unchanged as they describe different, legitimate behaviors (tag-based heuristics for fix-it, and semantic matching for todo) unrelated to the broken reference in meta-builder-agent.md
- Stage 4.5 follows the same pattern as `/task` Step 4.5 (AskUserQuestion with dynamic options from `active_topics`, "New topic..." free-text follow-up, "Skip (no topic)" escape hatch)

## Plan Deviations

- None (implementation followed plan, with one addition: the extension copy of meta-builder-agent.md also needed Stage 5 table Topic column and Stage 6 topic assignment note added, not just Stage 3.5 rename — the plan only mentioned Stage 3.5 for that file)

## Verification

- Build: N/A (markdown files)
- Tests: N/A
- Files verified: Yes
- `grep -rn "AnalyzeTopics" .claude/` returns zero results
- `grep -rn "keyword heuristic" .claude/agents/ .claude/extensions/core/agents/` returns zero results
- `grep -rn "AnalyzeConsolidation" .claude/` returns hits in all 5 updated files (10 total lines across both copies)
- `grep -rn "AssignTopic" .claude/agents/ .claude/extensions/core/agents/` returns Stage 4.5 heading in both files
- `grep -rn "batch_topic"` returns references in Stages 4.5, 5, and 6 of both agent files

## Notes

The new Stage 4.5 ensures that every `/meta`-created task batch gets a `topic` field when the user assigns one through the interactive picker. The "Skip (no topic)" option provides an escape hatch for multi-domain sessions where a single batch topic is inappropriate.
