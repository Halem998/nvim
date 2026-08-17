# Research Report: Task #61

**Task**: 61 - Surface coarse and duplicate file_scope declarations at task-creation time
**Started**: 2026-08-17T00:00:00Z
**Completed**: 2026-08-17T00:00:00Z
**Effort**: 3-5 hours (estimate)
**Dependencies**: Task #59 (completed — evidence-gated admission predicate)
**Sources/Inputs**: Codebase exploration (validate-state.sh, task.md, file-scope-overlap.sh,
  file-footprint-overlap.md, batch-orchestration-guardrails.md, batch-admit-schema.md,
  meta-builder-agent.md, multi-task-creation-standard.md), live specs/state.json data
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `file_scope` is currently populated only by multi-task creators (`/meta`'s Component 4a,
  `/fix-it`, `/spawn`) — the single-task `/task` Create Task Mode in `commands/task.md` never
  sets it. This task's job is not "check the newly created task's own scope" but "run a cheap,
  reusable declaration-quality scan of the whole `active_projects[].file_scope` population at
  the natural checkpoint of any `/task`-driven state.json write," which also catches
  already-present coarse/duplicate entries like the live one below.
- A live, concrete example of the exact defect already exists in this repo: task 44
  (`slim_task_command_body`, not_started) declares
  `agent-system/extensions/core/context/` as one of its two `file_scope` entries — a
  near-top-level directory with a measured overlap footprint of 8 distinct other non-terminal
  tasks (13 raw entry-level overlap hits: `53, 9, 17, 17, 17, 28, 29, 48, 50, 50, 60, 60, 60`).
  No task in this repo currently has an exact-duplicate `file_scope` entry (unlike the
  BimodalLogic `FormalSystem/` ×2 motivating example), so the duplicate-detection half has no
  live regression fixture in *this* repo and should be tested via a synthetic fixture.
- Recommended split: (a) a reusable jq predicate in `validate-state.sh` that flags
  directory-shaped, near-top-level `file_scope` entries and reports blast radius by reusing
  (not re-deriving) the existing `scripts/lib/file-scope-overlap.sh` overlap predicate; (b) a
  new WARN-level (never FAIL-level) base-mode check in `validate-state.sh`; (c) a new advisory
  step in `commands/task.md`'s Create Task Mode, inserted between Step 6 (state-write) and
  Step 7 (git commit), that invokes the deployed `validate-state.sh` and surfaces `[WARN]`
  lines inline. `validate-state.sh` currently has exactly one caller
  (`verify-deploy.sh` Gate 10, deploy-time only) — `task.md` would be the first
  interactive/creation-time caller.
- Because `verify-deploy.sh`'s Gate 10 treats validate-state.sh's exit code as the pass/fail
  signal (0 = pass, including WARN-only runs; nonzero = FAIL-level finding present), the new
  checks **must** use `log_warn`, never `log_fail` — this is the mechanical enforcement of the
  task's "advisory, not blocking" requirement, not just a style preference.

## Context & Scope

Researched how `file_scope` declarations are produced and validated today, where the "coarse
declaration" concept already exists in a narrower form (self-modification detection), and how
to add a general-purpose, non-blocking advisory for whole-directory-root and duplicate
`file_scope` entries at the two declared file_scope sites: `scripts/validate-state.sh` and
`commands/task.md`.

Task #59 (the predicate fix this task's description calls "the predicate task") is already
`completed` in current state.json, and its "workaround-edge removal" cleanup step appears to
have already run — none of the specific bare `commands/`/`skills/` collisions described in this
task's delegation context are present in the live state.json anymore. Task #60 (consumer
threading) is still `not_started`, depends on #59. This task depends only on #59, which is
satisfied.

## Findings

### Codebase Patterns

**`file_scope` field semantics** (`context/reference/state-management-schema.md` line 264,
`rules/state-management.md` "File Scope" section): optional, array of strings, prospective
(not filesystem-validated), "set at creation time," used to detect same-file overlap between
sibling tasks and derive serializing `dependencies[]` edges. Contrasted with retrospective
`modified_files`/`files_touched`.

