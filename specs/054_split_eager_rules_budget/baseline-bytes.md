# Baseline Byte Accounting: Task 54 (split_eager_rules_budget)

Canonical measurement command (reused by every phase and by Phase 7's re-measure):
```bash
cat ~/.config/CLAUDE.md ~/.config/nvim/CLAUDE.md .claude/CLAUDE.md \
    .claude/rules/git-workflow.md .claude/rules/artifact-formats.md \
    .claude/rules/state-management.md .claude/rules/pr-prohibition.md \
    .claude/rules/source-store-deploy-boundary.md \
    .claude/rules/no-task-references-in-deliverables.md | wc -c
```

## Phase 1 Baseline (recorded before any edit)

- **Git HEAD at baseline**: `3a2e795a2ac2004ab80f1169ffaad7565902fa97`
- **git status --porcelain at baseline**: dirty, but only with foreign/unrelated changes not in
  this task's territory: `.claude-extensions.json`, three `agent-system/extensions/literature/**`
  files, `specs/TODO.md`, `specs/events.jsonl`, `specs/state.json` (all task-lifecycle-mechanical),
  plus untracked `.memory/10-Memories/*.md`, `.memory/learn-harvest-log.json`, and
  `agent-system/extensions/literature/scripts/literature-pyenv/`. None of these paths overlap this
  task's territory contract (Phase 2-7 owned files); observed and recorded, not touched.

### Parent chain

| File | Bytes |
|------|-------|
| `~/.config/CLAUDE.md` | 769 |
| `~/.config/nvim/CLAUDE.md` | 3,046 |
| **Total** | **3,815** |

Matches research expectation (3,815) exactly.

### Generated CLAUDE.md

| File | Bytes |
|------|-------|
| `.claude/CLAUDE.md` | 46,475 |

Matches research expectation (46,475) exactly.

### Six eager rules (deployed tree)

| File | Bytes |
|------|-------|
| `.claude/rules/git-workflow.md` | 11,147 |
| `.claude/rules/artifact-formats.md` | 5,360 |
| `.claude/rules/state-management.md` | 5,148 |
| `.claude/rules/pr-prohibition.md` | 4,628 |
| `.claude/rules/source-store-deploy-boundary.md` | 2,746 |
| `.claude/rules/no-task-references-in-deliverables.md` | 1,489 |
| **Total** | **30,518** |

Matches research expectation (30,518) exactly.

### Whole-prefix canonical figure

`cat <parent chain> .claude/CLAUDE.md <six rules> | wc -c` = **80,808 B**

Matches research expectation (80,808) exactly.

### All ten source-store rule files (`agent-system/extensions/core/rules/*.md`)

| File | Bytes |
|------|-------|
| `artifact-formats.md` | 5,360 |
| `error-handling.md` | 5,420 |
| `git-workflow.md` | 11,147 |
| `no-task-references-in-deliverables.md` | 1,489 |
| `plan-format-enforcement.md` | 3,414 |
| `project-overview-detection.md` | 1,130 |
| `pr-prohibition.md` | 4,628 |
| `source-store-deploy-boundary.md` | 2,746 |
| `state-management.md` | 5,148 |
| `workflows.md` | 759 |
| **Total** | **41,241** |

### Both merge sources

| File | Bytes |
|------|-------|
| `agent-system/extensions/core/merge-sources/claudemd.md` | 24,707 |
| `agent-system/extensions/literature/merge-sources/claudemd.md` | 12,851 |
| **Total** | **37,558** |

### Source store vs. deployed tree parity (the six eager rules)

All six `cmp`-identical between `agent-system/extensions/core/rules/*.md` and `.claude/rules/*.md`:
`git-workflow.md`, `artifact-formats.md`, `state-management.md`, `pr-prohibition.md`,
`source-store-deploy-boundary.md`, `no-task-references-in-deliverables.md` — MATCH, no care needed
for any of the six.

---

## Per-Phase Before/After Table (appended by each phase)

| Phase | File | Before (B) | After (B) | Delta (B) | % Change |
|-------|------|-------------|-----------|-----------|----------|
| 1 | (baseline only, no edits) | — | — | — | — |
