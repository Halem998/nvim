---
next_project_number: 28
---

# TODO

## Task Order

*Updated 2026-08-11. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 14,16,17,18,19,20,22,25,26,27 | -- | agent-system, extensions, orchestration-concurrency, ... |
| 2 | 9,13 | 17,18 | agent-system |

**Grouped by Topic** (indented = depends on parent):

### Agent System

14 [NOT STARTED] — Two dispatches in a single batch fanned out to phase sub-agents a
17 [NOT STARTED] — command-gate-out.sh's entire post-metadata body is structurally u
  └─ 13 [NOT STARTED] — The acceptance criterion "gate-out reports zero format errors and
18 [NOT STARTED] — A repo can carry an arbitrarily stale .claude/ deploy with no sig
  └─ 9 [NOT STARTED] — Declared-vs-deployed parity for provides.* categories is one-dire
20 [NOT STARTED] — /todo's repository-metrics sync runs before its git commit, so th
27 [NOT STARTED] — .opencode/scripts/execute-command.sh is a command router that can

### Extensions

19 [NOT STARTED] — Reloading extensions in a consuming repo emits roughly 60 lines o
22 [NOT STARTED] — Silence and correct opencode-agents.json fragment validation spam

### Orchestration Concurrency

16 [IMPLEMENTING] — Fix the register-bare/acquire-suffixed session-id pattern in the 

### Mcp Integration

25 [PLANNING] — Activate the already-designed but parked Playwright MCP integrati
26 [PLANNED] — Migrate slidev deck screenshot verification from the standalone n

## Tasks

### 27. Remove the dead .opencode command router and its self-referential test scripts
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: .opencode/scripts/execute-command.sh is a command router that cannot execute anything and is called by nothing but its own tests. Delete it and the three test scripts that exist only to exercise it.

SCOPE NOTE -- THIS IS NOT THE SYNTAX-ERROR TASK. A duplicated case pattern in this file was already fixed in this repo; the file parses cleanly under `bash -n` today, and separately-tracked metrics-sync work already records that fix as done. Do not re-open it. The work here is deletion of a file that is dead for reasons unrelated to that syntax defect. If someone arrives expecting a one-line syntax repair, that repair has already landed.

MEASURED EVIDENCE (live, this repo, do not re-derive):

(1) Its runtime dependency has never existed. Both live branches of its case statement emit a heredoc that runs
        source "$OPENCODE_ROOT/context/core/patterns/command-integration.sh"
        execute_lean_command "$command_name" "$arguments"
    .opencode/context/core/patterns/command-integration.sh is absent. A repo-wide grep for `execute_lean_command` across all *.sh returns matches ONLY inside execute-command.sh's own two echo strings -- the function is defined nowhere. So every successful dispatch path terminates in a missing source file followed by an undefined function. The router has no working branch; the only reachable non-error outcome is the `*)` unknown-command arm that exits 1.

