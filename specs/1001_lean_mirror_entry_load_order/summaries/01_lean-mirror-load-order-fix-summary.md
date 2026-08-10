# Implementation Summary: Lean Mirror Entry Load-Order Fix

- **Task**: 1001 - Fix lean mirror entry load-order defect; audit duplicated index paths
- **Status**: [IN PROGRESS]
- **Started**: 2026-08-09T00:00:00Z
- **Completed**: (pending Phase 4 closing gate)
- **Effort**: 2 hours (estimated)
- **Dependencies**: Task 1000 (completed -- establishes and proves the union-valued pattern)
- **Artifacts**: plans/01_lean-mirror-load-order-fix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Lean's `agent-system/extensions/lean/index-entries.json` declared three mirror entries for
`context/contracts/*.md` files whose `load_when.agents` lists were strictly narrower than their
core counterparts. Because `merge.append_index_entries` upserts index entries by path and replaces
the whole entry object (no per-field merge), a lean-loaded deploy that processes lean after core
silently drops core's agent hooks on all three paths, with no error signal. This work
union-valued all three entries and proved the fix with an **executed** headless-Neovim
reconstruction of the actual core-then-lean merge, asserting on the merged output rather than
reading the edited JSON. It also re-ran the duplicated-path audit fresh across all 19 extensions
and records the cslib internal-duplicate finding and two follow-up candidates without implementing
either, per the task's explicit scope decisions.

## What Changed

- `agent-system/extensions/lean/index-entries.json` -- three `load_when.agents` arrays widened to
  their unions with core's corresponding entry:
  - `contracts/adversarial-verification.md`: `["lean-research-hard-agent"]` ->
    `["lean-research-hard-agent", "general-research-hard-agent"]`
  - `contracts/reference-grounding.md`: `["lean-research-hard-agent", "lean-implementation-hard-agent"]`
    -> `["lean-research-hard-agent", "lean-implementation-hard-agent", "general-research-hard-agent",
    "planner-hard-agent"]`
  - `contracts/anti-analysis.md`: `["lean-research-hard-agent", "lean-implementation-hard-agent"]`
    -> `["lean-research-hard-agent", "lean-implementation-hard-agent",
    "general-implementation-hard-agent", "general-research-hard-agent"]`
  - No other field (`line_count`, `task_types`, `domain`, `subdomain`, `summary`, `keywords`) was
    touched on any of the three entries.

## Verification Method (Phase 1 -- the mandated bar)

A disposable headless-Neovim Lua script (written under the session scratchpad directory, deleted
before task close) required the real
`neotex.plugins.ai.shared.extensions.merge.append_index_entries` function and called it twice
against a scratch index file: once with core's actual on-disk `index-entries.json` entries, then
with lean's actual on-disk entries (core-then-lean, the realistic core-then-extension deploy
order). The assertion is on the **merged output**, never on a static read of the edited source
file.

- **Pre-edit run** (captured before the `agent-system/extensions/lean/index-entries.json` edit):
  the merged entry for `contracts/adversarial-verification.md` carried only
  `["lean-research-hard-agent"]` -- the union assertion **demonstrably fails** pre-edit, exactly as
  the task's verification bar requires.
- **Post-edit run**: the merged entry for `contracts/adversarial-verification.md` carried
  `["lean-research-hard-agent", "general-research-hard-agent"]` -- both names present, single
  surviving entry.
- **Extended run (Phase 2)**: re-run against all three paths after the Phase 2 edits; each merged
  entry carried its full expected union:
  - `contracts/adversarial-verification.md`: `["lean-research-hard-agent","general-research-hard-agent"]`
  - `contracts/reference-grounding.md`: `["lean-research-hard-agent","lean-implementation-hard-agent","general-research-hard-agent","planner-hard-agent"]`
  - `contracts/anti-analysis.md`: `["lean-research-hard-agent","lean-implementation-hard-agent","general-implementation-hard-agent","general-research-hard-agent"]`

