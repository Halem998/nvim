# Research Report: Task #867

**Task**: 867 - Add sparse-literature detection to --lit and reconcile the drifted Stage 4a flow
**Started**: 2026-07-15T06:40:00Z
**Completed**: 2026-07-15T07:22:00Z
**Effort**: ~2 hours (research only)
**Dependencies**: 866 (complete — `literature-ingest-online.sh` bridge exists with a STABLE CONTRACT header)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/literature/scripts/literature-lit-flag-resolve.sh`,
  `literature-briefing.sh`, `literature-briefing-invoke.sh`, `literature-ingest-online.sh`,
  `literature-discover.sh`, `literature-search.sh`, `literature-create-setup-task.sh`
- Codebase: `agent-system/extensions/core/skills/{skill-researcher,skill-planner,skill-implementer}{,-hard}/SKILL.md`
- Codebase: `agent-system/extensions/literature/EXTENSION.md`,
  `agent-system/extensions/core/merge-sources/claudemd.md` (CLAUDE.md merge source)
- Codebase: `agent-system/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md`
- Codebase: `agent-system/extensions/core/skills/skill-orchestrate{,-hard}/SKILL.md`,
  `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- `.claude-extensions.json` (current pinned extension set)
**Artifacts**: - this report
**Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- The task's premise is confirmed exactly as described: `literature-lit-flag-resolve.sh` classifies
  purely on `[ -f ... ]` file existence with 5 directives and no count/threshold logic at all;
  `literature-briefing.sh` computes `seg_count` internally (global mode, line 311) but never prints
  it anywhere machine-readable, and the per-repo mode has no equivalent count surfaced either.
- All six `--lit` skills (`skill-researcher`, `skill-planner`, `skill-implementer`, and their
  `-hard` variants) are drifted from the design documented in CLAUDE.md's merge source and
  `adhoc-navigation-directive.md`: none of their Stage 4a blocks actually invoke
  `literature-lit-flag-resolve.sh`. Instead each reimplements a *subset* of the classification
  inline via raw `[ -f ... ]` checks, has **no `orchestrator_mode`/`AUTONOMOUS_GLOBAL` branch at
  all**, and buries the "Use global corpus now" / "Create curation task" / "Skip this run"
  `AskUserQuestion` as a **commented-out pseudocode block inside a bash fence** rather than as an
  executable instruction — so today it effectively never fires.
- A second, independent drift was found: 4 of 6 skills (`skill-researcher` and all three `-hard`
  variants) still call the raw `literature-briefing.sh 2>/dev/null` pattern the
  `literature-briefing-invoke.sh` wrapper was built to replace (silently swallowing script
  crashes), while `skill-planner`/`skill-implementer` correctly use the wrapper. This must be
  reconciled to all six calling the wrapper.
- A latent conflict was found in `skill-orchestrate`/`skill-orchestrate-hard`: the `orchestrator_mode`
  delegation-context field is `false` for research/plan dispatches and `true` only for implement
  dispatches (its established, narrower purpose: gating `.orchestrator-handoff.json` writes). If
  Stage 4a starts trusting this same field to select `AUTONOMOUS_GLOBAL` vs `PROMPT_NEEDED`, a
  fully autonomous `/orchestrate --lit` run would incorrectly attempt `AskUserQuestion` during its
  research/plan phases — reintroducing exactly the silent-hang risk this task is designed to
  eliminate. This must be fixed as part of the wiring work (see Decisions).
- `literature-ingest-online.sh` (task 866) is a stable, well-documented bridge that consumes ONE
  `literature-discover.sh` record and returns one of 9 directive tokens / exit codes 0–6/64. The
  new "Search online to ingest" option must chain `literature-discover.sh "<query>"` →
  per-record `literature-ingest-online.sh --record '<json>'` → re-run `literature-briefing.sh`
  to refresh the (hopefully now non-sparse) briefing.
