# Code Review Report — Refactor Completion & Token Efficiency

**Date**: 2026-08-11
**Scope**: agent system (`agent-system/extensions/**` source store, `.claude/**` deployed tree, `specs/**` task state)
**Question posed**: *What tasks should I complete to finish the agent system refactor and optimize performance, reducing token consumption, and improve efficiency in general?*
**Reviewed by**: Claude

---

## Summary

- Files/surfaces reviewed: deployed `.claude/` tree (~3.93 MB md/json), 12 rules, 21 commands, 33 skills, 16 agents, 193 context files, 138 scripts/hooks, `specs/state.json` (39 active tasks), `specs/errors.json` (11 entries), `specs/events.jsonl`
- Critical issues: 1
- High priority issues: 5
- Medium priority issues: 7
- Low priority issues: 4

**Headline**: the refactor is closer to done than the capstone gate suggests — `tests/run-all.sh` is green, the handoff-location regex is fixed, routing/parity/contract lints all pass, and the error-tracking layer is demonstrably working in production. What blocks a clean capstone re-run is now mostly *bookkeeping the validators already caught*, not deep structural work. Separately, the token-efficiency picture is materially worse than the completed context-loading audit modelled, and the single largest remaining lever is not eager context at all — it is the inline-bash bulk of the orchestrate skills.

---

## Critical Issues

### C1. A known-fixed concurrency safety bug is unpropagated: 65 of 70 call sites still hand-roll `git commit -m`

**File**: `agent-system/extensions/core/scripts/git-commit-scoped.sh` (the fix) vs 65 command/skill `.md` files (the unfixed call sites)
**Description**: `git-commit-scoped.sh` describes itself as *"the single sanctioned implementation of the scoped-commit contract"* and exists specifically to close a documented concurrency defect — a bare `git commit` sweeping in a file another agent staged but had not yet committed. Only 5 files call it: `skill-implementer`, `skill-planner`, `skill-team-implement`, `skill-orchestrate`, `commands/orchestrate.md`. The other 65 files carrying `git commit -m` (85 occurrences total), including core `research.md`, `plan.md`, `implement.md`, `todo.md`, `task.md`, `errors.md`, `review.md`, still use the vulnerable raw form.
**Impact**: This is not theoretical. This review ran with 8 concurrent peer Claude sessions active on this machine, several in this same repo. Every `/research`, `/plan`, `/task`, `/todo`, `/errors` and `/review` commit is currently capable of capturing another session's staged work. It is also the cleanest live instance of 2026-07-29 root cause 1 ("duplicated mechanism instead of shared mechanism"): the shared mechanism *exists and is correct*; adoption simply stopped at 5 sites.
**Recommended fix**: Migrate call sites to `git-commit-scoped.sh`, highest-traffic core commands first (`research.md`, `plan.md`, `implement.md`, `todo.md`, `task.md`, `errors.md`, `review.md`), then extension skills. Acceptance: `grep -rl 'git commit -m'` outside `git-commit-scoped.sh` and its tests reaches 0.

---

## High Priority Issues

### H1. Duplicate `project_number: 41` fails two verification gates

**File**: `specs/state.json`
**Description**: Two distinct active tasks both carry `project_number: 41` — `eager_context_measurement_harness` (created 16:14:06Z, has directory `specs/041_eager_context_measurement_harness/`) and `move_session_state_files_out_of_specs_root` (created 16:17:10Z, no directory). A concurrent-creation collision; `git log` shows `next_project_number` was already restored past it, but the duplicate entry itself was never renumbered.
**Impact**: `validate-state.sh --deep` FAILs, and via it `verify-deploy.sh` gate 10 FAILs. This is one of exactly two gates standing between the current tree and 23/23. It also means one of the two tasks has no artifact directory and will collide on any artifact write.
**Recommended fix**: Renumber `move_session_state_files_out_of_specs_root` to 47 (the next free number), set `next_project_number` to 48, regenerate TODO.md via `generate-todo.sh`. Route the write through `state-write.sh`.

### H2. Session-start eager context is ~18.5k tokens — 78% above the completed audit's model

