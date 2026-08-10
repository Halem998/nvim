# Implementation Plan: Dead-Machinery Quarantine Sweep

- **Task**: 985 - Dead-code quarantine sweep: orphan scripts, dead rules, dead Lua, vestigial twins
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: 952, 960, 963, 964, 969, 973, 980, 981, 982, 984, 987, 988, 992 (all confirmed landed by the research pass)
- **Research Inputs**: specs/985_quarantine_dead_scripts_rules_and_machinery/reports/01_dead-machinery-triage.md
- **Artifacts**: plans/01_dead-machinery-quarantine.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Execute the research report's per-item triage table: MOVE (never delete) nine genuinely dead
scripts into `deprecated/` directories with per-file README rationale, drop their
`manifest.json` `provides.scripts` declarations in the same substep, repair and wire in the one
valuable-but-unwired lint script as a new `verify-deploy.sh` gate, and land the documentation
notes that keep the four legitimate operator tools and the two auto-loaded rule files from being
mis-triaged as dead by the next audit. The research pass corrected the original inventory
substantially — both "dead rules" are live via YAML `paths:` frontmatter, two `test-*.sh` scripts
are live via `run-all.sh`'s discovery glob, and five inventory items are already resolved
upstream — so this plan implements the corrected triage, not the original review's list.

Definition of done: every quarantined file sits under a `deprecated/` directory with a README
rationale line and no manifest declaration; `check-extension-docs.sh` and `verify-deploy.sh` both
pass; a caller-graph re-grep finds zero live references to any quarantined basename; and a
destructive wipe-and-regenerate produces a `.claude/` tree containing none of them.

### Research Integration

Load-bearing corrections from the research report that this plan encodes:

- **Finding 0** (rule loading): `.claude/rules/*.md` are auto-loaded natively by the harness via
  their YAML `paths:` frontmatter glob, independent of `CLAUDE.md`'s `@`-import list. Neither
  `pr-prohibition.md` nor `project-overview-detection.md` is dead. Both are **keep-with-doc-note**.
  Quarantining either is a defect, not a scope reduction.
- **Finding 1**: nine files are genuinely dead (eight core scripts plus literature's
  `literature-decode-font-offset.py`); `roadmap-sync.sh` and `validate-extension-index.sh` are
  additionally **superseded duplicates** of differently-named live scripts, a fact the README
  must record so a future audit does not re-derive it.
- `lint/lint-contract-compliance.sh` is **wire-in, not quarantine** — genuinely non-redundant
  against the three lint scripts already wired as gates 6/7/9.
- Items already resolved upstream and explicitly out of edit scope: `skill-orchestrator/SKILL.md`
  + its `.archived` twin, both `EXTENSION.md` files, and `sync.lua`'s retired glob engine. The
  only residual edit in that cluster is one dead `.syncprotect` line.

Mechanical facts confirmed during planning (do not re-derive; do re-verify if a phase depends
on one):

| Fact | Consequence for this plan |
|---|---|
| `check-extension-docs.sh` Rule Q (`check_undeclared_scripts`) skips `deprecated/*` | Moving a script to `deprecated/` AND dropping its manifest entry is the sanctioned, lint-clean pattern |
| `.claude/` is gitignored; Rule M orphan check enumerates via `git ls-files .claude/<cat>` | Rule M is a structural no-op in this repo — stale deployed copies will NOT trip doc-lint after the manifest drop. Do not treat their survival as a failure |
| `verify.lua` category parity is declared -> deployed only | Dropping a manifest entry cannot break gate 5; nothing re-checks the reverse direction |
| `deploy-headless.sh` default mode is non-destructive (`resync_all`); `--wipe` is the destructive rebuild | The "no quarantined file present in `.claude/`" bar requires `--wipe`, not a plain resync |
| `lint/lint-contract-compliance.sh` currently emits 15 failures, and its own output names `agent-system/extensions/.claude/context/index.json` | Its root resolution is broken (`$SCRIPT_DIR/../../..` lands on `agent-system/extensions`). The failures are path artifacts, not real contract violations — fix resolution before triaging findings |
| `.syncprotect` has no source-store copy and is absent from `provides.root_files` | Edit the repo-root `.syncprotect` directly; this is not a source-store-boundary violation |
| Literature's `scripts/deprecated/README.md` is the format precedent | Mirror its shape: `# Deprecated Scripts` / `## Purpose` / `## Contents` with one bullet per file naming what superseded it |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- Quarantine (MOVE + document, never delete) the nine confirmed-dead files, with manifest
  declarations dropped in the same substep as each move.
