# Implementation Plan: Task #822

- **Task**: 822 - Implement email cleanup to memory vault contribution
- **Status**: [COMPLETED]
- **Effort**: 5.5 hours
- **Dependencies**: 821 (COMPLETED — design deliverable consumed)
- **Research Inputs**: specs/822_email_cleanup_memory_vault_contribution/reports/01_email-memory-harvest-implementation.md
- **Artifacts**: plans/01_email-memory-harvest-implementation.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta

## Overview

Task 822 transcribes the completed 821 design (`email-to-memory-preferences.md`, authoritative,
G1-G8 fully resolved) into working skill prose and two concrete script edits. It routes
wrapper-confirmed `skill-email-cleanup` decisions into the memory vault as sender/domain-aggregated
`email/preferences/{account}/{key}` preference memories that evolve over time via
CREATE/UPDATE/EXTEND tally arithmetic — never one memory per message. The harvest is an opt-in,
never-silent gate mirroring `skill-todo`'s harvest -> dedup -> tiered-`AskUserQuestion` ->
batch-regen *logic* (not its `state.json` substrate). Scope is confined to
`.claude/extensions/email/` and `.claude/extensions/memory/` plus two shared scripts; the frozen
email wrapper and `email-preferences.md`'s static classifier table are never touched. Definition
of done: the three concrete edit surfaces are in place, deterministic logic is extracted to a
testable helper with a passing bash test script, guardrails prevent cross-contamination and purge
of preference memories, and both extensions' docs pass `check-extension-docs.sh`.

### Research Integration

Report `01_email-memory-harvest-implementation.md` pinpointed every edit site and confirmed no
new design decisions are required:
- `skill-email-cleanup/SKILL.md`: new Stage 7 (Harvest) inserted after BOTH Stage 6 (Verify)
  sections — Default mode (~`:178-181`) and `--all` mode (~`:398-402`); MUST-DO/MUST-NOT list
  updates (~`:540-568`).
- `skill-memory/SKILL.md`: exact-key dedup short-circuit ahead of Classification Thresholds
  (~`:200-206`); `category: preference` recognition with tags-derivation fallback; purge/scoring
  zero-retrieval exemption at BOTH the Zero-Retrieval Penalty component (~`:990-999`) and the
  Purge Candidate OR-condition (~`:2042-2050`).
- `.claude/scripts/memory-retrieve.sh`: topic-prefix cross-contamination pre-filter as a second
  `map(select(...))` immediately after the tombstone filter (~line 77).
- Testing: extract normalization/tally/dedup logic to a bash helper so it is unit-testable in the
  `.claude/tests/test-command-route-skill.sh` style (no SKILL-prose test harness exists).
- Docs: email README File Inventory + new Stage 7 subsection; memory README `category` row and
  reserved-namespace callout; `check-extension-docs.sh` as the doc-lint gate.

Report line references are treated as provisional — the implementer MUST re-`Read` each target
and re-locate the insertion point with fresh reads before editing (repo convention: never trust
stale line numbers across sessions).

### Prior Plan Reference

No prior plan. This is the first plan for task 822.

### Roadmap Alignment

Advances the ROADMAP.md "Email/Memory Integration" subsection (per research Sources). No
`roadmap_flag` was set for this dispatch, so no ROADMAP review/update phases are included; `/todo`
will annotate ROADMAP.md from `completion_summary` on completion.

## Goals & Non-Goals

**Goals**:
- Add an opt-in Stage 7 harvest to `skill-email-cleanup` (both modes) that writes
  `email/preferences/{account}/{key}` memories from wrapper-confirmed executed actions only.
- Implement the deterministic identity-key normalization (§2.2), per-action tally (§3.2), and
  exact-key dedup -> CREATE/EXTEND/UPDATE operation mapping (§4.1-§4.3) as a testable bash helper.
- Add the two guardrails: `/distill` purge/scoring zero-retrieval exemption (§5.1) and the
  `memory-retrieve.sh` topic-prefix cross-contamination pre-filter (§5.2).
