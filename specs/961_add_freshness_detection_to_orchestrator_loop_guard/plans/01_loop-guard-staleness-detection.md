# Implementation Plan: Task #961

- **Task**: 961 - Add staleness detection to the orchestrator loop-guard resume path
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: 960 (established the sentinel-region + fixture-test pattern in the same SKILL.md; already complete)
- **Research Inputs**: specs/961_add_freshness_detection_to_orchestrator_loop_guard/reports/01_loop-guard-staleness-detection.md
- **Artifacts**: plans/01_loop-guard-staleness-detection.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The Stage 2 resume branch of `skill-orchestrate-hard/SKILL.md` adopts any syntactically valid
`.orchestrator-loop-guard` unconditionally — no freshness signal is consulted before its
`cycle_count`, `burnout_signals_this_session`, and `infra_failures` become the run's state. This
plan adds an OR-combined staleness detector (schema/version drift, plan-lineage drift, mtime-age
backstop), archives a tripped guard and its lifecycle-coupled churn-state file aside as preserved
evidence with a loud named notice, and lets the pre-existing fresh-init branch reinitialize at
cycle 0. The decision and its defense against the `session_id` objection are recorded in
`context/standards/orchestrator-runtime-files.md`. Definition of done: a stale guard is archived
(not deleted) and reinitialized at cycle 0 with a signal-naming notice; a current guard and an
ordinary cross-conversational-turn resume are untouched; a new fixture test proves all four cases;
`bash -n` clean.

### Research Integration

Findings adopted from `reports/01_loop-guard-staleness-detection.md`:
- Three OR-combined signals: `max_cycles` drift, `plan_version` drift (new guard field), mtime-age
  backstop. Each is invariant across ordinary resumes, unlike `session_id`.
- The archive-aside idiom is reused verbatim from the stray-handoff sweep in this same file:
  timestamped `mv` into `$TASK_DIR`, `ERROR:`-prefixed named notice, non-fatal fallback warning.
- `.orchestrator-churn-state.json` inherits the loop guard's verdict rather than deriving its own,
  justified by the already-documented 1:1 lifecycle coupling in the Class Table.
- The sentinel-region + fixture-test harness pattern (`resume-scan-conformance-gate` region and
  `scripts/tests/test-resume-scan-nonconformance.sh`) is the credible way to satisfy "test it
  explicitly".

**Two deliberate deviations from the report, decided during planning:**

1. **Placement, not restructuring.** The report's Recommendation 2 puts the check *inside* the
   present-and-valid branch and factors the fresh-init `jq` payload into a shared inline function
   to avoid a third duplicated call site. This plan instead places the detector **before** the
   existing `if [ -f "$loop_guard_file" ] ... else ... fi`, and has it `mv` the stale guard away.
   The pre-existing `[ -f ... ]` test then evaluates false and the existing fresh-init branch runs
   unchanged, at cycle 0, with zero edits to it. This makes the third call site never exist (so the
   payload-drift risk the report flagged evaporates rather than needing mitigation), keeps the new
   region free of any `task-lock.sh` dependency (so it is executable in a fixture harness in
   isolation), and produces a much smaller diff. The identical mechanism applies to the churn-state
   file, whose own `if [ -f "$churn_file" ]` block sits immediately below.
2. **mtime threshold pinned.** The report explicitly declined to prescribe a value. This plan picks
   `ORCHESTRATOR_LOOP_GUARD_STALE_DAYS`, default **7**, with rationale recorded in Phase 1.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context. `specs/ROADMAP.md` exists but contains no
item touching orchestrator runtime-file freshness; this task advances no tracked roadmap item.

### Scope Extension Declaration (explicit)

The task's `DECLARED FILE SCOPE` names two files. This plan extends it to **four**, both extensions
stated deliberately rather than assumed:

| File | In declared scope? | Justification |
|------|--------------------|---------------|
| `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` | Yes | The defect site |
| `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` | Yes | WORK item (1) |
| `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` | **No — extension** | The verification bar requires proving both a positive (stale -> archived + reinit at cycle 0, correct signal named) and a negative (ordinary resume NOT flagged). `bash -n` plus narrative assertion cannot demonstrate the negative at all. The directly-dependent sibling change to this same SKILL.md solved the identical "test bash embedded in markdown" problem with exactly this kind of companion script (`test-resume-scan-nonconformance.sh`); adopting it keeps the bar at the level already met in this file rather than below it. |
| `agent-system/extensions/core/manifest.json` | **No — extension** | Mechanically required by the file above, not an independent choice: `provides.scripts` enumerates every deployed script by path (it already lists 16 `tests/*.sh` entries including `tests/test-resume-scan-nonconformance.sh`). A new test script omitted from this array is never copied into a consumer's `.claude/scripts/tests/` and silently does not exist for anyone. One added array element. |