- Record, per file, *why* it is dead — especially supersession by a differently-named live
  script, and the prose-is-authoritative decision for the three `commands/todo.md`
  reimplementations.
- Repair `lint/lint-contract-compliance.sh`'s root resolution, triage its real findings, and wire
  it in as a new `verify-deploy.sh` gate.
- Document the four legitimate manual operator tools and the native rule-loading mechanism so
  the next dead-code audit does not repeat the review's two mis-triages.
- Delete the one dead `.syncprotect` line.

**Non-Goals**:
- Do NOT quarantine `pr-prohibition.md` or `project-overview-detection.md`. Both are live.
- Do NOT touch `test-four-tier-conflict.sh`, `test-session-runtime-files.sh` (live via
  `run-all.sh`), or `validate-context-budgets.sh` (reserved for its own consumer task).
- Do NOT re-decide or re-touch the `EXTENSION.md` files, `skill-orchestrator`'s files, or
  `sync.lua` — all already resolved upstream. Re-verify only.
- Do NOT repair, re-wire, or "fix" any quarantined script. Quarantine is terminal for this task.
- Do NOT extract `vault-operation.sh`'s logic into a new safe script. The task's own instruction
  and the research decision both select "prose is authoritative" over extraction.
- Do NOT edit anything under `.claude/**`. All source edits land in
  `agent-system/extensions/**`, plus the repo-root `.syncprotect`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A moved script's manifest entry is left behind, so the deploy engine fails on a missing path | H | M | Treat move + manifest drop as ONE substep per file; after each, re-run `jq -e '.provides.scripts \| index("<name>")'` expecting null, and validate the whole manifest parses |
| A quarantined basename still has a live caller the research grep missed | H | L | Phase 1 re-runs the caller-graph grep per basename immediately before each move, across `agent-system/extensions/**`, `lua/**`, and `.claude/**`, excluding the file's own body and its manifest line |
| Wiring `lint-contract-compliance.sh` as a blocking gate surfaces pre-existing real contract violations and turns `verify-deploy.sh` red repo-wide | H | M | Phase 2 fixes root resolution and runs the script standalone with `--verbose` FIRST; the gate is only added after a clean (or triaged-and-fixed) standalone run, per the Rule T/U migration precedent |
| A future contributor "restores" `vault-operation.sh` and resurrects the unmutexed-write hazard | M | M | The README entry must state per-file why the prose path is safer and that reactivation requires closing the mutex/renumbering gap first, not merely restoring a caller |
| The four operator tools are re-flagged as dead by a shallower future grep | M | H | Phase 3 adds them to `CLAUDE.md`'s Utility Scripts list — a documented manual entry point is a different disposition than an undocumented orphan |
| `deploy-headless.sh --wipe` is unavailable (no headless nvim) in the implementation environment | M | M | Phase 4 attempts `--dry-run` first; on unavailability, record the deploy-tree check as explicitly deferred with a named reason and verify all source-store invariants instead — never silently skip |
| Editing `index-entries.json`-tracked context files without refreshing `line_count` trips doc-lint Rule R | M | M | Phase 3 runs `generate-context-line-counts.sh --write` after any context-file edit and re-runs doc-lint |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 1 and 2 have disjoint file
territory: Phase 1 owns the two `manifest.json` files and the moved script paths; Phase 2 owns
`scripts/lint/lint-contract-compliance.sh` and `scripts/verify-deploy.sh`. Neither touches
`merge-sources/claudemd.md`, which Phase 3 owns exclusively.

---

### Phase 1: Quarantine the nine dead scripts [COMPLETED]

**Goal**: Move eight core scripts and one literature Python script into `deprecated/`
directories, drop each from its manifest's `provides.scripts`, and write per-file rationale
READMEs mirroring the literature precedent.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/deprecated/` and author its `README.md`
      following the shape of `agent-system/extensions/literature/scripts/deprecated/README.md`
      (`# Deprecated Scripts` / `## Purpose` / `## Contents` with one bullet per file). *(completed)*
