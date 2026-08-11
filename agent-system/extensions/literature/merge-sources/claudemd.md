## Literature Extension

Version 2.0.0. Unified management of the global Literature/ repository (`~/Projects/Literature/`)
and per-repo sub-indices (`specs/literature-index.json`): source discovery, PDF/DJVU conversion,
FTS5-backed search, agent context briefing, and Zotero integration.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-literature | (direct execution) | Scan, convert, validate, index, discover, and integrate literature |
| skill-cite | (direct execution) | Verify citation claims against Literature/ and Zotero |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/literature` | `/literature` | Show status and index health (Mode B) |
| `/literature` | `/literature N` | Discover sources relevant to task N (Mode A) |
| `/literature` | `/literature "query"` | Discover sources matching a query (Mode A) |
| `/literature` | `/literature ~/path/to/file.pdf` | Ingest a specific PDF/DJVU (Mode B) |
| `/literature` | `/literature ~/dir/` | Ingest all PDFs in a directory (Mode B) |
| `/literature` | `/literature --validate` | Validate the sub-index against the global index |
| `/literature` | `/literature --index FILE` | Add/update index entry for existing markdown file |
| `/literature` | `/literature --convert [FILE]` | Convert PDF/DJVU to markdown with chunking |
| `/cite` | `/cite N` | Verify all citations in task N artifacts |
| `/cite` | `/cite N --gaps` | Also flag citations found in Zotero but lacking a PDF |

### Context Pointers

- `context/project/literature/domain/literature-index.md` — global/per-repo index schemas, repo layout
- `context/project/literature/patterns/literature-command-modes.md` — two-mode `/literature`, discovery tiers
- `context/project/literature/patterns/agent-exploration.md` — `--lit` briefing+tools pattern, corpus navigation
- `context/project/literature/tools/zotero-scripts.md` — Zotero script inventory, setup, and related pointers
- `context/project/literature/domain/format-decision.md` — markdown retained as the sole convert/chunk/index format

## Literature Mode (`--lit`)

Literature mode produces a live, navigate-on-demand `<literature-briefing>` block for agent
prompts — never a static content dump. Use this when a task involves implementing from a paper,
specification, or reference document.

### What `--lit` Does

When `--lit` is passed to `/research`, `/plan`, `/implement`, or `/orchestrate`:
- `--lit` triggers `literature-briefing.sh` to build a live `<literature-briefing>` block against
  a corpus of pre-segmented literature chunks — the agent navigates on demand rather than
  receiving injected file content.
- Two source modes, matching `literature-briefing.sh`:
  - **Per-repo mode** (default, no args): sourced from the per-repo sub-index
    `specs/literature-index.json`, resolved against the global `$LITERATURE_DIR/index.json`.
  - **Global-corpus mode** (`literature-briefing.sh --global "<query>"`): a live relevance search
    over the global Literature corpus, used when no per-repo sub-index exists (see "Interactive
    Sub-Index Setup Detection" below for when this mode is selected).
- Both modes emit a single `<literature-briefing>` block containing document/chunk metadata plus
  a "How to Use" footer instructing the agent to run `literature-search.sh` and `Read` specific
  chunks on demand — no full-file content is ever injected.
- The block is injected after `<memory-context>` (if any) and before task-specific instructions.
- If `--lit` is not passed (`LIT_DISABLED`), nothing is injected. If a per-repo sub-index and the
  global index are both absent (`GLOBAL_MISSING`), the skill emits a visible notice that no
  literature is available and continues without a briefing — this is never a silent no-op (see
  "Interactive Sub-Index Setup Detection" for the full missing-sub-index decision flow).
- The only numeric limiter on any live path is `--top-n` (default 8 chunks), which applies to
  global-corpus mode only.
- **Sparse-coverage detection**: `literature-briefing.sh` also emits a machine-readable
  `<!-- lit-coverage mode=repo|global seg_count=N sparse=true|false threshold=T -->` marker and,
  when `sparse=true`, a loud `[SPARSE COVERAGE - N segment(s), threshold T]` banner (same family
  as `[UNVERIFIED ...]` / `[DEGRADED RETRIEVAL ...]`). Sparse is `seg_count < threshold` (never
  `<=`). `LITERATURE_SPARSE_THRESHOLD` (env var, default `3`) controls the threshold for both
  this marker and the resolver's `SPARSE_PROMPT_NEEDED` directive below.

### Ad-Hoc / Conversational Literature Requests

Stage 4a (below) only runs inside a `/research|/plan|/implement|/orchestrate --lit` dispatch. When
a user instead asks conversationally — outside any such dispatch — to consult "the literature", a
paper, or otherwise invoke `--lit`-like behavior, the primary/root session follows
`.claude/context/project/literature/patterns/adhoc-navigation-directive.md`: it runs
`literature-lit-flag-resolve.sh --orchestrator-mode false` and surfaces the SAME three-option
interactive question as Stage 4a ("Use global corpus now" / "Create curation task" / "Skip this
run") — never silently injecting nothing and never silently auto-searching.

### Interactive Sub-Index Setup Detection

When `--lit` is used, each skill (skill-researcher, skill-planner, skill-implementer, and their
`--hard` variants) resolves the situation via the shared helper
`.claude/scripts/literature-lit-flag-resolve.sh`, which classifies the case and prints exactly
one of SIX directives (`LIT_DISABLED`, `SUBINDEX_PRESENT`, `GLOBAL_MISSING`, `PROMPT_NEEDED`,
`AUTONOMOUS_GLOBAL`, `SPARSE_PROMPT_NEEDED`) — this eliminates the prior per-skill duplication
and, critically, ensures no directive branch defaults to an empty briefing without either a
visible logged notice or an explicit user choice. There is no silent fallback. All six skills
implement the branching via ONE shared, directly-executable block imported from
`.claude/context/patterns/lit-stage4a-flow.md` rather than six independently-maintained copies.

1. **No global index** (`GLOBAL_MISSING`): If the per-repo sub-index at
   `specs/literature-index.json` is absent AND `~/Projects/Literature/index.json` (or
   `$LITERATURE_DIR/index.json`) is also absent, the skill emits a visible notice that no
   literature is available and continues without literature context. This is the one acceptable
   empty branch, and it is explicitly announced, never silent.

2. **Global index exists, sub-index missing, interactive context** (`PROMPT_NEEDED`): An
   `AskUserQuestion` prompt appears with FOUR choices — three live outcomes plus one explicit,
   non-silent skip:
   - **Use global corpus now** (recommended default, listed first): Runs a live relevance
     search against the global Literature corpus via
     `literature-briefing-invoke.sh --global "<task description>"` and injects the result for
     this run only. No setup, no file writes. If the result's `<!-- lit-coverage ... -->` marker
     reports `sparse=true`, the skill re-prompts with the same four-option list (the
     two-checkpoint shape) rather than silently accepting thin coverage — but only when this was
     the option chosen, never after "Skip this run" or "Create curation task".
   - **Create curation task**: Creates a task (`populate_literature_sub_index`) in TODO.md via
     `.claude/scripts/literature-create-setup-task.sh`, then attempts to fork-populate
     `specs/literature-index.json` inline so the current run also benefits; injects via the
     no-arg `literature-briefing-invoke.sh` once the sub-index exists (or emits a visible notice
     if the inline population did not complete this run).
   - **Search online to ingest** (new): Runs `literature-discover.sh "<task description>"`,
     filters candidate records to `open_access`/`paywall`/`in_zotero_no_pdf`, ingests each via the
     `literature-ingest-online.sh --record` bridge (STABLE CONTRACT: input schema, directive
     tokens, and exit codes are documented in that script's own header and are never changed by
     this flow), then re-runs the per-repo briefing to pick up whatever was ingested. Live
     network calls; interactive-choice-only, never triggered autonomously.
   - **Skip this run**: An explicit, user-chosen decision to continue without literature context.
     The skill logs a visible `[lit] Skipped by user choice` notice — non-silent because it is an
     explicit choice, not a default.

3. **Global index exists, sub-index missing, autonomous context** (`AUTONOMOUS_GLOBAL`): When
   `orchestrator_mode == true` (e.g. `/orchestrate`), `AskUserQuestion` cannot prompt a human, so
   the skill MUST NOT call it. It takes the deterministic default **"Use global corpus now"**:
   it runs `literature-briefing-invoke.sh --global "<task description>"` and emits a visible
   `[lit:auto]` notice to the transcript stating that the global-corpus briefing was
   auto-selected because no per-repo sub-index exists and no human is available to prompt. This
   is never a silent no-op. Online ingest is never triggered autonomously even if the resulting
   briefing reports `sparse=true`.

4. **Per-repo sub-index exists but is sparse** (`SPARSE_PROMPT_NEEDED`): The sub-index at
   `specs/literature-index.json` exists but resolves to fewer than `LITERATURE_SPARSE_THRESHOLD`
   entries (default `3`; includes zero). Interactive contexts get the SAME four-option
   `AskUserQuestion` as `PROMPT_NEEDED` above (prompt wording names the sparse sub-index rather
   than a missing one). Autonomous contexts (`orchestrator_mode == true`) reuse the existing
   sub-index via the plain per-repo briefing and emit `[lit:auto]` — never `AskUserQuestion`,
   never online ingest.

The sub-index creation helper is `.claude/scripts/literature-create-setup-task.sh`. The
global-corpus search mode is `.claude/scripts/literature-briefing-invoke.sh --global "<query>"
[--top-n N]`; both the per-repo and global-corpus briefing modes share a single output section
that always appends the "How to Use" footer. The interactive detection block lives in Stage 4a
of each skill that supports `--lit` (skill-researcher, skill-planner, skill-implementer, and
their `--hard` variants), each delegating classification to `literature-lit-flag-resolve.sh` and
importing the single shared flow at `.claude/context/patterns/lit-stage4a-flow.md`.

### orchestrator_mode Dual-Consumer / Autonomy Contract

`orchestrator_mode` has TWO independent consumers: (1) the `.orchestrator-handoff.json`
write-gate (see `docs/architecture/handoff-schema.md`), and (2) the literature Stage 4a autonomy
gate above (`AUTONOMOUS_GLOBAL` / the autonomous branch of `SPARSE_PROMPT_NEEDED`). Both
`skill-orchestrate` and `skill-orchestrate-hard` pass `orchestrator_mode: true` uniformly for
research, plan, AND implement dispatches so the literature autonomy contract holds across all
three `/orchestrate --lit` phases — never just the implement phase. A future change to either
consumer's meaning MUST re-check the other before landing.

### specs/literature/ Directory Convention

The `specs/literature/` directory is user-maintained and not task-scoped:
- Place paper summaries, specification documents, algorithm descriptions, or reference PDFs
  (converted to .md/.txt) here
- All files in the directory are available to any task when `--lit` is active
- The directory is not created automatically — create it before using `--lit`
- Suitable content: academic paper summaries, RFC/spec excerpts, algorithm pseudocode,
  mathematical definitions the agent should treat as ground truth

### When to Use `--lit`

- Task requires implementing from a paper or formal specification
- Agent needs stable reference material beyond what is in memory
- Using `--hard` with H3 reference grounding tier "literature"
- Task description mentions "paper to code", "spec to implementation", or cites a specific document

### Relationship to `--clean`

The two flags are independent:

| Flag combination | Memory retrieval | Literature injection |
|------------------|-----------------|---------------------|
| (neither)        | active          | inactive            |
| `--clean`        | suppressed      | inactive            |
| `--lit`          | active          | active              |
| `--clean --lit`  | suppressed      | active              |

### Composability

- `--lit` works with `--team`, `--hard`, `--fast`, and model flags
- `--lit` is threaded through all dispatch contexts in skill-orchestrate
- Per-invocation only: no sticky state in state.json

### Per-Invocation Only

`--lit` has no persistent state. Each invocation of `/research`, `/plan`, `/implement`, or
`/orchestrate` must explicitly pass `--lit` to activate literature injection.