### Out-of-Scope Note (must survive into the summary)

`skill-orchestrate/SKILL.md` (base mode) carries the byte-for-byte identical unconditional-trust
shape in its own Stage 2 and is **not** changed by this task. This asymmetry must be stated
explicitly in the doc and the summary so no reader assumes base mode was silently fixed too.

## Goals & Non-Goals

**Goals**:
- Record the chosen staleness signals, their thresholds, and the anti-`session_id` defense in
  `orchestrator-runtime-files.md`, without disturbing the existing (still-correct) git-restoration
  rationale for the ephemeral/gitignored classification.
- Detect a stale loop guard on the hard-mode Stage 2 resume path via three OR-combined signals.
- On detection: preserve the guard and the churn-state file as timestamped evidence, emit a loud
  `ERROR: STALE LOOP GUARD` notice naming which signal tripped and where each file went, and let
  the existing init path produce a fresh guard at cycle 0.
- Prove the behavior — positive and negative — with an executable fixture test.

**Non-Goals**:
- Changing base-mode `skill-orchestrate/SKILL.md` (explicitly out of scope; noted, not fixed).
- Deriving an independent staleness signal for `.orchestrator-churn-state.json`.
- Changing the ephemeral/gitignored disposition of either runtime file.
- Any gate keyed on `session_id` equality (explicitly ruled out by the task description).
- Editing anything under `.claude/**` (gitignored, disposable deploy artifact).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| False positive on a legitimate long resume (the named regression risk) | H | M | Primary signals are drift-based and invariant under ordinary resume; mtime is a generous 7-day backstop only, env-overridable. Phase 4 tests a 2-day-old otherwise-current guard explicitly and asserts it is NOT flagged. |
| Guards written before this change lack `plan_version` and get spuriously flagged on first run | H | H | Missing/`"none"` on either side skips the plan-lineage check entirely — absence is never itself evidence of staleness. Same for a task in `researching`/`planning` status with no `plans/` directory yet. |
| Detector region depends on `task-lock.sh` and cannot be executed in a fixture harness | M | M | Deviation 1 above: the region only reads, decides, and `mv`s. Init stays outside the region and is reached by natural fall-through. |
| New test script never deploys because `manifest.json` was not updated | M | M | Made an explicit phase deliverable (Phase 4) with a verification step that greps the manifest, not an implicit assumption. |
| `mv` of the guard fails (permissions, read-only dir) and the stale guard is then trusted anyway | M | L | Mirror the stray-handoff sweep's non-fatal fallback: on `mv` failure emit a `WARNING:` naming the file and instructing manual removal. The subsequent `[ -f ]` test then still finds the guard — so the notice must state that the stale guard is still in place. |
| A task-number citation lands in a deliverable outside `specs/**` | M | M | All four touched files are outside `specs/**`. Cite durable anchors (`test-resume-scan-nonconformance.sh`, the `resume-scan-conformance-gate` sentinel region) never task numbers. Phase 5 runs `check-task-references.sh`. |
| Edits land in `.claude/**` and are wiped by the next deploy | H | L | Every path in this plan is `agent-system/extensions/core/**`. Phase 5 verifies no `.claude/**` file was modified. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files
(`orchestrator-runtime-files.md` vs. `skill-orchestrate-hard/SKILL.md`) and are safe to run
concurrently.

---

### Phase 1: Record the staleness decision in `orchestrator-runtime-files.md` [COMPLETED]

**Goal**: The chosen signals, their exact thresholds, the anti-`session_id` defense, and the
churn-state inheritance decision are documented as policy before any code depends on them.

**Tasks**:
- [x] Add a new subsection **after** (not replacing) `## Rationale: the freshness-gate asymmetry`,
      titled to make clear it is a second, orthogonal axis — e.g. `### Operational staleness: a
      second, orthogonal freshness axis`.
- [x] State the two-axis distinction plainly: the existing ephemeral/gitignored classification
      protects against a **git-restored** stale copy and stays correct and unchanged; this new gate
      protects against a **genuinely-present, never-git-touched** guard that is simply superseded or
      old on disk. Both hazards are live; neither subsumes the other.
