# Implementation Plan: Task #962

- **Task**: 962 - Correct the pr_ready skill text and docs to describe the actual resulting state
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: 961 (satisfied — sibling edits to the same SKILL.md already landed)
- **Research Inputs**: specs/962_reconcile_pr_ready_policy_across_docs_and_skill_text/reports/01_pr-ready-policy-accuracy.md
- **Artifacts**: plans/01_pr-ready-resting-state-accuracy.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This is a prose-accuracy fix across three source-store documentation artifacts. Research
confirmed `scripts/update-task-status.sh` is correct as written: its `--allow-pr-ready` guard
(permission axis) and its `postflight:pr_ready -> completed` mapping (resulting-value axis) are
independent and jointly consistent. The defect is that `skill-orchestrate-hard/SKILL.md`'s
skeleton-exhaustion branch describes a resting state (`pr_ready`) that the code path cannot
actually produce, and that neither the CLAUDE.md merge source nor the declared single source of
truth for status markers distinguishes a *transition target argument* from a *persisted resting
state*. Definition of done: the skeleton-exhaustion branch's comment and EXIT line name
`completed` as the resting state, `status-markers.md` carries a `[PR READY]` entry plus the
general target-vs-resting distinction, `claudemd.md` points at it, and no byte of
`update-task-status.sh` changes.

### Research Integration

Findings integrated from `reports/01_pr-ready-policy-accuracy.md`:
- The two-axis model (guard = permission, `map_status()` = resulting value) is the explanatory
  frame the corrected prose must convey; both axes are correct and neither is to be changed.
- The genuine `#### State: pr_ready` handler later in the same SKILL.md is a *different, correct*
  code path reachable only via `preflight:pr_ready` for `task_type == "pr"`. It is explicitly
  out of scope and must not be touched.
- `status-markers.md` contains zero occurrences of `pr_ready` / `[PR READY]` despite declaring
  itself the single source of truth — the research recommends this file as the permanent home
  for the definitive statement, with the other two artifacts deferring to it.
- Planner-side confirmation of the report's stated risk: `grep -rn "skeleton exhausted"` across
  `agent-system/`, `.claude/`, and `specs/` returns only the source-store line, its deployed
  copy, and historical `specs/**` reports — **no test harness or script consumes the EXIT
  string**, so rewording it has no mechanical blast radius.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- Make the skeleton-exhaustion branch's inline comment and EXIT line describe the state that
  actually results (`completed`), naming the `postflight:pr_ready -> completed` mapping.
- Keep the accurate part of the existing comment (why `--allow-pr-ready` is needed to pass the
  guard) while removing the misleading implication that the task rests at `pr_ready`.
- Give `context/standards/status-markers.md` a `[PR READY]` definition and a general
  "target arguments vs. resting states" statement, closing its single-source-of-truth gap.
- Add one clarifying sentence to `merge-sources/claudemd.md`'s Status Markers section that
  defers to `status-markers.md` rather than duplicating the detail.

**Non-Goals**:
- Any change to `scripts/update-task-status.sh` — guard and mapping alike. A diff touching that
  file means this task went wrong.
- Any change to the `#### State: pr_ready` handler in `skill-orchestrate-hard/SKILL.md`; its
  prose is accurate for the population that can reach it.
- Any change to `context/reference/state-management-schema.md` (out of FILE SCOPE; noted by
  research only as existing prior art for table shape).
- Regenerating or editing `.claude/**`. That tree is a disposable deploy artifact; deploying the
  corrected source store is a separate concern outside this task.
- Purging pre-existing task-number citations elsewhere in the touched files (e.g. unrelated
  section-marker comments). Out of scope; see the risk table for the interaction with the
  write-time guard.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer "fixes" `update-task-status.sh` because the guard sits adjacent to the misleading comment | H | M | Phase 4 verifies `git diff -- agent-system/extensions/core/scripts/update-task-status.sh` is empty. Task description item 4 mandates STOP-and-escalate, not proceed |