**File**: `agent-system/extensions/core/rules/*.md` (`paths:` frontmatter)
**Description**: Task 36's context-loading audit is complete *and deployed* (verified: zero `@`-path tokens remain in `.claude/CLAUDE.md`; the deploy at 09:40 postdates the source edit at 09:09). Its predicted post-deploy eager surface of 41,434 B reconstructs almost exactly — parent chain 3,815 + `.claude/CLAUDE.md` 33,624 + two deliberately-eager rules 4,235 = 41,674 B. But that model counted every `paths:`-gated rule as lazy. In this session, six of them loaded anyway:

| Rule | Bytes | `paths:` glob |
|---|---|---|
| `git-workflow.md` | 11,147 | `["specs/**/*", ".claude/**/*"]` |
| `error-handling.md` | 5,420 | `.claude/**/*` |
| `artifact-formats.md` | 5,360 | `specs/**/*` |
| `state-management.md` | 5,148 | `specs/**/*` |
| `pr-prohibition.md` | 4,628 | `"**/*"` — unconditionally eager |
| `workflows.md` | 759 | `.claude/**/*` |
| | **32,462 B** | |

**Impact**: Actual measured session-start eager load is **74,136 B ≈ 18.5k tokens**, not the modelled 10.4k. In a repo whose entire workflow lives under `specs/**` and `.claude/**`, gating a rule on those globs is nominal laziness, not real laziness — the rule fires every session. The audit's 41% reduction is real within its scope, but the scope excluded the largest remaining eager block.
**Recommended fix**: Treat the rules directory as a deliberate eager budget. Narrow `git-workflow.md` (the largest, 11 KB) to a short eager core — commit-message convention and the forbidden-operations list — and move the staging-scope and git-safety narrative to `context/standards/` behind a backticked path. Same split for `error-handling.md` and `state-management.md`. Slim `pr-prohibition.md`'s 4.6 KB (which includes two CSLib `/pr` subsections that are inert in this deploy) to the ~500 B of actual universal policy. Realistic recovery: ~26 KB ≈ 6.5k tokens off *every* session.

### H3. `/orchestrate` costs ~83k tokens before any work happens; the skill is 73% inline bash with 28 KB duplicated against its hard twin

**File**: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (175,303 B), `.../skill-orchestrate-hard/SKILL.md` (107,121 B)
**Description**: A skill's SKILL.md body is loaded *in full* on every invocation — confirmed: no include, partial, fragment, or compose mechanism exists in `install-extension.sh`, and deploy is a byte-for-byte copy. Measured composition: 72.6% and 74.2% of these two files respectively is fenced bash, and almost all of it sits in large multi-line blocks (17 blocks / 121,413 B in the standard skill; 17 blocks / 76,966 B in the hard one). At least 28,421 bytes across 427 substantive lines are byte-identical between the two files — a floor, since near-duplicates reworded only by a log prefix are not counted. `skill-orchestrate-hard/SKILL.md:956-964` documents this itself: *"HARD-MODE TWIN ... The two MUST stay in sync — this file pair is where a one-sided fix is a known recurring defect class."*

Measured per-invocation budgets (eager 18.5k + command + skill + agent):

| Command | Tokens before work begins |
|---|---|
| `/orchestrate N` | **82.8k** |
| `/distill` | 44.8k |
| `/todo` | 43.8k |
| `/implement N` | 41.3k |
| `/meta` | 37.0k |
| `/plan N` | 34.1k |
| `/research N` | 33.4k |

**Impact**: `/orchestrate` spends roughly a third of a 256k context on boilerplate before reading a single task file — and it is the command intended for the longest, most context-hungry runs. The duplication is simultaneously a correctness liability the files' own authors flag.
**Recommended fix**: Two distinct levers, and the difference matters. (a) Moving *reference prose* to `context/**` saves tokens only on invocations that don't need it. (b) Moving *procedural bash* into an executable script invoked by a one-line `bash .claude/scripts/foo.sh args` removes it from context entirely — the script's source is never loaded. Lever (b) is the strong one and is already the established pattern here (~20 orchestrate-* scripts exist). Extend `skill-base.sh`'s proven `skill_*` shared-function pattern to cover the duplicated Stage 5 logic (staleness gate, stray-handoff sweep, `append_detected_defect`) and the structurally-identical postflight-merge blocks. Estimated ~13k tokens/invocation off `/orchestrate`, ~9-10k off `/orchestrate --hard`, and the "MUST stay in sync" drift class closed by construction.

