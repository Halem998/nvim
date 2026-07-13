# Research Report: Task #857

**Task**: 857 - mail_reindex_on_failure_gate
**Started**: 2026-07-13T00:00:00Z
**Completed**: 2026-07-13T00:00:00Z
**Effort**: Small (single-function edit + two comments)
**Dependencies**: None
**Sources/Inputs**: lua/neotex/plugins/tools/mail.lua (full read), repo-wide grep for call sites
**Artifacts**: specs/857_mail_reindex_on_failure_gate/reports/01_reindex-on-failure-gate.md
**Standards**: report-format.md, neovim-lua.md (2-space indent, ~100 col), no-task-references-in-deliverables.md

## Executive Summary

- Verified the gap: `sync_all_mail()` (mail.lua lines 30-51) runs `notmuch new` only when
  `mbsync -a` exits 0; on failure it notifies and calls `on_done(false)` without reindexing,
  so partially-landed maildir files are invisible to the census fallback check.
- Recommended fix: extract a tiny local helper `run_notmuch_new(cb)` and chain it in BOTH
  branches of the mbsync `on_exit`. The failure branch reindexes, adjusts notifications, and
  still reports `on_done(false)` — the gate's never-fail-open semantics are untouched.
- Both call sites (`<leader>me` gate at line 120, `<leader>mN` at line 147) are safe with the
  failure path now reindexing; `<leader>mN` passes no callback and simply benefits.
- Two comment additions: an mbsync-failure rationale comment inside `sync_all_mail`, and a note
  on `census_freshness_ok` documenting the external census.nix signal-quality dependency.
- One comment-accuracy fix bundled in: the `sync_all_mail` header says "`<leader>mS`" but the
  actual keymap is `<leader>mN` (line 145).

## Context & Scope

The `<leader>me` keymap opens aerc only behind an authoritative freshness barrier: a clean
`mbsync -a` + `notmuch new` chain, or an `email-census` `[ok]` freshness line on both accounts;
otherwise it refuses with remediation guidance. The barrier itself is sound and out of scope for
change. The only defect is that a failed `mbsync -a` skips `notmuch new`, so any mailboxes that
synced before the abort remain unindexed when the census fallback evaluates freshness.

Out of scope (per task guardrails): census.nix, .mbsyncrc, ~/Mail data operations, any gate
rewrite, any duplication of census logic in Lua.

## Findings

### Existing Configuration (verified current state)

**`sync_all_mail()` — lines 28-51.** The failure branch (lines 45-48) is the gap:

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

Note the header comment drift: it says "`<leader>mS` (explicit sync)" but the actual keymap
defined at lines 144-150 is `<leader>mN`. (The file-top comment block at line 14 correctly says
`<leader>mN`.)

**`census_freshness_ok()` — lines 53-71.** Trusts the `email-census` wrapper's
"INBOX freshness ... [ok]" line; returns true only when the line is present and reads `[ok]`.
Unchanged by this task except for one added doc-comment line (see below).

**The `<leader>me` gate — lines 106-140.** Refuse-and-report logic, confirmed sound:

```lua
sync_all_mail(function(ok)
  if ok then
    open_aerc()
    return
  end
  vim.notify(
    "Sync/reindex did not complete cleanly -- checking index freshness via email-census...",
    vim.log.levels.WARN
  )
  if census_freshness_ok("gmail") and census_freshness_ok("logos") then
    vim.notify("Index freshness [ok] on both accounts -- opening aerc", vim.log.levels.INFO)
    open_aerc()
  else
    vim.notify(
      "aerc launch blocked: sync failed and index freshness is not [ok].\n"
        .. "Remediate: fix the sync (<leader>mN or mbsync <group>), run email-reindex "
        .. "if only the index lags, then retry <leader>me.",
      vim.log.levels.ERROR
    )
  end
end)
```

**Call sites.** `sync_all_mail` is a file-local function. Repo-wide grep over `lua/` and
`after/` confirms exactly two call sites, both in mail.lua:

- Line 120: `<leader>me` gate, with callback (above).
- Line 147: `<leader>mN`, called as `sync_all_mail()` with no callback.

### Recommended Edit (before/after)

