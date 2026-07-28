# Research Report: Fix off-schema .return-meta.json writes breaking orchestrator recovery

**Task**: 939 - Fix off-schema .return-meta.json writes breaking orchestrator recovery
**Started**: 2026-07-28
**Completed**: 2026-07-28
**Effort**: research phase only
**Dependencies**: None
**Sources/Inputs**: Codebase reads of the six declared file-scope files plus
`skill-implementer/SKILL.md`, `skill-implementer-hard/SKILL.md`,
`docs/architecture/handoff-schema.md`, `scripts/skill-base.sh`; empirical scratch-file
verification runs of `orchestrate-recover-outcome.sh`.
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both defects are reproduced empirically (item E) with scratch `.return-meta.json` files run
  through the real `orchestrate-recover-outcome.sh`. Defect 1's "silent" claim needs one
  correction: the script *does* exit 0 with `recovered:true`, but the phase counts are silently
  wrong (0/0 for genuinely-complete work) — see Findings for the exact reproduction.
- **New finding not stated in the task description**: the existing phase-marker-grep diagnostic
  (the one item D asks about) structurally **cannot fire** in Defect 1's own failure mode. It
  lives only in the `recovered=false` branch of `skill-orchestrate/SKILL.md` Stage 5; Defect 1
  produces `recovered=true` (status is a legitimate success value), so the branch that contains
  the diagnostic is never reached. This is the single most actionable fact for item D: the fix
  is not "add a new diagnostic," it is "widen the trigger condition of the existing one."
- **Root-cause insight for item A**: `.orchestrator-handoff.json` legitimately keeps
  `phases_completed`/`phases_total` at the **top level**, always (confirmed against
  `docs/architecture/handoff-schema.md`). `general-implementation-hard-agent.md` shows that exact
  top-level handoff JSON shape a few dozen lines *before* its `.return-meta.json` Stage 7
  instruction. Same field names, different file, different (correct) nesting rule — this is very
  likely why the Stage 7 wording drifted into describing a top-level shape for the wrong file.
- **`skill-team-implement/SKILL.md`'s current example is already schema-compliant** (nested under
  `.metadata`), contrary to what the task description states about it — flagged as a
  discrepancy to resolve explicitly, not silently followed. See Findings.
- **New defect adjacent to item A's scope**: `skill-implementer-hard/SKILL.md` Stage 6 reads
  `.phases_completed`/`.phases_total` at the **top level** (not `.metadata.*`), while its sibling
  `skill-implementer/SKILL.md` Stage 6 reads them correctly nested. This reader is currently
  "consistent" with `general-implementation-hard-agent.md`'s ambiguous writer instruction only by
  accident (both top-level) — fixing the writer per item A without also fixing this reader would
  **newly break** the non-orchestrator `/implement --hard` path's own phase-gate logic (a
  regression this task must not introduce). Neither `skill-implementer/SKILL.md` nor
  `skill-implementer-hard/SKILL.md` is in the declared `file_scope`, but the task description
  explicitly directs checking both — flagging this scope gap for the plan/orchestrator to
  resolve (expand file_scope or explicitly accept the gap).
- Defect 2 reproduces with a literal `jq: error (at <stdin>:1): Cannot index string with string
  "path"` on stderr (three such lines, one per field) — the failure is not perfectly silent at
  the shell level, it is silent *to the orchestrator's own logic*, which never inspects stderr
  and proceeds as if recovery fully succeeded.
- `general-research-agent.md` confirmed to contain **zero** mention of the `artifacts` array
  shape anywhere (only one unrelated prose use of the word "artifacts"), corroborating item B's
  premise exactly.

## Context & Scope

Task 939 (`meta` type) asks for writer-side fixes so `.return-meta.json` files conform to the
schema `context/formats/return-metadata-file.md` declares and `scripts/orchestrate-recover-outcome.sh`
assumes. Two independently observed off-schema shapes are in scope: top-level phase-count
fields (Defect 1) and a bare-string `artifacts` array (Defect 2). The format doc and the recovery
script are believed correct and are only in scope for defensive hardening (item C) and detection
(item D), not redefinition. All edits target `agent-system/extensions/core/**`; `.claude/**` is a
disposable deploy artifact per the source-store rule.

This report only investigates and verifies; no source files were edited.

## Findings

### A. Phase-field nesting — confirmed in all three named writers, with new nuances

