# Implementation Plan: Migrate the orphaned H4 adversarial-verification gate and repair its false-negative matcher

- **Task**: 128 - Migrate the orphaned H4 adversarial-verification gate and repair its false-negative matcher
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: 119 (hard-mode state-machine consolidation — already landed; this plan builds on the acceptance-checklist and residue notes it wrote)
- **Research Inputs**: `specs/128_fix_h4_adversarial_gate_matcher/reports/01_fix-h4-adversarial-gate-matcher.md`
- **Artifacts**: plans/01_fix-h4-adversarial-gate-matcher.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The H4 adversarial-verification gate exists only in `skill-orchestrate-hard/SKILL.md`, an engine
slated for deletion, and its two `grep` checks both produce false negatives against genuinely
conforming research reports — burning one wasted research dispatch on every hard-mode run. This
plan ports the gate into the consolidated base engine `skill-orchestrate/SKILL.md` behind the
existing `$hard_mode` fork, lands the two empirically-corrected matcher patterns there rather
than transcribing the broken originals, closes out the base engine's own "Not migrated" / "Hard-mode
residue not yet migrated" notes, and records the deliberate co-maintenance asymmetry (base engine
fixed, `-hard` engine left untouched) in both engine files. Definition of done: the corrected gate
is live in the base engine's `researched` and `planning` handlers, both positive cases pass and
both negative cases still trip the gate when exercised against real files under the deployed grep,
and no engine file claims the gate is unmigrated.

### Research Integration

The research report is the sole substantive input and every one of its findings is load-bearing
here:

- **Both failures reproduced empirically** against `ugrep 7.8.4` (the grep actually deployed),
  not reasoned about. The heading check fails on `## 7. Adversarial Self-Verification`; the table
  check fails even on the canonical unnumbered header line, because the deployed POSIX/DFA `-E`
  engine mis-evaluates a `\b` anchor occurring downstream of an earlier `\b`-anchored
  subexpression separated by a `[^|]*` run.
- **Two corrected patterns, verified against all six required cases plus one regression check.**
  They are carried into this plan verbatim (see Phase 1) and MUST be copied from this plan into
  the engine file character-for-character, not re-derived.
- **`-P` (PCRE2) was evaluated and rejected** as the fix: it works, but introduces a new
  engine-flag dependency in a codebase whose every other `grep` call in both engines uses `-E`,
  and this code demonstrably runs on more than one machine.
- **Full migration site inventory** (Stage 2 init, two post-dispatch resets, two handler gate
  insertions, plus three documentation sites), each anchored by heading or verbatim surrounding
  text rather than line number, because the target file is under concurrent edit by sibling tasks
  in this same batch.
- **Co-maintenance asymmetry decision**: fix the base engine only; record the asymmetry in both
  files using this repo's existing "Asymmetry decision (recorded, not acted on)" convention.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` supplied).

### Batch Coordination

This plan is one of seven in a coordinated batch whose unified aim is to finish consolidating the
two orchestrate engines into one `skill-orchestrate`, then make that engine's per-dispatch
plumbing uniform and its postflight reporting truthful. This task is strand (A) — finishing the
consolidation. The following coordination constraints are binding on the implementer:

**Shared-file territory in `skills/skill-orchestrate/SKILL.md`** (three tasks edit this file
concurrently). This task's territory is:

- the Stage 4 `#### State: researched` handler,
- the Stage 4 `#### State: planning` handler,
- the Stage 4 `#### State: not_started or not started` and `#### State: researching` handlers'
  closing "After Agent tool returns" sentences,
- the Stage 2 hard-mode-only variable init block (the `churn_file` assignment),
- the hard-mode acceptance-checklist table, the `**Not migrated**:` paragraph, and the
  `**Hard-mode residue not yet migrated**:` paragraph.

NOT this task's territory: Stage 3.5 Dispatch Prep and the dispatch-site `model` parameter lines
(owned by the model-flag task); a new phase-resolution step ahead of Stage 3's loop (owned by the
phase-forcing-flags task). Do not edit, reorder, or reflow those regions.

**Stage 1 / Stage MT-1 context-parse lists**: this task requires NO new bullet there — it adds no
new delegation-context field and reuses the already-derived `hard_mode`. Do not add one
gratuitously; sibling tasks are appending to those same lists and every avoidable touch is an
avoidable conflict.

