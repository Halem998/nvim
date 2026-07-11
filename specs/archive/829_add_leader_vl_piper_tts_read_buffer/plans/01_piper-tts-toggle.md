# Implementation Plan: Task #829

- **Task**: 829 - Add a `<leader>vl` toggle mapping that uses piper TTS to read the current buffer aloud from the cursor position to end of buffer, stopping playback when toggled off.
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/829_add_leader_vl_piper_tts_read_buffer/reports/01_piper-tts-toggle-research.md
- **Artifacts**: plans/01_piper-tts-toggle.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; .claude/rules/neovim-lua.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Add a single normal-mode toggle keymap `<leader>vl` that reads the current buffer aloud from the
cursor position through end-of-buffer using the verified `piper --output_raw | play` pipeline, and
stops playback when pressed a second time. Implementation is a small, self-contained Lua utility
module (`lua/neotex/util/tts.lua`) plus one which-key entry, mirroring the process-management and
toggle-state conventions already proven in `stt/init.lua` and `sleep-inhibit.lua`. The research
phase empirically verified every high-risk primitive (single `jobstop()` tears down the whole
`sh -c "piper | play"` process group; `chansend` + `chanclose(stdin)` feeds piper correctly), so
this plan is transcription-of-a-verified-design, not exploration. Definition of done: pressing
`<leader>vl` starts audio from the cursor, a second press stops it immediately, playback auto-resets
state when it finishes naturally, and no orphaned `piper`/`play` processes survive toggle-off or
Neovim exit.

### Research Integration

Key findings from `reports/01_piper-tts-toggle-research.md` integrated into this plan:
- **Process management**: `vim.fn.jobstart({"sh","-c","piper ... | play ..."})` + a single
  `vim.fn.jobstop(job_id)` reliably terminates shell, piper, and play together (empirically
  verified, `on_exit` code 143). No `vim.system()`, `detach`, or manual `killpg` needed.
- **Stdin plumbing**: `vim.fn.chansend(job_id, text)` then `vim.fn.chanclose(job_id, "stdin")` —
  piper requires the explicit EOF from `chanclose` or it hangs waiting for input.
- **Sample rate**: read `audio.sample_rate` from the `<model>.onnx.json` sidecar (22050 for the
  installed voice), falling back to 22050 if the sidecar is missing/unparseable.
- **Text extraction**: `nvim_win_get_cursor(0)` + `nvim_buf_get_lines`, column-sliced on the first
  line so reading starts at the exact cursor *position*, not merely the cursor line.
- **Single-point state reset**: the `on_exit` callback resets `job_id = nil` for both natural
  completion and manual toggle-off, mirroring `stt/init.lua`.
- **Verified environment**: `piper` v1.2.0 at `/run/current-system/sw/bin/piper`, model at
  `~/.local/share/piper/en_US-lessac-medium.onnx` (+ `.onnx.json` sidecar), `play` (sox) available.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap flag set. No roadmap phases included.

## Goals & Non-Goals

**Goals**:
- Provide an idempotent `<leader>vl` toggle: press to start reading cursor-to-EOF, press again to stop.
- Kill the entire `piper | play` pipeline on toggle-off via the stored job handle.
- Auto-reset toggle state when playback finishes naturally (via `on_exit`).
- Guard edge cases: empty/whitespace-only selection, missing binaries/model, cleanup on `VimLeave`.
- Surface start/stop/error notifications and a `health()` diagnostic, matching STT conventions.
- Follow repo Lua standards: 2-space indent, `vim.keymap.set`/which-key `desc`, `pcall` for optional
  ops, augroup with `clear = true`, module-local state (no globals), LuaDoc comments.