**`agents/general-implementation-agent.md`**, Stage 7 ("Write Metadata File"): the sentence
explicitly states `memory_candidates` and `modified_files` go "at the top level of the JSON
output," then ends with "Agent-specific metadata fields: `phases_completed`, `phases_total`" —
no location stated. The file's only worked JSON example at Stage 7 is the `partial` case, which
correctly nests `phases_completed`/`phases_total` under `partial_progress` — but there is **no
worked example anywhere in the file for the `implemented` success case**, so an implementer has
nothing to pattern-match against for the ambiguous sentence.

**`agents/general-implementation-hard-agent.md`**: doubly confirms the ambiguity, from a
different angle. Stage 5 (H9 wrap-up, writing `.orchestrator-handoff.json`) shows a correct,
literal top-level example: `{"status": ..., "phases_completed": N, "phases_total": M, ...}` —
correct for *that* file, since the handoff schema is genuinely top-level always (verified against
`docs/architecture/handoff-schema.md` line ~163: "`phases_completed` and `phases_total` are
TOP-LEVEL fields, always — never members of [a nested object]"). A few dozen lines later, Stage 7
("Write Metadata File," for `.return-meta.json`) says: "Include `phases_completed`,
`phases_total`, `modified_files` (from Stage 6-modified-files, ...)." Grouping `phases_completed`/
`phases_total` in the same clause as `modified_files` — which genuinely IS top-level in
`.return-meta.json` — reads as "these are all top-level too." This is the likely mechanism of the
drift: the correct top-level handoff example primes the wrong shape for the very next file's
instruction.

**`skills/skill-team-implement/SKILL.md`**: the task description states this file was "confirmed
to show or describe a top-level shape." Direct inspection of its Stage 13 JSON example (the only
`phases_completed`/`phases_total` occurrence in the file) shows the opposite — it is already
correctly nested:
```json
"metadata": {
  "session_id": "{session_id}",
  "agent_type": "skill-team-implement",
  "phases_completed": {N},
  "phases_total": {N}
}
```
This is a genuine discrepancy between the task description and the current file content. It does
not mean item A has nothing to do here — the surrounding prose still lacks the explicit "these
nest under `.metadata`" callout the other two files also lack, so it should get the same
disambiguating treatment for consistency and to guard against future drift — but the plan should
not assume this file's example needs correcting from wrong to right; it needs the same
explanatory reinforcement the other two need, applied to an already-correct example.

**`skills/skill-implementer/SKILL.md`** (checked per task description item A, not in declared
file_scope): does not itself instruct the dispatched agent how to write the field (that's
delegated to `general-implementation-agent.md`). Its own Stage 6 postflight read is already
correct: `jq -r '.metadata.phases_completed // 0'`.

**`skills/skill-implementer-hard/SKILL.md`** (checked per task description item A, not in
declared file_scope): Stage 6 postflight read is `jq -r '.phases_completed // 0'` —
**top level**, diverging from its non-hard sibling and from the normative schema. This is
currently self-consistent with `general-implementation-hard-agent.md`'s (ambiguous/top-level)
writer instruction only by coincidence. **If item A fixes the hard-mode agent's writer to nest
under `.metadata` without also fixing this reader, the non-orchestrator `/implement --hard` path
breaks anew** (it would start reading 0/0 from a now-correctly-nested file). This coupling must
be part of the same phase/commit as the hard-mode agent fix, not deferred.

### B. Artifacts array shape — general-research-agent.md has zero local instruction

`grep -n "artifacts\b" agents/general-research-agent.md` returns exactly one line, and it is
unrelated prose ("Reference existing artifacts in the new report..."). Stage 7 ("Write Metadata
File") reads: "Write to `specs/{NNN}_{SLUG}/.return-meta.json` with status `researched`.
Agent-specific metadata fields: `findings_count`. Include `memory_candidates` array (from Stage
5) at the top level of the JSON output. Set `next_steps`..." — `artifacts` (a **required** field
per the schema) is not mentioned at all. The only place the object-array-with-`type`/`path`/
`summary` shape is stated is `context/formats/return-metadata-file.md`, and the task's own Defect
2 is direct proof that a reference-only instruction is insufficient in practice. This confirms
the task description's premise exactly and leaves the choice open (per the task's own item B
wording) between: (a) adding an explicit local instruction to `general-research-agent.md`'s Stage
7, or (b) making the format-doc reference more prominent/explicit at that call site. Given
Defect 2 already falsified "the reference alone is sufficient," (a) is the safer choice — a
local, inline minimal example costs a few lines and removes the dependency on the agent actually
following the reference under context pressure.

