# Research Report: Task #50

- **Task**: 50 - Restore verification trust and close hygiene residue
- **Started**: 2026-09-01
- **Completed**: 2026-09-01
- **Effort**: ~2 hours (research only)
- **Dependencies**: Task 48 (completed)
- **Sources/Inputs**: Codebase (`agent-system/extensions/**`), `specs/TODO.md`, `specs/state.json`, `specs/errors.json`, `specs/events.jsonl`, `specs/archive/**`, live gate/script re-execution
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Every count in the filed description has moved since filing, and mostly in the OPPOSITE direction from "degraded"**: the two duplication items (session-ID one-liner, jq #1132 block) are effectively **already resolved**, not degraded. The description's own instruction to re-measure was correct to insist on it — the "most of it DEGRADED since filing" framing does not hold for these two items.
- **Session-ID one-liner is fully closed.** Task 84 (`fix_duplication_gate_scope_and_extensions_root`, archived, completed 2026-08-24) is the exact "duplication-gate task" the description says to sequence after — and it has already landed, already fixed the `*.sh`-only gate blindness, and already migrated all 37 real `.md` offenders plus the 1 real `.sh` offender onto `common_session_id()`. Current count: 14 files match `sess_$(date`, and all 14 are the two library/test files plus 12 deliberately-excluded illustrative-prose sites (`context/`, `rules/git-workflow.md`) — exactly what task 84's own verification recorded. **Nothing remains to do here.**
- **jq #1132 "duplication" is not duplication.** 36 files mention "1132" (matching the filed count exactly), but only 2 files carry the actual multi-line block — `merge-sources/claudemd.md` (the canonical CLAUDE.md source) and `context/patterns/jq-escaping-workarounds.md` (the canonical doc itself). The other 34 are one-to-four-line pointers ("See `jq-escaping-workarounds.md`") already in the exact form item (4b) asks for. **No further pointer-conversion work exists to do; at most a one-line note recording this as verified-closed.**
- **Real, unresolved work remains in exactly four places**: (2) the deploy ordering non-determinism (`err_1786350581240_JyztWt`, still `fix_status: unfixed`) — its sibling error was independently fixed and closed (task 1015) on a "semantic equality under `jq -S`" rationale that was never formally generalized to this one; (3) the live-cycle defect-criterion decision, now considerably better evidenced than at filing (13 defect events across 4 classes today, not 5 across ~3); (5a) `scripts/literature-retrieve.sh` quarantine (mechanical); (6) topic-taxonomy reconciliation and the already-decided ROADMAP.md deletion, which needs a companion fix to `roadmap-integration.sh` or it silently regenerates.
- **Orphan topic count grew past the filed "TEN"**: 13 declared-but-unused topics today, not 10 (four names not in the filed list: `agent-system`, `essential-refactor`, `orchestration-concurrency`, `team-mode-lifecycle`; `neovim` correctly dropped off, confirming the filed note).
- **Three pre-existing `verify-deploy.sh` failures (raised as current-run context, not in the original description) are all real and confirmed live, and none has an owning task.** One (doc-lint manifest-registration gap for 3 test scripts) is a one-line-per-file mechanical fix squarely in this task's "verification trust" theme. The other two (state-schema `--deep` drift, `test-force-phases.sh` state-writer-boundary violations) are recommended as **out of this task's scope**, named explicitly rather than silently dropped, per the same "name residuals rather than forcing them" convention task 48 used.
- **Recommendation: do not expand into multiple tasks.** The volume that justified "reasonable candidate for expansion" at filing time has now largely evaporated (two of the six items are already done). What remains is right-sized for a single two-phase implementation plan (Phase A: the two open decisions in items 2 and 3; Phase B: the five hygiene/mechanical items). See "Split Assessment" below.

## Context & Scope

Per the delegating message, this is a bundle-scoping research pass with an explicit re-measurement mandate: every count in the task description is stale-until-reverified, and several items are explicitly out of scope (item 1, the OFF_SCHEMA_STATUS/META_MISSING_AFTER_NARRATION defect events themselves, and anything already covered by the now-completed CI-expansion/deploy-verification tasks). ROADMAP.md's fate (delete, not rewrite) is decided and not re-litigated here. All measurements below were taken against the current working tree (2026-09-01), after the lifecycle-command deletion and the 105-file scoped-commit migration both landed.

## Findings

### 1. Session-ID one-liner — ALREADY RESOLVED (task 84)

The description said "sequence after" the duplication-gate task rather than duplicating its migration. That task is **task 84, `fix_duplication_gate_scope_and_extensions_root`**, archived at `specs/archive/084_fix_duplication_gate_scope_and_extensions_root/`, completed 2026-08-24T22:27:10Z. Its own filed baseline was 43 → 48 files, 46 of them `.md` — the *exact* numbers task 50's description repeats, confirming this is the same measurement lineage, not a coincidence.

Task 84's summary records: fixed the gate's `*.sh`-only blindness and environment-dependent `EXTENSIONS_ROOT` walk, then migrated the 1 real `.sh` offender and all 37 real `.md` offenders across 7 extensions onto `common_session_id()`.

Re-measured today:
```
grep -rl 'sess_$(date' agent-system/extensions/   # -> 14 files
```
All 14 are: `scripts/lib/common.sh` (the helper's own definition), `scripts/tests/test-common-lib.sh` (its test), and 12 illustrative-prose sites under `core/context/` (11 files) plus `core/rules/git-workflow.md` (1) — deliberately excluded by task 84's plan (positive-construction scan scoped to `commands/`/`skills/`/`agents/`, so narrative documentation showing the pattern as an example is untouched by design). This matches task 84's own verification section line-for-line ("returns exactly 14 files ... matching the plan's own enumeration").

**Nothing remains for task 50 to do on this item.** The description's instruction not to duplicate the migration was correct, but the sequencing dependency has already resolved: the predecessor task landed before this research ran.

### 2. jq Issue #1132 block — the count matches, but it is not duplication

Filed as 34 → 36 files. Re-measured: `grep -rli 1132 agent-system/extensions/` → exactly **36 files**, matching precisely.

However, inspecting what those 36 files actually contain (grepping each for the multi-line marker text — "SAFE pattern", "jq Command Safety", "BROKEN", "escaped as") shows only **2** files carry the real block: `core/merge-sources/claudemd.md` (36 lines, the CLAUDE.md source) and `core/context/patterns/jq-escaping-workarounds.md` (277 lines, the canonical doc). One more, `core/context/standards/error-recovery-strategies.md`, carries a compact 4-line summary-and-pointer, not the full block.

The remaining 33 files — including all 8 `present/` skills the description specifically called out ("8 of those copies sit inside present/ skills where they are per-invocation cost") — carry only short pointers, e.g.:
```
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)
...
**IMPORTANT**: Use two-step pattern to avoid Issue #1132 escaping bug. See `jq-escaping-workarounds.md`.
```
This is already the "calls/pointers" form item (4b) asks the item to be converted to. Someone (plausibly the context-loading/eager-context-reduction work referenced elsewhere in the backlog) already did this conversion; the description's characterization ("roughly 8 KB of duplication ... per-invocation cost") is stale.

**Recommendation**: record this item as verified-closed with the measurement above as evidence. No file edits are needed. If a defect-ledger entry exists asserting this item as open, close it with this finding.

### 3. `@.claude/docs` stylistic refs — confirmed, unchanged in character

Filed as 6 → 15 occurrences. Re-measured: `grep -rn '@\.claude/docs' agent-system/extensions/` → exactly **15** occurrences across 8 files:
`cslib/agents/cslib-implementation-hard-agent.md`, `cslib/agents/cslib-research-agent.md`, `cslib/agents/cslib-implementation-agent.md`, `core/docs/fork-patterns.md`, `core/context/architecture/component-checklist.md`, `core/context/patterns/thin-wrapper-skill.md`, `core/context/architecture/system-overview.md`, `core/agents/meta-builder-agent.md`.

Note the file set is larger than the description's named 4 files (it named `meta-builder-agent.md`, `system-overview.md`, `component-checklist.md`, `thin-wrapper-skill.md` — all 4 confirmed present — but 3 `cslib` agent files and `core/docs/fork-patterns.md` were not named). Real, unchanged, purely cosmetic (no runtime cost, since these paths are never `@`-imported, only cited in prose) — normalize `@.claude/docs/...` to a plain backticked path in all 8 files for consistency with the context-loading audit's normalization elsewhere.

### 4. `scripts/literature-retrieve.sh` — confirmed dead, confirmed misplaced quarantine candidate

The file lives at `agent-system/extensions/core/scripts/literature-retrieve.sh` (core, not literature extension) and is declared in `core/manifest.json:134`. Its own header:
```
# DEPRECATED: literature-retrieve.sh is superseded by literature-briefing.sh.
# Skill Stage 4a blocks now call literature-briefing.sh (no arguments) instead.
# ...
# Do not add new usages of this script. Use literature-briefing.sh instead.
```
Three files mention its name (`literature/context/guides/literature-organization.md`, `core/scripts/check-extension-docs.sh`, `core/scripts/lib/common.sh`) — all three are comments/documentation, not invocations; there is no automated caller, consistent with the description's negative finding (the 138-script caller analysis).

One thing the description did not flag: `literature/context/guides/literature-organization.md` describes `literature-retrieve.sh` as the live `--lit` mechanism ("The skill's preflight calls `literature-retrieve.sh <task_description> <task_type>`") — this is itself now-stale documentation, since CLAUDE.md's Literature Mode section (and `lit-stage4a-flow.md`) describe `literature-briefing.sh` as the current mechanism. **Recommend updating this doc's description of the flow as part of the quarantine work**, not just moving the script.

Current `scripts/deprecated/` quarantine population: `core/scripts/deprecated/` holds 8 `.sh` files (+ 1 `README.md`); `literature/scripts/deprecated/` holds 2 more (`zotero-index-remove.sh`, `zotero-index-add.sh`). Total 10 quarantined scripts today, not the "9-script" or "11 such scripts" figures named at different points in the description — both are stale; use 10 as the current baseline when writing the quarantine plan.

**Recommended action**: move `literature-retrieve.sh` to `core/scripts/deprecated/`, remove its `provides.scripts` line at `core/manifest.json:134`, update `literature-organization.md`'s flow description, and confirm `check-extension-docs.sh`'s comment (which name-checks it as a legitimate cross-extension mention) still resolves correctly against the new location.

### 5. Topic taxonomy — orphan count is 13 today, not 10; re-derive, do not reuse the filed list

Filed as "declared-but-unused grew to TEN": `commit-scoping-concurrency, context-loading, cslib, mcp-integration, memory-improvement-loop, neovim, orchestrate-admission-gate, status-marker-lifecycle, wezterm-notifications, workflow-refactor`, with an explicit note that `status-marker-lifecycle` may no longer be an orphan.

Re-derived via `comm` between `state.json .active_topics` (18 entries) and the set of `**Topic**:` values actually used across `specs/TODO.md` (5 distinct values in current use: `core-agent-system` (46), `literature` (14), `extensions` (6), `opencode` (2), `neovim` (1)):

**Declared-but-unused today (13)**: `agent-system`, `commit-scoping-concurrency`, `context-loading`, `cslib`, `essential-refactor`, `mcp-integration`, `memory-improvement-loop`, `orchestrate-admission-gate`, `orchestration-concurrency`, `status-marker-lifecycle`, `team-mode-lifecycle`, `wezterm-notifications`, `workflow-refactor`.

Confirms the filed note: `status-marker-lifecycle` IS still listed as declared in `active_topics` (the note said it "is no longer an orphan," but no active task currently carries that topic value — the note appears to describe a task that has since completed/archived and dropped off the active set again, or the referenced "plan-status task" used a different topic string). `neovim` correctly dropped off the orphan list (task 45 was re-topiced to `neovim` per its own backfill note, confirmed present in TODO.md).

**New orphans not in the filed list**: `agent-system`, `essential-refactor`, `orchestration-concurrency`, `team-mode-lifecycle` — four topic strings declared in `active_topics` with zero current `TODO.md` users. These read like completed/archived-task topics that were never pruned from `active_topics` (plausible given `essential-refactor` and `team-mode-lifecycle` sound like completed refactor-era workstreams). Used-but-undeclared side remains 0, confirmed.

**Recommendation**: do not port the filed 10-item list forward into an implementation plan; re-run the `comm` derivation above at implementation time (topics churn fast — 3 items changed status between filing and this research pass alone) and reconcile against `manage-topics.sh` if a dedicated pruning tool exists there.

### 6. ROADMAP.md deletion — decided, but `roadmap-integration.sh` will silently regenerate a stub unless also changed

`specs/ROADMAP.md` still exists (3,455 bytes, last modified 2026-07-12 — unchanged since filing). The decision to delete rather than rewrite is recorded and not re-litigated here.

Checked whether `/review`'s roadmap-integration step hard-requires the file: it does **not** hard-require it, but it also does not gracefully skip when it's absent. `roadmap-integration.sh:136-149`:
```bash
if [[ ! -f "$ROADMAP_PATH" ]]; then
  echo "Note: ROADMAP.md not found at $ROADMAP_PATH, creating default template" >&2
  mkdir -p "$(dirname "$ROADMAP_PATH")"
  cat > "$ROADMAP_PATH" << 'TEMPLATE'
# Project Roadmap
## Phase 1: Current Priorities (High Priority)
- [ ] (No items yet -- add roadmap items here)
## Success Metrics
- (Define success metrics here)
TEMPLATE
fi
```
So a bare `rm specs/ROADMAP.md` will not break the `/review` gate — but the very next `/review` run will silently recreate an empty stub, which is a different flavor of "a roadmap that describes nothing," and the file will keep reappearing forever. **This is exactly the "adjust that step's expectation" case the description anticipated.** The implementer must decide and implement one of: (a) change `roadmap-integration.sh` to skip roadmap processing entirely (no file, no template, no annotation) when `ROADMAP_PATH` is absent, treating absence as "no roadmap tracked" rather than "roadmap needs a stub"; or (b) accept the auto-recreated stub as intentional (contradicts the decided deletion) — (a) is the only choice consistent with the already-decided resolution.

### 7. Item 2 — deploy non-determinism: one error already fixed, the other still open, the fold genuinely never happened

Two related `errors.json` entries:

- **`err_1786350581208_23mAsn`** (`deploy_merge_content_loss`, severity high at filing): **`fix_status: "fixed"`, `fixed_date: 2026-08-10T18:44:25.268Z`, `fix_task: 1015`.** The entry's own message already records the resolving evidence: a 3-wipe-pair re-check found 0-of-3 reproduction of the original single-observation content-loss finding; the 3 pairs showed only "ordering-only differences ... semantically identical under `jq -S`, not a dropped block." **This one is closed — the description's framing of it as "entry-only" (unfixed) is stale.**
- **`err_1786350581240_JyztWt`** (`deploy_nondeterministic_merge`, severity low): **`fix_status: "unfixed"`.** Still open today, exactly as described.

The "orphan-file parity task" referenced as the fold target is **task 9, `resolve_deploy_orphan_file_parity`**, archived at `specs/archive/009_resolve_deploy_orphan_file_parity/`, completed 2026-08-24T23:30:00Z. Its summary confirms it closed two *different* errors entirely (`err_1786349061556_LuKGif` and `err_1786350581273_TAWj0I`) and its whole scope was the 4 orphan files / 2 ghost index rows — it never touches ordering or content-loss. **This confirms the description's process finding exactly: the fold of `err_1786350581240_JyztWt` into that task was recorded in the ledger but genuinely never performed, and the task it was folded into has since completed and archived without ever touching it.** The finding stands, unchanged, and is now more clearly demonstrable (task 9 is closed, so there is no ambiguity about whether it might still address this in a later phase).

Because the sibling error (`23mAsn`) was independently resolved on a "differences are ordering-only, semantically identical under `jq -S`" rationale and accepted as fixed, the precedent for `err_1786350581240_JyztWt` is arguably already set in practice — it just was never formally applied to this specific ticket. The description's instruction to "run the scratch wipe-pair procedure ... and either fix the ordering non-determinism or record an explicit decision that semantic equality under `jq -S` is the standard" is still live work (the wipe-pair re-check needs to be re-run against the *current* tree, not assumed from the 2026-08-10 run), but the most likely outcome given the precedent is: re-confirm, then formally record the `jq -S` semantic-equality decision and close `err_1786350581240_JyztWt` referencing both this task and the `23mAsn` precedent.

### 8. Item 3 — live-cycle defect criterion: significantly more evidence now than at filing, all pointing toward re-scoping

Filed: "specs/events.jsonl now holds 5 such events (3 from 2026-08-08 plus 2 newer)."

Re-measured: `specs/events.jsonl` currently holds **13** `system_defect` events across **4** distinct `detail.defect_class` values:

| defect_class | count |
|---|---|
| `HANDOFF_STALE_OR_ABSENT` | 7 |
| `OFF_SCHEMA_STATUS` | 4 |
| `META_MISSING_AFTER_NARRATION` | 1 |
| `AMBIENT_BINDING_MISMATCH` | 1 |

This has grown substantially (5→13 events, ~3→4 classes) since filing — consistent with the description's own warning that measurements have degraded, though the growth here is evidence *for* the item-3 recommendation rather than a defect requiring separate action.

Per the delegating instruction, do **not** fix `OFF_SCHEMA_STATUS` or `META_MISSING_AFTER_NARRATION` here — confirmed both remain owned elsewhere (their occurrences are attributed to `skill-orchestrate/SKILL.md` and `general-implementation-agent.md`, consistent with the handoff-identity and nonterminal-fanout tasks named in the description). `AMBIENT_BINDING_MISMATCH` is a fourth, newer class not mentioned in the filed description at all — it is **not** unowned residue: it was deliberately registered and its one firing produced by **task 133** (`Register the ambient-binding defect class and fix the /orchestrate deploy-pending annotation`), status `[COMPLETED]`, per `specs/TODO.md:278`. No action needed on it here beyond noting its existence when re-deriving the current event count.

**Direct, load-bearing evidence for the acceptance-bar decision**, found in **task 53** (`Suppress expected handoff absence defect`, `[NOT STARTED]`, `specs/TODO.md:2179`): task 53 explicitly names this exact open question three separate times across three dated evidence blocks (original 2026-08-24 filing, "EVIDENCE ADDED 2026-08-24", "EVIDENCE ADDED 2026-09-01") and asks that its observations be "folded in as evidence when that decision is made" — i.e., task 53 is written as a **contributor to task 50's item-3 decision**, not merely a sibling. Its evidence cuts both ways and should be weighed directly rather than re-derived:
  - *For relaxing the bar* ("no NEW defect classes" over "zero events"): a clean, fully-successful base-mode `/orchestrate` run recorded a `HANDOFF_STALE_OR_ABSENT` defect for expected, correct non-writer behavior — the recorder firing on a run where nothing went wrong is exactly the false-positive case that motivates loosening a strict "zero events" bar.
  - *Against relaxing it carelessly*: two independent live incidents (2026-08-24 late-completion clobber, 2026-09-01 git-restore clobber) show that on a run that was genuinely NOT clean, the single defect event was "the only signal distinguishing a predecessor clobber from a normal report." A criterion that stops caring about "new classes" without also protecting per-class firing-rate signal would blind the system to exactly this hazard the gates exist to catch.

**Recommendation for the implementer**: re-scope the acceptance bar to something like "no NEW defect classes on a clean run, AND no unexplained increase in a known class's firing rate absent a corresponding real incident" — a pure "no new classes" bar is under-specified against task 53's own evidence. Record the decision in the same place the capstone's other unverifiable gate-out criterion was re-scoped (locate that precedent in `specs/reviews/review-2026-08-10-agent-system-refactor-capstone.md` or its archived task, `996_capstone_end_to_end_refactor_verification`, before finalizing wording).

### 9. Undocumented machinery — both confirmed live

- **`/zulip` / `skill-zulip`**: both exist (`core/commands/zulip.md`, `core/skills/skill-zulip/`) and are deployed, but `grep -n 'zulip' core/merge-sources/claudemd.md` returns zero hits. No Command Reference row, no extension section. Confirmed as described.
- **`scripts/check-runtime-file-tracking.sh`**: exists at `core/scripts/check-runtime-file-tracking.sh` (and is already wired in as **CI gate 14** per task 86's summary — it is not orphaned functionally, only undocumented). `grep -c check-runtime-file-tracking core/docs/reference/utility-scripts-inventory.md` → 0. Confirmed missing from the Utility Scripts table as described. Note for the implementer: since task 86 already wired this script into CI as a mandatory gate, its documentation entry should say so explicitly (not just "operator-invoked-only" like its five siblings) — it is now dual-purpose (operator-invoked + CI-gate), which the original description's framing didn't anticipate.

### 10. Overlap check — CI-expansion and deploy-verification tasks are both completed; no scope overlap found

Located both referenced tasks in the archive: **task 82** (`wire_deploy_verification_into_deploy_headless`) and **task 86** (`expand_ci_to_full_gate_suite_and_go_green`), both `[COMPLETED]`/archived. Task 86's summary confirms it fixed 19 originally-live gate failures and wired `check-runtime-file-tracking.sh` in as gate 14 — its scope is CI plumbing and pre-existing gate failures at the time, not the ledger/taxonomy/documentation items task 50 covers. **No overlap; nothing to drop from task 50's scope on this account.**

### 11. Pre-existing `verify-deploy.sh` failures — confirmed real, none has an owning task

Re-ran the three specific checks named in the current-run context:

- **Doc-lint manifest-registration gap** (gate 3 of `verify-deploy.sh`): confirmed live. `bash .claude/scripts/check-extension-docs.sh` reports:
  ```
  FAIL: script file on disk NOT in provides.scripts: scripts/test-state-write-large-payload.sh
  FAIL: script file on disk NOT in provides.scripts: scripts/tests/test-force-phases.sh
  FAIL: script file on disk NOT in provides.scripts: scripts/tests/test-roadmap-argv-ceiling.sh
  ```
- **`validate-state.sh --deep` schema drift**: confirmed live.
  ```
  FAIL: Unknown entry field: abandon_reason (on project_number(s): 94,46,31,64,73,115,132)
  FAIL: Unknown entry field: blocks_note (on project_number(s): 106,107,109)
  ```
- **`test-force-phases.sh` state-writer-boundary violations**: confirmed live — 4 `[VIOLATION]` lines from `lint-state-writer-boundary.sh --verbose`, all raw `jq ... > specs/state.json.tmp && mv ...` writes inside the test fixture at lines 261, 307, 317, 327.

Searched `specs/TODO.md` for any task naming these three items by filename or field name: **none found.** All three are currently unowned.

**Scope assessment**: only the doc-lint item is squarely within this task's "restore verification trust" theme and is a trivial, low-risk fix (add 3 lines to `core/manifest.json`'s `provides.scripts` array — the scripts are legitimate test fixtures that simply were never registered, the same class of mismatch this task already treats as a "quarantine-convention miss" pattern for item 5a, just the mirror-image direction). Recommend folding this one fix into this task's hygiene phase.

The other two (schema drift, state-writer-boundary in a test fixture) are **recommended as out of scope** for this task and should be named explicitly rather than silently absorbed or silently dropped: schema drift belongs with whatever task owns `state-schema.json` maintenance (not identified in this pass — a `/spawn` or a fresh `/task` may be warranted if no owner exists), and the test-fixture violation is closer in nature to test-suite hygiene (adjacent to, though distinct from, the explicitly-excluded item 1) — it may be legitimate exempted fixture code needing the same kind of documented-exception treatment task 48 used for `git-commit-scoped.sh`'s own boundary lint, rather than a fix. Flagging both here satisfies "assess... or are owned elsewhere" without expanding this task's file_scope into schema or test-suite territory.

## Split Assessment

The description explicitly invited a split recommendation. Given the re-measurement:

- Two of the six original hygiene sub-items (session-ID one-liner, jq #1132) are **already fully resolved** and require no further work beyond a closing note.
- One item (item 1, non-deterministic shell suite) was **already extracted** to its own task before this research began.
- What remains — items 2, 3, and hygiene items 5a/5b/5c/6 (roadmap+taxonomy) plus the newly-surfaced 1-line doc-lint manifest fix — is a coherent, right-sized single implementation plan. It naturally splits into two **phases within one task**, not two tasks:
  - **Phase A (decisions + verification, no bulk file edits)**: item 2's wipe-pair re-check and `jq -S` decision recording; item 3's acceptance-bar re-scoping decision.
  - **Phase B (mechanical hygiene)**: `literature-retrieve.sh` quarantine; `@.claude/docs` normalization (8 files); topic taxonomy reconciliation; `zulip`/`check-runtime-file-tracking.sh` doc additions; ROADMAP.md deletion + `roadmap-integration.sh` absent-file handling; the doc-lint manifest 3-line fix.

**Recommendation: keep this as one task, planned in two phases.** Expanding into multiple tasks now would over-fragment work that has already shrunk by roughly a third since filing.

## Decisions

- Session-ID one-liner and jq #1132 items are recorded as **already resolved**; the implementation plan should not schedule migration work for either, only a closing verification note.
- ROADMAP.md deletion requires a companion change to `roadmap-integration.sh` (or the `/review` step that invokes it) to stop auto-recreating a stub on absence — treated as in-scope, not optional polish, because without it the decided deletion does not stick.
- The doc-lint manifest-registration gap for 3 test scripts is folded into this task's hygiene phase (trivial, on-theme); the state-schema `--deep` drift and the `test-force-phases.sh` state-writer-boundary violations are named explicitly as out of scope, owner not yet identified.
- Topic-taxonomy orphan list should be re-derived at plan/implementation time rather than reusing either the filed 10-item list or this report's 13-item snapshot verbatim, given the measured 3-item drift within this single research pass.

## Risks & Mitigations

- **Topic and event counts will drift again before implementation starts** (this report itself demonstrates ~2-3 item movement per research pass). Mitigation: the implementation plan should re-run the exact `comm`/`grep`/`jq` commands in this report rather than hard-coding the numbers found here.
- **`roadmap-integration.sh` change could regress `/review` for repos that still want a roadmap.** Mitigation: gate the "skip when absent" behavior on file absence only — a present, well-formed ROADMAP.md continues to be parsed and annotated exactly as today.
- **Folding the doc-lint 3-script fix into this task risks scope creep if the state-schema/state-writer items get pulled in too.** Mitigation: this report explicitly draws the line; the plan should cite this report's item 11 rather than re-deciding on the fly.

## Context Extension Recommendations

- **Topic**: session-ID/jq duplication-gate lifecycle. **Gap**: no context file records that task 84 closed the session-ID gate or that the jq-#1132 "duplication" was already pointer-form; a future audit is likely to re-flag both from stale prose in `specs/TODO.md`'s own historical task descriptions (which are not context files but do get read). **Recommendation**: none required for `context/` specifically — the errors.json closure and this report are sufficient; no new context file needed for a fully-closed item.

## Appendix

Search/verification commands used (all against the current working tree, 2026-09-01):
```
grep -rl 'sess_$(date' agent-system/extensions/
grep -rli 1132 agent-system/extensions/
grep -rn '@\.claude/docs' agent-system/extensions/
grep -n 'literature-retrieve' agent-system/extensions/core/manifest.json
comm -23 <(jq -r '.active_topics[]' specs/state.json | sort -u) <(grep -oP '(?<=\*\*Topic\*\*: )\S+' specs/TODO.md | sort -u)
jq -r '.errors[] | select(.id=="err_1786350581240_JyztWt" or .id=="err_1786350581208_23mAsn")' specs/errors.json
grep 'system_defect' specs/events.jsonl | jq -r '.detail.defect_class' | sort | uniq -c
bash .claude/scripts/check-extension-docs.sh
bash agent-system/extensions/core/scripts/validate-state.sh --deep
bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh --verbose
grep -rl 'git commit -m' agent-system/extensions/ | grep -v 'git-commit-scoped.sh|test'
```
Archived tasks consulted: `specs/archive/084_fix_duplication_gate_scope_and_extensions_root/`, `specs/archive/009_resolve_deploy_orphan_file_parity/`, `specs/archive/082_wire_deploy_verification_into_deploy_headless/`, `specs/archive/086_expand_ci_to_full_gate_suite_and_go_green/`.
Live TODO.md tasks consulted for cross-reference (not modified): task 42, task 48 (completed), task 53, task 133 (completed).
