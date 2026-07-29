# Research Report: Task #975

**Task**: 975 - Fix generated CLAUDE.md double-body and duplicate Stop-hook registration
**Started**: 2026-07-29T22:10:29Z
**Completed**: 2026-07-29T22:55:00Z
**Effort**: small (~10-30 line Lua fix + one-time regeneration + settings normalization)
**Dependencies**: 976 (completed; unrelated mutex-timing fix, no content overlap)
**Sources/Inputs**:
- Codebase: `lua/neotex/plugins/ai/shared/extensions/{merge,init,verify,config}.lua`,
  `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`,
  `agent-system/extensions/core/manifest.json`,
  `agent-system/extensions/core/{root-files/settings.json,merge-sources/settings-hooks.json}`
- Git history: `bbed96afe` (task-anchor: "computed CLAUDE.md generation" commit)
- Live artifacts: `.claude/CLAUDE.md`, `.claude/settings.json`
- `specs/reviews/review-2026-07-29-agent-system.md`
**Artifacts**:
- This report: `specs/975_fix_generated_claudemd_double_body/reports/01_claudemd-double-body-fix.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **CLAUDE.md double-body root cause confirmed**: `generate_claudemd()` (the canonical, correct
  "Engine A" mechanism, invoked from `init.lua`'s per-extension load/unload paths) fully computes
  CLAUDE.md from scratch on every call and deliberately writes **no** section markers — this was
  an intentional architectural change (anchor commit `bbed96afe`, "computed CLAUDE.md
  generation"). The stray second copy is injected by `reinject_loaded_extensions()` in
  `sync.lua` (the "Load Core"/"Sync all" picker path, "Engine B"), which still calls
  `merge_mod.inject_section()` for the `claudemd` merge key for every loaded extension. Since
  `generate_claudemd()` never wrote a `<!-- SECTION: id -->` marker, `inject_section()`'s
  idempotency check always misses and it **appends** a fresh, marker-wrapped copy of every loaded
  extension's fragment.
- **The fix should NOT restore markers.** Restoring markers would reverse a deliberate,
  documented, and already-partially-adopted simplification (the `opencode.json` analog already
  uses the pure-computed-artifact model with zero issues) and would require reintroducing
  section-tracking bookkeeping that was removed on purpose. The correct fix is the other option
  named in the task: make `reinject_loaded_extensions()` stop calling `inject_section()` for the
  config-markdown merge key, and instead call `merge_mod.generate_claudemd(project_dir, config)`
  once (outside the per-extension loop), exactly mirroring the existing
  `merge_mod.generate_opencode_json(project_dir, config)` call already present in the same
  function for the `opencode_md` case. This is a small, surgical change confined to
  `sync.lua`, and it fixes the parallel (currently latent) OPENCODE.md double-body risk for free,
  since `generate_claudemd()` is generic over `config.merge_target_key`.
- **The bug is intermittent, not permanently visible** — this explains why the live
  `.claude/CLAUDE.md` in this repo is currently a clean 897 lines (single copy) despite the
  review's 1801-line snapshot: `generate_claudemd()` performs a full deterministic overwrite on
  every extension load/unload, which silently "heals" a prior duplication until the next "Load
  Core"/"Sync all" run reintroduces it. `.claude/settings.json`'s duplicate `claude-stop-notify.sh`
  registration is NOT self-healing — it is a one-way ratchet, because the settings-merge path
  only ever appends, never regenerates from scratch.
- **The settings.json duplicate-Stop-hook root cause is independently confirmed and explained by
  the core manifest's own `_comment`** on `merge_targets.settings` (`manifest.json` line 18):
  `deep_merge`'s array dedup operates on **whole-array-item** `vim.deep_equal`, not
  matcher-aware merging. `merge-sources/settings-hooks.json` declares `claude-stop-notify.sh` as
  its own separate `{matcher: "*", hooks: [...]}` block, structurally different from whatever
  bundle already exists in the target's `Stop` array (from the one-time `root-files/settings.json`
  install seed, which already bundles `claude-stop-notify.sh` alongside `post-command.sh` and
  `memory-nudge.sh` in a single matcher block). Because the two blocks are not byte-identical,
  `deep_merge` treats them as distinct and appends rather than merging/deduping.
- **Scope confirmation**: every loaded extension's `manifest.json` declares a `claudemd` merge
  target (17 of 18 extension manifests found), so the magnitude of the CLAUDE.md duplication
  scales with the number of loaded extensions, not just core.

## Context & Scope

Scope per the task's binding source-store rule: fix in `lua/neotex/plugins/ai/**` (the deploy
machinery), not `.claude/**` (the disposable deploy artifact). This research traced both named
defects to their exact root causes, confirmed the currently-live design intent via git history
and code comments, and evaluated the task's suggested "restore markers" option against the
alternative ("stop calling inject_section") using the actual codebase evidence.

## Findings

### Codebase Patterns

**Two independent CLAUDE.md-writing code paths ("Engine A" vs "Engine B")**

| Engine | Location | Trigger | Behavior |
|--------|----------|---------|----------|
| A (canonical, correct) | `init.lua` lines 559-566 (load) and 740-747 (unload) | Individual extension load/unload via the picker or `manager.load`/`manager.unload` | Calls `merge_mod.generate_claudemd(project_dir, config)` — full deterministic overwrite, header + ordered fragments, **no markers written**. |
| B (stray, incorrect) | `sync.lua` `reinject_loaded_extensions()` lines 220-294, called from `load_all_globally()` line 1419 ("Load Core"/"Sync all") | Full picker sync | Loops over every loaded extension and calls `merge_mod.inject_section(target_path, section_content, mt_config.section_id)` for the `claudemd` merge key (lines 247-257) — append-if-marker-absent, update-if-present. |

`merge.lua`'s `inject_section()` (lines 107-143) is the section-marker primitive: it searches for
`<!-- SECTION: {id} -->`, updates in place if found, else **appends** a new marked block. Because
Engine A never writes that marker, every "Load Core"/"Sync all" run that follows an Engine-A
regeneration finds no marker and appends. A *second* consecutive "Sync all" run (with no
intervening extension load/unload) becomes idempotent, because the marker written by the *first*
stray append is now present — this is why the defect manifests as exactly one duplicate, not N
duplicates, and why it "self-heals" back to a single copy the next time any extension is
individually loaded or unloaded (Engine A's full overwrite discards the marker-wrapped block
Engine B appended).

**Design intent is unambiguous and already fully committed to the computed-artifact model.**

- `merge.lua:540-542` (docstring on `generate_claudemd`): *"This replaces the section-injection
  approach: the generated file has no section markers and is fully deterministic given the set
  of loaded extensions."*
- `init.lua:82-88` (`process_merge_targets`): *"Config markdown (CLAUDE.md or OPENCODE.md) is now
  a computed artifact. Section injection is skipped here; generate_claudemd() regenerates the
  file from all loaded extensions after each load/unload operation."*
- `init.lua:142-144` (`reverse_merge_targets`): *"Config markdown section removal is skipped:
  CLAUDE.md is now a computed artifact. generate_claudemd() is called after state is updated
  (extension removed from state) so regeneration naturally excludes the unloaded extension's
  content."*
- `verify.lua:187-189` (`verify_section_injection`): *"CLAUDE.md is a computed artifact
  (generated by generate_claudemd), so we check for the presence of the extension's source
  fragment content rather than section markers."*
- Git anchor: the commit that introduced `generate_claudemd()` is titled "computed CLAUDE.md
  generation" and its diff shows `init.lua`'s `process_merge_targets`/`reverse_merge_targets`
  functions being edited in the same change to remove their prior section-injection calls for
  the config-markdown key — i.e., the marker regime was deliberately retired from Engine A at
  the same time the computed-artifact model was introduced, not left as an oversight.

Four call sites (`init.lua` load, `init.lua` unload, `verify.lua`) already agree with each other
on the no-markers, fully-computed model. `sync.lua`'s `reinject_loaded_extensions()` is the
single outlier that was never updated to match. This directly answers the task's "prefer
restoring markers unless research shows otherwise" hint: **research shows otherwise** — markers
were a retired design, and three of four consuming sites already correctly assume they are gone.
Reintroducing them would mean re-adding tracked-section bookkeeping to `process_merge_targets`/
`reverse_merge_targets` (removed on purpose) and would leave `sync.lua`'s
`strip_extension_sections`/`preserve_sections`/`restore_sections` helpers doing real work again
for CLAUDE.md, when today (see below) they are dead code for the `.claude` case.

**`OPENCODE.md` is generated by the exact same `generate_claudemd()` function** (it is
parameterized by `config.merge_target_key`, which is `"claudemd"` for `.claude` and
`"opencode_md"` for `.opencode`; see `config.lua` lines 47-48, 67, 84). This means the fix
proposed below — replacing the per-extension `inject_section()` loop in
`reinject_loaded_extensions()` with a single post-loop `merge_mod.generate_claudemd(project_dir,
config)` call — automatically also fixes the latent, structurally-identical OPENCODE.md
double-body risk for the `.opencode` deploy target, at no extra cost. (The
`opencode_md` case already has exactly this pattern for `opencode.json`, a separate JSON
artifact: `sync.lua` lines 291-293 call `merge_mod.generate_opencode_json(project_dir, config)`
unconditionally after the loop when `config.merge_target_key == "opencode_md"` — the recommended
fix generalizes this same precedent to the markdown doc.)

**`strip_extension_sections()`/`preserve_sections()`/`restore_sections()` in `sync.lua` (lines
40-182) are dead code for the `.claude` CLAUDE.md case today**, independent of this bug. They
only run inside `sync_files()` against files present in `all_artifacts.root_files`, and
`M.scan_all_artifacts()` (lines 1141-1152) sets `root_file_names = {}` for `base_dir == ".claude"`
— i.e., CLAUDE.md itself is never included in the file-copy pass for `.claude` (a comment at
lines 1141-1146 confirms: *"For .claude: all root files ... are now managed by the extension
loader (root_files provides + generate_claudemd), not synced"*). These marker-preserving helpers
remain live only for `OPENCODE.md` under `.opencode`, where they run harmlessly redundant with
(and immediately overwritten by) the recommended `generate_claudemd()` fix, since that
regeneration happens after `sync_files()` in the same `load_all_globally()` call.

**settings.json duplicate Stop-hook — mechanism confirmed via three converging sources:**

1. **Live evidence**: `.claude/settings.json`'s `Stop` array currently has 3 matcher blocks: (a)
   `{post-command.sh, claude-stop-notify.sh, memory-nudge.sh}`, (b) `{claude-stop-notify.sh}`
   alone, (c) `{events-log-lifecycle.sh}` alone — `claude-stop-notify.sh` appears twice
   (`grep -c` = 2).
2. **Source of block (a)**: `agent-system/extensions/core/root-files/settings.json` (the
   one-time install seed, copied only when the target file does not already exist — see
   `sync.lua`'s root-file `action` logic, lines 1169-1180) bundles all four hooks
   (`post-command.sh`, `claude-stop-notify.sh`, `memory-nudge.sh`, `events-log-lifecycle.sh`) in
   a *single* `Stop` matcher block today. This repo's deployed file predates that consolidation
   (its block (a) has only 3 of the 4), consistent with having been seeded from an earlier
   version of the template and then drifted via re-applied merges.
3. **Source of blocks (b) and (c)**: `agent-system/extensions/core/merge-sources/settings-hooks.json`
   (the always-reapplied fragment, merged via `merge_targets.settings` on every extension
   load/sync) declares `claude-stop-notify.sh` and `events-log-lifecycle.sh` as **two separate**
   `{matcher: "*", hooks: [...]}` blocks in its own `Stop` array (lines 19-32), rather than one
   consolidated block. `merge.lua`'s `deep_merge()` (lines 172-222) merges array values by
   iterating source items and inserting only those that are not `vim.deep_equal` to any existing
   target item — comparison is **whole-item**, not matcher-keyed. Because the target's existing
   `Stop[0]` (block a) is a different table shape than the fragment's `Stop[0]`/`Stop[1]` (each a
   single-hook block), no equality match is found, and both fragment items get appended as new,
   independent matcher blocks. This exactly matches the hazard the core manifest's own
   `_comment` on `merge_targets.settings` predicts verbatim: *"deep_merge appends array entries
   per-matcher rather than merging into an existing '*' matcher, so a target repo with a
   pre-existing '*' entry for Stop/UserPromptSubmit will end up with two array entries for that
   matcher after merge -- safe ... but untidy."*
4. **Why dedup did not prevent this**: `deep_merge`'s dedup (`vim.deep_equal` on whole array
   items) only catches literal re-application of the *identical* array item (e.g., running the
   same merge twice back-to-back is idempotent). It has no concept of "this hook command already
   exists somewhere in a *different* matcher block" or "these two matcher blocks share the same
   `matcher` value and should be unioned." This is a structural gap, not a bug in the dedup
   check's correctness for what it does check.
5. **Asymmetry with CLAUDE.md**: unlike CLAUDE.md (which self-heals via full overwrite on every
   extension load/unload), `merge_settings()`/`deep_merge()` only ever adds keys/array items to
   the existing `settings.json` — there is no regeneration-from-scratch path — so once a
   duplicate hook registration lands, it is permanent until manually removed. The manifest
   `_comment` already flags this as a known, unfixed risk ("deep_merge also does not self-heal
   drifted command paths ... follow-up risk, not fixed by this mechanism").

### External Resources

Not applicable — this is a pure codebase-internal defect; no external documentation consulted.

### Recommendations

**Fix 1 — CLAUDE.md double-body (in `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`)**

In `reinject_loaded_extensions()` (lines 220-294):
- Remove the per-extension "Re-inject config markdown section" block (lines 247-257), which
  currently calls `merge_mod.inject_section(target_path, section_content, mt_config.section_id)`
  for the `merge_key` (`claudemd`/`opencode_md`) merge target inside the loop.
- Add a single, unconditional call after the extension loop completes (alongside, not
  replacing, the existing conditional `generate_opencode_json` call at lines 291-293):
  `merge_mod.generate_claudemd(project_dir, config)`. This mirrors the already-correct pattern
  Engine A uses in `init.lua`, and mirrors the existing `generate_opencode_json` precedent
  already present in this same function for the JSON artifact.
- No changes needed to `merge.lua`'s `generate_claudemd()` itself — it is already correct and
  config-generic.
- Optional follow-up cleanup (not required for the verification bar, flagged for a future task):
  the `section_id` field in every extension manifest's `merge_targets.claudemd` entry (e.g. core
  manifest.json line 11, `"section_id": "core"`) becomes fully vestigial once this fix lands —
  `generate_claudemd()` never reads it, and after this fix `inject_section()` will no longer be
  called for the config-markdown key from anywhere in the tree. Removing the field is safe but
  out of scope for this task's minimal fix.

**Fix 2 — regenerate the currently-deployed `.claude/CLAUDE.md`**

Per the "self-healing" mechanism above, the live file may already be single-copy at the moment
the fix lands (as observed during this research — the currently deployed file is a clean 897
lines with mtime matching a recent load). The verification bar's actual test is the "Load
Core"/"Sync all" cycle exercising the fixed `reinject_loaded_extensions()`, since that is the
path that previously introduced the duplicate. The implementer should run a full
unload-all/load-all cycle (or equivalent programmatic invocation of the fixed
`load_all_globally()`) twice in a row after the code fix, and diff the two resulting
`.claude/CLAUDE.md` files to confirm byte-identical idempotency, per the stated verification bar.

**Fix 3 — settings.json duplicate Stop-hook + dedup mechanism (in `lua/neotex/plugins/ai/shared/extensions/merge.lua`)**

Two parts:

1. **One-time cleanup of the currently-deployed `.claude/settings.json`**: collapse the three
   `Stop` matcher blocks currently present into the single canonical block already declared in
   `agent-system/extensions/core/root-files/settings.json` (all four hooks in one `{matcher:
   "*", hooks: [...]}` entry, in a stable order), removing the two stray single-hook blocks.
2. **Make `deep_merge` (or a targeted wrapper around it used by `merge_settings`) matcher-aware
   for hook-shaped arrays**, so future merges of `merge-sources/settings-hooks.json` (or any
   other extension's `settings-fragment.json`) cannot reintroduce the same class of duplicate.
   Concretely: when merging an array whose existing items are shaped like `{matcher: <string>,
   hooks: [...]}` (i.e., a Claude Code hook-event array such as `Stop`, `PreToolUse`,
   `UserPromptSubmit`, etc.), group by `matcher` instead of doing whole-item equality — if a
   target item with the same `matcher` value exists, merge the incoming item's `hooks`
   sub-array into it, deduping individual hook entries (e.g., by `command` string, or by
   `vim.deep_equal` on the whole `{type, command}` object) rather than by whole-block identity.
   This directly closes the gap the manifest's own `_comment` names as unfixed, and is a
   contained change local to `deep_merge`/`merge_settings` in `merge.lua` (the single place
   both Engine A's `process_merge_targets` and Engine B's `reinject_loaded_extensions` route
   settings merges through, so the fix applies uniformly regardless of which engine triggers
   it).
3. Also fix `merge-sources/settings-hooks.json`'s own `Stop` array (lines 19-32) to declare
   `claude-stop-notify.sh` and `events-log-lifecycle.sh` in one consolidated matcher block
   rather than two — this reduces the number of distinct matcher blocks the smarter merge in
   (2) has to reconcile, and is good hygiene independent of the merge-logic fix.

Verification for Fix 3: after redeploy, `grep -c "claude-stop-notify.sh" .claude/settings.json`
returns 1 (one `command` string, appearing once); confirm the `Stop` array structurally has one
`"*"` matcher block containing all four hook commands.

## Decisions

- **Do not restore section markers to `generate_claudemd()`.** The task's own hint text allowed
  for this outcome contingent on research; the evidence (a deliberate, previously-completed,
  multi-site architectural migration away from markers, confirmed by git history and four
  independent code comments) points unambiguously the other way.
- **Fix belongs entirely in `sync.lua`'s `reinject_loaded_extensions()`**, not in `merge.lua`'s
  `generate_claudemd()` (which needs no change) — this keeps the fix minimal and consistent with
  the review's own "~10-line fix" estimate for the CLAUDE.md half of the task.
- **The settings.json dedup fix targets `deep_merge` in `merge.lua`**, since that is the single
  shared merge primitive used by both engines' settings-merge paths; a fix scoped only to
  `settings-hooks.json`'s content (reshaping its `Stop` array) would reduce but not eliminate the
  general class of risk the manifest's `_comment` already flags as unaddressed by structure
  alone.

## Risks & Mitigations

- **Risk**: a matcher-aware merge change to `deep_merge` could alter behavior for other
  non-hook-shaped settings arrays (e.g., `permissions.allow`, which is a flat string array, not
  an array of `{matcher, hooks}` objects). **Mitigation**: gate the new matcher-merge behavior
  narrowly — only apply it when array items are tables containing both a `matcher` key and a
  `hooks` key (the specific shape Claude Code's hook-event arrays use); fall through to the
  existing whole-item `vim.deep_equal` behavior for every other array shape, so `permissions.*`,
  `mcpServers`, etc. are untouched.
- **Risk**: removing the `inject_section()` call from `reinject_loaded_extensions()` could break
  something relying on the old append-based behavior for CLAUDE.md. **Mitigation**: none found —
  three of four consuming call sites (`init.lua` x2, `verify.lua`) already assume the
  no-markers, fully-computed model; `sync.lua` was the sole holdout, and its own doc comment
  block (lines 6-9) describing "defense-in-depth" re-injection is itself the stale artifact
  needing correction (it still describes the pre-task-465 model).
- **Risk**: `unmerge_settings()` (the reverse of `merge_settings`, used when unloading an
  extension) currently tracks removal by `type` (`new_array`/`appended`/etc.) per the existing
  `deep_merge` tracked-entries shape. A matcher-aware merge changes what "tracked" means for
  hook arrays (a merged-in hook is now nested inside an existing matcher block's `hooks`
  sub-array, not a top-level new array item). **Mitigation**: the implementer should verify
  `unmerge_settings()`'s `remove_tracked()` recursion (lines 271-302) still correctly reverses a
  matcher-merged hook entry — this needs either a corresponding tracked-shape update or an
  explicit test exercising unload after the new merge behavior.

## Context Extension Recommendations

- **Topic**: computed-artifact merge-target model (CLAUDE.md/OPENCODE.md/opencode.json)
- **Gap**: no context file documents that `claudemd`/`opencode_md` merge targets are
  *computed artifacts* regenerated wholesale by `generate_claudemd()`/`generate_opencode_json()`
  rather than incrementally section-injected — this is currently only discoverable by reading
  `merge.lua`/`init.lua` docstrings and one archived commit. A short note in
  `.claude/context/architecture/` (or wherever extension-system architecture is documented)
  would have made this task's "which regime is correct" question answerable without full-file
  archaeology.
- **Recommendation**: add a short subsection to the extension-system architecture context
  documenting the three merge-target kinds (computed-artifact: `claudemd`/`opencode_md`/
  `opencode.json`; incremental-append: `settings`/`index`) and their respective idempotency
  properties, so future defects in this area are diagnosable without re-deriving the design
  history from git log.

## Appendix

### Search queries / investigation steps used
- `grep -n "generate_claudemd\|inject_section\|SECTION:\|function M\." merge.lua`
- `grep -rn "generate_claudemd\|reinject_loaded_extensions"` across
  `lua/neotex/plugins/ai/`
- `git log --oneline --follow -- init.lua` -> found anchor commit `bbed96afe` ("computed CLAUDE.md
  generation")
- `git show bbed96afe` (diff review of the commit that introduced `generate_claudemd()` and
  removed section-injection calls from `init.lua`)
- Read `sync.lua` in full (1647 lines) — traced `reinject_loaded_extensions`,
  `strip_extension_sections`/`preserve_sections`/`restore_sections`, `scan_all_artifacts`
  (`root_file_names` empty for `.claude`), `execute_sync`, `load_all_globally`.
- Read `merge.lua` `inject_section`/`remove_section`/`deep_merge`/`merge_settings`/
  `generate_claudemd` (lines 91-660).
- Read `init.lua` `process_merge_targets`/`reverse_merge_targets`/load path
  (lines 67-160, 520-580, 720-757).
- Read `verify.lua` `verify_section_injection` docstring (lines 187-214).
- Inspected live `.claude/CLAUDE.md` (897 lines, single copy at research time — confirms
  self-healing theory) and `.claude/settings.json` (`Stop` array, 3 matcher blocks, 2x
  `claude-stop-notify.sh`).
- Inspected `agent-system/extensions/core/manifest.json` (`merge_targets.claudemd.section_id`,
  `merge_targets.settings._comment`), `root-files/settings.json` (install-seed `Stop` block, 4
  hooks bundled), `merge-sources/settings-hooks.json` (always-reapplied fragment, `Stop` array
  split into 2 separate matcher blocks).
- Confirmed `config.lua` `merge_target_key` values (`"claudemd"` for `.claude`, `"opencode_md"`
  for `.opencode`) to establish that `generate_claudemd()` is shared/generic across both deploy
  targets.
- `grep -rl "claudemd" agent-system/extensions/*/manifest.json` — 17 of 18 extension manifests
  declare a `claudemd` merge target, confirming duplication scales with loaded-extension count.

### File:line references (durable anchors, no task-number citations)
- `lua/neotex/plugins/ai/shared/extensions/merge.lua`: `generate_claudemd()` lines 549-660,
  `inject_section()` lines 107-143, `deep_merge()` lines 172-222, `merge_settings()` lines
  229-257.
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`:
  `reinject_loaded_extensions()` lines 220-294, `strip_extension_sections()`/`preserve_sections()`/
  `restore_sections()` lines 40-182, `scan_all_artifacts()` root_file_names branch lines
  1141-1152, `load_all_globally()` lines 1208-1432.
- `lua/neotex/plugins/ai/shared/extensions/init.lua`: `process_merge_targets()` lines 67-128,
  `reverse_merge_targets()` lines 130-165, load-path `generate_claudemd()` call lines 559-566,
  unload-path call lines 740-747.
- `lua/neotex/plugins/ai/shared/extensions/verify.lua`: `verify_section_injection()` lines
  187-214.
- `agent-system/extensions/core/manifest.json`: `merge_targets.claudemd` lines 8-12,
  `merge_targets.settings` (with `_comment`) lines 17-21.
- `agent-system/extensions/core/root-files/settings.json`: `Stop` install-seed block lines
  114-136.
- `agent-system/extensions/core/merge-sources/settings-hooks.json`: `Stop` fragment lines 19-32.
