# Research Report: Task #978

**Task**: 978 - fix_index_validators_and_line_counts
**Started**: 2026-07-29T22:08:00Z
**Completed**: 2026-07-29T22:49:00Z
**Effort**: Medium (3 defects across 2 scripts, ~320 stale entries across the extension tree)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/**, .claude/**, lua/neotex/plugins/ai/shared/extensions/merge.lua), live script execution, specs/reviews/review-2026-07-29-agent-system.md
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All four claimed defects are confirmed live, empirically, against the current tree — the
  review is **not stale**. `validate-context-index.sh` really does print `Warnings: 0 /
  Validation PASSED` while 58 real line-count warnings scroll past; the numbers (104/164 wrong,
  58 beyond tolerance, 14 orphaned files including a 1103-line `task-lock.md`) reproduce exactly.
- The subshell bug is broader than "warnings only": **four** of the six check blocks
  (path-existence, line-count, domain-validity, deprecated-replacement) pipe `jq` into
  `while read`, discarding `ERRORS`/`WARNINGS` increments from all four, not just the
  line-count one. It happens to manifest as 0 real errors today only because no path/domain/
  deprecated-replacement violations currently exist — the error-side bug is real but dormant.
- `line_count` **is** a genuine downstream budget input, not decorative metadata: an existing
  (but currently unwired) `validate-context-budgets.sh` computes `line_count * 8` as a token
  estimate per agent against hard caps (8000/15000) and fails the gate on overage. Stale/typed
  counts corrupt this budget math in both directions.
- The true scope is larger than the 164-entry deployed index the review inspected: across all
  19 extensions' **source** `index-entries.json` (444 entries total), 226 have a numeric
  mismatch against `wc -l` and 94 (in cslib, latex, lean, python, typst, z3 — currently unloaded
  extensions) have `line_count: null` outright. 72% of all source entries need correction.
- The right wiring point for both a line-count regenerator/gate and the new index-orphan gate is
  **`check-extension-docs.sh`** (already invoked as gate 3 of `verify-deploy.sh`), extending its
  existing lettered-rule / `orphan_report()` / `ORPHAN_GATE_MODE` framework — not a new
  `verify-deploy.sh` gate. `validate-context-index.sh` itself is presently invoked by nothing
  automated; it is a manual tool only referenced from a docs guide.
- 10 of 14 currently-orphaned context files are already reachable via hardcoded `@`-references
  in specific agents/skills (so "unreachable by any agent" overstates it for those), but none of
  the 14 has a source-level `index-entries.json` entry in any extension — the gap is at the
  source, not a deploy-time drop. Recommendation for all 14: index, none warrant exclusion.
- The task description's "literature ... strays" does not currently exist: the `literature`
  extension is not loaded in this repo's `.claude-extensions.json` (only `core`, `email`,
  `memory`, `nix`, `nvim` are `active`), so it has zero deployed context files and zero orphans.
  Treat that phrase as describing a different/earlier snapshot; the live orphan set is 11 core +
  email + memory + nvim (3 extension strays), not 4 extension categories.

## Context & Scope

Verified each of the four claimed defects in `validate-context-index.sh` (source at
`agent-system/extensions/core/scripts/validate-context-index.sh`, deployed at
`.claude/scripts/validate-context-index.sh`) and `check-extension-docs.sh` against the live,
currently-deployed `.claude/` tree, plus the full source store across all 19 extensions
(`agent-system/extensions/*/index-entries.json`). No code was changed — this is empirical
verification and design-input gathering only, per the research focus.

## Findings

### Defect 1: the subshell bug — confirmed, and broader than stated

`validate-context-index.sh` lines 75, 97, 121, 132 all pipe `jq -r ... | while IFS=... read`.
Because the `while` is the last stage of a pipeline, bash runs it in a subshell; every
`ERRORS=$((ERRORS+1))` / `WARNINGS=$((WARNINGS+1))` inside those four blocks is invisible to the
parent shell. Only the "Checking entry fields" block (lines 84-93, a C-style `for` loop, not a
pipe) correctly updates the counters.

Live run against the current deployed index:

```
$ bash .claude/scripts/validate-context-index.sh 2>&1 | grep -c '^\[WARN\]'
58
$ bash .claude/scripts/validate-context-index.sh 2>&1 | tail -6
=== Validation Summary ===
Entries checked: 164
Errors: 0
Warnings: 0
Validation PASSED
```

58 printed warnings, reported total 0 — matches the review exactly. Additionally:

- **104 of 164** deployed entries have `line_count` that does not exactly equal `wc -l` (58 of
  those exceed the validator's own >10%-or-10-line tolerance and are the 58 warnings above).
- The **path-existence** (line 75), **domain-validity** (line 121), and **deprecated-replacement**
  (line 132) checks have the identical structural bug and would silently swallow real `ERRORS`
  today if any existed. None currently do (0 `[ERROR]` lines print), so this part of the bug is
  real but not currently visibly masking anything — worth fixing in the same pass since it's the
  same one-line structural cause (process substitution / temp-file count), not a second defect.
- Recommendation: fix via `< <(jq ...)` process substitution (keeps the loop in the current
  shell) for all four blocks, and decide error-vs-warning promotion for line-count
  beyond-tolerance mismatches as part of the same change — the task description leaves this open;
  given `line_count` is a real budget input (see Defect 2 below), promoting "exceeds tolerance"
  to a hard error (not just a warning) is defensible, but is a planning decision, not a research
  finding.

### Defect 2: `line_count` is hand-typed and does have a real downstream consumer

`line_count` is typed by hand in each extension's *source* `agent-system/extensions/<ext>/
index-entries.json` (confirmed: e.g. `project/neovim/README.md` is declared `80` in
`agent-system/extensions/nvim/index-entries.json`, actual `wc -l` is 96) and copied verbatim
into the deployed `.claude/context/index.json` by `M.append_index_entries` in
`lua/neotex/plugins/ai/shared/extensions/merge.lua` (lines 496-542) — a straight per-extension
append/dedupe-by-path, no recomputation, no `version`/`generated` stamp written (confirms Defect
4; see below).

**Does anything budget on it?** Yes. `agent-system/extensions/core/scripts/
validate-context-budgets.sh` (deployed at `.claude/scripts/validate-context-budgets.sh`) reads
`.claude/context/index.json` and computes, per agent, `total_tokens = sum(line_count) * 8`
against hard caps (`general-research-agent`: 8000, `meta-builder-agent`/`planner-agent`: 15000,
etc.), failing (`exit 1`) on overage. This is a real, if currently badly-out-of-date and
**unwired**, consumer — live run today reports 11 violations (e.g. `meta-builder-agent` computed
at 115512 tokens against a 15000 cap), independent of this task and not something to fix here,
but it demonstrates `line_count` accuracy is not cosmetic: it directly feeds a token-budget
enforcement calculation that a future gate promotion could rely on. `CLAUDE.md`'s own documented
`jq` query pattern for "Get line counts for budget calculation" corroborates this intended use.
`validate-context-budgets.sh` is **not** called by `verify-deploy.sh` or any other automated
gate today — it exists only as a manifest-deployed manual script, same status as
`validate-context-index.sh`.

**True scope, source-level, all 19 extensions** (444 entries total, not just the 164 currently
deployed from the 5 currently-loaded extensions core/email/memory/nix/nvim):

| Category | Count | % of 444 |
|---|---|---|
| Exact match (no action needed) | 124 | 28% |
| Numeric mismatch vs `wc -l` | 226 | 51% |
| `line_count: null` (cslib, latex, lean, python, typst, z3 — all-null, 100% of each extension's entries) | 94 | 21% |
| Source file missing | 0 | 0% |

The 6 all-null extensions are currently unloaded, so their entries never reach the deployed
index and the validator has never been run against them — but a `line_count: null` entry would
trip `jq -e ".entries[$i].line_count"` (exit 1 on `null`) in the *already-correct* C-style
"Checking entry fields" loop (lines 84-93) and correctly report a real missing-field `ERROR` the
first time one of those extensions is loaded and validated. The generator must handle `null`
uniformly with numeric-mismatch (both become "recompute from `wc -l`"), not as a special case.

**Regeneration must target the source, not just the deployed copy.** Because `.claude/` is a
disposable deploy artifact regenerated from `agent-system/extensions/**` (source-store/deploy
boundary rule), a `--fix` that only rewrites `.claude/context/index.json` would be silently
undone on the next "Load Core"/redeploy. The generator needs to iterate
`agent-system/extensions/*/index-entries.json`, recompute each entry's `line_count` from
`wc -l` against that extension's own `agent-system/extensions/<ext>/context/<path>` source tree,
and rewrite the source JSON in place (the same `$EXT_DIR="$REPO_ROOT/agent-system/extensions"`
pattern `check-extension-docs.sh` already uses).

`validate-context-index.sh`'s existing `--fix` flag (line 28-30) is presently a no-op stub — it
only prints `"  Would fix to: $actual"` (line 113) and never writes anything (the comment at
line 112 says so explicitly: "Note: Fixing would require modifying index.json"). This confirms
the task description's premise that no regenerator currently exists in any form.

### Defect 3: no script diffs deployed context files against index entries — confirmed

`check-extension-docs.sh`'s `check_context_orphans` (Rule L, lines 956-1005) diffs each
extension's `manifest.json` `provides.context` declarations against files on disk under
`.claude/context/` — the direction is "does every deployed file trace to a declared source",
never "does every deployed/declared file have an *index* entry." No script anywhere performs
the disk-vs-index (or source-vs-index) diff the task asks for.

Live orphan enumeration (deployed `.claude/context/*.md` vs. `.claude/context/index.json`
entries, current 5-extension-loaded state):

```
comm -23 <deployed .md files> <indexed paths>
```
produced exactly 14 files:

**11 core** (all zero source-level `index-entries.json` entries in any extension — confirmed by
grepping every `agent-system/extensions/*/index-entries.json` for each path; the gap is at the
source, not deploy-time):
`guides/hard-mode-routing.md`, `patterns/batch-drain-loop.md`,
`patterns/checkpoint-before-overflow.md`, `patterns/context-exhaustion-detection.md`,
`patterns/context-protective-lead.md`, `patterns/lit-stage4a-flow.md`,
`patterns/subagent-continuation-loop.md`, `patterns/task-lock.md` (1103 lines, the single
largest deployed context file), `patterns/topic-assignment-pattern.md`,
`standards/git-staging-scope.md`, `standards/orchestrator-runtime-files.md`.
Sum of these 11 files' line counts: **3243** — matches the review's "3,243 lines of authored
core context ... absent from the index" exactly.

**3 extension strays**: `project/email/design/email-to-memory-preferences.md` (email),
`project/memory/README.md` (memory), `project/neovim/domain/extension-deploy-modes.md` (nvim).

**No literature stray exists currently** — `literature` is not in the `active` set of
`.claude-extensions.json` (only `core`, `email`, `memory`, `nix`, `nvim` show
`"status": "active"`), so it deploys zero context files and has zero orphans. The task
description's "literature/email/memory/nvim strays" phrasing does not match the live state;
treat it as stale/imprecise rather than a fourth live category. `nix` itself has **zero**
orphans (its deployed context exactly matches its index entries) despite being loaded.

**Reachability nuance** (matters for the "unreachable by any agent" framing, and for deciding
`load_when` metadata once indexed): of the 14 orphans, 9 are already loaded today via hardcoded
`@context/...` references inside specific agent/skill/rule files, even without an index entry —
they are reachable by the agents/skills that already know to reference them, just not
discoverable via the index's dynamic `load_when` query mechanism by anyone else. Only 5 have
**zero** references anywhere (neither index nor `@`-reference) and are genuinely dead-reachable
today: `guides/hard-mode-routing.md`, `patterns/batch-drain-loop.md`,
`patterns/context-protective-lead.md`, `project/memory/README.md`,
`project/neovim/domain/extension-deploy-modes.md`. All 5 were read and contain real, current,
non-stale content (not candidates for deletion) — recommend indexing all 5. For the other 9,
recommend indexing too (for index-based discoverability by agents that don't have the hardcoded
reference) using the existing referencing agents/skills/commands as a starting point for
`load_when.agents`/`load_when.skills`/`load_when.commands`:

| Orphan | Existing `@`-referencing files (informs `load_when`) |
|---|---|
| `patterns/checkpoint-before-overflow.md` | general-research-agent, general-research-hard-agent, general-implementation-agent, general-implementation-hard-agent |
| `patterns/context-exhaustion-detection.md` | same 4 agents + skill-implementer |
| `patterns/lit-stage4a-flow.md` | skill-planner, skill-researcher, skill-planner-hard, skill-researcher-hard, skill-implementer-hard, skill-implementer |
| `patterns/subagent-continuation-loop.md` | general-implementation-agent, general-implementation-hard-agent, skill-implementer, skill-implementer-hard, skill-orchestrate |
| `patterns/task-lock.md` | general-implementation-agent, skill-refresh, skill-orchestrate-hard, skill-orchestrate, skill-implementer, commands/research.md, commands/refresh.md, commands/plan.md, commands/implement.md, commands/orchestrate.md |
| `patterns/topic-assignment-pattern.md` | skill-fix-it, skill-project-overview, meta-builder-agent, skill-spawn, skill-todo, commands/task.md, commands/review.md |
| `standards/git-staging-scope.md` | 17 files — the most widely `@`-referenced of the 14 (git-workflow.md, most implementation agents/skills, several commands) |
| `standards/orchestrator-runtime-files.md` | skill-refresh, skill-orchestrate-hard, commands/refresh.md, skill-orchestrate |
| `project/email/design/email-to-memory-preferences.md` | skill-learn, skill-email-cleanup |

**Recommended wiring point**: extend `check-extension-docs.sh` with a new project-wide rule
(next letter after Q, called after `check_context_orphans` around line 1080-1082), reusing the
identical infrastructure — `$EXT_DIR` iteration, `orphan_report()`, and either the existing
`ORPHAN_GATE_MODE` or (recommended, since this is a materially different check with its own
remediation timeline) a sibling severity variable — comparing `git ls-files
.claude/context` (already available via the existing `_git_deployed_files` helper) against the
deployed `.claude/context/index.json` entry paths. This automatically flows through
`verify-deploy.sh` gate 3 (`check-extension-docs.sh --quiet`) with no changes needed to
`verify-deploy.sh` itself, since gate 3 already invokes the full script. `check-extension-docs.sh`
currently passes cleanly (`PASS: all extensions OK`, all 19 extensions + project-wide) — adding
a new rule in `hard` mode immediately would break this baseline until the 14 orphans are
resolved, so (mirroring the established Rule J-Q precedent from prior orphan-check additions)
the plan should either land the gate and the 14 new index entries in the same phase, or land the
gate first in `advisory` mode and promote to `hard` in a follow-up phase once entries exist —
this is a planning decision, not a research finding, but the precedent for the two-phase
approach already exists in this same script (`ORPHAN_GATE_MODE`'s own advisory→hard promotion
history is documented in its surrounding comment, lines 875-887).

Note: the line-count generator/gate (Defect 2) is a distinct check from the index-orphan gate —
it is not covered by `check_context_orphans` at all (that rule never inspects `line_count`) — so
it should be a **separate** new rule in the same file, not folded into the orphan rule, comparing
each extension's `index-entries.json` `line_count` against `wc -l` of the corresponding
`agent-system/extensions/<ext>/context/<path>` source file (source-level, catching the 94 null
entries in unloaded extensions too, not just deployed-index drift).

### Defect 4: no version/generated stamp — confirmed

`.claude/context/index.schema.json` (deployed from `agent-system/extensions/core/context/
index.schema.json`) declares `$schema`, `entries`, `generated` (ISO8601 date-time), and
`version` (semver) as top-level properties. The live deployed `.claude/context/index.json` has
only the `entries` key (`jq keys` → `["entries"]`). `validate-context-index.sh` itself
documents why at lines 63-65: "version and generated are optional -- the loader (merge.lua)
does not write them." Confirmed in `merge.lua`'s `M.append_index_entries` (lines 501-542): it
reads-or-creates `{ entries = {} }`, appends, and writes back — no `version`/`generated` field
is ever set. Fixing this is a small, isolated change to `append_index_entries` (or a post-merge
step) to stamp `generated` with the current timestamp on every write and set/bump `version` —
straightforward, no wiring-point ambiguity like Defects 2-3 have.

### Not part of this task, but observed for context

`validate-context-budgets.sh`, independent of `line_count` accuracy, is itself unwired (not
called by `verify-deploy.sh`) and its current output is already badly failing for reasons
unrelated to this task (all 164 entries missing a `tier` field, 3 "dead entry" violations,
11 of 11 checked agents over budget) — this looks like a stale/parked validator from an earlier
context-tiering initiative that never finished landing. Out of scope for task 978, but worth
flagging for planning: if `line_count` accuracy improves, this script's failure count will
change (likely worsen, since several deployed placeholders are undercounts), which is a
legitimate and expected side effect, not a regression to chase down in this task.

## Decisions

- Confirmed all four defects as described; no evidence the review is stale for this section.
- The subshell bug affects error-reporting too, not only warnings (dormant today, same root
  cause, recommend fixing in the same edit).
- The regenerator/gate must operate on the **source** `agent-system/extensions/*/index-entries.json`
  files (444 entries, all 19 extensions), not only the 164 currently-deployed entries from the
  5 loaded extensions — the review's numbers describe the deployed subset only.
- The index-orphan gate and the line-count gate are two separate new rules, both best added to
  `check-extension-docs.sh` (already wired as `verify-deploy.sh` gate 3), not to
  `validate-context-index.sh` (currently invoked by nothing automated) and not as a new
  `verify-deploy.sh` gate.
- Literature is not currently a live orphan category; treat the task description's mention of it
  as describing a different snapshot, not a live requirement.

## Risks & Mitigations

- **Promoting a new rule straight to "hard"/FAIL mode will break the currently-clean
  `check-extension-docs.sh` baseline** until the 14 orphans are indexed and 320 line_count values
  are corrected. Mitigation: land the index entries/regeneration in the same phase as the gate,
  or use an advisory→hard two-phase rollout matching the existing `ORPHAN_GATE_MODE` precedent.
- **Regenerating `line_count` across 19 extensions touches files outside this task's 5
  currently-loaded extensions** (cslib, formal, founder, latex, lean, present, python, slidev,
  typst, web, z3, epidemiology, filetypes, literature) — a broad diff. Mitigation: this is
  mechanical (every value becomes `wc -l` of its own file, no judgment calls) and independently
  verifiable per-file; consider running the generator as its own commit separate from the
  gate-wiring commit for easier review.
- **Two-phase advisory promotion adds a phase but avoids an immediate hard-fail regression** —
  the plan should decide explicitly which approach to take; both are viable given the precedent.

## Context Extension Recommendations

- **Topic**: line_count accuracy / token budget enforcement relationship.
  **Gap**: `context-discovery.md` documents the `jq` query for "budget calculation" but nothing
  documents that `validate-context-budgets.sh` is the actual (currently unwired) consumer, or
  that it depends on `line_count` accuracy.
  **Recommendation**: once this task's line-count fix lands, consider a short note in
  `context/patterns/context-discovery.md` or a new standards doc cross-referencing
  `validate-context-budgets.sh` explicitly, and a decision on whether to wire it into
  `verify-deploy.sh` in a follow-up task (out of scope here).

## Appendix

### Commands used

```bash
bash .claude/scripts/validate-context-index.sh 2>&1 | tail -6
bash .claude/scripts/validate-context-index.sh 2>&1 | grep -c '^[WARN]'
jq -r '.entries[] | "\(.path)\t\(.line_count)"' .claude/context/index.json | while IFS=$'\t' read -r path expected; do ... done  # exact-match mismatch count = 104
find .claude/context -name "*.md" -type f | sed 's|.claude/context/||' | sort > deployed_files.txt
jq -r '.entries[].path' .claude/context/index.json | sort > indexed_paths.txt
comm -23 deployed_files.txt indexed_paths.txt   # 14 orphans
comm -13 deployed_files.txt indexed_paths.txt   # 6 non-.md index entries (schemas/templates), not orphans
grep -rl "context/$f" .claude/agents .claude/skills .claude/commands .claude/rules  # @-reference reachability check
jq '.extensions | to_entries[] | "\(.key): \(.value.status)"' .claude-extensions.json   # confirms literature not loaded
bash .claude/scripts/validate-context-budgets.sh 2>&1 | head -40
bash .claude/scripts/check-extension-docs.sh --quiet 2>&1 | tail -20   # baseline: PASS, all extensions
# full 444-entry source-level scan across agent-system/extensions/*/index-entries.json
```

### References

- `agent-system/extensions/core/scripts/validate-context-index.sh`
- `agent-system/extensions/core/scripts/validate-context-budgets.sh`
- `agent-system/extensions/core/scripts/check-extension-docs.sh` (lines 875-1005, 1074-1083)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (gates 0-4, line 193-224 for gate 3)
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` (lines 496-542, `M.append_index_entries`)
- `agent-system/extensions/core/context/index.schema.json`
- `specs/reviews/review-2026-07-29-agent-system.md` (lines 44, 89, 158-163)
- `.claude-extensions.json` (loaded-extension state)
