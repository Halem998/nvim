# Implementation Plan: Task #781

- **Task**: 781 - Agent context-overflow safety: checkpoint + handoff before the hard limit
- **Status**: [COMPLETED]
- **Effort**: 4-5 hours
- **Dependencies**: Task 780 (COMPLETED — provides `git-snapshot.sh` for the RED-path checkpoint)
- **Research Inputs**: reports/01_context_overflow_checkpoint_handoff.md
- **Artifacts**: plans/01_checkpoint-before-overflow.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 781 makes every dispatched general implementation and research agent degrade context
overflow into a clean, recoverable handoff instead of a mid-work crash that leaves a stale
handoff and a RED working tree. Research established that the two implementation agents already
have context-pressure monitoring (Stage 4.5) and handoff-writing (Stage 4C), but neither commits
green state or snapshots RED state before handing off; the two general research agents have **no**
context-exhaustion wiring at all; and `git-snapshot.sh` (task 780) is referenced by no agent yet.
This plan (1) defines the CHECKPOINT-BEFORE-OVERFLOW procedure once in a shared pattern doc,
(2) inserts the RED/green commit-or-snapshot branch into the two implementation agents' existing
pressure paths (without duplicating their monitoring), (3) wires detection + monitoring + a
research-shaped handoff into the two research agents, and (4) resolves the research
continuation-consumer scoping question explicitly. Definition of done: all four agents perform a
git checkpoint (commit if green, `git-snapshot.sh` if RED) before writing a handoff on context
pressure, both copies (deployed + extension-source) of every touched file are byte-identical, and
the research-agent handoff shape is documented as intentionally distinct from the H9 schema.

### Research Integration

Integrates `reports/01_context_overflow_checkpoint_handoff.md`. Key findings honored:
- Implementation agents (base + hard) already have Stage 4.5 monitoring and Stage 4C
  handoff-on-pressure; **the gap is a missing RED/green git branch before the handoff** — this
  plan ADDS that branch and does NOT touch their existing monitoring.
- `general-research-agent.md` and `general-research-hard-agent.md` have zero
  `context-exhaustion-detection.md` wiring (task 782 wired only the four lean/cslib domain hard
  agents) — this plan wires detection into both.
- `git-snapshot.sh` is referenced by no agent; the "commit or snapshot" step is a genuinely new
  integration (agents call `bash .claude/scripts/git-snapshot.sh {task}` on the RED path).
- Verified all four target agent files are currently byte-identical between their deployed
  (`.claude/agents/`) and extension-source (`.claude/extensions/core/agents/`) copies, so every
  edit must be mirrored in lockstep.

### Prior Plan Reference

No prior plan. This is the first plan for task 781.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; roadmap consultation skipped. Task 781
is part of the agent-system resilience cluster (pairs with task 780 snapshot mechanism and task
779 fix-forward recovery).

## Goals & Non-Goals

**Goals**:
- Define CHECKPOINT-BEFORE-OVERFLOW (STOP new work -> git checkpoint -> handoff -> clean
  terminate) once as a shared, `@`-referenceable pattern doc.
- Add the RED/green branch (commit if green, `git-snapshot.sh` if RED) to both implementation
  agents' existing Stage 4C pressure paths, recording the snapshot reference in the handoff.
- Wire `context-exhaustion-detection.md` + a monitoring stage + a research-shaped
  handoff-on-pressure flow into both general research agents.
- Add the item-(4) strategic-sorry-skeleton cross-reference to `general-implementation-hard-agent`
  so oversized goal states prefer the skeleton escape valve before a context-pressure handoff.
- Keep every edit mirrored across deployed + extension-source copies and verify parity.
- State the research continuation-consumer scoping decision explicitly (see Non-Goals).

**Non-Goals**:
- **NOT porting `skill-implementer`'s full continuation loop** (loop guard, successor spawn,
  `continuation_context`) into `skill-researcher{,-hard}`. **SCOPING DECISION — Option (A)
  chosen** (see Phase 4). Research agents get detection + clean-stop + a research-shaped
  partial-report handoff, WITHOUT claiming a continuation loop that does not exist. Option (B)
  (adding a minimal continuation consumer to `skill-researcher{,-hard}`) is recorded as a
  possible follow-up task, not done here.
- NOT re-implementing or duplicating the implementation agents' existing Stage 4.5 monitoring —
  only the git-checkpoint branch is added to their handoff path.
- NOT extending `wrap-up.md`'s H9 schema or its consumer allowlist to research. Research
  dispatches are single-pass with no phase list; they use the `handoff-artifact.md` shape +
  `partial` / `handoff_path` return, in both standard and hard mode.
- NOT modifying `git-snapshot.sh` itself (task 780 owns it; agents only call it).
- NOT touching the four lean/cslib domain agents (task 782 scope) or `.opencode/` mirrors (a
  separate system, out of scope per the task description).
