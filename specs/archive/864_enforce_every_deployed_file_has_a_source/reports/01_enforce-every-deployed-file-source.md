# Research Report: Task #864

**Task**: 864 - Enforce every deployed file has a source (hard drift gate)
**Started**: 2026-07-14T00:00:00Z
**Completed**: 2026-07-14T00:00:00Z
**Effort**: Medium-Large (audit is done; remediation touches 2 scripts + ~15 new source files + a
pre-existing regression in a third, unrelated subsystem)
**Dependencies**: 863 (extension store relocation — landed)
**Sources/Inputs**: Codebase inspection of `agent-system/extensions/*/manifest.json`,
`.claude/{agents,commands,rules,scripts,context}/`, `lua/neotex/plugins/ai/shared/extensions/{loader,init,config,verify}.lua`,
`.claude/scripts/check-extension-docs.sh`, git history (`git log --follow`), prior handoffs
(specs/862, specs/863)
**Artifacts**: This report; `.orchestrator-handoff.json`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Paths have moved**: the core extension source is now `agent-system/extensions/core/`, not
  `.claude/extensions/core/` (`.claude/extensions/` no longer exists as a directory — only a
  stray `.claude/extensions.json` state file remains). `check-extension-docs.sh` already reads
  `EXT_DIR="$REPO_ROOT/agent-system/extensions"` and is confirmed **byte-identical** between
  `.claude/scripts/check-extension-docs.sh` and `agent-system/extensions/core/scripts/check-extension-docs.sh`
  right now — the dual-write hazard has not yet drifted.
- **The real orphan set is much larger than the task description's "~4 standalone scripts" plus
  2 named files.** A full audit across all four requested categories (agents, commands, context,
  scripts — rules already covered by the landed `check_deployed_rule_drift`) finds **zero agent
  orphans, 2 command orphans, ~10 context orphans, and 8 script orphans** (23 files total),
  spanning **three different extensions** (core, literature, nvim) — not just core. See the full
  enumeration below.
- **Critical, separate finding**: 19 of the ~40 symlinks currently living under
  `.claude/{agents,commands,skills}/` are **broken** as a direct, verifiable regression from the
  predecessor relocation task (863). These are the intentional "symlink deploy mode" artifacts
  for the `cslib`, `literature`, and `pr-review` families, created by the legacy
  `install-extension.sh` script, which hardcodes the relative target
  `../extensions/$EXT_NAME/...` — a path that resolved correctly against the old
  `.claude/extensions/$EXT_NAME/` and is now dangling because the source moved to
  `agent-system/extensions/$EXT_NAME/`. This is NOT cosmetic: task 862's own handoff explicitly
  restored and verified `.claude/agents/literature-agent.md` and `.claude/commands/literature.md`
  as byte-identical, intentional symlinks — both are now broken again by 863. **This means the
  literature research agent and the `/literature` command may currently fail to resolve their
  deployed file at all.** This is a distinct invariant from "every deployed file has a source"
  (a broken symlink has no *resolvable* source, which is arguably a stricter failure), but a
  naive orphan scan over `.claude/commands/*.md` etc. via `git ls-files` — the natural
  implementation choice for the new hard gate — **will trip over these 19 broken symlinks** and
  must explicitly special-case them rather than either silently skipping them (masking the
  regression) or mis-reporting them as ordinary "unsourced" files (masking the real cause).
- **Recommendation**: treat the symlink regression as either an urgent Phase 0 of task 864's plan
  or a preceding hotfix; then extend `check-extension-docs.sh` with one new check per requested
  category plus one new "broken deployed symlink" check; then backfill the ~23 category orphans
  (mostly literature-owned, not core-owned as the original task description assumed) into their
  correct extension sources; then flip the gate from advisory to hard (non-zero exit already
  exists at the FAILURES>0 level — "hard gate" mainly means: CI/precommit wiring, if not already
  present, plus the new orphan checks contributing to `FAILURES`).

