# Implementation Plan: Task #887

- **Task**: 887 - Research: telemetry source architecture and /distill redesign
- **Status**: [IMPLEMENTING]
- **Effort**: 19 hours
- **Dependencies**: 873 (consumed, not redesigned)
- **Research Inputs**: `specs/887_research_telemetry_source_architecture_and_distill_redesign/reports/01_telemetry-source-architecture.md`
- **Artifacts**: plans/01_distill-telemetry-redesign.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan makes the four-tier signal-source model real and splits the 2,941-line
`skill-memory/SKILL.md` into `skill-learn` and `skill-distill`, growing `/distill` from 8 to 12
sub-modes by redefinition rather than deletion. The work divides into three independent tracks
that converge late: the **seam track** (one new `events.jsonl` field plus the documentation that
settles OTel field ownership), the **structure track** (split, reorder, factor the repeated
sub-mode skeleton), and the **contract track** (a shared guardrails context file every new
sub-mode cites). The five new sub-mode specifications (`--revise`, `--meta`, `--review`,
`--learn`, `--dream`) then land on top of all three.

Every phase writes to `agent-system/extensions/**` — the source store — and never to
`.claude/**`, which is a disposable deploy artifact regenerated from that source
(`rules/source-store-deploy-boundary.md`). No deliverable file outside `specs/**` may cite a task
number (`rules/no-task-references-in-deliverables.md`); the existing `distill.md` sub-mode
availability table already violates this and is corrected as part of Phase 11.

### Research Integration

The research report settles all four design questions and this plan adopts its conclusions, with
**one material correction discovered during plan grounding**:

- **CORRECTION — the `cwd` / repo-tag half of the seam is already fully implemented.** The report
  recommends adding a `cwd` field to `events-schema.json`, threading a `--cwd` flag through
  `events-append.sh`, and capturing `.cwd` from hook stdin in both event-writing hooks. All of
  that already exists on disk: `events-schema.json` carries a nullable `cwd` property;
  `events-append.sh` accepts `--cwd PATH` and writes `null` when absent;
  `events-log-lifecycle.sh` captures `CWD` from `STDIN_JSON` and threads it to both the Stop and
  SubagentStop appends; `events-log-artifact.sh` captures `CWD` from its parsed stdin and threads
  it to both the artifact-write and error-logged appends; and `events-query.sh` already derives a
  `repo` value as `basename(cwd)` at query time, exposes a `--repo` filter, and aggregates
  `by_repo` in `summary-counts`. `events-format.md` documents the whole "cwd stored, repo derived"
  contract. **The only genuinely new seam field is `cc_session_id`.** This shrinks Phase 1
  dramatically and gives it an exact template to copy: `cc_session_id` follows the identical path
  `cwd` already travels, at every one of the same call sites.
- Confirmed unchanged from the report: `cc_session_id` (Claude Code's native UUIDv4, present on
  every hook stdin) is the exact join key to OTel's `session.id`; `sess_{ts}_{rand}` is a dead end
  and is not revived; `gen_ai.*` names are borrowed as a citation vocabulary inside the already-open
  `detail` object only, never as top-level field names; the current `dream` sub-mode is already two
  separable deliverables at an existing prose boundary; sub-mode sections are non-contiguous
  (dispatch table at line 1071 lists `purge` second, but `### Purge Sub-Mode` sits at line 2489,
  ~1,400 lines later, and its logical pair `### GC Sub-Mode` at 2820).
- Confirmed unchanged: `memory-retrieve.sh`, `memory-harvest.sh`, `events-query.sh`, and
  `events-append.sh` need **no script-level change** for cross-repo access. They resolve
  `PROJECT_ROOT` from `BASH_SOURCE[0]`, which is the literal invocation string; because every
  existing call site uses the relative form `bash .claude/scripts/{name}.sh`, a chained
  `cd "$GLOBAL_ROOT" && bash .claude/scripts/{name}.sh ...` resolves `PROJECT_ROOT` to
  `$GLOBAL_ROOT` correctly. The requirement is an **invocation discipline at new call sites**, not
  a code change. Zero grep hits for `cc_session_id`, `CLAUDE_CODE_ENABLE_TELEMETRY`, or `gen_ai.`
  anywhere under `agent-system/` confirm this is new territory for the codebase.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Settle the OTel ↔ `events.jsonl` seam in code and prose: add `cc_session_id` as the exact join
  key, and document precisely which side owns which field.
- Split `skill-memory/SKILL.md` into `skill-learn` and `skill-distill` with no behavior change to
  either command's argument-parsing contract.
- Restructure `skill-distill` so sub-mode sections are contiguous and the seven-step skeleton is
  stated once and referenced by name, not restated six times.
- Specify all five new sub-modes (`--revise`, `--meta`, `--review`, `--learn`, and the redefined
  `--dream`) to a level that `/expand` can turn each into a standalone implementation task.
- Encode the design constraints (evaluator outside the loop, propose-then-human-review, ~70% v1
  miss rate, six failure modes) as a citable context file rather than repeated prose.

**Non-Goals**:

- Any change to the six existing hygiene sub-modes (`report`/`purge`/`merge`/`compress`/`refine`/
  `gc`/`auto`). The vault is 19 memories / 2,616 tokens with a single operator and static facts;
  the no-new-hygiene-below-~100-entries constraint holds and their behavior stays byte-identical
  apart from being relocated by the Phase 5 reorder.
- Building a span/trace system, a collector, or any OTel infrastructure. `gen_ai.*` names are
  borrowed as vocabulary only.
- Redesigning `GLOBAL_ROOT` / the `cd` chaining mechanism / `--local`. These already exist and are
  consumed as-is.
- Reimplementing task creation inside `--meta`. It delegates to the existing 1,429-line
  `meta-builder-agent`.
- Cross-repo `events.jsonl` aggregation. `events.jsonl` is a per-repo file; `events-query.sh`'s
  `--repo` filter operates within one file only. This is a documented residual limit and a
  candidate follow-up, explicitly out of scope.
- Writing a transcript/history parser from scratch. Reuse `ccusage` / `claude-code-log` parsing
  approaches where a parser is needed; neither extracts success/failure signal, which is exactly
  why OTel owns that half of the seam.
