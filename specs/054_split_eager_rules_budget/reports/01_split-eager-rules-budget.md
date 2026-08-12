# Research Report: Task #54

**Task**: 54 - split_eager_rules_budget
**Started**: 2026-08-12T17:01:20Z
**Completed**: 2026-08-12T17:03:30Z
**Effort**: research only (no files modified)
**Dependencies**: None (disjoint territory from LEVER 1 / LEVER 3 siblings; parallel-safe)
**Sources/Inputs**: - Codebase (`agent-system/extensions/core/rules/*.md`, `agent-system/extensions/*/merge-sources/*.md`, `agent-system/extensions/*/EXTENSION.md`, deployed `.claude/CLAUDE.md`, `agent-system/extensions/core/context/architecture/context-layers.md`, `specs/state.json`/`specs/TODO.md`)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All byte figures below were measured directly (`wc -c`, precise line-range extraction) against
  the SOURCE STORE at `agent-system/extensions/core/rules/*.md` and `agent-system/extensions/*/merge-sources/*.md`
  — never the deployed `.claude/` tree — confirming deployed bytes are byte-identical to source
  today, so no additional deploy-sync step changes the picture.
- **Work Item 1 (rules)**: precise, line-range-measured split boundaries for all four named
  rules (`git-workflow.md`, `error-handling.md`, `state-management.md`, `pr-prohibition.md`) are
  below, each classified pre-action-binding (must stay eager) vs. reference narrative (movable).
  Combined, the measured eager six drop from 30,518 B to an estimated ~18,900 B (-38%), with
  `error-handling.md` (not currently in the eager six, but sharing the `.claude/**/*` glob with
  two rules that ARE) cut proactively from 5,420 B to an estimated ~2,150 B against future
  regression.
- **Work Item 2 (generated CLAUDE.md)**: the literature-mode duplication claim is CONFIRMED but
  is NOT identical duplicate content (verified, not assumed) — see "Literature Duplication:
  Verified" below. The single largest cuttable chunk is the literature merge-source's
  `### Interactive Sub-Index Setup Detection` subsection: 5,255 B of prose that already
  duplicates the CANONICAL, agent-executable version of the same six-directive contract living
  at `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` (12,175 B, already the
  single source all six literature-aware skills reference directly). Cutting this one subsection
  to a ~500 B pointer saves ~4,750 B off the 46,475 B generated CLAUDE.md (~10% of the whole
  file) without any behavior loss, since skills never read CLAUDE.md's prose version of this
  logic — they import `lit-stage4a-flow.md` directly.
- **Budget ceiling recommendation**: state an explicit ceiling of **≤20,000 B** for the
  "measured eager six" rules class (rules gated on `specs/**/*`, `.claude/**/*`, `"**/*"`, or no
  `paths:` frontmatter), recorded in `agent-system/extensions/core/context/architecture/context-layers.md`'s
  existing "Eager vs. Lazy Loading Channels" section (channel 3) — see "Where to Record the
  Ceiling" below. This leaves ~1,100 B of headroom over the ~18,900 B projected post-cut total,
  detectable via the harness once corrected (see the harness correction, recorded verbatim below
  and NOT acted upon).
- **No pre-action constraint is lost** by any proposed cut: every forbidden-operations list,
  every write-gating prohibition, and every terminal-state/must-not-replace rule identified below
  is explicitly retained in each file's proposed eager core.

## Context & Scope

This is LEVER 2 of a three-lever context-cost initiative (LEVER 1 = the two `/orchestrate`
skills, LEVER 3 = command bodies). This subtask's territory is `rules/**` and `merge-sources/**`
in the SOURCE STORE (`agent-system/extensions/core/rules/*.md`,
`agent-system/extensions/{core,literature}/merge-sources/claudemd.md`), disjoint from its
siblings' territory, so it is safe to plan and implement independently.

Research focus, per the delegation: (1) confirm exactly which rules load eagerly and why, reading
`paths:` frontmatter from the source store; (2) classify per-file content as pre-action-binding
vs. reference narrative; (3) identify which CLAUDE.md merge sources drive the 33,624 -> 46,475 B
(+38%) growth; (4) verify — not assume — the claimed literature-section duplication.

## Findings

### Codebase Patterns: Rules Frontmatter Inventory (source store, all 10 core rules)

