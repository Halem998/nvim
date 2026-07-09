---
next_project_number: 831
---

# TODO

## Task Order

*Updated 2026-07-09. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 78,87,821,826 | -- | extensions, email integration, terminal ui |
| 2 | 822,827 | 821,826 | extensions |

**Grouped by Topic** (indented = depends on parent):

### Extensions

821 [RESEARCHED] — Route confirmed email-cleanup decisions (junk vs keep) from the e
  └─ 822 [NOT STARTED] — Implement the email->memory contribution per the #821 design. Add
826 [BLOCKED] — Root-cause and fix the pre-existing Logos (Protonmail Bridge) mai
  └─ 827 [BLOCKED] — The freshness gate shipped in tasks 823-825 is defective: email-c

### Terminal Ui

87 [RESEARCHED] — Investigate why the terminal working directory changes to a proje

### Email Integration

78 [PLANNED] — Fix Gmail SMTP authentication failure when sending emails via Him

## Tasks

### 830. Aerc terminal ctrl hjkl esc passthrough
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: Terminal UI
- **Dependencies**: None
- **Research**: [830_aerc_terminal_ctrl_hjkl_esc_passthrough/reports/01_aerc-terminal-passthrough-research.md]
- **Plan**: [830_aerc_terminal_ctrl_hjkl_esc_passthrough/plans/01_aerc-terminal-passthrough.md]
- **Summary**: [830_aerc_terminal_ctrl_hjkl_esc_passthrough/summaries/01_aerc-terminal-passthrough-summary.md]

**Description**: Special-case the aerc terminal in Neovim's terminal-mode keymap setup so <C-h/j/k/l> and <Esc> reach aerc instead of being intercepted by Neovim. This is the cross-repo companion to .dotfiles task 105 Recommendation B (aerc<->nvim/himalaya keymap alignment); it is a hard PREREQUISITE for the aerc-side <C-hjkl> folder binds in that task.

BACKGROUND: aerc is launched via <leader>me into a floating toggleterm (lua/neotex/plugins/tools/mail.lua, cmd="aerc"). Every terminal matches the term://* TermOpen autocmd (lua/neotex/config/autocmds.lua:25) which calls set_terminal_keymaps() (lua/neotex/config/keymaps.lua:116). aerc is neither the is_claude nor is_opencode special case, so it falls through to the generic else branch (keymaps.lua:147-150) that maps terminal-mode <C-h/j/k/l> -> wincmd h/j/k/l, and the <Esc> -> <C-\><C-n> exit-terminal map (keymaps.lua:133). Result: aerc NEVER receives <C-hjkl> (they navigate Neovim windows) or <Esc> (it drops to Neovim normal mode instead of cancelling aerc's :prompt / :search / selection).

CHANGE: add an is_aerc detection alongside is_claude/is_opencode (match the terminal bufname/cmd for 'aerc'), and for aerc terminals (1) SKIP the <C-h/j/k/l>->wincmd remaps so they pass through to aerc, and (2) SKIP the <Esc>->exit-terminal remap (extend the existing `if not is_claude` guard to also exempt aerc) so aerc prompts cancel with Esc. This is safe because the aerc window is a fullscreen float with no sibling Neovim windows, so wincmd h/j/k/l do nothing useful there anyway. The change MUST be strictly gated on is_aerc: claude, opencode, and generic terminals keep their current <C-hjkl>/<Esc> behavior unchanged.

AFTER THIS LANDS: the .dotfiles task 105 side binds aerc's <C-h>/<C-l> = :prev-folder/:next-folder (or <C-j>/<C-k> = message nav) in modules/home/email/aerc.nix. That aerc-side edit is out of scope here.

