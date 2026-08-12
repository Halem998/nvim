# Implementation Summary: Task #58

- **Task**: 58 - Add a version-consistency preflight gate to /tag so a tag can never be created or pushed while the package being released declares a different version
- **Status**: [COMPLETED]
- **Started**: 2026-08-12T21:20:00Z
- **Completed**: 2026-08-12T22:55:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_version-consistency-gate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a fail-closed version-consistency gate to `/tag` as a new `Step 3.5: Validate Version
Consistency` in `skill-tag/SKILL.md`, positioned between Step 3 (Compute New Version) and Step 4
(Display Summary) — strictly before Step 5's `--dry-run` `exit 0`, so all four invocation paths
(default, `--force`, `--dry-run`, `--skip-version-check`) traverse it identically. The gate
discovers declared versions across five ecosystem manifest formats (pyproject.toml, setup.cfg,
setup.py, package.json, Cargo.toml) via bounded-depth search from the repo root, fails closed on
any mismatch with an actionable message naming the computed tag, every declared version found,
and the manifest path(s) to edit, and prints an explicit "no declared version found" notice
(never silence) when no manifest declares one. Per DR-1, the gate never auto-bumps or writes to
any manifest — report-and-stop only, matching every other `/tag` failure mode. `commands/tag.md`
was updated so its Workflow (now 8 items), Requirements (now 5 bullets), and Usage flag table
agree with the implemented gate.

## What Changed

- `agent-system/extensions/core/skills/skill-tag/SKILL.md` — added `skip_version_check` flag
  parse to Step 1, a `--skip-version-check` row to the Command Syntax table, the full
  `### Step 3.5: Validate Version Consistency` section (bounded-depth manifest discovery,
  five-format extraction dispatch, mismatch/no-version/match branches), and three new
  `## Error Handling` transcripts (`Version Mismatch`, `No Declared Version Found`,
  `Version Check Skipped by Flag`).
- `agent-system/extensions/core/commands/tag.md` — added a `--skip-version-check` row to the
  Usage flag table, inserted a new Workflow item 3 (`Validate Version Consistency`) renumbering
  the following items to 4-8, and appended a fifth, explicitly conditional Requirements bullet.
- `.claude/skills/skill-tag/SKILL.md` and `.claude/commands/tag.md` — regenerated via
  `deploy-headless.sh`; byte-identical to the source-store files above.

## Decisions

- Implemented DR-1..DR-6 from the plan's Decision Record exactly as recorded (report-and-stop,
  never auto-bump; both `commands/tag.md` lists updated; check every discovered manifest with any
  mismatch failing; exact bare-string comparison after stripping a leading `v`; explicit
  `--skip-version-check` escape hatch that still discloses the divergence; `setup.py` non-match
  treated as no-version-declared, not an error).
- The extraction commands were transcribed verbatim from the research report's sandbox-verified
  shell (portable `sed`/`grep`/`jq` only, no `awk`), not re-derived.

## Plan Deviations

