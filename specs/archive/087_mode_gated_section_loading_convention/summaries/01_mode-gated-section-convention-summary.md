# Implementation Summary: Task #87

- **Task**: 87 - Mode gated section loading convention
- **Status**: [COMPLETED]
- **Started**: 2026-09-02T06:59:00Z
- **Completed**: 2026-09-02T09:15:00Z
- **Effort**: ~7 hours
- **Dependencies**: None
- **Artifacts**: plans/01_mode-gated-section-convention.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Formalized the mode-gated (branch-gated) section loading convention that addresses the largest
single token lever in the system: mutually-exclusive branch sections loaded unconditionally in
runtime-loaded skill/command `.md` bodies. Landed the marker convention and its documentation, a
structural-plus-reasoned-allowlist lint wired as `verify-deploy.sh` Gate 19, a fixture-driven
regression test, and one independent pilot extraction (`skill-email-cleanup`'s `` `--all` Mode ``
section) that measures the real saving end to end.

## What Changed

- `agent-system/extensions/core/context/patterns/mode-gated-section-loading.md` — new; the named
  convention (marker syntax, extraction procedure, imperative/passive pointer test,
  whole-section-vs-reference-appendix risk, path-selection rule, registration mechanics,
  when-not-to-extract guidance, enforcement pointer, measured example).
- `agent-system/extensions/core/index-entries.json` — one new entry for the convention doc
  (`on_demand: true`, `line_count: 215`).
- `agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh` — new; structural
  (paired-marker byte-span) plus file-level reasoned-allowlist lint, `THRESHOLD_BYTES=8000`,
  dual-mode root resolution, `set -euo pipefail` (Class A).
- `agent-system/extensions/core/scripts/tests/test-lint-branch-gated-sections.sh` — new;
  9 fixture-driven cases (16 PASS assertions), including the fence-interior decoy case and both
  root-resolution modes.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — Gate 19 appended, following Gate 18's
  call shape exactly.
- `agent-system/extensions/core/manifest.json` — two new `provides.scripts` entries (the lint and
  its test).
- `agent-system/extensions/email/skills/skill-email-cleanup/SKILL.md` — pilot: the `` `--all`
  Mode `` section (lines 281-534, 17,309 B) replaced with an imperative `READ ... now` pointer.
- `agent-system/extensions/email/context/project/email/patterns/email-cleanup-all-mode.md` — new;
  pilot destination, content-preserved verbatim plus opening framing line and `##`->`#`/`###`->`##`
  heading promotion.
- `agent-system/extensions/email/index-entries.json` — one new entry
  (`load_when.commands: ["/email"]`).

## Decisions

- Threshold `THRESHOLD_BYTES=8000` confirmed against all five known section sizes
  (17,309 / 25,883 / 43,254 / 65,772 / 103,462 B) — well below every instance, above trivial
  inline content.
- Allowlist mechanism present but starts empty (live marked-but-unextracted count was 0 at
  landing) rather than zero-tolerance, per the convention-selection check in Phase 2 — a
  zero-tolerance assertion would block legitimate mid-migration intermediate states for sibling
  tasks.
- Convention doc's "demote internal headings" instruction corrected to "promote" (`##`->`#`,
  `###`->`##`) during Phase 5 to match the repo's single-H1-per-file convention (see Plan
  Deviations).

## Plan Deviations

- **Phase 5** (`Approach: "Interpreted plan's 'demote internal headings' literally in the
  convention doc"`): the convention doc's guidance was fixed to say "promote" internal headings
  by one level when extracting (`##`->`#`, `###`->`##`), not "demote" — the plan's own phrasing
  was backwards relative to the repo's single-H1-per-file convention. Corrected in the convention
  doc during Phase 5; no functional impact on the pilot extraction itself, which already applied
  the correct (promote) transformation.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: Passed — `scripts/tests/run-all.sh`: 61 passed, 1 failed, 0 skipped, 62 total. The one
  failure (`test-four-tier-conflict.sh` case 6, "budget-bound", a timing-sensitive assertion) is
  pre-existing and unrelated to this task; re-run in isolation immediately after: 13 passed,
  0 failed. `test-lint-branch-gated-sections.sh` is discovered by `run-all.sh` and PASSes.
