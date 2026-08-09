---
next_project_number: 1003
---

# TODO

## Task Order

*Updated 2026-08-09. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 984,992,997,998 | -- | agent-system, orchestration-concurrency, status-marker-lifecycle |
| 2 | 985,993,995,1000,1002 | 984,992,998 | agent-system |
| 3 | 986,1001 | 985,1000 | agent-system |
| 4 | 999 | 986,1002 | agent-system |
| 5 | 996 | 993,995,999 | agent-system |

**Grouped by Topic** (indented = depends on parent):

### Agent System

992 [RESEARCHED] — Bring every EXTENSION.md into conformance with extension-slim-sta
  └─ 985 [NOT STARTED] — Quarantine (never silently delete) the dead machinery the review 
    └─ 986 [NOT STARTED] — Make the documentation layer stop describing machinery that does 
      └─ 999 [NOT STARTED] — Reduce the 8 standing per-agent context budget overruns that vali
        └─ 996 [NOT STARTED] — Capstone acceptance gate for the agent-system refactor: verify th
  └─ 993 [NOT STARTED] — Promote SCHEMA_CONFORMANCE_GATE_MODE (introduced by the prerequis
    └─ 996 [NOT STARTED] — Capstone acceptance gate for the agent-system refactor: verify th (see above)
  └─ 1000 [NOT STARTED] — Give the cslib extension its own copy of the adversarial-verifica
    └─ 1001 [NOT STARTED] — Fix the dormant load-order defect in lean/index-entries.json's mi
998 [RESEARCHED] — Triage the 49 entries the Double-Loading Check now names, and dec
  └─ 1002 [NOT STARTED] — Author a context file that states the tier-classification semanti
    └─ 999 [NOT STARTED] — Reduce the 8 standing per-agent context budget overruns that vali (see above)
995 [NOT STARTED] — Convert the hand-rolled specs/state.json read-modify-write sequen
  └─ 996 [NOT STARTED] — Capstone acceptance gate for the agent-system refactor: verify th (see above)

### Orchestration Concurrency

997 [NOT STARTED] — session_liveness() in scripts/task-lock.sh reports liveness_reaso

### Status Marker Lifecycle

984 [NOT STARTED] — Give specs/state.json a machine-enforced schema and make the stat

## Tasks

### 1002. Author the context tier-semantics standard for the derived tier classification
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 991, Task 998

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
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 991, Task 992, Task 1000

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
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 991, Task 992

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
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 991, Task 992, Task 986, Task 998, Task 1002

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
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 991
- **Research**: [998_double_loading_warning_triage/reports/01_double_loading_warning_triage.md]

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
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: None

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
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 985, Task 986, Task 993, Task 995, Task 999

**Description**: Capstone acceptance gate for the agent-system refactor: verify the COMPOSED system end-to-end after all structural waves land. Every prior refactor task carries its own verification bar; nothing yet verifies the composition — a fresh deploy, all gates at their hardened defaults, and a live orchestrate cycle exercising routing, handoff, gate-out, and defect-recording together. This task fixes nothing structural itself: any failure is recorded (errors.json entry and/or spawned follow-up task) and the gate re-runs after the fix lands.

VERIFICATION SCOPE:
  1. DEPLOY: wipe+regenerate to a scratch tree succeeds; running it twice is byte-identical; declared-vs-deployed parity plus content-hash equality holds for EVERY provides.* category; no quarantined/deprecated file is present in the deployed tree; protected (.syncprotect) files and settings.local.json survive the round-trip.
  2. GATES: check-extension-docs.sh exits 0 with every gate mode at its hardened baked-in default (no env overrides at invocation); validate-state.sh (including --deep invariants) passes on live state; the script test runner (run-all.sh) is green; the repo-wide task-reference lint (check-task-references.sh) passes.
  3. LIVE CYCLE: one scratch-task /orchestrate cycle runs end-to-end — routing resolution yields an agent file that EXISTS on disk for every task_type declared in any loaded manifest; the cycle produces a schema-valid handoff (or, if the return-meta single-channel design was chosen, no handoff and no recovery-bridge warnings); gate-out reports zero format errors and zero auto-repaired fields; the system-defect recorder emits NO system_defect event on the clean run (the negative test) and the deferred-defect surface renders empty.
  4. Record the results as a dated review artifact under specs/reviews/ so the refactor has a closing bookend to the review that opened it.

SOURCE-STORE RULE (binding): any fixes spun out of this task target agent-system/extensions/** (or lua/neotex/plugins/ai/** for deploy machinery), never .claude/**. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 995. Convert surviving extension state.json writers to state-write.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 983, Task 984

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
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 987, Task 990, Task 992

**Description**: Promote SCHEMA_CONFORMANCE_GATE_MODE (introduced by the prerequisite task in agent-system/extensions/core/scripts/check-extension-docs.sh, governing Rules T and U) from its advisory default to hard, mirroring the promotion sequence ORPHAN_GATE_MODE -> INDEX_TRUTH_GATE_MODE already went through once their own remediation landed. DEPENDS ON the index_entries_schema_migration and extension_md_slim_down follow-on tasks both landing clean first -- flipping the default before either lands would turn a passing doc-lint gate into a standing hard failure for every extension either task was meant to fix. WORK: change the default in the SCHEMA_CONFORMANCE_GATE_MODE="${SCHEMA_CONFORMANCE_GATE_MODE:-advisory}" line to hard, and update its preceding comment block to record that source-store remediation is now complete (mirroring INDEX_TRUTH_GATE_MODE's own comment). VERIFICATION BAR: REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh exits 0 with the gate hard (no SCHEMA_CONFORMANCE_GATE_MODE override needed at invocation time, since hard is now the baked-in default). SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 992. Trim the 6 over-length live EXTENSION.md files; resolve the 2 dead ones
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 987, Task 990, Task 991
- **Research**: [992_extension_md_slim_down/reports/01_extension_md_slim_down.md]

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
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 951, Task 960, Task 961, Task 962, Task 963, Task 969, Task 980, Task 982, Task 983, Task 984, Task 985, Task 987, Task 989, Task 992

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
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 952, Task 960, Task 963, Task 964, Task 969, Task 973, Task 980, Task 981, Task 982, Task 984, Task 987, Task 988, Task 992

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
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: status-marker-lifecycle
- **Dependencies**: Task 962, Task 969, Task 988

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
