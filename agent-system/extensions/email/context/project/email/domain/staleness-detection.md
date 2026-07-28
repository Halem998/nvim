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

**File-vs-file model**: the gate compares two FILE counts for the same maildir path —
never a file count against a deduped message count. `himalaya envelope list` reports one entry
per on-disk file (maildir++ semantics: duplicate copies across folders are duplicate files, not
deduped). `notmuch count folder:<Folder>` reports deduped **Message-IDs**, which collapses
duplicate copies — an apples-to-oranges comparison against the on-disk file count that is
*structurally* unreachable whenever an account has any real Message-ID duplication (confirmed:
Logos on-disk=341 vs `notmuch count folder:Logos`=318, permanently `[STALE]` under the old
equality rule even on a clean, fully-synced, freshly-reindexed mailbox — the 23-message gap is
real distinct messages, not duplicates).

| Source | What it measures | Trustworthy for the freshness gate? |
|--------|------------------|---------------------------|
| `himalaya envelope list -f INBOX \| jq length` | on-disk maildir FILE count, correct maildir++ mapping | **Yes** — authoritative on-disk truth |
| `notmuch --output=files` post-filtered by literal path prefix (`path:<acct>/cur` / `path:<acct>/new`) | indexed FILE count for the exact maildir path | **Yes** — the correct file-vs-file comparand |
| `notmuch count folder:<Folder>` | deduped **Message-ID** count | **No** — wrong unit; do not compare against an on-disk file count |
| `notmuch count --output=files folder:<Folder>` (unfiltered) | every known file for each matching message, across folders/accounts | **No** — inflated by cross-folder/cross-account duplicate copies (see quirk below) |
| `find ~/Mail/<acct>/{new,cur} \| wc -l` | raw file count | **No** — stray dirs / `.Labels.*` / notmuch `folder:` semantics make it diverge in both directions |

### The `--output=files` cross-folder/cross-account duplicate-inclusion quirk

`notmuch(1)` documents `--output=files` as follows: for a `search`/`count` query, `--output=files`
prints "the filenames of all messages matching the search terms" — **all** filenames known to
notmuch for each matching message, not just the ones under the folder implied by the query's
`folder:`/`path:` term. A message with copies in multiple maildir locations (label folders,
cross-account duplicates via shared Message-ID) contributes every one of those copies to the
output, regardless of which folder the query's `folder:X` term named.

Verified live (2026-07-13, this mailbox):
- `notmuch count --output=files folder:Gmail` = **238** vs **128** real on-disk files under
  `Gmail/{cur,new}` — 110 extra files from other folders/label-copies.
- `notmuch count --output=files folder:Logos` = **403**, of which **84** files are physically
  outside `Logos/{cur,new}`.

**Consequence**: a naive `notmuch count --output=files folder:X` is not merely the wrong
comparand's raw form — it is actively wrong even as a file count, because it is not scoped to the
folder's own path. The fix is (a) below: post-filter the `--output=files` result by literal path
prefix so only files physically under the target maildir directory are counted.

## Detection: the census freshness line

`email-census` (`.dotfiles` `census.nix`) implements three combined fixes:

- **(a) File-vs-file, path-prefix post-filtered**: count on-disk files via `himalaya envelope
  list`, and count indexed files via `notmuch search --output=files 'path:<acct>/cur or
  path:<acct>/new'` piped through `grep -cE '/<acct>/(cur|new)/'` to strip the cross-folder/
  cross-account duplicates the quirk above injects.
- **(b) Bounded tolerance, not strict equality**: divergence `Δ = |on-disk − indexed-files|`;
  tolerance `T = max(5, ceil(0.10 × on-disk))`. `[ok]` when `Δ ≤ T`, else `[STALE]`. 10% is
  chosen deliberately: it makes Logos's real residual (22/341 ≈ 6.5%, this mechanism's 22-unindexed-
  files anomaly — see Finding 3 / the Phase-7 follow-up) reachable today as `[ok]` while staying
  modest enough to still catch a genuinely far-behind index. The floor of 5 keeps small accounts
  from getting a zero-width tolerance. The threshold should be tightened once the follow-up task
  reduces the residual.
- **(c) Reindex-ran marker (informational secondary signal)**: `email-reindex` writes an
  ISO-8601 timestamp to
  `${XDG_STATE_HOME:-$HOME/.local/state}/email-agent/last-reindex` after its `notmuch new
  --no-hooks` call; `email-census` reads this file and surfaces `reindex=<ISO|never>` on the
  freshness line. The marker does **not** itself flip `[ok]`/`[STALE]` — it exists so the Stage 1
  gate (and autonomous/orchestrator mode especially) can distinguish "reindex never attempted"
  from "reindex ran, residual within tolerance," which the tolerance-only signal cannot
  distinguish on its own.

The canonical freshness-line format (quoted verbatim by every downstream site — census.nix,
wrapper-contracts.md §13, skill-email-cleanup SKILL.md's Stage 1 parser):

```
INBOX freshness  on-disk=<D>  indexed-files=<F>  divergence=<Δ>  tol=<T>  reindex=<ISO|never>  [ok|STALE]
```

`[ok]` when `Δ ≤ T` (file-vs-file within tolerance), else `[STALE]`. `skill-email-cleanup`'s
`--all` Stage 1 **staleness gate** parses this line and will not present a whole-mailbox bucket
approval while it reads `[STALE]`. If the line is absent (an `email-census` predating this redesign),
coverage is treated as *unverified* and a visible notice is emitted — never assumed fresh.

Live example (2026-07-13, current mailbox, new gate): Gmail `on-disk=128 indexed-files=128
divergence=0 tol=13 reindex=<ISO> [ok]`; Logos `on-disk=341 indexed-files≈319 divergence≈22
tol≈35 reindex=<ISO> [ok]` — both accounts reach `[ok]` under the new tolerance-based gate on the
same mailbox where the old equality gate left Logos permanently `[STALE]`.

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
- Also writes the (c) reindex-ran marker: after `notmuch new --no-hooks` completes, it
  writes an ISO-8601 timestamp to
  `${XDG_STATE_HOME:-$HOME/.local/state}/email-agent/last-reindex`, which `email-census` reads
  back as `reindex=<ISO|never>` on the freshness line.

## End-to-end flow

```
/email --all
  └─ Stage 1: email-census
       └─ parse "INBOX freshness … on-disk=<D> indexed-files=<F> divergence=<Δ> tol=<T>
                  reindex=<ISO|never> [ok|STALE]"
            ├─ [ok]     → proceed to count-probe + sweep (coverage honored; Δ ≤ T)
            └─ [STALE]  → report on-disk vs indexed-files divergence beyond tolerance
                          ├─ interactive: offer email-reindex → re-census → re-check → sweep
                          └─ autonomous: reindex=never  → STOP, report divergence + `email-reindex`
                                        │                  command (never attempted)
                                        └─ reindex=<ISO> → report as persistent residual
                                                            (candidate follow-up, not a stop)
```

## Cross-references

- wrapper-contracts.md §13 — index freshness, `email-reindex`, no-auto-indexer (frozen-repo facts)
- skill-email-cleanup SKILL.md — Stage 1 staleness gate + Staleness Remediation section
- archive-mode-risk.md — `--archive` coverage likewise depends on a fresh index
