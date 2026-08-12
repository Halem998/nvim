# Implementation Plan: Task #55

- **Task**: 55 - Dedupe orchestrate skill bodies (LEVER 1: the two orchestrate skills)
- **Status**: [IMPLEMENTING]
- **Effort**: 9.5 hours
- **Dependencies**: Task 48
- **Research Inputs**: specs/055_dedupe_orchestrate_skill_bodies/reports/01_dedupe-orchestrate-skill-bodies.md
- **Artifacts**: plans/01_dedupe-orchestrate-skill-bodies.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close the byte-identical duplication between `skill-orchestrate/SKILL.md` (196,171 B) and
`skill-orchestrate-hard/SKILL.md` (127,145 B) by moving the shared logic into exactly one home —
`scripts/skill-base.sh` functions for logic needing caller shell scope, and new
`scripts/orchestrate-*.sh` stdout-JSON scripts (the `orchestrate-recover-outcome.sh` pattern) for
self-contained procedural blocks. No new include or compose mechanism is invented; both mechanisms
are already exercised in production. The definition of done is: the duplicated logic exists in one
place, both engines call it by name, every mode remains fully specified, and the existing
orchestration test suite passes **unmodified**.

### Research Integration

The research report is carried forward in full for its Stage 5 mega-block anatomy (std lines
640-1345 / 705 lines / 50,017 B; hard 649 lines / 46,014 B; ~85% line-for-line identical after
normalizing the notice prefix and self-attribution paths), its enumeration of genuine hard-only
asymmetries that must NOT be forced into parity (`skeleton`, `sorry_inventory`, the
`loop-guard-staleness` detector, the H1-location `marker-handoff-crosscheck`), and its
identification of `hard_orchestrate_propagate_completion` as the already-half-done promotion
candidate.

**One research finding is superseded and materially widened by this plan.** The report names
`test-handoff-reader-parity.sh` as "the" binding test constraint. Direct inspection during planning
found **six** test files that read literal text out of the two SKILL.md bodies, and — decisively —
**two of them `eval` extracted SKILL.md regions as live bash in a subshell whose cwd is a temp
workdir, not the repo root**:

| Test | Mechanism | Consequence for extraction |
|------|-----------|----------------------------|
| `test-handoff-reader-parity.sh` | Regex-extracts `VAR=$(echo "$handoff" \| jq -[rc] '...')` literals; awk-extracts the `dispatch-seq-gate` sentinel region and compares engines | The ~13 `$handoff`-anchored one-line reads must stay literal, with the variable named `$handoff`, in both files |
| `test-handoff-dispatch-identity.sh` | awk-extracts `# ── Staleness gate ─` through `dispatch-seq-gate:end` from **both** files, prepends an `append_detected_defect` **stub**, runs `bash -n`, then `eval`s the region with `cd "$WORKDIR"` | This whole region must remain **self-contained inline bash**. A `bash .claude/scripts/foo.sh` call inside it would not resolve from the fixture cwd. Calls inside it must keep the literal name `append_detected_defect` |
| `test-loop-guard-budget-override.sh` | awk-extracts `budget-continuation-override:begin` through each engine's resume anchor from both files, `bash -n`, then `eval`s it; also greps the Stage 7 MAX_CYCLES message for `--continue-budget` | The Stage 2 budget-override + resume-read region must likewise remain self-contained inline bash |
| `test-routing-resolution.sh` | Asserts >= 3 `command-route-agent.sh` invocations in **each** SKILL.md and that no case-table/sed-derivation pattern remains | Extraction must not drop either file below 3 literal resolver invocations |
| `test-loop-guard-staleness.sh` | Sentinel-pair extraction from the hard file's `loop-guard-staleness` region | That region is already out of scope (intentional hard-only asymmetry) |
| `test-resume-scan-nonconformance.sh` | Reads the hard file's resume-scan region | Leave untouched |