**Ordering (binding)**: this task's port MUST land before the orchestrate-test-retarget task's
work is meaningful. That task retargets its fixtures at the base engine's `hard_mode` branch, and
its coverage must include the H4 gate this task adds — retargeting before the gate exists would
produce fixtures that cannot cover it. The `-hard` engine deletion task is likewise downstream of
this one: the engine cannot be removed while its last unmigrated gate lives only there.

**Anchoring**: every edit site below is identified by heading or verbatim surrounding text. Do not
navigate by line number — drift from concurrent sibling edits has already been observed in this
file. Re-locate each anchor with `grep -n` immediately before editing it.

**Source-store rule (binding)**: edit `agent-system/extensions/**` only. Never write to
`.claude/**`; it is a regenerated deploy artifact and any edit there is silently wiped.

**Deliverable rule (binding)**: no task-number references in any file outside `specs/**`. When the
engine files or the discrimination doc need to point at sibling work, name it descriptively (e.g.
"the companion word-boundary portability audit", "the engine-deletion task") — never by number.

## Goals & Non-Goals

**Goals**:

- Port the H4 adversarial-verification gate — its `adversarial_verified` state variable, its two
  post-dispatch resets, and its verify-then-re-dispatch body — into `skill-orchestrate/SKILL.md`,
  gated on `$hard_mode` in the same fork style already used for H1/H5/H6.
- Land the two corrected matcher patterns in that ported copy, verbatim from this plan.
- Preserve the gate's false-negative-only direction: a report with no adversarial section, or with
  the section but no claim/source/counterexample table, MUST still fail the gate and still trigger
  re-dispatch.
- Close out the base engine's own "Not migrated" and "Hard-mode residue not yet migrated" text and
  add the H4 row to the acceptance-checklist table.
- Record the deliberate co-maintenance asymmetry in BOTH engine files, using the existing
  "Asymmetry decision (recorded, ...)" convention.
- Verify the corrected patterns against real files under the deployed grep, as they actually land
  in the engine file — never by re-reasoning from the plan text.

**Non-Goals**:

- Editing `skill-orchestrate-hard/SKILL.md`'s gate logic or its broken patterns. That file is
  read-only reference here except for the one asymmetry note (Phase 5). It is slated for deletion;
  mirroring the fix into it is pure waste.
- Generalizing the `\b`-removal fix to other sites in the codebase. That is the explicit scope of
  the companion word-boundary portability audit, which owns the bisection evidence and will
  produce portable-construct guidance separately.