- Recommended design: add a `--count-only` (or similar) machine-readable mode to
  `literature-briefing.sh` that both `literature-lit-flag-resolve.sh` and the skills can call
  cheaply; extend the resolver to actually run this count (not just check file existence) and
  emit a new `SPARSE_PROMPT_NEEDED` directive, gated by a `LITERATURE_SPARSE_THRESHOLD` env var
  (default 3, following the `LITERATURE_LIMIT`/`DISCOVER_LIMIT` env-var-default precedent already
  used in this extension).

## Context & Scope

This is a design/specification task (no implementation performed — this is the `/research`
phase). The work touches the *source* tree (`agent-system/extensions/...`); `.claude/` is a
generated, gitignored deploy tree (per the recent "gitignore and untrack the .claude/ deploy
tree" commit) and must never be hand-edited. Note also: the `literature` extension is **not**
currently in the pinned selection in `.claude-extensions.json` (only `memory`, `core`, `email`,
`nvim`, `nix` are listed) — the deployed `.claude/CLAUDE.md` content shown in this session's
system context reflects a stale/prior deployment of the literature extension's merge-source
content, not the current pin state. This is out of scope for task 867 (it is a deployment/picker
concern, not a source-authoring concern) but is worth flagging since it explains why `.claude/scripts/`
in this checkout does not currently contain the literature scripts at all — all investigation for
this task was correctly done against `agent-system/extensions/literature/` and
`agent-system/extensions/core/skills/`, matching the task's explicit file-scope list.

Task 866 (dependency) is confirmed COMPLETE: `agent-system/extensions/literature/scripts/literature-ingest-online.sh`
exists with the STABLE CONTRACT header described in the task prompt.

## Findings

### 1. `literature-lit-flag-resolve.sh` — current shape (confirmed as described)

Full file read (111 lines). Classification is a straight-line `if`/`elif` chain over three
`[ -f PATH ]` existence checks plus the `--orchestrator-mode` argument:

1. `lit_flag != "true"` → `LIT_DISABLED`
2. `specs/literature-index.json` exists → `SUBINDEX_PRESENT` (no inspection of its *contents* —
   an empty `{"entries": []}` sub-index is treated identically to a rich one)
3. neither sub-index nor `$LITERATURE_DIR/index.json` exists → `GLOBAL_MISSING`
4. sub-index absent, global index present, `orchestrator_mode == "true"` → `AUTONOMOUS_GLOBAL`
5. sub-index absent, global index present, otherwise → `PROMPT_NEEDED`

No numeric threshold, no chunk/segment count, anywhere in this script. `SUBINDEX_PRESENT` is a
pure existence check — a sub-index with 1 stale/irrelevant entry is indistinguishable from one
with 40 well-matched entries under the current logic. This is gap #1 the task names.

### 2. `literature-briefing.sh` — internal counts never surfaced (confirmed)

431-line script, two modes sharing one output path:

- **Global mode** (`--global "<query>"`): computes `seg_count=$(echo "$results_json" | jq
  'length')` at line 311, used only to (a) decide whether to truncate to `--top-n` (default 8,
  `GLOBAL_TOP_N_DEFAULT`) and (b) populate the human-readable header line
  `## Available Literature — Global Corpus Search Results for: "<query>" (N segment(s))`. The
  count is never emitted as a separate machine-parseable token — a caller would have to scrape
  the markdown header text to recover it, which is fragile and undocumented.
- **Per-repo mode** (`SUBINDEX_PRESENT` path): builds `briefing_lines[]` from
  `specs/literature-index.json` entries resolved against the global index; the final count is
  `${#briefing_lines[@]}`, used only for the `## Available Literature (N document(s))` header.
  Same problem: no machine-readable count, and no way to distinguish "3 well-matched docs" from
  "3 barely-related docs" — the sub-index's `.relevance` field is free text, not a score.
- Both modes already follow a "loud, never silent" precedent worth reusing for the new sparse
  signal: the `[UNVERIFIED - provenance_fidelity: ...]` marker (`FIDELITY_MARKER_TEXT`,
  lines 117-119) and the `[DEGRADED RETRIEVAL - fallback_tier: ...]` banner (lines 353-372) are
  both prepended directly into the rendered briefing content — visible to the consuming agent,
  never a silently-dropped signal. A `[SPARSE COVERAGE ...]` banner in the same family is the
  natural fit for surfacing sparsity *inside* the briefing text, in addition to a separate
  machine-readable count for the resolver/skills to branch on.

### 3. Six `--lit` skills — Stage 4a is drifted from the documented design (confirmed, and worse than described)

All six SKILL.md files (`skill-researcher`, `skill-planner`, `skill-implementer`,
`skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard`) have a near-identical
Stage 4a block (~70-110 lines) that:

- Never calls `literature-lit-flag-resolve.sh` at all — despite CLAUDE.md's merge source
  (`agent-system/extensions/core/merge-sources/claudemd.md` lines 354-400) and
  `adhoc-navigation-directive.md` (lines 79-89, "Sources of Truth") both stating unambiguously
  that Stage 4a "delegat[es] classification to `literature-lit-flag-resolve.sh`".
- Reimplements only 2 of the resolver's 5 directives inline: `[ ! -f specs/literature-index.json
  ]` → (if also `[ ! -f $GLOBAL_INDEX ]`) emit a stderr note and continue empty (≈`GLOBAL_MISSING`);
  otherwise fall into an `else` branch that is **entirely commented-out pseudocode** describing
  the 3-option `AskUserQuestion` (≈`PROMPT_NEEDED`) — there is no `AUTONOMOUS_GLOBAL` branch, no
  `orchestrator_mode` variable read anywhere in these six files' Stage 4a, and thus no
  `[lit:auto]` notice is ever emitted by any deployed skill today, contrary to what CLAUDE.md
  documents as an existing guarantee.
- Because the `AskUserQuestion` invocation lives inside a fenced ` ```bash ` block as a `#`-prefixed
  comment (lines 180-213 of `skill-researcher/SKILL.md`, materially identical in the other five),
  it reads as non-executable pseudocode rather than as a direct instruction to the agent — this
  is very likely *why* it drifted silently: an agent executing this stage would run the real `if`
  chain (which only ever sets `lit_context=""` or the `SUBINDEX_PRESENT` case), see the comment
  block, and have no clear signal that it must actually call `AskUserQuestion` right there.