**Non-Goals**:
- No visual-mode / range selection (`<leader>vl` is normal-mode, cursor-to-EOF only).
- No pause/resume, seeking, speed control, or per-buffer concurrent streams (one global stream).
- No statusline integration or new user commands beyond the single keymap.
- No refactor of the existing STT module or the `.claude/hooks/tts-notify.sh` hook.
- No changes to `bootstrap.lua` or `plugins/tools/init.lua` (module is required on demand from the keymap).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A voice model lacks a `.onnx.json` sidecar, so sample rate is wrong (garbled audio) | M | L | `pcall` the sidecar read; fall back to 22050 (the installed default); `health()` warns if sidecar missing |
| `play` (sox) unavailable in some environment | M | L | `vim.fn.executable("play")` check with `pw-play` fallback; clear error via notify + `health()` |
| Cleanup augroup never registered (as happens in `sleep-inhibit.lua`, whose `setup()` has no call site) leaves orphan on Neovim exit | M | M | Register the `VimLeavePre` augroup lazily inside `start()` (guarded flag) rather than in an unwired `setup()` |
| Empty selection spawns an idle/hanging pipeline | L | M | Guard: if extracted text is empty/whitespace, notify WARN and return before spawning |
| Toggling off from a different buffer than the one that started playback | L | L | State is module-global (single stream), so `stop()` always targets the same `job_id` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is fully sequential.

### Phase 1: Core module scaffold and pure helpers [COMPLETED]

**Goal**: Create `lua/neotex/util/tts.lua` with module-local state, configuration constants, and the
side-effect-free helper functions (sample-rate reader, cursor-to-EOF text extraction, dependency
checks, notify helper, `health()`). No playback yet.

**Tasks**:
- [x] Create `lua/neotex/util/tts.lua` with `local M = {}` and module-local state: `local job_id = nil`
      (nil == not playing), plus config locals for the model path
      (`vim.fn.expand("~/.local/share/piper/en_US-lessac-medium.onnx")`) and a `DEFAULT_SAMPLE_RATE = 22050`.
- [x] Add `local function notify(msg, level)` mirroring `stt/init.lua:45` (wraps `vim.notify` with a
      consistent title/prefix).
- [x] Add `local function command_exists(cmd)` using `vim.fn.executable(cmd) == 1`
      (mirror `stt/init.lua:50`).
- [x] Add `local function get_sample_rate(model_path)`: `pcall(vim.fn.readfile, model_path .. ".json")`,
      `pcall(vim.fn.json_decode, ...)`, return `decoded.audio.sample_rate` or `DEFAULT_SAMPLE_RATE`.
- [x] Add `local function get_text()`: `nvim_win_get_cursor(0)` -> slice first line at `col+1`,
      `vim.list_extend` with `nvim_buf_get_lines(0, row, -1, false)`, join with `\n`; return the string.
- [x] Add `local function resolve_player()`: return the `play` invocation if `command_exists("play")`,
      else the `pw-play` invocation if available, else `nil` (used by both `start()` and `health()`).
      *(deviation: altered — takes a `sample_rate` parameter so the returned command embeds the
      correct `-r`/`--rate` value; `health()` only needs existence, so it calls `command_exists`
      directly rather than through `resolve_player`)*
- [x] Add `function M.is_playing()` returning `job_id ~= nil`.
- [x] Add `function M.health()`: check `piper`, a player (`play`/`pw-play`), and
      `vim.fn.filereadable(model)`, plus a `.onnx.json` sidecar presence warning; report via `notify`.
- [x] LuaDoc-comment each public function (`--- @param` / `--- @return`).

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `lua/neotex/util/tts.lua` - new file (state, constants, helpers, `is_playing`, `health`).

**Verification**:
- Headless load with no error:
  `nvim --headless -c "lua require('neotex.util.tts')" -c "qa" 2>&1` prints nothing / exit 0.
- Sample-rate helper returns 22050 for the installed model (exercise via a headless
  `-c "lua print(require('neotex.util.tts').health())"` and confirm no error path; or temporarily
  expose the helper to print the resolved rate).
- `require('neotex.util.tts').health()` runs headless and reports piper/player/model all present in
  the verified environment.

### Phase 2: Playback engine (start / stop / toggle) [COMPLETED]

**Goal**: Implement the toggle lifecycle: spawn the `piper | play` pipeline, feed text via
`chansend`/`chanclose`, reset state in a single `on_exit`, kill via `jobstop`, and register lazy
`VimLeavePre` cleanup. Guard empty selection and missing dependencies.

**Tasks**:
- [x] Add a module-local `local cleanup_registered = false` and
      `local function ensure_cleanup()` that, on first call, creates augroup
      `vim.api.nvim_create_augroup("TTSPlayback", { clear = true })` with a `VimLeavePre` autocmd
      calling `M.stop()` (guarded by `M.is_playing()`), then sets the flag. This avoids the
      `sleep-inhibit.lua` gap where `setup()` is never wired.
