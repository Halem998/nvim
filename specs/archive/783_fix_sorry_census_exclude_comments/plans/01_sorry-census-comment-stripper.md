# Implementation Plan: Task #783

- **Task**: 783 - Fix sorry-census to exclude comment/docstring lines (count only live proof debt)
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/783_fix_sorry_census_exclude_comments/reports/01_fix-sorry-census-comments.md
- **Artifacts**: plans/01_sorry-census-comment-stripper.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The sorry-census logic is duplicated as an inline `grep -rn "\bsorry\b" ... | grep -v ...`
chain at 5 sites across the `cslib` and `lean` extension agents. The `grep -v` filters cannot
strip interior lines of multi-line `/- -/` and `/-- -/` block comments, trailing inline `--`
comments, or nested block comments (regex cannot count nesting depth), so the census counts
comment/docstring text as live proof debt (the exact cslib task-431 false-positive class). This
plan (1) creates a single shared script `.claude/scripts/lean-sorry-census.sh` implementing a
character-scan, depth-counting Lean comment/string stripper piped into `grep -wn sorry`, with an
opt-in `--cross-check` against `lake build`'s "declaration uses 'sorry'" warnings; (2) validates
it against a fixture corpus reproducing every false-positive pattern before rollout; and (3)
replaces all 5 inline chains with a call to the shared script. Definition of done: the fixture
corpus reports only genuine code sorries with correct line numbers, the compiler cross-check
agrees, all 5 sites invoke the shared script, and no inline `\bsorry\b` grep chain remains under
`.claude/`.

### Research Integration

