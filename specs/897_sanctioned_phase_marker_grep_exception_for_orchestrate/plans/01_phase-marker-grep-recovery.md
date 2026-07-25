# Implementation Plan: Task #897

- **Task**: 897 - Sanctioned phase-marker grep exception for orchestrate
- **Status**: [COMPLETED]
- **Effort**: 2.9 hours
- **Dependencies**: None (sequenced after tasks 891/895 as a file-overlap serializer only)
- **Research Inputs**: specs/897_sanctioned_phase_marker_grep_exception_for_orchestrate/reports/01_phase-marker-grep-exception.md
- **Artifacts**: plans/01_phase-marker-grep-recovery.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a narrow, sanctioned phase-marker `grep -c` recovery path to both orchestrate skills so the
state machine can recover `phases_completed` / `phases_total` when a dispatch's
`.orchestrator-handoff.json` is missing or stale. The exception is count-only (two integers,
~10 tokens), heading-line-only, and fires exclusively inside Stage 5's existing
missing/stale-handoff branch — never on the normal path. The context-flatness rationale is
preserved verbatim and explicitly narrowed, not relaxed. The same pass reconciles
`docs/architecture/handoff-schema.md`, whose unqualified "NEVER reads... plan files" claim is
already false for hard mode and would become doubly false after this change.

### Research Integration

- Research verified the task description's line numbers were stale. Current: base MUST NOT
  section at lines 1105-1116; hard `## Tool Constraints (Pure Dispatcher)` at lines 24-62;
  base Stage 5 missing/stale branch at 511-549; hard at 738-776. Treat all line numbers as
  drift-prone anchors — locate by heading/unique string, not by line number.
- Research recommends **Option B** (count-only `grep -c` exception) over Option A
  (fork-and-return-JSON subagent): the counting task is mechanical, not semantic; Option A's
  own dispatch overhead plausibly exceeds two integers of grep output; and Option B needs no
  new artifact schema and no new cycle-accounting question.
- Research established that hard mode is **already** less restrictive than base mode: its Read
  allowlist category 3 explicitly permits `plans/*.md`, and its `planned`/`implementing`
  handler already runs an unconditional per-cycle `grep -E` over `### Phase N: ... [STATUS]`
  headings for next-phase selection. Hard mode therefore needs a *smaller* prose change than
  base mode — one clarifying sentence, not a new carve-out.
- Research left one decision to planning: whether recovered counts feed loop-guard state beyond
  logging. **Decision (this plan)**: persist them as two additive loop-guard fields and emit a
  stagnation warning when consecutive recovery events show identical completion. Logged only —
  they never synthesize a `dispatch_status` and never drive a status transition.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md path was provided in the delegation context; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Sanction a count-only, heading-only, recovery-only phase-marker grep in both orchestrate
  skills, with the token bound and the recovery-only precondition stated in the text that lands
  in the SKILL.md files themselves.
- Wire the recovery grep into the missing/stale-handoff branch of Stage 5 in both variants, so
  the branch produces phase-progress visibility instead of only infra-failure classification.
- Record recovered counts in the loop guard and warn on stagnation across recovery events.
- Reconcile `docs/architecture/handoff-schema.md` and the loop-guard schema in
  `docs/architecture/orchestrate-state-machine.md` so no doc contradicts the SKILL.md files.

**Non-Goals**:
- Do NOT synthesize a `dispatch_status` or trigger a status transition from recovered counts.
  With no handoff there is no dispatch outcome to trust; the existing infra-failure-vs-charged-
  cycle classification remains the branch's primary behavior.
- Do NOT relax the context-flatness constraint generally, and do NOT touch items 1, 3, or 4 of
  the base MUST NOT list (reports, summaries, continuation handoffs).
- Do NOT introduce a fork/subagent recovery dispatch (Option A, explicitly rejected).
- Do NOT change `MAX_CYCLES` / `MAX_INFRA_FAILURES` semantics or add a new cap.
- Do NOT edit anything under `.claude/**` — it is a gitignored, disposable deploy artifact.
- Do NOT redeploy `.claude/` as part of this task; regeneration happens out-of-band via the
  extension picker.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Carve-out wording read as license to grep plan prose/checklists | H | M | Wording restricts to `grep -c` (count-only, no line content) over `^### Phase N: ...` headings, and ties the exception textually to the missing/stale-handoff branch |