### H4. A live orchestration cycle since the capstone emitted a schema defect that no task owns

**File**: `specs/events.jsonl`
**Description**: The capstone recorded LIVE CYCLE as BLOCKED on the handoff-location hook's 3-digit regex. That regex is now fixed — `.claude/hooks/validate-handoff-location.sh:65` reads `[0-9]{3,}` — so LIVE CYCLE is unblocked. A real cycle then ran and produced a `system_defect` event of class `OFF_SCHEMA_STATUS`: the handoff was written with key `dispatch_status` instead of the schema-required `status`. A second new event, `META_MISSING_AFTER_NARRATION`, fired during dispatch for task 25. `events.jsonl` now carries **5** `system_defect` events (3 pre-existing from 2026-08-08, plus these 2 from 08-10 and 08-11).
**Impact**: The capstone's LIVE CYCLE sub-item 4 requires the deferred-defect surface to render empty on a clean run. It does not, and the two new entries are genuine live agent-compliance slips caught by correctly-working detectors — not false positives. No open task addresses either recurrence, so the gate cannot re-run clean and nothing owns the decision.
**Recommended fix**: One task to decide and act: either fix the handoff writer's key name (`dispatch_status` → `status`) and harden against the meta-narration slip, or re-scope acceptance sub-item 4 to "no *new* defect classes" — the same precedent §9.3 already set for the gate-out item. Either resolution beats the current silent ambiguity.

### H5. The error ledger has drifted out of sync with reality

**File**: `specs/errors.json`
**Description**: 11 entries, 10 marked `unfixed`. At least three are demonstrably fixed in code: `hook_regex_defect` (the regex now reads `[0-9]{3,}`), `test_suite_deployed_mode_failures` and `test_suite_failure_undocumented` (task 12 completed; `run-all.sh` reports 36/36). Related: `specs/reviews/state.json` records 3 reviews and `_last_updated: 2026-07-04`, while 4 review reports exist on disk — the 2026-07-29 and 2026-08-10 reviews were never registered.
**Impact**: 2026-07-29 root cause 3 ("the error-tracking layer is fiction") was closed by *building* the layer, but nothing closes entries when fixes land. A ledger that only ever grows is as uninformative as no ledger: an operator reading it today would conclude 10 defects are open when the real number is closer to 7, and would re-investigate the handoff regex that is already fixed.
**Recommended fix**: Reconcile the ledger — mark the demonstrably-fixed entries `fixed` with the closing evidence, register the two missing reviews in `specs/reviews/state.json`, and add ledger closure to the postflight path so it is not a manual sweep next time.

---

## Medium Priority Issues

### M1. Doc-lint regressed: 3 stale `line_count` entries + 1 missing index entry
**Files**: `agent-system/extensions/core/index-entries.json`, `agent-system/extensions/literature/index-entries.json`
`verify-deploy.sh` gate 3 FAILs on `context-layers.md` (declared 134, actual 194), `context-discovery.md` (375 vs 379), `literature-index.md` (117 vs 144), plus deployed `context/standards/task-reference-exemptions.md` having no `index.json` entry at all. All four are fallout from task 36's own edits. `generate-context-line-counts.sh --check` confirms exactly 3 numeric mismatches out of 481 entries and `--write` corrects them mechanically. **This plus H1 are the only two gates between the tree and 23/23.**

### M2. The DEPLOY non-determinism finding was recorded as "folded" into a task that does not mention it
**File**: `specs/errors.json` (`err_1786350581240_JyztWt`, `err_1786350581208_23mAsn`)
The capstone's defect ledger dispositions the ordering non-determinism as "folds into task 1009" and leaves the `settings.local.json` content-loss as entry-only. Task 9 (the renumbered successor) discusses only the 4 orphan files — it never mentions ordering or content loss. So capstone DEPLOY sub-item ii has no owner despite the ledger implying one. A fold recorded but not performed is precisely the failure mode a defect ledger exists to prevent.

