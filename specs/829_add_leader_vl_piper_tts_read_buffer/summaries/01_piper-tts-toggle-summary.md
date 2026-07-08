# Implementation Summary: Task #829

**Completed**: 2026-07-08
**Duration**: ~40 minutes

## Overview

Added a `<leader>vl` normal-mode toggle that reads the current buffer aloud from the cursor
position through end-of-buffer using an offline Piper TTS + sox `play` pipeline, stopping
playback immediately on a second press. Implemented as a new self-contained module,
`lua/neotex/util/tts.lua`, mirroring the process-management and toggle-state conventions of the
existing STT module and `sleep-inhibit.lua`, plus a single which-key entry in the existing
`<leader>v` voice group.

## What Changed

- `lua/neotex/util/tts.lua` — New module. Module-local state (`job_id`, `cleanup_registered`),
  config (`DEFAULT_SAMPLE_RATE = 22050`, model path default
  `~/.local/share/piper/en_US-lessac-medium.onnx`), helpers (`notify`, `command_exists`,
  `get_sample_rate`, `get_text`, `resolve_player`), and public API (`M.is_playing()`,
  `M.health()`, `M.start()`, `M.stop()`, `M.toggle()`). Playback spawns
  `sh -c "piper -m <model> --output_raw -q | play -q -t raw -r <rate> -e signed -b 16 -c 1 -"`
  via `vim.fn.jobstart`, feeds text via `chansend`/`chanclose("stdin")`, and resets `job_id` in a
  single `on_exit` callback shared by natural completion and manual stop. Cleanup (`VimLeavePre`)
  is registered lazily inside `M.start()` via a guarded `ensure_cleanup()`, avoiding the
  unwired-`setup()` gap present in `sleep-inhibit.lua`.
- `lua/neotex/plugins/editor/which-key.lua` — Added
  `{ "<leader>vl", function() require('neotex.util.tts').toggle() end, desc = "read buffer aloud (TTS)", icon = "" }`
  to the existing `<leader>v` voice `wk.add({...})` block (after `vv`), and broadened the
  section banner comment from `(STT)` to `(STT + TTS)`.

## Decisions

- `resolve_player(sample_rate)` takes a sample-rate parameter (rather than the plan's no-arg
  signature) so it directly emits a fully-formed player command (`play -r <rate> ...` or
  `pw-play --rate=<rate> ...`); `health()` checks player presence via `command_exists` directly
  since it only needs existence, not a formatted command.
- Icon `""` (speaker) used for the TTS entry to visually distinguish it from the STT
  mic-family icons already used by `vh`/`vr`/`vs`/`vv`.

## Plan Deviations

- **Phase 1, `resolve_player`**: altered to accept a `sample_rate` parameter (see Decisions).
- **Phase 2, `M.start()`**: internal check ordering altered (piper-exists -> model-readable ->
  `resolve_player(sample_rate)`) since the sample rate must be read from the model's `.onnx.json`
  sidecar before a player command string can be formatted. Behavior is unchanged.
- **Phase 3, headless which-key verification**: the plan's
  `nvim --headless -c "verbose nmap <leader>vl" -c "qa"` check is infeasible in this environment.
  Investigated and confirmed this is a pre-existing tooling limitation, not a regression:
  which-key.nvim v3's `wk.add()` queues mapping specs and only converts them into real
  `vim.keymap.set` calls via an internal `vim.schedule_wrap`'d loader that requires a genuine
  interactive event loop to fire (confirmed it never runs under `nvim --headless -c ... -c "qa"`,
  even after `doautocmd User VeryLazy` + `sleep`). The pre-existing `<leader>vh` mapping was
  tested and shows the identical "No mapping found" result, independent of this change.
  Substituted verification: `grep -rn "<leader>vl" lua/` confirms exactly one binding, added
  using the same `wk.add({...})` structure as the already-working `vh`/`vr`/`vs`/`vv` entries,
  plus a clean full-config headless load.
- **"Manual" test items**: exercised as direct headless calls to
  `require('neotex.util.tts').start()/.stop()/.is_playing()` against the real, unstubbed
  `piper | play` pipeline (not mocked), rather than literal `<leader>vl` keypresses, since
  which-key dispatch cannot be triggered headlessly (see above). This covers all playback-engine
  behavior end-to-end; the only remaining untested surface is the which-key key-dispatch layer
  itself, which is structurally identical to already-functioning entries.

## Verification

- Neovim startup: Success (`nvim --headless -c "echo 'Startup OK'" -c "q"`, exit 0)
- Module loading: Success (`nvim --headless -c "lua require('neotex.util.tts')" -c "q"`, exit 0)
- Full config load: Success (`nvim --headless -c "qa"`, exit 0, no which-key/Lua errors)
- `health()`: returns `true`, all dependencies (piper, `play`, model, `.onnx.json` sidecar)
  satisfied in this environment
- Real playback test (headless, real audio): `start()` on a multi-line buffer ->
  `is_playing() == true`; `stop()` -> `is_playing() == false` immediately, `pgrep piper`/
  `pgrep play` empty (no orphaned processes)
- Empty-buffer guard: `start()` on an empty buffer -> `is_playing()` stays `false`, no job spawned
- Mid-playback `:qa`: lazily-registered `VimLeavePre` cleanup fires, `pgrep piper`/`pgrep play`
  empty afterward (no orphaned processes survive Neovim exit)
- Duplicate-binding check: `grep -rn "<leader>vl" lua/` returns exactly one binding (plus one
  doc-comment reference in `tts.lua`)

## Notes

- No keybinding conflicts: `<leader>vl` was previously unbound.
- The which-key headless-verification gap documented above applies equally to all pre-existing
  voice-group entries and is not specific to this change; true interactive confirmation of the
  `<leader>vl` keypress is recommended as a follow-up manual check but was not possible in this
  non-interactive session.
- An unrelated, pre-existing uncommitted change to `lua/neotex/plugins/editor/which-key.lua`
  (updating `<leader>nr`/`<leader>nu` Nix rebuild commands to `cd ~/.dotfiles && ./scripts/...`)
  was present in the working tree before this task began and was deliberately left unstaged and
  uncommitted across all three phase commits, since it is out of scope for task 829.
