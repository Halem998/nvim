# Research Report: Task #881

**Task**: 881 - make_four_agents_emit_modified_files
**Started**: 2026-07-15
**Completed**: 2026-07-15
**Effort**: medium (1 shared context fragment + 4 targeted agent edits)
**Dependencies**: `modified_files`/`files_touched` schema (landed; see Sources)
**Sources/Inputs**:
- `agent-system/extensions/core/context/formats/return-metadata-file.md` (`modified_files` field spec)
- `agent-system/extensions/core/context/formats/progress-file.md` (`files_touched` field spec)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` (staging contract)
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` (Stage 9 staging consumer)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (working reference)
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (target 1)
- `agent-system/extensions/email/agents/email-implementation-agent.md` (target 2)
- `agent-system/extensions/nvim/agents/neovim-implementation-agent.md` (target 3)
- `agent-system/extensions/nix/agents/nix-implementation-agent.md` (target 4)
- `agent-system/extensions/{email,nvim,nix,core}/manifest.json`
- `agent-system/extensions/core/context/guides/extension-development.md` (`copy_context_dirs()` merge semantics)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Confirmed**: only `general-implementation-agent.md` implements the full `modified_files`
  emission chain. All four target agents are missing it, but the gap is *not uniform in kind* —
  it splits into two distinct bugs, not one, which matters for how the plan should fix them.
- **A core-owned shared context fragment IS a viable carrier and is not hypothetical** — it is
  the existing, already-working pattern. `return-metadata-file.md`, `summary-format.md`, and
  `git-staging-scope.md` are all core-owned files that email/nvim/nix agents already
  `@`-reference successfully today, because the extension loader's `copy_context_dirs()` merges
  every extension's `provides.context` into one flat `.claude/context/` tree — dependency
  declarations (`"dependencies": ["core"]`, present on all three) control load *order*, not
  path namespacing. A new file under `agent-system/extensions/core/context/standards/` or
  `.../patterns/` will be reachable via `@.claude/context/standards/{name}.md` from any
  extension's agent, with zero extension-specific plumbing required. Recommend extending
  `git-staging-scope.md` (already the "canonical authority" per its own header) rather than
  creating a second, competing fragment.
- **Two distinct failure modes**, not one:
  1. **general-implementation-hard-agent** already references `progress-file.md` and already
     tells the agent to update the progress file "same pattern as base agent" — but its Stage 7
     never mentions `modified_files` at all, and there is no "sum `files_touched` into
     `modified_files`" step anywhere in the file. This is a *completion* gap: the plumbing
     exists, the last step is missing.
  2. **neovim-implementation-agent** and **nix-implementation-agent** have *no progress-file
     machinery whatsoever* — no Stage 3.5, no `files_touched` tracking, no objectives array.
     Their Stage 6 "What Changed" is free-text prose in a human-readable summary, and their
     Stage 7 metadata example has no `modified_files` key. This is a *structural* gap: the
     tracking mechanism itself needs to be added, not just the final summing step.
  3. **email-implementation-agent** has neither progress-file machinery nor a
     `modified_files`/Stage-6 step, but its typical operation (wrapper-only mailbox mutation
     via `email-census`/`email-classify`/`email-archive-confirmed`/etc.) legitimately touches
     **no repo-tracked source files** in the common case — it writes only under
     `specs/{task}/` (summary + `.return-meta.json`), which the fixed `task_dir` scope already
     stages unconditionally. `modified_files: []` for a typical email task run is *correct*
     schema behavior, not a bug, per `return-metadata-file.md`'s "Empty behavior... never
     omit the field." The described failure mode (real edits silently dropped) only manifests
     for the rarer case where an email-typed task plan asks the agent to edit a repo-tracked
     file (e.g. `context/project/email/email-preferences.md`, `hooks/mail-guard.sh`). The fix
     is still required — for correctness and for that rarer case — but severity/likelihood
     differs materially from the other three agents and the plan should say so rather than
     imply email tasks are silently losing work at the same rate.
