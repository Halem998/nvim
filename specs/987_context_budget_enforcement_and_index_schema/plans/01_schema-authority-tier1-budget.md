# Implementation Plan: Task #987

- **Task**: 987 - Context budget enforcement: demote always-load bloat, break the meta catch-all, one index schema
- **Status**: [NOT STARTED]
- **Effort**: 6.25 hours
- **Dependencies**: 978 (index-validator/line-count repair — COMPLETED; precondition confirmed satisfied: all 470 entries across 19 extensions carry `line_count`)
- **Research Inputs**: specs/987_context_budget_enforcement_and_index_schema/reports/01_context-budget-schema-reconciliation.md
- **Artifacts**: plans/01_schema-authority-tier1-budget.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Give index entries ONE schema authority, make drift fail loudly, and bring Tier-1 (always-load)
context under its own 500-line target. The research established that no JSON-Schema validator is
ever run against `index.schema.json` — it is unenforced documentation, which is how 14 of 19
extensions drifted from it — so the durable fix is a hand-written jq conformance rule in
`check-extension-docs.sh` (the established idiom for Rules A-S), not a new validator dependency.
Definition of done: one reconciled schema file, its two competing prose examples corrected to
match it, a doc-lint rule that fires on non-conformance and on EXTENSION.md over 60 lines, a
fixture test proving both fire, Tier-1 at or under 500 lines, and four named follow-on tasks
created for the bulk migrations this task deliberately does not attempt.

### Research Integration

Findings this plan builds on directly:

- `task_types` is the dominant live `load_when` key (168/470 entries, 6 extensions) yet is
  FORBIDDEN by `index.schema.json`'s `additionalProperties: false`. `languages` (used by 12
  extensions as their sole task-type hook) and `skills` (literature, memory) are confirmed dead at
  runtime — their only two occurrences anywhere are defensive exclusions inside
  `validate-context-budgets.sh`'s dead-entry guard.
- `summary` and `line_count` are the one point of real convergence (100% of entries). `tier` is
  used by zero entries despite the budget script querying it four times.
- The live merge engine (`lua/neotex/plugins/ai/shared/extensions/merge.lua`,
  `append_index_entries`) passes entries through verbatim, so the reconciled shape needs no loader
  change — only the extensions' own source files must converge.
- Tier-1 is 996L against a 500L target; `patterns/context-discovery.md` (311L),
  `patterns/jq-escaping-workarounds.md` (281L), and `repo/project-overview.md` (70L, which also
  double-loads via a static `@`-import in `merge-sources/claudemd.md`) account for 662L of it.
- 7 of 19 EXTENSION.md files exceed the 60-line limit, which no script enforces today.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but `roadmap_flag` was not set for this dispatch, so no
roadmap-review/roadmap-update phases are included and ROADMAP.md is not modified. No open roadmap
item names index-entry schema or context budgets; the nearest neighbour is the unchecked "Context
discovery caching" item, which this work neither advances nor blocks.

## Scope Decision (explicit resolution of the escalated question)

The research recommended landing Phase A now and spawning Phases B-E as follow-on tasks. **This
plan ADOPTS that recommendation, with the boundary moved to include two additional items** that
are small, single-file, and each satisfy a distinct line of the task's own VERIFICATION BAR:

**In scope for this task**:

| Item | Files | Why it stays here |
|---|---|---|
| Reconcile the schema | `core/context/index.schema.json` | Declared `file_scope`; the "one authority" headline |
| Rule T (schema conformance) + Rule U (EXTENSION.md length), advisory | `core/scripts/check-extension-docs.sh` | Declared `file_scope`; the "fails loudly on drift" bar item |
| Fix the two competing examples | `core/docs/reference/standards/extension-slim-standard.md`, `agent-system/extensions/README.md` | The first is declared `file_scope`; the second is the *third* authority — leaving it uncorrected recreates exactly the problem this task exists to fix |
| Fixture test | new `core/scripts/tests/test-index-entries-schema.sh` + `core/manifest.json` | The bar item says the check must fail on a fixture; a fixture needs a test harness, and a new script must be declared or Rule Q fails |
| Tier-1 demotion + project-overview dedup | `core/index-entries.json` | Three-entry edit in one file, independently verifiable today, and the only way to satisfy the "Tier 1 <= 500 lines" bar item |

