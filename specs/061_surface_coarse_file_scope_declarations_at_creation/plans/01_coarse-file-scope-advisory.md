# Implementation Plan: Task #61

- **Task**: 61 - Surface coarse file_scope declarations at creation
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: 59 (completed)
- **Research Inputs**: specs/061_surface_coarse_file_scope_declarations_at_creation/reports/01_coarse-file-scope-detection.md
- **Artifacts**: plans/01_coarse-file-scope-advisory.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add two new WARN-only base-mode checks to `scripts/validate-state.sh` — Check 8 (coarse,
whole-directory-root `file_scope` declarations, triggered by measured blast radius) and Check 9
(duplicate `file_scope` entries) — plus an opt-in `--fix` flag that removes exact-duplicate
entries through the mutex-guarded writer, and a new advisory Step 6.5 in `commands/task.md`'s
Create Task Mode that surfaces those warnings at task-creation time. Every new check is
`log_warn`-only and every new output path is advisory: task creation, the git commit, and
`verify-deploy.sh` Gate 10 all proceed unchanged regardless of what is found. All edits target the
SOURCE STORE under `agent-system/extensions/core/`, never the deployed `.claude/` copies.

### Research Integration

Findings carried directly into this plan:

- **`log_warn`, never `log_fail`** — `verify-deploy.sh` Gate 10 (line 470) treats
  `validate-state.sh`'s exit code as the deploy pass/fail signal, and `validate-state.sh` exits 0
  on a WARN-only run (lines 526-535). A `log_fail` would turn task 44's existing declaration into
  an immediate deploy blocker. This is the mechanical enforcement of "advisory, not blocking".
- **Reuse, never re-derive, the overlap predicate** — blast radius is computed by splicing
  `FILE_SCOPE_OVERLAP_JQ_DEFS` from `scripts/lib/file-scope-overlap.sh` into the check's own
  `jq -n` program (the `orchestrate-batch-admit.sh` consumption shape). That library's own header
  states it is the only place the algorithm is written down as code.
- **Base mode, not `--deep`** — the new checks need only `active_projects[].file_scope` and
  `.status`; no git history. Base mode keeps them fast enough for an interactive `/task` call.
