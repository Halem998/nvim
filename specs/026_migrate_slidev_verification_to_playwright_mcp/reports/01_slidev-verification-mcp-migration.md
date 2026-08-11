# Research Report: Task #26

**Task**: 26 - Migrate slidev deck verification from standalone npm Playwright script to MCP server
**Started**: 2026-08-10T23:38:00Z
**Completed**: 2026-08-10T23:59:00Z
**Effort**: 3-6 hours
**Dependencies**: 24 (scoped Playwright MCP permission allowlist) — completed
**Sources/Inputs**: Codebase read (present/founder extensions, web extension, core ownership doc), specs/state.json (tasks 23, 24, 26 records)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The playwright-chromium npm devDependency in Slidev deck projects serves **two distinct
  purposes** that the task description conflates: (1) `slidev export`'s own internal PDF-export
  pipeline, which is a hard, unremovable dependency of `@slidev/cli` itself, and (2)
  `playwright-verify.mjs`'s own independent browser-launch/navigate/screenshot loop, which is the
  actual "second Playwright install path" duplicating the MCP server's capability. Only (2) is
  in scope for removal; (1) is untouched by this task.
- Founder's two file-scope entries (`deck-builder-agent.md`,
  `founder/context/project/founder/patterns/slidev-deck-template.md`) reference
  playwright-chromium **only** in the context of purpose (1) — PDF-export availability detection
  and export documentation. Founder has no per-slide verification loop at all today; it never
  calls `playwright-verify.mjs`. Both files need **no functional change** — the report recommends
  leaving them as-is with an explicit note recorded here so a future reader does not mistake the
  omission for an oversight.
- The verification loop's four checks map onto MCP tools with different fidelity:
  navigation (`browser_navigate`), screenshot capture (`browser_take_screenshot`), and console
  error capture (`browser_console_messages`) all map cleanly onto already-allowlisted safe tools.
  The blank-slide/visible-error-text check (`page.evaluate(() => document.body.innerText...)`)
  has no clean match — the tool that would replicate it exactly, `browser_evaluate`, is
  deliberately unpermissioned and prompts. `browser_snapshot`'s accessibility-tree text is the
  closest safe substitute, but it is a qualitative proxy, not a byte-for-byte equivalent of an
  `innerText.length` threshold.
- **Recommended outcome is "migrate X, keep Y," not a full migration**: keep
  `playwright-verify.mjs` (and its npm playwright-chromium dependency) as the required, default,
  batch full-deck verification phase — it is deterministic, exit-code-driven, and far cheaper
  than N agent-tool-call round trips for an N-slide deck. Add Playwright MCP tools as a
  **documented, optional, ad hoc single-slide debugging capability** for agents fixing one broken
  slide interactively, which the script cannot offer without a human re-running it. This
  discharges the acceptance criterion's alternate branch ("its continued existence is explicitly
  justified in writing") rather than the primary branch ("removed").
- **Scope-note finding, confirmed as a real gap**: neither `present` nor `founder` currently
  receives the `web` extension's Playwright permission grant. `present` declares dependencies on
  `["core", "slidev"]` only and has **no `settings-fragment.json` at all** and **no `settings`
  entry in `manifest.json`'s `merge_targets`**. `founder` declares the same dependency set and
  does have a `settings-fragment.json`, but it grants only `firecrawl`/`sec-edgar` tools — no
  Playwright entries. Adding the optional MCP debugging capability therefore requires new
  permission-grant plumbing in `present` (and, if founder ever adds its own visual-verification
  phase, in `founder`) — it does not arrive "for free" from the `web` extension's prior work.

## Context & Scope