**Who actually populates it today**: `docs/reference/standards/multi-task-creation-standard.md`
Component 4a ("File Footprint Capture and Overlap Detection") is the canonical population site,
implemented by `meta-builder-agent.md` (keyword-to-directory inference), `/fix-it`
(tag `file:line` locations), and `/spawn` (blocker/codebase research paths). **`commands/task.md`
Create Task Mode (Steps 1-8) has no `file_scope` handling at all** — confirmed by exhaustive
grep; Step 6's `state-write.sh` jq filter that creates the new `active_projects[]` entry omits
`file_scope` entirely, so new single-task entries get the schema default `[]`. This means this
task's `task.md` work is inherently about **surfacing pre-existing declaration-quality problems
already sitting in state.json**, not about validating a field `/task` itself sets — matching the
task description's own framing ("this task alone does nothing about the declarations already
sitting in state," implying the mechanism should reach existing declarations, not just new ones).

**An existing, narrower "coarseness" diagnosis already exists** —
`scripts/orchestrate-predispatch-review.sh` Class C (lines 368-384) computes `coarse: true/false`
for self-modification verdicts by comparing a candidate's matched `file_scope` entry against
`context/reference/orchestrator-critical-paths.json`'s declared `critical_paths` list (relative
to `scope_roots`: `agent-system/extensions/core`, `.claude`, `.opencode`). This is a **different,
narrower** mechanism than what this task needs: it only fires when a task's scope collides with
one of ~15 hardcoded orchestrator-critical files, not for general whole-directory-root
declarations against arbitrary sibling tasks. Do not conflate or reuse Class C's code path
directly — the new check is general-purpose (any task vs. any other non-terminal task), Class C
is self-modification-specific (any task vs. a fixed critical-path registry). They should remain
independent, though both ultimately rest on the same normalize/overlap primitives.

**The one true source of the overlap predicate**: `scripts/lib/file-scope-overlap.sh` exports
`scopes_overlap()` (bash-callable, single pairwise comparison via `jq -n`) and
`FILE_SCOPE_OVERLAP_JQ_DEFS` (raw jq `def` text for splicing into a larger single-pass `jq -n`
program). Its header is explicit: "the only place the algorithm's logic is written down as
code — every consumer sources this file... rather than re-deriving or restating the rule
locally." The canonical prose lives in `context/patterns/file-footprint-overlap.md` (path
normalization strips trailing `/`; overlap = exact match OR either side is a directory-prefix
ancestor of the other). **Any new blast-radius computation must splice/source this file, not
reimplement the normalize-and-compare logic inline** — this is a hard repo convention with
existing enforcement precedent (the header comment plus the "Consumers" section listing every
caller).

