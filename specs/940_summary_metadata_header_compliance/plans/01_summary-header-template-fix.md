# Implementation Plan: Task #940

- **Task**: 940 - summary_metadata_header_compliance
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/940_summary_metadata_header_compliance/reports/01_summary-metadata-header-compliance.md
- **Artifacts**: plans/01_summary-header-template-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research established the root cause empirically: `general-implementation-agent.md`'s own Stage 6
carries a literal, ready-to-copy summary skeleton that has never matched
`context/formats/summary-format.md`, and that concrete inline template wins over the two
already-standing advisory checks (the Stage 4b format injection and the real-time PostToolUse
hook). The remedy is therefore to reconcile that inline template in place, not to add a third
cross-reference. Around that core fix, this plan restores the validator's ability to *deliver* a
readable signal (the `--fix` anchor crash), closes the hard-mode postflight-validation asymmetry,
and records an explicit non-blocking enforcement posture. Definition of done: a summary written
from the corrected template validates clean, and the negative case produces a readable error list
rather than a crash.

### Research Integration

- Root cause (item A) is settled: the divergence is `general-implementation-agent.md` Stage 6's
  own skeleton (`**Completed**:` / `**Duration**:` only), missing all five reported header fields
  and three required sections. `general-implementation-hard-agent.md` Stage 6 says "Same as base
  agent," so **it needs no edit** — fixing the base agent in place fixes both modes. This plan
  deliberately does not duplicate the skeleton into the hard agent.
- The spec is already force-injected into every dispatch (Stage 4b `<artifact-format-specification>`
  in both implementer skills) and a real-time PostToolUse hook already fires on every summary
  write. Both are structurally sound and are left mechanically unchanged.
