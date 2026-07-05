# notmuch Index Staleness: Detection & Remediation

How the `/email` skill guarantees that a coverage-promising `--all` sweep actually covers the
whole mailbox, given that classification reads a notmuch index that can lag the on-disk maildir.

## The problem in one paragraph

`email-classify` sees only what notmuch has **indexed**. `email-census` likewise reports
`notmuch count` for its folder lines. When the index lags the maildir, both under-report by the
same amount, so an `--all` sweep can silently classify only the indexed subset while claiming
"whole-mailbox coverage." There is **no auto-indexer** (no mbsync systemd timer, no post-sync
`notmuch new` service — see wrapper-contracts.md §13), so the index falls behind whenever mail
arrives and nothing has re-run `notmuch new` since.

## Ground truth vs. index

| Source | What it measures | Trustworthy for coverage? |
|--------|------------------|---------------------------|
| `himalaya envelope list -f INBOX \| jq length` | on-disk maildir, correct maildir++ mapping | **Yes** — authoritative on-disk truth |
| `notmuch count folder:<Folder>` | what classification actually sees | This is the *coverage numerator*, not truth |
| `find ~/Mail/<acct>/{new,cur} \| wc -l` | raw file count | **No** — stray dirs / `.Labels.*` / notmuch `folder:` semantics make it diverge in both directions |

Live example (2026-07-05): Logos `on-disk=3736` vs `notmuch-indexed=62` (index far behind); Gmail
`on-disk=2276` vs `notmuch-indexed=3382` (index retains entries for removed files). The divergence
can go **either** direction, which is why the check is a divergence *warning*, not a one-sided
"index < disk" test — and why a plain `notmuch new` reindex (which both adds and prunes) is the
fix.

## Detection: the census freshness line

`email-census` (`.dotfiles` `census.nix`, task 823) prints:

```
INBOX freshness  on-disk=<D>  notmuch-indexed=<I>  [ok|STALE]
```

`[ok]` when `D == I`, else `[STALE]`. `skill-email-cleanup`'s `--all` Stage 1 **staleness gate**
parses this line and will not present a whole-mailbox bucket approval while it reads `[STALE]`.
If the line is absent (an `email-census` predating task 823), coverage is treated as *unverified*
and a visible notice is emitted — never assumed fresh.

## Remediation: `email-reindex`

The sanctioned reindex is the `email-reindex` operator helper (`.dotfiles` `mbsync.nix`, task
824), which runs `notmuch new --no-hooks`:

- `--no-hooks` skips `preNew = mbsync -a` (never-`mbsync -a` invariant; freeze-safe) and `postNew`
  auto-tagging. Folder-scoped classification is made current; `+inbox`/account tag views lag until
  a later full `notmuch new`.
- Index-only, mutates no mail — a sanctioned NON-wrapper operation, exempt from the "never call
  raw notmuch" rule exactly as `mbsync` is (wrapper-contracts.md §13). A raw `notmuch new` stays
  forbidden (it triggers `mbsync -a`).
- Does NOT pull from the server. If the maildir itself is behind the server, run `mbsync <group>`
  / `email-thaw` / `/email --sync` first, then `email-reindex`.

## End-to-end flow

```
/email --all
  └─ Stage 1: email-census
       └─ parse "INBOX freshness … [ok|STALE]"
            ├─ [ok]     → proceed to count-probe + sweep (coverage honored)
            └─ [STALE]  → report on-disk vs indexed divergence
                          ├─ interactive: offer email-reindex → re-census → re-check → sweep
                          └─ autonomous: STOP, report divergence + `email-reindex` command
```

## Cross-references

- wrapper-contracts.md §13 — index freshness, `email-reindex`, no-auto-indexer (frozen-repo facts)
- skill-email-cleanup SKILL.md — Stage 1 staleness gate + Staleness Remediation section
- archive-mode-risk.md — `--archive` coverage likewise depends on a fresh index
