# Research Report: Task #886

- **Task**: 886 - Retroactive bootstrap harvest from the transcript window
- **Started**: 2026-07-15T17:20:00Z
- **Completed**: 2026-07-15T17:35:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None (independent of the passive-capture task; can run in parallel)
- **Sources/Inputs**: live `~/.claude/projects/` corpus (read-only probes), live `~/.claude/history.jsonl`, `npx ccusage@latest --help`/`session --json`, `uvx claude-code-log --help` and a live single-file `--format json` run, `agent-system/extensions/core/context/schemas/events-schema.json` + `events-format.md`, `agent-system/extensions/core/scripts/memory-harvest.sh`, `agent-system/extensions/memory/manifest.json` + `data/README.md`, `specs/state.json` entries for tasks 870/871/885/887, live shell environment (`$CLAUDE_CODE_SESSION_ID`)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Context & Scope

The VERIFIED SOURCE INVENTORY in the task description (file counts, sizes, the 30-day retention
cliff, schema field names, the 2.9% `is_error` density, the `FAILED`-string trap, the 63%
task-attribution ceiling) is established and was not re-derived. This research instead settles
the parts the inventory explicitly leaves open: **how** to extract the distilled corpus, **what**
parser to reuse, **how** to resolve `cwd`/attribution/self-exclusion in practice, and **where**
the durable output should live given the source-store rule. Everything below is either a live
probe against the real corpus (read-only) or a design decision made to satisfy the binding
extraction constraints.

