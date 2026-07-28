# Implementation Summary: Task #940

- **Task**: 940 - summary_metadata_header_compliance
- **Status**: [COMPLETED]
- **Started**: 2026-07-28T00:00:00Z
- **Completed**: 2026-07-28T01:15:00Z
- **Effort**: ~1 session (5 phases)
- **Dependencies**: None
- **Artifacts**: plans/01_summary-header-template-fix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Research established that `general-implementation-agent.md`'s own Stage 6 carried a literal,
ready-to-copy summary skeleton (`**Completed**:` / `**Duration**:` only) that never matched
`context/formats/summary-format.md`, and that this concrete inline template beat both the
already-standing Stage 4b format injection and the real-time PostToolUse hook. This
implementation reconciled that template in place, brought `summary-format.md`'s own Example
Skeleton into line with its declared field list, closed the hard-mode postflight-validation gap,
recorded the non-blocking enforcement posture explicitly, and repaired `validate-artifact.sh`'s
`--fix` path so a future regression produces a readable diagnostic instead of a crash.

## What Changed

- `agent-system/extensions/core/context/formats/summary-format.md` — Example Skeleton now lists
  all eight required metadata fields (added `Effort`, `Dependencies`, `Standards`), matching its
  own `## Metadata (required)` list.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — Stage 6's fenced
  skeleton replaced with a fully-conformant template: all eight metadata bullets and all six
  required sections (`Overview`, `What Changed`, `Decisions`, `Impacts`, `Follow-ups`,
  `References`), while retaining the two locally valuable extra sections (`Plan Deviations`,
  `Verification`). Added directive sentences naming the block as authoritative and naming the
  `Status` vocabulary.
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — confirmed
  unchanged; its Stage 6 still reads "Same as base agent" with no duplicated skeleton
  (`grep -c 'Implementation Summary: Task #'` returns 0).
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` — Stage 6a: dropped `--fix`
  from the `validate-artifact.sh` invocation; replaced the auto-repair note with the posture
  rationale (non-blocking, no auto-repair for summaries).
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` — inserted a new
  `### Stage 6a: Validate Artifact Content` between `Stage 6: Parse Subagent Return` and
  `Stage 7: Update Task Status (Postflight)`, mirroring the corrected base-skill block.
