# Task 576: Fix OpenCode Session Picker Restore/Browse Options

- **Effort**: 2-4 hours (depending on root cause)
- **Status**: [NOT STARTED]
- **Task Type**: neovim
- **Dependencies**: 575 (audit failure modes)

## Description

Fix the "Restore last session" and "Browse all sessions" options in the OpenCode session picker (`<C-CR>` -> OpenCode) based on the root cause identified in task 575.

### Scope

The fix targets `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`, specifically the `show_opencode_session_picker()` function and its `attach_mappings` callback. Depending on the root cause found in 575, the fix may involve:

- Adjusting the timing/sequencing of `toggle()` and subsequent API calls
- Modifying the `snacks.terminal` server integration (start/toggle functions in `opencode.lua`)
- Adding explicit port configuration for reliable server discovery
- Adding wait/retry logic for server-ready detection before session API calls
- Adding better error messages and fallback behaviors
- Potentially replacing the Promise chain with an event-driven approach using `OpencodeEvent:server.connected`

### Key Files to Modify

- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` — Primary target (session picker logic)
- `lua/neotex/plugins/ai/opencode.lua` — May need server config adjustments

### Success Criteria

- [ ] Selecting "Restore last session" from the OpenCode session picker restores the previous session within 10 seconds
- [ ] Selecting "Browse all sessions" from the OpenCode session picker shows the session browser within 10 seconds
- [ ] "Create new session" continues to work (no regression)
- [ ] Cold-start scenario (no running server) works reliably
- [ ] Warm-start scenario (server already running) works reliably
- [ ] Clear error notifications appear when the server fails to start or connect
