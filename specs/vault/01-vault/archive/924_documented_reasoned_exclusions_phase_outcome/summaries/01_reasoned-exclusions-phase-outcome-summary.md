# Implementation Summary: Task #924

**Completed**: 2026-07-27
**Duration**: single session, 5 phases

## Overview

Introduced `[COMPLETED WITH EXCLUSIONS]` as a third terminal phase-heading outcome, documented as
a generalization of the existing strategic-sorry family (distinguishing property: absence of a
tracked follow-up). Closed the two-sided write/count trap in the scripts that mutate and gate on
phase headings, protected the new marker's `#### Reasoned Exclusions` record from Stage 5a's
automated repair pass in both implementation agents (fixing a pre-existing decimal-sub-phase
extraction defect along the way), reconciled the remaining digits-only phase-heading regex site,
and wired the outcome into the handoff schema and the plan-format enforcement checklist.

## What Changed

- `agent-system/extensions/core/context/standards/status-markers.md` — added the
  `[COMPLETED WITH EXCLUSIONS]` subsection: three-way distinction vs. `[COMPLETED]`/`[PARTIAL]`,
  the character-class constraint, and the five-condition admission test (generalized from the
  strategic-sorry test).
- `agent-system/extensions/core/context/formats/plan-format.md` — added the marker to the
  Implementation Phases format's valid-status list; extended "Plan-level vs. phase-level markers"
  with the three-way distinction; added the `## Reasoned Exclusions` record-format section
  (`Item | Reason | Evidence`, field-mapped to `sorry_inventory`, Scope Hypothesis
  cross-reference); added a new "Canonical phase-heading shape" subsection documenting the
  ERE/BRE decimal-admitting forms, the deliberate no-letter-suffix decision, and the consumer-site
  list.
- `agent-system/extensions/core/context/contracts/anti-analysis.md` — added the "Family
  relationship" cross-reference from the strategic-sorry section to the new marker/record
  sections (one definition, referenced twice, not restated).
- `agent-system/extensions/core/scripts/update-phase-status.sh` — added the
  `COMPLETED_WITH_EXCLUSIONS|completed_with_exclusions` case branch normalizing to
  `COMPLETED WITH EXCLUSIONS`; updated the header comment, usage line, and invalid-value error to
  enumerate it.
- `agent-system/extensions/core/scripts/update-task-status.sh` — `count_plan_phases()`'s TOTAL and
  DONE regexes now both admit an optional single decimal sub-phase level, and DONE now accepts the
  `COMPLETED WITH EXCLUSIONS` alternation; updated all three "phases [COMPLETED]" phase-check
  messages to read "phases closed (COMPLETED or COMPLETED WITH EXCLUSIONS)"; added a
  character-class-constraint comment above `count_plan_phases()`. Also fixed a second, previously
  undocumented digits-only phase-heading site (`first_phase` auto-advance convenience) discovered
  during the Phase 4 census to admit decimal sub-phases, since it was the same one-line-pattern
  fix.
- `agent-system/extensions/core/agents/general-implementation-agent.md` and
  `general-implementation-hard-agent.md` — Stage 5a's repair loop is now exclusion-aware: a stale
  heading whose phase body carries a `#### Reasoned Exclusions` subsection repairs to
  `COMPLETED_WITH_EXCLUSIONS`, never to plain `COMPLETED`; the phase-number extraction now admits
  decimal sub-phases (`Phase 3.1` extracts as `3.1`, fixing the pre-existing "Phase 3 not found"
  defect the plan identified); added direct-transition guidance (exclusion-close happens at Stage
  4D, never by parking at `[PARTIAL]`) and the `phases_completed` self-report instruction. The base
  agent's Stage 3 "Find Resume Point" list and Stage 2 phase-list description were also updated to
  include the new marker (skip-on-resume, like `[COMPLETED]`).
- `agent-system/extensions/core/scripts/validate-artifact.sh` — all three phase-heading regexes
  (presence check, phase-line enumeration, phase-number extraction) now admit decimal sub-phases.
- `agent-system/extensions/core/commands/task.md` — the phase-heading parse regex and the
  phase-status enumeration comment in the `/task --review` flow now admit decimal sub-phases and
  list the new marker; added a "Completed with Exclusions" category to the phase categorization.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — extended the
  `phases_completed`/`phases_total` field definition with the exclusion-accounting rule (counts
  identically to `[COMPLETED]`) and an explicit statement that no new handoff field is introduced,
  contrasted against the strategic-sorry family member's `sorry_inventory`.
