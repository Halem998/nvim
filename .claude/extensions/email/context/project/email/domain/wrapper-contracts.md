# Wrapper Contracts (Frozen, Task 72 §1-§9)

Summary of the frozen wrapper contract this extension authors and executes against. The
contract itself lives in the `.dotfiles` repo (Task 72 handoff, FROZEN); this file records the
parts an `email`-typed agent/skill needs at runtime. Cross-repo coupling is
documentation-only — this extension declares no machine dependency on `.dotfiles`.

**Ground-truth verification**: every claim below marked with a line reference was re-verified
verbatim against `~/.dotfiles/modules/home/email/agent-tools.nix` (718 lines) on 2026-07-03
(task 805, Phase 1). The wrapper is frozen: nothing in this extension may modify it, add flags
to it, or raise its constants (in particular `MAX_BATCH_SIZE=50` — split/loop instead).

## 1. The Five Binaries

| Binary | Verb | Safety class | Mutates? |
|--------|------|--------------|----------|
| `email-census` | report sender/folder/date census | read-only | no |
| `email-classify` | apply provisional `+proposed-*` notmuch tags; emit candidate manifest; `--append-approved` | local-tags-only | notmuch tags only (never maildir/IMAP) |
| `email-unsubscribe-extract` | extract `List-Unsubscribe` headers to a review list | read-only | no (never fetches/POSTs URLs) |
| `email-archive-confirmed` | move approved-`archive` IDs to All Mail | mutation | yes (maildir move) |
| `email-delete-confirmed` | move approved-`delete` IDs to Trash; `--expunge-trash` permanently removes | mutation | yes (maildir move + expunge) |

## 2. Global Flag Contract (all five signatures)

- **Dry-run by default.** Mutation binaries print the plan only, unless `--execute` is passed.
  The flag is positive `--execute` (never `--no-dry-run`).
- **`--execute` requires `--confirm-manifest <sha256>`.** The sha256 is computed over the raw
  bytes of the approved manifest file; the wrapper recomputes it at run time and refuses on
  mismatch (guards against edited/substituted manifests) (lines 125-133).
- **`--account gmail` reserved on all five.** Any other value is a hard error.
- **`--manifest-dir <path>`** overrides manifest storage.
- **`--manifest <path>`** (mutation binaries) points at an arbitrary approved-manifest file;
  default is `<manifest-dir>/approved-manifest.jsonl` (lines 101-109). All hash, mtime, batch,
  and state-file checks are computed against **whatever file `--manifest` points at** — this is
  what makes split sub-manifests first-class (each split independently hash-confirmed,
  expiry-checked, and state-tracked).
- `--help` on every binary prints its verb, safety class, and flags.

## 3. Manifest Schema (JSONL, keyed on Message-ID)

```json
{"message_id": "<id@host>", "sender": "a@b.com", "subject": "...", "date": "2026-02-16T21:18:00Z",
 "proposed_action": "delete|archive|unsure|keep", "reason": "...", "confidence": 0.94}
```

Himalaya envelope ids are per-folder and change on move; they are never manifest keys.

## 4. Companion Execution-State File (`<manifest>.state.jsonl`)

Per-Message-ID execution status, kept separate from the approved manifest so the approved
manifest's bytes (and sha256) stay immutable across a run. `--execute` skips IDs already
`executed` and records `failed` with error text — safely re-runnable.

Verified details (task 805 Phase 1):

- The state-file path is **derived per manifest path**: `STATE_FILE="${MANIFEST_FILE}.state.jsonl"`
  (line 111). A split sub-manifest at `splits/split-03.jsonl` therefore gets its own
  `splits/split-03.jsonl.state.jsonl` — idempotency is per split file, with no shared ledger.
- The state file is append-only JSONL, last line per Message-ID wins (lines 151-166).
- `email-delete-confirmed --expunge-trash` (hop 2) uses a **separate** companion,
  `${MANIFEST_FILE}.expunge-state.jsonl`, and gates each ID on the hop-1 state file showing
  `executed` (lines 630-637, 677-682). Hop 2 must therefore be pointed at the **same
  `--manifest` path** as hop 1 or every ID is skipped with "not yet moved to Trash".

## 5. Constants and Policies

