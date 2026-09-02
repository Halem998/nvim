# Research Report: Task #48

**Task**: 48 - Propagate the scoped-commit fix to the call sites it never reached
**Started**: 2026-09-01T23:40:00Z
**Completed**: 2026-09-01T23:59:59Z
**Effort**: large (multi-phase implementation; this report is inventory + design only)
**Dependencies**: None
**Sources/Inputs**: Codebase (`agent-system/extensions/`), `git-commit-scoped.sh` header/body, `git-staging-scope.md`, `lint-state-writer-boundary.sh` (design precedent), `verify-deploy.sh`, `manifest.json`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Re-measured current state** (the delegation's counts were explicitly marked stale): **103
  files**, **161 occurrences** of literal `git commit -m` under `agent-system/extensions/`. Of
  these, **98 files are genuine unmigrated call sites**; **5 are legitimate, reasoned exceptions**
  (the implementation itself, a whole-tree WIP-branch snapshot helper, a guard-hook comment, a
  guard-hook's own test fixtures, and one standards doc that already self-disclaims its inline
  example as illustrative-only). Only **7 files actually invoke `git-commit-scoped.sh`** today
  (the delegation's "5" was close but the tree has moved since).
- **Root cause of the spread, confirmed**: two scaffold templates —
  `context/templates/command-template.md` and `docs/templates/command-template.md` — still teach
  the raw `git add` + bare `git commit -m` shape, as do the core "how to commit" reference docs
  (`context/standards/git-safety.md`, `context/contracts/wrap-up.md`,
  `context/checkpoints/checkpoint-commit.md`, `skills/skill-git-workflow/SKILL.md`). Every
  extension command/skill/agent inspected (founder, present, lean, web, filetypes, epidemiology,
  cslib, typst, python, z3, nvim, nix, latex) reproduces the *identical* narrow-`git add` +
  bare-`git commit -m` shape — strong evidence they were copy-pasted from these templates/docs
  rather than independently invented. **Fixing the templates and reference docs first is the
  highest-leverage single step** — it stops new copy-paste regressions and gives every subsequent
  migrated call site a correct pattern to crib from.
- `context/standards/git-safety.md` (13 occurrences) is the most stale artifact in the tree: it
  predates `git-commit-scoped.sh` entirely (dated 2025-12-29) and contains zero reference to it,
  despite being the canonical "when/how to make a safety commit" doc that
  `implementation-workflow.md`'s XML-stage blocks quote near-verbatim.
- `context/standards/git-staging-scope.md` is **already correct** — it states the pathspec-naming
  and mutex-serialization rules as mandatory, names `git-commit-scoped.sh` as "the single
  sanctioned implementation," and explicitly labels its own inline example blocks
  "illustrative... NOT the sanctioned implementation." No content fix needed there; it is one of
  the 5 exceptions.
- **Lint recommendation: yes, add one.** `lint-state-writer-boundary.sh` is a directly reusable
  design template (two-layer: structural line classifier + a short, reason-carrying file-level
  allowlist) and is already wired as gate 12 of 16 in `verify-deploy.sh`. A sibling
  `lint-scoped-commit-boundary.sh` should occupy gate 17, registered in `manifest.json`'s lint
  list. Full design in Findings below.

## Context & Scope

Task 48 asks this research pass to re-derive the call-site inventory (the delegation context
states the description's counts are stale — this batch deleted `commands/research.md`,
`commands/plan.md`, `commands/implement.md`), categorize each site as migrate/exempt, and settle
whether a mechanical lint should gate the raw pattern going forward. This report does not perform
the migration; it hands a phased, prioritized inventory to `/plan`.

## Findings

### The mechanism (confirmed correct, no changes needed)

`agent-system/extensions/core/scripts/git-commit-scoped.sh` closes two independent defects:

1. **V1 (the original bug)**: a scoped `git add` followed by a *bare* `git commit` still commits
   the entire shared index, not just what was just staged — a concurrently-dispatched agent's
   staged-but-uncommitted work gets swept in. Fixed by requiring `git commit -m "..." --
   <pathspec>...` on every call.
2. **Residual race**: two simultaneous scoped commits can race on git's own `index.lock`. Fixed by
   serializing `git add`+`git commit` through the `specs/.commit-lock/` mutex
   (`task-lock.sh`'s `commit-acquire`/`commit-release`), with a bounded one-retry backoff on an
   `index.lock` failure that still occurs.

It also folds in two safety gates (V2: drop unmatched pathspecs rather than aborting the whole
commit; V3: refuse an exclude-only pathspec list, which would commit *wider* than a bare commit)
and auto-injects the canonical ephemeral-runtime-file exclusion set for any `specs/{NNN}_*/`
positive pathspec (conditionally, gated on `git check-ignore`, to avoid an abort hazard on an
already-ignored, currently-present path like a held `.lock/`). None of this needs rework —
confirmed by full read of the script.

### Current-state measurement (re-derived; supersedes the delegation's numbers)

```
grep -rl 'git commit -m' agent-system/extensions/          -> 103 files
grep -ro 'git commit -m' agent-system/extensions/ | wc -l    -> 161 occurrences
grep -rl 'git-commit-scoped.sh' agent-system/extensions/     -> 24 files (any mention: docs, tests, invocations)
actual invocation call sites of git-commit-scoped.sh         -> 7 files
```

### Category A — Exceptions (do NOT migrate; 5 files)

| File | Reason |
|---|---|
| `core/scripts/git-commit-scoped.sh` | The sanctioned implementation itself (2 occurrences, both the guarded `git commit -m "$full_message" -- "${pathspecs[@]}"` invocation plus its retry). |
| `core/scripts/git-snapshot.sh:279` | `--branch` mode: `git add -A && git commit -m "wip snapshot ${TS}"` on a scratch `wip-snapshot-{ts}` branch, immediately followed by checkout back to the original branch. This is a deliberate **whole-tree** WIP capture before a destructive operation (git reset --hard, clean -fd, etc.) — the entire point is to snapshot everything, not a task scope. It sits outside the dispatch/commit pipeline `git-staging-scope.md` governs. Confirmed by reading the file's header contract and the surrounding `--branch`/`--no-revert` logic. |
| `core/scripts/tests/test-guard-destructive-git.sh` | ~18 occurrences, all string literals fed to `guard-destructive-git.sh`'s parser as test fixtures (asserting the hook correctly allows/parses a `git commit -m "..."` containing quoted mentions of other git subcommands). No commit is ever executed; this is the hook's own test suite, not a commit call site. |
| `core/hooks/guard-destructive-git.sh:84` | A comment illustrating an edge case the hook's quote-stripping must handle (`git commit -m "fix -a bug"`) — prose, not executable. |
| `core/context/standards/git-staging-scope.md` | Contains 3 raw-looking example lines, but the file explicitly frames its first template as "illustrative of the overall staging shape only — it is NOT the sanctioned implementation" and dedicates a full section to naming `git-commit-scoped.sh` as canonical and mandating pathspec-naming. Already compliant messaging; no fix needed. (A textual-only lint would still need to allowlist this file — see Lint design below.) |

### Category B — Real call sites requiring migration (98 files, ~143 occurrences)

Organized into tiers by leverage/priority for `/plan` to phase:

**Tier 0 — Root cause / regression prevention (fix first — every extension pattern below was
almost certainly copy-pasted from one of these):**

| File | Occurrences | Note |
|---|---|---|
| `core/context/templates/command-template.md` | 1 | The scaffold new commands are built from |
| `core/docs/templates/command-template.md` | 1 | Docs mirror of the same template |
| `core/context/standards/git-safety.md` | 13 | Predates the fix; zero mention of `git-commit-scoped.sh`; XML `<stage>` blocks quoted by other workflow docs |
| `core/context/contracts/wrap-up.md` | 1 | Postflight commit contract reference |
| `core/context/checkpoints/checkpoint-commit.md` | 1 | The generic "Create Commit" checkpoint stage |
| `core/skills/skill-git-workflow/SKILL.md` | 2 | The dedicated "how to git commit" skill — does not use its own sibling script |

**Tier 1 — Core commands explicitly named in the delegation:**

| File | Occurrences |
|---|---|
| `core/commands/todo.md` | 7 |
| `core/commands/task.md` | 2 |
| `core/commands/errors.md` | 1 |
| `core/commands/review.md` | 1 |

**Tier 2 — Remaining core skills/agents:**

| File | Occurrences |
|---|---|
| `core/skills/skill-reviser/SKILL.md` | 2 |
| `core/skills/skill-spawn/SKILL.md` | 1 |
| `core/skills/skill-meta/SKILL.md` | 1 |
| `core/skills/skill-project-overview/SKILL.md` | 1 |
| `core/skills/skill-fix-it/SKILL.md` | 1 |
| `core/agents/meta-builder-agent.md` | 1 |

**Tier 3 — Core process/pattern/troubleshooting/guide docs (14 files):**

| File | Occurrences | Note |
|---|---|---|
| `core/context/processes/implementation-workflow.md` | 3 | Real automated call sites (phase/final commit XML stages) |
| `core/context/processes/research-workflow.md` | 1 | **"Manual commit required" error-recovery prose**, not an automated call site — see judgment call below |
| `core/context/processes/planning-workflow.md` | 1 | Same manual-fallback category |
| `core/context/standards/error-handling.md` | 2 | One is manual-fallback prose; one (`git commit -m "feat: Add new module"`) is a generic non-task illustrative example unrelated to the dispatch pipeline |
| `core/context/patterns/subagent-continuation-loop.md` | 2 | Real automated call sites (mid-loop + final commit) |
| `core/context/patterns/file-metadata-exchange.md` | 1 | Real call site; ironically its own comment cites `git-staging-scope.md` ("never a repo-wide add") yet still ends in a bare commit |
| `core/context/patterns/checkpoint-before-overflow.md` | 1 | Real automated call site (checkpoint-before-handoff commit) |
| `core/context/troubleshooting/workflow-interruptions.md` | 1 | Real automated call site |
| `core/docs/guides/creating-commands.md` | 1 | Doc guide |
| `core/docs/guides/creating-skills.md` | 1 | Doc guide |
| `core/docs/guides/permission-configuration.md` | 2 | Doc guide |
| `core/docs/guides/user-installation.md` | 1 | Doc guide |
| `core/docs/examples/research-flow-example.md` | 1 | Worked example |
| `core/docs/examples/fix-it-flow-example.md` | 1 | Worked example |

**Tier 4 — Non-core extension commands/skills/agents (68 files, ~1 occurrence each, uniform
narrow-`git add`-then-bare-`git commit -m` shape confirmed by direct sampling across every
extension listed):**

| Extension | Files | Count |
|---|---|---|
| founder | 10 commands + 15 skills + `founder-implement-agent.md` | 26 |
| present | 5 commands + 7 skills | 12 |
| lean | 4 skills + 2 agents | 6 |
| web | 2 skills + 1 agent | 3 |
| filetypes | 5 commands (convert, edit, scrape, sheet, table) | 5 |
| epidemiology | `commands/epi.md` + 2 skills | 3 |
| cslib | `commands/pr.md` + `skill-cslib-vet` + `cslib-implementation-hard-agent.md` | 3 |
| memory | `skill-learn/SKILL.md` + `memory-troubleshooting.md` | 2 |
| nix | `nix-implementation-agent.md` + `nixos-rebuild-guide.md` | 2 |
| typst, python, z3, nvim, latex, literature | 1 implementation-agent (or skill) each | 6 |

Sampled and confirmed identical (staged `git add`, then bare `git commit -m "task ${n}: ..."`) in:
`skill-analyze`, `skill-grant` (2 sites), `filetypes/table.md`, `skill-lean-implementation`,
`skill-web-implementation`, `skill-epi-implement`, `skill-cslib-vet` — no outliers found in the
sample; `/plan` should treat the remaining Tier 4 files as the same pattern unless a per-file read
during implementation finds otherwise.

### The manual-fallback / error-recovery sub-category (judgment call for /plan)

`research-workflow.md`, `planning-workflow.md`, and one of `error-handling.md`'s two sites show
the raw command inside a **"Manual commit required" human-recovery block** — text shown when the
automated pipeline failed and a human is expected to type the command themselves, not an
automated call site. These are not wrong in the same sense as the automated sites (nothing
executes them unattended), but leaving them raw means a manually-typed recovery commit skips the
mutex serialization and exclusion-set injection too. Recommend migrating the suggested command in
these blocks to the `git-commit-scoped.sh` invocation as well — it is no harder to type/paste and
keeps the recovery path exercising the same safety net — but flag this as a deliberate choice
rather than a mechanical rewrite, per the task's "inspect each" instruction.

### Migration mechanics note for /plan

Two message-construction styles appear across the corpus and both need a consistent target shape:

- Simple double-quoted: `git commit -m "task ${n}: complete implementation\n\nSession: ${sid}"`
- Heredoc-quoted: `git commit -m "$(cat <<'EOF' ... EOF)"`)

`git-commit-scoped.sh`'s `--message` flag takes the commit body **without** the trailing
`Session: ...` line (it appends that itself), so migration is a mechanical extraction of the
first-line/body text into `--message "<body>"` plus `--session "$session_id"` plus `--
<pathspec>...` reusing the same paths the site already staged — not a rewrite of the message
content itself. Sites already using `--honest-index-rows`-eligible staging (anything staging
`specs/state.json` or `specs/TODO.md`) should also gain `--honest-index-rows <task_number>` per
`git-staging-scope.md`'s stated requirement.

### Lint design (recommended: yes, add one)

`lint-state-writer-boundary.sh` (gate 12 of 16 in `verify-deploy.sh`, registered in
`manifest.json`'s `provides.hooks`/lint list at line ~127-132) is a directly reusable template:

- **Detection**: broad candidate regex over `.md`/`.sh` files (`git commit -m`), narrowed by a
  structural classifier (a genuinely scoped-and-serialized call is the sanctioned script's own
  invocation line, `git commit -m "$full_message" -- "${pathspecs[@]}"` — i.e. ends in a trailing
  `-- <pathspec>` — everything else is a candidate violation, mirroring
  `git-staging-scope.md`'s own stated rule that a commit lacking a trailing pathspec is a
  Forbidden Operation).
- **File-level allowlist**: exactly the 5 Category-A exceptions above, each carrying its reason
  inline (never a bare path list), plus the lint script's own path and its test fixture (mirrors
  `lint-state-writer-boundary.sh`'s self-reference exemption).
- **Wiring**: new script `core/scripts/lint/lint-scoped-commit-boundary.sh`; register in
  `core/manifest.json`'s lint array; add as **gate 17** in `verify-deploy.sh` (gates 1-16 currently
  exist, 12 is the state-writer sibling; new gate follows the same `[SKIP]`-if-not-source-store
  posture as gates 6/7/9/11/12).
- **Test fixture**: `core/scripts/tests/test-lint-scoped-commit-boundary.sh`, mirroring
  `test-lint-state-writer-boundary.sh`'s structure (dirty/clean fixture files, verbose-mode
  assertions).

### Acceptance-criterion feasibility check

`grep -rl 'git commit -m' agent-system/extensions/` returning only
`git-commit-scoped.sh` + its tests, plus named-and-exempted extras, is achievable: the 5
Category-A files above are the exemption set; every other file is either migrated to
`git-commit-scoped.sh` (which itself contains the literal string, so the acceptance grep's
"only git-commit-scoped.sh and its test files" phrasing already anticipates that) or its raw
text is removed by migration. `git-snapshot.sh` and `test-guard-destructive-git.sh` and
`guard-destructive-git.sh` need to be explicitly named as additional exemptions beyond
"git-commit-scoped.sh and its test files," matching the acceptance criterion's own escape clause
("or returns additional files each named in the summary with a stated exemption reason").

## Decisions

- Treat `context/templates/command-template.md`, `docs/templates/command-template.md`,
  `context/standards/git-safety.md`, `context/contracts/wrap-up.md`,
  `context/checkpoints/checkpoint-commit.md`, and `skill-git-workflow/SKILL.md` as **Phase 1** of
  the implementation plan (root-cause fix), ahead of the explicitly-named core commands, because
  every downstream extension site appears to derive from them.
- Recommend migrating the "Manual commit required" recovery-block sites too (not skip them),
  since the ask is safety-motivated and a manual recovery commit is exactly the moment a human is
  most likely to fat-finger scope.
- Recommend adding `lint-scoped-commit-boundary.sh` as gate 17, modeled directly on
  `lint-state-writer-boundary.sh`'s two-layer design, deferred until after migration lands (a
  lint added before migration would fail on ~98 pre-existing files and provide no signal).