- The `SUBINDEX_PRESENT` path (line ~243 in `skill-researcher`: `if [ "$lit_flag" = "true" ] &&
  [ -f "specs/literature-index.json" ]`) is a second, independent re-implementation of that one
  resolver directive, so the resolver script is doubly unused — even the directive it does
  correctly encode is never actually invoked by any of the six skills.

**Diff footnote**: `skill-planner` and `skill-implementer` are near-byte-identical to each other;
`skill-researcher`, `skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard` are
near-byte-identical to each other; the two families differ only in the second (script-name)
finding below.

### 4. Independent drift: inconsistent use of the failure-surfacing wrapper

`literature-briefing-invoke.sh` (42 lines) exists specifically to fix a documented anti-pattern:
callers historically ran `bash literature-briefing.sh 2>/dev/null || lit_context=""`, which
silently coerces "the script crashed" and "the briefing is legitimately empty" into the exact
same empty string. The wrapper preserves the empty-string fallback contract for callers but
surfaces failures via a `[lit] briefing generation failed (exit N)` stderr notice.

Only `skill-planner` and `skill-implementer` were updated to call
`literature-briefing-invoke.sh` (without `2>/dev/null`, correctly). `skill-researcher`,
`skill-researcher-hard`, `skill-planner-hard`, and `skill-implementer-hard` still call
`literature-briefing.sh 2>/dev/null` directly — the exact anti-pattern the wrapper exists to
retire. This must be reconciled to all six calling `literature-briefing-invoke.sh` consistently
as part of the Stage 4a rewrite this task requires anyway.

