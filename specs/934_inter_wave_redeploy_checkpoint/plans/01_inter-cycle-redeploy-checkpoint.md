# Implementation Plan: Task #934

- **Task**: 934 - Inter-wave redeploy checkpoint via the existing headless deploy path
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: 932 (completed), 933 (completed), 936 (completed)
- **Research Inputs**: specs/934_inter_wave_redeploy_checkpoint/reports/01_inter-wave-redeploy-checkpoint-design.md
- **Artifacts**: plans/01_inter-cycle-redeploy-checkpoint.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Retire hazard 3 (the bootstrapping hazard) recorded in
`context/patterns/batch-orchestration-guardrails.md` by adding an **evidence-gated inter-cycle
redeploy checkpoint** to `skill-orchestrate`'s multi-task loop. The checkpoint fires only when a
cycle's dispatched tasks actually modified an orchestrator-critical path, runs the existing
`deploy-headless.sh` + `verify-deploy.sh` pair under a fail-open mutex, and defers all remaining
not-yet-dispatched tasks for the rest of the invocation if either gate fails. The work is
design-and-documentation plus skill-text wiring across six source-store files; no new script is
created — both deploy scripts already exist and are already verified.

Definition of done: the checkpoint contract is recorded once in the guardrails doc, reconciled
against the deliberate-invocation constraint by an additive carve-out in
`regeneration-is-manual-only.md`, made safe to invoke from inside the deploy tree it overwrites,
wired into Stage MT-3 as a new step 7 with a matching `deferred_deploy_checkpoint` set threaded
through MT-3/MT-5, and cross-referenced from `commands/orchestrate.md` — with hazard 3 honestly
recorded as **partially retired, replaced by a narrower mid-invocation script-swap exposure**.

### Research Integration

The research report's five recommendations (A-E) are adopted verbatim as the plan's binding
decisions, plus its two corrections to the task description's framing:

- The self-modification admission gate already excludes a correctly-declared self-modifying
  candidate from the **whole invocation**, not merely a wave. The literal "W0 fixes it, W1 still
  runs stale" sequence is already structurally impossible for such a candidate. The live residual
  is (a) declared-`file_scope` vs actual-`modified_files` divergence, and (b) cross-invocation
  staleness. Both are what this checkpoint retires.
- Six of the nine critical paths are shell scripts re-read from disk per invocation, so a mid-run
  redeploy genuinely swaps executing machinery mid-flight. This is a **replacement** hazard — the
  same verification-gap tension as hazard 1, now manifesting mid-session — not an independent
  fourth hazard.
- Trigger gates on actual `modified_files` (already in scope at Stage MT-4 step 5.5), not declared
  `file_scope` — strictly more precise, closes gap (a), costs only a jq comparison.
- `skill-orchestrate-hard/SKILL.md` Stage 0 delegates multi-task stages to base by reference
  ("use base multi-task stages"), so the checkpoint is inherited automatically. Correctly excluded
  from the declared file scope; **verified, not assumed**, in Phase 7.
- The concurrent-`.claude/`-tree-overwrite race is new exposure this automation introduces. Fixed
  with a fail-open mutex mirroring the `specs/.commit-lock/` acquire/warn-and-proceed shape.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no ROADMAP.md consultation was
requested. No roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Record a single, unambiguous checkpoint contract (trigger, failure contract, sequencing,
  idempotence guard) in `context/patterns/batch-orchestration-guardrails.md`, and have every other
  edited file cross-reference it rather than restate it.
- Reconcile the checkpoint against the deliberate-invocation constraint by **additive carve-out**
  in `context/patterns/regeneration-is-manual-only.md`, leaving the existing "never as a silent
  side effect of an unrelated operation" sentence intact and visible.
- Make `scripts/deploy-headless.sh` safe to invoke automatically: fail-open `specs/.deploy-lock/`
  mutex against a concurrent session's tree overwrite, and self-overwrite safety for a deploy
  invoked from inside the tree being replaced.
- Document `scripts/verify-deploy.sh`'s role as the checkpoint's hard gate, including that its
  exit 2 ("cannot run") is treated as failure, never as a pass.
- Wire the checkpoint into `skills/skill-orchestrate/SKILL.md` as Stage MT-3 step 7, with a new
  invocation-scoped `deferred_deploy_checkpoint` set threaded through MT-3 steps 2/3/4, MT-4 step
  5.5's accumulation, and MT-5's reporting and `exit_status`.
- Record hazard 3 honestly as partially retired plus its named replacement exposure.

**Non-Goals**:

- **No edit to `skills/skill-orchestrate-hard/SKILL.md`.** Hard mode inherits base multi-task
  stages by reference. Phase 7 verifies the delegation sentence still exists; it does not add one.
