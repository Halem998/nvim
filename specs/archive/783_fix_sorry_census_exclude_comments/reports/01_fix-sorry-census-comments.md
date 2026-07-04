# Research Report: Task #783

**Task**: 783 - Fix sorry-census to exclude comment/docstring lines (count only live proof debt)
**Started**: 2026-07-03T00:00:00Z
**Completed**: 2026-07-03T00:00:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: - Codebase grep across `.claude/extensions/cslib/` and `.claude/extensions/lean/`
**Artifacts**: - specs/783_fix_sorry_census_exclude_comments/reports/01_fix-sorry-census-comments.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The raw `grep -rn "\bsorry\b" <dir>/` census exists at **5 duplicated sites** across two
  extensions (`cslib`, `lean`), not inside `/review` or `/vet` proper. `cslib-vet-agent.md`
  (the `/vet` skill's agent) currently runs **no sorry census at all** — it only runs
  `lake lint` for style violations. The census lives in the *implementation* agents'
  "Additional Verification Checks" / CI-pipeline steps, which is what cslib task 431's
  "health-review" indirectly relies on (via `sorry_count`/`sorry_inventory` fields propagated
  into task metadata and later read during review).
- All 5 sites already use `\bsorry\b` (word-boundary) plus two ad-hoc exclusion filters
  (`grep -v "^[[:space:]]*--"` and `grep -v "/--"`), but these filters only catch full lines
  that are pure `--` comments or that literally contain a docstring-open token `/--`. They do
  **not** catch: (a) interior lines of a multi-line `/- ... -/` or `/-- ... -/` block comment
  that don't themselves start with `--` or contain `/--`, and (b) trailing inline `--` comments
  on a code line. This exactly matches the bug cslib task 431 found — "sorry-free" and
  "removing the sorry" sitting on non-`--`-prefixed lines inside multi-line docstrings, plus a
  commented-out TODO stub inside a `/- ... -/` block.
- **Recommended fix**: replace the ad-hoc grep-filter chain with a single shared script,
  `.claude/scripts/lean-sorry-census.sh`, that (1) strips Lean comments correctly — including
  arbitrarily nested `/- -/` block comments — via a small depth-counting stripper (awk or
  python3, not regex, since regex cannot count nesting), preserving line numbers by keeping
  newlines in place of stripped content, then (2) greps `\bsorry\b` on the stripped text, and
  optionally (3) cross-checks the result against `lake build` "declaration uses 'sorry'"
  warnings (or `lean_verify` / `#print axioms ... sorryAx` for a specific declaration) as an
  authoritative second signal, since the compiler already discards comments correctly and can
  never be fooled by comment content. All 5 call sites should be updated to invoke the shared
  script instead of inlining the grep chain.
- Verification plan: build a small fixture `.lean` corpus covering code-sorry, `--`-comment
  sorry, single-line `/-- -/` docstring sorry, multi-line docstring sorry (the exact bug
  pattern), nested `/- /- -/ -/` block-comment sorry, and trailing inline-comment sorry; assert
  the script counts only the genuine code-sorry cases; cross-check against `lake build` warning
  count on the same fixture.

## Context & Scope

Task 783 is a meta task against this repository's shared `.claude/` agent system (not the
`cslib` project repo itself, which is a separate checkout at `~/Projects/cslib`). The task was
moved here from cslib task 437 specifically because the sorry-census logic lives in the shared
agent-system tooling (this `.claude/` tree, mirrored into child projects such as cslib), not in
cslib's own project files. The originating evidence (cslib `specs/431_.../reports/01_unowned-sorries-audit.md`,
`specs/reviews/review-2026-06-30*.md`) lives in the cslib repo and was not accessible from this
session; this research instead locates and analyzes the actual shared-tooling grep logic that
produces `sorry_count`/`sorry_inventory` values consumed during CSLib task implementation and
review.

Scope of this research: locate every place under `.claude/` that performs a raw/word-boundary
`grep`-based sorry census over a Lean source tree, understand exactly why the existing
exclusion filters fail on nested/multi-line comments, and evaluate the two fix strategies named
in the task (comment-stripping regex vs. compiler cross-check).

## Findings

### Codebase Patterns

**Exact census call sites** (all use `Bash` tool, all under `.claude/extensions/`):