- The defect is long-standing and repository-wide (20+ historical summaries lack a `**Task**:`
  line), not a three-dispatch regression. Backfill remains out of scope (item D).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_flag` in the delegation context; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:
- Replace `general-implementation-agent.md` Stage 6's inline skeleton with one that is literally
  conformant to `summary-format.md` — all eight metadata fields and all six required sections —
  while preserving the two locally valuable extra sections (`Plan Deviations`, `Verification`).
- Make `summary-format.md`'s own Example Skeleton match its own "Metadata (required)" list, so a
  future copy of the example cannot reintroduce the divergence.
- Make `validate-artifact.sh --fix` incapable of crashing the validator or anchoring on arbitrary
  prose bullets.
- Give `skill-implementer-hard/SKILL.md` the Stage-6a-equivalent postflight validation call it
  currently lacks.
- Record the enforcement-posture decision (item C) explicitly and in-file, not only in this plan.

**Non-Goals**:
- No backfill of historical summaries under `specs/` (item D, explicit).
- No relaxation of `validate-artifact.sh`'s `SUMMARY_METADATA` / `SUMMARY_SECTIONS` arrays and no
  edit to `summary-format.md`'s *required-field list* — the task description forbids inverting the
  defect this way. Only the format doc's illustrative Example Skeleton is brought into line with
  the list it already declares.
- No new `context/patterns/advisory-signal-desensitization.md` note (research's Context Extension
  Recommendation). It is a reasonable idea but is not part of items A-E; leaving it out keeps this
  task's footprint auditable. Recorded here so it is visibly dropped rather than silently absorbed.
- **No redeploy.** All edits target `agent-system/extensions/**`. Deployment to `.claude/` is the
  user's deliberate, separate action after this run.

## Declared Footprint

The delegation declared `file_scope` as five files. This plan touches those five plus one:

| File | In declared scope | Why |
|------|-------------------|-----|
| `agent-system/extensions/core/agents/general-implementation-agent.md` | yes | The defective Stage 6 template — the root cause |
| `agent-system/extensions/core/agents/general-implementation-hard-agent.md` | yes | **Expected: no edit.** Inherits by "Same as base agent"; listed so the implementer confirms rather than duplicates |
| `agent-system/extensions/core/skills/skill-implementer/SKILL.md` | yes | Stage 6a enforcement-posture change |
| `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` | yes | New Stage-6a-equivalent postflight validation |
| `agent-system/extensions/core/context/formats/summary-format.md` | yes | Example Skeleton alignment with its own required-field list |
| `agent-system/extensions/core/scripts/validate-artifact.sh` | **NO — declared widening** | The `--fix` anchor/crash bug. Justified below |

**Widening justification**: item C's whole point is that a warning must carry signal again. The
signal is delivered *through* this validator. Its `--fix` path can abort the script under
`set -euo pipefail` before the `[FAIL]`/`[PASS]` line ever prints (reproduced live in research),
so the first genuine future regression would surface as a `sed` error rather than the readable
five-field error list. Fixing the template without fixing the reporting channel would leave item
C's acceptance criterion satisfiable only by accident. The change is confined to the `--fix`
block; the `SUMMARY_METADATA`/`SUMMARY_SECTIONS` arrays and every non-`--fix` code path are
untouched.

## Enforcement Posture Decision (item C)

**Decision: keep summary validation non-blocking, and make a compliant run produce zero output
that reads as a warning.** Reasoning, stated rather than assumed because escalating to a blocking
gate would be a real departure from this repository's guardrails:

1. This repository's guardrail philosophy is explicitly defer-not-fail / non-blocking for
   conditions that are not structural facts causing silent, hard-to-attribute harm
   (`context/patterns/batch-orchestration-guardrails.md`). A missing summary header is loud by
   construction and trivially attributable once the template is correct.
2. Research verified that **no machine consumer parses these header fields** — not
   `reconcile-task-status.sh`, not any script under `scripts/`. The only consumers are the
   validator's own presence check and a human reader. The harm is a documentation/audit-trail
   quality cost, which does not meet this repository's own bar for a hard block.
3. The tension the task description names dissolves once the root cause is fixed: an advisory
   check firing on ~100% of runs is noise; the same check firing only on genuine regressions is
   signal. Blocking would solve a problem a correct template already eliminates.
4. **Auto-repair is rejected as the primary posture.** Beyond the crash bug, a `TBD`-placeholder
   repair makes a non-compliant artifact *look* compliant while conveying nothing — it hides the
   defect from exactly the human reader the header exists to serve. Consequently this plan also
   drops `--fix` from the two implementer summary call sites (Phase 3) while keeping the
   (now non-crashing) `--fix` capability available to other callers and to manual use.

**Acceptance criterion (item E)**: a summary written from the corrected template validates with
exit 0 and no `WARNING:` line at gate-out. **Known, accepted residual**: `skill-base.sh`'s
`skill_validate_task_artifacts` sweeps an entire task directory, so a task directory that already
contains historical non-compliant summaries can still warn. That is a direct consequence of item
D (no backfill) and is not a failure of this fix; Phase 5 verifies the newly written artifact, not
the historical population.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Fixing only the five named header fields leaves the three missing sections (`Impacts`, `Follow-ups`, `References`) failing forever, reproducing the noise problem one layer down | H | H if unguarded | Phase 2 brings Stage 6 into **full** conformance — header *and* all six required sections. Phase 5 asserts a clean run, which cannot pass on sections alone |
| Implementer duplicates the corrected skeleton into `general-implementation-hard-agent.md`, creating two copies that will drift | M | M | Declared Footprint marks that file "expected: no edit"; Phase 2 verification greps it to confirm the "Same as base agent" pointer is intact and no skeleton was added |
| The `--fix` shell repair is itself fragile shell scripting (as demonstrated) | M | M | Phase 4 replaces the `sed -i "Na\\..."` insertion with an `awk`-based rewrite that has no shell-escaping surface, and restricts the anchor to lines naming a known metadata field |
| Verification cannot exercise the real end-to-end path, because the deployed `.claude/` tree is deliberately stale and no redeploy is permitted | M | H (certain) | Phase 5 verifies against the **source-store** script and a hand-instantiated artifact that literally copies the new template; the plan states this limitation rather than claiming an end-to-end run |
| A task-number citation leaks into an agent/skill/format/script file | L | L | Every phase's verification includes a task-number grep over the files it touched (`no-task-references-in-deliverables` rule) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3, 4 | -- |
| 2 | 2 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Align summary-format.md's Example Skeleton with its own required-field list [COMPLETED]

**Goal**: Remove the internal inconsistency in the spec doc so the corrected agent template can be
a faithful copy of it, and so a future copy of the example cannot reintroduce the divergence.

**Context**: `summary-format.md`'s `## Metadata (required)` list declares eight fields (Task,
Status, Started, Completed, Effort, Dependencies, Artifacts, Standards), but its own
`## Example Skeleton` shows only five (Task, Status, Started, Completed, Artifacts). The required
list is correct and must NOT change — only the example is brought into line with it.

**Tasks**:
- [x] In `agent-system/extensions/core/context/formats/summary-format.md`, edit the fenced block
      under the `## Example Skeleton` heading so its metadata bullets list all eight fields from
      `## Metadata (required)`, in the same order, in `- **Field**: value` bullet form. *(completed)*
- [x] Add `- **Effort**: {estimate}`, `- **Dependencies**: {list or None}`, and
      `- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md`
      to the example. *(completed)*
- [x] Leave `## Metadata (required)`, `## Structure`, and `## Writing Guidance` unchanged. *(completed: confirmed via git diff — untouched)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/formats/summary-format.md` - Example Skeleton block only

**Verification**:
- Every field name in `## Metadata (required)` appears in the `## Example Skeleton` block
  (field-by-field grep, not a visual read).
- `git diff` confirms the changed hunks lie entirely inside the Example Skeleton fenced block.
- No task-number citation added: `grep -nEi 'task [0-9]+|tasks [0-9]+' <file>` returns nothing new.

---

### Phase 2: Replace general-implementation-agent.md Stage 6's inline skeleton [COMPLETED]

**Goal**: Make the one template that actually governs what gets written — for both base and
hard modes — literally conformant with `summary-format.md`.

**Context**: The current Stage 6 skeleton (anchored by the heading
`### Stage 6: Create Implementation Summary` and the fenced block opening
`# Implementation Summary: Task #{N}` / `**Completed**: {ISO_DATE}` / `**Duration**: {time}`) has
no `Task`, `Status`, `Started`, `Artifacts`, or `Standards` line and no `Impacts`, `Follow-ups`,
or `References` section. The two sections it has that the spec lacks — `## Plan Deviations` and
`## Verification` — are locally valuable (`Plan Deviations` is populated from the phase progress
files' `deviations` arrays by the sentence immediately after the block) and MUST be retained. The
validator checks required-section *presence*, not exclusivity or ordering, so extra sections are
safe.

**Tasks**:
- [x] Replace the fenced skeleton under `### Stage 6: Create Implementation Summary` with the
      replacement text below, verbatim in shape. *(completed)*
- [x] Keep the existing `**Path Construction**` bullets and the trailing
      "Populate `## Plan Deviations` from the `deviations` arrays..." sentence unchanged. *(completed)*
- [x] Add one directive sentence immediately above the fenced block stating that this block is the
      authoritative shape, that it already conforms to the injected
      `<artifact-format-specification>`, and that the metadata header is mandatory and must not be
      abbreviated or reordered away. *(completed)*
- [x] Add one sentence naming the `Status` values to use: `[COMPLETED]` when every plan phase is
      done, `[IN PROGRESS]` on a partial run, `[BLOCKED]` when blocked — matching
      `summary-format.md`'s declared vocabulary. *(completed)*
- [x] Confirm (do not edit) that `general-implementation-hard-agent.md`'s
      `### Stage 6: Create Implementation Summary` still reads "Same as base agent" and that no
      skeleton has been added there. *(completed: confirmed, 0 duplicated skeleton occurrences)*

**Replacement skeleton** (bullet form `- **Field**: value`, matching `summary-format.md` and
making the `--fix` anchor of Phase 4 meaningful):

```markdown
# Implementation Summary: Task #{N}

- **Task**: {N} - {title}
- **Status**: [COMPLETED]
- **Started**: {ISO8601}
- **Completed**: {ISO8601}
- **Effort**: {time}
- **Dependencies**: {list or None}
- **Artifacts**: plans/{NN}_{short-slug}.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

{2-3 sentences on scope and what was accomplished}

## What Changed

- `path/to/file.ext` — {change description}
- `path/to/new-file.ext` — Created new file

## Decisions

- {Key decision made during implementation}

## Plan Deviations

- **Task {P}.{N}** skipped: {reason}
- **Task {P}.{N}** altered: {what changed and why}

(Use `- None (implementation followed plan)` when no deviations occurred)

## Verification

- Build: Success/Failure/N/A
- Tests: Passed/Failed/N/A
- Files verified: Yes

## Impacts

- {Downstream effect of these changes}

## Follow-ups

- {Remaining item, caveat, or follow-up task; use `- None` when there are none}

## References

- {Paths to the plan, reports, and other artifacts informing this summary}
```

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts that `general-implementation-hard-agent.md` requires **no
edit** because its Stage 6 delegates to the base agent by reference. Confirm at implementation
time by reading that file's `### Stage 6: Create Implementation Summary` section in full; if it
turns out to carry any independent header or section instruction, that instruction must be
reconciled too and the widening reported in the summary rather than absorbed silently.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - Stage 6 fenced skeleton
  plus the two new directive sentences
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` - expected unchanged
  (confirmation only)

**Verification**:
- Each of the six `SUMMARY_METADATA` names and each of the six `SUMMARY_SECTIONS` names appears in
  the new Stage 6 block (field-by-field / section-by-section grep against the arrays in
  `scripts/validate-artifact.sh`, not a visual read).
- `## Plan Deviations` and `## Verification` are still present, and the "Populate
  `## Plan Deviations`..." sentence still follows the block.
- `grep -c 'Implementation Summary: Task #' agent-system/extensions/core/agents/general-implementation-hard-agent.md`
  returns 0 (no duplicated skeleton).
- No task-number citation added to either agent file.

---

### Phase 3: Enforcement posture — non-blocking, no auto-repair, and close the hard-mode gap [COMPLETED]

**Goal**: Implement the item C decision at both implementer call sites and give hard mode the
postflight validation it currently lacks.

**Context**: `skill-implementer/SKILL.md`'s `### Stage 6a: Validate Artifact Content` runs
`validate-artifact.sh "$artifact_path" summary --fix` inside an `if ! ...` and logs a
non-blocking `WARNING:` line. `skill-implementer-hard/SKILL.md` has **no** Stage-6a-equivalent at
all — its postflight goes `### Stage 6: Parse Subagent Return` straight to
`### Stage 7: Update Task Status (Postflight)`. `skill-researcher`, `skill-researcher-hard`,
`skill-planner`, and `skill-planner-hard` all call the validator; hard-mode implement is the lone
gap.

**Tasks**:
- [x] In `skill-implementer/SKILL.md` Stage 6a, drop the `--fix` flag from the
      `validate-artifact.sh` invocation. Keep the surrounding `if ! ... ; then echo "WARNING: ..."`
      structure, the `[ "$status" = "implemented" ] || [ "$status" = "partial" ]` guard, and the
      non-blocking behavior exactly as they are. *(completed)*
- [x] Replace Stage 6a's trailing `**Note**: The --fix flag attempts auto-repair...` note with a
      short note recording the posture: validation is non-blocking by design; auto-repair is
      deliberately not used for summaries because a `TBD` placeholder makes a non-compliant
      artifact look compliant to the validator while conveying nothing to the human reader the
      header exists to serve; a compliant summary must produce no warning, so that a warning
      again carries signal. *(completed)*
- [x] In `skill-implementer-hard/SKILL.md`, insert a new `### Stage 6a: Validate Artifact Content`
      between `### Stage 6: Parse Subagent Return` and `### Stage 7: Update Task Status
      (Postflight)`, mirroring the base skill's corrected block (same guard, same no-`--fix`
      invocation, same non-blocking `WARNING:` line, same posture note, using that file's existing
      `$status` / `$artifact_path` variables from its Stage 6). *(completed)*
- [x] Leave `hooks/validate-plan-write.sh`, `scripts/skill-base.sh`, and both Stage 4b format
      injections mechanically unchanged — research found all of them structurally sound.
      *(completed: confirmed via git diff — no changes to either file)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` - Stage 6a invocation and note
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` - new Stage 6a section

**Verification**:
- Extract the bash block from each edited Stage 6a into a scratch file and run `bash -n` on it —
  both must parse clean.
- `grep -n 'summary --fix' agent-system/extensions/core/skills/skill-implementer*/SKILL.md`
  returns nothing.
- `skill-implementer-hard/SKILL.md`'s stage headings, in order, now include `Stage 6`,
  `Stage 6a`, `Stage 7` (grep the `^### Stage` headings and read the sequence).
