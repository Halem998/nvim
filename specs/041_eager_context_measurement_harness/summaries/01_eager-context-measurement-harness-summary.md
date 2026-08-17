# Implementation Summary: Task #41

- **Task**: 41 - eager_context_measurement_harness
- **Status**: [COMPLETED]
- **Started**: 2026-08-17T18:10:00Z
- **Completed**: 2026-08-17T19:05:00Z
- **Effort**: 6.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_eager-context-measurement-harness.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built `agent-system/extensions/core/scripts/measure-eager-context.sh`, a harness that PREDICTS
the session-start eager context set from the source store alone — replicating
`generate_claudemd()`'s assembly algorithm in bash against source-store files, resolving
`@`-imports directory-relatively, and deriving the eager rule set by glob-matching each rule's
`paths:` frontmatter against a documented, overridable representative touched-path set — never by
reading or regenerating the deployed `.claude/` tree. All six plan phases completed; the script is
registered in the core manifest and catalogued in the utility-scripts inventory alongside its
predecessor.

## What Changed

- `agent-system/extensions/core/scripts/measure-eager-context.sh` — new file. Predictive
  eager-context measurement harness: parent CLAUDE.md chain, predicted assembled
  `.claude/CLAUDE.md` (materialized in a scratch file and measured with `wc -c`, correctly
  handling the untrimmed-header/trimmed-fragment asymmetry in `generate_claudemd()`), `@`-import
  resolution, and dynamic `paths:` glob-match rule classification via a hand-written `glob_to_ere`
  translator (`[[ str =~ ere ]]`, not `[[ str == pattern ]]`, which cannot correctly match `**`
  across path segments). `--check` (default) / `--write [path]` split with `--write` emitting a
  `jq -n`-built JSON snapshot. Volatile-file deny-list (`specs/TODO.md`, `specs/state.json`,
  `specs/errors.json`) flags and excludes rather than silently counting.
- `agent-system/extensions/core/manifest.json` — added `measure-eager-context.sh` to
  `provides.scripts`, placed alphabetically before `measure-eager-surface.sh`.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — added entries for
  both `measure-eager-context.sh` and (filling a pre-existing gap flagged by the research report)
  `measure-eager-surface.sh`, with an explicit coexistence statement in both entries.
- `agent-system/extensions/core/context/architecture/context-layers.md` — fixed the stale citation
  path (`specs/054_split_eager_rules_budget/baseline-bytes.md` -> the correct
  `specs/archive/054_split_eager_rules_budget/baseline-bytes.md`), added the section-heading
  anchor ("Eager-Context Measurement-Harness Correction"), and added a one-sentence pointer naming
  `scripts/measure-eager-context.sh` as the tool implementing the corrected glob-match model.

## Decisions

- **Predicted-CLAUDE.md computed by materialization, not arithmetic.** `generate_claudemd()`
  trims each fragment (`fragment:gsub("%s+$", "")`) but does NOT trim the prepended header
  template — an asymmetry confirmed by direct read of `merge.lua:855-869` and by the fact that
  `claudemd-header.md` ends in two raw newlines. Building the predicted document in a `mktemp`
  file and measuring it with `wc -c` sidesteps having to get this asymmetry right in hand-rolled
  byte arithmetic; it reproduced the deployed `.claude/CLAUDE.md`'s 33,215 B exactly on the first
  correct implementation.
- **`glob_to_ere` uses `[[ str =~ ere ]]`, never bash's own `[[ str == pattern ]]`.** Verified by
  a direct test showing bash's native glob matching treats `**` as a plain `*` (which does not
  cross `/`), so `specs/**/*` would silently fail to match a 3-segment nested path under that
  form. All ten required unit cases (`specs/**/*`, `.claude/**/*`, `**/*` against both probes,
  `specs/**/plans/**` and `**/*.lean` against both probes, and the narrow single-file
  `project-overview-detection.md` glob) pass.
- **A `local a=x b=$a` bash bug was found and avoided.** Initial testing showed `local pat="$1"
  out="$pat"` silently leaves `out` empty — bash does not make `$pat`'s newly-assigned value
  visible to a subsequent assignment within the same `local` statement. Fixed by splitting into
  two separate `local` statements; this is now how `glob_to_ere()` is written in the script.
- **Corrected `paths:` model implemented as literally specified by the research report and
  planner**, not the task description's original "absent or `**/*`" reading: `EAGER_REP_PATHS`
  defaults to one `specs/**` probe and one `.claude/**` probe, both overridable via the
  `EAGER_REP_PATHS` env var (comma-separated), echoed in every run's output.

## Plan Deviations

