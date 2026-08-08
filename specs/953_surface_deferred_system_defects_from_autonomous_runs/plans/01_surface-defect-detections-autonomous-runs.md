# Implementation Plan: Task #953

- **Task**: 953 - Surface deferred system-defect detections from autonomous runs
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: prerequisite recorder task (`system-defect-record.sh` + wired detection sites) — already merged
- **Research Inputs**: specs/953_surface_deferred_system_defects_from_autonomous_runs/reports/01_surface-deferred-system-defects.md
- **Artifacts**: plans/01_surface-defect-detections-autonomous-runs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a run-scoped, append-only `detected_defects` observation log to both `/orchestrate` engines,
mirroring the existing `defer_ledger` shape exactly, so that system-defect detections fired during
an autonomous run are (a) announced immediately with a visibly-tagged `[system-defect:auto]`
notice, (b) accumulated on the run's own runtime state file, (c) propagated into the postflight
metadata object alongside `defer_ledger`, and (d) rendered as an enumerated table in the
consolidated summary. The mechanism is pure bash/jq and markdown — it never calls
`AskUserQuestion`, so the "absolute" constraint is satisfied by construction rather than by an
added guard. Work spans exactly the three declared `file_scope` files; `scripts/skill-base.sh`
stays untouched via a caller-side discriminant for the one detection that lives inside it.

### Research Integration

The research report is the spine of this plan and every phase below cites it. Key findings carried
forward verbatim:

- **Eleven live detection call sites**, not one: four in base single-task Stage 5, two in base
  Stage MT-4, four in hard single-task Stage 5, and one shared site inside
  `skill_gate_completion_claim` reachable from three of the others.
- **Two accumulator homes**: `mt_state_file.detected_defects` for batches;
  `.orchestrator-loop-guard`'s `detected_defects` for single-task runs (the only per-invocation
  runtime state file a single-task run has).
- **Base and hard share the MT stages.** Hard mode has no MT implementation of its own, so wiring
  Stage MT-4/MT-5 once in `skill-orchestrate/SKILL.md` covers `/orchestrate --hard` batches too.
  Only the *single-task* paths are genuinely duplicated and need mirrored edits.
- **`scripts/skill-base.sh` scope tension is resolvable without touching it**: every caller of
  `skill_gate_completion_claim` already has `$phases_total` and `$plan_markers_verified` in scope,
  which is exactly the Case-3/3 discriminant (`phases_total -eq 0` AND
  `plan_markers_verified != "true"`).
- **Structural asymmetry**: hard mode's single-task Stage 8 is titled "Cleanup" and contains only
  `rm -f "$loop_guard_file"` / `rm -f "$churn_file"`. It has **no** `.return-meta.json`
  metadata-merge step at all. A net-new merge subsection must be added there, not a field appended
  to an existing merge.
- **Rendering precedent**: `### Pre-Existing Deploy-Verify Failures (Not Deferred)` is the exact
  structural template — gated solely on its own field's non-emptiness, rendered on a SUCCEEDED
  batch just as readily as a `"partial"` one.

Live re-verification performed during planning (the report's own Appendix asks for this rather
than trusting its line numbers): all eleven sites, both Stage 2 loop-guard blocks, both Stage 8
blocks, Stage MT-1's declaration block, Stage MT-5 steps 1/3/5, and both rendering slots were
re-read on disk. One correction to the report's framing was found and is reflected below: base
mode's `skill_gate_completion_claim` call has **no existing `else` branch** (it closes at `fi` with
an "On refuse" comment), whereas hard mode's **already has one** — so Phase 2 adds a branch and
Phase 3 extends an existing one.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and `roadmap_flag` was not set, so
`specs/ROADMAP.md` was not consulted and no roadmap phases are included. This plan neither reads
nor writes ROADMAP.md.

## Goals & Non-Goals

**Goals**:
- Every system-defect detection that fires during an autonomous run is visible twice: immediately,
  via a uniformly-tagged transcript notice, and at the end, via an enumerated summary table.
- The accumulator is a genuinely new, separately-declared field — additive to `defer_ledger`,
  never overloaded onto it, never merged with `verify_deploy_baseline_notices`.
- Single-task runs receive identical treatment to multi-task batches, in both base and hard mode.
- The top-level `status` vocabulary of both `.return-meta.json` and `.return-meta-multi.json` is
  unchanged. A batch that succeeded and also observed a defect is still a successful batch.
- Every edit lands in `agent-system/extensions/**`. Nothing is hand-authored under `.claude/**`.

**Non-Goals**:
- No task creation and no interactive prompt of any kind. The interactive lane is a separate,
  parallel downstream task and this plan overlaps it on no file.
- No change to `scripts/system-defect-record.sh`, `scripts/skill-base.sh`, or
  `context/patterns/system-defect-discrimination.md`.
- No change to any admission gate, eligibility check, all-terminal check, circuit breaker,
  convergence guard, or `exit_status` branching. The new field is read by reporting only.
- Not fixing the pre-existing, unrelated `AskUserQuestion` in hard mode's Stage 6 blocker
  escalation. The research report flags it as adjacent prior art; it is explicitly out of scope.
