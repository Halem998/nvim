# Skill Lifecycle Pattern (Stage-N Skeleton)

## Overview

Every lifecycle skill (`skill-researcher`, `skill-planner`, `skill-implementer`, their `--hard`
variants, the team skills, and every extension's `skill-{domain}-research` /
`skill-{domain}-implementation`) is a self-contained workflow that owns its complete lifecycle in
one skill invocation:

- **Preflight**: validate input, update task status, write a premature-termination marker
- **Delegate**: invoke an agent (via the `Agent` tool) to perform the actual work
- **Postflight**: parse the agent's return, update task status, link artifacts, commit, clean up
- **Return**: return a brief text summary (not JSON) to the caller

A single skill invocation replaces the older 3-skill gate-in/delegate/gate-out pattern, reducing
halt risk from 3-4 potential stop points per command down to 1.

```
/research N
├── VALIDATE: Inline task lookup (command layer)
├── DELEGATE: Skill(skill-researcher)
│   ├── Stage 1-5b: preflight, context prep, subagent invocation (this doc's skeleton)
│   ├── Stage 6-9: postflight — status, artifacts, notify, cleanup (this doc's skeleton)
│   └── Return: brief text summary
└── COMMIT: command-level batch commit (CHECKPOINT 3)
```

**This document is the canonical map of that skeleton**: which numbered stage does what, and
which shared `@`-imported context block or `skill-base.sh` function is the one real
implementation of it. It does not repeat `skill-base.sh`'s authoring walkthrough or its full
function-signature table — see "Division of Labor" below for where that content lives.

---

## The Stage-N Skeleton

This is the stage list every converted lifecycle skill follows today, in numbered order. Every
skill uses the *same* stage numbers for the *same* purpose — a reader who knows "Stage 7 is
status update" in `skill-researcher` can carry that fact to `skill-nix-implementation` unchanged.
Not every skill has every stage (see "Optional / skill-specific stages" below), and skills differ
in how far they split the postflight stages apart (see "Two Postflight Shapes").

| Stage | Name | Canonical implementation | Owning file |
|-------|------|---------------------------|-------------|
| 1 | Input Validation | `skill_validate_input()` (in practice, most skills still hand-roll the task-lookup `jq` inline rather than calling this function — see the Known Gaps note below) | `scripts/skill-base.sh` |
| 2 | Preflight Status Update | `skill_preflight_update()` | `scripts/skill-base.sh`, imported via `@.claude/context/patterns/skill-preflight-flow.md` |
| 3 | Create Postflight Marker | `skill_create_postflight_marker()` (Shape A schema: `session_id`, `skill`, `task_number`, `operation`, `reason`, `created`, `stop_hook_active`) | same shared block as Stage 2 |
| 3a | Read/Calculate Artifact Number | Inline `jq` against `next_artifact_number`, with a disk-reconciliation scan (research adds a collision-avoidance loop over `reports/`). `skill_read_artifact_number()` exists in `skill-base.sh` as an available helper but no current skill calls it by name — the inline form remains the de facto implementation. | skill body (Stage 3a of each skill) |
| 4a | Memory Retrieval + Literature Detection | `memory-retrieve.sh` (skipped when `clean_flag=true`) plus the `--lit` resolution flow, imported via `@.claude/context/patterns/lit-stage4a-flow.md` | `scripts/memory-retrieve.sh`, `scripts/literature-lit-flag-resolve.sh` |
| 4 | Prepare Delegation Context | Prose: build the JSON delegation context (`session_id`, `delegation_depth`, `delegation_path`, `task_context`, domain-specific fields); `skill_context_injection()` fires the extension `context_injection` hook alongside it | skill body + `scripts/skill-base.sh` |
| 4b | Read/Inject Format or Plan Context | Prose: `cat` the relevant format spec (`report-format.md`/`plan-format.md`) or read the plan file, for inclusion in the Stage 5 prompt | skill body |
| 5 | Invoke Subagent | The `Agent` tool with an explicit `subagent_type` — never `Skill(...)` | skill body |
| 5a | *(implementer only)* Validate Subagent Return Format | Prose: sanity-check the returned metadata shape before Stage 6 | `skill-implementer/SKILL.md` |
| 5b | Self-Execution Fallback | The `.return-meta.json` write obligation when the skill performed work without spawning a subagent, imported via `@.claude/context/patterns/skill-self-execution-fallback.md` | same shared block |
| 5c | *(implementer only)* Continuation Loop Init | Prose: multi-turn continuation guard setup | `skill-implementer/SKILL.md` |
| 6 | Parse Subagent Return | Read and `jq`-parse `.return-meta.json`; `skill_read_metadata()` is the available helper | `scripts/skill-base.sh` |
| 6a | Validate Artifact Content | `skill_validate_artifact()` / `skill_validate_task_artifacts()` — non-blocking `validate-artifact.sh --fix` pass | `scripts/skill-base.sh` |
| 7 | Update Task Status (Postflight) | `skill_postflight_update()`, imported via `@.claude/context/patterns/skill-postflight-flow.md` | same shared block |
| 7a | Propagate Memory Candidates | `skill_propagate_memory_candidates()` | same shared block |
| 8 | Link Artifacts | `skill_link_artifacts()` (two-step `jq` pattern, Issue #1132-safe) | same shared block |
| 8a | Lifecycle TTS Notification | `skill_lifecycle_notify()` | same shared block |
| 9 | Git Commit *or* Cleanup | See "Two Postflight Shapes" below — this is the one stage number whose *meaning* diverges by skill family | varies |
| 10 | Cleanup *or* Return Brief Summary | See "Two Postflight Shapes" below | varies |
| 11 | Return Brief Summary | Prose: a 3-6 bullet text summary, never JSON | skill body |

**Not part of the per-skill stage list** (used only by `skill-orchestrate` /
`skill-orchestrate-hard`, not by the research/plan/implement skills above):
`skill_gate_completion_claim()` and `skill_corroborate_phase_counts()` implement the
completion-claim gate and plan-heading corroboration for autonomous orchestration. They live in
`scripts/skill-base.sh` alongside the Stage-N functions but are orchestrator-only — do not expect
them at any research/plan/implement skill's Stage 6-9.

### Known gaps between this table and the literal source

Two of the function-to-stage mappings above are the *intended* implementation, not a universal
call-site fact, and are stated that way on purpose rather than glossed over:

- `skill_validate_input()` exists and is exported, but every core and extension skill audited for
  this rewrite still hand-rolls its Stage 1 task lookup as an inline `jq` block rather than
  calling the function. Treat the function as available, not yet exclusive.
- `skill_read_artifact_number()` is similarly unreferenced by name in any `SKILL.md` today; Stage
  3a's inline `jq` (with research's additional disk-reconciliation and collision-avoidance logic)
  is the real implementation in every skill that has one.

