# Research Report: MCP Ownership Doc Rewrite and Dead-Declaration Purge

**Task**: 28 - Rewrite the canonical MCP ownership document, whose central premise has been
empirically disproven, and purge the dead server declarations it catalogues.
**Started**: 2026-08-11
**Completed**: 2026-08-11
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (`agent-system/extensions/**`), live `~/.claude.json`, live
`~/.claude/settings.json`, live run of `uvx mcp-nixos` (`tools/list` over stdio), `claude
--version`, git log/blame on the target doc, prior task 023 report (`specs/023_.../reports/01_mcp-registration-ownership-boundary.md`)
**Artifacts**: - This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Items 3, 4, 5 are confirmed exactly as stated in the brief**, with precise file:line evidence
  below. The known-gaps table's `epidemiology` row is wrong (has `sec-edgar, rmcp`, should be
  `rmcp` only); `founder`'s row is *also* wrong in the opposite direction (has `firecrawl` only,
  is missing `sec-edgar`) — the brief undersold this: it's not one bad cell, it's a value
  transposed between two rows.
- **Item 5 (nix) is independently re-verified by running the actual server**: `uvx mcp-nixos`
  exposes exactly two tools, `nix` and `nix_versions`, over stdio — confirming the two existing
  grants (`mcp__nixos__nix`, `mcp__nixos__nix_versions`) are correct only because a *future*
  registration will use server name `nixos`, not the dead block's `mcp-nixos`.
