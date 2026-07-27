# Implementation Plan: Task #926

- **Task**: 926 - shared_tested_census_tooling_and_method
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**: specs/926_shared_tested_census_tooling_and_method/reports/01_shared-tested-census-tooling.md
- **Artifacts**: plans/01_census-tooling-and-method.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; source-store-deploy-boundary.md; no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Ship a shared, fixture-tested census tool plus a written method standard so that repo-wide counts
in this agent system are derived once, recorded with the exact command that produced them, and
cross-checked by an independent second method before being published or acted on. The same pass
closes the live instance of one of the three named bug classes inside the agent system's own
enforcement tooling: `hooks/validate-no-task-references.sh`'s whitespace-only separator regex.
Every deliverable is committed with a runnable regression suite; untested census tooling is the
defect this task exists to prevent, so a phase that adds tooling without a passing fixture suite
is not done.

Definition of done: two new scripts and two new standards docs exist under
`agent-system/extensions/core/**`, both test suites exit 0, the hook regex matches all named
separator forms, and every new artifact is registered in `manifest.json` / `index-entries.json`.

### Research Integration

From `reports/01_shared-tested-census-tooling.md`:
- The live hook pattern is confirmed as `\b[Tt]asks?[[:space:]]+[0-9]+(-[0-9]+)?\b`; `task-788`,
  `task_788`, and `Task #788` are all structurally invisible to it, and there is no `[Pp]hase`
  branch anywhere in the file.
- `lean-sorry-census.sh` already demonstrates the derive-then-cross-check shape (Python
  comment/string stripper as primary, `lake build`'s `declaration uses 'sorry'` warnings as an
  independent authority) but has zero tests and is `sorry`-specific.
- Core already has one flat shell test, `scripts/test-task-lock-reap.sh`, using
  `pass()`/`fail()`/`info()` with `PASSED`/`FAILED` counters; literature uses
  `scripts/tests/` with `t_pass`/`t_fail`. This plan resolves that tension explicitly in Phase 1.

**Planner-added on-disk correction (verified during planning, extends Finding 6)**: core's
`manifest.json` `provides.scripts` **already contains subdirectory-qualified paths** —
`lint/lint-contract-compliance.sh` and `lint/lint-postflight-boundary.sh`. A `scripts/tests/`
subdirectory is therefore consistent with **core's own** manifest conventions and needs no
borrowed precedent from literature. Separately, `provides.context` lists **directory names**
(`"standards"`, `"formats"`, ...), not individual files, so a new file under
`context/standards/` requires **no** `manifest.json` change — only an `index-entries.json`
entry. Both facts are re-confirmed as explicit tasks below rather than assumed.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- Ship `census-count.sh`: a shared, subcommand-based census helper whose three subcommands map
  one-to-one onto the three named bug classes plus the cross-check discipline.
- Ship a fixture-driven regression suite for that tool encoding all three bug classes.
- Fix `hooks/validate-no-task-references.sh`'s separator regex and ship a fixture suite covering
  every named separator and suffix form, positive and negative.
- Establish and write down a harness-location and helper-naming convention for core shell tests.
- Write down the standard census method: derive once, record the exact command, cross-check by an
  independent second method before publishing or acting.
- Register every new script and context file in `manifest.json` / `index-entries.json`.

**Non-Goals**:
- Re-running, auditing, or correcting any consuming repository's census. Method and tooling only.
- Migrating `scripts/test-task-lock-reap.sh` into the new `tests/` subdirectory. It is a
  single-script suite that would arguably belong there, but moving it is unrelated cleanup and is
  deliberately excluded; Phase 1's convention doc records it as a known, tolerated exception.
- A general-purpose build-graph parser. The membership check tests **declared** membership
  against a caller-supplied declared-set command, never transitive reachability.
- Reimplementing Lean's nesting-aware comment stripper generically. `lean-sorry-census.sh` keeps
  that responsibility; `census-count.sh` offers an escape hatch for pre-stripped input instead.
- Any edit under `.claude/**`, which is a gitignored disposable deploy artifact.

## Decisions Made By This Plan

These are settled here so no implementation phase re-litigates them.

