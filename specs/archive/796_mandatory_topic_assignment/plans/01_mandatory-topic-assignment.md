# Implementation Plan: Task #796

- **Task**: 796 - mandatory_topic_assignment
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: None (task 787 COMPLETE, no line/section overlap confirmed by research)
- **Research Inputs**: specs/796_mandatory_topic_assignment/reports/01_mandatory-topic-assignment.md
- **Artifacts**: plans/01_mandatory-topic-assignment.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Make topic assignment mandatory across every task-creation path so a new task can never land
in "Uncategorized". The research confirmed three escape hatches: (Mode A) a literal
"Skip (no topic)" option in the canonical picker and its inline duplicates; (Mode B) a
doc/impl divergence where `/task --expand` and `/spawn` already ship fallback pickers with Skip
while `/task --recover` has zero topic handling; and (Mode C) a silent `topic=""` no-op in
`/review` and `/fix-it` when the path heuristic misses. The fix rewrites the canonical
`topic-assignment-pattern.md` so Mode A becomes the universal fallback with no Skip, then
updates all six caller files (each dual-copied to `extensions/core/`) to inherit or wire that
fallback, adds a defense-in-depth stderr warning to `generate-task-order.sh`, and verifies no
Skip string survives in any new-task path. Definition of done: no "Skip (no topic)" reachable
from any new-task-creation path, `--recover` gains a topic check, `--sync` retains a single
explicitly-labeled deferral affordance, all dual copies byte-identical, and topicless tasks
surface loudly at TODO generation time. Backfilling existing topicless tasks is out of scope.

### Research Integration

- Six caller files confirmed dual-copy with byte-identical `extensions/core/` mirrors;
  `topic-assignment-pattern.md` has NO mirror (single source). `generate-task-order.sh` HAS a
  mirror. Verified live: task.md (6), skill-spawn (3), skill-project-overview (3), review.md (2),
  skill-fix-it (2), pattern doc (3) occurrences of "Skip (no topic)"; meta-builder-agent has 0
  (pure delegation, inherits the doc fix).
- No line-range collision with completed task 787 (787 touched Stage 3 file-scope / Component-4a
  regions, not topic sections).
- `errors.md` needs NO edit: it creates tasks via `/task`, inheriting the create-path fix.
- `manage-topics.sh` (`list`/`add`/`set`/`validate`) remains the sole state-mutation path; no
  inline jq topic writes are introduced.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this dispatch (roadmap_flag not set).

### Decisions (required by task)

