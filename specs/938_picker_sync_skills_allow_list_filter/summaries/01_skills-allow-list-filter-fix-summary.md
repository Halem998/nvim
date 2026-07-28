# Implementation Summary: picker_sync_skills_allow_list_filter

**Task**: 938 - picker_sync_skills_allow_list_filter
**Status**: [COMPLETED]
**Started**: 2026-07-28T15:37:01Z
**Completed**: 2026-07-28T16:45:00Z
**Artifacts**:
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync_spec.lua`
  - `specs/938_picker_sync_skills_allow_list_filter/plans/01_skills-allow-list-filter-fix.md`
**Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  `.claude/rules/neovim-lua.md`, `.claude/rules/no-task-references-in-deliverables.md`

## Overview

The picker sync's allow-list post-filter looked up `allowed[file_info.name]` — a file **basename**
— against an allow-list built from `provides.<category>` strings in the core manifest. For
`skills`, those strings are **directory** names (`skill-orchestrate`, …), while every scanned
skill file's basename is the literal `"SKILL.md"`, so the filter matched nothing and every skill
was silently dropped from "Load Core" syncs. This implementation generalizes the filter to match
on the first path segment after the scanned `subdir` (with a basename fallback for any call site
whose path shape doesn't fit), adds a non-blocking zero-result wipeout detector, and adds a
permanent regression spec, then performs one deliberate redeploy to confirm the fix in the real
deploy path.

## What Changed

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` — `sync_scan`'s allow-list
  post-filter now anchors on the scanned `subdir` (escaped with `vim.pesc()`), extracting the first
  path segment after `subdir` and admitting the file when that segment is in the allow-list, with
  a basename fallback for call sites whose path shape doesn't match. This single rule replaces the
  former `filter_category == "context"` special case and now also correctly matches directory-shaped
  `skills` entries. Also added: a non-blocking zero-result wipeout detector (`helpers.notify(...,
  "WARN")`) that fires only when results existed but the filter admitted none.
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync_spec.lua` — new regression spec
  (5 cases): directory-shaped skills admitted, flat categories unchanged, context selection
  preserved, OpenCode `agent/subagents` divergence still passes, and an undeclared file is still
  excluded (allow-list is not a pass-through).

## Decisions

- Anchored the generalized match on the scanned `subdir` argument, not `filter_category` — they
  diverge at exactly one call site (OpenCode's `agents_subdir == "agent/subagents"`), and anchoring
  on `filter_category` there would have silently dropped every OpenCode agent, reproducing the
  exact defect class being fixed.
- Added a basename fallback for when the anchor match yields no path segment, so any future
  divergent call site degrades to the prior behavior instead of a silent total wipeout.
- Kept the wipeout detector strictly report-only (no mutation, no blocking) and scoped its trigger
  to a genuine total wipeout (`#results > 0 and #filtered == 0`) to avoid false positives on
  ordinary partial exclusions.

## Plan Deviations

- None (implementation followed the plan as written, phases 1-6, with one correction recorded
  inline in Phase 2 to the research's premise about `scripts/tests/*.sh`/`scripts/lint/*.sh` — see
  Verification below).

## Verification

- **Phase 1 (before-state)**: scratch-tree reproduction confirmed the hard-gate hypothesis
  exactly: `skills=0 commands=1 agents=1`.
- **Phase 2 (category survey)**: re-derived from current source — exactly 7 categories receive a
  non-nil `filter_category` (`commands`, `agents`, `skills`, `hooks`, `scripts`, `rules`,
  `context`); `skills` and `context` are directory-shaped; the rest are flat; exactly one call site
  has `subdir ~= filter_category` (OpenCode agents). All matched the plan's hypothesis.
  **Correction to the research's premise**: `scripts/tests/*.sh` and `scripts/lint/*.sh` are now
  declared in `provides.scripts` (as path-prefixed strings), not absent as the research assumed —
  but a live read-only scan confirmed they still fail to sync today via a *third*, distinct
  mismatch mechanism (full relative path vs. basename-only lookup) that this task's fix does not
  address. Recorded as a follow-up candidate, out of scope per the plan's Non-Goals.
- **Phase 3 (generalized filter)**: 3 scratch-tree harness cases pass (skills+flat-categories,
  context-unchanged, OpenCode-divergence); `scan_spec.lua` still passes 19/19; module loads
  headless; `git diff --stat` confirmed exactly one file modified.
- **Phase 4 (wipeout detector)**: 3 cases pass via a `helpers.notify` capture stub — normal (0
  warnings), partial exclusion (0 warnings), total wipeout (exactly 1 WARN naming the category and
  dropped count).
- **Phase 5 (regression spec)**: new `sync_spec.lua` passes 5/5. A deliberate revert of `sync.lua`
  to its pre-Phase-3 content made 2 of 5 cases fail exactly as expected (the two cases depending on
  the generalized match), confirming the spec genuinely guards the defect; the fix was restored and
  re-verified green.
- **Phase 6 (end-to-end + redeploy)**: after-state scratch counts flipped to `skills=2 commands=1
  agents=1`. Pre-redeploy `.claude/skills/` already contained all 23 `provides.skills` entries
  (the bug stopped refreshes rather than deleting existing files) with both orchestrator
  `SKILL.md` files already byte-identical to source. Performed ONE deliberate redeploy via
  `M.load_all_globally({ base_dir = ".claude" })` (the sanctioned "Load Core" path, invoked
  headlessly with `vim.fn.confirm` stubbed to select "Sync all" — `execute_sync` is a private,
  unexported closure, so `load_all_globally` is the only public entry point that performs the
  write). Redeploy synced 295 total artifacts. Post-redeploy: all 23 `provides.skills` entries
  present; both orchestrator `SKILL.md` diffs against source remained empty; zero warnings from
  the Phase 4 detector (the one WARN observed was the pre-existing, unrelated content-audit
  notification); `git status --short` scoped to `lua/` and `agent-system/` showed no unintended
  modification (`.claude/` is gitignored, so its 295 synced files are outside git tracking by
  design).
- Full gate: module loads headless, `scan_spec.lua` (19/19) and `sync_spec.lua` (5/5) both pass.

## Impacts

- Future "Load Core" syncs will once again propagate skill updates from
  `agent-system/extensions/core/skills/` into `.claude/skills/` — previously, edits to any core
  skill's `SKILL.md` would silently stop reaching deployed repos.
- A total allow-list wipeout in any category (not just skills) now surfaces a visible WARN instead
  of failing silently, shortening detection time for a future instance of this defect class.
- No behavior change for any category that was already working correctly (flat categories,
  `context`, OpenCode agents) — verified unchanged by the regression spec and the harness cases.

## Follow-ups

- `scripts/tests/*.sh` and `scripts/lint/*.sh`: declared in `provides.scripts` as path-prefixed
  strings but still excluded from sync by a third, distinct mismatch mechanism (full relative-path
  provides keys vs. basename-only lookup) that this fix does not address. Recorded as a follow-up
  candidate for a future task; out of scope here per the plan's Non-Goals.

## References

- `specs/938_picker_sync_skills_allow_list_filter/plans/01_skills-allow-list-filter-fix.md`
- `specs/938_picker_sync_skills_allow_list_filter/reports/01_skills-allow-list-post-filter-defect.md`
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua`
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua`
- `lua/neotex/plugins/ai/shared/extensions/config.lua`

## Notes

- Per the orchestration run's sequencing constraint, `agent-system/extensions/core/skills/
  skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md` were verified clean
  (`git status --porcelain`) both immediately before this run started and again immediately before
  the Phase 6 redeploy, confirming the redeploy ran against a stable orchestrator source tree.