| # | File | Line | Command | Scanned dir |
|---|------|------|---------|-------------|
| 1 | `.claude/extensions/cslib/agents/cslib-implementation-agent.md` | 267 | `grep -rn "\bsorry\b" Cslib/ \| grep -v "^[[:space:]]*--" \| grep -v "/--" \| wc -l` | `Cslib/` |
| 2 | `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` | 197 | `grep -rn "\bsorry\b" Cslib/ \| grep -v "^[[:space:]]*--" \| wc -l` | `Cslib/` (phase-end; **missing the `/--` filter entirely**) |
| 3 | `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` | 234 | `grep -rn "\bsorry\b" Cslib/ \| grep -v "^[[:space:]]*--" \| grep -v "/--" \| wc -l` | `Cslib/` (final wrap-up) |
| 4 | `.claude/extensions/lean/agents/lean-implementation-agent.md` | 140 | `grep -rn "\bsorry\b" Theories/ \| grep -v "^[[:space:]]*--" \| grep -v "/--" \| wc -l` | `Theories/` (generic lean4 extension) |
| 5 | `.claude/extensions/lean/agents/lean-implementation-hard-agent.md` | 293 | `grep -rn "\bsorry\b" Theories/ \| grep -v "^[[:space:]]*--" \| grep -v "/--" \| wc -l` | `Theories/` |

A sixth, non-executable reference: `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md:285`
documents `grep -rn "sorry"`: 0 hits" as the example verification line for PR descriptions —
purely illustrative text, not invoked tooling, but should be updated to match whatever the
canonical script reports so PR descriptions don't imply a weaker check than what's actually run.

