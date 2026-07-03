# Implementation Plan: Task #772

- **Task**: 772 - Make hard-mode orchestrator a pure dispatcher (strip implementation capability)
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: 774 (DONE — commit `41cd982d4` landed the mirrored implementer fix), 778 (DONE — skeleton/sorry_inventory schema). Serialize BEFORE 779 (shared file, no state.json edge).
- **Research Inputs**: specs/772_hardmode_orchestrator_pure_dispatcher/reports/01_orchestrator-pure-dispatcher.md
- **Artifacts**: plans/01_orchestrator-pure-dispatcher.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 772 makes `skill-orchestrate-hard` *structurally* incapable of doing implementation work
itself, forcing every phase through a delegated agent. Five documented requirements are
implemented as edits to `.claude/skills/skill-orchestrate-hard/SKILL.md` (deployed copy) and its
byte-identical mirror `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`. All edits
are confined to clearly delimited regions so the two later tasks that also edit this file — 779
(5th CONTRACT SLOT in `build_hard_mode_prompt_context()`) and 773 (orchestrator-discipline
contract + burnout breaker at the top of the state-machine loop) — compose cleanly afterward.
Base `skill-orchestrate` is explicitly OUT OF SCOPE. Definition of done: both file copies are
byte-identical, contain zero build/test/compiler invocations, restrict tools structurally +
by prose, disable parallel-wave dispatch, and route per-phase / skeleton handoffs as ongoing
progress rather than task completion.

### Research Integration

The plan honors all five SCOPE DECISIONS from report `01_orchestrator-pure-dispatcher.md`:
1. **Item 1** — remove `Edit` from `allowed-tools` (line 4); unused in body, pure subtraction.
2. **Item 2** — scope Bash via `Bash(cmd:*)` frontmatter patterns for the 12 commands actually
   used (`jq, mkdir, mv, rm, ls, sort, tail, grep, cat, date, echo, source`) PLUS an explicit
   prose "Forbidden Bash Operations" list; the file currently issues zero build/test commands, so
   this is additive hardening. Multi-pattern-per-line syntax is unverified in this codebase and
   MUST be smoke-tested (see Risks).
3. **Item 3** — DISABLE the "Parallel Wave Dispatch (optional H7)" section (lines 323-347) so
   blocking single-phase dispatch is unambiguous; update the Key Differences table row (line 541)
   and the H7 overview bullet (line 20).
4. **Item 4** — widen the documented Read allowlist to FOUR categories (handoff/state files,
   plan+report files, `.claude/context/contracts/*`, `.claude/docs/architecture/*`) rather than
   the literal three, reconciling the skill's own Context References (22-31) and the H4 research-
   report grep (233-252); forbid implementation source explicitly.