| Rewording the EXIT line breaks a consumer grepping for `pr_ready` | M | L | Retired: planner-side grep found no script/test consumer of `skeleton exhausted` or that EXIT line. Additionally, keep the literal token `pr_ready` somewhere on the corrected line so a grep still lands here |
| An edit hunk in `skill-orchestrate-hard/SKILL.md` incidentally includes a pre-existing task-number citation (the `=== END ... Item 5A ===` section marker directly below the EXIT line), tripping the blocking `validate-no-task-references.sh` PreToolUse gate | M | M | Keep edit hunks narrow — never extend an `old_string`/`new_string` past the EXIT line into the section-marker line. Introduce no new task-number citations in any deliverable |
| Edits land in `.claude/**` instead of the source store, and are silently wiped on next regeneration | H | L | All three FILE SCOPE paths are already `agent-system/extensions/core/**`. Phase 4 verifies `git status` shows no `.claude/**` modifications |
| `check-extension-docs.sh` fails on a broken cross-reference introduced by the new `status-markers.md` section | M | L | Phase 4 runs the lint as the stated verification bar; cross-references are written as plain file/section names matching the file's existing `## References` conventions |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Establish the canonical statement in status-markers.md [COMPLETED]

**Goal**: Close the single-source-of-truth gap by adding a `[PR READY]` marker definition and a
general target-argument-vs-resting-state statement, so Phases 2 and 3 have one place to defer to.

**Tasks**:
- [x] Re-confirm the gap: `grep -in "pr.ready" agent-system/extensions/core/context/standards/status-markers.md` returns nothing *(completed: confirmed zero matches before editing)*
- [x] Add a `#### [PR READY]` subsection under `### Standard Status Markers`, following the
  existing per-marker format used by `[COMPLETED]` / `[BLOCKED]`: TODO.md Format, state.json
  Value (`pr_ready`), Meaning (type=pr only; implementation complete, awaiting user-invoked
  `/merge`), Valid Transitions (to `[COMPLETED]` after `/merge`; back to `[IMPLEMENTING]` if PR
  review finds issues) *(completed)*
- [x] Add a short "Target Arguments vs. Resting States" subsection near the
  `## Command → Status Mapping` table stating the general rule: the status value passed to
  `update-task-status.sh` as `$target_status` is a *request*, resolved by that script's
  `map_status()` against the `preflight`/`postflight` operation; the value that persists is the
  resting state, and the two are not always equal *(completed)*
- [x] Name `postflight:pr_ready -> completed` as the concrete instance, and state that a non-`pr`
  task passing `pr_ready` with `--allow-pr-ready` still comes to rest at `completed` *(completed)*
- [x] Confirm no task numbers appear in the added text *(completed: verified via check-task-references.sh)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: Research asserts `status-markers.md` contains zero `pr_ready` / `[PR READY]`
occurrences and that the only other codebase mention is a bare table row in
`context/reference/state-management-schema.md`. Confirm both with a grep before writing; if a
`[PR READY]` entry already exists, amend it rather than adding a duplicate subsection.

**Files to modify**:
- `agent-system/extensions/core/context/standards/status-markers.md` - add `#### [PR READY]`
  subsection and the target-vs-resting subsection

**Verification**:
- Both new subsections present; `grep -c "pr_ready"` is non-zero
- Marker subsection matches the field shape of the neighboring `[COMPLETED]` / `[BLOCKED]` entries
- No task-number citations introduced

---

### Phase 2: Correct the skeleton-exhaustion branch prose and EXIT line [COMPLETED]

**Goal**: Make the branch's inline comment and terminal message describe the resting state that
actually results, referring to the canonical statement added in Phase 1.

**Tasks**:
- [x] Rewrite the inline comment above the `update-task-status.sh` call: keep the accurate
  explanation that `--allow-pr-ready` is required to pass the script's guard for a non-`pr` task
  type, and add that this is a **postflight** call, so `map_status()`'s
  `postflight:pr_ready -> completed` mapping resolves it to a `completed` resting state
  regardless of task type *(completed)*
