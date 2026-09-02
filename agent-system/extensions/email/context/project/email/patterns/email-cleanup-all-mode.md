# `--all` Mode (`mode=all`): Whole-Mailbox Sweep, One Bucket Approval, Sub-50 Drain

This file is the COMPLETE and ONLY specification for `/email --all` mode's execution. It MUST be
followed exactly — there is no fuller version of this content anywhere else. The `` `--all` Mode ``
section of `skill-email-cleanup/SKILL.md` was extracted here per
`context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location
in `SKILL.md` sends an agent here whenever `mode=all` is dispatched.

The whole-mailbox operation. The wrapper's 50-cap disappears from the user's experience: the
classify sweep is unconditionally chunked, the human decision is ONE consolidated sender/domain
bucket approval, and execution is a mechanical drain of ≤50-per-action sub-manifests with
progress-only reporting. Never raise `MAX_BATCH_SIZE` — this mode exists precisely so that
looping in ≤50 splits replaces any temptation to touch the frozen wrapper.

**Pagination mechanism (ground-truth adapted)**: the round-2 design called for capturing the
in-scope message-ID list once and slicing it into `id:a or id:b ...` chunk queries. Phase-1
verification (wrapper-contracts.md §10) found that NO wrapper emits a complete message-ID list
for an arbitrary query, and capturing one any other way would require a raw `notmuch search` —
forbidden. Per the plan's pre-authorized fallback, the sweep therefore paginates with
`--limit`-based chunking driven by the QUERY positional:

- **New messages** (never classified): repeated
  `email-classify --account <account> --limit <CHUNK_SIZE> "<SCOPE_QUERY> and not
  tag:proposed-delete and not tag:proposed-archive and not tag:proposed-unsure and not
  tag:proposed-keep"` — each call tags everything it processes, so the exclusion query advances
  deterministically; the sweep of never-classified mail is COMPLETE (terminates when a chunk
  classifies 0).
- **Residual messages** (previously classified, e.g. seen-and-declined in earlier passes): one
  read-only re-emit pass per prior tag, `email-classify --account <account> --emit-tagged
  "<SCOPE_QUERY> and tag:proposed-<X>"` for each of `delete|archive|unsure|keep`. `--emit-tagged`
  derives `proposed_action` strictly from the message's existing `+proposed-<X>` tag (never
  recomputed from the live rule table, never re-tagged — wrapper-contracts.md §12), so a
  residual pass can never silently overwrite a prior human decision even if the classifier's
  rule table has drifted since the tag was applied. It also ignores `--limit`/`MAX_BATCH_SIZE`
  and processes the FULL per-tag match in one call — **the previously-documented completeness
  caveat (residual coverage bounded to `CHUNK_SIZE` per prior-tag bucket) no longer applies**:
  residual coverage is now complete by construction, not an estimate. (At very large per-tag
  bucket sizes — e.g. a fully-tagged multi-thousand-message archive — the per-message
  `notmuch show` read loop this mode uses may take noticeably longer; this is a performance
  characteristic, not a coverage gap.)

`CHUNK_SIZE = 1000` by default (tunable; confirm/adjust after the `--archive` pilot — see the
Pilot Gate section).

## Stage 1 (`--all`): Census + Staleness Gate + Pre-Sweep Estimate