- Any write to `.claude/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| ~70% v1 miss rate: `--revise` classification and `--meta` pattern discovery under-detect real friction (closest documented precedent self-reports keyword-based friction detection catching only 20-30%) | M | H | Design for iteration, not one-shot precision. Every new sub-mode is propose-then-human-review with a mandatory `AskUserQuestion` gate; ship a miss-rate expectation in the guardrails file (Phase 2) so a low v1 hit rate reads as expected, not as failure |
| Autonomous-loop degradation: the documented anti-pattern where an agent ran 220+ loops and began fabricating metrics once its own optimistic summaries became the next loop's input | H | M | Evaluator stays outside the loop. NEVER auto-apply. No sub-mode may consume its own prior output as primary evidence; evidence must trace to a source tier (OTel / events.jsonl / history.jsonl / transcript). Encoded as a hard rule in Phase 2 and cited by Phases 6-10 |
| `events-schema.json` is `"additionalProperties": false`, so adding `cc_session_id` is a deliberate schema revision, not a silent `detail` addition; strict validators may reject | M | M | Field is optional and nullable, so no backfill or migration is needed. Phase 1 explicitly enumerates and updates every strict validator in the same pass — a checklist item, not an afterthought |
| OTel tier contributes nothing when `CLAUDE_CODE_ENABLE_TELEMETRY=1` is unset in the user's environment | M | H | Degrade the way the current `dream` section's "No Events Yet" path already does: a first-class, explicitly-announced outcome, never a silent gap. Generalize that pattern to "OTel not enabled" in Phase 4 and reuse it in Phases 6-10 |
| The mechanical split (Phase 3) silently drops or duplicates content across the 2,941-line boundary | H | M | Split is line-boundary-mechanical at `## Mode: distill` (line 1063) with a line-count reconciliation check; no content is rewritten in the same phase that moves it. Restructuring is deferred to Phase 5 so a diff of Phase 3 is pure relocation |
| `--meta`'s signal is single-repo only; a reader assumes system-wide coverage | M | H | State the limitation in the flag's own description text, not only in the plan. Do not imply cross-repo aggregation exists |
| A new `--meta`/`--revise`/`--review` call site invokes a memory/event script by absolute path, silently defeating cwd-based `PROJECT_ROOT` resolution and always reading the wrong repo | H | M | Phase 2's guardrails file states the mandatory chained relative form verbatim; Phases 6-8 cite it. Absolute-path invocation of these four scripts is a named prohibition |
| Deploy-boundary violation: an implementer edits `.claude/**` and the change is wiped by the next regeneration | H | M | Every phase's file list names `agent-system/extensions/**` paths only. Phase 12 greps the diff for `.claude/` write targets as a gate |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4, 5 | 1 (for 4), 3 (for 5) |
| 3 | 6, 7, 8, 9 | 2, 4, 5 |
| 4 | 10 | 6, 7 |
| 5 | 11 | 6, 7, 8, 9, 10 |
| 6 | 12 | 11 |

Phases within the same wave can execute in parallel. Wave 1's three phases touch disjoint file
sets (core scripts/hooks/schema; a new context file; the memory extension's skill and registration
files) and are safe to parallelize with explicit territory.

---

### Phase 1: Add `cc_session_id` to the events seam [COMPLETED]

**Goal**: Give `events.jsonl` an exact join key to Claude Code's OTel stream by capturing Claude
Code's native session UUID, which every hook already receives on stdin and both event-writing
hooks currently discard.

**Design decisions (settled, do not relitigate)**:

- The field is named `cc_session_id`, flat `snake_case`, matching the schema's existing convention
  (`event_id`, `session_id`, `duration_seconds`). It is **not** named `session.id` — dotted OTel
  names never become top-level `events.jsonl` fields.
- It is distinct from the existing `session_id`, which stays exactly what it is: the agent-system's
  `sess_{ts}_{rand}` gate-in id. The two ids live in different id spaces and neither replaces the
  other. The `sess_*`-based join is a confirmed dead end and is not revived.
- Type is `["string", "null"]`, optional, defaulting to `null` — identical in shape and nullability
  to the `cwd` field already present.
- No backfill. Rows written before this change simply lack the field; consumers treat it as
  optionally-absent from day one.

**Tasks**:

- [x] Add the `cc_session_id` property to `events-schema.json` with a description that states: it
      is Claude Code's own native session UUID from hook stdin `.session_id`; it shares an id space
      with OTel's `session.id` resource attribute and `history.jsonl`'s `sessionId`; it is distinct
      from this schema's `session_id`; and it is `null` for events emitted outside any hook context.
      *(completed)*
- [x] Add a `--cc-session-id VALUE` flag to `events-append.sh`, following the existing `--cwd`
      implementation exactly: a `cc_session_id=""` initializer, an argument-parser case, an
      `--arg cc_session_id` binding, and an
      `if $cc_session_id == "" then null else $cc_session_id end` emission in the jq object.
      *(completed)*
- [x] In `events-log-lifecycle.sh`, extract `.session_id` from the already-parsed `STDIN_JSON`
      into a `CC_SESSION_ID` variable alongside the existing `CWD` extraction, and append
      `--cc-session-id` to `event_args` for both the SubagentStop and Stop paths, guarded by the
      same `[ -n "$X" ] &&` idiom already used for `CWD`. *(completed)*
- [x] In `events-log-artifact.sh`, extract `.session_id` from the parsed `INPUT` JSON alongside the
      existing `CWD` extraction, and thread it into both the `artifact_write` and `error_logged`
      `event_args` arrays with the same guard idiom. Note the `CLAUDE_TOOL_INPUT` env-var fallback
      path carries no `.session_id`, so the variable stays empty there and is written as `null` —
      the same edge case already documented for `CWD`. *(completed)*