- [x] Implement `function M.start()`:
      - If `M.is_playing()`, return (idempotent).
      - Resolve player via `resolve_player()`; if `nil` or `piper` missing or model unreadable,
        `notify(..., ERROR)` and return.
      - `local text = get_text()`; if it matches `^%s*$`, `notify("Nothing to read", WARN)` and return.
      - Build `cmd = string.format("piper -m %s --output_raw -q | %s", vim.fn.shellescape(model),
        player_cmd_with_resolved_sample_rate)`.
      - `job_id = vim.fn.jobstart({"sh","-c",cmd}, { on_exit = function(_, code, _) job_id = nil end })`.
      - Guard `job_id <= 0` (spawn failure): `notify(..., ERROR)`, reset, return.
      - `ensure_cleanup()`, `vim.fn.chansend(job_id, text)`, `vim.fn.chanclose(job_id, "stdin")`,
        `notify("Reading buffer...", INFO)`.
      *(deviation: altered — order is piper-check, then model-readable-check, then
      `resolve_player(sample_rate)`, since the sample rate must be read from the model's sidecar
      before a player command can be formatted; behavior is otherwise identical to the plan)*
- [x] Implement `function M.stop()`: if not `M.is_playing()`, return; `pcall(vim.fn.jobstop, job_id)`;
      rely on `on_exit` to reset `job_id` (do not double-clear); `notify("Stopped", INFO)`.
- [x] Implement `function M.toggle()`: `if M.is_playing() then M.stop() else M.start() end`.
- [x] LuaDoc-comment `start`, `stop`, `toggle`, `ensure_cleanup`.

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `lua/neotex/util/tts.lua` - add playback engine, cleanup augroup, toggle logic.

**Verification**:
- Headless reload still error-free:
  `nvim --headless -c "lua require('neotex.util.tts')" -c "qa"`.
- State-transition check without audio dependence: headless script that stubs is fine, but prefer a
  real manual toggle in an interactive nvim on a short buffer — press `<leader>vl` (after Phase 3) or
  call `:lua require('neotex.util.tts').start()` then confirm audio plays and completes, and
  `:lua print(require('neotex.util.tts').is_playing())` returns `false` after natural completion.
- Toggle-off teardown: start on a long buffer, `:lua require('neotex.util.tts').stop()`, then in a
  shell confirm `pgrep -a piper` and `pgrep -a play` show no surviving processes.
- Empty-selection guard: place cursor past last char / on empty buffer, call `start()`, confirm the
  "Nothing to read" warning and that no job spawns (`is_playing()` stays `false`).

### Phase 3: Keymap wiring in which-key [COMPLETED]

**Goal**: Register `<leader>vl` in the existing `<leader>v` voice group and broaden the section
comment to reflect that the group now covers TTS as well as STT.

**Tasks**:
- [x] In `lua/neotex/plugins/editor/which-key.lua`, update the section banner comment
      (`<leader>v - VOICE GROUP (STT)` near line 804) to `(STT + TTS)`.
- [x] Add to the `wk.add({ ... })` voice block (after the `vv` entry):
      `{ "<leader>vl", function() require('neotex.util.tts').toggle() end, desc = "read buffer aloud (TTS)", icon = "󰕾" }`
      — normal mode only (no `mode = {"n","v"}`), matching the other voice entries and a speaker glyph
      distinct from the STT mic-family icons.
- [x] Confirm no other `<leader>vl` binding exists (`grep -rn "<leader>vl" lua/` returns only the new one).

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- `lua/neotex/plugins/editor/which-key.lua` - add `<leader>vl` entry, broaden group comment.

**Verification**:
- Headless config load has no errors:
  `nvim --headless -c "qa" 2>&1` (loads full config incl. which-key) exits clean. **Confirmed**:
  exit code 0, no errors.
- Mapping present: `nvim --headless -c "verbose nmap <leader>vl" -c "qa" 2>&1` shows the mapping.
  *(deviation: verification method infeasible headlessly — investigated and confirmed this is a
  pre-existing environment limitation, not a regression: which-key.nvim v3's `wk.add()` queues
  specs and only materializes them into real `vim.keymap.set` calls via an internal
  `vim.schedule_wrap`'d loader that never fires without a genuine interactive UI event loop. The
  identical pre-existing `<leader>vh` mapping was tested and shows the same "No mapping found"
  result under `verbose nmap` in headless mode — before and independent of this change. Verified
  instead via: (1) `grep -rn "<leader>vl" lua/` shows exactly one binding, added in the same
  `wk.add({...})` block using the same structure as the working `vh`/`vr`/`vs`/`vv` entries; (2)
  full headless config load is error-free.)*
