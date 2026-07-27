# Implementation Plan: Task #907

- **Task**: 907 - Establish an orchestrator runtime-file tracking policy so ephemeral loop guards are never committed
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: 885, 902, 906, 909 (serialization-for-file-overlap edges only; no logical prerequisites)
- **Research Inputs**: specs/907_orchestrator_runtime_file_tracking_policy/reports/01_runtime-file-tracking-policy.md
- **Artifacts**: plans/01_runtime-file-tracking-policy.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Establish a single, source-store-authored policy that splits the runtime files `/orchestrate`
writes under `specs/{NNN}_{SLUG}/` into two classes — **ephemeral** (gitignored and untracked)
and **durable provenance** (kept tracked) — and reconcile every artifact that currently
contradicts that split. The split is the user's settled decision and is not re-opened here.
Delivery is: a new canonical policy standard, a narrowed staging contract with explicit
exclusion pathspecs at both `commands/orchestrate.md` staging sites, ephemerality statements in
both orchestrate skills, a corrected `handoff-schema.md`, a shipped verification script, and the
consumer-side application of the policy to this repository's own root `.gitignore` (which, in
this repo, is a **reversal**: two existing ignore lines are removed).

Definition of done: the three verification requirements in the task description are demonstrated
with recorded evidence, and no shipped artifact still describes `.orchestrator-handoff.json` or
`.return-meta.json` as "not checked in".

### Research Integration

The research report is treated as verified and is not re-litigated. Findings carried directly
into this plan:

- **Finding 1** — `docs/architecture/handoff-schema.md` line 5 says the handoff is "runtime; not
  checked in". This is current and correct-as-written today, so implementing the decided policy
  requires rewriting it in the same change (Phase 4). The repo-root `.gitignore` comment block
  (lines 25-31) quotes that same line and must be rewritten with it (Phase 6).
- **Finding 2** — the mid-lifecycle sweep is real: `orchestrator-postflight.sh` Stage 9 runs a
  whole-task-dir `git add` every dispatch cycle, while loop-guard cleanup fires only at full-loop
  termination (`rm -f "$loop_guard_file"` at `skill-orchestrate/SKILL.md` lines 444 and 912;
  `skill-orchestrate-hard/SKILL.md` lines 569, 648, 660, 1119). Live evidence: a committed,
  mid-run guard in `/home/benjamin/.dotfiles`.
- **Finding 3** — the documented rationale for the split: the loop guard has **no** freshness
  gate (`skill-orchestrate/SKILL.md` lines 130-133 resume `cycle_count` from any syntactically
  valid file, with no session_id or mtime check), whereas the handoff has a documented
  mtime-vs-`dispatch_start_ts` gate and `.return-meta.json` has an equivalent gate at its
  recovery read site. Ephemeral-and-ungated must be ignored; gated provenance is safe to track.
  This rationale is what gets written into the new standard — not the bare assertion.
- **Finding 4** — repo asymmetry: this repo already carries the full ephemeral ignore block
  (root `.gitignore` lines 25-40) and has **0** tracked runtime files; `/home/benjamin/.dotfiles`
  has no coverage at all and ~80 committed. Shipped guidance must work from both starting states.
- **Finding 5** — `root-files/.gitignore` **cannot** deliver `specs/*/` patterns: `copy_root_files()`
  deploys into the consumer's `.claude/` root, so the pattern would resolve to `.claude/specs/*/`
  and match nothing. No repo-root deploy path exists in the source store. Deliverable is therefore
  documented setup guidance **plus** a verification check; a net-new loader primitive is out of
  scope (see Non-Goals).
- **Finding 6** — applying the policy here is a reversal with a real, forward-only migration:
  removing the two ignore lines makes already-on-disk files stageable with no retroactive backfill.

Live counts re-confirmed in this repo at plan time: 299 `.return-meta.json`, 213
`.orchestrator-handoff.json`, 4 `.orchestrator-loop-guard`, 0 `.orchestrator-churn-state.json`,
3 `.lock/` directories on disk; **0** of any class currently tracked by git.

### Settled Decision (do not re-open)

