# Implementation Summary: Task #21

- **Task**: 21 - resolve_vault_transition_comment_nondurable
- **Status**: [COMPLETED]
- **Started**: 2026-08-10T00:00:00Z
- **Completed**: 2026-08-10T00:55:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_resolve-vault-transition-comment.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Applied the research report's Option (a): deleted the hand-inserted vault-transition-comment
instruction from both live source-store sites (`commands/todo.md` and `skill-todo/SKILL.md`),
added a durable anti-mirroring rationale note modeled on the existing Step 5.6.2
`repository_health` precedent, and reconciled `commands/todo.md`'s vault-section
heading/substep numbering mismatch (`### 5.7.` heading vs `5.8.1`-`5.8.9` substeps) down to
`5.7.1`-`5.7.8`. Closed with a measurement-based acceptance phase.

## What Changed

- `agent-system/extensions/core/commands/todo.md` — Deleted the dead `**Step 5.8.9: Add
  transition comment to TODO.md**:` block (heading + inert bash variable assignments with no
  insertion command) and replaced it with a one-line durable rationale note referencing Step
  5.6.2. Renumbered the eight remaining substep headings `**Step 5.8.1:`..`**Step 5.8.8:` to
  `**Step 5.7.1:`..`**Step 5.7.8:` (including the period-terminated `Step 5.8.6`), preserving all
  title text verbatim. Left the `### 5.7. Vault Operation` heading, the `Track vault operations
  for output:` block, Section 5.6, and Section 6 untouched.
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` — Deleted the `Add vault transition
  comment to TODO.md:` prose label and its entire fenced bash block (the corrupting
  `sed -i "/^---$/,/^---$/{...}"` insertion, the only site of the two that actually executed and
  corrupted `specs/TODO.md`'s YAML frontmatter). Left the preceding `Add entry to vault_history:`
  block, the `task_range` computation, and the following `After sub-step 9.4 completes, continue
  to Stage 11 (UpdateRoadmap).` cross-reference entirely unmodified.

## Decisions

- **Rationale-note wording deviated from the plan's suggested text.** The plan's example wording
  ("*Vault transition information lives in ...*") literally contains the substring
  `"Vault transition"`, which fails this same phase's own `grep -c "Vault transition"` == 0
  verification criterion. Reworded to "The vault-transition record lives in ..." (hyphenated,
  lowercase `v`) to preserve the identical meaning while satisfying the check. This is the kind
  of self-contradiction the acceptance phase is designed to catch by measurement rather than by
  trusting the plan's literal text.
- No change to `agent-system/extensions/core/scripts/deprecated/vault-operation.sh` (out of
  scope, quarantined, zero live callers) and no change to any `.opencode/**` copy (deferred to
  the separately-tracked opencode-drift work), per the plan's explicit non-goals.
- No hand-editing of any `.claude/**` file — the deployed copies still show the pre-fix text
  until the next deploy/reload, which is expected and correct per the source-store/deploy
  boundary.

## Plan Deviations

- **Phase 1, rationale-note wording**: altered from the plan's literal suggested text to avoid
  the note re-triggering its own "zero occurrences of `Vault transition`" verification check.
  See Decisions above.
- No other deviations. All other tasks in all three phases were completed as specified.

## Verification

- Build: N/A (markdown-only changes)
- Tests: N/A
- Files verified: Yes — see Phase 3 measurements below.

### Phase 1 verification (measured)

- `grep -n "^### 5\.\|^\*\*Step 5\." agent-system/extensions/core/commands/todo.md` shows
  `### 5.7. Vault Operation (when next_project_number > 1000)` followed by exactly `**Step 5.7.1`
  through `**Step 5.7.8`, with no `5.8.` heading remaining. Confirmed.
- `grep -c "Vault transition" agent-system/extensions/core/commands/todo.md` returns `0`.
  Confirmed.
- `grep -n "Track vault operations for output" agent-system/extensions/core/commands/todo.md`
  still matches (line 899). Confirmed.
- Rationale note present, references Step 5.6.2. Confirmed.

### Phase 2 verification (measured)

- `grep -c "Vault transition" agent-system/extensions/core/skills/skill-todo/SKILL.md` returns
  `0`. Confirmed.
- `grep -n "transition_comment" ...SKILL.md` returns nothing. Confirmed.
- `grep -n "9\.1\.\|9\.2\.\|9\.3\.\|9\.4\.\|Stage 11" ...SKILL.md` still matches all anchors
  (9.1 VaultConfirmation, 9.2 CreateVault, 9.3 RenumberTasks, 9.4 ResetState, and both Stage 11
  cross-references). Confirmed.
- `grep -n "task_range\|vault_history" ...SKILL.md` still matches (deferred schema-divergence
  scope preserved, untouched). Confirmed.

### Phase 3 acceptance evidence

**Frontmatter parse (strict YAML loader, asserting on key set, not merely "no exception")**:

```
Parsed type: <class 'dict'>
Keys: ['next_project_number']
Has '<!-- Vault transition' key: False
```

This is the correct evidentiary bar because the corrupted form *also* parses successfully — it
does not raise an exception. `yaml.safe_load` over the pre-fix corrupted block would silently
return `{'next_project_number': 20, '<!-- Vault transition': '...'}` (a bogus second key), so
"no exception raised" alone is insufficient evidence of correctness; the check must assert on
the key set.

**End-state simulation**: ran `bash .claude/scripts/generate-todo.sh` (the sanctioned
regeneration path) and re-parsed `specs/TODO.md`'s frontmatter — result identical (`Keys:
['next_project_number']`, no stray key), confirming the acceptance narrative holds: no
transition comment is present in the frontmatter before or after regeneration.

**Durable-record check**:
```
jq '.vault_history' specs/state.json
[
  {
    "vault_number": 1,
    "vault_dir": "specs/vault/01-vault/",
    "created_at": "2026-08-10T19:49:05Z"
  }
]

specs/vault/01-vault/meta.json
{
  "vault_number": 1,
  "created_at": "2026-08-10T19:49:05Z",
  "archived_count": 1431,
  "final_task_number": 1020
}
```
Both present and populated — Option (a) loses no information.

**Survivor grep (using `command grep`, bypassing the ugrep `.gitignore`-honoring shim)**:

Measured five-bucket accounting, `command grep -rn --exclude-dir=.git "Vault transition" .`:

| Bucket | Scope | Measured count | Plan hypothesis | Match? |
|--------|-------|-----------------|------------------|--------|
| 1 | `agent-system/extensions/**` excluding `scripts/deprecated/**` | **0** | 0 | Yes |
| 2 | `agent-system/extensions/core/scripts/deprecated/vault-operation.sh` | **1** | 1 | Yes |
| 3 | `.opencode/**` | **5 files** | 5 files | Yes |
| 4 | `.claude/**` (deployed copies) | **2 files** | 2 files | Yes |
| 5 | `specs/**` | **10 files** | not enumerated | N/A (exempt) |

Bucket 1 (the acceptance target) is measured at **0**, resolving the research report's internal
inconsistency in favor of its own "Post-fix survivor accounting" section (which projected 0)
over its Executive Summary (which stated "3 non-deprecated, non-`.opencode` occurrences...
remain"). The Executive Summary's "3" figure was written as a *pre-fix* prediction that
undercounted correctly-scoped exclusions; the report's own detailed accounting section already
explained why the true post-fix count in scope is 0 (both live sites drop to 0, and the "3" in
the loose repo-wide pre-fix listing conflated live-source-store hits with deployed/opencode/specs
hits that were never in bucket 1's scope). The measured 0 confirms the detailed section was
correct and the Executive Summary's one-line restatement was the inconsistent one.

Bucket 2 justification: `agent-system/extensions/core/scripts/deprecated/vault-operation.sh` is
quarantined dead code with zero live callers (see `deprecated/README.md`); retained by explicit
plan scope decision, not fixed.

Bucket 3 justification (5 files, enumerated so none is silently forgotten):
```
.opencode/commands/todo.md
.opencode/scripts/vault-operation.sh
.opencode/extensions/core/commands/todo.md
.opencode/extensions/core/skills/skill-todo/SKILL.md
.opencode/skills/skill-todo/SKILL.md
```
Deferred to the separately-tracked opencode-drift work per the plan's explicit non-goal.

Bucket 4 justification (2 files):
```
.claude/commands/todo.md
.claude/skills/skill-todo/SKILL.md
```
Deployed copies of the two source-store files just edited; not hand-edited per the binding
source-store rule; will self-correct on the next deploy/reload.

Bucket 5 justification (10 files, all exempt): this task's own live report/plan/progress
artifacts (which necessarily quote the defect string while describing it), `specs/TODO.md`'s own
current-task description text, `specs/state.json`'s corresponding task-description field, and
five files under `specs/vault/01-vault/archive/{653,248}_.../` that are archived historical
records documenting a prior, already-completed removal of the transition-comment *script* (not
this task's prose-instruction defect) — archived artifacts are never edited retroactively.

**Dangling-reference sweep**: `command grep -rn "5\.8\." agent-system/extensions/` returns hits
only under `scripts/deprecated/vault-operation.sh` (its own internal `# --- Step 5.8.N ---`
comment labels, 8 hits, now stale relative to the renumbered live doc — an accepted property of
quarantined code per the plan's explicit non-goal). No `5.8.` hits remain anywhere else under
`agent-system/extensions/`.

One related but non-blocking finding, **not fixed** (outside this plan's approved file list):
`agent-system/extensions/core/scripts/deprecated/README.md` line 32 describes
`vault-operation.sh`'s supersession as "`commands/todo.md` Steps 5.7-5.8 fully hand-implement
vault creation, renumbering, and state reset" — a *range* reference that predates this task's
renumbering and is now stale (everything is consolidated under `5.7.x`). This did not surface in
the literal `5\.8\.` sweep because the text reads "5.7-5.8" (no trailing period after "5.8").
The plan's own risk-mitigation claim that "`deprecated/README.md` references only the heading
('Step 5.7')" is therefore not fully accurate — line 43 does say only "Step 5.7", but line 32
says "Steps 5.7-5.8". This is cosmetic (describes a deprecated script's own now-superseded
counterpart, not a functional cross-reference) and touching it would expand this plan's reviewed
edit surface beyond its approved file list; flagged as a follow-up rather than fixed here.

**Doc-lint gate**: `bash .claude/scripts/check-extension-docs.sh` — all 20 extensions report
`PASS` (core included). The 36 advisory items listed are pre-existing, unrelated
"core script never deployed" notices (mostly literature-extension scripts) attributable to the
deploy tree being stale, not to these edits; none names `commands/todo.md`, `skill-todo/SKILL.md`,
or `deprecated/README.md`. No new failures attributable to this task's edits.

## Impacts

- No live document instructs a caller to hand-edit `specs/TODO.md` for vault transitions; the
  only remaining source of that instruction is the quarantined, zero-caller
  `scripts/deprecated/vault-operation.sh`.
- `commands/todo.md`'s vault section heading and substep numbers now agree (`5.7.1`-`5.7.8` under
  `### 5.7.`), matching the existing pattern in Section 5.6.
- The `.vault_history[]` schema divergence between the two documents (`task_range` /
  `archived_count` / `final_task_number` present in `SKILL.md`, absent from `commands/todo.md`)
  remains untouched, as explicitly scoped out of this plan — carried forward for a future task.

## Follow-ups

- `agent-system/extensions/core/scripts/deprecated/README.md` line 32's "Steps 5.7-5.8" range
  reference is now stale after this task's renumbering; a trivial follow-up could update it to
  "Step 5.7" for accuracy. Not fixed here — outside this plan's approved file list.
- The `.vault_history[]` schema divergence between `commands/todo.md` and `skill-todo/SKILL.md`
  (flagged by the research report, explicitly deferred by this plan) remains open for a future
  task.
- The five `.opencode/**` copies of the deleted instruction remain, deferred to the
  separately-tracked opencode-drift work (enumerated above in bucket 3).

## References

- Plan: `specs/021_resolve_vault_transition_comment_nondurable/plans/01_resolve-vault-transition-comment.md`
- Research report: `specs/021_resolve_vault_transition_comment_nondurable/reports/01_resolve-vault-transition-comment.md`
