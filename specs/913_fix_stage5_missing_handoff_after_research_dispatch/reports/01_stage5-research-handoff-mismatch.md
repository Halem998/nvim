# Research Report: Task 913

- **Task**: 913 - fix_stage5_missing_handoff_after_research_dispatch
- **Started**: 2026-07-26T00:00:00Z
- **Completed**: 2026-07-26T00:00:00Z
- **Effort**: ~2 hours (research)
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 5, Stage MT-4)
  - `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (Stage 5, H4/H5/Stage 6)
  - `agent-system/extensions/core/agents/general-research-agent.md`, `general-research-hard-agent.md`
  - `agent-system/extensions/core/agents/general-implementation-agent.md`, `general-implementation-hard-agent.md`
  - `agent-system/extensions/core/agents/planner-agent.md`
  - `agent-system/extensions/core/skills/skill-researcher/SKILL.md`, `skill-planner/SKILL.md`, `skill-implementer/SKILL.md`
  - `agent-system/extensions/core/scripts/skill-base.sh` (`skill_write_orchestrator_handoff`, `skill_gate_completion_claim`)
  - `agent-system/extensions/core/scripts/command-gate-out.sh`
  - `agent-system/extensions/core/docs/architecture/handoff-schema.md`
  - `agent-system/extensions/core/context/formats/return-metadata-file.md`
  - `agent-system/extensions/core/context/contracts/wrap-up.md`
  - Live artifact survey: `specs/**/.orchestrator-handoff.json` (status-value census across ~200 files)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The bug is real, but **broader than "research only"**: `docs/architecture/handoff-schema.md`
  itself documents, as current architecture, that base-mode `skill-researcher`, `skill-planner`,
  and `skill-implementer` **all** fail to write `.orchestrator-handoff.json` — "a pre-existing
  gap, out of scope" of whatever change last touched that file. The only active writer today is
  `general-implementation-hard-agent.md` (and its cslib/lean hard-mode counterparts). The helper
  function built to let any skill write one, `skill_write_orchestrator_handoff` in
  `scripts/skill-base.sh`, is defined but has **zero callers**.
- Confirmed independently at the agent level: `general-research-agent.md` and
  `general-research-hard-agent.md` both carry an explicit standalone prohibition (Stage 3.6
  "Scoping Decision") against ever writing `.orchestrator-handoff.json`, "independent of
  `orchestrator_mode`." Neither `skill-researcher/SKILL.md` nor `skill-planner/SKILL.md` nor
  `skill-implementer/SKILL.md` (the base, non-hard skills) contain any call to
  `skill_write_orchestrator_handoff` or any other handoff-writing step.
- **The plan-dispatch symmetry claim in the task description does not hold under the current
  source.** `planner-agent.md` has zero mentions of `.orchestrator-handoff.json`, and
  `skill-planner/SKILL.md`'s Stage 7 postflight only calls `update-task-status.sh` — it never
  writes a handoff either. A live-artifact survey of every `.orchestrator-handoff.json` under
  `specs/**` (≈200 files) shows exactly **zero** files with `status: "planned"` from any
  currently-in-scope task, and only one historical `status: "planned"` file at all (an archived
  task, containing only the bare fields of an ad-hoc, non-conformant shape predating the current
  documented schema). Every currently-live handoff with real content is `status: "implemented"`,
  written by a hard-mode implementation dispatch. The one observed run described in the task
  (planner "DID write a valid handoff") is not reproducible from the current source and should be
  treated as either a stale/leftover file from a prior cycle, or evidence the run in question used
  a code path not represented in the source tree today — not as proof of a currently-designed
  planner-writes-handoff behavior.
- `skill-orchestrate-hard`'s H4 (adversarial verification re-dispatch), H5 (divergence audit), and
  Stage 6 (blocker research) sub-dispatches **were already fixed** by a prior task (visible inline
  as committed comments citing the Stage 3.6 prohibition): all three now pass
  `orchestrator_mode: false` and omit the `task_dir`/`handoff_path` anchor, and their code paths
  explicitly skip Stage 5's handoff read ("Increment cycle_count. Loop continues." — no "read
  handoff (Stage 5)" instruction). The task description's premise that these three sub-dispatches
  "hit this branch on every invocation" is **outdated relative to the current source** and should
  not be re-broken by this fix.
- What remains genuinely broken, and is the correct scope for this fix:
  1. **Single-task mode, primary Stage 4 dispatches** in both `skill-orchestrate/SKILL.md` and
     `skill-orchestrate-hard/SKILL.md`: the `not_started`→research, `researched`→plan, and
     `planned`/`implementing`→(base-mode) implement dispatches all still pass
     `orchestrator_mode: true` with `task_dir`/`handoff_path`, and route unconditionally into
     Stage 5's missing-handoff branch — which has no concept of "this phase's writer is not
     expected to produce a handoff" and treats every miss identically as a suspected defect.
  2. **Multi-task mode Stage MT-4 step 1** has the identical defect and is strictly worse: on a
     missing handoff it either marks the task `failed_tasks` outright or (after a prior
     infra-discrimination patch) defers it for a retry — it never consults any success signal, so
     a task that genuinely succeeded (research, plan, or base-mode implement) is misclassified as
     failed or endlessly re-dispatched.
- A working, already-precedented fix mechanism exists in the codebase: `command-gate-out.sh` (the
  non-orchestrator postflight path used by plain `/research`, `/plan`, `/implement`) **already
  reads `.return-meta.json`'s own `status` field** as its sole source of truth for the dispatch
  outcome, and drives its defensive status correction from it. `.return-meta.json` is written by
  every research, plan, and implement dispatch (base and hard mode alike) per each skill's own
  Stage 7 contract, and its schema (`context/formats/return-metadata-file.md`) already carries
  `status`, `artifacts[]`, and (for implement) `metadata.phases_completed`/`phases_total` — the
  same fields Stage 5 currently only reads from the handoff.

## Context & Scope

The task asks: when should a missing `.orchestrator-handoff.json` after a dispatch be treated as
an error vs. a contractually-expected, benign outcome, and how should Stage 5 (and its multi-task
and hard-mode counterparts) be changed to stop mis-stranding tasks after a successful research (or
plan, or base-mode implement) dispatch. The task explicitly asked not to presume the fix and to
verify the plan/research asymmetry claim rather than assume it — that verification produced a
different picture than the task description assumed (see Executive Summary, bullet 3).

Per the binding SOURCE-STORE RULE, all findings below are drawn from
`agent-system/extensions/core/` (the source of truth); `.claude/` is the disposable, gitignored
deploy artifact and was not used as an information source for this report.

## Findings

### Who currently writes `.orchestrator-handoff.json` (ground truth)

`docs/architecture/handoff-schema.md`'s own "Handoff Writers" table (lines 227-234) states this
plainly and is corroborated independently by reading each skill/agent source file:

| Writer | Status | Corroborating source |
|--------|--------|----------------------|
| `general-implementation-hard-agent.md` (H9 Stage 5) | Active — the only active writer today | Agent's own Stage 5 "Step 1: Write the orchestrator handoff", writes via the Write tool to the absolute `handoff_path` in its delegation context |
| cslib/lean hard-mode implementation agent counterparts | Active | Mirror the core H9 wrap-up (not independently re-verified in this pass; documented as such) |
| `skill_write_orchestrator_handoff` (`scripts/skill-base.sh`) | Defined, unreferenced | `grep -rln skill_write_orchestrator_handoff` across the whole `agent-system/` tree returns only its own definition file, the two orchestrate SKILL.md files (which only reference it in an explanatory comment about *why a PostToolUse hook can't see its writes*), the handoff-schema doc, and the location-validation hook — no skill or agent actually calls it |
| Base-mode `skill-researcher`, `skill-planner`, `skill-implementer` | Not implemented | Verified: none of the three SKILL.md files, nor `planner-agent.md`, nor `general-implementation-agent.md` (base), contain a call to `skill_write_orchestrator_handoff` or any Write-tool instruction targeting `.orchestrator-handoff.json` |
| `general-research-agent.md` / `general-research-hard-agent.md` | Explicitly prohibited | Stage 3.6 "Scoping Decision" (both files): "Do NOT use `wrap-up.md`'s H9 schema or `.orchestrator-handoff.json` for research — that schema and its consumer allowlist are implementation-agent-only." |

A live census of every `.orchestrator-handoff.json` under `specs/**` (≈200 files, both active and
`specs/archive/`) confirms this at the artifact level: essentially all files with the current,
full `orchestrator-handoff-v1` schema (`$schema`, `phase`, `files_modified`, `decisions_made`,
`dead_ends`, `continuation_context`, etc.) carry `status: "implemented"`. Two files with
`status: "researched"` and one with `status: "planned"` exist, but all three are old,
schema-non-conformant, ad-hoc JSON shapes (extra invented fields like `research_decisions`,
`residual_risks`, `next_command` not in any documented schema) — evidence of pre-contract drift
from before the current Stage 3.6 prohibition and Handoff Writers table were written, not evidence
of a currently-functioning research/plan handoff path.

### The plan-dispatch symmetry question (explicitly asked for verification)

**Verified false as currently documented and implemented.** The task description's premise — "in
the observed run the planner DID write a valid handoff... planner-agent and research agents appear
to differ here" — does not hold against the current source:

- `planner-agent.md` contains **zero** occurrences of `.orchestrator-handoff.json` or `handoff`
  writing instructions of any kind.
- `skill-planner/SKILL.md` Stage 7 ("Update Task Status (Postflight)") calls only
  `update-task-status.sh postflight`; Stage 8 links artifacts into `state.json`. No handoff write
  appears anywhere in the file.
- The Handoff Writers table lists base-mode `skill-planner` in the same "Not implemented" row as
  `skill-researcher` and `skill-implementer` — the documentation itself does not distinguish
  planner from researcher.

The most plausible explanations for the described observed run are: (a) the `.orchestrator-handoff.json`
Stage 5 read for the `researched` state actually picked up a **stale file from a previous cycle**
(the file existed at the right path but was not fresh — this exact failure mode is why Stage 5 has
a staleness gate comparing mtime against `dispatch_start_ts`, added by a prior task), or (b) the
observed run predates the current source and used since-superseded planner behavior. Either way,
this fix should **not** assume planner writes handoffs, and should **not** special-case plan
dispatches differently from research dispatches — both are equally "not implemented" per the
documented table, and both should route through whatever missing-handoff recovery mechanism this
task adds. Base-mode implement dispatches share the identical gap and should also route through
the same mechanism (only hard-mode implement is a genuine active writer).

### Stage 5 structural mismatch (confirmed, live)

`skill-orchestrate/SKILL.md` Stage 5 (lines ~464-692) is a single branch entered for "after every
Agent tool invocation" with no phase-awareness. On missing/stale handoff it:

1. Logs `"ERROR: Skill did not write orchestrator handoff... This may mean orchestrator_mode was
   not propagated correctly, or the handoff was written outside the task directory."` — both
   explanations are categorically wrong for a research, plan, or base-mode-implement dispatch,
   where "no handoff" is the contractually correct outcome, not a propagation or misplacement
   fault.
2. Runs infra-failure discrimination: since a successful research/plan/base-implement dispatch
   writes real output (subagent-authored text) and touches `.return-meta.json` inside the
   dispatch window, `dispatch_was_transport_error=false` and `meta_touched=true` — so the
   corroboration condition for an infra-exempt cycle (`transport_error=true AND meta_touched=false`)
   is false, and **the cycle is charged as a genuine work cycle** against `MAX_CYCLES` even though
   real, successful work was done.
3. Runs the phase-marker recovery grep against `${TASK_DIR}/plans/*.md` — for a research dispatch
   this glob resolves to nothing (no plan exists yet), so it emits a `0/0` diagnostic that adds
   noise without recovering anything meaningful; the grep is a no-op-with-log rather than a crash,
   but it is dead weight on this branch.
4. **Performs no postflight status update whatsoever.** `skill_preflight_update` had already set
   `state.json` status to `"researching"` before the dispatch. Nothing in the missing-handoff
   branch calls `skill_postflight_update`, so status remains stuck at `"researching"`.
5. The next loop iteration's Stage 3a reads `current_status = "researching"`, which Stage 4's
   `researching` handler treats as an in-flight state owned by another session and exits
   immediately with a warning — exactly the stranding behavior described in the task.

`skill-orchestrate-hard/SKILL.md` Stage 5 (lines ~721+) has the **same shape** for the same reason
(near-identical branch structure, same diagnostic wording, same absence of a return-meta fallback)
for its own primary `not_started`/`researched`/`planned` dispatches — this is not limited to base
mode.

### `skill-orchestrate-hard`'s H4/H5/Stage 6 sub-dispatches: already fixed, do not re-break

Contrary to the task description's framing, these three specific dispatch sites were already
patched by a prior task and now correctly avoid Stage 5 entirely for their research forks:

- **H4** (adversarial verification re-dispatch, `skill-orchestrate-hard/SKILL.md` ~line 440): sets
  `delegation_context: {..., orchestrator_mode: false}` and passes no `task_dir`/`handoff_path`.
  Inline comment: "`$RESEARCH_AGENT` never writes `.orchestrator-handoff.json`, per the Stage 3.6
  'Scoping Decision'... so the anchor here was unread — removed rather than kept." The branch ends
  with "Increment cycle_count. Loop continues." — no handoff read.
- **H5** (divergence audit, ~line 703): identical `orchestrator_mode: false`, identical reasoning
  comment, identical "Increment cycle_count. Loop continues" ending.
- **Stage 6** (blocker research escalation, ~line 991): identical `orchestrator_mode: false`,
  identical comment, identical non-Stage-5 continuation.

These three fixes should be treated as the working precedent for *how to route around Stage 5 when
a dispatch is known in advance never to produce a handoff* — but they solve it by **not passing
`orchestrator_mode: true` at all**, which only works because none of these three sub-dispatches
needs a *status transition* out of the read (they're forks whose only job is to feed findings back
into a subsequent re-dispatch, not to move `state.json` from `researching`→`researched`). The
primary Stage 4 dispatches this task must fix **do** need a status transition (that's the entire
point of Stage 5's postflight-update block), so the H4/H5/Stage-6 "just don't ask for a handoff"
pattern is not directly reusable there — the primary dispatches still need *some* channel to learn
the outcome.

### Multi-task mode: same defect, worse consequence

`skill-orchestrate/SKILL.md` Stage MT-4 step 1 (~lines 1157-1189) handles a missing handoff for
research, plan, and implement tasks identically within the same loop. Its only recovery path is the
infra-discrimination branch (comparing `.return-meta.json`'s mtime, never its `status` content):
if the dispatch was not a corroborated transport failure — which is the case for every successful
research/plan/base-implement dispatch — the task is unconditionally logged as "missing handoff
charged as genuine... Marking `failed_tasks`." Unlike single-task Stage 5, MT-4 has historically had
**no retry at all** for this case (per its own inline comment: "This branch is the worse of the two
manifestations of the defect... it has historically had no retry at all"). A successfully-completed
research or plan dispatch in multi-task mode is therefore misclassified as an outright failure, not
merely stranded.

### The precedented fix mechanism: `.return-meta.json` as a secondary outcome channel

`scripts/command-gate-out.sh` (the CHECKPOINT 2 postflight used by the plain, non-orchestrator
`/research`, `/plan`, `/implement` commands) already solves exactly this problem for its own
callers, without ever touching `.orchestrator-handoff.json`:

```bash
meta_file="${task_dir}/.return-meta.json"
if [ ! -f "$meta_file" ]; then
  echo "WARNING: .return-meta.json not found..." >&2
  exit 0
fi
skill_status=$(jq -r '.status' "$meta_file")
# ... maps skill_status -> expected_status, applies defensive correction via update-task-status.sh
```

`.return-meta.json` is written by **every** research, plan, and implement dispatch — base and hard
mode alike — per each skill's own Stage 7 ("Write metadata to
`specs/{NNN}_{SLUG}/.return-meta.json`"). Its schema
(`context/formats/return-metadata-file.md`) already carries the fields Stage 5 needs:

- `status` (`researched|planned|implemented|partial|failed|blocked`) — the same vocabulary Stage 5
  currently reads from the handoff's `.status`.
- `artifacts[]` (`type`/`path`/`summary`) — same shape as the handoff's `artifacts[0]`, sufficient
  to drive `skill_link_artifacts`.
- `metadata.phases_completed` / `metadata.phases_total` — present for implement dispatches
  (`general-implementation-agent.md` Stage 7 explicitly lists these as agent-specific metadata
  fields), giving Stage 5's completion-claim gate (`skill_gate_completion_claim`) the same
  phase-accounting signal it currently only trusts from the handoff. `plan_markers_verified` is not
  part of the return-meta schema (it is a hard-mode-only, handoff-only marker-verification
  concept) — a return-meta-derived synthetic status for an "implemented" claim would correctly read
  `plan_markers_verified="absent"`, which is exactly the pre-designed fallback case in
  `skill_gate_completion_claim`'s existing three-case logic (Case 3: allow only if
  `plan_markers_verified=true`, otherwise refuse) — no new gate logic is needed, it already handles
  an absent marker correctly and conservatively.

This makes `.return-meta.json` a ready-made secondary outcome channel Stage 5 can consult
specifically inside its missing/stale-handoff branch, without weakening the existing staleness gate,
stray-handoff sweep, or infra-failure discrimination logic that already live there — those are all
orthogonal correctness properties Stage 5 already got right in prior work.

## Decisions

- Treat the plan-dispatch "symmetry" claim in the task description as **refuted** by the current
  source and the live-artifact census; the fix must not special-case plan differently from
  research, and should also cover base-mode implement (which the Handoff Writers table places in
  the identical "Not implemented" bucket).
- Treat `skill-orchestrate-hard`'s H4/H5/Stage-6 sub-dispatches as **already correctly fixed** and
  out of this task's remaining scope — do not touch their `orchestrator_mode: false` /
  no-anchor / no-Stage-5-read shape.
- Do not pursue candidate (b) from the task description (making research agents write handoffs
  after all) — it would require amending the standalone Stage 3.6 prohibition in both research
  agents plus the Handoff Writers table and the wrap-up.md consumer allowlist, a much larger and
  differently-motivated contract change than what a missing-handoff Stage 5 fix calls for, and it
  would still leave base-mode plan/implement dispatches (which are not prohibited from writing a
  handoff, they simply were never implemented to) unaddressed unless *those* skills were changed
  too — multiplying the blast radius for no corresponding benefit over reading a file they already
  write.

## Recommendations

1. **Make Stage 5's missing/stale-handoff branch phase-aware via a `.return-meta.json` fallback
   read** (single-task `skill-orchestrate/SKILL.md`, and the mirrored branch in
   `skill-orchestrate-hard/SKILL.md`): before emitting the "did not write a handoff" error
   diagnostic, read `${TASK_DIR}/.return-meta.json`'s `.status` field (same file the infra-failure
   discrimination code in that same branch already stats for mtime, so this is additive to an
   existing read, not a new file dependency). If `.return-meta.json` itself is missing/stale (per
   the same window-comparison the infra check already performs), keep today's error path
   unchanged — that combination is a genuine defect signal.
2. **Branch on the recovered status** the way `command-gate-out.sh` does: `researched` → drive the
   existing `skill_postflight_update ... research ... researched` path (same as Stage 5's
   handoff-present branch); `planned` → the plan equivalent; `implemented` → route through the
   existing `skill_gate_completion_claim` using return-meta's `metadata.phases_completed` /
   `metadata.phases_total` and `plan_markers_verified="absent"` (its already-correct fallback
   case); `partial`/`failed`/`blocked` → preserve today's behavior (no false success is invented).
   This reuses Stage 5's existing postflight-dispatch `case` statement rather than adding a second,
   parallel one.
3. **Retire the "orchestrator_mode was not propagated correctly, or the handoff was written outside
   the task directory" diagnostic wording** for the case where return-meta corroborates a genuine
   success — reserve that message text for when return-meta is ALSO missing/stale, i.e. the case
   that remains a real defect signal.
4. **Skip the phase-marker recovery grep when the dispatch phase is `research`** (no plan file can
   exist yet) — it currently runs unconditionally in the missing-handoff branch and produces a
   meaningless `0/0` reading for research dispatches; gate it on `phase == "plan" || phase ==
   "implement"`, or more simply on `plan_path` being non-empty as the branch already does, just
   without also emitting the "no plan file available" diagnostic as if that were surprising for a
   research phase.
5. **Do not charge `MAX_CYCLES` for a return-meta-corroborated success recovered this way** —
   the current infra-exemption path only avoids charging `cycle_count` for corroborated *infra*
   failures; a recovered genuine success should also not consume a work cycle, since real forward
   progress happened. Add a second, distinct exemption path (or fold into the existing
   `infra_exempt_cycle` flag's sibling) for "handoff missing but return-meta confirms success,"
   charged as a normal, successful cycle-completing dispatch rather than skipped or double-counted.
6. **Apply the identical `.return-meta.json` fallback to Stage MT-4 step 1** in multi-task mode,
   replacing its current "no return-meta status check at all, just infra-mtime-then-failed_tasks"
   logic — this is the higher-severity instance since it currently misclassifies successes as
   outright failures rather than merely stranding status.
7. **Update `docs/architecture/handoff-schema.md`'s Handoff Writers table** once the fix lands, to
   note that Stage 5/MT-4 now treat the documented "Not implemented" writers as an expected,
   return-meta-recoverable case rather than leaving the table's "pre-existing gap, out of scope"
   framing stale.
8. Keep all edits inside `agent-system/extensions/core/**` (plus `specs/state.json`/`TODO.md`/this
   task's own directory) per the binding SOURCE-STORE RULE; `.claude/**` must not be touched
   directly.

## Risks & Mitigations

- **Risk**: a return-meta-based recovery could mask a genuinely broken agent that silently failed
  to write proper output but still touched `.return-meta.json` with a stale/incorrect status.
  **Mitigation**: the existing staleness-window comparison (mtime vs. `dispatch_start_ts`) already
  guards this for the handoff; apply the identical window check to `.return-meta.json` before
  trusting its `.status` — this is exactly what the infra-discrimination code in the same branch
  already does for mtime, just not yet for content.
- **Risk**: widening what Stage 5 reads on the missing-handoff path could violate the "Context
  Flatness Constraint" (MUST NOT read reports/plans/summaries during the loop). **Mitigation**:
  `.return-meta.json` is explicitly designed to be small (status/artifacts/metadata only, no report
  prose) and is already read for its mtime in this exact branch — reading its `.status` field adds
  negligible tokens and does not violate the constraint's intent (it names reports/plans/summaries/
  continuation-handoff *content*, not the metadata file).
- **Risk**: fixing Stage 5 might tempt a broader fix that also makes base-mode planner/implementer
  start writing handoffs (candidate b), which would touch more files than necessary and risks
  drifting from the deliberate current design (only hard-mode gets full wrap-up discipline).
  **Mitigation**: recommendation 1-6 above deliberately treats "no handoff" from base-mode
  dispatches as a permanent, expected condition to route around, not a gap to close by making more
  agents write handoffs.

## Appendix

- Live-artifact status census command used: iterating `find specs -iname
  ".orchestrator-handoff.json"` and extracting `.status` via `jq` across all matches (~200 files).
- Handoff Writers table: `agent-system/extensions/core/docs/architecture/handoff-schema.md` lines
  227-234.
- Stage 3.6 Scoping Decision text: `agent-system/extensions/core/agents/general-research-agent.md`
  and `general-research-hard-agent.md`, both near their respective Stage 3.6 sections.
- `command-gate-out.sh` full postflight logic: `agent-system/extensions/core/scripts/command-gate-out.sh`.
- Return metadata schema: `agent-system/extensions/core/context/formats/return-metadata-file.md`.
