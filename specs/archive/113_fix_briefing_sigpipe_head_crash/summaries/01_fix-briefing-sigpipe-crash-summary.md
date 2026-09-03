# Implementation Summary: Task #113

- **Task**: 113 - Fix the SIGPIPE crash that makes repo-mode `--lit` briefing fail outright
- **Status**: [COMPLETED]
- **Started**: 2026-09-02T16:00:00Z
- **Completed**: 2026-09-02T16:30:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_fix-briefing-sigpipe-crash.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed the exit-141 SIGPIPE crash in `agent-system/extensions/literature/scripts/literature-briefing.sh`'s
repo mode by replacing two `jq -r ... | head -1` pipelines (which pipe a whole pretty-printed JSON
object into a line-truncating `head`, causing jq to receive SIGPIPE under `set -euo pipefail`)
with jq-internal `jq -c 'first(.entries[] | select(...))'` bounds. All four phases completed:
pre-fix baseline capture, the two-site fix, an audit of the remaining 8 `| head -1` sites, and
end-to-end verification against the real observed failing case
(`~/Projects/Logos/Theory/specs/literature-index.json` against the live
`~/Projects/Literature/index.json`, which contains the crash-triggering
`horty_2001_agency-and-deontic-logic` entry).

## What Changed

- `agent-system/extensions/literature/scripts/literature-briefing.sh` — replaced both
  `parent_entry` extraction pipelines (previously `:238-241` strict, `:245-247` fallback) with
  `jq -c --arg id "$doc_id" 'first(.entries[] | select(...))' "$GLOBAL_INDEX" 2>/dev/null`,
  removing `head` from both pipelines entirely. The `(.id // .doc_id)` stub-entry tolerance and
  the two-step strict-then-fallback lookup structure (two separate queries, two `[ -z ... ]`
  checks) are preserved verbatim. No other line in the file was touched.

## Decisions

- Chose Option 2 (`first(...)`, dropping `head` entirely) over Option 1 (`-c` alone with `head`
  retained), per the plan and research report: it removes the SIGPIPE structurally for any future
  entry size and stops jq's scan at the first match instead of streaming every match into a
  discarded pipe.
- Discovered mid-Phase-1 that `literature-briefing.sh` resolves `PROJECT_ROOT` from its own
  on-disk location (`$SCRIPT_DIR/../..` via `BASH_SOURCE`), not from `$PWD`. The plan's literal
  invocation instruction (`cd ~/Projects/Logos/Theory && bash <absolute source-store path> ...`)
  therefore never reaches repo mode when the source-store copy is invoked by absolute path — it
  silently hits the script's documented sub-index-missing/exit-0/empty-stdout branch instead. This
  is a pre-existing, out-of-scope property of the script (not part of this task's fix). Built an
  equivalent scratch harness mirroring the real per-repo `.claude/scripts/` deploy layout (script
  content copied verbatim + the real Logos/Theory sub-index content copied verbatim, against the
  real live global index via the unmodified `LITERATURE_DIR` default) to genuinely exercise repo
  mode's crash sites and the fix against real data, for both Phase 1 and Phase 4, without touching
  any file outside the scratchpad or the declared source-store target. This produced a live 141
  reproduction that the literal plan invocation would have missed entirely.

## Plan Deviations

- **Task 1.4** altered: literal `cd`+absolute-path invocation replaced with the equivalent scratch
  harness described above, because the literal command never reaches repo mode (see Decisions).
  This IS the authoritative pre-fix baseline used for Phase 4's diff.
- **Task 4.1** altered: same substitution applied to the fixed-script re-run for the same reason.

## Verification

- Build: N/A (bash script, no build step)
- Tests: N/A (no test suite for this script); manual verification per phase below
- Files verified: Yes

**Phase 2** (the fix itself):
- `bash -n` exits 0.
- `grep -c "head -1"` returns 8 (down from 10, as expected).
- `grep -n "parent_entry"` returns exactly 4 hits (two-step lookup structure intact).
- `grep -c 'first(.entries\[\]'` returns 2.
- `(.id // .doc_id)` tolerance present at both new sites.
- `set -euo pipefail` at line 63 unchanged.
- `git diff --stat` shows exactly one file changed.

**Phase 3** (audit): all 8 remaining `| head -1` sites individually read and classified as
scalar-emitting (string, joined string, `tostring`-coerced number, or number with `// 0`
fallback) — `:175` `.provenance_fidelity // empty`; `:261` `.title // "Unknown Title"`; `:265`
joined `.authors`; `:269` `.year | tostring`; `:285` and `:291` `.token_count // 0`; `:299`
`.path // ""`; `:320` `.relevance // ""`. Zero sites emit an object or array. No code change
required.

**Phase 1 + Phase 4** (baseline vs. fixed, via the scratch harness):
- Pre-fix baseline: exit **141** (live SIGPIPE reproduced against the real
  `horty_2001_agency-and-deontic-logic` entry), `BASELINE.out`/`BASELINE.err` both 0 bytes.
- Deterministic mechanism repro: `jq -n ... | head -1` under `pipefail` → 141; `jq -cn` counterpart
  → 0.
- Fixed run: exit **0**, `FIXED.out` 18,774 bytes, all 52 requested sub-index documents resolved
  (`resolved=52 skipped=0` in the `<!-- lit-coverage ... -->` marker).
- `diff BASELINE.out FIXED.out`: 238 pure additions, zero modified/removed shared lines (baseline
  was empty, so this satisfies bar #2 under the plan's explicit empty-baseline fallback clause).
- `horty_2001_agency-and-deontic-logic` resolved successfully as entry #48/52 (296 chunks, ~124,241
  tokens) — the exact doc_id that crashed the pre-fix baseline.
- `<!-- lit-coverage ... -->` marker present and well-formed.
- Second, unrelated query (`--query "separation logic frame rule"`) also exits 0 with non-empty
  output (237 lines), confirming the fix is not query-specific.
- `.claude/scripts/literature-briefing.sh` (this repo's deploy copy) confirmed untouched
  throughout (`git status --short` returns no output).

## Impacts

- `--lit` briefing in repo mode no longer crashes with exit 141 against sub-indices whose global
  index contains a large entry (any entry whose pretty-printed JSON representation exceeds the
  64KB pipe buffer, or which simply loses the pipe-buffer race under system load).
- No downstream behavior change: `parent_entry` is only emptiness-tested elsewhere in the file,
  never string-parsed, so switching from `-r`/multi-line to `-c`/single-line output has no
  observable effect beyond eliminating the crash.

## Follow-ups

- A repo-wide sweep for the same `jq | head` idiom in other extension scripts was explicitly
  out of scope for this task (see plan Non-Goals) but flagged by the research report as a
  worthwhile follow-up, along with a possible `context/patterns/jq-pipeline-safety.md`.
- The `literature-briefing.sh` `PROJECT_ROOT`-resolves-from-`$SCRIPT_DIR`-not-`$PWD` behavior
  discovered during Phase 1 is a pre-existing, separate property of the script's per-repo-deploy
  design (source-store invocation by absolute path cannot exercise a different repo's sub-index).
  It did not block this task (a scratch harness worked around it faithfully), but it's worth
  noting for anyone else invoking the source-store copy directly for ad hoc testing.

## References

- Plan: `specs/113_fix_briefing_sigpipe_head_crash/plans/01_fix-briefing-sigpipe-crash.md`
- Research: `specs/113_fix_briefing_sigpipe_head_crash/reports/01_sigpipe-head-crash-fix.md`
- Progress files: `specs/113_fix_briefing_sigpipe_head_crash/progress/phase-{1,2,3,4}-progress.json`
