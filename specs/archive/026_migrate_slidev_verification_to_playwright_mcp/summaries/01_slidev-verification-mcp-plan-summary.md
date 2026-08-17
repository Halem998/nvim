# Implementation Summary: Task #26

- **Task**: 26 - Migrate slidev deck screenshot verification from the standalone npm Playwright script to the live Playwright MCP server
- **Status**: [COMPLETED]
- **Started**: 2026-08-10T23:53:00Z
- **Completed**: 2026-08-11T00:45:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: 24 (scoped Playwright MCP permission allowlist) — completed
- **Artifacts**: plans/01_slidev-verification-mcp-plan.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This was resolved as a deliberate **keep-plus-add** outcome, not a full migration. `playwright-verify.mjs` remains the required, deterministic, batch verification gate for Slidev decks; the Playwright MCP server is added as a documented, optional, ad hoc single-slide debugging capability. All 5 plan phases completed: new permission plumbing for the `present` extension, an MCP Tools grant in `slidev-assembly-agent`'s contract, a written justification for keeping the script plus the ad hoc MCP workflow documentation, a downstream reference/index consistency sweep, and a final gate confirming the outcome landed cleanly with no regressions.

## What Changed

- `agent-system/extensions/present/settings-fragment.json` — NEW. `permissions.allow` with the same 9 Playwright MCP tool names as `web/settings-fragment.json` (set-equal, no wildcard): `browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests`, `browser_click`, `browser_type`, `browser_find`, `browser_wait_for`.
- `agent-system/extensions/present/manifest.json` — added a `"settings"` entry to `merge_targets` (`{"source": "settings-fragment.json", "target": ".claude/settings.local.json"}`), mirroring `web`'s exactly.
- `agent-system/extensions/present/README.md` — added the `settings-fragment.json` line to the Architecture tree.
- `agent-system/extensions/present/agents/slidev-assembly-agent.md` — added an `### MCP Tools` subsection under `## Allowed Tools`, listing the 4 tools needed for ad hoc single-slide inspection (`browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_console_messages`) plus a scope note cross-referencing `slidev-pitfalls.md`'s "Ad Hoc Single-Slide Inspection via MCP" section.
- `agent-system/extensions/present/context/project/present/talk/patterns/slidev-pitfalls.md` — the task's primary deliverable. Added a "Why This Phase Uses a Script, Not MCP Tools" subsection inside "Required Final Phase: Playwright Verification" stating the three justifications (determinism/CI, cost at scale, check fidelity), and a new sibling "Ad Hoc Single-Slide Inspection via MCP" section describing the workflow with an explicit "complements and does not replace" statement and the open `browser_console_messages`/`pageerror`-parity caveat.
- `agent-system/extensions/present/context/project/present/domain/talk-modes-and-library.md` — reworded the `talk/templates/` table row to name the script and its batch role explicitly.
- `agent-system/extensions/present/context/project/present/talk/templates/slidev-project/README.md` — reworded the `package.json` row to state `playwright-chromium`'s dual role (Slidev's own PDF export **and** the batch verification script) so it is not mistaken for a removable duplicate.
- `agent-system/extensions/present/context/project/present/talk/index.json` — updated the `playwright-verify` entry's `description` to state its required-batch-gate role, preserving the existing "copy to scripts/verify-slides.mjs" guidance.
- `agent-system/extensions/present/index-entries.json` — updated the `playwright-verify.mjs` entry's `summary` to match; also corrected its `line_count` field for the *`slidev-pitfalls.md`* entry (253 → 294) after that file grew from the Phase 3 additions — a pre-existing `check-extension-docs.sh` consistency rule, not part of the plan's asserted 4-site sweep, caught by the Phase 5 gate run and fixed before completion (see Plan Deviations).

## Decisions

- Kept `playwright-verify.mjs` as the required batch verification mechanism rather than removing it — the acceptance criterion's alternate branch ("its continued existence is explicitly justified in writing") is satisfied by the new "Why This Phase Uses a Script, Not MCP Tools" subsection in `slidev-pitfalls.md` (determinism/CI capability, cost at scale, check fidelity, in that order of weight).
- Gave `present` its own new `settings-fragment.json` + `manifest.json` entry rather than adding `web` to `present`'s `dependencies` — avoids pulling `web`'s unrelated agents/skills/rules into every `present` deployment, consistent with `mcp-server-ownership.md`'s domain-ownership guidance.
- Enumerated the 9 safe tool names verbatim rather than using a `mcp__playwright__*` wildcard, per `mcp-server-ownership.md`'s carve-out — a wildcard would silently re-permit `browser_evaluate`/`browser_run_code_unsafe`/`browser_file_upload`.

## Plan Deviations

- **Phase 5 verification** surfaced an unplanned `check-extension-docs.sh` line_count-mismatch failure for the `present` extension's `slidev-pitfalls.md` index entry (Phase 3 grew that file from 253 to 294 lines, and the entry's `line_count` field was not part of the plan's asserted Phase 4 edit list). Fixed in place using the project's existing `generate-context-line-counts.sh --write` maintenance script before declaring Phase 5 complete, so the gate's "no new failures relative to baseline" criterion holds. This is a minor, mechanically-detected addition to Phase 4's scope, not a deviation from the plan's intent.
- The same `--write` run touched an out-of-scope file (`agent-system/extensions/literature/index-entries.json`, unrelated to this task) as a side effect of running the script across all extensions; that change was identified and manually reverted so the task's diff stays scoped to `present`.

