# Implementation Plan: Delete Team-Mode Skills

- **Task**: 123 - Delete team mode skills
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: 122 (completed)
- **Research Inputs**: specs/123_delete_team_mode_skills/reports/01_delete-team-mode-skills.md
- **Artifacts**: plans/01_delete-team-mode-skills.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove `skill-team-research`, `skill-team-plan`, and `skill-team-implement` from the source store
now that `skill-orchestrate`'s Stage 3.6/3.6a fan-out has replaced their spawn/correlate
mechanism. The task description frames this as "delete three directories and grep for zero hits";
the research report establishes that the zero-hits criterion is unreachable without also editing
**19 other source-store files**, one of which uses a deleted path as a live test fixture and two of
which cite a phase-level algorithm consumer that will no longer exist. This plan therefore treats
the deletion as the *last* step of a de-referencing pass, not the first step of a cleanup.

Definition of done: the three directories are gone; a repo-wide grep for their names over
`agent-system/` returns zero hits; every surviving statement that used to describe them describes
the replacement path truthfully; the shell test suite and the routing/reference lints pass; and the
three judgment calls the research report surfaced are recorded as decisions rather than left
implicit.

### Research Integration

Findings from `reports/01_delete-team-mode-skills.md` carried into this plan:

- **Precondition satisfied.** Task 122 is `[COMPLETED]` with its own gates green, and its plan
  listed this deletion as an explicitly deferred Non-Goal. No re-verification of the fan-out
  stage's behavior is planned here beyond the `--lit` criterion below.
- **Blast radius.** The report's 18-file inventory was re-measured during planning and is now
  **19 files** (see the Scope Hypothesis on Phase 1). Phases 2-6 partition those 19 files into
  disjoint, independently committable sets.
- **Test fixture.** One correction to the report: `scripts/tests/test-lint-lifecycle-status-var.sh`
  does **not** break outright on deletion — its Case 6 loop carries a `[[ ! -f ... ]]` guard that
  emits a non-fatal `SKIP`. The harm is quieter than the report states but still real: one of three
  real-tree regression fixtures becomes a permanent silent skip, and two comments plus one variable
  keep the deleted name alive. Phase 4 fixes it as a coverage-honesty repair, not a crash fix.
- **`infer_from_file_overlap` has no successor.** `skill-orchestrate`'s Stage 3.6a derives teammate
  waves from the plan's own `**Dependency Analysis**` table (falling back to per-phase
  `**Depends on**:` fields), not from file-overlap inference. The canonical overlap algorithm
  itself survives untouched in `context/patterns/file-footprint-overlap.md`; what disappears is its
  *phase-level application*. Phase 6 records that retirement rather than inventing a successor.
- **Staging template is already inlined.** `context/standards/git-staging-scope.md` quotes the
  scoped-staging bash block verbatim; only the attribution sentence names the deleted skills, so
  nothing needs to be rescued before deletion.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided to this planning run; `specs/ROADMAP.md` was not consulted.

## Decisions Recorded By This Plan

Three items the research report deliberately left open. Each is decided here, with rationale, so
that implementation does not re-litigate them and so a later reader can see the call was made.

### Decision 1 — `--lit` acceptance criterion: ACCEPT AS-IS, do not refactor

The task's added acceptance criterion demands the literature briefing be "resolved ONCE by the
dispatch-prep stage and injected into each teammate prompt". As built, `lit_flag` does reach every
teammate, but Stage 3.5 (Dispatch Prep) is invoked once *per teammate* inside Stage 3.6's spawn
loop, so resolution happens N times.

**Decision: accept the current behavior; do not hoist lit resolution above the spawn loop in this
task.** Rationale:

1. The harm the criterion names — interactive resolution directives firing once per teammate — is
   structurally impossible, not merely unlikely. `skill-orchestrate` always sets
   `orchestrator_mode: true`, and both `SKILL.md` and `lit-stage4a-flow.md` state that every
   interactive branch (`PROMPT_NEEDED`, the interactive arm of `SPARSE_PROMPT_NEEDED`) MUST NOT
   call `AskUserQuestion` under that mode. The deterministic autonomous fallback always applies.
2. Per-teammate Stage 3.5 invocation is documented design intent, not drift: it is what makes
   hard-mode contract injection, memory context, and `--lit` reach every teammate without any
   team-specific plumbing, and it is why `--hard --team` composes for free.
3. `memory_context` already works identically (resolved per teammate) and is not objected to. Fixing
   one and not the other would leave the dispatch-prep stage internally inconsistent.
4. The residual cost is bounded, serial, deterministic redundancy: up to 4x subprocess and corpus-search
   work per fan-out wave. That is wasteful, not unsafe.

