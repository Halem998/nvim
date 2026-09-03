# Research Report: Task #20

**Task**: 20 - Fix /todo's repository-metrics sync running pre-commit against phantom (moved/renamed) paths
**Started**: 2026-09-02T00:00:00Z
**Completed**: 2026-09-02T00:00:00Z
**Effort**: medium (two independent script-level defects, one already fixed upstream)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts/assess-repo-health.sh, state-write.sh, commands/todo.md), git history (`git log`/`git show`), live test-suite execution
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Defect A (still open)**: `assess-repo-health.sh` builds its `*.sh`/`*.json` candidate list from
  `git ls-files` with no on-disk existence check. Any path present in the git index but absent on
  disk (an uncommitted rename/move/delete) fails `bash -n`/`jq empty` for the trivial reason that
  there is nothing to parse, and is counted as a structural error. Confirmed by direct code
  reading at `agent-system/extensions/core/scripts/assess-repo-health.sh:144-173`.
- **Defect B (still open, same root cause as A)**: `commands/todo.md` Step 5.6 (line 790) calls
  the probe after Step 5D's directory moves (line 574-608) and Step 5.7's vault operation, but
  before Step 6's commit (line 941-954) — the exact tree state that triggers Defect A's phantom
  counting, every time `/todo` archives anything with a directory.
- **Defect C (already fixed, no further work needed)**: the delegation message's second reported
  defect — Step 5A's `--argjson tasks "$archivable_tasks_json"` exceeding Linux's 131,072-byte
  `MAX_ARG_STRLEN` on large archive batches — was fixed by commit `67876e6b3` ("Fix 128KB argv
  ceiling in roadmap-integration.sh and state-write.sh"), which is already an ancestor of the
  current `HEAD`/branch tip. `state-write.sh` now transparently spills any `--argjson` value over
  100,000 bytes to a private `mktemp` file bound via `jq --slurpfile`, with **no caller-side
  change required** — Step 5A's call site is unmodified and automatically benefits. Verified live:
  `agent-system/extensions/core/scripts/test-state-write-large-payload.sh` passes 7/7 against a
  200,001-byte payload exceeding the ceiling; `agent-system/extensions/core/scripts/tests/test-roadmap-argv-ceiling.sh`
  passes 5/5.
- **Other callers**: `commands/todo.md` (Step 5.6, line 790) is the *only* production call site of
  `assess-repo-health.sh` in the entire `agent-system/extensions/**` tree — confirmed by
  `grep -rln "assess-repo-health" agent-system/`, which returns only `commands/todo.md`, the
  script itself, its test file, and `manifest.json`/inventory docs. No other caller carries this
  pre-commit exposure, so item 3 of the delegated work is resolved by observation: nothing else to
  fix.
- Recommended fix shape for A+B below; both are required together (the delegation message is
  correct that fixing A alone still leaves a pre-commit measurement describing a tree about to
  change, and fixing B alone does not stop a *concurrent* uncommitted rename from still inflating
  the count).

## Context & Scope

Task 20 was created 2026-08-10; the state-write.sh argv-ceiling fix (commit `67876e6b3`) landed
2026-08-25, after task creation but before this research pass — this explains why the delegation
message's live reproduction (which predates or is contemporaneous with that fix landing) still
describes the failure, while the current tree no longer exhibits it. This report treats Defect C
as closed and focuses the remaining research and fix-shape recommendation on Defects A and B.

## Findings

### Codebase Patterns

**Defect A — `enumerate_by_glob` / structural-check loops
(`agent-system/extensions/core/scripts/assess-repo-health.sh`)**:

```
144  enumerate_by_glob() {
145    local glob="$1"
146    if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
147      git -C "$ROOT" ls-files -z -- "$glob" 2>/dev/null | while IFS= read -r -d '' rel; do
148        printf '%s/%s\0' "$ROOT" "$rel"
149      done
150    else
151      find "$ROOT" -type f -name "$glob" -not -path '*/.git/*' -print0 2>/dev/null
152    fi
153  }
...
159  errors=0
160  for f in "${SH_FILES[@]}"; do
161    [ -n "$f" ] || continue
162    if ! bash -n "$f" >/dev/null 2>&1; then
163      errors=$((errors + 1))
164    fi
165  done
```

`git ls-files` reads the **index**, not the worktree. A path that was `mv`'d on disk but never
`git add`'d is still emitted by `git ls-files` at its old location (now nonexistent on disk) and
is *not yet* emitted at its new location. The guard at line 161 (`[ -n "$f" ] || continue`) checks
only for an empty string, never for existence, so `bash -n "$f"` on a nonexistent path fails
(nothing to parse) and increments `errors`. The same shape repeats for `JSON_FILES` at
lines 166-171. `total_candidates` (line 173) is built from the same phantom-inflated arrays, which
also perturbs the null/"unknown" degenerate-case branch (lines 174-183) when every real candidate
happens to be phantom.

This is **caller-independent**: the probe is wrong on its own terms for *any* uncommitted rename,
delete, or move under `--root`, not merely when called by `/todo` specifically. `/todo`'s Step 5D
is simply the call site most likely to trigger it, at scale, every run.

Live-run evidence already gathered by the requester (not re-derived here, since both are
one-shot production runs I cannot safely replay against this working tree): 89 phantom-inflated
`build_errors` (88 phantom, 1 real) on a 20-task archive, and 184/184 phantom on a 25-directory
archive — in both cases the identical probe re-run immediately after `git add specs/` + commit
reported the true count.

**Defect B — sequencing in `commands/todo.md`**: confirmed by direct read of the command file.
Step 5D (directory `mv`, lines 574-608) and Step 5.7 (vault operation, lines 814-940, itself doing
further `mv`s at lines 866-869) both run before Step 5.6 (Sync Repository Metrics, lines 779-813,
probe call at line 790), which in turn runs before Step 6 (Git Commit, lines 941-954, the first
point at which `specs/` is staged via `git-commit-scoped.sh`). The probe therefore always measures
a tree whose git index has not yet caught up with Step 5D's moves.

**Defect C — already fixed (`state-write.sh`, commit `67876e6b3`)**:

```
150  # --- Oversized --argjson transparent spill (D1/D2: report Shape 2, threshold below MAX_ARG_STRLEN) ---
155  SPILL_THRESHOLD=100000
...
199      if [ "${#3}" -gt "$SPILL_THRESHOLD" ]; then
200        spill_file=$(mktemp "$TMP_DIR/state-write-spill.XXXXXX") || { ... }
204        printf '%s' "$3" > "$spill_file"
...
206        JQ_ARGS+=(--slurpfile "$private_name" "$spill_file")
```

Any `--argjson NAME VALUE` over 100,000 bytes (below the 131,072-byte `MAX_ARG_STRLEN` ceiling) is
transparently rewritten to a `--slurpfile` binding against a private `mktemp` file; the caller's
own `$NAME` reference in its jq filter resolves unchanged via an `EFFECTIVE_FILTER` prefix
(lines 269-280). Step 5A's call site (`commands/todo.md:534-541`,
`--argjson tasks "$archivable_tasks_json"`) is untouched by this fix and needs no edit — it
already benefits automatically, exactly as the commit's own message states ("no existing or
future `--argjson` call site has to change"). I ran both regression suites live against the
current tree rather than trusting the commit message alone:

```
$ bash agent-system/extensions/core/scripts/test-state-write-large-payload.sh
... 7 passed, 0 failed
$ bash agent-system/extensions/core/scripts/tests/test-roadmap-argv-ceiling.sh
... 5 passed, 0 failed
```

Both suites include cases at/above the 131,072-byte ceiling (a 200,001-byte file, a 203,890-byte
file, a 150,033-byte spilled binding) and both pass. Defect C requires no further work under this
task; note it in the eventual plan as "already resolved by commit 67876e6b3" so the plan doesn't
re-open it.

### External Resources

None consulted — this is a pure codebase-internal defect with no external API/library surface.

### Recommendations

**Fix 1 (Defect A, existence-safety in the probe) — recommended shape**:

Filter phantom candidates at the single choke point where `SH_FILES`/`JSON_FILES` are populated
(`assess-repo-health.sh:155-156`, right after the two `mapfile` calls), not inside the later loops
individually — `total_candidates` (line 173), the structural-check loops (lines 159-171), and any
future consumer of these arrays all then automatically see only real, on-disk paths, from one
place. `count_marker()`'s own `enumerate_by_glob` calls (lines 187-199, used for TODO/FIXME
counting) are unaffected by design: `grep -c` against a nonexistent path already fails silently
and is coalesced to 0 via the existing `c="${c:-0}"` (line 194), so TODO/FIXME counts are already
existence-safe and need no change — only the two structural arrays need filtering.