1. Run `email-census --account <account>` for the folder/sender/date overview.
2. **Staleness gate (MANDATORY before an `--all` coverage claim)**: `--all`
   promises whole-mailbox coverage, but `email-classify` only sees what notmuch has indexed. When
   the notmuch index lags the on-disk maildir (no auto-indexer exists — wrapper-contracts.md §13),
   the sweep silently covers only the indexed subset. Parse the census output's
   `INBOX freshness  on-disk=<D>  indexed-files=<F>  divergence=<Δ>  tol=<T>  reindex=<ISO|never>
   [ok|STALE]` line (`email-census`; `on-disk` is himalaya's authoritative
   maildir FILE count, `indexed-files` is a path-prefix post-filtered `notmuch --output=files`
   FILE count for the exact maildir path — a file-vs-file comparison, never a deduped-message
   count; see staleness-detection.md for the full rationale):
   - **`[ok]`** (`Δ ≤ T`, i.e. `divergence <= tol` — a bounded tolerance, NOT strict equality):
     proceed to the count probe (step 3).
   - **`[STALE]`** (`Δ > T`): DO NOT silently proceed — a bucket approval over the indexed
     subset would misrepresent the mailbox. Surface the divergence explicitly (on-disk,
     indexed-files, divergence, tolerance) and route to the **staleness remediation** below (task
     824/827): offer to run the sanctioned reindex `email-reindex`, then re-run census and
     re-check freshness. Only continue the `--all` sweep once freshness reads `[ok]`, OR the user
     explicitly acknowledges partial coverage over the indexed subset for this run.
     - **Reindex marker and autonomous-mode behavior**: use the `reindex=<ISO|never>` field to
       distinguish "reindex never attempted" from "reindex ran, residual persists." In
       interactive mode this only changes the messaging (offer `email-reindex` either way). In
       **autonomous/orchestrator mode** (no human to prompt): if `reindex=never` AND `[STALE]`,
       STOP and report the divergence plus the `email-reindex` command to run — reindex has not
       been attempted this cycle. If `reindex=<ISO>` (recently ran) AND still `[STALE]`, do NOT
       STOP-loop on a repeat reindex; instead report the persistent residual as a candidate
       follow-up (the gap survived a reindex, so re-running it again is unlikely to help) and
       proceed per the interactive-mode acknowledgment path or continue to flag for the user.
   - If the census freshness line is absent (an older `email-census` predating this redesign), emit a
     visible notice that staleness could not be verified and treat coverage as unverified — never
     assume fresh.
3. **Count probe** (wrapper-only count oracle, wrapper-contracts.md §10, §12): run
   `email-classify --account <account> --limit 0 "<SCOPE_QUERY> and not tag:proposed-... (all
   four)"` and parse the `NOTE: query matched <total> message(s)` line for the new-message count
   N (no NOTE line = 0). This new-message probe stays on the mutating `--limit 0` NOTE-line
   oracle — untagged messages carry no `+proposed-*` tag, so there is nothing for a read-only,
   tag-derived mode to read here. It processes nothing and applies no tags, but DOES overwrite
   the candidate manifest — always run this probe before the sweep starts, never between sweep
   chunks.
   Then probe each of the four residual buckets with the read-only mode instead:
   `email-classify --account <account> --emit-tagged "<SCOPE_QUERY> and tag:proposed-<X>"` for
   each of `delete|archive|unsure|keep`, and count the resulting `candidate-manifest.jsonl` line
   count (`wc -l`) as R_delete, R_archive, R_unsure, R_keep respectively. `--emit-tagged` is
   genuinely read-only (no `notmuch tag` call — wrapper-contracts.md §12) and unbounded (no
   `--limit`/`MAX_BATCH_SIZE`), so each residual count is now the COMPLETE per-tag count, not an
   estimate.
4. Present a ONE-TIME estimate before starting:
   `"~N new + R previously-classified messages in scope (R_delete/R_archive/R_unsure/R_keep),
   ~ceil(N/1000) chunks, est. <time> — proceeding in background"`. This is informational, not an
   approval gate (the sweep is read/tag-only); but if N is very large the user can narrow the
   scope here.
5. **"0 new, all residual" status**: if the new-message count probe reports `N=0`, emit before
   Stage 2.5: `"0 new messages; R previously-classified messages across 4 tag buckets
   (R_delete/R_archive/R_unsure/R_keep) — proceeding directly to bucket review"`. In this case
   skip straight to the residual `--emit-tagged` pass (Stage 2 below) and Stage 2.5 — there is
   no new-message sweep to run or wait on.

## Stage 2 (`--all`): Chunked, Backgrounded, Read/Tag-Only Classify Sweep

The ONLY stage in this skill that may run in the background, because it is read/tag-only (the
`email-classify` binary never touches maildir/IMAP state). Start it as a SINGLE backgrounded
Bash job (`run_in_background`) that internally loops over all chunks:

```
ACCUMULATOR="$MANIFEST_DIR/sweep-accumulator-$(date +%Y%m%dT%H%M%S).jsonl"
PROGRESS_LOG="$ACCUMULATOR.progress.log"

# loop (inside ONE backgrounded job):
#   1. email-classify --account <account> --limit 1000 "<SCOPE_QUERY> and not tag:proposed-* (all four)"
#   2. append the candidate manifest to $ACCUMULATOR IMMEDIATELY (the wrapper overwrites
#      candidate-manifest.jsonl on every call — accumulate BEFORE the next chunk)
#   3. append a progress line to $PROGRESS_LOG: "chunk <i>: <count> classified, <running-total> total, <timestamp>"
#   4. stop when a chunk classifies 0 messages
# then one read-only --emit-tagged pass per prior tag (delete/archive/unsure/keep) — unbounded,
# not chunked (no --limit applies, full per-tag match processed in one call) — appending records
# to $ACCUMULATOR with a `"residual": true` field added per line, and logging it as one chunk
# entry in $PROGRESS_LOG.
```

