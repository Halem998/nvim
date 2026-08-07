# Research Report: Task #952

**Task**: 952 - Record detected system defects durably and wire the ready detection sites
**Started**: 2026-08-07T15:29:12Z
**Completed**: 2026-08-07T16:15:00Z
**Effort**: research
**Dependencies**: 951 (completed, prerequisite contract), 962, 988
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/**` (source store), `specs/951_*/`, `specs/events.jsonl`
- No web search required (fully internal, mechanical citation-verification task)
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Executive Summary

- All citations in the task description have drifted since the prerequisite task (951) verified
  its own numbers; **current, re-verified line numbers are given below for every site** and MUST
  replace the task description's numbers in the plan.
- The prerequisite task's deliverable (`agent-system/extensions/core/context/patterns/system-defect-discrimination.md`)
  contains the full predicate, registry, recursion-guard, and dedup rule — this report extracts
  the load-bearing specifics and cross-checks them against current file text; the plan should
  cite that document directly rather than re-deriving anything.
- `events-append.sh` and `events-schema.json` fully substantiate the substrate claims: `--cwd`
  flag exists (writes a `cwd` field into the row, does **not** redirect the write destination —
  see "Substrate mechanics" below, this is a critical nuance), `category` enum already contains
  `"deviation"`, `event_type` is an open string, `detail` is `additionalProperties: true`, and the
  append is `flock`-guarded. 904 lines currently in `specs/events.jsonl`.
- `system-defect-record.sh` does not yet exist anywhere (source store or deploy tree) — confirmed
  clean slate for Deliverable 1.
- Two of the five Class (c) hooks (`validate-plan-write.sh`, `validate-state-sync.sh`) are
  registered **only** in `root-files/settings.json` (install-only, not part of the merge-sources
  add-only mechanism) — this means no settings.json change is needed for wiring; only the hook
  scripts themselves need a recorder call added.
- `orchestrate-hard`'s multi-task handling is delegated entirely to base `skill-orchestrate`'s MT
  stages (confirmed at `skill-orchestrate-hard/SKILL.md:101-103,1470-1472`) — the multi-task
  off-schema wiring site exists exactly once, in `skill-orchestrate/SKILL.md`, not duplicated in
  hard mode.

## Context & Scope

Task 952 depends on task 951 (completed), which produced the discrimination predicate,
detection-point registry, recursion-guard rule, and dedup rule. This research task's job is: (1)
re-verify every citation in the task description and in 951's own deliverable against current
file text (all of them have drifted at least once already — 951's own document notes that its
predecessor's numbers had drifted before it even finished), (2) extract 951's four established
answers precisely enough that the implementation plan can encode them without re-deriving
anything, (3) verify the `events.jsonl` substrate claims mechanically, and (4) enumerate the exact
current call sites for all three wiring classes so the plan can dispatch phases against concrete
line numbers.

No implementation work was done in this task — per the report-format contract this is research
only. The next step is `/plan 952`.

## Findings

### The prerequisite task's four established answers (952 MUST encode these, not re-derive)

Full text lives at `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`
(the actual deliverable file — read in full during this research). Summary for the planner:

**1. The predicate**: a system defect is registered **iff both signals hold**:
- Signal A (schema violation, mechanical): one of `OFF_SCHEMA_STATUS`, `ARTIFACTS_SHAPE_MISMATCH`,
  `HANDOFF_MISLOCATED`, `META_MISSING_AFTER_NARRATION`, or `ARTIFACTS_MISSING_ON_SUCCESS` (the
  last one is a **named but not-yet-detected** instance — no current detector fires on it; task
  952's scope does not require building one, per its own scope boundary of wiring *ready* sites
  only).
- Signal B (attribution, mechanical): the violation resolves to a **named** file under
  `agent-system/extensions/**`, derived from the dispatched agent's name or the detecting site.
  **Detection without attribution must log only, never offer/create a task.**
- "A schema-conformant failure is always task work" is the load-bearing invariant — the recorder
  must never fire on a well-formed `failed`/`partial`/`blocked` outcome, however bad the
  underlying failure.

**2. The detection-point registry**, three classes (this is exactly what task 952's Deliverable 2
mirrors):
- Class (a) "loud but unactioned" — needs a recorder call beside the existing banner.
- Class (b) "computed but discarded" — `ARTIFACTS_SHAPE_MISMATCH` is the sole instance; needs a
  **consumer, not a new detector**.
- Class (c) "ephemeral" — the five `PostToolUse`/`PreToolUse` hooks; needs a recorder call added
  so detection outlives the single agent turn.
- **951 also names a fourth, distinct outcome not covered by any of the three classes**: the
  handoff-present branch of Stage 5 (`skill-orchestrate/SKILL.md`'s `else` branch) never calls
  `orchestrate-recover-outcome.sh` at all, so `evidence_reason`/`ARTIFACTS_SHAPE_MISMATCH` is
  **never computed** on that path — this is genuinely undetected, not merely unconsumed. Task 952's
  own description bounds Deliverable 2(a) to "the five sites above" (all on the recovered=true
  path), so this handoff-present-path hole is correctly **out of scope** for 952, but the plan
  should note it explicitly as a known residual gap rather than silently ignore it.

**3. The recursion guard**: extends `context/reference/orchestrator-critical-paths.json` (verified
below — read in full), reusing `self_mod_match` from `scripts/lib/file-scope-overlap.sh` (the same
predicate `orchestrate-batch-admit.sh` already uses for the self-modification hazard check).
Degraded behavior when the data file is missing/unparseable: unknown recursion status, **refuse to
record or file a task** (stricter than `orchestrate-batch-admit.sh`'s own precedent of degrading
to `null` and falling through — the recording pipeline has no safe fallback action).
`orchestrator-critical-paths.json` already carries a **binding forward reference**: "when the
recorder script (`scripts/system-defect-record.sh`) is created, its own path MUST be appended to
this same list as a fourth entry" — **this is a required edit for Deliverable 1**, not optional
polish. The file's current three-entry addition from 951 (verified present, see below) already
includes: `context/patterns/system-defect-discrimination.md`, `context/reference/orchestrator-critical-paths.json`
(self-reference), `scripts/orchestrate-recover-outcome.sh`.

**4. The dedup rule**: identity key `{defect_class}:{attributed_source_path}`. Check reads from
`specs/events.jsonl`, filtering `event_type: "system_defect"` events whose `detail.defect_key`
matches. For each match, resolve `detail.linked_task_number` against `state.json`'s
`active_projects` status:
- No prior matching event → not a duplicate.
- Prior event with `linked_task_number` whose status is **non-terminal** (per
  `state-management.md`'s terminal list: `completed`, `abandoned`, `expanded`) → duplicate, log
  only.
- Prior event with no `linked_task_number`, or a terminal one → not a duplicate (fresh occurrence
  worth recording).

### Substrate mechanics — one nuance not spelled out in the task description

`events-append.sh` resolves `PROJECT_ROOT` as `common_repo_root "$SCRIPT_DIR" 2` — i.e. **two
levels up from the script's own on-disk location**, guarded by `deploy-root-guard.sh` (which fails
loudly if invoked from the source store rather than a deployed `.claude/scripts/` or
`.opencode/scripts/` tree). This means:
- `--cwd` is written into the JSON row as a **provenance field only** (`cwd: (if $cwd == "" then
  null else $cwd end)`); it does **not** redirect where the event line is appended.
- A Class (c) hook firing in some other repo invokes **that repo's own deployed copy** of
  `.claude/hooks/*.sh` and `.claude/scripts/events-append.sh` (since `.claude/` is deployed
  per-repo), so the event naturally lands in that repo's own `specs/events.jsonl` — `--cwd` is
  needed only so the row records which absolute directory the hook actually fired from (useful
  when Claude Code's `cwd` at hook-invocation time is a subdirectory of the repo, not the repo
  root itself).
- The recorder (`system-defect-record.sh`) MUST NOT attempt to compute or pass a target
  `events.jsonl` path itself — it should simply call `events-append.sh` (relative to its own
  `SCRIPT_DIR`) and thread `--cwd "$cwd"` through unchanged from whatever it received.

`events-schema.json` (draft-07) confirms, verified by direct read:
- `category`: closed 4-value enum `["deviation", "blocker", "milestone", "success"]` — `deviation`
  already present, **zero schema revision needed**.
- `event_type`: open string, `minLength: 1`, explicitly documented as "not a closed enum".
- `detail`: `{"type": "object", "additionalProperties": true}` — `defect_key`,
  `linked_task_number`, defect class, attributed path, detecting site, dispatched agent name can
  all be added without any schema change.
- `cwd`, `cc_session_id`: both nullable, both provenance-only, matching the mechanics above.

`events-append.sh` itself (full house style to mirror in `system-defect-record.sh`):
- `set -euo pipefail`, documented usage block via heredoc, explicit exit codes (0 success, 1
  argument/validation error) in a header comment.
- `jq -c -n` construction exclusively — no string concatenation anywhere in the JSON build.
- Validates `--category` against the closed enum and `--detail-json` as parseable JSON *before*
  any write, failing loudly (exit 1) rather than writing malformed data.
- Append guarded by `flock -x 200` on `specs/.events.lock`, opened via `200> "$LOCK_FILE"`.
- `event_id` format: `evt_{timestamp_ms}_{random6}`, with a `/dev/urandom`-then-`$RANDOM` fallback
  chain for the random suffix.

`events-query.sh` provides the read side needed for the dedup check: `--event-type TYPE
--format json-array` returns matching rows as a JSON array (no `--detail-json`-field filtering
built in — the recorder must `jq`-filter the returned array client-side for
`detail.defect_key == "<key>"`). It tolerates an absent `specs/events.jsonl` (exit 0, empty
result), which matters for a repo whose events store doesn't exist yet.

`specs/events.jsonl` currently has **904 lines** (not merely "500+" as stated in the task
description — the store has grown since that number was written; both figures corroborate "live,
non-trivial substrate").

### Deliverable 2(a) — the five dead-signal consumer sites (re-verified, all task-description line numbers are stale)

`scripts/orchestrate-recover-outcome.sh` — the ARTIFACTS_SHAPE_MISMATCH computation itself:
- Header comment stating the in-file rationale quoted in the task description ("A non-empty array
  yielding no path is proof of a shape mismatch...") is at **lines 91-93** (not line 205 as the
  task description states — that line number was for the *assignment*, and even that has moved).
- The actual `evidence_reason="ARTIFACTS_SHAPE_MISMATCH"` assignment is at **line 214** (inside a
  `case "$status" in researched|planned|implemented)` block starting at line 195; the sibling
  `evidence_suspect=false` / `evidence_reason="NONE"` defaults are at lines 205-206).
- `PHASES_ZERO_ON_SUCCESS` (which "takes precedence when both signatures fire") is assigned at
  line 211.

The five consumer sites that read `evidence_reason` and currently branch **only** on
`PHASES_ZERO_ON_SUCCESS`, ignoring the sibling `ARTIFACTS_SHAPE_MISMATCH` value entirely
(re-verified by `grep -n "evidence_reason\|evidence_suspect"` against current file text — exactly
5 matches total across both files, confirming "five consumer sites, one signal, zero readers"
still holds structurally):

| # | Site | Current line | Kind | Notes |
|---|------|---------------|------|-------|
| 1 | `skills/skill-orchestrate/SKILL.md` | **658** | code | Stage 5, single-task recovered=true evidence-corroboration `if` — branches only on `evidence_reason = "PHASES_ZERO_ON_SUCCESS"` |
| 2 | `skills/skill-orchestrate/SKILL.md` | **1852** | code | Stage MT-4 mirror of #1, identical condition |
| 3 | `skills/skill-orchestrate/SKILL.md` | **2298** | prose | "Three reachable branches" specification naming branch (2)'s trigger condition |
| 4 | `skills/skill-orchestrate-hard/SKILL.md` | **1050** | code | hard-mode mirror of #1 |
| 5 | `skills/skill-orchestrate-hard/SKILL.md` | **61** | prose | Read-allowlist specification naming the same branch (2) trigger |

All five sit on the **recovered=true** path (branch (2) of the three named branches at
`skill-orchestrate/SKILL.md:2327-2329`: "(1) missing/stale-handoff recovery, (2) recovered=true
PHASES_ZERO_ON_SUCCESS corroboration, (3) handoff-present implemented/phases_total=0
corroboration"). Branch (3), the handoff-present path, never calls
`orchestrate-recover-outcome.sh` at all — confirming 951's "detection hole" finding: it is
structurally impossible for `ARTIFACTS_SHAPE_MISMATCH` to be consumed there because it is never
computed there. This is out of scope for 952 (whose Deliverable 2(a) is explicitly "the five sites
above"), but worth a one-line note in the plan so a future reader doesn't assume full coverage.

**Wiring shape at each site**: this is purely additive — add an `elif [ "$evidence_reason" =
"ARTIFACTS_SHAPE_MISMATCH" ]` (or prose-equivalent) arm beside the existing
`PHASES_ZERO_ON_SUCCESS` branch, calling the recorder non-fatally. The existing banners/comments
must not be reworded (task's own instruction).

### Deliverable 2(b) — the six "loud but unactioned" sites (re-verified)

| Site | Current line(s) | What it detects |
|------|------------------|------------------|
| Off-schema Tier C banner (single-task) | `skill-orchestrate/SKILL.md:953` (banner text), Tier C case-arm starts at **935** | `[OFF-SCHEMA DISPATCH STATUS - ...]` — `dispatch_status` outside the accept-list |
| Off-schema Tier C banner (hard mode) | `skill-orchestrate-hard/SKILL.md:1333` (banner), Tier C case-arm starts at **1315** | same, hard-mode mirror |
| Off-schema (multi-task) | `skill-orchestrate/SKILL.md:2010-2015` | prose specification, Stage MT-4 step 3's third bullet ("Any other value... → OFF-SCHEMA"). **This is prose only — there is no separate hard-mode multi-task copy**: hard mode explicitly delegates multi-task handling to base `skill-orchestrate`'s MT stages (`skill-orchestrate-hard/SKILL.md:101-103`, "Same as base `skill-orchestrate`... use base multi-task" and `:1470-1472`, "Same as base `skill-orchestrate` multi-task stages (MT-1 through MT-5)") |
| Stale-handoff gate | `skill-orchestrate/SKILL.md:561-570` (base), `skill-orchestrate-hard/SKILL.md` mirror at **~955-963** | handoff mtime predates the dispatch window |
| Stray-handoff sweep | `skill-orchestrate/SKILL.md:572-592` (base), hard-mode mirror at **~972-980ish** | `HANDOFF_MISLOCATED` — handoff written outside its task directory, moved to `.stray-handoff-{ts}.json` |
| Completion-claim gate Case 3/3 refuse | `scripts/skill-base.sh:623`, inside `skill_gate_completion_claim()` (function starts **line 592**) | already logs `handoff-writer defect suspected` verbatim; this is a **single shared function** called from all three engines (base single-task, base multi-task, hard mode) per the header comment at line 590 ("This function is the ONLY place the three-case logic may live") — **wiring this one site covers all three engines in one edit** |

**Open question for the plan** (not resolved by this research, flagged rather than answered):
`skill_gate_completion_claim()` doesn't know a specific attributed source-store file — "handoff
writer defect suspected" is intentionally non-specific about *which* handoff-writing code is at
fault, since the function has no visibility into which engine/phase called it beyond its
`log_prefix` parameter. Signal B (attribution) requires a **named** source-store file; the planner
will need to decide whether `log_prefix` (`"[orchestrate]"` / `"[hard-orchestrate]"`) is enough to
attribute to a specific file, or whether this site should record with attribution left
intentionally coarse (e.g. attributed to the calling SKILL.md itself) — consistent with Signal B's
"detection without attribution must log only" rule if no more precise attribution is available.

### Deliverable 2(c) — the five ephemeral hooks (re-verified, full file contents read)

All five exist at `agent-system/extensions/core/hooks/{validate-meta-write,validate-handoff-location,validate-no-task-references,validate-plan-write,validate-state-sync}.sh`, confirmed via `ls`.

Registration status (checked both `merge-sources/settings-hooks.json`, which is add-only and
re-applied on every deploy, and `root-files/settings.json`, which is install-only per
`source-store-deploy-boundary.md`'s deploy-mechanism note):

| Hook | Registered in | Trigger | Blocking? |
|------|----------------|---------|-----------|
| `validate-no-task-references.sh` | `merge-sources/settings-hooks.json` | `PreToolUse`, matcher `Write\|Edit` | **Yes** — exit 2 denies the write. Registered bare (no `2>/dev/null \|\| echo '{}'` wrapper — that wrapper would convert exit 2 into exit 0 per the hook's own header comment) |
| `validate-handoff-location.sh` | `merge-sources/settings-hooks.json` | `PostToolUse`, matcher `Write\|Edit` | Exit 2 (surfaces stderr as an error, doesn't prevent the already-completed write) |
| `validate-meta-write.sh` | `merge-sources/settings-hooks.json` | `PostToolUse`, matcher `Write\|Edit` | No — advisory `additionalContext` only |
| `validate-plan-write.sh` | `root-files/settings.json` only | `PostToolUse` | No — advisory |
| `validate-state-sync.sh` | `root-files/settings.json` only, wrapped in a `bash -c` conditional that only invokes it when `file_path` contains `specs/state.json` | `PostToolUse` | No — advisory |

**Implication for the plan**: because all five are already registered (across the two settings
sources), Deliverable 2(c) requires **zero settings.json changes** — only edits to the five hook
`.sh` files themselves to add a recorder call.

**Per-hook wiring notes** (from full file reads):
- `validate-meta-write.sh`: already resolves `FILE` and constructs the exact corrective message
  naming the source-store target inline (task description's claim confirmed verbatim: `"Edit the
  source store instead: agent-system/extensions/core/**..."`). Attribution (Signal B) is
  essentially done — capture `$FILE` as the attributed path.
- `validate-handoff-location.sh`: exit 2 on mismatch; the recorder call must not interfere with
  the exit-2 contract (call it before `exit 2`, non-fatally, exactly as the task instructs — `||
  echo "... (non-fatal)" >&2` pattern must not itself alter `$?` before the final `exit 2`).
- `validate-no-task-references.sh`: **`PreToolUse`, blocking, and registered bare** (no
  `2>/dev/null || echo '{}'` wrapper in its settings-hooks.json entry) — any recorder call added
  here must be *especially* careful not to introduce a nonzero exit on its own failure path, since
  this hook's own doc explicitly warns that a wrapper converting exit 2 to exit 0 "silently
  disables the block." A non-fatal recorder call added inline (not wrapped around the whole
  script) is safe as long as it doesn't touch `$?` before the two `exit 2` sites or the final
  `exit 0`.
- `validate-plan-write.sh`, `validate-state-sync.sh`: neither script currently reads `.cwd` from
  hook stdin JSON — both must add a `CWD=$(echo "$INPUT" | jq -r '.cwd // empty')`-style capture
  (mirroring the existing pattern already used in `hooks/events-log-lifecycle.sh:112-114` and
  `hooks/events-log-artifact.sh:59-76`) before they can pass `--cwd` through to the recorder.
  `validate-state-sync.sh` in particular currently does no stdin parsing at all — it hardcodes
  `STATE_FILE="specs/state.json"` relative paths, implicitly assuming cwd is the repo root; this
  is worth noting but is not something 952 needs to fix beyond adding the `--cwd` capture needed
  for the recorder call itself.

### The recursion guard's registry file (verified content)

`agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` — read in full.
Confirms 951's three additions are present exactly as documented:
`context/patterns/system-defect-discrimination.md`,
`context/reference/orchestrator-critical-paths.json` (self-reference),
`scripts/orchestrate-recover-outcome.sh`. The file's `scope_roots` are
`["agent-system/extensions/core", ".claude", ".opencode"]`. **952's Deliverable 1 must add a
fourth entry for `scripts/system-defect-record.sh`** per the binding forward reference already
recorded in the discrimination document — this is not optional.

The reusable jq predicate is `self_mod_match($cscope; $crit)` defined in
`scripts/lib/file-scope-overlap.sh:52-58` (part of the shared `FILE_SCOPE_OVERLAP_JQ_DEFS`
heredoc block, spliced into consumer jq programs — `orchestrate-batch-admit.sh` is the existing
consumer). It takes a candidate scope array and the critical-paths array and returns the first
`{path, label}` match (directory-prefix or exact match after `norm` trims trailing `/`), or `null`.
`orchestrate-batch-admit.sh`'s own degradation precedent (missing/unparseable critical-paths file
→ `self_modifying: null` on every verdict, warn loudly, fall through) is explicitly the pattern
951's document says the recursion guard **diverges from in direction** (guard refuses to
record/file rather than falling through) while keeping the same **principle** (degrade loudly,
never silently, never fail open).

## Decisions

- The plan must use the re-verified line numbers in this report, not the task description's
  numbers (all have drifted).
- The plan must treat `--cwd` as a provenance-only field, never as a write-destination redirect —
  `system-defect-record.sh` writes to its own repo's `events.jsonl` via its own `SCRIPT_DIR`-relative
  `events-append.sh`, exactly like every other caller.
- `system-defect-record.sh`'s own path must be appended to `orchestrator-critical-paths.json` as
  part of Deliverable 1, not deferred — 951's document states this as binding.
- `skill_gate_completion_claim()` in `scripts/skill-base.sh` is a single shared function; wiring
  it once (at the Case 3/3 refuse branch, line 623) covers all three engines.
- Multi-task off-schema wiring exists exactly once (base `skill-orchestrate/SKILL.md`); hard mode
  has no separate multi-task copy to wire.

## Risks & Mitigations

- **Line-number drift will happen again** between this report and implementation — the plan
  should instruct the implementer to `grep` for the anchor strings (e.g.
  `evidence_reason.*PHASES_ZERO_ON_SUCCESS`, `Tier C`, `handoff-writer defect suspected`) rather
  than trust line numbers blindly, consistent with the discipline both this report and 951's own
  document explicitly practiced.
- **`validate-no-task-references.sh`'s blocking contract is fragile** (a wrapper reintroducing
  `2>/dev/null || echo '{}'` silently disables the whole guard) — the plan must call this out as a
  specific verification step: confirm the hook is still registered bare after the edit.
- **Signal B attribution at the completion-claim gate is genuinely ambiguous** (see Deliverable
  2(b) open question above) — the plan should make an explicit decision here rather than leave it
  to the implementer to improvise, since an unattributed record must log-only per the predicate.
- **`ARTIFACTS_MISSING_ON_SUCCESS`** (951's newly-named fifth Signal A instance) has no detector
  anywhere — confirmed no code path computes it. Task 952 does not require building one (it wires
  *ready* sites only), but the recorder script's `--detail-json` schema should be built generally
  enough that a future detector for this instance doesn't require reshaping the recorder's
  interface.

## Context Extension Recommendations

None — this is a meta task producing agent-system infrastructure directly; 951's deliverable
already serves as the durable context document this work encodes.

## Appendix

### Verification commands used

```bash
grep -n "ARTIFACTS_SHAPE_MISMATCH\|evidence_reason\|PHASES_ZERO_ON_SUCCESS" \
  agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh
grep -n "evidence_reason\|evidence_suspect" \
  agent-system/extensions/core/skills/skill-orchestrate/SKILL.md \
  agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md
grep -n "Tier C\|handoff-writer defect suspected\|STALE HANDOFF\|STRAY HANDOFF" \
  agent-system/extensions/core/skills/skill-orchestrate*/SKILL.md \
  agent-system/extensions/core/scripts/skill-base.sh
