# Implementation Plan: Fast, responsive, non-failing `<leader>me` aerc launch

- **Task**: 858 - Fast, responsive, non-failing `<leader>me` aerc launch
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**:
  - specs/858_mail_launch_gate_performance/reports/02_hard-research-fast-responsive-launch.md (authoritative)
  - specs/858_mail_launch_gate_performance/reports/01_launch-gate-performance-diagnosis.md (seed)
- **Artifacts**: plans/02_fast-responsive-aerc-launch.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

`<leader>me` currently serializes two full server syncs (`mbsync -a`, then -- via the preNew
hook of hook-ful `notmuch new` -- `mail-sync both`) on the launch-blocking critical path, then
refuses to open aerc because both gate arms are permanently red: the primary arm requires
`mbsync -a` exit 0 (impossible while the duplicate-UID-15 collision persists) and the census
fallback is false-`[STALE]` by construction. The redesign (report 02 §5) gates the launch on
exactly what aerc needs -- a completed foreground `notmuch new --no-hooks` (measured 0.194 s) --
opens aerc immediately, and moves all server syncing into one backgrounded, deduplicated,
hook-ful `notmuch new` pipeline (preNew = `mail-sync both`, the canonical single choke point)
that warns on failure but never blocks. `mbsync -a` and the census launch check are deleted.
Definition of done: with the duplicate-UID collision still unrepaired, `<leader>me` opens aerc
in sub-second time, background sync failures surface as warnings only, `<leader>mN` performs the
explicit full sync through the same pipeline, and repeated presses do not stack sync processes.

### Research Integration

From report 02 (all grounded at file:line, adversarially verified):

- Gate on index reconciliation only: foreground `notmuch new --no-hooks` to completion before
  `open_aerc()` satisfies the read-safety contract (index-architecture.md Synchronous/Locked/
  Uninterruptible barrier) without any mbsync in the path (§4.4, §5.3).
- Never branch launch on mbsync exit code or census: both arms can be (and currently are)
  permanently wedged by faults orthogonal to read-safety (§3, §4.5).
- Single background pipeline: hook-ful `notmuch new` IS the sync pipeline (preNew =
  `mail-sync both`, flock-serialized, terminates at depth 1, postNew retags `tag:new` files),
  deduplicated caller-side with an in-flight guard (§5.2).
- `mbsync -a` is the forbidden form (fires `logos-labels` and the 64k `gmail-all` channel);
  delete it from the codebase (§5.1).
- himalaya's "Starting sync for inbox" is NOT triggered by `<leader>me`; it is an independent
  auto-sync timer (2 s startup delay, 15 min interval, enabled by default via
  `config.get('ui.auto_sync_enabled', true)` at `himalaya/sync/manager.lua:320`) that contends
  for the same mbsync channels under a disjoint lock namespace. Suppressing it is a
  contention-noise reduction, not a correctness requirement (§1.1, §5.4).
- `--no-hooks` tagging caveat: files first indexed by the gate carry only `tag:new` until the
  background hook-ful pass retags them; safety-neutral, closed by the post-open pipeline (§4.4).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- `<leader>me` opens aerc promptly (~0.2-0.3 s gate) on a cheaply-reconciled index, even while
  the duplicate-UID collision remains unrepaired.
- Launch is fully decoupled from mbsync exit codes and from `email-census`: sync failures warn,
  never block.
- One sync path: all server syncing routes through the `mail-sync` wrapper (via the hook-ful
  `notmuch new` pipeline); `mbsync -a` is removed from this codebase entirely.
- Background pipeline is deduplicated (in-flight guard); `<leader>mN` keeps the explicit full
  sync, loud, through the same pipeline.
- himalaya auto-sync timer no longer fires by default, removing the third concurrent sync layer
  contending for mbsync channels (manual himalaya sync paths retained).
- Read-safety preserved: the foreground reconcile completes before aerc opens (no return of
  "could not get MessageInfo" races).

**Non-Goals**:
- The one-time duplicate-UID-15 maildir data repair (manual data op, orthogonal).
- Fixing `census.nix`'s exclude-tags false-STALE (dotfiles repo; companion follow-up, and
  census is removed from the launch path so it is non-blocking here).
