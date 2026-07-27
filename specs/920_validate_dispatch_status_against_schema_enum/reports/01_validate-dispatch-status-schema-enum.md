# Research Report: Task #920

**Task**: 920 - validate_dispatch_status_against_schema_enum
**Started**: 2026-07-27
**Completed**: 2026-07-27
**Effort**: medium (3-site coordinated change, plus one probable additional site discovered during research)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/skills/skill-orchestrate/SKILL.md, skill-orchestrate-hard/SKILL.md, agent-system/extensions/core/context/formats/return-metadata-file.md, agent-system/extensions/core/docs/architecture/handoff-schema.md, agent-system/extensions/core/scripts/{skill-base.sh,update-task-status.sh,reconcile-task-status.sh,orchestrate-triage-classify.sh,orchestrate-recover-outcome.sh,validate-handoff.sh,command-gate-out.sh})
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All three sites named in the task description exist verbatim as described and are confirmed
  by direct quotation below. The defect is real: `dispatch_status` is read from the handoff with
  zero validation, and the shared postflight `case` statement's `*)` arm silently no-ops for
  anything outside `researched|planned|implemented` — including `partial`, `failed`, `blocked`,
  and any genuinely off-schema value (e.g. the reproduction's `"success"`).
- The handoff-schema enum and the `.return-meta.json` enum are **the same set**, not divergent
  ones. `context/formats/return-metadata-file.md`'s status table already declares itself
  normative for `.orchestrator-handoff.json` too (by explicit cross-reference), and
  `docs/architecture/handoff-schema.md` already states this in its own `status` field
  definition. The "three distinct vocabularies" warning in that same normative file is about a
  **different** ambiguity (the word "completed"/"implemented" meaning different things in the
  skill-status vocabulary vs. state.json vocabulary vs. notification vocabulary) — it does not
  imply the handoff and return-meta status enums differ. This resolves research goal 2 cleanly.
- There is direct, live precedent in the tree for a script/skill restating a normative
  enumeration inline while citing the source table by path in a comment, and asking future
  editors to keep the two in sync — this is the established idiom, not a mechanical import
  (bash/markdown have no such import mechanism). See `scripts/command-gate-out.sh` and
  `docs/architecture/handoff-schema.md` itself for two working examples, quoted below.
- **Important scope finding**: giving `partial`/`failed`/`blocked` genuine "explicit handling"
  (i.e. an actual state.json transition, not just a distinct log line) requires touching a
  **fourth** site beyond the three named in the task — `skill_postflight_update` in
  `scripts/skill-base.sh` — because its own internal `case "$status" in researched|planned|
  implemented) ... *) ... skip` gate means it cannot currently perform a `partial`/`blocked`
  state.json transition even if SKILL.md called it with the right arguments.
  `update-task-status.sh` already has a working `postflight:partial` / `postflight:blocked`
  mapping and it is already used successfully by `reconcile-task-status.sh` for an analogous
  self-heal, so the machinery exists — it is just not reachable from `skill_postflight_update`'s
  current gate. This is flagged for the planner, not fixed here.
- `artifacts[0].type` (`report | plan | summary`) reliably identifies **which phase** produced
  the artifact (research/plan/implement), which is a legitimate signal for the "infer intended
  phase" recovery idea. It does **not** reliably distinguish success from partial within that
  phase — the schema's own worked example shows a `"summary"` artifact attached to a `"partial"`
  implementation outcome, identical in shape to a `"summary"` on an `"implemented"` outcome. Type
  inference should only ever be used to pick which `operation` token to reason about, never as a
  substitute for the (now-to-be-validated) `dispatch_status` value itself.

## Context & Scope

This is a research-only task. It verifies the defect description, quotes the three sites
verbatim, establishes the normative-table cross-reference mechanism precedent, and answers the
five stated research goals. No code was modified — all findings below are read-only
verification plus synthesis for the eventual plan.

## Findings

### 1. The three sites, quoted verbatim

**Site 1 — `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, Stage 5, the
handoff-present branch** (unvalidated read):

```bash
else
  handoff=$(cat "$handoff_file")
  dispatch_status=$(echo "$handoff" | jq -r '.status')
  dispatch_summary=$(echo "$handoff" | jq -r '.summary // ""')
  ...
  have_outcome=true
fi
```

**Site 1 — shared postflight tail, the `*)` branch** (same file, `Stage 5`):

```bash
if [ "$have_outcome" = "true" ]; then
  case "$dispatch_status" in
    researched)
      skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status"
      ;;
    planned)
      skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status"
      ;;
    implemented)
      ...
      ;;
    *)
      echo "[orchestrate] Dispatch status '$dispatch_status' — no postflight update needed"
      ;;
  esac
  ...