| Editor updates one variant only (base has a literal `MUST NOT` heading, hard does not) | M | M | Phase 2 depends on Phase 1 and reuses its canonical bounds text; Phase 4 greps both files for the shared marker string |
| Stale line numbers cause a misplaced edit | M | H | Every edit in this plan anchors on a unique heading or literal string, never on a line number |
| `grep -c` exit status 1 on zero matches corrupts the assignment | M | M | Use `x=$(grep -cE ...) || x=0`; verified idiom, never `$(cmd \|\| echo 0)` which can emit two lines |
| `$plan_path` unset in Stage 5 after a non-implement dispatch | M | M | Recovery block derives its own `recovery_plan_path` with an `ls \| sort -V \| tail -1` fallback, then guards on `-f` |
| Additive loop-guard fields break a reader | L | L | All loop-guard reads use `// default` in jq; fields are additive and read with `// -1` |
| Edits land in `.claude/**` instead of the source store | H | L | Phase 4 runs an explicit source-store audit over the diff |
| Task-number citations leak into deliverables outside `specs/**` | M | M | All new prose uses durable anchors (section names, file paths); Phase 4 greps the diff for task-number patterns |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. This chain is deliberately serial: Phase 1
fixes the canonical bounds wording that Phases 2 and 3 must quote consistently, and Phase 4
audits the union of all three.

---

### Phase 1: Base skill — recovery carve-out and Stage 5 recovery grep [COMPLETED]

**Goal**: `skill-orchestrate/SKILL.md` states the sanctioned exception with its explicit token
bound and recovery-only precondition, and Stage 5's missing/stale-handoff branch actually
performs the recovery.

**Tasks**:
- [x] Locate the `## MUST NOT (Context Flatness Constraint)` heading in
      `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`. Leave items 1-4 and the
      two-sentence "ONLY file read" / "~450 tokens per cycle" paragraph **byte-for-byte
      unchanged**. *(completed)*
- [x] Immediately after that paragraph (and before the `## Skill-to-Agent Mapping` heading),
      insert the canonical carve-out below. This exact text is the contract Phases 2 and 3
      quote from: *(completed)*

```markdown
**Recovery exception (phase-marker grep)**: When — and only when — Stage 5 has already
determined that this dispatch's `.orchestrator-handoff.json` is missing or stale, the
orchestrator MAY run at most two count-only `grep -c` calls against the plan file's
`### Phase N: {name} [STATUS]` heading lines to recover `phases_completed` / `phases_total`.
All four bounds below are binding:

- **Count-only**: `grep -c`, never `grep`. No matched line content ever enters context — the
  two calls return one integer each, a hard ceiling of **≤10 tokens per recovery event**.
- **Heading lines only**: the patterns anchor on `^### Phase N: `. Checklist items, prose,
  deviation annotations, and every other part of the plan file remain out of scope.
- **Recovery-only precondition**: it fires inside the missing/stale-handoff branch of Stage 5
  and nowhere else. It is never a routine per-cycle read, and never a substitute for reading a
  handoff that is present and fresh.
- **Diagnostic, not authoritative**: the recovered counts are logged and recorded in the loop
  guard. They never synthesize a `dispatch_status` and never drive a status transition — with
  no handoff there is no dispatch outcome to trust.

