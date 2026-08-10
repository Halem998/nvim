# Implementation Summary: Task #975

- **Task**: 975 - Fix generated CLAUDE.md double-body and duplicate Stop-hook registration
- **Status**: [COMPLETED]
- **Started**: 2026-07-29T00:00:00Z
- **Completed**: 2026-07-29T01:35:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: 976 (completed; unrelated mutex-timing fix, no content overlap)
- **Artifacts**: plans/01_claudemd-hook-dedup-fix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed two independent deploy-machinery defects in the nvim extension loader. First,
`.claude/CLAUDE.md` acquired a second full copy of every loaded extension's fragment because
`reinject_loaded_extensions()` in `sync.lua` still drove the retired section-marker regime
(`inject_section()`) against a file `generate_claudemd()` now writes as a fully computed,
markerless artifact — fixed by regenerating the artifact once, after the extension loop, instead.
Second, `.claude/settings.json` carried `claude-stop-notify.sh` twice on `Stop` because
`deep_merge()`'s array dedup compared whole array items rather than being matcher-aware — fixed by
making `merge_settings()` self-normalizing for Claude Code hook-event arrays, with a matching
`unmerge_settings()` reversal path. Both fixes land entirely in `lua/neotex/plugins/ai/**` and
`agent-system/extensions/core/**`; no file under `.claude/**` was hand-authored.

## What Changed

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` — removed the per-extension
  `inject_section()` call for the config-markdown merge key inside `reinject_loaded_extensions()`;
  added a single unconditional `merge_mod.generate_claudemd(project_dir, config)` call after the
  extension loop (sibling to the existing conditional `generate_opencode_json()` call, generalizing
  its precedent to the markdown artifact); removed the now-dead `merge_key` local; corrected the
  module header comment and the function's docstring to describe the actual computed-artifact
  regime instead of the retired section-marker one.
- `agent-system/extensions/core/merge-sources/settings-hooks.json` — consolidated the `Stop`
  event's two separate `"*"`-matcher blocks into one, and `PostToolUse`'s two separate
  `Write|Edit`-matcher blocks into one, preserving the exact `(event, matcher, command)` triple set
  and first-appearance order.
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` — added `is_hook_event_array()` (shape
  predicate), `normalize_hook_event_array()` (matcher-grouping, idempotent), and
  `merge_hook_event_array()` (matcher-keyed merge with tracking); wired a gated fork into
  `deep_merge()`'s array branch so hook-event arrays route through matcher-aware merging while
  every other array shape (`permissions.allow`, `mcpServers`, etc.) falls through to the existing
  whole-item `vim.deep_equal` behavior unchanged; added the `hook_merged` branch to
  `unmerge_settings()`'s `remove_tracked()` to correctly reverse both whole-block appends and
  individual hook-entries merged into pre-existing matcher blocks, including the block-emptied
  cleanup semantics.
- `specs/975_fix_generated_claudemd_double_body/summaries/01_claudemd-hook-dedup-summary.md` —
  this summary (new).

## Decisions

- Did not restore `<!-- SECTION: id -->` markers to `generate_claudemd()` — the markerless
  computed-artifact model is a deliberate, already-completed migration confirmed by four
  independent code comments and the anchor commit that introduced it; `sync.lua`'s
  `reinject_loaded_extensions()` was the sole holdout.
- Scoped the matcher-aware merge narrowly via `is_hook_event_array()` (non-empty array, every item
  a table with both a `matcher` string key and an array-valued `hooks` key) so `permissions.*` and
  `mcpServers` are provably untouched — confirmed empirically in both the Phase 4 unit exercise and
  the Phase 6 full-redeploy regression guard.
- Phase 5's plan step calling for a real load/unload round trip of the `email` extension against
  `.claude/settings.json` was adapted: `email`'s actual settings merge target is
  `.claude/settings.local.json` (a live, personal, uncommitted file with many hand-added
  `permissions.allow` entries), not `.claude/settings.json`, and `email` was already loaded in this
  repo. Actually unloading it would have mutated the developer's live extension state. Instead,
  `merge_mod.merge_settings()`/`unmerge_settings()` were exercised directly against isolated
  scratchpad copies using the real `agent-system/extensions/email/settings-fragment.json` content,
  covering four scenarios (fresh block creation/removal; merge-into-existing-block with an
  unrelated hook preserved; the exact pre-fix 3-block `Stop` duplicate; legacy type-less tracked
  entries) — this exercises the identical code path without live-file mutation risk. See
  `progress/phase-5-progress.json`'s `deviations` array for the full record.
- Confirmed empirically, as instructed, rather than assuming: the plan's "Scope Hypothesis" that
  exactly `Stop` and `PostToolUse` have same-matcher splits in `settings-hooks.json` (via the `jq`
  group-by command specified in the plan) — no third event was found.
- Confirmed empirically the plan's other Scope Hypothesis: the loaded-extension set for this repo
  (from `.claude-extensions.json`) is `{core, email, memory, nix, nvim}` — 5 extensions, not the
  research report's 17-of-18-manifests-on-disk figure (which counts manifests declaring a
  `claudemd` merge target, not extensions actually loaded in this repo).
