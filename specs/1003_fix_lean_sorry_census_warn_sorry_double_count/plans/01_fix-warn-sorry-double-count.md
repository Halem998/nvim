# Implementation Plan: Fix lean-sorry-census.sh warn.sorry double-count

- **Task**: 1003 - Fix lean-sorry-census.sh double-counting warn.sorry suppression annotations
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/1003_fix_lean_sorry_census_warn_sorry_double_count/reports/01_fix-warn-sorry-double-count.md
- **Artifacts**: plans/01_fix-warn-sorry-double-count.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md, shell-script-testing.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`agent-system/extensions/lean/scripts/lean-sorry-census.sh` compiles its final match as
`re.compile(r'\bsorry\b')`. Because `.` is a non-word character, `\b` fires at the `n`/`.`
boundary in `warn.sorry`, so every own-line `set_option warn.sorry false in` suppression
annotation is counted as a phantom sorry on top of the real sorry it suppresses. The fix is a
one-token regex swap to the negative-lookbehind form `(?<![.\w])sorry\b`, plus the companion
docstring text that names the old pattern, plus the first regression fixture this script has ever
had. Definition of done: a new toolchain-free fixture suite that provably fails against the
unfixed script and passes against the fixed one, a real-corpus differential showing the count
drops by exactly the suppression-annotation count with no real sorry lost, and the repo's
existing lint gates still green.

### Research Integration

The research report verified the root cause at line 144 line-for-line, independently reproduced
`(?<![.\w])sorry\b` against five discriminating strings (including the same-line
`set_option warn.sorry false in theorem bar : Q := sorry` case that must NOT regress to 0 and the
general dotted-name case `foo.sorry`), and confirmed counting is per-line
(`if sorry_re.search(line): total += 1`) rather than per-occurrence — so this is a pure pattern
swap and the counting structure must be left alone. It also established that no test coverage
exists anywhere for this script, that the lean extension has no `scripts/tests/` directory yet,
and that core's `test-census-count.sh` is the style precedent (including its explicit
anti-vacuous dual-assertion discipline). It confirmed the downstream stakes: both
`lean-implementation-agent.md` and `cslib-implementation-agent.md` hard-gate "implemented" status
on `sorry_count == 0`, so an inflated census can falsely block a legitimate completion.

Two additions this plan makes beyond the report:

1. **The docstring drift set is larger than one line.** Three lines in the file contain the
   literal `\bsorry\b`: line 5, line 11, and line 96. Line 96 is the one the research named. Line
   11 ("...before matching `\bsorry\b` on the stripped text") also describes this script's own
   behavior and goes equally stale. Line 5 describes the *rejected* `grep -rn "\bsorry\b"` chain
   — an accurate description of the alternative being argued against, which must stay verbatim.
   Phase 2 carries this as an explicit Scope Hypothesis rather than a fact.
2. **A cheaper, stronger-than-planned real-corpus oracle exists.** `lake` and the reference Lean
   corpus are both present on this machine, so `--cross-check` is reachable; but a before/after
   differential run of the census itself over the same real corpus is toolchain-free, seconds
   fast, and directly asserts the claimed identity (delta == suppression-annotation count, and
   the post-fix inventory is a strict subset of the pre-fix inventory). Phase 3 makes the
   differential the required gate and `--cross-check` the confirming-but-slow secondary.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was supplied for this task and no ROADMAP.md consultation was requested.

## Goals & Non-Goals

**Goals**:
- Stop counting `sorry` inside any dotted-qualified name (`warn.sorry`, `foo.sorry`) as a sorry.
- Preserve the same-line annotation form counting as exactly 1 (not 0, not 2).
- Leave `strip_lean_comments()`'s executable body byte-identical.
- Ship the script's first regression fixture, proven non-vacuous by failing against the unfixed
  script before the fix lands.
- Verify by execution against both a synthetic fixture and the real Lean corpus, never by
  inspection.

**Non-Goals**:
- Changing the per-line counting semantic to occurrence counting (would break the same-line form).
- A line-level `warn.sorry` skip filter (silently drops real same-line sorries).
- Touching `lean-implementation-agent.md`, `cslib-implementation-agent.md`, or
  `pr-description-format.md` — they consume `sorry_count` as an opaque integer and simply start
  receiving a correct one.
- Editing anything under `.claude/**`. The lean extension is not loaded in this deploy, so there
  is no deployed copy to reconcile and no redeploy step in this task.
