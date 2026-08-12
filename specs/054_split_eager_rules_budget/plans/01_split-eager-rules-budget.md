# Implementation Plan: Task #54

- **Task**: 54 - split_eager_rules_budget
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None (territory disjoint from LEVER 1 / LEVER 3 siblings; parallel-safe)
- **Research Inputs**: specs/054_split_eager_rules_budget/reports/01_split-eager-rules-budget.md
- **Artifacts**: plans/01_split-eager-rules-budget.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Reduce the session-start eager context prefix (measured live at 80,808 B / ~20.2k tokens) by
splitting four oversized `rules/**` files into short eager cores plus lazily-loaded companions
under `context/standards/`, and by cutting the largest verified-redundant chunk out of the
literature extension's CLAUDE.md merge source. Every edit targets the source store at
`agent-system/extensions/**`; the deployed `.claude/**` tree is written only by the single
redeploy in the final phase. Definition of done: a measured before/after byte table for every
file touched, no pre-action constraint lost from any rule, and an explicit eager budget ceiling
recorded so the next regression is detectable.

### Research Integration

The plan is built directly on the research report's byte-measured findings, all of which were
independently re-confirmed at planning time against the live tree:

- **Eager prefix accounting reproduced exactly**: parent chain 3,815 B (`~/.config/CLAUDE.md`
  769 + `~/.config/nvim/CLAUDE.md` 3,046) + generated `.claude/CLAUDE.md` 46,475 B + the six
  rules that demonstrably loaded (30,518 B) = **80,808 B**.
- **Source store is byte-identical to the deployed tree today**, so per-phase measurement may be
  taken against `agent-system/extensions/**` and confirmed once at redeploy.
- **Per-file split boundaries** (which sections are pre-action-binding vs. movable narrative) are
  taken from the report's four measured tables rather than re-derived.
- **Literature duplication verified, not assumed**: the two `Literature Mode (--lit)` headings in
  the generated file are a heading collision (a 338 B core stub + the literature extension's real
  10,747 B section), NOT duplicate bytes. The real cut is one subsection inside the second
  occurrence — `### Interactive Sub-Index Setup Detection`, 5,255 B — whose contract already
  exists canonically and lazily at `context/patterns/lit-stage4a-flow.md`, which the six
  literature-aware skills import directly and never via CLAUDE.md.
- **Audited-but-not-targeted**: `artifact-formats.md` and core's `merge-sources/claudemd.md`
  contain no comparable verified-redundant chunk; the report recommends leaving both alone.

Two additional constraints were established at planning time and are NOT in the research report:

- `check-extension-docs.sh` **Rule S** fails on any deployed `context/**/*.md` with no entry in
  the deployed `context/index.json`. Every new companion file therefore requires an
  `index-entries.json` entry in its owning extension, with a `line_count` matching `wc -l`
  (**Rule R**) and a schema-conforming field set (**Rule T**).
- The `cslib` extension's `manifest.json` already declares `provides.context: ["project/cslib"]`,
  so the relocated `/pr` content lands in an already-wired directory; only the index entry is new.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists and was consulted read-only. No roadmap item names this work directly;
the nearest adjacency is Phase 1's **Agent System Quality** cluster (lint/standard enforcement for
the agent system's own files). This task adds a governance ceiling that a future roadmap lint item
could enforce, but no roadmap item is completed by it. No `roadmap_flag` was passed, so no
roadmap-review/roadmap-update phases are included and ROADMAP.md is not modified.

## Goals & Non-Goals

**Goals**:
- Cut the six-rule eager class from 30,518 B toward the ~18,900 B the research projects, with
  every byte change measured, never asserted.
- Cut the generated `.claude/CLAUDE.md` from 46,475 B by removing the verified-redundant
  literature subsection (~4,650-4,850 B expected).
- Preserve every pre-action constraint: forbidden-operation lists, write-gating prohibitions, and
  terminal-state restrictions stay eager by construction.
- Relocate (not delete) the CSLib-only `/pr` content into the `cslib` extension, where it is live.
- Record an explicit, numeric eager budget ceiling in an existing governance home.
- Record the measurement-harness correction in the summary without touching that task's territory.

**Non-Goals**:
- Building or modifying a measurement script. The eager-context measurement harness is a separate
  task's territory; this plan uses inline `wc -c` accounting only and hands over a correction.