- **GITIGNORE + UNTRACK (ephemeral)**: `specs/*/.orchestrator-loop-guard`, `specs/*/.lock/`,
  `specs/*/.orchestrator-churn-state.json`.
- **KEEP TRACKED (durable provenance)**: `specs/*/.orchestrator-handoff.json`,
  `specs/*/.return-meta.json` — in this repo a reversal, removing root `.gitignore` line 1
  (`**/.return-meta.json`) and line 33 (`**/.orchestrator-handoff.json`).
- The user explicitly accepted that ~512 currently-ignored files become stageable with **no**
  retroactive history backfill.
- `docs/architecture/handoff-schema.md` line 5 must be rewritten in the same change.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and `roadmap_flag` was not set, so
`specs/ROADMAP.md` was not consulted and no roadmap review/update phases are included.

## Declared file_scope Expansion

The task's declared `file_scope` is `commands/orchestrate.md`,
`context/standards/git-staging-scope.md`, `root-files/`, `skills/skill-orchestrate-hard/SKILL.md`,
`skills/skill-orchestrate/SKILL.md`, `templates/` — all under
`agent-system/extensions/core/`. The settled decision cannot be implemented within that set. This
plan therefore **declares** the following expansion explicitly rather than editing out of scope
silently. Every entry below is justified by a specific requirement, not convenience.

