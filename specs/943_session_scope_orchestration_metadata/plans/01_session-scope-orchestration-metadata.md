# Implementation Plan: Session-Scope Batch-Level Orchestration Metadata

- **Task**: 943 - Session-scope batch-level orchestration metadata and verify session_id on read
- **Status**: [IMPLEMENTING]
- **Effort**: 7.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/943_session_scope_orchestration_metadata/reports/01_session-scope-orchestration-metadata.md
- **Artifacts**: plans/01_session-scope-orchestration-metadata.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two repo-level orchestration runtime files (`specs/.orchestrator-multi-state.json` and
`specs/.return-meta-multi.json`) are written at fixed paths with no session component, so two
concurrent multi-task orchestrations silently overwrite each other's batch state and return
metadata. This plan adopts a `{session_id}`-suffix path scheme for both, adds **per-file
differentiated** read-time `session_id` verification, deletes the dead session-suffixed handoff
documentation, widens the tracking/gitignore machinery to match the new filename shape, and adds
an mtime-based reap path so session-scoping does not trade collisions for unbounded litter.

Done when: both singletons carry a `{session_id}` suffix at every writer and reader; the
multi-state reader hard-fails on a foreign `session_id` while the loop-guard/churn-state files
remain observational-only; `handoff-schema.md` no longer documents a nonexistent mechanism;
`check-runtime-file-tracking.sh` passes against the new names; and `/refresh` reaps abandoned
session-scoped files.

### Research Integration

Key findings carried in from the research report, in priority order:

1. **Suffix scheme, not directory scheme** (Findings §3). Live `git check-ignore` probes showed
   the suffix scheme needs one widened gitignore line and two widened script patterns, while a
   `specs/.orchestrations/{session_id}/` directory needs an entirely new gitignore entry, new
   probes, and a directory-shaped runtime-file class with no precedent in the existing flat
   Class Table.
2. **The `**/.return-meta-*.json` gitignore pattern was verified, not assumed** (Findings §3):
   `git check-ignore -v "specs/.return-meta-multi-sess_1234_abcd.json"` matches at
   `.gitignore:39`. **No gitignore change is needed for the return-meta side.** Only the
   `.orchestrator-multi-state` side needs widening.
3. **`specs/.return-meta-multi.json` is write-only today** (Findings §2) — no reader exists
   anywhere in the source store. Its path is still session-scoped for collision/audit hygiene,
   but deliverable item 2 (read-time verification) has no call site to attach to for this file.
4. **Read-time verification must be per-file, never uniform** (Findings §4). This is the single
   most important correction; the per-file table is transcribed verbatim into Phase 2 as
   acceptance criteria.
5. **The session-suffixed handoff documentation is dead** (Findings §5): every
   `HANDOFF_PATH_ABS`/`handoff_file` assignment in both orchestrate skills is the static
   `"${TASK_DIR_ABS}/.orchestrator-handoff.json"`. Recommendation is delete, not implement.
6. **`skill-orchestrate-hard/SKILL.md` has no separate multi-task path** (Findings §2) — its
   Stage 0 reuses the base MT-1..MT-5 stages verbatim. One writer/reader pair to update, not two.
7. **The `root-files/.gitignore` target in the task description is a misnomer** (Appendix).
   `root-files/` deploys into `.claude/`, which is itself wholly gitignored, so a `specs/*`
   pattern there matches nothing. The canonical documented location is
   `orchestrator-runtime-files.md`'s "Consumer Repo Setup" block, plus a hand-maintained edit to
   this repo's own root `/.gitignore`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Give `specs/.orchestrator-multi-state.json` and `specs/.return-meta-multi.json` a
  `{session_id}`-suffixed path, applied consistently at every writer and reader.
- Add read-time `session_id` verification with per-file semantics: hard-fail where the file is
  genuinely single-invocation-scoped, observational-only where cross-invocation resume is the
  designed behavior.
- Resolve the dead session-suffixed handoff documentation by deleting it.
- Keep the new paths ignored and audited: widen `check-runtime-file-tracking.sh` probes/regex,
  update `orchestrator-runtime-files.md`, update the repo root `/.gitignore`.
- Add an mtime-based reap for abandoned session-scoped files, wired into `/refresh` alongside
  the existing stale-task-lock reap.
- Prove all of the above with an isolated-temp-root test suite modeled on
  `scripts/test-task-lock-reap.sh`.

**Non-Goals**:
- No session registry. No conflict-detection changes. No change to what happens when a conflict
  is found. (Explicit scope boundary from the task description.)
- No re-isolation of per-task runtime files inside `specs/{NNN}_{SLUG}/` — they are already
  correctly isolated by task directory. Only their read-time verification behavior is in scope.
