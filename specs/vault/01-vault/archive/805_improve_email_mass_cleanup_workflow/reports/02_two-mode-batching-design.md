# Research Report: Task #805 — Round 2 (Two-Mode Batching Design)

**Task**: 805 - Improve the email/ extension's mass-cleanup workflow (bucket review, `--all`, `--archive`)
**Started**: 2026-07-03T07:40:00Z
**Completed**: 2026-07-03T07:45:00Z
**Effort**: ~1 hour (source re-verification + design synthesis)
**Dependencies**: Round 1 (`reports/01_team-research.md` and teammate findings)
**Sources/Inputs**:
- Round 1: `reports/01_team-research.md`, `01_teammate-{a,b,c,d}-findings.md`
- Ground truth (re-read directly): `~/.dotfiles/modules/home/email/agent-tools.nix` (full file)
- `.claude/extensions/email/commands/email.md`, `skills/skill-email-cleanup/SKILL.md`,
  `context/project/email/domain/wrapper-contracts.md`,
  `context/project/email/patterns/propose-review-confirm-execute.md`,
  `context/project/email/standards/recall-on-keep-bias.md`,
  `context/project/email/email-preferences.md`
- `.claude/skills/skill-fix-it/SKILL.md` (bulk-approval `AskUserQuestion` idiom, re-checked)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The user's design direction is fully realizable without touching the frozen wrapper**, but it
  requires re-partitioning where the "batches of 50" constraint actually lives. It is unavoidable
  on the **execute** side (`enforce_batch_size()` hard-refuses, verified again at
  `agent-tools.nix:235-243`) and **avoidable in the user's experience** everywhere else: classify
  and review can operate over the whole mailbox in one logical pass, and the 50-cap sub-manifest
  drain on the execute side runs **transparently** after one bulk bucket-approval, with no
  per-split re-prompt.
- **Two modes, cleanly separated by decision granularity, not by mechanism reuse**: default mode
  (no `--all`) makes ONE bounded classify→review→execute pass per invocation (≤50 candidates,
  never needs splitting because the input is already ≤50); `--all` mode makes ONE classify sweep
  up to a large scope, ONE consolidated bucket review, then a mechanical multi-split execute drain.
  `--archive` is an orthogonal folder-scope flag composable with either mode.