No static-JSON-read substitution was used at any point; the harness (headless Neovim, this
config's own runtime) was available throughout, so no phase was blocked on this bar.

## Duplicated-Path Audit (re-run fresh, not copied from the research report)

Re-ran both audit queries directly against `agent-system/extensions/*/index-entries.json` (19
extensions) rather than trusting the research report's table on faith.

**Per-extension internal-duplicate scan** (`jq -r '.entries[].path' file | sort | uniq -d` per
extension file): only `cslib` has an internal duplicate. No other extension, including lean and
core, has one.

**Cross-extension duplicate scan** (path declared in more than one extension's own array):

| Path | Declaring extension(s) | Shape | Disposition |
|------|-------------------------|-------|--------------|
| `contracts/adversarial-verification.md` | core, lean, cslib | Cross-extension (core vs. lean; core vs. cslib) | **Fixed here** for lean (Phase 1). Already fixed for cslib by a prior task using the identical union pattern -- confirmed on re-check: cslib's entry currently declares `["general-research-hard-agent","cslib-research-hard-agent"]`. |
| `contracts/reference-grounding.md` | core, lean | Cross-extension | **Fixed here** for lean (Phase 2). |
| `contracts/anti-analysis.md` | core, lean | Cross-extension | **Fixed here** for lean (Phase 2). |
| `project/cslib/standards/ci-pipeline.md` | cslib (twice, within its own array) | Same-file / internal (not cross-extension at all -- collides on every deploy that loads cslib, independent of any other extension) | **Out of `file_scope` for this task; recorded, not fixed** (see disposition below). |

No other duplicated paths were found across the remaining 16 extensions' index files (email,
epidemiology, filetypes, formal, founder, latex, literature, memory, nix, nvim, present, python,
slidev, typst, web, z3) -- each of those extensions' declared paths are unique across the whole
corpus. **Observed divergence from the research report**: the report's prose says "the remaining
15 extensions" but its own parenthetical lists 16 names, and 19 total extensions minus the 3
involved in duplicates (core, cslib, lean) is 16, matching the list -- the "15" in the report's
prose is a minor off-by-one typo, not a re-derived fact; the freshly observed count (16) is what is
recorded here. Total entry count across all 19 files was also re-measured at **479**, one more
than the research report's recorded **478**; the difference was not tracked down further (it is
consistent with ordinary churn from other in-flight tasks between the research and implementation
passes) and the freshly observed number is what is recorded here, per this phase's own Scope
Hypothesis instruction to let the observed numbers win.

### cslib `ci-pipeline.md` Disposition (WORK item 2, explicit)

`agent-system/extensions/cslib/index-entries.json` declares two separate entries for
`project/cslib/standards/ci-pipeline.md`: one with `load_when.agents: ["cslib-implementation-agent"]`
(`task_types: ["cslib","pr"]`), the other with `load_when.agents: ["cslib-implementation-hard-agent"]`
(`task_types: ["cslib"]`). Per `merge.append_index_entries`'s upsert-by-path loop, whichever entry
appears later in cslib's own array wins outright and the earlier one's agent hook and `pr` task type
are silently dropped -- on every deploy that loads cslib, independent of any other extension or load
order. **This is deliberately out of scope for a fix in this task**: `agent-system/extensions/cslib/index-entries.json`
is not in this task's declared `file_scope` (`agent-system/extensions/lean/index-entries.json` is
the entire declared scope), editing outside that scope risks colliding with a concurrent task
holding the cslib file, and the mechanism is genuinely different (same-file array-order collision,
no second extension required) so it warrants its own dedicated fix and verification rather than a
ride-along edit here. It is recorded, per WORK item 2's enumeration mandate, not fixed.

## Follow-Up Candidates (WORK item 3 -- recorded, not implemented)

**Candidate 1 -- a new `check-extension-docs.sh` lint rule.** The existing rule family runs through
Rule U (`EXTENSION.md` length limit); the next available letter is Rule V. Proposed check, to run
once across all `agent-system/extensions/*/index-entries.json` files (not per-extension, since it
is inherently a cross-file check):
  (a) flag any `path` declared by more than one extension's `index-entries.json` where the
      `load_when.agents` sets differ and neither is a superset of the other (the cross-extension
      load-order-collision shape fixed in Phases 1-2 here); and
  (b) unconditionally flag any `path` declared more than once within a single extension's own
      `entries` array (the cslib `ci-pipeline.md` same-file shape, recorded above).