- **Item 1's literal quote does not exist in the target file.** `mcp-server-ownership.md`
  contains zero occurrences of `.mcp.json`, "project scope", "project-scoped", or "subagent" —
  grep-confirmed. The false categorical claim ("custom subagents cannot access project-scoped MCP
  servers") actually lives in `agent-system/extensions/core/scripts/setup-lean-mcp.sh` lines 4-6,
  a file **not in this task's file_scope**. The doc's actual defect is different but related: it
  asserts user-scope `~/.claude.json` is "the only mechanism that registers an MCP server" (line
  23) and never once mentions `.mcp.json` (project scope) as a legitimate alternative — an
  omission with the same practical effect as the disproven claim, not a restatement of it. The
  rewrite must fix the omission; it cannot "correct" a sentence that isn't there.
- **Item 2's live playwright asymmetry is independently confirmed with exact evidence**,
  including a positive control that shows what "grant at the same scope as registration" looks
  like when done correctly (`lean-lsp`).
- **New out-of-scope finding, worth a follow-up task**: every extension with a dead
  `settings-fragment.json` `mcpServers` block (except `epidemiology`) *also* carries the identical
  dead server definition in its own `manifest.json` `mcp_servers` field — a second, independent
  dead-declaration surface the doc already calls "equally inert" (lines 57-60) but which this
  task's `file_scope` does not touch.

## Context & Scope

Verified all five brief items against the live tree at `/home/benjamin/.config/nvim`, the live
`~/.claude.json` (user-scope MCP registration) and `~/.claude/settings.json` (user-scope
permissions), and by running the `mcp-nixos` server directly over stdio. This is a research-only
dispatch — no source-store edits were made. All file:line citations below are against the current
HEAD of the files named.

## Findings

### Item 1 — The Refuted Premise: located, but not where the brief says

**Verification method**: `grep -n '\.mcp\.json\|project.scope\|project-scoped\|subagent'
agent-system/extensions/core/context/patterns/mcp-server-ownership.md` returns **zero matches**.
The doc never states, in any form, that subagents cannot access project-scoped servers.

**Where the claim actually lives**: `agent-system/extensions/core/scripts/setup-lean-mcp.sh`,
lines 4-6:
```
# This script adds the lean-lsp MCP server to ~/.claude.json (user scope). Project-scoped
# `.mcp.json` servers require an interactive approval prompt that a subagent cannot satisfy,
# so registering in user scope -- never gated by per-server approval -- is the reliable choice.
```
This is **not** in `file_scope` for this task (only `mcp-server-ownership.md`,
`permission-configuration.md`, and four `settings-fragment.json` files are). This script's
comment is itself already a *softened* version of an even more categorical claim: prior task
023's report (`specs/023_document_mcp_registration_ownership_boundary/reports/01_mcp-registration-ownership-boundary.md`,
lines 123-135) found the original claim was "custom subagents CANNOT access project-scoped MCP
servers" (full stop) and, after fetching the official docs, concluded this was "an
overclaim/simplification of an approval-prompt issue rather than an absolute access barrier" and
recommended "restating it precisely rather than repeating the categorical version." The current
script header at lines 4-6 is that restatement — it already narrows the claim to "requires an
interactive approval prompt a subagent cannot satisfy," which is a *different, narrower* claim
than a hard access wall. Task 28's fresh experiment (permission pre-granted, fresh session/`claude
-p`) directly refutes even this narrower claim: with the approval prompt bypassed via a
pre-granted permission, a subagent *did* reach a project-scoped server. So the script comment,
while already more careful than the version task 023 found, is still wrong, and is the true
locus of the disproven premise — flag it as a strong follow-up recommendation (see Risks) since it
is upstream of (and linked from) the doc this task is scoped to rewrite.

**What the doc itself gets wrong instead**: line 23 states "User-scope `~/.claude.json` is the
only mechanism that registers an MCP server for agent use," and the "Not registration" subsection
(lines 39-60) only rebuts *settings files* as a registration surface — it never engages with
`.mcp.json` at all, sanctioned or not. Per the official Claude Code scope table (reconstructed in
task 023's report, lines 105-112, and independently consistent with the "ADDITIONAL VERIFIED
FACTS" in this task's brief), there are three real registration surfaces: Local (`~/.claude.json`,
keyed per-project), Project (`.mcp.json` in the project root), and User (`~/.claude.json`
top-level). The doc's line 23 claim collapses three real surfaces into one, by omitting Project
scope entirely rather than by stating (and being wrong about) a subagent-access barrier. The
practical effect is the same as the brief describes — the doc currently gives no path to
project-scoped registration — but the *rewrite instruction* is "add the missing scope and its
governing rule," not "delete a sentence that claims subagents can't reach it," because no such
sentence exists to delete.

**Confirmed independently**: no `.mcp.json` exists anywhere in this repo today (`find
/home/benjamin/.config/nvim -maxdepth 2 -iname ".mcp.json"` returns nothing), consistent with the
brief's "ADDITIONAL VERIFIED FACTS." Live `~/.claude.json` currently registers exactly two
servers at user scope: `lean-lsp` and `playwright` (both `type: stdio`), confirmed by direct read.

### Item 2 — The Replacement Model: playwright asymmetry independently reproduced

The brief's claim — "registered machine-wide but granted only inside two extension fragments" —
is exactly right, and here is the full evidence chain:

- **Registration** (`~/.claude.json`, user scope, confirmed by direct read):
  ```json
  "playwright": { "type": "stdio", "command": "playwright-mcp", "args": [] }
  ```
  This is machine-wide — it takes effect in every project, independent of which extensions are
  loaded.
- **Permission grants** exist in **exactly two** places, both project-scope extension fragments,
  never in the matching user-scope settings file:
  - `agent-system/extensions/web/settings-fragment.json:4-12` — 9 enumerated
    `mcp__playwright__browser_*` tools (the safe/unsafe split carve-out from the doc's lines
    93-114 applies here, correctly).
  - `agent-system/extensions/present/settings-fragment.json:4-12` — the identical 9-tool
    enumeration, duplicated verbatim.
  - `~/.claude/settings.json` (the actual user-scope settings file Claude Code reads globally,
    confirmed present at that path) — **zero** occurrences of `playwright` anywhere (`grep -n
    playwright ~/.claude/settings.json` returns nothing). Its full `permissions.allow` array was
    read in full; no playwright entry exists.
- **Positive control — `lean-lsp` does this correctly**: registered at user scope in
  `~/.claude.json` (confirmed above), *and* granted at user scope: `~/.claude/settings.json`
  carries `"mcp__lean-lsp__*"` directly in its top-level `permissions.allow` array. That pairing —
  user-scope registration + user-scope grant — is exactly the symmetric case the new governing
  rule should require, and it already exists in this repo as a template.

This means the fix for the live bug (out of `file_scope`, not part of this task's edits) would be:
add `"mcp__playwright__*"` (or the same 9-tool enumeration, given the carve-out) to
`~/.claude/settings.json`'s `permissions.allow`, since playwright's registration is user-scope. The
web/present fragment grants would then be redundant for any project already inheriting the
user-scope grant, though harmless to leave (belt-and-suspenders) unless a future decision wants
them removed for cleanliness. **This task's file_scope does not include either
`web/settings-fragment.json`, `present/settings-fragment.json`, or `~/.claude/settings.json`** —
recommend a follow-up task to actually apply the fix; this task should only document the rule and
use playwright/lean-lsp as the worked example pair (one broken, one correct).

**The new governing rule to add to the doc** (verbatim recommendation): *"Grant permissions at the
same scope where the server is registered. A user-scope-registered server's permission grant
belongs in the user-scope settings file (`~/.claude/settings.json`), not scattered across
per-project extension fragments — a project-scope grant only helps projects where that specific
extension happens to be loaded, leaving every other project's calls to prompt or (in headless
runs) deny outright. A project-scope-registered server's (`.mcp.json`) permission grant belongs in
that extension's own `settings-fragment.json`, per the existing domain-specific/domain-agnostic
split."*

**The hybrid registration model to state** (verbatim recommendation): *"Registration is now a
two-track decision, not a single user-scope-only rule: (1) extension-owned, repo-local servers —
no per-project computed arguments, and useful in this repo specifically — register via a
project-scoped `.mcp.json`. (2) Servers that are genuine machine capabilities (installed once per
machine, useful across every project — e.g. `playwright`) or that need per-project computed
arguments (e.g. `lean-lsp`'s per-project `LEAN_PROJECT_PATH`) register in user scope
(`~/.claude.json`), via a home-manager activation block or a `core/scripts/` setup script. Pick
the track by asking: does this server's usefulness end at this repo's boundary, and does it need
no computed args? If yes to both, project scope. Otherwise, user scope."*

This also requires updating the "Decision procedure" section (doc lines 134-146), whose step 1
currently only offers the user-scope choice ("No per-project computed arguments needed -> a
host-level or home-manager activation block. Per-project computed arguments needed -> a setup
script"). It needs a new first fork: project-scope-repo-local vs. user-scope-machine-or-computed,
*then* the existing per-project-args fork applies only within the user-scope branch. Step 2 needs
the same-scope grant rule folded in.

### Item 3 — Factual error: confirmed, and worse than stated

Doc's Known-gaps table (lines 155-161):
```
| `founder`      | `firecrawl` |
| `epidemiology` | `sec-edgar`, `rmcp` |
```
Verified against the actual settings-fragment files:
- `agent-system/extensions/epidemiology/settings-fragment.json` (8 lines total, read in full) —
  declares **only** `rmcp` (lines 2-6). No `sec-edgar` anywhere in this extension: exhaustive
  `grep -rn "sec-edgar"` across `agent-system/extensions/epidemiology/` returns nothing; `grep -rn
  "rmcp"` returns exactly the settings-fragment declaration plus doc/README mentions of the
  optional server (all consistent with "rmcp only").
- `agent-system/extensions/founder/settings-fragment.json` (31 lines total, read in full) —
  declares **both** `sec-edgar` (lines 3-10) and `firecrawl` (lines 11-20), plus the five
  permission grants (lines 23-29, see Item 4).

So the brief is correct that the table's `epidemiology` row is wrong, but understates the defect:
it isn't a stray extra value, it's `sec-edgar` sitting in the wrong row entirely. The corrected
table (post-purge, see Item 4/5 below for why the columns also change) should read something
closer to:
```
| Extension      | Server(s) that were declared in the dead block (now deleted) |
|----------------|----------------------------------------------------------------|
| `founder`      | `firecrawl`, `sec-edgar` |
| `epidemiology` | `rmcp` |
```
with `nix` and `filetypes` moved out of this table entirely once their blocks are deleted (Items
4/5), and `memory` remaining as the one extension where the block still exists (untouched — not in
`file_scope`).

### Item 4 — Purge dead declarations: confirmed exactly, line ranges below

| File | Lines to delete | Content |
|---|---|---|
| `agent-system/extensions/epidemiology/settings-fragment.json` | 1-8 (entire file) | `mcpServers.rmcp` block, no `permissions` key exists in this file |
| `agent-system/extensions/filetypes/settings-fragment.json` | 1-20 (entire file) | `mcpServers.superdoc` + `mcpServers.openpyxl`, no `permissions` key exists in this file |
| `agent-system/extensions/founder/settings-fragment.json` | 1-21 (`mcpServers` block: `sec-edgar` lines 3-10, `firecrawl` lines 11-20) AND lines 23-29 (all 5 `permissions.allow` entries: `mcp__firecrawl__scrape`, `mcp__firecrawl__crawl`, `mcp__firecrawl__map`, `mcp__firecrawl__extract`, `mcp__sec-edgar__*`) | Both the mcpServers block and every permission grant that names either dead server |

For `epidemiology` and `filetypes`, since the entire file content *is* the dead block (no other
keys exist), the file becomes an empty JSON object `{}` after the purge — `jq empty` will still
pass on `{}`, satisfying the task's own verification step. For `founder`, once both the
`mcpServers` key and the `permissions` key are removed, nothing remains either — `founder`'s
`settings-fragment.json` also becomes `{}`.

**Count check on "five orphaned grants"**: confirmed exactly 5 — 4 enumerated `mcp__firecrawl__*`
tool names (`scrape`, `crawl`, `map`, `extract`) plus 1 `mcp__sec-edgar__*` wildcard. The brief's
count is exact.

**Known-gaps rewording** (per the brief's explicit instruction not to silently drop these): the
doc's Known-gaps section (currently framed as "five extensions still declare a non-functional
block... registering them is a pending follow-up") must be reframed for the four affected-here
extensions as a deliberate retirement, not a pending fix:

> *"`epidemiology` (`rmcp`), `filetypes` (`openpyxl`, `superdoc`), and `founder` (`firecrawl`,
> `sec-edgar`) previously carried dead `mcpServers` blocks for these five servers. Those blocks
> have been deleted, along with founder's five orphaned `mcp__firecrawl__*`/`mcp__sec-edgar__*`
> permission grants that pointed at them. This is a deliberate retirement, not an oversight:
> these five servers are not being migrated to functioning (project- or user-scope) registration
> at this time. If a future task wants any of them working, it needs a fresh registration
> decision under the hybrid model above, not a revival of the deleted block."*

### Item 5 — Nix is the exception: independently re-verified by running the server

Ran `uvx mcp-nixos` directly over stdio (JSON-RPC `initialize` + `tools/list`). Result: the server
identifies itself as `mcp-nixos` (FastMCP `serverInfo.name`), version `3.0.0`, and exposes
**exactly two tools**: `nix` and `nix_versions` — full schemas captured, matching
`context/project/nix/tools/mcp-nixos-integration.md`'s documented tool surface.

This confirms the brief's naming-trap claim precisely: the dead block in
`agent-system/extensions/nix/settings-fragment.json` (lines 1-7) declares the server under the
key `mcp-nixos`:
```json
"mcpServers": { "mcp-nixos": { "command": "uvx", "args": ["mcp-nixos"] } }
```
If this block were ever honored as a registration (it isn't — same "not registration" rule as
everywhere else), Claude Code would expose its tools as `mcp__mcp-nixos__nix` and
`mcp__mcp-nixos__nix_versions` — **not** matching the two existing, currently-correct grants
(`mcp__nixos__nix`, `mcp__nixos__nix_versions` at lines 10-11). Those grants are only right because
the actual (future, external) registration is planned under server name `nixos`, in a separate
NixOS/home-manager repo, not in this repo's dead block. Deleting the dead block removes a landmine
that would silently break both grants and every doc cross-reference to `nixos.*` tool names if
someone "helpfully" tried to make the block functional as written.

**Purge for nix**: delete lines 1-7 (the `mcpServers` block only); **keep** lines 8-13
(`permissions.allow` with both grants) verbatim. Resulting file:
```json
{
  "permissions": {
    "allow": [
      "mcp__nixos__nix",
      "mcp__nixos__nix_versions"
    ]
  }
}
```

**Known-gaps addition for nix** (distinct from the other four — this is a stated pending
migration, not a retirement):

> *"`nix`'s dead `mcpServers` block (declared as `mcp-nixos`) has been deleted. Registration is
> moving to a home-manager activation block in a separate NixOS configuration repository, under
> server name `nixos` — verified by directly running the server (`uvx mcp-nixos`), which exposes
> exactly two tools, `nix` and `nix_versions`, matching the existing `mcp__nixos__nix` /
> `mcp__nixos__nix_versions` grants this repo already carries in `nix/settings-fragment.json`.
> Those two grants are correct today even though registration has not landed yet — do not delete
> them, and do not 'fix' the deleted block by reinstating it under the name `mcp-nixos`; that name
> would produce `mcp__mcp-nixos__*` tools and break both existing grants."*

## Decisions

- **Rewrite target is the doc's omission, not a quoted sentence.** Since no literal
  "subagents-can't-reach-project-scope" sentence exists in `mcp-server-ownership.md`, the fix is
  to add the missing third registration surface (project-scope `.mcp.json`) and the hybrid
  decision procedure — not to hunt for and delete a false sentence that isn't there.
- **The Known-gaps table shrinks from 5 rows to essentially structural prose**: after this task,
  only `memory` (`obsidian-memory`, untouched, out of `file_scope`) still has a live dead block.
  `nix`'s block is gone but gets a distinct "pending migration" note; `epidemiology`/`filetypes`/
  `founder`'s blocks are gone and get a "deliberate retirement" note. The table structure itself
  should be replaced by two short prose paragraphs (retirement + migration) rather than forcing a
  now-mostly-empty table to persist.
- **`founder/settings-fragment.json`, `epidemiology/settings-fragment.json`, and
  `filetypes/settings-fragment.json` all end up as `{}`** — confirmed by re-reading each file in
  full; none carries any content besides the dead block(s) being removed.
- **Playwright's actual fix (adding the grant to `~/.claude/settings.json`) is out of
  `file_scope`** and should not be attempted in this task's implementation phase; it is cited only
  as the worked example proving the new governing rule matters.
- **`setup-lean-mcp.sh`'s header comment (lines 4-6) is the true locus of the still-live, refuted
  premise**, but is out of `file_scope`. Recommend a narrowly-scoped follow-up task to correct it
  once the ownership doc's rewrite lands, so the script and the doc it points readers to don't
  contradict each other.

## Risks & Mitigations

- **Risk**: an implementer, reading the brief literally, searches `mcp-server-ownership.md` for
  the quoted premise sentence, doesn't find it, and either (a) concludes item 1 is a no-op or (b)
  edits the wrong file (`setup-lean-mcp.sh`, outside `file_scope`). **Mitigation**: this report
  states explicitly that item 1's fix is adding the missing project-scope registration surface and
  hybrid decision procedure to the doc's Registration and Decision-procedure sections — a
  same-file, in-scope edit — not a sentence deletion.
- **Risk**: purging `founder/settings-fragment.json` down to `{}` could visually look like an
  accidental full-file wipe during review. **Mitigation**: the commit/PR description should state
  explicitly that `{}` is the correct, verified end state (confirmed by this report re-reading the
  full 31-line file with no other content).
- **Risk**: a future contributor "fixes" the nix block by reinstating `mcpServers.mcp-nixos`,
  silently breaking the two existing grants. **Mitigation**: the Known-gaps prose recommended above
  explicitly warns against this by name.
- **Risk**: `manifest.json` `mcp_servers` fields (nix, filetypes, founder, memory — confirmed by
  `jq '.mcp_servers'` against each extension's manifest) carry the identical dead declarations as
  a second, independent surface not touched by this task. Left as-is, a future reader could still
  be misled by the manifest field even after the settings-fragment purge. **Mitigation**: flagged
  here as an explicit follow-up recommendation, not silently left for someone to rediscover.
  `epidemiology`'s manifest has no `mcp_servers` field at all (consistent with it never having
  declared sec-edgar).

## Context Extension Recommendations

None — this is a meta task; the doc rewrite itself is the context-documentation deliverable.

## Appendix

### Verification commands used

```bash
grep -n "\.mcp\.json\|project.scope\|project-scoped\|subagent" \
  agent-system/extensions/core/context/patterns/mcp-server-ownership.md   # 0 matches
