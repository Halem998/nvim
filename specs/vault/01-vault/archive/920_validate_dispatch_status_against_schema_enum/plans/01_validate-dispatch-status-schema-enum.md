# Implementation Plan: Task #920

- **Task**: 920 - Validate dispatch_status against the schema enum so an off-schema value fails loudly instead of silently no-opping
- **Status**: [COMPLETED]
- **Effort**: 2.75 hours
- **Dependencies**: 936 (completed)
- **Research Inputs**: specs/920_validate_dispatch_status_against_schema_enum/reports/01_validate-dispatch-status-schema-enum.md
- **Artifacts**: plans/01_validate-dispatch-status-schema-enum.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

An off-schema `dispatch_status` read from `.orchestrator-handoff.json` currently falls to a
`case "$dispatch_status"` catch-all that prints a benign-sounding "no postflight update needed"
line and performs no update — stranding a task that in fact completed successfully. This plan
replaces that single catch-all at all three named sites with a **three-tier** structure: success
values (unchanged behavior), in-enum exception values (`partial|failed|blocked` — explicitly
recognized, honestly logged, no state transition), and off-schema values (a loud
`[OFF-SCHEMA DISPATCH STATUS - ...]` banner in the same family as `[UNVERIFIED ...]` /
`[SPARSE COVERAGE ...]`, followed by a halt/`failed_tasks` charge). Definition of done: no
`dispatch_status` value at any of the three sites can produce a silent no-op, and every accept-list
carries a sync comment citing `context/formats/return-metadata-file.md` by path.

### Research Integration

Findings from `reports/01_validate-dispatch-status-schema-enum.md` that shape this plan:

- **All three sites verified verbatim.** The defect is real and the catch-all shape is identical
  at each.
- **Enum identity settled.** The handoff `status` enum and the `.return-meta.json` enum are the
  **same six values** (`researched|planned|implemented|partial|failed|blocked`). There is no
  drift to reconcile — only a validator to add. The "three distinct vocabularies" warning in the
  normative file is about a *different* axis (skill-status vs. state.json vs. notification) and
  does not apply here.
- **Enum-sourcing precedent found.** Mechanical import is impossible in bash/markdown. The live
  in-tree idiom is: restate the literals with an explicit sync comment citing the normative
  source by path. `scripts/command-gate-out.sh` is the working bash example, with the exact
  wording this plan reuses: *"keep this list and that table in sync rather than letting them
  drift independently."* `docs/architecture/handoff-schema.md` is the prose example. This plan
  follows that precedent and invents no fourth convention.
- **`artifacts[0].type` is phase-reliable, success-unreliable.** `report|plan|summary` reliably
  identifies *which phase* wrote the artifact, but `summary` covers both `implemented` and
  `partial` in the schema's own examples. Inference is therefore scoped to naming the phase in
  the off-schema banner and is **never** used to synthesize a success verdict.
- **Loud-banner and loud-exit precedent confirmed.** Stage 4's own "Unknown state" handler
  (`WARNING: Unrecognized state ...` + `EXIT (partial)`) is the directly reusable internal
  precedent for how an off-schema value should behave.
- **Fourth site flagged, not fixed** — see the scope decision below.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (`roadmap_path` not provided).

## Scope Decision (explicit, per delegation)

**Chosen: Option (a) — stay within the declared `file_scope`.**

This task's declared `file_scope` in `state.json` is exactly:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`

`agent-system/extensions/core/scripts/skill-base.sh` is **not** in it and is **not** edited by
this plan.

**Rationale**:

1. **Concurrent-edit collision is real and imminent.** Task 931
   (`handoff_continuation_path_writer_predicate_contract`, currently `not_started`) declares
   `agent-system/extensions/core/scripts/skill-base.sh` in its own `file_scope` — *and also
   declares `skills/skill-orchestrate/SKILL.md`*. Expanding into `skill-base.sh` here would
   create a two-file overlap with work queued to run right after this task, in a tree the
   research explicitly observed being edited concurrently.