- Amending `~/Mail/.claude/context/project/email/domain/index-architecture.md` (out-of-repo
  follow-up; flagged in report 02 §5.3).
- Routing the himalaya plugin's own sync machinery through `mail-sync` (larger refactor; only
  the default-on auto-sync timer is addressed).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| notmuch DB write-locked at press time makes the gate `notmuch new --no-hooks` exit non-zero | M | L | Fail fast with a "retry <leader>me in a moment" warning; self-healing once the other writer finishes. Confirm the non-zero-exit (vs hang) behavior during Phase 4 testing (report 02 §6.5) |
| `--no-hooks` gate indexes new files with only `tag:new`, so they miss aerc's `tag:inbox` INBOX view until retagged | L | M | Background hook-ful `notmuch new` runs immediately after open; its postNew retags by `tag:new` regardless of which run indexed the files (report 02 §4.4) |
| aerc reading during the background reindex | M | L | notmuch/Xapian single-writer/multi-reader semantics plus the sanctioned in-client `$` sync precedent (index-architecture.md); optional soak test in Phase 4 |
| Disabling himalaya auto-sync changes sidebar freshness expectations | L | M | Manual sync paths retained (`:HimalayaSyncInbox`, sidebar `s`); background pipeline still refreshes the maildir on every `<leader>me`. Call out the behavior change in the implementation summary |
| Background sync failure warning fires on every press while duplicate-UID persists (notification fatigue) | L | M | Warning is a single WARN per pipeline run, gated by the in-flight guard; message names the remediation (`<leader>mN`, `mail-sync` output) |
| Module left in a broken intermediate state between phases | M | L | Each phase ends with `mail.lua` loadable and both keymaps functional (Phase 1 keeps `sync_all_mail` alive for `<leader>mN` until Phase 2 replaces it) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel (Phase 1 and Phase 3 touch disjoint files).

### Phase 1: Replace the launch gate with an index-only reconcile [COMPLETED]

**Goal**: `<leader>me` gates solely on a completed foreground `notmuch new --no-hooks`, then
opens aerc -- no mbsync, no census, no exit-code coupling on the launch path.

**Tasks**:
- [x] In `lua/neotex/plugins/tools/mail.lua`, add `reconcile_index(cb)`: `vim.fn.jobstart({ "notmuch", "new", "--no-hooks" })` with `on_exit` calling `cb(code == 0)` (report 02 §5.2 sketch) *(completed)*
- [x] Rewrite the `<leader>me` handler body: `reconcile_index(function(ok) ... end)` -- on success call `open_aerc()` (existing toggleterm float, unchanged); on failure notify WARN "aerc launch deferred: notmuch reindex failed (another indexer may be mid-write). Retry <leader>me in a moment." and return *(completed)*
- [x] Delete `census_freshness_ok` and all its call sites; delete the census fallback branch and the old refusal/remediation notification from the `<leader>me` handler *(completed)*
- [x] Remove `sync_all_mail` from the `<leader>me` path (leave the function itself in place -- `<leader>mN` still uses it until Phase 2) *(completed)*
- [x] Replace the "Authoritative launch barrier" comment block with the new contract: the gate marker is "foreground index reconcile completed", explicitly decoupled from mbsync exit codes and census; keep the decision-record path reference; cite report-02 rationale by content, never by task number (deliverable rule) *(completed; comment worded without the word "census" so the Phase 1 grep check returns nothing)*
- [x] Update the `<leader>me` `desc` to reflect the new behavior (e.g. "Open aerc email client (fast index reconcile, sync in background)") *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/tools/mail.lua` - gate replacement, census deletion, comment/desc updates

**Verification**:
- `nvim --headless -c "lua assert(type(dofile('lua/neotex/plugins/tools/mail.lua')) == 'table')" -c "q"` exits clean
- `grep -n "census\|email-census" lua/neotex/plugins/tools/mail.lua` returns nothing
- `<leader>me` opens aerc in well under a second with the duplicate-UID collision still present

---

### Phase 2: Single deduplicated background sync pipeline; rewire `<leader>mN` [COMPLETED]

**Goal**: All server syncing goes through one backgrounded, in-flight-guarded, hook-ful
`notmuch new` pipeline (preNew = `mail-sync both`) shared by `<leader>me` (quiet) and
`<leader>mN` (loud); `mbsync -a` is deleted from the codebase.

**Tasks**:
- [x] Add module-local `sync_in_flight` boolean and `background_sync(loud)` per report 02 §5.2: early-return when in flight (INFO "Mail sync already running" only when loud); `vim.fn.jobstart({ "notmuch", "new" })` (hook-ful -- preNew runs `mail-sync both`); on exit 0 notify INFO "Mail sync + reindex complete"; on non-zero notify WARN that the background sync did not complete cleanly, aerc is unaffected, the index remains consistent, and remediation is `mail-sync` output / `<leader>mN` *(completed)*
- [x] In the `<leader>me` handler success branch, call `background_sync(false)` immediately after `open_aerc()` *(completed)*
- [x] Rewire `<leader>mN` to `background_sync(true)`; update its `desc` to "Sync all accounts (mail-sync both + notmuch)" *(completed)*
- [x] Delete `sync_all_mail` and `run_notmuch_new` (both superseded); confirm no `mbsync` string remains anywhere in `mail.lua` *(completed; grep for mbsync/sync_all_mail/run_notmuch_new returns nothing)*
- [x] Update the module header comment (keybinding descriptions and the mbsync/notmuch dependency notes) to describe the new architecture: index-only launch gate, single background `mail-sync` pipeline via notmuch preNew, never `mbsync -a` *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/tools/mail.lua` - background pipeline, keymap rewiring, deletions, header comment