fi
```

**Site 2 — `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`, mirrored Stage
5** — the read is byte-identical to Site 1's handoff-present branch, and the postflight tail's
`*)` branch is:

```bash
    *)
      echo "[hard-orchestrate] Dispatch status '$dispatch_status' — no postflight update needed"
      ;;
```

(Both the read and this tail are wrapped in a comment block `<!-- BEGIN 772 Item 5B:
hard-mode-specific Stage 5 -->` / `<!-- END 772 Item 5B ... -->`, but the shape of the defect —
unvalidated read, `*)` benign no-op — is identical to base mode.)

**Site 3 — `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, Stage MT-4 step 3**
(multi-task engine), the "Other" clause:

```
3. Call `skill_postflight_update`:
   - `dispatch_status = "researched"` → ...
   - `dispatch_status = "planned"` → ...
   - `dispatch_status = "implemented"` → apply the same completion-claim verification gate ...
   - Other → no postflight update
```

This confirms the mechanism description exactly: three independently-maintained switch
statements, each with an unconditional catch-all that treats "unrecognized" identically to
"recognized non-success" (`partial`/`failed`/`blocked`) with no differentiation and no loud
signal.

### 2. The normative status table — is it actually the same enum?

`context/formats/return-metadata-file.md`'s `status` field section (verbatim):

```
This table is the **normative** status vocabulary for `.return-meta.json`,
`specs/.return-meta-multi.json`, and — by reference — `.orchestrator-handoff.json`'s `status`
field (see `docs/architecture/handoff-schema.md`, which cross-references this table rather than
restating the enumeration independently). Any writer of one of those three files should draw its
`status` value from this table rather than re-deriving or restating it elsewhere.

| Value | Description |
|-------|-------------|
| `in_progress` | Work started but not finished (early metadata, see below) |
| `researched` | Research completed successfully |
| `planned` | Plan created successfully |
| `implemented` | Implementation completed successfully |
| `partial` | Partially completed, can resume |
| `failed` | Failed, cannot resume without fix |
| `blocked` | Blocked by external dependency |
```

`docs/architecture/handoff-schema.md`'s own `status` field definition confirms the same set for
the handoff (verbatim):

```
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
```

So: **the two enums are the same set** (`researched|planned|implemented|partial|failed|
blocked` — `in_progress` is early-metadata-only and never a legal final `dispatch_status`).
There is no drift to reconcile between the handoff enum and the return-meta enum.

**The "three distinct vocabularies" section — what it actually warns about.** The same
normative file has a section titled "Three distinct vocabularies sharing the same words" that
SKILL.md's own Stage 8 comment echoes:

```
Write metadata file. `status` here is the `.return-meta.json` skill-status vocabulary defined
normatively in `context/formats/return-metadata-file.md` — it is NOT the state.json task-status
vocabulary (`current_status` above, where `"completed"` is correct); do not "correct" this value
back to `"completed"`.
```

This warns about a **different** axis of confusion: the word `"completed"`/`"implemented"`
means different things in (a) the skill-status vocabulary (`.return-meta.json` /
`.orchestrator-handoff.json`, where `"completed"` is forbidden and `"implemented"` is correct),
(b) `state.json`'s `active_projects[].status` (where `"completed"` is the correct terminal
value), and (c) the wezterm/TTS notification-status mapping (a third, unrelated vocabulary). It
is not a warning that the handoff enum and the `.return-meta.json` enum diverge from each
other — they do not. Research goal 2 is resolved: **same set, no divergence**; the warning that
exists is about a different pair of vocabularies (skill-status vs. state.json), not about the
handoff vs. return-meta status field.

### 3. Precedent for a SKILL.md/script drawing its enum from a normative table by path