A future conversion could route Stage 1 and Stage 3a through these functions the same way Stages
2/3/6/7/7a/8/8a/9(cleanup)/5b already were converted — that is out of scope for this rewrite,
which documents what skills actually do today.

---

## Two Postflight Shapes

Every skill shares Stages 6, 6a, 7, 7a, 8, 8a. They diverge on **who commits, and how many
numbered stages that takes** — this is a real, intentional difference between skill families, not
drift to be flattened.

### Collapsed shape (skill-researcher and every domain/extension thin wrapper)

`skill-researcher`, `skill-{domain}-research`, and `skill-{domain}-implementation` skills
(neovim, nix, latex, typst, z3, python, web, email, epidemiology, founder, present, etc.) fold
Stages 7/7a/8/8a/9 into a single `@`-import of `skill-postflight-flow.md`, where that block's own
Stage 9 is **Cleanup** (`skill_cleanup()`) — there is no inline git-commit stage in the skill
body at all. These skills rely entirely on the **command-level batch commit**
(`/research`'s and `/implement`'s own CHECKPOINT 3, e.g. `implement.md`'s "Apply the `implement`
scope... `git add`... `git commit`") to persist their changes. The skill's own numbering ends at
Stage 9 (cleanup, via the shared block) followed by either an explicit `### Stage 10: Return
Brief Summary` heading (as in `skill-researcher`) or an unnumbered `## Return Format` section
(as in most domain thin wrappers) — both are compliant with the skeleton; the final heading
number is a readability choice, not a validated field.

### Split shape (skill-planner and skill-implementer, core general/meta/markdown tasks)

`skill-planner` and `skill-implementer` interleave an explicit, inline **Stage 9: Git Commit**
between the shared block's TTS-notify stage and cleanup — calling
`.claude/scripts/git-commit-scoped.sh` directly (the sole sanctioned path-scoped, mutex-serialized
committer; see `@.claude/context/standards/git-staging-scope.md`) rather than relying solely on
the command-level batch commit. Because of this, these two skills' own Stage numbering runs one
stage longer:

- Stage 9: Git Commit (inline, via `git-commit-scoped.sh`)
- Stage 10: Cleanup (`skill_cleanup()`, called explicitly rather than through the shared block's
  own Stage 9 slot, since that slot is now occupied by Git Commit)
- Stage 11: Return Brief Summary

The command layer (`/plan`, `/implement`) still runs its own batch commit afterward as a safety
net — per `plan.md`'s own comment, "Per-skill postflight may have already committed individual
task changes; this batch commit captures any remaining unstaged changes and may be empty (which
fails gracefully)." The two commits are not a bug: the inline commit exists because multi-task
`/plan N,N,N` and `/implement N,N,N` dispatch several agents concurrently — a genuinely concurrent
site where each skill instance must commit its own task's changes rather than wait for a shared
batch step — while the command-level commit is the safety net for whatever the inline commit
didn't cover (e.g. a self-execution-fallback path).

**Rule of thumb**: if you are writing or converting a **core** general/meta/markdown lifecycle
skill (planner/implementer family), give it an explicit Stage 9 Git Commit. If you are writing a
**domain/extension** thin wrapper (research or implementation), do not — follow the collapsed
shape and let the command-level batch commit own it, exactly as `skill-researcher` and the
existing domain skills already do.

---

## skill-base.sh Functions Referenced Here

The full function-signature table and step-by-step authoring walkthrough live in
`docs/guides/creating-skills.md` — this document does not duplicate that table. The functions
named in the Stage-N table above are exactly the subset `creating-skills.md` documents, plus two
orchestrator-only functions (`skill_gate_completion_claim`, `skill_corroborate_phase_counts`)
called out above as explicitly out of scope for the per-skill stage list. If a function name
appears here that you cannot find in `creating-skills.md`'s table, treat the gap as this
document's own error, not a reason to hand-roll the logic — grep `scripts/skill-base.sh` for the
authoritative signature and header comment.

---

## Frontmatter Requirements

**Core skills** (`.claude/skills/skill-{name}/SKILL.md`) — call `skill-base.sh` functions
directly and invoke agents with explicit `subagent_type`:

```yaml
---
name: skill-{name}
description: {description}. Invoke for {use case}.
allowed-tools: Agent, Bash, Edit, Read, Write
---
```

**Extension/domain skills** (`.claude/extensions/*/skills/skill-{name}/SKILL.md`) — thin wrappers
under ~110-170 lines, same shared-block imports, domain-specific Stage 4/4a content only:

```yaml
---
name: skill-{name}
description: {description}. Invoke for {use case}.
allowed-tools: Agent, Bash, Edit, Read, Write
---
```

See `docs/guides/creating-skills.md`'s "Pattern A" / "Pattern B" split and step-by-step guide for
the full frontmatter decision matrix (including the older `context: fork` + `agent:` shorthand
some skills still use).

---

## Status Transitions by Workflow Type

| Workflow | Preflight Status | Postflight Status | Artifact Type |
|----------|-------------------|---------------------|----------------|
| Research | researching | researched | research |
| Planning | planning | planned | plan |
| Implementation | implementing | completed/implementing | summary |

---

## Error Handling

### Preflight Errors
- If Stage 2 (`skill_preflight_update`) fails, abort immediately — do not proceed to Stage 3 with
  an unset/unchanged status, and do not invoke the subagent.

### Agent Errors
- If the subagent returns `partial` or `failed`, do NOT run the Stage 7 status advance
  (`skill_postflight_update` already no-ops on a non-success status). Keep the task in its
  preflight-set status (e.g. `researching`) so the next `/research`/`/plan`/`/implement` invocation
  resumes rather than silently re-reporting success.

### Postflight Errors
- Log the error but don't fail the workflow — artifacts were already created by the agent, and
  status can be corrected manually or by re-running the command.

---

## Exclusion Criteria

Not every skill needs this lifecycle pattern. Skills matching these patterns are excluded:

| Pattern | Description | Example Skills |
|---------|--------------|-----------------|
| **Utility** | Provides a utility function, no task state management | skill-git-workflow |
| **Task Creation** | Creates new tasks, does not transition existing tasks | skill-meta |
| **Autonomous Loop** | Runs multi-phase lifecycle autonomously, delegates to workflow skills | skill-orchestrate, skill-orchestrate-hard |
| **Terminal State** | Operates only on completed/abandoned tasks | (archive operations) |
| **Non-Task** | Operates on different data like errors or reviews | (error/review skills) |
| **Mechanism** | IS the status update mechanism itself | skill-status-sync |

### Workflow Skills (Follow This Pattern)

These skills manage task lifecycle transitions and follow the Stage-N skeleton above:
- skill-researcher / skill-researcher-hard (not_started/researched -> researching -> researched)
- skill-planner / skill-planner-hard (researched -> planning -> planned)
- skill-implementer / skill-implementer-hard (planned -> implementing -> completed)
- Every extension's `skill-{domain}-research` / `skill-{domain}-implementation` pair

### Non-Workflow Skills (Excluded from Pattern)

- skill-status-sync: IS the mechanism, used for standalone operations
- skill-git-workflow: creates commits, no task state
- skill-orchestrate / skill-orchestrate-hard: runs the autonomous lifecycle loop (dispatches to
  workflow skills, which handle their own state)
- skill-meta: creates tasks via interview, no transitions

---

## Parallel Invocation

Workflow commands (`/research`, `/plan`, `/implement`) invoke multiple skills in a single message
for multi-task dispatch:

```
/research 7, 22, 24
  -> Skill(skill-researcher, task {N})   \
  -> Skill(skill-researcher, task {N})   > all invoked in a single message
  -> Skill(skill-researcher, task {N})  /
```

Each skill instance runs **independently** with its own preflight, delegation, postflight, and
(for the split-shape skills) its own inline git commit. Multiple parallel instances may write to
`state.json` concurrently — this is acceptable because every write is scoped to a specific
`project_number` via `select(.project_number == $num)`, so no instance touches another task's
fields.

**Multi-task vs. team mode** (orthogonal dimensions): multi-task invokes one skill instance per
task; team mode (`--team`) has a single team skill spawn multiple agents for *one* task. Combined
(`/research 7, 22 --team`), each task routes to the team skill, producing `N_tasks * team_size`
total agents.

---

## Postflight Boundary Restrictions

After the subagent returns (Stage 6 onward), a skill MUST NOT edit source files, run build/test
commands, call MCP/WebSearch tools, or analyze/grep source — that is agent work. Postflight is
limited to: reading the metadata file, calling `update-task-status.sh` (via
`skill_postflight_update`), incrementing `next_artifact_number`, linking artifacts, committing,
and cleanup. Every agent-delegating skill MUST include a `## MUST NOT (Postflight Boundary)`
section stating this explicitly — `lint-postflight-boundary.sh` enforces the section's presence
across the full skill corpus. See `@.claude/context/standards/postflight-tool-restrictions.md`
for the complete allowed/prohibited operation tables and the MUST NOT section template.

---

## Division of Labor with `docs/guides/creating-skills.md`

These two documents used to overlap and drift apart (a stale Stage-0-through-6 layout here that
matched zero actual skills, while `creating-skills.md` carried its own independent stage sketch).
They now split cleanly:

- **`docs/guides/creating-skills.md`** owns: the `skill-base.sh` function-signature table, the
  thin-wrapper authoring walkthrough (step-by-step skill creation), the frontmatter decision
  matrix (Pattern A core vs. Pattern B extension), the validation checklist, and common-mistakes
  examples. Its claim that core skills "use `skill-base.sh` lifecycle functions directly" was
  aspirational (false) when originally written — no core skill called those functions yet at the
  time — and is now true, following the conversion this document's own Stage-N skeleton reflects.
  See this document (`skill-lifecycle.md`) for the concrete stage-by-stage mapping that makes that
  claim verifiable.
- **`skill-lifecycle.md`** (this document) owns: the Stage-N skeleton itself, the shared-block map
  (which `@`-import implements which stage), the two postflight shapes, and the exclusion
  criteria for which skills follow the pattern at all.

When updating one, check whether the other needs a matching update — but do not re-duplicate
content between them; cross-reference instead.

---

## References

- Inline patterns: `@.claude/context/patterns/inline-status-update.md`
- Shared preflight block: `@.claude/context/patterns/skill-preflight-flow.md`
- Shared postflight block: `@.claude/context/patterns/skill-postflight-flow.md`
- Shared self-execution fallback: `@.claude/context/patterns/skill-self-execution-fallback.md`
- Literature `--lit` resolution flow: `@.claude/context/patterns/lit-stage4a-flow.md`
- Anti-stop patterns: `@.claude/context/patterns/anti-stop-patterns.md`
- Subagent return format: `@.claude/context/formats/subagent-return.md`
- Postflight restrictions: `@.claude/context/standards/postflight-tool-restrictions.md`
- Git staging scope (per-operation commit contract): `@.claude/context/standards/git-staging-scope.md`
- Authoring walkthrough and function table: `docs/guides/creating-skills.md`
