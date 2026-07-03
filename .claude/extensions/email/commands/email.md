---
description: Run a wrapper-only email triage pass - census, classify, review, confirmed archive/delete/unsubscribe-extract
---

# Command: /email

**Purpose**: Ad-hoc email cleanup pass over Himalaya/notmuch via the five nix-built wrapper
binaries, with a mandatory human review/approval gate before any mutation.
**Layer**: 2 (Command File - Argument Parsing)
**Delegates To**: skill-email-cleanup (direct execution)

**Input**: $ARGUMENTS (optional filter hint, e.g. a sender/domain/folder to focus on)

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse `$ARGUMENTS` as an optional free-text focus hint (e.g. "focus on newsletters",
    "folder INBOX", "sender github.com"). No hint is required; an empty `$ARGUMENTS` runs a
    full inbox triage pass.
  </step_1>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Delegate to Email Cleanup Skill</action>
    <input>
      - skill: "skill-email-cleanup"
      - args: "focus_hint={hint or empty}"
    </input>
    <expected_return>
      A census summary, a candidate manifest presented for review, and (after explicit user
      approval) a report of which Message-IDs were actually archived/deleted/extracted.
    </expected_return>
  </step_1>
</workflow_execution>

---

## Safety Notes

`/email` NEVER mutates anything without an explicit, in-conversation user approval of a
reviewed candidate manifest. The skill is wrapper-only: it invokes `email-census`,
`email-classify`, `email-archive-confirmed`, `email-delete-confirmed`, and
`email-unsubscribe-extract` by name only, never raw `himalaya`/`notmuch`/`msmtp`/`secret-tool`.

---

## Error Handling

<error_handling>
  <execution_errors>
    - Wrapper binary missing from `$PATH` -> Report which binary and instruct
      `home-manager switch --flake .#<user>`
    - Skill failure -> Return error details, no mutation performed
  </execution_errors>

  <interactive_errors>
    - User declines all proposed actions -> Exit gracefully, no files/messages mutated
  </interactive_errors>
</error_handling>
