# Implementation Summary: Task #890

**Completed**: 2026-07-18
**Duration**: ~1.5 hours

## Overview

Back-ported five already-completed, already-verified tooling-defect fixes (provenance: review
review-2026-07-16, core extension) from the downstream Hardware project's disposable,
git-ignored deploy tree into the agent-system SOURCE store at
`agent-system/extensions/core/`, so the fixes survive the next `.claude/` regeneration via the
Neovim extension loader. All five phases completed and were verified in the source context. The
one non-mechanical hazard flagged by research — `generate-task-order.sh`'s finished deploy-tree
version being stale and missing the `deploy-root-guard.sh` sourcing line — was handled via a
targeted Edit rather than a whole-file copy, confirmed by baseline/regression grep assertions
and a post-edit diff against the reference file showing only the (intentionally preserved)
guard line as a remaining difference.

## What Changed

- `/home/benjamin/.config/nvim/agent-system/extensions/core/scripts/roadmap-integration.sh` —
  whole-file copy from the finished reference (no drift hazard confirmed by grep). Applies
  Defect 1 (argv-length-overflow fix at both call sites: file path passed via argv instead of
  file content, and `ROADMAP_STATE`/`ALL_COMPLETED` passed via `mktemp` temp files instead of
  argv) and Defect 3 (generic any-column-count table parser, lookahead-based header detection,
  shared `find_match()` helper, additive `status_tables` matching loop).
- `/home/benjamin/.config/nvim/agent-system/extensions/core/commands/review.md` — whole-file
  copy from the finished reference (clean ~29-line additive diff, no drift). Applies Defect 2:
  captures `roadmap_exit=$?` immediately after the `roadmap-integration.sh` invocation and adds
  an `elif` branch that surfaces a warning and falls back to empty-state defaults on non-zero
  exit or empty output, instead of silently defaulting.
- `/home/benjamin/.config/nvim/agent-system/extensions/core/scripts/generate-task-order.sh` —
  TARGETED EDIT ONLY (never whole-file copy). Applies Defect 4: adds
  `undeclared_topics`/`undeclared_topic_task` tracking and a symmetric stderr warning block for
  topics present on a task but absent from `active_topics_order`. The `deploy-root-guard.sh`
  sourcing line (present in current source, absent from the stale deploy-tree file) was
  preserved throughout — confirmed by baseline grep (before), regression grep (after), and a
  post-edit diff against the reference file showing the guard line as the sole remaining
  difference.
- `/home/benjamin/.config/nvim/agent-system/extensions/core/context/formats/task-order-format.md`
  — whole-file copy from the finished reference. Applies the Defect 4 "Append-extras behavior"
  documentation paragraph to step 7 of the algorithm description. The pre-existing, unrelated
  `*Updated 2026-05-15...*` line was left untouched.
- `/home/benjamin/.config/nvim/agent-system/extensions/core/hooks/validate-no-task-references.sh`
  — NEW file (Defect 5), byte-identical copy from the finished reference, `chmod +x`'d.
  Non-blocking `PostToolUse` advisory hook: scans Write/Edit content outside `specs/**` for
  task-number citation patterns and surfaces an `additionalContext` reminder (always exits 0).
- `/home/benjamin/.config/nvim/agent-system/extensions/core/merge-sources/settings-hooks.json`
  — added a NEW standalone top-level `PostToolUse` key with one `Write|Edit` matcher block
  wrapping the new hook's invocation command, per the research report's Finding 4 exact shape.
  Did NOT copy the deploy tree's full `PostToolUse` array (which would have silently dropped
  unrelated `events-log-artifact.sh` wiring that lives in the out-of-scope
  `root-files/settings.json`).

## Decisions

- `roadmap-integration.sh`, `review.md`, and `task-order-format.md` were applied via whole-file
  copy after confirming (via diff review and, for the script, a `deploy-root-guard.sh` grep) that
  the finished deploy-tree version had no drift relative to current source for that file.