### C. Whether to defensively accept off-schema shapes in the reader

Layout of the tradeoff, to make the call explicit rather than by default:

- **For a fallback**: `orchestrate-recover-outcome.sh` already treats absence gracefully (`// 0`,
  `// ""`) everywhere; adding an explicit top-level-`phases_completed` fallback (e.g.
  `.metadata.phases_completed // .partial_progress.phases_completed // .phases_completed // 0`)
  is a small, mechanically consistent change, and it would make Defect 1's specific shape
  non-fatal even if a writer regresses again.
- **Against**: the task's own framing is correct that this "silently blesses an off-schema
  write." Concretely, it would also mask the `skill-implementer-hard/SKILL.md` coupling problem
  identified in Finding A — a bare fallback that quietly accepts top-level phases removes any
  signal that the hard-mode base path and the orchestrator path have drifted to different
  (incompatible) nesting assumptions.
- **Recommendation**: do not add a silent-accepting fallback. Prioritize the writer fixes (item
  A/B) plus the escalated detection in item D below, which is evidence-based (corroborates
  against the plan file) rather than schema-permissive. If a fallback is still wanted as
  belt-and-suspenders, the task's own requirement stands: it MUST log loudly that it fired (e.g.
  a `nesting_fallback_used: true` field in the emitted JSON, or a stderr line), so drift stays
  visible to whoever reads the orchestrator's log. This is a decision for the plan to ratify
  explicitly, not default silently either way.

### D. Detection mechanism — the existing diagnostic's blind spot, verified

