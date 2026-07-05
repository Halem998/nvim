# Research: notmuch-staleness detection & remediation for /email (tasks 823–825)

**Session**: sess_1783291831_e8177e (orchestrate 823-825)
**Date**: 2026-07-05
**Scope**: shared investigation grounding tasks 823 (detection), 824 (remediation), 825 (docs).
**Source of truth**: `~/.dotfiles/modules/home/email/` (frozen wrapper repo, task 72) —
read-only inspection, verbatim.

## Executive summary

The orchestration surfaced a **design-invalidating finding**: the premise that
`email-census` reports a maildir/himalaya *ground-truth* count (against which a stale notmuch
index could be compared) is **false**. `email-census` reads notmuch for every count it prints.
A correct staleness check therefore cannot be built from the current wrappers alone, and a
naive filesystem count is not a reliable substitute. Both core tasks (823, 824) acquire a
`~/.dotfiles` (frozen, separate-repo) component. Autonomous plan/implement was halted here
rather than encode a detector that can never fire or unilaterally edit the frozen wrapper repo.

## Finding 1 — `email-census` counts come from notmuch, not maildir

`~/.dotfiles/modules/home/email/agent-tools/census.nix`:

```sh
printf "%-10s %s\n" "INBOX" "$(notmuch count "folder:$ACCOUNT_FOLDER")"
# ... All_Mail/Sent/Trash/Spam/Drafts: all `notmuch count 'folder:...'`
# date buckets: `notmuch count "folder:$ACCOUNT_FOLDER and date:$y-..."`
# ONLY maildir touch: a 10-message sample ->
himalaya envelope list "${HIMALAYA_ACCT[@]}" -f INBOX -o json -s 10
```

Consequences:
- Every count line in `email-census` is a **notmuch** number. When the index is stale, census
  under-reports exactly like `email-classify` does — they share the same blind spot.
- Task 823 as written ("compare `email-census` count vs `notmuch folder:` count") compares
  **notmuch to notmuch**. It would report "no divergence" on a badly stale index. It cannot work.
- The "62 vs 12" in the originating report did **not** come from census's count lines (those
  would read 12/12). It came from a *separate* maildir-side observation (himalaya, or the
  on-disk maildir), which is not something any wrapper exposes as a full count.

## Finding 2 — a naive maildir file count is not a clean proxy for `folder:X`

Live measurement (2026-07-05, this machine):

| Source | Logos | Gmail |
|--------|-------|-------|
| `notmuch count folder:<acct>` | 62 | 3382 |
| `find ~/Mail/<acct>/{new,cur} -type f \| wc -l` | 3736 | 2276 |

The counts diverge in **both** directions, so `find | wc -l` cannot be trusted as ground truth:
- `~/Mail/Logos/` contains stray `INBOX/`, `Archive/`, `Drafts/` dirs (dot-less) that lib.nix
  explicitly flags as "stray, always-empty ... must never be queried", plus many `.Labels.*`
  maildirs — the bare-root `cur/` holds thousands of files that do not all map to `folder:Logos`.
- notmuch `folder:` matching semantics (exact-directory vs recursive) do not line up 1:1 with a
  bare `new/`+`cur/` file count.

A trustworthy ground-truth count must be **himalaya-aware** (himalaya resolves the maildir++
folder mapping correctly) — e.g. `himalaya envelope list -a <acct> -f INBOX -o json -s <big> |
jq length` — or must be produced inside the wrapper layer that already knows the mapping.

## Finding 3 — the reindex fix is `notmuch new --no-hooks`, and there is no auto-indexer

`~/.dotfiles/modules/home/email/notmuch.nix`:
```nix
hooks = {
  preNew  = "mbsync -a";          # plain `notmuch new` triggers a WHOLE-CONFIG sync
  postNew = ''notmuch tag +inbox +unread ...; +gmail/+logos by folder; ...'';
};
```
- Plain `notmuch new` runs `preNew = mbsync -a` first — **violates the never-`mbsync -a`
  invariant** (touches the deferred Logos/Bridge account). The sanctioned reindex is
  **`notmuch new --no-hooks`** (confirmed by `email-thaw` and `email-freeze` guidance, and the
  aerc rebind at `aerc.nix:117`).