- `agent-system/extensions/core/scripts/validate-artifact.sh` — `--fix` block: anchor search now
  restricted to lines naming a known `metadata_fields` entry (built from the array itself, bullet
  or bare form) instead of any bold bullet in the document; insertion rewritten via an `awk` pass
  to a temp file + `mv` instead of a `sed -i` that could abort on ordinary prose content; a
  latent, independent `set -e`/`pipefail` abort on the no-match path (discovered during this
  phase's own verification, not named in the plan) was also fixed with a one-line `|| true`
  guard so the existing "Cannot auto-fix" warning branch is reachable again.
- `specs/940_summary_metadata_header_compliance/summaries/01_summary-header-template-fix-summary.md`
  — this file, the live test of the corrected template (see Verification).

## Decisions

- Fixed the root-cause template in place (Stage 6 of `general-implementation-agent.md`) rather
  than adding a third cross-reference to the spec — per research, two already-standing checks
  (Stage 4b injection, real-time PostToolUse hook) were already being overridden by this same
  concrete inline skeleton, so a third reference would not have changed the outcome.
- Kept summary validation non-blocking and dropped `--fix` from both implementer call sites
  (item C): a `TBD`-placeholder auto-repair would make a non-compliant artifact look compliant
  to the validator while conveying nothing to the human reader the header exists to serve.
- Widened scope beyond the plan's Declared Footprint by exactly one line, inside the file already
  declared "widened" (`validate-artifact.sh`): fixed a second, independently-discovered
  `set -e`/`pipefail` abort on the anchor search's no-match path. This was required to satisfy the
  plan's own Phase 4 "no-anchor case" verification, which failed against the code as the plan
  literally specified it (the pre-existing `grep | tail | cut` pipeline aborts the whole script
  silently when grep finds nothing, under `set -euo pipefail`). No other file was touched beyond
  what the plan declared.

## Plan Deviations

- **Task 4.extra** altered: added a `|| true` guard to the `--fix` anchor-search assignment in
  `validate-artifact.sh`, beyond the plan's four listed Phase 4 tasks. Reason: the plan's own
  "no-anchor case" verification (a summary with zero metadata lines) failed without this guard —
  the anchor search's `grep` returns exit 1 on no match, and under `set -euo pipefail` a bare
  `var=$(cmd | cmd | cmd)` assignment propagates that failure and silently aborts the script
  before the `log_warn "Cannot auto-fix..."` line or the terminal `[FAIL]`/`[PASS]` summary ever
  print — the same crash class Phase 4 exists to remove, just on a different code path than the
  one reproduced in research. Fixing it was necessary to make the plan's own required verification
  pass at all, not a scope choice.
- No other deviations. All five phases were executed in full as declared; no task was skipped,
  and no other file outside the plan's Declared Footprint was modified.

## Verification

- **Compliant-artifact check**: ran
  `bash agent-system/extensions/core/scripts/validate-artifact.sh <this file> summary` against
  this summary (before this Verification section's final text was locked in, using a
  representative instance of the same header/section shape) —
  ```
  Validating summary: specs/940_summary_metadata_header_compliance/summaries/01_summary-header-template-fix-summary.md
  [PASS] summary artifact is valid (0 warning(s))
  ```
  Exit code 0, zero `[ERROR]` lines, zero `WARNING:` text.
- **`--fix` no-op check**: running the same command with `--fix` appended against the compliant
  artifact produced no `[FIXED]` line and exit 0 — a compliant artifact never triggers auto-repair.
- **Negative control**: copied this summary to a scratch path, deleted its metadata block (the 8
  bullet lines), and re-ran without `--fix`. Verbatim result: `[ERROR] Missing metadata field:
  **Status**:` / `**Started**:` / `**Artifacts**:` / `**Standards**:`, then `[FAIL] 4 error(s), 0
  warning(s)`, exit 1 — a readable signal, not a crash. Note, reported honestly rather than
  glossed over: only 4 of the 6 `SUMMARY_METADATA` fields showed as missing, not all 6. The
  validator's metadata check is a whole-document `grep -qF "**${field}**:"`, and this summary's
  own prose (this Verification section and the Overview, describing the defective old template
  and quoting `**Completed**:`/`**Task**:` illustratively) happens to contain those exact bold
  substrings elsewhere in the file, so `**Task**:` and `**Completed**:` still "pass" the
  whole-document check even with the real metadata block deleted. This is a genuine, mildly
  self-referential edge case in the validator's substring-based check (not a defect this task's
  scope covers, and not something Phase 4 touched), surfaced only because this summary's own body
  text discusses the very field names it is validating.
- **Gate-out simulation**: ran the exact `if ! bash ... ; then echo "WARNING: ..." ; fi` form used
  at the implementer Stage 6a call site against the compliant artifact; no `WARNING:` line printed.
- **Crash-regression case** (Phase 4): copied a historical non-compliant summary
  (`specs/908_.../summaries/01_git-index-contention-summary.md`, containing a
  `- **Files verified**: Yes — ...` em-dash bullet) to a scratch path and ran `--fix`: reached a
  terminal `[FIXED] 5 field(s) auto-repaired, 3 error(s), 0 warning(s) remaining` line, exit 2, no
  `sed:` error. The inserted `TBD` lines landed in the metadata block near the top (immediately
  after the existing `**Completed**:` line), not inside the Verification section.
- **No-anchor case** (Phase 4, and the deviation above): a scratch summary with an H1 and zero
  metadata lines produced `[WARN] Cannot auto-fix: no existing metadata lines found to anchor
  insertion`, then a terminal `[FAIL] 11 error(s), 1 warning(s)` line, exit 1 — reached only after
  the `|| true` fix; before it, the script aborted silently with no output past the `[ERROR]`
  lines and no terminal line at all.
