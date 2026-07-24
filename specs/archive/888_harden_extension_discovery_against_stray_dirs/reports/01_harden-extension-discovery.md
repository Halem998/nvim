# Research Report: Task #888

**Task**: 888 - Harden extension discovery against stray directories
**Started**: 2026-07-16T07:00:08Z
**Completed**: 2026-07-16T07:20:00Z
**Effort**: small (single function, two localized edits)
**Dependencies**: None
**Sources/Inputs**: Local codebase (`lua/neotex/plugins/ai/shared/extensions/`), headless
Neovim verification of `vim.fn.readdir` filter semantics and `vim.notify_once` dedup semantics
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md, neovim-lua.md

## Executive Summary

- Both defects live entirely inside one function: `M.list_extensions` in
  `lua/neotex/plugins/ai/shared/extensions/manifest.lua` (lines 171-212). No other file needs
  editing — the two other call sites named in the task (`manifest.lua:219`, `manifest.lua:245`)
  and `init.lua:842`, plus at least 8 more call sites found during this research, all funnel
  through `M.list_extensions`/`M.get_extension`, so a fix here propagates everywhere, including
  through the delegating wrapper `lua/neotex/plugins/ai/claude/extensions/manifest.lua`.
- **Defect 1 fix** (dot-prefix filter): `vim.fn.readdir()` accepts a Lua predicate as its second
  argument. Confirmed working in this Neovim build (v0.12.3):
  `vim.fn.readdir(extensions_dir, function(name) return name:sub(1, 1) ~= "." end)`. This is a
  true one-line change to the existing `readdir` call at manifest.lua:181 — no manual filtering
  loop needed.
- **Defect 2 fix** (warn-once dedup): Neovim's stdlib already provides exactly this semantic.
  `vim.notify_once(msg, level)` — confirmed empirically in this build to suppress a second call
  with identical message text while still emitting for a distinct message. Swapping
  `vim.notify` → `vim.notify_once` at manifest.lua:197 is a one-line change requiring no new
  module state (no hand-rolled "warned" table).
- Both fixes combined are a ~2-line diff in a single function. No other module needs changes,
  no test scaffolding is strictly required to fix the bug, though a regression test is
  recommended (pattern and location identified below).
- Recommended approach explicitly avoids introducing a full memoization/cache layer for
  `list_extensions()` results: that would also silently freeze `manager.get_status()`'s
  update-available detection (which compares live `manifest.version` against stored state) for
  the rest of the Neovim session, a behavior change the task did not ask for and that the user's
  "preserve existing behavior" framing argues against.

## Context & Scope

Task 888 reports two defects in extension discovery:

1. `M.list_extensions` treats every subdirectory of `config.global_extensions_dir`
   (`~/.config/nvim/agent-system/extensions/` for the Claude preset,
   `~/.config/nvim/.opencode/extensions/` for the OpenCode preset — see
   `lua/neotex/plugins/ai/shared/extensions/config.lua:58-87`) as an extension candidate,
   including dot-prefixed entries (e.g. a stray `.agent-logs/` directory with no
   `manifest.json`).
2. The invalid-manifest warning is not deduplicated. `list_extensions()` performs a fresh
   `readdir` + JSON-parse + validate pass on every call, and there are many call sites per
   picker/reload cycle, so one bad directory produces one `vim.notify` per call — which the task
   reports totaling ~120 identical notifications for a single stray directory.

The research goal was to locate the exact function(s) responsible, confirm the reported line
numbers, enumerate all call sites that would benefit from the fix, and identify the most
minimal/elegant mechanism (per user focus: "clean and elegant, high performance, minimal code")
satisfying both requirements without behavior regressions.

## Findings

### Existing Configuration — the exact code in question

`lua/neotex/plugins/ai/shared/extensions/manifest.lua`, `M.list_extensions` (lines 171-212):