The design consequence is the plan's central technique, applied throughout: **named-shim
preservation**. Where a test requires an identifier or a region to remain literally present, the
identifier keeps a two-to-three-line local definition in each engine that delegates to the single
shared implementation. The duplication closes; the test-visible surface does not move. This is why
Phase 1 exists as a distinct, mandatory phase: the locked-region manifest must be established as
evidence before any byte is moved, not discovered by a failing test in Phase 4.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- The 28,421+ bytes of literal cross-file duplication exists in exactly ONE place afterward, with
  both engines calling it by name.
- Extraction prefers executable bash (`scripts/orchestrate-*.sh`, `skill-base.sh` functions) over
  prose-to-`context/**`, because a script's source is never loaded into the invocation context
  whereas a backticked path is inert text an agent may still choose to Read.
- Every mode remains fully specified — inline, or via an explicit pointer the executing agent is
  instructed to follow. No behavior is silently dropped.
- Existing orchestration tests pass **unmodified**. No test file is edited, at all, for any reason.
- Measured before/after bytes are reported for every file touched, using eager-prefix + command +
  skill + agent accounting.

**Non-Goals**:
- Forcing parity where asymmetry is intentional: the hard-only `loop-guard-staleness` detector,
  `skeleton`/`sorry_inventory` reads, and the H1-location `marker-handoff-crosscheck` stay
  hard-mode-only. The base file's Stage-5-location `marker-handoff-crosscheck` is NOT unified with
  the hard file's H1-location equivalent — different trigger points, different semantics
  (downgrade-after-the-fact vs. refuse-before-dispatch), by design.
- Inventing a build-time include, partial, fragment, or compose mechanism for `install-extension.sh`.
- Editing `commands/todo.md`, `commands/orchestrate.md`, rules, or merge sources — sibling subtasks
  own those. They may be **read** for the accounting denominator; they are never written.
- Editing `context/architecture/orchestrate-state-machine.md`. The research report recommends adding
  a `skill_*`-vs-`orchestrate-*.sh` boundary note there; that file is outside this task's territory,
  so the recommendation is recorded in the implementation summary for a follow-up instead.
- Closing the ~13 `$handoff`-anchored one-line jq reads. Doing so requires rewriting
  `test-handoff-reader-parity.sh`, which the "pass unmodified" acceptance bar forbids. They are
  cheap (well under 1 KB combined per file) and are already policed against drift by that test.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A test that `eval`s an extracted region breaks because a script call was introduced inside it (cwd is a temp workdir, so `.claude/scripts/...` will not resolve) | H | H | Phase 1 produces the locked-region manifest with exact begin/end anchors; Phases 3-6 must not introduce any script invocation between those anchors. Phase 1's manifest is the checklist, re-read at the start of each later phase |
| A promoted helper renames a call site the dispatch-identity test stubs by name (`append_detected_defect`) | H | H | Named-shim preservation: each engine keeps a <=3-line `append_detected_defect()` / `mint_dispatch_seq()` local definition delegating to the shared `skill_orchestrate_*` implementation. Never rename call sites inside a locked region |
| A shared Stage 5 script silently drops a hard-only behavior by treating hard as a superset of base | H | M | The research report's divergence enumeration (skeleton, sorry_inventory, marker-handoff-crosscheck location, detecting-site strings) is carried as an explicit per-phase checklist; hard-only arms stay inline or are passed as explicit opt-in flags, never folded into a common path |
| Helpers close over ambient shell state (`loop_guard_file`, notice prefix) that differ per engine | M | H | Every promoted function takes the guard-file path and the notice prefix as **explicit positional parameters**. No shared function reads an ambient global |
| The Stage 5 `dispatch_status` case block (Phase 4, largest and riskiest) drives loop control state, so a script boundary could swallow a state transition | H | M | The script prints a decision JSON to stdout; the caller applies the state transition inline. The script never sets loop state itself. Phase 4 verifies by asserting every `case` arm in the pre-edit block maps to a decision value in the post-edit script |
| `test-routing-resolution.sh` drops below its >= 3 `command-route-agent.sh` invocations per file | M | L | Phase 1 records the current per-file count; Phase 7 re-asserts it. No phase touches Stage 1b routing |
| Detecting-site strings already disagree between the files (`stage-5-tier-c` vs `tier-c`) and are durable in `specs/events.jsonl` | L | H | **Decision (stated, not accidental)**: preserve each engine's existing self-attribution string verbatim by passing it as an explicit `--detecting-site` argument. Do not normalize; historical ledger entries are left alone |
| Edits land in `.claude/**` and are wiped by the next deploy | H | L | Source-store rule is binding: every write targets `agent-system/extensions/core/**`. Deploy with `deploy-headless.sh` only to verify propagation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 7 | 6 |

