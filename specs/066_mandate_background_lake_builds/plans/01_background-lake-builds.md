# Implementation Plan: Task #66

- **Task**: 66 - Mandate run_in_background for Lean builds and add long-builds anchor
- **Status**: [IMPLEMENTING]
- **Effort**: 3.25 hours
- **Dependencies**: core build-guard task (DELIVERED: `agent-system/extensions/core/scripts/lake-build-guard.sh` is committed)
- **Research Inputs**: specs/066_mandate_background_lake_builds/reports/01_mandate-background-lake-builds.md
- **Artifacts**: plans/01_background-lake-builds.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This is a single contract-text pass over the lean extension's source store that makes two
obligations mandatory together at every site that instructs an agent to run `lake build`:
detached invocation via `Bash(run_in_background: true)`, and invocation through the shared
`lake-build-guard.sh` wrapper. The prose lives in exactly one new canonical anchor,
`context/project/lean4/operations/long-builds.md`; the eight existing contract files gain
pointers and mandate text, never a restatement of the anchor's prose.

Phase 1 creates the anchor because every later phase cites it. Phases 2-5 then edit the four
contract clusters in parallel (implementation-agent twins, `rules/lean4.md`, the
`skill-lake-repair` exception, and the light-touch twins), and Phase 6 runs the cross-file
acceptance audit that twin-file discipline requires. No code compiles here — all nine files are
markdown — so every phase is `prose` tier except the final audit.

### Research Integration

The research report confirmed all eight contract files at their cited line numbers with zero
drift, and settled four open decisions that this plan adopts as binding:

1. **Scoped builds are in scope.** The measured single-module time already exceeds the foreground
   cap, and `lake-build-guard.sh` locks at whole-project granularity regardless of whether the
   invocation is scoped. "Scoped = safe" is therefore false and must be removed from the contract
   framing extension-wide. The cost — phase-end scoped builds from concurrent sessions on the same
   package now serialize project-wide — is recorded as a deliberate tradeoff in the anchor.
2. **`skill-lake-repair` takes Option (c).** Its two command-substitution sites are incompatible
   with detachment but fully compatible with the guard (which returns stdout and exit code through
   `$(...)`). Route both through the guard, keep them synchronous, carve them out of the
   *detachment* mandate only, and document the residual cap exposure inline.
3. **Explicit `--timeout 1800`.** The guard's default lock-wait timeout is 600s — the same value as
   the foreground cap being replaced — so a second session waiting on a legitimately long first
   build would itself time out at exit 75. Every contract site passes an explicit larger value.
4. **Anchor length ~90-130 lines**, not the task's stale "~40" estimate; the sibling anchor is
   ~121 lines for a narrower topic.

