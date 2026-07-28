---
title: "Command files cannot delegate Skill tool invocations to bash scripts"
created: 2026-05-22
tags: [INSIGHT]
topic: "task-595"  # task-ref-ok inline, category 7 (memory frontmatter provenance field)
source: "specs/595_refactor_research_plan_implement_commands/reports/02_command-refactor-research.md"
modified: 2026-05-22
retrieval_count: 0
last_retrieved: null
keywords:
  - command
  - skill-tool
  - bash-script
  - dispatch
  - multi-task
  - constraint
summary: "Command files cannot delegate Skill tool invocations to bash scripts"
token_count: 100
---

# Command files cannot delegate Skill tool invocations to bash scripts

Command files cannot delegate Skill tool invocations to bash scripts. The parallel Skill calls in multi-task dispatch must remain as markdown prose in command files. Only pre-dispatch validation and post-dispatch output formatting can be extracted to scripts. This constrains how much multi-task dispatch can be reduced.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