This check would have caught every finding in the audit table above automatically, before it ever
reached a lean-loaded or cslib-loaded deploy. Not implemented here -- WORK item 3 explicitly says
record, do not widen `check-extension-docs.sh` in this task.

**Candidate 2 -- the content-level path collision underneath the fixed hooks.** Lean's
`manifest.json` declares `provides.context: ["project/lean4", "contracts"]`; core's manifest
declares `provides.context` including `"contracts"` as well. Because `copy_category("context", ...)`
copies context files by path, a lean-loaded deploy has lean's `context/contracts/*.md` files
overwrite core's at the same deploy paths. Confirmed by direct inspection: lean's
`context/contracts/adversarial-verification.md` is 93 lines vs. core's 103; lean's
`context/contracts/reference-grounding.md` is 97 lines vs. core's 102; lean's
`context/contracts/anti-analysis.md` is 111 lines, matching core's line count exactly but
containing lean4-specific override content per its own summary metadata ("Lean4 H2 override:
formal proof line bar..."). Consequence, stated plainly: the union index entry fixed in this task
restores the **hook** for `general-research-hard-agent` (and, for the other two paths,
`planner-hard-agent` / `general-implementation-hard-agent`) on a lean-loaded deploy, but that
agent then receives lean's lean4-specialized override **content** at that path, not core's generic
contract. This is the same trade-off task 1000 already accepted for cslib's mirror entry. Recorded
as a follow-up candidate; not fixed here -- it is a separate, larger concern per the plan's
Non-Goals.

## Decisions

- Widened lean's `load_when.agents` arrays by appending core's (or core-plus-planner's) agent
  names after lean's existing names, preserving lean's original array order as a prefix -- matches
  the ordering convention already committed for cslib's entry by the prior task.
- Confirmed both sibling entries (`contracts/reference-grounding.md`, `contracts/anti-analysis.md`)
  were genuine instances of the same defect, not deliberate narrowings -- no `#### Reasoned
  Exclusions` record was needed for Phase 2.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (JSON configuration edit, no build step)
- Tests: N/A -- verified via executed headless-Neovim merge reconstruction (see Verification
  Method above); pre-edit failure and post-edit success both demonstrated
- Files verified: Yes (`jq empty` on the edited file after each phase's edits; `git diff` confined
  to `agents` arrays each time)
- `check-extension-docs.sh` / `generate-context-line-counts.sh --check`: recorded in Phase 4 (see
  Phase 4 checklist in the plan for the closing-gate results)

## Impacts

- A lean-loaded deploy now preserves core's `general-research-hard-agent` (and, for the two
  sibling paths, `planner-hard-agent` / `general-implementation-hard-agent`) hooks on all three
  contract paths instead of silently losing them to lean's narrower entry.
- No change to any file's deployed content, `line_count`, or the set of paths declared -- purely a
  `load_when.agents` widening.
- The union restores the hook only; Follow-Up Candidate 2 above documents the still-open
  content-level override this task deliberately does not resolve.

## Follow-ups

- Candidate 1 (new `check-extension-docs.sh` Rule V for duplicated-path detection) -- not
  implemented, recorded above.
- Candidate 2 (content-level `context/contracts/*.md` override collision) -- not implemented,
  recorded above.
- `agent-system/extensions/cslib/index-entries.json`'s internal `ci-pipeline.md` duplicate --
  out of `file_scope`, recorded above, not fixed by this task.

## References

- Plan: `specs/1001_lean_mirror_entry_load_order/plans/01_lean-mirror-load-order-fix.md`
- Research report: `specs/1001_lean_mirror_entry_load_order/reports/01_lean-mirror-load-order-defect.md`
- Prior pattern reference: Task 1000's completed plan and summary (union-valued `load_when.agents`
  convention, headless-Neovim merge reconstruction verification method)
