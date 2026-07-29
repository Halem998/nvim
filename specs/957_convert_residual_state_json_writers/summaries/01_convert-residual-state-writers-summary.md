# Implementation Summary: Task #957

- **Task**: 957 - convert_residual_state_json_writers
- **Status**: [COMPLETED]
- **Started**: 2026-07-29T00:00:00Z
- **Completed**: 2026-07-29T03:00:00Z
- **Effort**: ~3 hours
- **Dependencies**: `agent-system/extensions/core/scripts/state-write.sh` (unmodified, per plan)
- **Artifacts**: plans/01_convert-residual-state-writers.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Converted every in-scope inline hand-rolled `specs/state.json` write block (`jq ... > specs/tmp/state.json && mv ...` and its `.tmp`-suffix variant) across 16 core `SKILL.md`/command files into calls to the mutex-guarded `state-write.sh`, then updated 6 documentation files (plus one additional file discovered during the verification sweep) that still presented the old idiom as the recommended pattern. All 10 plan phases completed cleanly; the verification bar passes exactly as specified.

## What Changed

**Code conversion (16 files, 5 phases, 34 sites converted)**:
- `agent-system/extensions/core/skills/skill-status-sync/SKILL.md` — 6 sites
- `agent-system/extensions/core/skills/skill-researcher/SKILL.md` — 5 sites
- `agent-system/extensions/core/skills/skill-researcher-hard/SKILL.md` — 1 site
- `agent-system/extensions/core/skills/skill-planner/SKILL.md` — 2 sites
- `agent-system/extensions/core/skills/skill-planner-hard/SKILL.md` — 3 sites (1 folded with `--regen-todo`)
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` — 5 sites
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` — 1 site
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md` — 4 sites (actual; hypothesis was 5) — 2 folded
- `agent-system/extensions/core/skills/skill-spawn/SKILL.md` — 4 sites
- `agent-system/extensions/core/skills/skill-project-overview/SKILL.md` — 1 site
- `agent-system/extensions/core/skills/skill-team-research/SKILL.md` — 5 sites (1 folded)
- `agent-system/extensions/core/skills/skill-team-plan/SKILL.md` — 3 sites (1 folded)
- `agent-system/extensions/core/skills/skill-team-implement/SKILL.md` — 3 sites (1 folded)
- `agent-system/extensions/core/commands/task.md` — 5 sites (actual; hypothesis was 6) — 3 folded; 2 archive sites left hand-rolled with comments; 2 self-generated session_ids introduced (Create Task mode, Review mode); Recover mode also got a self-generated session_id
- `agent-system/extensions/core/commands/todo.md` — 3 sites (actual; hypothesis was 6) — no folds; 1 self-generated session_id introduced (linear flow); 2 archive sites left hand-rolled with comments
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` — 5 sites (actual; hypothesis was 12) — no folds (file never calls `generate-todo.sh`); reused the file's existing `$todo_session_id`; 1 archive-reinit site left hand-rolled with comment