Sibling tasks in the same commit batch clarify scope: task 887 ("Research: telemetry source
architecture and /distill redesign", not started) is the *design round* for the long-term
four-tier source model and the `--meta/--review/--revise/--dream/--learn` flags that will
eventually *consume* bootstrap data; task 885 ("Enable and verify passive signal capture", not
started) fixes the forward-looking capture gap. Task 886 is deliberately narrower: mine what
already exists, once, into a durable, pointer-based dataset that task 887's future `--learn`
pipeline (or any other consumer) can build on later — it must not itself become a load-bearing
pipeline or a premature vault-hygiene operation.

## Findings

### Parser reuse: `ccusage` is not usable for this task; `claude-code-log` is, with caveats

- `npx ccusage@latest --help` / `ccusage session --json` (live-tested) is purely a token/cost
  aggregator (`inputTokens`, `cacheReadTokens`, `modelBreakdowns[].cost`, `lastActivity`). It
  contains no `is_error`, no tool-result, no session-outcome field of any kind. This confirms the
  task description's own note — ccusage is not a candidate for the failure-signal layer. It could
  still supply free per-session cost/model-mix metadata as an optional secondary enrichment, but
  is not load-bearing for this task.
- `uvx claude-code-log --help` (live-tested, package downloads cleanly, no network auth needed)
  is the stronger candidate:
  - It auto-discovers and joins subagent files: running it against a single top-level session
    `.jsonl` automatically found and loaded all 13 `subagents/agent-*.jsonl` files sitting next
    to it, with **no manual sidecar wiring** on our part.
  - `--format json` output on that one file (live-tested, `uvx claude-code-log --format json -o
    out.json <file>`) preserves `is_error` as a nested per-tool-result field (verified: 30
    `is_error` occurrences recovered via `jq '[.. | objects | select(has("is_error"))]'`, each
    carrying `{file_path, is_error, output, tool_name, tool_use_id}`) — i.e. it does *not* discard
    the exact signal the binding constraints require, it just nests it inside a rendering tree
    (`.messages[].children[]...content[]`) rather than exposing it as a flat row.
  - It also computes `sessions[]` entries with `message_count`, `token_summary`,
    `parent_session_id`, and `first_user_message` per session — i.e. it already does
    parent/subagent linkage, which is one of the two hardest joins this task needs.
  - `--session-id`, `--filter-path`, `--expand-paths` (resolves the encoded dir name back to a
    real path **using the cache's recorded `cwd`**, with a first-JSONL-peek fallback), and
    `--all-projects` are exactly the primitives this task needs and were not something we had to
    write ourselves.
  - **Scale risk, not yet resolved empirically**: a single session file (with 13 subagent files)
    produced a 3.9MB nested JSON tree in a few seconds including `uv` package resolution
    overhead. Running it once per file across all 5,447 files (or even once per top-level session
    across the 832 top-level files) was **not** tested at full-corpus scale in this research pass
    — the per-invocation Python/`uv` startup cost times thousands of files is a real risk. This is
    flagged as an open risk for the plan phase (see Risks below), not resolved here.
- Net: reuse `claude-code-log` for the **schema-drift-robust, hard-to-get-right joins**
  (subagent-to-parent linkage, `cwd`→real-path resolution) rather than for bulk flat-field
  counting. Do the bulk `is_error` counting directly with `jq` streaming over the raw `.jsonl`
  files, since `is_error` is already established as a stable, flat, one-level-deep field and the
  inventory's own cheap-scan benchmark (1.63s/200 files → ~30s for the full 2.64GB / 819,035
  lines) is a `jq`/`wc`-class number, not a Python-tool-class number. This hybrid honors "reuse a
  parser rather than writing one" for the parts that actually have schema-drift risk, while
  keeping the bulk numeric pass cheap and using tooling already characterized by the inventory.

### Self-exclusion mechanism (verified, concrete)

`$CLAUDE_CODE_SESSION_ID` is live in the current shell environment and its value
(`c4adc98e-f94b-4ffe-bbf8-b105c7845204`) exactly matches the filename of the most-recently-modified
transcript in `~/.claude/projects/-home-benjamin--config-nvim/` (verified via `stat -c '%Y %n'`
sorted by mtime). This gives a concrete, verifiable self-exclusion rule for the harvest script:
read `$CLAUDE_CODE_SESSION_ID` at the start of the run and exclude that exact `sessionId` (and any
transcripts under `<that-sessionId>/subagents/`) from every count. Note this only excludes the
*current* agent's own session; if the harvest is itself dispatched as a subagent of a larger
orchestration run, the parent session's own `is_error` events are a separate, real session and
are correctly *included* (the hazard is exclusively self-counting the miner's own execution, not
excluding the whole ancestor chain).

### `cwd` resolution: two authoritative sources, prefer `sessions-index.json` when present

- Per-record `cwd` (e.g. `"cwd":"/home/benjamin/.config/nvim"` on `user`/`assistant` type
  records, verified live) is the per-turn authoritative field, exactly as the binding constraint
  requires — never the encoded directory name.
- Where `sessions-index.json` exists (7 of 23 project dirs per the inventory), its `entries[]`
  carry a `projectPath` field (verified: `"projectPath":"/home/benjamin/.config/nvim"`) that is a
  pre-resolved, session-level (not per-turn) real path, plus `originalPath`, `gitBranch`,
  `firstPrompt`, `summary`, `messageCount`, `created`/`modified` — cheaper to consume than
  scanning every record's `cwd` when it is available, and it is exactly the field
  `claude-code-log --expand-paths` also falls back to peeking the first JSONL line for when the
  cache is empty. Recommendation: prefer `sessions-index.json.entries[].projectPath` when the
  project dir has one; fall back to the first record's `cwd` field otherwise. Never use the
  dirname in either branch.
- `history.jsonl`'s `project` field is already an absolute repo path in the same format
  (`/home/benjamin/.dotfiles`, `/home/benjamin/.config/nvim`, verified live), so all three sources
  (`cwd`, `projectPath`, `history.jsonl.project`) share one path format — the join key across the
  transcript layer and the durable spine layer is literally string equality on this field, no
  transformation needed.

### Task-attribution join: chain is real but the description-text step is the bottleneck

`.meta.json` sidecars (verified live, e.g.
`{"agentType":"Explore","description":"Survey task-creation topic coverage","toolUseId":"toolu_...","spawnDepth":1}`)
give `agentType`, `description`, `toolUseId`, `spawnDepth` — exactly as the inventory states.
`toolUseId` is the `Task` tool-use content-block ID in the **parent** session's transcript (the
session that spawned the subagent), so the join is: sidecar → regex over `description` for a task
number → sidecar's own directory path gives the child `sessionId` (the subagent transcript) →
`toolUseId` matched against a `tool_use` block of type `Task` in the parent transcript (the file
one level up from `<session>/subagents/`) → that parent file's own `sessionId` is already known
from its filename → optionally cross-check against `sessions-index.json`/`history.jsonl` for the
parent's `cwd`/`project`. This is a **two-hop join entirely within transcript directory structure
already on disk** — no external ID space is needed, which matches task 887's warning that the
`sess_*` (agent-system-minted) ID space is a dead end for this: this join stays entirely inside
Claude Code's own UUID space and never touches `sess_*`. The 63% ceiling (2,904 of 4,613 sidecars
have a task-number-bearing `description`) is established and should not be re-chased; the
remaining 37% have no extractable task number and should be attributed `task: null`, not guessed.

