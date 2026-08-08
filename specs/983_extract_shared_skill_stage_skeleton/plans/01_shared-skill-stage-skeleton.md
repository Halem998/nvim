# Implementation Plan: Task #983

- **Task**: 983 - Extract shared skill stage blocks as imports; route all skills through skill-base.sh
- **Status**: [IMPLEMENTING]
- **Effort**: 23.5 hours
- **Dependencies**: None blocking (state.json lists 951, 952, 953, 959, 960, 961, 962, 964, 969, 981, 982, 988 as prior agent-system tasks; all are completed or independent)
- **Research Inputs**: `specs/983_extract_shared_skill_stage_skeleton/reports/01_shared-skill-stage-inventory.md`
- **Artifacts**: plans/01_shared-skill-stage-skeleton.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The skill lifecycle has drifted into hand-copied stage blocks: 38 SKILL.md files inline the
`.postflight-pending` heredoc across six mutually incompatible schemas, 6 of `skill-base.sh`'s 16
lifecycle functions have never had a production caller, and the 12 domain skills carry no Stage 4a
at all — so `--lit`/`--clean`/memory injection silently no-op for every non-core task type. This
plan settles ONE marker schema in `skill-base.sh`, adds the two lifecycle functions that do not yet
exist (`skill_lifecycle_notify`, `skill_propagate_memory_candidates`), authors three shared
`@`-imported prose blocks following the `lit-stage4a-flow.md` drift-history header convention, and
then converts the skill corpus onto that skeleton in ordered, deployable waves — lowest-risk and
most self-contained work first (schema settlement, MUST NOT restoration, lint gate), the wide
mechanical sweeps last. Done means: zero inline marker heredocs remain, every lifecycle skill emits
an identical-schema marker through `skill-base.sh`, `lint-postflight-boundary.sh` fails on a missing
MUST NOT section and passes on the whole corpus, and a `neovim` task run with `--lit` demonstrably
reaches the Stage 4a resolver.

### Research Integration

The research report is the authoritative inventory and **corrects the task description in five
places**. The plan is built against the report's measured findings; each divergence is called out
here and re-stated in the phase that depends on it:

| Description said | Report measured | Plan consequence |
|---|---|---|
| FOUR incompatible marker shapes | **SIX** (empty `touch` ×2; `skill-base.sh`'s own unused shape; and four JSON variants at 15/15/5/3 files) | Phase 1 settles one schema against six inputs, not four; Phase 9 exists specifically for the previously-uncounted founder/present "Shape B" family |
| `skill-base.sh` "sourced by only 8 files" | 9 real sourcing sites, but the sharper fact is **6 of 16 functions have zero production callers**, and the callers that exist are almost entirely the two `/orchestrate` engines, not the direct-invocation skills | Adoption work targets `skill-researcher`/`skill-planner`/`skill-implementer` first (Phase 4) — they are the reference implementations that currently call nothing |
| Team skills need `## MUST NOT (Postflight Boundary)` restored | All three **already have it**; what they genuinely lack is `update-task-status.sh` routing and a real Stage 5b | Phase 2 restores the section to the three core `-hard` skills and both orchestrate skills only; Phase 6 handles the team-skill gaps that are real |
| Three drifted `Same as skill-X Stage N` cross-references | Two are **valid**; exactly one (`skill-planner-hard:405` → "skill-planner Stage 7a") is drifted, and it is **not cosmetic** — `skill-planner` has no Stage 7a and therefore silently drops `memory_candidates` today | Phase 4 creates a real Stage 7a in `skill-planner`, closing a latent functional gap; Phase 5 then replaces the cross-references with imports |
| MUST NOT presence "10 standard skills" | 28/91 exact heading, 32/91 any MUST NOT; the gap is **core-specific**, not `-hard`-general (lean/cslib `-hard` variants do carry it) | Phase 2's scope is 5 named files, not "all `-hard` skills" |

Two further report findings shape the plan beyond the description's framing:

- `skill-nix-implementation` and `skill-neovim-implementation` write **no marker at all** — they
  have zero premature-termination protection today. Phase 7 adds one. This is an intentional
  behavior fix carried inside a refactor, flagged as such so review does not read it as incidental.
- `context/patterns/skill-lifecycle.md` prescribes a `0/1-4/5/6` layout used by **zero** skills,
  while `docs/guides/creating-skills.md` already asserts (falsely today, correctly as a target) that
  core skills call `skill-base.sh` directly. Phase 11 makes the second doc true and rewrites the
  first to match, rather than maintaining two competing prescriptions.

### Prior Plan Reference

No prior plan. This is the first plan for this task.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and `roadmap_flag` is absent, so
`specs/ROADMAP.md` was not consulted and no roadmap review/update phases are included. ROADMAP.md
is not modified by this plan.

## Goals & Non-Goals

**Goals**:
- One canonical `.postflight-pending` schema, produced by exactly one code path
  (`skill_create_postflight_marker` in `skill-base.sh`), with a fixture test asserting the field set.
- Every pure-bash lifecycle stage (preflight, marker, memory-candidate propagation, artifact
  linking, TTS notify, cleanup) reached through a `skill-base.sh` function call, not a hand-copy.
- Every prose lifecycle stage (self-execution fallback, and the preflight/postflight narrative
  wrappers) reached through a single `@`-imported block carrying the `lit-stage4a-flow.md`
  drift-history header convention.
- `## MUST NOT (Postflight Boundary)` present in the three core `-hard` skills and both orchestrate
  skills, with `lint-postflight-boundary.sh` enforcing section presence, not just pattern absence.
- The three team skills routed through `update-task-status.sh` and given a real Stage 5b fallback.
- All 12 domain skills on the shared skeleton, each gaining the Stage 4a import so `--lit`,
  `--clean`, and memory retrieval work uniformly across task types.
- `context/patterns/skill-lifecycle.md` rewritten to describe the Stage-N skeleton that skills
  actually use, and registered in `context/index.json` so it stops being unreachable.

**Non-Goals**:
- Changing what any lifecycle stage *does* semantically. This is a de-duplication and
  routing refactor; the two deliberate behavior changes (marker protection for the nix/nvim
  implementation skills, memory-candidate propagation for `skill-planner`) are both fixes of
  documented gaps, are named in their phases, and are the only ones permitted.
- Touching `.claude/**`. It is a gitignored deploy artifact regenerated from
  `agent-system/extensions/**`; a hand-edit there is silently wiped.
- Adding new lifecycle stages, renumbering the existing Stage-N convention, or altering
  `skill-base.sh`'s existing function signatures (the marker fix derives `task_number` from the
  already-passed `padded_num` precisely to avoid an arity change and its 9-site blast radius).
- Retiring `docs/guides/creating-skills.md` or merging it into `skill-lifecycle.md`. The two stay
  separate documents with a stated division of labor.