- NOT editing task 779's recovery-reference sections; 781's edits stay in distinct
  checkpoint-procedure sections.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Single-copy edit silently reverted by a later sync (the `block-pr-submission.sh` precedent) | H | M | Every phase edits both copies in the same phase; Phase 5 runs a `diff` parity gate across all touched files as a hard exit criterion. |
| Territory collision with task 779, which also edits `general-implementation-hard-agent.md` | H | M | Confine 781's edits to a new checkpoint sub-section inside Stage 4C / Stage 4.5, disjoint from 779's recovery-reference region; enumerate every touched file (below) so the orchestrator can serialize 781 and 779 on that file. |
| Writing research handoffs that nothing auto-consumes ("write with no reader") | M | H | Option (A) explicitly reframes the win as crash-avoidance + a discoverable partial report on disk that a fresh `/research N` builds on; auto-resume is deferred to follow-up Option (B). Documented in Phase 4 so the limitation is intentional, not accidental. |
| `git-snapshot.sh` interaction with the `guard-destructive-git.sh` freshness marker | L | L | The integration is purely additive (agents call the sanctioned snapshot helper, never a destructive git command), so it does not exercise the guard's blocking path; note this in the pattern doc. |
| New pattern doc not discoverable / not loaded | L | M | Agents `@`-reference it by path (works regardless of index); Phase 1 also registers it in `context/index.json` (both copies if a source index exists). |
| Duplicating the RED/green logic inline in four files causes drift | M | M | Define the branch once in the Phase 1 pattern doc; each agent adds a short `@`-reference + a thin inline pointer rather than a full copy of the logic. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Phase 2 (implementation agents) and Phase 3
(research agents) touch disjoint files and may run concurrently.

### Phase 1: Author the shared CHECKPOINT-BEFORE-OVERFLOW pattern doc [COMPLETED]

- **Goal:** Create one authoritative, `@`-referenceable definition of the checkpoint procedure so
  the four agents reference it instead of each inlining the RED/green logic.
- **Tasks:**
  - [x] Create `.claude/context/patterns/checkpoint-before-overflow.md` defining: the STOP
    condition, the git checkpoint branch (`git status --porcelain` -> if dirty AND green
    confirmable: `git commit`; if dirty AND cannot confirm green / confirmed RED:
    `bash .claude/scripts/git-snapshot.sh {task_number}`; if clean: no git action needed), what to
    record in the handoff's Current State (patch path / stash ref / branch name returned by the
    snapshot), the note that this is additive and does not interact with `guard-destructive-git.sh`,
    and the research-shaped handoff guidance (use `handoff-artifact.md` template + `partial` /
    `handoff_path`, NOT `wrap-up.md`'s H9 schema).
  - [x] Mirror the file to `.claude/extensions/core/context/patterns/checkpoint-before-overflow.md`
    (byte-identical).
  - [x] Register the doc in `.claude/context/index.json` with `load_when` scoped to the four target
    agents; mirror to the extension-source index if one exists (check
    `.claude/extensions/core/context/index.json`).
- **Timing:** ~1 hour
- **Depends on:** none
- **Files to modify:**
  - `.claude/context/patterns/checkpoint-before-overflow.md` (NEW)
  - `.claude/extensions/core/context/patterns/checkpoint-before-overflow.md` (NEW)
  - `.claude/context/index.json` (+ extension-source copy if present)
- **Verification:** Both pattern-doc copies exist and `diff` clean; `jq .` parses the updated
  index(es); the doc names `git-snapshot.sh`, the RED/green branch, and the research handoff shape.

### Phase 2: Add the RED/green git checkpoint to both implementation agents [COMPLETED]

- **Goal:** Insert the commit-or-snapshot branch into the existing Stage 4C pressure path of both
  implementation agents (base + hard), plus the item-(4) skeleton cross-reference in the hard
  agent — without duplicating their existing Stage 4.5 monitoring.
- **Tasks:**
  - [x] In `general-implementation-agent.md` Stage 4C ("E. Handoff on Context Pressure"), add a
    new **first** step (before the progress-file/handoff steps): "Git checkpoint (see
    `@.claude/context/patterns/checkpoint-before-overflow.md`)" performing the RED/green branch and
    recording the snapshot reference in the handoff's Current State.
  - [x] Add `@.claude/context/patterns/checkpoint-before-overflow.md` to that agent's Context
    References.
  - [x] In `general-implementation-hard-agent.md` Stage 4C, add the same git-checkpoint-first step;
    ensure the resulting snapshot reference is also written into `.orchestrator-handoff.json`
    (Current State / `blockers` context), keeping the edit in a distinct checkpoint sub-section
    separate from task 779's recovery-reference region.
  - [x] Add `@...checkpoint-before-overflow.md` to the hard agent's Context References.
  - [x] In `general-implementation-hard-agent.md` Stage 4.5, add a one-paragraph item-(4)
    cross-reference: when an oversized goal state belongs to a formal-domain phase with the
    strategic-sorry skeleton mechanism (778) available, prefer landing the skeleton over a
    context-pressure handoff; only hand off if the skeleton cannot be completed within budget.
  - [x] Mirror all edits to the two `.claude/extensions/core/agents/` copies (byte-identical).