5. **Item 5** — (A) replace the `next_phase=$((phases_completed + 1))` integer-increment at
   line 283 with the heading-scan selection mirroring 774's `skill-implementer-hard` fix, and add
   skeleton-exhaustion routing that derives the follow-up task list from
   `sorry_inventory[].follow_up_task` (the actually-shipped `wrap-up.md` field — NOT the
   unpopulated top-level `.follow_up_tasks` that 774's Stage 3b optimistically reads); (B) gate
   the Stage 5 postflight status transition (450-461) on `phases_completed >= phases_total` so a
   single per-phase `"implemented"` (skeleton or not) handoff does not flip the whole task to
   `completed` after phase 1.

### Prior Plan Reference

No prior plan for task 772.

### Roadmap Alignment

No ROADMAP.md consulted for this dispatch (meta task; roadmap flag not set).

### Territory: Exact Sections / Line-Regions Task 772 Touches

All regions apply identically to BOTH copies (`.claude/skills/...` and
`.claude/extensions/core/skills/...`). Line numbers are pre-edit references from the current
543-line file.

| Region | Lines (pre-edit) | Item | Phase | Notes / composition boundary |
|--------|------------------|------|-------|------------------------------|
| Frontmatter `allowed-tools` | 4 | 1, 2, 4 | 1 | Single-line rewrite (Edit removal + Bash/Read scoping) |
| H7 overview bullet | 20 | 3 | 3 | Reword to reflect parallel-wave disabled |
| NEW "## Tool Constraints" section | inserted after line 21 (before Context References) | 2, 4 | 2 | New delimited section; 773 must not overwrite |
| Per-phase `next_phase` selection | 283 | 5A | 4 | Replace integer-increment with heading-scan |
| NEW skeleton-exhaustion routing block | inserted after line ~296 (within Per-Phase Dispatch handler) | 5A | 4 | Reads `sorry_inventory[].follow_up_task` |
| `build_hard_mode_prompt_context()` | 305-319 | — | — | **772 does NOT edit this function** (reserved for 779's 5th CONTRACT SLOT) |
| H7 Parallel Wave Dispatch section | 323-347 | 3 | 3 | Removed/disabled |
| Stage 5 postflight gate + logging | 450-461 | 5B | 5 | Make hard-mode-specific; gate on phases_completed |
| Key Differences table H7 row | 541 | 3 | 3 | Update to "Disabled (single-phase only)" |

**Do NOT touch** (reserved for serialized siblings): `build_hard_mode_prompt_context()` body
(305-319, task 779); Stage 2/3 top-of-loop region 124-197 (task 773). Where 772 adds the new
"## Tool Constraints" section, it is a standalone block that 773's Context-References additions and
773's burnout breaker can be inserted around without overlap.

## Goals & Non-Goals

**Goals**:
- Structurally prevent the orchestrator from editing files (remove `Edit`) and from running
  build/test/compiler commands (scope Bash + prose forbid-list).
- Guarantee exactly one blocking, foreground `Agent` implement call per cycle by disabling the
  parallel-wave dispatch path.
- Restrict + document orchestrator Reads to the four legitimate categories; forbid implementation
  source.
- Accept green-building skeleton handoffs as per-phase progress; route skeleton-exhausted plans to
  a terminal state that enumerates pending follow-up tasks, never looping to `MAX_CYCLES`.
- Prevent premature whole-task `completed` transition on a single per-phase handoff.
- Keep both file copies byte-identical; keep all edits in delimited regions for 779/773.

**Non-Goals**:
- Modifying base `skill-orchestrate` (explicitly out of scope).
- Editing `wrap-up.md`, `anti-analysis.md`, or `skill-implementer-hard` (778/774 territory;
  preserved assets — must not regress).
- Adding the 779 recovery-contract 5th CONTRACT SLOT or the 773 burnout breaker.
- Changing `MAX_CYCLES`, churn detection (Stage 4b confirmed to not misfire on skeletons), or the
  H4 adversarial gate behavior.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Multi-pattern `Bash(cmd:*)` / `Read(path/*)` on one `allowed-tools:` line may not parse/enforce (no in-repo precedent) | H | M | Smoke-test in Phase 1: invoke the skill and confirm a disallowed Bash (`echo lake build`) / Read is denied; keep prose forbid-list as behavioral fallback regardless of frontmatter enforcement. |
| Disabling H7 removes an advertised feature (lines 20, 541) without explicit sign-off | M | L | Report already surfaced tradeoff; plan disables per literal item-3 wording and documents removal in Key Differences ("Disabled") rather than silently deleting the capability concept. |
| 772 and 779 both edit this file; concurrent edit collision in `build_hard_mode_prompt_context()` | H | M | 772 explicitly does NOT edit that function; Territory table records the boundary; recommend landing 772 before 779. |
| Deriving follow-up list from `.follow_up_tasks` (774's unpopulated read) instead of `sorry_inventory[].follow_up_task` would route to an empty list | M | M | Phase 4 derives from `sorry_inventory[].follow_up_task` with dedup; documents the divergence so both skeleton-exhaustion paths agree. |
| Stage 5 gate (Part B) touches core state-transition logic not named in the 5 items — scope-creep risk | M | L | Frame as required-for-item-5 (a per-phase "implemented" handoff cannot be "accepted as progress" if the next line flips the task to completed); keep to a single conditional gate, no new fields. |
| Dual-copy drift after edits | H | L | Phase 6 mirrors every edit and asserts `diff -q` returns empty before completion. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 1, 2, 3, 4, 5 |

Phases are sequential: all edit the same single file (deployed copy), so they run one at a time to
avoid intra-file edit collisions. Phase 6 mirrors the accumulated edits to the core copy and
verifies. Within Phases 1-5, edit only the deployed copy
(`.claude/skills/skill-orchestrate-hard/SKILL.md`); Phase 6 performs the dual-copy sync.

---

### Phase 1: Frontmatter tool restriction (Items 1, 2, 4 structural) [COMPLETED]

**Goal**: Rewrite the single `allowed-tools:` line (line 4) to remove `Edit`, scope `Bash` to the
12 orchestration commands actually used, and scope `Read` to the four allowed path categories;
then smoke-test that the multi-pattern syntax enforces as expected.

**Tasks**:
- [x] Replace line 4 `allowed-tools: Agent, Bash, Read, Edit` with a scoped form, e.g.:
      `allowed-tools: Agent, Bash(jq:*), Bash(mkdir:*), Bash(mv:*), Bash(rm:*), Bash(ls:*), Bash(sort:*), Bash(tail:*), Bash(grep:*), Bash(cat:*), Bash(date:*), Bash(echo:*), Bash(source:*), Read(specs/**), Read(.claude/context/contracts/*), Read(.claude/docs/architecture/*)`
      *(deviation: altered — see next item; landed as documented prose-fallback)*
- [x] Smoke-test the multi-pattern syntax: confirm an allowed command (`jq`) and an allowed Read
      (a `specs/**` path) succeed, and a disallowed command (`lake`/`lean`) and a disallowed Read
      (a `lua/**` source path) are denied. If multi-pattern-per-line does NOT enforce, fall back to
      `Agent, Bash, Read` on line 4 and rely on the Phase 2 prose forbid-list as the sole gate,
      recording the finding in the summary. *(completed: no in-repo precedent found for
      multi-pattern-per-line `Bash(cmd:*), Bash(cmd2:*)...` or `Read(path/*)` scoping in any
      skill's `allowed-tools:` frontmatter — grepped all `.claude/skills/*/SKILL.md`,
      `docs/guides/creating-skills.md`, `docs/guides/creating-commands.md`; only single-pattern
      precedent exists (`skill-git-workflow: Bash(git:*)`). settings.json's `permissions.allow`
      array is a different mechanism (JSON list, not frontmatter). No sandboxed harness is
      available to this agent to runtime-verify Claude Code's frontmatter tool-scope enforcement
      independent of a live invocation. Per the plan's own risk mitigation, took the documented
      fallback: `allowed-tools: Agent, Bash, Read` (Edit removed), relying on the Phase 2 prose
      forbid-list as the sole behavioral gate.)*
- [x] Confirm `Edit` is absent and referenced nowhere else in the body (only mention is the
      dispatched agent's contract at line 312, which stays). *(completed: grep confirms zero
      remaining "Edit" references anywhere in the file)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate-hard/SKILL.md` — line 4 only.

**Verification**:
- `grep -n '^allowed-tools:' .claude/skills/skill-orchestrate-hard/SKILL.md` shows no `Edit`.
- Smoke-test outcome recorded (enforced vs. prose-fallback).

---

### Phase 2: Tool Constraints prose section (Items 2, 4 documented) [COMPLETED]

**Goal**: Add a single delimited `## Tool Constraints (Pure Dispatcher)` section after the
hard-mode additions bullets (after line 21, before `## Context References`) documenting the
Bash forbid-list and the four-category Read allowlist in prose — the human/audit-readable
statement of intent that backs the frontmatter scoping.

**Tasks**:
- [x] Insert a new `## Tool Constraints (Pure Dispatcher)` section containing:
  - **Permitted Bash**: orchestration-only — `jq` state/handoff reads, file bookkeeping
    (`mkdir/mv/rm/ls`), `sort/tail/grep/cat/date/echo`, `source .claude/scripts/*.sh` helpers.
  - **Forbidden Bash Operations**: `lake build`, `lean`/`lean-lsp`/`mcp__lean-lsp__*`,
    `nvim --headless`, `npm`/`pytest`/`cargo test`/`go test`, or ANY language build/test/compiler
    tool — these belong exclusively to dispatched implementation agents.
  - **Read allowlist (4 categories)**: (1) `specs/state.json`; (2)
    `specs/{NNN}_{SLUG}/.orchestrator-handoff.json` + sibling `.orchestrator-loop-guard` /
    `.orchestrator-churn-state.json`; (3) `specs/{NNN}_{SLUG}/plans/*.md` and `reports/*.md`
    (reports needed for the H4 grep); (4) `.claude/context/contracts/*.md` and
    `.claude/docs/architecture/*.md`.
  - **Forbidden Reads**: implementation source (`lua/**`, `after/**`, or any per-project source
    root an `IMPLEMENT_AGENT` would modify).
  *(completed: inserted as a delimited `<!-- BEGIN/END 772 ... -->` block after the hard-mode
  additions bullets and before `## Context References`)*
- [x] Note this section is a standalone block that 773's Context-References additions must compose
      around, not overwrite. *(completed: HTML comment delimiters mark the block boundaries)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate-hard/SKILL.md` — insert section after line 21.

**Verification**:
- New section present with both a Forbidden Bash list and a 4-category Read allowlist.
- Section placed before `## Context References`; existing Context References list (22-31) unchanged.

---

### Phase 3: Disable Parallel Wave Dispatch (Item 3) [COMPLETED]

**Goal**: Remove the ambiguity between blocking single-phase dispatch and parallel-wave dispatch
by disabling the H7 parallel section so exactly one `Agent` call per cycle is the only path.

**Tasks**:
- [x] Remove (or replace with a short "Disabled" note) the
      `#### State: `planned` or `implementing` — Parallel Wave Dispatch (optional H7)` section and
      its code block (lines 323-344) plus the "Territory building" note (346-347). If replacing
      with a note, state: parallel-wave dispatch is disabled; the orchestrator dispatches exactly
      one phase per cycle and blocks on its return (see the Per-Phase Dispatch handler above).
      *(completed: replaced the entire heading + code block + territory-building note with a
      single delimited "Parallel Wave Dispatch: DISABLED" prose paragraph, no longer a `####`
      heading, so exactly one `#### State: \`planned\` or \`implementing\`` handler remains)*
- [x] Update the Key Differences table row (line 541): change
      `Parallel dispatch | None | Wave-based with territory (H7)` to reflect
      `Parallel dispatch | None | Disabled — single blocking phase per cycle`. *(completed)*
- [x] Update the H7 overview bullet (line 20) to describe territory contracts as informing
      single-phase dispatch context, not parallel waves (or remove the parallel claim).
      *(completed)*
- [x] Confirm the Per-Phase Dispatch handler (267-321) remains the sole implement-dispatch path
      and is unambiguously one blocking `Agent` call per cycle. *(completed: verified via grep —
      only one `#### State: \`planned\` or \`implementing\`` heading in the file)*

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-orchestrate-hard/SKILL.md` — lines 20, 323-347, 541.

**Verification**:
- `grep -n "Parallel Wave Dispatch" SKILL.md` returns nothing (or only a "Disabled" note).
- Only one `#### State: `planned` or `implementing`` handler remains.
- Key Differences table row updated.

---

### Phase 4: Skeleton-aware phase selection + exhaustion routing (Item 5 Part A) [COMPLETED]

**Goal**: Replace the naive `next_phase=$((phases_completed + 1))` at line 283 with the
heading-scan phase selection mirroring 774's `skill-implementer-hard` fix, and add
skeleton-exhaustion routing that terminates cleanly (enumerating pending follow-up tasks) instead
of looping on a nonexistent phase until `MAX_CYCLES`.

**Tasks**:
- [x] Replace line 283 with a heading-scan that finds the first incomplete phase heading, e.g.:
      `next_phase=$(grep -E '^### Phase [0-9]+(\.[0-9]+)?: .*\[(NOT STARTED|PARTIAL|IN PROGRESS)\]' "$plan_path" | head -1 | sed -E 's/^### Phase ([0-9]+(\.[0-9]+)?):.*/\1/')`
      (mirrors `skill-implementer-hard/SKILL.md:122-165`; handles dotted sub-phases and sparse
      numbering). *(completed)*
- [x] Add a skeleton-exhaustion branch: when no incomplete phase heading remains AND the last
      handoff had `skeleton == true`, derive the follow-up task list by mapping/dedup'ing
      `sorry_inventory[].follow_up_task` from the handoff (NOT the unpopulated top-level
      `.follow_up_tasks`), then transition the task to `pr_ready` with a note enumerating the
      pending follow-up tasks, e.g.:
      `follow_up_tasks=$(jq -r '[.sorry_inventory[]?.follow_up_task | select(. != null)] | unique | join(", ")' "$handoff_file")`
      then log `[hard-orchestrate] Skeleton plan exhausted — follow-up tasks pending: {...}` and
      set state to `pr_ready` (do not loop). *(completed: routes via
      `.claude/scripts/update-task-status.sh postflight ... pr_ready ...`, the centralized
      status-update script, rather than a raw state.json jq write)*
- [x] When no incomplete heading remains and the last handoff was NOT skeleton, fall through to the
      existing completion path (Stage 5 Part B gate handles the transition). *(completed)*
- [x] Do NOT edit `build_hard_mode_prompt_context()` (305-319) — reserved for 779. *(confirmed:
      function body unchanged, verified via grep before and after edit)*

**Timing**: 45 minutes

**Depends on**: 3

**Files to modify**:
- `.claude/skills/skill-orchestrate-hard/SKILL.md` — line 283 and an inserted branch within the
  Per-Phase Dispatch handler (~285-296), leaving 305-319 untouched.

**Verification**:
- No remaining `next_phase=$((phases_completed + 1))` in the file.
- Skeleton-exhaustion branch reads `sorry_inventory[].follow_up_task`, dedups, routes to
  `pr_ready`, and never loops on an empty `next_phase`.

---

### Phase 5: Stage 5 postflight completion gate (Item 5 Part B) [COMPLETED]

**Goal**: Make Stage 5's postflight status transition hard-mode-specific so a single per-phase
`"implemented"` handoff (skeleton or not) does not flip the whole task to `completed`; only
transition when all phases are done.

**Tasks**:
- [x] Rewrite Stage 5 (450-461) from "Same as base Stage 5, plus:" to an explicit hard-mode block
      that: for `dispatch_status == "implemented"`, calls `skill_postflight_update ... implement`
      ONLY when `phases_total > 0 && phases_completed >= phases_total`; otherwise logs
      `[hard-orchestrate] Phase ${phases_completed}/${phases_total} complete (skeleton=${skeleton}). Continuing.`
      and leaves state as `implementing` so Stage 3a re-enters the Per-Phase Dispatch handler next
      cycle. This applies identically whether or not the handoff carried `skeleton: true`.
      *(completed)*
- [x] Preserve the base Stage 5 behavior for `researched`/`planned` dispatch statuses and for
      artifact linking (do not regress those; only the `implemented` case is gated). *(completed:
      also preserved drift-detection, which was implicitly inherited via the old "same as base"
      reference — dropping it silently would have been a regression)*
- [x] Extend the existing `sorry_inventory` logging (456-459) to also read and log the `skeleton`
      boolean and each entry's `follow_up_task`. *(completed)*

**Timing**: 45 minutes

**Depends on**: 4

**Files to modify**:
- `.claude/skills/skill-orchestrate-hard/SKILL.md` — Stage 5, lines 450-461.

**Verification**:
- Stage 5 `implemented` transition is gated on `phases_completed >= phases_total`.
- Logging includes `skeleton` and `follow_up_task`.
- `researched`/`planned` postflight and artifact-linking behavior preserved (no base regression).

---

### Phase 6: Dual-copy sync + full verification [COMPLETED]

**Goal**: Mirror every Phase 1-5 edit into the core copy and assert both copies are byte-identical
and free of any build/test invocation.

**Tasks**:
- [x] Apply the identical edits (or copy the finalized deployed file) to
      `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`. *(completed: copied the
      finalized deployed file)*
- [x] Assert `diff -q .claude/skills/skill-orchestrate-hard/SKILL.md .claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
      returns empty (no drift). *(completed: exit 0, empty diff)*
- [x] Grep both copies for any forbidden invocation (`lake`, `lean`, `nvim --headless`, `pytest`,
      `npm`, `cargo`, `go test`) issued by the orchestrator's own instructions — expect none.
      *(completed: only matches are the Tool Constraints prose forbid-list itself, not live
      invocations)*
- [x] Confirm the Territory boundaries hold: `build_hard_mode_prompt_context()` (305-319) and the
      Stage 2/3 top-of-loop region (124-197) are unchanged from pre-772 baseline. *(completed:
      byte-for-byte diff against the pre-edit git HEAD version of both anchored regions returns
      empty; both regions merely shifted down by line offset due to earlier insertions)*

**Timing**: 20 minutes

**Depends on**: 1, 2, 3, 4, 5

**Files to modify**:
- `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — mirror of all edits.

**Verification**:
- `diff -q` between the two copies returns empty.
- No forbidden build/test tokens introduced.
- Reserved regions (779's function, 773's loop-top) untouched.

## Testing & Validation

- [x] `grep -n '^allowed-tools:'` on both copies shows no `Edit`, scoped Bash/Read (or documented
      prose-fallback if multi-pattern syntax did not enforce). *(verified: both copies show
      `allowed-tools: Agent, Bash, Read` — the documented prose-fallback path)*
- [x] Multi-pattern frontmatter smoke-test result recorded (enforced vs. fallback). *(verified:
      recorded in Phase 1 task notes — no in-repo precedent found, no sandboxed harness
      available, fallback taken)*
- [x] `grep -n "Parallel Wave Dispatch"` returns nothing (or only a "Disabled" note); one
      implement-dispatch handler remains. *(verified: only the "DISABLED" prose note matches;
      exactly one `#### State: \`planned\` or \`implementing\`` heading remains)*
- [x] No `next_phase=$((phases_completed + 1))` remains; heading-scan present; skeleton-exhaustion
      branch derives from `sorry_inventory[].follow_up_task` and routes to `pr_ready`. *(verified
      via grep: zero matches for the old integer-increment pattern)*
- [x] Stage 5 `implemented` transition gated on `phases_completed >= phases_total`; `skeleton` and
      `follow_up_task` logged. *(verified)*
- [x] `diff -q` between deployed and core copies returns empty. *(verified: exit 0)*
- [x] Reserved regions (305-319, 124-197 pre-edit) unchanged. *(verified: anchored-text diff
      against pre-edit git HEAD returns empty for both regions)*

## Artifacts & Outputs

- `.claude/skills/skill-orchestrate-hard/SKILL.md` (edited)
- `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (edited, byte-identical)
- specs/772_hardmode_orchestrator_pure_dispatcher/plans/01_orchestrator-pure-dispatcher.md (this file)
- specs/772_hardmode_orchestrator_pure_dispatcher/summaries/01_orchestrator-pure-dispatcher-summary.md (on implementation)

## Rollback/Contingency

All changes are confined to two copies of a single skill file. To revert:
`git checkout -- .claude/skills/skill-orchestrate-hard/SKILL.md .claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`.
If the multi-pattern frontmatter scoping proves non-enforcing (Phase 1 smoke-test fails), fall
back to unscoped `allowed-tools: Agent, Bash, Read` on line 4 and rely on the Phase 2 prose
forbid-list — this still satisfies items 1 (Edit removed) and the documented intent of items 2/4
without depending on unverified syntax. If a conflict with an already-landed 779 is discovered,
rebase 772's `build_hard_mode_prompt_context()`-adjacent edits (there are none by design) and
re-run the `diff -q` dual-copy assertion.