| # | Decision | Reason |
|---|----------|--------|
| D1 | Ship **both** tooling and a documented method | The binding testedness constraint cannot bind a prose-only deliverable; tooling alone records no cross-check discipline |
| D2 | Harness location is `agent-system/extensions/core/scripts/tests/` | Core's `provides.scripts` already carries subdirectory-qualified `lint/` paths, so this is a core-local convention, not a borrowed one; it also matches literature's scope-based split (narrow suites in `tests/`, broad pipeline suites flat) |
| D3 | Helper naming inside core tests is `pass()`/`fail()`/`info()` with `PASSED`/`FAILED` counters | Matches core's only existing precedent (`test-task-lock-reap.sh`); literature's `t_*` prefix stays valid within literature. Location is the shared rule; helper naming is extension-local |
| D4 | Fixtures are constructed inline via heredocs into a `mktemp -d` workdir; no committed fixture tree | Matches core's existing zero-committed-fixture approach, keeps each encoded bug visible next to the assertion that consumes it, and avoids registering non-script files in a `provides` array that has no fixtures slot |
| D5 | Phase references are **in remit only in the task-qualified compound form** (`task N phase P`, `phase P of task N`); a bare `Phase 3` is **out of remit** | A bare phase reference is indistinguishable from a document's own internal structure (`plan-format.md`, skill pipeline stages, this repo's own docs all use it legitimately). Flagging it would generate constant false positives and drive alert fatigue on an advisory hook, destroying its value for the real case. The compound form is unambiguously a citation of a specs/-scoped plan's internals and is the genuinely diagnosable case. Recorded as revisitable if evidence of bare-phase leakage appears |
| D6 | The method doc lives at `context/standards/census-methodology.md`, not `rules/` | `rules/` entries are auto-applied to every command; census correctness is needed selectively. Placing it under `context/standards/` makes it `load_when`-scoped and indexed |

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Broadened hook regex over-matches ordinary prose ("task force", "tasks 3 times") | M | M | Negative fixtures are mandatory in Phase 3, not optional; the hook is advisory (`additionalContext` only, never denies), so a residual false positive costs a reminder, not a blocked write |
| `-` placed mid-class in a bracket expression is read as a range, silently changing the pattern | H | M | Use an explicit alternation group rather than a bracket class containing `-`; Phase 3's fixtures fail loudly if the separator group is wrong |
| A generic comment stripper is correct for no language | M | H | Scope `occurrences` to line comments (`#`, `//`, `--`) and simple non-nested block comments, with an explicit `--comment-style none` / pre-stripped-input escape hatch; document the boundary in the method doc |
| The membership subcommand has no in-repo model to copy | M | M | Keep v1 narrow and explicit: tree glob in, declared-set command out, set difference reported both directions. Document that it checks declared membership only |
| Registration validators operate on the deployed `.claude/` tree rather than the source store, producing confusing results | L | M | Phase 7 reads each validator's own usage header before invoking it and records which tree it inspected; a redeploy is out of scope and a stale-deploy discrepancy is reported, not "fixed" by editing `.claude/**` |
| Test suites become repo-state-dependent and fragile | M | M | All assertions run against synthetic heredoc fixtures in a temp root. The real-manifest-vs-tree invocation appears only as a worked example in the method doc, never as a test assertion |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1, 2 |
| 3 | 5, 6 | 1, 4 |
| 4 | 7 | 3, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Establish and record the core shell-test harness convention [COMPLETED]

