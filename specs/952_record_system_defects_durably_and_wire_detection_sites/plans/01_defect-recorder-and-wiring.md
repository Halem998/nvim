# Implementation Plan: Task #952

- **Task**: 952 - Record detected system defects durably and wire the ready detection sites
- **Status**: [IMPLEMENTING]
- **Effort**: 11 hours
- **Dependencies**: 951 (completed, prerequisite contract), 962, 988
- **Research Inputs**: specs/952_record_system_defects_durably_and_wire_detection_sites/reports/01_recorder-and-wiring-research.md
- **Artifacts**: plans/01_defect-recorder-and-wiring.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build `scripts/system-defect-record.sh` — a thin, house-style wrapper over the existing
`events-append.sh` that turns a detected agent-system defect into a durable, deduplicated
`event_type: "system_defect"` / `category: "deviation"` row on `specs/events.jsonl` — then add
non-fatal recorder calls at the detection sites the prerequisite's registry classifies as ready.
The prerequisite's four established answers (predicate, three-class registry, recursion guard,
dedup rule) live in `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`
and are **encoded, not re-derived**. Definition of done: a malformed `artifacts` array on a
recovered dispatch produces a correctly-attributed `system_defect` row end-to-end, and a
schema-conformant `failed` outcome produces none.

**ALL edits target `/home/benjamin/.config/nvim/agent-system/extensions/**` (the source store).
No file under `.claude/**` is ever hand-authored** — `.claude/` is a gitignored, disposable deploy
artifact regenerated from the source store (`rules/source-store-deploy-boundary.md`). The one
sanctioned `.claude/` interaction in this plan is *running the deploy* so the new script becomes
executable for verification.

### Research Integration

The research report re-verified every citation in the task description (all had drifted) and
supplied the current anchors this plan uses. Load-bearing findings encoded below:

1. **`--cwd` is a provenance field only.** `events-append.sh` derives `PROJECT_ROOT` as
   `common_repo_root "$SCRIPT_DIR" 2` — two levels up from its *own on-disk location*, guarded by
   `deploy-root-guard.sh`. `--cwd` is written into the row (`cwd: (if $cwd == "" then null else
   $cwd end)`) and never redirects the write. Consequence: the recorder MUST NOT compute or pass
   an `events.jsonl` path; it calls `events-append.sh` relative to its own `SCRIPT_DIR` and
   threads `--cwd` through unchanged. A hook firing in another repo invokes *that repo's own*
   deployed `.claude/scripts/` copy and therefore writes to that repo's own store naturally.
2. **`deploy-root-guard.sh` fails loudly when invoked from the source store.** The recorder is
   therefore **not runnable from `agent-system/extensions/core/scripts/`** — every verification
   phase must run a deploy first and exercise the deployed `.claude/scripts/` copy. This is why
   Phase 3 exists as a distinct gate.
3. **Zero schema revision needed.** `events-schema.json`: `category` is a closed 4-value enum
   already containing `deviation`; `event_type` is an open string; `detail` is
   `additionalProperties: true`; `cwd`/`cc_session_id` are nullable provenance fields.
4. **`skill_gate_completion_claim()` is a single shared function** (`scripts/skill-base.sh`,
   header: "This function is the ONLY place the three-case logic may live") serving base
   single-task, base multi-task, and hard mode. Wiring it once covers all three engines.
5. **Multi-task off-schema exists exactly once** — in base `skill-orchestrate/SKILL.md`'s Stage
   MT-4 prose. Hard mode delegates multi-task handling to the base engine and has no separate copy.
6. **Zero `settings.json` changes are needed for Deliverable 2(c).** All five hooks are already
   registered — three via `merge-sources/settings-hooks.json`, two (`validate-plan-write.sh`,
   `validate-state-sync.sh`) via install-only `root-files/settings.json`. Only hook `.sh` bodies
   change.
7. **`orchestrator-critical-paths.json` carries a binding forward reference** requiring
   `scripts/system-defect-record.sh` be appended as a fourth entry when the recorder is created.
   Phase 1 discharges it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context; no ROADMAP.md consultation performed.

### Verified anchors (re-verified during planning, 2026-08-07)

Line numbers drift. **Grep for the anchor string, never trust the number.** Numbers are given
only to disambiguate which of several matches is meant.

| Anchor string to grep | File | Line at planning time |
|---|---|---|
| `evidence_reason" = "PHASES_ZERO_ON_SUCCESS"` (code branch) | `skills/skill-orchestrate/SKILL.md` | 658 (Stage 5 single-task), 1852 (Stage MT-4) |
| same (code branch) | `skills/skill-orchestrate-hard/SKILL.md` | 1050 |
| `PHASES_ZERO_ON_SUCCESS` (prose spec) | `skills/skill-orchestrate/SKILL.md` | 647, 1834, 2298 |
| `PHASES_ZERO_ON_SUCCESS` (prose spec) | `skills/skill-orchestrate-hard/SKILL.md` | 61 |
| `[OFF-SCHEMA DISPATCH STATUS` | `skills/skill-orchestrate/SKILL.md` | 953 (Tier C arm opens ~935) |
| `[OFF-SCHEMA DISPATCH STATUS` | `skills/skill-orchestrate-hard/SKILL.md` | 1333 (Tier C arm opens ~1315) |
| `→ OFF-SCHEMA` (multi-task prose) | `skills/skill-orchestrate/SKILL.md` | 2010-2015 |
| `ERROR: STALE HANDOFF` | `skills/skill-orchestrate/SKILL.md` / `-hard/SKILL.md` | 567 / 961 |
| `ERROR: STRAY HANDOFF` | `skills/skill-orchestrate/SKILL.md` / `-hard/SKILL.md` | 584 / 978 |
| `handoff-writer defect suspected` | `scripts/skill-base.sh` | 623 (in `skill_gate_completion_claim()`, opens 592) |
| `evidence_reason="ARTIFACTS_SHAPE_MISMATCH"` | `scripts/orchestrate-recover-outcome.sh` | 214 |

## Goals & Non-Goals

**Goals**:
- Deliver `agent-system/extensions/core/scripts/system-defect-record.sh` in `events-append.sh`
  house style: documented usage heredoc, explicit exit-code table in the header, `set -euo
  pipefail`, `jq -c -n` construction only, never string concatenation.
- Carry, at minimum, in `--detail-json`: the defect class, the attributed source-store path under
  `agent-system/extensions/**`, the detecting site, and the dispatched agent name.
- Enforce the prerequisite's recursion guard, degrading **loudly** (never silently, never fail
  open) when the critical-paths data file is missing or unparseable.
- Enforce the prerequisite's dedup rule on identity key `{defect_class}:{attributed_source_path}`.
- Append `scripts/system-defect-record.sh` to `orchestrator-critical-paths.json` (binding
  forward reference from the prerequisite).