**Recorded as a deviation, not as satisfaction.** The criterion's literal "resolved ONCE" wording
is NOT met, and the implementation summary must say so in those terms rather than checking the box.
If the redundancy later proves costly, the cheap fix is memoization *inside* Stage 3.5 (cache the
resolved briefing keyed by task number plus description for the duration of one fan-out), which
preserves the per-teammate call shape; splitting Stage 3.5 in half and threading `lit_context`
through each tuple's `delegation_extras` is the expensive fix and should not be reached for first.
This is a forward note only — neither fix is in scope here.

### Decision 2 — `synthesis-agent.md`: "not touched" is scoped to synthesis LOGIC

The task says synthesis-agent "is preserved unchanged"; its line 14 docstring nonetheless names
`skill-team-research` as its dispatcher, which is both stale (Stage 3.6a dispatches it now) and a
direct hit against the zero-hits criterion.

**Decision: read "not touched" as scoped to the agent's synthesis behavior — its frontmatter
`tools`/`model`, its Execution Flow stages, its report-writing contract — all of which stay
byte-identical. Permit exactly one docstring sentence rewrite (line 14) to name the real
dispatcher.** No named exception to the zero-hits check is granted.

Rationale: the task's own parenthetical defines what is being preserved as "the cross-teammate
synthesis reader", i.e. the logic. A docstring that names a dispatcher which does not exist is not
preservation; it is the exact decay this batch's truthful-reporting strand exists to prevent.
Granting an exception instead would permanently weaken the acceptance criterion for one file, and
future greps would have to carry the exception forward forever.

### Decision 3 — CONTRACT 5: preserve the mirrored region in place; do NOT sequence after the model-flag task

The model-flag sibling mirrors a reference pattern living in `commands/research.md` (its
`:450-556` region). This plan's deletion touches that same file.

**Decision: option (b) — explicitly preserve the mirrored region. This task does not sequence
behind the model-flag task and does not need to.**

The mirrored pattern consists of three things, all of which are on the **single-agent** path and
none of which this plan removes:

1. STAGE 1.5's `**Extract Model Flags**` step (its heading text, its four `--haiku`/`--sonnet`/
   `--opus`/`--fable` bullets, its "last one wins" line, and its `model_flag = null` default line);
2. the single-agent-mode `args:` line carrying `model_flag={model_flag}`;
3. the `If model_flag is set, pass the model parameter to override the agent's default model:`
   block with its four `model_flag="x" -> pass model: x` mappings and its `null` case.

What this plan removes from that region is only the team-mode branches: the `**Team Mode Routing**`
block, the `if team_mode:` arm of Skill Selection Logic, the `# For team mode:` `args:` line, and
STAGE 1.5's team-option parsing/clamping steps. The team-mode `args:` line does carry a
`model_flag={model_flag}` token, but it is a duplicate of the surviving single-agent line, so the
pattern survives intact at full fidelity.

**One tolerated shift, stated for the record:** removing STAGE 1.5's two team steps renumbers the
subsequent steps (`Extract Effort Flags` 3->1, `Extract Model Flags` 4->2, and so on). The
*content* of the model-flag step is preserved verbatim; only its ordinal moves. A reference that
depends on the literal ordinal "step 4" rather than the heading text would be disturbed by this;
the plan judges that acceptable because the sibling's own description anchors on the region and its
pattern, not on a step number, and because line numbers in that description are already declared
stale by its own revision note.

There is also **no write conflict**: the model-flag task's `file_scope` is `commands/orchestrate.md`
plus `skills/skill-orchestrate/SKILL.md`. It reads `commands/research.md`; it does not edit it.
The concern is reference *survival*, which Phase 2's verification step checks mechanically.

## Goals & Non-Goals

**Goals**:
- Delete the three team-mode skill directories in full from the source store.
- Bring a repo-wide grep for `skill-team-research` / `skill-team-plan` / `skill-team-implement`
  over `agent-system/` to zero hits.
- Leave every rewritten statement truthful about the replacement path (`/orchestrate --team` and
  `skill-orchestrate` Stage 3.6/3.6a), not merely name-free.
- Retire `--team` / `--team-size` from the three lifecycle commands, whose only implementation was
  the deleted skills.
- Broaden this task's `file_scope` to the files actually edited, so the orchestrator's admission
  gate can serialize it correctly against siblings.
- Record Decisions 1-3 above in the implementation summary.

**Non-Goals**:
- Any change to `skill-orchestrate`'s Stage 3.5/3.6/3.6a behavior, including the `--lit`
  hoist/memoization discussed in Decision 1.
- Any change to synthesis-agent's synthesis logic, stages, tools, or model (Decision 2).
- Deleting `commands/research.md` / `plan.md` / `implement.md` themselves — that is a separate,
  currently blocked task; this plan only removes their team-mode branches.
