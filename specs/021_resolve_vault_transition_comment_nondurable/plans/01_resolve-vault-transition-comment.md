# Implementation Plan: Task #21

- **Task**: 21 - resolve_vault_transition_comment_nondurable
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/021_resolve_vault_transition_comment_nondurable/reports/01_resolve-vault-transition-comment.md
- **Artifacts**: plans/01_resolve-vault-transition-comment.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Apply the research report's chosen resolution — **Option (a)**: delete the hand-inserted
vault-transition-comment instruction from both live source-store sites, relying on the already
correct and already durable `specs/state.json` `.vault_history[]` and
`specs/vault/{NN}-vault/meta.json` records (plus the existing vault git-commit-message signal).
Add a short anti-mirroring rationale note at the deletion site in `commands/todo.md`, modeled on
the existing Step 5.6.2 `repository_health` note, so the instruction is not reintroduced a third
time. Reconcile the same section's heading/substep numbering mismatch (`### 5.7.` heading vs
`5.8.1`–`5.8.9` substeps) down to `5.7.1`–`5.7.8`. Close with a measurement-based acceptance
phase that parses `specs/TODO.md`'s frontmatter as YAML and produces a justified survivor count.

### Research Integration

The report supplies the decision and the concrete edit shape; this plan does not re-derive it.
Key findings carried in directly:

- `generate-todo.sh` never reads the pre-existing `TODO.md` (write-only `TODO_FILE`, atomic
  `mktemp` + `mv`), so hand-authored content cannot survive by construction. Option (c) is
  rejected for contradicting that design; option (b) is rejected for diverging from the Step
  5.6.2 `repository_health` precedent without a distinguishing rationale.