```
  759  workflows.md                          paths: .claude/**/*
 1130  project-overview-detection.md         paths: .claude/context/repo/project-overview.md
 1489  no-task-references-in-deliverables.md (no frontmatter -- documented decision pending, see below)
 2746  source-store-deploy-boundary.md       (no frontmatter -- documented decision, in-file comment)
 3414  plan-format-enforcement.md            paths: specs/**/plans/**
 4628  pr-prohibition.md                     paths: "**/*"          (universal)
 5148  state-management.md                   paths: specs/**/*
 5360  artifact-formats.md                   paths: specs/**/*
 5420  error-handling.md                     paths: .claude/**/*
11147  git-workflow.md                       paths: ["specs/**/*", ".claude/**/*"]
```

**Why exactly six loaded in the measured session, not more, not fewer**: the measured session's
tool calls touched `specs/**` paths (task/state files) but never touched a `.claude/**` path
directly. That explains an asymmetry that looked odd at first: `git-workflow.md` (globs on
EITHER `specs/**/*` OR `.claude/**/*`) fired because its `specs/**/*` arm matched, while
`error-handling.md` and `workflows.md` (both gated ONLY on `.claude/**/*`) did NOT fire in that
same session — not because their frontmatter differs in kind, but because no `.claude/**` path
happened to be touched by a tool call that session. `pr-prohibition.md` (`"**/*"`, matches
anything) and the two frontmatter-less files (`source-store-deploy-boundary.md`,
`no-task-references-in-deliverables.md`) are eager unconditionally. `plan-format-enforcement.md`
and `project-overview-detection.md` have narrower globs that did not match this session's touched
paths (no plan file, no project-overview.md touch) but WOULD fire in `/plan` or `/implement`
sessions.

**Consequence for scope**: `error-handling.md` and `workflows.md` are latent risk, not
theoretical — the very next session that touches ANY `.claude/**` path (extremely common: any
`/meta` task, any skill/agent edit, most `/implement` sessions) pays their full weight. Splitting
`error-handling.md` now (named explicitly in the task) is proactive, not premature.

This confirms `context-layers.md`'s existing "Stated unknown" note (channel 3: whether a
`paths:`-gated rule fires before or after the matching write reaches the tool layer) is separate
from — and does not resolve — the touched-path-glob-match question established here empirically:
touched-path-glob-MATCH is what gates eager loading in this measured case, independent of the
before/after-write timing question.

### Per-File Split Boundaries (Work Item 1)

For each file: total bytes, the section(s) that are pre-action-binding (MUST stay eager per the
binding constraint — anything gating a write, a forbidden-operations list, or a terminal-state
restriction), and the section(s) that are reference/recovery/illustrative narrative (movable to
a `context/standards/` companion, or to an EXISTING authoritative doc where one already covers
the content — several sections below already duplicate content that lives, and is pointed to,
elsewhere).

#### `git-workflow.md` — 11,147 B (largest; loaded eagerly today)

| Section (line range) | Bytes | Classification | Disposition |
|---|---|---|---|
| Commit Conventions (tables, L7-35) | ~1,900 | **Pre-action** (format needed before ANY commit) | KEEP eager |
| Do Not Commit / Create Commits After (L37-53) | ~700 | **Pre-action** (short prohibition list) | KEEP eager |
| Commit-Per-Green-Substep Mandate (L55-93) | 3,156 | Narrative — largely re-explains `checkpoint-before-overflow.md`'s green/RED distinction and already points there | MOVE: keep a 2-3 sentence summary + pointer (~300 B), move rest |
| Commit Scope examples (L95-121) | 639 | Redundant — `git-staging-scope.md` (18,824 B) is ALREADY the pointed-to authoritative source (see L97-99) | DELETE (no new companion needed; pointer already exists) |
| Git Safety: forbidden-op lists (L123-153, "Never Run" + "Forbidden on a dirty tree") | ~900 | **Pre-action, write-gating** (destructive-git prohibitions) | KEEP eager in full |
| No Destructive Git: exemption/mode narrative (L154-190, minus the forbidden list already counted above) | ~2,300 | Narrative (mode-by-mode description of `--branch`/`--no-revert`, detailed exemption prose) | MOVE to companion; core keeps a 1-2 line "snapshot first via `git-snapshot.sh`" pointer |
| Always Check Before Commit (L185-191) | ~250 | **Pre-action** (short) | KEEP eager |
| Commit Message Format + Session ID format/generation (L192-211) | ~450 | **Pre-action** (needed to write ANY commit message) | KEEP eager |
| Session ID Lifecycle description (L213-217) | ~150 | Narrative | MOVE |
| Examples block (L219-239) | 375 | Redundant with Standard Actions table | DELETE or trim to 1 example |
| Branch Strategy (L241-252) | 273 | Narrative, low pre-action value | MOVE |
| Error Handling: on commit/hook failure (L254-266) | 290 | Reactive (post-failure), not pre-action | MOVE (or fold 1-line pointer into `error-handling.md`) |

