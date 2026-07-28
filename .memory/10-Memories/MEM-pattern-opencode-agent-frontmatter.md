---
title: "OpenCode agent frontmatter pattern: Only `name` and `description` fields are sup"
created: 2026-06-08
tags: [PATTERN]
topic: "task-635"  # task-ref-ok inline, category 7 (memory frontmatter provenance field)
source: "specs/635_port_synthesis_domain_agents/summaries/01_synthesis_domain_agents_implementation-summary.md"
modified: 2026-06-08
retrieval_count: 0
last_retrieved: null
keywords:
  - opencode
  - agent-frontmatter
  - port-pattern
  - model-field
  - allowed-tools
  - synthesis-agent
summary: "OpenCode agent frontmatter pattern: Only `name` and `description` fields are sup"
token_count: 197
---

# OpenCode agent frontmatter pattern: Only `name` and `description` fields are sup

OpenCode agent frontmatter pattern: Only `name` and `description` fields are supported. The `model` field causes 'Model not found' errors because parseModel() splits on '/'. When porting from .claude/ to .opencode/: (1) strip `model:` line entirely, (2) strip `allowed-tools:` line entirely (document minimal tool surface inline in Overview instead, since OpenCode does not enforce tool restrictions via frontmatter), (3) update all `.claude/context/` path references to `.opencode/context/`, (4) update all `.claude/extensions/` to `.opencode/extensions/`, (5) replace `Agent tool`/`Agent(...)` with `Task tool`/`Task(...)`. Frontmatter is exactly 5 lines: `---` opener, `name:`, `description:`, `---` closer.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
