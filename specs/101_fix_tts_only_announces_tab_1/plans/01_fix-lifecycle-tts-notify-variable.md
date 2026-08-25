# Implementation Plan: Fix lifecycle TTS notify variable (`$STATE_STATUS` -> `$status`)

- **Task**: 101 - fix_tts_only_announces_tab_1
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: `specs/101_fix_tts_only_announces_tab_1/reports/01_tts-tab-announcements-not-firing.md`
- **Artifacts**: plans/01_fix-lifecycle-tts-notify-variable.md (this file)
- **Standards**:
  - `.claude/context/formats/plan-format.md`
  - `.claude/context/standards/status-markers.md`
  - `.claude/rules/artifact-formats.md`
  - `.claude/rules/state-management.md`
  - `.claude/rules/source-store-deploy-boundary.md`
  - `.claude/rules/no-task-references-in-deliverables.md`
- **Type**: meta
- **Lean Intent**: false

## Overview

Every lifecycle skill's Stage 8a invokes the TTS notifier as `skill_lifecycle_notify "$STATE_STATUS"`,
but no skill ever assigns `STATE_STATUS`; the shared postflight contract names the operative
variable `status`. Bash expands the unset name to `""`, `lifecycle-notify.sh` hits its documented
empty-status no-op guard, and every lifecycle announcement ("Tab n researched" / "planned" /
"implemented") silently disappears before tab resolution or TTS is ever reached. This plan renames
the argument to `"$status"` at the shared origin and at every inlined call site, adds a
loud-failure guard so this defect class can never again fail invisibly, adds a narrow regression
lint, deploys the source store, and verifies end-to-end against the real
`specs/tmp/claude-tts-notify.log` evidence surface. Definition of done: a real lifecycle
transition appends a `Lifecycle notification sent: Tab N <status>` line to that log, and no
`SKILL.md` or context pattern file passes `$STATE_STATUS` to the notifier.

### Research Integration

Findings carried directly into this plan, without re-litigation:

- **Root cause is fixed and confirmed**: an undefined-variable name mismatch at the Stage 8a call
  site, originating at `agent-system/extensions/core/context/patterns/skill-postflight-flow.md:99`
  and predating the shared-postflight unification (present at commit `7e79b2695`, 2026-07-14).
- **Not a deploy-staleness bug**: `skill-base.sh`, `lifecycle-notify.sh`, and `tts-notify.sh` are
  byte-identical between source store and deployed tree. The bug is faithfully deployed.
- **The rest of the pipeline is healthy**: passing a real status produced
  `Lifecycle notification sent: Tab 5 researched (status=researched)`. Tab resolution, phrase
  construction, backgrounding, piper/paplay, and binary availability were all independently
  verified working. Do not re-investigate them.
- **`/orchestrate` is unaffected**: `orchestrator-postflight.sh` builds its own correctly-scoped
  `$status`/`$notify_status` and calls `lifecycle-notify.sh` directly.
- **The interactive path is a separate, working code path**: the `Notification` hook calls
  `tts-notify.sh` with no arguments and never touches any status variable. It is out of scope.
- **Collision risk flagged by research**: a blind find-and-replace could collide with an unrelated
  local `status` in a hard-mode skill's control flow. Phases 2 and 3 therefore require a per-file
  re-read of `status`-assignment history rather than a blind `sed`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`roadmap_flag` is false; no roadmap phases are added. `specs/ROADMAP.md` was consulted for
sequencing only and is not modified by this plan.

## Goals & Non-Goals

**Goals**:

- Rename the Stage 8a notifier argument from `$STATE_STATUS` to `$status` at the shared origin and
  at every inlined call site across the `core`, `web`, `cslib`, and `epidemiology` extensions.
- Convert the silent-empty-status failure mode into a loud, logged, observable one, so a future
  re-drift of this defect class announces itself instead of costing another six weeks of silence.
- Add a narrow regression lint that fails if any skill or context pattern file passes
  `$STATE_STATUS` to the lifecycle notifier.
- Deploy the source store so the fix reaches the running `.claude/` tree, and verify the fix
  empirically, end-to-end, against `specs/tmp/claude-tts-notify.log`.
- Leave every legitimate, correctly-scoped use of `STATE_STATUS` untouched.

**Non-Goals**:

- Re-diagnosing the root cause. It is confirmed and empirically reproduced.
- Changing `lifecycle-notify.sh`'s documented empty-status **exit-0, non-blocking** contract. Only
  its observability is changed (see Decision 1), never its control flow or exit status.
- Changing `skill_lifecycle_notify`'s function signature, or making it resolve status itself by
  re-reading `.return-meta.json`. See Decision 1 for why.
- Renaming the shared contract's `status` precondition to `STATE_STATUS` (the inverse fix). See
  Decision 1.
- Touching `update-task-status.sh`'s internal `STATE_STATUS` variable or the prose that documents
  it. These are correct and in scope of their own file. See Phase 1's exclusion list.