**Estimated new eager core**: ~4,200 B (-62%). **Movable to companion**
(`context/standards/git-workflow-narrative.md`, new file): ~6,300 B, largely absorbing content
that partially overlaps `checkpoint-before-overflow.md` and `git-staging-scope.md` — the planner
should verify no net-new duplication is created (prefer strengthening the EXISTING pointers over
copying prose into a third file where the first two already suffice, per the Commit Scope
deletion above).

#### `error-handling.md` — 5,420 B (not in today's measured six; `.claude/**/*`-gated, high-probability future trigger)

| Section | Bytes | Classification | Disposition |
|---|---|---|---|
| Error Categories (L7-28) | 821 | Reference taxonomy | KEEP (short; low marginal cost) |
| Error Response Pattern: Log the Error (L34-58, incl. script invocation + field spec) | 1,240 | Reactive (used AFTER an error, not pre-action); the formal contract already lives in `context/schemas/errors-schema.json` + `context/formats/errors-format.md` per the file's own cross-reference | MOVE: keep ~200 B one-liner + pointer |
| Preserve Progress / Enable Resume / Report Clearly (L59-83) | ~500 | Short, low-cost | KEEP |
| Severity Levels table (L85-92) | ~450 | Reference table, cheap | KEEP |
| Recovery Strategies: Timeout/State Sync/Build Error/jq/MCP Abort/Delegation Interrupted (L94-161) | 2,268 | Entirely reactive (invoked only after an error already occurred — never gates a write before it happens) | MOVE in full to `context/standards/error-recovery-strategies.md` (new file) |
| Non-Blocking Errors (L163-171) | ~230 | Short | KEEP |

**Estimated new eager core**: ~2,150 B (-60%). **Movable**: ~3,270 B.

#### `state-management.md` — 5,148 B (loaded eagerly today)

| Section | Bytes | Classification | Disposition |
|---|---|---|---|
| File Synchronization (L7-9): "Never edit TODO.md directly" | ~200 | **Pre-action prohibition** | KEEP |
| Canonical Sources (L11-20) | 448 | Short reference, needed to know which file is authoritative before writing either | KEEP |
| Artifacts Are Append-Only: core prohibition (L22-37, minus the paragraphs below) | ~900 | **Pre-action, write-gating** ("Wholesale `.artifacts = [...]` assignment is prohibited"; append via `+=` only) | KEEP eager in full |
| Enforcement mechanism + Known limitation paragraphs (L38-50) | 1,016 | Narrative explaining WHY/HOW enforcement works, not itself a pre-action constraint (the constraint is already stated above it) | MOVE |
| Status Transitions: Permissive Model + Restrictions (L52-74) | ~750 | **Pre-action** (terminal-state transition restrictions must be known before attempting a status change) | KEEP, but the ASCII diagram could be trimmed to the bullet restrictions alone if bytes are tight |
| State-First Update Pattern (bash examples, L75-90) | 641 | Mostly a "how" reference (the command exists); keep the one-liner, move the explanatory prose | MOVE ~440 B, KEEP ~200 B |
| Error Handling section (L92-104) | 326 | Reactive | MOVE |
| File Scope + Schema Reference (L106-117) | ~300 | Already pointers | KEEP (cheap) |

