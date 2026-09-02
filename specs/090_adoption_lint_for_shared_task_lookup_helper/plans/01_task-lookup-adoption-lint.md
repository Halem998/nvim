# Implementation Plan: Task #90

- **Task**: 90 - Adoption lint for the shared task-lookup helper
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: 124 (state.json `dependencies`); informational sequencing overlap with task 116 and task 48 (see Risks)
- **Research Inputs**: specs/090_adoption_lint_for_shared_task_lookup_helper/reports/01_task-lookup-adoption-lint.md
- **Artifacts**: plans/01_task-lookup-adoption-lint.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build and land `scripts/lint/lint-task-lookup-adoption.sh` in the core source store: a structural
lint that detects the hand-rolled full-record task-lookup jq shape on executable surfaces, exempts
the two canonical implementations and non-lookup jq operations by construction, and carries a
short, explicitly-reasoned file-level allowlist covering today's known offenders so it lands green
immediately. Wire it as `verify-deploy.sh` gate 17 with a fixture-driven regression test, record
the adopter/duplicate baseline so direction is measurable next review, and take only a bounded,
confirmed-safe migration slice — deferring the bulk lifecycle-`SKILL.md` migration until the
core-collapse sequencing question is settled.

Definition of done: a newly introduced inline task-lookup on an executable surface fails the lint;
the lint passes green against the current tree; the gate runs in `verify-deploy.sh`; the baseline
adopter and duplicate counts are recorded in a durable artifact.

### Research Integration

The research report materially corrects the task description and this plan is built on the report,
not the description:

- The duplication class is **63 files / 69 occurrences** of the exact full-record-lookup shape on
  executable surfaces (62 excluding `skill-base.sh` itself), not "111 files". A live re-measure at
  plan time returned 64 files for a near-equivalent narrow regex and 122 for the broad one,
  consistent with the report.
- **`skill_validate_input()` (`skill-base.sh`) has zero real callers.** The "six callers" figure
  described `gate_in()` in `command-gate-in.sh`, a *different* helper at a different layer. The two
  are not interchangeable (different export sets; `exit 1` vs `return 1`; `gate_in` also does
  locking, session registration, and the deploy-freshness warning). The lint targets the
  skill-layer duplication of `skill_validate_input`'s literal shape and must not conflate the two.
- **Target the narrow pattern, not the broad one.** The broad pattern also matches in-place
  mutations, deletions, existence/length checks, and single-field reads that neither helper serves;
  linting it would false-positive on `manage-topics.sh`, `reconcile-artifacts.sh`,
  `update-task-status.sh`, `command-gate-out.sh`, and `spawn.md`.
- **Reuse, do not re-derive, the scan-root and file-scope logic** from
  `tests/test-common-lib.sh`'s `collect_session_id_offenders()`: dual-mode root probe for
  `core/manifest.json`, `*.sh` whole-tree plus `*.md` scoped only to `commands/`, `skills/`,
  `agents/`, leaving `docs/`, `context/`, `rules/` out of scope by construction.
- **Adopt the `lint-state-writer-boundary.sh` enforcement convention** (structural Layer 1 +
  reasoned file-level Layer 2 allowlist), not the zero-tolerance convention, because non-zero
  migration debt exists at landing time.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; ROADMAP.md was not consulted and this
plan adds no roadmap phases.

## Goals & Non-Goals

**Goals**:
- Ship `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh` detecting the
  narrow full-record task-lookup shape on executable surfaces only.
- Land it **green** on the current tree via a reasoned, per-entry-justified allowlist.
- Prove it rejects a *newly introduced* offender via fixture-driven regression tests.
- Wire it as `verify-deploy.sh` gate 17, following the gate 12/15 wiring template exactly.
- Register the new script and its test in `core/manifest.json` so they deploy.
- Record the adopter count and duplicate count in a durable artifact so the next review measures
  direction rather than re-deriving it.