`skill-orchestrate/SKILL.md`'s "Phase-marker recovery grep" (~line 682) is explicitly scoped by
its own precondition comment: "reachable ONLY inside this missing/stale-handoff, **non-recovered**
branch. Never runs... when return-meta recovery already succeeded above." Defect 1's scratch
reproduction (below) shows `recovered=true` (status `implemented` is a legitimate success value —
the phase-count corruption doesn't change that), so **this diagnostic never runs for Defect 1's
own scenario, only for a strictly worse one (both handoff missing AND status not recoverable)**.
This means the existing diagnostic, as scoped today, would not have caught the near-miss the task
describes even after item D's stated concept ("a plan file on disk shows N completed phase
headings" cross-check) is already partially implemented — it's gated to the wrong branch.

Two independent, complementary detection additions, both consistent with the "reader got an
empty or zero value from a present, parseable file" general signature the task asks for:

1. **In `orchestrate-recover-outcome.sh` itself** (stays within its Context-Flatness Constraint —
   reads only the one file it already has): add a self-consistency check on the *same* parsed
   JSON, independent of any plan-file cross-reference. Two candidate signatures, generalized as
   one check each in the same family:
   - `status == "implemented"` and `phases_completed == 0` and `phases_total == 0` (0/0 is
     inherently suspicious for a claimed-complete implementation, since an implementation dispatch
     always has at least one phase).
   - `(artifacts | length) > 0` and `artifact_path == ""` (a non-empty `artifacts` array that
     nonetheless resolves to an empty path is direct proof of a shape mismatch, not "no
     artifacts").
   Emit an additional field (e.g. `evidence_suspect: true/false` plus a `reason` token) in the
   script's existing single-line JSON output. This adds no new file reads and is cheap.
2. **In `skill-orchestrate/SKILL.md` Stage 5 (and its hard-mode/multi-task mirrors)**: widen the
   phase-marker grep's trigger condition to also fire when `recovered=true`, `dispatch_status ==
   "implemented"`, and `phases_total == 0` — not only in the `recovered=false` branch. This is
   the one-line-scoped structural fix that closes the actual gap Defect 1 exposed. Escalation
   question (task's own prompt): the codebase already has a stagnation-signal precedent
   (`invoke_drift_inspection`, called today when `phases_total > 0` and completion ratio is below
   `DRIFT_COMPLETION_THRESHOLD`) that logs and inspects rather than silently continuing. Extending
   that same call to also fire on a "0/0 recovered `implemented`" contradiction (a degenerate case
   the ratio arithmetic can't currently express, since dividing by `phases_total == 0` is
   undefined) is the natural escalation path rather than inventing a third mechanism.

Both defects share exactly the signature the task names; recommend implementing detection #1 as
the single general check (covers both defects with one code shape, per the task's own
preference), and detection #2 as the targeted structural fix for the specific gap this research
proved exists.

### E. Verification by construction — reproduced, with exact observed output

Three scratch `.return-meta.json` files were constructed in a scratch directory outside the repo
and run through the real, unmodified `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`
with a `window_start_ts` one hour in the past (so freshness passes).

**Control (correctly nested, for baseline)**:
```json
{"status":"implemented","phases_completed":6,"phases_total":6,
 "metadata":{...,"phases_completed":6,"phases_total":6}}
```
Result: `{"recovered":true,"status":"implemented",...,"phases_completed":6,"phases_total":6,...}`,
exit 0. Confirms the script itself is correct against the documented schema (in scope only for
"defensive hardening," per the task, and this baseline shows no bug in the reader for the correct
shape).

**Defect 1 reproduction** (top-level `phases_completed`/`phases_total`, no `.metadata` copy, no
handoff file present):
```json
{"status":"implemented", ..., "phases_completed":6, "phases_total":6,
 "metadata":{"session_id":"sess_scratch_defect1", ...}}
```
Result:
```json
{"recovered":true,"status":"implemented","reason":"NONE",
 "artifact_path":"specs/999_scratch/summaries/01_scratch-summary.md",
 "artifact_type":"summary","artifact_summary":"Scratch implementation summary",
 "phases_completed":0,"phases_total":0, ...,
 "completion_summary":"Scratch task fully implemented across 6 phases.","roadmap_items":[]}
```
Exit code 0. This is the exact mechanism described in the task: the file is fully recoverable
(status is trusted), but phase accounting silently reads as 0/0 despite the file literally
containing `"phases_completed": 6, "phases_total": 6` two keys up. Feeding these values into
`skill_gate_completion_claim` (verified by reading `scripts/skill-base.sh`) with
`plan_markers_verified="absent"` (always set on this recovery path, per
`skill-orchestrate/SKILL.md` line ~627) lands in Case 3 with the corroborating signal absent —
"refusing completion; task stays implementing" — reproducing the near-stranding described.

**Defect 2 reproduction** (`artifacts` as an array of bare strings):
```json
{"status":"researched","artifacts":["specs/999_scratch/reports/01_scratch-research.md"], ...}
```
Result (stderr, three lines, one per field extraction):
```
jq: error (at <stdin>:1): Cannot index string with string "path"
jq: error (at <stdin>:1): Cannot index string with string "type"
jq: error (at <stdin>:1): Cannot index string with string "summary"
```
stdout:
```json
{"recovered":true,"status":"researched","reason":"NONE",
 "artifact_path":"","artifact_type":"","artifact_summary":"", ...}
```
Exit code 0. Correction to the task description's framing: this is not perfectly silent at the
shell level — three real `jq` parse errors are emitted to stderr (the script's `artifact_path=...`
line lacks the `2>/dev/null` most other jq calls in the script use). But the orchestrator's own
consuming logic (`skill-orchestrate/SKILL.md` line ~878: `if [ -n "$handoff_artifact_path" ] &&
...`) never inspects that stderr stream, sees only the empty string, and the `if` is simply
false — `skill_link_artifacts` is never called, no error is logged by the orchestrator itself, and
the dispatch is reported as a success. This matches "linked nothing... reported success" exactly,
with the refinement that the jq errors are a free, currently-unused corroborating signal the
detection work in item D could capture (e.g. redirect and check for non-zero jq exit rather than
relying only on the empty-string result) rather than swallowing to `/dev/null` outright.

Scratch files used for this verification were written under this session's scratchpad directory
(not under the repository) and are not part of any deliverable.

## Decisions

- Recommend NOT adding a silent-accepting top-level-phases fallback to
  `orchestrate-recover-outcome.sh` (item C) — see Finding C's full reasoning. If the plan
  disagrees, the loud-logging requirement from the task description is non-negotiable either way.
- Recommend the item-D detection work be split into the two concrete, independently-shippable
  pieces in Finding D — a same-file self-consistency check inside
  `orchestrate-recover-outcome.sh`, and a scope-widening one-line fix to
  `skill-orchestrate/SKILL.md`'s (and its hard-mode/multi-task mirrors') existing phase-marker
  grep trigger condition — rather than one combined mechanism, since they live in genuinely
  different files with different read-scope constraints (Context Flatness Constraint blocks the
  plan-file cross-check from living inside the recovery script itself).
- Recommend the plan explicitly address the `skill-implementer-hard/SKILL.md` top-level-read
  coupling found in Finding A as part of the same phase that fixes
  `general-implementation-hard-agent.md`'s writer instruction — not as a separately-scheduled
  follow-up — since fixing one without the other creates a fresh regression on the
  non-orchestrator `/implement --hard` path. This likely requires the plan to note a `file_scope`
  gap (neither `skill-implementer/SKILL.md` nor `skill-implementer-hard/SKILL.md` is in task
  939's declared `file_scope`, despite the task description directing both be checked).
- `skill-team-implement/SKILL.md`'s existing JSON example does not need shape correction (it is
  already nested correctly) — only the same explicit disambiguating prose the other two writers
  need, for consistency and to guard against regression.

## Risks & Mitigations

- **Risk**: fixing `general-implementation-hard-agent.md`'s Stage 7 writer instruction in
  isolation, without touching `skill-implementer-hard/SKILL.md`'s Stage 6 reader. **Mitigation**:
  schedule both edits in the same plan phase/commit; add a one-line regression check (grep for
  `.phases_completed` without a `.metadata.` prefix in that skill file) if the plan wants a
  cheap guard.
- **Risk**: a defensive fallback (item C), if added despite the recommendation above, could be
  implemented without the required loud logging, reintroducing a silent failure mode of a
  different shape. **Mitigation**: if the plan chooses to add one anyway, require the logged-field
  approach demonstrated feasible above (`nesting_fallback_used` or equivalent) as an explicit
  acceptance criterion.
- **Risk**: widening the phase-marker grep's trigger condition (item D) to include the
  `recovered=true` branch changes behavior on every task whose implementation genuinely completed
  with 0 phases (a possible but unusual case, e.g. a task whose plan has no `### Phase N:`
  headings at all). **Mitigation**: gate the widened check on `phases_total == 0` specifically
  (not `phases_completed == 0` alone), and treat a plan file with zero phase headings found by the
  grep itself (`recovered_total == 0`) as "no contradiction, nothing to escalate" rather than a
  second false-positive trigger.

## Context Extension Recommendations

- **Topic**: cross-file field-name collisions with different nesting rules.
- **Gap**: `return-metadata-file.md` already has a "Three distinct vocabularies sharing the same
  words" callout for `status`/`completed`, but no equivalent callout for
  `phases_completed`/`phases_total` colliding across `.return-meta.json` (nested) and
  `.orchestrator-handoff.json` (top-level) — the exact collision this task's root cause traces to.
- **Recommendation**: add a short callout box to `return-metadata-file.md`'s
  `phases_completed`/`phases_total` field spec, mirroring the existing "Three distinct
  vocabularies" table style, explicitly contrasting the two files' nesting rules side by side.
  This is a natural piece of item A's fix (the format doc is in file_scope) even though the format
  doc itself is "believed correct" and not being redefined — this is additive documentation
  hardening, not a schema change.

## Appendix

### Search queries / commands used

- `jq -r '.active_projects[] | select(.project_number == 939) | .description' specs/state.json`
- `grep -n "phases_completed\|phases_total\|top level\|top-level\|memory_candidates\|modified_files" agents/general-implementation-agent.md`
- `grep -n "phases_completed\|phases_total\|top level\|top-level\|metadata fields\|return-meta" agents/general-implementation-hard-agent.md skills/skill-team-implement/SKILL.md skills/skill-implementer/SKILL.md skills/skill-implementer-hard/SKILL.md`
- `grep -n "artifacts\b" agents/general-research-agent.md`
- `grep -n "phases_completed\|phases_total" docs/architecture/handoff-schema.md`
- `grep -n "skill_gate_completion_claim" -A 60 scripts/skill-base.sh`
- Empirical: three scratch `.return-meta.json` files run through
  `scripts/orchestrate-recover-outcome.sh` with a one-hour-past `window_start_ts` (control,
  Defect 1 shape, Defect 2 shape) — full stdout/stderr captured in Finding E above.

### Files read in full or substantial part

- `agent-system/extensions/core/context/formats/return-metadata-file.md`
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 5, Stage MT-4 regions)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (Stage 7 region)
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (Stage 5, Stage 7 regions)
- `agent-system/extensions/core/skills/skill-team-implement/SKILL.md` (Stage 13 region)
- `agent-system/extensions/core/agents/general-research-agent.md` (Stage 7 region, full artifacts grep)
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` (Stage 6 region)
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` (Stage 6 region)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (phases_completed/total section)
- `agent-system/extensions/core/scripts/skill-base.sh` (`skill_gate_completion_claim`)
