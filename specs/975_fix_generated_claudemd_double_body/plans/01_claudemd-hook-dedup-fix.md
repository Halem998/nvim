# Implementation Plan: Fix generated CLAUDE.md double-body and duplicate Stop-hook registration

- **Task**: 975 - Fix generated CLAUDE.md double-body and duplicate Stop-hook registration
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: 976 (completed; unrelated mutex-timing fix, no content overlap)
- **Research Inputs**: specs/975_fix_generated_claudemd_double_body/reports/01_claudemd-double-body-fix.md
- **Artifacts**: plans/01_claudemd-hook-dedup-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two independent deploy-machinery defects share one task. First, `.claude/CLAUDE.md` acquires a
second full copy of every loaded extension's fragment because `reinject_loaded_extensions()` in
`sync.lua` still drives the retired section-marker regime (`inject_section()`) against a file that
`generate_claudemd()` in `merge.lua` now writes as a fully computed, markerless artifact. Second,
`.claude/settings.json` carries `claude-stop-notify.sh` twice on `Stop`, because `deep_merge()`
dedups array items by whole-item `vim.deep_equal` and therefore never recognizes a separately
declared `{matcher, hooks}` block as already-present inside a differently-shaped existing block.
Both fixes land in `lua/neotex/plugins/ai/**` (the deploy machinery); `.claude/**` is a gitignored,
disposable deploy artifact and is never hand-authored — the settings duplicate is healed by making
the merge itself self-normalizing, not by editing the deployed file.

### Research Integration

Key findings carried forward from `reports/01_claudemd-double-body-fix.md`:

- **Do not restore section markers.** The markerless computed-artifact regime is a deliberate,
  already-completed migration: `generate_claudemd()`'s own docstring, `process_merge_targets()`,
  `reverse_merge_targets()`, and `verify_section_injection()` all four already assume no markers.
  `reinject_loaded_extensions()` is the sole holdout.
- **The fix mirrors an existing precedent in the same function**: `reinject_loaded_extensions()`
  already calls `merge_mod.generate_opencode_json(project_dir, config)` unconditionally after its
  extension loop for the JSON artifact. Adding the analogous `merge_mod.generate_claudemd(...)`
  call generalizes that precedent to the markdown doc, and fixes the latent, structurally identical
  `OPENCODE.md` risk for free (`generate_claudemd()` is generic over `config.merge_target_key`).
- **The CLAUDE.md defect is self-healing but recurring**: any individual extension load/unload
  overwrites the file cleanly, so a clean live file is not evidence the bug is absent. The only
  meaningful test is a "Load Core"/"Sync all" cycle, which `scripts/deploy-headless.sh` drives
  headlessly via the same `load_all_globally` entry point.
- **The settings defect is a one-way ratchet**: `merge_settings()` only ever adds, never regenerates,
  so the duplicate is permanent until something removes it. Confirmed live: `Stop` currently has 3
  matcher blocks and `claude-stop-notify.sh` appears twice; every other hook command across all 7
  event arrays appears exactly once.
- **Narrow gating is mandatory** for the matcher-aware merge: only `core` (6 event arrays) and
  `email` (1 `PreToolUse` array) contribute hook-shaped arrays. Every other extension fragment
  contributes `mcpServers` (an object) or `permissions` (flat string arrays), which must fall
  through to the existing whole-item behavior untouched.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation was requested for this task (`roadmap_path` not provided,
`roadmap_flag` not set).

## Goals & Non-Goals

**Goals**:
- `reinject_loaded_extensions()` stops calling `inject_section()` for the config-markdown merge key
  and instead regenerates the computed artifact once, after its loop.
- A "Load Core"/"Sync all" cycle produces a `.claude/CLAUDE.md` with exactly one copy of the core
  fragment and one copy per loaded extension fragment; two consecutive cycles are byte-identical.
- `merge_settings()` becomes matcher-aware for Claude Code hook-event arrays, so redeploying heals
  the existing `Stop` duplicate and cannot reintroduce that class of duplicate.
- `unmerge_settings()` correctly reverses the new merge shape (load -> unload leaves no residue).
- The stale doc comments in `sync.lua` that still describe the section-marker regime are corrected.

