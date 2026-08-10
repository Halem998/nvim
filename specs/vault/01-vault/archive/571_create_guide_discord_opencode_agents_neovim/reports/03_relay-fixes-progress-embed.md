# Implementation Report: Relay Fixes and Progress Embed

**Task**: 571 - Discord + OpenCode + Neovim integration
**Date**: 2026-05-14
**Scope**: Fix event loop blocking, remove dedup guard, replace synchronous relay with async fire-and-forget, add delayed progress embed for long-running tasks, add SSE reconnection

---

## Problem

Five issues prevented the Discord relay from working reliably:

1. **Event loop starvation**: The bot's `_send_message_sync` used `urllib.request.urlopen(timeout=600)` in a `ThreadPoolExecutor(max_workers=4)`, which blocked the asyncio event loop via GIL contention. The Discord gateway heartbeat was stuck for 1800+ seconds — the bot could not receive messages, send responses, or maintain the WebSocket connection. Logs showed:
   ```
   Shard ID None heartbeat blocked for more than 1800 seconds.
   ```

2. **Dedup guard suppressed SSE responses**: While `_relay_and_respond` held a session ID in `_discord_relay_sessions` (for up to 600s waiting on the sync response), the SSE subscriber's `_post_response` method checked this set and silently dropped the assistant response to avoid duplicates. The result: neither path could deliver the response.

3. **No progress feedback**: Users typing commands like `/implement 574` in Discord got no feedback until the agent finished (minutes to hours later), making it impossible to tell if the task started or stalled.

4. **Noisy embeds for short exchanges**: The initial fix posted a yellow "Processing..." embed immediately on every message, even quick exchanges like "hi" → "Hello! How can I help you?" (5 seconds). The embed stayed yellow because the response completed before the embed was created (timing race: `_finalize_embed` found `_status_msg=None`).

5. **Local OpenCode conversations not relayed**: When the user typed directly in the OpenCode TUI (not via Discord), responses did not appear in the linked Discord thread. The SSE subscriber had no reconnection logic — when the SSE connection dropped (TUI restart, timeout, network hiccup), the subscriber died silently and never recovered.

## Root Cause

The original architecture used a dual-path response model:
- **Path A**: `_relay_and_respond` → synchronous `urlopen` POST → wait for full response body → post to Discord
- **Path B**: SSE subscriber → stream events → post completed messages to Discord

A dedup guard (`_discord_relay_sessions` set) prevented Path B from posting while Path A was active. But Path A's blocking call starved the event loop, so neither path could post to Discord.

The initial fix (v1) replaced Path A with async fire-and-forget and removed the dedup guard, but introduced two new problems: eager embed creation on every message (noisy for short exchanges) and no SSE reconnection (subscriber death was silent and permanent).

## Changes Made

### Round 1: Core relay fix

#### 1. `opencode_client.py` — Fully async message sending

Replaced the blocking `ThreadPoolExecutor` + `urllib.request.urlopen` approach with a native `aiohttp` async POST. The method now returns immediately after OpenCode accepts the message (30s timeout) instead of waiting up to 600s for the response body.

**Before** (blocking, event loop starving):
```python
async def send_message(self, session_id, text):
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(
        self._executor, self._send_message_sync, session_id, text
    )

def _send_message_sync(self, session_id, text):
    with urlopen(req, timeout=600) as resp:
        return json.loads(resp.read())
```

**After** (non-blocking, fire-and-forget):
```python
async def send_message(self, session_id, text):
    session = self._get_session()
    url = f"{self._base_url}/session/{session_id}/message"
    async with session.post(url, json=payload, timeout=aiohttp.ClientTimeout(total=30)) as resp:
        resp.raise_for_status()
```

Removed imports: `ThreadPoolExecutor`, `urllib.request`, `urllib.error`, `base64`.

#### 2. `sse_subscriber.py` — Removed dedup guard

The `_discord_relay_sessions` check in `_post_response` was deleted. Since responses now flow exclusively through the SSE subscriber, there is no dual-path race to guard against.

#### 3. `bot.py` — Simplified relay

`_relay_and_respond` simplified to fire-and-forget — sends the POST only. `_discord_relay_sessions` set removed. Unused imports removed (`aiohttp`, `relay_response_to_thread`).

### Round 2: Delayed embed and reconnection

After testing round 1 in production, two follow-up issues were identified and fixed:

#### 4. `sse_subscriber.py` — Delayed status embed (10s threshold)

Instead of posting a yellow embed immediately on every message, the SSE subscriber now uses a delayed timer:

- When the first `message.part.updated` event arrives for a new message, a 10-second timer starts via `asyncio.create_task(_delayed_embed())`
- If the response completes before the timer fires (short exchange), the timer is cancelled — only the response text is posted, no embed
- If the timer fires (long-running task), the yellow "Processing..." embed appears and gets progress updates every 15 seconds
- On completion, `_finalize_embed` turns the embed green and resets `_status_msg = None` for a clean lifecycle on subsequent messages

This approach is based on research into Discord bot best practices (Midjourney pattern: single embed edited in-place). The 10-second threshold eliminates visual noise for quick exchanges while providing clear progress feedback for long tasks.

Key implementation details:
- `_schedule_embed(thread)`: starts the delayed timer, stores thread reference
- `_delayed_embed()`: async task that sleeps 10s then posts the embed
- `_cancel_embed_timer()`: cancels the timer on completion or stop
- `_finalize_embed()`: also cancels the timer (handles race where completion arrives just before timer fires)
- `_status_msg` reset to `None` after finalization, allowing fresh embed per message

Embed colour scheme:
- `0xFFC107` (yellow/amber) — Processing
- `0x4CAF50` (green) — Completed
- `0xF44336` (red) — Error

The embed fields are:
- **Status**: "Processing..." / "Completed" / "Error"
- **Started**: Discord relative timestamp (`<t:UNIX:R>`, auto-updates client-side)
- **Latest activity**: Code block with the last 300 chars of streaming output (only during processing)
- **Footer**: Session ID (truncated to 12 chars)

#### 5. `sse_subscriber.py` — SSE reconnection with exponential backoff

The `_run` method is wrapped in `_run_with_reconnect` — a `while self._running` loop:

```python
async def _run_with_reconnect(self):
    backoff = RECONNECT_BASE  # 2s
    while self._running:
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url) as response:
                    backoff = RECONNECT_BASE  # reset on success
                    await self._process_stream(response.content)
        except (aiohttp.ClientConnectorError, Exception):
            ...
        await asyncio.sleep(backoff)
        backoff = min(backoff * 2, RECONNECT_MAX)  # cap at 60s
```

This fixes the critical issue where conversations typed directly in the OpenCode TUI did not appear in Discord — the subscriber died on first connection drop and never recovered. Now it reconnects automatically, logging each reconnection attempt.

#### 6. `bot.py` — Removed eager embed, simplified further

- Removed `send_status_embed` call from `_relay_and_respond` (subscriber handles all embed logic autonomously)
- Removed `_get_sse_subscriber` helper (no longer needed)
- `_sse_subscriber_instances` dict retained for subscriber cleanup in `stop_sse_subscriber` and `close`
- `_relay_and_respond` is now purely: POST message → catch errors → done

## Architecture After Changes

```
Discord User types in thread             User types in OpenCode TUI
  |                                         |
  v                                         v
on_message -> _relay_and_respond          TUI processes locally
  |                                         |
  | async POST (fire-and-forget)            |
  v                                         |
OpenCode TUI processes message              |
  |                                         |
  v                                         v
TUI emits SSE events on /event endpoint
  |
  v
SSE subscriber (persistent connection with auto-reconnect):
  ├── message.part.updated:
  |     ├── First chunk: schedule embed timer (10s delay)
  |     └── Subsequent: throttled progress edit (15s interval)
  ├── message.updated (completed):
  |     ├── Cancel embed timer (if still pending)
  |     ├── Finalize embed green (if it was posted)
  |     └── Post full response text to Discord
  └── session.idle:
        └── Same as message.updated (fallback flush)
```

Both Discord-originated and TUI-originated messages are captured by the same SSE subscriber. The subscriber runs for the lifetime of the linked session, reconnecting automatically on connection loss.

## Response Flow Comparison