Phases within the same wave can execute in parallel. This plan is fully sequential: every phase
after Phase 1 edits overlapping regions of the same two SKILL.md files plus `skill-base.sh`, so
parallel execution would produce edit conflicts on shared files rather than genuine speedup.

---

### Phase 1: Locked-Region Manifest and Baseline Measurement [COMPLETED]

**Goal**: Establish, as evidence rather than assumption, exactly which literal regions and
identifiers in the two SKILL.md bodies are mechanically read or executed by existing tests, and
record the baseline byte accounting that Phase 7's acceptance report is measured against.

**Tasks**:
- [x] For each of the six tests listed in "Research Integration" above, record the exact extraction
      anchors (begin marker, end marker or anchor text, and grep/awk mechanism) and whether the
      extracted text is compared, `bash -n`-checked, or `eval`ed. *(completed)*
- [x] Resolve each anchor to concrete line ranges in both source-store SKILL.md files. Record
      begin/end anchor **text**, never line numbers alone — line numbers drift on every edit. *(completed)*
- [x] Record every identifier that a test stubs or greps by name (at minimum
      `append_detected_defect`, `mint_dispatch_seq`, `$handoff`, `handoff_artifact_{path,type,summary}`,
      `skeleton`, `sorry_inventory`, `blocker_target`, `verbatim_goal`). *(completed)*
- [x] Record the current `command-route-agent.sh` invocation count per SKILL.md file (must stay >= 3). *(completed: 3/3)*
- [x] Write the manifest to `specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md`. *(completed)*
- [x] Record baseline bytes: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
      `skill-orchestrate-hard/SKILL.md`, `scripts/skill-base.sh`, each existing
      `scripts/orchestrate-*.sh`, plus the accounting denominator files
      (`.claude/CLAUDE.md`, `.claude/commands/orchestrate.md`, the eager `.claude/rules/*.md` set). *(completed)*
- [x] Run the full test suite (`scripts/tests/run-all.sh`) and record a green baseline. Any test
      already failing before any edit must be recorded as pre-existing, so Phase 7 does not
      misattribute it. *(completed: 42 passed, 0 failed, 0 skipped, 42 total)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Planning found six test files reading literal SKILL.md text and two of them
`eval`ing extracted regions. Confirm at implementation time by re-running
`grep -l 'skill-orchestrate' agent-system/extensions/core/scripts/tests/*.sh` and, for each hit,
grepping for `eval`/`bash -n`/`grep -oP`. If the count differs from six, the manifest — not this
plan's prose — is authoritative for all later phases.

**Files to modify**:
- `specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md` - new; the manifest
- No source files are edited in this phase

**Verification**:
- The manifest names, for every one of the six tests, at least one concrete anchor resolved in at
  least one SKILL.md file.
- `run-all.sh` baseline captured with pass/fail counts recorded.

---

### Phase 2: Promote the Helper Trio to skill-base.sh Behind Named Shims [COMPLETED]

**Goal**: Move the three verbatim-twin helpers into one home in `scripts/skill-base.sh`, while
each engine retains the locally-named entry point the tests and existing call sites depend on.

