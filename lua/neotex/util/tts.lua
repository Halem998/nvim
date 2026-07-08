-- Text-to-Speech (TTS) playback via Piper
--
-- Reads the current buffer aloud from the cursor position through end-of-buffer using
-- Piper (offline neural TTS) piped into a system audio player. Provides a single toggle:
-- press to start reading from the cursor, press again to stop immediately.
--
-- Requirements:
--   - piper (offline TTS engine)
--   - a voice model (.onnx) with a matching .onnx.json sidecar (for sample rate)
--   - play (sox) or pw-play (PipeWire) for audio playback
--
-- Usage:
--   <leader>vl - Toggle reading the buffer aloud from the cursor (which-key)
--
-- Configuration (optional):
--   vim.g.tts_model_path = "~/.local/share/piper/en_US-lessac-medium.onnx"

local M = {}

-- Module state
local job_id = nil -- nil == not playing
local cleanup_registered = false

-- Configuration
local DEFAULT_SAMPLE_RATE = 22050
local DEFAULT_MODEL_PATH = vim.fn.expand("~/.local/share/piper/en_US-lessac-medium.onnx")

local function get_model_path()
  return vim.g.tts_model_path and vim.fn.expand(vim.g.tts_model_path) or DEFAULT_MODEL_PATH
end

local function notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify("[TTS] " .. msg, level)
end

local function command_exists(cmd)
  return vim.fn.executable(cmd) == 1
end

--- Read the sample rate from a Piper voice model's `.onnx.json` sidecar.
---
--- Falls back to DEFAULT_SAMPLE_RATE (22050) when the sidecar is missing or unparseable.
---
--- @param model_path string Absolute path to the `.onnx` voice model
--- @return number sample_rate Sample rate in Hz
local function get_sample_rate(model_path)
  local ok_read, lines = pcall(vim.fn.readfile, model_path .. ".json")
  if not ok_read or not lines then
    return DEFAULT_SAMPLE_RATE
  end

  local ok_decode, decoded = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
  if not ok_decode or type(decoded) ~= "table" then
    return DEFAULT_SAMPLE_RATE
  end

  local audio = decoded.audio
  if type(audio) == "table" and type(audio.sample_rate) == "number" then
    return audio.sample_rate
  end

  return DEFAULT_SAMPLE_RATE
end

--- Extract buffer text from the cursor position through end-of-buffer.
---
--- The first line is column-sliced so reading starts at the exact cursor column, not
--- merely the cursor line.
---
--- @return string text Newline-joined text from cursor to end of buffer
local function get_text()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]

  local first_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  local lines = { first_line:sub(col + 1) }

  local rest = vim.api.nvim_buf_get_lines(0, row, -1, false)
  vim.list_extend(lines, rest)

  return table.concat(lines, "\n")
end

--- Resolve the audio player invocation for the given sample rate.
---
--- Prefers `play` (sox); falls back to `pw-play` (PipeWire) if `play` is unavailable.
---
--- @param sample_rate number Sample rate in Hz to configure the player for
--- @return string|nil player_cmd Shell command fragment for the resolved player, or nil
--- if no supported player is installed
local function resolve_player(sample_rate)
  if command_exists("play") then
    return string.format("play -q -t raw -r %d -e signed -b 16 -c 1 -", sample_rate)
  elseif command_exists("pw-play") then
    return string.format("pw-play --raw --rate=%d --format=s16 --channels=1 -", sample_rate)
  end
  return nil
end

--- Check whether audio is currently playing.
---
--- @return boolean playing True if a playback job is active
function M.is_playing()
  return job_id ~= nil
end

--- Run TTS dependency diagnostics.
---
--- Checks for `piper`, an audio player (`play`/`pw-play`), the configured voice model, and
--- its `.onnx.json` sidecar. Reports each finding via `notify`.
---
--- @return boolean ok True if all required dependencies are satisfied
function M.health()
  local model_path = get_model_path()
  local issues = {}

  if not command_exists("piper") then
    table.insert(issues, "piper not found on PATH")
  end

  if not (command_exists("play") or command_exists("pw-play")) then
    table.insert(issues, "no audio player found (install sox for `play` or use PipeWire `pw-play`)")
  end

  if vim.fn.filereadable(model_path) ~= 1 then
    table.insert(issues, "voice model not found at " .. model_path)
  elseif vim.fn.filereadable(model_path .. ".json") ~= 1 then
    table.insert(issues, "voice model sidecar not found at " .. model_path .. ".json "
      .. "(falling back to " .. DEFAULT_SAMPLE_RATE .. "Hz)")
  end

  if #issues == 0 then
    notify("All dependencies satisfied!", vim.log.levels.INFO)
    return true
  else
    for _, issue in ipairs(issues) do
      notify("Issue: " .. issue, vim.log.levels.ERROR)
    end
    return false
  end
end

return M