- [x] Correct the stale header comment in `events-log-lifecycle.sh` (currently: "Claude Code hook
      stdin carries no workflow session_id or task number directly"). The statement is true of the
      agent-system's id and false of Claude Code's own; rewrite it to distinguish the two rather
      than deleting it, since the marker-file reconstruction it justifies is still needed.
      *(completed)*
- [x] Enumerate and update every strict validator of `events-schema.json` found by grep. This is an
      explicit checklist item because the schema's top-level object is `"additionalProperties":
      false` and a strict validator that has not been updated will reject the new field.
      *(completed: grepped all of agent-system/ for "events-schema.json" — only consumers are
      events-append.sh/events-query.sh (jq construction, not schema-strict validation) and
      verify-deploy.sh (file-presence check only, no additionalProperties enforcement); no
      other strict validator exists to update)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts (a) that `cc_session_id` is the *only* new field required
— i.e. `cwd` and its full `--cwd` / hook-capture / `--repo`-derivation path are already implemented
— and (b) that exactly five files change. Confirm at implementation time by grepping for `cwd`
across `events-schema.json`, `events-append.sh`, `events-query.sh`, and both hooks before writing
anything; if `cwd` is genuinely absent from any of them, this phase's scope doubles and the
plan-time correction in the Overview is wrong. Confirm (b) by grepping for consumers of the
schema and for other `events-append.sh` call sites; any additional call site that should carry the
join key expands the file list.

**Files to modify**:

- `agent-system/extensions/core/context/schemas/events-schema.json` - add nullable `cc_session_id`
  property
- `agent-system/extensions/core/scripts/events-append.sh` - add `--cc-session-id` flag, mirroring
  `--cwd`
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` - capture and thread
  `.session_id`; correct the stale header comment
- `agent-system/extensions/core/hooks/events-log-artifact.sh` - capture and thread `.session_id`
- Any strict schema validator surfaced by the enumeration task

**Verification**:

- `events-append.sh --help` shows the new flag; a manual append with and without
  `--cc-session-id` produces a line with the field populated and `null` respectively.
- The emitted line validates against the revised schema in both cases.
- A pre-existing `events.jsonl` line lacking the field still validates.
- Every `--cwd` occurrence in the two hooks has a sibling `--cc-session-id` occurrence.

---

### Phase 2: Author the telemetry guardrails context file [COMPLETED]

**Goal**: Encode the binding design constraints once, in a citable context file, so the five new
sub-mode specifications reference them by name instead of restating them five times — the same
factoring discipline Phase 5 applies to the sub-mode skeleton.

**Content the file must state**:

- **The four-tier source model**, with each tier's owner and its structural blind spot:
  (1) Claude Code OTel — outcome signal, enabled by `CLAUDE_CODE_ENABLE_TELEMETRY=1`;
  `claude_code.tool_result` carries `success`, `error_type`, `duration_ms`, `decision_source`;
  metrics `claude_code.session.count`, `.token.usage`, `.cost.usage`, `.code_edit_tool.decision`,
  `.active_time.total`; beta spans via `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1`; prompt and response
  content redacted unless `OTEL_LOG_USER_PROMPTS` / `OTEL_LOG_ASSISTANT_RESPONSES` /
  `OTEL_LOG_TOOL_DETAILS` are opted into. (2) `events.jsonl` — agent-system semantics and repo tag.
  (3) `history.jsonl` — the durable global prompt spine (~23,758 prompts, 7 months, 33 projects;
  each line carries `display`, `timestamp`, `project` as an absolute cwd, and `sessionId`), which
  outlives transcripts. (4) transcripts and their `.meta.json` sidecars — a 30-day replay and
  bootstrap window; the sidecar itself is minimal (`agentType`, `description`, `toolUseId`,
  `spawnDepth`) and carries no session id and no outcome field, so the replay value lives in the
  paired `.jsonl`.
- **The evaluator-outside-the-loop rule**: propose-then-human-review, NEVER auto-apply. No sub-mode
  may treat its own prior output as primary evidence; every proposal must trace to a source tier.
  Cite the documented anti-pattern in which an agent ran 220+ autonomous loops and began fabricating
  metrics once its own optimistic summaries became the next loop's input.
- **The six failure modes as an explicit design checklist**: stale-default bias; implementation
  drift toward simpler solutions under pressure; memory degradation absent persistent artifacts;
  over-optimism on noisy signals; weak domain knowledge; poor scientific taste.
- **The ~70% v1 miss-rate expectation**, framed as a design premise: iterate, do not chase one-shot
  heuristic precision.
- **The no-new-hygiene-below-~100-entries constraint** and the current vault's size (19 memories,
  2,616 tokens, single operator, static facts), so a future reader understands why the six existing
  hygiene sub-modes are frozen.
- **The `gen_ai.*` borrowing rule**: borrow `gen_ai.operation.name`, `gen_ai.provider.name`,
  `gen_ai.request.model`, `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, and
  `error.type` as a citation vocabulary, used as literal keys **only inside the already-open
  `detail` object** and only when the payload is explicitly citing OTel-derived evidence. Never as
  a top-level field name. Do not build a span/trace system or collector infrastructure.
- **The cross-repo script invocation discipline**: `memory-retrieve.sh`, `memory-harvest.sh`,
  `events-query.sh`, and `events-append.sh` resolve `PROJECT_ROOT` from the literal invocation
  string, so the mandatory form is
  `GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"; cd "$GLOBAL_ROOT" && bash .claude/scripts/{name}.sh ...`
  chained in a single Bash tool call. Name two prohibitions explicitly: never invoke these four
  scripts by absolute path (it silently defeats cwd resolution and always reads whatever the
  absolute path points at, ignoring `$GLOBAL_ROOT`), and never rely on a `cd` issued in an earlier,
  separate Bash invocation (subagent Bash cwd does not persist across tool calls).
- **The `sess_*` dead end**, recorded so it is not re-proposed: the agent system mints its ids at
  GATE IN and Claude Code never sees them; Claude Code's session id is a UUIDv4 in a different id
  space; no structural link exists.
- **The OSS-tooling position**: no OSS tool does the full mine-to-propose loop; reuse existing
  transcript/usage parsers rather than writing one, and note that none of them extract
  success/failure signal — which is precisely why OTel owns that half of the seam.

**Tasks**:

- [x] Create the guardrails context file under the memory extension's context tree (it is consumed
      by `skill-distill`, a memory-extension skill). *(completed:
      context/project/memory/telemetry-guardrails.md, 172 lines)*
- [x] Register it in `agent-system/extensions/memory/index-entries.json` with `load_when.skills`
      naming `skill-distill` and `load_when.commands` naming `/distill`, and an accurate
      `line_count`. *(completed)*