```lua
function M.list_extensions(config)
  local extensions_dir = config.global_extensions_dir
  local extensions = {}

  if vim.fn.isdirectory(extensions_dir) ~= 1 then
    return extensions
  end

  local entries = vim.fn.readdir(extensions_dir)        -- line 181: no dot filter (defect 1)
  for _, entry in ipairs(entries) do
    local extension_path = extensions_dir .. "/" .. entry

    if vim.fn.isdirectory(extension_path) == 1 then
      local manifest, err = M.read(extension_path)
      if manifest then
        table.insert(extensions, { name = manifest.name, path = extension_path, manifest = manifest })
      else
        vim.schedule(function()
          vim.notify(                                    -- line 197: re-warns every call (defect 2)
            string.format("Extension '%s' has invalid manifest: %s", entry, err),
            vim.log.levels.WARN
          )
        end)
      end
    end
  end

  table.sort(extensions, function(a, b) return a.name < b.name end)
  return extensions
end
```

The reported line numbers match exactly: the `readdir` scan is manifest.lua:181-182, the
`M.get_extension` call to `list_extensions` cited as manifest.lua:219 is at line 219
(`local extensions = M.list_extensions(config)` inside `M.get_extension`), and the
`M.aggregate_extension_artifacts` call cited as manifest.lua:245 is at line 245
(`local extensions = M.list_extensions(config)` inside that function).

### Call-site fan-out (explains the ~120-warning report)

`init.lua:842` (the third site named in the task) is `manager.list_available()`:

```lua
function manager.list_available()
  ...
  local extensions = manifest_mod.list_extensions(config)   -- init.lua:842
  ...
end
```

Beyond the three sites the task names, `manifest_mod.get_extension(...)` — which internally
re-calls `list_extensions()` and thus re-scans + re-warns — is called from at least 9 more
sites in `lua/neotex/plugins/ai/shared/extensions/init.lua` (lines 243, 504, 622, 629, 827, 881,
914) and `lua/neotex/plugins/ai/shared/extensions/merge.lua` (lines 592, 758). Notably,
init.lua:504 calls `get_extension` **inside a loop** over `loaded_names` during extension load
(pre-load cleanup of stale context index entries), so a single `/extension load` invocation with
several already-loaded extensions can itself trigger several full re-scans. The picker
(`shared/extensions/picker.lua:68` and `:148`) calls `manager.list_available()` on open and on
refresh, and `manager.get_status()` (which also calls `get_extension` → `list_extensions`) is
invoked once per extension row when rendering picker entries
(`lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`). This combination —
multiple call sites, some in per-extension loops, invoked repeatedly across picker opens and
reloads — plausibly accounts for the ~120-notification figure from a single malformed directory.

### Dual manifest modules — confirmed the fix propagates

`lua/neotex/plugins/ai/claude/extensions/manifest.lua` is a thin Claude-preset wrapper that
delegates every function, including `list_extensions`, to the shared module:

```lua
local shared_manifest = require("neotex.plugins.ai.shared.extensions.manifest")
...
function M.list_extensions(global_dir)
  local cfg = global_dir and config.get(global_dir) or claude_config
  return shared_manifest.list_extensions(cfg)
end
```

So fixing `shared/extensions/manifest.lua` fixes both the shared module's direct callers and
the Claude-preset wrapper's callers (including the existing test suite at
`lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua`) with zero additional edits.

### Verified fix mechanics (both confirmed via headless Neovim in this environment)

**Dot-prefix filter** — `vim.fn.readdir()` accepts a Lua function as an inline filter
predicate; entries for which it returns falsy are excluded from the result, avoiding a
separate post-filter loop:

```lua
local entries = vim.fn.readdir(extensions_dir, function(name)
  return name:sub(1, 1) ~= "."
end)
```

Verified: `nvim --headless -c "lua print(vim.fn.readdir('.', function(n) return n:sub(1,1) ~= '.' end)[1])"`
returned a non-dot entry, confirming the predicate is honored by this Neovim build (v0.12.3).

