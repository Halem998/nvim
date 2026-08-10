# Implementation Plan: Convert surviving extension state.json writers to state-write.sh

- **Task**: 995 - Convert surviving extension state.json writers to state-write.sh
- **Status**: [IMPLEMENTING]
- **Effort**: 9 hours
- **Dependencies**: 983 (skill-skeleton collapse, COMPLETED/archived), 984 (state schema/status vocabulary, COMPLETED)
- **Research Inputs**: specs/995_convert_extension_state_writers_to_state_write/reports/01_convert-extension-state-writers.md
- **Artifacts**: plans/01_convert-extension-state-writers.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Every hand-rolled `jq ... specs/state.json > <fixed-temp> && mv <fixed-temp> specs/state.json`
sequence surviving in the source store is replaced by a call to
`.claude/scripts/state-write.sh`, the single mutex-guarded, private-`mktemp` writer. The
conversion is mechanical but high-volume (~46 files) and is decomposed one extension at a time so
a dropped `--session-id` or malformed `--argjson` binding surfaces in a small, reviewable diff.
The task then lands a permanently-wired repo lint (`lint-state-writer-boundary.sh`) so the
anti-pattern class cannot silently return, replacing the one-off scoped grep the archive/vault
conversion used and discarded. Definition of done: the full-source-store grep for a hand-rolled
write returns zero modulo a short, individually-evidenced exclusion list; the new lint fails on a
hand-rolled fixture and passes on the cleaned tree; and a founder and a present skill dry-run
exercise the converted write path.

### Research Integration

The research report's re-grep (not the pre-collapse inventory in the task description) is the
basis for every count below, and this plan independently re-measured each one during planning.
Integrated findings:

- **web** and **epidemiology's `skills/`** are already fully converted — zero conversion budget,
  only a confirming re-grep. epidemiology is *not* clean once `commands/` is counted.
- The canonical "after" shapes to copy are `skill-status-sync` (status update + artifact append),
  `skill-researcher` (`--argjson num "$task_number"` rather than string-interpolated
  `'$task_number'`), and the already-converted `skill-web-*` skills as the closest structural
  analogue.
- Four cslib sites are structurally non-uniform and must be individually reviewed, never batch
  find/replaced: the `$CSLIB_STATE` hardcoded-absolute-path bug, two `/tmp/state.tmp`
  machine-global staging sites, and `skill-cslib-vet`'s task-creation shape.
- A regex-only lint cannot catch variable-indirected writes (the `$CSLIB_STATE` class). That
  limitation is documented in the lint header and compensated for by the dry-run smoke test,
  rather than being papered over.

### Scope Boundary Resolution (REQUIRED DECISION — resolved: INCLUDE)

The research report deliberately left this open. **This plan resolves it as Option A: the 16
`commands/*.md` survivor files are IN SCOPE and are converted by this task** (Phase 6). The
declared `file_scope` field lists only the six `skills/` directories; the task description's own
WORK item 1 and VERIFICATION BAR say "the FULL source store". They are included, for four
reasons:

1. **The verification bar is otherwise unsatisfiable.** The task's own bar reads "grep for 'mv'
   onto state.json outside state-write.sh across the FULL source store returns zero." Excluding
   `commands/` means the task cannot pass its own stated bar, only a silently narrowed one.
2. **`file_scope` is not a contract boundary.** Per `rules/state-management.md` and
   `context/reference/state-management-schema.md`, `file_scope` is descriptive/anticipated, set
   at creation time, never filesystem-validated, and used for lock-overlap detection — not for
   authorizing or forbidding edits. The description body is the authoritative statement of work,
   and it says FULL source store.
3. **The lint forces the question anyway.** WORK item 3 lands a permanent lint. If `commands/`
   is excluded, the lint must either fail on the tree the moment it is wired, or carry a
   22-line unjustified exclusion list — which is precisely the "declared and justified
   exclusions" discipline this plan is trying to uphold, inverted into an alibi.