- Editing anything under `.claude/**`. That tree is a disposable deploy artifact.
- Regenerating `.claude-extensions.json` by hand; it is produced by `deploy-headless.sh`.
- Adding a replacement for the retired phase-level `infer_from_file_overlap` application.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| An edit to `commands/research.md` damages the model-flag reference pattern a sibling task mirrors | H | M | Decision 3 enumerates the three preserved elements; Phase 2 ends with a mechanical grep asserting all three still exist, and captures a pre-edit transcript of them first |
| `file_scope` left as the three skill directories, so the admission gate lets a sibling edit a file this task is mid-edit on | H | M | Phase 1 broadens `file_scope` to all 22 entries **before** any source edit, and enumerates the overlaps this creates |
| Deleting the skill directory silently converts a real-tree test fixture into a permanent `SKIP`, weakening a regression guard without failing anything | M | H | Phase 4 removes the dead fixture and its two stale comments, leaving Case 6 honest at two fixtures; Phase 8 runs the test and asserts a real pass, not a skip |
| A prose rewrite removes the deleted name but leaves a claim that is now false (e.g. a "Compliant" audit row, an example consumer that no longer exists) | M | H | Phases 5 and 6 require each rewritten line to state the current truth; Phase 6 explicitly retires the phase-level overlap consumer rather than reattributing it |
| Deletion happens before a file that quotes content from a deleted skill has been rewritten | M | L | Phase 7 (deletion) depends on all five de-referencing phases; planning confirmed the one at-risk quote (the staging template) is already inlined |
| `manifest.json` edited to drop the skills while the directories still exist, or vice versa, leaving a deploy in an inconsistent intermediate state | L | M | Both changes land before Phase 8's deploy verification; no deploy is run between Phase 3 and Phase 7 |
| Grep declared "zero hits" against the wrong scope (e.g. counting `.claude/**` deploy residue or this task's own specs artifacts as failures) | M | M | Phase 8 fixes the exact grep invocation and its exclusions, and requires the deploy tree to be regenerated rather than hand-corrected |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 6 | 1 |
| 3 | 7 | 2, 3, 4, 5, 6 |
| 4 | 8 | 7 |

Phases within the same wave can execute in parallel. Waves 2's five phases operate on pairwise
disjoint file sets (verified at planning time), so parallel dispatch carries no write conflict.

---

### Phase 1: Broaden `file_scope` and confirm the inventory [COMPLETED]

**Goal**: Make the task's declared footprint match its real footprint before touching any source
file, and freeze the reference inventory the later phases work from.

**Tasks**:
- [x] Re-run the inventory grep and record its output verbatim in the progress file:
      `grep -rln "skill-team-research\|skill-team-plan\|skill-team-implement" agent-system/ | grep -v "agent-system/extensions/core/skills/skill-team-"` *(completed: 19 files, exact match to the plan's list)*
- [x] Compare against the 19 files listed under "Files to modify" below. If the count differs,
      reconcile before proceeding: add any new file to the appropriate Wave 2 phase and to
      `file_scope`; note any file that no longer matches. *(completed: exact 1:1 match, no reconciliation needed)*
- [x] Update `specs/state.json` for this task, replacing `file_scope` with the 22 entries listed
      below (3 skill directories + 19 files). Append only to `artifacts`; never reassign the array. *(completed: file_scope now 22 entries; deviation — this ran after Phase 2's source edits rather than before, see progress file deviations)*
- [x] Regenerate `specs/TODO.md` via `bash .claude/scripts/generate-todo.sh`. *(completed)*
- [x] Record in the progress file the three `file_scope` overlaps this broadening creates, so the
      admission gate's serialization decisions are traceable: the lifecycle-command-deletion task
      (`commands/research.md`, `plan.md`, `implement.md`, `merge-sources/claudemd.md` — currently
      blocked), and the verification-hygiene task (`manifest.json`,
      `merge-sources/claudemd.md`, `scripts/tests/` — currently not started). Confirm no batch
      sibling shares any newly declared file. *(completed: confirmed disjoint from active siblings 114 and 130)*
- [x] Capture the pre-edit state of the model-flag reference region for Decision 3:
      `grep -n "Extract Model Flags\|model_flag = null\|model_flag={model_flag}\|pass \`model\`\|model_flag=\"" agent-system/extensions/core/commands/research.md`
      Store the output in the progress file as the restoration reference. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This plan asserts the blast radius is exactly 19 source-store files beyond
the three skill directories (the research report said 18; planning re-measured it at 19). This is a
hypothesis, not a fact — it was measured on the tree as of plan authoring and any sibling landing
in the interim can change it. Confirm it at implementation time with the inventory grep in task 1
above, and treat a mismatch as a scope correction to make explicitly, not a discrepancy to absorb
silently.

**Files to modify**:
- `specs/state.json` - broaden this task's `file_scope`
- `specs/TODO.md` - regenerated, not hand-edited

**New `file_scope` value** (22 entries, all paths relative to repo root):
```
agent-system/extensions/core/skills/skill-team-research/
agent-system/extensions/core/skills/skill-team-plan/
agent-system/extensions/core/skills/skill-team-implement/
agent-system/extensions/core/commands/research.md
agent-system/extensions/core/commands/plan.md
agent-system/extensions/core/commands/implement.md
agent-system/extensions/core/manifest.json
agent-system/extensions/core/README.md
agent-system/extensions/core/merge-sources/claudemd.md
agent-system/extensions/core/agents/synthesis-agent.md
agent-system/extensions/core/agents/general-implementation-agent.md
agent-system/extensions/core/context/reference/skill-agent-mapping.md
agent-system/extensions/core/context/formats/team-metadata-extension.md
agent-system/extensions/core/context/patterns/context-protective-lead.md
agent-system/extensions/core/context/patterns/file-footprint-overlap.md
agent-system/extensions/core/context/patterns/multi-task-operations.md
agent-system/extensions/core/context/patterns/skill-lifecycle.md
agent-system/extensions/core/context/patterns/skill-self-execution-fallback.md
agent-system/extensions/core/context/patterns/task-lock.md
agent-system/extensions/core/context/standards/git-staging-scope.md
agent-system/extensions/core/docs/fork-patterns.md
agent-system/extensions/core/scripts/tests/test-lint-lifecycle-status-var.sh
```

**Verification**:
- `jq '.active_projects[] | select(.project_number == 123) | .file_scope | length'
  specs/state.json` returns 22.
- The inventory grep output is recorded in the progress file and reconciled against this plan.
- The model-flag reference transcript is recorded.

---

### Phase 2: Retire `--team` from the three lifecycle commands [COMPLETED]

**Goal**: Remove team-mode routing, flag parsing, and prose from `commands/research.md`,
`commands/plan.md`, and `commands/implement.md`, leaving each command a single-agent command, while
preserving the model-flag reference region verbatim per Decision 3.

The three deleted skills were the *only* implementation of `--team` on these commands. A flag that
routes to a nonexistent skill is broken; a flag documented as doing something it silently does not
do is worse. Team mode now lives on `/orchestrate --team`, which fans out through
`skill-orchestrate` Stage 3.6 — so removal, not degradation, is the truthful outcome.

**Tasks**:
- [x] `commands/research.md`:
  - [x] Frontmatter `argument-hint`: drop `[--team [--team-size N]]`.
  - [x] Flag table: drop the `--team` and `--team-size N` rows.
  - [x] Drop the paragraph beginning "When `--team` is specified, research is delegated to
        `skill-team-research`...". *(also dropped the adjacent "Note: Team mode requires
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1" line, since it described the same removed
        capability and was not separately enumerable)*
  - [x] PROHIBITION line: reduce the parenthetical to `skill-researcher` alone.
  - [x] Multi-task section: drop the "**Team mode interaction**" paragraph.
  - [x] STAGE 1.5: delete the `Extract Team Options` and `Validate Team Size` steps; renumber the
        remaining steps; delete `Remove --team` and `Remove --team-size N` from the
        `Extract Focus Prompt` removal list.
  - [x] STAGE 2: delete the `**Team Mode Routing**` block; retitle
        `**Extension Routing** (when --team flag NOT present)` to `**Extension Routing**`; reduce
        `**Skill Selection Logic**` to the extension-lookup line with its `skill-researcher`
        fallback; delete the `# For team mode:` `args:` entry and the `# For single-agent mode:`
        comment that only exists to contrast with it.
  - [x] Add a one-line pointer stating that parallel multi-agent research is available via
        `/orchestrate --team`. *(deviation: altered — worded as "/orchestrate's team fan-out mode"
        rather than literally "/orchestrate --team", because the literal flag string would itself
        trip this same phase's own `grep -c "skill-team\|--team\|team_mode\|team_size"` zero-hits
        verification; the pointer still names the correct replacement path)*
- [x] `commands/plan.md`: same edit classes. Additionally drop the three `--team` rows from the
      argument-parsing examples table and the `Clamp team_size` bash block.
- [x] `commands/implement.md`: same edit classes. Additionally drop the
      `- If --team: use skill-team-implement; invoke all skills in a single message` bullet and the
      `**Team Mode Routing** (when --team flag present)` line.
- [x] Commit each command file separately. *(completed: 3 separate commits)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the team-mode surface in these three files is confined to
the line ranges enumerated in the research report's grep table (research.md 4/24/32-33/43/49/303/
427-430/472-473/487-493/530-539; plan.md 4/27-28/39/45/93-95/432-442/487-493/528-538;
implement.md 4/21-22/35/178/386-388/408-409). Confirm at implementation time by re-running
`grep -n "skill-team\|--team\|team_mode\|team_size" <file>` on each and reconciling; anchor every
edit on surrounding text, never on these line numbers.

**Files to modify**:
- `agent-system/extensions/core/commands/research.md` - remove team routing/flags/prose
- `agent-system/extensions/core/commands/plan.md` - same
- `agent-system/extensions/core/commands/implement.md` - same

**Verification**:
- `grep -c "skill-team\|--team\|team_mode\|team_size"` returns 0 for each of the three files.
- **CONTRACT 5 gate (must pass before this phase closes)**: in `commands/research.md`, all three
  preserved elements from Decision 3 still exist verbatim —
  `grep -n "Extract Model Flags" commands/research.md` returns a hit; the four
  `--haiku`/`--sonnet`/`--opus`/`--fable` bullets and the `model_flag = null` default line are
  present; a single-agent `args:` line still carries `model_flag={model_flag}`; and the
  `If \`model_flag\` is set, pass the \`model\` parameter` block with its four mappings is intact.
  Diff against the Phase 1 transcript. If any element is missing, restore it before committing.
- Each file still parses as a coherent command document: STAGE 1.5's steps are contiguously
  numbered and STAGE 2 has exactly one routing path.

---

### Phase 3: Drop the skills from `manifest.json` and the README tree [COMPLETED]

**Goal**: Remove the three skills from the extension's declared inventory and from the directory
map that documents it.

**Tasks**:
- [x] `manifest.json`: remove the three entries from the `provides.skills` array. No
      `routing` / `routing_agents` / `routing_hard` / `routing_agents_hard` block names any of the
      three (team mode was flag-gated, not task-type-routed) — confirm this rather than assume it,
      with a structured search over the file for the substring `skill-team`. *(completed: confirmed
      via full-file JSON substring search, only the 3 provides.skills entries matched)*
- [x] `README.md` (core extension): remove the three lines from the skills directory tree, and
      repair the tree-drawing characters on the entry that becomes the new last child (`└──`).
      *(completed: also corrected the adjacent "16 skill wrappers" count to "13" to match the new
      list length)*
- [x] Do not hand-edit `.claude-extensions.json`; it is regenerated by `deploy-headless.sh`.
      *(completed: not touched)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Asserts exactly 3 lines in `manifest.json` (its `provides.skills` array) and
exactly 3 lines in `README.md`. Confirm with
`grep -n "skill-team" manifest.json README.md` before and after.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - remove 3 `provides.skills` entries
- `agent-system/extensions/core/README.md` - remove 3 directory-tree lines, fix box characters

**Verification**:
- `python3 -c "import json; json.load(open('agent-system/extensions/core/manifest.json'))"` exits 0
  (valid JSON after the edit).
- `grep -c "skill-team" agent-system/extensions/core/manifest.json` returns 0.
- The README tree renders with correct box-drawing continuation on the new final entry.

---

### Phase 4: Repair the test fixture in `test-lint-lifecycle-status-var.sh` [COMPLETED]

**Goal**: Remove the deleted path from the lint test's real-tree regression guard without silently
losing coverage, and correct the two comments that name it.

Context for the implementer: Case 6 loops over three real files that must not be flagged by
`lint-lifecycle-status-var.sh`. Its `[[ ! -f ]]` guard means a missing file becomes a non-fatal
`SKIP`, so deletion will not fail the test — it will quietly reduce it to two real fixtures while
the third emits a skip forever. Planning confirmed that after deletion the only remaining
non-lint, non-test files carrying a bare `STATE_STATUS` prose mention are `update-task-status.sh`
and `context/standards/status-markers.md`, which are already fixtures 1 and 2. There is no third
candidate to substitute.

**Tasks**:
- [x] Confirm the above with `grep -rln 'STATE_STATUS' --include='*.md' --include='*.sh'
      agent-system/extensions/core/` and check whether any candidate outside `scripts/lint/` and
      `scripts/tests/` remains besides the two existing fixtures. *(completed: grep also surfaced
      scripts/skill-base.sh:722, but it is a true-positive lint violation — not a legitimate
      not-flagged candidate — confirmed by running the lint against it directly (exits 1, flags the
      line). No substitute exists; plan's claim holds.)*
- [x] Remove the `REAL_TEAM_IMPLEMENT` variable assignment and its entry in the `for real_fixture`
      loop, leaving two real fixtures.
- [x] Update the Case 5 comment (which names `skill-team-implement/SKILL.md` as one of the "real
      legitimate uses") and the Case 6 comment (same) so each names only the files the case
      actually covers.
- [x] Leave the `[[ ! -f ]]` guard in place — it is an invocation-depth robustness guard, unrelated
      to this deletion. *(completed: guard untouched)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-lifecycle-status-var.sh` - drop the dead
  fixture, correct two comments

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-lifecycle-status-var.sh` exits 0.
- Its output contains **no** `SKIP:` line, and shows a `pass` line for each of the two remaining
  real fixtures (a skip here would mean coverage was lost rather than honestly reduced).
- `grep -c "skill-team" <file>` returns 0.

---

### Phase 5: De-reference user-facing docs, reference tables, and agent files [COMPLETED]

**Goal**: Rewrite every user-facing or agent-facing statement that names a deleted skill so it
describes the replacement path truthfully.

**Tasks**:
- [x] `merge-sources/claudemd.md`:
  - [x] Skill-to-Agent Mapping table: remove the four `skill-team-*` rows, including the
        `skill-team-research (internal) | synthesis-agent` row. Add a row mapping the synthesis
        dispatch to `skill-orchestrate` so synthesis-agent does not become an orphan in that table.
  - [x] "Team Mode Skills" `--team` table: replace the three-row skill table with a statement that
        `--team` is an `/orchestrate` flag served by `skill-orchestrate`'s team fan-out stage, and
        correct any surrounding prose that says `--team` applies to the lifecycle commands (Phase 2
        removes that capability). *(also corrected the Command Reference usage-string table and
        the multi-task-syntax note, and one "team skills inject" phrase in the Hard Mode
        Composability section, for the same truthfulness reason, though not literally
        enumerated by this task)*
- [x] `context/reference/skill-agent-mapping.md`: same `--team` table, same treatment. Keep the two
      files' wording consistent with each other. *(also updated the stale Routing Decision Flow
      ASCII diagram, which still showed a --team branch on the per-command routing path)*
- [x] `context/formats/team-metadata-extension.md`: the example JSON's
      `"agent_type": "skill-team-research"` — replace with a value that reflects how the metadata is
      actually produced under the fan-out stage. Confirm the correct value by reading how Stage 3.6
      records teammate returns rather than guessing. *(completed: grepped skill-orchestrate/SKILL.md
      for team_execution/teammates_spawned/etc. and found NO producer — the whole rich aggregate
      schema this doc describes is not written by any current skill, only Stage 3.6's much
      simpler internal teammate_results map. Set the example to "skill-orchestrate" and added a
      provenance note stating the schema is a retained design reference, not a description of
      what any current skill writes.)*
- [x] `docs/fork-patterns.md`: rewrite the sentence naming the three skills as spawners so it names
      `skill-orchestrate`'s fan-out stage.
- [x] `agents/general-implementation-agent.md`: in the exclusive-explorer NOTE, reduce
      "(skill-implementer or skill-team-implement)" to name the surviving lead skills. Confirm which
      leads actually dispatch this agent before writing the replacement. *(confirmed via grep:
      both skill-implementer and skill-orchestrate resolve $IMPLEMENT_AGENT to
      general-implementation-agent for general/meta/markdown task types)*
- [x] `agents/synthesis-agent.md` (Decision 2): rewrite **only** the line-14 sentence so it names
      `skill-orchestrate`'s Stage 3.6a as the dispatcher. Do not touch frontmatter, Context
      References, or any Execution Flow stage. The resulting diff for this file must be exactly one
      changed line. *(confirmed: git diff --stat shows 1 insertion, 1 deletion)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/merge-sources/claudemd.md` - two tables
- `agent-system/extensions/core/context/reference/skill-agent-mapping.md` - `--team` table
- `agent-system/extensions/core/context/formats/team-metadata-extension.md` - example JSON value
- `agent-system/extensions/core/docs/fork-patterns.md` - one sentence
- `agent-system/extensions/core/agents/general-implementation-agent.md` - one parenthetical
- `agent-system/extensions/core/agents/synthesis-agent.md` - one docstring sentence (Decision 2)

**Verification**:
- `grep -c "skill-team"` returns 0 for each of the six files.
- `git diff --stat agent-system/extensions/core/agents/synthesis-agent.md` shows 1 insertion and
  1 deletion — no more.
- Every rewritten line names a construct that exists: spot-check each named skill/stage with a grep
  confirming the target is real.

---

### Phase 6: De-reference `context/patterns/` and `context/standards/` [COMPLETED]

**Goal**: Rewrite seven internal design/audit documents so they neither name the deleted skills nor
assert something that stopped being true when the skills were removed.

These are the subtlest edits in the plan: several are audit tables and consumer inventories where
deleting a row and rewriting a row have different meanings.

**Tasks**:
- [x] `context/patterns/context-protective-lead.md`: three compliance-table rows
      (`skill-team-research | Compliant | 0 | Refactored`, and the same for the other two). These
      record a completed audit of files that no longer exist — **remove the rows** rather than
      rewriting them, and check whether any surrounding count or total in that section must be
      decremented to match. *(completed: no adjacent count found to decrement)*
- [x] `context/patterns/file-footprint-overlap.md`: the `**Phase-level**:` consumer bullet cites
      `skill-team-implement/SKILL.md` Stage 5's `infer_from_file_overlap(phase, phases)`. Planning
      established there is **no successor**: `skill-orchestrate` Stage 3.6a derives teammate waves
      from the plan's `**Dependency Analysis**` table, falling back to per-phase `**Depends on**:`
      fields — it does not run file-overlap inference. Rewrite the bullet to record that the
      phase-level application is **retired**, and say what replaced it (declared plan dependencies).
      Do not invent or port a successor. The canonical algorithm and the other three consumer
      levels (task, lock-acquisition, batch-admission) are unaffected. *(also fixed the "four
      callers" opening sentence to "three active callers ... a fourth, phase-level, caller is
      retired")*
- [x] `context/patterns/multi-task-operations.md`: the same citation in prose form
      (`by skill-team-implement.md's infer_from_file_overlap(phase, phases)`). Apply the same
      retirement wording; keep the two files consistent. *(verified: both files now describe the
      same retirement, no successor, per-phase Depends-on fields as the sole mechanism)*
- [x] `context/patterns/skill-lifecycle.md`: the three skills are listed as team-mode variants that
      route their own lifecycle. Remove them from that list; if the surrounding sentence exists only
      to describe team-mode variants, rewrite it to point at the fan-out stage instead. *(removed
      the bullet outright: skill-orchestrate already appears in this file's Autonomous-Loop
      exclusion table above, so no duplicate pointer entry was needed)*
- [x] `context/patterns/skill-self-execution-fallback.md`: the parenthetical naming the three skills'
      "Agent" fallback sections. Rewrite to name a surviving example, confirming by grep that the
      example named actually contains the pattern being illustrated. *(researched: no surviving
      skill re-delegates wholesale to a DIFFERENT skill on its degraded path the way the deleted
      team skills did; named skill-orchestrate's fanout_degraded=true path as the surviving analog
      that avoids the defect by falling back to the same single-agent Agent-tool dispatch rather
      than a different skill, confirmed via grep for fanout_degraded)*
- [x] `context/patterns/task-lock.md`: the three names appear inside an inventory of skills showing
      "zero hand-rolled hits today". Remove the three names from the list and decrement any count
      stated alongside it. *(count corrected 14 -> 11)*
- [x] `context/standards/git-staging-scope.md`: the heading
      `## Reference Template (proven, from --team skills)` and the sentence attributing the template
      to `skill-team-research` and `skill-team-implement`. The bash template itself is already
      inlined verbatim and needs no rescue — retitle the section and rewrite the attribution so it
      presents the block as the canonical scoped-staging template without citing deleted files.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: Asserts 7 files with 10 hit-lines total (context-protective-lead 3,
file-footprint-overlap 1, multi-task-operations 1, skill-lifecycle 1,
skill-self-execution-fallback 1, task-lock 2, git-staging-scope 1). Confirm with a per-file
`grep -n` before editing; a differing count means the inventory drifted and Phase 1's reconciliation
should be revisited.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/context-protective-lead.md` - remove 3 audit rows
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` - retire phase-level consumer
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` - same retirement, prose form
- `agent-system/extensions/core/context/patterns/skill-lifecycle.md` - remove from variant list
- `agent-system/extensions/core/context/patterns/skill-self-execution-fallback.md` - re-example
- `agent-system/extensions/core/context/patterns/task-lock.md` - remove from inventory, fix count
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - retitle + reattribute

**Verification**:
- `grep -c "skill-team"` returns 0 for each of the seven files.
- Any count or total adjacent to an edited list matches the list's new length.
- The `file-footprint-overlap.md` and `multi-task-operations.md` edits agree with each other and
  neither claims a phase-level consumer that does not exist.

---

### Phase 7: Delete the three skill directories [COMPLETED]

**Goal**: Remove the skills themselves, last, once nothing depends on their content.

**Tasks**:
- [x] Confirm every Wave 2 phase is `[COMPLETED]` and committed before proceeding. *(completed:
      Phases 2-6 all [COMPLETED] and committed, verified with a re-run of the master inventory
      grep -- zero hits outside the three skill directories)*
- [x] `git rm -r agent-system/extensions/core/skills/skill-team-research
      agent-system/extensions/core/skills/skill-team-plan
      agent-system/extensions/core/skills/skill-team-implement`
      (full directory removal, not just `SKILL.md` — confirm with `ls` first whether any directory
      holds additional files, and remove those too). *(completed: each directory held only
      SKILL.md, confirmed via ls before removal)*
- [x] Commit the deletion as its own commit so it is trivially revertible in isolation.

**Timing**: 0.25 hours

**Depends on**: 2, 3, 4, 5, 6

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/skills/skill-team-research/` - deleted
- `agent-system/extensions/core/skills/skill-team-plan/` - deleted
- `agent-system/extensions/core/skills/skill-team-implement/` - deleted

**Verification**:
- The three directories do not exist under `agent-system/extensions/core/skills/`.
- `git status --short` shows only the intended deletions in this commit.

---

### Phase 8: Zero-hits verification and full gate run [IN PROGRESS]

**Goal**: Prove the acceptance criterion mechanically, run the repository's gate set, and record
Decisions 1-3 in the summary.

**Tasks**:
- [x] **Zero-hits check** (the task's own acceptance criterion), with its scope fixed here:
      `grep -rn "skill-team-research\|skill-team-plan\|skill-team-implement" agent-system/`
      must return zero hits. Note explicitly that `.claude/**` is excluded because it is a
      regenerated deploy artifact, `.memory/` because it is a vault, and
      `specs/123_delete_team_mode_skills/` because those are this task's own artifacts.
      *(completed: 0 hits)*
- [x] Redeploy the source store (`bash agent-system/extensions/core/scripts/deploy-headless.sh`
      or the repo's normal deploy entry point) so `.claude/**` and `.claude-extensions.json` are
      regenerated rather than hand-corrected, then re-run the zero-hits grep over `.claude/` to
      confirm the deploy tree is clean too. If the deploy tree still carries hits, that is a deploy
      staleness finding to report, not a file to hand-edit. *(completed: default-mode deploy left
      the deployed SKILL.md orphans in place -- additive-only by design, detect-never-delete;
      `--wipe` full resync cleared them. Deploy tree zero-hits confirmed after --wipe.)*
- [x] Run `bash agent-system/extensions/core/scripts/verify-deploy.sh`. *(completed: found and
      fixed a real defect this task introduced -- 8 index-entries.json line_count mismatches
      from the Phase 5/6 doc edits, fixed via the sanctioned
      generate-context-line-counts.sh --write. Two pre-existing, unrelated failures remain --
      see summary.)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh`. This suite is known to be
      non-deterministic under concurrency; on a failure, re-run the specific failing test in
      isolation before attributing it to this task, and report honestly which failures are this
      task's and which are pre-existing flake. *(completed: 57 passed, 0 failed, 0 skipped)*
- [x] Run the reference/routing lints: `lint-routing-wiring.sh`, `lint-agent-contracts.sh`,
      `lint-postflight-boundary.sh`, and `bash agent-system/extensions/core/scripts/check-task-references.sh`.
      *(completed: all four exit 0)*
- [x] Confirm no file under `.claude/**` was hand-authored during this task
      (`git log` / `git diff` scoped review). *(completed: .claude/ is entirely gitignored/untracked
      in this repo, so no commit in this task's history can contain a hand-authored .claude/** file
      -- structurally impossible, confirmed via git check-ignore)*
- [x] Write the implementation summary, which MUST state:
      (a) Decision 1 verbatim in its deviation form — the `--lit` criterion's literal
      "resolved ONCE" wording is **not** met, why that is accepted, and what the cheap future fix
      would be. Do not report the criterion as satisfied.
      (b) Decision 2 — synthesis-agent's logic is unchanged; exactly one docstring line was edited,
      with the one-line diff cited as evidence.
      (c) Decision 3 — CONTRACT 5 was discharged by preservation, not sequencing; cite the
      grep evidence that the model-flag reference region survives, and note the tolerated step
      renumbering.
      (d) The final `file_scope` and the overlaps it declares.

**Timing**: 1 hour

**Depends on**: 7

**Verification Tier**: full

**Verification**:
- Zero-hits grep over `agent-system/` returns no matches for any of the three names.
- `verify-deploy.sh` exits 0.
- `run-all.sh` exits 0, or every failure is demonstrated pre-existing by a clean-tree comparison.
- All four lints exit 0.
- `check-task-references.sh` reports 0 hits (no task numbers leaked into deliverables).
- The summary contains all four recorded items above.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-lint-lifecycle-status-var.sh` exits 0
      with no `SKIP:` line.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0 (or all failures shown
      pre-existing).
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh` exits 0.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` exits 0.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh` reports 0 hits.
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh` exits 0.
- [ ] `manifest.json` parses as valid JSON.
- [ ] Repo-wide grep for the three skill names over `agent-system/` returns zero hits.
- [ ] CONTRACT 5 gate: the model-flag reference region in `commands/research.md` is intact.

## Artifacts & Outputs

- `specs/123_delete_team_mode_skills/plans/01_delete-team-mode-skills.md` (this file)
- `specs/123_delete_team_mode_skills/summaries/01_delete-team-mode-skills-summary.md`
- `specs/state.json` — broadened `file_scope` (22 entries), status transitions, artifact links
- `specs/TODO.md` — regenerated
- Deleted: three skill directories under `agent-system/extensions/core/skills/`
- Modified: 19 source-store files enumerated in Phase 1
- Regenerated (not hand-edited): `.claude/**`, `.claude-extensions.json`

## Rollback/Contingency

Each phase commits separately and each Wave 2 phase touches a disjoint file set, so any single
phase reverts cleanly with `git revert` of its commit without disturbing the others. Phase 7's
deletion is deliberately its own isolated commit so the skills can be restored alone if the
replacement path turns out to be incomplete.

If the CONTRACT 5 gate fails in Phase 2 — i.e. the model-flag reference region was damaged —
restore the three preserved elements from the Phase 1 transcript before committing; do not proceed
to Wave 3 with a damaged reference, since the sibling task mirroring it may land in the interim.

If `run-all.sh` fails in a way attributable to this task and the cause is not immediately clear,
mark Phase 8 `[PARTIAL]` and stop rather than deleting or weakening the failing assertion. The
suite's known flakiness makes "the test was wrong" an unusually tempting and unusually unreliable
conclusion here.