**Terminal vs. non-terminal status** (`rules/state-management.md` "Status Transitions"):
terminal states are exactly `completed`, `abandoned`, `expanded`. All 9 remaining
`status-vocabulary.sh` enum values (`not_started`, `researching`, `researched`, `planning`,
`planned`, `implementing`, `pr_ready`, `blocked`, `partial`) are non-terminal. "Blast radius"
per the task description ("how many existing non-terminal tasks the declaration would overlap")
should filter `active_projects[]` to non-terminal status before counting overlaps — mirroring
exactly the filter `orchestrate-batch-admit.sh`'s state.json collision dimension already uses
(per `batch-admit-schema.md` and task #59's own description).

**`validate-state.sh` structure** (535 lines): base-mode Checks 1-7 run unconditionally
(JSON parsability, required/unknown top-level fields, unknown per-entry fields, status enum
membership, numeric `project_number`, non-empty `task_type`) — **all seven are PASS/FAIL only;
base mode currently emits zero WARN-level output**. `--deep` adds git-history-dependent Checks
D1-D5 (uniqueness, TODO.md sync, dependency-graph integrity/cycles, terminal-status immutability,
per-type artifact-loss). The new coarse/duplicate checks need only `active_projects[].file_scope`
and `.status` — no git history — so they belong as new **base-mode** checks (not `--deep`),
keeping them fast and always-available (in particular, usable from `task.md` without requiring
a `--deep` git-history round trip). They should use `log_warn` (the function already exists,
lines 188), never `log_fail`, per the "advisory, not blocking" requirement and to preserve
`verify-deploy.sh` Gate 10's exit-code-based pass/fail contract (Gate 10 treats validate-state.sh
exit 0 — which covers both a clean pass and a WARN-only run — as passing; only exit 1, i.e. at
least one FAIL-level finding, fails the deploy gate). **This is a hard mechanical constraint, not
a style preference**: a `log_fail` here would silently start failing every deploy the moment any
existing task (e.g. #44 today) carries a coarse declaration.

**Only one existing caller of `validate-state.sh`**: `scripts/verify-deploy.sh` Gate 10, which
runs `--deep` against the *deployed* tree's `specs/state.json` at deploy time only — never
interactively. `commands/task.md` would become the **first creation-time/interactive caller**,
a genuinely new integration point, not an extension of an existing one.

**Repair-flag precedent**: `validate-return-meta.sh --fix` (bare-string artifact promotion) and
`validate-artifact.sh --fix` are the two existing "detect, then optionally auto-repair"
scripts in this codebase. Both are opt-in only, never implicit, and rewrite-then-revalidate
atomically. `orchestrate-predispatch-review.sh --repair` is the analogous pattern for
`dependencies`/`file_scope` null-field normalization. The task description's "detect and
de-duplicate" (work item 2) is a mechanically unambiguous, always-safe transform (drop
duplicate array elements, preserve first-occurrence order) — a natural `--fix`-style flag on
`validate-state.sh` fits this precedent better than folding dedup into every writer.

**No test coverage in the declared scope**: `scripts/tests/test-validate-state.sh` (487 lines)
is the existing fixture-driven regression suite for `validate-state.sh` (four seeded-defect
fixtures + one positive fixture, `pass()`/`fail()`/`info()` helper pattern) — but it is **not**
in this task's declared `file_scope` (only `scripts/validate-state.sh` and `commands/task.md`
are declared). New checks will need fixtures; flag this as a likely necessary minor `file_scope`
extension for the planner to make explicit (low collision risk — no other active task currently
declares this test file).

**Related site intentionally out of scope**: `agents/meta-builder-agent.md` Component 4a
is where `file_scope` actually gets populated for most tasks today (via `/meta`), and would
benefit from the same coarse/duplicate advisory at proposal time. It is not in this task's
declared `file_scope` and should not be touched — note it as a natural follow-up rather than
silently expanding scope.

### External Resources

Not applicable — this is a pure in-repo mechanism/convention task (task_type: meta), no external
library or API involved.

### Recommendations

1. **Shared detection logic**: add a new jq predicate that, for each `active_projects[]` entry
   with a non-empty `file_scope`, (a) flags directory-shaped near-top-level entries and (b)
   computes blast radius by splicing `FILE_SCOPE_OVERLAP_JQ_DEFS` (or calling `scopes_overlap()`)
   from `scripts/lib/file-scope-overlap.sh` against every *other* non-terminal task's
   `file_scope` — reusing, never re-deriving, the canonical overlap predicate.
