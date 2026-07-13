# Implementation Plan: Reindex notmuch on mbsync failure before gate fallback

- **Task**: 857 - mail_reindex_on_failure_gate
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/857_mail_reindex_on_failure_gate/reports/01_reindex-on-failure-gate.md
- **Artifacts**: plans/01_reindex-on-failure-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, neovim-lua.md, no-task-references-in-deliverables.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

`sync_all_mail()` in `lua/neotex/plugins/tools/mail.lua` runs `notmuch new` only when
`mbsync -a` exits 0. On failure it calls `on_done(false)` without reindexing, so mailboxes
that fully synced before the abort are invisible to the `<leader>me` gate's census fallback.
The fix extracts a small local helper `run_notmuch_new(cb)` and chains it in BOTH branches
of the mbsync `on_exit`, so the census fallback always evaluates a post-reindex database
while `on_done(false)` is still reported on any mbsync failure (gate semantics untouched).
Done means: mail.lua carries the new helper, the reindex-on-failure branch, an updated
`census_freshness_ok` doc comment, and the `<leader>mS` -> `<leader>mN` header-comment fix,
and the module still loads headlessly.

### Research Integration

The research report (01_reindex-on-failure-gate.md) is authoritative and fully integrated:

- Verified gap at mail.lua lines 45-48 (failure branch skips `notmuch new`).
- Exact replacement code provided in the report's "Recommended Edit" section and reproduced
  in Phase 1 below (helper extraction + both-branch chaining + notifications).
- Callback contract decision: `on_done(false)` on mbsync failure regardless of reindex
  outcome, fired only inside the notmuch `on_exit` (ordering guarantee).
- Call-site safety grep-verified: exactly two call sites, both in mail.lua (lines 120, 147);
  the function is file-local.
- Bundled comment work: census signal-quality doc comment and the header-comment keymap fix.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation requested for this task.

## Goals & Non-Goals

**Goals**:
- Run `notmuch new` after `mbsync -a` in BOTH the success and failure branches of
  `sync_all_mail`, via a single extracted helper `run_notmuch_new(cb)`.
- Preserve the gate's "clean chain" boolean semantics: on mbsync failure, `on_done(false)`
  is reported regardless of the reindex outcome, and only after the reindex finishes.
