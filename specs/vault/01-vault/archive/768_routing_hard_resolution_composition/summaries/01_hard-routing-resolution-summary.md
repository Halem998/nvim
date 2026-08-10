# Implementation Summary: Task #768

**Completed**: 2026-06-24
**Duration**: ~1.5 hours

## Overview

Implemented the `--hard` routing resolution in `.claude/scripts/command-route-skill.sh` by
adding a 4th `effort_flag` argument and a 5-step hard-mode resolution block (Steps 4a-4e).
Wired the effort_flag into all three command callers (`/implement`, `/research`, `/plan`) and
centralized `/research` and `/plan` routing through the script. Created a context doc and
index entry documenting the composition model. Added a shell-level test harness with 12
cases covering standard regression, core routing_hard, extension overrides, no-hard-variant
fallback, and compound-key base-type fallback.

## What Changed

- `.claude/scripts/command-route-skill.sh` — Added 4th `_effort_flag` arg; inserted 5-step
  hard-mode resolution block (Steps 4a-4e) after standard routing; extended `unset` to clean
  new locals; added inline precedence comment block
- `.claude/commands/implement.md` — STAGE 2: added `"${EFFORT_FLAG:-}"` as 4th arg to
  `command-route-skill.sh` call
- `.claude/commands/research.md` — STAGE 2: replaced 30-line inline manifest scan with
  centralized `source .claude/scripts/command-route-skill.sh "research" ...` call
- `.claude/commands/plan.md` — STAGE 2: replaced 30-line inline manifest scan with
  centralized `source .claude/scripts/command-route-skill.sh "plan" ...` call
- `.claude/context/guides/hard-mode-routing.md` — New composition-model doc: 5-step
  precedence, extension-overrides-core rule, SKILL.md safety gate, orchestrate-hard exception
- `.claude/context/index.json` — New entry for `guides/hard-mode-routing.md`
- `.claude/tests/test-command-route-skill.sh` — New test harness: 12 tests, all passing

## Decisions

- Non-core manifests are scanned before core by detecting `routing_exempt: true` on the core
  manifest; this makes "extension overrides core" deterministic regardless of glob order
- The `-hard` append fallback (Step 4e) gates on `SKILL.md` existence; Steps 4a-4d trust
  manifest authors to declare only deployed skills
- The lean extension's `routing_hard` entries (`skill-lean-research-hard`,
  `skill-lean-implementation-hard`) reference skills that are not deployed — these were noted
  in the context doc but not corrected (out of scope)
- `skill-orchestrate-hard` left untouched; its separate inline reader is documented in the
  context doc rather than refactored
- Tests use `cslib` (not `lean4`) for the extension-override case because cslib hard skills
  are deployed; lean hard skills are not and would produce an unverifiable assertion

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (shell scripts, no build step)
- Syntax check: `bash -n .claude/scripts/command-route-skill.sh` passes
- Tests: `bash .claude/tests/test-command-route-skill.sh` — 12/12 pass (exit 0)
- No leaked variables after sourcing
- CLAUDE.md unchanged in diff
- `skill-orchestrate-hard/SKILL.md` unchanged in diff

## Notes

The test tuple `(research, lean4, hard)` from the plan was adapted to use `cslib` instead
because the lean extension's declared hard skills (`skill-lean-research-hard`) are not yet
deployed. The test does verify the extension override pattern correctly using cslib. The lean
extension's manifest should be updated or its hard skills deployed in a future task.