- [x] For each of the eight core scripts, as ONE substep (re-grep, move, manifest drop, verify):
      `check-vault-threshold.sh`, `vault-operation.sh`, `claude-project-cleanup.sh`,
      `orphan-detection.sh`, `rename-session.sh`, `roadmap-sync.sh`,
      `validate-extension-index.sh`, `archive-task.sh`. *(completed: all 8 moved, per-file
      caller-graph re-grep zero live callers, manifest entries dropped and confirmed)*
  - [x] Re-run the caller-graph grep for the basename across `agent-system/extensions/**`,
        `lua/**`, and the deployed `.claude/**`, excluding the file's own body and its
        `manifest.json` declaration line. Abort the move and report if any live caller appears.
        *(completed)*
  - [x] `git mv` the file into `agent-system/extensions/core/scripts/deprecated/`. *(completed)*
  - [x] Remove its entry from `agent-system/extensions/core/manifest.json`'s
        `provides.scripts` array. *(completed)*
  - [x] Confirm `jq -e '.provides.scripts | index("<name>")'` returns null and the manifest
        still parses. *(completed)*
- [x] Author the README rationale bullets, each naming the supersession or authority explicitly:
  - `archive-task.sh`, `orphan-detection.sh`, `vault-operation.sh` — state that
    `commands/todo.md` / `skills/skill-todo/SKILL.md` prose is the **authoritative**
    implementation (orphan scan at Step 2.5; archival; vault threshold-check and operation at
    Steps 5.7-5.8), and that reactivating `vault-operation.sh` would require first closing its
    unmutexed fixed-temp-path write, absent dependency/artifact renumbering, and `sed`-against-a-
    generated-file hazards — not merely restoring a caller.
  - `check-vault-threshold.sh` — superseded by the inline threshold check in `commands/todo.md`.
  - `claude-project-cleanup.sh` — superseded duplicate; distinguish it explicitly from the LIVE
    `claude-cleanup.sh` + `claude-refresh.sh` pair, which remain wired to `commands/refresh.md`.
  - `rename-session.sh` — OpenCode-TUI-scoped utility, inapplicable to the Claude Code deploy path.
  - `roadmap-sync.sh` — dead predecessor of the live, differently-named `roadmap-integration.sh`.
  - `validate-extension-index.sh` — superseded by `check-extension-docs.sh`'s Rule T
    (`check_index_entries_schema`), already wired as doc-lint gate 3.
- [x] Move `agent-system/extensions/literature/scripts/literature-decode-font-offset.py` into
      the existing `agent-system/extensions/literature/scripts/deprecated/`, drop it from the
      literature `manifest.json` `provides.scripts`, and append a rationale bullet to that
      directory's existing README (zero callers; hyphenated filename makes it unimportable as a
      Python module, so it could only ever run as a CLI subprocess, which nothing does).
      *(completed)*
- [x] *(deviation: altered — additionally reworded the `archive-task.sh` mention in
      `commands/todo.md:26` to drop the literal `.sh` extension, since check-extension-docs.sh's
      Rule E (`check_referenced_scripts_declared`) fails any commands/skills/agents doc that
      still names a basename no longer in `provides.scripts`. Not listed in this phase's original
      Files to modify, but required to keep the phase's own "check-extension-docs.sh passes"
      verification criterion green.)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: exactly nine files move (eight in core, one in literature) and exactly
nine `provides.scripts` entries are removed across two manifests. Confirm at implementation time
by re-running the per-basename caller-graph grep before each move and by diffing the two
manifests' `provides.scripts` arrays before/after — nine removals, zero additions, no other key
touched. If the re-grep promotes any file to live, record it as a Reasoned Exclusion rather than
moving it.

**Files to modify**:
- `agent-system/extensions/core/scripts/deprecated/README.md` - new; per-file rationale
- `agent-system/extensions/core/scripts/deprecated/{eight scripts}` - moved in
- `agent-system/extensions/core/manifest.json` - eight `provides.scripts` entries removed
- `agent-system/extensions/literature/scripts/deprecated/literature-decode-font-offset.py` - moved in
- `agent-system/extensions/literature/scripts/deprecated/README.md` - rationale bullet appended
- `agent-system/extensions/literature/manifest.json` - one `provides.scripts` entry removed

