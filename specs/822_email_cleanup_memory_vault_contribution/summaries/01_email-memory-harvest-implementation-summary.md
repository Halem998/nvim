# Implementation Summary: Task #822

**Completed**: 2026-07-12
**Duration**: single session, 6 phases across 3 dependency waves

## Overview

Implemented the task 821 design (`email-to-memory-preferences.md`) transcribing it into
working skill prose and two concrete script edits. `skill-email-cleanup` now has an opt-in
Stage 7 harvest (both Default and `--all` modes) that routes wrapper-confirmed cleanup
decisions into the memory vault as sender/domain-aggregated `email/preferences/{account}/{key}`
preference memories, evolving via CREATE/EXTEND/UPDATE tally arithmetic. `skill-memory` gained
exact-key dedup, `category:` frontmatter recognition, and a zero-retrieval purge/scoring
exemption for this reserved namespace. `memory-retrieve.sh` gained a cross-contamination filter
preventing these memories from leaking into unrelated `/research`/`/plan`/`/implement`
auto-retrieval. All deterministic logic (normalization, redaction, tally arithmetic, exact-key
dedup, evidentiary threshold) lives in a new, independently unit-tested bash helper.

## What Changed

- `.claude/scripts/email-preference-harvest.sh` (new) — deterministic pure-function helper with
  7 subcommands (`normalize`, `freemail`, `identity`, `dedup`, `tally-op`, `dominant`,
  `threshold`) implementing design §2.2 (normalization), §3.3 (redaction), §3.2/§4.3 (tally
  model + CREATE/EXTEND/UPDATE mapping), §4.1 (exact-key dedup), §1.4 (evidentiary threshold).