**Tasks**:
- [x] Add `skill_orchestrate_mint_dispatch_seq <loop_guard_file>` to `scripts/skill-base.sh`,
      carrying the single copy of the increment-and-echo logic and its explanatory comments. *(completed)*
- [x] Add `skill_orchestrate_append_detected_defect <loop_guard_file> <notice_prefix> <class>
      <attributed_path> <site> <detail> <record_result>` — guard-file path and notice prefix as
      **explicit parameters**, never ambient globals. *(completed)*
- [x] Add `skill_orchestrate_propagate_completion <task_number> <task_type> <task_dir>
      <dispatch_start_ts> [recover_json]`, promoted from the hard file's local
      `hard_orchestrate_propagate_completion`. *(completed: added an extra optional 6th
      `notice_prefix` param, defaulting to `[orchestrate]`, so the shared function itself never
      hardcodes an engine-specific prefix — consistent with the "notice prefix is always an
      explicit parameter" risk mitigation)*
- [x] In **both** SKILL.md files, replace the full local bodies of `mint_dispatch_seq()` and
      `append_detected_defect()` with <=3-line shims delegating to the shared functions, preserving
      the exact function names and call signatures. Add a defensive idempotent `source` of
      `skill-base.sh` in each code fence that needs it, matching the pattern the Stage 5 fence
      already uses for `skill_corroborate_phase_counts`. *(completed)*
- [x] In the hard file, replace `hard_orchestrate_propagate_completion`'s body with a shim (both
      call sites keep calling the local name unchanged). *(completed)*
- [x] In the base file, replace the still-inline `completion_json`/`completion_summary`/
      `roadmap_items` propagation logic inside the `implemented` case with a call to the shared
      function. *(completed)*
- [x] Confirm no call site **inside** a Phase 1 locked region was renamed. *(completed: verified
      via test-handoff-dispatch-identity.sh pass — 22/22 — and by re-reading both locked regions
      after edit; the only edits inside either region were none, all shims sit strictly outside)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: Three helpers are asserted to be promotable (`mint_dispatch_seq`,
`append_detected_defect`, `hard_orchestrate_propagate_completion`), with two call sites for the
third in the hard file. Confirm by grepping both files for each identifier before editing and
re-grepping after; the post-edit count of definitions must be exactly one shim per file per
identifier, and the shared implementation exactly one.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - three new `skill_orchestrate_*` functions
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - two shims; inline completion
  logic replaced by a call
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - three shims

**Verification**:
- `bash -n` clean on `skill-base.sh`.
- `scripts/tests/test-handoff-dispatch-identity.sh` passes (this is the test that stubs
  `append_detected_defect` and `eval`s the region calling it — the direct proof the shim worked).
- `scripts/tests/test-skill-base-lifecycle.sh` and `test-handoff-reader-parity.sh` pass.
- Full `run-all.sh` matches the Phase 1 baseline.

---

### Phase 3: Extract the Stage 5 Stray-Handoff Sweep and Outcome-Recovery Narrative [COMPLETED]

**Goal**: Collapse the Stage 5 segment that begins strictly **after** `dispatch-seq-gate:end` —
the stray-handoff sweep, the outcome-recovery orchestration, and the evidence-corroboration
block — into one shared script, carrying its explanatory comments once instead of twice.

**Tasks**:
- [x] Re-read the Phase 1 manifest. Confirm the segment's start point lies strictly after
      `dispatch-seq-gate:end` in both files; the staleness/dispatch-seq region above it is
      `eval`ed by a test and MUST NOT be touched in this phase or any later one. *(completed)*
- [x] Create `agent-system/extensions/core/scripts/orchestrate-stage5-gates.sh` following the
      `orchestrate-recover-outcome.sh` idiom: compute, print a single JSON object to stdout, exit
      non-zero on hard error. Inputs include `TASK_DIR`, `dispatch_start_ts`, `task_number`,
      `session_id`, the notice prefix, and the engine's own `--detecting-site` string. *(completed:
      also takes handoff_file/handoff_stale/loop_guard_file/skill_attributed_path/cycle_count/
      plan_path — the additional explicit parameters the shared functions it calls require)*
