---
next_project_number: 1016
---

# TODO

## Task Order

*Updated 2026-08-10. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 1004,1007,1010,1011,1012,1013,1014,1015 | -- | agent-system |
| 2 | 1005,1009 | 1004,1015 | agent-system |
| 3 | 1006 | 1005 | agent-system |

**Grouped by Topic** (indented = depends on parent):

### Agent System

1004 [NOT STARTED] — /todo's "Sync Repository Metrics" stage cannot report a true buil
  └─ 1005 [NOT STARTED] — /todo documents a producer/consumer contract for ROADMAP.md synch
    └─ 1006 [NOT STARTED] — The artifact list in specs/state.json is append-only by intent bu
1007 [NOT STARTED] — validate-handoff-location.sh matches .orchestrator-handoff.json p
1010 [NOT STARTED] — tests/run-all.sh has a 7th, previously unreported deployed-mode-o
1011 [NOT STARTED] — The system-defect vocabulary has a gap: defect classes exist for 
1012 [NOT STARTED] — tests/run-all.sh is red and has been treated as permanently-expec
1013 [NOT STARTED] — The acceptance criterion "gate-out reports zero format errors and
1014 [NOT STARTED] — Two dispatches in a single batch fanned out to phase sub-agents a
1015 [NOT STARTED] — A VERIFICATION task, deliberately not a fix task. Do not change m
  └─ 1009 [NOT STARTED] — Declared-vs-deployed parity for provides.* categories is one-dire

## Tasks

### 1015. Re-check settings.local.json deploy merge for content loss before any fix effort
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: A VERIFICATION task, deliberately not a fix task. Do not change merge logic until reproduction is established. Recorded as err_1786350581208_23mAsn (severity high, reproduction 0 of 3).

WHAT WAS SEEN ONCE: a single observation of a content-lossy settings.local.json merge across a deploy-headless.sh --wipe pair - a dropped hooks.PreToolUse block and a dropped mcpServers block.

WHAT RE-CHECKING FOUND: 3 further wipe-pairs showed reproduction 0 of 3. All three exhibited ordering-only differences (mcpServers and hooks blocks relocated, semantically identical under jq -S), not a dropped block. The original finding did NOT reproduce.

WHY THIS STAYS OPEN DESPITE NOT REPRODUCING: non-reproduction is a result, not an all-clear. If it is real and intermittent, the consequence is a routine redeploy silently dropping a hook or an MCP registration - the most consequential hypothesis surfaced in the batch that found it. The asymmetry between a cheap re-check and a silently disabled security-relevant PreToolUse hook justifies keeping it open.

WORK:
  1. Run a substantially larger wipe-pair sample than 3 (10 or more), comparing settings.local.json semantically (jq -S) AND structurally (key/block presence), not by raw diff - raw diff cannot distinguish reordering from loss, which is exactly what confused the original observation.
  2. Determine whether any pre-existing settings.local.json state, ordering, or size correlates with loss.
  3. If reproduced: capture the exact input, escalate to critical, and only then plan a fix.
  4. If not reproduced across the larger sample: downgrade the recorded severity with the sample size stated, and close. Record the number of pairs run either way.

RELATED BUT SEPARATE: ordering non-determinism in context/index.json and settings.json between identical wipe runs is recorded as err_1786350581240_JyztWt (low). It is cosmetic on its own, but it is coupled to the deploy byte-identical-twice acceptance criterion, so resolving it may fall out of the orphan-parity work rather than this task.

ACCEPTANCE: a stated reproduction rate over a named sample size. Neither confirm nor dismiss on a single observation.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 1014. Prevent implementation-agent fan-out from returning non-terminal status and stale plan markers
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Two dispatches in a single batch fanned out to phase sub-agents and terminated before writing a terminal status, costing a recovery cycle each. Recorded as err_1786344051474_RcIhk6.

OBSERVED FAILURE MODE: a dispatched implementation agent spawned per-phase sub-agents, returned while they were still running, and left .return-meta.json at status=in_progress. Per context/formats/return-metadata-file.md that value is early-metadata-only and never a legal terminal dispatch outcome, so orchestrate-recover-outcome.sh correctly declines it (reason STATUS_IN_PROGRESS). The orchestrator contract for an unresolvable dispatch is failed_tasks - which would have been WRONG here, since 6 of 10 phases had in fact been committed. Correct handling came from rules/error-handling.md Delegation Interrupted Recovery (keep status, resume), not from the orchestrator stage contract.

COMPOUNDING DEFECT - STALE PLAN MARKERS: the sub-agents committed phases 3, 4, 5 and 7 but left every one of those phase markers reading [NOT STARTED]. Because the orchestrator phase-marker recovery grep reads exactly those markers, it would have reported 2/10 against a true 6/10. A resume driven by markers alone would have redone committed work. Recovery only succeeded because the actual state was reconstructed from git log and diffs instead.

TWO INDEPENDENT QUESTIONS, BOTH IN SCOPE:
  1. Should a dispatched implementation agent fan out to sub-agents at all? If yes, it must still write a terminal status covering its childrens work; if no, the prohibition belongs in the agent contract, not in per-dispatch prompt text (the workaround used during the incident).
  2. Should a sub-agent that commits a phase be required to update that phases marker in the same commit? Markers and commits diverging silently is the deeper defect - it degrades the recovery path for every future interrupted dispatch, not just fan-out ones.

CONSIDER ALSO: whether the orchestrator should treat status=in_progress plus evidence of committed phase work as PARTIAL/resume rather than routing it toward failed_tasks, so correct handling does not depend on an operator noticing.

ACCEPTANCE: an interrupted fan-out dispatch is either impossible by contract, or leaves markers and terminal status accurate enough that resume needs no manual git archaeology.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 1013. Instrument gate-out auto-repair reporting; stop silent in-place artifact mutation
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: The acceptance criterion "gate-out reports zero format errors and zero auto-repaired fields" is unverifiable as written, because no reporting surface exists. Recorded as err_1786350581339_Q4VnFy.

TRACED PATH: command-gate-out.sh (134 lines) has no counter, aggregate, or exit-code surface for auto-repairs; its only related line is a comment. The real repair path is
    command-gate-out.sh -> skill_validate_task_artifacts (skill-base.sh) -> validate-artifact.sh "$f" "$type" --fix 2>/dev/null
validate-artifact.sh DOES emit a terminal line of the form "[FIXED] N field(s) auto-repaired, E error(s), W warning(s) remaining" and exits 2. But skill_validate_task_artifacts discards stderr, collapses every non-zero exit into a single generic non-blocking WARNING carrying no numeric detail, and always returns 0. command-gate-out.sh therefore receives no signal at all.

PRIMARY HAZARD (the reason this is not merely cosmetic): --fix MUTATES THE ARTIFACT IN PLACE. A repair both happens and goes uncounted, so an artifact can be silently rewritten with nothing anywhere recording that it was. The instrumentation gap and the silent-mutation hazard are the same defect seen from two ends.

WORK:
  1. Propagate validate-artifact.sh fix/error/warning counts through skill_validate_task_artifacts instead of discarding them.
  2. Give command-gate-out.sh a reportable surface for those counts.
  3. Decide explicitly whether --fix should remain in-place-mutating on the gate-out path, or whether a repair should be reported and left for a human. State the decision and its reasoning.

ACCEPTANCE: a task whose artifact required auto-repair produces a gate-out report naming a nonzero repaired-field count, and a task needing none reports zero. Both directions must be demonstrated - a report that can only ever say zero is not instrumentation.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 1012. Fix run-all.sh deployed-mode failures: REPO_ROOT depth derivation and 6 further suites
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: tests/run-all.sh is red and has been treated as permanently-expected background noise, which is how a real regression would hide. This task makes it green or documents each residual failure.

MEASURED EVIDENCE (live run, not inherited): 25 passed, 8 FAILED, 0 skipped, 33 total. Earlier reports of a 5-suite REPO_ROOT count were NOT confirmed and should be treated as superseded by this measurement. Recorded as err_1786368358319_8jwcdo.

CONFIRMED ROOT CAUSE (2 of 8): test-skill-base-lifecycle.sh and test-update-task-status.sh both abort with
    ERROR: deployed scripts tree not found at /home/benjamin/.claude/scripts
proving REPO_ROOT resolved to $HOME instead of the repo root. Both derive it as:
    REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
Five levels up is correct from the SOURCE-STORE location agent-system/extensions/core/scripts/tests/, but wrong from the DEPLOYED location .claude/scripts/tests/, which is only three levels below the repo root. The same 5-level literal appears in at least test-corroborate-phase-counts.sh, test-errors-append.sh, test-handoff-reader-parity.sh, and test-index-entries-schema.sh, so the defect class is wider than the two suites that happen to fail loudly.

PROVEN-GOOD PATTERN ALREADY IN-TREE: test-deploy-propagation.sh derives it depth-independently:
    REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
    [ -z "$REPO_ROOT" ] && REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
Adopt this shape rather than inventing a new one.

UNCONFIRMED (6 of 8) - triage each individually, do NOT assume a shared cause:
  test-common-lib.sh (1 failure; overlaps the separately-tracked opencode session-id duplication finding)
  test-index-entries-schema.sh (8 passed, 1 failed)
  test-lint-state-writer-boundary.sh (7 passed, 1 failed)
  test-loop-guard-staleness.sh
  test-reconcile-handoff-status.sh
  test-resume-scan-nonconformance.sh

NOTABLE: test-lint-state-writer-boundary.sh is the suite added by the state-writer conversion work, which reported 8/8 green in source-store context but is 7/8 in deployed mode. Determine whether this is the same depth defect or a genuine gap in the new lint.