- Block-grouping normalization is expected to persist after `unmerge_settings()` and is not
  residue: it is semantically neutral (Claude Code runs every matching block regardless of split),
  idempotent, and reversing it would reintroduce the exact duplication hazard the fix closes. This
  is stated explicitly in a code comment on `normalize_hook_event_array()` and demonstrated in
  Phase 5's scenario 3 (the pre-fix 3-block `Stop` snapshot, merged then unmerged, retains its
  post-normalization single-block shape).

## Plan Deviations

- **Task 5.4** altered: round-trip round-trip verification for the `email` extension was exercised
  via direct `merge_mod` calls against scratchpad copies rather than a live load/unload of the
  extension, because its real settings target is `.claude/settings.local.json` (a personal,
  uncommitted file), not `.claude/settings.json` as the plan's phrasing implied. See "Decisions"
  above and `progress/phase-5-progress.json` for the full reasoning and evidence.

## Verification

- Build: N/A (Lua modules, no build step)
- Tests: N/A (no formal test suite for this module; verified via headless `nvim --headless -c
  "lua require(...)"` module-load checks and ad hoc headless Lua unit/round-trip exercises per
  phase, all passing — see `progress/phase-{2,4,5,6}-progress.json` for full command output)
- Files verified: Yes

**Verification-bar clauses, demonstrated against a real `deploy-headless.sh` cycle (Phase 6)**:

1. **Single-copy CLAUDE.md**: `grep -c "This file is generated automatically from loaded
   extensions" .claude/CLAUDE.md` → `1`. All 5 loaded extension fragments (`core`, `email`,
   `memory`, `nix`, `nvim`) confirmed present exactly once via their first heading line.
   `grep -c "<!-- SECTION:" .claude/CLAUDE.md` → `0`. File is 897 lines (both before and after the
   fix — the file self-heals per extension load/unload, so the meaningful evidence is the
   full-sync-cycle test, not the line count in isolation).
2. **Idempotency**: two consecutive `deploy-headless.sh` runs produced `.claude/CLAUDE.md` files
   confirmed byte-identical via `cmp`.
3. **Single Stop-hook registration**: `jq -r '.hooks.Stop[].hooks[].command' .claude/settings.json
   | grep -c claude-stop-notify.sh` → `1`. `.hooks.Stop` array has exactly 1 block, matcher `"*"`.
   `jq ... | sort | uniq -d` over all `(event, matcher, command)` triples in the whole file →
   empty (no duplicates anywhere, not just `Stop`).
4. **Regression guard**: `permissions` and `mcpServers` in the redeployed `.claude/settings.json`
   are semantically identical to the pre-redeploy baseline (`jq -S` sorted-key diff is empty; the
   only difference in a raw textual diff was object-key insertion order from JSON re-encoding, not
   content).
5. `bash .claude/scripts/verify-deploy.sh` → PASS, 12/12 checks, including the task-reference lint
   gate.

Empirical confirmation that the pre-fix defect was real at the start of this phase: the live
`.claude/settings.json` (last regenerated during Phase 2's redeploy, before the `merge.lua` fix
existed) had 4 `Stop` matcher blocks with `claude-stop-notify.sh` appearing 3 times — the fixed
redeploy in Phase 6 collapsed this to 1 block / 1 occurrence.

## Impacts

- Any future "Load Core"/"Sync all" cycle in this repo (or any other repo using this extension
  loader) no longer duplicates the config-markdown body, and self-heals any pre-existing
  hook-array duplication in `settings.json` on the next redeploy.
- The same fix automatically covers the structurally identical, previously-latent `OPENCODE.md`
  double-body risk for the `.opencode` deploy target, since `generate_claudemd()` is generic over
  `config.merge_target_key`.
- Any extension declaring a Claude Code hook-event array in its `settings-fragment.json` (matching
  the `{matcher, hooks}` shape) now merges by matcher instead of whole-item identity, closing the
  general class of risk the core manifest's own `_comment` on `merge_targets.settings` had
  previously flagged as unaddressed.

## Follow-ups

- The `section_id` field in every extension manifest's `merge_targets.claudemd` entry (e.g. core
  manifest.json's `"section_id": "core"`) is now fully vestigial — `generate_claudemd()` never
  reads it, and `inject_section()` is no longer called for the config-markdown key from anywhere in
  the tree. Removing the field is safe but was explicitly out of scope (a Non-Goal in the plan).
- Self-healing drifted hook *command paths* (a renamed hook script still appending alongside its
  stale registration) remains an unaddressed, pre-existing risk named in the core manifest's own
  `_comment` — not part of this task's scope.
- `strip_extension_sections()`/`preserve_sections()`/`restore_sections()` in `sync.lua` remain live
  (and now genuinely load-bearing only) for the `OPENCODE.md` path under `.opencode`; they were
  confirmed dead code for `.claude`'s CLAUDE.md case both before and after this fix, and were left
  untouched per the plan's Non-Goals.

## References

- Plan: `specs/975_fix_generated_claudemd_double_body/plans/01_claudemd-hook-dedup-fix.md`
- Research: `specs/975_fix_generated_claudemd_double_body/reports/01_claudemd-double-body-fix.md`
- Progress files: `specs/975_fix_generated_claudemd_double_body/progress/phase-{1,2,3,4,5,6}-progress.json`
