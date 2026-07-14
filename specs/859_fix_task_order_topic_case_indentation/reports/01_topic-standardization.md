# Research Report: Task #859

**Task**: 859 - Fix generate-task-order.sh: dependency tree renders flat for non-lowercase topic strings (topic-key case mismatch)
**Started**: 2026-07-14T15:44:41Z
**Completed**: 2026-07-14T16:20:00Z
**Effort**: low (origin bug) / medium (full topic-standardization mandate)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.claude/extensions/core/scripts/generate-task-order.sh`, `.claude/scripts/generate-task-order.sh`, `.claude/scripts/generate-todo.sh`, `.claude/scripts/manage-topics.sh`, `.opencode/scripts/generate-task-order.sh`
- Task-creation paths: `.claude/commands/task.md`, `.claude/commands/meta.md`, `.claude/agents/meta-builder-agent.md`, `.claude/skills/skill-meta/SKILL.md`, `.claude/skills/skill-spawn/SKILL.md`, `.claude/skills/skill-fix-it/SKILL.md`, `.claude/skills/skill-project-overview/SKILL.md`, `.claude/commands/review.md`, `.claude/commands/errors.md`
- Pattern/schema docs: `.claude/context/patterns/topic-assignment-pattern.md`, `.claude/rules/state-management.md`, `.claude/context/reference/state-management-schema.md`, `.claude/docs/reference/standards/multi-task-creation-standard.md`
- `.opencode/` mirror: `.opencode/commands/task.md`, `.opencode/scripts/generate-task-order.sh` (no `.opencode/scripts/manage-topics.sh` or `.opencode/context/patterns/topic-assignment-pattern.md` exist)
- Data: `specs/state.json` (`active_topics`, per-task `topic` fields), `specs/TODO.md` (live rendered output)
**Artifacts**: `specs/859_fix_task_order_topic_case_indentation/reports/01_topic-standardization.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The origin bug is real and precisely as described: `generate-task-order.sh` groups topics
  under a lowercased key but compares that key against **raw, unnormalized** topic strings in
  two guards (core extension script lines 553 and 578; mirrored in `.opencode/scripts/generate-task-order.sh`
  lines 481 and 506), which collapses the tree for any topic containing an uppercase character.
- A much larger system — mandatory topic assignment with interactive `AskUserQuestion` prompting
  across nearly every task-creation path — **already exists**, built by a prior task (referenced
  internally as "task 796") and documented in `.claude/context/patterns/topic-assignment-pattern.md`.
  This already satisfies mandate items 1 and 2 (always-assigned topic, interactive fallback) for
  `/task` create/expand/recover, `/meta`, `/spawn`, `/review`, `/fix-it`, `/project-overview`, and
  `/errors` (which delegates to `/task`).
