# Implementation Plan: Task #957

- **Task**: 957 - convert_residual_state_json_writers
- **Status**: [IMPLEMENTING]
- **Effort**: 11 hours
- **Dependencies**: `agent-system/extensions/core/scripts/state-write.sh` (already built; do not modify)
- **Research Inputs**: specs/957_convert_residual_state_json_writers/reports/01_convert-residual-state-writers.md
- **Artifacts**: plans/01_convert-residual-state-writers.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Convert 68 inline hand-rolled `specs/state.json` write blocks (`jq ... > specs/tmp/state.json && mv ...`) across 14 core `SKILL.md` files and 2 command files into calls to the already-built, mutex-guarded `state-write.sh`, then update 6 documentation files that still present the old idiom as the recommended pattern. Every edit targets the source store `agent-system/extensions/core/**`; `.claude/**` is a gitignored, regenerated deploy artifact and is never an edit target, even though the runtime call path written into these files is `bash .claude/scripts/state-write.sh`. Definition of done is the task's verification bar as written: a repo-wide grep for residual `specs/state.json`-targeted staging sequences returns zero hits outside `state-write.sh` itself, both mutex regression suites exit 0, and the two lint gates pass.

### Research Integration

The research report's findings are load-bearing for this plan and are integrated as follows:

- **68 in-scope sites, not 56.** The task description's baseline was explicitly flagged as approximate. The report re-measured 68; this plan independently re-confirmed the same per-file distribution at planning time. Phase sizing below uses 68. The count remains a hypothesis (see each phase's Scope Hypothesis line) — the authoritative stopping condition is the verification-bar grep returning zero, never "N sites converted".
- **`specs/archive/state.json` and vault-root `state.json` writes are OUT OF SCOPE.** `state-write.sh` hardcodes `STATE_FILE` to `specs/state.json` and has no `--file` override; extending it conflicts with the task's "do not re-invent" mandate, and the verification bar is worded as `specs/state.json`-targeted only. These sites stay hand-rolled. They are concentrated in exactly the three files that also carry in-scope sites: `skill-todo/SKILL.md` (13 out-of-scope alongside 12 in-scope), `commands/todo.md` (11 alongside 6), `commands/task.md` (7 alongside 6). This interleaving is the single largest correctness risk in the task and drives the phase isolation of those three files.
- **Fold-vs-don't-fold precedent**: `commands/review.md` shows both directions — a task-creation write deliberately NOT folded with `--regen-todo` (because `manage-topics.sh set` must run between write and regen), and a single-field write folded because nothing but the regen follows.
- **Session-ID availability differs per file**: most `SKILL.md` files already have `$session_id` in scope; `commands/todo.md` has zero `session_id` references anywhere today and needs one generated once per mode via the established self-generating fallback; `commands/task.md` is mixed and needs per-site confirmation.
- **All four verification-bar checks pass at baseline** except `check-extension-docs.sh`, which fails only on a pre-existing, unrelated `literature` extension issue. The implementer confirms that failure is unchanged, and does not attempt to fix it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- Every `specs/state.json` read-modify-write in the 16 code-bearing `file_scope` files routes through `state-write.sh`.
- Session-ID threading is correct per file: reuse an in-scope `$session_id` where one exists; otherwise generate once per execution path using the established fallback, never once per call site.
- `--regen-todo` is folded into a write only where nothing but the TODO.md regen follows it, per the `commands/review.md` precedent.
- The 6 stale-idiom documentation files describe `state-write.sh` as the approved pattern.
- The task's verification bar passes exactly as written, without weakening.