- [x] Verify no task-number citations appear anywhere in the new file. *(completed: grep clean)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/memory/context/project/memory/telemetry-guardrails.md` - new file
- `agent-system/extensions/memory/index-entries.json` - register the new entry

**Verification**:

- The file states every bullet above, each as a locatable heading or named rule.
- `jq .` parses the modified `index-entries.json`; the new entry's `path` resolves to a real file.
- Grep for `task [0-9]` and `tasks [0-9]` in the new file returns nothing.

---

### Phase 3: Split `skill-memory` into `skill-learn` and `skill-distill` [NOT STARTED]

**Goal**: Perform the mechanical split at the existing mode boundary, with zero content rewriting,
so the phase's diff is pure relocation plus registration updates and can be reviewed as such.

**Split boundary (settled)**: `skill-memory/SKILL.md` line 1063, `## Mode: distill`. Everything
above it — Context References, Execution Modes, Content Mapping, Memory Search, Memory Operations,
Task/Directory/Text/File Mode Execution, Error Handling, Git Commit (Postflight) — becomes
`skill-learn/SKILL.md`. Everything from 1063 to end of file becomes `skill-distill/SKILL.md`.

**Tasks**:

- [ ] Create `skill-learn/SKILL.md` from the pre-boundary content, with frontmatter `name:
      skill-learn` and a description scoped to memory creation only. Preserve the existing
      MANDATORY INTERACTIVE REQUIREMENT block verbatim.
- [ ] Create `skill-distill/SKILL.md` from the post-boundary content, with frontmatter `name:
      skill-distill`, `allowed-tools` matching what the distill sub-modes actually use, and a
      description scoped to vault analysis and maintenance. Add the header material the new file
      needs to stand alone (Context References, Overview) — this is the one permitted addition;
      no existing content is reworded.
- [ ] Determine which Context References belong to which half and split them accordingly rather
      than duplicating the whole list into both files.
- [ ] Delete `skill-memory/SKILL.md` and its `README.md`, or repoint the README, once both new
      skills exist and are registered.
- [ ] Update `agent-system/extensions/memory/manifest.json`: `provides.skills` becomes
      `["skill-learn", "skill-distill"]`; the three `routing` entries currently naming
      `skill-memory` are repointed (research and implement route to `skill-learn`; the `plan` entry
      stays `skill-planner`).
- [ ] Update `commands/learn.md`: the `Delegates To` line and all four `skill: "skill-memory"`
      dispatch references become `skill-learn`. Argument parsing is untouched.
- [ ] Update `commands/distill.md`: the `Delegates To` line and the `skill: "skill-memory"`
      reference become `skill-distill`. Argument parsing is untouched in this phase (Phase 11 owns
      the 12-sub-mode dispatch rewrite).
- [ ] Update the six `load_when.skills` arrays in `index-entries.json` that name `skill-memory`,
      assigning each context entry to whichever skill actually consumes it.
- [ ] Update `EXTENSION.md`'s skill-mapping table row and `README.md`'s two `skill-memory`
      references.
- [ ] Leave the email extension's five `skill-memory/SKILL.md` cross-references and the
      email-to-memory design doc's line-number citations for Phase 11's cross-reference sweep —
      they point at `/learn`-half content whose line numbers shift, and fixing them mid-split
      would mix two concerns.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the file is 2,941 lines and splits cleanly at line 1063,
and that exactly 16 non-SKILL.md references to `skill-memory` exist across the source store (6 in
`index-entries.json`, 3 in `manifest.json`, 5 in `commands/*.md`, 1 in `EXTENSION.md`, 2 in
`README.md`, plus 5 in the email extension deferred to Phase 11). Confirm at implementation time
with `wc -l`, a re-read of the boundary, and
`grep -rn "skill-memory" agent-system/ | grep -v "skills/skill-memory/SKILL.md:"`. If the counts
differ, update the task list before editing rather than after.

**Files to modify**:

- `agent-system/extensions/memory/skills/skill-learn/SKILL.md` - new, from lines 1-1062
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` - new, from lines 1063-2941
- `agent-system/extensions/memory/skills/skill-memory/` - removed
- `agent-system/extensions/memory/manifest.json` - `provides.skills` and `routing`
- `agent-system/extensions/memory/commands/learn.md` - delegation references
- `agent-system/extensions/memory/commands/distill.md` - delegation references
- `agent-system/extensions/memory/index-entries.json` - six `load_when.skills` arrays
- `agent-system/extensions/memory/EXTENSION.md` - skill-mapping table
- `agent-system/extensions/memory/README.md` - two references

**Verification**:

- Line-count reconciliation: `skill-learn` plus `skill-distill` line counts equal 2,941 plus the
  small, enumerable set of added standalone-header lines, with no other delta.
- A diff of the split content against the original shows relocation only — no reworded lines.
- `jq .` parses `manifest.json` and `index-entries.json`.
- `grep -rn "skill-memory" agent-system/extensions/memory/` returns nothing.

---

### Phase 4: Document the OTel ↔ events.jsonl seam in `events-format.md` [NOT STARTED]

**Goal**: Settle field ownership in prose so a future reader can tell, for any signal, which side
owns it and how to join across — including the degraded path when telemetry is off.

**Content the new section must state**:

- **OTel owns** (read via `CLAUDE_CODE_ENABLE_TELEMETRY=1`, never written by agent-system code):
  per-tool-call outcome (`tool_result.success`, `.error_type`, `.duration_ms`, `.decision_source`),
  per-API-call outcome (`api_request` / `api_error` / `api_refusal`), token and cost accounting
  (`claude_code.token.usage`, `.cost.usage`), permission and decision provenance
  (`tool_decision.source`, `permission_mode_changed`), and session aggregates
  (`claude_code.session.count`, `.active_time.total`). This is did-it-fail-and-why, and nothing
  task-, phase-, or plan-shaped — OTel structurally has no concept of a task number, a phase, or a
  plan deviation.
- **`events.jsonl` owns** (categories `deviation` / `blocker` / `milestone` / `success`, and the
  `task` / `checkpoint` fields, all unchanged): task numbers, phase and checkpoint boundaries, plan
  deviations, completion-time reflections, and the repo tag via the already-implemented `cwd`.
- **The exact join**: `cc_session_id` on an `events.jsonl` line equals `session.id` on OTel
  events, spans, and metrics for the same Claude Code session. No time-window heuristic is needed
  or permitted. `cwd` is the secondary correlator, covering the rare mid-session `CwdChanged` case,
  and is also the repo-tag source that makes OTel's non-standard `OTEL_RESOURCE_ATTRIBUTES` opt-in
  unnecessary — note explicitly that `cwd` is **not** a standard OTel resource attribute (the
  standard set is `session.id`, `user.id`, `user.email`, `user.account_uuid`, `user.account_id`,
  `organization.id`, `app.version`, `app.entrypoint`, `terminal.type`), which is exactly why the
  repo tag lives on the `events.jsonl` side.
- **The naming rule**: top-level `events.jsonl` fields keep flat `snake_case`; `gen_ai.*` dotted
  names appear only as literal keys inside `detail`, and only when that payload cites OTel-derived
  evidence — e.g. a `--revise` correlation event whose `detail` carries
  `{"gen_ai.usage.input_tokens": 1200, "error.type": "ENOENT"}` next to the existing evidence
  citation. Cross-reference the guardrails file rather than restating the full borrowing rule.
- **The schema-revision note**: `additionalProperties: false` makes `cc_session_id` a deliberate,
  versioned revision; both it and `cwd` are nullable, so no backfill is required and consumers must
  treat both as optionally-absent.
- **The degraded path**: when `CLAUDE_CODE_ENABLE_TELEMETRY=1` is unset, the OTel tier contributes
  nothing. This must be an explicitly-announced, first-class outcome — modeled on the existing "No
  Events Yet" degraded-path pattern — never a silent gap.
- **The hooks extension point**: hooks are the sanctioned mechanism (30 event types; every hook
  receives `session_id`, `prompt_id`, `transcript_path`, `cwd`, `permission_mode`,
  `hook_event_name`). Note that Stop and SubagentStop carry `last_assistant_message` explicitly
  because `transcript_path` is written asynchronously and may lag the in-memory conversation.

**Tasks**:

- [ ] Add a `## Claude Code OTel Correlation` section to `events-format.md` covering every bullet
      above.