Rules:

- The job invokes ONLY `email-classify` (by name) plus file plumbing (`cat`/`jq`/`cp` on
  manifest files it owns). Never a raw `himalaya`/`notmuch` call.
- Deduplicate the accumulator by `message_id` (last record wins) before Stage 2.5.
- **Crash/resume**: if the job dies mid-sweep, the progress log shows how far it got, and the
  tag-exclusion query makes restart safe — already-classified messages are excluded, so simply
  re-running the sweep loop resumes where it left off (the accumulator keeps prior chunks).
- Monitor the job from the root session; do NOT start Stage 2.5 until the sweep reports
  completion.

## Stage 2.5 (`--all`): Consolidated Bucket Review (mandatory stop, ROOT SESSION)

The single human decision point for the whole mailbox. Runs in the root session via direct
execution — NEVER in the background, NEVER in a subagent.

1. **Bucket construction**: group deduplicated accumulator records by sender domain; for
   freemail/shared domains (gmail.com, yahoo.com, outlook.com, proton.me, etc.) bucket by the
   full sender address instead.
2. **Per-bucket confidence rollup**: roll up with `min()` across member messages per proposed
   action — one weak match must NOT license bulk-approving strong ones.
3. **Option-availability gating (the 0.90 delete gate)**: a bucket receives an
   "approve all as DELETE" option ONLY if its `min()` delete confidence is `>= 0.90`. A
   sub-0.90 bucket's strongest offered options are "approve all as ARCHIVE" / "review
   individually" / "skip". The gate is enforced by WHICH options exist, never by post-hoc
   filtering of an approved set.
4. **Residual labeling**: records with `"residual": true` came from previously-classified
   messages (detectable via their durable `+proposed-*` tags). Present residual buckets
   labeled `[residual]` and new buckets labeled `[new]` so the user can distinguish a fresh
   backlog from previously-seen-and-declined mail; also report the aggregate residual counts
   from Stage 1 (including any residual beyond the bounded re-classify coverage).
5. **Presentation idiom** (reuse `skill-fix-it` Steps 6-7): AskUserQuestion with
   `multiSelect: true`, one option per bucket
   (`label: "<domain> (<count> msgs, <action>, min-conf <c>)"`), and — when there are more
   than 20 buckets — a leading `"Select all (<N> buckets)"` option. Split across successive
   AskUserQuestion calls when the bucket count exceeds one question's option capacity,
   ordered by descending bucket size. Selecting nothing exits gracefully with no mutation.
6. The outcome is a logically-approved set: every message in every approved bucket, with its
   approved action. Messages in unapproved buckets are left untouched (their `+proposed-*`
   tags remain, making them detectable as residual in future runs).

There is NO further approval prompt after this stage: the split/drain stages below are
mechanical and report progress only.

## Stage 3 (`--all`): Materialize the Approved Manifest

Write every approved (message, action) pair from Stage 2.5 into ONE approved manifest file
(JSONL, wrapper schema, git-tracked), e.g.
`$MANIFEST_DIR/approved-all-$(date +%Y%m%dT%H%M%S).jsonl`. This file's mtime IS the approval
time — the `PLAN_EXPIRY_DAYS=7` clock for the entire drain starts here and is never reset.

## Stage 4 (`--all`): Split into ≤50-Per-Action Sub-Manifests

`enforce_batch_size` hard-refuses (never auto-chunks) any manifest with more than 50 lines for
the invoked action (wrapper-contracts.md §5a), so the skill splits BEFORE any execute call:

1. Partition the approved manifest by action (`archive` lines, `delete` lines).
2. Cut each action's lines into groups of ≤ 50, in manifest order.
3. **Pack pairwise**: where both actions have a group at the same index, write the ≤50 archive
   lines AND the ≤50 delete lines into ONE split file — each action independently passes its
   own binary's per-action cap (the caps are per action, per file), halving the file count.
   E.g. 137 archive + 60 delete → splits: (50a+50d), (50a+10d), (37a) = 3 files instead of 5.
