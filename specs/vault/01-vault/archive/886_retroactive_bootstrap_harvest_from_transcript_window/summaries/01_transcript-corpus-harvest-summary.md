# Implementation Summary: Task #886

**Completed**: 2026-07-15
**Duration**: resumed session (Phases 1-4 committed by a prior, killed session; this session completed Phases 5-6)

## Overview

Mined the Claude Code transcript corpus (`~/.claude/projects/`) and the durable
`~/.claude/history.jsonl` prompt spine, once, into a pointer-based dataset under this task's
`specs/` tree. Fixed a real manifest-corruption bug inherited from a killed prior session,
completed the orchestrator script and the outcome-inference modeling decision, ran the harvest to
completion, registered the four harvest scripts as deployable memory-extension artifacts, and
validated the result against observed (not assumed) numbers.

## What Changed

- `agent-system/extensions/memory/scripts/bootstrap-harvest.sh` — new. Orchestrates the three
  passes (transcripts, history spine, attribution), joins them on `session_id`, computes the
  `inferred_outcome` label, and writes `harvest-manifest.json`. Fixed during this session:
  `parse_kv_line` was picking up interleaved WARN diagnostic lines ahead of each pass's summary
  line, corrupting the manifest into invalid JSON.
- `agent-system/extensions/memory/scripts/bootstrap-harvest-attribution.sh` — fixed a declared-
  but-never-incremented `sidecars_decode_failed` counter; it now increments on decode failure and
  is included in the script's stderr summary line.
- `agent-system/extensions/memory/scripts/bootstrap-harvest-history.sh` — self-exclusion via
  `$CLAUDE_CODE_SESSION_ID` (carried over from the killed session's WIP, verified correct).
- `agent-system/extensions/memory/manifest.json` — added `provides.scripts` listing all four
  harvest scripts (this key did not exist before; without it `loader.lua:copy_scripts()` would
  never deploy them).
- `agent-system/extensions/memory/README.md` — added a "Bootstrap Harvest Scripts" section
  documenting the pipeline, its read-only contract, and usage.
- `specs/886_.../dataset/sessions.jsonl` — new (generated). 829 rows, one per top-level transcript
  session.
- `specs/886_.../dataset/history-spine.jsonl` — new (generated). 4,930 rows, one per
  `history.jsonl` `sessionId`.
- `specs/886_.../dataset/harvest-manifest.json` — new (generated). Run metadata, per-pass counts,
  `inferred_outcome` distribution, tool versions.
- `specs/886_.../dataset/README.md` — new. Schema, the `inferred_outcome` modeling decision,
  pointer-based design rationale, and known gaps stated honestly.
- `specs/886_.../plans/01_transcript-corpus-harvest.md` — Phases 5-6 and the Testing & Validation
  checklist checked off with completion/deviation notes; top-level Status set to `[COMPLETED]`.
- `specs/886_.../progress/phase-5-progress.json`, `phase-6-progress.json` — new.

## Decisions

- Re-ran the full harvest three times during this resume (not once) to reach a fully correct,
  internally consistent manifest: the first re-run fixed the `parse_kv_line` corruption, the
  second additionally fixed the `sidecars_decode_failed` reporting gap, and the last two runs
  converged to identical counts. The corpus read is read-only and idempotent, so re-running
  carries no risk to the source data.
- Kept `EXTENSION.md` unchanged — it is the CLAUDE.md merge-source for command-level docs and
  does not need per-script detail; the doc-lint rule requiring scripts-in-docs to be declared in
  `provides.scripts` is satisfied via `README.md` alone.
- Left the memory extension's pre-existing task-number citations (in `README.md`, `SKILL.md`,
  `commands/*.md`, predating this task) untouched — out of this task's scope; only new content
  added by this task was checked and confirmed clean.

## Plan Deviations

- **Phase 5 harvest run count**: ran three times instead of once, to converge on a correct
  manifest after fixing two bugs inherited from the killed prior session (see Decisions above).
- **Phase 3's sentinel-row expectation** (pre-existing, inherited from the earlier committed
  phase, restated for completeness): the live `history.jsonl` shows 0 sessionId-less sentinel
  rows on this run, versus the task description's inventory figure of 437 — flagged as a
  time-of-observation divergence, not suppressed.
- **Testing checklist item "`check-extension-docs.sh` exits 0"**: the gate's overall exit code is
  1, but this is entirely a pre-existing `[core]` deploy-drift advisory (`skill-base.sh`,
  `orchestrator-postflight.sh`, `parse-command-args.sh`, `scripts/memory-harvest.sh`) owned by a
  concurrently running sibling task. The `[memory]` extension section — the scope this task
  actually owns — reports `OK` / `PASS` on its own.
- **Testing checklist item "attribution resolution rate ~63%"**: measured 63.8% on the final run,
  matching the expectation; no divergence to flag.
- **`inferred_outcome` distribution contradicts the plan's plausibility expectation**: the plan
  expected most sessions to be `clean` given the 2.9% corpus-wide `is_error` density, but the
  measured distribution is `{clean: 133, high_error: 472, mixed: 190, trivial: 34}` — 57% of
  sessions are `high_error`. Reported as an honest contradiction (see dataset/README.md and the
  plan's Testing & Validation section for the likely explanation: subagent-failure roll-up
  crossing the 10% threshold even when the parent session's own direct tool calls are clean).

## Verification

- Build: N/A (shell scripts + generated JSONL/JSON data)
- Tests: N/A (no test suite for this task type)
- Files verified: Yes — every row of both JSONL files passes `jq -e .` (829/829, 4930/4930), the
  manifest parses as valid JSON, the self-exclusion sessionId is absent from every `session_id`
  field in both dataset files, and `check-extension-docs.sh`'s `[memory]` section reports `OK`.

## Notes

- **Test-fixture transcript found in the corpus**: `sessions.jsonl` retains one row
  (`session_id: 618b2f2f-...`) whose `repo` is a scratchpad path used by an unrelated task's
  implementation testing. It is a real, legitimately-created Claude Code session — not a
  self-exclusion failure and not fabricated by this harvest — and was retained as-is per the
  read-only, non-editorializing design of the dataset. Documented in `dataset/README.md`'s Known
  Gaps section.
- **ProofChecker has zero retained transcripts**: confirmed independently — the highest-usage
  project in the durable history spine (8,720 prompts / 2,088 sessions) contributes zero rows to
  `sessions.jsonl`, so it has no outcome signal in this harvest at all.
- **Retention-cliff measurement**: 86.5% of distinct `history.jsonl` session ids have no matching
  transcript remaining (664 of 4,930 have one) — close to, but independently measured from, the
  plan's ~88% design-time estimate.