| Path | Phase | Why it must be in scope |
|------|-------|--------------------------|
| `/.gitignore` (repo root) | 6 | The consumer-side application of the decided policy. This is the ONLY place the un-ignore of handoff/return-meta can happen, and Finding 5 proves no source-store path can deliver it. Called out below as a sanctioned exception to the SOURCE-STORE RULE. |
| `agent-system/extensions/core/docs/architecture/handoff-schema.md` | 4 | Line 5's "runtime; not checked in" is the artifact the decision directly contradicts. The user's decision names this file explicitly. |
| `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (new) | 1 | The policy needs one canonical home. `git-staging-scope.md` governs staging scope, not file-tracking classification; overloading it would leave the policy hard to cite from the skills, the check script, and consumer setup guidance. |
| `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` (new) | 5 | The task requires "documented guidance **plus** a check" and forbids shipping a pattern file that does nothing. This is the check. |
| `agent-system/extensions/core/manifest.json` | 5 | `provides.scripts` enumerates individual filenames, so a new script is not deployed unless registered. Mechanical consequence of the line above. |
| `agent-system/extensions/core/context/guides/loader-reference.md` | 4 | Three-line note recording the verified `copy_root_files()` limitation, so the "put it in `root-files/`" mistake does not recur. Recommended by the research report's Context Extension Recommendations. |

`root-files/` and `templates/` remain in scope but are deliberately **not modified** — Finding 5
proves a `specs/*/` pattern placed there would silently match nothing. That non-edit is itself a
finding to record, not an omission.

## Binding Constraints

- **SOURCE-STORE RULE**: agent-system edits target `agent-system/extensions/core/**`, never
  `.claude/**`. The repo-root `/.gitignore` edit in Phase 6 is a legitimate **consumer-side**
  exception under the expansion declared above, not a violation — it is the application of the
  shipped policy to this repository, not an edit to the agent system.
- **No task-number references** in any file outside `specs/**` (per
  `no-task-references-in-deliverables.md`). Cite durable anchors (file names, section headings,
  mechanism descriptions) instead.
- `.claude/` is a **stale deploy artifact** that is NOT being re-synced during this run. Source-store
  edits will not change the behavior of the in-flight orchestration. Do not re-sync it.

## Ordering Constraint (critical — plan around it)

An `/orchestrate` run is executing this task, and its own CHECKPOINT 3 runs
`git add specs/907_.../` on completion. **The un-ignore of handoff/return-meta (Phase 6) MUST NOT
land before the ephemeral ignore lines and the staging narrowing.** Phase 6 therefore depends on
Phases 2-5 and is the last content phase before verification.

Two facts materially reduce (but do not eliminate) the hazard in this repository, and both are
recorded here so the implementer does not mistake safety for luck:

1. This repo **already** carries every ephemeral ignore line (root `.gitignore` lines 32, 34-40).
   Phase 6 removes only lines 1 and 33 and rewrites the comment block; it removes **no** ephemeral
   coverage. So at every commit boundary in this session, ephemeral files stay ignored.
2. The staging narrowing lands in the source store, which the in-flight run does not read. The
   in-flight run keeps using the deployed whole-dir `git add`; it is safe purely because of fact 1.

The constraint is still honored by phase ordering, because it is the general contract for any
consumer repo — including one with no ephemeral coverage at all.

## Goals & Non-Goals

**Goals**:
- Ship one canonical, source-store-authored policy naming every runtime file class under
  `specs/{NNN}_{SLUG}/` and its tracking disposition, with the freshness-gate rationale.
- Make automated staging correct **independently** of consumer gitignore state, so a repo with no
  coverage is still protected.
- Stop `handoff-schema.md`, `git-staging-scope.md`, and this repo's root `.gitignore` from
  contradicting each other or the decided policy.
- Ship a runnable verification check plus copy-pasteable consumer setup guidance (including
  `git rm --cached` untracking, and an explicit "do NOT untrack handoff/return-meta").
- Demonstrate the three required verifications with recorded evidence.

**Non-Goals**:
- Building a new loader primitive (e.g. `append_root_gitignore()`) to auto-deploy repo-root
  gitignore contributions. Finding 5 flags this as a candidate follow-up task with its own
  idempotency and merge-conflict design questions; it is not attempted inline.
- Retroactively backfilling the ~512 already-on-disk handoff/return-meta files into git history.
  The policy is forward-only; the user accepted this.
- Remediating `/home/benjamin/.dotfiles`. Its ~80 committed runtime files are the motivating
  evidence, but the fix is shipped guidance plus the check script, applied there separately.
- Re-syncing `.claude/` from the source store.
- Adding any pattern to `root-files/.gitignore` or `templates/` (proven to match nothing).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Un-ignoring handoff/return-meta causes the next automated commit to sweep unintended files | H | L | Phase 6 ordered last among content phases; this repo retains full ephemeral coverage throughout; Phase 6 ends with `git status --short` review before any commit |
| An allowlist-style staging narrowing silently drops durable artifacts | H | M | Verified at plan time that live task dirs also contain `progress/`, `handoffs/`, `fixtures/`, `tests/`, `HANDOFF.md`. Plan uses **exclusion pathspecs**, not an allowlist — see the deviation note in Phase 2 |
| Staging narrowing has no effect until consumers re-sync `.claude/` | M | H | Treat gitignore coverage as the primary fix (it is sufficient alone — this repo has 0 tracked runtime files purely from coverage) and staging exclusions as defense-in-depth. State this explicitly in the standard |
| The runtime-file class list is incomplete | M | M | Phase 1 runs an explicit source-store audit rather than trusting the five known names; the suffixed `.return-meta-*.json` variants are already known to differ from the bare durable name |
| New script is written but never deployed | M | M | Phase 5 registers it in `manifest.json` `provides.scripts` in the same phase and verifies with `jq` |
| Task-number citations leak into deliverables | L | M | Every phase's verification includes a grep for task-number citation patterns in files touched outside `specs/**` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 2, 3, 4, 5 |
| 4 | 7 | 6 |

Phases within the same wave can execute in parallel. Wave 2 phases touch disjoint file sets
(Phase 2: `commands/orchestrate.md` + `context/standards/git-staging-scope.md`; Phase 3: the two
`SKILL.md` files; Phase 4: `docs/architecture/handoff-schema.md` +
`context/guides/loader-reference.md`; Phase 5: `scripts/` + `manifest.json`), so parallel
execution carries no write conflict.

---

### Phase 1: Audit runtime file classes and author the canonical policy standard [COMPLETED]

**Goal**: Produce a verified, complete inventory of runtime scratch files written under
`specs/{NNN}_{SLUG}/`, and write the canonical policy standard that every later phase cites.

**Tasks**:
- [x] Audit the source store for every runtime file written under a task directory — do not assume
      the five known names are complete. Suggested sweep (from `agent-system/extensions/core/`):
      `grep -rnoE '\$\{?(TASK_DIR|task_dir)\}?/\.[A-Za-z0-9._-]+' skills/ scripts/ commands/ context/ | sort -u`
      plus a filesystem cross-check: `find specs -mindepth 2 -maxdepth 2 -name '.*' | sed 's|.*/||' | sort -u`
      *(completed: audit surfaced two additional names beyond the known five — `.drift-inspection.json`
      (adopted into the ephemeral class, same no-freshness-gate rationale) and
      `.stray-handoff-*.json` (reviewed and deliberately excluded — diagnostic evidence, not
      classified either way); see deviation entry)*