### 5. Latent `orchestrator_mode` semantic conflict (new finding, not in the original task description)

`orchestrator_mode` already has an established, narrower meaning in this codebase: it gates
whether a skill writes `.orchestrator-handoff.json` (see
`agent-system/extensions/core/docs/architecture/handoff-schema.md` line 181: "Skills MUST write
`.orchestrator-handoff.json` when and ONLY when `orchestrator_mode: true`"). Consistent with that
narrower purpose, `skill-orchestrate/SKILL.md`'s Stage 4 dispatch table sets
`orchestrator_mode: false` for the `not_started` (research) and `researched` (plan) dispatches
(lines 203, 232) and `orchestrator_mode: true` only for the `planned`/`implementing` (implement)
dispatch (line 253) and the `partial`-with-continuation dispatch (line 281).
`skill-orchestrate-hard/SKILL.md` mirrors this exactly (lines 332, 380 = false; line 427 = true).
Today no research/planner skill reads `orchestrator_mode` for any purpose, so this has no visible
effect yet.

However, CLAUDE.md's documented contract for the literature flag (and this task's deliverable 5)
requires: "When `orchestrator_mode == true` (e.g. `/orchestrate`), `AskUserQuestion` cannot prompt
a human, so the skill MUST NOT call it" — i.e. the *entire* `/orchestrate` run, including its
research and plan phases, is unattended. If Stage 4a is wired to read the delegation context's
`orchestrator_mode` field verbatim and pass it straight through to
`literature-lit-flag-resolve.sh --orchestrator-mode`, a `/orchestrate --lit` run would receive
`orchestrator_mode=false` during its research/plan phases and could select `PROMPT_NEEDED`
(or the new `SPARSE_PROMPT_NEEDED`) — attempting `AskUserQuestion` with no human present. That
is precisely the silent-hang failure mode this task is designed to prevent, just relocated one
layer up. This is a required companion fix, not an optional nice-to-have — see Decisions below.

### 6. `literature-ingest-online.sh` (task 866 bridge) — contract summary for wiring

Read in full (STABLE CONTRACT header, lines 1-107, plus argument parsing). Key facts for the new
"Search online to ingest" option:

- **Input**: exactly one JSON record from `literature-discover.sh`'s output array (not a batch);
  callers loop and invoke once per selected record. Required fields: `title`, `authors`, `year`,
  `doc_id`, `status` (`in_zotero_no_pdf` | `open_access` | `paywall` — `available`/`in_zotero`
  records are rejected, exit 64, since they need no bridge), `tier` (2 | 3), plus tier-3-only
  `doi`/`arxiv_id`/`pdf_url`.
- **Invocation**: `literature-ingest-online.sh --record '<json>' [--dry-run] [--idempotency-key
  KEY]` or via stdin.
- **Directive tokens / exit codes** (9 tokens, exit 0/1/2/3/4/5/6/64): success is
  `ONLINE_INGEST_INGESTED` (exit 0, create-item path) or `ONLINE_INGEST_ATTACHED` (exit 0,
  attach-to-existing path); everything else is a non-zero honest-stop with no partial side
  effects (`ONLINE_INGEST_NO_PDF` exit 1 is the "nothing found" case most relevant to a sparse
  Stage 4a flow).
- **`--dry-run`** stops after classification and previews the planned Zotero/ingest calls to
  stderr with no network/writes — useful for an `AUTONOMOUS_GLOBAL`-adjacent unattended path if
  the design wants a preview-only autonomous default rather than a live download (see Decisions).
- On success, the bridge registers into `specs/literature-index.json` sub-index itself (per its
  docstring: "sub-index registration"), so the natural post-ingest step for Stage 4a is simply to
  **re-run** `literature-briefing.sh` (per-repo mode now, since the sub-index will contain the
  newly ingested doc) rather than re-running the global search.