- Switching any `grep` call to `-P`. Evaluated and rejected in research.
- Extending the gate to the base engine's multi-task path (Stage MT-3 / MT-4). The `-hard` source
  engine's own multi-task path has no H4 gate either, so there is nothing to port; adding one
  would be new behavior, not a migration. Recorded here as a deliberate scope boundary, not an
  oversight (see Phase 4, which writes this down in the engine file so the next reader is not
  misled the way this task's own residue note misled).
- Extending the gate to base mode (`$hard_mode = false`). The gate stays hard-mode-gated, exactly
  as the `loop-guard-staleness` detector does; unconditional base-mode adoption is a separate,
  undecided question.
- Widening or reinterpreting the `HOOK_REGEX_BOUNDARY_DEFECT` vocabulary entry in
  `system-defect-discrimination.md`. The defect-class vocabulary gap is a sibling task's scope;
  Phase 6 only records this concrete observed instance additively.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Line-number drift from concurrent sibling edits to `skill-orchestrate/SKILL.md` makes an anchor stale mid-implementation | H | H | Every site is anchored by heading or verbatim surrounding text. Re-run `grep -n` for each anchor immediately before its edit; never carry a line number across phases. |
| Implementer transcribes the ORIGINAL broken patterns from the `-hard` engine while porting the gate body | H | M | Phase 1 writes the corrected patterns down and verifies them first; Phase 3 explicitly forbids copy-paste from the `-hard` file's `grep` lines and Phase 7 re-verifies the patterns *as they landed in the file*, extracted from the file itself. |
| A future refactor "restores" `\b` into the table pattern as a precision improvement | M | M | Carry an explicit in-file comment stating that `\b` was deliberately removed for grep-portability, pointing at the companion word-boundary audit by description — not a silent omission. |
| Forgetting the `$hard_mode` gate makes the ported gate run in base mode, changing base-mode behavior | H | L | Copy the existing, already-reviewed H1/H5/H6 fork style verbatim; Phase 7 verifies base-mode reachability explicitly. |
| Dropping `\b` reopens a false-positive hole (prose sentence containing the three words passes) | H | L | Research verified directly that a sentence containing loose substrings of all three keywords still returns NOMATCH, because it contains no `|` at all — the pipe-delimited cell structure does the discriminating work. Phase 1 re-runs this exact case. |
| Editing outside declared territory collides with a sibling task's in-flight edit | M | M | Territory is enumerated in Batch Coordination above. Touch nothing else in the file, including whitespace and reflow. |
| Adding narrative to `system-defect-discrimination.md` that asserts a stale instance count | M | M | Phase 6 forbids adding or altering any count in that file, and carries a Scope Hypothesis requiring the implementer to confirm no count was introduced. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5, 6 | 3 |
| 5 | 7 | 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Re-establish the fixture matrix and confirm both corrected patterns [COMPLETED]

**Goal**: Before touching any engine file, reproduce the research's verification independently, so
the patterns going into the engine are confirmed against the grep actually deployed on this
machine rather than trusted from a report.

**Tasks**:

- [x] Confirm the deployed grep identity: `grep --version` (research recorded
      `ugrep 7.8.4 x86_64-pc-linux-gnu +sse2; -P:pcre2jit`). If it differs, STOP and report — the
      patterns below were verified against that engine specifically.
- [x] Create scratch fixture files (in the session scratchpad, NOT in the repository) covering
      exactly these cases:
  - [x] `## 7. Adversarial Self-Verification` heading + canonical table header
        `| Claim | Source / counterexample | Verification method | Confidence |`
  - [x] `## 7.2. Adversarial Self-Verification` heading (the `N.N` form) + canonical table header
  - [x] Unnumbered `## Adversarial Self-Verification` heading + canonical table header
  - [x] No adversarial section at all
  - [x] Adversarial section present, but no claim/source/counterexample table
  - [x] Alternate already-supported header
        `| # | Claim under attack | Source / counterexample | Outcome |` (regression check — no
        previously-supported format may stop working)
  - [x] False-positive probe: prose reading
        `This section disclaims outsourced counterexamples informally, without a table.` under a
        valid heading, with no `|` characters anywhere
- [x] Run the two CORRECTED patterns against every fixture, as the literal combined shell
      conditional the production gate uses (`grep -qE ... && grep -qiE ...`), against real files.

  Heading pattern (carry verbatim into the engine):

  ```
  grep -qE '## ([0-9]+\.([0-9]+\.)?[[:space:]]*)?Adversarial Self-Verification' "$research_path"
  ```

  Table pattern (carry verbatim into the engine):

  ```
  grep -qiE '\|[^|]*claim[^|]*\|[^|]*source[^|]*counterexample[^|]*\|' "$research_path"
  ```

- [x] Confirm the expected result for each row: PASS (no re-dispatch) for the three positive rows
      and the regression row; FAIL (re-dispatch triggers) for the two negative rows; NOMATCH on
      the table check for the false-positive probe.
- [x] Record the actual command output for each row — it is the evidence Phase 7 re-checks
      against.

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts a seven-row fixture matrix (six from the research's
required set plus the false-positive probe) is sufficient to confirm both patterns. Confirm at
implementation time by running every row and checking that each produces the stated expected
result; if any row disagrees with the research's recorded outcome, STOP and report rather than
adjusting the pattern — a disagreement means the deployed grep differs from the one the research
verified against, which invalidates the chosen fix rather than requiring a tweak.

**Files to modify**: none (scratch fixtures only; no repository artifacts are created or retained)

**Verification**:

- All seven rows produce their stated expected results under the deployed grep, run against real
  files.
- `grep --version` matches the research-recorded engine.

---

### Phase 2: Port the `adversarial_verified` state variable and its two post-dispatch resets [NOT STARTED]

**Goal**: Establish the gate's state plumbing in `skill-orchestrate/SKILL.md` — the variable's
hard-mode-gated initialization and the two resets that force re-verification after any fresh
research dispatch — before the gate body that reads it exists.

**Tasks**:

- [ ] Re-locate the Stage 2 hard-mode-only variable init block by its verbatim comment
      `# Hard-mode-only per-target churn-state file (H5/H6).` and the
      `churn_file="${TASK_DIR}/.orchestrator-churn-state.json"` assignment inside
      `if [ "${hard_mode:-false}" = "true" ]; then ... fi`.
- [ ] Add `adversarial_verified=false` to that same hard-mode-gated block, in that block's own
      established style (assigned inside the `$hard_mode` guard; only ever read inside `$hard_mode`
      branches). Extend the block's existing comment, or add a short adjacent one, naming the
      variable as the H4 gate's state.
- [ ] Re-locate the `#### State: not_started or not started` handler's closing sentence, verbatim:
      `After Agent tool returns: read handoff (Stage 5). Increment cycle_count.`
- [ ] Add a hard-mode-gated reset of `adversarial_verified` to `false` at that site, matching the
      `-hard` engine's intent (a fresh research dispatch must always force the gate to re-verify
      rather than trusting a stale `true` from a previous cycle). Do not unconditionally reset —
      the reset belongs inside the `$hard_mode` fork, consistent with the variable only being
      assigned there.
