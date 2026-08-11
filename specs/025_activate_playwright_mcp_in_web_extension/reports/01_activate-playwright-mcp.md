# Research Report: Task #25

**Task**: 25 - Activate the already-designed but parked Playwright MCP integration in the web extension, and reconcile its drifted tool list against the live server.
**Started**: 2026-08-10T23:38:00Z
**Completed**: 2026-08-10T23:45:00Z
**Effort**: small
**Dependencies**: None (prerequisite MCP registration and settings-fragment.json work already committed)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/web/agents/web-implementation-agent.md`, `web-research-agent.md`, `settings-fragment.json`, `manifest.json`, `index-entries.json`, `context/project/web/README.md`, `context/project/web/tools/debugging-utilities.md`
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` (canonical registration/permission reference)
**Artifacts**:
- `agent-system/extensions/web/agents/web-implementation-agent.md` (edited)
- `agent-system/extensions/web/context/project/web/tools/playwright-mcp-guide.md` (new)
- `agent-system/extensions/web/context/project/web/README.md` (edited)
- `agent-system/extensions/web/index-entries.json` (edited)
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- This was an activation task with a fully specified design already in place; the only work
  was flipping status, fixing drifted tool names against the real 24-tool Playwright MCP
  surface, and adding "when to drive a browser" guidance consistent with the 9-tool
  unprompted/15-tool prompting permission split established by the prerequisite
  `settings-fragment.json` work.
- `web-implementation-agent.md`'s Playwright MCP subsection is now "active" and lists the real
  tool set; the non-existent `browser_verify_text_visible` reference was replaced with guidance
  to use `browser_find` (presence) or `browser_wait_for` (text becomes visible within a timeout).
- A new context file, `playwright-mcp-guide.md`, holds the full 24-tool reference, the
  unprompted/prompting split, and worked "when to drive a browser" scenarios (visual
  verification, console/network debugging, end-to-end UI checks), registered in
  `index-entries.json` scoped to `web-implementation-agent` only.
- `web-research-agent.md`'s `disallowedTools: mcp__playwright__*` line was read and confirmed
  unchanged — the role-scoping split (research blocks Playwright, implementation blocks
  Context7) is intact.
- All edits targeted the source store under `agent-system/extensions/web/**`; no `.claude/**`
  paths were hand-edited.

## Context & Scope

Task 25 asked to activate a previously-deferred Playwright MCP design in
`web-implementation-agent.md` (the "deferred -- not yet active" block, status "Deferred pending
browser binary installation"), now that the browser-binary precondition is satisfied and the
server is registered and connected with 24 `browser_*` tools. Scope was: (1) flip deferred to
active, (2) preserve existing usage conditions, (3) reconcile the drifted tool list (the deferred
spec named a tool, `browser_verify_text_visible`, that does not exist on the live server), (4)
add "when to drive a browser" guidance in a new context file, and (5) keep guidance consistent
with the just-completed permission split (9 unprompted tools vs. 15 prompting tools, with three
of those 15 -- `browser_evaluate`, `browser_file_upload`, `browser_run_code_unsafe` -- singled out
as escape hatches that must never be depended on).

## Findings

### Codebase Patterns

- The deferred block lived at `web-implementation-agent.md` lines ~50-63, immediately after the
  Astro Docs MCP subsection, both under a `## MCP Tools (when configured)` heading.
- `web-research-agent.md` line 4 carries `disallowedTools: mcp__playwright__*`;
  `web-implementation-agent.md` line 3 carries `disallowedTools: mcp__context7__*`. This is the
  documented symmetric role split (research reads docs via Context7, implementation drives
  browsers via Playwright) and was left untouched.
- `settings-fragment.json` (already committed, prerequisite work) allowlists exactly 9 tools:
  `browser_navigate`, `browser_snapshot`, `browser_take_screenshot`,
  `browser_console_messages`, `browser_network_requests`, `browser_click`, `browser_type`,
  `browser_find`, `browser_wait_for`. It is wired via `manifest.json`'s
  `merge_targets.settings` to `.claude/settings.local.json`.
- `mcp-server-ownership.md`'s "Carve-out: safe/unsafe tool splits require enumeration" section
  explicitly names this exact enumeration as the worked example for why a safe/unsafe split
  must use enumeration rather than a wildcard, and calls out the same three escape-hatch tools
  (`browser_evaluate`, `browser_file_upload`, `browser_run_code_unsafe`) as deliberately excluded.
  My new guidance file cites this document directly rather than re-deriving the rationale.
- The web extension's `context/project/web/tools/` directory already holds a
  `debugging-utilities.md` pattern (CLI tool reference, "When to use" per tool, tool-availability
  check commands) that the new `playwright-mcp-guide.md` follows structurally, and both README.md
  and `index-entries.json` list every tools/ file, so the new file was registered in both places
  for consistency with the existing convention (registration in `index-entries.json` was also an
  explicit task requirement).
- `index-entries.json` entries for implementation-only files (e.g. the two `templates/*.md`
  entries) scope `load_when.agents` to `["web-implementation-agent"]` only, without
  `web-research-agent`. The new Playwright guide entry follows that same convention since
  `web-research-agent` is blocked from `mcp__playwright__*` entirely and has no use for the file.

### External Resources

None required — this was a codebase-internal reconciliation task with no external documentation
lookups needed; the "real 24-tool set" was supplied directly in the task description and cross-
checked against the `mcp__playwright__*` deferred-tool listing visible in this session's tool
manifest.

### Recommendations

- Keep the three escape-hatch tools (`browser_evaluate`, `browser_file_upload`,
  `browser_run_code_unsafe`) out of every allow-listed usage recommendation project-wide, not
  just in this one file — any future web-extension guidance that touches Playwright should link
  back to `playwright-mcp-guide.md` rather than re-deriving the safe/unsafe split.
- If the Playwright server's tool surface changes again in the future (new tools added, existing
  ones renamed), update `settings-fragment.json`'s enumeration, `playwright-mcp-guide.md`'s tool
  reference table, and `web-implementation-agent.md`'s "Unprompted tools" list together — the
  three files list overlapping tool subsets that must stay in sync, and none of them wildcards
  automatically as the server grows (see the "Carve-out" section of `mcp-server-ownership.md`).