### `history.jsonl` has at least one non-atomic (embedded-newline) record — new finding, not in the inventory

A plain `jq` pass over the full file (`jq -r '.project' ~/.claude/history.jsonl | sort -u`)
throws `jq: parse error: Invalid numeric literal ... at line 23322`, even though the file overall
is valid JSONL and the aggregate query still completes (33 distinct projects recovered). Line
23322 is not itself malformed — it's a fragment: some earlier record's `display` field contains a
raw, unescaped newline from multi-line pasted content, which splits one logical JSON object across
two physical lines. **This was not surfaced in the task's verified inventory and must be designed
around**: a naive per-line `jq -c` streaming parse over `history.jsonl` will intermittently choke
or silently mis-split records. The extraction script must either (a) use `jq`'s native
whole-stream parsing (`jq` already parses concatenated JSON values without `-s`, and *tolerates*
embedded newlines inside a single JSON value correctly — the error above came from treating the
file as strictly one-object-per-`\n`, e.g. via `wc -l`-driven or `sed -n`-driven line extraction,
not from feeding the whole stream to `jq` directly) or (b) fall back to Python's
`json.JSONDecoder().raw_decode` in a skip-and-continue loop if a stricter line-oriented tool is
required. Recommendation: feed `history.jsonl` to `jq` as a whole file/stream (never
`sed -n '{line}p'` or naive `split('\n')`), and count/skip decode failures rather than aborting.

### Output storage location: resolves the file_scope ambiguity

`file_scope` for this task lists only `agent-system/extensions/memory/` and `specs/`. Checked
concretely:

- `agent-system/extensions/memory/data/.memory/` is a **skeleton-merge-copy template**
  (`manifest.json`: `"data": [".memory"]`; `data/README.md`: "Skeleton files are copied only if
  they don't exist... unload... user content is preserved") — it deploys into every repo's
  *live* `.memory/` (repo-root, git-tracked, confirmed via `git ls-files .memory`, **not** inside
  the gitignored `.claude/` tree) the first time that repo initializes the memory extension.
  Writing the harvested corpus here would make it a template shipped into *every future repo*,
  which is wrong for a point-in-time, cross-repo harvest result.
- The live `.memory/10-Memories/` vault currently has 18-19 individual memory files (~2,616
  tokens total, confirmed via `.memory/20-Indices/index.md`/`memory-index.json`). Task 887's own
  binding design note is explicit: **"NO NEW HYGIENE AUTOMATION BELOW ~100 VAULT ENTRIES"** and
  "leave existing --purge/--merge/--compress/--refine/--gc/--auto behavior UNCHANGED" — bulk
  materializing hundreds/thousands of distilled session rows as individual memory files today
  would violate that constraint the moment task 887's `--learn` design lands, and pre-empts a
  decision (retroactive/batch harvest sub-mode) task 887 has explicitly reserved for itself.
- Conclusion: **do not write into the live `.memory/10-Memories/` vault** from this task, and do
  not add a new top-level `data/` entry to the memory extension's skeleton. Instead:
  - The **harvest script(s)** (source of truth) belong under
    `agent-system/extensions/memory/scripts/` (new files, e.g. a `bootstrap-harvest.sh`
    orchestrating the `jq`-based transcript pass, the `history.jsonl` pass, and the
    `.meta.json`/`sessions-index.json` join), matching both the file_scope grant and the
    codebase's overwhelming bash+jq convention (105 existing `.sh` scripts vs. 4 `.py` files
    across `agent-system/extensions/`) — Python should be used only where genuinely required
    (the `history.jsonl` corruption-tolerant decode, if `jq`'s native stream handling proves
    insufficient in practice) and kept minimal/contained.
  - The **distilled dataset** (the actual "durable cold-start dataset" deliverable) belongs under
    this task's own `specs/886_retroactive_bootstrap_harvest_from_transcript_window/` tree (e.g.
    a `dataset/` subdirectory holding JSONL output files), since `specs/` is explicitly in scope,
    is git-tracked (confirmed, not gitignored), and — unlike `.claude/` — is never wiped by
    extension regeneration. `specs/` task directories persist indefinitely (archived to
    `specs/archive/`, eventually `specs/vault/{NN-vault}/` on vault operations, per
    `state-management.md`), which satisfies "durable" without prematurely committing to how a
    future `--learn` consumer will ingest it.