- No addition of a `session_id` field to the `.orchestrator-handoff.json` schema.
- No reader added for `.return-meta-multi-{session_id}.json`.
- No changes to `task-lock.sh` itself, or to the momentary mutex directories
  (`specs/.scope-lock/`, `specs/.commit-lock/`, `specs/.deploy-lock/`, `specs/.events.lock`) —
  their repo-level sharing is their intended function.

## Binding Constraints (apply to every phase)

- **SOURCE-STORE RULE**: every edit targets `agent-system/extensions/core/**`. Never hand-edit
  `.claude/**` — it is a gitignored, disposable deploy artifact regenerated from the source
  store. The single exception in this plan is the repo's own root `/.gitignore` (Phase 4), which
  is neither source store nor deploy artifact and is documented as a hand-maintained file.
- **DELIVERABLE RULE**: no file this task writes outside `specs/**` may cite a task number. Use
  durable anchors (script names, function names, stage names, mechanism names). This is enforced
  by the `validate-no-task-references.sh` write-time hook and
  `scripts/check-task-references.sh`.
- **LINE-NUMBER CAVEAT**: anchor every edit on symbol names and quoted strings, never on line
  numbers. Line numbers cited in this plan are navigational hints from the research pass only.
- **state.json writes**: no phase in this plan writes `specs/state.json`. If one turns out to,
  route it through `agent-system/extensions/core/scripts/state-write.sh` (the single
  mutex-guarded writer) rather than a hand-rolled tmp-and-mv.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer applies a uniform hard-fail `session_id` check to all session-bearing files, breaking multi-turn `/orchestrate` resume for the loop guard and churn state | H | H | Phase 2 transcribes the per-file table as explicit checklist items, one row per file, with hard-fail vs observational stated per row. Phase 6 adds a resume-tolerance test case. |
| Reap threshold set too aggressively, deleting a legitimately long-running batch's own state mid-run | H | M | Generous default (`ORCHESTRATOR_SESSION_REAP_MIN`, default 240 minutes) chosen because `MAX_CYCLES_MT = min(task_count * 5, 25)` cycles of full research+plan+implement can legitimately run long, and there is no PID/heartbeat liveness signal for the batch orchestrator. Phase 6 requires a "fresh, within threshold" fixture case, not just a stale one. |
| A missed reference site leaves a stale hardcoded path, so a writer and reader disagree and the batch silently reports "Multi-state file missing" | M | M | Phase 1 exit criterion is a zero-hit grep for the unsuffixed literals across the whole source store, excluding intentional historical/doc mentions which must be individually justified. |
| Gitignore widening applied to `root-files/.gitignore` instead of the repo root `/.gitignore`, silently protecting nothing | M | M | Phase 4 states both targets explicitly and requires a live `git check-ignore -v` probe as its verification, not a file-content inspection. |
| New test/reap scripts never reach the deployed `.claude/scripts/` because the loader does not re-run `copy_scripts` for already-loaded extensions | M | M | Both new scripts go in the existing flat `scripts/` directory (not a new subdirectory), and Phase 7 explicitly diffs source-store vs deployed copies and applies the documented one-off loader-primitive workaround if they did not propagate. |
| Deleting the handoff "Exception" paragraph removes context a future reader wants | L | L | The paragraph documents a mechanism with zero producers and zero consumers, and directly contradicts the "filename is static" rule two lines above it. Deletion is recorded in the plan's rationale; git history preserves the text. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4, 5 | 1 |
| 3 | 6 | 2, 4, 5 |
| 4 | 7 | 6 |

Phases within the same wave can execute in parallel. Note that Phases 1 and 2 both touch
`skills/skill-orchestrate/SKILL.md` and `commands/orchestrate.md`, which is why Phase 2 is
sequenced after Phase 1 rather than run alongside it.

---

### Phase 1: Session-scope both singleton paths [COMPLETED]

**Goal**: Both repo-level singletons carry a `{session_id}` suffix at every writer and reader,
with no unsuffixed literal remaining in any live code path.

