# Territory Contract (H7)

This contract implements H7: Territory Contracts for Parallel Dispatch. It governs
file ownership and commit coordination when multiple agents are dispatched simultaneously
to work on different phases of the same plan.

## File Territory

When the orchestrator dispatches multiple agents in parallel, each agent receives an
explicit file territory in its dispatch context:

```json
{
  "territory": {
    "owned_files": ["path/to/file1.ext", "path/to/file2.ext"],
    "read_only_files": ["path/to/reference.ext"],
    "forbidden_files": []
  }
}
```

**Rules**:
- Agent may create and modify files in `owned_files` only
- Agent may read (but not write) `read_only_files`
- Agent MUST NOT touch files in `forbidden_files`
- If a needed file is not in territory, request a territory extension via handoff
  (do not unilaterally expand territory)

## Plan-Section Territory

When multiple agents work on different phases of the same plan file:

- Each agent edits ONLY the checklist items for its assigned phase
- Phase heading status markers (`[IN PROGRESS]`, `[COMPLETED]`) may only be updated
  by the agent assigned to that phase
- The plan file preamble (Overview, Goals, Risks) is read-only for all implementation agents

## Commit Protocol

When working under territory constraints, agents follow strict commit discipline:

1. **Verify build before commit**: All commits must have a green build (or explicit "no build"
   task type). A failing commit is a territory violation regardless of who caused the failure.

2. **Non-fast-forward handling**: If `git commit` fails due to a non-fast-forward conflict:
   ```bash
   git fetch origin
   git rebase origin/$(git branch --show-current)
   # Re-verify build after rebase
   git commit ...
   ```

3. **Never force-push**: Territory violations by other agents are resolved via rebase,
   not force-push.

4. **Incremental commits**: Commit at each completed sub-task, not one commit at the end.
   Each commit message identifies the territory: "task N phase P: {step description}"

## Handoff Merge Rule

The `.orchestrator-handoff.json` file is a shared state file. Multiple agents may need
to update it. The protocol:

1. **Read current state**: Always read the file immediately before writing
2. **Merge, not clobber**: Merge your results into the existing JSON, do not overwrite
3. **Atomic update**: Write the merged result in a single Write operation
4. **Conflict resolution — reviewed against the `dispatch_seq` contract (Defect A)**: "last-write
   wins" is NOT a safe default for identifying whose write should be trusted — the whole point of
   `dispatch_seq` (see `context/patterns/dispatch-report-not-termination.md`) is that the
   chronologically LAST write to this file is not necessarily the current dispatch's own write; a
   woken predecessor's late write is, by construction, always the most recent one on disk. Do not
   read "last-write wins" as license to trust whichever write happened most recently in time.
   What DOES still hold, and is unaffected by this correction: two DIFFERENT phases' agents
   merging their own PHASE-SPECIFIC fields into the same handoff round-trip (read, add this
   phase's own data, write) do not need to coordinate with each other on those fields, because
   each phase's fields are disjoint. Fields shared across phases (e.g. `status`,
   `phases_completed`) still require re-read-merge, as before. The orchestrator's own Stage 5
   `dispatch_seq` gate — not "most recent mtime" and not "most recent write" — is the actual
   authority for which write is treated as this cycle's own.

## Territory Declaration Template

The orchestrator includes this in each parallel dispatch context:

```
Territory for this dispatch:
- Owned files: [list the exact files this agent creates/modifies]
- Read-only references: [list files this agent consults but must not write]
- Shared state file: .orchestrator-handoff.json (merge-write protocol required)
- Phase: {phase number and name}
- Scope: Do not work outside this phase's checklist items

This declaration asserts only what is locally checkable: which files THIS dispatch owns. It does
NOT assert that no other agent is concurrently active — a dispatch that has reported once may
still be live (a self-armed watcher/monitor, or an operator resume) and may still be committing
or writing files concurrently with this one. See
`context/patterns/dispatch-report-not-termination.md` for why. If you observe work you did not
do — a foreign commit, a foreign uncommitted modification, a running build you did not start —
STOP and report it. Do not proceed as though it were fictitious, and do not silently dismiss it
as noise.
```

**Explicit removal note**: no version of this template, past or present, licenses a dispatched
agent to conclude "I am the only agent working on this task" from anything stated here. If a
future edit reintroduces language that reads that way (e.g. "you have exclusive access" or "no
other agent is active"), that is a regression against this contract's intent — remove it rather
than resolve the tension in the agent's favor.
