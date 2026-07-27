# Implementation Plan: Task #909

- **Task**: 909 - Resolve the two hard-mode dispatch contexts that carry neither an absolute handoff anchor nor orchestrator_mode
- **Status**: [IMPLEMENTING]
- **Effort**: 1.25 hours
- **Dependencies**: 898
- **Research Inputs**: specs/909_resolve_unanchored_hard_mode_dispatch_contexts/reports/01_handoff-gating-and-fix-branch.md
- **Artifacts**: plans/02_orchestrator-mode-anchor-invariant.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Adopt research branch (a): make every `delegation_context` in
`agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` declare `orchestrator_mode`
explicitly, so the relationship between the gate flag and the absolute handoff anchor
(`task_dir` / `handoff_path`) is checkable by inspection rather than by re-deriving the research
analysis. Three sub-dispatch sites are touched: the H5 divergence-audit dispatch (line 670), the
Stage 6 blocker-research dispatch (line 953), and — to make the invariant actually hold — the H4
adversarial-verification re-dispatch (line 410), which carries the inverse defect (anchor present,
gate flag silent). A compact invariant note plus a mechanical grep check is added to the same file
so a future reader can confirm the property without re-reading the agent contracts.

All three edits are behavior-neutral. `orchestrator_mode` is read with a `// "false"` default at
every consumer, so an absent key and an explicit `false` are already equivalent at runtime; and no
research agent in the repository reads `task_dir` or `handoff_path` out of its delegation context
(verified below), so removing the unused anchor at line 410 changes nothing that executes.

### Research Integration

Key findings carried into this plan from `reports/01_handoff-gating-and-fix-branch.md`:

- `$RESEARCH_AGENT` (resolving to `general-research-hard-agent` for `general`/`meta`/`markdown`
  per the routing block at lines 146-156) **never** writes `.orchestrator-handoff.json`,
  regardless of `orchestrator_mode`. This is a standalone agent-level prohibition in Stage 3.6
  "Scoping Decision" of both `general-research-agent.md` (lines 183-191) and
  `general-research-hard-agent.md` (lines 198-206), corroborated by `contracts/wrap-up.md`
  (implementation-agent-only consumer allowlist) and the Handoff Writers table in
  `docs/architecture/handoff-schema.md` (lines 227-234), which names no research agent in any row.
- Therefore branch (a) — add explicit `orchestrator_mode: false` — is correct, and branch (b) —
  add `task_dir`/`handoff_path` — was rejected as actively misleading, since it would supply an
  anchor the agent is contractually forbidden to use.
- Base mode (`skill-orchestrate/SKILL.md`) already uses this convention at its four sub-dispatch
  sites (drift inspection, drift revision, blocker research, blocker revision — schema rows at
  `handoff-schema.md` lines 711, 725, 750, 766) and was verified consistent. It MUST NOT be edited.

Two facts were verified during planning, beyond the research report:

1. **Line numbers confirmed** by direct grep of the source file: the two named unanchored sites are
   at lines **670** and **953**; the inverse-ambiguity H4 site is at line **410**. The file has
   six `delegation_context:` occurrences total — 364, 410, 439, 515, 670, 953 — where 515 is
   `delegation_context: $dispatch_context`, a variable whose literal JSON is constructed at lines
   487-497 (already `orchestrator_mode: true` with both anchors present).
2. **No research agent consumes the delegation-context anchor.** Grepping every
   `agent-system/extensions/*/agents/*research*.md` for `task_dir`/`handoff_path` yields hits in
   only three files, none of which is a delegation-context read: `general-research-agent.md` and
   `general-research-hard-agent.md` mention `handoff_path` solely as a field they *return* in
   `partial_progress` (pointing at their own research-shaped
   `handoffs/research-handoff-{TIMESTAMP}.md`, explicitly *not* the H9 orchestrator handoff), and
   `founder/agents/deck-research-agent.md` constructs a local `task_dir` shell variable from the
   task number. This is what licenses the anchor removal in Phase 2.

### Decisions on the Three Items Raised by Research

| Item | Decision | Reasoning |
|------|----------|-----------|
| 1. Rationale comment at both sites | **Include** (Phase 1) | Cheap, and it is the actual deliverable: the comment records *why* no anchor is present, so a future weakening of the research-agent exclusion prompts revisiting these sites rather than silently invalidating them. |
| 2. Verification note / mechanical check | **Include** (Phase 3) | Explicitly requested for consideration by the task. Recorded as a compact in-file invariant plus a copy-pasteable grep sequence, so a reviewer confirms the property in seconds instead of re-deriving three agent contracts. |
| 3. H4 re-dispatch at line 410 | **Include** (Phase 2) | Justified below. |

