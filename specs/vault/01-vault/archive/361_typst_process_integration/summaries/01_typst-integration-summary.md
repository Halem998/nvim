# Implementation Summary: Task #361

**Completed**: 2026-04-03
**Duration**: 15 minutes

## Changes Made

Migrated `after/ftplugin/typst.lua` from ad-hoc `vim.fn.jobstart`/`jobstop` calls with a script-local `typst_watch_job` variable to the shared `neotex.util.process` registry API. All typst background processes (watch, compile, preview) are now tracked in the process registry, making them visible in the telescope process picker and manageable through unified `<leader>x` keymaps.

### Phase 1: Migrate typst_watch and typst_compile

- Added `require("neotex.util.process")` import
- Removed `typst_watch_job` script-local variable
- Rewrote `typst_watch()` to use `process.find_by_name("typst-watch")` for toggle detection and `process.start()` for job creation
- Rewrote `typst_watch_stop()` to use `process.find_by_name`/`process.stop` instead of direct jobstop
- Rewrote `typst_compile()` to use `process.start()` with `on_stderr`/`on_exit` callback passthrough, preserving all quickfix integration logic exactly
- Callbacks adapted from `(_, data)` jobstart signature to `(data)` process.lua signature

### Phase 2: Wrap TypstPreview with virtual registry entries

- Created `typst_preview_start()` wrapper: calls `vim.cmd("TypstPreview")` then `process.register_external()`
- Created `typst_preview_stop()` wrapper: calls `vim.cmd("TypstPreviewStop")` then `process.deregister()`
- Created `typst_preview_toggle()` wrapper: checks `process.find_by_name("typst-preview")` to decide start vs stop
- Updated which-key `<leader>lp`, `<leader>lx`, `<leader>ll` to use wrapper functions instead of raw commands
- Updated `tinymist_clear_cache()` to also call `process.deregister("typst-preview")`

## Files Modified

- `after/ftplugin/typst.lua` - Migrated job management to process.lua API, added TypstPreview wrappers

## Verification

- Build: N/A (ftplugin loaded at runtime)
- Lua syntax: Verified via `nvim --headless -c "luafile after/ftplugin/typst.lua" -c "q"` -- no errors
- No `typst_watch_job` references remain (grep verified)
- Only one `vim.fn.jobstart` remains (detached sioyek launcher, intentionally untracked)
- All keybindings preserved with same descriptions and icons

## Notes

- The sioyek PDF viewer launch (`<leader>lv`) remains a detached `vim.fn.jobstart` by design -- it is fire-and-forget and should not be tracked
- Process.lua `on_exit` callback wraps in `vim.schedule` and sends its own notification, so the `typst_watch` on_exit only handles the non-normal exit case to avoid duplicate "stopped" messages
- The `typst_compile` one-shot process will briefly appear in the registry during compilation, then be cleaned up by process.lua's on_exit handler