- [x] Move the stray-handoff sweep into the script: both `system-defect-record.sh` calls, the
      `append_detected_defect` observation, and the move-aside-rather-than-delete `mv`, preserving
      the ordering invariant that both records are written **before** the `mv` so the observation
      survives a failed move. *(completed)*
- [x] Move the outcome-recovery orchestration and its evidence-corroboration narrative
      (`PHASES_ZERO_ON_SUCCESS` arm calling `skill_corroborate_phase_counts`, and the sibling
      `ARTIFACTS_SHAPE_MISMATCH` arm) into the script, preserving each arm's precondition semantics
      and its banner/log token text verbatim (`[UNVERIFIED PHASES CORROBORATED]` and the
      "Corroborated by an independent source" tail). *(completed)*
- [x] Wire both engines: replace each inline copy with the single-line invocation plus the small
      `jq` reads of the returned decision JSON. The two call sites must differ **only** by the
      notice prefix and the `--detecting-site` string. *(completed — the hard engine's call site
      also sets `skeleton=false`/`sorry_inventory='[]'` after the call on the recovered=true path,
      an intentional hard-only addition the shared script never touches)*
- [x] Leave the `$handoff`-anchored one-line jq reads untouched and literally present. *(completed
      — verified via test-handoff-reader-parity.sh pass, 19/19)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: The segment is asserted to span roughly std lines 751-1000 and the
corresponding hard range, ~85% identical after normalization. Confirm at implementation time by
diffing the two segments after `sed`-normalizing `hard-orchestrate`->`orchestrate` and
`skill-orchestrate-hard`->`skill-orchestrate`, and record the measured identical-line count in the
phase's commit message rather than trusting this estimate.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-stage5-gates.sh` - new
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 5 segment replaced
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - Stage 5 segment replaced

**Verification**:
- `bash -n` clean on the new script; it runs standalone against a fixture TASK_DIR and prints valid
  JSON.
- `test-handoff-dispatch-identity.sh` passes — proving the `eval`ed region above was not disturbed.
- `test-handoff-reader-parity.sh` passes — proving the sentinel region and the anchored jq reads
  still extract.
- Full `run-all.sh` matches baseline.

---

### Phase 4: Extract the Stage 5 Postflight Status-Transition and Artifact-Link Tail [COMPLETED]

**Goal**: Collapse the `case "$dispatch_status"` postflight tail — the largest remaining duplicate
and the riskiest, because it drives loop control state — into one shared script that **decides**
while the caller **applies**.

**Tasks**:
- [x] Enumerate every `case` arm in both engines' tails before editing (`researched`, `planned`,
      `implemented`, `partial|failed|blocked`, plus the artifact-type inference sub-`case` and each
      engine's hard-only arms). Record the enumeration; it is the completeness checklist. *(completed:
      researched/planned/implemented/partial-failed-blocked/Tier-C — identical arms in both files;
      hard-only addition is the `echo "[hard-orchestrate] skeleton=${skeleton} at refusal."`
      diagnostic inside the `implemented` arm's refusal branch, preserved via the
      `implemented_gate_passed` decision field)*
- [x] Create `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh`. Inputs are
      already-resolved scalars: `dispatch_status`, `dispatch_summary`, `phases_completed`,
      `phases_total`, `plan_markers_verified`, `handoff_artifact_{path,type,summary}`,
      `task_number`, `session_id`, `TASK_TYPE`, `TASK_DIR`, notice prefix, detecting-site string.
      *(completed: also takes `tier_c_detecting_site` as a full literal string — base/hard
      disagree beyond a shared prefix — `command_suffix`, `handoff_file`, `loop_guard_file`, and
      `cycle_count`, the additional explicit parameters the shared functions it calls require)*
