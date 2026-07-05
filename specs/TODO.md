---
next_project_number: 826
---

# TODO

## Task Order

*Updated 2026-07-05. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 78,87,821,823 | -- | extensions, email integration, terminal ui |
| 2 | 822,824 | 821,823 | extensions |
| 3 | 825 | 824 | extensions |

**Grouped by Topic** (indented = depends on parent):

### Extensions

821 [RESEARCHED] — Route confirmed email-cleanup decisions (junk vs keep) from the e
  └─ 822 [NOT STARTED] — Implement the email->memory contribution per the #821 design. Add
823 [NOT STARTED] — /email --all promises whole-mailbox coverage but classification r
  └─ 824 [NOT STARTED] — When staleness is detected (task 823) the skill currently dead-en
    └─ 825 [NOT STARTED] — Synthesis/documentation task closing the loop opened by 823 (dete

### Terminal Ui

87 [RESEARCHED] — Investigate why the terminal working directory changes to a proje

### Email Integration

78 [PLANNED] — Fix Gmail SMTP authentication failure when sending emails via Him

## Tasks

### 825. Wire detect->remediate->re-run into the --all coverage contract and docs
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 823, Task 824

**Description**: Synthesis/documentation task closing the loop opened by 823 (detection) and 824 (remediation). Update commands/email.md (add the staleness->remediation flow to Workflow Execution and Error Handling), EXTENSION.md, README.md, and the archive-mode-risk.md / bulk-bucket-review.md context so the --all whole-mailbox coverage promise is EXPLICITLY conditioned on a fresh notmuch index, and the end-to-end flow (detect staleness -> recommend/run sanctioned reindex or --sync -> re-run --all) is documented consistently across command, skill, and context layers. Ensure no residual doc claims --all covers the whole mailbox unconditionally.

---

### 824. Provide a sanctioned notmuch reindex remediation path for /email
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 823

**Description**: When staleness is detected (task 823) the skill currently dead-ends: notmuch new is treated as forbidden raw notmuch, so there is no sanctioned remediation. But notmuch new is index-only and non-mutating — exactly analogous to mbsync, which IS sanctioned via skill-email-sync (not a wrapper binary, passes mail-guard.sh, human-confirmed). Research how notmuch reindexing is actually wired for these maildirs (post-mbsync notmuch new hook? systemd path/timer? manual). Then add a sanctioned remediation mirroring the mbsync precedent: fold a reindex step into skill-email-sync or a documented /email --sync behavior, or document the exact sanctioned command, so the skill can remediate rather than dead-end. Reconcile wrapper-contracts.md §8 (two-layer enforcement) and mail-guard.sh reasoning to distinguish index-only notmuch new (sanctioned, like mbsync) from forbidden raw notmuch/himalaya MUTATION and tag commands; ensure skill MUST-NOT text stays consistent. May surface a .dotfiles handoff recommendation if reindex belongs in the frozen wrapper layer.

---

### 823. Add notmuch-staleness detection gate to skill-email-cleanup
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: /email --all promises whole-mailbox coverage but classification reads notmuch (email-classify) while mailbox ground truth is maildir/himalaya (email-census); a stale notmuch index silently degrades --all to partial coverage (observed: census=62 vs notmuch folder:Logos=12 for the Logos INBOX). Add a wrapper-only staleness precondition to skill-email-cleanup that, before an --all sweep (and surfaced in default mode), compares the maildir ground-truth count from email-census against the notmuch indexed count for the same account/folder via the email-classify --limit 0 count-oracle (wrapper-contracts.md §10); on divergence beyond a small threshold, WARN or BLOCK with an actionable message rather than presenting partial coverage as whole-mailbox. Research must verify which source email-census actually counts from (maildir vs notmuch) so the comparison is meaningful. Add domain/staleness-detection.md documenting the check, count sources, and threshold. Wrapper-only compliant (both are wrapper calls); no .dotfiles change.

---

### 822. Implement email cleanup to memory vault contribution
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 821

**Description**: Implement the email->memory contribution per the #821 design. Add a harvest step to skill-email-cleanup (or a memory lifecycle hook) that, when junk/keep decisions are confirmed, creates or UPDATEs a sender/domain-aggregated preference memory in the vault (CREATE/UPDATE/EXTEND with dedup against memory-index.json). Include an opt-in/gate consistent with skill-todo's harvest pattern, tests, and documentation updates to both extensions' READMEs/manifests.

---

### 821. Research and design email-to-memory contribution architecture
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [821_email_to_memory_contribution_architecture/reports/01_team-research.md]

**Description**: Route confirmed email-cleanup decisions (junk vs keep) from the email extension into the memory vault so the system learns sender/domain preferences over time. RESEARCH PHASE FIRST: survey July-2026 best practices for email-triage to preference/memory-learning systems (sender reputation, preference capture, vault-bloat avoidance, aggregation strategies, dedup, feedback loops), plus the concrete integration surfaces already identified: capture point = skill-email-cleanup human review gate (Stage 3 per-message / Stage 2.5 bucket approval in --all mode) where the JSONL candidate manifest (Message-ID keyed, proposed_action delete|archive|keep|unsure + confidence) is confirmed; memory API = skill-memory CREATE/UPDATE/EXTEND with content-mapping + MCP dedup against .memory/memory-index.json; reusable pattern = skill-todo's harvest->dedup->user-gated-create flow (Stage ~181+); hook surface = memory extension manifest.json empty hooks object as an alternative capture path. DESIGN DECISION ALREADY MADE BY USER: memories are SENDER/DOMAIN-AGGREGATED (one evolving preference memory per sender or domain, UPDATE/EXTEND as more mail is seen -- NOT per-message), chosen to avoid vault bloat; the research should refine the aggregation/dedup/schema mechanics within that decision, not relitigate it. Output: chosen capture point, memory schema/tags, dedup + update strategy, and opt-in/gate behavior.

---

### 820. Email all resurface classified gap
- **Effort**: 2 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [820_email_all_resurface_classified_gap/reports/01_wrapper-gap-seed.md]
- **Plan**: [820_email_all_resurface_classified_gap/plans/02_email-all-emit-tagged.md]
- **Summary**: [~/.dotfiles/modules/home/email/agent-tools/classify.nix]

**Description**: /email --all cannot re-surface an already-fully-classified mailbox for review: email-classify is emit-on-change, email-census takes no query, and mutation wrappers plan over an approved manifest not proposed-* tags, so there is no wrapper-only read-out of tagged messages. Fix spans the email extension skill (--all Stage 2) and the .dotfiles wrapper binaries (a read-only --emit-tagged / candidate rebuild). See reports/01_wrapper-gap-seed.md.

---

### 819. Load email extension in extensions json
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [819_load_email_extension_in_extensions_json/reports/01_intent-and-mechanics.md]
- **Plan**: [819_load_email_extension_in_extensions_json/plans/01_document-no-op-decision.md]

**Description**: Add the email extension to .claude/extensions.json so it is actually loaded and its EXTENSION.md content propagates into .claude/CLAUDE.md (pre-existing gap flagged in review-2026-07-04: check-extension-docs.sh warns 'routing target not deployed: skill-email-implementation', and EXTENSION.md->CLAUDE.md merge is unobservable because 'email' is absent from extensions.json). Only do this if the email extension is intended to be loaded in this repo. Verify: extension loads without routing warnings, EXTENSION.md [email] section propagates to CLAUDE.md via the merge mechanism.

---

### 818. Email extension doc consistency sweep
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [{]
- **Plan**: [818_email_extension_doc_consistency_sweep/plans/01_email-doc-consistency-sweep.md]

**Description**: Email/ extension documentation consistency sweep (findings 3,4,5,6 from review-2026-07-04). (3 MED) Finish account-generalizing archive-mode-risk.md: title still says 'All Mail Scope' (line 1), Blast-Radius table hardcodes ~64,000 msgs with no Logos row (12-17), Gate #1 hardcodes 'All Mail' (61), Gate #3 hardcodes 'mbsync gmail' (68) — make them match the account-generic tables in skill-email-cleanup/SKILL.md. (4 MED) Hardcode ONE pilot-ack file convention in skill-email-cleanup/SKILL.md (428-442) — single 'account'-keyed file with the gate always checking that path — instead of leaving it to per-invocation agent judgment. (5 MED) Refresh README.md (16-17,106-125): still describes /email as Gmail-only with no --account/--logos. (6 MED) Add a --sync channel/account mismatch warning in Stage 3 confirm (commands/email.md ~32-34, skill-email-sync/SKILL.md ~64-66). Ref: specs/reviews/review-2026-07-04.md.

---

### 817. Reconcile email stale multiaccount gating
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Plan**: [817_reconcile_email_stale_multiaccount_gating/plans/01_reconcile-multiaccount-gating.md]

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