**Goal**: Settle where core shell tests live and what shape they take, in a file, so the next
core-script author does not re-derive it by reading two divergent existing tests.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/` (directory only; its first occupants
      arrive in Phases 3 and 5). *(completed)*
- [x] Write `agent-system/extensions/core/context/standards/shell-script-testing.md` recording:
  - The scope-based location rule (D2): a narrow, fixture-driven suite for a single script lives
    in `scripts/tests/`; a broad end-to-end/pipeline suite stays flat in `scripts/`.
  - The helper-naming convention (D3): `pass()`/`fail()`/`info()`, `PASSED`/`FAILED` integer
    counters, `set -uo pipefail`, `SCRIPT_DIR` resolution via
    `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`, `mktemp -d` workdir with a `trap ... EXIT`
    cleanup, exit 0 on all-pass and exit 1 on any-fail.
  - The inline-heredoc fixture convention (D4) and when a committed fixture generator would be
    preferable instead.
  - The known exception: `scripts/test-task-lock-reap.sh` predates this rule, sits flat in
    `scripts/`, and is intentionally not moved.
  - Loud-skip discipline: a prerequisite that is unavailable must exit non-zero or emit a visible
    skip warning; a silently-skipped check is treated as a failure of the harness. *(completed)*
- [x] Add a matching `index-entries.json` entry with `subdomain: "standards"`, keywords covering
      shell/testing/harness, and `load_when` scoped to the implementation agents and `task_types:
      ["meta"]`. *(completed)*
- [x] Confirm whether `provides.context` needs a change (expected: no, because it lists the
      directory `"standards"`, not individual files). Record the confirmed answer in the phase
      notes. *(completed: CONFIRMED — provides.context lists directory names only; "standards" is
      already present; no manifest.json edit needed. Scope Hypothesis holds.)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts that `provides.context` lists directory names and
therefore needs no edit for a new `context/standards/*.md` file. Confirm at implementation time
by reading the `provides.context` array in `agent-system/extensions/core/manifest.json` and
checking whether any entry is a path ending in `.md` beneath `standards/`. If individual files
turn out to be listed, add the entry and note the correction.

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - new convention doc
- `agent-system/extensions/core/index-entries.json` - new entry for the doc
- `agent-system/extensions/core/manifest.json` - only if the hypothesis above is refuted

**Verification**:
- The new doc exists, is non-empty, and states the location rule, helper naming, fixture
  convention, and the recorded exception.
- `index-entries.json` still parses as JSON and the new entry matches the schema of a neighboring
  `standards/` entry field-for-field.
- No task-number citation appears anywhere in the new doc (it is outside `specs/**`).

---

### Phase 2: Fix the `validate-no-task-references.sh` separator regex [COMPLETED]

**Goal**: Make the hook see the separator and suffix forms it is structurally blind to today, and
add the task-qualified Phase form per D5.

**Tasks**:
- [x] In `agent-system/extensions/core/hooks/validate-no-task-references.sh`, replace the quoted
      pattern `'\b[Tt]asks?[[:space:]]+[0-9]+(-[0-9]+)?\b'` in the `grep -qiE` guard with a
      separator-aware pattern. Candidate to validate, not to paste blindly:
      `'\b[Tt]asks?([[:space:]]+#?|[-_#])[0-9]+(-[0-9]+)?\b'`.
  - The separator group must be an explicit alternation, **not** a bracket class containing `-`,
    to avoid the mid-class range-interpretation trap.
  - `[[:space:]]+#?` covers both `task 788` and `Task #788`; `[-_#]` covers `task-788`,
    `task_788`, and `task#788`. *(completed: candidate validated as-is via manual spot checks;
    shipped as `TASK_SEP='([[:space:]]+#?|[-_#])'`, used to build `TASK_PATTERN`.)*
- [x] Add the task-qualified compound Phase branch (D5): match `task N phase P` and
      `phase P of task N`. A bare `Phase N` must **not** match. Anchor the new branch on the same
      separator group so `task-788 phase-3` is caught too. *(completed: `PHASE_PATTERN` built from
      the same `TASK_SEP`, checked before `TASK_PATTERN` so the phase-specific message wins.)*
- [x] Update the advisory `additionalContext` message text so it names the form that matched
      (task citation vs. task-qualified phase citation) rather than only the old `'task N' or
      'tasks N-M'` wording. *(completed: two distinct message branches, one per pattern.)*
- [x] Leave every other behavior byte-identical: the stdin/env-fallback parsing, the
      `specs/*|*/specs/*` exemption, the empty-`FILE` and empty-`CONTENT` early exits, and the
      unconditional `exit 0`. This hook stays advisory and non-blocking. *(completed: unchanged.)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/hooks/validate-no-task-references.sh` - separator group, Phase
  branch, advisory message text

**Verification**:
- `bash -n` on the modified hook passes.
- Manual spot check by piping a synthetic PostToolUse JSON payload on stdin for at least
  `task-788` and a bare `Phase 3`, confirming the first produces an `additionalContext` payload
  and the second produces `{}`. Full coverage is Phase 3's job, not this phase's.
- The hook still exits 0 in every branch.

---

### Phase 3: Fixture-tested regression suite for the hook [COMPLETED]

**Goal**: Prove the regex fix against every named form, and prove the deliberate non-matches stay
non-matching, so the separator gap cannot silently reopen.

**Tasks**:
- [x] Write `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh`
      following the Phase 1 convention: `pass`/`fail`/`info`, `mktemp -d` + `trap`, exit 0/1.
      *(completed)*
- [x] Drive the hook as a real subprocess by piping a synthetic PostToolUse JSON payload
      (`{"tool_input":{"file_path":...,"content":...}}`) on stdin and asserting on whether the
      emitted JSON contains an `additionalContext` key. Copy the hook into the temp root rather
      than adding any testability hook to the production script. *(completed: payloads built via
      `jq -n` for safe escaping; hook copied byte-for-byte into `mktemp -d`.)*
- [x] Positive fixtures (must trigger the advisory): `task 788`, `tasks 788-790`, `task-788`,
      `task_788`, `Task #788`, `task#788`, uppercase `TASK 788`, `(task 788)` in parentheses,
      `task 926 phase 3`, `phase 3 of task 926`. *(completed: all 10 present and passing.)*
- [x] Negative fixtures (must **not** trigger): a bare `Phase 3` heading, `### Phase 12: name`,
      the prose words `task list` / `task force` / `the tasks are` with no adjacent number,
      `taskbar788` (no word boundary), and an ordinary sentence containing neither. *(completed:
      all 7 present and passing.)*
- [x] Exemption fixtures: a `file_path` under `specs/` and one under `/abs/prefix/specs/` must
      both exit with `{}` even when the content is a positive fixture. *(completed.)*
- [x] Degenerate-input fixtures: empty `file_path` and empty `content` both exit `{}` and 0.
      *(completed.)*
- [x] Register `tests/test-validate-no-task-references.sh` in core `manifest.json`
      `provides.scripts`, using a subdirectory-qualified path exactly as `lint/lint-*.sh` entries
      already do. *(completed.)*

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Scope Hypothesis**: This phase enumerates roughly 20 fixture cases across five groups. That
count is a hypothesis, not a target — confirm at implementation time that every form named in
the task scope (`task-`, `task_`, `#`, hyphenated range, task-qualified phase) has at least one
positive case and that D5's bare-phase exclusion has at least one negative case. Add cases
freely; do not drop a named form to hit a count.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` - new suite
- `agent-system/extensions/core/manifest.json` - `provides.scripts` registration

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` exits 0
  with every case reported PASS. *(confirmed: 21 passed, 0 failed, exit 0.)*
- Deliberately reverting the Phase 2 separator group to `[[:space:]]+` makes the suite exit 1 —
  confirm this once, then restore. A suite that passes against the old regex is not testing
  anything. *(confirmed: mutation check performed — reverted `TASK_SEP` to `'[[:space:]]+'`,
  re-ran the suite, got 17 passed / 4 failed / exit 1 (the 4 separator-form positives went
  silent). Restored the fix; `git diff` on the hook confirmed byte-identical to the pre-mutation
  version.)*

---

### Phase 4: Implement the shared `census-count.sh` tool [COMPLETED]

**Goal**: Ship one shared script whose subcommands correspond one-to-one to the three bug classes
and to the cross-check discipline, and which always emits the exact command that produced its
count.

**Tasks**:
- [x] Write `agent-system/extensions/core/scripts/census-count.sh` with `set -uo pipefail`, a
      usage header describing the contract, and three subcommands. *(completed)*
- [x] `occurrences` (bug class 1 and 3): count real occurrences of a caller-supplied ERE within a
      path, excluding matches that fall inside comments or string literals.
  - `--comment-style` accepting at minimum `hash`, `slash` (`//` and `/* */`), `dash` (`--`), and
    `none`; `none` is the pre-stripped-input escape hatch for languages needing
    `lean-sorry-census.sh`-grade nesting-aware handling.
  - Emit both the real count and the naive (unstripped) count so the gap between them is visible
    rather than silently absorbed. *(completed: python3 depth-free stripper masks line comments
    per style, non-nested `/* */` blocks for slash, and double-quoted string interiors; smoke
    test showed naive_count=5 vs real_count=2 on a hand-built fixture.)*
- [x] `membership` (bug class 2): report the set difference between files present in the tree and
      files declared by a caller-supplied declared-set command.
  - Inputs: a tree glob or find expression, and a command emitting one declared path per line.
  - Output: tree count, declared count, `ONLY_IN_TREE` list, `ONLY_IN_DECLARED` list.
  - The usage header must state plainly that this checks **declared** membership only, never
    transitive reachability. *(completed: `comm -23`/`comm -13` on sorted unique lists; usage
    header and record block both state the declared-only scope.)*
- [x] `cross-check` (scope E mechanism): run two independent caller-supplied count commands,
      print both counts and both command strings, and report `MATCH` or `MISMATCH`. Exit non-zero
      on `MISMATCH` so a caller cannot ignore it by accident. *(completed: smoke-tested both
      MATCH (exit 0) and MISMATCH (exit 1).)*
- [x] Every subcommand emits a fixed, greppable record block containing at minimum the count, the
      method name, and the verbatim command string that produced it — this is the machine-side
      half of the derive-once/record-the-command rule Phase 6 writes down. *(completed: all three
      subcommands emit `=== census-count <method> record ===` ... `=== end record ===` blocks.)*
- [x] Reuse the vetted separator-alternation shape from Phase 2 as the documented reference
      example in the usage header for "do not assume whitespace separators". *(completed: usage
      header cites the `TASK_SEP='([[:space:]]+#?|[-_#])'` shape without a task-number
      citation.)*
- [x] Register `census-count.sh` in core `manifest.json` `provides.scripts`. *(completed.)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/census-count.sh` - new tool
- `agent-system/extensions/core/manifest.json` - `provides.scripts` registration

