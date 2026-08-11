## Email Extension

This project includes AI-assisted email triage over Himalaya/notmuch via the email extension.
All mutation goes through five nix-built wrapper binaries; the extension itself never calls
`himalaya`/`notmuch`/`msmtp` directly. Operating rules are non-negotiable — see
`domain/safety-invariants.md` before any `email` work.

### Task-Type Routing

| Task Type | Research | Plan | Implement | Agent |
|-----------|----------|------|-----------|-------|
| `email` | skill-researcher | skill-planner | skill-email-implementation | email-implementation-agent (sonnet) |

Direct-execution skills (no agent dispatch):

| Skill | Purpose |
|-------|---------|
| skill-email-cleanup | `/email` triage: default 50-step mode, `--all` whole-mailbox mode, `--archive` scope |
| skill-email-sync | `/email --sync` human-confirmed `mbsync` reconcile to the account's server |

### Commands

| Command | Description |
|---------|-------------|
| `/email` | Default safer mode: bounded 50-step census -> classify -> review -> confirmed archive/delete pass; repeated runs step forward via the durable `+proposed-*` tag cursor |
| `/email --all` | Whole-mailbox mode: chunked backgrounded classify sweep, ONE consolidated sender/domain bucket approval, transparent ≤50-per-action execute drain |
| `/email --archive` | Scope flag (composable): operate on the account's archive folder with extra-caution gates and a per-account pilot gate before full scale |
| `/email --sync [channel]` | Human-confirmed `mbsync` reconcile pushing a completed cleanup to the account's server; channel defaults from the account, never auto-chained |
| `/email --account <gmail\|logos>` / `/email --logos` | Account selector (default `gmail`). Composable with any of the above. Both accounts are live; an unknown value is rejected loudly, never a silent fallback |

### Context Pointers

- `.claude/context/project/email/domain/safety-invariants.md`
- `.claude/context/project/email/domain/wrapper-contracts.md`
- `.claude/context/project/email/domain/index-architecture.md`
- `.claude/context/project/email/domain/staleness-detection.md`
- `.claude/context/project/email/domain/archive-mode-risk.md`