Researched: the full playwright-related reference set named in the task description across
`present` and `founder`, the `web` extension's settings-fragment (prerequisite, already
completed as task 24), the canonical `mcp-server-ownership.md` pattern (task 23's deliverable),
and every agent/skill in `present`/`founder` that touches Playwright, screenshots, or slide
verification, to establish (a) what the standalone script actually does, (b) which files
genuinely need updating vs. which merely mention `playwright-chromium` for an unrelated reason,
and (c) whether the permission-grant scope note in the task is a real gap or already solved.

## Findings

### Codebase Patterns

**The `.mjs` script's actual behavior** (`present/context/project/present/talk/templates/playwright-verify.mjs`):
1. Spawns its own Slidev dev server via `npx @slidev/cli --port 3099` (detached child process),
   polling `fetch(BASE)` until ready.
2. Parses `slides.md` locally to count slide separators (pure string logic, not
   Playwright-related).
3. Launches its own `playwright-chromium` browser instance (`chromium.launch()`), independent of
   any MCP server session.
4. For each slide: navigates to `localhost:{port}/{i}`, waits for `networkidle` + a fixed 2s
   settle (for Mermaid rendering), then via `page.evaluate()`:
   - checks `document.body.innerText.includes('An error occurred on this slide')`
   - checks `document.body.innerText.trim().length < 30` (blank-slide proxy)
   - separately listens to `page.on('pageerror', ...)` and `page.on('console', ...)` for
     uncaught exceptions / `console.error` calls
   - optionally screenshots via `page.screenshot()`
5. Kills the dev server and browser, exits 0/1 based on aggregate pass/fail — a **deterministic,
   scriptable exit code**, callable with no agent or human in the loop.

**Where the verification phase is actually wired in**: only
`present/context/project/present/talk/patterns/slidev-pitfalls.md`'s "Required Final Phase:
Playwright Verification" section mandates this script as a plan phase (`### Phase N: Playwright
Slide Verification`), consumed by whichever agent executes present's Slidev implementation plans
(routing: `implement.present:slides -> skill-slides:assemble -> slidev-assembly-agent`).
`slidev-assembly-agent.md`'s own "Allowed Tools" section lists only Read/Write/Edit/Glob/Grep/Bash
— **no MCP tools are declared today**, and the phase currently runs the script purely via `Bash`
(`node scripts/verify-slides.mjs --screenshots`), which needs no MCP permission at all.

**Founder has no equivalent phase.** `founder/agents/deck-builder-agent.md`'s only
Playwright-related content is a Stage 2.5 CLI availability probe (`npx playwright --version`)
gating a Stage 8 "Non-Blocking PDF Export" (`slidev export ... --output ...`) — this is capability
detection for `slidev export`, not a call into `playwright-verify.mjs` or any per-slide check.
`founder/context/project/founder/patterns/slidev-deck-template.md`'s two Playwright mentions are
both `**Export**: slidev export (requires playwright-chromium for PDF)` documentation lines with
identical scope. Grepping `deck-planner-agent.md` and `deck-builder-agent.md` for any
"Playwright Verification"-style phase found none — founder's deck pipeline validates only file
existence, referenced-component presence, and slide count via `---` separator counting; it never
opens a browser to inspect rendered output at all. **Conclusion: these two founder files require
no functional edit under this task; the correct action is to leave them unchanged and record that
decision here so the file-scope list in the task description is not read as an implicit TODO.**

**Other reference sites, confirmed as pure prose/index pointers with no independent logic**:
- `present/context/project/present/domain/talk-modes-and-library.md` line 29: one table cell,
  "...a Playwright verification script."
- `present/context/project/present/talk/templates/slidev-project/README.md` line 10: one
  package.json-purpose table row mentioning `playwright-chromium`.
- `present/index-entries.json` (around line 953) and
  `present/context/project/present/talk/index.json` (line 63): index/catalog entries pointing at
  `playwright-verify.mjs`.

All four are downstream of whatever decision is made about the script's fate — they need
wording updates to match the final outcome (script kept with a stated purpose vs. removed), not
independent research.

**`playwright-chromium`'s dual role is the key parity fact.** The project scaffold's
`package.json` (`present/.../talk/templates/slidev-project/package.json`) pins
`playwright-chromium` as a `devDependency` with `"export": "slidev export"` as an npm script.
`slidev-deck-template.md` and `slidev-project/README.md` both independently document that
`slidev export` (Slidev's own PDF pipeline) requires `playwright-chromium` directly — this is
`@slidev/cli`'s own dependency, unrelated to the custom `.mjs` script's import of the same
package. **This means the npm `playwright-chromium` install cannot be fully removed from
generated Slidev projects under any outcome of this task** — `pnpm run export` needs it
regardless of what happens to the verification script. The "duplicate install path" the task
asks to eliminate is the *second independently-orchestrated browser-automation codepath* (the
script's own `chromium.launch()`/`page.goto()`/`page.evaluate()` loop), not the npm package pin
itself.

### External Resources

Not applicable — this was a pure codebase/architecture research task; no external documentation
was needed beyond what was already gathered in the two prerequisite tasks (23, 24).

### Recommendations

**1. Keep `playwright-verify.mjs` as the required batch/full-deck verification mechanism**, with
its role reframed and re-justified in `slidev-pitfalls.md` rather than silently left in place.
Rationale, in order of weight:

- **Determinism/CI capability**: the script's exit code is the only mechanism in this system that
  can gate a build without a human or agent turn per check. MCP tool calls always require a live
  agent turn — there is no headless/CI entry point for `browser_navigate` et al. If this
  capability is ever needed (e.g., a future CI step gating deck PRs), only the script provides it.
- **Cost/efficiency at scale**: an N-slide deck needs 4 MCP tool round-trips per slide
  (navigate → console_messages → snapshot → take_screenshot) if replicated faithfully — for a
  30-40 slide deck that is 120-160 agent tool calls in one turn sequence, against one `node`
  invocation today. This is a real efficiency regression, not just an aesthetic one.
- **Fidelity of the blank/error-text check**: `page.evaluate()`'s exact `innerText.length < 30`
  threshold and `.includes('An error occurred on this slide')` string match have no permissioned
  equivalent. `browser_evaluate` is deliberately unpermissioned (per the prerequisite web-extension
  work, this is intentional and "not going to change"). `browser_snapshot`'s accessibility tree is
  the nearest safe substitute but changes the check from a mechanical byte threshold to an
  agent's qualitative read of the snapshot — a legitimate but *different* check, not a drop-in
  replacement. (Note also: `browser_console_messages`' ability to surface uncaught
  `pageerror`-style exceptions the same way `page.on('pageerror', ...)` does was not verified
  empirically in this research pass — the tool's documented purpose is console messages, and
  Playwright's own `pageerror` event is a distinct channel from `console`; whichever agent
  implements this should verify this behavior against a real deck with an injected `pageerror`
  before relying on it, rather than assume parity.)

**2. Add Playwright MCP tools as a documented, optional, ad hoc capability** for interactive
single-slide debugging — e.g., an agent that just fixed one broken slide can
`browser_navigate` directly to `localhost:{port}/{i}` and `browser_take_screenshot` /
`browser_snapshot` to visually confirm the fix, without re-running the full batch script or
waiting on a human. This is a genuine, additive use of the MCP server that the standalone script
cannot offer (the script's dev-server lifecycle is start-all/stop-all, not "check just this one
slide right now while I'm mid-edit"). Suggested edit: a new subsection in `slidev-pitfalls.md`
("Ad Hoc Single-Slide Inspection via MCP") documenting this workflow, distinct from the "Required
Final Phase" batch section, with an explicit note that it complements rather than replaces the
batch script.

**3. This outcome satisfies the acceptance criterion's alternate branch explicitly**: "the
duplicate npm Playwright install path is removed, **or its continued existence is explicitly
justified in writing**." The justification above (determinism/CI, cost, and blank-check fidelity)
is that writing. Reframe `slidev-pitfalls.md`'s current "Required Final Phase" section to state
this justification inline (near the "NixOS Playwright Workaround" section, which already
acknowledges the script needs environment-specific handling) rather than leaving the script's
continued presence unexplained.

**4. Permission-grant plumbing is a required implementation step regardless of outcome #1/#2's
exact shape**, because recommendation #2 needs `mcp__playwright__*` tools to be non-prompting for
whichever agent uses them (currently `slidev-assembly-agent`, which the acceptance criteria imply
should gain this capability). Concretely:

- `present/manifest.json` currently has **no `settings` entry** in `merge_targets` at all (only
  `claudemd`, `index`, `opencode_json`) and **no `settings-fragment.json` file exists** in the
  `present` extension directory. Both need to be created, mirroring the exact pattern task 24
  established for `web`: a new `present/settings-fragment.json` with `permissions.allow` listing
  the same 9 safe tool names, plus a `"settings": {"source": "settings-fragment.json", "target":
  ".claude/settings.local.json"}` block added to `present/manifest.json`'s `merge_targets`.
- Per the carve-out rule in `mcp-server-ownership.md` ("Carve-out: safe/unsafe tool splits require
  enumeration"), a `mcp__playwright__*` wildcard is **not** an option here — it would silently
  re-permit `browser_evaluate`/`browser_file_upload`/`browser_run_code_unsafe`, which is exactly
  the hole the prerequisite task closed. The 9-tool enumeration must be copied verbatim into
  `present`'s new fragment (accepting the same documented drift cost `mcp-server-ownership.md`
  already accepts for `web`'s copy — a new safe tool added to Playwright's surface would need this
  list updated in both places).
- An alternative considered and **not recommended**: adding `"web"` to `present`'s (and
  `founder`'s) `dependencies` array so `web`'s fragment auto-merges via the existing
  dependency-auto-load mechanism (`extension-development.md`'s documented auto-load-on-parent-load
  behavior). This was rejected because it also pulls in `web`'s unrelated agents
  (`web-implementation-agent`, `web-research-agent`), skills, and the `web-astro.md` rule into
  every `present`/`founder` deployment — a domain-boundary violation for a grant that
  `mcp-server-ownership.md`'s own domain-ownership language ("belong in that extension's own
  settings-fragment.json") argues should live in `present`'s own fragment, since `present` is
  itself a direct consumer of the tool, not merely inheriting it from `web`.
- `slidev-assembly-agent.md`'s "Allowed Tools" section also needs the specific
  `mcp__playwright__browser_navigate` / `browser_snapshot` / `browser_take_screenshot` /
  `browser_console_messages` tool names added under a new "MCP Tools" subsection, matching the
  pattern of its existing "File Operations"/"Build Tools" subsections — the settings-fragment
  grant alone governs *prompting*, not whether the agent's own contract authorizes calling the
  tool at all.
- **`founder` does not need this plumbing under this task's scope** — it has no verification
  phase to attach MCP tools to. If a future task adds visual/screenshot-based verification to
  `deck-builder-agent`, it would need the identical treatment (new/extended fragment entry +
  Allowed Tools addition) at that time; this report does not add it speculatively.

## Decisions

- Founder's two file-scope entries need no functional edit; document why rather than silently
  skip them, so the eventual implementation summary doesn't read as incomplete against the task's
  named file list.
- Recommend a "keep the batch script, add MCP for ad hoc debugging" outcome rather than a full
  migration — consistent with the task's own explicit invitation to reach this kind of result.
- Recommend `present` receive its own new `settings-fragment.json` (9-tool enumeration, copied
  from `web`'s) plus a `manifest.json` `merge_targets.settings` entry, rather than adding `web` as
  a manifest dependency.
- Recommend `slidev-assembly-agent.md` gain an explicit MCP Tools entry in its Allowed Tools
  section, scoped to the 4 tools actually needed for ad hoc single-slide inspection
  (`browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_console_messages`).

## Risks & Mitigations

- **Risk**: `browser_console_messages` may not surface uncaught `pageerror`-style exceptions the
  same way the script's `page.on('pageerror', ...)` listener does, silently narrowing error
  coverage if adopted uncritically for the ad hoc path. **Mitigation**: the planner/implementer
  should note this as an open verification item and test against a deck with a deliberately
  broken component before treating MCP-based console checking as equivalent coverage to the
  script's dual pageerror+console listeners.
- **Risk**: enumerating the same 9-tool safe list in three places (`web`, `present`, and
  potentially `founder` later) drifts if the Playwright MCP server's safe-tool set ever changes.
  **Mitigation**: this is an accepted, already-documented cost per `mcp-server-ownership.md`'s
  carve-out section — not a new risk introduced by this task, but worth flagging in the
  implementation summary so a future maintainer updating one list remembers to check the others.
- **Risk**: reframing `slidev-pitfalls.md`'s "Required Final Phase" section to add a
  justification-for-keeping-the-script paragraph could be read as scope creep if the
  implementer instead expected a straight deletion. **Mitigation**: this report exists precisely
  to head that off — the plan should cite this report's parity analysis (cost/determinism/fidelity)
  as the basis for the "keep the script, add MCP for ad hoc use" phase, not treat it as an
  unplanned pivot.

## Context Extension Recommendations

- **Topic**: visual critique using rendered screenshots.
  **Gap**: `slide-critic-agent.md` (present) evaluates only text-based source materials
  (manuscripts, research reports, plans, assembled markdown slides) — it never looks at rendered
  screenshots today, even though the verification phase already produces them
  (`scripts/screenshots/slide-NN.png`).
  **Recommendation**: not in scope for this task, but worth a future task proposal — the critic
  agent could consume the batch script's screenshot output (or an MCP `browser_take_screenshot`
  call) to catch layout/overflow/visual issues that a text-only critique cannot see. Flagging here
  rather than acting on it, since it is outside this task's file scope and acceptance criteria.

## Appendix

**Files read in full or via targeted grep**:
- `agent-system/extensions/present/context/project/present/talk/templates/playwright-verify.mjs`
  (full)
- `agent-system/extensions/web/settings-fragment.json` (full)
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` (full)
- `agent-system/extensions/present/manifest.json`, `founder/manifest.json`, `web/manifest.json`
  (full)
- `agent-system/extensions/present/settings-fragment.json` (absent — confirmed via `cat`/`ls`)
- `agent-system/extensions/founder/settings-fragment.json` (full)
- `~/.claude.json` `mcpServers` block (confirmed `playwright` registered in user scope,
  independent of any extension)
- `agent-system/extensions/present/context/project/present/talk/patterns/slidev-pitfalls.md`
  (targeted grep + full verification-phase section read)
- `agent-system/extensions/present/context/project/present/domain/talk-modes-and-library.md`,
  `talk/templates/slidev-project/README.md`, `talk/templates/slidev-project/package.json`,
  `present/index-entries.json`, `talk/index.json` (targeted grep)
- `agent-system/extensions/founder/agents/deck-builder-agent.md` (full stage-list grep + targeted
  section reads), `founder/context/project/founder/patterns/slidev-deck-template.md` (targeted
  grep)
- `agent-system/extensions/present/agents/slidev-assembly-agent.md`,
  `slide-critic-agent.md` (targeted grep + header read)
- `specs/state.json` — task 23, 24, and 26 records (prerequisite context and task description
  cross-check)

**Searches performed**: exclusively local codebase (Bash `grep`/`cat`/`find`); no WebSearch or
WebFetch was needed — this is a self-contained architecture/parity question answerable entirely
from the repository's own source store and the two already-completed prerequisite tasks.