- Any git push, PR, or `/merge` action.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A hand-edit lands in `.claude/**` and is silently wiped by the next deploy, making a phase look done when it is not | H | M | Every phase's file targets are `agent-system/extensions/**` paths only. Every phase that changes deployed behavior runs `bash .claude/scripts/deploy-headless.sh` then `bash .claude/scripts/verify-deploy.sh` **before** its verification is trusted. Phase 1 additionally establishes this as the standing loop. |
| Marker-schema change breaks a consumer that branches on which fields are present | H | L | Report confirms no consumer reads marker contents — `skill_cleanup` only `rm -f`s by path, `skill-refresh` only checks staleness by mtime. Phase 1 re-confirms with an explicit grep for readers before editing, recorded as its Scope Hypothesis. Target schema is the fullest observed (Shape A), so no field is lost. |
| `update-task-status.sh` is not a drop-in for the team skills' `state-write.sh` calls (its `target_status` vocabulary is `research`/`plan`/`implement`, not `team-research`) | M | M | Phase 6 opens by reading `update-task-status.sh`'s argument contract and mapping each team operation to a supported target status; if no safe mapping exists for a call site, that call site stays on `state-write.sh` and is recorded as a Reasoned Exclusion rather than force-fitted. |
| The 38-file marker sweep is wide enough that one agent run cannot finish it, leaving a half-converted corpus | M | M | Split across four phases by extension family (4, 5/6, 7/8, 9, 10) with a disjoint file territory each, so the system stays deployable and verifiable at every phase boundary. The zero-inline-heredoc assertion is only claimed in Phase 11, after every family is converted. |
| Adding a marker stage to `skill-nix-implementation`/`skill-neovim-implementation` is a behavior change disguised as a refactor | M | H (certain) | Phase 7 names it explicitly as an intentional fix (these two skills have no premature-termination protection today) and verifies the new marker is written and cleaned up, not merely that the text was added. |
| Section-presence lint fires on the ~59 skills that legitimately lack a MUST NOT section (non-delegating skills, direct-execution skills) | M | M | Phase 2 gates the new check behind the existing `does_skill_delegate()` predicate, exactly as the pattern checks already are, and verifies the full-corpus run is green before the phase closes. |
| A task-number citation leaks into a deliverable outside `specs/**` (all edits here are deliverables) | M | M | The write-time `validate-no-task-references.sh` PreToolUse hook blocks it; `verify-deploy.sh` gate 4 catches any that slip. Every phase's task list carries the deliverable-rule reminder; drift-history headers cite durable anchors (file/section names), never task numbers. |
| `skill-team-plan` already uses the heading "Stage 5b" for an unrelated concept ("Load Research Context") | L | H (certain) | Phase 6 does not assume the stage number is free in that file; it places the fallback under a non-colliding heading and notes the collision inline. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4, 6, 7 | 1, 3 |
| 4 | 5, 8, 9, 10 | 3, 4, 7 |
| 5 | 11 | 1-10 |

Phases within the same wave can execute in parallel. Territory is disjoint within each wave:
Wave 1 splits `skill-base.sh`+tests (P1) from the lint script + 5 named SKILL.md files (P2);
Wave 3 splits the three core skills (P4) from the three team skills (P6) from the
nix/nvim/latex/typst domain skills (P7); Wave 4 splits the three core `-hard` skills (P5) from the
remaining domain skills (P8) from the founder/present family (P9) from the core/cslib stragglers
(P10).

**Standing constraints — apply to every phase below, restated in each phase's task list:**
- **SOURCE-STORE RULE**: edit `agent-system/extensions/**` only. Never write to `.claude/**`.
- **REDEPLOY GATE**: any phase changing deployed behavior runs
  `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh`
  before its verification is trusted.
- **DELIVERABLE RULE**: no task-number references in any file outside `specs/**`. Cite durable
  anchors (filenames, section headings) instead.

---

### Phase 1: Settle the marker schema and complete skill-base.sh [COMPLETED]

**Goal**: One canonical `.postflight-pending` schema exists in exactly one place, and the two
lifecycle functions the corpus needs but `skill-base.sh` lacks (TTS notify, memory-candidate
propagation) are added and tested — so every later conversion phase has a call target.

**Tasks**:
- [x] Re-confirm the Scope Hypothesis below before editing: grep the whole source store for any
      *reader* of `.postflight-pending` contents (as opposed to path-existence/mtime checks). If a
      content reader is found, stop and record it — the no-shim assumption does not hold.
      *(completed: confirmed zero content readers — subagent-postflight.sh only finds/paths, no
      field reads)*
- [x] Adopt **Shape A** as the canonical schema: `session_id`, `skill`, `task_number`, `operation`,
      `reason`, `created`, `stop_hook_active`. Rationale to record in the function's header comment:
      it is the fullest observed shape, so unification loses no field; `task_number` is retained
      because 38 of 40 live writers already emit it; `stop_hook_active` is retained because it is a
      behavioral field the hard-mode variants dropped by drift, not by decision.
- [x] Update `skill_create_postflight_marker` in
      `agent-system/extensions/core/scripts/skill-base.sh` to emit Shape A. Derive `task_number`
      from the already-passed `padded_num` (strip leading zeros) — **do not add a parameter**; the
      signature stays 5-arg so the 9 existing `source`-sites are unaffected.
- [x] Add `skill_lifecycle_notify` to `skill-base.sh` (Stage 8a). Body is the single shape all 11
      current TTS blocks already share: guard on `[ -f ".claude/scripts/lifecycle-notify.sh" ]`,
      background-invoke with the resolved state status, never block.
- [x] Add `skill_propagate_memory_candidates` to `skill-base.sh` (Stage 7a). It reads
      `memory_candidates` from the task's `.return-meta.json` and writes it to `state.json` via
      `state-write.sh`, following `skill_propagate_completion_summary`'s established
      `SKILL_REPO_ROOT`-qualified-path and self-generated-`session_id` conventions. It is a separate
      function from `skill_propagate_completion_summary`, which does **not** handle
      `memory_candidates` today.
- [x] Create `agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh`: a
      fixture test that calls `skill_create_postflight_marker` in a scratch task dir and asserts the
      produced JSON's key set is **exactly** the seven Shape A keys (no more, no fewer), that
      `task_number` is an unpadded integer, and that the file parses as valid JSON.
- [x] Register the new test in `agent-system/extensions/core/manifest.json` under
      `provides.scripts` as `tests/test-postflight-marker-schema.sh`. Scripts are enumerated
      file-by-file in the manifest (unlike `context`, which is directory-level), so an unregistered
      test never reaches the deploy tree and is invisible to `run-all.sh` and `verify-deploy.sh`
      gate 8.