- `git diff` confirms no change to `hooks/validate-plan-write.sh` or `scripts/skill-base.sh`.
- No task-number citation added to either skill file.

---

### Phase 4: Repair validate-artifact.sh's --fix anchor and insertion [COMPLETED]

**Goal**: Make `--fix` incapable of anchoring on arbitrary prose or aborting the validator, so the
validator can always deliver its readable diagnostic.

**Context** (reproduced live in research): the anchor search `grep -n '^- \*\*' | tail -1` is
intended to find the last metadata line, but matches the last line-initial `- **Bold**:` bullet
*anywhere* in the document — commonly a `- **Files verified**: Yes — ...` bullet in the
Verification section. The subsequent multi-line `sed -i "${last_meta_line}a\\ ..."` then fails on
ordinary prose content (an em dash in the reproduction), aborting the whole script under
`set -euo pipefail` before the `[FAIL]`/`[PASS]` summary line prints.

**Tasks**:
- [x] In the `# --- Auto-fix missing metadata (--fix mode) ---` block of
      `agent-system/extensions/core/scripts/validate-artifact.sh`, restrict the anchor search to
      lines that name a field from the active `metadata_fields` array, accepting both the bullet
      form `- **Field**:` and the bare form `**Field**:`. Build the anchor pattern from
      `metadata_fields`, so the anchor logic cannot drift from the arrays it serves. *(completed)*
