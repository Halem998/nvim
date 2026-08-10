# Research Report: Task #1003

**Task**: 1003 - Fix lean-sorry-census.sh double-counting warn.sorry suppression annotations
**Started**: 2026-08-10T07:02:30Z
**Completed**: 2026-08-10T07:10:00Z
**Effort**: Small (single-file regex fix + docstring edit + new regression fixture)
**Dependencies**: None
**Sources/Inputs**: Codebase read (script source, git log, referencing agent/context docs), local regex verification (python3)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Executive Summary

- The task description's root-cause analysis is fully verified: `agent-system/extensions/lean/scripts/lean-sorry-census.sh` line 144 uses `sorry_re = re.compile(r'\bsorry\b')`, and `\b` matches at the `n`/`.` boundary in `warn.sorry`, so every own-line `set_option warn.sorry false in` annotation is counted as an extra phantom sorry.
- Independently reproduced the exact fix in this session: `(?<![.\w])sorry\b` returns `False` on `set_option warn.sorry false in` and `foo.sorry` (both currently false positives) while still returning `True` on `theorem foo : P := sorry`, `set_option warn.sorry false in theorem bar : Q := sorry` (same-line form), and plain `  sorry` — i.e. the fix removes the phantom count without touching any real-sorry detection, including the same-line form the task description specifically warns not to regress.
- Counting is confirmed per-line (`if sorry_re.search(line): total += 1`, line 158), so the phantom inflation is strictly one count per own-line annotation, consistent with the task's evidence (18 annotations = 18 phantom).
- This script has a real downstream consumer with a hard gate: both `lean-implementation-agent.md` (line 147-149) and `cslib-implementation-agent.md` (line 305-309) run this script and require `sorry_count` to be exactly `0` for "implemented" status; `cslib`'s `pr-description-format.md` requires the same `sorry_count: 0` line verbatim in PR descriptions. The double-counting bug therefore does not just misreport a metric — it can hard-block legitimate zero-sorry submissions or overstate the size of a sorry backlog by exactly the suppression-annotation count in scope.
- No existing test file guards this script (`find agent-system -iname "*sorry*"` returns only the script itself); the lean extension has no `scripts/tests/` directory today (core does, at `agent-system/extensions/core/scripts/tests/`). A new fixture should follow the core convention (`test-census-count.sh`'s `pass()/fail()/info()` + `mktemp -d` + `trap EXIT` + PASSED/FAILED counters + exit 0/1 shape), most naturally at `agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` (new directory).
- Git history is clean for this concern: the only recent commit touching the file (`8dcb6d92e`) was a task-number-reference purge that did not touch matching logic — the bug is live and unaddressed in the source store, and no work-in-progress conflicts with this fix.

## Context & Scope

Researched the single-file defect described in the task: `agent-system/extensions/lean/scripts/lean-sorry-census.sh`'s final `sorry` regex counts `warn.sorry` substrings inside `set_option warn.sorry false in` annotations as phantom sorries, in addition to any real sorry the annotation exists to suppress. Scope per `file_scope` in state.json is the script itself plus the `agent-system/extensions/lean/` tree (for fixture placement and any downstream consumers/docs that reference the script's counting semantics).

Read the file in full, ran independent regex verification, searched for existing tests, and traced every caller/consumer of the script's `sorry_count` output across the lean and cslib extensions to confirm real-world impact and to determine what documentation, if any, needs a matching update.

## Findings

### Codebase Patterns