- [x] Confirm no `.claude/**` file was edited and no task number appears in any changed file.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: The report asserts (a) zero production callers of
`skill_create_postflight_marker`, and (b) no consumer branches on which marker fields are present —
`skill_cleanup` only `rm -f`s by path and `skill-refresh` only checks mtime. Confirm at
implementation time with:
`grep -rn "skill_create_postflight_marker" agent-system/extensions --include="*.sh" --include="SKILL.md"`
(expect hits only in `skill-base.sh`, its tests, and doc comments) and
`grep -rn "postflight-pending" agent-system/extensions --include="*.sh" | grep -vE "rm -f|find|mkdir|cat >"`
(expect no content-reading call site). If either is contradicted, a compatibility shim is required
and this phase's scope grows.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` — Shape A in `skill_create_postflight_marker`; add `skill_lifecycle_notify` and `skill_propagate_memory_candidates`
- `agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh` — new fixture test
- `agent-system/extensions/core/manifest.json` — register the new test under `provides.scripts`

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh` exits 0.
- `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` still exits 0 (no regression from the schema/function edits).
- `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh` — exits 0, and gate 8 (`run-all.sh`) reports the new suite as discovered and passing.
- `bash .claude/scripts/tests/run-all.sh` run from the **deployed** tree also discovers the new suite (proves the manifest registration reached the deploy, not just the source store).
- `git status --short` shows no modifications under `.claude/`.

---

### Phase 2: Restore the MUST NOT boundary and make the lint enforce presence [COMPLETED]

**Goal**: The five skills that lack a postflight-boundary contract get one, and
`lint-postflight-boundary.sh` gains the section-presence check that would have caught the gap —
turning a silent pass into a loud failure.

**Tasks**:
- [x] Add `## MUST NOT (Postflight Boundary)` to the three core hard skills:
      `skill-researcher-hard`, `skill-implementer-hard`, `skill-planner-hard`. Source the section
      text from `skill-researcher/SKILL.md`'s existing section (the reference implementation), not
      from memory. Note in the phase record that this gap is core-specific: the lean and cslib
      `-hard` variants already carry the section, so `-hard` is not the cause.
- [x] Add the section to `skill-orchestrate` and `skill-orchestrate-hard`.
      `skill-orchestrate` already has an unrelated `## MUST NOT (Context Flatness Constraint)` —
      add the postflight-boundary section **alongside** it, do not merge or replace.
      `skill-orchestrate-hard` currently has no MUST NOT section of any kind.
- [x] Add a section-presence check to
      `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh`: for any skill where
      `does_skill_delegate()` is true, assert a `## MUST NOT` heading exists; report a named
      violation if not. Gate it behind the existing `does_skill_delegate()` predicate so
      non-delegating and direct-execution skills are not falsely flagged — this mirrors how the
      existing pattern checks are already scoped. *(altered: also tightened
      `does_skill_delegate()` itself and switched the presence check to the specific
      `## MUST NOT (Postflight Boundary)` heading — see deviation note below)*
- [x] Create `agent-system/extensions/core/scripts/tests/test-lint-postflight-boundary.sh` with
      both polarities: a synthetic delegating skill **without** a MUST NOT section must make the
      lint exit non-zero; the same skill **with** the section must make it exit 0. Register it in
      `agent-system/extensions/core/manifest.json` under `provides.scripts`.
- [x] Wire `lint-postflight-boundary.sh` into
      `agent-system/extensions/core/scripts/verify-deploy.sh` as a new gate following the
      established gate structure (gates currently run `gate0`..`gate8`; add the next one, matching
      gate 6's agent-contracts-lint gate as the closest structural precedent, including its
      deploy-consumer skip behavior).
- [x] Confirm no `.claude/**` file was edited and no task number appears in any changed file.

**Deviation (altered, recorded per the standing DELIVERABLE/SOURCE-STORE constraints)**: the
original `does_skill_delegate()` predicate (`Agent tool|subagent_type|subagent|Invoke Subagent`)
false-positived on NEGATED prose ("executes inline **without** spawning a subagent" —
skill-refresh, skill-status-sync) and on any-`## MUST NOT`-heading presence (missing the
distinction between skill-orchestrate's pre-existing "Context Flatness Constraint" heading and
the postflight-boundary one). Both were tightened: `does_skill_delegate()` now requires a
positive delegation marker (`subagent_type:`, `Tool: Agent`, or the two team-skill Agent-tool
phrasings), verified against the known false-positive skills and the three team skills producing
zero regressions; the presence check anchors specifically on
`^## MUST NOT \(Postflight Boundary\)`. This also revealed the true corpus-wide scope: the report's
"may be larger than five" caveat resolved to exactly 3 additional files in THIS repo's actual
5-extension deployed footprint (`skill-email-implementation`, `skill-nix-research`,
`skill-neovim-research` — the other 8 source-store extensions the report's 91-skill count spans
are not loaded here, per `.claude-extensions.json`), all three also given the section so the
full deployed-corpus lint (verification bullet 3) is genuinely green now rather than deferred.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly five files need the section restored (`skill-researcher-hard`,
`skill-implementer-hard`, `skill-planner-hard`, `skill-orchestrate`, `skill-orchestrate-hard`), and
the three team skills do **not** (contradicting the task description). Confirm with
`grep -L "^## MUST NOT" agent-system/extensions/core/skills/*/SKILL.md` and, corpus-wide,
`grep -rL "^## MUST NOT" agent-system/extensions/*/skills/*/SKILL.md` cross-referenced against
`does_skill_delegate()`'s predicate — the set of *delegating* skills without the section is the true
scope, and it may be larger than five. If it is, extend this phase to cover every delegating skill
rather than leaving the new lint gate red.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-researcher-hard/SKILL.md` — add MUST NOT section
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` — add MUST NOT section
- `agent-system/extensions/core/skills/skill-planner-hard/SKILL.md` — add MUST NOT section
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — add postflight-boundary section alongside the existing flatness one
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — add MUST NOT section
- `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` — add section-presence check
- `agent-system/extensions/core/scripts/tests/test-lint-postflight-boundary.sh` — new both-polarity test
- `agent-system/extensions/core/scripts/verify-deploy.sh` — wire the lint in as a new gate
- `agent-system/extensions/core/manifest.json` — register the new test

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-postflight-boundary.sh` exits 0, proving both the negative case (missing section → non-zero) and the positive case.
- `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh` exits 0 with the new gate reporting PASS.
- `bash .claude/scripts/lint/lint-postflight-boundary.sh` run with no arguments (full deployed-corpus scan) exits 0 — no delegating skill is left without the section.
- `git status --short` shows no modifications under `.claude/`.

---

### Phase 3: Author the shared @-imported lifecycle blocks [COMPLETED]

**Goal**: The three shared prose blocks exist, each carrying the `lit-stage4a-flow.md` header
convention (placement rationale, single-canonical-source statement, named drift class it fixes,
explicit "every instruction below is DIRECT and EXECUTABLE" contract, and a Preconditions section
naming the variables the importing skill must already have in scope) — so conversion phases have
something to import.

**Tasks**:
- [x] Read `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` in full and treat
      its header structure as the template. Every new block reproduces: the placement rationale,
      the "SINGLE canonical block" statement naming its importers, the specific drift class being
      fixed (cite the measured divergence — six marker shapes, eleven duplicated TTS blocks, etc.),
      the directly-executable contract, and a `## Preconditions` section. *(completed)*
- [x] Create `agent-system/extensions/core/context/patterns/skill-preflight-flow.md` — Stage 2
      (preflight status update) + Stage 3 (marker creation). The bash bodies are **calls to**
      `skill_preflight_update` and `skill_create_postflight_marker`, not re-inlined logic; the
      block's prose covers sourcing `skill-base.sh`, ordering, and the failure semantics.
      *(completed)*
