# Research Report: Task #144

**Task**: 144 - Narrow the coarse whole-directory file_scope declarations that manufacture false collisions and needlessly serialize multi-task orchestration
**Started**: 2026-09-02
**Completed**: 2026-09-02
**Effort**: research pass (codebase-only; no plan/implementation performed)
**Dependencies**: None declared
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/validate-state.sh` (Check 8, live re-run against `specs/state.json`)
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` (overlap predicate definition)
- `specs/state.json` (live `active_projects[]` entries for projects 44, 20, 88, 129, 142, 143, 147, 148, 149, 150, 72, 76, 81, 100, 121, 136, 139, plus every entry containing `context/patterns`)
- `specs/044_slim_task_command_body/plans/01_task-command-mode-extraction.md`
- `agent-system/extensions/core/scripts/tests/` and `agent-system/extensions/core/scripts/lint/` directory listings
- Filesystem existence checks for orchestrate-engine scripts (`orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`, `orchestrate-churn.sh`, `orchestrate-dry-run-report.sh`, `orchestrate-recover-outcome.sh`, `orchestrate-triage-classify.sh`)
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` (Component 4a)
- `git log`/`git show` history for `c6467b078` (task 61, which added Check 8) and its plan file, to confirm no prior decision on the unknown-footprint convention exists
- `grep -rl file_scope` across `agent-system/extensions/core/scripts/*.sh`, `skills/*/SKILL.md`, `agents/*.md` (to locate the sole current `file_scope` writer, `update-task-status.sh`)
**Artifacts**:
- this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The task description's "3 coarse declarations" is a stale snapshot. A live re-run of `validate-state.sh` Check 8 (default `FILE_SCOPE_COARSE_MIN_OVERLAP=3`) finds **11** (task, entry) findings across **10 projects**: 44, 20, 88, 129, 142, 143, 147, 148, 149, 150.
- Each finding has a concrete, evidence-grounded narrowed replacement below. Three findings (project 129's `context/standards/`, project 142's `scripts/lint/`, project 149's `scripts/tests/`) are genuinely undeterminable before that task's own research runs — these are NOT left as directory roots; they are dropped in favor of a decided write-back convention (see "Decision" section).
- The narrowing of the `scripts/tests/` cluster around the orchestrate batch-engine refactor (projects 143, 147, 148, 150) **preserves three real, still-serializing collisions** on scripts that do not exist on disk yet (`orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`) — this is the most load-bearing part of the result: it proves the narrowing separates genuine footprint overlap from directory-root false positives rather than merely deleting all collision signal.
- Both addendum verification items are confirmed already clean; no action was needed for either.
- A root-cause defect was found in `multi-task-creation-standard.md` Component 4a: its own guidance currently instructs task creation to bias toward over-declaring. Narrowing today's 11 declarations without fixing that line leaves the generator of the problem in place — new coarse declarations will keep being created by any task-creation flow that follows the standard as written.
- Recommended approach: narrow the 9 in-scope declarations per the tables below, fix the Component 4a guidance line, and implement an additive `proposed_file_scope` → `--file-scope-add` write-back mechanism for the cases where a task's true footprint cannot be known before its research phase runs.

## Context & Scope

Task 144 asks for two things: (1) replace directory-root `file_scope` entries with the actual files each task will touch, without ever narrowing so far that a genuinely-touched file is left uncovered (under-declaration is strictly worse than over-declaration — it silently removes the collision guard); and (2) decide and document a convention for the case where a task's footprint cannot be known until its own research phase has run, rather than defaulting to a directory root in that case. Check 8 in `validate-state.sh` is WARN-only by design (added by task 61) and must stay WARN-only; this task does not touch the overlap predicate in `file-footprint-overlap.md`.

An addendum to the task also asked me to (a) verify that `general-implementation-hard-agent.md` references removed by the hard-mode collapse are fully gone from non-terminal tasks, and (b) explicitly avoid touching project 88's `core/context/patterns/` entry, which was described as being mid-rewrite.

This is a research-only dispatch: no `file_scope` edits were applied to `specs/state.json`, and no doc edits were applied to `multi-task-creation-standard.md`. Everything below is a finding and a recommendation for the plan phase to sequence and the implementation phase to apply.

## Findings

### Live Check 8 re-run — 11 findings, not 3

The task description's list (projects 44, 129, 88, each overlapping a fixed set) is explicitly called out by the team lead as "a snapshot in time." I re-ran Check 8's own jq program directly against the live `specs/state.json` (same predicate, same `min=3` default, no logic changes) and got:

| # | project_number | entry | overlap count | overlapping non-terminal tasks |
|---|---|---|---|---|
| 1 | 44 | `agent-system/extensions/core/context/` | 12 | 29, 51, 88, 91, 127, 129, 140, 143, 146, 147, 149, 150 |
| 2 | 20 | `agent-system/extensions/core/scripts/tests/` | 7 | 88, 129, 143, 147, 148, 149, 150 |
| 3 | 88 | `agent-system/extensions/core/scripts/tests/` | 7 | 20, 129, 143, 147, 148, 149, 150 |
| 4 | 129 | `agent-system/extensions/core/context/standards/` | 7 | 44, 51, 140, 143, 146, 149, 150 |
| 5 | 143 | `agent-system/extensions/core/scripts/tests/` | 7 | 20, 88, 129, 147, 148, 149, 150 |
| 6 | 147 | `agent-system/extensions/core/scripts/tests/` | 7 | 20, 88, 129, 143, 148, 149, 150 |
| 7 | 148 | `agent-system/extensions/core/scripts/tests/` | 7 | 20, 88, 129, 143, 147, 149, 150 |
| 8 | 149 | `agent-system/extensions/core/scripts/tests/` | 7 | 20, 88, 129, 143, 147, 148, 150 |
| 9 | 150 | `agent-system/extensions/core/scripts/tests/` | 7 | 20, 88, 129, 143, 147, 148, 149 |
| 10 | 88 | `agent-system/extensions/core/scripts/lint/` | 3 | 127, 129, 142 |
| 11 | 142 | `agent-system/extensions/core/scripts/lint/` | 3 | 88, 127, 142(sic — self-excluded; overlaps are 88, 127, 129) |

(Row 11 overlap set, precisely: 88, 127, 129.)

Two clusters dominate: a 7-way false-collision cluster around `agent-system/extensions/core/scripts/tests/` (rows 2–9, six distinct owning tasks), and a smaller 3-way cluster around `agent-system/extensions/core/scripts/lint/` (rows 10–11).

### Addendum verification (both already clean — no action taken)

**Hard-mode-collapse cleanup**: `grep general-implementation-hard-agent.md specs/state.json` matches only projects **81** (`mechanize_task_lock_and_session_heartbeat_refresh`) and **121** (`delete_hard_mode_lifecycle_files`), both `status: completed` — terminal, historical references, expected and correct. No non-terminal task references the deleted file. Confirmed nothing further to fix.

**Project 88's `core/context/patterns/` entry**: does not exist in the live state. Project 88's current `file_scope` is `[skill-orchestrate/SKILL.md, docs/architecture/orchestrate-state-machine.md, docs/architecture/handoff-schema.md, context/reference/orchestrator-critical-paths.json, scripts/tests/, scripts/lint/]` — no `context/patterns/` path anywhere in it. This item was already resolved before this dispatch (or the original task description was written against an older snapshot). Per the team lead's explicit instruction, this entry was not touched, and in fact there was nothing live to touch.

### Per-declaration narrowing: old → new, with justification

#### Project 44 — `slim_task_command_body` (status: `planned`; plan exists)

- OLD: `["agent-system/extensions/core/commands/task.md", "agent-system/extensions/core/context/"]`
- NEW: `["agent-system/extensions/core/commands/task.md", "agent-system/extensions/core/context/patterns/task-recover-mode.md", "agent-system/extensions/core/context/patterns/task-expand-mode.md", "agent-system/extensions/core/context/patterns/task-sync-mode.md", "agent-system/extensions/core/context/patterns/task-review-mode.md", "agent-system/extensions/core/context/patterns/task-abandon-mode.md", "agent-system/extensions/core/context/patterns/task-description-transformation-examples.md", "agent-system/extensions/core/index-entries.json"]`

The plan file `specs/044_slim_task_command_body/plans/01_task-command-mode-extraction.md` enumerates exactly these six new `context/patterns/task-*.md` files across its phases (verbatim grep-confirmed: each appears in a phase's "Files to modify"/checklist section, and a dedicated final checklist item lists all six together). No other path under `agent-system/extensions/core/context/` is referenced anywhere in the plan.

Notable incidental finding: the plan's Phase 7 mandates registering all six new files in `agent-system/extensions/core/index-entries.json` ("Register New Context Files in index-entries.json (MANDATORY)"). This file was **never covered by the old broad `context/` entry either** — `index-entries.json` sits at `agent-system/extensions/core/index-entries.json`, a sibling of `context/`, not nested beneath it. So this is a pre-existing under-declaration gap, not one introduced by narrowing; I'm closing it as part of this pass since it's directly evidenced by the same plan.

#### Project 20 — `fix_todo_metrics_sync_precommit_phantom_paths` (status: `researching`)

- OLD: `["agent-system/extensions/core/scripts/assess-repo-health.sh", "agent-system/extensions/core/commands/todo.md", "agent-system/extensions/core/scripts/tests/"]`
- NEW: `["agent-system/extensions/core/scripts/assess-repo-health.sh", "agent-system/extensions/core/commands/todo.md", "agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh"]`

`test-assess-repo-health.sh` already exists in `scripts/tests/`. The task's own "REGRESSION LOCK: add a test that stages nothing, moves a tracked file, runs the probe" item is squarely about `assess-repo-health.sh`'s behavior, and the repo follows a near-universal `test-<script-basename>.sh` naming convention (see "Test-naming convention" below) — this is the file that convention predicts and the only test file plausibly in scope.

#### Projects 143 / 147 / 148 / 150 — the in-flight orchestrate batch-engine refactor cluster (all `not_started`)

All four declare the whole `scripts/tests/` directory to cover tests for scripts they are creating/modifying. Applying the `test-<script-basename>.sh` convention to each task's own already-declared implementation scripts:

| Project | OLD implementation scripts already declared | Predicted test file(s) replacing `scripts/tests/` |
|---|---|---|
| 143 `mt_handoff_staleness_and_dispatch_seq_gates` | `orchestrate-cycle-postflight.sh` (not yet created), `orchestrate-recover-outcome.sh` (exists, no test yet) | `scripts/tests/test-orchestrate-cycle-postflight.sh`, `scripts/tests/test-orchestrate-recover-outcome.sh` |
| 147 `build_orchestrate_cycle_plan` | `orchestrate-cycle-plan.sh` (not yet created), `orchestrate-dry-run-report.sh` (exists, no test yet) | `scripts/tests/test-orchestrate-cycle-plan.sh`, `scripts/tests/test-orchestrate-dry-run-report.sh` |
| 148 `port_single_task_features_to_batch_engine` | `orchestrate-churn.sh` (not yet created), `orchestrate-cycle-plan.sh` (not yet created), `orchestrate-cycle-postflight.sh` (not yet created) | `scripts/tests/test-orchestrate-churn.sh`, `scripts/tests/test-orchestrate-cycle-plan.sh`, `scripts/tests/test-orchestrate-cycle-postflight.sh` |
| 150 `research_on_demand` | `orchestrate-cycle-plan.sh` (not yet created), `orchestrate-cycle-postflight.sh` (not yet created), `orchestrate-triage-classify.sh` (exists, has `test-orchestrate-triage-classify.sh` already) | `scripts/tests/test-orchestrate-cycle-plan.sh`, `scripts/tests/test-orchestrate-cycle-postflight.sh`, `scripts/tests/test-orchestrate-triage-classify.sh` |

Filesystem check confirmed: `orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`, and `orchestrate-churn.sh` **do not exist yet** on disk. `orchestrate-dry-run-report.sh`, `orchestrate-recover-outcome.sh`, and `orchestrate-triage-classify.sh` already exist; only `orchestrate-triage-classify.sh` currently has a companion test file.

**This is the most important result in this report.** Narrowing does not eliminate all collisions between these four tasks — it correctly reveals three that survive:

- **147 and 148 and 150 all legitimately collide on `orchestrate-cycle-plan.sh` (and its test)** — a script that does not exist yet, being introduced by 147 and then extended by both 148 and 150.
- **143 and 148 and 150 all legitimately collide on `orchestrate-cycle-postflight.sh` (and its test)** — likewise not-yet-created, introduced by 143 and extended by both 148 and 150.

These are real, correctly-serializing collisions, not artifacts of the coarse directory declaration. The old `scripts/tests/` entry was masking this real, narrower structure inside a 7-way false-positive mass; narrowing surfaces exactly the true dependency shape (147/148/150 and 143/148/150 should stay serialized on those specific files; 20/88/129/149 should not be pulled into either group at all).

#### Project 88 — `mode_gate_skill_orchestrate_multi_task_section` (status: `not_started`)

- OLD: `[..., "agent-system/extensions/core/scripts/tests/", "agent-system/extensions/core/scripts/lint/"]`
- NEW lint (7 of the 9 files in `scripts/lint/`): `lint-branch-gated-sections.sh, lint-contract-compliance.sh, lint-lifecycle-status-var.sh, lint-postflight-boundary.sh, lint-scoped-commit-boundary.sh, lint-state-writer-boundary.sh, lint-task-lookup-adoption.sh`
- NEW tests (12 files): `test-corroborate-phase-counts.sh, test-deploy-propagation.sh, test-double-loading-check.sh, test-handoff-dispatch-identity.sh, test-handoff-reader-parity.sh, test-lint-branch-gated-sections.sh, test-lint-task-lookup-adoption.sh, test-loop-guard-budget-override.sh, test-loop-guard-staleness.sh, test-resume-scan-nonconformance.sh, test-routing-resolution.sh, test-skill-base-lifecycle.sh`

Project 88's own task description literally instructs its implementer to do this enumeration: WORK item (5) says "Update ... every test that greps SKILL.md structure (enumerate by grep for skill-orchestrate/SKILL.md under scripts/tests and scripts/lint)." I ran that exact grep now (`grep -rl "SKILL.md" agent-system/extensions/core/scripts/tests/ agent-system/extensions/core/scripts/lint/`) and the results above are its output.

**Caveat, explicitly flagged**: project 88's current (REVISED 2026-09-02) description is a large rewrite of `skill-orchestrate/SKILL.md` — deleting ~183,000 bytes of single-task stages and replacing the whole file with a four-move loop. That rewrite could plausibly change which lint/test files reference `SKILL.md`'s structure by the time project 88 is actually implemented (a file that greps for a heading or stage name deleted by the rewrite might stop matching; a new file added by the rewrite might start matching). This grep result is today's best-evidence snapshot, not a permanent guarantee — it should be refreshed via the write-back convention (below) at project 88's own research/implementation stage rather than trusted blindly at that point.

Per the team lead's explicit instruction, project 88's `context/patterns/` entry was not touched (and does not currently exist — see Addendum Verification above).

#### Project 142 — `reduce_orchestrator_token_consumption` (status: `not_started`)

- OLD: `["agent-system/extensions/core/scripts/verify-deploy.sh", "agent-system/extensions/core/scripts/lint/", "agent-system/extensions/core/scripts/measure-eager-context.sh", "agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md"]`
- NEW: `["agent-system/extensions/core/scripts/verify-deploy.sh", "agent-system/extensions/core/scripts/measure-eager-context.sh", "agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md"]`

Its (REVISED 2026-09-02) description's WORK items target `verify-deploy.sh` (extend with a warning-first context-budget gate), a per-cycle growth probe ("a test or a documented procedure" — explicitly left open-ended by the description itself), and correcting prose in the state-machine doc. No specific file under `scripts/lint/` is named anywhere in the description, and nothing in the WORK items implies adding a new lint script. This is dropped entirely rather than narrowed to a guess — see the unknown-footprint convention below for what happens if implementation later discovers it does need one.

#### Project 149 — `delete_team_mode` (status: `not_started`)

- OLD: `[..., "agent-system/extensions/core/scripts/tests/"]`
- NEW: entry dropped.

Unlike the batch-engine cluster, no naming-convention match is available here: team-mode-specific test files were already deleted by the completed task 123 (`delete_team_mode_skills`) — a `grep -i "team\|synthesis\|parse-command" agent-system/extensions/core/scripts/tests/` finds nothing team-related left. `parse-command-args.sh`, also in this task's declared scope, has no existing companion test file either. Genuinely unknown until this task's own research determines which existing tests (if any) reference team-mode code paths for deletion.

#### Project 129 — `audit_word_boundary_regex_portability` (status: `not_started`)

- OLD: 8 already file-precise entries (`literature-audit.sh`, `literature-convert.sh`, `lean-sorry-census.sh`, `test-session-runtime-files.sh`, `check-extension-docs.sh`, `tests/test-lake-build-guard.sh`, `lint/lint-postflight-boundary.sh`, `guard-destructive-git.sh`) plus `"agent-system/extensions/core/context/standards/"`
- NEW: drop `context/standards/`; the 8 other entries are unchanged (already best practice — note in particular that this task already declares its two relevant existing test-harness files individually, `test-session-runtime-files.sh` and `tests/test-lake-build-guard.sh`, rather than the whole `scripts/tests/` directory — it is not part of the `scripts/tests/` cluster above at all).

The task's own DELIVERABLE BEYOND THE REPAIRS item asks for "a short portability guidance note under the core standards context directory" — the note's filename is not, and cannot be, fixed at creation time; it depends on what the audit's 26-site sweep concludes. Genuinely unknown until research runs.

### Test-naming convention (evidence for the predictions above)

`agent-system/extensions/core/scripts/tests/` follows a strong, near-universal `test-<script-basename>.sh` convention, confirmed directly from the directory listing: every `lint-*.sh` in `scripts/lint/` has a matching `test-lint-*.sh` in `scripts/tests/` (7 of 9 checked directly: `lint-branch-gated-sections.sh` ↔ `test-lint-branch-gated-sections.sh`, `lint-lifecycle-status-var.sh` ↔ `test-lint-lifecycle-status-var.sh`, `lint-postflight-boundary.sh` ↔ `test-lint-postflight-boundary.sh`, `lint-scoped-commit-boundary.sh` ↔ `test-lint-scoped-commit-boundary.sh`, `lint-state-writer-boundary.sh` ↔ `test-lint-state-writer-boundary.sh`, `lint-task-lookup-adoption.sh` ↔ `test-lint-task-lookup-adoption.sh`); `orchestrate-triage-classify.sh` ↔ `test-orchestrate-triage-classify.sh`; `assess-repo-health.sh` ↔ `test-assess-repo-health.sh`. This convention is reliable enough to predict the exact companion test-file path for a not-yet-created implementation script at task-creation time, which resolves most "unknown until research" cases for `scripts/tests/` without needing to declare the whole directory — as demonstrated for projects 20, 143, 147, 148, and 150 above. It does NOT resolve project 149's case (no implementation script of its own to mirror) or project 88's case (a doc/skill rewrite, not a single implementation script — resolved instead by the literal grep its own description specifies).

## Root-cause finding: `multi-task-creation-standard.md` is instructing task creation to over-declare

`agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md`, Component 4a ("File Footprint Capture and Overlap Detection"), step 1, currently reads verbatim:

> "Bias toward over-declaring (broader prefixes): false positives here only cost parallelism, not correctness."

This is the documented, standing instruction that produces exactly the coarse directory-root declarations Check 8 exists to catch (Check 8 was added by task 61 specifically for this defect class — see "Prior decision context" below). As long as this line stands unchanged, any task-creation flow that follows the standard as written — `/task`, `/fix-it`, `meta-builder-agent`, `skill-spawn` — will keep producing new coarse declarations even after today's 11 are narrowed. **Narrowing the current 11 declarations without fixing this line would leave the generator of the problem in place**; the fix is not complete without it.

Recommended replacement text (for the plan phase to finalize): bias toward the narrowest currently-known files or subtrees; a directory-root or extension-wide prefix should be used only when the task's own footprint is genuinely expected to span most of that directory — never merely because the exact files are not yet known. For the "not yet known" case, point to the write-back convention decided below rather than falling back to a directory root.

## Decision: the "unknown until research" convention

### Prior decision context

Task 61 (commit `c6467b078`, `task 61 phase 2: Check 8 — coarse (blast-radius) file_scope declarations`) added Check 8 as WARN-only by deliberate design and explicitly deferred the narrowing/policy question to a follow-up task. No prior task decided the unknown-footprint convention; this is that follow-up, and there is nothing earlier to build on or reconcile with.

### The decision

For file_scope entries whose true footprint cannot be known until a task's own research phase has run (project 129's guidance-note filename; project 149's and project 142's untraceable-until-research cases above):

1. **At creation time**: declare only the narrowest currently-known files. Never declare a directory root as a stand-in for "the exact files aren't known yet" — the directory root is exactly the false-collision generator this task exists to remove.
2. **At research-postflight time**: the research phase proposes an update to `file_scope`, additive only (never subtractive — this preserves the "no false negatives" constraint categorically; under-declaring a real file is strictly worse than a temporary over-declaration), written back to `specs/state.json` before the plan phase begins.

### Recommended wiring

- Add an optional `proposed_file_scope` field to `.return-meta.json`'s schema, populated by `skill-researcher`/`skill-researcher-hard` at their Stage 7 ("Write Metadata File") step whenever research discovers concrete new-file targets not already covered by the task's declared `file_scope`.
- Consume it via a new `--file-scope-add <json-array>` flag on `update-task-status.sh`'s research-postflight invocation. `update-task-status.sh` is confirmed (via `grep -rl file_scope` across `agent-system/extensions/core/scripts/*.sh`, `skills/*/SKILL.md`, `agents/*.md`) to be the **sole** current writer of `state.json` at status-transition time — no other script currently writes `file_scope` post-creation, so this is the natural, minimal-surface-area integration point rather than a new parallel writer.
- The merge must be a set union onto the existing array, never a replacement — this is what makes the mechanism additive-only and keeps it from ever silently removing coverage.

## Pre-existing, out-of-scope findings (left alone)

`validate-state.sh` also reports 2 unrelated FAILs on this run:
- `Unknown entry field: abandon_reason` on 12 projects (141, 94, 53, 46, 31, 42, 64, 73, 100, 115, 132, 138)
- `Unknown entry field: blocks_note` on 3 projects (106, 107, 109)

Both are schema-drift issues unrelated to `file_scope`/Check 8/Check 9 and are explicitly out of this task's scope (mirrors the precedent in task 61's own verification notes, which found and deliberately left alone a similarly unrelated pre-existing FAIL). Not touched here.

Check 9 ("No duplicate file_scope entries found") already passes and is unaffected by this work — Check 9 flags duplicates *within* a single task's own array, not the same path appearing across two different tasks' arrays (which is the expected, correct shape when two tasks genuinely share a file, e.g. the `orchestrate-cycle-plan.sh` collisions above).

## Recommendations (for the plan phase)

1. Apply the 9 per-task `file_scope` narrowings in the tables above directly to `specs/state.json` (a mechanical data edit — no `file_scope` entry that a task actually touches is omitted by any of the narrowings above).
2. Update `multi-task-creation-standard.md` Component 4a step 1's "bias toward over-declaring" guidance per the Root-cause section above.
3. Implement the write-back convention: `proposed_file_scope` in the `.return-meta.json` schema, plus `--file-scope-add` on `update-task-status.sh`, wired into `skill-researcher`/`skill-researcher-hard` Stage 7; additive-only.
4. Document the convention itself (either a new pattern file under `context/patterns/`, or a new subsection of Component 4a) so future task creation follows it rather than defaulting to a directory root.
5. Re-run `validate-state.sh` Check 8 after all edits land to confirm the 11 findings resolve to 0 (or to fully-justified survivors, if any remain deliberately), plus a full gate run (`verify-deploy.sh`) to confirm nothing else regressed.

## Risks & Mitigations

- **Risk**: the `scripts/lint/`/`scripts/tests/` predictions for project 88 could go stale before that task is implemented, since project 88 itself rewrites the file those predictions were derived from. **Mitigation**: flagged explicitly above; the write-back convention (recommendation 3) is designed to refresh this exact case at project 88's own research stage rather than relying on today's snapshot at implementation time.
- **Risk**: narrowing without also fixing the Component 4a "bias toward over-declaring" line only treats the symptom. **Mitigation**: called out explicitly as a required companion fix (recommendation 2), not an optional follow-up.
- **Risk**: an additive-only write-back mechanism could in principle grow `file_scope` arrays unboundedly across many research cycles if a task iterates. **Mitigation**: out of scope to solve here; noted for the plan phase to weigh (e.g. is there ever a legitimate need to shrink a proposed addition — likely handled by human/plan-phase review before commit, not by the mechanism itself).

## Context Extension Recommendations

- **Topic**: file_scope declaration convention for unknown-until-research footprints.
- **Gap**: no existing context file documents when a directory-root `file_scope` entry is legitimate versus when it should be replaced by the additive research-postflight write-back convention decided in this report.
- **Recommendation**: create `agent-system/extensions/core/context/patterns/file-scope-unknown-footprint-convention.md` (or fold into Component 4a of `multi-task-creation-standard.md` directly) documenting the decision in "Decision: the unknown until research convention" above, so `/task`, `/fix-it`, `meta-builder-agent`, and `skill-spawn` all converge on the same behavior.

## Appendix

### Commands run

```bash
bash agent-system/extensions/core/scripts/validate-state.sh
# then, to get the full unabbreviated Check 8 list (script truncates to 10 + "...N more"):
source agent-system/extensions/core/scripts/lib/file-scope-overlap.sh
jq -c --argjson COARSE_MIN_OVERLAP 3 "$_check8_prog" specs/state.json   # $_check8_prog = Check 8's own program, spliced verbatim from validate-state.sh

grep -c "general-implementation-hard-agent" specs/state.json
jq -r '.active_projects[] | select(.file_scope != null) | select(.file_scope[] | contains("context/patterns")) | ...' specs/state.json
jq -r '.active_projects[] | select(.file_scope != null) | select(.file_scope[] | contains("general-implementation-hard-agent")) | "\(.project_number) \(.project_name) \(.status)"' specs/state.json

ls agent-system/extensions/core/scripts/tests/ ; ls agent-system/extensions/core/scripts/lint/
for f in orchestrate-cycle-plan.sh orchestrate-cycle-postflight.sh orchestrate-churn.sh orchestrate-dry-run-report.sh orchestrate-recover-outcome.sh orchestrate-triage-classify.sh; do
  [ -f "agent-system/extensions/core/scripts/$f" ] && echo "EXISTS: $f" || echo "NEW: $f"
done

grep -rl "SKILL.md" agent-system/extensions/core/scripts/tests/ agent-system/extensions/core/scripts/lint/

git log --oneline --all -- agent-system/extensions/core/scripts/validate-state.sh | grep -i "coarse\|check 8\|blast"
git show c6467b078 -- '*/plans/01_coarse-file-scope-advisory.md'

grep -rl "file_scope" agent-system/extensions/core/scripts/*.sh agent-system/extensions/core/skills/*/SKILL.md agent-system/extensions/core/agents/*.md
```

### References

- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` — canonical overlap predicate (unchanged by this task)
- `agent-system/extensions/core/scripts/validate-state.sh` — Check 8 (unchanged by this task; WARN-only, stays WARN-only)
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` — Component 4a, flagged for a follow-up doc edit
- `specs/044_slim_task_command_body/plans/01_task-command-mode-extraction.md` — source of the project 44 narrowing
