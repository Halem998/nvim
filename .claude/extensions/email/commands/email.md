---
description: Wrapper-only email triage (census, classify, review, confirmed archive/delete/unsubscribe-extract) in a safer 50-step default mode or --all whole-mailbox mode, --archive to scope to the account's archive folder, or --sync to reconcile the cleanup to the account's server. --account <gmail|logos> / --logos selects the account (default gmail).
---

# Command: /email

**Purpose**: Ad-hoc email cleanup pass over Himalaya/notmuch via the five nix-built wrapper
binaries, with a mandatory human review/approval gate before any mutation. The default is a
bounded 50-at-a-time stepping pass; `--all` is a whole-mailbox pass (chunked classify sweep, one
consolidated bucket approval, transparent sub-50 execute drain); `--archive` scopes either mode
to the account's archive folder with extra-caution gates. With `--sync`, instead reconciles a
completed cleanup to the account's server via `mbsync`. An orthogonal `--account <gmail|logos>` /
`--logos` selector (default `gmail`) chooses which mailbox account these modes/flags apply to —
see the Accounts subsection below.
**Layer**: 2 (Command File - Argument Parsing)
**Delegates To**: skill-email-cleanup (default and `--all`/`--archive`) or skill-email-sync
(`--sync`), both direct execution

**Input**: $ARGUMENTS
- Default (no flags): a bounded, safer 50-step cleanup pass against `account=gmail`. Repeated bare
  `/email` runs step forward through the mailbox (durable `+proposed-*` tags act as a
  cross-invocation cursor). Optional free-text focus hint (e.g. a sender/domain/folder to focus
  on).
- `--all`: whole-mailbox mode — classify EVERYTHING in scope (chunked, backgrounded read/tag-only
  sweep), then ONE consolidated sender/domain bucket approval, then a mechanical sub-50 execute
  drain with progress-only reporting.
- `--archive`: scope flag — operate on the account's archive folder instead of INBOX
  (`folder:Gmail/.All_Mail` for `account=gmail`; `folder:Logos/.Archive` for `account=logos`),
  with extra-caution gates (second blast-radius confirmation, stricter delete bar,
  reversible-first deletes, pilot gate). Composable with default mode (50-step through the
  archive folder) and with `--all` (`/email --all --archive` = full archive-folder sweep).
- `--sync [channel]`: reconcile local mutations to the server; optional mbsync channel name
  (default: the resolved account's channel — `gmail` or `logos`; an explicit channel always
  overrides the account default).

**Accounts** (`--account <gmail|logos>` / `--logos` shorthand, default `gmail`):
- `account=gmail` (default, no flag needed): the existing, fully-functional path — unchanged by
  this selector.
- `account=logos` (`--account logos` or `--logos`): the Logos (Protonmail Bridge) account,
  folder-based (`folder:Logos`, `folder:Logos/.Archive`, `.Sent`, `.Drafts`, `.Trash` — there is
  no `.All_Mail`/`.Spam` for Logos). **Documented but gated**: parsing and query construction are
  implemented now, but `/email --logos` is routed through an actionable precondition gate (see
  Error Handling) that fails loudly until `.dotfiles` task 79's wrapper binaries land and accept
  `--account logos`. This is never a silent fallback to Gmail.
- Any other value (e.g. `--account work`) is an unknown account: an actionable rejection is
  surfaced (see Error Handling); it never silently falls back to `gmail`.

---

## Argument Parsing

