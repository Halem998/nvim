# Pattern: Propose -> Review -> Confirm -> Execute

The manifest lifecycle every mutation in this extension follows. No agent or skill may skip a
stage or collapse two stages into one.

## 1. Propose (dry-run / tag-only, no mutation)

`email-census` and `email-classify` run against the live mailbox but never mutate maildir/IMAP
state. `email-classify` applies provisional `+proposed-*` notmuch tags (local index only) and
emits a **candidate manifest**: one JSON object per line, keyed on Message-ID, with a
`proposed_action` and `confidence`.

## 2. Review (human-in-the-loop, mandatory)

The candidate manifest is presented to the user for review — via `AskUserQuestion` in an
agent/skill context, or an aerc tagged view in an interactive session. This stage cannot be
automated away: no confidence threshold, however high, licenses skipping human review.

## 3. Confirm (produces the approval artifact)

Approving a message (or a set of messages) appends its Message-ID to an **approved manifest**
(git-tracked, separate file from the candidate manifest). The sha256 of the approved manifest's
raw bytes is computed. This hash — not the manifest's logical content — is what
`--confirm-manifest` verifies, so any edit to the approved manifest after computing the hash
invalidates it.

## 4. Execute (the only path to mutation)

`email-archive-confirmed` / `email-delete-confirmed` are invoked with
`--execute --confirm-manifest <sha256>`. The wrapper recomputes the hash over the manifest file
it reads and refuses on mismatch. Execution updates a companion execution-state file
(`<manifest>.state.jsonl`) tracking per-ID status, so partial/failed runs are safely re-runnable
(already-`executed` IDs are skipped).

## 5. Verify (diff, never re-derive)

After execution, the actually-mutated ID set is determined by diffing the execution-state output
against the approved manifest — never by re-deriving "what should have happened" from the
candidate manifest or from re-running classification.

## Why This Shape

- **Git-tracked manifests** give an audit trail independent of mailbox state.
- **sha256-over-raw-bytes confirmation** makes the approval artifact tamper-evident.
- **Untrusted-data / lethal-trifecta rationale**: email subject/body/sender content can contain
  adversarial instructions (prompt injection). Because mutation is driven only by an inert,
  pre-approved manifest file — never by live message content interpreted at execute time — a
  malicious email cannot cause a mutation on its own, no matter what it says.
- **Freeze sync during bulk ops**: batch mutation runs should not interleave with a live mbsync
  reconcile, to avoid mutating a maildir view that is mid-sync.
