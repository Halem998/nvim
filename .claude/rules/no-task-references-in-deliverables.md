# No Task-Number References in Deliverables

## Path Pattern

Applies to: the entire repository EXCEPT `specs/**/*` (task-management artifacts), git commit
messages, and PR/branch metadata — see Exceptions below.

## Principle

Deliverable files — the actual work product under `.claude/`, `lua/`, other code, and
documentation — MUST NOT reference ephemeral task-management metadata such as "task N",
"tasks N-M", or "(task N)". Task numbers are renumbered during vault operations (when
`next_project_number` exceeds 1000, tasks are renumbered by subtracting 1000 — see
`.claude/rules/state-management.md`), and are meaningless to a future reader of a context file,
standard, or piece of code who has no access to (or interest in) the task tracker.

## Exceptions (task numbers ARE permitted here)

- `specs/**` artifacts: reports, plans, summaries, `TODO.md`, `state.json`
- Git commit messages (the `task {N}: {action}` convention in `.claude/rules/git-workflow.md`
  is the allowed use and stays as-is)
- PR/branch metadata (branch names like `task-{N}-{slug}`, PR descriptions)

## Reference Durable Anchors Instead

When a deliverable needs to explain provenance, prior context, or "why does this section exist,"
cite a durable anchor: a sibling document's filename, a section heading, a decision-record name,
or a verified fact — never the ephemeral task number that happened to produce it.

**Before** (observed anti-pattern, illustrative only):
```markdown
## 13. Index Freshness, Reindex, and the Absence of an Auto-Indexer (tasks 823-824)

**Architecture context (task 35)**: the freshness machinery below is mechanism 3 ...
```

**After**:
```markdown
## 13. Index Freshness, Reindex, and the Absence of an Auto-Indexer

**Architecture context**: the freshness machinery below is mechanism 3 of the notmuch indexing
pipeline described in `wrapper-contracts.md` section 9 (mbsync trigger paths) ...
```

The durable anchor is the section/document reference ("section 9", "mbsync trigger paths"), not
the ephemeral identifier that happened to write it.

## Enforcement

- **Advisory hook**: `.claude/hooks/validate-no-task-references.sh` (PostToolUse, non-blocking)
  scans new/edited content outside `specs/**` for task-number citation patterns and surfaces a
  reminder — it never blocks the write.
- **Agent reinforcement**: implementation agents that author files outside `specs/**` include a
  MUST NOT rule against task-number citations (see agent files below).