## Verification

- Build: N/A (no build step for this task)
- Tests: N/A
- Files verified: Yes — see Phase 1-5 verification runs below
- `jq empty` passes on `present/settings-fragment.json`, `present/manifest.json`, `present/talk/index.json`, `present/index-entries.json`
- `present/settings-fragment.json`'s `permissions.allow` is set-equal to `web/settings-fragment.json`'s (diff produces no output), no wildcard entry
- All 4 MCP tool names in `slidev-assembly-agent.md`'s new subsection are present in `present/settings-fragment.json`'s allow list
- `slidev-pitfalls.md` contains both the written justification (all 3 rationales) and the ad hoc MCP section (with the "complements, does not replace" statement and the console-coverage caveat); `grep -c '^### Phase '` unchanged at 2 before/after
- Full `grep -rni playwright` sweep across `present` and `founder` confirmed exactly the 4 asserted downstream sites needed wording changes, with no wording implying removal/migration remaining
- `bash .claude/scripts/check-extension-docs.sh` — baseline (pre-Phase-1) had 3 FAIL issues (`literature`, `web`, plus the `web` line_count mismatch bundled in that count); post-Phase-5 run has 2 FAIL issues, with no new failure introduced by this task's edits (the `present` extension is clean; the remaining `literature` FAIL is pre-existing and out of this task's scope)
- `bash .claude/scripts/check-task-references.sh` exits 0
- `git status --short` shows modifications only under `agent-system/extensions/present/**` and `specs/026_migrate_slidev_verification_to_playwright_mcp/**` (plus pre-existing, unrelated dirty files from other in-flight work) — zero `.claude/**` paths, zero `agent-system/extensions/founder/**` paths
- `playwright-verify.mjs` is confirmed unmodified (`git diff --stat` shows no hunk for it)
- `git diff -- agent-system/extensions/founder` is empty

## Impacts

- `present` now has its own scoped Playwright MCP permission grant, independent of `web`, following the domain-ownership pattern `mcp-server-ownership.md` establishes.
- `slidev-assembly-agent` can call 4 specific Playwright MCP tools for ad hoc single-slide debugging without prompting, once the extension is deployed and the settings fragment is merged.
- `slidev-pitfalls.md` now carries a durable, in-source-store record of why the batch script is kept, discharging the acceptance criterion's alternate branch for any future reader (human or agent) who might otherwise read the task's title as calling for a full migration.

## Follow-ups

- **Founder no-op, evidenced**: `founder/agents/deck-builder-agent.md`'s only Playwright content is the Stage 2.5 CLI availability probe (`npx playwright --version`) gating the Stage 8 non-blocking PDF export; `founder/context/project/founder/patterns/slidev-deck-template.md`'s two Playwright mentions are both `slidev export` PDF-capability documentation lines. Neither file references `playwright-verify.mjs` or any per-slide verification phase (confirmed via `grep -n -B3 -A5 -i playwright` on both files). No functional edit was made to either file, per the plan's Non-Goals; `founder` intentionally receives no MCP permission plumbing under this task's scope. If a future task adds visual/screenshot-based verification to `deck-builder-agent`'s pipeline, it would need the identical treatment (a new/extended settings-fragment entry plus an Allowed Tools addition) at that time.
- **Two-place drift note**: the 9-tool Playwright MCP safe-tool list now exists in two extension fragments (`web/settings-fragment.json` and `present/settings-fragment.json`). This is an accepted, already-documented cost per `mcp-server-ownership.md`'s carve-out — not a new risk introduced by this task — but a future maintainer changing Playwright's safe-tool surface (adding or removing a permitted tool name) must update both fragments, not just one.
- **Acceptance branch satisfied**: "its continued existence is explicitly justified in writing." The justification lives in `agent-system/extensions/present/context/project/present/talk/patterns/slidev-pitfalls.md`, in the "Why This Phase Uses a Script, Not MCP Tools" subsection (inside "Required Final Phase: Playwright Verification").
- **Open verification item carried forward from research**: whether `browser_console_messages` surfaces uncaught `pageerror`-style exceptions the same way the script's `page.on('pageerror', ...)` listener does was not empirically tested in this task (out of scope — no live dev-server/deck was available in this implementation run). This remains a stated, explicit caveat in `slidev-pitfalls.md`'s ad hoc section rather than a silently-assumed parity; any future adopter of the ad hoc path should verify it against a real deck with an injected `pageerror` before relying on it for coverage.
- A future task proposal (explicitly out of scope here, per research's Context Extension Recommendations): extend `slide-critic-agent` to consume rendered screenshots (from the batch script's output or an MCP `browser_take_screenshot` call) for visual/layout critique, since it currently evaluates only text-based source materials.

## References

- Plan: `specs/026_migrate_slidev_verification_to_playwright_mcp/plans/01_slidev-verification-mcp-plan.md`
- Research report: `specs/026_migrate_slidev_verification_to_playwright_mcp/reports/01_slidev-verification-mcp-migration.md`
- Prerequisite: `web/settings-fragment.json` (task 24's deliverable, the 9-tool source list copied verbatim)
- Pattern reference: `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
