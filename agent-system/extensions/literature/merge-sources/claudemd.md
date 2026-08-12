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

When `--lit` is used and the per-repo sub-index is missing or sparse, each `--lit`-capable skill
resolves the case via `.claude/scripts/literature-lit-flag-resolve.sh` and, in interactive
contexts, offers exactly four choices: **Use global corpus now** (recommended, live search
against the global Literature corpus, no setup); **Create curation task** (populates
`specs/literature-index.json` for future runs); **Search online to ingest** (discovers and
ingests candidate sources, then re-briefs); or **Skip this run** (explicit, logged). There is no
silent fallback — every branch, including autonomous (`orchestrator_mode == true`) contexts that
cannot prompt a human, emits a visible notice. The full six-directive resolver contract, the
per-branch mechanics, and the sparse-coverage re-prompt behavior are the executable, canonical
contract at `.claude/context/patterns/lit-stage4a-flow.md`, which all six `--lit`-capable skills
import directly — never via this file.

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

