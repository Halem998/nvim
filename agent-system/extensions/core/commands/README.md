# .claude/commands/ — Claude Code Command Definitions

**Status**: ACTIVE (primary)

These command files are the active slash-command definitions for Claude Code, deployed here
from each loaded extension's `commands/` directory via `provides.commands` in its
`manifest.json`. `.claude/` is the primary, actively-developed deploy tree for this
agent-system architecture.

## Relationship to `.opencode/commands/`

`.opencode/commands/` is a secondary mirror maintained for OpenCode compatibility. It uses its
own extension-source tree (`.opencode/extensions/`) and a materially smaller rule set (see
`.opencode/scripts/check-extension-docs.sh`, a separate, older tool from the one that lints this
tree). The two trees are related but independently deployed — do not assume they are kept in
lockstep automatically; each is populated from its own extension source layer.

## Source of Truth

Every file in this directory traces to a source under `agent-system/extensions/<name>/commands/`,
declared in that extension's `provides.commands` array. Do not hand-edit deployed command files
directly — edit the source and redeploy (or let the extension loader's copy-deploy handle it),
so the deployed copy and its source never drift. See
`agent-system/extensions/core/scripts/check-extension-docs.sh` for the drift/orphan gate that
enforces this invariant.