**Where `/review` and `/vet` fit in**: `cslib-vet-agent.md` (invoked by `/vet` via
`skill-cslib-vet`) runs the 7-step CI pipeline (`lake build`, `checkInitImports`, `lake lint`,
`lake exe lint-style`, etc.) plus `lake lint` style-violation grepping
(`docBlame|defLemma|defsWithUnderscore|simpNF|unusedSectionVars|topNamespace|dupNamespace`) but
**does not currently run a sorry census at all**. The generic `/review` command
(`.claude/commands/review.md`) has no Lean-specific logic and no sorry grep either. The actual
census is embedded in the *implementation* agents' verification stage (Stage/Step "Additional
Verification Checks" in the non-hard agents, Stage 4.5/5 in the hard agents), whose
`sorry_count`/`sorry_inventory` output is what later review/audit processes (like cslib's task
431 "unowned foundational sorry" audit) must be reading or re-deriving. Fixing task 783
correctly therefore means fixing the shared grep logic at its 5 source sites (all under
`.claude/extensions/{cslib,lean}/agents/*.md`), since that is the only place in this shared
system that performs the census today. If cslib task 431's own audit script independently
re-implements a raw `grep -rn sorry Cslib/**.lean` (outside this shared `.claude/` tree, in the
cslib repo itself), that is out of scope for this shared-system task per the task's own framing
("Update whichever shared agent-system tooling performs the census... under `.claude/`”) — but
the fix produced here (the shared script) is the artifact any such audit script should be
pointed at instead of re-inlining its own grep.

### Root-cause analysis: why the existing filters still false-positive

The current filter chain is:
```bash
grep -rn "\bsorry\b" Cslib/ | grep -v "^[[:space:]]*--" | grep -v "/--"
```

1. `\bsorry\b` matches "sorry" as a token, but `\b` is satisfied by *any* non-word character on
   either side — including `-`. So `sorry-free` still matches `\bsorry\b` (boundary between `y`
   and `-`). This is exactly why "moving to word-boundary did not help": the word-boundary claim
   in the task description is about token matching, not comment exclusion, and it was never
   going to fix a comment-scoping problem.
2. `grep -v "^[[:space:]]*--"` removes only lines whose **entire** content (after leading
   whitespace) is a `--` line comment. It does **not** remove:
   - Interior lines of a multi-line block comment, e.g.:
     ```lean
     /--
     This lemma is now sorry-free after removing the sorry from the earlier draft.
     -/
     ```
     Line 2 here starts with `This`, not `--`, so it survives filter 1. It also does not
     contain the substring `/--`, so it survives filter 2 as well. This is precisely the
     multi-line-docstring false positive cslib task 431 reports.
   - A commented-out code stub inside a generic block comment:
     ```lean
     /-
     TODO: this used to be `theorem foo := by sorry`, revisit later.
     -/
     ```
     Same failure mode — neither filter catches it.
   - A trailing inline comment on an otherwise sorry-free code line:
     ```lean
     theorem foo : True := trivial  -- no longer uses sorry
     ```
     `\bsorry\b` matches inside the trailing comment text; the line does not start with `--`
     (there's code before it), so filter 1 doesn't strip it, and it may or may not contain
     `/--`. This produces a false positive from a *pure* line comment tail, not even a block
     comment.
3. `grep -v "/--"` only removes lines that literally contain the 3-character substring `/--`
   (typically the docstring-opening line). It does nothing for any other line of the docstring
   body, and nothing for plain `/- -/` block comments (no `/--` token at all).
4. Site #2 (`cslib-implementation-hard-agent.md:197`, the phase-end check) is missing the
   `/--` filter entirely — it is strictly weaker than the other 4 sites, so it is even more
   prone to counting docstring-open lines as live debt. This inconsistency across the 5 sites
   is itself a defect: phase-end and wrap-up counts can disagree for the same file state.

None of these are fixable by adding more `grep -v` patterns, because Lean's `/- -/` block
comments **nest** (`/- outer /- inner -/ still outer -/` is valid Lean and is one comment, not
two), and nesting depth cannot be tracked by a regex/grep pipeline — regular expressions cannot
count unbounded, unmatched levels of nesting (a classic non-regular-language argument). Any
fix that stays inside single-pass `grep`/`sed` line filters will always have a `/- .. sorry ..
-/` counter-example somewhere. This is the concrete technical reason to move to a proper
stripping pass.

### External Resources / Language Reference

- Lean 4 comment syntax: `--` runs to end of line; `/- ... -/` is a nestable block comment;
  `/-- ... -/` is a documentation ("doc") comment, which is a block comment whose only special
  property is that it must immediately precede a declaration — lexically it obeys the exact
  same nesting rule as `/- -/` (it simply starts with the 3-character token `/--` instead of
  `/-`). Any correct stripper that handles nested `/- -/` automatically handles `/-- -/` for
  free, since `/--` is recognized as "start of block comment" the moment the lexer sees `/-`.
- The Lean compiler itself emits a diagnostic `warning: declaration uses 'sorry'` for every
  declaration whose elaborated term contains `sorryAx`, and `#print axioms <decl>` reports
  `sorryAx` in the axiom list for any declaration (transitively) depending on `sorry`. Both
  signals are **comment-immune by construction** — the compiler has already discarded all
  comments during lexing before either check runs. This is the "cross-check against the
  compiler" option named in the task, and it is strictly authoritative: it cannot be fooled by
  comment content, string literals, or `sorry`-shaped identifiers, because it observes the
  elaborated term, not source text at all.
- The `lean-lsp` MCP server available in this environment already exposes `lean_verify`
  ("Axiom check + source scan. Use fully qualified name.") — this is a ready-made,
  non-grep, compiler-backed check for a single declaration, already used elsewhere in the cslib
  agents (`rules/cslib.md:45`: "During proof (inner loop): ... `lean_verify` for axiom/sorry
  check"). It is not currently used for the *directory-wide* census, only per-declaration during
  active proof work.

### Recommendations

**Primary fix — shared comment-stripping script + optional compiler cross-check**:

1. Create `.claude/scripts/lean-sorry-census.sh` (a thin CLI wrapper) that:
   - Takes a directory (`Cslib/`, `Theories/`, or a specific file list from `git diff
     --name-only`) as its argument.
   - Internally strips comments with a small **depth-counting stripper** (python3 one-liner
     invoked via `python3 -c`, or `awk`, either works — python3 is simplest to get right).
     Concrete algorithm (character-scan, single pass per file, O(n)):
     ```python
     def strip_lean_comments(text: str) -> str:
         out, i, n, depth, in_str = [], 0, len(text), 0, False
         while i < n:
             c = text[i]
             if depth == 0 and not in_str:
                 if text[i:i+2] == "--":              # line comment
                     j = text.find("\n", i)
                     i = n if j == -1 else j            # keep the newline itself
                     continue
                 if text[i:i+2] == "/-":                # enter block comment (handles /-- too)
                     depth, i = 1, i + 2
                     continue
                 if c == '"':
                     in_str, out, i = True, out + [c], i + 1
                     continue
                 out.append(c); i += 1
             elif in_str:
                 out.append(c)
                 if c == "\\" and i + 1 < n:             # skip escaped char
                     out.append(text[i+1]); i += 2; continue
                 if c == '"':
                     in_str = False
                 i += 1
             else:                                      # inside block comment, depth >= 1
                 if text[i:i+2] == "/-":
                     depth += 1; i += 2; continue
                 if text[i:i+2] == "-/":
                     depth -= 1; i += 2; continue
                 if c == "\n":
                     out.append("\n")                    # preserve line numbers
                 i += 1
         return "".join(out)
     ```
     This handles: nested `/- /- -/ -/`, `/-- -/` doc comments (falls into the same `/-`
     branch), trailing `--` comments, and multi-line comment bodies — because block-comment
     interiors are simply dropped (except newlines, which are kept so `grep -n` line numbers on
     the stripped output still line up with the original file).
   - Pipes the stripped text through `grep -wn sorry` (or an equivalent Python
     `re.finditer(r'\bsorry\b', ...)`) to produce the file:line-accurate live-debt count.
   - Optionally accepts a `--cross-check` flag that also runs `lake build 2>&1 | grep -c
     "declaration uses 'sorry'"` (or parses `lean_verify`/`#print axioms` output per flagged
     declaration) and reports both numbers; a mismatch is itself a signal worth surfacing
     (e.g., stripper under/over-counts, or a `sorry` reachable only via a transitively-included
     axiom).
   - Emits both a total count (for `sorry_count`) and a `file:line:statement` list (for
     `sorry_inventory`, matching the schema in `.claude/context/contracts/wrap-up.md`: `{file,
     line, statement}`).
2. Replace the inlined `grep -rn "\bsorry\b" ... | grep -v ... | grep -v ...` command at all 5
   sites (table above) with a call to the shared script, e.g.
   `bash .claude/scripts/lean-sorry-census.sh Cslib/`. This removes the duplication (5 slightly
   inconsistent copies -> 1 canonical implementation) and fixes site #2's missing `/--` filter
   as a side effect of unification.
3. Update `pr-description-format.md:285`'s example verification line to reference the same
   script's output format so PR descriptions and the actual census agree.
4. Consider adding the same census (via the shared script) to `cslib-vet-agent.md`'s CI-pipeline
   report, since `/vet` currently has no sorry visibility at all — this directly closes the gap
   that let cslib task 431's "unowned foundational sorry" false positives go undetected by
   `/vet` in the first place (the audit that found them was evidently a separate, ad-hoc script
   outside this shared tooling).

**Why not comment-stripping regex alone, and why not compiler-only**:
- A single regex/grep pipeline cannot correctly strip arbitrarily nested `/- -/` comments
  (nesting requires a counter, not a fixed-depth pattern) — this rules out an ever-growing chain
  of `grep -v` filters as a durable fix.
- Compiler cross-check alone (`lake build` warning grep) is authoritative but requires a full or
  scoped `lake build`, which is slow (the CI pipeline docs note 2-5 minutes after cache, 25-45
  minutes on cache miss) and is not always run at every checkpoint where a quick sorry count is
  wanted (e.g., a fast `/vet` pass, or a mid-phase check). The text-based stripper gives a fast,
  build-independent count; the compiler cross-check is the authoritative confirmation at
  wrap-up/final-verification time, when a `lake build` is already being run anyway (all 5 sites
  already run `lake build` earlier in their same verification sequence — the marginal cost of
  grepping its output for "declaration uses 'sorry'" is ~zero).
- Recommendation is therefore **both**, layered: stripper for fast/frequent counts, compiler
  warning grep as the free-riding authoritative check whenever a `lake build` already ran in the
  same step (which is true at every one of the 5 existing call sites, since `lake build` always
  precedes the sorry check in their documented sequences).

## Decisions

- Treat all 5 grep sites listed above as the "shared agent-system tooling" the task refers to;
  no separate `/review` or `/vet` sorry-census logic exists in this `.claude/` tree today
  (confirmed by exhaustive grep for `sorry` across `.claude/commands/review.md`,
  `.claude/agents/code-reviewer-agent.md`, and both `cslib-vet-agent.md` /
  `skill-cslib-vet/SKILL.md`).
- Recommend a single new shared script (`.claude/scripts/lean-sorry-census.sh`) rather than
  patching each of the 5 markdown files' inline grep chains independently, to eliminate the
  duplication that already let site #2 drift out of sync (missing the `/--` filter).
- Recommend layering the comment-stripper (fast, build-independent) with a compiler
  cross-check (`lake build` "declaration uses 'sorry'" grep) reusing the `lake build` step every
  site already runs immediately beforehand, rather than picking only one of the two approaches
  named in the task.

## Risks & Mitigations

- **Risk**: A hand-rolled comment/string stripper could itself have edge-case bugs (e.g., Lean
  string literals containing `"--"` or `"/-"`, character literals `'"'`, raw string variants).
  **Mitigation**: keep the stripper minimal and scoped only to what's needed to correctly
  delimit `--`, `/- -/` nesting, and `"..."` string literals with backslash-escaping (shown
  above); validate against the fixture corpus in the verification plan before rollout; the
  compiler cross-check at wrap-up time acts as a backstop against stripper bugs.
- **Risk**: Updating 5 files plus a new script increases the chance of one site being missed or
  updated inconsistently (as already happened with site #2's missing filter). **Mitigation**:
  grep for `\\bsorry\\b.*grep -v` across `.claude/` post-fix as a regression check that no raw
  inline grep chain remains; all sites should reference the shared script.
- **Risk**: `lake build`-based cross-check is slow and not always desired for quick sorry
  checks. **Mitigation**: make `--cross-check` opt-in, defaulting to stripper-only for
  fast/frequent checks, reserving cross-check for the final wrap-up stage where `lake build`
  already runs.

## Context Extension Recommendations

- **Topic**: Shared Lean census/verification helper scripts
- **Gap**: `.claude/scripts/` currently has no Lean-specific helper scripts at all (verified:
  only `setup-lean-mcp.sh` and `verify-lean-mcp.sh` exist, both MCP-server setup, not source
  analysis). All Lean-source verification logic (sorry census, vacuous-definition grep, axiom
  grep) is duplicated as inline bash across 5 agent markdown files in 2 extensions.
- **Recommendation**: After this task lands `lean-sorry-census.sh`, consider extending the same
  shared-script pattern to the vacuous-definition and new-axiom checks (also duplicated
  verbatim across the same 5 sites), consolidating all "Additional Verification Checks" into one
  `.claude/scripts/lean-verification-checks.sh` invoked identically by both the `cslib` and
  `lean` extensions' implementation agents. Out of scope for this task; noted for a possible
  follow-up.

## Appendix

### Search queries used

```
grep -rn "sorry" .claude/skills/skill-cslib-vet .claude/scripts .claude/commands
grep -rln "sorry" .claude/ --include="*.sh" --include="*.md"
grep -rn "grep.*sorry\|sorry.*grep" .claude/ --include="*.md" --include="*.sh"
grep -rn "unowned\|foundational sorry\|health-review\|declaration uses sorry\|sorryAx" .claude/
grep -n "lake build\|declaration uses\|sorryAx\|#print axioms" -r .claude/extensions/{cslib,lean}
```

### File/line references

- `.claude/extensions/cslib/agents/cslib-implementation-agent.md:267`
- `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md:197,234`
- `.claude/extensions/lean/agents/lean-implementation-agent.md:140`
- `.claude/extensions/lean/agents/lean-implementation-hard-agent.md:293`
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md:285` (doc reference only)
- `.claude/extensions/cslib/agents/cslib-vet-agent.md` (no sorry census present; runs `lake lint` for style only)
- `.claude/context/contracts/wrap-up.md:33` (`sorry_inventory` schema: `{file, line, statement}`)
- `.claude/extensions/cslib/rules/cslib.md:45` (existing per-declaration `lean_verify` usage during proof loop)

## Verification Plan (for the implementation phase)

1. **Fixture corpus**: create a throwaway `.lean` test file (or in-memory string in a test
   harness) containing, each on distinguishable lines:
   - a genuine `sorry` in a theorem body (must count);
   - `-- sorry` as a full-line comment (must NOT count);
   - `theorem foo := trivial  -- no longer uses sorry` trailing comment (must NOT count);
   - `/-- This proof is sorry-free after removing the sorry. -/` single-line docstring (must
     NOT count, 2 occurrences on one line);
   - a multi-line docstring reproducing the exact bug: `/--\nsorry-free after removing the
     sorry\n-/` (must NOT count);
   - a nested block comment `/- outer /- inner sorry -/ still outer -/` (must NOT count, tests
     nesting depth tracking specifically);
   - a commented-out TODO stub `/-\nTODO: revisit `theorem foo := by sorry`\n-/` (must NOT
     count — this is the literal cslib task 431 case).
2. **Unit assertion**: run the new script against the fixture; assert reported count equals
   exactly the number of genuine code-sorry occurrences, and assert reported line numbers match
   the genuine occurrences' original (unstripped) line numbers.
3. **Compiler cross-check**: `lake build` the fixture module (or a minimal throwaway Lake
   project) and grep its output for `declaration uses 'sorry'`; assert the count matches the
   stripper's count on this fixture, validating the two signals agree when the stripper is
   correct.
4. **Regression against task 431's original report**: if the cslib repo's original 8 false
   positives (7 docstring occurrences + 1 commented-out stub) are available for inspection,
   re-run the new script against the same `Cslib/` state that produced them and confirm 0 of
   the 8 are reported.
5. **Consistency check**: after updating all 5 sites, grep `.claude/extensions/` for the old
   inline pattern (`grep -rn "\\\\bsorry\\\\b"`) and assert zero remaining matches outside the
   new shared script itself.