## Decisions

- Replaced the non-existent `browser_verify_text_visible` with a two-tool mapping
  (`browser_find` for "is it there now", `browser_wait_for` for "does it become visible within a
  timeout") rather than picking a single substitute, since the deferred spec's one tool actually
  covered two distinct assertion shapes.
- Placed the new context file at `context/project/web/tools/playwright-mcp-guide.md` (alongside
  `debugging-utilities.md`) rather than under `domain/` or `patterns/`, since it is a
  tool-specific reference (tool names, permission tiers) rather than a language/framework domain
  concept or a reusable code pattern.
- Scoped the new `index-entries.json` load_when.agents to `web-implementation-agent` only (not
  `web-research-agent`), matching the disallowedTools split rather than the broader
  `["web-research-agent", "web-implementation-agent"]` pattern used by most other web/ context
  files.
- Also updated `context/project/web/README.md`'s directory tree, loading-strategy section, and
  "Agent Context Loading" table for consistency with the existing self-documenting convention in
  that file, even though the task's acceptance criteria did not explicitly require it.

## Risks & Mitigations

- **Risk**: `check-extension-docs.sh` (the doc-lint gate that validates extension READMEs,
  manifests, and cross-references) could not be run from the source-store tree in this session
  — it requires a deployed `.claude/scripts/` or `.opencode/scripts/` copy and errors out when
  invoked directly from `agent-system/extensions/core/scripts/`. **Mitigation**: none of the
  edits change any manifest-declared file lists, agent frontmatter keys, or cross-reference
  targets that this lint checks structurally beyond what was verified manually (JSON validity of
  `index-entries.json` confirmed via `python3 -c "json.load(...)"`; the new file path matches the
  `context: ["project/web"]` glob already declared in `manifest.json`). A full deploy-and-relint
  pass is recommended before this task is marked complete, but was out of scope for research-only
  verification in this session.
- **Risk**: three files now separately enumerate overlapping Playwright tool-name lists
  (`settings-fragment.json`, `playwright-mcp-guide.md`, `web-implementation-agent.md`'s
  "Unprompted tools" bullet). **Mitigation**: documented explicitly in Recommendations above so a
  future edit to one is not made in isolation.

## Context Extension Recommendations

- **Topic**: Playwright MCP browser automation guidance for the web extension.
- **Gap**: Prior to this task, `web-implementation-agent.md`'s Playwright section was the only
  place this was documented, and it named a non-existent tool and an inactive status; there was
  no standalone context file a research or planning pass could load independently of the agent
  file.
- **Recommendation**: Addressed directly in this task via the new
  `context/project/web/tools/playwright-mcp-guide.md` file — no further gap remains for this
  topic.

## Appendix

- Files read: `web-implementation-agent.md`, `web-research-agent.md`, `settings-fragment.json`,
  `manifest.json`, `index-entries.json`, `README.md`, `debugging-utilities.md`,
  `mcp-server-ownership.md`.
- Files edited: `web-implementation-agent.md` (Playwright MCP subsection + Context References
  list), `context/project/web/README.md` (directory tree, loading strategy, agent context
  loading table), `index-entries.json` (new entry for `playwright-mcp-guide.md`).
- File created: `context/project/web/tools/playwright-mcp-guide.md`.
- No files under `.claude/**` were edited (source-store-deploy-boundary.md compliance).
- No task-number citations were introduced in any deliverable outside `specs/**`.