- [x] Replace the `sed -i "${last_meta_line}a\\ ..."` insertion with an `awk`-based rewrite to a
      temp file followed by `mv` — passing the insertion text via `-v` or an array read from a
      here-doc so no artifact content is ever interpolated into a shell or `sed` expression. No
      document content may reach a `sed` script again. *(completed: insertion text passed via
      stdin/getline, not -v, per an equivalent no-interpolation approach)*
- [x] Preserve the existing behavior when no metadata anchor is found: the existing
      `log_warn "Cannot auto-fix: no existing metadata lines found to anchor insertion"` branch
      stays. Do **not** widen `--fix` to anchor on the H1 title or to stuff placeholders more
      aggressively — honest failure is the intended outcome per the posture decision. *(completed:
      also fixed an independently-discovered set -e/pipefail abort on this exact no-match path —
      see progress file deviation 4.extra — that was silently preventing this branch from ever
      being reached)*
- [x] Leave `REPORT_METADATA`, `PLAN_METADATA`, `SUMMARY_METADATA`, all `*_SECTIONS` arrays, the
      per-phase Verification Tier loop, and the exit-code contract (0/1/2/3/4) untouched.
      *(completed: confirmed via git diff — untouched)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-artifact.sh` - the `--fix` block only

**Verification**:
- `bash -n agent-system/extensions/core/scripts/validate-artifact.sh` parses clean.
- **Crash-regression case**: copy a historical non-compliant summary containing a
  `- **Files verified**: Yes — ...` bullet (an em dash in the line) to a scratch path, run the
  source script with `summary --fix`; it must reach a terminal `[FIXED]`/`[FAIL]`/`[PASS]` line
  and must not emit a `sed:` error. Capture the exit code.
- **Anchor-correctness case**: on that same scratch copy, confirm any inserted `TBD` lines landed
  in the metadata block near the top, not inside the Verification section.
- **No-anchor case**: on a scratch summary with an H1 but zero metadata lines, confirm the
  `Cannot auto-fix` warning fires and the script still reaches a terminal line.
- **No-regression case**: run the source script without `--fix` over one existing compliant plan
  and one existing compliant report; exit codes and output must match the pre-change behavior.
- No task-number citation added to the script.

---

### Phase 5: End-to-end acceptance verification (item E) [COMPLETED]

**Goal**: Demonstrate the acceptance criterion on a real artifact: a summary written from the
corrected template validates clean and produces no warning.

**Method constraint (state this in the summary, do not paper over it)**: the deployed `.claude/`
tree is deliberately stale and no redeploy is permitted in this run, so an implementation agent
executing right now still follows the *old* deployed template. The acceptance test therefore
instantiates the **new source-store template** by hand into a real summary artifact and validates
it with the **source-store** script (`agent-system/extensions/core/scripts/validate-artifact.sh`),
never the deployed copy. This is the strongest claim available without deploying; it is not an
end-to-end live-dispatch run, and the summary must say so.

**Tasks**:
- [x] Write this task's own implementation summary at
      `specs/940_summary_metadata_header_compliance/summaries/01_summary-header-template-fix-summary.md`
      by instantiating the Phase 2 replacement skeleton literally — all eight metadata bullets,
      all six required sections plus `Plan Deviations` and `Verification`. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/validate-artifact.sh <that summary> summary`
      and confirm exit 0 with a `[PASS]` line and zero `[ERROR]` lines. *(completed: exit 0,
      `[PASS] summary artifact is valid (0 warning(s))`)*
