## Email Extension

This project includes AI-assisted email triage over Himalaya/notmuch via the email extension.
All mutation goes through five nix-built wrapper binaries; the extension itself never calls
`himalaya`/`notmuch`/`msmtp` directly.

### Task-Type Routing

| Task Type | Research | Plan | Implement |
|-----------|----------|------|-----------|
| `email` | skill-researcher | skill-planner | skill-email-implementation |

### Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-email-implementation | email-implementation-agent | sonnet | Wrapper-only classify/archive/delete execution via `/implement` |
| skill-email-cleanup | (direct execution) | - | `/email` triage: default 50-step mode, `--all` whole-mailbox mode, `--archive` scope to the account's archive folder |
| skill-email-sync | (direct execution) | - | `/email --sync` human-confirmed `mbsync` reconcile to the account's server |

### Commands

| Command | Description |
|---------|-------------|
| `/email` | Default safer mode: bounded 50-step census -> classify -> review -> confirmed archive/delete pass against `account=gmail`; repeated runs step forward via the durable `+proposed-*` tag cursor |
| `/email --all` | Whole-mailbox mode: chunked backgrounded classify sweep, ONE consolidated sender/domain bucket approval, transparent ≤50-per-action execute drain |
| `/email --archive` | Scope flag (composable with default or `--all`): operate on the account's archive folder (`folder:Gmail/.All_Mail` for gmail; `folder:Logos/.Archive` for logos) with extra-caution gates and a per-account pilot gate before full scale |
| `/email --sync [channel]` | Human-confirmed `mbsync` reconcile pushing a completed cleanup to the account's server; channel defaults from the account (`gmail`/`logos`), never auto-chained |
| `/email --account <gmail\|logos>` / `/email --logos` | Account selector (default `gmail`, unchanged behavior). Composable with any of the above (e.g. `/email --logos --archive`). Both `account=gmail` and `account=logos` (Protonmail Bridge) are live, accepted values per wrapper-contracts.md §2, gated only by a light step-1 liveness check before any wrapper call. Never a silent fallback to Gmail; an unknown `--account` value is rejected loudly. |

### Safety Invariants

- **Wrapper-only**: agents may invoke ONLY `email-census`, `email-classify`,
  `email-archive-confirmed`, `email-delete-confirmed`, `email-unsubscribe-extract` by name.
  Raw `himalaya`/`notmuch`/`msmtp`/`secret-tool` calls are prohibited. Sanctioned NON-wrapper
  exceptions (index/sync only, never mail mutation): the group-scoped `mbsync` reconcile
  (`/email --sync`) and the `email-reindex` operator helper (index-only `notmuch new --no-hooks`).
- **Index-freshness gate**: because classification reads notmuch and there is no auto-indexer,
  `--all` runs a staleness gate before claiming whole-mailbox coverage — comparing the
  `email-census` freshness line's on-disk file count against a path-prefix post-filtered
  indexed-files count (a file-vs-file comparison within a bounded tolerance, not strict equality)
  and reconciling with `email-reindex` when the divergence exceeds tolerance (tasks 823-824-827;
  see `domain/staleness-detection.md`, `wrapper-contracts.md` §13).
- **Two-layer enforcement**: the `mail-guard.sh` PreToolUse hook (social/technical layer 1,
  per-machine, may be gitignored) plus the nix-built wrapper source itself (layer 2, always
  present). Neither layer is sufficient alone.
- **Propose-review-confirm-execute**: mutation binaries are dry-run by default; `--execute`
  requires `--confirm-manifest <sha256>` over a human-reviewed, git-tracked manifest.
- **Delete is IMAP/maildir-level Himalaya only**, never a raw filesystem `rm` against Maildir.
- **`$PATH` precondition**: agents must verify wrapper binaries are on `$PATH` (nix/home-manager
  built) before invoking any of them, and fail actionably if not.
- **Default-mode cursor**: bare `/email` is bounded to 50 candidates per pass; the durable
  `+proposed-*` tags (expressed only as an `email-classify` QUERY exclusion) make successive
  runs advance instead of re-classifying the same newest 50.
- **Sub-50 transparent drain** (`--all`): the approved set is split caller-side into
  ≤50-lines-per-action sub-manifests (`MAX_BATCH_SIZE=50` is FROZEN — never raised); the drain
  is mechanical and progress-only after the single bucket approval, with idempotency via the
  wrapper's per-split `<manifest>.state.jsonl` only. Only the read/tag-only classify sweep may
  run in the background; every review gate and every execute call runs in the root session.
- **Mtime-preserve / expiry-stop**: split sub-manifests carry the ORIGINAL approval mtime
  (`touch -r`); an expired split (>`PLAN_EXPIRY_DAYS=7`) STOPS the drain with a residual
  report — never a silent re-timestamp.
- **Archive extra gates** (`--archive`): second blast-radius-naming confirmation, corroborated
  (rule-tier) confidence bar for bulk deletes, reversible-then-hard two-phase deletes
  (`--expunge-trash` opt-in only), a bounded per-account pilot gate before full scale (a Gmail
  pilot-ack never licenses a Logos archive-scope run, or vice versa), and never auto-chaining
  `/email --sync` after a drain.
- **Account isolation, folder-scoped only**: multi-account support (`--account <gmail|logos>` /
  `--logos`, default `gmail`) is resolved once per invocation and threaded unchanged through every
  wrapper call. Account scoping is expressed EXCLUSIVELY as `folder:` query tokens
  (`folder:Gmail*` vs `folder:Logos*`) — a `tag:<account>` scheme exists in the notmuch database
  but is confirmed inert (always 0 matches) and must never be relied on. No path for either
  account ever resolves to a whole-mailbox `mbsync -a`; the channel is always a single, explicit
  group (`gmail` or `logos`).
- **Per-account `--archive` semantics**: Gmail's archive-of-record is the `All Mail` label-folder
  (`folder:Gmail/.All_Mail`, ~64k messages); Proton/Logos has no label-based "All Mail" model —
  its archive-of-record is the real `Archive` folder (`folder:Logos/.Archive`, ~54 messages per
  the live probe, a much smaller blast radius). The same proportionate extra-caution gates apply
  to both, regardless of scale.
- **`/email --logos` is additive, live, and never a silent fallback**: the account selector,
  folder-token queries, and pilot-gate scoping for `account=logos` are implemented, documented,
  and accepted by the wrapper binaries (`--account <gmail|logos>`, wrapper-contracts.md §2,
  verified 9/9 by `.dotfiles` task 80); every `--logos` invocation is routed through a light
  step-1 liveness check before any wrapper call. A bare `/email` (Gmail, the default) is
  unaffected and remains byte-for-byte unchanged.
- **`hooks/mail-guard.sh` needed no change** for multi-account support: it allowlists the five
  wrapper binaries by NAME only (not by account/flag), and multi-account support was added as an
  `--account` flag on those same five binaries rather than as new binary names — so the guard's
  allowlist is unaffected by the account dimension.

### Key Technologies

- **Himalaya**: CLI email client (maildir backend) driving read/move/delete operations.
- **notmuch**: local tagging/search index used for classification tags and Message-ID lookup,
  across both the Gmail and Logos accounts (folder-scoped, never tag-scoped).
- **mbsync**: IMAP sync engine reconciling local maildir with the account's server (Gmail or
  Logos/Protonmail Bridge) after mutation.
