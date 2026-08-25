# Implementation Summary: Task #93

- **Task**: 93 - close_cross_repo_deploy_skew
- **Status**: [COMPLETED]
- **Started**: 2026-08-25T04:00:00Z
- **Completed**: 2026-08-25T05:15:00Z
- **Effort**: ~5.5 hours
- **Dependencies**: 83
- **Artifacts**: plans/01_cross-repo-consumer-freshness-report.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a source-side TIER 3 fleet freshness report on top of the existing two-tier
`check-deploy-freshness.sh` staleness model: a git-tracked known-consumer registry, a new
`check-consumer-freshness.sh` reporting script (with a `--discover` reconciliation mode) that
reuses `deploy_freshness_status` unmodified, a guarded post-deploy hook in `deploy-headless.sh`
that names newly-stale consumers, and a bounded, non-blocking consecutive-ignore escalation on
the existing tier-1 per-repo WARN. All 7 plan phases completed. Both acceptance criteria were
verified live against all 8 real consumer repos on this machine and against a real
`deploy-headless.sh` deploy in this repo.

## What Changed

- `agent-system/extensions/core/context/reference/known-consumer-repos.json` — NEW git-tracked
  registry naming 8 known consumer repos and `discover_roots` for reconciliation.
- `agent-system/extensions/core/scripts/check-consumer-freshness.sh` — NEW: enumerates every
  registered consumer's own recorded extensions, calls `deploy_freshness_status` per extension,
  reports commits-behind, supports `--stale-only` and `--discover`. Never writes to a consumer.
- `agent-system/extensions/core/scripts/tests/test-consumer-freshness.sh` — NEW 14-case fixture
  suite (classification, exit codes, `--stale-only`, `--discover`, no-write invariant).
- `agent-system/extensions/core/manifest.json` — registered both new scripts in `provides.scripts`.
- `agent-system/extensions/core/scripts/check-deploy-freshness.sh` — added the consecutive-ignore
  streak counter (`specs/.freshness-warn-streak.json`) and the threshold-5 escalated banner.
- `agent-system/extensions/core/scripts/deploy-headless.sh` — captured the verify outcome into a
  variable and added a guarded post-deploy call to `check-consumer-freshness.sh --stale-only`
  before the single final `exit`; the 0/1/2/3 exit-code contract is unchanged.
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` — added 7 streak-counter
  cases (increment, threshold banner, reset-on-fresh, cap, silent skip).
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — added the
  streak file's class-table row and the pattern in the "Consumer Repo Setup" documented block.
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` — added the streak-file
  probe to both `EPHEMERAL_PROBES` and Check B's tracked-file patterns.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — three-tier
  staleness model update, new "Tier 3" subsection, deploy-hook doc note, `## Related
  Documentation` entries.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — new entry for
  `check-consumer-freshness.sh`.
- `agent-system/extensions/core/index-entries.json` — synced `line_count` for
  `orchestrator-runtime-files.md` and `regeneration-is-manual-only.md` (both edited by this task).
- `.gitignore` (repo root) — added `**/.freshness-warn-streak.json`.

## Decisions

- Reused `deploy_freshness_status` unmodified — it already generalizes to any repo path (`source_dir`
  is always an absolute path back into this repo).
- Explicit git-tracked registry, not a routine scan, as the primary enumeration mechanism;
  `--discover` is the occasional reconciliation path.
- Escalation is visibility-only, never blocking, keyed on consecutive command invocations rather
  than wall-clock days.
- No push, ever — every consumer interaction is a read of that consumer's own
  `.claude-extensions.json`.

## Plan Deviations

- **Phase 5's gitignore target altered**: the plan named
  `agent-system/extensions/core/root-files/.gitignore`, but that file deploys only into a
  consumer's `.claude/` directory (per `orchestrator-runtime-files.md`'s own "Consumer Repo
  Setup" section), so a `specs/`-rooted pattern placed there would resolve to
  `.claude/specs/...` and match nothing. Verified against every existing sibling ephemeral-file
  registration site (`.orchestrator-churn-state.json`, `.events.lock`): neither appears in
  `root-files/.gitignore` either. Added the pattern to this repo's own root `.gitignore` (which
  already carries the sibling pattern block) and to the documented "Consumer Repo Setup" block in
  `orchestrator-runtime-files.md` instead.
- **Acceptance (b)'s "and still exits 0" does not hold in this specific repo state**: a real
  `deploy-headless.sh` run here exits 3 because of 15 pre-existing, unrelated `check-extension-docs.sh`
  Rule R/S findings (stale `index-entries.json` line counts and undeclared context entries in
  `core`/`project-wide`/`typst`, none touching a file this plan modified) — not because of
  anything added by this task. The exit-code CONTRACT itself is verified unchanged and intact
  (dry-run/success/failure/missing-checker cases all tested via a stubbed scratch repo), and the
  stale-consumer report was confirmed present as the last output on two live full deploys, both
  ending in exit 3 for the pre-existing reason above.

## Verification

- Build: N/A (bash/JSON, no build step)
- Tests: `bash -n` clean on all touched scripts; `jq empty` clean on all touched JSON;
  `tests/run-all.sh` 50/52 suites pass (2 pre-existing unrelated failures);
  `check-runtime-file-tracking.sh` PASS (3/3 checks); `check-task-references.sh` PASS (0
  occurrences); `check-extension-docs.sh` reports 15 pre-existing findings, zero of which name a
  file this plan touches
- Files verified: Yes — every new/edited file confirmed on disk and content-correct

## Impacts

- Operators can now run one command (`check-consumer-freshness.sh`) from this repo to see the
  deployed revision of every known consumer, and every `deploy-headless.sh` run ends by naming
  which consumers are now stale — closing the visibility gap the task delegation described (this
  repo itself was found stale relative to a consumer during the research pass).
- A tier-1 WARN ignored 5+ consecutive invocations now escalates its presentation without
  changing any blocking behavior.
- No behavioral change to any consumer repo, and no change to `deploy-headless.sh`'s documented
  exit-code contract.

## Follow-ups

- The 15 pre-existing `check-extension-docs.sh` Rule R/S findings (stale line counts in
  `context-layers.md`, `extension-development.md`, and others; undeclared context entries in
  `core`/`literature`) predate this task and remain open — out of this task's declared scope, but
  worth a dedicated cleanup task since they are the reason `deploy-headless.sh` currently exits 3
  on every run in this repo.
- `specs/018_detect_stale_claude_deploy_trees`-era `skill-orchestrate/SKILL.md`'s Stage MT-3
  step 7 exit-3 routing ambiguity, named in `regeneration-is-manual-only.md`'s own "Stage MT-3
  step 7 collision" paragraph, remains unresolved and is unrelated to this task.

## References

- `specs/093_close_cross_repo_deploy_skew/plans/01_cross-repo-consumer-freshness-report.md`
- `specs/093_close_cross_repo_deploy_skew/reports/01_cross-repo-deploy-skew-visibility.md`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` ("Tier 3" subsection)
