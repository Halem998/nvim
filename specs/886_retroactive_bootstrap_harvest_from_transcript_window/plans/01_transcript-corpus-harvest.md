# Implementation Plan: Task #886

- **Task**: 886 - Retroactive bootstrap harvest from the transcript window
- **Status**: [NOT STARTED]
- **Effort**: 5.75 hours
- **Dependencies**: None (independent of the passive-capture and telemetry-design siblings)
- **Research Inputs**: reports/01_extraction-design.md
- **Artifacts**: plans/01_transcript-corpus-harvest.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Mine the current ~2.64GB / 30-day transcript corpus **once** into a durable, pointer-based
cold-start dataset before more of the rolling window expires. The harvest scripts are authored
under `agent-system/extensions/memory/scripts/` (source store); the distilled JSONL dataset lands
under this task's own `specs/` tree. Every access to `~/.claude/` is strictly read-only. Definition
of done: `dataset/sessions.jsonl`, `dataset/history-spine.jsonl`, `dataset/harvest-manifest.json`,
and `dataset/README.md` exist with observed (not asserted) row counts, and the doc-lint gate passes
with the new scripts declared in the memory extension's manifest.

### Research Integration

The plan is built directly on reports/01_extraction-design.md:

- **Parser reuse (refined)**: `ccusage` was live-tested and is unusable (cost/token only, zero
  outcome signal) — it is dropped entirely. `uvx claude-code-log --format json` was live-tested and
  confirmed to auto-join subagent sidecars, preserve `is_error`, and resolve `cwd` via
  `--expand-paths`, but its performance was **only ever tested on one file**. The research's
  hybrid is adopted with one refinement made explicit in Phase 1: subagent→parent linkage is
  already free from directory structure (`<parent-sessionId>/subagents/agent-*.jsonl` sits under
  its parent), and `cwd` is already free from the records themselves. So `claude-code-log` is used
  as a **correctness oracle on the pilot slice** — cross-checking our jq-derived linkage and cwd
  against a maintained parser — rather than as a load-bearing full-corpus dependency. This keeps
  the reuse benefit without inheriting the unmeasured scale risk.
- **Self-exclusion**: `$CLAUDE_CODE_SESSION_ID` was verified to exactly match the current session's
  own transcript filename. Snapshot once at harvest start; exclude that sessionId and its
  `subagents/` children from every count.
- **cwd/attribution join**: prefer `sessions-index.json.entries[].projectPath`, fall back to a
  record's own `cwd`. Never the dirname. The `.meta.json` → `toolUseId` → parent-session join stays
  entirely inside Claude Code's UUID space and never touches `sess_*` IDs.
- **history.jsonl embedded-newline record** (new finding, not in the original inventory): a real
  record contains a raw unescaped newline that breaks naive line-oriented parsing. Phase 1 verifies
  the whole-stream `jq` approach against the live file before any counts are trusted.
- **Output location**: scripts to `agent-system/extensions/memory/scripts/`; dataset to this task's
  `specs/` tree — explicitly **not** the live `.memory/` vault and **not** a new skeleton `data/`
  entry.