- [ ] Re-locate the `#### State: researching` handler's closing sentence — the SAME verbatim text
      as above; this sentence occurs at both handlers, so disambiguate by which `#### State:`
      heading precedes it, not by the sentence alone.
- [ ] Add the equivalent hard-mode-gated reset at that second site.
- [ ] Confirm no other handler ends with that sentence and was missed.

**Timing**: 0.4 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts exactly three edit sites (one Stage 2 init, two handler
resets), matching the `-hard` engine's three `adversarial_verified` set-sites. Confirm at
implementation time by grepping the base engine for `adversarial_verified` after the edits and
checking the result is exactly three occurrences at the three intended anchors, and by grepping
the `-hard` engine for the same symbol to confirm its own count is unchanged at three. If the base
engine has a fourth handler that dispatches research and ends with the same closing sentence,
report it rather than silently extending or silently skipping.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 2 hard-mode init block
  (add `adversarial_verified=false`); `not_started` and `researching` handler closings (add
  hard-mode-gated resets).

**Verification**:

- `grep -c 'adversarial_verified' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  returns 3.
- Each occurrence sits inside a `$hard_mode` guard (inspect each hit's surrounding block).
- No text outside the three anchors changed: `git diff` shows only the intended hunks.
- `bash .claude/scripts/lint/lint-contract-compliance.sh` (or the repository's current equivalent
  contract lint) passes.

---

### Phase 3: Port the gate body with the corrected matcher into the `researched` and `planning` handlers [NOT STARTED]

**Goal**: Land the verify-then-re-dispatch gate itself in both handlers, using the corrected
patterns from Phase 1 and reusing each handler's already-computed `research_artifact` rather than
recomputing it.

**Tasks**:

- [ ] Re-locate the `#### State: researched` handler. Its anchor: the sentence
      `Read research artifact path from state.json:` followed by the `research_artifact=$(jq -r ...
      select(.type == "report") ...)` block, followed by
      `skill_preflight_update "$task_number" "plan" "$session_id"`.