- Not backfilling `cycles_used`/`final_state` for hard mode as a feature in its own right — Phase 5
  writes them only because the net-new merge block it must add would be malformed without them,
  and it says so in place.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Fix lands in base only, not hard — the codebase's named recurring defect class | H | M | Phases 2/3 and 5/6 are deliberately split base-vs-hard so neither can be silently skipped; Phase 8 is a dedicated parity audit that greps both files for every new token and fails on asymmetry |
| Hard mode's missing Stage 8 metadata merge is overlooked, silently dropping `detected_defects` on the hard single-task path only | H | M | Phase 5 exists solely for this and is a net-new subsection, not a field addition; Phase 8 asserts a `cycles_used` occurrence in the hard file, which is currently zero |
| Rendering gated on `exit_status` (e.g. only on `"partial"`), hiding defects on a successful batch | H | L | Phase 7 copies the `### Pre-Existing Deploy-Verify Failures (Not Deferred)` gating language verbatim ("renders on a SUCCEEDED batch just as readily"); Phase 8 greps the new section for any `exit_status` reference and fails if one appears |
| `detected_defects` accidentally read by an admission/eligibility branch, becoming a gate | H | L | Phase 1 carries `defer_ledger`'s MUST-NOT verbatim into the new declaration; Phase 8 greps every `detected_defects` read site and confirms each is a reporting site |
| Append conditioned on the recorder's dedup/suppression outcome, hiding a repeat detection | M | M | Phase 1 states the append is unconditional; Phases 2/3/4 place the append and notice *outside* any `record_result` test; Phase 8 checks no append sits inside a `record_result` conditional |
| Editing base SKILL.md from two phases concurrently causes conflicting edits | M | M | Wave map serializes same-file phases: Phase 4 depends on Phase 2, Phase 6 depends on Phase 4; only cross-file phases share a wave |
| Line numbers drift between planning and implementation | L | H | Every phase names an anchor *string* (a comment, a variable, a heading) rather than a line number; Scope Hypothesis lines require the implementer to confirm counts on disk |
| An edit lands under `.claude/**` instead of the source store | H | L | Every phase's "Files to modify" list is source-store-absolute; Phase 8 asserts `git status` shows no `.claude/**` modification |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4, 5 | 2 (for 4), 3 (for 5) |
| 4 | 6 | 4 |
| 5 | 7 | 5, 6 |
| 6 | 8 | 7 |

Phases within the same wave can execute in parallel. Wave 2 and Wave 3 each pair one base-file
phase with one hard-file phase, so the two members of a wave never touch the same file.

---

### Phase 1: Declare the `detected_defects` accumulator and its shared contract [COMPLETED]

**Goal**: Establish the new field in both accumulator homes and write, once, the canonical
contract (entry shape, append discipline, notice format, MUST-NOTs) that Phases 2-6 refer back to
instead of restating.

**Tasks**:
- [x] In `skill-orchestrate/SKILL.md` Stage MT-1, immediately after the `defer_ledger: []`
      declaration bullet and before `forward_progress_violated: false`, add a
      `detected_defects: []` bullet. Carry `defer_ledger`'s MUST-NOT **verbatim**: "never read by
      any eligibility check, all-terminal check, circuit breaker, convergence guard, or admission
      branch... written for reporting and read only at Stage MT-5 and by `commands/orchestrate.md`."
      State explicitly that it is ADDITIVE to `defer_ledger` and is never merged into it, because
      `defer_ledger`'s `defer_reason` vocabulary is load-bearing for admission reporting; and that
      it is likewise never merged into `verify_deploy_baseline_notices`, a different observation
      log for a different concern.
- [x] In the same declaration, fix the entry shape as
      `{"task": <int>, "defect_class": <string>, "attributed_source_path": <string>,
      "detecting_site": <string>, "cycle": <int>, "detail": <string>,
      "record_result": <string|null>}`. Note that `task` is ALWAYS populated (unlike
      `defer_ledger`'s MT-only `task`), because `$task_number`/`$task_num` is in scope at every one
      of the eleven sites.
- [x] In the same declaration, state the **unconditional-append rule**: the append fires whenever
      the caller's own detection fires, and is NEVER gated on `system-defect-record.sh`'s exit code
      or on a `SUPPRESSED:recursion_guard` / `SUPPRESSED:duplicate` stdout value. `record_result`
      records that outcome for the operator; it never decides whether the entry exists. Rationale:
      the recorder's dedup key is cross-run, and the goal here is "surface what fired this run."
      This mirrors `defer_ledger`'s existing unconditional-append discipline.
- [x] In the same declaration, fix the **notice format**, modelled on the literature
      `AUTONOMOUS_GLOBAL` directive's `[lit:auto]`:
      `[orchestrate] [system-defect:auto] queued for postflight summary — defect_class=<CLASS> attributed_path=<PATH> detecting_site=<SITE>`
      (`[hard-orchestrate]` prefix in the hard file). State that it is emitted immediately after
      the append, at every site, and that its purpose is the same "never a silent no-op" principle
      the literature directive states.
- [x] In the same declaration, state the **absolute constraint**: no site in this mechanism may
      call `AskUserQuestion`. When `orchestrator_mode` is true there is no human to prompt; the
      accumulate-then-render design is the deterministic default, exactly as `AUTONOMOUS_GLOBAL`
      prescribes.
- [x] In `skill-orchestrate/SKILL.md` Stage 2, add `"detected_defects": []` to the fresh-start
      `jq -n` loop-guard object (the one ending `}' | bash .claude/scripts/task-lock.sh
      init-marker "$loop_guard_file"`), and add
      `detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file")` to BOTH read paths:
      the top-level resume branch (alongside `cycle_count`/`infra_failures`) and the lost-init-race
      `else` branch (which the file's own comment insists must read all counters, not just
      `cycle_count`). The `// []` default is the forward-compatible read for guard files written
      before this field existed, matching the `// 0` idiom already used there.
- [x] Mirror the same three Stage 2 insertions in `skill-orchestrate-hard/SKILL.md`'s "Loop Guard
      and Churn State Initialization". Its fresh-init object is larger (it carries
      `burnout_signals_this_session`) and its resume branch reads three counters — add the field
      and the read to each without disturbing the surrounding churn-state handling, and do not
      touch `$churn_file`.