- Give `ARTIFACTS_SHAPE_MISMATCH` a consumer at the sites that already read `evidence_reason`.
- Add non-fatal recorder calls at the Class (a) "loud but unactioned" sites and the five Class (c)
  hooks, **purely additively** — no existing banner is removed, weakened, or reworded.
- Prove one end-to-end path with a matched positive AND negative test.

**Non-Goals**:
- Surfacing recorded defects to the user, or creating any task from a record. Both are downstream
  work. **No `AskUserQuestion` anywhere in this task.**
- Building a detector for `ARTIFACTS_MISSING_ON_SUCCESS` (named by the prerequisite, computed
  nowhere). The recorder's interface must be general enough that a future detector needs no
  reshaping, but no detector is built here.
- Closing the handoff-present detection hole. `skill-orchestrate/SKILL.md`'s handoff-present
  branch never calls `orchestrate-recover-outcome.sh`, so `ARTIFACTS_SHAPE_MISMATCH` is never
  *computed* there — genuinely undetected, not merely unconsumed. Deliverable 2(a) is bounded to
  the recovered=true path. **Recorded here as a known residual gap so a future reader does not
  assume full coverage.**
- Any `settings.json` edit (none is needed — see Research Integration item 6).
- Any change to `events-schema.json` or `events-append.sh`.
- Any change to `errors.json` or its schema.

## Design Decisions

These resolve the open questions the research report flagged rather than leaving them to the
implementer. Each is binding; deviating requires recording why in the summary.

### D1 — The recursion guard must match a SUBSET of `critical_paths`, not the whole list

`critical_paths` already contains `skills/skill-orchestrate/SKILL.md`,
`skills/skill-orchestrate-hard/SKILL.md`, and `scripts/skill-base.sh`. Running `self_mod_match`
against the **whole** list would suppress every defect attributed to those files — the exact
opposite of the prerequisite's stated intent ("most of the Class (a) detection sites above ... are
ordinary orchestrator machinery whose defects are exactly the kind of thing this mechanism should
record normally, not exempt. The guard's scope is limited to the files that **implement the
discrimination/recording pipeline itself**").

**Decision**: add an optional boolean field `"recursion_guard": true` to exactly the four
pipeline entries in `orchestrator-critical-paths.json`:

| Path | Rationale |
|---|---|
| `context/patterns/system-defect-discrimination.md` | the contract the pipeline implements |
| `context/reference/orchestrator-critical-paths.json` | the guard's own data file (self-reference) |
| `scripts/orchestrate-recover-outcome.sh` | the pipeline's detector |
| `scripts/system-defect-record.sh` | the recorder itself (new; the sharpest instance of the rule) |

The recorder filters `.critical_paths | map(select(.recursion_guard == true))` **before** calling
`self_mod_match`. The field is additive and backward-compatible: `orchestrate-batch-admit.sh`
reads only `.path`/`.label` and ignores unknown keys, so its self-modification-hazard behavior is
unchanged. The `$schema` value `orchestrator-critical-paths-v1` stays as-is (an added optional
field is not a breaking revision); the addition is documented in the discrimination document's
recursion-guard section.

**Rejected alternative**: a sibling data file listing only the four pipeline paths — rejected for
the same DRY reason the prerequisite rejected it, and it would require hand-syncing two lists.

### D2 — Attribution at `skill_gate_completion_claim()` (the research report's open question)

The gate has no dispatched-agent parameter and its log line ("handoff-writer defect suspected") is
deliberately non-specific. Signal B requires a **named** source-store file.

**Decision**: derive attribution mechanically from the existing `log_prefix` parameter via a
fixed two-entry lookup — a mechanical transform, not judgment, exactly as Signal B requires:

| `log_prefix` | Attributed source-store path |
|---|---|
| `[orchestrate]` | `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` |
| `[hard-orchestrate]` | `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` |
| anything else | **unresolved** → recorder refuses (exit 3), gate logs the non-fatal note, gate's own return value is unchanged |

This is defensible because the handoff-write contract each engine imposes on its dispatches
genuinely lives in that engine's SKILL.md. Signal B explicitly sanctions this shape: attribution
is "derivable from the dispatched agent's name **(or, for orchestrator-internal sites, from the
detecting site itself)**".

**Rejected alternative**: add a 6th `dispatched_agent` parameter to
`skill_gate_completion_claim()`. Rejected as disproportionate — it changes a shared function's
signature at three call sites for a marginal attribution gain. **Recorded as a named follow-on**,
not done here.

**Fire only on the Case 3/3 REFUSE branch** — the line already carrying `handoff-writer defect
suspected`. Never on Case 2 (allow), never on Case 3 allow, and **never on Case 1** (phase
accounting present but incomplete): Case 1 is an ordinary incomplete-work outcome, and recording
it would violate "a schema-conformant failure is always task work."

### D3 — Signal A's instance list must be extended for three of the ready sites

Signal A is a "closed, extensible list — extending it is a future task's decision, not silently
done by a detection site." Three ready sites map to no existing instance:

| Site | Existing instance? | Resolution |
|---|---|---|
| Stale-handoff gate | none | add `HANDOFF_STALE_OR_ABSENT` |
| `validate-meta-write.sh` | none | add `SOURCE_STORE_BOUNDARY_VIOLATION` |
| `validate-no-task-references.sh` | none | add `TASK_REFERENCE_IN_DELIVERABLE` |
| `validate-plan-write.sh` | none | add `ARTIFACT_FORMAT_VIOLATION` |
| `validate-state-sync.sh` | none | add `STATE_SYNC_DIVERGENCE` |

**Decision**: extend the Signal A table in `system-defect-discrimination.md` with these five
instances **as an explicit, documented decision** (Phase 1), and validate `--defect-class` in the
recorder against the resulting ten-value enum. Silently stretching an existing instance's meaning
is forbidden — it would corrupt the `{defect_class}:{attributed_source_path}` identity key's
semantics and therefore the dedup rule.

### D4 — Attribution outcomes for the five Class (c) hooks

A hook sees the *artifact*, not always the *writer*. Signal B's "detection without attribution
must log only, never offer/create a task" is the governing rule; a `log-only` outcome is the
**predicate working as designed**, not a wiring bug.

| Hook | Attributed path derivation | Expected outcome |
|---|---|---|
| `validate-meta-write.sh` | the `FILE` it already resolves, mapped `.claude/X` → `agent-system/extensions/core/X` (or `.claude/extensions/<ext>/X` → `agent-system/extensions/<ext>/X`) | **attributable** |
| `validate-no-task-references.sh` | the offending file, when it is under `agent-system/extensions/**` or maps there via the deploy transform; otherwise (e.g. `lua/**`) unresolved | **attributable when in-scope, else log-only** |
| `validate-handoff-location.sh` | the misplaced handoff is under `specs/**`; no writer identity is available at a PostToolUse hook | **log-only** |
| `validate-plan-write.sh` | the artifact is under `specs/**`; no writer identity available | **log-only** |
| `validate-state-sync.sh` | `specs/state.json` / `specs/TODO.md`; no writer identity available | **log-only** |