**Deliberately NOT in scope — spawned as follow-on tasks in Phase 6**:

| Follow-on | Slug | Covers | Verification it inherits |
|---|---|---|---|
| FU-1 | `index_entries_schema_migration` | Migrate all 19 extensions' `index-entries.json` to the reconciled shape: fold `description` detail into `summary` per entry (10 extensions, 166 entries — editorial, not a blind rename), rename `tags`->`keywords`, migrate `languages`->`task_types` 1:1 using the research's §4 map, delete the two `filetypes` `["deck"]` arrays, delete `literature`/`memory` `skills` arrays | Rule T zero advisories on all 19; `grep -rn 'load_when.languages\|load_when.skills'` returns zero declarations |
| FU-2 | `meta_catchall_decomposition` | Give the 24 meta-only `core/index-entries.json` entries real `agents`/`commands` hooks per the research's §5 thematic groupings; trim the wider 123-entry `task_types:["meta"]` set; derive `tier` algorithmically in `validate-context-budgets.sh` from `load_when` shape instead of the never-populated authored field; fix the 2 `load_when.agents` values naming agents that do not exist | `validate-context-budgets.sh` zero per-agent violations (or documented cap changes); the "all entries have tier field" check passes via derivation |
| FU-3 | `extension_md_slim_down` | Trim the 7 EXTENSION.md violators into their own `context/project/*/` files per the slim standard's own migration template, adding an index entry per moved file | Rule U zero advisories |
| FU-4 | `promote_schema_gates_to_hard` | Flip `SCHEMA_CONFORMANCE_GATE_MODE`'s default from `advisory` to `hard` once FU-1 and FU-3 are clean (mirrors the promotion sequence `ORPHAN_GATE_MODE`/`INDEX_TRUTH_GATE_MODE` already went through). Depends on FU-1 and FU-3 | `check-extension-docs.sh` exits 0 with the gate hard |

**Honest accounting of what this leaves unmet**: of the task's three VERIFICATION BAR lines, this
task satisfies "Tier 1 <= 500 lines" and "check-extension-docs.sh fails on a fixture" in full. It
does NOT satisfy "zero per-agent violations" (needs FU-2) or "grep for `load_when.languages`
returns zero declarations" (needs FU-1). Those two bars transfer to the named follow-on tasks
rather than being quietly dropped.

**`file_scope` is treated as advisory, not a wall**: per `state-management.md`, `file_scope` is
"descriptive/anticipated (not filesystem-validated)". The research proved it an undercount, so the
plan expands it by two files (`agent-system/extensions/README.md`, `core/index-entries.json`) plus
two new files, each justified in the table above, and defers the genuinely large migrations.

### Correction to one research recommendation

The research recommended Rule T reuse the existing `INDEX_TRUTH_GATE_MODE` variable "defaulting
advisory until migration". That is not achievable: `INDEX_TRUTH_GATE_MODE` already defaults to
`hard` (`check-extension-docs.sh`, `check_line_count_accuracy`'s preceding comment block explains
why), and Rules R/S depend on it staying hard. Routing Rule T through the same variable would
either make Rule T a day-one hard failure for 14 extensions or silently demote Rules R and S.
This plan therefore introduces a **sibling** variable, `SCHEMA_CONFORMANCE_GATE_MODE`, defaulting
to `advisory`, with its own reporter — the same sibling-not-overload pattern
`INDEX_TRUTH_GATE_MODE` itself used relative to `ORPHAN_GATE_MODE`.

## Goals & Non-Goals

**Goals**:

- `index.schema.json` describes the field set real extensions need: `task_types` allowed,
  `languages`/`skills` gone, `summary`/`line_count` required, and explicit prose recording why
  `description`, `tags`, and `tier` are deliberately absent.
