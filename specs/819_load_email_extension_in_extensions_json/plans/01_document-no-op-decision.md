# Implementation Plan: Task #819

- **Task**: 819 - Add the email extension to .claude/extensions.json so it is actually loaded
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_intent-and-mechanics.md
- **Artifacts**: plans/01_document-no-op-decision.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 819 asked to load the `email` extension into this repo's (`~/.config/nvim`)
`.claude/extensions.json`, but only if the extension is intended to run here. Research
(`reports/01_intent-and-mechanics.md`) resolved the gating question to a decisive **NO**: this
repo is the AUTHORING source for the email extension; its intended CONSUMER is `~/.dotfiles`,
which already loads it live (its `extensions.json` has `email` active with a cross-repo
`source_dir` pointing back here, and its `CLAUDE.md` already carries the propagated Email
Extension section). This repo has zero `email`-typed tasks. The doc-lint line
"skill-email-implementation not deployed" is `check-extension-docs.sh`'s documented, non-failing
`WARN` for an authored-but-uninstalled extension; `[email]` still reports overall `PASS`.

Therefore the correct implementation is a **minimal documented no-op**: make no edits to
`extensions.json`, `CLAUDE.md`, or settings; record the decision and rationale in a task summary
and completion_summary; and verify the baseline is unchanged. Definition of done: a summary
artifact exists capturing the finding, and verification confirms `extensions.json` is byte-for-byte
unchanged and `check-extension-docs.sh [email]` still reports `PASS` with the same expected WARN.

### Research Integration

The plan fully adopts the research report's Recommendation 1 (do not edit `extensions.json`) and
Recommendation 2 (no-op that documents the decision). The completion_summary text is derived
directly from the report's Executive Summary and Decisions sections. The plan does NOT pursue the
report's optional Recommendation 3 (adding a scope-note line to the email README) to keep the
no-op strictly zero-config-change; that optional polish is noted as out of scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided and no ROADMAP.md was loaded for this task. No roadmap alignment
recorded.

## Goals & Non-Goals

**Goals**:
- Durably record the decision that the email extension is intentionally NOT loaded in this repo,
  with its cross-repo rationale, so future reviewers do not re-flag the WARN as an actionable gap.
- Produce a task summary artifact and a completion_summary suitable for `[COMPLETED]` closure.
- Verify the no-op: confirm `extensions.json` is unchanged and the `[email]` doc-lint baseline is
  unchanged (`PASS` with the expected single WARN).

**Non-Goals**:
- Editing `.claude/extensions.json` (no `email` entry added).
- Editing `.claude/CLAUDE.md`, `.claude/settings.local.json`, or `.claude/context/index.json`.
- Running `install-extension.sh` or the extension picker for `email` in this repo.
- Fixing the `check-extension-docs.sh [email]` WARN (it is by-design, not a defect).
- Addressing the `.dotfiles`-side stale-manifest keyword drift (cross-repo, out of scope).
- Adding the optional scope-note line to `.claude/extensions/email/README.md` (out of scope to
  keep this a strict zero-config-change no-op).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer misreads intent and edits `extensions.json` | H | L | Plan and completion_summary state NO edits explicitly; Phase 2 verifies `extensions.json` is unchanged and fails closure if it changed. |
| Future reviewer re-flags the same doc-lint WARN as a gap | M | M | Summary + completion_summary make the cross-repo decision durably discoverable in-repo. |
| Verification misinterprets the expected `[email]` WARN as a regression | L | L | Phase 2 explicitly asserts the baseline is `PASS` WITH the single expected WARN, not zero WARN. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Record the No-Op Decision [COMPLETED]

- **Goal:** Write a task summary artifact capturing the finding, rationale, and explicit no-change
  outcome, and stage the completion_summary text for closure.
