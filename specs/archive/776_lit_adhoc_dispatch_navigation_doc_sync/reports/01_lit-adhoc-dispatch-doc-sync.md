# Research Report: Task #776

**Task**: 776 - Make --lit navigation work for ad-hoc dispatch and sync stale CLAUDE.md docs
**Started**: 2026-07-01
**Completed**: 2026-07-01
**Effort**: 3-6 hours
**Dependencies**: 775 (completed — documents interactive behavior 775 implements)
**Sources/Inputs**: Codebase read (scripts, skills, merge-sources, context patterns), task 775 artifacts
**Artifacts**: specs/776_lit_adhoc_dispatch_navigation_doc_sync/reports/01_lit-adhoc-dispatch-doc-sync.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Requirement 1 (ad-hoc dispatch)** is genuinely greenfield: no existing file, skill, or
  CLAUDE.md section covers what the primary/root Claude Code session should do when a user
  asks for literature/`--lit` behavior conversationally (outside `/research|/plan|/implement`
  Stage 4a). The fix is to add a new documentation-only "Literature Navigation Directive"
  pattern file that has the primary session **directly reuse** the two already-built task-775
  primitives — `literature-lit-flag-resolve.sh` (classification) and `literature-briefing.sh`
  (briefing generation, both per-repo and `--global` modes) — with `--orchestrator-mode false`
  always (a live user is present), and reference it from CLAUDE.md's Literature Mode section so
  the root session can find it.
- **Requirement 2 (CLAUDE.md doc sync)**: Task 775 already rewrote the "Interactive Sub-Index
  Setup Detection" subsection of `.claude/extensions/core/merge-sources/claudemd.md` (lines
  328–379) and left an explicit scoping note (lines 330–333) deferring the "What `--lit` Does"
  rewrite to this task. That subsection needs no further changes except removing the now-stale
  scoping note once "What `--lit` Does" is rewritten.
- **"What `--lit` Does"** (lines 313–327) still describes the fully-deprecated
  `literature-retrieve.sh` / `<literature-context>` static-dump model. `literature-retrieve.sh`
  is confirmed dead code — grep across all skill SKILL.md files (deployed and merge-source)
  shows zero remaining callers. It must be rewritten to describe the live
  `literature-briefing.sh` → `<literature-briefing>` navigate-on-demand model (both per-repo and
  `--global` sub-modes), matching the already-accurate "Interactive Sub-Index Setup Detection"
  section immediately below it.
- **Token-budget drift**: `literature-retrieve.sh` header/default is `TOKEN_BUDGET=8000` (and the
  global `~/Projects/Literature/index.json` also declares `"token_budget": 8000`), but CLAUDE.md
  says `TOKEN_BUDGET=4000`. Since the new briefing model has no comparable static token budget
  (the briefing itself is ~300 tokens; content is fetched on demand via `Read`/
  `literature-search.sh`), the correct fix is to **drop all `TOKEN_BUDGET`/`MAX_FILES` language**
  from "What `--lit` Does" rather than just correcting `4000` → `8000` — the number itself is no
  longer descriptive of live behavior.
- A related, pre-existing drift was found but is **out of scope** for 776's stated deliverables:
  all six `--lit`-aware skill mirrors under `.claude/extensions/core/skills/*` (the sync source
  per `.claude/docs/README.md` line 134) were **not** updated by task 775 — only the deployed
  copies under `.claude/skills/*` were. If "Load Core Agent System" sync runs again before this
  is fixed, it would silently revert 775's Stage 4a rewrite. Flagged as a risk, not a 776
  requirement (775's own summary explicitly deferred `.claude/CLAUDE.md` regeneration in the same
  way — no generator script was found on disk).

## Context & Scope

Task 775 (just completed, commit `7ef3d8aee` and phases `ff5da8bd9`..`98eccadb3`) built:
- `.claude/extensions/literature/scripts/literature-briefing.sh` (+ mirror
  `.claude/scripts/literature-briefing.sh`, byte-identical) — added `--global "<query>"
  [--top-n N]` mode.