- [x] Run the same command with `--fix` and confirm it is a no-op (no `[FIXED]` line, exit 0) —
      i.e. a compliant artifact never triggers auto-repair. *(completed: confirmed no-op, file
      byte-identical after --fix)*
- [x] Negative control: copy that summary to a scratch path, delete its metadata block, re-run
      without `--fix`, and confirm a readable list of the missing fields plus a terminal `[FAIL]`
      line and exit 1 — a signal, not a crash. *(completed: exit 1, `[FAIL] 4 error(s), 0
      warning(s)`; see summary Verification section for the honest note on why 4 of 6 fields
      showed, not 6)*
- [x] Confirm the gate-out path prints no summary warning for the compliant artifact by running
      the exact command form used at the implementer Stage 6a call site (`if ! bash ... ; then
      echo "WARNING: ..."`) against it and observing no `WARNING:` line. *(completed: no WARNING
      line printed)*
- [x] Record in the summary: the residual noted in the Enforcement Posture section (a whole-directory
      sweep can still warn on historical summaries, per item D), and the fact that no redeploy was
      performed. *(completed: recorded in Follow-ups)*

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Files to modify**:
- `specs/940_summary_metadata_header_compliance/summaries/01_summary-header-template-fix-summary.md` - created

**Verification**:
- Validator exit code 0 and a `[PASS]` line on the real summary artifact, captured verbatim in the
  summary's `## Verification` section.