- [x] Reconcile the audit against the classes already listed in this repo's root `.gitignore`
      lines 25-40, which include several beyond the task description's five:
      `.continuation-loop-guard`, `.postflight-loop-guard`, `.orchestrator-multi-state.json`,
      `.return-meta-*.json`, `.events.lock`. Confirm each is genuinely ephemeral before adopting it
      into the shipped policy. *(completed: all confirmed genuinely ephemeral, entries added to
      the class table)*
- [x] Record the **`.return-meta.json` vs `.return-meta-*.json` distinction explicitly**: the bare
      name is durable provenance; suffixed variants (e.g. the orchestrate-scoped one observed on
      disk) are ephemeral. A future reader must not collapse them. *(completed)*
- [x] Create `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` with:
  - [x] **Two-class table**: every audited file, its writer, its reader, its cleanup site, and its
        disposition (ephemeral / durable provenance).
  - [x] **Rationale section**: the freshness-gate asymmetry. The loop guard resumes `cycle_count`
        from any syntactically valid file with no session_id and no mtime check; the handoff has a
        documented mtime-vs-`dispatch_start_ts` gate and `.return-meta.json` has an equivalent gate
        at its recovery read site. Ephemeral-and-ungated must be ignored; gated provenance is safe
        to track. Cite the mechanism and file/section names, never a task number.
  - [x] **Consumer repo setup** section: the exact, copy-pasteable block for the consumer's **root**
        `.gitignore`, with a prominent note that this is applied by hand once — `root-files/` deploys
        into `.claude/` and a `specs/*/` pattern placed there resolves to `.claude/specs/*/` and
        matches nothing.
  - [x] **Untracking already-committed ephemeral files**: `git rm --cached <path>` (and
        `git rm -r --cached <dir>` for `.lock/`), stating that it leaves the file on disk so an
        in-flight orchestration is not disrupted.
  - [x] **Explicit prohibition**: handoff and return-meta files MUST NOT be untracked; they are the
        per-dispatch audit trail.
  - [x] **Forward-only note**: adopting the policy in a repo that previously ignored
        handoff/return-meta makes existing on-disk files newly stageable with no retroactive
        backfill; task directories that never receive another commit keep theirs untracked.
  - [x] **Defense-in-depth note**: gitignore coverage is the primary and sufficient control;
        staging exclusions protect repos that have not applied it.
- [x] Verify no task-number citations were introduced. *(completed: grep clean)*

**Timing**: 1.25 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - new canonical policy

**Verification**:
- The file exists, is non-empty, and its class table covers every name the audit sweep returned.
- `grep -nE '\btasks? [0-9]{2,}\b' agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` returns nothing.
- The `.return-meta.json` vs `.return-meta-*.json` distinction is present verbatim.

---

### Phase 2: Narrow the staging contract and both orchestrate staging sites [NOT STARTED]

**Goal**: Make automated task-directory staging exclude the ephemeral classes explicitly, so it is
correct in a consumer repo with zero gitignore coverage.

**Deviation from the task description's suggested mechanism — declared, with justification**:
The task description offers `git-staging-scope.md` lines 72-76 (the research variant's enumerated
allowlist) as "the model for the fix". A literal allowlist is **not** used, because live task
directories in this repo also contain `progress/`, `handoffs/`, `fixtures/`, `tests/`, and
`HANDOFF.md` — an allowlist of `reports/ plans/ summaries/ .return-meta.json
.orchestrator-handoff.json` would silently stop committing all of them, trading one silent-drop
bug for another. This plan instead applies the **principle** behind that narrow form (stop staging
the whole directory blindly) using git exclusion pathspecs, which drop exactly the ephemeral
classes and nothing else. Verified working at plan time (git 2.54.0): staging a task dir with
`:(exclude)` for the loop guard, churn state, and `.lock/` staged only the durable file.

