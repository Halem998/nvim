# Research Report: MCP Registration/Permission Ownership Boundary

**Task**: 23 - Define and document the ownership boundary between the four competing MCP
registration/permission mechanisms, and reconcile the existing lean-lsp three-way duplication.
**Started**: 2026-08-10
**Completed**: 2026-08-10
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/**), live `~/.claude.json`, live
`.claude/settings.local.json`, `claude mcp list` (v2.1.227), official Claude Code docs
(code.claude.com/docs/en/mcp, /sub-agents, /settings)
**Artifacts**: - This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Empirically confirmed, not just inferred**: `mcpServers` keys inside `settings.json` /
  `settings.local.json` (mechanism 2's actual deploy target) are **not honored by Claude Code
  at all**. `claude mcp list` run from this exact project shows only `lean-lsp` and `playwright`
  (both registered in **user-scope `~/.claude.json`**) as `Connected`. `mcp-nixos` and
  `obsidian-memory` — both declared under `mcpServers` in the live, deployed
  `.claude/settings.local.json` — do not appear at all, connected or otherwise. This is the
  load-bearing fact for the whole ownership question.
- **Registration owner**: user-scope `~/.claude.json`, written either by a home-manager
  activation block (static servers, no per-project parameters — e.g. playwright) or by a
  core-provided setup script (servers needing computed/per-project args — e.g. `LEAN_PROJECT_PATH`
  for lean-lsp). No other mechanism actually connects a server today.
- **Permission-grant owner**: whichever settings file matches the grant's scope —
  `permissions.allow` in an extension's `settings-fragment.json` (deployed to
  `.claude/settings.local.json`) for domain-specific tool grants, or core's
  `root-files/settings.json` only for genuinely domain-agnostic grants. A domain-specific
  wildcard sitting in core (the current `mcp__lean-lsp__*` entry) is a boundary violation on this
  axis, independent of the registration question.
- **The lean-lsp three-way duplication resolves to**: keep mechanism 4 (`setup-lean-mcp.sh`) as
  the only registration path; consolidate permission grants into lean's own
  `settings-fragment.json` as a single wildcard (replacing both the drifted 21-tool enumeration
  and core's misplaced wildcard); delete the non-functional `mcpServers` block from the fragment.
- **This bug is not lean-specific.** Six extensions (`lean`, `nix`, `memory`, `filetypes`,
  `founder`, `epidemiology`) all declare a `mcpServers` block in `settings-fragment.json`,
  targeting `mcpServers` in `settings.local.json`. Per the finding above, **none of those
  declarations register anything**. `mcp-nixos`, `obsidian-memory`, `rmcp`, `openpyxl`,
  `superdoc`, `firecrawl`, and `sec-edgar` are consequently unregistered in this environment
  right now unless something outside this repo (e.g. a not-yet-written home-manager block)
  separately puts them in user scope. This is a systemic latent defect, not a one-off.

## Context & Scope

The task asked to (1) confirm or refute the claim in `setup-lean-mcp.sh`'s header that "custom
subagents cannot access project-scoped MCP servers; user scope is required," (2) define which of
the four mechanisms owns registration vs. permission grants and how they compose, and (3)
reconcile the lean-lsp wildcard-vs-21-tool-enumeration split. Scope was codebase inspection of all
four mechanisms plus live verification against the actual running Claude Code installation
(v2.1.227) and official docs, since this is exactly the kind of platform-behavior claim that must
not be taken on faith from a comment.

## Findings

### The Four Mechanisms, As They Actually Exist

1. **Home-manager activation block -> `~/.claude.json` (user scope)**. Lives outside this repo
   (no home-manager config exists under `agent-system/**`). Registers `playwright` today.
   Confirmed `Connected` by `claude mcp list`.
2. **Extension `settings-fragment.json` -> `.claude/settings.local.json`** via
   `merge_targets.settings` in each extension's `manifest.json`
   (`agent-system/extensions/{nix,lean,memory,filetypes,founder,epidemiology}/manifest.json`).
   Each fragment carries both an `mcpServers` block AND a `permissions.allow` list, e.g.
   `agent-system/extensions/lean/settings-fragment.json` and
   `agent-system/extensions/nix/settings-fragment.json`. `extension-system.md`'s "Settings
   Merging" section documents this as deep-merge, non-overwriting.
3. **`core/root-files/settings.json` -> `.claude/settings.json` (install-once)**. Currently
   carries `"mcp__lean-lsp__*"` in `permissions.allow` — a domain-specific (lean) grant sitting in
   the domain-agnostic core file.
4. **`core/scripts/setup-lean-mcp.sh` -> `~/.claude.json` (user scope)**. Manually operator-invoked
   (no automated caller; confirmed via `grep` — it is not wired into any manifest `hooks` block,
   and `lean/manifest.json` has no `hooks` key at all). Computes `LEAN_PROJECT_PATH` per-project
   and writes it into the user-scope `lean-lsp` entry. This is the mechanism that actually put
   `lean-lsp` into `~/.claude.json` for the currently active project
   (`/home/benjamin/Projects/BimodalLogic`, per the live `~/.claude.json` contents observed).

### Live Verification (the decisive evidence)

Ran from this exact project root:

```
$ claude mcp list
lean-lsp: ...lean-lsp-mcp-wrapper.sh --lean-project-path /home/benjamin/Projects/BimodalLogic - Connected
playwright: playwright-mcp  - Connected
```

Both `Connected` servers are registered in **user-scope `~/.claude.json`** (confirmed by reading
that file directly — top-level `mcpServers.lean-lsp` and `mcpServers.playwright`). The live,
deployed `.claude/settings.local.json` in this project independently contains an `mcpServers`
block declaring `mcp-nixos` and `obsidian-memory` — **neither appears in `claude mcp list`
output, connected or otherwise.** This is not a connection failure (which would show as `✘ Failed
to connect`); it is total absence, meaning Claude Code never attempted to load these as servers
from that file. Cross-checking the deferred-tool roster available to this very research agent
session shows `mcp__lean-lsp__*` and `mcp__playwright__*` tools present, and no `mcp__nixos__*`
tools at all — consistent at every layer.

### What the Official Docs Actually Say

Fetched `code.claude.com/docs/en/mcp`, `/sub-agents`, and `/settings` directly (2026 docs,
Claude Code v2.1.x era):

- **MCP servers install at exactly three scopes**, all outside `settings.json`/
  `settings.local.json`:

  | Scope | Loads in | Shared with team | Stored in |
  |-------|----------|-------------------|-----------|
  | Local | Current project only | No | `~/.claude.json` (keyed under the project path) |
  | Project | Current project only | Yes, via VCS | `.mcp.json` in project root |
  | User | All projects | No | `~/.claude.json` (top-level) |

- **`settings.json`/`settings.local.json` do not support an `mcpServers` key.** A targeted
  re-fetch of `/docs/en/settings` asking specifically for every occurrence of the literal string
  `mcpServers` came back empty; the only MCP-adjacent settings keys that page documents are
  `enabledMcpjsonServers`, `disabledMcpjsonServers`, `enableAllProjectMcpServers`,
  `allowedMcpServers`, `deniedMcpServers`, and `allowManagedMcpServersOnly` — all of which
  **approve or deny servers already defined elsewhere** (`.mcp.json`, or enterprise managed
  config); none of them define a server. This matches the live-verification finding exactly:
  the `mcpServers` block in the deployed `settings.local.json` is not one of the keys Claude Code
  reads for server definitions.
- **Subagents "inherit the built-in tools and MCP tools available in the main conversation."**
  There is no documented categorical rule that subagents specifically cannot reach
  project-scoped (`.mcp.json`) servers. What the docs do note: "For security reasons, Claude Code
  prompts for approval in interactive sessions before using project-scoped servers from
  `.mcp.json` files" — and subagents cannot satisfy an interactive approval prompt. This is the
  likely real mechanism behind the "subagents can't use project-scoped servers" claim recorded in
  `setup-lean-mcp.sh`'s header: not a hard platform wall, but an approval-prompt deadlock that
  user-scope (never gated by per-server approval) sidesteps entirely. Verdict: **the operative
  conclusion in the script (user scope is required) is correct and is exactly what the live data
  in this repo confirms**, but the causal mechanism as literally stated ("custom subagents CANNOT
  access project-scoped MCP servers") is an overclaim/simplification of an approval-prompt issue
  rather than an absolute access barrier. Recommend restating it precisely rather than repeating
  the categorical version.

### Existing Documentation Already Contains the Wrong Answer

- `agent-system/extensions/core/docs/guides/creating-extensions.md` documents `mcp_servers` as a
  manifest.json field ("MCP server configs to merge"), directly contradicting
  `extension-system.md`'s own caveat two files over ("This field may appear in some manifests but
  is NOT directly consumed by the loader"). Both statements currently coexist in the source
  store.
- `agent-system/extensions/lean/README.md` and `agent-system/extensions/nix/README.md` both state
  "Configured automatically in `manifest.json`" for their MCP server ("MCP Tool Setup" section).
  This is doubly wrong: manifest.json's `mcp_servers` field is inert (confirmed above), and even
  the fragment's `mcpServers` block (the documented "real" path per `extension-system.md`) is
  itself inert per live verification. Neither README mentions `setup-lean-mcp.sh` at all, despite
  it being the only thing that actually makes `lean-lsp` reachable by agents today.
- `agent-system/extensions/core/context/patterns/mcp-tool-recovery.md` already contains informal
  tribal knowledge pointing the right direction ("Tool Unavailable ... may indicate MCP not in
  user scope (check ~/.claude.json)") but is scoped to runtime-failure recovery, not registration
  ownership, and has no cross-reference to a canonical ownership decision.

### Permission-Grant Layer: The Wildcard-vs-Enumeration Split

`core/root-files/settings.json`'s `permissions.allow` carries `"mcp__lean-lsp__*"` (a blanket
grant). `lean/settings-fragment.json`'s `permissions.allow` separately enumerates 21 individual
`mcp__lean-lsp__lean_*` tool names. Diffing the enumeration against the live tool roster available
to lean-lsp today (23 tools, per the MCP server's own instructions surfaced in this session) shows
the enumeration is **already missing two real tools**: `lean_minimal_hypotheses` and
`lean_references`. The wildcard, by construction, cannot drift this way. Functionally the two
grants are fully redundant wherever they overlap (the wildcard already covers everything the
enumeration lists), and the enumeration is strictly worse because it silently under-grants as the
server's tool surface grows — a maintenance trap with no compensating benefit, since there is no
scenario in this codebase where "all lean_* tools except two specific ones" is a desired grant
shape.

### Scope of the `mcpServers`-in-settings-fragment Defect

Grepping every extension's `settings-fragment.json` for an `mcpServers` key surfaces six
extensions carrying the same dead pattern, not just lean and nix:

| Extension | Declared (non-functional) server(s) |
|-----------|--------------------------------------|
| `lean` | `lean-lsp` |
| `nix` | `mcp-nixos` |
| `memory` | `obsidian-memory` |
| `filetypes` | `openpyxl`, `superdoc` |
| `founder` | `firecrawl`, `sec-edgar` |
| `epidemiology` | `rmcp` |

None of these names appear in the live `~/.claude.json` (user scope) observed during this
research pass, and `nix`'s own `context/project/nix/tools/mcp-nixos-integration.md` already
documents a "Graceful Degradation" fallback to WebSearch/CLI — language that reads, in hindsight,
like the extension's author already suspected the MCP path might not reliably materialize. This
is evidence the defect is old and systemic, not something introduced by the playwright work. It
is out of this task's direct scope to register all six (that requires host-machine or
home-manager changes per server, which a documentation task cannot verify or perform), but it
must be named as a consequence of the decision below, since "declare `mcpServers` in your
extension's `settings-fragment.json`" is precisely the fifth-duplicate-path this task's acceptance
criterion is meant to prevent.

## Decisions

1. **Registration owner: user-scope `~/.claude.json`, and nothing else.** An extension author
   adding a new MCP server writes ONE of:
   - A home-manager (or equivalent host-level) activation block, for a server with no
     per-project/per-machine computed arguments.
   - A setup script under `core/scripts/` (mirroring `setup-lean-mcp.sh`'s shape: detect/compute
     any per-project args, then `jq`-merge into `~/.claude.json`'s top-level `mcpServers`),
     for a server that needs one.
   Extension `settings-fragment.json` files MUST NOT declare an `mcpServers` key going forward —
   it has no effect and its presence actively misleads future authors into believing mechanism 2
   handles registration.
2. **Permission-grant owner: settings files, scoped to who needs the grant.** Domain-specific
   tool grants (any `mcp__{server}__*` pattern, or an enumerated subset) belong in that
   extension's `settings-fragment.json` `permissions.allow`, deployed to
   `.claude/settings.local.json`. Core's `root-files/settings.json` `permissions.allow` is
   reserved for grants that apply regardless of which extensions are loaded (e.g. `Read`, `Write`,
   `Bash(git:*)`) — never a single named MCP server's tools, since that couples a domain-agnostic
   file to one extension's presence.
3. **Composition rule.** Registration and permission are independent axes that must both be
   satisfied: a tool is usable without a prompt only if (a) its server shows `Connected` in
   `claude mcp list` (a registration-layer fact, decided by axis 1) AND (b) some active
   `permissions.allow` list contains a matching `mcp__{server}__*` or exact tool pattern (a
   permission-layer fact, decided by axis 2). Neither axis substitutes for the other; fixing one
   without the other leaves a server either connected-but-prompting or granted-but-absent.
4. **lean-lsp reconciliation.** Collapse the three-way duplication to two files with one
   responsibility each:
   - `core/root-files/settings.json`: remove `"mcp__lean-lsp__*"` from `permissions.allow`
     (domain-specific grant does not belong in the domain-agnostic file).
   - `agent-system/extensions/lean/settings-fragment.json`: replace the 21-tool enumeration with
     a single `"mcp__lean-lsp__*"` wildcard; delete the `mcpServers` block entirely (non-functional,
     per Finding above).
   - `core/scripts/setup-lean-mcp.sh` remains the sole registration mechanism; no change needed
     to its logic, only to its documentation trail (see below).
5. **Doc fixes required to meet the acceptance criterion** ("a future extension author can read
   one document and know where to declare a new MCP server and its permissions"):
   - `permission-configuration.md`: add a section stating decisions 1-3 above as the canonical
     ownership boundary, replacing any implication that settings files register servers.
   - `extension-system.md`: correct the "Settings Merging" section's example (currently shows
     `mcpServers` inside a `settings-fragment.json` example as if it worked) to state plainly that
     `mcpServers` in a settings fragment has no effect, and point to the registration-owner rule
     instead.
   - `creating-extensions.md`: remove/correct the `mcp_servers` manifest field row, which
     currently asserts the opposite of what `extension-system.md` already says two files over.
   - `lean/README.md` and `nix/README.md` "MCP Tool Setup" sections: replace "Configured
     automatically in `manifest.json`" with an accurate statement of the actual registration path
     (a setup script for lean; presently **unregistered/non-functional** for nix, pending a
     mechanism-1/4-style fix as a follow-up).
   - Consider a new `context/patterns/mcp-server-ownership.md` pattern file as the single
     canonical reference, cross-linked from all four docs above plus
     `mcp-tool-recovery.md`, so the acceptance criterion's "one document" has an unambiguous home
     rather than being reconstructed piecemeal across four files.

These are recommendations for the planning/implementation phase; this research pass does not
edit source-store files.

## Risks & Mitigations

- **Risk**: Fixing only lean's duplication without also correcting `creating-extensions.md`/
  `extension-system.md`/READMEs leaves the fifth-duplicate-path failure mode fully open for the
  next extension author, since the wrong guidance is what they'll read first.
  **Mitigation**: doc fixes (Decision 5) are listed as required, not optional, for this task's
  acceptance criterion.
- **Risk**: `mcp-nixos`, `obsidian-memory`, `rmcp`, `openpyxl`, `superdoc`, `firecrawl`,
  `sec-edgar` are discovered here to be non-functional MCP registrations; leaving this
  undocumented risks a future contributor assuming these tools work because the extension docs
  say so.
  **Mitigation**: flag explicitly (done above); recommend a follow-up task per extension (or one
  batched task) to add the missing user-scope registration (home-manager block or setup script)
  for each, using lean-lsp's `setup-lean-mcp.sh` as the template. Out of scope for this task's
  edits, since a documentation-boundary task should not silently attempt six unrelated host-level
  registrations.
- **Risk**: the "subagents can't access project-scoped servers" claim, if left as originally
  worded, could be copied verbatim into a new script's header without the nuance (it's an
  approval-prompt interaction, not a fundamental wall) — a future platform fix to the approval
  flow could make project scope viable for subagents, and the overclaimed wording would then be
  actively wrong rather than just imprecise.
  **Mitigation**: Decision 1 does not repeat the categorical wording; it states the operative
  rule (register in user scope) without asserting project scope is impossible in principle.

## Context Extension Recommendations

- **Topic**: MCP server ownership boundary (registration vs. permission).
  **Gap**: No existing context file states which of the four mechanisms owns which
  responsibility; `permission-configuration.md` and `extension-system.md` are the two most
  relevant existing docs but neither currently states it, and `extension-system.md`'s own
  settings-merging example is actively misleading (shows a non-functional `mcpServers` fragment
  as if it worked).
  **Recommendation**: create `context/patterns/mcp-server-ownership.md` per Decision 5, and
  cross-link it from `permission-configuration.md`, `extension-system.md`,
  `creating-extensions.md`, and `mcp-tool-recovery.md`.
- **Topic**: Six extensions with dead `mcpServers` declarations.
  **Gap**: No task currently tracks that `mcp-nixos`, `obsidian-memory`, `rmcp`, `openpyxl`,
  `superdoc`, `firecrawl`, `sec-edgar` are unregistered given this finding.
  **Recommendation**: file a follow-up task (outside this one's scope) to audit and register each
  via the corrected pattern from Decision 1.

## Appendix

- Commands run: `claude mcp list`, `jq` queries against `~/.claude.json` and
  `.claude/settings.local.json`, `grep`/`find` across `agent-system/extensions/**`.
- Docs fetched: `https://code.claude.com/docs/en/mcp`, `https://code.claude.com/docs/en/sub-agents`,
  `https://code.claude.com/docs/en/settings` (redirected from `docs.claude.com`).
- Files inspected: `core/root-files/settings.json`, `core/scripts/setup-lean-mcp.sh`,
  `core/scripts/verify-lean-mcp.sh`, `lean/manifest.json`, `lean/settings-fragment.json`,
  `nix/manifest.json`, `nix/settings-fragment.json`, `memory/settings-fragment.json`,
  `filetypes/settings-fragment.json`, `founder/settings-fragment.json`,
  `epidemiology/settings-fragment.json`, `core/docs/architecture/extension-system.md`,
  `core/docs/guides/permission-configuration.md`, `core/docs/guides/creating-extensions.md`,
  `lean/README.md`, `nix/README.md`, `nix/context/project/nix/tools/mcp-nixos-integration.md`,
  `core/context/patterns/mcp-tool-recovery.md`.
