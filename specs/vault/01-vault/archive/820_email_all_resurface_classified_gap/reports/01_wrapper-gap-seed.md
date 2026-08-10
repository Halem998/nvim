# Task 820 — `/email --all` cannot re-surface already-classified mail for review

**Status**: not_started
**Created**: 2026-07-05
**Task type**: meta (email extension) — fix spans the email extension skill AND the
`.dotfiles` wrapper binaries (cf. `.dotfiles` tasks 72 / 79)
**Origin**: discovered during a live `/email --logos --all` run (Mail repo maildir)

## Summary

`skill-email-cleanup` `--all` (whole-mailbox mode) cannot rebuild a review set for a mailbox
that has **already been fully classified** in a prior session. When every in-scope message
already carries a durable `+proposed-*` tag, the wrapper-only interface exposes **no sanctioned
read-out** of those tagged messages' per-message records (Message-ID, sender, subject,
proposed_action, confidence). The Stage 2.5 consolidated bucket review therefore cannot be
constructed, and the actionable `proposed-delete` / `proposed-archive` candidates cannot be
carried into an approved manifest for execution. Default mode is equally stuck: its cursor query
excludes all `+proposed-*`-tagged messages, so a fully-tagged inbox classifies 0.

The skill explicitly promises "To deliberately revisit previously-declined messages, use
`/email --all`" — that promise is currently unbacked for an already-fully-classified mailbox.

No mutation is possible for this state through the sanctioned path, and the skill (correctly)
forbids raw `notmuch`/`himalaya` as an escape hatch.

## Reproduction (live, Logos INBOX, 2026-07-04/05)

- `--account logos` gate now PASSES (`.dotfiles` task 79 landed; all five wrappers accept
  `--account logos` and executed read-only).
- `folder:Logos` INBOX = 62 messages, **0 un-tagged (new)**. Existing durable tags:
  `proposed-delete`: 12 (actionable), `proposed-archive`: 3 (actionable),
  `proposed-unsure`: 42, `proposed-keep`: 5 — total 62 ✓.
- `email-classify` is **emit-on-change**: re-classifying the actionable buckets
  (`folder:Logos and (tag:proposed-delete or tag:proposed-archive)`) emits **0 records**; a
  plain `folder:Logos --limit 50` run matched 62, processed 50, emitted only 7 (the churn set),
  never the delete/archive ones.
- `email-census` accepts **no query positional** — always whole-account census; cannot
  enumerate a `tag:proposed-delete` slice.
- `email-delete-confirmed` / `email-archive-confirmed` plan over an **approved manifest**
  (`--manifest`), not over `proposed-*` tags — a dry run cannot list the tagged set.
- The prior session's `candidate-manifest.jsonl` (the single per-message readout) is a single
  overwritten file — the actionable records are gone from the wrapper-accessible surface.

## Root cause

The `--all` design (skill-email-cleanup Stage 2) assumes classify can (re)emit records for the
messages it processes. `email-classify` instead only emits messages whose tag it *changes*, and
no other wrapper re-reads `+proposed-*` tags into per-message records.

## Candidate fixes

**Wrapper side (`.dotfiles` `modules/home/email/agent-tools/`)** — pick one, preserving
wrapper-only / folder-scoped / propose-review-confirm-execute invariants and the frozen
`MAX_BATCH_SIZE=50` contract:

1. `email-classify --emit-tagged` (a.k.a. `--rebuild-candidate`): read-only mode that writes the
   candidate manifest from existing `+proposed-*` tags for a query, without re-computing or
   re-tagging. Cleanest — keeps the wrapper the single source of per-message records.
2. `email-census "<query>"` positional emitting a read-only per-message envelope+tag listing so a
   `tag:proposed-*` slice can be enumerated.
3. Persist per-run candidate manifests (timestamped, not overwritten) so a prior session's
   classification can be recovered rather than lost.

**Extension side (this repo — `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md`)**:

4. Teach `--all` Stage 2 to detect the "0 new, all residual" state and drive the review off the
   wrapper read-out (fix 1/2) instead of off emit-on-change classify. Update the skill's
   residual-pass contract accordingly.

Recommended: fix 1 (wrapper `--emit-tagged`) + fix 4 (skill consumes it). This task should spawn
a `.dotfiles` sub-task for the wrapper change (mirroring the 72/79 cross-repo pattern) and carry
the skill change here.

## Provenance

Originally filed in error as task 30 in the **Mail** deployment repo; moved here (the canonical
email-extension source repo) as task 820 at the user's direction. No mutation occurred during
discovery — only read-only `email-census` and local tag-only `email-classify` probes ran; Logos
INBOX tag counts were stable before and after. The Mail maildir is left exactly as found.
