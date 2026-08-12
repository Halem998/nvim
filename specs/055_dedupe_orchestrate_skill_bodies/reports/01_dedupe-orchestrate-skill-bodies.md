# Research Report: Task #55

**Task**: 55 - Dedupe orchestrate skill bodies
**Started**: 2026-08-12T19:00:00Z
**Completed**: 2026-08-12T19:39:00Z
**Effort**: Large (deep structural analysis of two ~200KB/~130KB skill bodies plus a locking test suite)
**Dependencies**: Task 48
**Sources/Inputs**: Codebase (skill-orchestrate/SKILL.md, skill-orchestrate-hard/SKILL.md, scripts/skill-base.sh, scripts/orchestrate-*.sh, scripts/tests/test-handoff-reader-parity.sh, docs/architecture/handoff-schema.md)
**Artifacts**: - This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The two files' Stage 5 post-dispatch blocks (staleness gate, `dispatch_seq` identity gate,
  stray-handoff sweep, `.return-meta.json` recovery, evidence corroboration, postflight status
  transition, artifact linking) are **each a single ~46–50 KB fenced-bash block**, and the two
  blocks are ~85% line-for-line identical after normalizing only the `[orchestrate]` /
  `[hard-orchestrate]` notice prefix and each file's own self-attribution path strings. This one
  block pair is the dominant duplication source, well above the task's 28,421-byte floor.
- A second, smaller duplication cluster sits in each file's Stage 2 loop-guard initializer
  (~8.7 KB std / ~14 KB hard): the first ~40% (MAX_INFRA_FAILURES, `loop_guard_file`/
  `handoff_file` setup, `budget-continuation-override`, resume-read, `mint_dispatch_seq()`,
  blocker/drift constants) is common; the remainder is a genuinely hard-mode-only
  `loop-guard-staleness` detector and churn-state scaffolding that the base file's own prose
  explicitly records as "a SEPARATE, undecided question" — not accidental drift, and out of this
  task's scope to force into parity.