**Tasks**:
- [x] In `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, Stage MT-1: change the
      `mt_state_file` initialization from the literal `"specs/.orchestrator-multi-state.json"` to
      `"specs/.orchestrator-multi-state-${session_id}.json"`. The `session_id` variable is already
      in scope at this stage — it arrives via the skill's own delegation args (`session_id=...`),
      populated from `batch_session_id`. Add no new plumbing. *(completed)*
- [x] In the same file, sweep Stages MT-2 through MT-5 for any further occurrence of the
      unsuffixed literal (as opposed to the `$mt_state_file` variable) and convert each to the
      variable. Anchor on the quoted string, not on line numbers. *(completed: grep confirmed
      every other reference already used the `$mt_state_file` variable)*
- [x] In the same file, Stage MT-5 step 5: change the `jq -n ... > "specs/.return-meta-multi.json"`
      redirect target to `"specs/.return-meta-multi-${session_id}.json"`. *(completed)*
- [x] In the same `jq -n` invocation, add a top-level `session_id` field to the emitted JSON
      (`--arg session_id "$session_id"` plus `"session_id": $session_id`), placed alongside the
      existing `status` key and outside the `metadata` object. Rationale: the file currently has
      no `session_id` field at all, so a future reader could not verify it even if one were added;
      this makes the payload self-describing without adding a reader. *(completed)*
- [x] In `agent-system/extensions/core/commands/orchestrate.md` Step 5: change
      `mt_state_file="specs/.orchestrator-multi-state.json"` to
      `mt_state_file="specs/.orchestrator-multi-state-${batch_session_id}.json"`.
      `batch_session_id` is generated earlier in Step 4 and is already in scope at this read
      site — no new plumbing required. *(completed)*
- [x] In the same file, update the two prose sentences in Step 4/Step 5 that name
      `specs/.orchestrator-multi-state.json` literally so the documented path matches the code.
      *(completed)*
- [x] Update the missing-file WARNING message in the `else` branch of Step 5 to name the
      session-scoped path it actually looked for, so an operator can tell *which* file was
      missing rather than only *that* one was. *(completed)*
- [x] In `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`: confirm via grep
      that it contains no independent multi-state or return-meta-multi path literal (its Stage 0
      delegates to the base MT-1..MT-5 stages). If the grep is clean, make no edit and record
      that fact in the phase notes; if a literal is found, convert it the same way. *(completed:
      `grep -n "orchestrator-multi-state\|return-meta-multi" skills/skill-orchestrate-hard/SKILL.md`
      returned zero hits — confirmed no independent literal exists; no edit made)*
- [x] Run a source-store-wide grep for the two unsuffixed literals and confirm every remaining
      hit is a documentation/standards mention scheduled for Phase 4, not a live code path.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the reference sites are exactly the four found by
research — `skill-orchestrate/SKILL.md` Stage MT-1 (multi-state init),
`skill-orchestrate/SKILL.md` Stage MT-5 step 5 (return-meta-multi write),
`commands/orchestrate.md` Step 4 prose, and `commands/orchestrate.md` Step 5 read — plus zero in
`skill-orchestrate-hard/SKILL.md`. Confirm at implementation time by running
`grep -rn "orchestrator-multi-state\|return-meta-multi" agent-system/extensions/core/` before and
after; the after-set must contain only `context/standards/orchestrator-runtime-files.md`,
`context/formats/return-metadata-file.md`, and `scripts/check-runtime-file-tracking.sh` (all
handled in Phase 4). Any additional live-code hit invalidates the hypothesis and must be
converted, not skipped.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - session-suffixed
  `mt_state_file` init; session-suffixed return-meta-multi write target; new `session_id` field in
  the return-meta-multi payload
- `agent-system/extensions/core/commands/orchestrate.md` - session-suffixed `mt_state_file` read
  path, prose path references, missing-file warning text
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - inspect only; edit only
  if an independent literal is found

**Verification**:
- `grep -rn '"specs/\.orchestrator-multi-state\.json"\|"specs/\.return-meta-multi\.json"' agent-system/extensions/core/`
  returns no hit inside a bash code fence.
- The writer's path expression and the reader's path expression are textually equivalent modulo
  the variable name (`${session_id}` vs `${batch_session_id}`), and both variables trace to the
  same generated value via the delegation arg `session_id={batch_session_id}` in Step 4.
- The Stage MT-5 `jq -n` block still emits valid JSON shape (visual review of the `--arg`/key
  pairing; the block is instruction text, not executed here).

---

### Phase 2: Per-file read-time session_id verification [COMPLETED]

**Goal**: A foreign or stale session-owned runtime file is detected rather than silently trusted,
using per-file semantics that do not break the designed multi-turn resume path.

**Tasks**:
- [x] **`specs/.orchestrator-multi-state-{session_id}.json` — HARD-FAIL.** In
      `commands/orchestrate.md` Step 5, immediately inside the existing `if [ -f "$mt_state_file" ]`
      branch and before any field extraction, read `file_session_id=$(jq -r '.session_id // ""' "$mt_state_file")`
      and compare against `$batch_session_id`. On mismatch, emit a loud error naming both values
      and take the same path as the missing-file `else` branch (do not consume the foreign file's
      counts). Rationale to record inline: Stage MT-1 has no resume-on-exists branch — every
      multi-task invocation initializes fresh — so a mismatch here can only mean a real bug (stale
      variable reuse or a wrongly resolved path), never an expected condition. *(completed: added
      `mt_state_file_valid` gate reusing the existing missing-file fallback variables in the else
      branch)*
- [x] **`specs/.return-meta-multi-{session_id}.json` — NOT APPLICABLE TODAY.** Confirm by grep
      that no reader exists anywhere in the source store. Add no check. Record the reason as a
      short note in `context/standards/orchestrator-runtime-files.md` in Phase 4 so a future
      reader-adder knows to add both the check and the reader together. Do not invent a reader.
      *(completed: no reader found, no check added, note deferred to Phase 4)*
- [x] **`.orchestrator-loop-guard` (per-task) — OBSERVATIONAL ONLY, NEVER HARD-FAIL.** In
      `skills/skill-orchestrate/SKILL.md` where the loop guard is read on resume, add an
      informational log line when the guard's stored `session_id` differs from the current
      invocation's, and update a `last_session_id` field on write. Do NOT gate, branch, or abort
      on the difference. Rationale to record inline: `SESSION_ID` is regenerated per
      `/orchestrate` invocation in `command-gate-in.sh`, while this guard is explicitly designed
      to survive across conversational turns — a strict-equality gate would break legitimate
      resumption. The real same-task concurrency guard is `task-lock.sh`'s
      acquire/heartbeat/release mutex, not `session_id` equality. *(completed: INFO log at
      resume-read, `last_session_id` written at the per-cycle Stage 3b update)*
- [x] **`.orchestrator-churn-state.json` (hard mode, per-task) — OBSERVATIONAL ONLY, NEVER
      HARD-FAIL.** Apply the identical treatment in `skills/skill-orchestrate-hard/SKILL.md`:
      informational log on change, `last_session_id` tracked on write, no gate. Same
      resume-across-turns rationale. *(completed: added `session_id` field at init (file
      previously had none), INFO log at resume-read, `last_session_id` written at both churn-update
      sites)*
- [ ] **`.drift-inspection.json` (per-task) — OPTIONAL, WARN-ONLY IF DONE.** This file currently
      has no `session_id` field at all. Adding one costs one line in the fork prompt's write
      instruction; the corresponding read-side check must be warn-only, never a gate. The
      write-then-read happens synchronously within one stage of one session, so realistic
      collision risk is near zero. Implement only if the rest of the phase lands cleanly;
      otherwise leave untouched and note it as deferred. *(deviation: deferred — explicitly
      optional per plan; the mandatory items landed cleanly but this was left untouched to keep
      the phase's blast radius to the four mandatory files)*
- [x] **`.orchestrator-handoff.json` (per-task) — OUT OF SCOPE.** Its JSON schema has no
      `session_id` key and adding one is explicitly a non-goal. Make no change here; Phase 3
      handles its dead documentation separately. *(completed: no change made, consistent with
      Phase 3)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly one hard-fail call site exists (the
`commands/orchestrate.md` Step 5 `if [ -f "$mt_state_file" ]` branch) and exactly two
observational-only call sites (loop guard, churn state). Confirm at implementation time by
grepping for every read of each file across the source store; if a second reader of the
multi-state file is found, it needs the same hard-fail check, and if a third resume-scoped file
is found, it needs the observational treatment.

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - hard-fail session mismatch check in
  Step 5
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - observational
  `last_session_id` tracking and log on the loop guard; optional `session_id` in the
  drift-inspection write instruction
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - observational
  `last_session_id` tracking and log on the churn-state file

**Verification**:
- The word "hard-fail", "abort", "exit", or any early-return construct appears in the multi-state
  check and appears in NEITHER the loop-guard nor the churn-state edits.
- Reading the loop-guard section top to bottom, a resume by a different `session_id` still
  proceeds normally, emitting only a log line.
- The multi-state mismatch branch reuses the existing missing-file fallback variables rather than
  introducing a divergent third code path.

---

### Phase 3: Delete the dead session-suffixed handoff documentation [COMPLETED]

**Goal**: `handoff-schema.md` no longer describes a handoff path mechanism that no code produces
or consumes.

**Tasks**:
- [x] In `agent-system/extensions/core/docs/architecture/handoff-schema.md`, locate the
      `### File Path` subsection and delete the `**Exception**:` paragraph, its fenced
      `handoff_path="...-${session_id}.json"` code block, and the following sentence beginning
      "The orchestrator reads its own session's file...". Anchor on the quoted strings, not line
      numbers. *(completed)*