- `.claude/extensions/literature/scripts/literature-lit-flag-resolve.sh` (+ identical mirror
  `.claude/scripts/literature-lit-flag-resolve.sh`) — a **pure classification** helper (no
  `AskUserQuestion` inside it) that prints one of five directive tokens.
- Rewrote Stage 4a in the **deployed** copies of all six skills (`.claude/skills/skill-researcher
  {,-hard}/SKILL.md`, `skill-planner{,-hard}`, `skill-implementer{,-hard}`) to branch on those
  tokens with a non-silent three-option `AskUserQuestion` flow.
- Rewrote only the "Interactive Sub-Index Setup Detection" subsection of
  `.claude/extensions/core/merge-sources/claudemd.md`, explicitly deferring "What `--lit` Does"
  to task 776 via an inline scoping note.

This task's scope is: (1) design and document a reusable ad-hoc/conversational literature
navigation directive for the primary session, and (2) finish the CLAUDE.md doc sync that 775
deliberately left half-done.

## Findings

### Requirement 1: Ad-hoc dispatch directive

#### Current state — nothing exists for this path

Grep for `conversationally|ad-hoc|ad hoc` across `.claude/**/*.md` returns no hits in the
literature/agent-system domain. `skill-orchestrator/SKILL.md` (`.claude/skills/skill-orchestrator/
SKILL.md`) is task-lookup/routing logic triggered by slash commands, not a home for
conversational literature handling. There is no "primary agent" or "root session" behavioral
doc anywhere under `.claude/context/orchestration/`. This confirms G3: the navigation logic
(AskUserQuestion three-option flow, directive resolution, briefing injection) is currently
reachable **only** from inside Stage 4a of the six skills, which only run when a slash command
(`/research`, `/plan`, `/implement`, `/orchestrate`) passes `--lit`.

#### The reusable primitives already exist and are directly callable outside a skill

Both task-775 scripts are generic, side-effect-free (except `AskUserQuestion`, which the caller
must issue) shell scripts with no dependency on being invoked from inside a skill's Stage 4a:

- `.claude/extensions/literature/scripts/literature-lit-flag-resolve.sh` (identical mirror at
  `.claude/scripts/literature-lit-flag-resolve.sh`), 111 lines. Interface:
  ```
  literature-lit-flag-resolve.sh --lit-flag <true|false> --orchestrator-mode <true|false> \
    --query "<text>"
  ```
  Prints exactly one of `LIT_DISABLED | SUBINDEX_PRESENT | GLOBAL_MISSING | PROMPT_NEEDED |
  AUTONOMOUS_GLOBAL` to stdout, rationale to stderr (lines 16–43 document the contract;
  classification logic at lines 82–110).
  - For the ad-hoc/conversational case, the primary session should **always** pass
    `--orchestrator-mode false` — a live user is present by definition (that is what makes it
    "conversational"), so `PROMPT_NEEDED` (never `AUTONOMOUS_GLOBAL`) is the branch that applies
    when the sub-index is missing but the global index exists. This satisfies the task's
    requirement that the ad-hoc path "must surface the SAME interactive question defined in
    task 775."
- `.claude/extensions/literature/scripts/literature-briefing.sh` (identical mirror
  `.claude/scripts/literature-briefing.sh`), 314 lines. Two modes, one shared output section
  (lines 278–313) that always terminates with the "How to Use" footer:
  - No-arg / per-repo mode (lines 88–228): reads `specs/literature-index.json` + global
    `index.json` metadata, emits per-document chunk-count/token-estimate/directory-path lines.
  - `--global "<query>" [--top-n N]` mode (lines 230–276): runs
    `literature-search.sh --project "<repo>" "<query>"` (script auto-retries unfiltered on zero
    project-scoped results — see `literature-search.sh` line 15–17 comment), takes the top
    `N` (default 8, `GLOBAL_TOP_N_DEFAULT` line 52) ranked chunks, and emits one entry per chunk
    with a direct `literature-search.sh --read <chunk_id>` command.
  - Both modes always emit a `<literature-briefing>...</literature-briefing>` block (never
    `<literature-context>`), and the block is never silently empty when invoked in global mode
    with zero results — line 290–293 explicitly states "No matching literature segments found."

