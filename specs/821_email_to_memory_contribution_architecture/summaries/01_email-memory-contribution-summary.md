# Implementation Summary: Task #821

**Completed**: 2026-07-12
**Duration**: single-pass design task

## Overview

Task 821 designed the email-to-memory preference contribution architecture: how confirmed
`skill-email-cleanup` decisions get routed into the memory vault as sender/domain-aggregated
preference memories. All six plan phases produced a single design specification document at
`.claude/extensions/email/context/project/email/design/email-to-memory-preferences.md`,
resolving all eight gaps (G1-G8) the team-research phase identified, with the identity key
verified against a real, genuinely read-only sample of live mail rather than shipped as
provisional-unverified.

## What Changed

- `.claude/extensions/email/context/project/email/design/email-to-memory-preferences.md` —
  created. The design deliverable: capture point/harvest trigger/evidentiary rules (§1),
  identity-key normalization + real-sample verification (§2), memory schema/tally/namespace
  (§3), deterministic dedup + operation mapping (§4), retrieval/distill guardrails + gate + 822
  scope recommendation (§5), read-back contract seed for task 823 (§6), deferred design notes
  (§7), and the `email-preferences.md`-is-a-distinct-layer note (§8), plus a G1-G8 resolution
  index table.
- `specs/ROADMAP.md` — added a new "Email/Memory Integration" subsection under Phase 2 with two
  hand-authored entries: "Preference-memory read-back for email-classify" and "Generalize
  confirmed-decision harvest beyond email" (meta tasks do not auto-annotate ROADMAP.md).
- `specs/821_email_to_memory_contribution_architecture/plans/01_email-memory-contribution.md` —
  all six phases and the Testing & Validation checklist marked complete with per-item completion
  notes and deviation annotations.
- `specs/821_email_to_memory_contribution_architecture/progress/phase-{1..6}-progress.json` —
  created, one per phase.

## Decisions

- **Identity key verified, not provisional**: `email-census`/`email-classify` were available on
  `$PATH`. Rather than blocking or falling back to a provisional-unverified key, ran a
  genuinely read-only `email-classify --account gmail --emit-tagged` sample (confirmed
  side-effect-free per wrapper-contracts.md §10a — no `notmuch tag` call) against 2,656
  already-tagged messages from prior classify passes, yielding 2,128 re-emitted messages / 751
  unique sender strings. This gave concrete evidence for freemail multiplicity, sender-side
  plus-addressing, Gmail's DMARC-rewrite "via" pattern, and confirmed List-Id is structurally
  absent from the manifest schema (not merely untested).
- **Redaction**: domain stays plaintext, local-part is hashed (`sha256[:12]`) in the stored key —
  chosen because `memory-retrieve.sh` has no namespace filter today (verified by reading the
  script), so plaintext addresses risk leaking into unrelated `<memory-context>` blocks.
- **`/distill` exemption mechanism**: chose a topic-prefix exemption on the purge filter over an
  email-side `retrieval_count` increment, to avoid introducing a second uncoordinated writer to
  `memory-index.json`.
- **822 scope**: per the orchestrator's documented default, recommended folding revocation/edit
  UX, cross-account scoping, archive-scope isolation, and a minimal success signal into task 822
  (queued, `dependencies: [821]`, confirmed in `specs/state.json`) rather than spawning 823/824
  for those items — only the read-back "preference engine" (G8) remains a genuine standalone
  task-823 candidate.

## Plan Deviations

- **Task 2.2** altered: "prefer List-Id over From for lists" could not be specified as a
  preference rule because the `email-classify` manifest schema has no `List-Id` field at all
  (verified during the real-sample check); documented instead as a hard, schema-level
  limitation.
- **Task 3.1** altered: the topic namespace was account-prefixed to
  `email/preferences/{account}/{key}` (rather than bare `email/preferences/{key}`) to satisfy
  the Phase 5 cross-account scoping recommendation.
- **Task 5.5** altered: per explicit orchestrator instruction, took the plan's documented
  fold-into-822 default without an interactive `AskUserQuestion` confirmation, since task 822 is
  queued in the same batch and depends on 821.

## Verification

- Build: N/A (design/documentation task)
- Tests: N/A (no production code written; Testing & Validation checklist items verified
  directly against the design document's own content — see plan file)
- Files verified: Yes — design document, ROADMAP.md entries, and plan checklist all confirmed
  present and internally consistent.

## Notes

- The only live-system interaction performed was the read-only `email-classify --emit-tagged`
  verification call (§2.3 of the design doc); no `--execute`, no `notmuch tag` mutation, no
  edits to the frozen wrapper or to `email-preferences.md`'s static rule table.
- Task 822 (`Implement email cleanup to memory vault contribution`) is the next consumer of this
  design and should incorporate the §5.5 scope additions into its own plan.
