# Email Extension

Extension for AI-assisted email triage and cleanup over Himalaya/notmuch, using nix-built
"agent tools" wrapper binaries as the sole mutation surface. This extension authors and ships
the `.claude/extensions/email/` directory; loading it into a consuming repo (via the extension
picker) is a separate, later step and is out of scope for the task that authored this README.

## Loading the Extension

```
Extension picker -> select "email"
```

## Purpose

This extension gives an agent a safe, auditable way to triage a Gmail inbox: read a census of
senders/folders, classify messages into propose-archive/propose-delete/keep/unsure buckets,
surface unsubscribe candidates, and — only after a human reviews and confirms a manifest —
execute the approved archive/delete/unsubscribe-extract actions. The agent never talks to
`himalaya`, `notmuch`, or `msmtp` directly; it only invokes five named wrapper binaries.

## File Inventory

| Path | Purpose |
|------|---------|
| `manifest.json` | Extension manifest: routing, provides, merge_targets |
| `EXTENSION.md` | Slim CLAUDE.md fragment merged into the consuming repo |
| `README.md` | This file |
| `index-entries.json` | Context index entries for `context/project/email/` |
| `settings-fragment.json` | PreToolUse hook registration + permissions.deny entries |
| `agents/email-implementation-agent.md` | Wrapper-only executor for `/implement` |
| `skills/skill-email-implementation/SKILL.md` | `/implement` target skill (dispatches to the agent) |
| `skills/skill-email-cleanup/SKILL.md` | Direct-execution `/email` cleanup skill (default 50-step mode, `--all` mode, `--archive` scope) |
| `skills/skill-email-sync/SKILL.md` | Direct-execution `/email --sync` server-reconcile skill |
| `commands/email.md` | The `/email` slash command (default/`--all`/`--archive` cleanup, or `--sync`) |
| `hooks/mail-guard.sh` | Allowlist/deny PreToolUse hook (technical enforcement layer) |
| `context/project/email/` | Harvested preferences plus wrapper-contract, pattern, and standard docs |
| `context/project/email/domain/wrapper-contracts.md` | Ground-truth-verified wrapper contract (incl. classify pagination contract and folder tokens) |
| `context/project/email/domain/archive-mode-risk.md` | All Mail blast radius, reversible-vs-hard boundary, asymmetric confidence policy |
| `context/project/email/patterns/bulk-bucket-review.md` | Sender/domain bucket bulk-approval pattern (`--all` mode review gate) |

A fourth new doc lives at the agent-system layer (domain-agnostic):
`.claude/context/patterns/batch-drain-loop.md` — one approval draining many capped batches,
plus chunked-sweep pagination for `--limit`-only readers.

## The Five Wrapper Binaries

These are nix-built (`~/.dotfiles` `modules/home/email/agent-tools.nix`) and referenced by name
only — this extension does not bundle or reimplement them:

| Binary | Safety class | Mutates? |
|--------|--------------|----------|
| `email-census` | read-only | no |
| `email-classify` | local-tags-only (notmuch tags, never maildir/IMAP) | no (tags only) |
| `email-unsubscribe-extract` | read-only | no |
| `email-archive-confirmed` | mutation | yes (maildir move) |
| `email-delete-confirmed` | mutation | yes (maildir move + optional `--expunge-trash`) |

All five are dry-run by default. Mutation requires `--execute --confirm-manifest <sha256>` over
the raw bytes of a human-reviewed, git-tracked manifest.

## Workflow: Propose -> Review -> Confirm -> Execute

1. **Propose**: `email-census` and `email-classify` run read-only/tag-only, producing a
   candidate manifest with a `proposed_action` and `confidence` per Message-ID.
2. **Review**: a human reviews the candidate manifest (e.g. via an aerc tagged view).
3. **Confirm**: approving a message appends its Message-ID to an approved, git-tracked manifest;
   the sha256 of that manifest's raw bytes is computed.
4. **Execute**: `email-archive-confirmed` / `email-delete-confirmed` are invoked with
   `--execute --confirm-manifest <sha256>`; the wrapper recomputes the hash and refuses on
   mismatch. Executed IDs are diffed against the manifest — never re-derived.