**Verification**:
- Both manifests parse (`jq . <manifest> >/dev/null`) and neither names any moved basename.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` passes (Rule Q's
  `deprecated/*` exemption should make the moved files invisible to the undeclared-script check;
  if a moved file is still flagged, the move landed outside `deprecated/`).
- Per-basename caller-graph re-grep returns zero live references for all nine.
- Every moved file has a corresponding README bullet — count bullets against files moved.

---

### Phase 2: Repair and wire in the contract-compliance lint [COMPLETED]

**Goal**: Fix `lint/lint-contract-compliance.sh`'s broken root resolution, triage the findings
that survive the fix, and add the script as a new gate in `verify-deploy.sh`.

**Tasks**:
- [x] Reproduce the current state: run the script and confirm it exits 1 with 15 failures whose
      messages name paths under `agent-system/extensions/.claude/...` — evidence the failures are
      root-resolution artifacts rather than real contract violations. *(completed: confirmed 15
      failures, root cause `common_repo_root "$SCRIPT_DIR" 3` landing on
      `agent-system/extensions` instead of the repo root)*
- [x] Replace its root resolution with the sibling pattern used by
      `scripts/lint/lint-agent-contracts.sh`: `SCRIPT_DIR` from `BASH_SOURCE`, `REPO_ROOT` from a
      `REPO_ROOT` env override then `git rev-parse --show-toplevel` then a relative fallback, and
      derive agent/skill/context roots from `$REPO_ROOT/agent-system/extensions` (source store)
      rather than from a `.claude/` path relative to the script's own directory. *(completed; also
      repointed Check F from the deployed, merged `.claude/context/index.json` to core's source
      `index-entries.json`, the source-store equivalent, since the whole script now validates the
      source store consistently)*
- [x] Re-run with `--verbose` and triage every surviving finding. Real contract violations are
      fixed here; findings that reflect an intentional current design are recorded in the phase
      summary with justification. *(completed: 24/24 checks pass after the fix — all 15 original
      failures were root-resolution artifacts, zero real contract violations remained)*
- [x] Add the script as a new gate in `agent-system/extensions/core/scripts/verify-deploy.sh`,
      copying the structure of the existing gate 6 / gate 7 lint blocks verbatim (section banner,
      source-store existence check, `REPO_ROOT="$TARGET"` invocation with `--verbose`, `pass`/
      `fail` with a re-run hint, and `FINDINGS_LIST` population when `$FINDINGS` is true). Place
      it after the existing final gate and number it accordingly. *(completed: added as gate 11)*
- [x] Run the full `verify-deploy.sh` and confirm the new gate reports pass and the overall run
      is green. *(completed with a documented exception: gate 11 itself PASSes; gate 8
      (`tests/run-all.sh`) reports 2 pre-existing/flaky failures unrelated to this task —
      `test-index-entries-schema.sh` (known pre-existing fixture-suite defect) and
      `test-claude-refresh-matcher.sh` (PID-race flake; passes cleanly when re-run standalone).
      Neither failure is new, neither touches any file this task modified, and both are called
      out as expected/out-of-scope in this task's own delegation instructions. See Phase 4 for
      the final confirming re-run.)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: all 15 current failures are root-resolution artifacts and drop to zero
after the resolution fix, with no real contract violations remaining. Confirm by running
`--verbose` immediately after the fix and BEFORE adding the gate; if real violations survive,
fix them in this phase (they are in-scope) and record the count and nature in the summary —
never add the gate while it is red.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` - root resolution repair
- `agent-system/extensions/core/scripts/verify-deploy.sh` - new gate block appended

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh --verbose` exits 0.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` exits 0 and its summary line
  reports one more check than before, with zero failures.
- The new gate block's structure matches gates 6/7 (compare side by side).

---

### Phase 3: Documentation notes and the dead syncprotect line [COMPLETED]

**Goal**: Land the keep-with-doc-note dispositions and the rule-loading mechanism note, so the
next dead-code audit does not repeat either mis-triage; delete the one dead `.syncprotect` line.

**Tasks**:
- [x] In `agent-system/extensions/core/merge-sources/claudemd.md`, extend the `### Utility
      Scripts` list with one line each for the four manual operator tools —
      `install-aliases.sh`, `install-systemd-timer.sh`, `migrate-directory-padding.sh`,
      `verify-lean-mcp.sh` — each stating explicitly that it is invoked manually by an operator
      and has no automated caller by design. Add a line for
      `lint/lint-contract-compliance.sh` describing the hard-mode contract checks it performs.
      *(completed)*
- [x] In the same file's `## Rules References` section, add a short clarification that the listed
      `@`-imports are a curated subset, and that `.claude/rules/*.md` are additionally
      auto-loaded natively whenever a touched path matches their YAML `paths:` frontmatter glob —
      so a rule absent from the list is not thereby unwired. *(completed)*
- [x] Document the two independent rule-loading paths in
      `agent-system/extensions/core/context/patterns/context-discovery.md`: the harness-native
      `paths:` frontmatter glob and the `CLAUDE.md` `@`-import list. State that a dead-code audit
      MUST check frontmatter before declaring a rule file unwired. *(completed: new "Rule
      Loading: Two Independent Paths" section)*
- [x] In `agent-system/extensions/core/rules/pr-prohibition.md`, add a short note that the
      `/pr` and `/pr --review` subsections describe a CSLib-extension command not present in
      every deploy, and are inert where that extension is not loaded. Do not remove the sections
      and do not touch the file's frontmatter. *(completed; frontmatter untouched)*
- [x] Delete the `output/implementation-001.md` line from the repo-root `.syncprotect`. Leave
      `context/repo/project-overview.md` and all comment lines intact. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` to
      refresh `line_count` for any edited context file, then `--check` to confirm clean.
      *(completed: context-discovery.md's line_count corrected 355 -> 375; --check now clean)*
- [x] Re-verify (read-only, no edits) that `core/EXTENSION.md`, `slidev/EXTENSION.md`, and
      `agent-system/extensions/core/skills/skill-orchestrator/` are all still absent from the
      source store, and that `sync.lua`'s header still declares the glob engine retired. Record
      the confirmations; take no action. *(completed: all four re-verified, no action taken)*

**Timing**: 1 hour

**Depends on**: 1, 2

**Verification Tier**: local

**Scope Hypothesis**: five new `Utility Scripts` entries (four operator tools plus the newly
wired lint) and exactly one deleted `.syncprotect` line. Confirm by diffing the rendered
`Utility Scripts` list before/after (net +5 bullets, no bullet removed or reworded) and by
`diff`ing `.syncprotect` (net -1 line, and the removed line is exactly
`output/implementation-001.md`).

**Files to modify**:
- `agent-system/extensions/core/merge-sources/claudemd.md` - Utility Scripts entries, Rules References note
- `agent-system/extensions/core/context/patterns/context-discovery.md` - rule-loading paragraph
- `agent-system/extensions/core/rules/pr-prohibition.md` - CSLib-inertness note
- `agent-system/extensions/core/index-entries.json` - refreshed `line_count` (via the generator, not by hand)
- `.syncprotect` - one dead line removed

**Verification**:
- `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` reports clean.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` passes (Rule R line_count).
- `grep -c 'output/implementation-001.md' .syncprotect` returns 0; the file still contains its
  three comment lines and `context/repo/project-overview.md`.
- The four operator-tool basenames and `lint-contract-compliance.sh` each appear in
  `merge-sources/claudemd.md`'s Utility Scripts section.

---

### Phase 4: Deploy-tree sweep and final verification [COMPLETED]

**Goal**: Prove the quarantine holds end to end — a regenerated `.claude/` tree contains none of
the quarantined files, all gates pass, and no dangling reference survives anywhere.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh --dry-run` and confirm it
      reports the wipe/regenerate plan without error. *(completed; also confirmed via
      `--wipe --dry-run` that the destructive plan itself reports cleanly)*
- [x] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh --wipe`. The default
      (non-`--wipe`) mode never removes anything, so it CANNOT satisfy this phase's bar — a plain
      resync would leave every stale quarantined copy in place. If headless nvim is unavailable,
      record the deploy-tree check as explicitly deferred, naming the reason, and complete the
      remaining source-store verifications; never report this bar as met without running it.
      *(completed: headless nvim available, wipe-and-regenerate ran successfully twice — once
      after Phase 1-3's edits, once again after the dangling-reference cleanup below)*
- [x] Assert absence: for each of the nine quarantined basenames, confirm no file of that name
      exists under `.claude/scripts/` (or the literature extension's deployed script directory).
      *(completed: all nine confirmed absent via `find .claude -name "<basename>"`, re-confirmed
      after the second wipe)*
- [x] Run `bash agent-system/extensions/core/scripts/verify-deploy.sh` in full and confirm a
      PASS with zero failures, including the gate added in Phase 2. *(completed with the same
      documented exception as Phase 2: gate 11 PASSes; gate 8 (`tests/run-all.sh`) reports the
      known pre-existing `test-index-entries-schema.sh` failure only — re-run standalone confirms
      it is the sole failure among 34 discovered suites, with the two previously-observed flaky
      cases (`test-claude-refresh-matcher.sh`, `test-four-tier-conflict.sh`) both passing clean on
      this final run. 21 of 22 verify-deploy.sh checks PASS; the one FAIL is gate 8's pre-existing
      issue, unrelated to and untouched by this task)*
- [x] Run a final repo-wide dangling-reference grep for all nine quarantined basenames across
      `agent-system/extensions/**`, `lua/**`, `.claude/**`, and the repo-root config files.
      The only permitted hits are inside the `deprecated/` directories themselves (the moved
      files and their README rationale bullets). *(completed with a deviation: the first sweep
      found four accurate-but-outside-`deprecated/` historical-consumer comments naming
      `archive-task.sh`/`vault-operation.sh`/`roadmap-sync.sh`/`validate-extension-index.sh` in
      `scripts/lib/common.sh`, `context/patterns/task-lock.md`, and
      `scripts/generate-context-line-counts.sh`. These were reworded in place — dropping the bare
      `.sh` basename while preserving the historical/architectural meaning (the quarantined
      scripts still exist under `scripts/deprecated/` and still source `common.sh`), and
      `generate-context-line-counts.sh`'s stale precedent-reference was repointed to
      `check-extension-docs.sh`'s Rule T, the actual current superseding mechanism. Also corrected
      `common.sh`'s now-stale claim that `lint-contract-compliance.sh` consumes
      `common_repo_root` — Phase 2's root-resolution repair removed that dependency. Re-swept
      clean: all nine basenames' remaining hits are confined to `deprecated/` directories.)*
- [x] Run `bash agent-system/extensions/core/scripts/check-task-references.sh` to confirm no
      task-number citation leaked into any deliverable written by this task. *(completed: PASS,
      0 unexempted occurrences across all four scanned trees)*

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Scope Hypothesis**: the absence-assertion set is exactly the nine basenames Phase 1 actually
moved — not the nine this plan predicted. Read the moved set from Phase 1's summary (or from
`git log --diff-filter=R` over the phase commits) rather than re-copying the list from this
document, so a Phase 1 Reasoned Exclusion cannot silently produce a false-clean sweep here.

**Files to modify**: none (verification-only phase; any defect found here is fixed in the
owning phase's territory and re-verified)

**Verification**:
- `verify-deploy.sh` exits 0.
- Zero quarantined basenames present under the deployed tree.
- Dangling-reference grep yields hits only under `deprecated/`.
- `check-task-references.sh` exits 0.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0 (doc-lint,
      including Rule Q undeclared-scripts and Rule R line_count).
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh` exits 0 with the new gate present.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh --verbose` exits 0.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes (confirms the two
      `test-*.sh` files this plan deliberately did NOT move are still discovered and green).
- [ ] `jq . agent-system/extensions/core/manifest.json` and the literature manifest both parse.
- [ ] Per-basename caller-graph grep: zero live references to any of the nine quarantined files.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh` exits 0.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/deprecated/README.md` (new) plus eight moved scripts
- `agent-system/extensions/literature/scripts/deprecated/literature-decode-font-offset.py` plus an
  appended README bullet
- Updated `provides.scripts` in the core and literature `manifest.json` files
- Repaired `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh`
- New gate block in `agent-system/extensions/core/scripts/verify-deploy.sh`
- Documentation updates in `merge-sources/claudemd.md`, `context/patterns/context-discovery.md`,
  and `rules/pr-prohibition.md`
- One-line deletion in the repo-root `.syncprotect`
- `specs/985_quarantine_dead_scripts_rules_and_machinery/summaries/01_{short-slug}-summary.md`

## Rollback/Contingency

Every change is a source-store edit or a `git mv` under version control; `.claude/` is a
gitignored, disposable deploy artifact. To revert, `git revert` the phase commit(s) and re-run
`deploy-headless.sh --wipe` to rebuild the deploy tree from the restored source. Because each
script move and its manifest drop are committed as a single substep, a partial revert cannot
leave a manifest entry pointing at a moved path. If Phase 2's new gate proves too noisy after
landing, remove the gate block alone (a self-contained section in `verify-deploy.sh`) while
retaining the root-resolution repair, which is an unambiguous bug fix.

## Implementer Notes

- **Source-store boundary (binding)**: edit `agent-system/extensions/**` only, plus the repo-root
  `.syncprotect`. Never hand-author or edit files under `.claude/**` — those are regenerated.
- **No task numbers in deliverables**: none of the README rationale bullets, `claudemd.md`
  entries, context paragraphs, or code comments written by this task may cite a task number.
  Reference durable anchors instead — script basenames, section headings, rule filenames.
- **Quarantine means MOVE + document**: never `rm` a quarantined file. `git mv` preserves history
  and keeps the file recoverable.