- [x] Record the three OR-combined signals (any one tripping is sufficient — each is independent
      evidence the guard predates the live line of work):
      1. `guard.max_cycles != $MAX_CYCLES` (schema/version drift).
      2. `guard.plan_version != <current latest plans/*.md basename>`, evaluated **only when both
         sides are non-empty and neither is `none`**.
      3. `now - mtime(guard) > ORCHESTRATOR_LOOP_GUARD_STALE_DAYS` days (backstop).
- [x] Record the mtime default as **7 days**, with this rationale verbatim in substance: the guard
      is rewritten by the per-cycle Stage 3b update, so its mtime tracks last *cycle activity*, not
      creation. Seven days means no orchestration cycle touched it across an entire working week —
      far outside any plausible conversational-resume gap, and comfortably below the observed
      13-day failure. It is a backstop, not the primary gate: the two drift signals catch a
      superseded guard regardless of age. Name it as env-overridable
      (`ORCHESTRATOR_LOOP_GUARD_STALE_DAYS`) and note that
      `ORCHESTRATOR_SESSION_REAP_MIN`'s 4-hour default is deliberately NOT a usable anchor — it
      protects a much shorter-lived class of file.
- [x] Write the explicit anti-`session_id` defense: `session_id` is regenerated on *every*
      `/orchestrate` invocation regardless of whether any work progressed, so gating on it would
      flag every legitimate conversational resume — a 100% false-positive rate by construction, and
      directly contrary to the guard's purpose of surviving across turns. All three chosen signals
      lack that property: `MAX_CYCLES` changes only when the skill file itself is edited, the
      latest-plan basename changes only when a plan artifact is actually written, and mtime advances
      on every real cycle. None changes merely because a new invocation started.
- [x] Document the `.orchestrator-churn-state.json` decision (WORK item 4): it inherits the loop
      guard's verdict rather than deriving its own detector, justified by the Class Table rows that
      already document its 1:1 lifecycle coupling (co-created in the same Stage 2 block, co-removed
      only at full-loop termination). It has no `max_cycles`-equivalent constant, and a second
      independently-derived lineage check would be needless surface area.
- [x] Update the `.orchestrator-loop-guard` Class Table row's **Reader** cell: replace
      "unconditional trust, see Rationale" with a conditional-trust description pointing at the new
      subsection.
- [x] Update the `.orchestrator-churn-state.json` row's **Reader** cell to note it is archived aside
      under the loop guard's inherited verdict.
- [x] Correct the now-partly-false sentence in the Rationale section ("with no `session_id`
      comparison and no mtime/staleness check"): scope it explicitly to base-mode
      `skill-orchestrate/SKILL.md`, and state that hard mode now gates. Do not delete the sentence —
      base mode genuinely still has no gate and that must stay visible.
- [x] Add the timestamped archive filenames (`.stale-loop-guard-{ts}.json`,
      `.stale-churn-state-{ts}.json`) to the "Not classified here (reviewed and deliberately
      excluded)" paragraph alongside `.stray-handoff-{timestamp}.json`, for the same stated reason:
      they are preserved diagnostic evidence, not control-flow state.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — new subsection,
  two Class Table cell edits, one Rationale sentence scoped, one exclusion-paragraph addition.

**Verification**:
- The file contains `ORCHESTRATOR_LOOP_GUARD_STALE_DAYS` and the literal default `7`.
- The existing `## Rationale: the freshness-gate asymmetry` heading and its git-restoration
  paragraphs are still present and unmodified in substance.
- The doc states somewhere that base-mode `skill-orchestrate/SKILL.md` is unchanged.
- No task numbers appear anywhere in the diff (deliverable outside `specs/**`).

---

### Phase 2: Add `plan_version` to the loop-guard schema [COMPLETED]

**Goal**: The guard persists which plan version the run that wrote it last observed, so the
plan-lineage signal has something to compare against, and a mid-run plan revision never produces a
false verdict on the next resume.

**Tasks**:
- [x] Immediately after `mkdir -p "$TASK_DIR"` in Stage 2, compute the live reference value in a way
      that is safe when `plans/` does not exist yet:
      resolve the latest plan via the same `ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V |
      tail -1` idiom this file already uses elsewhere, take its `basename`, and fall back to the
      literal string `none` when empty. Assign to `current_plan_version`.