2. **The in-scope change is independently valuable and complete on its own terms.** The named
   defect — *a successful dispatch being silently indistinguishable from one that produced
   nothing* — is fully closed by this plan. Off-schema values become loud and halting; in-enum
   exception values become explicitly recognized rather than swept into an unlabeled catch-all.
3. **Option (b) would require a "do not run concurrently" constraint** that the orchestrator has
   no mechanism to enforce beyond prose, trading a bounded documented limitation for an
   unbounded undocumented risk.

### What remains NON-FUNCTIONAL after this task lands

State this plainly in the implementation summary; nobody should read this task as delivering more
than it does.

| Gap | Status after this task |
|-----|------------------------|
| `partial` / `failed` / `blocked` dispatch outcomes producing a real `state.json` transition | **STILL BROKEN.** They are now *recognized and logged honestly*, but no state transition occurs. `skill_postflight_update` in `scripts/skill-base.sh` has its own internal `case "$status" in researched\|planned\|implemented) ... *) ... skip` gate, so a call from SKILL.md would no-op one layer deeper regardless of what this task does. |
| A task stranded at `researching`/`planning`/`implementing` after a `partial` dispatch | **STILL STRANDED.** The next loop iteration still reaches Stage 4's `researching` handler and still emits the misleading "currently being researched in another session" message. |
| `failed` as a `state.json` target status | **STILL ABSENT.** `scripts/update-task-status.sh` has working `postflight:partial` and `postflight:blocked` mappings (already exercised by `reconcile-task-status.sh`), but **no `postflight:failed` mapping at all**. Whether `failed` should map to `blocked`, remain escalation-only, or gain its own mapping is an open decision. |

### Named follow-up dependency

**Follow-up (not created by this task, must be created separately):** *Admit `partial` and
`blocked` into `skill_postflight_update`'s internal accept-list in
`agent-system/extensions/core/scripts/skill-base.sh`, routing on `$status` directly (mirroring
`reconcile-task-status.sh`'s existing `update-task-status.sh postflight <task> partial <session>`
call shape), and decide the disposition of `failed`, which has no `postflight:` mapping today.*

This follow-up **must be sequenced after task 931**, which already holds `skill-base.sh` in its
`file_scope`. Phase 4 of this plan records the same pointer as a durable in-file comment at the
Tier-B branches (citing the script and function by path/symbol, never by task number).

## Goals & Non-Goals

**Goals**:
- Replace the single `*)` catch-all with a three-tier structure at all three named sites.
- Emit a loud, bracketed, stderr banner for off-schema values, in the established
  `[UNVERIFIED ...]` / `[SPARSE COVERAGE ...]` family.
- Halt (base/hard Stage 5) or charge to `failed_tasks` (MT-4) on off-schema, rather than
  continuing as if nothing happened.
- Give `partial|failed|blocked` explicit, named recognition branches whose log text states
  honestly what does and does not happen.
- Bind every restated accept-list to `context/formats/return-metadata-file.md` with a sync
  comment, using the `command-gate-out.sh` wording.
- Preserve artifact linking on the off-schema path so the dispatch's evidence is not lost.

**Non-Goals**:
- Editing `agent-system/extensions/core/scripts/skill-base.sh` (see Scope Decision).
- Editing `scripts/update-task-status.sh`, `scripts/validate-handoff.sh`, or
  `scripts/orchestrate-recover-outcome.sh`.
- Changing the recovery path. `dispatch_status` is assigned from `recover_json` only inside
  `if [ "$recovered" = "true" ]`, and `orchestrate-recover-outcome.sh` sets `recovered=true` only
  for `researched|planned|implemented`. A recovered `dispatch_status` is always in-enum and can
  never reach `*)`. **Do not "fix" it.**