### M3. The shell test suite is non-deterministic under concurrent sessions
Measured across 5 consecutive runs of `.claude/scripts/tests/run-all.sh`: exit 1, 0, 1, 0, 0 — roughly a 2-in-5 failure rate, with passing runs reporting a clean 36/36. `verify-deploy.sh` gate 8 passed during this review while a standalone run failed minutes later. A gate that passes 60% of the time is not evidence of health in either direction, and it is what let the capstone attribute a real failure to "flaky lock-contention ... not a deploy defect" without confirming that.

### M4. 43 duplicated session-ID one-liners across 35 files
The literal `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')` appears 43 times across 35 command/skill files, while `common_session_id()` in `scripts/lib/common.sh` exists and is already wired into `command-gate-in.sh`. Same shape as C1, lower stakes. Note this review command's own body carries one of the 43.

### M5. The jq Issue #1132 safety block is duplicated across 34 source files
`grep -rl "Issue #1132" agent-system/extensions/` returns 34 files, against a canonical home in `context/patterns/jq-escaping-workarounds.md` and a CLAUDE.md section. Roughly 8 KB of pure duplication, and 8 of those copies sit inside `present/` skills where they are per-invocation cost.

### M6. Topic taxonomy has drifted from the tasks that use it
`specs/state.json`'s `active_topics` omits `context-loading` and `email`, both of which are live topics on tasks 42, 43 and 44 — so `generate-task-order.sh` renders them via its append-extras path with a stderr warning rather than in curated order. Conversely 7 declared topics (`commit-scoping-concurrency`, `cslib`, `memory-improvement-loop`, `neovim`, `status-marker-lifecycle`, `wezterm-notifications`, `workflow-refactor`) now have zero tasks.

### M7. `specs/ROADMAP.md` no longer reflects the work actually being done
The roadmap's Phase 1 is documentation-infrastructure items (manifest-driven README generation, marketplace metadata, CI doc-lint), none of which appear in the 39 active tasks; its Success Metrics reference task 396 and a 14-extension count. Meanwhile the actual workstreams — refactor completion, MCP registration, context efficiency, literature/Zotero — are absent. `/review`'s roadmap-integration step consequently has nothing meaningful to annotate.

---

## Low Priority Issues

### L1. `literature-retrieve.sh` is deprecated by its own header but still deployed
7.9 KB, header reads *"DEPRECATED ... superseded by literature-briefing.sh ... Do not add new usages"*, zero automated callers, yet still declared in `core/manifest.json` `provides.scripts` so it deploys every time. The repo already runs a rigorous quarantine-never-delete convention (`scripts/deprecated/` holds 11 such scripts, removed from `provides`); this one file simply missed the process.

### L2. `/zulip` is live but entirely undocumented in CLAUDE.md
The command and `skill-zulip` are declared in `core/manifest.json` and deployed to `.claude/commands/zulip.md`, but CLAUDE.md has zero mentions — no Command Reference row, no extension section. On-disk-but-undocumented, the inverse of root cause 4.

### L3. `check-runtime-file-tracking.sh` missing from the Utility Scripts table
Legitimately operator-invoked-only, like its five documented siblings, but absent from CLAUDE.md's exception table — so a future dead-code sweep will flag it as an orphan.

### L4. Six stylistic `@.claude/docs/...` references contradict the stated convention
In `meta-builder-agent.md`, `context/architecture/system-overview.md`, `context/architecture/component-checklist.md`, `context/patterns/thin-wrapper-skill.md`. No runtime cost path (they sit inside already-selectively-loaded files), but they model the exact syntax task 36 spent a phase normalizing away.

---

## What is NOT a problem (negative findings worth recording)

Three hypotheses this review tested and rejected, so they are not re-investigated later:

- **`.claude/context/` (1.86 MB, 193 files) contains no orphans.** Every file has a live reference, and `context/index.json` is a real dynamic-discovery layer with documented jq query patterns — a naive "nothing points here" search cannot declare orphans in this directory. Recoverable bytes: 0.
- **`.claude/docs/` (455 KB) costs zero runtime tokens.** CLAUDE.md references it only by backticked path, never `@`-import. It is human/agent reference material, not deploy weight.
- **`.claude/scripts/` is nearly clean.** 136 of 138 scripts have live callers, including ones reachable only through `skill-base.sh`'s dynamic `hooks[$hook_name]` manifest lookup and `run-all.sh`'s glob discovery. Only `literature-retrieve.sh` (L1) and the already-tracked `.opencode/scripts/execute-command.sh` are dead.

Also worth noting against task 44 (`slim commands/task.md`): structural analysis found `task.md` to be procedural and mode-specific, already citing standards by pointer rather than restating them — roughly 0-1 KB is extractable, against `todo.md`'s ~8.75 KB and `orchestrate.md`'s ~6.7 KB. Task 44 appears mis-targeted and should be re-pointed or dropped.

---

## Code Quality Metrics

| Metric | Value | Status |
|--------|-------|--------|
| `verify-deploy.sh --findings` | 21/23 | Fail — gates 3 and 10 |
| `validate-state.sh --deep` | 14 pass / 0 warn / 1 fail | Fail — duplicate `project_number: 41` |
| `check-extension-docs.sh` | Fail | 3 `line_count` + 1 missing index entry |
| `check-task-references.sh` | Pass | 0 unexempted occurrences |
| `lint-routing-wiring.sh` | Pass | |
| `lint-agent-contracts.sh` | Pass | |
| `lint-contract-compliance.sh` | Pass | |
| `lint-state-writer-boundary.sh` | Pass | |
| `verify.lua` parity (gate 5) | Pass | |
| `tests/run-all.sh` | 36/36 when green, ~2-in-5 flake | Warning |
| Open `errors.json` entries | 10 unfixed / 11 | Warning — ≥3 stale |
| `system_defect` events | 5 | Warning — 2 new since capstone |
| Session-start eager context | 74,136 B (~18.5k tok) | Warning — 78% over model |
| Gate suite wall-clock | ~120 s (`check-extension-docs.sh` 38.5 s, `run-all.sh` 65 s) | Info |

---

## Capstone Acceptance Gate — current standing

Re-verified against `review-2026-08-10-agent-system-refactor-capstone.md`'s 14 sub-items:

| Scope | Then | Now |
|---|---|---|
| DEPLOY (6) | 4 PASS, 1 FAIL, 1 CONDITIONAL | Unchanged — sub-item ii (byte-identical twice) still FAIL and now **unowned** (M2); sub-item iii still CONDITIONAL, owned by task 9 |
| GATES (4) | 3 PASS, 1 FAIL | `run-all.sh` **resolved** (task 12); but `check-extension-docs.sh` and `validate-state.sh --deep` **regressed** (M1, H1) — net 21/23, different two gates |
| LIVE CYCLE (4) | 1 PASS, 2 BLOCKED, 1 UNVERIFIABLE | **Unblocked** — regex fixed. Sub-item 2 now demonstrably failing (H4); sub-item 4 failing with 5 events; sub-item 3 still unverifiable, owned by tasks 17 → 13 |

**The shape of the remaining work has changed.** The capstone's blockers were structural; today's are largely bookkeeping the validators already caught. Two of the four outstanding gate failures (H1, M1) are mechanical fixes measured in minutes.

### Root-cause closure

| Root cause (2026-07-29) | Status |
|---|---|
| 1. Duplicated mechanism instead of shared mechanism | **Still live, and C1 is the sharpest instance yet** — the shared mechanism exists, is correct, and reached 5 of 70 sites |
| 2. Verification that silently passes | **Shifted, improved, not closed** — validators now correctly alarm (H1, M1); what is missing is remediation ownership. M3's flaky suite is the residual "silently passes" surface |
| 3. Error-tracking layer is fiction | **Closed as built, open as maintained** — the layer works and caught two real live defects; nothing closes entries when fixes land (H5) |
| 4. Dead machinery documented as live | **Substantially better than hypothesised** — quarantine convention is working; only L1/L2/L3 remain |
| 5. Task treadmill | **Still running** — GATES 1 and 2 regressed between the capstone and this review; fixing `run-all.sh` surfaced gate 3 and gate 10 almost immediately |

