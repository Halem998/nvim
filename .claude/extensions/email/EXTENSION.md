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
| skill-email-cleanup | (direct execution) | - | Ad-hoc `/email` triage: census, classify, review, confirm |

### Commands

| Command | Description |
|---------|-------------|
| `/email` | Run a census -> classify -> review -> confirmed archive/delete/unsubscribe-extract pass |

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

### Key Technologies

- **Himalaya**: CLI email client (maildir backend) driving read/move/delete operations.
- **notmuch**: local tagging/search index used for classification tags and Message-ID lookup.
- **mbsync**: IMAP sync engine reconciling local maildir with Gmail after mutation.
