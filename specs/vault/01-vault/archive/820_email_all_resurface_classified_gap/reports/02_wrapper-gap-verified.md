# Research Report: Task #820

**Task**: 820 - `/email --all` cannot re-surface an already-fully-classified mailbox for review
**Started**: 2026-07-05T20:00:00Z
**Completed**: 2026-07-05T20:50:00Z
**Effort**: medium (source-grounded verification across two repos + a concrete two-file fix design)
**Dependencies**: reports/01_wrapper-gap-seed.md (seed, superseded on one factual claim — see Findings)
**Sources/Inputs**:
- Codebase: `~/.config/nvim/.claude/extensions/email/skills/skill-email-cleanup/SKILL.md`
- Codebase: `~/.config/nvim/.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`
- Codebase: `~/.config/nvim/.claude/extensions/email/context/project/email/patterns/bulk-bucket-review.md`
- Codebase (cross-repo): `~/.dotfiles/modules/home/email/agent-tools/{classify,census,archive-confirmed,delete-confirmed,lib,default}.nix`
- Codebase (cross-repo): `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md`
- `git log`/`git blame` on both repos to establish provenance and current-HEAD status
**Artifacts**: - this report; seed report at `reports/01_wrapper-gap-seed.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The seed report's three structural claims about the wrapper surface are **confirmed exactly**
  against current `.dotfiles` source: `email-census` takes no query positional (hardcoded
  queries only); `email-archive-confirmed`/`email-delete-confirmed` operate strictly against an
  **approved manifest file**, never against `+proposed-*` notmuch tags; and default mode's
  cursor query intentionally excludes all `+proposed-*`-tagged mail (by design, not a bug).
- The seed report's stated **root cause is not quite right**: `email-classify` is **not**
  "emit-on-change." Per `classify.nix` (current HEAD) and the extension's own
  `wrapper-contracts.md` §5c/§10 (independently verified against source at `.dotfiles` task
  805), **every** message id a classify call processes gets exactly one candidate-manifest line
  **unconditionally**, and is unconditionally re-tagged, regardless of whether the computed
  action differs from the tag it already carried.
- The actual, already-documented mechanical trap that best explains "0 records" is
  `wrapper-contracts.md` §10's own warning: **the candidate manifest is overwritten by every
  classify call**, including a `--limit 0` "counting probe" — which overwrites it with an
  **empty** file. Any classify invocation issued after (or interleaved with) the read-out
  attempt silently wipes it. This is a real, source-verified bug surface, distinct from the
  seed's "emit-on-change" framing.
- A second, previously undocumented correctness issue this research surfaces: the `--all` mode
  "residual pass" (already live in `SKILL.md`, added at task 803/815, **before** this task was
  filed) re-**derives** each residual message's action from the **current** rule table in
  `classify_one()`, not from the message's existing tag. If the rule table changed since the
  message was first tagged, the residual pass silently **overwrites** the durable tag — before
  the human ever sees it in Stage 2.5 — undermining the "previously seen and declined, tag
  unchanged" framing the skill's own cursor-rule commentary relies on.
- Recommended fix (confirms seed's own preference, fix 1 + fix 4, with a refined design): add a
  genuinely read-only `email-classify --emit-tagged` mode (reads existing `+proposed-*` tag,
  never calls `notmuch tag`, never recomputes the action) to `.dotfiles`
  `modules/home/email/agent-tools/classify.nix`, and change `skill-email-cleanup` Stage 1/2
  (`--all` mode) to call it instead of the current re-classify-and-retag pattern for residual
  buckets. `email-census`'s missing query positional (seed fix 2) and per-run persisted
  manifests (seed fix 3) are not required to close this task's specific gap and should be
  deferred/dropped — see Decisions.

## Context & Scope

Task 820 was filed after a live `/email --logos --all` run found that a mailbox with 0 new and
62 fully-tagged messages (12 `proposed-delete`, 3 `proposed-archive`, 42 `proposed-unsure`, 5
`proposed-keep`) could not be re-surfaced for the Stage 2.5 bucket review, because the
per-message record store (`candidate-manifest.jsonl`) appeared empty/near-empty when inspected.
The seed report (`01_wrapper-gap-seed.md`) proposed a root cause ("classify is emit-on-change")
and four candidate fixes spanning both `.dotfiles` (wrapper binaries) and this repo (the
`skill-email-cleanup` skill). This report's scope was to verify the seed's claims against the
actual current source in both repos, correct any inaccuracies, and produce a concrete,
file-and-function-level fix design for both sides.

Both repos were read directly (not from memory/summary): `.dotfiles` `agent-tools/` five-binary
split (post task-88), and this repo's `skill-email-cleanup/SKILL.md` plus its
`wrapper-contracts.md` context file, which itself carries its own independent source-verification
provenance (task 805 Phase 1, dated 2026-07-03, two days before this task's live incident).

## Findings

### Codebase Patterns

**1. `email-census` (`~/.dotfiles/modules/home/email/agent-tools/census.nix`)** — confirmed, no
query positional exists anywhere in the script. Every section (folder counts, sender census via
`notmuch address --output=sender --output=count --deduplicate=address -- '*'`, year-bucketed
date counts, `himalaya envelope list -f INBOX`) is hardcoded. There is no code path by which a
caller could pass `tag:proposed-delete` or any other filter. Seed claim confirmed exactly.

**2. `email-archive-confirmed` / `email-delete-confirmed`** — confirmed, both consume
`pending_ids_for_action()` (`lib.nix`, shared `mkMutationPreamble`), which is
`jq -r --arg action "$action" 'select(.proposed_action == $action) | .message_id' "$mf"` where
`$mf` defaults to `$MANIFEST_DIR/approved-manifest.jsonl` (overridable via `--manifest`). Neither
binary ever reads a notmuch tag directly. Seed claim confirmed exactly. This is intentional,
frozen safety behavior (contract §6, "approval provenance") and should not change.

**3. `email-classify` candidate-classification mode (`classify.nix` lines 82–172)** — read in
full. The inner loop (lines 132–167) processes every message id returned by
`notmuch search --output=messages "$QUERY" | head -n "$LIMIT"`, and for **each** one:
   - line 159–162: unconditionally appends one JSON line to `$CANDIDATE_FILE.tmp` (no gate on
     whether `action` differs from the message's existing `+proposed-*` tag);
   - line 164–165: unconditionally clears all four `+proposed-*` tags and re-applies
     `+proposed-$action` (again, no change-gate).

   This directly contradicts the seed's stated root cause ("classify instead only emits messages
   whose tag it *changes*"). It is also independently confirmed by this repo's own
   `wrapper-contracts.md` §5c ("classify calls are idempotent per message (its `+proposed-*` tag
   is cleared and re-applied, lines 473–474)") and §10 ("Every processed message is re-tagged
   with exactly one `+proposed-*` tag ... all four proposed tags cleared, then
   `+proposed-<action>` applied"), which was itself verified against `.dotfiles` source two days
   before this task's live incident (task 805 Phase 1, 2026-07-03).

**4. The real, already-documented destructive-overwrite trap** — `wrapper-contracts.md` §10:
   > "The candidate manifest is overwritten per call (`mv "$CANDIDATE_FILE.tmp"
   > "$CANDIDATE_FILE"`) ... Calling `email-classify --limit 0 "<query>"` therefore acts as a
   > wrapper-only counting probe: no message is processed, no tag is applied ... Side effect: the
   > candidate manifest is overwritten with an empty file — preserve any accumulator first."

   Traced through `classify.nix`: with `--limit 0`, `mids` is the empty string (`head -n 0`
   yields nothing), the processing loop runs zero iterations, and line 169
   (`mv "$CANDIDATE_FILE.tmp" "$CANDIDATE_FILE"`) still executes, replacing whatever
   `candidate-manifest.jsonl` held with a 0-line file. This mechanism is a far better fit for the
   seed's literal observation ("emits 0 records") than "emit-on-change": if the `--all` mode
   Stage 1 count-probe (which issues exactly this `--limit 0` pattern four times, once per prior
   tag, per `SKILL.md`) — or any ad hoc manual probe run during the live incident — executed at
   or after the point of inspecting `candidate-manifest.jsonl`, the file would read back empty
   regardless of what the immediately-preceding substantive classify call had written.
   `candidate-manifest.jsonl` is a single transient scratch file, not a durable per-message
   record store, and was never designed to survive a second classify call of any kind — a fact
   the skill authors already knew (hence the `--all` mode's `$ACCUMULATOR`-immediately-after-
   each-chunk discipline), but which is easy to violate outside that exact sequence.

**5. The `--all` mode residual pass already exists and is not new to this task** — `git blame`
shows the "Residual messages" bullet (`SKILL.md` Stage 2, `--all` mode) was introduced at
commit `19dc639f4` (task 803 phase 7) and carried forward through `6074fcc13` (task 815 phase 2,
account-aware). Both predate this task's 2026-07-04/05 live incident. The documented design
already runs "one bounded re-classify pass per prior tag" — `email-classify --account <account>
--limit <CHUNK_SIZE> "<SCOPE_QUERY> and tag:proposed-<X>"` for X in delete/archive/unsure/keep —
appending results to the sweep's `$ACCUMULATOR` with `"residual": true`. Given Finding 3 above
(classify unconditionally emits + re-tags every processed message, not just changed ones), this
design **should**, mechanically, already be capable of driving Stage 2.5 review for a
fully-tagged mailbox, provided the exact recipe (probes-before-sweep; no stray manual classify
calls mid-sweep) is followed. This suggests the live incident may be, in part, an
execution-fidelity gap (a manual/ad hoc reproduction sequence that deviated from the documented
recipe — e.g. the seed's own repro used a combined `(tag:proposed-delete or
tag:proposed-archive)` OR-query directly against `email-classify`, not the skill's prescribed
one-tag-at-a-time pattern, and does not report the exact probe/inspection ordering used) — not
purely a design gap. This does not invalidate the seed's conclusion that a fix is needed; it
sharpens where the fix should land (see Recommendations).

**6. New correctness issue found during this verification (not in the seed report)**: the
residual pass **recomputes** `proposed_action` from `classify_one()`'s current, hardcoded rule
table (`CUSTOM_DELETE_DOMAINS`, `CUSTOM_KEEP_SENDERS`, keyword lists — `classify.nix` lines
84–106), rather than reading the message's existing tag. If these constants have changed between
when a message was first tagged and when a later `--all` residual pass runs (e.g., a sender
domain is added to `CUSTOM_DELETE_DOMAINS` after a message was tagged `proposed-keep` or
`proposed-unsure`), the residual pass will silently flip that message's durable tag to the new
computed action, and unconditionally re-tag it (Finding 3), **before** the human sees it in
Stage 2.5. The Stage 2.5 human gate still stands between this and any mutation (so it is not
unsafe in the execute sense), but it is an unreviewed, silent rewrite of the "declined and
seen" audit signal the skill's own cursor-rule commentary depends on ("declined-but-seen
messages keep their durable tag"). A genuinely tag-reading, non-recomputing `--emit-tagged`
mode (Recommendations, below) removes this risk entirely, in addition to closing the destructive-
overwrite gap in Finding 4.

### External Resources

Not applicable — this is a self-contained wrapper-contract verification across two local repos;
no external documentation was needed or consulted.

### Recommendations

**Wrapper side — `.dotfiles` `modules/home/email/agent-tools/classify.nix`**:

Add a third top-level mode to `email-classify`, alongside the existing "append-approved" special
mode (lines 52–80) and "candidate classification" mode (lines 82–172): `--emit-tagged` (read-only
tag read-out; no `notmuch tag` call is ever made in this branch).

```bash
# New flag, parsed alongside --append-approved/--limit in the existing while-loop (lines 35-43):
#   --emit-tagged) EMIT_TAGGED=1; shift ;;