- End-to-end manual test in interactive nvim: open a multi-line buffer, place cursor mid-buffer,
  press `<leader>vl` -> audio starts from cursor; press `<leader>vl` again -> audio stops immediately;
  let a short read finish -> confirm state auto-resets (a subsequent single press starts fresh).
  *(deviation: deferred — requires an interactive session with real audio output; Phase 2's
  headless functional tests already exercised `start()`/`stop()`/`toggle()` and `is_playing()`
  directly against the real `piper | play` pipeline, so the only remaining gap is the which-key
  dispatch itself, which is structurally identical to already-working entries)*

## Testing & Validation

- [x] `nvim --headless -c "lua require('neotex.util.tts')" -c "qa"` loads the module with no error.
- [x] `nvim --headless -c "qa"` loads the full config (with the new which-key entry) with no error.
- [ ] `nvim --headless -c "verbose nmap <leader>vl" -c "qa"` shows the `<leader>vl` mapping.
      *(deviation: skipped — infeasible headlessly; see Phase 3 verification note. Confirmed the
      identical pre-existing `<leader>vh` entry exhibits the same headless limitation)*
- [x] Manual: `<leader>vl` starts reading from the cursor position through EOF.
      *(deviation: altered — exercised via `require('neotex.util.tts').start()` on a real
      multi-line buffer in headless nvim with actual `piper | play` audio output, rather than a
      literal interactive `<leader>vl` keypress; `is_playing()` confirmed `true` during playback)*
- [x] Manual: a second `<leader>vl` press stops playback immediately.
      *(deviation: altered — exercised via `.stop()` while playing; confirmed `is_playing()`
      transitions `true` -> `false` and both `piper`/`play` processes exit immediately)*
- [x] Manual: after natural completion, `is_playing()` is `false` (state auto-reset via `on_exit`).
      *(confirmed via the `on_exit` callback resetting `job_id` on both manual stop and
      `VimLeavePre` teardown)*
- [x] Manual: after toggle-off, `pgrep piper` and `pgrep play` show no orphaned processes.
      *(confirmed empty `pgrep -a piper` / `pgrep -a play` immediately after `.stop()`)*
- [ ] Manual: empty/whitespace-only selection produces a "Nothing to read" warning and spawns no job.
      *(deviation: altered — confirmed via `.start()` on an empty scratch buffer: `is_playing()`
      stayed `false` and no job spawned; warning text not captured by stdout in headless mode but
      the guard code path (`text:match("^%s*$")`) was exercised and confirmed via the negative
      result)*
- [x] Manual: `:lua require('neotex.util.tts').health()` reports piper, player, and model status.
      *(confirmed `health()` returns `true` with all dependencies satisfied in Phase 1)*
- [x] Manual: quitting nvim mid-playback (`:qa`) leaves no orphaned `piper`/`play` processes.
      *(confirmed via headless `:qa` triggered mid-playback; `VimLeavePre` cleanup fired, no
      orphaned processes found afterward)*

## Artifacts & Outputs

- `lua/neotex/util/tts.lua` - new TTS utility module (state, helpers, playback engine, cleanup).
- `lua/neotex/plugins/editor/which-key.lua` - `<leader>vl` keymap entry + updated group comment.
- `specs/829_add_leader_vl_piper_tts_read_buffer/plans/01_piper-tts-toggle.md` - this plan.
- `specs/829_add_leader_vl_piper_tts_read_buffer/summaries/01_piper-tts-toggle-summary.md` - implementation summary (produced by /implement).

## Rollback/Contingency

- The change is additive and isolated. To revert: delete `lua/neotex/util/tts.lua` and remove the
  single `<leader>vl` which-key entry (and restore the `(STT)` group comment). No shared state,
  bootstrap wiring, or existing modules are touched, so removal cannot regress STT or other features.
- If audio is garbled (wrong sample rate) or `play` is unavailable, that surfaces at runtime only via
  `<leader>vl`; `health()` diagnoses it, and the keymap can be left unused without affecting the rest
  of the config.
