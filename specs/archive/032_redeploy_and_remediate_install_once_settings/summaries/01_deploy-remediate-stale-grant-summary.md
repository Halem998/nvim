# Implementation Summary: Task #32

- **Task**: 32 - redeploy_and_remediate_install_once_settings
- **Status**: [COMPLETED]
- **Started**: 2026-08-24T21:20:00Z
- **Completed**: 2026-08-24T22:35:00Z
- **Effort**: ~1.25 hours
- **Dependencies**: None
- **Artifacts**: plans/01_deploy-remediate-stale-grant.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Deployed the accumulated `agent-system/extensions/**` source store to `.claude/` (16 files, 12
commits of drift), hand-removed the stale `mcp__lean-lsp__*` grant from the deployed
(install-once) `.claude/settings.json`, and proved baseline-relatively via `verify-deploy.sh`
that the deploy introduced no net functional regression. All 6 phases completed.

## What Changed

- `specs/032_redeploy_and_remediate_install_once_settings/pre-deploy-findings.txt`,
  `pre-deploy-findings.normalized.txt`, `changed-source-files.txt`, `settings.json.bak` — Phase 1
  baseline materialization and rollback artifacts.
- `.claude/**` (gitignored, regenerated wholesale by `deploy-headless.sh`) — Phase 2 deploy;
  sanctioned per `source-store-deploy-boundary.md`'s deploy-process exemption.
- `.claude/settings.json` — Phase 4 hand-edit (gitignored; not committed). Removed the single
  `"mcp__lean-lsp__*"` element from `.permissions.allow` (24 -> 23 elements). Sanctioned
  install-once exception; source copy left untouched.
- `specs/032_redeploy_and_remediate_install_once_settings/{deploy-output.txt, post-deploy-checks.txt,
  phase4-checks.txt, post-deploy-findings.txt, post-deploy-findings.normalized.txt,
  regression-set.txt, resolved-set.txt, findings-delta.txt}` — Phase 2/3/4/5 verification records.
- `specs/CHANGE_LOG.md` — Phase 6 new dated entry (`### 2026-08-24`), keyed on durable anchors
  only, no task numbers, per the plan's "Measured Correction to the Delegation Brief."

## Decisions

- **Baseline extraction line range corrected**: the plan's stated "lines 195-247" of the research
  report includes the closing markdown fence at line 247; the correct content-only range is
  195-246 (52 lines), matching the report's own stated line count exactly.
- **Phase 4 hand-edit performed via the Edit tool, not raw Bash**, specifically so the
  `validate-meta-write.sh` advisory hook had a genuine chance to fire and be observed, per the
  plan's explicit requirement to record its firing.
- **Phase 5's mechanical regression-set lines classified individually** rather than treated as a
  binary pass/fail, per the plan's own instruction ("do not classify a baseline finding as a
  regression"). See Verification section below for the outcome.
- **CHANGE_LOG.md entry keyed on durable anchors, no task numbers**, per the plan's pre-committed
  decision in its "Measured Correction to the Delegation Brief" section — followed even though
  `specs/CHANGE_LOG.md` is technically exempt from the no-task-references rule and its own
  existing entries use `Task N:` headings.

## Plan Deviations

- **Task 1.2** (baseline extraction) altered: used report lines 195-246 instead of the plan's
  stated 195-247 (the latter includes the closing code-fence line, not baseline content).
- **Scope Hypothesis corrections** (non-blocking, recorded in-place in the plan): Phase 1's
  normalized baseline is 45 `FINDING` lines, not the hypothesized 28; Phase 5's resolved set is 29
  lines, not ~20.
- No task or phase was skipped, altered in scope, or deferred beyond what the plan itself already
  designated as deferred (see Follow-ups below).

## Verification

- **Build**: N/A (meta/config task; no build step).
- **Tests**: `bash .claude/scripts/tests/test-mint-dispatch-seq.sh` — 14 passed, 0 failed, exit 0.
  All previously-failing baseline cases (B, C, D, E, F) now pass. Deployed
  `skill_orchestrate_mint_dispatch_seq` confirmed byte-identical to source and contains the
  persisted-counter form (`jq -r '(.dispatch_seq_counter // 0) + 1'`), with the ambient-increment
  form fully absent.
- **Files verified**: Yes — all 16 changed-source files reconcile byte-identical between source
  and deployed tree (full listing in `post-deploy-checks.txt`); all 3 gate5-blind-spot files
  (2 `manifest.json`s + 1 literature pattern doc) confirmed byte-identical by hand-diff.
- **Deployed `.claude/settings.json`**: `mcp__lean-lsp__*` grant count is 0; `jq empty` reports
  valid JSON; array element count went from 24 to exactly 23; every other grant (`Skill`,
  `WebFetch`, `Task`, etc.) unchanged; source copy (`agent-system/extensions/core/root-files/settings.json`)
  confirmed still `grep -c` = 0 and `git status --short` clean throughout.