if [ "$EMIT_TAGGED" -eq 1 ]; then
  mids=$(notmuch search --output=messages "$QUERY" 2>/dev/null | sed 's/^id://' || true)
  : > "$CANDIDATE_FILE.tmp"
  n=0
  while IFS= read -r mid; do
    [ -z "$mid" ] && continue
    json=$(notmuch show --format=json --body=false "id:$mid" 2>/dev/null \
      | jq -c 'if (.[0][0][0] | type) == "object" then .[0][0][0] else empty end' 2>/dev/null || true)
    [ -z "$json" ] && continue
    tags=$(echo "$json" | jq -r '(.tags // []) | join(",")')
    action=""
    case ",$tags," in
      *,proposed-delete,*)  action="delete"  ;;
      *,proposed-archive,*) action="archive" ;;
      *,proposed-unsure,*)  action="unsure"  ;;
      *,proposed-keep,*)    action="keep"    ;;
    esac
    [ -z "$action" ] && continue   # not yet classified — out of scope for a tag read-out
    subject=$(echo "$json" | jq -r '.headers.Subject // ""')
    from=$(echo "$json" | jq -r '.headers.From // ""')
    date=$(echo "$json" | jq -r '.headers.Date // ""')
    # Recompute confidence/reason for DISPLAY ONLY (classify_one is pure, side-effect-free) —
    # the action itself always comes from the existing tag above, NEVER from this recompute,
    # so a stale/changed rule table can never silently flip a message's category here.
    sender_lc=$(printf '%s' "$from" | tr '[:upper:]' '[:lower:]')
    result=$(classify_one "$sender_lc")
    reason="tag-derived;${result#*|}"          # keep the confidence/reason segment, tag-derived
    confidence="''${result#*|}"; confidence="''${confidence%%|*}"
    jq -nc --arg mid "$mid" --arg sender "$from" --arg subject "$subject" --arg date "$date" \
      --arg action "$action" --arg reason "$reason" --argjson confidence "$confidence" \
      '{message_id:$mid, sender:$sender, subject:$subject, date:$date, proposed_action:$action, reason:$reason, confidence:$confidence}' \
      >> "$CANDIDATE_FILE.tmp"
    n=$((n + 1))
  done <<< "$mids"
  mv "$CANDIDATE_FILE.tmp" "$CANDIDATE_FILE"
  log "Emitted $n tagged record(s) from existing +proposed-* tags (read-only: no re-tag, no recompute of action)."
  exit 0