- **Task 3.1** altered: the `### Version Mismatch` transcript's `Error:` line omits the single
  inline declared-version value the research report's example used (`Error: Declared package
  version (1.3.0) does not match computed tag (v1.3.1).`), instead printing `Error: Declared
  package version does not match computed tag ($new_version).` with the declared version(s) and
  manifest path(s) named immediately below under a `Declared in:` list. Reason: DR-3 requires
  checking and listing every discovered manifest (not prioritizing one), and an inline
  single-value Error line does not generalize to the multi-manifest case. All three required
  facts — computed tag, declared version, manifest path — remain present in the transcript, just
  distributed across two lines instead of one.

## Verification

- Build: N/A (markdown/shell documentation change, no build step)
- Tests: Passed — see the 12-cell outcome matrix below
- Files verified: Yes (byte-identical `.claude/` copies after redeploy; syntax-checked with
  `bash -n`; smoke-tested and full end-to-end tested)

### Phase 1 — 10-fixture extraction verification

| Case | Manifest | Expected | Actual |
|------|----------|----------|--------|
| 1 | root `pyproject.toml` (`[project]` 1.3.0 + `[tool.poetry]` 9.9.9) | `1.3.0` | `1.3.0` |
| 2 | `code/pyproject.toml` (subdirectory) | `1.3.0` | `1.3.0` (found at depth 2) |
| 3 | `pyproject.toml` with `dynamic = ["version"]` | empty | empty |
| 4 | `setup.cfg` `[metadata]` `version = 3.2.1` | `3.2.1` | `3.2.1` |
| 5 | `setup.py` literal `version="4.5.6"` | `4.5.6` | `4.5.6` |
| 6 | `setup.py` programmatic version | empty | empty |
| 7 | `package.json` `2.1.0` + `node_modules` decoys | `2.1.0` | `2.1.0` (decoys excluded) |
| 8 | `Cargo.toml` `[package]` `0.4.2` | `0.4.2` | `0.4.2` |
| 9 | `Cargo.toml` `version.workspace = true` | empty | empty |
| 10 | no manifest | no manifest found | no manifest found |

All 10 matched the research report's documented expectations exactly.

### Phase 5 — 12-cell end-to-end outcome matrix

Three real git repos (`R1` match, `R2` mismatch-in-subdirectory, `R3` no manifest), each tagged
`v0.1.0` with a subsequent untagged commit so `git describe --tags --abbrev=0` returns `v0.1.0`
and the default patch increment computes `v0.1.1`.

| Repo | default | `--dry-run` | `--force` | `--skip-version-check` |
|------|---------|-------------|-----------|-------------------------|
| R1 (match, `pyproject.toml` declares `0.1.1`) | exit 0, OK confirmation | exit 0, OK + DRY RUN MODE | exit 0, OK confirmation | exit 0, OK confirmation |
| R2 (mismatch, `code/pyproject.toml` declares stale `0.1.0`) | **exit 1**, mismatch error | **exit 1**, mismatch error | **exit 1**, mismatch error | exit 0, mismatch shown + WARNING override |
| R3 (no manifest) | exit 0, skip notice | exit 0, skip notice + DRY RUN MODE | exit 0, skip notice | exit 0, skip notice |

The single most important cell — **R2 under `--dry-run` exits non-zero with the mismatch
message** — passed, proving both that the gate fires under `--dry-run` (requirement 5) and that
subdirectory manifests are found (requirement 2, the real ModelChecker failure shape).

### Deploy and lint checks

- `deploy-headless.sh` run; `.claude/skills/skill-tag/SKILL.md` and `.claude/commands/tag.md`
  diffed byte-identical against their source-store originals.
- `check-extension-docs.sh` run pre-redeploy (baseline) and post-redeploy via the deployed
  `.claude/scripts/` copy: zero new findings. The one pre-existing FAIL (project-wide Rule S,
  `return-meta-artifacts-template.md` indexing) is unrelated to this task and unchanged in both
  runs.
- `check-task-references.sh`: PASS, 0 unexempted occurrences across all 4 scanned trees.

## Impacts

- `/tag` now blocks (by default) on any declared-version/computed-tag mismatch across five
  ecosystem manifest formats, closing the gap that let the real ModelChecker-shaped failure
  (subdirectory manifest, stale version) reach CI undetected.
- Repos with no manifest (including this Lua/Nix repo) are unaffected beyond one added notice
  line in the transcript.
- No new tool dependency: `jq` was already required by Step 7.

## Follow-ups

- Poetry-only `[tool.poetry]` pyproject layouts, workspace-root Cargo resolution, and monorepo
  per-package version policies remain unsupported (explicit Non-Goals in the plan).
- No lint enforces `SKILL.md`/`commands/tag.md` prose parity going forward — a future task could
  extract the five extraction commands into a shared, reusable context file (research
  recommendation, out of this task's file scope) and/or add a doc-parity check to
  `check-extension-docs.sh`.

## References

- `specs/058_add_version_consistency_gate_to_tag/plans/01_version-consistency-gate.md`
- `specs/058_add_version_consistency_gate_to_tag/reports/01_version-consistency-gate.md`
- `specs/058_add_version_consistency_gate_to_tag/progress/phase-{1..5}-progress.json`
