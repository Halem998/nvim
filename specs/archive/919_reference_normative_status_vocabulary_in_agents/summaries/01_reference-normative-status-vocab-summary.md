# Implementation Summary: Task #919

**Completed**: 2026-07-27
**Duration**: ~45 minutes

## Overview

Fifteen extension agent definitions under `agent-system/extensions/**` instructed agents to
write `.return-meta.json` but never pointed at `context/formats/return-metadata-file.md`, the
normative source for the seven-value status enum. All 15 files now carry an `@`-reference to
that file, placed per each file's structural shape (a new `## Context References` section for
13 files; a new leading `**Load Always**:` bullet inside an existing section for the 2 `web/`
files). One adjacent schema bug — `completion_data` nested inside `metadata` in
`pr-review-implementation-agent.md`'s worked example — was corrected in the same pass.

## What Changed

- `agent-system/extensions/latex/agents/latex-implementation-agent.md` — new `## Context References` section
- `agent-system/extensions/latex/agents/latex-research-agent.md` — same
- `agent-system/extensions/python/agents/python-implementation-agent.md` — same
- `agent-system/extensions/python/agents/python-research-agent.md` — same
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` — same
- `agent-system/extensions/typst/agents/typst-research-agent.md` — same
- `agent-system/extensions/z3/agents/z3-implementation-agent.md` — same
- `agent-system/extensions/z3/agents/z3-research-agent.md` — same
- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` — new `## Context References` section (Literature Briefing Context section left untouched)
- `agent-system/extensions/cslib/agents/cslib-research-agent.md` — same
- `agent-system/extensions/cslib/agents/pr-review-implementation-agent.md` — new `## Context References` section, plus un-nested `completion_data` from `metadata` to a top-level sibling in the Stage 7 worked example
- `agent-system/extensions/cslib/agents/pr-review-research-agent.md` — new `## Context References` section (no `completion_data` change needed; confirmed it has none)
- `agent-system/extensions/lean/agents/lean-research-agent.md` — new `## Context References` section
- `agent-system/extensions/web/agents/web-implementation-agent.md` — new `**Load Always**:` bullet inside existing `## Context References` section
- `agent-system/extensions/web/agents/web-research-agent.md` — same

## Decisions

- Followed the plan's correction to the research report: only `pr-review-implementation-agent.md`
  had the `completion_data`-nested-in-`metadata` bug; `pr-review-research-agent.md` correctly has
  no `completion_data` key (it terminates at `researched`, not `implemented`). Verified directly
  before editing — edited exactly one file in Phase 4, not two.
- Did not author local worked JSON examples for the 8 zero-example files (latex/python/typst/z3),
  per the plan's explicit Non-Goal — the `@`-reference gives them the canonical examples without
  creating 8 new copies to maintain.
- Did not add any `.orchestrator-handoff.json` contract to any of the 15 agents — hard scope
  boundary per the plan's Non-Goals; verified via diff grep in Phase 5.
- All edits landed exclusively in `agent-system/extensions/**` (the source store); zero writes to
  `.claude/**` at any point, verified after every phase.

## Plan Deviations

- None (implementation followed plan). One verification-methodology note: the plan's literal
  Phase 4 verification one-liner (`awk` extracting all fenced ` ```json ` blocks from
  `pr-review-implementation-agent.md` and piping the concatenation through `jq`) fails because
  the file has two separate ` ```json ` blocks (pre-existing, unchanged in count before/after
  this edit — confirmed via `git show`), which the plan's own text anticipates ("if the awk range
  picks up more than one block, check each block individually"). Followed that fallback: isolated
  the Stage 7 metadata block (lines 304-333) and ran the same placeholder-substitution + `jq -e`
  check on it alone — `JSON-SHAPE OK`.
- Similarly, the plan's Phase 5 verification script's boundary greps (`git diff -- agent-system/extensions`)
  are written assuming an uncommitted working tree; because each phase was committed
  immediately per the Commit-Per-Green-Substep Mandate, the working-tree diff was empty by Phase
  5. Re-ran the same four checks against `git diff ed4573caf..HEAD` (the pre-task-919 base
  commit) to cover the full task diff — all four checks (source-store, handoff-boundary,
  no-task-refs, no-enum-copy) pass against that wider diff.

## Verification

**Phase 1** (8 zero-example files): all report `refs=1 sections=1`, order
`## Context References|## Agent Metadata|`. `.claude/` clean.

**Phase 2** (5 cslib/lean files): all report `refs=1 sections=1`. Both cslib
`## Literature Briefing Context` counts remained `1` (untouched). `.claude/` clean.

**Phase 3** (2 web files): both report `refs=1 sections=1`. New `**Load Always**:` bullet
confirmed ahead of the pre-existing `**Load for ...**:` subgroups. `.claude/` clean.

**Phase 4** (pr-review-implementation-agent.md schema fix): `completion_data` now at exactly
2-space (top-level) indentation. Isolated Stage 7 JSON block validates with `jq -e` after
placeholder substitution: `JSON-SHAPE OK`. `pr-review-research-agent.md`'s `completion_data`
count: `0` (unchanged, correct). `.claude/` clean.

**Phase 5** (cross-cutting audit, run against full task diff `ed4573caf..HEAD`):
- All-15 reference check: `referenced: 15/15`, no `MISSING:` lines.
- Section-count check: all 15 files report `## Context References` count of exactly `1`, no
  `BAD SECTION COUNT` lines.
- Source-store check: `git diff ed4573caf..HEAD -- .claude/` is empty (0 lines) — zero `.claude/`
  modifications across the entire task.
- Handoff-boundary check: zero new `orchestrator-handoff` mentions added — `handoff boundary OK`.
- No-task-references check: zero task-number citations added outside `specs/**` —
  `no-task-refs OK`.
- Anti-copy-paste check: zero lines added containing both `in_progress` and `researched` — `no
  enum copy OK`.

- Build: N/A (markdown-only agent-prompt edits)
- Tests: N/A
- Files verified: Yes — all 15 target files confirmed present and edited; `pr-review-research-agent.md` confirmed unchanged in `completion_data` shape as required by the plan's correction to the research report.

## Notes

Every phase was committed individually per the Commit-Per-Green-Substep Mandate
(`task 919 phase 1` through `task 919 phase 5`), each preceded by phase-heading and progress-file
updates. No handoff artifacts were needed — all 5 phases completed within a single dispatch with
no context-pressure signals.
