# Research Report: Clear Failing Verification Gates and Reconcile Defect/Review Ledgers

- **Task**: 47 - Clear the two failing verification gates and reconcile the defect/review ledgers against reality
- **Started**: 2026-08-11T21:41:00Z
- **Completed**: 2026-08-11T22:20:00Z
- **Effort**: 1-2 hours (mostly registration/bookkeeping; no design work)
- **Dependencies**: None
- **Sources/Inputs**: `specs/state.json`, `specs/errors.json`, `specs/reviews/state.json`, `specs/reviews/*.md`, `.claude/scripts/validate-state.sh --deep`, `.claude/scripts/generate-context-line-counts.sh --check`, `.claude/scripts/verify-deploy.sh --findings`, `.claude/scripts/check-extension-docs.sh`, `agent-system/extensions/core/index-entries.json`, `agent-system/extensions/core/hooks/validate-handoff-location.sh`, `agent-system/extensions/core/scripts/errors-append.sh`, `tests/run-all.sh` (both source-store and deployed copies)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Item 1 (duplicate `project_number` 41) is ALREADY RESOLVED.** A prior same-day commit
  (`4c4c59ef7 "sync: resolve duplicate task number and wire orchestration dependencies"`)
  renumbered the directory-less duplicate to 51 and advanced `next_project_number` to 52.
  `validate-state.sh --deep` currently exits 0 with 15/0/0 (passed/warnings/failed). **No further
  action is required for this item** beyond leaving it alone.
- **Item 2 (doc-lint) is confirmed live and unfixed**: exactly the 2 `line_count` mismatches
  (`architecture/context-layers.md` 134→194, `patterns/context-discovery.md` 375→379, both in
  core) plus the 1 missing index entry (`context/standards/task-reference-exemptions.md`, present
  in the source store and deployed tree but registered nowhere in `index-entries.json`/`index.json`).
  The third mismatch named in the task description (`project/literature/domain/literature-index.md`,
  117→144) was **already fixed** in an earlier commit today (`7822f50cb`, task 38 phase 7) — it now
  reads 144/144 and is not part of what's left to do. `verify-deploy.sh --findings` currently
  reports **22/23**, with all 3 remaining findings inside gate 3 (doc-lint), matching the task
  description's expected shape exactly.
