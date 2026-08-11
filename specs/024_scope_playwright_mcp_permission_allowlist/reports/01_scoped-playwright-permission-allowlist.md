# Research Report: Task #24

**Task**: 24 - Scope Playwright MCP permission allowlist to safe browser tools, solving install-once propagation
**Started**: 2026-08-10
**Completed**: 2026-08-10
**Effort**: 1-3 hours
**Dependencies**: Task 23 (completed — MCP registration/permission ownership boundary)
**Sources/Inputs**: Codebase (agent-system/extensions/**, lua/neotex/plugins/ai/shared/extensions/**), TODO.md sibling tasks
**Artifacts**: specs/024_scope_playwright_mcp_permission_allowlist/reports/01_scoped-playwright-permission-allowlist.md
**Standards**: report-format.md, subagent-return.md, mcp-server-ownership.md

## Executive Summary

- **Owning location**: the permission grant belongs in a NEW `agent-system/extensions/web/settings-fragment.json`, wired via a new `merge_targets.settings` block in `agent-system/extensions/web/manifest.json` (mirroring `nix`/`lean`'s existing shape exactly). No `mcpServers` block should be added (registration is already live via home-manager per the sibling task's own PROBLEM section, and adding a dead `mcpServers` block here would repeat the exact anti-pattern `mcp-server-ownership.md`'s "Known gaps" table already lists for five other extensions).
- **Why `web`, not `core` or a new extension**: `web-implementation-agent.md` is the ONLY current-or-imminent consumer of `mcp__playwright__*` tools in this codebase — its Playwright section exists today but is marked `**Status**: Deferred pending browser binary installation`, and the immediately-dependent sibling task (25) activates it. `founder`'s deck-builder-agent and `present`'s `playwright-verify.mjs` both call the standalone npm Playwright, NOT the MCP server, today (migrating them is a separate, not-yet-started sibling task, 26). A domain-specific grant belongs with its one real domain owner, per `mcp-server-ownership.md`; `web` is that owner today, `core` is not (core is reserved for grants every loaded configuration needs, and non-web tasks have no use for browser tools).
- **This is exactly the sanctioned mechanism for reaching an already-initialized repo**: `merge_targets.settings` deploys to `.claude/settings.local.json`, which is copied through a completely different code path than the install-once `root_files` category (`process_merge_targets`/`merge_settings` in `init.lua`/`merge.lua`, not `loader.lua`'s `copy_category`). It performs an additive, idempotent deep-merge — it never overwrites an existing scalar and de-duplicates array items via `vim.deep_equal` before appending — so it is safe to re-run on a project that already has its own `settings.local.json`. `check-extension-docs.sh`'s own lint (`check_settings_merge_source_coverage`) states this in so many words: *"The file that DOES reach existing repos is the merge target declared in manifest.json (`merge_targets.settings.source`)"*, in direct contrast to `root-files/settings.json`, which "can never reach an already-initialized repo, no matter how many regenerations run."
- **Enumerate, don't wildcard** — a deliberate, documented exception to `mcp-server-ownership.md`'s general "prefer a wildcard" guidance. The fragment must list exactly the 9 named safe tools; a `mcp__playwright__*` wildcard would also grant `browser_evaluate`, `browser_run_code_unsafe`, and `browser_file_upload`, defeating the whole point of the task. This is the first case in the codebase where enumeration is the *correct* choice rather than technical debt, and the report recommends recording that exception explicitly (see Decisions).
- **Propagation to an existing project** happens the next time the `web` extension is loaded or reloaded in that project: fresh `load` (first time `web` is loaded there), `manager.reload("web")` (unload+load, re-merges from scratch), or the picker's "Reload All" bulk resync (`manager.load(..., {force = true})` for every already-active extension, bypassing the `is_loaded` short-circuit). All three paths run `process_merge_targets`, which is unconditional and not gated by `install_once` — that flag only exists on the `root_files` category descriptor and is checked exclusively inside `loader.lua`'s `copy_category`.

## Context & Scope

Task 24 is scoped narrowly by its own description to (a) picking the correct source-store location for a 9-tool Playwright permission enumeration and (b) confirming/establishing the propagation path that reaches a project whose `.claude/settings.json` already exists (the install-once hazard). It explicitly forbids re-deriving the granularity question (already proven by `nix`/`lean`/`founder`) and forbids inventing an `ask` permission tier. This report does not touch `web-implementation-agent.md`'s tool-list prose (that is task 25's job) and does not touch `founder`/`present`'s standalone npm Playwright usage (task 26's job).

## Findings

### Codebase Patterns

- **`merge_targets.settings` shape** (confirmed identical across `nix` and `lean`):
  ```json
  "settings": {
    "source": "settings-fragment.json",
    "target": ".claude/settings.local.json"
  }
  ```
  `agent-system/extensions/nix/manifest.json` and `agent-system/extensions/lean/manifest.json` both carry this block; `agent-system/extensions/web/manifest.json` currently does not (`merge_targets` has only `claudemd`, `index`, `opencode_json`).
- **Fragment content precedent**: `agent-system/extensions/lean/settings-fragment.json` is now (post task-23) a single wildcard:
  ```json
  { "permissions": { "allow": ["mcp__lean-lsp__*"] } }
  ```
  `agent-system/extensions/nix/settings-fragment.json` still enumerates 2 tools (`mcp__nixos__nix`, `mcp__nixos__nix_versions`) alongside a (now-known-dead, per `mcp-server-ownership.md`'s "Known gaps" table) `mcpServers` block. `agent-system/extensions/founder/settings-fragment.json` enumerates 5 `mcp__firecrawl__*` tool names plus a `mcp__sec-edgar__*` wildcard, alongside its own dead `mcpServers` block for `firecrawl`. Neither nix's nor founder's dead `mcpServers` blocks should be imitated — this is the precise defect class the ownership doc calls out, and the new `web` fragment must NOT add a sixth instance.
- **Merge mechanics** (`lua/neotex/plugins/ai/shared/extensions/merge.lua`, `M.merge_settings`/`deep_merge`, lines ~282-395; called from `lua/neotex/plugins/ai/shared/extensions/init.lua`'s `process_merge_targets`, lines ~89-102): reads the target file if it exists (else starts from `{}`), deep-merges the fragment in — arrays are appended with per-item `vim.deep_equal` dedup, objects are merged key-by-key recursively, and a scalar is only written if the target key is currently `nil` (never overwritten). Tracked additions are recorded so `manager.unload` can reverse exactly what was added, nothing more.
- **Load/reload code paths that trigger the merge** (`init.lua`):
  - `manager.load(extension_name, opts)` — line ~297 short-circuits with `"Extension already loaded"` unless `opts.force` is set; a genuinely first-time load of `web` in a project runs `process_merge_targets` unconditionally.
  - `manager.reload(extension_name, opts)` — lines ~861-885 — unloads then loads a single named extension. Unload reverses the tracked settings merge, load re-merges fresh from the current (edited) fragment.
  - The picker's "Reload All" bulk resync — documented at lines ~887-898 as calling `manager.load(..., {force = true})` for every currently active extension, explicitly to avoid an "everything unloaded" intermediate state. `force = true` bypasses the `is_loaded` short-circuit at line 297, so `process_merge_targets` runs again for every loaded extension including `web` (once it is loaded there), additively picking up any new fragment entries.
  - None of these three paths touch `loader.lua`'s `copy_category("root_files", ...)` or its `install_once` gate — that gate is a property of the `root_files` category descriptor only, and `merge_targets.settings` is an entirely separate deploy mechanism (`process_merge_targets`, not `copy_category`).
- **Doc-lint corroboration**: `agent-system/extensions/core/scripts/check-extension-docs.sh`'s `check_settings_merge_source_coverage` function (lines ~340-404) exists specifically to catch hook registrations that live ONLY in the install-once `root-files/settings.json` with no `merge_targets.settings` route, and states outright: *"root-files/settings.json is INSTALL-ONCE ... anything added only there can never reach an already-initialized repo, no matter how many regenerations run. The file that DOES reach existing repos is the merge target declared in manifest.json (merge_targets.settings.source)."* This check is scoped to extensions that already have a `root-files/settings.json` (a no-op for `web`, which has none), but its stated rationale is exactly the propagation argument this task needs, and it independently validates `merge_targets.settings` as the sanctioned answer rather than a novel workaround.
- **Live worked example in this very repo**: this repository's own deployed tree already has `.claude/settings.json` (5051 bytes) and `.claude/settings.local.json` (4879 bytes, currently carrying `nix`'s and `memory`'s fragment merges) — a real instance of the "project that ALREADY has a `.claude/settings.json`" scenario the acceptance criterion asks to verify against. However, `.claude-extensions.json` shows only `core, email, nvim, nix, memory` loaded here — `web` is NOT currently loaded in this repo. Reaching this specific repo would require loading `web` here first (a one-time `manager.load("web")`); the fix itself is unaffected by that — it is a property of which *target* project has `web` loaded, not a defect in the fix. A downstream project that already loads `web` (or loads it for the first time after this change lands) gets the grant with no further action beyond a normal load/reload.
- **Exact tool names verified against the live MCP tool surface** (system-provided deferred-tool list for `mcp__playwright__*`): all 9 requested safe names exist verbatim — `browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests`, `browser_click`, `browser_type`, `browser_find`, `browser_wait_for` — and all 3 tools to keep prompting also exist verbatim — `browser_evaluate`, `browser_file_upload`, `browser_run_code_unsafe`. No name drift to reconcile (unlike the `browser_verify_text_visible` drift task 25 must fix in `web-implementation-agent.md`'s prose).
- **Confirmed non-consumers today**: `agent-system/extensions/founder/agents/deck-builder-agent.md` shells out to `npx playwright --version` (standalone npm Playwright, not MCP). `agent-system/extensions/present/context/project/present/talk/templates/playwright-verify.mjs` is a standalone Node script. Neither references any `mcp__playwright__*` tool name today, so scoping the grant to `web` alone does not leave any currently-live MCP call unpermitted.

### External Resources

Not applicable — this task is entirely about this repository's own extension-loader mechanics and manifest schema; no external library or API documentation is relevant.

### Recommendations

1. **Create `agent-system/extensions/web/settings-fragment.json`**:
   ```json
   {
     "permissions": {
       "allow": [
         "mcp__playwright__browser_navigate",
         "mcp__playwright__browser_snapshot",
         "mcp__playwright__browser_take_screenshot",
         "mcp__playwright__browser_console_messages",
         "mcp__playwright__browser_network_requests",
         "mcp__playwright__browser_click",
         "mcp__playwright__browser_type",
         "mcp__playwright__browser_find",
         "mcp__playwright__browser_wait_for"
       ]
     }
   }
   ```
   No `mcpServers` key (registration is already live at user scope via home-manager; adding one here would be dead weight per `mcp-server-ownership.md`).

2. **Add to `agent-system/extensions/web/manifest.json`'s `merge_targets`**:
   ```json
   "settings": {
     "source": "settings-fragment.json",
     "target": ".claude/settings.local.json"
   }
   ```
   (Insert alongside the existing `claudemd`/`index`/`opencode_json` entries, matching `nix`/`lean`'s key ordering for consistency.)

3. **Document the enumeration exception**. `mcp-server-ownership.md` and `permission-configuration.md` both currently state a blanket "prefer wildcard over enumeration" rule with no carve-out. Add a short note (in `mcp-server-ownership.md`, next to the existing "Wildcard over enumeration" subsection) naming the Playwright fragment as the worked example of the one case where enumeration is *required*, not merely tolerated: when a server intentionally splits tools into a safe/always-allow tier and an unsafe/always-prompt tier, a wildcard would erase that split. Without this note, a future maintainer "cleaning up" the fragment into `mcp__playwright__*` (mirroring what was just done for `lean-lsp`) would silently re-open the arbitrary-execution/upload hole this task exists to keep closed.

4. **No change to `core/root-files/settings.json`.** It should not gain a `mcp__playwright__*` entry of any shape — that file is both the wrong domain owner (playwright is web-domain-specific today) and, independently, the install-once file that cannot reach existing projects at all.

5. **Verification approach for the implementer**: pick (or create) a scratch project that already has `.claude/settings.json`/`.claude/settings.local.json` and does NOT yet have `web` loaded (or has it loaded from a pre-fix `settings-fragment.json`). Load (or reload) `web` there after the fragment/manifest change lands, then confirm via the deployed `.claude/settings.local.json` that the 9 `mcp__playwright__browser_*` entries are present and that `browser_evaluate`/`browser_file_upload`/`browser_run_code_unsafe` are absent from every allow list in the deployed tree. A live tool call is the strongest confirmation but is not required if the settings-file inspection is unambiguous.

## Decisions

- **Owning extension**: `web`, not `core`, not a new dedicated extension. Rationale: domain-specific-grant rule from the completed prerequisite task, applied to the one extension with an actual (currently deferred) `mcp__playwright__*` consumer.
- **Mechanism**: `merge_targets.settings` -> `.claude/settings.local.json`, not `core/root-files/settings.json`, not a migration script, not user-scope settings. Rationale: it is the only one of the task's own candidate mechanisms that is both already-proven (nix, lean) and independently corroborated by `check-extension-docs.sh`'s lint rationale as the sanctioned route to an already-initialized repo.
- **Form**: explicit 9-item enumeration, not a wildcard. Rationale: the task's fixed design requires 3 tools to keep prompting; a wildcard cannot express that split. This is flagged as a documented exception to the codebase's general wildcard preference, not a silent deviation.
- **No `mcpServers` block** in the new fragment. Rationale: registration already happened at user scope; a settings-file `mcpServers` block is proven inert (per `mcp-server-ownership.md`) and would be a sixth instance of an already-catalogued anti-pattern.

## Risks & Mitigations

- **Risk**: `web` extension is not loaded in every project that might trigger a Playwright call (e.g., via a future `founder`/`present` MCP migration, task 26). *Mitigation*: explicitly out of scope for this task; flagged here as a known, intentional gap (mirroring the existing "Known gaps" table pattern in `mcp-server-ownership.md`) rather than silently left implicit. When task 26 migrates `founder`/`present` to the MCP server, that task will need to either add the same 9-tool block to their own fragments or introduce a `web` dependency for permission purposes.
- **Risk**: a future contributor "simplifies" the enumeration into a wildcard, reopening the arbitrary-execution hole. *Mitigation*: recommendation 3 above — document the exception inline in `mcp-server-ownership.md` so the rationale is visible at the point someone would make that edit.
- **Risk**: `web` extension not being loaded in a given target project means "just editing the source store" alone does not visibly fix that project until a load/reload action is taken. *Mitigation*: this is inherent to the extension system's design (every source-store change requires a load/reload/regenerate action to reach a deployed tree) and applies equally to every other extension fragment in the codebase; it is not specific to this change and is not the install-once hazard the task is about (that hazard is specifically "even after reload, the old file is never touched" — which does not apply here).

## Context Extension Recommendations

- **Topic**: enumeration-vs-wildcard exception criteria for MCP permission fragments.
- **Gap**: `mcp-server-ownership.md` and `permission-configuration.md` state "prefer wildcard" with no documented exception, even though this task establishes a legitimate one (partial-trust tool splitting).
- **Recommendation**: add a short subsection to `mcp-server-ownership.md` (see Recommendation 3) using the Playwright fragment as the canonical example, so the next MCP integration with a mixed safe/unsafe tool surface does not have to re-derive this from scratch.

## Appendix

### Search queries / commands used

- `find agent-system/extensions -iname "*playwright*"`, `grep -rl "playwright" agent-system/extensions --include="*.json"`
- `find agent-system/extensions -iname "settings-fragment.json"` and direct `cat` of `lean`, `nix`, `founder` fragments and their manifests' `merge_targets`
- Read of `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` (prerequisite task's canonical output)
- Read of `agent-system/extensions/core/docs/guides/permission-configuration.md`
- Read of `lua/neotex/plugins/ai/shared/extensions/merge.lua` (`deep_merge`, `M.merge_settings`, `M.unmerge_settings`) and `lua/neotex/plugins/ai/shared/extensions/init.lua` (`process_merge_targets`, `manager.load`/`reload`/"Reload All" bulk resync, `manager.regenerate`)
- Read of `agent-system/extensions/core/scripts/check-extension-docs.sh`'s `check_settings_merge_source_coverage` (lines ~340-404)
- `grep -n "playwright\|browser_"` across `agent-system/extensions/founder/agents/deck-builder-agent.md`, `agent-system/extensions/web/agents/web-{implementation,research}-agent.md` to confirm current (non-)consumers
- Cross-check of the 9 allowed + 3 excluded tool names against the live `mcp__playwright__*` deferred-tool listing supplied in this session's system context
- Read of `specs/TODO.md` entries for tasks 23 (prerequisite, completed), 25, and 26 (both dependent siblings) to confirm scope boundaries and avoid re-deciding what those tasks own
- Inspected this repository's own deployed `.claude/settings.json`/`.claude/settings.local.json` and `.claude-extensions.json` as a live "pre-existing settings file" example