- None (implementation followed plan). Phase 1's task list offered two options for computing the
  predicted assembled size ("without materializing the whole document" vs. "building the predicted
  document in a `mktemp` file and measuring it — either is acceptable"); the mktemp route was
  selected for the reason given above, and this is an explicitly plan-sanctioned choice, not a
  deviation.

## Verification

- Build: N/A (bash script, no build step)
- Tests: Passed — `bash -n` clean; `--check` exits 0 on the live tree; `--bogus` exits 2 with a
  `Usage:` line; two consecutive `--check` runs produce byte-identical stdout; `--write` produces
  `jq empty`-valid JSON; `glob_to_ere` unit cases all pass; narrowing `EAGER_REP_PATHS` to the
  `specs/**` probe alone reproduces the historical 23,547 B six-rule total; a scratch-copy
  volatile-file injection (`@specs/state.json`) produces a `FLAG:` line and exit 1; a
  scratch-copy dangling-ref injection produces a `DANGLING:` line with exit 0 (both scratch
  changes discarded, not committed); `jq empty` passes on `manifest.json`; the script appears
  exactly once in `provides.scripts`; `check-task-references.sh` reports 0 unexempted
  occurrences across all four scanned trees.
- Files verified: Yes — all four changed files (script, manifest, inventory, context-layers.md)
  confirmed present and correct via direct read after each edit.
- Anti-pattern guards confirmed: `grep -nE 'deploy-headless|nvim --headless'` on the script
  matches only the header comment's prohibition text (two lines, both inside the doc comment
  block); `grep -n '\.claude/CLAUDE\.md\|\.claude/rules'` shows no measurement read of the
  deployed tree (all matches are comments, labels, or the mktemp-based `PREDICTED_CLAUDEMD_TMP`
  variable's directory-context string, never an actual file read); no hardcoded rule filename
  appears in the classification code path (only inside comments).
- Doc-lint (`check-extension-docs.sh`): two pre-existing FAILs remain
  (`command-route-agent.sh`/`test-routing-resolution.sh` deploy-content drift, and Rule S's
  `return-meta-artifacts-template.md` index gap) — confirmed pre-existing via a `git stash`
  comparison against pre-task HEAD, unrelated to any file this task touched. The
  `measure-eager-context.sh` file itself is correctly reported as "script not deployed, skipping
  drift check" (expected: source-store-only work, no redeploy performed).

### Baseline Reconciliation

The recorded baseline (`specs/archive/054_split_eager_rules_budget/baseline-bytes.md`, Phase 7
post-redeploy whole-prefix figure) is **70,160 B / 17,540 tokens**, decomposed as
`parent + repo + assembled + six rules (23,547 B)`.

The harness's own current-run total is **64,323 B / 16,080 tokens**, decomposed as
`parent (769 B) + repo (3,046 B) + assembled (33,215 B) + eight rules (27,293 B)`.

| Component | Baseline (70,160 B) | Current (64,323 B) | Delta |
|---|---|---|---|
| parent CLAUDE.md + repo CLAUDE.md + assembled `.claude/CLAUDE.md` | 46,613 B (implied: 70,160 − 23,547) | 37,030 B (769 + 3,046 + 33,215) | **−9,583 B** (genuine shrinkage since the Phase-7 measurement) |
| Eager rules | 23,547 B (six-rule historical class) | 27,293 B (eight-rule corrected-model class) | **+3,746 B** (`error-handling.md` 2,987 B + `workflows.md` 759 B, newly counted by the corrected `.claude/**`-inclusive glob-match model) |
| **Total** | **70,160 B** | **64,323 B** | **−5,837 B** (net) |

Both halves of the decomposition were verified directly against the script's own per-source
output (not assumed): the `+3,746 B` figure equals the sum of the two newly-counted rules' exact
byte counts (2,987 + 759 = 3,746); the `−9,583 B` figure is the current parent+repo+assembled
group's actual measured total (37,030 B) minus the baseline's implied group total
(70,160 − 23,547 = 46,613 B). The net delta (−5,837 B) reconciles exactly: 70,160 − 5,837 =
64,323, matching the harness's own reported total with no unexplained residual. The model was not
adjusted to force a match to 70,160 B — the delta is explained, not reconciled away.

The "~9.5k tokens after" figure named in the original task description was **not validated**:
per the research report's Finding 5, it has no citable source anywhere in the repository and
reads as an externally-supplied target for a not-yet-scoped future normalization pass, not an
assertion this measurement harness is responsible for reproducing.

## Impacts

- Future work aiming to reduce the eager context budget now has an instrument that predicts the
  effect of a source-store change *before* a redeploy, closing the staleness gap the prior
  `measure-eager-surface.sh` (deployed-tree, hardcoded-list) could not close.
- The corrected `paths:` glob-match model surfaces `error-handling.md` and `workflows.md` as
  genuinely eager, which the historical six-rule accounting understated. Any future "eager budget
  ceiling" policy decision should use the eight-rule, 27,293 B figure as its baseline going
  forward, not the six-rule 23,547 B figure.

## Follow-ups

- None required by this task. A natural next step (not in scope here, per the plan's Non-Goals)
  would be a downward-normalization pass targeting the corrected 64,323 B total, using this
  harness as its measurement instrument.

## References

- `specs/041_eager_context_measurement_harness/reports/01_eager-context-measurement-harness.md`
- `specs/041_eager_context_measurement_harness/plans/01_eager-context-measurement-harness.md`
- `specs/archive/054_split_eager_rules_budget/baseline-bytes.md` (section "Eager-Context
  Measurement-Harness Correction")
- `agent-system/extensions/core/scripts/measure-eager-context.sh`
- `agent-system/extensions/core/context/architecture/context-layers.md`
