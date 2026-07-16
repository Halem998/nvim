# Implementation Plan: Task #888

- **Task**: 888 - Harden extension discovery against stray directories
- **Status**: [IMPLEMENTING]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/888_harden_extension_discovery_against_stray_dirs/reports/01_harden-extension-discovery.md
- **Artifacts**: plans/01_harden-extension-discovery.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, neovim-lua.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Two defects in `M.list_extensions` (`lua/neotex/plugins/ai/shared/extensions/manifest.lua`,
lines 171-212) cause a stray `.agent-logs/` directory to be reported as a malformed extension
~120 times per reload: the `readdir` scan has no dot-prefix filter, and the invalid-manifest
warning re-fires on every call across a large call-site fan-out. Both fixes are one line each,
both use Neovim stdlib primitives already verified working in this build (v0.12.3), and both are
confined to a single function that every other call site delegates through. Definition of done:
dot-prefixed directories are skipped during the scan, and a single malformed non-dot extension
produces exactly one notification per session while still being excluded from the results.

### Research Integration

The research report established the complete fix and its bounds:

- Both defects are entirely inside `M.list_extensions`. The three call sites named in the task
  (`manifest.lua:219`, `manifest.lua:245`, `init.lua:842`) plus 9+ more (`init.lua:504` inside a
  loop, `picker.lua:68`/`:148`, `merge.lua:592`/`:758`) all funnel through this one function —
  that fan-out is what produces ~120 warnings from one bad directory. Fixing the one function
  fixes every caller.
- Defect 1: `vim.fn.readdir(dir, function(name) return name:sub(1, 1) ~= "." end)` — the predicate
  form of `readdir`, verified headless. One line at `manifest.lua:181`.
- Defect 2: `vim.notify_once(msg, level)` is Neovim stdlib and dedups by exact message text
  (verified headless: two identical calls emit once, a distinct message still emits). Swap
  `vim.notify` -> `vim.notify_once` at `manifest.lua:197`, inside the existing `vim.schedule`
  wrapper. No new module state.
- The fix propagates automatically to the delegating wrapper
  `lua/neotex/plugins/ai/claude/extensions/manifest.lua` and its existing `manifest_spec.lua`.
  No other file needs edits.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (none provided in delegation context).

## Goals & Non-Goals

**Goals**:
- Skip dot-prefixed entries during the extensions-directory scan.
- Emit exactly one notification per distinct malformed-extension message per session.
- Preserve warn-and-continue behavior for genuinely malformed non-dot extensions.
- Keep the change minimal: two lines in one function, using stdlib primitives.

**Non-Goals**:
- Caching/memoizing `list_extensions()` results. Research explicitly recommends against this: it
  would silently stale `manager.get_status()`'s live update-available version check (which reads
  `manifest.version` fresh from disk on every call), a regression beyond this task's scope. If
  the broader "re-scan on every call" performance question is ever addressed, it belongs in its
  own task with a defined cache-invalidation strategy.
- Refactoring the call-site fan-out or reducing the number of `list_extensions()` invocations.
- Changing `M.read`/`validate`, the skip-on-error branch, or the `vim.schedule` wrapper.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `vim.notify_once` dedups two distinct malformed dirs producing byte-identical messages | L | L | Not practical — the directory name is embedded in the message, so names are always distinct. Even if it occurred, both extensions are still correctly excluded from results. |
| Dot-filter hides a legitimately misnamed extension directory (e.g. `.foo`) | L | L | Standard, expected behavior for directory scanners; no existing extension in `agent-system/extensions/` is dot-prefixed, and manifest-bearing extensions should never be by convention. |
| Regression test depends on real on-disk `agent-system/extensions/` state | M | L | Use the isolated `vim.fn.tempname()` + `mkdir` + `after_each(delete)` pattern from `scan_spec.lua` — never the live extensions dir. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Apply the two-line fix to M.list_extensions [COMPLETED]

**Goal**: Both defects fixed in `M.list_extensions`, verified behaviorally in headless Neovim.

**Tasks**:
- [x] At `manifest.lua:181`, pass the dot-prefix predicate to the existing `readdir` call:
      `vim.fn.readdir(extensions_dir, function(name) return name:sub(1, 1) ~= "." end)`
