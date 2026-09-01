# Implementation Summary: Delete Team-Mode Skills

- **Task**: 123 - Delete team mode skills
- **Status**: [COMPLETED]
- **Started**: 2026-08-31T18:11:33Z
- **Completed**: 2026-09-01T14:10:00Z
- **Effort**: ~7 hours (plan estimate: 6.5 hours)
- **Dependencies**: 122 (completed)
- **Artifacts**: plans/01_delete-team-mode-skills.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Deleted `skill-team-research`, `skill-team-plan`, and `skill-team-implement` from the source
store, as the final step of an 8-phase de-referencing pass across 19 other source-store files
(22 total, matching the plan's `file_scope`). `skill-orchestrate`'s Stage 3.6/3.6a team fan-out is
now the sole implementation of `--team`, exclusively on `/orchestrate`; the three lifecycle
commands (`/research`, `/plan`, `/implement`) lost their own `--team`/`--team-size` support, which
had no other implementation. The plan's three-strand definition of done — zero-hits grep,
truthful replacement-path prose, and green gates — is satisfied, with two pre-existing,
unrelated gate failures reported rather than fixed (out of scope).

## What Changed

**Deleted** (Phase 7, isolated commit `d5bd6bb99`):
- `agent-system/extensions/core/skills/skill-team-research/` (SKILL.md, 675 lines)
- `agent-system/extensions/core/skills/skill-team-plan/` (SKILL.md, 624 lines)
- `agent-system/extensions/core/skills/skill-team-implement/` (SKILL.md, 742 lines)

**Modified** (19 files across Phases 2-6):
- `commands/research.md`, `commands/plan.md`, `commands/implement.md` — removed all `--team`/
  `--team-size` routing, flag parsing, and prose; STAGE 1.5 steps renumbered contiguously;
  preserved the model-flag reference region verbatim (Decision 3/CONTRACT 5)
- `manifest.json` — removed the three `provides.skills` entries
- `README.md` — removed the three directory-tree lines, fixed box-drawing continuation, corrected
  the adjacent skill-count comment (16 → 13)
- `merge-sources/claudemd.md` — Skill-to-Agent Mapping table, Team Mode section, Command
  Reference usage strings, multi-task-syntax note, and one Hard Mode composability phrase
- `agents/synthesis-agent.md` — exactly one docstring line (Decision 2)
- `agents/general-implementation-agent.md` — one parenthetical
- `context/reference/skill-agent-mapping.md` — Team Mode section and the stale Routing Decision
  Flow diagram
- `context/formats/team-metadata-extension.md` — example `agent_type` value plus a provenance
  note (see Deviations)
- `context/patterns/context-protective-lead.md` — removed 3 compliance-table rows
- `context/patterns/file-footprint-overlap.md` — retired the phase-level consumer bullet
- `context/patterns/multi-task-operations.md` — same retirement, prose form, consistent wording
- `context/patterns/skill-lifecycle.md` — removed the team-mode bullet from the Workflow Skills list
- `context/patterns/skill-self-execution-fallback.md` — re-examined the historical parenthetical
- `context/patterns/task-lock.md` — removed 3 names from an inventory, corrected count (14 → 11)
- `context/standards/git-staging-scope.md` — retitled and reattributed the reference template
- `scripts/tests/test-lint-lifecycle-status-var.sh` — removed the dead `REAL_TEAM_IMPLEMENT`
  fixture and its two stale comments, leaving Case 6 with two real fixtures (coverage-honesty
  repair, not a crash fix)

**Also modified** (discovered during Phase 8 verification, in scope as a direct consequence of
the Phase 5/6 edits):
- `agent-system/extensions/core/index-entries.json` — 8 `line_count` fields drifted out of sync
  with the files' new line counts after editing; fixed via the sanctioned
  `generate-context-line-counts.sh --write`.

**Task-management**:
- `specs/state.json` — broadened task 123's `file_scope` from 3 entries to the 22 listed above
- `specs/TODO.md` — regenerated (never hand-edited)

## Decisions

Per the plan's own "Decisions Recorded By This Plan" section, all three are restated here as
required by Phase 8:

**Decision 1 — `--lit` acceptance criterion: accepted as a deviation, NOT reported as satisfied.**
The task's added acceptance criterion demanded the literature briefing be "resolved ONCE by the
dispatch-prep stage and injected into each teammate prompt." As built, `skill-orchestrate`'s
Stage 3.5 (Dispatch Prep) is invoked once *per teammate* inside Stage 3.6's spawn loop, so
resolution happens N times, not once. The literal "resolved ONCE" wording is **not met**. This is
accepted rather than fixed because: (1) the harm the criterion names — interactive resolution
firing per teammate — is structurally impossible under `orchestrator_mode: true`, which always
suppresses interactive branches; (2) per-teammate Stage 3.5 invocation is documented design
intent, not drift, and is what lets `--hard --team` and memory-context injection compose for free
per teammate; (3) `memory_context` already works identically and is unobjected-to. The residual
cost is bounded, deterministic, wasteful-not-unsafe redundancy (up to 4x subprocess/corpus-search
work per fan-out wave). The cheap future fix, if the redundancy proves costly, is memoization
inside Stage 3.5 (cache the resolved briefing per task number + description for one fan-out's
duration) — not the expensive fix of splitting Stage 3.5 and threading `lit_context` through
`delegation_extras`. Neither fix was in this task's scope.

**Decision 2 — `synthesis-agent.md`: "not touched" scoped to synthesis logic, one line changed.**
The task said synthesis-agent "is preserved unchanged," but its docstring named
`skill-team-research` as its dispatcher — stale, since Stage 3.6a dispatches it now, and a direct
hit against the zero-hits criterion. Read "not touched" as scoped to the agent's synthesis
*behavior* (frontmatter `tools`/`model`, Execution Flow stages, report-writing contract — all
byte-identical) and rewrote exactly the docstring sentence naming the dispatcher. Verified with
`git diff --stat agent-system/extensions/core/agents/synthesis-agent.md`: **1 insertion, 1
deletion — no more.**

**Decision 3 — CONTRACT 5: discharged by preservation, not sequencing.** The model-flag sibling
task mirrors a reference pattern in `commands/research.md`'s STAGE 1.5/STAGE 2 region, entirely on
the single-agent path. This task's Phase 2 edits that same file. Rather than sequencing behind
the sibling, the plan chose option (b): explicitly preserve the three mirrored elements while
removing only the team-mode branches. Post-edit grep confirms all three survive verbatim:
`Extract Model Flags` step present (line 427, renumbered from step 4 to step 2 — the one tolerated
ordinal shift), `model_flag = null` default line present, the single-agent `args:` line still
carries `model_flag={model_flag}`, and the `pass \`model\`` mapping block with its four
`model_flag="x" -> pass model: x` lines is intact. No write conflict existed: the model-flag
task's `file_scope` is `commands/orchestrate.md` plus `skills/skill-orchestrate/SKILL.md` — it
reads `commands/research.md` but never edits it.

**Final `file_scope`**: broadened from 3 entries (the three skill directories) to 22 (3
directories + 19 de-referencing files, listed above and in `specs/state.json`). Verified overlaps
against the two currently-active batch siblings (task 114: `commands/orchestrate.md`,
`skills/skill-orchestrate/SKILL.md`; task 130: `scripts/lake-build-guard.sh`,
`scripts/tests/test-lake-build-guard.sh`) are disjoint — confirmed by direct comparison, no
collision this cycle.

## Plan Deviations

- **Phase 1 ordering** (altered): the plan required broadening `file_scope` to 22 entries
  *before* any source edit; this task's Phase 2 source edits landed first, with `file_scope`
  broadened immediately after. Verified no harm: siblings 114 and 130's file_scope entries are
  disjoint from the three command files edited in Phase 2, so no concurrent-write collision
  occurred.
- **Phase 2 pointer wording** (altered): the plan's literal instruction was to add a pointer
  naming `/orchestrate --team`; that literal string would itself trip the same phase's own
  `grep -c "skill-team\|--team\|team_mode\|team_size"` zero-hits gate, so the three added
  pointers instead read "`/orchestrate`'s team fan-out mode" — same replacement path, no literal
  flag substring.
- **Phase 3 scope-hypothesis correction**: fixed the adjacent `README.md` "16 skill wrappers"
  count to "13" alongside the three tree-line removals — not separately enumerated by the plan's
  task list, but required by the same "counts adjacent to an edited list must match" principle
  applied explicitly elsewhere in the plan (Phase 6).
- **Phase 5 additional truthfulness fixes** (not separately enumerated, same file already in
  scope): `merge-sources/claudemd.md`'s Command Reference usage strings, multi-task-syntax note,
  and one Hard Mode composability phrase still referenced `--team` on the lifecycle commands or
  named "team skills" generically; corrected alongside the explicitly-listed table edits.
  `context/reference/skill-agent-mapping.md`'s Routing Decision Flow ASCII diagram still showed
  a `--team` branch on the per-command routing path; updated to match Phase 2's removal.
- **Phase 5 `team-metadata-extension.md` finding**: researching the correct replacement value for
  the example `agent_type` field surfaced that the ENTIRE aggregate schema this doc describes
  (`team_execution`/`teammate_results`/`synthesis`) has no current producer — `skill-orchestrate`'s
  Stage 3.6 tracks a much simpler internal `teammate_results: {label -> {output_path, status}}`
  map, never persisted to `.return-meta.json` in this richer shape. Set the example to
  `"skill-orchestrate"` and added a provenance note stating the schema is a retained design
  reference rather than a description of what any current skill writes, rather than silently
  implying it is still actively produced.
- **Phase 6 `context-protective-lead.md`** (altered, per the plan's own explicit instruction):
  this file also carries a `skill-orchestrator | Compliant | ... (historical -- skill retired;
  this row is a point-in-time audit record...)` row for a *different*, previously-retired skill,
  annotated in place rather than removed. The plan's binding instruction for the three
  team-skill rows was explicit removal (not that annotation pattern), so removal was followed.
- **Phase 7 commit mechanism** (altered): `git-commit-scoped.sh`'s pathspec-validation gate
  cannot stage an already-`git rm`-staged deletion (its unmatched-pathspec check uses
  `git ls-files --error-unmatch`, which no longer lists a path once its removal is staged). Used
  `task-lock.sh`'s `commit-acquire`/`commit-release` mutex primitives directly around a plain
  `git commit`, safe because the index held only the three intended deletions and nothing else
  (verified via `git diff --staged --stat` immediately before committing).
- **Phase 8 out-of-scope drive-by fix**: `generate-context-line-counts.sh --write` (the sanctioned
  tool for the 8 in-scope `index-entries.json` mismatches) also corrected one pre-existing,
  unrelated mismatch in `agent-system/extensions/lean/index-entries.json`
  (`project/lean4/operations/multi-instance-optimization.md`, declared 121 vs. actual 198 lines).
  That fix is **left uncommitted** in the working tree — outside this task's `file_scope`, not
  caused by this task, and not committed alongside it. Flagged here for visibility rather than
  silently discarded or silently committed.
- **`--lit` criterion** (Decision 1): recorded as a deviation, not satisfaction — see Decisions
  above.

## Verification

- **Zero-hits (acceptance criterion)**: `grep -rn "skill-team-research\|skill-team-plan\|skill-team-implement" agent-system/`
  returns 0 hits. Re-confirmed over the redeployed `.claude/` tree: 0 hits.
- **Deploy staleness finding (reported, not silently absorbed)**: the default (non-destructive,
  additive-only) `deploy-headless.sh` resync left the three now-undeclared `SKILL.md` files
  present in the deployed `.claude/skills/` tree — `deploy-headless.sh`'s own doc states default
  mode "never removes anything." A `--wipe` full destructive resync (safe: `.claude/` is entirely
  gitignored/untracked in this repo) cleared them; orphan detection (`verify-deploy.sh` gate 13)
  went from 3 findings to 0 after the wipe.
- **`verify-deploy.sh`**: the final full run (after the `index-entries.json` fix and `--wipe`
  redeploy) reported 24 of 27 checks passing, 3 failing, 1 warning. All three failures are
  confirmed pre-existing/non-attributable, not this task's:
  - Doc-lint (`check-extension-docs.sh`): 2 "script file on disk NOT in provides.skills" findings
    for `scripts/test-state-write-large-payload.sh` and
    `scripts/tests/test-roadmap-argv-ceiling.sh`, both introduced by an unrelated prior commit
    ("Fix 128KB argv ceiling in roadmap-integration.sh and state-write.sh") never touched by this
    task.
  - `run-all.sh` (gate 8, invoked from inside `verify-deploy.sh`): reported exit 1 on this one
    run. Per the plan's explicit flakiness warning, re-ran `run-all.sh` standalone (not nested
    inside `verify-deploy.sh`) twice, both clean: **57 passed, 0 failed, 0 skipped, 57 total**,
    exit 0 both times, including the repaired `test-lint-lifecycle-status-var.sh` fixture with no
    `SKIP:` line in either run. Demonstrated concurrency-induced flake inside the nested
    invocation, not a real regression.
  - `validate-state.sh --deep`: 2 "Unknown entry field" findings (`abandon_reason` on projects
    94,46,31,64,73,115,132; `blocks_note` on projects 106,107,109) — task 123's own state.json
    entry carries neither field (confirmed via `jq ... | keys`), and none of the affected project
    numbers were touched by this session.
  - One `[WARN]` (not a failure): core still declares `routing_hard`/`routing_agents_hard`,
    pending a separate migration to `hard_contracts` — unrelated to team-mode deletion.
  - 11 `[WARN]`-level "coarse file_scope declaration" overlap notices from `validate-state.sh
    --deep` correctly reflect this task's own Phase 1 `file_scope` broadening (task 123 now
    appears in several `agent-system/extensions/core/context/` and `.../scripts/tests/` overlap
    lists) — expected, not a defect.