fi
```

Key invariants for the implementer to preserve (see Decisions for the ones requiring an explicit
choice):
- **No `notmuch tag` call anywhere in this branch.** This is what makes the mode safe to call
  repeatedly, interleaved with anything else, without the Finding-4/Finding-6 risks.
- `--limit`/`MAX_BATCH_SIZE` do not apply here (no mutation, no batch-cap rationale) — process
  the full query match. If the implementer wants a safety valve for very large mailboxes, a
  separate `--limit` semantic (a true cap, not `head -n`-vs-total logging) could be added, but is
  not required to close this task.
- The `$CANDIDATE_FILE` overwrite-per-call caveat (Finding 4) still applies to this mode's own
  output path — that is fine and expected here, since the point of `--emit-tagged` IS to
  (re)populate that file from durable tags on demand; it should not need an accumulator to
  survive a single call for the immediate Stage 2.5 review construction.
- Safety class: this mode is closer to `read-only` than `local-tags-only` — worth reflecting in
  `--help` output and `wrapper-contracts.md`'s binary table (see spawned sub-task scope).

**Skill side — `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md`, `--all` mode**:

1. **Stage 1 count probe** (bullet 2, "Count probe"): once `--emit-tagged` exists, the four
   residual-count probes can use it directly (`email-classify --emit-tagged --account <account>
   "<SCOPE_QUERY> and tag:proposed-<X>"` and count output lines) instead of the current
   `--limit 0` counting-probe pattern against the mutating classify mode — this also sidesteps
   Finding 4's destructive-overwrite race entirely for the residual counts (the *new-message*
   count probe still legitimately needs the mutating mode's `--limit 0` NOTE-line count oracle,
   since untagged messages have no tag for `--emit-tagged` to read).
2. **Stage 2 residual pass** (bullet "Residual messages"): change
   `email-classify --account <account> --limit <CHUNK_SIZE> "<SCOPE_QUERY> and
   tag:proposed-<X>"` to `email-classify --emit-tagged --account <account> "<SCOPE_QUERY> and
   tag:proposed-<X>"` for each of delete/archive/unsure/keep. This removes both the
   destructive-overwrite footgun (Finding 4) and the silent-tag-rewrite-from-rule-drift risk
   (Finding 6), since `--emit-tagged` never calls `notmuch tag`. The existing
   "documented completeness caveat" (residual coverage bounded per prior-tag bucket) can likely
   be dropped once `--emit-tagged` has no batch/mutation rationale for a cap — recommend the
   implementer re-confirm whether an unbounded-per-tag read makes sense at the account's actual
   scale before removing the caveat outright.