- Add `category: preference` frontmatter recognition with tags-derivation fallback (§3.4).
- Fold in the §5.5 in-scope additions: cross-account key scoping, archive-scope tally isolation,
  revocation/edit UX via the existing tombstone pattern, minimal success-signal logging.
- Write a bash test script for the deterministic logic and update both extensions' docs to pass
  doc-lint.

**Non-Goals**:
- No changes to the frozen wrapper (`~/.dotfiles/modules/home/email/agent-tools.nix`) or to
  `email-preferences.md`'s static classifier rule table (821 Non-Goal, design §8).
- No read-back / `email_preference_lookup` consumer (design §6, seeded for task 823).
- No List-Id keying, notmuch-ruleset export, or cross-client generalization (design §2.4, §7).
- No new skill, command, or manifest structural change (in-place SKILL.md extension only).
- No re-litigation of any 821 design decision — the design is authoritative.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing `skill-memory/SKILL.md` (2482 lines) drifts unrelated sections (distill scoring, merge/compress) | H | M | Scope to the precisely-located insertion points via targeted `Edit` calls; never full-file rewrite; keep all skill-memory edits in one phase to avoid concurrent-wave file contention |
| Syntax error in the new `memory-retrieve.sh` jq filter breaks memory retrieval repo-wide (auto-invoked every /research /plan /implement preflight) | H | M | Test the jq filter against a synthetic `memory-index.json` fixture with `jq` directly (Phase 5) before/while wiring; keep the added `map(select(...))` on its own line for easy revert |
| `category: preference` recognition untested against `/distill`'s existing tags-derivation heuristic | M | M | Add the recognition-with-fallback logic explicitly (not just document the field); verify the other 19 memories (absent `category:`) still derive via tags |
| Stale line numbers from research cause mis-placed edits | M | M | Implementer re-`Read`s and re-locates every insertion point before editing |
| Two phases editing the same file in one wave cause conflicts | M | L | Territory rule: Phase 2 owns all `skill-memory/SKILL.md` edits exclusively; Phase 3 owns `memory-retrieve.sh`; Phase 4 owns `skill-email-cleanup/SKILL.md` |
| Harvest keying diverges from review bucket (mixed-sender §1.5) | M | L | Implement the first-class split/decline branch per design §1.5; review partition and memory partition are explicitly not required to be identical |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4, 5 | 1, 2 / 1, 3 |
| 3 | 6 | 4 |