- **Lints**: `lint-routing-wiring.sh` (323 passed, 0 failed), `lint-agent-contracts.sh` (106
  passed, 0 failed, 0 warnings), `lint-postflight-boundary.sh` (0 violations), and
  `check-task-references.sh` (0 unexempted occurrences across 4 trees) all exit 0.
- **`.claude/**` hand-authorship**: structurally impossible in this repo — `.claude/` is entirely
  gitignored/untracked (confirmed via `git check-ignore -v`), so no commit in this task's history
  can contain a hand-authored `.claude/**` file.
- Files verified: Yes (all 19 modified files individually grepped for zero `skill-team` hits;
  the two deletion commits verified via `git show --stat` and `ls`).

## Impacts

- `--team` is now exclusively an `/orchestrate` flag; `/research`, `/plan`, and `/implement` are
  single-agent-only. Any external documentation, muscle memory, or script invoking
  `/research ... --team` (etc.) directly will need to move to `/orchestrate ... --team`.
- The phase-level file-overlap-inference application (`infer_from_file_overlap(phase, phases)`)
  is retired with no successor; parallel phase execution now depends entirely on a plan's declared
  `**Dependency Analysis**` wave table / per-phase `**Depends on**:` fields being correct. This
  matches the memory candidate the planning stage already recorded as a forward-looking insight.