**Warn-once dedup** — `vim.notify_once(msg, level)` is a Neovim stdlib function (present in
this build) that suppresses a second call carrying the exact same message text while still
firing for any distinct message. Verified via headless test:

```lua
local n = 0
local orig = vim.notify
vim.notify = function(...) n = n + 1 end
vim.notify_once('same msg', vim.log.levels.WARN)
vim.notify_once('same msg', vim.log.levels.WARN)  -- suppressed
vim.notify_once('diff msg', vim.log.levels.WARN)
print('count=' .. n)  -- prints "count=2"
```

Because the existing message is built deterministically from `entry` (the directory name) and
`err` (the validation error text), the same broken directory produces the same message text on
every re-scan within a session, so `vim.notify_once` collapses all repeats to exactly one
notification — matching the task's literal requirement ("a single malformed extension yields a
single notification") without adding any new module-level state.

### Community/idiom check

Both `vim.fn.readdir(dir, expr)` (predicate/filter form) and `vim.notify_once` are documented
Neovim stdlib facilities, not project-specific conventions — no existing dot-filter or
warn-once pattern was found elsewhere in this codebase to match against (`grep` across
`shared/extensions/*.lua` for `:match("^%.")`/`vim.startswith`/`notify_once` returned no other
usages), so this task would be the first and canonical instance of both idioms in this module
family. Using the stdlib primitives directly (rather than hand-rolling dot-checks or a warned-
set table) best satisfies the user's "clean and elegant... minimal code" framing.

## Recommendations

1. **`manifest.lua:181`** — change the `readdir` call to pass the dot-prefix filter predicate
   shown above. This is defect 1's complete fix; it also incidentally reduces defect 2's blast
   radius (dot-directories with no manifest.json will no longer even reach the warn branch).
2. **`manifest.lua:197`** — change `vim.notify` to `vim.notify_once` inside the existing
   `vim.schedule` wrapper (keep `vim.schedule` as-is; it defers the call outside fast-event
   context, unrelated to the dedup fix). This is defect 2's complete fix and requires no new
   local/module state.
3. Do **not** memoize/cache the full `list_extensions()` result set to solve defect 2. It would
   also fix the warning duplication (since the scan+notify would only execute once), but it
   would silently make `manager.get_status()`'s "update-available" detection stale for the rest
   of the session (that function reads `extension.manifest.version` fresh from disk on every
   call today, via `get_extension` → `list_extensions` → `M.read` → `read_json`). That is a
   behavior change beyond what defect 2 requires and risks regressing a feature the task did not
   mention. If a future task wants to address the broader "re-scan on every call" performance
   question, it should do so as its own explicitly-scoped change with a defined cache
   invalidation strategy (e.g., explicit `M.clear_cache()` called after `manager.load`/`unload`),
   not bundled into this bug fix.
4. Preserve the existing warn-and-continue behavior for genuinely malformed non-dot extensions:
   the `M.read`/`validate` call chain, the `table.insert` skip-on-error branch, and the
   `vim.schedule` wrapper are all unchanged — only the two lines above change.
5. **Optional regression test**: no spec file currently exists for
   `lua/neotex/plugins/ai/shared/extensions/manifest.lua` directly (only the delegating
   `claude/extensions/manifest_spec.lua` exercises it indirectly against the real
   `agent-system/extensions/` directory on disk). A good home for a regression test is either a
   new `describe("list_extensions")` block in that existing spec file, or a new
   `shared/extensions/manifest_spec.lua`, using the `vim.fn.tempname()` + `vim.fn.mkdir(dir,
   "p")` + `after_each(vim.fn.delete(dir, "rf"))` pattern already used in
   `lua/neotex/plugins/ai/claude/commands/picker/utils/scan_spec.lua`. Two cases worth covering:
   (a) a dot-prefixed subdirectory with no `manifest.json` is silently skipped and does not
   appear in the result or trigger a warning; (b) a genuinely malformed non-dot subdirectory
   still triggers exactly one `vim.notify`-level call across two successive `list_extensions()`
   invocations (can be verified by stubbing `vim.notify` and counting invocations, mirroring the
   verification snippet above).