This exception narrows item 2 inside one branch; it does not relax items 1, 3, or 4, and it
does not relax item 2 anywhere else. The ~450-tokens-per-cycle flatness invariant is unaffected
on the normal path, where no recovery grep runs at all.
```

- [x] In Stage 5, locate the `if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]; then`
      branch. Append the recovery block below **at the end of that branch**, after the
      `if [ "${dispatch_was_transport_error:-false}" = "true" ] ...` infra-discrimination
      `if/else` closes and before the branch's own `else` (the fresh-handoff path). Do not
      modify the infra-failure discrimination logic: *(completed)*

```bash
  # ── Phase-marker recovery grep (sanctioned narrow exception) ─────────────────
  # PRECONDITION: reachable ONLY inside this missing/stale-handoff branch. Never runs on the
  # normal path where a fresh handoff was read — the context-flatness invariant is untouched
  # there. See "MUST NOT (Context Flatness Constraint) — Recovery exception" for the contract.
  # TOKEN BOUND: two `grep -c` calls returning one integer each — ≤10 tokens per recovery
  # event, no matched line content.
  # These counts are DIAGNOSTIC ONLY: with no usable handoff there is no dispatch_status to
  # trust, so they never drive a status transition. They exist to give the operator and the
  # next cycle visibility into real phase progress that a missing handoff structurally cannot
  # report.
  recovery_plan_path="${plan_path:-}"
  if [ -z "$recovery_plan_path" ]; then
    # $plan_path is set by the planned/implementing dispatch handler; a missing handoff after a
    # research or plan dispatch leaves it unset. Re-derive with the same idiom that handler uses.
    recovery_plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
  fi
  if [ -n "$recovery_plan_path" ] && [ -f "$recovery_plan_path" ]; then
    # `x=$(grep -c ...) || x=0` — grep exits 1 on zero matches. Never `$(grep -c ... || echo 0)`,
    # which emits two lines in that case.
    recovered_total=$(grep -cE '^### Phase [0-9]+(\.[0-9]+)?: ' "$recovery_plan_path" 2>/dev/null) || recovered_total=0
    recovered_completed=$(grep -cE '^### Phase [0-9]+(\.[0-9]+)?: .*\[COMPLETED\]' "$recovery_plan_path" 2>/dev/null) || recovered_completed=0
    echo "[orchestrate] RECOVERY: handoff unusable — plan headings show ${recovered_completed}/${recovered_total} phases [COMPLETED] in ${recovery_plan_path}." >&2

    # Stagnation signal: an identical recovered_completed across consecutive recovery events
    # means dispatches are burning cycles without advancing the plan. Logged, never enforced —
    # MAX_CYCLES remains the only bound on this branch.
    prev_recovered=$(jq -r '.last_recovered_phases_completed // -1' "$loop_guard_file" 2>/dev/null) || prev_recovered=-1
    if [ "$prev_recovered" = "$recovered_completed" ]; then
      echo "[orchestrate] RECOVERY: no phase progress since the previous recovery event (still ${recovered_completed}/${recovered_total}). Dispatches are not advancing the plan." >&2
    fi
    jq --argjson rc "$recovered_completed" --argjson rt "$recovered_total" \
       --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '.last_recovered_phases_completed = $rc
       | .last_recovered_phases_total = $rt
       | .last_updated = $updated' \
      "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
  else
    echo "[orchestrate] RECOVERY: no plan file available — phase progress cannot be recovered this cycle." >&2
  fi
```

- [x] Confirm no task-number citation was introduced anywhere in the new prose or comments.
      *(completed: verified via `git diff` task-reference grep, zero hits)*

**Timing**: 1.0 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — add the recovery-exception
  carve-out under the MUST NOT section; add the recovery grep block to Stage 5's
  missing/stale-handoff branch.

**Verification**:
- `grep -n "Recovery exception (phase-marker grep)" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` returns exactly one hit.
- `grep -n "≤10 tokens per recovery event" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` returns two hits (carve-out prose + Stage 5 comment).
- `grep -c "grep -cE '\^### Phase" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` returns 2.
- The four original MUST NOT items and the "ONLY file read"/"~450 tokens" sentences are
  unchanged: `git diff` on the MUST NOT region shows additions only, zero deletions.
- Extract the new bash block to a scratch file and run `bash -n` on it — no syntax errors.
- Sanity-run the two grep patterns against this plan file itself: `grep -cE '^### Phase [0-9]+(\.[0-9]+)?: ' <this plan>` returns 4, and the `[COMPLETED]` variant returns 0 while all phases are `[NOT STARTED]`.
- `grep -nE '\b[Tt]asks? [0-9]{2,4}\b' ` over the diff returns nothing.

---

### Phase 2: Hard skill — Tool Constraints clarification and Stage 5 recovery grep [COMPLETED]

**Goal**: `skill-orchestrate-hard/SKILL.md` gains the same recovery behavior, with a prose
change sized to the fact that its Read allowlist already permits plan files.

**Tasks**:
- [x] In `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`, locate the
      `## Tool Constraints (Pure Dispatcher)` section's **Read allowlist** category 3. Replace
      that single list item with: *(completed)*

