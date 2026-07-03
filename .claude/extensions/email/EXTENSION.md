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
| skill-email-cleanup | (direct execution) | - | `/email` triage: default 50-step mode, `--all` whole-mailbox mode, `--archive` All Mail scope |
| skill-email-sync | (direct execution) | - | `/email --sync` human-confirmed `mbsync` reconcile to Gmail |

### Commands

| Command | Description |
|---------|-------------|
| `/email` | Default safer mode: bounded 50-step census -> classify -> review -> confirmed archive/delete pass; repeated runs step forward via the durable `+proposed-*` tag cursor |
| `/email --all` | Whole-mailbox mode: chunked backgrounded classify sweep, ONE consolidated sender/domain bucket approval, transparent ≤50-per-action execute drain |
| `/email --archive` | Scope flag (composable with default or `--all`): operate on All Mail (`folder:Gmail/.All_Mail`) with extra-caution gates and a pilot gate before full scale |
| `/email --sync [channel]` | Human-confirmed `mbsync` reconcile pushing a completed cleanup to Gmail (never auto-chained) |

### Safety Invariants

- **Wrapper-only**: agents may invoke ONLY `email-census`, `email-classify`,
  `email-archive-confirmed`, `email-delete-confirmed`, `email-unsubscribe-extract` by name.
  Raw `himalaya`/`notmuch`/`msmtp`/`secret-tool` calls are prohibited.
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
  (`--expunge-trash` opt-in only), a bounded pilot gate before full scale, and never
  auto-chaining `/email --sync` after a drain.

### Key Technologies

- **Himalaya**: CLI email client (maildir backend) driving read/move/delete operations.
- **notmuch**: local tagging/search index used for classification tags and Message-ID lookup.
- **mbsync**: IMAP sync engine reconciling local maildir with Gmail after mutation.