(2) Nothing invokes it. Files referencing execute-command.sh outside specs/**:
        .opencode/scripts/execute-command.sh    (itself: shebang comment + usage string)
        .opencode/scripts/test-execution-system.sh   (3 references)
        .opencode/scripts/test-execution.sh          (1 reference)
        .opencode/scripts/test-command.sh            (1 reference)
        .opencode/scripts/test-results.md            (prose describing those tests)
    opencode.json contains no reference to it. No file under lua/ references it or .opencode/scripts at all. There is no other live execution path wired to this router -- it is not the mechanism by which .opencode commands actually run.

(3) The three test scripts test nothing else. They are 49, 16, and 10 lines; every reference each one makes is to execute-command.sh. Deleting the router without them would leave three scripts whose entire purpose is invoking a file that no longer exists.

(4) It is stale. Last commit touching .opencode/scripts predates this task by roughly five months.

WORK:
  1. Delete .opencode/scripts/execute-command.sh.
  2. Delete .opencode/scripts/test-execution-system.sh, test-execution.sh, and test-command.sh.
  3. Resolve .opencode/scripts/test-results.md -- it documents results for the deleted tests. Decide explicitly between deleting it and reducing it to a note recording that the router was removed; do not leave it describing tests that no longer exist.
  4. Confirm .opencode/scripts/README.md needs no edit. A grep for execute-command / test-execution / test-command / test-results against it currently returns nothing, so the expected outcome is no change -- but state that you re-checked rather than assuming, since the README is the natural place for a stale pointer to survive.

EDIT TARGET (binding): edit .opencode/** directly. A find across agent-system/ for execute-command.sh and test-execution*.sh returns nothing -- .opencode/ has no source-store counterpart in this repo and is separately git-tracked, so the source-store/deploy-boundary rule that governs .claude/** does not apply here. Do NOT attempt to locate or edit an agent-system source for these files; there is none.

DOWNSTREAM PROPAGATION (in scope to decide, not necessarily to perform): four other repos carry copies of this same router -- Logos/Theory, protocol, ModelChecker, and OpenCode. All four still contain the duplicated case pattern and therefore FAIL `bash -n`, and all four are likewise missing command-integration.sh. This repo is the reload source, so the intended mechanism is that deleting here propagates on the next reload. Verify whether reload actually removes downstream files or only adds and overwrites them -- a reload that never deletes would leave four broken copies in place indefinitely, which is a materially different outcome. Record the finding either way; if propagation does not delete, say so plainly and note what a follow-up would need to cover rather than silently assuming the copies are handled.

ACCEPTANCE: after the change, a repo-wide grep for `execute-command.sh` outside specs/** returns zero hits (or only hits inside a deliberately-retained note from item 3, accounted for individually). `bash -n` passes across every remaining .opencode/scripts/*.sh -- it already does for all thirteen non-router scripts, so this must not regress. assess-repo-health.sh reports build_errors unchanged or lower, and specifically not higher, than its pre-change value; report both numbers rather than asserting improvement.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 26. Migrate slidev deck verification from standalone npm Playwright script to MCP server
- **Effort**: 3-6 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: mcp-integration
- **Dependencies**: Task 24
- **Research**: [026_migrate_slidev_verification_to_playwright_mcp/reports/01_slidev-verification-mcp-migration.md]
- **Plan**: [026_migrate_slidev_verification_to_playwright_mcp/plans/01_slidev-verification-mcp-plan.md]

**Description**: Migrate slidev deck screenshot verification from the standalone npm Playwright script to the live Playwright MCP server, removing the duplicate Playwright install path.

PROBLEM: the present and founder extensions carry their own Playwright usage that predates the MCP server and duplicates its capability. agent-system/extensions/present/context/project/present/talk/templates/playwright-verify.mjs is a standalone Node script requiring a separate npm Playwright install and its own browser binaries. Related references appear in present/context/project/present/talk/patterns/slidev-pitfalls.md, present/context/project/present/domain/talk-modes-and-library.md, present/context/project/present/talk/templates/slidev-project/README.md, present/index-entries.json, present/context/project/present/talk/index.json, founder/agents/deck-builder-agent.md, and founder/context/project/founder/patterns/slidev-deck-template.md.

WORK: replace the standalone-script verification path with the MCP server (browser_navigate plus browser_snapshot / browser_take_screenshot), so the system has ONE browser automation mechanism rather than two independent Playwright installs. Update the referencing context files, agent docs, and index entries consistently so nothing points at a removed path.

CAUTION -- VERIFY PARITY BEFORE DELETING: confirm the .mjs script's full capability is genuinely covered by the MCP tool set before removing it. A standalone script can do things a permissioned MCP surface cannot: custom in-page evaluation loops, batch or offline runs with no agent in the loop, and deterministic CI invocation. Note specifically that browser_evaluate and browser_run_code_unsafe are deliberately NOT allowlisted and will prompt, so any verification logic depending on in-page evaluation may not migrate cleanly. If full parity is not achievable, DOCUMENT THE RESIDUAL GAP and keep the script for that narrow case rather than forcing the migration and silently losing coverage.

DEPENDS ON the permission work: this migration is only viable once the safe browser tools run without prompting.

ACCEPTANCE: deck screenshot verification runs through the MCP server; the duplicate npm Playwright install path is removed, or its continued existence is explicitly justified in writing; all referencing docs and index entries are consistent with the outcome.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/present/** and /home/benjamin/.config/nvim/agent-system/extensions/founder/**. Never edit any deployed .claude/** tree -- those are gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 25. Activate parked Playwright MCP integration in web extension and reconcile drifted tool list
- **Effort**: 3-6 hours
- **Status**: [PLANNING]
- **Task Type**: meta
- **Topic**: mcp-integration
- **Dependencies**: Task 23, Task 24
- **Research**: [025_activate_playwright_mcp_in_web_extension/reports/01_activate-playwright-mcp.md]

**Description**: Activate the already-designed but parked Playwright MCP integration in the web extension, and reconcile its drifted tool list against the live server.

THIS IS AN ACTIVATION TASK, NOT A GREENFIELD BUILD. A complete design already exists in agent-system/extensions/web/agents/web-implementation-agent.md (approximately lines 50-63) under the heading '**Playwright MCP** (deferred -- not yet active)' with '**Status**: Deferred pending browser binary installation'. That precondition is now satisfied: the server is registered at user scope, connected and healthy, exposing 24 browser_* tools.

DO NOT REMOVE THE web-research-agent BLOCK. agent-system/extensions/web/agents/web-research-agent.md line 4 carries 'disallowedTools: mcp__playwright__*'. This is DELIBERATE ROLE-SCOPING, not an obstacle to clear: web-implementation-agent symmetrically blocks mcp__context7__* instead. Each agent blocks the MCP server that is not its job -- research reads docs, implementation drives browsers. Leave BOTH blocks in place.

WORK:
(1) Flip the deferred status to active in web-implementation-agent.md.
(2) PRESERVE the usage conditions already written there: prefer accessibility snapshots over screenshots (lower token cost, more useful); do NOT use Playwright for tasks verifiable with 'pnpm build' alone; only use when the implementation plan includes visual verification steps.
(3) RECONCILE THE DRIFTED SPEC. The parked section lists browser_verify_text_visible, which does NOT exist among the server's actual tools. Map the deferred spec's INTENT onto real tools -- for example, text-visibility assertions map onto browser_find and/or browser_wait_for. The real 24-tool set is: browser_navigate, browser_navigate_back, browser_snapshot, browser_take_screenshot, browser_click, browser_type, browser_fill_form, browser_find, browser_hover, browser_drag, browser_drop, browser_select_option, browser_press_key, browser_wait_for, browser_resize, browser_tabs, browser_close, browser_handle_dialog, browser_console_messages, browser_network_request, browser_network_requests, browser_evaluate, browser_file_upload, browser_run_code_unsafe.
(4) Teach WHEN to drive a browser, not merely how: screenshot and visual verification of a running app, console and network inspection for debugging, end-to-end UI checks. Add a context file under agent-system/extensions/web/context/ and register it in web/index-entries.json if a new file is created.
(5) Keep guidance consistent with the permission split from the prerequisite task: guidance must NOT instruct agents to rely on tools that still prompt (browser_run_code_unsafe, browser_evaluate, browser_file_upload), since that would reintroduce the autonomous-run stall.

ACCEPTANCE: web-implementation-agent documents an active, accurate Playwright MCP capability naming only tools that actually exist; web-research-agent's disallowedTools line is unchanged; no guidance depends on a tool that still prompts.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/web/**. Never edit any deployed .claude/** tree -- those are gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 24. Scope Playwright MCP permission allowlist to safe browser tools, solving install-once propagation
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: mcp-integration
- **Dependencies**: Task 23
- **Research**: [024_scope_playwright_mcp_permission_allowlist/reports/01_scoped-playwright-permission-allowlist.md]
- **Plan**: [024_scope_playwright_mcp_permission_allowlist/plans/01_scoped-playwright-permission-allowlist.md]
- **Summary**: [024_scope_playwright_mcp_permission_allowlist/summaries/01_scoped-playwright-permission-allowlist-summary.md]

**Description**: Add a deliberately scoped Playwright MCP permission allowlist so autonomous runs stop stalling, without blanket-allowing arbitrary execution.

PROBLEM: mcp__playwright__* is absent from every settings allowlist while mcp__lean-lsp__* is present, so every browser call raises a permission prompt. Under /orchestrate there is no human available to answer, so autonomous runs stall.

DESIGN (fixed by user decision, not open for redesign): allowlist ONLY the safe navigation and inspection tools -- browser_navigate, browser_snapshot, browser_take_screenshot, browser_console_messages, browser_network_requests, browser_click, browser_type, browser_find, browser_wait_for. Deliberately OMIT browser_run_code_unsafe, browser_evaluate, and browser_file_upload: these are arbitrary-execution/upload tools and MUST continue to prompt.

GRANULARITY IS ALREADY PROVEN EXPRESSIBLE -- DO NOT RE-RESEARCH THIS. nix/settings-fragment.json allowlists mcp__nixos__nix and mcp__nixos__nix_versions individually; lean/settings-fragment.json enumerates 21 individual mcp__lean-lsp__lean_* entries; founder's fragment likewise enumerates individual tool names. Per-tool MCP permission entries work.

'KEEP PROMPTING' NEEDS NO ask/deny RULE: omission from permissions.allow already yields a prompt. The existing permissions.deny list is Bash-only (rm -rf /, rm -rf ~, sudo *, chmod 777 *) and there is no ask key in use anywhere. Do not invent one.

THE REAL HAZARD -- INSTALL-ONCE PROPAGATION: core/root-files/settings.json deploys to .claude/settings.json under install-once semantics (loader.lua's copy_category('root_files'), gated by CATEGORY_DESCRIPTORS.root_files.install_once; manager.unload also excludes these files via loader_mod.INSTALL_ONCE_ROOT_FILES). Once a project has its own .claude/settings.json, reloading or re-loading the providing extension NEVER overwrites it. Therefore simply editing core/root-files/settings.json will NOT reach any existing project. This task must establish how the new grants actually propagate -- for example via an extension settings-fragment.json (which targets .claude/settings.local.json and is not install-once), via user-scope settings, or via a documented migration step -- consistent with the ownership boundary decided in the prerequisite task.

ACCEPTANCE: in a project that ALREADY has a .claude/settings.json, the 9 safe browser tools run without prompting, and browser_run_code_unsafe, browser_evaluate, and browser_file_upload still prompt. Verify against a pre-existing settings file, not a freshly generated one -- a fresh project would mask the install-once defect.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never edit any deployed .claude/** tree -- those are gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 23. Document MCP registration vs permission ownership boundary; reconcile lean-lsp three-way duplication
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: mcp-integration
- **Dependencies**: None
- **Research**: [023_document_mcp_registration_ownership_boundary/reports/01_mcp-registration-ownership-boundary.md]
- **Plan**: [023_document_mcp_registration_ownership_boundary/plans/01_mcp-ownership-boundary.md]
- **Summary**: [023_document_mcp_registration_ownership_boundary/summaries/01_mcp-ownership-boundary-summary.md]

**Description**: Define and document the ownership boundary between the four competing MCP registration/permission mechanisms, and reconcile the existing lean-lsp three-way duplication.

PROBLEM: the agent system now has FOUR mechanisms that can register an MCP server or grant its permissions, with no documented boundary between them:
(1) A home-manager activation block writing to ~/.claude.json (user scope). This is how the playwright MCP server was registered; it is connected and healthy, exposing 24 browser_* tools.
(2) Per-extension settings-fragment.json, deployed via the manifest's settings section ({"source": "settings-fragment.json", "target": ".claude/settings.local.json"}). Used by nix (mcp-nixos plus 2 enumerated tool permissions) and lean (lean-lsp plus 21 enumerated tool permissions).
(3) core/root-files/settings.json, deployed to .claude/settings.json as INSTALL-ONCE. Currently carries a mcp__lean-lsp__* WILDCARD in permissions.allow.
(4) core/scripts/setup-lean-mcp.sh, which registers lean-lsp directly into user scope ~/.claude.json.

EVIDENCE THE PROBLEM IS REAL AND ALREADY BITING: lean-lsp is currently registered or permitted by THREE of these simultaneously (mechanisms 2, 3, and 4), and mechanisms 2 and 3 disagree about form -- the extension fragment enumerates 21 individual tools while core grants a blanket wildcard. This is precisely the duplication the playwright integration must avoid repeating.

KEY ARCHITECTURAL CONSTRAINT (already recorded in core/scripts/setup-lean-mcp.sh's own header): custom subagents CANNOT access project-scoped MCP servers (.mcp.json); user scope (~/.claude.json) is required for subagent access. Since agents are the consumers of browser tools, this argues that REGISTRATION belongs in user scope (home-manager or a setup script), while PERMISSION GRANTS must live in the settings files the host app reads. Confirm or refute this split rather than assuming it.

DELIVERABLE: a decision recorded in the source store stating which mechanism owns MCP server REGISTRATION, which owns PERMISSION grants, why, and how the two compose. Update permission-configuration.md and/or extension-system.md, adding a context pattern if warranted. Reconcile the lean-lsp wildcard-vs-enumeration split, or explicitly justify keeping it.

ACCEPTANCE: a future extension author can read one document and know where to declare a new MCP server and its permissions without creating a fifth duplicate path.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/**. Never edit any deployed .claude/** tree -- those are gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 22. Silence opencode fragment validation spam
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Silence and correct opencode-agents.json fragment validation spam on extension reload.

SYMPTOM (observed live): reloading .claude/ via <leader>al from a project with an
opencode.json.managed marker emits ~60 WARN notifications of the form "Extension 'X'
opencode-agents.json validation failed: Agent 'Y' references missing file: Z. Skipping
fragment." before "Resynced 12 extension(s)".

EMITTER: M.generate_opencode_json in lua/neotex/plugins/ai/shared/extensions/merge.lua
(vim.notify at ~line 994), gated on an opencode.json.managed marker check (~line 931), with
per-fragment validation by M.validate_opencode_fragment (~line 887), which resolves each agent
prompt's {file:PATH} against project_dir.

THREE DISTINCT DEFECT CLASSES (measured against a live project, not assumed):

(1) MISSING DEPLOY TARGETS -- 16 of 18 {file:} refs across python (2), present (5), nix (2),
and filetypes (7) point at .opencode/agent/subagents/*-agent.md files that were never
deployed. The .opencode/agent/subagents/ directory DOES exist and holds 15 agent files
(core, lean, latex, typst, math, logic, physics, formal, meta-builder, planner,
code-reviewer), but none for those four extensions. So this is a partial-deploy gap, not a
wholly absent tree.

(2) LEAN WRONG-PATH BUG (independent of any opencode policy decision) --
agent-system/extensions/lean/opencode-agents.json is the ONLY fragment using a .claude/ path
shape. It references .claude/extensions/lean/agents/lean-research-agent.md and
.claude/extensions/lean/agents/lean-implementation-agent.md, neither of which exists anywhere,
while the CORRECT files .opencode/agent/subagents/lean-research-agent.md and
.opencode/agent/subagents/lean-implementation-agent.md ALREADY EXIST on disk. This is a plain
mis-pathed reference, fixable on its own merits regardless of what is decided about opencode.

(3) NOTIFICATION SPAM AND SIMULTANEOUS UNDER-REPORTING -- the same 5 messages repeat ~12 times
because generation runs once per resynced extension rather than once per reload. Separately,
validate_opencode_fragment iterates with pairs() and returns on the FIRST missing ref, so only
one broken ref per extension is ever named, and WHICH one varies nondeterministically between
runs (python alternates python-research/python-implementation; filetypes alternates
scrape/filetypes-spreadsheet). The true breakage (18 refs) is therefore both over-announced in
aggregate and under-reported per message.

BINDING CONSTRAINT (from the user): .opencode/ is NOT currently used and may be excluded from
scope, BUT the fix MUST NOT damage or delete .opencode/ infrastructure. The opencode-agents.json
fragments, the validator function, the managed-marker gating, and the existing .opencode/ tree
must all survive intact so .opencode/ can be refactored in the future. Prefer suppressing or
gating the noise over removing the mechanism.

ACCEPTANCE: a <leader>al reload from a project carrying an opencode.json.managed marker
produces no validation-failure spam; the lean fragment's two refs resolve to real files;
whatever gating approach is chosen is documented; and no opencode fragment, no validator
function, and no .opencode/ file is deleted.

SOURCE-STORE RULE (binding): edit lua/** for the Lua emitter and agent-system/extensions/** for
the JSON fragments; never edit .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 21. Vault transition comment is wiped by TODO.md regeneration, corrupts frontmatter where it runs
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [021_resolve_vault_transition_comment_nondurable/reports/01_resolve-vault-transition-comment.md]
- **Plan**: [021_resolve_vault_transition_comment_nondurable/plans/01_resolve-vault-transition-comment.md]
- **Summary**: [021_resolve_vault_transition_comment_nondurable/summaries/01_resolve-vault-transition-comment-summary.md]

**Description**: /todo and skill-todo both instruct the vault path to hand-insert an HTML transition comment into specs/TODO.md, but generate-todo.sh regenerates that file wholesale, so the comment is wiped by the next regeneration. The instruction is also actively harmful where it does run: as written it corrupts the YAML frontmatter and duplicates itself. Decide the correct resolution and apply it consistently.

THE DECISION IS ALREADY ON RECORD -- this is a re-regression, not a new finding. The archived summary at
    specs/vault/01-vault/archive/653_update_task_creation_commands_state_first/summaries/01_task-creation-migration-summary.md
states under Decisions:
    "Vault transition comment: Removed the Python script that inserted HTML comments into TODO.md frontmatter. Since generate-todo.sh regenerates the entire file, vault transition info is preserved in state.json's vault_history array instead."
That earlier work removed the SCRIPT but left the PROSE INSTRUCTION in place, so the behavior was re-specified in the two live documents that callers actually follow. Treat that recorded decision as strong prior art; if the resolution chosen here differs from it, say why explicitly rather than silently diverging a second time.

MEASURED EVIDENCE (live, this investigation -- do not re-derive):

(1) The comment does not survive. A vault run inserted the documented comment after TODO.md's frontmatter; the very next state-write with --regen-todo removed it. generate-todo.sh treats TODO_FILE purely as an output target -- it is referenced only as a default path, an argument, an mktemp sibling, and the destination of `mv "$TEMP_FILE" "$TODO_FILE"`. There is no read of the existing file anywhere, so nothing hand-written into TODO.md can persist by construction.

(2) The skill's insertion corrupts the frontmatter AND double-inserts. Running skill-todo's exact sed against a real 3-line frontmatter (---, next_project_number: N, ---) produced:
    ---
    next_project_number: 20
    <!-- Vault transition: ... -->
    ---

    <!-- Vault transition: ... -->
    # TODO
The range /^---$/,/^---$/ matches the closing delimiter as well as the opening one, so `a` fires twice: once after the line following the opening --- (placing an HTML comment INSIDE the YAML block, which is not valid YAML) and once after the closing ---. Any consumer that parses TODO.md frontmatter strictly would see a malformed block.

(3) The computed task range is wrong. skill-todo derives the range as $((next_num - renumber_count - 1)). With this run's real values (next_num 1020, renumber_count 11) that yields 1008, so the comment would have claimed "tasks numbered 1 through 1008 archived" -- but the vault actually contains everything through 1015, and 1008 is not the renumbering boundary either. The number describes nothing.

LIVE SITES (both in the source store, both currently instructing the broken behavior):
  agent-system/extensions/core/commands/todo.md:893-898  (Step 5.8.9)
  agent-system/extensions/core/skills/skill-todo/SKILL.md:877-890  (the sed block)

DURABLE RECORDS THAT ALREADY EXIST (the reason deletion is viable):
  specs/state.json .vault_history[] -- {vault_number, vault_dir, created_at}
  specs/vault/{NN}-vault/meta.json -- {vault_number, created_at, archived_count, final_task_number}
Both were written correctly by the vault run that exposed this, so no information is lost today if the comment goes away.

PRECEDENT FOR THE RESOLUTION SHAPE: commands/todo.md Step 5.6.2 already documents this same overwrite property as the reason repository_health lives in state.json only and is deliberately NOT mirrored into TODO.md frontmatter. Whatever is decided here should be consistent with that existing, already-reasoned stance.

WORK -- evaluate these and pick one, recording the reasoning:
  (a) Delete the step from both live sites and rely on vault_history + meta.json. Matches the recorded decision, removes machinery, loses the at-a-glance signal in TODO.md.
  (b) Render the transition line from state.json .vault_history inside generate-todo.sh, so it is generated rather than hand-inserted and therefore survives every regeneration. Keeps a user-visible signal; costs a new rendering branch and a test.
  (c) Make generate-todo.sh preserve hand-authored comments across regeneration. Note that this contradicts the deliberate full-overwrite, atomic mktemp+mv design and would reintroduce read-modify-write; if rejected, say so rather than leaving it unconsidered.
Whichever is chosen, no live document may be left instructing a caller to hand-edit TODO.md for vault transitions.

ALSO IN SCOPE (adjacent, cheap, same section): commands/todo.md's vault section is headed "5.7. Vault Operation" while all nine of its substeps are numbered 5.8.1 through 5.8.9. Reconcile the numbering so a reader following a cross-reference to "Step 5.7" finds substeps that match.

SCOPE DECISIONS REQUIRED (state each explicitly, do not silently skip):
  - agent-system/extensions/core/scripts/deprecated/vault-operation.sh:242 carries the same comment logic but is quarantined under deprecated/. Confirm it stays untouched rather than "fixed".
  - Five .opencode/** copies carry the same instruction (.opencode/commands/todo.md, .opencode/extensions/core/commands/todo.md, .opencode/skills/skill-todo/SKILL.md, .opencode/extensions/core/skills/skill-todo/SKILL.md, .opencode/scripts/vault-operation.sh). .opencode/ has no agent-system source and is separately tracked, and separate work already covers opencode drift. Decide whether these are updated here or deferred there, and record which -- leaving five unlabeled copies of a known-broken instruction is not an acceptable outcome.

ACCEPTANCE: a vault operation followed immediately by a TODO.md regeneration leaves the file in the intended end state -- either no transition comment at all with the durable records present, or a comment that regeneration reproduces identically. specs/TODO.md's frontmatter must still parse as a closed, valid YAML block afterward; demonstrate this by parsing it, not by eyeballing. Grep the live (non-deprecated) source store for the transition-comment string and report the surviving count with justification for each survivor.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

FILE OVERLAP: separately-tracked work on the repository-metrics sync ordering also edits agent-system/extensions/core/commands/todo.md. Neither task depends on the other, but they touch the same file and should not run concurrently without re-reading it.

---

### 20. Metrics sync measures a stale git index, inflating build_errors with phantom paths
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: /todo's repository-metrics sync runs before its git commit, so the health probe measures a tree whose git index still points at pre-move paths. Every archived-away file is counted as a structural failure, inflating build_errors and flipping status to "critical" on a healthy tree.

MEASURED EVIDENCE (live /todo run archiving 20 tasks, this is not inherited): Step 5.6 reported
    {"todo_count":44,"fixme_count":2,"build_errors":89,"status":"critical"}
Re-running the identical probe after the commit reported build_errors: 1. Of the 89, 88 were phantom and exactly 1 was real (a duplicated case pattern in .opencode/scripts/execute-command.sh, fixed separately; the probe then reported build_errors: 0, status "healthy"). So the reported figure was wrong by 88 and the derived status was wrong outright.

CONFIRMED ROOT CAUSE (two independent contributing defects, both must be addressed):

(1) The probe counts paths that no longer exist. assess-repo-health.sh's enumerate_by_glob builds candidates from `git ls-files -z -- "$glob"` and emits "$ROOT/$rel" with no existence check. Both structural loops then guard only emptiness, not existence:
        for f in "${SH_FILES[@]}"; do
          [ -n "$f" ] || continue
          if ! bash -n "$f" >/dev/null 2>&1; then errors=$((errors + 1)); fi
A path present in the index but absent on disk fails `bash -n` / `jq empty` for the trivial reason that there is no file to parse, and is scored as a structural error. This is caller-independent: any uncommitted rename, delete, or move produces the same inflation, so the probe is wrong on its own terms and not merely mis-sequenced. total_candidates is also inflated by the same phantom paths, which perturbs the degenerate zero-candidate branch that emits build_errors: null.

(2) /todo sequences the probe against exactly the tree state that triggers (1). commands/todo.md places Step 5.6 (Sync Repository Metrics, calling assess-repo-health.sh at the documented line) after Step 5D's directory moves and Step 5.7's vault operation, but before Step 6's `git add specs/` + commit. The one caller most likely to have just moved hundreds of files measures before recording them.

WORK:
  1. Make the probe existence-safe: skip candidates that are not present on disk, and exclude them from total_candidates so the null/"unknown" branch stays meaningful. Decide explicitly whether a phantom path should be silently skipped or surfaced as a separate diagnostic field (an index/worktree divergence is itself a signal worth reporting); state the decision and its reasoning.
  2. Re-sequence /todo so the metrics sync reflects the tree it actually commits. Either move Step 5.6 after Step 6, or have Step 6 re-sync afterward. Do not rely on fix 1 alone to paper over the ordering: fix 1 stops the false inflation, but a pre-commit measurement still describes a tree that is about to change.
  3. Check for other callers of assess-repo-health.sh with the same pre-commit exposure and note whether each is affected.

ACCEPTANCE: a /todo run that archives at least one task with a directory reports the same build_errors and status as an identical probe run immediately after its commit, and both match the true count for the tree. Demonstrate both directions -- a genuinely broken file must still be counted (a probe that can only ever report zero is not a fix), and a large batch of moved-but-uncommitted files must contribute zero. Report the measured before/after counts explicitly; never an unqualified green.

REGRESSION LOCK: add a test that stages nothing, moves a tracked *.sh or *.json to a new path, runs the probe, and asserts the moved file contributes no error. Without this the defect silently returns on the next refactor of enumerate_by_glob.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 19. Fix opencode agent-fragment path resolution and validator fail-fast
- **Effort**: 3h
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Reloading extensions in a consuming repo emits roughly 60 lines of "Extension '<name>' opencode-agents.json validation failed: Agent '<agent>' references missing file: <path>. Skipping fragment." The resync otherwise succeeds and the Claude Code deploy is correct and complete, so nothing the user relies on today is broken. .opencode/ is NOT currently in use, though the user intends to return to it. Priority is therefore low: the present cost is misleading reload noise, and the real cost is latent, namely that whenever OpenCode is picked back up, 18 agents will be silently missing behind noise that has already been trained into background.

MEASURED EVIDENCE (do not re-derive). In a repo with 12 active extensions, the generated opencode.json contains 15 agents and 18 are dropped: lean 2, python 2, nix 2, filetypes 7, present 5. lua/neotex/plugins/ai/shared/extensions/merge.lua:886 validate_opencode_fragment resolves each agent's {file:PATH} prompt against project_dir and returns false on the FIRST unreadable path, so generate_opencode_json discards the ENTIRE fragment.

ROOT CAUSE 1 - the referenced directory is deployed by nothing. Ten of twelve fragments use {file:.opencode/agent/subagents/<agent>.md}. A grep of the whole lua/ tree for "opencode/agent" returns exactly one hit and it is a test fixture (commands/picker/operations/sync_spec.lua:100). No deploy, install, or resync path populates .opencode/agent/subagents/ at all. The 16 files present in the consuming repo are unmaintained legacy artifacts predating the current manifest-driven engine. latex (2/2), typst (2/2), and formal (4/4) validate only by accident because their agent files happen to be among those 16 leftovers; python, nix, filetypes, and present reference correctly-named files that were simply never deployed.

ROOT CAUSE 2 - lean uses a third convention, also wrong. agent-system/extensions/lean/opencode-agents.json uses {file:.claude/extensions/lean/agents/<agent>.md}, a directory that does not exist in the deployed tree. Those files are present both at the standard .opencode/agent/subagents/ path and at .claude/agents/. Pure path bug.

ROOT CAUSE 3 - present references an agent that exists nowhere. agent-system/extensions/present/opencode-agents.json declares an agent keyed "slides" pointing at slides-agent.md. No slides-agent.md exists anywhere under agent-system/extensions/; the real file is agent-system/extensions/present/agents/slides-research-agent.md. Stale name after a rename. timeline-agent.md in the same fragment DOES exist in source - do not flag it.

AMPLIFIER. Fail-fast-on-first-miss silently discards a whole fragment for one bad reference, which is why present loses all 5 agents. Lua pairs() ordering is nondeterministic, so each validation pass names a different arbitrary agent, making the reload output look inconsistent and repetitive across passes while never revealing the true count. The task must decide whether the validator changes to report ALL missing references per fragment.

DECISION REQUIRED - evaluate explicitly, do not treat any as pre-chosen: (a) repoint every fragment's {file:...} at .claude/agents/<agent>.md; (b) add a deploy step that populates .opencode/agent/subagents/; (c) gate opencode fragment processing off entirely while .opencode/ is dormant, so the noise stops without committing to a path convention that may be revisited when OpenCode returns; (d) some combination. Option (a) is the scouted recommendation but is not a fait accompli: .claude/agents/ IS deployed and maintained by the current engine and contains all 48 agents including every one currently reported missing (verified individually for python-implementation, nix-research, filetypes-router, funds, lean-implementation, slides-research, timeline), so repointing fixes all three root causes with no new deploy step and no duplicated copies. Option (c) is live precisely because .opencode/ is dormant. Whatever is chosen must handle the present/slides stale name and must state a verdict on the validator's fail-fast behavior.

CONSTRAINT. Do NOT delete .opencode/ or its fragments - the user intends to return to OpenCode.

ACCEPTANCE. A reload in a consuming repo with 12 active extensions produces no opencode fragment validation errors; the chosen approach is stated with its rationale against the rejected alternatives; the present/slides stale reference is resolved; and the validator's fail-fast-vs-report-all behavior has an explicit recorded decision.

SOURCE-STORE RULE (binding): edit agent-system/extensions/** and lua/**, never .claude/** or .opencode/**, which are disposable deploy artifacts.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 18. Detect stale .claude/ deploy trees and root-cause the silent staleness
- **Effort**: 5h
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: A repo can carry an arbitrarily stale .claude/ deploy with no signal, so a user hits a bug fixed upstream long ago with no indication that regeneration is the remedy. Discovered when /revise failed at GATE IN in a consuming repo on a task that had never produced an artifact.

WHAT IS NOT THE DEFECT (ruled out, do not re-litigate): resolve_task_dir is not broken in source. agent-system/extensions/core/scripts/task-lock.sh's resolve_task_dir (line 249) takes a create_mode parameter and mkdir -p's when it is "create"; cmd_acquire (line 607) passes "create". The failure exists only in the deployed copy.

MEASURED STALENESS EVIDENCE (live, this investigation): the consuming repo's .claude/scripts/task-lock.sh is 676 lines against a 1660-line source, with a deployed resolve_task_dir at line 98 taking no create_mode. Its .claude/scripts/ holds 94 scripts against core's 72 in source. Neither verify-deploy.sh nor deploy-headless.sh is present in the deployed tree at all. This is despite a large sync commit landing recently.

BOOTSTRAP HYPOTHESIS RULED OUT: deploy-headless.sh's header documents a failure mode where a repo deployed by the retired glob-based engine has no "core" entry in .claude-extensions.json, so manager.resync_all silently deploys nothing. That is NOT this case. The repo's .claude-extensions.json lists core with status "active" and 294 recorded installed_files, including .claude/scripts/task-lock.sh. The loader believes it owns and has installed the very file that is stale. Root cause is unknown and is a genuine investigation, not a known-issue application.

WORK, in order. (1) Determine WHY the deploy is stale despite core being active and the file being listed in installed_files. Hypotheses to test, not assume: the copy step skips existing destination files instead of overwriting; installed_files is treated as authoritative and short-circuits re-copy; resync only re-copies files whose manifest entry changed; or a later partial operation reverted the tree. If the cause is a loader defect, report and fix it as such. (2) Then design and implement staleness DETECTION on a path users actually hit. Note that verify-deploy.sh already performs source-vs-deploy comparison but is not itself deployed and is invoked only from skill-orchestrate's inter-cycle redeploy checkpoint, so no ordinary command surfaces its result. Directions to evaluate, do NOT pre-commit: stamp a source revision or content hash into the deployed tree at load time and have command gate scripts compare against the source store, warning on drift; extend /refresh or a doctor check to diff deployed script versions against source; or have the loader record a per-file hash manifest a preflight can validate cheaply. Whatever is chosen must be cheap enough for a normal command preflight.

INTERACTION WITH SIBLING TASK 9: 9's evidence (4 orphan files present in .claude/ but absent from a clean scratch regenerate) was measured against this same stale deploy tree, so it may be an artifact of the staleness rather than a genuine one-directional-parity gap. 9 is sequenced after this task and must re-measure against a freshly regenerated tree. Both tasks also edit verify-deploy.sh.

ACCEPTANCE: the root cause is identified and stated, with the loader defect fixed if that is the cause; a user running an ordinary command against a stale deploy receives an actionable warning naming regeneration as the remedy; demonstrated in both directions, where a stale tree warns and a fresh tree does not.

SOURCE-STORE RULE (binding): edit agent-system/extensions/** and lua/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 17. Fix .return-meta.json lifecycle ordering that makes the gate-out body unreachable
- **Effort**: 4h
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: command-gate-out.sh's entire post-metadata body is structurally unreachable on all five commands that call it, because the skill-internal postflight always deletes the metadata first. The misleading warning is the visible symptom; the dead defensive status correction and the dead artifact validation are the actual damage.

VERIFIED MECHANISM (do not re-derive): skill-base.sh's skill_cleanup (lines 618-625) rm -f's .postflight-pending, .postflight-loop-guard, AND .return-meta.json. It is the single shared implementation invoked from Stage 9 of context/patterns/skill-postflight-flow.md, used by NINE skills: skill-implementer, skill-implementer-hard, skill-planner, skill-planner-hard, skill-reviser, skill-spawn, skill-team-implement, skill-team-plan, skill-team-research. command-gate-out.sh lines 69-73 then read "${task_dir}/.return-meta.json"; on absence it prints "WARNING: .return-meta.json not found ... skill may have failed silently" and exit 0. FIVE commands run it: implement.md, orchestrate.md, plan.md, research.md, revise.md.

BLAST RADIUS IS LARGER THAN THE WARNING (measured, not inherited): the exit 0 at line 73 sits ABOVE everything else in the 134-line script. Code rendered unreachable in practice includes (a) the defensive status correction that repairs state.json when a skill reported completion but state is stale, and (b) the skill_validate_task_artifacts call at line 133, the last line, which is the artifact validation and --fix auto-repair path. One missing file disables both correctness mechanisms on all five commands. A real silent failure and an ordinary success emit the identical warning, so the signal carries no information.

CONSEQUENCE FOR SIBLING TASK 13: 13's acceptance criterion (a task whose artifact required auto-repair produces a gate-out report naming a nonzero repaired-field count) cannot be demonstrated until this ordering defect is fixed, because the path it instruments never executes. 13 is sequenced after this task; both also edit the same two files.

WORK: decide ONE direction and implement it. (a) run the command-level gate-out before skill cleanup; (b) have skill_cleanup preserve .return-meta.json and make gate-out delete it after consuming it; (c) have skill_cleanup archive the metadata to a location gate-out knows about; (d) if the skill-internal postflight genuinely subsumes both defensive correction and artifact validation, delete the dead reads and replace the warning with a truthful statement. Required regardless of direction: explicitly decide whether defensive status correction is still needed given skill-internal postflight and record the reasoning; and fix the warning text so a genuine silent failure is distinguishable from ordinary success.

UNIFORMITY REQUIREMENT: whatever is chosen must hold across all nine skills and all five commands. A fix that repairs skill-reviser and /revise alone is not acceptable.

ACCEPTANCE: a normal successful run of each of the five commands emits no false silent-failure warning; a genuinely failed skill run emits a distinguishable warning; and the defensive-correction path is demonstrated to execute, or is documented as deliberately removed with stated reasoning.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 16. Fix command register acquire session id parity
- **Status**: [IMPLEMENTING]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: None
- **Research**: [016_fix_command_register_acquire_session_id_parity/reports/01_register-acquire-session-id-parity.md]
- **Plan**: [016_fix_command_register_acquire_session_id_parity/plans/01_register-acquire-parity-fix.md]
- **Summary**: [016_fix_command_register_acquire_session_id_parity/summaries/01_register-acquire-parity-fix-summary.md]

**Description**: Fix the register-bare/acquire-suffixed session-id pattern in the research.md, plan.md, and implement.md command files.

TARGET: agent-system/extensions/core/commands/research.md, agent-system/extensions/core/commands/plan.md, agent-system/extensions/core/commands/implement.md.

CONTEXT: skill-orchestrate/SKILL.md carried a defect where the in-flight session registry was registered under the bare session_id but the per-task lock was acquired and released under a task-suffixed variant. Because the session-contention self-exclusion is an exact string match, the batch never recognized its own registration and every acquire aborted deterministically. That defect was fixed in skill-orchestrate, and the fix recorded that these three multi-task command files exhibit the structurally identical register-bare/acquire-suffixed pattern and are likely to carry the same latent bug.

WORK: verify whether each of the three command files actually reproduces the defect (the registration site, the acquire/release sites, and any dispatch context whose session_id feeds a downstream task-lock heartbeat call). Unify the session-id used across register/acquire/release/heartbeat in each file that is affected. Extend the existing register/acquire parity regression coverage to cover these consumers rather than adding a parallel test harness.

REFERENCE: the parity invariant is stated in agent-system/extensions/core/context/patterns/task-lock.md (Consumers section); the existing regression group lives in agent-system/extensions/core/scripts/test-conflict-predicate.sh.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 14. Prevent implementation-agent fan-out from returning non-terminal status and stale plan markers
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Two dispatches in a single batch fanned out to phase sub-agents and terminated before writing a terminal status, costing a recovery cycle each. Recorded as err_1786344051474_RcIhk6.

OBSERVED FAILURE MODE: a dispatched implementation agent spawned per-phase sub-agents, returned while they were still running, and left .return-meta.json at status=in_progress. Per context/formats/return-metadata-file.md that value is early-metadata-only and never a legal terminal dispatch outcome, so orchestrate-recover-outcome.sh correctly declines it (reason STATUS_IN_PROGRESS). The orchestrator contract for an unresolvable dispatch is failed_tasks - which would have been WRONG here, since 6 of 10 phases had in fact been committed. Correct handling came from rules/error-handling.md Delegation Interrupted Recovery (keep status, resume), not from the orchestrator stage contract.

COMPOUNDING DEFECT - STALE PLAN MARKERS: the sub-agents committed phases 3, 4, 5 and 7 but left every one of those phase markers reading [NOT STARTED]. Because the orchestrator phase-marker recovery grep reads exactly those markers, it would have reported 2/10 against a true 6/10. A resume driven by markers alone would have redone committed work. Recovery only succeeded because the actual state was reconstructed from git log and diffs instead.

TWO INDEPENDENT QUESTIONS, BOTH IN SCOPE:
  1. Should a dispatched implementation agent fan out to sub-agents at all? If yes, it must still write a terminal status covering its childrens work; if no, the prohibition belongs in the agent contract, not in per-dispatch prompt text (the workaround used during the incident).
  2. Should a sub-agent that commits a phase be required to update that phases marker in the same commit? Markers and commits diverging silently is the deeper defect - it degrades the recovery path for every future interrupted dispatch, not just fan-out ones.

CONSIDER ALSO: whether the orchestrator should treat status=in_progress plus evidence of committed phase work as PARTIAL/resume rather than routing it toward failed_tasks, so correct handling does not depend on an operator noticing.

ACCEPTANCE: an interrupted fan-out dispatch is either impossible by contract, or leaves markers and terminal status accurate enough that resume needs no manual git archaeology.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 13. Instrument gate-out auto-repair reporting; stop silent in-place artifact mutation
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 17

**Description**: The acceptance criterion "gate-out reports zero format errors and zero auto-repaired fields" is unverifiable as written, because no reporting surface exists. Recorded as err_1786350581339_Q4VnFy.

TRACED PATH: command-gate-out.sh (134 lines) has no counter, aggregate, or exit-code surface for auto-repairs; its only related line is a comment. The real repair path is
    command-gate-out.sh -> skill_validate_task_artifacts (skill-base.sh) -> validate-artifact.sh "$f" "$type" --fix 2>/dev/null
validate-artifact.sh DOES emit a terminal line of the form "[FIXED] N field(s) auto-repaired, E error(s), W warning(s) remaining" and exits 2. But skill_validate_task_artifacts discards stderr, collapses every non-zero exit into a single generic non-blocking WARNING carrying no numeric detail, and always returns 0. command-gate-out.sh therefore receives no signal at all.

PRIMARY HAZARD (the reason this is not merely cosmetic): --fix MUTATES THE ARTIFACT IN PLACE. A repair both happens and goes uncounted, so an artifact can be silently rewritten with nothing anywhere recording that it was. The instrumentation gap and the silent-mutation hazard are the same defect seen from two ends.

WORK:
  1. Propagate validate-artifact.sh fix/error/warning counts through skill_validate_task_artifacts instead of discarding them.
  2. Give command-gate-out.sh a reportable surface for those counts.
  3. Decide explicitly whether --fix should remain in-place-mutating on the gate-out path, or whether a repair should be reported and left for a human. State the decision and its reasoning.

ACCEPTANCE: a task whose artifact required auto-repair produces a gate-out report naming a nonzero repaired-field count, and a task needing none reports zero. Both directions must be demonstrated - a report that can only ever say zero is not instrumentation.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 12. Fix run-all.sh deployed-mode failures: REPO_ROOT depth derivation and 6 further suites
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [012_fix_test_suite_deployed_mode_failures/reports/01_run-all-deployed-mode-triage.md]
- **Plan**: [012_fix_test_suite_deployed_mode_failures/plans/02_gate8-and-verify-deploy-closeout.md]
- **Summary**: [012_fix_test_suite_deployed_mode_failures/summaries/02_gate8-and-verify-deploy-closeout-summary.md]

**Description**: tests/run-all.sh is red and has been treated as permanently-expected background noise, which is how a real regression would hide. This task makes it green or documents each residual failure.

MEASURED EVIDENCE (live run, not inherited): 25 passed, 8 FAILED, 0 skipped, 33 total. Earlier reports of a 5-suite REPO_ROOT count were NOT confirmed and should be treated as superseded by this measurement. Recorded as err_1786368358319_8jwcdo.

CONFIRMED ROOT CAUSE (2 of 8): test-skill-base-lifecycle.sh and test-update-task-status.sh both abort with
    ERROR: deployed scripts tree not found at /home/benjamin/.claude/scripts
proving REPO_ROOT resolved to $HOME instead of the repo root. Both derive it as:
    REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
Five levels up is correct from the SOURCE-STORE location agent-system/extensions/core/scripts/tests/, but wrong from the DEPLOYED location .claude/scripts/tests/, which is only three levels below the repo root. The same 5-level literal appears in at least test-corroborate-phase-counts.sh, test-errors-append.sh, test-handoff-reader-parity.sh, and test-index-entries-schema.sh, so the defect class is wider than the two suites that happen to fail loudly.

PROVEN-GOOD PATTERN ALREADY IN-TREE: test-deploy-propagation.sh derives it depth-independently:
    REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
    [ -z "$REPO_ROOT" ] && REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
Adopt this shape rather than inventing a new one.

UNCONFIRMED (6 of 8) - triage each individually, do NOT assume a shared cause:
  test-common-lib.sh (1 failure; overlaps the separately-tracked opencode session-id duplication finding)
  test-index-entries-schema.sh (8 passed, 1 failed)
  test-lint-state-writer-boundary.sh (7 passed, 1 failed)
  test-loop-guard-staleness.sh
  test-reconcile-handoff-status.sh
  test-resume-scan-nonconformance.sh

NOTABLE: test-lint-state-writer-boundary.sh is the suite added by the state-writer conversion work, which reported 8/8 green in source-store context but is 7/8 in deployed mode. Determine whether this is the same depth defect or a genuine gap in the new lint.

ACCEPTANCE: run-all.sh reports 0 failures, OR every residual failure has a written, evidenced justification. Report the count honestly; never an unqualified green.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.
=== SCOPE EXTENSION (folded in after gate-8 diagnosis; user-approved) ===

The Phase 6 residual is now diagnosed with captured evidence, and TWO items are folded into
this task rather than spawned separately.

(A) GATE-8 FLAKE -- ROOT CAUSE CONFIRMED, not a hypothesis. Measured 4/20 (20%) failures inside
verify-deploy.sh gate 8; 13/30 (43%) standalone on an idle machine; 25/30 (83%) in a mirror
copy. All four captured gate-8 failures are byte-identical apart from PID:
  [FAIL] is_live_inhibitor_target: still excludes the SAME inhibitor after its target
  (pid NNNNNNN) was killed -- tautological check
in agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh (assertion (c)).
Mechanism proven directly: kill -0 returns success for a killed-but-unreaped child; wait reaps
in 2ms. Failing runs averaged 141.5s vs 131.0s passing -- a 10.5s delta against the 8.0s poll
budget, i.e. every failure burns the full 40 x 0.2s loop.
  RULED OUT: task-lock.sh / holder.json TOCTOU. Zero occurrences across all 20 runs.
  CORRECTED ASSUMPTIONS: the flake is NOT load-sensitive (43% on an idle machine; CPU burners
  did not reproduce it). Widening the poll budget is DISPROVEN as a fix -- no finite budget
  helps a 43-83% failure, and the helper sometimes genuinely survives the kill, so widening
  only makes each failure slower. Two real-process repairs also failed under test: naive wait
  hung ~300s (the suite leaks a `sleep 300` helper inheriting stdout/stderr, so any reader
  using command substitution blocks for the full 300s -- one run measured 300022ms), and
  kill -9 + wait + detached streams killed the test script itself (RC=137, 20/20).
  REQUIRED FIX (injectable predicate, not budget widening): extract the bare
  kill -0 "$target_pid" in agent-system/extensions/core/scripts/claude-refresh.sh's
  is_live_inhibitor_target (lines ~138-149) into an overridable seam (e.g. _pid_is_alive), and
  replace lines ~112-145 of test-claude-refresh-matcher.sh (helper at 112, kill at 123, poll
  loop at 135-138, failing assertion at 140-144) with a scripted probe. Keep the "alive"
  direction as-is (deterministic; no reaping involved). This preserves the argv-parsing
  coverage the assertion exists to protect. NOTE: it does weaken the file's documented
  "driven by a REAL process" intent (line ~15) -- record that trade-off in the replacement
  comment rather than leaving it silent.

(B) STANDING VERIFY-DEPLOY FAILURES -- verify-deploy.sh exited non-zero on 20/20 runs
INDEPENDENT of gate 8, so fixing gate 8 alone will NOT turn it green. Phase 6's acceptance
criterion cannot be met without these:
  - Deploy drift (gates 3 and 5): agent-system/extensions/core/scripts/system-defect-record.sh
    (source 354 lines / deployed 352) and
    agent-system/extensions/core/context/patterns/system-defect-discrimination.md
    (source 397 / deployed 382). Source is AHEAD of deploy; a deploy-headless.sh run resolves
    both.
  - line_count mismatch (gate 3, Rule R): agent-system/extensions/core/index-entries.json
    (~line 1034) declares line_count 382 for patterns/system-defect-discrimination.md; the
    actual file is 397 lines. generate-context-line-counts.sh --write is the sanctioned fixer.
  - Dangling dependency (gate 10): specs/state.json task 9 carries dependencies [1015, 18].
    1015 exists in NEITHER active_projects NOR the archive, and neither does 15 -- it is a
    vault-renumbering leftover (renumbering subtracted 1000 from project_number values but did
    not rewrite dependencies arrays). Removing the dead 1015 entry is the honest fix; do not
    invent a replacement target.

ACCEPTANCE (revised): verify-deploy.sh reports 0 findings across a repeated sample (not a
single lucky run -- the flake was 20% inside gate 8, so a single green run is not evidence),
OR every residual failure carries a written, evidenced justification. Report counts honestly;
never an unqualified green.

---

### 11. Expand defect class vocabulary
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [011_expand_defect_class_vocabulary/reports/01_defect-class-vocabulary-gap.md]
- **Plan**: [011_expand_defect_class_vocabulary/plans/01_defect-class-vocabulary-expansion.md]
- **Summary**: [011_expand_defect_class_vocabulary/summaries/01_defect-class-vocabulary-expansion-summary.md]

**Description**: The system-defect vocabulary has a gap: defect classes exist for a narrow set of shapes, but at least three concrete instances from this batch do not fit cleanly into any existing defect_class value. Recorded as err_1786349061588_fqHbUZ, severity medium. Three concrete instances now ground the gap, confirmed by the capstone acceptance gate dispatch: lock/session contention (err_1786349061524_pY97cE, MT-1/MT-4 session-id mismatch), hook-regex/path-depth boundary defects (err_1786349061492_XpY38x, the 3-digit handoff-location regex), and deploy orphan-file drift (err_1786349061556_LuKGif / err_1786350581273_TAWj0I).

TARGET: wherever defect_class is enumerated for system-defect-record.sh (search the source store for its schema/enum definition) and any consumer that switches on defect_class value.

WORK: read the current defect_class enum, confirm the three instances above genuinely lack a fitting class (do not add classes for shapes that already have one), and add the minimum set of new classes needed to name them precisely -- for example a session/lock-contention class, a regex/path-boundary class, and an orphan-drift class. Update any documentation enumerating the vocabulary. Do not rename or remove existing classes as part of this task.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

CONSTRAINT: do not drive this task with multi-task /orchestrate until err_1786349061524_pY97cE (the MT-1/MT-4 session-id mismatch, spawned as a sibling task) is fixed -- multi-task orchestration is documented-broken until that lands. Use single-task /orchestrate or /implement.

---

### 9. Resolve deploy orphan file parity
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 18

**Description**: Declared-vs-deployed parity for provides.* categories is one-directional by design, and the live .claude/ tree carries 4 orphan files absent from a clean scratch regenerate: context/orchestration/orchestration-validation.md, context/orchestration/subagent-validation.md, docs/architecture/architecture-spec.md, docs/README.md. Two of these (docs/architecture/architecture-spec.md, docs/README.md) were not covered by the pre-existing err_1786349061556_LuKGif (deploy_ghost_index_entries), which only named the other two -- confirmed and extended by err_1786350581273_TAWj0I (deploy_orphan_files_undercounted). This task covers BOTH error ids with one decision; do not split it.

MECHANICAL REASON (already diagnosed, do not re-derive): verify.lua's result shape has no extra/orphan field and only ever iterates the declared side; install-extension.sh's merge_index_entries() is purely additive with no stale-removal step. Parity is therefore verified only in the declared-to-deployed direction, never the reverse.

TARGET: agent-system/extensions/core/scripts/verify-deploy.sh (or the shared verify.lua module it calls), and/or docs/architecture/architecture-spec.md if the decision is to document one-directional parity as intended rather than build detection.

WORK: decide ONE of two directions and implement it -- (a) add a subtractive/orphan-detection pass to verify.lua or verify-deploy.sh that flags live files present in .claude/ but absent from a clean regenerate of every provides.* category, so future orphan drift is caught mechanically; or (b) explicitly document in docs/architecture/architecture-spec.md that provides.* parity is one-directional by design (additive only, no stale-removal), so a future reader does not mistake the current behavior for an oversight. Resolve the 4 currently-orphaned files as part of whichever direction is chosen: either they get removed/reconciled (direction a) or explicitly enumerated as accepted legacy orphans in the documentation (direction b).

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

CONSTRAINT: do not drive this task with multi-task /orchestrate until err_1786349061524_pY97cE (the MT-1/MT-4 session-id mismatch, spawned as a sibling task) is fixed -- multi-task orchestration is documented-broken until that lands. Use single-task /orchestrate or /implement.

STALENESS CAVEAT (added after the deploy-staleness finding): the orphan-file measurement above (4 files present in .claude/ but absent from a clean scratch regenerate) was taken against a deploy tree since shown to be badly stale -- its task-lock.sh was 676 lines against a 1660-line source. That measurement may therefore be an artifact of the staleness rather than evidence of a one-directional parity gap. Re-take the measurement against a freshly regenerated tree before treating it as evidence, and revise the direction (a)/(b) decision if the orphan set changes. Depends on task 18, which diagnoses the staleness root cause.

---

### 6. Nothing prevents an agent from rewriting state.json .artifacts wholesale, silently discarding prior artifacts
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 5
- **Research**: [006_guard_against_nonadditive_artifact_rewrites/reports/01_guard-nonadditive-artifact-rewrites.md]
- **Plan**: [006_guard_against_nonadditive_artifact_rewrites/plans/01_guard-nonadditive-artifact-rewrites.md]
- **Summary**: [006_guard_against_nonadditive_artifact_rewrites/summaries/01_guard-nonadditive-artifact-rewrites-summary.md]

**Description**: The artifact list in specs/state.json is append-only by intent but not by enforcement. Every
sanctioned write path is additive, yet an agent that writes state.json directly can replace the
whole array, and nothing detects the loss.

SANCTIONED PATHS ARE ALREADY CORRECT (do not change them):
  - agent-system/extensions/core/scripts/orchestrator-postflight.sh:432 uses `.artifacts += [...]`
  - agent-system/extensions/core/scripts/reconcile-task-status.sh:172 (link_artifact) likewise
  - skill_link_artifacts in skill-base.sh routes through state-write.sh

THE GAP: these are helpers an agent MAY use, not a constraint it MUST satisfy. An implementation
agent updating state.json with its own jq assignment (`.artifacts = [...]`) bypasses all of them.
Nothing validates that the post-write artifact set is a superset of the pre-write set.

OBSERVED, WITH LOSS: during a real implementation dispatch, an agent updated its task's state.json
entry and the artifact list went from 11 entries to 8 -- five previously-recorded phase summaries
were dropped while two new entries were added. The summary FILES were still on disk; only the
links were destroyed, so nothing failed and no warning was emitted. The loss was caught only by a
manual count during postflight review and repaired by hand. Had it not been noticed, the task
would have archived with five phase summaries permanently unreferenced.

RELATIONSHIP TO THE STATE-WRITE CONVERSION TASK (adjacent, NOT duplicate -- read before starting):
the existing state-write conversion work targets hand-rolled read-modify-write sequences in the
SOURCE STORE, and its verification bar is a grep for `mv` onto state.json across source files.
That bar cannot catch this defect: the offending write came from an AGENT at runtime composing jq
inline, not from any checked-in script. Converting every source-store writer to state-write.sh
leaves this hole exactly as open. If the two are worked together, the deliverable here is the
superset-invariant, not another writer conversion.

WORK:
  1. Add a machine-checkable invariant: for any write touching .artifacts, the resulting set must
     contain every path present beforehand. Removal must require an explicit, named opt-in
     (legitimate cases exist -- a genuinely deleted artifact -- and must remain expressible).
  2. Enforce it where writes actually funnel. state-write.sh is the natural choke point; decide
     whether the invariant lives there (catches everything routed through it) or in
     validate-state.sh (catches drift regardless of writer, including direct jq). Prefer the
     option that ALSO catches a direct jq write, since that is the observed failure mode --
     enforcing only inside state-write.sh would miss the exact case that motivated this task.
  3. State the append-only rule explicitly in rules/state-management.md, which currently
     describes artifact linking formats without ever saying the list is append-only.
  4. Add a MUST NOT to the implementation agents that write state.json directly: never assign
     .artifacts wholesale; append, or call the helper.

VERIFICATION BAR:
  - A fixture write that drops an existing artifact path is REJECTED (or loudly flagged by the
    validator), and the same write with the opt-in flag is accepted. Both directions executed.
  - A normal additive link still succeeds unchanged; existing link_artifact / skill_link_artifacts
    call sites are unaffected.
  - The check triggers on a direct jq-composed write, not only on state-write.sh traffic.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 5. roadmap_items is never derived by any implement path, so /todo's ROADMAP sync is dead in practice
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [005_implement_roadmap_items_producer/reports/01_roadmap-items-producer.md]
- **Plan**: [005_implement_roadmap_items_producer/plans/01_roadmap-items-producer.md]
- **Summary**: [005_implement_roadmap_items_producer/summaries/01_roadmap-items-producer-summary.md]

**Description**: /todo documents a producer/consumer contract for ROADMAP.md synchronisation in which /implement
is the producer. The consumer half is fully built; the producer half computes nothing, so the
feature has never functioned.

WHAT EXISTS (the consumer and the write path -- both fine, do not rebuild):
  - agent-system/extensions/core/commands/todo.md:1122 states the contract explicitly:
    "/implement is the **producer**: populates completion_summary and optional roadmap_items".
  - todo.md's Step 3.5 matcher implements a three-priority strategy: (1) explicit roadmap_items,
    (2) exact `(Task N)` references in ROADMAP.md, (3) summary-based search.
  - skill_propagate_completion_summary (agent-system/extensions/core/scripts/skill-base.sh:526-551)
    WRITES roadmap_items to state.json correctly when handed a non-empty value, routed through
    state-write.sh, correctly skipping task_type == "meta" and empty/`[]` values.

WHAT IS MISSING: nothing anywhere DERIVES the value passed as that third argument. Grep of the
full source store finds write sites and schema references but no derivation logic. So the helper
is called with an empty value and the write is skipped every time.

CONSEQUENCE, MEASURED: on a real archival run, 24 consecutive completed tasks were archived and
produced ZERO roadmap annotations, while 8 unchecked items sat in ROADMAP.md -- several plainly
related to the work just completed. All three matcher priorities missed:
  - Priority 1 found no task carrying a roadmap_items field (none has ever been populated).
  - Priority 2 found no `(Task N)` references, because ROADMAP.md contains none -- and per the
    repo's own no-task-references-in-deliverables rule, ROADMAP.md arguably should not contain
    them, which makes Priority 2 structurally unreliable rather than merely unused.
  - Priority 3 is an explicit unimplemented placeholder in todo.md ("not currently implemented").
So the roadmap silently drifts from reality, and the drift is invisible: /todo reports success
with "0 roadmap items updated" and no warning that its only functioning matcher found nothing.

WORK:
  1. Decide where derivation belongs and state why. Candidates: the implementation agent proposes
     roadmap_items in its return metadata (agent judgement, no new matching machinery); or a
     script matches completion_summary against ROADMAP.md text at postflight (deterministic,
     testable, but needs a matching heuristic that Priority 3 was never given).
     Prefer the option that does not invent a fuzzy matcher -- an agent naming which roadmap
     items its work closed is both cheaper and more accurate than post-hoc string similarity.
  2. Implement derivation on the chosen path and thread it into the EXISTING
     skill_propagate_completion_summary call sites. Do not add a second write path.
  3. Make an empty result visible rather than silent: when /todo archives non-meta tasks and
     matches zero roadmap items, it must say so distinctly from "there was nothing to match".
     A silent 0 is what allowed this to go unnoticed across 24 tasks.
  4. Either implement Priority 3 or delete it. A documented placeholder that reads as a working
     tier is worse than an honest two-tier matcher.
  5. Reconcile Priority 2 with the no-task-references-in-deliverables rule. If `(Task N)` markers
     are not permitted in ROADMAP.md, say so in todo.md and stop presenting Priority 2 as a
     general mechanism.

VERIFICATION BAR:
  - A completed non-meta task with a roadmap-related completion_summary produces a populated
    roadmap_items in state.json, and a subsequent /todo run annotates the matching ROADMAP.md
    item. Demonstrated end to end on a fixture, not argued.
  - A task whose work matches no roadmap item produces an explicit "no match" report.
  - task_type == "meta" still writes no roadmap_items (existing behaviour preserved).

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.