- **Timing:** ~1 hour
- **Depends on:** 1
- **Files to modify:**
  - `.claude/agents/general-implementation-agent.md` + `.claude/extensions/core/agents/general-implementation-agent.md`
  - `.claude/agents/general-implementation-hard-agent.md` + `.claude/extensions/core/agents/general-implementation-hard-agent.md`
- **Verification:** `grep` shows the git-checkpoint step and pattern-doc `@`-reference in both
  agents; existing Stage 4.5 text is unchanged; deployed/source copies `diff` clean.

### Phase 3: Wire detection + monitoring into both research agents [COMPLETED]

- **Goal:** Give `general-research-agent.md` and `general-research-hard-agent.md` the
  context-exhaustion-detection reference and a monitoring stage they currently lack entirely.
- **Tasks:**
  - [x] Add `@.claude/context/patterns/context-exhaustion-detection.md` and
    `@.claude/context/patterns/checkpoint-before-overflow.md` to both research agents' Context
    References.
  - [x] Insert a new **Stage 3.5: Context Exhaustion Monitoring** immediately after Stage 3
    (Execute Primary Searches) and before Stage 4 (Synthesize Findings) in both agents, adapting
    the implementation-agent Stage 4.5 signals to research (large tool outputs, repeated
    reads/searches, high tool-call count relative to the model's threshold table).
  - [x] In `general-research-hard-agent.md`, phrase the monitoring stage consistently with its
    Anti-Analysis Contract (monitoring is a STOP-and-checkpoint trigger, not a license to stop
    producing output early).
  - [x] Mirror both edits to the `.claude/extensions/core/agents/` copies (byte-identical).
- **Timing:** ~1 hour
- **Depends on:** 1
- **Files to modify:**
  - `.claude/agents/general-research-agent.md` + `.claude/extensions/core/agents/general-research-agent.md`
  - `.claude/agents/general-research-hard-agent.md` + `.claude/extensions/core/agents/general-research-hard-agent.md`
- **Verification:** `grep -c "context-exhaustion-detection"` returns non-zero in all four research
  files; a "Stage 3.5" monitoring heading exists in both deployed agents; copies `diff` clean.

### Phase 4: Add research-shaped checkpoint + handoff-on-pressure to both research agents [COMPLETED]

- **Goal:** On detected pressure, both research agents STOP, git-checkpoint, write a research-shaped
  partial-report handoff, and return `partial` + `handoff_path` — cleanly, never crashing. Resolve
  and document the continuation-consumer scoping decision.
- **Tasks:**
  - [x] Extend Stage 3.5 (or add Stage 3.6: Handoff on Context Pressure) so that on pressure the
    agent: (a) runs the git checkpoint branch from the pattern doc (research rarely dirties the
    tree, but the branch is included for completeness — commit if green, `git-snapshot.sh` if RED);
    (b) writes the partial findings gathered so far to the report path as a "partial
    report-in-progress"; (c) writes a handoff using the `handoff-artifact.md` template (Immediate
    Next Action = the exact next search/section, Current State, Key Decisions, What NOT to Try,
    Critical Context including any snapshot reference, References); (d) jumps to Stage 7 and returns
    `partial` + `handoff_path` in the metadata.
  - [x] **State the SCOPING DECISION explicitly in both agent files** (a short note in the new
    stage): Option (A) is chosen — research checkpointing is detection + clean-stop +
    research-shaped handoff; it does NOT rely on or claim a `skill-researcher{,-hard}` continuation
    loop (none exists). The handoff's value is crash-avoidance plus a discoverable partial report a
    fresh `/research N` can build on. Do NOT use `wrap-up.md`'s H9 / `.orchestrator-handoff.json`
    schema for research.
  - [x] Record follow-up Option (B) — "add a minimal prior-handoff detection/consumer to
    `skill-researcher` and `skill-researcher-hard` (mirroring `is_successor` from
    `subagent-continuation-loop.md`)" — in this plan's Artifacts & Outputs as a recommended
    follow-up task; do not implement it here.
  - [x] Mirror all edits to the `.claude/extensions/core/agents/` copies (byte-identical).