3. **Explicit "0 new, all residual" framing** (fix 4's own ask): once the new-message count probe
   reports `N=0`, have the skill emit a distinct one-line status ("0 new messages; N residual
   across 4 tag buckets — proceeding directly to bucket review") before Stage 2.5, rather than
   silently falling through the same code path as a mixed new+residual sweep. This is a
   documentation/UX clarity change, not new control flow, since the residual pass already runs
   unconditionally after the new-message loop terminates.
4. Update this repo's `wrapper-contracts.md` (§1 binary table, §6 approval provenance, §10
   pagination contract) to document the new `--emit-tagged` mode once implemented, and to record
   the corrected understanding that `email-classify` re-tags/emits **unconditionally**, not
   on-change — so a future agent researching this area does not re-derive (or re-trust) the
   "emit-on-change" framing this report is correcting.

**Deferred / not required for this task**:
- Seed fix 2 (`email-census "<query>"` positional): a reasonable, independent read-only
  enumeration convenience, but neither the existing `--all` design nor the recommended
  `--emit-tagged` fix depends on it. Recommend filing separately if wanted, not bundling into
  this task's `.dotfiles` sub-task.
- Seed fix 3 (persist per-run candidate manifests, timestamped, not overwritten): the `--all`
  mode's own `$ACCUMULATOR` file already does this within one sweep invocation. `--emit-tagged`
  supersedes the cross-session use case this fix targeted (a later invocation can always
  regenerate an equivalent read-out on demand from durable tags, rather than needing to locate
  and re-parse a prior session's ephemeral accumulator file). Recommend not pursuing this
  separately.

## Decisions

- **Root-cause correction adopted**: this report treats "unconditional re-tag/re-emit,
  destructively overwritten per call" (Findings 3–4, both independently source- and
  contract-doc-verified) as the operative root cause instead of the seed's "emit-on-change"
  framing. The seed's proposed fixes 1 and 4 remain the right shape; only the diagnosis changes,
  which changes what the wrapper implementer needs to guard against (overwrite/idempotency, not
  "detect changed messages").
- **`--emit-tagged` derives `proposed_action` from the existing notmuch tag, never from a
  recompute of `classify_one()`.** This is the key design choice that closes Finding 6
  (silent tag rewrite from rule-table drift). `classify_one()` may still be called for
  confidence/reason display fields only, clearly labeled `reason="tag-derived;..."` so a
  consumer can tell a tag-derived record apart from a freshly-computed one.
- **`--emit-tagged` is unbounded (no `--limit`/batch-cap applies)** since it performs no
  mutation and no notmuch tag write; the `MAX_BATCH_SIZE=50` rationale (protecting against
  runaway *mutation*) does not transfer to a pure read.
- **`email-census`'s missing query positional and per-run persisted manifests (seed fixes 2/3)
  are out of scope** for closing this specific gap; recommend not bundling them into the
  `.dotfiles` sub-task this task will spawn, to keep that sub-task's territory narrow and
  reviewable.
- **Default mode (`mode=default`) requires no change.** Its cursor-query exclusion of all
  `+proposed-*` tags is intentional (SKILL.md line 148 explicitly hands the revisit job to
  `--all`); this task's fix makes that hand-off actually work, rather than changing default
  mode's own behavior.

## Risks & Mitigations

- **Risk**: `--emit-tagged`'s recomputed confidence/reason fields will not match whatever
  confidence originally justified the tag (that historical value is not durably stored anywhere
  — the only record was the transient, overwritten `candidate-manifest.jsonl`). **Mitigation**:
  document this explicitly as "confidence is current-rules-derived, for review display only;
  action is tag-derived and authoritative" in both the wrapper's `--help` text and
  `wrapper-contracts.md`.
- **Risk**: implementing `--emit-tagged` in `.dotfiles` is a cross-repo change this task cannot
  make directly (this repo has no machine dependency on `.dotfiles`, by design —
  `wrapper-contracts.md` line 6). **Mitigation**: spawn a `.dotfiles` sub-task for the wrapper
  change, mirroring the existing task 72/79/80 cross-repo pattern the seed report references;
  this repo's own change (SKILL.md Stage 1/2 + wrapper-contracts.md documentation) can land
  independently but should note it is blocked on the `.dotfiles` binary actually shipping
  `--emit-tagged` before the skill can call it.
- **Risk**: this report's re-diagnosis (Finding 3/4) rests on static source reading, not a fresh
  live reproduction against the actual Logos maildir (this research agent has no access to that
  live environment). **Mitigation**: recommend the implementation phase include one live
  read-only probe cycle (`email-classify --limit 0 "..."` then immediately
  `cat candidate-manifest.jsonl`) against the real mailbox before writing the fix, purely to
  confirm Finding 4's overwrite-to-empty mechanism reproduces exactly as traced through source,
  since this is the load-bearing claim the whole fix design rests on.

## Context Extension Recommendations

- **Topic**: `email-classify`'s exact per-call manifest/tag semantics.
- **Gap**: `wrapper-contracts.md` §10 already documents the overwrite-per-call and
  unconditional-re-tag facts correctly, but nothing in this repo's context previously flagged
  that these facts **contradict** an "emit-on-change" mental model an agent might otherwise form
  from casual reading of the `--all` mode's residual-pass prose (which talks about "re-classify"
  in a way that reads compatibly with either model). This report is itself the correction;
  recommend folding a short explicit note into `wrapper-contracts.md` §10 stating plainly:
  "classify is NOT emit-on-change — every processed message is re-emitted and re-tagged
  unconditionally" so a future agent does not have to re-derive this from source.

