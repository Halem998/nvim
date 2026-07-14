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
4. **Conflict resolution**: If two agents update simultaneously, last-write wins ONLY
   for fields specific to the writing agent's phase. Shared fields (e.g., `status`)
   require re-read-merge.

## Territory Declaration Template

The orchestrator includes this in each parallel dispatch context:

```
Territory for this dispatch:
- Owned files: [list the exact files this agent creates/modifies]
- Read-only references: [list files this agent consults but must not write]
- Shared state file: .orchestrator-handoff.json (merge-write protocol required)
- Phase: {phase number and name}
- Scope: Do not work outside this phase's checklist items
```