- **Tasks:**
  - [x] Create `specs/819_load_email_extension_in_extensions_json/summaries/01_document-no-op-decision-summary.md`. *(completed)*
  - [x] In the summary, state the decision (intent = NO; do not add `email` to this repo's
    `extensions.json`) and the rationale: this repo authors the email extension; `~/.dotfiles` is
    the live consumer (its `extensions.json` `email` entry has `source_dir`
    `/home/benjamin/.config/nvim/.claude/extensions/email`, and its `CLAUDE.md` already carries the
    merged Email Extension section); zero `email`-typed tasks exist here. *(completed)*
  - [x] In the summary, explain that the `skill-email-implementation not deployed` line is
    `check-extension-docs.sh`'s documented non-failing `WARN` for an authored-but-uninstalled
    extension, and that `[email]` reports overall `PASS`. *(completed)*
  - [x] In the summary, list files changed: none (config unchanged); reference the research report. *(completed)*
  - [x] Draft the completion_summary string for state.json (used at closure): "Investigated per
    task 819 gating condition; decision = do NOT load the email extension into this repo's
    .claude/extensions.json. The extension is authored here (.claude/extensions/email/) but is
    already loaded and live in its intended consumer, ~/.dotfiles (cross-repo source_dir confirmed;
    .dotfiles CLAUDE.md already carries the merged Email Extension section). This repo has zero
    email-typed tasks. The 'skill-email-implementation not deployed' doc-lint line is
    check-extension-docs.sh's documented non-failing WARN for an authored-but-uninstalled
    extension; [email] reports overall PASS. No config files changed (extensions.json, CLAUDE.md,
    settings.local.json all unmodified)." *(completed)*
- **Timing:** ~20 minutes
- **Depends on:** none
- **Files to modify:**
  - `specs/819_load_email_extension_in_extensions_json/summaries/01_document-no-op-decision-summary.md` (create)
- **Verification:**
  - The summary artifact exists and states intent = NO, the cross-repo rationale, the WARN
    explanation, and "no config files changed".

### Phase 2: Verify the No-Op Baseline [NOT STARTED]

- **Goal:** Confirm that no configuration changed and the `[email]` doc-lint baseline is intact.
- **Tasks:**
  - [ ] Run `git status --porcelain .claude/extensions.json .claude/CLAUDE.md .claude/settings.local.json .claude/context/index.json`
    and confirm none of these files are modified by task 819 (empty output for these paths, or only
    pre-existing unrelated changes — none introduced by this task).
  - [ ] Run `bash .claude/scripts/check-extension-docs.sh` and confirm the `[email]` section
    reports overall `PASS` with exactly the single expected line
    `WARN: routing target not deployed (extension not installed): skill-email-implementation`
    (baseline unchanged; the WARN is expected, not a regression).
  - [ ] Confirm `.claude/extensions.json` still contains exactly the four extension entries
    (`core`, `nix`, `memory`, `nvim`) and no `email` key.
- **Timing:** ~10 minutes
- **Depends on:** 1
- **Files to modify:** none (read-only verification)
- **Verification:**
  - `git status` shows no task-819-introduced modifications to the four config files.
  - `check-extension-docs.sh` shows `[email] ... PASS` with the single expected WARN.
  - `extensions.json` has no `email` key.

## Testing & Validation

- [ ] `.claude/extensions.json` is unchanged and has no `email` key (four entries: core, nix, memory, nvim).
- [ ] `.claude/CLAUDE.md`, `.claude/settings.local.json`, and `.claude/context/index.json` are unmodified by this task.
- [ ] `bash .claude/scripts/check-extension-docs.sh` reports `[email] ... PASS` with the single expected `WARN` line (baseline unchanged).
- [ ] The summary artifact exists and records the decision, rationale, and no-change outcome.

## Artifacts & Outputs

- `specs/819_load_email_extension_in_extensions_json/plans/01_document-no-op-decision.md` (this plan)
- `specs/819_load_email_extension_in_extensions_json/summaries/01_document-no-op-decision-summary.md` (created in Phase 1)
- completion_summary string for state.json (staged in Phase 1, applied at closure)

## Rollback/Contingency

No production/config changes are made, so there is nothing to roll back. If the summary artifact
needs revision, edit it in place. If a future decision reverses this (i.e., the email extension IS
to be loaded here), that is a separate task: follow the mechanics recorded in the research report's
"Decisions" section (add an `email` key to `extensions.json` shaped like the `nix`/`memory` entries
and run the install path), and re-run `check-extension-docs.sh` expecting `[email] OK` with no WARN.