Phases within the same wave can execute in parallel. Wave 2: Phase 4 blocked by 1, 2; Phase 5
blocked by 1, 3. Wave 3: Phase 6 blocked by 4 (and depends on 2's contract being final).

### Phase 1: Deterministic harvest helper (normalization + tally + exact-key dedup) [COMPLETED]

- **Goal:** Extract the design's deterministic, testable logic into a standalone bash helper so
  it is unit-testable in this repo's existing bash-test style, and reused verbatim by the Stage 7
  harvest prose.
- **Tasks:**
  - [x] Create `.claude/scripts/email-preference-harvest.sh` implementing: *(completed)*
    - [x] `normalize(sender)` per design §2.2: extract bare address, lowercase, strip plus-tag,
      primary key `local-part@domain`; non-freemail domain-rollup fallback with the freemail
      carve-out (gmail.com, yahoo.com, outlook.com, proton.me, ... never rolled up). *(completed:
      `normalize`/`identity` subcommands; `--rollup` flag gated by `freemail` subcommand)*
    - [x] Local-part redaction per §3.3: `domain` plaintext, `local-part` -> `sha256(local-part)[:12]`;
      domain-rollup keys carry no local-part and need no hash. *(completed: `identity` subcommand)*
    - [x] Cross-account key scoping per §5.5: emit `email/preferences/{account}/{key}` (never
      collapse across accounts). *(completed: caller composes `email/preferences/{account}/` +
      `identity`'s `.key`; verified via `dedup` subcommand's topic lookup)*
    - [x] Per-action tally model per §3.2: `{delete_count, archive_count, keep_count}` each with a
      per-action `last_seen`; derived `dominant = argmax(...)`, ties broken by most-recent
      per-action `last_seen`. *(completed: `dominant` subcommand)*
    - [x] Operation mapping per §4.3: CREATE (no exact key) / EXTEND (match, same dominant) /
      UPDATE (match, dominant differs — increment the opposite counter, never reset the matching
      one). *(completed: `tally-op` subcommand)*
    - [x] Exact-key dedup lookup per §4.1: `jq --arg k "email/preferences/${ACCOUNT}/${KEY}"
      '.entries[] | select(.topic == $k)' .memory/memory-index.json`. *(completed: `dedup`
      subcommand)*
  - [x] Structure the script as callable pure functions (subcommands or `source`-able functions)
    so the test script (Phase 5) can exercise normalization/tally/dedup without side effects.
    *(completed: 7 subcommands — normalize, freemail, identity, dedup, tally-op, dominant,
    threshold)*
  - [x] Evidentiary-threshold helper per §1.4: uniform-batch OR rolling N>=3 at >=80%, evaluated
    against the stored (post-increment) tally. *(completed: `threshold` subcommand)*
- **Timing:** ~1 hour
- **Depends on:** none

### Phase 2: skill-memory dedup, category recognition, and purge exemption [COMPLETED]

- **Goal:** Make `skill-memory/SKILL.md` aware of the reserved `email/preferences/*` namespace:
  exact-key short-circuit, namespace-scoped tally UPDATE/EXTEND variant, `category:` frontmatter
  recognition, and the zero-retrieval purge/scoring exemption. This phase exclusively owns all
  edits to `skill-memory/SKILL.md`.
- **Tasks:**
  - [x] Re-`Read` around the Classification Thresholds table (~`:200-206`) and add a new
    subsection ("Exact-Key Dedup for Reserved Namespaces") immediately before it, scoped to
    `topic` values matching `email/preferences/*`: a `topic ==` exact match short-circuits
    straight to UPDATE/EXTEND without computing keyword overlap (design §4.1). Document this as a
    sanctioned deviation from the fuzzy 60%/30% contract; retain the fuzzy path as a labeled
    near-miss *suggestion* only (§4.2). *(completed)*
  - [x] Document the namespace-scoped UPDATE/EXTEND *tally-arithmetic* variant (§4.3) as distinct
    from the generic wholesale UPDATE/EXTEND templates: EXTEND appends a dated `## History` line
    and bumps one counter; UPDATE increments the opposite counter and moves the prior summary line
    to `## History` marked `(superseded)`. Include the §3.5 memory body template (tally block,
    `## History`, evidence line, `category: preference`). *(completed: new "Namespace-Scoped
    Tally-Arithmetic UPDATE/EXTEND" subsection)*
  - [x] Add `category: preference` frontmatter recognition (§3.4): `index.md`/`/distill` prefer a
    present `category:` field over the tags-derived heuristic and fall back to tags-derivation when
    absent (non-breaking for the existing 19 memories). *(completed: JSON Index Maintenance loop +
    Schema Fields table + refine Tier-2 category_reclassify guard)*
  - [x] Add the zero-retrieval exemption (§5.1) at BOTH sites after re-`Read`ing them: the
    Zero-Retrieval Penalty scoring component (~`:990-999`) and the Purge Candidate OR-condition
    (~`:2042-2050`). The exemption `AND NOT topic startswith "email/preferences/"` must gate the
    whole purge OR-condition (`zero_retrieval_penalty == 1.0 OR staleness_score > 0.8`), not just
    the zero-retrieval leg. *(completed: both sites edited)*
  - [x] Document the archive-scope tally isolation contract (§5.5): archive-scope-sourced confirms
    recorded in a distinct `### Archive-scope tally` sub-section within the same memory (never a
    separate memory), preserving "one evolving memory per sender/domain." *(completed: folded into
    the Namespace-Scoped Tally-Arithmetic subsection)*
  - [x] Note the revocation/edit UX reuses the existing tombstone pattern (`status: tombstoned`,
    `tombstoned_at`, `tombstone_reason`); reference it here so Phase 4 can wire the user-invoked
    "forget this preference" action. *(completed: folded into the same subsection, with
    `tombstone_reason: "user_revoked"`)*
- **Timing:** ~1.25 hours
- **Depends on:** none

### Phase 3: memory-retrieve.sh cross-contamination pre-filter [COMPLETED]

- **Goal:** Prevent `email/preferences/*` memories from leaking into unrelated
  `/research`/`/plan`/`/implement` auto-retrieval. This phase exclusively owns
  `memory-retrieve.sh`.
- **Tasks:**
  - [x] Re-`Read` the scoring block (~lines 74-102) and confirm the tombstone pre-filter line
    (~line 77: `map(select((.status // "active") == "active")) |`).
  - [x] Add a second `map(select(...))` stage immediately after it (design §5.2):
    ```
    map(select(
      ((.topic // "") | startswith("email/preferences/")) and ($tt != "email")
      | not
    )) |
    ```
    Keep it on its own line for easy revert. This is an effectively unconditional exclusion today
    (no `email` task type exists in core routing) while leaving the door open for a deliberate
    future email-side reader passing `task_type="email"`. *(completed: applied verbatim to both
    `.claude/scripts/memory-retrieve.sh` and its extension-source copy
    `.claude/extensions/core/scripts/memory-retrieve.sh` to avoid deployed-vs-source drift)*
  - [x] Sanity-check the jq filter compiles against a minimal synthetic index before committing
    (full fixture assertions live in Phase 5). *(completed: verified against a synthetic
    2-entry fixture -- task_type=general excludes the email/preferences/* entry, task_type=email
    includes it)*
- **Timing:** ~0.5 hours
- **Depends on:** none

### Phase 4: skill-email-cleanup Stage 7 harvest (both modes) + folded-in scope [COMPLETED]

- **Goal:** Add the opt-in, never-silent Stage 7 harvest gate after Stage 6 (Verify) in both
  Default and `--all` modes, wiring the Phase 1 helper and the Phase 2 skill-memory contract. This
  phase exclusively owns `skill-email-cleanup/SKILL.md`.
- **Tasks:**
  - [x] Re-`Read` both Stage 6 (Verify) sections (Default ~`:178-181`; `--all` ~`:398-402`) and
    insert a new Stage 7 (Harvest) after each, before the following `---` section break.
  - [x] Default mode Stage 7: derive keys post-hoc per executed Message-ID from the approved
    manifest's `sender` field (§1.2), grouped by the Phase 2/normalization key across all
    Stage-6-executed IDs; read only the Stage 6 *executed* diff (never Stage 2/3/4 unconfirmed).
  - [x] `--all` mode Stage 7: key off the Stage 2.5 bucket grouping cross-referenced against the
    per-split Stage 6 executed totals; only actually-executed bucket members count as evidence.
    *(completed: `--all` Stage 7 reuses Default Stage 7's Steps 2-11 verbatim by reference and
    overrides only Step 1, key derivation)*
  - [x] Implement the harvest -> dedup -> tiered `AskUserQuestion` -> batch-regen flow mirroring
    `skill-todo` Stages 7-9 + 14 *logic only* (never `state.json`/`project_number` substrate):
    - [x] Tier 1 pre-selected: keys meeting the evidentiary threshold (§1.4) this round.
    - [x] Tier 2 shown-not-preselected: keys newly crossing the rolling-N threshold this round.
    - [x] Fuzzy near-miss suggestions (§4.2) as a labeled, non-pre-selected option.
    - [x] One consolidated non-silent prompt; batch-regenerate `memory-index.json` once after the
      whole round (§4.4), independent of the `--clean` flag (§5.4).
  - [x] Mixed-sender handling (§1.5) as a first-class branch: split by subject/category token into
    distinct keys OR decline to aggregate that portion this pass — never average into a false
    scalar.
  - [x] Feedback-loop cap (§5.3): the harvest MUST NOT mutate `proposed_action` or raise
    `confidence`; the vault stays strictly advisory relative to the frozen classifier.
  - [x] Revocation/edit UX (§5.5): a user-invoked "forget this preference" action reusing the
    tombstone pattern (or a tally reset), distinct from `/distill --purge`, never automatic.
  - [x] Minimal success-signal logging (§5.5): log a per-round agreement rate (confirmed action ==
    memory's pre-round derived dominant, when a memory pre-existed) as a harvest log line.
  - [x] Update the Critical Requirements lists (~`:540-568`): add a MUST-DO ("run the opt-in
    harvest gate after Stage 6, on wrapper-executed IDs only") and a MUST-NOT ("harvest never
    mutates `proposed_action`/confidence"). *(completed: MUST-DO item 7, MUST-NOT item 9)*
  - [x] Confirm `allowed-tools` frontmatter (`Bash, Read, AskUserQuestion`) remains sufficient
    (Bash/jq/file-write path); change only if the chosen implementation requires `Write`/`Edit`.
    *(completed: confirmed sufficient, no frontmatter change — Stage 7 Step 7 documents the
    Bash/jq heredoc file-write path explicitly)*
- **Timing:** ~1.5 hours
- **Depends on:** 1, 2

### Phase 5: Bash test script for deterministic logic [COMPLETED]

- **Goal:** Provide the "tests" deliverable using this repo's existing bash-assertion convention,
  exercising the Phase 1 helper and the Phase 3 retrieve filter.
- **Tasks:**
  - [x] Create `.claude/tests/test-email-preference-harvest.sh` in the style of
    `.claude/tests/test-command-route-skill.sh` (pure-bash assertions, no bats/spec framework).
  - [x] Assert normalization of the four verified §2.3 edge cases: freemail multiplicity (gmail
    addresses never rolled up), sender-side plus-addressing strip
    (`invoice+statements@stripe.com` -> `invoice@stripe.com`), DMARC "via" relay keying (key
    resolves to the relay/list address), case-insensitivity (`CorrAdmin1@spi-global.com`).
  - [x] Assert CREATE/EXTEND/UPDATE tally transitions per the §4.3 table (including the
    opposite-counter increment flipping the derived dominant action).
  - [x] Assert the exact-key jq lookup (§4.1) against a synthetic `memory-index.json` fixture
    (hit -> short-circuit; miss -> CREATE default).
  - [x] Assert the `memory-retrieve.sh` topic-prefix exclusion against a small fixture index:
    `task_type=general` -> email-preference entry NOT returned; `task_type=email` -> entry IS
    returned (§5.2 future-compat carve-out).
  - [x] Run the test script and confirm all assertions pass. *(completed: 35/35 assertions pass)*
- **Timing:** ~1 hour
- **Depends on:** 1, 3

### Phase 6: Documentation updates + doc-lint [COMPLETED]

- **Goal:** Update both extensions' READMEs to reflect the harvest and new schema, and pass
  doc-lint.
- **Tasks:**
  - [x] `email/README.md`: add a File Inventory row for
    `context/project/email/design/email-to-memory-preferences.md`; add a "Using `/email`"
    subsection describing the opt-in Stage 7 harvest gate (mirroring how the `--sync` confirmation
    gate is documented). *(completed: File Inventory rows for the design doc + the new
    `scripts/email-preference-harvest.sh`; new "Preference harvest (opt-in Stage 7, both modes)"
    subsection)*
  - [x] `memory/README.md`: add a `category` row to the Frontmatter Fields table; opportunistically
    fix the pre-existing gap (add `keywords, summary, retrieval_count, last_retrieved`,
    tombstone/`status` fields already in real use); add a short "Reserved Topic Namespaces" callout
    documenting the `email/preferences/*` convention and the hashed local-part rationale.
    *(completed)*
  - [x] Note in prose (README/EXTENSION.md) that the `memory` manifest's `hooks: {}` lifecycle slot
    is intentionally unused (design §1.3 rejection), since JSON cannot carry a comment.
    *(completed: new "Lifecycle Hooks (unused)" subsection in memory/README.md's Configuration
    section)*
  - [x] Confirm no manifest structural changes are needed (no new skills/commands); `provides.context`
    globs already cover the new `design/` subdirectory. *(confirmed: only `provides.scripts` in
    the email manifest changed, adding `email-preference-harvest.sh`; no skill/command/context
    structural changes)*
  - [x] Run `bash .claude/scripts/check-extension-docs.sh` and resolve any reported failures.
    *(completed: exit 0, all 20 extensions PASS — email and memory both clean; the one email WARN
    is the pre-existing "extension not installed" notice, unrelated to this task's changes)*
- **Timing:** ~0.75 hours
- **Depends on:** 4

## Testing & Validation

- [x] `.claude/tests/test-email-preference-harvest.sh` passes all assertions (normalization edge
  cases, tally transitions, exact-key dedup, retrieve-filter inclusion/exclusion). *(35/35 pass)*
- [x] `jq` compiles the new `memory-retrieve.sh` filter without error; a general-task-type
  retrieval against a fixture containing an `email/preferences/*` entry returns no leak.
  *(verified against a synthetic 2-entry fixture)*
- [x] `bash .claude/scripts/check-extension-docs.sh` exits zero after doc updates. *(exit 0, all
  20 extensions PASS)*
- [x] Manual dry-run walkthrough (documented in the summary): synthetic Default-mode Stage 6
  executed diff and synthetic `--all` bucket set each produce the expected Tier 1/Tier 2 gate
  presentation and, on confirm, the expected CREATE/EXTEND/UPDATE with a single batch index regen.
  *(completed: full Default-mode CREATE -> EXTEND -> UPDATE round-trip run against a scratch
  `.memory/` directory, including a rendered memory file matching the §3.5 template and a
  regenerated index; `--all` mode's Stage 7 differs only in key derivation — Step 1 — which
  reuses the identical `identity` subcommand, so Steps 2-11 are covered by the same walkthrough)*
- [x] Verify the other 19 existing memories (no `category:` field) still derive category via the
  tags-based fallback after the Phase 2 recognition change. *(verified: 18 memories currently on
  disk, 0 have a `category:` field, all exercise the fallback path; spot-checked one file's
  derivation manually)*
- [x] Confirm the frozen wrapper and `email-preferences.md` are unmodified (`git diff` scope check).
  *(confirmed: neither file appears in any task-822 commit; the wrapper lives outside this repo
  entirely)*

## Artifacts & Outputs

- plans/01_email-memory-harvest-implementation.md (this file)
- `.claude/scripts/email-preference-harvest.sh` (new helper)
- `.claude/tests/test-email-preference-harvest.sh` (new test)
- Edits: `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md`,
  `.claude/extensions/memory/skills/skill-memory/SKILL.md`,
  `.claude/scripts/memory-retrieve.sh`,
  `.claude/extensions/email/README.md`, `.claude/extensions/memory/README.md`
- summaries/01_email-memory-harvest-implementation-summary.md (on completion)

## Rollback/Contingency

- Each edit surface is isolated and independently revertible: the helper and test script are new
  files (delete to revert); the three edited files change only precisely-located sections via
  targeted `Edit`s.
- Highest-risk change is the `memory-retrieve.sh` jq filter (live, auto-invoked). If retrieval
  breaks, revert the single added `map(select(...))` line; the tombstone pre-filter above it is
  untouched and retrieval returns to prior behavior.
- If `category: preference` recognition regresses tags-derivation for existing memories, revert the
  Phase 2 recognition block; the field remains schema-additive and inert without the recognition
  logic.
- All changes are documentation/skill-prose/script edits with no production runtime dependency, so
  a `git revert` of the task commit fully restores prior behavior.