- Any change to the `--cross-check` mechanism itself.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A vacuous fixture that both the buggy and fixed regex pass, giving false confidence | H | M | Phase 1 runs the fixture against the UNFIXED script and REQUIRES a failure on the own-line case before Phase 2 may start; the suite additionally asserts the naive pattern's wrong number on the same fixture text |
| Implementer "fixes" it by skipping lines containing `warn.sorry`, silently dropping real same-line sorries | H | M | Same-line fixture asserts exactly 1; a skip-filter yields 0 and fails the suite. Named as an explicit Non-Goal above |
| Implementer switches to `findall`/occurrence counting while in the file | H | L | Phase 2 tasks require the `if sorry_re.search(line): total += 1` block to remain byte-identical, checked by diff |
| Docstring left naming the old pattern (drift) | M | M | Phase 2 greps all three `\bsorry\b` occurrences and dispositions each one explicitly; Scope Hypothesis requires confirming the set |
| `strip_lean_comments()` body accidentally reflowed by an editing tool | M | L | Phase 2 verifies the diff touches only the intended lines via `git diff --stat` plus a hunk read-through |
| `lake build` on the real corpus is slow or fails for unrelated reasons, stalling verification | M | M | The required gate is the toolchain-free before/after differential; `--cross-check` is secondary and its non-completion is recorded as a reasoned exclusion, never as a silent skip |
| New test file lands without the executable bit or with a task-number citation | L | M | Phase 4 runs `check-task-references.sh` and checks the mode against the core tests' convention |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Write the regression fixture and prove it fails against the unfixed script [COMPLETED]

**Goal**: Create `agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` and
demonstrate — by running it before any source change — that it FAILS on the own-line case. This
is the falsifiability check that makes the rest of the task meaningful.

**Tasks**:
- [x] Create the new directory `agent-system/extensions/lean/scripts/tests/`. *(completed)*
- [x] Read `agent-system/extensions/core/scripts/tests/test-census-count.sh` for the house style:
      `set -uo pipefail`, `pass()/fail()/info()` helpers with `PASSED`/`FAILED` integer counters,
      a `mktemp -d` workdir with `trap ... EXIT` cleanup, synthetic heredoc fixtures only, exit 0
      on all-pass / exit 1 on any failure, and a header comment stating the anti-vacuous guard.
      *(completed)*
- [x] Write `test-lean-sorry-census.sh` resolving the tool under test relative to
      `${BASH_SOURCE[0]}` (`$SCRIPT_DIR/../lean-sorry-census.sh`), erroring out if it is absent or
      if `python3` is not on PATH. *(completed)*
- [x] Parse the tool's `sorry_count` from stdout with the same idiom the script itself uses
      internally: `grep -oE '^sorry_count: [0-9]+' | grep -oE '[0-9]+'`. *(completed)*
- [x] Fixture A (own-line annotation): `set_option warn.sorry false in` on its own line followed
      by `theorem foo : P := sorry`. Assert reported count is exactly 1. *(completed)*
- [x] Fixture B (same-line annotation): `set_option warn.sorry false in theorem bar : Q := sorry`
      on one line. Assert exactly 1 — not 0 (line-skip anti-pattern) and not 2. *(completed)*
- [x] Fixture C (stripper guard): one `--` line-commented sorry, one sorry inside a nested
      `/- ... /- ... -/ ... -/` block comment, and one sorry inside a `"..."` string literal.
      Assert each contributes 0. *(completed)*
- [x] Fixture D (dotted-name generality): a line containing `foo.sorry` with no bare sorry.
      Assert 0. *(completed)*
- [x] Fixture E (aggregate): a file with N own-line annotations and M real sorries. Assert the
      reported total is M, not M + N. *(completed: N=3, M=2)*
- [x] Anti-vacuous dual assertion: for Fixtures A and D, additionally compute what the naive
      `\bsorry\b` pattern yields over the same fixture text (a small inline `python3 -c` is
      sufficient) and assert it differs from the tool's number, so a fixture both
      implementations would agree on can never masquerade as coverage. *(completed)*
- [x] Add an inventory assertion on Fixture A: the `sorry_inventory:` block must contain the
      `theorem foo` line and must NOT contain the `set_option` line — this catches a
      count-correct-but-inventory-wrong fix. *(completed)*
