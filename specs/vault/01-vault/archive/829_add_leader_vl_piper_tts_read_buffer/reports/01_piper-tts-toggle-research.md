# Research Report: Task #829

**Task**: 829 - Add a `<leader>vl` toggle mapping that uses piper TTS to read the current buffer aloud from the cursor position to end of buffer, stopping playback when toggled off.
**Started**: 2026-07-08T22:35:44Z
**Completed**: 2026-07-08T22:42:33Z
**Effort**: Small (single module + keymap registration + which-key entry)
**Dependencies**: None
**Sources/Inputs**: Local codebase (`lua/neotex/plugins/tools/stt/`, `lua/neotex/util/process.lua`, `lua/neotex/util/sleep-inhibit.lua`, `lua/neotex/plugins/editor/which-key.lua`, `lua/neotex/plugins/tools/init.lua`, `lua/neotex/bootstrap.lua`), Neovim 0.12.3 runtime docs (`job_control.txt`, `vimfn.txt`, `lua.txt` `vim.system`, `luvref.txt`), empirical headless-nvim experiments (see Appendix), existing `.claude/hooks/tts-notify.sh` piper precedent.
**Artifacts**: This report.
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `<leader>v` "voice" which-key group already exists (STT: `vh`/`vr`/`vs`/`vv` in `lua/neotex/plugins/tools/stt/init.lua`, registered via `lua/neotex/plugins/editor/which-key.lua:804-812`). `<leader>vl` is unclaimed and belongs in this same group.
- Recommended module: new directory `lua/neotex/plugins/tools/tts/init.lua` + thin `lua/neotex/plugins/tools/tts-plugin.lua` wrapper, registered in `lua/neotex/plugins/tools/init.lua`, mirroring the `stt`/`stt-plugin.lua` pair exactly.
- **`vim.fn.jobstart()` + `vim.fn.jobstop()` is the correct and sufficient primitive** — no `vim.system()`, no `detach`, no manual `killpg`/negative-PID tricks needed. I empirically verified (headless nvim, see Appendix) that `jobstart({"sh","-c","piper ... | play ..."})` places the shell **and both pipeline children in their own process group** (distinct from Neovim's), and a single `jobstop()` call reliably SIGTERMs the entire group — shell, piper, and play processes all die together. This directly contradicts the naive worry that killing only the shell PID would orphan the pipeline; it does not, because Neovim already isolates jobs into their own process group regardless of the `detach` option.
- Text extraction: `vim.api.nvim_win_get_cursor(0)` + `vim.api.nvim_buf_get_lines(0, row-1, -1, false)`, sliced at the cursor column on the first line.
- Feeding stdin: `vim.fn.chansend(job_id, text)` followed by `vim.fn.chanclose(job_id, "stdin")` — empirically verified to correctly forward through the *first* stage of a shell pipeline and let both stages complete/exit.
- `vim.system()` is available (Neovim 0.12.3) but is not used anywhere in this codebase; `jobstart`/`jobstop` is the established, exclusive convention (STT, mail, worktree, process-picker, sleep-inhibit, himalaya all use it). Recommend following that convention rather than introducing `vim.system()` as a one-off.

## Context & Scope

Researched how to wire a new toggle-based TTS playback feature into this Neovim config: keymap conventions, module placement conventions, and — the highest-risk unknown — whether killing a Neovim job that wraps a shell pipeline (`piper | play`) actually terminates every process in that pipeline, or only the shell. That last question was resolved empirically rather than by inference, since incorrect handling would leave orphaned `piper`/`play` processes running audio after "toggle off."

## Findings

### 1. Keymap infrastructure (`<leader>v` group)

`lua/neotex/plugins/editor/which-key.lua:804-813`:
```lua
-- ============================================================================
-- <leader>v - VOICE GROUP (STT)
-- ============================================================================

wk.add({
  { "<leader>v", group = "voice", icon = "󰍬" },
  { "<leader>vh", function() require('neotex.plugins.tools.stt').health() end, desc = "health check", icon = "󰸉" },
  { "<leader>vr", function() require('neotex.plugins.tools.stt').start_recording() end, desc = "start recording", icon = "󰑊" },
  { "<leader>vs", function() require('neotex.plugins.tools.stt').stop_recording() end, desc = "stop recording", icon = "󰓛" },
  { "<leader>vv", function() require('neotex.plugins.tools.stt').toggle_recording() end, desc = "toggle recording", icon = "󰔊" },
})
```
- `<leader>vl` is unclaimed (`grep -rn "<leader>vl" lua/` returns nothing).
- This block is currently labeled "(STT)" only; since `vl` adds a TTS/playback (not recording) function to the same group, the section comment should be broadened (e.g. "VOICE GROUP (STT + TTS)") and the group label possibly changed from `"voice"` to something more generic, or left as-is since "voice" already covers both directions. This is a planning-level decision, not a blocker.
- Existing keymap entries in this file do **not** pass `mode = {"n","v"}` for the voice group (unlike most other groups) — STT entries are normal-mode only. `<leader>vl` should follow suit (normal mode only makes sense for "read from cursor to EOF").
- No dedicated speaker/playback icon is reused elsewhere in this file; pick any Nerd Font speaker/headphone glyph (e.g. `󰕾`) for `vl`, distinct from the STT entries' mic-family icons.

### 2. Module placement

Precedent: `lua/neotex/plugins/tools/stt/` — a virtual-plugin directory module with `init.lua` (state + logic) and a `README.md`. It's registered as a lazy.nvim spec via a **separate wrapper file** `lua/neotex/plugins/tools/stt-plugin.lua`:
```lua
return {
  dir = vim.fn.stdpath('config') .. '/lua/neotex/plugins/tools/stt',
  name = 'stt',
  event = { 'VeryLazy' },
  config = function(_, opts)
    local module_path = 'neotex.plugins.tools.stt.init'
    local stt = require(module_path)
    stt.setup(opts)
  end,
}
```
That wrapper is then required and appended to the plugin list in `lua/neotex/plugins/tools/init.lua:87,122`:
```lua
local stt_module = safe_require("neotex.plugins.tools.stt-plugin")
...
add_if_valid(stt_module)
```
This whole chain is loaded explicitly from `lua/neotex/bootstrap.lua:82-85` (tools are loaded outside lazy.nvim's `{ import = ... }` auto-discovery, which is disabled on purpose per a comment at bootstrap.lua:138).

**Recommendation**: mirror this exactly —
- `lua/neotex/plugins/tools/tts/init.lua` — the TTS module (state, `toggle()`, `start()`, `stop()`, `health()`, `setup()`).
- `lua/neotex/plugins/tools/tts-plugin.lua` — thin lazy.nvim wrapper (`dir`, `name = 'tts'`, `event = 'VeryLazy'`, `config` calling `require('neotex.plugins.tools.tts.init').setup(opts)`).
- Register in `lua/neotex/plugins/tools/init.lua` alongside the `stt_module` lines (`local tts_module = safe_require("neotex.plugins.tools.tts-plugin")` + `add_if_valid(tts_module)`).

A simpler single-file alternative (`lua/neotex/util/tts.lua`, loaded directly via `require` from the keymap, no plugin-spec wrapper) is also viable and lower-ceremony (see `lua/neotex/util/sleep-inhibit.lua` and `lua/neotex/util/process.lua` for that pattern — plain modules with no lazy.nvim spec, required on demand). Since this feature needs no lazy-loading trigger beyond the keymap itself and has no plugin dependencies, `lua/neotex/util/tts.lua` is arguably the more idiomatic fit for a small self-contained utility (matches `process.lua` and `sleep-inhibit.lua`), while the `stt/` directory-module pattern is heavier (used there because STT has a README, Claude Code integration, and multiple keymaps/commands). Either is defensible; the `stt` sibling-module placement is more discoverable/consistent given `<leader>v` is explicitly the "voice" group and STT already lives under `plugins/tools/`, but a planner should pick one and note the trade-off explicitly (this report does not choose for you).

### 3. Process management: `jobstart`/`jobstop`, verified empirically

**Neovim version**: 0.12.3 (LuaJIT 2.1.1774638290). `vim.system()` is available but **unused anywhere in this codebase** — grep of `lua/` for `vim.system(` returned zero hits. Every existing background-process feature (STT, mail/mbsync, himalaya sync/oauth, worktree, process-picker, sleep-inhibit, discord-link, npm install) uses `vim.fn.jobstart()` / `vim.fn.jobstop()`. Following that convention keeps the new module consistent with the rest of the config.

**The core question**: does `jobstop()` on a job started as `jobstart({"sh", "-c", "piper ... | play ..."})` kill only the shell, orphaning `piper` and `play`? I tested this directly rather than relying on documentation, because the docs are ambiguous/silent on process-group behavior for shell-string jobs.

Test 1 — synthetic pipeline (`sh -c "sleep 100 | sleep 200"`):
```
Before jobstop:
  3040046 3040045 3040046  sh -c sleep 100 | sleep 200
  3040047 3040046 3040046  sleep 100
  3040048 3040046 3040046  sleep 200
After jobstop: (all three gone)
```
Test 2 — the actual production pipeline (`piper -m <model> --output_raw -q | play -q -t raw -r 22050 -e signed -b 16 -c 1 -`), fed a long synthetic text via `chansend`+`chanclose`, then `jobstop`ed mid-playback:
```
Before jobstop:
  3042985 ... sh -c piper -m ... --output_raw -q | play -q -t raw -r 22050 ...
  3042986 3042985 3042985  piper -m ... --output_raw -q
  3042987 3042985 3042985  play -q -t raw -r 22050 -e signed -b 16 -c 1 -
on_exit fired with code 143 (128+15 = SIGTERM)
After jobstop: (piper and play both gone; only unrelated host processes remain)
```
**Conclusion**: all three processes (shell, piper, play) share a single process group ID equal to the shell's own PID — distinct from Neovim's own group — and `jobstop()` terminates the whole group in one call. **No `detach=true`, no `vim.system()`, no `vim.uv.kill(-pid, ...)` workaround is needed.** A plain `vim.fn.jobstart({"sh", "-c", cmd}, {on_exit = ...})` + `vim.fn.jobstop(job_id)` is sufficient and matches the existing `stt/init.lua` pattern (`recording_job_id` / `vim.fn.jobstop(recording_job_id)`) almost verbatim.

**Stdin plumbing verified** too: `vim.fn.chansend(job_id, text)` then `vim.fn.chanclose(job_id, "stdin")` correctly delivers to the *first* stage of a `cmd1 | cmd2` pipeline (verified with `sh -c "cat | cat"`, output round-tripped correctly) and lets the pipeline finish naturally once stdin is closed (`on_exit` fires with code 0). Piper needs the stdin explicitly closed after the text is sent — otherwise it has no EOF signal and will hang waiting for more input.

**Recommended job invocation shape**:
```lua
local model = vim.fn.expand("~/.local/share/piper/en_US-lessac-medium.onnx")
local sample_rate = 22050 -- or read from model .onnx.json, see below
local cmd = string.format(
  "piper -m %s --output_raw -q | play -q -t raw -r %d -e signed -b 16 -c 1 -",
  vim.fn.shellescape(model), sample_rate
)
local job_id = vim.fn.jobstart({ "sh", "-c", cmd }, {
  on_exit = function(_, code, _)
    -- reset module-local state here (natural completion OR toggle-off both land here)
  end,
})
vim.fn.chansend(job_id, text)
vim.fn.chanclose(job_id, "stdin")
```
Toggle-off: `vim.fn.jobstop(job_id)` (verified to produce `on_exit` code 143 and fully tear down the pipeline).

Sample rate should ideally be read from `<model>.onnx.json` → `.audio.sample_rate` rather than hardcoded 22050, per the task's own guidance (verified: `~/.local/share/piper/en_US-lessac-medium.onnx.json` → `{"audio": {"sample_rate": 22050, "quality": "medium"}}`). Suggested helper:
```lua
local function get_sample_rate(model_path)
  local json_path = model_path .. ".json"
  local ok, lines = pcall(vim.fn.readfile, json_path)
  if not ok then return 22050 end
  local ok2, decoded = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
  if ok2 and decoded and decoded.audio and decoded.audio.sample_rate then
    return decoded.audio.sample_rate
  end
  return 22050
end
```

**Player choice**: prefer `play` (sox) as primary since it was the verified, explicitly-flagged pipeline in the task brief; `pw-play --format=s16 --rate=<n> --channels=1 --raw -` is a confirmed-working equivalent if `play` is ever unavailable — a `vim.fn.executable()` check with fallback would be a reasonable robustness addition, matching the `command_exists()` helper pattern already used in `stt/init.lua`.

### 4. Text extraction (cursor → end of buffer)

```lua
local cursor = vim.api.nvim_win_get_cursor(0)          -- {row (1-idx), col (0-idx)}
local row, col = cursor[1], cursor[2]
local first_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
local first_line_tail = first_line:sub(col + 1)         -- from cursor column to EOL
local rest_lines = vim.api.nvim_buf_get_lines(0, row, -1, false)  -- next line through EOF
local all = { first_line_tail }
vim.list_extend(all, rest_lines)
local text = table.concat(all, "\n")
```
This honors "from the cursor **position**" literally (column-precise), not merely "from the cursor line." If a simpler line-granular behavior is preferred instead (whole cursor line included regardless of column), drop the `:sub(col+1)` slicing and just use `nvim_buf_get_lines(0, row-1, -1, false)` joined with `\n` — this is a planning-level choice; the report presents both.

### 5. Toggle state

Follow the exact shape already used in `stt/init.lua` (module-local upvalues, not `vim.g.*` globals except optionally one for statusline integration) and `sleep-inhibit.lua` (a `M._state` table):
```lua
local M = {}
local job_id = nil   -- nil == not playing

function M.is_playing()
  return job_id ~= nil
end

function M.toggle()
  if job_id then
    M.stop()
  else
    M.start()
  end
end
```
`on_exit` callback must reset `job_id = nil` regardless of whether the job ended naturally (piper/play finished streaming the whole buffer) or was killed via `M.stop()` — this single reset point handles both "auto-off at end of buffer" and "manual toggle-off" without duplicated state-clearing logic, exactly mirroring how `stt/init.lua`'s `on_exit` resets `is_recording`/`recording_job_id` in one place regardless of stop cause.

State should be **global** (module-local, not buffer-scoped) — this matches STT's `is_recording` (a single global flag) and is simpler: only one TTS stream should ever play at a time regardless of which buffer triggered it. If toggled off from a different buffer than the one that started playback, it should still stop the same global job.

### 6. Edge cases

- **Empty selection** (cursor at/after last character of the buffer): `text` will be `""` or whitespace-only. Guard with a check and `vim.notify("Nothing to read", vim.log.levels.WARN)` before spawning, matching `stt/init.lua`'s guard-and-notify style (`notify(msg, level)` helper local to the module).
- **Playback already running**: toggle-off path — no special handling needed beyond the toggle logic above; a second `<leader>vl` press when `job_id ~= nil` calls `M.stop()`.
- **Dependency checks**: verify `piper`, and one of `play`/`pw-play`, are on `$PATH` via `vim.fn.executable()`, and that the model file (`vim.fn.filereadable()`) exists, before spawning — mirrors `stt/init.lua`'s `command_exists()` + `M.health()` pattern. Given the task's "verified environment facts," these should always succeed in this environment, but the guard costs nothing and matches repo conventions (every existing tool module in `plugins/tools/` checks `vim.fn.executable()` before spawning: mail.lua, stt/init.lua, worktree.lua all do this).
- **Buffer-specific vs. global state**: see above — recommend global.
- **Cleanup on VimLeave**: add an augroup with `clear = true` per `.claude/rules/neovim-lua.md`, calling `M.stop()` if a job is active on exit, following `sleep-inhibit.lua`'s and `lua/neotex/util/process.lua`'s `VimLeavePre` autocmd pattern (`lua/neotex/util/process.lua:562-569` registers exactly this kind of augroup for its own registry). If the new module is placed under `plugins/tools/tts/`, this augroup belongs in its `setup()` function, analogous to how `process.lua:M.setup()` registers `ProcessManager`'s `VimLeavePre`.

## Decisions

- Use `vim.fn.jobstart`/`vim.fn.jobstop` (not `vim.system()`) — matches 100% of existing background-job code in this repo, and is empirically confirmed sufficient to kill the whole `sh -c "piper | play"` pipeline via ordinary process-group semantics that Neovim already provides for every job it spawns.
- Spawn the pipeline as `{"sh", "-c", "<piper cmd> | <play cmd>"}` (List form with explicit `sh -c`), not a bare string — matches the documented/idiomatic form (`jobstart(['bash', '-c', ...])` example in `:help job-control`) and keeps quoting explicit and auditable (`vim.fn.shellescape(model_path)`).
- Feed text via `chansend` + `chanclose(job_id, "stdin")`, not a temp file — simpler, no cleanup, verified reliable.
- Read sample rate from the model's `.onnx.json` sidecar at runtime rather than hardcoding, per the task's own forward-compatibility note.

## Risks & Mitigations

- **Risk**: if a future voice model lacks a matching `.json` sidecar, the sample-rate lookup silently falls back to 22050 (wrong rate → garbled/pitched audio). *Mitigation*: the fallback constant should match the currently-installed default voice (22050), and `M.health()` should surface a warning if the resolved model has no `.onnx.json`.
- **Risk**: if `play` is missing but `pw-play` is present (or vice versa), the hardcoded command would fail. *Mitigation*: check `vim.fn.executable("play")` first, fall back to the `pw-play` invocation, matching the task's documented equivalent command; surface a clear error via `M.health()` if neither exists.
- **Risk**: very large buffers produce very long piper stdin; piper synthesizes "up front" per the task brief (this is piper's own behavior, not something the nvim code controls) — no mitigation needed here, this is expected/accepted behavior per the task description.

## Context Extension Recommendations

- **Topic**: Neovim job-control process-group semantics for shell pipelines (`jobstart({"sh","-c","a|b"})` + `jobstop()` reliably kills the whole group).
  **Gap**: Not documented in `.claude/context/project/neovim/domain/neovim-api.md` or any existing context file; this is a non-obvious, easy-to-get-wrong pattern (the naive assumption is that only the shell PID gets signaled) that was resolved here only by direct empirical testing in a headless Neovim instance.
  **Recommendation**: Add a short pattern note to `.claude/context/project/neovim/domain/neovim-api.md` (or a new `patterns/job-pipeline.md`) documenting: (1) `jobstart` places spawned jobs in their own process group regardless of `detach`, (2) `jobstop` signals the whole group, (3) verification method (`ps -eo pid,ppid,pgid,cmd`) for future features that need to manage shell pipelines from Neovim job control.
- **Topic**: `piper` TTS is now a verified, working dependency in this environment (binary + voice model + playback pipeline), already used by `.claude/hooks/tts-notify.sh` for Claude Code lifecycle notifications via a different pipeline shape (`--output_file - | paplay`, WAV container) than the one this task uses (`--output_raw | play`, raw PCM with explicit format flags).
  **Gap**: `.claude/context/project/neovim/guides/tts-stt-integration.md` and `neovim-integration.md` exist already (found via grep) but were not read in depth here since they concern the Claude Code hook integration, not buffer-reading; worth a planner's cross-check to ensure no duplication/conflicting piper invocation conventions emerge between the two features.
  **Recommendation**: cross-reference `.claude/context/project/neovim/guides/tts-stt-integration.md` during planning to keep the two piper-consuming features (notification hook vs. buffer-reader) consistent in configuration variable naming (e.g. `PIPER_VOICE` env var convention used by the hook) if that seems valuable, though they are architecturally independent (one is a bash hook script, the other a Lua Neovim module) and do not need to share code.

## Appendix

### Search queries / commands used
- `grep -n "\"v\"\|<leader>v\|leader_v\|group.*v\b" lua/neotex/plugins/editor/which-key.lua`
- `grep -rn "vim.system(" lua/` (zero hits — confirms `jobstart`/`jobstop` is the sole convention)
- `grep -rn "jobstart" lua/` (STT, mail, himalaya, worktree, process-picker, sleep-inhibit, discord-link, oauth, neo-tree — all list-form or plain jobstart usage)
- `grep -rln "piper" /home/benjamin/.config/nvim` → found `.claude/hooks/tts-notify.sh` and related context docs/archived task reports
- Read `nvim --version` → 0.12.3
- Read Neovim runtime docs: `doc/job_control.txt`, `doc/vimfn.txt` (`jobstart()`/`jobstop()` entries), `doc/lua.txt` (`vim.system()`), `doc/luvref.txt` (`uv.spawn` `detached` option, `uv.kill`)
- Read `python3 -c "json.load(...onnx.json...)"` → confirmed `audio.sample_rate = 22050`

### Empirical experiments (headless `nvim --clean -u NONE`)
1. `jobstart({"sh","-c","sleep 100 | sleep 200"})` then `jobstop()` — before/after `ps -eo pid,ppid,pgid,cmd` snapshot confirmed shared process group and full teardown.
2. `jobstart({"sh","-c","cat | cat"})` + `chansend` + `chanclose(job,"stdin")` — confirmed stdin correctly reaches the first pipeline stage and both stages exit cleanly (code 0) once stdin closes.
3. Full production pipeline `piper -m <model> --output_raw -q | play -q -t raw -r 22050 -e signed -b 16 -c 1 -` spawned via `jobstart`, fed text via `chansend`/`chanclose` — completed with exit code 0 (Test 1, short text) and, with a long text, was `jobstop()`-ed mid-stream, producing `on_exit` code 143 and confirmed via `ps` that both `piper` and `play` processes (and the shell) were fully gone afterward.

### References
- `lua/neotex/plugins/tools/stt/init.lua` (primary process-management + toggle-state precedent)
- `lua/neotex/plugins/tools/stt-plugin.lua` (lazy.nvim wrapper precedent)
- `lua/neotex/plugins/tools/init.lua` (registration precedent, lines 87/122)
- `lua/neotex/bootstrap.lua:73-145` (explains why tools are loaded explicitly, not via lazy `import`)
- `lua/neotex/util/process.lua` (general process registry; `VimLeavePre` cleanup precedent at lines 559-569)
- `lua/neotex/util/sleep-inhibit.lua` (simple single-job module-local state precedent)
- `lua/neotex/plugins/editor/which-key.lua:804-813` (existing `<leader>v` voice group)
- `.claude/hooks/tts-notify.sh` (existing piper TTS usage in this repo, different pipeline shape)