- [ ] Insert the H4 gate IMMEDIATELY BEFORE that `skill_preflight_update` call, wrapped in the
      `$hard_mode` fork so base mode reaches `skill_preflight_update` unchanged. Port the `-hard`
      engine's logic — its structure only, NOT its `grep` lines:
  - [ ] `if [ "$adversarial_verified" = "false" ]; then` — the outer gate.
  - [ ] Use the handler's already-in-scope `research_artifact` as the file under test. Do NOT add a
        second `jq` query; the `-hard` engine recomputes it independently only because its handler
        has no such value in scope, which is not the case here.
  - [ ] The two corrected `grep` checks, joined by `&&`, copied CHARACTER-FOR-CHARACTER from Phase 1
        (bind them to `"$research_artifact"`, which is the only substitution permitted — the
        pattern strings themselves are verbatim). Explicitly do not copy the `grep` lines from
        `skill-orchestrate-hard/SKILL.md`; those are the broken originals.
  - [ ] On both checks passing: set `adversarial_verified=true` and log the "section with Claim
        Verification Table found in report; proceeding to planning" message, adapted to this
        engine's own log-prefix convention (the `-hard` engine's `[hard-orchestrate]` prefix is not
        this engine's).
  - [ ] On failure: dispatch `$RESEARCH_AGENT` as a focused verification pass with
        `focus_prompt: "divergence audit"` and `orchestrator_mode: false`, mint
        `dispatch_start_ts` / `dispatch_was_transport_error=false` / `dispatch_seq` per this
        engine's own dispatch-window convention, do NOT write `.orchestrator-handoff.json`
        (research agents never write it), increment `cycle_count`, and loop.
  - [ ] Empty-or-missing `research_artifact`: set `adversarial_verified=true` (nothing to verify;
        proceed) rather than blocking.
  - [ ] Preserve the `-hard` engine's explicit warning comment that `skill_preflight_update` fires
        ONLY inside the verified branch and never in the re-dispatch branch — a preflight in the
        re-dispatch branch would wrongly regress status from `researched` to `researching`.
- [ ] Carry an in-file comment recording that the `\b` word-boundary anchors were DELIBERATELY
      removed from the table pattern for grep-portability under the deployed engine, pointing at
      the companion word-boundary portability audit by description (no task number). Also carry the
      `-hard` engine's existing comment describing the pattern's shape-matching intent (matching by
      table-cell shape, not a fixed header string, tolerant of extra columns, matching both known
      passing header formats).
- [ ] Re-locate the `#### State: planning` handler, anchored by its `**Converged (was: exit with
      warning ...)**` paragraph and its own duplicate `research_artifact` / `skill_preflight_update`
      pair.
- [ ] Insert the identical gate at the identical position in that handler. The `-hard` engine's own
      text states the `planning` handler runs the identical block for the identical reason: a task
      stranded in `planning` has research already complete and needs the same re-dispatch-to-plan
      treatment. Keep the two insertions byte-identical apart from any handler-name mention, so the
      two cannot drift.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts exactly two gate insertions, both in
`skill-orchestrate/SKILL.md`, both immediately before a
`skill_preflight_update "$task_number" "plan" "$session_id"` call. Confirm at implementation time
by grepping the base engine for `skill_preflight_update "$task_number" "plan"` and checking that
the result is exactly the two Stage 4 single-task handler sites this phase edits — and that any
additional hit belongs to the multi-task path (Stage MT-4), which this plan explicitly excludes
(see Non-Goals). If a third single-task plan-preflight site exists, report it before proceeding.

**Rationale for `atomic-batch`**: the two handler insertions plus Phase 2's state plumbing form
one coherent gate; a commit landing the gate body in one handler but not the other would leave the
engine in a state where `researched` verifies and `planning` does not — a real behavioral
inconsistency, not merely an unfinished edit. The declared batch is exactly the two handler
insertions in this one file. Do not retroactively widen it.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — `#### State: researched` and
  `#### State: planning` handlers.

**Verification**:

- Both handlers contain the gate; the two insertions are textually identical apart from any
  handler-name mention (diff them against each other).
- The two `grep` pattern strings in the file match Phase 1's verified patterns
  character-for-character.
- No `\b` appears in the ported table pattern; no `-P` flag appears in either ported check.
- `skill_preflight_update` appears exactly once per handler and lies OUTSIDE the re-dispatch
  branch.
- The gate is inside a `$hard_mode` guard in both handlers; base mode's path to
  `skill_preflight_update` is unchanged.
- `git diff` touches only the two handler regions.

---

### Phase 4: Close out the base engine's migration notes and record the asymmetry there [NOT STARTED]

**Goal**: Make the base engine's own documentation true: H4 is now migrated, the residue note no
longer describes reality, and the deliberate asymmetry with the `-hard` engine is on the record.

**Tasks**:

- [ ] Re-locate the acceptance-checklist table under the heading text
      `**Hard-mode state-machine migration — acceptance checklist.**`. Add a row for the H4
      adversarial-verification gate alongside the existing H1/H5/H6 rows, in the table's own
      `| Behavior | Stage | Notes |` style, naming Stage 4's `researched`/`planning` handlers as
      the implementing stage.