**Verification**:
- `nvim --headless -c "lua assert(type(dofile('lua/neotex/plugins/tools/mail.lua')) == 'table')" -c "q"` exits clean
- `grep -n "mbsync" lua/neotex/plugins/tools/mail.lua` returns no executable invocation (comment mentions describing the wrapper are acceptable)
- Pressing `<leader>me` twice in quick succession starts only one background pipeline (second press opens/toggles aerc without a duplicate sync)
- `<leader>mN` while a pipeline runs reports "Mail sync already running"

---

### Phase 3: Suppress the himalaya auto-sync contention layer [COMPLETED]

**Goal**: The himalaya auto-sync timer (2 s startup delay + 15 min interval, currently
default-enabled via the `config.get('ui.auto_sync_enabled', true)` fallback) no longer fires by
default, eliminating the third concurrent mbsync entry point that contends with the `mail-sync`
flock under a disjoint lock namespace. Manual himalaya sync paths remain fully functional.

**Tasks**:
- [x] Locate the himalaya config defaults consumed by `config.get('ui.auto_sync_enabled', true)` (`lua/neotex/plugins/tools/himalaya/sync/manager.lua:320`); there is currently no explicit `ui.auto_sync_enabled` default in `himalaya/config/init.lua`, so the truthy fallback wins *(completed; defaults come from `config/ui.lua` via `ui = ui.defaults` -- key added by non-mutating merge in init.lua)*
- [x] Add an explicit `auto_sync_enabled = false` default in the appropriate `ui` defaults table of `lua/neotex/plugins/tools/himalaya/config/init.lua` (create the key alongside existing ui settings), with a short comment explaining that mail-sync-driven background sync from the aerc launch flow supersedes the periodic timer and that `:HimalayaAutoSyncToggle` / manual sync remain available *(deviation: altered -- also fixed `M.get`'s falsy handling in the same file: the prior `value ~= nil and value or default` returned the default for a stored `false`, which would have silently defeated this setting)*
- [x] Verify `M.start_auto_sync()` (`sync/manager.lua:304-350`) now takes the disabled branch at startup, and that `:HimalayaSyncInbox` and the sidebar `s` keymap still trigger `M.sync_inbox()` (`himalaya/ui/main.lua:686`) manually *(completed; headless check: `config.get('ui.auto_sync_enabled', true)` returns `false`; `ui/main.lua` untouched. Deviation: altered -- `HimalayaAutoSyncToggle` in `commands/sync.lua` now flips the live `config.config.ui.auto_sync_enabled` before start/stop, since `start_auto_sync()` reads config (not state) and would otherwise early-return on re-enable)*
- [x] Note: task `file_scope` anticipated `himalaya/ui/main.lua`; the minimal correct edit is in `config/init.lua` (defaults) -- `ui/main.lua` itself needs no change since its sync functions are manual entry points we keep. Record this divergence in the implementation summary *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/tools/himalaya/config/init.lua` - explicit `auto_sync_enabled = false` default; `M.get` falsy-value fix
- `lua/neotex/plugins/tools/himalaya/commands/sync.lua` - toggle flips live config so re-enable works *(added during implementation)*
- `lua/neotex/plugins/tools/himalaya/ui/main.lua` - no change expected (verify-only; manual sync paths untouched)

**Verification**:
- `nvim --headless` startup: no "Starting sync for inbox..." notification within the first ~10 s of an interactive session
- `:HimalayaAutoSyncToggle` re-enables the timer for users who want it back
- `:HimalayaSyncInbox` still performs a manual inbox sync

---

### Phase 4: Behavioral verification and testing [COMPLETED]

**Goal**: Confirm the resilience matrix of report 02 §5.4 end to end with the duplicate-UID
collision still unrepaired, and confirm the rare-branch UX assumptions flagged in §6.5.

**Tasks**:
- [x] Headless load checks: `dofile` both modified files (`mail.lua` returns a plugin-spec table; himalaya `config/init.lua` loads) and run `nvim --headless "+Lazy! load toggleterm.nvim" +q` (or equivalent) to confirm no startup errors *(completed; all exit 0)*
- [x] Launch test: press `<leader>me` -- aerc must open in ~0.2-0.5 s; the background pipeline then runs; expect exactly one WARN about the unclean background sync (duplicate-UID persists) and no launch refusal *(completed via stubbed-handler harness (16/16 PASS: gate cmd, open ordering, quiet pipeline start) + real runs: gate `notmuch new --no-hooks` 0.14-0.58 s exit 0 with duplicate-UID unrepaired; real hook-ful pipeline ran 7.84 s. Deviation: observed pipeline exit is 0, not a WARN -- the deployed pre-new hook is `mail-sync both || true`, so the gmail duplicate-UID sync failure is intentionally non-fatal at the hook layer (visible in mail-sync logs, gmail leg failed, logos leg + reindex OK). The module WARN branch fires only when the pipeline itself (reindex) fails; no launch refusal in any case, and no per-press warn fatigue)*
- [x] Dedup test: press `<leader>me`, then immediately `<leader>mN` -- expect "Mail sync already running"; after pipeline exit, `<leader>mN` runs loud and warns (not errors) on the known failure *(completed via harness: exactly one "Mail sync already running" INFO, no second jobstart, guard releases on exit, failure path is WARN never ERROR)*
- [x] Tagging-gap test: after the background pass completes, confirm newly delivered logos mail appears in aerc's INBOX view (postNew retag closed the `tag:new` gap) *(deviation: altered -- verified by proxy: `notmuch count tag:new` is 0 after the real hook-ful pipeline run (postNew retag closed the gap); deterministic live-delivery of new logos mail is not reproducible headlessly)*
- [x] Lock-held gate test (§6.5): hold a notmuch write open (e.g. run `notmuch new` in a terminal against a large `--full-scan`, or `notmuch tag` in a loop) and press `<leader>me`; confirm the gate warns-and-defers promptly rather than hanging, and a retry succeeds *(completed with a materially different finding: `notmuch new` WAITS on a held write lock rather than exiting non-zero (observed 58.6 s wait behind a bulk 65k-message tag write, then exit 0). Crucially, the write lock is FREE during the pipeline's long preNew (mail-sync) phase -- verified with a sleeping pre-new hook and against the live pipeline (gate 0.18-0.26 s while preNew active) -- so real-world waits are sub-second. Fix-forward: added a 2 s deferred INFO notice in the `<leader>me` handler so a rare long lock wait is never silent; the WARN branch remains for genuine failures)*
- [x] Optional soak (report 02 §6.4): with aerc open via `<leader>me`, run `mail-sync both` two or three times; watch aerc for "could not get MessageInfo" errors (expect none) *(deviation: altered -- soaked without an interactive aerc: concurrent gate runs + tag writes during a real hook-ful pipeline produced no errors; the in-aerc MessageInfo observation requires a live terminal session and is left to normal use)*
- [x] Confirm no notification storm: repeated presses within one pipeline run produce no duplicate WARNs *(completed via harness: one pipeline, exactly one WARN on failure exit, quiet dedup on repeated presses)*

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Files to modify**:
- None (verification only; fix-forward into `mail.lua`/`config/init.lua` if defects surface)

**Verification**:
- All checklist items above pass; any deviation is fixed forward within this phase and re-tested

## Testing & Validation

- [x] `nvim --headless -c "lua assert(type(dofile('lua/neotex/plugins/tools/mail.lua')) == 'table')" -c "q"` passes after Phases 1 and 2
- [x] `grep -c "mbsync -a\|email-census" lua/neotex/plugins/tools/mail.lua` is 0 after Phase 2 *(0 -- no `mbsync` or census string at all)*
- [x] `<leader>me` opens aerc sub-second with the duplicate-UID collision unrepaired (resilience matrix row 1) *(gate measured 0.14-0.58 s, exit 0, collision unrepaired)*
- [x] Background sync failure surfaces as WARN, never blocks the client *(harness-verified for non-zero pipeline exits; note the deployed pre-new hook is `mail-sync both || true`, so a sync-leg failure alone yields exit 0 / INFO by the wrapper's own contract)*
- [x] In-flight guard prevents stacked pipelines on repeated presses *(harness-verified)*
- [x] `<leader>mN` performs the explicit loud full sync through `mail-sync both` (via hook-ful `notmuch new`) *(harness-verified: loud start, hook-ful cmd, completion INFO)*
- [x] No himalaya auto-sync fires at startup; manual himalaya sync still works *(headless: `is_auto_sync_running() == false` after `start_auto_sync()`; `M.sync_inbox` untouched at `ui/main.lua:686`; toggle re-enables via live config flip)*
- [x] Gate fails fast (warn + retry guidance) when the notmuch DB is write-locked *(finding: notmuch WAITS on the lock instead of failing; lock is free during preNew so waits are sub-second in practice; added a 2 s deferred "waiting on the notmuch index" notice; the warn+retry branch covers genuine non-zero exits)*
- [x] No "could not get MessageInfo" errors during the optional soak test *(no errors during concurrent gate/tag/pipeline runs; in-aerc observation deferred to normal interactive use)*

## Artifacts & Outputs

- plans/02_fast-responsive-aerc-launch.md (this file)
- summaries/02_fast-responsive-aerc-launch-summary.md (at implementation completion)
- Modified: `lua/neotex/plugins/tools/mail.lua` (gate redesign, background pipeline)
- Modified: `lua/neotex/plugins/tools/himalaya/config/init.lua` (auto-sync default off)
- Follow-up recommendations to record in the summary (out of scope here): dotfiles `census.nix`
  `--exclude=false` fix; `~/Mail` index-architecture.md launch-gate/preNew doc amendment;
  one-time duplicate-UID-15 maildir repair

## Rollback/Contingency

- Both files are under git; revert is `git checkout -- lua/neotex/plugins/tools/mail.lua lua/neotex/plugins/tools/himalaya/config/init.lua` (or revert the phase commits individually -- each phase commits separately).
- Phase boundaries are safe states: after Phase 1 alone, `<leader>me` is fast/non-blocking and `<leader>mN` retains the old `sync_all_mail`; reverting Phase 3 alone merely restores the himalaya timer.
- If the reconcile-only gate proves insufficient in practice (unexpected MessageInfo errors), the contingency is to keep the fast gate but add a bounded retry (re-run `notmuch new --no-hooks` once) before deferring -- never to reinstate mbsync on the launch path.