4. **Splitting costs more than it saves.** These are the same anti-pattern against the same
   target mechanism; a follow-on task would re-derive identical context. The one genuine
   difference — `commands/` sites are task-*creation* sites touching `next_project_number` — is
   an argument for the mutex, not against the conversion, and is handled by giving them their
   own phase with their own review criteria rather than folding them into the skills phases.

**Also pulled in, and flagged as a deliberate widening beyond even the six named extensions**:
`core/commands/review.md` writes `specs/reviews/state.json` through the identical hand-rolled
shape (2 matching lines). It matches the verification bar's literal grep. It is converted in
Phase 7 via `state-write.sh --state-file`, because leaving it means the new lint ships with a
core-extension carve-out that has no principled justification.

**Explicitly NOT in scope** (each carries evidence, recorded as the lint's exclusion list in
Phase 8, never as a silent omission):

| Excluded | Reason | Evidence |
|---|---|---|
| `state-write.sh` itself | It *is* the sanctioned writer | The file the lint exists to route callers to |
| `mv "${vault_path}/archive/state.json" "${vault_path}/state.json"` in `core/commands/todo.md`, `core/skills/skill-todo/SKILL.md`, `core/scripts/deprecated/vault-operation.sh` | A file relocation, not a jq-staged read-modify-write; no temp path, no transform | Grep line shows a bare `mv` of one state file onto another with no `jq` producing it |
| `jq -e ... specs/state.json > /dev/null` in `core/commands/task.md`, `core/context/orchestration/validation.md` | Read-only existence checks; redirect target is `/dev/null` | Grep line's redirect target |
| `core/scripts/tests/test-update-task-status.sh` | Test fixture deliberately constructing a corrupt-state fixture; converting it would defeat the test | File lives under `scripts/tests/` and the write is fixture setup |
| `core/context/patterns/jq-escaping-workarounds.md`, `core/context/patterns/task-lock.md` | Illustrative prose about the anti-pattern; not live writers | Both write `specs/tmp/test-state.json` or describe the pattern in prose |
| `base_branch` / `forcing_data` schema non-conformance | WORK item 2 says "preserving each site's semantics" — changing *what* is written is a different task from changing *how* | Report's schema-conformance section; logged as a follow-up, not fixed here |

`core/context/formats/command-structure.md` is the one doc hit that is NOT excluded: it teaches
the anti-pattern as a worked example and is corrected in Phase 7.

### Prior Plan Reference

No prior plan. This is the first plan for this task.

### Roadmap Alignment

`roadmap_path` was not supplied in the delegation context and `roadmap_flag` is not set, so no
roadmap phases are added. `specs/ROADMAP.md` exists but contains no `state-write` / state-writer
item, so there is no alignment claim to make.

## Goals & Non-Goals

**Goals**:
- Every live hand-rolled `specs/state.json` (and `specs/reviews/state.json`) read-modify-write in
  the source store routes through `state-write.sh`, preserving each site's existing semantics.
- The `$CSLIB_STATE` hardcoded-absolute-path bug is fixed as part of its site's conversion.
- A permanently-wired `lint-state-writer-boundary.sh` exists with its own fixture test, wired as
  a `verify-deploy.sh` gate, so the class cannot recur.
- The exclusion list is enumerated, reasoned, and evidenced — never an unqualified "zero hits".

**Non-Goals**:
- Changing *what* any site writes (no `base_branch`/`forcing_data` schema fixes, no field
  additions or removals).
- Changing any site's TODO.md handling. `--regen-todo` is added ONLY where the site already
  regenerated TODO.md; a site that hand-Edits TODO.md keeps doing so.
- Refactoring the surrounding skill/command prose, stage numbering, or structure.
- Editing `.claude/**` by hand. All edits target `agent-system/extensions/**`; `.claude/` is
  reached only by running the deploy.
- Merging adjacent write sites into a single `state-write.sh` call or introducing
  `SCOPE_MUTEX_HELD` guest-mode nesting. Each existing site becomes one call, matching the
  landed core-skill precedent.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| High-volume mechanical edit silently breaks a skill's postflight (dropped `--session-id`, malformed `--argjson`) | H | H | One extension per phase; each phase ends with bash-fence extraction + `bash -n` over every edited file; Phase 10 dry-runs a founder and a present path |
