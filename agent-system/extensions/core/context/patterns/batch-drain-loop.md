# Batch Drain Loop (One Approval, Many Capped Batches, Safe Resume)

Domain-agnostic pattern for executing MANY approved mutations through a tool that hard-caps
its per-invocation batch size, with exactly ONE human decision and no per-batch re-prompting.
Its sibling covers the read side: chunked-sweep pagination for a read-only/tag-only tool that
exposes a `--limit` cap but no offset. Distilled from the email extension's `--all` cleanup
mode; applies to any capped bulk-mutation tool (API rate windows, migration
runners, batch importers).

## Problem Shape

- A trusted executor enforces `MAX_BATCH <= N` per call and REFUSES (never auto-chunks)
  oversized inputs.
- The approved workload is far larger than N.
- The human has already made the real decision once (a consolidated review); re-prompting per
  batch trains reflexive approval and destroys the value of the gate.
- Runs can be interrupted; re-running must never re-execute completed work.

## The Pattern

### 1. Single upstream approval, then mechanical execution

Gate the WHOLE workload behind one consolidated human approval (see the domain's bulk-review
stage). Everything downstream is mechanical and progress-only. If a situation arises that
would genuinely need a new decision (expiry, scope change, precondition failure), STOP and
report — never re-prompt mid-drain, never proceed silently.

### 2. Split caller-side to the executor's cap

Partition the approved set into sub-batches of <= N items per enforced dimension BEFORE any
execute call. If the executor's cap is per-category (e.g. per action type per file), pack
complementary categories into the same sub-batch so each category independently passes —
fewer batches, same safety.

### 3. Preserve the approval timestamp on derived artifacts

If approvals expire (staleness windows), derived sub-batch files must carry the ORIGINAL
approval time (`touch -r <original> <split>`), so splitting can never silently extend the
window. On an expired sub-batch: STOP the drain and report the un-executed residual with
re-approval instructions. Never re-timestamp.

### 4. Idempotency via the executor's own state, no second ledger

If the executor keeps per-batch execution state (e.g. a `<batch>.state` companion that marks
items `executed`/`failed`), rely on it EXCLUSIVELY: resuming = re-running the same drain loop;
completed items are skipped by the executor itself. A caller-side shadow ledger will
eventually disagree with the executor's truth — do not keep one.

### 5. Progress-only reporting with a resume pointer

After each sub-batch, surface an aggregate line:
`"X of Y batches processed — Z items executed, W failed; resuming at batch #k"`.
Item-level failures are recorded and do NOT stop the loop; executor-level refusals
(verification mismatch, expiry, cap violation) DO.

## Sibling: Chunked Sweep for `--limit`-Only Readers

When the read/classify side exposes only a result cap (`--limit`) and no offset, paginate by
QUERY, not by position:

- **Exclusion cursor**: if processing leaves a durable mark on each processed item (a tag, a
  status field), loop on `<scope> AND NOT <mark>` with `--limit CHUNK` until a chunk returns
  0 — deterministic forward progress, complete for unmarked items. Document the caveat that
  already-marked items are skipped, and surface their count rather than hiding it.
- **Count probe**: a `--limit 0` call that discloses the total match count (without processing
  anything) gives pre-sweep estimates and residual counts for free — check whether the tool
  logs "matched TOTAL, processing first LIMIT".
- **Accumulate before the next chunk**: if the tool OVERWRITES its output artifact per call,
  append each chunk's output to a caller-owned accumulator immediately after the call.
- Only this read-only/mark-only sweep may run in the background. Anything interactive (the
  consolidated approval) and anything mutating (the drain) runs in the root session, direct
  execution.

## Invariants

1. Never raise or bypass the executor's cap — split and loop instead (the cap is usually
   someone's frozen safety contract).
2. Exactly one human approval per workload; zero prompts inside the drain; STOP (don't ask,
   don't proceed) when a new decision would be needed.
3. Executor-owned state is the only execution ledger.
4. Derived batch artifacts inherit the approval timestamp; expiry stops the loop with a
   report.
5. Background only the non-interactive, non-mutating sweep — never a human gate, never a
   mutation.