- [x] At `manifest.lua:197`, change `vim.notify` to `vim.notify_once` (keep the surrounding
      `vim.schedule` wrapper and the message/level arguments unchanged)
- [x] Confirm nothing else in the function changed: `M.read`/validate chain, the `table.insert`
      skip-on-error branch, and the `table.sort` are untouched
- [x] Verify the module loads clean:
      `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.manifest')" -c "q"`
- [x] Verify behaviorally against a temp dir containing a `.stray/` dir and a malformed non-dot
      extension: the dot dir is absent from results and produces no warning; the malformed dir
      warns exactly once across two successive `list_extensions()` calls

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` - dot-prefix predicate on the `readdir`
  call (line 181); `vim.notify` -> `vim.notify_once` (line 197)

**Verification**:
- Module loads without error headless
- Dot-prefixed directory neither appears in `list_extensions()` results nor triggers a warning
- A malformed non-dot directory is excluded from results and warns exactly once across two calls
- Existing `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua` still passes (it exercises
  the shared module through the delegating wrapper)

---

### Phase 2: Add regression test coverage [COMPLETED]

**Goal**: Both fixed behaviors are locked in by an isolated, repeatable test.

**Tasks**:
- [x] Add a `describe("list_extensions")` block covering the shared module, using the
      `vim.fn.tempname()` + `vim.fn.mkdir(dir, "p")` + `after_each(vim.fn.delete(dir, "rf"))`
      pattern from `lua/neotex/plugins/ai/claude/commands/picker/utils/scan_spec.lua` — never
      the live `agent-system/extensions/` directory *(deviation: altered — placed in a new
      `lua/neotex/plugins/ai/shared/extensions/manifest_spec.lua` rather than the existing
      `claude/extensions/manifest_spec.lua`; see Files to modify note below for rationale)*
- [x] Case (a): a dot-prefixed subdirectory with no `manifest.json` is absent from the result and
      triggers no notification
- [x] Case (b): a malformed non-dot subdirectory is excluded from the result and produces exactly
      one notification across two successive `list_extensions()` calls (stub `vim.notify` and
      count invocations)
- [x] Confirm a valid extension in the same temp dir is still returned (guards against the filter
      over-matching)
- [x] Run the spec and confirm it passes

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/manifest_spec.lua` (new file, new `describe` block).
  Judgment call resolved: the shared module's `M.list_extensions(config)` takes a config table,
  while the existing `claude/extensions/manifest_spec.lua` exercises the delegating wrapper's
  `list_extensions(global_dir_string)` against the real `agent-system/extensions/` directory
  (including a live `lean` extension fixture). Placing the new isolated, temp-dir-only tests in
  a new spec file colocated with the actually-fixed module avoids mixing the wrapper's
  string-argument/live-fixture style with the shared module's config-table/temp-dir style in one
  file, and keeps the new tests fully isolated from live on-disk extension state per the plan's
  deciding factor.

**Verification**:
- New test cases pass
- Pre-existing cases in the touched spec file still pass

## Testing & Validation

- [ ] `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.manifest')" -c "q"` loads clean
- [ ] Dot-prefixed directory skipped: absent from results, no warning
- [ ] Malformed non-dot extension: excluded from results, exactly one warning across two calls
- [ ] Valid extension still discovered and returned (filter does not over-match)
- [ ] Existing `manifest_spec.lua` suite passes unchanged
- [ ] Diff to `manifest.lua` is two lines

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` (two-line fix)
- Regression test coverage in `manifest_spec.lua` (existing file, new block) or a new shared-module spec
- `specs/888_harden_extension_discovery_against_stray_dirs/summaries/01_harden-extension-discovery-summary.md`

## Rollback/Contingency

The change is two lines in one function with no new state, no new files, and no signature
changes. `git checkout` of `manifest.lua` fully reverts it. If `vim.notify_once` proves
unsuitable in some unforeseen context, defect 1's filter alone still removes the reported
`.agent-logs/` trigger and can ship independently — the two lines are not coupled.
