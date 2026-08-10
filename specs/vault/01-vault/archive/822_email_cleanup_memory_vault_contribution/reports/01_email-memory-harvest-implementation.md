# Research Report: Task #822

**Task**: 822 - Implement email cleanup to memory vault contribution
**Started**: 2026-07-12
**Completed**: 2026-07-12
**Effort**: 3 hours (per state.json estimate)
**Dependencies**: 821 (COMPLETED — design deliverable consumed below)
**Sources/Inputs**:
- `.claude/extensions/email/context/project/email/design/email-to-memory-preferences.md` (821 design, primary spec)
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` (568 lines, read in full)
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` (2482 lines, targeted sections read)
- `.claude/skills/skill-todo/SKILL.md` (822 lines, read in full)
- `.claude/scripts/memory-retrieve.sh` (169 lines, read in full)
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`,
  `patterns/bulk-bucket-review.md`
- `.claude/extensions/email/manifest.json`, `.claude/extensions/memory/manifest.json`
- `.claude/extensions/email/README.md`, `.claude/extensions/memory/README.md`
- `specs/821_email_to_memory_contribution_architecture/plans/01_email-memory-contribution.md`,
  `summaries/01_email-memory-contribution-summary.md`
- `specs/ROADMAP.md` (Email/Memory Integration subsection)
- `.claude/scripts/check-extension-docs.sh` (doc-lint convention)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 821's design (`email-to-memory-preferences.md`) is a **complete, implementation-ready
  spec**: capture point, identity-key normalization (empirically verified), memory schema,
  dedup/operation mapping, guardrails, and gate behavior are all fully resolved (G1-G8). 822's
  job is to transcribe this design into working SKILL.md prose/logic + two concrete script fixes
  — not to make new design decisions.
- Three concrete file-level edit targets, all precisely located:
  1. `skill-email-cleanup/SKILL.md` — add a new **Stage 7 (Harvest)** section after the existing
     Stage 6 (Verify) in both Default Mode and `--all` Mode, implementing the design's §1-§5.
  2. `.claude/scripts/memory-retrieve.sh` — add a topic-prefix pre-filter (design §5.2) at the
     `map(select(...))` pipeline stage (currently line ~77, right after the tombstone filter).
  3. `skill-memory/SKILL.md` — add the exact-key dedup short-circuit (design §4.1) ahead of the
     existing fuzzy-overlap Classification Thresholds section (currently lines 200-206), and add
     the `retrieval_count==0 AND days_since_created>30 AND NOT topic startswith
     "email/preferences/"` purge exemption (design §5.1) to the Zero-Retrieval Penalty / Purge
     Candidate Identification logic (currently lines 990-999 and 2042-2050).
- The reusable opt-in-gate pattern to mirror is `skill-todo` Stages 7-9 (HarvestMemories ->
  DryRunOutput -> InteractivePrompts): candidate collection, keyword-overlap dedup
  classification, tiered `AskUserQuestion`, batch-regen after all writes. 822 reuses this
  **logic** only — never `skill-todo`'s `state.json`/`project_number` storage substrate (design
  §1.3 explicitly rejects that).
- No dedicated unit-test harness exists for skill-level logic in this repo (`.claude/tests/`
  holds only `test-command-route-skill.sh` and `test-validate-handoff.sh`, both routing/handoff
  scripts, not skill-behavior tests). "Tests" for this task means: (a) a bash test script
  exercising the new normalization/tally/dedup logic as pure functions if extracted to a script,
  or (b) documented manual verification steps in the plan's Testing & Validation section
  (dry-run walkthroughs against synthetic manifest data), consistent with how 821 and other
  meta/skill tasks in this repo verify SKILL.md prose changes. Recommend extracting the
  normalization + tally-arithmetic logic into a small bash helper script
  (`.claude/scripts/email-preference-harvest.sh` or similar) specifically so it CAN be unit
  tested with a bats-free bash assertion script mirroring `test-command-route-skill.sh`'s style.
- Both extensions' READMEs/manifests need updates: email's README File Inventory table (new
  design/ doc already exists, but no harvest-stage doc yet) and memory's README (frontmatter
  table needs the new `category` field documented, since 821 confirmed it's the first real use).
  Manifests likely need no structural changes (no new skills/commands are being added — this is
  an in-place SKILL.md extension) but the `hooks: {}` slot decision (rejected in favor of inline
  harvest) should be noted as intentionally unused.

## Context & Scope

Task 822 implements the write-path designed by task 821 (complete, `[COMPLETED]`). File scope
is restricted to `.claude/extensions/email/` and `.claude/extensions/memory/`. No production
code exists yet for the harvest; `email-preferences.md`'s static classifier table must remain
untouched (821 Non-Goal, reaffirmed by design §8).

The 821 design already resolved every open design question (G1-G8); this research focuses
purely on the **concrete implementation surfaces** — exact file locations, exact current line
content the implementer will edit around, and exact reusable patterns — so a plan can be written
without further design work.

## Findings

### 1. Capture point: exact `skill-email-cleanup/SKILL.md` attachment points

Read in full (568 lines). Two Stage 6 (Verify) sections exist, one per mode, and the harvest
attaches immediately after each:

- **Default Mode Stage 6** (`SKILL.md:178-181`, "Verify"): *"Diff the wrapper's own
  execution-state output (never re-derived) against the approved manifest to confirm which IDs
  were actually mutated. Report this diff to the user."* — followed immediately by the `---`
  section break before `## \`--all\` Mode`. **New Stage 7 (Harvest) should be inserted here**,
  reading the Stage 6 diff's executed-ID set and the Stage 4 approved manifest's `sender` field
  (per design §1.2, default mode has no bucket, so the key is derived post-hoc per executed
  Message-ID).