- Touching `artifact-formats.md` or core's `merge-sources/claudemd.md` beyond the one-line stub
  fix in Phase 6 (both audited and deliberately left alone).
- Touching the `/orchestrate` skills or command bodies (LEVER 1 / LEVER 3 sibling territory).
- Modifying `specs/ROADMAP.md`.
- Any edit under `.claude/**` by hand. That tree is written only by `deploy-headless.sh`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A moved section is the named authoritative home of a cross-reference elsewhere (e.g. `plan-format.md` names `rules/git-workflow.md`'s `### Commit-Per-Green-Substep Mandate` as "the authoritative home of this mode's rules") | H | H | Every split phase runs a reference sweep BEFORE cutting (`grep -rn "<rulename>.md" agent-system/extensions/`) and again after. Keep the referenced HEADING in the eager core with the binding statement plus a pointer; move only elaboration. Repoint any cross-reference that named a now-moved paragraph. |
| A pre-action constraint is silently lost in a trim | H | M | Each phase enumerates its KEEP list explicitly before editing, and Phase 7 runs a dedicated pre-action audit re-reading each trimmed rule against the report's classification tables. Any forbidden-operations list, write-gating prohibition, or terminal-state restriction that cannot be found in the new eager core is a phase failure, not a cleanup item. |
| New companion files fail doc-lint Rule S after deploy (deployed context file with no index entry) | M | H | Each phase that creates a context file adds its own `index-entries.json` entry in the same phase, with `line_count` from `wc -l`, then runs `generate-context-line-counts.sh --check` and `check-extension-docs.sh`. |
| Relocating CSLib content breaks CSLib deploys | M | L | `cslib/manifest.json` already declares `provides.context: ["project/cslib"]` (verified at planning time), so the destination directory is already wired. Add the index entry and run `check-extension-docs.sh`, which lints all extensions including unloaded ones. |
| Parallel phases collide on `agent-system/extensions/core/index-entries.json` | M | M | Encoded in the dependency waves: Phases 2 -> 3 -> 4 are serialized precisely because all three append to that one file. Phases 5 and 6 touch a different extension's index / no index at all and are wave-parallel with Phase 2. |
| Redeploy surfaces unrelated drift between source store and deployed tree | M | M | Phase 1 records `git status --porcelain` and a source-vs-deployed byte comparison as the baseline; Phase 7 diffs the post-deploy `.claude/` tree and attributes every change to a named phase. Unattributable drift is reported, not absorbed. |
| Over-cutting `git-workflow.md`'s No-Destructive-Git narrative removes the basis for choosing between snapshot modes | M | M | The forbidden-operations list and the "snapshot first via `git-snapshot.sh`" instruction stay eager in full; only the mode-by-mode `--branch` / `--no-revert` prose moves, and it stays one Read away. |
| Achieved total exceeds the recommended <=20,000 B ceiling | L | M | Phase 7 states the ceiling only AFTER re-measuring. If the achieved eager-class total exceeds 20,000 B, either take the optional `artifact-formats.md` Example-Flow trim (~700 B) or state the ceiling at the achieved value plus stated headroom, recording the reasoning in-file. Never state a ceiling the tree already violates. |
| In-file "why eager" comments add bytes to the very files being slimmed | L | H | Each comment is budgeted (~300 B) and counted in that phase's after-measurement, so the net figure is honest. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 5, 6 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 7 | 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel.

**Territory contract** (file ownership, so wave-2 parallelism is safe):

| Phase | Owns |
|-------|------|
| 2 | `core/rules/git-workflow.md`, `core/context/standards/git-workflow-narrative.md` (new), `core/index-entries.json`, any core file cross-referencing git-workflow sections |
| 3 | `core/rules/error-handling.md`, `core/context/standards/error-recovery-strategies.md` (new), `core/index-entries.json` |
| 4 | `core/rules/state-management.md`, `core/context/reference/state-management-schema.md` (or a new companion), `core/index-entries.json` |
| 5 | `core/rules/pr-prohibition.md`, `cslib/context/project/cslib/**` (new file), `cslib/index-entries.json` |
| 6 | `literature/merge-sources/claudemd.md`, `core/merge-sources/claudemd.md` (stub heading only) |
| 7 | `core/context/architecture/context-layers.md`, `core/rules/no-task-references-in-deliverables.md`, deploy + measurement |

**Binding rules for every phase**:
- Edit `agent-system/extensions/**` only. Never hand-author under `.claude/**`.
- Do not write task-number references into any file outside `specs/**`.
- Write the companion/destination file FIRST, then trim the source file, so each sub-step is green.

---

### Phase 1: Baseline Capture and Measurement Protocol [COMPLETED]

**Goal**: Freeze a reproducible, byte-exact baseline that every later phase measures against, and
fix the measurement command so "before/after" is one accounting method, not several.

**Tasks**:
- [x] Record `git status --porcelain` and current HEAD sha into the baseline record. *(completed)*
- [x] Measure and record the parent chain: `wc -c ~/.config/CLAUDE.md ~/.config/nvim/CLAUDE.md`
      (expected 769 + 3,046 = 3,815). *(completed: matched exactly)*
- [x] Measure and record `wc -c .claude/CLAUDE.md` (expected 46,475). *(completed: matched exactly)*
- [x] Measure and record the six eager rules in the deployed tree: `git-workflow.md`,
      `artifact-formats.md`, `state-management.md`, `pr-prohibition.md`,
      `source-store-deploy-boundary.md`, `no-task-references-in-deliverables.md`
      (expected 30,518 total). *(completed: matched exactly)*
- [x] Record the whole-prefix figure with the canonical single command so later runs are
      comparable: `cat <parent chain> .claude/CLAUDE.md <six rules> | wc -c` (expected 80,808). *(completed: matched exactly)*
- [x] Measure and record ALL ten source-store rule files (`wc -c agent-system/extensions/core/rules/*.md`)
      and both merge sources (`wc -c agent-system/extensions/*/merge-sources/claudemd.md`). *(completed)*
- [x] Confirm source store equals deployed for each of the six rules (`cmp` or matching byte
      counts); record any file where it does not, since that file's later measurement needs care. *(completed: all six MATCH)*
- [x] Write all of the above to `specs/054_split_eager_rules_budget/baseline-bytes.md` as the
      single reference table later phases append their after-figures to. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: The baseline figures asserted above (3,815 / 46,475 / 30,518 / 80,808) were
measured at planning time and are expected to reproduce exactly. Confirm by re-running the
commands; if any differs, record the discrepancy and its cause (an intervening commit, an
unrelated edit) in the baseline record before proceeding — do not silently adopt a new number.

**Files to modify**:
- `specs/054_split_eager_rules_budget/baseline-bytes.md` - new; the reference table for all
  later before/after accounting

**Verification**:
- `baseline-bytes.md` exists, is non-empty, and contains a per-file byte figure for all ten source
  rules, both merge sources, the parent chain, and the generated CLAUDE.md.
- The whole-prefix `cat | wc -c` figure is recorded and matches the sum of its named parts.
- No file under `agent-system/**` or `.claude/**` was modified in this phase.

---

### Phase 2: Split git-workflow.md (11,147 B, largest eager contributor) [COMPLETED]

**Goal**: Reduce `git-workflow.md` to a pre-action core carrying every commit-format and
forbidden-operation constraint, moving the elaborative narrative to a lazily-loaded companion,
without breaking any cross-reference that names a moved section.

**Tasks**:
- [x] Sweep references first: `grep -rn "git-workflow" agent-system/extensions/ --include=*.md --include=*.sh --include=*.json`
      and record every file that names a git-workflow section by heading. `plan-format.md` is
      known to name `### Commit-Per-Green-Substep Mandate` as the authoritative home of the
      `Commit Mode` field's rules; there may be others. *(completed: plan-format.md,
      general-implementation-agent.md, skill-implementer/SKILL.md, and recovery.md name headings
      that both survive the trim)*