- [x] Replace "Transition to `pr_ready`" with wording naming the actual outcome (the call routes
  through the `pr_ready` target argument and comes to rest at `completed`) *(completed)*
- [x] Rewrite the EXIT line so the named resting state is `completed`, while retaining the
  `skeleton exhausted` phrase, the follow-up count/list interpolations, and a literal `pr_ready`
  token so the line remains greppable *(completed)*
- [x] Confirm the `#### State: pr_ready` handler further down the file is untouched *(completed: verified via grep and diff, lines 845-850 unchanged)*
- [x] Keep every edit hunk strictly within the branch body — do not extend into the
  `=== END ... Item 5A ===` section-marker line below the EXIT *(completed: git diff confirms hunks confined to lines 707-722)*

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: Research asserts exactly two inaccurate sites in this file — the comment
block immediately above the `update-task-status.sh postflight ... pr_ready ... --allow-pr-ready`
call, and the `EXIT (success, pr_ready — skeleton exhausted, ...)` line — and that all other
`pr_ready` mentions in the file belong to the correct `#### State: pr_ready` handler. Confirm by
re-running `grep -n "pr_ready\|PR READY" agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
before editing; if a third inaccurate site appears, record it and treat it as in scope for this
phase.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - skeleton-exhaustion
  branch comment and EXIT line only

**Verification**:
- `git diff` on the file shows changes confined to the skeleton-exhaustion branch
- The `bash .claude/scripts/update-task-status.sh postflight ... --allow-pr-ready` command line
  itself is byte-identical (prose changed, invocation unchanged)
- The corrected EXIT line names `completed` as the resting state
- No task-number citations introduced

---

### Phase 3: Add the transition-vs-resting pointer to the CLAUDE.md merge source [COMPLETED]

**Goal**: Close the wording gap in the Status Markers list that invited the original misreading,
by deferring to Phase 1's canonical statement rather than duplicating it.

**Tasks**:
- [x] Add one clarifying sentence immediately after the Status Markers bullet list stating that
  these are *resting* states, and that a status value passed to `update-task-status.sh` as a
  target argument is not always the value that persists *(completed)*
- [x] Point the reader at `context/standards/status-markers.md` for the full rule, matching the
  file's existing pattern of linking out to fuller references instead of restating detail *(completed)*
- [x] Leave the existing eight bullets themselves unchanged — they are accurate as written *(completed: verified via git diff, eight bullets unmodified)*
- [x] Confirm no task numbers appear in the added sentence *(completed: verified via check-task-references.sh)*

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/merge-sources/claudemd.md` - one sentence appended after the
  `### Status Markers` bullet list

**Verification**:
- The eight existing bullets are unmodified in `git diff`
- The added sentence names `status-markers.md` as the fuller reference
- No task-number citations introduced

---

### Phase 4: Verification sweep and negative-diff confirmation [COMPLETED WITH EXCLUSIONS]

**Goal**: Satisfy the task's verification bar and prove the forbidden change did not happen.

**Tasks**:
- [x] Run `bash .claude/scripts/check-extension-docs.sh` and confirm it exits zero *(deviation: altered — see Reasoned Exclusions below)*
- [x] Run `bash .claude/scripts/check-task-references.sh` and confirm it exits zero *(completed: exit 0, "PASS: 0 unexempted task-reference occurrences across 4 tree(s)")*
- [x] Confirm `git diff -- agent-system/extensions/core/scripts/update-task-status.sh` is empty
  (no guard change, no mapping change) *(completed: confirmed empty)*