<argument_parsing>
  <step_1>
    First, regardless of which route this turns out to be, scan `$ARGUMENTS` for the account
    selector and remove it from the argument string (this happens before the `--sync` route
    check in step 2, so the account applies uniformly to both the cleanup and sync paths):
    - `--account <gmail|logos>` present -> `account=<value>`.
    - `--logos` present (shorthand for `--account logos`) -> `account=logos`. `--account` and
      `--logos` are mutually redundant, not additive; if both appear and agree, treat as one
      selector; if they conflict (e.g. `--account gmail --logos`), report the conflict rather
      than silently picking one.
    - Neither present -> `account=gmail` (default; unchanged behavior — a bare `/email` parses
      to exactly `account=gmail` as before this change).
    - Any `--account` value other than `gmail`/`logos` (e.g. `--account work`) -> unknown-account
      error (see Error Handling below): report an actionable rejection naming the supported
      values; NEVER silently fall back to `gmail`.
    - If `account=logos` is resolved, apply the **actionable precondition gate** (see Error
      Handling) before proceeding to either the cleanup or sync path below: confirm the wrapper
      binaries accept `--account logos` (they currently reserve `--account gmail` only, per
      wrapper-contracts.md §2, pending `.dotfiles` task 79); if the wrapper rejects it (or the
      binaries are absent), stop and report the gate failure loudly — never silently continue as
      `gmail`.
  </step_1>
  <step_2>
    If the remaining `$ARGUMENTS` begins with the `--sync` flag, this is a SYNC invocation.
    Capture any token following `--sync` as the mbsync channel name (default: the account's
    channel from step 1 — `gmail` or `logos` — when omitted; an explicit channel token always
    overrides the account default). Route to the sync workflow below; do NOT run a cleanup pass.
    `--sync` is a distinct route: it never combines with `--all`/`--archive` in a single
    invocation (if both appear, `--sync` wins and the others are reported as ignored).
  </step_2>
  <step_3>
    Otherwise this is a CLEANUP invocation. Scan the remaining `$ARGUMENTS` for the two
    composable cleanup flags and remove them from the argument string:
    - `--all` present -> `mode=all` (whole-mailbox); absent -> `mode=default` (50-step).
    - `--archive` present -> `scope=archive` (the account's archive folder — `folder:Gmail/.All_Mail`
      for `account=gmail`, `folder:Logos/.Archive` for `account=logos`); absent -> `scope=inbox`
      (`folder:Gmail` for `account=gmail`, `folder:Logos` for `account=logos`).
    The flags compose freely: `/email --all --archive` is `mode=all, scope=archive`;
    `/email --logos --archive` is `account=logos, scope=archive`. Flag order is irrelevant.
  </step_3>
  <step_4>
    Parse the remaining `$ARGUMENTS` (after flag removal) as an optional free-text focus hint
    (e.g. "focus on newsletters", "sender github.com"). No hint is required; an empty remainder
    runs an unfocused pass over the selected scope. Route to the cleanup workflow below with
    (account, mode, scope, focus_hint).
  </step_4>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <cleanup_path>
    <action>Delegate to Email Cleanup Skill (any invocation without --sync)</action>
    <input>
      - skill: "skill-email-cleanup"
      - args: "account={gmail|logos}, mode={default|all}, scope={inbox|archive}, focus_hint={hint or empty}"
    </input>
    <expected_return>
      A census summary, a candidate set presented for review (per-message in default mode; ONE
      consolidated sender/domain bucket approval in --all mode), and (after explicit user
      approval) a report of which Message-IDs were actually archived/deleted/extracted. In --all
      mode the execute phase is a mechanical sub-50 drain with progress-only reporting — no
      per-batch re-prompt after the single bucket approval. Both `--all` and `--archive` route to
      this SAME skill (no fork); the mode/scope branches live inside skill-email-cleanup. The
      `account` arg is threaded through unchanged so every wrapper call, and both the folder
      scope and pilot-gate scoping, resolve against the SAME account for the whole invocation.
      For `account=logos`, this path is reached only after the step-1 precondition gate passes.
    </expected_return>
  </cleanup_path>
  <sync_path>
    <action>Delegate to Email Sync Skill (when --sync is present)</action>
    <input>
      - skill: "skill-email-sync"
      - args: "account={gmail|logos}, channel={channel or <account-default>}"
    </input>
    <expected_return>
      A precondition check, an explicit confirmation prompt, then an `mbsync <channel>` reconcile
      that propagates the completed cleanup's archives/deletes up to the account's server, with
      the sync result reported. Run this only after a cleanup is complete and reviewed - never
      interleaved with an active cleanup batch (freeze sync during bulk ops). The channel defaults
      from the resolved `account` (`gmail` -> `mbsync gmail`, `logos` -> `mbsync logos`); an
      explicit channel token in `$ARGUMENTS` always overrides the account default. For
      `account=logos`, this path is reached only after the step-1 precondition gate passes.
    </expected_return>
  </sync_path>
</workflow_execution>

---

## Safety Notes

`/email` (cleanup) NEVER mutates anything without an explicit, in-conversation user approval of a
reviewed candidate manifest. The skill is wrapper-only: it invokes `email-census`,
`email-classify`, `email-archive-confirmed`, `email-delete-confirmed`, and
`email-unsubscribe-extract` by name only, never raw `himalaya`/`notmuch`/`msmtp`/`secret-tool`.
This applies identically to both accounts — the account dimension only changes WHICH server/
folders these calls target, never the safety gates around them.