- [x] `chmod +x` the new file, matching the mode of the core test files. *(completed)*
- [x] **Run it now, against the unfixed script.** Record the output. Fixtures A, D, and E MUST
      fail and B and C MUST pass. Any other outcome means the fixture is wrong, not the script —
      fix the fixture and re-run before proceeding. *(completed: observed exactly A/D/E FAIL,
      B/C PASS — PASSED=2, FAILED=6, exit 1. Fixture A: count 2 (expected 1), anti-vacuous
      naive==tool==2, inventory shows both lines. Fixture D: count 1 (expected 0), anti-vacuous
      naive==tool==1. Fixture E: count 5 (expected 2). Confirms the Scope Hypothesis exactly.)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts a specific expected failure pattern against the unfixed
script — A, D, E fail; B, C pass. That is a hypothesis derived from the research's per-line
counting analysis, not a fact. Confirm it by actually executing
`bash agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` before touching the
source, and paste the real pass/fail lines into the phase's completion note. If B or C
unexpectedly fails, stop and re-derive — a pre-existing stripper defect would be a different bug
than the one this task is scoped to.

**Files to modify**:
- `agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` - new file, the whole
  fixture suite
- `agent-system/extensions/lean/scripts/tests/` - new directory

**Verification**:
- The suite executes without shell errors and exits 1.
- The exact set of failing case names is recorded, demonstrating the fixture discriminates the
  buggy implementation from the intended one.

---

### Phase 2: Apply the regex fix and reconcile the stale pattern references [COMPLETED]

**Goal**: Swap line 144's pattern to `(?<![.\w])sorry\b`, update every comment line that names the
old pattern as this script's own behavior, and leave everything else byte-identical.

**Tasks**:
- [x] Edit line 144 from `sorry_re = re.compile(r'\bsorry\b')` to
      `sorry_re = re.compile(r'(?<![.\w])sorry\b')`. *(completed)*
- [x] Run `grep -n 'bsorry' agent-system/extensions/lean/scripts/lean-sorry-census.sh` and
      disposition each remaining hit explicitly:
      - line 5 (`a grep -rn "\bsorry\b" | grep -v ... chain cannot do this correctly`) — describes
        the REJECTED grep-chain alternative, not this script's matcher. Leave verbatim.
      - line 11 (`before matching \bsorry\b on the stripped text`) — describes this script's own
        matcher. Update to name the corrected pattern.
      - line 96, inside `strip_lean_comments()`'s docstring
        (`later matched by the \\bsorry\\b scan`) — update to name the corrected pattern,
        preserving the existing double-backslash escaping convention used inside that docstring.
      *(completed: confirmed exactly 3 occurrences before editing, matching the hypothesis;
      line 5 left verbatim, lines 11 and 96 updated to name `(?<![.\w])sorry\b`)*
- [x] Confirm `strip_lean_comments()`'s executable body (everything after its closing docstring
      through `return "".join(out)`) is byte-unchanged. *(completed: verified via git diff — no
      hunk touches this region)*
- [x] Confirm the counting block `if sorry_re.search(line): total += 1` and its surrounding loop
      are byte-unchanged — do NOT switch to `findall` or occurrence counting. *(completed:
      verified via git diff — no hunk touches this region)*
- [x] Review `git diff` hunk by hunk: the diff must contain exactly the regex line plus the
      dispositioned comment lines, and nothing else. *(completed: 3 hunks total, exactly lines
      11, 96, 144)*
