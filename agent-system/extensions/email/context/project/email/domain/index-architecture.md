# Index Architecture: Accounts, Folder Scoping, and the notmuch Layer

How the `/email` stack layers Himalaya, notmuch, and mbsync over a multi-account maildir, and
why account scoping is expressed EXCLUSIVELY as `folder:` query tokens. Contract facts come from
`wrapper-contracts.md` (§2 account enum, §11 folder tokens, §11a mbsync channel mapping);
freshness behavior lives in `staleness-detection.md`.

## Key Technologies

- **Himalaya**: CLI email client (maildir backend) driving read/move/delete operations. Its
  per-folder envelope count resolves the maildir++ folder mapping and is the authoritative
  on-disk ground truth.
- **notmuch**: local tagging/search index used for classification tags and Message-ID lookup,
  across both the Gmail and Logos accounts (folder-scoped, never tag-scoped).
- **mbsync**: IMAP sync engine reconciling local maildir with the account's server (Gmail or
  Logos/Protonmail Bridge) after mutation. Always a single, explicit group — never `mbsync -a`.

## Account Isolation, Folder-Scoped Only

Multi-account support (`--account <gmail|logos>` / `--logos`, default `gmail`) is resolved once
per invocation and threaded unchanged through every wrapper call. Account scoping is expressed
EXCLUSIVELY as `folder:` query tokens passed through the `email-classify` QUERY positional — no
wrapper flag exists or is needed for folder scoping.

### The Three `folder:` Query Forms (live-verified)

| Form | Example | Live behavior |
|------|---------|---------------|
| Glob (broken, never in wrapper source) | `folder:Gmail*` | 0 matches — notmuch `folder:` does not glob |
| Bare exact-match (the `/email` wrappers, by design) | `folder:Gmail` | INBOX-only exact maildir-folder match |
| Regex (aerc querymap) | `folder:/Gmail/` | Whole-account match across all folders |

The wrappers use the **bare exact-match** form deliberately: an `/email` run scopes to one
concrete maildir folder at a time (INBOX by default, the account's archive folder under
`--archive`), never to a whole account. The regex form's whole-account reach is exactly the
blast radius the wrappers are designed not to have; the glob form silently matches nothing and
would make a sweep claim coverage it does not have.

### The `tag:<account>` Scheme (live, deliberately unused)

A `tag:<account>` scheme (`tag:gmail` / `tag:logos`) is live — populated by notmuch's `postNew`
hook and exactly matching `folder:/Gmail/` / `folder:/Logos/`. The wrappers nonetheless scope by
`folder:` tokens only and never rely on it: tags lag until a full `notmuch new` runs (the
sanctioned `email-reindex` helper passes `--no-hooks`, so `postNew` auto-tagging is skipped —
see `staleness-detection.md`), which would make tag-scoped queries silently under-cover.

### Per-Account Tokens and Channels

See `wrapper-contracts.md` §11 for the verified per-account inbox/archive token table and §11a
for the mbsync channel mapping. No path for either account ever resolves to a whole-mailbox
`mbsync -a`; the channel is always a single, explicit group (`gmail` or `logos`).

Per-account archive semantics (blast radius, gates) are in `archive-mode-risk.md`.

## `/email --logos` Is Additive, Live, and Never a Silent Fallback

The account selector, folder-token queries, and pilot-gate scoping for `account=logos` are
implemented, documented, and accepted by the wrapper binaries (`--account <gmail|logos>`,
`wrapper-contracts.md` §2, verified 9/9 against the `.dotfiles` wrapper suite via
`verify_logos_wrapper_contract_close_phase6`). Every `--logos` invocation is routed through a
light step-1 liveness check before any wrapper call. An unknown `--account` value is rejected
loudly with a non-zero exit — never silently coerced to Gmail. A bare `/email` (Gmail, the
default) is unaffected and remains byte-for-byte unchanged.

## Cross-References

- `wrapper-contracts.md` §2, §11, §11a — account enum, folder tokens, mbsync groups (frozen)
- `staleness-detection.md` — index lag, the freshness gate, `email-reindex`
- `archive-mode-risk.md` — per-account archive blast radius and extra-caution gates
- `safety-invariants.md` — the account-isolation invariant in its enforcement context