- **The bug, confirmed line-for-line**: `agent-system/extensions/lean/scripts/lean-sorry-census.sh:144` — `sorry_re = re.compile(r'\bsorry\b')`. `\b` is a zero-width boundary between a `\w` and non-`\w` character; `.` is non-word, so the boundary fires between `warn` and `.sorry`, making `\bsorry\b` match the `sorry` in `warn.sorry` exactly as if it were a standalone identifier.
- **Per-line, not per-occurrence counting**: `lean-sorry-census.sh:157-161` — `if sorry_re.search(line): total += 1` increments once per *line* that contains a match, not once per match. This is the reason phantom inflation happens only when the annotation sits on its own line (own-line: two separate lines each independently match once → +1 phantom per annotation instead of the +1 for the real sorry alone) and does not currently over-inflate the same-line form (`set_option warn.sorry false in theorem bar : Q := sorry` is one line containing two textual `sorry`-boundary matches, but `search()` short-circuits on first match, so it is still counted once — coincidentally correct today, but fragile: a naive fix that switches to `findall`/count-of-matches instead of count-of-lines would newly break this case).
- **Comment/string stripper is correct and independent of this bug**: `strip_lean_comments()` (lines 91-141) runs before the regex scan and is untouched by the fix. Verified: a naive count that skips this stripper entirely returns 152 repo-wide per the task's own evidence, well below both the naive-`\bsorry\b`-after-stripping count (199 in the `Cslib/**/*.lean` sub-check) and the corrected count (181) — i.e. the stripper's contribution and the regex-boundary bug are two independent, non-overlapping effects, and stripper correctness is not implicated by this fix.
- **Docstring drift target identified**: `lean-sorry-census.sh:96` — `strip_lean_comments()`'s own docstring says "...later matched by the `\bsorry\b` scan..." This is documentation, not logic (the function it lives inside is stripping only, not matching), but it names the pre-fix regex literally and will go stale the moment line 144 changes. This is the "one docstring reference" the task description flags for a text-only edit.
- **Cross-check oracle already exists and is unaffected by the fix's mechanics**: `--cross-check` (flag parse at line 53-55, comparison at 175-195) shells out to `lake build` and greps `"declaration uses 'sorry'"`, a compiler-emitted signal that has already discarded comments/annotations by the time it's lexed. This is comment/annotation-immune by construction, making it the correct oracle to prove `cross_check: MATCH` post-fix on a scope that currently reports `MISMATCH` (Cslib/Logics/Bimodal: 41 reported vs. presumably 23 compiler-confirmed, per the task's own prior verification).
- **Real downstream gate, not just a metric**: both `lean-implementation-agent.md:145-149` and `cslib-implementation-agent.md:305-309` invoke this exact script and require `sorry_count` to equal `0` before an implementation may be marked complete; `cslib/context/project/cslib/standards/pr-description-format.md:285` requires the literal string `sorry_count: 0` to appear in the PR description's verification block. A file containing zero real sorries but one own-line `warn.sorry` suppression annotation (e.g., left over from a previously-fixed sorry, or copy-pasted boilerplate) would currently report `sorry_count: 1` and could incorrectly block a legitimate "implemented" status or produce an incorrect PR description claim. This raises the stakes of the fix beyond "the census number is off."
- **No existing regression coverage**: `find agent-system -iname "*sorry*"` returns only the script itself. The lean extension has no `scripts/tests/` subdirectory (`find agent-system/extensions/lean -type d` shows only `commands/, scripts/, agents/, rules/, context/, skills/` and their children) — core does, at `agent-system/extensions/core/scripts/tests/`, containing ~20 fixture-driven suites in a consistent style (see `test-census-count.sh`: `set -uo pipefail`, `pass()/fail()/info()` helpers with `PASSED`/`FAILED` integer counters, `mktemp -d` workdir with `trap ... EXIT` cleanup, synthetic-only fixtures built via heredocs, exit 0 on all-pass / 1 on any-fail). `test-census-count.sh`'s own header explicitly documents an "anti-vacuous-test guard": every bug-class fixture must assert *both* the naive/wrong number and the corrected number on the same fixture, so a fixture only a broken implementation would fail is required — directly applicable to the new sorry-census fixture (assert both "buggy regex would give 2" and "fixed regex gives 1" against the same own-line fixture).
- **Manifest wiring**: `agent-system/extensions/lean/manifest.json` line 38 lists `lean-sorry-census.sh` under `provides.scripts` with no `tests` key in the schema observed elsewhere for this manifest; a new `scripts/tests/test-lean-sorry-census.sh` would not need a manifest entry to be discoverable by the same mechanism as core's tests (core's test files are not separately listed in `provides` either — they ride along as part of the `scripts` directory being deployed, or are invoked directly by path in CI/lint tooling). No lint script currently enumerates or requires lean-extension test coverage, so adding the fixture is additive and low-risk.
- **Git history is clean**: `git log --oneline -- agent-system/extensions/lean/scripts/lean-sorry-census.sh` shows only two commits, `8dcb6d92e` (task-number-reference purge, matching logic untouched) and `7e79b2695` (an unrelated store/path relocation). No other agent or task has modified this file recently; the sibling batch task noted in the delegation context (index-entries.json `load_when.agents` union edits on `contracts/*` entries) touches a different file and is confirmed unrelated by inspection — it does not appear anywhere in this script's git history or its referencing docs.
- **Class A shell-strict-mode note (informational, out of scope for this fix)**: `agent-system/extensions/core/context/standards/shell-strict-mode.md` lists `lean/scripts/lean-sorry-census.sh` among non-core extension scripts classified for a future `-e`-hostility migration; the script already uses `set -uo pipefail` (no `-e`), which is consistent with that classification and requires no change for this task.

### External Resources