**Non-Goals**:
- Restoring `<!-- SECTION: id -->` markers to `generate_claudemd()` — explicitly rejected by research.
- Removing the now-vestigial `section_id` field from extension manifests' `merge_targets.claudemd`
  entries (safe but out of scope; flagged as a follow-up).
- Deleting `strip_extension_sections()` / `preserve_sections()` / `restore_sections()` from
  `sync.lua` — they remain live for `OPENCODE.md` under `.opencode` and are out of scope.
- Self-healing drifted hook *command paths* (a renamed hook script still appends alongside its stale
  registration) — a separate, pre-existing risk named in the core manifest's own `_comment`.
- Any hand-authored edit to files under `.claude/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Matcher-aware merge alters behavior for non-hook settings arrays (`permissions.allow`, `mcpServers`) | H | M | Gate on a strict shape predicate: apply only when the array is non-empty AND every item is a table carrying both a `matcher` key and an array-valued `hooks` key. Every other array shape falls through to the existing `vim.deep_equal` path unchanged. Verify by diffing `permissions` and `mcpServers` before/after redeploy. |
| `unmerge_settings()`'s `remove_tracked()` cannot reverse a hook entry now nested inside a pre-existing matcher block | H | H | Introduce an explicit `hook_merged` tracked type recording both whole blocks appended and individual hook entries injected into pre-existing blocks; add a matching `remove_tracked()` branch. Phase 5 exercises a real load -> unload -> load round trip. |
| Target-side normalization mutates blocks the extension system did not author | M | M | Normalization only groups same-`matcher` blocks and dedups identical hook entries — semantically neutral (Claude Code runs every matching block). Preserve first-appearance order of matchers and of entries within a matcher. Document explicitly that normalization is deliberately NOT reversed by unmerge. |
| Removing `inject_section()` from the sync path breaks a consumer relying on append behavior | M | L | Research found no such consumer: three of four call sites already assume the markerless model, and `.claude/`'s `root_file_names` is empty so CLAUDE.md never enters the file-copy pass. Phase 2's double-deploy test is the empirical check. |
| `deploy-headless.sh` overwrites the whole `.claude/` tree, obscuring what the fix changed | L | M | Capture `.claude/CLAUDE.md` and `.claude/settings.json` copies to the scratchpad before each deploy and diff explicitly, rather than inferring from the tree state. |
| Regression in the `.opencode` deploy target, which shares `generate_claudemd()` | M | L | The added call is unconditional and config-generic, matching the existing `generate_opencode_json()` precedent; confirm `config.merge_target_key` is read from config, never hardcoded. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4 | 1 (for 2), 3 (for 4) |
| 3 | 5 | 4 |
| 4 | 6 | 2, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Retire section injection from the sync re-inject path [COMPLETED]

**Goal**: `reinject_loaded_extensions()` agrees with the computed-artifact regime that
`generate_claudemd()`, `process_merge_targets()`, `reverse_merge_targets()`, and
`verify_section_injection()` already implement.

**Tasks**:
- [x] In `reinject_loaded_extensions()`, delete the "Re-inject config markdown section" block that
      resolves `ext_manifest.merge_targets[merge_key]`, reads the fragment via `read_file_string`,
      and calls `merge_mod.inject_section(target_path, section_content, mt_config.section_id)`.
      Leave the `settings` and `index` re-injection blocks in the same loop untouched. *(completed)*
- [x] After the extension loop closes — as a sibling of the existing
      `if config.merge_target_key == "opencode_md" then merge_mod.generate_opencode_json(...) end`
      guard, not inside it — add an unconditional `merge_mod.generate_claudemd(project_dir, config)`
      call. It must be unconditional and must read `config.merge_target_key` internally, so both the
      `.claude` and `.opencode` deploy targets are covered by the same call. *(completed)*
- [x] Check whether `merge_key` and any now-unused local remain referenced after the deletion;
      remove any local that has become dead. Do NOT remove `read_file_string` if other call sites
      in the file still use it. *(completed: merge_key removed; read_file_string retained, still
      used by read_json())*
- [x] Correct the module header comment block ("Section Preservation: ... merge targets for all
      loaded extensions are also re-injected as defense-in-depth") so it describes the actual regime:
      config markdown is a computed artifact regenerated by `generate_claudemd()`; section
      preservation applies only to the `.opencode` `OPENCODE.md` path. *(completed)*
- [x] Correct the `reinject_loaded_extensions()` docstring, which currently names `inject_section`
      among the idempotent merge operations it re-runs. *(completed)*
- [x] Reference durable anchors only (function names, file paths). Do not cite task numbers in any
      file outside `specs/**`. *(completed: verified via check-task-references.sh, 0 occurrences)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - remove the per-extension
  `inject_section()` call for the config-markdown merge key; add one post-loop
  `generate_claudemd()` call; correct two stale doc comments.

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.operations.sync')" -c "q"`
  exits 0 with no error output (module parses and loads).
- `grep -n "inject_section" lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
  returns no match.
- `grep -n "generate_claudemd" lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
  returns exactly one call site, positioned after the `for _, ext_name in ipairs(loaded_names)` loop
  ends.
- No task-number citation introduced: `bash .claude/scripts/check-task-references.sh` passes.

---

### Phase 2: Confirm CLAUDE.md single-copy and byte-identical idempotency [COMPLETED]

**Goal**: Empirically demonstrate the first two clauses of the verification bar against a real
"Load Core"/"Sync all" cycle, which is the only path that previously introduced the duplicate.

**Tasks**:
- [x] Copy the pre-deploy `.claude/CLAUDE.md` to the scratchpad as `claudemd-before.md` for
      reference. *(completed: 897 lines)*
- [x] Run `bash .claude/scripts/deploy-headless.sh` from the repository root. Confirm exit code 0
      and a reported artifact count. *(completed: exit 0, 304 artifacts deployed)*
- [x] Copy the resulting `.claude/CLAUDE.md` to the scratchpad as `claudemd-run1.md`. *(completed:
      897 lines)*
- [x] Run `bash .claude/scripts/deploy-headless.sh` a second time, with no intervening extension
      load or unload. Copy the result as `claudemd-run2.md`. *(completed: exit 0, 897 lines)*
- [x] `diff claudemd-run1.md claudemd-run2.md` — must report no differences (idempotency).
      *(completed: no diff, byte-identical)*
- [x] Sentinel check: `grep -c "This file is generated automatically from loaded extensions"
      .claude/CLAUDE.md` returns exactly `1`. *(completed: returned 1)*
- [x] Per-extension check: for each loaded extension declaring a `claudemd` merge target, grep the
      first heading line of its `merge-sources/claudemd.md` fragment against `.claude/CLAUDE.md` and
      confirm a count of exactly 1 for every one. Record the extension count actually observed.
      *(completed: 5 loaded extensions observed (core, email, memory, nix, nvim), from
      `.claude-extensions.json` keys; each fragment's first heading line appears exactly once)*
- [x] Marker check: `grep -c "<!-- SECTION:" .claude/CLAUDE.md` returns `0`. *(completed: returned
      0)*
- [x] If any check fails, stop and treat it as a Phase 1 defect — do not paper over it by editing
      `.claude/CLAUDE.md` directly. *(completed: no failure encountered)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: The report states 17 of 18 extension manifests declare a `claudemd` merge
target, but only the *loaded* subset contributes fragments to this repo's `.claude/CLAUDE.md`. The
per-extension check above must enumerate the loaded set at implementation time from
`.claude/extensions.json` (or the extension state file the loader actually reads) rather than
assuming 17; record the observed loaded count and confirm one fragment copy per loaded extension,
not per manifest on disk.

**Files to modify**:
- None (verification only). Scratchpad copies are working files, not deliverables.

**Verification**:
- `diff` between two consecutive deploy runs is empty.
- Sentinel core line count is 1; `<!-- SECTION:` count is 0.
- Every loaded extension's fragment appears exactly once.

---

### Phase 3: Consolidate same-matcher blocks in the core settings-hooks fragment [COMPLETED]

**Goal**: Reduce the number of distinct same-matcher blocks the matcher-aware merge must reconcile,
and remove the structural split that made the `Stop` duplicate possible in the first place.

**Tasks**:
- [x] Enumerate which hook events in
      `agent-system/extensions/core/merge-sources/settings-hooks.json` contain more than one block
      sharing an identical `matcher` value:
      `jq -r '.hooks | to_entries[] | "\(.key) \([.value[].matcher] | group_by(.) | map(select(length > 1)) | length)"'`.
      *(completed: confirmed exactly Stop and PostToolUse, matching the Scope Hypothesis)*
- [x] For each such event, merge the same-matcher blocks into a single
      `{"matcher": <value>, "hooks": [...]}` entry, concatenating the `hooks` arrays in their current
      first-appearance order. Do not reorder, rename, or drop any hook command. *(completed)*
- [x] Leave events whose blocks carry distinct matchers structurally unchanged. *(completed)*
- [x] Confirm the file still parses and that the total set of `(event, matcher, command)` triples is
      unchanged before and after — only the block grouping changes. *(completed: jq empty exits 0;
      sorted triple list byte-identical before/after)*

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Inspection at plan time found exactly two events with same-matcher splits —
`Stop` (two `*` blocks) and `PostToolUse` (two `Write|Edit` blocks) — out of six events in the file.
Confirm this with the `jq` group-by command above before editing rather than assuming it; if a third
event is found, consolidate it too and note the discrepancy.

**Files to modify**:
- `agent-system/extensions/core/merge-sources/settings-hooks.json` - consolidate same-matcher blocks
  per hook event.

**Verification**:
- `jq empty agent-system/extensions/core/merge-sources/settings-hooks.json` exits 0.
- The sorted list of `(event, matcher, command)` triples is byte-identical before and after:
  `jq -r '.hooks | to_entries[] | .key as $e | .value[] | .matcher as $m | .hooks[] | "\($e)\t\($m)\t\(.command)"' <file> | sort`
  produces the same output pre- and post-edit.
- No event contains two blocks with an identical `matcher` value.

---

### Phase 4: Matcher-aware, self-normalizing hook-array merge [COMPLETED]

**Goal**: `merge_settings()` recognizes Claude Code hook-event arrays, normalizes the target's
existing blocks, and merges incoming blocks by `matcher` — so a redeploy heals the existing
duplicate and cannot create a new one, while every non-hook array behaves exactly as before.

**Tasks**:
- [x] Add a local shape predicate to `merge.lua`, e.g. `is_hook_event_array(arr)`: returns true only
      when `arr` is a non-empty array AND every item is a table carrying both a `matcher` key and an
      array-valued `hooks` key. This predicate is the sole gate for all new behavior below.
      *(completed)*
- [x] Add a local `normalize_hook_event_array(arr)`: returns an array in which each distinct
      `matcher` value appears exactly once, with that matcher's `hooks` entries concatenated in
      first-appearance order and individually deduplicated by `vim.deep_equal` on the whole hook
      object (`{type, command}`). Match matchers by exact string equality — never by substring or
      pattern. Preserve first-appearance order of matchers. The function must be idempotent:
      normalizing an already-normalized array returns an equal array. *(completed)*
- [x] Add a local `merge_hook_event_array(target_arr, source_arr)`: for each source block, locate a
      target block with an equal `matcher`; if found, append each of the source block's hook entries
      not already `vim.deep_equal`-present in that block; if not found, append the whole source block.
      Return the tracking data described below. *(completed)*
- [x] In `deep_merge()`'s array branch, insert a gated fork: when `is_hook_event_array(value)` is
      true AND (`target[key]` is nil, empty, or itself satisfies `is_hook_event_array`), first
      normalize `target[key]` in place, then merge via `merge_hook_event_array`. In every other case
      fall through to the existing whole-item `vim.deep_equal` append loop, unmodified. Do not
      restructure or reindent the existing fall-through branch. *(completed)*
- [x] Define the new tracked shape: `tracked[key] = { type = "hook_merged", items = { <whole blocks
      appended> }, hook_items = { { matcher = <string>, hook = <hook object> }, ... } }`. `items`
      reuses the semantics of the existing `appended` type; `hook_items` is the new record for
      entries injected into a pre-existing matcher block. *(completed)*
- [x] Add a code comment at `normalize_hook_event_array` stating explicitly that normalization is
      deliberately NOT reversed by `unmerge_settings()`: it is semantically neutral (Claude Code runs
      every matching block), idempotent, and restoring the pre-normalization block split would
      reintroduce the duplication hazard it exists to close. *(completed)*
- [x] Keep 2-space indentation, ~100-character lines, `snake_case` locals, and LuaDoc `---` comment
      blocks on each new function, per the repository's Lua standards. *(completed)*

**Timing**: 1 hour 15 minutes

**Depends on**: 3

**Verification Tier**: interface

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - add `is_hook_event_array`,
  `normalize_hook_event_array`, `merge_hook_event_array`; add the gated fork inside `deep_merge`'s
  array branch; define the `hook_merged` tracked shape.

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.merge')" -c "q"` exits 0.
- Direct-dependent modules still load:
  `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.init')" -c "lua require('neotex.plugins.ai.claude.commands.picker.operations.sync')" -c "q"` exits 0.
- Headless unit exercise: call `merge_settings` against a scratchpad copy of the current
  `.claude/settings.json` using the core `settings-hooks.json` fragment, and assert (a)
  `claude-stop-notify.sh` appears exactly once in the resulting `Stop` array, (b) each hook event has
  at most one block per distinct matcher, (c) the `permissions` and `mcpServers` values are
  `vim.deep_equal` to their pre-merge values.
- Repeat the same call a second time against the merged result and assert the output is unchanged
  (merge idempotency at the function level, independent of the deploy path).

---

### Phase 5: Round-trip correctness for unmerge under the new tracked shape [COMPLETED]

**Goal**: Unloading an extension still removes exactly what its merge added, now that a merged hook
entry can live nested inside a pre-existing matcher block rather than as a top-level array item.

**Tasks**:
- [x] Add a `hook_merged` branch to `remove_tracked()` inside `unmerge_settings()`: first remove each
      entry in `items` from the array by `vim.deep_equal` (identical to the existing `appended`
      handling), then for each `hook_items` record locate the block whose `matcher` equals the
      recorded matcher and remove the `vim.deep_equal`-matching hook object from its `hooks` array.
      *(completed)*
- [x] If removing a hook entry leaves a block's `hooks` array empty, remove that block from the event
      array. If removing blocks leaves the event array empty, leave an empty array rather than
      deleting the key — matching the existing behavior for `appended`. *(completed)*
- [x] Confirm the existing `new_array`, `appended`, `merged`, `new_object`, and `new_value` branches
      are untouched, and that the legacy "old format or nested tracking" fall-through still runs for
      tracking data produced before this change (a repo may hold pre-existing tracked entries in its
      extension state file). *(completed)*
- [x] Exercise a real round trip headlessly with an extension that contributes a hook-shaped array —
      `email` is the only non-core one (`settings-fragment.json`, one `PreToolUse` block). Load it,
      capture `.claude/settings.json`, unload it, and confirm the file returns to its pre-load state
      modulo normalization (i.e. no residual `email` hook command remains, and no unrelated hook
      command was removed). *(deviation: altered — see progress/phase-5-progress.json deviations;
      exercised via merge_mod.merge_settings()/unmerge_settings() against isolated scratchpad
      copies of the real email/settings-fragment.json content rather than loading/unloading the
      live email extension, because its actual target is .claude/settings.local.json, a live
      personal file with hand-added permissions, not .claude/settings.json)*
- [x] Record explicitly in the summary that block-grouping normalization is expected to persist after
      unload and is not residue. *(completed)*

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - add the `hook_merged` branch to
  `remove_tracked()` within `unmerge_settings()`.

**Verification**:
- Module loads headlessly with no error.
- Load -> unload round trip for the `email` extension leaves no `email`-contributed hook command in
  `.claude/settings.json`, and leaves every core hook command intact.
- Load -> unload -> load returns `.claude/settings.json` to the same state as a single load
  (`vim.deep_equal` on the decoded `hooks` object).
- Pre-existing tracked entries lacking a `type` field still route through the legacy fall-through
  without error.

---

### Phase 6: Full redeploy and verification-bar sign-off [NOT STARTED]

**Goal**: Demonstrate all three clauses of the stated verification bar simultaneously against a clean
redeploy, and record the outcome.

**Tasks**:
- [ ] Copy the current `.claude/settings.json` and `.claude/CLAUDE.md` to the scratchpad as the
      pre-redeploy baseline.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` from the repository root; confirm exit 0.
- [ ] Clause 1: `grep -c "This file is generated automatically from loaded extensions"
      .claude/CLAUDE.md` returns `1`; every loaded extension fragment appears exactly once;
      `grep -c "<!-- SECTION:" .claude/CLAUDE.md` returns `0`.
- [ ] Clause 2: run the deploy a second time and confirm the two resulting `.claude/CLAUDE.md` files
      are byte-identical (`cmp` reports no difference).
- [ ] Clause 3: `jq -r '.hooks.Stop[].hooks[].command' .claude/settings.json | grep -c
      "claude-stop-notify.sh"` returns `1`; the `Stop` array has exactly one `*` matcher block; and
      no `(event, matcher, command)` triple in the whole file appears more than once
      (`jq -r '.hooks | to_entries[] | .key as $e | .value[] | .matcher as $m | .hooks[] |
      "\($e)\t\($m)\t\(.command)"' .claude/settings.json | sort | uniq -d` is empty).
- [ ] Regression guard: `permissions` and `mcpServers` in the redeployed `.claude/settings.json` are
      unchanged versus the pre-redeploy baseline.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and confirm it passes, including its
      task-reference lint gate.
- [ ] Write the implementation summary to
      `specs/975_fix_generated_claudemd_double_body/summaries/01_claudemd-hook-dedup-summary.md`,
      recording the observed loaded-extension count, the CLAUDE.md line count before and after, and
      the three clause results with their actual command output.

**Timing**: 45 minutes

**Depends on**: 2, 5

**Verification Tier**: full

**Files to modify**:
- `specs/975_fix_generated_claudemd_double_body/summaries/01_claudemd-hook-dedup-summary.md` - new
  implementation summary.

**Verification**:
- All three verification-bar clauses pass with recorded command output.
- `verify-deploy.sh` exits 0.
- `permissions` / `mcpServers` diff is empty.

---

## Testing & Validation

- [ ] `sync.lua` and `merge.lua` both load headlessly with no error, as do their direct dependents
      (`extensions/init.lua`, the picker sync operation module).
- [ ] Two consecutive `deploy-headless.sh` runs produce byte-identical `.claude/CLAUDE.md`.
- [ ] Sentinel core line appears exactly once in `.claude/CLAUDE.md`; no `<!-- SECTION:` markers remain.
- [ ] Each loaded extension's `claudemd` fragment appears exactly once.
- [ ] `claude-stop-notify.sh` is registered exactly once on `Stop` after redeploy.
- [ ] No `(event, matcher, command)` triple is duplicated anywhere in `.claude/settings.json`.
- [ ] `permissions` and `mcpServers` are unaffected by the matcher-aware merge.
- [ ] Extension load -> unload round trip removes exactly what it added.
- [ ] `check-task-references.sh` and `verify-deploy.sh` pass.

## Artifacts & Outputs

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (modified)
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` (modified)
- `agent-system/extensions/core/merge-sources/settings-hooks.json` (modified)
- `specs/975_fix_generated_claudemd_double_body/plans/01_claudemd-hook-dedup-fix.md` (this file)
- `specs/975_fix_generated_claudemd_double_body/summaries/01_claudemd-hook-dedup-summary.md`
- Regenerated deploy artifacts `.claude/CLAUDE.md` and `.claude/settings.json` (gitignored,
  untracked; produced by redeploy, never hand-authored)

## Rollback/Contingency

`.claude/` is gitignored and untracked, so nothing under it needs reverting through git — a
`deploy-headless.sh` run from the reverted source store restores it. Only three tracked files change:

- **Phase 1 regression** (CLAUDE.md still duplicated or now missing content): revert
  `sync.lua` with `git checkout HEAD -- lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
  and redeploy. The prior behavior is a self-healing single duplicate, not data loss.
- **Phase 4/5 regression** (settings merge damages `permissions`, `mcpServers`, or a hook array):
  revert `merge.lua` with `git checkout HEAD -- lua/neotex/plugins/ai/shared/extensions/merge.lua`,
  then restore `.claude/settings.json` from the scratchpad baseline captured at the start of Phase 6
  and redeploy. Because `merge_settings()` is add-only under the reverted code, a restored baseline
  plus redeploy is sufficient.
- **Phase 3 regression**: revert `agent-system/extensions/core/merge-sources/settings-hooks.json`;
  it is pure data with no consumers beyond the merge path.
- If the working tree is dirty when a rollback is needed, run
  `bash .claude/scripts/git-snapshot.sh 975` first, per the destructive-git rule.

The two halves of this task are independent: Phases 1-2 can ship without Phases 3-6, and vice versa.
Reverting one half does not require reverting the other.