- [x] Confirm the surviving text reads coherently: the subsection should end on the existing
      sentence "The filename is static (not timestamped). Each dispatch cycle overwrites the
      previous handoff." — which the deleted paragraph directly contradicted. *(completed: verified
      by re-read, now followed immediately by the added rationale sentence, then the next
      subsection heading)*
- [x] Optionally add one short sentence recording *why* there is no session component: per-task
      directories already isolate concurrent different-task sessions, and `task-lock.sh` already
      serializes concurrent same-task sessions via its acquire/heartbeat/release contract. Phrase
      it with those durable anchors — no task numbers. *(completed)*
- [x] Confirm by grep that no other file references the session-suffixed handoff filename shape.
      *(completed: `grep -rn 'orchestrator-handoff-\${session_id}\|orchestrator-handoff-.*session'`
      returns zero hits)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - delete the dead
  `**Exception**` paragraph and its code block

**Verification**:
- `grep -rn 'orchestrator-handoff-\${session_id}\|orchestrator-handoff-.*session' agent-system/extensions/core/`
  returns no hit.
- Diff read-through confirms every changed hunk lies inside markdown prose / a fenced example
  block, with no adjacent schema key or code path altered.
- The `Complete JSON Schema` section elsewhere in the same file is untouched (no `session_id` key
  added — that is an explicit non-goal).