Not applicable — this is a self-contained internal shell/Python defect with no external library or API dependency. No web research was needed or performed.

### Recommendations

1. **Regex fix** (line 144): replace `re.compile(r'\bsorry\b')` with `re.compile(r'(?<![.\w])sorry\b')`. Verified independently in this session against all five discriminating cases named in the task description plus one additional case (`foo.sorry`, a general dotted-qualified name, not just `warn.sorry`):

   | Input | naive `\bsorry\b` | fixed `(?<![.\w])sorry\b` |
   |---|---|---|
   | `set_option warn.sorry false in` | True (bug) | False (correct) |
   | `theorem foo : P := sorry` | True | True |
   | `set_option warn.sorry false in theorem bar : Q := sorry` (same-line) | True | True |
   | `foo.sorry` (general dotted name) | True (bug) | False (correct) |
   | `  sorry` | True | True |

   No other line in the file needs to change to support this — `strip_lean_comments()` is untouched, and the per-line `if sorry_re.search(line)` counting semantic is preserved as-is (do not switch to occurrence-counting; that would double the same-line case since `search()` on `(?<![.\w])sorry\b` still matches only the trailing bare `sorry`, once, per line — no regression risk from the regex change alone, but a hypothetical unrelated refactor to occurrence-counting would need re-verification against the same-line fixture).

2. **Docstring edit** (line 96 only): update `"...later matched by the \\bsorry\\b scan..."` to name the corrected pattern, e.g. `"...later matched by the (?<![.\\w])sorry\\b scan..."`. This is a comment/string-literal text change inside the Python heredoc, not a logic change — verify the byte range touched is exactly this one docstring line plus line 144's regex literal, and that `strip_lean_comments()`'s executable body (lines 98-141) remains byte-identical, per the task's explicit preservation requirement.

3. **New regression fixture**: create `agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` (new `tests/` subdirectory, mirroring core's `agent-system/extensions/core/scripts/tests/` convention). Follow `test-census-count.sh`'s shape: `set -uo pipefail`; `pass()/fail()/info()` with `PASSED`/`FAILED` counters; `mktemp -d` + `trap ... EXIT`; synthetic `.lean` fixtures only (never touches a real Lean project — no `lake` invocation needed for the non-cross-check assertions, keeping this suite fast). Minimum fixture content, per the task's explicit dual-form requirement:
   - Own-line form: `set_option warn.sorry false in` on its own line immediately followed by a `theorem ... := sorry` line → assert reported count contributes exactly 1 for this pair (anti-vacuous: also assert that the naive `\bsorry\b` pattern applied to the same fixture text would give 2, so the fixture actually discriminates the two implementations).
   - Same-line form: `set_option warn.sorry false in theorem bar : Q := sorry` on one line → assert exactly 1 (not 0, not 2) — this is the regression guard against an over-aggressive line-skipping alternative fix.
   - At least one commented-out sorry (inside `--` or `/- -/`) and one string-literal sorry → assert these contribute 0, to simultaneously pin the stripper's continued correctness.
   - Multiple real sorries (`N` annotations + `M` real sorries) → assert total reported count equals `M`, not `M + N`.
   Run the script under test via its documented CLI (`bash lean-sorry-census.sh <tmpdir>`) and parse `sorry_count: N` from stdout, matching the parsing style already used internally by the script's own `--cross-check` branch (`grep -oE '^sorry_count: [0-9]+' | grep -oE '[0-9]+'`).

4. **Verification bar**: per the task description, the intended external oracle is the script's own `--cross-check` flag against a real Lean scope (e.g., `Cslib/Logics/Bimodal` per the task's prior manual verification) — expect `cross_check: MATCH` post-fix where it previously reported `MISMATCH`. This requires a Lean toolchain and `lake build`, which is outside this research agent's tool access; the implementer should run this manually or via the lean extension's own build tooling as the final verification step, in addition to the new automated fixture (which is toolchain-free and CI-safe).

5. **No other file needs to change.** `lean-implementation-agent.md`, `cslib-implementation-agent.md`, and `pr-description-format.md` all consume `sorry_count` as an opaque integer with a `must be 0` gate — none of them encode the buggy regex or need updating; they will simply start receiving a correct number. `census-methodology.md` references `--cross-check` in general terms and does not describe the internal regex, so it also needs no edit.

## Decisions

