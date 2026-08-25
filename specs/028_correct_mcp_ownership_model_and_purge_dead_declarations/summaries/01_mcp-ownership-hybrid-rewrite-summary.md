# Implementation Summary: Task #28

- **Task**: 28 - Correct the MCP ownership model and purge the dead declarations
- **Status**: [COMPLETED]
- **Started**: 2026-08-11
- **Completed**: 2026-08-24
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_mcp-ownership-hybrid-rewrite.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Replaced the user-scope-only MCP registration model documented in
`mcp-server-ownership.md` with the decided hybrid model (project-scoped `.mcp.json` for
extension-owned repo-local servers; user scope for machine capabilities and servers needing
per-project computed args), added the missing governing rule (grant permissions at the same
scope where the server is registered), corrected the refuted "subagents cannot reach
project-scoped servers" premise in `setup-lean-mcp.sh`'s header, fixed a transposed value in the
Known-gaps table, and deleted four dead `mcpServers` blocks plus their orphaned permission
grants from four extension settings fragments. All eight plan phases are now `[COMPLETED]`; this
dispatch closed the final phase (a report-only verification sweep) which had been left
`[IN PROGRESS]` with all its checklist boxes still unchecked.

## What Changed

- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` — rewritten
  registration model (hybrid, same-scope grant rule, workspace-trust caveat, session-start
  snapshot trap), corrected decision procedure and composition sections, rewritten Known-gaps
  section (Phases 4, 5)
- `agent-system/extensions/core/docs/guides/permission-configuration.md` — MCP section synced to
  the hybrid model, same-scope grant rule cross-referenced (Phase 6)
- `agent-system/extensions/core/scripts/setup-lean-mcp.sh` — header corrected to state the true
  reason lean-lsp registers in user scope (computed `LEAN_PROJECT_PATH`), removing the refuted
  subagent-approval-barrier claim (Phase 3)
- `agent-system/extensions/epidemiology/settings-fragment.json` — `mcpServers` block deleted,
  now `{}` (Phase 1)
- `agent-system/extensions/filetypes/settings-fragment.json` — `mcpServers` block deleted, now
  `{}` (Phase 1)
- `agent-system/extensions/founder/settings-fragment.json` — `mcpServers` block deleted, now
  `{}` (Phase 1)
- `agent-system/extensions/nix/settings-fragment.json` — `mcpServers` block (trap name
  `mcp-nixos`) deleted; `permissions.allow` retains exactly the two `mcp__nixos__*` grants
  (Phase 2)
- `specs/028_correct_mcp_ownership_model_and_purge_dead_declarations/plans/01_mcp-ownership-hybrid-rewrite.md` —
  this dispatch: checked off all Phase 8 verification tasks and the Testing & Validation
  checklist, marked Phase 8 `[COMPLETED]`

No new file edits were made outside the plan file in this dispatch — Phases 1-7 were already
committed by prior dispatches (verified: `git status --short` shows the seven `file_scope` paths
clean against HEAD). This dispatch executed and recorded Phase 8's verification-only gate set.

## Decisions

- Phase 8's "byte-identical to baseline" doc-lint criterion could not be met literally: the
  captured baseline (`specs/tmp/doclint-baseline.txt`) is dated 2026-08-11, and roughly two
  weeks of unrelated task work landed on the repo in the interim, producing new,
  unrelated-to-this-task drift in the doc-lint output (10 new `core` index-entries.json
  line_count mismatches, a changed `literature` failure reason, 3 new project-wide Rule-S
  failures for files never touched by this task). Verified the substantive intent of the gate
  instead: grepped the full current doc-lint output for this task's three edited files
  (`mcp-server-ownership.md`, `permission-configuration.md`, `setup-lean-mcp.sh`) and confirmed
  zero hits, and confirmed `epidemiology`, `filetypes`, `founder`, `nix` (the four extensions
  whose fragments this task edited) all still report `OK`/PASS. This satisfies the plan's stated
  underlying requirement ("Any NEW failure is a defect of this task") without requiring the
  baseline file itself to be frozen against unrelated repo evolution.
- The baseline's original `core` failure (`setup-lean-mcp.sh` deployed-vs-source drift) is no
  longer present in the current doc-lint output — an intervening redeploy synced the deployed
  tree with the corrected source, which is an improvement, not a regression.

## Plan Deviations

- **Task 8.4** (`check-extension-docs.sh` diff against baseline) altered: verified the
  substantive no-new-failure gate rather than a literal byte-identical table diff, because the
  baseline accumulated ~2 weeks of unrelated drift before this phase could be closed. See
  Decisions above and the Phase 8 checklist annotation in the plan file for full detail.

## Verification

- Build: N/A
- Tests: N/A (meta/documentation task)
- Files verified: Yes — `jq empty` on all four fragments passes; `has("mcpServers")` is false on
  all four; nix `permissions.allow` exactly matches
  `["mcp__nixos__nix","mcp__nixos__nix_versions"]`; `grep -l mcpServers` across all extension
  fragments returns exactly one path (`memory/settings-fragment.json`); `bash -n` on
  `setup-lean-mcp.sh` exits 0; `check-extension-docs.sh` shows no new failure attributable to
  this task (see Decisions); `check-task-references.sh` PASSes with 0 unexempted occurrences;
  both edited docs carry the workspace-trust caveat and session-snapshot trap sections, and the
  one "subagents cannot reach project-scoped" grep hit is the historical, already-refuted claim
  inside the snapshot trap's own explanation, not a live assertion; `git status --short` shows
  the seven `file_scope` paths clean (already committed) with only pre-existing, unrelated dirty
  state from other concurrent task work present, and no `.claude/**` file was hand-edited.

## Impacts

- Future MCP server additions in this repo now have an accurate ownership doc to follow: hybrid
  scope selection, the same-scope grant rule, the workspace-trust one-time approval cost, and
  the session-start snapshot trap that produced the original wrong "subagents can't reach
  project scope" belief.
- Four extensions (`epidemiology`, `filetypes`, `founder`, `nix`) no longer carry dead
  `mcpServers` declarations or (for `epidemiology`/`filetypes`/`founder`) orphaned permission
  grants in their settings fragments.

## Follow-ups

The Phase 7 residual-consistency audit (report-only) recorded ten sites, all deliberately out of
`file_scope` and unedited by this task:
- `agent-system/extensions/nix/README.md` (MCP Tool Setup section) — stale "not currently
  registered" claim
- `agent-system/extensions/filetypes/README.md:54-55` — repeats the refuted subagent-approval
  premise
- `agent-system/extensions/epidemiology/README.md:28-30` — describes the deleted `rmcp` block as
  if live
- `agent-system/extensions/founder/README.md:33-67` — describes the deleted
  `firecrawl`/`sec-edgar` blocks/grants as if live
- Five manifests' dead `mcp_servers` field (`filetypes`, `founder`, `lean`, `memory`, `nix`)
- The live playwright grant asymmetry (registered user scope, granted only in `web`/`present`
  fragments)
- `agent-system/extensions/memory/settings-fragment.json` — the one legitimately surviving
  `mcpServers` block
- `agent-system/extensions/core/docs/docs-README.md:77` — asserts the categorical subagent
  barrier claim verbatim
- `agent-system/extensions/core/docs/architecture/extension-system.md:227,500` — two stale
  "only user-scope registers" statements
- `agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md:27,45-46` —
  repeats the refuted approval-barrier premise as lean-lsp's stated registration reason

Separately, unrelated repo drift accumulated on `specs/tmp/doclint-baseline.txt` since its
2026-08-11 capture (10 new `core` index-entries.json mismatches, 3 new project-wide Rule-S
failures, a changed `literature` failure reason) — none attributable to this task, but worth a
dedicated doc-lint/index-freshness pass at some point.

## References

- `specs/028_correct_mcp_ownership_model_and_purge_dead_declarations/plans/01_mcp-ownership-hybrid-rewrite.md`
- `specs/028_correct_mcp_ownership_model_and_purge_dead_declarations/reports/01_mcp-ownership-rewrite-and-purge-spec.md`
- `specs/tmp/doclint-baseline.txt`
