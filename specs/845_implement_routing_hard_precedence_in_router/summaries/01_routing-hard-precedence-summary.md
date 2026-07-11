# Implementation Summary: Task #845

**Completed**: 2026-07-10
**Duration**: ~20 minutes

## Overview

Restored the `--hard`/`routing_hard` 5-step precedence resolution in `command-route-skill.sh`,
which had regressed to a 3-argument, Steps-1-3-only implementation via a prior blanket
extension-source sync. Recovered the known-good implementation verbatim from commit `574bf515a`
(task #768), applied it to the extension-source copy first, then byte-synced it to the deployed
copy.

## What Changed

- `.claude/extensions/core/scripts/command-route-skill.sh` — Overwritten with the recovered
  5-step implementation: added `_effort_flag="${4:-}"` 4th positional argument, the Step 4
  hard-mode resolution block (sub-steps 4a-4e: non-core exact match, non-core compound-key
  fallback, core exact match, core compound-key fallback, and the `-hard` append fallback gated
  on `.claude/skills/${candidate}-hard/SKILL.md` existing on disk), the extended `unset` line,
  and the updated header comment documenting the 4th parameter.
- `.claude/scripts/command-route-skill.sh` — Byte-synced from the corrected extension-source
  copy via `cp` (not hand-edited), restoring byte-identity between the two copies.

## Decisions

- Restored the block verbatim from `git show 574bf515a:.claude/scripts/command-route-skill.sh`
  rather than reconstructing it, since the existing 14-assertion test file was authored against
  this exact code.
- Patched the extension-source copy first, then copied to deployed (not the reverse), per the
  plan's rationale: this prevents recreating the original regression on the next extension
  reload/sync.

## Plan Deviations

- None (implementation followed plan)

## Verification

- `bash .claude/tests/test-command-route-skill.sh`: 12/12 tests passed, exit 0 (up from 6 PASS / 8 FAIL baseline).
- `cmp -s .claude/scripts/command-route-skill.sh .claude/extensions/core/scripts/command-route-skill.sh`: identical (exit 0).
- `diff -q` between the two copies: no output (identical).
- `bash -n` on both copies: no syntax errors.
- `bash .claude/scripts/check-extension-docs.sh`: exit 0, all 19 extensions PASS (core included).

## Notes

The test file (`.claude/tests/test-command-route-skill.sh`) required no changes — it was correct
as-is and served as the ground truth the restoration was verified against. No manifest changes
were needed; `routing_hard` data in core/cslib/lean manifests was already complete and correct.