**Tasks**:
- [ ] Edit `agent-system/extensions/core/context/standards/git-staging-scope.md`:
  - [ ] Lines 25-27 (`plan` scope) — stop presenting the bare `specs/{padded}_{slug}/` form as safe;
        replace with the exclusion-pathspec form and a pointer to the new runtime-files standard.
  - [ ] Lines 88-90 (`implement` reference template) — same change to the `stage_paths` array.
  - [ ] Add a short subsection defining the canonical exclusion set once, so later readers extend
        one list rather than three:
        ```bash
        task_dir="specs/${padded_num}_${project_name}"
        ephemeral_excludes=(
          ":(exclude)${task_dir}/.orchestrator-loop-guard"
          ":(exclude)${task_dir}/.orchestrator-churn-state.json"
          ":(exclude)${task_dir}/.lock/"
        )
        git add "$task_dir" "${ephemeral_excludes[@]}" "specs/TODO.md" "specs/state.json"
        ```
  - [ ] State that handoff and return-meta are deliberately **not** excluded — they are durable
        provenance and staging them is intended.
  - [ ] Add the new standard to the "Related Documentation" list.
- [ ] Edit `agent-system/extensions/core/commands/orchestrate.md` at **both** confirmed staging
      sites, using the same exclusion set:
  - [ ] Multi-task batch commit (~lines 365-373): the per-task loop appends
        `specs/${tpadded}_${tname}/`; append the three exclusion pathspecs per task alongside it.
  - [ ] CHECKPOINT 3 single-task commit (~lines 496-501): add the exclusions to `stage_paths`
        before `git add`.
- [ ] Verify no task-number citations were introduced.

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - narrow both staging forms, add canonical exclusion set, cross-reference
- `agent-system/extensions/core/commands/orchestrate.md` - exclusion pathspecs at both staging sites

**Verification**:
- `grep -n 'exclude' agent-system/extensions/core/commands/orchestrate.md` shows the exclusions at
  both staging sites (batch loop and CHECKPOINT 3).
- No occurrence of a bare `git add "specs/${...}/"`-style whole-dir add without exclusions remains
  in `commands/orchestrate.md`.
- `git-staging-scope.md` lines formerly at 25-27 and 88-90 no longer present the unqualified
  whole-task-dir form as the contract.
- Task-number citation grep is clean on both files.

---

### Phase 3: Document ephemerality in both orchestrate skills [NOT STARTED]

**Goal**: Make the never-committed status of the loop guard and churn state legible at the exact
sites that create, resume from, and clean up those files.

**Tasks**:
- [ ] `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`:
  - [ ] At the Stage 2 loop-guard definition (~line 122) add a short note: the loop guard is
        ephemeral runtime state, is never committed, and the resume branch below trusts any
        syntactically valid guard at this path with **no** session_id or mtime check — which is
        precisely why a git-restorable guard would corrupt the cycle budget.
  - [ ] At the cleanup sites (~lines 444, 912) note that cleanup fires only at full-loop
        termination, never between cycles, so per-cycle commits would otherwise capture a mid-run
        guard.
  - [ ] Cross-reference the new runtime-files standard.
- [ ] `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`:
  - [ ] Mirror the same statements at the loop-guard definition (~line 234) and add the equivalent
        for `.orchestrator-churn-state.json` (~line 237) — same ephemeral class, same hazard.
  - [ ] Note the cleanup sites (~lines 569, 648, 660, 1119) share the loop-termination-only timing.
  - [ ] Cross-reference the new runtime-files standard.
- [ ] Verify no task-number citations were introduced.

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - ephemerality notes at guard definition and cleanup sites
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - same, plus churn-state coverage

**Verification**:
- Both files reference `orchestrator-runtime-files.md`.
- The hard variant's note covers `.orchestrator-churn-state.json` by name, not only the loop guard.
- No executable behavior changed — the diff is comment/prose only. Confirm with
  `git diff -- agent-system/extensions/core/skills/` that no bash line was altered.
- Task-number citation grep is clean on both files.

---

### Phase 4: Reconcile handoff-schema.md and record the loader limitation [NOT STARTED]