**Verification**:
- `bash -n` passes and `census-count.sh` with no arguments prints usage and exits non-zero.
  *(confirmed: exit 64, usage printed.)*
- Each subcommand runs end-to-end against a throwaway temp directory built by hand and emits the
  record block. Systematic coverage is Phase 5's job. *(confirmed: occurrences, membership,
  cross-check all smoke-tested against hand-built fixtures; each printed its record block.)*

---

### Phase 5: Fixture-tested regression suite for `census-count.sh` [COMPLETED]

**Goal**: Satisfy the binding constraint — the shipped tooling is tested against fixtures that
actually encode all three bug classes, not merely against happy-path inputs.

**Tasks**:
- [x] Write `agent-system/extensions/core/scripts/tests/test-census-count.sh` following the
      Phase 1 convention, building all fixtures inline via heredocs into a `mktemp -d` root and
      copying `census-count.sh` in byte-for-byte. *(completed)*
- [x] **Bug class 1 fixture** (keyword inside a comment or directive rather than a real
      occurrence): a fixture file containing the target keyword N times as live code and M times
      inside line comments, block comments, a directive line, and a string literal. Assert the
      real count is N, assert the naive count is N+M, and assert the two are reported separately.
      Include at least one case per supported `--comment-style`. *(completed: one fixture each
      for hash/slash/dash; naive=5/7/5, real=2/2/2 respectively — each verified to differ.)*