- [x] In the hard file, add a one-line pointer at its Stage 2 insertion stating that the entry
      shape, unconditional-append rule, notice format, and MUST-NOTs are defined once in
      `skill-orchestrate/SKILL.md`'s Stage MT-1 `detected_defects` declaration and are not restated
      here, so the two cannot drift.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts **7 insertion points** — 1 declaration + 3 Stage 2 points
in the base file, 3 Stage 2 points + 1 pointer in the hard file. Confirm at implementation time by
grepping each file for `loop_guard_file` and counting the distinct fresh-init / resume-read /
lost-race-read blocks before editing; if either file has more or fewer read paths than three, wire
every one found rather than exactly three.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-1 declaration; Stage 2 loop-guard fresh-init + two read paths
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - Stage 2 loop-guard fresh-init + read paths; contract pointer

**Verification**:
- `jq -n` blocks in both files still parse as valid jq programs when extracted and run against
  `/dev/null` (or by eye, if extraction is impractical).
- Grep both files for `detected_defects`: base has the declaration plus 3 Stage 2 hits; hard has 3
  Stage 2 hits plus the pointer.
- The new declaration bullet contains the words "never read by any eligibility check" and
  "ADDITIVE".
- `defer_ledger`'s own declaration text is byte-for-byte unchanged.

---

### Phase 2: Wire the four base single-task Stage 5 detection sites [COMPLETED]

**Goal**: Every detection reachable from `skill-orchestrate/SKILL.md`'s single-task Stage 5
appends to the loop guard's `detected_defects` and emits the `[system-defect:auto]` notice.

**Tasks**:
- [x] Define, once near the top of Stage 5 in this file, the append idiom to reuse at each site —
      matching the file's own existing loop-guard mutation idiom
      (`jq ... "$loop_guard_file" > "${loop_guard_file}.tmp" && mv ...`):
      ```bash
      append_detected_defect() {  # class, attributed_path, site, detail, record_result
        jq --argjson entry "$(jq -c -n \
              --argjson task "$task_number" --arg class "$1" --arg path "$2" \
              --arg site "$3" --argjson cycle "${cycle_count:-0}" --arg detail "$4" \
              --arg rr "${5:-}" \
              '{task:$task, defect_class:$class, attributed_source_path:$path,
                detecting_site:$site, cycle:$cycle, detail:$detail,
                record_result: (if $rr == "" then null else $rr end)}')" \
            '.detected_defects += [$entry]' \
            "$loop_guard_file" > "${loop_guard_file}.tmp" \
          && mv "${loop_guard_file}.tmp" "$loop_guard_file"
        echo "[orchestrate] [system-defect:auto] queued for postflight summary — defect_class=$1 attributed_path=$2 detecting_site=$3" >&2
      }
      ```
      The helper emits the notice itself so no site can append without announcing.
- [x] Site 1 — stale-handoff gate (`HANDOFF_STALE_OR_ABSENT`, detecting-site
      `skill-orchestrate/SKILL.md:stage-5-stale-handoff`): after the existing
      `system-defect-record.sh` call, call the helper. Capture the recorder's stdout into
      `record_result` by dropping only the `>/dev/null` half of the existing
      `>/dev/null 2>&1` redirect (keep stderr discarded and keep the `|| echo "Note: ..."`
      non-fatal tail intact).
- [x] Site 2 — stray-handoff sweep (`HANDOFF_MISLOCATED`, `...:stage-5-stray-handoff`): same
      treatment. The append must run BEFORE the `mv "$stray" ...` line, for the same reason the
      existing recorder call does — the observation must survive a failed move. Carry the stray
      path into `detail`.
- [x] Site 3 — recovered-path evidence arm (`ARTIFACTS_SHAPE_MISMATCH`, `...:stage-5-recovered`):
      same treatment, inside the existing
      `elif [ "$evidence_suspect" = "true" ] && [ "$evidence_reason" = "ARTIFACTS_SHAPE_MISMATCH" ]`
      arm.
- [x] Site 4 — Tier C off-schema arm (`OFF_SCHEMA_STATUS`, `...:stage-5-tier-c`): same treatment.
      Carry `$offschema_display` into `detail`.