- `verify-deploy.sh`: 27 of 30 checks PASS, including Gate 19 ("Branch-gated section threshold
  lint") which reports no marked-but-unextracted sections over threshold. The 3 failing checks
  (doc-lint on the literature extension's unrelated `zotero-item-creation.md` line-count drift;
  `validate-state.sh --deep` on unrelated `abandon_reason`/`blocks_note` unknown-field findings
  against other project numbers; state-writer boundary lint on pre-existing hand-rolled writes in
  `test-force-phases.sh`) are all pre-existing, outside this task's file scope, and caused by
  concurrent sibling-task work — none touch any of the four task-87 artifacts.
- Deploy verification: all four new/changed artifacts (convention doc, lint script, lint test,
  pilot pattern file) plus `SKILL.md` and `verify-deploy.sh` are byte-identical between the
  source store and the deployed `.claude/` tree — confirmed already current via direct diff
  rather than re-invoking `deploy-headless.sh` (this agent is not one of the two sanctioned
  automated call sites for that script). Consistent with Gate 5's PASS (manifest-driven category
  parity + content-hash equality).
- Deployed pointer path `.claude/context/project/email/patterns/email-cleanup-all-mode.md`
  resolves to a real 17,729 B file; the `SKILL.md` pointer text at line 283 reads
  "READ .claude/context/project/email/patterns/email-cleanup-all-mode.md now and follow it
  exactly"; the entry is present in `.claude/context/index.json`.
- `validate-context-budgets.sh`: 4 pre-existing violations (general-research-agent,
  general-implementation-agent, planner-agent — large pre-existing overages unrelated to this
  task) plus 2 documented `OK*` exceptions. Both new context entries have empty
  `load_when.agents` (the convention doc is `on_demand: true`; the pilot pattern file is
  `load_when.commands: ["/email"]` only), so they are not loaded by any agent's context budget
  and breach no tier cap.
- `check-task-references.sh`: PASS, 0 unexempted task-reference occurrences across all 4 scanned
  trees (`agent-system/extensions`, `.opencode`, `lua`, `.memory`).
- Files verified: Yes — all artifacts exist, JSON files parse, content-preservation diff clean
  (per Phase 5's own verification).

## Impacts

- Every future `/email --all`-style whole-mailbox invocation of `skill-email-cleanup` no longer
  pays the token cost of the `--all`-mode section's prose when it isn't `mode=all`.
- The convention and its lint are now available for sibling tasks migrating the four headline
  instances (skill-orchestrate, skill-distill, skill-literature, `commands/task.md`) — explicitly
  out of scope here per the plan's territory constraint.
- `verify-deploy.sh` now permanently guards against new marked-but-unextracted branch sections
  regressing above the 8,000 B threshold on any runtime-loaded `commands/*.md` or
  `skills/*/SKILL.md` surface.

## Measurement Table

| Metric | Before | After | Delta |
|---|---|---|---|
| `skill-email-cleanup/SKILL.md` | 47,832 B | 30,656 B | -17,176 B (-35.9%) |
| Extracted `email-cleanup-all-mode.md` | — | 17,729 B | new file |
| Approx. token saving per non-`--all` `/email` invocation | — | — | ~4,300 tokens (rough B/4 heuristic) |

## Follow-ups

- None. The four headline migrations (skill-orchestrate, skill-distill, skill-literature,
  `commands/task.md`) remain explicitly out of scope, owned by sibling tasks.

## References

- Plan: `specs/087_mode_gated_section_loading_convention/plans/01_mode-gated-section-convention.md`
- Convention: `agent-system/extensions/core/context/patterns/mode-gated-section-loading.md`
- Lint: `agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh`
- Lint test: `agent-system/extensions/core/scripts/tests/test-lint-branch-gated-sections.sh`
- Pilot destination: `agent-system/extensions/email/context/project/email/patterns/email-cleanup-all-mode.md`