- [x] Add `"plan_version": $plan_version` (seeded from `current_plan_version`) to the fresh-init
      `jq -n` payload piped into `task-lock.sh init-marker "$loop_guard_file"`, threading it in with
      `--arg plan_version "$current_plan_version"`.
- [x] Refresh `plan_version` at the Stage 3b per-cycle guard update alongside `current_state`,
      `last_updated`, and `cycle_count`, recomputing the latest-plan basename at that point so a
      revision landing mid-run is absorbed rather than treated as drift on the next resume.
- [x] Do NOT alter the lost-init-race fallback's resume-read (it reads counters from a guard another
      writer just created with the field already present).

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes exactly **one** `jq -n` init payload writes the loop guard
(the fresh-init branch) and exactly **one** per-cycle update site sets `current_state`/
`last_updated`/`cycle_count` (Stage 3b). Confirm at implementation time by grepping
`skill-orchestrate-hard/SKILL.md` for `loop_guard_file` and classifying every hit as read, payload
write, in-place update, or `rm -f`; there are additional in-place `jq ... > .tmp && mv` update sites
later in the file (around the recovery/`last_recovered_phases_completed` logic) which are NOT
payload sites and must be left alone. If the classification finds a second payload site, add
`plan_version` there too and record the correction in the summary.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Stage 2 fresh-init
  payload; Stage 3b per-cycle update; one new `current_plan_version` assignment.

**Verification**:
- `grep -c 'plan_version' skill-orchestrate-hard/SKILL.md` returns at least 3 (compute, seed,
  refresh).
- The Stage 2 fenced block extracted and run under `bash -n` is clean.
- A hand-run of the `current_plan_version` expression against a directory with no `plans/`
  subdirectory yields `none` and exits 0 (no error output).

---

### Phase 3: Implement the staleness detector on the Stage 2 resume path [NOT STARTED]

**Goal**: A stale guard is detected, named, archived aside with its churn-state companion, and
allowed to fall through to the existing fresh-init branch — with no change to that branch.

**Tasks**:
- [ ] Insert a new sentinel-delimited region between `mkdir -p "$TASK_DIR"` (plus the
      `current_plan_version` computation from Phase 2) and the existing
      `if [ -f "$loop_guard_file" ] && jq empty ...` block. Mark it
      `# --- loop-guard-staleness:begin ---` / `# --- loop-guard-staleness:end ---`, matching the
      existing `resume-scan-conformance-gate` sentinel naming convention in this same file.
- [ ] Inside the region, guard everything on the guard file existing and being valid JSON; a missing
      or unparseable guard is a no-op here (the existing block already handles both).
- [ ] Initialize `stale_reason=""` and append a human-readable clause for each signal that trips
      (naming the signal AND both compared values, so the notice is diagnostic, not just an alarm):
      - `max_cycles` drift: guard's `.max_cycles` vs. the live `$MAX_CYCLES`.
      - `plan_version` drift: guard's `.plan_version` (defaulted `// "none"`) vs.
        `$current_plan_version` — **skipped entirely** when either side is empty or `none`.
      - mtime age: `(now - mtime) > ORCHESTRATOR_LOOP_GUARD_STALE_DAYS * 86400`, using the portable
        idiom already in this file: `stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null ||
        echo 0`. Default the env var to 7 with `${ORCHESTRATOR_LOOP_GUARD_STALE_DAYS:-7}`. Treat an
        mtime of 0 (stat failed) as NOT stale — an unreadable timestamp is not evidence.
- [ ] When `stale_reason` is non-empty, emit to stderr, matching the `STALE HANDOFF` /
      `STRAY HANDOFF` vocabulary already used in this file:
      `[hard-orchestrate] ERROR: STALE LOOP GUARD — <stale_reason>. Archived to <path> for
      inspection; reinitializing fresh guard at cycle 0.` plus a second line naming the co-archived
      churn-state path.
- [ ] Archive with `mv "$loop_guard_file" "${TASK_DIR}/.stale-loop-guard-$(date -u +%s).json"`;
      on `mv` failure emit `[hard-orchestrate] WARNING:` stating the guard is still in place and must
      be removed manually before the next cycle. Never `rm` the guard.
- [ ] Archive the churn-state file under the same verdict and same timestamp suffix
      (`.stale-churn-state-$(date -u +%s).json`), only when it exists, with the same non-fatal
      fallback. Compute the timestamp **once** into a variable so both archives share it and are
      correlatable.