- [x] Site 11a — the `META_MISSING_AFTER_NARRATION` caller-side discriminant. The
      `if skill_gate_completion_claim "$task_number" "$phases_completed" "$phases_total"
      "$plan_markers_verified" "[orchestrate]"; then ... fi` block in this file currently has **no
      `else` branch** (it closes at `fi` followed by the "On refuse: no status transition" comment).
      Add one that preserves the existing no-transition semantics exactly and only observes:
      ```bash
      else
        # `skill_gate_completion_claim`'s Case 3/3 (phases_total == 0 AND plan_markers_verified
        # != "true") already called system-defect-record.sh internally. Re-derive that case here
        # from variables this caller already holds, so the observation reaches this run's ledger
        # without reading or editing scripts/skill-base.sh. Case 1 (phases_total > 0, incomplete)
        # is an ordinary refuse and is NOT a defect — it must not append.
        if [ "${phases_total:-0}" -eq 0 ] && [ "${plan_markers_verified:-}" != "true" ]; then
          append_detected_defect "META_MISSING_AFTER_NARRATION" \
            "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
            "scripts/skill-base.sh:skill_gate_completion_claim" \
            "completion claimed with phases_total=0 and unverified plan markers" ""
        fi
      fi
      ```
      `record_result` is empty here: the recorder was invoked inside the function, not by this
      caller, so its stdout is not observable from here. State that in a comment.
- [x] Confirm no edit in this phase alters control flow: every append is additive and no existing
      branch condition, `echo`, `case` arm, or status transition is changed.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts **5 wiring points** in this file (4 in-file recorder sites
+ 1 gate discriminant). Confirm by
`grep -c 'system-defect-record.sh' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
restricted to the single-task Stage 5 region (expected 4 executable call sites; a fifth
occurrence appears in a prose comment near the top of the file and is not a call site) and by
locating exactly one `skill_gate_completion_claim` call in single-task Stage 5. If the counts
differ, wire what is on disk.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 5: helper definition, four detection sites, one gate `else` branch

**Verification**:
- Grep the file for `append_detected_defect`: one definition + five call sites.
- Grep for `[system-defect:auto]`: present in the helper only (sites inherit it).
- Every `system-defect-record.sh` call in Stage 5 retains its `|| echo "Note: system-defect
  recording failed (non-fatal)" >&2` tail.
- No `AskUserQuestion` appears anywhere in the file (`grep -c AskUserQuestion` is 0).
- The `else` branch performs no `skill_postflight_update` and no state transition.

---

### Phase 3: Wire the four hard single-task Stage 5 detection sites [NOT STARTED]

**Goal**: Mirror Phase 2 in `skill-orchestrate-hard/SKILL.md`, whose single-task Stage 5 is a
structurally separate implementation, not a thin wrapper.

**Tasks**:
- [ ] Define the same `append_detected_defect` helper in this file's Stage 5, with the
      `[hard-orchestrate]` notice prefix. Add a comment stating it is the hard-mode twin of the
      base-file helper and that the two must stay in sync — this is the file pair where a one-sided
      fix is a known recurring defect class.
- [ ] Site 7 — stale-handoff gate (`HANDOFF_STALE_OR_ABSENT`,
      `skill-orchestrate-hard/SKILL.md:stage-5-stale-handoff`), attributed path
      `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`.
- [ ] Site 8 — stray-handoff sweep (`HANDOFF_MISLOCATED`, `...:stage-5-stray-handoff`), append
      before the `mv "$stray" ...` line.
- [ ] Site 9 — recovered-path evidence arm (`ARTIFACTS_SHAPE_MISMATCH`, `...:stage-5-recovered`).
- [ ] Site 10 — Tier C off-schema arm (`OFF_SCHEMA_STATUS`, detecting-site `...:tier-c` — note this
      file's existing recorder call uses `tier-c`, not `stage-5-tier-c`; reuse the string already
      on disk rather than normalizing it, so the ledger's `detecting_site` matches the durable
      `events.jsonl` record for the same firing).
- [ ] Site 11b — the gate discriminant. Unlike base mode, this file's
      `if skill_gate_completion_claim ... "[hard-orchestrate]"; then ... else ... fi` **already has
      an `else` branch** (it echoes `skeleton=${skeleton} at refusal.`). Extend that existing branch
      with the same `phases_total -eq 0 && plan_markers_verified != "true"` discriminant and append;
      do not add a second `else`, and do not remove or reorder the existing `skeleton=` echo or the
      "Leave state as `implementing`" comment.
- [ ] Capture `record_result` at the four in-file sites by the same `>/dev/null`-drop as Phase 2.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts **5 wiring points** in this file (4 in-file recorder sites
+ 1 gate discriminant extension) and asserts that the existing `else` branch is present. Confirm
both on disk before editing: locate the `skill_gate_completion_claim ... "[hard-orchestrate]"` call
and read its full `if/else/fi` before adding anything.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - Stage 5: helper definition, four detection sites, gate `else`-branch extension

