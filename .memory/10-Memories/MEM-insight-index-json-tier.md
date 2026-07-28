---
title: "When classifying context index entries as Tier 4 (on-demand), also clear their a"
created: 2026-05-22
tags: [INSIGHT]
topic: "task-598"  # task-ref-ok inline, category 7 (memory frontmatter provenance field)
source: ""
modified: 2026-05-22
retrieval_count: 0
last_retrieved: null
keywords:
  - index.json
  - tier
  - load_when
  - agents
  - context-budget
  - enforcement
summary: "When classifying context index entries as Tier 4 (on-demand), also clear their a"
token_count: 90
---

# When classifying context index entries as Tier 4 (on-demand), also clear their a

When classifying context index entries as Tier 4 (on-demand), also clear their agents[] array — entries still in agents[] are auto-loaded at agent spawn regardless of tier label. Tier labels in index.json are documentation only; load_when arrays are the actual enforcement mechanism.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