- **Timing:** ~1 hour
- **Depends on:** 3
- **Files to modify:**
  - `.claude/agents/general-research-agent.md` + `.claude/extensions/core/agents/general-research-agent.md`
  - `.claude/agents/general-research-hard-agent.md` + `.claude/extensions/core/agents/general-research-hard-agent.md`
- **Verification:** Both research agents contain a pressure-handoff stage that writes a handoff and
  returns `partial` + `handoff_path`; the Option (A) scoping note is present; no reference to
  `wrap-up.md`/`.orchestrator-handoff.json` was added to research agents; copies `diff` clean.

### Phase 5: Dual-copy parity gate and integration verification [COMPLETED]

- **Goal:** Guarantee every touched file is byte-identical across deployed + extension-source
  copies and that the checkpoint procedure is coherently wired across all four agents.
- **Tasks:**
  - [x] Run `diff` between deployed and extension-source copies of every touched file (four agents,
    the pattern doc, and the index); require zero differences.
  - [x] `grep` all four agents for `git-snapshot.sh` and `checkpoint-before-overflow` to confirm the
    new integration is present in each.
  - [x] Confirm `git-snapshot.sh` remains unmodified (`git diff --stat` shows no change to
    `.claude/scripts/git-snapshot.sh` or its source copy).
  - [x] Confirm task 779's recovery-reference regions in `general-implementation-hard-agent.md` were
    not modified (edits confined to the checkpoint sub-section).
- **Timing:** ~30-45 minutes
- **Depends on:** 2, 3, 4
- **Files to modify:** none (read-only verification; fix-and-recheck if a parity gap is found)
- **Verification:** All `diff`s clean; all `grep`s hit; `git-snapshot.sh` untouched; territory
  boundary with 779 respected.

## Testing & Validation

- [x] `diff .claude/agents/X.md .claude/extensions/core/agents/X.md` is empty for all four target
  agents.
- [x] `diff` is empty for both copies of `checkpoint-before-overflow.md`.
- [x] `jq . .claude/context/index.json` (and the extension-source index, if present) parses.
- [x] `grep -l "git-snapshot.sh" .claude/agents/general-*.md` lists all four agents.
- [x] `grep -l "context-exhaustion-detection" .claude/agents/general-research*.md` lists both
  research agents.
- [x] Implementation agents' existing Stage 4.5 monitoring text is unchanged (`git diff` shows only
  additive checkpoint edits).
- [x] Research agents return `partial` + `handoff_path` on the pressure path and contain no
  `wrap-up.md` / `.orchestrator-handoff.json` reference.
- [x] `.claude/scripts/git-snapshot.sh` and its source copy are unmodified.

## Artifacts & Outputs

- `.claude/context/patterns/checkpoint-before-overflow.md` (NEW) + extension-source copy
- Updated `.claude/context/index.json` (+ extension-source copy if present)
- Updated `general-implementation-agent.md` (+ source) — RED/green checkpoint in Stage 4C
- Updated `general-implementation-hard-agent.md` (+ source) — RED/green checkpoint + skeleton
  cross-ref
- Updated `general-research-agent.md` (+ source) — monitoring + research-shaped handoff
- Updated `general-research-hard-agent.md` (+ source) — monitoring + research-shaped handoff
- `specs/781_agent_context_overflow_checkpoint_handoff/summaries/01_*-summary.md` (on /implement)
- **Recommended follow-up task (Option B, not implemented here):** add a minimal prior-handoff
  detection/consumer to `skill-researcher` and `skill-researcher-hard` so research handoffs are
  auto-resumed, mirroring `subagent-continuation-loop.md`'s `is_successor` shape.

### Enumerated touched files (for orchestrator serialization)

| File | Phase | Cross-task overlap |
|------|-------|--------------------|
| `.claude/context/patterns/checkpoint-before-overflow.md` (+core) | 1 | none (new) |
| `.claude/context/index.json` (+core if present) | 1 | none |
| `.claude/agents/general-implementation-agent.md` (+core) | 2 | none |
| `.claude/agents/general-implementation-hard-agent.md` (+core) | 2 | **task 779** (keep edits in disjoint checkpoint sub-section) |
| `.claude/agents/general-research-agent.md` (+core) | 3, 4 | none |
| `.claude/agents/general-research-hard-agent.md` (+core) | 3, 4 | none |
| `.claude/scripts/git-snapshot.sh` | (called only) | task 780 (do not modify) |

## Rollback/Contingency

All edits are additive markdown sections plus one new pattern doc. To revert: `git checkout` the
four agent files and their source copies, delete `checkpoint-before-overflow.md` (both copies), and
restore `context/index.json`. Because no runtime code or `git-snapshot.sh` is modified, reverting is
a clean file-restore with no state migration. If a dual-copy parity gap is discovered post-merge,
re-run the Phase 5 `diff` gate and mirror the missing edit.