### Corpus shape: pointer-based, not content-duplicating

Per the binding "archival/replay substrate" constraint, the corpus should be JSONL, one row per
transcript **session** as the primary unit (not per-message), each row pointing into the
transcript via `session_id` + a coarse position marker rather than embedding message content.
Recommended fields per row (session-level file, transcript-sourced):

- `session_id` (Claude Code UUID), `repo` (resolved `cwd`/`projectPath`, absolute path — the
  cross-repo federation key shared with `history.jsonl.project`)
- `task_number` (nullable int, from the `.meta.json` join; `null`, not a guess, for the ~37% that
  don't resolve)
- `first_timestamp`, `last_timestamp`, `message_count`
- `is_error_count`, `is_error_rate` (own turns only) and a separate `subagent_is_error_count` /
  `subagent_is_error_rate` roll-up (see Decisions below on whether/how to combine them)
- `inferred_outcome` (a small closed label set, e.g. `clean` / `mixed` / `high_error` — see
  Decisions; explicitly a modeling label, not an extracted fact)
- `agent_types` (array, from `.meta.json` `agentType` values of any subagents spawned in-session —
  free structured signal already sitting in the sidecars)
- `transcript_path` (informational best-effort pointer; may already be gone by the time a future
  consumer reads it, which is expected and acceptable given the 30-day churn)

A second, separate JSONL file for the `history.jsonl` spine (its own pass, independent schema,
since it has no `is_error`/outcome signal at all — prompts only): `session_id`, `repo`
(`history.jsonl.project`), `prompt_count`, `first_timestamp`, `last_timestamp`. This file is the
one genuinely durable, transcript-independent artifact — it should be regenerable at any later
date without urgency, since `history.jsonl` is described as global/durable in the inventory (it is
not subject to the 30-day cliff), unlike the transcript-sourced file above which is genuinely
time-sensitive and should be produced from the *current* corpus before more days roll off.

## Decisions

- **Reuse `claude-code-log`** (via `uvx claude-code-log`) for subagent/parent-session linkage and
  `cwd`→real-path resolution; use direct `jq` streaming over raw `.jsonl` files for the bulk
  `is_error` counting pass, since that field is already established as flat, stable, and cheap to
  scan at full-corpus scale. Do not write a from-scratch transcript parser for either purpose.
- **Self-exclude via `$CLAUDE_CODE_SESSION_ID`**, verified live and confirmed to match the current
  session's own transcript filename exactly — snapshot this value once at harvest start and
  exclude that `sessionId` (and its own `subagents/` children) from every count.
- **Resolve `cwd` via `sessions-index.json.entries[].projectPath` when the project dir has an
  index, else via a record's own `cwd` field; never the encoded dirname.** This is the shared join
  key with `history.jsonl.project`.
- **Roll subagent `is_error` events up into the parent session's outcome** (recommended), since a
  failing subagent is real, load-bearing failure signal for the session as a whole — but *also*
  retain a separate subagent-only breakdown per row, since the `agentType` field is free
  structured signal for later "which agent types are error-prone" analysis that would otherwise
  be thrown away by flattening.
- **`inferred_outcome` is a documented modeling decision, not an extraction**: define it
  explicitly (e.g. a simple threshold on `is_error_rate`, or absence of any `is_error` combined
  with a non-trivial `message_count` as `clean`) and state the formula plainly in the harvest
  script's header comment, per the binding constraint that no session-level success/failure field
  exists natively.
- **Corpus output lives under `specs/886_retroactive_bootstrap_harvest_from_transcript_window/`**
  (a `dataset/` subdirectory of JSONL files), not in the live `.memory/` vault and not as a new
  memory-extension skeleton `data/` entry. The harvest **script** lives under
  `agent-system/extensions/memory/scripts/`.
- **`history.jsonl` must be parsed as a whole JSON stream, never via line-numbered/`sed`-style
  extraction**, given the confirmed embedded-newline record found live in the current file; count
  and skip decode failures rather than aborting the pass.

## Risks & Mitigations

- **Full-corpus `claude-code-log` performance is unverified at 5,447-file / 2.64GB scale** — only
  a single file was live-tested in this research pass (3.9MB output, a few seconds, but including
  one-time `uv` package resolution overhead that will not repeat per-invocation once cached).
  Mitigation: the implementation phase should run a timed pilot on the `nvim` project alone (110
  transcripts, already known from the inventory) before committing to a strategy across all 23
  dirs; if per-file subprocess overhead dominates, prefer `--all-projects` (or per-project
  batching) over one invocation per file, and fall back further to `jq`-only extraction for the
  parts `claude-code-log` isn't strictly needed for (bulk `is_error` counting, which was already
  designed as a `jq`-only pass above).
