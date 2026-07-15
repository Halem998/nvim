# Research Report: Task #885

**Task**: 885 - Enable and verify passive signal capture
**Started**: 2026-07-15T00:00:00Z
**Completed**: 2026-07-15T00:00:00Z
**Effort**: Medium (source-store edits are small; the blocking question is feasibility, not code volume)
**Dependencies**: 874 (self-sync guard removal — CONFIRMED COMPLETE, commit dc6d5e450)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/**`, `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`, `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`), live `.claude/` deploy tree, live `check-extension-docs.sh` run, `~/.dotfiles/config/claude/settings.json`, `~/.claude/settings.json`, sibling reports 874 and 887, `code.claude.com/docs/en/settings`, `code.claude.com/docs/en/monitoring-usage`, GitHub issue anthropics/claude-code#23710
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The central feasibility question is settled: there is no safe headless bypass for the
  `<leader>al` regeneration, in nvim or in any other repo.** `M.load_all_globally()`
  (`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua:1175`) always calls
  `vim.fn.confirm(...)` (line 1266) after scanning artifacts, regardless of `project_dir ==
  global_dir` — the guard removed in the dependency task only removed a DIFFERENT, additional
  block that was specific to nvim's own self-sync case. The function that actually performs the
  copy, `execute_sync` (line 507), is a **module-local (non-exported) function** — there is no
  `M.execute_sync` or any other public entry point that bypasses the dialog. This means the
  interactive confirm has always been, and remains, a mandatory step for *every* repo's `<leader>al`
  regeneration, not something task 874 introduced or could have removed. See Findings for the exact
  manual keystroke sequence and the precise "what success looks like" checklist.
- **A large share of this task's scope is fully completable today, with zero dependency on the
  regeneration happening.** Verified via a live run of `check-extension-docs.sh`: the deployed
  `.claude/` tree currently shows `core: FAIL` (4 issues) even *before* any of this task's changes —
  `skill-base.sh` and `orchestrator-postflight.sh` are already flagged as **drifted** (not just
  missing), while `events-append.sh`/`events-query.sh` are silently **skipped** (info-level, not
  FAIL) because they don't exist in the deploy at all. This live result is direct, first-party
  evidence for scope item 6: the existing "hard gate" already *can* catch drift once a file exists
  in both places, but it structurally cannot catch "this file was never deployed at all" for scripts,
  and has **no check whatsoever** for `hooks/`, `context/schemas/`, `context/formats/`, or
  `root-files/settings.json` drift/completeness. Source-store edits to
  `check-extension-docs.sh` (scope 6), `events-append.sh`/`events-schema.json` (scope 5), and the
  four `|| true` call sites plus `events-log-lifecycle.sh`/`events-log-artifact.sh`'s six internal
  `|| true` sites (scope 2) are pure text edits to files already committed in
  `agent-system/extensions/core/`, verifiable today (the drift-check extension can literally be run
  against the live, still-stale `.claude/` tree to prove it now correctly flags the gap) — **and none
  of them require the regeneration to land or be reviewed.**
- **Scope items 3 (OTel env vars) and 4 (`cleanupPeriodDays`) both resolve to the SAME correct
  home, and it is NOT this repo.** Per `code.claude.com/docs/en/settings` (fetched): `env` block
  variables merge from any settings scope, but `cleanupPeriodDays` is described as governing
  "application-wide cleanup that runs at startup and affects all projects on the machine" — so
  setting it only in this repo's project-level `.claude/settings.json` (i.e.
  `agent-system/extensions/core/root-files/settings.json`, which IS in this task's `file_scope`)
  would protect transcripts only for sessions launched from this repo, not the ~15 other repos
  with their own `.claude/` trees (`~/.dotfiles`, `cslib`, `ModelChecker`, etc. — enumerated in
  Findings). Since the whole point of scope item 5 is *cross-repo* federation, the correct home for
  both settings is the **user-level** `~/.claude/settings.json`, which is confirmed
  Home-Manager-managed from `~/.dotfiles/config/claude/settings.json` (its own `_NOTE` field says
  so verbatim). **This task's `file_scope` listing `root-files/settings.json` does NOT mean scope
  items 3/4 belong there** — that file's `env` block currently holds only
  `SLASH_COMMAND_TOOL_CHAR_BUDGET`, a project-specific setting, and should stay that way. Per the
  binding constraint, this task does not edit `~/.dotfiles` directly; it settles the home
  and hands off the exact snippet.
- **The `cleanupPeriodDays: 0` claim is verified TRUE, with a stronger and more specific finding
  than the task description states.** GitHub issue anthropics/claude-code#23710 ("cleanupPeriodDays:
  0 silently disables all transcript persistence (docs say it disables cleanup)", filed 2026-02-06,
  fetched via web search) confirms: `cleanupPeriodDays: 0` doesn't merely fail to protect old
  transcripts — it stops **new** transcript `.jsonl` writes from happening at all, because a guard
  clause in the session-storage write path (`appendEntry`) treats `0` as "don't persist" rather than
  "never expire." The documented default is **30 days** (confirmed independently via
  `code.claude.com/docs/en/settings`), which matches this task's own framing exactly. The
  locally-committed template at `agent-system/extensions/core/templates/settings.json` (mirrored
  into `~/.dotfiles/.claude/templates/settings.json`) states a **stale/incorrect** "Default is 7
  days" — worth a one-line doc fix if that file is touched, though it is outside this task's
  `file_scope` and is dead documentation (nothing deploys or reads it; see Findings).
- **The sibling design (887, unfrozen) proposes `cwd` + `cc_session_id`, not a literal `repo`
  field; this task's own scope text says "`repo`... or resolve it from cwd."** These are
  compatible but not identical, and adopting 887's fuller design wholesale here would be exactly
  the kind of premature-freeze the delegation context warned against. Recommendation (for the plan
  to decide, not resolved here): add a single nullable `cwd` field now (same name, same hook-stdin
  source 887 already identified), and treat "repo" as **derived** from `cwd` at query time
  (`events-query.sh`) rather than stored as a second redundant field — this satisfies scope item
  5's federation need today without pre-committing to `cc_session_id`, which 887 flags as still
  awaiting user revision.

## Context & Scope

This is a research-only pass. No files were edited. The task's own scope text supplies 6 items;
this report resolves the delegation context's three explicit questions (a)/(b)/(c) about
regeneration feasibility and settles which of the 6 scope items are regeneration-gated versus
fully completable today, with concrete evidence for each. Findings for the schema/`repo` field
design defer to sibling report 887 rather than re-deriving it, per instruction.

## Findings

### Codebase Patterns

**`M.load_all_globally()` always requires an interactive confirm — this was never blocked by the
874 guard and is not fixed by removing it** (`sync.lua:1175-1399`, full function read):
- Line 1181: scans artifacts via `M.scan_all_artifacts(global_dir, project_dir, config)` — this is
  the function 874 modified with the `is_self_load` exclusion.
- Lines 1229-1238: early-returns with a notify-only message if there is nothing to sync (0 files)
  or everything is already in sync (0 copy + 0 replace) — neither early-return reaches `confirm()`,
  but neither performs a sync either.
- Line 1266: `local choice = vim.fn.confirm(message, buttons, default_choice)` — this line is
  **unconditional**, reached for both self-load and cross-repo load whenever there is at least one
  file to copy or replace. The two dialog variants:
  - When `total_replace > 0`: `"Load artifacts from global directory?\n\nNew: %d | Existing:
    %d\n\n1: Sync all (replace existing)\n2: Add new only\n3: Cancel"`, buttons `"&Sync all\n&New
    only\n&Cancel"`, **`default_choice = 3` (Cancel)**.
  - When `total_replace == 0`: `"...\n\n1: Add all\n2: Cancel"`, buttons `"&Add all\n&Cancel"`,
    `default_choice = 2` (Cancel).
  - In both variants the default is Cancel — an unattended/non-interactive invocation that somehow
    returned immediately (e.g. `vim.fn.confirm` returning 0 or the default on EOF/no-TTY) would
    resolve to **"Sync cancelled"**, not a silent success. This is a second reason a headless
    attempt is unsafe: it fails closed, but a caller not checking the return value could easily
    misread "0 (cancelled)" as "nothing to do."
- Line 1340: `execute_sync(project_dir, all_artifacts, merge_only, base_dir, protected_paths,
  global_dir)` is the function that actually copies files — declared `local function
  execute_sync(...)` at line 507, i.e. a closure-local upvalue, **never assigned to `M`**. It is
  reachable only from within `sync.lua` itself, after `merge_only` has been resolved from the
  `confirm()` return value. There is no lower-level Lua API, no CLI wrapper, and no
  `install-extension.sh`-style bash entry point for this specific "Load Core" batch-sync operation
  — `install-extension.sh` (referenced in the task description) is a **different** mechanism
  (per-extension manifest-driven symlinking, has zero interactive prompts, confirmed via full-file
  grep for `read `/`confirm`/`prompt`) that runs as part of *loading a new extension*, not as part
  of the "Load Core" full regeneration triggered by `<leader>al`'s "Load All" picker entry.
- The only caller of `M.load_all_globally` in the entire codebase is
  `lua/neotex/plugins/ai/claude/commands/picker/init.lua:112`, inside the Telescope picker's
  `actions.select_default:replace(...)` handler for the `is_load_all` special entry — i.e. it is
  wired exclusively to interactive UI selection, with no companion command, autocmd, or CLI
  entrypoint anywhere in `lua/`.

**Exact manual regeneration procedure (answers question (b) precisely)**:
1. Open Neovim with cwd at the target repo root (nvim itself, or any other repo such as
   `~/.dotfiles`).
2. Press `<leader>al` (normal mode) — opens the unified AI commands/agents picker
   (`ai-tool-picker.show_commands_picker()`, per `lua/neotex/config/keymaps.lua:24` and
   `which-key.lua:266`).
3. Select the "Load All" entry (the `is_load_all` special row at the top of the picker list) and
   press Enter.
4. A `vim.fn.confirm()` dialog appears. **Select "Sync all (replace existing)"** (button 1 / the
   `&Sync all` accelerator) — not the default. Selecting "Add new only" (button 2) would add the
   never-before-deployed files (`events-append.sh`, `events-query.sh`, the two hooks, the schema,
   the format doc) but **skip re-copying `skill-base.sh`, `orchestrator-postflight.sh`, and
   `settings.json`**, which already exist in the stale deploy and must be *replaced*, not merely
   supplemented, for the hook registrations and event call sites to actually take effect. Cancelling
   (button 3, or the default) performs no changes at all.
5. **What success looks like** (all independently verifiable without trusting self-report):
   - `ls .claude/scripts/events-append.sh .claude/scripts/events-query.sh` — both now exist.
   - `ls .claude/hooks/events-log-artifact.sh .claude/hooks/events-log-lifecycle.sh` — both now
     exist.
   - `ls .claude/context/schemas/events-schema.json .claude/context/formats/events-format.md` —
     both now exist.
   - `jq '.hooks.Stop, .hooks.SubagentStop, .hooks.PostToolUse' .claude/settings.json` — shows the
     `events-log-lifecycle.sh`/`events-log-artifact.sh` command entries (currently absent; the live
     deployed `settings.json` also currently carries a **duplicate** `claude-stop-notify.sh` entry
     under two separate `Stop` matcher blocks — a pre-existing drift artifact this same
     regeneration should also resolve, since it is a byte-for-byte copy from source, and source's
     `root-files/settings.json` has no such duplicate).
   - `bash .claude/scripts/check-extension-docs.sh --quiet` (or the source-store copy with
     `REPO_ROOT` set) — the `core` extension's current 4 FAILs (`memory-harvest.sh`,
     `parse-command-args.sh`, `skill-base.sh`, `orchestrator-postflight.sh` drift) should all
     resolve to 0, and the two "not deployed, skipping drift check" info lines for
     `events-append.sh`/`events-query.sh` should disappear entirely (their existence is now real,
     not skipped).
6. Repeat steps 1-5 once per additional repo targeted for cross-repo verification (scope item 1's
   "at least one other repo"). **Candidate repos with an existing `.claude/` deploy tree** (found
   via `find ~ -maxdepth 3 -iname ".claude" -type d`): `~/.dotfiles`, `~/Projects/cslib`,
   `~/Projects/ModelChecker`, `~/Projects/BimodalLogic`, `~/Projects/Literature`, and ~10 others.
   `~/.dotfiles/.claude/settings.json` is dated 2026-07-13 12:37 (even staler than nvim's), and
   `grep -c "events-append\|events-log" ~/.dotfiles/.claude/scripts/skill-base.sh` returns `0` —
   confirming the gap is real there too and unaffected by the 874 fix (dotfiles' `project_dir !=
   global_dir`, so it was never subject to the self-load guard bug at all; it simply has never had
   `<leader>al` re-run there since events landed).

**A monkeypatch-based headless bypass is mechanically conceivable but is explicitly a hack, not a
supported path, and was already avoided once for this exact reason.** `vim.fn` is a Lua table with
an `__index` metamethod dispatching to Vimscript builtins; assigning `vim.fn.confirm = function()
return 1 end` before calling `sync.load_all_globally(config)` in a scripted `nvim --headless`
invocation would likely shadow the real `confirm()` for that process. This is **not recommended**:
it is undocumented behavior of an internal Lua/Vimscript bridge, not a "confirm-bypass that is
legitimately part of the API," and task 874's own implementation deliberately tested at the
`scan_all_artifacts` layer *specifically because* "the full `load_all_globally()` path reaches a
`vim.fn.confirm()` dialog that is not safely drivable headless" (874's summary, Plan Deviations
section) — i.e. the prior implementer already made and documented this same judgment call. This
report does not recommend building or shipping a monkeypatch harness as part of 885; it is noted
here only to answer question (a) completely (technically conceivable, deliberately not pursued).

**`check-extension-docs.sh`'s drift check structurally cannot catch "never deployed," confirmed by
a live run against the current, still-stale tree** (`agent-system/extensions/core/scripts/
check-extension-docs.sh`, run via `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/
check-extension-docs.sh` — note the source-store copy miscomputes `REPO_ROOT` if invoked with a
relative `BASH_SOURCE[0]` from inside `agent-system/extensions/core/scripts/`, since its own
`../..` climbs only to `agent-system/extensions`, not the repo root; the deployed
`.claude/scripts/` copy does not have this problem since it lives two levels shallower — this
mismatch is itself a minor latent bug worth a one-line note in the plan, not a blocker for this
research):
```
[core]
  script not deployed, skipping drift check: events-append.sh
  script not deployed, skipping drift check: events-query.sh
  FAIL: deployed script content drift (deployed != extension source): scripts/memory-harvest.sh
  FAIL: deployed script content drift (deployed != extension source): scripts/parse-command-args.sh
  FAIL: deployed script content drift (deployed != extension source): scripts/skill-base.sh
  FAIL: deployed script content drift (deployed != extension source): scripts/orchestrator-postflight.sh
  WARN: README.md older than manifest.json (possible drift)
```
This is direct, reproducible, already-observed evidence (not inferred) that:
- `check_deployed_script_drift` (`check-extension-docs.sh:172`, Rule F) iterates
  `.provides.scripts[]` only, and explicitly treats a not-yet-deployed script as `info` (not
  `fail`) — by design, per its own comment: "An extension's rules are not deployed in every
  consuming repo" (the equivalent comment on `check_deployed_rule_drift`, `line 205`). This design
  is correct for *optional* extensions a given repo may not have chosen to load, but `core` is
  special: every `.claude/` tree in this ecosystem includes core by construction (it is the
  baseline, `routing_exempt: true`), so "not deployed" should be a FAIL for core specifically, not
  an info-skip.
- `.provides.hooks[]` (which already lists `events-log-artifact.sh` and `events-log-lifecycle.sh`
  in `agent-system/extensions/core/manifest.json`, confirmed via `jq '.provides.hooks'`) is **never
  iterated by any drift-or-completeness check** — it is referenced only inside
  `check_flat_category_orphans`'s exclusion list (to avoid double-flagging a hook as an "orphan
  script"), never as its own positive check. So even after this task's changes land, drift or
  non-deployment of the two events hooks would remain invisible to this gate unless a new check is
  added for the `hooks` category specifically.
- `root-files/settings.json` (the file carrying the hook *registrations*, as opposed to the hook
  *scripts* themselves) has **zero** references anywhere in `check-extension-docs.sh` — there is no
  mechanism today that would have caught the deployed `.claude/settings.json` missing 3 hook
  registrations (or carrying a duplicate `claude-stop-notify.sh` Stop-matcher entry) relative to
  `root-files/settings.json`.
- `context/schemas/*.json` and `context/formats/*.md` are declared only at the **directory** level
  in `provides.context` (`"formats"`, `"schemas"` as bare directory names, confirmed via
  `jq '.provides.context'`, 20 entries total) — the existing orphan check (`check_context_orphans`,
  Rule L) can only flag a *deployed-but-undeclared* file, which structurally cannot detect a file
  that was declared (at the directory level) but never actually copied.
- **This is enforced today only via a GitHub Actions workflow**
  (`.github/workflows/check-extension-docs.yml`, confirmed present), not a local pre-commit hook —
  `.git/hooks/` contains only the default `.sample` files, none executable. This is consistent with
  (and directly explains) how the gap survived a full day locally: the "hard gate" language in
  CLAUDE.md is accurate for CI-gated pushes/PRs, but nothing runs this check proactively on a local
  working tree between commits.

**Recommendation for scope item 6** (concrete, sized, verifiable without regeneration): extend
`check_deployed_script_drift` (and add analogous logic for `provides.hooks`, `provides.context`
directories, and `root-files/settings.json`'s hook-registration set) so that for the `core`
extension specifically — identifiable via `routing_exempt: true`, already read at line 240 for a
different check — "not deployed" is `fail`, not `info`. This is directly testable today: the
current live `.claude/` tree already reproduces the exact "should be a FAIL but isn't" scenario for
`events-append.sh`/`events-query.sh`, so the enhanced check's correctness can be confirmed by
re-running it before the regeneration (should show new FAILs) and after (should show 0 FAILs) —
neither run requires touching `.claude/` by hand, since the "after" state comes from the manual
`<leader>al` step, not from this task's own edits.

**Scope item 2's exact `|| true` call sites** (all confirmed via full-file reads, none require
regeneration to edit or to reason about):
- `agent-system/extensions/core/scripts/skill-base.sh`: 4 sites, all identical shape —
  `bash .claude/scripts/events-append.sh ... >/dev/null 2>&1 || true` (preflight, context_injection,
  verification, postflight lifecycle stages).
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh`: 2 sites, **already partially
  observable** — `... || echo "[postflight] WARNING: events-append.sh failed (non-blocking)" >&2`
  (both the main status event and the reflection event). This is a strictly better starting point
  than `skill-base.sh`'s bare `|| true` and could be the pattern scope item 2 generalizes from,
  though it still swallows the actual exit code/reason.
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh`: 2 internal sites —
  `"$EVENTS_APPEND" "${event_args[@]}" >/dev/null 2>&1 || true` (SubagentStop path and Stop path).
- `agent-system/extensions/core/hooks/events-log-artifact.sh`: 2 internal sites, same shape, for
  the `return_meta` and `errors_json` match types.
- Design constraint already stated in the delegation context and confirmed structurally correct by
  this reading: none of these call sites can become fatal to their enclosing operation (a hook
  that emits a non-`{}` decision, or a lifecycle stage that aborts a skill, would be a much larger
  regression than a missed event). The three concrete "observable, non-fatal" mechanisms worth
  the plan's consideration, in increasing cost order: (1) a stderr WARNING on every failure
  (matches `orchestrator-postflight.sh`'s existing pattern, cheapest, but has no persistence — a
  user not watching stderr live still misses it); (2) a one-time-per-session sentinel file (e.g.
  `.claude/tmp/events-append-missing`) written on first observed failure, checked by
  `skill-base.sh`'s own preflight to surface a single, non-spammy notification; (3) extending scope
  item 6's drift check to *also* be the detection mechanism (a startup/preflight drift check that
  fails loudly if `events-append.sh` isn't executable) — heavier, but directly closes the loop
  scope item 6 is already opening. This report does not pick one; it is a plan-level trade-off.

**Scope item 3/4 settlement — exact evidence, not previously in the delegation context**:
- `~/.claude/settings.json` (live, read in full): begins with `"_NOTE": "Managed by Home Manager
  via ~/.dotfiles/config/claude/settings.json. Edit the source, then run 'home-manager switch'."` —
  self-documenting confirmation of the delegation context's claim. Its `env` block currently has
  `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`,
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION`,
  `CLAUDE_CODE_FORK_SUBAGENT`, `LITERATURE_DIR` — i.e. this is already the established,
  actively-used home for cross-repo env configuration; `CLAUDE_CODE_ENABLE_TELEMETRY` and the OTel
  exporter vars belong in the same block, by precedent. It has no `cleanupPeriodDays` key at all
  today (confirmed via `jq '.cleanupPeriodDays'` → `null`), meaning the live default (30 days,
  per official docs) is currently in effect — nothing is silently overriding it downward.
- `agent-system/extensions/core/root-files/settings.json` (this task's actual `file_scope` entry,
  read in full): its `env` block is `{"SLASH_COMMAND_TOOL_CHAR_BUDGET": "50000"}` only — a
  project-specific tool-output budget, unrelated to telemetry/retention. This is the file that
  deploys byte-for-byte to `.claude/settings.json` in **every** consuming repo (not just nvim), so
  adding `CLAUDE_CODE_ENABLE_TELEMETRY`/`cleanupPeriodDays` here would be a defensible alternative
  to the dotfiles route IF the goal were "every repo using this agent-system gets telemetry" — but
  per the settings-precedence docs, project-level settings only apply when Claude Code is *launched
  from within that project directory*, so this route would still miss any repo that hasn't loaded
  the core extension (or hasn't re-synced it), and would not cover ad hoc `claude` invocations from
  arbitrary other directories the way the user-level file does. The user-level route is the more
  complete fix and is what the delegation context's own phrasing ("likely belongs in the DOTFILES
  repo") anticipated; this research confirms that anticipation rather than overturning it.
- `agent-system/extensions/core/templates/settings.json` (and its two mirrors,
  `.claude/templates/settings.json` and `~/.dotfiles/.claude/templates/settings.json`, byte-compared
  and found identical): a **dead template** — `grep -rn "templates/settings.json" agent-system/`
  and `grep -n "templates" install-extension.sh` both return zero hits; nothing in the codebase
  reads, merges, or deploys from it. It states `"_usage": "Merge these settings into
  ~/.config/claude-code/settings.json"` — a path that does not match Claude Code's actual config
  home (`~/.claude/`), and `"_cleanup_notes": ["Default is 7 days...]"` — contradicted by the
  official docs' stated default of 30. This file is not in `file_scope` and this report does not
  recommend touching it as part of 885's critical path; it is flagged only as a pre-existing,
  independently-discovered doc-accuracy nit a future pass could clean up.
- `anthropics/claude-code` issue #23710 (fetched via WebSearch, title verified verbatim:
  "cleanupPeriodDays: 0 silently disables all transcript persistence (docs say it disables
  cleanup)"): confirms the task's claim exactly, and specifies the mechanism — a guard clause in
  the session-storage `appendEntry` write path checks `cleanupPeriodDays === 0` and skips writing
  entirely, conflating "don't clean up" with "don't persist." The documented, community-verified
  workaround is a **large explicit number** (e.g. `36500`), never `0`. This report recommends the
  plan pick a concrete value in that spirit — e.g. `365` (one year) is more than sufficient to
  outlive any plausible `/distill`/`--learn` batch-harvest cadence while not courting an untested
  edge case at the extreme (`36500`) this repo doesn't need.

### External Resources

- `code.claude.com/docs/en/settings` (fetched): settings precedence order is Managed > CLI args >
  Local (`.claude/settings.local.json`) > Project (`.claude/settings.json`) > User
  (`~/.claude/settings.json`); permission rules merge across scopes, other settings override.
  `env` block variables are accepted at any scope. `cleanupPeriodDays` default is 30, minimum 1,
  governs "session files and other application data" cleanup that runs "at startup," described as
  effectively machine-wide rather than strictly project-scoped in practice.
- `code.claude.com/docs/en/monitoring-usage` (fetched, supplementing 887's prior fetch): confirms
  the minimal telemetry wiring needs only `CLAUDE_CODE_ENABLE_TELEMETRY=1` plus an exporter
  selection; a **console exporter** (`OTEL_METRICS_EXPORTER=console`,
  `OTEL_LOGS_EXPORTER=console`) requires no collector infrastructure at all and is the
  lowest-friction way to "wire an OTel exporter" for local verification, versus the OTLP/collector
  route (`OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_PROTOCOL`) which needs a running
  collector this task has no mandate to stand up. `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1` +
  `OTEL_TRACES_EXPORTER=otlp` remains beta-only span/trace territory, consistent with 887's finding
  that a full span/trace rebuild is explicitly out of scope.
- anthropics/claude-code issue #23710 (fetched via WebSearch): see above.

### Recommendations

1. **Land today, no regeneration dependency** (scope items 2, 5, 6, and the settling half of 3/4):
   - Replace the four `|| true` sites in `skill-base.sh` and the six internal sites across
     `events-log-lifecycle.sh`/`events-log-artifact.sh` with an observable-but-non-fatal pattern
     (see the three-option trade-off above; a stderr WARNING matching
     `orchestrator-postflight.sh`'s existing convention is the minimal viable version, a one-time
     sentinel is the more durable one).
   - Add a single nullable `cwd` field to `events-schema.json` and thread a `--cwd` flag through
     `events-append.sh`, captured from already-parsed hook stdin in the two hooks — matching 887's
     unfrozen design exactly on this one field, without adopting `cc_session_id` (still under
     revision). Resolve "repo" as a derived value in `events-query.sh` (e.g. basename of the git
     toplevel for that `cwd`) rather than storing a second field, keeping the schema change minimal
     and reversible if 887's fuller design changes shape.
   - Extend `check-extension-docs.sh` so `core`'s never-deployed scripts/hooks are FAIL, not
     info-skip, and add drift/completeness checks for `provides.hooks` and
     `root-files/settings.json`'s hook registrations (currently unchecked entirely). Verify by
     running the modified script against the still-stale live tree before any regeneration — it
     must newly report FAILs where it previously reported info/nothing.
   - Confirm (already done in this report) that `CLAUDE_CODE_ENABLE_TELEMETRY` and
     `cleanupPeriodDays` both belong in `~/.dotfiles/config/claude/settings.json`'s existing `env`
     block / top level, respectively — write the exact recommended snippet into the plan for a
     human (or a separate dotfiles-repo task) to apply, but do not edit that file from this task.
     Suggested snippet:
     ```json
     "cleanupPeriodDays": 365,
     "env": {
       "...": "existing keys unchanged",
       "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
       "OTEL_METRICS_EXPORTER": "console",
       "OTEL_LOGS_EXPORTER": "console"
     }
     ```
     (console exporter chosen deliberately over OTLP to avoid requiring collector infrastructure
     this task has no mandate to provision; upgrading to OTLP is a follow-up, not a blocker.)

2. **Genuinely gated behind the manual `<leader>al` step** (the rest of scope item 1, plus true
   end-to-end verification of everything above): the events stack cannot be observed *flowing* —
   hooks firing, `specs/events.jsonl` growing, `check-extension-docs.sh` going green — until a
   human performs the exact 5-step procedure in Findings, at least twice (once in nvim, once in a
   second repo such as `~/.dotfiles`). This is not a "maybe" — it is a hard architectural fact
   established by direct code reading (no `M.execute_sync`, no CLI path, `vim.fn.confirm` is
   unconditional), not an assumption inherited from the dependency task.

3. **Do not fabricate verification.** Once the manual step happens, "end-to-end verified" means:
   `specs/events.jsonl` has grown with real lines (not just that the files exist),
   `check-extension-docs.sh` reports 0 FAILs for `core`, and at least one lifecycle event
   (preflight/postflight/Stop) has actually fired from a real `/research`, `/plan`, or `/implement`
   invocation post-regeneration. Until observed, the implementation plan should mark this
   verification step `[PARTIAL]`/pending, explicitly, rather than inferring success from the code
   changes alone.

## Decisions

- The confirm() dialog is not new, not introduced by 874, and not removable within this task's
  scope — plan around a documented manual handoff, not a code fix.
- `cwd` (not a separately-stored `repo` field) is the recommended schema addition for now, to stay
  aligned with 887 without freezing its still-under-revision `cc_session_id` proposal.
- `CLAUDE_CODE_ENABLE_TELEMETRY` and `cleanupPeriodDays` both belong in
  `~/.dotfiles/config/claude/settings.json`, confirmed by settings-precedence semantics
  (machine-wide cleanup behavior; cross-repo telemetry need) — not in
  `agent-system/extensions/core/root-files/settings.json`, despite that file being listed in this
  task's `file_scope`. The plan should treat that `file_scope` entry as covering only the
  hook-registration edits needed to wire the two new events hooks (already present in
  `root-files/settings.json` per the earlier drift-check finding — no change needed there beyond
  what regeneration will deploy), not the telemetry/cleanup settings.
- `check-extension-docs.sh` extension for scope item 6 targets the specific, now-demonstrated gap:
  `core`-extension non-deployment should FAIL, and `provides.hooks`/`root-files/settings.json`
  need their own drift/completeness checks, none of which exist today.
- `cleanupPeriodDays: 365` is the recommended value (not `36500`, not `0`) — comfortably exceeds
  any plausible harvest cadence without adopting an untested extreme.

## Risks & Mitigations

- **Risk**: the plan treats the manual `<leader>al` step as something the implementation agent can
  itself perform or verify. **Mitigation**: this report establishes, with code-level citations, that
  it cannot (no headless-safe path exists) — the plan must mark this step user-owned and the
  corresponding verification `[PARTIAL]` until the user confirms it happened.
  - **Risk**: scope item 3/4 edits land in `root-files/settings.json` instead of dotfiles, either by
  habit (matching this repo's `file_scope`) or convenience. **Mitigation**: this report's evidence
  (settings-precedence docs + the live `~/.claude/settings.json` env-block precedent) should be
  cited directly in the plan to make the correct home unambiguous; the plan should NOT add
  `CLAUDE_CODE_ENABLE_TELEMETRY`/`cleanupPeriodDays` to `root-files/settings.json`.
- **Risk**: adding `cc_session_id` (887's fuller, unfrozen proposal) prematurely, before the user
  has revised/expanded 887. **Mitigation**: this report explicitly scopes 885's schema change to
  `cwd` only, deferring `cc_session_id` to whenever 887 is frozen and its own implementation task
  exists.
- **Risk**: `check-extension-docs.sh`'s `REPO_ROOT` auto-detection breaks when the script is
  invoked directly from its source-store path (`agent-system/extensions/core/scripts/`) rather than
  its deployed path (`.claude/scripts/`), as observed during this research (`../..` climbs to the
  wrong directory). **Mitigation**: flag as a minor, independently-discovered latent bug for the
  plan's awareness; not a blocker, and the deployed copy is unaffected.

## Context Extension Recommendations

- **Topic**: `<leader>al` regeneration is fundamentally interactive (no headless path exists).
- **Gap**: no context file documents this constraint; a future task could waste effort trying to
  automate it without reading this report or 874's summary first.
- **Recommendation**: once this task lands, add a short note to
  `agent-system/extensions/core/docs/guides/creating-extensions.md` (or a new
  `context/patterns/` file) stating plainly that `<leader>al`'s "Load Core"/"Load All" sync has no
  headless/CI equivalent and always requires a human confirm() click, so future automation attempts
  (or CI-based deploy-verification designs) don't retread this investigation.

## Appendix

**Files read in full**: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
(targeted: lines 1175-1410, plus function-signature grep across the whole file),
`agent-system/extensions/core/scripts/events-append.sh`,
`agent-system/extensions/core/scripts/check-extension-docs.sh` (full, 823 lines),
`agent-system/extensions/core/hooks/events-log-lifecycle.sh`,
`agent-system/extensions/core/hooks/events-log-artifact.sh`,
`agent-system/extensions/core/context/schemas/events-schema.json`,
`agent-system/extensions/core/root-files/settings.json`, live `.claude/settings.json`, live
`~/.claude/settings.json`, `~/.dotfiles/config/claude/settings.json`,
`agent-system/extensions/core/templates/settings.json`,
`specs/874_fix_stale_self_sync_guard_blocking_regeneration/summaries/
01_remove-stale-self-sync-guard-summary.md`,
`specs/887_research_telemetry_source_architecture_and_distill_redesign/reports/
01_telemetry-source-architecture.md`.

**Live checks performed**: `bash agent-system/extensions/core/scripts/check-extension-docs.sh`
(with corrected `REPO_ROOT`) against the current, still-stale deployed `.claude/` tree — captured
the exact `core: FAIL (4 issues)` output quoted in Findings; `jq '.provides.hooks'` /
`jq '.provides.context'` against `agent-system/extensions/core/manifest.json`; `find ~ -maxdepth 3
-iname ".claude" -type d` for cross-repo candidates; `grep -c "events-append\|events-log"
~/.dotfiles/.claude/scripts/skill-base.sh` (0 hits, confirming dotfiles has the identical gap);
`grep -rn "load_all_globally"` / `grep -rn "leader>al"` across `lua/` to establish the single
call site and keymap.

**Web sources fetched**: `code.claude.com/docs/en/settings` (settings precedence,
`cleanupPeriodDays` semantics), `code.claude.com/docs/en/monitoring-usage` (OTel env var
reference, console-exporter option), WebSearch for `anthropics/claude-code#23710` (issue title and
mechanism confirmed via search-result synthesis, cross-checked against the task description's own
claim).

**Searches performed**: `grep -n "confirm\|function M\." sync.lua`; `grep -rn
"events-append.sh" agent-system/`; `grep -rln "check-extension-docs.sh"` (found the CI workflow,
confirmed no local pre-commit hook); `grep -n "templates/settings.json"
agent-system/install-extension.sh` (zero hits, confirming the template is dead code).
