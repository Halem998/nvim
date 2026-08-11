# Implementation Summary: Task #24

- **Task**: 24 - Scope Playwright MCP permission allowlist to safe browser tools, solving install-once propagation
- **Status**: [COMPLETED]
- **Started**: 2026-08-10
- **Completed**: 2026-08-10
- **Effort**: 2 hours
- **Dependencies**: Task 23 (completed - MCP registration/permission ownership boundary)
- **Artifacts**: plans/01_scoped-playwright-permission-allowlist.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md, mcp-server-ownership.md

## Overview

Added a deliberately scoped Playwright MCP permission grant to the `web` extension's own
`settings-fragment.json`, enumerating exactly the 9 safe `mcp__playwright__browser_*` tools and
wiring it into `.claude/settings.local.json` via a new `merge_targets.settings` block in
`web/manifest.json`, mirroring `nix`/`lean`'s existing shape exactly. The three unsafe tools
(`browser_evaluate`, `browser_file_upload`, `browser_run_code_unsafe`) remain absent from every
allow list in the source store, and `core/root-files/settings.json` was deliberately left
untouched as the wrong domain owner and an install-once file that cannot reach an
already-initialized project. The enumeration-over-wildcard carve-out is now documented in
`mcp-server-ownership.md` and cross-referenced from `permission-configuration.md` so a future
"cleanup" pass does not collapse it into a wildcard.

## What Changed

- `agent-system/extensions/web/settings-fragment.json` — Created; the 9-tool `permissions.allow`
  enumeration (`browser_navigate`, `browser_snapshot`, `browser_take_screenshot`,
  `browser_console_messages`, `browser_network_requests`, `browser_click`, `browser_type`,
  `browser_find`, `browser_wait_for`), no `mcpServers` key, no wildcard.
- `agent-system/extensions/web/manifest.json` — Added `merge_targets.settings` (source
  `settings-fragment.json`, target `.claude/settings.local.json`), inserted between `claudemd`
  and `index`, structurally identical to `nix`'s and `lean`'s equivalents.
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` — Added a new
  "Carve-out: safe/unsafe tool splits require enumeration" subsection immediately after
  "Wildcard over enumeration" and before "Composition", naming the Playwright fragment as the
  worked example, naming the three tools that must keep prompting, and stating the accepted
  drift-weakness cost honestly.
- `agent-system/extensions/core/docs/guides/permission-configuration.md` — Added a one-sentence
  pointer from the "Prefer a wildcard over an enumeration" paragraph to the new carve-out
  subsection.
- `agent-system/extensions/web/README.md` — Added `settings-fragment.json` to the `## Architecture`
  directory tree with a one-line comment.
- `agent-system/extensions/core/index-entries.json` — Corrected the `line_count` for the
  `patterns/mcp-server-ownership.md` entry (160 -> 183) to match the file's new length after the
  carve-out subsection was added; this cleared a doc-lint FAIL that the Phase 4 prose edit
  otherwise introduced.
- `specs/024_scope_playwright_mcp_permission_allowlist/summaries/01_scoped-playwright-permission-allowlist-summary.md`
  (this file) — new.

No files under any deployed `.claude/**` tree were created or modified.
`agent-system/extensions/core/root-files/settings.json` was intentionally left unchanged (see
Plan Deviations / Follow-ups — this was a deliberate no-op, not an omission).

## Decisions

- **Owning extension is `web`, not `core`**: `web-implementation-agent.md` is the only
  current-or-imminent consumer of `mcp__playwright__*` tools; a domain-specific grant belongs
  with its one real domain owner.
- **Enumeration, not a wildcard**: the fixed design requires 3 tools to keep prompting
  (`browser_evaluate`, `browser_file_upload`, `browser_run_code_unsafe`); a wildcard cannot
  express that split. Documented as a deliberate exception to the codebase's general wildcard
  preference in `mcp-server-ownership.md`.