- [x] Create `agent-system/extensions/core/context/standards/git-workflow-narrative.md` and move
      into it, verbatim: the Commit-Per-Green-Substep Mandate elaboration (the sub-step
      granularity / green-means-verified / atomic-batch / staging-reuse bullets beyond the core
      mandate sentence), the No-Destructive-Git exemption and snapshot-mode narrative
      (`--branch` / `--no-revert` mode-by-mode prose), the Session ID Lifecycle description,
      Branch Strategy, and the Error Handling (on commit / pre-commit hook failure) section. *(completed)*
- [x] KEEP eager in `git-workflow.md`, in full and unmodified: the Commit Conventions tables
      (task-scoped format + Standard Actions + System Operations), the "Do Not Commit" and
      "Create Commits After" lists, the `### Commit-Per-Green-Substep Mandate` HEADING with its
      one-paragraph binding statement plus a pointer to the companion, the "Never Run" list, the
      "Forbidden on a dirty tree" list, the "Not blocked" list, "Always Check Before Commit", and
      the Commit Message Format + Session ID format/generation block. *(completed: confirmed by grep)*
- [x] Delete the Commit Scope examples subsection: `context/standards/git-staging-scope.md` is
      already the pointed-to authoritative source and the pointer already exists in-file. Verify
      the pointer survives the deletion. *(completed: pointer sentence retained)*