**Decision (a) — Remove Skip entirely vs. keep a hard-to-reach explicit skip.**
Chosen: **Remove Skip from every new-task-creation path** (canonical Mode A template, Mode A
inline duplicate in `skill-project-overview`, Mode A batch delegation in `meta-builder-agent`,
Mode B fallbacks in `--expand`/`--recover`/`skill-spawn`, Mode C confirm-wraps in
`review.md`/`skill-fix-it`). **Retain exactly one explicitly-labeled deferral option — worded
as "Defer (leave uncategorized for now)", NOT "Skip" — ONLY in `/task --sync`'s backfill loop.**
Rationale: Task 796's guarantee is about *new* task creation; every Skip on a creation path is
exactly the in-scope bypass and is removed. `--sync` is the designated remediation path for
*pre-existing* gaps (out of 796's scope); blanket-removing its deferral would trap a user who
re-runs `--sync` against an old backlog they are not ready to categorize. A single, clearly
labeled "Defer" affordance there is a remediation-pacing control, not a creation bypass — and
the Phase 6 warning keeps those deferred tasks visible until categorized.

**Decision (b) — Defense-in-depth: warning in `generate-task-order.sh` vs. new validation script.**
Chosen: **stderr warning in the existing `generate-task-order.sh` Uncategorized block
(lines ~490-515)**. Rationale: lower effort, no new surface area, consistent with the codebase's
established non-fatal `Warning: ... (non-fatal)` convention, and fires on every
`generate-todo.sh` invocation (`/todo`, `/task --sync`, any status change) — satisfying 796's
"bypasses surface loudly" framing without introducing a new script/subcommand. The existing
`manage-topics.sh validate` (topic-string validity) is left unchanged; this is task-coverage
visibility, a distinct concern.

## Goals & Non-Goals

**Goals**:
- Rewrite `topic-assignment-pattern.md`: drop Skip from Mode A; make Mode A the universal
  fallback for parent-none / heuristic-miss / batch-null; keep "New topic..." always available;
  reconcile the Mode B "no fallback picker" divergence into "call Mode A as universal fallback";
  Mode C heuristic-miss routes to Mode A. Keep mode letters/headings A/B/C stable so caller
  `@`-references still resolve.
- Update all six caller files (both copies each) to remove Skip and wire the universal fallback,
  including adding a net-new `.topic` null/empty check to `/task --recover`.
- Retain a single labeled "Defer" option in `/task --sync` backfill per Decision (a).
- Add the Phase 6 stderr warning per Decision (b).
- Keep every dual-copy pair byte-identical (`diff -q` clean).

**Non-Goals**:
- Backfilling existing topicless tasks (handled by `/task --sync`; unchanged in mechanism).
- Renaming modes or restructuring the three-mode table (would break caller cross-references).
- A new validation script/subcommand or a doc-lint drift check (noted as out-of-scope follow-up
  in the research; not implemented here).
- Editing `errors.md` (inherits via `/task` create) or repurposing `manage-topics.sh validate`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Doc rewrite breaks caller `@`-references by mode name | H | M | Keep `Mode A: Interactive`, `Mode A: Interactive, batch variant`, `Mode B: Inherit`, `Mode C: Suggest` headings verbatim; change only picker content and the Mode B "no fallback" line. Phase 7 greps caller `@`-refs against surviving headings. |
| Dual-copy drift (edit one copy, forget mirror) | H | M | Every caller phase edits BOTH copies then runs `diff -q project core`; Phase 7 re-diffs all seven pairs as a final gate. |
| `--recover` under-scoped (has zero topic code today, easy to skip) | M | M | Phase 2 explicitly calls for ADDING a `.topic == null or == ""` check + fallback picker invocation; called out as net-new, not a fix of existing code. |
| `--sync` Skip blanket-removed, trapping backlog remediation | M | L | Decision (a) carve-out: retain a labeled "Defer" option in `--sync` only; Phase 7 asserts `--sync` still offers deferral while no other path does. |
| Mode C confirm-wrap partially fixed (Skip dropped but empty-heuristic no-op left silent) | M | M | Phase 4 requires BOTH parts: drop Skip from confirm-wrap AND route empty `inferred_topic` to Mode A fallback (not `topic=""`). |
| Warning added to only one copy of `generate-task-order.sh` | M | L | Phase 6 edits both copies and `diff -q`. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 6 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 7 | 1, 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel. Phases 2-5 touch disjoint file sets and
all depend only on Phase 1, so they are safe to parallelize (explicit territory below). Phase 6
is independent of the doc rewrite and can run in Wave 1.

### Phase 1: Rewrite canonical topic-assignment-pattern.md [COMPLETED]

**Goal**: Make the single canonical doc the universal, Skip-free source of truth so every
`@`-referencing caller inherits the fix.

**Tasks**:
- [x] In Mode A (Interactive) picker template: remove the "Skip (no topic)" option from the
      AskUserQuestion option set; keep existing-topics list and "New topic..." (always available). *(completed)*
- [x] Add an explicit statement that Mode A is the **universal fallback** invoked whenever a
      topic cannot be inherited or inferred (parent has no topic / heuristic miss / batch null). *(completed)*
- [x] Rewrite the Mode B (Inherit) fallback line (currently ~line 113: "no fallback picker in
      current implementation") to instruct: if the parent/source has no topic, invoke Mode A as
      the universal fallback (no Skip). *(completed)*
- [x] Rewrite Mode C (Suggest) so the `other -> (no topic assigned)` / silent branch (~line 134)
      instead routes to the Mode A universal fallback; document the confirm-wrap without a Skip
      option (Accept / Override / — no Skip). *(completed)*
- [x] Preserve mode letters and headings verbatim (`Mode A: Interactive`,
      `Mode A: Interactive, batch variant`, `Mode B: Inherit`, `Mode C: Suggest`) and the
      three-mode table structure; preserve the `manage-topics.sh`-only mutation guidance. *(completed)*
- [x] Note in the doc that `/task --sync` backfill is the sole path permitted an explicit
      "Defer" affordance (cross-reference to Decision (a)), so future edits do not re-add Skip. *(completed)*

**Timing**: ~1 hour

**Depends on**: none

**Files to modify**:
- `.claude/context/patterns/topic-assignment-pattern.md` — full rewrite of Mode A/B/C content
  (single copy, no `extensions/core/` mirror).

**Verification**:
- `grep -c "Skip (no topic)" .claude/context/patterns/topic-assignment-pattern.md` returns 0.
- Mode headings unchanged (grep for each of the four heading strings still matches).
- Doc explicitly names Mode A as universal fallback and Mode B/C route to it.

---

### Phase 2: Update /task create, --expand, --recover, --sync (task.md) [COMPLETED]

**Goal**: Close Mode A create, the Mode B `--expand` inline-Skip duplicate, and the
`--recover` zero-handling gap; retain a labeled Defer in `--sync` only.

**Tasks**:
- [x] **create** (task.md ~189-197): confirm the `@`-reference to Mode A still resolves to the
      rewritten section; no Skip text remains inline (grep). No behavioral edit expected beyond
      confirming inheritance. *(completed: also clarified the now-stale "not null/skipped" jq
      comment)*
- [x] **--expand** (~322-359): replace the inline Mode A-style picker WITH Skip with an explicit
      reference to the rewritten Mode A universal-fallback section (parent-topic-empty case);
      remove the inline "Skip (no topic)" option. *(completed: also fixed the equivalent
      Skip picker in Review Mode Step 7.6, not explicitly named in this task but caught by the
      Phase 7 grep gate)*
- [x] **--recover** (~248-306): ADD a check on the recovered `$task_data` — if
      `.topic == null or .topic == ""`, invoke the Mode A universal fallback picker before the
      task returns to `active_projects` (net-new code; recover has no topic handling today). *(completed)*
- [x] **--sync backfill** (~413-433): keep the per-task Mode A picker but replace/retain a single
      option labeled "Defer (leave uncategorized for now)" (NOT "Skip (no topic)") per Decision
      (a); ensure it is the only deferral affordance in the whole task surface. *(completed)*
- [x] Apply every edit to BOTH `.claude/commands/task.md` and
      `.claude/extensions/core/commands/task.md`; then `diff -q` the pair. *(completed)*

**Timing**: ~1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/commands/task.md` and `.claude/extensions/core/commands/task.md` (byte-identical).

**Verification**:
- `grep -c "Skip (no topic)" .claude/commands/task.md` returns 0.
- `--sync` section contains exactly one "Defer (leave uncategorized for now)" option.
- `--recover` section references a `.topic` null/empty check invoking Mode A fallback.
- `diff -q .claude/commands/task.md .claude/extensions/core/commands/task.md` is clean.

---

### Phase 3: Update meta-builder-agent.md Stage 4.5 + Stage 6 [COMPLETED]

**Goal**: Confirm the batch Mode A delegation inherits the Skip-free doc and tidy now-dead
`batch_topic` nullability guards.

**Tasks**:
- [x] Stage 4.5 (~577-585): confirm the "Follow @...topic-assignment-pattern.md (Mode A:
      Interactive, batch variant)" delegation still resolves; no inline Skip to remove (grep
      confirms 0 today) — verify the plural-wording note is intact. *(completed: added a
      mandatory-assignment clarification sentence)*
- [x] Stage 6 topic write (~715, 734) and `4b. Update active_topics` (~1345-1360): simplify the
      "omit if null/skipped" comment/guard now that `batch_topic` is non-null by construction
      (Skip removed). Keep any defensive `if null then del` only if genuinely harmless; document
      the assumption change in a comment. This is a low-risk clarity edit, not a behavior change. *(completed)*
- [x] Apply to BOTH `.claude/agents/meta-builder-agent.md` and
      `.claude/extensions/core/agents/meta-builder-agent.md`; then `diff -q`. *(completed)*

**Timing**: ~0.75 hour

**Depends on**: 1

**Files to modify**:
- `.claude/agents/meta-builder-agent.md` and
  `.claude/extensions/core/agents/meta-builder-agent.md` (byte-identical).

**Verification**:
- `grep -c "Skip (no topic)" .claude/agents/meta-builder-agent.md` returns 0 (already 0; confirm).
- Stage 4.5 delegation heading reference matches a surviving Phase 1 heading.
- `diff -q` on the pair is clean.

---

### Phase 4: Update Mode C callers — review.md + skill-fix-it/SKILL.md [COMPLETED]

**Goal**: Remove the Mode C Skip option AND eliminate the silent `topic=""` no-op on
heuristic miss in both structurally-identical callers.

**Tasks**:
- [x] **review.md** (~505-580): (a) drop "Skip (no topic)" from the confirm-wrap picker (keep
      Accept / Override); (b) when `inferred_topic` is empty (the "other" branch, ~553), invoke
      the Mode A universal fallback picker instead of `set topic=""`. *(completed)*
- [x] **skill-fix-it/SKILL.md** (~469-536): same two-part fix (~503 empty branch). Use the Mode
      A **batch variant** (plural wording) since this runs per `topic_groups[]` entry. *(completed)*
- [x] Apply each edit to BOTH copies:
      `.claude/commands/review.md` + `.claude/extensions/core/commands/review.md`, and
      `.claude/skills/skill-fix-it/SKILL.md` +
      `.claude/extensions/core/skills/skill-fix-it/SKILL.md`; `diff -q` each pair. *(completed)*

**Timing**: ~1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/commands/review.md` (+ core mirror).
- `.claude/skills/skill-fix-it/SKILL.md` (+ core mirror).

**Verification**:
- `grep -c "Skip (no topic)"` returns 0 for both project files.
- Neither file sets `topic=""` on the empty-heuristic branch; both route to Mode A fallback.
- `diff -q` clean for both pairs.

---

### Phase 5: Update Mode B skill-spawn + Mode A skill-project-overview [COMPLETED]

**Goal**: Close the `/spawn` doc/impl divergence and the `skill-project-overview` inline Mode A
Skip.

**Tasks**:
- [x] **skill-spawn/SKILL.md** (~55-83): replace the inline Mode A-style picker WITH Skip
      (parent-topic-empty case) with a reference to the rewritten Mode A universal fallback;
      remove the "Skip (no topic)" option (3 occurrences). *(completed: also updated Stage 14a's
      now-defensive-only `-n parent_topic` guard comment)*
- [x] **skill-project-overview/SKILL.md** (~355-420): remove the inline "Skip (no topic)" option
      directly (this picker does NOT `@`-reference the doc, so it needs a direct edit); keep
      existing-topics + "New topic..."; optionally add a "Follow @...topic-assignment-pattern.md
      (Mode A)" reference to prevent future drift. *(completed)*
- [x] Apply each to BOTH copies:
      `.claude/skills/skill-spawn/SKILL.md` (+ core mirror) and
      `.claude/skills/skill-project-overview/SKILL.md` (+ core mirror); `diff -q` each pair. *(completed)*

**Timing**: ~1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-spawn/SKILL.md` (+ core mirror).
- `.claude/skills/skill-project-overview/SKILL.md` (+ core mirror).

**Verification**:
- `grep -c "Skip (no topic)"` returns 0 for both project files.
- `diff -q` clean for both pairs.

---

### Phase 6: Defense-in-depth warning in generate-task-order.sh [COMPLETED]

**Goal**: Surface any topicless task loudly at TODO-generation time per Decision (b).

**Tasks**:
- [x] In the existing Uncategorized fallback block (~490-515), after collecting the
      uncategorized task list, if the count is > 0 emit a non-fatal `stderr` warning matching the
      codebase's `Warning: ... (non-fatal)` convention, listing the topicless task numbers (e.g.
      `Warning: N task(s) have no topic and will render under Uncategorized: 12, 34 (non-fatal)`). *(completed)*
- [x] Do NOT block or alter rendering output; warning is informational only. *(completed: verified
      via synthetic-task test — stdout of `--print` unchanged, warning only on stderr, exit 0)*
- [x] Apply to BOTH `.claude/scripts/generate-task-order.sh` and
      `.claude/extensions/core/scripts/generate-task-order.sh`; `diff -q` the pair. *(completed)*

**Timing**: ~0.5 hour

**Depends on**: none

**Files to modify**:
- `.claude/scripts/generate-task-order.sh` (+ core mirror).

**Verification**:
- With a synthetic topicless task present, `bash .claude/scripts/generate-todo.sh` writes the
  warning to stderr and still regenerates TODO.md successfully (exit 0).
- `diff -q` clean for the pair.

---

### Phase 7: Verification and reconciliation [COMPLETED]

**Goal**: Prove the guarantee holds and no dual-copy drift was introduced.

**Tasks**:
- [x] `grep -rn "Skip (no topic)"` across `.claude/` returns hits ONLY (if any) in archival/doc
      contexts, and ZERO in any new-task-creation path (task create/expand/recover, review,
      fix-it, spawn, project-overview, meta-builder, pattern doc). *(completed: grep returns 0
      hits system-wide, including 0 in `.claude/extensions/literature/skills/skill-cite/SKILL.md`
      — see Plan Deviations, a 7th creation path not enumerated in the original plan/research but
      caught by this exact verification gate and fixed)*
- [x] Confirm `/task --sync` retains exactly one "Defer (leave uncategorized for now)" option and
      no other path offers deferral. *(completed: `Defer (leave uncategorized for now)` appears
      only in task.md/core mirror (--sync section) and the pattern doc's documentation of the
      exception)*
- [x] `diff -q` all seven dual-copy pairs (task.md, review.md, meta-builder-agent.md,
      skill-fix-it, skill-spawn, skill-project-overview, generate-task-order.sh) — all clean. *(completed: all 7 CLEAN)*
- [x] Grep caller `@`-references to `topic-assignment-pattern.md` and confirm each named mode
      heading still exists in the rewritten doc (no dangling references). *(completed: all
      references cite "Mode A: Interactive" or "Mode A: Interactive, batch variant", both
      confirmed present)*
- [x] Confirm `errors.md` still requires no edit (grep: no independent topic handling) and
      `manage-topics.sh validate` unchanged. *(completed: errors.md untouched, delegates to
      /task; manage-topics.sh has zero git diff)*
- [x] Sanity-run `generate-todo.sh` to confirm the Phase 6 warning path executes without error. *(completed:
      exit 0, warning fires correctly on a synthetic active topicless task in an isolated test,
      real state.json restored byte-identical after test)*

**Timing**: ~0.5 hour

**Depends on**: 1, 2, 3, 4, 5, 6

**Verification**:
- All greps and `diff -q` checks pass; TODO.md regenerates cleanly.

## Testing & Validation

- [x] `grep -rn "Skip (no topic)" .claude/` shows zero hits on any new-task-creation path.
- [x] `diff -q` clean on all seven dual-copy file pairs.
- [x] Pattern doc: 0 "Skip (no topic)", all four mode headings intact, Mode A named universal
      fallback, Mode B/C route to it.
- [x] `/task --recover` has an added `.topic` null/empty check invoking Mode A fallback.
- [x] `/task --sync` retains exactly one labeled "Defer" option; no other path has deferral.
- [x] `generate-todo.sh` emits the topicless warning to stderr when a topicless task exists and
      exits 0.
- [x] Caller `@`-references to the pattern doc all resolve to surviving mode headings.

## Artifacts & Outputs

- plans/01_mandatory-topic-assignment.md (this file)
- Rewritten `.claude/context/patterns/topic-assignment-pattern.md`
- Edited (both copies): task.md, review.md, meta-builder-agent.md, skill-fix-it/SKILL.md,
  skill-spawn/SKILL.md, skill-project-overview/SKILL.md, generate-task-order.sh
- summaries/01_mandatory-topic-assignment-summary.md (on implementation)

## Rollback/Contingency

All changes are documentation/markdown and one shell warning; no data migration. To revert,
`git checkout` the affected files (pattern doc, six caller pairs, generate-task-order.sh pair).
Because Phase 1 is the semantic keystone, if a caller phase reveals the doc rewrite broke an
`@`-reference, fix forward by restoring the exact mode heading in Phase 1's output rather than
reverting caller edits. If the Phase 6 warning proves noisy, it is non-fatal and can be
gated/removed independently without affecting the Skip-removal guarantee.