- What is genuinely missing is mandate item 3: **no canonical form is enforced or normalized
  anywhere**. `manage-topics.sh` does exact case-sensitive string comparison with zero
  normalization; the interactive free-text prompt only shows a *hint string* ("lowercase,
  kebab-case, e.g. 'agent-system'") with no validation. This is the structural root cause that
  makes the origin bug possible and creates a live duplicate-heading risk (`Modal Logic` vs
  `modal-logic` vs `modal logic` would each become a distinct topic key).
- Mandate item 2's autonomous-context question ("how should `/orchestrate` behave") has **no
  answer implemented anywhere** in the topic system — unlike the well-designed `--lit` flag's
  `AUTONOMOUS_GLOBAL` deterministic-default pattern, none of `topic-assignment-pattern.md` or its
  callers (`skill-spawn`, `skill-fix-it`, `/review`) reference `orchestrator_mode` at all. This is
  currently latent (no autonomous caller invokes Mode A today — `skill-orchestrate` never
  dispatches `spawn-agent` directly), but is an unaddressed design gap the mandate explicitly asks
  about.
- The canonical schema docs (`state-management-schema.md`, `state-management.md`) do not document
  the `topic` field or the top-level `active_topics` array at all, despite both being mandatory
  and load-bearing since the prior task.
- `.opencode/` parity is much worse than the two-line renderer bug suggests: `.opencode/`
  has **no** `manage-topics.sh`, **no** `topic-assignment-pattern.md`, and `.opencode/commands/task.md`
  has zero topic-assignment logic — even though `.opencode/scripts/generate-task-order.sh` already
  contains the topic-grouping *renderer* code (`load_topics`, `task_topic`, `active_topics_order`)
  that expects a topic system nothing on the OpenCode side populates.
- In this repository's own `specs/state.json`, existing `active_topics` values are already
  clean (`agent-system`, `neovim`, `cslib`, `extensions`, `literature`, `wezterm-notifications`,
  `workflow-refactor` — all lowercase kebab-case), so **no migration is needed here**; the
  collision was observed in a sibling repository (`Projects/cslib`) where Title-Case and
  kebab-case values coexisted. The fix must land in the shared core extension source so all
  repositories benefit.

## Context & Scope

Task 859 was filed narrowly (a case-sensitivity bug in `generate-task-order.sh`'s topic-grouped
tree renderer) but the operator has expanded the mandate to a full audit of topic handling across
the agent system: schema, every write path, every read/render path, the desired canonical form,
interactive-prompting integration (including autonomous contexts), and `.opencode/` parity —
while explicitly asking for the smallest, most uniform fix rather than new scattered logic.

This report covers, with file:line grounding for every claim:
1. The origin bug (confirmed, both `.claude/` and `.opencode/`).
2. The complete current state of topic write paths (already extensive — a "task 796" system).
3. The complete current state of topic read/render paths (all lack normalization).
4. Schema/documentation gaps.
5. The canonical-form and autonomous-context gaps the mandate specifically asks about.
6. A concrete, minimal recommendation.

## Findings

### 1. The origin bug — confirmed with line numbers

`.claude/extensions/core/scripts/generate-task-order.sh` (source of truth; the deployed
`.claude/scripts/generate-task-order.sh` is a near-identical regenerated copy — the only diff
found was a cosmetic `declare -a all_task_nums=()` vs `declare -a all_task_nums`):

- `generate_grouped_section()` builds the rendered topic key by lowercasing the raw topic
  (`local t_key="${t,,}"` at line 430; `local tp_key="${tp,,}"` at line 441; membership test
  `[[ "${tp,,}" == "$topic" ]]` at line 456), then sets the tracking global
  `_current_section_topic="$topic"` at line 470 — always lowercased.
- `_print_topic_node()` (the recursive DFS printer) compares that lowercased global against the
  **raw** `task_topic[]` value in two places without lowercasing the right-hand side:
  - Line 553: `local task_topic_val="${task_topic[$task_num]:-}"` then
    `if [[ -n "$task_topic_val" && "$task_topic_val" != "$_current_section_topic" ]]` — used for
    the "already visited elsewhere, is it cross-topic?" annotation.
  - Line 578: `local dep_topic="${task_topic[$dep]:-}"` then
    `if [[ -n "$_current_section_topic" && -n "$dep_topic" && "$dep_topic" != "$_current_section_topic" ]]; then continue; fi`
    — the successor-skip guard that decides whether a child task renders indented under its parent.
- For a topic stored as `"Modal Logic"`, `_current_section_topic` is `"modal logic"` but
  `dep_topic`/`task_topic_val` remain `"Modal Logic"`, so line 578's `continue` fires for every
  successor and the tree collapses to a flat list — exactly as the task description states.
- `.opencode/scripts/generate-task-order.sh` has the **identical** unguarded comparisons at line
  481 (`task_topic_val` guard) and line 506 (`dep_topic` guard) — confirmed by direct read, no
  `.opencode/extensions/core/scripts/generate-task-order.sh` source-of-truth file exists (the
  OpenCode core extension does not have a scripts mirror at that path; `.opencode/scripts/` is
  the only copy), so the OpenCode fix must be applied directly to `.opencode/scripts/generate-task-order.sh`.

The topic **heading** itself (line 461-463:
`heading=$(echo "$topic" | sed 's/-/ /g; s/\b\(.\)/\u\1/g')`) already Title-Cases and
hyphen-to-space-converts the lowercased key for display, so headings always look uniform
regardless of storage casing — the display layer already assumes a normalize-then-render model;
only the two comparison guards were left comparing raw strings.

### 2. Topic write paths — already comprehensive (built by a prior task)

Contrary to an assumption that topic is scattered and ad hoc, `.claude/context/patterns/topic-assignment-pattern.md`
documents a **already-implemented**, centralized three-mode system, explicitly citing a prior task's
plan (`specs/796_mandatory_topic_assignment/plans/01_mandatory-topic-assignment.md`) for the
"no Skip option, ever, except one carve-out" rationale:

| Mode | Used by | Verified in this research |
|------|---------|---------------------------|
| **A: Interactive** (`AskUserQuestion` picker: existing topics + "New topic...", no Skip) | `/task` create (`.claude/commands/task.md` Step 4.5, lines 189-223), `/task --sync` backfill (lines 447-480, the ONE labeled "Defer" exception), `/meta` Interview Stage 4.5 "AssignTopic" (`.claude/agents/meta-builder-agent.md` lines 577-586) | Confirmed present and wired to `manage-topics.sh add`/`set` in all three |
| **B: Inherit** (silently copy parent topic; falls back to Mode A if parent has none) | `/task --expand` (task.md lines 353-392), `/task --recover` (lines 273-314), `/spawn` (`.claude/skills/skill-spawn/SKILL.md` lines 58-86, 439-449) | Confirmed; all three read `.topic // ""` from the parent and fall back to the Mode A picker |
| **C: Suggest** (path-heuristic guess, confirm-wrapped; falls back to Mode A batch variant if the heuristic misses) | `/review` (`.claude/commands/review.md` lines 519-582), `/fix-it` (`.claude/skills/skill-fix-it/SKILL.md` line 469+) | Confirmed; both use the same 3-bucket path heuristic (`.claude/`/`specs/` -> `agent-system`, `lua/`/`after/` -> `neovim`, `home/`/`modules/` -> `nix-config`, else -> Mode A fallback) |
| N/A — delegates | `/errors` | `.claude/commands/errors.md` line 131: "Tasks are created via the `/task` command, which handles topic detection... internally... No separate `active_topics` update is needed here." Confirmed: `/errors` invokes `/task "..."` directly rather than writing state.json itself, so it inherits Mode A automatically. |
| Full Mode A | `/project-overview` | `.claude/skills/skill-project-overview/SKILL.md` lines 362-417: identical Mode A picker, `manage-topics.sh set` call. |

All state mutation funnels through `.claude/scripts/manage-topics.sh` (`list`/`add`/`set`/`validate`
subcommands, tmp-file atomic write, exit codes 0-4), which is the single write chokepoint —
this is already the "one helper reused everywhere" pattern the mandate asks for, for
*state mutation*. It is not, however, a normalization chokepoint (see Finding 3).

**Conclusion for mandate items 1 and 2**: both are essentially solved already for every
interactive/human-in-the-loop task-creation path in `.claude/`. The remaining gap for item 2 is
autonomous-context behavior (Finding 5), not the interactive mechanism itself.

### 3. Topic read/render paths — zero normalization anywhere

Three independent consumers read the raw `topic` string, and none of them normalize:

- `generate-task-order.sh` (`load_topics()`, core extension lines 268-290): loads
  `task_topic["$tn"]="${topic}"` verbatim from `jq -r ... "\(.project_number)|\(.topic // "")"`.
  Grouping/heading logic lowercases on the fly (Finding 1) but the two buggy comparisons don't.
- `generate-todo.sh` (`.claude/scripts/generate-todo.sh` line 172, 187, 223-224): renders
  `- **Topic**: %s` verbatim from `jq -r '.topic'` with no case/separator transformation.
- `manage-topics.sh` `add`/`set`/`validate` (lines 73-78, 120-126, 151-153): all use `jq --arg t "$TOPIC" ... index($t)`,
  which is an **exact, case-sensitive string match**. Two different-cased or different-separator
  spellings of "the same" topic are treated as two unrelated topics, both silently accepted into
  `active_topics`.

This confirms the mandate's core diagnosis: there is no single normalization function; each
consumer either half-normalizes locally (the renderer's lowercased grouping key, which itself
doesn't collapse `-`/space variants — see the task description's "RELATED REFINEMENT") or does
nothing at all (`manage-topics.sh`, `generate-todo.sh`).

### 4. Canonical-form guidance exists only as a UI hint string, never enforced

Every Mode A free-text prompt across all callers uses the identical hint text:
`"Enter new topic name (lowercase, kebab-case, e.g. 'agent-system')"` (e.g.
`topic-assignment-pattern.md` line 87-89; `skill-project-overview/SKILL.md` line 388;
`.claude/commands/review.md` line 550). This establishes **kebab-case, all-lowercase** as the
already-intended canonical form by convention — it is not a new decision this report needs to
invent, just one that needs to move from "hint text" to "enforced normalization." The validation
that does exist ("non-empty, no spaces (suggest replacing with hyphens)") is advisory, not a hard
reject/normalize step — nothing lowercases or hyphenates the value before it reaches
`manage-topics.sh set`.

### 5. No autonomous-context (`/orchestrate`) fallback anywhere in the topic system

`topic-assignment-pattern.md` and every one of its Mode A/B/C callers (`skill-spawn/SKILL.md`,
`skill-fix-it/SKILL.md`, `.claude/commands/review.md`) were grepped for `orchestrator_mode` and
`autonomous`: zero matches. This is a striking contrast with the `--lit` flag's
`literature-lit-flag-resolve.sh` design (documented in this repo's own root `.claude/CLAUDE.md`),
which has an explicit `AUTONOMOUS_GLOBAL` directive — a deterministic default plus a visible
`[lit:auto]` notice — specifically because `AskUserQuestion` cannot prompt a human when
`orchestrator_mode == true`. No equivalent directive exists for topic assignment.

Currently this is **latent, not active**: `.claude/skills/skill-orchestrate/SKILL.md` and
`skill-orchestrate-hard/SKILL.md` were grepped for `spawn-agent` (the agent Mode B's `/spawn`
dispatches to) — zero matches. `/orchestrate`'s only "blocker" handling path (lines ~460-470 of
`skill-orchestrate/SKILL.md`) is a research-only `fork` dispatch to investigate the blocker, not
an actual `/spawn`-skill invocation that would hit the topic picker. So no currently-wired
autonomous flow can hang on an `AskUserQuestion` topic prompt today. But the mandate explicitly
asks "how those should behave," and the honest answer is: **undefined** — if `/spawn`,
`/fix-it`, or `/review` are ever invoked from a genuinely non-interactive context in the future,
Mode A/B/C fallback would attempt to prompt a human that isn't there.

### 6. Schema documentation gap

`.claude/context/reference/state-management-schema.md` (405 lines, the canonical field-by-field
reference `.claude/rules/state-management.md` line 85 points to for "complete field schemas")
contains zero mentions of `topic` or `active_topics` — the "state.json Full Structure" example
JSON (lines 6-33) and the "Project Entry Fields" table (lines 60-72) omit both entirely, despite
`topic` being a mandatory field on every task since the prior mandatory-assignment task and
`active_topics` being a required top-level array consumed by `manage-topics.sh`,
`generate-task-order.sh`, and every Mode A picker's option list.

### 7. `.opencode/` parity — worse than the task description implies

The task description asks only to mirror the two-line renderer fix to
`.opencode/scripts/generate-task-order.sh` (confirmed necessary and correctly line-numbered,
Finding 1). But the parity gap is structurally deeper:

- `.opencode/scripts/manage-topics.sh` does not exist (searched; not found anywhere under `.opencode/`).
- `.opencode/context/patterns/topic-assignment-pattern.md` does not exist.
- `.opencode/commands/task.md` has zero occurrences of the string `topic` — meaning OpenCode's
  `/task` command has no topic-assignment step of any kind, mandatory or optional.
- Yet `.opencode/scripts/generate-task-order.sh` **already contains** the full topic-grouping
  renderer (`load_topics()`, `task_topic[]`, `active_topics_order[]`, `generate_grouped_section()`
  equivalents) — i.e., OpenCode's renderer was kept in sync with `.claude/`'s renderer, but the
  upstream write-side system (task 796's mandatory-assignment work) was never ported. Any
  OpenCode-created task today gets `topic: null`/absent and renders under "Uncategorized" only.

This is a materially larger gap than the report's origin bug and is squarely inside the mandate's
explicit ".opencode/ parity" requirement, though it is arguably a separate, larger porting task
rather than something to fold into a "minimal, uniform" fix for task 859.

### 8. Existing topic value survey (this repository)

`specs/state.json` `active_topics`: `["wezterm-notifications", "workflow-refactor",
"agent-system", "literature", "cslib", "extensions", "neovim"]` — all lowercase, all
already-hyphenated where multi-word. Per-task `topic` values currently in `active_projects`:
task 859 -> `agent-system`, task 857/858 -> `neovim`. No casing or separator variants exist in
this repository's live state today; the collision scenario described in the task (`Modal Logic`
vs `modal-logic`) was observed in a different repository (`Projects/cslib`), not reproducible
here from current data. **Migration scope for this repository is zero tasks** — the fix is
purely preventive/structural here, but must land in the shared core extension source
(`.claude/extensions/core/scripts/`) since that is what `Projects/cslib` and other repos consume.

## Decisions

- **Canonical topic form**: lowercase kebab-case (hyphen-separated), matching the
  already-established hint text used at every free-text entry point and matching every existing
  value in this repository's `active_topics`. No new form needs to be invented — it needs to be
  *enforced* rather than merely suggested.
- **Normalization is a single function, applied at both write and read time**: a
  `normalize_topic()` bash function (lowercase + collapse whitespace/underscores to `-` + trim)
  should be added once, likely in a small shared shell library or duplicated verbatim (bash has
  no cheap "source a snippet" primitive across the `.claude/scripts/*.sh` collection today) into
  `manage-topics.sh` and `generate-task-order.sh`. Applying it at write time (inside
  `manage-topics.sh add`/`set`, before the `jq --arg t` calls) prevents new collisions from ever
  entering `active_topics`; applying the same function to the grouping-key derivation in
  `generate-task-order.sh` (replacing the ad hoc `${t,,}` lowercasing at lines 430/441 with a call
  to the shared function) fixes both the reported case-sensitivity bug *and* the separator
  duplicate-heading risk in one change, and removes the need to patch the two buggy comparisons
  independently — if `_current_section_topic` and `task_topic[]`/`dep_topic` are both piped
  through the same normalizer before comparison, `!=` becomes correct without special-casing.
- **This task (859) should scope itself to**: (a) the origin bug fix in both
  `.claude/extensions/core/scripts/generate-task-order.sh` and
  `.opencode/scripts/generate-task-order.sh`, ideally implemented via a shared normalize step
  rather than two separate `${var,,}` patches, and (b) adding write-time normalization to
  `manage-topics.sh` so future topics can't re-introduce the collision. Full `.opencode/`
  write-side parity (Finding 7) and the autonomous-context directive (Finding 5) are larger,
  separable follow-ups (see Recommendations) rather than in-scope for a "low effort" fix.

## Risks & Mitigations

- **Risk**: Normalizing at write time changes the *stored* value for newly-created topics (e.g. a
  user types `"Modal Logic"` and it's silently stored as `modal-logic`), which could surprise a
  user who typed exactly what they wanted echoed back. **Mitigation**: this matches the
  already-documented hint text's intent and is a strict improvement over the current silent
  collision risk; the picker's "New topic..." confirmation step is the natural place to surface
  the normalized value back to the user before commit (e.g. "Stored as `modal-logic`").
- **Risk**: Retroactively normalizing existing `active_topics` values could orphan any task whose
  stored `topic` field doesn't match a freshly-normalized `active_topics` entry, if normalization
  is applied to one but not the other in the same pass. **Mitigation**: not applicable to this
  repository today (Finding 8 — no variants exist), but any migration script must normalize both
  `active_topics` *and* every `active_projects[].topic` in the same atomic jq pass.
- **Risk**: Duplicating a `normalize_topic()` bash function into multiple scripts (no shared-lib
  convention exists in `.claude/scripts/`) reintroduces the "same logic in ~6 places" problem the
  prior mandatory-topic-assignment task was explicitly built to eliminate for the picker UI.
  **Mitigation**: keep the function to a single one-line `sed`/parameter-expansion idiom
  (lowercase + `s/[_ ]\+/-/g` + trim leading/trailing `-`) so duplication cost stays minimal; note
  in both copies that they must stay in sync, or add a shared `.claude/scripts/lib/topic-normalize.sh`
  if a third consumer ever needs it.

## Context Extension Recommendations

- **Topic**: state.json schema reference completeness
  **Gap**: `.claude/context/reference/state-management-schema.md` does not document `topic` or
  `active_topics` despite both being mandatory/load-bearing.
  **Recommendation**: add a `topic` row to the "Project Entry Fields" table and a short
  `active_topics` subsection (top-level array, maintained via `manage-topics.sh`, canonical form
  lowercase kebab-case) to `state-management-schema.md`.
- **Topic**: autonomous-context directive for topic assignment
  **Gap**: no `orchestrator_mode`-aware fallback exists for Mode A/B/C, unlike the `--lit` flag's
  `AUTONOMOUS_GLOBAL` pattern.
  **Recommendation**: a follow-up task should either (a) explicitly document that Mode A/B/C are
  currently only reachable from interactive contexts and add an assertion/guard that fails loudly
  if invoked with `orchestrator_mode == true`, or (b) design a deterministic-default directive
  analogous to `literature-lit-flag-resolve.sh`'s five-directive model (e.g., inherit-or-fail
  rather than inherit-or-prompt when no human is present).
- **Topic**: `.opencode/` topic-assignment write-side parity
  **Gap**: `.opencode/` has the render-side topic grouping machinery but none of the mandatory
  write-side assignment system (no `manage-topics.sh`, no `topic-assignment-pattern.md`, no
  `/task` Step 4.5 equivalent).
  **Recommendation**: file a separate, appropriately-scoped task to port the mandatory-topic-assignment
  system to OpenCode's `/task` and companion skills, referencing `topic-assignment-pattern.md` as
  the source spec.

## Appendix

- `.claude/extensions/core/scripts/generate-task-order.sh` lines 265-290 (`load_topics`), 411-527
  (`generate_grouped_section`, `_print_topic_node`) — full read.
- `.opencode/scripts/generate-task-order.sh` lines 450-520, and `grep -n "!="` targeted search
  confirming lines 481/506.
- `.claude/context/patterns/topic-assignment-pattern.md` — full read (241 lines).
- `.claude/scripts/manage-topics.sh` — full read (180 lines).
- `.claude/commands/task.md`, `.claude/agents/meta-builder-agent.md`, `.claude/skills/skill-spawn/SKILL.md`,
  `.claude/skills/skill-fix-it/SKILL.md`, `.claude/skills/skill-project-overview/SKILL.md`,
  `.claude/commands/review.md`, `.claude/commands/errors.md` — targeted `grep -n "topic"` plus
  surrounding context reads for each caller location cited above.
- `.claude/context/reference/state-management-schema.md`, `.claude/rules/state-management.md` —
  grepped for `topic`/`active_topics` (zero matches in both).
- `specs/state.json`, `specs/TODO.md` — live data inspection (Finding 8) confirming this
  repository's `active_topics` are already normalized and no migration is required locally.