- Notify the user of both facts on failure: mbsync failed (ERROR, "reindexing notmuch
  anyway"), and whether the index refresh succeeded (WARN "sync is not clean") or failed
  (ERROR).
- Document the external census signal-quality ownership on `census_freshness_ok` (doc
  comment only; points at ~/.dotfiles modules/home/email/agent-tools/census.nix).
- Fix the header-comment drift: `<leader>mS` -> `<leader>mN` in the `sync_all_mail` header.

**Non-Goals**:
- No changes to the `<leader>me` gate logic (mail.lua ~106-140) — zero edits there.
- No changes to census.nix, .mbsyncrc, or anything under ~/Mail.
- No duplication of census logic in Lua; no timeouts, retries, or new configuration.
- No changes to the telescope/notmuch search spec or any other file.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Longer failure path: `notmuch new` now runs before the census fallback | L | H | `notmuch new` on an already-indexed maildir is sub-second and runs async via jobstart; UI never blocks |
| Notification volume doubles on failure (ERROR + WARN) | L | H | Intentional: each notification carries distinct, actionable information (mbsync failed; index refreshed or not) |
| Behavior change for `<leader>mN` failure path (now reindexes) | L | M | Strict improvement matching the function's documented purpose; call site passes no callback and is nil-guarded in both branches |
| Regression in gate semantics via callback wiring mistake | M | L | `on_done(false)` placed INSIDE the notmuch `on_exit` in the failure branch; Phase 2 checklist verifies this line explicitly |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel (this plan is fully sequential).

### Phase 1: Edit mail.lua — helper, both-branch reindex, comments [COMPLETED]

**Goal**: Apply the complete, minimal edit to `lua/neotex/plugins/tools/mail.lua`: extract
`run_notmuch_new`, chain it in both mbsync `on_exit` branches, update the two comments.

**Tasks**:
- [x] Replace the `sync_all_mail` block (current lines 28-51) with the helper + rewritten
      function shown below (before/after). This single replacement also fixes the
      `<leader>mS` -> `<leader>mN` header-comment drift and adds the rationale comment.
- [x] Extend the `census_freshness_ok` header comment (current lines 53-56) with the
      external signal-quality note shown below. No code changes to the function body.
- [x] Confirm no other lines in the file changed (gate at ~106-140 and both keymap specs
      untouched). *(verified via git diff: hunks only at the two planned regions)*
- [x] Confirm no task-number references appear anywhere in the edited code or comments
      (repo rule: no-task-references-in-deliverables). *(grep for task-number patterns: no matches)*

**Before** (current lines 28-51):

```lua
-- Sync all accounts (mbsync -a) and reindex notmuch, with progress notifications.
-- Shared by <leader>me (open aerc) and <leader>mS (explicit sync).
local function sync_all_mail(on_done)
  vim.notify("Syncing all accounts...", vim.log.levels.INFO)
  vim.fn.jobstart({ "mbsync", "-a" }, {
    on_exit = function(_, code)
      if code == 0 then
        vim.fn.jobstart({ "notmuch", "new" }, {
          on_exit = function(_, notmuch_code)
            if notmuch_code == 0 then
              vim.notify("All accounts synced", vim.log.levels.INFO)
            else
              vim.notify("notmuch indexing failed", vim.log.levels.ERROR)
            end
            if on_done then on_done(notmuch_code == 0) end
          end,
        })
      else
        vim.notify("mbsync failed with code " .. code, vim.log.levels.ERROR)
        if on_done then on_done(false) end
      end
    end,
  })
end
```

**After** (replaces the block above in full):

```lua
-- Run `notmuch new` asynchronously and report success to cb(boolean).
local function run_notmuch_new(cb)
  vim.fn.jobstart({ "notmuch", "new" }, {
    on_exit = function(_, code)
      cb(code == 0)
    end,
  })
end

-- Sync all accounts (mbsync -a) and reindex notmuch, with progress notifications.
-- Shared by <leader>me (open aerc) and <leader>mN (explicit sync).
--
-- notmuch new runs on BOTH mbsync outcomes: an aborted mbsync -a may have fully
-- synced some mailboxes before failing, and those messages must be indexed
-- before any freshness decision reads the notmuch database. A failed mbsync
-- still reports on_done(false) -- reindexing reconciles the index with what
-- landed on disk, but it never certifies the sync itself as clean.
local function sync_all_mail(on_done)
  vim.notify("Syncing all accounts...", vim.log.levels.INFO)
  vim.fn.jobstart({ "mbsync", "-a" }, {
    on_exit = function(_, code)
      if code == 0 then
        run_notmuch_new(function(indexed)
          if indexed then
            vim.notify("All accounts synced", vim.log.levels.INFO)
          else
            vim.notify("notmuch indexing failed", vim.log.levels.ERROR)
          end
          if on_done then on_done(indexed) end
        end)
      else
        vim.notify(
          "mbsync failed with code " .. code .. " -- reindexing notmuch anyway",
          vim.log.levels.ERROR
        )
        run_notmuch_new(function(indexed)
          if indexed then
            vim.notify(
              "notmuch index refreshed (mbsync still failed -- sync is not clean)",
              vim.log.levels.WARN
            )
          else
            vim.notify("notmuch indexing failed after mbsync failure", vim.log.levels.ERROR)
          end
          if on_done then on_done(false) end
        end)
      end
    end,
  })
end
```

**Before** (`census_freshness_ok` header comment, current lines 53-56):

```lua
-- Authoritative freshness check via the email-census wrapper's freshness line
-- ("INBOX freshness ... [ok|STALE]"). Used as the fallback launch barrier when
-- the sync+reindex chain did not complete cleanly. Returns true only when the
-- freshness line is present and reads [ok] for the given account.
```

**After** (comment only; function body unchanged):

```lua
-- Authoritative freshness check via the email-census wrapper's freshness line
-- ("INBOX freshness ... [ok|STALE]"). Used as the fallback launch barrier when
-- the sync+reindex chain did not complete cleanly. Returns true only when the
-- freshness line is present and reads [ok] for the given account.
--
-- Signal quality is owned by the external wrapper (see ~/.dotfiles
-- modules/home/email/agent-tools/census.nix): the freshness line is a
-- count-with-tolerance proxy that cannot detect flag renames or phantom
-- drift. Improving that signal is a dotfiles-side follow-up, out of scope
-- for this module.
```

Style constraints for the edit: 2-space indent, all lines under ~100 columns, local
functions only, preserve the existing `vim.notify` style. Both snippets above already
satisfy these.

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/tools/mail.lua` - replace `sync_all_mail` block with helper +
  rewritten function; extend `census_freshness_ok` header comment. No other changes.

**Verification**:
- `git diff lua/neotex/plugins/tools/mail.lua` shows changes ONLY in the two regions above
  (lines ~28-71); the gate block and keymap specs are untouched.
- Visual check: in the failure branch, `on_done(false)` appears inside the
  `run_notmuch_new` callback, not before it.

---

### Phase 2: Verification — load check and reasoned smoke test [COMPLETED]

**Goal**: Confirm the module is syntactically valid and loads cleanly, and walk the async
failure path by reasoning plus a described manual smoke test (no real mail breakage
required).

**Tasks**:
- [x] Syntax/load check (run whichever is available, in order of preference):
  - `luacheck lua/neotex/plugins/tools/mail.lua` if `luacheck` is on PATH (accept
    warnings about `vim` global if no .luacheckrc; errors must be zero), otherwise
  - `nvim --headless -c "luafile lua/neotex/plugins/tools/mail.lua" -c "q"` — the file is
    a lazy.nvim spec table with no load-time side effects; expect no error output.
    *(luacheck not on PATH; headless luafile check exited 0 with no error output)*
- [x] Callback-contract review checklist (static, against the final file):
  - Success branch: `on_done(indexed)` fires only inside the notmuch `on_exit`; TRUE only
    when both mbsync and notmuch exited 0.
  - Failure branch: `run_notmuch_new` is invoked, and `on_done(false)` fires only inside
    its callback — never before the reindex completes, never with `true`.
  - Both `on_done` calls remain nil-guarded (`if on_done then ... end`) so `<leader>mN`
    (no-callback call site) is safe.
- [x] Described manual smoke test (perform if convenient; otherwise document as the
      acceptance procedure — do NOT break real mail state to force it):
      *(deviation: altered — documented as acceptance procedure, not performed; performing
      it requires disconnecting the network or an unreachable IMAP host, out of scope for a
      headless autonomous run)*
  1. Simulate mbsync failure non-destructively, e.g. disconnect the network or run with an
     unreachable IMAP host, then press `<leader>me`.
  2. Expect notification sequence: "Syncing all accounts..." (INFO) -> "mbsync failed with
     code N -- reindexing notmuch anyway" (ERROR) -> "notmuch index refreshed (mbsync still
     failed -- sync is not clean)" (WARN) -> "Sync/reindex did not complete cleanly --
     checking index freshness via email-census..." (WARN) -> gate then either opens aerc
     (census [ok] on both accounts) or blocks with remediation guidance.
  3. Confirm the gate never opens directly from the failure branch (i.e., only via the
     census [ok] path) — never-fail-open preserved.
  4. Restore network; press `<leader>me` again; expect "All accounts synced" (INFO) and
     aerc opening — success path unchanged.
- [x] Confirm `<leader>mN` with the simulated failure emits the same ERROR + WARN pair and
      returns without error (no callback involved). *(deviation: altered — verified
      statically: `<leader>mN` calls `sync_all_mail()` with no callback; both notification
      paths are shared and both `on_done` calls are nil-guarded, so the same ERROR + WARN
      pair fires and no callback is invoked)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- None (verification only).

**Verification**:
- Load check exits 0 with no error output.
- All checklist items above ticked; any deviation loops back to Phase 1 for correction.

## Testing & Validation

Success-criteria checklist (definition of done):

- [x] `run_notmuch_new(cb)` helper exists as a file-local function; the notmuch jobstart
      nest appears exactly once in the file.
- [x] `notmuch new` runs on both mbsync outcomes; on failure, `on_done(false)` fires only
      inside the notmuch `on_exit` (post-reindex census guarantee).
- [x] On mbsync failure, `on_done` receives `false` regardless of the reindex outcome
      (clean-chain semantics preserved; never fail-open).
- [x] Gate block (mail.lua ~106-140) and both keymap specs are byte-identical to before.
- [x] `census_freshness_ok` gains the signal-quality doc comment referencing
      ~/.dotfiles modules/home/email/agent-tools/census.nix; function body unchanged.
- [x] `sync_all_mail` header comment reads `<leader>mN` (drift fixed).
- [x] No task-number references in mail.lua code or comments.
- [x] Module loads headlessly without error (`luacheck` or
      `nvim --headless -c "luafile lua/neotex/plugins/tools/mail.lua" -c "q"`).
- [x] Manual smoke test performed or documented per Phase 2 (no real mail state broken;
      documented as acceptance procedure).

## Artifacts & Outputs

- plans/01_reindex-on-failure-gate.md (this file)
- Modified: lua/neotex/plugins/tools/mail.lua (single-file edit)
- summaries/01_reindex-on-failure-gate-summary.md (written by /implement)

## Rollback/Contingency

Single-file, single-commit change: revert with
`git checkout -- lua/neotex/plugins/tools/mail.lua` (uncommitted) or
`git revert <commit>` (committed). No state, config, or external-system changes exist to
unwind. If the reindex-on-failure path proves noisy or slow in practice, the failure branch
can be reverted to `on_done(false)` without touching the helper or the success branch.