- [ ] Add the `cc_session_id` row to the existing field table, adjacent to `session_id`, with
      language that prevents confusing the two.
- [ ] Update the three example JSONL lines at the end of the file to include `cc_session_id`, with
      at least one showing the `null` case.
- [ ] Cross-reference the guardrails file for the four-tier model rather than duplicating it.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/core/context/formats/events-format.md` - new correlation section, field
  table row, updated examples

**Verification**:

- Every example JSONL line in the file still validates against the revised schema.
- The field table distinguishes `session_id` from `cc_session_id` unambiguously.
- The degraded path is stated as an announced outcome, with the announcement text specified.

---

### Phase 5: Restructure `skill-distill` — shared skeleton and contiguous ordering [NOT STARTED]

**Goal**: Eliminate the six near-duplicate copies of the per-sub-mode skeleton and make sub-mode
sections contiguous, so Phases 6-10 add five new sub-modes as deltas against one skeleton rather
than as five more copies.

**Design decisions (settled)**:

- One `## Shared Sub-Mode Skeleton` section is placed once, before the first sub-mode, stating the
  seven-step shape generically with named placeholders: Edge Case Checks →
  Candidate Identification → Dry-Run → Interactive Selection (MANDATORY STOP) → Execution →
  Batch Index Regeneration → Log Entry.
- Each existing sub-mode section is reduced to only its deltas from that skeleton. This generalizes
  a convention the file already uses once — the `dream` section's "reference the `### Overlap
  Scoring` section by name — do not restate or fork the formula" — into a file-wide rule.
- Section order becomes: dispatch table, `## Shared Sub-Mode Skeleton`, then the seven unchanged
  hygiene sub-modes in dispatch-table order with `purge` immediately followed by its logical pair
  `gc`, then the telemetry-sourced sub-modes, then `--review` and `--learn`. Phases 6-10 append
  into the slots this ordering creates.
- **The seven hygiene sub-modes' behavior does not change.** Reduction to deltas is a
  presentation-level refactor and must be behavior-preserving: if a sub-mode's step genuinely
  differs from the skeleton, it stays stated in full rather than being bent to fit.

**Tasks**:

- [ ] Author the `## Shared Sub-Mode Skeleton` section with named placeholders and an explicit
      statement that the MANDATORY STOP is non-negotiable in every sub-mode that mutates.
- [ ] Reorder sub-mode sections to the target order, moving `### Purge Sub-Mode` and
      `### GC Sub-Mode` up from the end of the file to adjacent positions in dispatch-table order.
- [ ] Reduce each of the seven hygiene sub-modes to its deltas, verifying behavior preservation
      step by step and leaving any genuinely-divergent step stated in full.
- [ ] Leave the `dream` section in place and unreduced — Phase 10 splits it, and reducing it here
      would create churn against content that is about to move.
- [ ] Fix any internal line-number or section cross-references invalidated by the reorder.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the seven-step skeleton appears near-verbatim in six
places (`merge` at ~1320-1527, `compress` at ~1574-1691, `refine`, `auto`, `purge`, and `dream`'s
revision half) and that reduction is behavior-preserving in all six. Confirm at implementation time
by extracting each sub-mode's step sequence and diffing against the skeleton before reducing; any
sub-mode whose steps do not actually match is left stated in full and the count is corrected in the
phase record. Line numbers shift after Phase 3's split and must be re-derived, never reused.

**Files to modify**:

- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` - skeleton section, reorder,
  per-sub-mode reduction

**Verification**:

- Sub-mode section order matches the dispatch table order exactly.
- For each of the seven hygiene sub-modes, the skeleton plus its stated deltas reconstruct the
  pre-refactor behavior — checked step by step, not by line count.
- No internal cross-reference points at a stale line number or a moved heading.

---

### Phase 6: Specify the `--revise` sub-mode [NOT STARTED]

**Goal**: Define memory refactoring as a first-class sub-mode inheriting the existing correlation
machinery from `dream`'s first half, now additionally evidenced by OTel outcomes.

**Design decisions (settled)**:

- `--revise` inherits, in substance unchanged, the current `dream` section's Event Ingestion,
  Event-to-Memory Correlation, corroborated/contradicted/gap Classification with its three-strikes
  threshold, the `AskUserQuestion` UPDATE/TOMBSTONE/CREATE gate, and Batch Index Regeneration.
- Primary source is Tier 2 (`events.jsonl`). **New**: Tier 1 (OTel) supplies outcome evidence,
  joined on `cc_session_id`. A memory can be classified `contradicted` by citing an OTel
  `tool_result.error_type` alongside a `deviation` event from the same session.
- OTel-derived evidence is cited inside `detail` using the borrowed `gen_ai.*` / `error.type` keys,
  per the Phase 4 naming rule.
- Never auto-applies. The `AskUserQuestion` gate is mandatory and is the skeleton's MANDATORY STOP.
- Degraded paths are announced, never silent: "no events yet" (the existing pattern) and "OTel not
  enabled" (its generalization from Phase 4).

**Tasks**:

- [ ] Author the `--revise` section as deltas against the shared skeleton, stating its
      candidate-identification logic, dry-run format, and log-entry shape.
- [ ] Specify the OTel evidence join precisely: query `events.jsonl` for the sub-mode's candidate
      events, read `cc_session_id`, and correlate to OTel outcome records for that session.
- [ ] Specify the `detail` payload shape for an OTel-evidenced correlation event.
- [ ] Specify both degraded paths with their exact announcement text.
- [ ] Cite the guardrails file for the miss-rate expectation and the never-auto-apply rule rather
      than restating them.
- [ ] State the cross-repo invocation discipline for any `events-query.sh` call this sub-mode makes.

**Timing**: 2 hours

**Depends on**: 2, 4, 5

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` - new `--revise` section

**Verification**:

- Every one of the five inherited machinery elements is either present or explicitly referenced by
  name from the `dream` source content.
- The MANDATORY STOP is present and unconditional.
- Both degraded paths specify announcement text, not just "degrade gracefully".
- No `gen_ai.*` key appears outside a `detail` payload.

---

### Phase 7: Specify the `--meta` sub-mode [NOT STARTED]

**Goal**: Define cross-repo agent-system improvement as a sub-mode that **consumes** the existing
global-root mechanism and **delegates** task creation, inventing neither.

**Design decisions (settled)**:

- Discovery logic is unchanged in substance from the current `dream` section's "Improvement
  Proposals" half, which that section's own prose already calls out as a separate deliverable from
  memory revision, with a different destination and different write permissions.
- Target resolution consumes the existing mechanism verbatim:
  `GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"`, the `cd "$GLOBAL_ROOT"`
  chaining, and the `--local` opt-out. **Do not invent a parallel resolver.** Running from a
  session already inside `$GLOBAL_ROOT` is a genuine no-op, not a special branch.
- Task creation **delegates to `meta-builder-agent`** via the Agent tool. Do not reimplement the
  `/task` primitive.
- Extension targeting reuses `meta-builder-agent`'s existing component-detection to decide which of
  the 19 extension directories a proposal should contribute to. Do not write new detection logic.
- Confirms via `AskUserQuestion` after basic investigation, and lets the user select and modify the
  proposed tasks before anything is created.
- Every memory/event script call uses the chained relative form in a single Bash tool call.
  Absolute-path invocation is prohibited; a `cd` from an earlier tool call must never be assumed to
  persist.

**Tasks**:

- [ ] Author the `--meta` section as deltas against the shared skeleton.
- [ ] Specify the delegation contract to `meta-builder-agent`: what is passed (proposal set,
      resolved `target_root`, extension targets), what comes back, and what `--meta` does with it.
- [ ] Specify the `AskUserQuestion` confirmation: what "basic investigation" precedes it, and how
      the user selects and modifies proposed tasks.
- [ ] State the exact chained-Bash form for every script call, citing the guardrails file.
- [ ] Document the single-repo signal limitation **in the flag's own description text**:
      `events.jsonl` is a per-repo file, so `--meta` invoked from `$GLOBAL_ROOT` sees only
      `$GLOBAL_ROOT`'s own event store, not aggregated signal from the other repos this system runs
      in. Note that `events-query.sh`'s `--repo` filter operates within a single file and does not
      close this gap, and that cross-repo aggregation is an explicit out-of-scope follow-up.

**Timing**: 2 hours

**Depends on**: 2, 4, 5

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts 19 extension directories under
`agent-system/extensions/*/` (`core`, `cslib`, `email`, `epidemiology`, `filetypes`, `formal`,
`founder`, `latex`, `lean`, `literature`, `memory`, `nix`, `nvim`, `present`, `python`, `slidev`,
`typst`, `web`, `z3`) and that `meta-builder-agent` already provides component detection reusable
for extension targeting. Confirm with `ls -d agent-system/extensions/*/` and by locating the
detection logic in `meta-builder-agent.md` before writing the delegation contract. If the detection
logic does not exist, this phase must stop and surface that rather than writing new detection.

**Files to modify**:

- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` - new `--meta` section

**Verification**:

- The section contains no target-resolution logic of its own beyond consuming `GLOBAL_ROOT` and
  `--local`.
- The section contains no task-creation logic; every creation path routes through
  `meta-builder-agent`.
- Every script invocation shown is a single chained Bash call using a relative script path.
- The single-repo limitation appears in the flag description, not only in commentary.

---

### Phase 8: Specify the `--review` sub-mode [NOT STARTED]

**Goal**: Define read-only ad-hoc inquiry over the vault and all four source tiers — the one
sub-mode that legitimately spans every tier live.

**Design decisions (settled)**:

- Strictly read-only. It never proposes and never writes. This is what distinguishes it from
  `report` (fixed structured output over the vault only) and from `--revise` / `--meta` (which do
  propose writes).
- Consumes all four tiers on demand, driven by the user's question rather than a fixed query.
- Because it does not mutate, it needs no `AskUserQuestion` mutation gate — the one sanctioned
  deviation from the shared skeleton's MANDATORY STOP, which must be stated explicitly rather than
  left as an omission.
- Any action arising from a review funnels to `--meta` (proposal), `--revise` (memory change), or
  `/learn` (new memory). `--review` never acts directly.

**Tasks**:

- [ ] Author the `--review` section as deltas against the shared skeleton, explicitly naming the
      MANDATORY STOP exemption and its justification.
- [ ] Specify per-tier access: which script or read path serves each tier, and the announced
      degraded behavior when a tier is unavailable (OTel disabled, transcript rolled past 30 days,
      no events yet).
- [ ] Specify the output shape: open-ended answer with evidence citations naming the tier and
      record each claim came from.
- [ ] State the funnel-to-other-sub-mode rule.
- [ ] State the cross-repo invocation discipline for any script call.

**Timing**: 1.5 hours

**Depends on**: 2, 4, 5

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` - new `--review` section