**Decision — surface phantom paths as a diagnostic count, do not silently skip them.** Silently
dropping phantom candidates would fix the false-positive `build_errors` inflation but would also
erase the one piece of information a phantom path actually carries: that the git index and
worktree have diverged at the moment of assessment. That divergence is expected and benign
mid-`/todo`-run (Defect B's normal operating state before the fix below lands), but would be a
genuinely surprising signal in any *other* context this probe runs in (a human running it ad hoc
against a dirty tree, or a future caller this section's "Other callers" finding did not
anticipate). The script's own existing design philosophy already treats "don't know" as
first-class rather than guessing (`build_errors: null` for the zero-candidate case, documented at
lines 38-41 of the script's own header) — a `phantom_paths` (or similarly named) integer count
sitting alongside `build_errors` is the same pattern applied one level down, not a new one.
Concretely: `state-schema.json`'s `repository_health` object (`context/schemas/state-schema.json`)
has `additionalProperties: false`, so this requires an explicit new property added to that
sub-schema (not just the top-level `KNOWN_TOP_LEVEL_FIELDS` list in `validate-state.sh`, which
only guards `repository_health` as a whole, not its inner shape) — a small, contained schema
change, not a compatibility break for existing consumers who simply won't read the new field.

**Fix 2 (Defect B, re-sequencing) — recommended shape**: move Step 5.6 to run *after* Step 6's
commit, as its own follow-up step, immediately followed by a second, narrowly-scoped
`git-commit-scoped.sh` call covering only `specs/state.json` (message e.g. `"todo: sync
repository metrics"`). Rationale for this over the alternative ("have Step 6 re-sync afterward",
i.e. folding the probe into Step 6 itself): `git-commit-scoped.sh` is documented as "the single
sanctioned implementation of path-scoped, mutex-serialized committing (never a bare `git add` plus
a bare `git commit`)" and performs stage+commit as one atomic call — there is no supported
"stage only, don't commit yet" mode to run the probe against a staged-but-uncommitted tree without
either editing that script's contract or hand-rolling a `git add` (itself against
`no-task-references`-adjacent conventions this codebase already avoids elsewhere). Running the
probe strictly after Step 6's commit sidesteps that entirely: by the time it runs, `git ls-files`
already reflects every moved/renamed path from Step 5D and Step 5.7, so Defect A's existence gap
is never triggered by `/todo`'s own operation regardless of whether Fix 1 has landed — though Fix
1 is still required independently, per the delegation message's own instruction not to rely on
either fix alone, since a *concurrent* session's uncommitted rename elsewhere in the tree is not
addressed by re-sequencing `/todo`'s own steps. The two-commit result (archive commit, then a
small metrics-only commit) is also arguably a cleaner fit for `git-commit-scoped.sh`'s own
`--honest-index-rows` philosophy of not sweeping unrelated changes into one commit — cleaner, in
fact, than the current single archival commit, which the delegation message already noted
legitimately opts out of that flag because it spans many tasks' rows at once; a metrics-only
commit needs no such opt-out since it touches nothing task-scoped.

## Decisions

- Defect C (Step 5A argv-ceiling) is closed by an already-landed upstream fix (commit
  `67876e6b3`); no plan/implementation work should re-touch `commands/todo.md` Step 5A or
  `state-write.sh` for this. Confirmed via live execution of both associated regression suites on
  the current tree, not from the commit message alone.
- Phantom-path filtering belongs at the `SH_FILES`/`JSON_FILES` population site
  (`assess-repo-health.sh:155-156`), not inside each downstream loop, so every current and future
  consumer of those arrays is existence-safe from one place.
- Phantom paths are surfaced as a new diagnostic field on `repository_health` (schema change
  required in `state-schema.json`), not silently dropped — an index/worktree divergence is a
  signal worth keeping, per the script's own established "explicit unknown over guessing" pattern.
- Step 5.6 moves to run after Step 6's commit, followed by its own narrowly-scoped
  `git-commit-scoped.sh` call for `specs/state.json` only, rather than folding metrics-sync into
  Step 6's existing commit call — avoids any change to `git-commit-scoped.sh`'s stage+commit-atomic
  contract.
- No other caller of `assess-repo-health.sh` exists in the codebase; item 3 of the delegated work
  is resolved by this confirmed absence, requiring no code change.

## Risks & Mitigations

- **Risk**: adding a `phantom_paths` field to `repository_health` is a schema change with
  `additionalProperties: false` guarding it — a plan that adds the field to the probe's JSON
  output but forgets the schema update will make every subsequent `validate-state.sh --deep` run
  fail. **Mitigation**: the plan phase must treat the schema edit and the probe edit as one
  atomic unit of work, and the existing `test-assess-repo-health.sh` enum-conformance case
  (lines 111-120) is a ready-made pattern to extend for the new field.