| Aspect | Original | Round 1 | Round 2 (final) |
|--------|----------|---------|-----------------|
| Message sending | Blocking 600s via ThreadPoolExecutor | Async 30s via aiohttp | Async 30s via aiohttp |
| Response delivery | Dual path with dedup guard | Single path (SSE) | Single path (SSE) |
| Event loop impact | Starved (heartbeat blocked 1800s+) | Non-blocking | Non-blocking |
| User feedback | None until completion | Immediate embed on every message | Delayed embed (10s) only for long tasks |
| Short exchanges | Silent, then response | Yellow embed + response (noisy) | Response text only (no embed) |
| SSE connection loss | Subscriber dies silently | Subscriber dies silently | Auto-reconnect with backoff (2s→60s) |
| Local TUI conversations | Not relayed after first drop | Not relayed after first drop | Always relayed (reconnection) |
| Embed lifecycle | N/A | Stale yellow embeds on fast responses | Clean reset per message |

## Files Modified

| File | Round 1 Changes | Round 2 Changes |
|------|-----------------|-----------------|
| `opencode_client.py` | Replaced sync+ThreadPoolExecutor with async aiohttp POST | (no further changes) |
| `sse_subscriber.py` | Removed dedup guard; added `send_status_embed`, `_update_progress`, `_finalize_embed`, `_resolve_thread` | Replaced eager `send_status_embed` with delayed `_schedule_embed`/`_delayed_embed`; added `_run_with_reconnect` with backoff; reset `_status_msg` after finalization; added `_cancel_embed_timer` |
| `bot.py` | Simplified relay to fire-and-forget; removed `_discord_relay_sessions`; added `_sse_subscriber_instances` + `_get_sse_subscriber` | Removed `_get_sse_subscriber`; removed `send_status_embed` call from relay; relay is now purely POST + error handling |

## Impact on Guide (Task 571)

The existing plan at `plans/01_discord-opencode-guide.md` should be updated to reflect:

1. **Architecture section**: The response path is single-direction through the SSE subscriber with auto-reconnect, not dual-path. The `_send_message_sync` / `ThreadPoolExecutor` approach no longer exists. Both Discord-originated and TUI-originated messages are relayed.

2. **Heartbeat blocking (troubleshooting correction)**: The plan's Phase 1 troubleshooting item says heartbeat warnings "are normal during long AI operations and do not indicate a problem; the thread pool executor prevents them from blocking the bot." This should be updated — the fully async approach eliminates event loop blocking entirely, so heartbeat warnings should no longer appear at all.

3. **New feature to document — progress embed**: The guide should explain:
   - For **short exchanges** (< 10 seconds): only the response text is posted, no embed
   - For **long-running tasks** (> 10 seconds): a yellow status embed appears with a live "Started X ago" timestamp, updates every ~15 seconds with latest activity, and turns green on completion
   - The full response text is always posted below the embed (or standalone for short exchanges)

4. **Bidirectional relay**: The guide should document that conversations typed directly in the OpenCode TUI also appear in the linked Discord thread — not just Discord-to-OpenCode messages.

5. **SSE reconnection**: The guide should note that the bot automatically reconnects to the TUI's event stream if the connection drops (e.g., TUI restart). The user does not need to re-link with `<leader>ar` unless the TUI port changes (which happens on Neovim restart).

6. **Troubleshooting updates**:
   - Remove "Embed stays yellow indefinitely" as a common issue — the delayed embed + reconnection should prevent this
   - Add "Responses stop appearing in Discord": check if the TUI is still running on the same port; if the port changed (Neovim restart), re-link with `<leader>ar`
   - Add "No embed for long task": the SSE subscriber may have failed to connect; check `journalctl -u discord-bot` for reconnection logs

## Verification

After restarting `discord-bot.service`:

**Short exchange test:**
- Send "hi" in a linked Discord thread
- Response text appears directly (e.g., "Hello! How can I help you?")
- No yellow status embed
- No heartbeat blocking warnings in `journalctl -u discord-bot`

**Long task test:**
- Send `/implement N` in a linked Discord thread
- No embed for ~10 seconds (response text is being accumulated)
- After 10 seconds: yellow "Processing..." embed appears with live timestamp
- Embed updates with activity snippets every ~15 seconds
- On completion: embed turns green, full response posted below
- No heartbeat blocking warnings

**TUI-originated test:**
- Type a message directly in the OpenCode TUI
- Response appears in the linked Discord thread
- No status embed (unless response takes >10 seconds)

**Reconnection test:**
- Restart the OpenCode TUI (`opencode --port`)
- Wait for reconnection log in `journalctl -u discord-bot`
- Send a message — response should appear in Discord
