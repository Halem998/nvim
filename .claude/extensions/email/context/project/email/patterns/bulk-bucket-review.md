# Bulk Bucket Review (Sender/Domain Buckets, One Consolidated Approval)

How `mode=all` cleanup turns thousands of per-message classification candidates into ONE
human decision without weakening the mandatory review gate. Email-layer pattern: it is tied to
the sender/domain taxonomy, the wrapper's confidence constants (wrapper-contracts.md §5c), and
the recall-on-keep-bias standard. The domain-agnostic execution half lives at the agent-system
layer: `.claude/context/patterns/batch-drain-loop.md`.

## When to Use

- A whole-scope classify sweep has produced a candidate set far too large for per-message
  review (hundreds to tens of thousands of records).
- Candidates cluster naturally by sender/domain, and the user's real decision is per sender
  ("all of `marketing@foo.com` can go"), not per message.

## Bucket Construction

1. Deduplicate the accumulated candidate records by `message_id` (last record wins).
2. Group by **sender domain**; for freemail/shared domains (gmail.com, yahoo.com, outlook.com,
   proton.me, ...) group by the **full sender address** instead — a domain bucket must never
   mix unrelated humans.
3. Attach to each bucket: message count, proposed action(s), the `min()` confidence rollup,
   and a `[new]` / `[residual]` label (residual = messages carrying a `+proposed-*` tag from
   an earlier pass, i.e. previously seen and not acted on).

## Confidence Rollup: `min()`, Never `avg()`

A bucket's decision confidence is the MINIMUM across its member messages for the proposed
action. One weak match must not license bulk-approving strong ones: an `avg()` (or `max()`)
rollup would let one 0.98 custom-rule hit smuggle a pile of 0.55 keyword-fallback guesses
through a bulk approval.

## Option-Availability Gating (the 0.90 Delete Gate)

The `>= 0.90` delete-confidence bar is enforced by WHICH options are rendered, never by
post-hoc filtering of an approved set:

- `min()` delete confidence `>= 0.90` -> the bucket MAY offer "approve all as DELETE".
- below 0.90 -> the delete option simply does not exist for that bucket; the strongest offered
  options are "approve all as ARCHIVE" / "review individually" / "skip".
- Archive scope (`--archive`) tightens this further: bulk delete additionally requires a
  deterministic rule-tier reason, not just a number — see `domain/archive-mode-risk.md`.

Rationale: an option that never appears cannot be mis-selected, and no later code path has to
remember to filter it out.

## Presentation Idiom (borrowed from skill-fix-it Steps 6-7)

AskUserQuestion with `multiSelect: true`, one option per bucket:

```json
{
  "question": "Approve cleanup buckets (N buckets, M messages total):",
  "header": "Bucket approval",
  "multiSelect": true,
  "options": [
    { "label": "Select all (N buckets)", "description": "Approve every bucket at its proposed action" },
    { "label": "[new] foo.com (312 msgs, delete, min-conf 0.98)", "description": "custom-domain-delete:foo.com" },
    { "label": "[residual] bar.org (41 msgs, archive, min-conf 0.60)", "description": "keyword-fallback:newsletter — previously seen, declined" }
  ]
}
```

- Include the leading "Select all (N buckets)" option only when there are MORE than 20 buckets
  (the fix-it >20 idiom).
- Order buckets by descending size; split across successive AskUserQuestion calls when the
  bucket count exceeds one question's option capacity.
- Selecting nothing exits gracefully — no manifest is written, no mutation happens.

## Invariants This Pattern Must Never Weaken

- **The bucket approval IS the mandatory human review gate** for `mode=all` — it runs in the
  ROOT SESSION via direct execution, never in a background job or subagent.
- Wrapper-only: bucket data comes from `email-classify` candidate manifests (accumulated
  caller-side); no raw `himalaya`/`notmuch` call ever constructs or inspects a bucket.
- Approval produces a logically-approved set that is then split into ≤50-per-action
  sub-manifests and drained (batch-drain-loop pattern) — `MAX_BATCH_SIZE=50` is frozen and is
  never raised to "fit" a big bucket.
- After this one approval there is NO further prompt; anything that would need a new decision
  (expired manifest, archive-scope second confirmation) STOPS instead of re-prompting inside
  the drain.