- `agent-system/extensions/core/rules/plan-format-enforcement.md` — added the marker to the valid
  phase-heading list and the record requirement (advisory-first enforcement, matching the
  `**Verification Tier**` item's own honest status statement).

## Decisions

- The outcome is documented as a generalization of the strategic-sorry mechanism, not a parallel
  concept — one admission test, written once in status-markers.md, cross-referenced from
  anti-analysis.md rather than restated.
- `#### Reasoned Exclusions` nests inside the phase body (not a document-level `##` section)
  because exclusions are phase-scoped by definition.
- Phase 2's two script edits were committed as a single atomic-batch commit per the plan's
  `Commit Mode: atomic-batch` declaration — reverting either half alone would leave the marker
  either unwritable or uncountable.
- During the Phase 4 census, an additional (previously undocumented) digits-only phase-heading
  site was found in `update-task-status.sh` (the `first_phase` auto-advance convenience at the end
  of the file) and absorbed into scope per the plan's escalate-or-absorb rule, since it was the
  same one-line decimal-admitting fix already being applied elsewhere.

## Plan Deviations

- **Scope Hypothesis correction (Phase 4)**: the plan's Phase 4 Scope Hypothesis asserted
  `scripts/validate-artifact.sh` was the only remaining digits-only phase-heading regex site. The
  census (`grep -rn '### Phase \[0-9\]' agent-system/extensions/core/`) found one additional site:
  `commands/task.md`'s `/task --review` phase-parse regex (`grep -E "^### Phase [0-9]+:"`). This
  was a one-line fix and was absorbed into Phase 4 rather than escalated, per the plan's own
  instruction for that case. A second additional site (`update-task-status.sh`'s `first_phase`
  auto-advance regex, not part of `count_plan_phases()`) was found and absorbed for the same
  reason.
- **Not absorbed, flagged for follow-up**: `skill-orchestrate/SKILL.md` and
  `skill-orchestrate-hard/SKILL.md` each contain a `recovered_completed` count
  (`grep -cE '^### Phase [0-9]+(\.[0-9]+)?: .*\[COMPLETED\]' ...`) used only for an informational
  stagnation-detection log line during handoff recovery — it is not consulted by the completion
  gate (which reads `phases_completed`/`phases_total` from the handoff, already fixed at the
  self-report source in Phase 3). This count would also undercount an exclusion-closed phase, but
  fixing it well is the same category of regex work as Phase 2's DONE-regex change across two
  files at two sites each, which is a substantive addition beyond a one-line enumeration fix.
  Per the plan's Phase 5 Scope Hypothesis instruction ("escalate to a follow-up if it requires
  substantive rewriting"), this is flagged here as a candidate follow-up rather than silently
  absorbed or silently left broken.
- No other deviations. All five phases were implemented as planned.

## Verification

- **Build**: N/A (documentation and shell-script changes; `deploy-headless.sh` +
  `verify-deploy.sh` run after every phase, PASS each time — 11/11 checks, 0 failures).
- **Tests**: All plan-specified fixture assertions passed; transcripts below.
- **Files verified**: Yes — every file in Artifacts & Outputs was confirmed modified via
  `git status`/`git diff` before each phase commit.

### Phase 1 fixtures

```
$ grep -n 'COMPLETED WITH EXCLUSIONS' status-markers.md plan-format.md anti-analysis.md | wc -l
15
$ printf '### Phase 1: X [COMPLETED WITH EXCLUSIONS]\n' > fixture1.txt
$ grep -c '^### Phase [0-9][0-9]*:.*\[[A-Z][A-Z ]*\][[:space:]]*$' fixture1.txt
1
$ grep -c 'Reasoned Exclusions' anti-analysis.md ; grep -c 'Planned Strategic Sorries' plan-format.md
1
4
$ grep -rc 'No residual work' agent-system/extensions/core/ --include='*.md' | grep -v ':0'
context/standards/status-markers.md:1
```

### Phase 2 fixtures

```
$ FIXTURE (3 phases: [COMPLETED] / [COMPLETED WITH EXCLUSIONS] / Phase 3.1 [PARTIAL])
$ grep -c '^### Phase [0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}:.*\[[A-Z][A-Z ]*\][[:space:]]*$' fixture
3   # TOTAL
$ grep -c '^### Phase [0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}:.*\[\(COMPLETED\|COMPLETED WITH EXCLUSIONS\)\][[:space:]]*$' fixture
2   # DONE
```

Negative fixture (plain `[PARTIAL]`, no record), real gate, end-to-end:
```
$ bash update-task-status.sh postflight 999 implement sess_fixture_test --phase-check=refuse
Error: [phase-check] refusing postflight implement for task 999: only 0/1 phases are closed
(COMPLETED or COMPLETED WITH EXCLUSIONS) in .../01_fixture.md.
       No state.json write and no plan-file status stamp occurred.
       Finish the remaining phases, or correct the plan file's phase headings, and re-run.
EXIT_CODE=4
```

Positive round-trip:
```
$ bash update-phase-status.sh 999 phase2_negative_fixture 1 COMPLETED_WITH_EXCLUSIONS
.../01_fixture.md
$ cat 01_fixture.md
### Phase 1: Alpha [COMPLETED WITH EXCLUSIONS]
$ bash update-phase-status.sh 999 phase2_negative_fixture 1 COMPLETED_WITH_EXCLUSIONS   # re-invoke
exit=0   # idempotency no-op fired, no stdout
$ bash update-task-status.sh postflight 999 implement sess_fixture_test --phase-check=refuse --dry-run
[phase-check] Task 999: 1/1 phases closed (COMPLETED or COMPLETED WITH EXCLUSIONS) in
01_fixture.md -- proceeding.
$ bash update-phase-status.sh 999 phase2_negative_fixture 1 BOGUS_STATUS
Unknown status: BOGUS_STATUS
Valid values: IN_PROGRESS, NOT_STARTED, COMPLETED, COMPLETED_WITH_EXCLUSIONS, PARTIAL, BLOCKED
exit=1
```

Throwaway fixture directories (`specs/999_phase2_negative_fixture`) removed after the run;
`specs/state.json`/`TODO.md` confirmed clean (`git diff` empty) afterward.

### Phase 3 fixtures

Stage 5a bash block extracted verbatim from both deployed agent files and diffed — empty diff
(byte-identical). Ran the extracted block against a 3-phase fixture:

```
=== before ===
### Phase 1: WithRecordSurvival [COMPLETED WITH EXCLUSIONS]   (+ #### Reasoned Exclusions table)
### Phase 2: PartialWithRecord [PARTIAL]                      (+ #### Reasoned Exclusions table)
### Phase 4.1: PartialNoRecord [PARTIAL]                      (no record)

=== after running the extracted Stage 5a block verbatim ===
### Phase 1: WithRecordSurvival [COMPLETED WITH EXCLUSIONS]   <- byte-identical, untouched
### Phase 2: PartialWithRecord [COMPLETED WITH EXCLUSIONS]    <- repaired to exclusion marker, NOT [COMPLETED]
### Phase 4.1: PartialNoRecord [COMPLETED]                    <- regression guard: still repairs correctly
```

Full-body diff of Phase 1's block (heading + table) before/after: empty (byte-identical).
Decimal extraction: `Phase 4.1` extracted and repaired successfully — no "Phase 4 not found"
error. Gate re-run after the simulated Stage 5a:

```
$ bash update-task-status.sh postflight 998 implement sess_fixture_test --phase-check=refuse --dry-run
[phase-check] Task 998: 3/3 phases closed (COMPLETED or COMPLETED WITH EXCLUSIONS) in
01_fixture.md -- proceeding.
exit=0
```

Throwaway directory (`specs/998_phase3_fixture`) removed; state.json/TODO.md confirmed clean.

### Phase 4 fixtures

```
$ bash validate-artifact.sh specs/924_.../plans/01_reasoned-exclusions-phase-outcome.md plan
[PASS] plan artifact is valid (0 warning(s))   # regression case: this plan has no decimal sub-phases
```

Fixture with `### Phase 2.1: Beta [NOT STARTED]` (tiered): `[PASS] ... (0 warning(s))` — phase
2.1 enumerated and tier-matched, not skipped. Same fixture with the tier field removed from Phase
2.1: `[WARN] Phase 2.1 missing **Verification Tier** field` — the warning correctly names `2.1`,
not `2`, proving the extraction fix reached the message. Throwaway directory
(`specs/997_phase4_fixture`) removed afterward.

### Phase 5 fixtures

```
$ grep -rln 'COMPLETED WITH EXCLUSIONS' agent-system/extensions/core/ --include='*.md' --include='*.sh'
(10 files, matching every file this plan touched)
$ bash validate-artifact.sh specs/924_.../plans/01_reasoned-exclusions-phase-outcome.md plan
[PASS] plan artifact is valid (0 warning(s))
```

### Repo-wide invariants

- `git status --short` after the final commit shows changes only to files unrelated to this task
  (pre-existing, present before this session started: `.claude-extensions.json`,
  `lua/neotex/plugins/editor/which-key.lua`, `lua/neotex/plugins/tools/himalaya/utils/cli.lua`,
  `specs/events.jsonl`) — no residual authored edits under `.claude/**`, and no leftover throwaway
  fixture directories under `specs/`.
- `git log -- .claude/` shows `.claude/` is untracked/gitignored (last commit: "chore: gitignore
  and untrack the .claude/ deploy tree") — every phase's edits landed exclusively under
  `agent-system/extensions/core/`, deployed via `deploy-headless.sh` purely to execute
  verification, per the source-store rule.
- No task-number citation appears in any file this plan edited outside `specs/**` (spot-checked
  every edited file with `grep -nE 'task [0-9]+|tasks [0-9]+-[0-9]+|\(task [0-9]+\)'`; the only
  hits were pre-existing citations in `commands/task.md` unrelated to and untouched by this
  task's edits).

## Notes

- Follow-up candidate (not created as a task, flagged here per the plan's escalate-don't-absorb
  instruction): `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md`'s
  `recovered_completed` stagnation-detection log count does not recognize
  `[COMPLETED WITH EXCLUSIONS]`. It is informational-only (not consulted by the completion gate),
  but a future task could extend it to the same alternation used in
  `update-task-status.sh`'s `count_plan_phases()` DONE regex for full consistency.
- All five phases closed as plain `[COMPLETED]` — none of this task's own phases qualified for
  `[COMPLETED WITH EXCLUSIONS]` under the admission test it defines (no phase had a decided,
  evidenced, non-revisitable exclusion; all planned work was completed as specified).