---

### Phase 4: Update the tracking and gitignore machinery [COMPLETED]

**Goal**: The session-suffixed names stay gitignored and stay audited, with no pattern silently
ceasing to match.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh`, replace the
      `EPHEMERAL_PROBES` entry `"specs/.orchestrator-multi-state.json"` with a representative
      session-suffixed probe, e.g. `"specs/.orchestrator-multi-state-sess_0000000000_probe.json"`.
      *(completed)*
- [x] In the same array, ADD a representative return-meta-multi probe, e.g.
      `"specs/.return-meta-multi-sess_0000000000_probe.json"`. Research verified the existing
      `**/.return-meta-*.json` pattern already covers this shape, so this probe is regression
      coverage that locks the verified fact in place — it should pass on first run without any
      gitignore change. *(completed: live probe confirmed pass before and after the gitignore
      edit, per the Verification block below)*
- [x] In the same file's `b_patterns` array, widen `'\.orchestrator-multi-state\.json$'` to
      `'\.orchestrator-multi-state(-[^/]+)?\.json$'` so it matches both the legacy and the
      session-suffixed names. Leave `'\.return-meta-[^/]*\.json$'` unchanged — it already matches
      any suffix. *(completed)*
- [x] In this repo's own hand-maintained root `/.gitignore`, widen the line
      `**/.orchestrator-multi-state.json` to `**/.orchestrator-multi-state*.json`. Leave
      `**/.return-meta-*.json` unchanged. Note: this is the one non-source-store edit in the plan
      and is sanctioned — the root `.gitignore` is neither the source store nor a deploy artifact.
      *(completed)*
- [x] In `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`, apply
      the same widening to the `**/.orchestrator-multi-state.json` line inside the
      "Consumer Repo Setup" fenced `gitignore` block. This block is the canonical documented
      source that consumer repos copy by hand; it and the root `/.gitignore` must not drift.
      *(completed: verified line-for-line identical to root /.gitignore)*
- [x] In the same standards file's Class Table, update the
      `specs/.orchestrator-multi-state.json` row to the session-suffixed name and add a short
      note that the path carries a `{session_id}` suffix so concurrent batches do not collide.
      Update the `.return-meta-*.json` row's parenthetical example
      `specs/.return-meta-multi.json` to the suffixed form. *(completed)*
- [x] In the same standards file, add the short note deferred from Phase 2: the
      `.return-meta-multi-{session_id}.json` file has no reader today, so a future reader-adder
      must add the read-time `session_id` check together with the reader. *(completed: folded
      into the `.return-meta-*.json` Class Table row's Reader column)*
- [x] In `agent-system/extensions/core/context/formats/return-metadata-file.md`, update the two
      mentions of `specs/.return-meta-multi.json` to the session-suffixed form so the status
      vocabulary documentation names the real path. *(completed)*
- [x] Address the task description's literal `root-files/` gitignore target explicitly: verify by
      inspection that `agent-system/extensions/core/root-files/.gitignore` contains only unrelated
      hook-log/tmp patterns and deploys into `.claude/` (itself wholly gitignored at the repo
      root), so it has no bearing on repo-root tracking of `specs/*`. Make no edit there. Record
      this determination in the phase notes so it is a decision, not an omission. *(completed:
      inspected — contains only `hooks/*.log`, `logs/`, `output/`, `*.tmp`, and a commented-out
      settings.local.json line; no edit made, decision recorded here)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly two `check-runtime-file-tracking.sh` patterns and
exactly one gitignore line need widening, and that the return-meta side needs zero gitignore
change. Confirm at implementation time by running the live probes below; the return-meta probe
must pass *before* any gitignore edit, and the multi-state probe must fail before and pass after.
If the return-meta probe fails before the edit, the research finding is wrong and the pattern
needs widening too.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` - suffixed Check-A probes,
  widened Check-B regex
- `/home/benjamin/.config/nvim/.gitignore` - widened `**/.orchestrator-multi-state*.json`
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - Consumer Repo
  Setup block, Class Table rows, no-reader note
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - suffixed path mentions

**Verification**:
```bash
# Must FAIL before the root .gitignore edit, PASS after:
git check-ignore -v "specs/.orchestrator-multi-state-sess_0000000000_probe.json"
# Must PASS both before and after (locks in the verified finding):
git check-ignore -v "specs/.return-meta-multi-sess_0000000000_probe.json"
# Full audit:
bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh
```
- `check-runtime-file-tracking.sh` exits 0 with all three checks passing.
- The `gitignore` block in `orchestrator-runtime-files.md` and the repo root `/.gitignore` are
  line-for-line identical in their orchestrator-runtime section.

---

### Phase 5: Reap path for abandoned session-scoped files [COMPLETED]

**Goal**: `/refresh` sweeps stale session-scoped orchestration files, so session-scoping does not
trade collisions for unbounded litter.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/reap-session-runtime-files.sh` in the existing
      flat `scripts/` directory (NOT a new subdirectory — this sidesteps the documented
      deploy-loader gap for brand-new subdirectories). Model its structure, output shape, and
      `--dry-run` contract on `task-lock.sh`'s `reap` subcommand so `/refresh` can echo its
      output verbatim the same way it does for task locks. *(completed)*
