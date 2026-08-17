# Implementation Summary: Task #55

- **Task**: 55 - Dedupe orchestrate skill bodies (LEVER 1: the two orchestrate skills)
- **Status**: [COMPLETED]
- **Started**: 2026-08-12T19:49:39Z
- **Completed**: 2026-08-12T23:25:00Z
- **Effort**: ~3.5 hours
- **Dependencies**: Task 48
- **Artifacts**: plans/01_dedupe-orchestrate-skill-bodies.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the byte-identical duplication between `skill-orchestrate/SKILL.md` and
`skill-orchestrate-hard/SKILL.md` by moving the shared logic into `scripts/skill-base.sh`
functions and three new `scripts/orchestrate-*.sh` stdout-JSON scripts, following the
already-established `orchestrate-recover-outcome.sh` pattern. All seven plan phases completed;
every existing orchestration test passes unmodified.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — four new `skill_orchestrate_*`
  functions: `skill_orchestrate_mint_dispatch_seq`, `skill_orchestrate_append_detected_defect`,
  `skill_orchestrate_propagate_completion`, `skill_orchestrate_merge_return_meta`.
- `agent-system/extensions/core/scripts/orchestrate-stage5-gates.sh` — new; shared stray-handoff
  sweep + `.return-meta.json` outcome-recovery orchestration with evidence corroboration.
- `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` — new; shared
  `case "$dispatch_status"` postflight tail (completion-claim gate, completion propagation,
  artifact linking, off-schema Tier C handling). Prints a decision JSON; callers apply the
  `EXIT (partial)` / cycle_count transition inline, never the script.
- `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh` — new; shared Stage 2
  prologue (`MAX_INFRA_FAILURES`, `loop_guard_file`/`handoff_file` assignment, `mkdir -p`, the
  blocker-escalation counter pair).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — reduced from 196,171 B to
  171,071 B (-25,100 B); every extracted block replaced with a named shim or a script call.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — reduced from 127,145 B
  to 102,774 B (-24,371 B); same treatment, plus preserved hard-only additions
  (`skeleton`/`sorry_inventory` reset, the extra refusal diagnostic).
- `agent-system/extensions/core/manifest.json` — registered the three new scripts in
  `provides.scripts` (required for `deploy-headless.sh` to sync them into `.claude/scripts/`;
  omitting this silently strands a new script in the source store).
- `specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md` — Phase 1 manifest (new).

## Decisions

- **Named-shim preservation, applied literally.** `mint_dispatch_seq()`, `append_detected_defect()`,
  and `hard_orchestrate_propagate_completion()` all keep <=3-line local definitions in both
  SKILL.md files, delegating to the shared `skill_orchestrate_*` implementations. No call site
  inside a locked region was ever renamed.
- **`skill_orchestrate_propagate_completion` takes an explicit `notice_prefix` 6th parameter**
  (defaulting to `[orchestrate]`), a deliberate widening beyond the plan's literal signature
  suggestion, to satisfy the "notice prefix is always an explicit parameter" risk mitigation
  uniformly across all four promoted functions.
- **`skill_orchestrate_merge_return_meta` takes a resolved `detected_defects` JSON string, not a
  loop-guard path.** The base engine's clean-exit call site reads that value in an EARLIER fence,
  before its own `rm -f "$loop_guard_file"` cleanup; a function that re-read from the guard path
  itself would silently see an already-deleted file at that one call site. Requiring the caller to
  resolve the value at the same point the pre-dedup inline code did preserves the base/hard
  ordering asymmetry exactly.
- **`orchestrate-stage5-postflight.sh` performs the real state.json/TODO.md writes** (via
  `skill_postflight_update`, `skill_gate_completion_claim`, `skill_orchestrate_propagate_completion`,
  `skill_link_artifacts`) but never decides or applies the orchestrator's own loop-control
  transition (`EXIT (partial)`, cycle_count increment) — those stay inline in each SKILL.md,
  applied from the script's decision JSON. This is the mitigation for the "script boundary
  swallows a state transition" risk named in the plan.
- **Phase 6's extraction is deliberately small.** Hard mode has no Stage 5a Drift Inspection
  equivalent at all (its own H5 divergence-audit plays that role), so only the blocker-escalation
  counter pair was genuinely shared between engines; base's drift-detection constants stay inline,
  base-only. A small measured result here is correct, not a shortfall, per the plan's own Scope
  Hypothesis.

## Plan Deviations

- **Phase 2**: `skill_orchestrate_propagate_completion` gained an extra optional `notice_prefix`
  parameter beyond the plan's literal signature — recorded above under Decisions, not a scope
  reduction.
