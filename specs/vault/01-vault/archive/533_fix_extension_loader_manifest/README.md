# Task 533: Fix Extension Loader to Copy manifest.json

## Problem

The extension loader in the Neovim configuration copies all extension files into the target project's `.opencode/extensions/{name}/` directory **except** `manifest.json`. This breaks agent routing in `/implement`, `/research`, and `/plan` commands, which scan `.opencode/extensions/*/manifest.json` to determine task-type-to-skill mappings.

**Impact**: When a user runs `/implement 107` on a `type:lean4` task, the routing loop finds no manifests and silently falls back to the generic `skill-implementer`, even though `skill-lean-implementation` exists.

## Root Cause

The Lua extension loader (`extensions/lua/loader.lua` or equivalent) does not include `manifest.json` in the list of files to copy during `manager.load()`.

## Solution

Update the extension loader to:

1. **Copy `manifest.json`** into `.opencode/extensions/{name}/manifest.json` during `manager.load()`.
2. **Track it in `installed_files`** so `manager.unload()` removes it cleanly.
3. **Update `verify.lua`** to confirm the copied manifest exists during extension verification.
4. **Validate routing discovery**: After fixing the loader, confirm that `/implement`, `/research`, and `/plan` commands can successfully discover extension manifests in a target project.

## Why No Fallbacks

This task intentionally does NOT add fallback routing mechanisms (e.g., `extensions.json` fallback or hardcoded type-to-skill mappings). The system should have exactly ONE routing mechanism: manifest discovery in `.opencode/extensions/*/`. If that mechanism fails, the failure should be explicit and force a fix to the root cause rather than silently degrading.

## Acceptance Criteria

- [ ] Extension loader copies `manifest.json` into target projects
- [ ] Extension loader removes `manifest.json` on unload
- [ ] Verification step confirms manifest exists after load
- [ ] Running `/implement` on a `type:lean4` task in a fresh project correctly routes to `skill-lean-implementation`
- [ ] No fallback routing logic was added to commands

## Effort

1-2 hours

## Type

neovim

## Dependencies

None

## Key Files

- Neovim extension loader Lua source (likely in `lua/neotex/` or `lua/` related to opencode extension management)
- `verify.lua` or equivalent verification script
- `.opencode/extensions/` structure in target projects

## Next Steps After Completion

1. Test the fix by loading the lean extension in a fresh project and verifying `.opencode/extensions/lean/manifest.json` exists.
2. Run `/implement` on a lean4 task to confirm correct routing.
3. If routing is still broken, investigate the command routing logic (not the loader) as a separate task.