**Goal**: Remove the contradiction the decision named explicitly, and prevent the
`root-files/`-can-deliver-this mistake from recurring.

**Tasks**:
- [ ] `agent-system/extensions/core/docs/architecture/handoff-schema.md`:
  - [ ] Rewrite line 5's `(runtime; not checked in)` to state the decided disposition: the handoff
        is per-dispatch runtime state that **is** tracked as durable provenance.
  - [ ] Add one or two sentences immediately after, giving the reason: the reader-side
        mtime-vs-`dispatch_start_ts` freshness gate documented later in this same file neutralizes
        the "restored from an old commit" scenario, which is exactly what the ungated loop guard
        lacks. Point to `orchestrator-runtime-files.md` for the full two-class policy.
  - [ ] Scan the rest of the file for consistency and confirm the "The filename is static (not
        timestamped). Each dispatch cycle overwrites the previous handoff" statement (~lines
        351-352) still holds — it does; overwriting a tracked file is unchanged behavior, only the
        per-cycle diff becomes part of history. Leave it as-is unless the surrounding framing
        implies untracked-ness.
  - [ ] Check the "Outcome Channels" section's `.return-meta.json` description for any equivalent
        "not checked in" framing and correct it if present.
- [ ] `agent-system/extensions/core/context/guides/loader-reference.md`:
  - [ ] Add a short note near the `copy_root_files()` row (~line 29) recording that `root_files`
        deploy into the target `.claude/` root, so repo-root contributions (a `specs/*/` gitignore
        block being the motivating case) cannot be delivered this way and are applied by hand per
        `orchestrator-runtime-files.md`.
- [ ] Verify no task-number citations were introduced.

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - file-location line and framing
- `agent-system/extensions/core/context/guides/loader-reference.md` - copy_root_files limitation note

**Verification**:
- `grep -rn 'not checked in' agent-system/extensions/core/docs/architecture/handoff-schema.md`
  returns nothing.
- `grep -rn 'not checked in' agent-system/extensions/core/` returns no hit that refers to the
  handoff or return-meta files.
- `loader-reference.md` mentions the repo-root limitation and names the new standard.
- Task-number citation grep is clean on both files.

---

### Phase 5: Ship and register the verification check script [NOT STARTED]

**Goal**: Deliver the runnable check the task requires alongside documented guidance, so a consumer
repo can prove its coverage instead of assuming it.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh`:
  - [ ] **Check A — ignore coverage**: for each ephemeral pattern from the Phase 1 class list,
        confirm the repo actually ignores a representative path. Use `git check-ignore -q` against a
        synthesized path (e.g. `specs/000_probe/.orchestrator-loop-guard`) rather than grepping
        `.gitignore` text — this tests the real behavior, including patterns inherited from any
        source, and is exactly the "demonstrate it matches" bar the task sets.
  - [ ] **Check B — tracked ephemeral files**: scan `git ls-files` for each ephemeral class; for any
        hit, print the exact `git rm --cached` (or `git rm -r --cached`) remediation command and
        note that the file stays on disk.
  - [ ] **Check C — provenance not over-ignored**: confirm `.orchestrator-handoff.json` and
        `.return-meta.json` are NOT ignored (`git check-ignore` must fail for them), and never
        suggest untracking them. A repo that ignores them fails this check with a clear message
        naming the offending `.gitignore` line (`git check-ignore -v` reports it).
  - [ ] Exit non-zero when any check fails; print a compact pass/fail summary. Run correctly from
        the repo root of any consumer repo.
  - [ ] `chmod +x` the script.
- [ ] Register the script in `agent-system/extensions/core/manifest.json` under `provides.scripts`
      (that array enumerates individual filenames; an unregistered script is never deployed).
- [ ] Verify no task-number citations were introduced.

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` - new verification check
- `agent-system/extensions/core/manifest.json` - register the script under `provides.scripts`

**Verification**:
- `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` runs from this repo
  root. Before Phase 6 it is expected to FAIL Check C (this repo still ignores handoff and
  return-meta); that expected failure is itself evidence the check detects the condition. Record
  the output.