2. **Open design decision to resolve in planning**: how to define "bare top-level or near-top-level
   directory" structurally. Two candidate approaches, both defensible:
   - **(a) Depth heuristic**: count path segments after normalization: use a small threshold
     (repo examples: task 44's `agent-system/extensions/core/context/` is 4 segments; the
     BimodalLogic `FormalSystem/`/`docs/` examples are 1 segment). A single depth threshold is
     hard to make repo-shape-agnostic (a monorepo like this one nests everything under
     `agent-system/extensions/core/`, a small repo does not) — do **not** hardcode
     `orchestrator-critical-paths.json`'s `scope_roots`, since that list is a different,
     self-modification-specific feature with no general applicability guarantee.
   - **(b) Blast-radius-driven trigger** (recommended): treat any `file_scope` entry that (i) is
     declared directory-shaped (ends with `/` in the *original*, pre-normalization string — this
     matches how every motivating example is actually written: `"FormalSystem/"`, `"docs/"`,
     `"commands/"`) **and** (ii) overlaps at least N other non-terminal tasks (N=1 or 2 is a
     reasonable default, tunable) as coarse. This ties the trigger directly to the task's own
     stated rationale ("a warning that names the concrete blast radius... rather than a generic
     caution") rather than an arbitrary path-depth guess, and naturally excludes narrow,
     legitimately-scoped directory declarations (e.g. one task owning
     `skills/skill-orchestrate/` alone, which nothing else currently overlaps).
   Recommend (b), with the trailing-`/` structural pre-filter from (a) retained as a cheap first
   pass to avoid computing blast radius for ordinary file paths.
3. **`validate-state.sh`**: add as new base-mode Check 8 ("whole-directory-root `file_scope`
   declarations") and Check 9 ("duplicate `file_scope` entries"), both `log_warn`-only. Check 9
   is a straightforward per-entry `.file_scope | length != (unique | length)` test — already
   confirmed to produce zero hits against the live state.json, so it's safe to add without
   surfacing pre-existing noise.
4. **`--fix`-style repair** (optional but recommended, mirroring `validate-return-meta.sh --fix`):
   a flag that removes exact-duplicate `file_scope` entries in place (order-preserving, first
   occurrence kept), opt-in only, never implicit. Do not attempt to auto-repair coarse
   declarations — narrowing a directory scope requires human judgment about what the task
   actually touches, unlike duplicate removal which is unambiguous.
5. **`commands/task.md`**: insert a new advisory step between Step 6 (`state-write.sh` call) and
   Step 7 (git commit) — call it Step 6.5 — that invokes the deployed
   `.claude/scripts/validate-state.sh` (base mode, no `--deep`, for speed — no git-history
   dependency exists for these checks) against `specs/state.json` and surfaces any `[WARN]`
   lines from the new checks inline as part of the command's output, using language consistent
   with the repo-wide "advisory never means unlogged or silent" phrasing already established in
   `context/patterns/batch-orchestration-guardrails.md` (line 76) and echoed in task #60's own
   description. This surfaces pre-existing declaration-quality problems (like task 44's today)
   at the next natural checkpoint — any `/task` invocation — without requiring `/task` itself to
   ever collect `file_scope` for the task being created.
6. **Never block task creation**: Step 7 (git commit) and Step 8 (Output) proceed unconditionally
   regardless of what Step 6.5 finds — this is the literal mechanical expression of "advisory at
   creation time, not blocking."

## Decisions

- New checks belong in `validate-state.sh` base mode (not `--deep`): no git dependency needed,
  keeps them fast/always-available, and lets `task.md` invoke them without a git-history round
  trip.
- New checks MUST use `log_warn`, never `log_fail`, to satisfy both the task's explicit
  "advisory, not blocking" requirement and to avoid silently turning `verify-deploy.sh` Gate 10
  into a hard blocker on every pre-existing coarse declaration (e.g. task 44 today).
- Blast-radius computation must reuse `scripts/lib/file-scope-overlap.sh`'s
  `FILE_SCOPE_OVERLAP_JQ_DEFS`/`scopes_overlap()`, never re-derive the normalize/overlap logic —
  this is an explicit, enforced repo convention (the library file's own header statement plus
  its "Consumers" list in `file-footprint-overlap.md`).
- `commands/task.md`'s new advisory step targets the *whole* `active_projects[]` population
  (post-write), not just the newly created task's own `file_scope` — because Create Task Mode
  never sets `file_scope` for the new task itself, and the task's motivating framing is about
  surfacing declarations "already sitting in state," not only freshly authored ones.

## Risks & Mitigations

- **Risk**: a coarse/duplicate check accidentally implemented as `log_fail` breaks
  `verify-deploy.sh` Gate 10 against the live state.json (task 44's declaration would trip it
  today). **Mitigation**: use `log_warn` exclusively for both new checks; add a regression
  fixture in `test-validate-state.sh` asserting exit 0 despite a seeded coarse/duplicate
  fixture.
- **Risk**: reimplementing the overlap/normalize logic inline in `validate-state.sh` instead of
  sourcing `scripts/lib/file-scope-overlap.sh` creates a second, drifting copy of the predicate.
  **Mitigation**: source the library (matching `task-lock.sh`'s existing consumption pattern) or
  splice `FILE_SCOPE_OVERLAP_JQ_DEFS` into the check's own `jq` program (matching
  `orchestrate-batch-admit.sh`'s pattern).
- **Risk**: `test-validate-state.sh` is outside this task's declared `file_scope`, so new
  fixtures either can't be added without a scope amendment, or get skipped, leaving the new
  checks untested. **Mitigation**: flag explicitly for the planner to either extend
  `file_scope` (low collision risk — no other active task currently declares this file) or
  document the gap if the scope must stay exactly as declared.
- **Risk**: an overly aggressive depth/blast-radius threshold produces WARN noise on every
  `/task` invocation once any coarse declaration exists in state (e.g. task 44 today), degrading
  the signal. **Mitigation**: prefer the blast-radius-driven trigger (recommendation 2b) over a
  bare depth heuristic, and keep the threshold conservative (N>=1 or N>=2 overlapping
  non-terminal tasks) with the exact count always printed, per the task's own "concrete blast
  radius... rather than a generic caution" requirement.

## Context Extension Recommendations

- **Topic**: whole-directory-root / duplicate `file_scope` declaration-quality heuristics.
- **Gap**: `context/patterns/file-footprint-overlap.md` canonically defines the *overlap*
  predicate but has no section on *declaration-quality* heuristics (coarseness, duplication).
  `orchestrate-predispatch-review.sh`'s Class C coarseness diagnosis is self-modification-scoped
  only and not documented as a general pattern.
- **Recommendation**: once implemented, add a short "Declaration Quality" subsection to
  `file-footprint-overlap.md` (or a new sibling pattern doc) defining the blast-radius-driven
  coarseness trigger and duplicate-detection rule as the canonical, reusable definition —
  mirroring how the overlap predicate itself is defined once and referenced everywhere. This
  would also let the out-of-scope `meta-builder-agent.md` Component 4a site (noted above) adopt
  the same check later without re-deriving it.

## Appendix

### Search queries / commands used

- `grep -rl "file_scope" agent-system/extensions/core` — full consumer inventory
- `grep -rn -i "coarse" agent-system/extensions/core` — located existing Class C coarseness
  diagnosis in `orchestrate-predispatch-review.sh` and its schema documentation in
  `batch-admit-schema.md`
- Live blast-radius computation against `specs/state.json` for task 44's
  `agent-system/extensions/core/context/` entry (jq, reusing the `norm`/overlap predicate
  shape) — result: 8 distinct overlapping non-terminal tasks, 13 raw entry-level hits
  (`53, 9, 17×3, 28, 29, 48, 50×2, 60×3`)
- Duplicate-entry scan across all `active_projects[].file_scope` — zero hits in this repo today
- `git log --oneline --all -i --grep="file_scope\|coarse"` and `git show 105317477` — recovered
  the full text of sibling tasks #59/#60 for batch context and confirmed #59 is `completed`
  with workaround edges already removed

### References

- `agent-system/extensions/core/scripts/validate-state.sh`
- `agent-system/extensions/core/commands/task.md` (Create Task Mode, Steps 1-8, no `file_scope`
  handling)
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh`
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md`
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` (Class C, lines
  355-475)
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md`
  (Component 4a)
- `agent-system/extensions/core/agents/meta-builder-agent.md` (out-of-scope related site)
- `agent-system/extensions/core/rules/state-management.md` (terminal/non-terminal statuses)
- `agent-system/extensions/core/scripts/lib/status-vocabulary.sh`
- `agent-system/extensions/core/scripts/verify-deploy.sh` (Gate 10, sole existing caller)
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` (test pattern, not in
  declared scope)
- `agent-system/extensions/core/scripts/validate-return-meta.sh` (`--fix` precedent)