ACCEPTANCE: run-all.sh reports 0 failures, OR every residual failure has a written, evidenced justification. Report the count honestly; never an unqualified green.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 1011. Expand defect class vocabulary
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: The system-defect vocabulary has a gap: defect classes exist for a narrow set of shapes, but at least three concrete instances from this batch do not fit cleanly into any existing defect_class value. Recorded as err_1786349061588_fqHbUZ, severity medium. Three concrete instances now ground the gap, confirmed by the capstone acceptance gate dispatch: lock/session contention (err_1786349061524_pY97cE, MT-1/MT-4 session-id mismatch), hook-regex/path-depth boundary defects (err_1786349061492_XpY38x, the 3-digit handoff-location regex), and deploy orphan-file drift (err_1786349061556_LuKGif / err_1786350581273_TAWj0I).

TARGET: wherever defect_class is enumerated for system-defect-record.sh (search the source store for its schema/enum definition) and any consumer that switches on defect_class value.

WORK: read the current defect_class enum, confirm the three instances above genuinely lack a fitting class (do not add classes for shapes that already have one), and add the minimum set of new classes needed to name them precisely -- for example a session/lock-contention class, a regex/path-boundary class, and an orphan-drift class. Update any documentation enumerating the vocabulary. Do not rename or remove existing classes as part of this task.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

CONSTRAINT: do not drive this task with multi-task /orchestrate until err_1786349061524_pY97cE (the MT-1/MT-4 session-id mismatch, spawned as a sibling task) is fixed -- multi-task orchestration is documented-broken until that lands. Use single-task /orchestrate or /implement.

---

### 1010. Fix opencode gate in session id duplication
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: tests/run-all.sh has a 7th, previously unreported deployed-mode-only failure: test-common-lib.sh flags .opencode/scripts/command-gate-in.sh for an inline sess_$(date +%s)_... session-id generator that duplicates lib/common.sh's canonical generator instead of sourcing it. It passes in source-store mode and fails only in deployed mode. Recorded as err_1786350581305_8cNAZ7. No open task currently covers tests/run-all.sh failures (the prior consolidation task that made the suites runnable is already completed); this task is spawned standalone rather than folded, since nothing is open to fold into.

TARGET: .opencode/scripts/command-gate-in.sh (the inline sess_$(date +%s)_... construction) and agent-system/extensions/core/scripts/lib/common.sh (the canonical generator it should source instead).

WORK: replace the inline session-id generator in .opencode/scripts/command-gate-in.sh with a sourced call to lib/common.sh's canonical generator, matching the pattern already used elsewhere in the deployed tree. Re-run tests/run-all.sh in BOTH source-store and deployed modes and confirm test-common-lib.sh passes in both.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**. Note: .opencode/scripts/command-gate-in.sh is itself a deploy target mirroring a source-store equivalent -- confirm the correct source-store location before editing (do not hand-edit the deployed .opencode/ tree directly if it is generated).
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

CONSTRAINT: do not drive this task with multi-task /orchestrate until err_1786349061524_pY97cE (the MT-1/MT-4 session-id mismatch, spawned as a sibling task) is fixed -- multi-task orchestration is documented-broken until that lands. Use single-task /orchestrate or /implement.

---

### 1009. Resolve deploy orphan file parity
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 1015

**Description**: Declared-vs-deployed parity for provides.* categories is one-directional by design, and the live .claude/ tree carries 4 orphan files absent from a clean scratch regenerate: context/orchestration/orchestration-validation.md, context/orchestration/subagent-validation.md, docs/architecture/architecture-spec.md, docs/README.md. Two of these (docs/architecture/architecture-spec.md, docs/README.md) were not covered by the pre-existing err_1786349061556_LuKGif (deploy_ghost_index_entries), which only named the other two -- confirmed and extended by err_1786350581273_TAWj0I (deploy_orphan_files_undercounted). This task covers BOTH error ids with one decision; do not split it.

MECHANICAL REASON (already diagnosed, do not re-derive): verify.lua's result shape has no extra/orphan field and only ever iterates the declared side; install-extension.sh's merge_index_entries() is purely additive with no stale-removal step. Parity is therefore verified only in the declared-to-deployed direction, never the reverse.

TARGET: agent-system/extensions/core/scripts/verify-deploy.sh (or the shared verify.lua module it calls), and/or docs/architecture/architecture-spec.md if the decision is to document one-directional parity as intended rather than build detection.

WORK: decide ONE of two directions and implement it -- (a) add a subtractive/orphan-detection pass to verify.lua or verify-deploy.sh that flags live files present in .claude/ but absent from a clean regenerate of every provides.* category, so future orphan drift is caught mechanically; or (b) explicitly document in docs/architecture/architecture-spec.md that provides.* parity is one-directional by design (additive only, no stale-removal), so a future reader does not mistake the current behavior for an oversight. Resolve the 4 currently-orphaned files as part of whichever direction is chosen: either they get removed/reconciled (direction a) or explicitly enumerated as accepted legacy orphans in the documentation (direction b).

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

CONSTRAINT: do not drive this task with multi-task /orchestrate until err_1786349061524_pY97cE (the MT-1/MT-4 session-id mismatch, spawned as a sibling task) is fixed -- multi-task orchestration is documented-broken until that lands. Use single-task /orchestrate or /implement.

---

### 1008. Fix orchestrate mt session id mismatch
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: None
- **Research**: [1008_fix_orchestrate_mt_session_id_mismatch/reports/01_mt-session-id-self-contention.md]
- **Plan**: [1008_fix_orchestrate_mt_session_id_mismatch/plans/01_unify-mt-session-id.md]
- **Summary**: [1008_fix_orchestrate_mt_session_id_mismatch/summaries/01_unify-mt-session-id-summary.md]

**Description**: skill-orchestrate/SKILL.md has a session-id mismatch between two of its own construction sites (MT-1 and MT-4), causing lock self-contention that fully blocks multi-task /orchestrate, a documented capability. Recorded as err_1786349061524_pY97cE, severity critical.

TARGET: agent-system/extensions/core/skills/skill-orchestrate/SKILL.md, the two session-id construction sites referenced by the MT-1/MT-4 stage labels.

WORK: locate both construction sites, determine why they produce different session_id values for what should be the same orchestrated dispatch, and unify them so a single session_id is used consistently across the stages that acquire and later reference the task lock. Add a regression test or fixture that exercises a multi-task /orchestrate invocation end to end and confirms no self-contention on the task lock.

CONSTRAINT: do not drive this task with multi-task /orchestrate until it is fixed (self-evidently -- the defect blocks the very mechanism that would exercise the fix). Use single-task /orchestrate or /implement to work this task.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 1007. Fix handoff location regex 4digit tasks
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: validate-handoff-location.sh matches .orchestrator-handoff.json paths with a fixed-position [0-9]{3} task-directory regex: (^|/)specs/(OC_)?[0-9]{3}_[^/]+/\.orchestrator-handoff\.json$. Once specs/state.json's next_project_number crosses 1000, every task directory is 4+ digits, so the regex can never match, and the hook both exits 2 with a false MISPLACED diagnostic and unconditionally calls system-defect-record.sh --defect-class HANDOFF_MISLOCATED on every handoff write under a 4-digit task -- a spurious system_defect on every such task. Recorded as err_1786349061492_XpY38x. This is the single defect currently BLOCKING the capstone acceptance gate's LIVE CYCLE scope: acceptance sub-item 3 requires the system-defect recorder to emit NO system_defect event on a clean run, and the false positive above makes that negative test structurally unpassable on any 4-digit task, independent of system health.

TARGET: agent-system/extensions/core/hooks/validate-handoff-location.sh (the regex at approximately line 65).

WORK: widen the digit-count portion of the regex to accept 3+ digits (e.g. [0-9]{3,}) so it matches both the legacy 3-digit and the current/future 4+-digit task directory naming, while continuing to reject genuinely misplaced handoff paths. Add a negative-test fixture: writing a handoff under a 4-digit scratch task directory must NOT trip HANDOFF_MISLOCATED.

CONSTRAINT: do not drive this task with multi-task /orchestrate until err_1786349061524_pY97cE (the MT-1/MT-4 session-id mismatch, spawned as a sibling task) is fixed -- multi-task orchestration is documented-broken until that lands.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 1006. Nothing prevents an agent from rewriting state.json .artifacts wholesale, silently discarding prior artifacts
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 1005

**Description**: The artifact list in specs/state.json is append-only by intent but not by enforcement. Every
sanctioned write path is additive, yet an agent that writes state.json directly can replace the
whole array, and nothing detects the loss.

SANCTIONED PATHS ARE ALREADY CORRECT (do not change them):
  - agent-system/extensions/core/scripts/orchestrator-postflight.sh:432 uses `.artifacts += [...]`
  - agent-system/extensions/core/scripts/reconcile-task-status.sh:172 (link_artifact) likewise
  - skill_link_artifacts in skill-base.sh routes through state-write.sh

THE GAP: these are helpers an agent MAY use, not a constraint it MUST satisfy. An implementation
agent updating state.json with its own jq assignment (`.artifacts = [...]`) bypasses all of them.
Nothing validates that the post-write artifact set is a superset of the pre-write set.

OBSERVED, WITH LOSS: during a real implementation dispatch, an agent updated its task's state.json
entry and the artifact list went from 11 entries to 8 -- five previously-recorded phase summaries
were dropped while two new entries were added. The summary FILES were still on disk; only the
links were destroyed, so nothing failed and no warning was emitted. The loss was caught only by a
manual count during postflight review and repaired by hand. Had it not been noticed, the task
would have archived with five phase summaries permanently unreferenced.

