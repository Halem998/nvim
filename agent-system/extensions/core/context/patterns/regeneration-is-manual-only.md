# Regeneration Is Manual-Only: No Headless/CI Path

## Overview

The `<leader>al` picker ("Load Core" / "Load All") is the ONLY mechanism that deploys the
extension source store (`agent-system/extensions/**`) into a consuming repo's gitignored
`.claude/` tree. Every deployed file under `.claude/` has a source under
`agent-system/extensions/**`; nothing under `.claude/` is hand-authored. This document states
plainly, for future reference, that this deployment step has **no headless, scripted, or CI
equivalent** -- so future automation or CI-deploy-verification work does not retread this
already-settled question.

## Why There Is No Headless Path

The picker's "Load All" (`is_load_all`) entry invokes `M.load_all_globally()` in
`lua/neotex/plugins/ai/shared/extensions/loader.lua`. That function's actual sync work happens in
a module-local closure, `execute_sync`, which is **not exported** -- there is no public entry
point a script, hook, or headless `nvim --headless -c ...` invocation can call directly to trigger
a sync.

Independently of that, `execute_sync` itself is gated behind an unconditional `vim.fn.confirm()`
call presenting the user with "Sync all (replace existing)" / "Add new only" / "Cancel" (default)
choices. `vim.fn.confirm()` blocks on interactive user input in every code path -- there is no
flag, environment variable, or headless mode that bypasses it. A synthetic keystroke feed into a
headless Neovim instance could theoretically drive the dialog, but that is a bypass/re-
implementation of the interactive contract, not a legitimate headless equivalent, and is
explicitly out of scope for any task relying on this document.

## What This Means for Automation

- **No task, script, or CI job may assume a deploy has happened as a side effect of source-store
  edits.** Source-store edits under `agent-system/extensions/**` are the durable, version-
  controlled truth; the deployed `.claude/` tree only reflects them after a human runs
  `<leader>al` and explicitly chooses "Sync all (replace existing)".
- **A stale deployed tree is an expected, recurring state**, not a bug to route around. Doc-lint
  tooling (see `check-extension-docs.sh`'s core deploy-drift ADVISORY lane) makes this staleness
  visible without treating it as a hard failure, precisely because only a human can resolve it.
- **Verification of deployed behavior always requires two gates**, not one: first the manual
  regeneration, then (for anything involving hook-driven event flow) accumulated real usage over
  time. Neither gate can be satisfied by inspecting source-store code alone.

## Related Documentation

- `docs/guides/creating-extensions.md` -- extension authoring guide (manifest schema, file
  templates, deployment categories)
- `scripts/check-extension-docs.sh` -- doc-lint gate; its core deploy-drift ADVISORY lane surfaces
  never-deployed core scripts/hooks without hard-failing on this expected, user-gated condition
