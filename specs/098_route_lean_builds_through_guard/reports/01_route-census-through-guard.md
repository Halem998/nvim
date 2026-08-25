# Research Report: Task #98

**Task**: 98 - Route lean extension builds through the guard and rewrite the multi-instance operations anchor
**Started**: 2026-08-25T16:30:00Z
**Completed**: 2026-08-25T16:36:32Z
**Effort**: 3 hours (from task metadata)
**Dependencies**: 97 (lake-build-guard.sh — complete, shipped)
**Sources/Inputs**: Codebase (agent-system/extensions/{core,lean,nix,nvim}/**), specs/state.json
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The guard (`agent-system/extensions/core/scripts/lake-build-guard.sh`, deployed flat to
  `.claude/scripts/lake-build-guard.sh`) is fully shipped, has zero consumers today
  (`grep -rn lake-build-guard` finds no call sites outside the guard's own file and manifest
  registration), and exposes exactly the `status`/`preflight`/`build` CLI the task description
  promised — verified directly against its source rather than re-derived.
- Deliverable 1's edit site is confirmed unchanged at `agent-system/extensions/lean/scripts/lean-sorry-census.sh`
  lines 181-182 (`BUILD_OUTPUT="$(lake build 2>&1)"` / `BUILD_STATUS=$?`), inside the
  `--cross-check` branch which already has a `command -v lake` graceful-degradation precedent to
  mirror for "guard absent."
- Because extension scripts deploy **flat** into `.claude/scripts/` regardless of source
  extension (confirmed: `lean-sorry-census.sh` and `lake-build-guard.sh` are documented and
  invoked everywhere as siblings under `.claude/scripts/`, even though their source-store homes
  are in different extensions), a `$(dirname "${BASH_SOURCE[0]}")`-relative sibling lookup is the
  correct, CWD-independent way for the census script to find the guard post-deploy — but this
  breaks when the census script is exercised directly from the source store (its own home and the
  guard's own home are NOT siblings in `agent-system/extensions/**`). Recommend an overridable
  test-seam env var (e.g. `LEAN_SORRY_CENSUS_GUARD_BIN`), mirroring the guard's own
  `LAKE_BUILD_GUARD_LAKE_BIN` precedent, so the test suite can inject a fake guard.
- Deliverable 2 (hook decision): the lean manifest currently declares no top-level `hooks` object
  at all (`jq 'has("hooks")'` → `false`) and `provides.hooks: []`. Two extensions already declare
  the top-level object (`nix`: preflight + context_injection; `nvim`: context_injection only),
  giving two live reference shapes, not one. The task text itself pre-flags the strongest
  argument against adding a lean preflight hook: hook resolution keys strictly on
  `task_type == "lean4"` (`skill_get_extension_dir`), so a hook here would not have fired for
  *this task itself* (task_type `meta`) even though this task edits Lean-adjacent files — the
  exact coverage gap named in the task description. Recommend recording "no hook added" as the
  decision, with the reasoning captured verbatim in `multi-instance-optimization.md` itself
  (mechanism doc, not manifest), since hooks are non-blocking (warn-only) and the guard's own
  `preflight` subcommand is already directly invocable without hook machinery.
- Deliverable 3's anchor rewrite has a real coordination dependency: the sibling anchor
  `operations/long-builds.md` is owned by task 66 ("Mandate run_in_background for Lean builds..."),
  which is still `status: researching` (not started/completed) as of this report. This task's
  rewritten `multi-instance-optimization.md` will need to reference `long-builds.md` by path
  before that file necessarily exists on disk — this is fine (it's a forward path reference, not
  a broken link check), but the plan should note it explicitly rather than silently assuming
  task 66 has already landed.
- No other lean-extension file references `multi-instance-optimization.md` by path except
  `index-entries.json` and `context/project/lean4/patterns/mcp-fallback-table.md` — neither is in
  this task's `file_scope`, and neither needs edits since the filename is unchanged.

## Context & Scope

Task 98 integrates the already-shipped `lake-build-guard.sh` into the lean extension across
exactly four files (`file_scope`): `lean-sorry-census.sh`, its test suite, the lean
`manifest.json`, and `operations/multi-instance-optimization.md`. It explicitly excludes the
agent/skill contract text that instructs agents to run `lake build` (owned by task 66) and
excludes any `.claude/**` edits (disposable deploy artifact; source-store rule).

Guardrails carried into this research from the delegation context and confirmed against the
guard's own header comments:
- Lake 5.0.0 has no `-j`/`--jobs` flag; `LEAN_NUM_THREADS` was experimentally falsified as a
  concurrency lever (both facts are recorded as "RECORDED DEAD ENDS" directly in the guard's
  header, lines 34-44) — neither should be proposed here.
- The guard's own file already states its non-goal explicitly at line 15-17: "It does not wire
  itself into any call site... that wiring is separate, dependent work" — this task IS that
  dependent work for the census script specifically.

## Findings

### Codebase Patterns

**Guard CLI, confirmed from `agent-system/extensions/core/scripts/lake-build-guard.sh`:**
```
lake-build-guard.sh status    [--dir DIR] [--verbose]
lake-build-guard.sh preflight [--dir DIR] [--memory-high VAL] [--memory-max VAL] [--verbose]
lake-build-guard.sh build     [--dir DIR] [--timeout SECS] [--memory-bound]
                               [--memory-high VAL] [--memory-max VAL] [--defer-on-pressure]
                               [--no-share] [--verbose] [--] [LAKE ARGS...]
```
- `build` mode passes `lake`'s own exit code through untouched in the normal case; guard-specific
  failures use the reserved band 75-79 (lock-wait timeout=75, deferred-on-pressure=76, usage
  error=77, no Lean project found=78, missing capability e.g. no `lake` on PATH=79). The header
  documents an honest caveat: `lake` itself could in principle also exit 75-79, so a caller that
  needs to disambiguate should call `status`/`preflight` separately — the census script's simple
  capture-and-compare use (numeric match/mismatch report, not a hard gate) does not need that
  disambiguation.
- "silent-when-no-conflict" is a stated design invariant (header line 29-30): on the clean path
  the guard adds zero bytes of its own output, "so it composes safely inside a `$(... 2>&1)` call
  site" — this sentence in the guard's own header is effectively written for this exact call site.
  The one exception: `check_memory_pressure` on the default warn-and-proceed path (no
  `--defer-on-pressure`) prints one stderr line ("memory pressure detected; proceeding anyway...")
  even when it doesn't abort — since the census script currently does `2>&1` combined capture,
  this line lands inside `BUILD_OUTPUT` and would NOT match the `declaration uses 'sorry'` grep,
  so `COMPILER_COUNT` is unaffected, but it is worth a one-line comment in the implementation so a
  future reader isn't surprised by an extra line in captured output under memory pressure.
- Command-substitution compatibility is exactly what makes the guard (not detached invocation) the
  right instrument here, per the guard's own header and the task's own note: `run_in_background`
  cannot return stdout to a shell variable; the flock-based guard's `build` mode runs in the
  **foreground** (see `run_lake_foreground`, no `&` anywhere) and tees to capture files while
  still returning real stdout/stderr/exit-status to the caller, so
  `BUILD_OUTPUT="$(lake-build-guard.sh build -- build 2>&1)"; BUILD_STATUS=$?` is a drop-in shape
  replacement for `BUILD_OUTPUT="$(lake build 2>&1)"; BUILD_STATUS=$?`.
- `--dir DIR` defaults to `$PWD` and is used only to *resolve* the project root (walks up looking
  for `lakefile.lean`/`lakefile.toml`); it does not change lake's own cwd behavior beyond what
  plain `lake build` already does in the census script's existing (undirected) invocation, so no
  `--dir` flag is strictly required for a same-directory invocation — omitting it preserves
  current behavior exactly.

**Deliverable 1 call site, confirmed at `agent-system/extensions/lean/scripts/lean-sorry-census.sh`:**
```
175  if [[ $CROSS_CHECK -eq 1 ]]; then
176    echo ""
177    echo "--- Cross-check: lake build ---"
178    if ! command -v lake >/dev/null 2>&1; then
179      echo "cross_check: unavailable (lake not found in PATH)"
180    else
181      BUILD_OUTPUT="$(lake build 2>&1)"
182      BUILD_STATUS=$?
...
191      if [[ $BUILD_STATUS -ne 0 ]]; then
192        echo "Warning: lake build exited non-zero ($BUILD_STATUS); compiler_sorry_count may be incomplete" >&2
193      fi
194    fi
195  fi
```
The `command -v lake` check (line 178) is the existing graceful-degradation precedent to mirror
for guard-absence: an analogous `[ -x "$GUARD_BIN" ]` (or `command -v`-style) check should guard
the new call, falling through to the current plain `lake build` behavior — never a hard failure —
when the guard is not deployed. `set -uo pipefail` (no `-e`) is already in effect at the top of
the file (line 46), consistent with capturing a non-zero `$?` without the script aborting.

**Sibling-deploy topology (why dirname-relative resolution is the right shape):**
Every reference across the repo to the census script and to sibling core scripts uses a flat
`.claude/scripts/<name>.sh` path regardless of which extension originally provides it — confirmed
via `grep -rn "\.claude/scripts/lean-sorry-census"` (hits in `cslib` agent/context files) and via
`skill-base.sh`'s own `.claude/scripts/events-append.sh` convention. Core's `manifest.json`
`provides.scripts` and lean's `provides.scripts` are both flat basename lists with no
subdirectory nesting for the top-level scripts (only `tests/` and `lib/` are nested
subdirectories, themselves flat within). This confirms `lake-build-guard.sh` and
`lean-sorry-census.sh` land as literal siblings in the deployed `.claude/scripts/` tree even
though their source-store homes (`agent-system/extensions/core/scripts/` vs.
`agent-system/extensions/lean/scripts/`) are not siblings. A
`"$(dirname "${BASH_SOURCE[0]}")/lake-build-guard.sh"` lookup is therefore correct and
CWD-independent post-deploy, but will not resolve when the census script is exercised directly
from its source-store location (as the existing test suite does: `test-lean-sorry-census.sh`
invokes `TOOL_SRC="$SCRIPT_DIR/../lean-sorry-census.sh"` directly against the source tree, not a
deployed tree). This is precisely why a test-seam override is needed, not merely nice-to-have.

**Test-seam precedent, confirmed in `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`:**
The guard's own test suite fabricates a fake `lake` binary on a synthetic `PATH` and points
`LAKE_BUILD_GUARD_LAKE_BIN` at it (env-var override, `:-`-defaulted, "following
claude-refresh.sh's `_pid_is_alive` precedent" per the guard's own header comment at lines 100-101).
The same shape applies directly: introduce e.g. `LEAN_SORRY_CENSUS_GUARD_BIN` (or a name the
planner prefers) as an env-var override for the guard path, defaulted via `:-` to the
dirname-relative sibling lookup, so `test-lean-sorry-census.sh` can point it at a fixture guard
script (or leave it unset/pointed at a nonexistent path to exercise the "guard absent, fall back
to plain `lake build`" branch) without needing a real Lean toolchain or a real `flock`-based
guard run. The existing test suite already fabricates a synthetic `lake` project via `mktemp -d`
and asserts on `sorry_count`/`cross_check` output shape (see Fixture A-E pattern, `pass()`/
`fail()`/`info()` counters, `PASSED`/`FAILED` integers, trap-based cleanup) — the new guard-path
tests should follow that exact house style rather than introducing a second convention.

**Deliverable 2 (hook), confirmed facts:**
- `jq 'has("hooks")' agent-system/extensions/lean/manifest.json` → `false` (no top-level object at
  all today, matching the task description's claim).
- `agent-system/extensions/nix/manifest.json` top-level `hooks`: `{"preflight":
  "scripts/nix-preflight.sh", "context_injection": "scripts/nix-context.sh"}` — full reference
  implementation for a 5-positional-arg (`task_number task_type task_dir session_id operation`)
  hook contract, `set -euo pipefail`, warnings to stderr, always `exit 0`.
- `agent-system/extensions/nvim/manifest.json` top-level `hooks`:
  `{"context_injection": "scripts/nvim-context.sh"}` — context_injection only, no preflight,
  giving a second real precedent that not every extension needs every hook type.
- `skill_run_extension_hook()` in `skill-base.sh` (confirmed): resolves the hook script via
  `skill_get_extension_dir "$task_type"`, which in turn keys strictly on the loaded extension
  whose `task_type` field equals the *task's* `task_type` — i.e. `lean4` — via
  `.claude-extensions.json`'s `loaded_extensions[].task_type`. A task whose own `task_type` is
  `meta` or `general` (even one editing files under `agent-system/extensions/lean/**`, exactly
  like this task) will never resolve the lean extension's hook. This is the coverage caveat the
  task description names, now independently confirmed by reading the resolution function itself
  rather than taking the description's word for it.
- Non-blocking-by-design is also confirmed directly: `"$hook_path" ... || echo "[skill-base]
  WARNING: ... (non-blocking)"` — a non-zero exit is caught and downgraded, never propagated as a
  skill failure.
- No existing lean-extension script currently implements the 5-positional-arg hook contract; if a
  hook is added it would be new work following the `nix-preflight.sh` shape (read `TASK_NUMBER`,
  `TASK_TYPE`, `TASK_DIR`, `SESSION_ID`, `OPERATION` positionally, `set -euo pipefail`, warn to
  stderr on `lake-build-guard.sh preflight` exit 11, `exit 0` unconditionally).

**Deliverable 3 (anchor), confirmed facts:**
- Current `multi-instance-optimization.md` is ~110 lines of human-advisory prose (verified by
  reading the full file): "pause work in 3-4 other sessions", "run `lake build` before starting
  Claude sessions", `htop`/`ps aux --sort=-%mem` monitoring commands, and a results table
  claiming "Memory usage stays under 8GB (vs 16GB+ spikes)" as an *expected result* of following
  the advisory steps.
- That 8GB/16GB figure is directly contradicted by the measurement already on record from the
  guard's own predecessor research (echoed in task 66's description, itself confirmed in
  `specs/state.json`): "16 `lean` processes holding 29.9 GB RSS on a 30 GB machine, 29 GB of swap
  in use, 3.1 GB available" — nearly 4x the anchor's stated ceiling. The rewrite should either
  drop the 8GB figure entirely or explicitly relabel the measured range as illustrative
  (matching the same "MUST NOT be hardcoded as an assumption" instruction task 66 carries for its
  own ~11-minute figure).
- The file's own "Root Cause" and "Monitoring" sections (concurrent `lake build` memory pressure,
  `.olean` file-locking contention, `ps aux --sort=-%mem` / `htop` diagnostics) are diagnostically
  sound and explicitly called out in the task description as content to *preserve*; only the
  "Prevention Strategies" / "Workflow Recommendations" / "Expected Results" sections instruct a
  *person* to do things a *mechanism* (the guard) now does automatically and are the parts that
  need replacing.
- Sibling-anchor coordination: `operations/long-builds.md` does not exist yet on disk (confirmed:
  `find .../operations/` returns only `multi-instance-optimization.md`) and is owned by task 66,
  currently `status: "researching"` in `specs/state.json` (not `completed`). Task 66's own
  description already states the exact interaction that both anchors must jointly document in
  writing: detaching builds via `run_in_background` *without* the guard makes concurrent-build
  memory pressure strictly worse, because the 10-minute foreground cap was incidentally the only
  thing bounding a redundant concurrent build's lifetime. This task's anchor rewrite should state
  that interaction explicitly (task 66's own text is reusable almost verbatim, since it was
  clearly co-drafted with this task's description) and reference `long-builds.md` by path/filename
  without asserting its exact current content, since task 66 may complete before or after this
  task depending on dispatch order.
- No manifest change is needed to register the rewritten anchor: it already lands under the
  existing `provides.context` entry `"project/lean4"` (a directory-level entry, not a per-file
  list) — confirmed present in `agent-system/extensions/lean/manifest.json`'s `provides.context`
  array alongside `"contracts"`.

### External Resources

Not applicable — this is a pure internal-mechanism integration task; no external library or API
research is needed. The guard's own header comment doubles as its authoritative design-rationale
document and was read in full rather than summarized from any external source.

### Recommendations

1. **Census script edit** (lines 178-194 region): add a guard-path resolution step before the
   existing `command -v lake` check — e.g.
   `GUARD_BIN="${LEAN_SORRY_CENSUS_GUARD_BIN:-$(dirname "${BASH_SOURCE[0]:-$0}")/lake-build-guard.sh}"`
   — then branch three ways: (a) `lake` absent → existing `cross_check: unavailable` message,
   unchanged; (b) `lake` present, guard absent/non-executable → fall through to today's plain
   `lake build` invocation (preserves current behavior exactly, satisfies "must not hard-fail
   where the guard has not been deployed"); (c) both present → route through
   `"$GUARD_BIN" build -- build`, capturing combined output/status exactly as today. Keep the
   existing `COMPILER_COUNT`/`MATCH`/`MISMATCH` reporting unchanged in all three branches — the
   guard's build-mode output shape (clean path = zero extra bytes; pressure-warn path = one extra
   stderr line) does not disturb the `declaration uses 'sorry'` grep.
2. **Test suite edit**: add guard-path cases to `test-lean-sorry-census.sh` following its
   established `pass()`/`fail()`/`mktemp -d`/trap-cleanup house style (not the guard's own
   `FAKE_LAKE_*` env-var fixture shape, which is a different script's convention) — at minimum: (i)
   guard absent (default dirname resolution, no `lake-build-guard.sh` present) still produces
   working `cross_check` output identical in shape to pre-integration behavior; (ii) guard present
   via the env-var override, pointed at a synthetic guard stub, correctly threads exit status
   through to `BUILD_STATUS` and the existing non-zero-exit warning; (iii) `lake` itself still
   absent short-circuits to `cross_check: unavailable` regardless of guard presence (existing
   branch, must remain first-checked so it still wins).
3. **Hook decision**: record "no lean preflight/context_injection hook added" as the decision,
   with the reasoning inline in the rewritten `multi-instance-optimization.md` (not buried only in
   a commit message) — the coverage gap (hook keys on `task_type == lean4`, missing exactly the
   `meta`/`general`-typed tasks that also touch Lean files, this task included) plus the
   non-blocking nature of hooks (cannot enforce a refusal; the guard's own internal PSI/swap
   preflight and `--defer-on-pressure` already provide the enforceable mechanism when a caller
   opts in) together make a hook additive-at-best and misleading-at-worst if it implies protection
   it cannot deliver for the majority of task types that could touch a Lean build.
4. **Anchor rewrite structure**: keep "Root Cause"/diagnosis and the `ps`/`htop` monitoring
   commands; replace "Prevention Strategies" and "Workflow Recommendations" with: guard mechanism
   summary (flock serialization + result-sharing + staleness policy; PSI+swap preflight; opt-in
   systemd-run memory bounding); the three subcommands and when a caller would use each; the
   explicit detach-without-guard-makes-it-worse interaction; a forward reference to
   `long-builds.md` by filename; and either drop or explicitly relabel the 8GB/16GB figures as
   illustrative, replacing with (or alongside) the measured 29.9GB/16-process figure.

## Decisions

- No new external dependencies or design mechanisms were introduced by this research; the guard's
  design is treated as ground truth per the delegation context's explicit instruction not to
  re-derive it.
- Recommending the env-var test-seam name `LEAN_SORRY_CENSUS_GUARD_BIN` as a strawman consistent
  with the guard's own `LAKE_BUILD_GUARD_*` naming convention; the planner may choose a different
  name so long as the `:-`-defaulted, dirname-relative-default shape is preserved.
- Recommending "no hook" as the Deliverable 2 outcome, based on the coverage-gap and
  non-enforceability facts confirmed above; this is a recommendation for the plan to adopt or
  override with recorded reasoning, not a foreclosed decision.

## Risks & Mitigations

- **Risk**: `long-builds.md` (task 66, owned separately) may not exist when this task's anchor
  rewrite is implemented, if task 98 is dispatched before task 66 completes.
  **Mitigation**: reference it by filename/path only, describe what it will contain in general
  terms already stated in task 66's own description (foreground-cap livelock, passive progress
  checks), and do not assert exact section headings or line counts from a file that may not exist
  yet. Neither task blocks the other structurally (task 98 does not depend on 66 in
  `specs/state.json`; only both depend on 97).
- **Risk**: a future guard CLI change (flag rename, new subcommand) could silently break the
  census script's integration if the call site hardcodes flag names without a version/compat
  check. **Mitigation**: out of scope to solve here — the guard's own header states its
  "family conventions" (subcommand/exit-code/silent-when-no-conflict shape) as a stability
  contract for future consumers; the census integration should rely on that documented contract
  rather than undocumented behavior.
- **Risk**: the combined `2>&1` capture means a guard-emitted pressure-warning stderr line lands
  inside `BUILD_OUTPUT`, which is not itself a bug (grep is substring-safe) but could confuse a
  future reader diffing raw census output before/after this change.
  **Mitigation**: note it in an inline comment at the call site during implementation.

## Context Extension Recommendations

- **Topic**: cross-extension script sibling resolution (a script in one extension's source store
  needing to invoke a script from a different extension's source store, both landing flat in the
  deployed `.claude/scripts/`).
  **Gap**: no existing pattern doc states the "flat deploy means dirname-sibling lookup works
  post-deploy but not pre-deploy from source store, so use an overridable env-var test seam"
  reasoning explicitly; it was reconstructed here from first principles by reading manifest.json
  `provides.scripts` shapes and the guard's own `LAKE_BUILD_GUARD_LAKE_BIN` precedent.
  **Recommendation**: if a third build-guard family member (e.g. a hypothetical
  `latex-build-guard.sh`, named as a possibility in the guard's own header) or another
  cross-extension script dependency arises, consider promoting this reasoning into a short pattern
  doc under `.claude/context/patterns/` (e.g. `cross-extension-script-dependency.md`) rather than
  re-deriving it a third time.

## Appendix

Search queries / commands used (all local codebase, no web search — task is pure internal
mechanism integration):
- `jq -r '.active_projects[] | select(.project_number==98)' specs/state.json` — full task 98
  description
- `cat -n agent-system/extensions/core/scripts/lake-build-guard.sh` — full guard source (744
  lines) read in full
- `cat -n agent-system/extensions/lean/scripts/lean-sorry-census.sh` — full census script (195
  lines) read in full
- `cat agent-system/extensions/lean/manifest.json`, `jq 'has("hooks")' ...manifest.json`
- `cat agent-system/extensions/lean/context/project/lean4/operations/multi-instance-optimization.md`
  — full current anchor (110 lines) read in full
- `cat -n agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` (partial, house
  style)
- `grep -rn "lake-build-guard" agent-system/` — confirmed zero consumers today
- `grep -n "LAKE_BUILD_GUARD_LAKE_BIN\|FAKE_LAKE" agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`
  — test-seam precedent
- `cat agent-system/extensions/nix/scripts/nix-preflight.sh`, `grep -n '"hooks"' -A5
  agent-system/extensions/nix/manifest.json`, `grep -n '"hooks"' -A5
  agent-system/extensions/nvim/manifest.json` — hook reference implementations
- `grep -n "skill_run_extension_hook\|skill_get_extension_dir" -A 30
  agent-system/extensions/core/scripts/skill-base.sh` — hook dispatch/resolution mechanics
- `jq -r '.active_projects[] | select(.project_number==66)' specs/state.json` — sibling task 66
  full description and status (`researching`, not completed)
- `find agent-system/extensions/lean/context/project/lean4/operations/ -type f` — confirmed
  `long-builds.md` does not exist yet
- `grep -rln "multi-instance-optimization" agent-system/` — confirmed only
  `index-entries.json`/`mcp-fallback-table.md` reference it, neither in file_scope
