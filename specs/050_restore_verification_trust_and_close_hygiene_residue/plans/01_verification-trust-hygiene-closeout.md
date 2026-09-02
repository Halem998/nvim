# Implementation Plan: Task #50

- **Task**: 50 - Restore verification trust and close hygiene residue
- **Status**: [NOT STARTED]
- **Effort**: 9 hours
- **Dependencies**: Task 48 (completed)
- **Research Inputs**: specs/050_restore_verification_trust_and_close_hygiene_residue/reports/01_hygiene-residue-remeasurement.md
- **Artifacts**: plans/01_verification-trust-hygiene-closeout.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan implements the *re-measured* bundle, not the filed one. The research report re-ran every
count against the current tree and found the bundle materially smaller than filed: two of six
original sub-items are already fully closed and are scheduled here only as a recorded closing
note, never as migration work. What remains is two open decisions (deploy-ordering
non-determinism; the live-cycle defect-acceptance bar) plus six mechanical hygiene items, one of
which — the doc-lint manifest-registration gap for three test scripts — is folded in from the
standing verify-deploy failures because it is on-theme and trivial.

The report explicitly recommends keeping this as one task in a two-phase shape (A: decisions and
verification; B: mechanical hygiene) rather than expanding it. This plan honours that shape:
phases 1–2 are Group A, phases 3–7 are Group B, and phase 8 is the closing gate run. Every edit
targets `agent-system/extensions/**` (the source store) or `specs/**`; nothing writes to
`.claude/**`.

**Scope note — one item included that the dispatch brief did not enumerate.** Phase 7
(`@.claude/docs` prose normalization, 15 occurrences across 8 files) appears in the research
report's own Phase B list and was **not** named as out of scope in the dispatch brief, but was
also not restated in the brief's remaining-scope list. It is confirmed live, cosmetic, zero-risk,
and file-disjoint from every other phase. It is planned here rather than silently dropped; if it
was deliberately excluded upstream, drop Phase 7 alone and nothing else changes.

### Research Integration

Findings carried directly into this plan:

- **Already closed, do not re-work** (report findings 1 and 2): the session-ID one-liner class was
  fully migrated by the archived duplication-gate task (all 37 `.md` + 1 `.sh` offenders; the 14
  remaining matches are deliberate library/test/illustrative-prose exclusions), and the jq #1132
  "duplication" is not duplication — only 2 files carry the real block (both canonical sources),
  the other 34 are already 1–4 line pointers. Phase 8 records both as verified-closed with the
  measurement commands as evidence; no file edits are scheduled for either.
- **Genuinely open** (report findings 7 and 8): `err_1786350581240_JyztWt` is still
  `fix_status: "unfixed"`, and its recorded "fold" into the orphan-file parity task provably never
  happened (that task closed two unrelated errors and has since archived) — a process finding as
  well as a technical one. The sibling error `err_1786350581208_23mAsn` was independently closed on
  a "semantically identical under `jq -S`, ordering only" rationale that was never generalized.
- **Counts are stale by construction** (report findings 5 and the Risks section): the topic-orphan
  list moved from 10 (filed) to 13 (research time) with four new names inside a single research
  pass. Phase 5 re-derives the list live and is forbidden from reusing either snapshot.
- **The ROADMAP deletion does not stick on its own** (report finding 6): `roadmap-integration.sh`
  auto-creates a fresh empty stub when the file is absent, so a bare `rm` leaves the file
  regenerating forever. The report classes the companion script change as required, not optional.
- **Evidence to weigh, not re-derive** (report finding 8): the sibling evidence-contributor task
  carries three dated evidence blocks that cut both ways on the acceptance bar; Phase 2 reads them
  and the capstone's own re-scoping precedent before settling wording.

### Prior Plan Reference

No prior plan exists for this task. Effort calibration is derived from the research report's
per-item findings rather than from a previous version.

### Roadmap Alignment

No roadmap phases are scheduled: `roadmap_flag` was not set in the delegation context, and this
task's Phase 4 deletes `specs/ROADMAP.md` by an already-recorded decision. The deletion is
implemented, not re-litigated.

## Goals & Non-Goals

**Goals**:

- Close `err_1786350581240_JyztWt` with an explicit, re-verified decision (fix the ordering
  non-determinism, or formally adopt `jq -S` semantic equality as the deploy-comparison standard),
  and record the never-performed-fold as a process finding.
- Settle the live-cycle defect-acceptance criterion in writing, in the place the acceptance
  criteria live, having read the sibling task's three dated evidence blocks and the capstone's own
  precedent for re-scoping an unverifiable criterion.
- Make `specs/ROADMAP.md`'s deletion stick, by teaching `roadmap-integration.sh` to treat absence
  as "no roadmap tracked" instead of "roadmap needs a stub", and registering that outcome in both
  calling commands' warning-code vocabularies.