## Two-Layer Enforcement

1. **`mail-guard.sh` PreToolUse hook** (registered via `settings-fragment.json` into
   `.claude/settings.local.json`, which may be gitignored per-machine): allowlists only the five
   wrapper binaries and denies raw `himalaya message delete|move|send`, `himalaya folder
   expunge`, `msmtp`, `secret-tool`, and `rm *Mail*` at the agent's own Bash-tool boundary.
2. **The nix-built wrapper source itself**: hash verification, staleness (`PLAN_EXPIRY_DAYS`),
   batch cap (`MAX_BATCH_SIZE`), and execution-state tracking are baked into the binaries, so
   safety holds even for a human invoking a wrapper directly outside an agent session.

Neither layer is sufficient alone — this is why both exist.

## Using `/email`

Run `/email` to trigger a triage pass via `skill-email-cleanup`: census, classify, present the
candidates for review, then (on confirmation) execute the approved
archive/delete/unsubscribe-extract actions. `/email` is direct-execution — no `subagent_type`
dispatch — while the `/implement` path for `email`-typed tasks routes through
`skill-email-implementation` and `email-implementation-agent` instead.

### Two modes and a scope flag

- **`/email` (default — the safer mode)**: a bounded 50-at-a-time stepping pass. Each run
  classifies at most 50 messages and reviews them per-message; the durable `+proposed-*`
  notmuch tags act as a cross-invocation cursor, so repeated bare `/email` runs step forward
  through the mailbox instead of re-showing the same newest 50.
- **`/email --all` (whole-mailbox mode)**: classifies EVERYTHING in scope via an
  unconditionally-chunked, backgrounded, read/tag-only classify sweep; presents ONE
  consolidated sender/domain bucket approval; then drains the approved set as ≤50-per-action
  sub-manifests, mechanically and with progress-only reporting (no per-batch re-prompt). The
  wrapper's `MAX_BATCH_SIZE=50` is never raised — the drain loops over splits, each carrying
  the ORIGINAL approval mtime (`touch -r`) so the 7-day expiry window is never silently
  extended; an expired split stops the drain with a report.
- **`/email --archive` (scope flag, composable with either mode)**: operates on All Mail
  (`folder:Gmail/.All_Mail`, ~64k messages) instead of INBOX, with extra-caution gates: a
  second blast-radius-naming confirmation, a stricter corroborated delete bar, deletes always
  stopping at recoverable Trash (`--expunge-trash` strictly opt-in), and — because this
  extension has never been live-validated — a **pilot gate**: full-scale `--archive` is
  refused until a bounded pilot pass (low-thousands slice) has been run, verified, and
  explicitly acknowledged. See `context/project/email/domain/archive-mode-risk.md`.

### `/email --sync [channel]` — reconcile the cleanup to Gmail

The cleanup wrappers mutate the **local** maildir only; nothing reaches Gmail-in-the-browser until
a separate `mbsync` reconcile runs. This is deliberate — the "freeze sync during bulk ops" rule
keeps `mbsync` from interleaving with an in-progress mutation batch.

Once a cleanup is complete and looks right, run `/email --sync` (routes to `skill-email-sync`) to
run `mbsync <channel>` (default channel `gmail`, overridable: `/email --sync work`). This pushes
the local archives/deletes up to Gmail, so the browser inbox reflects the cleanup:

- Archived messages -> Gmail **All Mail** (still searchable/recoverable).
- Deleted messages -> Gmail **Trash** (recoverable ~30 days).
- Messages locally `--expunge-trash`'d -> **permanently removed** server-side after this sync.

Because the last case is irreversible, `skill-email-sync` stops for an explicit confirmation
before running. `mbsync` is not a wrapper binary and is not denied by `mail-guard.sh` — it passes
through the hook and is subject to normal Bash permissioning.

## Scope Note

This extension is authored and doc-lint-verified only; it has not been loaded into this or any
consuming repo. Loading (via the extension picker) is a deliberate, separate step performed
later by a user.