- [ ] Set a `loop_guard_stale=true|false` variable in the region (unused by control flow — the `mv`
      itself drives the fall-through — but asserted on by the fixture test and useful for a future
      caller).
- [ ] Leave the existing `if [ -f "$loop_guard_file" ] ... else ... fi` and the churn-state block
      **completely unmodified**: after the archive, `[ -f ]` is false and each falls to its own
      fresh-init branch naturally, at `cycle_count=0` / `total_churn=0`.
- [ ] Add a short prose note immediately below the fenced block explaining the fall-through
      mechanism and pointing at `context/standards/orchestrator-runtime-files.md` for the policy.

**Timing**: 1.25 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the region can be placed as a self-contained block whose
only inputs are `TASK_DIR`, `loop_guard_file`, `churn_file`, `MAX_CYCLES`, and
`current_plan_version`, all of which are already bound above the insertion point. Confirm at
implementation time by extracting the region and running it under `bash -n` and then under `bash -u`
in a fixture with only those five variables set; any unbound-variable error means an undeclared
input and the input list must be corrected here rather than papered over with a default.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — one new sentinel region in
  Stage 2 plus an explanatory prose paragraph.

**Verification**:
- Both sentinel markers are present exactly once each.
- The extracted region is `bash -n` clean.
- The pre-existing `if [ -f "$loop_guard_file" ]` line and the churn-state block are byte-identical
  to before this phase (confirm via `git diff` review).
- No `rm -f "$loop_guard_file"` was added inside the new region.

---

### Phase 4: Fixture test harness + manifest declaration [NOT STARTED]