## Decisions

- Fix location confirmed as `lua/neotex/plugins/ai/shared/extensions/manifest.lua`,
  `M.list_extensions` only — no other file requires edits for correctness, since every other
  call site (`get_extension`, `aggregate_extension_artifacts`, `manager.list_available`,
  `manager.get_status`, the Claude-preset wrapper, `merge.lua`) delegates to this one function.
- Chose Neovim stdlib primitives (`readdir` predicate argument, `vim.notify_once`) over
  hand-rolled filtering/dedup logic, per the user's "minimal code, high quality" framing and
  because both primitives were empirically verified to behave as needed in this Neovim build.
- Explicitly rejected caching/memoizing the extension list as the fix for defect 2, to avoid an
  unrequested regression in `manager.get_status()`'s live version-check behavior.

## Risks & Mitigations

- **Risk**: `vim.notify_once`'s dedup key is the literal message string. If two different
  malformed directories happen to produce byte-identical messages (unlikely, since `entry`
  — the directory name — is embedded in the message), only one notification would fire for
  both. **Mitigation**: not a practical concern (directory names are always distinct), and even
  if it occurred, it would still satisfy "warn and continue" — the extensions themselves are
  still correctly excluded from the extensions list regardless of whether a notification fires.
- **Risk**: `vim.notify_once`'s suppression set has no expiry, so if a user fixes a malformed
  manifest mid-session but a *different* error remains, the message text changes (since `err`
  is embedded) and a fresh notification correctly fires — no mitigation needed, this is the
  desired behavior.
- **Risk**: Silently skipping dot-directories could theoretically hide a legitimately misnamed
  extension directory (e.g. someone accidentally named a real extension folder `.foo`).
  **Mitigation**: this is standard, expected behavior for any directory-scanning tool (dotfiles/
  dot-directories are conventionally hidden/ignored); no existing extension in
  `agent-system/extensions/` is dot-prefixed, and manifest.json-bearing extensions should never
  be dot-prefixed by convention.

## Context Extension Recommendations

None — this is a narrowly-scoped bug fix in existing, already-documented module code. No new
Neovim API pattern or plugin-ecosystem topic is introduced that would warrant an addition to
`.claude/context/project/neovim/domain/neovim-api.md` or similar.

## Appendix

### Files examined
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` (primary fix location)
- `lua/neotex/plugins/ai/shared/extensions/init.lua` (call-site fan-out)
- `lua/neotex/plugins/ai/shared/extensions/config.lua` (confirms `global_extensions_dir` values)
- `lua/neotex/plugins/ai/shared/extensions/picker.lua` (confirms picker-driven repeated calls)
- `lua/neotex/plugins/ai/claude/extensions/manifest.lua` (delegating wrapper)
- `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua` (existing test coverage)
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan_spec.lua` (temp-dir test pattern
  reference for the recommended regression test)

### Verification commands run
```bash
nvim --headless -c "lua print(vim.fn.readdir('.', function(n) return n:sub(1,1) ~= '.' end)[1])" -c "q"
nvim --headless -c "lua local n=0; local orig=vim.notify; vim.notify=function(...) n=n+1 end; \
  vim.notify_once('same msg', vim.log.levels.WARN); vim.notify_once('same msg', vim.log.levels.WARN); \
  vim.notify_once('diff msg', vim.log.levels.WARN); print('count='..n)" -c "q"
grep -rn "list_extensions\|get_extension\|aggregate_extension_artifacts" lua/neotex/plugins/ai/shared/extensions/
```