- **Pilot first**: adopted verbatim as Phase 1.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` provided; `roadmap_flag` not set).

## Goals & Non-Goals

**Goals**:
- Produce a durable, pointer-based distilled corpus (sessionId + repo + coarse position) that
  points into transcripts rather than duplicating them.
- Capture the durable `~/.claude/history.jsonl` spine (23,758 prompts, 7 months, 33 projects),
  which outlives the 30-day transcript cliff.
- Make the per-session outcome **modeling decision** explicit, documented, and revisable without
  re-mining.
- Record honest provenance: what was excluded, what failed to decode, what has no signal at all.
- Leave the harvest scripts deployable and doc-lint-clean in the source store.

**Non-Goals**:
- Building a load-bearing, repeatedly-scheduled pipeline against the transcript format (it is
  undocumented, unversioned, and actively unstable — this is a one-shot mine).
- Writing anything into the live `.memory/10-Memories/` vault, or adding vault hygiene automation
  (reserved by the telemetry-design round; ruled out below ~100 vault entries).
- Designing the future consumer of this dataset (that is the telemetry-architecture design round's
  job — this task only produces the substrate).
- Re-deriving the already-verified source inventory (file counts, sizes, retention cliff, the 2.9%
  `is_error` density, the 63% attribution ceiling).
- Recovering the ~88% of history already past the retention cliff — it is gone and no phase should
  pretend otherwise.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Any write/delete under `~/.claude/` destroys irreplaceable scarce data | H | L | READ-ONLY is a binding constraint restated in every phase touching the corpus. Scripts use only read verbs (`jq`, `find`, `stat`, `wc`, `cat`); all intermediate output goes to the scratchpad. No phase may `rm`, `mv`, `>` , or `truncate` any path under `~/.claude/`. |
| `claude-code-log` too slow at 5,447-file scale (untested; only 1 file measured) | M | M | Phase 1 times it on the nvim slice (110 transcripts) before any commitment. It is demoted to a pilot-only correctness oracle; the bulk pass is jq-only, which the inventory already benchmarked at ~30s for the full corpus. If the oracle is too slow even on the pilot, cross-check a 5-file subset instead and record that reduced confidence in the manifest. |
| `history.jsonl` embedded-newline record silently mis-splits records | M | H (confirmed present) | Feed the whole file to `jq` as a stream; never `sed -n '{n}p'`, `wc -l`-driven extraction, or naive `split('\n')`. Count decode failures explicitly into `harvest-manifest.json` rather than aborting or silently dropping. |
| Miner counts its own `is_error` events (self-observation drift) | M | H | Snapshot `$CLAUDE_CODE_SESSION_ID` **once** at harvest start, exclude that sessionId and its `subagents/` children everywhere. Never re-derive "current session" mid-run. |
| `FAILED` string mistaken for failure signal | H | L | Binding: use `is_error=true` only. `FAILED` appears 2,198 times and is overwhelmingly *content* inside exit-0 successful Bash calls. No phase may grep for `FAILED` as an outcome signal. |
| Dirname→path used instead of authoritative `cwd` | M | L | Dirnames collapse both `/` and `.` to `-` and are not invertible. Resolution order is fixed: `sessions-index.json.entries[].projectPath` → record `cwd` → **fail loudly**, never a dirname guess. |
| Over-fitted task-number regex misattributes subagent work | M | M | The 63% ceiling is established and must not be chased. Non-matching sidecars get `task_number: null`, never a guess. Record the resolved/unresolved split in the manifest. |
| New scripts silently never deploy | M | H | `manifest.provides.scripts` does not exist on the memory extension today, and `loader.lua:copy_scripts()` only copies scripts named in that array. Phase 6 adds the key and verifies via the doc-lint gate. |
| Task-number citations leak into deliverables | L | M | Scripts and any docs under `agent-system/**` reference durable anchors only. The advisory hook flags violations; Phase 6 greps explicitly. |
| Corpus rolls further during the work | M | H | Phases are ordered so the perishable transcript pass completes before the durable `history.jsonl` spine work is finalized; the harvest timestamp is recorded in the manifest so the snapshot boundary is known. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Timed pilot and strategy decision [COMPLETED]

**Goal**: Settle empirically — before writing any harvest logic — whether `claude-code-log` is
viable at scale, whether the jq-only path produces the same linkage/cwd answers, and whether the
whole-stream `jq` read of `history.jsonl` survives the known embedded-newline record.

**READ-ONLY**: this phase only reads `~/.claude/`. All output goes to the scratchpad.

**Tasks**:
- [x] Snapshot `$CLAUDE_CODE_SESSION_ID` to the scratchpad; confirm a transcript with that exact
      filename exists under `~/.claude/projects/-home-benjamin--config-nvim/`. Record the value —
      this is the self-exclusion key for every later phase. *(completed: c4adc98e-f94b-4ffe-bbf8-b105c7845204, transcript confirmed)*
- [x] Time a jq-only `is_error` counting pass over the nvim project slice (110 transcripts).
      Record wall-clock and the observed count. *(completed: 109 top-level files, 2.109s, tool_result_count=3425, is_error_count=88)*
- [x] Time `uvx claude-code-log --format json` over the same nvim slice (per-project invocation,
      not per-file). Record wall-clock. If it exceeds ~5 minutes on the slice, stop it and record
      the timeout as the observation. *(completed: 42.073s for 109 files, well under 5min threshold)*
- [x] Cross-check the oracle: for at least 3 sessions, confirm that (a) the subagent→parent linkage
      derived from directory structure matches `claude-code-log`'s `parent_session_id`, and (b) the
      `cwd`/`projectPath` we resolve matches its `--expand-paths` output. Record agreement or
      disagreement verbatim — a disagreement is a finding, not a failure to hide. *(completed: 3/3 sessions, full agreement on linkage and cwd)*
- [x] Verify the `history.jsonl` whole-stream read: run `jq` over the whole file (never `sed -n`,
      never line-split), confirm it completes, and record both the record count and any decode
      failures observed. *(completed: bare jq aborts at first embedded-newline record with exit 5, recovering only 23321/~23775; deviation — switched to Python raw_decode skip-and-continue, see below)*
- [x] Write a short decision note to the scratchpad recording: bulk strategy (expected: jq-only),
      oracle role (expected: pilot-only cross-check), and the measured numbers backing each. *(completed: scratchpad/886-harvest/phase1-decision-note.md)*

**Timing**: 0.75 hours

**Depends on**: none

**Deviation note**: bare `jq` whole-stream read of `history.jsonl` is necessary but not
sufficient — it aborts (exit 5) at the first embedded-raw-newline parse error instead of
skipping past it, recovering only 23321 of the ~23775 records actually present. Phase 3's
`bootstrap-harvest-history.sh` uses the research's documented fallback (b) — Python
`json.JSONDecoder().raw_decode` in a skip-and-continue loop — which recovered 23775 records
with exactly 1 decode failure at 0.05s wall clock, confirmed live. This is an implementation
detail inside the whole-stream-parsing requirement (never `sed -n`/line-split), not a violation
of it.

**Files to modify**:
- scratchpad only (`/tmp/claude-1000/.../scratchpad/`) — no repo files, no `~/.claude/` files

**Verification**:
- The scratchpad decision note exists and contains **actually observed** wall-clock numbers for
  both the jq pass and the `claude-code-log` run (or an explicit recorded timeout).
- The self-exclusion sessionId is recorded and a matching transcript filename was confirmed to
  exist.
- The `history.jsonl` whole-stream read completed, with a recorded record count and a recorded
  decode-failure count (zero is a valid observation; "not checked" is not).
- `~/.claude/` is unmodified: `find ~/.claude -newermt "<phase start>" -type f` shows no files
  written by this phase (transcripts of the live session itself are expected and excluded from
  this check).

---

### Phase 2: Transcript pass script [COMPLETED]

**Goal**: Author `bootstrap-harvest-transcripts.sh` — the perishable-data pass. Emits one row per
top-level session with `is_error` statistics, resolved repo path, and self-exclusion applied.

**READ-ONLY**: the script must only read under `~/.claude/`.

**Tasks**:
- [x] Create `agent-system/extensions/memory/scripts/bootstrap-harvest-transcripts.sh`.
- [x] Implement self-exclusion: read `$CLAUDE_CODE_SESSION_ID` once at start; exclude that
      sessionId and any transcripts under `<that-sessionId>/subagents/` from every count. If the
      variable is unset, fail loudly rather than silently harvesting the miner's own output.
      *(completed: verified 108/109 rows emitted on nvim slice, self session absent)*
- [x] Implement repo resolution in fixed order: `sessions-index.json.entries[].projectPath` →
      first record's `cwd` → fail loudly. Never the encoded dirname. *(completed: 0 repo_unresolved on nvim slice)*
- [x] Implement the `is_error` count via jq streaming over raw `.jsonl`. Count own-session and
      subagent errors **separately**, and emit both plus a rolled-up total. Also emit the
      tool-result denominator so the rate is reconstructible. *(completed: is_error_count, subagent_is_error_count, tool_result_count all emitted separately; rolled-up total computed in Phase 5's inferred_outcome)*
- [x] Emit per row: `session_id`, `repo`, `first_timestamp`, `last_timestamp`, `message_count`,
      `is_error_count`, `subagent_is_error_count`, `tool_result_count`, `transcript_path`.
      Attribution fields are added by Phase 4; `inferred_outcome` by Phase 5. *(completed)*
- [x] Header comment: state the read-only contract and that `FAILED` is deliberately NOT used as a
      failure signal (it is content inside exit-0 calls), citing the `is_error` field as the only
      outcome signal. Use durable anchors — no task-number citations. *(completed)*
- [x] Emit a per-file skip/decode-failure count to stderr for the manifest to collect. Never drop a
      file silently. *(completed: files_scanned/files_skipped_self/files_decode_failed/rows_emitted/repo_unresolved all printed to stderr)*

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/memory/scripts/bootstrap-harvest-transcripts.sh` — new

**Verification**:
- Script runs against the nvim slice and emits valid JSONL: `jq -e . <output>` exits 0 on every
  row.
- The self-exclusion sessionId from Phase 1 is **absent** from the output rows (grep confirms zero
  matches).
- Row count is consistent with the pilot's observed transcript count for the slice; any divergence
  is explained, not rounded away.
- `grep -nE 'FAILED' bootstrap-harvest-transcripts.sh` finds it only in the explanatory header
  comment, never in an outcome predicate.
- No write verb targets `~/.claude/`: `grep -nE '(rm|mv|truncate|>|>>)' ` review shows every
  redirect targets the scratchpad or stdout.

---

### Phase 3: history.jsonl spine script [COMPLETED]

**Goal**: Author `bootstrap-harvest-history.sh` — the durable, transcript-independent spine pass.
Parallel-safe with Phase 2 (different source file, different script, no shared state).

**READ-ONLY**: reads `~/.claude/history.jsonl` only.

**Tasks**:
- [x] Create `agent-system/extensions/memory/scripts/bootstrap-harvest-history.sh`.
- [x] Parse `history.jsonl` as a **whole jq stream** using the approach validated in Phase 1. Never
      `sed -n '{n}p'`, never `wc -l`-driven extraction, never naive `split('\n')` — a real record
      with an embedded raw newline is confirmed present. *(completed: implemented via Python json.JSONDecoder().raw_decode skip-and-continue, per the Phase 1 finding that bare jq aborts fatally rather than skipping)*
- [x] Count and report decode failures explicitly; skip-and-continue rather than abort. The failure
      count is an output, not a swallowed detail. *(completed: records_decode_failed printed to stderr, observed=1)*
- [x] Group by `sessionId` and emit per row: `session_id`, `repo` (from the `project` field, which
      is already an absolute path in the same format as `cwd`), `prompt_count`,
      `first_timestamp`, `last_timestamp`. *(completed)*
- [x] Emit rows for sessions with no `sessionId` under an explicit sentinel rather than dropping
      them (437 records lack one per the inventory: 23,758 total vs 23,321 with sessionId).
      *(completed: `__no_session_id__` sentinel implemented; observed 0 sentinel rows on the live
      file today — a divergence from the inventory's 437 figure, flagged not suppressed, likely
      because history.jsonl is live/append-only and has grown since the inventory snapshot)*
- [x] Header comment documents the read-only contract and the whole-stream parse requirement with a
      durable anchor — no task-number citations. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/memory/scripts/bootstrap-harvest-history.sh` — new

**Verification**:
- Script completes over the live file and emits valid JSONL (`jq -e .` exits 0 on every row).
- Distinct `repo` count is observed and reported; it should be in the neighborhood of the 33 known
  projects — report the **actual** number, do not assert 33.
- Decode-failure count is printed and is a real observation (zero is acceptable if genuinely
  observed).
- Sum of `prompt_count` plus the no-sessionId sentinel count reconciles against the total record
  count; report the actual reconciliation, do not assume it balances.

---

### Phase 4: Attribution join script [COMPLETED]

**Goal**: Author `bootstrap-harvest-attribution.sh` — the `.meta.json` sidecar join that maps
subagent work to task numbers and agent types, with zero content parsing.

**READ-ONLY**: reads `.meta.json` sidecars and transcripts only.

**Tasks**:
- [x] Create `agent-system/extensions/memory/scripts/bootstrap-harvest-attribution.sh`.
- [x] Walk the `.meta.json` sidecars (4,613 known) reading `agentType`, `description`,
      `toolUseId`, `spawnDepth`. No transcript content parsing. *(completed)*
- [x] Extract a task number from `description` by regex. Sidecars with no match get
      `task_number: null` — **never** a guess. Do not widen the regex to chase the established 63%
      ceiling; a wrong attribution is worse than an honest null. *(completed: 420/573=73.3% resolved on nvim slice, ~10pts above the 63% ceiling — flagged as a finding, regex not widened/narrowed to chase either number)*
- [x] Resolve the parent session: the sidecar's own directory gives the child sessionId; the
      transcript one level up is the parent, and its filename is the parent sessionId. Match
      `toolUseId` against a `Task`-type `tool_use` block in that parent to confirm the link. This
      join stays entirely inside Claude Code's UUID space — it must never touch `sess_*` IDs.
      *(completed: 478/573=83.4% toolUseId-confirmed; grep for the orchestrator session-id token returns nothing)*
- [x] Emit per parent session: `session_id`, `task_numbers` (array, nulls excluded),
      `agent_types` (array from `agentType`), `subagent_count`. *(completed)*
- [x] Report the resolved/unresolved split as counts on stderr for the manifest. *(completed)*
- [x] Header comment uses durable anchors — no task-number citations. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 2

**Files to modify**:
- `agent-system/extensions/memory/scripts/bootstrap-harvest-attribution.sh` — new

**Verification**:
- Script emits valid JSONL (`jq -e .` exits 0 on every row).
- Resolved-vs-null split is **observed and printed**; it should land near the established ~63%
  resolution rate — report the actual measured rate and flag any large divergence as a finding
  rather than adjusting the regex to hit the expected number.
- Spot-check at least 3 rows by hand: the claimed parent sessionId's transcript actually contains
  the `toolUseId` in a `Task` tool_use block. Record which sessions were checked.
- `grep -n 'sess_' bootstrap-harvest-attribution.sh` returns nothing (the agent-system ID space is
  a dead end for this join and must not appear).

---

### Phase 5: Orchestrate and execute the full harvest [NOT STARTED]

**Goal**: Author `bootstrap-harvest.sh`, make the outcome-inference modeling decision explicit, and
**actually run** the harvest to produce the dataset. This is the perishable critical path.

**READ-ONLY**: the corpus is read; all writes go to the task's `specs/` tree and the scratchpad.

**Tasks**:
- [ ] Create `agent-system/extensions/memory/scripts/bootstrap-harvest.sh` orchestrating the three
      passes and joining their outputs on `session_id`.
- [ ] Implement `inferred_outcome` as an **explicit, documented modeling decision** — not an
      extraction. There is no session-level success/failure field in the source; this is a label we
      invent. Record the formula verbatim in the script header and in the dataset README:
      - `total_is_error = is_error_count + subagent_is_error_count` (subagent failures roll up:
        a failing subagent is real, load-bearing failure signal for the session)
      - `is_error_rate = total_is_error / tool_result_count` (0 when denominator is 0)
      - `trivial` when `message_count < 3` (too short to judge — explicitly NOT a success claim)
      - `clean` when `total_is_error == 0` and `message_count >= 3`
      - `mixed` when `0 < is_error_rate <= 0.10`
      - `high_error` when `is_error_rate > 0.10`
      - The 0.10 threshold is a **provisional judgement call**, chosen against the established 2.9%
        corpus-wide density. It is stated plainly so a future consumer can re-label from the
        retained raw counts **without re-mining** — every row keeps its raw numerator and
        denominator for exactly this reason.
- [ ] Run the harvest across all 23 project directories with self-exclusion applied.
- [ ] Write `specs/886_retroactive_bootstrap_harvest_from_transcript_window/dataset/sessions.jsonl`.
- [ ] Write `.../dataset/history-spine.jsonl`.
- [ ] Write `.../dataset/harvest-manifest.json` recording, from observation: harvest timestamp,
      excluded self sessionId, files scanned, rows emitted per file, decode failures, attribution
      resolved/unresolved split, tool versions, the Phase 1 strategy decision and its measured
      basis, and the wall-clock of the run.
- [ ] Write `.../dataset/README.md`: schema of both JSONL files, the `inferred_outcome` formula and
      its provisional threshold, the pointer-based (non-duplicating) design rationale, and the
      **known gaps stated honestly** — the ~88% already past the retention cliff, and ProofChecker
      (highest usage at 8,720 prompts / 2,088 sessions) having zero retained transcripts and
      therefore zero outcome signal in this harvest.

**Timing**: 1.25 hours

**Depends on**: 3, 4

**Files to modify**:
- `agent-system/extensions/memory/scripts/bootstrap-harvest.sh` — new
- `specs/886_.../dataset/sessions.jsonl` — new (generated)
- `specs/886_.../dataset/history-spine.jsonl` — new (generated)
- `specs/886_.../dataset/harvest-manifest.json` — new (generated)
- `specs/886_.../dataset/README.md` — new

**Verification**:
- Both JSONL files exist, are non-empty, and every row parses (`jq -e .` exits 0 across the file).
- `sessions.jsonl` row count is compared against the 832 known top-level transcripts; the actual
  number is reported and any gap explained (self-exclusion accounts for exactly one).
- The self-exclusion sessionId appears **zero** times across all dataset files.
- `harvest-manifest.json` parses and its counts are the ones actually printed by the run — not
  copied from the inventory or from this plan.
- Every `inferred_outcome` value is in the closed set {`trivial`, `clean`, `mixed`, `high_error`};
  the observed distribution is reported. Given the 2.9% corpus-wide `is_error` density, a plausible
  result is most sessions `clean` — but report the **measured** distribution, and if it contradicts
  that expectation, record the contradiction rather than tuning the threshold to produce a
  comfortable-looking spread.
- `~/.claude/` unmodified by the run (checked as in Phase 1).

---

### Phase 6: Register scripts and pass the doc-lint gate [NOT STARTED]

**Goal**: Make the harvest scripts real deployable artifacts of the memory extension rather than
orphaned files that silently never deploy.

**Tasks**:
- [ ] Add a `scripts` key to `agent-system/extensions/memory/manifest.json` under `provides`,
      listing all four new scripts. This key **does not currently exist** on the memory extension
      (its `provides` has only commands/skills/context/data/hooks), and `loader.lua:copy_scripts()`
      returns early without it — so without this change the scripts are never deployed at all.
- [ ] Document the scripts in `agent-system/extensions/memory/README.md` (and `EXTENSION.md` if its
      structure requires it), so the doc-lint rule that scripts referenced in docs be declared in
      `provides.scripts` is satisfied in both directions.
- [ ] Confirm no task-number citations leaked into any file outside `specs/**`.
- [ ] Confirm every edit landed in `agent-system/extensions/**` and nothing was written to
      `.claude/**` (gitignored disposable deploy tree — a change written there is silently wiped on
      the next regeneration).

**Timing**: 0.5 hours

**Depends on**: 5

**Files to modify**:
- `agent-system/extensions/memory/manifest.json` — add `provides.scripts`
- `agent-system/extensions/memory/README.md` — document the harvest scripts

**Verification**:
- `bash .claude/scripts/check-extension-docs.sh` exits 0 (the hard gate).
- `jq -e '.provides.scripts | length == 4' agent-system/extensions/memory/manifest.json` exits 0,
  and every listed script exists on disk.
- `grep -rnE '\b[Tt]asks? [0-9]{2,4}\b' agent-system/extensions/memory/` returns nothing.
- `git status --short .claude/` shows no modifications attributable to this task.

---

## Testing & Validation

- [ ] Every dataset JSONL row parses under `jq -e .` (whole-file pass, not a sampled spot-check).
- [ ] The self-exclusion sessionId is absent from every dataset file.
- [ ] `harvest-manifest.json` counts match what the run actually printed.
- [ ] `~/.claude/` is byte-identical before/after apart from the live session's own transcript:
      no file under `~/.claude/` was created, deleted, moved, or truncated by any phase.
- [ ] Attribution resolution rate is measured and reported (expected near ~63%; report the actual).
- [ ] `check-extension-docs.sh` exits 0.
- [ ] No task-number citations outside `specs/**`.
- [ ] `inferred_outcome` values are all within the closed label set and the distribution is
      reported as measured.

## Artifacts & Outputs

- `agent-system/extensions/memory/scripts/bootstrap-harvest.sh` (orchestrator + outcome modeling)
- `agent-system/extensions/memory/scripts/bootstrap-harvest-transcripts.sh`
- `agent-system/extensions/memory/scripts/bootstrap-harvest-history.sh`
- `agent-system/extensions/memory/scripts/bootstrap-harvest-attribution.sh`
- `agent-system/extensions/memory/manifest.json` (modified: `provides.scripts` added)
- `agent-system/extensions/memory/README.md` (modified)
- `specs/886_.../dataset/sessions.jsonl`
- `specs/886_.../dataset/history-spine.jsonl`
- `specs/886_.../dataset/harvest-manifest.json`
- `specs/886_.../dataset/README.md`
- `specs/886_.../summaries/01_transcript-corpus-harvest-summary.md`

## Rollback/Contingency

- **Fully reversible on the repo side**: every artifact is a new file except
  `memory/manifest.json` and `memory/README.md`. Reverting is `git checkout` of those two plus
  deleting the new scripts and the `dataset/` directory. Nothing is overwritten in place.
- **Nothing to roll back on the source side**: the harvest is read-only against `~/.claude/`, so a
  failed or abandoned run leaves the corpus untouched by construction. This is the whole reason the
  read-only constraint is binding rather than advisory.
- **If Phase 1 shows `claude-code-log` is unusable at any scale**: proceed jq-only. The oracle is a
  cross-check, not a dependency; record the reduced cross-validation confidence in the manifest
  rather than blocking.
- **If the transcript pass fails partway**: the `history.jsonl` spine (Phase 3) is independent and
  durable — it can be produced and committed on its own, and is regenerable later without urgency
  since it is not subject to the 30-day cliff. Ship the spine, mark the transcript pass
  `[PARTIAL]`, and record in the manifest exactly which project directories were covered.
- **If the outcome-inference thresholds prove wrong later**: no re-mine is needed. Every row retains
  its raw `is_error` numerator and `tool_result_count` denominator specifically so labels can be
  recomputed from the retained dataset.
