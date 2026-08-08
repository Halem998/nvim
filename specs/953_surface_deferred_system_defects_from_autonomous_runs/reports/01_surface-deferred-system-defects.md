# Research Report: Task #953

**Task**: 953 - Surface deferred system-defect detections from autonomous runs
**Started**: 2026-08-08T00:00:00Z
**Completed**: 2026-08-08T00:00:00Z
**Effort**: medium
**Dependencies**: prerequisite recorder task (system-defect-record.sh + wired detection sites) — already merged
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/system-defect-record.sh`
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- `agent-system/extensions/core/commands/orchestrate.md`
- `agent-system/extensions/core/scripts/skill-base.sh`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The recorder (`system-defect-record.sh`) and its wired detection sites already exist and are
  loud at detection time, but nothing durable accumulates *within a single autonomous run* and
  nothing renders an enumerated summary — exactly the gap the two named precedents
  (`defer_ledger`, the literature `[lit:auto]` directive) already solved for structurally
  identical problems.
- There are **eleven** live detection call sites across the two skill files and one shared
  helper: four in `skill-orchestrate/SKILL.md`'s single-task Stage 5, two in its Stage MT-4, four
  in `skill-orchestrate-hard/SKILL.md`'s single-task Stage 5 (a structurally separate
  implementation, not a thin wrapper), and one shared site — `skill_gate_completion_claim`'s
  Case 3/3 refuse in `scripts/skill-base.sh` — reached from three of the other locations.
- **Scope tension found and resolved**: the declared `file_scope` for this task excludes
  `scripts/skill-base.sh`, but the `META_MISSING_AFTER_NARRATION` detector lives inside that
  file's `skill_gate_completion_claim`. This is resolvable without touching `skill-base.sh` at
  all: every call site already has `$phases_total` and `$plan_markers_verified` in scope after
  the gate call, which is exactly the discriminant between an ordinary Case-1 refuse (not a
  defect) and the Case-3/3 defect refuse. The caller can re-derive "was this refusal a recorded
  defect?" locally.
- **Two accumulator homes, not one**: multi-task batches already have `mt_state_file`
  (`specs/.orchestrator-multi-state-${session_id}.json`), where a new field sits naturally
  beside `defer_ledger`. Single-task runs have no batch state file at all — the closest analogue
  is `.orchestrator-loop-guard` (`${TASK_DIR}/.orchestrator-loop-guard`), the per-invocation
  ephemeral runtime file already carrying `cycle_count`/`infra_failures`. Both needed for
  "single-task runs need the same treatment as multi-task batches."
- **Asymmetry found**: `skill-orchestrate-hard/SKILL.md`'s single-task Stage 8 is titled
  "Cleanup" and only removes the loop-guard/churn files — it has **no** existing
  `.return-meta.json` metadata-merge step to piggyback on (base's Stage 8 has one, at
  lines 1220–1270). A new merge subsection must be added to hard mode's Stage 8, not just a
  field added to an existing one.
- No detection site anywhere in either file currently calls `AskUserQuestion`; the whole
  mechanism (recorder call → ledger append → tagged notice) is pure bash/jq, so the "never call
  AskUserQuestion when orchestrator_mode is true" constraint is satisfiable by construction. A
  **pre-existing, unrelated** `AskUserQuestion` does exist in hard mode's Stage 6 blocker
  escalation (line ~1469) — flagged here as an adjacent, out-of-scope finding, not something this
  task's surface touches.

## Context & Scope

This is prerequisite-complete work: the recorder script and every currently-wired detection site
already write durable, deduplicated `event_type: "system_defect"` rows to `specs/events.jsonl`.
What's missing is a **run-scoped, in-transcript surface** — so an operator watching an autonomous
`/orchestrate` batch (where `orchestrator_mode: true` makes `AskUserQuestion` unusable) sees, at
minimum, an enumerated end-of-run summary, and ideally a per-detection notice as it happens.

The two precedents named in the task description were both re-read and confirmed as structurally
apt:

1. **`defer_ledger`** (`skill-orchestrate/SKILL.md` Stage MT-1, declared ~line 1375): "an
   APPEND-ONLY OBSERVATION LOG of every per-cycle defer/exclusion event... written for reporting
   and read only at Stage MT-5 and by `commands/orchestrate.md` Step 5. It is not a fifth
   admission gate and must never become one." Its entries carry
   `{"task", "defer_reason", "collision_scope", "cycle", "detail"}` — note this shape has **no**
   `detecting_site` or `defect_class`/`attributed_source_path` field, confirming the new
   structure must be a genuinely new, separately-declared field (never overloaded onto
   `defer_ledger` itself), exactly as the task description instructs.
2. **`[lit:auto]`** (CLAUDE.md's Literature Mode section, `AUTONOMOUS_GLOBAL` directive): when
   `orchestrator_mode == true`, the mechanism "MUST NOT call [AskUserQuestion]... it takes the
   deterministic default... and emits a visible `[lit:auto]` notice... This is never a silent
   no-op." The same shape — deterministic default + visibly-tagged notice — is the template for
   this task's "visibly-tagged per-detection notice."

## Findings

### The recorder's contract (what a call site already has in hand)

`scripts/system-defect-record.sh` (out of `file_scope` for this task, read-only reference):

- Every call site already passes `--defect-class`, `--detecting-site`, `--message`, and either
  `--attributed-path` or `--dispatched-agent` (which resolves to a source-store path under
  `agent-system/extensions/**`) — i.e. **every piece of data the REQUIRED BEHAVIOUR bullet asks
  for (defect class, attributed source-store path, detecting site) is already a local shell
  variable at each call site before the recorder is even invoked.** No new data-gathering is
  needed; only a second, additive write (to the ledger) alongside the existing recorder call.
- On stdout: the `event_id` on a successful record, or `SUPPRESSED:recursion_guard` /
  `SUPPRESSED:duplicate` on a deliberate no-write. Every call site today discards this
  (`>/dev/null 2>&1`). Capturing it (dropping the `>/dev/null` half only, keeping `2>&1`
  discarded as today) gives the ledger entry an optional `record_result` field, useful for an
  operator to see "was this actually a NEW durable record, or an already-tracked dup?" — but the
  ledger append itself must NOT be conditioned on this value: the requirement is to surface every
  detection *this run*, independent of whether the recorder's own cross-run dedup rule (identity
  key `{defect_class}:{attributed_source_path}`, see the discrimination doc's "deduplication
  rule" section) suppressed the durable write. This mirrors `defer_ledger`'s own unconditional-
  append behavior — it never asks "is this already ledgered elsewhere?" before appending.
- Exit codes 2 (recursion-guard data file missing/unparseable) and 3 (Signal B attribution
  unresolvable) both mean *nothing was written* to `events.jsonl`, but the caller's own detection
  already fired — the ledger append should still happen (with `record_result` reflecting the
  refusal) since the goal is "surface what fired," not "surface what was durably recorded."

### The eleven live detection call sites

| # | File | Site (Stage) | Line (approx) | `defect_class` | Reachable from |
|---|------|--------------|----------------|-----------------|-----------------|
| 1 | `skill-orchestrate/SKILL.md` | Stage 5, stale-handoff gate | ~572 | `HANDOFF_STALE_OR_ABSENT` | single-task |
| 2 | `skill-orchestrate/SKILL.md` | Stage 5, stray-handoff sweep | ~600 | `HANDOFF_MISLOCATED` | single-task |
| 3 | `skill-orchestrate/SKILL.md` | Stage 5, recovered-path evidence arm | ~712 | `ARTIFACTS_SHAPE_MISMATCH` | single-task |
| 4 | `skill-orchestrate/SKILL.md` | Stage 5, Tier C off-schema | ~1006 | `OFF_SCHEMA_STATUS` | single-task |
| 5 | `skill-orchestrate/SKILL.md` | Stage MT-4 step 1, recovered-path evidence arm | ~1935 | `ARTIFACTS_SHAPE_MISMATCH` | multi-task |
| 6 | `skill-orchestrate/SKILL.md` | Stage MT-4 step 3, off-schema | ~2097 | `OFF_SCHEMA_STATUS` | multi-task |
| 7 | `skill-orchestrate-hard/SKILL.md` | Stage 5, stale-handoff gate | ~970 | `HANDOFF_STALE_OR_ABSENT` | single-task (hard) |
| 8 | `skill-orchestrate-hard/SKILL.md` | Stage 5, stray-handoff sweep | ~998 | `HANDOFF_MISLOCATED` | single-task (hard) |
| 9 | `skill-orchestrate-hard/SKILL.md` | Stage 5, recovered-path evidence arm | ~1094 | `ARTIFACTS_SHAPE_MISMATCH` | single-task (hard) |
| 10 | `skill-orchestrate-hard/SKILL.md` | Stage 5, Tier C off-schema | ~1378 | `OFF_SCHEMA_STATUS` | single-task (hard) |
| 11 | `scripts/skill-base.sh` `skill_gate_completion_claim` Case 3/3 | ~638 (out of file_scope) | `META_MISSING_AFTER_NARRATION` | reached from base single-task Stage 5 (~933), base Stage MT-4 step 3 (~2027-2038), and hard single-task Stage 5 (~1323) |

Hard mode's `Multi-Task Mode` section (line ~1520) states explicitly: "Same as base
`skill-orchestrate` multi-task stages (MT-1 through MT-5)." Confirmed via the base file's own
Stage MT-1 comment (~1388-1396): "`skills/skill-orchestrate-hard/SKILL.md` has no MT-stage
implementation of its own... Multi-task `/orchestrate --hard` therefore already writes
`mt_state_file.dispatch_start_ts`, `defer_ledger`, and `forward_progress_violated` via this same
file with no separate hard-mode edit needed." **This means sites #5 and #6 above are the sole
multi-task detection sites for BOTH base and hard mode** — no separate hard-mode MT wiring is
needed for either the accumulator or the append logic; editing `skill-orchestrate/SKILL.md`'s
Stage MT-4 once covers both.

### Site #11: resolving the `skill-base.sh` file-scope tension without touching it

At all three reachable call sites, `$phases_total` and `$plan_markers_verified` are already
local variables passed as arguments to `skill_gate_completion_claim` immediately before the call:

```bash
if skill_gate_completion_claim "$task_number" "$phases_completed" "$phases_total" \
     "$plan_markers_verified" "[orchestrate]"; then
  # allow branch (existing)
  ...
fi
# NEW: else branch here can re-derive Case 3/3 without reading skill-base.sh's internals
```

`skill_gate_completion_claim`'s own three-case ladder (verified in `scripts/skill-base.sh`,
lines ~604-647) is: Case 2 (`phases_total > 0` and complete) → allow; Case 1 (`phases_total > 0`,
incomplete) → refuse, **not a defect**; Case 3 (`phases_total == 0`) → allow if
`plan_markers_verified == "true"`, else refuse **and record `META_MISSING_AFTER_NARRATION`**.
So a caller-side `else` branch can classify its own refusal exactly the same way the function
does internally, using only variables it already has:

```bash
else
  if [ "$phases_total" -eq 0 ] && [ "$plan_markers_verified" != "true" ]; then
    # This refusal was Case 3/3 — skill_gate_completion_claim already called
    # system-defect-record.sh internally (defect_class=META_MISSING_AFTER_NARRATION,
    # detecting-site="scripts/skill-base.sh:skill_gate_completion_claim"). Append the
    # SAME facts to this call site's own ledger — no read of skill-base.sh needed.
  fi
fi
```

The `--attributed-path` used internally by the function is resolved via a fixed two-entry
`log_prefix` lookup (`[orchestrate]` → `skill-orchestrate/SKILL.md`, `[hard-orchestrate]` →
`skill-orchestrate-hard/SKILL.md`) — each caller already knows its own path statically, so this
too needs no read-back. **Recommendation: implement site #11's ledger append at all three
call sites via this discriminant, keeping `scripts/skill-base.sh` untouched and the declared
three-file `file_scope` intact.** (An alternative — widening `file_scope` to add
`scripts/skill-base.sh` and having the function itself accept an optional ledger-file parameter —
was considered and is cleaner in the abstract, but is unnecessary given the discriminant above and
would require crossing the declared scope boundary; noted here as an option for planning, not a
recommendation.)

### Accumulator declaration and shape

Two additive fields are needed, deliberately new — never overloaded onto `defer_ledger` (whose
`defer_reason` vocabulary is load-bearing for admission reporting, per the task description) and
never merged with `verify_deploy_baseline_notices` (a different observation log for a different,
already-fully-specified concern).

**Multi-task**: `mt_state_file.detected_defects: []`, declared in Stage MT-1 immediately after
`defer_ledger`'s own declaration (`skill-orchestrate/SKILL.md` ~line 1385, right before
`forward_progress_violated: false`), with the same "APPEND-ONLY OBSERVATION LOG... never read by
any eligibility check, all-terminal check, circuit breaker, convergence guard, or admission
branch" MUST-NOT carried over verbatim from `defer_ledger`'s own declaration.

**Single-task**: `.orchestrator-loop-guard`'s `detected_defects: []`. Two insertion points inside
Stage 2 ("Loop Guard Initialization" in base, "Loop Guard and Churn State Initialization" in
hard), mirrored in both files:
- Fresh-start `jq -n` construction (base ~lines 133-147; hard has an equivalent, slightly larger
  construction reflecting churn fields) — add `"detected_defects": []` to the initial object.
- Resume-read branch (base ~lines 112-126) — add
  `detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file")` alongside the existing
  `cycle_count`/`infra_failures` reads, defaulting to `[]` for guard files written before this
  field existed (forward-compatible read, matching the `// 0` idiom already used for the other
  two counters).

**Entry shape** (both accumulators, same shape — matches the REQUIRED BEHAVIOUR bullet's three
named fields plus enough context to build the render table and to disambiguate multiple hits
within one run):

```json
{
  "task": 953,
  "defect_class": "OFF_SCHEMA_STATUS",
  "attributed_source_path": "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md",
  "detecting_site": "skill-orchestrate/SKILL.md:stage-5-tier-c",
  "cycle": 2,
  "detail": "handoff dispatch_status 'blah' is off-schema"
}
```

`task` is `null` in single-task-mode ledger entries only if genuinely ambiguous (it never is here
— `$task_number` is always in scope at every one of the four single-task-reachable sites, so this
field should always be populated, unlike `defer_ledger`'s MT-only `task` field which has no
single-task analogue to omit).

### Append-time notice ("never a silent no-op")

Every one of the ten in-file sites already emits a loud, human-legible banner at detection time
(`[OFF-SCHEMA DISPATCH STATUS - ...]`, `[orchestrate] ERROR: STALE HANDOFF — ...`,
`[orchestrate] ERROR: STRAY HANDOFF at ...`, `[orchestrate] EVIDENCE: ...`, and
`skill_gate_completion_claim`'s own `COMPLETION-CLAIM GATE case 3/3 ...` line) — so the
detection itself is never silent today (this matches the discrimination doc's own framing:
these are "Class (a) — loud but unactioned"). What's new is a second, small, uniformly-tagged
line — directly modeled on `[lit:auto]` — confirming the observation was durably queued for the
end-of-run summary, e.g.:

```
[orchestrate] [system-defect:auto] queued for postflight summary — defect_class=OFF_SCHEMA_STATUS attributed_path=agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
```

Emitted immediately after the ledger append (not conditioned on the recorder's own suppression —
see above), at all eleven call sites (site #11 emits it from its caller-side `else` branch, not
from inside `skill_gate_completion_claim`).

### Propagation at postflight

**Multi-task — Stage MT-5 step 5** (`skill-orchestrate/SKILL.md` ~lines 2289-2317): the existing
`jq -n` construction for `.return-meta-multi-${session_id}.json` already threads `defer_ledger`
through as `--argjson defer_ledger "$defer_ledger"` mapped to a `metadata.defer_ledger` key. Add
the identical pattern one line below: `--argjson detected_defects "$detected_defects"` /
`"detected_defects": $detected_defects` inside the same `metadata` object. Step 1's read-list
(line 2205-2206, "Read from `mt_state_file`: ... `defer_ledger`, ...") needs `detected_defects`
added to its enumeration. The task description's explicit constraint — "the top-level `status`
field keeps its existing closed vocabulary... A batch that completed its work successfully but
also observed a defect is still a successful batch" — requires **no change** to the `exit_status`
branching logic in step 3 (lines 2217-2247): `detected_defects` must never be read by that
branching, exactly as `verify_deploy_baseline_notices` already is explicitly excluded from it
("`verify_deploy_baseline_notices` is NEVER consulted by this branch selection", line 2254).

**Single-task — Stage 8** (`skill-orchestrate/SKILL.md` "Postflight", clean-exit block ~lines
1226-1247 and partial-exit block ~lines 1249-1270): both blocks currently do
`echo "$existing_meta" | jq --arg status ... --argjson cycles ... --arg final_state ...
'. * {"status": $status, "metadata": {"cycles_used": $cycles, "final_state": $final_state}}'`.
Read `detected_defects` from `$loop_guard_file` (still present at this point — Stage 8's cleanup
`rm -f "$loop_guard_file"` runs at the very end, after this merge) and add
`--argjson detected_defects "$detected_defects"` / `"detected_defects": $detected_defects` inside
the same `metadata` object, in both the clean-exit and partial-exit variants. `.return-meta.json`
already has a `"status"` field with its own six-value closed vocabulary
(`researched|planned|implemented|partial|failed|blocked`) — this write only ever sets
`"implemented"` or `"partial"` per the existing two branches, so the "no new top-level status
value" constraint is satisfied identically to the MT case with zero additional logic.

**Single-task, hard mode — the asymmetry**: `skill-orchestrate-hard/SKILL.md`'s Stage 8 (titled
"Cleanup", line ~1502) contains **only** `rm -f "$loop_guard_file"` / `rm -f "$churn_file"` — it
has no metadata-merge step of any kind (confirmed: zero occurrences of `cycles_used` or
`final_state` anywhere in the file, and every `.return-meta.json` reference in the file is a
*read*, never a write). This is a genuine structural gap relative to base mode, not something
this task can silently piggyback a field onto. **A new metadata-merge subsection, mirroring
base's Stage 8 verbatim (both clean-exit and partial-exit `jq` merges), must be added to hard
mode's Stage 8 before the `rm -f` cleanup lines**, so `detected_defects` (and, incidentally,
`cycles_used`/`final_state`, which hard mode's single-task path currently never writes at all)
has somewhere to land. Whether to also backfill `cycles_used`/`final_state` for hard mode while
doing this is a planning decision outside this task's stated scope (surfacing defects, not
fixing an unrelated missing-metadata gap) — flagged here so it isn't silently conflated with, or
silently omitted from, the `detected_defects` work.

### Rendering in `commands/orchestrate.md`

**Multi-task**: the existing "Consolidated Output" template (lines 550-666) has an established,
directly reusable slot pattern. `### Pre-Existing Deploy-Verify Failures (Not Deferred)` (line
634) is the closest structural precedent — "Rendered only when [field] is non-empty... Renders
on a SUCCEEDED (`"implemented"`) batch just as readily as a `"partial"` one: the third
operator-visible state is never omitted merely because the batch otherwise completed cleanly."
The same framing applies verbatim to `detected_defects`: a batch that both succeeded and observed
a defect must show the defect table. Insert a new `### System Defects Detected` section
immediately after `### Pre-Existing Deploy-Verify Failures (Not Deferred)` (after line 660) and
before `### Next Steps` (line 662), in the same table style as `### Deferred (other admission
exclusions)` (lines 613-621):

```markdown
### System Defects Detected

(Rendered only when `detected_defects` is non-empty — populated from
`mt_state_file.detected_defects` / `.return-meta-multi.json`'s `metadata.detected_defects`, one
row per entry. Renders on a SUCCEEDED (`"implemented"`) batch just as readily as a `"partial"`
one — an observation, never a failure signal; see `context/patterns/
system-defect-discrimination.md`'s "A schema-conformant failure is always task work" section.)

| Task | Defect Class | Attributed Source Path | Detecting Site | Detail |
|------|--------------|-------------------------|------------------|--------|
| #10 | OFF_SCHEMA_STATUS | agent-system/extensions/core/skills/skill-orchestrate/SKILL.md | skill-orchestrate/SKILL.md:stage-mt4-tier-c | handoff dispatch_status 'blah' is off-schema |
```

**Single-task**: the "## Output" section (lines 782-790) is a terse one-liner block, not a table
— there is no pre-existing multi-row rendering precedent to reuse directly. Per the task's
"Single-task /orchestrate runs need the same treatment as multi-task batches; do not wire only
the batch path" instruction, add an analogous small enumerated block beneath the existing
Completion/Partial/Blocked lines, gated the same way (non-empty `detected_defects` read from
`.return-meta.json`'s `metadata.detected_defects`), using the identical table shape as the MT
section above so the two renderings stay visually consistent — table style is a small,
correctness-neutral choice available to the implementer; the content contract (defect class,
attributed path, detecting site, per the REQUIRED BEHAVIOUR bullet) is what must match.

### The absolute AskUserQuestion constraint

Verified via a full-file search of both skill files, `orchestrate.md`, and `skill-base.sh`: the
only `AskUserQuestion` occurrences are three lines in `skill-orchestrate-hard/SKILL.md`'s Stage 6
("Blocker Escalation", lines 1445 and 1469-1471) — an **unrelated, pre-existing** mechanism for
architectural-decision escalation after repeated blocker cycles, not gated on
`orchestrator_mode` today. This is adjacent prior art worth flagging (it is arguably the same
class of latent bug the literature `AUTONOMOUS_GLOBAL` directive was built to prevent — an
interactive call that cannot fire during `/orchestrate`) but is **out of this task's scope
boundary**: the task is about surfacing system-defect detections, not fixing blocker-escalation
prompting, and no defect-detection call site anywhere touches `AskUserQuestion` at all. The
design recommended above (bash/jq accumulation + markdown-table rendering, exactly mirroring
`defer_ledger`) never introduces an interactive call, so the constraint is met by construction
rather than by an added guard.

## Decisions

- New field name: `detected_defects` (both `mt_state_file` and `.orchestrator-loop-guard`) —
  additive to, never merged with, `defer_ledger`.
- Entry shape: `{"task", "defect_class", "attributed_source_path", "detecting_site", "cycle",
  "detail"}` — a superset of what the REQUIRED BEHAVIOUR bullet names, matching `defer_ledger`'s
  own `{task, defer_reason, collision_scope, cycle, detail}` shape closely enough to read as "the
  same kind of thing," without literally being the same field.
- Site #11 (`META_MISSING_AFTER_NARRATION`) is handled at its three caller sites via the
  `phases_total == 0 && plan_markers_verified != "true"` discriminant, keeping
  `scripts/skill-base.sh` outside the edited file set, consistent with the declared `file_scope`.
- Hard mode's single-task Stage 8 needs a new metadata-merge subsection (not present today),
  mirroring base's Stage 8, as the landing point for `detected_defects` on that path.
- Ledger append is unconditional at detection time — never gated on the recorder's own
  suppression/dedup outcome — mirroring `defer_ledger`'s existing unconditional-append
  discipline.
- MT rendering slot: new `### System Defects Detected` section, positioned after `### Pre-Existing
  Deploy-Verify Failures (Not Deferred)` and before `### Next Steps`, following the same
  "renders on success and partial alike" rule already established for that neighboring section.

## Risks & Mitigations

- **Risk**: adding a 6th argument to `skill_gate_completion_claim` would have been simpler than
  the caller-side re-derivation, but crosses the declared `file_scope`. **Mitigation**: the
  `phases_total`/`plan_markers_verified` discriminant documented above avoids the edit entirely;
  flagged as an option for planning if a future pass decides to widen scope instead.
- **Risk**: forgetting hard mode's missing Stage 8 metadata-merge step would silently drop
  `detected_defects` (and leave `cycles_used`/`final_state` still unwritten) on the hard-mode
  single-task path only, reproducing the exact "fix landing in only one [file]" failure class the
  task description explicitly warns about. **Mitigation**: named explicitly above as a required,
  net-new subsection, not an existing-field addition.
- **Risk**: conditioning the MT `### System Defects Detected` render on `exit_status` (e.g. only
  showing it on `"partial"`) would violate the task's explicit "a batch that completed
  successfully but also observed a defect is still a successful batch" instruction.
  **Mitigation**: the render must be gated solely on `detected_defects` non-emptiness, exactly
  like `### Pre-Existing Deploy-Verify Failures (Not Deferred)`'s established precedent — call
  sites documented above.

## Context Extension Recommendations

None required for this task's own scope. The system-defect discrimination document
(`context/patterns/system-defect-discrimination.md`) already documents the predicate, the
detection-point registry, and the recursion/dedup rules exhaustively; this report only adds the
run-scoped-surfacing layer on top, which belongs in the two edited skill files and the command
doc, not in a new context file.

## Appendix

- Detection-site line numbers above are from the current on-disk source-store files at the time
  of this report; per this codebase's own stated discipline (see the discrimination document's
  "dead-signal finding" section), re-verify line numbers before citing them in an implementation
  plan rather than trusting this report's numbers as permanent anchors.
- Searches performed: full-file reads of `system-defect-record.sh`,
  `system-defect-discrimination.md`, both `SKILL.md` files (targeted region reads covering Stage
  1-8/MT-1-5 for base, Stage 1-8 for hard), `commands/orchestrate.md`'s Consolidated Output
  template and single-task Output section, and `scripts/skill-base.sh`'s
  `skill_gate_completion_claim` (read-only, per file_scope).
- Environment note (non-substantive): the sandboxed `grep` shell function in this session
  intermittently failed with an unrelated "claude native binary not installed" error; `command
  grep` bypassed it. Not a finding about the codebase, recorded only in case a future pass in the
  same session hits the same tool flakiness.