Bash and Markdown have no mechanism to "import" an enumeration from another document at
runtime — a `case` statement's arms are necessarily literal strings. The established idiom in
this tree, confirmed by two live examples, is: **restate the necessary subset as literals, but
bind it to the normative source with an explicit sync comment**, so a future editor knows not to
diverge it independently.

**Example A — `docs/architecture/handoff-schema.md`** (already quoted above): restates the
six-value enum as prose bullets, then states explicitly "`context/formats/return-metadata-file.md`
is the shared, normative source for both — this field draws from that table rather than defining
a second, independently-maintained enumeration." A second instance in the same file, for the
`orchestrate-recover-outcome.sh` three-value success accept-list:

```
A recovered outcome is fail-closed: only a present, fresh (within the current dispatch window),
parseable `.return-meta.json` whose `status` is `researched`, `planned`, or `implemented` is ever
treated as a success. ... This three-value accept-list is drawn from the same normative vocabulary
in `context/formats/return-metadata-file.md` as the schema field above — it is restated here only
because it is a strict subset (the success values), not a competing enumeration.
```

**Example B — `scripts/command-gate-out.sh`** (live bash, not just docs prose):

```bash
# skill_status accept-list: the normative enumeration of these three success values is
# context/formats/return-metadata-file.md's status vocabulary for .return-meta.json — keep this
# list and that table in sync rather than letting them drift independently. This branch is live
# for operation=orchestrate (not dead code): once the skill-orchestrate writer emits
# "implemented" instead of the format's forbidden "completed", a desynced state.json correctly
# falls through this accept-list and reaches the correction below.
if [ -n "$expected_status" ] && { [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; }; then
```

**Recommendation for the fix**: the SKILL.md `case "$dispatch_status"` blocks at all three sites
(and any validation added ahead of them) should follow this exact idiom — restate the six-value
literal set (or, for the loud-failure check, the same six values as an accept-list gate before
the `case`), with a comment citing `context/formats/return-metadata-file.md` by path as the
normative source, worded like Example B's "keep this list and that table in sync." This satisfies
the binding design constraint's intent (single normative source of truth, no restating-as-a-
fourth-drift-site in the sense of *inventing a new, independent* enumeration) while being
achievable in a markdown-instruction file that has no import mechanism. A purely mechanical
"read the table from the file" is not achievable in-band for a document meant to be followed by
an LLM executing bash one block at a time (there is no generic markdown-table-to-bash-array
parser already in the tree for this purpose, and building one solely for this would itself be a
disproportionate new dependency for a fixed six-value list that changes rarely).

Also worth noting: `scripts/validate-handoff.sh` already contains a **third**, narrower example
of a hardcoded status accept-list — `valid_statuses=("implemented" "partial" "blocked")` — but
this one is intentionally a subset scoped to the H9 wrap-up contract's implement-only writer (it
does not include `researched`/`planned`/`failed` because that offline linter only ever validates
handoffs written by the hard-mode implementation agent's H9 stage, which never reports
`researched`/`planned`, and — per its own comments — was not extended to `failed`). This script
validates handoff *files* offline (a lint pass), not live `dispatch_status` branching inside the
orchestrator loop, so it is a related but structurally different consumer; it should not be
conflated with the three sites in scope, but its accept-list should also eventually cite the
same normative table if it is touched again.

### 4. What "explicit handling" for `partial`/`failed`/`blocked` should mean

The task description observes that "the surrounding state machine already handles those states
in Stage 4" — this is correct but refers to a **different vocabulary layer** than
`dispatch_status`. Stage 4's `partial`/`blocked` handlers dispatch on **`state.json`'s
`current_status`** (the task's own persisted lifecycle state, read at the *top* of each loop
iteration, before a new dispatch). Stage 5's `case "$dispatch_status"` operates on the **outcome
of the dispatch that just returned** (a value from the handoff, read *after* the Agent tool call).
These are two different reads of two different fields that happen to share vocabulary words.

Given that, a genuinely partial/failed/blocked `dispatch_status` currently produces a real,
observable defect independent of the off-schema-value defect: if a research dispatch reports
`dispatch_status = "partial"` (a fully in-schema value), the `*)` branch fires, no
`skill_postflight_update` call happens, and `state.json`'s `current_status` is left at
`"researching"` (set by the preceding `skill_preflight_update` call). On the *next* loop
iteration, Stage 3a reads `current_status = "researching"` and Stage 4's `researching` handler
fires:

```
echo "[orchestrate] WARNING: Task $task_number is currently being researched in another session."
echo "Wait for the research to complete, then run /orchestrate $task_number again."
EXIT (partial)
```

This message is actively wrong in this scenario — the research is not "currently being
researched in another session," it already finished (with a partial outcome) in *this* session.
The task is stranded at an in-flight status with no path forward except manual intervention,
which is the same class of user-facing harm the task description centers on, just triggered by
a legitimate enum value rather than an off-schema one.

**What "explicit handling" needs to accomplish, therefore**: a `dispatch_status = "partial"` (or
`"failed"`, or `"blocked"`) outcome needs to transition `state.json`'s `current_status` **out of**
the in-flight `researching`/`planning`/`implementing` state into the corresponding terminal-ish
exception state (`"partial"` or `"blocked"`), so that a subsequent loop iteration (or a later
`/orchestrate` invocation) sees a state Stage 4 already knows how to triage correctly (the
`partial` handler's continuation/blockers/neither branches, or the `blocked` handler's
escalation), rather than a stale in-flight marker that produces a misleading "wait for it to
finish" message.

**This is reachable with existing machinery, but not from the three sites alone.**
`scripts/update-task-status.sh` already has working mappings for exactly this:

```bash
# partial/blocked are postflight-only task-level termini (state-management.md's permissive
# transition model admits them from [IMPLEMENTING] on timeout/error). There is deliberately
# no preflight:partial or preflight:blocked case here -- the catch-all below rejects that
# nonsensical combination with exit 1, which is the desired fail-loud behavior.
postflight:partial)  STATE_STATUS="partial";       TODO_STATUS="PARTIAL" ;;
postflight:blocked)  STATE_STATUS="blocked";       TODO_STATUS="BLOCKED" ;;
```

And it is already exercised successfully today by `reconcile-task-status.sh`'s stranded-task
self-heal:

```bash
echo "[reconcile] Would promote: not_started -> partial via postflight partial"
"$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "partial" "$session_id"
```

However, `scripts/skill-base.sh`'s `skill_postflight_update` — the function all three SKILL.md
sites actually call — cannot currently reach that mapping, because its own internal gate is:

```bash
skill_postflight_update() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  local status="$4"
  ...
  case "$status" in
    researched|planned|implemented)
      bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation" "$session_id" "${phase_check_args[@]}"
      ;;
    *)
      echo "[skill-base] Non-success status '${status}' — postflight status update skipped"
      ;;
  esac
  ...
}
```

Two things follow from this signature: (1) it switches on `$status` (the 4th positional arg,
i.e. `dispatch_status`) but always forwards `$operation` (the 2nd positional arg — literally
`"research"`/`"plan"`/`"implement"` at every call site today) as the `target_status` to
`update-task-status.sh` — never `"partial"`/`"blocked"` as a target_status token; (2) any call
with `$status` outside `researched|planned|implemented` falls to its own `*)` and silently skips,
regardless of what `$operation` was passed. So even if a future SKILL.md edit added a `partial)`
arm that called `skill_postflight_update "$task_number" "partial" "$session_id" "partial"`
(intending "operation=partial" to route to `postflight:partial`), the function's own gate would
still catch `$status = "partial"` at its `*)` branch and skip — the call would silently no-op one
layer deeper than the SKILL.md fix touches.