- `generate-task-order.sh` was the one file requiring a targeted Edit rather than a copy, per the
  research report's explicit caution about the missing `deploy-root-guard.sh` sourcing line in
  the stale deploy-tree version.
- `settings-hooks.json` received only the single new `PostToolUse` `Write|Edit` block, not the
  deploy tree's full array, to avoid dropping unrelated hook wiring out of scope for this task.
- The incidental "Hardware Port" column-name example in a `roadmap-integration.sh` code comment
  (a real ROADMAP.md schema column name, not a project-identifier leak) was kept verbatim per the
  plan's explicit non-blocking guidance.

## Plan Deviations

- **Testing & Validation, Defect 3 criterion** (altered): the plan's literal verification
  criterion — `annotation_summary.annotations_made` non-zero against a synthetic table-format
  `ROADMAP.md` — did not hold for a pure-table (no-checkbox) fixture, because the annotation
  write-back mechanism (lines ~436-520 of `roadmap-integration.sh`) only replaces literal
  `- [ ] {text}` checkbox lines and was not touched by Defect 3's diff. This was confirmed to be
  pre-existing, correct, non-regressed behavior — not a defect in the back-port — by running the
  identical synthetic fixture against both the newly-copied source file and the finished
  Hardware reference file and observing byte-identical output (`annotations_made: 0` in both).
  The substantive parsing/matching fix WAS verified successfully: `roadmap_matches` is now
  correctly populated for the table-format fixture (one high-confidence match found), whereas
  running the same fixture against the pre-fix (git history) version of the file produced an
  empty `roadmap_matches` array due to the old fixed-arity 3-column regex mis-parsing the 4-column
  table (treating the separator row and a data row as garbled single cells). This before/after
  comparison is the strongest available evidence the fix works as intended.

## Verification

- Build: N/A (bash scripts, verified via `bash -n` syntax checks)
- Tests: Passed — all 5 defects verified per the plan's phase-level and Phase 5 cross-cutting
  verification sections (see Plan Deviations above for the one criterion that required
  reinterpretation)
  - Defect 1: exit 0 against a 209,980-byte state.json payload (was exit 126 pre-fix)
  - Defect 2: extracted snippet against a throwaway `exit 1` `roadmap-integration.sh` surfaced
    the warning and set `annotations_made=0` with an explicit message, instead of a silent default
  - Defect 3: `roadmap_matches` correctly non-empty against a synthetic 4-column table-format
    `ROADMAP.md` (was empty pre-fix, confirmed via git-history before/after comparison)
  - Defect 4: `deploy-root-guard.sh` sourcing preserved (baseline + regression grep both passed,
    post-edit diff against reference shows only the guard line remaining); `undeclared_topics`
    warning block present; `bash -n` clean; doc paragraph present
  - Defect 5: hook `chmod +x`'d; live stdin invocation confirmed non-blocking (exit 0) for both
    the outside-`specs/**` reminder case and the inside-`specs/**` silent case;
    `jq . settings-hooks.json` parses with the new `PostToolUse` block as a distinct entry
- Files verified: Yes — all six target files confirmed present with intended changes; line
  counts match or exceed expectations (548/854/972/415/61/37); `git status --short` shows
  modifications only under `agent-system/extensions/core/**` and
  `specs/890_backport_tooling_defect_fixes_into_core_source/**`; three task-number-pattern
  matches found in the scan (review.md, generate-task-order.sh, task-order-format.md) were all
  confirmed pre-existing via `git show` of the pre-task commit, none introduced by this
  back-port; `manifest.json` confirmed unchanged.

## Notes

This was a same-session, non-deferrable back-port: the source Hardware deploy tree at
`/home/benjamin/Projects/Logos/Hardware/.claude/` is git-ignored and disposable, and would be
lost on the next `<leader>al` redeploy if these fixes were not copied into source before that
happened. All six deliverables now live permanently in
`agent-system/extensions/core/`. No `.claude/**` deploy-tree file was touched. No PR/push
operations were performed (out of scope for this meta task; standard PR prohibition applies).