- **Risk**: the two-commit re-sequencing (Fix 2) means a `/todo` run that fails between Step 6 and
  the new metrics-commit step leaves an archived-but-metrics-stale tree. **Mitigation**: this is
  strictly better than today's behavior (today's single commit can already carry *wrong* metrics
  baked in permanently), and the next `/todo` invocation's Step 5.6 will simply recompute and
  produce a fresh, correct commit — no state is lost, only a metrics update is deferred one run.
- **Risk**: a fixture-driven regression test for Defect A needs an actual git work tree (unlike
  the existing `test-assess-repo-health.sh` suite, which deliberately uses non-git `mktemp -d`
  fixtures to exercise the `find` fallback, per that file's own header note at lines 26-29) —
  a new case must `git init`/`git add`/`git commit` a fixture, then `mv` a tracked file without
  staging, to reproduce the index/worktree divergence at all. **Mitigation**: this is a new,
  clearly-scoped fixture (a third kind, alongside the existing non-git ones), not a rewrite of the
  existing suite's structure — `pass()`/`fail()`/`info()` helpers and the PASSED/FAILED counters
  are directly reusable.

## Regression Lock (for the plan/implementation phase)

Add a new case to `agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh`:
build a **git** fixture (`git init`, add a tracked `*.sh` with valid syntax, `git commit`), then
`mv` that tracked file to a new path **without staging the move**, then run the probe with
`--root` pointing at the fixture. Assert `build_errors == 0` and `status == "healthy"` — proving
the moved-away path contributes zero errors. Combine this in the same fixture with a second,
genuinely broken tracked `*.sh` (syntax error, left in place, not moved) to prove the fix does not
regress into "always reports zero" — `build_errors` must equal exactly 1 (the real defect), not 0
and not 2 (i.e., the phantom must not be silently double-counted either). This dual-assertion
shape mirrors the existing suite's own "Bar 1 vs. clean control" pairing (lines 8-13) that already
guards against a probe that always reports failure regardless of input — apply the same discipline
in the opposite direction (a probe that always reports success regardless of input).

## Context Extension Recommendations

- **Topic**: git-index-vs-worktree divergence as a general enumeration hazard.
- **Gap**: `context/standards/census-methodology.md` (the closest existing doc, covering
  `census-count.sh`'s enumeration conventions) does not currently document the existence-check
  requirement for any `git ls-files`-based enumerator. `census-count.sh` itself was checked
  (`grep -n "existence\|-f \"\$..." census-count.sh`) and has no existence-check pattern either —
  it is not an affected caller today only because nothing currently feeds it a mid-move tree, not
  because it is structurally immune.
- **Recommendation**: after this task's fix lands, add a short subsection to
  `context/standards/census-methodology.md` documenting the existence-check requirement for any
  future `git ls-files`-based enumerator in this codebase, using `assess-repo-health.sh`'s fixed
  version as the worked example. Out of scope for this task's own fix, noted here for a possible
  follow-up task.

## Appendix

Commands run:
- `grep -rn "assess-repo-health.sh"` / `grep -rln "assess-repo-health"` across `agent-system/` and
  `.claude/` — confirmed `commands/todo.md` as the sole production caller.
- `git log --oneline -5 -- .../state-write.sh`, `git show --stat 67876e6b3`,
  `git merge-base --is-ancestor 67876e6b3 HEAD` — confirmed the argv-ceiling fix is already merged.
- `bash agent-system/extensions/core/scripts/test-state-write-large-payload.sh` — 7/7 pass.
- `bash agent-system/extensions/core/scripts/tests/test-roadmap-argv-ceiling.sh` — 5/5 pass.
- `bash agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh` — 11/11 pass
  (pre-existing suite, unaffected by Defect A since all its fixtures are non-git and therefore
  never exercise `git ls-files`).
- `python3 -c "... state-schema.json repository_health ..."` — confirmed
  `additionalProperties: false` on the sub-object, so a new diagnostic field needs an explicit
  schema property, not just a probe-side emission.

References:
- `agent-system/extensions/core/scripts/assess-repo-health.sh`
- `agent-system/extensions/core/scripts/state-write.sh`
- `agent-system/extensions/core/commands/todo.md` (Steps 5, 5D, 5.6, 5.7, 6)
- `agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh`
- `agent-system/extensions/core/scripts/test-state-write-large-payload.sh`
- `agent-system/extensions/core/scripts/tests/test-roadmap-argv-ceiling.sh`
- `agent-system/extensions/core/context/schemas/state-schema.json`
- `agent-system/extensions/core/scripts/git-commit-scoped.sh`