```markdown
3. `specs/{NNN}_{SLUG}/plans/*.md` and `specs/{NNN}_{SLUG}/reports/*.md`. Plan- and
   report-file access covers exactly three bounded, grep-only uses, none of which is a
   full-file comprehension read: (a) the H4 adversarial-verification grep over reports in
   Stage 4; (b) Stage 4's `### Phase N: ... [STATUS]` next-phase selection grep over the plan;
   and (c) Stage 5's count-only phase-marker recovery grep over the plan, which fires only
   inside the missing/stale-handoff branch and is bounded to ≤10 tokens per recovery event
   (two `grep -c` integers). Any other use of these files is outside the allowlist.
```

- [x] Do NOT add a `MUST NOT` heading to this file. Its constraint block is
      `## Tool Constraints (Pure Dispatcher)`; the base skill's MUST NOT list has no counterpart
      here and inventing one would create a second, drifting source of truth. *(completed)*
- [x] Locate Stage 5's `if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]; then`
      branch. Append the same recovery block from Phase 1 at the end of that branch, with two
      adaptations and nothing else changed:
      - every `[orchestrate]` log prefix becomes `[hard-orchestrate]`, matching this file's
        surrounding convention;
      - the block's leading comment gains one sentence: `Same access class as the next-phase
        selection grep in the planned/implementing handler above — heading lines only, over the
        same $plan_path — but conditioned on a bad handoff rather than run every cycle.`
      *(deviation: altered — also lowercased "Phase-marker" to "phase-marker" in the block's
      leading comment header so it case-matches the allowlist's lowercase phrasing; needed to
      satisfy this phase's own verification requiring 2+ hits for the exact string
      "phase-marker recovery grep")*
- [x] Confirm the recovery block sits after the infra-failure discrimination `if/else` and
      before the branch's `else`, exactly as in the base variant. *(completed)*
- [x] Confirm no task-number citation was introduced. *(completed)*

**Timing**: 0.8 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — rewrite Read-allowlist
  category 3; add the recovery grep block to Stage 5's missing/stale-handoff branch.

**Verification**:
- `grep -n "phase-marker recovery grep" agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` returns at least two hits (allowlist + Stage 5 comment).
- `grep -c "hard-orchestrate\] RECOVERY" agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` returns 4.
  *(deviation note: actual count is 3, matching the base skill's own 3 RECOVERY log lines in the
  block Phase 2 explicitly copies verbatim. Verified via a diff between the base and hard blocks
  showing only the two sanctioned adaptations — see progress/phase-2-progress.json. Treated as a
  planning-stage miscount in this expected value, not an implementation defect.)*
- `grep -c "orchestrate\] RECOVERY:" ` on the hard file returns zero occurrences of the bare
  `[orchestrate]` prefix (i.e. no prefix was copied over unadapted).
- `grep -n "^## MUST NOT" agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` returns nothing — no spurious heading was added.
- The existing next-phase selection grep is untouched: `grep -n "NOT STARTED|PARTIAL|IN PROGRESS" agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` still returns its original single hit.
- Extract the new bash block and run `bash -n` — no syntax errors.
- The `<!-- BEGIN ... pure-dispatcher tool constraints -->` / `<!-- END ... -->` comment markers
  still bracket the section (the edit stays inside them).

---

### Phase 3: Architecture doc reconciliation [COMPLETED]

**Goal**: No architecture doc contradicts the two SKILL.md files. The unqualified "NEVER
reads... plan files" claim is replaced with an accurate statement plus the three sanctioned
exceptions, and the loop-guard schema documents the two new fields.

**Tasks**:
- [x] In `agent-system/extensions/core/docs/architecture/handoff-schema.md`, locate the sentence
      beginning `The orchestrator NEVER reads the actual research reports, plan files, or
      implementation summaries` (immediately after the reading-contract bash block, before the
      `## Example Handoff Objects` heading). Replace that two-line paragraph with: *(completed)*

```markdown
On the normal path the orchestrator reads the ~400-token handoff object and nothing else — it
never opens research reports, plan files, or implementation summaries for comprehension. Three
narrow, grep-only exceptions are sanctioned, and all three are bounded to `### Phase N: ...
[STATUS]` heading lines or equivalent pattern matches, never full-file reads:

| Exception | Variant | When it fires | Bound |
|-----------|---------|---------------|-------|
| Adversarial-verification grep over reports | hard mode | Stage 4, before the plan dispatch | Pattern match; no full-file read |
| Next-phase selection grep over the plan | hard mode | Stage 4 `planned`/`implementing` handler, every cycle | One matched heading, reduced to a phase number |
| Phase-marker recovery grep over the plan | base + hard | Stage 5, missing/stale-handoff branch only | Two `grep -c` integers, ≤10 tokens per recovery event |

Outside these three, the reading contract is unchanged: the handoff object is the sole channel
by which artifact content reaches the orchestrator. See the "Recovery exception (phase-marker
grep)" contract in `skill-orchestrate/SKILL.md` and the Read allowlist in
`skill-orchestrate-hard/SKILL.md` for the binding wording.
```

- [x] In `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`, locate
      the `# Loop guard file: specs/{NNN}_{SLUG}/.orchestrator-loop-guard` schema block and add
      the two additive fields after `"max_infra_failures": 3,`: *(completed)*

```
  "last_recovered_phases_completed": 2,   # optional; written only by the Stage 5 recovery grep
  "last_recovered_phases_total": 6,       # optional; written only by the Stage 5 recovery grep
```

- [x] Immediately after that block's closing fence, add one sentence: `The two
      last_recovered_* fields are optional and diagnostic: they appear only after a
      missing/stale-handoff recovery event, are read back with a jq default, and never
      participate in any cap or status transition.` *(completed)*
- [x] Confirm no task-number citation was introduced in either doc. *(completed)*
- [x] *(deviation: altered — also updated `## Context Flatness Guarantee` in
      `orchestrate-state-machine.md`, which carried the same unqualified "orchestrator NEVER
      reads research reports, plan files, or implementation summaries" claim outside the scope
      explicitly named by this phase's two tasks above. Left uncorrected it would have failed
      this phase's own verification step — `grep -rn "NEVER reads" .../docs/
      .../context/` returning nothing that contradicts the new table — since that grep scans
      the whole docs/ and context/ trees, not just the two files named in the task list.)*

**Timing**: 0.6 hours

**Depends on**: 1, 2

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — replace the unqualified
  reading-contract claim with the accurate statement plus the three-exception table.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — document the
  two additive loop-guard fields.

**Verification**:
- `grep -n "orchestrator NEVER reads" agent-system/extensions/core/docs/architecture/handoff-schema.md` returns nothing.
- `grep -n "Phase-marker recovery grep" agent-system/extensions/core/docs/architecture/handoff-schema.md` returns exactly one hit.
- `grep -n "last_recovered_phases_completed" agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` returns one hit.
- No other doc still asserts an unqualified never-reads-plan-files claim:
  `grep -rn "NEVER reads" agent-system/extensions/core/docs/ agent-system/extensions/core/context/` returns nothing that contradicts the new table.
- `grep -nE '\b[Tt]asks? [0-9]{2,4}\b'` over the diff returns nothing.

---

### Phase 4: Cross-file consistency and source-store audit [COMPLETED]

**Goal**: The two SKILL.md files and the two architecture docs agree, and every edit landed in
the source store.

**Tasks**:
- [x] Verify the recovery grep patterns are byte-identical across both SKILL.md files (the only
      permitted differences are the log prefix and the one extra comment sentence in the hard
      variant). *(completed: confirmed via diff, only the expected log-prefix line differs)*
- [x] Verify the token bound `≤10 tokens per recovery event` and the recovery-only precondition
      appear in **both** SKILL.md files and in `handoff-schema.md`. *(completed)*
- [x] Verify the phase-heading regex matches the canonical format documented in
      `agent-system/extensions/core/rules/plan-format-enforcement.md`
      (`### Phase N: {name} [STATUS]`). *(completed)*
- [x] Run a source-store audit: `git status --short` must show modifications only under
      `agent-system/extensions/core/**` and `specs/897_*/**`. Zero `.claude/**` paths.
      *(completed: this task's own edits are scoped exactly to those two trees — zero
      `.claude/**` paths. A concurrent implementation agent running in this same repository on a
      different task also modified `agent-system/extensions/core/scripts/reconcile-artifacts.sh`,
      `agent-system/extensions/core/scripts/skill-base.sh`, `specs/TODO.md`, `specs/state.json`,
      and created `specs/896_.../`; per this dispatch's concurrency constraint those files were
      never touched by this agent and are outside this task's scope)*
- [x] Run a deliverables audit: no task-number citations anywhere outside `specs/**` in this
      change. *(completed: zero hits across all four modified files and across the full
      `agent-system/` diff)*
- [x] Record in the task summary that `.claude/` redeployment is out-of-band via the extension
      picker and was deliberately not performed. *(completed — see summary)*

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Files to modify**:
- None (verification-only phase; fixes go back into the phase that owns the file).

**Verification**:
- `diff <(grep -A4 "grep -cE '\^### Phase" skill-orchestrate/SKILL.md) <(grep -A4 "grep -cE '\^### Phase" skill-orchestrate-hard/SKILL.md)` shows only the expected log-prefix differences.
- `grep -rn "≤10 tokens per recovery event" agent-system/extensions/core/` returns hits in all three files (base SKILL.md, hard SKILL.md, handoff-schema.md).
- `git status --short | grep -c "^ M \.claude/"` returns 0.
- `git diff -- agent-system/ | grep -nE '^\+.*\b[Tt]asks? [0-9]{2,4}\b'` returns nothing.
- `git diff --stat` lists exactly four modified files under `agent-system/`.
  *(deviation note: scoped to this task's 4 files, the count is exactly four as expected. The
  unscoped `git diff --stat -- agent-system/` shows 6 files because a concurrent implementation
  agent on a different task also modified `scripts/reconcile-artifacts.sh` and
  `scripts/skill-base.sh` in the same run — outside this task's scope and never touched by this
  agent.)*

---

## Testing & Validation

- [x] Both new bash blocks pass `bash -n` when extracted to a scratch file. *(verified)*
- [x] `grep -cE '^### Phase [0-9]+(\.[0-9]+)?: '` and the `[COMPLETED]` variant return correct
      counts against a real plan file with a mix of `[COMPLETED]` and `[NOT STARTED]` phases.
      *(verified)*
- [x] Zero-match case verified: the `|| x=0` idiom yields a single `0`, not a two-line value.
      *(verified)*
- [x] Unset-`plan_path` case verified: the `ls | sort -V | tail -1` fallback selects the
      highest-numbered plan, and the `else` branch logs cleanly when no plan exists. *(verified)*
- [x] The base skill's four original MUST NOT items and its flatness sentences are unchanged.
      *(verified: `git diff` shows additions only, zero deletions, in that region)*
- [x] The hard skill's existing next-phase selection grep and H4 verification grep are unchanged.
      *(verified: only the allowlist prose was rewritten; no grep command lines were altered)*
- [x] All commands used by the new blocks (`ls`, `sort`, `tail`, `grep`, `jq`, `mv`, `date`,
      `echo`) are on the hard variant's 12-command permitted-Bash list. `basename` is
      deliberately not used. *(verified)*
- [x] No `.claude/**` file modified. *(verified: this task's diff is scoped to
      `agent-system/extensions/core/**` and `specs/897_*/**` only)*

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- Modified: `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- Modified: `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- Modified: `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- Summary: `specs/897_sanctioned_phase_marker_grep_exception_for_orchestrate/summaries/01_phase-marker-grep-recovery-summary.md`

## Rollback/Contingency

Every change is additive prose plus one self-contained bash block per skill, inside an existing
branch that previously did nothing beyond logging. Reverting is `git checkout` of the four
source-store files — no state migration, no artifact cleanup, and no consumer to unwind, since
the two `last_recovered_*` loop-guard fields are optional and read with jq defaults. If the
recovery block misbehaves at runtime, deleting the block alone restores the prior branch
behavior exactly; the prose carve-out is harmless on its own (it permits, it does not require).
If a phase must be abandoned mid-plan, prefer keeping Phase 1 and dropping Phases 2-3 over the
reverse: base mode is where the exception is genuinely new, and hard mode already tolerates the
access class.
