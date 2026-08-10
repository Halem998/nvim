# Implementation Summary: Task #572

- **Task**: 572 - diagnose_opencode_lean_routing_failure
- **Status**: [COMPLETED]
- **Started**: 2026-05-14T00:00:00Z
- **Completed**: 2026-05-14T00:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Artifacts**: specs/572_diagnose_opencode_lean_routing_failure/plans/01_opencode-routing-fix.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

This implementation fixed the OpenCode extension routing failure that caused task 129 in ProofChecker to use a general implementation agent instead of the lean-specific agent. The root cause was that OpenCode's Glob tool silently returns zero results for relative paths into hidden directories (`.opencode/`), so the manifest discovery code `for manifest in .opencode/extensions/*/manifest.json` found nothing, causing fallback to the default `skill-implementer`. The fix derives an absolute path via `git rev-parse --show-toplevel` before constructing the manifest search path. Additionally, a reusable sync script was created to propagate canonical command updates from the nvim source to all 5 registered child projects.

## What Changed

- `/home/benjamin/Projects/ProofChecker/.opencode/commands/implement.md` — Replaced with nvim canonical version containing absolute-path manifest discovery, COMMAND EXECUTION MODE preamble, and routing validation warning
- `/home/benjamin/Projects/ProofChecker/.opencode/commands/research.md` — Same fix applied
- `/home/benjamin/Projects/ProofChecker/.opencode/commands/plan.md` — Same fix applied
- `/home/benjamin/.dotfiles/.opencode/commands/implement.md` — Same fix applied
- `/home/benjamin/.dotfiles/.opencode/commands/research.md` — Same fix applied
- `/home/benjamin/.dotfiles/.opencode/commands/plan.md` — Same fix applied
- `/home/benjamin/.config/zed/.opencode/commands/implement.md` — Same fix applied
- `/home/benjamin/.config/zed/.opencode/commands/research.md` — Same fix applied
- `/home/benjamin/.config/zed/.opencode/commands/plan.md` — Same fix applied
- `/home/benjamin/Projects/ModelChecker/.opencode/commands/implement.md` — Same fix applied
- `/home/benjamin/Projects/ModelChecker/.opencode/commands/research.md` — Same fix applied
- `/home/benjamin/Projects/ModelChecker/.opencode/commands/plan.md` — Same fix applied
- `/home/benjamin/Projects/protocol/.opencode/commands/implement.md` — Same fix applied
- `/home/benjamin/Projects/protocol/.opencode/commands/research.md` — Same fix applied
- `/home/benjamin/Projects/protocol/.opencode/commands/plan.md` — Same fix applied
- `/home/benjamin/.config/nvim/.opencode/commands/implement.md` — Added routing validation warning block to nvim canonical source
- `/home/benjamin/.config/nvim/.opencode/commands/research.md` — Added routing validation warning block
- `/home/benjamin/.config/nvim/.opencode/commands/plan.md` — Added routing validation warning block
- `/home/benjamin/.config/nvim/.opencode/scripts/sync-core-commands.sh` — New reusable sync script (created)

## Decisions

- Used full file replacement (copy) rather than targeted patches to bring child projects to full parity with nvim canonical source in one operation
- The routing validation warning uses a case statement to only fire for non-default task types (general/meta/markdown) — this prevents false positives for the most common use cases
- The sync script hardcodes the project registry rather than auto-discovering projects, keeping it simple and explicit; the plan notes this as acceptable given the low frequency of new project additions
- The opencode project at `/home/benjamin/Projects/opencode` was skipped because it has no `.opencode/commands` directory (it has not been set up with the agent system)

## Plan Deviations

- **Task 1.3** altered: Plan specified "3 child projects without routing code (OpenCode, ModelChecker, protocol)" but the opencode project has no `.opencode/commands` directory at all. Updated diff/replace scope to 5 projects instead of 6. The final count (5 projects) is still correct as opencode was never set up with OpenCode commands.

## Impacts

- ProofChecker `/implement 129` will now correctly route to `skill-lean-implementation` instead of falling back to `skill-implementer`
- All 5 child projects now have identical routing commands to the nvim canonical source (zero drift confirmed by sync script `--check` mode)
- Future routing failures for extension task types will emit an explicit `[WARN]` message instead of silently falling back
- The sync script enables future command updates to be propagated in one command: `.opencode/scripts/sync-core-commands.sh`

## Follow-ups

- Re-run `/implement 129` in ProofChecker to verify the lean routing now works end-to-end
- Consider adding the sync script to a CI check or pre-commit hook to detect drift automatically
- The opencode project at `/home/benjamin/Projects/opencode` has no `.opencode/` setup — if it needs agent system support, run the installation process for it

## References

- `specs/572_diagnose_opencode_lean_routing_failure/plans/01_opencode-routing-fix.md`
- `specs/572_diagnose_opencode_lean_routing_failure/reports/01_opencode-routing-diagnosis.md`
- `/home/benjamin/.config/nvim/.opencode/scripts/sync-core-commands.sh`