- [ ] Re-locate the paragraph beginning verbatim `**Not migrated**: the \`researched\`-state
      adversarial verification gate (H4) — see the residue note immediately below.` Rewrite it so
      it no longer claims H4 is unmigrated. The following sentence — "Everything else in the source
      engine's state-machine logic ... is now reproduced here" — must be adjusted too, since H4 is
      no longer an exception to that "everything else".
- [ ] Re-locate the full paragraph beginning verbatim `**Hard-mode residue not yet migrated**: the
      \`researched\`-state adversarial verification gate (H4)` and ending
      `...its absence here is not evidence it was folded in elsewhere in this file.` Replace it
      with a short note recording that the gate is now ported, pointing at the acceptance-checklist
      row rather than restating the gate's mechanics.
- [ ] In that replacement note, record the two deliberate scope boundaries so the next reader is
      not misled the way the original residue note's unowned "account for this gate separately"
      request misled: (a) the gate is hard-mode-gated only, base mode unchanged; (b) the gate is
      NOT present on the multi-task path, mirroring the `-hard` source engine, which has no
      multi-task H4 gate either — this is a migration boundary, not an omission.
- [ ] Add an `**Asymmetry decision (recorded, ...)**` note in this file's existing convention —
      copy the shape of the existing `loop-guard-staleness` example, which begins
      `**Asymmetry decision (recorded, "recorded not acted on" style)**:`. Content: the corrected
      matcher was landed only in this engine's ported copy, deliberately, because the `-hard`
      engine is scheduled for deletion by a separate downstream task; mirroring the fix there would
      create a second site to maintain for a file about to be removed, with no correctness benefit.
      Name the deletion work descriptively, never by task number.

**Timing**: 0.4 hours

**Depends on**: 3

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly three existing documentation sites need changing
(the checklist table, the `**Not migrated**:` paragraph, the `**Hard-mode residue not yet
migrated**:` paragraph) plus one new asymmetry note. Confirm at implementation time by grepping
the file for `Not migrated`, `residue`, and `H4` after the edits and checking that no surviving
sentence still asserts the gate is unported. If a fourth site elsewhere in the file also claims H4
is unmigrated, fix it too and note the widening.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — acceptance-checklist table,
  `**Not migrated**:` paragraph, `**Hard-mode residue not yet migrated**:` paragraph, plus the new
  asymmetry note.

**Verification**:

- `grep -n 'Not migrated\|residue\|adversarial' skill-orchestrate/SKILL.md` shows no surviving
  claim that H4 is unmigrated.
- The acceptance-checklist table has an H4 row and the table still renders as valid Markdown
  (column count matches the header).
- The asymmetry note uses the file's existing convention wording.
- No task numbers appear in any added text.
- All changed hunks lie inside prose/table/comment regions — no bash block was touched by this
  phase (this is the `prose` tier's blind spot; confirm by reading the diff, since Phase 3 edited
  bash in the same file).

---

### Phase 5: Record the mirror asymmetry note in the `-hard` engine [NOT STARTED]

**Goal**: Ensure a reader of `skill-orchestrate-hard/SKILL.md` understands its gate's broken
matcher was deliberately left unfixed, rather than reading it as live, correct reference logic.

**Tasks**:

- [ ] Re-locate the `#### State: \`researched\` — WITH Adversarial Verification Gate (H4)` heading
      in `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`.
- [ ] Add a brief `**Asymmetry decision (recorded, ...)**` note adjacent to that gate, in the same
      convention used in the base engine. Content: this gate has been ported to the consolidated
      base engine WITH a corrected matcher; the copy here retains the original, known-false-negative
      patterns deliberately, because this engine is scheduled for deletion and mirroring the fix
      would be wasted work. Point the reader at the base engine's ported copy as the live one.
- [ ] Change NOTHING else in this file. In particular, do not fix, reword, or reformat the two
      broken `grep` lines, the gate body, or any `adversarial_verified` site.

**Timing**: 0.15 hours

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — one added note only.

**Verification**:

- `git diff` on this file shows exactly one added block and zero modified lines.
- `grep -c 'adversarial_verified' skill-orchestrate-hard/SKILL.md` is unchanged from its
  pre-edit value.
