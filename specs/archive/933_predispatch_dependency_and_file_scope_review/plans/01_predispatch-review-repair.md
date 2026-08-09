# Implementation Plan: Task #933

- **Task**: 933 - Pre-dispatch dependency and file_scope review/repair stage for /orchestrate
- **Status**: [COMPLETED]
- **Effort**: 7 hours
- **Dependencies**: 932 (completed), 936 (completed) — both merged, task unblocked
- **Research Inputs**: `specs/933_predispatch_dependency_and_file_scope_review/reports/01_predispatch-review-repair-research.md`
- **Artifacts**: plans/01_predispatch-review-repair.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Extract a new shared script `orchestrate-predispatch-review.sh` that reads `specs/state.json`
directly — the only place raw, unfiltered `dependencies[]` is still visible — and reports four
classes of pre-dispatch defect (silently-dropped dependency edges, null metadata fields,
declaration-coarseness self-collisions, and missing cross-batch serializing edges) by task number
and path. The script is report-only by default, exposes repair strictly as a direct-invocation
`--repair` flag scoped to field normalization only, and is called identically from both
`commands/orchestrate.md`'s live path and `scripts/orchestrate-dry-run-report.sh`, so the two
surfaces cannot drift. Definition of done: both surfaces call one script, the guardrails doc
records the Non-Negotiable 3 resolution and closes the Open Design Fork, and the new script is
registered in `manifest.json`.

### Research Integration

The research report drives every structural decision in this plan:

- **Root cause identified**: `commands/orchestrate.md` Step 2 and `orchestrate-dry-run-report.sh`
  Step 3 independently reimplement the same raw-dependency filter and Kahn wave assignment in
  bash, hand-kept in sync with no enforcement — unlike `orchestrate-batch-admit.sh` and
  `orchestrate-triage-classify.sh`, which are genuinely shared. Scope Item C is therefore only
  honestly satisfiable by extracting a **third** shared script, not by adding logic to one surface.
- **Defect 1 confirmed** in both surfaces at the bare
  `if [[ " ${validated_tasks[*]} " == *" $dep "* ]]` membership test. A *partial* mitigation
  already exists — `orchestrate-dry-run-report.sh`'s Step 6 ("Out-of-batch unmet predecessors")
  excludes and warns for the live-out-of-batch subcase — but it exists only in the reporter, never
  on the live path, and never distinguishes a nonexistent task number from a terminal one.
- **Defect 2 confirmed as a real but currently dormant class**: the originally cited example tasks
  have all since gone terminal, and `jq` currently finds zero non-terminal tasks with
  `dependencies: null` / `title: null` / `topic: null`. The review stage must therefore re-derive
  its findings live at run time rather than hardcode against stale citations. Existing mitigations
  (`generate-todo.sh`'s derived-title fallback, `generate-task-order.sh`'s `Uncategorized` warning)
  both fire at `/todo` render time, never at admission time.
- **Defects 3 and 4 are already computed** by `orchestrate-batch-admit.sh` and exposed on its
  verdict schema (`self_modifying`, `defer_reason: "self_modifying"`, `defer_reason:
  "file_scope_collision"` with `collision_scope: "cross_batch"`). The new script consumes those
  verdicts as a subprocess rather than re-deriving the overlap predicate — this keeps the
  collision algorithm canonical in exactly one place and honors the task's explicit non-goal.
- **Open Design Fork resolution**: the report recommends "exclude the dependent task by default,"
  justified by the two existing precedents in this codebase (the reporter's Step 6 and
  `orchestrate-batch-admit.sh`'s cross-batch exclusion) that already chose exclude-and-warn, and
  by auto-expand's strictly larger untested surface (an auto-pulled predecessor would need the
  full admission check applied before it is safe to dispatch alongside).
- **Registration scope**: `index-entries.json` indexes only files under `context/`. The report
  found that `batch-orchestration-guardrails.md` is already un-indexed alongside its siblings — a
  pre-existing gap this task neither introduces nor must fix. Scope Item D therefore reduces to
  `manifest.json` unless a genuinely new `context/` file is introduced, which this plan
  deliberately avoids.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no ROADMAP.md consultation was
