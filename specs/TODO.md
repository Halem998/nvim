---
next_project_number: 820
---

# TODO

## Task Order

*Updated 2026-07-05. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 78,87,817,818,819 | -- | extensions, email integration, terminal ui |

**Grouped by Topic** (indented = depends on parent):

### Extensions

817 [NOT STARTED] — Reconcile the email/ extension's stale multi-account gating langu
818 [NOT STARTED] — Email/ extension documentation consistency sweep (findings 3,4,5,
819 [NOT STARTED] — Add the email extension to .claude/extensions.json so it is actua

### Terminal Ui

87 [RESEARCHED] — Investigate why the terminal working directory changes to a proje

### Email Integration

78 [PLANNED] — Fix Gmail SMTP authentication failure when sending emails via Him

## Tasks

### 819. Load email extension in extensions json
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Add the email extension to .claude/extensions.json so it is actually loaded and its EXTENSION.md content propagates into .claude/CLAUDE.md (pre-existing gap flagged in review-2026-07-04: check-extension-docs.sh warns 'routing target not deployed: skill-email-implementation', and EXTENSION.md->CLAUDE.md merge is unobservable because 'email' is absent from extensions.json). Only do this if the email extension is intended to be loaded in this repo. Verify: extension loads without routing warnings, EXTENSION.md [email] section propagates to CLAUDE.md via the merge mechanism.

---

### 818. Email extension doc consistency sweep
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Email/ extension documentation consistency sweep (findings 3,4,5,6 from review-2026-07-04). (3 MED) Finish account-generalizing archive-mode-risk.md: title still says 'All Mail Scope' (line 1), Blast-Radius table hardcodes ~64,000 msgs with no Logos row (12-17), Gate #1 hardcodes 'All Mail' (61), Gate #3 hardcodes 'mbsync gmail' (68) — make them match the account-generic tables in skill-email-cleanup/SKILL.md. (4 MED) Hardcode ONE pilot-ack file convention in skill-email-cleanup/SKILL.md (428-442) — single 'account'-keyed file with the gate always checking that path — instead of leaving it to per-invocation agent judgment. (5 MED) Refresh README.md (16-17,106-125): still describes /email as Gmail-only with no --account/--logos. (6 MED) Add a --sync channel/account mismatch warning in Stage 3 confirm (commands/email.md ~32-34, skill-email-sync/SKILL.md ~64-66). Ref: specs/reviews/review-2026-07-04.md.

---

### 817. Reconcile email stale multiaccount gating
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Reconcile the email/ extension's stale multi-account gating language with the now-verified wrapper contract. Ground truth: .dotfiles task 79 landed + switched in and was live-verified by .dotfiles task 80 (9/9 contract rows PASS), so wrapper-contracts.md is authoritative. Findings 1,2,7 from review-2026-07-04: (1 CRITICAL) strip the obsolete 'wrapper reserves --account gmail / hard error / pending task 79' gating language from commands/email.md (~41-44,67-72,204-208), EXTENSION.md (~29,72-77), skill-email-cleanup/SKILL.md (~45-60), skill-email-sync/SKILL.md (~58-61); (2 HIGH) convert the skill-email-cleanup precondition gate from a 'wrapper is gmail-only, STOP' gate into a light liveness check, and fix the probe: 'email-census --account logos --help' short-circuits before flag validation — use a real read-only probe like 'email-census --account logos' and check exit/stderr; (7 LOW) align gate naming ('step-1' vs 'Phase-1'). Ref: specs/reviews/review-2026-07-04.md. Verify: agent reading /email --logos gets one consistent, non-contradictory story; check-extension-docs.sh [email] still PASS.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Task Type**: neovim
- **Topic**: Terminal UI
- **Dependencies**: None
- **Research**: [087_investigate_wezterm_terminal_directory_change/reports/research-001.md]

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Task Type**: neovim
- **Topic**: Email Integration
- **Dependencies**: None
- **Research**: [078_fix_himalaya_smtp_authentication_failure/reports/research-001.md]
- **Plan**: [078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md]

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted. The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.