---

## Recommendations — the answer to the question asked

Ordered. Each line is a proposed task; the first group is hours, not days.

**Wave 0 — clear the gate (fast, unblocks the capstone re-run)**
1. Renumber the duplicate `project_number: 41` and run `generate-context-line-counts.sh --write` + add the missing index entry. Closes H1 and M1, takes `verify-deploy.sh` from 21/23 to 23/23. *(mechanical)*
2. Reconcile `specs/errors.json` and `specs/reviews/state.json` against reality; wire ledger closure into postflight. Closes H5.

**Wave 1 — the safety fix that stopped propagating**
3. Migrate the 65 raw `git commit -m` call sites to `git-commit-scoped.sh`, core commands first. Closes C1. Highest correctness value in this review, and directly closes root cause 1.

**Wave 2 — token consumption, largest lever first**
4. Extract the duplicated Stage 5 and postflight-merge logic from `skill-orchestrate`/`skill-orchestrate-hard` into shared `skill-base.sh` functions and standalone `orchestrate-*.sh` scripts. ~13k tokens/invocation off `/orchestrate`, and it closes the self-documented "MUST stay in sync" drift class. Closes H3.
5. Re-scope the eager rules budget: split `git-workflow.md`, `error-handling.md`, `state-management.md` into eager cores plus lazy `context/standards/` companions; slim `pr-prohibition.md`. ~6.5k tokens off *every* session. Closes H2. Fold task 41 (eager-context harness) in as the measurement backstop so this cannot silently regress.
6. Extract `todo.md`'s `## Notes` (~7.9 KB) and `orchestrate.md`'s batch-output template (~6.7 KB) to `context/`. Re-point or drop task 44 — `task.md` has almost nothing extractable.

**Wave 3 — finish the capstone's own scope**
7. Own the two post-capstone `system_defect` recurrences: fix the handoff `dispatch_status` → `status` key, decide the `META_MISSING_AFTER_NARRATION` disposition, or re-scope acceptance sub-item 4. Closes H4.
8. Give DEPLOY sub-item ii a real owner — the ordering non-determinism and the `settings.local.json` content-loss re-check that the ledger claimed was folded into task 9 but was not. Closes M2.
9. De-flake `tests/run-all.sh` under concurrent sessions. Closes M3; without it, the capstone's GATES scope cannot be trusted either way.

**Wave 4 — hygiene and doc truth (cheap, batchable)**
10. Dedupe the 43 session-ID one-liners to `common_session_id()` and the 34 jq-safety blocks to a single pointer. Closes M4, M5.
11. Quarantine `literature-retrieve.sh`; document `/zulip` and `check-runtime-file-tracking.sh` in CLAUDE.md; convert the 6 `@.claude/docs/` refs. Closes L1-L4.
12. Reconcile the topic taxonomy (M6) and rewrite `specs/ROADMAP.md` to describe the work actually in flight (M7).

**Already sequenced correctly, no change recommended**: tasks 18 → 9, 17 → 13, 33 → 35 → 37, and the MCP chain 28 → 29 → 30 → 31 → 32.

**One caution on task 32** (the deploy delivery gate): its dependency array and acceptance criteria are scoped to the MCP wave, but `deploy-headless.sh` deploys the entire source store regardless. Either widen its verification to a full source-vs-deploy drift check, or reframe it explicitly as "deploy pass 1 (MCP)" with an anticipated second pass once the Wave 2 and Wave 3 work lands.

---

*Evidence: live runs of `verify-deploy.sh --findings`, `validate-state.sh --deep`, `check-extension-docs.sh`, `generate-context-line-counts.sh --check`, and 5 consecutive `tests/run-all.sh` runs; byte measurement of the deployed `.claude/` tree; fenced-block structural analysis of the orchestrate skills; caller analysis across 138 scripts; and cross-reference against `review-2026-07-29-agent-system.md` and `review-2026-08-10-agent-system-refactor-capstone.md`.*