**Verification**:

- No write, edit, or task-creation path exists anywhere in the section.
- The MANDATORY STOP exemption is stated with its justification, not silently omitted.
- Each of the four tiers has a named access path and a named degraded behavior.

---

### Phase 9: Specify the `--learn` sub-mode [NOT STARTED]

**Goal**: Define retroactive, batch harvest across already-completed tasks, distinguished
unambiguously from the two existing harvest paths.

**Design decisions (settled)**:

- Scope is already-archived tasks whose `memory_candidates` were never harvested — declined,
  skipped, or predating the harvest mechanism.
- Distinct from `/learn --task N` (single task, any time, artifact-driven) and from `/todo`'s
  archive-time harvest (automatic, only at the moment of archival, reading only
  `memory_candidates` already present). The section must state both distinctions explicitly,
  because the flag name collides with the `/learn` command and a reader will otherwise conflate
  them.
- Primary source is Tier 4 (transcripts and `.meta.json`) within the 30-day window; Tier 3
  (`history.jsonl`) is the fallback beyond it. Once a transcript rolls out of the window, only
  `history.jsonl`'s prompt-level record and the task's own archived `specs/` artifacts remain.
- Note the sidecar's limits: `.meta.json` carries only `agentType`, `description`, `toolUseId`,
  `spawnDepth` — no session id and no outcome — so it is bootstrap-only and the replay value is in
  the paired `.jsonl`.
- Reuse existing transcript parsers rather than writing one; note that they extract no
  success/failure signal, so outcome must come from the OTel tier if it is wanted at all.
- Proposes candidates through the shared skeleton's MANDATORY STOP; never auto-creates memories.

**Tasks**:

- [ ] Author the `--learn` section as deltas against the shared skeleton.
- [ ] Specify candidate identification: how archived tasks with unharvested candidates are found.
- [ ] Specify the 30-day boundary behavior and the Tier 3 fallback, including the announcement when
      a task's transcript is no longer available.
