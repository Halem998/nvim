# Safety Invariants (Operational Contract for `email`-Typed Work)

The non-negotiable operating rules for every `email` task, `/email` invocation, and
`email-implementation-agent` dispatch. Each invariant states the rule and names the domain file
carrying its full derivation; nothing here is optional or context-dependent.

## Wrapper-Only

Agents may invoke ONLY these five nix-built binaries by name: `email-census`, `email-classify`,
`email-archive-confirmed`, `email-delete-confirmed`, `email-unsubscribe-extract`. Raw
`himalaya` / `notmuch` / `msmtp` / `secret-tool` calls are prohibited.

Sanctioned NON-wrapper exceptions (index/sync only, never mail mutation):

- the group-scoped `mbsync` reconcile invoked by `/email --sync`, and
- the `email-reindex` operator helper (index-only `notmuch new --no-hooks`).

A raw `notmuch new` stays forbidden — it triggers `preNew = mbsync -a`.
See `wrapper-contracts.md` §1 (binaries, safety classes) and §13 (reindex).

## Two-Layer Enforcement

1. **`mail-guard.sh` PreToolUse hook** — social/technical layer 1, per-machine, may be
   gitignored. Allowlists the five wrapper binaries and denies raw destructive mail commands.
2. **The nix-built wrapper source itself** — layer 2, always present: hash check, staleness,
   batch cap, and state file are baked into the binaries.

Neither layer is sufficient alone. The guard allowlists the five binaries **by NAME only**, not
by account or flag; multi-account support was added as an `--account` flag on those same five
binaries rather than as new binary names, so the guard's allowlist is unaffected by the account
dimension and needed no change for it. See `wrapper-contracts.md` §8.

## Propose-Review-Confirm-Execute

Mutation binaries are dry-run by default; `--execute` requires `--confirm-manifest <sha256>`
over a human-reviewed, git-tracked manifest. The mandatory human review gate (per-message or
bucket) precedes every mutation, always. Full lifecycle:
`../patterns/propose-review-confirm-execute.md`; flag contract: `wrapper-contracts.md` §2;
approval provenance: §6.

## Delete Is Himalaya-Level Only

Delete is an IMAP/maildir-level Himalaya operation, never a raw filesystem `rm` against Maildir.
Move-to-Trash and `--expunge-trash` are independently human-gated hops with separate state
files. See `wrapper-contracts.md` §7 and the reversible-vs-hard boundary in
`archive-mode-risk.md`.

## `$PATH` Precondition

Agents must verify the wrapper binaries are on `$PATH` (nix/home-manager built) before invoking
any of them, and fail with an actionable message (`run home-manager switch`) rather than a raw
"command not found". See `wrapper-contracts.md` §9.

## Index-Freshness Gate

Classification reads notmuch and there is no auto-indexer, so `--all` runs a staleness gate
before claiming whole-mailbox coverage: it compares the `email-census` freshness line's on-disk
file count against a path-prefix post-filtered indexed-files count (a file-vs-file comparison
within a bounded tolerance, not strict equality) and reconciles with `email-reindex` when the
divergence exceeds tolerance. Never present a bucket approval as whole-folder coverage while the
line reads `[STALE]`. Full mechanism: `staleness-detection.md`; frozen facts:
`wrapper-contracts.md` §13.

## Default-Mode Cursor

Bare `/email` is bounded to 50 candidates per pass. The durable `+proposed-*` tags — expressed
ONLY as an `email-classify` QUERY exclusion, never as a wrapper flag — make successive runs step
forward instead of re-classifying the same newest 50. Pagination contract:
`wrapper-contracts.md` §10.

## Sub-50 Transparent Drain (`--all`)

The approved set is split caller-side into ≤50-lines-per-action sub-manifests
(`MAX_BATCH_SIZE=50` is FROZEN — never raised; the wrapper hard-refuses over cap and never
auto-chunks). After the single consolidated bucket approval the drain is mechanical and
progress-only, with idempotency via the wrapper's per-split `<manifest>.state.jsonl` only. Only
the read/tag-only classify sweep may run in the background; every review gate and every execute
call runs in the root session. See `wrapper-contracts.md` §4, §5, §5a and
`../patterns/bulk-bucket-review.md`.

## Mtime-Preserve / Expiry-Stop

Split sub-manifests carry the ORIGINAL approval mtime (`touch -r`); an expired split
(> `PLAN_EXPIRY_DAYS = 7`) STOPS the drain with a residual report — never a silent
re-timestamp, never a widened approval window. See `wrapper-contracts.md` §5b.

## Archive Extra Gates (`--archive`)

A second blast-radius-naming confirmation, a corroborated (rule-tier) confidence bar for bulk
deletes, reversible-then-hard two-phase deletes (`--expunge-trash` opt-in only), a bounded
per-account pilot gate before full scale (a Gmail pilot-ack never licenses a Logos archive-scope
run, or vice versa), and never auto-chaining `/email --sync` after a drain. These are ADDITIONS
on top of the standard gates, never replacements. Full rationale and per-account blast radius:
`archive-mode-risk.md`.

## Account Isolation, Folder-Scoped Only

The account (`--account <gmail|logos>` / `--logos`, default `gmail`) is resolved once per
invocation and threaded unchanged through every wrapper call; scoping is expressed exclusively
as `folder:` query tokens. An unknown `--account` value is rejected loudly, never coerced to
Gmail. Query forms, the deliberately-unused `tag:<account>` scheme, and per-account liveness:
`index-architecture.md`.
