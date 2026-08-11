---
next_project_number: 36
---

# TODO

## Task Order

*Updated 2026-08-11. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 14,16,17,18,19,20,27,28,33,34 | -- | agent-system, extensions, orchestration-concurrency |
| 2 | 9,13,22,31,35 | 17,18,19,33 | agent-system, extensions, orchestration-concurrency |
| 3 | 29 | 22 | agent-system |
| 4 | 30 | 29 | agent-system |
| 5 | 32 | 28,30,31 | agent-system |

**Grouped by Topic** (indented = depends on parent):

### Agent System

14 [NOT STARTED] — Two dispatches in a single batch fanned out to phase sub-agents a
17 [NOT STARTED] — command-gate-out.sh's entire post-metadata body is structurally u
  └─ 13 [NOT STARTED] — The acceptance criterion "gate-out reports zero format errors and
18 [NOT STARTED] — A repo can carry an arbitrarily stale .claude/ deploy with no sig
  └─ 9 [NOT STARTED] — Declared-vs-deployed parity for provides.* categories is one-dire
20 [NOT STARTED] — /todo's repository-metrics sync runs before its git commit, so th
27 [NOT STARTED] — .opencode/scripts/execute-command.sh is a command router that can
28 [RESEARCHING] — Rewrite the canonical MCP ownership document, whose central premi
  └─ 32 [NOT STARTED] — Deploy the accumulated source-store changes and remediate the sta
34 [NOT STARTED] — Fix a false-positive class in the destructive-git PreToolUse guar
29 [NOT STARTED] — Build the deploy-engine mechanism that lets an extension declare 
  └─ 30 [NOT STARTED] — Register the obsidian-memory MCP server through the new manifest-
    └─ 32 [NOT STARTED] — Deploy the accumulated source-store changes and remediate the sta (see above)
31 [NOT STARTED] — Give the .opencode/extensions/ mirror a real generation path from
  └─ 32 [NOT STARTED] — Deploy the accumulated source-store changes and remediate the sta (see above)

### Extensions

19 [RESEARCHING] — Reloading extensions in a consuming repo emits roughly 60 lines o
  └─ 22 [NOT STARTED] — Silence and correct opencode-agents.json fragment validation spam

### Orchestration Concurrency

16 [IMPLEMENTING] — Fix the register-bare/acquire-suffixed session-id pattern in the 
33 [NOT STARTED] — Fix two coupled, high-severity run-state-integrity defects in the
  └─ 35 [NOT STARTED] — Remove or correctly gate a one-time preflight side effect that ma

## Tasks

### 35. Stop preflight from auto-advancing an undispatched plan phase to [IN PROGRESS]
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: Task 33

**Description**: Remove or correctly gate a one-time preflight side effect that marks a plan phase [IN PROGRESS] when no agent is dispatched for it. Observed live during a real `/orchestrate --hard` run (prior run, cycle 13).

=== OBSERVED FAILURE ===

Phase 19 was left marked [IN PROGRESS] with no dispatch behind it. That false marker then misled the phase-18 agent into reporting a nonexistent CONCURRENT DISPATCH -- a false territory-conflict signal. Correcting it required a /revise run. So the impact is not cosmetic: a bogus phase marker feeds directly into the territory-contract reasoning (H7) that hard mode relies on, and produces a fabricated conflict report.

=== THE REAL OWNER IS NOT skill-base.sh ===

This matters -- do not start from the wrong file. Investigation established:

  - `skill_preflight_update` in agent-system/extensions/core/scripts/skill-base.sh (lines 214-232) contains NO phase logic at all. It only shells out to update-task-status.sh, fires a hook, and appends an event.

  - THE ACTUAL OWNER is agent-system/extensions/core/scripts/update-task-status.sh, function `update_plan_file()`, block at lines 525-583. It is guarded by `if [[ "$operation" == "preflight" ]]` at line 526. It selects the highest-versioned plan file, runs `grep -m1 -E "${PHASE_HEADING_ERE}.*\[NOT STARTED\]"`, and calls `update-phase-status.sh "$task_number" "$project_name" "$first_phase" "IN_PROGRESS"` at line 578, with no check that any agent will actually be dispatched for that phase. The dry-run echo at line 501 confirms the documented intent.

  - IMPORTANT SCOPE WIDENING: the guard is keyed on the OPERATION SLOT `preflight`, NOT on `implement`. So this side effect fires for research and plan preflights too, not only implement preflights. Confirm the true breadth before choosing a fix.

  - Call sites are in skill-orchestrate-hard/SKILL.md Stage 4 (heading line 482): lines 489 (research), 578 (plan), 695 (implement), and 849 (implement, continuation-available sub-state, already annotated "Defense-in-depth: status is typically already 'implementing' here, so this is usually a no-op").

=== THE CODE ALREADY DOCUMENTS ITSELF AS REDUNDANT ===

Comments in update-task-status.sh lines 575-577 state the call is "Superseded by the base agent owning every per-phase transition directly; this call is a redundant convenience". If per-phase transitions are genuinely owned by the dispatched agent now, the strongest fix is to DELETE the convenience rather than gate it. Verify that claim against the current agents before acting on it -- if some path still depends on the auto-advance, deletion would silently regress it.

A PARTIAL GUARD ALREADY EXISTS: `has_nonconforming_phase_headings` (line 561) skips the convenience when phase headings do not conform. Nothing gates it on actual dispatch. That existing guard shows where a dispatch-awareness check would naturally slot in.

=== EXISTING TEST COVERAGE IS INSUFFICIENT ===

scripts/tests/test-skill-base-lifecycle.sh lines 251-271 exercise only the state.json transition, never the plan-file phase side effect. The regression that would have caught this defect does not exist yet.

=== ACCEPTANCE CRITERIA ===

1. A preflight that does not dispatch an agent for a given phase never marks that phase [IN PROGRESS].
2. The chosen fix is justified explicitly as either (a) deletion of a genuinely redundant convenience, having verified the dispatched agent owns every per-phase transition, or (b) a dispatch-awareness gate, having identified a path that still needs the auto-advance. Record which and why.
3. The behaviour is settled for ALL THREE operation slots the `operation == "preflight"` guard currently covers (research, plan, implement), not implement alone.
4. A regression test asserts the plan-file phase marker is untouched by a non-dispatching preflight, covering the side effect that test-skill-base-lifecycle.sh currently misses.
5. No phase marker is left [IN PROGRESS] without a corresponding dispatch, so the territory-conflict reasoning can no longer be fed a fabricated concurrent dispatch.

=== CO-MAINTENANCE ===

The two orchestrate SKILL.md files carry an explicit contract about each other (skill-orchestrate-hard/SKILL.md lines 956-961 and 1686-1688: "an edit to either copy REQUIRES the same edit to the other; the two MUST always agree"). If this fix changes anything at the Stage 4 preflight CALL SITES rather than solely inside update-task-status.sh, the corresponding change MUST be made in skill-orchestrate/SKILL.md as well. Verify base mode's preflight call sites for the same side effect regardless, since both engines call the same shared helper -- the defect is in shared code and is therefore very likely to affect base mode identically.

=== SEQUENCING ===

