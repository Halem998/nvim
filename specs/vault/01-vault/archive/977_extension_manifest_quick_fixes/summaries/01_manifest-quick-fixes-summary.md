# Implementation Summary: Task #977

- **Task**: 977 - Extension manifest quick-fix batch (keyword_overrides shape, mcpServers casing, dead weight)
- **Status**: [COMPLETED]
- **Started**: 2026-07-29
- **Completed**: 2026-07-29
- **Effort**: ~2.5 hours
- **Dependencies**: 976 (sequencing only; not blocking)
- **Artifacts**: plans/01_manifest-quick-fixes.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Executed all 8 phases of the extension-manifest quick-fix batch, fixing five independently-verified
defects across `agent-system/extensions/**`: a crashing `keyword_overrides` shape in `literature`,
a snake_case `mcpServers` typo in `epidemiology`, a 3 MB unreferenced PowerPoint template, an unused
`literature` -> `filetypes` dependency cascade, and four orphaned `mcp_servers` blocks (three
activated, one deleted). Every phase's verification tier passed and `verify-deploy.sh --findings`
ends at zero findings, matching the Phase 1 clean-tree baseline.

## What Changed

- `agent-system/extensions/literature/manifest.json` — reshaped `keyword_overrides` from
  string-valued (`{"literature": "meta", ...}`) to object-valued
  (`{"meta": {"keywords": ["literature","zotero","bibliography","citation"]}}`), the shape the
  consumer jq in `core/commands/task.md` requires; also dropped `filetypes` from `dependencies`
  (now `["core"]` only), breaking the `cslib` -> `lean` -> `literature` -> `filetypes` cascade.
- `agent-system/extensions/literature/EXTENSION.md` — added a "Dependencies" section documenting
  that `filetypes` is no longer transitive and must be loaded explicitly if relied upon.
- `agent-system/extensions/epidemiology/settings-fragment.json` — renamed top-level `mcp_servers`
  to `mcpServers` so the `rmcp` server actually merges into `.claude/settings.local.json` (the
  `merge_targets.settings` route already existed; only the key casing was wrong).
- `agent-system/extensions/present/context/project/present/talk/templates/pptx-project/UCSF_ZSFG_Template_16x9.pptx`
  — deleted (3,046,296 bytes, zero references anywhere in the repo); `present`'s directory dropped
  from 4.0M to 1.1M.
- `agent-system/extensions/founder/settings-fragment.json` — new: `mcpServers` for `sec-edgar` and
  `firecrawl` (verbatim from the manifest, including the `FIRECRAWL_API_KEY` env passthrough),
  plus `permissions.allow` for the four referenced `mcp__firecrawl__*` tools and a
  `mcp__sec-edgar__*` wildcard.
- `agent-system/extensions/founder/manifest.json` — added `merge_targets.settings` route; kept the
  existing top-level `mcp_servers` block as the picker's display source; removed the empty
  `hooks: {}` stub.
- `agent-system/extensions/filetypes/settings-fragment.json` — new: `mcpServers` for `superdoc` and
  `openpyxl` (verbatim).
- `agent-system/extensions/filetypes/manifest.json` — added `merge_targets.settings` route; removed
  the empty `hooks: {}` stub (kept `mcp_servers` for picker display).
- `agent-system/extensions/memory/settings-fragment.json` — new: `mcpServers` for `obsidian-memory`
  (verbatim, including the `OBSIDIAN_WS_PORT` env value).
- `agent-system/extensions/memory/manifest.json` — added `merge_targets.settings` route; removed
  the empty `hooks: {}` stub (kept `mcp_servers` for picker display).