- [x] Re-run the Phase 1 suite. All cases must now pass and the suite must exit 0. *(completed:
      8/8 PASS, exit 0)*

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the change set is exactly one regex line plus exactly two
comment lines (11 and 96), with line 5 deliberately untouched — i.e. `git diff --stat` shows one
file with 3 insertions and 3 deletions. Both the "three `\bsorry\b` occurrences" count and the
line-5-is-about-the-alternative classification are hypotheses. Confirm by running the grep above
against the live file and reading each hit in context before editing; if the file contains a
fourth occurrence or line 5's framing has changed, re-disposition rather than assuming this list.

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-sorry-census.sh` - line 144 regex; lines 11 and 96
  comment text

**Verification**:
- `bash agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` exits 0 with every
  case passing, including the same-line case at exactly 1.
- `git diff --stat` confirms a single file and a minimal insertion/deletion count.
- The enumerated direct dependents (`lean-implementation-agent.md`,
  `cslib-implementation-agent.md`, `pr-description-format.md`) are re-checked to confirm none
  encodes the regex or needs an edit — they consume `sorry_count` as an opaque integer.

---

### Phase 3: Real-corpus differential verification [COMPLETED WITH EXCLUSIONS]

**Goal**: Prove on real Lean sources — not synthetic fixtures — that the count drops by exactly
the suppression-annotation count and that no real sorry was lost.

**Tasks**:
- [x] Pick the reference corpus: `~/Projects/cslib` (present on this machine), scoping to both the
      whole `Cslib/` tree and the `Cslib/Logics/Bimodal` subtree the task description cites.
      *(completed)*
- [x] Capture the PRE-fix census on each scope by running the script from `git stash`/`git show`
      of the pre-fix revision (or a copy of the original file placed in a temp dir) — do NOT
      revert the working tree; copy the pre-fix file content into a scratch path and run that
      copy. Save full stdout including the `sorry_inventory:` block. *(completed: extracted
      `git show HEAD~2:...lean-sorry-census.sh` to a scratch copy, confirmed it retains the
      buggy `\bsorry\b` pattern, ran against both scopes: repo-wide 43, Bimodal 41)*
- [x] Capture the POST-fix census on the same scopes with the fixed script. Save full stdout.
      *(completed: repo-wide 25, Bimodal 23)*
- [x] Assert: `pre_count - post_count == <number of own-line \`set_option warn.sorry false in\`
      lines in scope>`, computed independently with a grep count. *(completed: repo-wide delta
      43-25=18, Bimodal delta 41-23=18; independent grep count of own-line
      `set_option warn.sorry false in` lines = 18 in both scopes — identity holds exactly.
      Absolute pre-fix repo-wide figure (43) diverges from the task description's hypothesized
      45 — recorded as corpus drift, not a fix failure, per the Scope Hypothesis below)*
- [x] Assert: the post-fix inventory is a strict subset of the pre-fix inventory (no line appears
      post-fix that was absent pre-fix), and every dropped inventory line is a `set_option
      warn.sorry` line. This is the "no real sorry lost" gate. *(completed: `comm -13` (added)
      empty on both scopes; `comm -23` (dropped) yields exactly 18 lines on both scopes, all of
      the form `set_option warn.sorry false in` — no real sorry lost)*
- [x] Secondary oracle: run `bash <path>/lean-sorry-census.sh Cslib/Logics/Bimodal --cross-check`
      from the corpus root. Expect `cross_check: MATCH` where it previously reported `MISMATCH`.
      *(completed: ran with a 540s timeout; `lake build` exited 0 in seconds since `.lake/build`
      was already fully cached (14G), so it elaborated nothing and emitted zero
      "declaration uses 'sorry'" warnings. Result: `compiler_sorry_count: 0`,
      `stripper_sorry_count: 23`, `cross_check: MISMATCH (stripper=23, compiler=0)`. This
      MISMATCH is a lake-cache-staleness artifact unrelated to the regex fix, not evidence the
      fix is wrong — see Reasoned Exclusions below)*
- [x] If `lake build` does not complete in a reasonable window or fails for reasons unrelated to
      this change, record that explicitly as a reasoned exclusion with the observed evidence —
      the differential above remains the binding gate. Never report the cross-check as "passed"
      without having seen `cross_check: MATCH` in real output. *(completed: recorded below as a
      Reasoned Exclusion; `cross_check: MATCH` was never observed and is not reported as passed)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Secondary `--cross-check` oracle expected to show `cross_check: MATCH` | `lake build` found the entire `.lake/build` cache (14G) already up to date and elaborated zero files, so it emitted zero `declaration uses 'sorry'` compiler warnings regardless of the regex fix's correctness — the cache-staleness behavior is orthogonal to this change, and forcing a full clean rebuild to get a genuine compiler count is out of scope for this task's timing budget. The binding, toolchain-free differential gate (delta == 18 on both scopes, independently grep-confirmed, strict-subset inventory check with only `set_option warn.sorry` lines dropped) fully passed and is not weakened by this exclusion. | Captured cross-check run: `compiler_sorry_count: 0`, `stripper_sorry_count: 23`, `cross_check: MISMATCH (stripper=23, compiler=0)`, with zero sorry-warning lines anywhere in the `lake build` output (`grep -n "warning" crosscheck.txt` returns nothing), and `du -sh ~/Projects/cslib/.lake` showing a pre-existing 14G build cache from before this task began. |

