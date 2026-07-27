# Research Report: Task #926

**Task**: 926 - shared_tested_census_tooling_and_method
**Started**: 2026-07-27T22:41:32Z
**Completed**: 2026-07-27T23:05:00Z
**Effort**: Medium (design decision + tooling + fixtures + one regex fix + docs)
**Dependencies**: None
**Sources/Inputs**: - Codebase (agent-system/extensions/{core,literature,lean}/**), manifest.json/index-entries.json schemas
**Artifacts**: - specs/926_shared_tested_census_tooling_and_method/reports/01_shared-tested-census-tooling.md
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- All edits target `agent-system/extensions/core/**` (source store); `.claude/**` is a disposable
  deploy artifact and must never be edited directly (see `source-store-deploy-boundary.md`).
- `hooks/validate-no-task-references.sh`'s live regex is confirmed as
  `\b[Tt]asks?[[:space:]]+[0-9]+(-[0-9]+)?\b` — it requires literal whitespace between `task`/
  `tasks` and the digits, so `task-788`, `task_788`, and `Task #788` are all structurally
  invisible to it, exactly as the task description states. It has no `Phase` pattern at all.
- The literature extension's test harness shape is a `scripts/tests/` subdirectory holding a
  bash test-runner (`test-literature-convert.sh`: `t_pass`/`t_fail` counters, `mktemp -d`
  scratch workdir, exit-1-on-any-failure) plus a `generate-test-fixtures.py` fixture generator,
  alongside one pipeline-level test script (`test-lit-pipeline.sh`) left flat in `scripts/`
  rather than in `tests/`.
- **Correction to the task description's framing**: core already has one script test —
  `agent-system/extensions/core/scripts/test-task-lock-reap.sh` — but it lives flat in
  `scripts/`, not in a `tests/` subdirectory, and uses a `PASSED`/`FAILED` counter convention
  (`pass()`/`fail()`/`info()` with ANSI colors) distinct from literature's `t_pass`/`t_fail`
  style. This is not a second "test directory" (the task description's literal claim — "the only
  script test directory... belongs to the literature extension" — is verified true, since
  `test-task-lock-reap.sh` is a bare file, not a directory), but it is a second **convention**
  competing for the "shape core testing follows" decision in Scope B, and the report below
  surfaces this tension explicitly rather than silently picking literature's shape.
- `lean-sorry-census.sh` (`agent-system/extensions/lean/scripts/`) has a sound two-tier design —
  a depth-counting Python comment/string stripper plus an opt-in `--cross-check` against `lake
  build`'s authoritative `declaration uses 'sorry'` compiler warnings — and zero tests anywhere
  in the tree, confirmed by exhaustive search.
- No `census` string appears anywhere in `agent-system/extensions/core/**`; no repo-wide count
  standard-method document exists. Both `manifest.json` (`provides.scripts`, `provides.hooks`)
  and `index-entries.json` (`entries[]`) have clear, low-friction registration slots for new
  artifacts, illustrated below.

## Context & Scope

This task asks only for the **method and tooling**, not a re-run of any consuming repository's
census (explicit non-goal). The scope is: (A) decide deliverable shape (tooling vs. documented
method vs. both) with a binding testedness constraint against three named bug classes; (B)
establish a core-scripts test harness location; (C) fix the hook regex and decide Phase-reference
scope; (D) register new scripts/context in `manifest.json`/`index-entries.json`; (E) document the
standard method (derive-once, record-command, cross-check-before-publish).

All facts stated as already-verified in the task description (the three bug classes, the 23→35→
40/41-vs-28 figure, the nine root-level scratch files, the 376-vs-399 undercount) are taken as
given per the task's explicit instruction not to re-derive them — this report verifies only the
on-disk claims about *this* repository's tooling and adds the design analysis needed to act.

## Findings

### Codebase Patterns

**1. `hooks/validate-no-task-references.sh` — exact regex and its gap**

Full path: `agent-system/extensions/core/hooks/validate-no-task-references.sh`. It is a
PostToolUse hook (non-blocking, always `exit 0`) wired into `merge-sources/settings-hooks.json`
line 46 as `bash .claude/hooks/validate-no-task-references.sh`. It fires on `Write`/`Edit` whose
`file_path` is outside `specs/**` (case `specs/*|*/specs/*` exempted), and scans `.content`/
`.new_string` for the pattern:

```bash
if echo "$CONTENT" | grep -qiE '\b[Tt]asks?[[:space:]]+[0-9]+(-[0-9]+)?\b'; then
```

Breaking this down: `\b[Tt]asks?` matches `task`/`Task`/`tasks`/`Tasks`; `[[:space:]]+` requires
one or more literal whitespace characters; `[0-9]+` then requires digits immediately after that
whitespace; `(-[0-9]+)?` optionally matches a following `-NNN` (the "tasks N-M" range form) but
only after the number, not as a separator between the word and the number. Consequences,
confirmed by direct pattern reasoning against the four cited forms:
- `task 788` — matches (whitespace separator, digits immediately follow).
- `task-788` — does not match: after `task` there is no whitespace, `-` is not in
  `[[:space:]]`, so the `[[:space:]]+[0-9]+` requirement fails.
- `task_788` — does not match, same reason (`_` is not whitespace).
- `Task #788` — does not match: whitespace after `Task` is present, but the next character is
  `#`, not a digit, so `[0-9]+` fails immediately after the whitespace requirement is satisfied.
- There is no `[Pp]hase` alternative anywhere in the pattern or file — `Phase 12`, `Phase-12`,
  `phase_12` are all completely outside this hook's remit today.

This exact whitespace-only gap is the class-3 bug pattern named in the task description
(separator/suffix variants missed by a naive regex), reproduced live in the agent system's own
enforcement tooling.

Cross-reference confirming the gap is reachable through normal use: `rules/git-workflow.md`'s
"Task Branches (Optional)" section names `task-{N}-{slug}` as the sanctioned branch-naming
convention, and `rules/no-task-references-in-deliverables.md` explicitly carves out "PR/branch
metadata (branch names like `task-{N}-{slug}`...)" as a permitted exception elsewhere in the
system — so hyphenated `task-N` forms are first-class, documented, everyday strings in this
repository, yet invisible to the one hook meant to catch task-number leakage into deliverables.

**2. Existing core-scripts test precedent (correction to the task description)**

`agent-system/extensions/core/scripts/test-task-lock-reap.sh` (232 lines) already exists as a
shell test suite for `task-lock.sh`'s `reap` subcommand. It is registered in
`agent-system/extensions/core/manifest.json`'s `provides.hooks` list — actually under
`provides.scripts` (confirmed: `python3 -c "..."` search of `provides.hooks` for
`test-task-lock-reap.sh` returned it, i.e. it is listed alongside the hook scripts array,
worth double-checking placement when doing the actual registration in Scope D since the search
matched `provides.hooks`, not `provides.scripts`, for this particular file — see Decisions below
for the exact list to check before assuming which array a new census test belongs in).

Its shape:
- Lives directly in `scripts/`, **not** under a `tests/` subdirectory.
- Uses `PASSED`/`FAILED` integer counters incremented by `pass()`/`fail()` helper functions with
  ANSI-colored `[PASS]`/`[FAIL]`/`[INFO]` output, distinct from literature's `t_pass`/`t_fail`
  naming.
- Builds a fully isolated `mktemp -d` temp root that mimics the real `specs/` tree and copies the
  *actual* production script (`task-lock.sh`) byte-for-byte into it, rather than mocking or
  stubbing — "task-lock.sh itself is copied byte-for-byte and never learns it is under test," per
  its own header comment. This zero-instrumentation approach is a strong pattern for shell script
  testing generally and is directly reusable for census-tool testing (no fixture files need to be
  committed for the *directory-structure* half of a census bug; only file *contents* need
  fixturing).
- No fixture-generator counterpart (unlike literature's `generate-test-fixtures.py`) — its
  fixtures are constructed inline via bash heredocs and helper functions
  (`write_holder_fixture`, `write_corrupt_holder_fixture`).
- Exit code: `0` all-pass, `1` any-fail — same contract as literature's test runner.

This means the "verified absence of infrastructure" framing in the task description is accurate
at the letter (no `tests/` *directory* for core scripts existed before this task), but not
accurate at the spirit level: core scripts already have one shell-test precedent, and it diverges
from literature's `scripts/tests/` subdirectory shape. Scope B's harness-location decision must
therefore choose between three real options, not two: (i) adopt literature's `scripts/tests/`
subdirectory shape uniformly going forward (task description's suggested default), (ii) follow
core's own existing flat `scripts/test-*.sh` precedent (recency/local-consistency argument), or
(iii) migrate `test-task-lock-reap.sh` into a new `scripts/tests/` subdirectory alongside the new
census test, unifying on one convention retroactively. See Decisions.

**3. Literature extension test harness — exact shape**

`agent-system/extensions/literature/scripts/tests/` contains:
- `generate-test-fixtures.py` (104 lines) — a Python fixture generator invoked by the bash test
  runner (e.g. `python3 "$FIXTURE_GEN" two-column "$FIXTURE1"`), producing synthetic PDFs on
  demand rather than committing binary fixture files to the repo.
- `test-literature-convert.sh` (265 lines) — the bash test runner. Pattern: `set -uo pipefail`;
  resolves `SCRIPT_DIR`/`TESTS_DIR` via `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`; checks
  prerequisites (`python3` availability, target script executability) and exits 1 loudly if
  missing rather than silently skipping; `PASS`/`FAIL` integer counters with `t_pass`/`t_fail`/
  `t_log` helpers; `WORKDIR=$(mktemp -d)` with a `trap 'rm -rf "$WORKDIR"' EXIT`; explicit
  numbered `# Test N: ...` block comments describing intent before each case; an optional
  real-world-input stronger check gated on an env var (`LITERATURE_TEST_PDF`) that "SKIPS WITH A
  VISIBLE WARNING" when unset rather than silently doing nothing. Its own header states the
  rationale directly: it exists to "prove... the exact bug class... was: a preferred engine
  silently absent, nobody noticed for months" — i.e. this harness was itself built in direct
  response to a silent-tooling-failure bug, the same category task 926 is guarding against for
  census tools.

Additionally, `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` (469 lines) is a
second, larger test script that lives flat in `scripts/`, *not* inside `tests/` — so even
literature itself does not apply the `tests/` subdirectory shape universally; it uses `tests/`
for narrowly-scoped unit-style regression suites (one script, one fixture generator) and leaves a
broader end-to-end pipeline test flat alongside the production scripts. This is a second
precedent worth weighing against core's flat `test-task-lock-reap.sh": literature itself already
mixes both shapes depending on test scope/breadth, which weakens "follow literature's shape
uniformly" as a clean default and strengthens a scope-based split (see Decisions).

Registration: literature's `manifest.json` → `provides.scripts` lists all three paths verbatim,
including the `tests/` prefix (`"tests/generate-test-fixtures.py"`,
`"tests/test-literature-convert.sh"`), confirming `provides.scripts` entries are relative paths
that may include subdirectories, not a flat basename list — directly relevant to how a new
`scripts/tests/census-*` path (if that shape is chosen) would be registered in core's manifest.

**4. Lean proof-hole counter — design and test gap**

`agent-system/extensions/lean/scripts/lean-sorry-census.sh` (196 lines), registered in
`agent-system/extensions/lean/manifest.json` line 38 under `provides.scripts` as
`"lean-sorry-census.sh"`. Design, confirmed by direct read:
- Primary count: a single-pass, depth-counting Python comment/string stripper
  (`strip_lean_comments`) that correctly handles Lean's nesting `/- outer /- inner -/ still
  outer -/` block comments (explicitly noted as impossible for a fixed-depth `grep -v` pipeline
  to get right — this is effectively the class-1 bug, "keyword appearing inside a directive/
  comment," pre-solved for Lean specifically) and masks string-literal interiors so a `sorry`
  appearing only as string *text* is not miscounted as a live proof obligation. Preserves
  newlines through stripping so post-strip line numbers still match the original file for the
  emitted inventory.
- Optional `--cross-check` tier: runs `lake build` and greps its output for the compiler's own
  `declaration uses 'sorry'` warnings — "an authoritative compiler-backed signal (comment-immune
  by construction -- comments are discarded during lexing before this warning is ever emitted)."
  Reports both counts and flags MATCH/MISMATCH. This is precisely the "cross-checked by a second
  independent method" requirement named in Scope E of the task description, already implemented
  once for one specific keyword/domain.
- **Zero tests**: exhaustive search (`find ... -iname "*count*" -o -iname "*sorry*" -o -iname
  "*hole*"` under `agent-system/extensions/lean`, and the repo-wide `test-*.sh` search below)
  confirms no test file references `lean-sorry-census.sh` anywhere in the tree.

This script is the strongest existing design reference for the census tool this task must
produce: it already demonstrates the derive-once/cross-check-before-trust shape Scope E asks the
standard method to codify, just without tests and without genericity beyond the `sorry` keyword.

**5. Repo-wide test-script census (verifying "verified absence")**

A repo-wide search for `test-*.sh`/`*-test.sh`/`*_test.sh` and any directory named `*test*`
across all of `agent-system/extensions/**` returns exactly:
- `agent-system/extensions/literature/scripts/tests/` (directory)
- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh`
- `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh`
- `agent-system/extensions/core/scripts/test-task-lock-reap.sh`

No other extension (email, memory, nix, nvim, lean, z3, latex, typst, python, web, cslib,
epidemiology, filetypes, formal, founder, present, slidev) has any test script or test directory
under this naming convention. `agent-system/extensions/core/scripts/` itself has 61 entries, of
which exactly one is test-shaped.

**6. Registration mechanics — `manifest.json` and `index-entries.json`**

`manifest.json` top-level keys: `name`, `version`, `description`, `dependencies`,
`routing_exempt`, `merge_targets`, `provides`, `hooks` (lifecycle hooks, distinct from
`provides.hooks`), `routing_hard`. `provides` has sub-arrays `agents`, `commands`, `rules`,
`skills`, `scripts`, `hooks`, `context`, `docs`, `templates`, `systemd`, `root_files` — flat JSON
arrays of relative path strings (verified against both core's and literature's manifests;
literature's `scripts` array includes subdirectory-qualified paths like
`"tests/test-literature-convert.sh"`, proving the array is not required to be flat basenames).

`index-entries.json` is `{"entries": [...]}`, 111 entries in core alone. Each entry: `path`
(relative to `context/`), `domain`, `subdomain`, `summary`, `line_count`, `keywords[]`,
`topics[]`, `load_when: {agents[], task_types[], commands[]}` (or `{always: true}`). Neither
`rules/no-task-references-in-deliverables.md` nor `rules/source-store-deploy-boundary.md` has an
`index-entries.json` entry — rules are auto-applied by path pattern per `CLAUDE.md`'s "Rules
References" section and are a separate mechanism from the `load_when`-driven context index, so a
new standard-method **rule** (if that shape is chosen) would not need an index entry, while a new
standard-method **context/standards doc** (if referenced via `@`-import or `load_when`) would.

`agent-system/extensions/core/context/standards/testing.md` already exists (128 lines) but is a
generic JS/AAA-pattern testing primer with no shell-specific or census-specific content — it is
not a collision with new census-method documentation and does not need to be superseded, only
possibly cross-referenced.

### External Resources

Not applicable — this is an internal agent-system architecture task with no external library or
API dependency; all relevant precedent is in-repo (literature harness, lean census tool, core
hook).

### Recommendations

1. **Deliverable shape (Scope A)**: both shared executable tooling *and* a documented standard
   method, per the task's own binding constraint framing ("Decide... BINDING CONSTRAINT: whatever
   ships must be TESTED"). A method document alone cannot be tested against fixtures; tooling
   alone has no cross-check discipline recorded. Concretely:
   - A generic, reusable census helper script (e.g. `scripts/census-count.sh` or similar,
     core-scoped since the task is about *shared* tooling) that implements: (a) a
     comment/string-aware keyword occurrence counter (generalizing the class-1 fix
     `lean-sorry-census.sh` already solved for Lean, but language-agnostic enough to at minimum
     handle line-comment and simple block-comment stripping, or explicitly delegate to a
     caller-supplied stripper for language-specific cases); (b) a build-graph/file-inventory
     cross-check helper (class-2 fix: enumerate tracked files matching a pattern, separately
     enumerate files actually reachable from a declared build/target list, and diff) — this is
     the one bug class none of the three existing tools (hook, lean census) currently address at
     all; (c) reuse of the fixed separator/suffix-aware regex from Scope C's hook fix as the
     reference implementation for "don't miss hyphenated/underscored/suffixed variants."
   - A `context/standards/census-methodology.md` (or `rules/`) doc for Scope E codifying:
     derive-once, record the exact command, cross-check by a second independent method before
     publishing/acting on the count.

2. **Test harness location (Scope B)**: given the finding above that core already has one
   flat-shaped precedent (`test-task-lock-reap.sh`) and literature itself mixes flat
   (`test-lit-pipeline.sh`, broad/pipeline-scope) and `tests/`-subdirectory (narrow/unit-scope)
   conventions, the cleanest non-arbitrary rule is scope-based, not extension-based: **narrow,
   fixture-driven regression suites for a single script go in a `tests/` subdirectory
   (`agent-system/extensions/core/scripts/tests/`); broad end-to-end/pipeline suites stay flat
   in `scripts/`** — this matches literature's own internal split rather than picking one of its
   two shapes arbitrarily, and does not require moving `test-task-lock-reap.sh` (it is a single-
   script suite, so it would arguably belong under `tests/` too, but moving it is optional
   cleanup outside this task's scope — do not fold that migration into task 926's diff unless the
   implementer judges it trivially safe). The new census tool test(s) are narrow/fixture-driven,
   so they belong under `agent-system/extensions/core/scripts/tests/`.

3. **Hook regex fix (Scope C)**: replace the separator requirement
   `[[:space:]]+` with a class covering whitespace, hyphen, underscore, and `#`(-then-optional-
   space), e.g. `[[:space:]_#-]+` (order-sensitive inside a bracket expression — `-` should be
   first or last to avoid being read as a range) or an alternation
   `([[:space:]]+|[-_]|[[:space:]]*#[[:space:]]*)`, and add a parallel `[Pp]hase` branch. **Decide
   Phase in-scope**: yes — the task description states the hook "has no concept of a Phase
   reference at all" as a named gap in the same breath as the separator bug, and the sibling
   task's update-task-status.sh fix already treats `### Phase N` headings as the same class of
   problem in a different file, so scope-parity argues for covering `Phase` here too rather than
   leaving a second silent gap right after closing the first. Add one fixture per form: `task
   788`, `task-788`, `task_788`, `Task #788`, `tasks 788-790`, `Phase 12`, `Phase-12`,
   `phase_12`, `Phase #12` — both positive (must trigger) and at least one negative fixture
   (ordinary prose containing the word "task" with no adjacent number, to guard against
   over-matching).

4. **Registration (Scope D)**: add the new census script(s) to
   `agent-system/extensions/core/manifest.json`'s `provides.scripts` (and `provides.scripts` again
   for the new `scripts/tests/*.sh` test file(s), following literature's precedent of listing
   `tests/`-prefixed paths verbatim in the same flat array — there is no separate "test scripts"
   array in the schema). Add the standard-method doc to `provides.context` if placed under
   `context/standards/`, and add a matching `index-entries.json` entry with `load_when` scoped to
   whichever agents/commands should surface it (a plausible starting point:
   `general-implementation-agent`, `general-research-agent`, and no restrictive `task_types`
   filter, since census correctness cross-cuts every task type). If the method document is placed
   under `rules/` instead (auto-applied by path, no index entry needed, but also not
   selectively loadable), that is a real trade-off to make explicitly rather than defaulting
   silently — see Decisions.

5. **Fixture coverage — binding constraint check**: confirm before closing this task that
   committed fixtures actually exercise all three named bug classes end-to-end (not just as
   regex unit tests): (1) a keyword inside a comment/directive vs. a real occurrence — reusable
   test shape already exists in `lean-sorry-census.sh`'s stripper logic as a reference; (2) a
   file present in the tree but outside a declared build/target graph — no existing tool in this
   repo tests this today, so this fixture is wholly new; (3) separator/suffix variants — covered
   by the hook regex fixtures in point 3 above, but the shared census tool's own separator
   handling (if it re-implements matching independently of the hook) needs its own copy of the
   same fixture set, not a cross-reference to the hook's tests.

## Decisions

- Both tooling and a documented method are in scope (not an either/or), per the binding-testedness
  constraint requiring something committed and runnable against fixtures.
- Recommend `agent-system/extensions/core/scripts/tests/` as the harness location for the new,
  narrow census-tool test(s), following literature's narrow-suite convention rather than core's
  own pre-existing flat single-script precedent — with the explicit caveat above that this is a
  scope-based rule, not a blanket "always follow literature," and that migrating
  `test-task-lock-reap.sh` is optional out-of-scope cleanup, not a requirement of this task.
  Whoever plans/implements this task should treat this as a recommendation open to revision, not
  a foreclosed decision — the report's job is to surface the tension (Finding 2/3), not silently
  resolve it without flagging the trade-off.
  - Test-lit-pipeline.sh's flat placement suggests a plausible fallback: if the census tool ends
    up broad/pipeline-shaped rather than narrow/unit-shaped once designed, flat placement in
    `scripts/` is equally defensible per literature's own precedent.
- Recommend Phase references be in-scope for the hook regex fix (see Recommendation 3's
  reasoning); this is a recommendation for the planner to confirm, not a unilateral decision by
  this research pass.
- Recommend placing the standard-method document under `context/standards/` (indexed, selectively
  loadable) rather than `rules/` (auto-applied everywhere by path, no index entry) — census
  correctness is a real property most tasks won't need loaded by default, whereas the existing
  `rules/` entries (state-management, git-workflow, error-handling, etc.) are all universally
  applicable to every command. This is a recommendation, not a final decision — the planner
  should confirm against how the doc will actually be consumed (referenced from an agent's
  MUST-DO checklist vs. always-loaded background knowledge).

## Risks & Mitigations

- **Risk**: a generic comment/string stripper that tries to handle "any language" ends up correct
  for none. **Mitigation**: scope the shared tool's stripping to line-comments (`#`, `//`, `--`)
  and simple non-nested block comments as a reasonable default, with an explicit escape hatch
  (caller-supplied stripper callback or pre-stripped input) for languages needing
  `lean-sorry-census.sh`-grade nesting-aware handling — do not attempt to reimplement Lean's
  nested-comment depth-counter generically; that complexity is language-specific and already
  solved where it's needed.
- **Risk**: the build-graph/file-inventory cross-check (class-2 fix) has no existing
  implementation anywhere in this repo to model, unlike the other two bug classes. **Mitigation**:
  keep this piece's first version narrow and explicit (e.g. "list files matching glob X; list
  files referenced by manifest/lakefile/build-target Y; diff") rather than attempting a
  general-purpose build-graph parser; document the narrowness in the method doc so future callers
  know the tool checks *declared* build membership, not transitive reachability.
- **Risk**: expanding `validate-no-task-references.sh`'s regex to also match `Phase` could
  introduce new false positives (e.g. "Phase 3 of the moon" in an unrelated doc) that didn't
  exist before. **Mitigation**: the hook is already advisory/non-blocking (`additionalContext`
  only, never denies the write), so the cost of an occasional false positive is a stray reminder
  message, not a blocked operation — acceptable given the binding requirement to close the
  documented gap.

## Context Extension Recommendations

- **Topic**: shell-script test harness conventions for `agent-system/extensions/core/scripts/`.
- **Gap**: `context/standards/testing.md` exists but is JS/AAA-oriented and does not mention the
  bash test-runner pattern (`t_pass`/`t_fail` or `pass`/`fail` counters, `mktemp -d` + `trap`
  cleanup, exit-1-on-failure) already used twice in this repo (literature, core/task-lock).
- **Recommendation**: once this task's harness-location decision is settled and at least one core
  census test exists, add a short "Shell Script Testing" subsection to
  `context/standards/testing.md` (or a new sibling `context/standards/shell-testing.md`)
  documenting the pattern so the next core-script author doesn't have to re-derive it by reading
  two existing test files. This is a natural follow-up, not part of this task's required scope.

## Appendix

### Search queries / commands used

- `find agent-system/extensions -type d -iname "*test*"`
- `find agent-system/extensions -iname "test-*.sh" -o -iname "*-test.sh" -o -iname "*_test.sh"`
- `find agent-system/extensions/lean -iname "*count*" -o -iname "*sorry*" -o -iname "*hole*"`
- `grep -rli "census" agent-system/extensions/{core,lean,literature}`
- `python3 -c "..."` inspections of `manifest.json`'s `provides` keys and `index-entries.json`'s
  `entries[]` shape (both core and literature manifests)
- Direct `Read` of `hooks/validate-no-task-references.sh`,
  `scripts/test-task-lock-reap.sh`, `scripts/tests/test-literature-convert.sh` (head),
  `lean/scripts/lean-sorry-census.sh` (full), `context/standards/testing.md` (full)

### Files read in full or substantial part

- `agent-system/extensions/core/hooks/validate-no-task-references.sh`
- `agent-system/extensions/core/scripts/test-task-lock-reap.sh`
- `agent-system/extensions/lean/scripts/lean-sorry-census.sh`
- `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` (first ~80 lines)
- `agent-system/extensions/core/context/standards/testing.md`
- `agent-system/extensions/core/manifest.json`, `agent-system/extensions/literature/manifest.json`
  (via `provides` key inspection)
- `agent-system/extensions/core/index-entries.json` (via entry-count/shape inspection)