- The two original `grep` patterns in this file are byte-identical to their pre-edit form.
- No task numbers appear in the added text.

---

### Phase 6: Record the concrete defect-shape instance in the discrimination doc [NOT STARTED]

**Goal**: Record, additively, that the `HOOK_REGEX_BOUNDARY_DEFECT` instance has now been
exercised by a non-hook site whose boundary assumption was a composed word-boundary anchor rather
than a fixed digit-count quantifier — without widening the vocabulary, which a sibling task owns.

**Tasks**:

- [ ] Re-locate the `### Extending the Signal A vocabulary is an explicit decision, not a silent
      act` section in
      `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`.
- [ ] Append a short paragraph recording the concrete observed shape: an orchestration gate's
      `grep` matcher, not a validation hook, whose unstated boundary assumption was a `\b` anchor
      composed downstream of an earlier `\b`-anchored subexpression — mis-evaluated by the deployed
      POSIX/DFA `-E` engine, producing a false negative that wrongly rejected conforming input.
      Note that this is the same *kind* of violation the existing row names, reached from a
      different site class.
- [ ] Explicitly state in that paragraph that the row itself was NOT reworded or reinterpreted, and
      that whether the row's site-class wording ("a validation hook's regex or path-depth pattern")
      should be widened is left to the separate defect-class vocabulary work — named descriptively,
      not by number.
- [ ] Do NOT add, alter, or restate any count of instances anywhere in this file. Do not touch the
      Signal A table row, the registry, or any other section.

**Timing**: 0.25 hours

**Depends on**: 3

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts a single additive paragraph in one section, and asserts
that no numeric count is introduced. Confirm at implementation time by diffing the file and
checking that (a) exactly one paragraph was added, (b) the added text contains no number-word or
digit asserting how many instances the vocabulary holds, and (c) the Signal A table is byte-identical
to its pre-edit form. Note that the pre-existing count language in this file's narrative ("the ten
pre-existing instances", "a further three instances") must be left exactly as found — the fix for a
stale count there is not this task's, and touching it would collide with the sibling vocabulary
task.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — one added
  paragraph in the "Extending the Signal A vocabulary" section.

**Verification**:

- `git diff` shows exactly one added paragraph; the Signal A table and every other section are
  unchanged.
- No count assertion was added or altered.
- No task numbers appear in the added text.

---

### Phase 7: End-to-end verification against the landed patterns [NOT STARTED]

**Goal**: Confirm the gate as it actually exists in the engine file behaves correctly in both
directions, under the deployed grep, against real files — closing the loop the research explicitly
asked for (verify the landed patterns, do not re-derive them).

**Tasks**:

- [ ] EXTRACT the two `grep` pattern strings from
      `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` as they landed — read them
      out of the file, do not retype them from this plan.
- [ ] Re-run the full Phase 1 fixture matrix using the EXTRACTED patterns, as the literal combined
      shell conditional, against real files, under the deployed grep.
- [ ] Confirm the positive direction: the `## 7.` numbered heading + canonical table header passes;
      the `## 7.2.` form passes; the unnumbered form passes; the alternate
      `| # | Claim under attack | Source / counterexample | Outcome |` header still passes.
- [ ] Confirm the NEGATIVE direction explicitly — this is the acceptance criterion the task
      description calls out as non-optional ("a gate that can only ever stay silent is not a fix"):
      a report with no adversarial section FAILS the gate; a report with the section but no
      claim/source/counterexample table FAILS the gate. Both must still trigger re-dispatch.
- [ ] Confirm the false-positive probe (prose with loose substrings, no `|`) still returns NOMATCH.
- [ ] Confirm base-mode reachability: with `hard_mode=false`, the `researched` and `planning`
      handlers reach `skill_preflight_update` without evaluating the gate — verify by reading the
      fork structure in the file, and confirm `adversarial_verified` is never read outside a
      `$hard_mode` guard.