- [x] **Bug class 2 fixture** (file present in the tree but outside the build graph): a temp tree
      with files A, B, C and a synthetic declared-set command naming only A and B plus a
      nonexistent D. Assert `ONLY_IN_TREE` is exactly `C`, `ONLY_IN_DECLARED` is exactly `D`, and
      both counts are reported. All fixtures synthetic — never assert against the real repo.
      *(completed.)*
- [x] **Bug class 3 fixture** (separator and suffix variants missed by a naive regex): its own
      copy of the separator fixture set, not a cross-reference to Phase 3's. Assert the tool's
      documented separator-aware pattern matches `task 788`, `task-788`, `task_788`, `Task #788`,
      and `tasks 788-790`, and that a naive whitespace-only pattern run through the same tool
      misses four of the five — proving the tool distinguishes them rather than passing both.
      *(completed: all 5 forms verified against the correct pattern (count=5). Correction to this
      task's estimate, verified directly rather than assumed: only 2 of the 5 named forms contain
      a literal whitespace separator (`task 788`, `tasks 788-790`), so the naive whitespace-only
      pattern run through the same tool matches those 2 and misses the other 3
      (`task-788`/`task_788`/`Task #788`), not 4 — the test asserts the verified 5-vs-2 result.
      The underlying proof point (naive produces a demonstrably wrong, smaller number; the tool
      produces the right one) holds regardless of the exact miss-count.)*
