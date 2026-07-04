# Implementation Summary: Task #783

**Completed**: 2026-07-03
**Duration**: ~1 hour

## Overview

Replaced the duplicated raw-grep sorry census (`grep -rn "\bsorry\b" ... | grep -v ...`) at 5
call sites across the `cslib` and `lean` extension agents with a single shared script,
`.claude/scripts/lean-sorry-census.sh`. The script uses a depth-counting Lean comment/string
stripper (python3) that correctly handles nested `/- -/` block comments, `--` line comments,
`/-- -/` docstrings, and string literals before matching `\bsorry\b`, eliminating the exact
false-positive class found by cslib task 431 (multi-line docstrings and commented-out TODO
stubs containing the word "sorry"). Validated against a 9-case fixture corpus and a buildable
Lake project cross-check before rollout.

## What Changed

- `.claude/scripts/lean-sorry-census.sh` (new) — canonical shared census script: bash wrapper
  around a python3 depth-counting comment/string stripper, piped into a `\bsorry\b` scan;
  emits `sorry_count` and a `file:line:statement` `sorry_inventory`; opt-in `--cross-check`
  runs `lake build` and compares the stripper count against compiler
  `declaration uses 'sorry'` warnings.
- `.claude/extensions/lean/scripts/lean-sorry-census.sh` (new) — byte-identical extension
  source-of-truth copy for packaging (lean is the base extension; cslib depends on lean).
- `.claude/extensions/lean/manifest.json` — added `"lean-sorry-census.sh"` to
  `provides.scripts` (fixed a duplicate `"scripts"` key introduced mid-edit; final manifest
  validated with `jq empty`).
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` — site #1 (line ~267):
  replaced inline grep chain with `bash .claude/scripts/lean-sorry-census.sh Cslib/`.
- `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` — site #2 (phase-end,
  line ~197): replaced inline chain with the shared script call, which also fixes this site's
  previously-missing `/--` filter via unification. Site #3 (final wrap-up, line ~234):
  replaced with `... --cross-check`, feeding the reported inventory into `sorry_inventory`.
- `.claude/extensions/lean/agents/lean-implementation-agent.md` — site #4 (line ~140): replaced
  inline chain with `bash .claude/scripts/lean-sorry-census.sh Theories/`.
- `.claude/extensions/lean/agents/lean-implementation-hard-agent.md` — site #5 (Stage 6 final
  verification, line ~293): replaced with `... --cross-check`.
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` — updated
  the example verification line (~285) to reference the shared script's `sorry_count: 0` output
  format instead of a bare `grep -rn "sorry"`.
- `specs/783_fix_sorry_census_exclude_comments/fixtures/SorryCensus.lean` (new) — 9-case fixture
  corpus: genuine sorry, full-line comment, trailing inline comment, single-line docstring,
  multi-line docstring (task-431 case), nested block comment, commented-out TODO stub
  (task-431 case), string-literal edge case, second genuine sorry.
- `specs/783_fix_sorry_census_exclude_comments/fixtures/run-census-test.sh` (new) — assertion
  harness asserting exact `sorry_count` and `file:line` matches against the fixture.
- `specs/783_fix_sorry_census_exclude_comments/fixtures/lake-project/` (new) — minimal buildable
  Lake project (toolchain `leanprover/lean4:v4.27.0-rc1`) mirroring the fixture, used to validate
  `--cross-check` against real `lake build` "declaration uses 'sorry'" warnings.

## Decisions

- **String-literal masking (deviation from the report's literal reference algorithm)**: the
  report's reference stripper preserves string-literal content verbatim (only using string
  boundaries to avoid misinterpreting `--`/`/-` tokens inside strings as comment openers). The
  plan's Phase 1 fixture requires a `sorry` appearing only as string text (e.g.
  `#eval "... sorry"`) to NOT count. The implemented stripper masks string interiors with spaces
  (preserving quote delimiters, escape-pair handling, and newlines) rather than preserving them
  verbatim, satisfying this requirement while still correctly tracking string boundaries.
- **`sorry_inventory` schema encoding**: emitted as `file:line:statement` text lines rather than
  JSON objects, per the plan's explicit instruction ("matching the `{file, line, statement}`
  schema" — colon-delimited, consumed by the calling agent to populate the JSON inventory).
- **`--cross-check` runs its own `lake build`**: rather than relying on call-site ordering (some
  sites run `lake build` before the sorry check, others after), the flag is self-contained and
  invokes `lake build` itself, so it works correctly regardless of surrounding step order.

## Plan Deviations

- **Task 2.2** (embed stripper "per the report's reference algorithm") altered: string interiors
  are masked with spaces instead of preserved verbatim. Required by the Phase 1 string-literal
  fixture case; the literal reference algorithm alone would not satisfy it. See Decisions above.
- **Task 3.4** (document cross-check command if toolchain unavailable) skipped: the lake/Lean
  toolchain (`leanprover/lean4:v4.27.0-rc1`) was available in this environment, so the
  build-dependent cross-check validation (including a deliberate-mismatch test) ran directly
  instead of falling back to documentation-only.

## Verification

- Build: N/A (meta task; no project build system for `.claude/` itself)
- Tests: Passed — `run-census-test.sh` reports 2/2 assertions passing (`sorry_count == 2`,
  reported lines == `{SorryCensus.lean:10, SorryCensus.lean:40}`), with zero false positives
  across all 7 non-genuine fixture cases.
- Compiler cross-check: Passed — `--cross-check` against the buildable `fixtures/lake-project/`
  reports `compiler_sorry_count: 2`, `stripper_sorry_count: 2`, `cross_check: MATCH`. A
  deliberate mismatch (3rd genuine sorry added to the buildable project only, stripper pointed
  at the stale 2-sorry fixture) was correctly surfaced as
  `cross_check: MISMATCH (stripper=2, compiler=3)`; the fixture project was reverted afterward
  and re-verified to MATCH.
- Regression sweep: `grep -rn '\bsorry\b' .claude/ --include="*.md"` outside the shared script
  and `grep -rn 'grep -v "^[[:space:]]*--"' .claude/` both return zero matches. Deployed cslib
  symlinks (`.claude/agents/cslib-implementation-agent.md`,
  `.claude/agents/cslib-implementation-hard-agent.md`) verified to resolve through to the edited
  extension-source files. The two script copies (`.claude/scripts/` and
  `.claude/extensions/lean/scripts/`) are confirmed byte-identical via `diff`.
- Files verified: Yes

## Notes

- Territory constraint observed: only the 4 lean/cslib implementation agent files,
  `lean-sorry-census.sh` (both copies), and the lean manifest's `provides.scripts` were edited.
  No `*-research-hard*` agents, `general-implementation-hard-agent.md`, `anti-analysis.md`,
  `wrap-up.md`, `reference-grounding.md`, `index-entries.json`, or `context-hygiene.md` were
  touched, leaving those for task 782's follow-on wiring.
- Follow-up (out of scope, noted in the research report): consider consolidating the
  vacuous-definition and new-axiom checks (still duplicated verbatim across the same 5 sites)
  into a shared script, and consider adding a sorry census to `cslib-vet-agent.md`, which
  currently has no sorry visibility at all.