- **No-regression case**: ran the corrected script (no `--fix`) over this task's own plan and
  report artifacts — both still `[PASS]`, exit 0, matching pre-change behavior.
- Build: N/A (Markdown/Bash edits only; `bash -n` passed clean on `validate-artifact.sh` and on
  both extracted Stage 6a bash blocks from `skill-implementer/SKILL.md` and
  `skill-implementer-hard/SKILL.md`).
- Tests: Passed (all Phase 1-4 field/section greps, `bash -n` checks, and the five Phase 5 cases
  above).
- Files verified: Yes.
- `git status --short` at time of writing shows edits confined to the six files in the Declared
  Footprint plus this task's `specs/` artifacts — no `.claude/**` path appears, and no deploy was
  run (the deployed `.claude/` tree remains deliberately stale for this session, per the binding
  constraint given at dispatch).

## Impacts

- Every future `/implement` and `/implement --hard` dispatch that writes an implementation summary
  now inherits a Stage 6 template that is literally conformant with `summary-format.md`, closing
  the actual point of divergence rather than adding another advisory layer on top of it.
- Hard-mode implementation dispatches now receive the same final postflight validation confirmation
  that base-mode, research, and planning dispatches already had; previously they had only the
  real-time PostToolUse hook with no postflight check.
- A future genuine regression in summary compliance will again produce a visible, non-zero-noise
  `WARNING:` at gate-out, because a compliant run now produces none — restoring the signal value
  of both existing advisory checks without adding a new one.
- `validate-artifact.sh --fix`, used standalone or by any other future caller, can no longer abort
  mid-run on ordinary artifact prose, and no longer mis-anchors on a bold bullet inside a
  Verification section.

## Follow-ups

- **Acceptance criterion (item E) status — reported honestly, not asserted**: this summary
  demonstrates that a summary instantiated from the corrected template validates clean against the
  source-store validator, and that the negative control produces a readable failure rather than a
  crash. It does **not** yet demonstrate a fully autonomous future dispatch, because I — the agent
  writing it — was given explicit, detailed instructions in this dispatch's own prompt pointing
  directly at the corrected Stage 6 template and the exact validation commands to run. That is the
  same kind of dispatch-prompt-level help that produced the two prior "compliant" in-session
  summaries research flagged as non-representative, and it is the crutch this task exists to
  remove. The only evidence that removing it actually works is structural: Stage 6 in the deployed
  source file is now the single template consulted for summary shape, and it is now byte-for-byte
  conformant with the validator's arrays (verified field-by-field above) — but a live, low-context,
  no-hand-holding `/implement` dispatch against a deployed copy of this corrected agent file has
  not been run in this session, per the explicit no-redeploy constraint. That is the one gap
  between "the template is fixed and self-validates" and "item E's acceptance criterion is proven
  under real autonomous conditions."
- **Known, accepted residual** (per the plan's Enforcement Posture section): `skill-base.sh`'s
  `skill_validate_task_artifacts` sweeps an entire task directory, so a task directory that already
  contains historical non-compliant summaries can still warn. This is a direct consequence of
  backfill being explicitly out of scope (item D) and is not a regression from this fix.
- No redeploy was performed in this session; the deployed `.claude/` tree remains stale by design.
  A future deliberate redeploy is required before any live dispatch actually exercises the
  corrected template end-to-end.

## References

- `specs/940_summary_metadata_header_compliance/plans/01_summary-header-template-fix.md` (the plan
  this summary implements)
- `specs/940_summary_metadata_header_compliance/reports/01_summary-metadata-header-compliance.md`
  (the research establishing root cause, historical scope, and the `--fix` crash)
- `agent-system/extensions/core/context/formats/summary-format.md` (the spec this template now
  matches)
- `agent-system/extensions/core/scripts/validate-artifact.sh` (the validator exercised throughout
  this Verification section)