## Context & Scope

Verified current layout before proposing anything (the task explicitly warned the description
predates the relocation):

- Global extension source: `agent-system/extensions/{core,cslib,email,epidemiology,filetypes,
  formal,founder,latex,lean,literature,memory,nix,nvim,present,python,slidev,typst,web,z3}/`.
- `.claude/extensions/` does **not exist** on disk (only `.claude/extensions.json`, an unrelated
  state file of load records).
- `check-extension-docs.sh` dual copies: `.claude/scripts/check-extension-docs.sh` (deployed) and
  `agent-system/extensions/core/scripts/check-extension-docs.sh` (source) — confirmed
  byte-identical via `diff` (empty diff, no output). A **third**, unrelated file of the same name
  exists at `.opencode/scripts/check-extension-docs.sh` (and its own extension-source counterpart
  under `.opencode/extensions/core/scripts/`) — this is a **different, older script** for a
  parallel OpenCode deploy tree (`.opencode/extensions/*/`) with a materially smaller rule set (no
  context checks, no script/rule drift checks, no routing consistency, no dangling-contract scan).
  It is **out of scope**: task 864's file_scope and the dual-write hazard note only the two
  `.claude` scripts. Do not fold `.opencode`'s copy into the "byte-identical" requirement — they
  are legitimately different tools that happen to share a filename.
- `loader.lua`'s copy-deploy functions confirmed per category:
  - `copy_simple_files(manifest, source_dir, target_dir, category, ext, agents_subdir, protected)`
    — used for `agents` (with `agents_subdir` override — Claude Code uses `"agents"`, OpenCode
    uses `"agent/subagents"`, per `config.lua`), `commands`, and `rules` (all flat-file
    categories, one directory level, no recursion).
  - `copy_context_dirs(...)` — recursive: `provides.context` entries can be either a directory
    name (recursively copied, preserving substructure) or a bare filename at context root (e.g.
    `"README.md"`). This is the "context needs recursive directory comparison" divergence the
    task description anticipated.
  - `copy_scripts(...)` — flat, but `provides.scripts` entries may themselves contain a `/`
    (e.g. `"lint/lint-postflight-boundary.sh"`), so "flat" here means "one call copies
    `source_dir/scripts/<entry>` to `target_dir/scripts/<entry>` for whatever `<entry>` is,"
    not "no subdirectories allowed."
  - Both `copy_simple_files` and `copy_skill_dirs` explicitly **skip (never touch) a
    pre-existing symlink** at the deployed target — this is the symlink-safe convention from
    task 862 that the drift/orphan checks must respect rather than fight.