- **No new script.** `deploy-headless.sh` and `verify-deploy.sh` both already exist and are
  already verified. Neither is rewritten, only hardened and documented.
- **No edit to `scripts/task-lock.sh`.** It is outside the declared file scope AND is itself an
  orchestrator-critical path. The deploy mutex is implemented self-contained inside
  `deploy-headless.sh` — which is also the correct engineering choice, since the deploy is about
  to overwrite the deployed `task-lock.sh` it would otherwise depend on.
- **No edit to `context/reference/orchestrator-critical-paths.json`.** The nine entries and the
  `scope_roots x critical_paths` expansion are reused unchanged.
- **No new overlap predicate.** The directory-prefix overlap algorithm in
  `context/patterns/file-footprint-overlap.md` is referenced by path, never restated.
- **No extension of the checkpoint to `/implement N,M`, `/research N,M`, or `/plan N,M`.** Those
  commands never call the admission gate either; that scope limitation is already recorded and
  stays recorded.
- **No unconditional "always between cycles" trigger, and no user-supplied opt-in flag.** Both are
  explicitly rejected below.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Trigger gated on declared `file_scope` instead of actual `modified_files` would miss the under-declaration gap and give false confidence hazard 3 is fully closed | H | M | Phase 5 gates on the cycle-accumulated `modified_files` union only; the guardrails contract (Phase 1) states the `file_scope`-vs-`modified_files` distinction as the reason |
| Repeated firing across cycles (a task in `implementing` re-reports the same `modified_files` every cycle) causes redundant deploys and maximizes the script-swap window | M | M | Idempotence guard: `mt_state_file.deployed_critical_paths` — the checkpoint fires only when this cycle's overlap set contains at least one path not already deployed this invocation. Mirrors `deferred_self_modifying`'s convergence rationale |
| A mid-run redeploy swaps executing shell-script machinery for the remaining cycles of the same invocation | M | L | Accepted and named as a replacement hazard (Phase 1), contained by the narrow trigger, the hard `verify-deploy.sh` gate, and the defer-remaining failure contract |
| `deploy-headless.sh` invoked as `bash .claude/scripts/deploy-headless.sh` overwrites its own file while bash is still reading it, causing bash to resume at a stale byte offset | H | M | Phase 3, gated behind a Scope Hypothesis: confirm the sync's write mode first; if truncate-in-place, restructure so the whole body is parsed before execution and the script exits without returning to read further |
| A concurrent `/orchestrate`, `/implement`, or a human's `<leader>al` races the checkpoint's whole-tree overwrite | M | L | Fail-open `specs/.deploy-lock/` mutex inside `deploy-headless.sh` (Phase 3), acquire/warn-and-proceed shape mirroring `specs/.commit-lock/` |
| Checkpoint failure treated as "continue anyway" leaves the batch running against a deploy state of unknown correctness — worse than never checking | H | L | Defer-remaining-tasks failure contract (Phase 5), with a loud warning naming which gate failed and its exit code. Silent-continue is forbidden; abort is also rejected |
| Silently rewriting the "must be invoked explicitly" sentence makes `regeneration-is-manual-only.md` self-contradictory to a future reader | M | M | Additive, explicitly-labeled carve-out subsection (Phase 2); the original sentence is left byte-for-byte intact |
| Reusing `deferred_self_modifying` for checkpoint deferrals would conflate two different causes with two different operator remedies | M | M | A distinct `deferred_deploy_checkpoint` set with its own MT-5 reporting category (Phase 5) |
| A future automated caller invokes `deploy-headless.sh` citing this carve-out as general precedent | M | L | The carve-out (Phase 2) explicitly states what it does NOT license: no other automated caller without its own recorded exception |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |
| 4 | 6 | 5 |
| 5 | 7 | 1, 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Record the checkpoint contract and rewrite hazard 3 [COMPLETED]

**Goal**: Make `context/patterns/batch-orchestration-guardrails.md` the single decision record for
the checkpoint, so every later phase cross-references it instead of restating the contract.

**Tasks**:

- [x] Rewrite item 3 under the `### The Deploy-Manual Analysis and the Surviving Hazards` heading. *(completed)*
      Retain the original hazard-3 sentence in retired-form style, matching exactly how hazard 2
      was retained rather than deleted. New label: **Bootstrapping risk — PARTIALLY RETIRED,
      replaced by a narrower mid-invocation script-swap exposure.** The rewritten item must state
      all three of:
  - [x] (i) The in-batch, correctly-declared form was **already structurally impossible** before *(completed)*
        this change, because the self-modification admission gate excludes such a candidate from
        the whole invocation (recorded in `deferred_self_modifying`), not merely from one cycle.
  - [x] (ii) The two residual forms the checkpoint retires: **declared/actual divergence** (a *(completed)*
        task whose declared `file_scope` does not name a critical path but whose actual
        `modified_files` do — invisible to a gate that only reads `file_scope`), and
        **cross-invocation staleness** (a correctly-excluded task is re-run solo, commits its fix,
        and nothing redeploys it before the next invocation).
  - [x] (iii) The replacement exposure, named as such: six of the nine critical paths are shell *(completed)*
        scripts re-invoked via a fresh `bash .claude/scripts/X.sh` subprocess at every use site, so
        they genuinely re-read on-disk bytes; the remaining three (`skills/skill-orchestrate/SKILL.md`,
        `skills/skill-orchestrate-hard/SKILL.md`, `commands/orchestrate.md`) are read once into the
        orchestrator's context at dispatch time and are unaffected for the current turn. State
        explicitly that this is the **same underlying verification-gap tension as hazard 1, now
        manifesting mid-session rather than only cross-session** — not an independent fourth hazard.