FILES: lua/neotex/config/keymaps.lua (set_terminal_keymaps, ~L116-158). Reference only: lua/neotex/config/autocmds.lua:25 (the term://* trigger), lua/neotex/plugins/tools/mail.lua (the <leader>me launcher).

VERIFICATION: open aerc via <leader>me; confirm (once the aerc.nix binds exist) <C-hjkl> reach aerc and <Esc> cancels an aerc :prompt from inside the float; confirm a Claude Code terminal and a general :terminal STILL have working <C-hjkl> window-nav and <Esc> exit (no regression from the is_aerc gate).

CROSS-REPO: research + rationale in ~/.dotfiles/specs/105_aerc_keybindings_nvim_himalaya_alignment/reports/01_aerc-keymap-alignment.md (esp. §4 reachability table and §6.2 Recommendation B). Companion .dotfiles task 105.

---

### 829. Add leader vl piper tts read buffer
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: neovim
- **Dependencies**: None
- **Research**: [829_add_leader_vl_piper_tts_read_buffer/reports/01_piper-tts-toggle-research.md]
- **Plan**: [829_add_leader_vl_piper_tts_read_buffer/plans/01_piper-tts-toggle.md]

**Description**: Add <leader>vl toggle mapping that uses piper TTS to read the current buffer aloud from the cursor position to end of buffer, stopping playback when toggled off

---

### 828. Resolve Logos Trash/Archive UID collisions via live IMAP verification
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [826_logos_maildir_duplication_mbsync_repair/reports/02_spawn-analysis.md]
- **Plan**: [828_logos_trash_archive_uid_collision_repair/plans/01_logos-uid-collision-repair.md]
- **Summary**: [828_logos_trash_archive_uid_collision_repair/summaries/01_logos-uid-collision-repair-summary.md]

**Description**: Build and run a live-IMAP-verified, rename-only repair for the 862 duplicate-UID pairs left unresolved by task 826's Phase 5 (860 in ~/Mail/Logos/.Trash/cur, 2 in ~/Mail/Logos/.Archive/cur). Task 826's implementation verified that all 862 pairs have DIFFERENT Message-Id values between the two colliding files -- these are distinct, irreplaceable real messages that collided on the same local U=NNN slot due to a corrupted, non-monotonic Near-side UID counter from the 2026-02-09 import (see specs/826_logos_maildir_duplication_mbsync_repair/handoffs/phase-5-blocker-report.md). No Message-Id-based delete is safe.

Scope: For each colliding UID, perform a live IMAP UID FETCH/Message-Id lookup against the ProtonMail Bridge server for the current Far-side UID assignment of the affected folder (.Trash or .Archive), compare it against each local candidate file's Message-Id, and where a match is found on one member of the pair, rename the OTHER (non-matching) member's Maildir filename to a fresh, non-colliding U=NNN token. Rename only -- never delete either file, never write/push anything to the server via this task's own script. Build a dry-run mode that lists all planned renames before executing any of them. Validate the technique end-to-end on the 2 tractable .Archive pairs first, then apply the same script to the 860 .Trash pairs. Use the existing Phase 1 backup at ~/Mail/.logos-backup-20260706/ (tarballs, mbsyncstate/uidvalidity snapshots, baseline counts) as the rollback source, and log every rename decision (matched/renamed, which file, old and new UID token) to a new artifact under that backup directory.

Explicitly out of scope (left for task 826 to resume afterward): running `mbsync logos`, clearing/resetting .mbsyncstate or .uidvalidity, lifting email-freeze, notmuch reindexing. Do not re-verify Message-Id distinctness (already established) or re-run Phase 3's Labels-mirror analysis (separate, already-decided concern). Ground the implementation in specs/826_logos_maildir_duplication_mbsync_repair/handoffs/phase-5-blocker-report.md (resolution path 1) and the Phase 5 section of specs/826_logos_maildir_duplication_mbsync_repair/plans/01_logos-mbsync-maildir-repair.md.

Definition of done: `ls ~/Mail/Logos/.Trash/cur | grep -oE 'U=[0-9]+' | sort | uniq -d` and the equivalent for .Archive/cur both return nothing (one physical file per UID), zero files deleted, zero server-side writes performed by this task's script, and a decision log written to the Phase 1 backup directory documenting every rename.

---

### 827. Redesign the /email staleness detector - stop equating maildir files with deduped messages
- **Status**: [BLOCKED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 826

**Description**: The freshness gate shipped in tasks 823-825 is defective: email-census compares `himalaya -f INBOX` maildir FILE count against `notmuch count folder:X` deduped-MESSAGE count. These are incomparable (different file sets; heavy label-folder duplication; Message-ID dedup), so the line reads [STALE] even immediately after a full email-reindex (observed live: on-disk=3736 vs notmuch-indexed=3735, and `notmuch count --output=files folder:Logos`=11075 - none agree). As a hard gate requiring [ok] it is unreachable, forcing a manual 'Proceed, accept N' override on every --all run. Redesign options to evaluate: (a) compare comparable file sets - on-disk files vs `notmuch count --output=files` for the EXACT indexed path (path:<acct>/cur); (b) downgrade from a hard equality gate to a 'notmuch grossly behind disk' ratio/threshold heuristic that can actually reach a passing state and only blocks on large lags; (c) make the real gate 'was email-reindex run this session?' rather than a count comparison. Update census.nix (freshness line), skill-email-cleanup Stage 1 gate, staleness-detection.md, and wrapper-contracts.md section 13. Depends on 826 because the correct true count depends on resolving the Logos maildir duplication first. Cross-repo: census.nix change lands in ~/.dotfiles.

---

### 826. Investigate Logos maildir file-duplication and repair broken mbsync logos sync
- **Status**: [BLOCKED]
- **Task Type**: nix
- **Topic**: extensions
- **Dependencies**: None
- **Research**:
  - [826_logos_maildir_duplication_mbsync_repair/reports/01_logos-maildir-mbsync-diagnosis.md]
  - [826_logos_maildir_duplication_mbsync_repair/handoffs/phase-7-blocker-report.md]
- **Plan**: [826_logos_maildir_duplication_mbsync_repair/plans/01_logos-mbsync-maildir-repair.md]
- **Summary**:
  - [826_logos_maildir_duplication_mbsync_repair/summaries/01_logos-mbsync-maildir-repair-summary.md]
  - [826_logos_maildir_duplication_mbsync_repair/summaries/02_phase7-reconcile-attempt-summary.md]

**Description**: Root-cause and fix the pre-existing Logos (Protonmail Bridge) mail infrastructure problem exposed by /email --logos --all (2026-07-05). Symptoms: (1) severe maildir file duplication - path:Logos/cur holds 8448 files for only 2869 unique Message-IDs (~3x), and folder:Logos spans 3735 messages / 11075 files; the Gmail-labels-over-IMAP pattern stores one message under many .Labels.* folders. (2) `mbsync logos` reconcile exits non-zero after mutations with: duplicate UIDs in .Trash/.Archive, a Maildir++ dotted-folder problem on `.Labels.benbrastmckie@gmail.com` (a dot in the folder name), and a draft with a missing Date header. Consequence: 161 local deletes from the recent cleanup are staged in local Logos Trash but CANNOT be pushed to the Proton server. Investigate ~/.dotfiles/modules/home/email/mbsync.nix (logos group/channels), notmuch.nix, and protonmail.nix; determine whether the .Labels.* folders should be excluded from the logos mbsync channels, whether Bridge label-folders are double-synced, and how to resolve the duplicate-UID and dotted-folder errors. Cross-repo: fixes land in ~/.dotfiles (deliberate handoff). Deliver a diagnosis + a concrete mbsync/notmuch config fix and a maildir de-duplication/cleanup plan. Do NOT run /email --logos --sync until this is fixed.

---

### 825. Wire detect->remediate->re-run into the --all coverage contract and docs
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 823, Task 824

**Description**: Synthesis/documentation task closing the loop opened by 823 (detection) and 824 (remediation). Update commands/email.md (add the staleness->remediation flow to Workflow Execution and Error Handling), EXTENSION.md, README.md, and the archive-mode-risk.md / bulk-bucket-review.md context so the --all whole-mailbox coverage promise is EXPLICITLY conditioned on a fresh notmuch index, and the end-to-end flow (detect staleness -> recommend/run sanctioned reindex or --sync -> re-run --all) is documented consistently across command, skill, and context layers. Ensure no residual doc claims --all covers the whole mailbox unconditionally.

---

### 824. Provide a sanctioned notmuch reindex remediation path for /email
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 823

**Description**: When staleness is detected (task 823) the skill currently dead-ends: notmuch new is treated as forbidden raw notmuch, so there is no sanctioned remediation. But notmuch new is index-only and non-mutating — exactly analogous to mbsync, which IS sanctioned via skill-email-sync (not a wrapper binary, passes mail-guard.sh, human-confirmed). Research how notmuch reindexing is actually wired for these maildirs (post-mbsync notmuch new hook? systemd path/timer? manual). Then add a sanctioned remediation mirroring the mbsync precedent: fold a reindex step into skill-email-sync or a documented /email --sync behavior, or document the exact sanctioned command, so the skill can remediate rather than dead-end. Reconcile wrapper-contracts.md §8 (two-layer enforcement) and mail-guard.sh reasoning to distinguish index-only notmuch new (sanctioned, like mbsync) from forbidden raw notmuch/himalaya MUTATION and tag commands; ensure skill MUST-NOT text stays consistent. May surface a .dotfiles handoff recommendation if reindex belongs in the frozen wrapper layer.

---

### 823. Add notmuch-staleness detection gate to skill-email-cleanup
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [823_email_notmuch_staleness_detection_gate/reports/01_staleness-detection-research.md]

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