There is therefore **no need for a new script**. Requirement 1 is a **documentation/procedure**
gap: something has to tell the primary session (a) that this procedure exists, (b) exactly which
scripts to call and in what order, and (c) how to route the resulting `<literature-briefing>`
block once built.

#### How Stage 4a currently generates `lit_context` (to mirror exactly)

`.claude/skills/skill-researcher/SKILL.md` Stage 4a (lines 146–278, directive branch case/esac
at lines 172–251 — this block is byte-identical across all six skills per the 775 summary):

```
directive=$(bash .claude/scripts/literature-lit-flag-resolve.sh \
  --lit-flag "$lit_flag" --orchestrator-mode "${orchestrator_mode:-false}" \
  --query "$description" 2>"$lit_rationale_file") || directive="GLOBAL_MISSING"

case "$directive" in
  LIT_DISABLED)      lit_context="" ;;
  SUBINDEX_PRESENT)  lit_context=$(bash .claude/scripts/literature-briefing.sh) ;;
  GLOBAL_MISSING)    echo "[lit] No literature available..." >&2; lit_context="" ;;
  PROMPT_NEEDED)     # AskUserQuestion inline, 3 options, then branch (see below)
  AUTONOMOUS_GLOBAL) echo "[lit:auto] ..." >&2
                      lit_context=$(bash .claude/scripts/literature-briefing.sh --global "$description")
esac
```

The `PROMPT_NEEDED` branch (skill lines ~192–238) issues `AskUserQuestion` with exactly three
options, in this order:
1. **"Use global corpus now"** (recommended default, listed first) → `lit_context=$(bash
   .claude/scripts/literature-briefing.sh --global "$description")`
2. **"Create curation task"** → `literature-create-setup-task.sh`, then Stage 4a-fork inline
   population (lines 254–275: fork agent reads global `index.json` + `specs/state.json`,
   writes `specs/literature-index.json`, marks the setup task completed), then `lit_context=
   $(bash .claude/scripts/literature-briefing.sh)` (no-arg) if population succeeded, else a
   visible non-silent notice.
3. **"Skip this run"** → explicit, logged `[lit] Skipped by user choice`; `lit_context=""`.

Then, in Stage 5 (skill lines 361–367): "If `lit_context` ... is non-empty, include it in the
prompt as a separate block ... Place the literature briefing block AFTER the memory context
block (if any) and BEFORE the task-specific instructions. Do NOT inject an empty
`<literature-briefing>` block."

**This is the exact procedure the new ad-hoc directive should describe**, minus the skill
plumbing (`$lit_flag`/`$description` variables, `.return-meta.json`) that only exists inside a
dispatched skill run.

#### Recommended design for the new directive

Create a new documentation-only pattern file (no new script needed):

- **Canonical**: `.claude/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md`
- **Mirror**: `.claude/context/project/literature/patterns/adhoc-navigation-directive.md`

This sits as a sibling to the existing `.claude/context/project/literature/patterns/
agent-exploration.md` (117 lines — canonical at
`.claude/extensions/literature/context/project/literature/patterns/agent-exploration.md`), which
already documents what a *dispatched* agent does once it *has* a `<literature-briefing>` block
in its prompt (search-first, read-selectively). The new file is the missing piece one level up:
what the **primary session** does to *produce* that block when there was no skill Stage 4a to do
it for them.