- The `skill-todo` sed range `/^---$/,/^---$/` matches both frontmatter delimiters, so `a\`
  fires twice — once inside the YAML block, once after it. The corrupted block does **not** raise
  a parse error; `yaml.safe_load` silently returns a bogus `'<!-- Vault transition'` key. Silent
  corruption, not a loud crash, which is why deletion (not repair) is correct.
- `commands/todo.md`'s Step 5.8.9 body is already dead: two shell variable assignments and a
  comment, with no insertion command. Only the `SKILL.md` block actually executes and corrupts.

**One research uncertainty resolved during planning** (do not re-investigate): the report flagged
that it had not traced `skill-todo/SKILL.md`'s `9.1`–`9.4` sub-step labeling and asked the
implementer to re-verify the boundary. Verified: the transition-comment bash block at
`SKILL.md:877-892` sits **inside** sub-step `9.4. ResetState` (which opens at line 827), as its
last element, followed at line 894 by the prose `After sub-step 9.4 completes, continue to Stage
11 (UpdateRoadmap).` Deleting the block therefore leaves the `9.1`–`9.4` scheme, the line-894
cross-reference, and the line-896/899 checkpoints all correct and untouched. **No renumbering is
needed in `SKILL.md`** — that risk from the report is closed.

**One research statement to reconcile by measurement, not by copying** (see Phase 3): the
report's Executive Summary says "3 non-deprecated, non-`.opencode` occurrences ... remain", while
its own "Post-fix survivor accounting" section says the same grep "should return **0**
occurrences". These are inconsistent. The plan treats **0 within
`agent-system/extensions/**` excluding `scripts/deprecated/**`** as the hypothesis and requires
the implementer to confirm by running the grep, not to restate either number.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but no `roadmap_path` was supplied in the delegation context and no
roadmap flag was set, so no roadmap review/update phases are included and ROADMAP.md is not read
or modified by this plan.

## Goals & Non-Goals

**Goals**:
- No live document instructs a caller to hand-edit `specs/TODO.md` for vault transitions.
- A durable rationale note prevents a third reintroduction of the same instruction.
- `commands/todo.md`'s vault section heading and substep numbers agree.
- Acceptance demonstrated by measurement: YAML parse of `specs/TODO.md` frontmatter, and a
  grep-derived survivor count with a written justification for every survivor.

**Non-Goals**:
- **`scripts/deprecated/vault-operation.sh` stays untouched.** Zero live callers; quarantined.
  Its internal `5.8.x` step-comment labels become stale relative to the renumbered live doc —
  that is an accepted property of deprecated code, not a defect to fix here.
- **All five `.opencode/**` copies are deferred** to the separately-tracked opencode-drift work.
  `.opencode/` has no agent-system source, is not currently in use, and is itself a deploy
  artifact. They are enumerated in Phase 3's survivor table so they are not silently forgotten.
- **Not fixing** the `.vault_history[]` schema divergence between the two documents
  (`task_range` / `archived_count` / `final_task_number` present in `SKILL.md`, absent from
  `commands/todo.md`, with a wrong `$((next_num - renumber_count - 1))` formula). The report
  flags it for a future task; touching it here would expand the reviewed edit surface. The
  `task_range` computation at `SKILL.md:855` is **left exactly as-is** even though it sits three
  lines above the deleted block.
- No change to `generate-todo.sh`. No new rendering branch, no read-modify-write.
- No hand-editing of `.claude/**` (binding source-store rule); deployed copies self-correct on
  the next deploy/reload.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent separately-tracked repository-metrics work edits the same `commands/todo.md` | M | M | Phase 1 opens with a mandatory fresh `Read` of the file and matches on text, never on the line numbers quoted here; if the Section 5.6 region has shifted, proceed on matched text |
| Survivor grep under-reports because this shell's `grep` is a ugrep shim with `--ignore-files` (honors `.gitignore`), silently hiding gitignored `.claude/**` hits | H | H | Phase 3 MUST use `command grep` (bypassing the shim) or explicit directory arguments; verified during planning that `grep -rln "Vault transition" .` omits both `.claude/**` hits that a targeted grep finds |
| Deleting the `SKILL.md` block breaks the `9.1`–`9.4` cross-references | M | L | Closed during planning: the block is the tail of 9.4, not its own sub-step; Phase 2 re-greps `9.1`–`9.4` and `Stage 11` anchors to confirm |
| Renumbering `5.8.x` -> `5.7.x` orphans a cross-reference elsewhere | M | L | Phase 3 re-greps for any surviving `5.8.` reference outside `deprecated/`; `deprecated/README.md` references only the heading ("Step 5.7") and is unaffected |
| Accidentally deleting the adjacent `task_range` lines or the `Track vault operations for output:` block | M | L | Both explicitly named as out-of-scope survivors in Phase 1/2 task lists; Phase 3 confirms both still present |
| An overbroad `sed` renumber rewrites `5.8.` occurrences outside the vault section | M | L | Renumber only the eight `**Step 5.8.N:` heading lines, anchored on the `**Step ` prefix; confirm exactly 8 heading lines changed |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files
(`commands/todo.md` vs `skills/skill-todo/SKILL.md`) and share no state.

---

### Phase 1: Delete dead vault-comment step and reconcile numbering in commands/todo.md [COMPLETED]

**Goal**: `agent-system/extensions/core/commands/todo.md` no longer instructs transition-comment
insertion, carries a durable rationale note against reintroduction, and its vault-section
substeps are numbered consistently with the `### 5.7.` heading.

**Tasks**:
- [x] **Re-read the whole file first** — separately-tracked repository-metrics work also edits
      it. Treat every line number below as advisory; match on text. *(completed: re-read
      confirmed exact anchors match plan expectations)*
- [x] Delete the `**Step 5.8.9: Add transition comment to TODO.md**:` block in its entirety —
      the heading line and the fenced bash block beneath it (`current_date=`, `comment=`,
      `# Insert after frontmatter`), around lines 893-898. *(completed)*
- [x] In its place, add a one-line rationale note in the style of the existing Step 5.6.2 note,
      e.g.: *Vault transition information lives in `state.json` `.vault_history[]` and
      `specs/vault/{NN}-vault/meta.json` only — TODO.md does not carry a transition marker,
      because `generate-todo.sh` fully overwrites TODO.md on every run (no read-modify-write of
      the existing file), so any hand-inserted marker is erased by the next regeneration. See
      Step 5.6.2 for the identical rationale applied to `repository_health`.*
      *(completed: deviation — wording changed to "The vault-transition record lives in
      `state.json` `.vault_history[]` and ..." because the plan's suggested wording literally
      contains the substring "Vault transition", which fails this same phase's own
      `grep -c "Vault transition" == 0` verification criterion)*
- [x] Renumber the eight remaining substep headings `**Step 5.8.1:` .. `**Step 5.8.8:` to
      `**Step 5.7.1:` .. `**Step 5.7.8:`, preserving each heading's title text verbatim. Note
      `Step 5.8.6` is worded `**Step 5.8.6: Reinitialize archive**.` (period-terminated, not
      colon) — do not let a colon-anchored match skip it. *(completed: all 8 headings renumbered,
      including the period-terminated 5.7.6)*
- [x] Leave untouched: the `### 5.7. Vault Operation (when next_project_number > 1000)` heading
      itself, the `Track vault operations for output:` block that follows the deleted step, all
      of Section 5.6, and Section 6. *(completed: confirmed unchanged)*
- [x] Confirm the file still contains zero occurrences of `Vault transition`. *(completed:
      `grep -c` returns 0)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly 8 substep headings remain after the deletion and are renumbered
`5.7.1`–`5.7.8`; the deleted block spans roughly lines 893-898. Confirm at implementation time by
re-running `grep -n "^### 5\.\|^\*\*Step 5\." agent-system/extensions/core/commands/todo.md` both
before and after the edit and comparing the heading lists — do not assume the pre-edit line
numbers still hold.

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md` - delete Step 5.8.9 block, insert rationale
  note, renumber eight substep headings

**Verification**:
- `grep -n "^### 5\.\|^\*\*Step 5\." agent-system/extensions/core/commands/todo.md` shows
  `### 5.7. Vault Operation ...` followed by exactly `**Step 5.7.1` through `**Step 5.7.8`, with
  no `5.8.` heading remaining.
- `grep -c "Vault transition" agent-system/extensions/core/commands/todo.md` returns 0.
- `grep -n "Track vault operations for output" agent-system/extensions/core/commands/todo.md`
  still matches.
- Rationale note is present and references Step 5.6.2.

---

### Phase 2: Delete the corrupting sed block from skill-todo/SKILL.md [COMPLETED]

**Goal**: `agent-system/extensions/core/skills/skill-todo/SKILL.md` no longer contains the
executable transition-comment insertion — the only site of the two that actually runs and
corrupts frontmatter.

**Tasks**:
- [x] Re-read the sub-step `9.4. ResetState` region (opens near line 827) before editing.
      *(completed: confirmed exact anchors match plan expectations)*
- [x] Delete the `Add vault transition comment to TODO.md:` prose label together with its entire
      fenced bash block — from `current_date=$(date +"%Y-%m-%d")` through the closing fence after
      the `fi`, i.e. roughly lines 877-892 including both the `grep -q "^---$"` branch and the
      `sed -i "1i${transition_comment}"` else-branch. *(completed)*
- [x] Leave the immediately preceding `Add entry to vault_history:` block **entirely unmodified**,
      including the `task_range="1-$((next_num - renumber_count - 1))"` line at ~855 and the
      `task_range` / `archived_count` / `final_task_number` fields — the schema divergence is
      explicitly deferred to a future task. *(completed: confirmed unchanged)*
- [x] Leave the following line `After sub-step 9.4 completes, continue to Stage 11
      (UpdateRoadmap).` unmodified — the deleted block was the tail of 9.4, not a sub-step of its
      own, so this cross-reference stays correct with no renumbering. *(completed: confirmed
      unchanged, line now immediately follows the vault_history block)*
- [x] Confirm the file still contains zero occurrences of `Vault transition`. *(completed:
      `grep -c` returns 0)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The deleted region is contained wholly within sub-step `9.4. ResetState`
and spans roughly lines 877-892, so no sub-step renumbering follows. Confirm at implementation
time by re-running `grep -n "9\.1\.\|9\.2\.\|9\.3\.\|9\.4\.\|Stage 11" ...SKILL.md` before and
after; the set of matched labels must be identical apart from line-number shift.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` - delete the transition-comment prose
  label and bash block from the tail of sub-step 9.4

**Verification**:
- `grep -c "Vault transition" agent-system/extensions/core/skills/skill-todo/SKILL.md` returns 0.
- `grep -n "transition_comment" ...SKILL.md` returns nothing.
- `grep -n "9\.4\. \*\*ResetState\|After sub-step 9.4 completes\|sub-steps 9.1-9.4" ...SKILL.md`
  still matches all three anchors.
- `grep -n "task_range\|vault_history" ...SKILL.md` still matches (deferred scope preserved).

---

### Phase 3: Acceptance — YAML parse, survivor accounting, dangling-reference sweep [COMPLETED]

**Goal**: Demonstrate the acceptance criteria by measurement and record the results, including a
justified survivor count for every remaining occurrence of the transition-comment string.

**Tasks**:
- [x] **Frontmatter parse (by parsing, not eyeballing)**: parse `specs/TODO.md`'s leading `---`
      block with a strict YAML loader (e.g. `python3` + `yaml.safe_load` over the extracted
      block) and record that it is a closed, valid YAML mapping whose keys are exactly the
      expected ones — specifically with **no** stray `<!-- Vault transition` key. Note in the
      output *why* the loader alone is insufficient evidence in general (the corrupted form
      parses successfully as a bogus key rather than erroring), so the check must assert on the
      key set, not merely on "no exception raised". *(completed: keys == ['next_project_number'],
      no stray key; see summary for parser output)*
- [x] **End-state simulation**: confirm the acceptance narrative holds — regenerate TODO.md via
      the sanctioned path (`bash .claude/scripts/generate-todo.sh`) and re-run the parse, showing
      the file is unchanged in the relevant respect (no transition comment present before or
      after, durable records untouched). Do not perform an actual vault operation. *(completed)*
- [x] **Durable-record check**: confirm `jq '.vault_history' specs/state.json` and
      `specs/vault/01-vault/meta.json` are both present and populated, i.e. Option (a) loses no
      information. *(completed: both present and populated)*
- [x] **Survivor grep — use `command grep`, not the shell `grep`**: this shell's `grep` is a
      ugrep shim invoked with `--ignore-files`, which honors `.gitignore` and therefore silently
      omits gitignored trees such as `.claude/**`. A naive repo-wide `grep -rln "Vault transition" .`
      under-reports. Run the accounting with `command grep -rn --exclude-dir=.git "Vault transition" .`
      (or with each directory named explicitly) and cross-check the `.claude/**` count with a
      targeted `command grep -c` on the two deployed files. *(completed)*
- [x] **Report the surviving count with justification for each survivor**, in these buckets:
      1. `agent-system/extensions/**` excluding `scripts/deprecated/**` — expected 0 (the
         acceptance target).
      2. `agent-system/extensions/core/scripts/deprecated/vault-operation.sh` — 1, retained by
         explicit scope decision (quarantined, zero live callers).
      3. `.opencode/**` — 5 files, deferred by explicit scope decision to the separately-tracked
         opencode-drift work; enumerate all five by path so none is silently forgotten.
      4. `.claude/**` — deployed copies, not source; not hand-edited per the binding source-store
         rule; self-correct on the next deploy/reload.
      5. `specs/**` — this task's own records plus archived historical artifacts; exempt and never
         edited retroactively.
      *(completed: measured 0 / 1 / 5 files / 2 files / 10 files respectively — matches all four
      numeric hypotheses; see summary for full table and per-bucket justification)*
- [x] **Dangling-reference sweep**: `command grep -rn "5\.8\." agent-system/extensions/` must
      return hits only under `scripts/deprecated/`; confirm `deprecated/README.md` still
      references only the heading ("Step 5.7") and needs no change. *(completed: all 8 hits
      confined to scripts/deprecated/vault-operation.sh's own comment labels; deviation —
      deprecated/README.md line 32 reads "Steps 5.7-5.8", a now-stale range reference the plan's
      risk-mitigation claim did not account for, undetected by the literal `5\.8\.` pattern
      because it lacks a trailing period; flagged as a follow-up in the summary, not fixed —
      outside this plan's approved file list)*
- [x] Run the repo's doc-lint gate `bash .claude/scripts/check-extension-docs.sh` and confirm no
      new failures are attributable to these edits. *(completed: all 20 extensions PASS)*
- [x] Write the execution summary to
      `specs/021_resolve_vault_transition_comment_nondurable/summaries/01_resolve-vault-transition-comment-summary.md`,
      including the survivor table and the parse evidence verbatim. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: Bucket 1 yields 0, bucket 2 yields 1, bucket 3 yields 5 files, bucket 4
yields 2 files. These are hypotheses inherited from the research report — and the report is
internally inconsistent about bucket 1 (its Executive Summary says 3, its survivor-accounting
section says 0). Confirm every bucket by running the grep and reporting the measured number; if a
measurement disagrees with a number above, report the measured value and explain the difference
rather than restating the plan's figure.

**Files to modify**:
- `specs/021_resolve_vault_transition_comment_nondurable/summaries/01_resolve-vault-transition-comment-summary.md` - new execution summary

**Verification**:
- `specs/TODO.md` frontmatter parses as a closed YAML mapping with the expected key set and no
  `<!-- Vault transition` key, demonstrated with the actual parser output.
- Measured survivor counts recorded for all five buckets, each with a written justification.
- No `5.8.` reference remains under `agent-system/extensions/` outside `scripts/deprecated/`.
- `check-extension-docs.sh` shows no new failures.

---

## Testing & Validation

- [ ] `specs/TODO.md` frontmatter parses via a strict YAML loader, asserting on the key set (not
      merely on the absence of an exception).
- [ ] `generate-todo.sh` regeneration leaves the intended end state (no transition comment,
      durable records intact).
- [ ] Zero occurrences of `Vault transition` in `agent-system/extensions/**` excluding
      `scripts/deprecated/**`.
- [ ] `commands/todo.md` vault substeps read `5.7.1`–`5.7.8` under the `### 5.7.` heading.
- [ ] `skill-todo/SKILL.md` sub-steps `9.1`–`9.4` and the `Stage 11` cross-references remain
      intact and accurate.
- [ ] `.vault_history[]` and `specs/vault/01-vault/meta.json` present and populated.
- [ ] `check-extension-docs.sh` passes with no new failures.
- [ ] No file under `.claude/**` or `.opencode/**` was hand-edited.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/commands/todo.md`
- Modified: `agent-system/extensions/core/skills/skill-todo/SKILL.md`
- New: `specs/021_resolve_vault_transition_comment_nondurable/summaries/01_resolve-vault-transition-comment-summary.md`
- Recorded (in the summary): the five-bucket survivor table and the frontmatter parse evidence
- Carried forward (not fixed here): the `.vault_history[]` schema divergence between the two
  documents, for a future task

## Rollback/Contingency

Both edits are deletions and renumberings in two markdown files under version control, with no
executable or state consequences until a vault operation next runs. To revert:
`git checkout HEAD -- agent-system/extensions/core/commands/todo.md agent-system/extensions/core/skills/skill-todo/SKILL.md`
(the working tree must be clean or the change committed first — see the destructive-git rule).
Contingency: if the concurrent repository-metrics work has restructured Section 5.6/5.7 such that
the Step 5.8.9 block or the substep headings cannot be matched unambiguously, stop and mark the
phase `[BLOCKED]` with the observed file state rather than guessing at a merge.
