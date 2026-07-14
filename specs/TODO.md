---
next_project_number: 862
---

# TODO

## Task Order

*Updated 2026-07-14. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 861 | -- | agent-system |

**Grouped by Topic** (indented = depends on parent):

### Agent System

861 [NOT STARTED] — Add a deployed-vs-source content drift check for extension rules 

## Tasks

### 861. Add rule drift check to extension lint
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Add a deployed-vs-source content drift check for extension rules in check-extension-docs.sh. The script's check_deployed_script_drift covers manifest.provides.scripts only, comparing the deployed .claude/scripts/<name> against the extension source <ext>/scripts/<name>. There is no equivalent check for provides.rules, so a rule file whose deployed .claude/rules/<name>.md has diverged from its extension source is invisible to lint.

This is not hypothetical. core/rules/pr-prohibition.md had silently accumulated 35 lines in its deployed copy (the "/pr --review Workflow" section) that were absent from the extension source. The divergence survived precisely because the rule was unregistered in provides.rules, so the loader never overwrote the deployed copy. Once registered, the loader's byte-for-byte copy_file() overwrite would have destroyed that content -- the reconciliation had to be performed by hand first. A drift check would have surfaced this years earlier.

Implement check_deployed_rule_drift mirroring check_deployed_script_drift: for each manifest.provides.rules entry where BOTH the deployed .claude/rules/<name> and the extension source <ext>/rules/<name> exist, fail on content mismatch; skip with an info note (never fail) when the deployed copy is absent, since an extension's rules are not deployed in every consuming repo.

Also evaluate whether the same deployed-vs-source asymmetry applies to provides.agents, provides.commands, and provides.context, and whether a single drift helper parameterized by category is warranted rather than adding a fourth near-duplicate function.

Note: check-extension-docs.sh is itself declared in core's provides.scripts, so any edit must be written to BOTH .claude/scripts/ and .claude/extensions/core/scripts/ or the drift check will flag the change itself.

---

### 860. Enforce plan compliance rule
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [860_enforce_plan_compliance_rule/reports/01_plan-compliance-rule.md]
- **Plan**: [860_enforce_plan_compliance_rule/plans/01_plan-compliance-rule.md]
- **Summary**: [860_enforce_plan_compliance_rule/summaries/01_plan-compliance-rule-summary.md]

**Description**: Add a .claude/rules/ rule enforcing strict plan compliance for lean-implementation-agent and other formal implementation agents. The rule should: (1) Prohibit agents from "assessing what's truly minimal" or inventing alternative approaches when a plan exists. (2) Require agents to follow the plan's exact task sequence step-by-step, in order. (3) Explicitly ban common divergence patterns: skipping intermediate theorems, inlining proofs instead of following the plan's decomposition, routing through different helper lemmas than specified, and "cleaner approach" rationalizations. (4) Be auto-applied via glob pattern to formal proof files (e.g. Theories/**, **/*.lean); the glob must generalize across consuming repos rather than hard-coding one project's layout. (5) Reference the repeated failures in BimodalLogic task 157 (8 plan versions, agents diverging every time) as motivation. The rule should be concise but firm -- agents must treat the plan as a contract, not a suggestion.

Provenance: relocated from BimodalLogic task 162 (2026-07-14). Authored here in the agent-system source of truth so the rule syncs out to consuming repos, rather than living only in BimodalLogic/.claude/.

---

### 859. Fix generate-task-order.sh: dependency tree renders flat for non-lowercase topic strings (topic-key case mismatch)
- **Effort**: low
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [859_fix_task_order_topic_case_indentation/reports/01_topic-standardization.md]
- **Plan**: [859_fix_task_order_topic_case_indentation/plans/01_topic-normalization.md]
- **Summary**: [859_fix_task_order_topic_case_indentation/summaries/01_topic-normalization-summary.md]

**Description**: generate-task-order.sh renders the Grouped-by-Topic dependency tree FLAT (no indented '└─' children) for any topic whose raw string is not already all-lowercase. ROOT CAUSE: topic sections are grouped under a LOWERCASED key (`_current_section_topic` = the lowercased topic, set from the grouping key at generate_grouped_section), but the two guards that decide child recursion / cross-topic annotation compare that lowercased key against the RAW topic string from state.json. In .claude/extensions/core/scripts/generate-task-order.sh: line 578 `"$dep_topic" != "$_current_section_topic"` (successor-skip in _print_topic_node) and line 553 `"$task_topic_val" != "$_current_section_topic"` (cross-topic 'see above' annotation). For a task with topic 'Modal Logic', dep_topic='Modal Logic' but _current_section_topic='modal logic', so the strings never match, every successor is skipped, and the tree collapses to a flat list. Only all-lowercase topics (e.g. 'modal-logic') ever showed the tree; Title-Case topics ('Modal Logic', 'Code Hygiene', etc.) always rendered flat. FIX (already validated live in the deployed Projects/cslib copy): lowercase both sides of both comparisons — line 578 -> `"${dep_topic,,}" != "$_current_section_topic"` and line 553 -> `"${task_topic_val,,}" != "$_current_section_topic"`. After the fix the 491->495->496->484 chain indents correctly under a single Modal Logic heading. APPLY TO: (1) source-of-truth .claude/extensions/core/scripts/generate-task-order.sh (lines 553, 578); (2) mirror the same two-line change to .opencode/scripts/generate-task-order.sh (lines 481, 506) for OpenCode parity. The deployed .claude/scripts/generate-task-order.sh is regenerated from the core extension on load, so editing the core source is what persists; do not rely on the standalone .claude/scripts copy. VERIFY: after editing, run `bash .claude/scripts/generate-todo.sh` (or a fixture) on a state.json containing a Title-Case topic with an intra-topic dependency chain and confirm the '└─' indentation appears. RELATED REFINEMENT (optional, same file): the topic grouping key lowercases but does NOT normalize separators, so 'Modal Logic' and 'modal-logic' hash to different keys ('modal logic' vs 'modal-logic') and produce TWO identical-looking '### Modal Logic' headings. Consider normalizing hyphen<->space (and maybe collapsing whitespace) in the grouping key so case- and separator-variant topic strings collapse into one section, preventing duplicate headings. CONTEXT: discovered in Projects/cslib while normalizing kebab-case topic values to Title-Case, which merged two duplicate Modal Logic sections but exposed this latent case-sensitivity bug.