The call site is added at all five regardless. The three log-only sites become live the moment a
writer-identifying signal exists — the wiring is the durable part. Phase 8 asserts both outcome
kinds explicitly so a future reader does not mistake log-only for breakage.

### D5 — Recorder session-id fallback

`events-append.sh` requires `--session`. Hook stdin carries Claude Code's native `.session_id`
(a UUID) but not an agent-system `sess_{timestamp}_{random}` id. **Decision**: `--session` is
optional on the recorder; when absent it synthesizes `sess_$(date +%s)_$(od -An -N3 -tx1
/dev/urandom | tr -d ' ')` (the codebase's portable generator, mirroring
`rules/git-workflow.md`), and threads the real Claude Code UUID through `--cc-session-id`
unchanged as the correlation key. Never invent a fake `sess_` value that could collide with a
real one — the synthesized value is freshly random.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Line numbers drift again between this plan and implementation | M | H | Every phase greps for the anchor string in the table above; line numbers are disambiguators only. Phase 0 of each wiring phase re-greps before editing. |
| A recorder call changes `$?` before `validate-no-task-references.sh`'s `exit 2`, silently disabling a blocking guard | H | M | Recorder call is `... >/dev/null 2>&1 \|\| echo "Note: ... (non-fatal)" >&2` on its own line, followed by an **explicit** `exit 2` that sets the code unconditionally. Phase 8 re-asserts the hook is still registered **bare** (no `2>/dev/null \|\| echo '{}'` wrapper) in `merge-sources/settings-hooks.json`. |
| Recursion guard suppresses ordinary orchestrator defects | H | H (if unguarded) | D1: filter on `recursion_guard: true` before `self_mod_match`. Phase 3 verifies a defect attributed to `scripts/skill-base.sh` **is** recorded while one attributed to `scripts/system-defect-record.sh` is **not**. |
| Recorder invoked from the source store fails on `deploy-root-guard.sh` and the failure is read as a code bug | M | M | Documented in the recorder header and in every verification phase: run the deploy first, exercise the `.claude/scripts/` copy. |
| An edit accidentally lands in `.claude/**` | H | M | `rules/source-store-deploy-boundary.md`; the advisory `validate-meta-write.sh` PostToolUse hook nudges. Phase 8 asserts `git status --short` shows no `.claude/` tracked change. |
| Recorder becomes fatal at a call site and breaks orchestration | H | L | Every call site uses the non-fatal `\|\| echo "Note: ... (non-fatal)" >&2` idiom. Phase 3 verifies the recorder cannot exit nonzero in a way that propagates past that guard. |
| A task-number citation leaks into a source-store deliverable | M | M | `rules/no-task-references-in-deliverables.md`; the blocking `validate-no-task-references.sh` PreToolUse hook. Phase 8 runs `.claude/scripts/check-task-references.sh`. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 7 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 8 | 4, 5, 6, 7 |

Phases within the same wave can execute in parallel. Phases 4, 5, and 6 are serialized despite
being logically independent because all three edit `skills/skill-orchestrate/SKILL.md` and
`skills/skill-orchestrate-hard/SKILL.md` — a territory conflict, not a data dependency. Phase 7
touches only `hooks/**` and is therefore safe to run alongside Phase 4.

---

### Phase 1: Extend the Signal A vocabulary and the recursion-guard registry [COMPLETED]

**Goal**: Establish the defect-class enum and the recursion-guard data the recorder will validate
against, before the recorder exists. Discharges the prerequisite's binding forward reference.

**Tasks**:
- [x] Read `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` in
      full (345 lines) — it is the contract being extended, not re-derived. *(completed)*
- [x] Extend the **Signal A — schema violation instances** table with the five new instances from
      D3: `HANDOFF_STALE_OR_ABSENT`, `SOURCE_STORE_BOUNDARY_VIOLATION`,
      `TASK_REFERENCE_IN_DELIVERABLE`, `ARTIFACT_FORMAT_VIOLATION`, `STATE_SYNC_DIVERGENCE`. Each
      row states what it is and where it is computed. Preserve the existing five rows verbatim.
      *(completed)*
- [x] Add a short subsection recording that the extension is an **explicit decision** made by
      downstream work, per the table's own "extending it is a future task's decision, not silently
      done by a detection site" clause. Do not reword the existing clause. *(completed)*