**Verification**:
- Grep for `append_detected_defect`: one definition + five call sites.
- The notice prefix in this file is `[hard-orchestrate]`, not `[orchestrate]`.
- `grep -c AskUserQuestion` on this file returns exactly the pre-existing count from Stage 6
  blocker escalation (record the before-count and assert it is unchanged) — this phase adds none.
- The Stage 6 blocker-escalation region is byte-for-byte unchanged.

---

### Phase 4: Wire the base multi-task Stage MT-4 detection sites [NOT STARTED]

**Goal**: The two multi-task detection sites — which serve `/orchestrate` and `/orchestrate --hard`
batches alike, since hard mode has no MT implementation of its own — append to
`mt_state_file.detected_defects`.

**Tasks**:
- [ ] Add an MT-scoped append idiom near Stage MT-4's start, targeting `$mt_state_file` and using
      `$task_num` (not `$task_number`) and this stage's `${session_id}_${task_num}` convention.
      Match the idiom the existing `defer_ledger` appends in Stages MT-3/MT-4 already use so the
      two read as the same kind of write. The notice prefix is `[orchestrate]` and the message
      names the task: `[orchestrate] Task #${task_num}: [system-defect:auto] queued for postflight
      summary — defect_class=... attributed_path=... detecting_site=...`.
- [ ] Site 5 — MT-4 step 1 recovered-path evidence arm (`ARTIFACTS_SHAPE_MISMATCH`,
      `skill-orchestrate/SKILL.md:stage-mt4-recovered`): append + notice after the existing
      recorder call, inside the same `elif` arm.
- [ ] Site 6 — MT-4 step 3 off-schema arm (`OFF_SCHEMA_STATUS`,
      `skill-orchestrate/SKILL.md:stage-mt4-tier-c`): this site is currently specified as prose
      naming an inline recorder invocation rather than as a fenced code block. Extend that prose
      with the append and notice in the same register, keeping the existing "scoped to this task's
      own `task_num`/`session_id`" and "attributed to this SKILL.md's own path" clauses intact.
