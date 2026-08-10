# Teammate C (Critic): Gaps, Blind Spots, and Unvalidated Assumptions

**Task**: 587 - Fix Neovim rendering corruption after system sleep in WezTerm
**Role**: Critic — identify what was missed or assumed incorrectly
**Confidence**: High

## Key Findings

### 1. CRITICAL: The Baseline Was Never Established

The single most important diagnostic step was skipped: **nobody verified that `Y` works without blinking in the restored yanky.nvim configuration.** The implementation jumped straight to replacing yanky without first confirming that the current config has no yank-time blinking.

With yanky.nvim, `Y` is NOT `y$`. It is `<Plug>(YankyYank)` (see yanky.lua line 21). YankyYank intercepts the native yank and routes it through yanky's own ring/clipboard/highlight pipeline. This is a completely different code path than native `y$` hitting the clipboard provider directly.

**Possibility**: The "blinking on Y" may be a pre-existing behavior of Neovim + WezTerm + Wayland + `clipboard=unnamedplus` that users never notice because yanky's `<Plug>(YankyYank)` masks it. When yanky was removed, native yank exposed the underlying terminal interaction.

### 2. CRITICAL: The Key Mapping Changed Silently

With yanky.nvim loaded:
- `y` → `<Plug>(YankyYank)` (yanky intercepts, handles clipboard internally)
- `Y` → `y$` (from keymaps.lua:303), BUT `y` is itself remapped to `<Plug>(YankyYank)`, so `Y` = `YankyYank` + `$` motion

With yanky.nvim removed and no replacement keymaps:
- `y` → native Vim yank (triggers clipboard provider via `clipboard=unnamedplus`)
- `Y` → `y$` (keymaps.lua:303, now using NATIVE yank)

The native yank path goes through Neovim's internal clipboard provider, which calls `wl-copy` synchronously via `systemlist()` on Wayland. YankyYank calls `vim.fn.setreg()` internally, which ALSO triggers the clipboard provider — but the timing and context may differ.

**The implementation team assumed that removing yanky was safe because `Y` → `y$` would behave the same. It does NOT. The clipboard interaction path changed.**

### 3. HIGH PRIORITY: `lazyredraw=true` Was Never Tested

`options.lua` line 155 sets `vim.opt.lazyredraw = true`. The `Y` key is a mapping (`y$`, from keymaps.lua:303). During mapping execution, `lazyredraw` suppresses all screen updates.

The clipboard provider write (wl-copy or OSC 52) happens synchronously during the mapping. If the clipboard write causes ANY terminal output (cursor repositioning, title update, escape sequence response), that output gets queued. When the mapping completes and lazyredraw releases, all pending updates render at once — producing a visible flash.

**This was identified in the diagnostic report's "What Was NOT Investigated" section (item 5) but was never actually tested.** Simply setting `vim.opt.lazyredraw = false` temporarily would have confirmed or eliminated this theory in 10 seconds.

### 4. HIGH PRIORITY: No Process-Level Verification Was Done

The diagnostic report claims OSC 52 was tried, which should eliminate `wl-copy`. But this was never verified:
- No `strace -f -e trace=execve` was run during a yank
- No `:lua print(vim.inspect(vim.g.clipboard))` was checked in a LIVE (non-headless) session with plugins loaded
- No confirmation that `vim.g.clipboard` set during VeryLazy actually takes precedence over the already-discovered default provider

Neovim's clipboard provider discovery (`runtime/autoload/provider/clipboard.vim`) caches the provider on first use. If any plugin or startup code accessed the clipboard before VeryLazy fired, the default wl-clipboard provider would be cached and `vim.g.clipboard` would be ignored for subsequent operations.

### 5. The Symptom Description Was Imprecise and Shifting

The reported symptoms changed across each fix:
1. "rapid blinking cursor" — cursor itself blinks rapidly
2. "slowed the rate of the blink" — debounce partially helped
3. "WezTerm in the top-left corner" — WezTerm UI element blinking
4. "same issue" — unclear which symptom

These are potentially THREE different issues:
- **Cursor blink**: Could be `cursor_blink_rate = 500` in wezterm.lua interacting with cursor visibility resets from `:mode` or clipboard operations
- **Screen flash**: Could be `lazyredraw` batching + release
- **WezTerm title/chrome blink**: Could be Wayland compositor focus changes (wl-copy stealing focus)