- `.claude/extensions/email/scripts/email-preference-harvest.sh` (new) — extension-source copy,
  byte-identical to the deployed script (required by `check-extension-docs.sh`'s drift check).
- `.claude/extensions/email/manifest.json` — added `email-preference-harvest.sh` to
  `provides.scripts`.
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` — new "Exact-Key Dedup for Reserved
  Namespaces" subsection (before Classification Thresholds), new "Namespace-Scoped
  Tally-Arithmetic UPDATE/EXTEND" subsection (body template, archive-scope isolation,
  tombstone-based revocation), `category:` frontmatter recognition in JSON Index Maintenance
  (with a guard added to `/distill --refine`'s category-reclassify Tier-2 fix so an explicit
  `category:` is never overridden by content inference), and a zero-retrieval exemption at both
  the Zero-Retrieval Penalty scoring component and the Purge Candidate OR-condition.
- `.claude/scripts/memory-retrieve.sh` + `.claude/extensions/core/scripts/memory-retrieve.sh` —
  identical topic-prefix `map(select(...))` pre-filter excluding `email/preferences/*` from
  general auto-retrieval, added immediately after the existing tombstone pre-filter.
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — new Stage 7 (Harvest)
  sections after Stage 6 (Verify) in both Default and `--all` modes; Default mode carries the
  full 11-step procedure (key derivation, mixed-sender handling, per-key dedup/tally,
  evidentiary threshold, archive-scope isolation, the consolidated tiered gate, the Bash/jq
  memory-file write path, batch index regen, the feedback-loop cap, revocation UX, success-rate
  logging); `--all` mode reuses Steps 2-11 by reference and overrides only Step 1 (bucket-based
  key derivation). Critical Requirements MUST-DO/MUST-NOT lists updated accordingly.
  `allowed-tools` frontmatter (`Bash, Read, AskUserQuestion`) confirmed sufficient — no change.
- `.claude/tests/test-email-preference-harvest.sh` (new) — 35 pure-bash assertions covering the
  four verified §2.3 normalization edge cases, redaction/rollup behavior, CREATE/EXTEND/UPDATE
  tally transitions (including a dominant-action flip), the evidentiary threshold, exact-key
  dedup hit/miss, and the `memory-retrieve.sh` topic-prefix filter. All 35 pass.
- `.claude/extensions/email/README.md` — File Inventory rows for the design doc and the new
  script; a "Preference harvest (opt-in Stage 7, both modes)" subsection.
- `.claude/extensions/memory/README.md` — `category` row plus a pre-existing Frontmatter Fields
  gap fix (`keywords`, `summary`, `retrieval_count`, `last_retrieved`, `status`/tombstone
  fields), a new Tombstoning subsection, a "Reserved Topic Namespaces" callout, and a
  "Lifecycle Hooks (unused)" note explaining the memory manifest's `hooks: {}` slot.

## Decisions

- Followed the plan's explicit territory split exactly: Phase 2 owned all `skill-memory/SKILL.md`
  edits, Phase 3 owned `memory-retrieve.sh` only, Phase 4 owned `skill-email-cleanup/SKILL.md`
  only — no cross-file contention across the wave-1 parallel phases.
- `--all` mode's Stage 7 was written as a short section that reuses Default mode's Steps 2-11 by
  explicit reference rather than duplicating ~80 lines of near-identical procedural prose twice
  — reduces future drift risk between the two mode-specific Stage 7 sections while still
  satisfying the plan's "insert a new Stage 7 after each Stage 6" requirement.
- `.claude/extensions/email/scripts/email-preference-harvest.sh` was created as the extension's
  own source-of-truth copy (mirroring how `memory-retrieve.sh` is owned by `core`), keeping it
  byte-identical to the deployed `.claude/scripts/` copy to satisfy `check-extension-docs.sh`'s
  deployed-vs-source drift check.
- Memory file writes in Stage 7 are documented as a Bash/jq heredoc operation, not a `Write`/
  `Edit` tool call or a `skill-memory`/`/learn` dispatch — this keeps `skill-email-cleanup`'s
  existing `allowed-tools: Bash, Read, AskUserQuestion` frontmatter unchanged, as anticipated by
  the plan's Phase 4 task list.
- Added a guard to `/distill --refine`'s Tier-2 category-reclassify fix so it skips memories with
  an explicit `category:` frontmatter field — a design-adjacent but necessary addition beyond
  the plan's literal wording, to prevent an explicit `category: preference` from later being
  suggested away by content-based inference.

## Plan Deviations

- None (implementation followed plan). The category-reclassify guard above is a direct
  consequence of implementing "category: preference frontmatter recognition" faithfully (an
  explicit field must be authoritative, not just read-preferred at index-generation time) rather
  than a deviation from any stated plan step.

## Verification

- Build: N/A (documentation/script edits, no compiled artifact)
- Tests: `.claude/tests/test-email-preference-harvest.sh` — 35/35 passed.
  `.claude/tests/test-command-route-skill.sh` (pre-existing suite) — 12/12 passed (regression
  check, unrelated to this task but confirms nothing broke).
- Doc-lint: `bash .claude/scripts/check-extension-docs.sh` exits 0 — all 20 extensions PASS
  (email and memory both clean; the one email WARN is the pre-existing "extension not
  installed" notice, unrelated to this task).
- Manual dry-run: full Default-mode CREATE -> EXTEND -> UPDATE round-trip executed against a
  scratch `.memory/` directory (not the live vault), producing a memory file matching the
  design's §3.5 body template and a correctly regenerated index.
- Files verified: Yes — all new files exist and are executable where applicable; all edited
  files retain valid markdown fence balance and valid JSON (manifests, index fixtures).
- Scope check: `git diff --stat` across all 5 task commits touches exactly the files declared in
  the plan's Artifacts & Outputs section (plus per-phase progress files); the frozen wrapper and
  `email-preferences.md` are untouched.

## Notes

- The read-back consumer (`email_preference_lookup`, design §6) is explicitly out of scope for
  822 and was not implemented — the vault is write-only (a preference log, not yet a preference
  engine) as designed, seeded for a future task.
- The `--all` mode Stage 7 walkthrough was validated conceptually (same `identity`/`tally-op`/
  `threshold` subcommands, same Steps 2-11) rather than with a second full live-diff simulation,
  since its only structural difference from Default mode is the bucket-based key-derivation step
  (Step 1), already covered directly by the `identity` subcommand's own unit tests.
- 18 pre-existing memory files (not 19, per the design's count at time of writing) were confirmed
  to have no `category:` frontmatter field and to still derive their category correctly via the
  tags-fallback path after the Phase 2 change.