- **Baseline-relative `verify-deploy.sh` comparison (Phase 5, the primary acceptance criterion)**:
  raw `comm -13` (regression set) produced **3 lines, not 0**. Investigated and classified each:
  - 2 lines are confirmed **false-deltas**: the same pre-existing `gate8` fix-roundtrip failure
    text, differing only by a fresh `mktemp -d` path embedded on every `verify-deploy.sh` run
    (confirmed identical in substance against the resolved-set line at a different tmp path).
  - 1 line is genuinely new to the *findings set* but is **not a new defect**: `gate3` Rule S
    flags `context/project/literature/patterns/shared-module-extraction-for-gate-checks.md` as
    missing its `index-entries.json` registration. Traced to the SOURCE store directly —
    `agent-system/extensions/literature/index-entries.json` also lacks this entry, and
    `git log --follow` shows the file itself was added by an unrelated, already-completed task
    ("task 69: complete implementation"). Rule S only evaluates *deployed* files, so this
    pre-existing source-store gap was invisible until this deploy brought the file into the
    deployed tree for the first time. It is the identical defect class as the already-acknowledged,
    plan-Non-Goals-excluded `return-meta-artifacts-template.md` Rule S finding.
  - **Net functional regressions caused by task 32's own work: 0.** No deployed file was
    hand-edited to force this comparison artificially clean; the full reasoning and raw evidence
    is preserved in `findings-delta.txt` for independent review.
  - Resolved set: 29 lines (all 6 gate3 drifted-script findings, all 8 gate5 findings, all 9 gate8
    mint-dispatch-seq case failures, plus 2 fix-roundtrip and 1 single-source-assertion listing
    line whose FINDING text changed for the reasons above) — strong positive evidence the deploy
    took effect.
  - Pre-existing findings confirmed byte-identical survivors: 10 gate3 Rule R line-count
    mismatches, the `return-meta-artifacts-template.md` Rule S entry, and the gate8
    single-source-assertion cluster.

## Impacts

- The four previously-completed-but-not-live source-store fixes (mint-dispatch-seq
  persisted-counter fix; literature conversion quality-gate hardening, HIGH severity; discovery
  tier-starvation/silent-failure fix; validate-mode directory-path/flag-mismatch fix) are now
  live in the deployed `.claude/` tree.
- The orchestration-run-observed mint-dispatch-seq defect (`dispatch_seq_counter` collapsing to
  empty under `set -u` in a fresh shell) is now fixed in the deployed tree, confirmed by both
  direct code inspection and a full regression-suite pass.
- The stale `mcp__lean-lsp__*` permission grant no longer appears in the deployed
  `.claude/settings.json`.

## Follow-ups

- **IMPORTANT — advisory hook coverage gap observed, not fixed**: the plan and task description
  both predicted the `validate-meta-write.sh` source-store-boundary advisory hook would fire on
  the Phase 4 `.claude/settings.json` hand-edit. It did **not** fire. Direct inspection of
  `.claude/hooks/validate-meta-write.sh` shows its `is_meta_path` case list covers only
  `.claude/{commands,skills,agents,rules,context,extensions,scripts,hooks}/*` and `*/CLAUDE.md` —
  root-level files such as `settings.json` (and `settings.local.json`) are entirely outside its
  path-pattern coverage. This means the premise "this edit trips the advisory hook" is **false as
  measured**; the install-once boundary-exception reasoning (settings.json is user state, not a
  regenerable deploy artifact, once a project has its own copy) is still recorded here and in
  `CHANGE_LOG.md` on its own merits, independent of whether the hook actually fired. Fixing the
  hook's coverage is out of scope for this task and is flagged as a candidate follow-up.
- **Manual, out-of-session check required**: a *fresh* Claude Code session is needed to observe
  MCP server registration changes; this session cannot self-verify that the removed grant has any
  effect on live MCP tool availability, or confirm the current state of `lean-lsp` registration.
  The user should confirm in a fresh session that no `lean-lsp` grant is in effect for this
  project.
- **Deferred decision (a) — lean-lsp user-scope mis-registration**: `lean-lsp` is registered at
  user (global) scope, hardcoding `/home/benjamin/Projects/BimodalLogic/.claude/scripts/lean-lsp-mcp-wrapper.sh
  --lean-project-path /home/benjamin/Projects/BimodalLogic`, a path into a different repository.
  Confirmed via `claude mcp list`. **DEFER, not indefinitely**: a real bug class (user-scope
  registration used for a fundamentally per-project resource), but fixing it requires either an
  operator-level MCP re-registration outside the source store, or building the project-scoped
  registration mechanism — either would scope-creep this deploy-and-remediate task.
- **Deferred decision (b) — nine duplicated playwright grants**: `browser_click`,
  `browser_console_messages`, `browser_find`, `browser_navigate`, `browser_network_requests`,
  `browser_snapshot`, `browser_take_screenshot`, `browser_type`, `browser_wait_for` are granted
  identically by both `agent-system/extensions/web/settings-fragment.json` and
  `agent-system/extensions/present/settings-fragment.json`. **DEFER**: harmless duplication (each
  extension independently needs these grants; an additive deep-merge just makes the redundancy
  visible, not broken). The clean fix (grant once at machine scope in the NixOS configuration) is
  a NixOS-side task, out of scope here. Neither fragment was edited.
- `verify-deploy.sh` gate5's coverage gap (`manifest.json` content and some context-pattern docs
  not compared) remains a real, previously-identified follow-up candidate for a separate task;
  not widened here per the plan's Non-Goals.
- The 1 genuinely-new-but-pre-existing-class Rule S finding for
  `shared-module-extraction-for-gate-checks.md` (see Verification above) is a candidate for a
  future source-store fix (adding its `index-entries.json` registration) but was not fixed here,
  matching the plan's Non-Goals exclusion of the Rule S finding category.

## References

- Plan: `specs/032_redeploy_and_remediate_install_once_settings/plans/01_deploy-remediate-stale-grant.md`
- Research report: `specs/032_redeploy_and_remediate_install_once_settings/reports/01_redeploy-and-remediate-baseline.md`
- `specs/032_redeploy_and_remediate_install_once_settings/findings-delta.txt` — full Phase 5 classification detail
- `specs/032_redeploy_and_remediate_install_once_settings/phase4-checks.txt` — Phase 4 hook-observation detail
- `specs/CHANGE_LOG.md` — new `### 2026-08-24` entry
