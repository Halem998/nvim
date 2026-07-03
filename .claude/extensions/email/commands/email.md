---
description: Wrapper-only email triage (census, classify, review, confirmed archive/delete/unsubscribe-extract), or --sync to reconcile the cleanup to Gmail
---

# Command: /email

**Purpose**: Ad-hoc email cleanup pass over Himalaya/notmuch via the five nix-built wrapper
binaries, with a mandatory human review/approval gate before any mutation. With `--sync`, instead
reconciles a completed cleanup to the Gmail server via `mbsync`.
**Layer**: 2 (Command File - Argument Parsing)
**Delegates To**: skill-email-cleanup (default) or skill-email-sync (`--sync`), both direct execution

**Input**: $ARGUMENTS
- Default: an optional free-text focus hint (e.g. a sender/domain/folder to focus on).
- `--sync [channel]`: reconcile local mutations to the server; optional mbsync channel name
  (default `gmail`).

---

## Argument Parsing

<argument_parsing>
  <step_1>
    If `$ARGUMENTS` begins with the `--sync` flag, this is a SYNC invocation. Capture any token
    following `--sync` as the mbsync channel name (default `gmail` when omitted). Route to the
    sync workflow below; do NOT run a cleanup pass.
  </step_1>
  <step_2>
    Otherwise, parse `$ARGUMENTS` as an optional free-text focus hint (e.g. "focus on newsletters",
    "folder INBOX", "sender github.com"). No hint is required; an empty `$ARGUMENTS` runs a
    full inbox triage pass. Route to the cleanup workflow below.
  </step_2>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <cleanup_path>
    <action>Delegate to Email Cleanup Skill (default, no --sync)</action>
    <input>
      - skill: "skill-email-cleanup"
      - args: "focus_hint={hint or empty}"
    </input>
    <expected_return>
      A census summary, a candidate manifest presented for review, and (after explicit user
      approval) a report of which Message-IDs were actually archived/deleted/extracted.
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
