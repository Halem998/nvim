# Wrap-Up and Handoff Contract (H9)

This contract implements H9: Handoff and Commit Discipline. Every hard-mode implementation
dispatch ends with a complete handoff artifact and a set of green-build incremental commits.
The orchestrator relies on handoff JSON to drive the next dispatch cycle; incomplete handoffs
break the pipeline.

**`--hard`-only**: This entire contract is loaded exclusively by hard-mode dispatch paths
(`skill-implementer-hard`, `general-implementation-hard-agent`, `skill-orchestrate-hard`);
STANDARD mode never loads this file.

## Orchestrator Handoff JSON Schema

Every hard-mode implementation dispatch MUST write the orchestrator handoff before
terminating. Maximum 400 tokens.

### Write location — absolute path, never a bare filename

Write to the ABSOLUTE path supplied in your delegation context as `handoff_path`. If
`handoff_path` is absent, use `{task_dir}/.orchestrator-handoff.json` with the absolute
`task_dir` from your delegation context. If BOTH are absent, STOP and report the missing
anchor in your final message — do not guess.

A bare `.orchestrator-handoff.json` filename resolves against whatever the ambient working
directory happens to be when the Write tool runs. The file then lands outside the task
directory, and the orchestrator either sees no handoff or reads the PREVIOUS cycle's leftover
and reports its status as this dispatch's result. That silent wrong-answer failure is worse
than a missing handoff.

A `PostToolUse` hook (`hooks/validate-handoff-location.sh`) rejects Write/Edit calls whose
destination is not `specs/{NNN}_{SLUG}/.orchestrator-handoff.json`. Treat that rejection as a
hard error: delete the stray file, then rewrite at the correct absolute path.

The machine-checkable authority for this shape is
`context/schemas/orchestrator-handoff-schema.json`; this section is the H9 prose contract and
must stay consistent with it.

Required fields:

```json
{
  "status": "implemented | partial | blocked",
  "summary": "One to two sentence summary of what this dispatch accomplished.",
  "artifacts": [
    {"type": "summary", "path": "specs/{NNN}_{SLUG}/summaries/{NN}_{slug}-summary.md", "summary": "One-line description"}
  ],
  "skeleton": false,
  "phases_completed": 2,
  "phases_total": 5,
  "dispatch_seq": 4,
  "sorry_inventory": [],
  "blockers": [
    {
      "phase": 3,
      "target": "exact description of what was attempted",
      "verbatim_goal": "exact text from plan checklist item",
      "what_was_tried": "one sentence",
      "why_it_failed": "one sentence"
    }
  ],
  "continuation_path": "specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TS}.md"
}
```

**Field semantics**:
- `summary`: REQUIRED. What the orchestrator surfaces as the dispatch summary — both engines
  read `.summary` unconditionally.
- `artifacts`: REQUIRED array (may be `[]` only when `status` is `partial`/`blocked`/`failed`;
  non-empty required when `status` is `implemented`). This is what `skill_link_artifacts`
  consumes to link the produced file(s) into `state.json` — an absent or empty `artifacts` on an
  `implemented` handoff silently prevents the summary artifact from being linked. Name the
  implementation summary file with `type: "summary"`.
- `phase`: Optional, informational. Not required.
- `dispatch_seq`: Optional (but REQUIRED-TO-ECHO whenever present in your delegation context).
  Copy the delegation context's `dispatch_seq` value into this field UNCHANGED — never invent,
  increment, or recompute one; that minting happens only in the orchestrator, immediately before
  the `Agent` call. Omit this field when your delegation context omits it — do not fabricate a
  value. This is the orchestrator-minted per-dispatch identity Stage 5 of both orchestrate
  engines compares against the value it minted for the current cycle, to discriminate a
  still-live predecessor's late write from this dispatch's own report. See
  `context/patterns/dispatch-report-not-termination.md`.
- `skeleton`: Boolean, default `false`. `true` ONLY when `status == "implemented"` and
  completeness rests on one or more strategic sorries meeting the `anti-analysis.md`
  strategic-sorry policy — the "implemented (skeleton)" outcome. MUST be `false` or absent when
  `status` is `"partial"` or `"blocked"` (see the status/skeleton interaction table below).
- `sorry_inventory`: Array of entries, one per sorry introduced, with the canonical schema
  `{file, line, statement, strategic, assumption, why_deferred, follow_up_task}`:
  - `file`, `line`, `statement`: location and verbatim statement of the sorry (as before).
  - `strategic`: boolean — `true` if the sorry qualifies as strategic under `anti-analysis.md`'s
    five-condition test; `false` for an ordinary leaf sub-sorry.
  - `assumption`: what the sorry stands in for / assumes.
  - `why_deferred`: why it was deferred rather than completed in this dispatch.
  - `follow_up_task`: the owning follow-up task number or sub-phase that will discharge it.
    REQUIRED (non-null) when `strategic: true` — an untracked strategic sorry is a defect, not a
    skeleton success.
- `blockers`: MUST include verbatim goal text (from the plan checklist) for each blocker.
  Paraphrasing is a defect -- the orchestrator uses verbatim text for re-dispatch prompts.
- `continuation_path`: Path to the handoff markdown artifact if `status != "implemented"`.
  Null when status is "implemented".

**status / skeleton interaction**:

| `status` | `skeleton` | Meaning |
|----------|------------|---------|
| `implemented` | `false` (or absent) | Fully complete, no outstanding sorries (unchanged baseline) |
| `implemented` | `true` | Build-green with only tracked strategic sorries — "implemented (skeleton)" |
| `partial` / `blocked` | `true` | **Invalid combination.** `skeleton: true` requires `status: "implemented"` |

## Continuation Handoff Markdown

When `status = "partial"` or `status = "blocked"`, the agent MUST also write a handoff
markdown artifact at `continuation_path`. Required sections:

1. **Immediate Next Action**: Exactly what the next agent should do first (1-3 sentences)
2. **Current State**: What files exist, what was completed, what is in an inconsistent state
3. **Key Decisions Made**: Architectural choices made during this dispatch that bind successors
4. **What NOT to Try**: Approaches attempted and failed, with brief failure reasons
5. **Remaining Goals** (verbatim from plan): Copy checklist items for incomplete work
6. **References**: Plan path, progress file path, key files

The handoff markdown is read by the successor agent, not the orchestrator. Write it for
an agent with no prior context about this task.

## Incremental Commit Discipline

Hard-mode agents commit at every green-build milestone. Never accumulate all changes into
a single end-of-dispatch commit.

**Commit triggers**:
- A new file is complete and syntactically valid
- A phase checklist item is verified done
- A test passes that previously failed
- Any other "green checkpoint"

**Commit format**:
```bash
git commit -m "task {N} phase {P}: {step description}

Session: {session_id}"
```

**Before each commit**:
1. Verify the build is green (or explicitly note "no build applicable for task type")
2. Check that no previously-passing tests now fail
3. Verify no sorry was introduced without being in the sorry_inventory

## Ordering: Handoff Write Precedes Marker Promotion (Defect 6)

**A phase heading MUST NOT be promoted to `[COMPLETED]` before the handoff reflecting that phase
has been written.** Phase-heading `[COMPLETED]` promotion is one of the commit triggers listed
above ("A phase checklist item is verified done"), which happens as part of this dispatch's
ongoing Incremental Commit Discipline; the terminal `.orchestrator-handoff.json` write happens
once, at the very end, "before terminating." Left unstated, these two events have no ordering
relationship to each other.

**Rationale**: an agent that marks a phase heading `[COMPLETED]` and then dies (API limit, infra
failure, any unrecoverable interruption) before reaching its terminal handoff write leaves the
plan file AHEAD of the handoff by construction — the plan claims more progress than the handoff
can confirm. A successor reading the plan's own markers to decide what to dispatch next (see both
orchestrate engines' heading-scan cross-check) would then dispatch over unconfirmed work.

**The ordering constraint**: within a single dispatch, write (or update) the terminal handoff
BEFORE the corresponding phase heading is promoted to `[COMPLETED]` in the same commit — or, if
the handoff is written once at the very end of a multi-phase dispatch, ensure the handoff's own
`phases_completed` accounts for every phase heading already promoted, so the two are never
observed out of sync by a reader. Do not promote a phase heading and defer the handoff update to
a later, uncommitted step.

## Teardown Precedes the Terminal Handoff Write

**Any watcher, monitor, or background job an agent arms during its own dispatch MUST be torn
down BEFORE that agent writes the terminal `.orchestrator-handoff.json`.** This is an
operational obligation, not a suggestion: a backgrounded `Bash` invocation (`run_in_background`),
a file/process watcher, or a monitor loop started to observe some condition during this dispatch
is this agent's own responsibility to stop before it reports. Leaving one running past the
terminal handoff write is a defect — it leaves an artifact of this dispatch alive after the
dispatch has told the orchestrator it is done.

**Standing limitation**: this teardown obligation cannot prevent a resume-driven wake — an
operator or a later cycle restarting work that observes state this agent left behind. It
complements, and never replaces, the sound territory contract's ownership declaration and
STOP-and-report duty. See `context/patterns/dispatch-report-not-termination.md`.

## Build-Green Invariant

At every commit, the following invariants hold:

1. **No regressions**: Completed work (phases marked [COMPLETED]) continues to pass its
   verification criteria
2. **Syntactically valid**: All modified files are syntactically valid for their language
3. **No leftover scaffolding**: No TODO-stubs, placeholder functions, or half-written code
   blocks, EXCEPT — under `--hard` only — documented strategic sorries that meet the
   `anti-analysis.md` strategic-sorry policy (deliberate skeleton division point, tightly
   scoped, documented, tracked in `sorry_inventory` with `strategic: true` and a non-null
   `follow_up_task`, and still build-green). STANDARD mode's invariant is unchanged and
   absolute: it has no strategic-sorry exception, and no leftover scaffolding of any kind is
   acceptable outside `--hard`.

Violating the build-green invariant is a critical defect. Do not commit broken work and
"continue in the next dispatch." Fix the regression before committing.

## Domain Specialization

- **lean4**: sorry_inventory is mandatory and must be populated. Each sorry includes
  the statement (verbatim from source), the location (file:line), and the justification. Under
  `--hard`, a sorry additionally counted as a strategic skeleton division point requires
  `strategic: true` and a non-null `follow_up_task` in its `sorry_inventory` entry (see the
  canonical entry schema above and the five-condition test in `anti-analysis.md`).
- **z3**: handoff JSON includes `assertion_inventory` with any un-verified assertions
