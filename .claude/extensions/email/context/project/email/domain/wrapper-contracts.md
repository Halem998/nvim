# Wrapper Contracts (Frozen, Task 72 §1-§9)

Summary of the frozen wrapper contract this extension authors and executes against. The
contract itself lives in the `.dotfiles` repo (Task 72 handoff, FROZEN); this file records the
parts an `email`-typed agent/skill needs at runtime. Cross-repo coupling is
documentation-only — this extension declares no machine dependency on `.dotfiles`.

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
  mismatch (guards against edited/substituted manifests).
- **`--account gmail` reserved on all five.** Any other value is a hard error.
- **`--manifest-dir <path>`** overrides manifest storage.
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

## 5. Constants and Policies

| Policy | Value |
|--------|-------|
| Max IDs mutated per `--execute` run | `MAX_BATCH_SIZE = 50` |
| Approved-manifest staleness limit | `PLAN_EXPIRY_DAYS = 7` |
| Min confidence to auto-propose delete | `>= 0.90` (below -> `unsure`) |
| Execute-mode target derivation | diff executed IDs against the approved manifest; never re-derive |

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
alone is a no-op on an unflagged message); a sync step then reconciles the server side.

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