Extract a small local helper and mirror the notmuch chain into the failure branch. This is the
one place where a helper genuinely reduces duplication (two structurally identical `jobstart`
nests differing only in notifications), so it satisfies the "only if it simplifies" bar.

**After** — replaces lines 28-51 in full:

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

All lines are under 100 columns, 2-space indented, and the comments contain no task numbers.

### Callback-Contract Decision

`on_done(false)` in the mbsync-failure branch **regardless of the notmuch outcome**. Rationale:

- The boolean means "the sync+reindex chain completed cleanly" — the gate's primary barrier
  marker (gate comment, lines 113-114). A failed mbsync is by definition not clean, even if the
  subsequent reindex succeeds: mail known to the server may simply not be on disk yet.
- With `on_done(false)`, the gate falls through to `census_freshness_ok()` on both accounts.
  That is exactly the intended flow: the reindex improves the index that the census check then
  evaluates; it never bypasses the check. The never-fail-open property is preserved verbatim —
  no gate code changes at all.
- Ordering is guaranteed by the async nesting: `on_done(false)` fires only inside the
  `notmuch new` `on_exit`, so the census check always reads a post-reindex database.

### Call-Site Safety

- **`<leader>me` (line 120)**: receives `false` exactly as before on mbsync failure; the only
  behavioral change is that the census fallback now evaluates a reconciled index. Safe and the
  point of the fix.
- **`<leader>mN` (line 147)**: passes no callback (`on_done` nil-guarded in both branches).
  Previously a failed `mbsync -a` left the index stale; now it gets reconciled — a strict
  improvement for the explicit-sync keymap too. Safe.
- No other call sites exist anywhere in `lua/` or `after/` (grep-verified; the function is
  `local` to mail.lua).

### Doc Comment for the Census Dependency

Add one sentence to the existing `census_freshness_ok` header comment (lines 53-56), so the
external dependency is documented in-code without duplicating census logic:

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

## Decisions

1. **Helper extraction (`run_notmuch_new`)**: adopted — two identical jobstart nests would
   otherwise be duplicated; the helper is 7 lines and removes all duplication.
2. **`on_done(false)` on mbsync failure even when notmuch succeeds**: adopted — preserves the
   gate's "clean chain" boolean semantics and never-fail-open intent.
3. **Notification set**: mbsync failure notice amended to say "reindexing notmuch anyway";
   a WARN follows on reindex success ("sync is not clean"), an ERROR if the reindex also fails.
   The user always learns both facts: mbsync failed, and whether the index was refreshed.
4. **Header comment fix**: `<leader>mS` -> `<leader>mN` in the `sync_all_mail` header, bundled
   because the edit rewrites that comment block anyway.
5. **No timeouts, no retries, no gate changes**: rejected as needless complexity for this fix.

## Risks & Mitigations

- **Slightly longer failure path**: `notmuch new` now runs before the gate's census fallback on
  mbsync failure. `notmuch new` on an already-indexed maildir is fast (typically sub-second),
  and it runs async via jobstart, so the UI is not blocked. Acceptable; it directly serves the
  freshness decision.
- **Double-notification volume on failure**: two notifications (mbsync ERROR + reindex WARN)
  instead of one. Intentional — each carries distinct, actionable information.
- **Behavior change for `<leader>mN` failure path**: now reindexes after failed mbsync. This is
  the desired reconciliation behavior and matches the function's documented purpose
  ("mbsync -a + notmuch new").

## Context Extension Recommendations

None. The relevant architecture is already documented externally
(~/Mail/.claude/context/project/email/domain/index-architecture.md, cited in the gate comment);
the in-code comments added by this change carry the module-local knowledge.

## Appendix

- Verification performed: full read of lua/neotex/plugins/tools/mail.lua (216 lines);
  `grep -rn "sync_all_mail\|email-census\|census_freshness" lua/ after/` (10 hits, all in
  mail.lua).
- Post-implementation check: `nvim --headless -c "lua require('neotex.plugins.tools.mail')" -c "q"`
  (module is a lazy.nvim spec table; loads without side effects), plus a manual `<leader>me`
  exercise with mbsync forced to fail (e.g. no network) to observe the new notification chain
  and census fallback.
