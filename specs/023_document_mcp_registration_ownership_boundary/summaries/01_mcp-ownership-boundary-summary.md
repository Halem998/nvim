# Implementation Summary: Task #23

- **Task**: 23 - Document MCP registration vs permission ownership boundary; reconcile lean-lsp three-way duplication
- **Status**: [COMPLETED]
- **Started**: 2026-08-11T05:48:29Z
- **Completed**: 2026-08-11T06:52:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_mcp-ownership-boundary.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Wrote the canonical registration-vs-permission ownership decision into one new source-store
document, corrected every existing wrong assertion that a settings file or `manifest.json`
registers an MCP server, and collapsed the lean-lsp three-way duplication (a wildcard in core, a
21-entry enumeration in lean, and a dead `mcpServers` registration block also in lean) down to one
registration mechanism (`setup-lean-mcp.sh`, writing user-scope `~/.claude.json`) and one
permission grant (a wildcard in lean's own `settings-fragment.json`). All seven phases across the
plan's four dependency waves completed as planned, with Phase 7's sweep widening scope to catch
and fix four additional wrong-assertion sites beyond the six files the plan named up front.

## What Changed

- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` -- new canonical
  document: Registration, Not registration, Permission (wildcard-over-enumeration), Composition,
  Decision procedure, Known gaps (five extensions with dead `mcpServers` blocks), Related
  Documentation.
- `agent-system/extensions/core/index-entries.json` -- registered the new pattern file
  (`line_count: 160`); later corrected `patterns/mcp-tool-recovery.md`'s `line_count` (257->261)
  after that file's own edit in Phase 4.
- `agent-system/extensions/core/docs/architecture/extension-system.md` -- replaced the
  non-functional `mcpServers` Settings Merging example with a `permissions.allow` example;
  corrected its note and the manifest-schema `mcp_servers` note; corrected the Install-Once
  section's "MCP server configuration" wording.
- `agent-system/extensions/core/docs/guides/creating-extensions.md` -- corrected the `mcp_servers`
  field-reference row; removed the dead `"mcp_servers": {}` example-manifest line, replaced with an
  explanatory note.
- `agent-system/extensions/core/docs/guides/permission-configuration.md` -- added a new
  "MCP Server Registration and Permissions" top-level section (with ToC entry), and corrected the
  "Settings File Location" subsection's "MCP server configuration" wording to "MCP permission
  grants".
- `agent-system/extensions/core/context/patterns/mcp-tool-recovery.md` -- cross-linked the new
  canonical document from both its "Tool Unavailable" symptom and its Related Documentation
  section.
- `agent-system/extensions/core/root-files/settings.json` -- removed the domain-specific
  `"mcp__lean-lsp__*"` wildcard from `permissions.allow` (committed atomically with the next item).
- `agent-system/extensions/lean/settings-fragment.json` -- replaced the 21-entry
  `mcp__lean-lsp__lean_*` enumeration with a single `"mcp__lean-lsp__*"` wildcard; deleted the dead
  `mcpServers` block entirely.
- `agent-system/extensions/lean/README.md` -- corrected the MCP Tool Setup registration statement
  and fixed a real invocation-line discrepancy (README showed `npx -y lean-lsp-mcp@latest`; the
  script actually configures `uvx lean-lsp-mcp`).
- `agent-system/extensions/nix/README.md` -- corrected the MCP Tool Setup statement: `mcp-nixos` is
  not currently registered by anything in the repo; agents fall back to WebSearch/CLI.
- `agent-system/extensions/core/scripts/setup-lean-mcp.sh` -- header-comment precision fix
  (categorical "subagents cannot access" claim -> the actual interactive-approval-prompt
  mechanism); no executable line changed.
- `agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md` -- corrected a
  contradicting claim ("The MCP server is configured in `.mcp.json`") to describe the actual
  user-scope registration path; `line_count` corrected in `lean/index-entries.json` (149->157).
- `agent-system/extensions/core/templates/extension-readme-template.md` -- corrected the MCP Tool
  Setup template section every future extension README is authored from, replacing the
  "Configured automatically in `manifest.json`" instruction with the real registration/permission
  split.
- `agent-system/extensions/filetypes/README.md` -- corrected the SuperDoc and openpyxl MCP Tool
  Setup statements (both said "Configured automatically in `manifest.json`") and replaced a
  confusing closing note with an accurate one.
- `agent-system/extensions/core/docs/guides/adding-domains.md` -- corrected the directory-tree
  comment for `settings-fragment.json` and removed the dead `"mcp_servers": {}` example-manifest
  line, mirroring the Phase 3 fix already applied to `creating-extensions.md`.

## Decisions

- Registration lives exclusively in user-scope `~/.claude.json`; no settings file or
  `manifest.json` field ever registers a server, regardless of extension.
- Domain-specific `mcp__{server}__*` grants belong in the owning extension's own
  `settings-fragment.json`, never in core's domain-agnostic `root-files/settings.json`.
- Wildcard grants are preferred over per-tool enumeration, since an enumeration silently
  under-grants as a server's tool surface grows.
- The five other extensions carrying dead `mcpServers` blocks (nix, memory, filetypes, founder,
  epidemiology) are named in the canonical document's Known Gaps table but deliberately not
  cleaned up here -- registering those servers is a follow-up requiring host-level/home-manager
  changes this documentation task cannot verify or perform.

## Plan Deviations

- None (implementation followed the plan). Phase 7's sweep uncovered four additional
  wrong-assertion sites beyond the six files named across Phases 1-6
  (`lean/context/project/lean4/tools/mcp-tools-guide.md`,
  `core/templates/extension-readme-template.md`, `filetypes/README.md`,
  `core/docs/guides/adding-domains.md`); this is an anticipated widening explicitly provided for
  by Phase 7's own Scope Hypothesis ("if one of those four carries such prose, correct that prose
  ... and note the widened scope"), not a deviation from the plan.

## Verification

- Build: N/A (documentation/configuration task)
- Tests: N/A
- Files verified: Yes -- every phase's own verification criteria passed (heading presence,
  `jq empty`, `grep -c`/`jq` counts, `bash -n`, comment-only diffs, link resolution checks), plus
  the Phase 7 repo-wide sweep (`generate-context-line-counts.sh --check`,
  `check-task-references.sh` PASS, `check-extension-docs.sh` triaged).

## Impacts

- A future extension author reading `context/patterns/mcp-server-ownership.md` now has a single,
  correct answer to "where do I register a server and grant its permissions," and every
  previously-wrong doc (including the extension-README template every future extension copies
  from) now points there instead of repeating the inert-`mcpServers` pattern.
- lean-lsp's permission surface is now maintained in exactly one place (a wildcard in
  `lean/settings-fragment.json`); a future lean-lsp tool addition needs no matching doc/permission
  edit, closing the drift vector that produced the original 21-entry enumeration.
- **Manual regeneration required**: all changes are source-store edits under
  `agent-system/extensions/**`. None of them reach the deployed `.claude/**` tree (or take runtime
  effect) until the user performs a manual reload/regenerate. `check-extension-docs.sh` currently
  reports exactly one drift finding attributable to this task
  (`core: FAIL: deployed script content drift ... scripts/setup-lean-mcp.sh`), which is the
  expected, non-blocking pre-regeneration state this plan explicitly anticipated -- not a defect.

## Follow-ups

- Registering `mcp-nixos`, `obsidian-memory`, `openpyxl`, `superdoc`, `firecrawl`, `sec-edgar`, and
  `rmcp` in user scope, and removing the five still-dead `mcpServers` blocks in the nix, memory,
  filetypes, founder, and epidemiology `settings-fragment.json` files -- named as an explicit,
  deliberate non-goal of this task (host-level/home-manager changes a documentation task cannot
  verify or perform).
- A manual regeneration (`<leader>al` -> Reload All/Regenerate, or `bash .claude/scripts/deploy-headless.sh`)
  is needed for these source-store changes (including the lean-lsp permission collapse) to take
  effect in the deployed `.claude/**` tree.

## References

- Plan: `specs/023_document_mcp_registration_ownership_boundary/plans/01_mcp-ownership-boundary.md`
- Research report: `specs/023_document_mcp_registration_ownership_boundary/reports/01_mcp-registration-ownership-boundary.md`
- Canonical document produced: `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
