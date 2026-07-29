# Orchestrator Handoff JSON Schema

**Status**: Current architecture.

**File location**: `specs/{NNN}_{SLUG}/.orchestrator-handoff.json` (per-dispatch runtime state,
tracked as durable provenance)
**Written by**: Skills when `orchestrator_mode: true` in delegation context
**Read by**: `skill-orchestrate` state machine loop

This file **is** git-tracked, unlike the loop guard and churn-state files `skill-orchestrate`
also writes. The reader-side freshness gate documented below ("Readers MUST check freshness")
neutralizes the "restored from an old commit" scenario a tracked file would otherwise risk —
exactly the gate the loop guard lacks, which is why that file stays gitignored instead. See
`context/standards/orchestrator-runtime-files.md` for the full two-class policy and rationale.

**See Also**: `architecture-spec.md` (Component 5), `orchestrate-state-machine.md`,
`context/standards/orchestrator-runtime-files.md`

## Path Resolution Contract

**Writers MUST use an absolute path.** A bare `.orchestrator-handoff.json` filename resolves
against whatever the ambient working directory happens to be at write time, stranding the file
outside the task directory. The orchestrator then either reports a missing handoff or — worse —
reads the previous cycle's leftover file and reports its status as the current dispatch's
result.

Two independent write mechanisms exist. Both are anchored absolutely, by different means:

| Mechanism | Anchor | Enforcement |
|-----------|--------|-------------|
| `skill_write_orchestrator_handoff` (`scripts/skill-base.sh`) — Bash redirect | `${SKILL_REPO_ROOT}/specs/{NNN}_{SLUG}/...`, with `SKILL_REPO_ROOT` resolved from `BASH_SOURCE` | Script-layer construction only. The PostToolUse hook CANNOT see this write. |
| Hard-mode agent direct write — Write tool | `handoff_path` (absolute) supplied in the delegation context, with absolute `task_dir` as fallback | `hooks/validate-handoff-location.sh` (PostToolUse, matcher `Write\|Edit`) rejects out-of-tree destinations with exit 2 |

**Hook coverage is deliberately partial, and this is not a defect to be fixed by widening the
matcher.** `validate-handoff-location.sh` reads `tool_input.file_path`, a field only `Write` and
`Edit` calls carry. A Bash-redirect write exposes only the raw, unexpanded command text — the
redirect target appears as the literal string `"$handoff_path"`, and its resolved value is not
present in the hook input at all. No pattern-matching strategy can recover it. The hook is
therefore complete coverage for agent-direct writes and zero coverage for script writes; the
orchestrator-side stray-handoff sweep (`skill-orchestrate` and `skill-orchestrate-hard`,
Stage 5) is the mechanism-agnostic backstop for the latter.

**Readers MUST check freshness.** A handoff at the correct path is not necessarily *this
dispatch's* handoff. Both orchestrators compare the file's mtime against `dispatch_start_ts` —
the same dispatch window already captured for infra-failure discrimination — and treat an
out-of-window handoff exactly as they treat a missing one.

**Dual-Consumer Note**: `orchestrator_mode` has TWO independent consumers as of the
sparse-literature-detection reconciliation (see `EXTENSION.md`'s "Sparse-Coverage Detection"
section in the literature extension): (1) the handoff-write gate documented on this page
("Skills MUST write `.orchestrator-handoff.json` when and ONLY when `orchestrator_mode: true`"),
and (2) the literature Stage 4a autonomy gate in
`context/patterns/lit-stage4a-flow.md` (`orchestrator_mode: true` suppresses `AskUserQuestion`
and takes the deterministic `[lit:auto]` global-corpus fallback instead). A future edit to
either consumer's semantics MUST re-check the other before landing -- fixing the autonomy gate
must never silently regress the handoff-write gate, or vice versa.

---

## Two Distinct Handoff Types

This document covers only the **orchestrator handoff**. Do not confuse with continuation handoffs:

| Type | File | Format | Written by | Read by | Purpose |
|------|------|--------|------------|---------|---------|
| **Orchestrator handoff** | `.orchestrator-handoff.json` | JSON, ≤400 tokens | Skills (orchestrator_mode) | skill-orchestrate | State machine dispatch decisions |
| Continuation handoff | `handoffs/phase-N-handoff-TIMESTAMP.md` | Markdown | Agents (context exhaustion) | Successor agents | Resume after context exhaustion |

These serve different consumers and MUST NOT be conflated. The orchestrator reads structured JSON;
the successor agent reads markdown prose.

---

## Two Accepted Forms

The continuation pointer — "where is the markdown continuation handoff a `partial` dispatch left
behind" — has **two accepted forms**, and every reader in the system accepts **both**:

| Form | Shape | Who writes it today | Canonical source |
|------|-------|----------------------|-------------------|
| **Flat** `continuation_path` | top-level string, e.g. `"specs/NNN_slug/handoffs/phase-N-handoff-TS.md"` | The only ACTIVE writer: hard-mode implementation agents' H9 wrap-up (`general-implementation-hard-agent.md` Stage 5, and the cslib/lean counterparts) | `context/contracts/wrap-up.md`'s Orchestrator Handoff JSON Schema — this is hard mode's canonical, required shape |
| **Nested** `continuation_context` | top-level object `{ "handoff_path": "...", "orchestrator_mode": true }` | `skill_write_orchestrator_handoff` in `scripts/skill-base.sh` — defined, but currently has **zero callers** anywhere in the deployed tree | This document (below) |

**Both are accepted by every reader and by `validate-handoff.sh`.** `validate-handoff.sh`
already treats `continuation_path` and `continuation_context` as two equally valid forms (its
`required_fields` check accepts either being non-null) — that pre-existing validator behavior is
the precedent the classifier and both orchestrator engines now conform to, not a new contract:
`scripts/orchestrate-triage-classify.sh`'s `continuation_ok` predicate, `skill-orchestrate/SKILL.md`
(Stage 4 partial handler, Stage 5 result read, Stage MT-4 dispatch bullet), and
`skill-orchestrate-hard/SKILL.md` (Stage 4 partial handler, Stage 5 result read) all resolve
**either** form, normalizing to `{ handoff_path, orchestrator_mode: true }` before the value is
handed to a successor dispatch.

**Do not re-narrow this to one form** without updating every one of those reader sites in
lockstep — that is exactly the defect this document once contained: it documented only the
nested form while simultaneously naming a writer (H9 wrap-up) that never emits it, and the
classifier/engines silently only read the nested form, so a real hard-mode continuation was
misclassified as absent. See the "Handoff Writers" table below for the corrected, form-aware
account of what each writer actually emits.

---

## Complete JSON Schema

```json
{
  "$schema": "orchestrator-handoff-v1",

  "phase": "research | plan | implement | revise",

  "status": "researched | planned | implemented | partial | failed | blocked",

  "summary": "2-4 sentence description of what was accomplished. Must be concise — this field has a ~100 token budget. Include: what was done, key outcome, any caveats.",

  "artifacts": [
    {
      "type": "report | plan | summary",
      "path": "specs/NNN_slug/type/file.md"
    }
  ],

  "blockers": [
    {
      "description": "What is blocking implementation — be specific enough that a research fork can investigate this without additional context",
      "phase": "phase-N (where blocker was detected)",
      "severity": "hard | soft"
    }
  ],

  "next_action_hint": "plan | implement | revise | none",

  "files_modified": [
    "list of modified file paths (relative to repo root)"
  ],

  "decisions_made": [
    "Key decision 1 (one sentence each)",
    "Key decision 2"
  ],

  "dead_ends": [
    "Approach tried but failed — so the orchestrator does not retry it"
  ],

  "phases_completed": 2,
  "phases_total": 4,

  "continuation_path": "specs/NNN_slug/handoffs/phase-N-handoff-TIMESTAMP.md",

  "continuation_context": {
    "handoff_path": "specs/NNN_slug/handoffs/phase-N-handoff-TIMESTAMP.md",
    "orchestrator_mode": true
  },

  "plan_markers_verified": true
}
```