Without a screen recording or precise description ("the cursor disappears and reappears" vs "the whole screen flashes" vs "the tab bar changes"), the fixes were targeting symptoms blindly.

### 6. WezTerm Config Has Relevant Settings

From `~/.dotfiles/config/wezterm.lua`:
- `cursor_blink_rate = 500` — Cursor blinks every 500ms. If Neovim resets cursor visibility (via `:mode` or clipboard provider terminal output), the blink cycle restarts, which LOOKS like rapid blinking.
- `window_decorations = "NONE"` — Compositor handles decorations. The "WezTerm in top-left corner" blink could be the compositor's title bar flickering when focus changes.
- `window_background_opacity = 0.9` — Transparency enabled. Focus changes can cause the compositor to re-composite the window, creating a visible flash through the transparent background.
- `front_end = "OpenGL"` — GPU rendering. GPU texture invalidation on focus change could cause a frame drop visible as a blink.
- The `window-focus-changed` handler is commented out (line 34), so it's not directly involved.

### 7. The Simplest Fix Was Skipped

Report 02 recommended four options. The implementation went directly to **Option C (Full Custom Implementation, 4-6 hours, Medium risk)** despite the report itself ranking it third.

**Option A (Minimal Fix, 15 minutes, Low risk)** was never tried:
1. Set `system_clipboard = { sync_with_ring = false }` in yanky config
2. Add recovery autocommand
3. Done

**Option D (Hybrid, 1 hour, Low risk)** was the actual recommendation and also never tried.

The yank-time blinking may have been entirely caused by removing yanky's `<Plug>` keymaps, not by anything in our custom code.

## Unvalidated Assumptions

| Assumption | Status | Impact |
|------------|--------|--------|
| Y blinks because of our yank ring code | **UNVALIDATED** — blink persisted even with handler gutted | Wasted 5 fix iterations |
| OSC 52 eliminates wl-copy calls | **UNVERIFIED** — no strace/process monitoring | May have been testing against cached provider |
| Native y$ behaves the same as YankyYank | **FALSE** — different clipboard interaction paths | Changed the behavior being tested |
| lazyredraw doesn't affect yank rendering | **UNTESTED** — listed as uninvestigated but never tested | Potentially the entire root cause |
| The blinking was a single issue | **UNLIKELY** — symptoms changed across fixes | May have been fixing one issue and exposing another |
| Replacing yanky was necessary | **UNVALIDATED** — simpler fixes never attempted | 4-6 hours wasted on unnecessary complexity |

## Recommended Diagnostic Steps (What Should Have Been Done)

### Before ANY implementation:
1. **Confirm Y works with yanky**: Press Y 20 times in current config, confirm no blinking
2. **Test with nvim --clean**: `nvim --clean -c "set clipboard=unnamedplus" test.txt`, press Y
3. **Test without clipboard sync**: `nvim --clean test.txt` (no clipboard=unnamedplus), press Y
4. **Test lazyredraw**: Temporarily add `vim.opt.lazyredraw = false` to options.lua, press Y

### When implementing:
5. **Start with Option A**: Just change `sync_with_ring = false` and test post-sleep behavior
6. **Verify process-level**: `strace -f -e trace=execve -p $(pgrep nvim)` during yank operations
7. **Log clipboard provider**: Add `vim.notify(vim.inspect(vim.g.clipboard.name))` to verify which provider is active
8. **Test incremental changes**: One change per iteration, test after each

### When debugging visual issues:
9. **Record the screen**: Use `wf-recorder` or OBS to capture exact visual behavior
10. **Check :messages**: Run `:messages` after the blink to see if any notification/error is shown
11. **Monitor terminal output**: Use `script` or terminal logging to capture raw escape sequences

## Additional Notes

- The `checktime` autocommand on FocusGained (autocmds.lua:98-111) is a secondary concern: if wl-copy steals focus and triggers FocusGained, `checktime` may reload the buffer if the file changed externally, causing a visible buffer refresh. This was not investigated.
- The `format-tab-title` handler in wezterm.lua (line 306) reformats tab titles on every tab event. If focus changes (from wl-copy) trigger tab title reformatting, this could cause the "WezTerm in top-left corner" blink.
- WezTerm's `window_background_opacity = 0.9` means the compositor re-composites on every focus change. This is a known cause of visual flashing on Wayland with transparent windows.