- **`ProofChecker`, the highest-usage project (8,720 prompts / 2,088 sessions), has zero retained
  transcripts** (inventory, not re-derived here). Its `history.jsonl` spine is minable, but no
  `is_error`/outcome signal exists for it at all in this harvest. This is an inherent, unfixable
  gap for this one-shot pass — not a defect in the extraction design.
- **The 37% of `.meta.json` sidecars without a task-number-bearing description** should be
  attributed `task_number: null` rather than guessed or regex-forced; over-fitting the regex to
  squeeze out marginal matches risks silently misattributing subagent work to the wrong task
  number, which is worse than an honest `null`.
- **`history.jsonl`'s embedded-newline corruption** (new finding, not in the inventory) could
  silently corrupt a naive line-oriented parse. Mitigated by the whole-stream `jq` / tolerant
  decode-loop design above; the implementation phase should explicitly test this against the live
  file before trusting aggregate counts.
- **Self-observation persists across the harvest's own runtime**: if the harvest is a long-running
  `/implement` session, its own transcript keeps growing *during* the run. Snapshot
  `$CLAUDE_CODE_SESSION_ID` once at the start (not per-file) and exclude that one ID consistently;
  do not attempt to re-derive "current session" mid-run.
- **Time sensitivity**: every day the corpus rolls, more of the ~88%-already-lost history becomes
  ~89%, ~90%, etc. This design is deliberately minimal-dependency (bash+jq, one `uvx` tool call
  with no auth/network requirements beyond package fetch) specifically so implementation can start
  immediately rather than waiting on task 887's broader design round, which this task is
  explicitly independent of.

## Context Extension Recommendations

- **Topic**: transcript-corpus mining conventions (self-exclusion via `$CLAUDE_CODE_SESSION_ID`,
  `cwd`/`sessions-index.json` resolution, the `.meta.json` two-hop attribution join).
  **Gap**: no existing context file documents these Claude-Code-transcript-layer conventions —
  they currently exist only inside this task's description and this report. **Recommendation**: if
  task 887's design round produces a durable `--learn`/bootstrap consumer, promote these findings
  into a `agent-system/extensions/memory/context/` domain doc at that point, once the design is
  settled, rather than documenting a one-shot script's internals prematurely here.

## Appendix

- Live probes run (read-only against `~/.claude/`): `ls`/`stat`/`wc`/`jq` inventory checks on
  `~/.claude/projects/-home-benjamin--config-nvim/`, `~/.claude/history.jsonl`; env inspection
  (`env | grep -i claude`); `npx -y ccusage@latest --help` and `... session --json --since
  20260701`; `uvx claude-code-log --help` and a single-file `--format json` conversion into the
  scratchpad (`/tmp/claude-1000/.../scratchpad/cclog-test/out.json`), inspected via `jq`.
- No writes, deletes, or renames were made under `~/.claude/` at any point (read-only throughout,
  per the task's binding safety constraint).
- Sibling tasks consulted for scope/consistency (not modified): 870 (unified events store,
  completed — establishes `specs/events.jsonl`'s `sess_*`-keyed schema, which this task correctly
  does *not* try to reuse, since the corpus here is keyed by Claude Code's own UUID session IDs),
  871 (completion-time reflective harvest), 885 (passive signal capture, not started, the
  forward-looking sibling), 887 (telemetry source architecture / `/distill` redesign, not started,
  the future consumer of this task's output).