**Safety posture by invocation form**:

- `/email` (default) is the SAFER mode: each pass is bounded to at most 50 candidates, reviewed
  per-message, and can never trip the wrapper's batch cap. Prefer it unless the user explicitly
  asks for a whole-mailbox operation.
- `/email --all` classifies the entire scope but concentrates the human decision into ONE
  consolidated bucket approval; everything after that approval is a mechanical drain of ≤50-per-
  action sub-manifests. Only the read/tag-only classify sweep may run in the background; the
  bucket-approval AskUserQuestion and the whole execute drain run in the root session (direct
  execution) — never in a background subagent.
- `/email --archive` (with or without `--all`) targets the account's archive folder (All Mail for
  Gmail, ~64k messages; the real `Archive` folder for Logos, a much smaller ~54-message blast
  radius per the live probe): it adds a second, distinctly-worded blast-radius confirmation, a
  stricter delete-confidence bar, defaults to recoverable Trash (expunge is opt-in only), and is
  blocked at full scale until a bounded pilot pass has been acknowledged **for that account** (see
  skill-email-cleanup's per-account pilot gate — a Gmail pilot-ack never licenses a Logos
  archive-scope run, or vice versa).
- The wrapper's `MAX_BATCH_SIZE=50` per-action cap is FROZEN (cross-repo contract, .dotfiles
  task 72) and is the same for every account. No mode raises it — `--all` loops over ≤50 splits
  instead.
- Never auto-chain `/email --sync` after a cleanup — especially not after an `--archive` drain.
  The mutation wrappers already run their own group-scoped `mbsync <account-channel>` reconcile
  internally; `--sync` is a separate, human-confirmed operation.
- **Accounts are isolated by folder, never by tag**: all account scoping is expressed as
  `folder:` query tokens (`folder:Gmail*` vs `folder:Logos*`); a `tag:<account>` scheme exists in
  the notmuch database but is confirmed inert (always 0 matches) and must never be relied on.
- **`--logos` is documented-but-gated**: `/email --logos` (any mode/scope) is parsed and its
  queries are constructed, but is routed through an actionable precondition gate (see Error
  Handling) that fails loudly until `.dotfiles` task 79's wrapper binaries land and accept
  `--account logos`. It never silently falls back to operating on Gmail.

`/email --sync` performs no classification and mutates no local mail; it runs a single
`mbsync <channel>` reconcile that PUSHES the already-approved local archives/deletes up to the
account's server (Gmail by default; Logos when `account=logos`). Because it can make locally
expunged deletions permanent server-side, skill-email-sync also stops for an explicit confirmation
before running. `mbsync` is not a wrapper binary and is not denied by `mail-guard.sh` (it passes
through the hook). Never run `--sync` while a cleanup batch is mid-flight (freeze sync during bulk
ops). No path — for either account — ever resolves to a whole-mailbox `mbsync -a`; the channel is
always a single, explicit group.

---

## Error Handling

<error_handling>
  <execution_errors>
    - Wrapper binary missing from `$PATH` -> Report which binary and instruct
      `home-manager switch --flake .#<user>`
    - `mbsync` missing from `$PATH` (`--sync`) -> Report and instruct `home-manager switch`
    - Unknown mbsync channel/group (`--sync`) -> Read `~/.mbsyncrc` and ask which channel to use
    - Unknown `--account` value (e.g. `--account work`) -> Report an actionable rejection naming
      the supported values (`gmail`, `logos`); NEVER silently fall back to `gmail`
    - `account=logos` precondition gate fails (wrapper binaries do not yet accept
      `--account logos`, e.g. because `.dotfiles` task 79 has not landed/switched-in) -> Stop
      before any wrapper call and report: "`/email --logos` is documented but not yet usable —
      the wrapper binaries only accept `--account gmail` until `.dotfiles` task 79 lands and
      `home-manager switch` activates it." NEVER silently continue against Gmail instead.
    - Skill failure -> Return error details, no mutation performed
  </execution_errors>

  <interactive_errors>
    - User declines all proposed actions -> Exit gracefully, no files/messages mutated
    - User declines the sync confirmation -> Exit gracefully, no reconcile performed
  </interactive_errors>
</error_handling>