RELATIONSHIP TO THE STATE-WRITE CONVERSION TASK (adjacent, NOT duplicate -- read before starting):
the existing state-write conversion work targets hand-rolled read-modify-write sequences in the
SOURCE STORE, and its verification bar is a grep for `mv` onto state.json across source files.
That bar cannot catch this defect: the offending write came from an AGENT at runtime composing jq
inline, not from any checked-in script. Converting every source-store writer to state-write.sh
leaves this hole exactly as open. If the two are worked together, the deliverable here is the
superset-invariant, not another writer conversion.

WORK:
  1. Add a machine-checkable invariant: for any write touching .artifacts, the resulting set must
     contain every path present beforehand. Removal must require an explicit, named opt-in
     (legitimate cases exist -- a genuinely deleted artifact -- and must remain expressible).
  2. Enforce it where writes actually funnel. state-write.sh is the natural choke point; decide
     whether the invariant lives there (catches everything routed through it) or in
     validate-state.sh (catches drift regardless of writer, including direct jq). Prefer the
     option that ALSO catches a direct jq write, since that is the observed failure mode --
     enforcing only inside state-write.sh would miss the exact case that motivated this task.
  3. State the append-only rule explicitly in rules/state-management.md, which currently
     describes artifact linking formats without ever saying the list is append-only.
  4. Add a MUST NOT to the implementation agents that write state.json directly: never assign
     .artifacts wholesale; append, or call the helper.

VERIFICATION BAR:
  - A fixture write that drops an existing artifact path is REJECTED (or loudly flagged by the
    validator), and the same write with the opt-in flag is accepted. Both directions executed.
  - A normal additive link still succeeds unchanged; existing link_artifact / skill_link_artifacts
    call sites are unaffected.
  - The check triggers on a direct jq-composed write, not only on state-write.sh traffic.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 1005. roadmap_items is never derived by any implement path, so /todo's ROADMAP sync is dead in practice
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 1004

**Description**: /todo documents a producer/consumer contract for ROADMAP.md synchronisation in which /implement
is the producer. The consumer half is fully built; the producer half computes nothing, so the
feature has never functioned.

WHAT EXISTS (the consumer and the write path -- both fine, do not rebuild):
  - agent-system/extensions/core/commands/todo.md:1122 states the contract explicitly:
    "/implement is the **producer**: populates completion_summary and optional roadmap_items".
  - todo.md's Step 3.5 matcher implements a three-priority strategy: (1) explicit roadmap_items,
    (2) exact `(Task N)` references in ROADMAP.md, (3) summary-based search.
  - skill_propagate_completion_summary (agent-system/extensions/core/scripts/skill-base.sh:526-551)
    WRITES roadmap_items to state.json correctly when handed a non-empty value, routed through
    state-write.sh, correctly skipping task_type == "meta" and empty/`[]` values.

WHAT IS MISSING: nothing anywhere DERIVES the value passed as that third argument. Grep of the
full source store finds write sites and schema references but no derivation logic. So the helper
is called with an empty value and the write is skipped every time.

CONSEQUENCE, MEASURED: on a real archival run, 24 consecutive completed tasks were archived and
produced ZERO roadmap annotations, while 8 unchecked items sat in ROADMAP.md -- several plainly
related to the work just completed. All three matcher priorities missed:
  - Priority 1 found no task carrying a roadmap_items field (none has ever been populated).
  - Priority 2 found no `(Task N)` references, because ROADMAP.md contains none -- and per the
    repo's own no-task-references-in-deliverables rule, ROADMAP.md arguably should not contain
    them, which makes Priority 2 structurally unreliable rather than merely unused.
  - Priority 3 is an explicit unimplemented placeholder in todo.md ("not currently implemented").
So the roadmap silently drifts from reality, and the drift is invisible: /todo reports success
with "0 roadmap items updated" and no warning that its only functioning matcher found nothing.

WORK:
  1. Decide where derivation belongs and state why. Candidates: the implementation agent proposes
     roadmap_items in its return metadata (agent judgement, no new matching machinery); or a
     script matches completion_summary against ROADMAP.md text at postflight (deterministic,
     testable, but needs a matching heuristic that Priority 3 was never given).
     Prefer the option that does not invent a fuzzy matcher -- an agent naming which roadmap
     items its work closed is both cheaper and more accurate than post-hoc string similarity.
  2. Implement derivation on the chosen path and thread it into the EXISTING
     skill_propagate_completion_summary call sites. Do not add a second write path.
  3. Make an empty result visible rather than silent: when /todo archives non-meta tasks and
     matches zero roadmap items, it must say so distinctly from "there was nothing to match".
     A silent 0 is what allowed this to go unnoticed across 24 tasks.
  4. Either implement Priority 3 or delete it. A documented placeholder that reads as a working
     tier is worse than an honest two-tier matcher.
  5. Reconcile Priority 2 with the no-task-references-in-deliverables rule. If `(Task N)` markers
     are not permitted in ROADMAP.md, say so in todo.md and stop presenting Priority 2 as a
     general mechanism.

VERIFICATION BAR:
  - A completed non-meta task with a roadmap-related completion_summary produces a populated
    roadmap_items in state.json, and a subsequent /todo run annotates the matching ROADMAP.md
    item. Demonstrated end to end on a fixture, not argued.
  - A task whose work matches no roadmap item produces an explicit "no match" report.
  - task_type == "meta" still writes no roadmap_items (existing behaviour preserved).

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 1004. Fix /todo repository-metrics sync: build_errors is structurally always 0 and the technical_debt frontmatter target does not exist
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: /todo's "Sync Repository Metrics" stage cannot report a true build-health signal, and half of it writes to a target that does not exist. Both defects are live in the source store and were observed on a real /todo run.

DEFECT 1 -- build_errors is unconditionally 0 (agent-system/extensions/core/commands/todo.md:757-762):

    # Build errors (0 if project-specific lint/check passes)
    if make check 2>/dev/null || npm run lint 2>/dev/null || true; then
      build_errors=0
    else
      build_errors=1
    fi

The trailing `|| true` makes the `if` condition unconditionally true, so the `else` branch is
unreachable and `build_errors` is ALWAYS 0. Downstream, `repository_health.status` is derived as
`(if build_errors == 0 then "healthy" else "needs_attention" end)`, so the status field is always
"healthy" no matter the actual state of the repository. The field carries no information while
looking authoritative -- the worst failure mode for a health signal.

A second, subtler problem sits behind the same lines: `make check` / `npm run lint` are the only
probes, and they are wrong for most repos this system is deployed into (Python/pytest, Lean/lake,
Nix). Even with the `|| true` removed, a repo with neither a Makefile nor package.json would take
the `else` branch and report `build_errors=1` -- a false RED replacing the current false GREEN.
The fix must address the probe, not merely the boolean.

DEFECT 2 -- the technical_debt frontmatter block does not exist (todo.md:783-800 vs
agent-system/extensions/core/scripts/generate-todo.sh:315-323):

todo.md Step 5.7.3 instructs: "Read TODO.md and update the YAML frontmatter `technical_debt`
section to match state.json", and shows a `technical_debt:` / `repository_health:` block to write.
But generate-todo.sh emits ONLY `next_project_number` into the frontmatter:

    printf 'next_project_number: %s\n' "$next_num"

So there is no `technical_debt` block to update. Worse, TODO.md is generated from state.json --
any hand-written frontmatter block would be destroyed on the next generate-todo.sh run, which
/todo itself triggers. The instruction is unexecutable as written, and executing it literally
would produce work that is silently discarded.

OBSERVED: on a real /todo run the recorded repository_health was `todo_count: 8, fixme_count: 0,
build_errors: 0, status: "healthy"`, last assessed ~2 months earlier. Actual measured counts were
41 TODO and 2 FIXME. The stale figures had never been corrected because the sync stage had never
produced a meaningful result.

WORK:
  1. Decide and document what `build_errors` is actually supposed to mean. Two coherent readings:
     (a) "the tree is structurally sound" -- importable/parseable/collectable; or
     (b) "the project's own check command passes". These are different signals with different
     costs; (a) is cheap and portable, (b) is expensive and repo-specific. Pick one, state it
     where the field is defined, and make status derivation match. Do NOT leave a field whose
     meaning must be inferred from a broken heuristic.
  2. Implement the chosen probe so it can actually fail. Remove the `|| true`. If no probe is
     applicable to the repo, the honest value is "not measured", not 0 and not 1 -- if the schema
     cannot express that, extend it rather than picking a misleading number.
  3. Resolve Defect 2 in ONE direction, not both: either (a) teach generate-todo.sh to emit the
     technical_debt/repository_health frontmatter from state.json, making it generated like every
     other part of TODO.md and making Step 5.7.3 a no-op that can be deleted; or (b) delete Step
     5.7.3 and let state.json be the sole home for repository_health. Option (a) is preferred only
     if the frontmatter has a real consumer -- verify that first; if it has none, take (b).
  4. Mirror the change into skill-todo/SKILL.md, which describes the same stage.

VERIFICATION BAR:
  - A fixture repo whose check command FAILS produces a non-zero/failed build_errors and a status
    that is not "healthy". This must be an executed test, not a reasoned claim -- the current bug
    is precisely a condition that was never exercised in its failing direction.
  - A fixture repo with no recognised check command does not silently report either 0 or 1.
  - Running generate-todo.sh twice in a row leaves the frontmatter byte-identical (no
    hand-written block is destroyed, no drift is introduced).

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 1003. Fix lean-sorry-census.sh double-counting warn.sorry suppression annotations
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [1003_fix_lean_sorry_census_warn_sorry_double_count/reports/01_fix-warn-sorry-double-count.md]
- **Summary**: [1003_fix_lean_sorry_census_warn_sorry_double_count/summaries/01_fix-warn-sorry-double-count-summary.md]