- **`--all` Mode Stage 6** (`SKILL.md:398-402`, "Verify"): *"diff the per-split execution-state
  files (never re-derived) against the approved manifest across ALL splits and report totals —
  executed, failed ..., skipped ..., and expired-unexecuted residual."* — followed by the
  `---` before `## Archive Scope`. **New Stage 7 (Harvest) should be inserted here**, keyed off
  the Stage 2.5 bucket grouping (`bulk-bucket-review.md`), cross-referenced against the executed
  totals (design §1.1-§1.2).
- Both new Stage 7 sections should be gated by the opt-in `AskUserQuestion` (design §5.4),
  independent of `--clean` (that flag only affects `/research`/`/plan`/`/implement` auto-
  retrieval per CLAUDE.md's Memory Extension section — confirmed, not a harvest-write gate).
- `Critical Requirements` / `MUST DO` / `MUST NOT` lists at the bottom of SKILL.md
  (`:540-568`) will need a new MUST-DO bullet ("run the opt-in harvest gate after Stage 6") and
  possibly a MUST-NOT bullet reaffirming the harvest never mutates `proposed_action`/confidence
  (design §5.3 feedback-loop cap).
- The skill's `allowed-tools` frontmatter (`SKILL.md:4`) is currently
  `Bash, Read, AskUserQuestion` — sufficient for the harvest (no `Write`/`Edit` needed if the
  harvest shells out to a script that writes memory files via `Write`... **note**: if the
  harvest writes `.memory/10-Memories/MEM-*.md` files and updates `memory-index.json` directly
  via Bash/jq — the pattern used throughout `skill-memory/SKILL.md` — then `Bash` alone
  suffices and `allowed-tools` needs no change. If instead the implementation chooses to
  literally invoke `skill-memory`'s CREATE/UPDATE/EXTEND logic in-process (not a sub-dispatch —
  `skill-email-cleanup` is direct-execution with no `subagent_type`), the same Bash-only
  toolset applies since skill-memory's own operations are themselves Bash/jq/file-write based.

### 2. `skill-memory` CREATE/UPDATE/EXTEND mechanics (concrete, from SKILL.md read)

Read targeted sections (lines 1-260, 480-700, 960-1070, 1330-1420, 2010-2100 of 2482 total).

- **Classification Thresholds** (`SKILL.md:200-206`): the existing fuzzy dedup contract —
  `>60% overlap -> UPDATE`, `30-60% -> EXTEND`, `<30% -> CREATE`, computed via
  `overlap_score = |segment_terms intersect memory_terms| / |segment_terms|`. Design §4.1
  mandates a **new exact-key check runs before this**, specifically:
  ```bash
  jq --arg k "email/preferences/${ACCOUNT}/${KEY}" \
    '.entries[] | select(.topic == $k)' .memory/memory-index.json
  ```
  A hit short-circuits straight to UPDATE/EXTEND (design §4.3 mapping) without computing
  overlap at all; this is a **documented, sanctioned deviation** — the implementer should add a
  new subsection to SKILL.md (e.g. "Exact-Key Dedup for Reserved Namespaces") immediately before
  the "Classification Thresholds" table, scoped explicitly to `topic` values matching
  `email/preferences/*`.
- **CREATE template** (`SKILL.md:360-384`): standard frontmatter is
  `title, created, tags, topic, source, modified, keywords, summary, retrieval_count,
  last_retrieved`. Design §3.4 adds `category: preference` as a new frontmatter field — schema-
  additive. Design §3.5 gives the exact body template to use in place of the generic CREATE
  template for `email/preferences/*` memories (tally block, `## History`, evidence line).
- **UPDATE template** (`SKILL.md:259-283`) and **EXTEND template** (`SKILL.md:298-306`): both
  generic templates move/append content wholesale. Design §4.3's operation mapping is a
  **narrower, tally-arithmetic variant** of these — EXTEND appends a dated `## History` line and
  bumps one counter (not a full section replace); UPDATE increments the *opposite* counter and
  moves the prior summary line to `## History` marked `(superseded)` (not a full content
  replace). The implementer should document this as a namespace-scoped variant of the existing
  UPDATE/EXTEND operations, not a wholesale reuse of the generic templates.
- **Index regeneration** (`SKILL.md:408-537`, "JSON Index Maintenance" / "Validate-on-Read"):
  confirms `memory-index.json` regeneration is a full filesystem rescan + overwrite
  (`.memory/10-Memories/MEM-*.md` glob, frontmatter extraction via `grep`/`sed`), and that the
  `status` field defaults to `"active"` when absent, preserved as `"tombstoned"` when present.
  Design §4.4 (batch regen once per harvest round) is directly compatible — call this
  regeneration procedure once after all CREATE/UPDATE/EXTEND calls in a round, exactly as
  `skill-todo` Stage 14 already does.
- **Zero-Retrieval Penalty** (`SKILL.md:990-999`, Component 2 of the scoring engine) and
  **Purge Candidate Identification** (`SKILL.md:2042-2050`): both currently compute
  `retrieval_count == 0 AND days_since_created > 30` with no topic filter. Design §5.1's
  exemption (`AND NOT topic startswith "email/preferences/"`) needs to be added to **both**
  places — the scoring-engine component (feeds the composite score used for `report`/`--merge`/
  `--compress` too, not just purge) and the purge-candidate OR-condition specifically. The purge
  OR-condition at `SKILL.md:2049` is `zero_retrieval_penalty == 1.0 OR staleness_score > 0.8` —
  the exemption must gate the whole OR, not just the zero-retrieval leg, since a 90+-day-stale
  but well-retrieved preference memory should also be exempt from auto-purge consideration
  (though in practice email-preference memories are unlikely to hit staleness alone without
  zero-retrieval, since they're never read by `memory-retrieve.sh`'s auto-injection path per
  finding 3 below).
- **Tombstone pattern** (`SKILL.md:1349-1366`): `status: tombstoned`, `tombstoned_at`,
  `tombstone_reason` fields, file never deleted. Design §5.5 recommends reusing this exact
  pattern for the 822-scope "revocation/edit UX" addition (a "forget this preference" action).

### 3. `memory-retrieve.sh` cross-contamination fix — exact line target

Read in full (169 lines). The scoring block design §5.2 targets is:

```bash
scored_entries=$(jq --argjson kw "$keywords_json" --arg tt "$task_type" '
  .entries // [] |
  # Pre-filter: exclude tombstoned memories (absent status defaults to "active")
  map(select((.status // "active") == "active")) |
  map( ... )
' "$INDEX_FILE" ...)
```

(current lines 74-102). The existing tombstone pre-filter is exactly at line 77:
`map(select((.status // "active") == "active")) |`. Design §5.2's exclusion should be added as a
**second `map(select(...))` stage immediately after this line**, e.g.:

```bash
map(select(
  ((.topic // "") | startswith("email/preferences/")) and ($tt != "email")
  | not
)) |
```

Confirmed by reading the topic-match-bonus logic further down (line 87:
`if ($entry.topic // "") == $tt then 2 ...`): `topic` is compared for *exact equality* against
`task_type`, never prefix-matched — so today's scoring has no way to special-case a namespace
prefix, confirming the design's claim that no such filter exists and this is a net-new addition,
not a modification of existing logic. Since core routing (`CLAUDE.md`) confirms no `email` task
type exists among core/extension task types passed to `/research`/`/plan`/`/implement`, the
`$tt != "email"` clause is currently always true, making this an effectively unconditional
exclusion today (matches design §5.2's stated intent exactly).

### 4. `skill-todo` harvest pattern — exact stages to mirror (logic only)

Read in full (822 lines, XML-tagged skill). The reusable **flow** is Stages 7-9 + 14:

- **Stage 7 (HarvestMemories)**: collect `memory_candidates` (here: harvest candidates derived
  from Stage 6 executed diff, not `state.json`), dedupe against `memory-index.json` by keyword
  overlap, apply three-tier classification (Tier 1 pre-selected / Tier 2 shown / Tier 3 hidden
  by confidence+category). For 822, design §5.4 replaces the confidence/category tiering with
  its own two-tier split: **Tier 1** = keys meeting the evidentiary threshold (design §1.4)
  outright this round; **Tier 2** = keys newly crossing the rolling-N threshold this round;
  fuzzy near-miss suggestions (design §4.2) as a labeled, non-pre-selected option.
- **Stage 9 (InteractivePrompts)** sub-step 4: the exact `AskUserQuestion` multiSelect
  presentation idiom to mirror — `[PRE-SELECTED] [TIER 1] ...` / `[TIER 2] ...` formatting,
  `dedup_action == "UPDATE"` warning-label append. 822's harvest gate (design §5.4) is "one
  consolidated, never-silent `AskUserQuestion` prompt" — directly analogous.
- **Stage 14 (CreateMemories)**: create-then-batch-regenerate-indexes-once pattern — confirms
  design §4.4's "one `memory-index.json` regeneration after the entire harvest round" is
  literally how `skill-todo` already does it (not a new invariant to invent).
- **Explicitly NOT reused**: `harvest_candidates` sourced from
  `.active_projects[] | select(.project_number == $task) | .memory_candidates` in
  `specs/state.json` (Stage 7 sub-step 1) — this is the `state.json`/`project_number` substrate
  design §1.3 rejects for email (`/email` has no task directory or `project_number`). 822's
  harvest candidates instead come from the Stage 6 executed-ID diff plus the identity-key
  normalization (design §2), an entirely different data source feeding the same *tiered-gate*
  logic shape.

### 5. Manifest/README doc-update surfaces

- **`email/manifest.json`** (32 lines): `provides.hooks: ["mail-guard.sh"]` — the `hooks` key
  here is the file-copy-target list (distinct from lifecycle hooks), already populated; no
  structural change needed since 822 is an in-place SKILL.md edit, not a new skill/command.
  `provides.context: ["project/email"]` already covers the new design/ subdirectory (glob-style
  inclusion of the whole `context/project/email/` tree — confirmed by README's File Inventory
  already listing the design doc's sibling docs without a separate manifest entry per file).
- **`memory/manifest.json`** (60 lines): has `"hooks": {}` — the *lifecycle-hook* slot (schema-
  ready but empty), confirmed by design §1.3 as explicitly rejected/unused for this design. No
  change needed to this field; if the implementer wants to document the rejection, a comment is
  not supported in JSON — better to note it in EXTENSION.md or README.md prose instead.
- **`email/README.md`** (162 lines): File Inventory table (lines 23-41) lists
  `context/project/email/domain/wrapper-contracts.md`, `archive-mode-risk.md`,
  `patterns/bulk-bucket-review.md` but **not** the already-existing `design/` subdirectory
  (created by 821) — needs a new row:
  `context/project/email/design/email-to-memory-preferences.md` — design spec. The "Using
  `/email`" section (lines 93-156) documents Stages/modes but stops at Stage 6/Verify-equivalent
  language; needs a new subsection describing the opt-in Stage 7 harvest (mirroring how
  `--sync`'s confirmation gate is documented at lines 138-156).
- **`memory/README.md`** (292 lines, first 180 read): Frontmatter Fields table (lines 151-160)
  lists `title, created, tags, topic, source, modified` — missing `keywords, summary,
  retrieval_count, last_retrieved` (already real fields per skill-memory SKILL.md, a pre-existing
  README gap, not 822's to fix unless the plan chooses to) and will need a new `category` row
  once 822 makes it real (design §3.4: first real use of `category:` frontmatter). Storage
  Details section doesn't currently mention any reserved/namespaced topic convention like
  `email/preferences/*` — worth a short callout so a future reader understands why some vault
  topics are hashed/non-human-readable.
- **Doc-lint** (`check-extension-docs.sh`, read header): validates README/EXTENSION.md/
  manifest.json presence, manifest-declared file existence, README staleness vs manifest mtime,
  and commands-in-manifest-vs-README-mention. Running `bash .claude/scripts/check-extension-docs.sh`
  after doc edits is the closest thing to an automated "test" for this task's doc-update
  requirement and should be part of the plan's Testing & Validation checklist.

### 6. Testing conventions for meta/skill artifacts in this repo

- No `tests/` directory exists under either the `email` or `memory` extension, and no bats/spec
  framework is used anywhere in `.claude/`. The only precedent bash test scripts are
  `.claude/tests/test-command-route-skill.sh` and `.claude/tests/test-validate-handoff.sh` —
  both test **routing/handoff shell scripts** (deterministic, pure-bash logic with clear
  input/output), not SKILL.md prose behavior.
- This strongly suggests the correct 822 testing strategy is: **extract the deterministic,
  testable pieces of the design** (identity-key normalization per §2.2, tally arithmetic per
  §3.2/§4.3, exact-key dedup lookup per §4.1) into a small helper script under
  `.claude/scripts/` (naming TBD by the plan, e.g. `email-preference-key.sh` and/or
  `email-preference-tally.sh`), and write a `.claude/tests/test-email-preference-harvest.sh` in
  the same bash-assertion style as the two existing test scripts, exercising:
  - normalization of the four verified edge cases from design §2.3 (freemail multiplicity,
    plus-addressing strip, DMARC "via" relay keying, case-insensitivity)
  - CREATE/EXTEND/UPDATE tally transitions per design §4.3's table
  - the exact-key jq lookup against a synthetic `memory-index.json` fixture
  - the `memory-retrieve.sh` topic-prefix exclusion (a small fixture index + `task_type=general`
    call, asserting the email-preference entry is never returned; a second call with
    `task_type=email` asserting it IS returned per design §5.2's stated future-compat carve-out)
- Prose-only SKILL.md changes (the new Stage 7 sections, the exact-key-before-fuzzy documentation
  in skill-memory) are not independently unit-testable and should instead get a documented manual
  verification checklist entry (dry-run walkthrough against a synthetic manifest, matching how
  821's own Testing & Validation section verified a documentation-only deliverable).

## Decisions

- The plan should structure phases around the three concrete edit targets found above (email
  Stage 7 harvest, skill-memory exact-key dedup + purge exemption, memory-retrieve.sh
  cross-contamination filter) plus a testing phase (helper-script extraction + bash test script)
  and a doc-update phase (both READMEs, doc-lint pass) — this maps cleanly onto the design's own
  G1-G8 structure without requiring new design decisions.
- Recommend extracting normalization/tally logic to a helper script specifically so the "tests"
  requirement in the task description is satisfiable with this repo's existing bash-test-script
  convention, rather than either skipping tests or inventing a new test framework.
- The 822-scope additions the design explicitly recommends folding in (design §5.5: cross-account
  key scoping, archive-scope tally isolation, revocation/edit UX via the existing tombstone
  pattern, minimal success-signal logging) should each become their own phase or task within the
  plan — none of them are optional footnotes; the design treats them as in-scope deliverables.

## Risks & Mitigations

- **Editing `skill-memory/SKILL.md` (2482 lines) risks unintended drift in unrelated sections**
  (distill scoring, merge/compress, task mode). Mitigation: the plan should scope edits to the
  four precisely-located insertion points identified above (Classification Thresholds preamble,
  Zero-Retrieval Penalty component, Purge Candidate Identification OR-condition) via targeted
  `Edit` calls, never a full-file rewrite.
- **`memory-retrieve.sh` is a live, auto-invoked script** (every `/research`/`/plan`/`/implement`
  preflight when the memory extension is loaded) — a syntax error in the new jq filter would
  break memory retrieval repo-wide, not just for email. Mitigation: test the filter against a
  synthetic `memory-index.json` fixture with `jq` directly before wiring it into the script (per
  Finding 6's proposed test script), and keep the added `map(select(...))` stage syntactically
  isolated (its own line, easy to `Edit`-revert).
  the field name is `topic` throughout, consistent with the identity-key namespace design.
- **`category: preference` is schema-additive but untested against `index.md`/`/distill`'s
  existing category-derivation heuristic** (design §3.4 says `/distill` "should recognize
  `category:` when present ... and continue to fall back ... when absent" — this fallback logic
  does not yet exist in skill-memory/SKILL.md and is itself part of 822's scope, not already
  built). The plan must include adding this recognition logic, not just documenting the field.

## Context Extension Recommendations

- **Topic**: `.claude/extensions/memory/context/project/memory/README.md` Frontmatter Fields
  table is stale (missing `keywords`, `summary`, `retrieval_count`, `last_retrieved`,
  `status`/tombstone fields already in real use before 822).
  **Gap**: pre-existing documentation drift, unrelated to 822 but touched by the same file.
  **Recommendation**: 822's doc-update phase should opportunistically fix this table while adding
  the new `category` row, since it's the same file and same section.
- **Topic**: no cross-extension index documenting the `email/preferences/*` reserved topic
  namespace convention for future extension authors who might want a similarly-namespaced vault
  region. **Gap**: the convention exists only in the design doc (email-extension-scoped path),
  not in memory's own README/domain docs. **Recommendation**: consider a short "Reserved Topic
  Namespaces" note in `memory/context/project/memory/domain/memory-reference.md` (not read in
  this pass — flagged for the planner to check) once 822 ships, so a third extension author
  doesn't collide with `email/preferences/*` or invent an incompatible convention.

## Appendix

- Search queries used: direct file reads (Read tool) of all files listed in Sources/Inputs above;
  no WebSearch/WebFetch was needed (fully internal implementation-surface research).
- Key line references cited above are current as of this research pass (2026-07-12) and should
  be re-verified by the implementer with fresh `Read` calls before editing, per this repo's
  general convention of never trusting stale line numbers across sessions.