grep -n "validate-plan-write\|validate-state-sync\|validate-handoff-location\|validate-meta-write\|validate-no-task-references" \
  agent-system/extensions/core/root-files/settings.json \
  agent-system/extensions/core/merge-sources/settings-hooks.json
wc -l specs/events.jsonl
```

### Files read in full during this research

- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` (951's deliverable)
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
- `agent-system/extensions/core/scripts/events-append.sh`
- `agent-system/extensions/core/scripts/events-query.sh` (header/usage)
- `agent-system/extensions/core/context/schemas/events-schema.json`
- `agent-system/extensions/core/scripts/deploy-root-guard.sh`
- `agent-system/extensions/core/scripts/lib/common.sh` (header/usage section)
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` (self_mod_match definition)
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (degradation precedent, grep-scoped)
- All five hooks in `agent-system/extensions/core/hooks/`: `validate-meta-write.sh`,
  `validate-handoff-location.sh`, `validate-no-task-references.sh`, `validate-plan-write.sh`,
  `validate-state-sync.sh`
- Relevant sections of `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and
  `skill-orchestrate-hard/SKILL.md` (Tier C branches, evidence-corroboration branches, stale/stray
  handoff sections, multi-task Stage MT-4 off-schema prose, Read-allowlist sections)
- `agent-system/extensions/core/scripts/skill-base.sh` (`skill_gate_completion_claim` function)
- `specs/951_define_system_defect_discrimination_predicate/.return-meta.json` and state.json entry