requested. No roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Surface all four verified defect classes with specific task numbers and paths **before** the
  dependency graph is built, reading `specs/state.json` directly.
- Satisfy `batch-orchestration-guardrails.md` Non-Negotiable 3's currently-violated clauses: warn
  loudly on every dropped dependency edge, and distinguish the nonexistent / terminal /
  live-out-of-batch subcases rather than discarding all three identically.
- Extract ONE shared implementation consumed identically by the live `commands/orchestrate.md`
  path and the existing `--dry-run` report surface, matching the two shared scripts that already
  exist.
- Resolve the Open Design Fork explicitly and record the resolution.
- Keep repair opt-in, human-triggered, and impossible to reach from an autonomous run.

**Non-Goals**:
- Changing the admission predicate's verdict schema or its collision algorithm (explicit task
  non-goal). The new script is a pure consumer of `orchestrate-batch-admit.sh`'s existing output.
- Introducing a second, parallel pre-dispatch preview path. The existing `--dry-run` surface is
  extended, never forked; `batch-admit-schema.md`'s sanctioned-reader list stays accurate by being
  updated, not by being quietly outgrown.
- Making the review stage a fifth admission gate. It reports; exclusion authority stays with the
  existing runtime wave-split check at dispatch time.
- Repairing dependency-graph topology. `--repair` never adds, removes, or rewrites a
  `dependencies[]` edge.
- Adding a test harness under `scripts/tests/`. That path is outside this task's declared
  `file_scope`; recorded below as a follow-up candidate.
- Fixing the pre-existing `index-entries.json` coverage gap for `context/patterns/` files.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new "Step 1.5" reads as a second admission gate competing with the runtime wave-split check | M | H | Name the stage a REVIEW stage in both the script header and the command text; state explicitly that it never excludes or defers on its own and that exclusion authority remains with the dispatch-time check. Its role is "surface earlier what would otherwise only be discovered at dispatch." |
| Adding a fourth reader of the admit verdict schema silently contradicts `batch-admit-schema.md`'s "exactly three sanctioned readers" list | M | H | Update the **Read by** list in `batch-admit-schema.md` to name the new script explicitly and honestly, as a documentation change (not a verdict-schema change). Phase 5 owns this. |
| `--repair` mutates `specs/state.json` outside the `update-task-status.sh` gatekeeper path | H | M | Confirm that script's atomicity convention at implementation time and reuse it (temp-then-`mv`); refuse to write when the field is anything other than a literal `null`; never write on the live or dry-run paths. |
| The two wired surfaces drift again if only one is updated | H | M | Phase 4 declares `Commit Mode: atomic-batch` over both surfaces — the exact failure this task exists to prevent must not be reintroduced by a half-landed wiring phase. |
| The live path's review call aborts an invocation it should only annotate | H | L | Report-only invocation on the live path is non-blocking by contract: exit 0 regardless of finding count, matching the "verdicts are data, not errors" convention both sibling scripts already follow. |
| Renumbering the dry-run report's six documented sections breaks other docs that reference them | M | M | Append the new findings as section 7 rather than inserting early. Sections 1-6 keep their existing order and numbering byte-for-byte; only an additive "ran" line is added inside the existing "Checks run" section. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 4 |
| 5 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Shared review script skeleton with Classes A and B [COMPLETED]