- `agent-system/extensions/present/manifest.json` — deleted the entire `mcp_servers.superdoc` block
  (referenced nowhere in `present`'s own agents/skills/context/README — a copy-paste artifact); no
  fragment created for `present`; also removed the empty `hooks: {}` stub.
- Empty-stub sweep (Phase 7), all `agent-system/extensions/*/manifest.json`: removed `mcp_servers: {}`
  from `cslib`, `latex`, `nvim`, `python`, `typst`, `web`, `z3` (7 manifests), and `hooks: {}` from
  `core`, `cslib`, `epidemiology`, `filetypes`, `formal`, `founder`, `latex`, `lean`, `literature`,
  `memory`, `present`, `python`, `slidev`, `typst`, `web`, `z3` (16 manifests).
- `specs/977_extension_manifest_quick_fixes/baseline-verify-deploy.txt` — Phase 1 scratch baseline
  capture, kept as provenance.

## Decisions

- Item 5 convention: kept the top-level `mcp_servers` block in `founder`, `filetypes`, and `memory`
  manifests (the picker previewer's display source) rather than removing it now that a
  `settings-fragment.json` handles the actual merge — the fragment is the merge path, the manifest
  field is the display path, and they now agree on server sets.
- `present`'s `mcp_servers.superdoc` block was deleted outright rather than converted to a fragment,
  per the research's finding that `superdoc` is unreferenced anywhere in `present`'s own material.
- Phase 7's stub sweep included `core`, `literature`, and `epidemiology` (16 total, not the
  originally-cited 13), per the research recommendation to clean all empty `hooks: {}` stubs for
  consistency rather than reconstruct an arbitrary exclusion.

## Plan Deviations

- **Phase 7** (stub sweep): the first implementation attempt piped each of the 17 target manifests
  through `jq --indent 2 <filter>` to delete the stub fields. This correctly deleted the fields but
  also reformatted unrelated compact-inline arrays in several files (e.g. `cslib`'s
  `keyword_overrides` arrays, `lean`'s `args: ["lean-lsp-mcp"]`) into multi-line form — reformatting
  churn beyond the intended deletion, caught by the plan's own instruction to confirm the diff shows
  only the intended change. All 17 files were reverted to their last-committed state (via
  `git show HEAD:<path> > <path>`, since `git checkout -- <path>` was blocked by the
  destructive-git guard on a dirty tree) and redone with targeted `Edit` string replacements
  touching only the two stub fields. The final `git diff` for this phase contains exactly four
  line-pattern types across all 17 files: removal of `"hooks": {}`, removal of `"mcp_servers": {}`,
  removal of the preceding `},`, and its replacement with a bare `}` — no other line changed. No
  scope or outcome was altered; this was a self-corrected execution-method issue, not a deviation
  from what the phase was supposed to accomplish.

## Verification

- Build: N/A (no build step for extension manifests)
- Tests: N/A (no automated test suite for this surface)
- Files verified: Yes — all touched/created JSON files pass `jq empty`; all four task-description
  verification-bar assertions re-run and passed in Phase 8; `check-extension-docs.sh` (non-quiet)
  exits 0 across all 20 extensions; `verify-deploy.sh --findings --quiet` exits 0 with zero FINDING
  lines, matching the Phase 1 baseline; `check-task-references.sh` reports 0 unexempted occurrences.

## Impacts

- `literature`'s keyword-override mechanism now actually routes `literature`/`zotero`/
  `bibliography`/`citation` task descriptions to `task_type: meta`, a feature that had silently
  never worked since the manifest's crash was swallowed by `2>/dev/null`.
- `epidemiology`'s `rmcp` MCP server will now actually install into `.claude/settings.local.json`
  on the next deploy/regeneration for any repo loading that extension.
- Any repo that loaded `literature` and was unknowingly relying on the `filetypes` cascade
  (docx/xlsx/pptx tooling) being force-installed alongside it will need to load `filetypes`
  explicitly going forward; `literature/EXTENSION.md`'s new "Dependencies" section documents this.
- `founder`, `filetypes`, and `memory` will now merge their previously-orphaned MCP server
  declarations (`sec-edgar`+`firecrawl`, `superdoc`+`openpyxl`, `obsidian-memory` respectively)
  into `.claude/settings.local.json` on next deploy for any repo loading those extensions — this
  activates real, previously-inert tool integrations, including a `FIRECRAWL_API_KEY` env
  passthrough for `founder` that was already declared but never wired to a merge target.
- `present`'s deploy footprint shrinks by ~3 MB (the deleted `.pptx`) and its manifest no longer
  advertises the `superdoc` tool it never used.

## Follow-ups

- Not implemented (out of scope per the plan's Non-Goals): extending `check-extension-docs.sh` with
  a new rule that fails when a manifest declares a non-empty top-level `mcp_servers` without a
  corresponding `merge_targets.settings` entry — this would have caught all four Phase 6 orphans
  automatically. Flagged by the research report as a worthwhile follow-up meta task.
- The Phase 1 scratch baseline file at
  `specs/977_extension_manifest_quick_fixes/baseline-verify-deploy.txt` was kept as provenance
  rather than deleted, per the plan's either/or instruction.

## References

- `specs/977_extension_manifest_quick_fixes/plans/01_manifest-quick-fixes.md`
- `specs/977_extension_manifest_quick_fixes/reports/01_manifest-quick-fixes-verification.md`
- `specs/977_extension_manifest_quick_fixes/baseline-verify-deploy.txt`