**Discovery step**: `literature-discover.sh "search terms"` (or `--task N`) is the natural
upstream step — its JSON output array's elements are exactly the bridge's input schema. The
"Search online to ingest" option therefore chains: `literature-discover.sh "<task description or
query>"` → filter/select records with `status` in `{open_access, paywall, in_zotero_no_pdf}` →
per-record `literature-ingest-online.sh --record '<json>'` → re-run
`literature-briefing.sh`/`literature-briefing-invoke.sh`.

## Decisions

These are proposed design decisions for the planning phase, not yet implemented:

1. **Surfacing the count** (deliverable 1): Add a machine-readable summary to
   `literature-briefing.sh` rather than scraping the markdown header. Recommended shape: a
   `--summary-only` flag (or a second stdout stream discipline) that prints a one-line JSON
   object `{"seg_count": N, "sparse": true|false, "mode": "repo"|"global"}` — OR, to avoid a new
   flag surface, have `literature-lit-flag-resolve.sh` itself compute the count directly (it
   already has the paths/query it needs) rather than shelling out to `literature-briefing.sh`
   twice. The research favors the resolver computing its own lightweight count (reusing the same
   `jq '.entries | length'` / `literature-search.sh` calls `literature-briefing.sh` already makes)
   over adding a new output mode to the briefing script, since the resolver is the single
   classification authority and the briefing script's job (render markdown) stays unchanged. The
   planning phase should weigh script-duplication cost against this separation-of-concerns
   benefit.
2. **Threshold config** (deliverable 2): Follow the existing `LITERATURE_LIMIT`/`DISCOVER_LIMIT`
   env-var-with-default precedent (`literature-search.sh` line 42, `literature-discover.sh` line
   37). Recommend `LITERATURE_SPARSE_THRESHOLD="${LITERATURE_SPARSE_THRESHOLD:-3}"` — fewer than 3
   relevant chunks/documents (repo mode) or fewer than 3 matched segments (global mode) counts as
   sparse. Document the env var alongside `LITERATURE_DIR` in both scripts' header comments and in
   EXTENSION.md.
