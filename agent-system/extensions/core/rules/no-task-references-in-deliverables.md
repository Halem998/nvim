# No Task-Number References in Deliverables

<!-- Deliberately eager (no `paths:` frontmatter): this rule gates writes across the entire
repo -- any deliverable file, in any location, could be about to receive a task-number
reference. A glob narrow enough to matter would have to be "**/*", which buys nothing over no
frontmatter at all (see `source-store-deploy-boundary.md` and `pr-prohibition.md` for the same
reasoning applied to their own universal-scope rules). This is a deliberate decision recorded
here during the eager-context-budget audit, not an omission. -->

## Path Pattern

Applies to: the entire repository EXCEPT `specs/**/*` (task-management artifacts), git commit
messages, and PR/branch metadata.

## Principle

Deliverable files — the actual work product under `.claude/`, `lua/`, other code, and
documentation — MUST NOT reference ephemeral task-management metadata such as "task N",
"tasks N-M", or "(task N)". Task numbers are renumbered during vault operations (see
`.claude/rules/state-management.md`) and are meaningless to a future reader. Cite durable
anchors instead: a filename, a section heading, a decision-record name, or a verified fact.

## Exceptions (task numbers ARE permitted here)

- `specs/**` artifacts: reports, plans, summaries, `TODO.md`, `state.json`
- Git commit messages (the `task {N}: {action}` convention in `.claude/rules/git-workflow.md`)
- PR/branch metadata (branch names like `task-{N}-{slug}`, PR descriptions)

## Full Taxonomy and Enforcement

The 7-category exemption taxonomy (including the `task-ref-ok` marker convention) and the
three-layer enforcement narrative live in
`.claude/context/standards/task-reference-exemptions.md` — load it before adding, exempting, or
reviewing any task-number occurrence. The mechanical source of truth for pattern and exemption
logic is `scripts/lib/task-reference-patterns.sh`, consumed by both `check-task-references.sh`
(repo-wide lint) and `hooks/validate-no-task-references.sh` (blocking write-time gate).