- [x] Trim the trailing Examples block to a single example (the Standard Actions table already
      carries the format). *(completed: kept the single task-ref-ok-marked canonical example)*
- [x] Repoint every cross-reference found in the sweep that named a moved paragraph, so it now
      names either the retained heading or the companion file. Do not leave a reference pointing
      at prose that no longer exists. *(completed: no repointing needed — every referenced heading
      survived in the eager core)*
- [x] Add the `git-workflow-narrative.md` entry to `agent-system/extensions/core/index-entries.json`
      with `domain: "core"`, `subdomain: "standards"`, a one-line summary, `line_count` from
      `wc -l`, keywords, topics, and a `load_when` block naming the implementation agents that
      consume git guidance. *(completed)*
- [x] Measure and append to `baseline-bytes.md`: before/after bytes for `git-workflow.md` and the
      byte size of the new companion. *(completed: 11,147 -> 7,000 B, -37.2%; companion 5,082 B)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: The research projects a new eager core of ~4,200 B (-62%) with ~6,300 B
moved. Both are hypotheses. Confirm by measuring the actual `wc -c` of the trimmed file and the
companion, and record the real figures. If the achieved core exceeds ~5,000 B, state which
sections were retained beyond the KEEP list and why, rather than trimming a KEEP-listed
pre-action constraint to hit the number.

**Files to modify**:
- `agent-system/extensions/core/rules/git-workflow.md` - trim to pre-action core plus pointers
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` - new companion
- `agent-system/extensions/core/index-entries.json` - add the companion's entry
- Any core file surfaced by the reference sweep that names a moved section

**Verification**:
- Every item on the KEEP list above is present in the trimmed file, located by grep, and quoted in
  the phase report.
- `grep -rn "git-workflow" agent-system/extensions/` produces no reference to a heading or
  paragraph that no longer exists.
- `bash .claude/scripts/generate-context-line-counts.sh --check` reports no drift for the new entry.
- `bash .claude/scripts/check-extension-docs.sh` exits 0.
- Before/after bytes recorded in `baseline-bytes.md`.

---

### Phase 3: Split error-handling.md (5,420 B, latent `.claude/**/*` trigger) [COMPLETED]

**Goal**: Move the entirely reactive recovery-strategy content out of the eager surface while
keeping the taxonomy and the short response pattern that an agent may need before acting.

**Tasks**:
- [x] Sweep references: `grep -rn "error-handling" agent-system/extensions/ --include=*.md`.
      Agent contracts are known to say "See `rules/error-handling.md` for general error patterns";
      confirm none of them depend on a section being moved. *(completed: all references name the
      file generically or a heading that survived; none named a moved paragraph)*
- [x] Create `agent-system/extensions/core/context/standards/error-recovery-strategies.md` and
      move into it, verbatim: the whole Recovery Strategies section (Timeout, State Sync, Build
      Error, jq Parse Failure, MCP Abort Error, Delegation Interrupted) and the detailed
      `errors-append.sh` invocation plus field specification from "Log the Error". *(completed)*
- [x] KEEP eager in `error-handling.md`: the Error Categories taxonomy, a ~200 B "log via
      `errors-append.sh`" one-liner plus pointers to `context/schemas/errors-schema.json` and
      `context/formats/errors-format.md`, the Preserve Progress / Enable Resume / Report Clearly
      bullets, the Severity Levels table, the Non-Blocking Errors list, and a pointer to the new
      companion. *(completed: confirmed by grep)*
- [x] Verify the build-error recovery step's "never discard uncommitted changes" language survives
      somewhere eager or is explicitly re-anchored: it is a write-gating constraint even though it
      sits inside a reactive section. If it moves, leave the prohibition itself in the eager core.
      *(completed: re-anchored as a standalone `## Write-Gating Constraint` eager section)*
