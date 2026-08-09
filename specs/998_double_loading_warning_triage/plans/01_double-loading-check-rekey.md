# Implementation Plan: Double-Loading Check Triage and Re-Keying

- **Task**: 998 - Triage the 49 Double-Loading context-index warnings
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: 991 (satisfied -- the restatement work that produced the warning)
- **Research Inputs**: specs/998_double_loading_warning_triage/reports/01_double_loading_warning_triage.md
- **Artifacts**: plans/01_double-loading-check-rekey.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The Double-Loading Check in `validate-context-budgets.sh` currently flags any index entry carrying
both a `load_when.agents` hook and a `load_when.commands` hook, reports 49 matches as a
non-exit-code-affecting WARNING, and has sat untriaged since it was restated on `load_when` shape.
This plan replaces the shape-only predicate with a mechanically derived *redundancy* predicate
(an entry is redundant only when every command in `commands[]` routes to an agent already listed in
that entry's own `agents[]`), narrows the entries that predicate identifies as redundant, and
promotes the redundant bucket from a warning to an exit-code-contributing violation. The
legitimately dual-addressed shape is exempted by construction of the predicate -- re-derived from
deployed artifacts on every run -- rather than by an allowlist file or a frozen count in a comment.
Done means: the deployed check reports 0 redundant entries, contributes to the exit code, and a
committed regression test proves it still fires on a fixture containing a genuinely over-broad
dual-hooked entry.

### Research Integration

The research report supplies four inputs this plan builds on directly:

1. **No live runtime consumer.** Every reader of `load_when` is a validator, linter, or the
   extension installer; no `SKILL.md` queries `load_when` to assemble a subagent's context (that
   comes from each agent's own hand-authored Context References list). The check therefore catches
   *structural index redundancy*, not an observed duplicate-read bug. This scopes the fix
   conservatively: narrowing `commands[]` on a redundant entry cannot change any agent's live
   context, because nothing reads it at dispatch time.
2. **The criterion.** An entry with non-empty `agents[]` and non-empty `commands[]` is REDUNDANT
   iff every `c` in `commands[]` is agent-routed to an agent already in `agents[]`. Any
   direct-execution command, or `/orchestrate` (whose reach is the union of research + plan +
   implement agents), makes the entry legitimately dual.
3. **The classification.** 36 redundant (all in `agent-system/extensions/core/index-entries.json`),
   13 legitimately dual (11 core, 2 memory). The report's per-entry table is the expected outcome
   this plan re-derives mechanically rather than transcribes.
4. **The derivation design.** Route the six agent-routed core commands live from the deployed
   `manifest.json` `routing_agents` block (`/research`, `/plan`, `/implement`) and the sole
   `subagent_type:` line in each of `skill-meta`, `skill-spawn`, `skill-reviser` (`/meta`,
   `/spawn`, `/revise`) -- never a second hardcoded copy of agent names.

**One correction this plan makes to the report's design.** The report's predicate treats any
command absent from the six-command route table as "direct", which silently folds *extension*
commands (`/grant`, `/epi`, `/deck`, `/convert`, `/literature`, ...) into the exempt bucket. Those
commands are frequently agent-routed in fact -- `/grant` reaches `grant-agent`, and entries hooking
both are structurally the same redundancy shape -- but no manifest maps an extension *command name*
to an agent (extension `routing`/`routing_agents` blocks are keyed by task type, not command), so
the route is not mechanically derivable today. Silently classifying them as exempt would recreate
this task's own failure mode one layer over: a shape the check has quietly stopped seeing. This
plan therefore requires a **third, explicitly named bucket** -- `unclassifiable-command` -- reported
by count and by path, so the check's coverage boundary is visible in its own output rather than
buried in a comment. It is informational (not exit-code-affecting), because under-detection is the
safe direction and no evidence-backed route exists to promote it on.

**Deployment-scope fact discovered while planning** (not in the report, and load-bearing for the
promotion decision): the 49 is a property of *this repository's currently loaded extension set*
(core + memory + email + nix + nvim + literature). Other extensions in the source store carry
their own dual-hook entries -- present 36, founder 25, epidemiology 15, slidev 15, filetypes 10,
literature 6 -- which would enter the merged index if loaded. Every sampled one of those pairs an
extension command with an extension agent, so under the new predicate they land in the
`unclassifiable-command` bucket, not the violation bucket. Promoting the redundant bucket to a
violation is therefore safe for repos with other extensions loaded. Phase 4 measures this rather
than assuming it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no ROADMAP.md was consulted.

## Goals & Non-Goals

**Goals**:
- Encode the redundancy criterion mechanically inside `validate-context-budgets.sh`, deriving every
  agent name live from deployed artifacts.
- Narrow the entries the predicate identifies as redundant by dropping their `commands[]` hook,
  keeping `agents[]`.
- Promote the redundant bucket from WARNING to a VIOLATIONS-contributing check.
- Keep the legitimately dual-addressed shape exempt *by construction of the predicate*, with no
  allowlist file and no hardcoded count.
- Make the predicate's coverage boundary visible via a named `unclassifiable-command` bucket.
- Commit a regression test that proves the check still fires (positive fixture) and still
  discriminates (negative fixture).

**Non-Goals**:
- Widening `agents[]` arrays to cover hard-mode agents or to match agents' own Context References
  lists. The report flags both as pre-existing *coverage* gaps; they are not double-loading and are
  out of scope.
- Wiring `validate-context-budgets.sh` into `verify-deploy.sh`. The report notes this is an
  unscheduled follow-up; this plan changes only the check's internal severity.
- Editing non-loaded extensions' `index-entries.json` files. Phase 4 measures their behavior under
  the new predicate and records the finding; it does not mass-edit them.
- Introducing a new `index.schema.json` field or an exemption allowlist file.
- Deleting the check, or leaving it frozen at warning with no exemption mechanism (both explicitly
  forbidden by the task).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Source-store copy of the script cannot be executed for testing -- `deploy-root-guard.sh` hard-exits when `SCRIPT_DIR`'s parent is not `.claude`/`.opencode` | H | H (confirmed at plan time, not a hypothesis) | All verification runs invoke the **deployed** `.claude/scripts/validate-context-budgets.sh`. Deploy (Phase 4) is a hard prerequisite of every test phase; the dependency graph encodes this. Prototyping in Phase 1 uses a standalone scratch script, never the guarded source copy. |
| Editing `.claude/**` directly instead of the source store -- the edit appears to succeed and is wiped on next regeneration | H | M | Binding source-store rule: every edit targets `agent-system/extensions/**`. `.claude/**` changes arrive only via `bash .claude/scripts/deploy-headless.sh`. Phase 4 verifies the deployed copy matches the source by diff, not by assumption. |
| Route derivation silently yields empty (manifest moved, `subagent_type:` line reworded) and every entry becomes "unclassifiable", neutering the check without any output change | H | M | Phase 2 requires an explicit precondition assertion: if any of the six routes resolves empty, the check prints a loud named `[DEGRADED ROUTE DERIVATION]` line and counts a warning, rather than proceeding with a silently-empty table. Phase 5's test suite includes a case that stubs a missing manifest and asserts the degraded banner appears. |
| The 36/13 split does not reproduce mechanically (report's hand classification diverges from the coded predicate) | M | M | Phase 1 exists solely to reproduce the partition *before* any file is edited. A divergence is a finding to reconcile in Phase 1, not a surprise discovered after 36 entries have been rewritten. |
| Promoting to a violation breaks runs in repos with other extension sets loaded | M | L | Phase 4 measures every extension's `index-entries.json` against the predicate and records per-extension bucket counts. Sampling at plan time indicates all land in `unclassifiable-command`, but the phase confirms rather than assumes. |
| Hand-editing 36 JSON entries introduces a typo or drops an unrelated key | M | M | Phase 3 applies one `jq` transformation driven by the predicate itself, then verifies with a structural diff that the only key removed anywhere is `load_when.commands` and that entry count and all other fields are byte-identical. |
| Task-number citations leak into deliverables under `agent-system/extensions/**` | M | M | The write-time `validate-no-task-references.sh` PreToolUse gate blocks such writes; Phase 6 additionally runs `check-task-references.sh` over the changed trees. All provenance references use durable anchors (script name, section heading), never a task number. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint files
(`scripts/validate-context-budgets.sh` vs `index-entries.json`) and are territory-safe to run
concurrently.

---

### Phase 1: Reproduce the partition mechanically before editing anything [COMPLETED]

**Goal**: Prove the coded predicate reproduces the report's classification against the live
deployed index, and surface any divergence *before* a single source file is edited.

**Tasks**:
- [x] Capture the baseline: run `bash .claude/scripts/validate-context-budgets.sh --verbose`, save
      full output (including the current dual-hook count and the verbose entry listing) to the
      scratch directory as the before-state. *(completed: 49 dual-hook entries at baseline, WARNING branch, 8 violations/1 warning overall)*
- [x] Write a standalone scratch classifier (scratch directory only -- not a deliverable, not under
      `agent-system/**`) that derives the six-command route table from
      `.claude/extensions/core/manifest.json` (`routing_agents.{research,plan,implement}.{general,meta,markdown}`,
      uniqued) and the sole `subagent_type:` line in each of `.claude/skills/skill-meta/SKILL.md`,
      `.claude/skills/skill-spawn/SKILL.md`, `.claude/skills/skill-reviser/SKILL.md`. *(completed)*
- [x] Print the derived route table and eyeball it against CLAUDE.md's Skill-to-Agent Mapping.
      *(completed: /research->general-research-agent, /plan->planner-agent, /implement->general-implementation-agent, /meta->meta-builder-agent, /spawn->spawn-agent, /revise->reviser-agent -- matches CLAUDE.md)*
- [x] Apply the three-way partition to `.claude/context/index.json`: `redundant` (every command
      agent-routed and its route contained in `agents[]`), `unclassifiable-command` (at least one
      command not in the route table and not a known direct command), `legitimate-dual` (remainder).
      *(completed)*
- [x] Emit each bucket as a sorted path list; confirm the three counts sum to the baseline dual-hook
      total. *(completed: 36 + 13 + 0 = 49)*
- [x] Diff the `redundant` path list against the research report's 36-row table and the
      `legitimate-dual` list against its 13-row table. Record any divergence and reconcile it
      (report error vs. predicate error) before proceeding. *(completed: initial classifier had a jq
      bug -- `X | index(.)` rebinds `.` to the piped array, a known jq footgun -- that silently
      produced 0/49 instead of 36/13; fixed with an explicit `any(. == $c)` membership test, after
      which both path sets are byte-identical to the report's tables, zero divergence)*
- [x] Attribute every `redundant` path to its owning source `index-entries.json` by looking each up
      against every `agent-system/extensions/*/index-entries.json` `.entries[].path`; confirm the
      set of owning files. *(completed: all 36 owned exclusively by agent-system/extensions/core/index-entries.json, 0 in any other extension)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The report asserts 36 redundant / 13 legitimate / 49 total, all redundant
entries owned by `agent-system/extensions/core/index-entries.json`. Under this plan's three-bucket
predicate the expected split is 36 redundant / 13 legitimate / 0 unclassifiable for the *currently
deployed* extension set. Confirm by running the scratch classifier and comparing its emitted path
lists against the report's tables; a non-zero `unclassifiable-command` count or any set difference
is a finding to reconcile in this phase, not a number to overwrite.

**Files to modify**:
- None. This phase writes only to the scratch directory.

**Verification**:
- The three bucket counts sum exactly to the baseline dual-hook count from the saved before-state.
- Each of the six derived routes is a non-empty, existing agent name.
- Set difference between the `redundant` list and the report's 36 rows is empty, or every
  difference is explained in writing.

---

### Phase 2: Re-key the Double-Loading Check in the source script [COMPLETED]

**Goal**: Replace the shape-only predicate with the three-bucket mechanical predicate, promote the
redundant bucket to a violation, and make degraded route derivation loud.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/validate-context-budgets.sh`, replace the
      `--- Double-Loading Check ---` section (its `double_loaded` computation, WARNING branch, and
      the preceding comment block explaining the deliberate warning downgrade). *(completed)*
- [x] Add the route derivation, lifted from the Phase 1 scratch classifier: read
      `routing_agents.{research,plan,implement}` from `${REPO_ROOT}/.claude/extensions/core/manifest.json`
      and the sole `subagent_type:` line from each of the three singleton skills. Never hardcode an
      agent name as a literal. *(completed: `_dlc_route_agents`/`_dlc_subagent_type` helpers, plus
      env-var overrides for test stubbing, e.g. `VALIDATE_BUDGETS_MANIFEST_OVERRIDE`)*
- [x] Add the precondition assertion: if any of the six routes resolves empty (missing file,
      changed key, reworded line), print a loud named `[DEGRADED ROUTE DERIVATION]` line naming which
      route(s) failed, increment `WARNINGS`, and treat the affected command(s) as unclassifiable --
      never as "direct" and never as a silent no-op. *(completed)*
- [x] Define the direct-command roster as a literal list (`/review`, `/errors`, `/task`, `/todo`,
      `/refresh`, `/fix-it`, `/learn`, `/distill`, `/literature`, `/project-overview`, `/tag`,
      `/merge`, `/cite`) plus `/orchestrate` handled as its own never-subsuming case, with a comment
      explaining why `/orchestrate` can never make an entry redundant (union reach across three
      skills' agent resolution). *(completed)*
- [x] Implement the three-bucket partition and its reporting:
      - `redundant` -> add to `VIOLATIONS`, list every offending path **unconditionally** (not gated
        on `--verbose`, so the failure is actionable from a bare run).
      - `legitimate-dual` -> informational line only; never touches `WARNINGS` or `VIOLATIONS`.
      - `unclassifiable-command` -> informational line naming the count and, under `--verbose`, the
        paths and the specific unrecognized command tokens.
      *(completed)*
- [x] Rewrite the section's comment block: state the criterion, state that the exemption is the
      predicate's own false result (no allowlist), and state the coverage boundary (extension
      command names are not mechanically routable today, hence the third bucket). Reference durable
      anchors -- script names, manifest keys, section headings -- never a task number. *(completed)*
- [x] Confirm the `WARNINGS` / `EXCEPTIONS_APPLIED` separation comment at the top of the script is
      still accurate now that this check no longer produces a routine warning; update it if its
      stated rationale has gone stale. *(completed: updated to describe the current WARNINGS
      sources -- OK* budget exceptions, degraded route derivation -- and points to the
      Double-Loading Check section for the current criterion)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-context-budgets.sh` - replace the Double-Loading
  Check section, add route derivation and the degraded-derivation guard.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/validate-context-budgets.sh` parses clean.
- `shellcheck` (if available) reports no new findings against the changed section.
- No literal agent name (`general-research-agent`, `planner-agent`, `general-implementation-agent`,
  `meta-builder-agent`, `spawn-agent`, `reviser-agent`) appears in the new code outside comments --
  verified by grep over the changed section.
- The script is NOT executed from the source store (blocked by `deploy-root-guard.sh`); behavioral
  verification happens in Phase 4.

---

### Phase 3: Narrow the redundant entries in the core index [COMPLETED]

**Goal**: Drop `load_when.commands` on exactly the entries Phase 1 classified as redundant, keeping
`load_when.agents` and every other field untouched.

**Tasks**:
- [x] Take the Phase 1 `redundant` path list as input (do not re-type it from the report).
      *(completed: consumed from the Phase 1 scratch classifier's saved partition JSON)*
- [x] Apply a single `jq` transformation to `agent-system/extensions/core/index-entries.json`
      setting `load_when.commands` to `[]` for exactly the paths in that list, writing to a temp file
      and moving into place only after `jq empty` validates the result. *(completed)*
- [x] Verify the transformation is surgical: compare before/after with a structural diff confirming
      (a) `.entries | length` is unchanged, (b) the only differing key anywhere is
      `load_when.commands`, and (c) it differs on exactly the redundant-list paths and no others.
      *(completed: 136 entries before and after; 36 changed entries, every one's only differing
      top-level key is `load_when` and only differing load_when sub-key is `commands`; the
      changed-to-`[]` path set is byte-identical to the redundant-list set)*
- [x] Re-run the Phase 1 scratch classifier against a locally merged preview of the index (or
      directly against the modified `index-entries.json`) and confirm the redundant count for core
      is now 0 and the legitimate-dual set is unchanged. *(completed: dual-hook count in
      index-entries.json dropped from 47 to 11, matching the plan's own prediction; full
      cross-index re-classification against the merged deployed index.json happens in Phase 4
      after deploy)*
- [x] Confirm `agent-system/extensions/memory/index-entries.json` is NOT modified -- both of its
      dual-hook entries are legitimate. *(completed: `git diff --stat` shows no change to that file)*
- [x] Confirm no `line_count`, `keywords`, `topics`, `summary`, or ordering changed. *(completed:
      entry order preserved path-for-path; `generate-context-line-counts.sh --check` reports
      467/467 exact match across all extensions, 0 mismatch)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 36 entries in `agent-system/extensions/core/index-entries.json` are expected
to change, and no entry in any other extension's `index-entries.json`. The file currently holds 47
dual-hook entries, of which 11 are expected to remain dual after this phase. Confirm by counting
changed entries in the structural diff and by re-running the classifier; if the count differs from
36, stop and reconcile against Phase 1's output rather than adjusting the target number.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - set `load_when.commands` to `[]` on the
  entries classified redundant.

**Verification**:
- `jq empty agent-system/extensions/core/index-entries.json` succeeds.
- Structural diff shows changes confined to `load_when.commands` on the expected path set.
- Dual-hook count in that file drops from 47 to 11.
- `bash .claude/scripts/generate-context-line-counts.sh --check` reports no new drift (line counts
  were not touched, so this should be unchanged from baseline).

---

### Phase 4: Deploy and run the verification bar [COMPLETED]

**Goal**: Propagate both source-store changes into the deploy tree and confirm the deployed check
reports 0 redundant entries and contributes to the exit code.

**Tasks**:
- [x] Run `bash .claude/scripts/deploy-headless.sh` (or the picker's Reload All / Regenerate path)
      to regenerate the deploy tree. *(completed: "Resynced 5 extension(s)")*
- [x] Verify propagation explicitly rather than assuming it: diff
      `agent-system/extensions/core/scripts/validate-context-budgets.sh` against
      `.claude/scripts/validate-context-budgets.sh` and confirm they match; confirm
      `.claude/context/index.json` now shows the narrowed `load_when.commands` arrays. *(completed:
      byte-identical diff; deployed index.json shows 13 dual-hook entries, down from 49, and
      `meta/meta-guide.md`'s `load_when.commands` is now `[]`)*
- [x] Run `bash .claude/scripts/validate-context-budgets.sh` and `--verbose`. Capture both outputs.
      *(completed)*
- [x] Confirm: redundant count is 0; the legitimate-dual informational line reports the expected
      count; the `unclassifiable-command` line reports its count; no `[DEGRADED ROUTE DERIVATION]`
      banner appears. *(completed: redundant=0, legitimate=13 -- path-for-path identical to the
      Phase 1 legitimate-dual list -- unclassifiable=0, no degraded banner)*
- [x] Confirm the exit code and Summary block: the redundant bucket now contributes to `VIOLATIONS`
      (demonstrated in Phase 5 against a fixture; here confirm the run is clean and the exit code is
      unchanged-from-baseline-or-better). *(completed: Violations stayed at 8 (all pre-existing
      Agent Budget Check overages, unrelated to this check); the prior "Warnings: 1" line is now
      gone since the Double-Loading Check no longer contributes a routine warning)*
- [x] Confirm no other check in the script regressed: compare the full output against the Phase 1
      baseline capture, section by section (tier caps, Dead Entry Check, documented exceptions).
      *(completed: full-section diff between the baseline and the post-deploy `--verbose` capture
      is byte-identical for every section except Double-Loading Check)*
- [x] Measure the cross-extension blast radius: run the predicate over every
      `agent-system/extensions/*/index-entries.json` and record per-extension bucket counts. Record
      the finding (expected: extension entries land in `unclassifiable-command`, so loading another
      extension set does not newly fail the check). Do not mass-edit those files. *(completed --
      see the "Cross-extension blast radius" table below)*
- [x] Run the adjacent validators that read the same index to confirm no collateral breakage:
      `validate-index.sh`, `validate-context-index.sh`, `validate-extension-index.sh`,
      `validate-wiring.sh`, `check-extension-docs.sh`. *(completed: all five pass in `.claude`
      scope. `validate-wiring.sh --all`'s 41 failures are entirely in the unrelated `.opencode`
      tree -- pre-existing "Missing context file" drift, confirmed independent of this task's
      changes by running `--claude` alone (0 failures, 1 pre-existing warning) vs. `--opencode`
      alone (same 41 failures) in isolation)*

**Cross-extension blast radius** (measured, not assumed):

| Extension | Dual-hook | Redundant | Legitimate | Unclassifiable |
|---|---|---|---|---|
| core (loaded) | 11 | 0 | 11 | 0 |
| memory (loaded) | 2 | 0 | 2 | 0 |
| literature (loaded) | 6 | 0 | 6 | 0 |
| email, nix, nvim (loaded) | 0 | 0 | 0 | 0 |
| present | 36 | 0 | 0 | 36 |
| founder | 25 | 0 | 0 | 25 |
| epidemiology | 15 | 0 | 0 | 15 |
| slidev | 15 | 0 | 0 | 15 |
| filetypes | 10 | 0 | 0 | 10 |
| cslib, formal, latex, lean, python, typst, web, z3 | 0 | 0 | 0 | 0 |

Every non-loaded extension's dual-hook entries land entirely in `unclassifiable-command` -- 0
redundant anywhere outside `core`. Confirms the plan's Deployment-scope prediction: loading
another extension set does not newly fail the check under the new predicate.

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: interface

**Scope Hypothesis**: The deploy is expected to touch exactly two deployed artifacts derived from
this task's edits -- `.claude/scripts/validate-context-budgets.sh` and `.claude/context/index.json`
-- and the five adjacent validators are expected to be unaffected. Confirm by diffing the deployed
script against source, by inspecting the deployed index's changed entries, and by running each of
the five validators and comparing to their pre-change behavior; a validator that newly fails is a
finding to resolve in this phase.

**Files to modify**:
- None directly. Deploy regenerates `.claude/**`, which is a disposable artifact, not an edit target.

**Verification**:
- `bash .claude/scripts/validate-context-budgets.sh` reports 0 redundant dual-hook entries.
- Deployed script is byte-identical to the source-store copy.
- All five adjacent validators exit as they did at baseline.

---

### Phase 5: Negative test proving the check still fires [NOT STARTED]

**Goal**: Commit a regression test that fails if the check ever stops discriminating -- the durable
guard against this defect recurring.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-double-loading-check.sh` following the
      conventions of the existing tests under that directory (exit codes, assertion helpers, output
      style).
- [ ] Build fixture index files in a temp directory, invoking the **deployed**
      `.claude/scripts/validate-context-budgets.sh --index <fixture>` (the source copy is blocked by
      `deploy-root-guard.sh`).
- [ ] **Positive case (the check still fires)**: fixture entry with
      `agents: ["meta-builder-agent"]`, `commands: ["/meta"]` -- the most common redundant shape.
      Assert the redundant count is >= 1, the offending path is named in the output, and the exit
      code is non-zero.
- [ ] **Discrimination case (it is not trivially firing)**: fixture entry with
      `agents: ["meta-builder-agent"]`, `commands: ["/review"]` -- a direct command. Assert it does
      NOT increment the redundant count and does not affect the exit code.
- [ ] **Orchestrate case**: fixture entry with `agents: ["meta-builder-agent"]`,
      `commands: ["/meta", "/orchestrate"]`. Assert it lands in the legitimate-dual bucket, pinning
      the documented decision that `/orchestrate` never subsumes an entry's `agents[]`.
- [ ] **Unclassifiable case**: fixture entry pairing an extension command with an extension agent.
      Assert it lands in the named `unclassifiable-command` bucket and does not contribute to the
      exit code -- pinning the coverage boundary so a future change cannot silently reclassify it.
- [ ] **Degraded-derivation case**: run against a stubbed environment where one route source is
      unreadable; assert the `[DEGRADED ROUTE DERIVATION]` banner appears and the affected command is
      treated as unclassifiable, never as direct.
- [ ] Declare the test in `agent-system/extensions/core/manifest.json` `provides.scripts` (matching
      how sibling tests under `scripts/tests/` are declared) so it reaches the deploy tree.
- [ ] Redeploy and run the test from `.claude/scripts/tests/`; confirm all cases pass.

**Timing**: 1.25 hours

**Depends on**: 4

**Verification Tier**: interface

**Scope Hypothesis**: Five test cases are asserted here (positive, discrimination, orchestrate,
unclassifiable, degraded). Confirm each is actually exercised by temporarily inverting the check's
predicate and observing that the positive and discrimination cases fail -- a test that cannot fail
is not a test. Also confirm the manifest declaration is the correct propagation mechanism for a
`scripts/tests/` path by checking how an existing sibling test is declared, rather than assuming.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-double-loading-check.sh` - new regression test.
- `agent-system/extensions/core/manifest.json` - declare the new test script under `provides.scripts`.

**Verification**:
- All five cases pass against the deployed script.
- Temporarily inverting the predicate makes the positive and discrimination cases fail (proving the
  assertions are live).
- The test file lands in `.claude/scripts/tests/` after redeploy.

---

### Phase 6: Document the criterion and close out [NOT STARTED]

**Goal**: Record the criterion where a future entry author will find it, and confirm no deliverable
rule was violated.

**Tasks**:
- [ ] Document the hook-shape policy in
      `agent-system/extensions/core/context/patterns/context-discovery.md` (which already discusses
      `load_when` query patterns and references this validator): state when an entry should carry
      `agents[]` only, `commands[]` only, or both; state that a `commands[]` hook whose route is
      already covered by `agents[]` is redundant and will fail validation; point to the check as the
      enforcement mechanism.
- [ ] Update the `agent-system/extensions/core/context/index.schema.json` `load_when` field
      documentation if it describes `agents`/`commands` semantics, so the schema and the policy
      agree.
- [ ] Check whether `check-extension-docs.sh` or the extension-development guide documents index
      entry authoring and needs the same policy pointer; add it if so.
- [ ] Update `line_count` for any context file whose length changed:
      `bash .claude/scripts/generate-context-line-counts.sh --write`, then re-verify with `--check`.
- [ ] Run `bash .claude/scripts/check-task-references.sh` and confirm no task-number citation was
      introduced anywhere outside `specs/**`.
- [ ] Run `bash .claude/scripts/lint/lint-agent-contracts.sh` and
      `bash .claude/scripts/lint/lint-routing-wiring.sh` to confirm no lint regression.
- [ ] Redeploy and run the full verification bar one final time: the check reports 0 redundant, the
      regression test passes, `check-extension-docs.sh` passes.

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/context-discovery.md` - hook-shape authoring policy.
- `agent-system/extensions/core/context/index.schema.json` - `load_when` semantics note (only if it
  currently documents them).

**Verification**:
- `check-task-references.sh` exits 0.
- `generate-context-line-counts.sh --check` exits clean.
- `check-extension-docs.sh` exits 0.
- Final `validate-context-budgets.sh` run reports 0 redundant dual-hook entries.

---

## Testing & Validation

- [ ] `bash .claude/scripts/validate-context-budgets.sh` reports 0 redundant dual-hook entries.
- [ ] The redundant bucket contributes to `VIOLATIONS` and the exit code (demonstrated by the
      positive fixture case, not merely asserted in a comment).
- [ ] The legitimately dual-addressed entries are exempt by the predicate's own false result, with
      no allowlist file and no hardcoded count anywhere in the script.
- [ ] `test-double-loading-check.sh` passes all five cases from `.claude/scripts/tests/`.
- [ ] Inverting the predicate makes the positive and discrimination cases fail.
- [ ] `validate-index.sh`, `validate-context-index.sh`, `validate-extension-index.sh`,
      `validate-wiring.sh`, `check-extension-docs.sh` all exit as at baseline.
- [ ] `check-task-references.sh` exits 0.
- [ ] Every edit landed in `agent-system/extensions/**`; `.claude/**` changed only via deploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/validate-context-budgets.sh` (modified) - three-bucket
  mechanical Double-Loading Check with live route derivation and violation promotion.
- `agent-system/extensions/core/index-entries.json` (modified) - `load_when.commands` cleared on the
  redundant entries.
- `agent-system/extensions/core/scripts/tests/test-double-loading-check.sh` (new) - regression test.
- `agent-system/extensions/core/manifest.json` (modified) - test script declaration.
- `agent-system/extensions/core/context/patterns/context-discovery.md` (modified) - hook-shape policy.
- `specs/998_double_loading_warning_triage/summaries/01_*-summary.md` - implementation summary
  recording the final bucket counts and the cross-extension measurement from Phase 4.

## Rollback/Contingency

All changes are confined to tracked files under `agent-system/extensions/**` plus regenerated
`.claude/**` deploy output. Rollback is `git checkout` of the changed source files followed by a
redeploy; `.claude/**` is a disposable artifact and needs no separate revert.

Per-phase contingencies:
- **Phase 1 divergence** (predicate does not reproduce the report's 36/13): stop. Reconcile before
  editing any file -- the entire plan is built on that partition, and proceeding on an unreconciled
  split would narrow the wrong entries.
- **Phase 3 over-broad diff**: restore `index-entries.json` from git and re-derive the path list;
  never hand-repair a partially applied transformation.
- **Phase 4 adjacent-validator regression**: revert Phase 3's index change first (it is the only
  edit that alters data other validators read), diagnose, then reapply. The script change in Phase 2
  is inert to other validators.
- **Phase 5 test cannot be made to fail under an inverted predicate**: treat as a blocking defect in
  the test, not a passing result. A regression test that cannot fail is exactly the failure mode
  this task exists to eliminate.
- **Escape hatch if the redundant count cannot reach 0**: the task forbids resolving this by
  deleting the check or freezing it at warning. The permitted fallback is the second branch of the
  verification bar -- the count consists solely of entries covered by the mechanically enforced
  exemption criterion. Any such residue must be named in the script's own output and explained in
  the summary, never silently absorbed.