- A concrete, already-half-done promotion candidate exists: `hard_orchestrate_propagate_completion`
  is a ~15-line helper defined **locally inside** `skill-orchestrate-hard/SKILL.md` (used twice
  within that same file) whose equivalent logic is still written out inline, uncollapsed, inside
  `skill-orchestrate/SKILL.md`'s `implemented` case. Promoting it to `skill_orchestrate_
  propagate_completion` in `scripts/skill-base.sh` and calling it from both files closes one
  concrete duplicate with no design risk.
- **Binding constraint discovered, not in the task description**:
  `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` mechanically
  extracts specific literal text out of both SKILL.md files and asserts equality/parity. Most of
  what it checks (the `dispatch-seq-gate:begin`/`:end` sentinel region) tolerates extraction to a
  shared script transparently, because the test's own comparison already normalizes exactly the
  prefix/path substitution pattern extraction would produce. But ~10 of its assertions require a
  handful of one-line `VAR=$(echo "$handoff" | jq -r '...')` reads to remain **literally present,
  with the variable name `$handoff` unchanged**, in both files — extraction of those specific
  lines to a script would empty-match the test's regex and fail it. Those lines are cheap in
  bytes; recommend leaving them as parallel literal duplication (which the test already polices)
  and spending extraction effort on the surrounding narrative/procedural bash, which is the
  actual multi-KB cost.
- Recommended mechanism, per the task's own stated preference: extend `scripts/skill-base.sh`
  (currently 51,859 B / 919 lines, 15 `skill_*` functions, already the established
  cross-engine-shared idiom) for the reusable helper logic, and extend the existing
  `scripts/orchestrate-*.sh` "print JSON to stdout, caller parses via jq" pattern (5 scripts
  today: `orchestrate-batch-admit.sh`, `orchestrate-dry-run-report.sh`,
  `orchestrate-predispatch-review.sh`, `orchestrate-recover-outcome.sh`,
  `orchestrate-triage-classify.sh`) for the multi-step procedural logic (the staleness/
  dispatch_seq/stray-handoff gate sequence and the postflight status-transition + artifact-link
  tail). `orchestrate-recover-outcome.sh` already proves this pattern scales to Stage-5-sized
  concerns: both engines already call it identically today for `.return-meta.json` fallback.

## Context & Scope

Task 55 is LEVER 1 of a three-part context-cost initiative (task 55: orchestrate skills; task 56:
command bodies; task 54, completed: eager rules budget; task 57, completed: generated CLAUDE.md
eager surface). It targets exactly two files plus their shared-infrastructure homes:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — 196,171 B (2,963 lines)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — 127,145 B (2,069 lines)
- `agent-system/extensions/core/scripts/skill-base.sh` — 51,859 B (919 lines), extension target
- `agent-system/extensions/core/scripts/orchestrate-*.sh` — extension target for new/extended scripts

Out of scope per the task's own territory statement: rules/merge-sources (sibling subtask),
`commands/todo.md` and `commands/orchestrate.md` (sibling subtask, task 56).

The SEQUENCING NOTE in the task description is confirmed discharged by direct inspection: the
current base file already documents its `loop-guard-staleness` absence as a settled, recorded,
independent decision (line ~257 of `skill-orchestrate/SKILL.md`), not as an in-flight redesign
blocking this work.

## Findings

### Measured current state (2026-08-12, this checkout)

| File | Bytes | Lines | Fenced-`bash` bytes | % of file |
|---|---|---|---|---|
| `skill-orchestrate/SKILL.md` | 196,171 | 2,963 | 82,084 | 41.8% |
| `skill-orchestrate-hard/SKILL.md` | 127,145 | 2,069 | 95,465 | 75.1% |
| Combined | 323,316 | 5,032 | 177,549 | 54.9% |

Note for the plan phase: the standard file's bash-fraction (41.8%) is now far below the task
description's cited baseline figure (72.6%), while the hard file's (75.1%) is close to its cited
baseline (74.2%). This means the two files' composition has diverged since that baseline was
taken — the standard file has picked up substantially more non-bash prose/tables growth relative
to its bash content. Re-verify current percentages at report time in the plan rather than reusing
the task description's baseline numbers, which are now stale for the standard file specifically.
The two files are deployed byte-for-byte identical to `.claude/skills/...` (confirmed via `wc -c`
on both source-store and deploy-tree copies) and there is no include/partial/compose mechanism in
`install-extension.sh` — `deploy-headless.sh` performs a straight file copy, matching the task
description's claim.

### The dominant duplication: the Stage 5 post-dispatch block

Both files carry Stage 5 (result-read → status transition → artifact link) as **one single
fenced-bash block**, not several smaller ones:

- `skill-orchestrate/SKILL.md` lines 640–1345 (705 lines / 50,017 B)
- `skill-orchestrate-hard/SKILL.md` lines 1129 area (649 lines / 46,014 B)

After normalizing only `[hard-orchestrate]`→`[orchestrate]` and
`skill-orchestrate-hard/SKILL.md`/its full path →the base equivalents, a diff of the two blocks
shows the divergence is concentrated in:

1. **Comment-only rewording** (the large majority of the diff — see the diff excerpt below):
   near-identical explanatory prose restated with slightly different phrasing per file, evidence
   the hard file was hand-mirrored from the base file at some point and has since drifted in
   wording without drifting in logic.
2. **Genuine hard-mode-only fields**: `skeleton` and `sorry_inventory` (with `follow_up_task`)
   are read and logged only in the hard file — these are real, intentional hard-mode extensions
   (Lean/formal-verification wrap-up fields) and must stay hard-mode-only, not forced into base.
3. **A hard-only already-promoted helper vs. base's still-inline equivalent**:
   `hard_orchestrate_propagate_completion()` (defined at hard file line ~929, called at lines 888
   and 1637) replaces ~20 lines of inline `completion_json`/`completion_summary`/`roadmap_items`
   logic that `skill-orchestrate/SKILL.md` still carries inline (lines ~1210–1226). This is the
   clearest "closes by construction" candidate: promote the function itself into
   `scripts/skill-base.sh` as (e.g.) `skill_orchestrate_propagate_completion`, called identically
   by both engines.
4. **One block present only in base**: the `marker-handoff-crosscheck` region (base file,
   ~30 lines inside Stage 5, diagnostic-and-downgrading semantics) has **no counterpart at this
   location** in the hard file — but this is NOT missing duplication to fix. The hard engine
   performs the equivalent marker/handoff mismatch check at a different point (line ~769, inside
   its H1 per-phase-dispatch selection logic, block "plan_path=... H1..."), where it is
   **dispatch-refusing** rather than after-the-fact-downgrading, because hard mode selects the
   next phase to dispatch rather than always re-dispatching the whole plan. Do not attempt to
   force this into a single shared function across engines — the trigger point and semantics
   differ by design.
5. **Cosmetic/attribution-only diffs**: `detecting-site` strings differ in a way that is already
   durable on disk (`skill-orchestrate/SKILL.md:stage-5-tier-c` vs.
   `skill-orchestrate/SKILL.md:tier-c` in the hard file's own self-attribution, i.e. even the two
   files disagree with each other about their own convention) — flag for the plan to decide
   whether to normalize going forward (new events only) or leave historical ledger entries alone.

Byte composition of the mega-block itself: roughly half is comments (25,776 B / 52.3% in the
std block, 23,295 B / 51.4% in the hard block) and half is code — so the same block, once
extracted to one script carrying its comments once instead of twice, removes not just the
duplicate logic but the duplicate prose explaining it.

### The append_detected_defect / mint_dispatch_seq micro-duplicates

- `append_detected_defect()`: defined at `skill-orchestrate/SKILL.md:657` and
  `skill-orchestrate-hard/SKILL.md:1129`. Small (~15–20 lines), fully identical logic apart from
  the notice-prefix string. The hard file's own comment already names this exact function as
  "the mechanical backstop" case and states "the two MUST stay in sync."
- `mint_dispatch_seq()`: defined at `skill-orchestrate/SKILL.md:224` and
  `skill-orchestrate-hard/SKILL.md:423`. ~8 lines, byte-identical logic (increments
  `dispatch_seq_counter` in the loop guard file, returns the new value on stdout). Both files'
  own comments already call each other "verbatim-twin."

Both are strong candidates for `skill-base.sh` promotion (`skill_append_detected_defect`,
`skill_mint_dispatch_seq`), taking the loop-guard-file path and notice-prefix as parameters —
though note `append_detected_defect` closes over `loop_guard_file`, so any script/function
version must take that as an explicit argument rather than relying on ambient scope.

### The Stage 2 loop-guard initializer (secondary duplication cluster)

- `skill-orchestrate/SKILL.md` lines 102–242 (8,692 B)
- `skill-orchestrate-hard/SKILL.md` corresponding block (14,036 B)

The first portion is common (MAX_INFRA_FAILURES constant, `loop_guard_file`/`handoff_file`
assignment, `mkdir -p "$TASK_DIR"`, the `budget-continuation-override` region — itself already
explicitly called a "verbatim-twin mechanism" in the base file's own prose — the resume-read /
fresh-init branch, `mint_dispatch_seq()`, and the blocker-escalation/drift-detection constants).
The hard file then adds, genuinely hard-mode-only and NOT missing duplication: a
`current_plan_version` computation, the 3-signal `loop-guard-staleness` detector
(`loop-guard-staleness:begin`/`:end`, ~70 lines), and `churn_file` initialization. The base file's
own prose (line ~257) records this asymmetry as a deliberate, separately-decided, currently-open
question — treat it as out of scope for this dedup task; extracting the genuinely-common ~60% of
this block to a shared script/function is still valuable and low-risk.

### Already-established extraction infrastructure

`scripts/skill-base.sh` (51,859 B, 919 lines) already defines 15 `skill_*` functions consumed by
both engines: `skill_preflight_update`, `skill_postflight_update`, `skill_gate_completion_claim`,
`skill_corroborate_phase_counts`, `skill_link_artifacts`, `skill_propagate_completion_summary`,
`skill_propagate_memory_candidates`, `skill_lifecycle_notify`, `skill_cleanup`,
`skill_validate_artifact`, `skill_validate_task_artifacts`, `skill_read_metadata`,
`skill_read_artifact_number`, `skill_context_injection`, `skill_run_extension_hook`,
`skill_get_extension_dir`, `skill_create_postflight_marker`, `skill_validate_input`. This is
exactly the pattern the task asks to extend — it is not a new mechanism to invent.

`scripts/orchestrate-*.sh` today has 5 scripts (not the ~20 the task description estimates;
across both SKILL.md bodies, 13 distinct `.claude/scripts/*.sh` paths are actually invoked,
counting non-`orchestrate-`-prefixed shared scripts like `system-defect-record.sh`,
`task-lock.sh`, `reconcile-task-status.sh`, `update-task-status.sh`, `git-commit-scoped.sh`,
`git-snapshot.sh`, `command-route-agent.sh`, `deploy-headless.sh`, `verify-deploy.sh` alongside
`skill-base.sh` and the 5 `orchestrate-*.sh` scripts). This doesn't undercut the task's
recommendation — the pattern is real and proven, just smaller in current inventory than
estimated. All 5 `orchestrate-*.sh` scripts follow the same "compute, print JSON/text to stdout,
caller parses with jq" idiom. `orchestrate-recover-outcome.sh` in particular is the strongest
existing precedent for the exact kind of extraction this task needs: it already implements a
substantial piece of Stage 5's own logic (the `.return-meta.json` fallback-recovery computation)
as a script called identically, with identical arguments, by both `skill-orchestrate/SKILL.md`
and `skill-orchestrate-hard/SKILL.md` (and multi-task Stage MT-4). Its own header comment states
this explicitly: "so the three call sites... cannot drift into three separately-maintained
recovery rules" — literally the task's own stated goal, already achieved once and ready to be
achieved again for the surrounding Stage 5 bash.

### Critical constraint: `test-handoff-reader-parity.sh`

`agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` (364 lines) is an
existing orchestration test whose entire purpose is verifying the two SHIPPED SKILL.md files
agree on specific handoff-reading logic, by extracting literal substrings from each file's text
and comparing them (deliberately NOT hand-copying the filters into the test, "to catch drift if a
future editor changes one engine's Stage 5 read but not the other's"). Two distinct extraction
techniques are used, with different implications for this task:

1. **`dispatch-seq-gate:begin`/`:end` sentinel region** (`extract_sentinel_region`, an
   `awk`-based extraction of everything between two comment markers): the test's own comparison
   already normalizes `hard-orchestrate`→`orchestrate` and `skill-orchestrate-hard`→
   `skill-orchestrate` substrings, and separately strips the one `HARD-MODE-TWIN-CROSS-REFERENCE`
   comment line. This means **extracting the dispatch_seq gate to a shared script is safe and
   will continue to pass this test unmodified**, as long as (a) the `dispatch-seq-gate:begin`/
   `:end` sentinel comments remain in both files surrounding whatever replaces the inline logic
   (even a single one-line script-call), (b) the hard file keeps its
   `HARD-MODE-TWIN-CROSS-REFERENCE` comment line, and (c) the call's arguments differ between the
   two files by exactly the same substitution pattern the test already tolerates (notice prefix,
   self-path string).
2. **Per-field `jq` filter extraction** (`extract_jq_filter`): this regex-matches the literal
   bash idiom `VAR=$(echo "$handoff" | jq -[rc] '...')` for `dispatch_status`, `dispatch_summary`,
   `blockers`, `next_hint`, `phases_completed`, `phases_total`, `plan_markers_verified`, and
   `artifacts[0].{path,type,summary}` in **both files independently**, then asserts the extracted
   filter strings and evaluated values are identical. Crucially, the regex requires the literal
   substring `$handoff` as the variable being piped to `jq` — if these reads are moved behind an
   intermediary script/function whose output variable is named anything else (e.g. `$result`),
   the anchor-scoped grep returns empty and the test FAILS with "could not extract jq filter,"
   not silently passes. These specific lines are cheap (roughly a dozen one-line reads, well
   under 1 KB combined per file) — they are not where the actual byte cost lives.

**Recommendation for the plan phase**: treat these ~10 one-line `$handoff` reads as an
intentionally-retained, test-policed exception to the extraction effort — leave them as literal
parallel duplication in both files (satisfying "existing orchestration tests pass unmodified"
exactly as written), and extract everything else in the Stage 5 block (staleness gate, stray-
handoff sweep, outcome-recovery orchestration and its surrounding evidence-corroboration prose,
the postflight status-transition case statement, artifact-linking tail) to shared
scripts/functions. This captures the overwhelming majority of the ~46–50 KB block's bytes while
leaving the mechanically-tested seam untouched. If a future iteration wants to also close this
last piece, it requires deliberately rewriting `test-handoff-reader-parity.sh` at the same time
(a change to a test, which the task's "pass unmodified" acceptance bar does not appear to
authorize) — flag this explicitly as a decision point rather than silently picking one path.

### Two extraction mechanisms and where each applies (per the task's own framing)

The task description distinguishes prose-to-`context/**` (weak — an agent may still read the
backticked pointer) from bash-to-executable-script (strong — the script source is never loaded).
Given the measured composition (roughly half of the Stage 5 mega-block is comments explaining the
code, and the code itself is the duplicated logic), both apply here in combination:
- The **logic** (staleness/dispatch_seq/stray-sweep gates, outcome recovery orchestration,
  postflight case statement, artifact linking, `append_detected_defect`, `mint_dispatch_seq`,
  `hard_orchestrate_propagate_completion`) moves to `scripts/skill-base.sh` functions and/or new
  `scripts/orchestrate-*.sh` scripts, following the existing "stdout JSON, caller `jq`-parses"
  idiom `orchestrate-recover-outcome.sh` already establishes.
- The **prose explaining that logic** moves with it — once the logic lives in one script instead
  of two near-identical inline copies, its explanatory comments do too, which is where roughly
  half the byte savings actually come from (the comments were duplicated 1:1 with the code, not
  independently).
- Genuinely hard-mode-only logic (skeleton/sorry_inventory reads, the loop-guard-staleness
  detector, the H1-time marker-handoff-crosscheck) stays inline in `skill-orchestrate-hard/
  SKILL.md` — do not force parity where none is intended.

## Decisions

- Recommend the extraction unit for the Stage 5 mega-block be `scripts/skill-base.sh` functions
  for logic that closes over caller-scoped shell state cheaply (staleness gate, dispatch_seq
  gate, stray-handoff sweep, `append_detected_defect`, `mint_dispatch_seq`,
  `skill_orchestrate_propagate_completion`), and a new `scripts/orchestrate-stage5-postflight.sh`
  (stdout-JSON pattern, mirroring `orchestrate-recover-outcome.sh`) for the larger, more
  self-contained postflight-status-transition-plus-artifact-linking tail, since that logic mostly
  consumes already-resolved scalar inputs (`dispatch_status`, `phases_completed`, `phases_total`,
  `plan_markers_verified`, `handoff_artifact_path/type/summary`, `task_number`, `session_id`,
  `TASK_TYPE`) and produces a small set of outputs (`offschema_dispatch_status`, whether to halt)
  rather than needing broad ambient shell scope.
- Leave the ~10 `$handoff`-anchored one-line `jq` reads that `test-handoff-reader-parity.sh`
  extracts by regex as literal, test-policed parallel duplication — do not route them through an
  intermediary variable name.
- Leave the hard-only `loop-guard-staleness` detector, `skeleton`/`sorry_inventory` handling, and
  H1-time marker-handoff-crosscheck untouched — they are intentional asymmetries, not
  duplication.
- Do not attempt to unify the base file's Stage-5-location `marker-handoff-crosscheck` block with
  the hard file's H1-location equivalent — different trigger points, different semantics
  (downgrade-after-the-fact vs. refuse-before-dispatch), by design.

## Risks & Mitigations

- **Risk**: extracting Stage 5 changes the literal text `test-handoff-reader-parity.sh` scans,
  silently failing it. **Mitigation**: preserve the `dispatch-seq-gate:begin`/`:end` sentinel
  comments and the substitution-only-difference invariant around whatever replaces that region;
  leave the `$handoff`-anchored one-liners untouched; run this test explicitly (not just the
  general test suite) before and after any Stage 5 edit in the implementation phase.
- **Risk**: a shared Stage 5 script/function silently drops a hard-mode-only behavior (skeleton,
  sorry_inventory, loop-guard-staleness) by treating the hard file's block as a pure superset of
  the base file's. **Mitigation**: the diff in this report enumerates every genuine (non-prose,
  non-attribution) divergence found; the plan should carry this enumeration forward as an
  explicit checklist rather than re-deriving it from a fresh diff.
- **Risk**: `append_detected_defect`/`mint_dispatch_seq` close over ambient shell variables
  (`loop_guard_file`, notice prefix) that differ per engine — a naive shared-function promotion
  that assumes a single global `loop_guard_file` name is fine (both engines already use that
  exact variable name for their own guard file), but the notice-prefix and self-path strings must
  become explicit parameters, not assumed constants.
- **Risk**: detecting-site string inconsistency already exists between the two files
  (`stage-5-tier-c` vs `tier-c`) and is already durable in `specs/events.jsonl`. **Mitigation**:
  decide explicitly (plan phase) whether extraction normalizes this going forward or preserves
  the existing asymmetry; either is defensible, but it should be a stated decision, not an
  accidental byproduct of extraction.

## Context Extension Recommendations

- **Topic**: Stage-5-sized shared orchestration logic extraction pattern.
- **Gap**: no context doc currently states "when a Stage-scale (not helper-scale) block is
  duplicated across the two orchestrate engines, extend `orchestrate-*.sh`'s stdout-JSON pattern
  rather than `skill-base.sh` alone" — this report derives that guidance from
  `orchestrate-recover-outcome.sh`'s precedent but it isn't written down anywhere durable.
  Recommend a short addition to `context/architecture/orchestrate-state-machine.md` after this
  task's implementation lands, documenting the boundary between `skill_*` (skill-base.sh) and
  `orchestrate-*.sh` (stdout-JSON scripts) so future Stage additions pick the right mechanism the
  first time.

## Appendix

### Search queries / commands used

- `wc -c` / `wc -l` on both SKILL.md files (source store and deploy tree)
- Python `re.findall(r'```bash\n(.*?)```', ...)` to enumerate fenced-bash blocks and byte sizes
  per file, sorted to find the largest blocks
- `diff -u` between the two Stage 5 mega-blocks, both raw and after `sed`-normalizing the
  `[hard-orchestrate]`/`skill-orchestrate-hard` substrings to their base equivalents
- `diff -u` between the two Stage 2 loop-guard initializer blocks
- `grep -n` for `append_detected_defect()`, `mint_dispatch_seq()`, `hard_orchestrate_propagate_
  completion`, `loop-guard-staleness`, `marker-handoff-crosscheck` across both files
- Full read of `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh`
- `grep -ohE '\.claude/scripts/[a-zA-Z0-9_-]+\.sh'` across both SKILL.md files to enumerate
  actually-invoked shared scripts
- Read of `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` header
- `specs/TODO.md` grep for the LEVER 1–3 sibling task descriptions and dependency (task 48)

### Key file/line references for the plan phase

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`: Stage 2 loop-guard init
  (lines 102–242), `mint_dispatch_seq()` (224), `append_detected_defect()` (657), Stage 5 mega-
  block (640–1345), inline completion-propagation logic (~1210–1226)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`: Stage 2 loop-guard init
  with `loop-guard-staleness:begin`/`:end` (~242–319), `mint_dispatch_seq()` (423),
  `append_detected_defect()` (1129), H1 marker-handoff-crosscheck (~769–794),
  `hard_orchestrate_propagate_completion()` definition (~929) and call sites (888, 1637)
- `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh`: full file is the
  binding test constraint discussed above
- `agent-system/extensions/core/scripts/skill-base.sh`: existing `skill_*` extension point
  (51,859 B, 919 lines)
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`: precedent for the
  stdout-JSON extraction pattern to extend
