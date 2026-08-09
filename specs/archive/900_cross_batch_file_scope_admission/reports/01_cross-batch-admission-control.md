# Research Report: Task #900

**Task**: 900 - Cross-batch file_scope admission control for /orchestrate
**Started**: 2026-07-25T17:00:00Z
**Completed**: 2026-07-25T17:48:00Z
**Effort**: ~2h research
**Dependencies**: Task 898, Task 899 (both completed)
**Sources/Inputs**: Codebase (agent-system/extensions/core/{commands,skills,scripts,context,docs}), specs/state.json (live), specs/899 artifacts, WebSearch, WebFetch
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md, no-task-references-in-deliverables.md

## Executive Summary

- All three "why existing checks miss it" claims in the task description are **verified accurate
  against current on-disk source** (`agent-system/extensions/core/`, not the deployed `.claude/`
  copy). Each check's own text explicitly scopes its read; none scans "every non-terminal task."
- The gap is **live and current**, not hypothetical: a scan of `specs/state.json`'s 12 currently
  non-terminal tasks with `file_scope` finds **7 unordered pairs** with overlapping `file_scope`
  and no `dependencies[]` edge between them today (e.g. this task's own candidate script path
  `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` collides with two sibling
  tasks in adjacent, separately-created batches). This is direct, reproducible evidence the
  defect is real, not a constructed example.
- The **blocking-versus-advisory criterion**, per the sibling task's written guardrails research,
  is: a check is BLOCKING when it is (a) computable purely from on-disk structural state without
  invoking any agent, AND (b) the harm of proceeding anyway is silent/hard-to-detect later. The
  proposed cross-batch check satisfies both — it reads only `state.json`, and an undetected
  concurrent-write collision is exactly the silent-harm case the criterion names. **The new
  script must be blocking (defer-not-fail), never advisory**, at any batch size.
