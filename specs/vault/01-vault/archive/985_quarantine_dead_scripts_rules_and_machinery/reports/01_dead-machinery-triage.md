# Research Report: Dead-Machinery Quarantine Triage

**Task**: Quarantine (never silently delete) dead machinery inventoried by the agent-system review, mirroring the literature extension's `scripts/deprecated/` + README-with-per-file-rationale precedent
**Started**: 2026-08-09
**Completed**: 2026-08-09
**Effort**: Research only (empirical re-verification of every inventory claim; no edits made)
**Dependencies**: deploy-engine consolidation, EXTENSION.md slim-down, state-schema, and test-runner efforts — all confirmed landed (see Findings)
**Sources/Inputs**: `specs/reviews/review-2026-07-29-agent-system.md`, `specs/state.json`, empirical `grep`/`git log` caller-graph re-verification across `agent-system/extensions/**`, `.claude/**` (deployed), `lua/neotex/plugins/ai/**`, and live Claude Code session behavior (see Finding 0)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The review's own headline claim about `.claude/rules/` loading is **wrong**, and it is wrong in a way that flips the triage for both "dead rules" — see Finding 0. Neither `pr-prohibition.md` nor `project-overview-detection.md` is dead: both carry YAML `paths:` frontmatter that Claude Code's harness auto-loads natively, independent of `CLAUDE.md`'s `@`-import list, and this was already true before the review date (`paths: "**/*"` on `pr-prohibition.md` dates to a mid-June commit). Recommendation for both: **keep-with-doc-note**, not quarantine.
- Of the 16 "manifest-only" scripts, two (`test-four-tier-conflict.sh`, `test-session-runtime-files.sh`) are **no longer dead** — the task-description's hint about `run-all.sh` checked out: both are flat `scripts/test-*.sh` files, and `run-all.sh`'s discovery glob picks up every such file automatically, so they run on every Gate-8 `verify-deploy.sh` pass. `validate-context-budgets.sh` is confirmed genuinely still unwired but has a real, `not_started` consumer (task-999-equivalent, "Reduce the 8 per-agent context budget overruns", file_scope includes this script) — keep, defer.
- Nine scripts are genuinely dead with zero callers anywhere (commands, skills, hooks, docs, other scripts, Lua): `check-vault-threshold.sh`, `vault-operation.sh`, `claude-project-cleanup.sh`, `orphan-detection.sh`, `rename-session.sh`, `roadmap-sync.sh`, `validate-extension-index.sh`, `archive-task.sh`, plus literature's `literature-decode-font-offset.py`. Three of these are outright **superseded duplicates** of a live script under a similar name (`roadmap-sync.sh` by `roadmap-integration.sh`, `validate-extension-index.sh` by `check-extension-docs.sh`'s Rule T) — a caller-graph trap the review's file-list format could not surface, since it only checked "is this basename referenced," not "does a differently-named script already do this."
- `archive-task.sh`, `orphan-detection.sh`, and `vault-operation.sh` are confirmed triple prose-reimplementations: `commands/todo.md` hand-rolls orphan detection (Step 2.5), archiving, and the full vault threshold-check-and-operation (Steps 5.7–5.8) directly in bash-in-markdown, never invoking any of the three scripts.
- One script, `lint/lint-contract-compliance.sh`, is genuinely non-redundant and valuable (hard-mode H-technique contract compliance, no overlap with the three lint scripts that already are wired into `verify-deploy.sh` gates 6/7/9) but simply was never added as a gate — recommend **wire-in**, not quarantine.
- Four scripts (`install-aliases.sh`, `install-systemd-timer.sh`, `migrate-directory-padding.sh`, `verify-lean-mcp.sh`) fit the "legitimate one-shot operator tool" pattern the task description names for the first three — `verify-lean-mcp.sh` (a manual lean-lsp MCP config diagnostic) belongs in the same bucket, a detail the original review inventory did not call out. Recommend **keep-with-doc-note**: add all four to `CLAUDE.md`'s "Utility Scripts" list, which currently omits every one of them.
- `skill-orchestrator/SKILL.md.archived` and its live twin are **already gone from the source store** (deleted by a dependency task's commit). The only place they still exist is the disposable, gitignored `.claude/` deploy tree — no source-store action is needed; the stale deployed copy self-heals on the next full reload/regenerate.
- The two `core/EXTENSION.md` / `slidev/EXTENSION.md` dead files are confirmed **already deleted** by the EXTENSION.md slim-down dependency, exactly as the task description said to expect — re-verified, not re-decided.
- `sync.lua`'s old glob+allow-list "engine B" (the thing that would have had empty `artifacts.settings/lib/tests` targets) is **already retired** per the file's own header comment; nothing to quarantine there.
- The `.syncprotect` entry `output/implementation-001.md` is confirmed dead (no such file, no "output" artifact category anywhere) and should simply be deleted as a line-level cleanup, not routed through a `deprecated/` directory (it is a root-level config file, not a script/rule artifact).

## Context & Scope

This is task 985's research phase: verify the specific inventory in the task description
(sourced from `specs/reviews/review-2026-07-29-agent-system.md`) against the current repository
state, since the task explicitly warns the sibling reviews undercounted twice and instructs
re-verification of every claim before quarantining anything. No files were modified during this
research pass — every finding below is drawn from live `grep`/`git log`/`jq` inspection of
`agent-system/extensions/**` (the source store), the deployed `.claude/**` tree, and
`lua/neotex/plugins/ai/**`.

Six dependency tasks are declared for 985 (deploy-engine consolidation, EXTENSION.md slim-down,
state-schema rewiring, test-runner wiring, and others). All were confirmed landed during this
pass — see Findings 2–7 below, each of which independently corroborates a piece of the "recent
context" note in the delegation.

## Findings

### Finding 0 — The review's premise about rule-loading is empirically wrong

The review states: *"two rules files are deployed but wired to nothing... `pr-prohibition.md`
(96L, references cslib `/pr` commands not in this deploy) and `project-overview-detection.md`
(28L) are deployed but wired to nothing (`.claude/rules/` is not auto-loaded; only `CLAUDE.md`
`@`-imports pull rules in, and neither is imported)."*

This is false as a general claim about `.claude/rules/`, and directly falsifiable from this very
research session's own context. `.claude/rules/*.md` files carry a YAML frontmatter `paths:`
glob:

```
--- head of each core rule file ---
pr-prohibition.md:                    paths: "**/*"
project-overview-detection.md:        paths: .claude/context/repo/project-overview.md
error-handling.md:                    paths: .claude/**/*
workflows.md:                         paths: .claude/**/*
state-management.md:                  paths: specs/**/*
artifact-formats.md:                  paths: specs/**/*
plan-format-enforcement.md:           paths: specs/**/plans/**
git-workflow.md:                      paths: ["specs/**/*", ".claude/**/*"]
```

Claude Code's harness auto-loads a matching rule file into the session context whenever a
touched/referenced path matches its `paths:` glob — a mechanism completely independent of
`CLAUDE.md`'s `@`-import "Rules References" list. This session is direct proof: `pr-prohibition.md`
(glob `"**/*"`, always matches) and five of the eight `CLAUDE.md`-`@`-imported rules were injected
into this agent's own context unprompted, purely from touching `specs/**` and `.claude/**` paths
during the investigation below; `project-overview-detection.md` (glob restricted to one file) and
`nix.md`/`neovim-lua.md`-style domain rules were selectively included or excluded exactly in
proportion to whether their glob matched a path this session actually touched. `no-task-references-
in-deliverables.md` and `source-store-deploy-boundary.md` are the only two core rules with **no**
YAML frontmatter at all — those two rely purely on the `CLAUDE.md` `@`-import path, which is why
`CLAUDE.md`'s prose correctly labels its list "auto-applied by file path" as a description of the
frontmatter mechanism, even though the list itself is really documenting a curated subset.

`git log -p` confirms `pr-prohibition.md`'s `paths: "**/*"` frontmatter is **not new** — it was
already present in a commit from mid-June 2026, well before the review's 2026-07-29 date. This is
not staleness; it is a factual error in the review's mechanism model, one instance of the "the
sibling reviews undercounted twice" pattern the task description warned about, caught here for a
third time.

**Consequence for triage**: neither rule file is dead. `pr-prohibition.md`'s prohibition on
agent-created PRs/pushes is live and enforced by inclusion on every touch of any path (its glob is
universal); `project-overview-detection.md`'s generic-template detection fires whenever
`project-overview.md` is read. The only accurate residual complaint is narrower than "wired to
nothing": `pr-prohibition.md`'s "CSLib Extension: `/pr` Command" and "`/pr --review`" subsections
describe a command (`/pr`) that does not exist in this deploy (`.claude-extensions.json` shows no
`cslib` extension loaded, and `find .claude/commands -iname pr.md` finds nothing) — inert prose
within an otherwise-live file, not a dead file. Recommend documenting that inertness rather than
quarantining the file itself.

### Finding 1 — 16-script inventory, per-item caller-graph re-verification

Caller-graph method: `grep -rn <basename>` across `agent-system/extensions/**` (all extensions,
not just core) and `lua/neotex/plugins/ai/**`, filtered to exclude the script's own file and its
`manifest.json provides.scripts` declaration line (a manifest entry is necessary for deployment,
never sufficient for liveness).

| Script | Review verdict | Re-verified verdict | Evidence |
|---|---|---|---|
| `install-aliases.sh` | dead, plausibly legit | **keep-with-doc-note** | Zero callers anywhere (expected — it's an opt-in shell-alias installer a user runs by hand); absent from `CLAUDE.md`'s Utility Scripts list |
| `install-systemd-timer.sh` | dead, plausibly legit | **keep-with-doc-note** | Same pattern; installs a systemd timer, invoked manually by an operator |
| `migrate-directory-padding.sh` | dead, plausibly legit | **keep-with-doc-note** | One-shot historical migration tool, run manually once per repo |
| `verify-lean-mcp.sh` | dead (not called out as "plausibly legit" in the review) | **keep-with-doc-note** | Same operator-tool shape as the three above — a manual lean-lsp MCP config diagnostic (`~/.claude.json` scope check) run by hand, not wired into any automated flow. The task description's "plausibly legitimate" bucket named only three scripts; this is a fourth of the same kind, found during re-verification |
| `test-four-tier-conflict.sh` | dead, belongs to test-runner effort | **keep, no action — review claim now STALE** | `agent-system/extensions/core/scripts/tests/run-all.sh` globs `"$ext_scripts"/test-*.sh` (flat, non-`tests/`-subdir files) in every extension; this file lives flat in `scripts/`, so `run-all.sh` auto-discovers and runs it. `run-all.sh` is itself invoked as Gate 8 of `verify-deploy.sh`. Confirmed executable (`-rwxr-xr-x`) |
| `test-session-runtime-files.sh` | dead, belongs to test-runner effort | **keep, no action** | Identical reasoning to the row above — also a flat `scripts/test-*.sh` file, also auto-discovered by the same glob |
| `validate-context-budgets.sh` | dead, consumed by pending context-budget task | **keep, defer — confirmed** | `context-discovery.md:164` itself states the script "is not currently wired"; `specs/state.json` has a `not_started` task ("Reduce the 8 per-agent context budget overruns") whose `file_scope` names this exact script. Genuinely unwired today, but has a real forward consumer — do not quarantine out from under it |
| `check-vault-threshold.sh` | dead (part of vault feature) | **quarantine** | Zero callers; `commands/todo.md` Step 5.7 hand-rolls its own `vault_needed=true` threshold check inline rather than invoking this script |
| `vault-operation.sh` | dead, worst state.json corruption hazard, three divergent implementations | **quarantine — confirmed, with explicit prose-authoritative note** | Zero callers; `commands/todo.md` Steps 5.7–5.8 fully hand-implement vault creation/renumbering/reset (`mkdir`, `mv specs/archive`, `vault_count` bump) without ever invoking this script. Per the task's explicit instruction: quarantine the script and record `commands/todo.md`/`skills/skill-todo/SKILL.md` prose as authoritative — do not attempt to merge or "fix" the script into a caller, since the prose path is already mutex-safer per `context/patterns/task-lock.md`'s own conversion notes |
| `claude-project-cleanup.sh` | dead | **quarantine** | Zero callers. Distinguish carefully from the *live* `claude-cleanup.sh` + `claude-refresh.sh` pair (both invoked by `commands/refresh.md` and `skills/skill-refresh/SKILL.md`, and referenced by `install-aliases.sh`/`install-systemd-timer.sh`) — `claude-project-cleanup.sh` is a same-sounding but functionally distinct, superseded duplicate |
| `lint/lint-contract-compliance.sh` | dead | **wire-in, not quarantine** | Zero current callers, but genuinely non-redundant: it checks hard-mode H-technique contract wiring (agents reference required contracts, all 5 contract files exist, hard skills dispatch to the correct hard agent, `skill-orchestrate-hard` has convergence-policing fields, `general-implementation-hard-agent` has H2 vocabulary, index coverage) — none of which overlaps with `lint-agent-contracts.sh` (frontmatter/no-task-refs), `lint-routing-wiring.sh` (routing manifest wiring), or `lint-postflight-boundary.sh` (postflight section presence), the three lint scripts that already are wired as Gates 6/7/9 of `verify-deploy.sh`. Recommend adding it as a new gate (e.g. Gate 11) rather than quarantining a check with real, uncovered value |
| `orphan-detection.sh` | dead, prose-reimplemented | **quarantine — confirmed** | Zero callers; `commands/todo.md` Step 2.5 ("Detect Orphaned Directories") reimplements the identical two-category orphan scan (`orphaned_in_specs[]` / `orphaned_in_archive[]`) directly in bash-in-markdown |
| `rename-session.sh` | dead | **quarantine** | Zero callers in the Claude Code deploy path. Its own header states it is for "the active OpenCode session in the current TUI instance" and is "a no-op when no OpenCode TUI is running" — it is cross-system utility code sitting in the core scripts directory rather than a Claude-Code-specific dead feature; still zero live callers regardless of system |
| `roadmap-sync.sh` | dead | **quarantine — superseded duplicate, not previously identified as such** | Zero callers. Its own docstring describes a two-phase "scan"/"apply" roadmap-annotation design; `commands/todo.md` Step 3.5 and `skills/skill-todo/SKILL.md` instead call a **different, live script**, `roadmap-integration.sh` (`bash .claude/scripts/roadmap-integration.sh --roadmap ... --state ...`), which does the same scan+annotate job under a similar-but-distinct name. `roadmap-sync.sh` is a dead predecessor, not merely an orphan |
| `validate-extension-index.sh` | dead | **quarantine — superseded duplicate, not previously identified as such** | Zero callers. Its 4-point docstring (JSON structure, path prefixes, cross-system references, path resolution for `index-entries.json`) is now covered by `check-extension-docs.sh`'s Rule T (`check_index_entries_schema`), which validates the same file against `index.schema.json` and **is** wired into `verify-deploy.sh` Gate 3 (doc-lint). `check-extension-docs.sh`'s own comments (around its Rule T section) confirm Rule T was a deliberate migration target, reinforcing that this script is the pre-migration leftover |
| `archive-task.sh` | dead, prose-reimplemented (task item 2) | **quarantine — confirmed** | Zero callers; `commands/todo.md`'s archival steps hand-implement the same behavior in prose. `commands/todo.md:26` mentions the filename only as a naming-convention precedent for session-ID generation ("same self-generating fallback used elsewhere (`manage-topics.sh` / `archive-task.sh`)"), never as an invocation |
| `literature-decode-font-offset.py` (literature extension) | dead | **quarantine** | Zero callers anywhere in `agent-system/extensions/literature/` outside its own `manifest.json` declaration and its own docstring; not imported by either of the two other literature Python scripts (and its hyphenated filename cannot be imported as a Python module regardless — it can only ever run as a CLI subprocess, which nothing does). Candidate for the extension's own existing `scripts/deprecated/` directory, which already documents `zotero-index-add.sh`/`zotero-index-remove.sh` with per-file rationale in the exact format this task should mirror for core |

### Finding 2 — `skill-orchestrator/SKILL.md.archived` twin: already resolved in source, stale only in the disposable deploy tree

`agent-system/extensions/core/skills/skill-orchestrator/` **does not exist** in the source store —
confirmed via `find`. `git log --diff-filter=D` on that path shows a commit titled "phase 7: delete
retired skill-orchestrator files," i.e. a dependency task already deleted both the live `SKILL.md`
and its `.archived` twin from source. The only place either file still exists is the deployed,
gitignored `.claude/skills/skill-orchestrator/` directory (`git check-ignore` confirms it's
ignored), which still holds a byte-identical `SKILL.md` / `SKILL.md.archived` pair left over from
before that deletion propagated. Per the source-store/deploy-boundary rule, `.claude/**` is a
disposable artifact regenerated from source — no source-store edit is needed or possible here; the
stale deployed copy will disappear on the next full `[Reload All]`/`[Regenerate]`. **Recommendation:
no action for 985's edit scope; note in the report that this item is already closed upstream.**

### Finding 3 — `.syncprotect` dead entry and `sync.lua` glob targets: partly dead, partly moot

`.syncprotect` (repo root) lists `output/implementation-001.md` as a protected path. No such file
exists anywhere in the repository, and no "output" artifact category exists in any manifest or in
`lua/neotex/plugins/ai/shared/extensions/*.lua`. This line is dead and should simply be deleted —
`.syncprotect` is a flat root-level protection list, not a script or rule, so it does not fit the
`scripts/deprecated/` + README pattern; a one-line removal (with the removal itself visible in git
history, satisfying "never silently delete" via normal commit provenance) is the right shape.

Separately, `sync.lua`'s own header comment states plainly: *"The former bulk 'Load Core Agent
System' glob+allow-list sync engine that once lived in this module has been retired: bulk
load/resync/regenerate is now handled entirely by the manifest-driven extension loader...
`M.scan_all_artifacts` below is retained as a tested utility... even though its own bulk-sync
caller is gone."* The `artifacts.settings`/`lib`/`tests` empty-glob-target defect the review
flagged belonged to the retired engine; since that engine no longer exists, there is nothing left
to quarantine in `sync.lua` — the file's surviving surface (`M.scan_all_artifacts`, per-artifact
`Ctrl-u` update) is live and tested (`operations/sync_spec.lua`). **Recommendation: delete the
dead `.syncprotect` line; no `sync.lua` action needed.**

### Finding 4 — EXTENSION.md dead files: confirmed already executed, not re-decided

`find` confirms neither `agent-system/extensions/core/EXTENSION.md` nor
`agent-system/extensions/slidev/EXTENSION.md` exists on disk. `check-extension-docs.sh`'s own
source comments (near its Rule T/Rule U section) describe the resolution directly: "core/EXTENSION.md
and slidev/EXTENSION.md were each a 100%... filename-authoritative," i.e. the dependency task
already deleted both files and made the manifest's `merge_targets.claudemd.source` (for core) the
sole authority, with `check-extension-docs.sh` teaching itself the new rule. `core`'s
`merge_targets.claudemd` correctly points at `merge-sources/claudemd.md`; `slidev`'s
`merge_targets` object has no `claudemd` key at all (correct — it never had a claudemd merge
target). **Per the task description's explicit instruction, this item is re-verified only, not
re-decided: confirmed done, no action for 985.**

### Finding 5–7 — Recent-session context, independently corroborated

- `validate-state.sh` exists in `agent-system/extensions/core/scripts/` and is declared in
  `provides.scripts`; `verify-deploy.sh` Gate 10 invokes it (`validate-state.sh --deep`) —
  confirms the state-schema task landed as described.
- `manager.regenerate` (Lua) is defined and called (`lua/neotex/plugins/ai/shared/extensions/init.lua:1141,1223`);
  `settings_backup.backup`/`.restore` are defined and called at `init.lua:1163,1212` — confirms the
  deploy-engine consolidation task wired both, exactly as the task description said it would (out
  of scope for 985 to re-touch).
- `test-four-tier-conflict.sh` and `test-session-runtime-files.sh` are both live via `run-all.sh`'s
  discovery glob (Finding 1 above) — the task description's hint checked out empirically.

## Per-Item Triage Table (consolidated)

| # | Item | Verdict | Action for implementation phase |
|---|---|---|---|
| 1 | `install-aliases.sh` | keep-with-doc-note | Add one-line entry to `CLAUDE.md` Utility Scripts list |
| 2 | `install-systemd-timer.sh` | keep-with-doc-note | Same |
| 3 | `migrate-directory-padding.sh` | keep-with-doc-note | Same |
| 4 | `verify-lean-mcp.sh` | keep-with-doc-note | Same |
| 5 | `test-four-tier-conflict.sh` | keep, no action | None — already wired via `run-all.sh` |
| 6 | `test-session-runtime-files.sh` | keep, no action | None — already wired via `run-all.sh` |
| 7 | `validate-context-budgets.sh` | keep, defer | None — leave for its own consumer task |
| 8 | `check-vault-threshold.sh` | quarantine | Move to `agent-system/extensions/core/scripts/deprecated/`, drop from `provides.scripts`, README rationale line |
| 9 | `vault-operation.sh` | quarantine | Same; README notes `commands/todo.md`/`skills/skill-todo/SKILL.md` prose is authoritative and flags the mutex/renumbering hazards the review cited |
| 10 | `claude-project-cleanup.sh` | quarantine | Same; README notes it's superseded by the live `claude-cleanup.sh` + `claude-refresh.sh` pair |
| 11 | `lint/lint-contract-compliance.sh` | wire-in | Add as a new `verify-deploy.sh` gate; do not quarantine |
| 12 | `orphan-detection.sh` | quarantine | Same pattern as #9; README notes `commands/todo.md` Step 2.5 prose is authoritative |
| 13 | `rename-session.sh` | quarantine | Same; README notes it is OpenCode-only scope, inapplicable to this deploy's Claude Code path |
| 14 | `roadmap-sync.sh` | quarantine | Same; README notes supersession by live `roadmap-integration.sh` |
| 15 | `validate-extension-index.sh` | quarantine | Same; README notes supersession by `check-extension-docs.sh` Rule T |
| 16 | `archive-task.sh` | quarantine | Same pattern as #9/#12; README notes `commands/todo.md` prose is authoritative |
| 17 | `literature-decode-font-offset.py` | quarantine | Move into literature's existing `scripts/deprecated/` (already has the README precedent); drop from literature `manifest.json` |
| 18 | `pr-prohibition.md` (rule) | keep-with-doc-note | Not dead — natively loaded via `paths: "**/*"` frontmatter. Note the CSLib-specific subsections are inert in this deploy; consider clarifying `CLAUDE.md`'s Rules References list is a partial/legacy subset, not the sole loading path |
| 19 | `project-overview-detection.md` (rule) | keep-with-doc-note | Not dead — natively loaded via its narrow `paths:` frontmatter whenever `project-overview.md` is touched. No action needed beyond the same `CLAUDE.md` clarification note |
| 20 | `skill-orchestrator/SKILL.md.archived` (+ live twin) | defer / no action | Already deleted from source store by a dependency task; stale deployed copy self-heals on next reload |
| 21 | `.syncprotect` entry `output/implementation-001.md` | quarantine-equivalent (delete line) | Remove the dead line; not a `deprecated/`-dir candidate (root config file, not a script/rule) |
| 22 | `sync.lua` `artifacts.settings/lib/tests` glob targets | moot / no action | Old glob+allow-list engine already fully retired per the file's own header |
| 23 | `core/EXTENSION.md`, `slidev/EXTENSION.md` | defer / no action | Already deleted by the EXTENSION.md slim-down dependency; re-verified only |

## Decisions

- Treat Finding 0 as load-bearing: do not quarantine either "dead rule." This is the single
  biggest correction to the task's own inventory and changes two items from quarantine to
  keep-with-doc-note.
- Quarantine `archive-task.sh`, `orphan-detection.sh`, and `vault-operation.sh` together, in the
  same commit/PR, with the README explicitly declaring `commands/todo.md` /
  `skills/skill-todo/SKILL.md` prose as the authoritative implementation for all three — per the
  task's explicit instruction not to leave divergent implementations.
- `lint/lint-contract-compliance.sh` should be wired in (new verify-deploy.sh gate), not
  quarantined — it is the one item in the 16-script inventory whose correct disposition is neither
  "dead" nor "legitimate one-shot tool" but "valuable and simply never hooked up."
- `roadmap-sync.sh` and `validate-extension-index.sh` are quarantine candidates for a reason the
  original review inventory did not surface (superseded-by-a-differently-named-live-script) — flag
  this explicitly in the quarantine README so a future dead-code audit doesn't need to
  rediscover it.
- `skill-orchestrator/SKILL.md.archived`, the two `EXTENSION.md` files, and the `sync.lua` glob
  targets require no source-store edits at all for this task — they are already resolved upstream.
  The only remaining edit in that cluster is deleting the one dead `.syncprotect` line.

## Risks & Mitigations

- **Risk**: quarantining `vault-operation.sh`/`check-vault-threshold.sh` without loudly documenting
  the prose-is-authoritative decision could tempt a future contributor to "fix" and re-wire the
  script, resurrecting the unmutexed-write hazard the review correctly flagged. **Mitigation**: the
  quarantine README must state explicitly, per-file, why the prose path is safer (mutex-routed via
  `state-write.sh`) and that reactivating the script requires first closing that gap, not just
  restoring a caller.
- **Risk**: `verify-lean-mcp.sh` and the three original "plausibly legit" operator tools could be
  mistaken for dead code by a shallower future grep pass since they will still show zero callers
  even after documentation. **Mitigation**: the `CLAUDE.md` Utility Scripts doc-note is the
  mitigation — a documented, intentionally-manual entry point is a different disposition than an
  undocumented orphan, and doc-lint tooling (`check-extension-docs.sh`) does not currently fail on
  either category, so there's no enforcement gap being introduced.
- **Risk**: adding `lint-contract-compliance.sh` as a new `verify-deploy.sh` gate could surface
  pre-existing hard-mode contract violations that have accumulated silently since the script was
  never run. **Mitigation**: the implementer should run it standalone first (`--verbose`) and
  triage any findings before wiring it as a blocking gate, exactly as `check-extension-docs.sh`'s
  own Rule T/Rule U migration comment describes doing ("a hard-mode dry run confirmed zero...
  findings" before promotion).

## Context Extension Recommendations

- **Topic**: `.claude/rules/` native frontmatter auto-loading mechanism.
  **Gap**: no context file documents that `.claude/rules/*.md` `paths:` frontmatter is a live,
  harness-native auto-load mechanism independent of `CLAUDE.md`'s `@`-import list — this gap is
  exactly what produced the review's Finding-0 error.
  **Recommendation**: add a short paragraph to `context/patterns/context-discovery.md` (or a new
  `context/architecture/rule-loading.md`) stating the two independent rule-loading paths
  explicitly, so a future dead-code audit checks frontmatter `paths:` before declaring a rule file
  "wired to nothing."

## Appendix

Search methods used: `grep -rn <basename>` (and invocation-shaped variants: `bash .../X`,
`source .../X`, `"X"`, `/X\b`) across `agent-system/extensions/**` and `lua/neotex/plugins/ai/**`;
`jq` queries against `agent-system/extensions/core/manifest.json` and `specs/state.json`;
`git log --diff-filter=D` / `git log -p --follow` for provenance of the `.archived` twin and the
`pr-prohibition.md` frontmatter date; direct `Read` of `run-all.sh`, `verify-deploy.sh`,
`sync.lua`, `check-extension-docs.sh`, `commands/todo.md`, `commands/refresh.md`, and the relevant
rule files' YAML frontmatter.