| Policy | Value |
|--------|-------|
| Max IDs mutated per `--execute` run | `MAX_BATCH_SIZE = 50` (line 34; FROZEN — never raise; split/loop instead) |
| Approved-manifest staleness limit | `PLAN_EXPIRY_DAYS = 7` (line 35) |
| Min confidence to auto-propose delete | `>= 0.90` (below -> `unsure`) (lines 459-466) |
| Execute-mode target derivation | diff executed IDs against the approved manifest; never re-derive |

### 5a. Hard-refuse-over-cap behavior (verified, lines 236-243)

`enforce_batch_size <action>` counts the manifest lines whose `proposed_action` equals that
action **in the file `--manifest` points at**, and if the count exceeds `MAX_BATCH_SIZE=50` it
logs `"... exceeds MAX_BATCH_SIZE=50 — split required"` and exits 1. It **never
partial-processes and never auto-chunks** — the caller must split.

The cap is **per action, per file**: `email-archive-confirmed` enforces it for `archive` lines
only (line 559) and `email-delete-confirmed` for `delete` lines only (line 639). One manifest
file containing ≤50 `archive` lines AND ≤50 `delete` lines passes both binaries' caps — a
mixed split file can carry up to 100 mutations (50+50) across the two binaries.

### 5b. Mtime-based expiry semantics (verified, lines 135-142)

The expiry check runs **only under `--execute`** and reads the raw filesystem mtime of the
pointed-at manifest: `stat -c %Y "$MANIFEST_FILE"`; if `(now - mtime) / 86400 > 7` the wrapper
refuses to mutate ("Re-approve via the ... review flow"). Consequences:

- Copying an approved manifest into split files resets mtime; `touch -r <original> <split>`
  preserves the original approval time so splits expire exactly when the original approval
  would have — split-file creation must never be allowed to silently extend the 7-day window.
- Dry-run planning (`--execute` absent) is not expiry-gated.

### 5c. Classifier confidence constants (verified, lines 396-432, 459-466)

`classify_one()` is a **deterministic rule table with hardcoded constants** — not a model, not
tunable at invocation time:

| Rule tier | Action | Confidence |
|-----------|--------|------------|
| `CUSTOM_KEEP_SENDERS` match (1 sender) | keep | 0.98 |
| `CUSTOM_DELETE_DOMAINS` match (14 domains, lines 396-400) | delete | 0.98 |
| `NEWSLETTER_KEYWORDS` match | archive | 0.60 |
| `NOTIFICATION_DOMAINS` match | archive | 0.55 |
| no match | unsure | 0.50 |

A `delete` below 0.90 is downgraded to `unsure` with
`;downgraded-below-0.90-delete-threshold` appended to the reason (lines 459-466). Because the
constants are deterministic, re-classifying the same message yields the same result —
classify calls are idempotent per message (its `+proposed-*` tag is cleared and re-applied,
lines 473-474).

## 6. Approval Provenance

1. `email-classify` (dry-run) emits a candidate manifest and applies `+proposed-*` tags.
   Candidates are not approved and are never consumed by mutation wrappers.
2. A human review/approval gesture is the sole approval act: it appends a Message-ID line to an
   approved manifest.
3. Mutation wrappers consume ONLY approved manifests — never `email-classify`'s raw candidate
   output.

## 7. Delete Invariant

Himalaya's backend is maildir; safety is a sequence: delete moves a message to Trash (leaving
flags `:2,S`); `--expunge-trash` must `\Deleted`-flag the message before expunging (expunge
alone is a no-op on an unflagged message); a sync step then reconciles the server side. Move
and expunge are **independently human-gated** — each hop needs its own
`--execute --confirm-manifest` invocation, tracked in separate state files (§4).

### 7a. Built-in post-mutation reconcile (verified, lines 253-279, 591-593, 713-715)

After any run in which at least one ID was actually executed, both mutation binaries
internally run `mbsync gmail` (group-scoped, never `mbsync -a`) with an auth-failure fail-safe
(`invalid_grant` / `[AUTHENTICATIONFAILED]` detection halts further mutation and preserves the
manifest + state files). This reconcile is **wrapper-internal and part of the frozen
contract** — it is distinct from the `/email --sync` skill, which is a separate, human-confirmed
reconcile for cases outside a wrapper run. Skills must never auto-chain `/email --sync` onto a
cleanup; the wrapper's own reconcile already covers the per-run server push.

## 8. Two-Layer Enforcement Model