- **Item 3 (ledger drift) largely confirms the task description, with one extra find**: all three
  named `errors.json` entries (`hook_regex_defect`, `test_suite_deployed_mode_failures`,
  `test_suite_failure_undocumented`) are demonstrably fixed in the current tree, with evidence
  below. A fourth entry, `lock_session_self_contention`, also shows strong (but not
  execution-verified) evidence of being fixed — flagged separately, not asserted with the same
  confidence as the three named entries. `deploy_ghost_index_entries` is confirmed **still live**
  (correctly stays unfixed and out of this task's scope). `specs/reviews/state.json` is missing 2
  of 6 on-disk review reports (`review-2026-07-29-agent-system.md`,
  `review-2026-08-10-agent-system-refactor-capstone.md`); both are registerable with concrete
  data pulled from their contents, though `review-2026-07-29` has no severity taxonomy in its own
  text and requires an explicit (documented) choice at plan/implementation time.
- **Postflight auto-closure is not cheaply automatable as a semantic match**, but a narrow,
  cheap partial automation exists: `errors-append.sh update` already supports exactly this
  operation (`--fix-status fixed --fix-task N`) and currently has **zero callers anywhere in the
  codebase** — the tool to close ledger entries exists but nothing invokes it. See Recommendations.

## Context & Scope

Task 47 is scoped as pure bookkeeping/reconciliation across three independent verification
surfaces: `specs/state.json` (task numbering), the doc-lint layer that feeds
`verify-deploy.sh` gate 3, and two drifted ledgers (`specs/errors.json`,
`specs/reviews/state.json`). The task explicitly excludes deciding the declared-vs-deployed
parity question and the 4-orphan-file resolution (both belong to a separate,
already-existing `resolve_deploy_orphan_file_parity` task). This report verifies current state
against the task's claims, distinguishes what is already fixed from what remains, and gathers
the concrete data needed to fix the remainder without further investigation.

## Findings

### Item 1 — Duplicate `project_number` 41 (state.json)

- **Already fixed**, not by this task. `git log --oneline -5 -- specs/state.json` shows commit
  `4c4c59ef7` (`"sync: resolve duplicate task number and wire orchestration dependencies"`,
  same day) with commit body: *"Renumbered the directory-less duplicate 41 to 51; added
  territory- and baseline-based dependencies..."*.
- Current state: `project_number: 51` now belongs to `move_session_state_files_out_of_specs_root`
  (the entry that had no directory); `project_number: 41` still correctly belongs to
  `eager_context_measurement_harness` (which has `specs/041_eager_context_measurement_harness/`).
  `next_project_number` is `52`. `jq '[.active_projects[].project_number] | group_by(.) |
  map(select(length > 1))' specs/state.json` returns `[]` — no duplicates anywhere.
  `specs/051_move_session_state_files_out_of_specs_root/` now exists on disk.
- `bash .claude/scripts/validate-state.sh --deep` output: **15 passed / 0 warnings / 0 failed**,
  including the specific `--deep` check "All active_projects[].project_number values are unique"
  (PASS) and "TODO.md is in sync with specs/state.json (regenerated content is byte-identical)"
  (PASS) — confirming `generate-todo.sh` was already re-run as part of that commit.
- **Conclusion**: no work needed. A plan/implementation phase for this item should be a
  verification-only step (re-run `validate-state.sh --deep`, confirm 0 FAIL), not a fix.

### Item 2 — Doc-lint failures (verify-deploy.sh gate 3)

Confirmed via `bash .claude/scripts/generate-context-line-counts.sh --check`:
```
core: 'architecture/context-layers.md' mismatch: declared 134, actual 194
core: 'patterns/context-discovery.md' mismatch: declared 375, actual 379
core: 135 entries, 133 exact, 2 mismatch, 0 null, 0 missing source
...
literature: 15 entries, 15 exact, 0 mismatch, 0 null, 0 missing source
Total entries checked: 483; Exact match: 481; Numeric mismatch: 2
```
- Only **2** numeric mismatches remain (both core), not 3. The literature mismatch
  (`project/literature/domain/literature-index.md`, declared 117) was already corrected to 144 in
  commit `7822f50cb` ("task 38 phase 7: activate literature extension, deploy, and verify byte
  identity") — confirmed via `git log -p -1 -- agent-system/extensions/literature/index-entries.json`,
  which shows `- "line_count": 117, + "line_count": 144,` already landed, and the file itself is
  144 lines on disk. **No action needed for the literature entry.**
- Both remaining core mismatches are pure `--write` corrections: `wc -l` on the actual files
  confirms 194 and 379 lines respectively, matching the `--check` output exactly.
- **Missing index entry** (Rule S): `agent-system/extensions/core/context/standards/task-reference-exemptions.md`
  exists in the source store (103 lines) and is deployed at
  `.claude/context/standards/task-reference-exemptions.md`, but has **zero** entries anywhere —
  not in `agent-system/extensions/core/index-entries.json`, not in `.claude/context/index.json`.
  Confirmed via `check-extension-docs.sh`'s exact failure text: `FAIL: Rule S: deployed
  context/standards/task-reference-exemptions.md has no entry in .claude/context/index.json`.
- **Important mechanical note for the plan**: Rule S checks the *deployed* `.claude/context/index.json`,
  which is generated from `index-entries.json` during a deploy/regenerate cycle (`check_deployed_index_orphans`
  comment in `check-extension-docs.sh` explains this is deliberately filesystem-enumerated, not
  git-tracked, because `.claude/` is gitignored). **Editing only the source-store
  `index-entries.json` will not by itself clear gate 3 or Rule S** — a redeploy/regenerate step
  (e.g. `deploy-headless.sh` or the picker's `[Regenerate]`) is required afterward for
  `.claude/context/index.json` to pick up both the corrected line counts and the new entry, before
  `verify-deploy.sh --findings` will report 23/23.
- **Schema/content reference for the new entry** — the file's purpose (companion doc to
  `rules/no-task-references-in-deliverables.md`, describing the 7-category exemption taxonomy)
  and neighboring `subdomain: "standards"` entries (e.g. `standards/census-methodology.md`) give a
  concrete shape to draft from:
  ```json
  {
    "path": "standards/task-reference-exemptions.md",
    "domain": "core",
    "subdomain": "standards",
    "summary": "Task-number citation exemption taxonomy and enforcement narrative, companion to rules/no-task-references-in-deliverables.md",
    "line_count": 103,
    "keywords": ["standards", "task-reference", "exemptions", "no-task-references", "deliverables"],
    "topics": ["quality"],
    "load_when": { "agents": [], "task_types": [], "commands": [] },
    "on_demand": true
  }
  ```
  (Modeled on the `architecture/context-layers.md` / `patterns/context-discovery.md` entries,
  which use the same `on_demand: true` + empty `load_when` shape for docs loaded via plain
  backticked reference rather than eager `@`-import or a specific agent/command hook.)
- `verify-deploy.sh --findings` run in full confirms **22/23**, single failing gate is gate 3,
  with exactly these 3 `FINDING gate3 ... FAIL` lines and nothing else — no other gate is
  affected by this item.

### Item 3 — Ledger drift

#### errors.json: verified-fixed entries

All verification below is evidence gathered by reading current source, not by trusting the task
description's assertions.

1. **`hook_regex_defect`** (`err_1786349061492_XpY38x`) — claim: `validate-handoff-location.sh`'s
   3-digit regex blocks 4+-digit task directories. **Confirmed fixed**: both
   `agent-system/extensions/core/hooks/validate-handoff-location.sh:65` and the deployed
   `.claude/hooks/validate-handoff-location.sh:65` read
   `'(^|/)specs/(OC_)?[0-9]{3,}_[^/]+/\.orchestrator-handoff\.json$'` — the `{3,}` quantifier (not
   `{3}`) already matches 4+-digit directories. Both source and deployed copies agree.
2. **`test_suite_deployed_mode_failures`** (`err_1786368358319_8jwcdo`) and
   **`test_suite_failure_undocumented`** (`err_1786350581305_8cNAZ7`) — claim: `tests/run-all.sh`
   now completes cleanly. **Confirmed fixed**: `bash agent-system/extensions/core/scripts/tests/run-all.sh`
   reports **39 passed, 0 failed, 0 skipped, 39 total**; `bash .claude/scripts/tests/run-all.sh`
   (deployed copy) reports **38 passed, 0 failed, 0 skipped, 38 total**. (The task description's
   "36/36" figure is stale/approximate — the current counts are 39/39 and 38/38 — but the
   load-bearing fact, zero failures in both source-store and deployed modes, holds for both named
   entries.)

#### errors.json: spot-checked, additional candidate (not one of the 3 named)

- **`lock_session_self_contention`** (`err_1786349061524_pY97cE`) — claim: `skill-orchestrate`'s
  per-task lock `acquire` call used a suffixed `${session_id}_${task_num}` while Stage MT-1's
  batch registration used the bare `session_id`, causing self-contention. Current
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` shows the `task-lock.sh
  acquire` call using the **bare** `$session_id` (not suffixed), with an explicit inline comment
  explaining this is deliberate specifically to keep the acquire call aligned with the bare
  `session_id` `session-register` uses, and a further comment at the release call site stating
  "must match the acquire argument above — bare `$session_id`". This is strong textual evidence
  the fix landed, but it was **not execution-verified** (would require an actual multi-task
  `/orchestrate` dispatch, which the task boundary and the 2026-08-10 capstone review both flag as
  presently blocked/risky to run casually). **Recommendation**: close only if the implementer can
  independently confirm (e.g., by re-reading the full MT-1/MT-3/MT-4 call chain, or a scratch
  dry-run) — do not close on this report's evidence alone, since the task explicitly warns "do not
  mass-close on this description's say-so" and this entry was not one of the three named.

#### errors.json: confirmed still unfixed (correctly stays open, out of scope)

- **`deploy_ghost_index_entries`** (`err_1786349061556_LuKGif`) — confirmed still live:
  `orchestration/orchestration-validation.md` and `orchestration/subagent-validation.md` remain
  registered in `.claude/context/index.json` (233 and 313 lines respectively) with **no
  corresponding source file** in `agent-system/extensions/core/context/orchestration/` (only
  `validation.md` exists there, not the two ghost-named files). This is exactly the orphan-file
  parity question the task boundary explicitly excludes — leave as unfixed, do not touch.
- Other unfixed entries (`deploy_nondeterministic_merge`, `deploy_orphan_files_undercounted`,
  `acceptance_criterion_not_instrumented`, `defect_vocabulary_gap`, `delegation_interrupted`) were
  not independently re-verified in this pass; each either requires live-deploy testing
  (`deploy_nondeterministic_merge`), is explicitly the excluded orphan-parity question
  (`deploy_orphan_files_undercounted`), requires tracing runtime instrumentation gaps
  (`acceptance_criterion_not_instrumented`, `defect_vocabulary_gap`), or is a historical record
  with no live fix target (`delegation_interrupted` — the 2026-08-10 capstone review itself
  disposed of this one as "Entry only — historical record, no live fix target"). None should be
  closed by this task.

**Note on task-number references inside errors.json/reviews**: several `errors.json` messages and
the 2026-08-10 review's defect ledger cite specific spawned task numbers (1007-1011) from
*before* a task-number-vault reset — current `active_projects` numbers top out around 51-52, so
those numbers no longer resolve to any live task (confirmed: `jq` lookups for project_number
1007-1011 return nothing in either `specs/state.json` or `specs/archive/state.json`). This is
expected and not itself a defect: `specs/errors.json` and `specs/reviews/*.md` are historical
records (exempted from the no-task-references rule per its `specs/**` scope), and the state.json
vault-reset mechanics documented in `.claude/rules/state-management.md` explain the renumbering.

#### reviews/state.json: registration gap

- `specs/reviews/state.json` currently lists **4** reviews (`_last_updated: 2026-08-11T21:04:00Z`):
  `review-2026-04-10`, `review-2026-05-22`, `review-2026-07-04`, and
  `review-2026-08-11-refactor-completion-and-efficiency` — the last of these is the "fifth" the
  task description says was added by the review that created this task; it is already correctly
  present, so only **2** entries are actually missing, not 3.
- `specs/reviews/` holds **6** report files on disk: the 4 above plus
  `review-2026-07-29-agent-system.md` and `review-2026-08-10-agent-system-refactor-capstone.md`
  — exactly matching the task description's named gap.
- **`review-2026-07-29-agent-system.md`**: an "opening" diagnostic review (5 root causes, 15
  proposed tasks T1-T15). Explicitly states in its own text, Section 3 header: *"Proposed meta
  tasks (for user review — none created)"* — confirmed via full-text search for
  `task [0-9]{3,4}`/`spawn(ed)?`/`creat(e|ing|ed) task` returning no evidence of any task actually
  created by this review. **`tasks_created` should be `[]`.** The review has **no**
  critical/high/medium/low severity classification anywhere in its text (it uses PASS/FAIL-style
  root-cause and wave/task framing instead) — this is a genuine schema-fit gap, not an omission on
  my part; see Recommendations for how to handle it.
- **`review-2026-08-10-agent-system-refactor-capstone.md`**: a verification-gate review with an
  explicit "Defect ledger — all 10 confirmed defects" table (Section 7), stating outright:
  *"Five tasks spawned (1007-1011)"*. Per-defect severities from that table:
  - critical: 1 (`lock_session_self_contention`)
  - high: 2 (`hook_regex_defect`, `deploy_merge_content_loss`)
  - medium: 5 (`deploy_ghost_index_entries`, `defect_vocabulary_gap`,
    `deploy_orphan_files_undercounted`, `test_suite_failure_undocumented`,
    `acceptance_criterion_not_instrumented`)
  - low: 1 (`deploy_nondeterministic_merge`)
  - unclassified/historical: 1 (`delegation_interrupted`, table cell literally `—`, disposition
    "Entry only — historical record, no live fix target")
  `tasks_created: [1007, 1008, 1009, 1010, 1011]` (stale/historical numbers, per the note above —
  consistent with how the 4 already-registered reviews also cite pre-vault-reset numbers like
  402/606/817-819 without renumbering them).

## Decisions

- Item 1 requires **no fix**, only re-verification; do not spend an implementation phase editing
  `state.json` for the duplicate.
- Item 2's literature mismatch requires **no fix**; only the 2 core `line_count` values and the 1
  missing index entry remain.
- Item 2's fix must include a redeploy/regenerate step, not just a source-store edit, or
  `verify-deploy.sh --findings` will continue to report the gate-3 failures against the stale
  deployed `.claude/context/index.json`.
- Item 3 closes exactly the 3 named `errors.json` entries with confidence; `lock_session_self_contention`
  is reported as a strong candidate but left for the implementer's own independent confirmation
  before closing, per the task's explicit "do not mass-close" instruction and because it is not
  one of the three the task description named.
- `deploy_ghost_index_entries` and the other unverified `errors.json` entries are left untouched —
  confirmed or presumed still open, correctly out of this task's scope.
- Both missing review reports are registerable now with concrete, sourced data; `review-2026-07-29`'s
  missing severity taxonomy is flagged as a judgment call rather than silently invented.

## Recommendations

1. **Item 1**: Add a verification-only step — re-run `validate-state.sh --deep`, confirm 0 FAIL —
   and skip any state.json edit for the duplicate.
2. **Item 2**: Run `generate-context-line-counts.sh --write` (source store only touches the 2 core
   mismatches now, since literature is already correct), add the one missing index entry to
   `agent-system/extensions/core/index-entries.json` using the drafted shape above, then redeploy
   (`deploy-headless.sh` or equivalent regenerate path) before re-running
   `verify-deploy.sh --findings` to confirm 23/23.
3. **Item 3 (errors.json)**: Use `errors-append.sh update --id <ID> --fix-status fixed --fix-task 47
   --fixed-date <ISO8601>` for the 3 confirmed entries, each with a `--suggested-action`-style
   note or an accompanying `--message`-visible closing-evidence trail (the `update` subcommand
   only mutates `fix_status`/`fixed_date`/`fix_task`; if per-entry closing evidence beyond that
   needs to live in the record, confirm whether the schema supports an evidence field before
   inventing one — `context/formats/errors-format.md` is the authority). Decide separately (do not
   default silently) whether to also close `lock_session_self_contention` after independent
   confirmation.
4. **Item 3 (reviews/state.json)**: Add both missing review entries using the extracted data
   above. For `review-2026-07-29`'s missing severity taxonomy, two honest options — pick one and
   record the reasoning rather than inventing numbers: (a) record `0/0/0/0` since the review
   created no tasks and diagnosed rather than triaged discrete issues (consistent with how the
   already-registered `review-2026-08-11` entry uses `files_reviewed: 0` for a similarly
   non-diff-based analysis, though that entry does carry real severity counts so the parallel is
   partial), or (b) leave a documented note in the entry (e.g. an extra descriptive field or a
   comment in the commit message) that this review predates/doesn't fit the severity schema.
   Recompute `statistics`: `total_reviews: 6`, `last_review: "2026-08-11"` (unchanged, already
   latest), `total_issues_found` = existing `32` + 07-29's contribution (0 under option (a)) + 9
   from 08-10 (1+2+5+1, excluding the unclassified historical entry) = **41** under option (a);
   `total_tasks_created` = existing `9` + 07-29's `0` + 08-10's `5` = **14**.
5. **Postflight auto-closure question** (explicitly asked by the task): a fully automatic
   semantic match between "a change just landed" and "which `errors.json` entry it fixes" is not
   cheaply automatable — it requires judgment about what a diff actually resolves, which is
   exactly the kind of verification this task itself had to do by hand (reading hook source,
   running test suites, tracing SKILL.md comments). That said, a **narrow, cheap** partial
   automation already has its plumbing in place and is simply unused: `errors-append.sh update`
   supports `--fix-status fixed --fix-task N` and is called from **zero** sites in the entire
   codebase (`grep -rn "errors-append.sh update"` across all extensions matches only the script's
   own usage/doc comments). A future task could let a plan or implementation phase optionally
   declare which `errors.json` id(s) it resolves (e.g. a `resolves_error_ids` field alongside the
   existing plan/completion-data schema) and have postflight call `errors-append.sh update`
   automatically when that field is present and the phase's own verification passed — this
   requires a schema decision and is therefore explicitly **not** something to build inside this
   bookkeeping-only task; record it as a follow-up recommendation rather than implementing it here.

## Risks & Mitigations

- **Risk**: closing an errors.json entry that isn't actually fixed. **Mitigation**: this report
  only recommends closing the 3 entries with direct evidence (regex text match, full green test
  suite runs in both modes); `lock_session_self_contention` is explicitly flagged as needing
  independent confirmation, not auto-closed.
- **Risk**: fixing `index-entries.json` without a redeploy leaves `verify-deploy.sh` still red.
  **Mitigation**: called out explicitly in Item 2's findings and Recommendation 2.
- **Risk**: inventing severity numbers for `review-2026-07-29` that don't reflect the source
  document. **Mitigation**: two explicit, non-fabricated options presented in Recommendation 4;
  no number invented without being labeled as a choice.

## Appendix

- Commands run: `jq` queries against `specs/state.json`, `specs/errors.json`,
  `specs/reviews/state.json`; `bash .claude/scripts/validate-state.sh --deep`;
  `bash .claude/scripts/generate-context-line-counts.sh --check`;
  `bash .claude/scripts/verify-deploy.sh --findings`;
  `bash .claude/scripts/check-extension-docs.sh`;
  `bash agent-system/extensions/core/scripts/tests/run-all.sh`;
  `bash .claude/scripts/tests/run-all.sh`;
  `git log`/`git show`/`git diff` against `specs/state.json`,
  `agent-system/extensions/literature/index-entries.json`,
  `agent-system/extensions/core/index-entries.json`.
- Relevant commits: `4c4c59ef7` (duplicate renumbering), `7822f50cb` (literature line_count fix,
  task 38 phase 7).
- Files read in full or in relevant part: `specs/errors.json`, `specs/reviews/state.json`,
  `specs/reviews/review-2026-07-29-agent-system.md`,
  `specs/reviews/review-2026-08-10-agent-system-refactor-capstone.md`,
  `agent-system/extensions/core/hooks/validate-handoff-location.sh`,
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (targeted sections),
  `agent-system/extensions/core/scripts/errors-append.sh`,
  `agent-system/extensions/core/context/formats/errors-format.md` (targeted sections),
  `agent-system/extensions/core/context/standards/task-reference-exemptions.md`.