- [x] Add `"recursion_guard": true` to the three existing pipeline entries in
      `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
      (`context/patterns/system-defect-discrimination.md`,
      `context/reference/orchestrator-critical-paths.json`,
      `scripts/orchestrate-recover-outcome.sh`). Leave every other entry untouched (no field added).
      *(completed)*
- [x] Append the fourth entry `{"path": "scripts/system-defect-record.sh", "label": "system-defect
      recorder (recursion-guard self-reference)", "recursion_guard": true}` — the prerequisite's
      binding forward reference. *(completed)*
- [x] Update the discrimination document's **recursion guard rule** section to record D1: the
      guard matches the `recursion_guard: true` subset, not the whole `critical_paths` list, and
      why (naming `skill-orchestrate/SKILL.md` and `skill-base.sh` as files that must remain
      recordable). Record the "sibling file" rejected alternative already stated there — do not
      duplicate it, cross-reference it. *(completed)*
- [x] Update the discrimination document's **detection-point registry** with a site → defect-class
      mapping column so every wiring phase has one authoritative table to read from. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly two files change
(`context/patterns/system-defect-discrimination.md`,
`context/reference/orchestrator-critical-paths.json`) and that exactly three existing
`critical_paths` entries gain `recursion_guard: true`. Confirm at implementation time by re-reading
the JSON file (it had 13 entries at planning time) and by `git diff --stat` showing only those two
paths.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — Signal A
  table extension, recursion-guard subset decision, registry class mapping
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` — three
  `recursion_guard` flags + one new entry

**Verification**:
- `jq -e '.critical_paths | map(select(.recursion_guard == true)) | length == 4'
  agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
- `jq -e '.critical_paths | map(select(.path == "scripts/system-defect-record.sh")) | length == 1'` on the same file
- `jq empty` on the file parses clean
- Diff read-through confirming every changed hunk in the `.md` is additive prose/table content and
  no existing sentence was reworded
- No task-number citation introduced (both files are outside `specs/**`)

---

### Phase 2: Build `scripts/system-defect-record.sh` [COMPLETED]

**Goal**: Deliver the recorder — a house-style wrapper over `events-append.sh` implementing the
predicate's Signal B check, the recursion guard, and the dedup rule.

**Tasks**:
- [x] Read `agent-system/extensions/core/scripts/events-append.sh` in full as the house-style
      template (documented usage heredoc, exit-code header table, `set -euo pipefail`, `jq -c -n`
      only, validate-before-write). *(completed)*
- [x] Read `agent-system/extensions/core/scripts/events-query.sh` header (the dedup read side) and
      `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` (the
      `FILE_SCOPE_OVERLAP_JQ_DEFS` / `self_mod_match($cscope; $crit)` contract). *(completed)*
- [x] Create `agent-system/extensions/core/scripts/system-defect-record.sh` with this interface:
      ```
      system-defect-record.sh --defect-class CLASS --detecting-site SITE --message "..."
        (--attributed-path PATH | --dispatched-agent NAME)
        [--attributed-path PATH] [--dispatched-agent NAME] [--task N] [--session SESSION_ID]
        [--cwd PATH] [--cc-session-id VALUE] [--extra-detail-json '{...}']
      ``` *(completed)*
- [x] Validate `--defect-class` against the ten-value enum established in Phase 1, failing loudly
      (exit 1) on an unknown value — mirroring `events-append.sh`'s `--category` enum check.
      *(completed)*
- [x] Implement Signal B resolution: use `--attributed-path` when given; otherwise resolve
      `--dispatched-agent NAME` mechanically to `agent-system/extensions/<ext>/agents/<NAME>.md`
      by globbing the source store. Additionally implement the deploy→source transform
      (`.claude/X` → `agent-system/extensions/core/X`; `.claude/extensions/<ext>/X` →
      `agent-system/extensions/<ext>/X`) so callers may pass a deploy path. If nothing resolves to
      a path under `agent-system/extensions/**`, **log only and refuse to record** (exit 3) —
      Signal B's governing rule. *(completed)*
- [x] Implement the recursion guard: read `context/reference/orchestrator-critical-paths.json`,
      filter to `recursion_guard == true` (D1), splice `FILE_SCOPE_OVERLAP_JQ_DEFS` into a
      `jq -n` program, call `self_mod_match([$normalized_attributed_path]; $crit)`. Normalize the
      attributed path by stripping any leading `scope_roots` prefix before matching (registry
      entries are scope-root-relative; attributed paths are repo-relative). *(completed)*
- [x] Implement the guard's **loud degradation**: if the data file is missing or `jq empty` fails,
      emit a `[SYSTEM-DEFECT RECORDER] REFUSING: recursion status indeterminate (...)` stderr line
      and exit 2 **without recording**. Never fall through, never fail open, never silent.
      *(completed)*
- [x] Implement the dedup rule: identity key `defect_key = "{defect_class}:{attributed_source_path}"`.
      Query prior rows via `events-query.sh --event-type system_defect --format json-array`, then
      `jq`-filter client-side on `.detail.defect_key == $key` (`events-query.sh` has no
      `detail`-field filter). For each match resolve `.detail.linked_task_number` against
      `specs/state.json`'s `active_projects`:
      - no matching event → not a duplicate, record;
      - match with a `linked_task_number` whose status is non-terminal (terminal set:
        `completed`, `abandoned`, `expanded`) → duplicate, log only, exit 0 with
        `SUPPRESSED:duplicate`;
      - match with no `linked_task_number`, or a terminal one → not a duplicate, record.
      `events-query.sh` tolerates an absent `specs/events.jsonl` (exit 0, empty) — rely on that,
      do not add an existence check that could diverge. *(completed)*
- [x] Build the `--detail-json` payload with `jq -c -n` **only** (never string concatenation),
      carrying at minimum: `defect_class`, `attributed_source_path`, `detecting_site`,
      `dispatched_agent` (null when absent), `defect_key`, and `linked_task_number: null`. Merge
      `--extra-detail-json` (validated as parseable JSON first) so a future detector can extend
      the payload without reshaping this interface. *(completed)*
- [x] Call `events-append.sh` **relative to the recorder's own `SCRIPT_DIR`**, with
      `--event-type system_defect --category deviation`, threading `--cwd`, `--cc-session-id`,
      `--task`, and `--session` (D5 fallback) through unchanged. Never compute an `events.jsonl`
      path. *(completed)*
- [x] Write the header exit-code table:
      `0` recorded, or deliberately suppressed with a logged reason (stdout: the `event_id`, or
      `SUPPRESSED:<reason>`); `1` argument/validation error; `2` refused — recursion status
      indeterminate (loud degradation); `3` refused — Signal B attribution unresolvable (log only).
      *(completed)*
- [x] Add a header note: the script is **not runnable from the source store**
      (`deploy-root-guard.sh` in the `events-append.sh` it calls fails loudly there); deploy first.
      *(completed)*
- [x] `chmod +x` the file (mirror sibling scripts' mode). *(completed)*

**Timing**: 2.5 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/system-defect-record.sh` (new)

**Verification**:
- `bash -n agent-system/extensions/core/scripts/system-defect-record.sh` (syntax)
- `shellcheck` if available on PATH (non-blocking if absent)
- `grep -c 'jq -c -n' ...` returns >= 1 and a read-through confirms no JSON is built by string
  concatenation anywhere
- Header contains `set -euo pipefail`, a `usage()` heredoc, and the exit-code table
- Invoking with no arguments prints usage and exits 1
- Invoking with an unknown `--defect-class` exits 1 with a named error

---

### Phase 3: Deploy and verify the recorder standalone [COMPLETED]

**Goal**: Prove the recorder's four behavioral contracts in isolation, before any wiring depends
on them. This is the gate that makes every later phase's `|| echo ... (non-fatal)` idiom safe.

**Tasks**:
- [x] Determine and run the correct deploy invocation so
      `agent-system/extensions/core/scripts/system-defect-record.sh` lands at
      `.claude/scripts/system-defect-record.sh` and the Phase 1 registry/doc edits propagate.
      `deploy-headless.sh` exists at both `agent-system/extensions/core/scripts/deploy-headless.sh`
      and `.claude/scripts/deploy-headless.sh`; confirm which is the operator entry point before
      running. *(completed: used `bash .claude/scripts/deploy-headless.sh` (resync mode) as the
      operator entry point; also required adding `system-defect-record.sh` to
      `agent-system/extensions/core/manifest.json`'s `scripts` array — the deploy engine copies
      only manifest-declared entries, and the new script was not yet declared; see Deviations)*
- [x] Confirm the deployed copy is present and executable, and that the deployed
      `orchestrator-critical-paths.json` carries the four `recursion_guard: true` entries.
      *(completed)*
- [x] Snapshot `wc -l specs/events.jsonl` before each check (904 lines at research time) so every
      assertion below is a measured delta, not an eyeball. *(completed: 911 lines at phase-3
      execution time, not 904 — used the live count per this phase's own Scope Hypothesis)*
- [x] **Positive**: record a synthetic defect attributed to `scripts/skill-base.sh` (an ordinary
      orchestrator file, deliberately NOT recursion-guarded). Assert exactly one new line, with
      `event_type == "system_defect"`, `category == "deviation"`, and a `detail` object carrying
      `defect_class`, `attributed_source_path`, `detecting_site`, `dispatched_agent`, `defect_key`.
      *(completed; found and fixed two recorder bugs along the way — see Deviations)*
- [x] **Recursion guard suppression**: record the same class attributed to
      `scripts/system-defect-record.sh`. Assert **zero** new lines and a visible suppression
      message. *(completed)*
- [x] **Dedup**: re-record the Phase-3 positive case's exact `{defect_class}:{attributed_path}`
      pair after manually setting a `linked_task_number` on the first row pointing at a
      non-terminal `active_projects` entry. Assert zero new lines and `SUPPRESSED:duplicate`.
      Then assert the no-`linked_task_number` case DOES record a second row. *(completed)*
- [x] **Loud degradation**: temporarily move the deployed
      `context/reference/orchestrator-critical-paths.json` aside, invoke the recorder, assert exit
      2, a loud stderr refusal, and **zero** new lines. Restore the file. *(completed)*
- [x] **Signal B refusal**: invoke with an attributed path outside `agent-system/extensions/**`
      and no resolvable `--dispatched-agent`. Assert exit 3, a logged reason, zero new lines.
      *(completed)*
- [x] **Non-fatal contract**: confirm every nonzero exit above is absorbed by the
      `|| echo "Note: ... (non-fatal)" >&2` idiom under `set -euo pipefail` in a scratch harness.
      *(completed)*
- [x] Remove every synthetic row this phase appended to `specs/events.jsonl`, restoring the
      original line count, and record the before/after counts in the phase notes. *(completed:
      911 -> 913 -> 911; `git diff --stat specs/events.jsonl` shows zero diff after restore)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: `specs/events.jsonl` had 904 lines at research time. Every assertion in this
phase is a measured line-count delta against a fresh `wc -l` taken immediately before the
invocation, never against the number 904 — confirm the live count first.

**Files to modify**:
- None in the source store. `.claude/**` changes only as deploy output; `specs/events.jsonl` is
  mutated by the tests and restored. *(deviation: two source-store files were touched during this
  phase — see Phase Notes / Deviations below)*

**Verification**:
- All six behavioral checks above pass with the stated line-count deltas
- `specs/events.jsonl` line count is restored to its pre-phase value
- `git status --short` shows no unintended tracked-file modification

**Phase Notes / Deviations**:
- **`agent-system/extensions/core/manifest.json`**: the deploy engine copies only files declared
  in a manifest's `scripts`/`hooks` arrays (no glob). `system-defect-record.sh` was created in
  Phase 2 but never added to `manifest.json`'s `scripts` array, so the first deploy attempt in
  this phase silently produced no `.claude/scripts/system-defect-record.sh`. Fixed by inserting
  `"system-defect-record.sh"` in alphabetical position between `"state-write.sh"` and
  `"task-lock.sh"`. This is an in-scope correction to make Phase 2's deliverable deployable, not
  a scope expansion.
- **`agent-system/extensions/core/scripts/system-defect-record.sh`**: two bugs were found and
  fixed while exercising the standalone behavioral checks, both real defects in the Phase 2
  script (not scope creep):
  1. The scope-root-stripping normalization used `map(select($p == . or ($p | startswith(. +
     "/"))))` — inside the piped `startswith(. + "/")` argument, `.` had already been rebound to
     `$p` by the preceding `$p |`, so it never referred to the current array element. Fixed by
     capturing the element into `$r` first: `map(. as $r | select($p == $r or ($p |
     startswith($r + "/"))))`. Symptom before the fix: every attributed path normalized to the
     empty string, which coincidentally matched `self_mod_match`'s empty-string comparison
     against a guarded entry's `path`-prefix check when both sides degenerated to trivial
     strings, causing every attributed path (including ordinary, non-guarded files like
     `scripts/skill-base.sh`) to be wrongly suppressed as a false recursion-guard hit.
  2. Two `jq` invocations (`normalized_attributed_path` and `sm_hit`) omitted the `-n` flag while
     also supplying no file argument, so each call blocked on/read from the process's inherited
     stdin instead of running query-only — under the non-interactive shell here, stdin resolved
     to no documents and the substitution silently captured an empty string. Fixed by adding `-n`
     to both. Neither bug was visible from `bash -n` or the Phase 2 unit checks (missing
     arguments, unknown `--defect-class`) — both were caught only by Phase 3's live behavioral
     checks, which is exactly the gate this phase exists to provide.
  3. (Found during the dedup check, not the two above) The dedup lookup originally read
     `specs/state.json` into a bash variable and passed it via `--argjson`, which exceeded the
     shell's `ARG_MAX` on this repo's `state.json` (hundreds of historical tasks) and failed with
     `Argument list too long`. Fixed by switching to `jq -n --slurpfile state_arr "$STATE_FILE"`,
     which reads the file directly rather than via a command-line argument.

  All three fixes are corrections to Phase 2's deliverable discovered by Phase 3's own
  verification tasks, not new scope. The script was re-`bash -n`-checked and redeployed after
  each fix before its corresponding behavioral check was (re-)run.

---

### Phase 4: Wire Deliverable 2(a) — give `ARTIFACTS_SHAPE_MISMATCH` a consumer [COMPLETED]

**Goal**: The single highest-value wiring. `orchestrate-recover-outcome.sh` already computes
`ARTIFACTS_SHAPE_MISMATCH`; every consumer branches only on the sibling `PHASES_ZERO_ON_SUCCESS`
and discards it. Add the missing arm. **This needs a consumer, not a new detector** — do not
touch the computation.

**Tasks**:
- [x] Re-grep the anchors (do not trust the numbers in the table above):
      `grep -n 'evidence_reason' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
      agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` *(completed)*
- [x] At each of the **three code branches** (`skill-orchestrate/SKILL.md` Stage 5 single-task and
      Stage MT-4; `skill-orchestrate-hard/SKILL.md` Stage 5), add an `elif [ "$evidence_suspect" =
      "true" ] && [ "$evidence_reason" = "ARTIFACTS_SHAPE_MISMATCH" ]; then` arm **beside** the
      existing `PHASES_ZERO_ON_SUCCESS` `if`. Do not alter the existing condition, its body, or
      any banner text. *(completed)*
- [x] In each new arm: emit a short banner in the file's existing voice, then call the recorder
      non-fatally:
      ```bash
      bash .claude/scripts/system-defect-record.sh \
        --defect-class ARTIFACTS_SHAPE_MISMATCH \
        --detecting-site "skill-orchestrate/SKILL.md:stage-5-recovered" \
        --task "$task_number" --session "$session_id" \
        --message "recovered return-meta carried a non-empty artifacts array yielding no path" \
        ${dispatched_agent:+--dispatched-agent "$dispatched_agent"} \
        >/dev/null 2>&1 || echo "Note: system-defect recording failed (non-fatal)" >&2
      ```
      Use each site's own `log_prefix` voice (`[orchestrate]` / `[hard-orchestrate]`) for the
      banner and its own real variable names. *(completed)*
- [x] Determine whether a dispatched-agent-name variable is in scope at each branch (grep for
      `agent_name`, `AGENT_NAME`, `dispatch_agent`, `AGENT` in the enclosing stage). If one
      exists, pass `--dispatched-agent`. If none exists, pass `--attributed-path` naming the
      detecting site's own SKILL.md — Signal B explicitly sanctions attribution "from the
      detecting site itself" for orchestrator-internal sites. *(completed: no dispatched-agent
      variable is in scope at any of the three sites — Stage 5 in both engines is shared,
      stage-agnostic postflight code, and Stage MT-4's per-task loop spans three differently
      routed agent groups without tracking which one a given task_num came from; all three arms
      use `--attributed-path` naming their own detecting SKILL.md)*
- [x] Update the **four prose specification sites** that enumerate the reachable branches so the
      new arm is documented and the specs stay truthful: `skill-orchestrate/SKILL.md` (the
      "Three reachable branches" spec, the Stage-5 comment, and the Stage MT-4 precondition prose)
      and `skill-orchestrate-hard/SKILL.md` (the Read-allowlist spec). Additive only. *(completed)*
- [x] Add a one-line residual note at the "Three reachable branches" spec recording the known gap:
      branch (3), the handoff-present path, never calls `orchestrate-recover-outcome.sh`, so
      `ARTIFACTS_SHAPE_MISMATCH` is never *computed* there — out of scope here, named so a future
      reader does not assume full coverage. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly three code branches and four prose sites. Confirm
at implementation time with `grep -n 'evidence_reason\|evidence_suspect'` across both SKILL.md
files (7 matches at planning time); if the count differs, enumerate the delta before editing and
record it.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — two code arms, three prose
  sites, one residual note
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — one code arm, one prose
  site

**Verification**:
- `grep -c 'ARTIFACTS_SHAPE_MISMATCH' ` on both files returns >= the number of new arms
- Every pre-existing `PHASES_ZERO_ON_SUCCESS` condition and banner is byte-identical
  (`git diff` read-through: no deletion, no reword)
- Each new bash fence passes `bash -n` when extracted
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` is **unmodified**

---

### Phase 5: Wire Deliverable 2(b) part 1 — off-schema Tier C and the completion-claim gate [NOT STARTED]

**Goal**: Add recorder calls beside the two loudest existing banners: the off-schema Tier C arms
and the completion-claim gate's Case 3/3 refuse.

**Tasks**:
- [ ] Re-grep `[OFF-SCHEMA DISPATCH STATUS` and `handoff-writer defect suspected` before editing.
- [ ] **Tier C, single-task** (`skill-orchestrate/SKILL.md`): add a non-fatal recorder call after
      the two existing `echo` lines in the `*)` Tier C arm. `--defect-class OFF_SCHEMA_STATUS`,
      `--detecting-site "skill-orchestrate/SKILL.md:stage-5-tier-c"`. Attribute via
      `--dispatched-agent` if an agent-name variable is in scope; else `--attributed-path` naming
      this SKILL.md. **Do not touch `offschema_display`, the banner strings, `inferred_phase`, or
      the ERROR line.**
- [ ] **Tier C, hard mode** (`skill-orchestrate-hard/SKILL.md`): identical treatment at its mirror
      arm, with `--detecting-site "skill-orchestrate-hard/SKILL.md:tier-c"` and the
      `[hard-orchestrate]` voice.
- [ ] **Tier C, multi-task** (`skill-orchestrate/SKILL.md` Stage MT-4 step 3, third bullet): this
      site is **prose specification**, not a code fence. Add the recorder call as a prose
      instruction in the same specification voice, so the MT path's OFF-SCHEMA handling records
      identically to Stage 5's. There is no hard-mode multi-task copy to mirror — hard mode
      delegates MT handling to the base engine.
- [ ] **Completion-claim gate** (`scripts/skill-base.sh`, `skill_gate_completion_claim()`): add
      the recorder call immediately before the **Case 3/3 refuse** `return 1`, on the branch that
      already logs `handoff-writer defect suspected`. Use `--defect-class
      META_MISSING_AFTER_NARRATION` (the discrimination document's own registry assignment for
      this site). Resolve `--attributed-path` from `log_prefix` per D2's two-entry table; on an
      unrecognized prefix pass nothing resolvable and let the recorder refuse (exit 3), absorbed
      non-fatally.
- [ ] Add a short comment above the gate's recorder call recording D2's decision and its rejected
      alternative (6th parameter), so a future reader does not re-open the question.
- [ ] Confirm **no recorder call is added** to Case 1, Case 2, or the Case 3 allow branch. Case 1
      (phase accounting present but incomplete) is ordinary incomplete work — recording it would
      violate "a schema-conformant failure is always task work."
- [ ] Confirm the gate's `return 0` / `return 1` values are unchanged on every branch, and that
      the recorder call cannot alter them (it precedes `return 1` and is `||`-guarded).

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Tier C code arm + MT-4 prose
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Tier C code arm
- `agent-system/extensions/core/scripts/skill-base.sh` — one call in
  `skill_gate_completion_claim()`

**Verification**:
- `bash -n agent-system/extensions/core/scripts/skill-base.sh`
- Source `skill-base.sh` in a scratch shell and exercise all four gate branches: Case 2 allow
  (`return 0`), Case 1 refuse (`return 1`, **no** recorder invocation), Case 3 allow (`return 0`),
  Case 3 refuse (`return 1`, recorder invoked once). Stub the recorder with a counter script.
- Every pre-existing gate log line is byte-identical
- The `[OFF-SCHEMA DISPATCH STATUS - ...]` banner strings are byte-identical in both SKILL.md files

---

### Phase 6: Wire Deliverable 2(b) part 2 — stale-handoff gate and stray-handoff sweep [NOT STARTED]

**Goal**: Record the two handoff-integrity detections that today move evidence aside and log, but
persist nothing.

**Tasks**:
- [ ] Re-grep `ERROR: STALE HANDOFF` and `ERROR: STRAY HANDOFF` in both SKILL.md files.
- [ ] **Stale-handoff gate**, both engines: add a non-fatal recorder call after the two existing
      `echo` lines inside `if [ "$handoff_mtime" -lt "$stale_window_start" ]`. `--defect-class
      HANDOFF_STALE_OR_ABSENT` (added in Phase 1 per D3). Attribute via `--dispatched-agent` when
      an agent-name variable is in scope, else `--attributed-path` naming the detecting engine's
      own SKILL.md. **Do not alter `handoff_stale=true`, the fail-closed `9999999999` default, or
      either message.**
- [ ] **Stray-handoff sweep**, both engines: add a non-fatal recorder call inside the `if [ -e
      "$stray" ]` block, **before** the `mv`, so the record is written even if the move fails.
      `--defect-class HANDOFF_MISLOCATED` (an existing Signal A instance — no vocabulary
      extension needed). Include the stray path in `--extra-detail-json` for forensics.
      **Do not alter the `mv`, its `&&`/`||` arms, or the two-path bounded sweep list.**
- [ ] Verify the added calls do not perturb `$?` in a way that changes the `mv` chain's
      `&& echo ... || echo ...` outcome.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts four edit sites (stale + stray, times two engines).
Confirm with `grep -n 'STALE HANDOFF\|STRAY HANDOFF'` across both files (4 matches for the ERROR
lines at planning time, plus the `mv` line); if the hard-mode mirror has diverged structurally
from the base engine, enumerate the difference before editing rather than pattern-matching blindly.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`

**Verification**:
- Extracted bash fences pass `bash -n`
- Every pre-existing `STALE HANDOFF` / `STRAY HANDOFF` message is byte-identical
- The stray-sweep `mv ... && echo ... || echo ...` chain is byte-identical
- Scratch-harness test: create a stray `.orchestrator-handoff.json` at a fake repo root, run the
  sweep fence, confirm the file is still moved aside and a record is attempted

---

### Phase 7: Wire Deliverable 2(c) — the five ephemeral hooks [NOT STARTED]

**Goal**: Make hook detections outlive the single agent turn. **Preserve each hook's advisory,
non-blocking, exit-0 contract EXACTLY** — and preserve `validate-no-task-references.sh`'s blocking
exit-2 contract exactly.

**Tasks**:
- [ ] Read all five hooks in full before editing:
      `hooks/{validate-meta-write,validate-handoff-location,validate-no-task-references,validate-plan-write,validate-state-sync}.sh`.
- [ ] Determine how a hook locates a sibling script, by reading how `hooks/events-log-lifecycle.sh`
      resolves `events-append.sh`, and reuse that exact idiom for
      `.claude/scripts/system-defect-record.sh`. Do not invent a second resolution scheme.
- [ ] `validate-meta-write.sh`: capture the `FILE` it already resolves and pass it as
      `--attributed-path` (the recorder applies the deploy→source transform).
      `--defect-class SOURCE_STORE_BOUNDARY_VIOLATION`. **Keep the `additionalContext` JSON output
      and `exit 0` byte-identical**; the recorder call is added before the output, `||`-guarded.
- [ ] `validate-handoff-location.sh`: add the call **before** the existing `exit 2`, `||`-guarded,
      with an explicit `exit 2` following on its own line so the exit code is set unconditionally.
      `--defect-class HANDOFF_MISLOCATED`. Per D4 this site is expected to be **log-only**
      (attribution unresolvable) — that is correct behavior, not a bug.
- [ ] `validate-no-task-references.sh`: **highest-risk edit.** Add the call at each of the two
      `exit 2` sites, `>/dev/null 2>&1 || echo "Note: ... (non-fatal)" >&2`, each immediately
      followed by an explicit `exit 2` on its own line. `--defect-class
      TASK_REFERENCE_IN_DELIVERABLE`, `--attributed-path` = the offending file. Do **not** wrap
      the script, do **not** add a trailing `|| true` at file scope, do **not** change the
      fail-open behavior when the shared pattern library cannot be sourced, and do **not** change
      the final `exit 0`.
- [ ] `validate-plan-write.sh`: add a `CWD=$(echo "$INPUT" | jq -r '.cwd // empty')`-style capture
      (mirroring `hooks/events-log-lifecycle.sh`'s existing pattern) — the script does not read
      `.cwd` today — then add the `||`-guarded call. `--defect-class ARTIFACT_FORMAT_VIOLATION`.
      Expected **log-only** per D4. Keep advisory `exit 0` unchanged.
- [ ] `validate-state-sync.sh`: same `.cwd` capture (this script does no stdin parsing at all
      today; add only the capture needed for `--cwd`, nothing more — its relative-path
      `STATE_FILE`/`TODO_FILE` assumptions are out of scope here). `--defect-class
      STATE_SYNC_DIVERGENCE`. Expected **log-only** per D4. Keep advisory `exit 0` unchanged.
- [ ] Pass `--cc-session-id` from hook stdin's `.session_id` at every hook, and omit `--session`
      (the recorder synthesizes one per D5).
- [ ] Confirm **no `settings.json` file is touched** — all five hooks are already registered
      (three via `merge-sources/settings-hooks.json`, two via install-only
      `root-files/settings.json`).

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly five hook files change and zero settings files
change. Confirm with `git diff --name-only` at phase close: five paths under
`agent-system/extensions/core/hooks/`, and neither
`agent-system/extensions/core/merge-sources/settings-hooks.json` nor
`agent-system/extensions/core/root-files/settings.json` present.

**Files to modify**:
- `agent-system/extensions/core/hooks/validate-meta-write.sh`
- `agent-system/extensions/core/hooks/validate-handoff-location.sh`
- `agent-system/extensions/core/hooks/validate-no-task-references.sh`
- `agent-system/extensions/core/hooks/validate-plan-write.sh`
- `agent-system/extensions/core/hooks/validate-state-sync.sh`

**Verification**:
- `bash -n` on all five
- Exit-contract regression per hook, driven by synthetic stdin JSON: the three advisory hooks
  still exit 0 on both the clean and the detecting path; `validate-handoff-location.sh` still
  exits 2 on mismatch; `validate-no-task-references.sh` still exits **2** on a citation and **0**
  on clean input, **and still exits 0 (fails open) when its shared pattern library is
  unavailable**
- `git diff --name-only` contains no `settings.json` path and no `.claude/` path
- `bash .claude/scripts/check-task-references.sh` passes (these hooks are deliverables)

---

### Phase 8: End-to-end verification — matched positive and negative [NOT STARTED]

**Goal**: Prove at least one complete path from induced defect to durable, correctly-attributed
record, **and** prove that a schema-conformant failure produces no record. The negative test is as
important as the positive one.

**Tasks**:
- [ ] Re-deploy so every source-store edit from Phases 4-7 is live in `.claude/**`.
- [ ] Record `wc -l specs/events.jsonl` as the baseline before each check.
- [ ] **Positive (required)**: construct a synthetic `.return-meta.json` with a malformed
      `artifacts` array — use the bare-string form `{"status":"planned","artifacts":["some/path.md"]}`,
      which the research confirmed fires `ARTIFACTS_SHAPE_MISMATCH` via the `jq_artifact_failure`
      arm. Run `orchestrate-recover-outcome.sh` against it, confirm
      `evidence_reason == "ARTIFACTS_SHAPE_MISMATCH"`, then drive the Phase-4 consumer arm and
      assert **exactly one** new `specs/events.jsonl` line with `event_type == "system_defect"`,
      `category == "deviation"`, and a `detail.attributed_source_path` under
      `agent-system/extensions/**` matching the expected attribution.
- [ ] **Negative (required)**: construct a schema-conformant failure —
      `{"status":"failed","artifacts":[{"type":"report","path":"specs/.../x.md","summary":"..."}]}`
      — run the identical path and assert **zero** new lines. This is the "a schema-conformant
      failure is always task work" invariant; a nonzero delta here is a hard failure of the task.
- [ ] **Negative, second form**: a well-formed `partial` outcome with a well-formed non-empty
      `artifacts` array. Assert zero new lines.
- [ ] Confirm `detail.defect_key` on the positive row equals
      `{defect_class}:{attributed_source_path}` exactly, and re-running the positive case
      suppresses (per Phase 3's dedup semantics) rather than duplicating.
- [ ] Restore `specs/events.jsonl` to its pre-phase line count and record the before/after counts.
- [ ] Run the full repository gate set:
      - `bash .claude/scripts/verify-deploy.sh`
      - `bash .claude/scripts/check-task-references.sh`
      - `bash .claude/scripts/check-extension-docs.sh`
      - `bash .claude/scripts/lint/lint-agent-contracts.sh`
      - `bash .claude/scripts/lint/lint-routing-wiring.sh`
      - `bash -n` on every modified `.sh`
- [ ] Assert the source-store boundary held: `git status --short` shows changes **only** under
      `agent-system/extensions/**` (plus `specs/**` task artifacts). No tracked `.claude/**` change.
- [ ] Record the D4 attribution-outcome table's **actual** results (which hooks attributed, which
      logged only) in the implementation summary, so a future reader does not read log-only as
      breakage.
- [ ] Record the known residual gaps in the summary: the handoff-present detection hole, and
      `ARTIFACTS_MISSING_ON_SUCCESS` having no detector anywhere.

**Timing**: 1.5 hours

**Depends on**: 4, 5, 6, 7

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts "exactly one new line" (positive) and "zero new lines"
(both negatives). Each assertion is a delta against a `wc -l` taken immediately before that
specific invocation — never against a remembered number.

**Files to modify**:
- None in the source store (verification only). `specs/events.jsonl` is mutated and restored.

**Verification**:
- Positive test: delta == 1, all asserted `detail` fields present and correct
- Both negative tests: delta == 0
- Dedup re-run: delta == 0
- All six gate commands exit 0
- `git status --short` shows no `.claude/**` tracked modification

---

## Testing & Validation

- [ ] Recorder rejects an unknown `--defect-class` (exit 1) and prints usage with no arguments
- [ ] Recorder builds its JSON exclusively via `jq -c -n` (read-through confirms zero string
      concatenation)
- [ ] Recursion guard suppresses a defect attributed to `scripts/system-defect-record.sh`
- [ ] Recursion guard does **not** suppress a defect attributed to `scripts/skill-base.sh` or
      `skills/skill-orchestrate/SKILL.md` (the D1 correctness check)
- [ ] Missing/unparseable `orchestrator-critical-paths.json` → exit 2, loud stderr, zero rows
- [ ] Unresolvable Signal B attribution → exit 3, logged, zero rows
- [ ] Dedup suppresses a repeat with a non-terminal `linked_task_number`; does not suppress when
      the link is absent or terminal
- [ ] Every call site absorbs a recorder failure non-fatally under `set -euo pipefail`
- [ ] `validate-no-task-references.sh` still blocks (exit 2) and still fails open (exit 0) when
      its pattern library is unavailable
- [ ] All four advisory hooks still exit 0 on both clean and detecting paths
- [ ] End-to-end positive: exactly one correctly-attributed `system_defect` row
- [ ] End-to-end negative: zero rows for a schema-conformant `failed` and a schema-conformant
      `partial`
- [ ] No `settings.json`, `events-schema.json`, `events-append.sh`, `errors.json`, or
      `orchestrate-recover-outcome.sh` modification
- [ ] No `AskUserQuestion` invocation anywhere in the task
- [ ] No task-number citation outside `specs/**`
- [ ] Full gate set green

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/system-defect-record.sh` (new, executable)
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` (4
  `recursion_guard` flags, 1 new entry)
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` (Signal A
  extension, recursion-guard subset decision, registry class mapping)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (consumer arm, Tier C, MT-4
  prose, stale/stray, spec updates)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (consumer arm, Tier C,
  stale/stray, spec update)
- `agent-system/extensions/core/scripts/skill-base.sh` (completion-claim gate call)
- `agent-system/extensions/core/hooks/validate-meta-write.sh`
- `agent-system/extensions/core/hooks/validate-handoff-location.sh`
- `agent-system/extensions/core/hooks/validate-no-task-references.sh`
- `agent-system/extensions/core/hooks/validate-plan-write.sh`
- `agent-system/extensions/core/hooks/validate-state-sync.sh`
- `specs/952_record_system_defects_durably_and_wire_detection_sites/summaries/01_defect-recorder-and-wiring-summary.md`

## Rollback/Contingency

Every edit is additive to the source store and every change is committed per green sub-step, so
rollback is a targeted `git revert` of the offending phase commit — no coordinated multi-file
unwind is required.

- **A wiring phase destabilizes orchestration**: revert that phase's commit. The recorder and the
  registry entry (Phases 1-2) are inert without call sites, so they may safely remain.
- **The recorder itself is defective**: revert Phases 1-2 as well; nothing else depends on them.
  Because every call site is `||`-guarded, a broken recorder degrades to a stderr note, never to a
  failed dispatch — reverting is a cleanliness action, not an emergency one.
- **`validate-no-task-references.sh`'s blocking contract is compromised**: revert Phase 7 first
  and immediately; a silently-disabled blocking guard is worse than no wiring. Re-verify the
  bare (unwrapped) registration in `merge-sources/settings-hooks.json` after any revert.
- **`specs/events.jsonl` accumulates synthetic test rows**: Phases 3 and 8 each record before/after
  line counts and restore the baseline. If a restore is missed, remove the rows by `event_id`
  (each verification phase logs the ids it created).
- **A revert leaves `.claude/` stale**: re-run the deploy after any source-store revert. `.claude/`
  is regenerated wholesale and carries no state of its own.
