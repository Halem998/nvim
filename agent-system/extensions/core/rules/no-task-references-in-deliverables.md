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
<!-- task-ref-ok:begin quoted historical anti-pattern -->
```markdown
## 13. Index Freshness, Reindex, and the Absence of an Auto-Indexer (tasks 823-824)

**Architecture context (task 35)**: the freshness machinery below is mechanism 3 ...
```
<!-- task-ref-ok:end -->

**After**:
```markdown
## 13. Index Freshness, Reindex, and the Absence of an Auto-Indexer

**Architecture context**: the freshness machinery below is mechanism 3 of the notmuch indexing
pipeline described in `wrapper-contracts.md` section 9 (mbsync trigger paths) ...
```

The durable anchor is the section/document reference ("section 9", "mbsync trigger paths"), not
the ephemeral identifier that happened to write it.

## Exemption Taxonomy

This is the single source of truth for what counts as a citation and what is exempt. Both
`scripts/check-task-references.sh` (the repo-wide lint gate) and
`hooks/validate-no-task-references.sh` (the write-time guard) consume this taxonomy
mechanically through one shared library, `scripts/lib/task-reference-patterns.sh` — neither
script defines pattern or exemption logic on its own.

**Exemption marker convention**: a line containing the substring `task-ref-ok:begin` opens an
exempt region that runs through (and includes) the next line containing `task-ref-ok:end`;
comment syntax is irrelevant (markdown `<!-- -->`, shell `#`, Lua `--`) since the token is
matched as a plain substring. A single line containing the substring `task-ref-ok` is itself
exempt (inline form). Both the block form and the inline form REQUIRE a trailing reason naming
one of the categories below, carried on the begin marker (block form) or the inline marker line
(inline form); the end marker itself may be bare.

| Category | Verdict | Marker required? | Example |
|----------|---------|-------------------|---------|
| 1. `specs/**` artifacts | Path-level exemption, no marker, unchanged | No | Any file under `specs/**` |
| 2. Git commit-message convention examples | Convert to placeholders (`task {N}: {action}`, `task {N} phase {P}: {phase_name}`); a single genuinely-rendered example per convention may keep concrete numbers | Yes, for the one retained rendered example only | `task {N}: create {title}` (placeholder); one marked rendered instance kept for illustration |
| 3. Command-usage examples | Keep concrete numbers — the flag takes a number and a placeholder makes the example unusable | Yes | `/research 7, 22-24, 59` |
| 4. Quoted historical anti-patterns | Keep verbatim — the point is to show a real past violation as a negative example | Yes | The **Before** block above |
| 5. Placeholder-bearing prose | Not matched by `TASK_PATTERN` at all; recorded here as a constraint on future pattern changes, never broaden the digit-requirement | No (not applicable — never matches) | `task {N}`, `specs/{NNN}_{SLUG}/`, `MM_{short-slug}.md` |
| 6. Test fixtures for the reference-pattern detector itself | Keep concrete digits verbatim — the fixture's whole purpose is asserting the shared library's regex triggers (or does not trigger) on a specific literal string; a placeholder would not match `[0-9]+` and would silently disable the assertion | Yes | `assert_triggers "positive: task 788" ... "See task 788 for context"` in `scripts/tests/test-validate-no-task-references.sh` and the five-named-forms fixture block in `scripts/tests/test-census-count.sh` <!-- task-ref-ok quoting the actual fixture strings, category 6 --> |
| 7. Memory vault frontmatter provenance fields (`topic`, `source`) | Keep concrete numbers verbatim in the YAML frontmatter block only — `memory-harvest.sh` and `/learn` write `topic: "task-${task_number}"` / `source: "${source_artifact}"` as structured provenance data, not deliverable prose; a placeholder would misrepresent which task actually produced the memory | Yes, inline on the frontmatter line itself as a `#`-prefixed trailing comment (the only comment syntax YAML recognizes; `<!-- -->` is NOT valid here and can break strict parsers) | `topic: "task-595"  # task-ref-ok inline, category 7` |

**Discovered during Phase 5 purge, not pre-declared in Phase 1**: this category was added when
the repo-wide scan flagged `scripts/tests/test-validate-no-task-references.sh` and
`scripts/tests/test-census-count.sh` — both author literal `task N` / `Task #N` / `tasks N-M`
strings on purpose, as input fixtures asserting the shared pattern library's regex behavior.
These are distinct from category 4 (quoted historical anti-patterns, which quote a REAL past
violation) — the fixture digits here are synthetic and were never a citation of any actual task.
Converting them to `{N}` would silently break the positive-match assertions (a placeholder never
satisfies `[0-9]+`), so they are marked and kept verbatim rather than converted.

**Discovered during Phase 10 purge, not pre-declared in Phase 1**: this category was added when
the repo-wide scan flagged `.memory/10-Memories/*.md` frontmatter — `topic: "task-NNN"` and
`source: "..."` are written directly by `memory-harvest.sh` (and by `/learn`) as structured
provenance data recording which task produced the memory, not as prose a human author composed.
This directly conflicts with a naive purge, which would falsify the record; the field is marked
in place with an inline `task-ref-ok` comment on the same YAML line rather than rewritten,
consistent with how category 6 marks rather than rewords a machine-authored literal. Only the
memory's PROSE BODY (the `# {title}` section and everything below it) is purged of citations;
the frontmatter block above the second `---` is never rewritten for this rule, only marked.

**Resolved test case**: `.claude/rules/git-workflow.md`'s own `Examples` block self-tripped the
write-time hook's `PHASE_PATTERN` at `task {N} phase {P}: {phase_name}` rendered concretely.
Category 2 applies: the other rendered examples in that section were converted to placeholder
form, and the one retained rendered example (showing the compound task+phase commit form) is
wrapped in a `task-ref-ok:begin/end` region with reason `canonical rendered commit-message
example`. A path-scoped allowlist for that whole file was considered and rejected — it would
grant blanket immunity to a file that could also, in the future, accumulate real violations
elsewhere in its body.

## Enforcement

Three layers. `specs/**` is the ONLY exempt tree — `agent-system/extensions/**`, `.opencode/**`,
`lua/**`, and `.memory/**` are all deliverables subject to this rule.

- **Repo-wide lint gate**: `.claude/scripts/check-task-references.sh` scans every git-tracked
  file under the four deliverable tree roots above and exits non-zero on any unexempted finding.
  It is wired as gate 4 of `scripts/verify-deploy.sh`.
- **Write-time gate**: `.claude/hooks/validate-no-task-references.sh` (currently advisory
  PostToolUse — this bullet states the present truth and will be updated once the hook is
  flipped to a blocking PreToolUse gate) scans new/edited content outside `specs/**` for
  task-number citation patterns and surfaces a reminder. It does not yet block the write.
- **Agent contracts**: four agent files carry an explicit MUST-NOT bullet against citing task
  numbers in files outside `specs/**` —
  `agent-system/extensions/core/agents/general-implementation-agent.md`,
  `agent-system/extensions/core/agents/general-implementation-hard-agent.md`,
  `agent-system/extensions/cslib/agents/cslib-implementation-agent.md`, and
  `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`.

**Known gap**: the extension implementation agents `neovim-implementation-agent`,
`nix-implementation-agent`, and `email-implementation-agent` also author files outside
`specs/**` and do not yet carry the MUST-NOT bullet. This is a real, named gap, not an oversight
papered over — adding it to those three agents is out of scope for the plan that authored this
section and is left as a follow-up.