- **New finding (not in round 1): a single-call classify sweep over the full ~64k-message archive
  is not just "unverified" (round-1 C's framing) — it is very unlikely to complete inside a single
  Bash tool call's realistic timeout window.** `email-classify`'s per-message loop does 2
  `notmuch` subprocess forks and ~5 `jq` forks (verified: `agent-tools.nix:443-476`); at a
  conservative 150-400ms/message this is 2.7-7.1 hours for 64k messages. The fix is **unconditional
  internal chunking** of the classify phase for `--all` (not a fallback for when the single sweep
  is "too slow" — the single sweep should not be attempted at archive scale at all), run as a
  single backgrounded Bash job the skill starts once and monitors, landing ONE accumulated
  candidate set before bucket review.
- **New finding: `email-classify` has no offset/cursor flag — it only has `--limit` (a cap) and a
  `QUERY` positional (a filter).** Repeating the same call with the same `LIMIT`/`QUERY` reprocesses
  the identical first-N messages every time (verified: `head -n "$LIMIT"` over
  `notmuch search --output=messages "$QUERY"`, no offset semantics,
  `agent-tools.nix:434-439`). Chunk-to-chunk pagination inside a single `--all` classify sweep must
  therefore be driven by an **explicit message-ID-list slice computed once at sweep start**
  (`notmuch search --output=messages <QUERY>` captured to a scratch file, then chunked by line
  range into `id:a or id:b or ...` sub-queries) — not by the wrapper's own `+proposed-*` tags,
  which persist durably across separate top-level invocations and would silently exclude
  previously-reviewed-but-declined messages from a later `--all` sweep if reused for this purpose.
- **New finding: `email-classify` overwrites its own candidate manifest on every call** (`mv
  "$CANDIDATE_FILE.tmp" "$CANDIDATE_FILE"`, `agent-tools.nix:478`) — chunked classify calls must
  have the skill copy/append each chunk's output into a separate accumulator file at the
  orchestration layer immediately after each chunk call, before the next chunk overwrites it.
- **Mtime policy for split manifests, now decided (round 1 left this open): preserve the original
  bucket-approval's mtime via `touch -r` on every split.** The alternative (fresh mtime per split)
  makes `PLAN_EXPIRY_DAYS=7` practically untriggerable for exactly the highest-blast-radius case it
  exists to guard — this is a correctness regression, not a convenience.
- **`--archive`'s folder-scope question from round 1 (F4/finding 6, previously medium-confidence)
  is now resolved with high confidence by direct re-read**: the exact scope token is the notmuch
  query `folder:Gmail/.All_Mail` (confirmed verbatim in `email-census`'s own report,
  `agent-tools.nix:299`), passed as `email-classify`'s `QUERY` positional argument. No new wrapper
  flag is needed or exists.

## Context & Scope

Round 1 (`reports/01_team-research.md`) established that the task's original framing — "loop
`email-*-confirmed --execute` in repeated ≤50 batches" — does not match the as-built wrapper, which
hard-refuses over-cap manifests rather than auto-chunking them, and recommended manifest
pre-splitting as the batch-drain mechanism. This round takes an explicit **user design direction**:
the workflow should not force the human to think in units of 50 at all. It redesigns the `--all`
and default flows into two modes with different decision granularity, and closes the specific
reconciliation the user flagged — that the 50-cap is unavoidable on the execute side but must
disappear from the user's experience there, while classify+review can genuinely operate at whole-
mailbox scale.

Scope of this report: the batching/mode UX only (classify-sweep design, bucket-approval-to-split
pipeline, execute drain, mode definitions, mtime policy, `--archive` composition). It does **not**
re-derive: the bucket confidence-rollup algorithm, the `AskUserQuestion` schema shapes, the
`--archive`-specific extra confirmation gates, the feedback-loop/durable-rule-write idea, or the
pilot-before-64k recommendation — these carry forward from round 1 unchanged and are referenced,
not repeated, below.

## Findings

### Ground-truth re-verification (direct re-read of `agent-tools.nix`, this round)

All five of round-1 teammate C's F1-F5 findings are re-confirmed unchanged on this second read:

- **F1** `enforce_batch_size()` (lines 235-243): counts ALL manifest lines matching one action
  (`archive` or `delete`) in the **manifest file the wrapper is pointed at via `--manifest`**,
  regardless of whether they are already `executed` in the state file, and exits 1 if that count
  exceeds 50. It does not consult "remaining pending" — it consults "total lines for this action in
  this physical file." This matters for splitting: **each split file's per-action line count**, not
  its remaining-unexecuted count, is what must stay ≤50.
- **F2** staleness (lines 135-142): `MTIME=$(stat -c %Y "$MANIFEST_FILE")` — raw file mtime of
  whichever file `--manifest` points at (defaults to `approved-manifest.jsonl`, but any path works).
  Confirms this is purely a filesystem timestamp with no notion of "logical approval time" separate
  from file creation/modification time.
- **F3** classify pagination (lines 328-479): `LIMIT="$MAX_BATCH_SIZE"` (50) by default,
  overridable via `--limit <N>` with **no upper bound check anywhere in the code** — `head -n
  "$LIMIT"` is the only gate. Confirms a large `--limit` is mechanically accepted. New this round:
  the per-message loop body (lines 443-476) is exactly: `notmuch show --format=json` (1 fork) →
  4x `jq` calls extracting fields from that JSON (lines 448-450, 468-470 use `echo | jq -r` and a
  final `jq -nc`) → `notmuch tag` (1 fork). That is 2 `notmuch` invocations and up to 5 `jq`
  invocations per message, fully sequential, no batching of the notmuch/jq calls themselves.
- **F4** folder scope (lines 333-344, 492-501, and — newly cross-checked this round —
  `email-census`'s own hardcoded report at line 299): `QUERY="folder:Gmail"` is the default for
  `email-classify` and `email-unsubscribe-extract`; the query for Gmail's All Mail is
  `folder:Gmail/.All_Mail`, taken verbatim from `email-census`'s own `notmuch count
  'folder:Gmail/.All_Mail'` line. `email-census` itself takes no QUERY argument (it hardcodes both
  folder counts in its fixed report), so `--archive`'s scoping burden falls entirely on
  `email-classify`/`email-unsubscribe-extract`'s QUERY positional.
- **F5** classifier tiers (lines 396-432): unchanged — deterministic bash, `>=0.90` delete bar
  reached only via the ~13-domain hardcoded list (`CUSTOM_DELETE_DOMAINS`); everything else lands
  at 0.98 (custom-keep), 0.60 (newsletter keyword), 0.55 (notification-domain keyword), or 0.50
  (default-unsure), then the delete-specific downgrade at lines 460-466 knocks any sub-0.90 `delete`
  proposal down to `unsure`. At archive scale this means the bulk of bucket-review load is
  `unsure`/`archive`-tier buckets, not `delete`-tier — unchanged framing from round 1, carried
  forward.

New ground-truth details this round (not previously called out):

- **No offset/cursor exists.** `email-classify` accepts only `--limit` (a cap) and `QUERY` (a
  filter). There is no `--skip`/`--offset`/`--after` flag. Two calls with identical `LIMIT` and
  `QUERY` process the identical message set (notmuch's search order is deterministic for an
  unchanged index), so naive re-invocation makes zero forward progress.
- **Candidate manifest is overwritten, not appended, per call.** `CANDIDATE_FILE.tmp` is truncated
  at the start of every `email-classify` invocation (line 441) and `mv`'d over `CANDIDATE_FILE` at
  the end (line 478). A multi-chunk classify sweep must accumulate chunk outputs itself.
- **`+proposed-*` tags are the only durable, cross-invocation signal `email-classify` writes**
  (line 473-474: `notmuch tag -proposed-delete -proposed-archive -proposed-unsure -proposed-keep
  "+proposed-$action"`), and they persist regardless of whether the tagged message is ever
  approved/executed. This makes them usable as an intra-run pagination signal but risky as a
  cross-campaign one (see Decisions below).
- **A split sub-manifest's companion state file is automatically namespaced correctly.**
  `STATE_FILE="${MANIFEST_FILE}.state.jsonl"` is derived from whatever path `--manifest` points at
  (line 111), so N split files at N distinct paths get N distinct, independently idempotent state
  files with zero extra plumbing — this confirms round-1 teammate B's "reuse
  `<manifest>.state.jsonl`, don't invent a second ledger" survives unchanged into the split design.

### Runtime risk of a single large classify sweep (new analysis)

Per-message cost in `email-classify`'s loop is dominated by process-fork overhead: 1 `notmuch show`
(xapian lookup, typically tens of ms), up to 5 `jq` invocations (each ~5-15ms including process
startup), 1 `notmuch tag` (10-30ms). A conservative estimate is 150-400ms/message. At full-archive
scale (~64,000 messages, per the task description and round 1's math):

| Per-message cost | Total wall-clock for 64k messages |
|---|---|
| 100ms (optimistic, warm cache) | ~1.8 hours |
| 250ms (mid estimate) | ~4.4 hours |
| 400ms (conservative) | ~7.1 hours |

This is far beyond this environment's Bash tool's practical per-call ceiling (default 120s, max
600s per the tool's own documented limits) even at the low end. **A single `--limit 70000` call is
not a viable design**, regardless of the wrapper's lack of an internal cap — the constraint here is
the calling harness's timeout, layered on top of (not caused by) the wrapper's own unlimited
`--limit`. This is a meaningful correction to round-1 teammate C's F3/F9 framing, which treated the
single-sweep path as merely "unverified" — it should be treated as **not recommended at archive
scale**, with chunking as the primary design, not a fallback.

## Decisions

1. **Two modes, split by decision granularity, not by which binaries are called.** Both modes use
   the same five wrapper binaries and the same propose→review→confirm→execute shape from
   `propose-review-confirm-execute.md`; what differs is how much of the mailbox is swept before the
   human is asked to decide, and whether the resulting approved set needs splitting before
   execution.

   **Default mode** (no `--all`, current behavior, refined):
   ```
   classify (--limit 50, default QUERY, no chunking — input is bounded by construction)
     -> review (bucket-or-message-by-message, user's choice per existing Question-0 mode-select)
     -> approve (approved manifest, <=50 lines per action BY CONSTRUCTION — the candidate pool
                 itself never exceeded 50, so it can never trip enforce_batch_size)
     -> execute ONE call per action against the single approved manifest (no splitting needed)
     -> report results -> STOP (return control to the user)
   ```
   Re-running `/email` (no `--all`) advances to the next 50 by construction: already-executed
   messages have physically left the folder (archived/deleted), so `folder:Gmail`'s natural
   membership shrinks; messages seen-but-not-approved on a prior pass carry a durable
   `+proposed-*` tag from that pass, and **this mode should rely on that tag as the forward-progress
   cursor** (see rationale below) — i.e. its classify call should use
   `<QUERY> and not tag:proposed-delete and not tag:proposed-archive and not tag:proposed-unsure and not tag:proposed-keep`
   once a mailbox has been through at least one default-mode pass, so "step through in batches of
   50" makes real forward progress across separate invocations instead of re-showing the same
   newest 50 messages forever (notmuch's default search order is stable, so without this filter a
   second bare re-run reprocesses the identical first 50 with zero progress).

   **`--all` mode** (new, whole-mailbox bulk decision):
   ```
   Stage 2 (Sweep, replaces the single classify call):
     1. Capture the full in-scope message-ID list ONCE: `notmuch search --output=messages <QUERY>`
        (read-only, fast — this is a plain notmuch query, not a classify call) into a scratch file.
     2. Slice that captured list into fixed-size chunks (recommend 1000 IDs/chunk; see sizing
        below) by line range — NOT by re-querying or by tag-exclusion.
     3. For each chunk, construct an `id:a or id:b or ... or id:n` query string from that chunk's
        literal message-IDs and invoke `email-classify --limit <chunk-size> "<id-query>"`.
     4. Immediately append/copy that call's `candidate-manifest.jsonl` output into a persistent
        accumulator file before the next chunk's call overwrites it.
     5. Run steps 1-4 as a single backgrounded Bash job (`run_in_background`) that internally loops
        over all chunks and emits periodic progress lines; the skill starts it once and monitors it
        rather than issuing N separate foreground Bash tool calls. This is legitimate under the
        direct-execution/root-session invariant because that invariant governs the interactive
        REVIEW gate (Stage 3), not the read/tag-only classify sweep — nothing about backgrounding a
        non-mutating, non-gated stage violates "the review gate cannot live in a background
        subagent." Before starting, surface a one-time estimate to the user ("~64,000 messages in
        scope, ~64 chunks, estimated Xh at current settings — proceeding in the background").
   Stage 2.5 (Bucket review, ONE consolidated pass over the accumulated candidate set):
     Unchanged from round 1's design (min()-confidence rollup, option-availability gating at 0.90,
     fix-it's multiSelect/"Select all" idiom) — carried forward, not re-derived here.
   Stage 4 (Split, new): partition the logically-approved set by action, then by chunks of <=50
     lines per action, writing N physical sub-manifest files. Where both actions are present in the
     same index range, pack them into the SAME physical file (<=50 archive lines AND <=50 delete
     lines in one file both pass their respective independent enforce_batch_size checks) to halve
     the number of physical files versus fully separate per-action series.
   Stage 3.5 (Transparent drain, new): for each split file in order, compute its sha256, invoke
     `email-archive-confirmed`/`email-delete-confirmed --execute --confirm-manifest <sha256>
     --manifest <split-path>` for whichever action(s) that split contains, log
     executed/failed/remaining, and move to the next split — MECHANICALLY, with NO re-prompt. The
     human already made every decision at Stage 2.5; this stage is progress-reporting only, per
     round 1's synthesis point (carried forward, not re-derived).
   ```

2. **Mtime policy: preserve the original approval's mtime on every split, via `touch -r
   <original-approved-file> <split-file>` at split-creation time.** Resetting to a fresh mtime per
   split would make `PLAN_EXPIRY_DAYS=7` untriggerable in practice for a mechanically-fast drain
   (splits get created and executed within seconds of each other), which defeats the guard's actual
   purpose — protecting against executing a decision the human made a long time ago — for exactly
   the bulk-approval case where that protection matters most. The trade-off this creates: if the
   transparent drain is interrupted (aborted, crashed, or an `mbsync` auth failure halts it per the
   wrapper's own fail-safe) and not resumed for >7 days, ALL remaining un-executed splits expire
   simultaneously. Do not silently re-timestamp to work around this. On an expired split, the drain
   must **stop** and report: "N remaining approved actions across M un-executed splits have expired
   (originally approved {age} days ago); re-run `/email --all` to re-sweep and re-review the
   residual." Because already-executed splits are skipped by the wrapper's own idempotent state
   file (F1/companion-state, unchanged from round 1), and a fresh `--all` sweep's Stage 2 will
   naturally omit anything already physically moved out of scope, resuming costs the user only a
   fresh look at the genuinely-unresolved remainder — not a full re-decision of the whole mailbox.

3. **Do not reuse `+proposed-*` tags as `--all`'s intra-sweep pagination cursor; use the captured
   ID-list slice instead (Decision 1, Stage 2).** These tags are durable across separate top-level
   `/email` invocations (nothing clears them). If `--all`'s chunk-to-chunk pagination were tag-based
   (as default mode's cross-invocation pagination is, by design, in Decision 1), a later `--all`
   sweep would silently exclude any message a prior default-mode pass had seen-but-declined,
   understating the true current mailbox state for exactly the case ("look at everything right
   now") where completeness matters most. The ID-list-slice approach scopes exclusion to
   this-run-only and has no such cross-campaign side effect. This is the one place default mode and
   `--all` mode deliberately use different pagination mechanisms for the same underlying
   `+proposed-*`-tag artifact, precisely because their intended semantics differ ("advance through
   the mailbox over many sessions" vs. "one comprehensive current snapshot").

4. **Chunk size: recommend 1,000 message-IDs per internal classify chunk for `--all`**, based on
   the runtime table above (worst case ~400s/chunk at the conservative 400ms/message estimate,
   comfortable margin under this environment's 600s Bash-call ceiling even without the
   background-job design in Decision 1). Treat this as a tunable default to be confirmed by the
   pilot run round 1 already recommended (F9) — a real measurement of this system's per-message
   `notmuch show`/`jq` latency may support a larger chunk size (2,000-3,000) and should adjust this
   number rather than the report guessing further.

5. **Default mode remains the safer default flag state, unchanged from round 1's implicit
   position, now made explicit.** It needs neither classify-chunking (candidate pool is
   structurally bounded to 50) nor manifest-splitting (approved set can never exceed 50 per action)
   — it is a strict, simpler subset of the machinery `--all` requires. `--all` should stay
   opt-in: it is where all of the new complexity (sweep chunking, accumulator files, split
   generation, mtime preservation, transparent multi-split drain) lives, and that complexity should
   not be forced onto a first-time or low-volume user's default path.

6. **`--archive` remains a purely orthogonal folder-scope flag**, composable with either mode:
   `mode=default, archive` steps through All Mail 50-at-a-time with QUERY scoped to
   `folder:Gmail/.All_Mail` (no new machinery — same as default mode's "no chunking needed" case,
   just a different QUERY); `mode=all, archive` is the full 64k drain, combining this round's
   sweep/split/drain design with round 1's already-decided extra safety gates (second
   blast-radius-naming confirmation, `--expunge-trash` opt-in only, asymmetric/corroborated
   confidence bar, never auto-chain `--sync`) — those gates are unchanged and referenced from round
   1's report/teammate-A findings, not re-derived here.

## Risks & Mitigations

- **Risk**: a fresh `--all` sweep re-surfaces messages a prior default-mode (or prior `--all`) pass
  already reviewed-and-declined, adding review load the user may perceive as repetitive.
  **Mitigation**: this is the deliberate trade-off of Decision 3 (favor completeness over
  quietly-hidden history for the "look at everything" mode) — the report from Stage 2.5 should
  clearly label buckets that were previously seen-and-declined (detectable via the `+proposed-*`
  tag, even though it isn't used for exclusion) so the user can distinguish "new since last look"
  from "still here from before."
- **Risk**: the background classify sweep (Decision 1, step 5) runs unattended for hours; if it
  crashes partway, the accumulator file has a partial chunk set with no marker of which chunks
  completed. **Mitigation**: the background job should write a small progress-log line per
  completed chunk (chunk index, message count, accumulator running total) that the skill can
  inspect on resume to know how far the sweep got, distinct from the drain-side progress reporting
  in Stage 3.5.
- **Risk**: packing both actions into one physical split file (Decision 1, Stage 4) makes each
  split's blast radius up to 100 total mutations (50 archive + 50 delete) instead of 50 — still
  wrapper-legal (each action is independently checked) but a larger single transparent step than a
  strictly-per-action series. **Mitigation**: this is a deliberate throughput/legibility trade-off;
  if the aggregate audit surface (round 1's F11, carried forward as a follow-on) later shows this
  is confusing to reason about post-hoc, fall back to fully separate per-action split series (twice
  as many files, simpler per-file semantics).
- **Risk (carried forward from round 1, unchanged)**: the extension has never been loaded/run
  anywhere (F9) — none of this round's runtime estimates or chunk-size recommendations are
  empirically verified. A bounded pilot (a few hundred to low-thousands of messages) before the
  full 64k `--archive` drain remains the load-bearing recommendation from round 1 for validating
  both the mechanism and the tuning constants in Decision 4.

## Context Extension Recommendations

- **Topic**: chunked-sweep pagination for read-only/tag-only wrapper binaries with `--limit` but no
  offset flag.
  **Gap**: no existing pattern doc addresses "how to page through a large scope when the underlying
  tool only exposes a cap, not a cursor."
  **Recommendation**: fold this into the agent-system-layer `batch-drain-loop.md` pattern doc round
  1 already recommended authoring (Teammate D, finding 3) — it is the natural sibling half (sweep
  pagination) to that doc's original scope (execute-side idempotent draining).

## Appendix

### What changes from round 1 vs. what carries forward unchanged

**Changes (this round)**:
- The single `--all` flag with an embedded Stage 2.5 is replaced by two explicit modes (default
  50-step vs. `--all` whole-mailbox), differentiated by decision granularity per the user's
  direction.
- Classify-side chunking is now the required design for `--all`, not a fallback for an
  under-verified single-sweep path (round-1 C's F3/F9 framing corrected by the runtime-risk
  analysis above).
- A concrete pagination mechanism for classify chunks (captured ID-list slice) replaces round 1's
  silence on how the "candidate-manifest-building stage" (F3's identified gap) actually pages.
- The mtime policy for split manifests (round 1 F2, left as "a conscious choice to make") is now
  decided: preserve original mtime via `touch -r`, with an explicit stop-and-report path on expiry.
- The exact `--archive` folder-scope query (round 1 F4/finding 6, medium confidence) is now
  confirmed high-confidence: `folder:Gmail/.All_Mail`.
- A concrete backgrounding mechanism (`run_in_background` for the non-gated sweep only) resolves
  round 1's F7 (root-session chunking model) for the classify phase specifically — the review and
  execute stages remain foreground/direct-execution, unchanged.

**Carries forward unchanged (referenced, not re-derived)**:
- Bucket confidence rollup: `min()`, not `avg()`; option-availability gating at the 0.90 delete
  floor (Teammate A).
- `AskUserQuestion` bulk-approval schema shapes (Question-0 mode-select, per-bucket multiSelect),
  modeled on `skill-fix-it/SKILL.md` (Teammate A/B).
- Extend `skill-email-cleanup` in place; do not fork a new skill (Teammate A, synthesis point 3).
- `--archive`'s extra safety gates: second blast-radius-naming confirmation, `--expunge-trash`
  opt-in only, asymmetric/corroborated confidence bar for archive scope, never auto-chain `--sync`
  (Teammate A/D).
- Reuse the wrapper's own `<manifest>.state.jsonl` per split file as the sole execution-idempotency
  ledger — no second ledger invented (Teammate B, now additionally confirmed automatic-per-path in
  this round's re-read).
- Feedback-loop / durable-rule-write enhancement and maintenance-mode (`loop`/`schedule` on the
  read-only Propose stage only) remain flagged as fast-follow, out of core scope (Teammate D).
- Pilot-before-64k recommendation (Teammate C, F9) — reinforced, not superseded, by this round's
  runtime-risk finding.

### References (file:line)

- `~/.dotfiles/modules/home/email/agent-tools.nix:235-243` (`enforce_batch_size`)
- `~/.dotfiles/modules/home/email/agent-tools.nix:108-146` (mutation gate: hash check, staleness)
- `~/.dotfiles/modules/home/email/agent-tools.nix:328-481` (`email-classify` full body: QUERY/LIMIT
  parsing, per-message loop, candidate-manifest overwrite, `+proposed-*` tagging)
- `~/.dotfiles/modules/home/email/agent-tools.nix:290-322` (`email-census`: hardcoded
  `folder:Gmail/.All_Mail` query, confirming the exact All Mail scope token)
- `~/.dotfiles/modules/home/email/agent-tools.nix:559-560, 639-640` (`enforce_batch_size` call
  sites in `email-archive-confirmed`/`email-delete-confirmed`, per-action independence)
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md:44-82` (existing stage
  definitions and constants table)
- `.claude/extensions/email/context/project/email/patterns/propose-review-confirm-execute.md`
  (unchanged 5-stage shape this round's two modes both still follow)
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md:38-51` (companion
  state-file and constants, restated for continuity)
- `.claude/skills/skill-fix-it/SKILL.md:121-243` ("Select all (N items)" affordance, re-checked)
- `specs/805_improve_email_mass_cleanup_workflow/reports/01_team-research.md` and
  `01_teammate-{a,b,c,d}-findings.md` (round 1, full synthesis and per-teammate detail)