**Documentation updates (6 files + 1 discovered during Phase 10 sweep)**:
- `agent-system/extensions/core/context/patterns/inline-status-update.md`
- `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md`
- `agent-system/extensions/core/context/patterns/file-metadata-exchange.md`
- `agent-system/extensions/core/context/troubleshooting/workflow-interruptions.md`
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` — allowlist table rows updated (content-based edit, not grep-triggered)
- `agent-system/extensions/core/docs/guides/creating-skills.md`
- `agent-system/extensions/core/context/workflows/preflight-postflight.md` — a "❌ WRONG" anti-pattern illustration was found during the Phase 10 repo-wide sweep (not pre-identified in the plan); reworded to name `state-write.sh` as the correct replacement while keeping the anti-pattern framing intact

All `.claude/**` runtime call paths in the converted code read `bash .claude/scripts/state-write.sh` — this is the intended CALL PATH per the task's binding constraints, not an edit target; every actual edit landed in `agent-system/extensions/core/**` (confirmed via `git log --name-only` across all 9 phase commits: zero paths under `.claude/**`).

## Decisions

- **Actual site counts diverged substantially from the plan's hypotheses in the three highest-risk files** (task.md: 5 actual vs. 6 hypothesized; todo.md: 3 actual vs. 6 hypothesized; skill-todo/SKILL.md: 5 actual vs. 12 hypothesized). In each case the divergence traces to prose-only archival descriptions with no literal grep-matchable code, or to a smaller literal write count than the research/planning estimate. Per the plan's own "Scope Hypothesis... not the stopping condition" clause, the actual counts were converted and the deltas recorded honestly rather than forcing a match to the hypothesis.
- **`--regen-todo` fold decisions** followed the `commands/review.md` precedent strictly: folded only where a write is immediately followed by nothing but a bare `generate-todo.sh` call (no intervening `manage-topics.sh` call, artifact-link step, or second write). Applied in skill-planner-hard, skill-reviser (2x), skill-team-research, skill-team-plan, skill-team-implement, commands/task.md (3x). Left un-folded everywhere a `manage-topics.sh` call or Edit-tool TODO.md update intervened.
- **Session-ID threading**: reused existing in-scope `$session_id`/`$SESSION_ID`/`$todo_session_id` wherever already present (most `SKILL.md` files, and `skill-todo/SKILL.md`'s pre-existing `$todo_session_id`). Generated a new self-generating-fallback session_id exactly once per execution path where none existed: `commands/task.md`'s Create Task, Recover, and Review modes (3 separate generations, one per mode, since `task.md` is multi-mode); `commands/todo.md`'s single linear flow (1 generation, since `/todo` has no distinct modes).
- **Out-of-scope archive/vault sites** (targeting `specs/archive/state.json`, never `specs/state.json`) were left deliberately hand-rolled per the plan's Non-Goals, each annotated with a one-line comment naming the mechanism (`state-write.sh` targets `specs/state.json` only), never a task number.
- **One in-scope core-file hit was found during the Phase 10 verification sweep that was not pre-identified in Phases 1-9**: `context/workflows/preflight-postflight.md`'s anti-pattern illustration. Converted per the plan's explicit Phase 10 instruction ("If a hit is outside file_scope... record... If inside, convert it and re-run").
- **Incidental fix**: in `jq-escaping-workarounds.md`, two archive-only steps had a pre-existing staging-filename inconsistency (staged to `specs/tmp/state.json` but moved to `specs/archive/state.json`). Renamed the staging file to `specs/tmp/archive.json` for clarity, consistent with the naming convention used elsewhere in the codebase for archive writes. This is a documentation clarity fix, not a behavior change (the `mv` still worked correctly either way).

## Plan Deviations

- **Task {P}.{N} scope-hypothesis deviations**: recorded inline in each phase's checklist (Phases 3, 6, 7, 8) — actual site counts differed materially from the plan's pre-implementation estimates in 4 of 8 conversion phases. None of these are "deviations" in the sense of skipped or altered work; they are honestly-recorded corrections to a hypothesis the plan itself flagged as approximate and non-authoritative.
- **Phase 10 scope expansion**: one additional file (`preflight-postflight.md`) was discovered and converted during the verification sweep, bringing the total edited-file count to 23 rather than the plan's stated 22. This was handled per the plan's own Phase 10 contingency instructions, not a deviation from them.
- No task or phase was skipped, descoped, or left incomplete.

## Verification

- **Repo-wide grep for `specs/state.json`-targeted `> tmp && mv` / `.tmp` staging**: zero hits inside `agent-system/extensions/core/**` (outside `state-write.sh` itself). 47 files with residual hits found under non-core extensions (`web`, `founder`, `cslib`, `lean`, `epidemiology`, `present`) — explicitly out-of-scope per this task's Non-Goals; full path list below.
- **Repo-wide grep for `python3 json.load`/`json.dump` in-place state.json writes**: zero hits anywhere in the source store.
- **`bash -n`**: clean on every converted block across all 23 edited files. The full re-sweep also (re-)surfaced 9 pre-existing, unrelated block failures (multi-line `git commit -m "..."` doc examples with deliberately open quotes; Python-pseudocode inside a `\`\`\`bash` fence; one heredoc illustration with a bare `EOF` delimiter) — every one confirmed via `git diff` to be untouched by this task.
- **`test-state-write-concurrency.sh`**: exit 0, 4/4 passed.
- **`test-task-lock-reap.sh`**: exit 0, 6/6 passed.
- **`check-task-references.sh`**: exit 0, PASS, 0 unexempted occurrences.
- **`check-extension-docs.sh`**: exit 0, ALL extensions PASS (including `core` and `literature`, both of which failed at this task's own Phase 1 baseline). This improvement is attributable to a separate, concurrently-landed in-flight task (git history shows "task 965 phase 1"/"task 965 phase 2" commits modifying `check-extension-docs.sh` between this task's Phase 1 baseline and Phase 10 sweep) — the exact concurrent task named in this task's own binding constraints as out of scope to touch. This task made zero edits to `check-extension-docs.sh`, confirmed via `git diff`.
- **`.claude/**` write check**: zero writes landed under `.claude/**` across all 9 phase commits (confirmed via `git log --name-only`).

### Non-core residual paths (recorded, not silently passed; out of scope per Non-Goals)

```
agent-system/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md
agent-system/extensions/cslib/skills/skill-cslib-vet/SKILL.md
agent-system/extensions/epidemiology/commands/epi.md
agent-system/extensions/epidemiology/skills/skill-epi-implement/SKILL.md
agent-system/extensions/epidemiology/skills/skill-epi-research/SKILL.md
agent-system/extensions/founder/commands/{analyze,consult,deck,finance,legal,market,meeting,project,sheet,strategy}.md
agent-system/extensions/founder/skills/{skill-analyze,skill-consult,skill-deck-implement,skill-deck-plan,skill-deck-research,skill-finance,skill-financial-analysis,skill-founder-implement,skill-founder-plan,skill-founder-spreadsheet,skill-legal,skill-market,skill-meeting,skill-project,skill-strategy}/SKILL.md
agent-system/extensions/lean/skills/{skill-lean-implementation,skill-lean-implementation-hard,skill-lean-research,skill-lean-research-hard}/SKILL.md
agent-system/extensions/present/commands/{budget,funds,grant,slides,timeline}.md
agent-system/extensions/present/skills/{skill-budget,skill-funds,skill-grant,skill-slide-critic,skill-slide-planning,skill-slides,skill-timeline}/SKILL.md
agent-system/extensions/web/skills/{skill-web-implementation,skill-web-research}/SKILL.md
```

## Impacts

- Every core skill/command in `agent-system/extensions/core/**` that writes `specs/state.json` now routes through the single mutex-guarded `state-write.sh`, eliminating the fail-open-on-timeout and shared-staging-path corruption channels the old hand-rolled idiom carried.
- Documentation now consistently presents `state-write.sh` as the approved write path, including the postflight tool-allowlist standard and the skill-authoring guide.
- Non-core extensions still carry the old idiom and are a natural follow-up task (out of scope here).

## Follow-ups

- Convert the residual sites in the non-core extensions listed above (`web`, `founder`, `cslib`, `lean`, `epidemiology`, `present`) in a separate task, if desired.
- The report's suggested follow-up — adding a `specs/archive/state.json` exclusion note to `context/patterns/task-lock.md` — remains explicitly out of scope per this task's Non-Goals.

## References

- Plan: `specs/957_convert_residual_state_json_writers/plans/01_convert-residual-state-writers.md`
- Research report: `specs/957_convert_residual_state_json_writers/reports/01_convert-residual-state-writers.md`
- Precedent: `agent-system/extensions/core/commands/review.md` (fold/no-fold precedent)