3. **New directive `SPARSE_PROMPT_NEEDED`** (deliverable 3): Insert into
   `literature-lit-flag-resolve.sh`'s classification chain as a refinement of both existing
   "found something" branches:
   - `SUBINDEX_PRESENT` becomes conditional: if the sub-index's resolved chunk/doc count is
     `>= threshold`, still emit `SUBINDEX_PRESENT` (unchanged, no new dispatch needed by the
     skill); if `< threshold` (including 0, i.e. entries present but none resolve against the
     global index), emit `SPARSE_PROMPT_NEEDED` instead.
   - The global-search path currently has no directive of its own (skills reach it only via
     `PROMPT_NEEDED`'s user choice, or `AUTONOMOUS_GLOBAL`'s deterministic default) — after this
     task, a global search that itself returns `< threshold` segments should also route through
     `SPARSE_PROMPT_NEEDED` semantics (interactive: re-prompt with the new "Search online to
     ingest" option added; autonomous: see point 5 below). This likely means
     `SPARSE_PROMPT_NEEDED` is reachable from two different call sites/timings — once at initial
     classification (sub-index sparse) and once after a global search already ran (global sparse)
     — and the skill Stage 4a needs a second decision point after invoking
     `literature-briefing.sh --global`, not just a single up-front classification. Plan carefully
     for this two-checkpoint shape; it does not fit the resolver's current single-shot
     invocation model.
4. **Reconcile Stage 4a across all six skills** (deliverable 4): Rewrite the Stage 4a "Literature"
   sub-block in all six SKILL.md files to (a) call `literature-lit-flag-resolve.sh` for real, (b)
   branch on all 6 directives (5 existing + `SPARSE_PROMPT_NEEDED`) with actual `AskUserQuestion`
   tool calls issued as direct instructions (not comments inside a bash fence) for
   `PROMPT_NEEDED`/`SPARSE_PROMPT_NEEDED`, (c) add the new "Search online to ingest" option
   (wired to `literature-discover.sh` → `literature-ingest-online.sh` → re-briefing, per Finding
   6) alongside the existing "Use global corpus now" / "Create curation task" / "Skip this run"
   options, and (d) standardize all six on `literature-briefing-invoke.sh` (never the raw
   `literature-briefing.sh 2>/dev/null` pattern), closing Finding 4. Given the near-identical
   structure across the six files, consider extracting the ~100-line Stage 4a block into a single
   shared context/pattern file that all six `@`-import, rather than maintaining six divergent
   copies — this is very likely *how* the current drift happened (six independent copies, only
   two of which got the wrapper fix) and a shared file would make future changes self-reconciling.
5. **Preserve the autonomous contract** (deliverable 5): Fix the `orchestrator_mode` conflict
   found in Finding 5 as a prerequisite, not an afterthought. Two options, for the planning phase
   to choose between:
   - **(a)** Change `skill-orchestrate`/`skill-orchestrate-hard`'s Stage 4 dispatch context to
     pass `orchestrator_mode: true` uniformly for research/plan/implement dispatches (verified
     safe: no research/planner skill currently reads this field for any purpose, so this only
     activates the new literature-autonomy behavior and does not affect the existing
     handoff-file-writing gate, which only `skill-implementer` checks).
   - **(b)** Introduce a distinct field (e.g. `unattended: true`) for the literature
     autonomy check, computed once at the top of Stage 3 in each skill, so the two concerns never
     share a name. This avoids touching `skill-orchestrate` at all but adds a second
     autonomy-signaling field to the delegation-context schema.
   Recommend (a): it is a 4-line change (2 skills × 2 dispatch sites), reuses the field CLAUDE.md
   and `literature-lit-flag-resolve.sh` already document, and is lower-risk than growing the
   schema. Whichever is chosen, the resulting `[lit:auto]` notice must fire for every
   `/orchestrate --lit` phase (research, plan, implement), not just implement, to satisfy "never
   a silent no-op" for the whole autonomous lifecycle — not only its final phase.
6. **`--hard` variants get the same wiring, not a divergent one**: since the three `-hard` skills'
   Stage 4a is materially identical to their non-hard counterparts today, the reconciled block
   should be shared verbatim (see point 4's shared-file recommendation) rather than re-diverging.

## Risks & Mitigations

- **Risk**: Two-checkpoint sparsity detection (Decision 3) adds a second `AskUserQuestion`
  opportunity after a global search already ran, which could surprise a user who already answered
  once this run. **Mitigation**: only re-prompt on the *global* sparse path if the user's original
  choice was "Use global corpus now" (i.e., they already opted into a live search) — do not
  re-prompt after "Skip this run" or "Create curation task" outcomes.
- **Risk**: Fixing `orchestrator_mode: false → true` for research/plan dispatch (Decision 5a) is a
  behavior change to `skill-orchestrate`/`skill-orchestrate-hard`, outside this task's literal
  file-scope list (`agent-system/extensions/core/skills/` is listed, so `skill-orchestrate` is
  technically in-scope, but it is easy to miss since the task description names the six `--lit`
  skills specifically). **Mitigation**: the planning phase should explicitly add
  `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md` as touched files, and the
  hard-mode architecture docs (`handoff-schema.md`, `architecture-spec.md`) should get a one-line
  cross-reference noting `orchestrator_mode` now has two consumers (handoff-writing gate +
  literature-autonomy gate) so future readers do not "fix" one without checking the other.
- **Risk**: The "Search online to ingest" option performs live network calls (Semantic
  Scholar/Unpaywall/arXiv via `literature-discover.sh`, then a PDF download in
  `literature-ingest-online.sh`) from inside a research/plan/implement skill's Stage 4a — this is
  a heavier, slower, and less predictable operation than anything else currently in Stage 4a.
  **Mitigation**: gate it as an explicit user choice in interactive contexts (never auto-triggered
  by `SPARSE_PROMPT_NEEDED` alone), and in autonomous contexts default to the existing
  `AUTONOMOUS_GLOBAL`-style deterministic fallback (global search, not online ingestion) unless a
  future task explicitly opts autonomous runs into online ingestion — auto-downloading and
  auto-attaching to Zotero without human review is a meaningfully bigger blast radius than a
  read-only global corpus search and should not be the silent default.
- **Risk**: `SUBINDEX_PRESENT` sparsity requires actually resolving each sub-index `doc_id`
  against the global index to count "relevant chunks" — this duplicates
  `literature-briefing.sh`'s own resolution loop (Finding 2's per-repo mode). **Mitigation**:
  see Decision 1 — whichever component (resolver or briefing script) ends up owning the count
  should be the single source of truth the other calls into, not two independent
  re-implementations of the same jq queries (which is exactly how Finding 1/2's original gap and
  Finding 3's six-way skill drift both happened).

## Context Extension Recommendations

- **Topic**: Sparse-coverage detection and online-ingest escalation for `--lit`.
  **Gap**: `agent-system/extensions/literature/EXTENSION.md` currently has no mention of the
  `--lit` Stage 4a flow, the resolver directives, or (after this task) the sparsity threshold —
  all of that context lives only in `claudemd.md` (merge source) and
  `adhoc-navigation-directive.md`. **Recommendation**: add a short "Sparse-Coverage Detection"
  subsection to EXTENSION.md summarizing the `SPARSE_PROMPT_NEEDED` directive, the
  `LITERATURE_SPARSE_THRESHOLD` env var, and a cross-reference to `claudemd.md`'s fuller spec, so
  a reader of the extension's own README-equivalent isn't missing the feature entirely.
- **Topic**: `orchestrator_mode`'s dual consumers.
  **Gap**: `handoff-schema.md` and `architecture-spec.md` document `orchestrator_mode` as
  exclusively gating `.orchestrator-handoff.json` writes; once Decision 5a lands, it will also gate
  literature Stage 4a's `AskUserQuestion` eligibility. **Recommendation**: add a one-line
  cross-reference in `handoff-schema.md`'s `orchestrator_mode` section noting the second consumer,
  so future edits to `skill-orchestrate`'s dispatch context don't silently reintroduce Finding 5's
  conflict.

## Appendix

- Full-file reads: `literature-lit-flag-resolve.sh` (111 lines), `literature-briefing.sh` (431
  lines), `literature-ingest-online.sh` (header + arg parsing, lines 1-150),
  `literature-briefing-invoke.sh` (42 lines), `literature-create-setup-task.sh` (header, lines
  1-40), `EXTENSION.md` (121 lines), `adhoc-navigation-directive.md` (93 lines).
- Targeted reads: `skill-researcher/SKILL.md` lines 140-360 (Stage 4a through Stage 5 injection);
  grep-diff comparison of Stage 4a across all six skills confirmed near-identical structure with
  the two sub-families noted in Finding 3/4.
- `skill-orchestrate/SKILL.md` lines 180-300 (Stage 4 state-handler dispatch table);
  `skill-orchestrate-hard/SKILL.md` lines 320-430 (equivalent dispatch sites).
- `literature-discover.sh` header comment (lines 1-30) for the discovery-record schema consumed by
  the task 866 bridge.
- Env-var-default precedent: `literature-search.sh:42` (`LITERATURE_LIMIT`),
  `literature-discover.sh:37` (`DISCOVER_LIMIT`), `literature-briefing.sh:52`
  (`GLOBAL_TOP_N_DEFAULT`).
