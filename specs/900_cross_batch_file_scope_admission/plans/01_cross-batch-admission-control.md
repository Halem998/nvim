# Implementation Plan: Task #900

- **Task**: 900 - Cross-batch file_scope admission control for /orchestrate
- **Status**: [COMPLETED]
- **Effort**: 5.5 hours
- **Dependencies**: 898, 899 (both completed)
- **Research Inputs**: specs/900_cross_batch_file_scope_admission/reports/01_cross-batch-admission-control.md
- **Artifacts**: plans/01_cross-batch-admission-control.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`, a read-only,
blocking (defer-not-fail) admission predicate that compares each candidate task's `file_scope`
against **every non-terminal task in `specs/state.json`** — not just the tasks in the current
invocation, and not just the tasks currently holding a lock. It emits one NDJSON verdict line
per candidate under the pinned schema `orchestrate-batch-admit-v1`, then both existing call
sites (`commands/orchestrate.md` Step 3, `skills/skill-orchestrate/SKILL.md` Stage MT-3 step
4.5) replace their inline, invocation-scoped pairwise loop with a call to this script while
keeping their surrounding defer/log/reschedule behavior unchanged.

The work is sequenced contract-first-in-code: the script and its pinned output schema land and
are proven by a deterministic fixture test before either wiring edit is made, because a
downstream sibling task will build a report renderer directly against this schema.

### Research Integration

Findings carried directly into this plan:

- **The gap is live, not hypothetical.** Re-verified against `specs/state.json` while writing
  this plan: 7 unordered pairs of non-terminal tasks currently have overlapping `file_scope`
  with no `dependencies[]` edge (900↔902, 900↔906, 900↔907, 900↔908, 901↔907, 901↔908,
  906↔908). Phase 2's fixture is derived from these live entries, so the regression test
  reproduces a real collision rather than a constructed one.
- **Blocking, at any batch size.** The check satisfies both halves of the imported
  blocking-vs-advisory criterion (computable from on-disk state alone; harm of skipping is
  silent and hard to detect later), so it is blocking and defer-not-fail. This forces a
  semantic change at both call sites: the existing `2+ tasks` guard must be **removed**, since
  a cross-batch collision exists at batch size 1.
- **Terminal statuses are exactly `{completed, abandoned, expanded}`**, confirmed against
  `rules/state-management.md`. Every other status (`not_started`, `researching`, `researched`,
  `planning`, `planned`, `implementing`, `partial`, `pr_ready`/`PR READY`, `blocked`) is in the
  comparison set.
- **Do not fork the overlap predicate.** Mirror `task-lock.sh`'s `scopes_overlap()` jq
  transcription with a comment pointing at `.claude/context/patterns/file-footprint-overlap.md`;
  register the new script as that document's fourth named consumer (Phase 6).
- **`collision_scope`, never `severity`.** `severity` already carries two incompatible
  vocabularies in this codebase (`hard|soft` for handoff blockers; `critical|high|medium|low`
  for error/review issues). Field names and types are pinned verbatim in Phase 1 and published
  canonically in Phase 3.
- **False positives from coarse directory-prefix matching are accepted, not engineered around.**
  No CID/content-hash refinement, no second algorithm for this consumer.

Two constraints discovered while reading current on-disk source, not present in the research
report, and load-bearing for this plan:

1. `scripts/deploy-root-guard.sh` (sourced by every core script after root computation) **aborts
   any invocation from the source store** — `${SCRIPT_DIR%/*}` must end in `/.claude` or
   `/.opencode`. All verification in this plan therefore runs the script from a throwaway
   scratch deploy tree, never from `agent-system/` and never by writing into the real `.claude/`.
2. `check-extension-docs.sh` Rule E fails when a script is referenced in docs but absent from
   `manifest.provides.scripts`. Manifest registration must land in the **same phase** that
   creates the script (Phase 1), before any doc or wiring references it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no ROADMAP.md was consulted.

## Goals & Non-Goals

**Goals**:

- A new `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` that reads
  `specs/state.json` exactly once, compares each candidate against every non-terminal task, and
  emits one `orchestrate-batch-admit-v1` NDJSON verdict per candidate in input order.
- The verdict schema pinned by field name and type, published canonically under
  `docs/architecture/`, so the downstream report-renderer task can build against it without
  reading the script.
- Both existing call sites wired to the script, with their defer/log/reschedule behavior
  preserved and their `2+ tasks` guard removed.
- A deterministic, re-runnable test that reproduces a real cross-batch collision and asserts the
  exact verdict line.

**Non-Goals**:

- Any change to the overlap predicate itself, or a second/finer-grained algorithm for this
  consumer (CID hashing, glob/regex matching, content comparison).
- Any mutation of `state.json` by the new script — it is a pure predicate that only prints.
- Auto-expanding batch membership to fold an out-of-batch colliding task into the run. That
  needs its own admission gates and is explicitly out of scope.
- Any wiring into `skill-orchestrate-hard/SKILL.md` — hard mode delegates multi-task stages to
  base `skill-orchestrate` and has no independent copy of Stage MT-3 step 4.5.
- Any edit under `.claude/**`. Deployment to `.claude/` is a separate, user-driven step
  (`<leader>al`).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| An edit lands under `.claude/**` instead of the source store | H | M | Phase 6 verification greps the git diff for any `.claude/` path and fails the phase. Every phase's file list is source-store-only. |
| `deploy-root-guard.sh` makes the new script untestable in place | M | H | Phase 2 builds a scratch deploy tree (`$TMPDIR/.../proj/.claude/scripts/`) with a fixture `specs/state.json`; no writes to the real `.claude/`. |
| Cross-batch deferral starves a candidate forever (the colliding task is idle and in no batch, so it never advances) | M | M | Accepted and documented: the verdict is visible, names the colliding task and its status, and a human resolves batch composition. Recorded in the script header and schema doc so a later pass does not "fix" it by weakening the check. |
| A later maintainer reads the false-positive literature and relaxes the check to advisory | H | M | The script header and the schema doc both record, with the imported criterion as backing, why this check stays blocking. Required content in Phase 1 and Phase 3. |
| Removing the `2+ tasks` guard causes visible new defers on batches that previously ran clean | M | H | This is the intended behavior change, not a regression. Both call sites must log the cross-batch case with a distinct message so the cause is legible in the transcript. |
| Verdict field names drift from the downstream renderer's expectation | H | L | Field names, types, presence conditions, and key order are pinned in Phase 1, asserted by exact-line comparison in Phase 2, and published in Phase 3. |
| A live-state smoke test becomes flaky as tasks complete | L | H | Exact-value assertions live only in the frozen fixture. The live run asserts only the robust structural facts (`decision == "defer"`, `collision_scope == "cross_batch"`) and prints the full verdict for inspection. |
| `check-extension-docs.sh` Rule E flags the script mid-plan | L | M | Manifest registration lands in Phase 1 together with the script, before any reference to it exists. |
| Task-number citations leak into deliverables outside `specs/**` | M | M | Explicit MUST NOT in every phase that writes outside `specs/**`; Phase 6 greps the added lines for task-number citation patterns. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4, 5 | 3 |
| 4 | 6 | 4, 5 |

Phases within the same wave can execute in parallel. Phases 4 and 5 touch disjoint files
(`commands/orchestrate.md` vs `skills/skill-orchestrate/SKILL.md`) and are genuinely
parallelizable; Phases 2 and 3 touch disjoint trees (`specs/900_.../` vs `docs/`).

---

### Phase 1: Implement `orchestrate-batch-admit.sh` and register it [COMPLETED]

**Goal**: The admission predicate exists, is deployable, and pins the verdict schema in its own
header.

**Tasks**:

- [x] Create `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` with the standard
      core-script preamble, copied structurally from `task-lock.sh` lines 85-91:
      `set -uo pipefail`; `SCRIPT_DIR`; `PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"`;
      `. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1`;
      `STATE_FILE="$PROJECT_ROOT/specs/state.json"`.
- [x] Write the header comment block covering, in this order: purpose (close the cross-batch
      hole the three existing checks leave open); the by-path reference to
      `.claude/context/patterns/file-footprint-overlap.md` as the canonical predicate (state
      plainly that the algorithm is transcribed, not forked, and is never restated in prose
      here); the full verdict schema (`$schema`, `task_number`, `decision`,
      `colliding_task_number`, `colliding_task_status`, `overlapping_path`, `collision_scope`,
      `reason`) with types and presence conditions; the usage line; the exit codes; and a
      **"why this check is blocking, not advisory"** paragraph recording the criterion (on-disk
      computation only + silent, hard-to-detect harm if skipped) so it cannot be independently
      rediscovered and reversed.
- [x] Implement the CLI contract: `orchestrate-batch-admit.sh <task_number> [<task_number> ...]`.
      Zero arguments, or any argument that is not a non-negative integer, is a usage error:
      message on stderr, exit 2, nothing on stdout.
- [x] Implement the single-read requirement literally: exactly one read of `STATE_FILE` (a single
      `jq --slurpfile`/`--argjson` feed), no `find`, no glob, no second read, no per-candidate
      re-read. If `jq` is unavailable or `STATE_FILE` is missing/unparseable: print a loud
      one-line stderr notice naming the reason, emit nothing on stdout, exit 2.
- [x] Implement the comparison set: every entry in `active_projects` whose `status` is not one of
      `completed`, `abandoned`, `expanded` (compare case-insensitively so `PR READY` is handled),
      excluding the candidate itself. Cite `rules/state-management.md` in a code comment as the
      source of the terminal-status list.
- [x] Implement edge exclusion: skip any other task where a `dependencies[]` edge exists in
      either direction (candidate's `dependencies` contains the other's `project_number`, or the
      other's `dependencies` contains the candidate's).
- [x] Implement the deferral-direction rule exactly:
      - **in_batch** (the other task is itself one of the candidate arguments): the candidate
        defers only against a **lower** `project_number` — a higher-numbered in-batch task is the
        one that defers, so the candidate is unaffected by it. This preserves the existing
        wave-split behavior bit-for-bit.
      - **cross_batch** (the other task is not among the candidate arguments): the candidate
        defers **unconditionally**, regardless of `project_number` ordering, because an
        out-of-batch task cannot be deferred by this invocation.
- [x] Pin determinism: among the surviving comparison set, iterate in **ascending
      `project_number`** order and emit the verdict for the **first** overlapping task. Within
      that task, take the first overlapping path using `scopes_overlap()`'s convention (first
      match from the foreign scope, not an exhaustive list).
- [x] Transcribe the overlap predicate as a jq `def` mirroring `task-lock.sh`'s
      `scopes_overlap()` — `rtrimstr("/")` normalization, exact match or either-side `+ "/"`
      prefix — with a comment naming `file-footprint-overlap.md` as the source. Do not re-derive
      or paraphrase the rule.
- [x] Emit one compact JSON object per candidate, one per line, **in input order**, with keys in
      exactly this order: `$schema`, `task_number`, `decision`, then (defer only)
      `colliding_task_number`, `colliding_task_status`, `overlapping_path`, `collision_scope`,
      `reason`. `$schema` is the literal string `orchestrate-batch-admit-v1`. `task_number` and
      `colliding_task_number` are integers; all other values are strings.
- [x] Pin the `reason` template verbatim:
      `file_scope overlap with non-terminal task #{colliding_task_number} ({in this batch|not in this batch}) at {overlapping_path}; no dependencies[] edge between them`
      — machine-templated, never the sole carrier of any fact.
- [x] Handle the degenerate candidates: a candidate absent from `active_projects`, in a terminal
      status, or with a null/empty `file_scope` emits a plain `admit` verdict (no collision
      fields). Document each case in the header.
- [x] Exit 0 whenever verdicts were emitted successfully, regardless of how many are `defer` —
      verdicts are data, not errors. Never exit non-zero because a task was deferred, and never
      write to `state.json`.
- [x] `chmod +x` the script.
- [x] Add `orchestrate-batch-admit.sh` to `provides.scripts` in
      `agent-system/extensions/core/manifest.json`.

**MUST NOT**: cite any task number in the script header or comments (the
no-task-references-in-deliverables rule applies — reference `file-footprint-overlap.md`,
`rules/state-management.md`, and `task-lock.sh` by path instead); restate the overlap algorithm
in prose; read `state.json` more than once; touch `.claude/**`.

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - new script (the whole
  deliverable of this phase)
- `agent-system/extensions/core/manifest.json` - add the script to `provides.scripts`

**Verification**:

```bash
cd /home/benjamin/.config/nvim

# 1. File exists, is executable, and is syntactically valid bash
test -x agent-system/extensions/core/scripts/orchestrate-batch-admit.sh || echo "FAIL: not executable"
bash -n agent-system/extensions/core/scripts/orchestrate-batch-admit.sh && echo "OK: syntax"

# 2. Exactly one state.json read path; no filesystem scanning
test "$(grep -c 'STATE_FILE' agent-system/extensions/core/scripts/orchestrate-batch-admit.sh)" -ge 1 && echo "OK: STATE_FILE defined"
grep -nE '\bfind\b|\bls \b|\*/|glob' agent-system/extensions/core/scripts/orchestrate-batch-admit.sh \
  && echo "REVIEW: possible filesystem scan — must be none" || echo "OK: no filesystem scan"

# 3. Predicate referenced by path, not restated
grep -q 'file-footprint-overlap.md' agent-system/extensions/core/scripts/orchestrate-batch-admit.sh \
  && echo "OK: predicate referenced by path" || echo "FAIL: missing by-path reference"

# 4. Guard is sourced (required for every core script)
grep -q 'deploy-root-guard.sh' agent-system/extensions/core/scripts/orchestrate-batch-admit.sh \
  && echo "OK: guard sourced" || echo "FAIL: guard not sourced"

# 5. Schema literal is pinned exactly
grep -q 'orchestrate-batch-admit-v1' agent-system/extensions/core/scripts/orchestrate-batch-admit.sh \
  && echo "OK: schema literal present" || echo "FAIL: schema literal missing"

# 6. Registered in the manifest
jq -e '.provides.scripts | index("orchestrate-batch-admit.sh")' agent-system/extensions/core/manifest.json >/dev/null \
  && echo "OK: manifest registered" || echo "FAIL: not in provides.scripts"

# 7. No task-number citations in the new deliverable
grep -nEi '\btasks? +[0-9]{2,4}\b|\(task +[0-9]{2,4}\)' agent-system/extensions/core/scripts/orchestrate-batch-admit.sh \
  && echo "FAIL: task-number citation found" || echo "OK: no task-number citations"

# 8. Source-store rule: nothing under .claude/ was touched
git status --short | grep -E '^\s*[AM?]{1,2}\s+\.claude/' && echo "FAIL: .claude/ modified" || echo "OK: source store only"
```

---

### Phase 2: Deterministic fixture and verdict test suite [COMPLETED]

**Goal**: Every schema field, every exclusion rule, and both deferral directions are proven by a
re-runnable test, including an exact-line reproduction of a real cross-batch collision.

**Tasks**:

- [x] Create `specs/900_cross_batch_file_scope_admission/fixtures/state-cross-batch.json` — a
      minimal `state.json` whose `active_projects` entries are copied **verbatim** (fields
      `project_number`, `project_name`, `status`, `dependencies`, `file_scope`) from the live
      `specs/state.json` for tasks 900, 902, 906, and 907, plus two synthetic entries: one
      terminal (`status: "completed"`) task whose `file_scope` overlaps 900's, and one task
      declaring a scope that is a directory **with a trailing slash** containing another
      fixture task's declared file, with no edge between them.
- [x] Create `specs/900_cross_batch_file_scope_admission/tests/test-batch-admit.sh`. It must build
      a throwaway scratch deploy tree — `$(mktemp -d)/proj/.claude/scripts/` — copy
      `orchestrate-batch-admit.sh` and `deploy-root-guard.sh` into it, place the fixture at
      `$(mktemp -d)/proj/specs/state.json`, and invoke the copied script from there. This is what
      satisfies `deploy-root-guard.sh`. The test MUST NOT write anything into the repository's
      real `.claude/` directory, and MUST `rm -rf` its scratch tree on exit.
- [x] Assert each of the following, counting pass/fail and exiting non-zero on any failure:
      1. **Cross-batch defer, exact line.** Candidate `900` alone against the fixture emits
         exactly one line, `decision == "defer"`, `colliding_task_number == 902`,
         `collision_scope == "cross_batch"`,
         `overlapping_path == "agent-system/extensions/core/scripts/orchestrate-batch-admit.sh"`,
         `$schema == "orchestrate-batch-admit-v1"`, and the `reason` matching the pinned
         template. Compare the whole line against an expected literal so key order is asserted
         too.
      2. **In-batch defer preserves existing direction.** Candidates `900 902` emit two lines in
         input order: 900 `admit`, 902 `defer` with `colliding_task_number == 900` and
         `collision_scope == "in_batch"`. *(deviation: altered — 900's line reflects its genuine,
         independent cross_batch collision with 906 (verbatim fixture data), not `admit`; the
         in_batch direction property is still verified via 902's line. See
         `specs/900_cross_batch_file_scope_admission/progress/phase-2-progress.json` deviation
         2.3.)*
      3. **Terminal tasks are excluded.** A candidate whose only overlap is with the fixture's
         `completed` task emits `admit`.
      4. **Edge-linked pairs are excluded.** A candidate whose only overlap is with a task
         connected by a `dependencies[]` edge (in either direction) emits `admit`.
      5. **Trailing-slash directory prefix is detected.** The synthetic directory-vs-file pair
         emits `defer` with the containing directory or contained file as `overlapping_path`.
      6. **Well-formedness.** Output line count equals candidate count for every invocation
         above; every line parses as JSON (`jq -e . <<< "$line"`); verdict `task_number` values
         appear in input order.
      7. **Exit codes.** No arguments -> exit 2 with empty stdout. Non-integer argument -> exit 2.
         Missing `specs/state.json` in the scratch root -> exit 2, empty stdout, non-empty
         stderr. A run producing defers -> exit 0.
- [x] Add a final, clearly-labelled **live smoke check** to the same test script: copy the real
      `specs/state.json` into a second scratch root, run the script for candidate `900`, assert
      only `decision == "defer"` and `collision_scope == "cross_batch"` (robust while any of the
      live collisions persist), and print the full verdict line for human inspection. Comment in
      the script that exact-value assertions deliberately live in the frozen fixture because
      live state mutates as tasks complete.
- [x] Run the suite; fix the script (Phase 1 output) rather than the assertions if any pinned
      schema fact fails.

**MUST NOT**: write into the repository's real `.claude/` directory; assert exact task numbers
against live `specs/state.json`; place test or fixture files anywhere outside
`specs/900_cross_batch_file_scope_admission/`.

**Timing**: 1.25 hours

**Depends on**: 1

**Files to modify**:

- `specs/900_cross_batch_file_scope_admission/fixtures/state-cross-batch.json` - new frozen fixture
- `specs/900_cross_batch_file_scope_admission/tests/test-batch-admit.sh` - new test suite

**Verification**:

```bash
cd /home/benjamin/.config/nvim

# 1. Suite runs green
bash specs/900_cross_batch_file_scope_admission/tests/test-batch-admit.sh; echo "exit=$?"

# 2. Fixture is valid JSON with the expected shape
jq -e '.active_projects | length >= 6' specs/900_cross_batch_file_scope_admission/fixtures/state-cross-batch.json \
  && echo "OK: fixture shape"

# 3. Fixture entries for 900/902/906/907 match live state.json verbatim on the load-bearing fields
for n in 900 902 906 907; do
  a=$(jq -c --argjson n "$n" '.active_projects[] | select(.project_number==$n) | {status,dependencies,file_scope}' \
        specs/state.json)
  b=$(jq -c --argjson n "$n" '.active_projects[] | select(.project_number==$n) | {status,dependencies,file_scope}' \
        specs/900_cross_batch_file_scope_admission/fixtures/state-cross-batch.json)
  [ "$a" = "$b" ] && echo "OK: fixture $n matches live" || echo "NOTE: fixture $n diverges from live (expected once the task advances)"
done

# 4. The test left no scratch tree behind and never touched the real .claude/
git status --short | grep -E '^\s*[AM?]{1,2}\s+\.claude/' && echo "FAIL: .claude/ modified" || echo "OK: .claude/ untouched"
```

---

### Phase 3: Publish the canonical verdict schema document [COMPLETED]

**Goal**: The `orchestrate-batch-admit-v1` contract has one citable, canonical location so the
downstream report-renderer task builds against a document, not a script's comments.

**Tasks**:

- [x] Create `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`, modelled on
      the existing `handoff-schema.md` in the same directory (same heading style, same
      field-by-field structure, same example-then-table layout).
- [x] Document the invocation contract: arguments are the candidate task numbers (the caller's
      already-computed `validated_tasks`/`task_numbers`), output is NDJSON on stdout with one
      object per candidate in input order, exit 0 on success and 2 on usage/unavailable-state.
- [x] Document every field with name, type, presence condition, and meaning — `$schema`,
      `task_number`, `decision` (`admit|defer`, never `fail`), `colliding_task_number`,
      `colliding_task_status`, `overlapping_path`, `collision_scope` (`in_batch|cross_batch`),
      `reason`. State that key order is stable and that `reason` never carries a fact unavailable
      as a structured field.
- [x] Document the deferral-direction rule for both `collision_scope` values, and state plainly
      what a caller should do with each: `in_batch` resolves by ordinary same-run deferral;
      `cross_batch` means the requested candidate is excluded from this invocation and the
      colliding task is surfaced for human batch-composition judgment — explicitly **not** a
      correctness verdict on the candidate task, and explicitly **not** an instruction to fold
      the out-of-batch task into the run.
- [x] Record two things a later maintainer must not undo: (a) why this check is blocking rather
      than advisory (on-disk-only computation plus silent, hard-to-detect harm), and (b) why the
      field is named `collision_scope` rather than `severity` (that name already carries two
      incompatible vocabularies in this codebase — `hard|soft` for handoff blockers,
      `critical|high|medium|low` for error/review issues).
- [x] Note the accepted false-positive profile of directory-prefix matching: a task declaring a
      whole directory as its scope will defer against anything beneath it, and that cost is
      accepted rather than engineered around.
- [x] Add an index entry to `agent-system/extensions/core/docs/README.md` alongside the existing
      `Handoff Schema` line.

**MUST NOT**: cite any task number anywhere in either file; restate the overlap algorithm
(reference `.claude/context/patterns/file-footprint-overlap.md` by path); duplicate the field
table into any other document.

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - new schema document
- `agent-system/extensions/core/docs/README.md` - index entry next to the Handoff Schema line

**Verification**:

```bash
cd /home/benjamin/.config/nvim
DOC=agent-system/extensions/core/docs/architecture/batch-admit-schema.md

# 1. Document exists and pins every schema field name
test -f "$DOC" || echo "FAIL: schema doc missing"
for f in '\$schema' 'task_number' 'decision' 'colliding_task_number' 'colliding_task_status' \
         'overlapping_path' 'collision_scope' 'reason' 'orchestrate-batch-admit-v1' \
         'in_batch' 'cross_batch'; do
  grep -q "$f" "$DOC" && echo "OK: $f" || echo "FAIL: missing $f"
done

# 2. Records the blocking rationale and the severity-naming rationale
grep -qi 'blocking' "$DOC" && echo "OK: blocking rationale" || echo "FAIL: blocking rationale absent"
grep -q 'severity' "$DOC" && echo "OK: naming rationale" || echo "FAIL: naming rationale absent"

# 3. References the canonical predicate by path, does not restate it
grep -q 'file-footprint-overlap.md' "$DOC" && echo "OK: by-path reference" || echo "FAIL"
grep -qi 'rtrimstr\|startswith' "$DOC" && echo "REVIEW: possible algorithm restatement" || echo "OK: no restatement"

# 4. Indexed from the docs README
grep -q 'batch-admit-schema.md' agent-system/extensions/core/docs/README.md \
  && echo "OK: indexed" || echo "FAIL: not indexed"

# 5. No task-number citations
grep -nEi '\btasks? +[0-9]{2,4}\b|\(task +[0-9]{2,4}\)' "$DOC" agent-system/extensions/core/docs/README.md \
  | grep -v '^agent-system/extensions/core/docs/README.md' \
  && echo "FAIL: task-number citation in new content" || echo "OK: no new task-number citations"

# 6. Every example line in the doc is valid JSON
grep -oE '^\{"\$schema".*\}$' "$DOC" | while IFS= read -r l; do
  jq -e . >/dev/null 2>&1 <<< "$l" && echo "OK: example parses" || echo "FAIL: example is not valid JSON"
done
```

---

### Phase 4: Wire `commands/orchestrate.md` Step 3 [COMPLETED]

**Goal**: The pre-computed wave schedule consults the script instead of its own
invocation-scoped inline loop, with unchanged defer/log semantics and the batch-size guard
removed.

**Tasks**:

- [x] Re-read the current on-disk `agent-system/extensions/core/commands/orchestrate.md` Step 3
      section before editing. Do not trust line numbers quoted anywhere in this plan or in the
      research report — locate the section by its heading text and by the string
      `Runtime wave-split check (cross-batch defense-in-depth)`.
- [x] Replace the inline mechanism in that paragraph with a call to
      `bash .claude/scripts/orchestrate-batch-admit.sh "${wave_tasks[@]}"` (deployed path, per
      this repository's convention for prose references in source-store files), executed before
      dispatching each wave.
- [x] **Remove the `2+ tasks` precondition.** The current text reads "Before dispatching any wave
      with 2+ tasks"; the new text must run the check for every wave including single-task waves,
      because a cross-batch collision exists at batch size 1. State this explicitly so the change
      reads as intentional.
- [x] **Correct the scope claim.** The current text says the check reads `file_scope` "only for
      the tasks already collected into `validated_tasks` for this invocation — no repo-wide
      scan." That is no longer accurate. The replacement must say the check compares each
      candidate against every non-terminal task in a single `specs/state.json` read, and that
      this is still not a repo-wide filesystem scan (no globbing, no second read).
- [x] Show the caller-side handling: `jq`-filter stdout for `.decision == "defer"`, then branch on
      `collision_scope` — `in_batch` defers the named task to the next wave (existing behavior,
      existing warning format preserved); `cross_batch` excludes the candidate from this
      invocation's admitted set and logs a **distinct** warning naming the out-of-batch task and
      its `colliding_task_status`, so the transcript distinguishes "resolves by waiting one wave"
      from "this batch's composition is contested".
- [x] State the defer-not-fail invariant explicitly: the check never marks a task failed and
      never mutates `state.json`.
- [x] Document the degradation path: exit 2 means state is unavailable (missing `jq` or
      unreadable `specs/state.json`), in which case log a loud warning and proceed without the
      check — noting that orchestration cannot function at all in that condition, so this is not
      a silent weakening of the gate.
- [x] Reference `.claude/docs/architecture/batch-admit-schema.md` by path for the verdict schema
      rather than restating the fields; keep the existing by-path reference to
      `.claude/context/patterns/file-footprint-overlap.md`.

**MUST NOT**: add any task-number citation to this file (the existing rollback pointer to a
`specs/.../plans/...` path may be updated or retained as-is, but no new `task N` prose); restate
the schema field table; restate the overlap algorithm; edit `.claude/commands/orchestrate.md`.

**Timing**: 0.75 hours

**Depends on**: 3

**Files to modify**:

- `agent-system/extensions/core/commands/orchestrate.md` - Step 3 wave-split check section

**Verification**:

```bash
cd /home/benjamin/.config/nvim
F=agent-system/extensions/core/commands/orchestrate.md

# 1. The script is invoked, by its deployed path
grep -q '\.claude/scripts/orchestrate-batch-admit\.sh' "$F" && echo "OK: script wired" || echo "FAIL: not wired"

# 2. The stale invocation-scoped claim is gone
grep -q 'already collected into `validated_tasks` for this invocation' "$F" \
  && echo "FAIL: stale scope claim remains" || echo "OK: scope claim updated"

# 3. The 2+ guard is gone
grep -qi 'wave with 2+ tasks' "$F" && echo "FAIL: 2+ guard remains" || echo "OK: guard removed"

# 4. Both collision_scope branches are handled
grep -q 'in_batch' "$F" && grep -q 'cross_batch' "$F" && echo "OK: both branches" || echo "FAIL: missing branch"

# 5. Defer-not-fail invariant stated; schema referenced by path
grep -qi 'defer' "$F" && echo "OK: defer language present"
grep -q 'batch-admit-schema.md' "$F" && echo "OK: schema referenced" || echo "FAIL: schema not referenced"

# 6. Predicate still referenced by path, still not restated
grep -q 'file-footprint-overlap.md' "$F" && echo "OK: predicate by path" || echo "FAIL"

# 7. No NEW task-number citations (compare against the diff, not the whole file)
git diff -- "$F" | grep '^+' | grep -vE '^\+\+\+' \
  | grep -nEi '\btasks? +[0-9]{2,4}\b|\(task +[0-9]{2,4}\)' \
  && echo "FAIL: new task-number citation" || echo "OK: none added"

# 8. Source store only
git status --short | grep -E '^\s*[AM?]{1,2}\s+\.claude/' && echo "FAIL: .claude/ modified" || echo "OK"
```

---

### Phase 5: Wire `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 [COMPLETED]

**Goal**: The per-cycle eligibility gate consults the script, mirroring Phase 4's semantics for
cycle-by-cycle dispatch.

**Tasks**:

- [x] Re-read the current on-disk
      `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` before editing. This file
      has been modified by sibling work during this batch (a Stage 5 recovery-grep block, and
      `skill_gate_completion_claim` calls at Stage 5 and Stage MT-4). Locate step 4.5 by its
      heading text `Runtime wave-split check (cross-batch defense-in-depth)` within
      `### Stage MT-3`, never by a quoted line number.
- [x] Replace the inline pairwise mechanism with
      `bash .claude/scripts/orchestrate-batch-admit.sh "${eligible_tasks[@]}"`, run before Stage
      MT-4 dispatch on each cycle.
- [x] **Remove the `2+ tasks` precondition** ("Before dispatching `eligible_tasks` when it
      contains 2+ tasks"), for the same reason as Phase 4.
- [x] **Correct the scope claim** ("read only for the tasks already in `task_numbers` for this
      invocation — no repo-wide scan") to describe the actual new behavior: comparison against
      every non-terminal task via a single `specs/state.json` read, still with no filesystem
      globbing.
- [x] Preserve the surrounding cycle semantics verbatim: a deferred task is removed from **this
      cycle's** dispatch batch, is never added to `failed_tasks`, and becomes eligible again on a
      later cycle. Keep the existing warning block for `in_batch` and add a distinct one for
      `cross_batch` naming the out-of-batch task number and its `colliding_task_status`.
- [x] Keep the cross-reference to `orchestrate.md` Step 3 as the mirrored site, updating its
      wording so the two descriptions stay consistent after Phase 4's edit (both now describe a
      script call, not an inline loop).
- [x] Note the interaction with the existing task-lock acquire step in Stage MT-4: admission runs
      **before** lock acquisition and is a distinct gate (admission compares declared scopes of
      all non-terminal tasks; the lock compares against currently-held locks only). Neither
      replaces the other.
- [x] Document the exit-2 degradation path identically to Phase 4.
- [x] Reference `.claude/docs/architecture/batch-admit-schema.md` by path for the schema.

**MUST NOT**: add task-number citations; restate the schema or the overlap algorithm; alter Stage
MT-4's lock-acquire behavior; edit `.claude/skills/skill-orchestrate/SKILL.md`; disturb the
sibling-added Stage 5 recovery-grep block or the `skill_gate_completion_claim` calls.

**Timing**: 0.75 hours

**Depends on**: 3

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-3 step 4.5

**Verification**:

```bash
cd /home/benjamin/.config/nvim
F=agent-system/extensions/core/skills/skill-orchestrate/SKILL.md

# 1. Script wired at the right stage
grep -q '\.claude/scripts/orchestrate-batch-admit\.sh' "$F" && echo "OK: script wired" || echo "FAIL"
awk '/### Stage MT-3/,/### Stage MT-4/' "$F" | grep -q 'orchestrate-batch-admit.sh' \
  && echo "OK: wired inside Stage MT-3" || echo "FAIL: not inside Stage MT-3"

# 2. Stale claims and the 2+ guard are gone
grep -q 'already in `task_numbers` for this invocation' "$F" && echo "FAIL: stale scope claim" || echo "OK"
grep -qi 'when it contains 2+ tasks' "$F" && echo "FAIL: 2+ guard remains" || echo "OK: guard removed"

# 3. Both branches handled; defer-not-fail preserved
grep -q 'in_batch' "$F" && grep -q 'cross_batch' "$F" && echo "OK: both branches" || echo "FAIL"
grep -q 'failed_tasks' "$F" && echo "OK: failed_tasks language still present"

# 4. Schema referenced by path
grep -q 'batch-admit-schema.md' "$F" && echo "OK: schema referenced" || echo "FAIL"

# 5. Sibling work untouched
grep -q 'skill_gate_completion_claim' "$F" && echo "OK: completion-claim gate intact" || echo "FAIL: sibling work lost"

# 6. No NEW task-number citations
git diff -- "$F" | grep '^+' | grep -vE '^\+\+\+' \
  | grep -nEi '\btasks? +[0-9]{2,4}\b|\(task +[0-9]{2,4}\)' \
  && echo "FAIL: new task-number citation" || echo "OK: none added"

# 7. Source store only
git status --short | grep -E '^\s*[AM?]{1,2}\s+\.claude/' && echo "FAIL: .claude/ modified" || echo "OK"
```

---

### Phase 6: Register the fourth consumer and run whole-system verification [COMPLETED]

**Goal**: `file-footprint-overlap.md` remains the complete index of callers, and the full change
passes the repository's own doc-lint and wiring gates.

**Tasks**:

- [x] Edit `agent-system/extensions/core/context/patterns/file-footprint-overlap.md`:
      - Change "This algorithm has three callers, at the task, phase, and lock-acquisition
        levels" to four callers, adding batch-admission-level.
      - Add a **Batch-admission-level** bullet naming
        `.claude/scripts/orchestrate-batch-admit.sh`, describing its scan scope (every
        non-terminal task in `state.json`, one read, no filesystem scan) and its consumers
        (`orchestrate.md` Step 3, `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5).
      - Change "All three callers reference this document by path" to "All four".
      - Update the Non-Goals scan-scope note, which currently contrasts exactly two usages
        ("Both usages are in scope"), so it accommodates the third scan scope without weakening
        the "this document defines the predicate only" statement.
- [x] Run the repository's doc-lint and wiring validators and resolve anything the change
      introduced. Pre-existing findings unrelated to this change are recorded, not fixed here.
- [x] Re-run the Phase 2 test suite end-to-end as a final regression gate.
- [x] Confirm the complete diff touches only `agent-system/extensions/core/**` and
      `specs/900_cross_batch_file_scope_admission/**`.

**MUST NOT**: add task-number citations to the new bullet (the file already contains a
pre-existing `(task 809)` citation — leave it alone, do not add another); restate the predicate;
edit `.claude/context/patterns/file-footprint-overlap.md`.

**Timing**: 0.75 hours

**Depends on**: 4, 5

**Files to modify**:

- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` - Consumers section
  and Non-Goals scan-scope note

**Verification**:

```bash
cd /home/benjamin/.config/nvim
P=agent-system/extensions/core/context/patterns/file-footprint-overlap.md

# 1. Fourth consumer registered and the count updated
grep -q 'orchestrate-batch-admit.sh' "$P" && echo "OK: consumer added" || echo "FAIL: consumer missing"
grep -q 'three callers' "$P" && echo "FAIL: count not updated" || echo "OK: count updated"
grep -q 'All three callers' "$P" && echo "FAIL: closing sentence not updated" || echo "OK"
grep -qi 'four' "$P" && echo "OK: four callers stated" || echo "FAIL"

# 2. No new task-number citations in the added lines
git diff -- "$P" | grep '^+' | grep -vE '^\+\+\+' \
  | grep -nEi '\btasks? +[0-9]{2,4}\b|\(task +[0-9]{2,4}\)' \
  && echo "FAIL: new task-number citation" || echo "OK: none added"

# 3. Repository doc-lint and wiring gates
bash .claude/scripts/check-extension-docs.sh; echo "check-extension-docs exit=$?"
bash .claude/scripts/validate-wiring.sh; echo "validate-wiring exit=$?"
bash .claude/scripts/validate-extension-index.sh; echo "validate-extension-index exit=$?"

# 4. Full regression re-run
bash specs/900_cross_batch_file_scope_admission/tests/test-batch-admit.sh; echo "tests exit=$?"

# 5. Source-store rule over the WHOLE change
git status --short | grep -E '\.claude/' && echo "FAIL: .claude/ touched" || echo "OK: no .claude/ changes"
git status --short | grep -vE 'agent-system/extensions/core/|specs/900_cross_batch_file_scope_admission/|specs/state.json|specs/TODO.md|specs/events.jsonl' \
  && echo "REVIEW: out-of-scope paths in the working tree" || echo "OK: change confined to expected paths"

# 6. Every bash deliverable still parses
bash -n agent-system/extensions/core/scripts/orchestrate-batch-admit.sh && echo "OK: script syntax"
bash -n specs/900_cross_batch_file_scope_admission/tests/test-batch-admit.sh && echo "OK: test syntax"
```

---

## Testing & Validation

- [x] `orchestrate-batch-admit.sh` passes `bash -n` and is executable.
- [x] Every fixture assertion in Phase 2 passes, including the exact-line cross-batch verdict and
      the exact-line in-batch verdict.
- [x] The live smoke check reproduces a real cross-batch collision against the current
      `specs/state.json` (`decision == "defer"`, `collision_scope == "cross_batch"`).
- [x] Terminal tasks, edge-linked pairs, empty/absent `file_scope`, and unknown candidates all
      resolve to `admit`.
- [x] Trailing-slash directory entries overlap files beneath them.
- [x] Exit codes: 0 with verdicts (including defers), 2 for usage errors and unavailable state,
      never non-zero merely because a task was deferred.
- [x] Output is valid NDJSON, one line per candidate, in input order, with stable key order.
- [x] The script never writes to `specs/state.json` (verify by checksumming the scratch fixture
      before and after a run).
- [x] Both call sites invoke the script, handle both `collision_scope` values, and no longer
      carry a `2+ tasks` guard or an invocation-scoped scan claim.
- [x] `check-extension-docs.sh`, `validate-wiring.sh`, and `validate-extension-index.sh` report no
      new findings attributable to this change.
- [x] No file under `.claude/**` was modified.
- [x] No task-number citation was added to any file outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (new)
- `agent-system/extensions/core/manifest.json` (modified — `provides.scripts`)
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` (new)
- `agent-system/extensions/core/docs/README.md` (modified — index entry)
- `agent-system/extensions/core/commands/orchestrate.md` (modified — Step 3)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified — Stage MT-3 step 4.5)
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` (modified — Consumers)
- `specs/900_cross_batch_file_scope_admission/fixtures/state-cross-batch.json` (new)
- `specs/900_cross_batch_file_scope_admission/tests/test-batch-admit.sh` (new)
- `specs/900_cross_batch_file_scope_admission/summaries/01_*-summary.md` (at completion)

**Deployment note**: nothing in this plan deploys to `.claude/`. The new script and the edited
commands/skills/context/docs reach the running system only after a user-driven sync
(`<leader>al`, "Load Core"). Until then the wiring text is authored but the script is not on the
deployed path — expected, and not a defect to work around by writing into `.claude/`.

## Rollback/Contingency

- **Per-phase**: every phase is a self-contained, independently committed change. Reverting a
  single phase's commit restores the prior state without touching the others.
- **If the check proves too aggressive in practice** (over-deferring on cross-batch pairs that
  are not real conflicts): the correct response is **not** to relax it to advisory — the schema
  doc and script header record why. The available levers are (a) narrowing task authors'
  declared `file_scope` from directory granularity to file granularity, which is where the false
  positives actually originate, and (b) reverting the two wiring phases (4 and 5) while leaving
  the script and its schema in place for the downstream report renderer, which restores the
  previous in-batch-only behavior exactly.
- **If the script cannot be made deterministic under some state.json shape**: revert Phases 4
  and 5 only. The pre-existing inline check text is recoverable verbatim from git history for
  both files, and the previous behavior returns intact.
- **Full rollback**: revert all six phase commits. The system returns to the three existing
  checks with the cross-batch hole open — the state it is in today.