Recommended content outline:
1. **Trigger**: user asks, in conversation, to consult/search "the literature" / a paper /
   invoke `--lit`-like behavior, without the primary session currently being inside a
   `/research|/plan|/implement|/orchestrate --lit` dispatch (i.e., Stage 4a did not run).
2. **Procedure** (mirrors Stage 4a exactly, `--orchestrator-mode` hardcoded to `false`):
   - Run `literature-lit-flag-resolve.sh --lit-flag true --orchestrator-mode false --query
     "<user's request text>"`.
   - Branch on the returned directive using the *same* four live outcomes as Stage 4a
     (`AUTONOMOUS_GLOBAL` is unreachable here since `--orchestrator-mode` is always `false`):
     - `SUBINDEX_PRESENT` → `literature-briefing.sh` (no args).
     - `GLOBAL_MISSING` → visible chat notice ("no literature available"); do not proceed
       silently.
     - `PROMPT_NEEDED` → issue `AskUserQuestion` with the **identical** three options and
       wording as Stage 4a ("Use global corpus now" / "Create curation task" / "Skip this
       run"), so the interactive experience is indistinguishable from the formal `/research
       --lit` path (this is the explicit requirement — "surface the SAME interactive
       question").
     - `LIT_DISABLED` is not applicable (the primary session only runs this procedure when the
       user has, in effect, requested `--lit`-equivalent behavior, so `--lit-flag` is always
       `true` here).
3. **Routing the result** — two cases:
   - **Self-execution** (primary session answers directly, no subagent dispatch): use the
     resulting `<literature-briefing>` content itself — run `literature-search.sh` against the
     chosen corpus and `Read` the relevant segmented chunk files, per the existing
     `agent-exploration.md` "How to Explore Literature" steps (search first, read selectively).
   - **Subagent dispatch** (primary session uses the Agent tool / fork to hand the work to a
     research/implementation agent): inject the `<literature-briefing>` block into that
     subagent's prompt using the **same placement rule** as skill-researcher Stage 5 (lines
     361–367) — after `<memory-context>` (if any), before task-specific instructions. Never
     dispatch with an empty `<literature-briefing>` block.
4. **Non-silence invariant** (explicit, restated): no branch of this directive may result in
   literature being silently ignored (no notice) or a search being silently auto-run (no user
   choice when one is due) — matching the "must NOT silently inject nothing and must NOT
   silently auto-search" requirement verbatim.

#### Discoverability: how the primary session finds this directive

The literature extension's `index-entries.json` (`.claude/extensions/literature/
index-entries.json`) is the mechanism used to register `agent-exploration.md` for load-on-demand
by skills/agents/commands (entry confirmed at that file, `load_when.commands` includes
`/literature`, `/research`, `/plan`, `/implement`). However, this `load_when` mechanism is
designed for skill/agent/command-triggered loading, not for the primary session's own judgment
about a conversational request — and, as noted below, this extension's entries are not currently
merged into the deployed `.claude/context/index.json` at all (0 entries with `subdomain ==
"literature"` found there today, vs. the always-loaded root `.claude/CLAUDE.md`). The most
reliable place for the primary session to learn about this directive is therefore a direct
pointer from CLAUDE.md's "Literature Mode (`--lit`)" section (always loaded at session start) —
this dovetails with requirement 2's rewrite. Recommend adding one new short subsection there
(e.g. "Ad-Hoc / Conversational Literature Requests") that names the new file path and states the
one-line contract from item 2–4 above. Also add a normal `index-entries.json` entry for the new
file (same shape as the `agent-exploration.md` entry) so it is available for skill/agent-level
loading too, even though the primary-session path relies on the CLAUDE.md pointer rather than
`load_when` matching.

### Requirement 2: CLAUDE.md doc sync

File: `.claude/extensions/core/merge-sources/claudemd.md` (this is the single source that
regenerates `.claude/CLAUDE.md`'s "Literature Mode" section — confirmed via
`.claude/extensions/core/manifest.json` `merge_targets.claudemd` → target `.claude/CLAUDE.md`,
`section_id: "core"`). **Note**: 775's own summary
(`specs/775_lit_global_corpus_fallback_briefing/summaries/01_lit-global-corpus-briefing-summary.md`,
"Plan Deviations") confirms no generator script for this merge exists on disk — 775 edited only
the merge-source and deliberately left the deployed `.claude/CLAUDE.md` untouched, deferring
regeneration "to next extension load." **776 should follow the identical precedent**: edit only
`claudemd.md`; do not hand-edit the deployed `.claude/CLAUDE.md` (which is currently still fully
pre-775 — it retains the old three-option wording "Skip / Create setup task / Create task and
run now" rather than 775's "Use global corpus now / Create curation task / Skip this run").

#### "What `--lit` Does" (lines 313–327) — needs full rewrite

Current text (verbatim):
```
313: ## Literature Mode (`--lit`)
314:
315: Literature mode injects reference files from `specs/literature/` as `<literature-context>` into
316: agent prompts. Use this when a task involves implementing from a paper, specification, or
317: reference document.
318:
319: ### What `--lit` Does
320:
321: When `--lit` is passed to `/research`, `/plan`, `/implement`, or `/orchestrate`:
322: - `literature-retrieve.sh` reads all `.md` and `.txt` files from `specs/literature/`
323: - Files are included up to TOKEN_BUDGET=4000 tokens (MAX_FILES=10)
324: - A `<literature-context>` block is injected after `<memory-context>` (if any) and before
325:   task-specific instructions
326: - If `specs/literature/` does not exist or is empty, the flag is silently ignored (no error)
327: - If `specs/literature/` does not exist or is empty, the flag is silently ignored (no error)
```
(line 326 duplication is as-read from the file; verify exact line count when editing — content
spans lines 313–327.)

Every substantive claim here is stale:
- `literature-retrieve.sh` is dead code. Confirmed by grep: zero skill SKILL.md files (deployed
  `.claude/skills/*` or merge-source `.claude/extensions/core/skills/*`) reference it. Only three
  `.md` files in the whole tree still mention it: the deployed `.claude/CLAUDE.md`, this
  merge-source `claudemd.md`, and `.claude/context/guides/literature-organization.md` (the last
  is out of explicit scope for 776 but shares the identical drift — see Risks).
- `specs/literature/` (flat directory of `.md`/`.txt` files) is not the corpus the live system
  reads from at all — the live system reads from `specs/literature-index.json` (per-repo
  sub-index of `doc_id`s) resolved against the global, pre-segmented corpus at
  `$LITERATURE_DIR/index.json` (default `~/Projects/Literature/index.json`).
- `<literature-context>` (full-content injection) has been replaced by `<literature-briefing>`
  (metadata + on-demand navigation instructions) — confirmed by
  `.claude/context/project/literature/patterns/agent-exploration.md` line 9: "This replaces the
  old content-injection approach (`<literature-context>`) which blindly loaded all literature
  files up to a token budget."
- The silent-ignore behavior described in the last bullet is **exactly** what task 775 removed
  (that is the "no-silent-fallback" the task description references) — this bullet must not
  survive the rewrite.

Recommended replacement content (structure, not final prose):
- State the new model: `--lit` triggers a **live, navigate-on-demand briefing** — never a static
  content dump — against a corpus of pre-segmented literature chunks.
- Two source modes, matching `literature-briefing.sh`'s two modes:
  - Per-repo mode: sourced from `specs/literature-index.json` (curated sub-index of `doc_id`s
    relevant to this repo), resolved against `$LITERATURE_DIR/index.json` metadata.
  - Global-corpus mode: a live relevance search (`literature-briefing.sh --global "<query>"`)
    against the entire global corpus, used when no per-repo sub-index exists (see next
    subsection for the interactive decision that selects this mode).
- Both modes emit one `<literature-briefing>` block (never `<literature-context>`) containing
  document/chunk metadata plus a "How to Use" footer that instructs the agent to run
  `literature-search.sh` to search and `Read` specific chunk files on demand — no full-file
  content is injected.
- Injection placement is unchanged: after `<memory-context>` (if any), before task-specific
  instructions (this line from the old text is still accurate and should be kept, just
  re-anchored to `<literature-briefing>` instead of `<literature-context>`).
- If `--lit` is not passed (or resolves to `LIT_DISABLED`), nothing is injected — this remains
  accurate and should be kept, reworded to reference the directive-token model rather than
  "flag is silently ignored" (which is exactly the phrase 775 explicitly disallowed as user-facing
  behavior for the *missing-sub-index* case; keep it only for the *`--lit` not passed at all*
  case, where "nothing happens" is correct and expected, not a fallback).
- Cross-reference the "Interactive Sub-Index Setup Detection" subsection immediately below for
  what happens when the per-repo sub-index is missing (avoids duplicating 775's already-correct
  text).
- Drop `TOKEN_BUDGET`/`MAX_FILES` entirely (see token-budget drift below) rather than correcting
  the number.

#### "Interactive Sub-Index Setup Detection" (lines 328–379) — no changes needed

Already rewritten correctly by 775 to describe the five-directive model, the three-option
`AskUserQuestion` flow, and the `AUTONOMOUS_GLOBAL` autonomous default. The **only** change
needed here is removing the scoping note at lines 330–333:
```
330: > **Scoping note**: This section describes only the interactive decision flow for a missing
331: > per-repo sub-index. The broader `--lit` model description above ("What `--lit` Does" /
332: > `literature-retrieve.sh` narrative) is owned by task 776 and is intentionally left unchanged
333: > here.
```
This note exists solely to mark the boundary between 775's and 776's work; once 776 completes
the "What `--lit` Does" rewrite, the note is stale and should be deleted (its content is a
process artifact, not user-facing documentation).

#### Token-budget drift — three numbers, reconciled by removing the claim

| Location | Value | Status |
|----------|-------|--------|
| `.claude/extensions/core/scripts/literature-retrieve.sh` line 25 (+ mirror `.claude/scripts/literature-retrieve.sh` line 25) | `TOKEN_BUDGET=8000` | Dead code default (unused by any skill) |
| `~/Projects/Literature/index.json` line 4 | `"token_budget": 8000` | Read by `literature-retrieve.sh` line 50 to override the default (also dead-code-only consumer) |
| `.claude/extensions/core/merge-sources/claudemd.md` line 323 (+ deployed `.claude/CLAUDE.md`) | `TOKEN_BUDGET=4000` | Stale — never matched the script default (8000) even before deprecation |
| `.claude/context/guides/literature-organization.md` lines 163, 222 | `TOKEN_BUDGET=4000` | Same stale value, same root cause, **out of 776's explicit scope** but same drift |

Since `literature-retrieve.sh` is unused, correcting `4000` → `8000` would make CLAUDE.md
factually consistent with the (dead) script/index.json pair but would still describe behavior
that no longer occurs. The `--global` mode's actual limiting parameter is `--top-n` (default 8
**chunks**, not tokens — `GLOBAL_TOP_N_DEFAULT=8` in `literature-briefing.sh` line 52); the
per-repo mode has no limiting parameter at all (it lists every doc_id in the sub-index). The
correct reconciliation is to **remove the token-budget claim from "What `--lit` Does" entirely**
and, if a numeric limit is worth stating for the new model, cite `--top-n` (default 8) for the
global-corpus mode only.

### Related finding (out of scope, flag only): stale skill mirrors under `extensions/core/skills`

`.claude/docs/README.md` line 134 states sync ("Load Core Agent System") installs
`extensions/core/` content into the deployed `.claude/` layout — i.e. `extensions/core/skills/*`
is the sync **source**, `.claude/skills/*` is the deployed **target**. Diff confirms task 775
updated only the deployed targets:
```
skill-researcher: DIFFERS      skill-planner: DIFFERS      skill-implementer: DIFFERS
skill-researcher-hard: DIFFERS skill-planner-hard: DIFFERS skill-implementer-hard: DIFFERS
```
(all six pairs — `.claude/skills/{name}/SKILL.md` vs. `.claude/extensions/core/skills/{name}/
SKILL.md` — differ; the extensions/core copies retain the pre-775 Stage 4a). If "Load Core Agent
System" sync ever runs again before these are updated, it would silently revert 775's non-silent
`--lit` rewrite back to the old silent-fallback behavior. This is not named in 776's G3/G4 root
causes and 775's own summary treated the analogous `.claude/CLAUDE.md` lag as acceptable
("regeneration deferred to next extension load"), so this report flags it as a risk for
awareness/a possible fast-follow task rather than adding it to 776's required deliverables.
(Scripts, by contrast, are *not* affected: `literature-briefing.sh` and
`literature-lit-flag-resolve.sh` are byte-identical between `.claude/extensions/literature/
scripts/` and `.claude/scripts/` — only the six SKILL.md mirrors under `core` are stale.)

## Decisions

- Requirement 1 will be implemented as a new documentation-only pattern file (no new script) —
  the two task-775 scripts (`literature-lit-flag-resolve.sh`, `literature-briefing.sh`) are
  already sufficiently generic to call directly from the primary session.
- The ad-hoc directive will hardcode `--orchestrator-mode false` (never `AUTONOMOUS_GLOBAL`) —
  a conversational request implies a human is present to answer `AskUserQuestion`.
- The ad-hoc directive's `AskUserQuestion` wording must match Stage 4a's `PROMPT_NEEDED` options
  verbatim ("Use global corpus now" / "Create curation task" / "Skip this run") to satisfy "the
  SAME interactive question."
- Requirement 2 touches only `.claude/extensions/core/merge-sources/claudemd.md`, following
  775's own precedent of not hand-editing the deployed `.claude/CLAUDE.md`.
- Token-budget reconciliation = remove the stale `TOKEN_BUDGET`/`MAX_FILES` claim rather than
  just fixing the number, since the number no longer describes any live code path.
- The stale `extensions/core/skills/*` mirrors and `literature-organization.md` drift are
  reported as risks/follow-ups, not folded into 776's scope (not named in the task's G3/G4 root
  causes; scope creep risk).

## Risks & Mitigations

- **Risk**: New ad-hoc directive duplicates Stage 4a logic and drifts from it over time (two
  places describing the same branching). **Mitigation**: the new file should cite Stage 4a
  (`.claude/skills/skill-researcher/SKILL.md` Stage 4a, lines 146–278) as the source of truth for
  the exact directive-token semantics and only add the primary-session-specific routing (self-
  execution vs. subagent dispatch), not re-derive the classification logic in prose.
  `literature-lit-flag-resolve.sh` is the actual single source of truth for classification either
  way (both paths shell out to the same script).
- **Risk**: `extensions/core/skills/*` mirror staleness (see Related Finding) could resurface if
  a future sync runs before those six files are updated. **Mitigation**: explicitly note this in
  the implementation plan/summary as a known follow-up rather than silently ignoring it.
- **Risk**: Editing "What `--lit` Does" without removing the now-orphaned scoping note (lines
  330–333) leaves a confusing "task 776 will fix this" note in a file 776 just fixed.
  **Mitigation**: delete the note as part of this task's edit.

## Context Extension Recommendations

- **Topic**: Literature ad-hoc/conversational navigation for the primary session.
  **Gap**: No context file currently documents this path (confirmed absent from
  `.claude/context/orchestration/*` and `.claude/context/project/literature/patterns/*`).
  **Recommendation**: Create `.claude/extensions/literature/context/project/literature/patterns/
  adhoc-navigation-directive.md` (+ mirror `.claude/context/project/literature/patterns/
  adhoc-navigation-directive.md`), register it in `.claude/extensions/literature/
  index-entries.json` (same shape as the existing `agent-exploration.md` entry), and add a
  pointer subsection to it from CLAUDE.md's "Literature Mode (`--lit`)" section.
- **Topic**: `literature-organization.md` guide token-budget/model staleness.
  **Gap**: `.claude/context/guides/literature-organization.md` (lines 53, 102, 163, 196–224, 332)
  describes the identical deprecated `literature-retrieve.sh`/`<literature-context>`/
  `TOKEN_BUDGET=4000` model.
  **Recommendation**: File a small follow-up task (not part of 776) to sync this guide to the
  briefing model, since it is a distinct file from `claudemd.md` and editing it is not named in
  776's description.

## Appendix

### Search queries / commands used

- `find .claude -iname "*lit-flag-resolve*"`, `find .claude -iname "literature-briefing.sh"`,
  `find .claude -iname "claudemd.md"`
- `grep -n "Stage 4a" -A 100 .claude/extensions/core/skills/skill-researcher/SKILL.md`
- `git log --oneline -- .claude/skills/skill-researcher/SKILL.md .claude/extensions/core/skills/skill-researcher/SKILL.md`
- `diff .claude/skills/skill-researcher/SKILL.md .claude/extensions/core/skills/skill-researcher/SKILL.md`
- `diff .claude/scripts/literature-briefing.sh .claude/extensions/literature/scripts/literature-briefing.sh` (identical)
- `grep -n "TOKEN_BUDGET\|MAX_FILES" .claude/scripts/literature-retrieve.sh .claude/extensions/core/scripts/literature-retrieve.sh`
- `grep -n "token_budget" ~/Projects/Literature/index.json`
- `grep -rln "literature-retrieve.sh" .claude --include="*.md"`
- `jq -r '.entries[] | select(.path|test("literature"))' .claude/context/index.json`
- Read: `.claude/extensions/literature/scripts/literature-lit-flag-resolve.sh` (full, 111 lines),
  `.claude/extensions/literature/scripts/literature-briefing.sh` (full, 314 lines),
  `.claude/context/project/literature/patterns/agent-exploration.md` (full, 117 lines),
  `.claude/extensions/core/merge-sources/claudemd.md` (lines 313–420),
  `specs/775_lit_global_corpus_fallback_briefing/summaries/01_lit-global-corpus-briefing-summary.md`,
  `specs/775_lit_global_corpus_fallback_briefing/reports/01_lit-no-silent-fallback.md` (grep),
  `specs/775_lit_global_corpus_fallback_briefing/plans/01_lit-global-corpus-briefing.md` (grep)

### References

- `.claude/skills/skill-researcher/SKILL.md` — Stage 4a (lines 146–278), Stage 4a-fork
  (254–275), Stage 5 injection rule (361–367)
- `.claude/extensions/literature/scripts/literature-lit-flag-resolve.sh` — directive contract
  (16–43), classification (82–110)
- `.claude/extensions/literature/scripts/literature-briefing.sh` — per-repo mode (88–228),
  global mode (230–276), shared exit point (278–313)
- `.claude/extensions/literature/scripts/literature-create-setup-task.sh` — setup task creation
- `.claude/context/project/literature/patterns/agent-exploration.md` — dispatched-agent-side
  briefing usage pattern
- `.claude/extensions/core/merge-sources/claudemd.md` — lines 313–420 (Literature Mode section)
- `.claude/extensions/core/manifest.json` — `merge_targets.claudemd` (source/target mapping)
- `.claude/docs/README.md` line 134 — core extension sync direction
- `specs/775_lit_global_corpus_fallback_briefing/` — predecessor task artifacts