**Goal**: Create `orchestrate-predispatch-review.sh` as a read-only, report-only script that reads
`specs/state.json` directly and emits findings for the two defect classes no existing script
computes at all: raw-dependency classification (Class A) and metadata defects (Class B).

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` following
      the structural conventions of `orchestrate-batch-admit.sh` and
      `orchestrate-dry-run-report.sh`: `set -uo pipefail`, `SCRIPT_DIR`/`PROJECT_ROOT` resolution,
      sourcing `deploy-root-guard.sh`, a single read of `specs/state.json`, and a header comment
      stating Purpose, Usage, the full finding schema, the forbidden-calls list, and exit codes.
      *(completed)*
- [x] Adopt the positional invocation contract `orchestrate-predispatch-review.sh <task_number>
      [<task_number> ...]`, identical in shape to `orchestrate-batch-admit.sh`, with the same
      non-negative-integer validation and the same exit-code contract (0 = findings emitted
      regardless of count; 2 = usage error or unavailable state). *(completed: verified via
      zero-arg and non-integer-arg exit-2 tests against a fixture)*
- [x] Implement **Class A**: for each candidate, iterate its RAW `dependencies[]` (never a filtered
      subset) and classify each entry into exactly one of four buckets — `intra_batch` (no finding;
      the existing Kahn logic already handles it correctly), `out_of_batch_live` (target exists,
      non-terminal, absent from this invocation), `out_of_batch_terminal` (target exists but is
      already terminal), and `nonexistent` (target absent from `active_projects` entirely). Emit a
      finding naming the dependent task, the dependency target, and the bucket for all three
      non-`intra_batch` buckets — including the terminal one, since Non-Negotiable 3 draws no
      exception for terminal targets. *(completed: all four buckets verified against a seeded
      fixture and against live task 887's terminal dependency edges)*
- [x] Implement **Class B**: flag `dependencies == null`, `title == null`, and `topic == null` on
      every candidate. Before hardcoding that field list, survey `specs/state.json`'s live schema
      for any other array-typed field commonly present as `null` instead of `[]` (in particular
      `file_scope`) and include whatever the survey actually finds. *(completed: live survey of
      all 48 active_projects[] entries found zero null values on any field, confirming Defect 2's
      dormant status; the schema reference documents `file_scope` as the other array field with a
      `[]` default alongside `dependencies`, so both were added to the checked set — `artifacts`
      was surveyed too but excluded as not consumed by any admission-relevant code path)*
- [x] Add a header note that this script is a REVIEW stage only: it never excludes, never defers,
      never writes on this default path, and never substitutes for the dispatch-time admission
      check. *(completed)*
- [x] Verify the script is executable and its default invocation is genuinely read-only (no write
      call sites present anywhere in the file). *(completed: `chmod +x` applied; the only two
      `mv`/write call sites in the file are gated strictly inside the `--repair` branch, confirmed
      by re-running the default path against live state.json and diffing — byte-identical)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Class B is asserted to cover three named fields plus possibly `file_scope`.
Confirm at implementation time by querying live `specs/state.json` for every field on
`active_projects[]` entries whose value is `null`, and expand or narrow the checked field set to
match what the schema actually exposes rather than to match this plan's guess.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` - new file; header
  contract, arg parsing, state read, Class A and Class B finding emission

**Verification**:
- `bash -n` parses the script cleanly; `shellcheck` (if available) reports no errors.
- Running the script against the current live task numbers exits 0 and prints a well-formed
  report, including the honest "no findings" case for a class with nothing to report.
- Running with zero arguments and with a non-integer argument each exit 2 with a single loud
  stderr line.
- `git diff` confirms `specs/state.json` is unmodified after every invocation.

---

### Phase 2: Classes C and D via the existing admission predicate [COMPLETED]

**Goal**: Add self-collision (Class C) and missing-cross-batch-edge (Class D) findings by consuming
`orchestrate-batch-admit.sh`'s existing NDJSON verdicts as a subprocess, never by re-deriving the
overlap predicate.

**Tasks**:
- [x] Call `orchestrate-batch-admit.sh` once for the candidate set with `--invocation-count` set to
      that set's own size, exactly as `orchestrate-dry-run-report.sh` already does, and parse the
      NDJSON verdicts. *(completed)*
- [x] Implement **Class C** by consuming verdicts with `defer_reason == "self_modifying"`: report
      the matched `critical_path` and `critical_label`, then add the diagnostic value this stage
      exists to provide — when the candidate's `file_scope` covers that critical path only because
      it declares a directory prefix broader than any file it will actually touch, say so in the
      finding text and suggest the narrower `file_scope` alternative. This declaration-coarseness
      diagnosis is the new information; the verdict itself is not. *(completed: coarse vs. exact
      distinction verified against a seeded fixture and against live tasks 933-935's exact-match
      declarations)*
- [x] Implement **Class D** by consuming verdicts with `defer_reason == "file_scope_collision"` and
      `collision_scope == "cross_batch"`: report the colliding task number, its status, and the
      `overlapping_path`, and suggest the specific serializing `dependencies[]` edge that would
      close the gap. Suggest only — never write it. *(completed: verified against a seeded
      cross-batch collision fixture; suggestion direction follows the existing higher-number
      -defers-against-lower-number precedent)*
