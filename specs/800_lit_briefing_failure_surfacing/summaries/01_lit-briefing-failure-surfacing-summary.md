# Implementation Summary: Task #800

**Completed**: 2026-07-01
**Duration**: ~1 hour

## Overview

Fixed the `--lit` consumer-side anti-pattern across all six core skills
(skill-researcher, skill-planner, skill-implementer, and their `-hard` variants), where
`literature-briefing.sh` crashes were silently indistinguishable from a legitimately empty
briefing (`2>/dev/null` discarded stderr, and `|| lit_context=""` reassigned the same empty
value the crash already produced). Introduced a shared wrapper script,
`.claude/scripts/literature-briefing-invoke.sh`, and repointed all 18 invocation sites at it.

## What Changed

- `.claude/scripts/literature-briefing-invoke.sh` — New wrapper script. Passes args through to
  `literature-briefing.sh` unchanged, captures stdout, lets stderr flow through unmodified, and
  on non-zero exit emits `[lit] briefing generation failed (exit N)` to stderr while still
  exiting 0 (preserving callers' `|| lit_context=""` fallback semantics). Executable, passes
  `bash -n`.
- `.claude/skills/skill-researcher/SKILL.md` — 3 sites repointed to the wrapper; stale
  `# - script exited with error` comment (literature block only) rewritten.
- `.claude/skills/skill-planner/SKILL.md` — same.
- `.claude/skills/skill-implementer/SKILL.md` — same.
- `.claude/skills/skill-researcher-hard/SKILL.md` — same.
- `.claude/skills/skill-planner-hard/SKILL.md` — same.
- `.claude/skills/skill-implementer-hard/SKILL.md` — 3 sites repointed to the wrapper (this
  file's live block had no stale comment to rewrite — see Plan Deviations).

## Decisions

- Used `Edit` with `replace_all: true` on the exact literal substring
  `bash .claude/scripts/literature-briefing.sh 2>/dev/null` per file, since all three sites in
  each file share this substring byte-for-byte.
- Disambiguated the literature-specific "script exited with error" comment from an unrelated,
  identically-worded `# memory_context will be empty string if: ... # - script exited with
  error` comment (Stage 4a memory retrieval) that appears earlier in each of the six files, by
  matching on the surrounding `# lit_context will be empty string if:` block. The memory-context
  comment was correctly left untouched (out of scope).

## Plan Deviations

- **Task 3.4** altered: `skill-implementer-hard/SKILL.md`'s live literature-briefing bash block
  contains no `# lit_context will be empty string if: ... # - script exited with error` comment
  section at all (confirmed via grep across the file). There was nothing to rewrite in that
  file; the canonical comment rewrite was applied to `skill-researcher-hard` and
  `skill-planner-hard` only, where the comment exists.

## Verification

- Build: N/A (markdown/shell task)
- Tests: Passed — `bash -n` clean, wrapper executable, failure path verified (`--global` with
  missing query -> `[lit] briefing generation failed (exit 1)` on stderr, empty stdout, wrapper
  exit 0), success path verified (wrapper stdout byte-identical to direct
  `literature-briefing.sh` invocation in both per-repo and `--global` modes, no stray stderr).
- Files verified: Yes — zero residual `literature-briefing.sh 2>/dev/null` across the six
  skills; `literature-briefing-invoke.sh` appears exactly 3 times in each; `literature-briefing.sh`,
  `literature-lit-flag-resolve.sh`, and the four `skill-cslib-*` skills are byte-unchanged
  (confirmed via `git diff --stat` and `git status --porcelain`).

## Notes

`git status --porcelain` for the six skills + wrapper shows exactly the seven expected changed
files (six `SKILL.md` modifications + one new untracked wrapper script), matching the plan's
declared scope with no drift.