- Any change to `state.json` transition semantics for `partial`/`failed`/`blocked`.
- Building a markdown-table-to-bash-array parser.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Legitimate `partial` outcomes regress into the alarming off-schema banner | H | M | Tier B (`partial\|failed\|blocked`) is a distinct case arm with its own non-alarming wording, matched *before* `*)`. Phase 1 verification explicitly asserts a `partial` value does not print the banner. |
| Off-schema halt drops the artifact link, losing the dispatch's evidence | M | M | The halt is a flag set inside the case, consumed **after** the artifact-linking block, not an inline exit. Artifact linking still runs. |
| Restating six literals in two SKILL.md files becomes a new drift site | M | M | Every restatement carries the `command-gate-out.sh` sync-comment wording citing `context/formats/return-metadata-file.md` by path. Phase 4 greps that all restatements are present and identical. |
| Base and hard implementations diverge | M | M | Phase 2 is a deliberate mirror of Phase 1 and depends on it; Phase 4 diffs the two case blocks and asserts they differ only in log prefix and hard-mode-specific lines. |
| `set -u` abort on the unset halt flag | H | L | Initialize the flag before the `case` and read it as `${offschema_dispatch_status:-false}`. |
| Edits land in `.claude/**` (wiped on next regeneration) | H | L | Every phase names an `agent-system/extensions/core/**` target. Phase 4 greps the diff for `.claude/` write targets. |
| Line-number anchors drift under concurrent edits | M | H | Every phase anchors on quoted distinctive strings and symbol names only. No line numbers appear in any phase. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Base-mode Stage 5 three-tier validation (reference implementation) [COMPLETED]

**Goal**: Establish the canonical three-tier `dispatch_status` structure in
`skill-orchestrate/SKILL.md`'s Stage 5. This phase defines the shape Phases 2 and 3 mirror.

**Anchors** (locate by these strings, never by line number):
- Handoff read: the line `dispatch_status=$(echo "$handoff" | jq -r '.status')` inside the `else`
  branch that begins `handoff=$(cat "$handoff_file")`.
- Case block: the comment `# ── Shared postflight tail ─────` followed by
  `if [ "$have_outcome" = "true" ]; then` and `case "$dispatch_status" in`.
- Catch-all to replace: `echo "[orchestrate] Dispatch status '$dispatch_status' — no postflight update needed"`.
- Halt insertion point: the end of the `if [ "$have_outcome" = "true" ]; then ... fi` block,
  **after** the artifact-linking `if [ -n "$handoff_artifact_path" ] ...` block.

**Tasks**:
- [ ] Change the handoff read to `dispatch_status=$(echo "$handoff" | jq -r '.status // ""')` so a
      handoff with a missing `status` field yields an empty string rather than the literal string
      `null`. Both empty and `null` must route to Tier C.
- [ ] Immediately above the `case "$dispatch_status" in`, add the accept-list sync comment. Reuse
      `command-gate-out.sh`'s wording verbatim in spirit: state that the normative enumeration of
      these six values is `context/formats/return-metadata-file.md`'s status vocabulary, which
      declares itself normative for `.orchestrator-handoff.json`'s `status` field, and *"keep this
      list and that table in sync rather than letting them drift independently."*
- [ ] In that same comment, state explicitly that `in_progress` — present in the normative table —
      is deliberately **not** accepted here: it is early-metadata-only and never a legal terminal
      dispatch outcome, so a handoff carrying it means the writer never finished and is correctly
      treated as off-schema. This makes the six-value accept-list a documented strict subset, not
      an unexplained divergence.
- [ ] Initialize `offschema_dispatch_status=false` before the `case` (guards `set -u`).
- [ ] Leave the `researched)`, `planned)`, and `implemented)` arms **byte-for-byte unchanged**,
      including the `skill_gate_completion_claim` call and the completion-summary propagation.
- [ ] Add a Tier B arm `partial|failed|blocked)` before the catch-all. It performs **no**
      `skill_postflight_update` call and emits one stderr recognition line naming the status and
      stating plainly that no `state.json` transition is performed here, that the task remains at
      its in-flight status, and that this cycle's loop counter still advances.
- [ ] Add a comment on the Tier B arm citing `scripts/skill-base.sh`'s `skill_postflight_update`
      internal accept-list as the reason a call from here would no-op one layer deeper. Cite by
      script path and function symbol only — **no task-number citation** (this file is outside
      `specs/**`).