- Building the general "bash variable referenced in a fenced block with no assignment in this
  file's precondition scope" linter the research recommended. See Decision 2 — recorded as a
  follow-up, deliberately not attempted here.
- Fixing `get_tab_prefix()`'s multi-window `tab_id` sort-scoping. See Decision 4.
- Fixing the two pre-existing, unrelated `verify-deploy.sh --findings` findings. See Decision 5.
- Any interactive-notification (`Notification` hook) behavior. That path already works.

## Decisions

These are the judgment calls this plan makes, recorded so the implementer does not re-open them.

### Decision 1: Fix direction — rename call sites to `"$status"`, plus a loud-failure guard

**Chosen**: direction (a), rename every call site to `"$status"`, **combined with** a defensive
loud-failure guard (Phase 4). Rejected: direction (b), having `skill_lifecycle_notify` resolve the
status itself, and the inverse rename of the contract variable.

**Rationale**:

- `$status` is already the name the shared contract's own Preconditions section documents
  (`skill-postflight-flow.md`, "Preconditions" bullet: "`status` — the operation's success-variant
  string read from `.return-meta.json` at Stage 6"), and it is already the name Stage 7's
  `skill_postflight_update` call correctly uses two stages earlier. Renaming to `$status` makes the
  code block agree with the contract it already sits inside — the minimal edit that removes the
  drift rather than codifying it.
- Direction (b) — self-resolution — would require `skill_lifecycle_notify` to re-read
  `.return-meta.json`. The shared pattern file's own "Ordering" section explicitly states that
  "Stage 8a's ... value [is] derived from the same already-read `status` value, **not a fresh file
  read**". Adding a file dependency there would contradict a documented invariant and couple a
  generic `skill-base.sh` shell function to task-directory layout it currently knows nothing about.
- The inverse rename (contract variable -> `STATE_STATUS`) has a far larger blast radius (every
  `status` read at Stage 6, Stage 7, and each skill's own partial/failure guard) and would collide
  head-on with `update-task-status.sh`'s own, legitimate, internal `STATE_STATUS`.
- **Rename alone is not robust against future re-drift**, which is precisely why this defect
  survived six-plus weeks and a full unification refactor. The rename is therefore paired with
  Phase 4's guard: `skill_lifecycle_notify` emits a visible stderr warning on an empty argument,
  and `lifecycle-notify.sh` logs its no-op branch instead of exiting invisibly. A re-drifted call
  site then produces an observable artifact on its very first execution rather than nothing at all.
- A `set -u`-style guard is **not** used. These bash blocks are executed by agents in ad hoc
  shells, not by a script with a controlled preamble; `set -u` cannot be reliably imposed at the
  call site and would risk aborting an otherwise-successful postflight over a non-fatal
  notification. A warn-and-continue guard preserves the never-blocking property the notifier
  contract requires while still being loud.

### Decision 2: Regression guard — narrow grep guard in scope, general linter deferred

**Chosen**: implement a **narrow, targeted** regression guard (Phase 6) that fails if any
`SKILL.md` or `context/patterns/*.md` file passes `$STATE_STATUS` to `skill_lifecycle_notify` or
`lifecycle-notify.sh`. Do **not** implement the general undefined-variable linter.

**Rationale**: the general linter the research proposed — flagging any bash-block variable
reference with no matching assignment in that file's own precondition scope — is a genuinely
non-trivial piece of static analysis over markdown, and would be heavily false-positive-prone here:
most skill files legitimately reference variables supplied by an imported pattern file or by
`skill-base.sh`, so a naive implementation would fire on nearly every skill. Getting it right
requires modelling the `@`-import graph and each pattern file's Preconditions section, which is its
own task with its own research. The narrow guard costs a few lines, has zero false-positive
surface, and closes this exact regression permanently. The general class is separately covered at
runtime by Decision 1's loud-failure guard, which catches *any* empty-status call site regardless of
which variable name drifted. The general linter is recorded here as a recommended follow-up; a
separate task should carry it.

### Decision 3: Phase granularity — split by ownership boundary, not by file count

The mechanical edit is one token per site, but the sites span four extensions and three distinct
kinds of change (the shared origin, mechanical propagation, and genuinely new behavior). Phases are
therefore split so that each has a **single reviewable character** and a distinct verification
tier: the shared origin is settled first and alone (Phase 1, because it is the canonical text every
other site should end up agreeing with, and because its own scope confirmation gates everything
else); mechanical propagation splits core (Phase 2) from extensions (Phase 3) along disjoint file
territories so they can run in parallel; the behavior-changing guard (Phase 4) is isolated because
it touches shared runtime scripts and needs a `full` tier that the doc edits do not; adjacent
defects discovered during scope confirmation (Phase 5) are isolated because they carry their own
judgment and may legitimately end as reasoned exclusions; the lint (Phase 6) must follow the
renames it asserts; and deploy plus empirical verification (Phase 7) is last and alone because it
is the only phase that proves the task actually worked.

### Decision 4: `get_tab_prefix()` multi-window sort-scoping is out of scope

**Chosen**: out of scope, recorded, no action.

`get_tab_prefix()` sorts `tab_id` values gathered across *all* WezTerm windows rather than scoping
to the current window's `window_id`. The research verified this arithmetic produces the correct
answer in the actual environment (tab_id 10 -> position 4 -> "Tab 5", matching the confirmed tab),
and it does not contribute to the reported symptom in any way — the lifecycle path never reaches
this function at all. Bundling a latent, unreproduced, multi-window correctness concern into a fix
whose whole value is a precise one-token rename would dilute the change and enlarge its
verification surface for no benefit to the reported defect. It should be its own task.

### Decision 5: Pre-existing deploy findings are acknowledged, not fixed

`verify-deploy.sh --findings` currently reports two findings that predate this work and are
unrelated to it: a `lean4` extension documentation line-count mismatch
(`project/lean4/operations/multi-instance-optimization.md`) and a missing deployed core script
(`scripts/lake-build-guard.sh`, which is present in the source store but absent from the deployed
tree). Gate-in additionally warns that the deployed `core` extension is stale. The implementer
MUST treat all three as the pre-existing baseline, MUST NOT mistake them for regressions
introduced by this work, and MUST NOT scope-creep into fixing them. Phase 7 records the baseline
before deploying so the post-deploy comparison is meaningful.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A blind repo-wide `sed 's/STATE_STATUS/status/'` corrupts `update-task-status.sh`, which assigns and uses `STATE_STATUS` legitimately in `map_status()` and ~10 further references | H | M | Phase 1 fixes an explicit, enumerated exclusion list before any edit; every phase edits by enumerated file and line, never by repo-wide substitution. Phase 6's lint is scoped to `SKILL.md` and `context/patterns/*.md` only |
| Renaming to `$status` collides with an unrelated local `status` in a hard-mode skill's more complex control flow (e.g. a continuation loop that reassigns `status` per iteration) | M | L | Phases 2 and 3 require re-reading each file's own `status`-assignment history immediately before its Stage 8a, confirming the terminal value is the intended lifecycle status, before editing that file. Research inspected these files and observed no collision, but confirmation is required per file |
| Fixing only the shared pattern file leaves the inlined copies broken, since those files do not re-read the pattern at execution time | H | M | Phases 2 and 3 explicitly enumerate every inlined occurrence; Phase 6's lint makes an incomplete propagation fail loudly; Phase 7 verifies end-to-end rather than by inspection |
| Edits land in the gitignored `.claude/**` deploy tree and are silently wiped by the next regeneration | H | M | Every phase names `agent-system/extensions/**` targets explicitly; Phase 7's deploy-then-diff step would expose any `.claude/**`-only edit as a post-deploy divergence |
| Fix is edited correctly but never deployed, so the running tree stays broken and the task appears done | H | M | Phase 7 runs `deploy-headless.sh` and then verifies the deployed twins by `diff`, and only then runs the end-to-end log check |
| Static verification (grep for absence of `STATE_STATUS`) passes while the pipeline is still silent | H | L | Phase 7's completion criterion is a new line in `specs/tmp/claude-tts-notify.log`, not a grep result. A grep-only Phase 7 is explicitly insufficient |
| The loud-failure guard breaks the notifier's never-blocking contract and aborts a postflight | M | L | Phase 4 warns to stderr and returns success; it never uses `set -u`, never changes an exit status, and never removes the backgrounding. Phase 4 includes an explicit non-blocking regression check |
| Task-number references leak into the edited deliverable files | M | L | Phases 1-6 each carry an explicit "no task numbers in edited files" task; Phase 7 runs `check-task-references.sh` |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 2, 3 |
| 4 | 7 | 4, 5, 6 |

Phases within the same wave can execute in parallel. Phases 2, 3, 4, and 5 edit disjoint file
territories (core skills / extension skills / shared runtime scripts / adjacent-defect files
respectively) and may be dispatched together.

---

### Phase 1: Confirm scope and fix the shared origin [COMPLETED]

- **Goal:** Establish the confirmed, exclusion-aware file inventory for the whole task, and correct
  the single canonical source from which the defect propagated.

- **Tasks:**
  - [x] Run `grep -rn "STATE_STATUS" agent-system/extensions/` and record the full result as the
    scope baseline. *(completed: 16 files matched)*
  - [x] Partition the results into **defect sites** (a `$STATE_STATUS` passed as the status
    argument to `skill_lifecycle_notify` or `lifecycle-notify.sh`) and **legitimate uses**. Record
    the partition in the implementation summary. *(completed: 12 defect sites, 3 legitimate uses,
    1 stale doc for Phase 5)*
  - [x] Confirm the following are **legitimate and MUST NOT be edited**:
    `agent-system/extensions/core/scripts/update-task-status.sh` (assigns `STATE_STATUS` itself in
    `map_status()` and references it throughout — it is correctly scoped within that one script);
    `agent-system/extensions/core/context/standards/status-markers.md` (prose describing that
    script's internal mapping); `agent-system/extensions/core/skills/skill-team-implement/SKILL.md`
    (prose describing that same mapping — see Phase 5 for what this file *does* need). *(completed)*
  - [x] Edit `agent-system/extensions/core/context/patterns/skill-postflight-flow.md`: change the
    Stage 8a code block from `skill_lifecycle_notify "$STATE_STATUS"` to
    `skill_lifecycle_notify "$status"`. *(completed)*
  - [x] Update the two explanatory prose references in the same file that also name `$STATE_STATUS`
    (the Stage 8a paragraph beginning "Fires the TTS + WezTerm tab-coloring notification", and the
    "Ordering" section's parenthetical about the value being derived from an already-read value) so
    the prose names `$status` and no longer implies a distinct variable exists. *(completed)*
  - [x] Confirm the file's own Preconditions section already lists `status` and needs no change.
    *(completed: confirmed at line 37)*
  - [x] Verify no task numbers were introduced into the edited file. *(completed:
    check-task-references.sh reports 0 occurrences)*

- **Timing:** 0.5 hours

- **Depends on:** none

- **Verification Tier:** interface

- **Scope Hypothesis:** The research reports 13 affected files (12 skills + 1 shared pattern file)
  and a repo-wide `grep -rln STATE_STATUS` over `agent-system/extensions/` returns 16 files. These
  numbers do not agree and neither is authoritative. Confirm the real count by running the grep and
  applying the defect-site/legitimate-use partition above. Two specific deltas are expected and
  must be checked by name: (i) `skill-team-implement/SKILL.md` is listed by the research as an
  inlined defect site, but its only occurrence appears to be prose about `update-task-status.sh` —
  if so it is **not** a rename target and this phase's count drops by one; (ii)
  `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` contains a
  `$STATE_STATUS` occurrence that fell outside the research's grep glob — classify it (see Phase 5).
  Record the confirmed count and the resolution of both deltas; do not carry the research's number
  forward unconfirmed.

- **Files to modify:**
  - `agent-system/extensions/core/context/patterns/skill-postflight-flow.md` - Stage 8a code block
    and its two prose references.

- **Verification:**
  - `grep -n "STATE_STATUS" agent-system/extensions/core/context/patterns/skill-postflight-flow.md`
    returns nothing.
  - `grep -n 'skill_lifecycle_notify' agent-system/extensions/core/context/patterns/skill-postflight-flow.md`
    shows the call passing `"$status"`.
  - The confirmed defect-site inventory and the exclusion list are written down and available to
    Phases 2, 3, and 5.

---

### Phase 2: Propagate the rename to core skills [COMPLETED]

- **Goal:** Fix every inlined Stage 8a call site inside the `core` extension so the skills that do
  not lazily import the shared pattern also pass a real status.

- **Tasks:**
  - [x] For each file below, read its own `status`-assignment history from Stage 6 through Stage 8a
    and confirm that `status` holds the intended terminal lifecycle value at the call site. Record
    the confirmation. Do not apply a blind find-and-replace. *(completed: all 5 files confirmed,
    no collisions)*
  - [x] `agent-system/extensions/core/skills/skill-planner/SKILL.md` - change
    `skill_lifecycle_notify "$STATE_STATUS"` to `skill_lifecycle_notify "$status"`. *(completed)*
  - [x] `agent-system/extensions/core/skills/skill-planner-hard/SKILL.md` - same change. *(completed)*
  - [x] `agent-system/extensions/core/skills/skill-implementer/SKILL.md` - same change. *(completed)*
  - [x] `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` - same change; this
    file has an extra `status` assignment relative to its siblings, so re-read its control flow
    with particular care before editing. *(completed: confirmed the extra `status="partial"`
    assignment at Stage 7's phase-check-refusal branch is intentional and correctly scoped)*
  - [x] `agent-system/extensions/core/skills/skill-reviser/SKILL.md` - this site calls
    `lifecycle-notify.sh` directly rather than via `skill_lifecycle_notify`; change the argument
    `"$STATE_STATUS"` to `"$status"` while leaving the direct-invocation shape unchanged.
    *(completed)*
  - [x] Verify no task numbers were introduced into any edited file. *(completed:
    check-task-references.sh reports 0 occurrences)*

- **Timing:** 0.5 hours

- **Depends on:** 1

- **Verification Tier:** local

- **Scope Hypothesis:** This phase asserts exactly 5 core-extension defect sites. Confirm against
  Phase 1's inventory before editing; if Phase 1 found more or fewer core sites, this phase's file
  list is the one that changes, not Phase 1's inventory.

- **Files to modify:**
  - `agent-system/extensions/core/skills/skill-planner/SKILL.md` - Stage 8a argument.
  - `agent-system/extensions/core/skills/skill-planner-hard/SKILL.md` - Stage 8a argument.
  - `agent-system/extensions/core/skills/skill-implementer/SKILL.md` - Stage 8a argument.
  - `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` - Stage 8a argument.
  - `agent-system/extensions/core/skills/skill-reviser/SKILL.md` - Stage 8b direct-invocation argument.

- **Verification:**
  - `grep -rn "STATE_STATUS" agent-system/extensions/core/skills/` returns only the
    `skill-team-implement` prose line confirmed legitimate in Phase 1.
  - Each edited call site passes `"$status"`.

---

### Phase 3: Propagate the rename to extension skills [COMPLETED]

- **Goal:** Fix every inlined Stage 8a call site in the `web`, `cslib`, and `epidemiology`
  extensions.

- **Tasks:**
  - [x] Apply the same per-file `status`-scope confirmation required by Phase 2 to each file below
    before editing it. *(completed: all 6 files confirmed, no collisions)*
  - [x] `agent-system/extensions/web/skills/skill-web-research/SKILL.md` - change
    `skill_lifecycle_notify "$STATE_STATUS"` to `skill_lifecycle_notify "$status"`. *(completed)*
  - [x] `agent-system/extensions/web/skills/skill-web-implementation/SKILL.md` - same change. *(completed)*
  - [x] `agent-system/extensions/epidemiology/skills/skill-epi-research/SKILL.md` - same change. *(completed)*
  - [x] `agent-system/extensions/epidemiology/skills/skill-epi-implement/SKILL.md` - same change. *(completed)*
  - [x] `agent-system/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md` - direct
    `lifecycle-notify.sh` invocation; change the argument only. *(completed)*
  - [x] `agent-system/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` - direct
    `lifecycle-notify.sh` invocation; change the argument only. *(completed)*
  - [x] Verify no task numbers were introduced into any edited file. *(completed:
    check-task-references.sh reports 0 occurrences across all three extension trees)*

- **Timing:** 0.5 hours

- **Depends on:** 1

- **Verification Tier:** local

- **Scope Hypothesis:** This phase asserts exactly 6 extension defect sites (2 web, 2 cslib, 2
  epidemiology). Confirm against Phase 1's inventory before editing. Note that extensions not
  currently loaded still ship these files in the source store and are in scope regardless of load
  state.

- **Files to modify:**
  - `agent-system/extensions/web/skills/skill-web-research/SKILL.md` - Stage 8a argument.
  - `agent-system/extensions/web/skills/skill-web-implementation/SKILL.md` - Stage 8a argument.
  - `agent-system/extensions/epidemiology/skills/skill-epi-research/SKILL.md` - Stage 8a argument.
  - `agent-system/extensions/epidemiology/skills/skill-epi-implement/SKILL.md` - Stage 8a argument.
  - `agent-system/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md` - Stage 8a argument.
  - `agent-system/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` - Stage 8a argument.

- **Verification:**
  - `grep -rn "STATE_STATUS" agent-system/extensions/web agent-system/extensions/cslib agent-system/extensions/epidemiology`
    returns nothing.

---

### Phase 4: Make empty-status failure loud instead of silent [COMPLETED]

- **Goal:** Ensure that any future call site passing an empty status produces an immediately
  observable artifact, rather than silently no-opping — the property whose absence let this defect
  survive six-plus weeks and a full refactor.

- **Tasks:**
  - [x] In `agent-system/extensions/core/scripts/skill-base.sh`, add an empty-argument guard to
    `skill_lifecycle_notify` that emits a clearly-worded warning to stderr naming the function and
    the fact that no notification will be sent, then returns success without invoking the notifier.
    *(completed)*
  - [x] Confirm the guard preserves the function's never-blocking contract: it must not use
    `set -u`, must not change the function's exit status, must not remove the backgrounded
    invocation on the non-empty path, and must not make a failed notification able to abort a
    postflight. *(completed: manually verified)*
  - [x] In `agent-system/extensions/core/scripts/lifecycle-notify.sh`, make the existing
    empty-status branch append a log line to the same log file the success path writes
    (`specs/tmp/claude-tts-notify.log`), recording that an empty status was received and no
    notification was sent. Keep the branch's `exit 0` and its documented no-op contract exactly as
    they are — change observability only, never control flow. *(completed)*
  - [x] Update the usage/behavior comment block at the top of `lifecycle-notify.sh` so the
    documented `""` no-op behavior mentions that the no-op is now logged. *(completed)*
  - [x] Extend `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` with a
    case asserting that `skill_lifecycle_notify ""` warns on stderr and still returns success, and
    a case asserting the non-empty path still invokes the notifier. *(completed: new Group 2a)*
  - [x] Verify no task numbers were introduced into any edited file. *(completed)*

- **Timing:** 0.75 hours

- **Depends on:** 1

- **Verification Tier:** full

- **Files to modify:**
  - `agent-system/extensions/core/scripts/skill-base.sh` - `skill_lifecycle_notify` empty-argument guard.
  - `agent-system/extensions/core/scripts/lifecycle-notify.sh` - log the empty-status no-op branch; update usage comment.
  - `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` - guard regression cases.

- **Verification:**
  - `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` passes when run
    against the source-store `skill-base.sh` directly (manually confirmed: empty status warns on
    stderr naming the function and returns 0; non-empty status still invokes the notifier). The
    suite's own `resolve_candidate()` prefers the deployed `.claude/scripts/skill-base.sh` tree
    (matching real SKILL.md runtime), which is known-stale per gate-in's warning until Phase 7
    deploys — the full official run against the deployed tree is re-verified there (see Phase 4
    progress-file deviation).
  - Sourcing `skill-base.sh` and calling `skill_lifecycle_notify ""` prints a warning and returns 0.
    *(confirmed)*
  - `bash agent-system/extensions/core/scripts/lifecycle-notify.sh ""` exits 0 and appends an
    empty-status line to `specs/tmp/claude-tts-notify.log`. *(confirmed)*
  - `bash agent-system/extensions/core/scripts/lifecycle-notify.sh "researched"` still appends a
    `Lifecycle notification sent: Tab N researched` line, unchanged from current behavior.
    *(confirmed: prior behavior unmodified for the non-empty path)*

---

### Phase 5: Resolve adjacent defects found during scope confirmation [COMPLETED]

- **Goal:** Address the two non-rename issues Phase 1's inventory surfaces, or close them as
  reasoned exclusions with evidence.

- **Tasks:**
  - [x] **Missing Stage 8a in `skill-team-implement`**: confirm whether
    `agent-system/extensions/core/skills/skill-team-implement/SKILL.md` invokes the lifecycle
    notifier at all. If it does not, it never announces a lifecycle transition — a distinct defect
    with the same user-visible symptom this task exists to fix. Add a Stage 8a call passing the
    literal success value that file's Stage 7 already passes, matching the shape used by its
    sibling skills. If evidence is found that the omission is deliberate, record a
    `#### Reasoned Exclusions` subsection under this phase instead of adding the call, citing that
    evidence. *(completed: confirmed no lifecycle-notify call existed; added a new Stage 12a
    passing the literal `"implemented"` value)*
  - [x] **Stale TTS documentation**: `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md`
    documents lifecycle TTS as being fired directly by `update-task-status.sh` PHASE 5, using
    `$STATE_STATUS`. Confirm whether `update-task-status.sh` still contains any
    `tts-notify.sh`/`lifecycle-notify.sh` invocation. If it does not, the guide describes a
    mechanism that no longer exists and is itself a vector for re-propagating the wrong variable
    name; rewrite that section to describe the actual path (a skill's Stage 8a ->
    `skill_lifecycle_notify` -> `lifecycle-notify.sh` -> `tts-notify.sh --lifecycle`) with the
    correct variable name. *(completed: confirmed update-task-status.sh has zero tts-notify/
    lifecycle-notify references; rewrote How It Works, Hook Configuration, the event-types table
    row, and Troubleshooting)*
  - [x] Verify no task numbers were introduced into any edited file. *(completed)*

- **Timing:** 0.5 hours

- **Depends on:** 1

- **Verification Tier:** local

- **Scope Hypothesis:** This phase asserts exactly 2 adjacent items. Both are conditional on
  findings confirmed in Phase 1 and re-checked here; either may resolve to "no change needed", in
  which case record a `#### Reasoned Exclusions` table with the confirming evidence rather than
  editing. If Phase 1's inventory surfaced a third adjacent item, add it here rather than deferring
  it silently.

- **Files to modify:**
  - `agent-system/extensions/core/skills/skill-team-implement/SKILL.md` - add Stage 8a lifecycle notification (conditional).
  - `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` - correct the stale lifecycle-TTS mechanism description (conditional).

- **Verification:**
  - `grep -n "lifecycle" agent-system/extensions/core/skills/skill-team-implement/SKILL.md` shows
    a Stage 8a call, or the phase carries a `#### Reasoned Exclusions` record.
  - The nvim guide's TTS section names no variable that does not exist in the path it describes.

---

### Phase 6: Add a narrow regression lint [COMPLETED]

- **Goal:** Make it impossible for this exact defect to be reintroduced without a gate failing.

- **Tasks:**
  - [x] Add a check that fails when any `SKILL.md` under `agent-system/extensions/*/skills/` or any
    file under `agent-system/extensions/*/context/patterns/` passes `$STATE_STATUS` as an argument
    to `skill_lifecycle_notify` or to `lifecycle-notify.sh`. *(completed: new
    lint-lifecycle-status-var.sh)*
  - [x] Scope the check narrowly and deliberately: it MUST NOT flag `update-task-status.sh`, MUST
    NOT flag prose mentions of `STATE_STATUS` that describe that script's internal mapping, and
    MUST NOT attempt general undefined-variable analysis (see Decision 2). *(completed: verified
    against all three confirmed-legitimate files)*
  - [x] Give the failure message a self-explanatory body that names the correct variable
    (`$status`), names the shared contract file where the canonical Stage 8a block lives, and
    states that the wrong name causes a silent no-op — so a future reader does not have to
    rediscover the defect. *(completed)*
  - [x] Add a test for the check under `agent-system/extensions/core/scripts/tests/` covering both
    a passing tree and a synthetic failing input. *(completed: test-lint-lifecycle-status-var.sh,
    9 cases, all passing)*
  - [x] Verify no task numbers were introduced into any edited or created file. *(completed)*

- **Timing:** 0.75 hours

- **Depends on:** 2, 3

- **Verification Tier:** full

- **Scope Hypothesis:** The intended host is
  `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh`, which already lints
  postflight structure across skills and is already invoked by `verify-deploy.sh`. Confirm at
  implementation time that this is the right host by reading that script's existing check
  structure and its `verify-deploy.sh` wiring; if it is not a natural fit, add a new script under
  `agent-system/extensions/core/scripts/lint/` and wire it into `verify-deploy.sh` the same way its
  siblings are wired. Do not create a new lint entry point that nothing invokes. **Resolved**: not
  a natural fit -- `lint-postflight-boundary.sh` only scans `SKILL.md` files under the DEPLOYED
  tree (`.claude/skills`, `.claude/extensions`) and has no `context/patterns/*.md` scan surface at
  all, by design (its own `verify-deploy.sh` wiring comment documents it as auditing deployed
  content, not source). A new sibling script, `lint-lifecycle-status-var.sh`, was added instead,
  following `lint-agent-contracts.sh`'s source-store-invocation convention, and wired into
  `verify-deploy.sh` as gate 15 the same way gates 6/7/11/12 are wired (`REPO_ROOT="$TARGET"`
  override, SKIP-if-not-source-store).

- **Files to modify:**
  - `agent-system/extensions/core/scripts/lint/lint-lifecycle-status-var.sh` - new sibling lint
    script (resolved from the Scope Hypothesis above).
  - `agent-system/extensions/core/scripts/verify-deploy.sh` - gate 15 wiring.
  - `agent-system/extensions/core/manifest.json` - `provides.scripts` registration for both new
    files (corollary of adding new source-store files -- otherwise `deploy-headless.sh` never
    ships them).
  - `agent-system/extensions/core/scripts/tests/test-lint-lifecycle-status-var.sh` - test for the
    new check.

- **Verification:**
  - The lint passes against the current tree (with Phases 2 and 3 applied).
  - The lint fails against a synthetic file containing
    `skill_lifecycle_notify "$STATE_STATUS"`, with the self-explanatory message.
  - The lint still passes when run against `update-task-status.sh` and the legitimate prose
    references confirmed in Phase 1 (no false positives).

---

### Phase 7: Deploy and verify end-to-end [NOT STARTED]

- **Goal:** Get the fix into the running `.claude/` tree and prove, empirically, that a real
  lifecycle transition now produces a TTS announcement. This phase, not any grep, is what closes
  the task.

- **Tasks:**
  - [ ] **Record the pre-existing baseline before deploying.** Run
    `bash .claude/scripts/verify-deploy.sh --findings` and capture its output. Per Decision 5, the
    expected baseline is 2 findings: a `lean4` doc line-count mismatch
    (`project/lean4/operations/multi-instance-optimization.md`) and a missing deployed
    `scripts/lake-build-guard.sh`. Note that this script may exceed a 120-second foreground window
    and should be backgrounded if so.
  - [ ] Capture the current tail of `specs/tmp/claude-tts-notify.log` so new entries are
    distinguishable from historical ones.
  - [ ] Run `bash .claude/scripts/deploy-headless.sh`.
  - [ ] Verify the deploy actually landed: `diff` each implicated source file against its `.claude/`
    twin — `scripts/skill-base.sh`, `scripts/lifecycle-notify.sh`,
    `context/patterns/skill-postflight-flow.md`, and a representative edited `SKILL.md` from each
    of Phases 2 and 3. All must be byte-identical.
  - [ ] Confirm `grep -rn "STATE_STATUS" .claude/skills .claude/context/patterns` returns nothing
    but confirmed-legitimate prose, proving the deployed tree carries the fix and not a stale copy.
  - [ ] **End-to-end check (required; a grep is not sufficient).** Reproduce the researcher's
    verified method against the *corrected* text: in a fresh subshell, source the deployed
    `.claude/scripts/skill-base.sh`, set `status` to a real lifecycle value (e.g. `researched`),
    execute the corrected literal call site `skill_lifecycle_notify "$status"`, and confirm a new
    `Lifecycle notification sent: Tab N researched (status=researched)` line appears in
    `specs/tmp/claude-tts-notify.log`.
  - [ ] **Full-path check.** Drive a genuine lifecycle transition through a real skill postflight
    (the simplest available is this task's own subsequent lifecycle transition) and confirm a
    corresponding new log line appears — proving the fix works through the actual skill execution
    path, not only through a hand-constructed subshell.
  - [ ] Confirm the loud guard is live in the deployed tree: `bash .claude/scripts/lifecycle-notify.sh ""`
    now appends an empty-status line to the log rather than exiting silently.
  - [ ] Re-run `bash .claude/scripts/verify-deploy.sh --findings` and confirm the findings set is
    unchanged from the pre-deploy baseline apart from resolution of the `core` staleness warning.
    Any *new* finding is a regression from this work and must be fixed before the phase closes.
  - [ ] Run `bash .claude/scripts/check-task-references.sh` and confirm no task-number references
    were introduced into any file outside `specs/**`.

- **Timing:** 0.75 hours

- **Depends on:** 4, 5, 6

- **Verification Tier:** full

- **Files to modify:** none (deploy and verification only; `.claude/**` is written by the deploy
  script by design, never by hand).

- **Verification:**
  - A new `Lifecycle notification sent: Tab N <status>` line exists in
    `specs/tmp/claude-tts-notify.log` with a timestamp after the deploy, from both the subshell
    check and the full-path check.
  - Source and deployed twins of every implicated file are byte-identical.
  - `verify-deploy.sh --findings` shows no new findings relative to the recorded baseline.
  - `check-task-references.sh` passes.

---

## Testing & Validation

- [ ] `grep -rn "STATE_STATUS" agent-system/extensions/` returns only the confirmed-legitimate uses
      enumerated in Phase 1 (`update-task-status.sh` and prose describing its internal mapping).
- [ ] `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` passes.
- [ ] The new narrow lint passes on the real tree and fails on a synthetic reintroduction of
      `skill_lifecycle_notify "$STATE_STATUS"`.
- [ ] `bash .claude/scripts/verify-deploy.sh --findings` reports no findings beyond the two
      pre-existing, unrelated ones recorded as the Phase 7 baseline.
- [ ] Every implicated source-store file is byte-identical to its deployed `.claude/` twin.
- [ ] A new `Lifecycle notification sent: Tab N <status>` line appears in
      `specs/tmp/claude-tts-notify.log` from a hand-constructed corrected call site.
- [ ] A new `Lifecycle notification sent: Tab N <status>` line appears from a genuine skill
      postflight execution path.
- [ ] `bash .claude/scripts/lifecycle-notify.sh ""` logs its no-op instead of exiting silently, and
      still exits 0.
- [ ] `bash .claude/scripts/check-task-references.sh` passes.
- [ ] No file under `.claude/**` was hand-edited; the only `.claude/**` writes came from
      `deploy-headless.sh`.

## Artifacts & Outputs

- `specs/101_fix_tts_only_announces_tab_1/plans/01_fix-lifecycle-tts-notify-variable.md` (this plan)
- `specs/101_fix_tts_only_announces_tab_1/summaries/01_implementation-summary.md` (written at
  implementation completion; the `summaries/` directory is created lazily at that point, not
  pre-created)
- Modified: `agent-system/extensions/core/context/patterns/skill-postflight-flow.md`
- Modified: 5 core `SKILL.md` files (planner, planner-hard, implementer, implementer-hard, reviser)
- Modified: 6 extension `SKILL.md` files (web x2, cslib x2, epidemiology x2)
- Modified: `agent-system/extensions/core/scripts/skill-base.sh`,
  `agent-system/extensions/core/scripts/lifecycle-notify.sh`
- Modified or added: a narrow lint under `agent-system/extensions/core/scripts/lint/` and its test
  under `agent-system/extensions/core/scripts/tests/`
- Conditionally modified: `agent-system/extensions/core/skills/skill-team-implement/SKILL.md`,
  `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md`
- Regenerated (by `deploy-headless.sh`, never by hand): the corresponding `.claude/**` tree

## Rollback/Contingency

- Every phase's edits are small, enumerated, and independently committed per the
  commit-per-green-substep mandate, so reverting is a targeted `git revert` of the offending
  phase's commit rather than an all-or-nothing unwind.
- Before any intentional rollback that would discard uncommitted work, run
  `bash .claude/scripts/git-snapshot.sh 101` first, per `.claude/rules/git-workflow.md`.
- If Phase 4's loud guard proves to interfere with any postflight (the only phase that changes
  runtime behavior rather than text), revert Phase 4 alone and redeploy. The Phase 1-3 rename is
  independently valuable and independently correct without it; the guard is defense-in-depth.
- If the deploy in Phase 7 introduces unexpected findings, the source store is the authority: revert
  the offending source-store commit and re-run `deploy-headless.sh`. Never patch `.claude/**` by
  hand to paper over a deploy divergence — that edit is wiped on the next regeneration and hides
  the real problem.
- Worst case, the whole change set is text-level and reversible with no data migration, no schema
  change, and no state.json mutation.