- [x] **Cross-check fixtures**: one pair of commands that agree (expect `MATCH`, exit 0) and one
      pair that disagree (expect `MISMATCH`, exit non-zero). *(completed.)*
- [x] **Record-block fixture**: assert the emitted record block contains the verbatim command
      string, so the derive-once/record-the-command guarantee is mechanically enforced rather
      than merely documented. *(completed.)*
- [x] Register `tests/test-census-count.sh` in core `manifest.json` `provides.scripts`.
      *(completed.)*

**Timing**: 1.5 hours

**Depends on**: 1, 4

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts three bug-class fixture groups plus two auxiliary groups
suffice. Confirm at implementation time that each of the three binding bug classes has at least
one fixture where the naive approach demonstrably produces the wrong answer and the tool produces
the right one. A fixture that both approaches get right is not evidence and does not count toward
coverage.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-census-count.sh` - new suite
- `agent-system/extensions/core/manifest.json` - `provides.scripts` registration

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-census-count.sh` exits 0 with every case
  reported PASS. *(confirmed: 8 passed, 0 failed, exit 0.)*
- The suite leaves no residue outside its temp root (`trap` cleanup confirmed by checking the
  temp root is gone after exit). *(confirmed: `/tmp/tmp.*` directory count identical before and
  after a run.)*

---

### Phase 6: Document the standard census method [NOT STARTED]

**Goal**: Write down the method so a count produced anywhere in this system carries its
provenance and its independent confirmation with it.

**Tasks**:
- [ ] Write `agent-system/extensions/core/context/standards/census-methodology.md` stating the
      three-part rule as a contract:
  1. **Derive once.** A repo-wide count is produced by a single named method. Re-deriving a count
     ad hoc mid-discussion, by a different method, produces a second number, not a confirmation.
  2. **Record the exact command.** The count is published together with the verbatim command
     string that produced it. A count without its command is an assertion, not a measurement.
  3. **Cross-check before publishing or acting.** A second, independent method must produce the
     same number first. Independence means a different mechanism, not the same grep with a
     different flag — the `lean-sorry-census.sh` pattern (a stripper as primary, the compiler's
     own `declaration uses 'sorry'` warnings as authority) is the reference shape.
- [ ] Enumerate the three bug classes the method exists to catch, each with the concrete failure
      it produces and the `census-count.sh` subcommand that addresses it.
- [ ] Include worked examples using the real CLI from Phase 4, including the dogfooding example:
      `membership` comparing core `manifest.json` `provides.scripts` against `scripts/*.sh` on
      disk. Present it as a documented example invocation only — it must not become a test
      assertion, since it depends on live repo state.
- [ ] State the tool's boundaries explicitly: `occurrences` handles line comments and simple
      non-nested block comments and delegates nesting-aware cases via `--comment-style none`;
      `membership` checks declared membership, never transitive reachability.
- [ ] Cross-reference `context/standards/shell-script-testing.md` (Phase 1) and
      `context/standards/testing.md` (existing, generic; cross-reference only, do not supersede).
