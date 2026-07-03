# Research Report: Task #805 — Teammate A (Primary Angle)

**Task**: 805 - Improve email mass-cleanup workflow (bucket review, `--all`, `--archive`)
**Role**: Teammate A — Primary Angle (concrete implementation approach)
**Sources/Inputs**: `.claude/extensions/email/` (commands, skills, context), task 803 artifacts,
`git show 51bfda974` (the `--sync` precedent)
**Artifacts**: this report

## Key Findings

1. The existing propose→review→confirm→execute pipeline (`skill-email-cleanup/SKILL.md`
   Stages 1-6, `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md:44-76`) already
   separates classification (unbounded, whole-mailbox) from execution (capped at
   `MAX_BATCH_SIZE=50` per invocation). The 50-cap is an *execute-call* cap, not a manifest-size
   cap — nothing in `wrapper-contracts.md` limits how many lines a candidate/approved manifest
   may contain. This means `--all` doesn't need to fight the cap; it needs to **loop the same
   `--execute` call against the same approved manifest** until nothing remains.
2. The companion execution-state file is explicitly designed for exactly this: `--execute skips
   IDs already executed and records failed with error text — safely re-runnable`
   (`wrapper-contracts.md:40-42`, restated in `propose-review-confirm-execute.md:31-33`). This is
   the idempotency primitive the batch-drain loop should rely on rather than re-deriving state.
3. `--sync` (git commit `51bfda974`) is the closest precedent for adding a mode flag to `/email`:
   it added a *second skill* (`skill-email-sync`) rather than extending `skill-email-cleanup`,
   specifically because `mbsync` is a non-wrapper binary and keeping `skill-email-cleanup`
   wrapper-only required a hard boundary (`email.md:70-80`, `skill-email-sync/SKILL.md:32-37`).
   **`--all` and `--archive` do not have this problem** — both only ever call the same five
   wrapper binaries, just repeated (`--all`) or folder-scoped with extra gates (`--archive`).
   The `--sync` precedent argues for extending `skill-email-cleanup` in place, not forking a
   third skill, because there is no contract-purity reason to split.
4. The recall-on-keep bias and the 0.90 delete-confidence gate
   (`standards/recall-on-keep-bias.md:31-42`) are manifest-line-level concepts today. Bucket-based
   review needs a bucket-level aggregation rule layered on top, not a replacement.
5. `skill-fix-it/SKILL.md` already has a working, in-repo `AskUserQuestion` bulk-approval idiom
   (`multiSelect: true`, "Select all" convenience option, grouping-mode pre-question) that can be
   copied almost directly for sender/domain-bucket approval
   (`.claude/skills/skill-fix-it/SKILL.md:121-198, 221-227`).

## Recommended Approach

### 1. AskUserQuestion bucket/domain bulk-approval design

Add a **Stage 2.5 (Bucket)** between classify and review in `skill-email-cleanup/SKILL.md`:

- After `email-classify` emits the candidate manifest (JSONL, one line per Message-ID with
  `sender`, `proposed_action`, `confidence` — schema at `wrapper-contracts.md:29-36`), group
  candidate lines by **sender domain** (fallback: exact sender address when one sender dominates
  a domain, e.g. `notifications@github.com` vs generic `github.com`). Sort buckets by message
  count descending. Cap the number of buckets that get their own question at ~15; fold any
  remaining long tail into a synthetic "Other senders (≤3 msgs each)" bucket.
