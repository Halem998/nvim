# Research Report: Task #887

**Task**: 887 - Research: telemetry source architecture and /distill redesign
**Started**: 2026-07-15T00:00:00Z
**Completed**: 2026-07-15T00:00:00Z
**Effort**: Large (design round only — no implementation)
**Dependencies**: 873 (consumed, not redesigned)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/**`, `agent-system/extensions/memory/**`, `~/.claude/history.jsonl`, `~/.claude/projects/**/*.meta.json`), sibling report 873, official Claude Code docs (`code.claude.com/docs/en/monitoring-usage`, `code.claude.com/docs/en/hooks`)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The OTel/events.jsonl seam has one concrete gap, and it is closeable with a small, additive
  schema change, not a redesign.** `specs/events.jsonl` currently carries only the
  agent-system's own `session_id` (`sess_{ts}_{random}`, confirmed dead-end per task framing) and
  has **no `cwd` field at all**. Claude Code's native `session_id` (a UUIDv4 — same value
  Claude Code calls `session.id` in OTel resource attributes, `sessionId` in `history.jsonl`, and
  `session_id` in hook stdin) and `cwd` are already present, live, on **every** hook invocation's
  JSON stdin (confirmed via `code.claude.com/docs/en/hooks`: "Every hook receives... `session_id`
  ... `cwd`"). The two already-registered hooks that write to `events.jsonl`
  (`events-log-lifecycle.sh` for Stop/SubagentStop, `events-log-artifact.sh` for PostToolUse) both
  already parse hook stdin as JSON but currently **discard** these two fields
  (`events-log-lifecycle.sh` line 9 even says explicitly: "Claude Code hook stdin carries no
  workflow session_id or task number directly" — true of the agent-system's own id, but the
  hook's stdin *does* carry Claude Code's own `session_id`/`cwd`, unused). Recommendation: add two
  new, optional, additive fields to `events-schema.json` — `cc_session_id` (Claude Code's native
  UUIDv4) and `cwd` (absolute path, doubling as the raw source for "repo tag") — captured by both
  hooks from their own stdin and threaded through `events-append.sh` as new
  `--cc-session-id`/`--cwd` flags. This gives an **exact** join key (`cc_session_id`) between
  `events.jsonl` and OTel data for the same Claude Code session, eliminating the need for any
  time-window/heuristic correlation. **Caveat**: `events-schema.json`'s top-level object sets
  `"additionalProperties": false`, so this is a genuine, deliberate schema revision (not a silent
  `detail`-style addition) — flag it as such in the plan.
- **`gen_ai.*` names are borrowed as documentation/mapping vocabulary and, where literal JSON keys
  are wanted, only inside the already-open `detail` object — never as new top-level field names.**
  The codebase's existing field-naming convention is flat `snake_case` (`event_id`, `session_id`,
  `duration_seconds`); OTel's GenAI semantic-convention names are dotted
  (`gen_ai.usage.input_tokens`). Top-level `events.jsonl` fields must keep the existing convention
  (`cc_session_id`, not `session.id`). `detail` is the one place dots are both legal JSON and
  low-risk (it is `additionalProperties: true`, open by design) — use literal `gen_ai.*` keys only
  there, and only when a `detail` payload is explicitly summarizing/citing OTel-derived evidence
  (e.g. a `--revise` correlation event citing an OTel `tool_result.error_type`). This settles "do
  we borrow the names" as: yes, as a citation vocabulary for cross-referencing evidence, not as a
  structural rebuild — consistent with the binding constraint that a full span/trace system is
  disproportionate.
- **873's `cd "$GLOBAL_ROOT"` mechanism DOES fully resolve cross-repo access for
  `memory-retrieve.sh`/`memory-harvest.sh`/`events-query.sh`/`events-append.sh` — but only because
  every existing call site already invokes them via the relative path
  `bash .claude/scripts/{name}.sh` (verified: every one of 13 call sites across `cslib`, `core`,
  and `literature` skills uses this exact relative form, never an absolute path).** These four
  scripts compute `PROJECT_ROOT` as `cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd` — i.e.
  `BASH_SOURCE[0]` is whatever *string* the caller used to invoke the script. When invoked with a
  relative path, that string is resolved against the **caller's cwd at invocation time**, so
  `cd "$GLOBAL_ROOT" && bash .claude/scripts/memory-retrieve.sh ...` (chained in one Bash call)
  correctly resolves `PROJECT_ROOT` to `$GLOBAL_ROOT`. This is the same "Strategy A, cwd-sensitive
  only via relative invocation" finding 873 documented for other scripts, now confirmed
  specifically for the memory/event trio — and it inherits 873's finding (c) exactly: it works
  **only** if the `cd` and the `bash .claude/scripts/...` call are the same chained Bash tool
  invocation, never a `cd` issued turns earlier. `/distill --meta`'s design (below) must chain,
  never assume persistence.
- **The four-tier model maps cleanly onto the 12 sub-modes**, with three tiers newly consumed
  (OTel, events.jsonl-as-extended, history.jsonl) and one (transcripts/`.meta.json`) consumed only
  by the new `--learn`. The six existing hygiene sub-modes (`report`/`purge`/`merge`/`compress`/
  `refine`/`gc`/`auto`) stay **source-unchanged** (`.memory/*` only) per the binding no-new-hygiene
  constraint.
- **`--dream`, `--revise`, and `--meta` are a clean split of the current `dream` sub-mode's two
  existing halves, not new machinery.** The current `### Sub-Mode: dream` section (lines
  2085-2391 of `skill-memory/SKILL.md`) already separates "Event Ingestion / Correlation /
  Classification / UPDATE-TOMBSTONE-CREATE" (lines 2102-2271) from "Improvement Proposals" (lines
  2273-2325) as two distinct deliverables in its own prose. The redesign literally lifts the first
  half into `--revise` (renamed, unchanged in substance, now also OTel-evidenced) and the second
  half into `--meta` (renamed, now cross-repo via 873's mechanism and delegated to
  `meta-builder-agent` instead of reimplementing task creation), leaving `--dream` for genuinely
  new content: speculative direction-finding sourced from `history.jsonl`'s durable prompt spine.

## Context & Scope

This is a design-only research pass for a task the user will `/revise` and then `/expand` into
implementation tasks. No files were written or modified outside
`specs/887_research_telemetry_source_architecture_and_distill_redesign/`. The design below settles
(a) the OTel/events.jsonl seam precisely, (b) the source contract for each of the 5 new `/distill`
flags, (c) whether 873's cross-repo mechanism fully covers the memory/event scripts, and (d) the
skill-learn/skill-distill split shape — per the task's four explicit design questions. It
consumes, and does not redesign, task 873's `GLOBAL_ROOT`/`cd`/`--local` mechanism.

## Findings

### Codebase Patterns

**Current `events.jsonl` schema is closed and cwd-blind** (`context/schemas/events-schema.json`,
full file read): the line schema is `"additionalProperties": false` with 6 required + 5 optional
fields (`event_id`, `event_type`, `category`, `timestamp`, `session_id`, `message` required;
`duration_seconds`, `task`, `checkpoint`, `detail`, `error_ref` optional). There is no `cwd`, no
repo identifier, and no Claude-Code-native session id anywhere in the schema. `session_id` is
explicitly documented (`events-format.md` line 60) as "the exact `sess_{timestamp}_{random}` value
already generated at command gate-in" — i.e. it is unambiguously the agent-system id, not Claude
Code's.

**Both event-writing hooks already parse the fields they'd need, and discard them**
(`hooks/events-log-lifecycle.sh` full file, `hooks/events-log-artifact.sh` full file):
- `events-log-lifecycle.sh` reads `STDIN_JSON` (the full hook payload) and extracts only
  `.agent_id` and `.last_assistant_message`. Its own header comment (lines 9-11) documents that it
  reconstructs the agent-system session_id via marker-file lookups specifically *because* "Claude
  Code hook stdin carries no workflow session_id... directly" — a true statement about the
  agent-system's id, but the same stdin blob does carry Claude Code's own `session_id` and `cwd`
  per the hooks contract (see External Resources below), unused today.
- `events-log-artifact.sh` (PostToolUse) derives its `session_id` argument entirely from the
  **written file's content** (`.return-meta.json`'s `.metadata.session_id`, or
  `errors.json`'s `.errors[-1].context.session_id`) rather than from hook stdin, even though the
  same PostToolUse stdin payload also carries Claude Code's native `session_id`/`cwd` per the
  common-fields contract.

**`memory-retrieve.sh`/`memory-harvest.sh`/`events-query.sh`/`events-append.sh` PROJECT_ROOT
resolution is invocation-relative, not file-location-fixed** (all four scripts, lines cited in
Findings summary): `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`. `BASH_SOURCE[0]`
is literally the string used to invoke the script. Every one of 13 grep-confirmed call sites across
`skill-researcher{,-hard}`, `skill-planner{,-hard}`, `skill-implementer{,-hard}`,
`skill-cslib-{research,implementation}{,-hard}`, and `skill-pr-review-{research,implementation}`
uses the identical relative form `bash .claude/scripts/memory-retrieve.sh ...` — never an absolute
path. This is why 873's `cd "$GLOBAL_ROOT" && bash .claude/scripts/foo.sh ...` chain works for
these scripts: the relative-path convention is exactly what makes cwd (at chained-invocation time)
determine `PROJECT_ROOT`.

**Existing `dream` sub-mode is already two deliverables, cleanly separable at an existing prose
boundary** (`skill-memory/SKILL.md` lines 2085-2391, full section read): "Event Ingestion" (2102),
"Event-to-Memory Correlation" (2154), "Classification" (2167, three-strikes
corroborated/contradicted/gap), the `AskUserQuestion` UPDATE/TOMBSTONE/CREATE flow (2204-2261),
and "Batch Index Regeneration" (2262) form one coherent unit that mutates `.memory/*`. "Improvement
Proposals" (2273-2325) is explicitly called out in the section's own prose as "**A separate
deliverable from memory revision** — never merged into the same list... The two have different
destinations and different write permissions" — task creation via the `/task` primitive directly
(2312-2319), which is exactly what 887's `--meta` redesign must instead delegate to
`meta-builder-agent`.

**Sub-modes are non-contiguous today, confirming the task description's claim**: dispatch table at
line 1071 lists `report, purge, merge, compress, refine, gc, auto, dream` in that order; but
`### Sub-Mode: merge` is at line 1316, `### Sub-Mode: compress` at 1570, `### Sub-Mode: refine` at
1767, `### Sub-Mode: auto` at 1987, `### Sub-Mode: dream` at 2085-2391, then — separated from
`merge`/`compress` by the entire `dream` section — `### Purge Sub-Mode` at 2489 and
`### GC Sub-Mode` at 2820, ~1,350 lines after the dispatch table lists `purge` second and ~1,150
lines after its logical pair `gc`.

**20-extension claim verified at 19 directories (`core` counts as one of the 20 the task text
rounds from)**: `agent-system/extensions/*/` lists `core, cslib, email, epidemiology, filetypes,
formal, founder, latex, lean, literature, memory, nix, nvim, present, python, slidev, typst, web,
z3` — 19 extension directories. `meta-builder-agent.md` is 1,429 lines (confirmed), the delegation
target `--meta` must reuse rather than reimplement.

**`history.jsonl` already carries a cwd-equivalent field** (`~/.claude/history.jsonl`, sampled):
each line is `{"display", "pastedContents", "timestamp" (unix ms), "project" (absolute cwd path),
"sessionId" (UUIDv4, same id space as OTel `session.id` and hook `session_id`)}`. This confirms
Tier 3's "durable global prompt spine" is already natively cwd-scoped and session-scoped — no
transformation needed to slice it per-repo for `--dream`'s direction-finding use.

**Transcript `.meta.json` sidecar files are per-subagent, minimal, and confirm the 30-day-replay
framing**: sampled files (`~/.claude/projects/*/subagents/agent-*.meta.json`) contain exactly
`{"agentType", "description", "toolUseId", "spawnDepth"}` — no session id, no outcome field. The
30-day-replay value is in the paired `.jsonl` transcript itself (full conversation), not this
sidecar; the sidecar is bootstrap-only (what kind of agent, what it was asked).

### External Resources

- `code.claude.com/docs/en/monitoring-usage` (fetched in full): confirms the exact metric/event
  vocabulary the task description cites (`claude_code.tool_result` with `success`, `error_type`,
  `duration_ms`, `decision_source`; `claude_code.session.count`, `.token.usage`, `.cost.usage`,
  `.code_edit_tool.decision`, `.active_time.total`), and additionally reveals: (a) **`cwd` is NOT
  a standard OTel resource attribute** — the "Standard Attributes (All Events/Metrics)" list is
  `session.id, user.id, user.email, user.account_uuid, user.account_id, organization.id,
  app.version, app.entrypoint, terminal.type` plus custom `OTEL_RESOURCE_ATTRIBUTES` — meaning cwd
  correlation on the OTel side, if ever wanted, requires either injecting `OTEL_RESOURCE_ATTRIBUTES`
  at Claude Code launch (out of this repo's control) or relying on the fact that `session.id` is
  already effectively 1:1 with a launch cwd (a session rarely changes cwd mid-session; `CwdChanged`
  is its own rare hook event). (b) Prompt/response content is redacted by default
  (`OTEL_LOG_USER_PROMPTS`/`OTEL_LOG_ASSISTANT_RESPONSES`/`OTEL_LOG_TOOL_DETAILS` opt-in), matching
  the task's framing. (c) `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1` + `OTEL_TRACES_EXPORTER=otlp`
  produces `claude_code.interaction`/`claude_code.llm_request`/`claude_code.tool`/`claude_code.hook`
  spans — confirmed still beta, confirming the "do not rebuild as a span/trace system" constraint
  is about *this* mechanism specifically, not a hypothetical.
- `code.claude.com/docs/en/hooks` (fetched in full): confirms all ~30 event types and the exact
  common-field contract quoted in the Executive Summary
  (`session_id, prompt_id, transcript_path, cwd, permission_mode, hook_event_name`), and confirms
  verbatim the `last_assistant_message`-on-Stop/SubagentStop rationale the task description cites:
  "The transcript file is written asynchronously and may lag the in-memory conversation."
- Sibling report 873 (`specs/873_.../reports/01_global_default_target_resolution.md`, read in
  full): source of the `GLOBAL_ROOT`/`cd`-chaining/`--local` mechanism this task consumes, and of
  finding (c) on subagent Bash-tool cwd non-persistence (GitHub issue #12748) that this task's
  `--meta`/`--revise` designs must respect identically.

### Recommendations

#### 1. The OTel <-> events.jsonl seam — exact field ownership and join

**OTel owns** (read via `CLAUDE_CODE_ENABLE_TELEMETRY=1` export/collector, never written by
agent-system code): per-tool-call outcome (`tool_result.success`, `.error_type`, `.duration_ms`,
`.decision_source`), per-API-call outcome (`api_request`/`api_error`/`api_refusal`), token/cost
accounting (`claude_code.token.usage`, `.cost.usage`), permission/decision provenance
(`tool_decision.source`, `permission_mode_changed`), and session-level aggregates
(`claude_code.session.count`, `.active_time.total`). This is exactly "did-it-fail-and-why" and
nothing task/phase/plan-shaped — OTel has no concept of a task number, a phase, or a plan
deviation.

**events.jsonl owns** (unchanged categories `deviation`/`blocker`/`milestone`/`success`, unchanged
`task`/`checkpoint` fields): task numbers, phase/checkpoint boundaries, plan deviations,
completion-time reflections (`event_type: "reflection"`), and — new in this design — the repo tag
(`cwd`, see below). OTel structurally cannot know any of these; they are agent-system semantics
layered on top of raw Claude Code activity.

**The exact join** (settling "join on session_id + cwd" precisely): add two new optional fields to
`events-schema.json` —
```json
"cc_session_id": {
  "type": ["string", "null"],
  "description": "Claude Code's own native session UUID (hook stdin `.session_id`; same id space as OTel's `session.id` resource attribute and history.jsonl's `sessionId`). Distinct from this schema's `session_id`, which is the agent-system's sess_{ts}_{random} id. Null for events emitted outside any Claude Code hook context."
},
"cwd": {
  "type": ["string", "null"],
  "description": "Absolute working directory at the moment the underlying hook fired (hook stdin `.cwd`). Doubles as the repo tag: the source of truth for which repo this event belongs to. Null when not captured (e.g. events predating this field)."
}
```
captured by both `events-log-lifecycle.sh` and `events-log-artifact.sh` from their own already-parsed
hook stdin (`STDIN_JSON`/`INPUT` in the current code) and threaded through two new optional
`events-append.sh` flags (`--cc-session-id`, `--cwd`), defaulting to `null` when absent (matching
every other optional field's `if $x == "" then null` pattern already in the script). The join is
then **exact**: `cc_session_id` on an `events.jsonl` line equals `session.id` on OTel
events/spans/metrics for the same Claude Code session — no time-window heuristic needed. `cwd`
serves as (a) a defense-in-depth secondary correlator for the rare `CwdChanged` mid-session case
and (b) the repo-tag value `--meta`/`--review` filter on directly, without needing OTel's
non-standard `OTEL_RESOURCE_ATTRIBUTES` opt-in at all.

**Compatibility note (must be flagged explicitly in the plan)**: `events-schema.json`'s top-level
object is `"additionalProperties": false`. Adding these two fields is a deliberate, versioned
schema revision — unlike `detail`, which absorbs new shapes silently. Existing `events.jsonl` lines
written before this change simply have `cc_session_id`/`cwd` absent (both nullable), so no
backfill or migration is required; `events-query.sh` consumers must treat both as
optionally-absent from day one.

**`gen_ai.*` naming**: borrowed only as literal keys **inside `detail`** (already
`additionalProperties: true`, open by design), and only for `detail` payloads that explicitly
mirror/cite OTel-derived evidence (e.g. a `--revise` correlation event's `detail` citing
`{"gen_ai.usage.input_tokens": 1200, "error.type": "ENOENT"}` alongside the existing
`event_id`/`message` evidence citation). Never introduced as a top-level `events.jsonl` field name
(the schema's flat `snake_case` convention — `event_id`, `session_id`, `duration_seconds` — is kept
uniform). This satisfies "borrow OTel GenAI field names only, do not rebuild as a span/trace
system": the vocabulary is borrowed for cross-referencing, the storage model stays this
codebase's existing flat-JSONL convention.

#### 2. Source contract per flag (12 sub-modes total)

| Sub-mode | Status | Primary tier(s) consumed | Notes |
|---|---|---|---|
| `report` (bare) | Existing, **unchanged** | `.memory/*` only | No telemetry integration — below the ~100-entry automation threshold. |
| `purge` | Existing, **unchanged** | `.memory/*` only | Per binding constraint. |
| `merge` | Existing, **unchanged** | `.memory/*` only | Per binding constraint. |
| `compress` | Existing, **unchanged** | `.memory/*` only | Per binding constraint. |
| `refine` | Existing, **unchanged** | `.memory/*` only | Per binding constraint. |
| `gc` | Existing, **unchanged** | `.memory/*` only | Per binding constraint. |
| `auto` | Existing, **unchanged** | `.memory/*` only | Tier 1 refine only, as today. |
| `--revise` | Redefined (was half of `dream`) | Tier 2 (events.jsonl) primary; **Tier 1 (OTel) new** — outcome evidence via `cc_session_id` join, e.g. citing a `tool_result.error_type` alongside a `deviation` event when classifying a memory `contradicted` | Inherits corroborated/contradicted/gap classification, three-strikes threshold, `AskUserQuestion` UPDATE/TOMBSTONE/CREATE gate verbatim from current `dream` lines 2102-2271. |
| `--meta` | Redefined (was half of `dream`) | Tier 2 (events.jsonl) primary, scoped to `$GLOBAL_ROOT`'s own `specs/events.jsonl` (see caveat below); optionally Tier 1 for system-wide hook/tool-decision patterns in that same repo | Discovery unchanged from current "Improvement Proposals" (2273-2325); **task creation now delegates to `meta-builder-agent` via the Agent tool** (873's mechanism: `cd "$GLOBAL_ROOT" && ...` chained, never a distant `cd`) instead of hand-rolling the `/task` primitive. Checks which of the 19 extensions to contribute to (via `meta-builder-agent`'s existing component-detection, not new logic) before proposing. |
| `--dream` | Redefined, genuinely new content | **Tier 3 (history.jsonl) primary** — durable global prompt spine, cwd/project-filterable, 23,758+ prompts across 7 months/33 projects | Speculative "new directions" only: surfaces recurring themes/interests in the user's own prompt history that have no corresponding memory or task yet — brainstorming, not event-correlated revision. No `AskUserQuestion` mutation gate needed at the surfacing step (nothing mutates); any resulting action funnels to `--meta` (proposal) or `/learn` (new memory), never applies directly. |
| `--review` | New | **All four tiers, on demand** | Read-only ad hoc inquiry ("why did X happen", "what does the vault say about Y") — the one sub-mode that legitimately spans OTel + events.jsonl + history.jsonl + transcripts live, per the user's specific question. Never proposes or writes; this is what keeps it distinct from `report` (fixed structured output) and from `--meta`/`--revise` (which do propose writes). |
| `--learn` | New | **Tier 4 (transcripts/.meta.json, 30-day window) primary; Tier 3 (history.jsonl) fallback beyond 30 days** | Retroactive/batch harvest across already-*completed* (archived) tasks whose `memory_candidates` were never harvested (declined, skipped, or predating the harvest mechanism) — distinct from `/learn --task N` (single task, any time, artifact-driven) and `/todo`'s archive-time harvest (automatic, at the moment of archival only, reads only `memory_candidates` already present). Once a task's transcript has rolled past the 30-day window, only `history.jsonl`'s prompt-level record and the task's own archived `specs/` artifacts remain as source. |

**`--meta` cross-repo caveat (must be documented, not solved here)**: `events.jsonl` is per-repo —
there is no unified, cross-repo event store. `--meta` invoked from `$GLOBAL_ROOT` sees only
`$GLOBAL_ROOT`'s own `specs/events.jsonl`, not aggregated signal from the ~14 other repos this
agent system runs in. This is a real scope limit, not a design gap to close in this task — flag it
as a residual risk (below) and a candidate follow-up (a cross-repo event aggregation pass is
explicitly out of scope for 887's file_scope).

#### 3. GLOBAL_ROOT/cd resolution for memory/event scripts — CONFIRMED sufficient, with one hardening

873's mechanism fully resolves cross-repo access for all four scripts **as long as every call site
keeps the existing relative-path convention and chains `cd` + invocation in one Bash call** (see
Codebase Patterns above for the mechanism). No script-level change is required to `memory-retrieve.sh`,
`memory-harvest.sh`, `events-query.sh`, or `events-append.sh` themselves — they already resolve
correctly once cwd is correct at invocation time. The one hardening this design adds: any new
`--meta`/`--revise`/`--review` call site that needs `$GLOBAL_ROOT`'s vault/event-store MUST follow
the exact `GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"; cd "$GLOBAL_ROOT" &&
bash .claude/scripts/{memory-retrieve,memory-harvest,events-query,events-append}.sh ...` chained
form 873 specifies for its own git-commit case — never invoke these scripts with an absolute path
(which would silently defeat the cwd-based resolution and always resolve to wherever the absolute
path points, ignoring `$GLOBAL_ROOT` entirely) and never rely on an earlier, separately-invoked `cd`.

#### 4. skill-learn/skill-distill split

Split `skill-memory/SKILL.md` (2,941 lines) along its existing mode boundary: everything before
`## Mode: distill` (line 1063) — Content Mapping, Memory Search, Memory Operations, Task/Directory/
Text/File Mode Execution, Error Handling — becomes `skill-learn/SKILL.md`; everything from line
1063 onward becomes `skill-distill/SKILL.md`. Both commands (`/learn`, `/distill`) already route to
a single skill today (`commands/learn.md` and `commands/distill.md` both name `skill-memory`) — the
split changes only which skill file each command's `Delegates To` line names, with no change to the
commands' own argument-parsing contracts.

**Reorder `skill-distill/SKILL.md` to be contiguous by sub-mode**, closing the non-contiguity
finding above: dispatch table, then `report`, `purge`, `merge`, `compress`, `refine`, `gc`, `auto`
(the unchanged six, in dispatch-table order, `purge` immediately followed by `gc` as its logical
pair), then the three telemetry-sourced sub-modes `--revise`, `--meta`, `--dream`, then `--review`
and `--learn`.

**Factor the repeated per-sub-mode skeleton into one shared section**, referenced by name rather
than restated: the task description's own six-step skeleton — Edge Case Checks -> Candidate
Identification -> Dry-Run -> Interactive Selection MANDATORY STOP -> Execution -> Batch Index
Regeneration -> Log Entry — is confirmed present near-verbatim in `merge` (1320-1527), `compress`
(1574-1691+), `refine`, and `dream`'s revision half. A single `## Shared Sub-Mode Skeleton` section
(placed once, before the first sub-mode) states the seven-step shape generically with named
placeholders (`{candidate_identification_logic}`, `{dry_run_format}`, etc.), and each sub-mode
section is reduced to only its deltas from that skeleton — mirroring the existing "reference the
`### Overlap Scoring` section by name — do not restate or fork the formula" convention already
used once in the current `dream` section (line 2165) and generalizing it into the section-wide
factoring rule the task asks for.

## Decisions

- `events.jsonl` gains two new, nullable, additive-but-schema-versioned fields (`cc_session_id`,
  `cwd`) captured from existing, already-parsed hook stdin in `events-log-lifecycle.sh` and
  `events-log-artifact.sh` — no new hook registrations needed.
- The OTel <-> events.jsonl join is `cc_session_id` (exact), with `cwd` as a secondary
  correlator/repo-tag source — not a `sess_*`-based join (confirmed dead end, not revived) and not
  a time-window heuristic (unnecessary once `cc_session_id` is captured).
- `gen_ai.*` names are borrowed only inside `detail` payloads that explicitly cite OTel evidence;
  top-level `events.jsonl` fields keep the existing flat `snake_case` convention.
- No changes are needed to `memory-retrieve.sh`, `memory-harvest.sh`, `events-query.sh`, or
  `events-append.sh` themselves for cross-repo resolution — only a documented invocation
  discipline (chained `cd` + relative-path call) at every new call site.
- `--revise` and `--meta` are the current `dream` sub-mode's two existing halves, renamed and
  extended (OTel evidence for `--revise`; cross-repo delegation to `meta-builder-agent` for
  `--meta`); `--dream` is redefined to source from `history.jsonl` for speculative direction-finding
  only, with no event-correlation machinery of its own.
- `--review` is the one sub-mode that legitimately spans all four tiers live, distinguished from
  `report` by being open-ended/read-only-inquiry rather than fixed-format.
- `--learn` sources primarily from Tier 4 transcripts within the 30-day window, falling back to
  Tier 3 `history.jsonl` beyond it, and is scoped to *already-archived* tasks whose memory
  candidates were never harvested — distinct from both `/learn --task N` and `/todo`'s
  archive-time harvest.
- The six existing hygiene sub-modes (`report`/`purge`/`merge`/`compress`/`refine`/`gc`/`auto`)
  get zero source changes, per the binding no-new-hygiene-below-~100-entries constraint.
- `skill-memory/SKILL.md` splits at its existing `## Mode: distill` boundary (line 1063) into
  `skill-learn` and `skill-distill`; `skill-distill` is additionally reordered to contiguous
  sub-mode sections and factored around one shared skeleton section.

## Risks & Mitigations

- **Risk**: `--meta`'s events.jsonl signal is single-repo only (no cross-repo aggregation exists).
  **Mitigation**: document the limitation explicitly in the flag's own description; do not imply
  system-wide coverage. A cross-repo event aggregation task is a plausible, separate follow-up —
  not attempted here (out of 887's file_scope).
- **Risk**: the `events-schema.json` revision (`additionalProperties: false` + two new fields) is a
  breaking-adjacent change to a schema other tooling may validate against strictly.
  **Mitigation**: both new fields are nullable and optional; any strict validator must be updated
  in the same implementation pass — call this out explicitly as an implementation-plan checklist
  item, not an afterthought.
- **Risk**: per the ~70% v1 miss-rate precedent (productowner.ro), `--revise`'s OTel-evidenced
  classification and `--meta`'s recurring-pattern discovery will both under-detect real friction on
  v1. **Mitigation**: design (already reflected above) treats both as propose-then-human-review
  with a mandatory `AskUserQuestion` gate, never auto-apply — consistent with Lilian Weng's
  "evaluator outside the loop" hard rule and the documented 220-loop metric-fabrication anti-pattern
  the task cites. Iteration, not one-shot precision, is the explicit design goal.
- **Risk**: adding OTel as a `--revise` evidence source assumes `CLAUDE_CODE_ENABLE_TELEMETRY=1`
  is actually set in the user's environment; if unset, this tier silently contributes nothing.
  **Mitigation**: `--revise` must degrade the same way the current `dream` section already
  documents for "No Events Yet" (lines 2134-2152) — a normal, first-class, explicitly-announced
  outcome, not a silent gap. The same degraded-path pattern generalizes directly to "OTel not
  enabled."

## Context Extension Recommendations

- **Topic**: OTel/events.jsonl join mechanics
- **Gap**: No existing context file documents the `cc_session_id`/`cwd` seam design once
  implemented — `events-format.md` will need a new section once the schema revision lands.
- **Recommendation**: when this design is implemented, extend `context/formats/events-format.md`
  with a "Claude Code OTel Correlation" section documenting the two new fields, the exact-join
  contract, and the degraded-path behavior when OTel is not enabled — mirroring the existing
  "No Events Yet (Degraded Path)" pattern already established for `dream`/`--revise`.

## Appendix

**Files read in full**: `agent-system/extensions/memory/skills/skill-memory/SKILL.md` (targeted
full sections: header/dispatch 1-1090, sub-mode headers via grep across the whole file, `dream`
section 2085-2391 in full), `agent-system/extensions/memory/commands/distill.md`,
`agent-system/extensions/memory/manifest.json`, `agent-system/extensions/core/scripts/
memory-retrieve.sh`, `agent-system/extensions/core/scripts/events-append.sh`,
`agent-system/extensions/core/hooks/events-log-lifecycle.sh`, `agent-system/extensions/core/hooks/
events-log-artifact.sh`, `agent-system/extensions/core/context/formats/events-format.md`,
`agent-system/extensions/core/context/schemas/events-schema.json`,
`agent-system/extensions/core/commands/meta.md`, `agent-system/extensions/core/skills/skill-meta/
SKILL.md` (Sections 1-3), sibling report `specs/873_.../reports/01_global_default_target_resolution.md`.

**Files spot-read / grepped**: `agent-system/extensions/memory/index-entries.json`,
`agent-system/extensions/memory/EXTENSION.md`, `agent-system/extensions/core/agents/
meta-builder-agent.md` (line count only), `agent-system/extensions/memory/commands/learn.md`
(`--task` section), `agent-system/extensions/core/skills/skill-todo/SKILL.md` (harvest sections),
`~/.claude/history.jsonl` (head sample), `~/.claude/projects/**/*.meta.json` (2 samples).

**Live environment checks**: `~/.claude/history.jsonl` line shape (23,771 lines confirmed present),
`~/.claude/projects/*/subagents/*.meta.json` shape, extension directory count (19 via `ls -d
agent-system/extensions/*/`).

**Web sources fetched in full**: `code.claude.com/docs/en/monitoring-usage` (OTel event/metric
reference), `code.claude.com/docs/en/hooks` (hook event list + common-field contract +
Stop/SubagentStop `last_assistant_message` rationale).

**Searches performed**: `grep -rn "memory-retrieve.sh\|memory-harvest.sh\|events-query.sh\|
events-append.sh"` across `agent-system/extensions/`; `grep -n "^## \|^### "` across
`skill-memory/SKILL.md` for section-boundary mapping; `grep -rln "OTel\|OTEL\|
CLAUDE_CODE_ENABLE_TELEMETRY\|gen_ai\."` across `agent-system/` (zero pre-existing hits, confirming
this is genuinely new territory for the codebase).
