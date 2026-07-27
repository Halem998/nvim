# Orchestrator Handoff JSON Schema

**Status**: Current architecture.

**File location**: `specs/{NNN}_{SLUG}/.orchestrator-handoff.json` (runtime; not checked in)
**Written by**: Skills when `orchestrator_mode: true` in delegation context
**Read by**: `skill-orchestrate` state machine loop

**See Also**: `architecture-spec.md` (Component 5), `orchestrate-state-machine.md`

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

  "continuation_context": {
    "handoff_path": "specs/NNN_slug/handoffs/phase-N-handoff-TIMESTAMP.md",
    "orchestrator_mode": true
  },

  "plan_markers_verified": true
}
```

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

### `continuation_context` (optional, present when `status = "partial"`)
Points to the continuation handoff file written by the agent. The orchestrator reads
`handoff_path` and passes it in the next implement dispatch as `continuation_context`. It also
carries `orchestrator_mode` (see below). It does NOT carry `phases_completed` or `phases_total`.

**Note**: `continuation_context` and `blockers` can both be present (partial completion with
identified blockers). The orchestrator handles blockers first via escalation.

### `plan_markers_verified` (optional, boolean)
Set to `true` when Stage 5a of the implementation agent completed successfully — i.e., all
phase headings in the plan file carry `[COMPLETED]` after the final verification and repair pass.

**Semantics**:
- `true`: Stage 5a ran and confirmed (or repaired) all phase headings to `[COMPLETED]`
- `false` or absent: Stage 5a was skipped, ran but found unresolvable stale markers, or the
  agent did not implement Stage 5a (pre-task-764 behavior)

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

| Writer | Status | Notes |
|--------|--------|-------|
| `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (H9 Stage 5) | Active | The only active writer of `.orchestrator-handoff.json` today |
| cslib and lean hard-mode implementation agent counterparts | Active | Mirror the core H9 wrap-up |
| `skill_write_orchestrator_handoff` in `agent-system/extensions/core/scripts/skill-base.sh` | Defined, unreferenced | No caller currently invokes it |
| Base-mode `skill-researcher`, `skill-planner`, `skill-implementer` | Never writes a handoff, by design | Research is explicitly prohibited from writing one (Stage 3.6 "Scoping Decision" in the research agents); base-mode plan/implement simply never gained a writer. This is an expected, `.return-meta.json`-recoverable case — see "Outcome Channels" below — not an unaddressed defect. |

`agent-system/extensions/core/scripts/validate-handoff.sh` independently requires
`phases_completed` and `phases_total` as top-level fields (its `required_fields` array reads them
via `jq ".phases_completed"` / `jq ".phases_total"`, not `.continuation_context.phases_completed`
/ `.continuation_context.phases_total`) — corroborating that top level, not nested under
`continuation_context`, is the canonical schema documented above. No change to that script was
needed or made.

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
| `continuation_context` | ~20 |
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

**Exception**: If concurrent `/orchestrate` invocations are possible, include session_id:
```bash
handoff_path="specs/${padded_num}_${project_name}/.orchestrator-handoff-${session_id}.json"
```

The orchestrator reads its own session's file using the same session_id it wrote to the
loop guard.

### When to Write `continuation_context`

Write `continuation_context` only when the skill returns `status = "partial"` AND a continuation
handoff file was written by the agent. The continuation handoff path comes from the agent's
`.return-meta.json` `partial_progress.handoff_path` field.

### `orchestrator_mode` Flag in Continuation Context

When skill-implementer runs in orchestrator_mode and returns partial, it MUST preserve the
`orchestrator_mode` flag in the continuation_context embedded in the orchestrator handoff:

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

This ensures the next implement dispatch (via the orchestrator's re-dispatch) still operates
in orchestrator mode and does not re-enable the inner continuation loop.

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
continuation=$(echo "$handoff" | jq -c '.continuation_context // null')
artifacts=$(echo "$handoff" | jq -c '.artifacts // []')
phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
plan_markers_verified=$(echo "$handoff" | jq -r '.plan_markers_verified // "absent"')
```

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

### Partial with Continuation

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
skill-implementer (in orchestrator_mode):
  ├── Writes: handoffs/phase-2-handoff-T.md   (for successor agent)
  └── Writes: .orchestrator-handoff.json      (for skill-orchestrate)
              └── continuation_context.handoff_path = "handoffs/phase-2-handoff-T.md"

skill-orchestrate (next cycle):
  ├── Reads: .orchestrator-handoff.json       (400 tokens)
  │          └── sees continuation_context.handoff_path
  └── Passes: continuation_context to next implement dispatch
              └── successor agent reads: handoffs/phase-2-handoff-T.md
```

The two files are never confused because:
1. They are in different locations (`.orchestrator-handoff.json` vs. `handoffs/*.md`)
2. They use different formats (JSON vs. Markdown)
3. They are read by different components (skill-orchestrate vs. successor agent)