- [x] Add the companion's `index-entries.json` entry (`subdomain: "standards"`, accurate
      `line_count`, schema-conforming fields). *(completed)*
- [x] Measure and append before/after bytes to `baseline-bytes.md`. *(completed: 5,420 -> 2,987 B,
      -44.9%; companion 4,435 B)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: The research projects a new eager core of ~2,150 B (-60%) with ~3,270 B
moved. Confirm by measurement and record the actual figures. Note this file was NOT in the
measured eager six (its `.claude/**/*` glob did not match that session's touched paths), so its
saving is regression-prevention rather than an immediate reduction in the 30,518 B figure — report
it in a separate line of the accounting, not folded into the six-rule total.

**Files to modify**:
- `agent-system/extensions/core/rules/error-handling.md` - trim to taxonomy plus pointers
- `agent-system/extensions/core/context/standards/error-recovery-strategies.md` - new companion
- `agent-system/extensions/core/index-entries.json` - add the companion's entry

**Verification**:
- The "never discard uncommitted changes to reach a passing build" constraint is locatable by grep
  in an eager file after the split.
- `check-extension-docs.sh` and `generate-context-line-counts.sh --check` both clean.
- Before/after bytes recorded.

---

### Phase 4: Split state-management.md (5,148 B) [COMPLETED]

**Goal**: Move the enforcement-mechanism and error-handling narrative out while keeping every
write-gating prohibition and terminal-state restriction eager.

**Tasks**:
- [x] Read `agent-system/extensions/core/context/reference/state-management-schema.md` FIRST and
      decide whether the moved narrative belongs there (preferred, avoids a third home) or in a
      new `context/standards/` companion. Record the decision and its reason. *(completed: chose
      the existing schema doc — see baseline-bytes.md Phase 4 note for the reason)*
- [x] Move: the "Enforcement mechanism" and "Known limitation" paragraphs under Artifacts Are
      Append-Only, the explanatory prose around the State-First Update Pattern (keeping the two
      bash one-liners), and the Error Handling (On Write Failure / On Inconsistency Detection)
      section. *(completed)*
- [x] KEEP eager in full: "Never edit TODO.md directly", the Canonical Sources block, the
      Artifacts Are Append-Only core prohibition including "Wholesale `.artifacts = [...]`
      assignment is prohibited" and the `+=` / sanctioned-helper instruction, the Status
      Transitions restrictions bullets (cannot transition from terminal states; cannot mark
      COMPLETED without all phases done), the `update-task-status.sh` / `generate-todo.sh`
      one-liners, and the File Scope / Schema Reference pointers. *(completed: confirmed by grep)*
- [x] If the ASCII transition diagram is dropped for bytes, keep the bulleted restrictions
      verbatim. Never drop both. *(completed: diagram was NOT dropped — not needed to hit target)*
- [x] Add or update the `index-entries.json` entry for the destination file (new entry if a new
      companion; refresh `line_count` if content was appended to the existing schema doc).
      *(completed: refreshed line_count 472 -> 519)*
- [x] Measure and append before/after bytes to `baseline-bytes.md`. *(completed: 5,148 -> 3,850 B,
      -25.2%)*

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: The research projects ~3,450 B remaining (-33%, a deliberately smaller ratio
because more of this file is genuinely pre-action) with ~1,700 B moved. Confirm by measurement.
The destination choice (existing schema doc vs. new companion) is itself unconfirmed — resolve it
by reading the schema doc, not by assuming.

**Files to modify**:
- `agent-system/extensions/core/rules/state-management.md` - trim to prohibitions plus pointers
- `agent-system/extensions/core/context/reference/state-management-schema.md` OR a new
  `context/standards/` companion - destination for the moved narrative
- `agent-system/extensions/core/index-entries.json` - add/refresh the destination's entry

**Verification**:
- All five KEEP items above are locatable by grep in the trimmed file.
- The destination decision is recorded with its reason.
- `check-extension-docs.sh` and `generate-context-line-counts.sh --check` both clean.
- Before/after bytes recorded.

---

### Phase 5: Slim pr-prohibition.md by Relocating CSLib Content [COMPLETED]

**Goal**: Move the two CSLib-only `/pr` subsections into the `cslib` extension where they are
live, leaving core's universal prohibition rule as a small, purely prohibition-shaped file, and
record the deliberate-eager decision in-file.

**Tasks**:
- [x] Confirm the destination is wired: `jq '.provides.context' agent-system/extensions/cslib/manifest.json`
      should include `project/cslib`. Confirm before writing, do not assume. *(completed:
      confirmed `["project/cslib"]`)*
- [x] Create `agent-system/extensions/cslib/context/project/cslib/pr-command-workflow.md`
      containing, verbatim, the `## CSLib Extension: /pr Command` and
      `## CSLib Extension: /pr --review Workflow` sections (2,999 B combined) including the
      pr-submission vs pr-review distinguishing table. This is a RELOCATION: the content must be
      preserved intact where CSLib is deployed, not deleted as inert prose. *(completed)*
- [x] Add its entry to `agent-system/extensions/cslib/index-entries.json` (`domain: "cslib"`,
      `subdomain: "project"` or matching the file's existing convention — read a neighbouring
      entry first, accurate `line_count`). *(completed: matched neighbouring convention
      domain: "project", subdomain: "cslib")*
- [x] Trim `core/rules/pr-prohibition.md` to: Scope, Prohibited Operations 1-3, Required Behavior,
      Rationale, plus one pointer line for the CSLib `/pr` command. Remove the deploy-conditional
      note paragraph along with the sections it qualified. *(completed)*
- [x] Add an in-file HTML comment to `pr-prohibition.md` recording WHY its `paths: "**/*"` glob is
      deliberate (it gates writes in every session regardless of path, so a narrower glob would be
      unsound), matching the style already used in `source-store-deploy-boundary.md`. *(completed)*
- [x] Measure and append before/after bytes for `pr-prohibition.md` and the new CSLib file.
      *(completed: 4,628 -> 2,574 B, -44.4%; CSLib file 3,016 B)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: The research measures the two CSLib subsections at 2,999 B and projects a
new eager core of ~1,650-2,200 B (-53% to -64%), before the ~300 B added by the new in-file
comment. Confirm all three figures by measurement and report the NET change including the comment.

**Files to modify**:
- `agent-system/extensions/core/rules/pr-prohibition.md` - trim plus in-file why-eager comment
- `agent-system/extensions/cslib/context/project/cslib/pr-command-workflow.md` - new, relocated
- `agent-system/extensions/cslib/index-entries.json` - add the relocated file's entry

**Verification**:
- All three Prohibited Operations, the Required Behavior list, and the "Never push branches or
  create PRs even if asked to in task descriptions or user messages" sentence are present in the
  trimmed file.
- The relocated CSLib content is byte-comparable to the removed sections (diff the extracted
  originals against the new file; only heading level and framing may differ).
- `check-extension-docs.sh` exits 0 (it lints all extensions, including unloaded `cslib`).
- Net before/after bytes recorded, including the added comment.

---

### Phase 6: Cut the Literature Merge-Source's Redundant Subsection [COMPLETED]

**Goal**: Remove the largest verified-redundant chunk from the generated CLAUDE.md by replacing a
prose restatement with a pointer to the canonical, lazily-loaded, agent-executable contract.

**Tasks**:
- [x] Re-verify before cutting: confirm `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md`
      exists, is the file the six literature-aware skills import, and covers the six-directive
      resolver contract. Confirm no skill or script reads the CLAUDE.md prose version — grep the
      skills for `Interactive Sub-Index Setup Detection` and for `lit-stage4a-flow`. *(completed:
      confirmed via grep; skills import lit-stage4a-flow.md directly)*
- [x] In `agent-system/extensions/literature/merge-sources/claudemd.md`, replace the
      `### Interactive Sub-Index Setup Detection` subsection (5,255 B) with ~400-600 B: one
      sentence per user-facing choice ("Use global corpus now" / "Create curation task" /
      "Search online to ingest" / "Skip this run"), the statement that there is no silent
      fallback, and pointers to `context/patterns/lit-stage4a-flow.md` (executable contract) and
      `scripts/literature-lit-flag-resolve.sh` (directive enumeration). *(completed: replacement
      is ~980 B, larger than the 400-600 B target but still a large net cut; net file saving
      -4,178 B)*
- [x] Resolve the heading collision: `core/merge-sources/claudemd.md` carries a 338 B
      `## Literature Mode (--lit)` stub that becomes confusing noise exactly when the literature
      extension IS loaded and defines the same H2 later in the generated file. Either drop the
      stub's duplicate heading or reword it so the generated file does not present two
      identically-titled H2 sections. Verify the generated output after the change. *(completed:
      reworded to "Extension Pointer"; generated-output confirmation deferred to Phase 7's
      redeploy per this phase's own Scope Hypothesis note — this phase does not deploy)*
- [x] Leave `### orchestrator_mode Dual-Consumer / Autonomy Contract` in place. It is flagged
      optional/secondary by the research and is a maintainer-facing invariant; cutting it is not
      required to hit the ceiling. *(completed: left untouched)*
- [x] Measure and append before/after bytes for both merge sources. *(completed: literature
      12,851 -> 8,673 B, -32.5%; core 24,707 -> 24,770 B, +63 B for the heading reword)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: The research measures the subsection at 5,255 B and projects a net saving of
~4,650-4,850 B (~10% of the 46,475 B generated file). Confirm by measuring the merge source before
and after; the generated-file effect is confirmed separately at redeploy in Phase 7, since this
phase does not deploy.

**Files to modify**:
- `agent-system/extensions/literature/merge-sources/claudemd.md` - replace subsection with pointer
- `agent-system/extensions/core/merge-sources/claudemd.md` - resolve the duplicate H2 heading

**Verification**:
- The four user-facing choices and the "no silent fallback" guarantee are all still stated in the
  merge source.
- Both pointer paths resolve to files that exist.
- Grep confirms no skill or script depends on the removed prose.
- Before/after bytes recorded for both merge sources.

---

### Phase 7: Redeploy, Re-Measure, and Record the Eager Budget Ceiling [NOT STARTED]

**Goal**: Prove the eager surface actually shrank against the deployed tree using the same
accounting as the baseline, record a numeric ceiling so the next regression is detectable, and
close every acceptance criterion.

**Tasks**:
- [ ] Add the in-file "why eager" comment to
      `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` (eager by
      omission today, not by a recorded decision), matching `source-store-deploy-boundary.md`'s
      style: this rule gates writes across the entire repo, so any glob narrow enough to matter
      would have to be `"**/*"`, which buys nothing over no frontmatter.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the `.claude/` tree from source.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and `bash .claude/scripts/check-extension-docs.sh`;
      both must exit 0. Investigate and fix any failure before measuring.
- [ ] Re-measure with the Phase 1 canonical command: parent chain, generated `.claude/CLAUDE.md`,
      the six eager rules individually, and the whole-prefix `cat | wc -c`.
- [ ] Build the final before/after table covering EVERY file touched (both rules and merge
      sources, plus each new companion's size as lazily-loaded content), with absolute bytes and
      percentage change per file, plus the class totals and the whole-prefix total.
- [ ] Run the pre-action audit: for each of `git-workflow.md`, `error-handling.md`,
      `state-management.md`, `pr-prohibition.md`, re-read the trimmed file against the research
      report's classification table and confirm every row classified pre-action is present.
      Report the audit as a checklist with a locatable quote per item, not as an assertion.
- [ ] Record the eager budget ceiling in
      `agent-system/extensions/core/context/architecture/context-layers.md`, as a new bullet or
      short subsection under channel 3 ("Rules `paths:` frontmatter") — the existing home of the
      "absence of frontmatter must be a decision, not an omission" norm. State: the class being
      bounded (rules that eagerly load in a representative session — those gated on `specs/**/*`,
      `.claude/**/*`, `"**/*"`, or no frontmatter), the numeric ceiling, the measurement command,
      and the measured figure at the time of writing. Recommended ceiling is 20,000 B; state the
      ceiling only after measuring, and never state one the tree already violates.
- [ ] Diff the post-deploy `.claude/` tree and attribute every change to a named phase. Report any
      unattributable drift rather than absorbing it.
- [ ] In the implementation summary, record verbatim the correction to hand to the
      eager-context measurement-harness task: its stated model ("rules lacking `paths:` frontmatter
      or carrying `paths: "**/*"`") catches only 8,863 B of the measured 30,518 B, missing
      `git-workflow.md`, `artifact-formats.md`, and `state-management.md` (21,655 B combined,
      ~71% under-count) because those are gated on `specs/**/*` / `.claude/**/*` globs that DO
      match a real session's touched paths. The harness must glob-MATCH each rule's `paths:` value
      against a representative touched-path set (at minimum `specs/**` and `.claude/**`), not
      merely check for absent-or-universal frontmatter. Record only; make no edit to that task's
      territory.
- [ ] Note in the summary that `artifact-formats.md` and core's `merge-sources/claudemd.md` were
      audited and deliberately left untouched, with the reason, so a future reader does not read
      their absence as an oversight.

**Timing**: 1.25 hours

**Depends on**: 2, 3, 4, 5, 6

**Verification Tier**: full

**Scope Hypothesis**: The research projects the six-rule eager class dropping from 30,518 B to
~18,900 B (-38%) and the generated CLAUDE.md dropping ~4,650-4,850 B from 46,475 B, for a
whole-prefix figure near 64,000-65,000 B. These are hypotheses built from per-file estimates.
Confirm every one by measurement against the redeployed tree and report the achieved figures. A
shortfall is a finding to report with its cause, not a reason to cut a KEEP-listed constraint.

**Files to modify**:
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` - add why-eager comment
- `agent-system/extensions/core/context/architecture/context-layers.md` - record the ceiling
- `.claude/**` - regenerated by `deploy-headless.sh` only (never hand-edited)
- `specs/054_split_eager_rules_budget/baseline-bytes.md` - final before/after table

**Verification**:
- `verify-deploy.sh` exits 0.
- `check-extension-docs.sh` exits 0.
- The whole-prefix `cat | wc -c` figure is recorded and is lower than 80,808.
- Every file touched across all phases appears in the final before/after table with measured
  absolute bytes; no file is described as "slimmed" without a number.
- The pre-action audit checklist shows a locatable quote for every pre-action row in the research
  report's four classification tables.
- The ceiling statement in `context-layers.md` names a number, a class, and a measurement command,
  and the measured figure is at or below it.

---

## Testing & Validation

- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 after the redeploy.
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 (covers index Rules R/S/T for every
      new companion and the relocated CSLib file).
- [ ] `bash .claude/scripts/generate-context-line-counts.sh --check` reports no `line_count` drift.
- [ ] `bash .claude/scripts/lint/lint-agent-contracts.sh` exits 0 (agent contracts reference
      several of the trimmed rules).
- [ ] Reference sweep: `grep -rn "git-workflow\|error-handling\|state-management\|pr-prohibition" agent-system/extensions/ --include=*.md`
      surfaces no pointer to a heading or paragraph that no longer exists.
- [ ] Pre-action audit passes for all four trimmed rules, with a locatable quote per retained
      constraint.
- [ ] Whole-prefix byte figure measured against the redeployed tree and recorded.
- [ ] The relocated CSLib content is present and intact in the `cslib` extension.

## Artifacts & Outputs

- `specs/054_split_eager_rules_budget/plans/01_split-eager-rules-budget.md` (this plan)
- `specs/054_split_eager_rules_budget/baseline-bytes.md` (baseline and final before/after tables)
- `specs/054_split_eager_rules_budget/summaries/01_split-eager-rules-budget-summary.md`
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` (new)
- `agent-system/extensions/core/context/standards/error-recovery-strategies.md` (new)
- `agent-system/extensions/cslib/context/project/cslib/pr-command-workflow.md` (new, relocated)
- Trimmed: `core/rules/git-workflow.md`, `error-handling.md`, `state-management.md`,
  `pr-prohibition.md`
- Amended: `core/context/architecture/context-layers.md` (ceiling),
  `core/rules/no-task-references-in-deliverables.md` (why-eager comment),
  `literature/merge-sources/claudemd.md` and `core/merge-sources/claudemd.md`
- Updated: `core/index-entries.json`, `cslib/index-entries.json`

## Rollback/Contingency

- Every phase commits separately with a scoped message, so any single phase reverts with
  `git revert` of its commit without disturbing the others. The territory contract guarantees
  phase commits do not overlap in files except on `core/index-entries.json`, where Phases 2-4 are
  serialized precisely to keep those reverts clean.
- `.claude/**` is a disposable deploy artifact: if the redeploy produces a bad tree, revert the
  source-store commits and re-run `deploy-headless.sh` to regenerate. No `.claude/` state needs
  manual repair.
- If the pre-action audit in Phase 7 finds a lost constraint, restore that specific paragraph to
  the eager core from git history and re-measure. Restoring a constraint always outranks hitting a
  byte target.
- If `verify-deploy.sh` fails after redeploy and the cause is not quickly attributable, revert to
  the Phase 1 baseline sha, redeploy, and confirm the tree returns to 80,808 B before
  re-attempting.