- [ ] Replace the `*)` body with the Tier C off-schema handler: set
      `offschema_dispatch_status=true`; derive `inferred_phase` from `$handoff_artifact_type`
      (`report`->research, `plan`->plan, `summary`->implement, anything else->unknown); emit the
      banner `[OFF-SCHEMA DISPATCH STATUS - '<value>' is not in the handoff status vocabulary
      (researched|planned|implemented|partial|failed|blocked); the dispatch may have SUCCEEDED but
      its outcome cannot be trusted or applied]` to **stderr**, rendering an empty value as
      `<empty>`; follow with an `[orchestrate] ERROR:` line naming the handoff file, the inferred
      phase, and the remedy.
- [ ] Add a MUST-NOT comment on the inference block: `artifacts[0].type` identifies the **phase
      only** and is never a success-vs-partial signal (the schema's own examples pair `summary`
      with both `implemented` and `partial`). It must never be used to synthesize a success
      verdict for a missing or invalid `dispatch_status`.
- [ ] After the artifact-linking block, inside the same `have_outcome` block, add the halt: when
      `${offschema_dispatch_status:-false}` is `true`, emit a closing stderr line noting the task
      was left at its current status and that the artifact (if any) was still linked so the
      dispatch's evidence is preserved, then `EXIT (partial)` — following Stage 4's "Unknown
      state" handler precedent.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts **exactly four edit regions in one file**
(`skills/skill-orchestrate/SKILL.md`): the handoff read, the pre-`case` comment + flag init, the
`case` arms, and the post-artifact-linking halt. Confirm at implementation time by grepping the
file for `dispatch_status` and checking that no Stage 5 occurrence outside these four regions
needed a change; if a fifth region turns out to require edits, record it rather than silently
widening.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 5 handoff read,
  accept-list sync comment, three-tier `case`, post-linking halt.

**Verification**:
- Grep confirms the string `no postflight update needed` no longer appears in Stage 5 of this file.
- Grep confirms `[OFF-SCHEMA DISPATCH STATUS` appears exactly once in this file.
- Grep confirms `context/formats/return-metadata-file.md` is cited in the new accept-list comment.
- Grep confirms `keep this list and that table in sync` (the `command-gate-out.sh` wording) appears
  in the new comment.
- Read-through confirms `partial` matches the Tier B arm and cannot reach `*)`, so a legitimate
  partial outcome never prints the off-schema banner.
- Read-through confirms the `researched`/`planned`/`implemented` arms are unchanged.
- `bash -n` is not applicable (markdown-embedded bash); instead, extract the modified `case` block
  and confirm it parses via `bash -n` on a scratch file containing just that block with stub
  function definitions.

---

### Phase 2: Hard-mode Stage 5 mirror [COMPLETED]

**Goal**: Apply the identical three-tier structure to `skill-orchestrate-hard/SKILL.md`'s
mirrored Stage 5, so base and hard modes cannot drift apart.

**Anchors**:
- Handoff read: `dispatch_status=$(echo "$handoff" | jq -r '.status')` inside the `else` branch
  beginning `handoff=$(cat "$handoff_file")`.
- Case block: the comment
  `# ── Shared postflight tail — hard-mode-specific gate on `implemented`` followed by
  `case "$dispatch_status" in`.
- Catch-all to replace: `echo "[hard-orchestrate] Dispatch status '$dispatch_status' — no postflight update needed"`.

**Tasks**:
- [ ] Apply every Phase 1 change, adapted only in log prefix (`[hard-orchestrate]` rather than
      `[orchestrate]`).
- [ ] Leave the hard-mode-specific `implemented)` arm body unchanged, including the
      `else` branch that emits `[hard-orchestrate] skeleton=${skeleton} at refusal.`
- [ ] Leave the hard-mode-specific reads (`skeleton`, `sorry_inventory`, the follow-ups log line)
      untouched.
- [ ] Use the identical banner text and the identical accept-list sync comment as Phase 1, so a
      future reader diffing the two files sees them as one contract in two places.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the hard-mode Stage 5 differs from base-mode Stage 5
**only** in log prefix plus the hard-mode-specific `skeleton`/`sorry_inventory` lines and the
`implemented)` refusal `else` branch. Confirm at implementation time by diffing the two `case`
blocks after editing; any additional difference must be recorded, not silently accepted.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - mirrored Stage 5 read,
  accept-list sync comment, three-tier `case`, post-linking halt.

