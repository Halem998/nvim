# Seed Diagnosis: `<leader>me` slow / blocking / never opens aerc

**Task**: 858 — Fast, responsive, non-failing `<leader>me` aerc launch
**Author**: seed report (root session), to be extended by `--hard` research
**Status**: preliminary — hypotheses grounded in code, timing not yet instrumented

---

## 1. Observed symptoms

Pressing `<leader>me` (notify log, oldest→newest):

```
Starting sync for inbox...
Sync completed for inbox
Syncing all accounts...
mbsync failed with code 1 -- reindexing notmuch anyway
notmuch index refreshed (mbsync still failed -- sync is not clean)
Sync/reindex did not complete cleanly -- checking index freshness via email-census...
aerc launch blocked: sync failed and index freshness is not [ok].
Remediate: fix the sync (<leader>mN or mbsync <group>), run email-reindex ...
```

- Took a **very long time**.
- aerc **never opened** (gate refused).
- Regression: materially slower and less usable than before the recent gate/wrapper work
  (tasks 857 nvim, 108 + 109 dotfiles).

This is *correct* behavior per the current gate contract (refuse rather than open onto a
stale index while sync is failing) — but the UX cost is unacceptable, and the block is
effectively permanent given the underlying cause.

## 2. What actually runs on one `<leader>me` press — THREE sync layers

Traced across `~/.config/nvim` and `~/.dotfiles`:

1. **himalaya plugin sync** — `Starting sync for inbox` / `Sync completed for inbox` come from
   `lua/neotex/plugins/tools/himalaya/ui/main.lua:552,605`. A himalaya-side sync runs in the
   same window as `<leader>me`. Whether `<leader>me` triggers it directly or it is
   autosync/coincidental needs confirmation, but it is a *separate* sync path from mail.lua.

2. **`mail.lua` `sync_all_mail`** — `Syncing all accounts...` → `vim.fn.jobstart({"mbsync","-a"})`
   (`lua/neotex/plugins/tools/mail.lua:47`). This is the **forbidden all-channels `-a` form**
   the dotfiles email module deliberately engineered away from (it runs every channel including
   Gmail `All Mail` ≈ 64k messages, and can fire `logos-labels`). It fails with code 1 on the
   pre-existing duplicate-UID-15 collision in `Gmail/.All_Mail`.

3. **`mail.lua` `run_notmuch_new`** — plain `notmuch new` **with hooks**
   (`mail.lua:30`). notmuch's `preNew` hook is now `mail-sync both`
   (`~/.config/notmuch/default/hooks/pre-new`, repointed by dotfiles task 109), so this reindex
   step **re-triggers a full serialized dual-account sync**: `mail-sync both` takes its flock,
   runs `mbsync gmail` + `mbsync logos`, then `notmuch new --no-hooks`.

So one press ≈ `himalaya inbox sync` + `mbsync -a` (all channels, ~64k) + `mbsync gmail` +
`mbsync logos` + at least two `notmuch new` passes + two `email-census` scans (gate fallback).
That is the "very long time."

## 3. Why it is slow (performance)

- **`mbsync -a` is the worst case**: it syncs all channels including the 64k `All_Mail`
  archive, synchronously, before aerc is allowed to open — even though aerc maintains its own
  sync and does not need this.
- **Redundant work**: the task-857 reindex helper calls hook-ful `notmuch new`, which recursively
  drives `mail-sync both` (another gmail+logos mbsync). The 857 change (good in isolation)
  compounds badly now that `preNew` = `mail-sync both` (task 109). The two hardening tasks
  interact to *double* the sync work.
- **Everything is on the launch-blocking critical path**: nothing is backgrounded relative to
  opening aerc. The user waits for the slowest full sync before seeing anything.

## 4. Why it never opens (correctness / design flaw)

The gate opens aerc only if **(a)** `mbsync -a` + `notmuch new` both exit 0, OR **(b)**
`census_freshness_ok("gmail")` AND `census_freshness_ok("logos")` both read `[ok]`.

- **(a) can never succeed** while the duplicate-UID-15 collision persists — that is a manual
  maildir data repair, not something any sync will fix. So the primary barrier is permanently red.