**Estimated new eager core**: ~3,450 B (-33% — smaller ratio than the others because more of
this file's content is genuinely pre-action-binding). **Movable**: ~1,700 B to
`context/standards/state-management-narrative.md` (new file) or folded into the existing
`context/reference/state-management-schema.md` (already the pointed-to schema doc).

#### `pr-prohibition.md` — 4,628 B (loaded eagerly today, universal `"**/*"` glob)

| Section | Bytes | Classification | Disposition |
|---|---|---|---|
| Scope + Prohibited Operations 1-3 (L1-31) | ~1,300 | **Pre-action, write-gating** (PR/push/merge-invocation prohibitions — the single most write-gating content in the whole rules directory, since it applies to every session unconditionally) | KEEP eager in full, unchanged |
| Required Behavior + Rationale (L33-45) | ~900 | **Pre-action** (what to do INSTEAD; the "why" is short and worth keeping for judgment calls under ambiguity) | KEEP eager |
| CSLib Extension: `/pr` Command + `/pr --review` Workflow (L47-103) | 2,999 | Deploy-conditional. Verified: this repo's `.claude-extensions.json` does NOT load `cslib`, and `agent-system/extensions/cslib/` exists as a separate, independently-deployed extension. The content describes CSLib's OWN `/pr` command internals — it is not generic PR-workflow guidance | **RELOCATE, don't just trim**: this content structurally belongs to the `cslib` extension (its own rule/context file, merged only when `cslib` is loaded), not to core's universal `pr-prohibition.md`. Recommend moving verbatim to `agent-system/extensions/cslib/context/...` (exact destination TBD by planner/CSLib owner) with, at most, a one-line pointer left in core: "See the CSLib extension's own docs for the `/pr` command, where deployed." |

**Estimated new eager core**: ~1,650-2,200 B (-53% to -64%). This is the single highest-value,
lowest-risk cut in Work Item 1: the moved content is 100% inert prose in every deploy without
CSLib (verified, not assumed), and the retained core is the smallest, most purely
prohibition-shaped file of the four.

#### `artifact-formats.md` — 5,360 B (loaded eagerly today; NOT named in the task's explicit split list)

Read in full for completeness. This file is dense reference/naming-convention content
(placeholder table, artifact naming/sequencing rules, phase-status-marker vocabulary) that an
agent genuinely needs before creating any `specs/**` artifact — it is already comparatively lean
relative to its information density (mostly tables and short enumerated rules, minimal prose
narrative). The one optional, low-priority trim identified: the "Example Flow" walkthroughs
(L58-81, ~700 B of illustrative round-numbering examples) restate the prose rules immediately
above them and could move to a companion if the planner wants a fourth cut, but this was not
requested by the task and is NOT required to hit a reasonable ceiling — recommend leaving
`artifact-formats.md` untouched unless the ceiling number chosen requires the extra ~700 B.

#### Already-good models: `source-store-deploy-boundary.md` and `no-task-references-in-deliverables.md`

`source-store-deploy-boundary.md` (2,746 B, no frontmatter) already carries an in-file HTML
comment recording WHY it is deliberately eager (its only enforcement is a non-blocking
PostToolUse hook, so gating it on `paths:` would mean the agent learns the rule only after the
violating write already landed). This is the pattern the ACCEPTANCE criterion asks every
deliberately-eager rule to follow.

`no-task-references-in-deliverables.md` (1,489 B, also no frontmatter) has NO such comment today
— it is eager by omission, not by a recorded decision, even though the omission is almost
certainly the right call (this rule also gates writes across the ENTIRE repo, not just
`specs/**`/`.claude/**`, so a `paths:` glob narrow enough to matter would have to be `"**/*"`,
which buys nothing over no frontmatter at all). **Recommend**: add the same style of in-file
comment here, and consider adding one to `pr-prohibition.md` too (its `paths: "**/*"` is
deliberate but currently unexplained in-file — the ACCEPTANCE criterion's "record the decision
in-file" applies equally to an explicit universal glob, not only to omitted frontmatter).

### External Resources: Where the Companion Docs Belong

`agent-system/extensions/core/context/standards/` already exists and holds 20 files including
two that are ALREADY the authoritative destination for content proposed for removal above:
`git-staging-scope.md` (18,824 B — commit-scope contract) and (via `checkpoint-before-overflow.md`,
9,103 B, in `context/patterns/`) the green/RED distinction `git-workflow.md`'s
Commit-Per-Green-Substep Mandate re-explains. The planner should prefer STRENGTHENING these
existing pointers over creating new companion files that re-duplicate the same prose a third
time. New companion files are genuinely needed for: `error-handling.md`'s Recovery Strategies
(no existing home), `state-management.md`'s enforcement/limitation narrative (partial overlap
with `context/reference/state-management-schema.md`, verify before creating a new file),
`git-workflow.md`'s No-Destructive-Git mode-by-mode narrative and Branch Strategy/Examples
(no existing home).

### Literature Duplication: Verified (Work Item 2)

The claim in the task description — that a "Literature Mode (`--lit`)" section appears TWICE
under two headings, with the second running several KB of directive-level detail — is CONFIRMED
in the generated `.claude/CLAUDE.md` (headings at line 293 and line 448), but is **NOT identical
duplicate content**, so "verify before cutting" was the right instruction:

- The FIRST occurrence (from `agent-system/extensions/core/merge-sources/claudemd.md`, L285-291,
  338 B) is already a short STUB pointer: "The `--lit` documentation now lives in the literature
  extension's merge source ... merged into generated CLAUDE.md only where the literature
  extension is loaded." This is low-cost (338 B) but becomes confusing noise specifically WHEN
  the literature extension IS loaded (as it is in this repo): the reader hits the stub, then 155
  lines later finds a second, identically-titled H2 with the real content. This is a heading-
  collision problem, not a duplicate-bytes problem — low-priority polish, not the main target.
- The SECOND occurrence (from `agent-system/extensions/literature/merge-sources/claudemd.md`,
  L37-198, 10,747 B) is the full, real content — genuinely present only once, not duplicated
  within itself.

**The real, measured, high-value cut** is inside that second occurrence:
`### Interactive Sub-Index Setup Detection` (source file L82-149) is **5,255 B** — over half of
the literature merge-source's Literature Mode section, and over 11% of the entire 46,475 B
generated CLAUDE.md by itself. It enumerates, in prose, the six-directive resolver contract
(`LIT_DISABLED`/`SUBINDEX_PRESENT`/`GLOBAL_MISSING`/`PROMPT_NEEDED`/`AUTONOMOUS_GLOBAL`/
`SPARSE_PROMPT_NEEDED`), the four-option `AskUserQuestion` wording, and the sub-index decision
flow — and this is verifiably NOT information an agent needs prefetched at session start: the
same content already lives as the SINGLE canonical, directly-executable version at
`agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` (12,175 B), which the file's
own header states is imported by `skill-researcher`, `skill-planner`, `skill-implementer`, and
their `-hard` variants — "rather than maintaining six near-duplicate copies." The CLAUDE.md prose
is therefore a THIRD, human-readable restatement of logic whose only two legitimate homes
(the resolver script `literature-lit-flag-resolve.sh` and `lit-stage4a-flow.md`) are already
lazy and already canonical. Cutting the CLAUDE.md restatement loses no agent-facing behavior: no
skill reads CLAUDE.md's prose version of this contract to decide what to do.

**Recommended cut**: replace the 5,255 B subsection with ~400-600 B: one sentence per each of the
four user-facing choices ("Use global corpus now" / "Create curation task" / "Search online to
ingest" / "Skip this run") plus a pointer to `context/patterns/lit-stage4a-flow.md` for the
executable contract and to `literature-lit-flag-resolve.sh` for the directive enumeration.
Net savings: ~4,650-4,850 B off the 12,851 B literature merge-source (-37% to -38%), ~10% off the
46,475 B generated CLAUDE.md total.

A secondary, smaller candidate in the same file: `### orchestrator_mode Dual-Consumer / Autonomy
Contract` (part of a 2,388 B trailing chunk after the Interactive Sub-Index subsection) is
maintainer-facing "future change must recheck" narrative, not agent pre-action content — flagged
as optional/secondary, not required to hit a reasonable ceiling.

**Core `merge-sources/claudemd.md` (24,707 B) audited, not targeted**: broken down by section,
the largest contributors are `Skill-to-Agent Mapping` (5,346 B), `Command Reference` (5,145 B),
`Hard Mode` (4,502 B), and `Task Management` (3,861 B) — all are routing/reference tables
actively consulted for command dispatch correctness, with no single chunk comparable in
shape to literature's Interactive Sub-Index subsection (i.e., no chunk that duplicates content
already canonical and lazy elsewhere). Recommend leaving core's merge-source untouched in this
task and flagging it as a lower-priority future audit target rather than inventing unverified
cuts to actively-used routing tables.

**Other extensions (email, memory, nix, nvim) use a DIFFERENT mechanism** — `EXTENSION.md`
(2,185 B / 4,054 B / 1,385 B / 1,491 B respectively, total 9,115 B), not
`merge-sources/claudemd.md`. Summing core (24,707) + literature (12,851) + the four EXTENSION.md
files (9,115) = 46,673 B, within ~200 B of the measured 46,475 B generated CLAUDE.md — confirming
these are the complete, exhaustive set of contributors and no other source (e.g. a stray template
skeleton) is hiding meaningful bytes. None of the four `EXTENSION.md` files is large enough to be
a plausible growth driver on its own.

### Where to Record the Eager Budget Ceiling

No `README.md` exists in `agent-system/extensions/core/rules/` today, and no existing
budget/ceiling language exists anywhere in the repo (`grep` for "budget"/"ceiling" across
rules and architecture context returned nothing). The natural, already-established home is
`agent-system/extensions/core/context/architecture/context-layers.md`'s "Eager vs. Lazy Loading
Channels" section (channel 3, L153-163), which ALREADY documents the "absence of frontmatter must
be a decision, not an omission" norm this task extends, and is the file `source-store-deploy-
boundary.md` already points readers to for this exact audit trail. Recommend adding the ceiling
statement there (e.g. a new bullet or short subsection under channel 3), not a new rules/README.md,
to avoid creating a second competing home for the same governance fact. If the planner prefers a
dedicated rules-directory README instead (also acceptable per the task's "or equivalent"), it
should cross-reference `context-layers.md` rather than duplicate the channel taxonomy.

### Recommendations

1. Split `git-workflow.md`, `error-handling.md`, `state-management.md` per the tables above,
   preferring reuse of `git-staging-scope.md` / `checkpoint-before-overflow.md` /
   `state-management-schema.md` over new companion files where content already overlaps.
2. Relocate `pr-prohibition.md`'s two CSLib subsections (2,999 B) into the `cslib` extension's own
   territory rather than trimming them in place — this is a structural fix, not just a slim.
3. Add an in-file "why eager" comment to `no-task-references-in-deliverables.md` (missing today)
   and to `pr-prohibition.md` (universal glob, currently unexplained in-file).
4. Cut the literature merge-source's `Interactive Sub-Index Setup Detection` subsection (5,255 B)
   to a short pointer at `lit-stage4a-flow.md` — the single highest-value Work Item 2 cut.
5. Consider (secondary, optional) trimming `orchestrator_mode Dual-Consumer / Autonomy Contract`
   and resolving the core-stub / literature-full heading collision at "Literature Mode (`--lit`)".
6. Leave `artifact-formats.md` and core's `merge-sources/claudemd.md` untouched — audited, not
   targeted; no comparable unverified-duplication chunk found in either.
7. Record the eager budget ceiling (recommend ≤20,000 B for the measured-eager-six rules class)
   in `context-layers.md`'s existing channel-3 section, not a new README.

## Decisions

- Companion docs go under `agent-system/extensions/core/context/standards/` (source store),
  deployed to `.claude/context/standards/`, per the existing five-layer context architecture.
- `pr-prohibition.md`'s CSLib content is a relocation (to the `cslib` extension), not a trim —
  recorded here so the planner does not simply delete it as inert prose without preserving it
  where it IS live (in CSLib deploys).
- The literature merge-source's `lit-stage4a-flow.md` pointer strategy (pointer + 4-line summary,
  not a full second copy) was chosen over creating a THIRD near-duplicate file, consistent with
  the file's own stated anti-drift rationale.

## Risks & Mitigations

- **Risk**: trimming `state-management.md`'s Status Transitions ASCII diagram too aggressively
  could strip a restriction an agent needs before attempting an invalid status transition.
  **Mitigation**: keep the bulleted restrictions verbatim even if the diagram is dropped; do not
  drop both.
- **Risk**: relocating CSLib content out of `pr-prohibition.md` could silently break CSLib deploys
  if the new destination isn't wired into CSLib's own merge/rule loading.
  **Mitigation**: planner should verify the CSLib extension's existing rule-loading mechanism
  before choosing the exact destination path; this is out of scope for further exploration here
  since CSLib is not loaded in this repo.
- **Risk**: over-cutting `git-workflow.md`'s No Destructive Git narrative could remove context an
  agent needs to correctly choose between `--branch` and `--no-revert` snapshot modes before a
  destructive operation. **Mitigation**: the forbidden-operations list and the "snapshot first"
  instruction stay eager in full; only the mode-by-mode prose explanation is proposed to move,
  and the moved companion doc remains one Read call away, consistent with "PRESERVE BEHAVIOR" for
  content that informs a CHOICE (not a stop/go gate) — the binding constraint applies to what an
  agent must know BEFORE acting to avoid a prohibited action, which the forbidden list alone
  supplies; the mode-selection detail is a secondary refinement, not the gate itself.

## Context Extension Recommendations

- **Topic**: eager rules budget / eager-vs-lazy loading channel 3 (`paths:` frontmatter).
  **Gap**: no explicit numeric ceiling exists anywhere in the repo for the eager rules class, so
  there is nothing for a future measurement to regress against. **Recommendation**: add the
  ceiling statement to `context-layers.md` channel 3 as described above (this task's own
  deliverable, not a separately spawned task).

## Correction to Hand to the Measurement-Harness Task (recorded, not acted upon)

Per the delegation's explicit instruction to record — and NOT act on — this correction: task 41
("Build eager-context measurement harness (`measure-eager-context.sh`)", currently
`[NOT STARTED]`) states its eager-set model as item (4): "rules lacking `paths:` frontmatter or
carrying `paths: "**/*"`". This measurement research confirms that model under-counts: it would
correctly catch `pr-prohibition.md` (`"**/*"`), `source-store-deploy-boundary.md`, and
`no-task-references-in-deliverables.md` (no frontmatter) — 8,863 B — but would MISS
`git-workflow.md` (11,147 B, `["specs/**/*", ".claude/**/*"]`), `artifact-formats.md` (5,360 B,
`specs/**/*`), and `state-management.md` (5,148 B, `specs/**/*`), a combined 21,655 B that
demonstrably loaded in the measured live session (total measured eager six: 30,518 B). That is a
~71% under-count of the measured six, in the same ballpark as this task description's own stated
"roughly 78%" figure (computed against a slightly different baseline set including
`error-handling.md`/`workflows.md`). The harness's model must be extended to glob-MATCH each
rule's `paths:` value against a representative session touched-path set (at minimum
`specs/**` and `.claude/**`, since this repo's entire workflow lives under those two roots),
not merely check for absent-or-universal frontmatter. This is recorded here per instruction; no
edit was made to task 41 or its territory.

## Appendix

### Search queries / commands used

- `wc -c agent-system/extensions/core/rules/*.md` (source-store rule sizes)
- `wc -c .claude/rules/*.md` (deployed sizes, confirmed byte-identical to source)
- `wc -c .claude/CLAUDE.md` / `wc -c agent-system/extensions/*/merge-sources/*.md` (CLAUDE.md
  contributor sizes)
- Per-file `sed -n '<range>p' <file> | wc -c` for every section-boundary measurement in the
  per-file tables above (git-workflow.md, error-handling.md, state-management.md,
  pr-prohibition.md, literature merge-source)
- `grep -rln "Email Extension" / "Memory Extension" / "Nix Extension" / "Neovim Extension"
  agent-system/` (traced the non-literature/core extension CLAUDE.md contributors to
  `EXTENSION.md`, not `merge-sources/claudemd.md`)
- `grep -n "^## " / "^### "` on both merge-sources files and the generated `.claude/CLAUDE.md`
  (heading-collision and section-boundary discovery for the literature duplication check)
- `jq` / `grep` against `specs/state.json` / `specs/TODO.md` to identify task 41 as the
  measurement-harness task referenced by the delegation's correction

### References

- `agent-system/extensions/core/context/architecture/context-layers.md` — "Eager vs. Lazy
  Loading Channels" section, existing home for the eager/lazy taxonomy and the ceiling
  recommendation's target location
- `agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md` — existing home
  for the green/RED distinction `git-workflow.md`'s Commit-Per-Green-Substep Mandate re-explains
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — existing home for the
  commit-scope contract `git-workflow.md`'s Commit Scope examples duplicate
- `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` — the canonical,
  agent-executable version of the literature Interactive Sub-Index Setup Detection contract