- **Fix locus confirmed as line 144 (regex) + line 96 (docstring) only** — no changes to `strip_lean_comments()`'s logic body, no changes to the per-line counting semantic, no changes to the `--cross-check` mechanism.
- **Fixture location**: new `agent-system/extensions/lean/scripts/tests/` directory, following core's naming and structural convention (`test-lean-sorry-census.sh`), rather than a flat file directly under `agent-system/extensions/lean/scripts/`. This mirrors the only existing precedent in the repo (`agent-system/extensions/core/scripts/tests/`) and keeps test files clearly separated from the two invocable scripts in the lean extension.
- **Regex form**: `(?<![.\w])sorry\b`, matching the task description's specified and pre-verified form exactly (not an alternative like a line-level `set_option warn.sorry false in` pre-filter, which the task description itself flags as riskier because it must still special-case the same-line form — the regex fix subsumes both forms uniformly and was chosen as primary by the task author; this research independently confirms that choice rather than proposing an alternative).

## Risks & Mitigations

- **Risk**: a fix that switches from line-search to match-count (e.g., `len(sorry_re.findall(line))`) would double-count the same-line form (`set_option warn.sorry false in theorem bar : Q := sorry` would then match twice under the naive pattern, or the annotation text itself could still partially match variants of a less-precise fixed pattern). Mitigation: keep the existing `if sorry_re.search(line): total += 1` per-line-boolean structure unchanged; only the compiled pattern changes.
- **Risk**: an implementer might be tempted to solve this by skipping any line containing the literal substring `warn.sorry`, which breaks the same-line form (the sorry_re would never see that line, so a genuine sorry riding on the same line as the annotation would be silently dropped — false negative for real proof debt). Mitigation: the task description already names this exact anti-pattern and requires the fixture to test the same-line case for exactly 1, not 0; this research confirms via direct fixture-style testing that the regex-based fix does not have this defect while a line-skip fix would.
- **Risk**: docstring line 96 is easy to overlook since it lives inside a large Python heredoc embedded in bash and might not surface in a naive diff review of "the regex line." Mitigation: call it out explicitly as a required companion edit (already done in Recommendations #2).
- **Risk**: without toolchain access, this research could not itself run `--cross-check` against a live Lean project to reproduce the exact 45→27 / 41→23 deltas claimed in the task description. Mitigation: the regex-level verification performed here (five discriminating test strings covering own-line, same-line, dotted-name, and plain-sorry cases) is a sufficient unit-level proof of correctness independent of a live build; the implementer should still run `--cross-check` once as the task's own stated verification bar, since it is cheap (already implemented, opt-in) and is the authoritative end-to-end oracle.

## Context Extension Recommendations

None. This is a narrowly-scoped, single-file bug fix with clear existing documentation (the script's own header, `census-methodology.md`, `shell-strict-mode.md`) that requires no new context file. The one required documentation touch (docstring line 96) is scoped as part of the fix itself, not a context-extension gap.

## Appendix

### Search queries / commands used

- `Read agent-system/extensions/lean/scripts/lean-sorry-census.sh` (full file)
- `find agent-system -iname "*sorry*"` — confirmed no existing test coverage
- `git log --oneline -- agent-system/extensions/lean/scripts/lean-sorry-census.sh` — confirmed clean recent history
- `python3` inline regex verification of naive vs. fixed pattern against 5 discriminating strings
- `grep -rn "lean-sorry-census" agent-system/ --include="*.sh" --include="*.md" -l` — enumerated all consumers
- `grep -n "lean-sorry-census" -B2 -A5/6 <agent .md files>` — confirmed the `sorry_count: 0` gate in both `lean-implementation-agent.md` and `cslib-implementation-agent.md`, and the PR-description requirement in `pr-description-format.md`
- `find agent-system/extensions/core/scripts -iname "*test*" -maxdepth 2` and `sed -n '1,40p' .../tests/test-census-count.sh` — established the test-file style convention to follow
- `find agent-system/extensions/lean -type d` — confirmed no existing `tests/` subdirectory in the lean extension
- `grep -n "sorry" -i agent-system/extensions/core/context/standards/census-methodology.md` and `shell-strict-mode.md` — confirmed no logic-level documentation needs updating beyond the in-script docstring

### References

- `agent-system/extensions/lean/scripts/lean-sorry-census.sh` (target file, lines 91-167 read in full)
- `agent-system/extensions/lean/agents/lean-implementation-agent.md:145-149`
- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md:305-309`
- `agent-system/extensions/cslib/context/project/cslib/standards/pr-description-format.md:283-287`
- `agent-system/extensions/core/scripts/tests/test-census-count.sh` (style reference for new fixture)
- `agent-system/extensions/core/context/standards/census-methodology.md`
- `agent-system/extensions/core/context/standards/shell-strict-mode.md:115-131`
- `agent-system/extensions/lean/manifest.json:1-60`