- **(b)** now uses the task-108 rename/deletion-aware census, which honestly reports `[STALE]`
  whenever real drift exists (and requires BOTH accounts `[ok]`; logos index lag alone blocks).

**The core design flaw**: the gate conflates *"the sync succeeded"* with *"the index is safe for
aerc to read."* Those are orthogonal. After `notmuch new` reconciles the index to on-disk state,
aerc can open safely **regardless of whether mbsync succeeded**. Blocking aerc on mbsync success
means a persistent, sync-independent data corruption (duplicate UID) **permanently denies the
user their mail client** through `<leader>me`, even though opening aerc would be perfectly safe.

## 5. Interaction map (which repo owns what)

- `~/.config/nvim/lua/neotex/plugins/tools/mail.lua` — the `<leader>me`/`<leader>mN`
  orchestration and the gate. **Primary locus of this task.** Still uses `mbsync -a` +
  hook-ful `notmuch new`; does not use the `mail-sync` wrapper.
- `~/.config/nvim/lua/neotex/plugins/tools/himalaya/…` — the second sync layer.
- `~/.dotfiles/modules/home/email/` — `mail-sync` (task 109, serialized/group-scoped/`-a`-proof,
  `--no-wait` fast-fail flag, internal `--no-hooks` reindex), `census.nix` (task 108 freshness),
  `notmuch.nix` preNew=`mail-sync both`, `aerc.nix` `$`=`mail-sync gmail`.
- `~/Mail/Gmail/.All_Mail` — the duplicate-UID-15 data (two distinct messages both `,U=15`);
  still unrepaired, so mbsync still exits 1 and no server mail flows.

## 6. Design desiderata for the fix (fast, responsive, does not fail)

Directions for the researcher to evaluate/verify (not prescriptions):

- **Open aerc immediately on the current (reindexed) index; sync in the background.** aerc has its
  own sync; the "sync-before-open barrier" may be the wrong model entirely. A cheap
  `notmuch new --no-hooks` (index-only, fast) before open may be sufficient, with mbsync deferred.
- **Decouple launch from mbsync success.** Gate on *index freshness* only (which a plain
  `notmuch new --no-hooks` can guarantee), never on mbsync exit code. A failing mbsync should
  warn, not block the client.
- **Eliminate the redundant sync layers.** Route mail.lua through the single `mail-sync` wrapper
  (respecting task-109 serialization) instead of raw `mbsync -a`; stop `run_notmuch_new` from
  using hook-ful `notmuch new` (use `--no-hooks`) so it does not recursively drive `mail-sync both`;
  reconcile or suppress the himalaya-layer sync so only one sync path fires.
- **Never use `mbsync -a`** — conform to the dotfiles doctrine (group-scoped only).
- **Make the slow full sync asynchronous / opt-in** (`<leader>mN` for an explicit full sync);
  `<leader>me` should be near-instant.
- Consider `mail-sync --no-wait` semantics and whether launch should ever wait on a lock.

## 7. Constraints / non-goals

- Non-goal: the one-time duplicate-UID-15 maildir repair (separate manual data op). But the fix
  MUST make `<leader>me` usable *despite* an unrepaired collision.
- Preserve safety: never open aerc onto a genuinely stale/mid-write index (Xapian
  reader/writer). "Fast" must not reintroduce the `could not get MessageInfo` race.
- Keep mail.lua cohesive; push sync/lock policy to the dotfiles `mail-sync` wrapper where it
  belongs.

## 8. Open questions for `--hard` research

1. Does `<leader>me` itself invoke the himalaya sync, or is it independent/autosync? Exact trigger.
2. Exact timing breakdown per layer (instrument each mbsync/notmuch/census call).
3. Is any `notmuch new --no-hooks` alone sufficient to guarantee aerc-safe freshness, and how fast
   is it vs. a full sync?
4. Correct division of labor: what should mail.lua do vs. delegate to `mail-sync`?
5. Can the gate be reduced to a single fast index-freshness check (no mbsync on the launch path)?
6. What is the minimal, durable redesign that is fast, responsive, and cannot be permanently
   blocked by a sync-independent data fault?