- [x] Handle the degraded case where `orchestrate-batch-admit.sh` is unavailable or exits 2: report
      Classes C and D as "SKIPPED (degraded: <reason>)" rather than silently emitting nothing, and
      still exit 0 with Classes A and B intact. *(completed: verified by temporarily hiding
      orchestrate-batch-admit.sh in a fixture and confirming exit 0 with explicit SKIPPED lines)*
- [x] Record in the script header that Classes C/D are re-presentations of an existing verdict and
      that this script is a consumer of, never a fork of, the admission predicate. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` - add the admit
  subprocess call, verdict parsing, Class C and Class D finding emission, and the degraded-path
  handling

**Verification**:
- `bash -n` parses cleanly.
- Invoking against a candidate set that includes a task whose `file_scope` names an
  orchestrator-critical path produces a Class C finding naming that path.
- Temporarily making `orchestrate-batch-admit.sh` unreachable produces the explicit degraded line
  and still exits 0 — never a silent empty section.
- The verdict field names read by this script match `batch-admit-schema.md` exactly, confirmed by
  reading that document rather than by inference.

---

### Phase 3: Opt-in `--repair` mode, scoped to field normalization [COMPLETED]

**Goal**: Add a `--repair` flag that writes ONLY Class B field normalizations, is reachable only by
direct human invocation, and can never be triggered by an autonomous `/orchestrate` run.

**Tasks**:
- [x] Implement `--repair` as a flag on `orchestrate-predispatch-review.sh` only. It is
      deliberately NOT plumbed through any `/orchestrate` flag: `parse-command-args.sh` is not
      modified, so no `/orchestrate` invocation — autonomous or interactive — can reach repair mode.
      An operator runs the script directly. Record this as the deliberate design choice satisfying
      the task's constraint against autonomous silent rewrites, not as an incidental limitation.
      *(completed; confirmed by grep in Phase 6)*
- [x] Scope writes strictly to Class B normalization: `dependencies: null` becomes `[]`, and any
      other array-typed field the Phase 1 survey confirmed as `null`-instead-of-`[]` becomes `[]`.
      Write only when the current value is a literal `null`; never overwrite a present value.
      *(completed: `.dependencies = (.dependencies // [])` is a no-op on any already-present
      value, verified against a fixture)*
