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
| 2 | `core/rules/git-workflow.md` | 11,147 | 7,000 | -4,147 | -37.2% |
| 2 | `core/context/standards/git-workflow-narrative.md` (new, lazy) | 0 | 5,082 | +5,082 | new file |

**Phase 2 note**: the achieved eager core (7,000 B) is higher than the research's ~4,200 B
hypothesis. Reason: the full "No Destructive Git on Uncommitted Work" forbidden-operations list,
exemption summary, and the "snapshot first" instruction were kept in full per the Risks table's
explicit mitigation (only the mode-by-mode `--branch`/`--no-revert` prose moved), and the
Commit Conventions tables plus the retained portions of Git Safety are inherently large. All
KEEP-list items (Commit Conventions tables, Do Not Commit / Create Commits After, the
Commit-Per-Green-Substep Mandate heading + binding paragraph, Never Run, Forbidden-on-a-dirty-tree,
Not-blocked, Always Check Before Commit, Commit Message Format + Session ID format/generation) are
present verbatim — confirmed by direct read of the trimmed file, not asserted.

| 3 | `core/rules/error-handling.md` | 5,420 | 2,987 | -2,433 | -44.9% |
| 3 | `core/context/standards/error-recovery-strategies.md` (new, lazy) | 0 | 4,435 | +4,435 | new file |

**Phase 3 note**: this file was NOT one of the measured eager six (its `paths: .claude/**/*` glob
did not match the session that produced the 30,518 B figure), so this saving is
regression-prevention rather than an immediate cut to the 30,518 B six-rule total — reported here
as its own line, not folded into that total. The write-gating "never discard uncommitted changes
to reach a passing build" constraint was re-anchored as a standalone eager
`## Write-Gating Constraint` section (confirmed present via grep) rather than left inside the
now-moved Build Error Recovery narrative. All explicit KEEP items (Error Categories taxonomy,
condensed Log-the-Error pointer, Preserve Progress/Enable Resume/Report Clearly, Severity Levels
table, Non-Blocking Errors list) are present verbatim in the trimmed file.

| 4 | `core/rules/state-management.md` | 5,148 | 3,850 | -1,298 | -25.2% |
| 4 | `core/context/reference/state-management-schema.md` (existing, appended) | 472 lines | 519 lines | +47 lines | destination for moved narrative |

**Phase 4 note**: destination decision — the moved narrative (Artifacts-Are-Append-Only
enforcement mechanism + known limitation, State-First Update Pattern explanation, Error Handling)
was appended to the EXISTING `context/reference/state-management-schema.md` as a new
"## Enforcement and Update-Pattern Narrative" section, rather than creating a third
`context/standards/` companion. Reason: that schema doc is already the rule's designated
elaboration home (referenced by its own "## Schema Reference" section and the `#file-scope-field`
anchor), so appending there avoids fragmenting elaboration across three files for one rule. The
ASCII status-transition diagram was NOT dropped (both the diagram and the bulleted Restrictions
survive eager, per the "never drop both" instruction) since the achieved core (3,850 B) already
lands close to the ~3,450 B hypothesis without needing that cut. All five KEEP items (Never edit
TODO.md directly, Canonical Sources block, Artifacts-Are-Append-Only core prohibition +
wholesale-assignment prohibition + `+=`/sanctioned-helper instruction, Status Transitions
restrictions bullets, the two `update-task-status.sh`/`generate-todo.sh` one-liners, File
Scope/Schema Reference pointers) are present verbatim — confirmed by grep.

**Phase 2 check-extension-docs.sh note**: `check-extension-docs.sh` reports
`FAIL: deployed rule content drift (deployed != extension source): rules/git-workflow.md` at this
point in the plan. This is EXPECTED and BY DESIGN: the deployed `.claude/` tree is written only by
the single `deploy-headless.sh` redeploy in Phase 7 (per this plan's binding rules and Non-Goals),
so source-vs-deployed drift is expected to persist through Phases 2-6 and is resolved only once,
in Phase 7. Five additional pre-existing drift FAILs (`lint-agent-contracts.sh`,
`orchestrate-recover-outcome.sh`, `orchestrator-postflight.sh`, `skill-base.sh`,
`test-lint-agent-contracts.sh`) were already present in the working tree BEFORE this task's Phase 1
baseline commit (confirmed: Phase 1's `cmp` check found the six eager RULES byte-identical to
deployed, but this drift check also covers `provides.scripts`, which Phase 1 did not check) — they
belong to other, unrelated in-flight work and are out of this task's territory; not touched, not
fixed here. `generate-context-line-counts.sh --check` passes clean (486/486 exact) confirming the
new companion's `index-entries.json` entry is correct.