- **No fully static/textual proxy for the acceptance test exists.** These are LLM prompt files;
  there is no compiler or unit-test harness that can confirm an agent will *behaviorally* honor
  new prose. At least one live dispatch per agent is required to satisfy "behavioral, not
  textual." The available cost reduction is dispatching each agent against a **minimal
  synthetic one-phase plan** (a throwaway scratch task that edits a single trivial file) rather
  than a full production task lifecycle — this is 4 small dispatches, not 4 full
  research→plan→implement cycles. See Verification section below for the concrete recipe.

## Context & Scope

Task 881 requires making four implementation agents emit a non-empty, repo-relative
`modified_files: string[]` in `.return-meta.json` so `orchestrator-postflight.sh`'s Stage 9
targeted-staging path (`git add` over `modified_files` entries) actually picks up their source
edits, instead of falling back to the fixed `task_dir`-only scope and printing the "staged 0
files" warning. The dependency schema (`modified_files` in `return-metadata-file.md`,
`files_touched` in `progress-file.md`) is settled and must be conformed to, not reinvented. The
CONSTRAINT is no new scripts; the DELIVERABLE RULE is no task-number references in files outside
`specs/**`.

## Findings

### Codebase Patterns

**The reference chain, precisely** (from `general-implementation-agent.md`):
1. Stage 3.5 creates a per-phase progress file (`specs/{NNN}_{SLUG}/progress/phase-{P}-progress.json`)
   with an `objectives[]` array, each with `status` and (added lazily) `files_touched`.
2. Stage 4B step 2 instructs: "Track the path: append the repo-relative path of every file
   `Write`/`Edit`-ed to the current objective's `files_touched` list."
3. Stage 4B step 4 instructs updating the progress file after each objective, appending (never
   overwriting) to `files_touched`.