- `check-extension-docs.sh` flags schema non-conformance (Rule T) and EXTENSION.md over 60 lines
  (Rule U), advisory-first, without changing today's exit code.
- The two competing prose examples point at the schema instead of contradicting it, reducing three
  authorities to one-plus-pointers.
- A committed fixture test proves both new rules fire on a violation and stay silent on a
  conformant input.
- Tier-1 always-load total is at or under 500 lines, and `repo/project-overview.md` no longer
  double-loads.
- Four follow-on tasks exist in `state.json`/TODO.md carrying the deferred work and its
  verification bars.

**Non-Goals**:

- Migrating any extension's `index-entries.json` field set (FU-1).
- Re-hooking the meta catch-all or changing `validate-context-budgets.sh` (FU-2).
- Trimming any EXTENSION.md content (FU-3).
- Promoting either new rule to `hard` (FU-4).
- Fixing `install-extension.sh`'s stale index-merge jq logic (separate deploy mechanism, not
  exercised by the live Lua loader; recorded as a known out-of-scope risk).
- Fixing the `nvim` directory vs `neovim` task_type string mismatch — pre-existing, belongs with
  the routing-consolidation work.
- Editing anything under `.claude/**`. That tree is a gitignored, disposable deploy artifact; every
  edit targets `agent-system/extensions/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Rule T/U ship hard and turn a passing doc-lint gate into a standing failure for 14 (T) and 7 (U) extensions | H | H if reused var, L as planned | Dedicated `SCHEMA_CONFORMANCE_GATE_MODE` defaulting `advisory`; Phase 6 asserts the exit code is unchanged from the pre-change baseline |
| New test script not declared in `core/manifest.json` `provides.scripts` trips Rule Q (undeclared scripts on disk) | M | H if forgotten | Phase 4 declares it in the same phase that creates it, and re-runs the doc-lint to confirm |
| Editing `core/index-entries.json` does not change `.claude/context/index.json`, so a Tier-1 measurement taken without redeploy is meaningless | H | M | Phase 5 measures with `validate-context-budgets.sh --index` against a freshly regenerated deployed index (`deploy-headless.sh`), and records the before/after pair |
| Demoting `always: true` without giving the entry another hook makes it register as a dead entry in `validate-context-budgets.sh` | M | H if unhandled | Each demoted entry receives an explicit `commands`/`agents` hook in the same edit; Phase 5 verification includes the dead-entry section of the script's output |
| A brand-new `scripts/tests/*.sh` file may never reach `.claude/scripts/tests/` on an already-deployed repo (documented extension-loader gap) | M | M | Run the fixture test from the source store with the sanctioned `REPO_ROOT=$(pwd)` override rather than asserting it is deployed; record the gap, do not attempt to fix the loader here |
| Folding `description` into `summary` looks mechanical but is editorial | M | — | Explicitly deferred to FU-1 with that constraint written into the task description |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 5 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Reconcile index.schema.json into the single authority [NOT STARTED]

**Goal**: `index.schema.json` declares exactly the field set real extensions need, and records in
prose which fields are deliberately excluded and why.

**Tasks**:
- [ ] Add `task_types` to `$defs.entry.properties.load_when.properties` as an array of strings,
      with a description naming it the primary task-type discriminator and examples drawn from
      real values (`["meta"]`, `["lean4"]`).
- [ ] Delete the `languages` property from `load_when` (confirmed dead at runtime; only consumer
      is a defensive exclusion in `validate-context-budgets.sh`'s dead-entry guard).
- [ ] Leave `load_when`'s `additionalProperties: false` in place so `skills` and any future
      undeclared discriminator stay forbidden; add a `description` line on the `load_when` object
      recording that the closed key set is `agents` / `commands` / `task_types` / `always`, and
      that `languages` and `skills` were removed as never-queried.
- [ ] Add a prose note (as a `$comment` or an extended top-level `description`) recording that
      `description`, `tags`, and `tier` are deliberately absent at entry level: `description`
      duplicates `summary` and its unique detail is to be folded into `summary`, `tags` is a naming
      mismatch for the already-declared `keywords`, and `tier` is to be derived from `load_when`
      shape rather than hand-authored.
- [ ] Confirm entry-level `required` stays `["path", "domain", "summary", "line_count"]` and
      `additionalProperties: false` is retained.
- [ ] Bump `version` if the file carries one, or leave absent if it does not.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/context/index.schema.json` - add `task_types`, remove `languages`,
  add exclusion rationale prose

**Verification**:
- `jq empty agent-system/extensions/core/context/index.schema.json` exits 0.
- `jq -r '.["$defs"].entry.properties.load_when.properties | keys[]'` prints exactly `agents`,
  `always`, `commands`, `task_types` (sorted) and nothing else.
- `jq -r '.["$defs"].entry.required[]'` prints `path`, `domain`, `summary`, `line_count`.

---

### Phase 2: Add Rules T and U to check-extension-docs.sh, advisory-first [NOT STARTED]

**Goal**: Schema non-conformance and EXTENSION.md over-length are detected and reported loudly on
every doc-lint run, without changing the script's current exit code.

**Tasks**:
- [ ] Introduce `SCHEMA_CONFORMANCE_GATE_MODE="${SCHEMA_CONFORMANCE_GATE_MODE:-advisory}"` with a
      comment block explaining it is a SIBLING to `INDEX_TRUTH_GATE_MODE` (which defaults `hard`
      and whose remediation already landed), not an overload of it, and that it defaults advisory
      because the extension migration has not yet happened.
- [ ] Add `schema_conformance_report()` mirroring `index_truth_report()`: route to `fail()` when
      the mode is `hard`, otherwise `info "ADVISORY (not yet blocking): ..."`.
- [ ] Add `check_index_entries_schema()` (Rule T), per-extension, source-level, following
      `check_line_count_accuracy()`'s hand-written jq idiom — never a new ajv/jsonschema
      dependency. For each entry in `$ext_path/index-entries.json` assert: (a) `path`, `domain`,
      `subdomain`, `summary`, `line_count` all present; (b) no `description` key, no `tags` key;
      (c) `load_when`'s populated keys are a subset of `agents`/`commands`/`task_types`/`always`
      (so a present-but-empty `languages` array is reported, since the goal is zero declarations);
      (d) `domain` is one of `core`/`project`/`system`. Report each violation through
      `schema_conformance_report()` with the extension name and entry path in the message.
- [ ] Add `check_extension_md_length()` (Rule U), per-extension: `wc -l` of
      `$ext_path/EXTENSION.md`, report through `schema_conformance_report()` when it exceeds 60,
      naming the actual and the limit. Skip silently when the file is absent (`check_file` already
      fails that case).
- [ ] Register both in the per-extension loop next to `check_line_count_accuracy`.
- [ ] Update the script header: add the two new bullets to the leading checks list, and add
      `T - check_index_entries_schema` and `U - check_extension_md_length` to the Rule letter
      index in first-introduced order.

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Rule T is expected to fire for 14 of 19 extensions and Rule U for 7 of 19
(literature 169L, email 106L, lean 73L, cslib 71L, present 64L, nix 62L, core 62L). Confirm at
implementation time by counting the ADVISORY lines the run actually emits per rule and comparing
against these numbers; a materially different count means the predicate is wrong, not that the
codebase changed. Record the observed counts.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - new gate-mode variable,
  reporter, two check functions, two loop registrations, header index update

**Verification**:
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits with
  the SAME code as a baseline run captured before the edit (capture the baseline first).
- ADVISORY lines appear for both `Rule T:` and `Rule U:` in that output.
- `SCHEMA_CONFORMANCE_GATE_MODE=hard REPO_ROOT=$(pwd) bash ... check-extension-docs.sh` exits 1
  and the same findings appear as `FAIL:` — proving the severity switch is wired, without
  committing the hard default.
- `bash -n` on the script passes.

---

### Phase 3: Correct the two competing schema examples [NOT STARTED]

**Goal**: Neither prose document contradicts `index.schema.json`; both point at it as the
authority.

**Tasks**:
- [ ] In `extension-slim-standard.md`'s "Index Integration" section, replace the example's
      `description` with `summary`, replace `load_when.languages` with `load_when.task_types`, and
      add `domain`/`subdomain` so the example is actually schema-conformant as written.
- [ ] Add one line under that example naming
      `agent-system/extensions/core/context/index.schema.json` as the authoritative field
      definition, so a future edit to the example cannot silently become a fourth authority.
- [ ] Note in the "Size Limit" section that the 60-line limit is now lint-enforced (Rule U in
      `check-extension-docs.sh`), and correct the stale "Current total across 14 extensions: ~1,111
      lines" figure — recount it against the 19 extensions that exist now, or replace the absolute
      figure with a pointer to the lint output so it cannot go stale again (prefer the latter).
- [ ] In `agent-system/extensions/README.md`'s "index-entries.json Format" section, replace
      `load_when.languages` with `load_when.task_types` and add the required `summary` and
      `line_count` fields to the "Correct example".
- [ ] Reduce that section to a canonical-path rule plus a pointer to `index.schema.json` and
      `extension-slim-standard.md`, rather than a third free-standing field example.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md` - Index
  Integration example, authority pointer, size-limit enforcement note
- `agent-system/extensions/README.md` - index-entries.json Format example and pointer

**Verification**:
- Extract each corrected JSON example and confirm it satisfies the Rule T predicate set (paste it
  into a scratch `index-entries.json` under a temp fixture and confirm Rule T is silent).
- `grep -n 'languages' ` on both files returns no hit inside an index-entry example.
- No task numbers appear in either file (both are deliverables outside `specs/**`).

---

### Phase 4: Fixture test for Rules T and U [NOT STARTED]

**Goal**: A committed test proves both new rules fire on a crafted violation and stay silent on a
conformant input — the task's "fails on a fixture index entry" bar.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` following
      the existing test idiom in that directory (`test-validate-no-task-references.sh`'s
      assert-triggers / assert-clean shape).
- [ ] Build a temp fixture extension tree (`manifest.json`, `EXTENSION.md`, `README.md`,
      `index-entries.json`, `context/`) under `mktemp -d`, point `EXT_DIR` at it, and run
      `check-extension-docs.sh` against it.
- [ ] Rule T positive cases, one fixture entry each: a `description` key present; a `tags` key
      present; a `load_when.languages` array present; a missing `line_count`; a `domain` outside
      the enum. Assert a `Rule T:` line naming the entry appears for each.
- [ ] Rule T negative case: a fully conformant entry. Assert no `Rule T:` line mentions it.
- [ ] Rule U positive case: a 61-line `EXTENSION.md`. Assert a `Rule U:` line appears. Negative
      case: a 60-line file. Assert none does (the limit is "exceeds 60", not "reaches 60" — the
      research recorded `formal` at exactly 60L as OK).
- [ ] Assert with `SCHEMA_CONFORMANCE_GATE_MODE=hard` that the fixture run exits non-zero, so the
      test pins the severity wiring rather than only the message text.
- [ ] Declare `tests/test-index-entries-schema.sh` in `agent-system/extensions/core/manifest.json`
      `provides.scripts` (alongside the seven `tests/*.sh` entries already there) — otherwise
      Rule Q fails on an undeclared script file on disk.
- [ ] Clean up the temp fixture on exit (trap), and do not leave anything under `specs/`.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: five Rule T positive cases and one Rule U positive case are assumed
sufficient to cover the predicate set from Phase 2. Confirm at implementation time by checking
every branch of `check_index_entries_schema` and `check_extension_md_length` is reached by at
least one fixture case; add cases if a branch is unexercised.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` - new fixture test
- `agent-system/extensions/core/manifest.json` - declare the new script in `provides.scripts`

**Verification**:
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh`
  exits 0 with all assertions passing.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no
  Rule Q failure for the new script.
- `jq -e '.provides.scripts | index("tests/test-index-entries-schema.sh")'` on the core manifest
  returns a number.

---

### Phase 5: Bring Tier-1 under 500 lines and remove the project-overview double-load [NOT STARTED]

**Goal**: `validate-context-budgets.sh`'s always-loaded total is at or under its 500-line target,
and `repo/project-overview.md` is loaded once rather than twice.

**Tasks**:
- [ ] Capture the baseline: regenerate the deploy tree
      (`bash .claude/scripts/deploy-headless.sh`) and record
      `bash .claude/scripts/validate-context-budgets.sh` always-loaded count, total lines, and the
      per-entry breakdown, plus its dead-entry section.
- [ ] In `agent-system/extensions/core/index-entries.json`, remove `always: true` from
      `patterns/context-discovery.md` and give it a real hook — `agents: ["meta-builder-agent"]`
      plus `commands: ["/meta"]` — on the grounds that CLAUDE.md already inlines the canonical
      adaptive query, so the full document is system-builder reference material, not per-prompt
      material.
- [ ] Remove `always: true` from `patterns/jq-escaping-workarounds.md` and give it a real hook
      scoped to the agents that actually author jq (`meta-builder-agent`,
      `general-implementation-agent`, `general-implementation-hard-agent`) plus
      `commands: ["/errors", "/meta"]`. CLAUDE.md's own jq-safety section already carries the
      essential `| not` pattern inline, so the deep reference is genuinely on-demand.
- [ ] Remove `always: true` from `repo/project-overview.md` and give it
      `commands: ["/project-overview"]`. Keep the `@`-import at `merge-sources/claudemd.md` — it
      is the more universal of the two mechanisms and does not depend on an agent running the
      dynamic-discovery query. This removes the DUPLICATE, not the load: the file is still present
      in every session via the import, and `merge-sources/claudemd.md` is not edited in this phase.
- [ ] Confirm no demoted entry is left hookless (each must retain at least one of
      `agents`/`commands`/`task_types`), so none registers in the dead-entry check.
- [ ] Redeploy and re-measure.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: Tier-1 is currently 996L across 6 entries; removing `always: true` from the
three named entries (311L + 281L + 70L) is predicted to yield 334L across 3 entries
(`checkpoints/README.md` 100L, `README.md` 202L, `reference/README.md` 32L). Confirm by running
`validate-context-budgets.sh` before and after and recording both figures; if the "after" is not
334L, reconcile the discrepancy before closing the phase rather than accepting whatever number
appears.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - three entries lose `always: true` and gain
  explicit `agents`/`commands` hooks

**Verification**:
- `bash .claude/scripts/validate-context-budgets.sh` (after redeploy) reports always-loaded total
  lines <= 500 with status OK.
- Its dead-entry section does not name any of the three demoted paths.
- `jq '[.entries[] | select(.load_when.always == true)] | length'` on
  `agent-system/extensions/core/index-entries.json` returns 3.
- Every demoted entry still satisfies
  `jq '.load_when | (.agents//[] | length) + (.commands//[] | length) + (.task_types//[] | length) > 0'`.

---

### Phase 6: Full-gate verification and follow-on task creation [NOT STARTED]

**Goal**: Every gate is green (or its verdict is unchanged from baseline), and the four deferred
work items exist as real tasks carrying their own verification bars.

**Tasks**:
- [ ] Regenerate the deploy tree and run the full gate set: `bash .claude/scripts/verify-deploy.sh`
      (which includes doc-lint gate 3 and task-reference lint gate 4),
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`,
      `bash .claude/scripts/validate-context-budgets.sh`, and the new fixture test.
- [ ] Confirm `check-extension-docs.sh`'s exit code matches the Phase 2 baseline (the two new
      advisory rules must not have changed the verdict), and that Rules R and S are still hard.
- [ ] Confirm `check-task-references.sh` passes — none of the edited deliverables outside
      `specs/**` may cite a task number.
- [ ] Record the observed Rule T / Rule U advisory counts in the implementation summary, against
      the Phase 2 Scope Hypothesis.
- [ ] Create the four follow-on tasks (FU-1..FU-4 from the Scope Decision table) by appending to
      `specs/state.json` `active_projects` with numbers allocated from `next_project_number` at
      execution time — never hardcoded — each with `task_type: "meta"`, `topic: "agent-system"`, a
      description carrying its scope and inherited verification bar verbatim from that table, the
      binding source-store rule, and a `file_scope` reflecting what the research actually
      established it touches. Set FU-4's `dependencies` to the allocated FU-1 and FU-3 numbers;
      set every FU's `dependencies` to include 987.
- [ ] Regenerate TODO.md with `bash .claude/scripts/generate-todo.sh` and confirm the four new
      entries render.
- [ ] Record the two out-of-scope risks in the implementation summary so they are not lost:
      `install-extension.sh`'s stale index-merge jq logic, and the `nvim`/`neovim` naming mismatch.

**Timing**: 1 hour

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: four follow-on tasks are asserted to cover 100% of the deferred WORK items
2-5. Confirm at implementation time by walking each of the task description's WORK items 1-5 and
each of its three VERIFICATION BAR lines and naming, for each, either the phase in this plan or
the follow-on task that owns it. Any item with no owner is a gap to close before completion.

**Files to modify**:
- `specs/state.json` - four new `active_projects` entries
- `specs/TODO.md` - regenerated (never hand-edited)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` reports no new failures relative to its pre-task baseline.
- `jq '[.active_projects[] | select(.dependencies[]? == 987)] | length'` on `specs/state.json`
  returns 4.
- FU-4's `dependencies` array contains the allocated FU-1 and FU-3 numbers.
- `specs/TODO.md` contains all four new task titles.

---

## Testing & Validation

- [ ] `jq empty` passes on `index.schema.json`, `core/index-entries.json`, and `core/manifest.json`.
- [ ] `bash -n` passes on `check-extension-docs.sh` and the new fixture test.
- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh`
      passes all assertions, including the `SCHEMA_CONFORMANCE_GATE_MODE=hard` non-zero-exit case.
- [ ] `check-extension-docs.sh` exit code is unchanged from the pre-task baseline; Rule T and
      Rule U advisories are visible in its output.
- [ ] `validate-context-budgets.sh` always-loaded total is <= 500 lines with status OK.
- [ ] `check-task-references.sh` passes (no task numbers in any deliverable outside `specs/**`).
- [ ] `verify-deploy.sh` reports no new failures.
- [ ] Every write in this task targeted `agent-system/extensions/**` or `specs/**`; nothing under
      `.claude/**` was hand-authored.

## Artifacts & Outputs

- `agent-system/extensions/core/context/index.schema.json` (modified — the single authority)
- `agent-system/extensions/core/scripts/check-extension-docs.sh` (modified — Rules T and U)
- `agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` (new)
- `agent-system/extensions/core/manifest.json` (modified — declares the new test script)
- `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md` (modified)
- `agent-system/extensions/README.md` (modified)
- `agent-system/extensions/core/index-entries.json` (modified — Tier-1 demotion)
- `specs/state.json`, `specs/TODO.md` (four follow-on tasks)
- `specs/987_context_budget_enforcement_and_index_schema/summaries/01_schema-authority-tier1-budget-summary.md`

## Rollback/Contingency

Every phase touches a small, git-tracked set of files with no generated dependents beyond the
deploy tree, so `git revert` of the phase commit is a complete rollback. Two specifics:

- If Rule T or Rule U turns out to change `check-extension-docs.sh`'s exit code despite the
  advisory default, revert Phase 2's commit rather than patching the severity in place — a
  doc-lint gate that fails for every caller blocks unrelated work, and the rule is worthless if
  its severity wiring is not understood.
- If the Tier-1 demotion in Phase 5 measurably degrades an agent's behavior (a demoted file turns
  out to be load-bearing per-prompt), restore `always: true` on that single entry and record the
  finding; the 500L target is then met by demoting a different candidate, not by abandoning the
  target.
- The deploy tree is regenerable at any point via `bash .claude/scripts/deploy-headless.sh`; a
  broken deploy is never a reason to hand-edit `.claude/**`.
