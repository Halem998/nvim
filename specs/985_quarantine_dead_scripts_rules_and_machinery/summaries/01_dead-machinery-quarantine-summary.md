# Implementation Summary: Task #985

- **Task**: 985 - Dead-code quarantine sweep: orphan scripts, dead rules, dead Lua, vestigial twins
- **Status**: [COMPLETED]
- **Started**: 2026-08-09
- **Completed**: 2026-08-10
- **Effort**: ~5 hours
- **Dependencies**: 952, 960, 963, 964, 969, 973, 980, 981, 982, 984, 987, 988, 992
- **Artifacts**: plans/01_dead-machinery-quarantine.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Executed the research report's corrected per-item triage table across four phases: quarantined
(moved, never deleted) nine genuinely-dead scripts into `deprecated/` directories with per-file
README rationale and manifest de-declaration; repaired and wired in the one valuable-but-unwired
`lint-contract-compliance.sh` as a new `verify-deploy.sh` gate; landed documentation notes
preventing the four legitimate operator tools and the two auto-loaded rule files from being
mis-triaged as dead again; and proved the quarantine holds end to end via a destructive
`deploy-headless.sh --wipe` regeneration and full `verify-deploy.sh` run.

## What Changed

- `agent-system/extensions/core/scripts/deprecated/README.md` — Created; per-file rationale for
  the eight quarantined core scripts, including the mutex/renumbering reactivation hazard note
  for `vault-operation.sh` and the two superseded-duplicate call-outs.
- `agent-system/extensions/core/scripts/deprecated/{check-vault-threshold,vault-operation,
  claude-project-cleanup,orphan-detection,rename-session,roadmap-sync,
  validate-extension-index,archive-task}.sh` — Moved in via `git mv` from `scripts/`.
- `agent-system/extensions/core/manifest.json` — Eight `provides.scripts` entries removed.
- `agent-system/extensions/literature/scripts/deprecated/literature-decode-font-offset.py` —
  Moved in via `git mv`.
- `agent-system/extensions/literature/scripts/deprecated/README.md` — Rationale bullet appended.
- `agent-system/extensions/literature/manifest.json` — One `provides.scripts` entry removed.
- `agent-system/extensions/core/commands/todo.md` — Reworded its `archive-task.sh` mention (now
  `archive-task` script, no bare `.sh` suffix) to keep `check-extension-docs.sh` Rule E green
  after the manifest drop.
- `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` — Root-resolution
  repair: replaced the broken `common_repo_root "$SCRIPT_DIR" 3` (landed on
  `agent-system/extensions` instead of the repo root) with the `lint-agent-contracts.sh` sibling
  pattern (`git rev-parse --show-toplevel`, `REPO_ROOT` env override, relative fallback);
  repointed Check F from the deployed `.claude/context/index.json` to core's source
  `index-entries.json`.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — New gate 11
  (`lint-contract-compliance.sh --verbose`), mirroring gates 6/7's structure.
- `agent-system/extensions/core/merge-sources/claudemd.md` — Five new Utility Scripts entries
  (four operator tools + `lint-contract-compliance.sh`) and a Rules References clarification
  that the `@`-import list is a curated subset.
- `agent-system/extensions/core/context/patterns/context-discovery.md` — New "Rule Loading: Two
  Independent Paths" section documenting the harness-native `paths:` frontmatter glob vs. the
  `CLAUDE.md` `@`-import list.
- `agent-system/extensions/core/rules/pr-prohibition.md` — CSLib deploy-conditional note added
  above the two CSLib subsections; frontmatter untouched.
- `.syncprotect` — Deleted the dead `output/implementation-001.md` line.
- `agent-system/extensions/core/index-entries.json` — `line_count` refreshed via the generator
  (context-discovery.md: 355 -> 375).
- `agent-system/extensions/core/scripts/lib/common.sh` — Reworded historical-consumer comments to
  drop bare quarantined-script basenames; corrected a now-stale claim that
  `lint-contract-compliance.sh` consumes `common_repo_root`.
- `agent-system/extensions/core/context/patterns/task-lock.md` — Same rewording for
  `archive-task.sh`/`vault-operation.sh` historical-consumer mentions.
