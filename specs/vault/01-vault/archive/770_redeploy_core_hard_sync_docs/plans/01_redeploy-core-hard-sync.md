# Implementation Plan: Re-deploy Core Hard Pieces + Sync CLAUDE.md Docs

- **Task**: 770 - Re-deploy/propagate corrected core hard pieces to installed projects and sync CLAUDE.md docs
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: 767, 768, 769 (all completed)
- **Research Inputs**: specs/770_redeploy_core_hard_sync_docs/reports/01_redeploy-core-hard-sync.md
- **Artifacts**: plans/01_redeploy-core-hard-sync.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 770 is the final step in the 767-770 series that corrected the core extension's hard-mode agents/skills and routing. This plan covers two in-scope writes to this repo's `.claude/`: (1) replace the outdated 4-step Routing Mechanism description in the core CLAUDE.md merge-source with the accurate 5-step (Steps 1-5) algorithm that `command-route-skill.sh` actually implements, using the exact replacement text from the research report; and (2) author a re-deploy / propagation procedure document describing how a user updates an already-installed project (BimodalLogic) via the extension picker (Ctrl-l) to pick up the missing core hard agents + `skill-orchestrate-hard`, plus how to regenerate the deployed CLAUDE.md. A final verification phase asserts the doc-lint baseline is unchanged (exactly 4 pre-documented FAILs, no new regressions) and that the merge-source edit is internally consistent with `hard-mode-routing.md`.

**Definition of done**: merge-source Routing Mechanism section matches the 5-step implementation and `hard-mode-routing.md`; a propagation procedure doc exists listing BimodalLogic's missing items and the Ctrl-l update + CLAUDE.md-regeneration steps; `check-extension-docs.sh` shows exactly the 4 documented FAILs with zero new regressions.

### Research Integration

