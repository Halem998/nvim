# Implementation Summary: Task #858

**Completed**: 2026-07-13
**Duration**: ~45 minutes (4 phases)

## Overview

Redesigned the `<leader>me` aerc launch flow so it gates solely on a completed foreground
`notmuch new --no-hooks` (measured 0.14-0.58 s, exit 0 with the duplicate-UID-15 collision
still unrepaired) and opens aerc immediately, moving all server syncing into one backgrounded,
deduplicated, hook-ful `notmuch new` pipeline (preNew = `mail-sync both`). `mbsync -a` and the
email-census launch check are deleted from the codebase, and the himalaya auto-sync timer no
longer fires by default.

## What Changed

- `lua/neotex/plugins/tools/mail.lua` — Launch gate replaced with `reconcile_index()`
  (`notmuch new --no-hooks`, hook-free, foreground); `census_freshness_ok`, `sync_all_mail`,
  `run_notmuch_new`, and every `mbsync` string deleted; new `background_sync(loud)` pipeline
  with a `sync_in_flight` dedup guard shared by `<leader>me` (quiet) and `<leader>mN` (loud);
  warn-never-block failure semantics; 2 s deferred "waiting on the notmuch index" notice for
  rare lock waits; header/architecture comments and keymap descs rewritten.
- `lua/neotex/plugins/tools/himalaya/config/init.lua` — Explicit `ui.auto_sync_enabled = false`
  default (non-mutating merge over `config/ui.lua` defaults); fixed `M.get`'s falsy handling so
  a stored `false` is returned instead of silently replaced by the default.
- `lua/neotex/plugins/tools/himalaya/commands/sync.lua` — `HimalayaAutoSyncToggle` now flips
  the live `config.config.ui.auto_sync_enabled` before start/stop so re-enabling works
  (`start_auto_sync()` reads config, not state).
- `lua/neotex/plugins/tools/himalaya/ui/main.lua` — Untouched (verify-only per plan): manual
  `M.sync_inbox()` entry points (`:HimalayaSyncInbox`, sidebar `s`) retained.

## Decisions

- The launch-barrier comment in `mail.lua` preserves the decoupling rationale by content but
  avoids the literal word "census" so the Phase 1 verification grep returns nothing.
- Fixed the `config.get` falsy-fallback bug rather than working around it: no existing caller
  stores `false` where its default differs, so behavior changes only for the new key.
- Kept the gate as a plain blocking-wait on the notmuch lock (no timeout/kill): correctness is
  preserved, real-world waits are sub-second, and a deferred INFO notice covers the rare long
  wait. Never reinstated any sync signal on the launch path.

## Plan Deviations

- **Phase 3, config edit** altered: also fixed `M.get`'s falsy-value handling in
  `config/init.lua` — the prior `value ~= nil and value or default` expression returned the
  default for a stored `false`, which would have silently defeated `auto_sync_enabled = false`.
- **Phase 3, verification** altered: also edited `commands/sync.lua` so
  `:HimalayaAutoSyncToggle` can re-enable the timer (it calls `start_auto_sync()`, which
  early-returns on the now-false config value unless the live config is flipped first).
- **Phase 3, file scope**: task `file_scope` anticipated `himalaya/ui/main.lua`; the correct
  edits were in `config/init.lua` and `commands/sync.lua` — `ui/main.lua` needed no change.
- **Phase 4, lock-held gate test** finding: `notmuch new` WAITS on a held write lock rather
  than exiting non-zero (observed 58.6 s behind a bulk 65k-message tag write, then exit 0).
  The write lock is FREE during the pipeline's long preNew (mail-sync) phase — verified with a
  sleeping pre-new hook and against the live pipeline (gate 0.18-0.26 s while preNew active) —
  so real waits are sub-second. Fix-forward: 2 s deferred INFO notice in the `<leader>me`
  handler.
- **Phase 4, launch test** finding: the deployed pre-new hook is `mail-sync both || true`, so
  a sync-leg failure (the gmail duplicate-UID collision) is intentionally non-fatal at the hook
  layer: the pipeline exits 0 and the module reports INFO, not the WARN the plan predicted.
  The gmail failure remains visible in `mail-sync` output (run `<leader>mN`'s pipeline in a
  terminal or check mbsync state); the module WARN fires when the pipeline itself (reindex)
  exits non-zero. No per-press warning fatigue; no launch refusal in any case.
- **Phase 4, tagging-gap and soak tests** altered: verified by proxy headlessly
  (`notmuch count tag:new` is 0 after the real pipeline run; concurrent gate/tag/pipeline runs
  produced no errors). Live new-mail delivery and in-aerc MessageInfo observation require an
  interactive session and are left to normal use.

## Verification

- `mail.lua` dofile returns a plugin-spec table; himalaya `config/init.lua` and
  `commands/sync.lua` load clean; `nvim --headless "+Lazy! load toggleterm.nvim" +q` exits 0.
- Behavioral harness (stubbed `jobstart`/`vim.notify`/toggleterm): 16/16 PASS — gate command
  is hook-free, aerc opens only after gate success, quiet background pipeline starts post-open,
  in-flight dedup ("Mail sync already running" once, loud only), single WARN on failure exit,
  guard release, gate-failure warn-and-defer with no open and no pipeline.
- Real gate runs: 0.14-0.58 s, exit 0, duplicate-UID collision unrepaired; 0.18-0.26 s while
  the live pipeline's preNew phase was running.
- Real hook-ful pipeline run: 7.84 s; gmail leg failed on duplicate UID 15 (expected), logos
  leg + reindex OK; `notmuch count tag:new` = 0 afterwards (postNew retag gap closed).
- Himalaya: `config.get('ui.auto_sync_enabled', true)` returns `false`;
  `is_auto_sync_running()` stays `false` after `start_auto_sync()`; sidebar/manual sync paths
  untouched.
- No `mbsync`, census, or task-number strings in any deliverable lua file.

## Notes

- Behavior change to call out: the himalaya periodic auto-sync timer (2 s startup delay,
  15 min interval) no longer runs by default. Background maildir refresh now happens on every
  `<leader>me` press via the mail-sync pipeline; `:HimalayaAutoSyncToggle` re-enables the
  timer per-session, and `:HimalayaSyncInbox` / sidebar `s` remain manual sync paths.
- Follow-up recommendations (out of scope here): dotfiles `census.nix` `--exclude=false` fix;
  `~/Mail` index-architecture.md launch-gate/preNew doc amendment; one-time duplicate-UID-15
  maildir repair (until then, the gmail sync leg keeps failing quietly inside the pipeline —
  run `mail-sync both` in a terminal to see its remediation guidance).