- [ ] Site 11c — the MT-4 step 3 gate discriminant. Step 3's `implemented` arm calls
      `skill_gate_completion_claim "$task_num" "$phases_completed" "$phases_total"
      "$plan_markers_verified" "[orchestrate]"` and its refuse path is specified in prose ("On a
      refuse, **skip the postflight call**... leave the task at `implementing`"). Add, in the same
      prose register, the instruction that on a refuse the implementer additionally evaluates the
      `phases_total -eq 0 && plan_markers_verified != "true"` discriminant and appends a
      `META_MISSING_AFTER_NARRATION` entry with detecting-site
      `scripts/skill-base.sh:skill_gate_completion_claim`. State explicitly that this changes
      nothing about the refuse path's existing behavior — steps 4-6 still run unchanged, the task
      still stays at `implementing` and still stays eligible for re-dispatch bounded by
      `MAX_CYCLES_MT`.
- [ ] Add a note at Stage MT-4 recording, as Stage MT-1 already does for `defer_ledger`, that these
      MT sites serve hard-mode batches too and need no hard-file mirror.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts **3 wiring points** in Stage MT-4 (2 recorder sites + 1
gate discriminant) and asserts that site 6 and site 11c are prose-specified rather than fenced
code. Confirm both forms on disk before editing; if either has been converted to a fenced block
since, wire it as code in that block's own idiom.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-4 steps 1 and 3: MT append idiom, two detection sites, one gate discriminant

**Verification**:
- Grep the MT-4 region for `detected_defects`: three appends plus the idiom definition.
- No append in this phase targets `$loop_guard_file` (MT runs have no loop guard).
- The `defer_ledger` appends in MT-3/MT-4 are unchanged.
- No admission gate, eligibility check, or `failed_tasks` mutation was touched.

---

### Phase 5: Add hard mode's missing single-task Stage 8 metadata merge [NOT STARTED]

**Goal**: Give `detected_defects` somewhere to land on the hard-mode single-task path by adding the
`.return-meta.json` metadata-merge subsection that Stage 8 currently lacks entirely.

**Tasks**:
- [ ] Confirm on disk that hard mode's Stage 8 ("Cleanup") contains only `rm -f "$loop_guard_file"`
      and `rm -f "$churn_file"`, and that `cycles_used` and `final_state` occur nowhere in the file.
- [ ] Insert a new "Write metadata file" subsection into hard mode's Stage 8, **before** the `rm -f`
      block (the loop guard must still exist when `detected_defects` is read from it), mirroring
      base mode's Stage 8 structure: a clean-exit variant and a partial-exit variant, each doing a
      merge-onto-existing (`existing_meta=$(cat "$meta_file" 2>/dev/null || echo '{}')`,
      `jq ... '. * {...}' > "$tmp_meta" && mv "$tmp_meta" "$meta_file"`), never a wholesale
      overwrite — carrying base mode's own comment about not clobbering fields an earlier writer
      owns.
- [ ] In both variants, read `detected_defects=$(jq -c '.detected_defects // []'
      "$loop_guard_file" 2>/dev/null || echo '[]')` and pass it as
      `--argjson detected_defects "$detected_defects"` into a
      `"detected_defects": $detected_defects` key inside the same `metadata` object.
- [ ] Set `status` to `"implemented"` on the clean-exit variant and `"partial"` on the partial-exit
      variant — the same two values base mode's Stage 8 writes. Carry base mode's comment that this
      is the `.return-meta.json` skill-status vocabulary, NOT the state.json task-status
      vocabulary, and must not be "corrected" to `"completed"`. **No new top-level status value is
      introduced**: a run that observed a defect but otherwise completed is still `"implemented"`.
- [ ] Include `cycles_used` and `final_state` in the same `metadata` object, matching base mode's
      shape. Add an in-place comment stating that these two are written here because a merge block
      mirroring base mode's would be structurally incomplete without them, and that closing the
      broader hard-mode metadata gap is not this change's purpose.
- [ ] Retitle the stage from "Cleanup" to something covering both responsibilities (e.g. "Postflight
      and Cleanup"), and preserve verbatim the existing paragraph about both runtime files being
      ephemeral, gitignored, and removed only at full-loop termination, plus the trailing "(Only on
      successful completion. Leave loop guard and churn state on partial for resume.)" note.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts that hard mode's Stage 8 today has **zero** metadata-merge
statements and that `cycles_used` occurs **zero** times in the file. Confirm with
`grep -c 'cycles_used\|final_state' agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
before editing; a non-zero result means the asymmetry has since been fixed elsewhere and this phase
must be re-scoped to a field addition instead of a net-new block.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - Stage 8: net-new metadata-merge subsection (clean-exit + partial-exit), stage retitle

**Verification**:
- The merge block precedes the `rm -f "$loop_guard_file"` line in document order.
- Both variants use `. * {...}` merge semantics, never a bare object write.
- `grep -c 'detected_defects' ` on hard mode's Stage 8 region returns 2 reads + 2 argjson + 2 keys.
- The top-level `status` values written are exactly `"implemented"` and `"partial"`.
- The ephemerality paragraph and the "(Only on successful completion...)" note survive unchanged.

---

### Phase 6: Propagate `detected_defects` through base-mode postflight [NOT STARTED]

**Goal**: Carry the accumulator into `.return-meta.json` (single-task) and
`.return-meta-multi-${session_id}.json` (batch) alongside `defer_ledger`, with no change to either
file's top-level `status` vocabulary.

**Tasks**:
- [ ] Base Stage 8, clean-exit block: read
      `detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file" 2>/dev/null || echo '[]')`
      **before** the `rm -f "$loop_guard_file"` line, add `--argjson detected_defects
      "$detected_defects"` and a `"detected_defects": $detected_defects` key inside the existing
      `metadata` object next to `cycles_used`/`final_state`. Add a comment noting the read must
      precede cleanup.
- [ ] Base Stage 8, partial-exit block: same addition. The loop guard is preserved on partial exit,
      so ordering is not load-bearing there, but keep the two blocks structurally identical.
- [ ] Base Stage MT-5 step 1: add `detected_defects` to the enumerated read-list from
      `mt_state_file` (currently `completed_tasks, failed_tasks, deferred_self_modifying,
      deferred_deploy_checkpoint, dispatch_start_ts, defer_ledger, verify_deploy_baseline_notices,
      current_statuses, cycles_used, counts`).
- [ ] Base Stage MT-5 step 5: add `--argjson detected_defects "$detected_defects"` and a
      `"detected_defects": $detected_defects` key inside the existing `metadata` object, positioned
      immediately after `defer_ledger`. Leave `--arg status "$exit_status"` and the top-level
      `status` key untouched.
- [ ] Immediately after that `jq -n` block, extend the existing paragraph ("The top-level `status`
      field keeps its existing closed vocabulary... and gains no new value") to name
      `detected_defects` alongside `forward_progress_violated` as carried only inside `metadata`,
      never as a `status` value.
- [ ] Base Stage MT-5 step 3: add an explicit sentence, modelled on the existing
      "**`verify_deploy_baseline_notices` is NEVER consulted by this branch selection**" paragraph,
      stating that `detected_defects` is likewise never consulted by `exit_status` branch selection.
      A batch that completed its work successfully and also observed a defect is `"implemented"`.
      State that this is a deliberate decision so a later pass does not "fix" it into `"partial"`.
- [ ] Base Stage MT-5 step 4: add a short reporting instruction, parallel to the existing
      `verify_deploy_baseline_notices` paragraph, stating that whenever `detected_defects` is
      non-empty it MUST be reported as its own distinct category — never folded into any defer
      category and never omitted merely because the batch otherwise succeeded — and pointing at
      `commands/orchestrate.md`'s `### System Defects Detected` section for the actual rendering,
      with the standing "this stage only supplies the data" caveat.

**Timing**: 1.25 hours

**Depends on**: 4

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts **6 edit points** in the base file (2 Stage 8 blocks, MT-5
steps 1/3/4/5). Confirm by locating each anchor string on disk first; in particular confirm the
Stage 8 clean-exit block's `rm -f "$loop_guard_file"` and its metadata merge are in the order the
report describes, so the read can be placed before cleanup.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 8 clean-exit and partial-exit metadata merges; Stage MT-5 steps 1, 3, 4, 5

**Verification**:
- Both Stage 8 `jq` merges parse and carry three metadata keys each.
- The Stage MT-5 `jq -n` block's argument list and object keys stay in matching order; the
  top-level `status` line is unchanged.
- The `exit_status` branch logic in step 3 contains no reference to `detected_defects` other than
  the new never-consulted statement.
- Key name `detected_defects` matches the producer sites from Phases 2 and 4 exactly (this is the
  cross-file contract this phase's `interface` tier exists to check).

---

### Phase 7: Render the enumerated section in `commands/orchestrate.md` [NOT STARTED]

**Goal**: Make the accumulated detections visible to the operator at batch postflight and at
single-task completion, in the same table style as the existing Deferred sections.

**Tasks**:
- [ ] Insert a new `### System Defects Detected` section in the "Batch Orchestrate Results"
      consolidated-output template, positioned immediately after
      `### Pre-Existing Deploy-Verify Failures (Not Deferred)` and immediately before
      `### Next Steps`.
- [ ] Give it a parenthetical gating note copied in structure from its neighbour: rendered only
      when `detected_defects` is non-empty; populated from `mt_state_file.detected_defects` /
      `.return-meta-multi.json`'s `metadata.detected_defects`; one row per entry; **renders on a
      SUCCEEDED (`"implemented"`) batch just as readily as a `"partial"` one** — an observation,
      never a failure signal. Reference
      `context/patterns/system-defect-discrimination.md` for the underlying predicate. Do not gate
      on `exit_status` in any form.
- [ ] Give it the table, in the same style as `### Deferred (other admission exclusions)`:
      ```markdown
      | Task | Defect Class | Attributed Source Path | Detecting Site | Detail |
      |------|--------------|-------------------------|------------------|--------|
      | #{N} | OFF_SCHEMA_STATUS | agent-system/extensions/core/skills/skill-orchestrate/SKILL.md | skill-orchestrate/SKILL.md:stage-mt4-tier-c | handoff dispatch_status is off-schema |
      ```
      The three columns the required behaviour names — defect class, attributed source-store path
      under `agent-system/extensions/**`, and detecting site — are mandatory; Task and Detail are
      the contextual columns.
- [ ] Add an operator-remedy line beneath the table: these rows name a defect in the agent system
      itself, not in the task's work; the remedy is a fix in the named source-store path, and the
      durable record is already in `specs/events.jsonl`. State that no task was excluded and no
      task status was mutated because of these rows.
- [ ] Add the single-task counterpart in the `## Output` section, beneath the existing
      Completion / Partial / Blocked lines: a **System Defects Detected** block gated identically
      (non-empty `metadata.detected_defects` read from the task's `.return-meta.json`), using the
      same table shape as the batch section so the two renderings stay visually consistent. State
      that it renders on a Completion outcome as readily as on a Partial one.
- [ ] Add a sentence to the single-task block noting it applies to `/orchestrate --hard` runs
      identically, since hard mode writes the same `metadata.detected_defects` key (from Phase 5).
- [ ] Confirm the new sections introduce no `AskUserQuestion` and no interactive step of any kind,
      and create no task.

**Timing**: 1 hour

**Depends on**: 5, 6

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts **2 rendering slots** (one batch, one single-task) in a
single file, and asserts that the anchor sections
`### Pre-Existing Deploy-Verify Failures (Not Deferred)`, `### Next Steps`, and `## Output` are all
present on disk. Confirm all three anchors before inserting.

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - new `### System Defects Detected` section in the consolidated-output template; new defects block in `## Output`

**Verification**:
- The new batch section sits strictly between `### Pre-Existing Deploy-Verify Failures (Not
  Deferred)` and `### Next Steps`.
- The gating sentence contains "renders on a SUCCEEDED" (or equivalent) and the section contains no
  occurrence of `exit_status`.
- Both tables carry the Defect Class, Attributed Source Path, and Detecting Site columns.
- The field name read in both slots is `metadata.detected_defects` / `mt_state_file.detected_defects`,
  matching Phases 5 and 6 exactly.
- `grep -c AskUserQuestion agent-system/extensions/core/commands/orchestrate.md` is unchanged from
  its pre-edit value.

---

### Phase 8: Base/hard parity audit and end-to-end consistency verification [NOT STARTED]

**Goal**: Prove the mechanism is complete, symmetric across the base/hard pair, and free of the
specific failure modes named in the Risks table — the "fix landing in only one file" class above
all.

**Tasks**:
- [ ] **Parity check.** For each of the two skill files, enumerate: number of
      `append_detected_defect` call sites, presence of the Stage 2 fresh-init field, number of
      Stage 2 read paths carrying the field, and presence of a Stage 8 metadata merge carrying the
      field. Base and hard must each report 5 single-task call sites, a fresh-init field, all read
      paths wired, and a Stage 8 merge. Record the actual numbers; any asymmetry is a defect to fix
      before closing this phase, not a note to file.
- [ ] **MT coverage check.** Confirm the three MT-4 wiring points exist in the base file only, and
      that the base file carries the explicit note that MT stages serve hard-mode batches too, so a
      future reader does not "fix" the intentional absence in the hard file.
- [ ] **Never-a-gate check.** Grep both skill files and `commands/orchestrate.md` for every
      occurrence of `detected_defects` and classify each as declaration, append, read-for-metadata,
      read-for-render, or prose. Assert zero occurrences inside an eligibility check, all-terminal
      check, circuit breaker, convergence guard, admission branch, or `exit_status` branch.
- [ ] **Unconditional-append check.** Assert no `append_detected_defect` call is nested inside a
      conditional on `record_result`, on the recorder's exit status, or on a `SUPPRESSED:` value.
- [ ] **No-interactive check.** Assert `grep -c AskUserQuestion` on each of the three files equals
      the pre-change baseline (0 for the base skill and the command doc; the pre-existing Stage 6
      count for the hard skill), proving this change added none.
- [ ] **Vocabulary check.** Assert no new top-level `status` value was introduced: the values
      written are `"implemented"` / `"partial"` in single-task Stage 8 (both files) and
      `$exit_status` unchanged in MT-5.
- [ ] **jq validity check.** Extract every `jq`/`jq -n` program touched by Phases 1-6 and confirm
      each parses (e.g. `jq -n '<program>' </dev/null` or `echo '{}' | jq '<program>'` with
      arguments stubbed), so no malformed filter ships in a spec file.
- [ ] **Source-store boundary check.** Run `git status --short` and assert every modified path is
      under `agent-system/extensions/core/` and that nothing under `.claude/` was written.
- [ ] **Deliverable-hygiene check.** Run `bash .claude/scripts/check-task-references.sh` (or grep
      the three modified files) and confirm no task-number citation was introduced — the example
      rows in the rendering tables must use `#{N}` placeholders, not concrete task numbers.
- [ ] **Doc-lint.** Run `bash .claude/scripts/verify-deploy.sh` (or at minimum
      `check-extension-docs.sh`) and confirm no new finding relative to the pre-change baseline.
      Record the baseline first: a pre-existing failure is not this change's to fix, and must be
      reported as pre-existing rather than silently absorbed.
- [ ] Record every count and check result in the phase's completion notes so the audit is
      reproducible, not merely asserted.

**Timing**: 0.75 hours

**Depends on**: 7

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the expected per-file counts from Phases 1-7 (5 single-task
call sites per skill file, 3 MT wiring points in the base file only, 2 rendering slots). These are
hypotheses inherited from earlier phases; this phase's whole purpose is to confirm them against
disk. A mismatch means an earlier phase under- or over-delivered and must be corrected here.

**Files to modify**:
- None (verification only). Any defect found is fixed in the owning phase's file and re-verified.

**Verification**:
- All ten checks above pass, with recorded numbers.
- The full gate set for this repository runs clean relative to its pre-change baseline.

---

## Testing & Validation

- [ ] Both skill files and the command doc parse as valid markdown and their fenced bash/jq blocks
      are syntactically valid.
- [ ] `detected_defects` is declared in exactly two accumulator homes and never conflated with
      `defer_ledger` or `verify_deploy_baseline_notices`; those two fields' declarations and
      consumers are byte-for-byte unchanged.
- [ ] All eleven detection sites append and announce; the shared `skill-base.sh` site is covered at
      all three of its callers via the caller-side discriminant, with `scripts/skill-base.sh`
      unmodified.
- [ ] Case 1 refusals of `skill_gate_completion_claim` (`phases_total > 0`, incomplete) do NOT
      append — only Case 3/3 does.
- [ ] `.return-meta.json` and `.return-meta-multi.json` carry `metadata.detected_defects`; neither
      top-level `status` vocabulary gained a value.
- [ ] The consolidated summary renders the defects table on an `"implemented"` batch, not only on a
      `"partial"` one.
- [ ] Single-task base and single-task hard both surface detections; neither path is wired alone.
- [ ] No `AskUserQuestion` was added anywhere.
- [ ] No file under `.claude/**` was hand-authored.

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — accumulator declaration, Stage 2
  loop-guard wiring, five single-task Stage 5 wiring points, three Stage MT-4 wiring points, Stage 8
  metadata propagation, Stage MT-5 propagation and reporting instructions.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Stage 2 loop-guard wiring,
  five single-task Stage 5 wiring points, net-new Stage 8 metadata-merge subsection.
- `agent-system/extensions/core/commands/orchestrate.md` — `### System Defects Detected` batch
  section and single-task `## Output` defects block.
- Phase 8's recorded audit numbers (in the implementation summary, not a separate file).

## Rollback/Contingency

Every change is additive: a new field, new append statements, new notice lines, new metadata keys,
and two new rendering sections. No existing field, branch, gate, or status value is modified, so
reverting is a clean `git revert` of the phase commits with no data migration and no state-file
compatibility concern — the `// []` forward-compatible reads mean a loop-guard or `mt_state_file`
written by the reverted code is still read correctly by the reverted-to code, and vice versa.

If a phase must be abandoned mid-way, the safe partial states are: after Phase 1 (field declared,
never written — harmless), and after any of Phases 2-5 (detections accumulate and announce but do
not yet reach metadata or the summary — a strict improvement over today, since the per-detection
`[system-defect:auto]` notice already fires). The one state to avoid shipping is a base-only or
hard-only wiring, which is why Phase 8's parity audit is a gate rather than a formality.