**Goal**: The verification bar's positive and negative cases are proven by an executable test, and
that test actually deploys.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh`, structurally
      modeled on `scripts/tests/test-resume-scan-nonconformance.sh`: `pass()`/`fail()`/`info()`
      helpers, `PASSED`/`FAILED` counters, exit 0 all-pass / 1 any-fail / 2 environment error,
      `mktemp -d` workdir with an `EXIT` trap, and a loud failure (not a silent skip) if either
      sentinel marker is missing.
- [ ] Resolve the SKILL.md from the **source store**
      (`$REPO_ROOT/agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`), matching
      how the sibling suite resolves its sites.
- [ ] Extract the `loop-guard-staleness` region with the same `awk` begin/end filter and assert
      `bash -n` cleanliness before running any behavioral fixture.
- [ ] Drive the extracted region in a subshell against a fixture `TASK_DIR` for each case below,
      asserting on captured stderr, on the presence/absence of the archive files, and on
      `loop_guard_stale`:

      | Case | Fixture | Expected |
      |------|---------|----------|
      | Current guard | `max_cycles` matches, `plan_version` matches latest plan, mtime now | NOT stale; guard untouched; no archive file; no `ERROR:` output |
      | Ordinary cross-turn resume (**the named regression**) | identical to above but mtime backdated 2 days, and a *different* `session_id` from the caller's | NOT stale; guard untouched — proves the `session_id` gate that was rejected is genuinely absent |
      | Version drift | `max_cycles: 5` against live `MAX_CYCLES=13` | Stale; `ERROR: STALE LOOP GUARD` naming `max_cycles`; guard moved to `.stale-loop-guard-*.json`; original path gone |
      | Plan-lineage drift | `plan_version: "01_old.md"`, `plans/` latest is `03_new.md` | Stale; notice names the plan-lineage signal and both values |
      | mtime backstop | mtime backdated 30 days, all other fields current | Stale; notice names the age signal and the threshold |
      | Old-format guard (no `plan_version`) | field absent, everything else current | NOT stale — a missing field is not evidence |
      | No `plans/` directory yet | guard current, `plans/` absent | NOT stale; region exits 0 with no stderr noise |
      | Churn co-archive | any stale case with a `.orchestrator-churn-state.json` present | Both archived, sharing the same timestamp suffix |
      | Churn absent | stale case with no churn file | Guard archived; no error, no empty churn archive created |

- [ ] Add a cycle-0 assertion at the structural level: after a stale case, assert the guard path no
      longer exists, so the unmodified `[ -f "$loop_guard_file" ]` test downstream must take the
      fresh-init branch. Document in the header that init itself is verified structurally (a grep
      that the init branch is unchanged and seeds `cycle_count: 0`) rather than by execution,
      because it depends on `task-lock.sh` — state this as an honest scope limit, mirroring how the
      sibling suite declares its own.
- [ ] Add `"tests/test-loop-guard-staleness.sh"` to `provides.scripts` in
      `agent-system/extensions/core/manifest.json`, placed to keep the `tests/` entries in their
      existing sorted position.
- [ ] `chmod +x` the new script.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: The table above asserts **nine** fixture cases. This is a hypothesis about
sufficient coverage, not a ceiling — confirm at implementation time that each of the three signals
has both a tripping and a non-tripping case and that every early-return path in the region is
reached by at least one fixture; add cases if a path is uncovered, and record any addition in the
summary.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` — new file.
- `agent-system/extensions/core/manifest.json` — one added `provides.scripts` element.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` exits 0 with every
  case reported `[PASS]`.
- `bash -n` on the new script is clean.
- The manifest parses as JSON and contains the new entry:
  `jq -e '.provides.scripts | index("tests/test-loop-guard-staleness.sh")'`.
- The script header cites durable anchors (`test-resume-scan-nonconformance.sh`, the
  `resume-scan-conformance-gate` region) and contains no task numbers.

---

### Phase 5: Full verification sweep [NOT STARTED]

**Goal**: Every gate the task's verification bar and the repo's standing rules impose is actually
run, not asserted.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` — expect
      exit 0.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` — the
      standing regression suite over the same SKILL.md; expect exit 0 (proves the new region did not
      disturb the neighbouring sentinel region).
- [ ] Extract the full Stage 2 fenced block and confirm `bash -n` clean.
- [ ] Run `bash .claude/scripts/check-task-references.sh` — expect exit 0 (all four modified files
      are outside `specs/**`).
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` — expect exit 0 (manifest/README
      cross-reference lint).
- [ ] Confirm `git status --short` shows **no** modified path under `.claude/` — every edit must be
      in `agent-system/extensions/core/**`.
- [ ] Confirm the modified-file set is exactly the four declared in the Scope Extension table; any
      fifth file is an unplanned expansion that must be justified in the summary.
- [ ] Record in the summary: the mtime default chosen and why; the two deliberate deviations from
      the research report; the two scope extensions; and the explicit statement that base-mode
      `skill-orchestrate/SKILL.md` retains the unguarded shape and was not changed.

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Files to modify**:
- None (verification only).

**Verification**:
- All six commands above exit 0.
- `git status --short` shows exactly four modified/added paths, all under
  `agent-system/extensions/core/`.

---

## Testing & Validation

- [ ] `test-loop-guard-staleness.sh` passes all nine fixture cases, exit 0.
- [ ] The "ordinary cross-conversational-turn resume" case explicitly passes — a 2-day-old guard
      with a different `session_id` and matching drift fields is NOT flagged.
- [ ] A stale guard is *archived*, never deleted: the `.stale-loop-guard-*.json` file exists and the
      original path does not.
- [ ] The stderr notice names which signal tripped and both compared values, and names the archive
      destination for both the guard and the churn state.
- [ ] `test-resume-scan-nonconformance.sh` still passes (no collateral damage in the same file).
- [ ] `bash -n` clean on the extracted region and on the new test script.
- [ ] `check-task-references.sh` and `check-extension-docs.sh` exit 0.
- [ ] No file under `.claude/**` was modified.

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (modified) — the
  staleness policy, thresholds, anti-`session_id` defense, churn-inheritance decision, updated Class
  Table cells.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (modified) — the
  `loop-guard-staleness` sentinel region, `plan_version` schema seeding and per-cycle refresh.
- `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` (new) — fixture suite.
- `agent-system/extensions/core/manifest.json` (modified) — one `provides.scripts` entry.
- `specs/961_add_freshness_detection_to_orchestrator_loop_guard/summaries/01_*-summary.md` — must
  record the mtime rationale, the two report deviations, the two scope extensions, and the base-mode
  out-of-scope note.

## Rollback/Contingency

All four files are text and every phase is committed separately, so `git revert` of the phase
commits restores prior behavior exactly — the pre-existing `if [ -f "$loop_guard_file" ]` block and
the churn-state block are deliberately left unmodified by Phase 3, so reverting the sentinel region
alone fully restores the unconditional-trust path without touching anything else. If the detector
proves too aggressive in the field before a full revert is warranted, setting
`ORCHESTRATOR_LOOP_GUARD_STALE_DAYS` to a very large value disables the mtime backstop while leaving
the two drift signals active; disabling those requires the revert. No state migration is involved —
a guard carrying the extra `plan_version` field is still read correctly by the pre-change code,
which ignores unknown fields.