- [x] The script prints a decision JSON (at minimum: next state, `offschema_dispatch_status`,
      whether to halt, inferred phase, artifact-link outcome). **It never sets loop state itself** —
      the caller applies the transition inline. This is the mitigation for the state-swallowing risk.
      *(completed: `offschema_dispatch_status`, `implemented_gate_passed`, `artifact_linked`,
      `halt`, `inferred_phase`; the caller applies `EXIT (partial)` and the cycle_count increment)*
- [x] Keep hard-only handling out of the shared path: `skeleton` and `sorry_inventory` reads and
      their logging stay inline in the hard file, or are passed as explicit opt-in flags whose
      absence is the base-mode default. Never fold them into a common arm. *(completed)*
- [x] Do not touch the base file's Stage-5-location `marker-handoff-crosscheck` region or the hard
      file's H1-location equivalent. They are intentionally non-parallel. *(completed — verified
      untouched by re-reading both regions after edit)*
- [x] Preserve the three literal `handoff_artifact_{path,type,summary}=$(echo "$handoff" | jq -r ...)`
      reads in both files — `test-handoff-reader-parity.sh` greps them file-wide. *(completed —
      19/19 pass)*
- [x] Wire both engines; the two call sites must differ only by the tolerated substitutions plus the
      hard-only flags. *(completed)*

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: The tail is asserted to span std lines ~1173-1345 (one `case` with four
top-level arms plus two nested type-inference `case`s) and the hard file's corresponding ~110-line
region with additional arms. Confirm by the pre-edit arm enumeration above; if the post-edit script
does not have a decision value for every enumerated arm, the phase is incomplete regardless of test
results.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` - new
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 5 tail replaced
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - Stage 5 tail replaced

**Verification**:
- Every arm in the pre-edit enumeration maps to a decision value produced by the new script.
- `test-handoff-reader-parity.sh` passes (artifact reads still extract identically in both engines).
- `test-reconcile-handoff-status.sh`, `test-validate-handoff.sh`,
  `test-validate-handoff-location.sh` pass.
- Full `run-all.sh` matches baseline.

---

### Phase 5: Extract the Four .return-meta.json Postflight-Merge Blocks [COMPLETED]

**Goal**: Replace the four structurally identical Stage 8 merge blocks — two in each engine
(clean-exit and terminal variants) — with a single shared function, so the merge-onto-existing
discipline cannot drift into four separately-maintained copies.

**Tasks**:
- [x] Locate all four blocks (each reads `detected_defects` from `$loop_guard_file`, then pipes
      `$existing_meta` through a `jq` merge). Confirm the count before editing. *(completed: 4
      confirmed, 2 per file)*
- [x] Add `skill_orchestrate_merge_return_meta` to `scripts/skill-base.sh`, taking the meta path,
      loop-guard path, status, and the per-site fields (`cycles_used`, `final_state`) as explicit
      parameters. *(completed with a recorded deviation: takes a resolved
      `detected_defects_json` STRING, not a loop-guard path — the base engine's clean-exit call
      site reads that value in an EARLIER fence, before its own `rm -f "$loop_guard_file"`
      cleanup, so a function that re-reads from the guard path itself would silently see an
      already-deleted file at that one call site. Requiring the caller to resolve the value at
      the same point the pre-dedup inline code did preserves the base/hard ordering asymmetry
      exactly; see the function's own header comment in skill-base.sh for the full rationale)*
- [x] Preserve read-modify-write merge semantics exactly: producer-owned fields (`modified_files`,
      `completion_data`, `memory_candidates`, `reflection`, `artifacts`) MUST survive untouched, per
      the return-metadata schema's Multiple Sequential Writers rule. *(completed — verified via a
      standalone fixture call showing modified_files/completion_data/memory_candidates untouched)*
- [x] Wire all four sites; each becomes a single call. *(completed)*
- [x] Preserve each site's distinguishing comment (the hard file's note on why `cycles_used` and
      `final_state` are written there, and the "Same merge-onto-existing discipline as the
      clean-exit variant above" note) as a one-line comment at the call site. *(completed)*

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: Four merge blocks are asserted (two per file). Confirm by grepping both
files for `existing_meta` and `detected_defects=$(jq -c '.detected_defects` before editing; if the
count is not four, adjust and record the actual count.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - one new function
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - two call sites
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - two call sites

**Verification**:
- `test-validate-return-meta.sh` and `test-skill-base-lifecycle.sh` pass.
- A fixture `.return-meta.json` carrying all five producer-owned fields survives the merge with
  those fields byte-identical.
- Full `run-all.sh` matches baseline.

---

### Phase 6: Extract the Common Stage 2 Loop-Guard Initializer Prologue [NOT STARTED]

**Goal**: Share the genuinely-common portion of each engine's Stage 2 initializer, while leaving
both the test-`eval`ed budget-override region and the intentional hard-only asymmetries untouched.

**Tasks**:
- [ ] Re-read the Phase 1 manifest and establish the exact boundaries of the `eval`ed region
      (`budget-continuation-override:begin` through each engine's resume anchor). **Nothing inside
      those boundaries may be replaced by a script call** — `test-loop-guard-budget-override.sh`
      `eval`s that text from a temp-workdir cwd.
- [ ] Create `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh` covering only
      the common prologue that sits **outside** the locked region: the `MAX_INFRA_FAILURES`
      constant, `loop_guard_file`/`handoff_file` assignment, `mkdir -p "$TASK_DIR"`, and the
      blocker-escalation/drift-detection constants.
- [ ] Leave untouched: the hard file's `current_plan_version` computation, its 3-signal
      `loop-guard-staleness` detector region, and its `churn_file` initialization. These are
      intentional hard-mode-only logic that the base file's own prose records as a separately
      decided, currently-open question — out of scope for this task.
- [ ] Leave the Stage 7 MAX_CYCLES message text intact in both files; the budget-override test
      greps it for `--continue-budget`.
- [ ] Wire both engines to the new script for the prologue only.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: The initializer blocks are asserted at ~8,692 B (base) and ~14,036 B (hard),
with roughly the first 60% common. Confirm by diffing the two blocks after normalization and by
resolving the locked-region boundary first; the extractable portion is whatever common text lies
outside that boundary, which may be materially smaller than 60%. Record the measured extractable
byte count; a small result here is a correct outcome, not a shortfall.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh` - new
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 2 prologue
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - Stage 2 prologue

**Verification**:
- `test-loop-guard-budget-override.sh` passes — the direct proof the `eval`ed region survived.
- `test-loop-guard-staleness.sh` passes — the hard-only detector region is intact.
- Full `run-all.sh` matches baseline.

---

### Phase 7: Acceptance Measurement and Duplication Verification [NOT STARTED]

**Goal**: Produce the measured before/after accounting the task's acceptance criteria require, and
prove mechanically that the duplication now has exactly one home.

**Tasks**:
- [ ] Re-measure every file touched across Phases 2-6 and produce a before/after byte table against
      the Phase 1 baseline.
- [ ] Compute eager-prefix + command + skill + agent accounting for both engines. For
      `/orchestrate` this is: eager prefix (generated `CLAUDE.md` + the eager `rules/*.md` set) +
      `commands/orchestrate.md` + the engine's `SKILL.md`. Both orchestrate skills are
      direct-execution, so the agent term is zero — state that explicitly rather than omitting it.
      Report the per-invocation total before and after.
- [ ] Prove single-home duplication: re-run the normalized diff between the two Stage 5 blocks and
      report the remaining identical-line count. Enumerate every remaining intentional duplicate
      (the ~13 `$handoff` jq reads, the `dispatch-seq-gate` sentinel region, the
      `budget-continuation-override` region, the named shims) with the specific test that requires
      each to stay.
- [ ] Confirm no mode lost a behavior: walk the research report's divergence enumeration
      (`skeleton`, `sorry_inventory`, `loop-guard-staleness`, both `marker-handoff-crosscheck`
      locations, detecting-site strings) and confirm each is either still inline or reachable via
      an explicit pointer the executing agent is instructed to follow.
- [ ] Confirm the `command-route-agent.sh` invocation count is still >= 3 per SKILL.md file.
- [ ] Run `deploy-headless.sh` and `verify-deploy.sh`; confirm the deploy tree matches the source
      store byte-for-byte and that no file was hand-authored under `.claude/**`.
- [ ] Run the full `run-all.sh` and confirm it matches the Phase 1 baseline with **zero test files
      modified** (`git status` on `scripts/tests/` must be clean).
- [ ] Record in the implementation summary the research report's follow-up recommendation to
      document the `skill_*` vs `orchestrate-*.sh` boundary in
      `context/architecture/orchestrate-state-machine.md` — outside this task's territory, so
      handed off rather than done.

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: full

**Scope Hypothesis**: The task asserts a 28,421-byte duplication floor. Confirm by direct
measurement of the removed duplicate bytes summed across Phases 2-6. If the measured figure falls
short, report the actual number with the locked-region bytes accounted for separately rather than
adjusting the claim — the locked regions are a known, test-mandated, documented residue, not a
failure to meet the bar.

**Files to modify**:
- `specs/055_dedupe_orchestrate_skill_bodies/summaries/01_dedupe-orchestrate-skill-bodies-summary.md` - new

**Verification**:
- The before/after table covers every file touched, with no file omitted.
- `git status agent-system/extensions/core/scripts/tests/` is clean.
- `run-all.sh` pass count >= Phase 1 baseline, fail count <= Phase 1 baseline.

---

## Testing & Validation

- [ ] `scripts/tests/run-all.sh` matches or improves on the Phase 1 baseline at every phase boundary.
- [ ] `test-handoff-dispatch-identity.sh` passes after every phase — the single most sensitive test,
      because it `eval`s SKILL.md text with a stubbed helper name.
- [ ] `test-loop-guard-budget-override.sh` passes after Phase 6 — the second `eval`ing test.
- [ ] `test-handoff-reader-parity.sh` passes after every phase touching Stage 5.
- [ ] `test-routing-resolution.sh` passes (>= 3 `command-route-agent.sh` invocations per file).
- [ ] `test-loop-guard-staleness.sh` and `test-resume-scan-nonconformance.sh` pass (hard-only
      regions untouched).
- [ ] Every new `orchestrate-*.sh` script is `bash -n` clean and runs standalone against a fixture,
      printing valid JSON.
- [ ] No file under `scripts/tests/` is modified, at all.
- [ ] No file under `.claude/**` is hand-authored; every write targets
      `agent-system/extensions/core/**`.
- [ ] No task-number reference is introduced in any file outside `specs/**`.

## Artifacts & Outputs

- `specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md` (Phase 1 manifest)
- `agent-system/extensions/core/scripts/orchestrate-stage5-gates.sh` (new)
- `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` (new)
- `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh` (new)
- `agent-system/extensions/core/scripts/skill-base.sh` (extended: four new `skill_orchestrate_*`
  functions)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (reduced)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (reduced)
- `specs/055_dedupe_orchestrate_skill_bodies/summaries/01_dedupe-orchestrate-skill-bodies-summary.md`

## Rollback/Contingency

Each phase is a separate commit against the source store, and `.claude/**` is a regenerable deploy
artifact, so rollback is `git revert` of the phase commit followed by `deploy-headless.sh`. No
migration, schema change, or data mutation is involved.

If a phase's extraction cannot satisfy a locked region — most plausibly Phase 4, where the
`dispatch_status` tail may prove to carry more loop state than the decision-JSON boundary can
express — the correct outcome is to narrow that phase's scope to the sub-blocks that do extract
cleanly, mark it `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` record naming the
specific test and anchor that blocked the rest, and carry the shortfall into Phase 7's accounting.
Do not modify a test to make an extraction fit; that violates the acceptance bar directly.
