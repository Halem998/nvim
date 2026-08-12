# Research Report: Task #56

**Task**: 56 - LEVER 3 of the context-cost work (command bodies): slim todo.md and orchestrate.md
**Started**: 2026-08-12T20:44:09Z
**Completed**: 2026-08-12T20:49:53Z
**Effort**: Small (single research pass, no context-pressure handoff needed)
**Dependencies**: None for this research dispatch (see Decisions on the `dependencies: [48]` field)
**Sources/Inputs**: Codebase read (commands/todo.md, commands/orchestrate.md, commands/task.md,
  context/patterns/*, index-entries.json, lint-state-writer-boundary.sh, test suite under
  scripts/tests/), specs/state.json
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both extraction regions are confirmed present and unchanged from the task description's
  estimate; exact re-measured sizes: `## Notes` in `todo.md` = **7,851 B** (168 lines, byte-exact
  match to the audit figure), `## Batch Orchestrate Results` fenced template in `orchestrate.md`
  = **6,648 B** (137 lines, fence content only; 6,674 B including the `**Consolidated Output**:`
  label line immediately above the fence).
- One internal cross-reference inside `todo.md`'s Execution section (line 148: "...per the
  jq/shell escaping guidance in the Notes section") points INTO the region being extracted and
  MUST be repointed at the new destination file or at `context/patterns/jq-escaping-workarounds.md`
  directly — otherwise this is a silent behavior loss, not a clean extraction.
- No test file greps literal text out of either extraction region. One test
  (`test-session-runtime-files.sh`) does grep `orchestrate.md` for literal strings
  (`file_session_id`, `mt_state_file_valid`), but those live in Step 5 (Commit Reconciliation,
  ~lines 425-434) — entirely outside the `## Batch Orchestrate Results` fence (lines 555-691).
  `lint-state-writer-boundary.sh` allowlists `todo.md` for a `mv .../state.json` pattern that
  lives in Step 5.7.4 (vault operation, ~line 866) — also outside `## Notes` (line 1028-EOF).
  Existing tests should pass unmodified as long as the extraction touches only the two named
  regions.
- `orchestrate.md` is on the orchestrator-critical-path Inclusion Table (row 3) in
  `batch-orchestration-guardrails.md`, and this very research dispatch is running under
  `orchestrator_mode: true` (i.e., inside a live `/orchestrate 56` invocation) — a genuine
  self-modification case. Per that same table's Reachability test, the self-modification
  admission gate is **multi-task-only** ("single-task `/orchestrate` never has siblings to worry
  about"); a solo `/orchestrate 56` implement dispatch will not trip it. It becomes live only if
  task 56 is ever co-dispatched in a batch alongside another task.
- The standing task to slim `commands/task.md` (task_number 44, `not_started`) rests on a premise
  that does not hold up structurally, and is further weakened by a byte-count fact worth
  recording explicitly: `task.md` (37,465 B) is not even the largest of the three command files
  by raw size — `todo.md` (49,254 B) and `orchestrate.md` (43,180 B) are both bigger. See
  Decisions for the explicit recommendation.
- `dependencies: [48]` on task 56's own state.json entry is an auto-added file-scope-overlap edge
  (Multi-Task Creation Standard Component 4a), not a human-authored ordering statement, and has no
  effect on this single-task `/orchestrate 56` dispatch — see Decisions for why this is not a
  contradiction of the task description's "this work will land first" framing.

## Context & Scope

Re-measure and confirm the two extractable regions the task description identified in
`agent-system/extensions/core/commands/todo.md` and
`agent-system/extensions/core/commands/orchestrate.md`; identify every internal or external
pointer that must be updated so the extraction preserves behavior; check for test coverage that
greps literal text out of either file; assess the self-modification hazard for `orchestrate.md`
given this dispatch's own `orchestrator_mode: true`; investigate the overlap with the
not-yet-run scoped-commit-propagation task (task_number 48) at its `git commit -m` call sites;
and independently verify the standing task.md-slimming premise (task_number 44).

## Findings

### File sizes (re-measured, source store)

```
49254 agent-system/extensions/core/commands/todo.md
43180 agent-system/extensions/core/commands/orchestrate.md
37465 agent-system/extensions/core/commands/task.md
```

Byte-identical to the audit figures in the task description — no drift, unlike the orchestrate
skills' +12%/+19% drift the task description warned about.

### Region 1: `todo.md`'s `## Notes` section

- Location: line 1028 to EOF (line 1195), 168 lines, **7,851 bytes** (`awk '/^## Notes/{flag=1}
  flag' commands/todo.md | wc -c`) — exact match to the task description's ~7,851 B estimate.
- Five subsections, each pure reference/explanatory material that restates or elaborates on
  concepts the Execution section (lines 1-1027) already implements procedurally:
  - `### Task Archival` (21 lines) — archivable-status definitions, archive routing rules,
    subtasks-defer guard rationale, recovery pointer
  - `### Orphan Tracking` (18 lines) — the two orphan categories and their actions
  - `### Misplaced Directories` (31 lines) — definition, a directory-category summary table,
    causes, recovery
  - `### Roadmap Updates` (68 lines) — matching-strategy explanation (delegated to
    `roadmap-integration.sh`), producer/consumer workflow, annotation format examples, safety
    rules, date/reason formatting notes, "well-formed completion summary" examples
  - `### jq Pattern Safety (Issue #1132)` (28 lines) — already mostly duplicate: it restates the
    problem and gives three example patterns, then ends with "See
    `.claude/context/patterns/jq-escaping-workarounds.md` for comprehensive patterns" — i.e. the
    canonical version of this content already lives outside the command body.
- **Cross-reference INTO this region from the Execution section that must be repointed**: line
  144-149 (Step 3, subtasks-defer guard) reads "Use a `case` statement for status classification,
  per the jq/shell escaping guidance in the Notes section (never `!=`)". After extraction this
  must become an explicit pointer to wherever the jq-safety subsection lands (either the new
  extraction destination, or directly to `context/patterns/jq-escaping-workarounds.md`, which
  already exists and already carries this exact guidance in full). Leaving the words "the Notes
  section" in place after the section is gone would be exactly the silent-deletion failure mode
  the task description's PRESERVE BEHAVIOR clause warns against.
- No other line in the Execution section (1-1027) says "see Notes" or equivalent — this is the
  only internal pointer requiring a fix-up.

### Region 2: `orchestrate.md`'s `## Batch Orchestrate Results` output template

- Location: the fenced ` ```markdown ... ``` ` block at lines 555-691 (137 lines, **6,648
  bytes** for the fence content alone; 6,674 B if the immediately preceding
  "**Consolidated Output**:" label line is included). Close to, slightly under, the task
  description's ~6,739 B estimate — the difference is measurement-boundary noise (whether the
  label line and the code-fence markers themselves are counted), not drift.
  is only reached from `#### Step 5: Commit Reconciliation and Consolidated Output`, itself
  reached only via `### MULTI-TASK DISPATCH` (`len(TASK_NUMBERS) > 1`). It renders once, at the
  end of a multi-task batch invocation, and is never referenced or needed by a single-task
  `/orchestrate N` invocation.
- The template is dense with embedded rendering rules (nine `###`-level subsections: ZERO
  DISPATCH, Succeeded, Failed, Skipped, Deferred (self-modifying), Deferred (other admission
  exclusions), Deferred (redeploy checkpoint), Pre-Existing Deploy-Verify Failures (Not Deferred),
  System Defects Detected, Next Steps), each carrying its own "rendered only when X" / "populated
  from Y" gating prose interleaved with the literal markdown to emit. This makes it a genuine
  "template to follow," not passive prose — the pointer that replaces it must be phrased as an
  imperative ("this template MUST be followed exactly," per the task description's own
  distinction between a followed pointer and a silent deletion), not a soft "see also."
- No cross-reference from elsewhere in `orchestrate.md`'s Execution section points INTO this
  specific block by name (nothing else says "see Batch Orchestrate Results" or similar), so
  unlike Region 1 there is no second internal pointer to fix up — only the call site itself
  (Step 5, immediately before the fence) needs to become the pointer.
- Everything surrounding the fence (Steps 1-5's prose, the "Exit-path coverage" table, the
  "Re-run sequence derivation" note) is decision logic/derivation instructions that stays inline;
  only the literal markdown-to-emit fence is the extraction candidate.

### Test coverage / literal-text-grep hazard (the investigative angle this task named explicitly)

Checked every `scripts/tests/*.sh` and `scripts/lint/*.sh` file that references either command
file by path:

| File | What it does with todo.md/orchestrate.md | Touches either extraction region? |
|------|-------------------------------------------|-------------------------------------|
| `scripts/test-session-runtime-files.sh` | Greps `orchestrate.md` (via `$ORCHESTRATE_MD`) for literal strings `file_session_id`, `file_session_id.*=.*batch_session_id`, `mt_state_file_valid` (Case 2, foreign-session detection) | No — these live in Step 5 (Commit Reconciliation, ~lines 425-434), well before the `## Batch Orchestrate Results` fence (555-691) |
| `scripts/lint/lint-state-writer-boundary.sh` | Allowlists `agent-system/extensions/core/commands/todo.md` for the literal `mv "${vault_path}/archive/state.json" "${vault_path}/state.json"` pattern in Step 5.7.4 (vault operation, ~line 866) | No — Step 5.7.4 is well before `## Notes` (line 1028-EOF) |
| `scripts/tests/test-roadmap-items-producer.sh` | References `commands/todo.md` only in comments, to explain that its `derive_roadmap_no_match` shell function is a faithful re-implementation (mirror, not a grep) of the jq expression `/todo` Step 3.5.5 uses | No — comment-only; the actual test logic never reads `todo.md`'s file content, so it is unaffected regardless of which section moves |
| `scripts/test-double-loading-check.sh` | Fixture path is literally named `"fixture/orchestrate.md"` — this is an unrelated fixture filename for `validate-context-budgets.sh`'s redundancy check, not a reference to the real command file | No — coincidental name collision only |
| `scripts/orchestrate-dry-run-report.sh`, `orchestrate-predispatch-review.sh`, `orchestrate-triage-classify.sh`, `assess-repo-health.sh` | Comments only, pointing a human reader at the corresponding step in the `.md` file for context; none execute a grep against the `.md` file's content | No |

**Conclusion**: no test file greps literal text out of either target extraction region. The one
real content-dependency (`test-session-runtime-files.sh` Case 2) and the one allowlist reference
(`lint-state-writer-boundary.sh`) both sit in parts of the command bodies this task does not
touch. Existing tests should pass unmodified, provided the extraction is scoped exactly to the
two named regions and does not touch Step 5 (orchestrate.md) or Step 5.7 (todo.md) content.

### Self-modification hazard for `orchestrate.md` (investigative angle 2)

This research dispatch is itself running with `orchestrator_mode: true` — i.e., the currently
active `/orchestrate 56` invocation loaded `commands/orchestrate.md` as its own command body,
and task 56's `file_scope` names that same file as an edit target. Two facts bound the actual
risk:

1. `commands/orchestrate.md` is row 3 of the ten-file Inclusion Table in
   `context/patterns/batch-orchestration-guardrails.md`'s "Self-Modification Hazard" section — it
   IS one of the orchestrator-critical paths the admission gate exists to protect.
2. That same document's "Reachability" test states plainly: "Single-task `/orchestrate` never has
   siblings to worry about, so a file that is only reachable [on the MULTI-TASK batch-dispatch
   path] is out of scope for this specific gate." The self-modification admission check
   (`orchestrate-batch-admit.sh`'s `self_modifying` defer_reason) is invoked only from
   `skill-orchestrate`'s Stage MT-3 step 4.5, on the multi-task path.

Net effect: a solo `/orchestrate 56` implement dispatch (task 56 alone, not co-batched) will not
trip the self-modification gate at all — there is no sibling to defer against. The hazard becomes
live only if a future `/orchestrate` invocation batches task 56 alongside another task; in that
case the implementer should expect the batch admission report to defer task 56 (or its
co-dispatched sibling) at least one wave/cycle unless `--allow-self-modifying` is passed. Separately,
editing the source-store file mid-loop does not retroactively change the currently-loaded command
prompt (Claude Code does not re-read `commands/orchestrate.md` mid-invocation), and the one
sanctioned automated redeploy call site (`skill-orchestrate` Stage MT-3 step 7, per
`context/patterns/regeneration-is-manual-only.md`'s "Automated Exception" section) is itself
multi-task-only — so a solo implement dispatch for task 56 has no automated mid-loop redeploy to
worry about either.

### Overlap with task 48 (scoped-commit propagation) — what it will need to rebase around

Confirmed by grep for `git commit -m` and `git-commit-scoped.sh` in both files:

```
orchestrate.md:760  (prose) commit via `.claude/scripts/git-commit-scoped.sh`
orchestrate.md:790  bash .claude/scripts/git-commit-scoped.sh \
orchestrate.md:799  bash .claude/scripts/git-commit-scoped.sh \
todo.md:942  git commit -m "todo: archive {N} completed tasks"
todo.md:948,951,954,957,960,963  (six more raw `git commit -m` variants)
```

- `orchestrate.md` is **already migrated** — it is one of the 5 files task 48's own description
  names as already calling `git-commit-scoped.sh` (CHECKPOINT 3: COMMIT, lines 757-806). Task 48
  needs to do nothing to `orchestrate.md`.
- `todo.md`'s 7 raw `git commit -m` call sites all live in `### 6. Git Commit` (Step 6, lines
  938-964) — entirely BEFORE `## Notes` (line 1028) in file order.
- **What task 48 will need to rebase around**: essentially nothing. Because Step 6 sits before
  `## Notes` in the file, removing the trailing `## Notes` section does not shift a single line
  number inside Step 6 — `git status --porcelain` line offsets for task 48's target lines
  (938-964) are unaffected by this task's edit. The only change task 48 will see is a smaller
  total file (fewer lines after Step 7's end), which does not affect a content-based `grep '
  git commit -m'` migration at all. There is no line-number-based tooling anywhere in this repo
  that would be confused by the shift (all lint/test references found above use content greps,
  never fixed line numbers). Sequencing order between the two tasks (this one first, task 48
  second) is safe in either direction for `todo.md`; for `orchestrate.md`, task 48 has literally
  no work to do regardless of order.

### `dependencies: [48]` vs. the task description's "this work will land first" (Decisions)

Task 56's own `specs/state.json` entry lists `"dependencies": [48]`, which at first read appears
to contradict the task description's framing ("That work has NOT yet run... this work will land
first"). Reconciled: `dependencies: [48]` is the auto-added file-scope-overlap serialization edge
from Multi-Task Creation Standard Component 4a (both tasks' `file_scope` name `todo.md` and
`orchestrate.md`), not a human-authored statement of narrative order. Per
`commands/orchestrate.md` MULTI-TASK DISPATCH Step 2, `dependencies[]` is consulted **only** for
multi-task wave assignment (Kahn's-algorithm topological sort across a batch). CHECKPOINT 1: GATE
IN for a **single-task** `/orchestrate N` dispatch "only blocks on terminal states: completed,
abandoned, expanded" — it never reads `dependencies[]` at all. This dispatch (`task_number: 56`,
not `multi_task_mode`) is exactly that single-task path, which is why research proceeded despite
task 48 still being `not_started`. No action is needed to reconcile this; it is recorded here so a
future reader does not mistake the auto-added edge for an ordering directive that this task or
task 48 is violating.

### Independent verification of the task.md-slimming premise (task_number 44, `not_started`)

Read `commands/task.md` end to end (944 lines, 37,465 B). Structure: a mode-detection stanza plus
six top-level mode sections (`Create Task Mode`, `Recover Mode`, `Expand Mode`, `Sync Mode`,
`Review Mode`, `Abandon Mode`), closing with a 15-line `## Constraints` section. Findings:

- **Byte count alone already weakens the premise**: `task.md` (37,465 B) is the *smallest* of
  the three files measured in this task, not the largest — `todo.md` is 49,254 B (31% bigger) and
  `orchestrate.md` is 43,180 B (15% bigger). Whatever "largest per-invocation context
  contributor" claim task 44 rests on must be about combined body-plus-import token cost, not raw
  command-body bytes, and even then the premise needs re-derivation rather than being taken as
  given.
- **Structurally, almost everything in `task.md` is decision logic and dispatch instructions
  specific to whichever mode is active** (jq/bash steps, `AskUserQuestion` schemas, state-write
  filter expressions) — the same category CLAUDE.md and this task's own instructions treat as
  "must stay inline," not extractable reference material.
- The one candidate reference block found — `### Standards Reference (--review mode)` (18 lines,
  ~700 B) — already points at `.claude/docs/reference/standards/multi-task-creation-standard.md`
  rather than restating it, and carries only a compact compliance table plus one clarifying
  sentence. There is no `## Notes`-style appendix, no large standalone output-formatting template
  comparable to `orchestrate.md`'s Batch Results block, and no example-narrative bloat.
  Re-checked the one apparent counter-example — a `## Task Review: #{N} - {slug}` heading inside
  Review Mode's Step 4 — and confirmed it is a 22-line fenced display template tightly coupled to
  the immediately following procedural steps (5-9), not a movable reference appendix.
- **Verdict: the premise does not hold, on both grounds** — the file is not the largest by raw
  size among the three measured here, and its content does not contain a comparable-sized
  extractable reference region. Estimated extractable material: roughly 0-1 KB (the Standards
  Reference table, if moved at all), consistent with the task description's own claim.

## Decisions

- Extract `todo.md`'s `## Notes` section (7,851 B, lines 1028-EOF) to a new
  `context/patterns/` file (suggested: `context/patterns/todo-archival-reference.md`), leaving an
  imperative "follow this pointer" instruction in its place, and repoint the Step 3 internal
  cross-reference (line 148, "the Notes section") at either that new file or directly at the
  already-existing `context/patterns/jq-escaping-workarounds.md` (which already carries the exact
  jq/shell-escaping content in full — the todo.md `### jq Pattern Safety` subsection is largely
  redundant with it already).
- Extract `orchestrate.md`'s `## Batch Orchestrate Results` fenced template (6,648 B, lines
  555-691) to a new `context/patterns/` file (suggested:
  `context/patterns/orchestrate-batch-results-template.md`), replacing it at the Step 5 call site
  with an imperative pointer stating the template MUST be followed exactly (matching the task
  description's own distinction between a followed pointer and a deletion).
- Both new destination files must be registered in `agent-system/extensions/core/index-entries.json`
  (the source-store file that merges into deployed `.claude/context/index.json`) with
  `load_when.commands` set to `["/todo"]` and `["/orchestrate"]` respectively and
  `load_when.agents: []` — matching the existing pattern for `patterns/roadmap-update.md` and
  `patterns/batch-orchestration-guardrails.md`. An empty `agents[]` alongside a populated
  `commands[]` is the "direct command, not agent-dispatched" shape `test-double-loading-check.sh`
  Case 2 confirms never trips the redundancy check.
- Recommendation for task 44 (`slim_task_command_body`, `not_started`): **drop it, recording the
  reason** (structural analysis in this report contradicts its premise on two independent
  grounds: `task.md` is the smallest of the three command files by raw byte count, and it
  contains no `## Notes`-style or output-template-style extractable region — only ~0-1 KB of
  reference material, already pointer-based). Re-pointing task 44 at `todo.md`/`orchestrate.md`
  is unnecessary since this task (56) already covers both. If the original premise's concern was
  actually about `task.md`'s *imported* context files (the "~2.8k tokens of imports" the task
  description mentions) rather than the command body itself, that is a different lever
  (import-chain trimming) and would need a freshly-scoped task, not a repoint of task 44 as
  currently worded.

## Risks & Mitigations

- **Risk**: leaving the line-148 "Notes section" cross-reference unrepointed after extraction
  would be a silent behavior loss per the task's own PRESERVE BEHAVIOR clause. **Mitigation**:
  explicitly listed above as a required edit, not left implicit.
- **Risk**: an implementer paraphrasing the `## Batch Orchestrate Results` template instead of
  moving it verbatim would lose the interleaved per-section gating rules (nine `###`-level
  "rendered only when X" conditions). **Mitigation**: move the fence content verbatim; the pointer
  replacing it should state "MUST be followed exactly," not "see also."
- **Risk**: touching Step 5 (orchestrate.md, lines ~420-534) or Step 5.7 (todo.md, lines
  ~811-937) while doing the extraction would break `test-session-runtime-files.sh` Case 2 or
  `lint-state-writer-boundary.sh`'s allowlist assumption. **Mitigation**: scope the diff strictly
  to the two named regions plus their call-site pointer text; do not touch either of those two
  areas.
- **Risk (low)**: a future co-batched `/orchestrate` run including task 56 alongside another task
  could trip the self-modification admission gate on `orchestrate.md`. **Mitigation**: none
  needed proactively — the existing `--allow-self-modifying` flag and defer-then-retry semantics
  already handle this; solo dispatch (the expected path) is unaffected.

## Context Extension Recommendations

- None beyond the two new `context/patterns/` files this task itself will create as part of its
  own extraction work (not a gap in unrelated documentation).

## Appendix

### Search queries / commands used

- `wc -c` on all three command files (re-measurement)
- `awk '/^## Notes/{flag=1} flag' commands/todo.md | wc -c` (Region 1 exact byte count)
- `sed -n '555,691p' commands/orchestrate.md | wc -c` (Region 2 exact byte count)
- `grep -rn "commands/todo.md\|commands/orchestrate.md"` across `agent-system/extensions/core/scripts/`
  (test/lint literal-reference survey)
- `grep -n "git commit -m\|git-commit-scoped.sh"` in both target files (task 48 overlap check)
- `jq -r '.active_projects[] | select(.project_number==44 or .project_number==48)'` against
  `specs/state.json` (standing-task cross-checks)
- Read of `context/patterns/batch-orchestration-guardrails.md`'s Self-Modification Hazard section
  and Inclusion Table
- Read of `context/patterns/regeneration-is-manual-only.md`'s Automated Exception section
- Read of `agent-system/extensions/core/index-entries.json` entries for
  `patterns/jq-escaping-workarounds.md` and `patterns/roadmap-update.md` (registration pattern)

### References

- `agent-system/extensions/core/commands/todo.md`
- `agent-system/extensions/core/commands/orchestrate.md`
- `agent-system/extensions/core/commands/task.md`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
- `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md`
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh`
- `agent-system/extensions/core/scripts/test-session-runtime-files.sh`
- `agent-system/extensions/core/scripts/tests/test-roadmap-items-producer.sh`
- `agent-system/extensions/core/scripts/tests/test-double-loading-check.sh`
- `agent-system/extensions/core/index-entries.json`