- **No `mcpServers` block**: registration is already live at user scope via home-manager; a
  settings-file `mcpServers` block is proven inert and would be a sixth instance of an
  already-catalogued anti-pattern.
- **`core/root-files/settings.json` left unchanged, verified positively**: it is both the wrong
  domain owner (Playwright is web-domain-specific today) and the install-once file that cannot
  reach an already-initialized project regardless of domain, so putting the grant there would not
  even satisfy the acceptance criterion. `git diff --quiet` against this file printed `UNCHANGED`.

## Plan Deviations

- None (implementation followed plan). One mechanical correction was made that the plan itself
  anticipated as a residual risk but did not pre-script: Phase 4's prose edit to
  `mcp-server-ownership.md` grew the file from 160 to 183 lines, which the doc-lint's Rule R
  caught as a `line_count` mismatch in `core/index-entries.json`. This was corrected with a
  single targeted `Edit` to that one entry (not the global
  `generate-context-line-counts.sh --write`, which would also have rewritten an unrelated,
  pre-existing `literature` extension mismatch left by a concurrent, out-of-scope session). This
  is recorded here as a completion detail, not a plan deviation, since Phase 5's own verification
  task ("confirm no new FAIL attributable to `web` or `core`") required exactly this fix to pass.
- Phase 5's `grep -rn 'mcp__playwright__\*' agent-system/extensions/ || echo "no wildcard"`
  assertion, taken completely literally, does not print its fallback message: it finds two
  matches. Both are benign and neither is a permission-grant wildcard: (1)
  `web/agents/web-research-agent.md`'s pre-existing `disallowedTools: mcp__playwright__*` frontmatter
  field (a denial, predating this task, unmodified by it — confirmed via `git log`/`git status`),
  and (2) this task's own Phase 4 prose in `mcp-server-ownership.md`, which is required by Phase
  4's own task text to name the exact anti-pattern string as a worked example of what NOT to do. A
  targeted check of every `agent-system/extensions/*/settings-fragment.json` for a wildcard grant
  found none. This is recorded as a documented interpretation of an overbroad literal grep against
  the plan's own clearly-stated intent (no wildcard *grant*), not a defect.

## Verification

- Build: N/A (no build step for this task type)
- Tests: N/A (mechanical `jq`/`grep`/`diff` assertions and a headless Neovim acceptance run — see
  below)
- Files verified: Yes

**Phase 1** (fragment): `jq empty` valid; exactly one top-level key (`permissions`); exactly 9
entries, all prefixed `mcp__playwright__browser_`; no wildcard; none of the 3 unsafe tool names
present.

**Phase 2** (manifest wiring): `jq empty` valid; `merge_targets.settings.source`/`.target` match
the required values; declared source file exists; `merge_targets.settings` block is
structurally identical (via `diff` on `jq -S`) to both `nix`'s and `lean`'s; `git diff` on the
manifest shows only the 4 added lines.

**Phase 3** (acceptance, fixture-based): Pre-seeded
`$SCRATCH/pw-fixture/.claude/settings.json` (containing a `$schema` key and
`permissions.allow: ["Bash(git status:*)"]`) and `.claude/settings.local.json` (containing
`someUnrelatedScalar: "preserve-me"` and `permissions.allow: ["mcp__nixos__nix"]`), recorded
`sha256sum` of both before merging.

Ran the real `merge.lua` `M.merge_settings(target_path, fragment)` path headlessly against the
fixture's `settings.local.json` twice:
- **First run**: `ok=true`; `tracked` reported `permissions.allow` as `{type = "appended", items
  = {9 playwright tool names}}`.
- **Second run** (idempotency): `ok=true`; `tracked` reported `permissions.allow` as `{type =
  "appended", items = {}}` — nothing new to append, confirming idempotency.