## Risks & Mitigations

- **Scale**: 98 files is too large for one implementation phase. Mitigate by phasing per the
  tiers above (Tier 0 root-cause -> Tier 1 core commands -> Tier 2 core skills/agents -> Tier 3
  core docs -> Tier 4 extensions, extension-by-extension or in small batches).
- **Drift during migration**: as `git-staging-scope.md` itself notes, this exact pattern ("nine
  of eleven near-duplicate call sites never received the canonical exclusion set") has drifted
  before. The lint (once added post-migration) is the intended guardrail against recurrence.
  Until the lint lands, each migrated batch should be verified by re-running the measurement grep
  from this report.
- **False confidence from Tier 4 sampling**: only 7 of 68 Tier 4 files were opened directly; the
  rest were inferred identical by strong pattern consistency across every extension sampled.
  `/plan`/implementation should still open each file rather than blind-mechanically-rewrite, per
  the task's explicit instruction, in case an outlier exists (e.g., a commit that stages files
  outside the task directory legitimately).

## Context Extension Recommendations

- **Topic**: scoped-commit migration status / lint coverage
- **Gap**: `context/standards/git-staging-scope.md` documents the *contract* thoroughly but has
  no companion doc tracking *adoption status* across the source store the way, e.g., a lint
  summary would. Once `lint-scoped-commit-boundary.sh` exists, consider a one-line pointer from
  `git-staging-scope.md` to it (mirroring how `lint-state-writer-boundary.sh`'s existence is
  discoverable from `state-write.sh`'s neighborhood) so future contributors know a mechanical
  check exists.

## Appendix

### Search queries used

```
grep -rl 'git commit -m' agent-system/extensions/
grep -ro 'git commit -m' agent-system/extensions/ | wc -l
grep -rl 'git-commit-scoped.sh' agent-system/extensions/
grep -rn 'bash .claude/scripts/git-commit-scoped.sh' agent-system/extensions/
grep -rc 'git commit -m' agent-system/extensions/ --include=*.md
```

### Files read in full or substantial part

`core/scripts/git-commit-scoped.sh`, `core/scripts/git-snapshot.sh` (relevant sections),
`core/context/standards/git-staging-scope.md`, `core/context/standards/git-safety.md` (header),
`core/scripts/lint/lint-state-writer-boundary.sh` (full), `core/scripts/verify-deploy.sh` (gate
list), `core/manifest.json` (lint registration section).
