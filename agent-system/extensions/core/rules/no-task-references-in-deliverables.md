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
- **Write-time gate**: `.claude/hooks/validate-no-task-references.sh` is a blocking PreToolUse
  gate (matcher `Write|Edit`) that scans new/edited content outside `specs/**` for task-number
  citation patterns and denies the write via exit code 2 (not `permissionDecision: "deny"`, which
  is documented-buggy for tools bare-allow-listed in `settings.json`'s `permissions.allow` — see
  `guard-destructive-git.sh` for the same pattern). It fails OPEN (exit 0, stderr warning) if its
  own shared pattern library cannot be sourced, so a broken guard never blocks every write in the
  repo. **`.memory/**` coverage, empirically verified**: `skill-todo`'s Stage 14 memory-harvest
  logic (the live path — distinct from the separate, presently-uncalled `memory-harvest.sh`
  script) creates new memory files via the `Write` tool with natural-language instructions, not a
  Bash heredoc, so this hook DOES see and can block `.memory/**` memory-candidate harvest writes.
  The heredoc gap exists only in `memory-harvest.sh` itself, which is not on the live `/todo`
  path today.
- **Agent contracts**: every agent that authors deliverable files outside `specs/**` carries an
  explicit MUST-NOT bullet against citing task numbers, sourced from one canonical fragment,
  `agent-system/extensions/core/context/contracts/no-task-references-bullet.md`. That fragment is
  a generated-copy source (not an `@`-import — `@`-references in an agent body do not auto-resolve
  at subagent spawn) and states the exact in-scope/out-of-scope classification rule: an agent must
  carry the bullet if and only if it authors deliverable files outside `specs/**`. This covers
  every dispatchable implementation agent (core and extensions alike), the planning agents
  (`planner-agent`, `planner-hard-agent`, `reviser-agent`), and `meta-builder-agent`; research
  agents whose only output is a `specs/**` report are out of scope by that same rule, not by
  oversight.
- **Coverage lint**: `lint-agent-contracts.sh` (Check C) enforces bullet presence across the full
  in-scope set defined by the fragment above, reading the expected text from the fragment file
  itself rather than a hardcoded string, so drift between the fragment and any agent's literal
  copy fails loudly instead of silently re-accumulating. See
  `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`.

**Deploy-mechanism note (not part of this rule's own scope, recorded for maintainers)**:
`agent-system/extensions/core/root-files/settings.json` is install-only by design — the deploy
loader's `manager.load` (`neotex.plugins.ai.shared.extensions.init`) skips a
`root-files/settings.json` copy once a target repo already has one, since that file carries
user/project-specific hook permissions and MCP configuration that must never be silently
overwritten. A new hook registration therefore does not reach an already-deployed repo's
`.claude/settings.json` through the root-files copy at all — it reaches it exclusively through
`merge-sources/settings-hooks.json` (an add-only, dedup-on-`deep_equal` merge target re-applied
on every load/resync/regenerate, reachable via the picker's `[Reload All]`/`[Regenerate]` entries
or `deploy-headless.sh`).

A second, related class of symptom — a brand-new `scripts/<subdir>/*.sh` file (e.g. this rule's
own `scripts/lib/task-reference-patterns.sh`, added when the taxonomy/library were first
authored) silently never reaching `.claude/scripts/<subdir>/` on an existing deploy — was
mis-diagnosed at the time this note was first written as an "already-loaded skip" analogous to
the settings.json case above. It was not: the root cause was the (now-retired) glob+allow-list
sync engine's top-path-segment allow-list match, which dropped every subdirectory-declared
`provides.scripts`/`provides.hooks` entry unconditionally, on both a fresh deploy and a resync
alike — it never ran a correct script copier for anyone, loaded or not. This is now fixed: the
deploy tree is driven by a single manifest-driven engine (`neotex.plugins.ai.shared.extensions`'s
`manager.load`/`manager.resync_all`/`manager.wipe`, reachable interactively via the picker's
`[Reload All]`/`[Regenerate]` entries and headlessly via `deploy-headless.sh`), which addresses
every declared entry — including subdirectory-declared ones — by its manifest path rather than by
a directory-glob allow-list. A scratch-tree regression harness
(`agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh`) asserts a
subdirectory-declared `scripts/lib/*.sh` entry lands on both a fresh deploy and a resync, guarding
against a regression of this exact defect class.