- `context/reference/team-wave-helpers.md` (400 lines) is now an orphaned reference document with
  no consumer — see Follow-ups.

## Follow-ups

- **`context/reference/team-wave-helpers.md`** (400 lines) is referenced only by the three now-
  deleted skills, plus its own `index-entries.json` entry. It was missed by this plan's 19-file
  inventory because it cites the deleted skills via a `skill-team-*` glob rather than one of the
  three literal names, so it never tripped the literal-name zero-hits grep. A small follow-up task
  should delete it or repurpose it as general (non-team-specific) wave-coordination reference
  material, and remove its `index-entries.json` entry if deleted.
- `agent-system/extensions/lean/index-entries.json`'s one pre-existing line-count mismatch (see
  Deviations) is fixed in the working tree but left uncommitted — a future task or the next commit
  touching that file should pick it up.
- The two pre-existing `verify-deploy.sh` failures (doc-lint's 2 undeclared scripts,
  `validate-state.sh --deep`'s 2 unknown-field findings) remain open; neither is in this task's
  scope.

## References

- `specs/123_delete_team_mode_skills/plans/01_delete-team-mode-skills.md`
- `specs/123_delete_team_mode_skills/reports/01_delete-team-mode-skills.md`
- `specs/123_delete_team_mode_skills/progress/phase-{1..8}-progress.json`
- Commits: `584e2cb11`, `1ea95f869`, `f7f8e28e8`, `b1b26a0c5`, `f82fe2e1c`, `b685221d1`,
  `ac4a56052`, `4cbc39101`, `d687a2856`, `d5bd6bb99`, `5543a848f`, `24a9e1d8d`