**Description**: lean-sorry-census.sh counts every `set_option warn.sorry false in` suppression annotation as a
phantom extra sorry, on top of the real sorry that annotation exists to suppress. The census is
therefore inflated by exactly the number of own-line suppression annotations in the scanned scope.

ROOT CAUSE (agent-system/extensions/lean/scripts/lean-sorry-census.sh, line 144):
    sorry_re = re.compile(r'\bsorry\b')
`.` is a non-word character, so `\b` matches between `warn` and `.sorry`. The regex therefore
matches the "sorry" substring inside "warn.sorry" -- and inside any other dotted-qualified name
ending in `.sorry`. The script's comment/docstring/string-literal stripper runs BEFORE this scan
and correctly removes commented-out and string-literal sorries; the stripper is not the problem.
The final regex match is the only broken piece.

COUNTING IS PER-LINE, NOT PER-OCCURRENCE (line 158):
    if sorry_re.search(line): total += 1
This detail was discovered while verifying the bug and materially shapes the fix and its test.
Consequences:
  - Phantom inflation occurs ONLY when `set_option warn.sorry false in` sits on its own line.
    All 18 instances in the reference corpus do, which is why the observed delta equals the
    occurrence count there.
  - When the annotation shares a line with the sorry it suppresses
    (`set_option warn.sorry false in theorem foo : P := sorry`), the buggy regex and a correct
    regex BOTH yield 1 for that line, so this form does not currently inflate the count -- but a
    careless fix (e.g. skipping any line containing `warn.sorry`) would wrongly drop it to 0.
    The fix must not regress this case.

EVIDENCE (independently verified twice, most recently 2026-08-09 against ~/Projects/cslib):
  - Repo-wide census: 45 reported = 27 real + 18 phantom.
  - Cslib/Logics/Bimodal: 41 reported = 23 real + 18 phantom.
  - The 27 and 23 figures independently match the pre-existing ROADMAP.md census and a separate
    hand-audited scope.
  - Direct regex comparison over Cslib/**/*.lean (pre-stripping, hence higher absolute numbers):
    naive `\bsorry\b` = 199, corrected `(?<![.\w])sorry\b` = 181, delta = 18, and the count of
    `warn.sorry` occurrences = 18. Exact match.
  - A naive grep-style count that skips the block-comment/docstring stripper gives 152 repo-wide,
    confirming the stripper itself is correct and valuable.

WORK:
  1. Replace the line-144 regex with the negative-lookbehind form `(?<![.\w])sorry\b` (verified
     working by two independent parties). The `\w` term is redundant with the existing `\b` and is
     retained only for explicitness; excluding a preceding `.` is the substantive change, and it
     correctly covers every dotted-qualified `*.sorry` name, not just `warn.sorry`.
     An equivalent accepted alternative is a line-level pre-filter that skips any line whose
     stripped content is exactly the `set_option warn.sorry false in` directive -- but note this
     alternative must still handle the same-line form above, so the regex fix is preferred.
  2. PRESERVE strip_lean_comments() (lines 91-141) BYTE-UNCHANGED. It is correct and is the
     script's valuable part. However, its docstring at line 96 explicitly references "the
     \bsorry\b scan" it feeds; that one reference must be updated to name the corrected regex so
     the docstring does not go stale. This is a comment-text edit inside the function's docstring,
     not a change to the stripping logic -- the logic body stays byte-identical.
  3. Add a regression fixture. None exists today: `find agent-system -iname "*sorry*"` returns only
     the script itself, so this is new test scaffolding under agent-system/extensions/lean/.
     The fixture MUST cover BOTH forms:
       (a) own-line annotation:
             set_option warn.sorry false in
             theorem foo : P := sorry
           -> must count as exactly 1 (today: 2)
       (b) same-line annotation:
             set_option warn.sorry false in theorem bar : Q := sorry
           -> must count as exactly 1 (not 0, not 2) -- this pins the per-line semantics and
              guards against an over-aggressive line-skipping fix.
     Include N annotations and M real sorries and assert the census reports M. Also include at
     least one commented-out sorry and one string-literal sorry so the fixture simultaneously
     guards the stripper against future regression.
  4. Verify with the script's own `--cross-check` flag, which already exists (flag parsing at
     line 53, comparison logic at lines 179-189) and is the intended verification oracle. It
     compares the stripper count against `lake build`'s "declaration uses 'sorry'" warning count,
     which is comment- and annotation-immune by construction. A post-fix run must report
     `cross_check: MATCH` on a scope where it previously reported MISMATCH.

PRIOR STATE: the only recent commit touching this script is 8dcb6d92e, a task-number-reference
purge (3 files, 3 insertions / 3 deletions, rewriting a citation string in a comment). It did not
touch the matching logic. The bug is live in the source store.

PROVENANCE: this originated in the cslib repository, where the target path pointed outside that
repo. It is recreated in this global root because the source store lives here; a fix applied under
cslib's gitignored .claude/ deploy tree would be wiped on the next regeneration.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 1002. Author the context tier-semantics standard for the derived tier classification
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 991, Task 998
- **Research**: [1002_context_tier_semantics_doc/reports/01_context-tier-semantics.md]
- **Plan**: [1002_context_tier_semantics_doc/plans/01_context-tier-semantics.md]
- **Summary**: [1002_context_tier_semantics_doc/summaries/01_context-tier-semantics-summary.md]

**Description**: Author a context file that states the tier-classification semantics for context index entries. The meta-catch-all decomposition task converted validate-context-budgets.sh from reading a never-populated authored `tier` field to deriving tier algorithmically from load_when shape, at all four former read sites. The derivation is now real and load-bearing, but its ONLY authority is the derived_tier jq function and its header comment inside that one script -- there is no context file a human or an agent can read to learn what the tiers mean or why an entry lands in one.

THE SEMANTICS TO DOCUMENT (as landed; verify against the script rather than trusting this summary):
  Tier 1  load_when.always == true                                   -- always loaded, every prompt
  Tier 2  non-empty load_when.agents                                 -- loaded for named agents
  Tier 3  non-empty commands/task_types only                         -- loaded for named commands
  Tier 4  all hooks empty                                            -- reachable only on demand
  Current deployed distribution: Tier 1: 3, Tier 2: 144, Tier 3: 34, Tier 4: 6 (187 entries).

WORK:
  1. Write the context file (a standards/ file under core context is the natural home) covering:
     what each tier means operationally, the derivation rule, why the authored `tier` field was
     abandoned (index.schema.json sets additionalProperties:false on entries AND carries a $comment
     stating tier is deliberately absent because it is meant to be derived from load_when shape --
     the schema already asserts this design, the doc should make it discoverable), and the cost of
     the Tier 4 fallthrough decision.
  2. Cover the on_demand marker and why it exists: with Tier 4 defined as all-hooks-empty, the Dead
     Entry Check would become a tautology, so an explicit schema-declared on_demand:true property
     marks intent and preserves the check's signal. A reader needs to know when to set it -- this is
     the single most likely thing for a future entry author to get wrong.
  3. Add the index entry for the new file, with an accurate line_count (Rule R gates it) and a
     load_when hook narrow enough not to worsen any agent's budget.
  4. Point the derived_tier function's header comment at the new file so the two do not drift.

SEQUENCING NOTE: this file lands in core context/, which the docs truth sweep also claims wholesale.
It is deliberately NOT gated behind that sweep -- the knowledge is fresh now and the file is small --
so if both are in flight the runtime file-scope check will simply defer one. The sweep should treat
this file as current truth rather than re-deciding it.

VERIFICATION BAR: the new file exists with a schema-conformant index entry whose declared line_count
matches; check-extension-docs.sh passes (Rules R and T); bash .claude/scripts/validate-context-budgets.sh
introduces no new budget violation and its tier distribution is unchanged apart from the one added
entry.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 1001. Fix lean mirror entry load-order defect; audit duplicated index paths
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 991, Task 992, Task 1000
- **Research**: [1001_lean_mirror_entry_load_order/reports/01_lean-mirror-load-order-defect.md]
- **Plan**: [1001_lean_mirror_entry_load_order/plans/01_lean-mirror-load-order-fix.md]

**Description**: Fix the dormant load-order defect in lean/index-entries.json's mirror entry for contracts/adversarial-verification.md. The entry names ONLY lean-research-hard-agent in its load_when.agents. The extension loader upserts index entries BY PATH (merge.lua, append_index_entries) with last-extension-processed winning the WHOLE entry -- so in a lean-loaded deploy where lean is processed after core, lean's single-agent entry REPLACES core's and silently drops general-research-hard-agent's hook on that path. The agent keeps working; it just stops receiving a contract it is supposed to receive, with no error anywhere.

STATUS: dormant, not currently biting -- lean is not loaded in this deploy, so the replacement never
happens here. It was observed and deliberately left out of scope by the meta-catch-all decomposition
task, and recorded in that task's summary so it would not be lost. It is cheap to fix now and
genuinely unpleasant to diagnose later, since the symptom is a silently absent context file rather
than a failure.