- [ ] Run the repository's artifact/contract gates over the changed files: `bash
      .claude/scripts/validate-artifact.sh` on this plan, `bash
      .claude/scripts/lint/lint-contract-compliance.sh`, and
      `bash .claude/scripts/check-task-references.sh` (or the current equivalents) to confirm no
      task-number reference leaked into a non-`specs/**` deliverable.
- [ ] Confirm the source-store boundary held: `git status` shows no modified file under
      `.claude/**`.
- [ ] Confirm territory discipline: `git diff --stat` lists exactly the three intended files
      (`skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`,
      `system-defect-discrimination.md`) and nothing else.

**Timing**: 0.5 hours

**Depends on**: 4, 5, 6

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the same seven-row matrix from Phase 1 is the complete
acceptance set, and that exactly three files changed. Confirm by running every row against the
extracted patterns and by checking `git diff --stat`. A fourth changed file means either scope
crept or a sibling task's edit was accidentally staged — investigate before committing rather than
including it.

**Files to modify**: none (verification only)

**Verification**:

- All seven matrix rows produce their expected results using the patterns extracted from the
  engine file.
- Both negative rows still trip the gate.
- No `.claude/**` file is modified.
- Exactly three files changed.
- All repository gates pass.

---

## Testing & Validation

- [ ] `grep --version` confirms the deployed engine matches the one the patterns were verified
      against.
- [ ] Positive: `## 7. Adversarial Self-Verification` + `| Claim | Source / counterexample |
      Verification method | Confidence |` passes the gate; no re-dispatch.
- [ ] Positive: the `## 7.2.` (`N.N`) heading form passes.
- [ ] Positive: the unnumbered `## Adversarial Self-Verification` heading passes.
- [ ] Regression: the alternate `| # | Claim under attack | Source / counterexample | Outcome |`
      header still passes.
- [ ] Negative: a report with no adversarial section fails the gate and triggers re-dispatch.
- [ ] Negative: a report with the section but no claim/source/counterexample table fails the gate
      and triggers re-dispatch.
- [ ] Negative: prose containing loose substrings of all three keywords, with no `|`, returns
      NOMATCH.
- [ ] Every check above is run against a real file by the deployed grep, using the patterns
      extracted from the engine file — never reasoned about.
- [ ] `adversarial_verified` occurs exactly three times in the base engine, each inside a
      `$hard_mode` guard, plus its reads inside the two ported gate bodies.
- [ ] Base mode (`hard_mode=false`) reaches `skill_preflight_update` in both handlers unchanged.
- [ ] `skill-orchestrate-hard/SKILL.md`'s gate logic and patterns are byte-identical to their
      pre-task form; only the asymmetry note was added.
- [ ] Contract lint, artifact validation, and the task-reference lint all pass.
- [ ] No file under `.claude/**` was modified.

## Artifacts & Outputs

- `specs/128_fix_h4_adversarial_gate_matcher/plans/01_fix-h4-adversarial-gate-matcher.md` (this
  plan)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — H4 gate ported with corrected
  matcher; state variable and two resets added; acceptance checklist, `Not migrated` and residue
  paragraphs updated; asymmetry note added
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — one asymmetry note added,
  nothing else changed
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — one additive
  paragraph recording the concrete defect shape
- `specs/128_fix_h4_adversarial_gate_matcher/summaries/01_fix-h4-adversarial-gate-matcher-summary.md`
  (written at implementation completion)

## Rollback/Contingency

All changes are confined to three Markdown files in the source store, with no generated or
compiled downstream artifacts, so rollback is a plain revert.

- **Per-phase**: each phase except 3 commits per green sub-step, so any single site can be reverted
  independently with `git revert` of that commit. Phase 3 is a declared `atomic-batch` — its two
  handler insertions land as one commit and revert as one.
- **Whole task**: `git revert` the task's commits in reverse order. The base engine returns to its
  pre-task state, in which the residue note again correctly describes H4 as unmigrated — the file
  is self-consistent at both endpoints, so a partial rollback that keeps the gate but reverts
  Phase 4's note updates must be avoided (it would leave the file claiming the gate is absent while
  it is present).
- **If Phase 1 fails** (the deployed grep does not match the research-verified engine, or a matrix
  row disagrees): stop before any engine edit. Nothing has changed; report the discrepancy, since
  it invalidates the pattern choice rather than requiring a tweak.
- **If a sibling task's concurrent edit makes an anchor unrecoverable**: stop, report the collision,
  and re-derive the anchor from the surrounding heading rather than guessing at a line range.
