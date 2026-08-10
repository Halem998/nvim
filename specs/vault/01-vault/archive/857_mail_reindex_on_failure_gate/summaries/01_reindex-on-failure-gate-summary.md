# Implementation Summary: Task #857

**Completed**: 2026-07-13
**Duration**: ~15 minutes
**Plan**: plans/01_reindex-on-failure-gate.md (both phases [COMPLETED])

## Overview

`sync_all_mail()` in `lua/neotex/plugins/tools/mail.lua` previously ran `notmuch new` only
when `mbsync -a` exited 0, so mailboxes that fully synced before an aborted run were
invisible to the `<leader>me` gate's census fallback. The fix extracts a file-local helper
`run_notmuch_new(cb)` and chains it in BOTH branches of the mbsync `on_exit`, so the census
fallback always evaluates a post-reindex notmuch database while `on_done(false)` is still
reported on any mbsync failure. Gate semantics are untouched.

## What Changed

- `lua/neotex/plugins/tools/mail.lua` (single-file edit, two regions):
  - Added `run_notmuch_new(cb)` — 8-line file-local helper wrapping the async
    `notmuch new` jobstart; the notmuch jobstart nest now appears exactly once in the file.
  - Rewrote `sync_all_mail(on_done)`:
    - Success branch: chained through `run_notmuch_new`; behavior unchanged
      (`on_done(indexed)`, INFO/ERROR notifications preserved).
    - Failure branch (the fix): notifies "mbsync failed with code N -- reindexing notmuch
      anyway" (ERROR), runs `run_notmuch_new`, then notifies "notmuch index refreshed
      (mbsync still failed -- sync is not clean)" (WARN) or "notmuch indexing failed after
      mbsync failure" (ERROR), and calls `on_done(false)` INSIDE the notmuch `on_exit` —
      hard-coded `false` regardless of reindex outcome (never fail-open).
  - Added rationale comment on `sync_all_mail` explaining the both-branch reindex.
  - Fixed header-comment drift: `<leader>mS` -> `<leader>mN`.
  - Extended `census_freshness_ok` header comment: freshness signal quality is owned
    externally by ~/.dotfiles modules/home/email/agent-tools/census.nix
    (count-with-tolerance proxy; dotfiles-side follow-up). Function body unchanged.

## Decisions

- Followed the plan's exact before/after code verbatim (research-provided replacement).
- Manual smoke test documented as the acceptance procedure rather than performed: forcing
  an mbsync failure requires disconnecting the network or pointing at an unreachable IMAP
  host, which is out of scope for a headless autonomous run and the plan explicitly allows
  documenting instead.

## Plan Deviations

- **Phase 2 smoke-test item** altered: documented as acceptance procedure, not executed
  (see Decisions above). All other items executed exactly as planned.

## Verification

- Headless load check: `nvim --headless -c "luafile lua/neotex/plugins/tools/mail.lua"
  -c "qa"` exited 0 with no error output (`luacheck` not on PATH).
- Static callback-contract checklist (all pass):
  - Success branch: `on_done(indexed)` fires only inside the notmuch `on_exit`; true only
    when both mbsync and notmuch exited 0.
  - Failure branch: `on_done(false)` fires only inside the notmuch `on_exit` callback,
    hard-coded `false` — never before the reindex, never `true`.
  - Both `on_done` calls nil-guarded; `<leader>mN` (callback-less call site) safe.
- `git diff` confined to the two planned regions; gate block (~lines 106-140) and both
  keymap specs byte-identical to before.
- No task-number references in mail.lua (grep for task-number patterns: no matches);
  census.nix cited by durable path only.

## Constraint Confirmation

- Real code edit performed (not analysis-only).
- census.nix, .mbsyncrc, ~/Mail, and the gate logic untouched.
- 2-space indent, all lines under ~100 columns, local functions, existing vim.notify
  levels/style preserved.
- `sync_all_mail(on_done)` public callback contract preserved for both call sites
  (`<leader>me` with callback, `<leader>mN` without).

## Notes

Acceptance procedure for the failure path (when convenient): simulate an mbsync failure
non-destructively (disconnect network), press `<leader>me`, expect
INFO -> ERROR ("reindexing notmuch anyway") -> WARN ("sync is not clean") -> gate census
fallback; the gate must never open directly from the failure branch. Restore network and
retry to confirm the unchanged success path.