- Compute **per-bucket confidence rollup**: `bucket.delete_ok = avg(confidence for proposed_action == delete) >= 0.90` AND `min(confidence) >= 0.90` (use min, not avg, so one weak
  match doesn't licence bulk-approving strong ones — preserves the recall-on-keep bias at
  bucket granularity, not just per-message). Buckets that fail this test must present with
  `unsure` framing and must never pre-word an "approve all as delete" option — only
  archive/keep/inspect options, mirroring `recall-on-keep-bias.md:36-39` ("everything below 0.90
  must resolve to unsure ... never auto-actioned as delete").
- **Question 0 (mode select, once per pass)**, single-select, modeled on the fix-it
  grouping-mode pattern at `.claude/skills/skill-fix-it/SKILL.md:221-227`:
  ```json
  {
    "question": "How do you want to review the {N} classified messages ({B} sender/domain buckets)?",
    "multiSelect": false,
    "options": [
      {"label": "Review by bucket (recommended)", "description": "Approve/reject in {B} groups by sender/domain"},
      {"label": "Review message-by-message", "description": "Step through all {N} candidates individually"},
      {"label": "Skip low-signal buckets, review the rest", "description": "Auto-skip buckets ≤2 msgs; bucket-review the remainder"}
    ]
  }
  ```
- **Question N (per bucket, multiSelect)**, modeled on
  `.claude/skills/skill-fix-it/SKILL.md:121-172`:
  ```json
  {
    "question": "Bucket: notifications@github.com — 42 msgs, proposed: archive (avg conf 0.95). Approve?",
    "multiSelect": true,
    "options": [
      {"label": "Approve all 42 as archive", "description": "Move all matched Message-IDs to All Mail"},
      {"label": "Approve only auto-proposed subset (38 @ confidence ≥0.90)", "description": "Leave 4 unsure messages for later/manual review"},
      {"label": "Reject bucket — keep all 42", "description": "No action on this bucket this pass"},
      {"label": "Inspect subjects first", "description": "Show up to 10 example subject/date pairs before deciding"}
    ]
  }
  ```
  When `bucket.delete_ok` is false (below the 0.90 floor), drop the "Approve all as delete"
  option entirely and replace it with "Approve all as archive" / "Mark bucket unsure — surface
  for manual review", i.e. the confidence gate is enforced by *which options exist*, not by
  post-hoc filtering of a chosen option — this prevents a user's blanket "approve all" click from
  silently deleting sub-0.90 messages.
- Each approved bucket selection appends its Message-IDs to the approved manifest exactly as
  today (Stage 4, `SKILL.md:61-64`) — bucketing changes only the *presentation* of Stage 3, not
  the approval artifact's shape or the confirm/execute mechanics.
- Recommend a new context doc `context/project/email/patterns/bulk-bucket-review.md` documenting
  the bucketing rule (domain grouping, min-not-avg confidence rollup, option-availability gating)
  as a sibling to `patterns/propose-review-confirm-execute.md`, since it is a reusable review
  presentation policy, not command-specific glue.

### 2. `--all` batch-drain loop design

Add `--all` as a flag parsed by `email.md` (same shape as the existing `--sync` parsing at
`email.md:22-33`), threaded into `skill-email-cleanup` as `mode=all`. Design:

```
Stage 3.5 (new, mode=all only): Batch Drain Loop
  approved_manifest, sha256 := <from Stage 4>
  batch_num := 0
  loop:
    age_days := (now - approved_manifest.approved_at) in days
    if age_days > PLAN_EXPIRY_DAYS:               # 7, wrapper-contracts.md:49
      stop loop; report "manifest expired ({age_days}d > 7d) with {remaining} actions
      un-executed; re-run /email --all to re-classify + re-review the remainder"
      # do NOT silently re-timestamp/re-approve — that would bypass the human gate
    for each pending verb (archive, delete) with pending IDs:
      run `email-{verb}-confirmed --execute --confirm-manifest <sha256>`
      # wrapper internally: skips already-`executed` IDs (idempotent), processes
      # up to MAX_BATCH_SIZE=50 new IDs, appends to <manifest>.state.jsonl
    batch_num += 1
    diff <manifest>.state.jsonl against approved_manifest ->
      {executed_total, failed_total, remaining_total} this call
    report progress (see shape below)
    if remaining_total == 0: break
    if this batch executed 0 new IDs and failed 0 (no progress) and remaining_total > 0:
      stop loop; report stuck IDs (likely a wrapper-side error) — do not spin
```

- **Idempotency**: comes entirely from the wrapper's own `<manifest>.state.jsonl` semantics
  (`wrapper-contracts.md:38-42`) — re-invoking the identical `--execute --confirm-manifest <sha256>`
  command is safe by contract; the loop is just "call it again until the state file shows
  nothing left," never re-deriving targets from the candidate manifest or live mailbox state
  (that would violate `SKILL.md:75-76`'s "diff against approved manifest... never re-derive").
- **Batch size**: unchanged at ≤50 per call (this task explicitly forbids raising
  `MAX_BATCH_SIZE`); `--all`'s contribution is purely the outer loop, never a wrapper-contract
  edit.
- **`PLAN_EXPIRY_DAYS=7` window**: only a real risk if a `--all` drain spans multiple sessions
  over a week (e.g., user pauses mid-drain). Check manifest age **before each loop iteration**,
  not just once at Stage 4, since the loop itself may straddle the boundary. On expiry, stop and
  route back to classify+review for the *remaining unexecuted* IDs only (not the whole mailbox
  again) — construct a residual candidate set as `approved_manifest minus <manifest>.state.jsonl
  executed IDs`.
- **Progress reporting shape** (printed after every loop iteration, not just at the end):
  ```
  Batch 3 (archive): 42 executed, 0 failed this call
  Batch 3 (delete):  8 executed, 0 failed this call
  Cumulative: 650/1,240 approved actions executed (52%), 590 remaining
  ```
- Files touched: `email.md` (arg parsing + routing input, mirroring the `--sync` diff shape at
  `email.md:22-33` and `41-50`), `skill-email-cleanup/SKILL.md` (new Stage 3.5), and a new
  context doc `context/project/email/patterns/batch-drain-loop.md` cross-referencing
  `wrapper-contracts.md` §4-5 for the idempotency/expiry contract this loop depends on.

### 3. `--archive` mode design (extra safety gates)

Add `--archive` as a second, composable flag (`--all --archive` should be legal: drain the whole
All Mail folder). Because All Mail is ~64k messages and post-`--expunge-trash`+sync is
irreversible, layer additional gates rather than reusing the inbox flow verbatim:

- **Folder scope, not blast radius, is the first gate.** `email-census`/`email-classify` must be
  invoked with an explicit archive-folder scope (e.g. an equivalent of `--folder "All Mail"`,
  exact flag TBD by the wrapper's actual CLI — verify against the frozen `.dotfiles` binaries
  before implementation) so `--archive` never silently expands scope to include INBOX in the same
  pass. Never run `--all` (inbox) and `--archive` in the same classify call implicitly — they
  should always be visibly separate manifests, even when chained in one session.
- **A second, distinctly-worded confirmation before archive-scope execution begins**, styled
  after `skill-email-sync`'s Stage 3 mandatory stop (`skill-email-sync/SKILL.md:70-75`): state the
  message count, that this is the *Archive/All Mail* folder (not inbox), and that any
  `--expunge-trash` component makes the affected subset permanently unrecoverable once later
  synced. This is in addition to, not instead of, the normal Stage 3 manifest review.
  `AskUserQuestion` should require an explicit typed/selected confirmation option like "Yes,
  execute against All Mail (64,xxx msgs)" rather than a generic "Approve" — the label itself
  should carry the blast-radius number.
- **`--expunge-trash` must never be bundled as a default in archive mode.** Recommend archive
  mode default to plain delete-to-Trash (recoverable ~30 days per Gmail, matching
  `skill-email-sync/SKILL.md:26-27`'s own description of Trash recoverability), and require a
  *separate, explicitly-opt-in* follow-up flag/confirmation for `--expunge-trash` scoped to
  archive mode specifically — never inherit inbox mode's expunge default (if any) automatically.
- **Smaller effective review chunks.** Even with manifest size uncapped, presenting bucket
  questions over tens of thousands of archive messages in one sitting is unreasonable. Recommend
  archive mode's classify step run/report in explicit date-range or count chunks (e.g. "oldest
  5,000 first") so bucket-review Stage 2.5 questions stay a tractable few dozen per round, with
  the batch-drain loop (`--all`-style) applied per chunk.
- **Never auto-chain to `/email --sync` after an archive drain.** `--sync` is already a distinct,
  confirmation-gated skill (`skill-email-sync`) and the "freeze sync during bulk ops" rule
  (`propose-review-confirm-execute.md:48-50`, `email.md:79-80`) already forbids interleaving; make
  this explicit in `--archive` mode's own safety notes so a future implementer doesn't add a
  convenience auto-sync at the end of a drain loop.
- Files touched: `email.md` (parse `--archive`, composable with `--all`), `skill-email-cleanup/SKILL.md` (archive-mode branch: folder-scope precondition, the extra confirmation stage,
  expunge opt-in gate), and a short addition to `context/project/email/domain/wrapper-contracts.md`
  or a new `context/project/email/domain/archive-mode-risk.md` documenting the blast-radius
  rationale (64k, expunge+sync irreversibility) so future readers don't have to reconstruct why
  archive mode is stricter than inbox mode.

### 4. New skill vs. extend existing — recommendation: extend, do not fork

Unlike `--sync` (which forked to `skill-email-sync` because `mbsync` is a **non-wrapper**
binary and keeping `skill-email-cleanup` wrapper-only required a hard boundary — see
`skill-email-sync/SKILL.md:32-37` for the explicit rationale), **`--all` and `--archive` never
call anything beyond the same five wrapper binaries.** They differ only in looping and folder
scope/confirmation strictness, both of which are naturally expressed as internal stage
variations of the existing propose→review→confirm→execute pipeline. Forking a fourth skill would
duplicate the wrapper-only contract, the mandatory-gate language, and the manifest/state-file
mechanics across files that must then be kept in lockstep — a maintenance liability with no
corresponding safety benefit (the precedent that *did* justify a fork, non-wrapper binary usage,
does not apply here).

**Concrete files to touch**:
1. `.claude/extensions/email/commands/email.md` — extend argument parsing (step after the
   existing `--sync` check) to detect `--all` and `--archive` (composable with each other and
   with the free-text focus hint), pass `mode=default|all|archive|all+archive` into
   `skill-email-cleanup`'s args.
2. `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — add Stage 2.5 (bucket
   grouping + confidence-gated bucket options), Stage 3.5 (batch-drain loop, mode=all), and an
   archive-mode safety-gate subsection (folder scope, extra confirmation, expunge opt-in),
   updating the "Critical Requirements" MUST/MUST NOT lists to reference the new gates.
3. New: `context/project/email/patterns/bulk-bucket-review.md`.
4. New: `context/project/email/patterns/batch-drain-loop.md`.
5. New (or extend `wrapper-contracts.md`): `context/project/email/domain/archive-mode-risk.md`.
6. `.claude/extensions/email/README.md` and `EXTENSION.md` — add `--all`/`--archive` to the
   command inventory, mirroring how `--sync` was documented (`git show 51bfda974` touched
   `README.md` at 21 lines).
7. No changes needed to `manifest.json` (no new skill registered, no new routing entries) and no
   changes to `mail-guard.sh` (no new binaries introduced).

## Evidence/Examples (file:line)

- Wrapper-only constraint & 5 binaries: `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md:9-13, 32-40`
- Mandatory human review gate, Stage 3: `skill-email-cleanup/SKILL.md:56-59, 94-95`
- Execution-state idempotency (`<manifest>.state.jsonl` skips executed IDs):
  `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md:38-42`
- `MAX_BATCH_SIZE=50` / `PLAN_EXPIRY_DAYS=7` constants: `wrapper-contracts.md:47-50`,
  restated `skill-email-cleanup/SKILL.md:80-82`
- Recall-on-keep bias / 0.90 delete confidence floor:
  `.claude/extensions/email/context/project/email/standards/recall-on-keep-bias.md:31-42`
- Manifest JSONL schema (sender/confidence fields for bucketing):
  `wrapper-contracts.md:29-36`
- Verify-by-diff-never-re-derive rule: `skill-email-cleanup/SKILL.md:73-76`,
  `patterns/propose-review-confirm-execute.md:35-39`
- Freeze-sync-during-bulk-ops rule: `patterns/propose-review-confirm-execute.md:48-50`,
  `.claude/extensions/email/commands/email.md:79-80`
- `--sync` as the only prior precedent for a new flag on `/email`, and why it forked a skill
  (non-wrapper `mbsync` binary): `git show 51bfda974` (commit message + diff),
  `skill-email-sync/SKILL.md:32-37`
- Delete invariant (Trash → `--expunge-trash` → sync = irreversible sequence):
  `wrapper-contracts.md:63-66`, `skill-email-sync/SKILL.md:18-27`
- AskUserQuestion bulk-approval idiom to copy (multiSelect, "Select all", grouping-mode
  pre-question): `.claude/skills/skill-fix-it/SKILL.md:121-198, 221-227`
- Task 803 build summary confirming skill-email-cleanup contains no `subagent_type:` (direct
  execution, must run in root session — matches task 805's constraint):
  `specs/803_email_claude_code_extension/summaries/02_author-email-extension-summary.md:58-60`

## Confidence Level

**High** on: the batch-drain loop design (idempotency mechanism is explicitly documented in the
frozen contract, not inferred), the "extend, don't fork" recommendation (directly supported by
contrasting the `--sync` precedent's actual rationale), and the AskUserQuestion schema shape
(directly modeled on a working in-repo pattern).

**Medium** on: the exact folder-scoping flag needed for `--archive` (the wrapper binaries'
CLI surface lives in the frozen `.dotfiles` repo, not this repo — I could not verify an exact
`--folder`/equivalent flag name; this should be confirmed against the actual binary `--help`
output or `.dotfiles` Task 72 handoff before implementation) and the precise bucket-count/chunk
thresholds (15 buckets, 5,000-message archive chunks) — these are reasonable starting defaults,
not empirically derived.
