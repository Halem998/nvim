# Research Report: Task #933

**Task**: 933 - Pre-dispatch dependency and file_scope review/repair stage for /orchestrate
**Started**: 2026-07-28T00:31:39Z
**Completed**: 2026-07-28T00:45:00Z
**Effort**: medium (single new shared script + wiring into two existing surfaces + one guardrails doc update)
**Dependencies**: 932 (completed), 936 (completed) — both merged, unblocking this task
**Sources/Inputs**: Codebase read of agent-system/extensions/core/{commands,scripts,skills,context,docs}, live specs/state.json query
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Architectural gap confirmed**: `commands/orchestrate.md` Step 2 (Dependency Graph
  Construction) and `scripts/orchestrate-dry-run-report.sh` Step 3 each independently
  reimplement the SAME raw-dependency-filtering and Kahn wave-assignment logic inline in bash —
  there is no shared script for this step, unlike the admission predicate
  (`orchestrate-batch-admit.sh`) and the triage classifier (`orchestrate-triage-classify.sh`),
  which ARE already shared. This is the root cause of the task's four verified defects and the
  reason a new shared script (`orchestrate-predispatch-review.sh`, already declared in this
  task's `file_scope`) is the correct fix shape for Scope Item C ("share one implementation").
- **Defect 1 (silent dependency drop) is real and lives in exactly one place per surface**: both
  `commands/orchestrate.md` Step 2 (lines ~113-136) and `orchestrate-dry-run-report.sh`'s mirrored
  Step 3 (lines 182-197) filter `dependencies[]` down to `validated_tasks` membership with a bare
  `if [[ " ${validated_tasks[*]} " == *" $dep "* ]]` test and simply drop non-matching entries —
  no warning, no distinction between "nonexistent task", "terminal/completed task", and "live task
  simply not in this invocation." A DOWNSTREAM partial mitigation already exists for the
  live-but-out-of-batch case: dry-run-report.sh's separate Step 6 ("Out-of-batch unmet
  predecessors") re-derives dependency edges independently and DOES exclude+warn for that one
  subcase — but Step 6 exists only in the dry-run reporter, not in `commands/orchestrate.md`'s
  live Step 2/3, and it does not distinguish "nonexistent" from "terminal" from "live-but-absent"
  either (it just checks whether the dep's status is terminal or not).
- **Defect 2 (dependencies:null / title:null / topic:null) is real but currently dormant**: the
  four tasks originally cited as live examples (913, 918, 919, 931) have all since transitioned to
  `completed`. As of this research pass, `jq` finds **zero** currently non-terminal tasks with
  `dependencies: null`, `title: null`, or `topic: null` in `specs/state.json` (only 887, 933, 934,
  935 are non-terminal right now, and all four have well-formed metadata). The defect class is
  real and structurally uncaught (nothing currently validates these fields before dispatch), but
  the specific citations in the task description are historical, not live, at research time — the
  report stage this task builds should re-derive its own live findings at run time rather than
  rely on stale citations. Two existing partial mitigations already exist downstream, both AFTER
  dispatch, not before: `generate-todo.sh` falls back to a derived `project_name`-based title when
  `title` is null/empty (line 193), and `generate-task-order.sh` emits a non-fatal
  `Uncategorized`-bucket warning when `topic` is null (line 541) — but only at `/todo` render
  time, never at `/orchestrate` admission time.
- **Defect 3 (over-broad file_scope self-collision) is architecturally confirmed**:
  `context/reference/orchestrator-critical-paths.json` declares `scope_roots: ["agent-system/
  extensions/core", ".claude", ".opencode"]` and nine `critical_paths` entries under
  `scripts/`, `skills/skill-orchestrate*/SKILL.md`, and `commands/orchestrate.md`. A task
  declaring the coarse directory prefix `agent-system/extensions/core/scripts/` (this task's own
  first `file_scope` entry is exactly one file below that prefix, not the prefix itself — but a
  sibling task declaring the bare directory would trigger this) overlaps SIX of the nine critical
  paths (all `scripts/*` entries) under `file-footprint-overlap.md`'s directory-prefix rule, even
  when the task creates only new files and touches none of the six. This is `orchestrate-batch-
  admit.sh`'s own documented "Accepted False-Positive Profile" (see `batch-admit-schema.md`), not
  a bug in the predicate — it is a declaration-coarseness problem the predicate deliberately does
  not solve, which is exactly why a pre-dispatch review/repair stage (rather than a predicate
  change) is the correct locus for a fix, and matches this task's explicit non-goal ("this task
  does not change the admission predicate's verdict schema or its collision algorithm").
- **Defect 4 (missing cross-batch serializing edges) is explicitly documented as a residual, not
  hidden**: `commands/orchestrate.md`'s own "File-safety is a property of dependencies[] accuracy"
  paragraph (Step 3, lines 185-193) names this gap directly and points to the
  ALREADY-IMPLEMENTED runtime wave-split check (`orchestrate-batch-admit.sh`'s cross-batch
  collision scan) as the closing mechanism — but that check fires at dispatch time (Step 4/Stage
  MT-4), after wave assignment already ran, not as a pre-dispatch structural finding an operator
  can review and fix before running the batch. This task's Scope Item A asks for the SAME
  underlying fact (a would-be cross-batch collision) to be surfaced as a review finding earlier
  than the runtime defer already surfaces it.
- **Recommended approach**: extract a new shared script `orchestrate-predispatch-review.sh` that
  (a) reads `specs/state.json` directly (never the already-filtered `validated_tasks`/
  `dependency_graph`), (b) reports all four defect classes by task number and path, (c) is
  report-only by default, (d) offers an explicit, separately-invoked `--repair` mode that writes
  ONLY normalization fixes (`null` → `[]`/derived-title/`"Uncategorized"`-adjacent topic-warning)
  never silent dependency rewrites, and (e) is called from BOTH `commands/orchestrate.md` (new
  Step, immediately before the existing Step 2) and `orchestrate-dry-run-report.sh` (as a new
  early section), so the report and the live path share one implementation per Scope Item C.

## Context & Scope

This is task 933 in a family of five sibling `/orchestrate`-hardening tasks (932 through 936),
all created in the same batch and all declaring overlapping `file_scope` against
`commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`, and
`context/patterns/batch-orchestration-guardrails.md`. Multi-Task Creation Standard Component 4a's
auto-serialization already gave this family a correct dependency chain (932 → 933 → 934 → 935,
with 936 as a zero-dependency sibling each of them also depends on) — this family is itself a
working example of defect 4's stated non-goal (cross-batch collisions), since ALL FIVE were
created in the SAME batch, so the auto-serialization fired as designed. 932 and 936 are both
already `completed`, so this task is unblocked.

The research scope was: (1) confirm each of the four verified defects against the current
codebase and current `specs/state.json`, (2) identify exactly where raw, unfiltered
`dependencies[]` is visible before Step 2's filter destroys that visibility, (3) identify the
existing shared-script pattern (`orchestrate-batch-admit.sh`, `orchestrate-triage-classify.sh`)
as the template a new shared script should follow, (4) determine the read/write boundary the
"decide the repair contract" design question must resolve, and (5) confirm the manifest.json /
index-entries.json registration mechanics for whatever new script and (if any) new context file
this task's plan will introduce.

## Findings

### Codebase Patterns

**Two independent inline reimplementations of Steps 1-3, never a shared script.**
`commands/orchestrate.md`'s MULTI-TASK DISPATCH section (Step 1 Batch Validation, Step 2
Dependency Graph Construction, Step 3 Kahn wave assignment) is bash embedded directly in the
markdown command file. `scripts/orchestrate-dry-run-report.sh` reimplements the identical three
steps as its own Steps 1-3 (lines 132-241), independently, in a real `.sh` file. The two are
currently believed to match behavior only because they were hand-kept in sync — there is no
enforcement that they stay identical, unlike the two genuinely-shared scripts
(`orchestrate-batch-admit.sh`, `orchestrate-triage-classify.sh`), which both surfaces call by
path with byte-identical invocation contracts. This is the single most load-bearing finding for
Scope Item C: "wire the stage into the existing --dry-run surface so the report and the live path
share one implementation" is only honestly satisfiable by extracting a THIRD shared script
(matching the two that already exist), not by adding logic to one surface and hoping the other
stays in sync by hand.

**Where raw `dependencies[]` is last visible.** `commands/orchestrate.md` Step 2 (`for task_num in
"${validated_tasks[@]}"; do deps=$(jq -r ... .dependencies // [] | .[] ...)`) reads
`specs/state.json` directly and is the only point in the live path where a task's FULL declared
`dependencies[]` array (before intra-batch filtering) is available. Immediately after this loop,
only `predecessors[$task_num]` (the intra-batch-filtered subset) survives; the discarded entries
are never logged, stored, or referenced again anywhere in `commands/orchestrate.md`. Note that
`skill-orchestrate/SKILL.md`'s Stage MT-1 does NOT rebuild this graph — it receives an
already-built `dependency_graph` map from the command's Step 2/3 output as part of the
`multi_task_mode=true` Skill-tool invocation (see "Single-Dispatch Multi-Task Mode" in
`orchestrate.md` Step 4, which serializes `dep_graph_json` and `waves_json` into the Skill call
args). This confirms the task description's claim precisely: `commands/orchestrate.md` Step 2 is
the ONE place with raw-dependency visibility on the live path, and a review stage must run there
(or immediately before it) rather than inside `skill-orchestrate/SKILL.md`.

**`orchestrate-dry-run-report.sh`'s Step 6 partially — but not fully — already surfaces
defect-1's "live but out-of-batch" subcase.** Its Step 6 ("Out-of-batch unmet predecessors")
independently re-derives, for every validated task, which of its `dependencies[]` entries fall
outside `validated_tasks`, looks up each such dependency's live status, and — if that dependency
is NOT terminal — adds an exclusion + a Notes-section warning naming the out-of-batch task and its
status. This is real, working, non-silent behavior, but it exists ONLY in the dry-run reporter
(not in `commands/orchestrate.md`'s live Step 2/3), and it does not warn at all for the
"nonexistent task number" subcase (a dep pointing at a task number absent from
`active_projects` entirely is silently indistinguishable from one that resolved and turned out to
be terminal — both fall through the `[ -z "$dep_data" ] || [ "$dep_data" = "null" ] &&
continue`/terminal-status `continue` guard with no note emitted). The Non-Negotiable 3 text in
`batch-orchestration-guardrails.md` ("Never silently drop a dependency edge because its target is
out of batch... exclude the dependent task by default") is satisfied by dry-run-report.sh's Step 6
for the live-out-of-batch subcase specifically, but NOT for the nonexistent-task subcase, and NOT
at all on the live `commands/orchestrate.md` path (Step 6 has no counterpart there — the live path
relies solely on the LATER `orchestrate-batch-admit.sh` runtime wave-split check, which checks
`file_scope` collisions and self-modification, never dependency-graph validity).

**Self-modification critical-path list and its scope_roots.**
`context/reference/orchestrator-critical-paths.json` declares `scope_roots: ["agent-system/
extensions/core", ".claude", ".opencode"]` and 9 `critical_paths` entries (all relative, e.g.
`scripts/orchestrate-batch-admit.sh`, `commands/orchestrate.md`). The expansion in
`orchestrate-batch-admit.sh` (`$roots[] as $r | $paths[] as $p | {path: ($r + "/" + $p.path), ...}`)
produces 27 expanded paths (9 × 3 roots). A `file_scope` entry of
`agent-system/extensions/core/scripts/` (bare directory, no trailing file) would directory-prefix-
overlap SIX of the nine entries under that one root alone (`scripts/skill-base.sh`,
`scripts/task-lock.sh`, `scripts/update-task-status.sh`, `scripts/orchestrate-batch-admit.sh`,
`scripts/orchestrate-triage-classify.sh`, `scripts/orchestrate-dry-run-report.sh`) per
`file-footprint-overlap.md`'s rule 2 (`pathA` is a directory-prefix ancestor of `pathB`). This
task's OWN declared `file_scope` deliberately avoids that trap — its first entry is the specific
new file `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh`, not the bare
`scripts/` directory — which is itself a small, live illustration of the "declare narrowly" fix
this task's Scope Item A/B should recommend to operators, though narrower declaration is a
task-authoring discipline this task cannot itself enforce retroactively; it can only surface the
finding before dispatch.

**Multi-Task Creation Standard Component 4a is creation-time only.** Its four numbered steps
(populate `file_scope`, run the shared overlap algorithm PAIRWISE ACROSS THE BATCH, auto-add a
serializing edge, never-silent annotation) explicitly scope the pairwise comparison to "the
current batch" (step 2: "apply ... to every unordered pair of proposed tasks in the current
batch"). There is no code path anywhere that re-runs 4a's comparison against tasks OUTSIDE the
creation batch that already exist in `state.json` — this is exactly defect 4, and it is the
documented, accepted residual `commands/orchestrate.md`'s Step 3 commentary already names, closed
today only by the LATER runtime `orchestrate-batch-admit.sh` defer at dispatch time, never at
review time.

**Existing shared-script conventions to follow.** Both `orchestrate-batch-admit.sh` and
`orchestrate-dry-run-report.sh` share a consistent header-comment contract (Purpose, Usage,
full field-by-field verdict/output schema, exit codes 0/2, `set -uo pipefail`, sourcing
`deploy-root-guard.sh`, single `--slurpfile`/single read of `specs/state.json`, NDJSON-on-stdout
for the predicate script vs. structured plain-text sections for the reporter). A new
`orchestrate-predispatch-review.sh` should follow the SAME structural conventions: single read of
`specs/state.json`, `deploy-root-guard.sh` sourced, explicit exit-code contract, and (per Scope
Item C) an invocation contract simple enough that both `commands/orchestrate.md`'s Step-2-adjacent
bash and `orchestrate-dry-run-report.sh`'s composer can call it identically and consume the same
output shape.

### External Resources

Not applicable — this is a pure agent-system meta task; no external library or web research was
needed. All findings are drawn from the codebase itself.

### Recommendations

1. **New shared script, not new inline logic in either surface.** Create
   `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` (already declared in
   this task's `file_scope`) that takes the same `<task_number> [<task_number> ...]` positional
   contract as `orchestrate-batch-admit.sh`, reads `specs/state.json` directly (once, via
   `--slurpfile` per existing convention), and emits findings for all four defect classes:
   - **Class A (out-of-batch/nonexistent dependency)**: for each candidate, for each entry in its
     RAW `dependencies[]` (not the filtered `predecessors[]`), classify as `intra_batch` (already
     handled correctly by existing Kahn logic — no finding needed), `out_of_batch_live`
     (dependency exists, non-terminal, not in this invocation — mirrors dry-run-report.sh's
     existing Step 6, but now shared), `out_of_batch_terminal` (dependency exists but is already
     terminal — arguably fine to drop, but should still be a visible NOTE not a silent drop, since
     the guardrails doc's Non-Negotiable 3 draws no exception for terminal targets), or
     `nonexistent` (dependency task number absent from `active_projects` entirely — a metadata
     defect on its own, currently the least visible subcase).
   - **Class B (metadata defects)**: `dependencies == null` (should be `[]`), `title == null`,
     `topic == null`, plus (recommended addition beyond the four literal fields named in the task
     description, if the plan scopes it in) any other array-typed field commonly found `null`
     instead of `[]` in this schema (e.g. `file_scope == null`) — worth a quick grep across
     `state.json`'s schema fields during planning rather than hardcoding exactly three field
     checks.
   - **Class C (self-collision via over-broad file_scope)**: reuse
     `orchestrate-batch-admit.sh`'s existing `self_modifying` verdict field (already computed,
     already exposed) rather than re-deriving the critical-path overlap independently — this
     avoids forking `file-footprint-overlap.md`'s predicate a fifth time. The NEW value this
     stage adds on top of the existing verdict is the "this looks like declaration coarseness,
     not a real conflict" diagnosis: when a `self_modifying: true` verdict's matched
     `critical_path` is covered ONLY because the candidate declared a directory prefix broader
     than any file it will actually touch, that is exactly the class this task's Scope Item A
     asks to make visible before dispatch, with a suggested narrower `file_scope` alternative
     in the finding text.
   - **Class D (missing cross-batch serializing edges)**: reuse
     `orchestrate-batch-admit.sh`'s existing `file_scope_collision`/`cross_batch` verdict the
     same way — this stage's job is to surface it as a review-time finding with a suggested
     `dependencies[]` edge to add, not to reimplement the overlap scan.
   - For Classes C and D, calling `orchestrate-batch-admit.sh` from within the new script (as a
     subprocess, the same way `orchestrate-dry-run-report.sh` already does) is preferable to
     re-deriving the predicate a third time — it keeps the ONE admission predicate canonical and
     the new stage a pure consumer/re-presenter of its existing output for classes C/D, while
     being a first-party producer of NEW findings only for classes A/B (the two defect classes
     no existing script currently computes at all).

2. **Report-only by default; repair strictly opt-in and narrowly scoped.** The task description's
   own framing ("report-only by default with opt-in repair is the presumed shape, but justify
   whatever is chosen") together with the read-only, defer-not-fail invariant
   `orchestrate-batch-admit.sh`'s header explicitly states ("this script never writes to
   state.json") is the strongest signal in the codebase: EVERY existing admission-adjacent script
   is read-only, and `commands/orchestrate.md` states the invariant explicitly for
   `orchestrate-batch-admit.sh`. The plan should:
   - Default `orchestrate-predispatch-review.sh` invocation to **report-only**, matching every
     sibling script's convention (exit 0 regardless of finding severity, per the existing
     "verdicts/findings are data, not errors" convention shared by `orchestrate-batch-admit.sh`
     and `orchestrate-triage-classify.sh`).
   - Gate any state-mutating repair behind an explicit, separately-named flag (e.g. `--repair`)
     that is NEVER passed automatically by `commands/orchestrate.md`'s live dispatch path or by
     `skill-orchestrate/SKILL.md`'s autonomous cycling loop — only a human-invoked `/orchestrate
     --dry-run --repair N,M` (or a dedicated repair invocation path the plan should name
     explicitly) may trigger a write. This directly satisfies the task's explicit constraint "Do
     not make an autonomous /orchestrate run silently rewrite declared dependencies."
   - Scope repair strictly to Class B's own-field normalization (`null` → `[]` for
     `dependencies`/`file_scope`, and a WARN-not-silently-default behavior for `title`/`topic`
     null, since `generate-todo.sh` already has a derivation convention for title that repair
     could reuse rather than invent a second one). Repair should almost certainly NOT rewrite
     `dependencies[]` edges (Class A/D) autonomously even in `--repair` mode, since choosing which
     edge to add is a judgment call the Open Design Fork below leaves unresolved — repair-mode
     should limit itself to the field-normalization subset of findings where there is exactly one
     correct fixed value, not the graph-topology subset where there are competing valid choices.

3. **Resolve the Open Design Fork for Non-Negotiable 3 as "exclude the dependent task by
   default," matching every other defer-not-fail precedent in this codebase, and document that
   resolution explicitly rather than leaving the fork open.** The guardrails doc's own "Defer-Not-
   Fail: The Standing Default" section already states the intended generalization ("a declared
   dependency whose target lies outside the batch... should be deferred, never hard-failed") and
   the two existing precedents that already implement exactly this shape for the live-out-of-batch
   subcase — `orchestrate-dry-run-report.sh`'s Step 6 (exclude + warn) and
   `orchestrate-batch-admit.sh`'s Non-Negotiable-2-driven cross-batch collision exclusion (exclude
   + warn, never auto-expand) — both already chose "exclude the dependent task," never
   "auto-expand the batch." Auto-expanding the batch would require applying the FULL admission
   check (file_scope collision, self-modification, lock, handoff-triage) to the newly-pulled-in
   predecessor before it is safe to dispatch alongside it, which is strictly more machinery for a
   less-tested code path, with no existing precedent anywhere in this codebase choosing the
   auto-expand shape. The plan should record this as the resolution (Scope Item E: "record the
   resolution... and, if applicable, the Open Design Fork") rather than re-opening the design
   question from scratch.

4. **Wiring points.**
   - `commands/orchestrate.md`: insert a new step ("Step 1.5: Pre-Dispatch Review" or similar,
     the plan should name it precisely) between the existing Step 1 (Batch Validation) and Step 2
     (Dependency Graph Construction), calling `orchestrate-predispatch-review.sh` against
     `validated_tasks` and printing its findings as loud, non-blocking warnings (report-only mode
     — this call must never abort the invocation, since `--dry-run` already exists as the
     abort-before-dispatch surface; the live path's own review step is advisory-loud, not
     blocking, unless the plan decides otherwise and justifies it against the Blocking vs.
     Advisory criterion in `batch-orchestration-guardrails.md`).
   - `orchestrate-dry-run-report.sh`: insert an equivalent early section (before or alongside its
     existing Step 1/2/3) that calls the SAME script and prints its findings in a new report
     section (the existing report format's six sections — Header, Checks run, Admitted, Excluded,
     Notes, Recommended split — should gain either a seventh section or fold the new findings into
     "Notes," per the plan's judgment; either choice must remain additive to the existing six,
     never restructuring them, since `batch-admit-schema.md` and `docs/architecture/*` name the
     dry-run reporter's existing shape in several places).
   - `skill-orchestrate/SKILL.md`: per the codebase finding above, the skill receives an
     already-built `dependency_graph`, so it likely needs NO logic change — but its file_scope
     inclusion in this task suggests at minimum a documentation cross-reference (e.g. a note in
     Stage MT-1 that raw dependency review already happened upstream in `commands/orchestrate.md`
     Step 1.5, so the skill can trust `dependency_graph`'s completeness within the review stage's
     own limits). The plan should confirm during implementation whether any code change is
     actually needed here or whether this is documentation-only.

5. **Registration**: `manifest.json`'s `provides.scripts` array is a flat, alphabetically-loose
   list of script basenames relative to `scripts/` (e.g. `"orchestrate-batch-admit.sh"`,
   `"orchestrate-dry-run-report.sh"`) — add `"orchestrate-predispatch-review.sh"` to that array.
   `index-entries.json`'s `entries[]` array indexes only files under `context/` (paths relative to
   `context/`, e.g. `"patterns/jq-escaping-workarounds.md"`) for context-discovery `load_when`
   purposes — it does NOT index `docs/` files (confirmed: neither `batch-admit-schema.md` nor
   `orchestrate-state-machine.md`, both under `docs/architecture/`, appear in `index-entries.json`
   at all) and, notably, does NOT currently index `context/patterns/batch-orchestration-
   guardrails.md`, `context/patterns/file-footprint-overlap.md`, or
   `context/reference/orchestrator-critical-paths.json` either — this appears to be a pre-existing
   gap unrelated to this task's scope, not something this task introduces or must fix. Scope Item
   D applies only if the plan introduces a genuinely NEW file under `context/` (e.g. a new pattern
   document explaining the review/repair contract) — if the plan's design fits entirely within
   updates to the already-`file_scope`-declared `batch-admit-schema.md` and
   `batch-orchestration-guardrails.md` (both pre-existing, already presumably indexed or
   consistently un-indexed per the above), no new `index-entries.json` entry may be required at
   all; this should be confirmed once the plan's exact file list is finalized.

## Decisions

- **Shared-script extraction is the correct shape for Scope Item C**, not "add logic to
  `orchestrate-dry-run-report.sh` and hope `commands/orchestrate.md` stays in sync by hand" — this
  follows the existing precedent of `orchestrate-batch-admit.sh` and
  `orchestrate-triage-classify.sh`, both already shared and already declared in this task's
  `file_scope` as the new script name (`orchestrate-predispatch-review.sh`) that name implies.
- **Report-only by default; repair is opt-in, human-triggered, and scoped to field-normalization
  only (never dependency-edge rewrites)** — justified directly by the read-only convention every
  sibling admission script already follows, and by the task's own explicit constraint against
  autonomous silent rewrites.
- **The Open Design Fork resolves to "exclude the dependent task by default," not "auto-expand
  the batch"** — justified by the two existing precedents in this codebase that already chose
  exclude-and-warn for structurally identical situations, and by auto-expand's strictly larger,
  untested surface area.
- **Classes C and D reuse `orchestrate-batch-admit.sh`'s existing verdict fields rather than
  re-deriving the overlap predicate a third/fourth time** — this keeps the collision algorithm
  canonical in exactly one place, honoring the task's explicit non-goal against changing that
  predicate or its schema.

## Risks & Mitigations

- **Risk**: a new "Step 1.5" in `commands/orchestrate.md` could be mistaken for a second admission
  gate competing with `orchestrate-batch-admit.sh`'s runtime wave-split check (Step 3/Stage MT-3),
  confusing future readers about which check is authoritative for what. **Mitigation**: the plan
  should name the new stage explicitly as a REVIEW stage (report findings, do not exclude/defer on
  its own for Classes C/D — those remain the runtime check's job at dispatch time), reserving
  actual exclusion authority to the existing runtime check; the review stage's role is strictly
  "surface earlier what would otherwise only be discovered at dispatch," never "replace or
  duplicate the dispatch-time gate."
- **Risk**: adding a fourth reader of `orchestrate-batch-admit.sh`'s verdict schema (if the new
  script calls it as a subprocess for Classes C/D) could be read as violating
  `batch-admit-schema.md`'s "exactly three sanctioned readers" list. **Mitigation**: the plan
  should treat `orchestrate-predispatch-review.sh` calling `orchestrate-batch-admit.sh` as
  analogous to `orchestrate-dry-run-report.sh` ALREADY calling it (dry-run-report.sh is one of the
  three sanctioned readers precisely because it composes a report FROM the predicate's output,
  not because it re-derives the predicate) — but since this is a NEW script, `batch-admit-
  schema.md`'s "Read by" list (currently three named call sites) will need a fourth line added
  when this script becomes a caller, which the plan must do explicitly and honestly rather than
  treat as an invisible extension. This is a schema-documentation update, not a verdict-schema
  behavior change, so it does not conflict with the task's explicit non-goal.
- **Risk**: repair mode, even scoped to field-normalization, still mutates `specs/state.json`
  outside the existing `update-task-status.sh` gatekeeper path (per
  `context/reference/orchestrator-critical-paths.json`'s label for that script: "status-transition
  gatekeeper"). **Mitigation**: the plan should confirm whether a direct `jq` write to
  `state.json` (bypassing `update-task-status.sh`, which is scoped to status-field transitions
  specifically, not generic field repair) is acceptable, or whether a narrower, dedicated
  read-modify-write helper following `update-task-status.sh`'s existing atomicity conventions
  (e.g. write-to-temp-then-`mv`, matching whatever pattern that script already uses) should be
  reused/extended instead of a bespoke write path.

## Context Extension Recommendations

- **Topic**: pre-existing `index-entries.json` coverage gaps for `context/patterns/`.
- **Gap**: `context/patterns/batch-orchestration-guardrails.md`,
  `context/patterns/file-footprint-overlap.md`, and
  `context/reference/orchestrator-critical-paths.json` are all live, heavily-cross-referenced
  files under `context/` with no corresponding entry in `index-entries.json`, meaning they are
  never pulled into agent context automatically via the `load_when` mechanism — they are only ever
  reached via explicit path reference from another file.
- **Recommendation**: out of scope for this task's plan (this task's `file_scope` does not
  include `file-footprint-overlap.md` or `orchestrator-critical-paths.json`, and updating
  `batch-orchestration-guardrails.md`'s own indexing is incidental to updating its content) — flag
  as a candidate follow-up task rather than folding into this one's scope.

## Appendix

### Search queries used

- `jq '.active_projects[] | select(.project_number==933)' specs/state.json`
- `jq -r '.active_projects[] | select((.status | test("completed|abandoned|expanded";"i") | not)) | select(.dependencies == null or .title == null or .topic == null)'`
- Grep across `agent-system/extensions/core` for `Step 2`, `Dependency Graph`, `MAX_TASKS`, `Kahn`
- Grep for `Uncategorized`, `title == null` handling in `generate-todo.sh` / `generate-task-order.sh`
- Grep for `orchestrate-dry-run-report`, `orchestrate-batch-admit`, `batch-admit-schema`,
  `batch-orchestration-guardrails`, `orchestrator-critical-paths` across `index-entries.json`

### References to documentation

- `agent-system/extensions/core/commands/orchestrate.md` (Steps 1-4, MULTI-TASK DISPATCH section)
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` (full file — Steps 1-7,
  report composer)
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (full file — verdict predicate
  and header contract)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (full file —
  Non-Negotiables, Open Design Fork, Self-Modification Hazard sections)
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` (full file — overlap
  predicate and consumer list)
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` (full file)
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` (full file — verdict
  schema, "Read by" sanctioned-consumer list)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (full file — orchestrator
  handoff schema used to write this research dispatch's own handoff)
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md`
  (Component 4a section)
- `agent-system/extensions/core/scripts/generate-todo.sh` (title-null fallback, lines ~182-208)
- `agent-system/extensions/core/scripts/generate-task-order.sh` (Uncategorized warning, lines
  ~473-545)
- `agent-system/extensions/core/manifest.json` (`provides.scripts` registration format)
- `agent-system/extensions/core/index-entries.json` (`entries[]` registration format and scope)