- Trade-off: `--no-hooks` also skips `postNew`, so newly-indexed mail is **not** auto-tagged
  `+inbox`/`+gmail`/`+logos`. Folder-scoped classification (`email-classify "folder:Logos ..."`)
  still works (folder tokens are path-based, not tag-based), but any tag-based consumer would
  lag until a full `notmuch new` runs. Remediation design must state this explicitly.
- **No mbsync systemd timer exists** (mbsync.nix §"TRIGGER-PATH GUARDS": "there is NO mbsync
  systemd timer — these are mbsync's ONLY trigger paths"): (1) notmuch `preNew` = `mbsync -a`,
  (2) aerc `$` = `mbsync -a && notmuch new`, (3) manual. **Nothing reindexes automatically after
  server mail arrives** — this is the systemic root cause of intermittent staleness. (The
  originating "12" had already self-healed to "62" by this session, because one of those paths
  ran in between — confirming the intermittency.)

## Finding 4 — guard & precedent

- `mail-guard.sh` does **not** deny `notmuch` (it denies raw `himalaya` mutations, `msmtp`,
  `secret-tool`, `rm *Mail*`). `notmuch new --no-hooks` **passes the hook** — only the skills'
  *wrapper-only discipline* (a MUST-NOT in SKILL.md prose) forbids it. So sanctioning it is a
  skill-prose + docs change, not a hook change. This mirrors how `mbsync` is handled
  (non-wrapper, sanctioned via `skill-email-sync`).
- `email-freeze` / `email-thaw` are existing `.dotfiles` **operator helpers** (task 72 Phase 8,
  explicitly "NOT part of the 5-binary agent contract"). They are the exact template for a new
  `email-reindex` helper (`notmuch new --no-hooks`, freeze-aware) if remediation is put in the
  wrapper repo.
- A freeze may be active (SyncState backed up under `~/Mail/.syncstate-backups/`). During a
  freeze, `notmuch new --no-hooks` is safe (no sync) but plain `notmuch new` / `mbsync` are not.
  Remediation must be freeze-aware.

## Revised task scoping (supersedes the as-created descriptions)

| Task | As created | Corrected |
|------|-----------|-----------|
| 823 detection | wrapper-only, "no .dotfiles change" | Needs a trustworthy maildir/server count. Cleanest: **`.dotfiles` change to `email-census`** to add a himalaya-derived per-folder count line beside the notmuch count, so the skill can compare the two numbers wrapper-only. In-repo-only fallback (sanction a himalaya read-only count in the skill) is possible but weaker. |
| 824 remediation | in-repo skill/guard prose | Sanctioned reindex = **`notmuch new --no-hooks`**. Options: (a) recommend the user run it / `email-thaw`; (b) add an **`email-reindex` operator helper** in `.dotfiles` (mirrors email-freeze/thaw). Reconcile SKILL.md MUST-NOT prose + wrapper-contracts §8 to distinguish index-only `notmuch new --no-hooks` (sanctioned, like mbsync) from raw notmuch *mutation/tag*. |
| 825 docs | doc sweep | Unchanged in spirit; must document the corrected model (census reads notmuch; ground truth is himalaya-side; reindex = `notmuch new --no-hooks`; no auto-indexer; freeze-awareness). |

## Recommendation

Both 823 and 824 now require decisions that cross into the frozen `~/.dotfiles` repo and change
the intended scope. Rather than auto-implement a non-functional detector or unilaterally modify
the frozen wrapper repo fire-and-forget, the orchestration paused for a human decision on
**where the maildir-count and reindex helper should live** (in-repo skill discipline vs a
`.dotfiles` wrapper/helper change). See the three options presented to the user.
