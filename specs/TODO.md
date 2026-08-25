---
next_project_number: 101
---

# TODO

## Task Order

*Updated 2026-08-25. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 13,14,20,22,27,29,31,39,42,43,44,45,46,48,51,53,68,72,73,74,78,81,85,86,87,90,91,93,94,96,97,99,100 | -- | agent-system, extensions, literature, ... |
| 2 | 30,50,64,66,75,76,88,89,98 | 29,42,48,74,87,97 | agent-system, extensions, essential-refactor |

**Grouped by Topic** (indented = depends on parent):

### Agent System

13 [NOT STARTED] — The acceptance criterion "gate-out reports zero format errors and
14 [NOT STARTED] — === REVISED 2026-08-24 (refactor survey) ===
20 [NOT STARTED] — /todo's repository-metrics sync runs before its git commit, so th
27 [NOT STARTED] — .opencode/scripts/execute-command.sh is a command router that can
29 [NOT STARTED] — Build the deploy-engine mechanism that lets an extension declare 
  └─ 30 [NOT STARTED] — Register the obsidian-memory MCP server through the new manifest-
31 [RESEARCHING] — === REVISED 2026-08-24 (refactor survey) ===
51 [NOT STARTED] — Move per-session state files cluttering the specs/ root (.orchest

### Extensions

22 [RESEARCHING] — === REVISED 2026-08-24 (refactor survey) ===
45 [NOT STARTED] — Implement <leader>al repo registration and 'Global Update' action
46 [NOT STARTED] — Fix present extension compound-skill routing so /implement resolv
74 [NOT STARTED] — Build a shared, task-type-agnostic guard script that detects a us
  └─ 75 [NOT STARTED] — Wire the shared LaTeX build guard into the latex extension's life
  └─ 76 [NOT STARTED] — Close the coverage gap that the latex-extension wiring cannot rea
97 [NOT STARTED] — Ship a shared, portable build-concurrency and memory guard for Le
  └─ 66 [NOT STARTED] — Mandate detached (run_in_background) invocation for Lean full bui
  └─ 98 [NOT STARTED] — Integrate the shared Lean build guard into the lean extension: ro

### Literature

39 [PLANNED] — Upgrade the literature extension's Zotero integration beyond bare
78 [RESEARCHED] — literature-briefing.sh's coverage marker counts documents that RE
94 [NOT STARTED] — Wire the --lit flag through the three team skills so literature m
96 [NOT STARTED] — Surface the sub-index vs global-index coverage delta when --lit i

### Orchestration Concurrency

53 [NOT STARTED] — Stop recording a spurious HANDOFF_STALE_OR_ABSENT system defect w
68 [NOT STARTED] — Make the multi-task /orchestrate classifier's `blocked` row DISCR
81 [NOT STARTED] — Task-lock and session-registry heartbeats never fire during a rea

### Status Marker Lifecycle

91 [NOT STARTED] — update-plan-status.sh reports every non-conforming plan Status li

### Essential Refactor

42 [NOT STARTED] — === REVISED 2026-08-24 (refactor survey) ===
  └─ 64 [NOT STARTED] — Decide and implement how --hard behavioral contracts reach agents
43 [NOT STARTED] — LIVE DEFECT, not an efficiency item: the email extension's five '
44 [PLANNED] — LOWER PRIORITY (per-invocation cost, not per-session). `commands/
48 [NOT STARTED] — Propagate the scoped-commit fix to the 65 call sites it never rea
  └─ 50 [NOT STARTED] — === REVISED 2026-08-24 (refactor survey) ===
85 [NOT STARTED] — THE SHELL TEST SUITE IS NON-DETERMINISTIC, and until it is fixed 
86 [NOT STARTED] — .github/workflows/check-extension-docs.yml is the repository's ON
87 [NOT STARTED] — Establish the convention that fixes the single largest token leve
  └─ 88 [NOT STARTED] — Apply the mode-gated section convention to the largest single ins
  └─ 89 [NOT STARTED] — Apply the mode-gated section convention to the two remaining larg
90 [NOT STARTED] — The largest duplication class in the repo, and it has never been 
93 [RESEARCHED] — The postflight deploy gate makes 'completed' mean 'in effect' IN 

### Team Mode Lifecycle

72 [NOT STARTED] — Teammate agents spawned by team-mode skills write the skill-level
73 [NOT STARTED] — The SubagentStop postflight hook picks an arbitrary .postflight-p

### Uncategorized

99 [NOT STARTED] — Make the .orchestrator-handoff.json artifacts[] element shape una
100 [NOT STARTED] — Close the file_scope blind spot for AGGREGATOR/REGISTRATION files

## Tasks

### 100. Close aggregator file scope blind spot
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: None

**Description**: Close the file_scope blind spot for AGGREGATOR/REGISTRATION files: a task that adds a new module must edit its parent aggregator, which by construction lies outside the new module's own declared path, so the admission gates never see that edit coming.

MIRROR OF THE COARSE-DECLARATION WORK, NOT A DUPLICATE OF IT. The completed task surface_coarse_file_scope_declarations_at_creation addresses declarations that are too BROAD -- a bare directory root swallowing every task in the repo. This is the opposite failure: a declaration that is too NARROW, omitting a file the work provably cannot avoid touching. Both degrade the same admission machinery from opposite directions, and neither fix implies the other. Read that task's resolution before designing this one so the two creation-time checks compose instead of contradicting.

OBSERVED MECHANISM (verified live, do not re-derive). In a seven-task lean4 batch in a separate consumer repo, TWO tasks each edited a module aggregator that appeared nowhere in their declared file_scope:
  - one declared [WeakCanonical/Transfer.lean, BXCanonical/DiscreteCarrierProbe.lean] and additionally edited Metalogic/BXCanonical.lean
  - one declared [Semantics/ShiftSet.lean] and additionally edited Semantics.lean
In both cases the edit was minimal and structurally REQUIRED -- a single `import` line plus a docstring index entry -- without which the newly created module is unreachable from the build. Neither agent did anything wrong: both honestly listed the aggregator in .return-meta.json's modified_files after the fact. The gap is entirely in the PRE-DISPATCH declaration that the admission gate actually consults.

THE CONCRETE HAZARD (why this is not merely cosmetic). orchestrate-batch-admit.sh compares DECLARED file_scope across non-terminal tasks to decide co-dispatch safety. An undeclared aggregator edit is invisible to that comparison. In the observed batch the two tasks happened to touch DIFFERENT aggregators, so nothing collided and the run was clean -- this was luck, not a guarantee. Two tasks that each add a module beneath the SAME parent (entirely ordinary: two new modules under Semantics/) would both be admitted to the same wave, both edit that one aggregator concurrently, and the gate designed to prevent exactly that would stay silent. The failure would surface as a lost import line or a clobbered docstring index, i.e. a task whose module silently stops being built.

NOTE THE ASYMMETRY THAT MAKES THIS DETECTABLE TODAY. modified_files (post-hoc, agent-authored, accurate here) already names the aggregator, while file_scope (pre-dispatch, human/creation-authored) does not. The system therefore already holds both halves of the evidence and never compares them.

CANDIDATE DIRECTIONS (evaluate, do not blindly adopt):
  (a) DETECTION FIRST, cheapest and lowest-risk: at postflight, compare each task's reported modified_files against its declared file_scope and emit an advisory naming any excursion. This is exactly the manual check that caught the observed case. It prevents nothing, but it converts a silent gap into a logged one and would immediately quantify how common aggregator excursions are before anyone designs a preventive rule.
  (b) CREATION TIME: when a declared path names a not-yet-existing module, infer and auto-add its parent aggregator to file_scope. Requires a language-aware notion of "parent aggregator" (Lean's Foo.lean beside Foo/), so scope it per extension rather than pretending it is universal.
  (c) ADMISSION TIME: expand declared scopes to include parent aggregators before running the overlap predicate. Strictly more conservative, and risks re-introducing the over-blocking that the evidence-gated collision narrowing deliberately removed -- weigh against that work rather than reverting it by accident.
Direction (a) is a sound first deliverable on its own and does not commit the design to (b) or (c).

DO NOT "FIX" THIS BY WIDENING DECLARATIONS BY HABIT. Declaring the enclosing directory to be safe would reintroduce precisely the coarse-declaration defect the mirror task exists to prevent. The aggregator is a single named FILE; name it, do not reach for its directory.

ACCEPTANCE: an aggregator edit made outside a task's declared file_scope is no longer silent -- at minimum it is reported against that task; and two tasks adding modules beneath a shared parent aggregator are either serialized or surfaced, demonstrated with a concrete two-task case rather than argued in the abstract.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 99. Pin handoff artifacts element shape
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: None

**Description**: Make the .orchestrator-handoff.json artifacts[] element shape unambiguous in the agent contracts, and stop research dispatches from emitting bare strings where the consumers require objects.

OBSERVED MECHANISM (verified live, do not re-derive). In a seven-task lean4 batch in a separate consumer repo, THREE of seven research dispatches running extensions/lean/agents/lean-research-agent.md wrote .orchestrator-handoff.json with artifacts as an array of BARE PATH STRINGS rather than objects. Recorded as ARTIFACTS_SHAPE_MISMATCH, evt_1787609609484_JsLV9N, evt_1787609609589_NoKGP8 and evt_1787609609694_0qUk6t. The remaining four wrote the object form. Same agent, same batch, same phase -- so this is contract ambiguity, not a per-task accident.

THE CONSUMER-SIDE SYMPTOM. Orchestrator artifact linking reads artifacts[0].path / .type / .summary. Against a bare string that indexing raises "Cannot index string with string \"path\"", so the read yields nothing and the artifact silently fails to link -- the report exists on disk and is committed, but never lands in state.json's artifacts[]. The orchestrator recovered by resolving BOTH shapes tolerantly at the call site, which is a workaround at the wrong layer: every future consumer of a handoff would have to repeat it.

WHY THE EXISTING DEFECT CLASS DOES NOT ALREADY COVER THIS. ARTIFACTS_SHAPE_MISMATCH is already defined and already has consumer-side detection arms wired into both orchestrate engines (skill-orchestrate Stage 5's handoff-present probe and its Stage MT-4 recovered-path sibling). Those arms DETECT and record the mismatch; nothing prevents a writer from producing it. This task is the writer-side half, and it is currently unowned -- no active task names ARTIFACTS_SHAPE_MISMATCH or the artifacts element shape.

DECIDE EXPLICITLY, THEN STATE IT ONCE. context/formats/return-metadata-file.md is normative for .return-meta.json and declares itself normative for the handoff's status field too, but the artifacts ELEMENT shape is not pinned with the same force, and docs/architecture/handoff-schema.md is the natural home for it. Settle: (1) is the element an object {path, type, summary} with path required, or is a bare string an accepted shorthand that consumers must normalize; (2) whichever is chosen, state it in ONE normative place and have the agent contracts reference it rather than each restating it. Do not answer (1) with "accept both" merely because the orchestrator currently tolerates both -- that tolerance was added under incident conditions and should be reconsidered on its merits, not ratified by default.

EVIDENCE THE CONTRACT WORDING IS THE LEVER. When the dispatch prompt stated the object requirement explicitly, all seven plan dispatches and all seven implement dispatches in the same batch emitted the object form, with zero recurrences. Per-dispatch prompt text is the workaround this task exists to retire.

SCOPE NOTE. The reproducing agent is the LEAN research agent, but the ambiguity is in the shared schema, so the fix belongs in the schema doc plus whichever agent contracts restate the shape. Check the core research agent and the hard variants for the same wording gap rather than patching only the file that happened to reproduce it. If a shared normative statement referenced by all writers is the better mechanism, prefer it over copying a paragraph into several files.

ACCEPTANCE: the handoff artifacts element shape is stated normatively in exactly one place; every research/plan/implement agent contract that mentions artifacts conforms to it or references it; a dispatch that emits the non-conforming shape is either impossible by contract or is caught with a clear message naming the offending element; and the orchestrator's dual-shape tolerance is either removed as no longer needed or deliberately retained with a recorded reason.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 98. Route lean extension builds through the guard and rewrite the multi-instance operations anchor
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 97

**Description**: Integrate the shared Lean build guard into the lean extension: route the extension's own build-invoking script through it, decide and implement the lifecycle-hook wiring, and rewrite the multi-instance operations anchor from human-advisory prose into mechanism documentation with corrected figures.

DEPENDS ON the core guard script task. This task consumes the script and its chosen subcommand shape and must not re-litigate the mechanism decisions made there.

SCOPE BOUNDARY (important -- read before planning). The agent and skill CONTRACT text that instructs an agent to run `lake build` is NOT in this task's scope. Those sites (both implementation agent twins, both implementation skills, both research agents, skill-lake-repair, and rules/lean4.md) are edited by the background-builds task, whose description was revised to absorb the guard obligation so that detached invocation and guard usage are mandated together in a SINGLE coherent pass over those files. Splitting that pass across two tasks would edit the same eight files twice and invite exactly the twin-file drift this extension treats as a known recurring defect class. This task covers the script, the manifest, and the documentation anchor -- and nothing that the background-builds task already owns.

DELIVERABLE 1 -- ROUTE THE CENSUS SCRIPT THROUGH THE GUARD.
`agent-system/extensions/lean/scripts/lean-sorry-census.sh` runs its own unguarded full build under `--cross-check`. The site is line ~181 (verified at task-creation time; locate by content, line numbers drift):
    BUILD_OUTPUT="$(lake build 2>&1)"
    BUILD_STATUS=$?
This is a second, independent source of unguarded full builds, and it is invoked by the hard implementation agent's verification step -- so a single hard dispatch can trigger two full builds.
NOTE THE COMMAND-SUBSTITUTION SHAPE, and note that it is exactly why the guard rather than detached invocation is the right instrument here: `run_in_background` cannot return stdout to a shell variable, but the flock-based guard can. Route this call through the guard while preserving the existing capture of both output and exit status. Preserve the existing graceful degradation when `lake` is absent from PATH (`cross_check: unavailable`), and add the equivalent for the guard being absent -- the census script must not hard-fail in a repo where the guard has not been deployed.
Update `agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` to cover the new path.

DELIVERABLE 2 -- LIFECYCLE-HOOK DECISION AND WIRING.
`agent-system/extensions/lean/manifest.json` currently declares NO top-level `hooks` object (verified: `.hooks` is null) and its `provides.scripts` holds only the census script and its test. Decide whether the lean extension should declare a preflight hook that consults the guard, and record the reasoning either way.
Inputs to that decision, all verified:
  - `skill_run_extension_hook()` in `agent-system/extensions/core/scripts/skill-base.sh` dispatches preflight, context_injection, verification, and postflight to a script named in the extension's TOP-LEVEL `hooks` object. This is DISTINCT from `provides.hooks`, which is a file-copy target list; do not confuse the two. The new object is a SIBLING of `provides`, not a replacement for any field inside it.
  - Hooks are NON-BLOCKING BY DESIGN: a non-zero exit is caught, downgraded to a `[skill-base] WARNING`, and execution continues. A preflight hook therefore CANNOT enforce a refusal on its own. If the intended behaviour is "refuse to build under memory pressure", that refusal must be carried in contract text (owned by the background-builds task) with the hook serving only as detector and reporter. Resolve this explicitly rather than assuming a non-zero exit stops anything.
  - `agent-system/extensions/nix/scripts/nix-preflight.sh` is the reference implementation and shows the exact contract: five positional args (task_number, task_type, task_dir, session_id, operation), `set -euo pipefail`, warnings to stderr, `exit 0` even when warnings fired. Only two extensions (nix, nvim) declare top-level hooks today, so this is a lightly-trodden path -- read both before writing.
  - Hooks fire for ALL operations of the matching task type, research included, since `operation` is passed as an argument rather than filtered on. Decide whether the hook self-filters on `operation`.
  - COVERAGE CAVEAT that may argue against relying on a hook at all: `skill_get_extension_dir` keys hook resolution on task_type, so a lean-extension hook fires if and only if `task_type == "lean4"`. A `general`- or `meta`-typed task working in a Lean repository would get nothing. This is the same structural gap a companion task documents for LaTeX. A defensible outcome is to declare no lean hook and rely on the contract mandate plus the guard's own internal safety, PROVIDED that choice is recorded with its reasoning rather than reached by omission.
If a hook is added, register it in the top-level `hooks` object AND add the script to `provides.scripts`.

DELIVERABLE 3 -- REWRITE THE OPERATIONS ANCHOR.
`agent-system/extensions/lean/context/project/lean4/operations/multi-instance-optimization.md` is today ~120 lines of human-advisory prose. It instructs a PERSON to "pause work in 3-4 other sessions", to "run `lake build` before starting Claude sessions", and to watch `htop`. It contains no mechanism an agent can execute, and its stated expectation -- "Memory usage stays under 8GB (vs 16GB+ spikes)" -- is contradicted by a measured 29.9 GB across 16 concurrent `lean` processes. Its diagnosis section is sound and should be preserved; its remedies are the stale part.
Rewrite it as mechanism documentation: what the guard does, how a caller invokes it, what the waiter/result-sharing semantics are, what the memory bounding does and when it degrades, and what the operator can still do by hand. Correct the figures, or state the measured range as illustrative rather than predictive. Keep the extension's single-anchor convention: prose lives here once and is referenced by path from the call sites, never restated at them.
COORDINATE WITH THE SIBLING ANCHOR: the background-builds task creates `operations/long-builds.md` covering the foreground-cap livelock and passive progress checks. These two anchors are siblings in the same directory and must be coherent, cross-referenced, and non-duplicating. In particular they must jointly and explicitly resolve the interaction described next.

THE INTERACTION THAT MUST BE RESOLVED IN WRITING (the reason these tasks are coupled). The background-builds task mandates `run_in_background` so builds escape the 10-minute foreground Bash cap -- a correct fix for a real livelock, since a cap-killed build caches no .olean and retries restart at the identical module. But that cap is currently the ONLY thing bounding how long a redundant concurrent build survives. Removing it means that instead of ten duplicate builds each dying at ten minutes, ten duplicate builds run to completion, each holding multi-gigabyte `lean` processes for the full duration. Detached invocation and serialization must therefore land together: detaching WITHOUT the guard makes the measured memory situation strictly worse. Say this plainly in the anchors so a future reader does not adopt one half of the pair.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/lean/**`. Never edit a deployed `.claude/**` tree -- those are disposable artifacts regenerated on reload, so such an edit silently vanishes.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/. Cite the anchor filename and the mechanism, never a task number.

ACCEPTANCE: `lean-sorry-census.sh --cross-check` routes its build through the guard while still capturing both output and exit status, degrades gracefully when either `lake` or the guard is absent, and its test covers the new path; the hook decision is recorded WITH REASONS, and if a hook was added it is declared in the manifest's top-level `hooks` object, listed in `provides.scripts`, follows the five-argument nix-preflight contract, and its operation-filtering behaviour is recorded; `multi-instance-optimization.md` no longer instructs a human to pause sessions as its primary remedy, documents the guard's actual mechanism, and carries no figure contradicted by measurement; the two operations anchors cross-reference each other without duplicating prose; the detached-invocation-amplifies-concurrency interaction is stated explicitly in writing; no contract file owned by the background-builds task is modified here; no `.claude/**` file is modified.

---

### 97. Add shared Lean build concurrency and memory guard script (flock serialization, result sharing, cgroup bounding)
- **Effort**: 4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Ship a shared, portable build-concurrency and memory guard for Lean projects as a core script, so that many concurrent agent sessions working in the same Lean repository serialize their `lake build` invocations, share a single build's result instead of duplicating it, and cannot exhaust machine memory. This task delivers the MECHANISM only; wiring it into the lean extension's contracts and scripts is handled by the dependent task and by the revised background-builds task.

PROBLEM (observed live on this machine, not hypothetical). Multiple Claude Code sessions running long Lean tasks in one repository each independently launch a full `lake build`. Nothing serializes them, so they do not divide the work -- they duplicate it. Each redundant build re-elaborates the SAME modules concurrently, multiplying peak memory by the number of sessions while making every copy slower than a single build would have been.

MEASURED EVIDENCE (illustrative, from one large Lean repo -- MUST NOT be hardcoded as an assumption in the script or its docs):
- 16 concurrent `lean` processes held 29.9 GB RSS on a 30 GB machine; 29 GB of swap in use; 3.1 GB RAM available. The machine was thrash-bound, not crash-bound: earlyoom was running and there were ZERO OOM kills in the preceding 6 hours. The failure presents as "everything is slow", which is why it went undiagnosed.
- Roughly ten simultaneous `lake build` runs, launched by separate sessions, were rebuilding identical modules: 6 concurrent copies of one module, 3 of another, 3 each of two more.
- Single-module peaks: 6.36 GB RSS in ONE `lean` process for the heaviest module; 3.2 GB and 2.6 GB for the next two. A single process cannot be split across cores, so this is a hard floor that no scheduling change lowers.
- The problem reproduces continuously: after killing the duplicates, a new session started another full build within five minutes and immediately re-duplicated the heaviest module (6.36 GB + 4.76 GB simultaneously).
The NORMATIVE statement in the script and its docs must be the generic one: "concurrent unguarded builds in one project duplicate work and multiply peak memory." The figures above belong in the docs only as an illustrative note. The source store deploys to roughly ten repositories and must not assume this one repo's profile.

VERIFIED ENVIRONMENT FACTS (re-verify during research; do not trust these blindly):
- Lake 5.0.0 (Lean 4.33.0-rc1) has NO `-j`/`--jobs` flag. Both `lake -j 2` and `lake build -j 2` return `error: unknown short option '-j'`. Any design that assumes a job-count flag is wrong.
- `flock` and `systemd-run` are both present at /run/current-system/sw/bin/. Neither may be ASSUMED present on every deployment target -- the script must degrade gracefully and audibly when either is missing.
- One `lake build` was observed spawning 6 concurrent `lean` child processes with LEAN_NUM_THREADS=8 in the environment.

MECHANISM 1 -- FLOCK SERIALIZATION WITH RESULT SHARING (the core fix; without this the others only soften the symptom). Serialize builds on a lock derived from the project's resolved `.lake` directory, so a second session queues rather than duplicating. Deriving the lock path from the project root (via `lake` itself, or by walking up to the lakefile) is REQUIRED for portability -- the script is deployed to many Lean repos and must never hardcode a project path.
  Result sharing is the part that distinguishes this from plain serialization and deserves explicit design attention: a session that finds a build already in flight should consume THAT build's log and exit status rather than waiting for the lock and then launching a second, now-redundant build. Naive `flock` alone produces a convoy -- ten sessions each waiting their turn and then each running a full build in sequence, which is slower in wall-clock than the duplication it replaces even though it is safe on memory. Design the waiter path deliberately; do not treat `flock <lock> lake build` as a finished answer.
  Decide and record the staleness policy: how a waiter distinguishes an in-flight build from an abandoned lock left by a killed session, and what happens when the in-flight build's result predates the waiter's own edits (a shared result is only valid if the tree has not changed under it).

MECHANISM 2 -- CGROUP MEMORY BOUNDING (optional, opt-in). Wrap the build in `systemd-run --scope -p MemoryHigh=... -p MemoryMax=...` so a runaway build is throttled and then killed rather than driving the whole machine into swap. Prefer cgroups over `ulimit -v`, which interacts badly with Lean's allocator. Limits must be derived from available memory or configurable, never hardcoded. Must degrade to an unbounded build with a visible notice where systemd-run is unavailable or the user session has no cgroup delegation.

MECHANISM 3 -- AVAILABLE-RAM PREFLIGHT. Before launching a full build, check available memory and defer or warn when the machine is already under pressure. Note the subtlety that makes a naive check wrong: on this machine `free` reported 3.1 GB available while 29 GB of swap was in use, so "available" alone does not capture pressure. Consider swap-in-use and/or PSI (/proc/pressure/memory) as better signals, and record what was chosen and why.

MECHANISM 4 -- LEAN_NUM_THREADS. Because Lake 5.0.0 exposes no `-j`, this is the only apparent parallelism lever. IT IS UNVERIFIED. The belief that LEAN_NUM_THREADS governs Lake's build job count (and not merely the thread count WITHIN each `lean` process) is an INFERENCE drawn from observing 6 concurrent `lean` children under one build with LEAN_NUM_THREADS=8 -- consistent with, but not proof of, that reading. RESEARCH MUST RUN A CONTROLLED EXPERIMENT (vary the value, count concurrent `lean` children) AND RECORD THE RESULT before the script or any documentation states this as fact. If the inference is false, say so plainly and drop the lever rather than shipping folklore.

REUSABLE PATTERN -- `agent-system/extensions/core/scripts/claude-refresh.sh`. Read it before writing anything new; it already solves the hard parts of safe process handling. It takes a single atomic `ps -eo` snapshot per invocation rather than re-querying live; it applies exclusion regexes so the script can never target itself or its own ancestry; it gates destructive action behind an explicit `--force`; and it escalates SIGTERM -> `kill -0` liveness recheck -> SIGKILL rather than killing outright.

SELF-MATCH HAZARD. Any detection of running builds must match on the actual executable and resolved target, and must exclude self and own ancestry. This is not theoretical: a companion task recorded that a plain `pgrep -af latexmk` matched only the task-creating agent's OWN bash wrapper, whose argv merely contained the string. The same trap applies to `pgrep -f 'lake build'`.

COHERENCE WITH THE LATEX BUILD GUARD (design constraint, NOT a blocking dependency). A sibling task adds `latex-build-guard.sh` to the same core scripts directory, guarding a different situation: one agent build racing a USER-OWNED continuous watcher, remedied by detect/stop/restore. This task guards N AGENT builds racing EACH OTHER, remedied by serialization and result sharing. Detection and remedy genuinely differ, so a shared implementation was considered and deliberately rejected in favor of a sibling script. Neither script exists yet, so there is no ordering requirement -- but the two should share subcommand shape, exit-code conventions, and the silent-when-no-conflict rule so they read as one family. If the sibling lands first, follow its conventions rather than inventing new ones.

COMMAND-SUBSTITUTION COMPATIBILITY (load-bearing advantage, record it). A companion task mandates `run_in_background` for Lean builds to escape the 10-minute foreground Bash cap, and flags as its highest-risk edit that `skill-lake-repair`'s loop captures build output synchronously via `build_output=$(lake build 2>&1)` -- fundamentally incompatible with detached invocation. A flock-based guard has no such incompatibility: it serializes and still returns stdout and exit status to the caller. The same applies to `lean-sorry-census.sh --cross-check`, which uses the identical `BUILD_OUTPUT="$(lake build 2>&1)"` shape. Design the guard so it is usable from a command-substitution call site, and record this explicitly -- it converts that task's architectural carve-out into a solved case.

DELIVERABLE. A new executable script `agent-system/extensions/core/scripts/lake-build-guard.sh`, registered in `agent-system/extensions/core/manifest.json` under `provides.scripts` (which currently holds 126 entries) so it is deployed. Placement in CORE rather than the lean extension is DELIBERATE and load-bearing: extension hooks are keyed on task_type, so a guard living behind the lean extension's `lean4` gate would never fire for a `general`- or `meta`-typed task that happens to build a Lean project. Suggested subcommand shape (refine during planning): a wrapping/exec mode that runs a guarded build, plus a status/detect mode that reports in-flight builds without launching one. Modes should be separable so callers can adopt detection first. Ship the accompanying test under `agent-system/extensions/core/scripts/tests/` following the existing test convention.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/core/**`. Never edit a deployed `.claude/**` tree -- those are disposable artifacts regenerated on reload, so such an edit silently vanishes.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: the script exists, is executable, and is registered in core's `provides.scripts`; the lock path is derived from the project root and no project path is hardcoded anywhere; a second concurrent invocation demonstrably does NOT launch a duplicate build, and the waiter's behaviour (share result vs. queue) is implemented and documented along with its staleness policy; cgroup bounding and the RAM preflight are present, opt-in, and degrade gracefully with a visible notice where `systemd-run` or the needed signals are unavailable; the LEAN_NUM_THREADS experiment has been run and its ACTUAL result recorded, with the lever shipped only if verified; the script is safe and silent (exit 0, no output) when no conflict exists, since it will run on every build; the script works correctly when invoked from a command substitution; detection never matches itself or its own ancestry; a test exists under core/scripts/tests/; no `.claude/**` file is modified.

---

### 96. Surface literature coverage delta under lit
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 77

**Description**: Surface the sub-index vs global-index coverage delta when --lit is active, so decision-relevant sources sitting in the global corpus are not silently invisible to research. REPORTED EVIDENCE: in the Logos/Theory repo, specs/literature-index.json holds 37 entries against 399 in ~/Projects/Literature/index.json. Sources that turned out to be decision-relevant were present in the global repo, already chunked and readable, and were never surfaced to the research agents: the canonical branching-time cluster (thomason-1970-indeterminist-time, 78 chunks; reynolds-2003-ockhamist, 30; rumberg-zanardo-2019-transition-structures, 42) and the hyperproperty-monitoring cluster (finkbeiner_etal_2017_monitoring_hyperproperties; finkbeiner_etal_2018_rvhyper; bonakdarpour_sheinvald_2023_finite_word_hyperlanguages, 53; sousa_dillig_2016_cartesian_hoare_logic_k_safety, 69; agrawal_bonakdarpour_2016_runtime_verification_k_safety_hyperltl).

CONSEQUENCE OBSERVED: two independent research rounds reached substantive conclusions of the form 'the framework has no counterpart for X' without consulting available global sources that define X. Both claims happened to survive later checking -- a framing gap rather than a false claim shipped -- but that outcome was luck, not a property of the pipeline.

ROOT CAUSE: nothing in the pipeline checks the global index against a draft's specific 'no counterpart exists' claims before they are finalized, and nothing flags that the active sub-index covers a small fraction of what is available.

CONSIDER (do not assume) a lightweight guard: when --lit is active and the sub-index covers materially less than the global index, surface the topic-scoped delta rather than silently proceeding. Design decisions the plan must settle: what counts as 'materially less' (absolute gap, ratio, or topic-scoped miss count); whether the delta is computed against the whole global index or only against entries matching the task's keywords; where the guard fires (the Stage 4a shared block in context/patterns/lit-stage4a-flow.md already has a SPARSE_PROMPT_NEEDED directive and a two-checkpoint sparse re-prompt -- check whether this is an extension of that existing mechanism rather than a new one, which is the preferred outcome); and whether the surfacing is interactive, advisory-in-prompt, or both, given that orchestrator_mode forbids AskUserQuestion. Prefer extending the existing sparse-coverage machinery over adding a parallel mechanism.

Depends on the global-index resolver keying audit: a delta computation that resolves entries by id would itself under-report by more than half the corpus, so the resolver field question must be settled first. The two also share edit territory under extensions/literature/scripts/.

=== REVISED 2026-08-24: DEPENDENCY RETARGETED, AND THE BOUNDARY AGAINST THE COVERAGE-MARKER TASK MADE EXPLICIT ===

DEPENDENCY CHANGE. This task originally depended on a resolver-keying audit task that has since
been abandoned as a duplicate and absorbed into the literature global-index schema-unification
task. The dependency is retargeted to that schema task. The original sequencing reason still
holds and is unchanged: a delta computation keyed on id would itself under-report by more than
half the corpus (sources/<id>/ resolves for 173 of 399 entries; path resolves for all 399), so
the keying question must be settled before a delta is computed.

DO NOT MERGE THIS WITH THE BRIEFING COVERAGE-MARKER TASK. They address two different failure
modes and a fix for either one leaves the other completely open:

  Coverage-marker task  -- REQUESTED BUT NOT RESOLVED. A doc_id IS in the sub-index, the briefing
                           tries to resolve it, resolution fails, and the skip is invisible
                           because only successful resolutions are counted. Detectable from
                           inside the briefing, because the request exists.

  THIS task            -- NEVER REQUESTED BECAUSE NEVER INDEXED. The source is in the global
                           corpus, is relevant, and is absent from the sub-index entirely. No
                           request is ever made, so nothing is ever skipped, so the coverage
                           marker reports healthy and IS CORRECT to do so. Structurally invisible
                           to the other task's mechanism no matter how well that mechanism works.

MOTIVATING EVIDENCE (measured, Logos/Theory, 2026-08-24). A --team --lit research round ran
against a 37-entry sub-index while the global index held 399 entries. The briefing resolved 37 of
37 with zero skip warnings -- a clean bill of health under the coverage marker, and an accurate
one. Meanwhile the sources that decided the round's two headline conclusions were sitting
unindexed in the global corpus, chunked and readable, and were never surfaced:

  branching-time:  thomason-1970-indeterminist-time (78 chunks), reynolds-2003-ockhamist (30),
                   rumberg-zanardo-2019-transition-structures (42)
  hyperproperties: finkbeiner_etal_2017_monitoring_hyperproperties,
                   finkbeiner_etal_2018_rvhyper, bonakdarpour_sheinvald_2023_finite_word_hyperlanguages (53),
                   sousa_dillig_2016_cartesian_hoare_logic_k_safety (69),
                   agrawal_bonakdarpour_2016_runtime_verification_k_safety_hyperltl

CONSEQUENCE, and the reason this is a correctness issue rather than a convenience one: two
independent research rounds reached substantive conclusions of the form "the framework has no
counterpart for X" without consulting available global sources that define X. Both claims
survived later checking -- a framing gap, not a false claim shipped -- but that outcome was luck,
not a property of the process. The claim shape is the tell: an assertion that something is ABSENT
is exactly the claim that unindexed literature is least able to refute.

ROOT CAUSE TO DESIGN AGAINST: nothing in the pipeline checks the global index against a draft's
specific "no counterpart exists" claims before they are finalized. A topic-scoped delta surfaced
at briefing time is the cheap approximation; a claim-shaped check is the expensive one. Decide
which is in scope rather than silently building the cheap one and calling the class closed.

---

### 95. Audit literature index resolver keying
- **Status**: [ABANDONED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: Audit the literature global-index resolvers for id-vs-path keying and fix any that key on id. REPORTED EVIDENCE: in ~/Projects/Literature/index.json all 399 entries have a populated id field, but sources/<id>/ resolves for only 173 of 399. The path field resolves 399/399 -- it points to a directory for whole-work entries and to a specific .md file for chapter-level entries. Any resolver keyed on id therefore fails on 226 entries, silently yielding no content for more than half the corpus.

PARTIAL VERIFICATION ALREADY DONE, DO NOT REDO BLINDLY: extensions/literature/scripts/literature-briefing.sh at lines 227-246 already prefers the parent entry's path field and falls back to $LIT_DIR/sources/$doc_id only when path is empty or dirname resolves to '.'. That specific script may therefore already be correct or near-correct; the fallback branch is still reachable and should be assessed. The audit's real job is the OTHER scripts. Candidates that reference id or "id" and were not inspected: literature-discover.sh, literature-search.sh, literature-normalize-authors.sh, literature-fidelity-audit.sh, zotero-resolve-pdf.sh, zotero-generate-export.sh, test-lit-pipeline.sh (all under extensions/literature/scripts/). Determine for each whether it resolves on-disk content by id or by path, and fix the ones that key on id to prefer path with the same directory-vs-file handling literature-briefing.sh already implements.

EXPLICITLY NOT A DEFECT -- DO NOT "FIX" IT: only 73 of 399 global-index entries carry a doc_id key at all; the other 326 simply lack the key. That is a legacy partially-migrated field, not missing data or corruption. An earlier analysis wrongly flagged it as corruption. Leave it alone.

This is expected to be small and mechanical, but the scope must be verified rather than assumed -- confirm which field each script actually keys on before changing anything. Add a regression check that a resolver returns content for a chapter-level entry (path pointing at a .md file) as well as a whole-work entry (path pointing at a directory).

=== ABANDONED 2026-08-24: ABSORBED AS A DUPLICATE ===
This task's scope is already owned by the literature global-index schema-unification task, whose
acceptance criterion 4 requires a complete reader survey with each reader either fixed or its
exclusion documented as deliberate. That task additionally covers a namespace this one did not
find at all (the .literature.db FTS chunks_data.doc_id namespace, which disagrees with the global
index on 49 documents) and carries the id-vs-FTS agreement requirement as its own criterion 7.
The five readers this task named that the survey did not (literature-discover.sh,
literature-normalize-authors.sh, zotero-resolve-pdf.sh, zotero-generate-export.sh,
test-lit-pipeline.sh), the 173/399-vs-399/399 path measurement, and the doc_id do-not-fix note
have all been folded into that task as an addendum. Nothing is lost by abandoning this one.
Working both would collide: both declare file_scope agent-system/extensions/literature/scripts/**.

---

### 94. Wire lit flag through team skills
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: Wire the --lit flag through the three team skills so literature mode is not silently dropped in team mode. VERIFIED DEFECT (checked directly against the source store at agent-system/, not a deploy artifact): skill-team-research/SKILL.md, skill-team-plan/SKILL.md, and skill-team-implement/SKILL.md contain ZERO references to lit_flag or literature (grep -ci 'lit_flag|literature' returns 0 for all three). Their single-agent counterparts skill-researcher, skill-planner, and skill-implementer return 8 each; the -hard variants return 6 each. None of the three team skills even declares lit_flag in its Input Parameters table (they declare task_number, session_id, team_size, model_flag, effort_flag, and skill-specific fields only).

THIS IS NOT A COMMAND-LAYER BUG. All three commands already pass the flag into team mode: commands/research.md:539 passes lit_flag={lit_flag} in the team-mode args string (line 543 does the same for single-agent), and lines 465-467 parse --lit correctly; commands/plan.md:537 and commands/implement.md:319 do the same for their team-mode dispatches. The command hands the flag over and the skill drops it on the floor. Observed live during a /research N --team --lit run: the flag was accepted, passed to the skill, and did nothing.

REQUIRED FIX: each team skill must execute the canonical literature flow at context/patterns/lit-stage4a-flow.md -- the same shared block skill-researcher imports. See skill-researcher/SKILL.md around lines 153-165 for the exact import prose to mirror: call literature-lit-flag-resolve.sh, branch on all six directives (LIT_DISABLED, SUBINDEX_PRESENT, GLOBAL_MISSING, PROMPT_NEEDED, AUTONOMOUS_GLOBAL, SPARSE_PROMPT_NEEDED), issue the real four-option AskUserQuestion for the two interactive directives (including the 'Search online to ingest' option wired to the STABLE-CONTRACT literature-ingest-online.sh bridge), apply the two-checkpoint sparse re-prompt after 'Use global corpus now', and take the deterministic [lit:auto] autonomous fallback when orchestrator_mode == 'true'. Each team skill must supply the shared block's preconditions: lit_flag, description, and orchestrator_mode.

DESIGN QUESTION THE PLAN MUST DECIDE AND DOCUMENT EXPLICITLY (this is the real work, not the import). Single-agent skills resolve lit_context once and inject it into one agent prompt. Team skills spawn 2-4 teammates via the Agent tool, each with its own prompt and fresh context. Choose among: (a) the lead resolves the briefing ONCE and injects the same lit_context into every teammate prompt; (b) each teammate resolves its own; (c) the lead resolves once and teammates navigate the corpus on demand per context/project/literature/patterns/agent-exploration.md. Option (a) is the likely answer because the interactive AskUserQuestion directives cannot sensibly fire 4x in parallel, but the orchestrator_mode dual-consumer contract in lit-stage4a-flow.md MUST be checked against parallel spawn before committing to it. Whatever is chosen must be stated in prose in each skill file, because the next person will hit the same question. Consider also whether the lead should resolve BEFORE the wave spawns (Stage 5 in skill-team-research) so no teammate starts without the briefing.

STAGE-NUMBER COLLISION TO RESOLVE AS PART OF THIS WORK: skill-team-research/SKILL.md:123 has a stage literally titled 'Stage 4a: Fallback to Single Agent' -- an unrelated stage colliding with the number used by the canonical literature stage (Stage 4a) everywhere else in the system. This is a live source of confusion for anyone implementing this fix. Renumber or retitle the fallback stage; do not introduce a second Stage 4a.

VERIFICATION STEP TO INCLUDE (regression guard): add a lint asserting that every skill reachable from a command that accepts --lit either consumes lit_flag or carries an explicit documented statement of why it does not. Register it wherever the repo's other doc/contract lints are registered (see docs/reference/utility-scripts-inventory.md). This lint is what would have caught the defect.

ACCEPTANCE CRITERION: after implementing in this repo and reloading the agent system into a project repo (via <leader>al), /research N --team --lit must produce a real literature briefing for every teammate rather than silently proceeding as if --lit were absent. This task is independently implementable and independently satisfies that criterion; it is the blocker.

=== ADDENDUM 2026-08-24: DUPLICATE CHECK RESULT, AND THE RELOAD DEPENDENCY ===

DUPLICATE CHECK: a sweep of all 60 active tasks found NOTHING covering the team-skill lit_flag
defect. This task is genuinely new. Its two sibling tasks from the same /meta dispatch did overlap
existing work and were handled: the resolver-keying task was abandoned and absorbed into the
literature global-index schema-unification task, and the coverage-delta task was retargeted to
depend on that same schema task. This task has no such overlap and no dependency on either -- it
is independently implementable and independently satisfies the acceptance criterion, which is the
point of keeping it separate.

RELOAD DEPENDENCY, worth stating because the acceptance criterion runs through it: the criterion
is that /research N --team --lit produces a real briefing for every teammate in a CONSUMING repo,
which requires the fix to be deployed there, not merely committed here. The task covering
postflight deploy gating for source-store tasks documents that completed source-store work can sit
undeployed indefinitely -- and this was observed live during the run that found this defect: the
consuming repo's gate-in emitted "deployed extension 'core' is stale" and "deployed extension
'literature' is stale" warnings in the same session. Verifying this task means regenerating the
consuming repo's .claude/ tree and re-running the command there, not just reading the diff in the
source store. Do not mark it verified on a source-store-only check.

---

### 93. Close cross repo deploy skew
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 83
- **Research**: [093_close_cross_repo_deploy_skew/reports/01_cross-repo-deploy-skew-visibility.md]

**Description**: The postflight deploy gate makes 'completed' mean 'in effect' IN THIS REPO ONLY. It does nothing for consuming repos, which pull independently -- so a fix verified here stays broken everywhere else until each repo is reloaded by hand. That is not hypothetical drift; it is the measured state today.

MEASURED 2026-08-24, three repos at THREE DIFFERENT REVISIONS of the same source store:
- BimodalLogic/.claude/scripts/skill-base.sh -- matches CURRENT SOURCE (carries the persisted-counter fix)
- .config/nvim/.claude/scripts/skill-base.sh -- STALE since 2026-08-17 (pre-fix ambient-variable code)
- Logos/Theory/.claude/scripts/skill-base.sh -- STALE, byte-identical to the nvim copy
The source-of-truth repo is running OLDER code than one of its own consumers. Separately confirmed that this is pure staleness and not local editing: every deployed script in both consuming repos either matches current source or matches a historical source revision exactly (Theory's archive-task.sh matches the 2026-07-16 revision byte-for-byte). No hand-edits, so nothing is lost by reloading -- only context/repo/project-overview.md is syncprotected in each, and it survives.

DETECTION IS NOT THE GAP. check-deploy-freshness.sh is deployed in all three repos and correctly reports 'stale' in all three, on every command. It is always-exit-0 and wrapped in `|| true` at its call site, so all three have been warning correctly and being ignored for a week.

WHAT MAKES THIS DIFFERENT FROM THE SINGLE-REPO GATE: regeneration is pull-only BY DESIGN, documented in context/patterns/regeneration-is-manual-only.md -- a consuming repo's tree deliberately freezes until its owner reloads. Do NOT 'fix' this by having this repo push into consuming repos; that inverts a deliberate architectural decision and would deploy into a repo whose session is mid-command.

SCOPE, framed as making skew VISIBLE AND ACTIONABLE rather than eliminating it: (a) enumerate known consuming repos and report, from here, which are behind and by how much -- the source_git_head stamping work already provides the per-extension revision needed; (b) after a deploy here, name the consuming repos that now need a reload rather than leaving the operator to remember; (c) decide whether a consuming repo's own freshness warning should escalate on its Nth consecutive ignored run, since a warning ignored seven days running is not functioning as a warning.

ACCEPTANCE: from this repo, one command reports the deployed revision of every known consuming repo and flags those behind source. A deploy here ends by naming which consuming repos are now stale.

---

### 92. Quality gate false positive on logic notation
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 32
- **Research**: [092_quality_gate_false_positive_on_logic_notation/reports/01_quality-gate-binder-exemption.md]
- **Plan**: [092_quality_gate_false_positive_on_logic_notation/plans/01_gate-binder-exemption-fix.md]

**Description**: === ADDENDUM 2026-08-24: exact mechanism, verified by execution ===
LOCATION: literature_quality_gate.py:118, in sentence_boundary_glue_count():
    exempted = re.sub(r"[∀∃λ][a-z]\.[A-Z]", "", exempted)
    return len(re.findall(r"[a-z]\.[A-Z]", exempted))
The binder exemption matches a quantifier or lambda followed by EXACTLY ONE lowercase letter. Executed against the real pattern:
    λx.Fx    -> exempted, 0 counted   (correct)
    λxy.Ryx  -> NOT exempted, 1 counted   (DEFECT: multi-character bound variable)
    ^x.Fx    -> NOT exempted, 1 counted   (DEFECT: `^` hat abstraction absent from the character class)
    ∀x.Px    -> exempted, 0 counted   (correct)
    λx1.Rx1  -> not exempted but 0 counted anyway -- the digit breaks [a-z]\.[A-Z]. Subscripted/numbered variables are NOT part of this defect; do not widen for them.
The docstring at :114-116 states the narrow class is deliberate, so that a bare letter-period-capital with no binder prefix is still counted. That intent is correct; the bug is that a MULTI-CHARACTER binder reads as 'no binder prefix'. The gate threshold is 3, so a higher-order-logic paper trips on notation alone.

THE FIX IS NOT A THRESHOLD BUMP, and this is the crux. Five PDFs rejected during a higher-order-identity ingest batch were inspected match-by-match, and the outcomes SPLIT:
    goodman_2024_higher_order_logic_as_metaphysics   11/11 hits lambda notation      -> FALSE POSITIVE
    bacon_a_case_for_higher_order_metaphysics        11/11 hits hat/lambda           -> FALSE POSITIVE
    bacon_dorr_2024_classicism                       genuine <sup>-span space collapse under pymupdf4llm -> TRUE POSITIVE
    hott_book_2013                                   8 genuine + 3 bibliography in 229k words -> MIXED
    ahrens_north_shulman_tsementzis_univalence       ~17 genuine + ~7 bib in 69k words        -> MIXED
The gate DOES catch real corruption. Widening the exemption must not blind it to the <sup>-span collapse, which is the failure it exists for.

SUGGESTED SHAPE (evaluate, do not assume): extend to roughly [∀∃λ^][a-z][A-Za-z0-9]*\. -- adding hat abstraction and allowing a multi-character bound-variable run.
REGRESSION FIXTURES: all five documents above, on disk under ~/Projects/Literature/sources/. Acceptance is that the two false positives drop to zero hits WHILE bacon_dorr_2024 still trips. The two MIXED documents are the honest hard cases -- state explicitly what the gate should do with a document carrying both genuine corruption and legitimate notation, rather than tuning until they happen to pass.
PROVENANCE: analysis recorded in ~/Projects/Literature/FIND_SOURCES.md under 'Quality-gate overrides (2026-08-20, higher-order identity batch)'.
=== ORIGINAL DESCRIPTION FOLLOWS ===
The literature conversion quality gate rejects correctly-converted documents whose content is formal-logic notation. Surfaced during a real conversion session in a consuming repo and recorded there in FIND_SOURCES.md as a manual override log for five PDFs; it was never filed as a task in any tracker, and the consuming repo's own note correctly observes that the durable fix belongs in agent-system/extensions/literature/ rather than that repo's deployed .claude/ tree.

MECHANISM: the gate's mojibake/corruption heuristic includes an `[a-z]\.[A-Z]` pattern -- a lowercase letter, a literal period, an uppercase letter -- intended to catch run-together words from a bad PDF extraction. Lambda-binder notation trips it directly: `λxy.Ryx` matches, as does any `λx.Fx` form. So a CLEAN conversion of a logic or semantics paper is scored as corrupt.

WHY THIS MATTERS BEYOND THE FALSE POSITIVE: the operator response is to override the gate by hand, five times in one session in the observed case. A gate that must be routinely overridden stops being read, and the next genuine pymupdf4llm corruption gets waved through with the same reflex. The failure mode is the override habit, not the rejected file.

SCOPE: distinguish genuine extraction corruption from formal notation. Candidate approaches, to be evaluated rather than assumed: exclude matches whose preceding character is a binder glyph (λ, ∀, ∃, ι, μ); require the pattern to recur above a density threshold rather than firing on any single occurrence; or exempt documents whose detected subject matter is logic/mathematics. Preserve the mojibake detection that the completed conversion-quality-gate work added -- this narrows that gate, it does not revert it. Carry the five FIND_SOURCES.md cases in as regression fixtures, and add at least one genuine-corruption fixture so the narrowing is proven non-vacuous.

DEPENDENCY NOTE: literature-convert.sh is one of the scripts currently drifted between source and deploy, so any before/after measurement taken before the deploy lands is measuring the wrong file.

ACCEPTANCE: all five recorded false-positive documents pass the gate unmodified; a known-corrupt fixture still fails it; no hand override required for either.

---

### 91. Make update-plan-status.sh diagnose non-conforming Status lines, and settle the trailing-text tolerance policy
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: status-marker-lifecycle
- **Dependencies**: None

**Description**: update-plan-status.sh reports every non-conforming plan Status line with one generic, undiagnosable message, and hard-fails /orchestrate postflight on a plan shape that a legitimate resume workflow produces. Reported independently by a peer session reviewing a consuming repo (BimodalLogic) and re-derived by execution against the source store on 2026-08-24.

CORRECTION TO THE ORIGINAL FILING. This task previously led with a claim that lines 62/72 compare two EMPTY strings and yield a silent SUCCESS. That is false, and it was verified false by running the script against fixtures for all three malformed shapes. Do not go looking for that path.
  - Line 62's `grep -m1 "^- \*\*Status\*\*:" | sed 's/.*\[\([^]]*\)\].*/\1/'` does NOT return empty on a bracket-less line. grep matches (the `- **Status**:` prefix is present), so `|| echo ""` never fires, and sed's substitution simply does not apply -- so the whole line comes back verbatim as `current_status`. It is non-empty, and it never equals a bare status token, so the equality check cannot pass.
  - Measured outcomes: trailing-text shape -> rc=1; no-brackets shape (target PARTIAL and target COMPLETED alike) -> rc=1; missing-`- `-prefix shape -> rc=1; well-formed change -> rc=0 and correctly stamped. There is no false-success input.
  - Consequently the old acceptance criterion "no input produces an empty-equals-empty pass" was already vacuously satisfied and has been dropped.

WHAT IS ACTUALLY WRONG. Four distinct defects, all confirmed:

1. DIAGNOSTIC OPACITY (the core defect). All three malformed shapes exit 1 with the byte-identical message `Failed to update status in <file>`. It names no line number, quotes no line content, and states no reason. The operator must reverse-engineer which of three different problems occurred.

2. `$`-ANCHOR INTOLERANCE OF TRAILING ANNOTATIONS. Line 69's replacement pattern `s/^- \*\*Status\*\*: \[.*\]$/.../` requires the line to END at the closing bracket. A plan carrying `- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)` can therefore NEVER be stamped -- the sed is a permanent no-op and every transition on that plan fails. This shape arose from a legitimate resume workflow, which is the argument for tolerating it rather than rejecting it.

3. PREFLIGHT MASKS THE LEADING INDICATOR. update-task-status.sh:515-525 branches fatal-vs-warn on operation. Preflight prints only `Warning: plan file update failed (non-fatal)`, so a malformed Status line survives an entire task and only bites at POSTFLIGHT, where the same failure is `exit 3`. Note carefully: postflight does NOT silently diverge. It fails loudly and calls itself retryable. The "state.json says completed while the plan still reads [IMPLEMENTING], and generate-todo.sh reads only state.json" sentence in the original filing is the code comment's RATIONALE for making postflight fatal, not a description of an undetected outcome. The real cost is a late, expensive failure that a preflight warning already knew about.

4. stdout/rc CONTRACT AMBIGUITY. The script header promises "Outputs: Updated plan file path on success, empty on failure/no-op". The idempotency early-exit (lines 62-66, already-at-target) returns rc=0 with EMPTY stdout -- so stdout alone cannot distinguish success from failure. The sole current caller branches on rc and is unaffected, but commands/implement.md:353 documents a defensive call site, and any future stdout-consuming caller would be misled.

REQUIRED FIX.
(a) Diagnose loudly. On no-match, print the offending line VERBATIM with its line number and state WHICH condition failed: missing `- **Status**:` prefix, missing brackets, or trailing text after the closing bracket. Replace the single generic message with these three distinct ones.
(b) Decide and implement a tolerance policy for trailing text after `]`. Either accept it -- rewriting only the bracketed token and preserving the remainder, which defect 2 argues for -- or reject it explicitly as malformed. Apply the choice consistently and document it in context/formats/plan-format.md, which is where plan format is specified (see its existing line 99 discussion of the three status-mutating scripts).
(c) PRESERVE the deliberate preflight/postflight asymmetry. update-task-status.sh's error text acknowledges it on purpose. The fix is diagnosability, not flipping fatality.

ALSO EVALUATE (evaluate, do not assume).
  - Whether the preflight non-fatal path should emit a one-line operator-visible WARNING naming the malformed line, given that a preflight no-op is the leading indicator of the fatal postflight failure.
  - Whether a plan-format lint should validate the Status line at plan-creation time, so a malformed line never reaches a dispatch.
  - Whether the idempotent-no-op path (defect 4) should echo the plan path rather than empty, making stdout a reliable success signal.

ACCEPTANCE.
  - Each of the three malformed shapes (trailing text, no brackets, missing prefix) produces a DISTINCT, line-numbered diagnostic quoting the offending line.
  - A well-formed plan still stamps correctly, and the already-at-target path stays a no-op.
  - The chosen trailing-text policy is implemented and documented in plan-format.md.
  - Redeploy and confirm the fix survives regeneration (.claude/ is a deploy artifact; the edit target is agent-system/extensions/core/).

PROVENANCE. Originally filed in the BimodalLogic repo and abandoned there on 2026-08-24 because its entire work product lands in this repo -- BimodalLogic's .claude/ is a gitignored deploy artifact wiped on every reload, so the fix was not executable from there. That repo's specs/archive/state.json retains the original description and its specs/PATH.md records the handoff. This entry closes that handoff and supersedes the peer session's request to file a second task.

---

### 90. Adoption lint for shared task lookup helper
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 84

**Description**: The largest duplication class in the repo, and it has never been named in any review: the inline task-lookup jq block. 111 files carry a hand-rolled `jq --argjson num ... '.active_projects[] | select(.project_number == $num)'` lookup against specs/state.json, totalling roughly 62,000 duplicated bytes. The canonical helper skill_validate_input() already exists at skill-base.sh:185 and has SIX callers, with ZERO overlap against the 111.

For scale: this single class exceeds the three classes named in the 2026-08-11 review COMBINED (raw git commit -m, session-ID one-liner, jq #1132 block, ~58 KB together).

This is an ADOPTION gap, not a missing-abstraction gap -- the same shape as every other class here. Someone built the helper; nothing held the line. Six classes in this repo have a canonical home and near-zero adoption.

SCOPE: build the adoption lint FIRST, modelled on the corrected single-source gate (correct file-type scope, source-store-deterministic root, restricted to executable surfaces so illustrative prose in docs/ and context/ is not flagged); land it as failing-with-a-known-baseline or fix-then-enforce, whichever convention the gate fix establishes; then migrate the call sites. Migration can be incremental as long as the lint prevents NEW occurrences from day one -- preventing growth matters more than the backlog, since this class grew while unwatched.

ACCEPTANCE: lint rejects a newly introduced inline task-lookup on an executable surface; adopter count rises and duplicate count falls; both numbers recorded so the next review can measure direction rather than re-derive it.

---

### 89. Mode gate literature and distill skills
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 87

**Description**: Apply the mode-gated section convention to the two remaining large instances, after the pilot proves it.

skill-literature/SKILL.md, 84,265 B total, 64.5% fenced bash. Seven mutually exclusive mode sections of which exactly ONE fires per invocation: Mode: Rebuild 20,170 | Mode: Convert 17,534 | Mode: Search 10,043 | Mode: Validate 5,989 | Mode: Import Pipeline 5,785 | Mode: Index 5,234 | Mode: Ingest 1,917 = ~65,772 B, 78% of the file. Cleanly '## Mode:'-delimited, so the split is mechanical. Estimated ~14,000 tokens per /literature invocation, taking it from ~46.2k toward ~32k.

skill-distill/SKILL.md, 93,044 B total, only 1.9% bash -- essentially pure prose. `## Auto Distill Complete` is 43,254 B, 46% of the file, and is an OUTPUT TEMPLATE used by --auto alone. It belongs in context/formats/, not in a skill body loaded on every /distill invocation. Estimated ~10,800 tokens per non---auto /distill, taking it from ~42.4k toward ~32k.

Combined estimated saving ~24,800 tokens across the two commands' invocations.

Both carry the same fence-interior heading hazard as the orchestrate application -- '## Mode:' and '## Auto' strings can appear inside fenced examples. Split bottom-up and verify each extracted section round-trips.

ACCEPTANCE: each mode section loads only when its mode is selected; all seven literature modes and both distill paths verified working; measured reductions reported against the 46.2k and 42.4k baselines.

---

### 88. Mode gate skill orchestrate multi task section
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 87

**Description**: Apply the mode-gated section convention to the largest single instance in the system. skill-orchestrate/SKILL.md is 188,284 B; its `## Multi-Task Mode` section measures 103,462 B -- 55% of the file -- and is entered ONLY when multi_task_mode=true. Stage 0 states it explicitly: 'If multi_task_mode is true: skip Stages 1-8 entirely and proceed to Stage MT-1.' Every single-task /orchestrate N therefore loads ~26k tokens of text it will never execute, on the command intended for the longest, most context-hungry runs.

Section breakdown of the file: ## Multi-Task Mode 103,462 (only ~11% bash) | ## Execution Flow 71,570 | ## MUST NOT (Context Flatness) 8,932 | remainder ~2,500.

ESTIMATED SAVING: ~26,000 tokens per single-task /orchestrate invocation, taking its budget from ~83.5k toward ~57k. This is the single largest measured token item in the system and it is a pure move -- the section is self-contained and the branch is already explicit, so no prose rewriting is required.

Secondary, separable lever recorded here so it is not lost: this file carries 5 bash blocks of >=20 lines totalling 39,275 B, and skill-orchestrate-hard carries 9 such blocks totalling 63,892 B. Bash moved into a standalone script costs ZERO context because the script source is never loaded. That is a bigger per-token win than prose extraction and is already the established pattern here (~20 orchestrate-*.sh scripts exist). Do it in a follow-up rather than widening this work.

BEWARE the fence-interior heading trap: naive '^## ' section splitting can match headings inside fenced code blocks and silently truncate. The slim-task-command plan documents this exact hazard and mandates bottom-up extraction so earlier line numbers do not drift. Reuse that approach.

ACCEPTANCE: single-task /orchestrate no longer loads the multi-task section; multi-task /orchestrate still works end to end; measured budget reduction reported against the 83.5k baseline.

---

### 87. Mode gated section loading convention
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None

**Description**: Establish the convention that fixes the single largest token lever in the system: MUTUALLY-EXCLUSIVE BRANCH SECTIONS LOADED UNCONDITIONALLY. A skill's SKILL.md body is loaded IN FULL on every invocation -- there is no include, partial, fragment or compose mechanism in install-extension.sh, and deploy is a byte-for-byte copy. Four files carry large sections entered on exactly one branch and skipped on every other invocation:

| File | Dead-branch section | Bytes | Share | Fires when |
| skill-orchestrate/SKILL.md | ## Multi-Task Mode | 103,462 | 55% | multi_task_mode=true only |
| skill-distill/SKILL.md | ## Auto Distill Complete | 43,254 | 46% | --auto only |
| skill-literature/SKILL.md | 7x ## Mode: sections | ~65,772 | 78% | exactly one fires |
| commands/task.md | 5 non-default modes | 25,883 | 66% | one mode per invocation |

Verified in skill-orchestrate Stage 0: 'If multi_task_mode is true: skip Stages 1-8 entirely and proceed to Stage MT-1.' The branches are explicitly exclusive, so every single-task /orchestrate N loads ~26k tokens it will never execute. Measured /orchestrate budget today is ~83.5k tokens before any work begins.

This is ONE architectural defect, not four. This work defines the convention ONLY; the per-file applications are separate tasks so each stays bounded to one agent run. The commands/task.md instance is already owned by the slim-task-command work.

SCOPE: decide the mechanism (a referenced context/ file read on demand when the branch is taken is the established pattern -- moving procedural bash to scripts/ removes it from context entirely, while moving prose to context/ saves only on invocations that do not need it); define the section-marker convention; document it in context/patterns/; and add a lint that flags a runtime-loaded .md carrying a mutually-exclusive branch section above a byte threshold. Without the lint this regresses, exactly as every other extracted-then-readopted class in this repo has.

DO NOT pursue twin-dedup between skill-orchestrate and skill-orchestrate-hard as part of this: the 2026-08-11 review's '>=28,421 B byte-identical' figure did not reproduce. Contiguous identical runs of >=8 lines total only 8,168 B. It is a weak lever and a distraction.

ACCEPTANCE: convention documented, lint in place and green, and one pilot application landed demonstrating the measured saving.

---

### 86. Expand ci to full gate suite and go green
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 82

**Description**: .github/workflows/check-extension-docs.yml is the repository's ONLY CI workflow. It runs exactly one of the nine check/lint scripts, and it exits 1 today. The single automated enforcement point in the repo is red and has been ignored -- which makes it functionally advisory, the same shape as the non-blocking hooks.

THE 16 CURRENT FAILURES (from a live run):
- core, 1x deployed script content drift: scripts/skill-base.sh
- core, 7x index-entries.json line_count mismatch: architecture/context-layers.md 219->221; patterns/file-metadata-exchange.md 305->314; standards/postflight-tool-restrictions.md 216->219; patterns/regeneration-is-manual-only.md 210->259; patterns/batch-orchestration-guardrails.md 737->812; patterns/file-footprint-overlap.md 194->202; reference/orchestrator-critical-paths.json 70->74; patterns/skill-postflight-flow.md 126->177
- literature, 5x deployed script content drift: literature-discover.sh, literature-convert.sh, literature-normalize-authors.sh, tests/generate-test-fixtures.py, tests/test-literature-convert.sh
- literature, 1x line_count mismatch: project/literature/domain/literature-index.md 144->117
- project-wide, 1x Rule S: deployed context/contracts/return-meta-artifacts-template.md has no entry in .claude/context/index.json

Most of these clear as a side effect of the pending deploy plus generate-context-line-counts.sh --write; the return-meta index entry needs a real fix. Do not paper over any of them by relaxing the lint.

SCOPE: expand the workflow to run all nine gates (or verify-deploy.sh as the aggregator, once it is callable); fix the 16 issues; keep it green. Sequence after the deploy-verification wiring so CI and local deploy share one entry point rather than drifting into two definitions of 'verified'.

ACCEPTANCE: CI runs the full suite on every push and is green; a deliberately reintroduced line_count mismatch fails the build.

---

### 85. Deflake shell test suite under concurrency
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 32

**Description**: THE SHELL TEST SUITE IS NON-DETERMINISTIC, and until it is fixed no acceptance gate in this repo is trustworthy in either direction -- including the 19/23 verify-deploy figure the 2026-08-24 survey reports. Split out of a former six-item bundle where its value was diluted by hygiene items.

MEASURED 2026-08-24: two runs in the same session failed in DIFFERENT suites. The verify-deploy gate-8 run reported failures in test-mint-dispatch-seq.sh (Cases B-F), fix-roundtrip, and the single-source assertion; an independent standalone run minutes later reported 41 passed / 4 failed with the failures in test-validate-return-meta.sh instead. Wall clock 100s. The 2026-08-11 review measured the same class across five consecutive runs: exit 1, 0, 1, 0, 0 -- roughly a 2-in-5 failure rate with passing runs reporting a clean 36/36.

Note the confounder that must be separated during diagnosis: SOME of the gate-8 failures are NOT flake. test-mint-dispatch-seq.sh's failures are real and caused by deploy staleness -- the deployed skill-base.sh carries the pre-fix ambient-variable code while the test asserts the fixed persisted-counter behavior. Re-measure after the deploy lands so genuine staleness failures are not misattributed to flake, and flake is not excused as staleness. That exact misattribution already happened once: the 2026-08-10 capstone dismissed a real failure as 'a flaky lock-contention test attributable to concurrent sibling sessions, not a deploy defect' WITHOUT being able to confirm it, precisely because the suite cannot distinguish the two.

Suspected cause: the suite runs concurrently with other live sessions holding the same locks and touching shared global state. Diagnose it; then either isolate the affected tests from shared state or make them wait deterministically. A test that is merely retried is not fixed.

ACCEPTANCE: 10 consecutive runs, executed while at least one other session is active, all report the same result.

---

### 84. Fix duplication gate scope and extensions root
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None
- **Research**: [084_fix_duplication_gate_scope_and_extensions_root/reports/01_duplication-gate-scope-and-extensions-root.md]
- **Plan**: [084_fix_duplication_gate_scope_and_extensions_root/plans/01_duplication-gate-scope-fix.md]

**Description**: The one duplication gate that exists has the wrong scope and has reported PASS while its class grew. test-common-lib.sh:230-234 asserts single-source for the session-ID generator with `grep -rl 'sess_\$(date' --include="*.sh" "$EXTENSIONS_ROOT"`. It greps ONLY *.sh. 46 of the 48 duplicate sites are *.md. The class grew 43 -> 48 files between 2026-08-11 and 2026-08-24 with the gate green throughout.

Second, independent defect in the same block: EXTENSIONS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)" resolves to the repo root when the test runs from the deployed tree rather than the source store, making the assertion environment-dependent even for the two .sh files it can see. This is tracked as errors.json err_1787022038113_c3VPTR, severity HIGH, fix_status unfixed, and verified still present in BOTH source and deploy today.

A gate with the wrong scope is worse than no gate: it reports safety. This is the template every other duplication class needs, so fix it before cloning the pattern.

SCOPE: add *.md to the include set; scope the search to executable surfaces (commands/, skills/, agents/) to avoid flagging illustrative prose in docs/ and context/; fix EXTENSIONS_ROOT to resolve the source store deterministically in both modes; then migrate the 46 newly-visible .md sites to common_session_id() (10 adopters today). Mark err_1787022038113_c3VPTR fixed with closing evidence.

ACCEPTANCE: the gate fails on a deliberately reintroduced inline sess_$(date in a .md under commands/, passes from both the source store and a deployed tree, and the live count reaches 0 outside lib/common.sh.

---

### 83. Postflight deploy gate for source store tasks
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 82
- **Research**: [083_postflight_deploy_gate_for_source_store_tasks/reports/01_postflight_deploy_gate.md]
- **Plan**: [083_postflight_deploy_gate_for_source_store_tasks/plans/01_postflight-deploy-gate.md]
- **Summary**: [083_postflight_deploy_gate_for_source_store_tasks/summaries/01_postflight-deploy-gate-summary.md]

**Description**: Make 'completed' mean 'in effect' for tasks that edit the source store. TODAY IT DOES NOT: the deploy is 7 days and 133 commits stale, and four completed tasks (the mint-dispatch-seq fix and the three literature fixes) are marked COMPLETED with honest summaries while their fixes are absent from the running system. Deployed .claude/scripts/skill-base.sh:958 still reads `dispatch_seq_counter=$((dispatch_seq_counter + 1))` -- the exact pre-fix ambient-variable code that was replaced; source line 963 reads the corrected `jq -r '(.dispatch_seq_counter // 0) + 1'`. The accompanying test-mint-dispatch-seq.sh was never deployed. The HIGH-severity literature corpus-corruption gate is likewise not live.

The detection half already exists and works: check-deploy-freshness.sh correctly reports both core and literature stale right now. It cannot act -- it has ZERO exit-1 paths anywhere in the file, and its one caller at command-gate-in.sh:120 wraps it in `|| true` regardless. Two independent layers of non-blocking. It has warned correctly on every command for seven days.

DECISION TAKEN (user, 2026-08-24): gate at POSTFLIGHT, not preflight. A meta task that touched agent-system/** cannot reach [COMPLETED] until a deploy has run. Preflight blocking was rejected: 47 of 48 tasks are task_type meta, so nearly every /implement dirties the tree and would block the NEXT command, and a hard preflight block dead-ends autonomous /orchestrate.

MANDATORY PREREQUISITE: context/patterns/regeneration-is-manual-only.md states deploy-headless.sh 'must be invoked explicitly and never as a silent side effect of an unrelated operation', narrowed by exactly ONE sanctioned automated call site (skill-orchestrate Stage MT-3 step 7, the inter-cycle redeploy checkpoint). That section explicitly states it is NOT precedent and that any further automated caller needs its own exception recorded in the same section. This work MUST add that recorded carve-out, following the document's correction-as-addition convention -- additive, labeled, never rewriting the existing constraint in place. Model the justification on the existing one: not a side effect of an unrelated operation (the deploy makes live precisely the fix that triggered it), not silent (log on fire/success/failure), and bounded (evidence-gated on modified_files actually touching agent-system/**).

ACCEPTANCE: a meta task whose implementation edits the source store cannot reach [COMPLETED] without the deploy having run; the carve-out is recorded; and check-deploy-freshness.sh's read-side role is explicitly documented as advisory-only so its always-exit-0 contract is no longer mistaken for a gate.

---

### 82. Wire deploy verification into deploy headless
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 32
- **Research**: [082_wire_deploy_verification_into_deploy_headless/reports/01_wire-verify-into-deploy-headless.md]
- **Plan**: [082_wire_deploy_verification_into_deploy_headless/plans/01_wire-verify-into-deploy-headless.md]
- **Summary**: [082_wire_deploy_verification_into_deploy_headless/summaries/01_wire-verify-into-deploy-headless-summary.md]

**Description**: deploy-headless.sh:233 PRINTS the verification step instead of running it. The line reads `echo "[deploy-headless] Verify with: bash $TARGET/.claude/scripts/verify-deploy.sh"` followed immediately by `exit 0`. verify-deploy.sh aggregates five working contract lints (lint-agent-contracts, lint-contract-compliance, lint-postflight-boundary, lint-routing-wiring, lint-state-writer-boundary) plus doc-lint, task-reference lint, verify.lua parity, the shell test suite and validate-state --deep, and exits 1 on failure. Because its only caller echoes instead of invoking, all of that is reachable only by a human typing the command. command-gate-out.sh invokes ZERO checks (grep for 'check-|lint-' returns nothing). check-runtime-file-tracking.sh has no caller anywhere in the repo -- only a manifest declaration and prose references.

This single echo is the proximate cause of the 2026-08-11 -> 2026-08-24 regression: verify-deploy went 21/23 -> 19/23, doc-lint failures 4 -> 16, and index-entries line_count drift 3 -> 8 stale entries, all while five green lints sat disconnected.

SCOPE: change the echo to an actual invocation; decide and document the failure contract (does a failing verify fail the deploy, or warn loudly and exit non-zero?); ensure --dry-run does not invoke it. Consider running only the fast gates inline and deferring the 100s test suite, since gate wall-clock is ~2.8 min and a slow deploy is a deploy that gets skipped.

ACCEPTANCE: a deploy that leaves the tree failing any verify-deploy gate reports that fact in its own output, non-zero. Verified by deliberately introducing a line_count mismatch, deploying, and observing the failure surface without a human running verify-deploy by hand.

---

### 81. Mechanize task-lock and session-registry heartbeat refresh: liveness timestamps never advance during a multi-phase /implement run
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: None

**Description**: Task-lock and session-registry heartbeats never fire during a real single-task /implement run. Both liveness timestamps stay frozen at their acquire-time value for the entire run, so every staleness-based consumer sees a healthy, actively-working session as long-dead.

=== OBSERVED LIVE (do not re-derive the observation; DO re-derive the cause) ===

Run: /implement 111 in the PossibleWorlds repo, session sess_1787265639_358e17, PID 263643. The run SUCCEEDED — all 8 plan phases reached [COMPLETED] over ~18 minutes wall clock. Throughout:

- specs/111_verify_interval_twisted_arrow_lemma/.lock/holder.json read acquired_at=2026-08-20T22:40:39Z and heartbeat_at=2026-08-20T22:40:39Z — byte-identical.
- specs/.sessions/sess_1787265639_358e17.json read started_at and heartbeat_at at that same value — byte-identical.
- Both stayed frozen when sampled at 171s and again past the 5-, 7-, and 18-minute marks, while `ps -p 263643` confirmed the process alive and progress/phase-1-progress.json plus successive plan-heading transitions confirmed forward progress.

Eight phase transitions occurred. heartbeat_at never moved once.

=== THE CRUX: THE MECHANISM IS WIRED IN AND STILL DID NOT FIRE ===

This is NOT an absent-caller bug and must not be researched as one. Verified in the source store:

1. agent-system/extensions/core/agents/general-implementation-agent.md, Stage 4D ("Mark Phase Complete"), lines ~279-297, carries BOTH calls adjacently at the phase-transition point:
     bash .claude/scripts/task-lock.sh heartbeat "{task_number}" "{session_id}" 2>/dev/null || true
     bash .claude/scripts/task-lock.sh session-heartbeat "{session_id}" 2>/dev/null || true
   with prose asserting this is "the actual per-phase-transition site for single-task /implement".

2. agent-system/extensions/core/skills/skill-implementer/SKILL.md:217-219 documents that it is a thin wrapper with no phase-transition point of its own, and that the refresh lives in the agent's Stage 4D.

3. agent-system/extensions/core/commands/implement.md:169-183 documents the batch-loop side and states the single-task heartbeat "lives one layer down, inside each dispatched general-implementation-agent.md".

4. agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:2115 goes further and threads the BARE session_id into the dispatch context specifically "because general-implementation-agent's per-phase task-lock.sh heartbeat call presents this exact field's value against holder.json, and a suffixed value would desync the heartbeat from the lock".

5. Routing verified: task_type=formal resolves via command-route-agent.sh to general-implementation-agent (noncore-exact) — the very agent carrying the calls. Not a routing miss to some other implementation agent lacking the hook.

So: the calls exist, routing reaches them, the whole design depends on them, eight transitions occurred, and nothing moved.

=== HYPOTHESES TO INVESTIGATE — DO NOT PRE-COMMIT TO ANY ===

(a) STRUCTURAL. The calls are prose instructions inside a markdown agent definition, not enforced code. An agent may simply not run them and nothing detects the omission. If so the fix is structural: move the refresh into a script the lifecycle mechanically invokes rather than trusting an agent to execute a documented bash snippet. A concrete candidate exists — the SAME Stage 4D block already calls `bash .claude/scripts/update-phase-status.sh "$task_number" "$project_name" "$phase_num" COMPLETED`, which is the one script guaranteed to run at every phase transition. It currently takes no session_id (verified: agent-system/extensions/core/scripts/update-phase-status.sh accepts exactly 4 positional args and contains no session/SESSION reference), so mechanizing there requires threading session_id in. Weigh that against alternatives (skill-base.sh, a lifecycle hook) rather than assuming it.

(b) SILENT FAILURE. The calls ran but failed. Both use `2>/dev/null || true` — the same silence-on-failure idiom filed in the empty-block-reason task. Any of these would be indistinguishable from success:
    - Unsubstituted `{task_number}` / `{session_id}` placeholders. Note that the agent file uses BRACE-placeholder form while skill-orchestrate/SKILL.md:313,318 uses shell-variable form `"$task_number"` / `"$session_id"` for the identical calls. Determine whether substitution actually happens in the agent's rendered prompt.
    - The RELATIVE path `.claude/scripts/task-lock.sh`. Agent threads reset cwd between bash calls; a non-repo-root cwd makes every invocation a silent no-op.
    - Argument-order or subcommand mismatch.
   Check placeholder substitution and cwd empirically before anything else.

(c) FALLBACK PATH. Stage 4D offers an Edit-tool fallback for the phase heading "if the script is unavailable". Determine whether that path was taken and whether it bypasses the heartbeat site.

(d) CONDITIONAL NO-OP IN cmd_heartbeat ITSELF. Verified: cmd_heartbeat (agent-system/extensions/core/scripts/task-lock.sh:831) returns 0 WITHOUT writing in two cases — no lock directory/holder.json, and holder session_id mismatching the passed session_id — emitting only a WARN to stderr, which `2>/dev/null` discards. A session_id desync (exactly what skill-orchestrate:2115 warns about) produces a silent successful-looking no-op. cmd_session_heartbeat (line 1283) has the same never-blocks contract.

=== WHY THIS OUTRANKS A COSMETIC METADATA BUG ===

Verified consumer behavior in agent-system/extensions/core/scripts/task-lock.sh:

- TASK_LOCK_STALE_MIN defaults to 30 (line 206). cmd_acquire's stale-override path (~lines 730-740) compares heartbeat age against it and, when exceeded, prints "WARN: ... lock is stale ... overriding and acquiring" and TAKES THE LOCK. A frozen heartbeat means any /implement run exceeding 30 minutes has its lock broken out from under a live implementer mid-edit.
- TASK_LOCK_REAP_MIN defaults to TASK_LOCK_STALE_MIN * 4 = 120 (line 214). cmd_reap (line ~950) `rm -rf`s any lock whose heartbeat age exceeds it.
- cmd_check returns exit 2 for "held, stale (heartbeat older than the threshold)" (documented contract, line 117), so every downstream staleness consumer reads a live session as dead.
- The overlap-scan path at ~lines 656-666 also decides on heartbeat age, printing "proceeding without modifying it" for a lock it deems stale.

The observed 18-minute run stayed under the 30-minute threshold, so nothing actually broke THIS time. That is the honest severity: this is a live latent hazard whose blast radius scales with run length, not an already-fired incident. Establish empirically whether any long-running command has crossed 30 minutes in practice — that sets true severity.

It also misleads operators. The human running this session twice nearly concluded the implementer had died from these fields, and was corrected only by `ps` and the progress directory. A liveness field that is wrong in the "looks dead" direction is worse than no field at all.

=== DEFENSE IN DEPTH: THE TASK LOCK CANNOT CHECK LIVENESS AT ALL ===

Independent of the root cause, there is a verified asymmetry between the two registries:

- The SESSION registry records a pid. write_session_entry (task-lock.sh:471-484) persists pid and pid_source, resolve_session_pid (line ~424) does a bounded ancestor walk for the nearest "claude" process, and session-reap's dead-pid shortcut is additionally floored by a dead-pid-minutes constant (lines 225-231) so it can never fire against a recently-heartbeated entry. That reaper is already defensive.
- The TASK lock records NO pid. write_holder (task-lock.sh:298, 319-321) persists exactly seven fields — session_id, task_number, operation, acquired_at, heartbeat_at, command — and pid is not among them. cmd_reap and cmd_acquire's stale-override therefore have NOTHING but the timestamp to go on, and cannot refuse to act against a live process even in principle.

Consider adding a pid (and pid_source) to holder.json and making both the task-lock reaper and the stale-override path fail safe: refuse to reap or override a lock whose recorded pid is alive, mirroring the floor already applied on the session side. This is worth doing whatever the heartbeat root cause turns out to be, because the reaper acting on a bad timestamp is where the real damage occurs.

=== DETECTABLE FINGERPRINT ===

`acquired_at == heartbeat_at` after N minutes is a reliable fingerprint of "never heartbeated once", distinct from "heartbeated then went quiet". Consider surfacing it as its own diagnostic signal (in `check`, in the reap dry-run output, or in a health probe) rather than letting the two failure modes look identical.

=== SURVEY REQUIREMENT — DO NOT SPOT-FIX ONE CALL SITE ===

Audit every heartbeat call site for the same problem and determine which, if any, demonstrably fire:
- agent-system/extensions/core/agents/general-implementation-agent.md Stage 4D (lines ~283, 296) — the site observed failing.
- agent-system/extensions/core/skills/skill-orchestrate/SKILL.md lines ~313, ~318, ~1518 — same snippets, same `2>/dev/null || true` silence idiom, shell-variable placeholder form.
- agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md — check for the same pattern.
- agent-system/extensions/core/commands/implement.md lines ~169-183 — documents the multi-task expectation and an intentional omission of an intra-batch session heartbeat; verify that reasoning still holds once the root cause is known.
Also check the hard-mode implementation agent for the same block.

=== DESIGN QUESTIONS TO SETTLE IN RESEARCH (directions, not decisions) ===

1. Does heartbeat refresh belong in agent prose AT ALL? Argue it explicitly. If a documented bash snippet in a markdown agent definition cannot be relied on to execute, every other best-effort snippet in that file is equally suspect and this is a systemic finding, not a local one.
2. If mechanized at a lifecycle call site, WHICH one, and how does session_id reach it? Name the threading path concretely.
3. Should these calls stay silent? `2>/dev/null || true` is correct for "never block phase progression" but it is exactly what made this undiagnosable for eight consecutive transitions. Separate "never block" from "never report" — a heartbeat that no-ops because of a session mismatch is a real defect signal being thrown away.

=== SECOND FINDING, SAME TELEMETRY-INTEGRITY THEME (decide placement in research) ===

specs/events.jsonl recorded three subagent_stop events attributed to session_id sess_1787265639_358e17 (the implementer) that carry cc_session_id 08ebe7c9-f020-45bc-bce1-0eea931247e6 — a DIFFERENT Claude session's agents. Foreign stops are logged under the marker owner's session_id because of the `head -1` arbitrary-marker mis-selection in subagent-postflight.sh, so the event record is falsified and post-hoc telemetry misattributes work between sessions. Verified in the live events.jsonl.

Decide during research whether this belongs here or as an amendment to the existing subagent-postflight marker-ownership/correlation task, which already owns the `head -1` selection defect. Default expectation: it is a CONSEQUENCE of that defect and should amend that task's acceptance criteria (the fix must be shown to correct event attribution, not merely marker selection). Do not fix it here without recording that decision.

=== RELATIONSHIP TO ADJACENT TASKS ===

Cross-reference only; no file_scope overlap was found and no hard dependency is declared:
- The subagent-postflight marker-ownership/correlation task and the empty-block-reason task both live in agent-system/extensions/core/hooks/, which this task does not touch. The empty-block-reason task shares only the `2>/dev/null` silence-idiom THEME with hypothesis (b) — cross-reference, do not merge.
If research finds this task must edit a file in either of those tasks' file_scope, declare the dependency then rather than assuming it now.

=== ACCEPTANCE CRITERIA ===

1. The root cause is established EMPIRICALLY, not argued from the source. A reproduction is recorded: run a multi-phase /implement, sample holder.json and the session registry entry across at least two phase transitions, and show heartbeat_at advancing. A fix that cannot be demonstrated against a real multi-phase run does not satisfy this criterion.
2. After the fix, both specs/{NNN}_{slug}/.lock/holder.json and specs/.sessions/{session_id}.json show heartbeat_at strictly greater than acquired_at / started_at, and advancing, within a single multi-phase /implement run.
3. The refresh survives the failure mode identified in research — if the cause is that agent prose is not executed, the fix is NOT more prose. State in the plan which mechanism guarantees execution and why it cannot be skipped.
4. A heartbeat call that no-ops (missing lock, session mismatch, unresolvable task dir) leaves a recorded trace an operator can find after the fact, without making the call blocking.
5. The call-site survey above is complete: every listed site is either demonstrated to fire, fixed, or documented as deliberately absent with the reason.
6. Either holder.json carries pid liveness information and both cmd_reap and cmd_acquire's stale-override refuse to act against a live process, or the decision not to add it is recorded with an argument for why timestamp-only reaping is acceptable for task locks when it was explicitly judged unacceptable for session entries.
7. The `acquired_at == heartbeat_at` never-heartbeated fingerprint is either surfaced as a distinct diagnostic or explicitly rejected with a reason.
8. The events.jsonl cross-session attribution finding is resolved to a definite home: fixed here, or filed as a recorded amendment to the marker-ownership task.

=== BINDING RULES ===

SOURCE-STORE RULE: edits target agent-system/extensions/**, never the deployed .claude/** tree, a disposable deploy artifact regenerated from the source store.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 80. Stop the literature index rebuild from indexing backed-up chunk manifests
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [080_exclude_backups_from_literature_index_rebuild/reports/01_exclude-backups-from-index-rebuild.md]
- **Plan**: [080_exclude_backups_from_literature_index_rebuild/plans/01_exclude-backups-index-rebuild.md]

**Description**: literature-build-index.sh traverses the corpus with an unguarded recursive `find` and indexes chunk manifests inside ~/Projects/Literature/.backups/ as if they were live, silently inflating chunk counts and admitting STALE CHUNK CONTENT into the searchable FTS5 index. The safe re-ingestion practice — move the old chunk set aside rather than delete it — is exactly what triggers the bug.

=== VERIFIED MECHANISM (re-verify line numbers, they drift) ===

File: agent-system/extensions/literature/scripts/literature-build-index.sh

Line 91:  mapfile -t manifests < <(find "$target_dir" -name "chunks.json" | sort)

No -prune, no -path exclusion, no maxdepth. $target_dir is the Literature root, so the traversal descends into .backups/ and every other dotfile-prefixed directory.

OBSERVED LIVE: during a re-ingestion of Schultz, Spivak & Vasilakopoulou, "Dynamical Systems and Sheaves", the rebuild reported 144 chunks for a doc_id that has 99, because the backed-up 45-chunk manifest was summed alongside the new one. The operator worked around it by renaming the backup's manifest to chunks.json.bak. That workaround is undocumented and unenforced, so the next re-ingestion hits the same trap.

CONFIRMED CURRENT STATE of ~/Projects/Literature/.backups/ (four directories, any of which may carry manifests):
  chunk-regen-2026-07-27/
  combining-repair-2026-07-27/
  quarantined-orphaned-chunks-2026-07-27/
  schultz-spivak-vasilakopoulou-dynamical-systems-sheaves_old_20260820/
A find for chunks.json under .backups/ currently returns nothing, but a find for chunks.json.bak returns many (e.g. quarantined-orphaned-chunks-2026-07-27/baier_katoen_2008_dot_chunks/section*/chunks.json.bak). The corpus is clean ONLY because of manual .bak renames. The next backup written without that rename reintroduces the defect immediately.

=== THE MISCOUNT IS THE COSMETIC HALF; STALE SEARCHABLE CONTENT IS THE SUBSTANTIVE HALF ===

Do not scope this as a counting bug. Chunks are written with INSERT OR REPLACE INTO chunks_data keyed on chunk_id (line ~192), and `find | sort` places ".backups/..." FIRST lexicographically, so for chunk_ids present in BOTH manifests the live version wins the replace and the count is merely wrong. But a re-chunking that changes section boundaries produces chunk_ids that exist ONLY in the old manifest. Those have no live counterpart to replace them, so they persist in the rebuilt database permanently and are returned by search. Worse, their content_preview was read from the BACKUP directory's chunk files (the loop resolves chunk_file relative to os.path.dirname(manifest_path), line ~168), so the FTS5 index carries superseded text and source_path values that point into .backups/. Determine empirically whether stale-only chunk_ids are actually present in the current database before deciding the migration/rebuild story.

=== SCOPE — DIRECTIONS, NOT DECISIONS ===

1. Exclude backups from the traversal. Decide whether the exclusion belongs in the `find` itself (-path '*/.backups/*' -prune) or, more durably, in a shared "what counts as a live corpus directory" predicate. A bare .backups exclusion is a spot-fix: any dot-prefixed or quarantine directory has the same property, and the current .backups/ contents show at least three distinct non-corpus directory conventions in use.

2. TREAT DUPLICATE doc_id AS AN ERROR, NOT A SILENT SUM. This is the more durable fix and should be evaluated on its merits, not as an add-on. A rebuild that encounters two manifests claiming the same doc_id has encountered an ambiguity it cannot resolve correctly, wherever those manifests live. Erroring (or at minimum warning loudly with both paths named) catches this entire class regardless of path, including cases no exclusion list anticipates. Decide whether it should be fatal or a loud warning, and whether an explicit override is warranted.

3. Traversal survey. A grep of the extension's scripts for `find ... -name` found the build-index line to be the only unguarded recursive traversal; literature-audit.sh (lines ~104, ~163, ~311) and literature-ingest.sh (line ~142) all use -maxdepth 2 or narrower, and literature-ingest-online.sh uses -maxdepth 1. literature-search.sh performs NO traversal of its own — it queries the database that build-index.sh produces, which is precisely why a corrupted build propagates straight into search results with no independent check. Confirm this survey rather than assuming it; if any other script gains a recursive traversal it must inherit the same predicate.

4. Decide whether a rebuild should report what it indexed in a way that would have made this visible — e.g. per-doc_id chunk counts, or a diff against the prior index — so a 99-chunk document reporting 144 is caught at rebuild time rather than noticed by an operator reading log output.

=== RELATIONSHIP TO THE SCHEMA-UNIFICATION TASK (sequencing) ===

Sequenced after the literature global-index schema-unification task, for two reasons. Mechanically, that task lists literature-build-index.sh in its file scope, so the two must serialize. Substantively, the duplicate-doc_id question in scope item 2 interacts directly with that task's decision about canonical entry shape and about how entries are keyed — settling the schema first means the duplicate-detection rule is written against a single known entry shape rather than against two incompatible ones.

=== ACCEPTANCE CRITERIA ===

1. A rebuild run with an intact chunks.json present under ~/Projects/Literature/.backups/ produces the same index as a rebuild with that directory absent. Verified by a regression test that plants a backup manifest and asserts the resulting per-doc_id chunk count matches the live manifest exactly.
2. A rebuild that encounters two manifests claiming the same doc_id fails, or warns with both manifest paths named — not silently sums. The chosen behavior is documented.
3. The current database is audited for stale chunk_ids and stale source_path values pointing into .backups/, and any found are removed by a clean rebuild.
4. The traversal survey above is completed and any exclusion logic is shared rather than duplicated per script.
5. The manual chunks.json.bak rename workaround is no longer necessary, and nothing in the ingestion or re-ingestion path depends on an operator remembering it.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/**, never the deployed .claude/** tree — it is a disposable deploy artifact regenerated from the source store, and hand-authored files there are silently wiped.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 79. Make subagent-postflight hook diagnosable when its marker is malformed
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [079_diagnosable_subagent_postflight_marker_failure/reports/01_diagnosable-postflight-marker-failure.md]
- **Plan**: [079_diagnosable_subagent_postflight_marker_failure/plans/01_diagnosable-postflight-marker-failure.md]
- **Summary**: [079_diagnosable_subagent_postflight_marker_failure/summaries/01_diagnosable-postflight-marker-failure-summary.md]

**Description**: subagent-postflight.sh blocks a SubagentStop with an EMPTY reason string whenever the postflight marker is not valid JSON, so the blocked agent receives "Blocked by hook" with no explanation of any kind and no way to learn what happened. The hook's own default reason never fires in exactly the case where a reason is most needed.

=== VERIFIED MECHANISM (do not re-derive; re-verify line numbers, they drift) ===

File: agent-system/extensions/core/hooks/subagent-postflight.sh

Line 90:  local reason=$(jq -r '.reason // "Postflight operations pending"' "$MARKER_FILE" 2>/dev/null)
Line 95:  echo "{\"decision\": \"block\", \"reason\": \"$reason\"}"

jq's `//` alternative operator fires only when the left side evaluates to null or false. It does NOT fire on a PARSE ERROR. When $MARKER_FILE is not valid JSON, jq exits nonzero, writes its diagnostic to stderr — which `2>/dev/null` discards — and emits nothing on stdout. $reason is therefore the empty string, the "Postflight operations pending" default is never reached, and the hook emits {"decision": "block", "reason": ""}.

OBSERVED LIVE: a planner subagent's SubagentStop was blocked and the only feedback it received was "Blocked by hook", with no reason text whatsoever. It had to reverse-engineer the cause from first principles. The marker in that instance was key=value shaped rather than JSON. NOTE: the reason THAT particular marker was malformed was a separate caller bug, already understood, and is explicitly NOT part of this task. skill_create_postflight_marker() at agent-system/extensions/core/scripts/skill-base.sh:247 writes correct JSON; that marker did not come from it. The defect here is that the hook's failure mode is undiagnosable no matter WHY the marker is malformed.

=== THE FIX PATTERN ALREADY EXISTS IN A SIBLING HOOK ===

agent-system/extensions/core/hooks/events-log-lifecycle.sh line 127 reads the SAME marker file and guards it correctly:

    jq empty "$MARKER_FILE" 2>/dev/null || exit_success

That is precisely the validation step subagent-postflight.sh lacks. There is no need to invent a mechanism; there is in-repo precedent five lines from an identical `find specs -maxdepth 3 -name ".postflight-pending" -type f | head -1` call. Use it, and reconcile the two hooks' handling of the same file rather than fixing one in isolation.

=== SECOND VICTIM: THE TELEMETRY THAT WOULD DIAGNOSE THIS IS BLINDED BY THE SAME MALFORMATION ===

events-log-lifecycle.sh's guard is correct as a guard but its consequence is `exit_success` — it silently logs NOTHING. So when a marker is malformed, the postflight lifecycle event is simply absent from the events log. The agent gets an empty block reason AND the telemetry that would let an operator reconstruct what happened after the fact records nothing at all. Both channels fail silently on the same input. Whatever is decided for the hook, decide also whether a malformed marker should itself be a logged event rather than a silent no-op.

=== ADJACENT DEFECT IN THE SAME FIVE LINES (in scope) ===

Line 95 interpolates $reason unescaped into hand-built JSON. A marker whose .reason contains a double quote, a backslash, or a newline produces malformed JSON on the hook's stdout — a second, distinct silent failure with the same blast radius. The inline comment at line 94 ("Using simple JSON output - no jq dependency for robustness") justifies the hand-built JSON on robustness grounds, but line 90 already invokes jq unconditionally, so the stated justification does not hold. Either drop the jq dependency genuinely or use `jq -n --arg` to build the output safely.

=== SURVEY REQUIREMENT (do not spot-fix one call site) ===

A grep of agent-system/extensions/core/hooks/*.sh for the `jq -r '... // default' 2>/dev/null` idiom returns roughly 38 call sites across claude-stop-notify.sh, events-log-artifact.sh, events-log-lifecycle.sh, guard-destructive-git.sh, memory-nudge.sh, validate-handoff-location.sh, validate-meta-write.sh, and validate-no-task-references.sh. Nearly all use `// empty`, where an empty result on parse error is indistinguishable from an empty result on a missing field — usually benign, because those sites treat empty as "skip". subagent-postflight.sh is distinguished by using a NON-EMPTY default that the parse-error path silently discards, which is what makes it user-visible. Classify the sites rather than rewriting all of them: identify every site where a non-empty default is expected to fire, and every site where "field absent" and "file unparseable" must be handled differently. Fix those; document the rest as deliberately tolerant.

=== DESIGN QUESTIONS TO SETTLE IN RESEARCH (directions, not decisions) ===

1. Distinguish "marker parses but has no .reason field" (where the existing default IS the right answer) from "marker does not parse at all" (which needs its own explicit reason naming the malformed marker's path, so the blocked agent can inspect it).
2. Decide whether an unparseable marker should block the stop AT ALL, or fail open with a loud diagnostic. Blocking on a marker that cannot be read traps an agent in a stop it cannot satisfy and cannot diagnose; failing open loses the premature-termination guard. Argue the tradeoff explicitly rather than defaulting.
3. If it blocks, the reason MUST name the marker path and the parse failure. A reason string is the only channel the blocked agent has.

=== FILE-SCOPE OVERLAP — SEQUENCING IS REQUIRED, NOT OPTIONAL ===

This task and the subagent-postflight marker-ownership/correlation task (which addresses `head -1` arbitrary marker selection and teammate stops burning the orchestrator's loop-guard budget) both edit subagent-postflight.sh, in adjacent regions of the same function. They MUST be serialized. This task is sequenced second, for a substantive reason as well as a mechanical one: the ownership task decides WHICH marker the hook is responsible for, and it is not worth deciding how to report a marker's reason before deciding whose marker it is. The two tasks do not otherwise overlap — ownership/correlation does not touch .reason parsing, and this task does not touch marker selection or the loop guard.

=== ACCEPTANCE CRITERIA ===

1. A SubagentStop blocked because of an unparseable postflight marker produces a non-empty reason that names the marker path and states that it could not be parsed. Verified by a test that writes a deliberately malformed marker and asserts on the emitted reason.
2. A marker that parses but lacks .reason still yields the existing "Postflight operations pending" default — the two cases are distinguishable in the emitted reason.
3. The hook's stdout is valid JSON for any marker content, including a .reason containing double quotes, backslashes, and newlines. Verified by test.
4. The malformed-marker case is observable after the fact through the events log or an equivalent recorded signal, rather than leaving no trace in either channel.
5. The hook survey above is completed: every core hook site where a non-empty jq default is expected to fire is either fixed or documented as tolerant-by-design.
6. subagent-postflight.sh and events-log-lifecycle.sh handle the same malformed marker file consistently, and the divergence between them is either eliminated or documented as intentional.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/**, never the deployed .claude/** tree — it is a disposable deploy artifact regenerated from the source store, and hand-authored files there are silently wiped.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 78. Make the briefing coverage marker report resolution-failure rate
- **Effort**: 1-3 hours
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 77
- **Research**: [078_briefing_coverage_resolution_failure_signal/reports/01_coverage-resolution-failure-signal.md]

**Description**: literature-briefing.sh's coverage marker counts documents that RESOLVED and is structurally blind to the resolution FAILURE RATE, so a briefing that dropped every primary source for a task self-reports as healthy. This is the silent-degradation half of the stub-entry defect and is arguably the more dangerous half: the schema bug loses documents, this bug hides that they were lost.

=== VERIFIED EVIDENCE (re-verify line numbers, they drift) ===

During a real /research --lit run, literature-briefing-invoke.sh emitted 13 consecutive "not found in global index — skipping" warnings to stderr — every one of them a primary or confirmatory source for the task — and the briefing nonetheless emitted:

    <!-- lit-coverage mode=repo seg_count=56 sparse=false threshold=3 -->

sparse=false. The run retained only tangential material (temporal logic, hyperproperties, modal logic background — none of it on the actual research topic) and reported healthy coverage. Nothing downstream had any signal that the briefing was gutted: not lit-stage4a-flow.md's two-checkpoint sparse detection, not the consuming agent.

Mechanism confirmed: literature-briefing.sh computes sparse from coverage_count (~lines 411-415), which is incremented only on successful resolution. Skips hit `continue` (~line 186) without touching any counter. There is no skip tally anywhere in the script.

=== WHY STDERR IS NOT SUFFICIENT ===

The warnings did go to stderr, and literature-briefing-invoke.sh (introduced by the completed, vaulted lit_briefing_failure_surfacing work) deliberately lets stderr flow through unmodified. But stderr is not part of the briefing payload the consuming agent reads. The agent receives the <literature-briefing> block and the coverage marker; it never sees the warnings. So the agent proceeds believing it holds the relevant corpus.

Per lit-stage4a-flow.md's own Non-Silence Invariant, a branch must "either produce a briefing or explicitly and visibly announce why none was produced". A briefing that silently omits the majority of its requested documents satisfies the letter and violates the spirit.

=== RELATION TO PRIOR WORK ===

The vaulted, completed lit_briefing_failure_surfacing task made briefing CRASH distinguishable from briefing EMPTY, via the invoke wrapper. It stopped exactly one step short: PARTIAL resolution failure — some documents resolve, others silently do not — remained indistinguishable from full success. This task closes that gap. Treat that task's summary as the design precedent for the anti-silence posture, and its wrapper as the seam to extend rather than replace.

The completed discover tier-starvation / silent-tier3-failure fix is the direct precedent for the general principle: a zero-or-degraded result must never be reportable as a healthy one.

=== SCOPE ===

1. Track resolution failures. Add a skip counter alongside the existing coverage_count, incremented at the skip path.
2. Extend the lit-coverage marker to carry the failure signal (e.g. requested/resolved/skipped counts), so a high skip rate cannot self-report as sparse=false. Preserve the existing marker fields — lit-stage4a-flow.md (~lines 199-204) greps for `lit-coverage mode=global .*sparse=true`, and adhoc-navigation-directive.md (~lines 45-46) matches the marker too. Both must keep working.
3. Surface skipped doc_ids in the briefing BODY, not only on stderr, so the consuming agent can see what it did not get and can navigate to those documents by other means.
4. Decide and document the threshold policy: at what skip rate does the briefing itself become untrustworthy, and should that force sparse=true or a distinct signal? Update context/project/literature/domain/sparse-coverage.md accordingly.
5. Verify both consumers still behave correctly after the marker change.

=== ACCEPTANCE CRITERIA ===

1. A briefing run in which some requested doc_ids fail to resolve reports that fact in the coverage marker; the failure is not inferable only from stderr.
2. Skipped doc_ids appear in the briefing body.
3. Existing consumers of the lit-coverage marker (lit-stage4a-flow.md's grep, adhoc-navigation-directive.md's two-checkpoint re-prompt) continue to work unchanged, verified.
4. The threshold policy is documented in sparse-coverage.md.
5. Regression test: a deliberately-unresolvable doc_id registered in a sub-index drives the coverage marker to report the failure rather than reporting sparse=false. This assertion is the point of the task — without it the silent-degradation behavior regresses freely.

=== SEQUENCING NOTE ===

Depends on the schema-unification task. Two reasons. Mechanically, both tasks edit literature-briefing.sh, so they must serialize. Substantively, running this task second means its regression test asserts against an already-correct resolver: a green test then means the failure signal genuinely works, rather than merely that the corpus happened to resolve. The failure signal itself is NOT specific to the schema bug — it must fire for any future resolution failure from any cause, and should be designed to that broader requirement rather than to the stub-entry case alone.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed .claude/** tree — it is a disposable deploy artifact regenerated from the source store, and hand-authored files there are silently wiped.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 77. Unify the literature global-index schema and end stub-entry invisibility
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 32
- **Research**: [077_unify_literature_global_index_schema/reports/01_unify-literature-global-index-schema.md]
- **Plan**: [077_unify_literature_global_index_schema/plans/01_unify-global-index-fts-namespace.md]
- **Summary**: [077_unify_literature_global_index_schema/summaries/01_unify-global-index-fts-namespace-summary.md]

**Description**: === ADDENDUM 2026-08-24: exact writer/reader mismatch, and a duplicate filed elsewhere ===
THE MECHANISM IS A WRITER/READER KEY MISMATCH, not a missing write. The ingest DOES write to the global index; it writes the wrong key.
    Writer -- literature-ingest.sh emits {"doc_id": ..., "title": <slug>, "authors": [], "year": null, "chunk_count": N}
    Reader -- literature-briefing.sh:114,175 resolves `select(.id == $id)` and counts chunks via child entries with parent_doc == id
Since doc_id != id, EVERY ingest-written entry is invisible to the briefing. Measured in ~/Projects/Literature/index.json today: 73 entries keyed doc_id, 324 keyed id. Even on a key match the ingest entries are metadata-poor -- title is the bare slug, authors empty, year null -- and they have no parent_doc chunk children for the reader to count.

OBSERVED CONSEQUENCE, not inference: a --lit research round in a consuming repo silently missed 7 of 25 ingested verification sources, INCLUDING both of the user's own manuscripts (brast-mckie_2026_counterfactual-worlds and construction-possible-worlds), despite the work resting on the semantics they develop. The agent hand-routed to selected doc_ids because the briefing surfaced nothing, so corpus coverage became one agent's topical guess. There is no error in that path -- the sources are simply absent from the briefing, so the gap is invisible at the point of use.

SCOPE (supersedes the vaguer framing below): (a) reader tolerates BOTH key shapes -- the immediate unblock; (b) writer normalized to the curated schema with real title/authors/year plus parent_doc chunk children; (c) one-shot backfill of the existing doc_id-keyed entries; (d) regression check that ingest-then-brief actually surfaces the document.
CONCRETE VERIFICATION: the briefing resolves every sub-index entry with ZERO skip warnings.

DUPLICATE FILED ELSEWHERE: a consuming repo opened its own task for this defect in its own tracker, because the defect surfaced there. It belongs here -- literature-ingest.sh and literature-briefing.sh live in this source store, and a fix written into that repo's .claude/ tree would be wiped on its next reload. Close that one as a duplicate of this task rather than working it there.
COUNT CAVEAT: the global index is being actively repaired from another repo (null-id repair, sources/ consolidation), so entry counts move. Re-measure at implementation time rather than trusting the numbers above; the SHAPE of the defect is what is stable.
=== ORIGINAL DESCRIPTION FOLLOWS ===
The literature global index at ~/Projects/Literature/index.json contains two mutually incompatible entry shapes, and literature-briefing.sh understands only one of them, so an entire class of ingested documents is silently invisible to --lit. Verified empirically during a real /research --lit run, not speculation. SEVERITY: HIGH — silent corpus invisibility.

=== VERIFIED EVIDENCE (re-verify line numbers, they drift) ===

A --lit invocation resolved SUBINDEX_PRESENT (69 sub-index entries, threshold 3) and literature-briefing-invoke.sh emitted 13 consecutive warnings of the form:

    Warning: doc_id 'dorr_2016_to_be_f_is_to_be_g' not found in global index — skipping

The 13 skipped doc_ids were EXACTLY the primary and confirmatory sources the task needed. The corpus is NOT missing: every one is on disk and fully chunked (dorr_2016 has 170 chunks, bacon_dorr_2024_classicism 148, hott_book 691, escardo 331), readable at ~/Projects/Literature/<doc_id>/chunk_NNNN.md.

Counts confirmed: `[.entries[] | select(.id == null)] | length` == 16 stub-shaped entries vs 359 canonical.

CANONICAL shape (written by literature-build-index.sh): keyed by .id; path "sources/<doc_id>/"; separate child entries per chunk linked by parent_doc; carries bib_key, real title, authors, keywords, summary.

STUB shape: keyed by .doc_id, .id ABSENT; path "<doc_id>/" at TOP LEVEL not under sources/; chunks_dir (absolute) plus a scalar chunk_count; NO per-chunk child entries.

=== FIVE INDEPENDENT BREAKAGES (a lookup-only fix is insufficient) ===

1. Identity lookup (literature-briefing.sh ~lines 173, 180): select(.id == $id) never matches a stub entry.
2. Path resolution (~228-245): reads .path, and the fallback hardcodes $LIT_DIR/sources/$doc_id. Stub documents live at $LIT_DIR/$doc_id. Fixing only the id lookup still misses.
3. Chunk counting (~204-222): counts children via select(.parent_doc == $id) and sums their token_count. Stub entries have no children — they carry a scalar chunk_count and a document-level token_count instead.
4. Metadata (~191-201): title/authors/year resolve to degraded stub values, rendering "dorr_2016_to_be_f_is_to_be_g (?) — " rather than "To Be F Is To Be G (2016) — Cian Dorr".
5. get_doc_fidelity() (~line 113) repeats the same select(.id == $id) pattern and silently returns the fail-open default "unverified_summary" for every stub entry — so all 16 are also invisible to the fidelity-marker system.

The comment at literature-briefing.sh lines 105-107 asserts the now-false invariant that all lookups are "keyed by index.json's .id field".

=== TWO STUB SUB-VARIANTS — WRITER PROVENANCE IS AN OPEN RESEARCH QUESTION ===

The stub shape is NOT uniform, and this must be resolved before choosing a migration strategy:

- THIN variant (e.g. dorr_2016_to_be_f_is_to_be_g): 8 fields only, degraded metadata — title set to the literal doc_id string, authors [], year null. No path, no token_count, no doc_type, no provenance_fidelity.
- RICH variant (e.g. j_nsson_and_tarski_-_1951_...): additionally carries path, token_count, doc_type, source_format, zotero_key, provenance_fidelity — AND real title/authors/year.

literature-ingest.sh's python3 heredoc (Step 4, ~lines 285-330) hardcodes "title": "$DOC_ID", "authors": [], "year": None and emits only the 8-field thin variant. It therefore CANNOT be the producer of the rich variant. A static grep of the extension's scripts found no writer of source_format or doc_type at all, and the only writer of provenance_fidelity (literature-fidelity-audit.sh) documents in its own header that it only ever touches sources/ directories. RESEARCH MUST DETERMINE where the rich variant's enrichment came from (historical script version, one-off migration, or out-of-band manual edit) before deciding whether migration can be mechanical.

=== ADDITIONAL AFFECTED READERS (survey, do not assume briefing is the only victim) ===

- literature-search.sh hardcodes prefix = "sources/" at four sites (~251, 540, 779, 921), unguarded. Confirm FTS5 index coverage of stub docs.
- literature-fidelity-audit.sh header (~lines 63-65) documents that entries "live outside sources/" from the other ingestion pipeline "are never matched or written" — the divergence is already KNOWINGLY ACCOMMODATED rather than fixed. Decide whether to fix or keep the exclusion deliberate.
- zotero-attach-chunks.sh resolves via select(.zotero_key == $k) — a third namespace; thin-variant stubs have no zotero_key.
- Note a THIRD index file exists: specs/zotero-index.json, distinct from specs/literature-index.json. scripts/deprecated/README.md already documents this divergence and records that literature-briefing.sh reads a 4-field sub-index shape {doc_id, relevance, added, source}. Do not conflate the three files.

=== --validate GAP (confirmed) ===

/literature --validate checks index entries against the FILESYSTEM (stale entries, missing files, token-count drift). Stub entries point at real, populated directories and pass cleanly. There is no schema-shape conformance check anywhere in the extension. Add one, so this class cannot recur undetected.

=== SCOPE DECISION TO MAKE IN RESEARCH ===

Decide the schema question first. Normalizing at the WRITER (fix literature-ingest.sh to emit the canonical shape, plus a migration for the 16 existing entries) is the more durable route; a reader-only fix leaves the divergence in place for the next reader to rediscover. Reader tolerance may still be worth adding defensively. Address the title/authors/year degradation at the same time — the metadata is available from Zotero in the ingest path (cf. zotero-read.sh).

=== RELATED WORK ===

- Vaulted, completed: literature_schema_unification handled a DIFFERENT axis (v1/v2 field presence: doc_type/source_format/zotero_key/project_tags). Do not conflate it with this doc-vs-chunk shape divergence.
- Vaulted, completed: lit_briefing_failure_surfacing introduced literature-briefing-invoke.sh so briefing CRASH became distinguishable from EMPTY. It did not cover PARTIAL resolution failure — that gap is the companion task's subject.
- Planned: the Zotero metadata resolution upgrade task targets literature-ingest-online.sh (the web-discovery path). This task targets literature-ingest.sh (the local/Zotero PDF path). Different writers, no scope collision — coordinate on the shared metadata-quality goal, do not duplicate.
- Completed precedent for the anti-silence posture: the discover tier-starvation / silent-tier3-failure fix.

=== ACCEPTANCE CRITERIA ===

1. A document ingested via literature-ingest.sh is written to the global index in a shape literature-briefing.sh resolves, with correct title, authors, year, path, and chunk count.
2. All 16 existing stub entries resolve in a briefing, or are migrated to the canonical shape, with the rich/thin variant distinction handled explicitly rather than by accident.
3. get_doc_fidelity() returns a real fidelity value for migrated entries rather than the fail-open default.
4. The reader survey above is completed and each reader is either fixed or its exclusion documented as deliberate.
5. /literature --validate gains a schema-shape conformance check that fails on a divergent entry.
6. A regression test ingests (or fixtures) a document through the literature-ingest.sh path, registers it in a per-repo sub-index, runs literature-briefing-invoke.sh, and asserts the document appears in the briefing with correct title/authors/year/chunk count.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed .claude/** tree — it is a disposable deploy artifact regenerated from the source store, and hand-authored files there are silently wiped.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

=== PAIRED REGRESSION ASSERTION (companion task) ===

Acceptance criterion 6 above is the FIRST of a two-assertion regression requirement spanning this task and its companion coverage-marker task. This task owns assertion one: an ingested document appears in the briefing with correct title/authors/year/chunk count. The companion task owns assertion two: a deliberately-unresolvable doc_id drives the coverage marker to report the failure rather than reporting sparse=false. Both must exist for the defect class to be closed — assertion one alone leaves the silent-degradation half free to regress. Do not consider this task's test complete without confirming the companion assertion is scheduled.


=== UPDATED EVIDENCE (2026-08-24, second independent observation) ===

Re-observed from a different consumer repo (Logos/Theory) during a /research --lit run, after a
batch ingest of 25 verification sources through literature-ingest.sh --local. The defect
reproduces exactly as described above; three facts have CHANGED and one is NEW.

CHANGED -- the invisible population has more than doubled, 16 -> 38.

  jq '[.entries[] | select(.id == null)] | length'  ~/Projects/Literature/index.json  =>  38

The 22 added entries came from that single batch ingest, confirming the stub population grows
with ordinary use rather than being a fixed legacy residue. Migration scope in acceptance
criterion 2 should be read as "all currently-invisible entries", not the literal 16.

NEW -- the index holds THREE shapes, not two. This was not visible at 16 entries and it bears
directly on the rich/thin writer-provenance question above:

  | Shape                        | Count | Resolves in briefing? |
  |------------------------------|-------|-----------------------|
  | canonical, .id present       |  359  | yes                   |
  | BOTH .id and .doc_id present |   35  | yes (matches on .id)  |
  | .doc_id only, .id absent     |   38  | NO                    |

  Totals: 397 entries; 73 carry .doc_id, of which 35 also carry .id.

The 35 dual-keyed entries are the interesting ones: they resolve correctly today purely because
they happen to carry .id, so they are invisible as a problem while still carrying the stub key.
They look like the "RICH variant" the section above flags as unexplained -- a candidate answer to
the open provenance question is that the rich variant is a canonical entry that later acquired a
.doc_id (or a stub that was later enriched with .id), rather than a distinct writer. Research
should test that hypothesis directly before assuming two separate producers. Sample invisible
doc_ids skew to older philosophy/logic material (j_nsson_and_tarski_-_1951_...,
goldblatt_-_mathematical_modal_logic..., awodey_2016_univalence..., bacon_2019_substitution_structures),
while the 22 newly-added ones are the 2026-08-24 verification batch -- so the two cohorts have
different provenance and may migrate differently.

CONFIRMED -- writer/reader key mismatch, line numbers re-verified against the source store at
agent-system/extensions/literature/scripts/ (not the deployed tree):

  literature-ingest.sh:315   writes  "doc_id": "$DOC_ID"   (Step 4 python3 heredoc)
  literature-briefing.sh:175 reads   select(.id == $id and (.parent_doc == null or .parent_doc == ""))
  literature-briefing.sh:181 reads   select(.id == $id)                       (fallback path)
  literature-briefing.sh:114 reads   select(.id == $id) | .provenance_fidelity  (get_doc_fidelity)

CONSUMER-SIDE IMPACT (new, argues for priority)

In the observed run the briefing resolved SUBINDEX_PRESENT against a 37-entry sub-index and
emitted 24 consecutive "not found in global index -- skipping" warnings, returning only the 13
pre-existing entries -- i.e. exactly the sources the task did NOT need, while every source it did
need was skipped. The consuming research proceeded only because the operator noticed the warnings
and hand-routed agents to read specs/literature/<doc_id>/chunk_NNNN.md directly.

Measured cost of that workaround: of 25 relevant ingested sources, 7 went entirely uncited in the
resulting research round, including the corpus's single largest practical reference (658 chunks)
and both of the repo owner's own manuscripts, which bore directly on the round's central technical
claim. Silent corpus invisibility therefore does not merely degrade a briefing -- it measurably
changes which sources a research round draws on, and the failure is only caught if a human reads
stderr. This strengthens the case for the companion coverage-marker task's assertion two.

=== ADDENDUM 2026-08-24 (third observation, Logos/Theory): A FOURTH NAMESPACE, AND THE MIGRATION HALF IS ALREADY DONE ===

Three facts change the shape of this task. All were measured by execution against the live
system, not read from source.

(1) NEW BREAKAGE -- THE FTS DATABASE IS A FOURTH ID NAMESPACE, AND IT DISAGREES WITH THE INDEX.

This task enumerates .id, .doc_id and .zotero_key, plus three index FILES. It does not account for
~/Projects/Literature/.literature.db, table chunks_data, column doc_id -- the namespace that
literature-search.sh and its --toc and --read modes all key on. Measured:

    FTS distinct doc_id                                                204
    global-index parent .id (parent_doc null or empty)                 189
    present in both                                                    172
    FTS-only  (searchable; no parent entry -> invisible to briefing)     32
    index-only (in briefing; --toc and --read return nothing)            17

The divergences are systematic, not incidental. Sample pairs naming the same work:
    blackburn_2002                        (FTS)  vs  blackburn_2002_book                (index)
    courcoubetis_1992                     (FTS)  vs  courcoubetis_1992_memory_efficient (index)
    vardi_1996                            (FTS)  vs  vardi_1996_automata_ltl            (index)
    kupferman_vardi_2001_weak_alternating  -- index-only, no FTS chunks under that id

WHY THIS BEARS DIRECTLY ON SCOPE (b) AND ACCEPTANCE CRITERION 1: normalizing the writer to the
curated schema is safe ONLY IF the id it writes AGREES with chunks_data.doc_id. If normalization
renames ids to the curated long form, every renamed document keeps its briefing entry and LOSES
its search path. This was demonstrated by hand on 2026-08-24 while repairing two Logos/Theory
sub-index entries: renaming a sub-index doc_id from vardi_wolper_1986 to the curated
vardi_wolper_1986_automata_verification made the briefing resolve it AND made
`literature-search.sh --toc` return []. The defect was invisible to code reading and was caught
only by running the command. The repair that works is the opposite direction -- keep the bare id
that FTS already holds, and ADD a parent entry to the global index under that same id.

Note that the existing "ADDITIONAL AFFECTED READERS" bullet on literature-search.sh concerns the
hardcoded "sources/" PATH PREFIX, and asks only to "confirm FTS5 index coverage of stub docs" --
a coverage question. The namespace-AGREEMENT question is a different one and was never asked.
Its answer is 49 disagreeing documents.

NEW ACCEPTANCE CRITERION 7: the id under which a document is registered in the global index MUST
equal its chunks_data.doc_id in .literature.db. Add a check that compares the two sets and fails
on divergence -- the natural home is the /literature --validate schema-conformance check already
required by acceptance criterion 5. Migrating the search path in lockstep is an acceptable
alternative, but the choice must be made explicitly; do not leave the two namespaces to drift.

(2) THE MIGRATION HALF -- SCOPE (c) AND ACCEPTANCE CRITERION 2 -- IS ALREADY DONE, OUT OF BAND.

    jq '[.entries[] | select(.id == null)] | length'   =>   0        (was 16, then 38)
    total entries 399; 73 still carry .doc_id, and ALL of those also carry .id

Repaired by Literature repo commits 782ca166 ("migrate 17 ingest-schema records to the curated
schema") and a1e74586 ("consolidate all sources under sources/, repair 38 broken index entries").
The invisible population is now ZERO, and that repo's working tree is clean.

Consequence for scope: do NOT build a backfill for the existing population -- there is nothing
left to backfill. Re-measure at implementation time; if the count is still 0, acceptance
criterion 2 is satisfied by inspection and this task reduces to the WRITER defect plus the new
criterion 7. The writer is untouched and remains live -- literature-ingest.sh:315 still emits
"doc_id" -- so the next ingest recreates the class. That is now the whole of the live problem.

(3) PARENT/CHILD GRANULARITY IS AMBIGUOUS AND MUST BE DECIDED, NOT INHERITED.

The canonical shape described above says "separate child entries per chunk linked by parent_doc".
The corpus does not honour a single granularity. baier_katoen_2008 registers 12 PART children
(Baier_Katoen_2008_partNN.md, roughly 229 KB each) while FTS holds 1263 CHUNK rows for the same
document. The briefing therefore reports "12 chunk(s), ~590624 tokens" for a document that --toc
reports as 1263 chunks. Both reading paths function, but the count is meaningless and an agent
trusting "12 chunks" will attempt to Read a 229 KB file. Normalization must pick a granularity,
or carry both explicitly in distinct fields, rather than inheriting whichever the writer produced.

CORRECTION TO THE SECOND-OBSERVATION EVIDENCE ABOVE: the "7 of 25 uncited, including both of the
repo owner's manuscripts" measurement is now HISTORICAL. Both manuscripts
(brast-mckie_2026_construction-possible-worlds and brast-mckie_2026_counterfactual-worlds)
resolve today, and a Logos/Theory briefing run on 2026-08-24 resolved 37 of 37 sub-index entries
with zero skip warnings, after the two id repairs described in (1). The SHAPE of the defect is
unchanged and the writer is unfixed; only the data population was repaired.


=== ADDENDUM 2026-08-24 (fourth observation, Logos/Theory --team --lit run): READER SURVEY LIST EXTENDED, AND A DUPLICATE ABSORBED ===

A separate /research --team --lit round in Logos/Theory re-measured this defect and filed a
narrow companion task for the resolver-keying half. That companion is ABSORBED HERE and abandoned
rather than worked separately, since acceptance criterion 4 above ("the reader survey is completed
and each reader is either fixed or its exclusion documented as deliberate") already owns the work.
This is the second consuming-repo duplicate this task has absorbed; the first is the one named in
the "DUPLICATE FILED ELSEWHERE" note above.

WHAT THE ABSORBED TASK ADDS -- five readers NOT named in the "ADDITIONAL AFFECTED READERS" survey
above. That survey names literature-search.sh, literature-fidelity-audit.sh, and
zotero-attach-chunks.sh. Add these to the same survey and hold them to the same criterion:

    literature-discover.sh
    literature-normalize-authors.sh
    zotero-resolve-pdf.sh
    zotero-generate-export.sh
    test-lit-pipeline.sh

All five reference id / "id" and none has been inspected for the id-vs-path keying question.

CORRECTION TO A LIKELY ASSUMPTION -- literature-briefing.sh is NOT one of the offenders on this
axis. It already prefers path over an id-derived path at ~227-246:

    parent_path=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | .path // ""' ...)

falling back to $LIT_DIR/sources/$doc_id only when path is empty or dirname resolves to ".". Do
not "fix" it there; the keying defect, where it exists, is in the other readers.

SUPPORTING MEASUREMENT (consistent with point (3) above on parent/child granularity, and worth
keeping as the concrete number): of 399 global-index entries, all 399 carry a populated id, but
sources/<id>/ resolves as a directory for only 173. The path field resolves for all 399 -- it
points to a directory for whole-work entries and to a specific .md file for chapter-level entries
(e.g. blackburn_2002_ch00 -> sources/blackburn_2002/ch00_preface.md). Any resolver that
reconstructs a path as sources/<id>/ rather than reading path fails on 226 of 399 entries. This is
the same granularity ambiguity point (3) requires a decision on, observed from the reader side.

EXPLICIT DO-NOT-FIX, carried over from the absorbed task: only 73/399 entries carry a doc_id key
at all; the other 326 simply lack the key. That is the legacy partially-migrated field this task
already documents -- it is NOT missing data and NOT corruption. An earlier analysis in the
consuming repo wrongly flagged it as such and was corrected; do not re-open it as a defect.

---

### 76. Close task-type-keyed hook gap for non-latex agents that compile .tex
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 74

**Description**: Close the coverage gap that the latex-extension wiring cannot reach: agents that compile .tex files under a task type OTHER than `latex` currently get no build-guard protection at all, because the extension hook mechanism is keyed on task_type.

DEPENDS ON the core guard script task. This task is NOT redundant with the latex-extension wiring task -- it covers a disjoint set of dispatches, and skipping it would leave the exact incident that prompted this work uncovered.

THE GAP, VERIFIED PRECISELY. `skill_run_extension_hook()` in `agent-system/extensions/core/scripts/skill-base.sh` resolves which extension's hooks to run by calling `skill_get_extension_dir "$task_type"`, which maps a task type to `.claude/extensions/<ext_name>`. It then reads `.hooks[<stage>]` from THAT extension's manifest. Consequence: a preflight hook declared in the latex manifest fires if and only if `task_type == "latex"`. It never fires for any other task type. Additionally, when no extension matches the task type, `skill_get_extension_dir` returns empty and the function returns 0 immediately -- so core-typed tasks (`general`, `meta`, `markdown`) run NO lifecycle hooks whatsoever, from any extension.

WHY THIS MATTERS CONCRETELY. `agent-system/extensions/formal/manifest.json` routes ALL of `formal`, `formal:logic`, `formal:math`, and `formal:physics` implement operations to `skill-implementer` / `general-implementation-agent`. Philosophy and logic paper repositories are precisely where .tex files live, and `formal`-typed paper tasks are a normal, expected shape. The formal manifest declares NO top-level `hooks` object at all (verified: `.hooks` is null, `provides.scripts` is an empty array). So a `formal`-typed task that builds a .tex file receives zero protection from a latex-extension-only fix. The user flagged this explicitly: a latex-extension-only fix would not have covered the live incident that prompted this work. The same reasoning applies to `general`-typed tasks that happen to touch LaTeX.

DECISION TO MAKE -- WHERE THE UNCONDITIONAL PATH LIVES. Two structurally different options; choose one and record why:

  (i) AGENT-CONTRACT MANDATE. Add the guard obligation to `agent-system/extensions/core/agents/general-implementation-agent.md` and its twin `general-implementation-hard-agent.md`: before running any `pdflatex`/`latexmk` invocation, run the shared guard. Cheap, no harness change, and it composes with the "detect and refuse" mechanism (a contract can refuse; a non-blocking hook cannot). Weakness: it is instruction text an agent may skip, and it must be duplicated across the two twins.

  (ii) CORE-LEVEL UNCONDITIONAL CHECK. Add a task-type-independent guard invocation into `skill-base.sh` itself, running regardless of extension. Strongest coverage, and it survives agents ignoring instructions. Weaknesses: it touches the shared lifecycle spine that every skill in every repository depends on; it would run for every task type including ones that never touch LaTeX (mitigated if the guard is cheap and silent when no .tex conflict exists -- an explicit acceptance requirement of the core guard task); and, because hook/preflight failures are deliberately non-blocking, it still cannot ENFORCE a refusal on its own.

  A defensible outcome is BOTH: (ii) for detection and reporting, (i) for the refusal obligation. The user's framing invites exactly this ("the latex extension, a shared preflight hook, or both"). Do not silently pick the cheaper option without recording the tradeoff.

  A third possibility worth evaluating and rejecting explicitly: giving the formal extension its own preflight hook that delegates to the shared guard. This closes the `formal` case specifically but leaves `general`/`meta`/`markdown` uncovered and does not generalize -- it invites one hook per extension forever.

TWIN-FILE DISCIPLINE (binding). If option (i) is chosen, `general-implementation-agent.md` and `general-implementation-hard-agent.md` MUST be edited together in this task. A one-sided edit between engine twins is a known recurring defect class in this system. Do not assume the two files are line-symmetric; locate each site by content.

BLAST-RADIUS WARNING. If option (ii) is chosen, `skill-base.sh` is the shared lifecycle spine sourced by essentially every skill and deployed to roughly ten repositories. Changes there must be additive, must not alter existing hook ordering or the existing non-blocking semantics, and must be exercised against `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh`, which already covers the hook-invocation contract.

FILE-SCOPE NOTE. This task's scope includes `agent-system/extensions/core/scripts/skill-base.sh`, which falls under the `agent-system/extensions/core/scripts/**` scope of the prerequisite core-guard task. That overlap is already serialized by the declared dependency, so no additional ordering constraint is needed -- but the two tasks must not be run concurrently.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/core/**` (and `agent-system/extensions/formal/**` only if the rejected third option is nonetheless adopted). Never edit a deployed `.claude/**` tree.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: a task-type-independent path exists by which an agent about to compile a .tex file consults the shared guard, demonstrably covering `formal`-typed and `general`-typed tasks; the (i)/(ii)/both decision is recorded with reasons, and the rejected per-extension-hook option is explicitly rejected in writing; if agent contracts were edited, both twins carry equivalent obligations; if `skill-base.sh` was edited, the change is additive, preserves existing hook ordering and non-blocking semantics, and the lifecycle test suite passes; no `.claude/**` file is modified.

---

### 75. Wire build guard into latex extension preflight hook and agent contracts
- **Effort**: 2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 74

**Description**: Wire the shared LaTeX build guard into the latex extension's lifecycle and contracts, so that `latex`-typed research and implementation dispatches detect (and, per the chosen mechanism, stop) a competing vimtex continuous build before the agent runs its own.

DEPENDS ON the core guard script task: this task consumes the script and its chosen mechanism, and must not re-litigate the mechanism decision.

HOOK MECHANISM (verified). `skill_run_extension_hook()` in `agent-system/extensions/core/scripts/skill-base.sh` (lines ~89-126) dispatches four lifecycle stages -- preflight, context_injection, verification, postflight -- to a script named in the extension's manifest under a TOP-LEVEL `hooks` object. This is distinct from `provides.hooks`, which is a file-copy target list; do not confuse the two. The preflight hook is invoked from `skill_preflight_update()` (line ~225) AFTER the status update. Hooks are non-blocking by design: a non-zero exit is caught and downgraded to a `[skill-base] WARNING` line, and execution continues. THIS IS A REAL CONSTRAINT ON THIS TASK -- if the chosen mechanism is "detect and refuse", a preflight hook CANNOT enforce the refusal on its own, because the harness ignores its exit code. In that case the refusal must additionally be carried in the agent contract text (the agent declines to build), with the hook serving as the detector and reporter. Resolve this explicitly rather than assuming a non-zero exit will stop anything.

REFERENCE IMPLEMENTATION. `agent-system/extensions/nix/scripts/nix-preflight.sh` is the only existing preflight hook in the source store and shows the exact contract: five positional args (`task_number`, `task_type`, `task_dir`, `session_id`, `operation`), `set -euo pipefail`, warnings to stderr, and `exit 0` even when warnings fired. The nix manifest declares it as `"hooks": {"preflight": "scripts/nix-preflight.sh", "context_injection": "scripts/nix-context.sh"}`. Only two extensions (nix, nvim) declare top-level hooks today, so this is a lightly-trodden path -- read both before writing.

DELIVERABLES.
  1. A new `agent-system/extensions/latex/scripts/` directory (it does NOT exist yet -- latex's `provides.scripts` is currently an empty array) containing a preflight hook that calls the shared core guard. The hook should be a thin adapter, not a reimplementation.
  2. `agent-system/extensions/latex/manifest.json`: add the top-level `hooks` object (preflight, and postflight if the restore/report decision requires it), and add the new script(s) to `provides.scripts`. Note the manifest currently has `"hooks": []` nested inside `provides` -- the new object is a SIBLING of `provides`, not a replacement for that field.
  3. `agent-system/extensions/latex/agents/latex-implementation-agent.md`: the build guidance is concentrated at lines ~38-62 ("Build Tools (via Bash)", listing `pdflatex`, `latexmk -pdf`, `latexmk -c`, with worked multi-pass examples) and recurs at lines ~97, ~134, and ~175 as bare build instructions. Line numbers verified at task-creation time and may drift; locate by content. Add the guard obligation, and add a MUST NOT item against running a build without first invoking the guard -- MUST NOT is the strongest lever these contracts have, and advisory prose buried mid-file is what gets skipped.
  4. `agent-system/extensions/latex/rules/latex.md`: the build-command block at lines ~74-93 presents `pdflatex`/`latexmk -pdf` with no concurrency caveat. Point it at the guard.
  5. `agent-system/extensions/latex/context/project/latex/tools/compilation-guide.md`: add a build-coordination section. This file already has "Automated Build", "Using latexmk", and ".latexmkrc Configuration" sections (lines ~46-60) that discuss latexmk without mentioning the watcher conflict, so it is the natural anchor. Per this extension's convention, put the explanatory prose HERE ONCE and have the agent/rules files reference it by path rather than restating it.

NO -HARD TWIN. Unlike the lean extension, latex declares no `routing_hard`/`routing_agents_hard` block and has no `-hard` agent variants, so there is no twin-file discipline burden here. `latex-research-agent.md` is a lighter touch -- research dispatches rarely build, but should not be silently exempt if the hook is manifest-level (the hook fires for ALL latex-typed operations, research included, since `operation` is only passed as an argument, not filtered on). Decide whether the hook self-filters on the `operation` argument.

SCOPE BOUNDARY. This task covers `latex`-TYPED tasks only. Coverage for agents that build .tex files under other task types is a separate task and must not be absorbed here.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/latex/**`. Never edit a deployed `.claude/**` tree.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: a latex preflight hook exists, is executable, is declared in the manifest's top-level `hooks` object, and is listed in `provides.scripts`; it delegates to the shared core guard rather than duplicating detection logic; the agent, rules, and compilation-guide files carry the obligation with prose stated once in compilation-guide.md and referenced elsewhere; the non-blocking-hook constraint is explicitly resolved (either the mechanism does not need enforcement, or the enforcement is carried in contract text); the operation-filtering decision is recorded; no `.claude/**` file is modified.

---

### 74. Add shared LaTeX build-conflict guard script (detect competing vimtex latexmk -pvc)
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Build a shared, task-type-agnostic guard script that detects a user-owned LaTeX continuous-build watcher (`latexmk -pvc`, typically driven by nvim's vimtex plugin) competing for the same .tex target an agent is about to build, and that can report, stop, and restore it. This task delivers the MECHANISM only; wiring it into lifecycle stages is handled by the two dependent tasks.

PROBLEM (observed live, not hypothetical). An agent ran `latexmk -pdf possible_worlds.tex` in a paper repo while the user's nvim vimtex continuous-mode compile was watching the same file. The two builds raced and corrupted aux files (null bytes, `^^@`). The failure mode is already documented in that repo's own CLAUDE.md under "Build Workflow: Preventing Aux File Corruption" -- but that documentation instructs a HUMAN to run `:VimtexStop` by hand. Nothing in the agent system detects, prevents, or even warns about it, so the user must notice and intervene manually every time an agent begins LaTeX work.

WHY THE EXISTING DEBOUNCE DOES NOT COVER THIS. The paper repo carries a `.latexmkrc` with `$sleep_time = 5` and a `$compiling_cmd` that pre-scans `build/*.aux` for null bytes and unlinks corrupted files. NOTE TWO CORRECTIONS TO THE ORIGINATING PROMPT, both verified at task-creation time: the file is at `JPL/.latexmkrc`, NOT the repo root; and the value is `$sleep_time = 5`, NOT the `2` that repo's CLAUDE.md claims (that CLAUDE.md is stale on this point -- do not propagate the wrong number). More importantly, `$sleep_time` debounces the file watcher WITHIN a single latexmk instance. It provides no coordination whatsoever between two SEPARATE latexmk processes, which is precisely the race here. The `$compiling_cmd` null-byte sweep is a post-hoc corruption cleanup, not prevention. Neither existing mechanism can solve this; a new one is required.

MECHANISM DECISION -- THIS IS THE CORE RESEARCH QUESTION. An agent cannot invoke a Vim command directly, so the shutdown path is non-obvious. Three candidates, to be evaluated and one (or a documented layering) chosen:

  (a) PROCESS TERMINATION. Detect a running `latexmk -pvc` whose target resolves to the .tex file about to be built, and SIGTERM it. Most reliable, most destructive -- it kills a process the user owns, and vimtex's own state will not know its child died, potentially leaving the plugin's status display stale or its callback machinery confused.

  (b) EDITOR REMOTE CONTROL. Use `nvim --server <socket> --remote-expr` (or `--remote-send`) against the live nvim instance to invoke VimtexStop. VERIFIED FEASIBLE IN THIS ENVIRONMENT: four live sockets were present at task-creation time under `/run/user/1000/` in the form `nvim.<PID>.0` (XDG_RUNTIME_DIR). This is the only option that leaves vimtex's internal state consistent, because vimtex itself performs the stop. Costs: it requires mapping socket -> the nvim instance that actually owns the target buffer (a socket exists per nvim instance, and most of them will be unrelated); `--remote-expr` executes arbitrary expressions in the user's editor, which is a real side effect deserving explicit justification; and it depends on vimtex being loaded in that instance.

  (c) DETECT AND REFUSE. Detect the conflict and emit a clear, actionable message -- naming the PID, the target file, and the exact `:VimtexStop` remedy -- then either warn-and-continue or refuse to build. Zero side effects on user-owned processes and zero remote editor control. The user's explicit steer is to PREFER THE LEAST DESTRUCTIVE OPTION THAT RELIABLY PREVENTS THE RACE, and to weigh killing a user process or driving their editor remotely against simply refusing with a clear message. Research should take that steer seriously rather than defaulting to (a) because it is easiest to implement. A defensible outcome is (b) with (c) as fallback when no owning socket can be identified, or (c) alone.

RESTORE-VS-REPORT DECISION. Also decide whether the agent restores continuous mode on exit or merely reports that it stopped it. The user's stated position: an agent that silently leaves the user's watch mode off is its own (smaller) annoyance. At minimum, whatever is stopped must be REPORTED. Restoration is materially easier under mechanism (b) (re-invoke VimtexCompile over the same socket) than under (a) (the script would have to reconstruct and relaunch a latexmk invocation it did not create -- generally a bad idea). Note that this decision is coupled to the mechanism decision and should not be made independently of it.

REUSABLE PATTERN -- `agent-system/extensions/core/scripts/claude-refresh.sh`. That script already solves the hard parts of safe process handling and should be read before writing anything new. It takes a single atomic `ps -eo` snapshot per invocation rather than re-querying live; it applies exclusion regexes so the script can never target itself or its own ancestry; it gates destructive action behind an explicit `--force` (the calling skill handles confirmation separately); and it escalates SIGTERM (`kill -15`) -> liveness recheck (`kill -0`) -> SIGKILL (`kill -9`) rather than killing outright.

SELF-MATCH HAZARD (verified concretely, do not skip). During task creation, a plain `pgrep -af latexmk` returned exactly one "match" -- the task-creating agent's OWN bash wrapper command, whose argv merely CONTAINED the string `latexmk`. A naive detector would therefore report a phantom conflict, and under mechanism (a) would attempt to kill the agent's own shell. Detection must match on the actual executable and its `-pvc` flag, resolve the build target, and exclude self/ancestry, exactly as claude-refresh.sh does. This is not a theoretical edge case; it fired on the first probe.

DELIVERABLE. A new executable script under `agent-system/extensions/core/scripts/` (suggested name `latex-build-guard.sh`; final name to be fixed during planning). Placement in CORE, not in the latex extension, is DELIBERATE and load-bearing: the two dependent tasks show that non-latex-typed tasks also run LaTeX builds, so the mechanism cannot live behind the latex extension's task-type gate. Suggested subcommand shape (refine during planning): a `detect` mode that reports conflicts and exits non-zero, a `stop` mode implementing the chosen mechanism, and a `restore`/`report` mode for the exit path. Modes should be separable so callers can adopt detect-only first.

The script must be registered in `agent-system/extensions/core/manifest.json` under `provides.scripts` alongside the ~124 existing entries so it is deployed.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/core/**`. Never edit a deployed `.claude/**` tree -- those are disposable artifacts regenerated on reload, so such an edit silently vanishes.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: the script exists, is executable, and is registered in core's `provides.scripts`; the chosen mechanism is implemented and the rejected candidates are recorded WITH REASONS in the task's artifacts; detection correctly distinguishes a real `latexmk -pvc` on the target .tex from a process whose argv merely contains the string, and never matches itself or its own ancestry; the restore-vs-report decision is recorded and implemented; whatever the script stops is always reported to the user; the script is safe and silent (exit 0, no output) when no conflict exists, since it will run on every applicable build.

---

### 73. Correlate subagent postflight hook to marker owning session
- **Effort**: 3h
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: team-mode-lifecycle
- **Dependencies**: None

**Description**: The SubagentStop postflight hook picks an arbitrary .postflight-pending marker with no correlation to the session that owns it. In a team run, teammate stops burn the orchestrator's continuation budget and can delete the orchestrator's marker mid-run, silently removing the premature-termination guard.

VERIFIED MECHANISM (do not re-derive), file agent-system/extensions/core/hooks/subagent-postflight.sh:
- find_marker() runs `find specs -maxdepth 3 -name ".postflight-pending" -type f 2>/dev/null | head -1`. It takes the FIRST marker found anywhere under specs/, with no correlation to which session or agent is stopping. The marker's own JSON carries a session_id field (written by skill_create_postflight_marker in agent-system/extensions/core/scripts/skill-base.sh) which the hook never reads.
- The hook is registered as a SubagentStop hook (agent-system/extensions/core/root-files/settings.json), so it fires when ANY subagent stops, including a teammate spawned by a team skill, which has no postflight obligation of its own.
- check_loop_guard() increments $TASK_DIR/.postflight-loop-guard on every such firing. MAX_CONTINUATIONS=3. On reaching the cap it executes `rm -f "$LOOP_GUARD_FILE"; rm -f "$MARKER_FILE"` and allows the stop.

CONSEQUENCE: in a team run, each teammate stop burns one continuation from the ORCHESTRATOR's budget for a marker the teammate does not own. With team_size=4 the cap is reached by teammate stops alone, and the hook then DELETES the orchestrator's .postflight-pending marker. The premature-termination guard is removed without postflight having run.

OBSERVED (live team run, skill-team-research, 4 teammates): a teammate reported the loop guard had reached 3 (MAX_CONTINUATIONS) purely from its own stop attempts, and warned the orchestrator its marker was about to be deleted. In that instance the orchestrator's postflight had already completed so nothing was lost, but that was timing luck, not design. Had synthesis taken longer, the marker would have been deleted mid-run.

THE FAILURE IS SILENT AND LEAVES NO DISTINGUISHING TRACE: skill_cleanup's normal path also removes the marker, so after the fact there is no way to tell a hook-deleted marker from a properly-completed one.

WORK: correlate the hook to the marker it is actually responsible for. Directions to evaluate, do not pre-commit:
(a) read session_id out of the marker JSON and compare against the stopping subagent's session before counting or deleting anything;
(b) have team skills suppress or scope this hook for teammate subagents;
(c) make the loop guard per-session rather than per-task-directory so a teammate's stops cannot consume the orchestrator's budget;
(d) distinguish "cap reached" from "postflight done" so the silent-deletion path is at minimum observable. log_debug already writes .agent-logs/subagent-postflight.log; decide whether that is sufficient or whether the deletion should record a system defect.

ALSO REQUIRED: reconsider whether `head -1` over a repo-wide glob is ever correct. With concurrent tasks in flight there can be several markers and the hook currently picks an arbitrary one, so the defect is not confined to team mode.

RELATED BUT DISTINCT: task 17 fix_return_meta_lifecycle_ordering (COMPLETED) touched skill_cleanup's deletion of .postflight-pending / .postflight-loop-guard / .return-meta.json, but addressed the ordering of the return-metadata read, not marker ownership or hook correlation.

FILE-SCOPE OVERLAP: this task and the teammate return-meta write-conflict task both touch the three skill-team-* SKILL.md files. Sequence them rather than running them concurrently.

ACCEPTANCE: a teammate subagent stopping during a team run does not increment the orchestrator's loop-guard counter and cannot delete a marker it does not own; a genuine cap-reached deletion is distinguishable in the log (or by whatever mechanism is chosen) from a normal skill_cleanup removal; marker selection is correlated rather than `head -1` arbitrary when multiple markers exist.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 72. Fix teammate return-meta write conflict in team mode
- **Effort**: 4h
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: team-mode-lifecycle
- **Dependencies**: None

**Description**: Teammate agents spawned by team-mode skills write the skill-level .return-meta.json, clobbering the record the team skill is supposed to own. The surviving record is an arbitrary teammate's, is the wrong shape for a skill-level return, and can publish a terminal status while the operation is still running.

VERIFIED MECHANISM (do not re-derive):
skill-team-research/SKILL.md Stage 11 specifies that THE SKILL writes a single specs/{NNN}_{SLUG}/.return-meta.json for the whole team run, carrying the team_execution block (teammates_spawned/completed/failed), teammate_results, and synthesis conflict counts. A teammate's only deliverable is reports/{RR}_teammate-{letter}-findings.md, which the skill collects by glob. Teammates have no postflight step and are not supposed to write .return-meta.json at all.

But 63 agent definition files under agent-system/extensions/*/agents/*.md instruct writing specs/{NNN}_{SLUG}/.return-meta.json unconditionally. Confirmed example: agent-system/extensions/formal/agents/math-research-agent.md line 131 ("Write initial metadata to `specs/{NNN}_{SLUG}/.return-meta.json`") and line 326 ("Always write final metadata to ..."). Only 8 of those 63 agent files mention team mode at all (grep for team_mode|teammate_letter|skill-team), and math-research-agent is not among them. There is no team-mode carve-out anywhere in the agent definitions.

OBSERVED (live team run, skill-team-research, 4 teammates): a teammate spawned as math-research-agent wrote .return-meta.json TWICE. Mid-run the file read {"status":"researching","metadata":{"teammate":"b"}}; its second write replaced it with {"status":"researched", artifacts:[its own findings .md], next_steps:"Synthesis with teammate A findings", metadata:{agent_type:"math-research-agent","teammate":"b","findings_count":13}}. That is a single teammate's record occupying the slot reserved for the whole operation's return.

IMPACT:
(a) With N teammates racing, last-writer-wins and the surviving record is an arbitrary teammate's, not the team's.
(b) The shape is wrong for a skill-level return (no team_execution block), so the command-gate-out.sh consumer reads a well-formed but semantically false record.
(c) A teammate finishing before its siblings publishes status "researched" while the operation is still running. If the orchestrator or gate-out read it at that moment it would report the operation complete early. In the observed run the orchestrator overwrote it wholesale at postflight so no damage persisted, but that depended on the orchestrator noticing.

SECOND SYMPTOM, SAME ROOT CAUSE: a teammate spawned as formal-research-agent avoided the collision by inventing its own path .return-meta-teammate-d.json and committing it. That is a non-schema file no consumer reads. Two teammates given the same instruction chose two different wrong behaviors, which indicates the instruction is genuinely ambiguous under team mode rather than simply ignored.

WORK: decide ONE direction and apply it uniformly. Candidate directions to evaluate, do not pre-commit:
(a) add an explicit team-mode carve-out to the shared agent-definition boilerplate so a teammate writes only its findings file;
(b) give teammates a per-teammate metadata path the skill actually reads and merges (this would also make .return-meta-teammate-{letter}.json legitimate rather than stray, and must then be reconciled with the placement question owned by task 51 move_session_state_files_out_of_specs_root);
(c) have skill-team-* pass an explicit "you are a teammate, do not write .return-meta.json" instruction in every teammate prompt, and treat the agent-definition instruction as conditional on its absence.

UNIFORMITY REQUIREMENT: whatever is chosen must hold for all three team skills (skill-team-research, skill-team-plan, skill-team-implement) and for ANY agent type that can be spawned as a teammate. Team skills spawn arbitrary domain agents, so a fix touching only the core research agents is not acceptable. Also decide explicitly whether the .return-meta-teammate-{letter}.json convention is adopted or prohibited.

RELATED BUT DISTINCT:
- Task 17 fix_return_meta_lifecycle_ordering (COMPLETED) covers a different mechanism: skill_cleanup deleting .return-meta.json before command-gate-out.sh reads it. That is an ordering defect in the single-agent lifecycle; this is a write-conflict defect among concurrent teammates. Fixing 17 does not address this.
- Task 51 move_session_state_files_out_of_specs_root (NOT STARTED) covers .return-meta-*.json file PLACEMENT clutter in the specs/ root, not the write conflict. If direction (b) is chosen, coordinate with 51 on where per-teammate files live.

ACCEPTANCE: in a team run of each of the three team skills, the task directory ends with exactly one skill-owned .return-meta.json carrying the team_execution block; no teammate has overwritten it; no stray per-teammate metadata file exists unless the chosen direction deliberately defines one and a consumer reads it.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 71. Fix validate-mode directory-path false positives and normalize-authors flag mismatch
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 69
- **Research**: [071_fix_validate_directory_path_false_positives_and_flag_mismatch/reports/01_validate-false-positives-flag-mismatch.md]
- **Plan**: [071_fix_validate_directory_path_false_positives_and_flag_mismatch/plans/01_validate-dirpath-flag-fix.md]
- **Summary**: [071_fix_validate_directory_path_false_positives_and_flag_mismatch/summaries/01_validate-dirpath-flag-fix-summary.md]

**Description**: LOW severity -- validate-mode false positives and a documentation/CLI mismatch. Verified during a real /literature --validate run.

DEFECT 1 -- DIRECTORY-PATH FALSE POSITIVES. skill-literature validate mode tests entry paths with `[ ! -f "$full" ]`, which fails for the directory-path schema variant used by book/parent-level entries (paths ending in '/', e.g. `sources/blackburn_2002/`). Result: 65 of 368 entries were reported stale when ALL 65 exist on disk as directories and ZERO files are genuinely missing -- the check is 100% false positive and therefore useless as a signal. FIX: branch on -d for directory paths.

ADJACENT FINDING A -- TOKEN-DRIFT BASELINE. The same validate run reported 56 token-drift warnings, of which roughly 52 are systematic: 55 of 56 drift the same direction (actual > stored) and 40+ cluster in a tight 1.21-1.35 ratio band, indicating a changed token formula or a bulk re-conversion rather than real per-document drift. Consider re-baselining stored token_count values so the drift check becomes a meaningful signal.

ADJACENT FINDING B -- FOUR GENUINELY REAL DRIFT ENTRIES, flag for separate follow-up. Most important: `sources/diamondsareforever/chunk_0001.md`, whose index entry claims token_count 95000 while `path` points at a single 903-byte chunk containing only the abstract; it also mixes the legacy absolute-path `chunks_dir` schema into the `path` schema and carries provenance_fidelity 'unverified_no_baseline'. Any --lit consumer budgeting on token_count would reserve 95k tokens for an abstract fragment, or read `path` and receive 1/56th of the paper while believing it had the whole thing. The other three: `sources/fine_2012_guide-to-ground` (521 stored vs 27134 actual), `sources/vardi_wolper_1986/...` (196 vs 11871), and `sources/fine_2012_counterfactuals-without-possible-worlds` (2222 vs 15982) -- all three look like counts recorded against stub extracts that were later properly converted.

DEFECT 2 -- FLAG MISMATCH. skills/skill-literature/SKILL.md instructs users to run literature-normalize-authors.sh with '--dry-run (default) first', but the script rejects --dry-run as 'Unknown argument' -- dry-run is the bare no-flag default. FIX: correct the doc, or accept --dry-run as a no-op alias.

INFORMATIONAL, NOT A DEFECT: literature-normalize-authors.sh correctly proposes normalizing 60 entries whose `authors` field is a comma-joined string rather than an array. Zero array-valued entries have comma-joined elements, so the malformed-array regression that the validate authors-shape check guards against has NOT reappeared.

DEPENDENCY RATIONALE -- sequenced after task 69 (conversion quality gate hardening). Two couplings: (a) validate mode in skills/skill-literature/SKILL.md already special-cases `.md.rejected` quarantine artifacts, and task 69 changes which conversions produce them, so the validate branch should be fixed against the post-69 rejection behavior; (b) Adjacent Finding A (token-count re-baselining) and Finding B (stub-extract token counts) would be invalidated by any re-conversion pass that task 69 stricter gate forces, so re-baselining before 69 lands would have to be redone. Task 70 is independent of both and can run in parallel.

Primary files: agent-system/extensions/literature/skills/skill-literature/SKILL.md, agent-system/extensions/literature/scripts/literature-normalize-authors.sh. Per .claude/rules/source-store-deploy-boundary.md all edits target agent-system/extensions/literature/**, never .claude/**.

---

### 70. Fix literature-discover.sh tier starvation and silent Tier 3 failure
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [070_fix_discover_tier_starvation_and_silent_tier3_failure/reports/01_fix-discover-tier-starvation.md]
- **Plan**: [070_fix_discover_tier_starvation_and_silent_tier3_failure/plans/01_fix-discover-tier-starvation.md]
- **Summary**: [070_fix_discover_tier_starvation_and_silent_tier3_failure/summaries/01_fix-discover-tier-starvation-summary.md]

**Description**: MEDIUM severity -- discovery correctness. Two verified defects in scripts/literature-discover.sh, plus one query-construction issue.

DEFECT 1 -- TIER 3 FAILS SILENTLY. Semantic Scholar returned HTTP 429 and the script discards Tier 3 stderr (invoked as `tier3_search 2>/dev/null || true`), so a rate-limited run is indistinguishable from 'nothing found online'. This is exactly the silent-zero-result failure mode that the Zotero branch of commands/literature.md has elaborate machinery to prevent (ZOTERO_EXPORT_STALE and friends); Tier 3 has no equivalent. FIX: emit a visible directive/rationale notice on non-200 responses, mirroring the existing zotero-export-status.sh directive-on-stdout + rationale-on-stderr pattern.

DEFECT 2 -- TIER 1 STARVES TIERS 2 AND 3. With the default DISCOVER_LIMIT=10, a task-description query filled all 10 slots from the local corpus; tier3_search then early-returned on its `current_count >= DISCOVER_LIMIT` guard, and the final `jq '.[0:$limit]'` truncation discarded the Tier 2 hits that had been appended after Tier 1's. REAL CONSEQUENCE: Jonsson & Tarski 1951 and 1952 were sitting in the user's own Zotero library the entire time and never surfaced under the task-scoped discovery run; they appeared only when re-run as a focused query with DISCOVER_LIMIT=60. FIX DIRECTION: per-tier quotas or reserved slots so every tier contributes, instead of first-tier-wins.

ALSO IN SCOPE -- NOISY QUERY CONSTRUCTION. Building the query from a full multi-paragraph task description produces very noisy terms: the same run surfaced Buchi complementation and CTL axiomatization papers as top hits merely because the description mentions temporal operators.

Primary files: agent-system/extensions/literature/scripts/literature-discover.sh, agent-system/extensions/literature/commands/literature.md. Reference pattern: agent-system/extensions/literature/scripts/zotero-export-status.sh. Per .claude/rules/source-store-deploy-boundary.md all edits target agent-system/extensions/literature/**, never .claude/**.

---

### 69. Harden literature conversion quality gate against mojibake and unextractable-PDF output
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [069_harden_conversion_quality_gate_against_mojibake/reports/01_harden-quality-gate-against-mojibake.md]
- **Plan**: [069_harden_conversion_quality_gate_against_mojibake/plans/01_harden-quality-gate-against-mojibake.md]
- **Summary**: [069_harden_conversion_quality_gate_against_mojibake/calibration-notes.md]

**Description**: HIGH severity -- corpus-corruption vector. The conversion quality gate in scripts/literature-convert.sh does not detect control-character/mojibake output, allowing garbage to enter the global corpus and the FTS index.

EVIDENCE (verified empirically during a real /literature session, not speculation): Gabbay/Kurucz et al. 2003 'Many-Dimensional Modal Logics' (742pp) has a broken/custom font encoding with no usable ToUnicode CMap. The pymupdf4llm tier was CORRECTLY rejected by the gate (sentence-boundary-glue: 4 transitions vs threshold 3). But forcing LITERATURE_CONVERTER=pymupdf produced 2260 chunks of raw glyph indices and control characters -- 4824 NUL bytes, word_ratio 2.761 vs pdftotext (inflated precisely BECAUSE garbage tokens split on whitespace) -- and this output PASSED the gate, reporting 'Files quality-gate-failed: 0'. The garbage was ingested into the global corpus and FTS index and had to be manually removed with an index rebuild.

INDEPENDENT CORROBORATION that the PDF, not the converter, is at fault: pdftotext on the same PDF yields only 69.5% printable characters with visibly scrambled letters.

FIX DIRECTION: add to the gate (a) a printable-character-ratio check, (b) a control-character / NUL-byte check, and (c) a word_ratio sanity BAND rather than a one-sided floor -- flag ratios far ABOVE ~1.0 as well as far below, since the existing thinking only guards the low side and the observed corruption manifested as an inflated ratio of 2.761. Goal: an unextractable PDF must fail on EVERY tier rather than passing on the fallback tier.

CRITICAL CONSTRAINT FOR THE IMPLEMENTER -- DO NOT DISABLE THE FALLBACK TIER. The pymupdf fallback is legitimately useful and must be preserved. In the same session it rescued Goldblatt 2006 'Mathematical modal logic: A view of its evolution', which pymupdf4llm rejected but which converted cleanly under LITERATURE_CONVERTER=pymupdf (verified: word_ratio 0.979 vs pdftotext across 98 pages, symbols and footnotes preserved, and every apparent fusion artifact traced to either the running head 'Robert Goldblatt' or a URL). The objective is to catch garbage, not to remove the fallback path.

Primary files: agent-system/extensions/literature/scripts/literature-convert.sh, agent-system/extensions/literature/scripts/literature-ingest.sh. Per .claude/rules/source-store-deploy-boundary.md all edits target agent-system/extensions/literature/**, never .claude/**.

---

### 68. Make the /orchestrate blocked verdict discriminating: dispatch a task blocked on an in-batch predecessor instead of skipping it forever
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: None

**Description**: Make the multi-task /orchestrate classifier's `blocked` row DISCRIMINATING rather than unconditional, so a task blocked on a predecessor the same batch is going to complete becomes dispatchable instead of being skipped on every cycle until MAX_CYCLES_MT is exhausted.

=== OBSERVED DEFECT ===

In multi-task mode a task with status `blocked` routes to the `skip` group unconditionally, with no consideration of WHAT it is blocked on. When the blocker is an in-batch predecessor, skipping defeats the entire purpose of submitting the chain as one batch: the predecessor completes, the successor is still `blocked`, NOTHING REWRITES THAT STATUS, and the successor is skipped again every subsequent cycle. The missing status rewrite is the core gap -- a status no component ever rewrites is why the skip repeats forever rather than resolving.

=== LIVE REPRODUCTION (measured in a deploy repo, `/orchestrate 437,436,434,433`) ===

- The chain was 437 -> 436 -> 434 -> 433, strictly serial by `dependencies[]`, correctly computed into four waves by Kahn's algorithm.
- The second task was `blocked` on the first; the third was `blocked` on the second. Both markers were set by `/spawn` at the moment each task spawned its own unblocker -- i.e. blocked ON AN IN-BATCH PREDECESSOR, the exact case this defect concerns.
- Both tasks' `.orchestrator-handoff.json` recorded `blockers: []` -- ZERO recorded blockers. The `blocked` status was pure dependency-ordering information, fully duplicated by the `dependencies[]` edge the wave scheduler had already consumed.
- Result: even after unrelated admission problems cleared, the batch would have dispatched the first task and then idled, skipping the rest every cycle. The operator had to hand-edit both statuses to `partial` via `state-write.sh` to make the chain runnable.

=== MEASURED SOURCE-STORE STATE (re-measure before relying on line numbers) ===

`scripts/orchestrate-triage-classify.sh` is the executable source of truth.
- Its `elif $status == "blocked"` arm (around line 311) emits group `skip` for engine `mt`, `needs_human` for engine `single`, with reason string "task #N is blocked; mt skips / single needs human".
- Its header verdict table (around line 63) carries the row `| blocked | skip | needs_human |`, and lines ~77-85 carry an explicit justification calling this divergence "a DESIGN, not an oversight", with a stated discriminator for future audits: "does the OTHER engine's own handler implement the divergence in its own code, or does only this shared table assert it? Independent implementation by both sides = design (keep it, documented); bare assertion by one shared table = defect (converge it)." That discriminator must be applied honestly to this change rather than quoted as a reason not to touch the row -- the defect here is not the ENGINE DIVERGENCE, it is the UNCONDITIONALITY of the mt side.

TWO FACTS THAT MAKE THE FIX TRACTABLE, BOTH VERIFIED BY DIRECT READ:
1. The classifier's CLI is `orchestrate-triage-classify.sh <engine> <task_number> [<task_number> ...]` -- it ALREADY RECEIVES THE FULL CANDIDATE LIST. Batch membership is therefore computable inside the classifier without a new argument or a call-site change.
2. The classifier already reads `specs/state.json` (hence `dependencies[]`) and, for `partial`-status candidates only, that candidate's own `.orchestrator-handoff.json`. Both discriminator signals are already within its declared read set; extending the handoff read to `blocked` candidates is a scope widening of an existing read, not a new I/O class. Respect the Context Flatness Constraint in its header: never read a plan, report, or summary.

HARD CONSTRAINT ON WHERE THE REWRITE CAN LIVE: the classifier header declares the script READ-ONLY and enumerates forbidden calls (`task-lock.sh acquire`, `update-task-status.sh`, `generate-todo.sh`, `skill-base.sh` write functions, `reconcile-task-status.sh` without `--dry-run`, and any dispatch of the Agent or Skill tool). So the classifier MAY decide the verdict but MUST NOT perform any status rewrite. Either the verdict alone suffices (route the discriminated row to its real phase group and let the normal dispatch path proceed, leaving the stale `blocked` string to be corrected by the dispatch's own preflight), or a separate component performs the rewrite. Research must pick one and name the component.

=== CO-MAINTENANCE SET (all must agree; verify by grep, do not trust this list) ===

- `scripts/orchestrate-triage-classify.sh` -- the jq arm AND the header verdict table AND the adjacent justification prose. All three, or the file self-contradicts.
- `skills/skill-orchestrate/SKILL.md` -- Stage MT-4's phase-grouping table (around line 2030) folds `blocked` into `skip`, with a divergence justification at ~2039-2043 and a related note at ~528. Stage MT-3 step 3's eligibility rule does NOT exclude `blocked`, so these tasks are ELIGIBLE-BUT-SKIPPED -- that combination is precisely what makes them spin rather than terminate, and it is the mechanism to keep in view when reasoning about convergence. The single-task engine's `#### State: blocked` handler (around line 658) reads blockers from state.json (not the handoff) and escalates to a human via Stage 6.
- `skills/skill-orchestrate-hard/SKILL.md` -- has its OWN compressed `#### State: blocked` handler (around line 1037: "Read blockers from state.json. Invoke blocker escalation (Stage 6)"), but its Multi-Task Mode section (from ~line 1539) is a bare "Same as base" pointer that transcribed only two mechanisms (the admission gate and the redeploy checkpoint) and has NO phase-grouping table. So determine, and record, whether it needs its own edit or genuinely inherits -- note its own stated rationale (~1544-1551) that bare pointers demonstrably fail to carry mechanisms forward.
- `scripts/tests/test-orchestrate-triage-classify.sh` -- already carries `fixture_blocked` (around line 219) and two assertions (~263-265) that name the current rows as "DOCUMENTED DIVERGENCE ... not a bug" and instruct the reader NOT to "fix" them. These fixtures WILL need rewriting, and the instruction comment must be rewritten with them so the suite does not preserve a claim the code no longer makes.
- `scripts/orchestrate-dry-run-report.sh` -- the read-only consumer of classifier verdicts; a dry-run's entire value is being a prediction of the live path, so any new verdict field or reason string must surface there.
- `context/patterns/batch-orchestration-guardrails.md` -- carries the NORMATIVE principle (around lines 100-119) that every gate "should degrade to an ORDERING CONSTRAINT ... and fall back to a genuine EXCLUSION" only when justified, with a per-gate table classifying each. The `blocked` status verdict is not currently a row in that table because it is a triage verdict rather than an admission gate; decide explicitly whether it becomes one, and whether the principle as stated already implies this fix.
- `docs/architecture/orchestrate-state-machine.md` -- line ~31's state table row for `blocked`, and line ~434's "No eligible tasks | partial | Deadlock or all blocked" outcome row.

=== PRIOR ART: THIS ROW WAS DELIBERATELY SCOPED OUT BY EARLIER WORK ===

The completed task `orchestrate_eligibility_not_status_gated` is the closest prior art and deliberately did NOT cover this. Its plan states: "The `blocked` and `unknown` classifier rows -- left unchanged per research Decision 3", and it explicitly preserved the blocked row as "the one documented engine-divergent row". That work fixed the ADJACENT `researching`/`planning` strandedness under the principle that "every admission gate degrades to an ORDERING CONSTRAINT and never to a PERMANENT EXCLUSION". This defect is the SAME PRINCIPLE applied to a row that earlier work scoped out. Research MUST locate that Decision 3 in `specs/067_orchestrate_eligibility_not_status_gated/reports/` and either OVERTURN IT WITH REASONS or NARROW IT -- silently contradicting it is not acceptable, and neither is citing it as a reason to do nothing.

=== DESIGN DIRECTION TO EVALUATE (decide; do not presuppose) ===

The plausible fix is to make the blocked row discriminating: distinguish a task blocked on a predecessor IN THE CURRENT BATCH (an ordering constraint the batch itself will discharge -- should become dispatchable once the predecessor terminates) from a task blocked on something the batch CANNOT resolve (a genuine external blocker -- skip or escalate as today). Points research must settle rather than assume:

1. WHICH DISCRIMINATOR. `dependencies[]` membership in the candidate list, the handoff's `blockers[]` being empty, or both (conjunction or disjunction)? Note the live reproduction had BOTH signals available AND AGREEING, so it does not by itself discriminate between the options -- construct the disagreement cases deliberately (dependency edge present but blockers non-empty; blockers empty but blocker is out-of-batch) and decide what each should do. Also settle whether a predecessor that FAILED counts as "discharged" (today a failed predecessor already moves its dependents to `failed_tasks` with status `blocked` -- see the state-machine doc around line 413 and skill-orchestrate around line 1554; that path must not be broken).

2. WHAT STATUS THE SUCCESSOR SHOULD BECOME once its in-batch predecessor terminates, and WHICH COMPONENT performs the rewrite. Nothing does today -- that is the core gap. Candidate homes, all in file_scope: `scripts/orchestrator-postflight.sh` (natural: a terminating predecessor clears its successors), `scripts/reconcile-task-status.sh` (which already gained a lock-aware demotion guard in the prior work and is the system's designated status-repair component), or skill-orchestrate's own Stage MT-3 cycle loop. It CANNOT be the classifier (read-only, see above). If the answer is "no rewrite is needed because the verdict alone routes it", say so explicitly and show what then corrects the stale `blocked` string, and when.

3. WHETHER THE SINGLE-TASK ENGINE'S `needs_human` ESCALATION STAYS DIVERGENT OR CONVERGES, applying the classifier header's own stated audit discriminator honestly. Note the asymmetry: a solo invocation has no sibling batch, so "in-batch predecessor" is vacuous there and the row may legitimately remain unchanged for `single` -- but that is a conclusion to argue, not to assume. Both engines' handlers implement the current divergence independently, which by the header's own rule makes it DESIGN; the question is whether the mt side's new discrimination changes that verdict.

4. WHETHER `/spawn` SHOULD STOP WRITING `blocked` AT ALL when it has just recorded the same ordering in `dependencies[]`. `skills/skill-spawn/SKILL.md` sets `status = "blocked"` directly via `state-write.sh` (around lines 114, 161, 178) and its own note at line 98 states "`[BLOCKED]` means 'has unmet dependencies', not 'encountered an error'" -- i.e. the file already documents the status as PURE ORDERING INFORMATION, corroborating the live reproduction's `blockers: []`. Decide whether that redundancy is deliberate (and only the consumer should change) or whether the producer should stop writing it. If `/spawn` keeps writing it, say what the status is FOR, given `dependencies[]` already carries the same fact.

=== ACCEPTANCE ===

- A batch submitted as a dependency chain where each successor is `blocked` on its in-batch predecessor runs END-TO-END IN A SINGLE `/orchestrate` INVOCATION, with no hand-editing of statuses and no operator instruction to run the tasks one at a time.
- A task blocked on something OUTSIDE the batch still does not silently spin: it is either skipped WITH A LOUD, NAMED WARNING or escalated, and which one is a RECORDED DECISION.
- A task whose predecessor FAILED still lands in `failed_tasks` and is not spuriously dispatched.
- All co-maintained copies of the verdict table agree, VERIFIED BY GREP, and every justification paragraph that asserts the now-changed premise is re-derived or corrected in the SAME change -- landing the mechanism while leaving prose asserting a false premise is not acceptable.
- New classifier fixtures cover the DISCRIMINATED blocked rows for BOTH engines and FAIL AGAINST THE PRE-FIX CLASSIFIER (observe the mutation-check discipline in `context/standards/shell-script-testing.md`: a suite that passes unchanged both before and after proves nothing). The existing `fixture_blocked` assertions and their "do not fix this" comment are rewritten, not left contradicting the new behaviour.
- The dry-run report predicts the new behaviour, since a dry-run that disagrees with the live path is worse than no dry-run.

=== SCOPE RULES (binding) ===

Edit ONLY `agent-system/extensions/core/**`, NEVER the deployed `.claude/**` tree, per `.claude/rules/source-store-deploy-boundary.md`; verify via a deploy after the change rather than editing the deploy tree. No task-number references in any deliverable outside `specs/**`, per `.claude/rules/no-task-references-in-deliverables.md` -- cite filenames and section headings instead. If implementation finds another file genuinely needs editing, widen `file_scope` deliberately via `state-write.sh`, naming each file exactly -- no bare directory roots, no duplicate entries.

=== SELF-MODIFYING TASK ===

`scripts/orchestrate-triage-classify.sh`, `skills/skill-orchestrate/SKILL.md`, `skills/skill-orchestrate-hard/SKILL.md`, `commands/orchestrate.md`, `scripts/orchestrate-batch-admit.sh` and `scripts/orchestrate-dry-run-report.sh` are all registered in `context/reference/orchestrator-critical-paths.json`, so `orchestrate-batch-admit.sh` will classify this task as `self_modifying`. Under the designated-candidate tie-breaker shipped by the prior admission-gate work, one self-modifying candidate is admitted per cycle, so this task self-sequences rather than deadlocking. Do NOT run it solo -- solo dispatch is the workaround that line of work exists to eliminate.

---

### 67. Make /orchestrate admission gates ordering constraints, not exclusions: unstrand in-flight tasks and end solo-only self-modifying dispatch
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: None
- **Research**: [067_orchestrate_eligibility_not_status_gated/reports/01_admission-predicate-eligibility-and-self-mod-tiebreak.md]
- **Plan**: [067_orchestrate_eligibility_not_status_gated/plans/01_admission-gates-as-ordering-constraints.md]
- **Summary**: [067_orchestrate_eligibility_not_status_gated/summaries/01_admission-gates-as-ordering-constraints-summary.md]

**Description**: Repair two coupled defects in /orchestrate's multi-task admission predicate so that every admission gate degrades to an ORDERING CONSTRAINT and never to a PERMANENT EXCLUSION. Work stream A: make eligibility depend on locks, dependencies[], and file_scope overlap rather than on an in-flight status string, so tasks stranded in researching/planning by a dead prior session are no longer silently skipped forever. Work stream B: give the self-modification gate a deterministic tie-breaker and make it phase-aware, so N self-modifying tasks in one batch run in sequence instead of deadlocking, and so the operator is never told to "run it solo". Both work streams edit the same predicate file (scripts/orchestrate-batch-admit.sh) and the same co-maintenance set, and B supplies the replacement convergence exit condition that A removes -- see COUPLING below for why splitting them is not viable.

=== WORK STREAM A: ELIGIBILITY MUST NOT BE STATUS-GATED ===

OBSERVED DEFECT. Stage MT-3 step 3 of skills/skill-orchestrate/SKILL.md (lines 1449-1460) builds eligible_tasks with the condition "Status is NOT {researching, planning} (in-flight from prior cycle)". Stage MT-4's phase-grouping table (lines 1877-1885) folds "blocked, researching, planning, unknown" into the skip group. scripts/orchestrate-triage-classify.sh encodes the same rule executably: researching and planning are not named anywhere in its jq at all, so they fall into the final else arm and are emitted as group "skip" with reason "transitional/unknown". A task stranded in either status is therefore absent from every cycle, produces no warning, and never surfaces to the operator.

LIVE EVIDENCE, MEASURED AT TASK-CREATION TIME, WITH ONE PREMISE CORRECTION. Tasks 22 (researching), 28 (implementing) and 31 (researching) are stranded. IMPORTANT CORRECTION TO THE ORIGINATING REPORT: the originating report asserted these tasks have "no lock holder". That is FALSE and must not be carried into research. All three DO hold lock directories, all three held by the same dead session sess_1786459614_0c9ada, with heartbeat_at frozen at 2026-08-11. Measured directly via the deployed task-lock.sh check: each returns "held-stale ... heartbeat_age_min=9073 (or 9086) threshold_min=30", exit code 2. So the correct diagnosis is STALE FOREIGN LOCK, not ABSENT LOCK. This matters because it changes what the fix must prove: the question is not "is a lock-free in-flight status safe to dispatch" but "does acquire's stale-override path actually reclaim these". Re-measure before relying on any of this; the stranded set will have changed.

THE LOCK LAYER ALREADY BEHAVES CORRECTLY, AND THIS IS THE CORE FINDING. scripts/task-lock.sh keys locks on task number alone (operation/phase is recorded in holder.json but never compared when granting or refusing). TASK_LOCK_STALE_MIN defaults to 30 minutes. cmd_acquire refuses (exit 1) on exactly three branches: a cross-task file_scope overlap against a FRESH foreign lock; a session-registry contention hit; and its own task's lock being held FRESH by a different session. Same-session re-entry never blocks and only refreshes heartbeat_at. A stale foreign lock is override-and-warn, never refusal, and the .lock directory is not removed, holder.json is simply overwritten. Critically, cmd_acquire never reads .status at all. So the status string is doing no concurrency work whatsoever, and the lock is already the real mutex. That is the substantive support for the user's stated requirement.

RECONCILE IS INERT ON THIS CASE, MEASURED. scripts/reconcile-task-status.sh was run live against the stranded researching task: it produced no output, exited 0, and did not mutate state.json. The blocking condition is its artifact-presence check. Its researching branch reads report_file=$(find_latest_artifact reports) and then "if [[ -z "$report_file" ]] ... exit 0" under the comment "# No artifact -- genuine in-progress, no-op". planning and implementing have byte-identical shapes. The script contains only promotion rules; there is no demotion rule anywhere in it (researching -> not_started does not exist). It never consults task-lock.sh, never reads holder.json, never references a .lock path, so its "genuine in-progress" assertion rests on no evidence. Note reconcile-task-status.sh is deliberately ABSENT from context/reference/orchestrator-critical-paths.json, and that absence is a recorded non-decision, see context/patterns/system-defect-discrimination.md lines 326-336, which explicitly leaves "whether they belong in critical_paths for the self-modification-hazard check" as an undecided follow-on.

DECIDE, DO NOT PRESUPPOSE. The user's stated requirement is that in-flight status alone must not be an eligibility exclusion, and that concurrency safety be enforced only by the admission gate's file_scope overlap check and by dependencies[] edges. Research must still choose and record HOW, weighing at minimum: (a) remove the status exclusion from eligibility and map researching -> research group and planning -> plan group in the classifier, letting acquire's stale-override reclaim the lock; (b) leave eligibility alone and instead make reconcile-task-status.sh lock-aware, demoting an in-flight status with no artifact and no fresh lock back to its predecessor status, so the task re-enters eligibility through the existing path; (c) both, with (a) as the mechanism and (b) as defence in depth plus operator visibility. Weigh (b) seriously rather than dismissing it: it repairs the state rather than routing around it, it fixes the same stranding for the single-task engine and for every other consumer of status at once, and it does not disturb the safety arguments enumerated below. Weigh against it that a demotion rule is a new class of write for that script and that a task genuinely in flight under a FRESH lock must never be demoted.

CO-MAINTENANCE SET IS LARGER THAN THE THREE ARTIFACTS THE ORIGINATING REPORT NAMED. The self-declared triple (skill-orchestrate SKILL.md's MT-4 table, skill-orchestrate-hard SKILL.md, and orchestrate-triage-classify.sh's header verdict table) governs the PHASE-GROUPING TABLE only. The ELIGIBILITY rule has a further set of dependents that a naive edit would silently falsify, several of which are load-bearing SAFETY ARGUMENTS asserting a hazard is "structurally impossible BECAUSE of" the exclusion:
  - scripts/orchestrate-batch-admit.sh lines 189-194: the A1 dead-code justification, which argues an explicit dependency-edge exemption in the self-mod branch "would therefore be unreachable dead code" because "Stage MT-3 step 3's eligibility rule makes it structurally impossible for a dependencies[]-edge predecessor/successor pair to occupy the same eligible_tasks batch".
  - context/patterns/batch-orchestration-guardrails.md, four sites (around lines 200-206, 238-241, 254-259, 276-278), which RETIRE hazards on exactly that premise.
  - commands/orchestrate.md lines 262-265, and docs/architecture/batch-admit-schema.md at three sites (around 155-157, 264-267, 286-289), restating the same claim.
  - docs/architecture/orchestrate-state-machine.md, four sites (ASCII diagram around 331-337, prose around 379-382, worked example around 437) restating the eligibility rule directly.
  - The in_batch defer CONVERGENCE argument, present in BOTH skills (base around 1552-1570, hard around 1583-1586), which states a deferred task "becomes eligible again on a later cycle, once the colliding in-batch task leaves eligible_tasks (entering researching/planning, terminating, or failing)" and is explicitly labelled "load-bearing for the convergence argument elsewhere in this file". If in-flight statuses no longer remove a task from eligible_tasks, this convergence argument loses one of its three exit conditions and MUST be re-derived, not merely reworded. This is the single highest-risk consequence of direction (a) and is the strongest argument for weighing (b). NOTE: work stream B's deterministic tie-breaker supplies a replacement exit condition that does not depend on status transitions at all -- re-derive the convergence argument against BOTH work streams' post-change exit conditions, not against work stream A alone.
Every one of these must be re-derived or corrected in the same change. A fix that lands the mechanism while leaving these asserting a now-false premise is not acceptable.

HARD-MODE FILE DIVERGES FROM THE ORIGINATING REPORT'S ASSUMPTION. skill-orchestrate-hard/SKILL.md is NOT a full transcription twin for these items. It has NO eligible_tasks construction, NO phase-grouping table, NO circuit breaker, NO entry reconcile and NO Decision 1 -- its Multi-Task Mode section (from line 1539) is a bare "Same as base" pointer that deliberately transcribed only two mechanisms (the admission gate and the redeploy checkpoint). It DOES carry compressed Stage 4 researching/planning handlers (lines 599-601 and 689-691) that say only "In-flight. Exit with warning ... Same as base skill", having dropped the base file's verbatim operator message and its EXIT (partial) code entirely. So the hard-file work is smaller and different in kind from what was assumed: update the handlers and the transcribed in_batch convergence text, and decide explicitly whether the eligibility rule now needs transcribing there given its own stated rationale (lines 1544-1551) that bare pointers demonstrably fail to carry mechanisms forward. Note that the hard file DID transcribe the admission gate, so work stream B's predicate change lands in it too.

SINGLE-TASK ENGINE, DECIDE AND RECORD EITHER WAY. Base Stage 4's researching handler (lines 359-367) and planning handler (lines 408-410) EXIT the whole invocation with "is currently being researched in another session" and EXIT (partial), whereas implementing dispatches normally. Decide whether these converge with the multi-task change or deliberately diverge, and record the reasoning explicitly. Precedent for a documented intentional divergence exists on the blocked row (Decision 1, base lines 597-602: single-task escalates to needs_human because it has no siblings, multi-task skips so siblings proceed), so divergence is acceptable IF justified and written down, never accidental. Note the asymmetry that motivates convergence: the single-task engine's message asserts another session owns the task, which in the measured evidence is false -- the owning session is dead and its lock is stale.

BLOCKED AND UNKNOWN ROWS: EXPLICIT SCOPE DECISION REQUIRED, DEFAULT IS LEAVE ALONE. Do not silently widen scope. The default position is that blocked keeps its documented Decision 1 divergence and unknown keeps routing to skip, since neither is implicated in the stranding defect. If research concludes either should change, that must be argued separately and called out, not folded in.

NO TEST COVERAGE EXISTS FOR THE RULE BEING CHANGED. scripts/tests/test-orchestrate-triage-classify.sh covers ONLY the partial-status continuation-pointer predicate. No fixture anywhere exercises researching/planning -> skip, the blocked engine divergence, or the terminal rows, so the triple's co-maintenance is currently enforced by prose comments alone. Add fixtures covering the status-to-group rows for both engines, and observe the mutation-check discipline in context/standards/shell-script-testing.md: a suite that passes unchanged both before and after the fix proves nothing.

=== WORK STREAM B: SELF-MODIFICATION GATE MUST NOT REQUIRE SOLO DISPATCH ===

USER REQUIREMENT, STATED VERBATIM: "why do I ever have to run tasks solo? I don't like that restriction... worst case tasks will run in sequence." Sequencing is acceptable; exclusion and operator-instructed solo runs are not.

MEASURED MECHANISM (scripts/orchestrate-batch-admit.sh lines 476-495, verified by direct read; re-measure before relying on line numbers). The rule is exactly:
    if ($sm_flag == true) then
      if ($inv_count > 1) then  -> decision "defer", defer_reason "self_modifying"
      else                      -> decision "admit"
where $inv_count is --invocation-count, passed by skill-orchestrate Stage MT-3 step 4.5 as ${#eligible_tasks[@]}, i.e. this cycle's co-dispatch count. There is NO tie-breaker: EVERY self-modifying candidate defers whenever more than one task is eligible that cycle.

CONSEQUENCE A -- WORKS, BUT WASTEFUL. One self-modifying task among N ordinary tasks defers every cycle until it is the LAST eligible task, then admits. Observed live in a two-task batch: the self-modifying task deferred cycles 1-3 while its sibling ran research/plan/implement, then dispatched at cycle 4 and completed. It self-sequenced correctly. Cost was three wasted cycles, not exclusion.

CONSEQUENCE B -- THE REAL FAILURE. TWO OR MORE self-modifying tasks in one batch deadlock permanently. Once they are the only eligible candidates, $inv_count is 2, so BOTH defer; neither can ever become the sole candidate. The batch spins until skill-orchestrate's consecutive_no_dispatch_cycles convergence guard trips at 3 and ends the invocation "partial". The guard's own diagnostic (skill-orchestrate/SKILL.md around line 1668) already names this failure mode: "likely a mutually-colliding self-modifying set; re-run affected tasks solo or pass --allow-self-modifying". The system therefore already knows about the deadlock and its only remedy today is exactly the solo workaround the user is rejecting. Verified independently: a dry-run over three orchestrator-critical candidates admitted only one and excluded BOTH others with "re-run it alone (orchestrator-critical work runs solo only, never alongside sibling tasks)".

CONSEQUENCE C -- PHASE-BLINDNESS, LIKELY THE LARGEST FALSE-POSITIVE SOURCE. The gate keys on the task's DECLARED file_scope regardless of WHICH PHASE is being dispatched. But file_scope is the IMPLEMENTATION footprint. A research dispatch writes only to the task's own reports/ subdirectory; a plan dispatch writes only to plans/; both additionally write only .return-meta.json and .orchestrator-handoff.json inside their own task_dir. Neither can touch orchestrator machinery. Deferring a self-modifying task's research or plan dispatch is therefore a pure false positive. Applied to the observed session: that task's research and plan dispatches could have run concurrently with its sibling, and only its implement dispatch needed serialization -- three cycles saved at identical safety.

DIRECTIONS TO EVALUATE. Do not pre-commit; research must choose among these and record the reasoning, including any rejections.
  (1) TIE-BREAKER. Change the predicate from "defer if inv_count > 1" to "defer if inv_count > 1 AND this candidate is not the designated self-modifying candidate for this cycle". Selection must be deterministic -- lowest task number, or most live dependents; decide and record which. N self-modifying tasks then run in strict sequence rather than deadlocking. This is the minimal change that delivers the user's stated "worst case is sequence" requirement, and it is the change that supplies work stream A's replacement convergence exit condition.
  (2) PHASE-AWARE GATING. Apply the self-modification gate only to implement dispatches, not to research or plan dispatches. This requires the admission call site to know which phase each eligible task would dispatch to. Note that skill-orchestrate Stage MT-4 already computes exactly this via scripts/orchestrate-triage-classify.sh, but the admission call at Stage MT-3 step 4.5 runs BEFORE that classification, so either the ordering must change or the classifier must be called earlier. VERIFY THIS ORDERING CLAIM DIRECTLY before relying on it; a naive reordering may break other MT-3 invariants.
  (3) REDEPLOY-BOUNDARY SERIALIZATION (larger; may belong in a follow-up -- decide explicitly). The actual hazard is not concurrent editing: it is the inter-cycle redeploy checkpoint (Stage MT-3 step 7) rewriting the running orchestrator's own definition while sibling dispatches are in flight. That is a quiesce-before-redeploy problem, not a refuse-to-dispatch problem. Direction: let everything dispatch, and when a cycle's modified_files overlap critical paths, HOLD the redeploy until in-flight siblings reach a cycle boundary. This yields strictly more parallelism than (2) but materially more design work. If research concludes it belongs in a separate follow-up task, SAY SO and recommend the split explicitly rather than silently deferring it.

=== THE GENERAL PRINCIPLE TO RECORD (TIES BOTH WORK STREAMS TOGETHER) ===

Every admission gate should degrade to an ORDERING CONSTRAINT, never a PERMANENT EXCLUSION. Measured current state of the five gates:
  - file_scope_collision / in_batch      -> defers to a later cycle             = ordering (correct)
  - session_active                       -> defers                              = ordering (correct)
  - self_modifying                       -> defers, but deadlocks at 2+         = exclusion in practice (defect, work stream B)
  - file_scope_collision / cross_batch   -> excluded from the run               = exclusion (defect)
  - deploy_checkpoint                    -> excluded for the whole invocation   = exclusion (defect)
Three of five already satisfy the principle. The per-invocation override flags (--allow-self-modifying, and --allow-scope-collision added by the recently-completed consumer-threading work; both parsed in scripts/parse-command-args.sh around lines 141-144 and stripped around 168-169) are escape hatches bolted onto the exclusion cases -- evidence that the underlying shape is wrong, since a correctly-shaped gate would not need a bypass in order to make progress. Research should decide (i) whether to state this principle NORMATIVELY in context/patterns/batch-orchestration-guardrails.md, and (ii) whether the cross_batch and deploy_checkpoint gates are in scope here or are a recommended follow-up. Either answer is acceptable; silence is not.

=== COUPLING: WHY BOTH WORK STREAMS BELONG IN ONE TASK ===

These two defects are COUPLED, not merely adjacent:
  - Work stream A's single highest-risk consequence (named above) is that removing the in-flight status exclusion breaks the in_batch defer CONVERGENCE ARGUMENT, which currently relies on a task leaving eligible_tasks by "entering researching/planning, terminating, or failing". Work stream B's deterministic tie-breaker (direction 1) SUPPLIES a replacement exit condition that does not depend on status transitions at all. The second work stream therefore repairs what the first work stream breaks.
  - Both edit the same predicate file (scripts/orchestrate-batch-admit.sh) and the same co-maintenance set already enumerated under work stream A.
  - Splitting them would create two self-modifying work items with heavily overlapping file_scope, which -- under the very defect being fixed -- would mutually deadlock (CONSEQUENCE B). This is a concrete, not rhetorical, argument for keeping them together.

=== ACCEPTANCE ===

A stranded in-flight task with a stale lock is dispatched (or repaired then dispatched) rather than skipped, demonstrated against the real stranded set after re-measuring it. A task genuinely in flight under a FRESH foreign lock is still not concurrently dispatched, and the mechanism that prevents it is named. All co-maintained copies agree, verified by grep, and every safety argument listed above is either re-derived or corrected. New classifier fixtures cover the status-to-group rows for both engines and fail against the pre-fix classifier. The single-task engine's behaviour is either converged or divergent-by-record. Additionally:
  - N self-modifying tasks submitted in one batch ALL complete, dispatched in a deterministic sequence, with zero deadlock and no operator instruction to "run it solo".
  - A research or plan dispatch of a self-modifying task is NOT deferred merely because the task's IMPLEMENTATION footprint names a critical path -- if direction (2) is adopted; if it is rejected, record why.
  - The in_batch defer convergence argument is re-derived against whatever exit conditions actually exist AFTER both work streams land, and does not cite an exit condition that no longer holds.
  - No admission gate in the changed set produces a permanent exclusion where an ordering constraint would suffice; any remaining exclusion is named and justified.
  - The convergence guard's "re-run affected tasks solo" diagnostic is updated or removed, since it should no longer be reachable for a mutually-colliding self-modifying set.

SCOPE RULES (binding). Edit only agent-system/extensions/core/**, never the deployed .claude/** tree, per .claude/rules/source-store-deploy-boundary.md; verify via a deploy after the change rather than editing the deploy tree. No task-number references in any deliverable outside specs/**, per .claude/rules/no-task-references-in-deliverables.md -- cite filenames and section headings instead. context/patterns/multi-task-operations.md and context/patterns/task-lock.md were both checked and deliberately EXCLUDED from file_scope: neither asserts that in-flight status implies a held lock and neither restates the eligibility rule (task-lock.md's Tier-1 row only points at Stage MT-3 step 4.5 by reference, and multi-task-operations.md's status table is a per-command admission whitelist that actually admits implementing). scripts/parse-command-args.sh and context/reference/orchestrator-critical-paths.json HAVE been added to file_scope for work stream B: the former because a new selection or override behaviour may need a flag or a changed strip list, the latter because phase-aware gating may need per-path phase metadata. If either turns out not to need editing, leave it untouched rather than inventing a change. If implementation finds any other file genuinely needs editing, widen file_scope deliberately via state-write.sh, naming each file exactly -- no bare directory roots, no duplicate entries.

SELF-MODIFYING TASK. skills/skill-orchestrate/SKILL.md, skills/skill-orchestrate-hard/SKILL.md, scripts/orchestrate-triage-classify.sh, scripts/orchestrate-batch-admit.sh and scripts/task-lock.sh are all registered in context/reference/orchestrator-critical-paths.json, so orchestrate-batch-admit.sh will classify this task as self_modifying and defer it out of any cycle where it is co-dispatched. Under the CURRENT (pre-fix) predicate that means it will self-sequence into the last eligible slot, costing cycles but still completing -- CONSEQUENCE A, not CONSEQUENCE B, so long as it is the only self-modifying task in the batch. Do NOT run it solo: solo dispatch is the workaround this work exists to eliminate, and using it here would suppress the very evidence the fix needs. If it is co-dispatched with another self-modifying task and the batch stalls, that stall is the reproduction case for CONSEQUENCE B -- record it rather than working around it.

---

### 66. Mandate run_in_background for Lean builds and add long-builds anchor
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 97

**Description**: Mandate detached (run_in_background) invocation for Lean full builds across the lean extension's agent and skill contracts, and add a canonical anchor file documenting the foreground-cap livelock and the passive progress checks that do not disturb a running build.

PROBLEM (livelock, not slowdown). The Lean implementation contracts instruct agents to run a full `lake build` for final verification with no guidance on HOW to invoke it, so agents run it as a plain foreground Bash call. The Bash tool kills foreground calls at a 10-minute cap. Lean caches compilation per module, and a cap-killed build writes no .olean for the module it was working on, so NO progress is cached and the next attempt restarts at the identical module. The agent retries indefinitely and can never converge.

MEASUREMENT (illustrative, from one large Lean repo -- MUST NOT be hardcoded as an assumption in the contract text): a single module required ~11 minutes to elaborate (15 MB .olean, ~21 cores engaged, 8.2 GB peak RSS). Three consecutive agent attempts were each killed at the 10-minute cap. The same build run detached and uncapped completed in 11m56s (2457 jobs, exit 0); the blocking module alone accounted for ~11 minutes. The NORMATIVE statement in the contract must be the generic one: "any single module may exceed the foreground cap." The source store deploys to roughly ten repositories and must not assume this one repo's profile.

TRIGGER IS ORDINARY. Lean hashes whole files, so even a comment- or docstring-only edit to an upstream module invalidates every downstream .olean and forces the heavy cluster to rebuild. Any docstring pass re-arms the trap. The contract should say this explicitly so the failure is not read as exotic.

MECHANISM ALREADY EXISTS. Bash(run_in_background: true) runs detached, survives across turns, and re-invokes the agent on completion. This task adds no new machinery; it is contract text making that invocation mandatory. VERIFIED: `grep -rn run_in_background` across the entire lean extension returns zero hits today, so the guidance is absent, not merely weak.

DELIVERABLE 1 -- NEW CANONICAL ANCHOR (~40 lines):
  agent-system/extensions/lean/context/project/lean4/operations/long-builds.md
Follows the extension's single-anchor convention: one authoritative file referenced by path, prose never duplicated at the call sites. The operations/ directory already exists (currently holds multi-instance-optimization.md), so this is a sibling addition. Content: the 10-minute foreground cap; Lean's per-module caching; why a cap-killed build caches nothing and therefore livelocks rather than merely slowing down; the mandate to run builds via run_in_background; and the set of PASSIVE progress checks that do not disturb a running build -- fresh .olean files by mtime, the live `lean` PID's /proc/PID/cmdline (which module it is on), accumulated CPU time via `ps -o times` or /proc/PID/stat (the tiebreaker during a long single module, when the olean list looks frozen), and VmRSS trend (also an OOM early-warning). Include the honest caveat that these prove LIVENESS, not TERMINATION.
No manifest.json change required: this lands under the already-declared provides.context entry "project/lean4" (verified present in manifest.json alongside "contracts").

DELIVERABLE 2 -- POINT THE INSTRUCTION SITES AT THE ANCHOR. 19 files in the extension mention `lake build`; only the following actually instruct an agent to run one. Scope edits to these and no others. Line numbers verified at task-creation time and may drift:

  agents/lean-implementation-agent.md
    - line 165: verification step is currently a bare fenced ```lake build 2>&1``` block
    - line 424, MUST DO item 8, currently: "Always run full `lake build` before returning implemented status (final verification only)"
      becomes: "...(final verification only). Run it via `Bash(run_in_background: true)`, never as a plain foreground call -- see `context/project/lean4/operations/long-builds.md`."
    - add a NEW MUST NOT item: "**Run a full `lake build` as a foreground Bash call.** The 10-minute cap kills it mid-module; a killed build caches no .olean, so retries restart at the same module and livelock indefinitely."
      Placing the prohibition in MUST NOT is DELIBERATE and must not be softened into advisory prose mid-file: MUST NOT is the strongest lever these contracts have, and advisory prose buried mid-file is exactly what gets skipped, which is how this defect survived.
  agents/lean-implementation-hard-agent.md -- engine twin. Note the twin is NOT line-symmetric with the base file: its MUST DO item is number 7 at line 515 (not item 8), it has an additional site at line 223 (`lake build ModuleName 2>&1`), a full-build fence at line 373, and line 356 describes a stripper that "runs its own `lake build`". Locate by content, not by line number.
  agents/lean-research-agent.md -- lighter touch (line 52 tool description, line 183 "verify with `lake build`")
  agents/lean-research-hard-agent.md -- lighter touch (line 59 tool description)
  skills/skill-lean-implementation/SKILL.md -- build-verification stage (lines 108, 302)
  skills/skill-lean-implementation-hard/SKILL.md -- build-verification stage (lines 223, 444)
  skills/skill-lake-repair/SKILL.md -- see the ARCHITECTURAL EXCEPTION below
  rules/lean4.md -- pointer to the anchor. NOTE: the prompt estimated a one-line pointer, but this file carries a whole build-command reference block (lines 47-48, 58, 61-62) presenting scoped-vs-full choice as purely a speed tradeoff. Expect more than one line.

ARCHITECTURAL EXCEPTION -- skill-lake-repair/SKILL.md IS THE HIGHEST-RISK EDIT, DO NOT TREAT IT AS A POINTER EDIT. Its repair loop captures build output synchronously via command substitution: `build_output=$(lake build "$module" 2>&1)` and `build_output=$(lake build 2>&1)` at lines 69 and 71. Command substitution is fundamentally incompatible with run_in_background, which does not return stdout to a shell variable. Honoring the mandate here requires restructuring the loop to redirect build output to a file and poll that file, not appending a pointer. Decide and record whether the repair loop is (a) restructured to file-and-poll, or (b) explicitly carved out of the mandate with its cap-vulnerability documented in the anchor. Do not silently leave it as-is while claiming the mandate is enforced extension-wide.

DECISION TO MAKE -- SCOPED BUILDS ARE ALSO CAP-VULNERABLE. Currently lean-implementation-agent.md MUST DO item 7 (line 423) says to "prefer `lake build Module.Name` for phase-end verification (scoped, faster)" and MUST NOT item 3 (line 436) explicitly exempts scoped builds from the full-build mandate; rules/lean4.md lines 47/58/61 repeat this framing. But the measurement above is that a SINGLE MODULE took ~11 minutes, which exceeds the cap on its own -- so the scoped build these lines recommend as the safe fast path is itself cap-vulnerable, and an agent following the contract can livelock at phase-end verification without ever reaching a full build. Recommended resolution: extend the anchor and the mandate to cover any build that may touch an uncached heavy module, full or scoped, and revise item 7 / MUST NOT item 3 / the rules/lean4.md block so scoped-vs-full is no longer presented as the safety boundary. If instead the narrower full-builds-only scope is chosen, record why and leave the scoped-build vulnerability explicitly noted rather than unmentioned. This decision was flagged at task creation and was NOT confirmed by the user -- the interactive confirmation gate was unavailable in the creating context -- so treat it as an open recommendation to validate during research, not a settled requirement.

TWIN-FILE DISCIPLINE (binding). The base and -hard variants must be edited together in this task. The extension treats a one-sided edit between engine twins as a known recurring defect class, and the two files are not line-symmetric (see above), so a mechanical copy of one diff onto the other will not work -- locate each site by content.
VERIFIED NON-SURFACE: opencode-agents.json contains zero `lake build` occurrences, so it does not mirror this contract prose and needs no edit. There is no third drift surface.

SOURCE-STORE RULE (binding): all edits target agent-system/extensions/lean/**. Never edit a deployed .claude/** tree -- those are disposable artifacts regenerated on reload, so such an edit silently vanishes. NOTE: the originating prompt gave the file_scope paths rooted at `extensions/lean/...`; the actual source store at this repo root is rooted at `agent-system/`, so the correct paths are `agent-system/extensions/lean/...` as recorded in file_scope.
DELIVERABLE RULE (binding): no task-number references in the contract text. These files are deliverables outside specs/, governed by the no-task-references-in-deliverables rule. Cite the anchor filename and the mechanism, never a task number.

ADJACENT TASK, NO FILE OVERLAP: an in-progress task holds agent-system/extensions/lean/opencode-agents.json in its file_scope. That file is not in this task's scope and carries none of this contract prose, so no serialization is required.

ACCEPTANCE: long-builds.md exists at the stated path with the cap, the per-module-caching livelock explanation, the run_in_background mandate, and the four passive progress checks with the liveness-not-termination caveat; every instruction site above points at the anchor rather than restating its prose; lean-implementation-agent.md carries the new MUST NOT item verbatim in intent; the -hard twin carries equivalent changes located by content; the skill-lake-repair command-substitution incompatibility is resolved or explicitly carved out with a recorded reason; the scoped-build decision is recorded either way; the normative text says "any single module may exceed the foreground cap" with the ~11-minute figure present only as an illustrative note; no .claude/** file is modified; no task numbers appear in any edited file.


=== SCOPE ADDENDUM: ABSORB THE BUILD-GUARD OBLIGATION INTO THIS CONTRACT PASS ===

This task's scope is EXTENDED. The contract pass described above must now mandate TWO things
together at every instruction site it already covers: detached invocation via
`Bash(run_in_background: true)`, AND invocation through the shared Lean build guard delivered by
the core guard task. The two obligations are edited in ONE pass over the eight contract files
rather than two, because a second independent pass over the same twins is exactly the twin-file
drift this extension treats as a known recurring defect class.

WHY THE TWO MUST LAND TOGETHER (do not adopt one half of this pair). The diagnosis above is
correct: the 10-minute foreground Bash cap kills builds mid-module, a cap-killed build caches no
.olean, and retries restart at the identical module, so the agent livelocks. But that cap is
currently the ONLY thing bounding how long a REDUNDANT CONCURRENT build survives. Measured on one
large Lean repo: roughly ten simultaneous `lake build` runs launched by separate sessions, all
re-elaborating the SAME modules -- 6 concurrent copies of the heaviest module alone -- with 16
`lean` processes holding 29.9 GB RSS on a 30 GB machine, 29 GB of swap in use, and 3.1 GB
available. Uncapping those builds does not reduce that load; it removes the ten-minute ceiling on
it, so ten duplicates run to completion instead of dying partway. MANDATING run_in_background
WITHOUT THE GUARD MAKES THE MEMORY SITUATION STRICTLY WORSE. Treat the guard obligation as a
precondition of the detachment mandate, not as an optional companion.

THE ARCHITECTURAL EXCEPTION IS NOW A SOLVED CASE. The section above flags
`skills/skill-lake-repair/SKILL.md` as the highest-risk edit because its repair loop captures build
output synchronously -- `build_output=$(lake build "$module" 2>&1)` and
`build_output=$(lake build 2>&1)` at lines ~69 and ~71 -- and command substitution is
fundamentally incompatible with run_in_background, which returns no stdout to a shell variable.
That reasoning stands for detachment. It does NOT apply to the guard: a flock-based guard
serializes the build and still returns stdout and exit status to the caller, so a
command-substitution call site can adopt the guard unchanged in shape.
This materially changes the recorded decision. The choice is no longer "(a) restructure to
file-and-poll, or (b) carve the repair loop out of the mandate with its cap-vulnerability
documented". A THIRD option now exists and should be evaluated first: leave the repair loop
synchronous, route it through the guard, and carve it out of the DETACHMENT mandate only -- so it
gains serialization and memory bounding while keeping its cap exposure explicitly documented.
Record which of the three is chosen and why. The same command-substitution shape appears in
`scripts/lean-sorry-census.sh --cross-check`, but that site is owned by the lean-integration task,
not this one -- do not edit it here.

ANCHOR COORDINATION. The new anchor this task creates, `operations/long-builds.md`, is a sibling of
`operations/multi-instance-optimization.md`, which the lean-integration task rewrites from
human-advisory prose into mechanism documentation. The two must be coherent, cross-referenced, and
non-duplicating, and the detachment-amplifies-concurrency interaction stated above must appear in
writing in at least one of them. Coordinate rather than duplicating.

SCOPE UNCHANGED IN ALL OTHER RESPECTS. The instruction-site list, the twin-file discipline, the
verified non-surface finding for opencode-agents.json, the scoped-build decision left open for
research to validate, the source-store rule, and the deliverable rule all stand exactly as written
above. This addendum adds an obligation to the same pass; it does not widen the file scope beyond
the contract files already listed, and it does not authorize editing the census script or either
operations anchor owned by the lean-integration task.

DEPENDENCY ADDED: the core guard task must deliver the guard script before this contract pass can
name it. This task is now blocked on that task.

---

### 65. Fix mint dispatch seq persisted counter
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None
- **Research**: [065_fix_mint_dispatch_seq_persisted_counter/reports/01_mint-dispatch-seq-fresh-shell-fix.md]
- **Plan**: [065_fix_mint_dispatch_seq_persisted_counter/plans/01_mint-dispatch-seq-persisted-counter-fix.md]
- **Summary**: [065_fix_mint_dispatch_seq_persisted_counter/summaries/01_mint-dispatch-seq-fix-summary.md]

**Description**: Fix skill_orchestrate_mint_dispatch_seq to increment from the persisted counter. The helper in scripts/skill-base.sh computes dispatch_seq_counter=$((dispatch_seq_counter + 1)) from an ambient shell variable rather than from the value it reads back out of the loop guard file, then persists that result. Any caller that does not hold a single long-lived shell across the whole orchestration loop therefore re-mints the same value on every dispatch: in a fresh shell the variable is unset, so it evaluates to 0 + 1 = 1 every time. Observed during an /orchestrate run where each Bash tool call ran in its own shell -- the second dispatch re-returned dispatch_seq=1 despite the loop guard already carrying dispatch_seq_counter=1. Impact: dispatch_seq is the content-based discriminator the Stage 5 identity gate relies on to tell a legitimate current-dispatch handoff apart from a still-live predecessor's late write (mtime alone is structurally insufficient -- see context/patterns/dispatch-report-not-termination.md). A repeated value defeats that gate in both directions: a stale predecessor handoff carrying seq=1 would pass as the current dispatch's own report, and the mismatch branch could fire against a legitimate handoff. Likely fix: read the counter from the loop guard file inside the function (jq -r '(.dispatch_seq_counter // 0) + 1') rather than from the ambient variable, matching the read-modify-write idiom the multi-task engine already uses at Stage MT-4. Check whether skill-orchestrate-hard/SKILL.md's Stage 2 shares the same helper and is affected identically, and whether test-handoff-dispatch-identity.sh covers the fresh-shell case. SECOND INDEPENDENT CONFIRMATION (Philosophy/Papers/PossibleWorlds repo, base-mode /orchestrate of a formal task, 3 cycles): reproduced exactly as described above, in a different repository and a different task type. Cycle 1 (research) minted dispatch_seq=1 correctly; cycle 2 (plan) re-minted dispatch_seq=1 from a fresh shell while the loop guard already carried dispatch_seq_counter=1. The orchestrator worked around it by seeding dispatch_seq_counter=$(jq -r '.dispatch_seq_counter // 0' "$loop_guard_file") immediately before each skill_orchestrate_mint_dispatch_seq call, which produced correct seqs 2 and 3 for the remaining cycles; both later handoffs then passed the Stage 5 identity gate cleanly. This confirms the defect is not environment-specific and that it fires for ANY orchestrator driving its cycles through separate Bash tool invocations rather than one long-lived shell -- which is the normal execution shape for the base-mode engine, not an edge case. The caller-side seeding above is a workaround only and was NOT committed anywhere; the durable fix remains the read-inside-the-function change described above.

---

### 64. Decide and implement how --hard behavioral contracts reach agents system-wide
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 42

**Description**: Decide and implement how --hard behavioral contracts reach agents system-wide. Only core, cslib, and lean declare routing_hard/routing_agents_hard. For every other extension that declares routing, --hard resolves via=hard-miss-standard-fallback and the H2-H5 behavioral contracts never reach the agent, even though CLAUDE.md advertises --hard as composable with extension routing at a 3-5x cost multiplier. In the originating session the H2/H3/H4/H5 contracts had to be hand-injected into the delegation prompt by the orchestrator for --hard to mean anything at all, which is neither reproducible nor something a user should have to do.

CORRECTED COUNT - VERIFIED INVENTORY, USE THIS NOT THE 16 FIGURE. The delegating description said 16 extensions and listed literature and slidev among them. A direct inventory of all 19 manifests under agent-system/extensions/*/manifest.json shows the real figure is 14. literature and slidev declare routing_exempt: true and declare NO routing blocks whatsoever - they are legitimately exempt, not gaps, and must not be counted, rolled out to, or failed by any lint.
The 14 that declare routing (and routing_agents) but no routing_hard/routing_agents_hard are: email, epidemiology, filetypes, formal, founder, latex, memory, nix, nvim, present, python, typst, web, z3.
For completeness: core declares routing_agents + routing_hard + routing_agents_hard but no plain routing block; cslib and lean declare all four.
CONSEQUENCE FOR LINT DESIGN: any check must skip routing_exempt: true manifests, or it emits 2 false failures on literature and slidev.

DECIDE, DO NOT PRESUPPOSE:
  (a) Declare hard variants across the remaining 14 manifests.
  (b) Make the fallback inherit standard extension routing while delivering hard contracts from a single shared contract block rather than per-skill '-hard' files.
  (c) Both, plus a lint check flagging any extension that declares routing but no routing_hard.
Weigh (b) seriously. The shared ladder lives in exactly one place - agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh, consumed by both command-route-skill.sh and command-route-agent.sh - so a resolver-side fix is a single change point covering all extensions, whereas (a) is 14 manifest edits that can drift. The fact that only 3 of 19 extensions have hard variants is itself evidence that the per-extension '-hard' file approach does not scale, and that evidence bears directly on the choice.

DEPENDS ON THE AGENT-SIDE ROUTING-DOWNGRADE FIX IN THIS BATCH, AND THAT FIX MATERIALLY DE-SCOPES THIS ONE. Once the agent side inherits standard extension routing on a hard miss, most of the 14 resolve to their correct domain agent with ZERO manifest edits. What remains is then the narrower and different question of how the H2-H5 CONTRACTS reach the agent, which is the shared-contract-block idea in option (b). Do not price a 14-manifest rollout before that fix has landed - it would be costing work the fix largely obviates. Re-run the resolver inventory after the dependency completes and report what actually still misroutes.

LINT COORDINATION (binding, read before proposing lint scope). The existing not_started task fix_present_extension_compound_skill_routing already proposes extending lint-routing-wiring.sh, which currently validates declared AGENT names but not SKILL names. Read that task's description in specs/state.json first. The checks are genuinely additive rather than duplicative, and the current coverage matters: lint-routing-wiring.sh already has Check A (routing.{op} keys have routing_agents.{op} counterparts), Check B (routing_agents/routing_agents_hard values name existing agent files), Check C (routing_hard.{op} keys have routing_agents_hard.{op} counterparts), and Check D (report-only general-* declarations). Check C therefore ALREADY covers the within-manifest hard counterpart requirement. What is missing is a new check for 'declares routing but no routing_hard at all' - additive to that task's Check B skill-name extension. Both edit the same file, so declare a dependency or otherwise serialize with it rather than duplicating its work or racing it.

ACCEPTANCE: a single documented decision among (a)/(b)/(c) with its reasoning recorded; --hard delivers the H2-H5 contracts to agents for every non-exempt extension without requiring per-invocation hand-injection by the orchestrator; any lint check added skips routing_exempt manifests and does not duplicate the sibling task's skill-name validation; CLAUDE.md's claim that --hard is composable with extension routing is either made true or corrected to match reality.

RELATED BUT DISTINCT - DO NOT ABSORB. The typst/latex task-type restriction task in this repo concerns which task type a task is ASSIGNED from keywords, not which agent or contracts a type resolves to. No file overlap with this task's resolver and lint scope, though note that if option (a) is chosen it would edit the typst and latex manifests, which that task also touches (different keys: keyword_overrides/aliases there, routing_hard/routing_agents_hard here) - coordinate if (a) is selected.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 63. Fix the agent-side hard-mode routing downgrade that discards declared domain agents
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None
- **Research**: [063_fix_hard_mode_agent_routing_downgrade/reports/01_agent-routing-hard-mode-parity.md]
- **Plan**: [063_fix_hard_mode_agent_routing_downgrade/plans/01_fix-hard-mode-agent-routing.md]
- **Summary**: [063_fix_hard_mode_agent_routing_downgrade/summaries/01_fix-hard-mode-agent-routing-summary.md]

**Description**: Fix the agent-side hard-mode routing downgrade. command-route-agent.sh, given effort_flag=hard and a task_type whose extension declares no routing_agents_hard, falls through to the caller-supplied default_agent and DISCARDS the extension's declared standard agent. So --hard routes strictly worse than no flag, losing the domain agent entirely.

VERIFIED EVIDENCE (reproduced independently against the source store with ROUTE_MANIFEST_ROOT=agent-system; do not re-derive). Originally observed in a live /research --fable --lit --hard invocation in the Logos/Theory repo:
  op=research task_type=formal:logic effort=hard resolved=general-research-agent via=default
  op=research task_type=formal:logic effort=     resolved=logic-research-agent   via=noncore-exact
The defect is NOT compound-key-specific. The same downgrade reproduces on a simple task_type:
  op=research task_type=typst        effort=hard resolved=general-research-agent via=default
  op=research task_type=typst        effort=     resolved=typst-research-agent   via=noncore-exact
It therefore affects every extension that declares routing_agents but no routing_agents_hard (14 extensions; see the companion contract-delivery task in this batch for the verified inventory).

THE DECISIVE FINDING - THIS IS A PARITY DEFECT, NOT A DEBATABLE FALLBACK. The two resolvers that were consolidated onto the shared ladder kept DIVERGENT fallback policies, and the skill-side resolver already implements the correct never-worse-than-standard behavior:
  - command-route-skill.sh (lines ~57-65) resolves the standard SKILL_NAME FIRST, then on hard mode only UPGRADES it: a routing_hard hit wins; else a '-hard'-appended candidate is used only if its SKILL.md exists on disk (via=hard-append-fallback); else it KEEPS the standard skill and emits via=hard-miss-standard-fallback. Standard resolution is never discarded.
  - command-route-agent.sh (lines ~62-68) computes ONLY the hard block, then unconditionally overwrites with AGENT_NAME="$_route_default_agent"; _route_via="default". The extension's declared standard agent is never consulted at all.
So the fix is to bring the agent side to parity with the already-correct skill side, not to invent new policy. Note also that the agent script's own header justifies the fall-through as "matching the behavior of the case tables this script replaces" - i.e. it was a conservative do-no-harm choice made during a consolidation refactor, NOT a considered design decision that domain agents should be discarded. That is the evidence bearing on whether the documented intent or its consequence is the thing that is wrong. Establish that explicitly, then fix accordingly.

LIKELY CORRECT LADDER: routing_agents_hard -> the extension's routing_agents -> default_agent. This preserves the documented intent (a caller's own hard-mode default such as general-research-hard-agent is still honored on a genuine total miss where no extension declares anything) while no longer discarding a declared domain agent.

BINDING CONSTRAINT - AN EXISTING TEST PINS THE CURRENT BEHAVIOR AS CORRECT AND MUST BE AMENDED. agent-system/extensions/core/scripts/tests/test-routing-resolution.sh Assert 3 (semantic) iterates `for tt in neovim nix` and asserts hard-mode research resolves to the caller default, failing with "expected fall-through to caller default"; its header frames standard-block reuse as "a precedence-direction / fallback-source regression". The fix necessarily amends that assertion. Keep Assert 3's lean4 half intact - it still validly proves hard mode reads a DISTINCT block (lean4 standard resolves lean-research-agent, hard resolves lean-research-hard-agent). Also note `nix` is itself one of the 14 extensions lacking hard blocks, so if the companion task later declares hard blocks for nix, that fixture's meaning shifts again; leave a comment in the test recording this coupling.

SCOPE (source store only, never .claude/**): agent-system/extensions/core/scripts/command-route-agent.sh (the primary change), agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh (the shared ladder, only if the fix genuinely belongs there rather than in the consumer), and agent-system/extensions/core/scripts/tests/test-routing-resolution.sh. Consider adding the via=hard-miss-standard-fallback vocabulary to the agent-side trace so the agent and skill resolvers report the same diagnostic shape.

ACCEPTANCE: --hard never resolves to a less specific agent than the same call without --hard, for all 19 extensions; the caller-supplied hard default is still honored where no extension declares anything for that (op, task_type); lean4 still resolves lean-research-hard-agent under --hard; the routing test suite is green with Assert 3 amended to pin the corrected contract rather than the defect.

RELATED BUT DISTINCT - DO NOT ABSORB. The typst/latex task-type restriction task in this repo governs WHICH task type gets assigned from keywords (manifest keyword_overrides/aliases, /task's keyword table, meta-keyword precedence). This task governs WHICH AGENT a given task type resolves to under --hard. No file overlap. They compound, though, and that is worth knowing: a content-bearing task misfiled as typst AND run with --hard currently loses both the correct domain agent and the hard contracts.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 62. Restrict typst latex task types to formatting only
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [062_restrict_typst_latex_task_types_to_formatting_only/reports/01_restrict-latex-typst-formatting-only.md]
- **Plan**: [062_restrict_typst_latex_task_types_to_formatting_only/plans/01_restrict-latex-typst-formatting-only.md]
- **Summary**: [062_restrict_typst_latex_task_types_to_formatting_only/summaries/01_restrict-latex-typst-formatting-only-summary.md]

**Description**: Restrict typst and latex task types to formatting-only concerns. Identify what in the agent extension system needs revision so that the 'typst' and 'latex' task types are assigned ONLY when a task is concerned purely with formatting/typesetting issues, not with the intellectual content of what is being formatted. Investigation should cover: keyword_overrides and aliases in the typst/latex extension manifests, the hardcoded keyword table in /task step 4d ('latex', 'tex', 'document', 'typeset' -> latex; 'typst' -> typst), the interaction with the meta-keyword precedence rule in step 4a, alias remapping in step 4e, and any routing or documentation that assumes content-bearing work routes to these types. Produce the concrete revisions needed (manifest edits, keyword table changes, precedence adjustments, docs) so content-focused tasks route to a substantive task type instead.

---

### 61. Surface coarse and duplicate file_scope declarations at task-creation time
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 59
- **Research**: [061_surface_coarse_file_scope_declarations_at_creation/reports/01_coarse-file-scope-detection.md]
- **Plan**: [061_surface_coarse_file_scope_declarations_at_creation/plans/01_coarse-file-scope-advisory.md]
- **Summary**: [061_surface_coarse_file_scope_declarations_at_creation/summaries/01_coarse-file-scope-advisory-summary.md]

**Description**: Treat whole-directory-root file_scope declarations as a declaration-quality problem caught at task creation, rather than as a runtime blocker discovered only when /orchestrate silently excludes a candidate.

MOTIVATING EXAMPLE (real, from the live incident): a BimodalLogic documentation task named update_readme_and_module_docstrings declares ["README.md", "ROADMAP.md", "FormalSystem/", "FormalSystem/", "docs/"]. Note that FormalSystem/ appears TWICE. That single declaration exhibits both defects at once - a whole-directory root that swallows essentially every Lean task in the repo, and an exact duplicate entry. This repo has the same pattern: one idle task declares the bare directories commands/ and skills/, and another declares the bare directory context/.

WORK:
1. Flag whole-directory-root declarations (a bare top-level or near-top-level directory) at task creation and in state validation, with a warning that names the concrete blast radius - how many existing non-terminal tasks the declaration would overlap - rather than a generic caution.
2. Detect and de-duplicate exact duplicate file_scope entries.
3. Keep this advisory at creation time, not blocking. The point is to fix declaration quality upstream, not to add a second runtime gate.

Relationship to the predicate task in this batch: that task stops coarse declarations from silently blocking dispatch; this task stops them from being written in the first place. Both are needed - the predicate fix alone leaves declaration quality unaddressed, and this task alone does nothing about the declarations already sitting in state.

COLLISION WORKAROUND: this task's declared scope overlaps two idle tasks in this repo - one declaring commands/task.md exactly, and one declaring the bare directory commands/. Workaround dependencies[] edges have been written onto those two colliding tasks pointing AT this task - deliberately that direction, because writing them onto this task instead would block it until both completed, which is backwards.

WORKAROUND EDGES (remove once the admission-gate predicate fix is deployed): the dependencies[] edges added to the colliding tasks named above are artifacts of the very defect this batch fixes, not genuine ordering constraints. They exist only to dissolve the cross_batch file_scope collision that would otherwise permanently exclude this task from /orchestrate. Once the predicate fix is implemented and deployed, the collision no longer fires against idle tasks and every one of these edges must be removed.

---

### 60. Thread the evidence-gated verdict and --allow-scope-collision through admission consumers
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 59
- **Research**: [060_thread_evidence_gated_verdict_through_admission_consumers/reports/01_thread-evidence-gated-verdict.md]
- **Plan**: [060_thread_evidence_gated_verdict_through_admission_consumers/plans/01_thread-evidence-gated-verdict.md]
- **Summary**: [060_thread_evidence_gated_verdict_through_admission_consumers/summaries/01_thread-evidence-gated-verdict-summary.md]

**Description**: Consumer-side half of the batch-admission gate redesign. The predicate task in this batch changes the admission predicate and bumps the verdict schema to v5; this task updates every consumer that branches on it.

WORK:
1. Render the new advisory field emitted for provably-idle overlaps in the dispatch-path warning and in the batch results surface. The advisory must be loud - advisory never means unlogged or silent.
2. Add an --allow-scope-collision per-invocation override, symmetric with the existing --allow-self-modifying. Thread it parser -> command -> both orchestrate skills. It must NEVER be passed to orchestrate-batch-admit.sh, which always computes and emits the honest verdict regardless; the override is a consumer decision not to ACT on an emitted verdict, with a loud bypass notice logged either way. Defaults off, per-invocation only. No override for file_scope_collision was ever considered and rejected in the corpus - this is a genuinely open addition, not a reversal of a recorded decision.
3. Fold orchestrate-predispatch-review.sh's EXISTING Class D dependencies[]-edge suggestion into the dispatch-path warning. Class D already emits a suggestion to add the predecessor as a dependencies[] entry; the gap is only that it lives in a separate review surface rather than where the exclusion is actually reported. Do not build a new suggestion mechanism.
4. Correct the false self-clearing claims. skill-orchestrate/SKILL.md claims BOTH collision branches become eligible again on a later cycle, which is false for cross_batch. The corpus is three-way contradictory here: the schema doc instead says the out-of-batch task is idle and will not advance on its own so a human resolves batch composition, while commands/orchestrate.md says the candidate is excluded from this run. Make all three agree with the post-fix behavior.
5. Fix the stale schema-v3 prose in the two consumer files that still say v3 while emitting v4 (v5 after this batch).

Co-maintenance: skill-orchestrate and skill-orchestrate-hard are transcription twins - every consumer change must land in both.

This task declares orchestrator-critical paths and is therefore self_modifying, requiring solo dispatch. Expected and accepted.

COLLISION WORKAROUND: this task's declared scope overlaps four idle tasks in this repo - two that declare skills/skill-orchestrate/SKILL.md, one that declares the bare directories commands/ and skills/ (which swallow this scope entirely), and one that declares the bare directory context/. Under the current gate this task would be permanently excluded from /orchestrate by the very defect it fixes. Workaround dependencies[] edges have been written onto those four colliding tasks pointing AT this task - deliberately that direction, because writing them onto this task instead would block it until all four completed, which is backwards and defeats the purpose.

WORKAROUND EDGES (remove once the admission-gate predicate fix is deployed): the dependencies[] edges added to the colliding tasks named above are artifacts of the very defect this batch fixes, not genuine ordering constraints. They exist only to dissolve the cross_batch file_scope collision that would otherwise permanently exclude this task from /orchestrate. Once the predicate fix is implemented and deployed, the collision no longer fires against idle tasks and every one of these edges must be removed.

---

### 59. Gate cross-batch file_scope collisions on execution evidence, not non-terminal status
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None
- **Research**: [059_narrow_cross_batch_collision_to_execution_evidence/reports/01_narrow-cross-batch-collision.md]
- **Plan**: [059_narrow_cross_batch_collision_to_execution_evidence/plans/01_narrow-cross-batch-collision.md]
- **Summary**: [059_narrow_cross_batch_collision_to_execution_evidence/summaries/01_narrow-cross-batch-collision-summary.md]

**Description**: The /orchestrate batch-admission gate's specs/state.json collision dimension defers a candidate against ANY non-terminal task whose file_scope overlaps it with no dependencies[] edge. Because a cross_batch defer can never self-clear (an idle task's status cannot change without a dispatch), any broad-scoped not_started task becomes a permanent blanket blocker. Observed in the BimodalLogic repo: an /orchestrate invocation permanently excluded a candidate on every cycle because an idle documentation task declaring the whole FormalSystem/ directory overlapped it. That colliding task held no lock, had no live session-registry entry, and could not have been editing anything; corroborated_by named non_terminal_status as the sole basis for the defer.

ROOT CAUSE (verified during investigation): the dimension conflates ORDERING (both tasks will eventually touch these files, so one should land before the other) with CONCURRENCY (two agents are writing these files right now). Ordering belongs in dependencies[]; concurrency is already handled correctly by task-lock.sh and the v4 session_active dimension, whose session_contention() def in scripts/lib/file-scope-overlap.sh already gates on liveness via pid-alive / heartbeat staleness. Decisive evidence that this is an undeclared-ordering check rather than a genuine conflict check: adding a dependencies[] edge dissolves the collision entirely, which no real concurrent-write hazard could permit.

Two further findings confirm the strictness was never actually derived. First, the blocking rationale in batch-admit-schema.md is self-refuting within a single sentence: it justifies the block as 'two sessions can concurrently edit the same files with no lock contention' while parenthetically conceding 'the colliding task holds no lock; it simply is not running'. Second, batch-orchestration-guardrails.md's Blocking-vs-Advisory decision table has NO cross_batch row at all - its file-scope row covers only the creation-time and runtime wave/cycle-split (in_batch) case. The verification-gap hazard does not defend this dimension either: the guardrails explicitly state it is 'UNAFFECTED BY THE SCOPE CHOICE IN EITHER DIRECTION' and scope it to self-modification.

SCOPE OF FIX (deliberately narrow): narrow the state.json dimension's defer condition to actual execution evidence - an in-flight status in {researching, planning, implementing}. Live-session coverage stays session_active's job and must not be duplicated here. A provably-idle overlap becomes an admit verdict carrying a loud advisory field rather than a defer; the advisory must never be silent. in_batch behavior stays blocking and unchanged bit-for-bit, because both candidates there are genuinely about to be dispatched, which does satisfy the Blocking-vs-Advisory criterion. Bump the verdict schema to orchestrate-batch-admit-v5, correct the self-refuting rationale, and add the missing cross_batch row to the Blocking-vs-Advisory table.

This narrowing is evidence-gating, not batch-size-gating, so it does not conflict with the guardrails' standing rejection of relaxing a blocking check as batch size grows. The shared overlap predicate is NOT changed: file-footprint-overlap.md explicitly disclaims any opinion on scan scope, so this is a comparison-set filter change only. Only three files pin the schema version string, so the version bump has a narrow blast radius, but consumers branching on defer_reason are updated separately by the consumer-side task in this batch.

This task declares orchestrator-critical paths and is therefore self_modifying, requiring solo dispatch. Expected and accepted.

CLOSING STEP: after this task is implemented AND deployed, remove the workaround dependencies[] edges recorded on the four colliding tasks in this repo's state (the ones pointing at this batch's three task numbers). Those edges exist only to work around the defect this task fixes and must not outlive it.

WORKAROUND EDGES (remove once the admission-gate predicate fix is deployed): the dependencies[] edges added to the colliding tasks named above are artifacts of the very defect this batch fixes, not genuine ordering constraints. They exist only to dissolve the cross_batch file_scope collision that would otherwise permanently exclude this task from /orchestrate. Once the predicate fix is implemented and deployed, the collision no longer fires against idle tasks and every one of these edges must be removed.

---

### 53. Suppress expected handoff absence defect
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: None

**Description**: Stop recording a spurious HANDOFF_STALE_OR_ABSENT system defect when a contractual non-writer leaves no fresh handoff. Observed live on a clean, fully-successful base-mode /orchestrate run (recorded as evt_1786550950625_o2KoSv; the class already has 3 occurrences in specs/events.jsonl).

OBSERVED MECHANISM (verified, do not re-derive). In a base-mode /orchestrate run of a task that entered at [RESEARCHED], the plan dispatch wrote .orchestrator-handoff.json carrying dispatch_seq=1. The implement dispatch that followed wrote no handoff, correctly: docs/architecture/handoff-schema.md's "Handoff Writers" table settles that .orchestrator-handoff.json is hard-mode-implement-only, and general-implementation-agent.md states "base-mode implement is a non-writer by design". Nothing clears the prior cycle's handoff, so the planner's file was still sitting at the path when Stage 5 ran. Both freshness gates fired on it exactly as designed -- mtime predated the dispatch window, and dispatch_seq=1 did not match the minted dispatch_seq=2 -- and the dispatch_seq gate recorded a HANDOFF_STALE_OR_ABSENT system defect. The run then proceeded correctly: orchestrate-recover-outcome.sh recovered status=implemented, 7/7 phases, from .return-meta.json, and the task completed.

THE DEFECT IS ORDERING, NOT DETECTION. The gates are right and must not be weakened -- they are the identity mechanism delivered by the handoff-identity work, and they are the reason a genuine late-writer clobber would be caught. The bug is that the recording happens BEFORE the system consults whether the absence was expected. skill-orchestrate/SKILL.md's own recovery branch prints "no handoff written for this dispatch -- expected outcome for this phase's writer (base-mode research/plan/implement never write one)". The knowledge that this is expected already exists in the file; it just arrives one step too late to suppress the defect record. The recorder therefore fires on a run in which nothing went wrong.

WHY THIS MATTERS BEYOND NOISE. A defect class that fires on ordinary success carries no information, and a real stale-handoff incident becomes indistinguishable from routine base-mode operation. This is the same failure shape as the gate-out warning that cannot separate silent failure from ordinary success, tracked separately. It also directly bears on the open question of whether "zero defect events on a clean run" is a sound acceptance bar, tracked in the verification-trust bundle: that item assumes the recorder only fires on genuine agent-compliance slips. This observation falsifies that assumption and should be folded in as evidence when that decision is made.

SECOND, INDEPENDENT QUESTION -- DECIDE EXPLICITLY. Base-mode dispatch contexts pass handoff_path to every dispatch (research, plan, and implement alike), which invites a contractual non-writer to write a handoff at all. That is how the planner came to write one in the observed run. Decide whether base mode should stop passing handoff_path except where a writer is contractually expected, or whether passing it uniformly is deliberate and the leftover file should instead be cleared or rotated at dispatch start. Either resolution is acceptable; the current arrangement, where a non-writer is handed a write target and its output then trips the successor's freshness gates, is not.

CANDIDATE DIRECTIONS (evaluate, do not blindly adopt): (a) consult the writer contract before recording -- if the dispatched writer is contractually a non-writer for this mode and phase, treat a stale-or-absent handoff as the expected outcome and log it without recording a defect; (b) clear or rotate any pre-existing handoff at dispatch start so the gates only ever fire on a genuine late write from a live predecessor; (c) narrow handoff_path propagation to contractual writers. Note that (b) alone must not blind the gates to the live-predecessor late-write case, which is the hazard they exist to catch.

CO-MAINTENANCE (binding). skill-orchestrate/SKILL.md and skill-orchestrate-hard/SKILL.md carry an explicit co-maintenance contract, and the Stage 5 staleness/dispatch_seq gate is a verbatim twin across the two. A one-sided fix here reproduces a named recurring defect class. Both copies must be changed together, or the asymmetry recorded in both.

ACCEPTANCE: a clean base-mode /orchestrate run that transitions plan to implement records no system defect; a genuine stale or late-written handoff still trips the gates and still records one; and both engines agree. Demonstrate both directions -- a detector that can only ever stay silent is not a fix.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== EVIDENCE ADDED 2026-08-24 (the live-predecessor case, observed for real) ===
CONFIRMING, NOT CONTRADICTING. This task's candidate direction (b) carries the caveat that
clearing or rotating a stale handoff at dispatch start "must not blind the gates to the
live-predecessor late-write case, which is the hazard they exist to catch". That hazard has now
been OBSERVED LIVE rather than merely anticipated, and the observation should be treated as a
binding test case for whichever direction is adopted.

OBSERVED MECHANISM (verified, do not re-derive). In a seven-task lean4 batch in a separate
consumer repo, an implementation dispatch (minted dispatch_seq=19) went quiet for ~25 minutes
after writing a wrap-up summary. It was judged terminated and the task was re-dispatched as a
resume (minted dispatch_seq=22). The ORIGINAL dispatch was in fact still alive: it then completed
and wrote .orchestrator-handoff.json claiming status=implemented, 5/5 phases. Its mtime was NEWER
than the resume dispatch's own window start, so THE MTIME FRESHNESS GATE PASSED IT. Only the
dispatch_seq comparison (19 against the minted 22) exposed it as a predecessor's late write.
Recorded as evt_1787614360544_SgKpRP. The resume subsequently wrote its own seq-22 handoff and
that report was taken as authoritative.

WHY THIS IS DECISIVE FOR THE DESIGN CHOICE. It is a direct, non-hypothetical demonstration that
mtime alone is insufficient and that dispatch_seq is load-bearing, exactly as
context/patterns/dispatch-report-not-termination.md argues. Any resolution of this task that
suppresses or reorders the recording MUST still surface this case. Specifically: direction (a)
(consult the writer contract before recording) is safe here only if "contractual non-writer"
is evaluated per dispatch identity and not per phase alone -- an implement dispatch that IS a
contractual non-writer in base mode still produced a real seq-mismatched clobber in this
incident, so a contract-only check keyed on phase would have silently swallowed it.

SECONDARY OBSERVATION, RELEVANT TO THE ACCEPTANCE BAR. This task notes the open question of
whether "zero defect events on a clean run" is a sound acceptance bar and asks that this
observation be folded in as evidence. Add this one too, pulling in the opposite direction: the
run above was NOT clean, and the single recorded defect event was the only signal distinguishing
a predecessor clobber from a normal report. A bar of "zero defect events" is sound only if the
genuine-incident channel stays as loud as it is today.

---

### 51. Move session state files out of specs root
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Move per-session state files cluttering the specs/ root (.orchestrator-multi-state-sess_* and .return-meta-*.json files) into a dot-prefixed directory, or handle otherwise as most appropriate

---

### 50. Restore verification trust and close hygiene residue
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 48

**Description**: === REVISED 2026-08-24 (refactor survey) ===
SPLIT AND REDUCED. Item 1 -- the non-deterministic shell test suite -- has been extracted into its own task (deflake_shell_test_suite_under_concurrency) because it is the highest-value piece here by a wide margin: until the suite is deterministic, no acceptance gate in this repo is trustworthy in either direction, including this task's own. Do not work it here.
WHAT REMAINS is hygiene residue, and the measurements below are updated -- most of it DEGRADED since filing, which is the point:
- session-ID one-liner: 43 -> 48 files (46 of them .md). Note the gate for this exists but greps only *.sh, so it has been green throughout; the gate fix is owned by the duplication-gate task, so sequence after it rather than duplicating the migration here.
- jq #1132 block: 34 -> 36 files.
- @.claude/docs stylistic refs: 6 -> 15 occurrences.
- literature-retrieve.sh: still declared in core/manifest.json:134 despite its own header reading DEPRECATED with zero automated callers, while a 9-script scripts/deprecated/ quarantine directory sits right there. Straight quarantine-convention miss.
- topic taxonomy: PARTLY SELF-HEALED. The used-but-undeclared side is now 0. But declared-but-unused grew to TEN orphan topics: commit-scoping-concurrency, context-loading, cslib, mcp-integration, memory-improvement-loop, neovim, orchestrate-admission-gate, status-marker-lifecycle, wezterm-notifications, workflow-refactor. (Note status-marker-lifecycle is no longer an orphan -- the plan-status task now carries it.)
- ROADMAP.md: unmodified since 2026-07-12. NONE of its 11 items maps to any active task, and its success metric says '14 extensions' against 19. Rewrite it to describe work actually in flight, or delete it -- a roadmap that describes nothing is worse than no roadmap, because /review's roadmap-integration step dutifully annotates it.
Verification-surface items from the original scope are superseded by the CI-expansion and deploy-verification tasks; check for overlap before starting and drop anything they already cover.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Make the verification surface trustworthy, and close the doc-truth and duplication residue. Grouped because each item individually is too small to dispatch, and all of them undermine confidence in the same gate suite.

(1) THE SHELL TEST SUITE IS NON-DETERMINISTIC (highest value item here). Measured across five consecutive runs of scripts/tests/run-all.sh: exit 1, 0, 1, 0, 0 -- roughly a 2-in-5 failure rate, with passing runs reporting a clean 36/36. During the same review, verify-deploy.sh gate 8 passed while a standalone run failed minutes later. A gate that passes 60% of the time is not evidence of health in either direction. It is also actively harmful to the refactor's own acceptance gate: the capstone attributed a real failure to "a flaky lock-contention test attributable to concurrent sibling sessions, not a deploy defect" WITHOUT being able to confirm that, precisely because the suite cannot distinguish the two. Diagnose the contention (the suite runs concurrently with other live sessions holding the same locks), then either isolate the affected tests from shared global state or make them wait deterministically. A test that is merely retried is not fixed. ACCEPTANCE: 10 consecutive runs, executed while at least one other session is active, all report the same result.

(2) THE DEPLOY NON-DETERMINISM FINDING HAS NO OWNER. The capstone's defect ledger dispositions err_1786350581240_JyztWt (deploy_nondeterministic_merge) as "folds into" the orphan-file parity task, and leaves err_1786350581208_23mAsn (deploy_merge_content_loss, observed once, then 0-of-3 on re-check) as entry-only. The parity task's actual text discusses only the four orphan files -- it never mentions ordering or content loss. The fold was recorded but never performed, so capstone DEPLOY sub-item ii ("running the deploy twice is byte-identical") is failing with nobody assigned. A fold recorded but not performed is exactly the failure mode a defect ledger exists to prevent; note that as a process finding, not only a technical one. WORK: run the scratch wipe-pair procedure, establish whether context/index.json and settings.json still differ by object-key/array-element ordering beyond the expected generated timestamp, re-check the settings.local.json content-loss observation, and either fix the ordering non-determinism or record an explicit decision that semantic equality under `jq -S` is the standard and byte-identity is not required. Either resolution is acceptable; the current silent ambiguity is not.

(3) RE-SCOPE OR SATISFY THE LIVE-CYCLE DEFECT CRITERION. The capstone requires that a clean orchestration cycle emit no system_defect event and that the deferred-defect surface render empty. specs/events.jsonl now holds 5 such events (3 from 2026-08-08 plus 2 newer: OFF_SCHEMA_STATUS and META_MISSING_AFTER_NARRATION). Both new events are correctly-firing detectors catching real agent-compliance slips -- the recorder working as designed, not noise. DO NOT FIX THOSE TWO DEFECTS HERE: the OFF_SCHEMA_STATUS handoff-key problem belongs to the in-flight handoff identity-contract task, and META_MISSING_AFTER_NARRATION belongs to the in-flight nonterminal-fanout task. Both should have the observation appended to them. What is unowned, and what belongs HERE, is the criterion itself: decide whether "zero defect events on a clean run" is the right acceptance bar given a recorder that will legitimately fire whenever any agent slips, or whether it should be re-scoped to "no NEW defect classes" -- the same precedent the capstone already set for its unverifiable gate-out criterion. Record the decision where the acceptance criteria live.

(4) DUPLICATION WITH AN AVAILABLE SHARED MECHANISM. (a) The literal one-liner `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')` appears 43 times across 35 command and skill files, while common_session_id() exists in scripts/lib/common.sh and is already wired into command-gate-in.sh. (b) The jq Issue #1132 safety block appears in 34 source files against a canonical home in context/patterns/jq-escaping-workarounds.md and a CLAUDE.md section -- roughly 8 KB of duplication, and 8 of those copies sit inside present/ skills where they are per-invocation cost. Replace both with calls/pointers. Note that some sites may not be convertible where sourcing common.sh a second time is genuinely awkward; name any residual rather than forcing it.

(5) DEAD AND UNDOCUMENTED MACHINERY. (a) scripts/literature-retrieve.sh (7.9 KB) is deprecated by its own header ("superseded by literature-briefing.sh ... Do not add new usages"), has zero automated callers, yet is still declared in the core manifest's provides.scripts and therefore deploys every time. This repository already runs a rigorous quarantine-never-delete convention -- scripts/deprecated/ holds 11 such scripts, removed from provides so they never deploy -- and this one file simply missed the process. Put it through the same process. (b) /zulip and skill-zulip are live and deployed but have zero mentions in the generated CLAUDE.md: no Command Reference row, no extension section. (c) scripts/check-runtime-file-tracking.sh is legitimately operator-invoked-only, like its five documented siblings, but is missing from CLAUDE.md's Utility Scripts table, so a future dead-code sweep will flag it as an orphan. (d) Six `@.claude/docs/...` references remain in meta-builder-agent.md, context/architecture/system-overview.md, context/architecture/component-checklist.md and context/patterns/thin-wrapper-skill.md; they carry no runtime cost, but they model the exact syntax the context-loading audit spent a phase normalizing away.

(6) TAXONOMY AND ROADMAP DRIFT. specs/state.json's active_topics omits `context-loading` and `email`, both live topics on existing tasks, so generate-task-order.sh renders them through its append-extras path with a stderr warning instead of in curated order; meanwhile seven declared topics now have zero tasks. Separately, specs/ROADMAP.md no longer describes the work in flight -- its Phase 1 is documentation-infrastructure items that appear nowhere in the active task set, and its Success Metrics cite a task number and an extension count from a previous era. Because /review's roadmap-integration step annotates against this file, a stale roadmap makes that step a guaranteed no-op. Reconcile the topics and rewrite the roadmap to describe the actual workstreams.

NEGATIVE FINDINGS -- DO NOT RE-INVESTIGATE THESE. A caller analysis across all 138 scripts and hooks found only literature-retrieve.sh dead; the rest have live callers, including ones reachable only through skill-base.sh's dynamic hooks[$hook_name] manifest lookup and run-all.sh's glob discovery. All 193 files under context/ have live references and are enrolled in context/index.json, a real dynamic-discovery layer -- there are no orphans there and no bytes to recover. docs/ (455 KB) costs zero runtime tokens: CLAUDE.md references it only by backticked path, never @-import. Recording these so they are not re-derived.

THIS TASK IS A BUNDLE AND IS A REASONABLE CANDIDATE FOR EXPANSION -- items 1-3 are verification trustworthiness, items 4-6 are hygiene. If driven as one unit, commit them as separate phases.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 48. Propagate scoped commit to all call sites
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None

**Description**: Propagate the scoped-commit fix to the 65 call sites it never reached. This is a correctness/safety task, not a cleanup task.

THE MECHANISM ALREADY EXISTS AND IS CORRECT. scripts/git-commit-scoped.sh describes itself as "the single sanctioned implementation of the scoped-commit contract". It was built to close a documented concurrency defect: a bare `git commit` sweeping in a file that another concurrently-running agent had staged but not yet committed. The fix is sound. Adoption simply stopped.

MEASURED STATE: 85 occurrences of raw `git commit -m` across 70 command/skill files in the source store. Only 5 files call git-commit-scoped.sh -- skill-implementer, skill-planner, skill-team-implement, skill-orchestrate, and commands/orchestrate.md. The remaining 65 files still hand-roll the vulnerable raw form, including the highest-traffic core commands: research.md, plan.md, implement.md, todo.md, task.md, errors.md, review.md.

WHY THIS IS NOT THEORETICAL: the review that produced this task ran with eight concurrent Claude sessions active on the same machine, several in this same repository. Under that load every /research, /plan, /task, /todo, /errors and /review commit is currently capable of capturing another session's staged work. Concurrent multi-session operation is the normal working mode here, not an edge case.

THIS IS ALSO THE SHARPEST LIVE INSTANCE of the "duplicated mechanism instead of shared mechanism" root cause named in the opening refactor review. Unlike most instances of that pattern, the shared mechanism here is already written, already tested, and already proven at 5 sites -- so the work is propagation and verification, not design.

WORK: migrate call sites to git-commit-scoped.sh, highest-traffic first. Suggested ordering: (a) core commands research.md, plan.md, implement.md, todo.md, task.md, errors.md, review.md; (b) remaining core skills; (c) non-core extension commands and skills (founder, present, filetypes, lean, web, epidemiology, literature, memory, cslib).

DO NOT MECHANICALLY REWRITE ALL 85 SITES. Some call sites may legitimately differ -- a commit whose staging scope is genuinely not task-scoped, or a test fixture that must exercise the raw form. Inspect each; where a site should NOT be migrated, record why in the summary rather than silently skipping it. A migration that converts 85 of 85 without noting a single exception is more likely to be careless than thorough.

ALSO SETTLE: whether the raw form should be blocked mechanically once migration lands (a lint in the verify-deploy gate list, in the same family as lint-state-writer-boundary.sh, which already polices the analogous state.json write boundary). Without such a gate the pattern regrows on the next new command. If a lint is added, it must exempt git-commit-scoped.sh itself and its tests.

ACCEPTANCE: `grep -rl 'git commit -m' agent-system/extensions/` returns only git-commit-scoped.sh and its test files, or returns additional files each of which is named in the summary with a stated reason for exemption. Existing test suites still pass. At least one migrated command is exercised end-to-end (a real commit through the converted path) rather than only inspected statically.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 46. Fix present extension compound skill routing
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Fix present extension compound-skill routing so /implement resolves to a real skill. The present manifest's routing.implement declares "present:grant" -> "skill-grant:assemble" and "present:slides" -> "skill-slides:assemble", but the shared routing resolver (scripts/lib/manifest-routing-lib.sh, consumed via command-route-skill.sh) returns those values verbatim with no colon splitting, and no skill directories named skill-grant:assemble or skill-slides:assemble exist -- only skill-grant and skill-slides do. Running /implement on a present:grant or present:slides task therefore resolves SKILL_NAME to a nonexistent skill (verified: resolver returned skill-grant:assemble via noncore-exact). skill-grant/SKILL.md documents "assemble" as a workflow_type value, not part of the skill name, so the manifest is encoding skill + workflow_type in one field that no consumer ever splits. Decide whether the fix belongs in the manifest (drop the :suffix and carry workflow_type another way) or in the resolver (split on the first colon and expose the suffix as a workflow_type/sub-mode variable), implement it, and add a lint check so any routing or routing_hard value naming a nonexistent skill fails verify-deploy -- lint-routing-wiring.sh currently validates declared agent names but not skill names. Scope is exactly 2 occurrences, both in agent-system/extensions/present/manifest.json under routing.implement; present declares no routing_hard, and no other extension uses colon-bearing routing values. Found during a deploy-integrity audit of the Logos/Theory repo.

---

### 45. Global update extension repo registry
- **Status**: [NOT STARTED]
- **Task Type**: general
- **Topic**: extensions
- **Dependencies**: None

**Description**: Implement <leader>al repo registration and 'Global Update' action: when <leader>al loads extensions into other repos, register those repos and their loaded extensions in this nvim repo; add a 'Global Update' entry (similar to 'Reload All') that reloads all extensions already loaded in each registered repo, reporting any failures in a message and otherwise success as a count of the total

---

### 44. Slim commands/task.md, the largest per-invocation context contributor
- **Effort**: 2-4 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 62
- **Research**: [044_slim_task_command_body/reports/01_command-body-extraction-approach.md]
- **Plan**: [044_slim_task_command_body/plans/01_task-command-mode-extraction.md]

**Description**: LOWER PRIORITY (per-invocation cost, not per-session). `commands/task.md` measures 37,465 bytes (~9.4k tokens) loaded on every `/task` invocation, plus ~2.8k tokens of imports it pulls in — the largest single per-invocation context contributor found by the context-loading audit. Slim the command body by moving reference material (long option tables, worked examples, edge-case narratives) into lazily-loaded context files under the core extension's context tree, keeping the command body to the decision logic and dispatch instructions an invocation actually needs. Preserve behavior: every mode (--recover, --expand, --sync, --abandon, multi-task creation) must remain fully specified — either inline or via an explicit pointer the executing agent is instructed to follow. Measure before/after bytes and record them in the implementation summary. CONSTRAINTS: all edits target agent-system/extensions/core/** (source store), never the deployed .claude/** tree; no task-number references in deliverables outside specs/**; do not change command behavior, only where its prose lives.

---

### 43. Decide and implement how email safety context actually reaches agents (live defect: five inert safety pointers)
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None

**Description**: LIVE DEFECT, not an efficiency item: the email extension's five 'non-negotiable' safety context pointers (safety-invariants.md, wrapper-contracts.md, index-architecture.md, staleness-detection.md, archive-mode-risk.md) were written as `@.claude/context/...` imports in the merge-source era — a form that resolves to a nonexistent path and silently loads NOTHING. They have since been normalized to plain backticked paths (still non-loading by design), so the question the audit deferred is now unavoidable: how does safety-invariants.md actually reach an agent before it mutates a mailbox? Decide deliberately between: (a) making the safety pointers genuinely eager in the email extension's CLAUDE.md contribution, accepting roughly 13k tokens of every-session cost in deploys where email is loaded; (b) establishing that the wrapper contracts (five nix-built wrapper binaries as the only mutation path) plus the email skills'/agent's own explicit context-loading instructions already carry the enforcement, and recording that as the documented decision; or (c) a middle path such as eager-loading ONLY safety-invariants.md (the smallest, most critical file) while the rest stay lazy. Verify empirically what skill-email-cleanup, skill-email-sync, and email-implementation-agent load today before choosing. Whatever the choice, record it in the email extension's docs so the next audit does not re-litigate. CONSTRAINTS: all edits target agent-system/extensions/** (source store); no volatile files in any eager prefix; no task-number references in deliverables outside specs/**.

---

### 42. Add verify-deploy gates: broken-@-ref lint and warning-first context-budget gate
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None

**Description**: === REVISED 2026-08-24 (refactor survey) ===
ITEM (a) IS ALREADY ACHIEVED. grep for '@\.claude|@[a-zA-Z]' across every merge-sources/claudemd.md returns ZERO. The broken-@-ref lint therefore guards an end state that already holds -- it is a REGRESSION GUARD, not a fix for a live problem. Say so in the acceptance criteria rather than describing a defect that no longer exists; an implementer who reads the original wording will go looking for broken refs and find none, then either invent work or stall.
ITEM (b) IS GENUINELY ABSENT AND IS THE REAL CONTENT OF THIS TASK. scripts/lint/ holds five linters, none budget- or @-related, and verify-deploy.sh has no budget hook. The measurement harness this depends on is BUILT AND READY: scripts/measure-eager-context.sh exists, runs clean, and currently reports 64,323 B / ~16.1k tokens of session-start eager context (improved from 74,136 B at the 2026-08-11 review). Wire it into the gate suite with a threshold so the eager-context win cannot silently regress -- it already nearly did, since the 13% rules-diet saving was entirely consumed by skill growth over the same period.
Suggested threshold anchor: fail above the current 64,323 B, and record the number in the gate output so drift direction is visible per run rather than re-derived per review.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Add two context gates to the deploy verification pipeline. (a) Broken-@-ref lint: every `@path` token appearing in generated CLAUDE.md (and in the merge sources that produce it) must either RESOLVE relative to its containing file's directory or be explicitly marked citation-only; a ref that resolves to a nonexistent path is silently inert today (no error, no load) and must fail the gate loudly. The desired end-state for this repo is zero `@`-refs in merge sources (downward normalization to plain backticked paths is already applied), so the lint primarily guards against regression. (b) Warning-first context-budget gate: compute the predicted eager surface (reuse or invoke the measurement harness if it exists by then) and WARN when it exceeds a configured budget; escalate to a hard failure only after the warning tier has proven stable. Consider a per-extension `merge_targets.claudemd.max_bytes` manifest field — NOTE THE SEQUENCING DEPENDENCY: manifest-schema changes must coordinate with the in-flight manifest-schema work (correct-mcp-ownership / extension-manifest efforts); if that work is unsettled when this task starts, implement the budget with an external config and defer the manifest field. CONSTRAINTS: gates must read the source store and the freshly generated output, never trust the possibly-stale deployed .claude/** tree; volatile files (specs/TODO.md, state.json, errors.json) appearing in the eager set is always a FAILURE, not a warning; all edits target agent-system/extensions/**; no task-number references in deliverables outside specs/**.

---

### 41. Build eager-context measurement harness (measure-eager-context.sh)
- **Effort**: 2-4 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None
- **Research**: [041_eager_context_measurement_harness/reports/01_eager-context-measurement-harness.md]
- **Plan**: [041_eager_context_measurement_harness/plans/01_eager-context-measurement-harness.md]
- **Summary**: [041_eager_context_measurement_harness/summaries/01_eager-context-measurement-harness-summary.md]

**Description**: Create `measure-eager-context.sh` in the core extension's scripts: a harness that PREDICTS the session-start eager context set from the source store plus a fresh regenerate — never by measuring the live `.claude/` tree (stale-deploy concern; the deployed tree routinely lags the source store). The eager set to model: (1) the parent CLAUDE.md chain (e.g. ~/.config/CLAUDE.md, repo CLAUDE.md, generated .claude/CLAUDE.md); (2) the generated CLAUDE.md content assembled from core + loaded extensions' merge sources; (3) any RESOLVING `@`-imports found in that chain (directory-relative resolution — see context/architecture/context-layers.md 'Eager vs. Lazy Loading Channels'); (4) rules lacking `paths:` frontmatter or carrying `paths: "**/*"`. Emit bytes and estimated tokens (bytes/4) per contributing source plus a total, in a stable machine-parseable format. Provide a `--check`/`--write` split following the precedent of `generate-context-line-counts.sh` (`--check` reports, `--write` records a baseline snapshot for later drift comparison). The audit baseline to compare against: ~69.9 KB / ~17.5k tokens before downward normalization; predicted ~9.5k tokens after. CONSTRAINTS: no volatile files (specs/TODO.md, state.json, errors.json) may ever be counted as legitimately eager — flag any found; all edits target agent-system/extensions/** (source store), never the deployed .claude/** tree; no task-number references in deliverables outside specs/**.

---

### 39. Upgrade Zotero metadata resolution and plan the Zotero 10 backend swap
- **Effort**: 3-6 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [039_zotero_metadata_resolution_upgrade/reports/02_zotero-metadata-resolution-design.md]
- **Plan**: [039_zotero_metadata_resolution_upgrade/plans/02_zotero-metadata-resolution.md]

**Description**: Upgrade the literature extension's Zotero integration beyond bare write-path activation: add a real metadata-resolution step for web-discovered sources, decide the MCP question, gate auto-attach on storage quota, and record the Zotero 10 backend-swap plan. Grounded in verified Aug-2026 tooling research — see the seed report before re-deriving any landscape claim.

=== WORK ITEMS ===

1. TRANSLATION-SERVER INTEGRATION (the pipeline's thinnest point today). The online ingest bridge currently relies on `zot add --pdf`'s DOI-from-PDF extraction for metadata, which fails on books, preprints without embedded DOIs, and scans. Integrate the official `zotero/translation-server` (HTTP, port 1969; service provisioning is the ~/.dotfiles repo's job — its task 129): call `POST /search` (DOI/ISBN/arXiv ID, preferred when Tier-3 discovery already has an identifier) or `POST /web` (URL fallback) to resolve full Zotero JSON BEFORE item creation, and pass that metadata through the create path. Degrade gracefully (current behavior) when the service is down, and surface which resolution path produced the record.

2. ZOTERO-MCP ADOPTION DECISION. Evaluate adding 54yyyu/zotero-mcp (de-facto standard, ~4.6k stars, hybrid mode = local-API reads + Web-API writes, add-by-DOI/URL/ISBN, OA-PDF cascade) as an INTERACTIVE complement for `/research --lit` sessions. The deterministic scripts remain the pipeline of record — community practice in 2026 is exactly this split. Deliverable is a recorded decision (adopt/defer with reasons); if adopted, registration scope and permission grants follow the grant-at-registration-scope principle already established for MCP servers in the ~/.dotfiles Claude configuration, and the registration itself lands there, not here.

3. STORAGE-QUOTA GATE. Stored-file uploads via the Web API count against the zotero.org 300 MB free tier (948 attachments already exist locally; the account's plan/usage is unverified). Verify quota state and encode an explicit auto-attach policy in the ingest bridge rather than discovering the ceiling by failure. Note the upload flow's `{"exists": 1}` content-hash dedup for PDF bytes.

4. ZOTERO 10 BACKEND-SWAP PLAN (plan, do NOT implement while 10 is beta). Zotero 10 ships native local writes (items + file upload) at `localhost:23119/api/` with consent-based local API keys via `POST /api/local/authorize` — eliminating cloud round-trips and the storage quota for attached files. Record the swap plan against the single write choke-point (`zotero-write.sh`) so callers never change; explicitly reject `/connector/saveItems` as a write contract (undocumented internal protocol).

=== ACCEPTANCE CRITERIA ===

1. Web-discovered sources get translation-server-resolved metadata when an identifier or URL is available, with honest surfacing of which resolution path was used and graceful degradation when the service is unreachable.
2. The MCP decision is recorded with reasons; no MCP registration or grants are hand-edited in this repo either way.
3. Auto-attach policy is explicit and quota-aware; no silent quota-exhaustion failure mode remains.
4. The Zotero 10 swap plan exists in the extension's context docs, names the choke-point, and states what stays constant for callers.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed .claude/** tree.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 34. Anchor guard-destructive-git.sh destructive-pattern matching to argv, not commit-message prose
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None
- **Research**: [034_anchor_git_guard_matching_to_argv/reports/01_anchor-guard-matching.md]
- **Plan**: [034_anchor_git_guard_matching_to_argv/plans/01_anchor-guard-matching.md]
- **Summary**: [034_anchor_git_guard_matching_to_argv/summaries/01_anchor-guard-matching-summary.md]

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
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.=== ADDENDUM: LIVE REPRODUCTION (appended by the orchestrator; the meta agent hit this itself and was terminated by an API usage limit before it could record the trigger) ===

While committing the very tasks that describe this defect, the meta agent's own `git commit` was BLOCKED by `guard-destructive-git.sh` — on a command line containing no `-a`, no `-am`, and no `--all`. Its last words before termination: "The guard just blocked a commit that contains no `-a`, `-am`, or `--all` — a live reproduction of Defect 4. Let me identify the exact trigger to record as evidence." It did not get to identify the trigger.

This is a second, independent live firing (the first was during a `/orchestrate 414 --hard` run in the BimodalLogic repository, where a legitimate commit was blocked until its message was reworded). Both firings share a shape: the blocked command was non-destructive, and the only plausible trigger was TEXT — a commit message describing destructive git operations, in a task about destructive git operations.

Note the self-referential hazard this creates and treat it as an acceptance criterion: any commit message, task description, plan, or test fixture that DISCUSSES destructive git commands can trip a prose-matching guard. Work on this very task is therefore likely to trip it repeatedly. The fix must make it safe to write about `git reset --hard` without being unable to commit that writing.

Reproduction hint for the implementer: the commit that eventually succeeded was `f2679860a` ("meta: create 3 tasks for hard-mode orchestrator defect remediation"). Compare against whatever earlier message was rejected — the delta identifies the trigger substring. Per the task body above, the `git add`/`git commit` over-staging detectors already quote-strip via `seg_scan`; it is the destructive chain (lines 116-184) that greps raw, and that is where both firings originate.=== ADDENDUM: THIRD LIVE FIRING, WITH THE TRIGGER ISOLATED (recorded during batch scoping) ===

The trigger the two earlier firings could not identify has now been isolated by bisection against
the deployed hook. Both root causes are in the git commit over-staging detector (the one the task
body above lists as ALREADY SAFE -- that assessment is WRONG for multi-line messages and must be
corrected).

CAUSE 1 -- THE QUOTE-STRIP IS LINE-BASED AND FAILS ON MULTI-LINE MESSAGES. The detector builds
seg_scan via `echo "$seg" | sed -e 's/"[^"]*"/""/g'`. sed processes input line by line. A -m
message spanning multiple lines leaves the opening quote unclosed on its own line, so no complete
quoted span exists on any single line and NOTHING is stripped. Every line of the message is then
flag-scanned as if it were argv. The identical command with a single-line message passes, because
there the quoted span closes and is stripped correctly. Demonstrated: same header text, PASS as
one line, BLOCK as the first line of a multi-line message.

CAUSE 2 -- THE FLAG REGEX MATCHES ORDINARY HYPHENATED PROSE. The pattern is
    (^|[^-])-[a-zA-Z]*a[a-zA-Z]*([[:space:]]|$)
which matches ANY hyphenated word whose post-hyphen part contains an 'a' and is followed by
whitespace. The concrete blocked token was the batch topic name itself: in `essential-refactor `,
the `l` satisfies [^-], `-refactor` satisfies -[a-zA-Z]*a[a-zA-Z]*, and the trailing space closes
the match. Neutral words like `un-edged` and `repo-wide` do NOT match (no 'a' after the hyphen),
which is why the failure looked nondeterministic across earlier attempts.

WHY BOTH MATTER. Cause 2 alone is harmless while the strip works; cause 1 alone is harmless while
no line contains a matching token. The false positive requires both, which is why it presented as
intermittent and message-dependent. A fix addressing only one leaves the other live.

CORRECTION TO THE TASK BODY: the claim that the `git add` and `git commit` over-staging detectors
"ALREADY strip quoted spans before flag-scanning" and are the correct pattern to extend is only
true for single-line commands. Extending that pattern to the destructive chain without first
making the strip multi-line-aware would propagate this defect rather than contain it. Fix the
strip first, then extend.

ADDITIONAL ACCEPTANCE CRITERIA:
  - A multi-line -m message is quote-stripped as a single logical span, not per line.
  - A commit whose message contains an ordinary hyphenated word with an 'a' after the hyphen
    (essential-refactor, auto-repair, multi-task) is never blocked, single- or multi-line.
  - A genuine `git commit -am "msg"` and a genuine `git commit -a` are still blocked, including
    when the message spans multiple lines.
  - The regression suite required by this task covers the multi-line case explicitly; a
    single-line-only suite would have passed against this defect.

---

### 32. Redeploy and remediate install once settings
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [032_redeploy_and_remediate_install_once_settings/reports/01_redeploy-and-remediate-baseline.md]
- **Plan**: [032_redeploy_and_remediate_install_once_settings/plans/01_deploy-remediate-stale-grant.md]
- **Summary**: [032_redeploy_and_remediate_install_once_settings/summaries/01_deploy-remediate-stale-grant-summary.md]

**Description**: === REVISED 2026-08-24 (refactor survey) ===
PREMISE CORRECTION, AND A LARGE PRIORITY INCREASE. This task is now the single most important item in the backlog.
WHAT IS FALSE: the claim that context/patterns/mcp-server-ownership.md 'does not exist in the deployed tree at all'. It is present at .claude/context/patterns/mcp-server-ownership.md, 18,827 B, byte-identical to source. Do not act on that premise.
WHY IT IS NOW URGENT ANYWAY: the deploy is 7 days and 133 commits stale. Exactly 15 source files have changed since the last deploy and four scripts are measurably drifted, including skill-base.sh -- the orchestration core. Deployed skill-base.sh:958 still carries the pre-fix ambient-variable dispatch_seq code while source line 963 has the corrected persisted-counter jq form. FOUR TASKS ARE MARKED COMPLETED WITH HONEST SUMMARIES AND ARE NOT LIVE: the mint-dispatch-seq fix and the three literature fixes, one of which is a HIGH-severity corpus-corruption gate. Until this deploy runs, 'completed' does not mean 'in effect', and every measurement taken against .claude/ is measuring last week.
RESCOPE TO: (1) run the deploy -- justified now by measured script drift, not by the false 'never deployed' premise; (2) capture a verify-deploy --findings baseline BEFORE and AFTER, since deploy-headless.sh deploys the entire source store regardless of this task's MCP framing (the 2026-08-11 caution was right); (3) hand-remove the stale mcp__lean-lsp__* grant at .claude/settings.json:188, absent from the source root-files/settings.json -- the install-once trap; (4) record the two deferred decisions.
Dependencies cleared: nothing about generating .mcp.json or the opencode mirror gates a redeploy. Note in CHANGE_LOG which previously-completed tasks became live at this deploy, so a future reader does not misdate them.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Deploy the accumulated source-store changes and remediate the stale grant that the install-once mechanism structurally cannot fix.

WHY THIS IS LAST: a substantial body of MCP work now exists in the source store and has NEVER been deployed -- context/patterns/mcp-server-ownership.md does not exist in the deployed tree at all, and every correction from the preceding tasks is likewise source-only. Deploying once at the end, after the source store is settled, avoids redeploying a document that is about to be rewritten.

THE INSTALL-ONCE TRAP -- THE WHOLE POINT OF THIS TASK: the deployed .claude/settings.json still contains a mcp__lean-lsp__* wildcard that was already removed from core/root-files/settings.json in the source store. A redeploy WILL NOT fix this. That file deploys under install-once semantics (loader.lua's copy_category('root_files') gated by CATEGORY_DESCRIPTORS.root_files.install_once, with manager.unload excluding it via INSTALL_ONCE_ROOT_FILES), so once a project has its own copy it is never overwritten. The stale wildcard is ALSO a leftover from a deploy cycle when the lean extension was loaded, and an additive deep-merge never retracts. It must be removed by hand from the deployed file. Anyone who runs a deploy and assumes the grant is gone will be wrong.

EXPECTED HOOK WARNING: hand-editing .claude/settings.json will trip the source-store-boundary advisory hook. That warning is expected and correct in general but does not apply here: an install-once file is effectively user state, not a regenerable deploy artifact. Record that reasoning rather than silently ignoring the warning, and do not 'fix' it by editing the source copy instead -- the source copy is already correct.

WORK: run `bash .claude/scripts/deploy-headless.sh`; then remove the stale mcp__lean-lsp__* entry from the deployed .claude/settings.json; then run `bash .claude/scripts/verify-deploy.sh` and compare its findings against a baseline captured BEFORE the deploy, so pre-existing failures are not misread as newly introduced ones.

ALSO SETTLE, OR EXPLICITLY DEFER WITH A REASON: (a) lean-lsp is registered at user scope pointing at a DIFFERENT repository (/home/benjamin/Projects/BimodalLogic), because user-scope registration is global while that server needs a per-project path -- moving it to the new project-scoped mechanism would fix this class of bug; (b) the nine playwright grants duplicated in the web and present settings fragments become redundant once those tools are granted at machine scope in the NixOS configuration, under the grant-at-registration-scope rule. Item (b) is harmless duplication, not a fault -- treat it as cleanup and do not break working grants chasing tidiness.

VERIFICATION: mcp-server-ownership.md exists in the deployed tree; the deployed .claude/settings.json contains no mcp__lean-lsp__* entry; verify-deploy.sh reports no findings that were absent from the pre-deploy baseline; a FRESH Claude Code session (not the current one, which cannot observe registration changes) shows the expected servers. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 31. Opencode extensions sync mechanism
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: === REVISED 2026-08-24 (refactor survey) ===
NARROWED -- the original scope is a poor trade against all three refactor goals. Confirmed today: 804 git-tracked files under .opencode/extensions/ with no generation mechanism, and the live defect is real (.opencode/extensions/web/agents/web-implementation-agent.md:57 still teaches browser_verify_text_visible as a real tool, while the source at agent-system/extensions/web/agents/web-implementation-agent.md:72 explicitly RETRACTS it). But this task's sibling records that .opencode/ is not currently used, and building a full 804-file generator for an unused mirror buys no token efficiency, no performance, and no uniformity.
NARROW TO THREE THINGS: (1) fix the one fake-tool line so the mirror cannot teach a retracted tool as real; (2) add a drift-detection gate so the divergence is visible rather than silent -- this is the durable part; (3) document the divergence policy, i.e. whether .opencode/ is maintained, frozen, or slated for removal.
If the answer to (3) is 'frozen or removal', say so explicitly and this task shrinks further. Deciding that is worth more than generating the mirror.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Give the .opencode/extensions/ mirror a real generation path from the source store, so it stops silently drifting, and fix the live defect that drift has already produced.

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
- **Dependencies**: None

**Description**: Build the deploy-engine mechanism that lets an extension declare an MCP server and have it actually registered, by generating a project-scoped .mcp.json.

WHY THIS IS NEEDED: extensions currently express server declarations as `mcpServers` keys inside settings-fragment.json, which register nothing -- settings files are not a registration surface. Project-scoped .mcp.json IS a real registration surface, and it IS reachable by dispatched subagents (verified by direct experiment; the earlier belief to the contrary rested on a session-start snapshot confound). So the fix is to route declarations to a surface that works, not to abandon the idea of extensions declaring servers.

WORK: add a new manifest merge target -- e.g. `merge_targets.mcp` with a source file per extension -- that the deploy engine collects across all LOADED extensions and writes to the repository-root .mcp.json. Mirror the existing settings merge path (process_merge_targets / merge_settings in merge.lua) rather than inventing a second idiom: the existing path is an additive, idempotent deep-merge that does not clobber pre-existing content, and it deliberately targets a file that is NOT install-once, which is exactly the property needed here. Extend manifest_spec.lua so the new key validates.

REQUIREMENTS THE MECHANISM MUST SATISFY: (a) each generated server entry carries an explicit "type" field -- as of Claude Code v2.1.202 a remote server lacking an explicit type fails fast rather than failing silently, and all current declarations omit it; (b) unloading an extension must REMOVE its servers from .mcp.json, because an additive deep-merge alone never retracts, and a stale grant surviving an unload is an already-observed defect class in this system; (c) the operation must be idempotent -- deploying twice yields a byte-identical .mcp.json; (d) hand-written entries a user added to .mcp.json themselves must survive regeneration, or the file must clearly declare itself generated. Decide (d) explicitly and record the choice.

IMPORTANT CONTEXT: a project-scoped .mcp.json server requires workspace-trust approval before `claude mcp list` will read it (v2.1.196+), and a server added to .mcp.json is invisible to any ALREADY-RUNNING session. Both facts must be documented for users, or the mechanism will be reported as broken when it is working correctly. Verify against a fresh session or `claude -p`, never against the current one.

VERIFICATION: build a scratchpad fixture project, load an extension declaring a trivial stdio server, and confirm .mcp.json is generated correctly; confirm a second deploy is a no-op; confirm unloading removes the entry; confirm `claude mcp get <name>` in the fixture reports Scope: Project config. Do NOT deploy against this repository as part of verification. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 28. Correct mcp ownership model and purge dead declarations
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 32
- **Research**: [028_correct_mcp_ownership_model_and_purge_dead_declarations/reports/01_mcp-ownership-rewrite-and-purge-spec.md]
- **Plan**: [028_correct_mcp_ownership_model_and_purge_dead_declarations/plans/01_mcp-ownership-hybrid-rewrite.md]
- **Summary**: [028_correct_mcp_ownership_model_and_purge_dead_declarations/summaries/01_mcp-ownership-hybrid-rewrite-summary.md]

**Description**: === REVISED 2026-08-24 (refactor survey) ===
NOT COMPLETE -- CORRECTION TO AN EARLIER READ. A survey pass reported this task as finished-but-unclosed, on the basis that all its plan phases read [COMPLETED]. That was wrong: the plan has EIGHT phases, not seven. Phases 1-7 are [COMPLETED] with progress files through phase-7-progress.json, but Phase 8 (Full verification sweep) is [IN PROGRESS] with all nine of its checkboxes unchecked and no phase-8-progress.json. This task keeps status implementing and needs its verification sweep run -- it was NOT closed out.
CAVEAT ON RESUMING PHASE 8: its doc-lint assertion has been overtaken by events and cannot be run as written. It requires diffing check-extension-docs.sh output against specs/tmp/doclint-baseline.txt (still present, dated 2026-08-11) and expects core's SOLE issue to be the pre-existing setup-lean-mcp.sh deployed-vs-source drift. Core now has EIGHT issues: one skill-base.sh deploy drift plus seven index-entries.json line_count mismatches, and literature has six. Most of that is unrelated deploy staleness, not a defect of this task. Re-baseline AFTER the deploy task lands, then re-run the sweep, so this task is not blamed for drift it did not cause and does not silently absorb it either.
The other eight Phase 8 checks (jq assertions on the four edited fragments, the single-mcpServers-path grep, bash -n on setup-lean-mcp.sh, check-task-references, the contradiction greps, and the git status scope confirmation) are unaffected and can run now.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Rewrite the canonical MCP ownership document, whose central premise has been empirically DISPROVEN, and purge the dead server declarations it catalogues.

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

### 22. Silence opencode fragment validation spam
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: === REVISED 2026-08-24 (refactor survey) ===
SUBSTANTIALLY OVERTAKEN, and the remaining half got worse. Re-verified today:
- Defect class (3) is FIXED. merge.lua:1002-1041 now degrades per-agent-key, reports every missing key rather than only the first, and no longer discards a whole fragment. Close it out; do not re-fix.
- Defect class (2) MOVED rather than got fixed. The archived path-fix work changed the lean fragment to reference .claude/agents/lean-research-agent.md instead of .claude/extensions/lean/agents/... -- but that path does not exist either.
- Defect class (1) is WORSE: 30 of 34 {file:} refs across all fragments now point at nonexistent files (was 16 of 18). Only nvim and nix resolve, because those are the extensions loaded in this repo -- which is itself the clue.
REFRAME around the one live question rather than patching paths again: SHOULD opencode-agents.json fragments reference a per-project deploy tree at all? Every {file:} ref is per-repo-deploy-dependent by construction, so any path fix is correct only for the extension set of whichever repo it was fixed in. That is why class (1) keeps regrowing. Answer the design question first; the path corrections fall out of it.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Silence and correct opencode-agents.json fragment validation spam on extension reload.

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
=== ADDENDUM: SECOND LIVE REPRODUCTION, STRONGER THAN THE ORIGINAL (recorded during a real /todo run) ===

A /todo run archiving 25 tasks and moving 25 directories reproduced the defect with a cleaner
signal than the original measurement. Step 5.6, run at its documented position (after the
directory moves, before the Step 6 commit), reported:
    {"todo_count":44,"fixme_count":2,"build_errors":184,"status":"critical"}
The identical probe re-run immediately after the commit reported:
    {"todo_count":44,"fixme_count":2,"build_errors":0,"status":"healthy"}

ALL 184 WERE PHANTOM. The original measurement had 88 phantom of 89, leaving 1 real error that
slightly muddied the signal. This run has a true count of exactly 0, so the inflation is total
and the derived status is wrong in both fields with no residue to explain away. Use this as the
regression fixture: it is a cleaner before/after pair than the original.

The run also confirms the ordering half of the root cause independently of the existence-check
half. Nothing about the tree changed between the two probes except `git add specs/` plus a
commit, which converted 298 rename entries from index-vs-worktree divergence into recorded
state. No file content was edited between the two measurements.

WORKAROUND APPLIED DURING THAT RUN (not a fix, and it must not be mistaken for one): the operator
inverted Steps 5.6 and 6 by hand, committing first and then probing, so state.json recorded the
true value rather than the phantom one. That inversion is item 2 of this task's WORK list. It was
applied ad hoc to avoid persisting a known-false "critical" into repository_health; the durable
fix, including the existence-safety of item 1 and the regression lock, is still outstanding.

=== SECOND, INDEPENDENT DEFECT IN THE SAME FILE -- STEP 5A EXCEEDS MAX_ARG_STRLEN AT SCALE ===

Found in the same run, and in scope here because it is the same file and the same command. Step
5A ("Update archive/state.json") passes the ENTIRE archivable task set as one shell argument:
    --argjson tasks "$archivable_tasks_json"
Linux caps a SINGLE argument at MAX_ARG_STRLEN (128 KB, 32 pages), independent of the much larger
total ARG_MAX. Archiving 25 tasks produced a 175 KB value and the call died with:
    bash: /run/current-system/sw/bin/bash: Argument list too long
This is a hard failure of the archive insert, not a warning. It fired BEFORE any state was
written, so nothing was lost; had it fired between the archive insert and the Step 5B deletion,
the archivable set would have been removed from active_projects without ever landing in the
archive. The blast radius is therefore data loss, not merely an aborted run.

The trigger is total description bytes, not task count: these task descriptions routinely run
5-10 KB each, so the ceiling arrives at roughly 15-25 tasks. Any repository that lets completed
tasks accumulate will hit it, and it gets worse the longer /todo goes unrun -- the command
becomes unrunnable exactly when it is most needed.

state-write.sh offers no file-based input flag; it supports only --arg and --argjson, both
command-line. So the fix belongs in one of:
  (a) batch the Step 5A insert into chunks that stay under the per-argument ceiling (the ad hoc
      workaround used during this run: five batches of five tasks, 28-50 KB each, all succeeded);
  (b) add a file-based input flag to state-write.sh (jq --slurpfile / --rawfile) and have Step 5A
      use it, which fixes the whole class rather than this one call site;
  (c) have the Step 5A filter read the source tasks itself rather than receiving them as an
      argument.
Direction (b) is worth weighing beyond this call site: any other caller passing a large --argjson
payload through state-write.sh has the same latent ceiling.

ACCEPTANCE FOR THIS SECOND DEFECT: a /todo run archiving at least 30 tasks with realistic
multi-kilobyte descriptions completes its archive insert without an argument-length failure, and
the archive insert and the active_projects deletion cannot end up on opposite sides of a partial
failure.

---

### 18. Detect stale .claude/ deploy trees and root-cause the silent staleness
- **Effort**: 5h
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None
- **Research**: [018_detect_stale_claude_deploy_trees/reports/01_stale-deploy-detection.md]
- **Plan**: [018_detect_stale_claude_deploy_trees/plans/01_stale-deploy-detection.md]
- **Summary**: [018_detect_stale_claude_deploy_trees/summaries/01_stale-deploy-detection-summary.md]

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
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 16, Task 35, Task 37
- **Research**: [017_fix_return_meta_lifecycle_ordering/reports/01_return-meta-lifecycle-ordering.md]
- **Plan**: [017_fix_return_meta_lifecycle_ordering/plans/01_return-meta-lifecycle-ordering.md]
- **Summary**: [017_fix_return_meta_lifecycle_ordering/summaries/01_return-meta-lifecycle-ordering-summary.md]

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

### 14. Prevent implementation-agent fan-out from returning non-terminal status and stale plan markers
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: === REVISED 2026-08-24 (refactor survey) ===
NARROWED: roughly half of this task already landed with the handoff-identity work and must not be redone. skill-orchestrate/SKILL.md:2374,2384 now treats in_progress (and null/empty) as OFF-SCHEMA rather than routing it toward failed_tasks, and orchestrate-recover-outcome.sh:233 emits a clean STATUS_IN_PROGRESS verdict. Verified in the source store today.
WHAT REMAINS is the AGENT-CONTRACT side only, and it is untouched: general-implementation-agent.md contains NO fan-out prohibition, and NO requirement that a sub-agent which commits a phase must update that phase's marker in the same commit. Both gaps are what produced the original symptom -- dispatches fanning out to phase sub-agents and terminating before writing a terminal status, leaving plan markers reading [NOT STARTED] against landed commits.
Rescope to those two contract additions. Do not re-litigate the status-vocabulary half.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Two dispatches in a single batch fanned out to phase sub-agents and terminated before writing a terminal status, costing a recovery cycle each. Recorded as err_1786344051474_RcIhk6.

OBSERVED FAILURE MODE: a dispatched implementation agent spawned per-phase sub-agents, returned while they were still running, and left .return-meta.json at status=in_progress. Per context/formats/return-metadata-file.md that value is early-metadata-only and never a legal terminal dispatch outcome, so orchestrate-recover-outcome.sh correctly declines it (reason STATUS_IN_PROGRESS). The orchestrator contract for an unresolvable dispatch is failed_tasks - which would have been WRONG here, since 6 of 10 phases had in fact been committed. Correct handling came from rules/error-handling.md Delegation Interrupted Recovery (keep status, resume), not from the orchestrator stage contract.

COMPOUNDING DEFECT - STALE PLAN MARKERS: the sub-agents committed phases 3, 4, 5 and 7 but left every one of those phase markers reading [NOT STARTED]. Because the orchestrator phase-marker recovery grep reads exactly those markers, it would have reported 2/10 against a true 6/10. A resume driven by markers alone would have redone committed work. Recovery only succeeded because the actual state was reconstructed from git log and diffs instead.

TWO INDEPENDENT QUESTIONS, BOTH IN SCOPE:
  1. Should a dispatched implementation agent fan out to sub-agents at all? If yes, it must still write a terminal status covering its childrens work; if no, the prohibition belongs in the agent contract, not in per-dispatch prompt text (the workaround used during the incident).
  2. Should a sub-agent that commits a phase be required to update that phases marker in the same commit? Markers and commits diverging silently is the deeper defect - it degrades the recovery path for every future interrupted dispatch, not just fan-out ones.

CONSIDER ALSO: whether the orchestrator should treat status=in_progress plus evidence of committed phase work as PARTIAL/resume rather than routing it toward failed_tasks, so correct handling does not depend on an operator noticing.

ACCEPTANCE: an interrupted fan-out dispatch is either impossible by contract, or leaves markers and terminal status accurate enough that resume needs no manual git archaeology.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== REVISED 2026-08-24 (second live occurrence, extension-agent gap) ===
RECURRED, AND THE CONTRACT GAP IS WIDER THAN THIS TASK'S CURRENT SCOPE. A seven-task lean4 batch
orchestrated in a separate consumer repo reproduced this exact failure mode TWICE in one
implementation cycle: two of seven dispatches performed real work, committed it, and then
terminated WITHOUT writing a terminal handoff, leaving .return-meta.json at status=in_progress.
orchestrate-recover-outcome.sh correctly declined both (STATUS_IN_PROGRESS); both needed a
re-dispatch cycle to resolve, exactly as the original incident did.

SCOPE CORRECTION (the actionable part). Both offending dispatches ran
extensions/lean/agents/lean-implementation-agent.md, NOT
extensions/core/agents/general-implementation-agent.md -- the only agent contract this task's
file_scope currently names. The terminal-status requirement is therefore missing from the
EXTENSION implementation agents as well as the core one, and fixing only the core file would
leave the reproducing path untouched. file_scope is extended accordingly to the lean pair. Treat
the core agent as the normative contract and the extension agents as required conformers; if a
shared include or a single normative statement referenced by all implementation agents is the
better mechanism, prefer that over copying the same paragraph into four files.

MARKER DIVERGENCE RECURRED IN THE OPPOSITE DIRECTION -- fold into question 2, do not treat as a
separate concern. The original incident recorded markers UNDER-claiming (phases committed, markers
still [NOT STARTED]). This batch recorded the inverse: one task's plan carried five of seven
phases marked [COMPLETED] while its sole declared file_scope target was UNMODIFIED against HEAD --
markers OVER-claiming against work that had not landed. A resume driven by those markers would
have skipped real work rather than redone it. Both signs share one root cause, which question 2
already names: markers and committed reality are allowed to diverge silently. Any fix must be
bidirectional -- a marker must not be promotable without the corresponding work being verifiable,
and committed work must not leave its marker unpromoted. The over-claim direction was only caught
because the orchestrator cross-checked the marker count against the working tree; a fix that
merely tightens promotion-on-commit would not have caught it.

WHAT IS ALREADY GOOD AND MUST NOT BE UNDONE. The re-dispatch path worked: both tasks resumed from
their real state and completed, and the resumed dispatches -- when explicitly instructed to write
the handoff FIRST and to re-verify prior phase markers with a real build rather than trust them --
both reported correctly and downgraded nothing falsely. That per-dispatch prompt text is the
workaround this task exists to retire; it is evidence the contract wording works, not a substitute
for putting it in the contract.

ACCEPTANCE (extends, does not replace, the original): the terminal-status requirement and the
fan-out resolution apply to extension implementation agents as well as the core one, demonstrated
against a lean4 dispatch; and marker/reality divergence is caught in BOTH directions.

---

### 13. Instrument gate-out auto-repair reporting; stop silent in-place artifact mutation
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

### 9. Resolve deploy orphan file parity
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 32
- **Research**: [009_resolve_deploy_orphan_file_parity/reports/01_orphan-file-parity-remeasurement.md]
- **Plan**: [009_resolve_deploy_orphan_file_parity/plans/01_orphan-detection-parity.md]
- **Summary**: [009_resolve_deploy_orphan_file_parity/summaries/01_orphan-detection-summary.md]

**Description**: === REVISED 2026-08-24 (refactor survey) ===
SCOPE CORRECTION: the orphan set is ELEVEN files, not the four named below. A manifest cross-check finds the entire deployed .claude/context/orchestration/ directory (architecture.md, delegation.md, orchestration-core.md, orchestration-reference.md, orchestration-validation.md, orchestrator.md, postflight-pattern.md, preflight-pattern.md, sessions.md, subagent-validation.md) plus docs/architecture/architecture-spec.md, with no source-store owner. Conversely docs/README.md is NO LONGER an orphan -- drop it from the set.
SEQUENCING: this task's own STALENESS CAVEAT says to re-measure against a fresh tree first. That caveat is now load-bearing: the deployed tree is 7 days and 133 commits stale, so ANY orphan measurement taken before the deploy lands is unreliable. Dependency set to the deploy task for exactly this reason -- do not start before it.
Related evidence: errors.json err_1786349061556_LuKGif (deploy_ghost_index_entries) records orchestration-validation.md and subagent-validation.md as still present in .claude/context/index.json with no source owner; verified still true today.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Declared-vs-deployed parity for provides.* categories is one-directional by design, and the live .claude/ tree carries 4 orphan files absent from a clean scratch regenerate: context/orchestration/orchestration-validation.md, context/orchestration/subagent-validation.md, docs/architecture/architecture-spec.md, docs/README.md. Two of these (docs/architecture/architecture-spec.md, docs/README.md) were not covered by the pre-existing err_1786349061556_LuKGif (deploy_ghost_index_entries), which only named the other two -- confirmed and extended by err_1786350581273_TAWj0I (deploy_orphan_files_undercounted). This task covers BOTH error ids with one decision; do not split it.

MECHANICAL REASON (already diagnosed, do not re-derive): verify.lua's result shape has no extra/orphan field and only ever iterates the declared side; install-extension.sh's merge_index_entries() is purely additive with no stale-removal step. Parity is therefore verified only in the declared-to-deployed direction, never the reverse.

TARGET: agent-system/extensions/core/scripts/verify-deploy.sh (or the shared verify.lua module it calls), and/or docs/architecture/architecture-spec.md if the decision is to document one-directional parity as intended rather than build detection.

WORK: decide ONE of two directions and implement it -- (a) add a subtractive/orphan-detection pass to verify.lua or verify-deploy.sh that flags live files present in .claude/ but absent from a clean regenerate of every provides.* category, so future orphan drift is caught mechanically; or (b) explicitly document in docs/architecture/architecture-spec.md that provides.* parity is one-directional by design (additive only, no stale-removal), so a future reader does not mistake the current behavior for an oversight. Resolve the 4 currently-orphaned files as part of whichever direction is chosen: either they get removed/reconciled (direction a) or explicitly enumerated as accepted legacy orphans in the documentation (direction b).

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

CONSTRAINT: do not drive this task with multi-task /orchestrate until err_1786349061524_pY97cE (the MT-1/MT-4 session-id mismatch, spawned as a sibling task) is fixed -- multi-task orchestration is documented-broken until that lands. Use single-task /orchestrate or /implement.

STALENESS CAVEAT (added after the deploy-staleness finding): the orphan-file measurement above (4 files present in .claude/ but absent from a clean scratch regenerate) was taken against a deploy tree since shown to be badly stale -- its task-lock.sh was 676 lines against a 1660-line source. That measurement may therefore be an artifact of the staleness rather than evidence of a one-directional parity gap. Re-take the measurement against a freshly regenerated tree before treating it as evidence, and revise the direction (a)/(b) decision if the orphan set changes. Depends on task 18, which diagnoses the staleness root cause.