- [x] For `title: null` and `topic: null`, WARN with the suggested value rather than writing.
      `generate-todo.sh` already owns a derived-title convention; repair must not invent a second,
      competing derivation. *(completed: title suggestion replicates generate-todo.sh's
      underscore-to-space + capitalize-first-letter fallback exactly; topic WARN references
      generate-task-order.sh's "Uncategorized" bucket rather than inventing a derivation)*
- [x] Refuse categorically to add, remove, or rewrite any `dependencies[]` edge, even in repair
      mode. Choosing which edge to add is a judgment call; repair is limited to the subset of
      findings that have exactly one correct fixed value. *(completed: the only dependencies
      write is `null -> []`; no code path appends/removes an element)*
- [x] Confirm `update-task-status.sh`'s atomicity convention by reading it, then reuse that same
      convention (write-to-temp-then-`mv`, or whatever that script actually does) for the state
      write. Do not invent a bespoke write path. *(completed: confirmed update-task-status.sh
      writes to `$TMP_DIR/state.json.tmp`, validates with `jq empty`, then `mv`s atomically —
      reused verbatim, minus the specs/.scope-lock mutex since --repair is direct-invocation-only,
      documented as a deliberate scope reduction in the header)*
- [x] Print a full before/after diff of every field the repair would change, and exit non-zero only
      on write failure — never merely because findings existed. *(completed; a bug in the initial
      diff/write jq filters — `select(($cands | index(.project_number)) != null)` re-piped "."
      into `$cands` inside `index()`'s argument, raising "Cannot index array with string" — was
      found and fixed during fixture testing by binding `.project_number as $pn` first)*
- [x] Have the default report-only path print the exact `--repair` command an operator can
      copy-paste, so the repair route is discoverable without being automatic. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase assumes `update-task-status.sh` uses a temp-then-`mv` atomic write
and that reusing it requires no new helper. Confirm by reading `update-task-status.sh` before
writing any state-mutating code; if its convention differs, adopt the actual convention and note
the deviation in the script header.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` - add `--repair` flag
  parsing, the normalization write path, the refusal guard on dependency edges, and the diff output

**Verification**:
- Run `--repair` against a **copy** of `specs/state.json` seeded with a `dependencies: null` entry;
  confirm the copy is normalized to `[]` and every other byte is unchanged.
- Confirm the live `specs/state.json` is untouched by any default (non-`--repair`) invocation, via
  `git diff`.
- Confirm no code path in `commands/orchestrate.md` or `skills/skill-orchestrate/SKILL.md` passes
  `--repair`, by grep across both files.
- After any repair write, `jq . specs/state.json` parses and `bash .claude/scripts/generate-todo.sh`
  regenerates TODO.md without error — the full downstream gate for a state.json mutation.

---

### Phase 4: Wire both surfaces to the one shared script [COMPLETED]

**Goal**: Call the new script identically from the live path and the `--dry-run` report so the two
surfaces share one implementation and cannot drift.

**Tasks**:
- [x] In `commands/orchestrate.md`, insert **Step 1.5: Pre-Dispatch Review** between the existing
      Step 1 (Batch Validation) and Step 2 (Dependency Graph Construction) — Step 2 is the last
      point at which raw `dependencies[]` is visible, so the review must run before it. Call
      `orchestrate-predispatch-review.sh` against `validated_tasks` in report-only mode and print
      its findings as loud, non-blocking warnings. *(completed)*
- [x] State explicitly in the Step 1.5 prose that this call is advisory-loud, never blocking:
      `--dry-run` already exists as the abort-before-dispatch surface, and exclusion authority for
      Classes C/D remains with the dispatch-time admission check. Cross-reference
      `batch-orchestration-guardrails.md`'s Blocking vs. Advisory criterion. *(completed)*
- [x] Update the existing Step 2 prose so it no longer describes an unqualified silent filter:
      note that the raw edges have already been classified and reported by Step 1.5, and that the
      intra-batch restriction here is a wave-assignment concern, not a discard. *(completed)*
- [x] In `scripts/orchestrate-dry-run-report.sh`, call the SAME script and print its findings as a
      new **section 7 (Pre-dispatch review)**, appended after the existing "Recommended split"
      section. Sections 1-6 keep their current order and numbering unchanged — this is additive,
      never a restructuring, because several documents name the reporter's existing shape.
      *(completed; verified end-to-end against real tasks 887/933/934/935 — all 7 sections
      printed in original order, section 7 present with live findings)*
- [x] Add one additive line to the reporter's existing "Checks run" section for the new check,
      following that section's established "ran" / "SKIPPED (degraded: <reason>)" format.
      *(completed)*
- [x] Update the reporter's header comment: add the new call to its Composition list and add
      section 7 to its Report-sections list, preserving the "printed unconditionally, never
      omitted, never collapsed" property for the new section too. *(completed)*
- [x] Confirm both call sites use a byte-identical invocation shape, so a future reader can see at
      a glance that neither surface has a private variant. *(completed: both pass
      `"${validated_tasks[@]}"` with no extra flags; the only difference is
      `.claude/scripts/...` (literal, matching every other orchestrate.md call site) vs.
      `"$SCRIPT_DIR/..."` (matching every other sibling-script call inside
      orchestrate-dry-run-report.sh, e.g. its existing orchestrate-batch-admit.sh and
      orchestrate-triage-classify.sh calls) — the identical pre-existing convention already used
      for both sibling scripts, not a private variant)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - new Step 1.5; Step 2 prose correction
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` - new section 7, new
  Checks-run line, header Composition and Report-sections updates

**Verification**:
- `bash -n` on the reporter parses cleanly.
- Running `orchestrate-dry-run-report.sh` against a real multi-task candidate set prints all seven
  sections in order, with section 7 present even when it has no findings.
- Grep confirms the invocation string is identical at both call sites.
- Grep confirms the reporter still never calls any forbidden write path listed in its own header.
- The atomic-batch justification holds: neither file is committed without the other, since a
  half-landed wiring reintroduces exactly the drift this task exists to eliminate.

---

### Phase 5: Documentation of record [COMPLETED]

**Goal**: Record the Non-Negotiable 3 resolution, close the Open Design Fork, add the fourth
sanctioned reader to the admit schema, and cross-reference the new upstream stage from the skill.

**Tasks**:
- [x] In `context/patterns/batch-orchestration-guardrails.md`, update **Non-Negotiable 3** to
      record that its violated clauses are now satisfied: every dropped dependency edge is warned
      about by name, and the four subcases (`intra_batch`, `out_of_batch_live`,
      `out_of_batch_terminal`, `nonexistent`) are distinguished rather than discarded identically.
      *(completed: worded precisely — the warn-loudly and distinguish-subcases clauses are marked
      satisfied; the exclude-by-default clause is explicitly noted as NOT newly implemented on
      the live dispatch path by this review-only stage, deferring to the Open Design Fork
      resolution below, since the plan's own Non-Goals explicitly bar this stage from becoming a
      fifth admission gate)*
- [x] In the same file's **Open Design Fork** section, record the resolution: **exclude the
      dependent task by default, never auto-expand the batch.** Justify it by the two existing
      precedents that already chose exclude-and-warn for structurally identical situations, and by
      the fact that an auto-expanded batch would require the full admission check applied to the
      newly-pulled-in predecessor before the expansion is safe — strictly more machinery on a
      less-tested path. Mark the fork resolved rather than deleting it, so the reasoning survives.
      *(completed)*
- [x] In `docs/architecture/batch-admit-schema.md`, add `scripts/orchestrate-predispatch-review.sh`
      as a fourth entry on the **Read by** list, naming it as a report composer that consumes the
      verdicts (the same relationship the dry-run reporter already has), not as a re-derivation.
      Keep the list accurate rather than letting the "exactly three sanctioned readers" claim
      quietly become false. *(completed; confirmed no literal "exactly three sanctioned readers"
      string exists elsewhere in this doc or others needing a parallel update)*
- [x] In `skills/skill-orchestrate/SKILL.md`, add a Stage MT-1 cross-reference noting that raw
      dependency review already happened upstream at `commands/orchestrate.md` Step 1.5, so the
      `dependency_graph` the skill receives arrives already reviewed — within the review stage's
      own stated limits. *(completed: cross-reference added; confirmed by reading Stage MT-1 that
      it only reads `dependency_graph` from delegation context and never rebuilds any part of it,
      so this phase closes doc-only, matching the plan's Scope Hypothesis)*
- [x] Verify no file outside `specs/**` gained a task-number citation, per the
      no-task-references-in-deliverables rule. *(completed: grepped all six changed files for
      task-number citation patterns; the only matches are pre-existing lines untouched by this
      task's diff — confirmed via `git diff` on each match)*

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: prose

**Scope Hypothesis**: This phase assumes `skills/skill-orchestrate/SKILL.md` needs a
documentation-only cross-reference and no code change, because Stage MT-1 receives an
already-built `dependency_graph` from the command's Step 2/3 output rather than rebuilding it.
Confirm at implementation time by reading Stage MT-1 and the `multi_task_mode=true` invocation
args; if the skill does rebuild any part of the graph, a code change is required and this phase
must be re-scoped rather than closed as doc-only.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` -
  Non-Negotiable 3 resolution; Open Design Fork resolution
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - fourth Read-by entry
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-1 cross-reference

**Verification**:
- Every changed hunk lies inside prose/markdown with no compile or elaboration surface, confirmed
  by diff read-through.
- Cross-references resolve: each named path and section heading exists.
- Grep across all changed files outside `specs/**` finds no "task N" citation pattern.

---

### Phase 6: Registration and full verification sweep [COMPLETED]

**Goal**: Register the new script, settle the `index-entries.json` question explicitly, and run the
complete gate set.

**Tasks**:
- [x] Add `"orchestrate-predispatch-review.sh"` to `manifest.json`'s `provides.scripts` array,
      matching the flat basename-relative-to-`scripts/` convention the existing orchestrate scripts
      use. *(completed; inserted alphabetically between orchestrate-dry-run-report.sh and
      orchestrate-recover-outcome.sh)*
- [x] Settle Scope Item D's `index-entries.json` half explicitly. This plan introduces no new file
      under `context/`, so no new entry is expected. Confirm that by enumerating the actual files
      created and modified; if the confirmation holds, record it as a reasoned exclusion on this
      phase rather than silently leaving the declared file untouched. *(completed: enumerated
      every file touched across Phases 1-5 — confirmed zero new files under `context/`, so the
      literal reading of Scope Item D was satisfied with no edit. See the follow-on item below,
      which closed the underlying coverage gap the confirmation exposed.)*
- [x] **Follow-on (operator-directed, closes the exposed gap)**: the confirmation above surfaced
      that `patterns/batch-orchestration-guardrails.md` — the file this task's Phase 5 wrote its
      Non-Negotiable 3 and Open Design Fork resolutions into — had no `index-entries.json` entry
      at all, so those resolutions were never auto-loadable via `load_when`. Two sibling files in
      the same cluster, `patterns/file-footprint-overlap.md` (the overlap predicate this task's
      report consumes) and `reference/orchestrator-critical-paths.json` (the critical-path
      declaration driving the `self_modifying` verdict), had the same gap. *(completed: all three
      entries appended to `index-entries.json` — 113 -> 116 entries — as a pure append with no
      reordering; `load_when.commands` includes `/orchestrate`, `task_types` includes `meta`.
      Indexing a `.json` reference file follows existing convention: `schemas/*.json` and
      `templates/state-template.json` are already indexed. Verified by redeploy —
      `verify-deploy.sh` PASS, 11 checks / 0 failures; `check-extension-docs.sh` exit 0 — and by
      confirming all three paths resolve in the merged `.claude/context/index.json`.)*
- [x] Verify the deploy pipeline still regenerates cleanly and the new script lands where both call
      sites expect it (`.claude/scripts/orchestrate-predispatch-review.sh`). *(completed via
      `bash .claude/scripts/deploy-headless.sh` — 272 artifacts deployed — and
      `bash .claude/scripts/verify-deploy.sh`, which reported PASS with 0 failures; incidentally
      this same regeneration also resolved TWO pre-existing, task-933-unrelated drift failures
      in `scripts/orchestrate-triage-classify.sh` and `scripts/skill-base.sh` left over from a
      prior task's un-redeployed source-store changes)*
- [x] Run `bash .claude/scripts/check-extension-docs.sh` and confirm it exits zero. *(completed:
      exit 0, "PASS: all extensions OK")*
- [x] Run the full end-to-end path: `/orchestrate --dry-run` over a real multi-task candidate set,
      confirming section 7 appears with live findings; and confirm the live path's Step 1.5 text is
      internally consistent with what the script actually prints. *(completed: ran
      `orchestrate-dry-run-report.sh 887 933 934 935` against the deployed tree — all 7 sections
      printed, section 7 present with live Class A/C findings; Step 1.5's advisory-loud prose in
      `commands/orchestrate.md` matches the script's actual report-only, non-blocking behavior)*
- [x] Confirm `specs/state.json` is unmodified by every non-`--repair` path exercised in this
      sweep. *(completed: `git diff --stat specs/state.json` shows only the pre-existing
      preflight status transition — not-started -> implementing — that predates this phase's
      testing; no additional diff appeared after any report-mode invocation)*

#### Resolved Exclusion (formerly a reasoned exclusion)

This phase originally closed as `[COMPLETED WITH EXCLUSIONS]` with one item: `index-entries.json`
left unmodified. That exclusion's reasoning was verified correct on its own terms — `git status
--porcelain` against `agent-system/extensions/core/` confirmed exactly one new file
(`scripts/orchestrate-predispatch-review.sh`, under `scripts/`, not `context/`) and five modified
files, with `context/patterns/batch-orchestration-guardrails.md` modified in place rather than
created. Zero new files landed under `context/`, so Scope Item D's literal wording ("any new
context file") was satisfied by no edit.

The exclusion was nonetheless **closed rather than deferred**, on operator direction, because the
confirmation exposed a live gap with direct bearing on this task's own deliverable: the guardrails
file carrying Phase 5's Non-Negotiable 3 and Open Design Fork resolutions was absent from
`index-entries.json` entirely, making those resolutions unreachable through `load_when`
auto-loading. Closing it required no `file_scope` widening — `index-entries.json` was already a
declared file. See the follow-on task bullet above for what was added and how it was verified.

No exclusions remain on this phase.

**Timing**: 1 hour

**Depends on**: 3, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that `index-entries.json` requires no change because no
new `context/` file is introduced. Confirm by listing every file created across Phases 1-5 and
checking whether any lives under `agent-system/extensions/core/context/`; if one does, add the
entry rather than closing this as an exclusion.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - add the new script to `provides.scripts`
- `agent-system/extensions/core/index-entries.json` - only if the confirmation above finds a new
  `context/` file; otherwise unmodified with a recorded reasoned exclusion

**Verification**:
- `jq . manifest.json` and `jq . index-entries.json` both parse.
- `check-extension-docs.sh` exits zero.
- The deployed `.claude/scripts/orchestrate-predispatch-review.sh` exists and is executable after
  regeneration.
- Full `/orchestrate --dry-run` run succeeds end to end with all seven sections printed.
- `git diff specs/state.json` is empty.

---

## Testing & Validation

- [ ] `bash -n` (and `shellcheck` where available) passes on both the new script and the modified
      reporter.
- [ ] The new script exits 0 on every findings outcome and 2 only on usage error or unavailable
      state, matching both sibling scripts' convention.
- [ ] All four defect classes produce findings against a candidate set constructed to exhibit them;
      classes with nothing to report print an explicit empty line, never nothing.
- [ ] Class A distinguishes all four dependency buckets, including `nonexistent` — the subcase no
      existing code path currently warns about at all.
- [ ] The degraded path (admit predicate unavailable) is reported explicitly and never silently
      empty.
- [ ] Default and `--dry-run` paths leave `specs/state.json` byte-identical.
- [ ] `--repair` is unreachable from any `/orchestrate` invocation, confirmed by grep.
- [ ] `--repair` normalizes only `null` array fields and refuses every dependency-edge rewrite.
- [ ] The dry-run report's original six sections keep their order and numbering.
- [ ] `check-extension-docs.sh` exits zero.
- [ ] No task-number citation appears in any file outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` (new)
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` (modified — section 7,
  Checks-run line, header)
- `agent-system/extensions/core/commands/orchestrate.md` (modified — Step 1.5, Step 2 prose)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified — Stage MT-1
  cross-reference)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (modified —
  Non-Negotiable 3 resolution, Open Design Fork resolution)
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` (modified — fourth
  sanctioned reader)
- `agent-system/extensions/core/manifest.json` (modified — script registration)
- `agent-system/extensions/core/index-entries.json` (conditional — see Phase 6)
- `specs/933_predispatch_dependency_and_file_scope_review/summaries/01_predispatch-review-repair-summary.md`

## Follow-Up Candidates (not in this task's scope)

- A test harness at `scripts/tests/test-orchestrate-predispatch-review.sh`, matching the existing
  `test-orchestrate-triage-classify.sh` precedent. Outside this task's declared `file_scope`.
- ~~The pre-existing `index-entries.json` coverage gap~~ — **closed in Phase 6** rather than
  deferred (operator-directed). All three files (`context/patterns/batch-orchestration-guardrails.md`,
  `context/patterns/file-footprint-overlap.md`, `context/reference/orchestrator-critical-paths.json`)
  now carry `index-entries.json` entries and are auto-loadable via `load_when`. See Phase 6's
  Resolved Exclusion section.

## Rollback/Contingency

Every change is additive and confined to eight files in the source store, all under version
control. Reverting is a `git revert` of the phase commits: deleting
`orchestrate-predispatch-review.sh`, removing the Step 1.5 block and the section-7 block, and
restoring the three documentation files and `manifest.json` returns both surfaces to their current
behavior with no residue. The one irreversible action is a `--repair` state write; because repair
is direct-invocation-only, prints a before/after diff, and touches only literal-`null` fields, any
unwanted normalization is recoverable from git history of `specs/state.json`. If Phase 4's
atomic-batch wiring lands only partially, revert that commit whole rather than patching forward —
a half-wired pair of surfaces is the precise defect this task exists to remove.