- [x] The script sweeps two globs at the `specs/` root:
      `specs/.orchestrator-multi-state-*.json` and `specs/.return-meta-multi-*.json`. It must NOT
      recurse into `specs/{NNN}_{SLUG}/` — per-task runtime files are out of scope. *(completed)*
- [x] Staleness criterion is file mtime, matching `task-lock.sh cmd_reap`'s own fallback path.
      Record inline why this does not conflict with the "no freshness check on read" principle in
      `orchestrator-runtime-files.md`: that principle governs whether an in-flight *read* trusts
      an old file's content; reap is a distinct, explicitly-invoked *deletion* sweep that already
      uses mtime elsewhere in this codebase for the identical purpose. *(completed: recorded in
      the script's header comment)*
- [x] Introduce a dedicated env var `ORCHESTRATOR_SESSION_REAP_MIN`, default **240 minutes**.
      Do not reuse `TASK_LOCK_REAP_MIN`. Rationale to record inline: a multi-task batch runs up to
      `MAX_CYCLES_MT = min(task_count * 5, 25)` cycles, each potentially a full research + plan +
      implement dispatch per task, so the safe threshold must be materially longer than the task
      lock's own default. Note in the script header that the multi-state file's mtime advances on
      every dispatch cycle (cycle_count, current_statuses, dispatch_start_ts all rewrite it), so
      mtime is a live signal that only stops advancing once the writing invocation truly
      terminates. *(completed)*
- [x] `--dry-run` reports what would be deleted without deleting; the live run deletes and reports
      per-file detail (filename, embedded session id, age in minutes). *(completed)*
- [x] Add `### Step 4.5: Reap Stale Session-Scoped Orchestration Files` to
      `agent-system/extensions/core/skills/skill-refresh/SKILL.md`, immediately after the existing
      `### Step 4: Reap Stale Task Locks`. Use the `X.5` numbering deliberately to avoid renumbering
      Steps 5-7 and churning their existing cross-references in both `SKILL.md` and `refresh.md`.
      Mirror Step 4's dry-run/live branch structure and its "echo the script's output verbatim
      rather than summarizing it away" instruction. *(completed)*
- [x] Add a `### Stale Session-Scoped Orchestration Files` subsection to
      `agent-system/extensions/core/commands/refresh.md` under "What It Cleans", parallel to the
      existing `### Stale Task Locks` subsection and following the same reporting shape (what is
      swept, dry-run vs live, threshold source). Carry over that section's existing note that this
      cleanup runs only on explicit `/refresh` invocation, not on the hourly systemd cadence.
      *(completed)*
- [x] Make the new script executable (`chmod +x`) to match its `scripts/` siblings. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/reap-session-runtime-files.sh` - NEW: mtime-based reap
  with `--dry-run`
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` - new Step 4.5
- `agent-system/extensions/core/commands/refresh.md` - new "Stale Session-Scoped Orchestration
  Files" subsection

**Verification**:
- `bash -n agent-system/extensions/core/scripts/reap-session-runtime-files.sh` parses cleanly.
- `bash agent-system/extensions/core/scripts/reap-session-runtime-files.sh --dry-run` runs against
  the real `specs/` tree without deleting anything and without erroring on an empty match set.
- `skill-refresh/SKILL.md` Steps 5, 6, 7 retain their original numbers, and no cross-reference to
  them in `refresh.md` was changed.

---

### Phase 6: Test suite [COMPLETED]

**Goal**: The path isolation, foreign-session detection, resume tolerance, and reap threshold
behaviors are each proven by an automated test that never touches the real `specs/` tree.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/test-session-runtime-files.sh` in the existing
      flat `scripts/` directory. Model it on `scripts/test-task-lock-reap.sh`: build a throwaway
      `$TMPROOT` with `.claude/scripts/` and `specs/` fixture trees, copy the real script under
      test byte-for-byte so production code never learns it is under test, and use controlled
      epoch arithmetic for fixture mtimes instead of real sleeping. Same `pass`/`fail` counters
      and exit-0-on-all-pass contract. *(completed)*
- [x] **Case: path isolation.** Fixture two distinct `batch_session_id` values, write both
      `specs/.orchestrator-multi-state-{sidA}.json` and `specs/.orchestrator-multi-state-{sidB}.json`
      with distinct `cycle_count`/`current_statuses` content, assert both persist independently
      with their own content intact. This is a filesystem-path-isolation assertion, not a
      concurrency/locking one — the whole point of session-scoping is that no lock is needed here.
      *(completed)*
- [x] **Case: foreign-session detection.** Write
      `specs/.orchestrator-multi-state-{sidA}.json` whose *content* `session_id` is deliberately
      `{sidB}`, and assert the Step 5 read-time check rejects/flags it rather than silently
      consuming its counts. Since the check lives in a markdown instruction file rather than an
      executable script, extract the check into the test as a faithful transcription and assert
      the transcribed logic, then add a companion grep assertion that the live
      `commands/orchestrate.md` still contains the comparison against `batch_session_id`. Record
      this two-part approach in the test header so its limitation is explicit, not implied.
      *(completed)*
- [x] **Case: resume tolerance (guard against the top risk).** Assert that the loop-guard and
      churn-state instructions contain NO hard-fail construct on `session_id` mismatch — a grep
      assertion over `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md`
      confirming the mismatch handling is a log line and not a gate. This case exists specifically
      to catch a future well-meaning "make it consistent" edit that would break multi-turn resume.
      *(completed)*
- [x] **Case: reap, stale.** Fixture a session-scoped multi-state file and a return-meta-multi
      file with mtimes past `ORCHESTRATOR_SESSION_REAP_MIN`; assert `--dry-run` reports them
      without deleting, and the live run deletes them. *(completed)*
- [x] **Case: reap, fresh (must never delete).** Fixture files with recent mtimes well within the
      threshold; assert BOTH `--dry-run` and the live run leave them untouched. This case is
      mandatory, not optional — it is the direct mitigation for the "reap deletes a live batch's
      own state" risk. *(completed)*
- [x] **Case: reap, per-task files untouched.** Fixture an old-mtime
      `specs/000_probe/.orchestrator-loop-guard`; assert the reap leaves it alone (per-task files
      are out of scope for this sweep). *(completed)*
- [x] Make the test script executable and confirm it exits 0. *(completed: 6/6 cases pass, exit 0)*

**Timing**: 1.5 hours

**Depends on**: 2, 4, 5

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/test-session-runtime-files.sh` - NEW: isolated-temp-root
  suite

**Verification**:
- `bash agent-system/extensions/core/scripts/test-session-runtime-files.sh` exits 0 with every
  case reporting PASS.
- Running it twice in a row produces identical output (no leaked temp state, no dependence on the
  real `specs/` tree).
- `git status --short specs/` is unchanged after the run, proving the suite never touched the real
  tree.
- `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` still exits 0 (no regression
  in the sibling suite whose pattern was copied).

---

### Phase 7: Deploy propagation and final verification [NOT STARTED]

**Goal**: The source-store edits reach the deployed `.claude/` tree, and the full gate set passes
against the deployed copies.

**Tasks**:
- [ ] Redeploy via the standard "Load Core" / "Sync all" path so the edited files propagate from
      `agent-system/extensions/core/**` into `.claude/**`.
- [ ] Diff each modified file's source-store copy against its deployed counterpart to confirm
      propagation. Edits to already-existing files (the six SKILL.md/command/docs/standards/script
      files) are expected to propagate normally — the two documented loader gaps concern brand-new
      files only.
- [ ] Explicitly confirm the two NEW scripts landed:
      `.claude/scripts/reap-session-runtime-files.sh` and
      `.claude/scripts/test-session-runtime-files.sh`. If either did not propagate, apply the
      documented one-off workaround (a direct invocation of the loader's copy primitives), and
      record which gap was hit.
- [ ] Run `bash .claude/scripts/check-runtime-file-tracking.sh` against the deployed copy; it must
      exit 0 with Checks A, B, and C all passing.
- [ ] Run `bash .claude/scripts/test-session-runtime-files.sh` against the deployed copy; it must
      exit 0.
- [ ] Run `bash .claude/scripts/check-task-references.sh` to confirm no deliverable outside
      `specs/**` gained a task-number citation. Every rationale note added by this plan must use
      durable anchors (stage names, script names, mechanism names) instead.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` if available, to exercise the full gate set
      including the task-reference lint wired in as one of its gates.
- [ ] Final consistency read: the writer path expression, the reader path expression, the
      `check-runtime-file-tracking.sh` probes, the root `/.gitignore` pattern, the
      `orchestrator-runtime-files.md` Consumer Repo Setup block, and the reap script's globs all
      describe the same filename shape. A drift in any one of these six is the exact failure mode
      this task exists to prevent.

**Timing**: 0.75 hours

**Depends on**: 6

**Verification Tier**: full

**Files to modify**:
- None (verification-only phase; deploy writes `.claude/**` as a mechanical artifact of the
  sanctioned deploy process, which is not a hand-edit and not a source-store-rule violation)

**Verification**:
- All of `check-runtime-file-tracking.sh`, `test-session-runtime-files.sh`,
  `test-task-lock-reap.sh`, and `check-task-references.sh` exit 0 from the deployed `.claude/`
  tree.
- Both new scripts exist and are executable under `.claude/scripts/`.
- The six-way filename-shape consistency read passes.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` exits 0 with the
      session-suffixed probes for both singletons passing Check A and Check B.
- [ ] Live `git check-ignore -v` probes confirm `specs/.orchestrator-multi-state-{sid}.json` is
      ignored after the root `/.gitignore` widening, and that
      `specs/.return-meta-multi-{sid}.json` was already ignored before any edit.
- [ ] `bash agent-system/extensions/core/scripts/test-session-runtime-files.sh` exits 0 with all
      six cases passing (path isolation, foreign-session detection, resume tolerance, reap-stale,
      reap-fresh, per-task-untouched).
- [ ] `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` still exits 0.
- [ ] `bash .claude/scripts/check-task-references.sh` exits 0 — no task-number citation in any
      deliverable outside `specs/**`.
- [ ] `grep -rn "orchestrator-handoff-.*session" agent-system/extensions/core/` returns nothing.
- [ ] Manual read-through confirms the loop-guard and churn-state session handling is a log line,
      never a gate.
- [ ] `bash -n` parses cleanly on both new shell scripts.

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified) — session-suffixed
  multi-state and return-meta-multi paths, `session_id` in the return-meta-multi payload,
  observational loop-guard session tracking
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (modified) —
  observational churn-state session tracking
- `agent-system/extensions/core/commands/orchestrate.md` (modified) — session-suffixed read path,
  hard-fail session mismatch check
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (modified) — dead
  session-suffixed handoff exception deleted
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (modified) —
  Class Table rows, Consumer Repo Setup gitignore block, no-reader note
- `agent-system/extensions/core/context/formats/return-metadata-file.md` (modified) — suffixed
  path mentions
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` (modified) — suffixed
  probes, widened Check-B regex
- `agent-system/extensions/core/scripts/reap-session-runtime-files.sh` (new) — mtime-based reap
- `agent-system/extensions/core/scripts/test-session-runtime-files.sh` (new) — isolated-temp-root
  test suite
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` (modified) — Step 4.5
- `agent-system/extensions/core/commands/refresh.md` (modified) — new "What It Cleans" subsection
- `/home/benjamin/.config/nvim/.gitignore` (modified) — widened
  `**/.orchestrator-multi-state*.json`

## Rollback/Contingency

All edits are text edits to git-tracked source-store files plus two new scripts. Rollback is
`git checkout` of the modified paths and `rm` of the two new scripts, followed by a redeploy to
restore `.claude/`. No data migration is involved: both singletons are gitignored ephemeral
runtime files with no durable content, so a rollback that leaves a stale
`specs/.orchestrator-multi-state-{sid}.json` on disk is harmless — the reverted reader looks at
the unsuffixed path, finds it missing, and takes its existing "Multi-state file missing" warning
branch. Delete any leftover session-suffixed files by hand after a rollback.

Per-phase contingency: if Phase 6's foreign-session-detection case proves untestable because the
check lives in a markdown instruction file rather than an executable, fall back to the grep-based
assertion alone and record the reduced coverage explicitly in the test header rather than dropping
the case silently.