Findings integrated from `reports/01_fix-sorry-census-comments.md`:
- Exact 5 call sites and their command variants (including site #2's missing `/--` filter).
- Root-cause: nested `/- -/` comments form a non-regular language; no `grep -v` chain can be a
  durable fix. A single-pass depth-counting stripper (python3) is required.
- Recommended layered fix: fast text stripper for frequent counts + free-riding compiler
  cross-check at wrap-up (all 5 sites already run `lake build` immediately before the census).
- Verification plan: fixture `.lean` corpus covering code-sorry, `--`-comment sorry, trailing
  inline-comment sorry, single- and multi-line docstring sorry, nested block-comment sorry, and
  a commented-out TODO stub (the literal task-431 case).
- The stripper reference algorithm (character scan, preserves newlines for line-number fidelity,
  handles `"..."` string literals with backslash escaping) is reproduced in the report.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (meta task; roadmap flag not set).

### Deployment Model (deployed vs extension-source copies)

Verified during planning:
- **Agent `.md` files are symlinks when deployed.** `.claude/agents/cslib-implementation-agent.md`
  and `.claude/agents/cslib-implementation-hard-agent.md` are symlinks into
  `../extensions/cslib/agents/`. Editing the extension source therefore auto-propagates to the
  deployed copy; no dual-edit is required, but the symlink resolution must be re-verified after
  editing.
- **The `lean` agents are NOT deployed** to `.claude/agents/` in this repo (lean extension source
  present, not installed). Only the extension-source copies exist and must be edited.
- **`install-extension.sh` deploys agents (symlinks), commands, and skills, but NOT scripts.**
  There is no script-install step. `.claude/scripts/` is a real, version-controlled directory and
  is the canonical home every agent references. The shared script's authoritative copy must live
  at `.claude/scripts/lean-sorry-census.sh` directly.
- For extension-packaging completeness (fresh installs in other repos), a source-of-truth copy is
  also placed in the owning extension (`lean`, since `cslib` depends on `lean`) and registered in
  its manifest `provides.scripts`.

## Goals & Non-Goals

**Goals**:
- Create one shared, correct Lean sorry-census script that strips comments/strings (including
  nested block comments) before matching, preserving accurate line numbers.
- Provide an opt-in compiler cross-check reusing the `lake build` each site already runs.
- Replace all 5 inline grep chains with a call to the shared script, eliminating the duplication
  and site #2's missing-filter drift.
- Prove correctness with a fixture corpus before rollout.
- Keep deployed (symlinked) and extension-source copies consistent, and keep the extension
  package complete.

**Non-Goals**:
- Consolidating the vacuous-definition / new-axiom checks into a shared script (noted as a
  follow-up in the report; out of scope).
- Adding a sorry census to `cslib-vet-agent.md` where none exists today (report suggestion #4;
  out of scope for this task's stated deliverable).
- Modifying anything in the separate `~/Projects/cslib` repo.
- Extending `install-extension.sh` to deploy scripts (out of scope; canonical script lives in
  `.claude/scripts/` directly).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hand-rolled stripper mishandles Lean string/char literals containing `--` or `/-` | M | M | Fixture corpus includes string-literal edge cases; `--cross-check` acts as authoritative backstop at wrap-up |
| One of the 5 sites missed or updated inconsistently (as site #2 already drifted) | M | M | Phase 5 regression grep asserts zero remaining inline `\bsorry\b` chains under `.claude/` |
| Editing extension source but stale deployed copy remains (if a copy were not a symlink) | M | L | Phase 4 re-verifies symlink resolution; grep the resolved deployed path post-edit |
| `lake build` cross-check slow / not always available | L | M | `--cross-check` is opt-in; default path is stripper-only and build-independent |
| Line-number drift between stripped and original text | M | L | Stripper preserves newlines in place of stripped content; fixture asserts exact original line numbers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Fixture corpus and test harness [COMPLETED]

**Goal**: Encode the expected census behavior as a runnable spec before writing the script (TDD),
covering every false-positive pattern from the report's Verification Plan.

**Tasks**:
- [x] Create a scratch fixture `.lean` file (e.g. under `specs/783_fix_sorry_census_exclude_comments/fixtures/SorryCensus.lean`) containing, on distinguishable lines: *(completed: 9 cases, genuine sorries at lines 10 and 40)*
  - a genuine `sorry` in a theorem body (MUST count);
  - a full-line `-- sorry` comment (MUST NOT count);
  - `theorem foo : True := trivial  -- no longer uses sorry` trailing comment (MUST NOT count);
  - a single-line `/-- ... sorry-free ... sorry ... -/` docstring (MUST NOT count);
  - a multi-line `/-- ... \n sorry-free after removing the sorry \n -/` docstring (MUST NOT count);
  - a nested `/- outer /- inner sorry -/ still outer -/` block comment (MUST NOT count);
  - a commented-out TODO stub `/-\nTODO: theorem foo := by sorry\n-/` (MUST NOT count -- the task-431 case);
  - a string-literal edge case, e.g. `#eval "not a -- comment, not /- either, sorry"` (MUST NOT count).
- [x] Create a test harness script (e.g. `fixtures/run-census-test.sh`) that records, for each fixture line, the expected count/verdict and the expected original line numbers of the genuine sorries. *(completed)*
- [x] Document expected total count and expected `file:line` list as assertions the harness checks. *(completed: EXPECTED_COUNT=2, EXPECTED_LINES=SorryCensus.lean:10,40)*

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `specs/783_fix_sorry_census_exclude_comments/fixtures/SorryCensus.lean` (new) - fixture corpus
- `specs/783_fix_sorry_census_exclude_comments/fixtures/run-census-test.sh` (new) - assertion harness

**Verification**:
- Harness runs and, with no script yet, reports the expected-vs-actual assertions it will enforce
  (dry structure); the genuine-sorry line numbers are explicitly listed.

### Phase 2: Implement the shared census script [COMPLETED]

**Goal**: Create `.claude/scripts/lean-sorry-census.sh` that passes the Phase 1 fixture assertions.

**Tasks**:
- [x] Write `.claude/scripts/lean-sorry-census.sh` (bash wrapper) accepting a directory or file-list argument (e.g. `Cslib/`, `Theories/`). *(completed)*
- [x] Embed the depth-counting comment/string stripper (python3 `-c`, per the report's reference algorithm): handles `--` line comments, nested `/- -/` and `/-- -/` block comments, and `"..."` string literals with backslash escaping; preserves newlines so line numbers match the original file. *(deviation: altered — string interiors are masked with spaces rather than preserved verbatim, so a bare "sorry" appearing only as string text does not false-positive; required by Phase 1's string-literal fixture case, which the report's literal reference algorithm alone would not satisfy since it preserves string content verbatim)*
- [x] Pipe stripped text through `grep -wn sorry` (or equivalent `re.finditer(r'\bsorry\b', ...)`) to produce a `file:line` accurate live-debt list. *(completed: implemented as Python re.finditer equivalent, not a separate grep pipe)*
- [x] Emit both a total count (for `sorry_count`) and a `file:line:statement` inventory list (for `sorry_inventory`, matching the `{file, line, statement}` schema in `.claude/context/contracts/wrap-up.md`). *(completed)*
- [x] Add an opt-in `--cross-check` flag stub that (when set) also runs `lake build 2>&1 | grep -c "declaration uses 'sorry'"` and reports both numbers, surfacing any mismatch (full behavior validated in Phase 3). *(completed)*
- [x] `chmod +x` the script; add a top-of-file usage comment. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/lean-sorry-census.sh` (new) - shared census implementation

**Verification**:
- `bash specs/783_fix_sorry_census_exclude_comments/fixtures/run-census-test.sh` passes: the
  script reports exactly the genuine code-sorry count with correct original line numbers and
  excludes all comment/docstring/nested/string-literal cases.

### Phase 3: Compiler cross-check validation [COMPLETED]

**Goal**: Validate that `--cross-check` agrees with the compiler's authoritative signal on a
minimal buildable fixture.

**Tasks**:
- [x] Create (or reuse) a minimal throwaway Lake project / module whose declarations reproduce the genuine-sorry cases (comment cases carry no build warnings by construction). *(completed: fixtures/lake-project/, toolchain leanprover/lean4:v4.27.0-rc1, mirrors SorryCensus.lean)*
- [x] Run `.claude/scripts/lean-sorry-census.sh --cross-check <dir>` and confirm the stripper count equals the count of `declaration uses 'sorry'` warnings from `lake build`. *(completed: both report 2; MATCH)*
- [x] Confirm a deliberate mismatch (e.g. add a genuine sorry not caught, or a comment sorry) is surfaced by the cross-check reporting divergent numbers. *(completed: added a 3rd genuine sorry to the buildable project only, ran cross-check against the stale 2-sorry fixture; compiler_sorry_count=3, stripper_sorry_count=2, cross_check: MISMATCH reported correctly; project reverted to the 2-sorry MATCH state afterward)*
- [x] If `lake`/Lean toolchain is unavailable in this environment, document the exact cross-check command and expected output in the script's usage notes and mark this phase's build step as environment-gated (stripper path remains fully validated by Phase 2). *(deviation: skipped — lake/lean toolchain (v4.27.0-rc1) was available in this environment, so the build-dependent validation ran directly; no environment-gating fallback was needed)*

**Timing**: 0.75 hours

**Depends on**: 2

**Files to modify**:
- `.claude/scripts/lean-sorry-census.sh` - finalize `--cross-check` behavior if adjustments needed
- (optional) `specs/783_fix_sorry_census_exclude_comments/fixtures/` - minimal Lake project

**Verification**:
- Stripper count and `lake build` warning count match on the buildable fixture; mismatch is
  detected and reported when intentionally introduced (or command documented if toolchain absent).

### Phase 4: Update the 5 call sites [COMPLETED]

**Goal**: Replace every inline `grep -rn "\bsorry\b" ... | grep -v ...` chain with a call to the
shared script, honoring the deployed-vs-source model.

**Tasks**:
- [x] `.claude/extensions/cslib/agents/cslib-implementation-agent.md:267` -> `bash .claude/scripts/lean-sorry-census.sh Cslib/` (record `sorry_count`). *(completed)*
- [x] `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md:197` (phase-end) -> shared script call; this also fixes its missing `/--` filter via unification. *(completed)*
- [x] `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md:234` (final wrap-up) -> shared script call, using `--cross-check` since `lake build` already ran in the same sequence; feed the inventory into `sorry_inventory`. *(completed)*
- [x] `.claude/extensions/lean/agents/lean-implementation-agent.md:140` -> `bash .claude/scripts/lean-sorry-census.sh Theories/`. *(completed)*
- [x] `.claude/extensions/lean/agents/lean-implementation-hard-agent.md:293` -> shared script call (with `--cross-check` at wrap-up). *(completed)*
- [x] Edit only the extension-source files. Then verify the deployed cslib symlinks resolve to the updated source: `readlink .claude/agents/cslib-implementation-agent.md` and `grep -n lean-sorry-census .claude/agents/cslib-implementation-hard-agent.md` (should reflect edits via the symlink). *(completed: verified, symlinks reflect edits)*
- [x] Preserve surrounding numbering/context of each verification-step list so step ordering stays intact. *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` - replace inline chain (line ~267)
- `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` - replace two chains (lines ~197, ~234)
- `.claude/extensions/lean/agents/lean-implementation-agent.md` - replace inline chain (line ~140)
- `.claude/extensions/lean/agents/lean-implementation-hard-agent.md` - replace inline chain (line ~293)

**Verification**:
- Each edited site invokes `.claude/scripts/lean-sorry-census.sh`; no `grep -v "^[[:space:]]*--"`
  remnant remains at those sites; cslib deployed symlinks reflect the changes.

### Phase 5: Doc reference, extension packaging, and regression sweep [COMPLETED]

**Goal**: Align the PR-description example, complete extension packaging for the shared script,
and prove no inline census chain survives.

**Tasks**:
- [x] Update `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md:285`'s example verification line so it references the shared script's output format (not a bare `grep -rn "sorry"`); check for and update any deployed/symlinked copy of this context file. *(completed: no deployed/symlinked copy of this context file exists, only the extension-source copy was edited)*
- [x] Place a source-of-truth copy of the script at `.claude/extensions/lean/scripts/lean-sorry-census.sh` (lean is the base extension; cslib depends on lean) and add `"lean-sorry-census.sh"` to `provides.scripts` in `.claude/extensions/lean/manifest.json`. *(completed)*
- [x] Regression grep: `grep -rn '\\bsorry\\b' .claude/ --include="*.md"` returns zero inline census chains outside the shared script; `grep -rn 'grep -v "^\[\[:space:\]\]\*--"' .claude/` returns nothing. *(completed: both greps return zero matches)*
- [x] Confirm the two script copies (`.claude/scripts/` canonical and `.claude/extensions/lean/scripts/` source) are byte-identical. *(completed: diff confirms identical)*

**Timing**: 0.5 hours

**Depends on**: 4

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` - update example line (~285)
- `.claude/extensions/lean/scripts/lean-sorry-census.sh` (new) - extension source-of-truth copy
- `.claude/extensions/lean/manifest.json` - register script in `provides.scripts`

**Verification**:
- Regression greps return zero inline chains; the two script copies are identical; the
  pr-description example matches the shared script's reported format.

## Testing & Validation

- [x] Fixture harness (`run-census-test.sh`) passes: only genuine code sorries counted, with
      correct original line numbers, across all 8 fixture patterns. *(verified: 2/2 assertions pass)*
- [x] Nested block-comment case (`/- outer /- inner sorry -/ still outer -/`) yields 0 (proves
      depth tracking). *(verified)*
- [x] Multi-line docstring and commented-out TODO stub (task-431 cases) yield 0. *(verified)*
- [x] Trailing inline-comment sorry yields 0. *(verified)*
- [x] String-literal edge case yields 0. *(verified)*
- [x] `--cross-check` count equals `lake build` "declaration uses 'sorry'" count on the buildable
      fixture (or command documented if toolchain absent). *(verified: MATCH on 2/2; deliberate MISMATCH also proven and reverted)*
- [x] All 5 call sites invoke the shared script; cslib deployed symlinks reflect edits. *(verified)*
- [x] `grep -rn '\bsorry\b' .claude/ --include="*.md"` finds no inline census chain outside the
      shared script. *(verified: zero matches)*
- [x] `.claude/scripts/lean-sorry-census.sh` and `.claude/extensions/lean/scripts/lean-sorry-census.sh`
      are byte-identical; lean manifest lists the script under `provides.scripts`. *(verified: diff identical, provides.scripts updated)*

## Artifacts & Outputs

- `.claude/scripts/lean-sorry-census.sh` (canonical, executable)
- `.claude/extensions/lean/scripts/lean-sorry-census.sh` (extension source-of-truth copy)
- `.claude/extensions/lean/manifest.json` (updated `provides.scripts`)
- Updated agent files: `cslib-implementation-agent.md`, `cslib-implementation-hard-agent.md`,
  `lean-implementation-agent.md`, `lean-implementation-hard-agent.md`
- Updated `pr-description-format.md`
- `specs/783_fix_sorry_census_exclude_comments/fixtures/` (fixture corpus + test harness)
- `specs/783_fix_sorry_census_exclude_comments/summaries/01_*-summary.md` (on implementation)

## Rollback/Contingency

- All edits are git-tracked; revert with `git checkout -- <path>` for any file, or
  `git revert` the implementation commit(s).
- The shared script is additive; if it regresses, the previous inline chains are recoverable from
  git history and can be temporarily restored at any single site without affecting the others.
- The `--cross-check` path is opt-in; if the compiler signal proves unreliable in an environment,
  sites can fall back to stripper-only by omitting the flag with no code change.