The report also surfaced two residual gaps that this plan documents rather than fixes:
`mcp__lean-lsp__lean_build` is a second, MCP-based build path that `run_in_background` cannot
wrap and that is outside the deliverable list, and the harness's completion notification — not
the passive progress checks — remains the actual termination signal a dispatch must wait on
before writing final metadata.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` was read. This task does not map onto a currently listed roadmap item; it is
closest in spirit to the "Agent System Quality" cluster (contract correctness across engine
twins) but no existing checkbox covers build-invocation contracts. No roadmap edit is planned or
permitted here.

## Goals & Non-Goals

**Goals**:
- Create one canonical anchor, `long-builds.md`, that owns all prose about the foreground cap, the
  per-module-caching livelock, the detachment mandate, the guard mandate, and the passive progress
  checks.
- Make detached-plus-guarded invocation mandatory at all eight instruction sites, with the
  strongest available lever (a new MUST NOT item) in both implementation-agent twins.
- Standardize one invocation shape across every site so the contract cannot be satisfied two
  different ways.
- Remove the "scoped builds are exempt" framing wherever it appears.
- Record the `skill-lake-repair` carve-out as a deliberate, reasoned decision rather than an
  oversight.

**Non-Goals**:
- Editing anything under `agent-system/extensions/lean/scripts/**`, `lean/manifest.json`, or
  `operations/multi-instance-optimization.md` — a concurrent task owns those.
- Editing `scripts/lean-sorry-census.sh`, which carries the same command-substitution shape but is
  owned by the lean-integration task.
- Editing `opencode-agents.json` — verified to contain zero `lake build` occurrences.
- Wrapping or otherwise fixing `mcp__lean-lsp__lean_build`; it is documented as a known gap.
- Any write under `.claude/**`; that tree is a disposable deploy artifact.
- Any new machinery. This task is contract text over an already-delivered mechanism.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Twin-file drift: the new MUST NOT item lands in the base agent but not the `-hard` twin (a known recurring defect class in this extension; the twins are not line-symmetric) | H | M | Phase 2 edits both files in one phase, located by content; Phase 6 greps both MUST NOT lists for the prohibition and fails the phase if only one carries it |
| Guard is mandated but `.claude/scripts/lake-build-guard.sh` is not yet deployed in this repo (source store has it; deploy happens on reload) | M | H | Contract text cites the deploy path, matching the existing `lean-sorry-census.sh` citation convention; Phase 6 verifies the source-store script exists and that the cited path matches the flat deploy directory shape |
| Anchor prose gets duplicated at call sites, violating the extension's single-anchor convention | M | M | Phase 6 checks that no contract file restates the cap value, the caching mechanism, or the four progress checks — only the anchor may |
| `--timeout` default (600s) silently relied on at some site, reintroducing a livelock one layer up | H | M | One canonical invocation string fixed in Phase 1 and copied verbatim; Phase 6 greps every guard invocation for an explicit `--timeout` |
| The `skill-lake-repair` carve-out is later read as "this file was missed" | M | M | Inline note at Step 4 recording the decision and its reason, plus a matching caveat in the anchor |
| New anchor is not registered in `index-entries.json` (outside file_scope), reducing discoverability | M | H | Wire the anchor into the implementation agents' `## Context References` blocks (in scope) as the primary discovery path; record the index entry as a recommended follow-up |
| Task-number references leak into deliverable files outside `specs/**` | H | L | Phase 6 runs the repo's task-reference check over all nine touched files |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel. Phases 2-5 touch disjoint file sets, so they
carry no write conflicts with each other.

---

### Phase 1: Create the `long-builds.md` anchor [COMPLETED]

**Goal**: Establish the single canonical file that owns every piece of prose the other eight files
will point at, and fix the one canonical invocation string those files must copy verbatim.

**Tasks**:
- [x] Read `agent-system/extensions/lean/context/project/lean4/operations/multi-instance-optimization.md`
      in full to match its heading structure and prose-and-table register (this is the sibling
      anchor; do not edit it).
- [x] Create `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` with
      these sections, in order:
  - [x] **Overview** — one paragraph: long Lean builds livelock under a foreground Bash call, and
        the fix is two obligations that must land together.
  - [x] **The foreground cap** — the Bash tool kills a plain foreground call at its hard cap
        (10 minutes / 600000ms max explicit timeout; 120000ms default).
  - [x] **Why this is a livelock, not a slowdown** — Lean caches compilation per module; a
        cap-killed build writes no `.olean` for the module it was working on, so no progress is
        cached and the next attempt restarts at the identical module.
  - [x] **The normative statement** — state it generically: "any single module may exceed the
        foreground cap." Include the ~11-minute measurement only as an explicitly labelled
        illustrative footnote from one large repo. MUST NOT be written as an assumption the
        contract depends on; the source store deploys to roughly ten repositories.
  - [x] **The trigger is ordinary** — Lean hashes whole files, so a comment- or docstring-only edit
        to an upstream module invalidates every downstream `.olean` and re-arms the trap. Any
        docstring pass can trigger this; it is not an exotic failure.
  - [x] **Obligation 1: detach** — `Bash(run_in_background: true)` runs detached, survives across
        turns, and re-invokes the agent on completion.
  - [x] **Obligation 2: route through the guard** — and *why the two must land together*: the
        foreground cap is currently the only thing bounding how long a redundant concurrent build
        survives. Uncapping without serializing makes memory pressure strictly worse (measured on
        one large repo: ~10 simultaneous builds re-elaborating the same modules, 16 `lean`
        processes at 29.9 GB RSS on a 30 GB machine with swap in use). Adopting one half of this
        pair is a regression.
  - [x] **The canonical invocation** — fix one string that every contract site copies verbatim:
        `bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- <lake args>`, run under
        `Bash(run_in_background: true)`. Explain that `--timeout` is the guard's *lock-wait*
        budget, not a build-duration limit, that its default is 600s (the same value as the cap
        being replaced), and that an explicit larger value is required so a second waiting session
        does not itself time out at exit 75.
  - [x] **Scoped builds are covered too** — record the decision and its cost: a single module can
        already exceed the cap on its own, and the guard's lock is project-granular regardless of
        scope, so scoped builds get no exemption. The named tradeoff: phase-end scoped builds from
        concurrent sessions on the same package now serialize project-wide where they could
        previously run in parallel against different modules. This is the deliberate price of
        closing the memory-pressure gap, not a hidden regression. Scoped remains preferred for
        doing less work, never for being categorically safe.
  - [x] **Passive progress checks** (four, each with the command shape and what it proves):
        fresh `.olean` mtime frontier under `.lake/build/`; the live `lean` PID's
        `/proc/PID/cmdline` (which module is being elaborated); accumulated CPU time via
        `ps -o times=` or `/proc/PID/stat` fields 14/15 (the tiebreaker when the `.olean` list
        looks frozen inside one long module); `VmRSS` trend from `/proc/PID/status` (progress
        signal and OOM early-warning).
  - [x] **The liveness caveat** — state explicitly that these four prove *liveness*, never
        *termination*: a process burning CPU with growing RSS can still be stuck in a divergent
        tactic search. They are for interim observability, not a substitute for the harness's
        completion notification.
  - [x] **Completion discipline** — detach the build, but the dispatch is not complete and final
        metadata MUST NOT be written until the harness's completion notification for that job has
        arrived. Fire-and-forget is prohibited (see the wrap-up contract's teardown rule).
  - [x] **Known gaps** — `mcp__lean-lsp__lean_build` is a second build path invoked as an MCP tool
        rather than a Bash command; `run_in_background` cannot wrap it and its own timeout behavior
        is outside this anchor's visibility. It is deliberately not covered by this mandate.
        `skill-lake-repair`'s repair loop is carved out of the detachment obligation only (see that
        file for the reason) and retains residual cap exposure.
  - [x] **Cross-reference** — a short paragraph pointing to
        `operations/multi-instance-optimization.md` for concurrent-session setup, stating the
        detachment-amplifies-concurrency interaction here (this file owns it) without duplicating
        that anchor's content.
- [x] Verify no task-number reference appears anywhere in the new file.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: the anchor is expected to land at roughly 90-130 lines. The task
description's "~40 lines" is a stale estimate; the sibling anchor is ~121 lines for a narrower
topic. Confirm at implementation time by `wc -l` on the finished file — if it lands under ~80
lines, re-check the section checklist above for a dropped section rather than accepting the
shorter file.

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` - new file, all
  content above

**Verification**:
- File exists at the stated path.
- Every section in the checklist above is present as a heading or labelled paragraph.
- The generic normative sentence "any single module may exceed the foreground cap" appears; the
  ~11-minute figure appears only inside an explicitly illustrative note.
- The canonical invocation string appears exactly once, with `--timeout 1800`.
- All four passive checks and the liveness-not-termination caveat are present.
- `grep -n "task [0-9]" long-builds.md` returns nothing.

---

### Phase 2: Implementation-agent twins [COMPLETED]

**Goal**: Land the substantive mandate — including the new MUST NOT item — in both implementation
agents, edited together in one phase, located by content.

**Tasks**:
- [x] `agents/lean-implementation-agent.md`:
  - [x] Add the anchor to the `## Context References` block (around L15-20) as
        `` `@.claude/context/project/lean4/operations/long-builds.md` `` with a one-line summary,
        matching the block's existing entry style.
  - [x] Verification Steps step 4 (near L165): replace the bare ```` ```bash / lake build 2>&1 ````
        fence with the canonical guarded invocation, and add one line stating it is run via
        `Bash(run_in_background: true)` with a pointer to the anchor.
  - [x] MUST DO item 7 (near L423): revise so scoped is preferred for doing *less work*, not for
        being safe. Drop the implication that `(scoped, faster)` exempts it; require the same
        guarded, detached invocation.
  - [x] MUST DO item 8 (near L424): append "Run it via `Bash(run_in_background: true)` through the
        build guard, never as a plain foreground call — see
        `context/project/lean4/operations/long-builds.md`."
  - [x] MUST NOT item 3 (near L436): remove the scoped-build exemption clause. Final full `lake
        build` remains mandatory; scoped no longer reads as a category exempt from the mandate.
  - [x] Add a NEW MUST NOT item, verbatim in intent: "**Run a `lake build` as a plain foreground
        Bash call.** The foreground cap kills it mid-module; a killed build caches no `.olean`, so
        retries restart at the same module and livelock indefinitely. Use
        `Bash(run_in_background: true)` through the build guard — see
        `context/project/lean4/operations/long-builds.md`." Placing this in MUST NOT is deliberate
        and MUST NOT be softened into advisory prose elsewhere in the file.
- [x] `agents/lean-implementation-hard-agent.md` (twin — locate every site by content, never by
      mirroring a line number from the base file):
  - [x] Add the same anchor entry to its `## Context References` block.
  - [x] Stage 4.D scoped build (near L221-224): replace `lake build ModuleName 2>&1` with the
        canonical guarded invocation and revise the "(faster)" comment per the scoped decision.
  - [x] Stage 6 verification fence (near L371-375): same replacement as the base agent's step 4.
  - [x] MUST DO item 7 (near L515, note this is item 7 here, not 8): same append as the base
        agent's item 8.
  - [x] Add the equivalent new MUST NOT item to its MUST NOT list (near L520-533, currently 12
        items with no equivalent), positioned near the existing build-related items.
  - [x] The prose at ~L356 describing the sorry-census `--cross-check` running "its own `lake
        build`" may gain at most a note that that script is not covered by this mandate. Do not
        edit the script.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: exactly two files and six edit sites in the base agent, six in the twin, as
enumerated. Confirm at implementation time with `grep -n "lake build"` over both files — every
remaining occurrence must either carry the guarded/detached form or be explicitly annotated as
out of scope (the census prose). An unaccounted occurrence means a site was missed.

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - anchor reference, step-4
  fence, MUST DO 7 and 8, MUST NOT 3, new MUST NOT item
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - anchor reference,
  Stage 4.D fence, Stage 6 fence, MUST DO 7, new MUST NOT item

**Verification**:
- Both files carry a MUST NOT item prohibiting a foreground `lake build`; the prohibitions are
  equivalent in content though not necessarily identical in wording.
- Both `## Context References` blocks name the anchor.
- No remaining `lake build` fence in either file lacks the guard wrapper.
- Every guarded invocation in both files passes an explicit `--timeout`.
- No file restates the anchor's cap value, caching mechanism, or progress checks.

---

### Phase 3: `rules/lean4.md` build-command block [COMPLETED]

**Goal**: Rewrite the build-command reference so it no longer presents scoped-vs-full as purely a
speed tradeoff, and point at the anchor.

**Tasks**:
- [x] Workflow Pattern items 4-5 (near L44-45): revise so both the phase-end scoped build and the
      final full build are shown in the canonical guarded, detached form.
- [x] Build Commands section (near L56-62): revise the "Prefer scoped / Full project / Clean" line
      and the "When to use each" bullets so scoped is framed as *less work*, not as *safe*. Add the
      canonical invocation shape once and a pointer to
      `context/project/lean4/operations/long-builds.md`.
- [x] Add a short pointer line (not a restatement) noting that a plain foreground `lake build` can
      livelock and that the anchor is authoritative.

**Timing**: 25 minutes

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/lean/rules/lean4.md` - Workflow Pattern items 4-5, Build Commands block

**Verification**:
- No line in the file frames scoped builds as exempt from the cap or the guard.
- The anchor path appears at least once.
- Any invocation example shown uses the canonical guarded form with an explicit `--timeout`.
- The file does not duplicate the anchor's explanatory prose.

---

### Phase 4: `skill-lake-repair` guard routing and carve-out [COMPLETED]

**Goal**: Resolve the architectural exception — route both command-substitution sites through the
guard while explicitly carving the loop out of the detachment mandate, with the reason recorded
inline.

**Tasks**:
- [x] Step 4 "Run Build" (near L68-72): rewrite both command-substitution sites to call through the
      guard, keeping them synchronous:
      `build_output=$(bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- "$module" 2>&1)`
      and the unscoped twin
      `build_output=$(bash .claude/scripts/lake-build-guard.sh build --timeout 1800 2>&1)`.
      Preserve the surrounding `if`/`build_exit_code=$?` structure.
- [x] Add a short inline note at the top of Step 4 recording the decision explicitly: command
      substitution is incompatible with `run_in_background` (which returns no stdout to a shell
      variable), so this loop is carved out of the *detachment* mandate only; it still adopts the
      guard, gaining serialization and memory bounding. State the residual exposure: a heavy
      first-time build in this loop can still be killed at the foreground cap, but unlike a
      detached agent build the failure is not silent — it surfaces as a failed command substitution
      the loop's existing error handling already covers. Point at
      `context/project/lean4/operations/long-builds.md`.
- [x] Confirm no other `lake build` invocation remains unguarded in the file.

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/lean/skills/skill-lake-repair/SKILL.md` - Step 4 build block and its
  new decision note

**Verification**:
- Both build sites call the guard; neither uses `run_in_background`.
- The `build_exit_code=$?` capture still follows the substitution and is not broken by the rewrite.
- The inline note states the carve-out, its reason, and the residual cap exposure.
- The note's content matches the anchor's "Known gaps" paragraph without contradicting it.

---

### Phase 5: Light-touch twins — research agents and implementation skills [COMPLETED]

**Goal**: Point the four remaining files at the anchor without rewriting them; these sites describe
behavior rather than instructing invocation, so they need pointers, not mandate text.

**Tasks**:
- [x] `agents/lean-research-agent.md`:
  - [x] L52 Build Tools bullet: append that builds run detached through the guard, with the anchor
        path.
  - [x] L183 APOLLO decomposition step 4 ("verify with `lake build`"): append the same pointer.
- [x] `agents/lean-research-hard-agent.md`:
  - [x] L59 Build Tools bullet: same append as the base research agent's L52 (located by content).
- [x] `skills/skill-lean-implementation/SKILL.md`:
  - [x] L108: append "(detached, via the build guard — see
        `context/project/lean4/operations/long-builds.md`)".
  - [x] L302 MUST NOT Postflight Boundary item 2: leave the prohibition intact; it already forbids
        the skill from running builds. Add at most a parenthetical noting the agent's build is
        detached and guarded.
- [x] `skills/skill-lean-implementation-hard/SKILL.md`:
  - [x] L223 and L444: same treatment as the base skill's L108 and L302, located by content.
- [x] Confirm the `lean_diagnostic_messages` fallback rows (research agents L33/L46) that mention
      "`lake build` via Bash" either carry the pointer or are left alone deliberately — record
      which.

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: four files, seven touch points as enumerated. Confirm at implementation time
by `grep -n "lake build"` across all four; any occurrence not in the enumerated list must be
consciously accepted or added, not silently skipped.

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-research-agent.md` - L52, L183
- `agent-system/extensions/lean/agents/lean-research-hard-agent.md` - L59
- `agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md` - L108, L302
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` - L223, L444

**Verification**:
- Each of the four files names the anchor at least once.
- No file in this phase gained mandate prose or a restatement of the anchor's explanation.
- Both skill files' MUST NOT postflight-boundary items remain intact and still forbid the skill
  from running builds itself.

---

### Phase 6: Acceptance audit and twin-symmetry verification [NOT STARTED]

**Goal**: Verify the whole pass against the task's acceptance criteria as one artifact, catching
the failure modes (twin drift, prose duplication, missing `--timeout`, scope violations) that only
a cross-file view can see.

**Tasks**:
- [ ] Confirm all nine files were touched and no others:
      `git status --porcelain agent-system/extensions/lean/` matches exactly the file_scope list.
- [ ] Confirm zero writes under `.claude/**`: `git status --porcelain .claude/` is empty.
- [ ] Confirm no out-of-scope file was edited: `scripts/**`, `manifest.json`,
      `multi-instance-optimization.md`, `index-entries.json`, and `opencode-agents.json` are all
      unmodified.
- [ ] Twin-symmetry check by content: both implementation agents carry an equivalent foreground-
      build MUST NOT item; both research agents carry an equivalent Build Tools pointer; both
      implementation skills carry equivalent pointers. Compare by meaning, not by diff shape.
- [ ] Guard-invocation audit: every `lake-build-guard.sh` invocation across all touched files
      passes an explicit `--timeout`; none relies on the 600s default.
- [ ] Anchor-uniqueness audit: no contract file restates the cap value, the per-module caching
      explanation, or the four passive progress checks. Only `long-builds.md` may.
- [ ] Residual-`lake build` audit: `grep -rn "lake build" agent-system/extensions/lean/` — every
      remaining bare occurrence is either inside the anchor's own prose, an explicitly noted
      out-of-scope path (the census script prose, the `lean_build` MCP tool lines), or a
      historical/illustrative mention. Enumerate each and record why it is acceptable.
- [ ] Task-reference check over all nine files (per the no-task-references-in-deliverables rule);
      expect zero hits.
- [ ] Confirm `agent-system/extensions/core/scripts/lake-build-guard.sh` exists and that the deploy
      path cited in the contracts (`.claude/scripts/lake-build-guard.sh`) matches the flat deploy
      directory convention already used by `lean-sorry-census.sh`.
- [ ] Record, in the implementation summary, the two decisions that must survive as decisions: the
      scoped-build inclusion with its serialization cost, and the `skill-lake-repair` Option (c)
      carve-out.
- [ ] Record as a recommended follow-up (do not implement): add an `index-entries.json` entry for
      `long-builds.md`, and add a reciprocal pointer from `multi-instance-optimization.md` back to
      the new anchor when the owning task next rewrites it.

**Timing**: 30 minutes

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Verification**:
- Every checklist item above passes, or the phase does not close.
- The task's acceptance list is walked item by item with a recorded pass/fail per item.

---

## Testing & Validation

- [ ] `long-builds.md` exists with the cap, the per-module-caching livelock explanation, the
      detachment mandate, the guard mandate, and the four passive progress checks with the
      liveness-not-termination caveat.
- [ ] Every instruction site points at the anchor rather than restating its prose.
- [ ] `lean-implementation-agent.md` carries the new MUST NOT item, verbatim in intent.
- [ ] `lean-implementation-hard-agent.md` carries the equivalent item, located by content.
- [ ] The `skill-lake-repair` command-substitution incompatibility is resolved via guard routing
      with the detachment carve-out and its reason recorded inline.
- [ ] The scoped-build decision is recorded explicitly, with its serialization cost named.
- [ ] Normative text says "any single module may exceed the foreground cap"; the ~11-minute figure
      appears only as an illustrative note.
- [ ] No `.claude/**` file is modified.
- [ ] No task numbers appear in any edited file.
- [ ] Every guard invocation passes an explicit `--timeout`.

## Artifacts & Outputs

- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` (new, ~90-130
  lines)
- Eight edited contract files under `agent-system/extensions/lean/` (four agents, three skills,
  one rules file)
- Implementation summary recording the two binding decisions (scoped-build inclusion,
  `skill-lake-repair` Option (c)) and the two recommended follow-ups (`index-entries.json` entry,
  reciprocal cross-reference from the sibling anchor)

## Rollback/Contingency

All nine files are markdown in a git-tracked source store with no build or runtime surface, so
rollback is `git checkout -- agent-system/extensions/lean/` (or a per-file revert). Phases 2-5 are
independent of each other, so a single failing phase can be reverted without disturbing the
others; only Phase 1's anchor is a shared dependency, and reverting it would require reverting the
pointers added by Phases 2-5. If the guard script's deploy path turns out to differ from
`.claude/scripts/lake-build-guard.sh` at reload time, the fix is a single path correction across
the touched files — no structural rework.