`continuation_path` and `continuation_context` are shown together above for schema
documentation only — a real handoff carries **one or the other**, never both (see the "Two
Accepted Forms" table above for which writer emits which).

`phases_completed` and `phases_total` are TOP-LEVEL fields, always — never members of
`continuation_context`. See the `continuation_context` field definition below and the
Completion-Claim Verification Gate section for why this matters.

---

## Field Definitions

### `phase` (required)
Which lifecycle phase just completed.
- `"research"`: `/research` skill completed
- `"plan"`: `/plan` skill completed
- `"implement"`: `/implement` skill completed (full or partial)
- `"revise"`: `/revise` skill completed

### `status` (required)
Outcome of this dispatch cycle.
- `"researched"`: Research complete, report written
- `"planned"`: Plan written, ready for implementation
- `"implemented"`: All plan phases complete
- `"partial"`: Incomplete — see `continuation_context` or `blockers`
- `"failed"`: Non-recoverable failure — implementation cannot continue
- `"blocked"`: Hard blockers prevent progress — escalation required

This six-value enumeration is intentionally identical to `.return-meta.json`'s `status` field.
`context/formats/return-metadata-file.md` is the shared, normative source for both — this field
draws from that table rather than defining a second, independently-maintained enumeration.

### `summary` (required)
2-4 sentences describing what was accomplished. **Token budget: ~100 tokens**. Be concise.
The orchestrator reads this to understand cycle outcome without reading full artifacts.

### `artifacts` (required)
List of artifacts written by this cycle. The orchestrator uses these to populate delegation
context for the next cycle (e.g., plan path for implement dispatch).

### `blockers` (optional)
Non-empty only when `status = "partial"` or `status = "blocked"`. Each blocker entry must
contain enough context for a research fork to investigate without reading full artifacts.

**Severity semantics**:
- `"hard"`: Cannot proceed without resolution. Triggers escalation.
- `"soft"`: Can be worked around. Orchestrator may choose to continue anyway.

### `next_action_hint` (optional)
Suggested next action. The orchestrator's state machine may override this hint. It is advisory only.

### `files_modified` (optional)
Paths of files changed during this cycle. Used by the orchestrator to include in downstream
delegation context (e.g., "the plan was revised to include these changes").

### `decisions_made` (optional)
Key decisions that downstream cycles should be aware of. Prevents downstream agents from
re-investigating already-settled questions.

### `dead_ends` (optional)
Approaches tried but failed. The orchestrator passes these to downstream delegation context
to prevent repetition.

### `phases_completed` / `phases_total` (optional, integers, TOP LEVEL)
Phase-accounting fields read by the completion-claim verification gate (see below). These are
ALWAYS top-level fields on the handoff object — never members of `continuation_context`.
`continuation_context` carries only `handoff_path` and `orchestrator_mode`. The single active
handoff writer (the hard-mode implementation agents' H9 wrap-up) and the orchestrator's readers
at all three call sites (base Stage 5, base Stage MT-4, hard Stage 5) agree on top level; do not
move these fields into `continuation_context` in either a writer or a reader.

**`[COMPLETED WITH EXCLUSIONS]` accounting**: a phase closed via `[COMPLETED WITH EXCLUSIONS]`
(see `context/standards/status-markers.md`'s `[COMPLETED WITH EXCLUSIONS]` subsection) counts
toward `phases_completed` identically to a `[COMPLETED]` phase. The reasoning is the same reason
this whole section exists: `skill_gate_completion_claim` below consumes only these two
self-reported integers and never reads the plan file, so the agent-side self-report at handoff
time is the sole lever. Under-counting an exclusion-closed phase here drives the gate's Case 1
(phase accounting present, incomplete) and refuses completion forever — the task can never reach
`completed` no matter how many times implement re-dispatches, since the plan file (the only place
that could show the phase is actually closed) is never consulted.

**No new handoff field is introduced for this outcome, deliberately.** The `Item | Reason |
Evidence` record itself lives in the plan artifact (`#### Reasoned Exclusions`,
`context/formats/plan-format.md`), and the handoff carries only the already-existing
`phases_completed` integer, incremented exactly as it would be for a plain `[COMPLETED]` phase.
This is a deliberate contrast with the strategic-sorry family member: a strategic sorry DOES carry
a dedicated handoff-side field, `sorry_inventory` (see `wrap-up.md`), because a sorry is
*tracked* with a follow-up that a future dispatch must locate. A reasoned exclusion is *decided
and will not be revisited*, so there is nothing to track and no follow-up-locating field is
needed — the difference in handoff shape follows directly from the difference in the two family
members' defining property (see `context/contracts/anti-analysis.md`'s "Family relationship" note
for that property).

### `continuation_path` (optional, present when `status = "partial"`)
The **flat** form of the continuation pointer: a top-level string naming the continuation
handoff markdown file the agent wrote. This is the form live H9 hard-mode wrap-up writers
actually emit (`context/contracts/wrap-up.md`'s canonical schema; see "Two Accepted Forms"
above). `null` when `status = "implemented"`.

The orchestrator resolves this field (or the nested `continuation_context.handoff_path` below,
whichever is present) and normalizes the result to `{ handoff_path, orchestrator_mode: true }`
before passing it to the next implement dispatch as `continuation_context` in the dispatch
context — see "Reading Contract" below. `orchestrator_mode: true` is supplied by the reader
during this normalization, since a flat `continuation_path` carries no `orchestrator_mode` field
of its own (cross-reference: `### orchestrator_mode Flag` below).

### `continuation_context` (optional, present when `status = "partial"`)
The **nested** form of the continuation pointer: a top-level object `{ handoff_path,
orchestrator_mode }`. Points to the continuation handoff file written by the agent, same as
`continuation_path` above but pre-packaged with `orchestrator_mode`. Written today only by the
unreferenced `skill_write_orchestrator_handoff` (see "Handoff Writers" below) — no active writer
emits it currently, but every reader accepts it, and a future caller of that function produces a
handoff every reader already understands. It does NOT carry `phases_completed` or
`phases_total`.

**Note**: either continuation-pointer form and `blockers` can both be present (partial completion
with identified blockers). The orchestrator handles blockers first via escalation — see
`scripts/orchestrate-triage-classify.sh`'s documented precedence (continuation outranks
blockers whenever a continuation pointer, in either form, is present).

### `plan_markers_verified` (optional, boolean)
Set to `true` when Stage 5a of the implementation agent completed successfully — i.e., all
phase headings in the plan file carry `[COMPLETED]` after the final verification and repair pass.

**Semantics**:
- `true`: Stage 5a ran and confirmed (or repaired) all phase headings to `[COMPLETED]`
- `false` or absent: Stage 5a was skipped, ran but found unresolvable stale markers, or the
  agent did not implement Stage 5a (behavior predating Stage 5a's introduction)

**Orchestrator behavior — the completion-claim verification gate**: `plan_markers_verified` is
the Case 3 corroborating signal consumed by `skill_gate_completion_claim` (defined once, in
`skill-base.sh`, and called identically from all three sites: base Stage 5, base Stage MT-4, and
hard Stage 5). The gate has three fail-closed cases, evaluated in this order:

1. **Case 1 — phase accounting present, incomplete** (`phases_total > 0` and
   `phases_completed < phases_total`): always REFUSES. `plan_markers_verified` is not consulted.
2. **Case 2 — phase accounting present and complete** (`phases_total > 0` and
   `phases_completed >= phases_total`): always ALLOWS. `plan_markers_verified` is not consulted.
3. **Case 3 — phase accounting absent or malformed** (`phases_total == 0`): falls back to
   `plan_markers_verified`. `true` ALLOWS; `false`, absent, `null`, or any other value REFUSES.

A refusal means the `completed` transition does NOT happen this cycle: the task stays
`implementing`, `cycle_count` still increments, and the existing MAX_CYCLES / MAX_CYCLES_MT caps
bound the retry — the next cycle re-dispatches implement against the same plan. This supersedes
the previous "non-blocking warning only" behavior for the phase-accounting-absent case.

Every gate decision logs one of four greppable shapes (all carry the literal token
`COMPLETION-CLAIM GATE case N/3` plus the task number):
```
${log_prefix} COMPLETION-CLAIM GATE case 2/3 (phase accounting present and complete) task ${task_number}: ${phases_completed}/${phases_total} — allowing completion.
${log_prefix} COMPLETION-CLAIM GATE case 1/3 (phase accounting present, incomplete) task ${task_number}: ${phases_completed}/${phases_total} — refusing completion; task stays implementing.
${log_prefix} COMPLETION-CLAIM GATE case 3/3 (phase accounting absent, plan_markers_verified=true) task ${task_number}: allowing completion on the corroborating marker signal.
${log_prefix} COMPLETION-CLAIM GATE case 3/3 (phase accounting absent, plan_markers_verified=${plan_markers_verified}) task ${task_number}: refusing completion — handoff-writer defect suspected; task stays implementing.
```
`${log_prefix}` is `[orchestrate]` (base and multi-task) or `[hard-orchestrate]` (hard mode).

### Handoff Writers

| Writer | Status | Continuation form emitted | Notes |
|--------|--------|----------------------------|-------|
| `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (H9 Stage 5) | Active | **Flat** `continuation_path` | The only active writer of `.orchestrator-handoff.json` today; see `context/contracts/wrap-up.md`'s canonical schema |
| cslib and lean hard-mode implementation agent counterparts | Active | **Flat** `continuation_path` | Mirror the core H9 wrap-up. Exception: `cslib-implementation-hard-agent.md` Stage 5 currently hardcodes `continuation_context: null` with no population instruction — a separate, narrower defect than the one this document's rewrite addresses; tracked as a named follow-up, not fixed here. |
| `skill_write_orchestrator_handoff` in `agent-system/extensions/core/scripts/skill-base.sh` | **Defined, unreferenced** — zero callers anywhere in the deployed tree | **Nested** `continuation_context` | Documented as dead (not deleted, not rewired) as of the reader dual-form fix: since every reader now accepts its nested output, a future caller may use it as-is. |
| Base-mode `skill-researcher`, `skill-planner`, `skill-implementer` | Never writes a handoff, by design | Neither (no handoff written at all) | Research is explicitly prohibited from writing one (Stage 3.6 "Scoping Decision" in the research agents); base-mode plan/implement simply never gained a writer. This is an expected, `.return-meta.json`-recoverable case — see "Outcome Channels" below — not an unaddressed defect. |

**Reader/writer form agreement, corrected**: prior revisions of this table named
`general-implementation-hard-agent.md`'s H9 Stage 5 as "the only active writer" while the schema
above documented only the nested `continuation_context` form — a form that writer never emits.
Every reader (the classifier and both SKILL.md engines) now accepts whichever form a writer
actually produces; see "Two Accepted Forms" above.

`agent-system/extensions/core/scripts/validate-handoff.sh` independently requires
`phases_completed` and `phases_total` as top-level fields (its `required_fields` array reads them
via `jq ".phases_completed"` / `jq ".phases_total"`, not `.continuation_context.phases_completed`
/ `.continuation_context.phases_total`) — corroborating that top level, not nested under
`continuation_context`, is the canonical schema documented above. No change to that script was
needed or made.

**`validate-handoff.sh` wiring status**: this script was previously correct but unwired — no
call site invoked it. It is now invoked as a **log-only, non-gating** producer-defect diagnostic
from `skill_corroborate_phase_counts()` in `agent-system/extensions/core/scripts/skill-base.sh`,
firing only when that function receives a non-empty, existing `handoff_path` argument (the
handoff-present corroboration call sites in `skill-orchestrate/SKILL.md` and
`skill-orchestrate-hard/SKILL.md` Stage 5 pass the current handoff; the recovery-path call sites
pass an empty string, since there is no handoff to validate there). Its exit status never
influences `skill_corroborate_phase_counts()`'s own return value or the completion-claim gate.

---

## Outcome Channels

`.orchestrator-handoff.json` is the **primary** outcome channel Stage 5 (single-task, base and
hard mode) and Stage MT-4 step 1 (multi-task) read after a dispatch. It is written by exactly one
active writer today (the hard-mode implementation agent's H9 wrap-up) — see Handoff Writers above.

`.return-meta.json` is the **fallback** outcome channel, consulted only inside the
missing/stale-handoff branch, for the writers in the "Never writes a handoff, by design" row: a
missing handoff from base-mode research, plan, or implement is the expected outcome for those
writers, not a defect, since `.return-meta.json` is written by every research/plan/implement
dispatch (base and hard mode alike) per each skill's own Stage 7 postflight contract.

`agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` is the single, shared
implementation of this fallback — the ONE place that normalizes `.return-meta.json`'s `status`,
`artifacts[0]`, and phase-accounting fields into the same outcome shape Stage 5 already reads from
a handoff (`recovered`, `status`, `phases_completed`, `phases_total`, `artifact_path/type/summary`,
plus a `reason` token for the non-recovered case). Base Stage 5, hard-mode Stage 5, and multi-task
Stage MT-4 step 1 each call this one script rather than maintaining three separately-derived
recovery rules. See that script's own header for its full field/exit-code contract, and see the
"MUST NOT (Context Flatness Constraint) — Recovery exception (return-meta fallback)" section in
`skills/skill-orchestrate/SKILL.md` for the token-budget and fail-closed bounds it operates under.

A recovered outcome is fail-closed: only a present, fresh (within the current dispatch window),
parseable `.return-meta.json` whose `status` is `researched`, `planned`, or `implemented` is ever
treated as a success. A missing, stale, unparseable, `in_progress`, or otherwise non-success
`.return-meta.json` preserves the pre-existing missing-handoff error path exactly, unchanged by
this fallback. This three-value accept-list is drawn from the same normative vocabulary in
`context/formats/return-metadata-file.md` as the schema field above — it is restated here only
because it is a strict subset (the success values), not a competing enumeration.

**Freshness is orthogonal to vocabulary, by design.** The accept-list above needed no change when
the skill-status vocabulary's forbidden `"completed"` writer was fixed elsewhere (Stage 8 of
`skill-orchestrate/SKILL.md` now emits `"implemented"`): this script's gate is `meta_mtime` versus
the current dispatch's `window_start_ts`, not the status string. A `.return-meta.json` left over
from a *previous* invocation's Stage 8 always has an mtime before the current invocation's
`window_start_ts` and is therefore classified stale regardless of what status value it contains.
Do not couple these two mechanisms — a future change to the status vocabulary should never need a
corresponding change here, and vice versa.

**`completion_summary` / `roadmap_items` live exclusively in `.return-meta.json`, never in this
handoff.** The JSON Schema above has no `completion_summary` or `roadmap_items` field, and none
should ever be added to it: these two values are completion metadata (see
`context/formats/return-metadata-file.md`'s `completion_data` object), not dispatch-outcome
metadata, and they are read exclusively through `orchestrate-recover-outcome.sh`'s
`completion_summary`/`roadmap_items` output fields — regardless of whether a handoff is present or
missing for that dispatch. This matters most for hard mode: its implement dispatch ALWAYS writes
a handoff (H9 wrap-up), so its `implemented` outcome is read from the handoff-present branch, not
the recovery branch above — if a future editor assumed the handoff carried completion data (by
analogy with `status`/`phases_completed`/artifact fields, which it does carry), the propagation
would silently break again. Every `implemented)` postflight site (base Stage 5, hard Stage 5,
Stage MT-4 step 3) therefore issues its own `orchestrate-recover-outcome.sh` read for this purpose
independently of which branch supplied `dispatch_status`, reusing that cycle's already-recovered
JSON when the recovery branch already ran rather than reading the file twice.

---

## Token Budget Constraints

The full `.orchestrator-handoff.json` object MUST stay under **400 tokens**. This is the mechanism
that keeps orchestrator context flat across cycles.

Field-level budgets:
| Field | Max Tokens |
|-------|-----------|
| `summary` | ~100 |
| `artifacts` (all entries) | ~50 |
| `blockers` (all entries) | ~100 |
| `decisions_made` (all entries) | ~50 |
| `dead_ends` (all entries) | ~50 |
| `files_modified` (all entries) | ~30 |
| `continuation_path` OR `continuation_context` (whichever form is present; never both) | ~20 |
| Schema overhead (field names, JSON structure) | ~50 |

If content would exceed 400 tokens, truncate `decisions_made` and `dead_ends` first (these are
advisory). Never truncate `status`, `summary`, or `blockers`.

---

## Writing Contract

### When to Write

Skills MUST write `.orchestrator-handoff.json` when and ONLY when `"orchestrator_mode": true`
appears in the delegation context received from the skill wrapper.

```bash
# In skill SKILL.md, after receiving delegation context:
orchestrator_mode=$(echo "$delegation_context" | jq -r '.orchestrator_mode // "false"')

if [ "$orchestrator_mode" = "true" ]; then
  write_orchestrator_handoff
fi
```

When NOT in orchestrator mode (normal `/research`, `/plan`, `/implement` invocation), skills do
NOT write this file. The file's presence signals orchestrator dispatch.

### File Path

```bash
handoff_path="specs/${padded_num}_${project_name}/.orchestrator-handoff.json"
```

The filename is static (not timestamped). Each dispatch cycle overwrites the previous handoff.
There is no session-scoped variant: per-task directories already isolate concurrent
different-task sessions, and `task-lock.sh`'s acquire/heartbeat/release contract already
serializes concurrent same-task sessions, so a session component here would add nothing.

### When to Write a Continuation Pointer

Write a continuation pointer — in **either** accepted form (see "Two Accepted Forms" above) —
only when the skill returns `status = "partial"` AND a continuation handoff file was written by
the agent. The continuation handoff path comes from the agent's `.return-meta.json`
`partial_progress.handoff_path` field.

- Hard-mode wrap-up (the only active writer today) writes the **flat** top-level
  `continuation_path` string, per `context/contracts/wrap-up.md`.
- `skill_write_orchestrator_handoff` (unreferenced today) would write the **nested**
  `continuation_context` object, per this document.

Whichever form a future writer chooses, every reader accepts it — see "Two Accepted Forms".

### `orchestrator_mode` Flag in Continuation Context

A flat `continuation_path` string carries no `orchestrator_mode` field of its own — there is
nowhere on a bare string to attach one. The **reader** supplies `orchestrator_mode: true` during
normalization: every reader site (the classifier and both SKILL.md engines) resolves whichever
form is present and builds `{ handoff_path: <resolved path>, orchestrator_mode: true }` before
handing the result to the next dispatch as `continuation_context`. This is the same
normalization Phase 3 of the continuation-pointer reader fix added to the base engine's
dispatch-context construction, and it is unconditional — `orchestrator_mode: true` is set
regardless of which form supplied `handoff_path`.

When a writer instead emits the **nested** form directly (`skill_write_orchestrator_handoff`,
today unreferenced), it MUST preserve the `orchestrator_mode` flag itself, since in that case the
value already exists on the object being written rather than being synthesized by the reader:

```json
{
  "status": "partial",
  "phases_completed": 2,
  "phases_total": 4,
  "continuation_context": {
    "handoff_path": "specs/.../handoffs/phase-2-handoff-T.md",
    "orchestrator_mode": true
  }
}
```

Either way — reader-synthesized (flat writer) or writer-preserved (nested writer) — the next
implement dispatch receives `orchestrator_mode: true` and continues operating in orchestrator
mode rather than re-enabling the inner continuation loop.

---

## Reading Contract

The orchestrator reads the handoff after each dispatch:

```bash
handoff_file="specs/${padded_num}_${project_name}/.orchestrator-handoff.json"

# Safety: check file exists before reading
if [ ! -f "$handoff_file" ]; then
  echo "[orchestrate] ERROR: handoff not written by skill (orchestrator_mode not detected?)"
  exit 1
fi

# Read only what the state machine needs — do NOT load full artifacts
handoff=$(cat "$handoff_file")
status=$(echo "$handoff" | jq -r '.status')
blockers=$(echo "$handoff" | jq -c '.blockers // []')
next_hint=$(echo "$handoff" | jq -r '.next_action_hint // "none"')
# Dual-form resolution + normalization: accept EITHER the nested continuation_context.handoff_path
# OR the flat top-level continuation_path (see "Two Accepted Forms" above), and normalize the
# result to a single shape before it reaches a downstream dispatch context.
continuation=$(echo "$handoff" | jq -c '
  ((.continuation_context // null) | if . != null then (.handoff_path // null) else null end) as $nested |
  (.continuation_path // null) as $flat |
  ($nested // $flat) as $resolved |
  if $resolved != null then {handoff_path: $resolved, orchestrator_mode: true} else null end
')
artifacts=$(echo "$handoff" | jq -c '.artifacts // []')
phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
plan_markers_verified=$(echo "$handoff" | jq -r '.plan_markers_verified // "absent"')
```

This dual-form resolution is applied identically at every reader site:
`scripts/orchestrate-triage-classify.sh`'s `continuation_ok` predicate,
`skill-orchestrate/SKILL.md` (Stage 4 partial handler, Stage 5 result read, Stage MT-4 dispatch
bullet), and `skill-orchestrate-hard/SKILL.md` (Stage 4 partial handler, Stage 5 result read).
It is one rule, applied in several places — never independently re-derived.

When `status = "implemented"`, the orchestrator additionally calls
`skill_gate_completion_claim` (see the `plan_markers_verified` field definition above) to decide
whether the `completed` transition is corroborated. This introduces NO new file read — it
consumes only fields already parsed out of the handoff object above, so the ~450-tokens-per-cycle
context-flatness invariant is unchanged and the three sanctioned grep exceptions table below is
unaffected.

On the normal path the orchestrator reads the ~400-token handoff object and nothing else — it
never opens research reports, plan files, or implementation summaries for comprehension. Three
narrow, grep-only exceptions are sanctioned, and all three are bounded to `### Phase N: ...
[STATUS]` heading lines or equivalent pattern matches, never full-file reads:

| Exception | Variant | When it fires | Bound |
|-----------|---------|---------------|-------|
| Adversarial-verification grep over reports | hard mode | Stage 4, before the plan dispatch | Pattern match; no full-file read |
| Next-phase selection grep over the plan | hard mode | Stage 4 `planned`/`implementing` handler, every cycle | One matched heading, reduced to a phase number |
| Phase-marker recovery grep over the plan | base + hard | Stage 5, missing/stale-handoff branch only | Two `grep -c` integers, ≤10 tokens per recovery event |

Outside these three, the reading contract is unchanged: the handoff object is the sole channel
by which artifact content reaches the orchestrator. See the "Recovery exception (phase-marker
grep)" contract in `skill-orchestrate/SKILL.md` and the Read allowlist in
`skill-orchestrate-hard/SKILL.md` for the binding wording.

---

## Example Handoff Objects

### Successful Research

```json
{
  "$schema": "orchestrator-handoff-v1",
  "phase": "research",
  "status": "researched",
  "summary": "Researched shared command infrastructure patterns across research.md, plan.md, and implement.md. Found ~525 lines of identical duplication across 3 commands. Identified 3 extraction candidates: parse-command-args.sh, command-gate-in.sh, command-gate-out.sh.",
  "artifacts": [
    {"type": "report", "path": "specs/593_extract_shared_workflow_utilities/reports/01_extraction-research.md"}
  ],
  "blockers": [],
  "next_action_hint": "plan",
  "files_modified": [],
  "decisions_made": [
    "Extraction to .claude/scripts/ is preferred over context documents (scripts can be executed)"
  ],
  "dead_ends": []
}
```

### Successful Implementation

```json
{
  "$schema": "orchestrator-handoff-v1",
  "phase": "implement",
  "status": "implemented",
  "summary": "Implemented all 3 shared command scripts. parse-command-args.sh, command-gate-in.sh, and command-gate-out.sh created. research.md, plan.md, implement.md updated to source shared scripts. All verification tests passed.",
  "artifacts": [
    {"type": "summary", "path": "specs/593_extract_shared_workflow_utilities/summaries/01_extraction-summary.md"}
  ],
  "blockers": [],
  "next_action_hint": "none",
  "files_modified": [
    ".claude/scripts/parse-command-args.sh",
    ".claude/scripts/command-gate-in.sh",
    ".claude/scripts/command-gate-out.sh",
    ".claude/commands/research.md",
    ".claude/commands/plan.md",
    ".claude/commands/implement.md"
  ],
  "decisions_made": [
    "Command files now source shared scripts via 'source .claude/scripts/NAME.sh'",
    "Existing update-task-status.sh and validate-artifact.sh left unchanged"
  ],
  "dead_ends": [],
  "plan_markers_verified": true
}
```

### Partial with Continuation (flat form — what a live writer actually produces)

This is the shape hard-mode H9 wrap-up (`general-implementation-hard-agent.md` Stage 5, the only
active writer today) actually emits — a flat top-level `continuation_path` string, per
`context/contracts/wrap-up.md`:

```json
{
  "$schema": "orchestrator-handoff-v1",
  "phase": "implement",
  "status": "partial",
  "summary": "Completed phases 1-2 of 4 (parse-command-args.sh and command-gate-in.sh created). Context exhaustion during phase 3. Continuation handoff written at specified path.",
  "artifacts": [
    {"type": "summary", "path": "specs/593_extract_shared_workflow_utilities/summaries/01_extraction-summary.md"}
  ],
  "blockers": [],
  "next_action_hint": "implement",
  "files_modified": [
    ".claude/scripts/parse-command-args.sh",
    ".claude/scripts/command-gate-in.sh"
  ],
  "decisions_made": [
    "parse-command-args.sh exports FOCUS_PROMPT as remaining text after all flags stripped"
  ],
  "dead_ends": [],
  "phases_completed": 2,
  "phases_total": 4,
  "continuation_path": "specs/593_extract_shared_workflow_utilities/handoffs/phase-3-handoff-20260522T120000Z.md"
}
```

The orchestrator reader resolves `continuation_path` above and normalizes it to
`{ handoff_path: "specs/593_extract_shared_workflow_utilities/handoffs/phase-3-handoff-20260522T120000Z.md", orchestrator_mode: true }`
before passing it to the next implement dispatch — see "Reading Contract" below.

### Partial with Continuation (nested form — the `skill_write_orchestrator_handoff` shape)

This is the shape `skill_write_orchestrator_handoff` in `scripts/skill-base.sh` would write, were
it ever called (it currently has zero callers — see "Handoff Writers" above). Every reader
accepts this form identically to the flat form above:

```json
{
  "$schema": "orchestrator-handoff-v1",
  "phase": "implement",
  "status": "partial",
  "summary": "Completed phases 1-2 of 4 (parse-command-args.sh and command-gate-in.sh created). Context exhaustion during phase 3. Continuation handoff written at specified path.",
  "artifacts": [
    {"type": "summary", "path": "specs/593_extract_shared_workflow_utilities/summaries/01_extraction-summary.md"}
  ],
  "blockers": [],
  "next_action_hint": "implement",
  "files_modified": [
    ".claude/scripts/parse-command-args.sh",
    ".claude/scripts/command-gate-in.sh"
  ],
  "decisions_made": [
    "parse-command-args.sh exports FOCUS_PROMPT as remaining text after all flags stripped"
  ],
  "dead_ends": [],
  "phases_completed": 2,
  "phases_total": 4,
  "continuation_context": {
    "handoff_path": "specs/593_extract_shared_workflow_utilities/handoffs/phase-3-handoff-20260522T120000Z.md",
    "orchestrator_mode": true
  }
}
```

### Blocked with Escalation Required

```json
{
  "$schema": "orchestrator-handoff-v1",
  "phase": "implement",
  "status": "partial",
  "summary": "Implemented parse-command-args.sh successfully. Blocked at command-gate-in.sh: the current update-task-status.sh script does not export SESSION_ID, which is required by the gate-in design.",
  "artifacts": [],
  "blockers": [
    {
      "description": "update-task-status.sh does not export SESSION_ID; command-gate-in.sh needs to generate SESSION_ID independently or update-task-status.sh needs modification",
      "phase": "phase-2",
      "severity": "hard"
    }
  ],
  "next_action_hint": "revise",
  "files_modified": [".claude/scripts/parse-command-args.sh"],
  "decisions_made": [],
  "dead_ends": [
    "Tried sourcing update-task-status.sh to get SESSION_ID — it does not set this variable"
  ]
}
```

---

## Relationship to Continuation Handoffs

The orchestrator handoff and continuation handoff are written by different components and read by
different consumers:

```
general-implementation-hard-agent (H9 wrap-up, the only active writer today):
  ├── Writes: handoffs/phase-2-handoff-T.md   (for successor agent)
  └── Writes: .orchestrator-handoff.json      (for skill-orchestrate / skill-orchestrate-hard)
              └── continuation_path = "handoffs/phase-2-handoff-T.md"   (flat form — see
                  "Two Accepted Forms" above; a nested-writing caller of
                  skill_write_orchestrator_handoff would instead set
                  continuation_context.handoff_path to the same value)

skill-orchestrate / skill-orchestrate-hard (next cycle):
  ├── Reads: .orchestrator-handoff.json       (400 tokens)
  │          └── resolves EITHER continuation_path OR continuation_context.handoff_path
  └── Passes: normalized continuation_context = { handoff_path, orchestrator_mode: true }
              to next implement dispatch
              └── successor agent reads: handoffs/phase-2-handoff-T.md
```

The two files are never confused because:
1. They are in different locations (`.orchestrator-handoff.json` vs. `handoffs/*.md`)
2. They use different formats (JSON vs. Markdown)
3. They are read by different components (skill-orchestrate vs. successor agent)