1. **`mail-guard.sh` PreToolUse hook**: gates the agent's own top-level Bash calls. Allowlists
   only the five wrapper binaries; denies raw `himalaya message delete|move|send`, `himalaya
   folder expunge`, `msmtp`, `secret-tool`, `rm *Mail*`. Does not police the wrappers' own
   subprocesses.
2. **The nix-built wrapper source itself**: hash check, staleness, batch cap, and state file are
   baked into the binaries, so safety holds even for a human invoking a wrapper directly.

## 9. $PATH Precondition (this extension's added requirement)

The binaries are only on `$PATH` after a `home-manager switch` activates the generation
containing the wrapper module. Agents/skills in this extension must check
`command -v email-census` (and peers) and fail with an actionable message
("run `home-manager switch`") rather than a raw "command not found".

## 10. email-classify Pagination Contract (verified, task 805 Phase 1)

These facts govern any multi-pass ("sweep") design built on top of `email-classify`:

- **`--limit <N>` is a head-cap, not a page.** The binary runs
  `notmuch search --output=messages "$QUERY" | head -n "$LIMIT"` (line 435; newest-first
  order). Default `LIMIT` is `MAX_BATCH_SIZE=50` (line 345). There is **no offset / `--skip` /
  `--after` flag** — repeated calls with the same QUERY re-process the same newest N.
- **`QUERY` is a free positional** (lines 356-359), default `"folder:Gmail"` (= INBOX, line
  344). It accepts any notmuch query expression, including `folder:`, `date:`, `tag:`, and
  `id:a or id:b ...` terms. This positional is the only pagination lever the frozen wrapper
  exposes — folder scoping, date-windowing, tag-exclusion, and id-list slicing are all
  expressed here, by the caller, without any raw `notmuch` invocation.
- **The candidate manifest is overwritten per call** (`mv "$CANDIDATE_FILE.tmp"
  "$CANDIDATE_FILE"`, line 478). Any accumulation across calls must copy/append the candidate
  file to a caller-owned accumulator **before** the next call.
- **Total-match disclosure ("count oracle")**: when the query matches more messages than
  `--limit`, the wrapper logs `"NOTE: query matched <total> message(s); processing the first
  <LIMIT>"` (lines 436-439). Calling `email-classify --limit 0 "<query>"` therefore acts as a
  wrapper-only **counting probe**: no message is processed, no tag is applied, and the NOTE
  line discloses the total (absent NOTE = 0 matches). Side effect: the candidate manifest is
  overwritten with an empty file — preserve any accumulator first.
- **Every processed message is re-tagged with exactly one `+proposed-*` tag** (all four
  proposed tags cleared, then `+proposed-<action>` applied; lines 473-474). Tags are durable
  in notmuch across invocations, so `... and not tag:proposed-delete and not
  tag:proposed-archive and not tag:proposed-unsure and not tag:proposed-keep` is a valid
  forward-progress cursor for never-before-classified messages.
- **No wrapper emits a complete message-ID list for an arbitrary query.** Verified across all
  five binaries: `email-census` prints hardcoded counts/samples only; `email-classify`'s
  candidate manifest contains only the (≤ limit) messages it processed and is overwritten per
  call; `email-unsubscribe-extract` emits IDs only for messages bearing a `List-Unsubscribe`
  header. Consequently a "capture the full in-scope ID list once, then slice it" pagination
  design is **not implementable wrapper-only**; sweep designs must paginate via the QUERY
  positional (date windows and/or tag exclusion) with `--limit`, per the count oracle above.

## 11. Folder-Scope Query Tokens (verified)

Notmuch folder tokens for the gmail maildir, as hardcoded in `email-census` (lines 297-303):

| Mailbox | notmuch query token |
|---------|---------------------|
| INBOX | `folder:Gmail` |
| All Mail (archive) | `folder:Gmail/.All_Mail` |
| Sent | `folder:Gmail/.Sent` |
| Trash | `folder:Gmail/.Trash` |
| Spam | `folder:Gmail/.Spam` |
| Drafts | `folder:Gmail/.Drafts` |

The All Mail token `folder:Gmail/.All_Mail` (line 299) is the exact scope token for
archive-scoped (`--archive`) operations, passed as (part of) the `email-classify` QUERY
positional — no wrapper flag exists or is needed for folder scoping.