- **Phase 5**: `skill_orchestrate_merge_return_meta` takes a resolved `detected_defects` JSON
  string instead of a loop-guard path — recorded above under Decisions, required for correctness
  (base's clean-exit ordering would otherwise silently lose the observation log).
- **Manifest registration**: added `orchestrate-stage5-gates.sh`, `orchestrate-stage5-postflight.sh`,
  and `orchestrate-loop-guard-init.sh` to `agent-system/extensions/core/manifest.json`'s
  `provides.scripts` list. Not named in the plan's Files-to-modify lists, but mechanically
  required — `deploy-headless.sh` only syncs manifest-registered files, so a new script silently
  never reaches `.claude/scripts/` without this registration. In scope as necessary plumbing for
  "new ... scripts/orchestrate-*.sh", not a territory violation.

## Verification

- Build: N/A (bash scripts + markdown skill files)
- Tests: **Passed** — `scripts/tests/run-all.sh`: 42 passed, 0 failed, 0 skipped, 42 total,
  matching the Phase 1 baseline exactly. `git status` on `scripts/tests/` is clean — **zero test
  files modified**, at any phase.
  - `test-handoff-dispatch-identity.sh` (the most sensitive test — `eval`s the locked
    Staleness-gate/dispatch-seq-gate region with a stubbed `append_detected_defect`): 22/22,
    re-verified after every phase touching Stage 5.
  - `test-loop-guard-budget-override.sh` (the second `eval`ing test, locked
    budget-continuation-override region): 36/36, re-verified after Phase 6.
  - `test-handoff-reader-parity.sh`: 19/19, verifying the ~13 literal `$handoff` jq reads and the
    `dispatch-seq-gate` sentinel byte-identity survived every phase.
  - `test-routing-resolution.sh`: 18/18, `command-route-agent.sh` invocation count unchanged at 3
    per file.
  - `test-loop-guard-staleness.sh`: 28/28. `test-reconcile-handoff-status.sh`: 14/14.
    `test-validate-handoff.sh`: 10/10. `test-validate-handoff-location.sh`: 9/9.
    `test-validate-return-meta.sh`: 14/14. `test-skill-base-lifecycle.sh`: 18/18.
  - One transient flake was observed on an intermediate full-suite run:
    `test-handoff-dispatch-identity.sh`'s `case2-mismatch-inside-window (base)` failed on a
    sub-second mtime race inside the test's own fixture setup (a region this task never touched).
    Re-ran in isolation 3x, clean 3/3; a subsequent full clean `run-all.sh` re-run confirmed
    42/42. Reported honestly per the acceptance bar rather than omitted.
  - Every new `orchestrate-*.sh` script is `bash -n` clean and was run standalone against a
    fixture task directory, printing valid JSON and (for `orchestrate-stage5-postflight.sh`)
    correctly flipping a fixture `state.json` task from `implementing` to `completed`.
- Files verified: Yes — every source-store file diffed byte-identical against its deployed
  `.claude/` counterpart after `deploy-headless.sh`.

## Acceptance Measurement

### Before/after byte table (against the Phase 1 baseline)

| File | Before | After | Delta |
|---|---:|---:|---:|
| `skills/skill-orchestrate/SKILL.md` | 196,171 | 171,071 | -25,100 |
| `skills/skill-orchestrate-hard/SKILL.md` | 127,145 | 102,774 | -24,371 |
| `scripts/skill-base.sh` | 51,859 | 60,770 | +8,911 |
| `scripts/orchestrate-stage5-gates.sh` | 0 (new) | 18,656 | +18,656 |
| `scripts/orchestrate-stage5-postflight.sh` | 0 (new) | 12,768 | +12,768 |
| `scripts/orchestrate-loop-guard-init.sh` | 0 (new) | 2,704 | +2,704 |
| `scripts/orchestrate-batch-admit.sh` | 33,855 | 33,855 | 0 (unchanged) |
| `scripts/orchestrate-dry-run-report.sh` | 32,072 | 32,072 | 0 (unchanged) |
| `scripts/orchestrate-predispatch-review.sh` | 27,325 | 27,325 | 0 (unchanged) |
| `scripts/orchestrate-recover-outcome.sh` | 13,667 | 13,667 | 0 (unchanged) |
| `scripts/orchestrate-triage-classify.sh` | 17,814 | 17,814 | 0 (unchanged) |

Net across all touched/new files: **-6,432 B** (even counting every new-script byte as cost).
Duplication removed from the SKILL.md pair alone: **49,471 B** — well above the 28,421+ B floor
the task asserts.

### Eager-prefix + command + skill + agent accounting (per-invocation total)

Both orchestrate skills are direct-execution — the agent term is 0 for both, stated explicitly.

| Engine | Eager prefix | Command | Skill (before) | Skill (after) | Agent | Total before | Total after | Delta |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `/orchestrate` | 63,922 | 43,180 | 196,171 | 171,071 | 0 | 303,273 | 278,173 | -25,100 |
| `/orchestrate --hard` | 63,922 | 43,180 | 127,145 | 102,774 | 0 | 234,247 | 210,076 | -24,371 |

Eager prefix = generated `CLAUDE.md` (33,215 B, unchanged) + the eager `rules/*.md` set (30,707 B
sum, unchanged) — neither touched by this task (out of territory per the plan's Non-Goals).
`commands/orchestrate.md` (43,180 B, unchanged) likewise untouched.

### Remaining intentional duplication (single-home proof)

The duplicated logic now exists in exactly ONE place for every case NOT listed below. What
remains duplicated is enumerated here, each with the specific test that requires it to stay:

| Remaining duplicate | Size | Required by |
|---|---|---|
| `dispatch-seq-gate` sentinel region (Staleness gate through `:end`) | base 6,037 B / hard 6,314 B, byte-identical after normalizing notice prefix + a hard-only cross-reference comment | `test-handoff-dispatch-identity.sh` (`eval`s it with a stubbed `append_detected_defect`), `test-handoff-reader-parity.sh` (byte-identity assertion) |
| `budget-continuation-override` region + resume-read echo | base 4,916 B / hard 4,180 B | `test-loop-guard-budget-override.sh` (`eval`s it from a temp-workdir cwd) |
| ~13 literal `$handoff`-anchored one-line jq reads | well under 1 KB per file | `test-handoff-reader-parity.sh` (regex-extracts them by exact literal shape) |
| Named shims (`mint_dispatch_seq`, `append_detected_defect`, `hard_orchestrate_propagate_completion`) | <=3 lines each, x2-3 per file | `test-handoff-dispatch-identity.sh` stubs `append_detected_defect` by exact name; call-site identifiers must never be renamed |

A normalized diff of the dispatch-seq-gate region confirms this: after substituting
`[hard-orchestrate]`->`[orchestrate]` and `skill-orchestrate-hard/SKILL.md`->
`skill-orchestrate/SKILL.md`, the only remaining difference is one extra cross-reference comment
line in the hard file.

### Divergence enumeration (no behavior lost)

| Divergence | Status |
|---|---|
| `skeleton` reads/resets | Hard-only, inline, untouched (8 occurrences) |
| `sorry_inventory` reads/resets | Hard-only, inline, untouched (8 occurrences) |
| `loop-guard-staleness` detector | Hard-only, sentinel-bounded, untouched (1 region) |
| Base Stage-5-location `marker-handoff-crosscheck` | Inline, untouched (1 sentinel pair) |
| Hard H1-location `marker-handoff-crosscheck` (`resume-scan-conformance-gate`) | Inline, untouched (1 sentinel pair) — intentionally NOT unified with the base location |
| Detecting-site strings (`skill-orchestrate/SKILL.md:stage-5-tier-c` vs. `skill-orchestrate-hard/SKILL.md:tier-c`) | Preserved verbatim, passed as explicit `tier_c_detecting_site` arguments to `orchestrate-stage5-postflight.sh` |
| `command-route-agent.sh` invocation count | Unchanged at 3 per file (floor met) |

## Impacts

- Both orchestrate engines now call four shared `skill_orchestrate_*` functions and three shared
  `orchestrate-*.sh` scripts by name for logic that previously had to be hand-kept in sync across
  two 100K+ byte files — a known recurring defect class the files themselves documented.
- Per-invocation prompt-context cost for `/orchestrate` and `/orchestrate --hard` drops by
  ~25,000 and ~24,000 bytes respectively, with no test regression and no behavior loss.
- Future fixes to the stray-handoff sweep, outcome recovery, evidence corroboration, the
  postflight status-transition tail, artifact linking, or the return-meta merge only need to
  change once.

## Follow-ups

- The research report recommends documenting the `skill_*`-vs-`orchestrate-*.sh` boundary in
  `context/architecture/orchestrate-state-machine.md`. That file is outside this task's territory
  (Non-Goals explicitly exclude it), so the recommendation is handed off here rather than done.
- Phase 6's extraction was intentionally small (hard mode has no drift-detection constants to
  share with base). If a future task wants to further reduce Stage 2 duplication, the remaining
  candidate is normalizing the two `MAX_CYCLES` values' surrounding comment prose — not attempted
  here since the values themselves (5 vs. 13) are genuinely per-engine.
- None of `commands/todo.md`, `commands/orchestrate.md`, rules, or merge sources were edited, per
  the plan's Non-Goals — those remain sibling-task territory.

## References

- `specs/055_dedupe_orchestrate_skill_bodies/plans/01_dedupe-orchestrate-skill-bodies.md`
- `specs/055_dedupe_orchestrate_skill_bodies/reports/01_dedupe-orchestrate-skill-bodies.md`
- `specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md`