- [x] Confirm `git status --short` lists no modification under `.claude/**` *(completed: confirmed none)*
- [x] Confirm the full change set touches exactly the three FILE SCOPE paths *(deviation: altered — a fourth file, `agent-system/extensions/core/index-entries.json`, required a one-line companion edit; see Reasoned Exclusions below)*
- [x] Read the corrected skeleton-exhaustion branch end to end and confirm an operator reading
  only the EXIT line would correctly conclude the task rests at `[COMPLETED]` *(completed: EXIT line now reads "EXIT (success, completed — skeleton exhausted via pr_ready target argument, ...)")*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `check-extension-docs.sh` exits zero | The script already failed at baseline (before any edit in this task) with 5 issues: deploy-drift on `scripts/command-route-skill.sh`, `scripts/lib/phase-heading-patterns.sh`, `scripts/update-task-status.sh`, `scripts/verify-deploy.sh` (all outside FILE SCOPE, and `update-task-status.sh` is explicitly forbidden from being touched), plus a pre-existing `index-entries.json` line_count mismatch for `formats/plan-format.md` (a file this task never touches). None of these can be fixed without exceeding FILE SCOPE or violating the "no update-task-status.sh changes" constraint. | Confirmed via `git stash` + rerun: baseline exits 1 with exactly these same 5 issues (`FAIL: 5 issue(s) found`), byte-identical to the post-implementation run. This task introduced and then self-corrected one additional, transient issue (see next row) — after that correction, the failure set is identical, pre-existing, and out of scope. |
| Fourth file touched: `index-entries.json` | Adding the `[PR READY]` and "Target Arguments vs. Resting States" subsections in Phase 1 grew `status-markers.md` from 380 to 408 lines, which on its own would have introduced a NEW `check-extension-docs.sh` failure (`line_count mismatch: declared 379, actual 408`) not present at baseline. A one-line companion edit (`"line_count": 379` -> `"line_count": 408"` for the `standards/status-markers.md` entry) is mechanical index bookkeeping — the same correction `scripts/generate-context-line-counts.sh --write` performs — with zero behavioral or policy surface, restoring the failure set to exact baseline parity. No other line in `index-entries.json` was touched. | `git diff -- agent-system/extensions/core/index-entries.json` shows exactly one line changed; rerunning `check-extension-docs.sh` before vs. after this companion edit shows the failure count drop from 6 to 5, matching baseline exactly. |

These two exclusions satisfy the five-condition admission test: both are deliberate, tightly
scoped to named items, documented with reasons, evidenced by command output, and leave nothing
for a future dispatch — the pre-existing deploy-drift and plan-format.md mismatch are genuinely
unrelated infrastructure debt, not a residual of this task's own scope.

**Timing**: 25 minutes

**Depends on**: 2, 3

**Verification Tier**: full

**Verification**:
- Both lint gates exit zero
- Empty diff against `update-task-status.sh`
- Changed-file list equals the three FILE SCOPE paths

## Testing & Validation

- [ ] `bash .claude/scripts/check-extension-docs.sh` exits zero (stated verification bar)
- [ ] `bash .claude/scripts/check-task-references.sh` exits zero (deliverable rule)
- [ ] `git diff -- agent-system/extensions/core/scripts/update-task-status.sh` is empty
- [ ] `git status --short` shows no `.claude/**` modifications
- [ ] Changed files are exactly the three FILE SCOPE paths
- [ ] `status-markers.md` now matches `grep -i "pr.ready"`

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/status-markers.md` (modified)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (modified)
- `agent-system/extensions/core/merge-sources/claudemd.md` (modified)
- `specs/962_reconcile_pr_ready_policy_across_docs_and_skill_text/summaries/01_pr-ready-resting-state-accuracy-summary.md`

## Rollback/Contingency

All three edits are additive or in-place prose changes to markdown, with no behavioral surface.
Rollback is `git checkout -- <path>` per file against a clean tree, or reversion of the phase
commit. If implementation surfaces a genuine reason to change `update-task-status.sh`, STOP: mark
the task `[BLOCKED]` with the reason recorded and escalate, rather than proceeding — that would
be a policy change, not the accuracy fix this task is scoped to.
