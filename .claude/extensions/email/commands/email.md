---
description: Wrapper-only email triage (census, classify, review, confirmed archive/delete/unsubscribe-extract) in a safer 50-step default mode or --all whole-mailbox mode, --archive to scope to All Mail, or --sync to reconcile the cleanup to Gmail
---

# Command: /email

**Purpose**: Ad-hoc email cleanup pass over Himalaya/notmuch via the five nix-built wrapper
binaries, with a mandatory human review/approval gate before any mutation. The default is a
bounded 50-at-a-time stepping pass; `--all` is a whole-mailbox pass (chunked classify sweep, one
consolidated bucket approval, transparent sub-50 execute drain); `--archive` scopes either mode
to All Mail with extra-caution gates. With `--sync`, instead reconciles a completed cleanup to
the Gmail server via `mbsync`.
**Layer**: 2 (Command File - Argument Parsing)
**Delegates To**: skill-email-cleanup (default and `--all`/`--archive`) or skill-email-sync
(`--sync`), both direct execution

**Input**: $ARGUMENTS
- Default (no flags): a bounded, safer 50-step cleanup pass. Repeated bare `/email` runs step
  forward through the mailbox (durable `+proposed-*` tags act as a cross-invocation cursor).
  Optional free-text focus hint (e.g. a sender/domain/folder to focus on).
- `--all`: whole-mailbox mode — classify EVERYTHING in scope (chunked, backgrounded read/tag-only
  sweep), then ONE consolidated sender/domain bucket approval, then a mechanical sub-50 execute
  drain with progress-only reporting.
- `--archive`: scope flag — operate on All Mail (`folder:Gmail/.All_Mail`) instead of INBOX, with
  extra-caution gates (second blast-radius confirmation, stricter delete bar, reversible-first
  deletes, pilot gate). Composable with default mode (50-step through All Mail) and with `--all`
  (`/email --all --archive` = full All Mail sweep).
- `--sync [channel]`: reconcile local mutations to the server; optional mbsync channel name
  (default `gmail`).

---

## Argument Parsing

<argument_parsing>
  <step_1>
    If `$ARGUMENTS` begins with the `--sync` flag, this is a SYNC invocation. Capture any token
    following `--sync` as the mbsync channel name (default `gmail` when omitted). Route to the
    sync workflow below; do NOT run a cleanup pass. `--sync` is a distinct route: it never
    combines with `--all`/`--archive` in a single invocation (if both appear, `--sync` wins and
    the others are reported as ignored).
  </step_1>
  <step_2>
    Otherwise this is a CLEANUP invocation. Scan `$ARGUMENTS` for the two composable cleanup
    flags and remove them from the argument string:
    - `--all` present -> `mode=all` (whole-mailbox); absent -> `mode=default` (50-step).
    - `--archive` present -> `scope=archive` (All Mail, `folder:Gmail/.All_Mail`); absent ->
      `scope=inbox` (`folder:Gmail`).
    The flags compose freely: `/email --all --archive` is `mode=all, scope=archive`. Flag order
    is irrelevant.
  </step_2>
  <step_3>
    Parse the remaining `$ARGUMENTS` (after flag removal) as an optional free-text focus hint
    (e.g. "focus on newsletters", "sender github.com"). No hint is required; an empty remainder
    runs an unfocused pass over the selected scope. Route to the cleanup workflow below with
    (mode, scope, focus_hint).
  </step_3>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <cleanup_path>
    <action>Delegate to Email Cleanup Skill (any invocation without --sync)</action>
    <input>
      - skill: "skill-email-cleanup"
      - args: "mode={default|all}, scope={inbox|archive}, focus_hint={hint or empty}"
    </input>
    <expected_return>
      A census summary, a candidate set presented for review (per-message in default mode; ONE
      consolidated sender/domain bucket approval in --all mode), and (after explicit user
      approval) a report of which Message-IDs were actually archived/deleted/extracted. In --all
      mode the execute phase is a mechanical sub-50 drain with progress-only reporting — no
      per-batch re-prompt after the single bucket approval. Both `--all` and `--archive` route to
      this SAME skill (no fork); the mode/scope branches live inside skill-email-cleanup.
    </expected_return>
  </cleanup_path>
  <sync_path>
    <action>Delegate to Email Sync Skill (when --sync is present)</action>
    <input>
      - skill: "skill-email-sync"
      - args: "channel={channel or gmail}"
    </input>
    <expected_return>
      A precondition check, an explicit confirmation prompt, then an `mbsync <channel>` reconcile
      that propagates the completed cleanup's archives/deletes up to Gmail, with the sync result
      reported. Run this only after a cleanup is complete and reviewed - never interleaved with an
      active cleanup batch (freeze sync during bulk ops).
    </expected_return>
  </sync_path>