Depends on the handoff-identity and loop-guard task because both edit skill-orchestrate-hard/SKILL.md; the dependency serializes the overlapping edit territory. The root-cause file here (update-task-status.sh) is disjoint from that task.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/**. NEVER edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 34. Anchor guard-destructive-git.sh destructive-pattern matching to argv, not commit-message prose
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Fix a false-positive class in the destructive-git PreToolUse guard, observed live during a real `/orchestrate --hard` run: a legitimate, entirely non-destructive `git commit` was BLOCKED purely because its message text contained wording resembling a destructive pattern. It succeeded only after the message was reworded. A guard that can be tripped by prose is both a false-positive source and, more importantly, evidence that the matching is not anchored where it should be.

FILE: agent-system/extensions/core/hooks/guard-destructive-git.sh (222 lines). Registered as a PreToolUse Bash hook at agent-system/extensions/core/root-files/settings.json line 51.

=== THE CLAIM IS PARTIALLY ACCURATE -- SCOPE IT CORRECTLY ===

The guard reads the raw top-level Bash command string at line 54 (`COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')`) and every detector then greps that string, or `[^;&|]`-delimited segments of it. But the detectors are NOT uniform, and the fix must only touch the broken half:

ALREADY SAFE (do not regress these): the `git add` over-staging detector (lines 76-89) and the `git commit` over-staging detector (lines 95-104) ALREADY strip quoted spans before flag-scanning, building `seg_scan=$(echo "$seg" | sed -e 's/\"[^\"]*\"/\"\"/g' -e "s/'[^']*'/''/g")`. Their rationale is stated at lines 70-72: "Quoted spans are stripped before flag-scanning so free-text commit messages (e.g. -m \"fix -a bug\") never false-positive." This is the correct pattern and the fix should extend it, not reinvent it.

VULNERABLE (the actual defect): the entire destructive-command MATCHED chain at lines 116-184 greps the raw string/segments with NO seg_scan quote-stripping:
  - line 120, `git reset --hard`: regex '(^|[;&|][[:space:]]*)git[[:space:]]+reset[^;&|]*--hard\b'
  - line 126, `git checkout -- <path>`: matches a bare ` -- ` anywhere after `git checkout` in the segment
  - lines 133-142, `git restore`: matches any `git restore ...` segment lacking the literal `--staged`; conversely a message containing `--staged` would FALSELY EXEMPT the command
  - lines 148-162, `git clean`: HAS_F / HAS_D scan the RAW segment, so a message such as `git clean -n -m "remove -d dirs and -f files"` sets both flags
  - lines 173-183, forced checkout/switch: '(^|[^-])-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|$)|--force' on raw segment text, so `git switch -c foo -m "hotfix -f rollout"` trips it

HIGHEST-RISK PRACTICAL CASE (matches the live observation): a single git command whose own -m / -c message argument contains flag-like or command-like prose. Example: `git commit -m "revert the git clean -fd fallout"` contains the literal substring `git clean` and `-fd`, so the line-148 detector matches on the raw command and blocks an ordinary commit.

SECONDARY DEFECT FOUND WHILE INVESTIGATING: the `git commit` segment regex at line 95 uses `[^;&|]*`, so a commit message containing a literal `|`, `;`, or `&` truncates the segment mid-message and can leak the message tail into the next scan. Segment splitting on shell metacharacters is not quote-aware anywhere in the file. Decide whether to fix this as part of the same change or record it explicitly as out of scope.

=== NO TEST COVERAGE EXISTS ===

Verified: `grep -rn guard-destructive` across the extension returns only root-files/settings.json line 51, the script's own header, and two "modeled on / mirrors" references in hooks/validate-no-task-references.sh (lines 8 and 50). scripts/tests/ contains 30 suites and none covers this hook; there is no hooks test directory at all. This task must CREATE the first test suite for it, following the house conventions used by the sibling suites in scripts/tests/ and wiring it into run-all.sh.

=== ACCEPTANCE CRITERIA ===

1. Destructive-pattern matching is anchored to argv flags and subcommands, not to free-text message content. A commit whose message merely mentions destructive wording is never blocked.
2. Genuine destructive commands are STILL blocked. Every currently-detected destructive form must remain detected -- this fix must not open a bypass in which an attacker or an agent hides a real `git clean -fd` behind quoting. Explicitly test both directions.
3. The false-exemption inverse is also closed: a quoted `--staged` in a message must not exempt a real `git restore` (lines 133-142).
4. A new regression suite at scripts/tests/test-guard-destructive-git.sh covers, at minimum: the observed false positive; each of the five vulnerable detectors at lines 116-184; a true-positive case per detector; and the already-safe `git add` / `git commit` over-staging detectors to prevent regression.
5. The new suite is wired into scripts/tests/run-all.sh and passes in both source-store and deployed modes.
6. The header comment at lines 41-47, which currently frames "the whole tool_input.command string" as the sole observation boundary, is updated to describe the actual post-fix matching contract.

NOTE ON INDEPENDENCE: this task shares no files with the orchestrator run-state work and can proceed in parallel with it.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/**. NEVER edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 33. Give .orchestrator-handoff.json per-dispatch identity and fix the exhausted-loop-guard resume deadlock
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: None

**Description**: Fix two coupled, high-severity run-state-integrity defects in the orchestrator engines. Both were observed live during a real `/orchestrate --hard` run in a separate repository; both are recorded system-defect observations with concrete evidence, not speculation. They are combined into one task because they live in the same two files, share the same co-maintenance contract, and overlap heavily on edit territory.

=== DEFECT A: HANDOFF_SINGLE_SLOT_OVERWRITE (observed twice: prior run cycle 13, and again cycle 2 of the following run) ===

PROBLEM: `.orchestrator-handoff.json` is a single fixed path per task, shared by every per-phase dispatch. Path construction carries no phase number, cycle number, dispatch id, or agent name:
  - skill-orchestrate-hard/SKILL.md line 142: HANDOFF_PATH_ABS="${TASK_DIR_ABS}/.orchestrator-handoff.json"
  - skill-orchestrate/SKILL.md line 66: the same literal expression.
Hard mode dispatches one phase per cycle, so successive phases all write the same slot (hard-mode Stage 4 handlers at lines ~495, 546, 582, 699, 849 all write/overwrite it).

OBSERVED FAILURE: a subagent that stops and is later resumed writes the slot AGAIN, after the orchestrator has already dispatched the NEXT phase. Concretely: the phase-19 agent's late write landed at mtime 1786458768, while the phase-20 dispatch window had opened at 1786458762 -- the late write is 6 seconds INSIDE the successor's window.

WHY THE EXISTING GATE CANNOT CATCH IT: Stage 5's staleness gate is purely mtime-based. Hard mode lines 1000-1006, base mode lines 581-620 (byte-identical apart from the notice prefix) compute `handoff_mtime` via stat and mark the handoff stale only when `handoff_mtime -lt dispatch_start_ts`. A late predecessor write has a NEWER mtime than the successor's dispatch start, so it passes the gate and is read as the successor's own result. The orchestrator would then apply the WRONG phase's `phases_completed`, `status`, and `blockers`.

NO CONTENT-SIDE IDENTITY EXISTS TODAY: the handoff-present read block (hard lines 1267-1345 and base equivalents) reads `.status`, `.summary`, `.next_action_hint`, `.phases_completed`, `.phases_total`, `.skeleton`, `.plan_markers_verified`, `.artifacts[0].*`, `.blockers[0].*`, and `.continuation_context.handoff_path // .continuation_path` -- never any phase or dispatch identifier. The schema at context/schemas/orchestrator-handoff-schema.json DOES define a `phase` property, but (i) it is NOT in the `required` array, (ii) docs/architecture/handoff-schema.md lines 148-149 label it "optional, informational", and (iii) its enum is the LIFECYCLE phase [research, plan, implement, revise], so it cannot discriminate plan phase 19 from plan phase 20 -- both are "implement". The nominally-present identity field is therefore useless for this purpose as it stands.

THE STANDARD'S OWN RATIONALE IS UNDERMINED: context/standards/orchestrator-runtime-files.md classifies the handoff as "Durable provenance (tracked)" and justifies tracking it on the grounds that "a documented freshness gate already protects against exactly that 'restored from an old commit' scenario". That rationale only ever considered the git-restoration hazard (an OLD mtime, which the gate does catch). It never considered the late-writer hazard (a NEW mtime from a predecessor agent), which the gate structurally cannot catch. docs/architecture/handoff-schema.md line 49 already states "A handoff at the correct path is not necessarily *this dispatch's* handoff" and then offers only mtime as the mitigation. base SKILL.md line 1204 separately acknowledges "a stale handoff from an unrelated prior hard-mode dispatch happens to sit at that path".

WHY THE PRIOR RUN SURVIVED: the prior run's own recorded note said "read-before-overwrite held this run, so no data was lost in practice". That ordering is luck. It is not enforced anywhere.

SUGGESTED DIRECTION (evaluate during research/plan, do NOT blindly adopt): give the handoff a per-dispatch identity. Candidate approaches include phase-scoped filenames plus a pointer file, or embedding a dispatch-id and/or numeric plan-phase in the handoff CONTENT which the orchestrator verifies against the phase it actually dispatched. The goal is content-based discrimination rather than timestamp-based. Weigh this against the file's current "Durable provenance (tracked)" classification and the stray-handoff sweep, both of which assume a static filename.

BLAST RADIUS (verified by grep across the source store): the handoff is referenced by core agents (general-implementation-agent, general-implementation-hard-agent, general-research-agent, general-research-hard-agent), core skills (skill-orchestrate, skill-orchestrate-hard, skill-implementer-hard, skill-team-implement), the schema, validate-handoff.sh, hooks/validate-handoff-location.sh, skill-base.sh, orchestrate-triage-classify.sh, orchestrate-recover-outcome.sh, orchestrate-dry-run-report.sh, reconcile-task-status.sh, several context patterns and contracts, AND non-core extensions: cslib (cslib-implementation-agent, cslib-implementation-hard-agent, cslib-research-agent, skill-cslib-implementation-hard, skill-cslib-research) and lean (lean-implementation-hard-agent, skill-lean-implementation-hard, context/contracts/anti-analysis.md). Any change to the identity contract MUST sweep the non-core extensions too, not just core.

=== DEFECT B: EXHAUSTED_LOOP_GUARD_RESUME_DEADLOCK (hit at the start of the following run) ===

PROBLEM: when a run terminates at MAX_CYCLES, Stage 7 prints a resume instruction, but the loop guard persists `cycle_count` across invocations and Stage 2's resume branch reads it back with no invocation discrimination. The very next invocation therefore reads cycle_count == MAX_CYCLES, the `while` loop condition is immediately false, nothing is dispatched, and the run exits at Stage 7 printing the same instruction again. The documented resume path is a guaranteed no-op.

HARD MODE EVIDENCE (skill-orchestrate-hard/SKILL.md):
  - MAX_CYCLES=13 (line 225); loop_guard_file at line 231
  - unconditional resume read at lines 317-327: cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  - loop condition line 414: while [ "$cycle_count" -lt "$MAX_CYCLES" ]
  - Stage 7 (heading line 1563), lines 1576-1581: prints "Run /orchestrate $task_number --hard to resume, or /implement $task_number --hard for manual phase dispatch."
  - Stage 8 cleanup lines 1663-1666: `rm -f "$loop_guard_file"` runs ONLY on successful completion -- "Leave loop guard and churn state on partial for resume."
So on partial exit the guard is preserved carrying cycle_count == 13 == MAX_CYCLES, and the next invocation deadlocks.

THE STALENESS DETECTOR DOES NOT CATCH THIS: the hard-mode `loop-guard-staleness` detector (sentinel-delimited, lines 247-315) has exactly three OR-combined signals -- max_cycles drift (263-266), plan_version drift (271-276), and mtime age (280-289, threshold ORCHESTRATOR_LOOP_GUARD_STALE_DAYS default 7 days). On a genuine same-plan resume none of them fire: max_cycles is unchanged, plan_version is unchanged, and the guard was just written so its mtime is fresh. A budget-exhausted-but-current guard is invisible to all three. Hard mode therefore self-heals only after the 7-day mtime backstop.

BASE MODE IS STRICTLY WORSE (skill-orchestrate/SKILL.md): MAX_CYCLES=5 (line 99), resume read at lines 112-130, and there is NO staleness detector at all (`grep -c loop-guard-staleness` returns 0). The file documents the absence as deliberate at lines 91-96: the guard is "per-cycle runtime state with no freshness check on read ... any syntactically valid guard file at this path is trusted, with no session_id or mtime comparison". Line 113 repeats "Resume: read existing guard. No session_id or mtime check". Exhaustion messages at lines 1263-1266 and 1298 both say "Run /orchestrate $task_number to continue." Guard rm -f only on clean exit (line 1286). Base mode therefore deadlocks PERMANENTLY with no self-healing path whatsoever.

OPERATIONAL IMPACT: the operator has no sanctioned way to resume an exhausted run. The observed run only proceeded because the exhausted guard was archived by hand.

CRITICAL EXISTING CONSTRAINT THE FIX MUST RESPECT: the loop guard already carries a `guard_session_id`, and scripts/test-session-runtime-files.sh Case 3 asserts that loop-guard and churn-state session_id mismatch handling MUST be a log line and MUST NEVER be a gate. Its stated rationale: "Guards the top risk: a future 'make it consistent' edit that hard-fails these files would break legitimate conversational-turn resume." The test fails if the mismatch block contains hard-fail/abort/exit/return 1, and fails if it does not log an INFO line. So the naive fix -- resetting cycle_count whenever session_id differs -- is explicitly forbidden by an existing regression test protecting a real behaviour. Any solution must distinguish a NEW OPERATOR-INITIATED INVOCATION from a CONVERSATIONAL-TURN RESUME WITHIN the same invocation. Do not weaken or delete Case 3 without a recorded justification.

SUGGESTED DIRECTION (evaluate, do not blindly adopt): a new operator-initiated invocation should receive a fresh work-cycle budget while preserving the cross-invocation history the guard carries. Decide EXPLICITLY whether cycle_count is per-invocation or per-task, then make Stage 2, Stage 7, Stage 8 cleanup, and the resume message all agree on that answer. Consider whether budget exhaustion should become a fourth staleness signal, or whether it needs a different mechanism entirely given that an exhausted guard is current rather than stale.

=== CO-MAINTENANCE (BINDING ACCEPTANCE CRITERION, NOT AN AFTERTHOUGHT) ===

skill-orchestrate/SKILL.md and skill-orchestrate-hard/SKILL.md carry an explicit co-maintenance contract about each other. skill-orchestrate-hard/SKILL.md lines 956-961: "The two MUST stay in sync: this file pair is where a one-sided fix is a known recurring defect class, because hard mode's single-task stages are a structurally separate reimplementation rather than a thin wrapper." And lines 1686-1688: "CO-MAINTENANCE: an edit to either copy REQUIRES the same edit to the other; the two MUST always agree." Supporting rationale at lines 60-64.

Apply it per defect, noting they differ in shape:
  - Defect A: the Stage 5 gate is a VERBATIM TWIN (hard 985-1030 / base 581-620). A one-sided fix here reproduces exactly the named recurring defect class. Both copies MUST be fixed together.
  - Defect B: ASYMMETRIC. The 3-signal detector exists only in hard mode; base mode documents its absence as deliberate. The base-mode fix is therefore NET-NEW code, not a mirror edit. Do not mechanically copy the hard-mode block into base without first deciding whether base mode should gain a detector at all, or whether budget exhaustion should be handled by a mechanism that suits both. Record the decision either way. Related precedent: base line 1518 records a similar asymmetry as "Hard-mode finding, recorded, not acted on".

=== ACCEPTANCE CRITERIA ===

1. A predecessor phase's late handoff write can no longer be mistaken for the successor phase's result, demonstrated by a regression test that reproduces the observed timing (late write with mtime INSIDE the successor's dispatch window) and asserts the orchestrator rejects it.
2. Whatever identity mechanism is chosen is reflected consistently in: the JSON schema, validate-handoff.sh, docs/architecture/handoff-schema.md, context/standards/orchestrator-runtime-files.md (including its now-incomplete tracking rationale), every core writer/reader listed above, and the cslib and lean extension writers.
3. An operator invoking the documented resume command on a task whose previous run exhausted MAX_CYCLES actually dispatches work, in BOTH base and hard mode. Covered by a regression test.
4. Stage 2, Stage 7, Stage 8 cleanup, and the printed resume message agree on a single explicit answer to "is cycle_count per-invocation or per-task", and that answer is documented in the source store.
5. scripts/test-session-runtime-files.sh Case 3 still passes unmodified, or its modification carries a recorded justification.
6. Both SKILL.md files are updated in lockstep for Defect A; for Defect B the asymmetry decision is recorded in both files.
7. Existing suites still pass: test-validate-handoff.sh, test-handoff-reader-parity.sh, test-loop-guard-staleness.sh, test-reconcile-handoff-status.sh, test-validate-handoff-location.sh, test-session-runtime-files.sh.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target /home/benjamin/.config/nvim/agent-system/extensions/** (core, plus the cslib and lean extensions where named). NEVER edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 32. Redeploy and remediate install once settings
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 28, Task 29, Task 30, Task 31

**Description**: Deploy the accumulated source-store changes and remediate the stale grant that the install-once mechanism structurally cannot fix.

WHY THIS IS LAST: a substantial body of MCP work now exists in the source store and has NEVER been deployed -- context/patterns/mcp-server-ownership.md does not exist in the deployed tree at all, and every correction from the preceding tasks is likewise source-only. Deploying once at the end, after the source store is settled, avoids redeploying a document that is about to be rewritten.

THE INSTALL-ONCE TRAP -- THE WHOLE POINT OF THIS TASK: the deployed .claude/settings.json still contains a mcp__lean-lsp__* wildcard that was already removed from core/root-files/settings.json in the source store. A redeploy WILL NOT fix this. That file deploys under install-once semantics (loader.lua's copy_category('root_files') gated by CATEGORY_DESCRIPTORS.root_files.install_once, with manager.unload excluding it via INSTALL_ONCE_ROOT_FILES), so once a project has its own copy it is never overwritten. The stale wildcard is ALSO a leftover from a deploy cycle when the lean extension was loaded, and an additive deep-merge never retracts. It must be removed by hand from the deployed file. Anyone who runs a deploy and assumes the grant is gone will be wrong.

EXPECTED HOOK WARNING: hand-editing .claude/settings.json will trip the source-store-boundary advisory hook. That warning is expected and correct in general but does not apply here: an install-once file is effectively user state, not a regenerable deploy artifact. Record that reasoning rather than silently ignoring the warning, and do not 'fix' it by editing the source copy instead -- the source copy is already correct.

WORK: run `bash .claude/scripts/deploy-headless.sh`; then remove the stale mcp__lean-lsp__* entry from the deployed .claude/settings.json; then run `bash .claude/scripts/verify-deploy.sh` and compare its findings against a baseline captured BEFORE the deploy, so pre-existing failures are not misread as newly introduced ones.

ALSO SETTLE, OR EXPLICITLY DEFER WITH A REASON: (a) lean-lsp is registered at user scope pointing at a DIFFERENT repository (/home/benjamin/Projects/BimodalLogic), because user-scope registration is global while that server needs a per-project path -- moving it to the new project-scoped mechanism would fix this class of bug; (b) the nine playwright grants duplicated in the web and present settings fragments become redundant once those tools are granted at machine scope in the NixOS configuration, under the grant-at-registration-scope rule. Item (b) is harmless duplication, not a fault -- treat it as cleanup and do not break working grants chasing tidiness.

VERIFICATION: mcp-server-ownership.md exists in the deployed tree; the deployed .claude/settings.json contains no mcp__lean-lsp__* entry; verify-deploy.sh reports no findings that were absent from the pre-deploy baseline; a FRESH Claude Code session (not the current one, which cannot observe registration changes) shows the expected servers. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 31. Opencode extensions sync mechanism
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 19

**Description**: Give the .opencode/extensions/ mirror a real generation path from the source store, so it stops silently drifting, and fix the live defect that drift has already produced.

SCALE -- MEASURE BEFORE PLANNING: .opencode/extensions/ is 804 git-tracked files mirroring 17 extensions (core, epidemiology, filetypes, formal, founder, latex, lean, memory, nix, nvim, present, python, slidev, typst, web, z3). An earlier estimate of '34 files' was wrong by more than an order of magnitude, so size the work against a fresh count, not against that figure. There is currently NO deploy or sync mechanism for this tree at all -- it is maintained by periodic manual 'mirror' commits, which is why the drift is structural rather than incidental.

THE LIVE DEFECT: .opencode/extensions/web/agents/web-implementation-agent.md (around line 57) still teaches `browser_verify_text_visible` as a real Playwright MCP tool. That tool does not exist. The source store at the corresponding path already retracts it explicitly. Any agent reading the .opencode copy is being taught to call a nonexistent tool. Note carefully: the source store deliberately RETAINS two mentions of that string as corrections that teach the name is fake -- a sync mechanism or cleanup pass must not mistake those for defects and 'fix' them into nonsense.

WORK: decide and implement how this tree is generated or verified. At minimum produce a drift-detection check that fails loudly when .opencode/extensions/ diverges from agent-system/extensions/**; a full generator is preferable if the two trees are genuinely meant to be identical. FIRST establish whether they ARE meant to be identical -- the trees use a different @-reference convention, so a naive byte-for-byte generator may be wrong. If a full sync is not appropriate, a drift-detection gate plus documented divergence rules is an acceptable and honest outcome; say which was chosen and why.

SCOPE BOUNDARY: another task already owns .opencode/scripts/* (dead command-router removal). Stay out of that subtree to avoid a conflicting edit.

VERIFICATION: the fake tool name no longer appears as usable guidance anywhere in .opencode/extensions/; the drift check runs clean, or reports exactly the divergences the chosen policy permits; the check is wired somewhere it will actually run rather than existing as an uninvoked script. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 30. Register obsidian memory mcp server
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 29

**Description**: Register the obsidian-memory MCP server through the new manifest-driven .mcp.json mechanism, and grant its tools at the matching scope.

CURRENT STATE: memory/settings-fragment.json carries a dead `mcpServers` block declaring obsidian-memory (npx -y @anthropic-ai/obsidian-claude-code-mcp@latest, with env OBSIDIAN_WS_PORT). It registers nothing, because settings files are not a registration surface. The memory extension IS loaded in this repository, so unlike the five retired servers this one is wanted and should be made to work.

WORK: move the declaration to the new merge target so it lands in .mcp.json, with an explicit "type": "stdio". Then determine the server's ACTUAL tool names and add matching permission grants to the fragment, applying the grant-at-registration-scope rule. Do NOT guess the tool names and do NOT copy them from any existing documentation: enumerate them empirically by starting the server and issuing a tools/list request. This system has already shipped documentation instructing agents to call MCP tools that never existed, and a naming mismatch between a declared server name and its granted mcp__<name>__* prefix has already been found in another extension -- verify both the server name and every tool name against the running server.

RUNTIME PREREQUISITE, DO NOT PAPER OVER: this server needs OBSIDIAN_WS_PORT set and a running Obsidian instance with the companion plugin. If that prerequisite cannot be satisfied in this environment, wire the declaration correctly, document the prerequisite plainly in the memory extension README, and report the tool-name enumeration as NOT VERIFIED rather than inventing plausible names. A truthful 'could not verify' is the correct outcome here; a fabricated tool list is not.

VERIFICATION: .mcp.json contains the entry after a fixture deploy; `jq empty` on both edited files; doc-lint passes for the memory extension; every granted mcp__ tool name either matches a name observed from the running server or is explicitly marked unverified with the reason. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 29. Generate mcp json from extension manifests
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 19, Task 22

**Description**: Build the deploy-engine mechanism that lets an extension declare an MCP server and have it actually registered, by generating a project-scoped .mcp.json.

WHY THIS IS NEEDED: extensions currently express server declarations as `mcpServers` keys inside settings-fragment.json, which register nothing -- settings files are not a registration surface. Project-scoped .mcp.json IS a real registration surface, and it IS reachable by dispatched subagents (verified by direct experiment; the earlier belief to the contrary rested on a session-start snapshot confound). So the fix is to route declarations to a surface that works, not to abandon the idea of extensions declaring servers.

WORK: add a new manifest merge target -- e.g. `merge_targets.mcp` with a source file per extension -- that the deploy engine collects across all LOADED extensions and writes to the repository-root .mcp.json. Mirror the existing settings merge path (process_merge_targets / merge_settings in merge.lua) rather than inventing a second idiom: the existing path is an additive, idempotent deep-merge that does not clobber pre-existing content, and it deliberately targets a file that is NOT install-once, which is exactly the property needed here. Extend manifest_spec.lua so the new key validates.

REQUIREMENTS THE MECHANISM MUST SATISFY: (a) each generated server entry carries an explicit "type" field -- as of Claude Code v2.1.202 a remote server lacking an explicit type fails fast rather than failing silently, and all current declarations omit it; (b) unloading an extension must REMOVE its servers from .mcp.json, because an additive deep-merge alone never retracts, and a stale grant surviving an unload is an already-observed defect class in this system; (c) the operation must be idempotent -- deploying twice yields a byte-identical .mcp.json; (d) hand-written entries a user added to .mcp.json themselves must survive regeneration, or the file must clearly declare itself generated. Decide (d) explicitly and record the choice.

IMPORTANT CONTEXT: a project-scoped .mcp.json server requires workspace-trust approval before `claude mcp list` will read it (v2.1.196+), and a server added to .mcp.json is invisible to any ALREADY-RUNNING session. Both facts must be documented for users, or the mechanism will be reported as broken when it is working correctly. Verify against a fresh session or `claude -p`, never against the current one.

VERIFICATION: build a scratchpad fixture project, load an extension declaring a trivial stdio server, and confirm .mcp.json is generated correctly; confirm a second deploy is a no-op; confirm unloading removes the entry; confirm `claude mcp get <name>` in the fixture reports Scope: Project config. Do NOT deploy against this repository as part of verification. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 28. Correct mcp ownership model and purge dead declarations
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Rewrite the canonical MCP ownership document, whose central premise has been empirically DISPROVEN, and purge the dead server declarations it catalogues.

ITEM 1 -- THE REFUTED PREMISE. context/patterns/mcp-server-ownership.md states that MCP server REGISTRATION belongs exclusively to user scope (~/.claude.json) BECAUSE custom subagents cannot access project-scoped .mcp.json servers. That justification is false. Direct experiment: a .mcp.json-registered stdio server exposing a sentinel tool WAS reached by a filesystem-based subagent, confirmed twice, including via the general-research-agent class this system actually dispatches, with the permission pre-granted so permission was not a confound. The original belief came from a confounded observation -- an ALREADY-RUNNING session cannot see a server added to .mcp.json after that session started, and this affects the MAIN session identically. It is a session-start tool-registry snapshot effect, unrelated to subagents or to scope. Anyone re-testing this MUST start a fresh session (or use `claude -p`) or they will reproduce the same false negative.

ITEM 2 -- THE REPLACEMENT MODEL (decided, not open for redesign). Adopt a HYBRID surface. Registration: project-scoped .mcp.json for extension-owned, repo-local servers; user scope (~/.claude.json, via home-manager or a setup script) reserved for servers that are genuine machine capabilities or need per-project computed arguments -- playwright (Nix-built wrapper binary plus a machine-level browser cache) and lean-lsp (needs a computed per-project path) are the two current user-scope cases. Add this governing rule, which the current doc lacks entirely and which is the actionable core of the whole model: GRANT PERMISSIONS AT THE SAME SCOPE WHERE THE SERVER IS REGISTERED. User-scope registration implies user-scope grants; project-scope registration implies extension settings-fragment grants. The live playwright defect is exactly this asymmetry -- registered machine-wide but granted only inside two extension fragments, so every call prompts, and DENIES outright in headless runs.

ITEM 3 -- FIX A FACTUAL ERROR IN THE DOC. Its Known-gaps table attributes 'sec-edgar, rmcp' to the epidemiology extension. Verified false: epidemiology declares only rmcp; sec-edgar is in founder alongside firecrawl. The count of five affected extensions is right; that row's attribution is wrong.

ITEM 4 -- PURGE DEAD DECLARATIONS. `mcpServers` keys inside a settings-fragment.json have never been a registration surface and register nothing. Delete these dead blocks entirely: epidemiology (rmcp), filetypes (openpyxl, superdoc), founder (firecrawl, sec-edgar). Also delete founder's five orphaned mcp__firecrawl__* / mcp__sec-edgar__* permission grants, which point at servers that do not exist. These five servers belong to extensions not loaded in this repository and are being retired rather than wired up -- that is a deliberate decision, so record it in the doc's Known-gaps section rather than silently dropping them.

ITEM 5 -- NIX IS THE EXCEPTION, HANDLE IT PRECISELY. Delete nix/settings-fragment.json's dead mcpServers block too, BUT KEEP its two permission grants (mcp__nixos__nix and mcp__nixos__nix_versions) exactly as they are. Registration for that server is moving to home-manager in the NixOS configuration repository, under the server name 'nixos' -- which is precisely what makes the existing mcp__nixos__* grants correct. VERIFIED by running the server and requesting tools/list: it exposes exactly two tools, `nix` and `nix_versions`, matching those grants and matching context/project/nix/tools/mcp-nixos-integration.md. Note the naming trap that caused this: the dead block declared the server as 'mcp-nixos', which would have produced mcp__mcp-nixos__* and broken every existing grant and doc reference.

SCOPE NOTE: file_scope names mcp-server-ownership.md as an exact FILE, deliberately not the enclosing context/patterns/ directory, because a directory-prefix declaration there overlaps an orchestrator-critical path and trips the self-modification admission gate as a false positive.

VERIFICATION: `REPO_ROOT=$(pwd) bash .claude/scripts/check-extension-docs.sh` passes for every touched extension; `jq empty` on each edited fragment; grep confirms zero surviving mcpServers keys in any settings-fragment.json; grep confirms founder's orphaned grants are gone and nix's two grants remain; the doc contains no surviving claim that subagents cannot reach project scope. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 27. Remove the dead .opencode command router and its self-referential test scripts
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: .opencode/scripts/execute-command.sh is a command router that cannot execute anything and is called by nothing but its own tests. Delete it and the three test scripts that exist only to exercise it.

SCOPE NOTE -- THIS IS NOT THE SYNTAX-ERROR TASK. A duplicated case pattern in this file was already fixed in this repo; the file parses cleanly under `bash -n` today, and separately-tracked metrics-sync work already records that fix as done. Do not re-open it. The work here is deletion of a file that is dead for reasons unrelated to that syntax defect. If someone arrives expecting a one-line syntax repair, that repair has already landed.

MEASURED EVIDENCE (live, this repo, do not re-derive):

(1) Its runtime dependency has never existed. Both live branches of its case statement emit a heredoc that runs
        source "$OPENCODE_ROOT/context/core/patterns/command-integration.sh"
        execute_lean_command "$command_name" "$arguments"
    .opencode/context/core/patterns/command-integration.sh is absent. A repo-wide grep for `execute_lean_command` across all *.sh returns matches ONLY inside execute-command.sh's own two echo strings -- the function is defined nowhere. So every successful dispatch path terminates in a missing source file followed by an undefined function. The router has no working branch; the only reachable non-error outcome is the `*)` unknown-command arm that exits 1.

(2) Nothing invokes it. Files referencing execute-command.sh outside specs/**:
        .opencode/scripts/execute-command.sh    (itself: shebang comment + usage string)
        .opencode/scripts/test-execution-system.sh   (3 references)
        .opencode/scripts/test-execution.sh          (1 reference)
        .opencode/scripts/test-command.sh            (1 reference)
        .opencode/scripts/test-results.md            (prose describing those tests)
    opencode.json contains no reference to it. No file under lua/ references it or .opencode/scripts at all. There is no other live execution path wired to this router -- it is not the mechanism by which .opencode commands actually run.

(3) The three test scripts test nothing else. They are 49, 16, and 10 lines; every reference each one makes is to execute-command.sh. Deleting the router without them would leave three scripts whose entire purpose is invoking a file that no longer exists.

(4) It is stale. Last commit touching .opencode/scripts predates this task by roughly five months.

WORK:
  1. Delete .opencode/scripts/execute-command.sh.
  2. Delete .opencode/scripts/test-execution-system.sh, test-execution.sh, and test-command.sh.
  3. Resolve .opencode/scripts/test-results.md -- it documents results for the deleted tests. Decide explicitly between deleting it and reducing it to a note recording that the router was removed; do not leave it describing tests that no longer exist.
  4. Confirm .opencode/scripts/README.md needs no edit. A grep for execute-command / test-execution / test-command / test-results against it currently returns nothing, so the expected outcome is no change -- but state that you re-checked rather than assuming, since the README is the natural place for a stale pointer to survive.

EDIT TARGET (binding): edit .opencode/** directly. A find across agent-system/ for execute-command.sh and test-execution*.sh returns nothing -- .opencode/ has no source-store counterpart in this repo and is separately git-tracked, so the source-store/deploy-boundary rule that governs .claude/** does not apply here. Do NOT attempt to locate or edit an agent-system source for these files; there is none.

DOWNSTREAM PROPAGATION (in scope to decide, not necessarily to perform): four other repos carry copies of this same router -- Logos/Theory, protocol, ModelChecker, and OpenCode. All four still contain the duplicated case pattern and therefore FAIL `bash -n`, and all four are likewise missing command-integration.sh. This repo is the reload source, so the intended mechanism is that deleting here propagates on the next reload. Verify whether reload actually removes downstream files or only adds and overwrites them -- a reload that never deletes would leave four broken copies in place indefinitely, which is a materially different outcome. Record the finding either way; if propagation does not delete, say so plainly and note what a follow-up would need to cover rather than silently assuming the copies are handled.

ACCEPTANCE: after the change, a repo-wide grep for `execute-command.sh` outside specs/** returns zero hits (or only hits inside a deliberately-retained note from item 3, accounted for individually). `bash -n` passes across every remaining .opencode/scripts/*.sh -- it already does for all thirteen non-router scripts, so this must not regress. assess-repo-health.sh reports build_errors unchanged or lower, and specifically not higher, than its pre-change value; report both numbers rather than asserting improvement.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 26. Migrate slidev deck verification from standalone npm Playwright script to MCP server
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: mcp-integration
- **Dependencies**: Task 24
- **Research**: [026_migrate_slidev_verification_to_playwright_mcp/reports/01_slidev-verification-mcp-migration.md]
- **Plan**: [026_migrate_slidev_verification_to_playwright_mcp/plans/01_slidev-verification-mcp-plan.md]
- **Summary**: [026_migrate_slidev_verification_to_playwright_mcp/summaries/01_slidev-verification-mcp-plan-summary.md]

**Description**: Migrate slidev deck screenshot verification from the standalone npm Playwright script to the live Playwright MCP server, removing the duplicate Playwright install path.

PROBLEM: the present and founder extensions carry their own Playwright usage that predates the MCP server and duplicates its capability. agent-system/extensions/present/context/project/present/talk/templates/playwright-verify.mjs is a standalone Node script requiring a separate npm Playwright install and its own browser binaries. Related references appear in present/context/project/present/talk/patterns/slidev-pitfalls.md, present/context/project/present/domain/talk-modes-and-library.md, present/context/project/present/talk/templates/slidev-project/README.md, present/index-entries.json, present/context/project/present/talk/index.json, founder/agents/deck-builder-agent.md, and founder/context/project/founder/patterns/slidev-deck-template.md.

WORK: replace the standalone-script verification path with the MCP server (browser_navigate plus browser_snapshot / browser_take_screenshot), so the system has ONE browser automation mechanism rather than two independent Playwright installs. Update the referencing context files, agent docs, and index entries consistently so nothing points at a removed path.

CAUTION -- VERIFY PARITY BEFORE DELETING: confirm the .mjs script's full capability is genuinely covered by the MCP tool set before removing it. A standalone script can do things a permissioned MCP surface cannot: custom in-page evaluation loops, batch or offline runs with no agent in the loop, and deterministic CI invocation. Note specifically that browser_evaluate and browser_run_code_unsafe are deliberately NOT allowlisted and will prompt, so any verification logic depending on in-page evaluation may not migrate cleanly. If full parity is not achievable, DOCUMENT THE RESIDUAL GAP and keep the script for that narrow case rather than forcing the migration and silently losing coverage.

DEPENDS ON the permission work: this migration is only viable once the safe browser tools run without prompting.

ACCEPTANCE: deck screenshot verification runs through the MCP server; the duplicate npm Playwright install path is removed, or its continued existence is explicitly justified in writing; all referencing docs and index entries are consistent with the outcome.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/present/** and /home/benjamin/.config/nvim/agent-system/extensions/founder/**. Never edit any deployed .claude/** tree -- those are gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 25. Activate parked Playwright MCP integration in web extension and reconcile drifted tool list
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: mcp-integration
- **Dependencies**: Task 23, Task 24
- **Research**: [025_activate_playwright_mcp_in_web_extension/reports/01_activate-playwright-mcp.md]
- **Plan**: [025_activate_playwright_mcp_in_web_extension/plans/01_activate-playwright-mcp.md]
- **Summary**: [025_activate_playwright_mcp_in_web_extension/summaries/01_activate-playwright-mcp-summary.md]

**Description**: Activate the already-designed but parked Playwright MCP integration in the web extension, and reconcile its drifted tool list against the live server.

THIS IS AN ACTIVATION TASK, NOT A GREENFIELD BUILD. A complete design already exists in agent-system/extensions/web/agents/web-implementation-agent.md (approximately lines 50-63) under the heading '**Playwright MCP** (deferred -- not yet active)' with '**Status**: Deferred pending browser binary installation'. That precondition is now satisfied: the server is registered at user scope, connected and healthy, exposing 24 browser_* tools.

DO NOT REMOVE THE web-research-agent BLOCK. agent-system/extensions/web/agents/web-research-agent.md line 4 carries 'disallowedTools: mcp__playwright__*'. This is DELIBERATE ROLE-SCOPING, not an obstacle to clear: web-implementation-agent symmetrically blocks mcp__context7__* instead. Each agent blocks the MCP server that is not its job -- research reads docs, implementation drives browsers. Leave BOTH blocks in place.

WORK:
(1) Flip the deferred status to active in web-implementation-agent.md.
(2) PRESERVE the usage conditions already written there: prefer accessibility snapshots over screenshots (lower token cost, more useful); do NOT use Playwright for tasks verifiable with 'pnpm build' alone; only use when the implementation plan includes visual verification steps.
(3) RECONCILE THE DRIFTED SPEC. The parked section lists browser_verify_text_visible, which does NOT exist among the server's actual tools. Map the deferred spec's INTENT onto real tools -- for example, text-visibility assertions map onto browser_find and/or browser_wait_for. The real 24-tool set is: browser_navigate, browser_navigate_back, browser_snapshot, browser_take_screenshot, browser_click, browser_type, browser_fill_form, browser_find, browser_hover, browser_drag, browser_drop, browser_select_option, browser_press_key, browser_wait_for, browser_resize, browser_tabs, browser_close, browser_handle_dialog, browser_console_messages, browser_network_request, browser_network_requests, browser_evaluate, browser_file_upload, browser_run_code_unsafe.
(4) Teach WHEN to drive a browser, not merely how: screenshot and visual verification of a running app, console and network inspection for debugging, end-to-end UI checks. Add a context file under agent-system/extensions/web/context/ and register it in web/index-entries.json if a new file is created.
(5) Keep guidance consistent with the permission split from the prerequisite task: guidance must NOT instruct agents to rely on tools that still prompt (browser_run_code_unsafe, browser_evaluate, browser_file_upload), since that would reintroduce the autonomous-run stall.

ACCEPTANCE: web-implementation-agent documents an active, accurate Playwright MCP capability naming only tools that actually exist; web-research-agent's disallowedTools line is unchanged; no guidance depends on a tool that still prompts.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/web/**. Never edit any deployed .claude/** tree -- those are gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 24. Scope Playwright MCP permission allowlist to safe browser tools, solving install-once propagation
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: mcp-integration
- **Dependencies**: Task 23
- **Research**: [024_scope_playwright_mcp_permission_allowlist/reports/01_scoped-playwright-permission-allowlist.md]
- **Plan**: [024_scope_playwright_mcp_permission_allowlist/plans/01_scoped-playwright-permission-allowlist.md]
- **Summary**: [024_scope_playwright_mcp_permission_allowlist/summaries/01_scoped-playwright-permission-allowlist-summary.md]

**Description**: Add a deliberately scoped Playwright MCP permission allowlist so autonomous runs stop stalling, without blanket-allowing arbitrary execution.

PROBLEM: mcp__playwright__* is absent from every settings allowlist while mcp__lean-lsp__* is present, so every browser call raises a permission prompt. Under /orchestrate there is no human available to answer, so autonomous runs stall.

DESIGN (fixed by user decision, not open for redesign): allowlist ONLY the safe navigation and inspection tools -- browser_navigate, browser_snapshot, browser_take_screenshot, browser_console_messages, browser_network_requests, browser_click, browser_type, browser_find, browser_wait_for. Deliberately OMIT browser_run_code_unsafe, browser_evaluate, and browser_file_upload: these are arbitrary-execution/upload tools and MUST continue to prompt.

GRANULARITY IS ALREADY PROVEN EXPRESSIBLE -- DO NOT RE-RESEARCH THIS. nix/settings-fragment.json allowlists mcp__nixos__nix and mcp__nixos__nix_versions individually; lean/settings-fragment.json enumerates 21 individual mcp__lean-lsp__lean_* entries; founder's fragment likewise enumerates individual tool names. Per-tool MCP permission entries work.

'KEEP PROMPTING' NEEDS NO ask/deny RULE: omission from permissions.allow already yields a prompt. The existing permissions.deny list is Bash-only (rm -rf /, rm -rf ~, sudo *, chmod 777 *) and there is no ask key in use anywhere. Do not invent one.

THE REAL HAZARD -- INSTALL-ONCE PROPAGATION: core/root-files/settings.json deploys to .claude/settings.json under install-once semantics (loader.lua's copy_category('root_files'), gated by CATEGORY_DESCRIPTORS.root_files.install_once; manager.unload also excludes these files via loader_mod.INSTALL_ONCE_ROOT_FILES). Once a project has its own .claude/settings.json, reloading or re-loading the providing extension NEVER overwrites it. Therefore simply editing core/root-files/settings.json will NOT reach any existing project. This task must establish how the new grants actually propagate -- for example via an extension settings-fragment.json (which targets .claude/settings.local.json and is not install-once), via user-scope settings, or via a documented migration step -- consistent with the ownership boundary decided in the prerequisite task.

ACCEPTANCE: in a project that ALREADY has a .claude/settings.json, the 9 safe browser tools run without prompting, and browser_run_code_unsafe, browser_evaluate, and browser_file_upload still prompt. Verify against a pre-existing settings file, not a freshly generated one -- a fresh project would mask the install-once defect.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never edit any deployed .claude/** tree -- those are gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 23. Document MCP registration vs permission ownership boundary; reconcile lean-lsp three-way duplication
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: mcp-integration
- **Dependencies**: None
- **Research**: [023_document_mcp_registration_ownership_boundary/reports/01_mcp-registration-ownership-boundary.md]
- **Plan**: [023_document_mcp_registration_ownership_boundary/plans/01_mcp-ownership-boundary.md]
- **Summary**: [023_document_mcp_registration_ownership_boundary/summaries/01_mcp-ownership-boundary-summary.md]

**Description**: Define and document the ownership boundary between the four competing MCP registration/permission mechanisms, and reconcile the existing lean-lsp three-way duplication.

PROBLEM: the agent system now has FOUR mechanisms that can register an MCP server or grant its permissions, with no documented boundary between them:
(1) A home-manager activation block writing to ~/.claude.json (user scope). This is how the playwright MCP server was registered; it is connected and healthy, exposing 24 browser_* tools.
(2) Per-extension settings-fragment.json, deployed via the manifest's settings section ({"source": "settings-fragment.json", "target": ".claude/settings.local.json"}). Used by nix (mcp-nixos plus 2 enumerated tool permissions) and lean (lean-lsp plus 21 enumerated tool permissions).
(3) core/root-files/settings.json, deployed to .claude/settings.json as INSTALL-ONCE. Currently carries a mcp__lean-lsp__* WILDCARD in permissions.allow.
(4) core/scripts/setup-lean-mcp.sh, which registers lean-lsp directly into user scope ~/.claude.json.

EVIDENCE THE PROBLEM IS REAL AND ALREADY BITING: lean-lsp is currently registered or permitted by THREE of these simultaneously (mechanisms 2, 3, and 4), and mechanisms 2 and 3 disagree about form -- the extension fragment enumerates 21 individual tools while core grants a blanket wildcard. This is precisely the duplication the playwright integration must avoid repeating.

KEY ARCHITECTURAL CONSTRAINT (already recorded in core/scripts/setup-lean-mcp.sh's own header): custom subagents CANNOT access project-scoped MCP servers (.mcp.json); user scope (~/.claude.json) is required for subagent access. Since agents are the consumers of browser tools, this argues that REGISTRATION belongs in user scope (home-manager or a setup script), while PERMISSION GRANTS must live in the settings files the host app reads. Confirm or refute this split rather than assuming it.

DELIVERABLE: a decision recorded in the source store stating which mechanism owns MCP server REGISTRATION, which owns PERMISSION grants, why, and how the two compose. Update permission-configuration.md and/or extension-system.md, adding a context pattern if warranted. Reconcile the lean-lsp wildcard-vs-enumeration split, or explicitly justify keeping it.

ACCEPTANCE: a future extension author can read one document and know where to declare a new MCP server and its permissions without creating a fifth duplicate path.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/**. Never edit any deployed .claude/** tree -- those are gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 22. Silence opencode fragment validation spam
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 19

**Description**: Silence and correct opencode-agents.json fragment validation spam on extension reload.

SYMPTOM (observed live): reloading .claude/ via <leader>al from a project with an
opencode.json.managed marker emits ~60 WARN notifications of the form "Extension 'X'
opencode-agents.json validation failed: Agent 'Y' references missing file: Z. Skipping
fragment." before "Resynced 12 extension(s)".

EMITTER: M.generate_opencode_json in lua/neotex/plugins/ai/shared/extensions/merge.lua
(vim.notify at ~line 994), gated on an opencode.json.managed marker check (~line 931), with
per-fragment validation by M.validate_opencode_fragment (~line 887), which resolves each agent
prompt's {file:PATH} against project_dir.

THREE DISTINCT DEFECT CLASSES (measured against a live project, not assumed):

(1) MISSING DEPLOY TARGETS -- 16 of 18 {file:} refs across python (2), present (5), nix (2),
and filetypes (7) point at .opencode/agent/subagents/*-agent.md files that were never
deployed. The .opencode/agent/subagents/ directory DOES exist and holds 15 agent files
(core, lean, latex, typst, math, logic, physics, formal, meta-builder, planner,
code-reviewer), but none for those four extensions. So this is a partial-deploy gap, not a
wholly absent tree.

(2) LEAN WRONG-PATH BUG (independent of any opencode policy decision) --
agent-system/extensions/lean/opencode-agents.json is the ONLY fragment using a .claude/ path
shape. It references .claude/extensions/lean/agents/lean-research-agent.md and
.claude/extensions/lean/agents/lean-implementation-agent.md, neither of which exists anywhere,
while the CORRECT files .opencode/agent/subagents/lean-research-agent.md and
.opencode/agent/subagents/lean-implementation-agent.md ALREADY EXIST on disk. This is a plain
mis-pathed reference, fixable on its own merits regardless of what is decided about opencode.

(3) NOTIFICATION SPAM AND SIMULTANEOUS UNDER-REPORTING -- the same 5 messages repeat ~12 times
because generation runs once per resynced extension rather than once per reload. Separately,
validate_opencode_fragment iterates with pairs() and returns on the FIRST missing ref, so only
one broken ref per extension is ever named, and WHICH one varies nondeterministically between
runs (python alternates python-research/python-implementation; filetypes alternates
scrape/filetypes-spreadsheet). The true breakage (18 refs) is therefore both over-announced in
aggregate and under-reported per message.

BINDING CONSTRAINT (from the user): .opencode/ is NOT currently used and may be excluded from
scope, BUT the fix MUST NOT damage or delete .opencode/ infrastructure. The opencode-agents.json
fragments, the validator function, the managed-marker gating, and the existing .opencode/ tree
must all survive intact so .opencode/ can be refactored in the future. Prefer suppressing or
gating the noise over removing the mechanism.

ACCEPTANCE: a <leader>al reload from a project carrying an opencode.json.managed marker
produces no validation-failure spam; the lean fragment's two refs resolve to real files;
whatever gating approach is chosen is documented; and no opencode fragment, no validator
function, and no .opencode/ file is deleted.

SOURCE-STORE RULE (binding): edit lua/** for the Lua emitter and agent-system/extensions/** for
the JSON fragments; never edit .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 21. Vault transition comment is wiped by TODO.md regeneration, corrupts frontmatter where it runs
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [021_resolve_vault_transition_comment_nondurable/reports/01_resolve-vault-transition-comment.md]
- **Plan**: [021_resolve_vault_transition_comment_nondurable/plans/01_resolve-vault-transition-comment.md]
- **Summary**: [021_resolve_vault_transition_comment_nondurable/summaries/01_resolve-vault-transition-comment-summary.md]

**Description**: /todo and skill-todo both instruct the vault path to hand-insert an HTML transition comment into specs/TODO.md, but generate-todo.sh regenerates that file wholesale, so the comment is wiped by the next regeneration. The instruction is also actively harmful where it does run: as written it corrupts the YAML frontmatter and duplicates itself. Decide the correct resolution and apply it consistently.

THE DECISION IS ALREADY ON RECORD -- this is a re-regression, not a new finding. The archived summary at
    specs/vault/01-vault/archive/653_update_task_creation_commands_state_first/summaries/01_task-creation-migration-summary.md
states under Decisions:
    "Vault transition comment: Removed the Python script that inserted HTML comments into TODO.md frontmatter. Since generate-todo.sh regenerates the entire file, vault transition info is preserved in state.json's vault_history array instead."
That earlier work removed the SCRIPT but left the PROSE INSTRUCTION in place, so the behavior was re-specified in the two live documents that callers actually follow. Treat that recorded decision as strong prior art; if the resolution chosen here differs from it, say why explicitly rather than silently diverging a second time.

MEASURED EVIDENCE (live, this investigation -- do not re-derive):

(1) The comment does not survive. A vault run inserted the documented comment after TODO.md's frontmatter; the very next state-write with --regen-todo removed it. generate-todo.sh treats TODO_FILE purely as an output target -- it is referenced only as a default path, an argument, an mktemp sibling, and the destination of `mv "$TEMP_FILE" "$TODO_FILE"`. There is no read of the existing file anywhere, so nothing hand-written into TODO.md can persist by construction.

(2) The skill's insertion corrupts the frontmatter AND double-inserts. Running skill-todo's exact sed against a real 3-line frontmatter (---, next_project_number: N, ---) produced:
    ---
    next_project_number: 20
    <!-- Vault transition: ... -->
    ---

    <!-- Vault transition: ... -->
    # TODO
The range /^---$/,/^---$/ matches the closing delimiter as well as the opening one, so `a` fires twice: once after the line following the opening --- (placing an HTML comment INSIDE the YAML block, which is not valid YAML) and once after the closing ---. Any consumer that parses TODO.md frontmatter strictly would see a malformed block.

(3) The computed task range is wrong. skill-todo derives the range as $((next_num - renumber_count - 1)). With this run's real values (next_num 1020, renumber_count 11) that yields 1008, so the comment would have claimed "tasks numbered 1 through 1008 archived" -- but the vault actually contains everything through 1015, and 1008 is not the renumbering boundary either. The number describes nothing.

LIVE SITES (both in the source store, both currently instructing the broken behavior):
  agent-system/extensions/core/commands/todo.md:893-898  (Step 5.8.9)
  agent-system/extensions/core/skills/skill-todo/SKILL.md:877-890  (the sed block)

DURABLE RECORDS THAT ALREADY EXIST (the reason deletion is viable):
  specs/state.json .vault_history[] -- {vault_number, vault_dir, created_at}
  specs/vault/{NN}-vault/meta.json -- {vault_number, created_at, archived_count, final_task_number}
Both were written correctly by the vault run that exposed this, so no information is lost today if the comment goes away.

PRECEDENT FOR THE RESOLUTION SHAPE: commands/todo.md Step 5.6.2 already documents this same overwrite property as the reason repository_health lives in state.json only and is deliberately NOT mirrored into TODO.md frontmatter. Whatever is decided here should be consistent with that existing, already-reasoned stance.

WORK -- evaluate these and pick one, recording the reasoning:
  (a) Delete the step from both live sites and rely on vault_history + meta.json. Matches the recorded decision, removes machinery, loses the at-a-glance signal in TODO.md.
  (b) Render the transition line from state.json .vault_history inside generate-todo.sh, so it is generated rather than hand-inserted and therefore survives every regeneration. Keeps a user-visible signal; costs a new rendering branch and a test.
  (c) Make generate-todo.sh preserve hand-authored comments across regeneration. Note that this contradicts the deliberate full-overwrite, atomic mktemp+mv design and would reintroduce read-modify-write; if rejected, say so rather than leaving it unconsidered.
Whichever is chosen, no live document may be left instructing a caller to hand-edit TODO.md for vault transitions.

ALSO IN SCOPE (adjacent, cheap, same section): commands/todo.md's vault section is headed "5.7. Vault Operation" while all nine of its substeps are numbered 5.8.1 through 5.8.9. Reconcile the numbering so a reader following a cross-reference to "Step 5.7" finds substeps that match.

SCOPE DECISIONS REQUIRED (state each explicitly, do not silently skip):
  - agent-system/extensions/core/scripts/deprecated/vault-operation.sh:242 carries the same comment logic but is quarantined under deprecated/. Confirm it stays untouched rather than "fixed".
  - Five .opencode/** copies carry the same instruction (.opencode/commands/todo.md, .opencode/extensions/core/commands/todo.md, .opencode/skills/skill-todo/SKILL.md, .opencode/extensions/core/skills/skill-todo/SKILL.md, .opencode/scripts/vault-operation.sh). .opencode/ has no agent-system source and is separately tracked, and separate work already covers opencode drift. Decide whether these are updated here or deferred there, and record which -- leaving five unlabeled copies of a known-broken instruction is not an acceptable outcome.

ACCEPTANCE: a vault operation followed immediately by a TODO.md regeneration leaves the file in the intended end state -- either no transition comment at all with the durable records present, or a comment that regeneration reproduces identically. specs/TODO.md's frontmatter must still parse as a closed, valid YAML block afterward; demonstrate this by parsing it, not by eyeballing. Grep the live (non-deprecated) source store for the transition-comment string and report the surviving count with justification for each survivor.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

FILE OVERLAP: separately-tracked work on the repository-metrics sync ordering also edits agent-system/extensions/core/commands/todo.md. Neither task depends on the other, but they touch the same file and should not run concurrently without re-reading it.

---

### 20. Metrics sync measures a stale git index, inflating build_errors with phantom paths
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: /todo's repository-metrics sync runs before its git commit, so the health probe measures a tree whose git index still points at pre-move paths. Every archived-away file is counted as a structural failure, inflating build_errors and flipping status to "critical" on a healthy tree.

MEASURED EVIDENCE (live /todo run archiving 20 tasks, this is not inherited): Step 5.6 reported
    {"todo_count":44,"fixme_count":2,"build_errors":89,"status":"critical"}
Re-running the identical probe after the commit reported build_errors: 1. Of the 89, 88 were phantom and exactly 1 was real (a duplicated case pattern in .opencode/scripts/execute-command.sh, fixed separately; the probe then reported build_errors: 0, status "healthy"). So the reported figure was wrong by 88 and the derived status was wrong outright.

CONFIRMED ROOT CAUSE (two independent contributing defects, both must be addressed):

(1) The probe counts paths that no longer exist. assess-repo-health.sh's enumerate_by_glob builds candidates from `git ls-files -z -- "$glob"` and emits "$ROOT/$rel" with no existence check. Both structural loops then guard only emptiness, not existence:
        for f in "${SH_FILES[@]}"; do
          [ -n "$f" ] || continue
          if ! bash -n "$f" >/dev/null 2>&1; then errors=$((errors + 1)); fi
A path present in the index but absent on disk fails `bash -n` / `jq empty` for the trivial reason that there is no file to parse, and is scored as a structural error. This is caller-independent: any uncommitted rename, delete, or move produces the same inflation, so the probe is wrong on its own terms and not merely mis-sequenced. total_candidates is also inflated by the same phantom paths, which perturbs the degenerate zero-candidate branch that emits build_errors: null.

(2) /todo sequences the probe against exactly the tree state that triggers (1). commands/todo.md places Step 5.6 (Sync Repository Metrics, calling assess-repo-health.sh at the documented line) after Step 5D's directory moves and Step 5.7's vault operation, but before Step 6's `git add specs/` + commit. The one caller most likely to have just moved hundreds of files measures before recording them.

WORK:
  1. Make the probe existence-safe: skip candidates that are not present on disk, and exclude them from total_candidates so the null/"unknown" branch stays meaningful. Decide explicitly whether a phantom path should be silently skipped or surfaced as a separate diagnostic field (an index/worktree divergence is itself a signal worth reporting); state the decision and its reasoning.
  2. Re-sequence /todo so the metrics sync reflects the tree it actually commits. Either move Step 5.6 after Step 6, or have Step 6 re-sync afterward. Do not rely on fix 1 alone to paper over the ordering: fix 1 stops the false inflation, but a pre-commit measurement still describes a tree that is about to change.
  3. Check for other callers of assess-repo-health.sh with the same pre-commit exposure and note whether each is affected.

ACCEPTANCE: a /todo run that archives at least one task with a directory reports the same build_errors and status as an identical probe run immediately after its commit, and both match the true count for the tree. Demonstrate both directions -- a genuinely broken file must still be counted (a probe that can only ever report zero is not a fix), and a large batch of moved-but-uncommitted files must contribute zero. Report the measured before/after counts explicitly; never an unqualified green.

REGRESSION LOCK: add a test that stages nothing, moves a tracked *.sh or *.json to a new path, runs the probe, and asserts the moved file contributes no error. Without this the defect silently returns on the next refactor of enumerate_by_glob.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 19. Fix opencode agent-fragment path resolution and validator fail-fast
- **Effort**: 3h
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Reloading extensions in a consuming repo emits roughly 60 lines of "Extension '<name>' opencode-agents.json validation failed: Agent '<agent>' references missing file: <path>. Skipping fragment." The resync otherwise succeeds and the Claude Code deploy is correct and complete, so nothing the user relies on today is broken. .opencode/ is NOT currently in use, though the user intends to return to it. Priority is therefore low: the present cost is misleading reload noise, and the real cost is latent, namely that whenever OpenCode is picked back up, 18 agents will be silently missing behind noise that has already been trained into background.

MEASURED EVIDENCE (do not re-derive). In a repo with 12 active extensions, the generated opencode.json contains 15 agents and 18 are dropped: lean 2, python 2, nix 2, filetypes 7, present 5. lua/neotex/plugins/ai/shared/extensions/merge.lua:886 validate_opencode_fragment resolves each agent's {file:PATH} prompt against project_dir and returns false on the FIRST unreadable path, so generate_opencode_json discards the ENTIRE fragment.

ROOT CAUSE 1 - the referenced directory is deployed by nothing. Ten of twelve fragments use {file:.opencode/agent/subagents/<agent>.md}. A grep of the whole lua/ tree for "opencode/agent" returns exactly one hit and it is a test fixture (commands/picker/operations/sync_spec.lua:100). No deploy, install, or resync path populates .opencode/agent/subagents/ at all. The 16 files present in the consuming repo are unmaintained legacy artifacts predating the current manifest-driven engine. latex (2/2), typst (2/2), and formal (4/4) validate only by accident because their agent files happen to be among those 16 leftovers; python, nix, filetypes, and present reference correctly-named files that were simply never deployed.

ROOT CAUSE 2 - lean uses a third convention, also wrong. agent-system/extensions/lean/opencode-agents.json uses {file:.claude/extensions/lean/agents/<agent>.md}, a directory that does not exist in the deployed tree. Those files are present both at the standard .opencode/agent/subagents/ path and at .claude/agents/. Pure path bug.

ROOT CAUSE 3 - present references an agent that exists nowhere. agent-system/extensions/present/opencode-agents.json declares an agent keyed "slides" pointing at slides-agent.md. No slides-agent.md exists anywhere under agent-system/extensions/; the real file is agent-system/extensions/present/agents/slides-research-agent.md. Stale name after a rename. timeline-agent.md in the same fragment DOES exist in source - do not flag it.

AMPLIFIER. Fail-fast-on-first-miss silently discards a whole fragment for one bad reference, which is why present loses all 5 agents. Lua pairs() ordering is nondeterministic, so each validation pass names a different arbitrary agent, making the reload output look inconsistent and repetitive across passes while never revealing the true count. The task must decide whether the validator changes to report ALL missing references per fragment.

DECISION REQUIRED - evaluate explicitly, do not treat any as pre-chosen: (a) repoint every fragment's {file:...} at .claude/agents/<agent>.md; (b) add a deploy step that populates .opencode/agent/subagents/; (c) gate opencode fragment processing off entirely while .opencode/ is dormant, so the noise stops without committing to a path convention that may be revisited when OpenCode returns; (d) some combination. Option (a) is the scouted recommendation but is not a fait accompli: .claude/agents/ IS deployed and maintained by the current engine and contains all 48 agents including every one currently reported missing (verified individually for python-implementation, nix-research, filetypes-router, funds, lean-implementation, slides-research, timeline), so repointing fixes all three root causes with no new deploy step and no duplicated copies. Option (c) is live precisely because .opencode/ is dormant. Whatever is chosen must handle the present/slides stale name and must state a verdict on the validator's fail-fast behavior.

CONSTRAINT. Do NOT delete .opencode/ or its fragments - the user intends to return to OpenCode.

ACCEPTANCE. A reload in a consuming repo with 12 active extensions produces no opencode fragment validation errors; the chosen approach is stated with its rationale against the rejected alternatives; the present/slides stale reference is resolved; and the validator's fail-fast-vs-report-all behavior has an explicit recorded decision.

SOURCE-STORE RULE (binding): edit agent-system/extensions/** and lua/**, never .claude/** or .opencode/**, which are disposable deploy artifacts.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 18. Detect stale .claude/ deploy trees and root-cause the silent staleness
- **Effort**: 5h
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: A repo can carry an arbitrarily stale .claude/ deploy with no signal, so a user hits a bug fixed upstream long ago with no indication that regeneration is the remedy. Discovered when /revise failed at GATE IN in a consuming repo on a task that had never produced an artifact.

WHAT IS NOT THE DEFECT (ruled out, do not re-litigate): resolve_task_dir is not broken in source. agent-system/extensions/core/scripts/task-lock.sh's resolve_task_dir (line 249) takes a create_mode parameter and mkdir -p's when it is "create"; cmd_acquire (line 607) passes "create". The failure exists only in the deployed copy.

MEASURED STALENESS EVIDENCE (live, this investigation): the consuming repo's .claude/scripts/task-lock.sh is 676 lines against a 1660-line source, with a deployed resolve_task_dir at line 98 taking no create_mode. Its .claude/scripts/ holds 94 scripts against core's 72 in source. Neither verify-deploy.sh nor deploy-headless.sh is present in the deployed tree at all. This is despite a large sync commit landing recently.

BOOTSTRAP HYPOTHESIS RULED OUT: deploy-headless.sh's header documents a failure mode where a repo deployed by the retired glob-based engine has no "core" entry in .claude-extensions.json, so manager.resync_all silently deploys nothing. That is NOT this case. The repo's .claude-extensions.json lists core with status "active" and 294 recorded installed_files, including .claude/scripts/task-lock.sh. The loader believes it owns and has installed the very file that is stale. Root cause is unknown and is a genuine investigation, not a known-issue application.

WORK, in order. (1) Determine WHY the deploy is stale despite core being active and the file being listed in installed_files. Hypotheses to test, not assume: the copy step skips existing destination files instead of overwriting; installed_files is treated as authoritative and short-circuits re-copy; resync only re-copies files whose manifest entry changed; or a later partial operation reverted the tree. If the cause is a loader defect, report and fix it as such. (2) Then design and implement staleness DETECTION on a path users actually hit. Note that verify-deploy.sh already performs source-vs-deploy comparison but is not itself deployed and is invoked only from skill-orchestrate's inter-cycle redeploy checkpoint, so no ordinary command surfaces its result. Directions to evaluate, do NOT pre-commit: stamp a source revision or content hash into the deployed tree at load time and have command gate scripts compare against the source store, warning on drift; extend /refresh or a doctor check to diff deployed script versions against source; or have the loader record a per-file hash manifest a preflight can validate cheaply. Whatever is chosen must be cheap enough for a normal command preflight.

INTERACTION WITH SIBLING TASK 9: 9's evidence (4 orphan files present in .claude/ but absent from a clean scratch regenerate) was measured against this same stale deploy tree, so it may be an artifact of the staleness rather than a genuine one-directional-parity gap. 9 is sequenced after this task and must re-measure against a freshly regenerated tree. Both tasks also edit verify-deploy.sh.

ACCEPTANCE: the root cause is identified and stated, with the loader defect fixed if that is the cause; a user running an ordinary command against a stale deploy receives an actionable warning naming regeneration as the remedy; demonstrated in both directions, where a stale tree warns and a fresh tree does not.

SOURCE-STORE RULE (binding): edit agent-system/extensions/** and lua/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 17. Fix .return-meta.json lifecycle ordering that makes the gate-out body unreachable
- **Effort**: 4h
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: command-gate-out.sh's entire post-metadata body is structurally unreachable on all five commands that call it, because the skill-internal postflight always deletes the metadata first. The misleading warning is the visible symptom; the dead defensive status correction and the dead artifact validation are the actual damage.

VERIFIED MECHANISM (do not re-derive): skill-base.sh's skill_cleanup (lines 618-625) rm -f's .postflight-pending, .postflight-loop-guard, AND .return-meta.json. It is the single shared implementation invoked from Stage 9 of context/patterns/skill-postflight-flow.md, used by NINE skills: skill-implementer, skill-implementer-hard, skill-planner, skill-planner-hard, skill-reviser, skill-spawn, skill-team-implement, skill-team-plan, skill-team-research. command-gate-out.sh lines 69-73 then read "${task_dir}/.return-meta.json"; on absence it prints "WARNING: .return-meta.json not found ... skill may have failed silently" and exit 0. FIVE commands run it: implement.md, orchestrate.md, plan.md, research.md, revise.md.

BLAST RADIUS IS LARGER THAN THE WARNING (measured, not inherited): the exit 0 at line 73 sits ABOVE everything else in the 134-line script. Code rendered unreachable in practice includes (a) the defensive status correction that repairs state.json when a skill reported completion but state is stale, and (b) the skill_validate_task_artifacts call at line 133, the last line, which is the artifact validation and --fix auto-repair path. One missing file disables both correctness mechanisms on all five commands. A real silent failure and an ordinary success emit the identical warning, so the signal carries no information.

CONSEQUENCE FOR SIBLING TASK 13: 13's acceptance criterion (a task whose artifact required auto-repair produces a gate-out report naming a nonzero repaired-field count) cannot be demonstrated until this ordering defect is fixed, because the path it instruments never executes. 13 is sequenced after this task; both also edit the same two files.

WORK: decide ONE direction and implement it. (a) run the command-level gate-out before skill cleanup; (b) have skill_cleanup preserve .return-meta.json and make gate-out delete it after consuming it; (c) have skill_cleanup archive the metadata to a location gate-out knows about; (d) if the skill-internal postflight genuinely subsumes both defensive correction and artifact validation, delete the dead reads and replace the warning with a truthful statement. Required regardless of direction: explicitly decide whether defensive status correction is still needed given skill-internal postflight and record the reasoning; and fix the warning text so a genuine silent failure is distinguishable from ordinary success.

UNIFORMITY REQUIREMENT: whatever is chosen must hold across all nine skills and all five commands. A fix that repairs skill-reviser and /revise alone is not acceptable.

ACCEPTANCE: a normal successful run of each of the five commands emits no false silent-failure warning; a genuinely failed skill run emits a distinguishable warning; and the defensive-correction path is demonstrated to execute, or is documented as deliberately removed with stated reasoning.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 16. Fix command register acquire session id parity
- **Status**: [IMPLEMENTING]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: None
- **Research**: [016_fix_command_register_acquire_session_id_parity/reports/01_register-acquire-session-id-parity.md]
- **Plan**: [016_fix_command_register_acquire_session_id_parity/plans/01_register-acquire-parity-fix.md]
- **Summary**: [016_fix_command_register_acquire_session_id_parity/summaries/01_register-acquire-parity-fix-summary.md]

**Description**: Fix the register-bare/acquire-suffixed session-id pattern in the research.md, plan.md, and implement.md command files.

TARGET: agent-system/extensions/core/commands/research.md, agent-system/extensions/core/commands/plan.md, agent-system/extensions/core/commands/implement.md.

CONTEXT: skill-orchestrate/SKILL.md carried a defect where the in-flight session registry was registered under the bare session_id but the per-task lock was acquired and released under a task-suffixed variant. Because the session-contention self-exclusion is an exact string match, the batch never recognized its own registration and every acquire aborted deterministically. That defect was fixed in skill-orchestrate, and the fix recorded that these three multi-task command files exhibit the structurally identical register-bare/acquire-suffixed pattern and are likely to carry the same latent bug.

WORK: verify whether each of the three command files actually reproduces the defect (the registration site, the acquire/release sites, and any dispatch context whose session_id feeds a downstream task-lock heartbeat call). Unify the session-id used across register/acquire/release/heartbeat in each file that is affected. Extend the existing register/acquire parity regression coverage to cover these consumers rather than adding a parallel test harness.

REFERENCE: the parity invariant is stated in agent-system/extensions/core/context/patterns/task-lock.md (Consumers section); the existing regression group lives in agent-system/extensions/core/scripts/test-conflict-predicate.sh.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 14. Prevent implementation-agent fan-out from returning non-terminal status and stale plan markers
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

### 13. Instrument gate-out auto-repair reporting; stop silent in-place artifact mutation
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 17

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

### 12. Fix run-all.sh deployed-mode failures: REPO_ROOT depth derivation and 6 further suites
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [012_fix_test_suite_deployed_mode_failures/reports/01_run-all-deployed-mode-triage.md]
- **Plan**: [012_fix_test_suite_deployed_mode_failures/plans/02_gate8-and-verify-deploy-closeout.md]
- **Summary**: [012_fix_test_suite_deployed_mode_failures/summaries/02_gate8-and-verify-deploy-closeout-summary.md]

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
=== SCOPE EXTENSION (folded in after gate-8 diagnosis; user-approved) ===

The Phase 6 residual is now diagnosed with captured evidence, and TWO items are folded into
this task rather than spawned separately.

(A) GATE-8 FLAKE -- ROOT CAUSE CONFIRMED, not a hypothesis. Measured 4/20 (20%) failures inside
verify-deploy.sh gate 8; 13/30 (43%) standalone on an idle machine; 25/30 (83%) in a mirror
copy. All four captured gate-8 failures are byte-identical apart from PID:
  [FAIL] is_live_inhibitor_target: still excludes the SAME inhibitor after its target
  (pid NNNNNNN) was killed -- tautological check
in agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh (assertion (c)).
Mechanism proven directly: kill -0 returns success for a killed-but-unreaped child; wait reaps
in 2ms. Failing runs averaged 141.5s vs 131.0s passing -- a 10.5s delta against the 8.0s poll
budget, i.e. every failure burns the full 40 x 0.2s loop.
  RULED OUT: task-lock.sh / holder.json TOCTOU. Zero occurrences across all 20 runs.
  CORRECTED ASSUMPTIONS: the flake is NOT load-sensitive (43% on an idle machine; CPU burners
  did not reproduce it). Widening the poll budget is DISPROVEN as a fix -- no finite budget
  helps a 43-83% failure, and the helper sometimes genuinely survives the kill, so widening
  only makes each failure slower. Two real-process repairs also failed under test: naive wait
  hung ~300s (the suite leaks a `sleep 300` helper inheriting stdout/stderr, so any reader
  using command substitution blocks for the full 300s -- one run measured 300022ms), and
  kill -9 + wait + detached streams killed the test script itself (RC=137, 20/20).
  REQUIRED FIX (injectable predicate, not budget widening): extract the bare
  kill -0 "$target_pid" in agent-system/extensions/core/scripts/claude-refresh.sh's
  is_live_inhibitor_target (lines ~138-149) into an overridable seam (e.g. _pid_is_alive), and
  replace lines ~112-145 of test-claude-refresh-matcher.sh (helper at 112, kill at 123, poll
  loop at 135-138, failing assertion at 140-144) with a scripted probe. Keep the "alive"
  direction as-is (deterministic; no reaping involved). This preserves the argv-parsing
  coverage the assertion exists to protect. NOTE: it does weaken the file's documented
  "driven by a REAL process" intent (line ~15) -- record that trade-off in the replacement
  comment rather than leaving it silent.

(B) STANDING VERIFY-DEPLOY FAILURES -- verify-deploy.sh exited non-zero on 20/20 runs
INDEPENDENT of gate 8, so fixing gate 8 alone will NOT turn it green. Phase 6's acceptance
criterion cannot be met without these:
  - Deploy drift (gates 3 and 5): agent-system/extensions/core/scripts/system-defect-record.sh
    (source 354 lines / deployed 352) and
    agent-system/extensions/core/context/patterns/system-defect-discrimination.md
    (source 397 / deployed 382). Source is AHEAD of deploy; a deploy-headless.sh run resolves
    both.
  - line_count mismatch (gate 3, Rule R): agent-system/extensions/core/index-entries.json
    (~line 1034) declares line_count 382 for patterns/system-defect-discrimination.md; the
    actual file is 397 lines. generate-context-line-counts.sh --write is the sanctioned fixer.
  - Dangling dependency (gate 10): specs/state.json task 9 carries dependencies [1015, 18].
    1015 exists in NEITHER active_projects NOR the archive, and neither does 15 -- it is a
    vault-renumbering leftover (renumbering subtracted 1000 from project_number values but did
    not rewrite dependencies arrays). Removing the dead 1015 entry is the honest fix; do not
    invent a replacement target.

ACCEPTANCE (revised): verify-deploy.sh reports 0 findings across a repeated sample (not a
single lucky run -- the flake was 20% inside gate 8, so a single green run is not evidence),
OR every residual failure carries a written, evidenced justification. Report counts honestly;
never an unqualified green.

---

### 11. Expand defect class vocabulary
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [011_expand_defect_class_vocabulary/reports/01_defect-class-vocabulary-gap.md]
- **Plan**: [011_expand_defect_class_vocabulary/plans/01_defect-class-vocabulary-expansion.md]
- **Summary**: [011_expand_defect_class_vocabulary/summaries/01_defect-class-vocabulary-expansion-summary.md]

**Description**: The system-defect vocabulary has a gap: defect classes exist for a narrow set of shapes, but at least three concrete instances from this batch do not fit cleanly into any existing defect_class value. Recorded as err_1786349061588_fqHbUZ, severity medium. Three concrete instances now ground the gap, confirmed by the capstone acceptance gate dispatch: lock/session contention (err_1786349061524_pY97cE, MT-1/MT-4 session-id mismatch), hook-regex/path-depth boundary defects (err_1786349061492_XpY38x, the 3-digit handoff-location regex), and deploy orphan-file drift (err_1786349061556_LuKGif / err_1786350581273_TAWj0I).

TARGET: wherever defect_class is enumerated for system-defect-record.sh (search the source store for its schema/enum definition) and any consumer that switches on defect_class value.

WORK: read the current defect_class enum, confirm the three instances above genuinely lack a fitting class (do not add classes for shapes that already have one), and add the minimum set of new classes needed to name them precisely -- for example a session/lock-contention class, a regex/path-boundary class, and an orphan-drift class. Update any documentation enumerating the vocabulary. Do not rename or remove existing classes as part of this task.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

CONSTRAINT: do not drive this task with multi-task /orchestrate until err_1786349061524_pY97cE (the MT-1/MT-4 session-id mismatch, spawned as a sibling task) is fixed -- multi-task orchestration is documented-broken until that lands. Use single-task /orchestrate or /implement.

---

### 9. Resolve deploy orphan file parity
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 18

**Description**: Declared-vs-deployed parity for provides.* categories is one-directional by design, and the live .claude/ tree carries 4 orphan files absent from a clean scratch regenerate: context/orchestration/orchestration-validation.md, context/orchestration/subagent-validation.md, docs/architecture/architecture-spec.md, docs/README.md. Two of these (docs/architecture/architecture-spec.md, docs/README.md) were not covered by the pre-existing err_1786349061556_LuKGif (deploy_ghost_index_entries), which only named the other two -- confirmed and extended by err_1786350581273_TAWj0I (deploy_orphan_files_undercounted). This task covers BOTH error ids with one decision; do not split it.

MECHANICAL REASON (already diagnosed, do not re-derive): verify.lua's result shape has no extra/orphan field and only ever iterates the declared side; install-extension.sh's merge_index_entries() is purely additive with no stale-removal step. Parity is therefore verified only in the declared-to-deployed direction, never the reverse.

TARGET: agent-system/extensions/core/scripts/verify-deploy.sh (or the shared verify.lua module it calls), and/or docs/architecture/architecture-spec.md if the decision is to document one-directional parity as intended rather than build detection.

WORK: decide ONE of two directions and implement it -- (a) add a subtractive/orphan-detection pass to verify.lua or verify-deploy.sh that flags live files present in .claude/ but absent from a clean regenerate of every provides.* category, so future orphan drift is caught mechanically; or (b) explicitly document in docs/architecture/architecture-spec.md that provides.* parity is one-directional by design (additive only, no stale-removal), so a future reader does not mistake the current behavior for an oversight. Resolve the 4 currently-orphaned files as part of whichever direction is chosen: either they get removed/reconciled (direction a) or explicitly enumerated as accepted legacy orphans in the documentation (direction b).

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

CONSTRAINT: do not drive this task with multi-task /orchestrate until err_1786349061524_pY97cE (the MT-1/MT-4 session-id mismatch, spawned as a sibling task) is fixed -- multi-task orchestration is documented-broken until that lands. Use single-task /orchestrate or /implement.

STALENESS CAVEAT (added after the deploy-staleness finding): the orphan-file measurement above (4 files present in .claude/ but absent from a clean scratch regenerate) was taken against a deploy tree since shown to be badly stale -- its task-lock.sh was 676 lines against a 1660-line source. That measurement may therefore be an artifact of the staleness rather than evidence of a one-directional parity gap. Re-take the measurement against a freshly regenerated tree before treating it as evidence, and revise the direction (a)/(b) decision if the orphan set changes. Depends on task 18, which diagnoses the staleness root cause.

---

### 6. Nothing prevents an agent from rewriting state.json .artifacts wholesale, silently discarding prior artifacts
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 5
- **Research**: [006_guard_against_nonadditive_artifact_rewrites/reports/01_guard-nonadditive-artifact-rewrites.md]
- **Plan**: [006_guard_against_nonadditive_artifact_rewrites/plans/01_guard-nonadditive-artifact-rewrites.md]
- **Summary**: [006_guard_against_nonadditive_artifact_rewrites/summaries/01_guard-nonadditive-artifact-rewrites-summary.md]

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

### 5. roadmap_items is never derived by any implement path, so /todo's ROADMAP sync is dead in practice
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [005_implement_roadmap_items_producer/reports/01_roadmap-items-producer.md]
- **Plan**: [005_implement_roadmap_items_producer/plans/01_roadmap-items-producer.md]
- **Summary**: [005_implement_roadmap_items_producer/summaries/01_roadmap-items-producer-summary.md]

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