WORK:
  1. Change lean's mirror entry to a UNION-valued load_when.agents covering every agent that should
     reach this path -- at minimum general-research-hard-agent alongside lean-research-hard-agent.
     Apply the same pattern the sibling cslib task establishes; this task is sequenced after it so
     there is one pattern, not two.
  2. Audit for the same shape elsewhere: any index entry whose path is ALSO declared by another
     extension (core especially) and whose load_when is narrower than the union of both declarations
     is the same latent defect. Enumerate every duplicated path across all extensions'
     index-entries.json and report the set, even if this task only fixes the lean instance.
  3. Consider whether the loader's silent last-writer-wins upsert on a duplicated path deserves a
     warning of its own; if so, record it as a follow-up rather than widening this task.

VERIFICATION BAR: a simulated lean-loaded merge (lean processed after core) yields an entry for
contracts/adversarial-verification.md whose load_when.agents contains BOTH agents -- demonstrated by
actually running the merge or its reconstruction, not by reading the JSON and asserting it. The
duplicated-path audit from item 2 is recorded in the task summary. check-extension-docs.sh passes.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 1000. Give cslib its own adversarial-verification contract copy and union-valued index entry
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 991, Task 992
- **Research**: [1000_cslib_adversarial_verification_mirror/reports/01_cslib-adversarial-verification-mirror.md]
- **Plan**: [1000_cslib_adversarial_verification_mirror/plans/01_cslib-h4-contract-mirror.md]
- **Summary**: [1000_cslib_adversarial_verification_mirror/summaries/01_cslib-h4-contract-mirror-summary.md]

**Description**: Give the cslib extension its own copy of the adversarial-verification contract and a union-valued index entry for it, closing a recorded regression. The meta-catch-all decomposition task removed two agent names -- cslib-research-hard-agent and lean-research-hard-agent -- from core's index entry for contracts/adversarial-verification.md, because both name agents that exist in the source store but belong to unloaded extensions and so never reach .claude/agents/ in this deploy. That removal was correct and is not to be reverted. Its recorded consequence is this task's subject: the contract is now unreachable for cslib-research-hard-agent in a cslib-loaded deploy.

WHY THE OBVIOUS ONE-LINE FIX DOES NOT WORK (established, do not re-discover):
  Adding a mirror entry to cslib/index-entries.json alone is REJECTED by check-extension-docs.sh
  Rule R, a hard gate requiring every index entry to resolve to a source file at
  <ext>/context/<path>. The lean extension's precedent works only because lean owns its own copy of
  the file (a ~93-line lean/context/contracts/adversarial-verification.md); cslib owns none. The
  decomposition task took its phase contingency and recorded the gap rather than authoring a
  ~103-line cslib copy outside its approved scope. Ordering is therefore load-bearing: the source
  file first, the index entry second.

WORK:
  1. Author agent-system/extensions/cslib/context/contracts/adversarial-verification.md. Decide
     deliberately whether it is a verbatim copy of the core contract, a cslib-specialized variant,
     or (better, if the machinery allows) a mechanism that avoids a third divergent copy of the same
     contract entirely -- three copies of one contract is itself a defect worth not creating. Record
     the rationale.
  2. Add the corresponding cslib/index-entries.json entry with a load_when.agents value that is the
     UNION of every agent that should reach this path, never a single-agent value. The loader
     upserts index entries BY PATH (merge.lua, append_index_entries) and the last extension
     processed wins the whole entry -- so a naive single-agent mirror would REPLACE core's entry and
     silently drop general-research-hard-agent's hook. This is the same load-order hazard the sibling
     lean task addresses; this task establishes the union-valued pattern that one applies.
  3. Verify the entry's declared line_count matches the authored file (Rule R gates it).

VERIFICATION BAR: REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh
passes with the new file and entry present; a cslib-loaded deploy resolves the contract for
cslib-research-hard-agent AND still resolves it for general-research-hard-agent (prove the union
survived the upsert, do not assume it); bash .claude/scripts/validate-context-budgets.sh shows no new
budget violation introduced.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 999. Reduce the 8 per-agent context budget overruns
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 991, Task 992, Task 986, Task 998, Task 1002
- **Research**: [999_per_agent_context_budget_reduction/reports/01_reduce-agent-budget-overruns.md]

**Description**: Reduce the 8 standing per-agent context budget overruns that validate-context-budgets.sh reports, so the budget check can become an instrument that passes rather than one whose failure is permanently expected. The meta-catch-all decomposition task established the diagnosis and deliberately did NOT attempt the reduction: its verification bar was re-scoped (option b) precisely because these 8 violations are load_when.agents breadth across core/nvim/nix and lay outside that task's file_scope. Raising CAPS was considered there and REJECTED with reasoning that binds this task too -- a cap set to current usage can never fail, which retires the check as an instrument. Do not resolve this task by raising caps to meet current usage.

MEASURED BASELINE (re-measure at implementation time; these are post-decomposition, deployed):
  meta-builder-agent            130400 tok  cap  15000  OVER:115400
  general-implementation-agent   68560 tok  cap   8000  OVER:60560
  neovim-implementation-agent    40104 tok  cap   8000  OVER:32104
  planner-agent                  31848 tok  cap  15000  OVER:16848
  general-research-agent         28744 tok  cap   8000  OVER:20744
  neovim-research-agent          22872 tok  cap   8000  OVER:14872
  nix-implementation-agent       22520 tok  cap   8000  OVER:14520
  nix-research-agent             19896 tok  cap   8000  OVER:11896
  (OK: spawn-agent 5568, code-reviewer-agent 5544)

WHAT THE PRIOR WORK ALREADY PROVED, so this task does not re-derive it:
  - The per-agent budget check reads ONLY load_when.agents. It never reads task_types. Trimming
    task_types therefore cannot move any number above -- this was confirmed empirically when the
    repo-wide meta trim (87 -> 0 occurrences) left the per-agent block byte-identical. The lever is
    load_when.agents breadth alone.
  - meta-builder-agent's RESOLVED context under the documented adaptive query did fall 93 entries /
    26,987 lines -> 54 / 16,634 (-38.4%) from that trim, while its budget-check number moved only
    +40. The two measurements answer different questions; this task must be explicit about which one
    it is moving, and should consider whether the check's own query is the right measure of an
    agent's real prompt cost.

WORK:
  1. Per over-budget agent, enumerate the entries its load_when.agents hook pulls in, ranked by
     line_count, and classify each as genuinely needed by that agent vs. hooked out of convenience.
  2. Narrow the hooks. Where a file is genuinely needed by many agents, consider whether it belongs
     behind a command hook, an on_demand marker, or a smaller extracted core rather than a broad
     agents list.
  3. Where a remaining overrun is deliberate and defensible, the cap may be adjusted ONLY with a
     written per-agent justification recorded next to the CAPS table stating why that agent's
     working set is legitimately that large -- never as a bulk adjustment to silence the check.
  4. Treat meta-builder-agent (8.7x its cap) as the anchor case; it likely needs decomposition of
     what "meta" work actually requires rather than incremental trimming, and may warrant being
     split into its own follow-up if the analysis shows it is a task-sized problem on its own.

SEQUENCING: depends on the EXTENSION.md slim-down (which authors NEW context files and index
entries, moving these numbers upward) and on the docs truth sweep (which consolidates four
validation docs and relocates ~250+ lines out of the claudemd merge source, moving them downward).
Measuring before both land would target numbers that are about to change materially. Also depends on
the double-loading triage and the tier-semantics doc, which share this task's file_scope.

VERIFICATION BAR: bash .claude/scripts/validate-context-budgets.sh reports zero per-agent budget
violations, OR each surviving violation carries a written per-agent justification adjacent to the
CAPS table and the count of violations has strictly decreased from 8. A before/after table of all 10
capped agents is recorded in the task summary.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 998. Triage the 49 Double-Loading context-index warnings
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 991
- **Research**: [998_double_loading_warning_triage/reports/01_double_loading_warning_triage.md]
- **Plan**: [998_double_loading_warning_triage/plans/01_double-loading-check-rekey.md]
- **Summary**: [998_double_loading_warning_triage/summaries/01_double-loading-check-rekey-summary.md]

**Description**: Triage the 49 entries the Double-Loading Check now names, and decide whether the check is a defect detector or a shape it should stop flagging. The check was restated on load_when shape (from a predicate that keyed off the never-populated authored tier field) by the meta-catch-all decomposition task and DELIBERATELY downgraded to a warning so it would not block that task; the 49 matches are pre-existing, not introduced there. A warning nobody triages is a check that has quietly stopped working -- the same failure mode that task just repaired in the Dead Entry Check, so leaving this at "WARNING -- pending triage" indefinitely re-creates the defect one layer over.

CURRENT STATE (verify at implementation time, the number moves as entries are added):
  bash .claude/scripts/validate-context-budgets.sh reports
  "Entries with both agents and commands hooks: 49 (WARNING -- pending triage)", 0 violations from
  this check, and it does not contribute to the exit code.