grep -n "custom subagents\|cannot access" \
  agent-system/extensions/core/scripts/setup-lean-mcp.sh                  # located premise, lines 4-6
jq '.mcpServers' ~/.claude.json                                            # lean-lsp, playwright only
grep -n playwright ~/.claude/settings.json                                 # 0 matches (the bug)
jq '.permissions.allow' ~/.claude/settings.json                            # confirms mcp__lean-lsp__* present, no playwright
grep -rln "mcp__playwright" agent-system/extensions/*/settings-fragment.json  # web, present only
echo '{"jsonrpc":"2.0","id":1,"method":"initialize",...}\n{"jsonrpc":"2.0","id":2,"method":"tools/list",...}' \
  | uvx mcp-nixos                                                          # confirms tools: nix, nix_versions
jq '.mcp_servers' agent-system/extensions/{nix,epidemiology,filetypes,founder,memory,lean,web}/manifest.json
claude --version                                                           # 2.1.227
grep -rn "autoMode" agent-system/ .claude/                                 # 0 matches
```

### Files read in full for this report

- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` (184 lines)
- `agent-system/extensions/core/docs/guides/permission-configuration.md` (843 lines)
- `agent-system/extensions/{epidemiology,filetypes,founder,nix}/settings-fragment.json` (8, 20, 31, 14 lines respectively)
- `agent-system/extensions/{nix,memory}/settings-fragment.json` (memory, for the untouched comparison)
- `agent-system/extensions/lean/settings-fragment.json`
- `agent-system/extensions/{web,present}/settings-fragment.json`
- `agent-system/extensions/core/root-files/settings.json`
- `~/.claude/settings.json`, `~/.claude.json` (live, outside the repo)
- `agent-system/extensions/{nix,epidemiology,filetypes,founder,memory,lean,web}/manifest.json` (mcp_servers field only)
- `specs/023_document_mcp_registration_ownership_boundary/reports/01_mcp-registration-ownership-boundary.md` (lines 1-140)
- `agent-system/extensions/core/scripts/setup-lean-mcp.sh` (header, lines 1-30)