4. **Stage 6-modified-files** (a dedicated numbered stage, distinct from Stage 6 "Create
   Implementation Summary" and Stage 7 "Write Metadata File"): reads every phase's progress
   file, flattens+dedupes every `objectives[].files_touched` array across all phases, and holds
   the result for Stage 7.
5. Stage 7 explicitly instructs: "Include `modified_files` (from Stage 6-modified-files) at the
   top level of the JSON output."
6. The Phase Checkpoint Protocol's per-phase git commit (step 5) *also* reads the current
   objective's `files_touched` via `jq` and stages it directly — so the same tracked data feeds
   both the final `modified_files` emission and the routine per-objective green commits.

**general-implementation-hard-agent.md** (target 1 — completion gap):
- Context References already lists `@.claude/context/formats/progress-file.md`.
- Stage 3.5 says "Same as base agent. Create progress file..."
- Stage 4 step B says "following the same pattern as base agent" (ambiguous — does this
  silently inherit `files_touched` tracking, or does an agent reading only the hard-agent file
  fail to see the explicit tracking instruction that lives in the base agent's own prose?).
- **The gap**: there is no "Stage X-modified-files" summing step anywhere in the file, and
  Stage 7 ("Write to `specs/{NNN}_{SLUG}/.return-meta.json` with status
  `implemented|partial|failed`. Include `phases_completed`, `phases_total`. Include
  `memory_candidates` array.") never mentions `modified_files`. Given this agent is
  reached-for specifically on "complex, deflection-prone" work (per its own Overview), this is
  the highest-stakes of the four gaps per the task description's framing.

**neovim-implementation-agent.md** and **nix-implementation-agent.md** (targets 2 & 3 —
structural gap, near-identical shape in both):
- Neither references `progress-file.md` at all in Context References.
- Neither has a Stage 3.5 progress-file-init step.
- Stage 4B step 2 ("Create or modify files") has no "track the path" instruction.
- Stage 6 "What Changed" is unstructured markdown prose in the human-readable summary
  (`- nvim/lua/plugins/newplugin.lua — Created plugin spec`), not a machine-readable list.
- The Stage 7 metadata JSON example in both files has no `modified_files` key at all.
- These two agents *do* routinely Write/Edit real, non-`specs/` repo source files
  (`nvim/lua/**/*.lua` for neovim tasks; `flake.nix`, `modules/*.nix`, `home.nix` for nix
  tasks) as their entire purpose — this is exactly the "source changes silently never
  committed" failure the task description names.

**email-implementation-agent.md** (target 4 — narrower/rarer gap):
- References `@.claude/context/formats/return-metadata-file.md` ("always load") but not
  `progress-file.md`.
- Its Execution Flow (Stage 3 "Execute Steps via Wrapper Binaries Only") is fundamentally
  different from the other three: it invokes exactly five allowlisted nix-built wrapper
  binaries (`email-census`, `email-classify`, `email-archive-confirmed`,
  `email-delete-confirmed`, `email-unsubscribe-extract`) against a *live external mailbox*
  (IMAP/maildir), never `Write`/`Edit` on arbitrary repo files as its normal operating mode.
  `email-preference-harvest.sh` (a separate script in `provides.scripts`) is invoked by
  `skill-email-cleanup`'s Stage 7 (the ad-hoc `/email` triage command), **not** by
  `email-implementation-agent`/`skill-email-implementation` (the `/implement N` production
  path for `email`-typed tasks) — confirmed by grepping both skill files; no evidence the
  implementation agent itself writes `context/project/email/email-preferences.md`.
- Stage 5 ("Write Summary and Metadata") says only "Write the implementation summary and
  `.return-meta.json` per the standard formats referenced above" — no mention of
  `modified_files` either way.
- **Conclusion**: for the common case (a plan whose steps are entirely
  propose→review→confirm→execute mailbox operations), `modified_files: []` is the *correct*,
  schema-conformant emission — not a bug. The task description's blanket claim that all four
  agents have "real source edits ... silently never committed" is not equally true here; it
  is true only for the subset of email-typed task plans that also touch a repo-tracked file
  (e.g. editing `email-preferences.md` or `mail-guard.sh` as part of a task). The fix (add the
  same tracking discipline) should still be applied for correctness and for that subset, but
  the plan/verification should not budget for it the same way as the other three, and should
  not expect a typical email-task test run to produce a *non-empty* `modified_files` unless the
  synthetic test plan specifically includes a repo-file edit step.

### Shared Fragment Feasibility (settled, not assumed)

Verified via `agent-system/extensions/core/context/guides/extension-development.md` and by
inspecting the deployed `.claude/` tree directly (byte-identical to source, confirming the copy
mechanism, not a symlink-at-file-level mechanism for context):

- `email`, `nvim`, and `nix` extensions all declare `"dependencies": ["core"]` in their
  `manifest.json`. Per the auto-load section of `extension-development.md`, "The loader resolves
  and auto-loads dependencies before the dependent extension" — this only orders *when* core
  loads relative to the dependent, it does not gate whether core's context paths are visible.
- `copy_context_dirs()` (in `loader.lua`) copies each extension's `provides.context` entries
  into `.claude/context/{relative-path}` — a single flat merge target shared by every loaded
  extension, regardless of which extension authored a given subtree. Core's manifest lists
  `formats`, `patterns`, `standards`, `contracts`, etc. directly in `provides.context`, so they
  land at `.claude/context/formats/`, `.claude/context/patterns/`, `.claude/context/standards/`,
  etc. — the *same* paths every extension's agents already `@`-reference.
- **Empirical confirmation, not inference**: `email-implementation-agent.md`,
  `neovim-implementation-agent.md`, and `nix-implementation-agent.md` **already**
  `@`-reference `@.claude/context/formats/return-metadata-file.md` and
  `@.claude/context/formats/summary-format.md` today — both core-owned files. Since this
  cross-extension reference pattern is already live and working (not proposed), adding a new
  core-owned fragment (e.g., extending `agent-system/extensions/core/context/standards/git-staging-scope.md`,
  which its own header already calls "the canonical authority referenced by
  `orchestrator-postflight.sh`, `skill-implementer`, `general-implementation-agent`,
  `git-workflow.md`, and `skill-git-workflow`") and `@`-referencing it from all five
  implementation agents carries zero additional risk beyond what already works.
- **Recommendation**: do not create a second, competing fragment file. Extend
  `git-staging-scope.md` with a copy-pasteable "How Agents Populate `modified_files`" procedure
  section (the concrete Stage-numbered steps: track-on-write, progress-file `files_touched`
  accumulation, dedup-and-sum step, Stage 7 field inclusion), and have all five agents
  (including the reference agent, for single-source-of-truth discipline going forward) point
  their Stage 6/7 prose at that one section instead of re-deriving it. This directly answers
  the task's framing question: yes, a shared `@`-referenced fragment is the better carrier, and
  it is the existing pattern already proven live rather than a new mechanism to validate.

### External Resources

Not applicable — this is a pure meta/agent-system task; no external documentation consulted.

### Recommendations

1. **Extend `agent-system/extensions/core/context/standards/git-staging-scope.md`** with a
   named, directly-followable procedure section covering: (a) inline tracking on every
   `Write`/`Edit` call, (b) the progress-file `files_touched` accumulation mechanism (for
   agents that use progress files), (c) the flatten-dedupe-sum step, (d) the exact
   `modified_files` field shape to emit at Stage 7. This becomes the single source every agent
   points to.
2. **general-implementation-hard-agent.md**: smallest fix of the four. Add an explicit
   "sum `files_touched` into `modified_files`" step before Stage 7 (mirroring the base agent's
   Stage 6-modified-files, by `@`-reference to the extended `git-staging-scope.md` rather than
   re-copied prose), and add `modified_files` to the Stage 7 field list. No structural change
   needed — the progress-file plumbing already exists.
3. **neovim-implementation-agent.md** and **nix-implementation-agent.md**: structural fix.
   Add a Stage 3.5 progress-file-init step (mirroring the base agent, `@`-referencing
   `progress-file.md`), add the "track the path" instruction to Stage 4B step 2, add a
   pre-Stage-7 summing step (`@`-referencing the extended `git-staging-scope.md`), and add
   `modified_files` to the Stage 7 JSON example in both files. This is the highest-value fix of
   the four since these two agents' entire job is editing non-`specs/` repo files.
4. **email-implementation-agent.md**: add the same tracking discipline for correctness and for
   the rare repo-file-touching case, but do not over-invest in progress-file/objectives
   machinery this agent doesn't otherwise use — a lighter-weight "if you `Write`/`Edit` any
   repo-tracked file during a step, append its repo-relative path to `modified_files`; if none,
   emit `[]`" instruction at Stage 5, `@`-referencing the same shared fragment, is proportionate
   to how rarely this agent touches repo files at all.
5. Do **not** add a new script for any of this (per CONSTRAINT) — all four fixes are pure
   prose/`@`-reference edits to existing `.md` files plus one extension to an existing `.md`
   context file. `progress-file.md`-based tracking is itself just JSON written via the `Write`
   tool by the agent (as the base agent already does) — no script involved.
6. Author all new prose without task-number citations (per DELIVERABLE RULE) — reference
   `git-staging-scope.md`'s section name / `return-metadata-file.md`'s `modified_files` field
   name as the durable anchor, never "task 881."

## Decisions

- Treat this as two fix classes, not one uniform copy-paste: (hard-agent = completion gap,
  small patch) vs. (neovim/nix = structural gap, needs progress-file scaffolding) vs. (email =
  narrow/rare gap, lighter-weight instruction proportionate to actual repo-file-touch
  frequency). A plan that applies identical prose to all four will over-fit two of them and
  under-fit two of them.
- Recommend extending the existing `git-staging-scope.md` standard as the shared fragment
  rather than creating a new file, since it already self-identifies as the canonical authority
  and is already cross-extension-referenced in spirit (its own text already narrates the
  contract two of the four target agents are missing).
- Do not attempt to make the shared-fragment feasibility question a research risk in the plan —
  it is settled here with direct evidence (existing successful cross-extension references to
  core-owned `formats/*.md` files), not a design unknown the plan needs to re-investigate.

## Risks & Mitigations

- **Risk**: Retrofitting full progress-file/objectives machinery onto neovim/nix agents could
  be over-engineered relative to their simpler single-pass phase loops. **Mitigation**: the
  plan can scope this down to just enough progress-file structure to carry `files_touched`
  (objectives array can be a flat 1-entry-per-phase list if the agent's plans are typically
  small), without importing the base agent's full handoff/continuation apparatus wholesale.
- **Risk**: Verifying "behaviorally, not textually" requires real agent dispatches, which cost
  real tokens/time across 4 agents. **Mitigation**: see Verification section — minimal
  synthetic single-phase plans, not full task lifecycles, bound the cost.
- **Risk**: email-implementation-agent's fix might get "verified" against a synthetic plan that
  doesn't resemble any real email task (since real email tasks rarely touch repo files),
  producing a false sense of coverage. **Mitigation**: the plan's verification step for email
  should explicitly construct a synthetic plan phase that *does* edit a repo-tracked file (e.g.
  a throwaway file under `specs/881_.../scratch/`), specifically to exercise the emission path,
  and should document that this is a synthetic exercise of the mechanism, not a realistic email
  workflow.

## Verification Question: Cheaper Faithful Proxy?

**Direct answer: no fully static/textual proxy exists that satisfies "behavioral, not
textual."** These four files are LLM prompt instructions, not executable code — there is no
compiler, type-checker, or unit-test harness that can confirm an LLM will actually follow new
prose at dispatch time. Any claim of "verified" based solely on grepping for the string
`modified_files` in the edited `.md` files would be exactly the "prose was added" failure mode
the task explicitly warns against.

**What honestly reduces cost without weakening the test:**

1. **Minimal synthetic dispatch, not a full task lifecycle.** Rather than running each agent
   through a complete `/task` → `/research` → `/plan` → `/implement` cycle (expensive: real
   research + real plan generation + real multi-phase execution), construct a tiny scratch task
   directory with a hand-written one-phase, one-step plan that touches exactly one trivial file
   (e.g., for neovim: a one-line comment edit to a throwaway `.lua` file; for nix: a one-line
   comment edit to a throwaway `.nix` file; for email: a one-line edit to a throwaway file under
   `context/project/email/`, since real email plans don't touch repo files — see above; for
   general-implementation-hard-agent: a one-line edit to a throwaway `.md` file with
   `phase_number` set so it does a true single-phase dispatch). Invoke the target agent directly
   via the `Agent` tool (bypassing the full skill wrapper) with a synthetic delegation context.
   This is still a genuine behavioral exercise of the prompt (an LLM actually executes the
   Stage-by-stage instructions), just against the smallest plan that can possibly trigger the
   `Write`/`Edit` → `files_touched` → `modified_files` chain. Four small dispatches, not four
   full production runs.
2. **Inspect the emission, not just its presence.** After each dispatch: `jq '.modified_files'`
   on the resulting `.return-meta.json` must show the exact repo-relative path of the one file
   actually edited (not `[]`, not an absolute path, not a directory). This is the load-bearing
   check — a non-empty array with the wrong path form would pass a naive "is it non-empty" check
   while still failing `orchestrator-postflight.sh`'s `git add`.
3. **Confirm the consumer, not just the producer.** Run (or simulate) the
   `orchestrator-postflight.sh` Stage 9 staging block against the resulting metadata file and
   confirm via `git status --staged`/`git diff --staged --name-only` that the edited file is
   actually staged — this closes the loop the task explicitly demands ("a run of each agent
   must produce a non-empty `modified_files` that `orchestrator-postflight.sh` actually
   stages"), rather than stopping at "the JSON field looks right."
4. **What does NOT count as a proxy, honestly**: grepping the four agent `.md` files for the
   string `modified_files` or `files_touched`; a plan phase that describes "verify the agents
   were updated correctly" without an actual dispatch; reasoning from the reference agent's
   correctness by analogy without exercising the target agent's own prompt text. All three are
   textual, not behavioral, and the task explicitly rules them out as acceptance evidence.

There is no cheaper *substitute* for the one-dispatch-per-agent requirement — only a cheaper
*shape* of dispatch (synthetic minimal plan vs. full production task). A plan that skips live
dispatch entirely and calls the task done based on prose review would not meet the stated
acceptance bar.

## Context Extension Recommendations

- **Topic**: cross-extension context fragment reuse pattern.
- **Gap**: `extension-development.md` documents `copy_context_dirs()` mechanics but does not
  explicitly call out, as a named pattern, "core-owned `context/{formats,standards,patterns}/`
  files are safe to `@`-reference from any dependent extension's agent without additional
  wiring" — this had to be re-derived from first principles (manifest inspection + live
  `.claude/` tree inspection) for this task, and is exactly the kind of fact a future extension
  author will need again.
- **Recommendation**: add a short "Cross-Extension Context Reuse" subsection to
  `extension-development.md` (or a new short pattern file) stating this explicitly, with the
  `return-metadata-file.md`/`summary-format.md` cross-references as the worked example.

## Appendix

### Search Queries / Commands Used

- `find agent-system -iname "*general-implementation-agent*"` and siblings for the four targets
- Direct reads of `return-metadata-file.md`, `progress-file.md`, `git-staging-scope.md`,
  `orchestrator-postflight.sh` (staging block), all five agent `.md` files
- `python3 -c "json.load(...)['provides']['context']"` against `core/manifest.json`
- `stat` + `diff` on deployed `.claude/context/formats/return-metadata-file.md` vs. source, to
  confirm copy (not symlink) semantics and byte-identity
- grep of `email-preference-harvest.sh` callers to confirm it is a `skill-email-cleanup`
  concern, not `email-implementation-agent`/`skill-email-implementation`

### Files Read (for planner reference; section/field names are the durable anchors, not line
numbers — per this task's own note that prior line-number citations had already drifted stale)

- `agent-system/extensions/core/context/formats/return-metadata-file.md` — `modified_files`
  section
- `agent-system/extensions/core/context/formats/progress-file.md` — `files_touched` field spec
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — full file (extension
  target)
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — Stage 9 git-commit block
- `agent-system/extensions/core/agents/general-implementation-agent.md` — Stage 3.5, Stage 4B,
  Stage 6-modified-files, Stage 7, Phase Checkpoint Protocol
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — Context
  References, Stage 3.5, Stage 4 step B, Stage 5/7
- `agent-system/extensions/email/agents/email-implementation-agent.md` — Context References,
  Stage 5
- `agent-system/extensions/nvim/agents/neovim-implementation-agent.md` — Context References,
  Stage 4B, Stage 6, Stage 7
- `agent-system/extensions/nix/agents/nix-implementation-agent.md` — Context References,
  Stage 4 step C, Stage 6, Stage 7
- `agent-system/extensions/{email,nvim,nix,core}/manifest.json` — `dependencies`,
  `provides.context`
- `agent-system/extensions/core/context/guides/extension-development.md` — Merge Process,
  `copy_context_dirs()` Dual Behavior, Dependencies sections
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — full schema (for this
  report's own orchestrator handoff)