**Justification for including line 410.** It sits inside the declared `file_scope` (same file), and
the task's stated intent is to remove dispatch-context ambiguity in hard mode. Item 2 is the
binding argument: a verification note is only worth adding if the invariant it states is *true*.
Line 410 currently carries the anchor while omitting the gate flag — the exact mirror image of the
defect at 670 and 953 — so any invariant strong enough to be useful ("declare the flag everywhere;
the anchor accompanies `true` and only `true`") fails its own mechanical check while 410 is
untouched. The alternative is a deliberately weakened one-directional invariant that permits
anchor-without-flag, which re-admits the ambiguity the task exists to eliminate. The change at 410
is the same one-line class of edit as the other two sites and is behavior-neutral for the same
reason. This is scope *completion* of the named intent within the named file, not scope expansion
to new files or new mechanisms; if a reviewer disagrees, Phase 2 is independently revertible
without disturbing Phase 1.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in the delegation context; ROADMAP.md was not consulted and MUST
NOT be modified by this task.

## Goals & Non-Goals

**Goals**:
- Every `delegation_context` in `skill-orchestrate-hard/SKILL.md` declares `orchestrator_mode`
  explicitly (`true` or `false`), with no site relying on the implicit `// "false"` default.
- `task_dir` / `handoff_path` appear on a dispatch context if and only if that context declares
  `orchestrator_mode: true`.
- Both properties are stated once in the file and confirmable by a short grep sequence.
- Zero runtime behavior change.

**Non-Goals**:
- Editing `skill-orchestrate/SKILL.md` (base mode) — verified consistent; explicitly off-limits.
- Editing any agent definition, `wrap-up.md`, `handoff-schema.md`, or `skill-base.sh`.
- Changing which agent writes `.orchestrator-handoff.json`, or adding a research-agent handoff
  consumer (`general-research{,-hard}-agent.md` Stage 3.6 names that as a separate follow-up).
- Flipping any existing `orchestrator_mode: true` to `false` or vice versa. In particular, the
  primary research dispatch at line 364 keeps `orchestrator_mode: true`: that value has a second
  consumer beyond the handoff gate (the literature Stage 4a autonomy gate — see the Dual-Consumer
  Note in `handoff-schema.md`), so changing it would be a real behavior change.
- Hand-editing or redeploying the `.claude/` tree (see Rollback/Contingency).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Anchor removal at line 410 breaks an agent that silently reads `task_dir` | H | L | Pre-verified: no research agent in any extension reads either field from its delegation context (see Research Integration item 2). Phase 2 re-runs that grep as a gating precondition and falls back to flag-only + one-directional invariant if it ever finds a consumer. |
| Reviewer reads item 3 as scope expansion | M | M | Justification stated above; Phase 2 is a self-contained commit, revertible without touching Phase 1 or 3. |
| Invariant note drifts from reality as new dispatch sites are added | M | M | The note ships with its own mechanical check, so drift is detectable in one command rather than by re-reading contracts. |
| Task-number citation leaks into the edited file | M | L | `no-task-references-in-deliverables.md` applies; comments cite durable anchors only (`general-research-hard-agent.md` Stage 3.6 "Scoping Decision", the Handoff Writers table in `docs/architecture/handoff-schema.md`). Phase 3 greps the diff for task-number patterns. |
| Explicit `false` at sub-dispatch sites read as a literature-autonomy regression | L | L | No-op: these three sites pass no `lit_flag` at all, so the literature resolver is `LIT_DISABLED` there regardless. Noted in the Phase 3 invariant text so the dual-consumer reader is not misled. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. All three phases edit the same file, so they
are deliberately serialized: a single owner holds
`agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` for the whole task.

### Phase 1: Declare `orchestrator_mode: false` at the Two Unanchored Sites [COMPLETED]

**Goal**: The H5 divergence-audit dispatch and the Stage 6 blocker-research dispatch state the gate
flag explicitly and carry a one-line rationale for the absent anchor.

**Tasks**:
- [x] Edit line ~670 (Stage 4b, three-strikes divergence audit), appending `, orchestrator_mode: false`
      to the inline context so it reads
      `delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "divergence audit $blocker_target", orchestrator_mode: false}` *(completed)*
- [x] Edit line ~953 (Stage 6, blocker escalation), appending `, orchestrator_mode: false` so it reads
      `delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "blocker research", orchestrator_mode: false}` *(completed)*
- [x] Add a short comment immediately above each dispatch (or one comment per site, not a shared
      one — the sites are ~280 lines apart) stating that `$RESEARCH_AGENT` never writes
      `.orchestrator-handoff.json`, per the Stage 3.6 "Scoping Decision" in
      `general-research-agent.md` / `general-research-hard-agent.md` and the Handoff Writers table
      in `docs/architecture/handoff-schema.md`, so no absolute anchor is passed; if that exclusion
      is ever lifted, these sites must be revisited. *(completed)*
- [x] Confirm no task-number citation appears in either comment. *(completed: verified via git diff grep)*

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - two dispatch contexts gain
  `orchestrator_mode: false`; two rationale comments added.

**Verification**:
- `grep -n 'delegation_context: {' agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  shows `orchestrator_mode` present on the lines formerly at 670 and 953.
- `grep -n 'focus_prompt: "divergence audit \$blocker_target"\|focus_prompt: "blocker research"' <file>`
  returns exactly two lines, each also containing `orchestrator_mode: false` and neither containing
  `task_dir` or `handoff_path`.
- `grep -niE 'task [0-9]{2,}|tasks [0-9]{2,}' ` over the diff hunks returns nothing.

---

### Phase 2: Resolve the Inverse Ambiguity at the H4 Verification Re-Dispatch [COMPLETED]

**Goal**: The H4 adversarial-verification re-dispatch matches the other two research sub-dispatches:
gate flag explicit, no anchor.

**Tasks**:
- [x] **Gating precondition** — re-run
      `for f in agent-system/extensions/*/agents/*research*.md; do grep -Hn 'task_dir\|handoff_path' "$f"; done`
      and confirm every hit is a locally-constructed variable or a returned `partial_progress`
      field, not a delegation-context read. If any research agent is found to consume the
      delegation-context anchor, STOP the removal: apply only `orchestrator_mode: false`, keep the
      anchor, and tell Phase 3 to state the weaker one-directional invariant instead.
      *(completed: re-verified; all hits are either the returned `partial_progress.handoff_path`
      in general-research-agent.md/general-research-hard-agent.md, or a locally-constructed
      `task_dir` shell variable in deck-research-agent.md — no delegation-context read found)*
- [x] Edit line ~410 (inside the `adversarial_verified = false` branch) to
      `delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "divergence audit", orchestrator_mode: false}`
      — adding the flag and removing `task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS`. *(completed)*
- [x] Add the same style of rationale comment as Phase 1, additionally noting that the anchor was
      removed because it was unread — and that `handoff_path` in a research agent's *return*
      metadata means its own `handoffs/research-handoff-*.md`, not this file, so passing the
      orchestrator anchor here invited exactly that conflation. *(completed)*
- [x] Leave the plan dispatch at line ~439 and the primary research dispatch at line ~364 untouched
      (both already `orchestrator_mode: true` with both anchors). *(completed: verified unchanged)*

**Timing**: 0.25 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - one dispatch context gains
  `orchestrator_mode: false` and drops the two anchor fields; one rationale comment added.

**Verification**:
- `grep -n 'focus_prompt: "divergence audit"' <file>` returns one line containing
  `orchestrator_mode: false` and neither `task_dir` nor `handoff_path`.
- `grep -n 'TASK_DIR_ABS' <file>` no longer matches inside the H4 branch; the remaining matches are
  the `orchestrator_mode: true` contexts (lines ~364, ~439) and the `dispatch_context` construction
  block (~487-497).
- Nothing else in the H4 branch changed: `git diff` for this phase shows only the one context line
  plus the added comment.

---

### Phase 3: Record the Invariant and Run the Full-File Check [COMPLETED]

**Goal**: The invariant is stated once in the file with a mechanical check, and the whole file
satisfies it.

**Tasks**:
- [x] Add a compact subsection (target: 8-14 lines) titled "Dispatch Context Anchor Invariant",
      placed after Stage 1b (`Resolve Hard-Mode Agent Routing`, ends ~line 179) and before
      Stage 1c, so it precedes every dispatch site in reading order. *(completed)*
- [x] State the two-part invariant: (I1) every `delegation_context` in this file declares
      `orchestrator_mode` explicitly — never relying on the `// "false"` reader default; (I2)
      `task_dir` / `handoff_path` are present if and only if that context declares
      `orchestrator_mode: true`. *(completed)*
- [x] Note the one indirection a checker must follow: `delegation_context: $dispatch_context` in the
      per-phase implement dispatch refers to the JSON literal built immediately above it, which is
      where its `orchestrator_mode` and anchors live. *(completed)*
- [x] Note that `orchestrator_mode` is dual-consumer (handoff-write gate + literature Stage 4a
      autonomy gate, per `docs/architecture/handoff-schema.md`) so a future edit weighs both, and
      that the `false` sub-dispatches pass no `lit_flag`, leaving the literature path disabled there.
      *(completed)*
- [x] Embed the mechanical check as a fenced block:
      `grep -c 'delegation_context: {' FILE` equals
      `grep -c 'delegation_context: {.*orchestrator_mode' FILE`;
      every `orchestrator_mode: true` context line also matches `task_dir` and `handoff_path`;
      every `orchestrator_mode: false` context line matches neither.
      *(completed: altered — anchored the check patterns at line-start
      (`^[[:space:]]*delegation_context: \{`) rather than the plan's unanchored literal, because
      the unanchored form self-matches the check's own quoted grep-pattern text once embedded in
      the same file it inspects, producing a false "I2 VIOLATED" reading. Verified the anchored
      check runs clean against the real file: I1 holds, I2 holds for both true and false sites,
      5 inline sites (2 true, 3 false) as expected.)*
- [x] Cite durable anchors only — section headings and document filenames, never task numbers.
      *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - one new subsection.

**Verification**:
- Run the embedded check against the edited file. Expected end state: 5 inline
  `delegation_context: {` sites, all 5 declaring `orchestrator_mode`; 2 with `true` + both anchors
  (the primary research dispatch and the plan dispatch); 3 with `false` + no anchors (H4
  verification, divergence audit, blocker research); plus the single
  `delegation_context: $dispatch_context` reference whose construction block is `true` + both
  anchors. Total `true`-mode dispatch contexts including the variable: 3.
- `grep -niE '\btasks? [0-9]{2,}\b' agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  returns no *newly added* line (pre-existing markers such as the `772` HTML comments are untouched).
- `git diff --stat` shows exactly one file changed across all three phases.
- `git diff -- .claude/` is empty, confirming no deployed-copy edit.

---

## Testing & Validation

- [ ] Only `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` is modified.
- [ ] `skill-orchestrate/SKILL.md` is byte-identical to its pre-task state.
- [ ] No file under `.claude/` was edited.
- [ ] All 6 `delegation_context` sites declare `orchestrator_mode` (5 inline + 1 via the
      construction block above `$dispatch_context`).
- [ ] The anchor-iff-`true` property holds at every site.
- [ ] No executable logic changed: the diff touches only comment lines, one new documentation
      subsection, and the field lists inside three `delegation_context:` pseudo-code lines. No
      `if`, `jq`, `grep`, or variable assignment in the surrounding Bash blocks is altered.
- [ ] No task-number citation appears in any added line.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- Summary: `specs/909_resolve_unanchored_hard_mode_dispatch_contexts/summaries/03_*-summary.md`
- Handoff: `specs/909_resolve_unanchored_hard_mode_dispatch_contexts/.orchestrator-handoff.json`

## Rollback/Contingency

**Source store and deployment.** `agent-system/extensions/core/` is the source of truth; `.claude/`
is gitignored (`/.gitignore` line 7) and regenerated from it by the extension picker's "Load Core"
sync. As of planning, the deployed
`.claude/skills/skill-orchestrate-hard/SKILL.md` is byte-identical to the source copy.

**This task performs no redeploy.** All verification in every phase runs against the source file —
the edits are documentation and pseudo-code field lists, so there is nothing to execute and no
runtime check that requires the deployed copy. The implementer MUST NOT hand-edit
`.claude/skills/skill-orchestrate-hard/SKILL.md`, and MUST NOT copy the file over as a shortcut
"deploy": the deployed tree picks the change up on the user's next picker "Load Core" sync. That
sync will carry the edit, since this path is absent from `/.syncprotect` (which protects only
`context/repo/project-overview.md` and `output/implementation-001.md`). Until then, a
long-running session holding the old deployed copy in context simply sees the pre-edit text —
harmless, because no behavior depends on it.

**Rollback.** Each phase is a separate commit against a single file. `git revert` the phase commit,
or `git checkout HEAD -- agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` to
discard all three. Phase 2 is independently revertible if the line-410 inclusion is rejected on
review; Phase 3's invariant text would then need its (I2) clause weakened to the one-directional
form, which is the only cross-phase coupling.
