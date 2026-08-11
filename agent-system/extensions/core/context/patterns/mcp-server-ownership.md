# MCP Server Ownership: Registration vs. Permission

**Purpose**: Answer, in one place, "where do I declare a new MCP server and where do I grant its
tools?"
**Audience**: Extension authors and anyone debugging why an MCP tool call prompts, or why a
configured server never appears.

---

## Overview

MCP tool availability rests on two independent axes. **Registration** is which file makes a
server exist and connect. **Permission** is which file grants its tools without a prompt. Neither
axis substitutes for the other: a registered-but-unpermitted server still prompts on every call,
and a permitted-but-unregistered server has no tools to grant permission for in the first place.
Getting one axis right while getting the other wrong looks like a working configuration until the
first tool call, so both must be verified independently.

---

## Registration

User-scope `~/.claude.json` is the only mechanism that registers an MCP server for agent use.
There are two sanctioned ways to write into it:

1. **A host-level or home-manager activation block**, for servers with no per-project computed
   arguments. The activation block writes the server's `command`/`args`/`env` directly into
   `~/.claude.json`'s top-level `mcpServers` object once, outside of any single project's
   lifecycle.
2. **A setup script under `core/scripts/`**, mirroring `setup-lean-mcp.sh`'s shape, for servers
   that need per-project computed arguments (for example, a project path detected at setup time).
   The script detects or computes those arguments, then `jq`-merges the result into
   `~/.claude.json`'s top-level `mcpServers`, preserving whatever the file already holds for other
   servers.

Both paths write to the same destination and are otherwise interchangeable; the choice is driven
entirely by whether the server needs per-project computed arguments.

### Not registration

An `mcpServers` key inside `settings.json` or `settings.local.json` — and therefore inside an
extension's `settings-fragment.json`, which merges into one of those two files — has **no
effect**. Claude Code never reads those files for server definitions; it reads only user-scope
`~/.claude.json`. This is an empirically verified fact, not an inference from documentation
silence:

- **Evidence shape**: running `claude mcp list` shows only servers registered in user scope as
  `Connected`. A server whose only declaration is an `mcpServers` block in a settings file does
  not appear in the list at all — it is absent, not present-but-failing-to-connect. Absence is the
  tell: a misconfigured-but-registered server would still show up (as `Failed` or similar); a
  settings-declared server shows up nowhere because the file was never consulted for registration.
- **Doc-side corroboration**: the settings-file schema documents only `enabledMcpjsonServers`,
  `disabledMcpjsonServers`, `enableAllProjectMcpServers`, `allowedMcpServers`,
  `deniedMcpServers`, and `allowManagedMcpServersOnly`. Every one of these keys approves, denies,
  or scopes servers that are defined *elsewhere*; none of them defines a server.

A `manifest.json` `mcp_servers` field is equally inert for the same reason: nothing in the loader
reads it to write `~/.claude.json`. Extension `settings-fragment.json` files must not declare
`mcpServers` — the block is dead weight that misleads a future reader into thinking it registers
something.

---

## Permission

Once a server is registered, its tools still need a `permissions.allow` grant to be callable
without an interactive prompt. Ownership of that grant follows the domain boundary:

- **Domain-specific grants** (`mcp__{server}__*`, scoped to tools only one extension's agents
  use) belong in that extension's own `settings-fragment.json`.
- **Domain-agnostic grants** (tools every loaded configuration needs regardless of which
  extensions are present, such as `Read`/`Write`/`Bash(git:*)`) belong in core's
  `root-files/settings.json`.

A domain-specific `mcp__{server}__*` grant living in core's settings is a boundary violation even
if it happens to work today — it survives the extension being unloaded, misrepresents core as
domain-aware, and duplicates a grant that belongs entirely to the owning extension.

### Wildcard over enumeration

Prefer a single wildcard (`"mcp__{server}__*"`) over enumerating each tool the server exposes.
An enumeration silently under-grants as the server's tool surface grows — every new tool the
server adds requires a matching edit to the enumeration, and a missed edit reintroduces prompting
for that one tool with no error to signal the gap. A wildcard cannot drift: it grants whatever the
server exposes, today or after an upgrade, with one line to maintain.

The lean-lsp server is the worked example of enumeration drift: its permission grant was
duplicated three ways — a wildcard in core's `root-files/settings.json`, a 21-entry enumeration in
lean's own `settings-fragment.json`, and a dead `mcpServers` registration block also in lean's
fragment — none of which needed to coexist. The correct end state is one wildcard in lean's own
fragment and nothing in core.