- [x] Create `agent-system/extensions/core/context/patterns/skill-postflight-flow.md` — Stage 7
      (postflight status update), Stage 7a (memory-candidate propagation), Stage 8 (artifact
      linking), Stage 8a (TTS notify), Stage 9 (cleanup). Again: calls to `skill_postflight_update`,
      `skill_propagate_completion_summary`, `skill_propagate_memory_candidates`,
      `skill_link_artifacts`, `skill_lifecycle_notify`, `skill_cleanup`. Document the
      `## Postflight (ALWAYS EXECUTE)` marker's placement relative to the block. *(completed:
      `skill_propagate_completion_summary` is documented as NOT part of this shared block —
      see deviation note below — the block covers the other five functions)*
- [x] Create `agent-system/extensions/core/context/patterns/skill-self-execution-fallback.md` —
      Stage 5b. This one is genuinely prose (agent instructions, not shell), so it stays an
      `@`-import rather than becoming a function. It must state the `.return-meta.json`
      write obligation explicitly, since the report found the team skills' degraded path produces no
      return metadata at all. *(completed)*
- [x] Record in each block's header which skills are expected to import it, and state the rule that
      a skill importing the block must not also keep an inline copy of the same stage. *(completed)*
- [x] No manifest change is needed: `provides.context` lists `patterns` as a **directory**, so new
      files under `context/patterns/` deploy automatically. Confirm this by inspecting
      `agent-system/extensions/core/manifest.json` rather than assuming. *(completed: confirmed via
      `jq -r '.provides.context' agent-system/extensions/core/manifest.json`)*
- [x] Follow `lit-stage4a-flow.md`'s precedent of **not** registering these blocks in
      `index-entries.json`: they are reached by direct `@`-import from a skill body, not by context
      discovery. (`skill-lifecycle.md` in Phase 11 is the opposite case and *is* registered.)
      *(deviation: altered — see deviation note below)*
- [x] Confirm no `.claude/**` file was edited and no task number appears in any changed file.
      *(completed: `git status --short` shows zero `.claude/` modifications;
      `check-task-references.sh` passes)*

**Deviation (altered)**: the task list's premise that `lit-stage4a-flow.md` is NOT registered in
`index-entries.json` was factually wrong — it IS registered (`agent-system/extensions/core/index-entries.json`,
path `patterns/lit-stage4a-flow.md`), and `check-extension-docs.sh`'s Rule S enforces that every
deployed `context/**/*.md` file has an index entry (verified empirically: registering none of the
three new files produced three Rule S `FAIL`s under `verify-deploy.sh` gate 3). All three new
blocks were therefore registered in `agent-system/extensions/core/index-entries.json` following
the exact `load_when.agents` set `lit-stage4a-flow.md` already uses, and
`generate-context-line-counts.sh --check` confirms exact `line_count` values for all three. This
does not touch `manifest.json` (script/test registration) — only `index-entries.json`, which is
what Rule S actually reads.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/skill-preflight-flow.md` — new
- `agent-system/extensions/core/context/patterns/skill-postflight-flow.md` — new
- `agent-system/extensions/core/context/patterns/skill-self-execution-fallback.md` — new

**Verification**:
- All three files exist, are non-empty, and each contains a `## Preconditions` section and a drift-history header paragraph naming the drift class it fixes.
- No block contains commented-out pseudocode inside a bash fence (the `lit-stage4a-flow.md` "DIRECT and EXECUTABLE" contract): `grep -n "^# *[a-z].*\$" ` review of each fenced block confirms every line is executable or an intentional explanatory comment.
- Every `skill_*` function named in the blocks exists in `skill-base.sh`: for each name, `grep -c "^<name>()" agent-system/extensions/core/scripts/skill-base.sh` returns 1.
- `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh` exits 0, and all three files are present under `.claude/context/patterns/` afterwards (proves the directory-level manifest entry carried them).
- `git status --short` shows no modifications under `.claude/`.

---

### Phase 4: Convert the three core skills onto the shared skeleton [COMPLETED]

**Goal**: `skill-researcher`, `skill-planner`, and `skill-implementer` — the reference
implementations that today call **zero** `skill-base.sh` functions — import the shared blocks and
route every lifecycle stage through `skill-base.sh`. `skill-planner` gains the Stage 7a it has never
had, closing the dropped-`memory_candidates` gap.

**Tasks**:
- [x] In `skill-researcher/SKILL.md`, replace the hand-written Stage 2, Stage 3, Stage 5b, Stage 7,
      Stage 7a, Stage 8, Stage 8a, and Stage 9 bodies with `@`-imports of the three Phase 3 blocks.
      Preserve the file's existing Stage numbering and its `## Postflight (ALWAYS EXECUTE)` marker —
      that numbering is the convention Phase 11 will document, not something to change here.
      Preserve Stage 4a's existing `lit-stage4a-flow.md` import untouched. *(completed)*
- [x] Do the same for `skill-implementer/SKILL.md`. Note its divergences from the researcher
      skeleton (Stage 7 embeds researcher's 7+7a as "Steps 1-4"; it has a continuation loop, Stage
      5a/5c, a Stage 6b commit-inside-loop, and a Stage 9 Git Commit distinct from Stage 10 Cleanup).
      Convert only what the shared blocks cover; leave the implementer-specific stages alone and
      record which ones were deliberately not touched. *(completed: Stage 9 Git Commit and Stages
      5a/5c/6b left untouched as implementer-specific; Stage 7's memory-candidate Step 4 and
      Stage 8/8a converted to shared-function calls; a redundant duplicate `source
      skill-base.sh` at old Stage 7 Steps 2-3 was removed since Stage 2+3 now sources it once)*