Post-merge `settings.local.json` assertions, all passing: valid JSON; all 9
`mcp__playwright__browser_*` entries present; none of the 3 unsafe tool names anywhere in the
file; no wildcard; the pre-existing `mcp__nixos__nix` entry survived; exactly 9
`mcp__playwright__*` entries after both runs (no duplication); `settings.json`'s `sha256sum`
matched its pre-merge recording exactly (never touched by the web fragment's own merge).

**Optional end-to-end tier**, attempted and successful: the plan's suggested invocation shape
(`require(...).manager.load(...)`) does not match the module's actual API — `init.lua` exposes
`M.create(config)` returning a manager instance, not a module-level `M.manager` table. Corrected
to `require('...extensions.config').claude()` -> `require('...extensions.init').create(cfg)` ->
`manager.load(name, {project_dir=FIX, confirm=false})`, then ran `manager.load('core', ...)`
followed by `manager.load('web', ...)` against the fixture's `project_dir` only (never against
this repository). Both loads returned `ok2=true`. The resulting fixture `settings.local.json`
carried all 9 playwright grants plus the pre-existing `mcp__nixos__nix` entry and
`someUnrelatedScalar`. Loading `core` additively added its own unrelated `hooks` block to the
fixture's `settings.json` via core's own `merge_targets.settings` — orthogonal to this task's
playwright grant, and not evidence against the "`settings.json` never touched by the web merge"
claim, which was already confirmed via the `sha256sum` check taken immediately after the two
direct `merge_settings` runs, before this optional tier ran.

**Phase 4** (documentation): new "Carve-out" subsection confirmed sitting between "### Wildcard
over enumeration" and "## Composition" via heading-order grep; all three named tools appear in
the new subsection; task-reference grep across all three edited files returned nothing; the
"Known gaps" table was left unmodified.

**Phase 5** (final gates):
- `check-extension-docs.sh`: `web` PASS. `core` had one new FAIL (the `mcp-server-ownership.md`
  `line_count` mismatch, corrected — see Plan Deviations) and, after that fix, its only remaining
  FAIL/WARN (`setup-lean-mcp.sh` drift, `README.md older than manifest.json`) and `literature`'s
  FAIL are pre-existing and unmodified by this task.
- `check-task-references.sh`: PASS, 0 unexempted occurrences across `agent-system/extensions`,
  `.opencode`, `lua`, `.memory`.
- `git diff --quiet -- agent-system/extensions/core/root-files/settings.json`: printed `UNCHANGED`.
- `git status --short -- .claude/`: no output.
- No `mcp__playwright__*` wildcard grant in any `settings-fragment.json`; the 3 unsafe tool names
  are granted nowhere in `agent-system/extensions/`.

## Impacts

- The `web` extension now propagates a scoped, always-allow grant for 9 safe browser tools to any
  project that loads or reloads `web`, without requiring the install-once `root_files` category
  (which cannot reach an already-initialized project).
- `mcp-server-ownership.md` now carries a documented, worked-example exception to its general
  "prefer wildcard" guidance, closing the gap the research report flagged.
- This repository's own deployed `.claude/settings.local.json` will NOT gain these grants until
  the `web` extension is loaded here (it currently loads `core, email, nvim, nix, memory`) — this
  is expected, out of scope, and not the install-once hazard this task closes.

## Follow-ups

- Loading the `web` extension into this repository (or any other project that wants the grant
  today) is a separate, unstarted action — out of scope for this task.
- A sibling task owns reconciling `web-implementation-agent.md`'s Playwright tool-list prose and
  its `browser_verify_text_visible` name drift.
- A sibling task owns migrating `founder`'s deck-builder-agent and `present`'s
  `playwright-verify.mjs` from standalone npm Playwright to the MCP server, at which point they
  will need their own permission grant (or a `web` dependency) for the same 9 tools.

## References

- Plan: `specs/024_scope_playwright_mcp_permission_allowlist/plans/01_scoped-playwright-permission-allowlist.md`
- Research report: `specs/024_scope_playwright_mcp_permission_allowlist/reports/01_scoped-playwright-permission-allowlist.md`
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
- `agent-system/extensions/core/docs/guides/permission-configuration.md`
