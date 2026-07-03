# Archive-Mode Risk (`--archive`, All Mail Scope)

Why archive-scope (`folder:Gmail/.All_Mail`) email operations get extra-caution gates beyond
the standard propose-review-confirm-execute flow, and what those gates are. Companion to
`skill-email-cleanup`'s "Archive Scope" and "Pilot Gate" sections; contract facts come from
`wrapper-contracts.md` (§10 pagination, §11 folder tokens).

## The Blast Radius

| Property | INBOX (`folder:Gmail`) | All Mail (`folder:Gmail/.All_Mail`) |
|----------|------------------------|--------------------------------------|
| Approximate size | hundreds | ~64,000 messages |
| Content age | recent, familiar | years of archive-of-record history |
| Classifier validation | rules hand-tuned against inbox traffic | never validated against archive-era senders |
| Cost of a wrong delete | annoying | potentially irreplaceable history |

Two multipliers compound in archive scope: **volume** (a single bulk-approved bucket can cover
thousands of messages) and **rule drift** (the deterministic classifier constants —
wrapper-contracts.md §5c — were tuned on current inbox traffic; a domain that is
delete-worthy today may have sent important mail in 2016). Extra gates are proportionate to
that product, not paranoia.

## The Reversible-vs-Hard Boundary

The wrapper's delete path is two independent hops (wrapper-contracts.md §7):

1. **Reversible**: `email-delete-confirmed --execute ...` moves messages to Trash. Recoverable
   until Trash is expunged (locally) and, server-side, per Gmail's Trash retention.
2. **Hard**: `email-delete-confirmed --expunge-trash --execute ...` flags `\Deleted` and
   expunges — unrecoverable after the reconcile.

**Archive-scope policy**: every delete stops at hop 1. Hop 2 (`--expunge-trash`) is opt-in
ONLY — a separate, explicit user request in a later invocation, with its own
`--execute --confirm-manifest` gate and its own state file. Never bundle the hops in one pass;
never expunge by default. This makes the worst credible archive-scope mistake "a pile of old
mail sitting in Trash", not "history destroyed".

## The Asymmetric Confidence Policy

Inbox rule (recall-on-keep-bias standard): delete may be bulk-proposed at `min()` confidence
`>= 0.90`.

Archive-scope rule (stricter, corroborated): a bucket receives a bulk-DELETE option only if:

1. `min()` confidence across the bucket is `>= 0.90`, AND
2. the match reason is a deterministic rule-tier reason (`custom-domain-delete:*` /
   `custom-sender-*`, 0.98 tier) — keyword-fallback reasons (`keyword-fallback:*`, the
   0.55-0.60 tier) NEVER license an archive-scope bulk delete, whatever the number says.

Asymmetry: bulk-ARCHIVE proposals (recoverable moves within the account) keep the standard
bar. The stricter bar applies exactly where irreversibility begins. Enforcement is by option
availability (the delete option is never rendered for a non-qualifying bucket), not post-hoc
filtering.

## The Extra Interaction Gates

1. **Second blast-radius-naming confirmation**: after the normal review/bucket approval and
   before any execute, a separate confirmation whose affirmative option names the scale and
   the folder verbatim: "Yes, operate on N archived messages in All Mail". Distinct wording is
   deliberate — a reflexive second "yes" to an identical prompt has no safety value.
2. **Pilot prerequisite**: full-scale archive scope is REFUSED until a bounded pilot pass
   (low-thousands slice, full flow, clean Stage-6 verify) has been run and explicitly
   acknowledged (`archive-pilot-ack.json`). The pilot also confirms or adjusts the sweep
   `CHUNK_SIZE` default (1000). See "Pilot Gate for `--archive`" in `skill-email-cleanup`.
3. **Never auto-chain `/email --sync`** after an archive drain. The mutation wrappers already
   run their own group-scoped `mbsync gmail` reconcile per executed run (frozen contract,
   wrapper-contracts.md §7a); the separate `--sync` skill — which can make expunged deletions
   permanent server-side — must remain a deliberate, human-initiated follow-up, never an
   automatic tail call.

## What Archive Scope Does NOT Change

- Wrapper-only invariant: All Mail scoping is purely the classify QUERY base token
  `folder:Gmail/.All_Mail` — no new binary, no wrapper flag, no raw `notmuch`/`himalaya`.
- `MAX_BATCH_SIZE=50` stays frozen; archive-scope drains loop over ≤50-per-action splits like
  any `--all` drain.
- The mandatory human review gate (per-message or bucket) still precedes every mutation; the
  archive gates are ADDITIONS on top of it, never replacements.