4. Name splits predictably: `<approved-manifest-basename>-split-01.jsonl`, `-split-02.jsonl`, …
5. **Preserve the approval mtime on EVERY split**:
   `touch -r <original-approved-file> <split-file>`. Splits must expire exactly when the
   original approval would have — file creation never silently extends the 7-day window.

## Stage 5 (`--all`): Transparent Execute Drain (plan name: Stage 3.5)

Mechanical, progress-only, ROOT SESSION (direct execution — never backgrounded, never a
subagent). The human already decided at Stage 2.5; there is NO per-batch re-prompt.

For each split file, in order:

1. **Expiry pre-check**: if the split's (preserved) mtime is older than `PLAN_EXPIRY_DAYS=7`,
   STOP the drain (see stop-and-report below). The wrapper would refuse anyway; the pre-check
   produces the clean report instead of a wrapper error.
2. Compute `sha256sum <split-file>`.
3. For whichever action(s) the split contains, invoke (same `account` resolved in Stage 0):
   - `email-archive-confirmed --account <account> --execute --confirm-manifest <sha256> --manifest <split-path>`
   - `email-delete-confirmed --account <account> --execute --confirm-manifest <sha256> --manifest <split-path>`
4. **Idempotency**: rely EXCLUSIVELY on the wrapper's per-split `<split>.state.jsonl`
   companion (derived per manifest path, wrapper-contracts.md §4) — already-`executed` IDs are
   skipped by the wrapper on re-run. The skill keeps NO second ledger.
5. Log per split: `split <k>/<K>: <executed> executed, <failed> failed, <skipped> skipped`.
   Individual ID failures (recorded as `failed` in the state file) do NOT stop the drain;
   wrapper-level refusals (hash mismatch, expiry, batch-cap) DO stop it.
6. Note: each split run that executes ≥1 mutation triggers the wrapper's own internal
   `mbsync <account-channel>` reconcile (wrapper-contracts.md §7a; `mbsync gmail` for
   `account=gmail`, `mbsync logos` for `account=logos`) — expect one reconcile per executed
   split; this is frozen wrapper behavior, not something to suppress or replicate.

**Aggregate progress surface** — after each split, report:
`"X of Y splits processed — Z messages executed, W failed; resuming at split #k"` so an
interrupted drain is transparently resumable (re-run the drain; per-split state files skip
completed work).

**Expiry stop-and-report (never re-timestamp)** — on an expired split:

> N remaining approved actions across M un-executed splits have expired (approved {age} days
> ago; limit PLAN_EXPIRY_DAYS=7). Stopping. Re-run `/email --all` to re-sweep and re-review
> the residual.

NEVER `touch` a split (or the approved manifest) to reset its clock after approval; the ONLY
legitimate mtime manipulation is the Stage 4 `touch -r` that back-dates splits to the original
approval time.

## Stage 6 (`--all`): Verify

As in default mode: diff the per-split execution-state files (never re-derived) against the
approved manifest across ALL splits and report totals — executed, failed (with wrapper error
text), skipped-as-already-executed, and expired-unexecuted residual.

## Stage 7 (`--all`): Harvest (opt-in, never-silent)

Same opt-in harvest -> dedup -> tiered-gate -> Bash/jq batch-regen procedure as Default Mode
Stage 7 above (Steps 2-11 apply verbatim: mixed-sender handling, per-key dedup/tally,
evidentiary threshold, archive-scope isolation, the consolidated gate, the Bash/jq write path,
batch index regen, the feedback-loop cap, revocation/edit UX, and success-signal logging). The
ONLY difference is key derivation (Step 1):

1. **Key derivation (`--all` mode)**: key off the Stage 2.5 bucket grouping (domain, or full
   address for freemail/shared domains) as the harvest trigger/start key, cross-referenced
   against the per-split Stage 6 executed totals — only bucket members whose Message-ID is
   confirmed `executed` in some split's state-file diff count as evidence; approved-but-expired
   or failed IDs within an otherwise-executed bucket contribute nothing. Derive each executed
   member's identity the same way as default mode
   (`.claude/scripts/email-preference-harvest.sh identity "<sender>"`) and group by the
   resulting key — the Stage 2.5 bucket is the harvest *trigger*, not itself the memory key; one
   review bucket may fan out into multiple memory-write candidates (design §1.5).

Run this Stage 7 pass once, after Stage 6 totals are final for the whole `--all` sweep (all
splits), not per-split.

---