**Verification**:
- Grep confirms `no postflight update needed` no longer appears in this file.
- Grep confirms `[OFF-SCHEMA DISPATCH STATUS` appears exactly once in this file.
- Side-by-side diff of the base and hard `case` blocks shows only the expected differences
  enumerated in the Scope Hypothesis.
- Same scratch-file `bash -n` parse check as Phase 1.

---

### Phase 3: Multi-task Stage MT-4 clause [COMPLETED]

**Goal**: Close the same defect in the multi-task engine, where the analogous clause is prose
rather than bash and where the correct off-schema response is a per-task `failed_tasks` charge
rather than a whole-wave halt.

**Anchors** (all in `skills/skill-orchestrate/SKILL.md`, Stage MT-4):
- Step 3's clause `- Other → no postflight update`.
- Step 5's list containing `- If \`dispatch_status\` is \`"failed"\` or \`"blocked"\`: add to \`failed_tasks\`.`
- The `**Commit message selection**, keyed off this task's own \`dispatch_status\`` bullet list.
- The `**Branch coverage** (every \`dispatch_status\` / recovery path this loop can reach)` list.

**Tasks**:
- [ ] Replace step 3's `- Other → no postflight update` with two explicit clauses mirroring
      Phase 1's Tier B and Tier C:
      - `partial`, `failed`, or `blocked`: in-enum exception outcome. No postflight update
        (`skill_postflight_update`'s own accept-list would skip it anyway); log an explicit
        recognition line naming the status. Steps 4-6 still run unchanged.
      - Any other value, **including `null`, empty, and `in_progress`**: OFF-SCHEMA. Emit the same
        `[OFF-SCHEMA DISPATCH STATUS - ...]` banner to stderr with the same
        `artifacts[0].type`-derived phase inference (phase identification only), and perform no
        postflight update.
- [ ] Add the same accept-list sync comment (citing `context/formats/return-metadata-file.md` and
      using the `keep this list and that table in sync` wording) to step 3, adapted to prose form.
- [ ] Extend step 5 so an off-schema `dispatch_status` also adds the task to `failed_tasks` — the
      multi-task analogue of Stage 5's halt. It is loud and per-task, and deliberately does **not**
      kill sibling tasks in the wave.
- [ ] Add an off-schema arm to the **Commit message selection** list, so an off-schema outcome does
      not fall through with no `commit_message` assigned. Follow the existing `failed`/`blocked`
      form: `"task ${task_num}: orchestration dispatch off-schema"`.
- [ ] Add an off-schema entry to the **Branch coverage** list, stating that step 5.5 DOES run
      (artifacts the dispatch actually produced are still real and belong in a commit) and that the
      task is charged to `failed_tasks`.

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts **exactly four edit points** within Stage MT-4 (step 3
clause, step 5 `failed_tasks` list, commit-message selection list, branch-coverage list). Confirm
at implementation time by re-reading Stage MT-4 end to end after editing and checking no fifth
`dispatch_status`-keyed decision point exists there; record any additional one found.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-4 steps 3, 5, 5.5
  commit-message selection, and branch-coverage list.

**Verification**:
- Grep confirms the string `Other → no postflight update` no longer appears in the file.
- Read-through confirms every `dispatch_status` value — the six in-enum values plus off-schema —
  now has a named branch in step 3, step 5, the commit-message list, and the branch-coverage list.
- Confirm no bash was introduced into a prose-only region in a way that breaks Stage MT-4's
  existing prose/bash conventions.

---

### Phase 4: Cross-site consistency, limitation record, and boundary gates [COMPLETED]

**Goal**: Verify the three sites express one contract, record the non-functional gaps and the
named follow-up durably, and run the binding-constraint gates.

**Tasks**:
- [ ] Diff the base and hard `case` blocks; confirm the only differences are those enumerated in
      Phase 2's Scope Hypothesis.
- [ ] Confirm the banner text `[OFF-SCHEMA DISPATCH STATUS - ...]` is character-identical across
      all three sites (modulo the interpolated status value).
- [ ] Confirm the accept-list sync comment citing `context/formats/return-metadata-file.md` is
      present at all three sites and uses the `keep this list and that table in sync` wording.
- [ ] Confirm the Tier B in-file comment pointing at `scripts/skill-base.sh`'s
      `skill_postflight_update` gate is present at all three sites, cited by path and symbol.
- [ ] **Source-store gate**: `git status --short` and the staged diff must show **zero** paths
      under `.claude/`. Every modified path must be under `agent-system/extensions/core/`.
- [ ] **No-task-references gate**: grep both modified SKILL.md files for task-number citation
      patterns (`task [0-9]`, `tasks [0-9]`, `(task [0-9]`). Pre-existing markers such as the
      `<!-- BEGIN 772 Item 5B` comment block in the hard-mode file are **not** introduced by this
      work and must be left untouched; assert only that no *new* task-number citation was added.
- [ ] **Line-number-anchor gate**: confirm no edit was located or documented by line number.
- [ ] Record in the implementation summary, verbatim from this plan's Scope Decision, the three
      **NON-FUNCTIONAL** rows and the named follow-up (admit `partial`/`blocked` into
      `skill_postflight_update`'s accept-list in `scripts/skill-base.sh`; decide `failed`'s
      disposition given `update-task-status.sh` has no `postflight:failed` mapping), including the
      note that the follow-up must be sequenced after task 931.
- [ ] Run `bash .claude/scripts/validate-artifact.sh` against this plan file.

**Timing**: 30 minutes

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- None (verification and summary-authoring phase only).

**Verification**:
- All gate greps above return the expected results.
- The implementation summary contains the non-functional table and the named follow-up.
- `validate-artifact.sh` exits 0 on the plan.

---

## Testing & Validation

- [ ] Extracted `case` blocks from both SKILL.md files parse cleanly under `bash -n` with stub
      function definitions.
- [ ] Trace check — `dispatch_status="success"` (the observed reproduction value): reaches Tier C,
      prints the banner to stderr, links the artifact, then exits partial. Never silent.
- [ ] Trace check — `dispatch_status="partial"`: reaches Tier B, prints the recognition line, does
      **not** print the off-schema banner, does not transition state, loop counter still advances
      (behavior otherwise identical to today).
- [ ] Trace check — `dispatch_status="implemented"`: reaches the unchanged `implemented)` arm,
      `skill_gate_completion_claim` still gates the transition.
- [ ] Trace check — handoff with no `status` field: `// ""` yields empty, reaches Tier C, banner
      renders `<empty>`.
- [ ] Trace check — `dispatch_status="in_progress"`: reaches Tier C (deliberately not accepted).
- [ ] Trace check — recovered path (`recovered=true`): `dispatch_status` is always one of the three
      success values, so Tier B and Tier C are unreachable from it. Confirms the recovery path was
      not disturbed.
- [ ] Trace check — MT-4 off-schema: task charged to `failed_tasks`, commit message assigned,
      sibling tasks in the wave unaffected.
- [ ] `bash .claude/scripts/validate-artifact.sh <plan_path> plan` exits 0.

## Artifacts & Outputs

- `specs/920_validate_dispatch_status_against_schema_enum/plans/01_validate-dispatch-status-schema-enum.md` (this file)
- Modified: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- Modified: `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- `specs/920_validate_dispatch_status_against_schema_enum/summaries/01_validate-dispatch-status-schema-enum-summary.md`

## Rollback/Contingency

Both modified files are markdown-embedded instruction files under version control with no build
artifact. Rollback is a targeted `git checkout` of the two paths from the pre-task commit — no
migration, no state cleanup, no deploy step. Because `.claude/` is a disposable deploy artifact
regenerated from the source store, reverting the source store is sufficient; no `.claude/` cleanup
is required.

Partial-completion contingency: Phases 1, 2, and 3 are each independently valid. If Phase 2 or 3
cannot land, the completed sites are still strictly better than the current catch-all, but the
implementation summary must then record which sites remain on the old silent-no-op behavior, since
a partially-applied fix is exactly the drift the in-file "duplicated `case \"$dispatch_status\"`"
comment warns against.
