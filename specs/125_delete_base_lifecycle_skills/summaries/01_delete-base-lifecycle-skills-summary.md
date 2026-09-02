# Implementation Summary: Task #125

- **Task**: 125 - Delete the three base lifecycle skills (skill-researcher, skill-planner, skill-implementer)
- **Status**: [COMPLETED]
- **Started**: 2026-09-02T14:12:00-07:00
- **Completed**: 2026-09-02T15:10:00-07:00
- **Effort**: ~11 hours (matches plan estimate)
- **Dependencies**: None outstanding
- **Artifacts**: plans/01_delete-base-lifecycle-skills.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Deleted the three base lifecycle skills (`skill-researcher`, `skill-planner`, `skill-implementer`)
from the core extension source store, landed the two wiring fixes required to keep
`validate-wiring.sh` and the core `manifest.json` deploy list truthful post-deletion, and swept
115 files across `agent-system/**` (the plan's sole declared scope) so a repo-wide word-boundary
grep for all three names returns zero hits across `agent-system/**` outside `specs/**` (exempt as
frozen task-management history). This does not extend to `.opencode/`: 114 files under that
separate, out-of-scope OpenCode agent-system mirror still reference the three names, including
its own `command-route-skill.sh` and `skill-base.sh`; neither the research report nor the plan
ever named `.opencode/` in their file scope, so those references were never swept. All 10 plan
phases completed; every named lint/test gate passes; the deployed `.claude/skills/` tree no
longer contains the three directories.

## What Changed

- `agent-system/extensions/core/skills/skill-researcher/`,
  `agent-system/extensions/core/skills/skill-planner/`,
  `agent-system/extensions/core/skills/skill-implementer/` — deleted in full (424/508/726 lines)
- `agent-system/extensions/core/scripts/validate-wiring.sh` — core-skills existence loop narrowed
  to `skill-meta` only
- `agent-system/extensions/core/manifest.json` — removed the three `provides.skills` entries
- 15 extension `manifest.json` files (formal, latex, cslib, lean, nvim, web, z3, nix, filetypes,
  present, epidemiology, python, typst, memory, email) — pruned dangling `routing.{op}` entries
  valued at the three deleted skills; dropped now-empty `routing.{op}` objects
- `agent-system/extensions/epidemiology/commands/epi.md` — retargeted the router's literal
  default argument from `"skill-researcher"` to `"skill-epi-research"`
- `agent-system/extensions/core/merge-sources/claudemd.md`,
  `agent-system/extensions/literature/merge-sources/claudemd.md` — removed the three
  Skill-to-Agent Mapping rows; rewrote the Task-Type-Based Routing table for direct agent
  dispatch; fixed the Stage 4a literature pointer
- ~90 further files across `agent-system/extensions/core/{context,docs,scripts,hooks,agents,
  skills}` and 14 non-core extensions — swept every remaining textual reference, rewriting each
  hit line (never a bulk regex replace) to reflect the current architecture
- `specs/125_delete_base_lifecycle_skills/plans/01_delete-base-lifecycle-skills.md` — all 10
  phases checked off, plan-level status set to `[COMPLETED]`

## Decisions

- **Phase 2 routing-prune scope**: pruned only the dangling key-value pairs whose value was one
  of the three deleted skills, dropping an enclosing `routing.{op}` object only when it became
  empty — the minimal, lint-safe fix (per the plan's own pre-stated decision).
- **`.claude/skills/` orphan removal requires `--wipe`**: `deploy-headless.sh`'s default resync
  mode is additive-only by design and never deletes stale deploy copies. Ran `--wipe` mode to
  actually remove the three orphaned directories; confirmed via `verify-deploy.sh`'s whole-tree
  orphan-detection gate going from 3 findings to 0.
- **`specs/**` carve-out scope**: treated the entire `specs/**` tree as exempt from the zero-hit
  bar (not just this task's own directory and `specs/vault/**`), matching this task's own
  Non-Goals framing ("frozen; exempted by the `specs/**` carve-out") and the repo-wide
  `no-task-references-in-deliverables.md` convention. Rewriting other tasks' frozen historical
  reports/plans/summaries would itself be out of scope and counterproductive.
- **Historical-record rewrite discipline**: every prose hit was read and rewritten individually
  (never a blind bulk substitution), per the plan's own risk mitigation. Several files required
  correcting the underlying architectural claim, not just the literal skill name, once the claim
  itself turned out to be stale (see Plan Deviations).

## Plan Deviations

- **No `-hard` variants exist anywhere in the source tree.** The plan's Non-Goals explicitly
  preserved `skill-researcher-hard`/`skill-planner-hard`/`skill-implementer-hard`, but a
  repo-wide grep confirms zero references to any of the three anywhere — an earlier, unrelated
  task had already deleted them. Every plan instruction to "name only the surviving `-hard`
  variants" was correspondingly infeasible; affected prose was rewritten to name the actual
  current importers/owners instead (typically `skill-orchestrate`).
- **`orchestrator-postflight.sh` is fully orphaned, not just Stage 10.** A repo-wide grep for
  actual invocation sites (not documentation mentions) returns zero results anywhere.
  `skill-orchestrate` now performs research/plan/implement postflight commits directly via its
  own dispatch-loop commit sites. Corrected `orchestrator-postflight.sh`'s own header/inline
  comments and `skill-git-workflow/SKILL.md`'s "Relationship to `orchestrator-postflight.sh`"
  section to state this accurately.
- **`skill-lifecycle.md`'s Collapsed/Split shape classification self-correction.** An initial
  Phase 5 edit incorrectly classified `skill-reviser`/`skill-spawn` as collapsed-shape (no inline
  git commit). Verified against their actual `SKILL.md` stage lists (both carry an explicit
  "Stage 9: Git Commit" before Cleanup) and corrected in Phase 6 — they are split-shape, like the
  two deleted skills whose pattern they continue.
- **`test-lit-pipeline.sh` Section D required a functional fix, not a comment swap.** Its skills
  array (`"skill-researcher" "skill-implementer"`) would have failed at runtime once those files
  were deleted. Reduced to `("skill-orchestrate")`; re-ran the full suite (8 passed, 0 failed).
- **Scope-hypothesis undercounts across several phases** (Phase 6: 16 actual vs. 21 estimated;
  Phase 8: 12 actual vs. 21 estimated) — several plan-named files (e.g.
  `lint-contract-compliance.sh`, `test-resume-scan-nonconformance.sh`,
  `test-routing-resolution.sh`, `anti-analysis.md`, `recovery.md`, `wrap-up.md`,
  `hard-mode-routing.md`, `plan-format.md`) had zero hits — confirmed already clean rather than
  missed.
- **`docs/examples/research-flow-example.md` was rewritten, not retired** (the plan offered both
  options): it is cross-linked from three other docs; retiring it would have left dangling
  references. The rewrite is grounded against `skill-orchestrate/SKILL.md`'s actual verified
  single-task stage sequence (Stage 1, 1b, 2, 3, 3.5, 5, 7, 8) rather than invented detail.
- **Accidental foreign-file sweep, corrected.** Phase 9's commit passed a directory pathspec
  that swept in an unrelated, pre-existing untracked pyenv cache file
  (`agent-system/extensions/literature/scripts/literature-pyenv/.cclib_path`). Reverted in a
  follow-up commit that restored its untracked status without deleting the file from disk.
- **14 stale `index-entries.json` `line_count` declarations, corrected post-hoc.** Phases 5-9
  changed the line counts of 14 `agent-system/extensions/core/context/**` files without updating
  their corresponding `index-entries.json` entries (a gate this task's own commit-by-commit lint
  runs never exercised — `check-extension-docs.sh`'s Rule R only surfaced this on a subsequent
  full `verify-deploy.sh` run). Derived every actual count independently with `wc -l`, updated the
  14 entries, re-ran `check-extension-docs.sh` (core: PASS) and `verify-deploy.sh` (3 remaining
  failures, all pre-existing and unrelated — the same three seen throughout this task), and
  committed scoped strictly to `index-entries.json`.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: `test-postflight-marker-schema.sh` 10/10 passed; `test-lit-pipeline.sh` 8/8 passed;
  `lint-task-lookup-adoption.sh` 0 violations across 339 files
- Lints: `lint-routing-wiring.sh` 259 passed / 0 failed; `lint-agent-contracts.sh` 101 passed / 0
  failed; `lint-contract-compliance.sh` 21 passed / 0 failed; `validate-wiring.sh` zero
  `Skill missing:` lines for any of the three; `check-task-references.sh` 0 unexempted
  occurrences across 4 trees
- Deploy: `deploy-headless.sh --wipe` regenerated `.claude/`; `.claude/skills/skill-{researcher,
  planner,implementer}/` confirmed absent; `verify-deploy.sh`'s whole-tree orphan-detection gate
  passes with 0 findings (was 3 before the wipe)
- Grep of the plan's declared scope: `grep -rnE '\bskill-(researcher|planner|implementer)\b'`
  across `agent-system/`, `docs/`, `lua/`, `*.md` returns zero hits; zero hits outside `specs/**`
  within that scope. `.opencode/` (114 files, never in the plan's scope) was not swept — see
  Overview.
- Files verified: Yes (`jq .` parses every touched `manifest.json`/`.json`; `bash -n` passes on
  every touched shell script)

## Impacts

- The `general`/`meta`/`markdown` task types now dispatch research/plan/implement work directly
  to `general-research-agent`/`planner-agent`/`general-implementation-agent` via
  `skill-orchestrate`, with no intervening per-function skill layer — matching the architecture
  that `/research`, `/plan`, `/implement` command deletion (a prior task) already established.
- Every extension manifest's `routing` block is now free of dangling pointers to deleted skills;
  `routing_agents` blocks (already correct) are the sole live routing mechanism for these
  task types.
- Documentation across `context/`, `docs/`, and extension READMEs now describes the current
  direct-dispatch architecture rather than the retired command-and-skill-layer shape, reducing
  future confusion for anyone authoring new skills/agents from these references.

## Follow-ups

- `.opencode/` (114 files, including its own `command-route-skill.sh` and `skill-base.sh`) still
  references the three deleted skill names. This is a separate OpenCode agent-system mirror that
  the plan never named in scope (its own file scope is `agent-system/**`), so it was left
  untouched. Whether `.opencode/` should be swept, retired, or left alone is a decision for a
  future task, not implied here.

## References

- `specs/125_delete_base_lifecycle_skills/reports/01_delete-base-lifecycle-skills.md`
- `specs/125_delete_base_lifecycle_skills/plans/01_delete-base-lifecycle-skills.md`
- `specs/125_delete_base_lifecycle_skills/progress/phase-{1..10}-progress.json`
- `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` (A1 migration
  note, A7 ledger, cited by the delegation as the design source)