- [ ] Add a matching `index-entries.json` entry with `load_when` broad enough that census
      correctness surfaces across task types rather than being pinned to one — no restrictive
      `task_types` filter, `agents` covering the research and implementation agents.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/standards/census-methodology.md` - new method doc
- `agent-system/extensions/core/index-entries.json` - new entry for the doc

**Verification**:
- Every command shown in the doc is copy-pasteable and matches the actual Phase 4 CLI — run each
  worked example once and confirm it produces the documented shape of output.
- `index-entries.json` still parses and the new entry's `line_count` matches the file's real
  length.
- No task-number citation appears in the doc (it is outside `specs/**`).

---

### Phase 7: Registration and wiring verification [NOT STARTED]

**Goal**: Confirm every new artifact is registered, every validator is satisfied, and no binding
constraint was violated anywhere in the diff.

**Tasks**:
- [ ] Read the usage header of each of `scripts/validate-extension-index.sh`,
      `scripts/validate-context-index.sh`, and `scripts/check-extension-docs.sh` to determine the
      correct invocation, then run each. Record which tree each one actually inspects.
  - If a validator inspects the deployed `.claude/` tree rather than the source store, report the
    stale-deploy discrepancy in the summary. A redeploy is out of scope, and editing `.claude/**`
    to satisfy a validator is forbidden.
- [ ] Re-run both new suites (`tests/test-validate-no-task-references.sh`,
      `tests/test-census-count.sh`) from a clean shell and confirm both exit 0.
- [ ] Confirm `manifest.json` `provides.scripts` now contains exactly three new entries:
      `census-count.sh`, `tests/test-validate-no-task-references.sh`,
      `tests/test-census-count.sh` — and that each is subdirectory-qualified where applicable.
- [ ] Confirm `index-entries.json` contains exactly two new entries
      (`standards/shell-script-testing.md`, `standards/census-methodology.md`) and still parses.
- [ ] **Source-store audit**: run `git status --short` and confirm no path under `.claude/`
      appears in the diff. Any `.claude/**` modification is a constraint violation and must be
      reverted, with the equivalent edit made under `agent-system/extensions/core/**` instead.
- [ ] **No-task-references audit**: grep every file this task created or modified outside
      `specs/**` for task-number citations, using the newly fixed separator-aware pattern from
      Phase 2 rather than the old whitespace-only one. Dogfooding the fix here is deliberate.
- [ ] **Line-number-anchor audit**: confirm no new deliverable cites a line number as an anchor;
      every reference must name a symbol, a filename, a section heading, or a quoted regex
      string.

**Timing**: 1 hour

**Depends on**: 3, 5, 6

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts three new `provides.scripts` entries, two new
`index-entries.json` entries, and three named validators. Confirm each count against the actual
diff at implementation time; if Phase 1's `provides.context` hypothesis was refuted, the manifest
entry count differs and that is a correction to record, not a failure.

**Files to modify**:
- None expected. Any file touched in this phase is a correction to an earlier phase and must be
  reported as such.

**Verification**:
- All three validators exit 0, or every non-zero exit is explained and attributed to a
  pre-existing condition unrelated to this task's diff.
- Both new suites exit 0.
- `git status --short` shows zero `.claude/**` paths.
- The no-task-references grep over new non-`specs/**` files returns no hits.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` exits 0.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-census-count.sh` exits 0.
- [ ] Each of the three binding bug classes has at least one fixture where a naive approach
      demonstrably produces the wrong answer and the shipped tool produces the right one.
- [ ] Reverting the Phase 2 separator group to `[[:space:]]+` makes the hook suite fail
      (mutation check performed once, then restored).
- [ ] `bash -n` passes on `census-count.sh`, both test suites, and the modified hook.
- [ ] `census-count.sh cross-check` exits non-zero on a deliberate `MISMATCH`.
- [ ] `manifest.json` and `index-entries.json` both parse as JSON after all edits.
- [ ] `validate-extension-index.sh`, `validate-context-index.sh`, and `check-extension-docs.sh`
      run, with results and inspected-tree recorded.
- [ ] `git status --short` shows no `.claude/**` path.
- [ ] No task-number citation in any new or modified file outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/census-count.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-census-count.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` (new)
- `agent-system/extensions/core/context/standards/census-methodology.md` (new)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (new)
- `agent-system/extensions/core/hooks/validate-no-task-references.sh` (modified)
- `agent-system/extensions/core/manifest.json` (modified: three `provides.scripts` entries)
- `agent-system/extensions/core/index-entries.json` (modified: two new entries)
- `specs/926_shared_tested_census_tooling_and_method/summaries/01_census-tooling-and-method-summary.md`

## Rollback/Contingency

- All five new files are additive; deleting them plus reverting the three registration entries
  restores the prior state exactly.
- The only modification to existing behavior is the hook's `grep -qiE` pattern and its advisory
  message string. Reverting that single quoted pattern to
  `'\b[Tt]asks?[[:space:]]+[0-9]+(-[0-9]+)?\b'` restores the prior (gapped) behavior with no
  other coupling — the hook remains advisory and always exits 0 in both versions, so no rollback
  can block a write.
- Nothing under `.claude/**` is touched, so no redeploy is required to roll back and no deployed
  artifact can be left inconsistent.
- If the Phase 2 regex proves to over-match in practice, the narrower fallback is to keep the
  separator fix and drop the task-qualified Phase branch (D5) independently; the two changes are
  separable and Phase 3's fixtures cover them as distinct groups.
