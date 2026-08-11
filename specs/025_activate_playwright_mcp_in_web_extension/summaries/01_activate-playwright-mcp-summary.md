# Implementation Summary: Task #25

- **Task**: 25 - Activate the already-designed but parked Playwright MCP integration in the web extension, and reconcile its drifted tool list against the live server.
- **Status**: [COMPLETED]
- **Started**: 2026-08-10T23:38:00Z
- **Completed**: 2026-08-11T01:00:00Z
- **Effort**: 1.75 hours
- **Dependencies**: None (prerequisite MCP registration and `settings-fragment.json` allowlist work already committed)
- **Artifacts**: plans/01_activate-playwright-mcp.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This was a verify-and-close-gaps task, not a from-scratch build: the activation edits (flipping
the Playwright MCP subsection from deferred to active, creating `playwright-mcp-guide.md`, and
updating the web extension README) had already been made and committed as `1610a6a35` by an
earlier, over-reaching research dispatch. This plan independently re-verified every acceptance
criterion against file contents on disk, closed the one real gap the audit found, and recorded
an explicit, evidenced decision on the one open question — without re-authoring any already-
satisfactory prose.

## What Changed

- `agent-system/extensions/web/index-entries.json` — corrected the `line_count` of the
  `project/web/README.md` entry from `110` to `116` (the true line count after the prior
  dispatch's README edit added 6 lines without updating the declared count).
- `specs/025_activate_playwright_mcp_in_web_extension/plans/01_activate-playwright-mcp.md` —
  checked off all five phases with evidence annotations.
- `specs/025_activate_playwright_mcp_in_web_extension/progress/phase-{1,2,3,4}-progress.json` —
  created, recording per-objective evidence.
- `specs/025_activate_playwright_mcp_in_web_extension/.return-meta.json` — status tracking.

No other source-store files required edits: every other acceptance criterion was already
satisfied by the prior dispatch's committed work (see Verified No-Ops below).

## Decisions

- Fixed the `line_count` drift with a single scoped numeric-field edit rather than running
  `generate-context-line-counts.sh --write`, which would have rewritten counts across all 20
  extensions and produced an unreviewable out-of-scope diff.
- Recorded the `.opencode` stale-copy question as **Branch 3: independently-maintained live
  deliverable** (see Recorded Decision below) and made no edit there, per the binding
  source-store rule.

## Gaps Closed

- **`line_count` drift** (Phase 2): `agent-system/extensions/web/index-entries.json`'s
  `project/web/README.md` entry declared `line_count: 110` while the file actually had 116
  lines after the prior dispatch's edit. Before: `REPO_ROOT=$(pwd) bash
  .claude/scripts/check-extension-docs.sh` reported `FAIL: Rule R: index-entries.json entry
  'project/web/README.md' line_count mismatch: declared 110, actual 116` and `web FAIL` in the
  Summary table. After: the field was corrected to `116`, `generate-context-line-counts.sh
  --check` confirmed `web: 24 entries, 24 exact, 0 mismatch`, and the gate re-run reported
  `web PASS`.

## Verified No-Ops

All seven Phase 3 acceptance criteria were already satisfied by the prior dispatch's committed
work and required no rework:

1. **Research agent's block unchanged** — `web-research-agent.md` line 4 still reads
   `disallowedTools: mcp__playwright__*`; the file is absent from commit `1610a6a35`'s changed-file
   list. The symmetric `disallowedTools: mcp__context7__*` on `web-implementation-agent.md` line 4
   also survives.
2. **No guidance depends on a prompting tool** — every `browser_*` name appearing in an
   instruction-to-act position across `web-implementation-agent.md` and `playwright-mcp-guide.md`
   falls inside the unprompted 9 (`browser_navigate`, `browser_snapshot`,
   `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests`,
   `browser_click`, `browser_type`, `browser_find`, `browser_wait_for`). The three escape hatches
   (`browser_evaluate`, `browser_file_upload`, `browser_run_code_unsafe`) appear only inside
   prohibition sentences.
3. **9-tool list matches the allowlist exactly** — `settings-fragment.json`'s
   `permissions.allow`, `web-implementation-agent.md`'s "Unprompted tools" bullet, and
   `playwright-mcp-guide.md`'s "Permission Tiers" section all name the identical 9 tools.
4. **24-tool reference is accurate** — the guide's tool table (8 category rows summing to 24)
   matches the live `mcp__playwright__*` surface exactly, including both `browser_network_request`
   (singular) and `browser_network_requests` (plural) as distinct real tools.
5. **No invented tool name survives as usable guidance in the source store** —
   `grep -rn "browser_verify_text_visible" agent-system/extensions/web/` finds exactly 2 hits
   (`web-implementation-agent.md:72`, `playwright-mcp-guide.md:43`), both stating the tool does
   **not** exist and mapping the intent onto `browser_find`/`browser_wait_for`. Both are
   deliberate corrections and were preserved unedited.
6. **Deferred status genuinely flipped** — the Playwright subsection reads `**Playwright MCP**
   (active)` / `**Status**: Active`, with no `deferred`/`not yet active`/pending-installation
   phrasing remaining, and all three preserved usage conditions (prefer snapshots; do not use for
   what `pnpm build` verifies alone; only when the plan includes a visual/debug/e2e step) intact.
7. **`mcp-server-ownership.md` reference follows house convention** — the source file exists at
   `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`; the guide's
   `@.claude/context/patterns/mcp-server-ownership.md` reference is consistent with the agent
   file's own `@.claude/context/project/web/...` convention (both absent from this undeployed
   repo, not dangling).

## Research-Report Corrections

- The research report's flagged "known gap" — that `check-extension-docs.sh` "could not be run
  from the source-store tree" — is false. The script's `EXT_DIR` defaults to
  `$REPO_ROOT/agent-system/extensions`; it lints the source store, not a deploy tree, and its own
  header documents the `REPO_ROOT=$(pwd)` override for exactly this invocation. Phase 1 ran it
  successfully: `REPO_ROOT=$(pwd) bash .claude/scripts/check-extension-docs.sh`.
- Running that gate surfaced a real `FAIL` the report asserted did not exist (the `line_count`
  drift above), closing the report's flagged "compensating check" question with a real run
  rather than an assertion.

## Recorded Decision: `.opencode` Stale-Copy Question

`.opencode/extensions/web/agents/web-implementation-agent.md` line 57 still presents
`` `browser_verify_text_visible` -- Assert text is visible on page `` as a usable tool, and its
Playwright subsection still reads `Deferred pending browser binary installation`.

**Branch selected: independently-maintained live deliverable.** Evidence:
- No live deploy script writes `.opencode/extensions/`; only a `deprecated/` script
  (`validate-extension-index.sh`) mentions the path.
- The commit titled `task 941 phase 12.2: purge .opencode/extensions/{present,web}` (`80f967a7f`)
  in fact touched only 8 unrelated lines of this file (co-author-string cleanup) — the directory
  was never actually purged, despite the misleading title, and remains git-tracked today.
- The `.opencode` copy uses `@.opencode/context/project/web/...` reference paths, distinct from
  the source-store file's `@.claude/context/project/web/...` convention, and diverges in
  frontmatter/wording beyond the Playwright section — consistent with a hand-maintained parallel
  copy, not a stale generated snapshot.
- `git log` shows the file is updated only via deliberate, task-driven "mirror" commits (e.g.
  `task 167 phase 4: mirror changes to .opencode/`, `task 395 phase 2: update opencode mirror
  references`), never by automated regeneration.

**Decision**: the acceptance criterion "no invented tool names survive anywhere" is **not fully
met** outside the source store. No edit was made under this plan — the binding source-store rule
scopes all edits to `agent-system/extensions/web/**`, and this plan's non-goals explicitly forbid
`.opencode` edits. **Recommended follow-up**: a separate, scoped task to mirror the activated
Playwright section into `.opencode/extensions/web/agents/web-implementation-agent.md`, following
the same pattern as the prior "mirror changes to .opencode/" tasks.

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (documentation/context task)
- Tests: N/A
- Doc-lint gate: `web PASS` (was `web FAIL` before Phase 2); `core FAIL` and `literature FAIL`
  unchanged from the Phase 1 baseline (pre-existing, unrelated to this task).
- `agent-system/extensions/web/index-entries.json`: valid JSON, confirmed via
  `python3 -c "import json;json.load(open(...))"`.
- `generate-context-line-counts.sh --check`: `web: 24 entries, 24 exact, 0 mismatch`.
- Working-tree diff for this task confined to `agent-system/extensions/web/index-entries.json`
  plus `specs/**`; `git status --short .claude .opencode` empty.
- Files verified: Yes

## Impacts

- The web extension's Playwright MCP guidance is now internally consistent (three tool-list
  sources — `settings-fragment.json`, `playwright-mcp-guide.md`,
  `web-implementation-agent.md` — agree exactly) and passes the doc-lint gate.
- The `.opencode` mirror now has a documented, evidenced staleness gap and a recommended
  follow-up task, rather than a silently-drifted copy.

## Follow-ups

- Recommended: a scoped follow-up task to mirror the activated Playwright MCP section from
  `agent-system/extensions/web/agents/web-implementation-agent.md` into
  `.opencode/extensions/web/agents/web-implementation-agent.md`, replacing the stale
  `browser_verify_text_visible` reference and the "deferred" status there.
- Pre-existing `core` and `literature` doc-lint `FAIL`s (unrelated to this task: a deployed-script
  content drift in `core`, and a separate `line_count` mismatch in `literature`) remain open and
  out of scope.
- The `routing target not deployed` warnings for `skill-web-research`/`skill-web-implementation`
  remain, as expected — the web extension is not installed in this repo.

## References

- Plan: `specs/025_activate_playwright_mcp_in_web_extension/plans/01_activate-playwright-mcp.md`
- Research report: `specs/025_activate_playwright_mcp_in_web_extension/reports/01_activate-playwright-mcp.md`
- Prior activation commit: `1610a6a35` (task 25: complete research)
- Progress files: `specs/025_activate_playwright_mcp_in_web_extension/progress/phase-{1,2,3,4}-progress.json`