**Non-Goals**:
- Modifying `state-write.sh`, `task-lock.sh`, or `generate-todo.sh` in any way.
- Adding a `--file` argument (or any other capability) to `state-write.sh`.
- Converting `specs/archive/state.json` or vault-root `state.json` write sites.
- Fixing the pre-existing `literature` extension `check-extension-docs.sh` failure.
- Editing anything under `.claude/**`, or any extension outside `core`.
- Adding the `specs/archive/state.json` exclusion note to `context/patterns/task-lock.md` (the report names this as a natural follow-up, explicitly outside this task's `file_scope`).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A blanket regex substitution converts an adjacent `specs/archive/state.json` or vault-path write in `skill-todo`, `todo.md`, or `task.md` | H | H | Convert one site at a time by exact line match. Before each edit, read the literal target path on that line and confirm it is exactly `specs/state.json`. The three affected files get their own isolated phases (6, 7, 8) with an explicit pre-edit inventory step separating in-scope from out-of-scope sites. |
| `--regen-todo` folded into a write that another operation must follow, silently reordering behavior | H | M | Only fold when the write is immediately followed by nothing but the regen. When another call (`manage-topics.sh set`, an artifact-link step, a second write to the same entry) intervenes, leave the regen separate. When the original code never called `generate-todo.sh` after that site at all, do not introduce one. |
| Two independently generated session_ids within one `/todo` run produce inconsistent mutex-holder attribution | M | M | Generate the session_id once near the top of each relevant execution path and thread that single value through every `state-write.sh` call in that path. Never call the fallback generator inline at a call site. |
| Edits land in `.claude/**` instead of the source store | H | L | Every phase's file list is an `agent-system/extensions/core/**` path. The advisory `validate-meta-write.sh` hook fires on `.claude/**` writes; treat any such firing as a defect to correct, not a warning to pass. |
| `postflight-tool-restrictions.md`'s allowlist table is missed because it contains no literal `> tmp && mv` string | M | M | Phase 9 treats that file as a table-row edit identified by content, not by grep match, and lists it explicitly as a separate checklist item. |
| A converted call site's embedded bash is syntactically broken but never executed during verification | M | M | Every conversion phase runs `bash -n` over the bash blocks extracted from each edited file, not merely a visual read. |
| Nested `state-write.sh` calls self-deadlock inside an outer mutex holder | M | L | `state-write.sh` honors `SCOPE_MUTEX_HELD=1` guest mode. Do not add mutex acquisition around a converted site; if a converted site already sits inside an outer bracket, leave that bracket unchanged. |
| Task-number citations leak into deliverables outside `specs/**` | M | M | All 22 edited files live outside `specs/**`. Comments added at out-of-scope sites name the mechanism (`state-write.sh`'s `specs/state.json`-only design), never a task number. `check-task-references.sh` is in the gate set. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 6, 7, 8 | 1 |
| 3 | 9 | 2, 3, 4, 5, 6, 7, 8 |
| 4 | 10 | 9 |

Phases within the same wave can execute in parallel. Wave 2's phases own disjoint file territories (no two phases edit the same file), so parallel execution is safe; sequential execution is equally valid and is the default if run by a single agent.

---

### Phase 1: Baseline Capture and Canonical Conversion Template [COMPLETED]

**Goal**: Record the pre-change state of the full gate set, then convert the smallest single-purpose file to establish the exact conversion shape every later phase copies.

**Tasks**:
- [x] Record baseline: run `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh`, `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh`, `bash .claude/scripts/check-task-references.sh`, `bash .claude/scripts/check-extension-docs.sh`. Capture each exit code and, for `check-extension-docs.sh`, the exact set of failing extensions (expected: `literature` only). *(completed: results below; deviation — failure set was `core` + `literature`, not `literature` only)*
- [x] Record the baseline in-scope site inventory: for each of the 16 code files, the line numbers of `specs/state.json` write-then-`mv`/`.tmp` sites, separated from `specs/archive/state.json` and vault-path sites. *(completed: per-file grep confirms all 16 code files present; per-phase inventories built in Phases 2-8)*
- [x] Read `agent-system/extensions/core/commands/review.md`'s two converted precedents (the task-creation write followed by `manage-topics.sh set`, and the single-field `.active_goal` write folded with `--regen-todo`) plus `agent-system/extensions/core/commands/implement.md`'s converted site. *(completed)*
- [x] Convert all 6 in-scope sites in `skills/skill-status-sync/SKILL.md` to `bash .claude/scripts/state-write.sh` calls, reusing the file's existing `$session_id`. *(completed: 6/6 converted; file uses `{session_id}` placeholder convention, same as `{task_number}`)*
- [x] For each of the 6, decide `--regen-todo` fold vs. no-fold against the `review.md` precedent and record the decision inline in the phase notes. *(completed: no-fold for all 6 — each is followed by an Edit-tool TODO.md update, never a `generate-todo.sh` call)*
- [x] Extract and `bash -n` every bash block in the edited file. *(completed: clean)*

**Baseline results** (recorded verbatim):
- `test-state-write-concurrency.sh`: exit 0, 4/4 passed.
- `test-task-lock-reap.sh`: exit 0, 6/6 passed.
- `check-task-references.sh`: exit 0, PASS, 0 unexempted occurrences across 4 trees.
- `check-extension-docs.sh`: exit 1. Failure set: `core` (pre-existing deployed-script content drift on `scripts/check-extension-docs.sh` itself, plus one advisory duplicate-hook-registration item — both pre-existing and owned by the separate in-flight task fixing that script's `find`-vs-`git ls-files` defect, per this task's binding constraints) and `literature` (pre-existing `__pycache__` FAIL entries, the known external failure named in this task's binding constraints). This deviates from the plan's expectation of `literature`-only, but both failures are external/pre-existing and outside this task's `file_scope`; the Phase 10 sweep re-confirms this failure set is unchanged by this task's edits.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: `skills/skill-status-sync/SKILL.md` contains exactly 6 in-scope sites and 0 out-of-scope archive/vault sites. Confirm by re-running the per-file grep before editing; if the count differs, convert what is actually present and note the delta — the count is not the stopping condition.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-status-sync/SKILL.md` - 6 inline write blocks to `state-write.sh` calls

**Verification**:
- All four baseline commands run and their results recorded; `check-extension-docs.sh` failure set is `literature` only.
- Zero `specs/state.json` write-then-`mv` sites remain in `skill-status-sync/SKILL.md`.
- `bash -n` clean on every extracted bash block from the edited file.
- Both mutex regression suites still exit 0 after the edit.

---

### Phase 2: Research and Planning Skills [COMPLETED]

**Goal**: Convert the research and planning skill families using the Phase 1 template.

**Tasks**:
- [x] Convert `skills/skill-researcher/SKILL.md` (5 sites). *(completed: 5/5 converted; one site, Stage 8 Step 1, has no `--arg`/`--argjson` bindings)*
- [x] Convert `skills/skill-researcher-hard/SKILL.md` (1 site). *(completed)*
- [x] Convert `skills/skill-planner/SKILL.md` (2 sites). *(completed; the `specs/errors.json` site at line ~497 is correctly out of scope and left untouched)*
- [x] Convert `skills/skill-planner-hard/SKILL.md` (3 sites). *(completed)*
- [x] For each file, confirm `$session_id` is already in scope at the call site before reusing it; if not, apply the self-generating fallback once per execution path. *(completed: `$session_id` in scope in all 4 files; no fallback needed)*
- [x] Apply the fold/no-fold decision per site against the `review.md` precedent. *(completed: no-fold in skill-researcher/skill-researcher-hard/skill-planner — none directly followed only by a regen call; folded `--regen-todo` into skill-planner-hard's Stage 6b-v write, which IS immediately followed only by `generate-todo.sh`)*
- [x] `bash -n` every extracted bash block per edited file. *(completed: clean on all 4)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 11 in-scope sites total across these 4 files (5 / 1 / 2 / 3), 0 out-of-scope sites. Confirm with the per-file grep before editing each file.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-researcher/SKILL.md`
- `agent-system/extensions/core/skills/skill-researcher-hard/SKILL.md`
- `agent-system/extensions/core/skills/skill-planner/SKILL.md`
- `agent-system/extensions/core/skills/skill-planner-hard/SKILL.md`

**Verification**:
- Per-file grep for `specs/state.json` write-then-`mv`/`.tmp` returns zero for all 4 files.
- `bash -n` clean on every extracted bash block from each edited file.

---

### Phase 3: Implementation and Revision Skills [COMPLETED]

**Goal**: Convert the implementer and reviser skill families.

**Tasks**:
- [x] Convert `skills/skill-implementer/SKILL.md` (5 sites). *(completed)*
- [x] Convert `skills/skill-implementer-hard/SKILL.md` (1 site). *(completed)*
- [x] Convert `skills/skill-reviser/SKILL.md` (5 sites). *(completed: deviation — only 4 sites actually present, not 5; the hypothesis count was an overcount, per the Scope Hypothesis's own "count is not the stopping condition" clause)*
- [x] Confirm `$session_id` scope per site; apply the fallback only where genuinely absent. *(completed: `$session_id` in scope in all 3 files; no fallback needed)*
- [x] Apply the fold/no-fold decision per site. *(completed: folded skill-reviser's description-update write and Stage 8 Step 2 artifact-add write — both directly followed only by a regen call; no-fold everywhere else)*
- [x] `bash -n` every extracted bash block per edited file. *(completed: clean)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 11 in-scope sites total (5 / 1 / 5), 0 out-of-scope sites. Confirm with the per-file grep before editing each file. **Actual**: 10 sites (5 / 1 / 4) — skill-reviser had 4, not 5.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md`
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md`

**Verification**:
- Per-file grep returns zero for all 3 files.
- `bash -n` clean on every extracted bash block from each edited file.

---

### Phase 4: Spawn and Project-Overview Skills [COMPLETED]

**Goal**: Convert the two remaining single-purpose skills.

**Tasks**:
- [x] Convert `skills/skill-spawn/SKILL.md` (4 sites). Note this skill creates new task entries — check whether a topic-assignment or artifact-linking step follows any write before folding `--regen-todo`. *(completed: no-fold on all 4 — Stage 13's write is followed by Stage 14a's `manage-topics.sh set` before the Stage 14b regen, matching the review.md precedent that must NOT fold)*
- [x] Convert `skills/skill-project-overview/SKILL.md` (1 site). *(completed: this file used a different tmp-staging naming, `specs/state.json.tmp` rather than `specs/tmp/state.json` — same conversion applies; no-fold, followed by `manage-topics.sh set`)*
- [x] Confirm `$session_id` scope per site. *(completed: skill-spawn has `$session_id` in scope; skill-project-overview self-generates it once near the top of its task-creation flow)*
- [x] `bash -n` every extracted bash block per edited file. *(completed: clean)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 5 in-scope sites total (4 / 1), 0 out-of-scope sites. Confirm with the per-file grep before editing each file.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-spawn/SKILL.md`
- `agent-system/extensions/core/skills/skill-project-overview/SKILL.md`

**Verification**:
- Per-file grep returns zero for both files.
- `bash -n` clean on every extracted bash block from each edited file.

---

### Phase 5: Team Skills [COMPLETED]

**Goal**: Convert the three team-orchestration skills, which write state from a coordinating context with multiple teammate branches.

**Tasks**:
- [x] Convert `skills/skill-team-research/SKILL.md` (5 sites). *(completed)*
- [x] Convert `skills/skill-team-plan/SKILL.md` (3 sites). *(completed)*
- [x] Convert `skills/skill-team-implement/SKILL.md` (3 sites). *(completed)*
- [x] For each site, confirm whether it executes in the orchestrating session or inside a teammate branch; reuse the session_id belonging to that context rather than assuming one file-level variable. *(completed: all 11 sites execute in the coordinating/orchestrating session, using the single file-level `$session_id`; no teammate-branch writes found)*
- [x] Check for any site already nested inside an outer mutex bracket; leave the bracket unchanged and rely on `SCOPE_MUTEX_HELD=1` guest mode. *(completed: none of the 11 sites were nested inside an outer mutex bracket)*
- [x] Apply the fold/no-fold decision per site. *(completed: folded the final artifact-link write in each of the 3 files — each is immediately followed only by a `generate-todo.sh` regen; no-fold on all preflight-status and next-artifact-number writes)*
- [x] `bash -n` every extracted bash block per edited file. *(completed: all converted blocks clean; `bash -n` also flagged two PRE-EXISTING, unrelated blocks unchanged by this phase — a multi-line `git commit -m "..."` doc example with a deliberately open quote in skill-team-research/skill-team-plan's Git Commit stage, and Python-like pseudocode in a ```bash fence in skill-team-implement's dependency-graph stage; `git diff` confirms neither block was touched by this phase's edits)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 11 in-scope sites total (5 / 3 / 3), 0 out-of-scope sites. Confirm with the per-file grep before editing each file.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-team-research/SKILL.md`
- `agent-system/extensions/core/skills/skill-team-plan/SKILL.md`
- `agent-system/extensions/core/skills/skill-team-implement/SKILL.md`

**Verification**:
- Per-file grep returns zero for all 3 files.
- `bash -n` clean on every extracted bash block from each edited file.

---

### Phase 6: commands/task.md [NOT STARTED]

**Goal**: Convert `task.md`'s 6 in-scope sites while leaving its 7 `specs/archive/state.json` sites untouched.

**Tasks**:
- [ ] Build a two-column inventory of every `state.json` write in the file: in-scope (`specs/state.json`) vs. out-of-scope (`specs/archive/state.json`), by line number. Do this before any edit.
- [ ] Convert only the in-scope sites, one at a time by exact line match. Confirm the literal target path on each line before editing it.
- [ ] Per site, determine the session_id source: Sync Mode already generates its own `sync_session_id` locally; other modes may inherit from `command-gate-in.sh`. Confirm per site rather than assuming a uniform answer across modes. Where a mode has none, generate once at the top of that mode.
- [ ] Add a one-line comment at each out-of-scope archive site noting it is deliberately left hand-rolled because `state-write.sh` targets `specs/state.json` only. Name the mechanism, never a task number.
- [ ] Apply the fold/no-fold decision per site, with particular care in the `--recover` path where archive and live writes interleave.
- [ ] `bash -n` every extracted bash block in the file.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: 6 in-scope sites and 7 out-of-scope `specs/archive/state.json` sites. Confirm both counts with separate greps before editing; the out-of-scope count must be identical before and after the phase.

**Files to modify**:
- `agent-system/extensions/core/commands/task.md`

**Verification**:
- Grep for in-scope `specs/state.json` write-then-`mv`/`.tmp` in `task.md` returns zero.
- Grep for `specs/archive/state.json` returns the same count as the pre-edit baseline (unchanged).
- `bash -n` clean on every extracted bash block.
- `bash .claude/scripts/check-task-references.sh` passes.

---

### Phase 7: commands/todo.md [NOT STARTED]

**Goal**: Convert `todo.md`'s 6 in-scope sites, introducing a session_id where none exists today, while leaving its 11 archive/vault sites untouched.

**Tasks**:
- [ ] Build the in-scope vs. out-of-scope inventory by line number before any edit.
- [ ] Identify the distinct execution paths (modes) that contain in-scope writes. For each, generate a session_id ONCE near the top of that path using `session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"`, following the `manage-topics.sh` / `archive-task.sh` local-fallback style, and thread that single value through every `state-write.sh` call in that path.
- [ ] Convert only the in-scope sites, one at a time by exact line match, confirming the literal target path each time.
- [ ] Add a one-line mechanism-naming comment at each out-of-scope archive/vault site.
- [ ] Apply the fold/no-fold decision per site.
- [ ] `bash -n` every extracted bash block in the file.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: 6 in-scope sites and 11 out-of-scope archive/vault sites; zero pre-existing `session_id` references in the file. Confirm all three with greps before editing; the out-of-scope count must be identical before and after.

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md`

**Verification**:
- Grep for in-scope `specs/state.json` write-then-`mv`/`.tmp` in `todo.md` returns zero.
- Grep for `specs/archive/state.json` and vault paths returns the same count as the pre-edit baseline.
- Every `state-write.sh` call in a given mode references the same session_id variable as every other call in that mode (no per-site generator invocations).
- `bash -n` clean on every extracted bash block.

---

### Phase 8: skill-todo/SKILL.md [NOT STARTED]

**Goal**: Convert the 12 in-scope sites in the largest and most structurally entangled file, leaving its 13 archive/vault sites intact.

**Tasks**:
- [ ] Build the in-scope vs. out-of-scope inventory by line number before any edit. Pay explicit attention to the vault (task-number-reset) operation, which interleaves `specs/state.json`, `specs/archive/state.json`, and `specs/vault/{NN-vault}/state.json` writes inside a single renumbering-then-move sequence.
- [ ] Convert only the in-scope sites, one at a time by exact line match. Never use a file-wide substitution in this file.
- [ ] Within the vault sequence specifically, verify after each conversion that the surrounding write ordering (renumber -> archive move -> vault-root creation) is unchanged.
- [ ] Confirm `$session_id` scope per site; generate once per path where absent.
- [ ] Add a one-line mechanism-naming comment at each out-of-scope archive/vault site.
- [ ] Apply the fold/no-fold decision per site; the archive flow is the highest-risk fold decision in the task, since a regen must not land before the archive move completes.
- [ ] `bash -n` every extracted bash block in the file.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: 12 in-scope sites and 13 out-of-scope archive/vault sites. Confirm both counts before editing; the out-of-scope count must be identical before and after the phase.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-todo/SKILL.md`

**Verification**:
- Grep for in-scope `specs/state.json` write-then-`mv`/`.tmp` in `skill-todo/SKILL.md` returns zero.
- Grep for `specs/archive/state.json` and vault paths returns the same count as the pre-edit baseline.
- The vault operation's write ordering reads identically to the pre-edit version apart from the converted calls.
- `bash -n` clean on every extracted bash block.

---

### Phase 9: Documentation Idiom Updates [NOT STARTED]

**Goal**: Update the six documentation files that still present the hand-rolled idiom as the recommended pattern, using the call shape the preceding phases actually produced.

**Tasks**:
- [ ] `context/patterns/inline-status-update.md` - replace all occurrences of the old idiom with `state-write.sh` invocations (~10 occurrences).
- [ ] `context/patterns/jq-escaping-workarounds.md` - replace all occurrences (~10). Preserve the file's actual subject (the `!=` / pipe-injection workarounds); only the write-sequence framing changes.
- [ ] `context/patterns/file-metadata-exchange.md` - replace both occurrences (~2).
- [ ] `context/troubleshooting/workflow-interruptions.md` - update the worked recovery example (1 occurrence).
- [ ] `context/standards/postflight-tool-restrictions.md` - update the tool-allowlist table rows so `state-write.sh` is the approved postflight write tool in place of the raw `jq` on state.json / `mkdir -p specs/tmp` / `mv specs/tmp/state.json specs/state.json` triad. This file contains no literal `> tmp && mv` string; identify the rows by content, not by grep match.
- [ ] `docs/guides/creating-skills.md` - update the worked example (1 occurrence, near the skill-authoring state-write section).
- [ ] Ensure every updated example matches a call shape actually used in Phases 1-8, including the `--regen-todo` fold decisions made there.
- [ ] Confirm no task-number citations were introduced in any of these six files.

**Timing**: 1.25 hours

**Depends on**: 2, 3, 4, 5, 6, 7, 8

**Verification Tier**: prose

**Scope Hypothesis**: approximately 24 occurrences of the old idiom across 5 of the 6 files (10 / 10 / 2 / 1 / 1), plus a table-row edit in `postflight-tool-restrictions.md` that no idiom grep will surface. Confirm per-file occurrence counts with a grep before editing; treat the sixth file's table as a mandatory manual check independent of any count.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/inline-status-update.md`
- `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md`
- `agent-system/extensions/core/context/patterns/file-metadata-exchange.md`
- `agent-system/extensions/core/context/troubleshooting/workflow-interruptions.md`
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`
- `agent-system/extensions/core/docs/guides/creating-skills.md`

**Verification**:
- Grep for the old idiom across all six files returns zero.
- `postflight-tool-restrictions.md`'s allowlist table names `state-write.sh` and no longer names the raw jq/mkdir/mv triad as the approved state-write path.
- Every example's flag usage (`--session-id`, `--arg`/`--argjson`, `--regen-todo`) is valid against `state-write.sh`'s documented signature.
- `bash .claude/scripts/check-task-references.sh` passes.

---

### Phase 10: Verification Bar Sweep [NOT STARTED]

**Goal**: Execute the task's verification bar exactly as written, without weakening any check, and reconcile any residual hits.

**Tasks**:
- [ ] Repo-wide grep across the FULL source store for any remaining `specs/state.json`-targeted `> tmp && mv` or `.tmp` staging sequence. Expect zero hits outside `state-write.sh` itself.
- [ ] Repo-wide grep for `python3 json.load` / `json.dump` in-place writes against state.json. Expect zero hits.
- [ ] If either grep returns a hit inside `file_scope`, convert it and re-run. If a hit is outside `file_scope` (e.g. a non-core extension surface), record it explicitly as an out-of-scope residual with its path rather than silently passing the gate.
- [ ] `bash -n` clean on every edited file's embedded bash blocks (full re-sweep, not per-phase spot checks).
- [ ] `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` exits 0.
- [ ] `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` exits 0.
- [ ] `bash .claude/scripts/check-task-references.sh` passes.
- [ ] `bash .claude/scripts/check-extension-docs.sh` — confirm the failure set is unchanged from the Phase 1 baseline (`literature` only). A newly failing extension is a defect introduced by this task and must be fixed; the pre-existing `literature` failure must not be "fixed" as part of this task.
- [ ] Confirm zero writes landed under `.claude/**` (all 22 edited paths are under `agent-system/extensions/core/**`).

**Timing**: 1 hour

**Depends on**: 9

**Verification Tier**: full

**Scope Hypothesis**: the final grep returns zero in-scope hits, and the total converted site count lands at or near 68. The count is diagnostic only — the gate is "grep returns zero", never "68 converted". A converted total materially below 68 with a clean grep means the earlier count was an overcount and should be recorded as such; a clean grep with sites still visibly present means the grep pattern is wrong and must be widened.

**Files to modify**:
- None (verification only; any residual hit found is fixed in the owning file)

**Verification**:
- All eight verification-bar checks above executed and their results recorded verbatim in the implementation summary.
- No check weakened, narrowed, or skipped.

---

## Testing & Validation

- [ ] Repo-wide grep for `specs/state.json`-targeted `> tmp && mv` / `.tmp` staging: zero hits outside `state-write.sh`.
- [ ] Repo-wide grep for `python3 json.load` / `json.dump` in-place state.json writes: zero hits.
- [ ] `bash -n` clean on the embedded bash of all 16 edited code files.
- [ ] `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` exits 0.
- [ ] `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` exits 0.
- [ ] `bash .claude/scripts/check-task-references.sh` passes.
- [ ] `bash .claude/scripts/check-extension-docs.sh` failure set unchanged from baseline (`literature` only).
- [ ] `specs/archive/state.json` and vault-path write-site counts unchanged in all three files that carry them.
- [ ] Zero files edited under `.claude/**`.

## Artifacts & Outputs

- `specs/957_convert_residual_state_json_writers/plans/01_convert-residual-state-writers.md` (this file)
- 16 converted code files under `agent-system/extensions/core/skills/**` and `agent-system/extensions/core/commands/**`
- 6 updated documentation files under `agent-system/extensions/core/context/**` and `agent-system/extensions/core/docs/**`
- `specs/957_convert_residual_state_json_writers/summaries/01_convert-residual-state-writers-summary.md`

## Rollback/Contingency

Every edit is confined to text files in the source store, and no schema, script, or mechanism changes. Rollback is a `git checkout` of the affected `agent-system/extensions/core/**` paths at any granularity — per file, per phase, or whole task — with no migration or state repair required. Because `.claude/**` is regenerated from the source store, no deploy-side cleanup is needed either; a redeploy after rollback restores the prior runtime behavior.

Per-phase commits (the default `per-substep` commit mode) keep the rollback granularity at the phase level. If the verification bar in Phase 10 surfaces a defect traceable to one phase, roll back that phase's files only and re-run it, rather than reverting the whole task.

Contingency if a converted site proves to require behavior `state-write.sh` cannot express (e.g. a write that genuinely must target a non-`specs/state.json` file, discovered mid-phase): leave that site hand-rolled, record it as a reasoned exclusion in the phase with evidence, and do not extend `state-write.sh` — extending the mechanism is out of scope and would need its own task.