---

### 858. Fast, responsive, non-failing <leader>me aerc launch
- **Effort**: medium
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: neovim
- **Dependencies**: None
- **Research**:
  - [858_mail_launch_gate_performance/reports/01_launch-gate-performance-diagnosis.md]
  - [858_mail_launch_gate_performance/reports/02_hard-research-fast-responsive-launch.md]
- **Plan**: [858_mail_launch_gate_performance/plans/02_fast-responsive-aerc-launch.md]
- **Summary**: [858_mail_launch_gate_performance/summaries/02_fast-responsive-aerc-launch-summary.md]

**Description**: The <leader>me aerc launch workflow in lua/neotex/plugins/tools/mail.lua has become slow and now permanently refuses to open aerc. A single press triggers THREE overlapping sync layers -- (1) a himalaya-plugin inbox sync, (2) mail.lua sync_all_mail running the forbidden all-channels `mbsync -a` (which syncs Gmail All_Mail ~64k messages and fails code 1 on a pre-existing duplicate-UID collision), and (3) run_notmuch_new calling hook-ful `notmuch new`, whose preNew hook is now `mail-sync both` (dotfiles task 109), recursively driving a full serialized gmail+logos mbsync -- plus two email-census scans. All of it runs synchronously on the launch-blocking critical path, so the user waits for the slowest full sync before anything appears. The gate then refuses to open aerc because it conflates "mbsync succeeded" with "index is safe to read": the primary barrier requires mbsync -a + notmuch new to exit 0 (impossible while the duplicate-UID persists -- a manual data repair, not a sync fix), and the census fallback honestly reports [STALE]. Net effect: a sync-independent data fault permanently denies the mail client even though, after notmuch new reconciles the index, opening aerc would be safe. GOAL: redesign <leader>me for fast, responsive, non-failing launch -- open aerc promptly on a cheaply-reconciled index (notmuch new --no-hooks) with mbsync deferred/backgrounded and never on the launch-blocking path; decouple launch from mbsync exit code (warn, do not block); eliminate the redundant sync layers (route through the single mail-sync wrapper, use --no-hooks to avoid recursive re-sync, reconcile/suppress the himalaya double-sync); never use mbsync -a; keep the full explicit sync on <leader>mN. Must remain safe against opening onto a genuinely stale/mid-write Xapian index (no return of "could not get MessageInfo" races). Non-goal: the one-time duplicate-UID-15 maildir data repair, but the fix must make <leader>me usable despite an unrepaired collision. See reports/01_launch-gate-performance-diagnosis.md for the seed diagnosis; deep study to be produced by a fable --hard researcher.

---

### 857. Reindex-on-failure for the aerc launch gate
- **Effort**: small
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: neovim
- **Dependencies**: None
- **Research**: [857_mail_reindex_on_failure_gate/reports/01_reindex-on-failure-gate.md]
- **Plan**: [857_mail_reindex_on_failure_gate/plans/01_reindex-on-failure-gate.md]
- **Summary**: [857_mail_reindex_on_failure_gate/summaries/01_reindex-on-failure-gate-summary.md]

**Description**: Harden the <leader>me aerc launch gate in lua/neotex/plugins/tools/mail.lua so a failed `mbsync -a` no longer leaves notmuch stale before the freshness decision, providing a minimal, durable fix without unnecessary complexity.

CURRENT BEHAVIOR (verified in mail.lua): sync_all_mail() runs `notmuch new` ONLY when `mbsync -a` exits 0; on mbsync failure it notifies the error and returns via on_done(false) WITHOUT reindexing. The gate itself already refuses-and-reports rather than failing open -- it opens aerc only on a clean sync+reindex, or when census_freshness_ok() reads [ok] on BOTH accounts, otherwise it refuses with remediation guidance. That refuse-and-report barrier is sound and must be preserved.

GAP TO FIX (the real durable change): on the mbsync-failure path, run `notmuch new` BEFORE the freshness decision, so maildir files that already landed on disk -- or mailboxes that synced before an abort such as a duplicate-UID collision -- get reconciled into the index. Then let the existing authoritative barrier make the launch decision against a freshly reindexed state instead of a stale one.

SCOPE CONSTRAINTS:
- Keep the change minimal and cohesive (one function/gate); do not duplicate freshness logic that belongs in the external census wrapper.
- Preserve the existing refuse-and-report barrier and its remediation messaging.
- The fallback signal census_freshness_ok() reads the "INBOX freshness ... [ok]" line, a count-with-tolerance proxy that cannot detect flag-renames or phantom drift -- this is what produced the false green. Making that signal authoritative is an EXTERNAL follow-up in ~/.dotfiles modules/home/email/agent-tools/census.nix (rename/deletion-aware freshness) and is intentionally OUT OF SCOPE here. Document the dependency in the gate's comment so a future reader knows the barrier's trustworthiness rests on that external signal.

OUT OF SCOPE (context only, no repo change, no commit): one-time ~/Mail data repair for the duplicate UID 15 collision in Gmail/.All_Mail, and the one-time `notmuch new` index reconciliation of the ~38-file INBOX phantom drift. These are manual mail-data operations, not code.