## Appendix

**Search/verification steps used** (all local, no web search needed):
1. Read `reports/01_wrapper-gap-seed.md` in full.
2. Read `skill-email-cleanup/SKILL.md` in full (492 lines) — confirmed current `--all` mode
   design, residual-pass text, count-probe text.
3. Located `.dotfiles` wrapper source via `find ~/.dotfiles -path "*modules/home/email*"`.
4. Read `classify.nix`, `lib.nix`, `census.nix`, `archive-confirmed.nix`, `delete-confirmed.nix`
   (partial), `default.nix` in full or in relevant part.
5. `git log`/`git blame`/`git log -p` on both repos to establish provenance: `classify.nix` last
   touched at the task-88 split (`d81cbf8`) plus a lint-only commit (`8bc1aee`); `SKILL.md`'s
   residual-pass text traced to task 803 (`19dc639f4`), carried through task 815
   (`6074fcc13`), both predating this task's live incident.
6. Read `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` in full —
   found §5c and §10 independently corroborate the source-code reading and predate this task by
   two days (task 805, 2026-07-03), meaning the "emit-on-change" framing in the seed report was
   avoidable by cross-checking this file.
7. Skimmed `bulk-bucket-review.md` for Stage 2.5 bucket-construction context (residual labeling,
   `min()` rollup, 0.90 gate) to confirm the recommended fix integrates cleanly with existing
   Stage 2.5 machinery without requiring changes there.

**Files identified as the precise change targets**:
- `.dotfiles`: `modules/home/email/agent-tools/classify.nix` (add `--emit-tagged` mode; arg
  parsing near lines 35–43, new branch near line 80 alongside the `--append-approved` special
  mode).
- `.dotfiles`: `specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md`
  and/or successor contract doc — document the new mode.
- This repo: `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — Stage 1 "Count
  probe" bullet and Stage 2 "Residual messages" bullet (`--all` mode section, lines ~216–261).
- This repo: `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` — §1,
  §6, §10 updates once `--emit-tagged` ships.