Integrates `reports/01_redeploy-core-hard-sync.md`:
- The exact CURRENT (4-step) and REQUIRED (5-step) Routing Mechanism text for `core/merge-sources/claudemd.md` (report Finding 4).
- Mechanism distinction: `install-extension.sh` scans the filesystem and creates symlinks (deploys NEW files only, skips existing non-symlinks); the extension loader (Ctrl-l) reads `manifest.provides` and copies with overwrite-on-confirm — the correct UPDATE path for BimodalLogic (Findings 1-2).
- BimodalLogic's missing items: `planner-hard-agent.md`, `general-research-hard-agent.md`, `general-implementation-hard-agent.md`, and `skill-orchestrate-hard` (Finding 3).
- CLAUDE.md is generated from merge-sources via the extension picker; there is no standalone regeneration script (Finding 5).
- Doc-lint baseline is exactly 4 FAILs (2 pre-existing core + 2 lean routing_hard); "confirm clean" = no NEW failures beyond these 4, not exit 0 (Finding 6).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (no roadmap_path provided; roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- Replace the 4-step Routing Mechanism description in `.claude/extensions/core/merge-sources/claudemd.md` with the accurate 5-step description from the research report.
- Verify the merge-source edit is internally consistent with `.claude/context/guides/hard-mode-routing.md` (task 768's guide).
- Author a propagation/re-deploy procedure document covering the user's Ctrl-l update path for an already-installed project and the CLAUDE.md regeneration step, including BimodalLogic's explicit missing-items list and the `install-extension.sh` vs extension-loader distinction.
- Confirm the doc-lint baseline is unchanged: exactly 4 documented FAILs, no new regressions.

**Non-Goals**:
- Do NOT modify BimodalLogic or any project outside this repo (no write access assumed; Ctrl-l is a user action).
- Do NOT edit the generated `.claude/CLAUDE.md` directly (it is generated from merge-sources; regeneration is a user Ctrl-l action).
- Do NOT attempt to make `check-extension-docs.sh` exit 0; the 4 documented FAILs are the accepted baseline.
- Do NOT run `git push` or create any PR/MR.
- Do NOT run `install-extension.sh` against BimodalLogic.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing generated `.claude/CLAUDE.md` instead of the merge-source | H | M | Phase 1 edits only `core/merge-sources/claudemd.md`; verification greps the merge-source path, not CLAUDE.md |
| 5-step text drifts from `hard-mode-routing.md` or `command-route-skill.sh` | M | M | Phase 1 verification cross-reads the guide and (optionally) the script; assert terminology and step semantics match |
| Doc-lint regressions from the routing edit | M | L | Phase 3 runs `check-extension-docs.sh` and asserts exactly the same 4 FAILs as the report baseline |
| Procedure doc placed where it gets treated as authoritative system behavior incorrectly | L | L | Place in task summary or a clearly-scoped context guide; describe as a user procedure, note Ctrl-l + regeneration are user actions |
| Attempting BimodalLogic write / push | H | L | Explicit Non-Goals; phases only write under this repo's `.claude/` and `specs/770_*/` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Update Routing Mechanism in core merge-source [COMPLETED]

- **Goal:** Replace the outdated 4-step Routing Mechanism description in the core CLAUDE.md merge-source with the accurate 5-step algorithm, and verify it is consistent with the 768 routing guide.
- **Tasks:**
  - [x] Read `.claude/extensions/core/merge-sources/claudemd.md` around the `## Hard Mode` -> `### Routing Mechanism` section (lines ~285-291) to confirm the current 4-step text matches the report's CURRENT block. *(completed)*
  - [x] Replace the 4-step block with the 5-step REQUIRED block from `reports/01_redeploy-core-hard-sync.md` Finding 4, verbatim: 5-step precedence (first match wins) covering (1) non-core extension `routing_hard` exact match, (2) non-core compound-key fallback, (3) core `routing_hard` exact match, (4) core compound-key fallback, (5) `-hard` append fallback gated on `.claude/skills/${candidate}-hard/SKILL.md` existence — plus the trailing paragraph stating non-core is scanned before core (overrides) and the SKILL.md gate applies only to Step 5. *(completed)*
  - [x] Read `.claude/context/guides/hard-mode-routing.md` and confirm the new merge-source text is internally consistent with it (step ordering, non-core-before-core precedence, compound-key fallback, SKILL.md gate scoped to the append fallback). Reconcile any wording mismatch in favor of the guide's described behavior. *(completed: consistent — both describe same 5-step algorithm; guide uses 4a-4e labels internally, merge-source uses 1-5 user-facing labels)*
  - [x] Do NOT touch the generated `.claude/CLAUDE.md`. *(completed: only merge-source was modified)*
- **Timing:** ~45 min
- **Depends on:** none
- **Files to modify:**
  - `.claude/extensions/core/merge-sources/claudemd.md` - replace the `### Routing Mechanism` 4-step list with the 5-step description (and trailing precedence/gate paragraph).
- **Verification:**
  - `grep -n "5-step" .claude/extensions/core/merge-sources/claudemd.md` returns a hit in the Routing Mechanism section.
  - `grep -c "Non-core" .claude/extensions/core/merge-sources/claudemd.md` confirms the non-core/core precedence wording is present.
  - The old phrase `4th \`effort_flag\` argument:` is no longer followed by a 4-item numbered list collapsing manifest lookups into one step.
  - `git diff .claude/extensions/core/merge-sources/claudemd.md` shows changes limited to the Routing Mechanism subsection.

### Phase 2: Author re-deploy / propagation procedure doc [COMPLETED]

- **Goal:** Produce a clearly-scoped document describing how a user updates an already-installed project to pick up the corrected core hard pieces, and how to regenerate the deployed CLAUDE.md.
- **Tasks:**
  - [x] Write a propagation procedure section into the task summary (`specs/770_redeploy_core_hard_sync_docs/summaries/01_redeploy-core-hard-sync-summary.md`, created at /implement time) and/or a scoped context guide such as `.claude/context/guides/` describing the deploy-mechanism distinction. *(completed: summary created with full procedure; deploy-mechanism section added to extension-development.md)*
  - [x] Document the `install-extension.sh` vs extension-loader (Ctrl-l) distinction: `install-extension.sh` scans the filesystem and symlinks NEW files only (skips existing non-symlinks); the extension loader reads `manifest.provides` and copies with overwrite-on-confirm — the correct UPDATE path for already-installed projects. *(completed: documented in both summary and extension-development.md)*
  - [x] List BimodalLogic's explicit missing items: `planner-hard-agent.md`, `general-research-hard-agent.md`, `general-implementation-hard-agent.md` (agents), and `skill-orchestrate-hard` (skill). *(completed)*
  - [x] Give the step-by-step user procedure: in the target project's Claude Code session, open the extension picker -> select "core" -> Ctrl-l ("Load Core") -> confirm the overwrite/conflict dialog (confirming is expected and correct) to copy the missing hard agents + `skill-orchestrate-hard` and refresh existing copies. *(completed)*
  - [x] Document CLAUDE.md regeneration: after the core merge-source edit (Phase 1), the deployed `.claude/CLAUDE.md` regenerates only when the user triggers it via the extension picker (unload/reload core, or Ctrl-l) — there is no standalone regeneration script. Note the regenerated diff should be limited to the Routing Mechanism subsection. *(completed)*
  - [x] Mark clearly that Ctrl-l and CLAUDE.md regeneration are USER actions; the agent does not and cannot perform them on external projects. *(completed: multiple places note "USER ACTION REQUIRED")*
- **Timing:** ~45 min
- **Depends on:** none
- **Files to modify:**
  - `specs/770_redeploy_core_hard_sync_docs/summaries/01_redeploy-core-hard-sync-summary.md` - propagation procedure (created during /implement).
  - Optionally `.claude/context/guides/extension-development.md` - add a note comparing the two deploy mechanisms (per report Context Extension Recommendation), if a durable home is preferred over the summary.
- **Verification:**
  - The procedure doc names all four missing items (3 agents + `skill-orchestrate-hard`).
  - The doc explicitly states the install-extension.sh-vs-Ctrl-l distinction and that regeneration/Ctrl-l are user actions.
  - The doc includes the step-by-step Ctrl-l procedure and the CLAUDE.md regeneration note.

### Phase 3: Verify doc-lint baseline and merge-source well-formedness [COMPLETED]

- **Goal:** Confirm no new doc-lint regressions and that the merge-source edit is well-formed; do not attempt exit 0.
- **Tasks:**
  - [x] Run `bash .claude/scripts/check-extension-docs.sh` and capture output. *(completed)*
  - [x] Assert exactly the 4 documented FAILs are present and NO new ones: core `dispatch-agent.sh` missing-on-disk, core `/zulip` not-in-README, lean `skill-lean-research-hard` not-deployed, lean `skill-lean-implementation-hard` not-deployed. (Per report Finding 6, the script exits non-zero on these 4 — that is the accepted baseline; do not try to make it exit 0.) *(completed: confirmed 4 FAILs, zero new)*
  - [x] Confirm the merge-source is well-formed: the `### Routing Mechanism` heading is intact, the numbered list parses, and no adjacent sections (`### Per-Invocation Only`, `## Literature Mode`) were disturbed. *(completed: grep confirmed all adjacent headings intact at expected line positions)*
  - [x] Optionally show a dry-run/symlink check (e.g. `ls -la .claude/agents/ | grep hard`) demonstrating that the hard agents are present in core and would deploy; do NOT run install-extension.sh against any external project. *(completed: 3 hard agents present as files in .claude/agents/)*
- **Timing:** ~30 min
- **Depends on:** 1, 2
- **Files to modify:** none (verification only).
- **Verification:**
  - `check-extension-docs.sh` output FAIL count == 4 and the 4 lines match the documented baseline; diff against the report's FAIL table shows no new entries.
  - No FAIL references the Routing Mechanism / merge-source edit.
  - Merge-source structural greps from Phase 1 still hold.

## Testing & Validation

- [ ] `bash .claude/scripts/check-extension-docs.sh` produces exactly the 4 documented FAILs (2 core + 2 lean); zero new FAILs.
- [ ] `grep -n "5-step" .claude/extensions/core/merge-sources/claudemd.md` matches inside the Routing Mechanism section.
- [ ] Merge-source Routing Mechanism text is consistent with `.claude/context/guides/hard-mode-routing.md` (step ordering, non-core-before-core, compound-key fallback, SKILL.md gate on Step 5 only).
- [ ] `git diff .claude/extensions/core/merge-sources/claudemd.md` limited to the Routing Mechanism subsection.
- [ ] `.claude/CLAUDE.md` is NOT modified by the agent (only the merge-source is edited).
- [ ] Propagation doc lists all four BimodalLogic missing items and the Ctrl-l + regeneration user procedure.
- [ ] No write to BimodalLogic; no git push; no PR.

## Artifacts & Outputs

- `.claude/extensions/core/merge-sources/claudemd.md` - updated Routing Mechanism (5-step).
- `specs/770_redeploy_core_hard_sync_docs/summaries/01_redeploy-core-hard-sync-summary.md` - includes the propagation procedure (created during /implement).
- Optionally `.claude/context/guides/extension-development.md` - deploy-mechanism comparison note.
- `specs/770_redeploy_core_hard_sync_docs/plans/01_redeploy-core-hard-sync.md` - this plan.

## Rollback/Contingency

- All edits are confined to this repo's `.claude/` and `specs/770_*/`. To revert: `git checkout -- .claude/extensions/core/merge-sources/claudemd.md` (and any touched context guide) restores the prior Routing Mechanism text.
- The summary/procedure doc is additive; deleting it is a clean rollback.
- No external-project or remote state is touched, so there is nothing to undo outside this repo.
