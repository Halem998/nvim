---
title: Artifact Creation Must Use Skill Delegation
created: 2026-04-13
tags: [enforcement, delegation, bypass-prevention, artifacts, plans]
topic: agent-system
source: task-414, task-416  # task-ref-ok inline, category 7 (memory frontmatter provenance field)
modified: 2026-04-13
retrieval_count: 0
last_retrieved: null
keywords: [delegation, artifact, skill, bypass-prevention, enforcement]
summary: "When executing /plan, /research, or /implement commands, always invoke the appropriate Skill tool to create artifact files rather than writing directly from the orchestrator level."
token_count: 302
---

# Artifact Creation Must Use Skill Delegation

## Rule

When executing /plan, /research, or /implement commands, **always invoke the appropriate Skill tool** (skill-planner, skill-researcher, skill-implementer) to create artifact files. Never write plan, report, or summary files directly using Write or Edit tools from the orchestrator level.

## Incident Context

On 2026-04-13, the /plan command bypassed skill-planner delegation and wrote a plan file directly. The resulting artifact was missing required metadata fields (Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type) and required sections (Goals & Non-Goals, Risks & Mitigations, Testing & Validation, Artifacts & Outputs, Rollback/Contingency). This violated the plan format standard and produced a non-conforming artifact.

## Enforcement Mechanisms

1. **PostToolUse Hook** (primary): `.claude/hooks/validate-plan-write.sh` monitors all Write/Edit operations to `specs/*/plans/*.md`, `specs/*/reports/*.md`, and `specs/*/summaries/*.md`. Validation failures inject corrective context via `additionalContext`.

2. **Command Spec Anti-Bypass Sections** (secondary): plan.md, research.md, and implement.md each contain explicit "Anti-Bypass Constraint" sections prohibiting direct artifact writes.

3. **This Memory Entry** (tertiary): Persists the lesson across sessions so the delegation requirement is always in context.

## Key Principle

The delegation chain (command -> skill -> agent) exists to ensure format compliance. Each layer adds value: skills inject format specifications, agents have domain context, and postflight validates output. Bypassing any layer degrades artifact quality.