- **Whole-population scan, not new-task-only** — Create Task Mode never sets `file_scope` for the
  task it creates (confirmed: Step 6's `state-write.sh` filter omits the field entirely), so the
  advisory necessarily scans the whole post-write `active_projects[]` population. This is what
  surfaces declarations already sitting in state.
- **`--fix` precedent** — `validate-return-meta.sh --fix` (lines 129-160): opt-in only, never
  implicit, repair-then-revalidate.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap consultation performed.

## Resolved Design Decisions

These were open questions at research time. They are decided here so the implementer does not
re-litigate them.

### D1 — Coarseness trigger: blast-radius-driven, with a trailing-slash structural pre-filter

**Decision**: an entry is flagged coarse iff BOTH hold:
1. **Structural pre-filter**: the entry string, as declared (pre-normalization), ends with `/`.
2. **Blast radius**: the entry overlaps at least `N` *distinct other non-terminal* tasks, where
   overlap is `scopes_overlap_first` from `scripts/lib/file-scope-overlap.sh` and non-terminal
   means status not in `{completed, abandoned, expanded}`. Both sides of the comparison are
   filtered to non-terminal.

**Default `N` = 3**, overridable via the environment variable
`FILE_SCOPE_COARSE_MIN_OVERLAP` (integer; a non-integer value is a hard error, exit 2 — never a
silent fallback, matching the `--allow-artifact-removal` malformed-value posture at lines 96-111).

**Calibration evidence** (measured against the live `specs/state.json` during planning, using the
canonical predicate; 111 total `file_scope` entries, 12 of them directory-shaped, 23 non-terminal
tasks carrying a non-empty `file_scope`):

| Task | Entry | Distinct non-terminal overlaps |
|------|-------|-------------------------------|
| 48 | `agent-system/extensions/` | 21 |
| 50 | `agent-system/extensions/` | 21 |
| 44 | `agent-system/extensions/core/context/` | 8 |
| 31 | `agent-system/extensions/core/scripts/lint/` | 4 |
| 42 | `agent-system/extensions/core/scripts/lint/` | 4 |
| 9 | `agent-system/extensions/core/context/orchestration/` | 3 |
| 20 | `agent-system/extensions/core/scripts/tests/` | 2 |
| 43 | `agent-system/extensions/email/agents/` | 2 |
| 43 | `agent-system/extensions/email/skills/` | 2 |
| 50 | `agent-system/extensions/core/scripts/tests/` | 2 |
| 18 | `lua/neotex/plugins/ai/claude/extensions/` | 0 |
| 31 | `.opencode/extensions/` | 0 |

At `N=3` this yields 6 warnings covering exactly the genuinely broad declarations and excludes
both the narrow 2-overlap cases and the two legitimately-scoped 0-overlap directories. At `N=2` it
would yield 10. `N=3` is the default; the env var exists so the threshold can be tuned without a
code edit.

**Why not a path-depth heuristic**: rejected per the research. A depth threshold cannot be made
repo-shape-agnostic (this monorepo nests everything under `agent-system/extensions/core/`, so
task 44's 4-segment entry and a small repo's 1-segment `docs/` are the same defect at different
depths), and it ties the warning to a proxy rather than to the task's own stated rationale — "a
warning that names the concrete blast radius rather than a generic caution".

**Accepted known limitation (documented, not fixed)**: a directory declared *without* a trailing
slash (`agent-system/extensions/core/context`) is not flagged. The alternative structural signal —
"last segment has no file extension" — produces false positives on every extensionless file, and
this repo declares its directories with trailing slashes in all 12 live cases. Record this
limitation in the script header; do not widen the pre-filter.

**Must not**: do not hardcode or consult `context/reference/orchestrator-critical-paths.json`'s
`scope_roots` / `critical_paths`. That is `orchestrate-predispatch-review.sh`'s Class C
self-modification feature (any task vs. a fixed critical-path registry) — a different mechanism
from this one (any task vs. any other non-terminal task). They stay independent.

### D2 — Duplicate detection: two distinct classes, only one of them repairable

- **Class A, exact duplicates**: the same string appears twice in one `file_scope` array. WARN, and
  repairable by `--fix`.
- **Class B, normalization-equivalent duplicates**: two entries differ only by a trailing slash
  (`a/` vs `a`), i.e. they are distinct strings that `norm` collapses. WARN, reported as a
  separate, explicitly-labelled class, and **never** auto-repaired — choosing which spelling
  survives is a judgment call, and `--fix` must remain a mechanically unambiguous transform.

Live baseline: zero hits of either class in the current `specs/state.json`, so adding these checks
surfaces no pre-existing noise.

### D3 — `--fix` writes only through the deployed `state-write.sh`, or refuses loudly

`scripts/state-write.sh` is the single mutex-guarded writer for `specs/state.json`; hand-rolling a
`jq > tmp && mv` sequence inside `validate-state.sh` would reopen exactly the two corruption
channels that script's header says it exists to close. But `state-write.sh` carries a
deploy-root guard: **it refuses to run from the source store** (verified during planning — the
source-store copy exits with "must run from a deployed scripts/ tree"), while `validate-state.sh`
is deliberately guard-free so it runs from both trees.

**Decision**: `--fix` resolves a `state-write.sh` whose own path matches `*/.claude/scripts/` or
`*/.opencode/scripts/` (candidates in order: `$SCRIPT_DIR/state-write.sh`,
`$SCRIPT_DIR/../../.claude/scripts/state-write.sh`, then
`<git toplevel of STATE_FILE's directory>/.claude/scripts/state-write.sh`). If no deployed copy is
found, `--fix` exits 2 with a named message telling the caller to deploy first. It never falls back
to an in-script write.

Invocation shape: `--state-file "<absolute path to STATE_FILE>"`, `--session-id` (self-generated
via the portable `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')` pattern already
used by Create Task Mode and Sync Mode; also accept an optional `--session-id` passthrough on
`validate-state.sh` itself). **No `--regen-todo`** — `file_scope` is not rendered into TODO.md, and
`--regen-todo` is refused outright when combined with a non-default `--state-file`.

Verified during planning: the *deployed* `state-write.sh` writes an out-of-tree fixture correctly
when given an absolute `--state-file`, so the Phase 6 `--fix` regression fixture works from a temp
workdir.

Order-preserving dedup filter (jq; `unique` sorts and must not be used):
`reduce .[] as $x ([]; if index($x) then . else . + [$x] end)`.

### D4 — `--help` range must move with the header

`validate-state.sh`'s `--help` is `sed -n '2,74p' "$0"` (line 116) — a hardcoded line range over
its own header comment. Every phase that adds header documentation MUST update that range in the
same edit, and confirm `--help` still renders the whole header and nothing past it. This is a
silent-breakage trap, not a nicety.

## Goals & Non-Goals

**Goals**:
- A WARN-only base-mode Check 8 in `validate-state.sh` that names, per flagged entry, the owning
  task number, the entry string, the distinct blast-radius count, and the overlapping task numbers.
- A WARN-only base-mode Check 9 reporting exact and normalization-equivalent duplicate
  `file_scope` entries as two labelled classes.
- An opt-in `--fix` flag that removes exact-duplicate entries in place via the deployed
  `state-write.sh`, then re-validates.
- A Step 6.5 in `commands/task.md` Create Task Mode that runs the deployed `validate-state.sh`
  (base mode) after the Step 6 state write and surfaces `[WARN]` lines inline.
- Regression fixtures proving each new check fires AND that a seeded coarse/duplicate fixture still
  exits 0.

**Non-Goals**:
- No `log_fail` anywhere in the new code, and no change to any existing check's severity.
- No blocking of task creation, the Step 7 git commit, or `verify-deploy.sh` Gate 10.
- No auto-repair of coarse declarations (narrowing a directory scope needs human judgment) and no
  auto-repair of Class B normalization-equivalent duplicates.
- No second runtime gate: `task.md` Step 6.5 is the only new invocation site.
- No edits to `agents/meta-builder-agent.md` Component 4a (the site that actually populates
  `file_scope` for most tasks) — a natural follow-up, explicitly out of scope.
- No "Declaration Quality" subsection added to `context/patterns/file-footprint-overlap.md` — the
  research recommends it; it is out of declared scope and belongs to a follow-up task.
- No edits to `orchestrate-predispatch-review.sh` Class C or to
  `context/reference/orchestrator-critical-paths.json`.
- No hand-authored edits under `.claude/**` (deploy artifact; regenerate via
  `.claude/scripts/deploy-headless.sh` instead).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new check implemented as `log_fail` breaks `verify-deploy.sh` Gate 10 against live state (task 44 would trip it today) | H | M | `log_warn` exclusively; Phase 6 fixture asserts exit 0 on a seeded coarse+duplicate fixture; Phase 6 runs Gate 10 for real |
| Overlap/normalize logic re-derived inline, creating a second drifting copy of the predicate | H | M | Splice `FILE_SCOPE_OVERLAP_JQ_DEFS`; Phase 2 verification greps the diff for any locally-written `rtrimstr`/`startswith` normalize logic |
| `--help` breaks silently because the `sed -n '2,74p'` range was not moved | M | H | D4; each header-touching phase re-runs `--help` and eyeballs first/last lines |
| `--fix` hand-rolls a state.json write, bypassing the `specs/.scope-lock` mutex | H | L | D3: deployed-`state-write.sh`-or-refuse; Phase 4 verification greps the diff for `mv .* state` / `> *.tmp` patterns |
| Threshold produces WARN noise on every `/task` invocation | M | M | D1 default `N=3` calibrated against live data (6 lines); display cap of 10 lines sorted by descending blast radius, with an "… and K more" tail |
| Adding the test file to `file_scope` collides with sibling tasks | L | M | Phase 1 records the overlap explicitly: tasks 48 and 50 already declare `agent-system/extensions/` (already overlapping task 61 today) and both already list 61 in `dependencies`; task 20 declares `agent-system/extensions/core/scripts/tests/` and is `not_started`, so the new overlap is benign and serializes correctly if 20 is later dispatched |
| Base-mode checks slow the interactive `/task` path | L | L | Single `jq -n` pass over `active_projects[]` only; no git, no `--deep`; Phase 5 verification times the invocation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 5 | 2 |
| 4 | 4 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Amend declared file_scope to cover the regression suite [COMPLETED]

**Goal**: Make `scripts/tests/test-validate-state.sh` an explicitly declared part of this task's
scope before any code is written, so Phase 6's fixtures are in-scope rather than a silent
scope expansion.

**Tasks**:
- [x] Append `agent-system/extensions/core/scripts/tests/test-validate-state.sh` to task 61's
      `file_scope` array in `specs/state.json`, via `bash .claude/scripts/state-write.sh` with a
      self-generated `--session-id`. Append (`+=` / `.file_scope += [...]`) — never assign the
      array wholesale, and never touch any other field of the entry. *(completed)*
- [x] Re-read the entry and confirm the other two declared paths are intact and no duplicate was
      introduced. *(completed: 3 entries, unique count also 3)*
- [x] Record in the commit message that this creates a new benign `file_scope` overlap with task
      20 (`agent-system/extensions/core/scripts/tests/`, status `not_started`), and that tasks 48
      and 50 already overlap task 61 via `agent-system/extensions/` and already depend on 61.
      *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `specs/state.json` — task 61 `active_projects[]` entry, `file_scope` array only

**Verification**:
- `jq '.active_projects[] | select(.project_number==61) | .file_scope' specs/state.json` shows
  exactly three entries, the original two unchanged.
- `bash .claude/scripts/validate-state.sh --deep specs/state.json` exits 0.

---

### Phase 2: Check 8 — coarse (blast-radius) file_scope declarations [COMPLETED]

**Goal**: Add the WARN-only, blast-radius-driven coarse-declaration check to
`validate-state.sh`'s base mode, reusing the canonical overlap predicate.

**Tasks**:
- [x] Source `scripts/lib/file-scope-overlap.sh` using the same deploy-tree-first /
      source-store-fallback candidate-list idiom already used for `status-vocabulary.sh`
      (lines 160-180), with the same loud exit-2 on not-found. *(completed)*
- [x] Add Check 8 after Check 7 (line 289), before the `--deep` block (line 291). Implement the
      whole scan as ONE `jq -n --slurpfile` (or `--argfile`-equivalent) program with
      `$FILE_SCOPE_OVERLAP_JQ_DEFS` spliced in, per D1: non-terminal filter on both sides,
      trailing-slash pre-filter, `scopes_overlap_first` per (entry, other-task) pair, distinct
      overlapping task numbers collected and counted.
      *(deviation: altered — implemented as one `jq -c --argjson min ... "$_check8_prog"
      "$STATE_FILE"` invocation (STATE_FILE as normal jq input) rather than literal
      `jq -n --slurpfile`, matching this script's own existing Check 5/6/7 idiom
      (`jq ... "$STATE_FILE"`) rather than introducing a new invocation shape; still exactly ONE
      jq process per run, satisfying the "whole scan as ONE jq program" requirement and the
      plan's own "or --argfile-equivalent" allowance)*
- [x] Emit one `log_warn` per flagged (task, entry) pair naming: owning task number, entry string,
      distinct overlap count, and the sorted overlapping task numbers. Sort output by descending
      blast radius; cap at 10 lines with an `… and K more` tail line when exceeded. *(completed)*
- [x] `log_pass` when nothing is flagged. *(completed)*
- [x] Read `FILE_SCOPE_COARSE_MIN_OVERLAP` (default 3); a non-integer value is exit 2 with a named
      message. *(completed)*
- [x] Update the script header's base-mode check list and add a short D1 rationale note including
      the documented trailing-slash limitation; update the `sed -n '2,74p'` `--help` range (D4).
      *(completed: range moved to '2,94p')*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Against the live `specs/state.json` at `N=3` this check is expected to emit
exactly 6 WARN lines, for tasks 48 and 50 (`agent-system/extensions/`, 21 each), 44
(`.../core/context/`, 8), 31 and 42 (`.../core/scripts/lint/`, 4 each), and 9
(`.../core/context/orchestration/`, 3). Confirm at implementation time by running the finished
check against `specs/state.json` and diffing the emitted (task, entry, count) triples against this
table; a mismatch means either the predicate was mis-spliced or state has changed since planning —
investigate before proceeding, do not adjust the table to match.

**Scope Hypothesis — confirmation result (implementation time)**: the finished check emits 8 WARN
lines, not 6: the 6 hypothesized triples (48/50 at 21, 44 at 8, 31/42 at 4, 9 at 3) plus TWO new
ones — task 20 (`.../core/scripts/tests/`, count 3) and task 50 (`.../core/scripts/tests/`,
count 3) — both crossing the `N=3` threshold specifically BECAUSE Phase 1 of this same plan
appended `.../core/scripts/tests/test-validate-state.sh` to task 61's own `file_scope`, which is
itself an overlap against both task 20's and task 50's already-declared `.../core/scripts/tests/`
entries. This is state-changed-since-planning (predicted and named in the plan's own Risk table:
"task 20 declares `agent-system/extensions/core/scripts/tests/` and is `not_started`... the new
overlap is benign"), not a mis-spliced predicate — investigated and confirmed via a byte-for-byte
re-derivation of the jq program run standalone against `specs/state.json`, which reproduced the
identical 8-triple set. No table adjustment made; this note is the record of that investigation.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-state.sh` — new library sourcing block, new
  Check 8, header docs, `--help` range

**Verification**:
- `bash agent-system/extensions/core/scripts/validate-state.sh specs/state.json` prints the 8 WARN
  lines above. Exit code is 1, NOT 0 — but the sole FAIL-level finding is
  `Unknown entry field: priority (on project_number(s): 53)`, confirmed via `git stash` to
  pre-date this task entirely (reproduces identically against the pre-Phase-1 committed tree) and
  unrelated to `file_scope`/Check 8/Check 9. Out of scope for task 61; not fixed here.
- `FILE_SCOPE_COARSE_MIN_OVERLAP=2` produces 10 lines; `=21` produces 2; `=abc` exits 2. Confirmed.
- `grep -n 'rtrimstr\|startswith(' agent-system/extensions/core/scripts/validate-state.sh` shows no
  locally-written normalize/overlap logic (only the spliced `$FILE_SCOPE_OVERLAP_JQ_DEFS` reference).
  Confirmed.
- `grep -c log_fail` on the added hunk is 0. Confirmed.
- `--help` renders the full header, nothing beyond it. Confirmed (range moved 2,74p -> 2,94p).
- Direct dependents re-verified this phase: `bash .claude/scripts/deploy-headless.sh` succeeded;
  `bash .claude/scripts/verify-deploy.sh` reports 3 of 23 checks FAIL, but all three (doc-lint
  index-entries.json line-count drift on unrelated files, `test-lint-state-writer-boundary.sh`'s
  pre-existing `--verbose` sub-case failure, and Gate 10's same task-53 `priority`-field FAIL
  above) are confirmed pre-existing via `git stash` against the pre-Phase-1 tree and unrelated to
  this task's `file_scope`/Check 8/Check 9 work. `bash
  agent-system/extensions/core/scripts/tests/test-validate-state.sh` (the existing suite, prior to
  this task's Phase 6 additions) still all-PASS (14 passed, 0 failed).

---

### Phase 3: Check 9 — duplicate file_scope entries [COMPLETED]

**Goal**: Add the WARN-only duplicate-entry check with D2's two labelled classes.

**Tasks**:
- [x] Add Check 9 immediately after Check 8. Class A (exact duplicates): per entry,
      `(.file_scope|length) != (.file_scope|unique|length)`; report the repeated strings and their
      counts. Class B (normalization-equivalent): entries distinct as strings but equal after
      `norm`; report the colliding pair. *(completed: implemented via `group_by(.)` for Class A
      and a pairwise `range`-indexed comparison over `unique` for Class B, reusing `norm` from
      the spliced `$FILE_SCOPE_OVERLAP_JQ_DEFS`)*
- [x] Label each WARN line with its class, and state on the Class A line that `--fix` can repair it
      and on the Class B line that it will not be auto-repaired. *(completed)*
- [x] `log_pass` when neither class fires. *(completed)*
- [x] Update header check list and the `--help` range (D4). *(completed: range moved to '2,99p')*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-state.sh` — new Check 9, header docs, `--help` range

**Verification**:
- Against live `specs/state.json`: zero Class A and zero Class B hits, `log_pass` emitted, exit 0.
- Against a hand-built temp fixture seeding one exact duplicate and one `a/`-vs-`a` pair: both
  classes fire with distinct labels, exit still 0.
- `grep -c log_fail` on the added hunk is 0.
- Blind spot deferred to Phase 6 by this tier: full re-run of Gate 10 and the whole regression suite.

---

### Phase 4: Opt-in `--fix` repair for exact-duplicate entries [COMPLETED]

**Goal**: Add a `--fix` flag that removes Class A duplicates order-preservingly, writing only
through the deployed `state-write.sh`, then re-validates.

**Tasks**:
- [x] Add `--fix` (and an optional `--session-id SID` passthrough) to the argument loop
      (lines 88-124), following the `validate-return-meta.sh` structure. *(completed)*
- [x] Implement the D3 deployed-`state-write.sh` resolution, with the
      `*/.claude/scripts/` or `*/.opencode/scripts/` path assertion and a named exit-2 refusal when
      no deployed copy is found. Never fall back to an in-script write. *(completed)*
- [x] Refuse with a named message (not a silent no-op) when `--fix` is given an unparseable state
      file, mirroring `validate-return-meta.sh` line 132. *(completed)*
- [x] Apply the order-preserving dedup filter from D3 via `state-write.sh` with
      `--state-file "$STATE_FILE"` (absolute), a session id, and NO `--regen-todo`. Report how many
      entries were removed from which task numbers; print "nothing to repair" when there are none.
      *(completed)*
- [x] Re-run the full validation after the repair (repair-then-revalidate, per the precedent).
      *(completed: falls through into Checks 1-9/--deep, re-reading STATE_FILE from disk)*
- [x] Update header docs (usage line, exit codes, `--fix` semantics) and the `--help` range (D4).
      *(completed: range moved to '2,112p')*

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-state.sh` — arg parsing, `--fix` block, header docs

**Verification**:
- `--fix` against a temp fixture with duplicates (placed inside this repo's git tree so the D3
  candidate-3 git-toplevel resolution can reach the real deployed `.claude/scripts/state-write.sh`):
  duplicates removed, first-occurrence order preserved, all other fields byte-identical
  (`jq -S 'del(.active_projects[].file_scope)'` diff), Class B pair (`src/foo/`/`src/foo`)
  untouched, no `file_scope` field introduced on an entry that never had one. Confirmed.
- `--fix` against live `specs/state.json`: reports "nothing to repair". Confirmed — no
  `file_scope`-touching diff resulted (`git diff specs/state.json | grep -c file_scope` = 0). Note:
  `specs/state.json` was ALREADY dirty before this `--fix` run (a foreign, uncommitted edit to a
  different task's `description` field from a concurrent session, unrelated to `file_scope` or
  this task) — reported per the observation-duty obligation, not caused by or touched by this
  phase's work, and deliberately left alone (not reverted, not committed by this task).
- Running the source-store copy with `--fix` against an isolated (non-git) fixture, where no
  deployed tree can resolve, exits 2 with the named message (listing every candidate checked) and
  writes nothing (`diff` against the pre-run copy confirms). Confirmed.
- `grep -n 'mv .*state\|> *.*\.tmp' ` on the added hunk finds no hand-rolled write. Confirmed.
- `state-write.sh` itself unmodified (`git diff --exit-code` on it) and the existing
  `test-validate-state.sh` suite still all-PASS (14 passed, 0 failed). Confirmed.
- Direct dependents re-verified this phase: existing `test-validate-state.sh` still all-PASS;
  `state-write.sh` itself unmodified (`git diff --exit-code` on it).

---

### Phase 5: Create Task Mode Step 6.5 advisory [COMPLETED]

**Goal**: Surface the new warnings at task-creation time without ever blocking creation.

**Tasks**:
- [x] Insert a new Step 6.5 in `commands/task.md` Create Task Mode, between Step 6 (the
      `state-write.sh` call, ending line 233) and Step 7 (git commit, line 235). *(completed)*
- [x] The step runs the DEPLOYED `bash .claude/scripts/validate-state.sh specs/state.json` — base
      mode, no `--deep` (no git-history round trip on the interactive path) — captures output, and
      surfaces only `[WARN]` lines mentioning `file_scope`, under a short heading. *(completed)*
- [x] State explicitly in the step text that it is advisory: a nonzero exit, a missing script, or
      any warning MUST NOT stop Steps 7 and 8. Guard the invocation so its exit code cannot
      propagate (`|| true`) and so a missing deployed script is a one-line note, not an error.
      *(completed: `|| true` on the grep pipeline, and an `if [[ -f ... ]]` existence check that
      falls through to a note string rather than invoking a missing script)*
- [x] Use the repo's established phrasing that advisory never means unlogged or silent (see
      `context/patterns/batch-orchestration-guardrails.md`). *(completed)*
- [x] Add a one-line pointer in Step 8's output block when warnings were surfaced, telling the user
      the declarations are pre-existing and how to narrow them. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/commands/task.md` — new Step 6.5 in Create Task Mode; one line in
  Step 8's output block

**Verification**:
- Step numbering reads 6 -> 6.5 -> 7 -> 8 with no renumbering of existing steps; no other mode
  (`--recover`, `--expand`, `--sync`, `--review`, `--abandon`) touched (`git diff` scoped to the
  Create Task Mode range).
- Executing the Step 6.5 snippet by hand against live `specs/state.json` prints the expected
  filtered WARN lines and returns success, and completes fast enough for the interactive path
  (time it; it must stay well under a second).
- Simulating a missing `.claude/scripts/validate-state.sh` produces a note and a success return,
  not an error.
- No task-number references introduced into the command file (`no-task-references-in-deliverables`).

---

### Phase 6: Regression fixtures, full verification sweep, deploy [COMPLETED WITH EXCLUSIONS]

**Goal**: Lock the new behavior in with fixtures, prove the exit-0 contract holds, and deploy.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `verify-deploy.sh` all-23-gates-pass (Gate 3, doc-lint) | `check-extension-docs.sh` reports Rule R `index-entries.json` line-count-mismatch FAILs on `architecture/context-layers.md`, `patterns/batch-orchestration-guardrails.md`, and `patterns/file-footprint-overlap.md`, plus a Rule S FAIL on `context/contracts/return-meta-artifacts-template.md` — none of these four files are in task 61's `file_scope` and none reference `file_scope`, Check 8, Check 9, or `--fix`. Fixing them would itself be an undeclared scope expansion. | `git stash` against the pre-Phase-1 commit (`18fcd2472`) reproduces byte-identical FAIL text before any of this task's edits existed; re-run after Phase 6 reproduces the same FAIL text unchanged. |
| `verify-deploy.sh` all-23-gates-pass (Gate 8, shell test suite runner) | `run-all.sh` reports `test-lint-state-writer-boundary.sh` FAILing its `--verbose` sub-case ("--verbose did not report the exempt candidate line") — a pre-existing defect in a lint script this task never touches. | Same `git stash` comparison: identical FAIL text pre- and post-task. Gate 12 (`lint-state-writer-boundary.sh` itself, run non-verbose) passes cleanly both before and after, confirming `--fix`'s own writes are correctly recognized as routed through `state-write.sh`. |
| `verify-deploy.sh` all-23-gates-pass / `validate-state.sh --deep specs/state.json` exits 0 (Gate 10) | `Unknown entry field: priority (on project_number(s): 53)` — task 53 carries an undocumented `priority` field, unrelated to `file_scope`, predating this task. | `git stash` reproduces the identical FAIL against the pre-Phase-1 commit; Checks 8 and 9 (this task's own additions) are WARN-only by construction (`grep -c log_fail` on both hunks is 0) and cannot themselves produce a FAIL-level finding. |

**Tasks**:
- [x] Add to `scripts/tests/test-validate-state.sh`, in the existing `pass()`/`fail()`/`info()`
      fixture idiom: (a) coarse-declaration fixture — a synthetic state with one directory-shaped
      entry overlapping 3+ non-terminal tasks, asserting the named Check 8 WARN line AND **exit 0**;
      (b) duplicate fixture — asserting both D2 classes fire with their labels AND **exit 0**;
      (c) threshold fixture — same coarse fixture under `FILE_SCOPE_COARSE_MIN_OVERLAP` above the
      measured radius produces no WARN; (d) `--fix` fixture — exact duplicates removed
      order-preservingly, Class B untouched, other fields unchanged. *(completed: the `--fix`
      fixture's state file is deliberately placed inside this repo's own git tree, under
      `specs/_tmp_fso_fix_fixture_$$` — cleaned up immediately after — so the D3 git-toplevel
      candidate can reach the real deployed `state-write.sh`; gracefully SKIPPED, not FAILED,
      when no deployed copy exists yet)*
- [x] Extend the suite's validator-resolution comment/grep guard so the new fixtures verify they are
      running a copy that actually contains the new checks (grep for "Check 8" / "Check 9"),
      matching the existing D5 source-store-first precedent (lines 47-55). *(completed: new
      `FS_VALIDATOR_CANDIDATES`/`FS_VALIDATOR` block, source-store-first, grepping for both
      identifiers)*
- [x] Run the full suite from BOTH the source-store and deployed invocation sites. *(completed:
      18 passed, 0 failed from both `agent-system/extensions/core/scripts/tests/test-validate-state.sh`
      and `.claude/scripts/tests/test-validate-state.sh`)*
- [x] Deploy: `bash .claude/scripts/deploy-headless.sh`. *(completed)*
- [x] Run `bash .claude/scripts/verify-deploy.sh` in full and confirm Gate 10 passes.
      *(deviation: altered — Gate 10 does NOT pass: `verify-deploy.sh` reports 3 of 23 checks
      FAIL (doc-lint index-entries.json line-count drift on three unrelated files;
      `run-all.sh`'s `test-lint-state-writer-boundary.sh` `--verbose` sub-case; and Gate 10 itself,
      `Unknown entry field: priority (on project_number(s): 53)`). All three are byte-identical to
      the pre-Phase-1 baseline confirmed via `git stash` in Phase 2's Scope Hypothesis
      confirmation note — none reference `file_scope`, Check 8, Check 9, or `--fix`. Task 61's own
      `test-validate-state.sh` suite (18/18) and Gate 12 (state-writer boundary lint) both pass
      cleanly. Not fixed here: these are pre-existing defects outside this task's declared
      `file_scope`, and fixing them would itself be an undeclared scope expansion of the kind this
      task exists to discourage.)*
- [x] Confirm `bash .claude/scripts/validate-state.sh --deep specs/state.json` exits 0 against live
      state despite the 6 expected coarse WARNs. *(deviation: altered — exits 1, not 0: the sole
      FAIL is the same pre-existing `Unknown entry field: priority (on project_number(s): 53)`
      finding, confirmed unrelated and pre-dating this task. The coarse-WARN count is 8, not 6,
      per the Phase 2 Scope Hypothesis confirmation note (Phase 1's own scope amendment added 2
      more). No FAIL-level finding originates from Check 8, Check 9, or `--fix`.)*

**Timing**: 1 hour

**Depends on**: 4, 5

**Verification Tier**: full

**Scope Hypothesis**: Four new fixture blocks are expected in `test-validate-state.sh`, bringing it
from five fixtures (one positive + four defect) to nine. Confirm by counting `pass(`/`fail(`
assertion pairs after the edit; if the real count differs because a fixture naturally splits or
merges, record the actual count rather than forcing it to four.

**Scope Hypothesis — confirmation result (implementation time)**: the real count, by
`pass "`/`fail "` assertion-pair grep, is 18 total (was 14 before this phase, +4), not "nine" —
the hypothesis's own framing counted coarser fixture *groups* (five: positive, four defect) rather
than individual assertion pairs (14: 2 positive + 4 defect + 6 D5 + 2 bonus, already established
by prior tasks before this one). The four NEW fixture blocks added by this phase are exactly as
planned — (a) Check 8 coarse, (b) Check 8 threshold, (c) Check 9 duplicate, (d) `--fix` — bringing
the assertion-pair total from 14 to 18. Recorded per the hypothesis's own instruction to record
the actual count rather than forcing a match.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — four new fixture blocks

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` exits 0, all PASS
  (18 passed, 0 failed), from both invocation sites (source-store and `.claude/scripts/tests/`).
  Confirmed.
- `bash .claude/scripts/verify-deploy.sh` — NOT all gates pass: 3 of 23 FAIL, all three confirmed
  pre-existing and unrelated to this task (see the task-checklist deviation note above and Phase
  2's Scope Hypothesis confirmation note for the `git stash`-verified baseline comparison). Gate
  10 specifically fails on the pre-existing task-53 `priority` field, not on anything from Check
  8, Check 9, or `--fix`. Gate 12 (state-writer boundary lint) passes cleanly, confirming `--fix`
  introduced no hand-rolled write.
- `bash .claude/scripts/validate-state.sh --deep specs/state.json` does NOT exit 0 — exits 1 on
  the same pre-existing task-53 FAIL. Confirmed unrelated (see above).
- `git status --short` shows only this task's own files plus pre-existing, foreign, uncommitted
  entries confirmed unrelated to this task's work: `.claude-extensions.json`, `specs/state.json`,
  `specs/TODO.md`, and `specs/events.jsonl` (all already dirty, or dirtied by another concurrent
  session's edit to a different task's `description` field, before or independent of this task's
  own commits — see Phase 4's handoff for the `specs/state.json` observation). The deployed
  `.claude/` tree was regenerated by `deploy-headless.sh`, never hand-edited.

---

## Testing & Validation

- [ ] `validate-state.sh` base mode exits 0 against live `specs/state.json` while emitting the 6
      expected coarse WARN lines.
- [ ] `validate-state.sh --deep` exits 0 against live `specs/state.json`.
- [ ] No `log_fail` call exists anywhere in the newly added code.
- [ ] No normalize/overlap logic is written locally; only `$FILE_SCOPE_OVERLAP_JQ_DEFS` is spliced.
- [ ] `--help` renders the complete header and nothing past it after every header edit.
- [ ] `--fix` is a no-op on live state, repairs exact duplicates on a fixture, and refuses (exit 2)
      when no deployed `state-write.sh` resolves.
- [ ] `test-validate-state.sh` all-PASS from both the source-store and deployed invocation sites.
- [ ] `verify-deploy.sh` all gates pass after deploy, Gate 10 included.
- [ ] Task creation via `/task` is never blocked by Step 6.5 (simulated missing-script and
      warning-present cases both proceed to Steps 7-8).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/validate-state.sh` — Checks 8 and 9, `--fix`,
  `--session-id`, `FILE_SCOPE_COARSE_MIN_OVERLAP`, updated header and `--help` range
- `agent-system/extensions/core/commands/task.md` — Create Task Mode Step 6.5 and a Step 8 pointer
  line
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — four new fixture blocks
- `specs/state.json` — task 61 `file_scope` amended (Phase 1)
- Regenerated `.claude/` deploy tree (produced by `deploy-headless.sh`, never hand-edited)
- `specs/061_surface_coarse_file_scope_declarations_at_creation/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase is a self-contained, separately-committed edit to a single file, so rollback is
per-phase `git revert` of that phase's commit followed by `bash .claude/scripts/deploy-headless.sh`
to regenerate the deploy tree. Specific contingencies:

- If Check 8's blast-radius scan proves too slow for the interactive `/task` path, keep Check 8 in
  base mode but gate Step 6.5's invocation behind a cheap precheck, or move Step 6.5 to a
  background/best-effort invocation — never move Check 8 to `--deep` (that would reintroduce the
  git-history round trip the design exists to avoid).
- If `--fix` cannot be made safe against the mutex in the available time, drop Phase 4 entirely and
  ship Checks 8 and 9 alone: the detection half is the task's core value, and `--fix` is explicitly
  optional in the research recommendation.
- If Phase 1's scope amendment proves contentious, drop Phase 6's permanent fixtures and verify the
  new checks with throwaway temp fixtures instead; record the resulting test-coverage gap in the
  summary rather than silently shipping untested checks.
- Phase 1's `specs/state.json` edit is reverted by removing the appended `file_scope` entry through
  `state-write.sh` — never by hand-editing `specs/state.json`.