**Timing**: 45 minutes

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: The task description asserts specific figures (45 -> 27 repo-wide,
41 -> 23 for `Cslib/Logics/Bimodal`, delta 18 in both). These are prior measurements from
2026-08-09 and are hypotheses, not facts — the corpus may have moved since. Confirm the
*identity* (delta equals the independently-grepped own-line annotation count, and no real sorry
is dropped) rather than the specific integers; report the actual observed numbers and note any
divergence from 45/27/41/23/18 as corpus drift rather than treating a mismatch as a fix failure.

**Files to modify**:
- None. This phase produces evidence only; no repository file changes.

**Verification**:
- The recorded delta equals the independently counted annotation occurrences on each scope.
- The post-fix inventory diff contains only `set_option warn.sorry` lines as removals.
- `cross_check: MATCH` observed, or its non-completion recorded with evidence.

---

### Phase 4: Repository gates and hygiene [NOT STARTED]

**Goal**: Confirm the new test file and the edit satisfy the repo's standing lint gates and
source-store rules.

**Tasks**:
- [ ] Run `bash .claude/scripts/check-task-references.sh` — the new test file lives outside
      `specs/**` and must carry no task-number citation. Fix any finding at the source rather
      than adding an exemption marker unless the finding genuinely falls into the documented
      exemption taxonomy.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and confirm the lean extension's docs
      still pass; if the extension README enumerates its scripts, add the new tests directory
      there in the same style the core extension uses.
- [ ] Confirm the new file's executable bit and shebang match the core test convention.
- [ ] Confirm nothing under `.claude/**` was written by this task (`git status --short` shows
      only `agent-system/extensions/lean/**` and `specs/1003_*/**`). The lean extension is not
      loaded in this deploy, so no redeploy is required or appropriate.
- [ ] Consider whether `agent-system/extensions/lean/manifest.json`'s `provides.scripts` needs the
      test path added. Core's test files are not individually listed in `provides`, so the
      default answer is no — record the decision either way rather than leaving it unexamined.
- [ ] Re-run the fixture suite one final time from a clean shell to confirm it is
      location-independent and leaves no temp directory behind.

**Timing**: 30 minutes

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/lean/README.md` - only if it enumerates scripts and the tests
  directory belongs in that list
- `agent-system/extensions/lean/manifest.json` - only if the recorded decision is to list the
  test

**Verification**:
- `check-task-references.sh` exits 0.
- `check-extension-docs.sh` reports no new failures attributable to this change.
- `git status --short` confirms the change set is confined to the source store and the task's
  own `specs/` directory.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` exits 1 against
      the unfixed script (Phase 1) and exits 0 against the fixed script (Phase 2).
- [ ] Own-line annotation fixture reports exactly 1.
- [ ] Same-line annotation fixture reports exactly 1 (the non-regression guard).
- [ ] Commented-out, nested-block-commented, and string-literal sorries each report 0.
- [ ] `foo.sorry` with no bare sorry reports 0.
- [ ] Aggregate fixture with N annotations and M real sorries reports M.
- [ ] Real-corpus delta equals the independently grepped annotation count, with no real sorry
      dropped from the inventory.
- [ ] `cross_check: MATCH` on a scope that previously reported `MISMATCH`, or a recorded reasoned
      exclusion with evidence.
- [ ] `check-task-references.sh` and `check-extension-docs.sh` green.

## Artifacts & Outputs

- `agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` (new)
- `agent-system/extensions/lean/scripts/lean-sorry-census.sh` (modified: line 144 regex, lines 11
  and 96 comment text)
- `specs/1003_fix_lean_sorry_census_warn_sorry_double_count/summaries/01_fix-warn-sorry-double-count-summary.md`
- Recorded pre/post census output for the reference corpus, embedded in the summary as the
  execution evidence for the differential gate

## Rollback/Contingency

The change is two files, one of them new. To revert: `git revert` the phase commits, or restore
`lean-sorry-census.sh` from HEAD and delete `agent-system/extensions/lean/scripts/tests/`. No
deployed copy exists (the lean extension is not loaded in this deploy), no generated artifact
depends on the script's output, and no state migration is involved. If Phase 3's differential
contradicts the expected identity — e.g. a real sorry disappears from the inventory — stop, do
not proceed to Phase 4, revert Phase 2's edit, and re-open the analysis: that outcome would mean
the lookbehind is excluding something beyond dotted-qualified names and the fix is wrong as
specified.