- `jq -r '.provides.scripts[]' agent-system/extensions/core/manifest.json | grep -c check-runtime-file-tracking.sh`
  returns 1.
- `test -x agent-system/extensions/core/scripts/check-runtime-file-tracking.sh`.
- `bash -n` on the script passes.
- Task-number citation grep is clean on the script.

---

### Phase 6: Apply the policy to this repository's root .gitignore (the reversal) [NOT STARTED]

**Goal**: Perform the consumer-side application of the decided policy here, un-ignoring the two
durable provenance classes while retaining every ephemeral ignore line.

**Ordering**: This phase is deliberately last among content phases per the Ordering Constraint
section. Do not start it before Phases 2-5 are complete.

**Tasks**:
- [ ] Remove root `/.gitignore` line 1 `**/.return-meta.json`.
- [ ] Remove root `/.gitignore` line 33 `**/.orchestrator-handoff.json`.
- [ ] Leave **every** other line of the ephemeral block intact — currently lines 32, 34-40:
      `**/.lock/`, `**/.orchestrator-loop-guard`, `**/.continuation-loop-guard`,
      `**/.orchestrator-churn-state.json`, `**/.postflight-loop-guard`,
      `**/.orchestrator-multi-state.json`, `**/.return-meta-*.json`, `**/.events.lock`. Note that
      `**/.return-meta-*.json` (suffixed variants) stays even though the bare
      `**/.return-meta.json` is removed — this is the distinction recorded in Phase 1, not an
      oversight.
- [ ] Rewrite the comment block currently at lines 25-31. It presently quotes `handoff-schema.md`'s
      "runtime; not checked in" line, which Phase 4 removes. Replace it with the two-class split and
      the freshness-gate rationale, referencing `orchestrator-runtime-files.md` as the authority.
      No task-number citations.
- [ ] Run `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` and confirm it
      now passes all three checks (contrast with the Phase 5 pre-change output).
- [ ] Run `git status --short | head -50` and confirm the newly visible untracked files are only
      `.return-meta.json` / `.orchestrator-handoff.json` paths under `specs/` — no ephemeral class
      appears. Record the observed count (expected on the order of 299 + 213 = 512).
- [ ] Do **not** create a bulk backfill commit. The policy is forward-only; existing files are
      picked up by whatever natural task-scoped commit next touches their directory.

**Timing**: 45 minutes

**Depends on**: 2, 3, 4, 5

**Files to modify**:
- `/.gitignore` (repo root) - remove the two durable-provenance ignore lines, rewrite the comment block

**Verification**:
- `git check-ignore -q specs/000_probe/.orchestrator-loop-guard` succeeds (still ignored).
- `git check-ignore -q specs/000_probe/.orchestrator-churn-state.json` succeeds.
- `git check-ignore -q specs/000_probe/.lock/holder.json` succeeds.
- `git check-ignore -q specs/000_probe/.orchestrator-handoff.json` **fails** (no longer ignored).
- `git check-ignore -q specs/000_probe/.return-meta.json` **fails** (no longer ignored).
- `git check-ignore -q specs/000_probe/.return-meta-orchestrate.json` succeeds (suffixed variant
  still ignored).
- The check script exits 0.
- `git status --short` shows no ephemeral-class path.

---

### Phase 7: Demonstrate the three required verifications [NOT STARTED]

**Goal**: Produce recorded evidence for each of the task description's three verification
requirements, in a scratch consumer-repo checkout plus this repo where applicable.