- `check-extension-docs.sh`'s existing rules, confirmed by full read (634 lines): `check_file`,
  `check_manifest_entries` (declared-but-missing-on-source, all 6 categories: agents, skills,
  commands, rules, scripts, context), `check_deployed_script_drift` (Rule F — content drift,
  scripts only), `check_deployed_rule_drift` (Rule I — content drift, rules only, the "already
  landed" check named in the task), `check_routing_block`, `check_undeclared_skills` (Rule A),
  `check_undeclared_rules` (Rule H), `check_routing_consistency` (Rules B+C), `check_deployed_skill_agents`
  (Rule D), `check_readme_vs_manifest`, `check_referenced_scripts_declared` (Rule E),
  `check_dangling_contract_references` (Rule G, project-wide). None of these detect a deployed
  file with **no manifest declaration in any extension** — that is precisely the gap task 864
  closes, and it is a third, previously-unimplemented direction (declared-but-missing exists;
  present-but-undeclared exists per-extension via Rule A/H; but "deployed and traceable to
  literally nothing, in any manifest, anywhere" does not exist for any category yet).

## Findings

### Complete Orphan Enumeration (deployed file, zero manifest source anywhere)

Method: for each category, built the set of every file under `.claude/<category>/` tracked by
git (`git ls-files`), then built the union of every extension's `provides.<category>` entries
resolved against every extension's own source tree (recursively, for `context`), then diffed.
Symlinks are separately enumerated (see next section) and excluded from this table since they are
governed by a different mechanism (`install-extension.sh`, not `provides.*` copy-deploy).

**rules** (already covered by the landed `check_deployed_rule_drift`, included here for
completeness since it motivated the task):
| Deployed file | Declared in any manifest? | Source exists anywhere? | Verdict |
|---|---|---|---|
| `no-task-references-in-deliverables.md` | **No** (not in core's `provides.rules`, confirmed via `jq`) | No | Orphan — needs both a manifest entry AND a source file. Note: the original task description said "declared in core manifest but no source file" — current manifest state is stricter: it is not declared at all. |
| `neovim-lua.md`, `nix.md` | Yes (nvim, nix extensions respectively) | Yes | Not an orphan — correctly sourced by their owning extensions, just not by core. (Confirms these two are NOT part of this task's remediation.) |

**agents**: **zero orphans**. Every deployed `.claude/agents/*.md` traces to a `provides.agents`
entry with a matching source file in some extension.

**commands** — 2 orphans:
| Deployed file | Declared? | Source? | Proposed home |
|---|---|---|---|
| `README.md` | No | No | `agent-system/extensions/core/commands/README.md` + add `"README.md"` to core's `provides.commands`. Content is currently **stale/misleading** — it claims `.claude/commands/` is a "Legacy Mirror Directory" superseded by `.opencode/commands/`, which is backwards from this repo's actual primary/mirror relationship as documented everywhere else in CLAUDE.md and the recent task history (`.claude/` is the actively-developed, primary Claude Code deploy tree; `.opencode/` is the secondary OpenCode mirror). Recommend the implementation phase rewrite this file's content, not just relocate it verbatim. |
| `zotero.md` | N/A — **this is a symlink, not a regular file** (`zotero.md -> ../extensions/zotero/commands/zotero.md`), and the target does not exist (no `zotero` extension exists anywhere — it was absorbed into `literature` before task 862). This was already flagged in task 862's handoff as a known, deliberately-deferred non-goal ("dangling `skill-zotero`/`zotero.md` symlink cleanup, provably inert but unrelated housekeeping"). | — | Not a source-homing candidate — it is dead weight from a merged-away extension. Recommend `git rm .claude/commands/zotero.md` (and the sibling `.claude/skills/skill-zotero` symlink) as cleanup, not "give it a source." |

**context** — 10 file-level orphans (using full recursive per-file comparison, matching how
`copy_context_dirs` actually deploys directory entries):
| Deployed file | Owning category entry | Source dir has other files but not this one? | Proposed home |
|---|---|---|---|
| `context/guides/hard-mode-routing.md` | core declares `"guides"` | Yes — `core/context/guides/` has `extension-development.md`, `loader-reference.md` only | `agent-system/extensions/core/context/guides/hard-mode-routing.md` |
| `context/guides/literature-organization.md` | core declares `"guides"` | Yes | Given the name, likely belongs under **literature**'s context tree instead of core's `guides/` — literature does not currently declare a `"guides"` context entry at all. Needs a planning-time decision: either (a) add `"guides"` to literature's `provides.context` and move the file under `literature/context/guides/`, or (b) keep it as a core-owned cross-cutting guide. Recommend (a) given the filename. |
| `context/patterns/batch-drain-loop.md` | core declares `"patterns"` | Yes — `core/context/patterns/` has 21 files, missing 4 | `agent-system/extensions/core/context/patterns/batch-drain-loop.md` |
| `context/patterns/context-protective-lead.md` | core declares `"patterns"` | Yes | `agent-system/extensions/core/context/patterns/context-protective-lead.md` |
| `context/patterns/fork-patterns.md` | core declares `"patterns"` | Yes, **and** a same-named file already exists at `agent-system/extensions/core/docs/fork-patterns.md` (in `docs`, not `context`). This looks like a miscategorization or an unfinished move between `docs/` and `context/patterns/` in a prior task, not a clean "never had a source" case. Needs a diff between the deployed `context/patterns/fork-patterns.md` and the existing `docs/fork-patterns.md` before deciding whether to (a) treat `docs/fork-patterns.md` as canonical and delete the deployed `context/patterns/` copy, or (b) add a `context/patterns/fork-patterns.md` source alongside the docs one if content has diverged. | Planning-time decision (content diff required first). |
| `context/patterns/topic-assignment-pattern.md` | core declares `"patterns"` | Yes | `agent-system/extensions/core/context/patterns/topic-assignment-pattern.md` |
| `context/project/literature/patterns/chunk-file-conventions.md` | literature declares `"project/literature"` | Yes — literature's `context/project/literature/` tree has `domain/literature-index.md`, `patterns/adhoc-navigation-directive.md`, `patterns/agent-exploration.md` only | `agent-system/extensions/literature/context/project/literature/patterns/chunk-file-conventions.md` |
| `context/project/literature/patterns/zotero-pdf-resolution.md` | literature declares `"project/literature"` | Yes | `agent-system/extensions/literature/context/project/literature/patterns/zotero-pdf-resolution.md` |
| `context/project/neovim/domain/extension-deploy-modes.md` | nvim declares `"project/neovim"` | Yes — this file was added by **task 862** (git blame confirms) and never backfilled into `nvim/context/project/neovim/domain/` | `agent-system/extensions/nvim/context/project/neovim/domain/extension-deploy-modes.md` |
| `context/index.json` | N/A — produced by `merge_targets.index` (a JSON-merge target from `index-entries.json` fragments across extensions), not by any `provides.context` copy. | — | **Not an orphan** under this mechanism — exclude explicitly from the new check (comparable to how `CLAUDE.md` is produced by `merge_targets.claudemd`, not `provides`). The new context-orphan check must skip `index.json` at the context root the same way it should skip any `merge_targets`-produced file, not just this one. |

**scripts** — 8 orphans (after excluding gitignored runtime artifacts: `literature-pyenv/` venv
tree, `__pycache__/`, both already `.gitignore`d and never tracked, so `git ls-files`-based
enumeration correctly excludes them without extra filtering):
| Deployed file | Proposed home |
|---|---|
| `scripts/lint/lint-contract-compliance.sh` | `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` (sibling of the already-sourced `lint/lint-postflight-boundary.sh`; add `"lint/lint-contract-compliance.sh"` to core's `provides.scripts`) |
| `scripts/validate-handoff.sh` | `agent-system/extensions/core/scripts/validate-handoff.sh` (validates the H9 `.orchestrator-handoff.json` schema referenced by `context/contracts/wrap-up.md` — clearly core-owned orchestration tooling) |
| `scripts/literature-audit.sh` | `agent-system/extensions/literature/scripts/literature-audit.sh` |
| `scripts/literature-pyenv-provision.sh` | `agent-system/extensions/literature/scripts/literature-pyenv-provision.sh` (referenced by `literature-convert.sh`, already in literature's own source — this is purely a packaging omission) |
| `scripts/zotero-resolve-pdf.sh` | `agent-system/extensions/literature/scripts/zotero-resolve-pdf.sh` |
| `scripts/.zotero-title-sim.py` | `agent-system/extensions/literature/scripts/.zotero-title-sim.py` (helper invoked only by `zotero-resolve-pdf.sh`, ship together) |
| `scripts/tests/generate-test-fixtures.py` | `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py` |
| `scripts/tests/test-literature-convert.sh` | `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` |

Note: `.claude/tests/` (a **different** directory — `test-validate-handoff.sh`,
`test-email-preference-harvest.sh`, `test-command-route-skill.sh`) is **not** part of the
copy-deploy mechanism at all — there is no `"tests"` `provides` category and no `copy_tests`
function in `loader.lua`. These are hand-maintained files, structurally identical in kind to
`specs/` or a hand-written `CLAUDE.md`, and are correctly **out of scope** for this task's drift
gate. Do not conflate `.claude/tests/` (out of scope) with `.claude/scripts/tests/` (in scope,
because it lives inside the `scripts` provides category).

### Critical: 19 Broken Symlinks From the Predecessor Relocation (separate from, but adjacent to, this task)

Full symlink audit of `.claude/{agents,commands,skills}/`:

```
BROKEN  .claude/skills/skill-cslib-research -> ../extensions/cslib/skills/skill-cslib-research
BROKEN  .claude/skills/skill-pr-review-implementation -> ../extensions/cslib/skills/skill-pr-review-implementation
BROKEN  .claude/skills/skill-zotero -> ../extensions/zotero/skills/skill-zotero
BROKEN  .claude/skills/skill-pr-review-research -> ../extensions/cslib/skills/skill-pr-review-research
BROKEN  .claude/skills/skill-literature -> ../extensions/literature/skills/skill-literature
BROKEN  .claude/skills/skill-cslib-implementation -> ../extensions/cslib/skills/skill-cslib-implementation
BROKEN  .claude/skills/skill-cslib-vet -> ../extensions/cslib/skills/skill-cslib-vet
BROKEN  .claude/skills/skill-cslib-implementation-hard -> ../extensions/cslib/skills/skill-cslib-implementation-hard
BROKEN  .claude/skills/skill-pr-implementation -> ../extensions/cslib/skills/skill-pr-implementation
BROKEN  .claude/skills/skill-cslib-research-hard -> ../extensions/cslib/skills/skill-cslib-research-hard
BROKEN  .claude/commands/vet.md -> ../extensions/cslib/commands/vet.md
BROKEN  .claude/commands/zotero.md -> ../extensions/zotero/commands/zotero.md
BROKEN  .claude/commands/literature.md -> ../extensions/literature/commands/literature.md
BROKEN  .claude/commands/pr.md -> ../extensions/cslib/commands/pr.md
BROKEN  .claude/agents/cslib-vet-agent.md -> ../extensions/cslib/agents/cslib-vet-agent.md
BROKEN  .claude/agents/literature-agent.md -> ../extensions/literature/agents/literature-agent.md
BROKEN  .claude/agents/cslib-research-agent.md -> ../extensions/cslib/agents/cslib-research-agent.md
BROKEN  .claude/agents/cslib-implementation-agent.md -> ../extensions/cslib/agents/cslib-implementation-agent.md
BROKEN  .claude/agents/cslib-implementation-hard-agent.md -> ../extensions/cslib/agents/cslib-implementation-hard-agent.md
BROKEN  .claude/agents/pr-review-implementation-agent.md -> ../extensions/cslib/agents/pr-review-implementation-agent.md
BROKEN  .claude/agents/cslib-research-hard-agent.md -> ../extensions/cslib/agents/cslib-research-hard-agent.md
BROKEN  .claude/agents/pr-review-research-agent.md -> ../extensions/cslib/agents/pr-review-research-agent.md
```

(21 total; the 4 `literature-pyenv/venv/...` symlinks under `scripts/` are internal to a
gitignored, auto-provisioned Python venv and resolve fine — unrelated.)

**Root cause, confirmed by reading `install-extension.sh`**: it is a legacy, parallel
deploy mechanism (distinct from `loader.lua`'s copy-deploy, used historically for `cslib` and
previously `zotero`) that hardcodes `rel_path="../extensions/$EXT_NAME/..."` at three call
sites (commands, skills, agents symlink creation). That relative path was correct when the
source lived at `.claude/extensions/$EXT_NAME/` (sibling of `.claude/commands/` etc.) and is
now wrong after task 863 moved the source to `agent-system/extensions/$EXT_NAME/` — a
different relative depth from `.claude/{agents,commands,skills}/`.

**Why this is more than housekeeping**: `skill-zotero`/`zotero.md`/`vet.md`/`pr.md` were
*already* broken before 863 (known, deferred in task 862's handoff — `zotero` was absorbed
into `literature` and never cleaned up; `cslib`'s `vet.md`/`pr.md` symlink health at that time
is not separately evidenced either way). But **`literature-agent.md` and `literature.md`
were explicitly restored and verified working by task 862** ("Restored the two
previously-flattened symlinks ... after verifying byte-identical content"). Task 863 (which
ran after 862) then broke them again as a side effect of the relocation, and nothing in 863's
scope or handoff mentions touching or re-verifying these symlinks. **This means the
`/literature` command and the literature research agent may not currently resolve at all**
in a Claude Code session, which is a live functional regression, not a documentation nit.

**Interaction with this task's hard gate**: `loader.lua`'s `copy_simple_files`/`copy_skill_dirs`
correctly treat any pre-existing symlink at a deployed target as "not owned by copy-deploy" and
never touch it — this is the intentional, already-landed "symlink-safe" convention from task 862,
and the new orphan checks in `check-extension-docs.sh` must **not** silently skip symlinks in a
way that hides breakage. Recommend a **new, distinct check** —
`check_broken_deployed_symlinks` (or folded as a stricter arm of the per-category orphan checks) —
that: (a) for every symlink found under `.claude/{agents,commands,skills}/`, verifies the target
resolves (`[[ -e "$f" ]]`), and (b) FAILs loudly (not silently skips) on any broken one, with a
message distinguishing it from an ordinary "unsourced regular file" orphan so a future reader
knows to look at `install-extension.sh`'s relative-path math rather than a missing extension
source file.

## Decisions

- **Scope confirmation**: the task's REQUIRED section 2 says "give every deployed-only orphan a
  source home in the core extension." Based on the actual audit, only 2 of the ~23 file-level
  orphans are genuinely core-owned (`no-task-references-in-deliverables.md`,
  `commands/README.md`) plus the new-and-not-yet-declared `lint-contract-compliance.sh` and
  `validate-handoff.sh` scripts (4 core-owned total). The remaining ~2 context files (nvim) and
  ~10 files (literature: 6 scripts + 2 context files, plus the commands/context items noted
  above) belong in their respective owning extensions, not core. The planning phase should treat
  "give it a source home" as "give it a source home in its **correct owning extension**," not
  literally always `core`.
- **`zotero.md` and `skill-zotero` are cleanup, not sourcing**: recommend deletion rather than
  fabricating a source for dead, superseded functionality. This should be called out explicitly
  in the plan so it isn't miscounted as "needs a source file."
- **`fork-patterns.md` needs a content diff before deciding its fate** — do not blindly create a
  `context/patterns/fork-patterns.md` source copy without first comparing it against the existing
  `docs/fork-patterns.md`, since one may be a stale duplicate of the other.
- **The broken-symlink regression is a distinct invariant from "has a source"** (a broken symlink
  technically *has* a manifest-declared source — `cslib`/`literature` do declare these
  agents/commands/skills, and the source files exist on disk under
  `agent-system/extensions/{cslib,literature}/...` — the symlink's *target path* is simply wrong
  post-relocation). Recommend surfacing it as its own check with its own failure message, and
  recommend the orchestrator decide whether to fix it inside 864 (natural fit, since it blocks a
  clean "hard gate = 0 failures" baseline) or spin it out as an urgent, narrowly-scoped hotfix
  task first.

## Risks & Mitigations

- **Risk**: a naive orphan check implemented via `find .claude/<category> -type f` (rather than
  `git ls-files`) will also enumerate the gitignored `literature-pyenv/venv/` tree and
  `__pycache__/`, producing hundreds of false-positive FAILs. **Mitigation**: use
  `git ls-files .claude/<category>` (as this research did) or explicitly exclude
  `literature-pyenv/` and `__pycache__/` by path, matching the existing `.gitignore` entries.
- **Risk**: treating symlinks as ordinary files in the new orphan scan will either (a) crash
  `cmp`/content-diff logic on a dangling symlink, or (b) silently mask the 19-symlink regression
  if the scan simply `[[ -f ]]`-skips anything not a regular file. **Mitigation**: explicit
  `[[ -L ]]` branch with its own check, as designed above.
- **Risk**: making the gate hard (non-zero exit blocking) before the ~23 orphans are backfilled
  and the 19 symlinks are repaired will make `check-extension-docs.sh` permanently red,
  encouraging future agents to ignore or bypass it. **Mitigation**: sequence the plan so
  remediation (backfill + symlink repair) lands in the same task/plan before or atomically with
  flipping any new check from advisory (`info`) to blocking (`fail`), never after.
- **Risk**: `context/guides/literature-organization.md`'s correct home is ambiguous (core vs.
  literature) without a deliberate decision. **Mitigation**: flagged explicitly above; planning
  phase should decide before implementation, not implementation-time guess.

## Context Extension Recommendations

- **Topic**: extension-deploy-modes (symlink vs copy-deploy) and their post-relocation fragility.
  **Gap**: `agent-system/extensions/nvim/context/project/neovim/domain/extension-deploy-modes.md`
  was created by task 862 but never backfilled to its own declared source location (ironic, given
  its subject matter) — this is itself one of the 10 context orphans found above, and its content
  should probably be extended to document the `install-extension.sh` relative-path fragility
  uncovered here, once repaired.
- **Topic**: `check-extension-docs.sh` rule taxonomy. **Gap**: the script's own header comment
  (lines 4-21) enumerates its rules by behavior but not by letter (Rules A/B/C/D/E/F/G/H/I are
  named inline at each function but never indexed together). **Recommendation**: once the new
  orphan checks (call them Rule J/K/L/M, one per category, plus a symlink-health rule) are added,
  consider adding a short index comment block mapping rule letters to one-line descriptions, to
  keep the now-10+-rule script navigable.

## Appendix

### Search Queries / Commands Used

- `find agent-system/extensions/core -maxdepth 2`, `diff .claude/scripts/check-extension-docs.sh agent-system/extensions/core/scripts/check-extension-docs.sh`
- `comm -23` set differences per category between `git ls-files .claude/<category>` and the union
  of `jq -r '.provides.<category>[]?' agent-system/extensions/*/manifest.json`
- Recursive context comparison: custom loop expanding each extension's `provides.context` entries
  (directory -> `find . -type f`; file -> itself) into a source-file-set, diffed against
  `git ls-files .claude/context`
- `find .claude -type l | while read f; do readlink + -e test; done` for the symlink audit
- `git log --oneline --follow -- <path>` to establish provenance/timing for several orphans and
  the literature-agent.md / literature.md symlink restoration claim (cross-checked against
  `specs/862_fix_loader_symlink_delete_data_loss/.orchestrator-handoff.json`)

### Files Read in Full

- `.claude/scripts/check-extension-docs.sh` (634 lines, confirmed identical to the
  `agent-system/extensions/core/scripts/` copy)
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` (copy_simple_files, copy_skill_dirs,
  copy_context_dirs, copy_scripts, remove_installed_files — symlink-safety sections)
- `agent-system/extensions/core/scripts/install-extension.sh` (symlink-creation rel_path logic)
- `specs/863_relocate_extension_source_store_out_of_claude/.orchestrator-handoff.json`
- `specs/862_fix_loader_symlink_delete_data_loss/.orchestrator-handoff.json`
- `agent-system/extensions/core/context/formats/handoff-artifact.md` (handoff schema reference)