- [x] In `skill-planner/SKILL.md`, replace the hand-written stages **and add a real Stage 7a**
      between its existing Stage 7 and Stage 8, calling `skill_propagate_memory_candidates`. This is
      an intentional behavior fix, not a refactor artifact: `skill-planner` has no Stage 7a today and
      `grep memory_candidates skill-planner/SKILL.md` currently returns zero hits, so candidates
      emitted by `planner-agent` are silently discarded. *(completed: added `memory_candidates` read
      at Stage 6, a real `### Stage 7a: Propagate Memory Candidates` heading, and kept Stage 9 Git
      Commit / Stage 10 Cleanup as this skill's own interleaved stages, per deviation note below)*
- [x] Verify each converted skill still `source`s `skill-base.sh` exactly once, near the top of its
      first bash-bearing stage. *(completed: confirmed via
      `grep -c '^source .claude/scripts/skill-base.sh'` returning 1 for all three)*
- [x] Confirm no `.claude/**` file was edited and no task number appears in any changed file.
      *(completed: `git status --short` shows zero `.claude/` modifications;
      `check-task-references.sh` passes)*

**Deviation (altered)**: `skill-planner`'s Stage 9 (Git Commit) sits between Stage 8a (TTS notify)
and Stage 10 (Cleanup) in its existing numbering, unlike `skill-researcher`'s skeleton where
cleanup follows notify directly. The `skill-postflight-flow.md` import was therefore split at its
natural stage boundaries rather than imported as one contiguous block: Stage 7/7a/8/8a import the
shared block's corresponding stages, and Stage 10 calls `skill_cleanup` directly (documented as
reusing the shared block's Stage 9 behavior from a different physical location) rather than
importing the whole fragment verbatim at one site. This is a structural accommodation, not a
scope or behavior change — every function call the shared block specifies is still made exactly
once, in the same order, just split across this skill's pre-existing stage boundaries.

**Timing**: 2.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: These three files currently contain zero occurrences of `skill-base.sh` or any
`skill_*` function name. Confirm before editing with
`grep -c "skill-base.sh\|skill_preflight_update\|skill_create_postflight_marker\|skill_cleanup\|skill_link_artifacts\|skill_postflight_update" agent-system/extensions/core/skills/skill-{researcher,planner,implementer}/SKILL.md`
— the report measured 0 for `skill-researcher` and 1 real call site
(`skill_propagate_completion_summary`) for `skill-implementer`. If `skill-implementer` has more call
sites than the report found, reconcile rather than overwrite.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-researcher/SKILL.md` — import shared blocks; route Stages 2/3/5b/7/7a/8/8a/9 through `skill-base.sh`
- `agent-system/extensions/core/skills/skill-planner/SKILL.md` — same, **plus** add Stage 7a (new behavior)
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` — same for the stages the shared blocks cover

**Verification**:
- `grep -c "cat > .*postflight-pending" <each of the three files>` returns 0.
- `grep -c "skill_create_postflight_marker" <each>` returns at least 1 (directly or via the imported block).
- `grep -c "memory_candidates\|skill_propagate_memory_candidates" agent-system/extensions/core/skills/skill-planner/SKILL.md` returns at least 1 — the previously-missing Stage 7a is present.
- `grep -c "### Stage 7a" agent-system/extensions/core/skills/skill-planner/SKILL.md` returns 1.
- `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh` exits 0.
- `bash .claude/scripts/lint/lint-postflight-boundary.sh` (full corpus) exits 0 — the Phase 2 gate still passes after the rewrites.
- End-to-end smoke: run `/research` against a scratch task and confirm `specs/{NNN}_{SLUG}/.postflight-pending` is created with the Shape A key set and removed at cleanup.
- `git status --short` shows no modifications under `.claude/`.

---

### Phase 5: Convert the three core hard skills and replace the prose cross-references [NOT STARTED]

**Goal**: `skill-researcher-hard`, `skill-planner-hard`, and `skill-implementer-hard` share the same
skeleton as their standard counterparts, and the three `Same as skill-X Stage N` prose
cross-references become real imports that cannot drift.

**Tasks**:
- [ ] Convert all three core `-hard` skills to import the Phase 3 blocks, exactly as Phase 4 did for
      the standard skills. Their marker heredocs are "Shape C" (dropping `created` and
      `stop_hook_active`); the conversion restores those fields via the shared function — note this
      as an intended unification, since the report found the drop was drift, not a hard-mode design
      decision.
- [ ] Replace `skill-researcher-hard/SKILL.md`'s two cross-references ("Same as `skill-researcher`
      Stage 7a", "Same as `skill-researcher` Stage 8") with imports of the shared postflight block.
      Both targets are currently **valid**, so this is drift-proofing, not a bug fix.
- [ ] Replace `skill-planner-hard/SKILL.md`'s cross-reference ("Same as `skill-planner` Stage 7a
      pattern") with an import. This one is currently **drifted and functionally broken**: its
      target did not exist until Phase 4 created it. Verify the import resolves to the same shared
      block `skill-planner` now uses.
- [ ] Confirm the Phase 2 MUST NOT sections added to these same three files survived the rewrite.
- [ ] Confirm no `.claude/**` file was edited and no task number appears in any changed file.

**Timing**: 2 hours

**Depends on**: 3, 4

**Verification Tier**: interface

**Scope Hypothesis**: Exactly three `Same as skill-` prose cross-references exist in core skills
(two valid, one drifted). Confirm with
`grep -rn "[Ss]ame as skill-" agent-system/extensions/core/skills/` before editing; if the count
differs from three, resolve each additional hit the same way rather than leaving it.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-researcher-hard/SKILL.md` — shared blocks; replace 2 cross-references
- `agent-system/extensions/core/skills/skill-planner-hard/SKILL.md` — shared blocks; replace the drifted cross-reference
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` — shared blocks

**Verification**:
- `grep -rn "[Ss]ame as skill-" agent-system/extensions/core/skills/` returns zero hits.
- `grep -c "cat > .*postflight-pending" <each of the three files>` returns 0.
- `grep -c "^## MUST NOT (Postflight Boundary)" <each of the three files>` returns 1 (Phase 2's work preserved).
- `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh` exits 0.
- `bash .claude/scripts/lint/lint-postflight-boundary.sh` exits 0.
- `git status --short` shows no modifications under `.claude/`.

---

### Phase 6: Route the team skills through update-task-status.sh and give them a real fallback [NOT STARTED]

**Goal**: `skill-team-research`, `skill-team-plan`, and `skill-team-implement` stop hand-rolling
state writes, so TODO.md's Task Order block is no longer stale for the whole duration of a team run,
and their degraded path produces return metadata instead of silently re-delegating.

**Tasks**:
- [ ] **First**, read `agent-system/extensions/core/scripts/update-task-status.sh`'s argument
      contract in full. Its `target_status` vocabulary is `research`/`plan`/`implement`/`pr_ready`/
      `partial`/`blocked` — there is no `team-research` value — and it regenerates TODO.md
      internally via `generate-todo.sh` (there is no `--regen-todo` flag on it, unlike the
      `state-write.sh` calls the team skills currently make). Map each team-skill call site to a
      supported target status before changing anything.
- [ ] Replace the preflight `state-write.sh` call in each of the three team skills with an
      `update-task-status.sh preflight` call using the mapped target status. This is the fix for the
      stale-Task-Order finding: TODO.md is regenerated at preflight, not only at postflight.
- [ ] Replace the postflight `state-write.sh` call in each with `update-task-status.sh postflight`.
- [ ] If any call site has no safe mapping (e.g. a multi-teammate intermediate write with no
      single-task equivalent), leave it on `state-write.sh` and record it as a
      `#### Reasoned Exclusions` entry under this phase with the evidence that forced it. Do not
      force-fit a mapping.
- [ ] Give each team skill a real self-execution fallback importing
      `skill-self-execution-fallback.md`. It must write `.return-meta.json` itself rather than
      re-delegating wholesale to `skill-researcher`/`skill-planner`/`skill-implementer`, which is
      what the current "Stage 4a: Fallback to Single Agent" does.
- [ ] **Heading-collision guard**: `skill-team-plan` already uses the heading "Stage 5b" for an
      unrelated concept ("Load Research Context"). Do not reuse that number in that file; place the
      fallback under a non-colliding heading and add an inline note recording the collision.
- [ ] Route the three team skills' marker creation and cleanup through the Phase 3 blocks (their
      current markers are "Shape D", adding `team_size` and dropping `created`/`stop_hook_active`).
      Decide and record whether `team_size` survives as an extra field or is dropped — the canonical
      Shape A does not include it, and the fixture test asserts an exact key set.
- [ ] Do **not** add `## MUST NOT (Postflight Boundary)` — all three already have it (the task
      description's framing here does not hold). Verify it survived the rewrite instead.
- [ ] Confirm no `.claude/**` file was edited and no task number appears in any changed file.

**Timing**: 2.5 hours

**Depends on**: 1, 3

**Verification Tier**: interface

**Scope Hypothesis**: Each team skill has exactly two `state-write.sh` state-status call sites (one
preflight, one postflight), and zero `update-task-status.sh` calls. Confirm with
`grep -n "state-write.sh\|update-task-status.sh" agent-system/extensions/core/skills/skill-team-{research,plan,implement}/SKILL.md`
before editing. Additional call sites (artifact writes, teammate bookkeeping) are out of scope for
this phase and must not be converted — only task-status writes.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-team-research/SKILL.md`
- `agent-system/extensions/core/skills/skill-team-plan/SKILL.md`
- `agent-system/extensions/core/skills/skill-team-implement/SKILL.md`

**Verification**:
- `grep -c "update-task-status.sh" <each of the three files>` returns at least 2.
- `grep -c "cat > .*postflight-pending" <each>` returns 0.
- Each file contains an import of `skill-self-execution-fallback.md`, and the fallback text names `.return-meta.json` as a write obligation.
- `grep -c "^## MUST NOT (Postflight Boundary)" <each>` returns at least 1 (pre-existing section preserved).
- `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh` exits 0.
- Behavioral check: run a team operation against a scratch task (or dry-run the preflight call directly) and confirm TODO.md's Task Order block is regenerated at preflight, not only at postflight.
- `git status --short` shows no modifications under `.claude/`.

---

### Phase 7: Collapse the nix/nvim and latex/typst domain pairs [NOT STARTED]

**Goal**: The four most-duplicated domain skills pairs (86-90% pairwise identical) move onto the
shared skeleton and each gains the Stage 4a import, so `--lit`, `--clean`, and memory retrieval stop
being silent no-ops for nix, neovim, latex, and typst tasks. The two nix/nvim implementation skills
additionally gain premature-termination protection they have never had.

**Tasks**:
- [ ] Convert the eight files to the shared skeleton: import
      `lit-stage4a-flow.md` (Stage 4a), `skill-preflight-flow.md`, `skill-postflight-flow.md`, and
      `skill-self-execution-fallback.md`. Preserve each skill's genuinely domain-specific content
      (build/verification commands, domain context imports, agent routing) verbatim.
- [ ] **Intentional behavior fix, flagged**: `skill-nix-implementation` and
      `skill-neovim-implementation` currently write **no** `.postflight-pending` marker at all — they
      have zero premature-termination protection. Adding the Phase 3 preflight block gives them one.
      This is a deliberate fix carried inside a refactor, not an incidental side effect; record it in
      the phase notes and in the implementation summary so review does not miss it.
- [ ] These two files are also the only domain skills that already call a `skill-base.sh` function
      (`skill_propagate_completion_summary`). Preserve that call; the shared postflight block should
      subsume it rather than duplicate it.
- [ ] Restore `## Error Handling` to `skill-nix-research`, `skill-nix-implementation`,
      `skill-neovim-research`, and `skill-neovim-implementation`, sourcing the section from the
      latex/typst skills that still have it — the report confirms these four lost it to drift.
- [ ] Normalize each pair's Stage numbering onto the core convention. The nix/nvim implementation
      skills currently use a third, thinner numbering (Stage 4b for the fallback, no Stage 3a/4a/8a);
      align them with the core Stage-N skeleton so Phase 11's documentation describes one shape.
- [ ] Confirm no `.claude/**` file was edited and no task number appears in any changed file.

**Timing**: 2.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: Eight files are in scope
(`skill-nix-research`, `skill-nix-implementation`, `skill-neovim-research`,
`skill-neovim-implementation`, `skill-latex-research`, `skill-latex-implementation`,
`skill-typst-research`, `skill-typst-implementation`), and **zero** of them currently reference
`lit-stage4a-flow.md`, call `memory-retrieve.sh`, or have a Stage 4a heading. Confirm with
`grep -rlc "lit-stage4a-flow\|memory-retrieve.sh\|Stage 4a" agent-system/extensions/{nix,nvim,latex,typst}/skills/*/SKILL.md`
(expect 0 hits) before editing.

**Files to modify**:
- `agent-system/extensions/nix/skills/skill-nix-research/SKILL.md`
- `agent-system/extensions/nix/skills/skill-nix-implementation/SKILL.md` — **adds a marker stage where none existed**
- `agent-system/extensions/nvim/skills/skill-neovim-research/SKILL.md`
- `agent-system/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` — **adds a marker stage where none existed**
- `agent-system/extensions/latex/skills/skill-latex-research/SKILL.md`
- `agent-system/extensions/latex/skills/skill-latex-implementation/SKILL.md`
- `agent-system/extensions/typst/skills/skill-typst-research/SKILL.md`
- `agent-system/extensions/typst/skills/skill-typst-implementation/SKILL.md`

**Verification**:
- Each of the eight files contains an import of `lit-stage4a-flow.md`: `grep -l "lit-stage4a-flow" <each>` matches all eight.
- Each contains a `### Stage 4a` heading.
- `grep -c "^## Error Handling"` returns 1 for all four nix/nvim files.
- `grep -c "cat > .*postflight-pending" <each>` returns 0, and each reaches marker creation via the shared block.
- `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh` exits 0.
- **Stage 4a trace assertion (verification-bar item 4)**: run `/research <scratch-neovim-task> --lit` and confirm the transcript contains a `[lit` notice (`[lit:auto]`, `[lit] Skipped by user choice`, or a `<literature-briefing>` block) — proving the resolver was reached. Independently, `bash .claude/scripts/literature-lit-flag-resolve.sh --lit-flag true --orchestrator-mode false --query "neovim keymap"` prints one of the six directives.
- Marker behavior check for the two newly-protected skills: run a neovim implementation against a scratch task, confirm `.postflight-pending` appears with the Shape A key set and is removed at cleanup.
- `git status --short` shows no modifications under `.claude/`.

---

### Phase 8: Collapse the remaining domain skills [NOT STARTED]

**Goal**: The remaining domain research/implementation skills (z3, python, web, email, epi) join the
shared skeleton, so no task type is left without Stage 4a.

**Tasks**:
- [ ] Enumerate the remaining domain skill files at implementation time rather than trusting a
      plan-time list (see Scope Hypothesis). Expected families: z3, python, web, email, epidemiology.
- [ ] Apply the identical conversion Phase 7 established — the four Phase 3 imports plus the
      `lit-stage4a-flow.md` Stage 4a import — reusing Phase 7's converted files as the worked
      reference rather than re-deriving the pattern.
- [ ] Restore `## Error Handling` to the z3 and python skills, which the report confirms lack it,
      sourcing from the latex/typst reference.
- [ ] Normalize Stage numbering onto the core convention, as in Phase 7.
- [ ] Confirm no `.claude/**` file was edited and no task number appears in any changed file.

**Timing**: 2 hours

**Depends on**: 7

**Verification Tier**: interface

**Scope Hypothesis**: The report checked 17 domain files total and found 0/0/0 for
`lit-stage4a-flow.md` / `memory-retrieve.sh` / `Stage 4a` across nix, nvim, latex, typst, z3,
python, web, email, and epi. Phase 7 handled 8; this phase's remainder is therefore expected to be
roughly 9 files. Enumerate exactly at implementation time with
`grep -rL "lit-stage4a-flow" agent-system/extensions/*/skills/skill-*-{research,implementation,implement}/SKILL.md`
and convert every hit — the true count governs, not the estimate.

**Files to modify**:
- `agent-system/extensions/z3/skills/skill-z3-research/SKILL.md`, `.../skill-z3-implementation/SKILL.md`
- `agent-system/extensions/python/skills/skill-python-research/SKILL.md`, `.../skill-python-implementation/SKILL.md`
- `agent-system/extensions/web/skills/skill-web-research/SKILL.md`, `.../skill-web-implementation/SKILL.md`
- `agent-system/extensions/email/skills/skill-email-implementation/SKILL.md`
- `agent-system/extensions/epidemiology/skills/skill-epi-research/SKILL.md`, `.../skill-epi-implement/SKILL.md`
- (plus any additional file the Scope Hypothesis enumeration surfaces)

**Verification**:
- `grep -rL "lit-stage4a-flow" agent-system/extensions/*/skills/skill-*-{research,implementation,implement}/SKILL.md` returns no files.
- `grep -c "^## Error Handling"` returns 1 for the z3 and python skills.
- `grep -rc "cat > .*postflight-pending"` returns 0 for every file touched in this phase.
- `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh` exits 0.
- `bash .claude/scripts/lint/lint-postflight-boundary.sh` exits 0.
- `git status --short` shows no modifications under `.claude/`.

---

### Phase 9: Convert the founder/present marker family [NOT STARTED]

**Goal**: The 15-file "Shape B" family (`task_number` + `created`, no `stop_hook_active`) — the
variant the task description's four-shape framing missed entirely — moves onto the shared marker
path.

**Tasks**:
- [ ] Enumerate the Shape B writers at implementation time. The report names: `skill-founder-implement`,
      `skill-budget`, `skill-web-research`, `skill-deck-plan`, `skill-deck-research`, `skill-finance`,
      `skill-analyze`, `skill-founder-plan`, `skill-project`, `skill-deck-implement`, `skill-meeting`,
      `skill-founder-spreadsheet`, `skill-legal`, `skill-strategy`, `skill-market`. Note
      `skill-web-research` may already be handled by Phase 8 — de-duplicate against that phase's
      actual output rather than converting twice.
- [ ] Replace each file's inline marker heredoc and inline cleanup block with the Phase 3 shared
      blocks. These are largely non-lifecycle content skills, so convert **only** the marker,
      cleanup, preflight, and TTS stages; do not restructure their domain bodies.
- [ ] For any file in this family where `does_skill_delegate()` is true but no
      `## MUST NOT (Postflight Boundary)` section exists, add one — Phase 2's lint gate will
      otherwise fail the corpus scan.
- [ ] Confirm no `.claude/**` file was edited and no task number appears in any changed file.

**Timing**: 2 hours

**Depends on**: 3, 4

**Verification Tier**: local

**Scope Hypothesis**: 15 files carry Shape B. Confirm the live set at implementation time with a
per-file heredoc field probe rather than trusting the list — e.g. for each candidate,
`sed -n '/postflight-pending/,/^EOF/p' <file> | grep -c '"stop_hook_active"'` returning 0 while
`grep -c '"task_number"'` returns 1. Convert the measured set, not the plan-time list.

**Files to modify**:
- The founder and present extension skills enumerated above, under `agent-system/extensions/founder/skills/*/SKILL.md` and `agent-system/extensions/present/skills/*/SKILL.md`

**Verification**:
- `grep -rlc "cat > .*postflight-pending" agent-system/extensions/{founder,present}/skills/*/SKILL.md` returns no files.
- `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh` exits 0.
- `bash .claude/scripts/lint/lint-postflight-boundary.sh` exits 0 across the full corpus.
- `git status --short` shows no modifications under `.claude/`.

---

### Phase 10: Convert the remaining marker writers [NOT STARTED]

**Goal**: Every remaining inline marker writer — the core stragglers, the cslib family, and the two
`touch`-only skills — is converted, so the zero-inline-heredoc assertion becomes claimable.

**Tasks**:
- [ ] Enumerate every remaining inline writer at implementation time (see Scope Hypothesis).
      Expected remainder: `skill-spawn`, `skill-reviser`, `skill-financial-analysis`, the cslib
      `-hard` skills (`skill-cslib-research-hard`, `skill-cslib-implementation-hard`),
      `skill-pr-implementation`, and the two `touch`-only cslib pr-review skills.
- [ ] Convert the JSON-heredoc writers to the shared marker block.
- [ ] Convert the two `touch`-only writers (`skill-pr-review-implementation`,
      `skill-pr-review-research`) — they create an empty marker file with no metadata inside. Moving
      them to `skill_create_postflight_marker` gives them the full Shape A payload; confirm their
      matching `rm -f` cleanup still targets the same path.
- [ ] Exclude `skill-refresh` explicitly: it only *reads and deletes* orphaned markers as part of its
      cleanup sweep and never writes one. It is a false positive in the raw 41-file grep. Record this
      as a `#### Reasoned Exclusions` entry with the evidence (its `find ... -delete` / `rm -f` call
      sites and the absence of any `cat >` marker write).
- [ ] Confirm no `.claude/**` file was edited and no task number appears in any changed file.

**Timing**: 2 hours

**Depends on**: 3, 4

**Verification Tier**: local

**Scope Hypothesis**: The corpus has 41 files mentioning `.postflight-pending`, of which 38 write an
inline heredoc, 2 use a bare `touch`, and 1 (`skill-refresh`) is a read/delete-only false positive.
After Phases 4-9, the remainder in this phase should be small. Enumerate exactly with
`grep -rl "postflight-pending" agent-system/extensions/*/skills/*/SKILL.md` minus the files already
converted, and verify each remaining hit is either a true writer (convert) or a reader/deleter
(exclude with evidence). The stated remainder list is a hypothesis; the measured set governs.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-spawn/SKILL.md`
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md`
- `agent-system/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md`
- `agent-system/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md`
- `agent-system/extensions/cslib/skills/skill-pr-implementation/SKILL.md`
- `agent-system/extensions/cslib/skills/skill-pr-review-implementation/SKILL.md` — `touch` → shared marker
- `agent-system/extensions/cslib/skills/skill-pr-review-research/SKILL.md` — `touch` → shared marker
- (plus any additional file the Scope Hypothesis enumeration surfaces)

**Verification**:
- `grep -rl "cat > .*postflight-pending\|postflight-pending.*<<" agent-system/extensions/*/skills/*/SKILL.md` returns no files.
- `grep -rl "touch .*postflight-pending" agent-system/extensions/*/skills/*/SKILL.md` returns no files.
- `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh` exits 0.
- `bash .claude/scripts/lint/lint-postflight-boundary.sh` exits 0.
- `git status --short` shows no modifications under `.claude/`.

---

### Phase 11: Rewrite skill-lifecycle.md, index it, and satisfy the full verification bar [NOT STARTED]

**Goal**: The prescriptive documentation matches reality and is reachable, and every one of the
task's four verification-bar claims is demonstrated end-to-end in a single pass.

**Tasks**:
- [ ] Rewrite `agent-system/extensions/core/context/patterns/skill-lifecycle.md` to document the
      Stage-N skeleton skills actually use. Its current `### 0. Preflight` / `### 1-4.` / `### 5.` /
      `### 6.` layout is used by **zero** of the 91 skills. Use the (now-converted)
      `skill-researcher/SKILL.md` stage list as the reference shape, and document each shared block
      and `skill-base.sh` function as the canonical implementation of its stage.
- [ ] State the division of labor with `docs/guides/creating-skills.md` explicitly in both
      directions, so the two stop being competing prescriptions: `creating-skills.md` keeps the
      `skill-base.sh` function table and authoring walkthrough; `skill-lifecycle.md` owns the
      Stage-N skeleton and the shared-block map. Update `creating-skills.md`'s claim that core
      skills "use `skill-base.sh` lifecycle functions directly" — it was false when written and is
      true after Phase 4, so add a pointer rather than deleting it.
- [ ] Register the rewritten `skill-lifecycle.md` in the core extension's `index-entries.json` so it
      is reachable via context discovery. This is the deliberate opposite of the Phase 3 blocks,
      which follow `lit-stage4a-flow.md`'s `@`-import-only precedent. Recompute the entry's
      `line_count` with `bash .claude/scripts/generate-context-line-counts.sh --write` (or `--check`
      first) rather than hand-writing it.
- [ ] Update `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` if its
      "Correct Postflight (skill-researcher pattern)" example no longer matches the converted
      `skill-researcher`.
- [ ] Run the complete verification bar (below) and record each result in the implementation summary
      with the actual command output, not a claim.
- [ ] Confirm no `.claude/**` file was edited and no task number appears in any changed file.

**Timing**: 2 hours

**Depends on**: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/context/patterns/skill-lifecycle.md` — full rewrite
- `agent-system/extensions/core/docs/guides/creating-skills.md` — reconcile with the rewritten pattern doc
- `agent-system/extensions/core/context/index-entries.json` — register `skill-lifecycle.md`
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` — refresh the example if drifted

**Verification** (this is the task's full verification bar):
1. **Zero inline marker copies**: `grep -rl "postflight-pending" agent-system/extensions/*/skills/*/SKILL.md | xargs grep -l "cat >\|<<\|touch "` returns nothing; the only marker-producing code path is `skill_create_postflight_marker` in `skill-base.sh`.
2. **Identical-schema marker**: `bash agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh` exits 0, asserting the exact Shape A key set through `skill-base.sh`.
3. **Lint enforces section presence**: `bash agent-system/extensions/core/scripts/tests/test-lint-postflight-boundary.sh` exits 0 (negative case fails as required), and `bash .claude/scripts/lint/lint-postflight-boundary.sh` over the full corpus exits 0.
4. **Domain `--lit` reaches Stage 4a**: `/research <scratch-neovim-task> --lit` produces a `[lit` notice or `<literature-briefing>` block in the transcript.
- Plus: `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh` exits 0 with every gate PASS, and `bash .claude/scripts/tests/run-all.sh` exits 0.
- Plus: `bash .claude/scripts/check-task-references.sh` exits 0 (deliverable rule held across ~70 changed files).
- Plus: `jq -e '.entries[] | select(.path | test("skill-lifecycle"))' agent-system/extensions/core/context/index-entries.json` succeeds, and `bash .claude/scripts/generate-context-line-counts.sh --check` reports no drift.
- `git status --short` shows no modifications under `.claude/`.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh` — exact Shape A key set through `skill-base.sh`.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-lint-postflight-boundary.sh` — both polarities of the section-presence check.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — no regression in existing lifecycle functions.
- [ ] `bash .claude/scripts/tests/run-all.sh` — full shell suite, from the deployed tree (also proves manifest registration of both new tests).
- [ ] `bash .claude/scripts/verify-deploy.sh` — all gates PASS, including the new postflight-boundary gate.
- [ ] `bash .claude/scripts/lint/lint-postflight-boundary.sh` — full-corpus scan exits 0.
- [ ] `bash .claude/scripts/check-task-references.sh` — no task-number citations in any changed deliverable.
- [ ] Zero-inline-heredoc grep across all SKILL.md files returns nothing.
- [ ] End-to-end smoke: one `/research`, one `/plan`, and one domain (`neovim`) `--lit` run against scratch tasks, each producing a Shape A marker that is created at preflight and removed at cleanup.
- [ ] `git status --short` confirms zero modifications under `.claude/` at every phase boundary.

## Artifacts & Outputs

- `specs/983_extract_shared_skill_stage_skeleton/plans/01_shared-skill-stage-skeleton.md` (this plan)
- `specs/983_extract_shared_skill_stage_skeleton/summaries/01_shared-skill-stage-skeleton-summary.md` (on completion)
- Three new shared context blocks: `skill-preflight-flow.md`, `skill-postflight-flow.md`, `skill-self-execution-fallback.md` under `agent-system/extensions/core/context/patterns/`
- Two new test suites: `test-postflight-marker-schema.sh`, `test-lint-postflight-boundary.sh` under `agent-system/extensions/core/scripts/tests/`
- Modified: `skill-base.sh` (settled schema + two new functions), `lint-postflight-boundary.sh` (section-presence check), `verify-deploy.sh` (new gate), `manifest.json` (two script registrations), `index-entries.json` (one context registration)
- Rewritten: `context/patterns/skill-lifecycle.md`; reconciled: `docs/guides/creating-skills.md`
- Converted: ~40 SKILL.md files across the core, cslib, nix, nvim, latex, typst, z3, python, web, email, epidemiology, founder, and present extensions

## Rollback/Contingency

- Every phase is committed separately per the Commit-Per-Green-Substep Mandate, and the system is
  deployable and verifiable at each phase boundary. Reverting is `git revert` of the phase's commits
  followed by `bash .claude/scripts/deploy-headless.sh` to regenerate `.claude/` from the restored
  source store.
- Because `.claude/` is a gitignored deploy artifact, no rollback needs to touch it directly — a
  redeploy from the reverted source store is always sufficient and is the only supported path.
- If Phase 1's Scope Hypothesis is contradicted (a live consumer reads marker contents), stop before
  editing `skill_create_postflight_marker`, add a compatibility shim reading both old and new
  shapes, and re-plan Phases 9-10 around it rather than proceeding.
- If a wide sweep phase (7-10) runs out of context mid-file-set, mark it `[PARTIAL]`, commit the
  green subset, and resume — the phases are ordered so a partial sweep never leaves the deploy
  broken, only incompletely converted. The zero-inline-heredoc assertion is deliberately deferred to
  Phase 11 so no earlier phase can falsely claim it.
- If `update-task-status.sh` proves unsafe for a team-skill call site (Phase 6), that call site stays
  on `state-write.sh` and is recorded as a Reasoned Exclusion; the phase still closes green with the
  converted call sites.
