# Implementation Summary: Task #771

**Completed**: 2026-06-24
**Duration**: ~15 minutes

## Overview

Resolved all 4 doc-lint baseline FAILs reported by `check-extension-docs.sh` across 3 targeted file edits. The script now exits 0 with all 18 extensions PASS, and lean's `routing_hard` entries correctly appear as WARN (not FAIL).

## What Changed

- `.claude/extensions/core/manifest.json` — Removed stale `"dispatch-agent.sh"` entry from `provides.scripts` (the file was deleted in task 766 but the manifest entry was not cleaned up)
- `.claude/extensions/core/README.md` — Added `/zulip` row to Commands table; updated overview count from 15 to 16
- `.claude/scripts/check-extension-docs.sh` — Changed `routing_hard` uninstalled-extension branch from `fail` to `info "WARN: ..."` and corrected the policy rationale comment to reflect that both `routing` and `routing_hard` share the same WARN-when-uninstalled severity (core is always `installed=1` so core violations still FAIL via the installed branch)

## Decisions

- Chose to downgrade uninstalled-extension `routing_hard` branch to WARN rather than install lean, keeping the fix fully in-scope and non-invasive
- Left `/orchestrate` without a table row in the README (it already passes the grep check via architecture text, consistent with the research report's decision)
- Updated count to 16 (not 17) to reflect only what's in the Commands table

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: `bash .claude/scripts/check-extension-docs.sh` — exit=0, all 18 extensions PASS
- JSON validated: `jq .` on manifest.json succeeds, `dispatch-agent.sh` absent
- lean extension shows `WARN` (not `FAIL`) for both `skill-lean-research-hard` and `skill-lean-implementation-hard`
- No FAIL lines containing "routing_hard target declared but not deployed"
- `command-route-skill.sh` and all uninstalled extension files untouched

## Notes

The README-drift WARNs on most extensions (README older than manifest) are pre-existing and non-blocking. They remain as expected WARN-only output.