- Write `context/patterns/adoption-lint-conventions.md` naming the two competing adoption-lint
  conventions and the decision rule between them (research's Context Extension Recommendation).

**Non-Goals**:
- Bulk migration of the ~47 lifecycle-`SKILL.md` offender sites. Deferred pending the core-collapse
  sequencing decision, per the orchestration constraint.
- Any edit to `commands/research.md`, `commands/plan.md`, `commands/implement.md` — deleted earlier
  in this batch.
- Any edit to raw `git commit -m` call sites (task 48's territory).
- Unifying `skill_validate_input()` and `gate_in()` into one helper. That is a separate design
  question; this task only stops the duplication class from growing.
- Any hand-authored write under `.claude/**`. All edits target `agent-system/extensions/**`;
  `.claude/**` is reached only via the normal deploy step.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Lint self-fails on the two canonical implementations (`skill-base.sh`, `command-gate-in.sh`), which legitimately *contain* the pattern | H | H | Explicit file-level Layer 2 exemption for both, with the reason stated inline per entry (Phase 3); a dedicated regression test asserts neither is ever flagged (Phase 4) |
| Broad-pattern false positives on legitimate mutations/deletions/existence-checks/field-reads | H | H | Layer 1 structural classifier targets the narrow full-record shape only; Phase 4 plants fixtures for each of the four legitimate shapes and asserts none is flagged |
| Environment-dependent scan root (the defect that made the prior single-source gate worthless) | M | M | Reuse `test-common-lib.sh`'s dual-mode `core/manifest.json` probe verbatim rather than a fresh `../../..` walk; Phase 4 pins the probe with a test |
| `.sh`-only file-type scope, blind to the `.md` executable surfaces where most offenders live | H | M | Scope is `*.sh` whole-tree plus `*.md` under `commands/`/`skills/`/`agents/` by construction; Phase 4 pins deployed-mode `.md` detection and the prose-exclusion boundary |
| Sequencing collision: the core-collapse effort names 47 of 62 offenders as deletion/rewrite candidates | M | H | Land the lint now (cheap, additive; its allowlist is trivially editable when files are deleted). Phase 7's migration slice is bounded and gated on implementation-time confirmation that a candidate is NOT in the deletion set; if none qualifies, close it `[COMPLETED WITH EXCLUSIONS]` with evidence |
| Allowlist becomes a silent dumping ground that never shrinks | M | M | Every entry carries an inline reason (no bare paths, per `lint-state-writer-boundary.sh`'s stated design); Phase 6's convention doc records the shrink-the-allowlist expectation and the decision rule for retiring it |
| Migrating a `SKILL.md` to `skill_validate_input()` breaks it because the skill uses different variable names than the helper exports | H | M | Phase 7 requires per-site variable-parity verification (`TASK_DATA`/`TASK_TYPE`/`TASK_STATUS`/`PROJECT_NAME`/`PADDED_NUM`/`TASK_DIR`/`TASK_DIR_ABS`) and `exit`-vs-`return` semantics review before any edit; a site that does not match is left alone and recorded, not forced |
| Plan-time counts (63/69/62/47) drift before implementation | L | M | Every count-asserting phase carries a **Scope Hypothesis** requiring re-measurement at implementation time; Phase 1 exists specifically to re-derive them before anything is written |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5, 6 | 3 |
| 5 | 7 | 4, 5 |
| 6 | 8 | 4, 5, 6, 7 |

Phases within the same wave can execute in parallel. Wave 4's three phases touch disjoint files
(the test suite, `verify-deploy.sh` + `manifest.json`, and the context doc + `index-entries.json`),
so parallel execution is safe.

---

### Phase 1: Re-measure the class and derive the offender baseline [COMPLETED]

**Goal**: Establish the live, reproducible offender list and the two acceptance numbers (adopter
count, duplicate count) before writing any code, so the lint's allowlist and the recorded baseline
are derived from the tree as it actually is rather than from the report's snapshot.

**Tasks**:
- [x] Re-run the report's narrow and broad measurement commands from the repo root against
      `agent-system/extensions/`; record file counts and occurrence counts for both.
- [x] Enumerate the narrow-pattern offender files, grouped as `scripts/`, `commands/`, `skills/`,
      and note which fall under `deprecated/`.
- [x] Confirm the two canonical implementations still exist and still contain the narrow pattern
      in their own bodies: `skill_validate_input()` in `scripts/skill-base.sh` and `gate_in()` in
      `scripts/command-gate-in.sh`.
- [x] Re-confirm `skill_validate_input()`'s caller count (report says zero real callers; every hit
      outside its own definition is a doc example or its docstring) and `gate_in()`'s adopter list.
- [x] Verify the three deleted lifecycle command files (`commands/research.md`, `plan.md`,
      `implement.md`) are absent, and drop any report-era reference to them from the offender list.
- [x] Confirm `tests/test-common-lib.sh` still passes and its `collect_session_id_offenders()`
      dual-mode root probe is still present and reusable.
- [x] Write the measured numbers and the grouped offender list into a scratch note for Phases 3
      and 7 to consume (not a deliverable; the durable record is written in Phase 7).

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: The report asserts 63 files / 69 occurrences on executable surfaces (62
excluding `skill-base.sh`), ~47 of them lifecycle `SKILL.md` files, 122 files under the broad
pattern, and zero real `skill_validate_input()` callers. A plan-time spot re-measure returned 64
narrow files and 122 broad files. Confirm all of these by re-running the report's Appendix commands
at implementation time; if any number differs by more than a couple of files, record the new number
and carry it forward rather than the report's.

**Files to modify**:
- None (measurement only).

**Verification**:
- Every count in the phase's output is accompanied by the exact command that produced it.
- The offender list is grouped and each group's count sums to the stated total.
- `bash agent-system/extensions/core/scripts/tests/test-common-lib.sh` exits 0.

---

### Phase 2: Lint core — root resolution, scan scope, narrow-pattern detection [COMPLETED]

**Goal**: Create `lint-task-lookup-adoption.sh` with correct dual-mode root resolution, correct
executable-surface file scope, and a Layer 1 structural classifier that matches the narrow
full-record lookup shape and exempts the four legitimate jq shapes by construction.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh`, executable,
      `set -euo pipefail`, following `lint-state-writer-boundary.sh`'s file layout: header block
      stating purpose, a KNOWN LIMITATION section written plainly (regex-only, line-oriented;
      cannot see variable-indirected or multi-line-assembled lookups), a DETECTION MODEL section
      naming the two layers, a Usage block, and documented exit codes 0/1/2.
- [x] Implement root resolution by reusing the dual-mode probe: resolve via `common_repo_root` and
      fall back to walking up for a directory containing `agent-system/extensions`, exactly as
      `lint-state-writer-boundary.sh`'s `resolve_project_root()` does; additionally probe for
      `core/manifest.json` one level under the candidate root to distinguish source-store from
      deployed layout, as `collect_session_id_offenders()` does.
- [x] Implement the scan-scope function: `*.sh` across each extension's `scripts/` tree, plus
      `*.md` scoped **only** to `commands/`, `skills/`, `agents/` subdirectories (source-store:
      per extension; deployed: directly under the deploy root). `docs/`, `context/`, `rules/` are
      out of scope by construction, never by an exclusion list.
- [x] Exclude `scripts/tests/*.sh` (fixture builders that legitimately mutate rather than look up)
      and `scripts/deprecated/*.sh` (dead code) by directory.
- [x] Implement Layer 1: broad candidate match on `.active_projects[] | select(.project_number`,
      then classify each candidate line. Emit `VIOLATION` only for the narrow full-record shape
      (the filter terminates after the `select(...)` with nothing piped after it). Emit
      `EXEMPT: <reason>` for each legitimate shape, with a distinct reason string per shape:
      in-place mutation (`|= . + {...}`), deletion (`del(...)`), existence/length check
      (`[...] | length`), and single-field read (`... | .field`).
- [x] Implement `--verbose` / `--quiet` / positional `path...` argument handling with the same
      semantics as `lint-state-writer-boundary.sh` (`--verbose` reports exempt candidates tagged
      with their reason; `--quiet` suppresses the header and all-clear summary but never the
      violations or the failing summary).
- [x] Print the summary counters (candidates scanned, exempted, violations) in the same shape as
      the sibling lint.

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh` - new file.

**Verification**:
- `bash -n` parses the script; `shellcheck` (if available) reports no errors.
- Running with `--verbose` against `agent-system/extensions/core/scripts/manage-topics.sh`,
  `reconcile-artifacts.sh`, `update-task-status.sh`, and `command-gate-out.sh` reports each
  candidate as `EXEMPT` with the correct shape-specific reason and zero violations.
- Running with `--verbose` against one known lifecycle `SKILL.md` offender reports a violation.
- Running against a `context/` or `docs/` path containing the pattern reports zero candidates
  (out of scope by construction, not by exclusion list).

---

### Phase 3: Layer 2 reasoned allowlist and self-exemption of the canonical implementations [COMPLETED]

**Goal**: Land the lint green on the current tree by adding a file-level allowlist whose every
entry carries an inline reason, with the two canonical implementations exempted by definition.

**Tasks**:
- [x] Add the Layer 2 file-level allowlist to `lint-task-lookup-adoption.sh`, modelled on
      `lint-state-writer-boundary.sh`'s: an array of paths where **no entry is bare** — each
      carries its reason as an inline comment.
- [x] Exempt by definition, with that reason stated: `scripts/skill-base.sh` (defines
      `skill_validate_input()`; its own body IS the pattern) and `scripts/command-gate-in.sh`
      (defines `gate_in()`; contains the pattern legitimately as that function's body, plus a
      second lookup flagged in research as needing inspection rather than automatic migration).
- [x] Exempt `scripts/deprecated/**` by directory with the reason "dead legacy code, excluded from
      the live system" (if not already excluded structurally in Phase 2, prefer the structural
      exclusion and do not duplicate it here).
- [x] Add the remaining current offenders from Phase 1's list as allowlist entries, grouped by
      category with a shared reason per group: pending-migration lifecycle `SKILL.md` sites
      (deferred pending core-collapse sequencing), and `commands/*.md` sites carrying additional
      distinct lookups for multi-task/recover/sync/expand paths that intentionally do not source
      `command-gate-in.sh` (per-site disposition deferred to the migration pass).
- [x] Add a header note stating the allowlist is expected to **shrink**, that a new entry requires
      a stated reason, and that adding one is a deliberate act rather than the default response to
      a failing run.
- [x] Run the lint against the full source store and confirm exit 0.

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: The allowlist is expected to hold roughly 60 entries (Phase 1's measured
offender count minus any structurally excluded `deprecated/` files). Confirm the final entry count
against Phase 1's measured list at implementation time and state the number in the phase's
completion note; a large divergence means Layer 1 is mis-classifying and Phase 2 needs revisiting
before the allowlist is padded.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh` - add Layer 2 allowlist
  and the shrink-expectation header note.

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh --verbose` exits 0
  against the whole source store.
- Every allowlist entry has a non-empty inline reason (verified by reading the array; no bare
  paths).
- `--verbose` output shows `skill-base.sh` and `command-gate-in.sh` as allowlist-exempt with their
  by-definition reasons.

---

### Phase 4: Fixture-driven regression test suite [COMPLETED]

**Goal**: Pin the lint's behaviour against the specific defects that made the earlier single-source
gate worthless, and prove the acceptance criterion — a newly introduced offender is rejected.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-lint-task-lookup-adoption.sh`,
      modelled on `tests/test-lint-state-writer-boundary.sh`'s harness shape (temp-dir fixtures,
      `pass`/`fail` helpers, summary line, nonzero exit on any failure).
- [x] Test: a planted NEW offender on an executable surface (a fresh `skills/skill-x/SKILL.md`
      carrying the narrow shape, not on the allowlist) causes exit 1 and is named in the output.
      This is the task's stated acceptance criterion and must be an explicit test.
- [x] Test: a planted offender in `context/illustrative.md` is NOT flagged (prose-exclusion
      boundary).
- [x] Test: deployed-mode `.md` detection — a fixture laid out in deploy shape
      (`commands/`/`skills/`/`agents/` directly under the root) is detected, not silently skipped.
- [x] Test: the source-store-vs-deployed mode probe itself resolves correctly for both layouts.
- [x] Test: each of the four legitimate jq shapes (mutation, deletion, existence/length check,
      single-field read) is exempted, one assertion per shape.
- [x] Test: `skill-base.sh` and `command-gate-in.sh` fixtures are never flagged.
- [x] Test: `--quiet` on a failing run still prints violations and the failing summary.
- [x] Run the new suite and confirm all cases pass; confirm each negative-case test genuinely fails
      when its guard is removed (RED-before-GREEN check) before finalising.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-task-lookup-adoption.sh` - new file.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-task-lookup-adoption.sh` exits 0 with
  every case passing.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` picks the new suite up automatically
  (it globs `scripts/tests/test-*.sh`; no registration needed there) and passes.
- Each planted-offender assertion was observed RED before the corresponding lint logic was in place
  or with the guard removed.

---

### Phase 5: verify-deploy gate 17 wiring and manifest registration [COMPLETED]

**Goal**: Make the lint run as part of deploy verification, and make the new script and test
actually deploy.

**Tasks**:
- [x] Append gate 17 to `agent-system/extensions/core/scripts/verify-deploy.sh` after the existing *(deviation: altered — landed as gate 18, since gate 17 was already claimed by lint-scoped-commit-boundary.sh from a concurrent batch; wired line-for-line on gate 12's template as instructed)*
      gate 16 block, copying gate 12's structure line-for-line: the section-rule comment header,
      `say "17. Task-lookup adoption lint (lint-task-lookup-adoption.sh --verbose)"`,
      `CURRENT_GATE="gate17"`, the same skip/missing-file guards gate 12 uses, the
      `cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh" --verbose` invocation, `pass`/`fail` with the
      re-run-for-detail hint, and the `FINDINGS_LIST` `[VIOLATION]` harvesting loop tagged
      `FINDING gate17`.
- [x] Confirm gate 17 is placed before the final summary block and followed by `say ""` in the same *(altered to gate 18, same reasoning)*
      rhythm as the preceding gates.
- [x] Register `lint/lint-task-lookup-adoption.sh` in `agent-system/extensions/core/manifest.json`
      under `provides.scripts`, adjacent to the other `lint/` entries.
- [x] Register `tests/test-lint-task-lookup-adoption.sh` in the same block, adjacent to the other
      `tests/test-lint-*.sh` entries.
- [x] Validate `manifest.json` parses (`jq . manifest.json > /dev/null`).

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - add gate 17.
- `agent-system/extensions/core/manifest.json` - register the lint script and its test under
  `provides.scripts`.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` parses.
- `jq -e '.provides.scripts | index("lint/lint-task-lookup-adoption.sh")' agent-system/extensions/core/manifest.json` returns a match, and likewise for the test entry.
- `bash agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` still passes (it
  does not hardcode a gate count, so gate 17 must not break it).
- A `verify-deploy.sh` run shows a `17.` gate line and reports it passing.

---

### Phase 6: Adoption-lint conventions context document [COMPLETED]

**Goal**: Record the two competing adoption-lint conventions and the decision rule between them, so
the next adoption-lint task does not re-derive the distinction from three separate files.

**Tasks**:
- [x] Create `agent-system/extensions/core/context/patterns/adoption-lint-conventions.md` naming:
      the zero-tolerance convention (precedent: `tests/test-common-lib.sh`'s single-source
      assertion) and the structural-plus-reasoned-allowlist convention (precedent:
      `scripts/lint/lint-state-writer-boundary.sh`).
- [x] State the decision rule explicitly: non-zero migration debt at landing time selects the
      allowlist convention; a class already migrated to ~zero selects zero-tolerance.
- [x] Record the two structural requirements every adoption lint in this repo must satisfy:
      deterministic dual-mode root resolution (source-store vs. deployed), and executable-surface
      file scope by construction (`*.sh` plus `*.md` under `commands/`/`skills/`/`agents/` only).
- [x] Record the allowlist hygiene rule: every entry carries an inline reason, no bare paths, and
      the list is expected to shrink.
- [x] Cite durable anchors only — filenames, function names, section headings. No task-number
      references (this file is outside `specs/**`).
- [x] Add the corresponding entry to `agent-system/extensions/core/index-entries.json` with `path`
      `patterns/adoption-lint-conventions.md`, `domain` `core`, `subdomain` `patterns`, a one-line
      `summary`, an accurate `line_count`, keywords, topics, empty `load_when` arrays, and
      `on_demand: true` — matching the existing entry shape.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/adoption-lint-conventions.md` - new file.
- `agent-system/extensions/core/index-entries.json` - add the index entry.

**Verification**:
- `jq -e '.entries | map(select(.path == "patterns/adoption-lint-conventions.md")) | length == 1' agent-system/extensions/core/index-entries.json` is true.
- The entry's `line_count` matches `wc -l` on the new file.
- `bash agent-system/extensions/core/scripts/check-task-references.sh --quiet` (or the repo's
  task-reference lint) reports no violation for the new file.
- Every file and function named in the document resolves to a real path/symbol.

---

### Phase 7: Bounded migration slice and direction-metrics record [COMPLETED]

**Goal**: Satisfy the acceptance criterion that adopter count rises and duplicate count falls,
without spending effort on files the core-collapse effort may delete — and record both numbers so
the next review measures direction rather than re-deriving it.

**Tasks**:
- [x] Determine which of Phase 1's offender sites are NOT named as deletion/rewrite candidates by
      the core-collapse effort (read that task's description/artifacts under `specs/` to get the
      named file list; do not guess).
- [x] From the qualifying set, select at most three `SKILL.md` sites as a migration pilot. *(completed: skill-spawn/SKILL.md, web/skill-web-research/SKILL.md, web/skill-web-implementation/SKILL.md)*
- [x] For each candidate, verify variable parity before editing: the site must consume only
      variables `skill_validate_input()` actually exports (`TASK_DATA`, `TASK_TYPE`, `TASK_STATUS`,
      `PROJECT_NAME`, `PADDED_NUM`, `TASK_DIR`, `TASK_DIR_ABS`) and must tolerate `exit 1` rather
      than `return 1` failure semantics. A site failing either check is left alone and recorded.
- [x] Migrate each verified candidate: replace the inline jq block with a `skill_validate_input`
      call after the existing `source .../skill-base.sh`, and remove the corresponding allowlist
      entry from `lint-task-lookup-adoption.sh`.
- [x] Re-run the lint after each migration; it must stay green (the removed allowlist entry is only
      safe to remove once the site no longer carries the pattern).
- [x] Write the durable metrics record: adopter count and duplicate count, before and after, with
      the exact commands that produced each, into
      `specs/090_adoption_lint_for_shared_task_lookup_helper/summaries/01_task-lookup-adoption-summary.md`
      (or the summary the implementer writes at completion), so the next review can compare.
- [ ] If **no** candidate qualifies (every offender is in the deletion set, or none passes the *(deviation: skipped — three candidates qualified and were migrated; the exclusions branch does not apply)*
      parity check), close this phase `[COMPLETED WITH EXCLUSIONS]` with a
      `#### Reasoned Exclusions` table enumerating the rejected candidates, the reason per
      candidate, and the evidence (the deletion-set list, or the failing parity check). The metrics
      record is still written in that case — the baseline numbers are the deliverable, the
      migration is the optional slice.

**Timing**: 1.0 hours

**Depends on**: 4, 5

**Verification Tier**: interface

**Scope Hypothesis**: This phase assumes at least one of the ~62 offender sites is outside the
core-collapse deletion set (research names 47 of 62 as candidates, implying roughly 15 are not) and
passes the variable-parity check. Confirm at implementation time by reading the core-collapse
task's named file list and running the parity check per candidate. If the assumption fails, take
the `[COMPLETED WITH EXCLUSIONS]` branch above rather than migrating a deletion-set file.

**Files to modify**:
- Up to three `agent-system/extensions/*/skills/skill-*/SKILL.md` files - replace inline lookup
  with `skill_validate_input` (exact set determined at implementation time).
- `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh` - remove the allowlist
  entries for migrated sites.
- The task summary artifact under `specs/090_.../summaries/` - metrics record.

**Verification**:
- The lint exits 0 after every migration.
- Each migrated skill's bash block still resolves every variable it uses (re-read the block; no
  variable is consumed that `skill_validate_input` does not export).
- The metrics record states before/after adopter and duplicate counts, each with its command.
- If exclusions were taken, the `#### Reasoned Exclusions` table has an Item, Reason, and Evidence
  for every excluded candidate.

---

### Phase 8: Full gate run and deploy verification [NOT STARTED]

**Goal**: Confirm the whole change set is green end-to-end, deployed, and that gate 17 actually
runs against the deployed tree.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh` and confirm the full suite
      passes, including the new test-lint suite.
- [ ] Run the deploy (`deploy-headless.sh`) so the new lint and test land in `.claude/scripts/`.
- [ ] Run `bash agent-system/extensions/core/scripts/verify-deploy.sh` and confirm gate 17 appears
      and passes, and that no previously-passing gate regressed.
- [ ] Diff any remaining `verify-deploy.sh` findings against a pre-change baseline (`git log` /
      `git stash` comparison) so pre-existing unrelated findings are not attributed to this work.
- [ ] Confirm no file under `.claude/**` was hand-authored: every `.claude/` change is attributable
      to the deploy step (`git status` review plus the deploy log).
- [ ] Confirm the working tree contains no edits to `commands/research.md`, `commands/plan.md`,
      `commands/implement.md` (deleted earlier in this batch) and none to `git commit -m` call
      sites (task 48's territory).

**Timing**: 0.75 hours

**Depends on**: 4, 5, 6, 7

**Verification Tier**: full

**Files to modify**:
- None (verification only; the deploy step writes `.claude/**` by design).

**Verification**:
- `run-all.sh` exits 0.
- `verify-deploy.sh` exits 0, or its only failures are shown by the baseline diff to predate this
  work.
- Gate 17's line is present in the `verify-deploy.sh` output.
- `git status --short` shows no unexpected files staged or modified outside the planned scope.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh --verbose` exits
      0 against the current source store.
- [ ] A newly planted inline task-lookup on an executable surface causes the lint to exit 1 and be
      named in the output (the task's stated acceptance criterion, covered by an explicit test).
- [ ] A planted offender under `context/` or `docs/` is not flagged.
- [ ] Deployed-layout `.md` files under `commands/`/`skills/`/`agents/` are scanned, not skipped.
- [ ] All four legitimate jq shapes (mutation, deletion, existence/length, single-field read) are
      exempted with shape-specific reasons.
- [ ] `skill-base.sh` and `command-gate-in.sh` are never flagged.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-lint-task-lookup-adoption.sh` passes.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-common-lib.sh` still passes (unchanged).
- [ ] `bash agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` still passes.
- [ ] `verify-deploy.sh` gate 17 present and passing.
- [ ] Adopter count and duplicate count recorded, before and after, each with its command.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-lint-task-lookup-adoption.sh` (new)
- `agent-system/extensions/core/context/patterns/adoption-lint-conventions.md` (new)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (gate 17 added)
- `agent-system/extensions/core/manifest.json` (two `provides.scripts` entries added)
- `agent-system/extensions/core/index-entries.json` (one entry added)
- Up to three `SKILL.md` files migrated (exact set determined at implementation time; possibly zero
  with a reasoned-exclusions record)
- Task summary under `specs/090_adoption_lint_for_shared_task_lookup_helper/summaries/` carrying the
  before/after adopter and duplicate counts

## Rollback/Contingency

The change set is additive and isolated: three new files plus append-only edits to
`verify-deploy.sh`, `manifest.json`, and `index-entries.json`. Reverting means deleting the three
new files, removing the gate 17 block, and removing the manifest/index entries — no existing
behaviour depends on any of it.

If Phase 7's migration slice turns out to be unsafe (a migrated skill misbehaves), revert only that
phase's `SKILL.md` edits and restore the corresponding allowlist entries; the lint stays green
either way, because the allowlist is what makes it green.

If the lint proves too noisy in practice, the contingency is to make gate 17 warn rather than fail
(gate 16 is the in-repo precedent for a non-blocking warning gate) while the detection model is
tightened — not to delete the gate, since preventing regrowth is the task's primary value.