- [x] Update the paragraph immediately following the hazard list (the "A later maintainer must not *(completed)*
      read the disproven live-corruption hypothesis..." paragraph) so its "hazards 1 and 3 above
      remain live" phrasing agrees with hazard 3's new partially-retired status.
- [x] Add a new subsection, `### The Inter-Cycle Redeploy Checkpoint`, placed after *(completed)*
      `### Scope Limitation and Residual Risk`, recording the full contract:
  - [x] **Trigger**: the union of every task dispatched this cycle's actual `modified_files`, *(completed)*
        compared against the `scope_roots x critical_paths` expansion of
        `context/reference/orchestrator-critical-paths.json` using the directory-prefix overlap
        predicate in `context/patterns/file-footprint-overlap.md` (both referenced by path, never
        restated). Non-empty overlap fires the checkpoint.
  - [x] **Why `modified_files` and not `file_scope`**: the admission gate already performs the *(completed)*
        `file_scope` check pre-dispatch; using post-dispatch `modified_files` is strictly more
        precise and closes the under-declaration gap. Cost is one jq comparison, since the array is
        already in scope at Stage MT-4 step 5.5.
  - [x] **Rejected alternatives, recorded so a later pass cannot rediscover them**: "always between *(completed)*
        cycles" (unjustified deploy/verify cost on every cycle of every batch regardless of
        relevance, and it maximizes the script-swap window) and a bare user-supplied opt-in flag
        (defeats `/orchestrate`'s zero-synchronous-confirmation-gates design — the operator cannot
        know in advance which cycle will touch a critical path).
  - [x] **Failure contract**: on failure of either gate, defer all remaining not-yet-dispatched *(completed)*
        tasks for the rest of the invocation. Never abort, never silently continue. Cross-reference
        the existing `## Defer-Not-Fail: The Standing Default` section as the governing default,
        and state why abort is rejected (it discards `mt_state_file` bookkeeping for no benefit,
        since deferral already halts further exposure) and why silent-continue is rejected outright
        (the operator would see nothing distinguishing "we didn't check" from "we checked, it's
        broken, and we proceeded").
  - [x] **Sequencing**: per-task commits at Stage MT-4 step 5.5 already precede any point the *(completed)*
        checkpoint can occupy, unconditionally and inside the same per-task loop iteration.
        Committed-then-redeployed, in that order, is guaranteed by existing step ordering and is
        stated here, not built.
  - [x] **Idempotence guard**: the checkpoint fires only when this cycle's overlap set contains at *(completed)*
        least one critical path not already recorded in `mt_state_file.deployed_critical_paths`.
        State the convergence rationale explicitly, mirroring `deferred_self_modifying`'s: without
        it, a task sitting in `implementing` across several cycles would re-report the same
        `modified_files` and re-fire the checkpoint every cycle.
  - [x] **Concurrency**: the whole-tree overwrite is serialized by a fail-open `specs/.deploy-lock/` *(completed)*
        mutex, same acquire/warn-and-proceed shape as `specs/.commit-lock/`.
- [x] Add `context/patterns/regeneration-is-manual-only.md` to the `## Related Documents` list if *(completed)*
      it is not already present.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts that hazard 3's text lives under the
`### The Deploy-Manual Analysis and the Surviving Hazards` heading as list item 3, that hazard 2 is
already retained in retired form as the style precedent to copy, and that a
`### Scope Limitation and Residual Risk` heading exists to insert after. Confirm by grepping the
file for those three headings and for the string `Bootstrapping risk` before editing; if any
anchor is absent, locate the actual anchor by heading text (never by line number) and record the
divergence in the phase notes.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - hazard 3
  rewrite, following-paragraph reconciliation, new `### The Inter-Cycle Redeploy Checkpoint`
  subsection, Related Documents entry.

**Verification**:

- Grep the file for `PARTIALLY RETIRED` and confirm it appears exactly once, on hazard 3.
- Grep for `### The Inter-Cycle Redeploy Checkpoint` and confirm the subsection contains all six
  contract elements (trigger, `modified_files` rationale, rejected alternatives, failure contract,
  sequencing, idempotence guard) plus the concurrency note.
- Confirm the file contains no `task {N}` / `(task N)` citations (the
  no-task-references-in-deliverables rule).
- Confirm the original hazard-3 sentence text is still present in retired form, not deleted.

---

### Phase 2: Additive deliberate-invocation carve-out [COMPLETED]

**Goal**: Reconcile the checkpoint with `regeneration-is-manual-only.md`'s "must be invoked
explicitly and never as a silent side effect of an unrelated operation" constraint by narrowing the
constraint's scope with a labeled exception, not by loosening it wholesale.

**Tasks**:

- [x] Leave the existing sentence under `## When to Prefer Which` **byte-for-byte intact**. Do not *(completed)*
      edit it in place. This matches the document's own established
      correction-as-addition pattern (see its `**CORRECTION.**` block).
- [x] Add a new subsection `## Automated Exception: The Inter-Cycle Self-Modification Checkpoint`, *(completed)*
      placed immediately after `## When to Prefer Which`, stating:
  - [x] The exact and only sanctioned automated call site: `skill-orchestrate`'s Stage MT-3 step 7. *(completed)*
  - [x] Why it is **not a side effect of an unrelated operation**: the fix that triggers it is *(completed)*
        precisely the fix the checkpoint exists to make live. The operation is not unrelated — it
        is the operation being corrected.
  - [x] Why it is **not silent**: the checkpoint logs on fire (naming the matched critical paths), *(completed)*
        on success (naming the deployed artifact count), and on failure (naming the failing gate
        and its exit code).
  - [x] Why it is **bounded**: evidence-gated on actual `modified_files` overlapping a declared *(completed)*
        critical path; fired at most once per critical path per invocation via the idempotence
        guard; and any failure defers the remainder of the invocation rather than proceeding.
  - [x] What the carve-out explicitly does **NOT** license: no other automated caller may invoke *(completed)*
        `deploy-headless.sh` without its own equivalent exception recorded in this same section.
        A future reader must not read this as general precedent for scripted deploys.
  - [x] A cross-reference to `context/patterns/batch-orchestration-guardrails.md`'s *(completed)*
        `### The Inter-Cycle Redeploy Checkpoint` subsection as the authoritative contract, so the
        contract itself is not duplicated here.
- [x] Add `context/patterns/batch-orchestration-guardrails.md` to the `## Related Documentation` *(completed)*
      list.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - new
  `## Automated Exception` subsection, Related Documentation entry.

**Verification**:

- `git diff` the file and confirm the "must be invoked explicitly and never as a silent side effect
  of an unrelated operation" line appears as context, never as a `-`/`+` pair.
- Grep for `## Automated Exception` and confirm the subsection names Stage MT-3 step 7 and contains
  an explicit "does not license" statement.
- Confirm no task-number citations.

---

### Phase 3: Harden `deploy-headless.sh` for automated invocation [COMPLETED]

**Goal**: Make the headless deploy safe to call automatically from inside the tree it overwrites,
and serialized against a concurrent session's reads of that tree.

**Tasks**:

- [x] **Confirm the self-overwrite hypothesis before implementing** (see Scope Hypothesis below). *(completed)*
      Determine whether the sync writes deployed files by truncate-in-place or by
      write-temp-then-rename. Record the finding in the phase notes either way.
- [x] If truncate-in-place is confirmed: restructure the script so its executable body is a single *(completed)*
      `main()` function defined in full before any of it runs, invoked as the file's last command,
      with every exit path inside `main` calling `exit` (never `return` followed by further
      top-level reads). Add a header comment naming the hazard by mechanism ("bash reads a script
      incrementally by byte offset; a deploy that rewrites this file in place while it is executing
      would resume at a stale offset") so a future editor does not undo the structure. If
      write-then-rename is confirmed instead, skip the restructure and record in the header that
      the hazard was evaluated and does not apply, with the evidence.
- [x] Add a self-contained, fail-open `specs/.deploy-lock/` mutex around the `nvim --headless` *(completed)*
      invocation:
  - [x] Acquire via `mkdir` (atomic-on-creation), write an owner file containing session/pid/epoch, *(completed)*
        release on every exit path including the failure paths at the `DEPLOY_ERROR` and empty-count
        branches.
  - [x] **Fail-open with a loud warning** on failed acquisition, mirroring the wording shape of the *(completed)*
        `specs/.commit-lock/` warning in `scripts/git-commit-scoped.sh` (acquire, warn, proceed
        unserialized) — do not introduce a blocking primitive and do not invent a second warning
        convention.
  - [x] Honor a stale-lock reclaim window so a crashed holder does not wedge every future deploy. *(completed)*
  - [x] **Implement it inline, without sourcing `scripts/task-lock.sh`.** State the reason in a *(completed)*
        comment: the deploy is about to overwrite the deployed copy of `task-lock.sh`, so depending
        on it here would be depending on the very file being replaced.
- [x] Extend the existing `SAFETY:` header block with a pointer to *(completed)*
      `context/patterns/regeneration-is-manual-only.md`'s `## Automated Exception` subsection, so a
      reader of the script sees that exactly one automated caller is sanctioned and where the
      justification lives.
- [x] Ensure `--dry-run` reports the mutex state (held / not held) and still writes nothing. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts that (a) the sync overwrites deployed files
truncate-in-place, making the self-overwrite hazard real, and (b) `deploy-headless.sh`'s current
top-level structure is exposed to it. Confirm (a) by reading the write call in the sync operations
module that `load_all_globally` reaches, and confirm (b) by checking whether the script's body
executes as top-level commands. If (a) is false the restructure is dropped and only the header note
lands; the mutex work is unaffected either way. Do not implement the restructure on the assumption
alone.

**Finding (confirmed, not assumed)**: (a) TRUE — `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`'s write path calls `helpers.write_file`, which is `vim.fn.writefile(lines, filepath)` with no flags. Neovim's own `writefile()` documentation states plainly: "An existing file is overwritten, if possible" — no temp-then-rename indirection, confirming truncate-in-place. (b) TRUE — the pre-edit `deploy-headless.sh` executed its entire body (arg parsing through the final `exit 0`) as top-level statements with no enclosing function, so a mid-execution overwrite of the file (which happens when `TARGET` defaults to the current repo, i.e. the file being executed is itself the file that gets overwritten) was a live exposure. The restructure into a single `main()` function invoked as the file's last physical line was therefore implemented, not skipped.

**Files to modify**:

- `agent-system/extensions/core/scripts/deploy-headless.sh` - `specs/.deploy-lock/` fail-open
  mutex, conditional self-overwrite restructure, header cross-reference, dry-run mutex reporting.

**Verification**:

- `bash -n agent-system/extensions/core/scripts/deploy-headless.sh` parses clean.
- `shellcheck` the file if available; no new warnings relative to the pre-edit baseline.
- Run `deploy-headless.sh --dry-run` from the repo root: exit 0, nothing written, mutex state
  reported, and `specs/.deploy-lock/` absent afterwards.
- Simulate a held lock by pre-creating `specs/.deploy-lock/` with a fresh owner file, run
  `--dry-run` again, confirm the loud fail-open warning is emitted and the exit code is unchanged,
  then remove the directory.
- Confirm the script still refuses a non-git-repository target (exit 1) and still reports its
  documented exit codes 0/1/2 unchanged.

---

### Phase 4: Document `verify-deploy.sh` as the checkpoint's hard gate [COMPLETED]

**Goal**: Make the checkpoint's consumption contract for `verify-deploy.sh` explicit at the script
itself, so a future editor does not change its exit-code semantics without seeing the caller.

**Tasks**:

- [x] Extend the script's header comment block with a `Callers:` note naming the inter-cycle *(completed)*
      redeploy checkpoint (`skill-orchestrate` Stage MT-3 step 7) as an automated consumer, and
      cross-referencing `context/patterns/batch-orchestration-guardrails.md`'s
      `### The Inter-Cycle Redeploy Checkpoint` subsection.
- [x] State explicitly in the exit-code block that an automated gate treats **exit 2 ("cannot run") *(completed)*
      as failure, not as a pass** — a checkpoint that cannot establish the redeploy landed is in
      the same position as one that established it did not. This closes the one point the research
      report left open.
- [x] Reinforce the existing "do NOT report a passing run here as end-to-end verification" note by *(completed)*
      stating what the checkpoint therefore does and does not claim: it claims the deploy tree
      matches its source store and hooks are registered; it does not claim the redeployed machinery
      has been exercised.
- [x] Make no behavioral change to any check, and no change to any exit code. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/core/scripts/verify-deploy.sh` - header `Callers:` note, exit-2
  treatment statement, claim-scope reinforcement. Comments only.

**Verification**:

- `git diff` shows changes confined to comment lines; no executable line is touched.
- `bash -n` parses clean.
- Run `verify-deploy.sh --quiet` and confirm the exit code matches the pre-edit baseline for the
  same tree state.

---

### Phase 5: Wire the checkpoint into `skill-orchestrate` Stage MT-3 [COMPLETED]

**Goal**: Add the executable checkpoint as Stage MT-3 step 7, with the state it needs threaded
through MT-3, MT-4 step 5.5, and MT-5.

**Tasks**:

- [x] **`mt_state_file` schema** (the initialization site in Stage MT-2, anchored on the existing *(completed)*
      `deferred_self_modifying: []` declaration): add two invocation-scoped fields alongside it,
      with the same never-reset-mid-invocation semantics:
  - [x] `deferred_deploy_checkpoint: []` — task numbers excluded for the remainder of the *(completed)*
        invocation because a checkpoint gate failed.
  - [x] `deployed_critical_paths: []` — critical paths already redeployed this invocation; the *(completed)*
        idempotence guard's backing store.
- [x] **Stage MT-4 step 5.5 accumulation**: at the point where the existing `while IFS= read -r f` *(completed)*
      loop reads `.modified_files[]?` from that task's `.return-meta.json` into `stage_paths`, also
      append each path to a cycle-scoped `cycle_modified_files` array. State in a comment why the
      accumulation happens here rather than being re-read in step 7: the metadata file may be
      removed by postflight cleanup before step 7 runs. Make no other change to step 5.5 — its
      staging, fail-safe warning, commit-message selection, non-blocking behavior, and branch
      coverage are all unchanged.
- [x] **New Stage MT-3 step 7: Inter-cycle redeploy checkpoint**, placed after step 6 (cycle-count *(completed)*
      increment) and before the loop returns to step 1. Content:
  - [x] State the sequencing guarantee up front: every task dispatched this cycle already had its *(completed)*
        own scoped commit attempted at step 5.5, unconditionally, before this step runs.
        Committed-then-redeployed is guaranteed by step ordering, not by new synchronization.
  - [x] **Overlap computation**: expand `context/reference/orchestrator-critical-paths.json` using *(completed)*
        the same `scope_roots x critical_paths` jq expression `orchestrate-batch-admit.sh` already
        performs (reuse it; do not re-derive), and intersect against `cycle_modified_files` using
        the directory-prefix overlap predicate in `context/patterns/file-footprint-overlap.md`
        (referenced by path, never restated).
  - [x] **Idempotence guard**: subtract `mt_state_file.deployed_critical_paths` from the overlap *(completed)*
        set. If the remainder is empty, skip the checkpoint this cycle at zero further cost and
        continue to the next cycle. Include the convergence rationale inline.
  - [x] **Fire**: log a loud notice naming every matched critical path and its label, then run, *(completed)*
        in order: `bash .claude/scripts/deploy-headless.sh` (from the repo root), then — only on
        its success — `bash .claude/scripts/verify-deploy.sh`.
  - [x] **Success path**: record the matched paths into `mt_state_file.deployed_critical_paths`, *(completed)*
        log the deployed artifact count and a `verify-deploy` pass, continue to the next cycle.
  - [x] **Failure path**: `deploy-headless.sh` exit 1 or 2, or `verify-deploy.sh` exit 1 or 2 (exit *(completed)*
        2 is a failure, per Phase 4). Log a loud warning naming which gate failed and its exit code,
        then add every task in `task_numbers` that is not terminal, not in `failed_tasks`, and not
        already in `deferred_self_modifying` to `mt_state_file.deferred_deploy_checkpoint`. Never
        add to `failed_tasks`. Never status-mutate. Never abort the invocation. Include the
        operator remedy in the warning: fix the deploy/verify failure, redeploy manually, then
        re-run `/orchestrate` on the remaining task numbers.
  - [x] Note explicitly that already-dispatched-and-committed tasks from prior cycles are *(completed)*
        unaffected — their commits landed at step 5.5 before this step ran.
- [x] **Thread `deferred_deploy_checkpoint` through the loop**, mirroring `deferred_self_modifying` *(completed)*
      at each existing site rather than inventing new control flow:
  - [x] Step 2 (all-terminal check): treat membership the same as terminal/failed for deciding *(completed)*
        whether the loop has anything left to do.
  - [x] Step 3 (build `eligible_tasks`): exclude members. This is what makes the deferral converge. *(completed)*
  - [x] Step 4 (no-eligible circuit breaker): exclude members from the "stuck tasks" framing, the *(completed)*
        same way `deferred_self_modifying` members are excluded.
- [x] **Stage MT-5**: add `deferred_deploy_checkpoint` to the `mt_state_file` read in step 1; make *(completed)*
      a non-empty set force `exit_status = "partial"` in step 2 (same clause shape as
      `deferred_self_modifying`, with the same "incomplete by design, not broken" framing); report
      it in step 3 as a **distinct** category — **deferred-by-redeploy-checkpoint**, separate from
      both deferred-for-solo-run and `failed_tasks`, because the operator remedy differs; and add a
      corresponding `tasks_deferred_deploy_checkpoint` field to the `.return-meta-multi.json` jq
      construction.
- [x] Cross-reference `context/patterns/batch-orchestration-guardrails.md`'s *(completed)*
      `### The Inter-Cycle Redeploy Checkpoint` subsection from step 7 as the authoritative contract
      rather than restating the rationale in the skill text.

**Timing**: 1.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts six edit sites inside a single file: the `mt_state_file`
initialization block (anchored on `deferred_self_modifying: []`), Stage MT-3 steps 2, 3, and 4, the
`.modified_files[]?` read inside Stage MT-4 step 5.5, and Stage MT-5 steps 1-3 plus its
`.return-meta-multi.json` jq block. Confirm each by grepping for `deferred_self_modifying` and for
`modified_files` and locating every hit by surrounding heading and step number, never by line
number. If the count of `deferred_self_modifying` sites differs from what this plan enumerates,
treat every additional site as in scope for the mirroring and record the divergence.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - `mt_state_file` schema, MT-3
  steps 2/3/4 and new step 7, MT-4 step 5.5 accumulation, MT-5 steps 1/2/3 and multi-metadata jq.

**Verification**:

- Grep the file for `deferred_deploy_checkpoint` and confirm a hit at every site where
  `deferred_self_modifying` appears in a control-flow role (MT-3 steps 2/3/4, MT-5 steps 1/2/3, the
  multi-metadata jq) plus the new step 7 population site.
- Grep for `deployed_critical_paths` and confirm both the schema declaration and the step-7
  idempotence guard.
- Confirm step 7 is positioned after step 6 and before the `### Stage MT-4` heading.
- Confirm step 7 references `orchestrator-critical-paths.json` and `file-footprint-overlap.md` by
  path and does not restate the overlap algorithm.
- Confirm Stage MT-4 step 5.5's staging block, fail-safe warning, commit-message table, and branch
  coverage are otherwise unchanged (`git diff` the step and confirm the only addition is the
  accumulation line and its comment).
- Confirm no task-number citations were introduced.

---

### Phase 6: Cross-reference the checkpoint from `commands/orchestrate.md` [COMPLETED]

**Goal**: Keep the command-level documentation consistent with the skill's new behavior, so a
reader of `orchestrate.md` alone does not conclude that no redeploy ever happens mid-invocation.

**Tasks**:

- [x] Under `### MULTI-TASK DISPATCH`, at the existing self-modification defer-trigger discussion, *(completed)*
      add a short note that a task whose *actual* `modified_files` touch a critical path — as
      distinct from its *declared* `file_scope`, which is what this gate reads — is caught after
      dispatch by the inter-cycle redeploy checkpoint in `skill-orchestrate` Stage MT-3 step 7.
      Reference the guardrails subsection for the contract.
- [x] Under `#### Step 5: Commit Reconciliation and Consolidated Output`, in the *(completed)*
      **Commit Reconciliation (no batch commit)** discussion, add one clause stating the ordering
      explicitly: per-task commits at Stage MT-4 step 5.5 always precede the inter-cycle redeploy
      checkpoint, so a wave's work is committed before the tree it produced is redeployed over.
- [x] Add a row to the results-table area under `## Batch Orchestrate Results` (alongside the *(completed)*
      existing `Deferred self-modifying` row and the `### Skipped` section) covering
      **deferred-by-redeploy-checkpoint**, with its distinct operator remedy: resolve the
      deploy/verify failure, redeploy manually, re-run `/orchestrate` on the remaining task numbers.
- [x] Restate nothing about the trigger, failure contract, or idempotence guard — cross-reference *(completed)*
      the guardrails subsection instead.

**Timing**: 0.5 hours

**Depends on**: 5

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts three edit sites in `commands/orchestrate.md`: the
self-modification defer-trigger discussion under `### MULTI-TASK DISPATCH`, the
**Commit Reconciliation (no batch commit)** block under `#### Step 5`, and the results-reporting
area under `## Batch Orchestrate Results`. Confirm each by grepping for
`self-modification defer trigger`, `Commit Reconciliation`, and `Deferred self-modifying`, locating
hits by heading rather than line number.

**Files to modify**:

- `agent-system/extensions/core/commands/orchestrate.md` - three cross-reference additions.

**Verification**:

- Grep for `step 7` (or the step-7 reference wording used) and confirm all three sites reference
  the checkpoint.
- Confirm the trigger and failure contract are referenced, not restated (no duplicated contract
  prose that could drift from the guardrails doc).
- Confirm no task-number citations.

---

### Phase 7: Cross-document consistency and full gate [NOT STARTED]

**Goal**: Verify the six edited files agree with each other and with the two files deliberately
left unedited, and run the repository's full gate set.

**Tasks**:

- [ ] **Verify the hard-mode inheritance claim rather than assuming it**: grep
      `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` Stage 0 for the
      multi-task delegation-by-reference sentence ("use base multi-task stages" or equivalent).
      If present, record that the checkpoint is inherited with no edit required. **If absent or
      changed, do not edit the file** — record it as a discovered divergence requiring a follow-up
      task, since that file is outside the declared file scope and is itself an orchestrator-critical
      path.
- [ ] **Contract-consistency sweep**: confirm the trigger, failure contract, sequencing, and
      idempotence guard are stated **once** (in the guardrails subsection) and referenced — not
      restated — by `regeneration-is-manual-only.md`, `skill-orchestrate/SKILL.md`,
      `commands/orchestrate.md`, `deploy-headless.sh`, and `verify-deploy.sh`. Any second statement
      of the contract is drift waiting to happen and must be collapsed to a cross-reference.
- [ ] **Terminology sweep**: confirm every file uses `deferred_deploy_checkpoint` and
      `deployed_critical_paths` verbatim, with no spelling variants, and that
      `deferred_self_modifying` is never reused for checkpoint deferrals.
- [ ] **Source-store boundary check**: confirm `git status --short` shows no modifications under
      `.claude/` — every edit landed under `agent-system/extensions/core/`.
- [ ] **No-task-references check**: grep all six edited files for `task [0-9]`, `tasks [0-9]`, and
      `(task ` and confirm zero hits.
- [ ] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` (doc-lint gate) and
      confirm it exits zero, or that any failure predates this task's changes.
- [ ] Run `bash -n` over both edited shell scripts.
- [ ] Run `bash .claude/scripts/validate-artifact.sh` against this plan if the helper is available,
      confirming per-phase Verification Tier fields are present.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4, 5, 6

**Verification Tier**: full

**Files to modify**:

- None (verification only). Any defect found is repaired in the phase that owns the file.

**Verification**:

- Doc-lint exits zero (or the failure is demonstrably pre-existing, with evidence).
- Zero task-number citations across the six edited files.
- Zero modifications under `.claude/`.
- The hard-mode delegation sentence is confirmed present, with the grep output recorded.

---

## Testing & Validation

- [ ] `bash -n` parses both `deploy-headless.sh` and `verify-deploy.sh` clean.
- [ ] `deploy-headless.sh --dry-run` exits 0, writes nothing, reports mutex state, and leaves no
      `specs/.deploy-lock/` behind.
- [ ] With `specs/.deploy-lock/` pre-created, `deploy-headless.sh --dry-run` emits the fail-open
      warning and does not block.
- [ ] `verify-deploy.sh --quiet` exit code is unchanged from the pre-edit baseline for the same
      tree state.
- [ ] `check-extension-docs.sh` exits zero.
- [ ] `deferred_deploy_checkpoint` appears at every control-flow site in
      `skill-orchestrate/SKILL.md` where `deferred_self_modifying` appears in a control-flow role.
- [ ] Stage MT-3 step 7 is positioned after step 6 and before the `### Stage MT-4` heading.
- [ ] Hazard 3 in the guardrails doc reads as partially retired, names both residual forms, and
      names the replacement exposure as a mid-session manifestation of hazard 1.
- [ ] `regeneration-is-manual-only.md`'s "never as a silent side effect of an unrelated operation"
      sentence is unmodified in the diff.
- [ ] No file under `.claude/` is modified.
- [ ] No task-number citations in any edited file.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (modified)
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (modified)
- `agent-system/extensions/core/scripts/deploy-headless.sh` (modified)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (modified)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified)
- `agent-system/extensions/core/commands/orchestrate.md` (modified)
- `specs/934_inter_wave_redeploy_checkpoint/summaries/01_inter-cycle-redeploy-checkpoint-summary.md`

## Rollback/Contingency

All six files are markdown or shell under version control, and every phase commits at its own
granularity, so rollback is per-phase `git revert` of that phase's commit — no schema migration, no
generated artifact, and no state to unwind.

Two narrower contingencies if the checkpoint proves too aggressive in practice, both editable in
place without reverting the documentation:

- **Relax to warn-only**: change Stage MT-3 step 7's failure path from populating
  `deferred_deploy_checkpoint` to logging only. This weakens the contract and must be recorded in
  the guardrails subsection if taken, never applied silently.
- **Disable the checkpoint**: delete step 7 and its `mt_state_file` fields. The threading in MT-3
  steps 2/3/4 and MT-5 becomes dead but harmless (an always-empty set), so a partial revert is safe
  if a full one is not desired.

This task modifies orchestrator-critical machinery, so it must be run solo — the self-modification
admission gate already enforces that for any invocation whose batch includes it. After
implementation, redeploy manually (`<leader>al` "Load Core", or `deploy-headless.sh` invoked
deliberately) and run `verify-deploy.sh` before relying on the new behavior. The first exercise of
the checkpoint will necessarily run against the pre-change deployed copy of the skill text — the
bootstrapping circularity this task documents applies to this task itself.
