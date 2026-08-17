# Research Report

**Task**: fix_handoff_identity_and_loop_guard_resume_deadlock
**Started**: 2026-08-11
**Completed**: 2026-08-11
**Effort**: large (6 coupled defects, 2 engines, 3 extensions)
**Dependencies**: None (this task is itself a dependency of the separately-tracked unsound-territory-assertion defect per the task description's "shared root cause" section)
**Sources/Inputs**: codebase (agent-system/extensions/core, cslib, lean), specs/state.json task description
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Every file:line citation in the task description was checked against the current source
  store and is accurate, with one soft nuance: Defect 5's quoted assertion text ("No other
  agent is running concurrently — any claim of a concurrent dispatch is false") does not appear
  verbatim anywhere in the source; the closest real text is structurally equivalent but weaker
  (see Defect 5 section). The "base line 1518" precedent citation is directionally right (that
  pattern of behavior exists) but the specific line discusses multi-task stage-sharing, not
  loop-guard staleness — a minor mischaracterization, not a hard drift.
- Defect A: confirmed. No writer or reader anywhere in core, cslib, or lean attaches a
  per-dispatch identity to `.orchestrator-handoff.json`. The `phase` schema field is a
  four-value lifecycle enum (`research|plan|implement|revise`), useless for discriminating
  plan-phase 19 from plan-phase 20 — both are `"implement"`. `cslib-implementation-hard-agent.md`
  additionally hardcodes the literal filename rather than reading `handoff_path` from its
  delegation context, unlike `lean-implementation-hard-agent.md` and core — this is an
  independent, pre-existing latent gap the identity fix must also close.
- Defect B: confirmed deadlocked in both engines, and the investigation surfaces the actual
  crux: `session_id` is generated exactly once per `/orchestrate` command invocation (at GATE
  IN) and never regenerated mid-run, so "same session_id" already IS a reliable same-invocation
  signal. Case 3 forbids gating on it anyway — and correctly so, because the loop guard's
  entire purpose is a **per-task, cross-invocation** cumulative budget that must survive being
  re-invoked; gating on session_id mismatch would silently reset that budget on every
  re-invocation, which is the exact abuse vector the guard exists to prevent. The fix is not
  "distinguish new invocation from resumed turn" (that distinction already exists via
  session_id and is correctly *not* wired to a reset) — it is "budget exhaustion has no
  sanctioned override path at all." Recommendation: `cycle_count` stays per-task/cumulative by
  design; the deadlock is closed by adding an explicit, operator-typed override (not an
  automatic detector signal, and not a session_id gate).
- Defects 5 and 6: both real and reproducible against current source. Defect 5's fix belongs in
  this task (it shares Defect A's root cause and its own fix touches the same dispatch-context
  construction site). Defect 6 is a distinct, smaller ordering hazard that can be fixed
  independently and does not require the identity mechanism — recommend keeping it in this task
  given the small size and shared file territory, but flag it as separable if scope needs to
  shrink.
- The shared "report != termination" model should live as one new pattern file, referenced (not
  restated) from every fix site — proposed path and content given below.

## Context & Scope

Full task description read via `jq -r '.active_projects[] | select(.project_number == 33) | .description' specs/state.json` (not reproduced here — see that command's own output, which is long, evidence-bearing, and authoritative). This report verifies its claims against `agent-system/extensions/**` (the source store; `.claude/**` is a disposable deploy artifact and was not treated as ground truth for any claim) and extends it with the writer/reader map, candidate-mechanism evaluation, and the crux analysis for Defect B that the task explicitly asked this research phase to resolve.

## Findings

### Citation Verification

All cited lines checked directly against `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (1817 lines) and `skill-orchestrate/SKILL.md` (2684 lines):

| Citation | Verified content |
|---|---|
| hard:142 | `HANDOFF_PATH_ABS="${TASK_DIR_ABS}/.orchestrator-handoff.json"` — exact |
| hard:225, 231 | `MAX_CYCLES=13`; `loop_guard_file="${TASK_DIR}/.orchestrator-loop-guard"` — exact |
| hard:247-315 | `loop-guard-staleness:begin/end` sentinel block, 3 OR-combined signals (max_cycles drift, plan_version drift, mtime age) — exact |
| hard:317-327 | Unconditional `cycle_count=$(jq -r '.cycle_count // 0' ...)` resume read, reached only if the guard survived the staleness block above — exact |
| hard:414 | `while [ "$cycle_count" -lt "$MAX_CYCLES" ]` — exact |
| hard:956-961 | Co-maintenance comment on `append_detected_defect` twin — exact |
| hard:985-1030 | Stage 5 staleness gate, `handoff_mtime -lt stale_window_start` only — exact, and confirms the defect: a **newer** mtime always passes |
| hard:1267-1345 | Handoff-present read block — confirmed no phase/dispatch-id field is ever read; `phase` is not among the fields listed even as optional here |
| hard:1563-1581 | Stage 7 MAX_CYCLES branch, prints resume instruction — exact |
| hard:1663-1666 | `rm -f "$loop_guard_file"` / `rm -f "$churn_file"`, "Only on successful completion. Leave loop guard and churn state on partial for resume." — exact |
| hard:1686-1688 | Co-maintenance requirement text — exact |
| base:91-96, 112-130 | Ephemeral/no-freshness-check framing — exact, **with one addition not mentioned in the task description**: base mode already has a **log-only, non-gating** `guard_session_id != session_id` comparison (base:126-128) that emits an INFO line and is explicitly commented "NEVER a gate". This is directly relevant to the Defect B crux below. |
| base:1263-1266, 1298 | Both say "Run /orchestrate $task_number to continue." — exact |
| base:1286 | `rm -f "$loop_guard_file"` only inside the clean-exit branch — exact |
| base "line 1518" precedent | The literal precedent text ("Hard-mode finding, recorded, not acted on") exists at that location, but its actual subject is MT-stage sharing between engines, not loop-guard staleness. The citation is right that this *pattern of recorded-not-acted-on asymmetry* exists in the file; it is not a citation of a loop-guard-specific precedent. |
| Defect 5's quoted assertion | Not found verbatim anywhere in `skill-orchestrate-hard/SKILL.md`, `context/contracts/territory.md`, `anti-analysis.md`, `wrap-up.md`, or `orchestrator-discipline.md`. See Defect 5 section for what the current text actually says. |

**scripts/test-session-runtime-files.sh** confirmed at `agent-system/extensions/core/scripts/test-session-runtime-files.sh` (not under `scripts/tests/` — a naming inconsistency with its siblings, unrelated to this task). Its Case 3 (lines 158-189) extracts the 3 lines following the `guard_session_id.*!=.*session_id` anchor in `skill-orchestrate/SKILL.md` (`LOOP_GUARD_SKILL`) and the `churn_session_id.*!=.*session_id` anchor in `skill-orchestrate-hard/SKILL.md` (`CHURN_SKILL`), and fails the suite if that block contains `hard-fail|abort|exit|return 1` or lacks an `INFO:` line. Confirmed exactly as described: this is a narrow, regex-anchored test against a specific 3-line window, not a broad prohibition on ever reading `session_id`.

### Defect A: Handoff Writer/Reader Map

Full grep for `orchestrator-handoff.json` across `agent-system/extensions/**` (superset of the task description's blast-radius list, all confirmed present):

**Core**: `agents/general-implementation-agent.md`, `agents/general-implementation-hard-agent.md`, `agents/general-research-agent.md`, `agents/general-research-hard-agent.md`, `context/contracts/territory.md`, `context/contracts/wrap-up.md`, `context/formats/return-metadata-file.md`, `context/patterns/checkpoint-before-overflow.md`, `context/patterns/context-protective-lead.md`, `context/patterns/infra-failure-discrimination.md`, `context/patterns/lit-stage4a-flow.md`, `context/schemas/orchestrator-handoff-schema.json`, `context/standards/git-staging-scope.md`, `context/standards/orchestrator-runtime-files.md`, `docs/architecture/handoff-schema.md`, `docs/architecture/orchestrate-state-machine.md`, `hooks/validate-handoff-location.sh`, `scripts/check-runtime-file-tracking.sh`, `scripts/orchestrate-dry-run-report.sh`, `scripts/orchestrate-recover-outcome.sh`, `scripts/orchestrate-triage-classify.sh`, `scripts/reconcile-task-status.sh`, `scripts/skill-base.sh`, `scripts/validate-handoff.sh`, `scripts/tests/test-handoff-reader-parity.sh`, `scripts/tests/test-orchestrate-triage-classify.sh`, `scripts/tests/test-reconcile-handoff-status.sh`, `scripts/tests/test-validate-handoff-location.sh`, `skills/skill-implementer-hard/SKILL.md`, `skills/skill-orchestrate-hard/SKILL.md`, `skills/skill-orchestrate/SKILL.md`, `skills/skill-team-implement/SKILL.md`.

**cslib**: `agents/cslib-implementation-agent.md`, `agents/cslib-implementation-hard-agent.md`, `agents/cslib-research-agent.md`, `skills/skill-cslib-implementation-hard/SKILL.md`, `skills/skill-cslib-research/SKILL.md`.

**lean**: `agents/lean-implementation-hard-agent.md`, `context/contracts/anti-analysis.md`, `skills/skill-lean-implementation-hard/SKILL.md`.

**literature**: `merge-sources/claudemd.md` (a doc reference only, not a reader/writer — no action needed there).

**Key asymmetry found (new finding, not in the task description)**: `lean-implementation-hard-agent.md:263-264` explicitly instructs "Write to the ABSOLUTE path given in your delegation context as `handoff_path`. If that field is absent, use `{task_dir}/.orchestrator-handoff.json`" — i.e. it already resolves the write location dynamically from the dispatch context, matching `wrap-up.md`'s H9 contract. `cslib-implementation-hard-agent.md:296` ("**Step 2: Write `.orchestrator-handoff.json`**") hardcodes the bare literal filename with no reference to a dynamic `handoff_path`. This means cslib is currently **not** wired to honor a non-default handoff path at all. Any per-dispatch identity scheme that changes `HANDOFF_PATH_ABS`'s construction (e.g. to a phase-scoped filename) will silently fail to reach cslib's writer unless `cslib-implementation-hard-agent.md` is also updated to read `handoff_path` dynamically — this is a prerequisite fix, not an optional one, for whichever identity mechanism is chosen.

**Candidate mechanism evaluation** (per the binding "must work when predecessor is still live" constraint):

1. **Phase-scoped filename + pointer file** (e.g. `.orchestrator-handoff-phase-{P}.json` plus a `.orchestrator-handoff-current` pointer, or simply have the orchestrator construct `HANDOFF_PATH_ABS` per-dispatch as `${TASK_DIR_ABS}/.orchestrator-handoff-phase-${next_phase}.json` and pass that exact absolute path via `handoff_path` in the dispatch context). **This is the mechanism that survives a live predecessor**: even if the phase-19 agent wakes and writes again, it writes to `.orchestrator-handoff-phase-19.json`, a path the phase-20/21 successor's Stage 5 gate is not reading from — there is no slot to overwrite. Precedent already exists in the codebase for phase-scoped filenames: `wrap-up.md`'s own `continuation_path` field's documented example is `specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TS}.md` — the naming convention is not novel, only its application to the JSON handoff itself is. Interaction with the stray-handoff sweep: the sweep (hard:1035-1067) checks exactly two fixed OUTSIDE-task-dir paths (repo root and `specs/` root) — it is orthogonal to an in-task-dir filename change and needs no modification for that reason, though it should gain matching stray-pattern coverage for the new filename shape as a follow-on hardening, not a blocker. Interaction with `orchestrator-runtime-files.md`'s "Durable provenance (tracked)" classification and its `check-runtime-file-tracking.sh` consumer: both currently assume a single static filename per task; a phase-scoped scheme changes this from "one tracked file per task" to "N tracked files per task, one per phase" — the standard's prose and any script iterating expected filenames need updating, not just the schema.
2. **Embedded dispatch-id/phase in content, verified by the orchestrator against what it dispatched**: writes stay at the single static path, but the orchestrator captures the phase number (`next_phase`, already a shell variable at hard:672) into the dispatch context, requires the written handoff to echo it back as e.g. `"dispatch_phase": <int>`, and Stage 5 rejects (treats as stale/absent) any handoff whose `dispatch_phase` doesn't equal the phase it just dispatched. **This does NOT close the defect on its own against a live predecessor**: a woken phase-19 agent, still holding its OWN dispatch context from when it was originally invoked, would echo back `dispatch_phase: 19` — a value that is internally consistent with what IT was told, not evidence of when it wrote. The check only works if the orchestrator remembers, across the whole run, which phase-content values are still "current" — which degenerates back to needing a second axis (a monotonic dispatch counter or timestamp-window check) layered on top. Content-only identity is necessary but not sufficient.
3. **Recommended combination**: content-embedded identity (a monotonic `dispatch_seq` integer minted by the orchestrator itself immediately before each `Agent` call, unrelated to phase number, so a resumed agent cannot forge or predict it — it never appears in what the agent was told before its first dispatch) is the discriminator, and Stage 5 compares the READ handoff's `dispatch_seq` against the `dispatch_seq` the orchestrator itself just minted for THIS cycle, rejecting any mismatch regardless of mtime. This is stronger than approach 1 alone (no dependency on filename uniqueness or an extra pointer file) and stronger than approach 2 alone (the successor, not the predecessor, is the source of truth for what counts as current — a woken predecessor cannot know the successor's freshly-minted `dispatch_seq` in advance). It is the only one of the three that is demonstrably correct against a still-live, still-writing predecessor, per the task's binding acceptance criterion. The planning phase should decide the exact wire format (a top-level `dispatch_seq` field is the minimal-diff option) and whether it fully replaces or supplements the mtime gate (supplements is safer — mtime the-guard-was-clearly-ancient case is still worth keeping as a second line of defense, at low cost).

### Defect B: Loop Guard Resume Deadlock — Crux Analysis

Confirmed deadlocked in both engines by direct code read (not just the task description's claim): hard mode's `while [ "$cycle_count" -lt "$MAX_CYCLES" ]` (hard:414) and base mode's structurally identical loop guard begin false immediately whenever `cycle_count` was persisted at `MAX_CYCLES` by the prior invocation's Stage 8 partial-exit path (hard:1663-1666 / base:1286, both `rm -f` only on success).

**session_id granularity, resolved**: `session_id` is minted exactly once, by `common_session_id()` (`scripts/lib/common.sh:126-133`, `sess_$(date +%s)_$(6-hex-random)`), at `command-gate-in.sh` — i.e. once per `/orchestrate` **command invocation**, full stop. Both `SKILL.md` files read it once near the top (`session_id=$(echo "$delegation_context" | jq -r '.session_id')`, hard:113) into a shell variable that persists for that invocation's entire run, including every cycle of its `while` loop. There is no runtime concept of "a later conversational turn within the SAME invocation acquiring a different `session_id`" — the variable simply doesn't get re-read mid-run. Therefore: **same `session_id` on the guard file ⟺ genuinely the same command invocation; different `session_id` ⟺ genuinely a new command invocation**, with no ambiguity between the two.

This resolves the crux differently than the task description frames it. The two are not hard to distinguish — they already are trivially distinguished. The reason Case 3 still forbids gating on the (perfectly reliable) mismatch signal is that the loop guard is **deliberately a per-task, cross-invocation budget**: its whole purpose is to survive being re-invoked, so that an operator (or an automated retry loop) cannot bypass `MAX_CYCLES` by simply running `/orchestrate N --hard` again and again. Base mode's own existing comment (base:118-121) states this directly: "SESSION_ID is regenerated per /orchestrate invocation, while this guard is explicitly designed to survive across conversational turns... The real same-task concurrency guard is task-lock.sh's acquire/heartbeat/release mutex, not session_id equality." Gating a reset on session_id mismatch would silently zero the budget on *every single re-invocation*, defeating the guard's entire reason for existing — which is precisely why Case 3's regression test exists to block exactly that "consistency" refactor.

**Answer to the explicit question — is `cycle_count` per-invocation or per-task**: per-task, cumulative across invocations, by design, and this should not change. The actual bug is narrower than "how do we tell invocations apart" (already solved) — it is "there is no sanctioned way to raise or clear an exhausted per-task budget once it is genuinely, currently, correctly at its cap." Today's Stage 7 message ("Run /orchestrate $task_number --hard to resume...") is simply false once `cycle_count == MAX_CYCLES`, because Stage 2's unconditional resume read (reached — correctly — because none of the 3 staleness signals fire on a budget-exhausted-but-current guard) restores exactly the value that makes the loop immediately false again.

**Recommended fix shape** (for the planning phase to size, not adopted here):
- Do NOT fold budget exhaustion into the 3-signal `loop-guard-staleness` detector. That detector's whole design premise is "this guard's *content* no longer reflects current reality" (schema drift, plan drift, stale age) — silently archiving and reinitializing at `cycle_count=0`. A budget-exhausted guard is the opposite: it is completely current and accurate; archiving it silently would be the same "make it consistent" hazard Case 3 exists to prevent, just moved into a 4th signal instead of the session_id block.
- Add a distinct, explicit, operator-typed override — e.g. a new flag on `/orchestrate` (`--continue-budget` or similar; naming is a planning decision) that, when present AND `cycle_count >= MAX_CYCLES` is read at Stage 2, archives the exhausted guard aside (same `mv` pattern already used by the staleness detector, for auditability) and reinitializes at `cycle_count=0`, logging loudly (`[orchestrate] Budget was exhausted (13/13); operator requested continuation via --continue-budget — archived to ...`). Absent the flag, Stage 2 should refuse to silently loop zero times — it should exit immediately with a clear, honest message naming the actual required command, rather than todays' misleading "just run this again."
- Apply the same override symmetrically to Stage 2 (read), Stage 7 (exit message — must name the actual working command, not the current no-op one), and Stage 8 cleanup stays unchanged (still "leave the guard on partial" — correct, since the guard's job is to persist across exactly this kind of gap).
- Base-mode asymmetry: base mode needs the same explicit-override mechanism (it has the identical deadlock, arguably worse since it has zero self-healing today). Whether base mode ALSO gains the general 3-signal `loop-guard-staleness` detector is a **separate** decision this task does not need to make — the override mechanism above is orthogonal to that detector and can be added to base mode's much simpler Stage 2/7/8 shape without first deciding that question. Record the "not deciding this now" choice explicitly in both files, matching the base file's own existing "recorded, not acted on" precedent style (base:~1517-1522, see Citation Verification above for the caveat on that specific line's actual subject).

### Defect 5: Unsound Territory Assertion

The task description's quoted sentence is not literal source text; it is a fair paraphrase of the *effect* of two true, separate statements combining into a false compound claim when read by a dispatched agent:

1. `skill-orchestrate-hard/SKILL.md`'s own framing (lines 14-20, and the "Parallel Wave Dispatch: DISABLED" block at ~811-819): "Parallel-wave dispatch... is disabled... the orchestrator dispatches exactly one phase per cycle and blocks on its return — no simultaneous/background `Agent` calls." This statement is **true and correctly scoped** — it is a claim about what *this orchestrator instance's own Stage 4* does (never issues two concurrent `Agent` calls), not a claim about the state of the world.
2. `context/contracts/territory.md`'s "Territory Declaration Template" (lines 71-82), which is injected into dispatch context and includes no analogous caveat — it presents `owned_files`/`read_only_files`/`forbidden_files`/`Phase` as an apparently exhaustive, static picture with no "you may observe evidence of other work; if so, stop and report" clause.

The unsoundness is that (1)'s true, narrowly-scoped claim gets read by a dispatched agent as license to interpret (2)'s territory declaration as a *global* no-concurrency guarantee — which is false whenever a predecessor is woken (self-armed watcher, or an operator resume) while this dispatch is in flight, exactly the corroborating live evidence the task description cites (phase-19 agent waking during phase-21's flight, observing five foreign commits and a running `lake build`).

Confirmed this is the same root cause as Defect A (both are instances of "report treated as termination" — see Shared Model section below), and the fix site is the same file (`context/contracts/territory.md`'s Territory Declaration Template) plus wherever `skill-orchestrate-hard/SKILL.md`'s dispatch-context construction (hard:672-686, currently has no `territory` key at all in `dispatch_context`) is extended to actually inject it — worth noting the current per-phase `dispatch_context` JSON literal doesn't include a `territory` object today, so wiring Defect 5's fix is not purely a wording change to `territory.md`; it also requires adding the injection call site in Stage 4's per-phase dispatch, which does not exist yet. Given the shared root cause and overlapping fix territory (both land in `skill-orchestrate-hard/SKILL.md` Stage 4 and `territory.md`), Defect 5 belongs in this task rather than split out.

Recommended reframing direction (confirmed feasible, not adopted here): replace the implicit global claim with an explicit, checkable, locally-scoped one — "this dispatch owns these files; other work may exist; if you observe evidence of work you did not do, STOP and report it rather than proceeding or dismissing it" — matching exactly what the phase-19 agent's own correct, contract-defying behavior already did in the observed near-miss.

### Defect 6: Unverified Phase Marker on Infra Termination

Confirmed real by reading `wrap-up.md`'s "Build-Green Invariant" (line ~150s, "phases marked [COMPLETED]... continues to pass") together with the "Incremental Commit Discipline" section immediately above it: phase-heading `[COMPLETED]` promotion happens as one of several commit-trigger events *during* a dispatch's ongoing incremental-commit discipline, while the terminal `.orchestrator-handoff.json` write happens once, "before terminating," at the very end. These are not ordered relative to each other by any stated rule — an agent that marks a phase heading complete and then dies (API limit, infra failure) before reaching its terminal handoff write leaves the plan file ahead of the handoff by construction, exactly as observed (marker claimed 21/23, handoff still at 20).

This also confirms the mechanism named in the task description: Stage 4's per-phase dispatch determines `next_phase` via a heading-status scan (hard:606-664 region, matching "H1: Per-phase dispatch — phase $next_phase (heading-scan)" at hard:672) that trusts the plan file's own markers — so an unconfirmed `[COMPLETED]` marker really does cause the successor phase to be dispatched over unconfirmed work, independent of any handoff-identity fix.

Recommendation on scope: Defect 6 is real, but its fix (either reorder wrap-up so the handoff write precedes any marker promotion, or make the heading-scan cross-check the marker against the handoff's own `phases_completed`) is small, touches `wrap-up.md` and the Stage 4 heading-scan logic, and does not depend on the identity mechanism chosen for Defect A. Given the task description already asks "decide whether it belongs here or as its own," and given it shares no hard technical dependency with Defects A/B/5 (only file-territory proximity), it is reasonable either way. Recommend keeping it in this task on efficiency grounds (same files touched, same co-maintenance review pass would need to happen either way) unless the plan phase judges the combined scope too large for one implementation pass — in which case splitting Defect 6 out cleanly is low-risk.

### Shared "Report != Termination" Model

Recommend a single new file, `agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md`, stating (approximate final content, to be refined during planning/implementation):

> **The system must never treat "a dispatched agent reported a result" as "that agent has
> terminated."** A dispatch can resume after reporting — via a stale watcher/monitor it armed
> before reporting, or via an operator-initiated resume of that same dispatch — and continue
> running, committing, and writing files concurrently with whatever the orchestrator dispatches
> next. Every mechanism that assumes single-writer exclusivity after a report is read must be
> built to tolerate a still-live predecessor, not merely a finished one. Two known instances of
> this root cause: (1) a woken predecessor's late handoff write always carries a newer mtime
> than the successor's dispatch window, so any mtime-only staleness gate is structurally blind to
> it; (2) a woken predecessor reading a global "no concurrent agent" territory assertion has no
> way to recognize its own liveness as the exception the assertion failed to name.

This file should be referenced (via a one-line pointer, not restated) from: `skill-orchestrate-hard/SKILL.md`'s Stage 5 staleness-gate comment block, `skill-orchestrate/SKILL.md`'s equivalent, `context/contracts/territory.md`'s Territory Declaration Template, and `context/standards/orchestrator-runtime-files.md`'s handoff tracking-rationale entry (which currently only names the git-restoration hazard and needs its rationale corrected regardless, per the task's acceptance criteria).

## Decisions

- The identity mechanism for Defect A should combine an orchestrator-minted, unforgeable
  `dispatch_seq` content field with Stage 5 comparing it against the value minted for the
  current cycle — not a bare phase number, and not a filename change alone. A phase-scoped
  filename remains attractive as a *defense-in-depth* addition since it also produces a durable
  per-phase audit trail, but the content-based `dispatch_seq` check is the load-bearing piece
  because it is the only mechanism verified correct against a still-live predecessor.
- `cycle_count` remains per-task, cumulative across invocations. This is not a new decision —
  it is the existing, deliberate design (protected by Case 3), and Defect B's fix must not
  disturb it.
- Defect B's fix is an explicit, operator-typed, loudly-logged override — never an automatic
  detector signal and never a session_id gate.
- Defect 5 stays in this task (shared root cause and overlapping fix territory with Defect A).
  Defect 6 is recommended to stay in this task on efficiency grounds but is genuinely separable
  if scope needs to shrink.
- `cslib-implementation-hard-agent.md`'s hardcoded handoff filename (not reading `handoff_path`
  from delegation context, unlike lean and core) must be fixed as part of Defect A's blast
  radius — it is a prerequisite for the chosen identity mechanism to actually reach cslib.

## Risks & Mitigations

- **Risk**: changing `HANDOFF_PATH_ABS` construction (if the phase-scoped-filename component is
  adopted) touches every writer/reader in the blast-radius list above; a partial rollout leaves
  some extension silently reading/writing the old static path. **Mitigation**: land the
  content-based `dispatch_seq` check first (works at the existing static path, zero filename
  changes required), verified independently; treat filename-scoping as an optional
  defense-in-depth follow-on, not a blocking requirement for closing Defect A.
- **Risk**: an explicit budget-override flag could itself be silently abused (operator scripts
  always passing `--continue-budget`), defeating the guard the same way session_id-gating would
  have. **Mitigation**: this is explicitly out of scope to prevent — the guard's job is to make
  runaway *automatic* re-invocation impossible, not to prevent a deliberate, visible, typed
  operator decision. This mirrors how MAX_CYCLES itself was never meant to be un-overridable by
  a human.
- **Risk**: Case 3's regex-anchored extraction (`extract_block`, 3 trailing lines from the
  mismatch anchor) is brittle to any reformatting of the surrounding comment block, even when
  the intended behavior is preserved. **Mitigation**: keep the mismatch comparison's 3-line
  shape stable when editing nearby text for the Defect B fix; run
  `bash agent-system/extensions/core/scripts/test-session-runtime-files.sh` (deployed path
  `.claude/scripts/test-session-runtime-files.sh`) after any edit near that anchor, not only at
  the end.

## Context Extension Recommendations

- **Topic**: dispatch report-vs-termination model. **Gap**: no existing context file states
  this as a named, reusable principle — it currently lives only inside prose scattered across
  the task description and various file-local comments. **Recommendation**: create
  `context/patterns/dispatch-report-not-termination.md` as described above; this is itself one
  of this task's acceptance criteria, not merely a nice-to-have.
- **Topic**: `orchestrator-runtime-files.md`'s two-class (ephemeral/durable) tracking policy.
  **Gap**: the "Durable provenance (tracked)" justification for `.orchestrator-handoff.json`
  needs a rewrite regardless of which identity mechanism is chosen, since its current rationale
  ("a documented freshness gate already protects against exactly that scenario") is simply false
  for the late-writer hazard. **Recommendation**: update in the same pass as the schema/gate
  changes, not as an afterthought — this is already acceptance criterion 2.

## Appendix

Search/verification commands used (representative, not exhaustive):
- `jq -r '.active_projects[] | select(.project_number == 33) | .description' specs/state.json`
- `grep -rl "orchestrator-handoff.json" agent-system/extensions/`
- `grep -n "guard_session_id" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `grep -n "^common_session_id" -A 10 agent-system/extensions/core/scripts/lib/common.sh`
- `sed -n` range reads of `skill-orchestrate-hard/SKILL.md` and `skill-orchestrate/SKILL.md` at
  every cited line range, and of `context/contracts/territory.md`,
  `context/standards/orchestrator-runtime-files.md`, `docs/architecture/handoff-schema.md`,
  `context/schemas/orchestrator-handoff-schema.json`, `scripts/validate-handoff.sh`,
  `scripts/test-session-runtime-files.sh`.