### Carve-out: safe/unsafe tool splits require enumeration

The wildcard preference above assumes every tool a server exposes is equally fine to
always-allow. When a server intentionally splits its own tool surface into a safe/always-allow
tier and an unsafe/always-prompt tier, a wildcard cannot express that split — it grants
everything, collapsing the two tiers into one. Enumeration is **required** here, not merely
tolerated.

The worked example is `agent-system/extensions/web/settings-fragment.json`, which enumerates
exactly the 9 safe `mcp__playwright__browser_*` tools (navigate, snapshot, take_screenshot,
console_messages, network_requests, click, type, find, wait_for) and deliberately omits
`browser_evaluate`, `browser_file_upload`, and `browser_run_code_unsafe` from every allow list.
Those three tools must keep prompting: `browser_evaluate` and `browser_run_code_unsafe` run
arbitrary code, and `browser_file_upload` reads arbitrary local files onto a page. Collapsing the
enumeration into a `mcp__playwright__*` wildcard — the same simplification legitimately applied to
`lean-lsp` above — would silently re-grant all three and reopen an arbitrary-execution and
file-upload hole.

**Accepted cost, stated honestly**: this enumeration inherits exactly the drift weakness the
"Wildcard over enumeration" section above describes — a newly added safe Playwright tool will
prompt until this list is updated to include it. That is the deliberate price of keeping the
unsafe tier prompting; it is not an oversight to "fix" by wildcarding.

---

## Composition

A tool is usable without a prompt only when **both** axes hold at once: its server shows
`Connected` in `claude mcp list`, **and** an active `permissions.allow` entry matches its tool
name. The two failure shapes point to different fixes:

| Symptom | Registration | Permission | Fix |
|---|---|---|---|
| Connected, but every call prompts | OK (`Connected`) | Missing or non-matching grant | Add/correct the `mcp__{server}__*` entry in the owning extension's `settings-fragment.json` |
| Granted, but the tool is simply absent | Missing (not in `~/.claude.json`) | Present but moot | Register the server in user scope (activation block or setup script) — a permission grant cannot conjure a server that was never connected |

Checking only one axis and concluding "it's configured" is the recurring mistake this document
exists to prevent — always verify both.

---

## Decision procedure

Follow top to bottom when adding a new server:

1. **Pick a registration mechanism.** No per-project computed arguments needed → a host-level or
   home-manager activation block. Per-project computed arguments needed → a setup script under
   `core/scripts/`, mirroring `setup-lean-mcp.sh`.
2. **Write the permission grant** in the *extension's own* `settings-fragment.json`
   `permissions.allow`, as a wildcard (`"mcp__{server}__*"`), not core's settings and not an
   enumeration.
3. **Verify both axes**: run `claude mcp list` and confirm the server shows `Connected`, then make
   one real tool call and confirm it does not prompt.

---

## Known gaps

Five extensions still declare a non-functional `mcpServers` block in their own
`settings-fragment.json`, left in place as a named-but-not-fixed follow-up rather than corrected
here:

| Extension | Server(s) named in the dead block |
|---|---|
| `nix` | `mcp-nixos` |
| `memory` | `obsidian-memory` |
| `filetypes` | `openpyxl`, `superdoc` |
| `founder` | `firecrawl` |
| `epidemiology` | `sec-edgar`, `rmcp` |

None of these servers is registered in user scope by anything in this repository today. Their
agents fall back to WebSearch/CLI equivalents where documented (see, for example,
`context/project/nix/tools/mcp-nixos-integration.md`'s graceful-degradation section). Registering
them is a pending follow-up, not a defect this document's presence should be read to excuse —
treat every one of these five blocks as the same misleading example this document warns against,
not as a counter-example to the registration rule above.

---

## Related Documentation

- [Permission Configuration Guide](../../docs/guides/permission-configuration.md) — the guide an
  author reaches for when writing a `permissions.allow` entry; carries a summary of the same
  registration/permission split with a link back here.
- [Extension System Architecture](../../docs/architecture/extension-system.md) — Settings Merging
  section, covering how `settings-fragment.json` merges into `settings.json` at load time.
- [Creating Extensions](../../docs/guides/creating-extensions.md) — the extension-authoring guide,
  including the manifest field reference for `mcp_servers`.
- [MCP Tool Recovery Pattern](mcp-tool-recovery.md) — defensive handling for MCP tool call
  failures once a server is registered and permitted; its "Tool Unavailable" symptom links back
  here for the registration-scope check.