- Negative control produces exit 1 with the missing-field list, and no `sed:` error.
- `git status --short` shows edits confined to the six files in the Declared Footprint plus this
  task's `specs/` artifacts — no `.claude/**` path appears.

---

## Testing & Validation

- [x] Source-store validator reports `[PASS]` (exit 0) on a summary instantiated from the new
      Stage 6 template.
- [x] Same validator reports a readable `[FAIL]` with the missing-field list (exit 1, no `sed:`
      error) on the negative control.
- [x] `--fix` reaches a terminal line on the historical-artifact crash reproduction.
- [x] `bash -n` clean on `validate-artifact.sh` and on both extracted Stage 6a bash blocks.
- [x] Every `SUMMARY_METADATA` and `SUMMARY_SECTIONS` entry is present in the new Stage 6 template.
- [x] `general-implementation-hard-agent.md` carries no duplicated skeleton.
- [x] No `.claude/**` file modified; no task-number citation added outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/summary-format.md` (Example Skeleton aligned)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (Stage 6 template replaced)
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` (Stage 6a posture)
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` (new Stage 6a)
- `agent-system/extensions/core/scripts/validate-artifact.sh` (`--fix` anchor/insertion repaired)
- `specs/940_summary_metadata_header_compliance/summaries/01_summary-header-template-fix-summary.md`

## Rollback/Contingency

Every change is a text edit to a tracked file under `agent-system/extensions/**`, committed
per-phase. Reverting any single phase is a `git revert` of that phase's commit; no state migration,
no generated artifact, and no deployed file is involved. If Phase 4's `--fix` repair proves harder
to make robust than budgeted, the fallback permitted by research is to make the `--fix` block a
no-op for `summary` artifacts (emitting the existing `Cannot auto-fix` warning) rather than to
leave a crashing repair path in place — Phases 1-3 stand on their own and deliver the item B and
item C outcomes without Phase 4.