**Consequence for scope**: making `partial`/`failed`/`blocked` produce an actual, non-benign
state.json transition (as opposed to merely a differently-worded, still-no-op log line) requires
extending `skill_postflight_update` itself — most simply, adding `partial` and `blocked` as
additional case arms that call `update-task-status.sh postflight "$task_number" "$status"
"$session_id"` (i.e. route on `$status` directly for these two, bypassing `$operation` — mirroring
`reconcile-task-status.sh`'s existing direct call shape). `failed` has no corresponding
`postflight:failed` mapping in `update-task-status.sh` at all today — state-management.md's
model apparently treats a hard `failed` dispatch outcome as escalation-worthy (Stage 6 blocker
handling) rather than a distinct state.json status, which is consistent with `blocked` already
being the state.json-side terminus for unrecoverable-without-human-input outcomes. Whether
`failed` should map to `blocked` in state.json, remain an escalation-only signal with no direct
state.json write, or gain its own mapping is a decision for the planner, not resolved here.

**Recommendation**: treat `skill-base.sh`'s `skill_postflight_update` as a fourth, necessary site
alongside the three named in the task description — not a separate task, since it is the single
function all three call sites route through and splitting it out would recreate exactly the
three-copies-of-one-rule problem this task exists to eliminate. This should be surfaced to
whoever plans the implementation rather than silently expanded here.

### 5. Reliability of `artifacts[0].type` for phase inference

`docs/architecture/handoff-schema.md`'s artifact schema constrains `type` to a closed
three-value set: `"type": "report | plan | summary"`. Cross-referencing
`return-metadata-file.md`'s worked examples:

- A `"researched"` outcome pairs `type: "report"`.
- A `"planned"` outcome pairs `type: "plan"`.
- An `"implemented"` outcome pairs `type: "summary"` (see the "Implementation Success" example).
- **Critically**, a `"partial"` outcome *also* pairs `type: "summary"` (see the "Implementation
  Partial" example: `{"type": "summary", "path": ".../01_lsp-config-summary.md", "summary":
  "Partial implementation summary with 2 of 4 phases completed"}`).

So `artifacts[0].type` is a reliable, low-cardinality signal for **which phase** produced the
artifact (`report` → research, `plan` → plan, `summary` → implement), which is exactly the use
the fix direction proposes ("infer the intended phase from the handoff's artifact type as a
recovery path") — e.g. as a corroborating signal when `dispatch_status` is off-schema but an
`artifacts[0].type` is present and well-formed, to decide *which* loud-failure/recovery message
to emit, or which operation token a human should be told to re-check. It is **not** a reliable
signal for success-vs-partial within that phase, since `summary` covers both `implemented` and
`partial` outcomes identically. Any recovery path built on `artifacts[0].type` must therefore be
scoped to phase identification only, never used to substitute a guessed "implemented" or
"researched" success verdict for a missing/invalid `dispatch_status` — doing so would silently
convert a `partial` (or garbage) dispatch into a false completion claim, which is precisely the
class of defect this task exists to close, just introduced from a different angle.

### 6. Precedent for the "loud banner" family

The task's fix direction asks for the same visible-banner family as `[UNVERIFIED ...]` and
`[SPARSE COVERAGE ...]`. Confirmed live precedent (all are plain `echo`'d bracketed-prefix
strings, not a shared bash function — each site emits its own literal banner text):

- `agent-system/extensions/literature/scripts/literature-briefing.sh`: `"[UNVERIFIED -
  provenance_fidelity: $1 - not confirmed faithful to its source PDF; verify before citing]"`
  and `"[DEGRADED RETRIEVAL - fallback_tier: trigram] ..."`.
- `agent-system/extensions/core/merge-sources/claudemd.md` documents the sparse-coverage marker
  as "same family" as those two: `[SPARSE COVERAGE - N segment(s), threshold T]`.
- Within `skill-orchestrate/SKILL.md` itself, Stage 5's existing stray/staleness checks already
  use a comparable loud-ERROR idiom (not bracket-tagged, but `stderr` + `ERROR:` prefix +
  multi-line explanation), e.g. `"[orchestrate] ERROR: STALE HANDOFF — ..."` and `"[orchestrate]
  ERROR: STRAY HANDOFF at ..."`.
- Stage 4's own "Unknown state" handler (for `state.json`'s `current_status`, a sibling defect
  surface to the one in scope) already treats an off-schema value as loud + exiting, not a
  silent continuation: `echo "[orchestrate] WARNING: Unrecognized state '$current_status' for
  task $task_number." / EXIT (partial)`. This is directly reusable internal precedent for how the
  fixed `dispatch_status` validation should behave on a genuinely off-schema value — a `WARNING`/
  `ERROR` line plus `EXIT (partial)` (not merely a differently-worded `echo` that still falls
  through to cycle-increment and artifact-linking as if nothing happened).

## Decisions

- Confirmed: no re-derivation needed for the mechanism, the three sites, or the reproduction
  path — all match the task description's claims exactly on inspection.
- Confirmed: the handoff-schema enum and the `.return-meta.json` enum are the same six success/
  exception values; no reconciliation between the two is needed, only a validator that draws
  from the single normative table.