- 2026 literature on admission control for concurrent (multi-)agent systems over shared mutable
  files converges on the same shape already used in this repository: **footprint-based
  pre-write admission is conservative by design** (it blocks on *possible* overlap, not proven
  conflict), and the field's live response to conservatism's false-positive cost is not to
  abandon prefix/footprint matching but to (a) keep it cheap and boolean at the admission gate,
  and (b) route the false-positive cost to a place equipped to resolve it semantically — a
  human review surface (this repository's pattern) or an LLM-judged advisory-notification layer
  (a research pattern, not yet in production maturity as of the surveyed sources). Naive
  filename-only matching is explicitly called out as too imprecise; directory-prefix matching
  (this repository's and this task's approach) is a documented middle ground.
- **Proposed verdict schema** (full detail in Findings): one JSON object per candidate task,
  `decision` in `{"admit", "defer"}`, with defer verdicts carrying the colliding task number,
  the overlapping path, and a `collision_scope` of `"in_batch"` or `"cross_batch"` — the field
  the design constraints explicitly ask for to let a downstream report distinguish "resolves by
  waiting one wave" from "this task may not belong in this batch at all."
- The new script is designed as a **read-only, O(active tasks) admission predicate** — one
  `state.json` read, no locking, no filesystem globbing — consistent with the existing three
  checks' bounded-scan discipline and directly reusable, unmodified, by both wiring call sites
  (`commands/orchestrate.md` Step 3, `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5) and
  by the sibling dry-run report task that will render its output.

## Context & Scope

This report grounds the design of `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`,
a new admission-control script that closes a verified gap: non-terminal, unlocked, out-of-batch
tasks are invisible to all three of this repository's existing file-scope safety checks
simultaneously. The report (a) re-verifies each of the three "why existing checks miss it" claims
against the CURRENT on-disk source under `agent-system/extensions/core/` (never the deployed,
gitignored `.claude/` copy, per the binding source-store rule), (b) reads specs/899's completed
research to import its already-settled blocking-vs-advisory criterion rather than re-deriving it,
(c) proposes a concrete, machine-readable verdict schema for the sibling dry-run-report task to
build against, and (d) surveys July-2026-current literature on footprint-based admission control
versus optimistic after-the-fact conflict detection for concurrent agents over shared files. No
skill/command/script file was modified — this is a research-only task; the script and its two
wiring edits are implementation-phase work.

## Findings

### Codebase Patterns (verified against current on-disk source)

**Claim 1 — `commands/orchestrate.md` Step 3 scopes to the invocation's wave.** Verified at
`agent-system/extensions/core/commands/orchestrate.md` lines 165-169 (current numbering; the
task description's own line numbers are explicitly flagged stale and were not relied on): "compare
every pair of tasks in that wave using the shared directory-prefix overlap algorithm in
`.claude/context/patterns/file-footprint-overlap.md` ... applied to each task's `file_scope`
(read only for the tasks already collected into `validated_tasks` for this invocation — no
repo-wide scan)." The prose is explicit and self-describing about its own scope limit.

**Claim 2 — `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 scopes to `eligible_tasks`.**
Verified at lines 944-949 (current numbering): "compare every pair using the shared
directory-prefix overlap algorithm ... applied to each task's `file_scope` (read only for the
tasks already in `task_numbers` for this invocation — no repo-wide scan)." Identical scoping
language to Claim 1, confirming the two checks are deliberately mirrored, not independently
drifted.

**Claim 3 — `scripts/task-lock.sh` only compares against currently-held locks.** Verified in
`cmd_acquire` (current lines ~295-388): the cross-task overlap scan iterates
`find_held_locks "$lock_dir"` (lines 217-229), which lists only `.lock` directories that
currently exist under `specs/*/`. `get_file_scope` (lines 182-194) reads a single task's
`file_scope` from `state.json`, but is only ever called for (a) the acquiring task itself and (b)
tasks that hold a lock right now (`other_task` from the held-lock loop). A non-terminal,
unlocked, out-of-batch task's `file_scope` is never read by this script at all.

**The union of scopes has a hole, confirmed live in current `state.json`.** All three checks are
individually correct within their own stated scope (this invocation's task set; currently-held
locks). None scans "every non-terminal task in `state.json`." A reproducible scan of the current
`specs/state.json` (12 tasks with `status` outside `{completed, abandoned, expanded}` and a
non-null `file_scope`) against the canonical overlap predicate in `file-footprint-overlap.md`
finds these unordered pairs with overlapping `file_scope` and **no** `dependencies[]` edge
between them, right now:

| Pair | Statuses | Overlapping path |
|------|----------|-------------------|
| 900 ↔ 902 | researching / not_started | `.../scripts/orchestrate-batch-admit.sh` |
| 900 ↔ 906 | researching / not_started | `.../skills/skill-orchestrate/SKILL.md` |
| 900 ↔ 907 | researching / not_started | `.../commands/orchestrate.md` |
| 900 ↔ 908 | researching / not_started | `.../commands/orchestrate.md` |
| 901 ↔ 907 | not_started / not_started | `.../commands/orchestrate.md` |
| 901 ↔ 908 | not_started / not_started | `.../commands/orchestrate.md` |
| 906 ↔ 908 | not_started / not_started | `.../skills/skill-orchestrate/SKILL.md` |

(Two other pairs on the same paths — 900↔901, 901↔902, 901↔906, 902↔907, 906↔907, 907↔908 — DO
carry a `dependencies[]` edge and are therefore not gaps; they are listed here only to show the
comparison method is symmetric and not cherry-picked.) These are exactly the tasks in this same
research-and-design effort, created across at least two separate `/meta` batches, which is the
literal scenario the task description names ("two active tasks share
`agent-system/extensions/core/scripts/skill-base.sh`... created in separate `/meta` batches") —
that specific skill-base.sh pair (tasks 885 and 906) now happens to carry a `dependencies[]` edge
(906 depends on 885) so it is no longer an open gap example, but the table above shows the same
class of gap recurring in the current task set. This is strong evidence the defect is not a
one-off; it recurs naturally whenever `/meta` batches are created independently over time, which
is the normal way this repository accumulates tasks.

**Terminal-status list, confirmed against the state-management rule** (not assumed): exactly
`{completed, abandoned, expanded}`, per `agent-system/extensions/core/rules/state-management.md`
line 42 ("Cannot transition from terminal states (completed, abandoned, expanded)") and matching
Stage MT-3 step 2's own literal set (`{completed, abandoned, expanded}`). `state.json` currently
uses exactly this vocabulary plus `not_started`, `researching`, `researched`, `planning`,
`planned`, `implementing`, `partial`, `pr_ready`/`PR READY`, `blocked` for non-terminal statuses
— all of these must be included in the new script's comparison set. Scale check: `state.json`
currently has 22 `active_projects` total, of which 12 are non-terminal — confirming a single read
and O(active tasks) pairwise comparison is trivially cheap, well within the "single read, no
globbing" design constraint.

**The overlap predicate itself must not be restated.** `file-footprint-overlap.md` is explicit —
"This document defines the algorithm exactly once. Every consumer references this file by path
and never restates or re-derives the rule" — and already documents three consumers (task-level
Component 4a, phase-level `skill-team-implement`, lock-acquisition-level `task-lock.sh`). The new
script is a **fourth consumer** at a new level ("batch-admission-level"); the implementation phase
should both reference the algorithm by path (as `task-lock.sh`'s `scopes_overlap()` does — a
direct jq transcription with a code comment pointing at the source lines, not a restatement in
prose) and add this new consumer to `file-footprint-overlap.md`'s "Consumers" list so the
canonical document stays the complete index of callers.

**`task-lock.sh`'s `scopes_overlap()` (lines 196-215) is the ready-made jq transcription to
reuse or mirror.** It takes two compact JSON path arrays and returns the first overlapping path
from the second array, implementing exactly the `rtrimstr("/")`-normalized exact-or-prefix rule.
The new script can call this same function (if `task-lock.sh` is sourced) or an identical
transcription — either way, by-path reference to `file-footprint-overlap.md`'s pseudocode is what
matters, not code reuse for its own sake. `get_file_scope()` (lines 182-194) is likewise a
ready-made, gracefully-degrading (`"[]"` on any lookup failure) `state.json` reader keyed by
`project_number`, directly reusable pattern for reading every non-terminal task's `file_scope` in
one pass instead of task-lock.sh's current per-task lookup.

**Sibling-task landing confirmed live**: `scripts/skill-base.sh` now defines
`skill_gate_completion_claim` (current lines ~608-670+), and both `skill-orchestrate/SKILL.md`
(lines 625-629, 1090) and `skill-orchestrate-hard/SKILL.md` (lines 867-873) call it before
postflight — corroborating the delegation context's note that sibling tasks just landed changes
to these exact files. This has no direct bearing on the admission-control design (a different
concern, gated at postflight rather than admission time) but confirms current-state reading was
necessary and correct practice for this research pass.

**Hard-mode has no separate wiring surface.** `skill-orchestrate-hard/SKILL.md` Stage 0 states
"Same as base `skill-orchestrate`. Parse `multi_task_mode`. If true, use base multi-task..." and
its "Multi-Task Mode" section (line 1002) states "Same as base `skill-orchestrate` multi-task
stages (MT-1 through MT-5)." Hard mode delegates the entire wave-split/eligibility machinery to
base `skill-orchestrate`; it has no independent copy of Stage MT-3 step 4.5 to wire separately.
The task's two named wiring targets (`commands/orchestrate.md` Step 3, `skills/skill-orchestrate/
SKILL.md` Stage MT-3 step 4.5) are therefore the complete set of call sites — no third,
hard-mode-specific site exists.

### Blocking-vs-Advisory Criterion (imported from specs/899, not re-derived)

Per the completed sibling research, the settled criterion is: a guardrail is **BLOCKING** when it
is (a) computable purely from on-disk structural state without invoking any agent, AND (b) the
harm of proceeding anyway is silent and hard to detect after the fact. It is **ADVISORY** only
when the underlying signal is inherently a heuristic/estimate, or the condition is not this
invocation's to fix — but advisory never means silent/unlogged.

Applying this criterion to the new cross-batch check: (a) it is computed entirely from a single
`state.json` read (`file_scope`, `status`, `dependencies`) — no agent invocation, no filesystem
scan; (b) the harm of skipping it — two agents editing overlapping files concurrently, one
silently clobbering or racing against the other's writes — is exactly the "concurrent file
corruption... silent and hard to detect after the fact" example the criterion names explicitly.
**Both conditions hold. The new check must be blocking (defer-not-fail), matching the two checks
it extends, and must never be relaxed to advisory as batch size grows** (Decision 2 of specs/899's
report: batch size changes the *scope* of what gets deferred — one task, per pair — never the
*existence* of the check).

### External Resources (July-2026-current)

**Admission-control shape for concurrent (multi-)agent systems over shared mutable files** has a
consistent 2026 answer across both production commentary and fresh research: pure locking and
pure optimistic concurrency both fail at agent scale for different reasons, and the field is
converging on hybrids that still use conservative footprint declaration at the front door.
Production commentary on scaling equal-status agent fleets reports that naive mutual-exclusion
locking causes agents to hold locks too long and throughput collapses (a 20-agent fleet dropping
to 2-3 effective concurrent workers), while naive optimistic concurrency control made agents
"risk-averse" — they learned to avoid tasks likely to trigger a rollback. The reported fix was
architectural role separation (planners that decompose and sequence work vs. workers that execute
without inter-worker coordination vs. judges that gate continuation) rather than tuning either
locking or OCC directly — a validation, from a different angle, of this repository's own
layered design (creation-time edges + admission-time deferral + acquisition-time lock), where no
single mechanism is asked to carry the whole burden.
([mikemason.ca, "AI Coding Agents in 2026"](https://mikemason.ca/writing/ai-coding-agents-jan-2026/))

**Conservative, footprint-based pre-write admission is an actively-researched July-2026 pattern
that matches this task's design directly.** "ATM: CID-Brokered Pre-Write Admission for Multi-Agent
Code Co-Synthesis" (arXiv 2607.00041 — the `2607` prefix places it in this month) proposes exactly
the shape being designed here: agents declare file footprints upfront; the broker checks
overlap **before** any write is admitted, i.e. conservative admission, not after-the-fact
conflict detection ("Pre-write admission prevents conflicts by checking file access patterns
before agents write"). Its refinement over naive filename matching is content-identifier (CID)
hashing for finer-than-path precision; that refinement is a heavier-weight technique this
repository's simpler directory-prefix rule deliberately does not adopt (see Risks below), but the
paper's core admission strategy — block on declared-footprint overlap before dispatch, not after
— is the same strategy this task implements.
([arXiv 2607.00041](https://arxiv.org/pdf/2607.00041))

**The false-positive cost of conservative footprint comparison, and how the 2026 literature
routes it, is the most directly relevant finding for this task's open design question.**
"CoAgent: Concurrency Control for Multi-Agent Systems" (arXiv 2606.15376) states the trade-off
explicitly: footprint-based conflict detection is "fundamentally conservative" — "two calls
conflict on footprint when one's write set intersects the other's footprint" — which by
construction over-approximates real conflicts (a peer appending a log line to a file another
agent merely scanned trips the same footprint check as a genuine concurrent edit to the same
logic). CoAgent's answer is to demote the conservative check from a hard block to an **advisory
notification**, delegating the final real-vs-false-positive judgment to the affected LLM agent's
semantic reasoning, backed by a serializability proof (Monotonic Trajectory Pre-Order) that a
σ-monotone precedence DAG cannot cycle. Reported results: ≈95% correctness (5% residual error
attributed to agents misjudging notification relevance, not the protocol), 1.4× speedup over
serial execution at 1.15× token cost, versus 2PL's 1.04× speedup with visible deadlocks (0.81/trial)
and OCC's 0.93× speedup with expensive aborts (0.95/trial, 1.83× token cost).
([arXiv 2606.15376](https://arxiv.org/html/2606.15376v1))

**Why this repository correctly does NOT adopt CoAgent's advisory-notification answer for this
check.** CoAgent's mitigation requires an LLM in the loop to adjudicate every notified
"may-conflict" at genuine per-tool-call granularity, with a self-healing/compensation
(saga-style inverse) mechanism to undo wrongly-ordered writes — a real-time, per-write judgment
system this repository's batch-admission model does not have and, per specs/899's already-settled
Decision 2 and Non-negotiables, should not build here: the blocking-vs-advisory criterion this
repository uses turns on whether harm is *silent and hard to detect later*, and per that
criterion this check stays blocking. The right response to false-positive cost here is not "make
the check advisory" but **cheap, correct scoping of the pairwise comparison and a defer (not
fail) response** — which is exactly what this repository already does for the two checks this
task extends, and what the new script should also do. CoAgent's contribution is valuable evidence
that footprint conflict detection is *inherently* conservative/over-approximating by construction
(this repository should not expect or promise zero false positives from directory-prefix
matching) — not a design this task should adopt wholesale.

**Directory-prefix / coarse-granularity false positives are a well-understood, decades-old
database-systems phenomenon, and the mitigation pattern generalizes directly.** The canonical
hierarchical/multi-granularity locking literature (Gray et al. 1976, "Granularity of Locks and
Degrees of Consistency in a Shared Data Base") establishes that coarser lock granularity
(escalating from row-level to table-level, or here, from exact-path to directory-prefix) trades
increased false-conflict rate for cheaper tracking and simpler correctness reasoning — "lock
escalation to coarser-grain locks increases the likelihood of false conflicts... unnecessary
serialization can result when multiple transactions lock overlapping ranges of data even if they
don't actually conflict." This is the precise, well-precedented cost this task's directory-prefix
rule pays: a task declaring `agent-system/extensions/core/skills/skill-orchestrate/` as its
`file_scope` will defer against any other task touching any file anywhere in that directory, even
if the two tasks' actual edits never touch the same line. The mitigation the DBMS literature
recommends — finer-grained locks where contention is frequent enough to matter, coarser locks
elsewhere — maps directly onto this repository's own existing, un-stated convention: task authors
who declare `file_scope` at file granularity (most tasks observed in the current `state.json`
scan) get precise, low-false-positive admission; task authors who declare a whole directory as
scope accept a higher false-positive/defer rate as the cost of a simpler declaration. This is a
task-author-facing trade-off, not something the admission script itself can or should resolve —
the script's job is to apply the declared scope faithfully and defer visibly (never silently),
consistent with the "advisory never means silent" clause of the blocking-vs-advisory criterion.
([Gray et al. 1976, mirrored at mwhittaker.github.io](https://mwhittaker.github.io/papers/html/gray1976granularity.html);
general corroboration from Bazel's own directory-output-prefix conflict detection, which similarly
treats a declared-directory output as covering everything nested under it —
[bazelbuild/bazel#21782](https://github.com/bazelbuild/bazel/issues/21782))

**Build-system precedent for treating a directory declaration as covering its full subtree** (the
same rule `file-footprint-overlap.md`'s "Directory-vs-file example" already encodes) is
independently corroborated by Bazel's action-conflict checker, which rejects two declared output
paths where one is a prefix of the other for the identical structural reason — this is not a
repository-specific invention but a recognized pattern in mature build/orchestration tooling.

## Decisions

1. **The new script is a pure, blocking (defer-not-fail) admission predicate — never advisory —**
   because it satisfies both halves of the specs/899 criterion (on-disk-only computation; silent
   hard-to-detect harm if skipped). This is non-negotiable per the imported criterion, not a
   fresh judgment call for this task.
2. **One `state.json` read, O(active tasks) pairwise comparison, no locking, no filesystem
   globbing.** At the current scale (22 total tasks, 12 non-terminal), this is trivially cheap;
   nothing about the design should introduce a second read or a live filesystem scan.
3. **Comparison set = every task whose `status` is NOT in `{completed, abandoned, expanded}`**,
   confirmed against `rules/state-management.md`, independent of whether the task holds a lock,
   independent of whether it is in the requested batch. This is precisely the union the three
   existing checks miss.
4. **Defer-not-fail, always.** A collision defers the higher-`project_number` (lower-priority)
   candidate; the script never marks a task `failed` and never mutates `state.json` itself — it
   only emits a verdict for the caller (Step 3 / Stage MT-3 step 4.5) to act on, mirroring the
   existing wave-split check's own behavior exactly.
5. **The verdict must distinguish in-batch from cross-batch collisions** (`collision_scope`,
   below) per the task's explicit design constraint. An in-batch collision is resolved by the
   existing per-wave/per-cycle defer machinery unchanged (the colliding task is simply a member
   of `task_numbers`/`validated_tasks` for this same invocation). A cross-batch collision names a
   task the caller did not even request — the caller cannot "defer it to the next wave" in the
   same sense, because that task is not part of this run's wave schedule at all. The correct
   caller-side response to a cross-batch verdict is to defer/exclude the *requested* candidate
   from this invocation's admitted set (never attempt to silently fold the out-of-batch task in,
   which is a distinct, separately-gated concern — auto-expanding batch membership needs its own
   admission checks, explicitly flagged as future/out-of-scope work by specs/899's Risks section
   and unchanged here) and surface both the colliding out-of-batch task number and its status, so
   a human (via the dry-run report) can judge whether the batch composition itself needs
   revisiting.
6. **Reference `file-footprint-overlap.md` by path; do not restate the predicate.** Mirror
   `task-lock.sh`'s `scopes_overlap()` jq transcription pattern (a direct, comment-linked
   transcription, not free-hand reimplementation) and register the new script as a fourth named
   consumer in `file-footprint-overlap.md`'s "Consumers" section during implementation.
7. **Field names use `task_number`/`project_number` consistent with existing usage** — `state.json`
   uses `project_number`; `skill-orchestrate`'s bash variables and JSON dispatch-window keys use
   `task_number`/`$t`. The verdict schema below uses `task_number` for the candidate being judged
   (matching the calling skill's own variable name) and `colliding_task_number` for the other
   side, avoiding ambiguity with `project_number` while staying recognizable to both callers.

### Proposed Verdict Schema

One compact JSON object per candidate task, one line per object (newline-delimited JSON,
mirroring this repository's existing `events.jsonl` convention for machine-consumed, per-record
output — grep/jq-friendly, no reparsing of prose, and trivially appendable if a future caller
wants to log verdicts over time). A `"$schema"` tag mirrors the `.orchestrator-handoff.json`
convention (`"$schema": "orchestrator-handoff-v1"`) for the same reason: an explicit, versioned
self-description a downstream consumer can branch on if the schema changes later.

```json
{"$schema": "orchestrate-batch-admit-v1", "task_number": 900, "decision": "admit"}
{"$schema": "orchestrate-batch-admit-v1", "task_number": 907, "decision": "defer", "colliding_task_number": 901, "colliding_task_status": "not_started", "overlapping_path": "agent-system/extensions/core/commands/orchestrate.md", "collision_scope": "cross_batch", "reason": "file_scope overlap with non-terminal task #901 (not in this batch) at agent-system/extensions/core/commands/orchestrate.md; no dependencies[] edge between them"}
```

**Field definitions**:

| Field | Type | Present when | Meaning |
|-------|------|---------------|---------|
| `$schema` | string | always | Literal `"orchestrate-batch-admit-v1"`, versioned so a future schema change is self-describing to downstream parsers. |
| `task_number` | integer | always | The candidate task this verdict is about (unpadded, matches `project_number`/existing `task_number` bash variable convention). |
| `decision` | string enum `"admit" \| "defer"` | always | The admission verdict for this candidate. Never `"fail"` — defer-not-fail is structural, not a config option. |
| `colliding_task_number` | integer | `decision == "defer"` only | The other task's `project_number` whose `file_scope` overlaps this candidate's. |
| `colliding_task_status` | string | `decision == "defer"` only | The colliding task's current `status`, verbatim from `state.json` — lets a report render e.g. "blocked by #885 (partial)" without a second lookup. |
| `overlapping_path` | string | `decision == "defer"` only | The single overlapping path returned by the overlap predicate (mirrors `task-lock.sh`'s `scopes_overlap()` return convention: first match, not an exhaustive list — sufficient for a human-readable reason and consistent with the existing wave-split warning's `({path})` format). |
| `collision_scope` | string enum `"in_batch" \| "cross_batch"` | `decision == "defer"` only | `"in_batch"` when `colliding_task_number` is itself a member of the candidate set passed to the script (resolves by ordinary same-run deferral); `"cross_batch"` when it is not (the colliding task is not part of this invocation at all — the caller should treat this as a signal the requested candidate, not just its dispatch order, may need reconsideration, per Design Constraint 5 above). |
| `reason` | string | `decision == "defer"` only | One human-readable sentence, machine-templated (not free-form prose the caller must parse for facts) — all facts a report needs (`colliding_task_number`, `overlapping_path`) are ALSO available as separate structured fields above; `reason` exists only as a ready-to-print message, never as the sole carrier of any fact. |

**Script invocation contract** (input side, for the two wiring call sites to agree on): the script
takes the candidate task numbers as arguments (the caller's `validated_tasks`/`task_numbers` for
this invocation — the exact same list already computed for the existing wave-split check), reads
`specs/state.json` once, and for each candidate emits exactly one verdict line, in input order,
to stdout. This lets `commands/orchestrate.md` Step 3 and `SKILL.md` Stage MT-3 step 4.5 both
call it identically — `jq`-filter the stdout for `decision == "defer"` and act exactly as they do
today on their own inline overlap check, with no change to the surrounding defer/log/reschedule
logic, only a change to how the overlap fact is produced (script call instead of inline pairwise
loop scoped to the invocation's own task set).

**Why `collision_scope` rather than a `severity` field**: this repository already uses `severity`
with two different, incompatible vocabularies — `"hard" | "soft"` for handoff blockers
(`docs/architecture/handoff-schema.md`) and `"critical" | "high" | "medium" | "low"` for
error/review issues (`commands/errors.md`, `commands/review.md`, `issue-grouping.sh`,
`tier-selection.sh`). Reusing the name `severity` for a third, different two-value vocabulary
risks a reader assuming one of the existing meanings. `collision_scope` is a fresh, unambiguous
name for a fact neither existing `severity` vocabulary represents (which side of the requested
batch boundary the collision falls on), leaving room for a genuine severity judgment to be added
later (e.g. by the self-modification-hazard-gate sibling task) without a naming collision.

## Risks & Mitigations

- **Risk**: implementing CID-content-hash-level precision (per ATM's refinement over plain
  directory-prefix matching) to reduce false positives. **Mitigation**: explicitly out of scope —
  `file-footprint-overlap.md` defines directory-prefix matching as the canonical, single-source
  algorithm and states plainly it is "directory-prefix matching only... no glob or regex
  matching." Adding a second, more precise algorithm for just this consumer would fork the
  canonical predicate the task's own instructions forbid forking. Accept the same false-positive
  profile as the two checks already in production.
- **Risk**: over-widening the comparison set "while we're in there" (e.g. including terminal
  tasks "just in case," or scanning `specs/` on disk instead of `state.json`). **Mitigation**: the
  design constraints are explicit — single `state.json` read, no globbing — and this report's
  Decision 3 pins the comparison set to the rule-confirmed terminal-status exclusion list. Any
  implementation that reads more than `state.json` once has silently widened blast radius against
  an explicit instruction.
- **Risk**: a future maintainer reads the false-positive-cost literature (CoAgent) and concludes
  the fix is to make this check advisory to reduce nuisance defers. **Mitigation**: this report's
  Decisions section states explicitly, with the imported specs/899 criterion as backing, why that
  conclusion is wrong for this check — record this reasoning directly in the implementation's
  code comments and/or the guardrails context pattern (`context/patterns/
  batch-orchestration-guardrails.md`, the specs/899 deliverable) so it cannot be independently
  rediscovered and reversed by a later, less-grounded pass.
- **Risk**: `collision_scope: "cross_batch"` verdicts, once the dry-run report renders them (a
  named downstream consumer), could be misread by a human reviewer as "this task is broken" rather
  than "this task's batch placement is contested." **Mitigation**: the `reason` field's templated
  sentence and the schema's field-level documentation above both frame it as a scheduling/batch-
  composition signal, not a correctness verdict on the task itself — the implementation phase
  should carry this framing into the dry-run report's rendered language too, though that report's
  exact wording is the downstream task's own responsibility to finalize.
- **Risk**: since this task and its downstream siblings (the dry-run report task, the
  self-modification-hazard-gate task) all declare overlapping `file_scope` on the very files this
  admission machinery concerns, running them concurrently in one `/orchestrate` batch is itself an
  instance of the defect being fixed (confirmed live in the table above). **Mitigation**: not this
  task's decision to make — noting it here so whoever assembles the next `/orchestrate` batch for
  this task family can see the collision table and choose wave order deliberately (this task has
  no unmet predecessor among its own listed dependencies, so it can proceed independently; the
  downstream tasks correctly declare a dependency back on this one).

## Context Extension Recommendations

- **Topic**: `file-footprint-overlap.md`'s "Consumers" section will be stale the moment the new
  script exists (currently lists three consumers: task-level, phase-level, lock-acquisition-level).
  **Gap**: no fourth "batch-admission-level" entry yet, since this predicate exists only as
  informally-duplicated inline logic in `orchestrate.md`/`SKILL.md` today, not a distinct script.
  **Recommendation**: the implementation phase should add a fourth bullet to that section pointing
  at `scripts/orchestrate-batch-admit.sh`, consistent with the document's own stated goal of being
  "the complete index of callers."
- **Topic**: no existing context file documents the `orchestrate-batch-admit-v1` verdict schema
  proposed above. **Gap**: `docs/architecture/handoff-schema.md` is the precedent for documenting
  a machine-consumed JSON contract this precisely; there is no equivalent for admission verdicts.
  **Recommendation**: the implementation phase (or the downstream dry-run-report task, whichever
  lands the schema in its final form) should add a short schema doc, most naturally alongside
  `handoff-schema.md` in `docs/architecture/`, so the contract has one canonical, citable location
  rather than living only in script comments.

## Appendix

### Codebase files read (current on-disk source, agent-system/extensions/core/)

- `commands/orchestrate.md` (Steps 1-4, focus on Step 3 lines 108-205)
- `skills/skill-orchestrate/SKILL.md` (Stage MT-2 routing table, Stage MT-3 steps 1-6, Stage MT-4
  phase-grouping and task-lock-acquire sections, lines ~900-1100)
- `skills/skill-orchestrate-hard/SKILL.md` (Stage 0 multi-task detection, Multi-Task Mode section)
- `scripts/task-lock.sh` (full: `get_file_scope`, `scopes_overlap`, `find_held_locks`,
  `acquire_scope_mutex`/`release_scope_mutex`, `cmd_acquire`, lines 178-390)
- `context/patterns/file-footprint-overlap.md` (full)
- `rules/state-management.md` (Status Transitions / terminal states)
- `docs/architecture/handoff-schema.md` (JSON schema conventions, `$schema` tag, 400-token budget)
- `specs/state.json` (live: all `active_projects`, `status`, `file_scope`, `dependencies` fields;
  scripted pairwise-overlap scan against the canonical predicate)
- `specs/TODO.md` (task 901 and task 902 full descriptions, for downstream-consumer contract)
- `specs/899_batch_orchestration_guardrails_context/reports/01_batch-orchestration-guardrails.md`
  (full — blocking-vs-advisory criterion, defer-not-fail rationale)
- `scripts/issue-grouping.sh`, `scripts/tier-selection.sh`, `commands/errors.md`, `commands/review.md`
  (existing `severity` field usages, to avoid a colliding third vocabulary)

### Search queries used

- "2026 multi-agent coding assistants file lock admission control conservative footprint
  serialization vs optimistic conflict detection"
- "build system declared file inputs outputs coarse directory prefix false positive conflict
  Bazel action conflict checking"
- "hierarchical intent locking granularity trade-off unnecessary serialization coarse-grained
  lock false conflict database systems"

### Sources fetched in full

- [ATM: CID-Brokered Pre-Write Admission for Multi-Agent Code Co-Synthesis (arXiv 2607.00041)](https://arxiv.org/pdf/2607.00041)
- [CoAgent: Concurrency Control for Multi-Agent Systems (arXiv 2606.15376)](https://arxiv.org/html/2606.15376v1)

### Additional sources referenced from search snippets (not individually fetched)

- [AI Coding Agents in 2026: Coherence Through Orchestration, Not Autonomy — Mike Mason](https://mikemason.ca/writing/ai-coding-agents-jan-2026/)
- [Granularity of Locks and Degrees of Consistency in a Shared Data Base — Gray et al. 1976, mirrored](https://mwhittaker.github.io/papers/html/gray1976granularity.html)
- [Bazel #21782 — nested/prefix action output directory conflicts](https://github.com/bazelbuild/bazel/issues/21782)