WORK:
  1. Enumerate the 49 entries (jq over the merged .claude/context/index.json, and per-extension over
     agent-system/extensions/*/index-entries.json so each is attributed to its owning source file).
  2. Classify each. The question is whether an entry carrying BOTH an agents hook and a commands
     hook is (a) legitimately dual-addressed -- a file that genuinely must load both for a named
     agent and for a named command that a different agent runs -- or (b) an over-broad hook that
     loads the file twice into the same resolved context, which is what the check was written to
     catch. Produce a written criterion that separates the two, not a per-entry verdict list only.
  3. Act on the classification: fix the (b) entries by narrowing a hook; for the (a) shape, decide
     whether the check should exempt it (and encode the exemption mechanically, not by lowering the
     count in a comment).
  4. Re-key the check on the outcome: either it reaches 0 and is promoted from warning back to a
     violation-producing check, or it retains a documented, mechanically-enforced exemption set and
     the warning names only genuinely-untriaged entries. Do NOT resolve this by deleting the check
     or by permanently freezing it at warning with no exemption mechanism.

SEQUENCING NOTE: this task establishes the hook-shape policy that later entry-authoring work should
follow; it deliberately does not wait on the EXTENSION.md trim work, which will author new entries
and would rather have the policy in hand than be retrofitted to it.

VERIFICATION BAR: bash .claude/scripts/validate-context-budgets.sh reports either 0 double-loading
matches, or a count consisting solely of entries covered by the recorded exemption criterion, with
the criterion enforced by the script rather than asserted in prose. A negative test proves the check
still fires: introducing one genuinely over-broad dual-hooked entry into a fixture makes it reappear.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 997. Report a confirmably-dead pid within the grace floor as its own liveness reason
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: None
- **Research**: [997_fix_session_liveness_reason_mislabel/reports/01_verify-liveness-reason-ladder.md]
- **Plan**: [997_fix_session_liveness_reason_mislabel/plans/01_dead-pid-within-grace-reason.md]
- **Summary**: [997_fix_session_liveness_reason_mislabel/summaries/01_dead-pid-within-grace-reason-summary.md]

**Description**: session_liveness() in scripts/task-lock.sh reports liveness_reason "pid-alive" for a pid that
`kill -0` just proved is GONE, whenever the entry's age is below SESSION_REGISTRY_DEAD_PID_MIN
(default 10 min). Observed live: `task-lock.sh session-list` emitted
{"pid":793539,"live":true,"liveness_reason":"pid-alive","age_min":9} for a batch session whose
process did not exist (`kill -0 793539` -> "No such process").

ROOT CAUSE (scripts/task-lock.sh, session_liveness(), the five-branch reason ladder):
  if [ -n "$pid" ] && [[ "$pid" =~ ^[0-9]+$ ]]; then
    if ! kill -0 "$pid" 2>/dev/null; then
      if [ "$age" -gt "$SESSION_REGISTRY_DEAD_PID_MIN" ]; then reason="dead-pid"; fi
    fi
  fi
  ...
  if [ -z "$reason" ]; then
    if [ -n "$pid" ] && [[ "$pid" =~ ^[0-9]+$ ]]; then reason="pid-alive"; else reason="undeterminable"; fi
  fi
When `kill -0` FAILS but age <= the grace floor, `reason` is left empty, and the final else-branch
assigns "pid-alive" on the sole basis that the pid field is NUMERIC -- it never re-consults the
`kill -0` result it already computed. The dead-pid probe's outcome is discarded below the floor.

WHAT IS AND IS NOT THE BUG:
  - The VERDICT (`live: true`) is CORRECT and must not change. The grace floor exists so a
    just-registered session is not reaped before its pid is observable (see the floor's rationale
    at the SESSION_REGISTRY_DEAD_PID_MIN definition and in context/patterns/task-lock.md's
    "Two-Signal Liveness" section). Conservative contention is the intended behavior.
  - The REASON STRING is WRONG. It positively asserts the process is alive when the script has
    just proved the opposite. This is a fifth state ("confirmably dead, still within the grace
    floor") being reported under a label that means the opposite.

WHY IT MATTERS (not merely cosmetic): liveness_reason is not internal-only -- it is propagated
verbatim into operator-facing output.
  1. scripts/orchestrate-batch-admit.sh (~lines 488-489) copies it into the session_active defer
     verdict's `session_liveness_reason` field AND interpolates it into the human-readable
     `reason` string.
  2. commands/orchestrate.md and skills/skill-orchestrate/SKILL.md both render it in the
     session_active defer warning ("liveness: {session_liveness_reason}"). An operator diagnosing
     a deferred task is told a dead session is "pid-alive", which points debugging in exactly the
     wrong direction -- toward hunting a live process that does not exist, instead of waiting out
     or reaping a stale entry.

THE DOCS CARRY THE SAME DEFECT (they describe the buggy behavior as if intended, so fixing code
alone would leave them contradicting the fix):
  - context/patterns/task-lock.md ~line 842 defines `pid-alive` as "not dead-pid, not
    stale-heartbeat, and pid is a parseable integer for which `kill -0` succeeded" -- the
    `kill -0` succeeded clause is false in exactly this window.
  - docs/architecture/batch-admit-schema.md ~line 119 enumerates "session_liveness()'s five
    reasons" and constrains the session_active case to pid-alive/corrupt/undeterminable.

WORK:
  1. Add a distinct sixth reason (suggested: `dead-pid-within-grace`) for "pid confirmably gone,
     age <= SESSION_REGISTRY_DEAD_PID_MIN". Restructure the ladder so the `kill -0` result is
     carried forward rather than discarded when the floor check fails.
  2. PRESERVE the verdict exactly: the new reason MUST map to `live: true` in cmd_session_list's
     `dead-pid|stale-heartbeat) live_flag="false"` case, and MUST NOT be reaped by
     cmd_session_reap (whose reap set stays {dead-pid, stale-heartbeat}). Confirm
     session_contention()'s contend-set is unchanged: the entry still contends.
  3. Update the two docs above, plus the five-reasons count wherever it is stated, and the
     session_active allowed-value list in batch-admit-schema.md.
  4. Check whether any consumer branches on the literal string `pid-alive` (grep both trees); the
     known consumers interpolate it as an opaque placeholder, but verify rather than assume.

VERIFICATION BAR:
  - A registry entry with a dead pid and age below the floor reports the new reason with
    `live: true`, and `session-reap --dry-run` does not select it.
  - A registry entry with a dead pid and age above the floor still reports `dead-pid` with
    `live: false` and IS selected by reap (no regression to the existing path).
  - A registry entry with a live pid still reports `pid-alive`.
  - scripts/test-conflict-predicate.sh and the session-registry reap tests still pass.
  - `bash .claude/scripts/verify-deploy.sh` passes, including the task-reference lint gate.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 996. Capstone: end-to-end verification of the refactored agent system
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 985, Task 986, Task 993, Task 995, Task 999
- **Research**: [996_capstone_end_to_end_refactor_verification/reports/01_capstone-verification-findings.md]
- **Plan**: [996_capstone_end_to_end_refactor_verification/plans/01_capstone-gate-recording.md]
- **Summary**: [996_capstone_end_to_end_refactor_verification/plans/01_capstone-gate-recording.md]

**Description**: Capstone acceptance gate for the agent-system refactor: verify the COMPOSED system end-to-end after all structural waves land. Every prior refactor task carries its own verification bar; nothing yet verifies the composition — a fresh deploy, all gates at their hardened defaults, and a live orchestrate cycle exercising routing, handoff, gate-out, and defect-recording together. This task fixes nothing structural itself: any failure is recorded (errors.json entry and/or spawned follow-up task) and the gate re-runs after the fix lands.

VERIFICATION SCOPE:
  1. DEPLOY: wipe+regenerate to a scratch tree succeeds; running it twice is byte-identical; declared-vs-deployed parity plus content-hash equality holds for EVERY provides.* category; no quarantined/deprecated file is present in the deployed tree; protected (.syncprotect) files and settings.local.json survive the round-trip.
  2. GATES: check-extension-docs.sh exits 0 with every gate mode at its hardened baked-in default (no env overrides at invocation); validate-state.sh (including --deep invariants) passes on live state; the script test runner (run-all.sh) is green; the repo-wide task-reference lint (check-task-references.sh) passes.
  3. LIVE CYCLE: one scratch-task /orchestrate cycle runs end-to-end — routing resolution yields an agent file that EXISTS on disk for every task_type declared in any loaded manifest; the cycle produces a schema-valid handoff (or, if the return-meta single-channel design was chosen, no handoff and no recovery-bridge warnings); gate-out reports zero format errors and zero auto-repaired fields; the system-defect recorder emits NO system_defect event on the clean run (the negative test) and the deferred-defect surface renders empty.
  4. Record the results as a dated review artifact under specs/reviews/ so the refactor has a closing bookend to the review that opened it.

SOURCE-STORE RULE (binding): any fixes spun out of this task target agent-system/extensions/** (or lua/neotex/plugins/ai/** for deploy machinery), never .claude/**. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 995. Convert surviving extension state.json writers to state-write.sh
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 983, Task 984
- **Research**: [995_convert_extension_state_writers_to_state_write/reports/01_convert-extension-state-writers.md]
- **Plan**: [995_convert_extension_state_writers_to_state_write/plans/01_convert-extension-state-writers.md]
- **Summary**: [995_convert_extension_state_writers_to_state_write/summaries/01_convert-extension-state-writers-summary.md]

**Description**: Convert the hand-rolled specs/state.json read-modify-write sequences that SURVIVE the skill-skeleton collapse to state-write.sh (or its guest mode). SPLIT RATIONALE (post-review): this work was originally item 5 of the state-schema/status-vocabulary task; it is split out because the skill-skeleton task collapses the 12 domain skill files onto a shared skeleton and routes the three team skills through update-task-status.sh, eliminating many of the ~110 hand-rolled writer blocks by construction (founder ~44, present ~22, web, lean, cslib — two via machine-global /tmp/state.tmp — epidemiology; all mutex-blind, most via fixed shared temp paths). Converting before the collapse would be partially wasted work, and gating the whole state-schema task on the collapse would delay the schema/vocabulary fixes needlessly. Correct sequence: collapse first, then convert the survivors against the landed schema.

WORK:
  1. Re-grep the FULL source store for hand-rolled state.json writes after the skeleton collapse lands (mv onto state.json, jq-to-temp-then-mv sequences, fixed shared temp paths such as /tmp/state.tmp) — do not trust the pre-collapse inventory counts.
  2. Convert every survivor to state-write.sh or its guest mode, preserving each site's semantics.
  3. Add the repo lint generalized from the archive/vault conversion's verification bar so the class cannot recur, wired where the other repo lints run.

VERIFICATION BAR:
  - grep for 'mv' onto state.json outside state-write.sh across the FULL source store returns zero.
  - A founder/present skill dry-run exercises the converted write path.
  - The new lint fails on a fixture containing a hand-rolled write and passes on the clean tree.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 993. Promote SCHEMA_CONFORMANCE_GATE_MODE from advisory to hard
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 987, Task 990, Task 992
- **Research**: [993_promote_schema_gates_to_hard/reports/01_promote-schema-gate-hard.md]
- **Plan**: [993_promote_schema_gates_to_hard/plans/01_promote-schema-gate-hard.md]
- **Summary**: [993_promote_schema_gates_to_hard/summaries/01_promote-schema-gate-hard-summary.md]

**Description**: Promote SCHEMA_CONFORMANCE_GATE_MODE (introduced by the prerequisite task in agent-system/extensions/core/scripts/check-extension-docs.sh, governing Rules T and U) from its advisory default to hard, mirroring the promotion sequence ORPHAN_GATE_MODE -> INDEX_TRUTH_GATE_MODE already went through once their own remediation landed. DEPENDS ON the index_entries_schema_migration and extension_md_slim_down follow-on tasks both landing clean first -- flipping the default before either lands would turn a passing doc-lint gate into a standing hard failure for every extension either task was meant to fix. WORK: change the default in the SCHEMA_CONFORMANCE_GATE_MODE="${SCHEMA_CONFORMANCE_GATE_MODE:-advisory}" line to hard, and update its preceding comment block to record that source-store remediation is now complete (mirroring INDEX_TRUTH_GATE_MODE's own comment). VERIFICATION BAR: REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh exits 0 with the gate hard (no SCHEMA_CONFORMANCE_GATE_MODE override needed at invocation time, since hard is now the baked-in default). SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 992. Trim the 6 over-length live EXTENSION.md files; resolve the 2 dead ones
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 987, Task 990, Task 991
- **Research**: [992_extension_md_slim_down/reports/01_extension_md_slim_down.md]
- **Plan**: [992_extension_md_slim_down/plans/01_extension-md-slim-down.md]
- **Summary**: [992_extension_md_slim_down/summaries/01_extension-md-slim-down-summary.md]

**Description**: Bring every EXTENSION.md into conformance with extension-slim-standard.md and Rule U (check-extension-docs.sh, check_extension_md_length), so the gate-promotion follow-on can flip SCHEMA_CONFORMANCE_GATE_MODE to hard without standing failures. Two sub-scopes:

(A) TRIM the 6 over-length LIVE EXTENSION.md files flagged by Rule U: literature (169L), email (106L), lean (73L), cslib (71L), present (64L), nix (62L) -- observed counts at the time Rule U was added; re-measure at implementation time since these may have grown further. For each, follow extension-slim-standard.md's own Migration Template to move detailed content (usage examples, architecture docs, conversion tables, migration guides, troubleshooting, prerequisites, MCP tool integration, mode descriptions) into context/project/{ext}/{domain,patterns,tools}/ files, leaving only the four required sections (Header, Routing Table, Command List, Context Pointers) in EXTENSION.md, each under the required per-section line budgets. Add an index-entries.json entry (conforming to the reconciled schema landed by the prerequisite schema-migration sibling — this task is sequenced AFTER it for exactly that reason) for every new context file created.

(B) RESOLVE the two DEAD EXTENSION.md files instead of trimming them (SCOPE MOVED HERE, post-review, from the quarantine sweep so the doc-lint lane stays self-contained and the gate promotion is not blocked behind that late sweep): core/EXTENSION.md (62L) is dead because core's manifest points its claudemd merge target at merge-sources/claudemd.md, and slidev/EXTENSION.md is dead because slidev has no claudemd merge target at all. Decide deliberately: delete each dead file (updating manifest provides.* and any references so check-extension-docs.sh passes), or teach check-extension-docs.sh that merge_targets.claudemd.source is the authority for which file must exist. Record the decision rationale. Trimming a dead file is the one WRONG outcome — it spends effort making conformant a file nothing consumes.

VERIFICATION BAR: REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh reports zero Rule U advisories across all 19 extensions (via trim for the 6 live files, via delete-or-checker-fix for the 2 dead ones); every new context file has a schema-conformant index entry.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 991. Break the meta task_types catch-all and derive tier algorithmically
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 987, Task 990
- **Research**: [991_meta_catchall_decomposition/reports/01_meta-catchall-decomposition.md]
- **Plan**: [991_meta_catchall_decomposition/plans/01_meta-catchall-decomposition.md]
- **Summary**: [991_meta_catchall_decomposition/summaries/01_meta-catchall-decomposition-summary.md]

**Description**: Break the meta task_types catch-all. WORK: (1) give the ~24 core/index-entries.json entries whose ONLY load_when hook is task_types:["meta"] real agents/commands hooks, grouped thematically per the prerequisite task's research report section 5; (2) trim the wider 123-entry task_types:["meta"] set so meta-builder-agent's resolved context stops including everything tagged meta regardless of relevance; (3) derive the tier classification algorithmically inside validate-context-budgets.sh from load_when shape (always==true -> Tier 1, non-empty agents -> Tier 2, non-empty commands/task_types only -> Tier 3) instead of querying the never-populated authored tier field (0 of 470 entries anywhere carry it, confirmed by the prerequisite task's research); (4) fix the 2 load_when.agents values across all extensions that name agents not present in this deploy. VERIFICATION BAR: bash .claude/scripts/validate-context-budgets.sh reports zero per-agent budget violations (or each remaining violation carries a documented, deliberate cap change); its 'entries with tier field' check passes via the new derivation logic rather than the authored field. SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 986. Docs truth sweep: retire dispatch-agent fiction, dead-script refs, doc consolidation
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 951, Task 960, Task 961, Task 962, Task 963, Task 969, Task 980, Task 982, Task 983, Task 984, Task 985, Task 987, Task 989, Task 992
- **Research**: [986_docs_truth_sweep/reports/01_docs-truth-sweep-findings.md]
- **Plan**: [986_docs_truth_sweep/plans/01_docs-truth-sweep.md]
- **Summary**: [986_docs_truth_sweep/summaries/01_docs-truth-sweep-summary.md]

**Description**: Make the documentation layer stop describing machinery that does not exist, and consolidate the redundant doc surfaces. This is the LAST pass of the review batch: it DEPENDS ON the deploy-engine consolidation task (the correct replacement text for every 'Load Core / Sync all' remediation instruction is decided there), the quarantine sweep (its removals change which references are dangling), the agent-contract normalization (the canonical template decision feeds item 7), and the EXTENSION.md slim-down (item 5's target shape and Rule U budgets).

INVENTORY (from specs/reviews/review-2026-07-29-agent-system.md, docs/context section; all verified):
  1. The dispatch-agent fiction: docs/architecture/system-overview.md (~line 7) asserts dispatch-agent.sh is CURRENT architecture; architecture-spec.md (599 lines) describes it in detail; docs/fork-patterns.md admits it is old; the script does not exist; dispatch-agent-spec.md is cited four times and does not exist. Retire architecture-spec.md (or rewrite to reality), fix system-overview.md, remove the dangling citations.
  2. Eight-plus references to nonexistent scripts: postflight-research/plan/implement.sh in context/patterns/jq-escaping-workarounds.md (~lines 267-273 — an ALWAYS-LOADED file, so dead recipes ship in every prompt), postflight-workflow.sh + nix-postflight.sh + nix-verify.sh in architecture-spec.md, cleanup-stale-sessions.sh in orchestration/sessions.md, validate-context-refs.sh/update-context-refs.sh in context-loading-best-practices.md, validate-all-standards.sh in postflight-tool-restrictions.md, test-implement-pipeline.sh in shell-script-testing.md. Purge or correct each (artifact-linking-todo.md's 'correctly marked removed' style is the model).
  3. Consolidate the four validation docs sharing verbatim headings (orchestration/validation.md 698L, subagent-validation.md 313L, orchestration-validation.md 233L, context/validation.md 46L) into one.
  4. Fold docs/README.md (restates CLAUDE.md's tables, titled 'v3.0') into docs/docs-README.md (the actual directory map); one README per directory.
  5. Move the 162-line '## Literature Mode (--lit)' section out of core's merge-sources/claudemd.md into the LITERATURE EXTENSION'S OWN claudemd merge-source, so it merges into a repo's .claude/CLAUDE.md only where the literature extension is loaded, with any overflow detail landing in context/project/literature/** files. Do NOT move it into literature/EXTENSION.md: the slim-down task has just brought that file under Rule U's per-section line budgets and the gate-promotion task makes Rule U a hard failure — parking 162 lines there would re-bloat it and turn the hardened gate red. Apply the same relocation test to the other ~300 lines of claudemd.md that restate always-loaded context files (Context Discovery, jq Safety, State Synchronization sections).
  6. Trim rules/no-task-references-in-deliverables.md to its ~60-line actionable constraint: move the four 'Discovered during Phase N purge' / 'Resolved test case' / 'deploy-mechanism gap' narratives (~90 lines) to a decision record under specs/; the deploy-gap narrative is additionally OBSOLETE once the deploy consolidation lands and contains the wrong Lua path.
  7. Two agent templates exist (docs/templates/agent-template.md, context/templates/agent-template.md) — keep one, redirect the other, consistent with the canonical template the agent-contract normalization task selects.
  8. Rewrite context/patterns/skill-lifecycle.md's prescribed section layout (used by zero skills) — coordinate with the skill-skeleton task which owns the replacement content.
  9. Fix the always-loaded context/patterns/context-discovery.md documented jq recipe that declares --arg lang but references $task_type (copy-pasting the recommended pattern errors).

VERIFICATION BAR:
  - grep across docs/ and context/ for each nonexistent script name returns zero hits (or only marked-removed notes).
  - check-extension-docs.sh doc-lint passes; no doc references dispatch-agent as current.
  - merge-sources/claudemd.md shrinks by >=250 lines with no loss of unique content (each removed section has a durable home); literature's EXTENSION.md stays within Rule U budgets after the move.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**. DELIVERABLE RULE: no task numbers in deliverables outside specs/**; the narratives moved out of the rule file land under specs/ where task numbers are permitted.

---

### 985. Dead-code quarantine sweep: orphan scripts, dead rules, dead Lua, vestigial twins
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 952, Task 960, Task 963, Task 964, Task 969, Task 973, Task 980, Task 981, Task 982, Task 984, Task 987, Task 988, Task 992
- **Research**: [985_quarantine_dead_scripts_rules_and_machinery/reports/01_dead-machinery-triage.md]
- **Plan**: [985_quarantine_dead_scripts_rules_and_machinery/plans/01_dead-machinery-quarantine.md]
- **Summary**: [985_quarantine_dead_scripts_rules_and_machinery/summaries/01_dead-machinery-quarantine-summary.md]

**Description**: Quarantine (never silently delete) the dead machinery the review inventoried, mirroring the literature extension's existing scripts/deprecated/ + README-with-per-file-rationale precedent. DEPENDS ON the deploy-engine consolidation task landing first, because that task decides the fate of several items below (manager.regenerate and settings_backup get WIRED there, not quarantined; sync.lua's status changes there).

INVENTORY (from specs/reviews/review-2026-07-29-agent-system.md; re-verify each at implementation time — the sibling reviews undercounted twice):
  1. Sixteen core scripts referenced ONLY by manifest.json with no caller in any command, skill, hook, doc, script, or Lua: check-vault-threshold.sh, claude-project-cleanup.sh, install-aliases.sh, install-systemd-timer.sh, lint/lint-contract-compliance.sh, migrate-directory-padding.sh, orphan-detection.sh, rename-session.sh, roadmap-sync.sh, test-four-tier-conflict.sh, test-session-runtime-files.sh, validate-context-budgets.sh, validate-extension-index.sh, vault-operation.sh, verify-lean-mcp.sh (+ literature-decode-font-offset.py in literature). TRIAGE, don't bulk-quarantine: install-aliases/install-systemd-timer/migrate-directory-padding are plausibly legitimate one-shot operator tools needing only a doc note; the two test-*.sh belong to the test-runner effort; validate-context-budgets is consumed by the context-budget task. vault-operation.sh deserves special note: it is dead AND the worst remaining state.json corruption hazard (unmutexed fixed-temp-path writes, no dependency/artifact renumbering, sed against a generated file) while skill-todo/SKILL.md carries the better prose implementation — quarantine the script and record that the prose is authoritative, OR extract the prose into a safe script; do not leave three divergent vault implementations.
  2. archive-task.sh and orphan-detection.sh: dead scripts whose logic skill-todo/commands/todo.md reimplement in prose. Either wire the scripts in or quarantine them with the prose declared authoritative — one owner per operation.
  3. Dead rules: pr-prohibition.md (96L, references cslib /pr commands not in this deploy) and project-overview-detection.md (28L) are deployed but wired to nothing (.claude/rules/ is not auto-loaded; only CLAUDE.md @-imports pull rules in, and neither is imported). Decide: wire into the @-import list or quarantine.
  4. skill-orchestrator/SKILL.md.archived — byte-identical twin of the live file (the routing task retires the skill itself; this task removes the twin).
  5. The dead .syncprotect entry (output/implementation-001.md) and the empty artifacts.settings/lib/tests glob targets in sync.lua IF the deploy task leaves sync.lua alive.
  6. Two dead EXTENSION.md files (core/EXTENSION.md — manifest points claudemd at merge-sources/claudemd.md instead; slidev/EXTENSION.md — no claudemd merge target at all). SCOPE ADJUSTMENT (post-review): this item is now DECIDED AND EXECUTED by the EXTENSION.md slim-down task, which this task depends on — that task resolves the dead-file status (delete, or teach check-extension-docs.sh that merge_targets.claudemd.source is the authority) as part of its doc-lint lane so the gate-promotion task is not blocked behind this sweep. Here, only RE-VERIFY its outcome during the caller-graph re-grep; do not re-decide or re-touch those files.

VERIFICATION BAR:
  - Every quarantined file sits under a deprecated/ dir with a README rationale line (literature's format); manifest provides.* no longer declares it; check-extension-docs.sh passes.
  - A caller-graph re-grep at implementation time confirms zero live references for each quarantined item (and finds any this inventory missed).
  - Deploy after the sweep produces a .claude/ tree with no quarantined file present.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 984. One state.json schema, one status vocabulary, converted extension writers
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: status-marker-lifecycle
- **Dependencies**: Task 962, Task 969, Task 988
- **Research**: [984_state_schema_and_status_vocabulary_single_source/reports/01_state-schema-status-vocabulary.md]
- **Plan**: [984_state_schema_and_status_vocabulary_single_source/plans/01_state-schema-single-source.md]
- **Summary**: [984_state_schema_and_status_vocabulary_single_source/summaries/01_state-schema-single-source-summary.md]

**Description**: Give specs/state.json a machine-enforced schema and make the status vocabulary a single source of truth. This SUBSUMES task 950 (marked abandoned in favor of this task — its verified command-structure.md defect inventory folds into item 4 below) and DEPENDS ON task 969 (state-write.sh archive/vault coverage) landing first so the writer conversion in item 5 has a mechanism that can address every target.

WHAT IS WRONG (from the review, specs/reviews/review-2026-07-29-agent-system.md, state-machinery section):
  1. No JSON Schema and no validator exist for state.json (contrast events-schema.json). Live data already carries the damage an unvalidated writer produces: two tasks with a stray 'updated' field alongside 'last_updated'; tasks missing 'title'. Nine live fields (topic, description, session_id, title, version, active_topics, completed_projects, memory_health, repository_health sub-fields) are undocumented; four documented fields (vault_count, vault_history, effort, reflection) appear in zero entries.
  2. TWO competing 'authoritative' status vocabularies disagree: context/standards/status-markers.md (13 values incl. revising/revised, MISSING pr_ready, stamped 2026-01-05) vs context/reference/state-management-schema.md (12 values incl. pr_ready, missing revising/revised). Neither is a superset. The list is re-typed in ~20 executable and doc locations; update-task-status.sh's map_status has no revise target so revising/revised are unreachable through the canonical writer; generate-todo.sh's format_status has a permissive catch-all '*)' arm that renders ANY off-schema status as a plausible marker instead of failing.
  3. The bootstrap template context/templates/state-template.json is a stale v1.0.0 schema whose fields do not exist in live data; the 440-line context/repo/self-healing-implementation-details.md specs an ensure_state_json() that was never implemented and would rebuild state.json FROM TODO.md — inverting the canonical direction. Both would corrupt the system if ever exercised.
  4. context/formats/command-structure.md teaches agents a FABRICATED vocabulary ('research_complete', 'ready'), the wrong store (.claude/state.json, .tasks[], .number — six occurrences, not two), and the unprotected write idiom state-write.sh exists to eliminate (two occurrences).
  5. ~110 hand-rolled state.json read-modify-write sequences remain in non-core extension SKILL.md files (founder ~44, present ~22, web, lean, cslib — two via machine-global /tmp/state.tmp — epidemiology), all mutex-blind, most via fixed shared temp paths.

WORK:
  1. Write context/schemas/state-schema.json (draft-07) matching live reality (document the nine live fields; decide the fate of the four phantom ones); add validate-state.sh; wire it into deploy verification and/or a PostToolUse path. Repair the two live off-schema entries.
  2. Make the schema's status enum THE single source: status-markers.md and state-management-schema.md both point at it; reconcile the revising/revised vs pr_ready split (decide which values are real); give update-task-status.sh a complete map; DELETE the permissive '*)' arm in generate-todo.sh (off-schema status = loud failure).
  3. Replace state-template.json with a current-schema minimal template; rewrite or delete self-healing-implementation-details.md (if kept, the recovery direction must be state-from-scratch or from git history — never from TODO.md).
  4. Fix all eight command-structure.md defect sites (vocabulary, store path, array name, key name, write idiom).
  5. Convert the non-core extension writers to state-write.sh (or its guest mode), and add the repo lint generalized from the archive/vault conversion's verification bar: grep for 'mv' onto state.json outside state-write.sh across the FULL source store returns zero.
  6. Add the cheap invariant checks the review enumerated to a validate-state.sh --deep mode: project_number uniqueness, TODO.md sync (regen-to-temp + diff), dependency-graph integrity (dangling/self/cycles), terminal-status immutability.

VERIFICATION BAR:
  - validate-state.sh passes on repaired live state and fails loudly on a fixture with a stray field, a duplicate project_number, an off-schema status, and a dangling dependency.
  - generate-todo.sh hard-fails on an off-schema status fixture.
  - The repo-wide ad-hoc-writer grep returns zero hits; a founder/present skill dry-run exercises the converted write path.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.