| Non-uniform cslib sites missed by batch conversion | M | H | Phase 5 handles all 5 cslib files as individually-reviewed sites, explicitly forbidding batch find/replace |
| Regex-only lint gives false confidence against variable-indirected writes | M | M | Limitation documented in the lint header; lint paired with the dry-run smoke test; Phase 10 verifies by inspection, not by grep alone |
| Line-count vs. site-count confusion inflates or deflates "done" (a two-line `... > tmp && \` + `mv ...` site counts as 2 grep lines) | M | H | Every conversion phase carries a Scope Hypothesis naming the *matching-line* baseline from Phase 1 and requiring per-file confirmation; counts are hypotheses, never facts |
| `next_project_number` race semantics change when task-creation sites move under one mutex | L | L | `state-write.sh` provides strictly stronger serialization than the current unguarded sequence; Phase 6 confirms each filter's read-modify-write stays inside one call |
| Lint wired to `verify-deploy.sh` before the tree is clean, red-lighting every deploy | H | M | Phase 9 (wiring) depends on ALL conversion phases; phase declares `atomic-batch` so lint + manifest + gate land together |
| Hand-editing `.claude/**` instead of the source store | H | M | Every phase names `agent-system/extensions/**` targets only; Phase 9 is the sole phase that runs a deploy |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 6, 7, 8 | 1 |
| 3 | 9 | 2, 3, 4, 5, 6, 7, 8 |
| 4 | 10 | 9 |

Phases within the same wave can execute in parallel. Phases 2-7 own disjoint file territories
(founder/skills, present/skills, lean/skills, cslib/skills, the three extensions' commands/, and
core) and may be dispatched concurrently. Phase 8 authors the lint against its own fixtures and
touches no conversion territory.

---

### Phase 1: Baseline inventory and conversion recipe [COMPLETED]

**Goal**: Establish a machine-checkable before-state so every later phase can prove its own
delta, and fix the exact conversion recipe once so six phases do not each invent their own.

**Tasks**:
- [x] Run the full-source-store grep and record per-file matching-line counts to a baseline
      record under the task directory. *(completed: 109 matching lines, baseline/01_grep-baseline-and-recipe.md)*
- [x] Classify every hit as CONVERT or EXCLUDE, reproducing the exclusion table from this plan's
      Scope Boundary Resolution with the concrete grep line as evidence for each exclusion.
      *(completed)*
- [x] Write the canonical conversion recipe as a short reference block in the baseline record,
      copying the shapes from `skill-status-sync` (status update, artifact append) and
      `skill-researcher` (`--argjson num "$task_number"`), including: bind the task number with
      `--argjson`, never string-interpolate it; one existing site becomes exactly one
      `state-write.sh` call; add `--regen-todo` only where the site already regenerated TODO.md.
      *(completed)*
- [x] Record the bash-fence extraction command each conversion phase will use for its `bash -n`
      pass over edited markdown. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: Planning-time re-measurement found these matching-line counts:
founder/skills 37, present/skills 17, lean/skills 10, cslib/skills 5, founder/commands 11,
present/commands 10, epidemiology/commands 2, core 13 (of which most are excludable). The
research report independently reported founder/commands as 10, not 11 — the discrepancy is a
line-vs-site artifact (`consult.md` has one site spanning two grep-matching lines). This phase
must re-run the grep and record the actual per-file numbers; every downstream phase confirms
against this record, not against the numbers written in this plan.

**Files to modify**:
- `specs/995_convert_extension_state_writers_to_state_write/` - baseline inventory record (new)

**Verification**:
- The baseline record enumerates every grep hit with a CONVERT/EXCLUDE verdict and no
  unclassified remainder.

---

### Phase 2: Convert founder/skills [COMPLETED]

**Goal**: Every hand-rolled write in the 15 founder skill files routes through `state-write.sh`.

**Tasks**:
- [x] For each of the 15 `SKILL.md` files, replace each hand-rolled write with one
      `state-write.sh` call per Phase 1's recipe. *(completed)*
- [x] Preserve each site's `--arg`/`--argjson` bindings and filter semantics exactly; convert
      string-interpolated `'$task_number'` to `--argjson num "$task_number"`. *(completed)*
- [x] Leave each site's TODO.md handling untouched unless it already regenerated TODO.md.
      *(completed)*
- [x] Extract bash fences from every edited file and run `bash -n` over each. *(completed: all
      state-write.sh fences pass; whole-file fence concatenation hits pre-existing, unrelated
      prose fences elsewhere in these files — e.g. an intentionally-truncated illustrative git
      commit message example — so verification was scoped to the fences this phase edited)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 15 files / 37 matching lines (`skill-finance`, `skill-strategy`,
`skill-deck-research`, `skill-deck-implement`, `skill-deck-plan`, `skill-project`,
`skill-consult`, `skill-financial-analysis`, `skill-meeting`, `skill-founder-implement`,
`skill-market`, `skill-legal`, `skill-founder-plan`, `skill-analyze`,
`skill-founder-spreadsheet`). Confirm against Phase 1's record before starting and re-grep the
directory after; the two-line-per-site artifact means site count may be lower than 37.

**Files to modify**:
- `agent-system/extensions/founder/skills/*/SKILL.md` - hand-rolled writes replaced with `state-write.sh` calls

**Verification**:
- `grep -rn 'mv .*state\.json\|state\.json > \|> .*state\.tmp' agent-system/extensions/founder/skills/`
  returns zero.
- `bash -n` passes on every extracted fence from every edited file.

---

### Phase 3: Convert present/skills [NOT STARTED]

**Goal**: Every hand-rolled write in the 5 present skill files routes through `state-write.sh`.

**Tasks**:
- [ ] Convert each site in the 5 `SKILL.md` files per Phase 1's recipe.
- [ ] Preserve bindings and filter semantics; leave TODO.md handling untouched.
- [ ] Extract bash fences from every edited file and run `bash -n` over each.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 5 files / 17 matching lines (`skill-slides`, `skill-budget`,
`skill-timeline`, `skill-grant`, `skill-funds`). Confirm against Phase 1's record; re-grep after.

**Files to modify**:
- `agent-system/extensions/present/skills/*/SKILL.md` - hand-rolled writes replaced with `state-write.sh` calls

**Verification**:
- Directory-scoped grep returns zero.
- `bash -n` passes on every extracted fence.

---

### Phase 4: Convert lean/skills [NOT STARTED]

**Goal**: Every hand-rolled write in the 4 lean skill files routes through `state-write.sh`.

**Tasks**:
- [ ] Convert each site in the 4 `SKILL.md` files per Phase 1's recipe.
- [ ] Confirm the hard-mode variants (`-hard` skills) keep their own stage semantics unchanged.
- [ ] Extract bash fences from every edited file and run `bash -n` over each.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 4 files / 10 matching lines (`skill-lean-research`,
`skill-lean-research-hard`, `skill-lean-implementation`, `skill-lean-implementation-hard`).
Confirm against Phase 1's record; re-grep after.

**Files to modify**:
- `agent-system/extensions/lean/skills/*/SKILL.md` - hand-rolled writes replaced with `state-write.sh` calls

**Verification**:
- Directory-scoped grep returns zero.
- `bash -n` passes on every extracted fence.

---

### Phase 5: Convert cslib/skills (individually reviewed) [NOT STARTED]

**Goal**: Convert all 5 cslib sites, each reviewed individually, and fix the hardcoded
absolute-path bug as part of its site's conversion.

**Tasks**:
- [ ] `skill-pr-implementation/SKILL.md`: drop `CSLIB_DIR`/`CSLIB_STATE` entirely and write the
      project-relative `specs/state.json`, matching the same file's own earlier
      `update-task-status.sh preflight` call. Do NOT carry the absolute path into a
      `--state-file` argument.
- [ ] `skill-pr-review-implementation/SKILL.md`: convert the `/tmp/state.tmp` site.
- [ ] `skill-pr-review-research/SKILL.md`: convert the `/tmp/state.tmp` site.
- [ ] `skill-cslib-vet/SKILL.md`: convert the task-creation site (prepends to `.active_projects`,
      bumps `next_project_number`); confirm the read-modify-write stays within one
      `state-write.sh` call so the bump is serialized.
- [ ] `skill-cslib-research-hard/SKILL.md`: convert the `specs/tmp/state.json` site.
- [ ] MUST NOT batch find/replace across these files — each site is reviewed and edited on its
      own.
- [ ] Extract bash fences from every edited file and run `bash -n` over each.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 5 files / 5 matching lines, three distinct staging-path variants
(`/tmp/state.tmp` x2, `specs/state.json.tmp`, `specs/tmp/state.json`) plus one `$CSLIB_STATE`
variable-indirected site. Confirm against Phase 1's record; a regex re-grep alone will NOT prove
the `$CSLIB_STATE` site is gone — confirm that one by reading the file.

**Files to modify**:
- `agent-system/extensions/cslib/skills/skill-pr-implementation/SKILL.md` - drop hardcoded absolute path, convert to `state-write.sh`
- `agent-system/extensions/cslib/skills/skill-pr-review-implementation/SKILL.md` - convert `/tmp/state.tmp` site
- `agent-system/extensions/cslib/skills/skill-pr-review-research/SKILL.md` - convert `/tmp/state.tmp` site
- `agent-system/extensions/cslib/skills/skill-cslib-vet/SKILL.md` - convert task-creation site
- `agent-system/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md` - convert staged-temp site

**Verification**:
- Directory-scoped grep returns zero.
- `grep -n 'CSLIB_DIR\|CSLIB_STATE' agent-system/extensions/cslib/skills/skill-pr-implementation/SKILL.md`
  returns zero.
- `bash -n` passes on every extracted fence.

---

### Phase 6: Convert commands/*.md task-creation sites [NOT STARTED]

**Goal**: Convert the task-creation writers in founder, present, and epidemiology `commands/`
— the scope expansion resolved in this plan's Scope Boundary Resolution.

**Tasks**:
- [ ] Convert the founder `commands/*.md` sites (`finance.md`, `strategy.md`, `deck.md`,
      `project.md`, `consult.md`, `analyze.md`, `meeting.md`, `market.md`, `legal.md`,
      `sheet.md`).
- [ ] Convert the present `commands/*.md` sites (`budget.md`, `slides.md`, `timeline.md`,
      `grant.md`, `funds.md`).
- [ ] Convert the epidemiology `commands/epi.md` sites.
- [ ] For each: the `next_project_number` bump and the `.active_projects` append MUST remain in
      one `state-write.sh` call, so the read-modify-write is serialized by one mutex acquisition.
- [ ] Preserve every existing field written into the new entry verbatim, including
      `forcing_data` — do NOT drop or rename fields to satisfy the schema (out of scope).
- [ ] Extract bash fences from every edited file and run `bash -n` over each.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 16 files / 23 matching lines (founder 10 files / 11 lines, present 5 files
/ 10 lines, epidemiology 1 file / 2 lines). The founder line count exceeds the file count because
`consult.md` has one site spanning two matching lines — confirm per-file against Phase 1's record
rather than assuming one site per file.

**Files to modify**:
- `agent-system/extensions/founder/commands/*.md` - task-creation writes converted
- `agent-system/extensions/present/commands/*.md` - task-creation writes converted
- `agent-system/extensions/epidemiology/commands/epi.md` - task-creation writes converted

**Verification**:
- Directory-scoped grep across all three `commands/` directories returns zero.
- `bash -n` passes on every extracted fence.

---

### Phase 7: Core residual — reviews state file and the doc example [NOT STARTED]

**Goal**: Remove the two core-extension residuals that the new lint would otherwise have to
carve out without justification.

**Tasks**:
- [ ] `core/commands/review.md`: convert both `specs/reviews/state.json` sites to
      `state-write.sh --state-file specs/reviews/state.json`, preserving the filters exactly.
      Confirm `--regen-todo` is NOT passed (it is refused with a non-default `--state-file`).
- [ ] `core/context/formats/command-structure.md`: replace the illustrative
      `jq ... specs/state.json > tmp.json && mv tmp.json specs/state.json` example with the
      `state-write.sh` shape, so the doc stops teaching the anti-pattern.
- [ ] Confirm the vault-rename, read-only-check, test-fixture, and prose hits identified in
      Phase 1 remain unconverted and are recorded as exclusions for Phase 8's list.
- [ ] Extract bash fences from both edited files and run `bash -n` over each.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 2 convertible sites in `review.md` (2 matching lines) and 1 doc example in
`command-structure.md` (2 matching lines). The remaining core hits are exclusions, not
conversions — confirm each against Phase 1's classification before touching anything under
`core/`.

**Files to modify**:
- `agent-system/extensions/core/commands/review.md` - two `specs/reviews/state.json` writes converted via `--state-file`
- `agent-system/extensions/core/context/formats/command-structure.md` - illustrative example updated to the sanctioned shape

**Verification**:
- Both files' grep hits are gone or reclassified as exclusions with evidence.
- `bash -n` passes on every extracted fence.

---

### Phase 8: Author lint-state-writer-boundary.sh and its fixture test [NOT STARTED]

**Goal**: A standalone lint that detects hand-rolled state-file writes across the source store,
with pass/fail fixtures, authored against fixtures and not yet wired.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh`, following
      the structure of `lint-postflight-boundary.sh` (the closest content-pattern lint precedent):
      same `--verbose`/`--quiet` flag handling, same pass/fail reporting idiom, non-zero exit on
      any finding.
- [ ] Detection basis: `jq`-staged writes onto any `state.json` across all three observed staging
      variants (`specs/tmp/state.json`, `specs/state.json.tmp`, `/tmp/state.tmp`) plus bare `mv`
      onto a `state.json` target.
- [ ] Encode the exclusion list from Phase 1's classification, each entry carrying an inline
      comment stating WHY it is exempt — never a bare path list.
- [ ] Document in the header comment, in the manner of `state-write.sh`'s own header, that a
      regex lint CANNOT catch a variable-indirected write (the `$CSLIB_STATE` class), so the lint
      is a guardrail against recurrence and not a proof of absence.
- [ ] Create `agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` with
      a fixture containing a hand-rolled write (must fail) and a clean fixture (must pass).
- [ ] `bash -n` both new scripts.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` - new lint
- `agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` - new fixture test

**Verification**:
- The fixture test passes: lint exits non-zero on the dirty fixture, zero on the clean fixture.
- `bash -n` passes on both scripts.

---

### Phase 9: Wire the lint (manifest, verify-deploy gate, deploy) [NOT STARTED]

**Goal**: The lint runs automatically where the other repo lints run, and is present in the
deployed tree.

**Tasks**:
- [ ] Add `lint/lint-state-writer-boundary.sh` and `tests/test-lint-state-writer-boundary.sh` to
      `core/manifest.json`'s `provides.scripts`, alongside the four existing lint entries.
- [ ] Add gate 12 to `verify-deploy.sh` immediately after gate 11
      (`lint-contract-compliance.sh`), using the established `say "12. ..."` / `fail "<message>"
      "<remediation hint>"` idiom and the same source-store-vs-deploy-consumer `[SKIP]` posture
      the sibling lint gates use.
- [ ] Run the deploy so `.claude/scripts/lint/` receives the new lint. Do NOT hand-author
      anything under `.claude/**`.
- [ ] Run the lint against the real, fully-converted tree; it must pass.
- [ ] Run `verify-deploy.sh` end to end; all gates including the new gate 12 must pass.

**Timing**: 1 hour

**Depends on**: 2, 3, 4, 5, 6, 7, 8

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: 2 manifest entries and 1 new gate block in `verify-deploy.sh`, whose gate
numbering currently tops out at 11. Confirm the highest existing gate number by reading
`verify-deploy.sh` before inserting, rather than assuming 11 is still the maximum.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - two new `provides.scripts` entries
- `agent-system/extensions/core/scripts/verify-deploy.sh` - new gate 12

**Verification**:
- `verify-deploy.sh` passes end to end, including gate 12.
- The lint is present and executable at `.claude/scripts/lint/lint-state-writer-boundary.sh`
  after deploy.

---

### Phase 10: Verification bar [NOT STARTED]

**Goal**: Satisfy all three of the task's stated verification criteria and record the evidence.

**Tasks**:
- [ ] Full-source-store grep for a hand-rolled write outside `state-write.sh` returns zero,
      modulo the enumerated exclusion list — report the result WITH the exclusion list, never as
      an unqualified "zero hits".
- [ ] Dry-run smoke test: exercise one converted founder skill write path and one converted
      present skill write path via `state-write.sh --dry-run`, confirming the filter and bindings
      validate.
- [ ] Confirm the `$CSLIB_STATE` site by reading the file, not by grep, per the documented lint
      limitation.
- [ ] Re-run the lint fixture test (fails dirty, passes clean) and the full `verify-deploy.sh`.
- [ ] Record the two deferred follow-ups in the summary: the `base_branch`/`forcing_data` schema
      non-conformance, and any variable-indirected write class the lint cannot cover.

**Timing**: 0.75 hours

**Depends on**: 9

**Verification Tier**: full

**Scope Hypothesis**: The bar asserts a count of zero. That zero is a hypothesis until the grep
is actually run against the post-conversion tree AND every remaining hit is matched against the
Phase 1 exclusion classification. A hit not on that list is a failure, not a new exclusion.

**Files to modify**:
- `specs/995_convert_extension_state_writers_to_state_write/summaries/` - execution summary (new)

**Verification**:
- All three of the task's VERIFICATION BAR criteria demonstrably met, with the exclusion list
  stated alongside the grep result.

---

## Testing & Validation

- [ ] Per-extension directory grep returns zero after each conversion phase (Phases 2-7).
- [ ] `bash -n` passes on every bash fence extracted from every edited markdown file.
- [ ] `test-lint-state-writer-boundary.sh` passes: non-zero exit on the dirty fixture, zero on
      the clean fixture.
- [ ] `verify-deploy.sh` passes end to end, including the new gate 12.
- [ ] `state-write.sh --dry-run` validates one converted founder and one converted present write
      path.
- [ ] `skill-pr-implementation/SKILL.md` contains no `CSLIB_DIR`/`CSLIB_STATE` reference.
- [ ] Full-source-store grep returns zero modulo the enumerated, evidenced exclusion list.

## Artifacts & Outputs

- `specs/995_convert_extension_state_writers_to_state_write/plans/01_convert-extension-state-writers.md` (this file)
- Baseline inventory record under the task directory (Phase 1)
- ~46 edited files under `agent-system/extensions/{founder,present,lean,cslib,epidemiology,core}/`
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` (new)
- Updated `agent-system/extensions/core/manifest.json` and `verify-deploy.sh`
- Execution summary under `specs/995_convert_extension_state_writers_to_state_write/summaries/`

## Rollback/Contingency

Every conversion phase is an independent, per-extension commit with a disjoint file territory, so
a defective extension can be reverted alone without disturbing the others. If a converted skill
misbehaves at runtime, revert that extension's commit and re-run the deploy — the hand-rolled
sequence is restored verbatim and the skill returns to its prior (unserialized but working)
behavior.

If Phase 9's gate wiring red-lights `verify-deploy.sh` on a residual the exclusion list does not
cover, the correct response is to convert the residual or add an evidenced exclusion, NOT to
weaken the lint's detection pattern. If the residual cannot be resolved within this task, revert
only the gate-12 block in `verify-deploy.sh` (leaving the lint script and its test in place,
runnable manually), mark Phase 9 `[PARTIAL]`, and record the residual as a named follow-up.

`.claude/**` is a disposable deploy artifact — no rollback is needed there beyond re-running the
deploy from the reverted source store.