</workflow_execution>

---

## Safety Notes

`/email` (cleanup) NEVER mutates anything without an explicit, in-conversation user approval of a
reviewed candidate manifest. The skill is wrapper-only: it invokes `email-census`,
`email-classify`, `email-archive-confirmed`, `email-delete-confirmed`, and
`email-unsubscribe-extract` by name only, never raw `himalaya`/`notmuch`/`msmtp`/`secret-tool`.

**Safety posture by invocation form**:

- `/email` (default) is the SAFER mode: each pass is bounded to at most 50 candidates, reviewed
  per-message, and can never trip the wrapper's batch cap. Prefer it unless the user explicitly
  asks for a whole-mailbox operation.
- `/email --all` classifies the entire scope but concentrates the human decision into ONE
  consolidated bucket approval; everything after that approval is a mechanical drain of ≤50-per-
  action sub-manifests. Only the read/tag-only classify sweep may run in the background; the
  bucket-approval AskUserQuestion and the whole execute drain run in the root session (direct
  execution) — never in a background subagent.
- `/email --archive` (with or without `--all`) targets All Mail (~64k messages): it adds a
  second, distinctly-worded blast-radius confirmation, a stricter delete-confidence bar, defaults
  to recoverable Trash (expunge is opt-in only), and is blocked at full scale until a bounded
  pilot pass has been acknowledged (see skill-email-cleanup's pilot gate).
- The wrapper's `MAX_BATCH_SIZE=50` per-action cap is FROZEN (cross-repo contract, .dotfiles
  task 72). No mode raises it — `--all` loops over ≤50 splits instead.
- Never auto-chain `/email --sync` after a cleanup — especially not after an `--archive` drain.
  The mutation wrappers already run their own group-scoped `mbsync gmail` reconcile internally;
  `--sync` is a separate, human-confirmed operation.

`/email --sync` performs no classification and mutates no local mail; it runs a single
`mbsync <channel>` reconcile that PUSHES the already-approved local archives/deletes up to Gmail.
Because it can make locally expunged deletions permanent server-side, skill-email-sync also stops
for an explicit confirmation before running. `mbsync` is not a wrapper binary and is not denied by
`mail-guard.sh` (it passes through the hook). Never run `--sync` while a cleanup batch is
mid-flight (freeze sync during bulk ops).

---

## Error Handling

<error_handling>
  <execution_errors>
    - Wrapper binary missing from `$PATH` -> Report which binary and instruct
      `home-manager switch --flake .#<user>`
    - `mbsync` missing from `$PATH` (`--sync`) -> Report and instruct `home-manager switch`
    - Unknown mbsync channel/group (`--sync`) -> Read `~/.mbsyncrc` and ask which channel to use
    - Skill failure -> Return error details, no mutation performed
  </execution_errors>

  <interactive_errors>
    - User declines all proposed actions -> Exit gracefully, no files/messages mutated
    - User declines the sync confirmation -> Exit gracefully, no reconcile performed
  </interactive_errors>
</error_handling>