**Tasks**:
- [ ] Build a scratch consumer repo under the session scratchpad (never under this repo's tree):
      `git init`, a `specs/NNN_slug/` task directory, and the root `.gitignore` block exactly as
      shipped in `orchestrator-runtime-files.md`'s Consumer Repo Setup section. Using the shipped
      block verbatim is the point — it proves the guidance, not a hand-tuned variant.
- [ ] **(a) Newly created ephemeral file is ignored**: create
      `specs/NNN_slug/.orchestrator-loop-guard` (plus a `.lock/holder.json` and an
      `.orchestrator-churn-state.json`) and confirm `git status --porcelain` does not list them and
      `git check-ignore -v` reports the shipped pattern. Repeat the loop-guard check in this repo.
- [ ] **(b) `git rm --cached` preserves the file on disk**: in the scratch repo, first commit a
      loop guard **without** the ignore block (reproducing the `.dotfiles` starting state), then add
      the block, run the untracking command from the standard, and confirm `git ls-files` no longer
      lists it while `test -f` still succeeds. Also confirm its contents are byte-identical before
      and after.
- [ ] **(c) Post-fix staging is correct**: in the scratch repo, populate a task dir with all five
      classes plus a durable artifact (e.g. `plans/01_x.md`), then execute the exact `git add`
      idiom Phase 2 wrote into `git-staging-scope.md` and `commands/orchestrate.md`. Confirm
      `git diff --cached --name-only` lists the durable artifact, `.orchestrator-handoff.json`, and
      `.return-meta.json`, and lists **none** of `.orchestrator-loop-guard`,
      `.orchestrator-churn-state.json`, `.lock/`. Run this variant with the ignore block **absent**
      as well, to prove the exclusions protect an uncovered repo on their own.
- [ ] Record all command output verbatim in the implementation summary. Do not summarize a check as
      "passed" without its output.
- [ ] Remove the scratch repo when finished.

**Timing**: 1.25 hours

**Depends on**: 6

**Files to modify**:
- None in this repository (scratch checkout under the session scratchpad only)

**Verification**:
- Each of (a), (b), (c) has recorded command output in the summary.
- (c) passes in both configurations: ignore block present, and ignore block absent.
- The scratch directory no longer exists at phase end.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` exits 0 in this repo after Phase 6.
- [ ] `bash -n` passes on the new script.
- [ ] `bash .claude/scripts/check-extension-docs.sh` (doc-lint hard gate) exits 0 — new context/docs files must not break README/manifest cross-reference validation.
- [ ] `jq empty agent-system/extensions/core/manifest.json` succeeds and the new script is listed in `provides.scripts`.
- [ ] `grep -rn 'not checked in' agent-system/extensions/core/` returns no hit referring to handoff or return-meta.
- [ ] No task-number citation patterns in any file touched outside `specs/**`:
      `git diff --name-only HEAD | grep -v '^specs/' | xargs -r grep -nE '\btasks? [0-9]{2,}\b'` returns nothing.
- [ ] No file under `.claude/**` was modified: `git status --porcelain | grep '^.. \.claude/'` returns nothing (`.claude/` is gitignored here, so also confirm by direct inspection that no Write/Edit targeted that tree).
- [ ] All three task-description verification requirements demonstrated with recorded output (Phase 7).

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (new) - canonical two-class policy, rationale, consumer setup, untracking guidance
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` (new) - verification check
- `agent-system/extensions/core/manifest.json` - script registration
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - narrowed staging contract with canonical exclusion set
- `agent-system/extensions/core/commands/orchestrate.md` - exclusion pathspecs at both staging sites
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - loop-guard ephemerality notes
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - loop-guard and churn-state ephemerality notes
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - corrected file-location line and framing
- `agent-system/extensions/core/context/guides/loader-reference.md` - repo-root deploy limitation note
- `/.gitignore` (repo root) - policy applied: two durable classes un-ignored, ephemeral block retained, comment block rewritten
- `specs/907_orchestrator_runtime_file_tracking_policy/summaries/01_runtime-file-tracking-policy-summary.md` - execution summary with Phase 7 evidence

## Rollback/Contingency

- Every phase is a documentation or configuration edit under version control; `git revert` of the
  phase commit restores prior behavior with no data loss.
- **Highest-consequence step is Phase 6.** If un-ignoring produces unexpected `git status` noise
  (any ephemeral-class path appearing), restore the two removed `.gitignore` lines immediately and
  stop before committing — the ephemeral block was never removed, so a re-add of lines 1 and 33
  fully restores the prior state.
- No file is deleted and no history is rewritten at any point. The `git rm --cached` guidance is
  documentation only in this repo (0 runtime files are currently tracked here), and is exercised
  solely inside the disposable scratch repo in Phase 7.
- If the doc-lint gate (`check-extension-docs.sh`) rejects the new script or standard, fix forward
  by satisfying the gate's requirement; do not drop the artifact to make the gate pass.
