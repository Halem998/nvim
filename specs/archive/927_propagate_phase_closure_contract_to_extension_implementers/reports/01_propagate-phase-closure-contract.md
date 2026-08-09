# Research Report: Task #927

**Task**: 927 - Propagate the depth-first phase-closure and pre-edit verification contract to extension implementers
**Started**: 2026-07-27
**Completed**: 2026-07-27
**Effort**: ~1 hour
**Dependencies**: 925 (contract authored, core-only), 919 (unrelated concurrent edits to the same agent files, already merged)
**Sources/Inputs**: Codebase (`agent-system/extensions/**`, `specs/925_*`, `specs/919_*`), git log
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The prerequisite finding is independently confirmed, not just taken on faith.** Directory
  placement in `context/contracts/` is a naming convention only; the load-bearing mechanism is an
  explicit `@`-reference bullet in a consuming file's `## Context References` section, and no
  central injection point exists that would let a core contract reach extension implementers "for
  free." `skill-base.sh`'s `context_injection` hook runs extension -> core, the wrong direction.
  **Conclusion: propagation is required.** This is not a case that closes as unnecessary.
- **The referencing mechanism the task asks me to recommend already exists in-repo** — it does not
  need to be invented. Two extension files already do exactly this for other core contracts
  (`cslib-implementation-hard-agent.md` and core's own `skill-implementer{,-hard}/SKILL.md`): a
  single `@`/`Path:` bullet naming the core file's deployed path
  (`.claude/context/contracts/phase-closure.md`), never a prose copy. Propagation should reuse
  this identical pattern for both new contracts across all thirteen extensions — one bullet per
  contract per file, pointing at the single core source.
- **The actual surface is fourteen agent files and, in two extensions, their hard-mode skill
  files** — not a uniform "thirteen extensions, one file each." Enumerated below per extension;
  several extensions have both a standard and a hard-mode implementer (cslib, lean), one extension
  (`cslib`) has a third implementer file (`pr-review-implementation-agent.md`) that is a poor fit
  for phase-closure specifically (it has zero phase-loop structure), and one extension (`email`)
  has a single-stage implementer with no `### Phase N [STATUS]` loop at all, making phase-closure
  inapplicable there in its current form.
- **No conflict with the sibling `.return-meta.json` status-vocabulary effort** — it is a
  completed, already-committed task (`919 phase 1` through `919 phase 5`, `bdb2d2265`) that added
  `## Context References` sections (or bullets into existing ones) to fifteen agent files,
  including six of the files this task will also touch (`cslib-implementation-agent.md`,
  `latex-implementation-agent.md`, `python-implementation-agent.md`,
  `typst-implementation-agent.md`, `z3-implementation-agent.md`,
  `pr-review-implementation-agent.md`). The practical interaction is sequencing only: for those
  six files the `## Context References` section already exists (created by that task) and this
  task's two new bullets should be *added into* it, not create a second section.

## Context & Scope

Task 925 authored two new, mode-agnostic contracts in the source store —
`agent-system/extensions/core/context/contracts/phase-closure.md` (depth-first phase closure:
close-before-open, cheapest-closure-first, stop-at-a-closed-boundary) and
`.../contracts/pre-edit-gate.md` (per-item evidence before applying an item from a
mechanically-generated list, landing failures in the plan's `Reasoned Exclusions` table) — and
wired both into all four **core** implementer files only
(`general-implementation-agent.md`, `general-implementation-hard-agent.md`,
`skill-implementer/SKILL.md`, `skill-implementer-hard/SKILL.md`). It explicitly deferred extension
propagation and recorded a placement/injection finding in `context-layers.md` for this task to
build on.

This task's scope was to (1) independently verify that finding, (2) if propagation is genuinely
required, enumerate the real file surface across all non-core extensions, and (3) recommend a
referencing mechanism that avoids a thirteen-file copy-paste liability. Per the delegation
context, no edits were made in this research pass — only investigation and reporting.

## Findings

### Independent verification of task 925's finding (confirmed)

Read directly from `agent-system/extensions/core/context/architecture/context-layers.md`'s
"Contracts directory: convention vs. load path" subsection and cross-checked against the actual
files it cites:

- **Finding (i) — placement is not a load mechanism.** Confirmed by inspection: every
  pre-925 occupant of `context/contracts/` (`anti-analysis.md`, `wrap-up.md`, `territory.md`,
  etc.) is loaded only via explicit `@`-reference bullets in specific agents' and skills'
  `## Context References` sections — never by virtue of living in the directory. `phase-closure.md`
  and `pre-edit-gate.md` themselves each open with a "Loaded via explicit reference in BOTH modes"
  section stating this plainly and listing their four core referrers.
- **Finding (ii) — no central injection point.** Confirmed: `general-implementation-agent.md` is
  the only implementer that runs the adaptive `context-discovery.md` index query (`jq` over
  `index.json`/`index-entries.json` by `load_when` criteria); no extension implementer runs it.
  `scripts/skill-base.sh`'s `context_injection` lifecycle stage runs `skill_run_extension_hook
  "context_injection"`, which lets an *extension* inject content into a *core* skill's dispatch
  prompt — the reverse of what would be needed for a core contract to reach extension
  implementers automatically. No shared dispatch-prompt builder exists; every `SKILL.md` and every
  agent file constructs its own prompt and its own Context References section inline.

No mechanism was found that the prior task missed. **This task's scope is real: propagation is
required, and it is genuinely manual, per-file work.**

### The referencing mechanism: already established, not invented here

The task asked me to "research and recommend the concrete referencing mechanism," with an explicit
steer to prefer a pointer over copied prose. This mechanism is not new — the codebase already uses
it in two places for other core contracts, giving a directly reusable template:

1. `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`'s
   `## Context References` section carries:
   `` `@.claude/context/contracts/anti-analysis.md` - H2 anti-analysis contract (MANDATORY) ``,
   plus equivalent bullets for `wrap-up.md` and `territory.md` — single-line pointers to the
   deployed core path, no prose duplication.
2. Core's own `skill-implementer/SKILL.md` and `skill-implementer-hard/SKILL.md` (added by task
   925 itself) carry:
   `` - Path: `.claude/context/contracts/phase-closure.md` - depth-first phase closure: close one
   phase before opening the next (loaded by agent) `` and the equivalent `pre-edit-gate.md` line.

**Recommendation**: propagate both new contracts to every extension implementer using this exact
pattern — one `@`/`Path:` bullet per contract, in each file's `## Context References` section (or
whatever the file's existing equivalent-heading convention is), pointing at
`.claude/context/contracts/phase-closure.md` and `.claude/context/contracts/pre-edit-gate.md` (the
deployed path core's own referrers already use — the source-store files themselves are literal
copies of what gets deployed, so the `@`-reference text is written against the deploy-time path
even though the edit lands in `agent-system/extensions/**`). This keeps the two contracts as
single-source files: a future revision touches two files in `core/`, not two-plus-thirteen. No new
indirection layer, alias file, or shared-include mechanism needs to be invented — the existing
convention already solves the "don't repeat prose across files" problem the task is worried about;
what it does not yet solve is "reach every extension," which is exactly the gap this task closes.

**Where the bullet must land differs by which agent actually loop over phases.** Two of the
existing precedents (`cslib-implementation-hard-agent.md`'s three bullets,
`skill-implementer{,-hard}/SKILL.md`'s two bullets) are the load-bearing copy for the *agent* and a
"discoverability" duplicate for the *skill* respectively — `phase-closure.md`'s own header says so
explicitly ("the skills delegate loading to their respective agents"). Most extension skill files
(see below) are thin wrappers with no `## Context References`-equivalent section of their own, so
for those the agent file is the only place the bullet needs to go; only where a skill file already
carries its own contract-bullet list (cslib's hard skill) should a matching discoverability bullet
be added there too.

### Actual propagation surface (enumerated, not assumed)

Twelve non-core extensions have an implementer. Two (cslib, lean) have both a standard and a
hard-mode implementer. cslib additionally has a third implementation-flavored agent
(`pr-review-implementation-agent.md`) that is a response composer, not a plan-phase executor.

| Extension | Implementer agent(s) | Phase-loop present? | Hard-mode pair? | Own Skill Context-References list? |
|---|---|---|---|---|
| cslib | `cslib-implementation-agent.md` | yes (`Phase Checkpoint Protocol`, "For each phase...") | yes: `cslib-implementation-hard-agent.md` (same shape) | hard skill only (`skill-cslib-implementation-hard/SKILL.md`) |
| cslib (pr-review) | `pr-review-implementation-agent.md` | **no** — zero "phase" occurrences, single-stage "Implement Code Changes" | no | no |
| lean | `lean-implementation-agent.md` | yes (identical `Phase Checkpoint Protocol` structure) | yes: `lean-implementation-hard-agent.md` | no (hard skill narrates the contracts prose-only, no `Path:` bullet list) |
| email | `email-implementation-agent.md` | **no** — single-stage "Execute Steps via Wrapper Binaries Only", no `### Phase N [STATUS]` loop | no | no |
| epidemiology | `epi-implement-agent.md` | yes | no | no |
| founder | `founder-implement-agent.md` | yes | no | no |
| latex | `latex-implementation-agent.md` | yes | no | no |
| nix | `nix-implementation-agent.md` | yes | no | no |
| nvim | `neovim-implementation-agent.md` | yes | no | no |
| python | `python-implementation-agent.md` | yes | no | no |
| typst | `typst-implementation-agent.md` | yes | no | no |
| web | `web-implementation-agent.md` | yes | no | no |
| z3 | `z3-implementation-agent.md` | yes | no | no |

Every extension's implementer skill (`skill-{ext}-implementation/SKILL.md`) is a thin dispatcher
(`## Trigger Conditions` / `## Execution Flow` / `## Postflight` / `## Return Format`) with no
`## Context References`-equivalent section at all, except the two already noted
(`skill-cslib-implementation-hard/SKILL.md`, which does carry an explicit `Path:` bullet list, and
core's own two, out of scope here). So the primary edit target is **the agent file** in each
extension; skill-file edits are only warranted where a skill already maintains its own bullet
list, which today means `skill-cslib-implementation-hard/SKILL.md` alone.

**Scope judgment calls worth flagging explicitly** (not resolved by this research pass — for the
implementation plan to decide):
- `pr-review-implementation-agent.md` has no phase concept to close depth-first over;
  `phase-closure.md` would be a non-sequitur there. `pre-edit-gate.md`'s per-item evidence
  principle is more plausibly relevant (verifying a reviewer's requested change against the code
  before applying it) but the file's single-stage "Implement Code Changes" step isn't built around
  a mechanically-generated candidate list the way a plan's file list or a grep result set is —
  applying the gate here would be an analogy, not a direct fit.
- `email-implementation-agent.md` similarly has no `[NOT STARTED]/[IN PROGRESS]/[COMPLETED]`
  phase-heading loop for `phase-closure.md` to govern — it executes plan "Steps" in a single
  pass. `pre-edit-gate.md`'s spirit already exists there under a different name (the
  propose-review-confirm-execute manifest gate is arguably a stricter, domain-specific superset),
  so adding a generic reference risks presenting two overlapping gates rather than one.
- The other eleven agent files (cslib main, lean main, epi, founder, latex, nix, nvim, python,
  typst, web, z3) all have the same `### Phase N [STATUS]` / "Phase Checkpoint Protocol" /
  "For each phase..." shape that motivated `phase-closure.md` in core, confirmed by direct grep
  rather than assumed from the extension name — these are the clean, low-risk propagation targets
  for both contracts.

### Interaction with the sibling `.return-meta.json` status-vocabulary task

That task (state.json project 919, `task 919: complete orchestration`, commit `bdb2d2265`) is
**already completed and merged** — `git status --short` on all touched files is clean. It added an
`@`-reference to `context/formats/return-metadata-file.md` (the status-enum source) to fifteen
agent files that lacked one, six of which overlap this task's surface:
`cslib-implementation-agent.md`, `latex-implementation-agent.md`, `python-implementation-agent.md`,
`typst-implementation-agent.md`, `z3-implementation-agent.md`, and
`pr-review-implementation-agent.md`. For those six, that task *created* the `## Context References`
section (it did not exist before); this task's contract bullets should be added into that
already-existing section, not stand up a second, duplicate section. For the other implementer
files in this task's surface (`email`, `epidemiology`, `founder`, `nix`, `nvim`, `web`, and
`lean`'s non-hard agent), a `## Context References` section already predates both tasks and needs
no structural change, only new bullets. There is no content conflict — the two tasks touch
disjoint bullets within the same sections — but a future implementer of this task should re-grep
each target file's current `## Context References` count immediately before editing (this is
itself an instance of the pre-edit-gate principle this task is about to propagate) rather than
assume the pre-919 state described in task 925's own scope notes.

## Decisions

- Concluded propagation is genuinely required (not "already handled") based on independent
  re-derivation of task 925's finding, not on trusting its summary at face value.
- Recommend the referencing mechanism already used twice in-repo (`@`/`Path:` bullet to the
  deployed core path) rather than any new indirection layer — this satisfies "prefer a
  referencing mechanism over copied prose" with zero new machinery.
- Recommend excluding `email-implementation-agent.md` and
  `pr-review-implementation-agent.md` from `phase-closure.md` propagation (no phase-loop
  structure to govern), and treating `pre-edit-gate.md` for those two as an optional,
  lower-confidence addition rather than a mandatory one — left for the planning stage to decide
  explicitly rather than silently including or excluding them.

## Risks & Mitigations

- **Risk**: an implementer copies prose instead of a pointer bullet, recreating the exact
  maintenance defect this task exists to avoid. **Mitigation**: the plan should state the bullet
  text verbatim (matching the two existing precedents) rather than leaving wording to the
  implementer's discretion.
- **Risk**: colliding with task 919's already-landed `## Context References` sections in the six
  overlapping files, e.g. creating a duplicate section header. **Mitigation**: documented above;
  the implementation plan's per-file pre-edit probe should grep each target's current section
  count before editing, per the very pre-edit-gate contract being propagated.
- **Risk**: over-applying `phase-closure.md` to the two agents that have no phase-loop
  (`email`, `pr-review`), producing a contract reference with nothing for it to govern.
  **Mitigation**: flagged explicitly above as a planning-stage decision, not silently resolved
  either way by this research pass.

## Context Extension Recommendations

None — the relevant convention (`context-layers.md`'s "Contracts directory" subsection) already
documents the mechanism this task relies on; no new context file is needed to record this
research's findings beyond this report and the implementation plan it feeds.

## Appendix

- Read: `agent-system/extensions/core/context/architecture/context-layers.md`,
  `agent-system/extensions/core/context/contracts/phase-closure.md`,
  `agent-system/extensions/core/context/contracts/pre-edit-gate.md`,
  `specs/925_depth_first_phase_closure_and_pre_edit_gate/summaries/01_depth-first-closure-pre-edit-gate-summary.md`,
  `specs/919_reference_normative_status_vocabulary_in_agents/summaries/01_reference-normative-status-vocab-summary.md`.
- Searches: `grep`/`find` across all `agent-system/extensions/*/agents/*implement*.md` and
  `*/skills/*implement*/SKILL.md` for `## Context References`, `phase`, `for each phase`,
  `contracts/`; `git log --oneline` and `git status --short` on the task-919 overlap set.