- Put `literature-retrieve.sh` through the repository's established quarantine-never-delete
  convention and correct the one doc that still describes it as the live `--lit` mechanism.
- Close the three named documentation-truth gaps: `/zulip` + `skill-zulip` in the generated
  CLAUDE.md, and `check-runtime-file-tracking.sh` in the Utility Scripts inventory (as a
  dual-purpose operator-invoked *and* CI-gate entry, not a bare row).
- Reconcile `active_topics` against the live `TODO.md` topic usage, from a freshly derived list.
- Fix the doc-lint manifest-registration gap for three unregistered test scripts, clearing one of
  the three standing `verify-deploy.sh` failures.
- Leave a recorded, evidenced closing note for the two sub-items that are already resolved, so a
  future audit does not re-open them from stale prose.

**Non-Goals**:

- **The session-ID one-liner migration and the jq #1132 pointer conversion.** Both are already
  done. Scheduling either would be duplicate work; Phase 8 records them closed with evidence.
- **The non-deterministic shell test suite.** Extracted to its own task before this research began.
- **The `OFF_SCHEMA_STATUS` and `META_MISSING_AFTER_NARRATION` defects themselves.** Owned
  elsewhere. This task settles the *criterion*, never the individual defects.
- **`validate-state.sh --deep` schema drift** (`Unknown entry field: abandon_reason` on 7 tasks,
  `blocks_note` on 3). Confirmed live, **no owning task found**. Named here rather than silently
  absorbed or dropped; belongs with whatever owns `state-schema.json` maintenance, and a `/spawn`
  or fresh `/task` is warranted if no owner surfaces.
- **`test-force-phases.sh` state-writer-boundary violations** (4 `[VIOLATION]` lines from
  `lint-state-writer-boundary.sh --verbose`, all raw `jq … > specs/state.json.tmp && mv …` inside
  the test fixture). Confirmed live, **no owning task found**. Closer in nature to test-suite
  hygiene; may be legitimate exempted fixture code needing a documented exception rather than a
  fix. Named, not owned, here.
- **Any edit to `skill-base.sh`, `scripts/lint/`, or the base lifecycle skill directories**
  (`skill-researcher/`, `skill-planner/`, `skill-implementer/`) — two concurrent tasks hold those
  territories.
- **Any write to `.claude/**`.** The source store is `agent-system/extensions/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Topic and defect counts drift again between planning and implementation (they moved 3 items inside one research pass) | M | H | Phases 2, 5 and 8 re-run the exact derivation commands recorded in the report's Appendix; no phase may act on a number copied from this plan or the report |
| `roadmap-integration.sh` change regresses `/review` or `/todo` for a repo that still keeps a roadmap | H | L | Gate the new behavior on file absence only — a present, well-formed ROADMAP.md continues to parse and annotate byte-identically; Phase 4 verifies with a present-file fixture as well as an absent-file one |
| `test-roadmap-argv-ceiling.sh` copies `roadmap-integration.sh` byte-for-byte and asserts a structural marker (`# ─── Build output JSON ───…`) is present | M | M | Insert the absent-file branch *before* that marker and never touch the marker line; re-run the suite in Phase 4 |
| Removing `literature-retrieve.sh` from `provides.scripts` breaks a caller the report's 138-script analysis missed | M | L | The three known mentions are all comments/docs, not invocations; Phase 3 re-greps for invocation forms specifically before moving, and the quarantine convention is move-not-delete so the file remains recoverable in place |
| Deleting `specs/ROADMAP.md` breaks a gate or script that assumes its presence | M | L | Phase 4 greps for every reader of the path before deleting, and Phase 8's full gate run is the backstop |
| The acceptance-bar wording lands as unfalsifiable prose ("no unexplained increase") that no one can check | M | M | Phase 2 must state, alongside the criterion, the concrete command that evaluates it and what a failing evaluation looks like; a criterion with no evaluation procedure repeats the exact defect it is replacing |
| Concurrent sessions hold locks on `specs/state.json` during Phase 5 | L | M | Route the `active_topics` change through `manage-topics.sh`/`state-write.sh` (the mutex-guarded writer), never a raw `jq … > tmp && mv` |
| Scope creep pulls the two named out-of-scope verify-deploy failures back in | M | M | Non-Goals names both explicitly with their measured evidence; Phase 8 asserts they are still failing and still unowned rather than fixing them |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4, 5, 6, 7 | -- |
| 2 | 8 | 1, 2, 3, 4, 5, 6, 7 |

Phases within the same wave can execute in parallel. Wave 1's seven phases hold pairwise-disjoint
file territories (verified at plan time), so parallel dispatch is safe:

| Phase | Territory |
|-------|-----------|
| 1 | `specs/errors.json`; a scratch deploy target outside the repo tree |
| 2 | `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` |
| 3 | `agent-system/extensions/core/manifest.json`; `core/scripts/literature-retrieve.sh` -> `core/scripts/deprecated/`; `literature/context/guides/literature-organization.md` |
| 4 | `core/scripts/roadmap-integration.sh`; `core/commands/review.md`; `core/commands/todo.md`; `specs/ROADMAP.md` |
| 5 | `specs/state.json` (`active_topics` only) |
| 6 | `core/merge-sources/claudemd.md`; `core/docs/reference/utility-scripts-inventory.md` |
| 7 | 8 markdown files carrying `@.claude/docs` prose references |

---

### Phase 1: Re-run the deploy wipe-pair and settle the ordering non-determinism [NOT STARTED]

**Goal**: Establish, against the *current* tree rather than the 2026-08-10 run, whether two
identical `deploy-headless.sh --wipe` runs still differ only by object-key/array-element ordering
and the expected generated timestamp — then either fix the non-determinism or formally record
`jq -S` semantic equality as the standard, and close `err_1786350581240_JyztWt` either way.

**Tasks**:
- [ ] Read `err_1786350581240_JyztWt` and its already-closed sibling `err_1786350581208_23mAsn`
      from `specs/errors.json`. Note that the sibling's own `message` field already records the
      resolving rationale ("sorted-key diffs are empty (settings.json) or differ only in the
      generated timestamp (index.json), i.e. structurally/semantically identical, ordering only")
      — this is the precedent to apply or refute, not to re-derive.
- [ ] Run the wipe-pair procedure against a scratch target directory (never the live `.claude/`):
      two consecutive `deploy-headless.sh --wipe` runs into two separate scratch roots, from an
      unchanged source store.
- [ ] For each pair, compare `context/index.json` and `settings.json` in three ways: raw `diff`,
      `jq -S . a > /tmp/a.s; jq -S . b > /tmp/b.s; diff /tmp/a.s /tmp/b.s`, and a timestamp-stripped
      sorted diff. Record all three outcomes verbatim.
- [ ] Re-check the `settings.local.json` content-loss observation specifically (the sibling error's
      original single-observation finding) and record whether it reproduces.
- [ ] Repeat the pair at least twice more (3 pairs total) so a single observation cannot decide the
      outcome — this mirrors the 3-pair methodology the sibling error was closed on.
- [ ] **Decide and record**: if the diffs are ordering-only under `jq -S`, write the explicit
      decision that semantic equality under `jq -S` is the deploy-comparison standard and
      byte-identity is not required, generalizing the sibling's precedent to this ticket. If a
      genuine content difference reproduces, do NOT close the error — record the reproduction and
      mark the phase `[PARTIAL]` with the finding.
- [ ] Update `err_1786350581240_JyztWt` in `specs/errors.json`: set `fix_status`, `fixed_date`, and
      `fix_task`, and extend `message` with the re-measured evidence (pair count, the three diff
      forms, the decision taken).
- [ ] Record the **process finding** in the same `message`: the ledger disposition folded this
      error into the orphan-file parity task, that task closed two unrelated errors and has since
      archived without ever touching ordering or content loss, so a recorded fold was never
      performed. State it as a ledger-hygiene finding, not only a technical one.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts that exactly one error entry (`err_1786350581240_JyztWt`)
remains `unfixed` in this family and that its sibling is already `fixed`. Confirm at implementation
time with `jq -r '.errors[] | select(.type=="deploy_nondeterministic_merge" or .type=="deploy_merge_content_loss") | {id,fix_status}' specs/errors.json`
before editing; if a third entry has appeared, widen the phase rather than editing only the named one.

**Files to modify**:
- `specs/errors.json` — close (or explicitly decline to close) `err_1786350581240_JyztWt` with the
  re-measured evidence and the process finding

**Verification**:
- Three wipe-pairs executed, with all three diff forms recorded for each
- `jq empty specs/errors.json` passes
- `jq -r '.errors[] | select(.id=="err_1786350581240_JyztWt") | .fix_status' specs/errors.json`
  returns a decided value, and the `message` names both the diff evidence and the never-performed
  fold
- No write occurred inside the live `.claude/` tree (confirm the scratch target path in the command
  history)

---

### Phase 2: Re-scope and record the live-cycle defect-acceptance criterion [NOT STARTED]

**Goal**: Replace the unverifiable "zero `system_defect` events on a clean run" bar with a
criterion that is both sound against the observed evidence and mechanically evaluable, and record
it where the acceptance criteria live.

**Tasks**:
- [ ] Re-derive the current event census rather than trusting any recorded number:
      `grep 'system_defect' specs/events.jsonl | jq -r '.detail.defect_class' | sort | uniq -c`.
      Record the live counts and class list in the criterion's own evidence block.
- [ ] Read the sibling evidence-contributor task's **three dated evidence blocks** in
      `specs/TODO.md` (the original filing plus the two `EVIDENCE ADDED` blocks) before drafting
      any wording. That task is written as a contributor to this decision, not merely a sibling.
      Weigh both directions it establishes:
      *for* relaxing — a clean, fully-successful base-mode run recorded a defect for expected,
      correct non-writer behavior (a recorder firing where nothing went wrong);
      *against* relaxing carelessly — two independent live clobber incidents where the single
      defect event was the only signal distinguishing a predecessor clobber from a normal report.
- [ ] Read the capstone's own precedent for re-scoping an unverifiable criterion in
      `specs/reviews/review-2026-08-10-agent-system-refactor-capstone.md` (the
      UNVERIFIABLE-AS-WRITTEN gate-out item, which states the criterion may be amended to something
      checkable rather than waiting on new instrumentation). Match its framing.
- [ ] Draft the criterion. The report's recommended shape is: *no new defect classes on a clean
      run, AND no unexplained increase in a known class's firing rate absent a corresponding real
      incident.* A pure "no new classes" bar is under-specified against the clobber evidence and
      must not be adopted alone.
- [ ] **State the evaluation procedure alongside the criterion** — the concrete command that
      computes the class set and per-class rate, what the baseline is compared against, and what a
      failing evaluation looks like. A criterion with no evaluation procedure reproduces the exact
      defect being replaced.
- [ ] Add the decision as a new section in
      `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — the
      existing home of the system-defect predicate, signal vocabulary, and recursion/deduplication
      rules. Cross-reference the existing "Extending the Signal A vocabulary is an explicit
      decision" section, whose deliberate-extension posture the "no new classes" half depends on.
- [ ] Record explicitly, inside the new section, that the two individually-owned defect classes are
      out of scope for this decision and remain owned elsewhere — so the criterion is not read as
      having dispositioned them.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: The report measured 13 `system_defect` events across 4 classes. This is a
hypothesis, not a fact — re-run the `uniq -c` census above at implementation time and write the
live numbers into the criterion's evidence block. If the class count has moved, the criterion's
wording still holds but its evidence block must reflect the live census.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — add the
  acceptance-criterion decision section with its evidence block and evaluation procedure

**Verification**:
- The new section names the criterion, its evaluation command, its failure condition, and the live
  event census with the date it was taken
- The section cites both directions of the sibling task's evidence, not only the relaxing one
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` shows no new failures
- The diff is confined to markdown prose (Verification Tier `prose` read-through)

---

### Phase 3: Quarantine `literature-retrieve.sh` and close the manifest-registration gap [NOT STARTED]

**Goal**: Put the deprecated script through the repository's established quarantine-never-delete
convention, correct the one doc that still presents it as the live `--lit` mechanism, and register
the three unregistered test scripts so the doc-lint gate goes green on this count.

**Tasks**:
- [ ] Before moving, re-confirm the script is invocation-dead: grep for invocation forms
      specifically (`bash .*literature-retrieve`, `\./.*literature-retrieve`,
      `literature-retrieve\.sh [^ ]`) across `agent-system/extensions/`, not just name mentions.
      The three known mentions are a doc guide, a `check-extension-docs.sh` comment, and a
      `lib/common.sh` comment — all prose, none an invocation.
- [ ] `git mv agent-system/extensions/core/scripts/literature-retrieve.sh
      agent-system/extensions/core/scripts/deprecated/` — move, never delete, matching the
      convention the existing quarantine population already follows.
- [ ] Remove the `"literature-retrieve.sh",` line from `provides.scripts` in
      `agent-system/extensions/core/manifest.json` so it stops deploying. Validate the JSON
      (`jq empty`) immediately after.
- [ ] Add the three on-disk-but-unregistered test scripts to the same `provides.scripts` array:
      `scripts/test-state-write-large-payload.sh`, `scripts/tests/test-force-phases.sh`,
      `scripts/tests/test-roadmap-argv-ceiling.sh`. Match the surrounding entries' path-prefix
      convention exactly (inspect neighbouring entries before writing — do not assume).
- [ ] Update `agent-system/extensions/literature/context/guides/literature-organization.md`: the
      flow description stating that the skill's preflight calls
      `literature-retrieve.sh <task_description> <task_type>` is stale — the current mechanism is
      `literature-briefing.sh`, per the Literature Mode contract and the Stage 4a flow file. Correct
      the flow description and the two other references that present the script as live.
- [ ] Confirm `check-extension-docs.sh`'s comment that name-checks `literature-retrieve.sh` as a
      legitimate cross-extension mention still resolves correctly against the new
      `scripts/deprecated/` location; adjust the comment if it names the old path.
- [ ] Append a line to `agent-system/extensions/core/scripts/deprecated/README.md` recording the
      new quarantine entry and its supersession reason, matching the existing entries' format.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts (a) exactly one script to quarantine, (b) exactly three
unregistered test scripts, and (c) a pre-existing quarantine population of 10 across the two
`deprecated/` directories. Confirm each at implementation time:
`bash .claude/scripts/check-extension-docs.sh 2>&1 | grep 'NOT in provides.scripts'` must list
exactly the three named scripts and no others — if it lists more, register all of them and say so;
if fewer, note which were registered in the interim.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` — remove one `provides.scripts` entry, add three
- `agent-system/extensions/core/scripts/literature-retrieve.sh` — moved to `scripts/deprecated/`
- `agent-system/extensions/core/scripts/deprecated/README.md` — record the new quarantine entry
- `agent-system/extensions/literature/context/guides/literature-organization.md` — correct the
  stale live-mechanism description
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — only if its comment names the
  pre-move path

**Verification**:
- `jq empty agent-system/extensions/core/manifest.json` passes
- `bash .claude/scripts/check-extension-docs.sh` no longer reports the three
  `NOT in provides.scripts` failures
- `grep -rn 'literature-retrieve' agent-system/extensions/` returns only the quarantined file
  itself, the `deprecated/README.md` entry, and comment-only mentions — no doc presents it as live
- The moved file exists at `core/scripts/deprecated/literature-retrieve.sh` and is absent from
  `core/scripts/`

---

### Phase 4: Make the ROADMAP deletion stick [NOT STARTED]

**Goal**: Change `roadmap-integration.sh` so an absent roadmap means "no roadmap tracked" rather
than "roadmap needs a stub", register that outcome in both calling commands' warning-code
vocabularies, and then delete `specs/ROADMAP.md`.

**Tasks**:
- [ ] Locate the auto-create block in `agent-system/extensions/core/scripts/roadmap-integration.sh`
      (the `if [[ ! -f "$ROADMAP_PATH" ]]` branch that emits
      `Note: ROADMAP.md not found …, creating default template` and heredocs a stub).
- [ ] Replace the auto-create with an early, well-formed skip: emit the same empty-state payload
      shape the callers' fallback branches already construct
      (`{"phases":[],"status_tables":[]}`, `[]` matches, `annotations_made: 0`,
      `{"phases":0,"checkboxes":0,"table_rows":0,"parseable":false}` structure, `items_skipped: 0`,
      `[]` skipped reasons, `high_confidence_matches: 0`, `silent_noop: false`), plus a new stable
      warning code `roadmap_absent` in the existing `warnings` array. Exit 0 — absence is a
      supported state, not a failure.
- [ ] Insert the branch **before** the `# ─── Build output JSON ───…` marker line and leave that
      line byte-identical: `test-roadmap-argv-ceiling.sh` copies the script and asserts the marker
      is present, failing loudly with "marker not found — roadmap-integration.sh structure changed"
      if it moves or changes.
- [ ] Update the script's own header comment block, which documents the `warnings` array as
      "stable string codes", to include `roadmap_absent` alongside `unparseable_roadmap` and
      `annotation_noop`.
- [ ] Register `roadmap_absent` in the warning-code `case` statement in
      `agent-system/extensions/core/commands/review.md` so it prints a specific, informative message
      rather than falling through to the `unrecognized warning code` catch-all.
- [ ] Do the same in `agent-system/extensions/core/commands/todo.md`, whose parse-only invocation
      and completed-task annotation path share the same vocabulary.
- [ ] Grep for every reader of the `specs/ROADMAP.md` path across `agent-system/extensions/` and
      `specs/` before deleting; confirm each either skips gracefully or is one of the two commands
      updated above.
- [ ] `git rm specs/ROADMAP.md`.
- [ ] Verify the deletion sticks: run `roadmap-integration.sh` in parse-only mode against the now-
      absent path and confirm it exits 0, emits `roadmap_absent`, and **does not recreate the file**
      (`test ! -f specs/ROADMAP.md` after the run).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` — replace auto-create with skip +
  `roadmap_absent` warning code; update the header's warning-code documentation
- `agent-system/extensions/core/commands/review.md` — register `roadmap_absent` in the warning
  `case`
- `agent-system/extensions/core/commands/todo.md` — register `roadmap_absent` in the warning `case`
- `specs/ROADMAP.md` — deleted

**Verification**:
- `bash -n agent-system/extensions/core/scripts/roadmap-integration.sh` passes
- Absent-file run: exits 0, output is valid JSON (`jq empty`), `warnings` contains
  `roadmap_absent`, and `specs/ROADMAP.md` still does not exist afterward
- Present-file run against a temporary fixture roadmap: parses and annotates exactly as before —
  the enumerated one-hop dependents (`review.md`, `todo.md`) see no behavioral change on the
  present-file path
- `bash agent-system/extensions/core/scripts/tests/test-roadmap-argv-ceiling.sh` passes (all three
  cases, including the marker assertion)
- Neither command's warning handler reports `unrecognized warning code: roadmap_absent`

---

### Phase 5: Reconcile the topic taxonomy [NOT STARTED]

**Goal**: Prune `active_topics` of declared-but-unused entries, working from a list derived live at
implementation time.

**Tasks**:
- [ ] **Re-derive the orphan list from scratch. Do not reuse the filed 10-item list or the research
      report's 13-item snapshot** — the two disagree by four names, and three items moved status
      inside a single research pass. Run:
      `comm -23 <(jq -r '.active_topics[]' specs/state.json | sort -u) <(grep -oP '(?<=\*\*Topic\*\*: )\S+' specs/TODO.md | sort -u)`
- [ ] Also re-derive the used-but-undeclared side (`comm -13` with the same operands) and confirm it
      is still empty; if it is not, add the missing topics — an undeclared live topic makes
      `generate-task-order.sh` fall through to its append-extras path with a stderr warning.
- [ ] For each orphan, check `specs/archive/state.json` before pruning: a topic whose only users are
      archived/completed tasks is a safe prune; a topic that is orphaned only because its task is
      momentarily between states is not. Record which category each fell into.
- [ ] Prune the safe orphans from `active_topics`. Route the write through the mutex-guarded state
      writer (`state-write.sh`, which `manage-topics.sh` already uses) — never a raw
      `jq … > specs/state.json.tmp && mv …`, which is the exact pattern
      `lint-state-writer-boundary.sh` polices.
- [ ] Note that `manage-topics.sh` exposes only `list`/`add`/`set`/`validate` — there is no `remove`
      subcommand. Either add one (preferred: it keeps the encapsulation the script's own header
      claims, and future prunes get a tool) or perform the prune through `state-write.sh` directly
      and record why no subcommand was added.
- [ ] Regenerate the rendered view: `bash .claude/scripts/generate-todo.sh`.
- [ ] Record the before/after topic lists and the per-topic prune rationale for the phase's commit
      message and the eventual summary.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The report measured 13 declared-but-unused topics and 0 used-but-undeclared,
naming four orphans that were absent from the filed list. Treat both numbers as stale. The `comm`
derivation above is the authority at implementation time; state the live count in the commit
message and flag any divergence from 13 rather than silently reconciling to it.

**Files to modify**:
- `specs/state.json` — `active_topics` array only
- `specs/TODO.md` — regenerated, not hand-edited
- `agent-system/extensions/core/scripts/manage-topics.sh` — only if a `remove` subcommand is added

**Verification**:
- `bash agent-system/extensions/core/scripts/validate-state.sh` passes (note: `--deep` has two
  pre-existing, explicitly out-of-scope failures — assert those are the *only* `--deep` failures,
  and that this phase added none)
- The `comm -23` derivation returns empty (or only entries with a recorded keep-rationale)
- The `comm -13` derivation returns empty
- `generate-task-order.sh` emits no append-extras stderr warning
- No raw state-file write occurred: `bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh --verbose`
  reports no new violations beyond the pre-existing, out-of-scope test-fixture ones

---

### Phase 6: Close the CLAUDE.md and utility-inventory documentation gaps [NOT STARTED]

**Goal**: Make `/zulip`, `skill-zulip`, and `check-runtime-file-tracking.sh` visible in the
generated documentation, so a future dead-code sweep does not flag live machinery as orphaned.

**Tasks**:
- [ ] Add a `/zulip` row to the Command Reference table in
      `agent-system/extensions/core/merge-sources/claudemd.md`, matching the surrounding rows'
      three-column shape and terseness. Source the usage and description from
      `core/commands/zulip.md` rather than inventing them.
- [ ] Add a `skill-zulip` row to the Skill-to-Agent Mapping table in the same file. The skill is
      direct-execution (it has a `SKILL.md` and no dedicated agent), so the Agent column reads
      `(direct execution)`, matching `skill-fix-it` and `skill-project-overview`.
- [ ] Add `check-runtime-file-tracking.sh` to
      `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`, matching the
      existing entries' `` `.claude/scripts/NAME` - description `` bullet format.
- [ ] **Write that entry as dual-purpose, not as a bare row.** Its five documented siblings are
      described as operator-invoked-only with no automated caller; this one is different — it is
      already wired in as a mandatory CI gate. The entry must say both: what an operator invokes it
      for, and that it runs as a `verify-deploy.sh` gate. Confirm the gate number live against
      `verify-deploy.sh` before writing it into the text rather than copying a remembered number.
- [ ] Confirm the inventory's own preamble claim — "Every entry below is unchanged from the original
      list — none was dropped or summarized away" — still reads correctly with an entry added that
      was never in the original CLAUDE.md list; adjust the preamble if the addition makes it false.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts `/zulip` and `skill-zulip` have zero mentions in the
CLAUDE.md merge source and `check-runtime-file-tracking.sh` has zero mentions in the inventory.
Re-confirm with `grep -c zulip agent-system/extensions/core/merge-sources/claudemd.md` and
`grep -c check-runtime-file-tracking agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`
(both expected `0`) before adding, so a concurrent addition is not duplicated.

**Files to modify**:
- `agent-system/extensions/core/merge-sources/claudemd.md` — one Command Reference row, one
  Skill-to-Agent Mapping row
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — one dual-purpose
  entry

**Verification**:
- `grep -c zulip agent-system/extensions/core/merge-sources/claudemd.md` returns a non-zero count,
  with both a Command Reference row and a Skill-to-Agent Mapping row present
- The inventory entry names both the operator use and the CI-gate role, with the gate number
  verified against `verify-deploy.sh`
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no new failures
- Markdown tables still render (column counts match their headers)

---

### Phase 7: Normalize `@.claude/docs` prose references [NOT STARTED]

**Goal**: Convert `@.claude/docs/...` prose citations to plain backticked paths, so the files stop
modelling the `@`-import syntax that the context-loading normalization removed everywhere else.

**Tasks**:
- [ ] Re-derive the occurrence list: `grep -rn '@\.claude/docs' agent-system/extensions/`. Do not
      work from this plan's count.
- [ ] For each occurrence, confirm it is a **prose citation**, not a live `@`-import in a context or
      rule file whose loader actually resolves `@` syntax. A genuine import must not be converted —
      if any is found, leave it and record it as a named residual rather than forcing the change.
- [ ] Convert each prose citation from `@.claude/docs/path/file.md` to `` `.claude/docs/path/file.md` ``,
      preserving the surrounding sentence.
- [ ] Confirm each cited path still exists on disk; a citation that is both stylistically wrong and
      broken should be fixed on both counts, and a broken one flagged if the target is genuinely
      gone.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: The report measured 15 occurrences across 8 files — 4 files named in the
original description plus 3 `cslib` agent files and one `core/docs/` file it did not name. This is a
hypothesis. Re-run the grep at implementation time; if the file set differs, convert what is
actually there and state the live count in the commit message.

**Files to modify** (re-derive; expected set at plan time):
- `agent-system/extensions/core/agents/meta-builder-agent.md`
- `agent-system/extensions/core/context/architecture/system-overview.md`
- `agent-system/extensions/core/context/architecture/component-checklist.md`
- `agent-system/extensions/core/context/patterns/thin-wrapper-skill.md`
- `agent-system/extensions/core/docs/fork-patterns.md`
- `agent-system/extensions/cslib/agents/cslib-research-agent.md`
- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md`
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`

**Verification**:
- `grep -rn '@\.claude/docs' agent-system/extensions/` returns nothing, or only occurrences
  recorded as named residuals with a stated reason
- Every diff hunk lies inside prose (Verification Tier `prose` read-through) — no change crosses
  into a frontmatter key, a code block, or a live import directive
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` passes (four of the
  eight files are agent contracts)

---

### Phase 8: Closing verification, closed-item notes, and the full gate run [NOT STARTED]

**Goal**: Run the complete gate set, record the two already-resolved sub-items as verified-closed
with evidence, and assert the two out-of-scope failures are still present and still unowned rather
than silently absorbed.

**Tasks**:
- [ ] Run `bash .claude/scripts/verify-deploy.sh` (or the source-store equivalent) end-to-end and
      record the per-gate result. The doc-lint gate must now pass on the three test scripts
      (Phase 3's work).
- [ ] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh` and record the result. Note
      that this suite is known non-deterministic under concurrency and is owned by a separate task —
      report the result honestly, and do not treat a flaky failure as this task's regression without
      first re-running and comparing.
- [ ] Re-run the two already-resolved items' measurement commands and record their output as the
      closing evidence:
      `grep -rl 'sess_$(date' agent-system/extensions/ | wc -l` (expected: only library, test, and
      illustrative-prose sites) and a check that only the two canonical sources carry the full jq
      #1132 block while the rest are pointers.
- [ ] Write both closed-item findings into the implementation summary with their commands and
      output, so a future audit reading the stale filed prose can see they were re-verified rather
      than assumed. If a defect-ledger entry asserts either as open, close it with this evidence.
- [ ] Re-run and record the two explicitly out-of-scope failures so their continued existence is
      documented, not implied:
      `bash agent-system/extensions/core/scripts/validate-state.sh --deep` (expected: the
      `abandon_reason` / `blocks_note` unknown-field failures) and
      `bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh --verbose`
      (expected: the `test-force-phases.sh` fixture violations). Confirm the counts are unchanged
      from the research baseline — an increase would mean this task caused it.
- [ ] Confirm no file under `.claude/**` was modified by any phase:
      `git status --short | grep '^.* \.claude/'` returns nothing attributable to this task.
- [ ] Confirm no task-number reference was introduced outside `specs/**`:
      `bash .claude/scripts/check-task-references.sh`.
- [ ] Write the implementation summary to
      `specs/050_restore_verification_trust_and_close_hygiene_residue/summaries/01_verification-trust-hygiene-closeout-summary.md`,
      naming every completed item, every recorded decision, both closed-with-evidence items, and
      both named-but-unowned residuals.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5, 6, 7

**Verification Tier**: full

**Files to modify**:
- `specs/050_restore_verification_trust_and_close_hygiene_residue/summaries/01_verification-trust-hygiene-closeout-summary.md`

**Verification**:
- Full `verify-deploy.sh` run recorded gate-by-gate; the doc-lint manifest-registration failures are
  gone; any remaining failures are exactly the two named out-of-scope ones plus anything the shell
  suite's known non-determinism accounts for
- `check-task-references.sh` passes
- No `.claude/**` modification attributable to this task
- The summary names all three categories explicitly: completed, closed-with-evidence, and
  named-but-unowned

---

## Testing & Validation

- [ ] `bash .claude/scripts/verify-deploy.sh` — full gate set, results recorded per gate
- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` — no
      `NOT in provides.scripts` failures for the three test scripts
- [ ] `bash agent-system/extensions/core/scripts/tests/test-roadmap-argv-ceiling.sh` — all cases
      pass, marker assertion intact
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` — result recorded, flakiness
      distinguished from regression by re-run
- [ ] `bash agent-system/extensions/core/scripts/validate-state.sh` — passes; `--deep` shows only
      the two pre-existing out-of-scope failures
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh --verbose` — no
      new violations
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — passes
- [ ] `bash .claude/scripts/check-task-references.sh` — passes
- [ ] `jq empty` on every modified JSON file (`core/manifest.json`, `specs/errors.json`,
      `specs/state.json`)
- [ ] `bash -n` on every modified shell script
- [ ] Absent-roadmap run of `roadmap-integration.sh` exits 0, warns `roadmap_absent`, and does not
      recreate the file
- [ ] Present-roadmap fixture run of `roadmap-integration.sh` behaves exactly as before

## Artifacts & Outputs

- `specs/050_restore_verification_trust_and_close_hygiene_residue/plans/01_verification-trust-hygiene-closeout.md` (this plan)
- `specs/050_restore_verification_trust_and_close_hygiene_residue/summaries/01_verification-trust-hygiene-closeout-summary.md` (Phase 8)
- Updated `specs/errors.json` — `err_1786350581240_JyztWt` dispositioned with re-measured evidence
- New acceptance-criterion section in `core/context/patterns/system-defect-discrimination.md`
- `core/scripts/deprecated/literature-retrieve.sh` (quarantined) and an updated
  `deprecated/README.md`
- Updated `core/manifest.json` (one entry removed, three added)
- Updated `core/scripts/roadmap-integration.sh`, `core/commands/review.md`, `core/commands/todo.md`
- `specs/ROADMAP.md` deleted
- Updated `specs/state.json` `active_topics` and regenerated `specs/TODO.md`
- Updated `core/merge-sources/claudemd.md` and `core/docs/reference/utility-scripts-inventory.md`
- Up to 8 markdown files with normalized `.claude/docs` path citations

## Rollback/Contingency

Every phase is independently revertible because the wave-1 territories are disjoint; a bad phase is
reverted with `git revert` of that phase's commit(s) without disturbing the others.

Per-item contingencies:

- **Phase 1**: if a genuine content difference reproduces across the wipe-pairs, do NOT close the
  error. Mark the phase `[PARTIAL]`, record the reproduction with all three diff forms, and leave
  `fix_status: "unfixed"` — a real reproduction is a finding worth more than a closed ticket.
- **Phase 3**: the quarantine is a move, not a delete, so restoring the script is a `git mv` back
  plus re-adding the `provides.scripts` line. If an unexpected invocation surfaces, restore rather
  than patching the caller.
- **Phase 4**: this is the highest-risk phase. If the absent-file skip regresses `/review` or
  `/todo`, revert the script change first — `specs/ROADMAP.md` can be restored from git history at
  any time, and its recreation is harmless while the script change is reverted. Do not delete the
  roadmap until the script change is verified green.
- **Phase 5**: the prior `active_topics` array is recoverable from git history; a wrongly pruned
  topic is re-added with `manage-topics.sh add`.
- **Phases 2, 6, 7**: documentation-only; revert is a plain `git revert` with no runtime effect.

If the task must be abandoned mid-flight, the phases that landed stand on their own — none depends
on a later phase to be coherent, and Phase 8's gate run is a report, not a mutation.