- `agent-system/extensions/core/scripts/generate-context-line-counts.sh` — Repointed its stale
  `validate-extension-index.sh` precedent reference to `check-extension-docs.sh`'s Rule T.

## Decisions

- Treated Finding 0 (rule-loading) as load-bearing: neither `pr-prohibition.md` nor
  `project-overview-detection.md` was quarantined; both are documented as live via frontmatter.
- Quarantined `archive-task.sh`, `orphan-detection.sh`, `vault-operation.sh` together with
  README notes declaring `commands/todo.md`/`skills/skill-todo/SKILL.md` prose authoritative.
- `lint/lint-contract-compliance.sh` was repaired and wired in, not quarantined.
- `roadmap-sync.sh` and `validate-extension-index.sh` READMEs explicitly record the
  superseded-duplicate relationship for future audits.

## Plan Deviations

- **Phase 1**: reworded `commands/todo.md`'s `archive-task.sh` mention (not in the original
  Files to modify list) — required to keep `check-extension-docs.sh` Rule E
  (`check_referenced_scripts_declared`) green after the manifest drop.
- **Phase 4**: reworded historical-consumer comments in `scripts/lib/common.sh`,
  `context/patterns/task-lock.md`, and `scripts/generate-context-line-counts.sh` (not in any
  phase's original Files to modify list) — required to satisfy Phase 4's dangling-reference-grep
  bar ("hits confined to `deprecated/`"), since these were accurate but non-compliant
  historical/architectural comments naming quarantined basenames outside `deprecated/`.
- **Phase 2/4**: `verify-deploy.sh`'s gate 8 (`tests/run-all.sh`) reports one pre-existing,
  unrelated failure — `test-index-entries-schema.sh` (a fixture-suite defect predating this
  task). Two other transient failures observed during intermediate runs
  (`test-claude-refresh-matcher.sh`, `test-four-tier-conflict.sh`) were confirmed to be PID-race
  flakes: both pass cleanly on isolated re-run and on the final full run. No new failures were
  introduced by this task; this is documented per the delegation's explicit instruction, not
  fixed (out of scope).

## Verification

- Build: N/A (no build step for this task type)
- Tests: `tests/run-all.sh` — 33/34 or 34/34 passed across runs (1 pre-existing, unrelated
  failure; two flaky cases confirmed non-reproducing)
- Files verified: Yes — all nine quarantined files confirmed present under `deprecated/` with
  README rationale bullets; both manifests parse and name none of the nine; deployed `.claude/`
  tree (post `--wipe`) contains none of the nine; dangling-reference grep confined to
  `deprecated/`; `check-extension-docs.sh`, `check-task-references.sh` both PASS

## Impacts

- Nine dead scripts (eight core + one literature) are no longer deployed, reducing deploy-tree
  surface area, while remaining recoverable via `git mv` history and the deprecated READMEs.
- `verify-deploy.sh` now has an 11th gate catching hard-mode contract-compliance regressions that
  were previously silently unchecked.
- The two rule-loading mis-triage vectors (frontmatter-only rules, CSLib-inert prose in a
  universally-live rule) are now documented, reducing the risk of a future audit repeating either
  error.
- Four legitimate manual operator tools are now discoverable in `CLAUDE.md`'s Utility Scripts
  list instead of appearing as unexplained zero-caller orphans.

## Follow-ups

- `test-index-entries-schema.sh`'s pre-existing fixture-suite failure (Rule U not firing on a
  61-line `EXTENSION.md` fixture) remains unfixed — out of this task's scope, flagged for a
  future task.
- `lint/lint-contract-compliance.sh`'s comment/help-text still describes only Tier 1 static
  checks; Tier 3 runtime-behavior checks remain explicitly out of scope (as documented in the
  script's own header), unchanged by this task.

## References

- `specs/985_quarantine_dead_scripts_rules_and_machinery/reports/01_dead-machinery-triage.md`
- `specs/985_quarantine_dead_scripts_rules_and_machinery/plans/01_dead-machinery-quarantine.md`
- `agent-system/extensions/literature/scripts/deprecated/README.md` (format precedent)