- [ ] State the two distinctions (from `/learn --task N` and from `/todo`'s harvest) prominently.
- [ ] State the parser-reuse position.

**Timing**: 1.5 hours

**Depends on**: 2, 4, 5

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` - new `--learn` section

**Verification**:

- Both distinctions are stated in the section's opening, not buried.
- The 30-day boundary and its fallback are specified with announcement text.
- The MANDATORY STOP is present.

---

### Phase 10: Redefine `--dream` and retire its migrated content [NOT STARTED]

**Goal**: Reduce `--dream` to speculative direction-finding only, once its two current halves have
landed in `--revise` and `--meta`.

**Design decisions (settled)**:

- Overlap is resolved by redefinition, not deletion. `--dream` survives with a narrower charter.
- Primary source becomes Tier 3 (`history.jsonl`) — the durable global prompt spine, natively
  cwd-scoped via its `project` field and session-scoped via `sessionId`, so slicing per-repo needs
  no transformation.
- Charter: surface recurring themes and interests in the user's own prompt history that have no
  corresponding memory or task yet. Brainstorming, not event-correlated revision.
- It carries **no event-correlation machinery of its own** — that all lives in `--revise` now.
- No `AskUserQuestion` mutation gate is needed at the surfacing step because nothing mutates; like
  `--review`, this exemption is stated explicitly. Any resulting action funnels to `--meta` (a
  proposal) or `/learn` (a new memory), never applied directly.

**Tasks**:

- [ ] Verify the `--revise` and `--meta` sections fully contain the migrated content before
      removing anything from `dream` — no content may be deleted until its destination exists.
- [ ] Rewrite the `dream` section to the new charter and reduce it to deltas against the shared
      skeleton.
- [ ] Specify `history.jsonl` access: line shape (`display`, `pastedContents`, `timestamp` as unix
      ms, `project` as an absolute cwd, `sessionId`), per-repo slicing via `project`, and the
      recurring-theme surfacing logic.
- [ ] State the MANDATORY STOP exemption and the funnel rule.
- [ ] Move the section into its ordered slot from Phase 5.

**Timing**: 1.5 hours

**Depends on**: 6, 7

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` - rewritten `--dream` section

**Verification**:

- Every element of the old `dream` section is traceable to `--revise`, `--meta`, or the new
  `--dream` charter — nothing is lost in the migration.
- No event-correlation machinery remains in `--dream`.
- `history.jsonl` is the stated primary source.

---

### Phase 11: Command surface, extension docs, and cross-reference sweep [NOT STARTED]

**Goal**: Make all 12 sub-modes reachable and correctly documented, and repair every reference
invalidated by the split and reorder.

**The 12 sub-modes**: `report` (bare), `purge`, `merge`, `compress`, `refine`, `gc`, `auto`
(seven unchanged), plus `--meta`, `--review`, `--revise`, `--dream`, `--learn` (five new or
redefined).

**Tasks**:

- [ ] Rewrite `commands/distill.md` argument parsing to dispatch all 12 sub-modes, first-match-wins,
      preserving the existing `--dry-run` and `--verbose` additional flags.
- [ ] Rewrite the sub-mode availability table. **Remove the task-number column entirely** — it
      currently cites task numbers in a deliverable outside `specs/**`, violating
      `rules/no-task-references-in-deliverables.md`. Replace with a durable anchor: the sub-mode's
      section name in `skill-distill/SKILL.md`.
- [ ] Update the command's purpose line, which currently names only the five hygiene sub-modes.
- [ ] Update `EXTENSION.md`: the skill-mapping table (now two skills) and the `/distill` command
      table (now 12 rows), keeping the description text task-number-free.
- [ ] Update `README.md`'s memory-lifecycle description to reflect the new sub-modes.
- [ ] Sweep the email extension's five `skill-memory/SKILL.md` references and its
      `email-to-memory-preferences.md` line-number citations, repointing them to
      `skill-learn/SKILL.md` with re-derived line numbers or, preferably, to section names instead
      of line numbers so they stop being fragile.
- [ ] Re-audit `index-entries.json`: correct `line_count` values, and add a `skill-distill` entry
      for the guardrails file if Phase 2's registration needs adjusting after the split.
- [ ] Verify the top-level `.claude/CLAUDE.md` merge target regenerates correctly from the updated
      `EXTENSION.md` — by regeneration, never by hand-editing `.claude/CLAUDE.md`.

**Timing**: 2 hours

**Depends on**: 6, 7, 8, 9, 10

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts that the cross-reference sweep covers exactly the five
email-extension `skill-memory` references plus the `email-to-memory-preferences.md` line citations
(`SKILL.md:200-206`, `:995`, `:518`, `:1363`, `:2042-2050`). Confirm with a fresh
`grep -rn "skill-memory" agent-system/` after Phases 3-10 have landed; the set may have grown if
any intervening phase introduced a reference.

**Files to modify**:

- `agent-system/extensions/memory/commands/distill.md` - 12-sub-mode dispatch, detoxified table
- `agent-system/extensions/memory/EXTENSION.md` - skill and command tables
- `agent-system/extensions/memory/README.md` - lifecycle description
- `agent-system/extensions/memory/index-entries.json` - line counts, skill assignments
- `agent-system/extensions/email/skills/skill-email-cleanup/SKILL.md` - repointed references
- `agent-system/extensions/email/context/project/email/design/email-to-memory-preferences.md` -
  repointed citations

**Verification**:

- All 12 sub-modes appear in the dispatch logic, the availability table, and `EXTENSION.md`, with
  consistent naming across all three.
- `grep -rn "skill-memory" agent-system/` returns nothing.
- `grep -rniE "task [0-9]+|tasks [0-9]+" ` over every file changed in this phase returns nothing.
- `jq .` parses `index-entries.json`.

---

### Phase 12: Validation and deploy-boundary gate [NOT STARTED]

**Goal**: Prove the whole change set is internally consistent, schema-valid, boundary-clean, and
free of task-number citations before it is considered done.

**Tasks**:

- [ ] Validate a representative `events.jsonl` line — with `cc_session_id` populated, with it
      `null`, and a legacy line lacking it entirely — against the revised schema.
- [ ] Exercise `events-append.sh` with and without `--cc-session-id` and confirm the emitted lines
      match expectations.
- [ ] Confirm `events-query.sh` tolerates rows both with and without the new field.
- [ ] Grep the full diff for any write target under `.claude/` and fail if one exists.
- [ ] Grep every changed file outside `specs/**` for task-number citation patterns and fail if any
      exist.
- [ ] Run `bash .claude/scripts/validate-artifact.sh` against this plan and any artifacts produced.
- [ ] Confirm the extension loader deploys both new skills and that `manifest.json`,
      `index-entries.json`, and `EXTENSION.md` are mutually consistent.
- [ ] Walk the six-failure-mode checklist from the guardrails file against the five new sub-mode
      specifications and record the result.

**Timing**: 1.5 hours

**Depends on**: 11

**Verification Tier**: full

**Files to modify**:

- None (validation only; any defect found is fixed in its owning phase)

**Verification**:

- Every check above passes, or its failure is recorded and routed back to the owning phase.

---

## Testing & Validation

- [ ] Revised `events-schema.json` validates lines with `cc_session_id` present, `null`, and absent.
- [ ] `events-append.sh` emits `cc_session_id` correctly with and without the flag.
- [ ] Both event-writing hooks thread `cc_session_id` at every site where they already thread `cwd`.
- [ ] `events-query.sh` tolerates rows with and without the new field.
- [ ] The Phase 3 split reconciles by line count with no content loss.
- [ ] All 12 sub-modes are consistently named across dispatch logic, availability table, skill file,
      and `EXTENSION.md`.
- [ ] Every mutating sub-mode retains a MANDATORY STOP; every non-mutating one states its exemption
      explicitly.
- [ ] Both degraded paths (no events, OTel disabled) specify announcement text.
- [ ] `grep -rn "skill-memory" agent-system/` returns nothing.
- [ ] No file outside `specs/**` gained a task-number citation.
- [ ] No file under `.claude/**` was written.
- [ ] `jq .` parses every modified JSON file.

## Artifacts & Outputs

- Revised `events-schema.json`, `events-append.sh`, `events-log-lifecycle.sh`,
  `events-log-artifact.sh` (Phase 1)
- New `telemetry-guardrails.md` context file (Phase 2)
- New `skill-learn/SKILL.md` and `skill-distill/SKILL.md`; `skill-memory` removed (Phase 3)
- New `## Claude Code OTel Correlation` section in `events-format.md` (Phase 4)
- Restructured `skill-distill/SKILL.md` with one shared skeleton and contiguous sub-modes
  (Phases 5-10)
- Rewritten `commands/distill.md` with 12-sub-mode dispatch; updated `EXTENSION.md`, `README.md`,
  `manifest.json`, `index-entries.json` (Phases 3, 11)
- Repointed email-extension cross-references (Phase 11)

## Rollback/Contingency

Every phase is a git commit against source-store files only. `.claude/**` is regenerated from the
source store, so reverting a commit and redeploying fully restores prior behavior — there is no
hand-edited deploy state to reconcile.

Per-phase contingencies:

- **Phase 1**: `cc_session_id` is optional and nullable; reverting the schema and script changes
  leaves existing `events.jsonl` rows valid under the prior schema, since no row is rewritten.
- **Phase 3**: the highest-risk phase, because it moves 2,941 lines. Contingency is the line-count
  reconciliation gate — if reconciliation fails, revert and re-split rather than patching forward.
  Restructuring is deliberately deferred to Phase 5 so a failed split is a clean revert.
- **Phase 10**: content must not be deleted from `dream` until Phases 6 and 7 have landed its
  destinations. If either is incomplete, `--dream` stays as-is and Phase 10 blocks; it never
  deletes into a void.
- **Phases 6-10**: each adds an independent section. A defective sub-mode specification can be
  reverted alone without disturbing the others, provided Phase 5's shared skeleton stays intact.
