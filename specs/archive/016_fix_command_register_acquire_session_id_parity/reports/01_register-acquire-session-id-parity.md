# Research Report: Task #1016

**Task**: 1016 - Fix the register-bare/acquire-suffixed session-id pattern in research.md, plan.md, implement.md
**Started**: 2026-08-10
**Completed**: 2026-08-10
**Effort**: small (verification + a scoped 3-file text fix + test extension)
**Dependencies**: None (skill-orchestrate/SKILL.md's session-id parity fix already landed and is the reference pattern)
**Sources/Inputs**: Codebase (agent-system/extensions/core/{commands,skills,scripts,context}/**)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Confirmed, not merely suspected**: `commands/research.md`, `commands/plan.md`, and
  `commands/implement.md` all three reproduce the exact register-bare/acquire-suffixed defect,
  byte-for-byte identical across all three files. `session-register` is called with the bare
  `$batch_session_id`; the per-task `acquire-retry`/`release` calls in the same file's Step 3 are
  called with `"${batch_session_id}_${task_num}"` — a different string.
- **Mechanically verified against the live code**, not just against `task-lock.md`'s prose: in
  `scripts/task-lock.sh`'s `cmd_acquire()`, the third positional argument (`session_id`) is passed
  directly as `own_sid` into `session_contention()`'s self-exclusion test (`--arg own_sid
  "$session_id"` at line 686). A mismatch between the registered session_id and the acquiring
  session_id means the batch's own session-registry entry is never recognized as "self," so its
  registered union `file_scope` reads as a foreign, live, overlapping session — and `cmd_acquire`
  refuses (`ABORT: ... overlaps registered session ...`, exit 1) for every task in the batch that
  declares a `file_scope`.
- **The three files' own inline prose actively rationalizes the bug as intentional** ("Step 3
  below suffixes the same variable per-task for its own task-lock acquire/release calls; the
  registry entry is batch-scoped, not per-task, so it stays keyed on the unsuffixed value") — this
  sentence is present verbatim in all three files and is the wrong conclusion; it must be corrected
  alongside the code fix, not just the code.
- **Reference fix already exists**: `skill-orchestrate/SKILL.md` Stage MT-4 (line ~1960) calls
  `task-lock.sh acquire "$task_num" "$op" "$session_id"` with the **bare** `$session_id` — the
  same bare id Stage MT-1 registered. The recommended fix for the three command files is the same
  transform: change the acquire-retry/release call sites from
  `"${batch_session_id}_${task_num}"` to `"$batch_session_id"`.
- **A secondary, downstream heartbeat risk applies to `implement.md` only** (research.md and
  plan.md have no per-phase heartbeat checkpoint): `general-implementation-agent.md`'s Stage 4D
  issues *both* `task-lock.sh heartbeat "{task_number}" "{session_id}"` *and* `task-lock.sh
  session-heartbeat "{session_id}"` from the **same** single `{session_id}` context value. Those
  two calls need to match two *different* registries (the per-task lock holder vs. the
  session-registry entry) — which is only simultaneously satisfiable if the same bare
  `batch_session_id` is used everywhere upstream (register, acquire, release, **and** whatever
  `session_id` is threaded into the per-task implementer dispatch context). `implement.md`'s Step
  3 does not literally show what `session_id` value it passes in the per-task skill/agent
  delegation context (unlike `skill-orchestrate`, which shows an explicit `context = {...}` JSON)
  — this is a genuine gap to close in the plan/implementation phase, not something resolvable by
  reading this command file alone.
- **A documentation tension worth flagging, not resolving here**: `task-lock.md`'s own "Cross-Task
  `file_scope` Overlap Check" section states "Multi-task dispatch sessions are suffixed per-task
  ... and are therefore distinct sessions for this purpose — they ARE enforced against each
  other," while the same document's "Register/acquire parity invariant" paragraph (added later,
  describing the just-fixed defect) says the opposite — the batch MUST use one bare, shared
  session_id for every per-task acquire. These are likely reconciled in practice by Step 2.5's
  batch-admission pre-check already handling in-batch collisions before Step 3's acquire loop ever
  runs (so the acquire-time held-lock pass's same-session bypass is a non-issue for in-batch
  pairs), but the document itself does not say so explicitly, and the sentence should probably be
  corrected or caveated when this fix lands.
- **Existing regression coverage is directly extensible**: `scripts/test-conflict-predicate.sh`
  Group 9 already contains a static-guard case (9.5) that is a template for exactly this fix — it
  greps `skill-orchestrate/SKILL.md` for any lock-touching `task-lock.sh` call still carrying
  `${session_id}_${task_num}` and fails if found. The same pattern (adapted for the
  `${batch_session_id}_${task_num}` variable name used in the three command files) should be added
  as sibling cases in the same group, not a new harness.

## Context & Scope

Task 1016 asks to verify whether `commands/research.md`, `commands/plan.md`, and
`commands/implement.md` reproduce a defect that was found and fixed in
`skills/skill-orchestrate/SKILL.md`: the in-flight session registry was registered under a bare
`session_id`, but the per-task lock was acquired/released under a task-suffixed variant of the
same id. Because the session-registry contention self-exclusion check is an exact string match,
the batch never recognized its own registration as "self," and every acquire in the batch was
refused. The work requested is (1) verification per file, (2) a unification fix, and (3)
extending the existing register/acquire parity regression group
(`scripts/test-conflict-predicate.sh` Group 9) to cover these three consumers.

This is a research report only — no code was changed. The SOURCE-STORE RULE binds any actual
fix to `agent-system/extensions/core/**`, never `.claude/**`.

## Findings

### Codebase Patterns

**Exact defect location in each file** (identical shape, three separate files):

| File | `session-register` call (bare) | `acquire-retry` call (suffixed) | `release` call (suffixed) |
|------|-------------------------------|----------------------------------|----------------------------|
| `commands/research.md` | line 165: `session-register "$batch_session_id" ...` | line 234: `acquire-retry "$task_num" research "${batch_session_id}_${task_num}" ...` | line 238: `release "$task_num" "${batch_session_id}_${task_num}"` |
| `commands/plan.md` | line 172: `session-register "$batch_session_id" ...` | line 241: `acquire-retry "$task_num" plan "${batch_session_id}_${task_num}" ...` | line 245: `release "$task_num" "${batch_session_id}_${task_num}"` |
| `commands/implement.md` | line 89: `session-register "$batch_session_id" ...` | line 155: `acquire-retry "$task_num" implement "${batch_session_id}_${task_num}" ...` | line 159: `release "$task_num" "${batch_session_id}_${task_num}"` |

All three files carry the identical inline rationalization prose immediately after their `Step 2:
Generate Batch Session ID` heading (research.md:158-161, plan.md:165-168, implement.md:82-85):

> "Register the in-flight session registry entry for this batch. **Use the bare
> `batch_session_id` here — never a `_${task_num}`-suffixed derivative.** Step 3 below suffixes
> the same variable per-task for its own task-lock acquire/release calls; the registry entry is
> batch-scoped, not per-task, so it stays keyed on the unsuffixed value."

This sentence pre-emptively defends the suffixed acquire/release pattern as a deliberate design
choice. Per the parity invariant in `context/patterns/task-lock.md` ("Register/acquire parity
invariant" paragraph, Consumers item 2) and the mechanical trace below, this reasoning is
incorrect: the suffix breaks the session-registry contention self-exclusion match, which is a
distinct code path from the "acquire holds one lock per task number" property the sentence seems
to be reasoning from.

**Mechanical trace confirming the defect is live, not just documented as a risk** —
`scripts/task-lock.sh`, `cmd_acquire()`:

```
cmd_acquire() {
  local task_number="$1" operation="$2" session_id="$3" command="${4:-}"
  ...
  # --- session-registry contention pass (input 2, session_contention from the shared lib) ---
  sess_hit=$(jq -n -c --argjson cscope "$own_scope" --argjson cnum "$task_number" \
    --arg own_sid "$session_id" --argjson all "$all_json" --argjson sessions "$sessions_json" \
    "$FILE_SCOPE_OVERLAP_JQ_DEFS"'
session_contention($cscope; $cnum; $own_sid; $all; $sessions)' 2>/dev/null) || true
  if [ -n "$sess_hit" ] && [ "$sess_hit" != "null" ]; then
    ...
    echo "ABORT: Task $task_number's file_scope overlaps registered session $sess_session_id's file_scope at \"$sess_overlap_path\" ..." >&2
    return 1
  fi
```

`session_contention()` (in `scripts/lib/file-scope-overlap.sh`) applies D4's three exclusions —
self-session-id, liveness, dependency-edge — with the FIRST being an exact string comparison
between `$own_sid` (the third positional `acquire` argument) and each registered session's
`session_id`. If `acquire` is called with `"${batch_session_id}_${task_num}"` while the registry
holds `"$batch_session_id"`, exclusion 1 never fires; the registered entry's `file_scope` (the
union across the whole batch, per `session-register`'s own contract) is then tested for overlap
against the acquiring task's own `file_scope`. For any batch where the acquiring task's declared
`file_scope` is itself part of that same union — the overwhelmingly common case, since the union
is built from the very tasks being acquired — the overlap test hits, and `cmd_acquire` returns 1
(refused) for every task in the batch.

This precisely reproduces the mechanism task-lock.md's "Register/acquire parity invariant"
paragraph describes as the originally-found defect, and confirms it is live in all three command
files as currently written (not merely theoretically similar).

**Reference fix pattern, already landed, in `skill-orchestrate/SKILL.md`**:

- Stage MT-1 (line 1418): `task-lock.sh session-register "$session_id" ...` — bare.
- Stage MT-4 (line 1960): `task-lock.sh acquire "$task_num" "$op" "$session_id" ...` — **bare**,
  with an explicit inline invariant comment (lines 1963-1966): "the bare `$session_id` is used
  here deliberately — it MUST equal the value Stage MT-1 passed to `session-register` ... A
  per-task-suffixed value (`${session_id}_${task_num}`) would make the batch's own [registration]
  ... contend against itself."
- Immediately below that acquire call, the SAME stage's per-task delegation still uses a
  **suffixed** id for two unrelated purposes: `skill_preflight_update "$task_num" "research"
  "${session_id}_${task_num}"` (line 1989) and the Agent tool's `context.session_id:
  "${session_id}_${task_num}"` (line 1990) — these are per-task bookkeeping identifiers (surfaced
  in `.return-meta.json`, commit trailers, etc.), not lock/registry keys, and are intentionally
  distinct per task. This is the important nuance: the fix is not "never suffix `session_id`
  anywhere," it is "never suffix the specific value passed to `task-lock.sh
  acquire`/`release`/`heartbeat`/`session-register`/`session-heartbeat`" — the lock-and-registry
  family of calls, specifically.

### Per-file verification detail

- **`commands/research.md`**: defect confirmed (Step 2 register bare at line 165; Step 3
  acquire-retry/release suffixed at lines 234 and 238). No per-phase heartbeat checkpoint exists
  in this file's multi-task path (explicitly documented as "No intra-batch session-registry
  heartbeat" at line 242-245) — heartbeat is not a concern here.
- **`commands/plan.md`**: defect confirmed (Step 2 register bare at line 172; Step 3
  acquire-retry/release suffixed at lines 241 and 245). Same "no intra-batch heartbeat" note at
  line 249-252 — heartbeat is not a concern here either.
- **`commands/implement.md`**: defect confirmed (Step 2 register bare at line 89; Step 3
  acquire-retry/release suffixed at lines 155 and 159). This file's own multi-task Step 3 also
  carries the same "No intra-batch session-registry heartbeat" disclaimer (line 161-164) for the
  *command-level* loop — but `implement.md` is the one file of the three whose dispatched skill
  (`skill-implementer` → `general-implementation-agent.md`) has an internal per-*phase*-transition
  heartbeat (Stage 4D), which the command-level disclaimer does not cover and does not need to,
  since that heartbeat lives one layer down in the agent, not in the command file's own loop. This
  is the "downstream dispatch context whose session_id feeds a task-lock heartbeat call" named in
  the task's WORK section. See "Downstream heartbeat risk" below.

### Downstream heartbeat risk (implement.md only)

`agents/general-implementation-agent.md` Stage 4D (lines 271-288) fires, at every phase
transition, two heartbeat calls back to back, both driven by the SAME `{session_id}` value taken
from the agent's own delegation context:

```
bash .claude/scripts/task-lock.sh heartbeat "{task_number}" "{session_id}" 2>/dev/null || true
...
bash .claude/scripts/task-lock.sh session-heartbeat "{session_id}" 2>/dev/null || true
```

These two calls check membership against two *different* records:
- `task-lock.sh heartbeat` succeeds silently only if `{session_id}` matches the CURRENT per-task
  `.lock/holder.json` session_id — i.e., whatever value `acquire` used for that task.
- `task-lock.sh session-heartbeat` succeeds silently only if `{session_id}` matches the
  session-registry entry's `session_id` — i.e., whatever value `session-register` used for the
  whole batch.

A single `{session_id}` value can satisfy both simultaneously only if `acquire` and
`session-register` used the *same* value in the first place — which is exactly the parity
invariant this task is about. `commands/implement.md`'s Step 3 prose does not literally spell out
what `session_id` value is threaded into the per-task `skill-implementer` delegation context for
the multi-task loop (unlike `skill-orchestrate/SKILL.md`, which shows an explicit `context =
{...}` JSON object per dispatch) — this is implicit in the current file and needs to be made
explicit as part of the fix: whatever value is passed as that context's `session_id` should be
the SAME bare `batch_session_id` used for `acquire`/`release` (per the corrected pattern below),
so that Stage 4D's two heartbeat calls both land on a live, matching record rather than
degrading silently to a no-op warning for one or both of them. Note this is non-blocking either
way (`heartbeat`'s contract is "no-op with a warning," never a hard failure) — it is a
correctness/observability gap, not a new outage class, but it is squarely in scope of "unify the
session-id used across register/acquire/release/heartbeat" as the task instructs.

### External Resources

Not applicable — this is a self-contained codebase concurrency-primitive defect; no external
documentation is relevant.

### Recommendations

1. **In each of `commands/research.md`, `commands/plan.md`, `commands/implement.md`**: change the
   `acquire-retry` and `release` call sites in Step 3 (and Step 3.5's identical second-pass
   bracket in research.md/plan.md/implement.md, which reuses the same per-task acquire/release
   shape) from `"${batch_session_id}_${task_num}"` to the bare `"$batch_session_id"`, mirroring
   `skill-orchestrate/SKILL.md` Stage MT-4's already-fixed pattern exactly.
2. **Correct the inline rationalization prose** in the "Step 2: Generate Batch Session ID"
   section of all three files — the sentence claiming Step 3 "suffixes the same variable per-task"
   is describing the bug, not a deliberate design choice, and must be rewritten to state that
   Step 3 uses the SAME bare `batch_session_id` for every task's acquire/release, matching
   `session-register`. Consider porting `skill-orchestrate/SKILL.md`'s explicit inline invariant
   comment (lines 1963-1966) verbatim or near-verbatim, since it already states the correct
   reasoning and the failure mode it prevents.
3. **For `implement.md` specifically**: make explicit what `session_id` value is passed as the
   per-task delegation context to `skill-implementer` in the multi-task Step 3 loop, and set it to
   the same bare `batch_session_id` (not a per-task-suffixed variant), so that
   `general-implementation-agent.md`'s Stage 4D heartbeat pair (task-lock heartbeat +
   session-registry heartbeat) both resolve against live, matching records. If there is a genuine,
   separate need for a per-task-unique identifier downstream (e.g., for `.return-meta.json`'s own
   `session_id` field or a commit trailer), that identifier should be a DIFFERENT field/variable
   from the one threaded into the two `task-lock.sh` heartbeat calls — do not conflate the two the
   way the current single-`{session_id}`-context design invites.
4. **Flag, but do not necessarily resolve in this task**, the tension between `task-lock.md`'s
   "Cross-Task `file_scope` Overlap Check" section's "Multi-task dispatch sessions are suffixed
   per-task ... they ARE enforced against each other" sentence and the "Register/acquire parity
   invariant" paragraph's opposite instruction. The most likely reconciliation is that in-batch
   collisions are already excluded by Step 2.5's `orchestrate-batch-admit.sh` pre-check before
   Step 3's acquire loop runs, making the acquire-time held-lock pass's same-session bypass a
   non-issue for same-batch task pairs — but the document does not say this explicitly today, and
   a maintainer reading only the "Cross-Task" section (without also reading the later parity
   invariant) would draw the wrong conclusion, exactly as the three command files' own prose
   currently does. Recommend a cross-reference or explicit caveat be added to whichever
   `task-lock.md` section is edited as part of landing this fix, so the two sections stop reading
   as contradictory.
5. **Test extension** (per the task's explicit instruction not to add a parallel harness):
   `scripts/test-conflict-predicate.sh` Group 9 (lines 384-458) already has the right shape.
   Case 9.5 is a static guard scoped to `skill-orchestrate/SKILL.md` alone — grep for any
   lock-touching `task-lock.sh` call (`acquire|release|heartbeat`) that still carries the literal
   substring `${session_id}_${task_num}`, fail if found, info-and-skip if the file isn't
   reachable. The natural extension is 2-3 sibling cases (e.g., 9.6/9.7/9.8, one per command file)
   using the identical grep-and-skip shape, adjusted for:
   - the file path (`$SCRIPT_DIR/../commands/research.md`, `.../plan.md`, `.../implement.md`)
   - the bad-pattern substring (`${batch_session_id}_${task_num}` instead of
     `${session_id}_${task_num}`, since the three command files use a differently-named shell
     variable than `skill-orchestrate/SKILL.md` does)
   The existing dynamic cases (9.1-9.4), which drive the real `task-lock.sh` CLI end to end against
   the 820/850 fixture pair, do not need new fixtures for this fix — they already prove the
   underlying `cmd_acquire`/`session_contention()` behavior generically (independent of which
   caller constructs the session_id string), so the three new cases only need to be static
   grep-based guards against the command files' literal text, exactly like 9.5. This keeps the
   fix inside the existing regression group rather than adding a parallel harness, per the task's
   instruction.

## Decisions

- Scope confirmed as literal-text fixes to three files (`commands/research.md`,
  `commands/plan.md`, `commands/implement.md`) plus the implicit-context gap noted in
  `implement.md`'s per-task delegation, plus a documentation-prose correction in the same three
  files, plus a test-group extension — no new script, no new mutex, no change to
  `scripts/task-lock.sh` itself (which is already correct; the bug is entirely in the three
  callers' argument construction).
- The `task-lock.md` cross-section tension (finding 4 above) is surfaced as a flag for the
  planning phase to decide whether to address in the same task or defer, not resolved here.

## Risks & Mitigations

- **Risk**: naively changing every `${batch_session_id}_${task_num}` occurrence in these files to
  bare `$batch_session_id` without checking each call site's actual purpose could accidentally
  touch a call site that is NOT part of the lock/registry family (e.g., a `.return-meta.json`
  provenance field or a log line) and does not need to change. Mitigation: the audit above lists
  every exact line number and confirms all suffixed occurrences found in these three files are, in
  fact, `acquire-retry`/`release` calls — no other suffixed-session_id call sites were found by
  the `session_id\|session-register\|...` grep sweep across the three files (see Appendix).
- **Risk**: the `implement.md` downstream-context gap (finding/recommendation 3) is not a literal
  string in the command file today, so "fixing" it requires the planning/implementation phase to
  first locate where the per-task `session_id` is actually threaded into the `skill-implementer`
  delegation (likely inside `skill-implementer/SKILL.md`'s own preflight, or an implicit
  convention the Skill tool call inherits) before it can be changed. Mitigation: flagged explicitly
  as a distinct, scoped follow-up rather than folded silently into the three-file text fix, so it
  isn't missed or conflated with the simpler literal-substitution fix.
- **Risk**: the test extension could be written as three entirely new, hand-rolled test blocks
  instead of true siblings of 9.5, drifting from its shape over time. Mitigation: recommendation 5
  above is explicit that the new cases should reuse 9.5's exact grep-and-skip shape line for line,
  varying only the file path and the bad-pattern substring.

## Context Extension Recommendations

- **Topic**: `task-lock.md`'s "Cross-Task `file_scope` Overlap Check" section vs. its "Register/
  acquire parity invariant" paragraph.
- **Gap**: the two sections give apparently opposite guidance about whether multi-task dispatch
  sessions should share one bare session_id or use per-task-suffixed variants, without
  cross-referencing each other or explaining why both can be true (in-batch collisions are
  resolved earlier, at the batch-admission pre-check stage, before the acquire-time held-lock pass
  ever sees them).
- **Recommendation**: when this task's fix lands, add a one- or two-sentence cross-reference in
  the "Cross-Task `file_scope` Overlap Check" section pointing to the "Register/acquire parity
  invariant" paragraph (or vice versa), explaining that the same-session bypass there is a
  non-issue for same-batch task pairs specifically because `orchestrate-batch-admit.sh`'s Step 2.5
  pre-check already excludes in-batch collisions before Step 3's acquire loop runs.

## Appendix

### Search queries / commands used

```
grep -n "session_id\|session-register\|session-heartbeat\|session-release\|task-lock.sh\|batch_session_id" \
  commands/research.md commands/plan.md commands/implement.md

grep -n "heartbeat" commands/research.md commands/plan.md commands/implement.md

grep -n "session_contention\|cmd_acquire()\|SESSION_ID" scripts/task-lock.sh

grep -n "heartbeat\|session_id" agents/general-implementation-agent.md
```

### References

- `agent-system/extensions/core/commands/research.md` (lines 152-245: Step 2/2.5/3)
- `agent-system/extensions/core/commands/plan.md` (lines 159-252: Step 2/2.5/3)
- `agent-system/extensions/core/commands/implement.md` (lines 76-165: Step 2/2.5/3)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (lines 1418, 1960-1997: the
  reference fix pattern)
- `agent-system/extensions/core/scripts/task-lock.sh` (lines 614-701: `cmd_acquire()`, the
  session-registry contention pass)
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` (`session_contention()`, D4's
  three exclusions)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (lines 271-288: Stage 4D
  dual heartbeat)
- `agent-system/extensions/core/context/patterns/task-lock.md` ("Register/acquire parity
  invariant" paragraph in Consumers item 2; "Cross-Task `file_scope` Overlap Check" section's
  same-session-bypass sentence; Consumers item 5's per-file wiring list)
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` (lines 384-458: Group 9,
  the existing register/acquire parity regression coverage, case 9.5 as the extension template)