- Established idiom for "draw from the normative table without an inline restatement": restate
  the literal six values with a sync-comment citing `context/formats/return-metadata-file.md` by
  path (Examples A and B above), not a markdown-table-parsing mechanism.
- Flagged, not resolved: `skill_postflight_update` in `scripts/skill-base.sh` is a necessary
  fourth site for `partial`/`blocked` to produce a real state.json transition, given its own
  internal `case` gate. `failed` currently has no `update-task-status.sh` postflight mapping at
  all and needs an explicit planner decision (map to `blocked`, escalation-only, or new mapping).
- `artifacts[0].type` inference should be scoped to phase identification only, never used to
  infer success/partial within a phase.

## Risks & Mitigations

- **Risk**: fixing only the three named sites (adding case arms + a loud banner for genuinely
  unrecognized values) without touching `skill_postflight_update` would make `partial`/`failed`/
  `blocked` visibly distinct from garbage in the logs, but would still leave the underlying
  state.json stranding behavior (the `researching`/`planning`/`implementing` in-flight status
  never clearing on a partial outcome) unfixed. **Mitigation**: the plan should explicitly decide
  whether closing this gap is in scope for this task or deliberately deferred, and say so, rather
  than have it discovered as a second silent gap after the loud-banner fix ships.
- **Risk**: a validator that treats every non-`researched|planned|implemented` value as "loud
  failure, EXIT" would regress the *legitimate* `partial`/`failed`/`blocked` cases into the same
  alarming banner as truly off-schema garbage, contradicting the task's explicit ask for
  "explicit handling" of the three legitimate exception values as distinct from unrecognized
  ones. **Mitigation**: the validator/case structure must distinguish three tiers — success
  (`researched|planned|implemented`, existing behavior), legitimate exception
  (`partial|failed|blocked`, needs its own non-alarming-but-non-silent branch, and ideally a real
  state transition per finding 4), and off-schema (anything else, loud banner + `EXIT (partial)`
  per the Stage 4 "Unknown state" precedent).
- **Risk**: restating the six-value enum as literals in three (or four) separate files without a
  strong enough sync comment recreates exactly the drift problem the binding design constraint
  warns about. **Mitigation**: use the same explicit wording pattern as
  `command-gate-out.sh`'s "keep this list and that table in sync rather than letting them drift
  independently," in every restatement.

## Appendix

- Search queries / methods used: direct file reads of both `skill-orchestrate/SKILL.md` and
  `skill-orchestrate-hard/SKILL.md` (Stage 5, Stage MT-4); grep for `MT-4`, `vocabulary`,
  `UNVERIFIED`, `SPARSE COVERAGE`, `valid_statuses`/`VALID_STATUSES`/`STATUS_ENUM`, `postflight.*
  partial|blocked`, `update-task-status.sh postflight` (repo-wide caller survey); read of
  `context/formats/return-metadata-file.md` (full file) and
  `docs/architecture/handoff-schema.md` (Field Definitions + Outcome Channels sections); read of
  `scripts/skill-base.sh`'s `skill_postflight_update`, `scripts/update-task-status.sh`'s
  `map_status`, `scripts/reconcile-task-status.sh`'s stranded-task self-heal call,
  `scripts/orchestrate-triage-classify.sh`'s header table, `scripts/validate-handoff.sh`'s
  status-value check, `scripts/command-gate-out.sh`'s defensive-correction accept-list.
- Key file paths referenced (all under `agent-system/extensions/core/`, per the source-store
  rule — none of these should be edited under `.claude/**`):
  - `skills/skill-orchestrate/SKILL.md` (Stage 5, Stage MT-4 step 3)
  - `skills/skill-orchestrate-hard/SKILL.md` (mirrored Stage 5)
  - `scripts/skill-base.sh` (`skill_postflight_update`)
  - `scripts/update-task-status.sh` (`map_status`, `postflight:partial`/`postflight:blocked`)
  - `scripts/reconcile-task-status.sh` (existing `postflight partial` caller precedent)
  - `context/formats/return-metadata-file.md` (normative status table)
  - `docs/architecture/handoff-schema.md` (handoff schema, cross-reference precedent)
  - `scripts/command-gate-out.sh` (inline-restatement-with-sync-comment precedent)
  - `scripts/validate-handoff.sh` (narrower, differently-scoped status accept-list)
