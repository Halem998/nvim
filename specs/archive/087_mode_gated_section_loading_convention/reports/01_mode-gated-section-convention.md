# Research Report: Task #87

**Task**: 87 - Mode gated section loading convention
**Started**: 2026-09-02
**Completed**: 2026-09-02
**Effort**: ~1.5 hours
**Dependencies**: None
**Sources/Inputs**: Codebase (`agent-system/extensions/core/**`, `agent-system/extensions/{memory,literature,email,lean}/**`), `specs/TODO.md`, `specs/044_slim_task_command_body/**`, `specs/archive/056_slim_todo_and_orchestrate_command_bodies/**`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The mechanism this task is asked to "decide" is **not undecided in practice** — it already
  exists as a proven, twice-applied precedent: task 56 (archived, completed) extracted
  `todo.md`'s `## Notes` and `orchestrate.md`'s `## Batch Orchestrate Results` fence into
  `context/patterns/*.md` with an imperative "READ ... now" pointer; task 44 (planned, blocked on
  this task) designed the same mechanism for `commands/task.md`'s five non-default modes. This
  task's real job is to **formalize** that proven mechanism into a documented convention, add the
  one missing piece (a machine-detectable section marker), and build the regression-prevention
  lint — not to invent a new extraction strategy.
- **Two distinct mechanisms exist and both matter, but only one is this task's mechanism.**
  Prose/decision-logic branch content → `context/patterns/*.md` + imperative pointer (saves
  tokens only on invocations that skip the branch — this task's mechanism). Procedural bash →
  `scripts/*.sh` (saves tokens on *every* invocation, branch-gated or not; already established via
  ~20 existing `orchestrate-*.sh` scripts). The four target files are dominated by prose, not
  bash, confirming the pointer mechanism is primary here; bash-to-scripts is a separable,
  complementary lever the per-file tasks (88/89) may apply independently and should not be folded
  into this task's scope.
- **The convention's one real gap** is that the existing precedent has no way to *mark* a section
  as branch-gated, so its own implementation record documents having to manually re-locate section
  boundaries by heading text before every deletion to dodge the "fence-interior heading trap"
  (a naive `^## ` scan matching a decoy heading inside a fenced code example). This task should
  close that gap with an explicit paired HTML-comment marker
  (`<!-- branch-gated:begin condition="..." -->` / `<!-- branch-gated:end -->`), mirroring the
  bash `# --- name:begin ---` / `# --- name:end ---` marker style already used informally inside
  `skill-orchestrate/SKILL.md` itself. This gives both the lint and any future extraction tooling
  unambiguous, non-heading-dependent boundaries.
- **Lint recommendation**: model it directly on `lint-task-lookup-adoption.sh` — the
  structural-plus-reasoned-allowlist convention (not zero-tolerance), because real migration debt
  exists at landing time (3 of 4 known instances — orchestrate, literature, distill — will not be
  migrated by this task; only a small pilot lands here). Scope: runtime-loaded `.md` surfaces only
  (`commands/*.md`, `skills/*/SKILL.md`), never `docs/`/`context/`. Trigger: sum of
  `branch-gated:begin/end`-marked, not-yet-extracted bytes in one file exceeds a threshold —
  recommend **8,000 B (~2,000 tokens)** as the number for the plan/implementation to pin, chosen
  to sit comfortably below all four known instances (25,883 / 43,254 / 65,772 / 111,218 B) while
  giving headroom for small, legitimately-inline branch content not worth the extraction overhead.
  Wire it into `verify-deploy.sh` as **Gate 19** (Gate 18 is the current last gate).
- **Pilot recommendation**: do NOT pilot on any of the four named instances (skill-orchestrate,
  skill-distill, skill-literature, `commands/task.md`) — all four are explicitly owned by other,
  already-scoped tasks (88, 89, 44) and piloting there creates avoidable overlap/coordination
  debt. A clean, independent, appropriately-sized candidate exists: **`skill-email-cleanup/SKILL.md`'s
  `` `--all` Mode `` section (17,309 B, mutually exclusive with `Default Mode`, 254 lines,
  self-contained, no known dependent task)**. Extracting it demonstrates the full convention (marker,
  pointer wording, `index-entries.json` registration, lint passing green, measured byte/token
  delta) end-to-end without touching any of the four headline files.

## Context & Scope

Task 87 asks for three deliverables: (1) a documented convention in `context/patterns/` for
extracting mutually-exclusive branch sections out of always-loaded skill/command bodies, (2) a
lint enforcing it, (3) one pilot application proving the measured saving. The four large instances
named in the task description (skill-orchestrate's Multi-Task Mode, skill-distill's Auto Distill
Complete, skill-literature's seven Mode sections, `commands/task.md`'s five non-default modes) are
explicitly **not** this task's responsibility to migrate — they are owned by tasks 88, 89, and 44
respectively, all three already `[NOT STARTED]`/`[PLANNED]` and dependent on this task landing
first. This task's scope is the convention plus enforcement plus one small proof-of-concept.

## Findings

### The mechanism already exists — twice — and both applications are directly inspectable

**Precedent 1 (completed): task 56** (`specs/archive/056_slim_todo_and_orchestrate_command_bodies/`).
Extracted `todo.md`'s `## Notes` section (7,851 B) and `orchestrate.md`'s `## Batch Orchestrate
Results` fence (6,648 B) into `context/patterns/todo-archival-reference.md` and
`context/patterns/orchestrate-batch-results-template.md`. Both new files were registered in
`index-entries.json` with `load_when.commands`. The commit-verified summary
(`specs/archive/056.../summaries/01_command-body-extraction-summary.md`) records exact
before/after byte counts:

| File | Before (B) | After (B) | Delta |
|------|-----------:|----------:|------:|
| `commands/todo.md` | 49,254 | 41,855 | -15.0% |
| `commands/orchestrate.md` | 43,180 | 36,774 | -14.8% |

This precedent's pointer wording is the exact template to reuse:
> "**Reference material**: the archival-status definitions... live in
> `.claude/context/patterns/todo-archival-reference.md`. READ that file before executing any of
> those steps."
> "**Consolidated Output**: READ `.claude/context/patterns/orchestrate-batch-results-template.md`
> now and emit the batch results using that template. The template MUST be followed exactly —
> its per-section rendering conditions are part of the contract, not commentary."

Both pass what that task's own summary calls the **passive/imperative test**: "would an agent
reading only the command body know it is REQUIRED to open the referenced file at that moment?"
Never "see also" / "for more detail" phrasing.

**Precedent 2 (planned, blocked on this task): task 44**
(`specs/044_slim_task_command_body/reports/01_command-body-extraction-approach.md`,
`plans/01_task-command-mode-extraction.md`). Extends the same mechanism from *reference-appendix*
extraction (task 56's shape) to **whole-mode** extraction — `commands/task.md`'s Recover/Expand/
Sync/Review/Abandon modes (25,883 B combined, 65.7% of the file) each become a standalone
`context/patterns/task-{mode}-mode.md` file, with the Mode Detection dispatch table rewritten to
carry per-mode pointers:

```
- `--abandon RANGES` → Archive tasks. READ
  `.claude/context/patterns/task-abandon-mode.md` now and follow it exactly.
```

This report explicitly names the elevated risk of whole-section (vs. reference-appendix)
extraction: **the pointer target becomes the section's only specification**. A skipped/garbled
READ degrades a reference-appendix extraction (the agent still has surrounding procedural steps
and can muddle through); for a whole-mode extraction it produces **unspecified execution** — the
agent has nothing left to reconstruct the mode's exact behavior from. The mitigation task 44
designed, and this task should adopt as part of the formal convention: each extracted file's
opening line must state, unsoftened, that it is "the complete and only specification" for that
section and "MUST be followed exactly" (mirroring `orchestrate-batch-results-template.md`'s
existing framing) — not "additional detail" language.

Both precedents also independently confirm the deploy/registration mechanics needed:
- Pointer uses the **deployed** path form (`.claude/context/patterns/...`), never the source-store
  form, because that is the path an executing agent can open unambiguously.
- New file registered in `index-entries.json` with `load_when.commands`/`load_when.agents` as
  appropriate — `manifest.json` needs **no edit**, since `.provides.context` already lists the
  `patterns/` directory wholesale (confirmed by direct `jq` inspection in task 56's summary).
- Internal cross-references from other sections into the extracted region must be checked and
  repointed if needed (task 44's report found two such references and determined, after checking,
  that no repointing was needed today — but flagged the check as a required step every time,
  not assumed clean by pattern-matching).

### The fence-interior heading trap and why extraction order matters

Both task 44's plan and the task 88/89 descriptions in `specs/TODO.md` name the same hazard: a
naive `^## ` line-anchor scan used to find section boundaries can match a `##`-level heading that
appears **inside a fenced code block** (a worked example, an illustrative table) rather than a
real document heading — silently truncating the wrong range. Task 44's plan
(`specs/044_slim_task_command_body/plans/01_task-command-mode-extraction.md:172-183,273-302`)
documents one concrete decoy: a fence-interior `## Task Review` heading that a naive scan would
mistake for the real `## Review Mode` boundary. The mitigation already adopted there:

1. **Extract bottom-up** (last section first: Abandon → Review → Sync → Expand → Recover), so
   sections not yet touched keep their original line numbers.
2. **Re-locate every boundary by heading text, not a stored line number**, immediately before each
   deletion — confirming the fence-interior decoy is excluded by direct inspection each time.
3. Build a "boundary map" of every anchor (heading + line number + surrounding fence count) as a
   scratch verification step before any edit, and reconcile it against expectations before
   proceeding.

This hazard is a strong argument for the marker-pair recommendation below (see "Section-marker
convention"): an explicit paired comment marker gives both the lint and any future extraction
script an unambiguous boundary that does not depend on `^## ` heading-scanning at all, closing
the exact gap that forced task 44's plan into a three-step manual mitigation.

### Two mechanisms, correctly scoped: this task owns only one of them

The task description itself poses the choice: "a referenced context/ file read on demand when the
branch is taken is the established pattern — moving procedural bash to scripts/ removes it from
context entirely, while moving prose to context/ saves only on invocations that do not need it."
Measuring the four named instances' own composition confirms which mechanism dominates each:

- skill-orchestrate's Multi-Task Mode: **~11% bash** (per task 88's own measurement) — prose/
  decision-logic dominant.
- skill-distill's Auto Distill Complete: **~1.9% bash, essentially pure prose** (per task 89's own
  measurement) — an output template, not procedure.
- skill-literature's seven Mode sections: mixed; `## Mode: Ingest` (measured directly this
  session, 1,917 B) is itself majority-bash (script invocation + usage examples), but the file-wide
  bash share (64.5%) includes large procedural sections outside the Mode-gated regions too, so the
  Mode sections themselves are not uniformly bash-dominant.
- `commands/task.md`'s five non-default modes: decision logic (jq lookups, status-transition
  rules) with some bash, but task 44's own disposition table extracts them as prose/decision-logic
  blocks wholesale (whole-mode extraction), not as bash-to-scripts moves.

Net: the **prose/decision-logic → `context/patterns/*.md` + pointer** mechanism is the correct
primary mechanism for this convention, consistent with both existing precedents. The **bash →
`scripts/*.sh`** mechanism is real, already established (~20 existing `orchestrate-*.sh` scripts),
and *unconditionally* removes tokens (branch-gated or not) — but task 88 itself already classifies
it as "a secondary, separable lever... do it in a follow-up rather than widening this work" for
skill-orchestrate specifically. This task should note the bash-to-scripts option in the convention
doc as a complementary, pre-existing lever a per-file application task may reach for when a
branch-gated section happens to be bash-heavy — without adopting it as part of *this* convention's
own mechanism or lint scope. Conflating the two would both overclaim this task's mechanism
decision and risk duplicating a lever that already has its own established pattern and owner.

### Section-marker convention (new — closes the precedent's gap)

Neither existing precedent used an explicit marker; both relied on heading-text matching plus, for
task 44, a manually-built boundary map to dodge the fence-interior trap. This task should define
an explicit **paired HTML-comment marker**, placed immediately around the qualifying section:

```markdown
<!-- branch-gated:begin condition="multi_task_mode=true" -->
## Multi-Task Mode
...content...
<!-- branch-gated:end -->
```

Rationale for this specific shape:
- **Paired begin/end, not a single marker before the heading.** A single marker still requires
  finding the *end* of the section by scanning for the next same-or-higher heading — exactly the
  operation the fence-interior trap corrupts. A paired marker sidesteps that scan entirely: the
  lint (and any future extraction script) greps for the literal `branch-gated:end` string, which
  is far less likely to coincidentally appear inside an unrelated fenced example than a bare `##
  ` heading is.
- **Precedent for the naming shape**: `skill-orchestrate/SKILL.md` already uses an informal
  paired-comment convention for demarcating logical regions in bash — e.g.
  `# --- loop-guard-staleness:begin ---` / `# --- loop-guard-staleness:end ---` and
  `# --- budget-continuation-override:begin ---` / `# --- budget-continuation-override:end ---`
  (both found in `skill-orchestrate/SKILL.md`'s Stage 2). This convention exists today only as an
  ad hoc in-file style, not documented anywhere as a general pattern — formalizing the Markdown
  equivalent for branch-gated sections is a natural, low-friction extension of a style this
  codebase already reaches for instinctively, not an invented new syntax.
- **`condition="..."` attribute** documents, machine-readably, which delegation-context
  field/flag/status gates the section (e.g. `multi_task_mode=true`, `--auto`, `mode=all`) —
  useful both for a human auditing the marker and for a future lint enhancement that cross-checks
  the condition text against the actual dispatch logic (out of scope for this task, but free
  documentation value from a field that costs nothing to add now).
- **Known limitation, stated plainly rather than hidden** (matching this repo's stated practice in
  `lint-task-lookup-adoption.sh`'s own header): a marker-based convention only catches sections an
  author remembers to mark. A brand-new large branch-gated section introduced without the marker
  evades detection entirely. This is the same class of limitation the task-lookup lint already
  documents for its own line-oriented regex approach, and the repo's own
  `adoption-lint-conventions.md` treats "some real duplication grows unwatched until named" as the
  normal starting condition for this lint family, not a reason not to land it. Mitigation: the
  convention doc should instruct that any new `##`-level section entered via an explicit
  conditional dispatch statement (the same "skip Stages X-Y, proceed to Z" / "if `--auto`, ..."
  phrasing already used at each of the four known dispatch points) SHOULD be marked at authoring
  time, and code review / `/meta` skill-authoring guidance should reinforce it — but the lint
  itself, like its siblings, is a regression guard on the *marked* class, not a proof that no
  unmarked instance exists.

### Lint design: model directly on `lint-task-lookup-adoption.sh`

`context/patterns/adoption-lint-conventions.md` states the repo's own decision rule precisely:
**non-zero migration debt at landing time selects the allowlist convention; a class starting at
zero selects zero-tolerance.** This lint starts with 3-4 units of real debt (skill-orchestrate,
skill-distill, skill-literature all still fully inline after this task lands; `commands/task.md`
already deferred to task 44) and only the pilot instance clean — so it must use the
**structural-plus-reasoned-allowlist** convention, not zero-tolerance. Concretely:

- **Scope, by construction (not exclusion list)**: `commands/*.md` and `skills/*/SKILL.md` across
  each extension — the runtime-loaded executable surfaces. `docs/`, `context/`, `rules/` are out
  of scope because the scan never visits them, matching
  `adoption-lint-conventions.md`'s "Structural Requirement 2."
- **Root resolution**: reuse the exact dual-mode probe `lint-task-lookup-adoption.sh` already
  implements (`core/manifest.json` one level under a candidate root distinguishes source-store
  from deployed layout) rather than re-deriving it — `adoption-lint-conventions.md`'s "Structural
  Requirement 1" names this reuse explicitly.
- **Layer 1 (structural)**: for each file in scope, sum the byte span between every
  `<!-- branch-gated:begin ... -->` / `<!-- branch-gated:end -->` pair still present in the file
  (i.e., not yet replaced by a pointer). A file whose sum exceeds the threshold is a candidate.
- **Layer 2 (file-level allowlist)**: every known not-yet-migrated instance gets a reasoned entry,
  exactly like `lint-task-lookup-adoption.sh`'s `EXCLUDED_FILES` block — e.g. "`core/skills/skill-orchestrate/SKILL.md`
  — Multi-Task Mode section, pending migration (see task 88)". The allowlist is expected to shrink
  as 88/89/44 land; a new entry requires a stated reason, never a default response to a failing
  run.
- **Threshold**: recommend **8,000 B (~2,000 tokens)** as the number to pin at plan/implementation
  time. Calibration: it sits below all four known instances' aggregate sizes (25,883 / 43,254 /
  65,772 / 111,218 B) by a wide margin — so it will not need re-tuning as 88/89/44 land — while
  being comfortably above small, legitimately-inline branch content (e.g. a two-line `--verbose`
  toggle) not worth the extraction/pointer/registration overhead. This is a recommendation for the
  plan phase to confirm or adjust, not a hard requirement from the task description, which asks
  only for "a byte threshold" without naming one.
- **Class B script** (`set -uo pipefail`, counter-idiom): the lint must keep scanning every file
  after a violation to report a complete summary, per
  `context/standards/shell-strict-mode.md`'s Class B admission test — identical posture to
  `lint-task-lookup-adoption.sh`.
- **Regression test**: a fixture-driven `scripts/tests/test-lint-<name>.sh`, structurally modeled
  on `scripts/tests/test-lint-task-lookup-adoption.sh` (synthetic fixtures in a scratch dir, dual
  root-resolution modes exercised, never depends on the live tree being clean).
- **Wiring**: `verify-deploy.sh`'s last gate today is **Gate 18** (task-lookup adoption lint,
  `scripts/verify-deploy.sh:803`). The new lint should land as **Gate 19**, following the exact
  call shape of Gate 18 (`scripts/verify-deploy.sh:796-818`): existence check, `--verbose` run
  against the deployed tree, findings appended to `FINDINGS_LIST` on violation.
- **`run-all.sh` regression coverage**: no separate registration needed — `run-all.sh` discovers
  every `scripts/tests/test-*.sh` and flat `scripts/test-*.sh` file automatically per extension;
  adding the fixture test file is sufficient.

### Pilot candidate: `skill-email-cleanup/SKILL.md`'s `` `--all` Mode ``

Measured this session (`agent-system/extensions/email/skills/skill-email-cleanup/SKILL.md`,
47,832 B total):

| Section | Lines | Bytes |
|---|---:|---:|
| `## Default Mode (`mode=default`): Bounded 50-Step Pass` | 156 | 9,985 |
| `` ## `--all` Mode (`mode=all`): Whole-Mailbox Sweep, One Bucket Approval, Sub-50 Drain `` | 254 | 17,309 |
| `## Archive Scope (`scope=archive`): ...` | 50 | 3,774 |

`Default Mode` and `` `--all` Mode `` are genuinely mutually exclusive per CLAUDE.md's own
description ("default 50-step mode, `--all` whole-mailbox mode") — exactly one fires per
`/email` invocation depending on the `--all` flag. (`Archive Scope` is a composable modifier on
either, per CLAUDE.md: "Composable with any of the above" — not a third exclusive branch, so it
is a poor pilot candidate on its own and should be left alone.)

Recommend piloting on `` `--all` Mode `` alone (17,309 B, ~4,300 tokens): extract it into
`context/patterns/email-cleanup-all-mode.md`, leave `Default Mode` inline (it is the more
frequently invoked path, mirroring task 44's decision to keep `task.md`'s default Create Task Mode
inline), mark the section with the new `branch-gated:begin/end` pair before extraction so the
pilot also exercises the marker convention and the lint's detection path, register the new file in
`index-entries.json` with `load_when.commands: ["/email"]`, and measure the exact before/after
byte delta per the task 56 convention's `## Measurement Table` shape.

**Why not pilot on one of the four named instances instead**: all four already have dedicated,
scoped follow-up tasks (88 for skill-orchestrate, 89 for skill-literature + skill-distill, 44 for
`commands/task.md`), each written assuming the *full* section (all seven Mode sections in
literature, the whole Multi-Task Mode block, etc.) is still available to extract when that task
runs. If this task's pilot consumed even one of those sections (e.g. `skill-literature`'s smallest,
`## Mode: Ingest` at 1,917 B), it would force task 89's plan to be re-derived against a changed
starting state — an avoidable coordination cost this task's own text explicitly warns against
("per-file applications are separate tasks so each stays bounded to one agent run"). An
independent instance outside all three files removes that coupling entirely. (`skill-lean-version/SKILL.md`'s
three tiny Check/Upgrade/Rollback modes, 3,077 B total file, were also considered and rejected as
a pilot: too small to produce a meaningfully "measured saving," and the marginal extraction
overhead — new file, pointer, index entry — likely exceeds the win at that scale.)

## Decisions

- **Mechanism**: prose/decision-logic branch sections use the existing `context/patterns/*.md` +
  imperative "READ ... now" pointer mechanism (precedents: task 56, task 44's design). Procedural
  bash extraction to `scripts/*.sh` is a separate, already-established, complementary lever —
  documented as an adjacent option in the convention file, not adopted as this task's own
  mechanism or folded into the lint's detection model.
- **Section marker**: adopt a new paired HTML-comment convention,
  `<!-- branch-gated:begin condition="..." -->` / `<!-- branch-gated:end -->`, modeled on the
  informal bash `:begin`/`:end` comment style already present in `skill-orchestrate/SKILL.md`.
  This closes the fence-interior-heading-trap gap the two existing precedents had to work around
  manually.
- **Lint convention**: structural-plus-reasoned-allowlist (per
  `adoption-lint-conventions.md`'s decision rule), built directly on
  `lint-task-lookup-adoption.sh`'s structure (dual-mode root resolution, scope-by-construction,
  Class B counter-idiom, fixture-driven regression test), wired as Gate 19 in `verify-deploy.sh`.
- **Threshold**: recommend 8,000 B (~2,000 tokens) aggregate marked-but-unextracted bytes per file
  as the trigger value for the plan phase to confirm.
- **Pilot**: `skill-email-cleanup/SKILL.md`'s `` `--all` Mode `` section (17,309 B), independent of
  all three named follow-up tasks' territory.

## Risks & Mitigations

- **Marker-adoption blind spot** (stated above under Section-marker convention): a lint keyed on
  an explicit marker cannot catch an unmarked new offender. Mitigate via convention-doc guidance
  telling authors to mark any section entered by an explicit conditional-dispatch statement, and
  accept — as this repo's own adoption-lint precedent already accepts — that the lint is a
  regression guard on the marked class, not a completeness proof.
- **Whole-section extraction risk** (task 44's own finding, applies identically here): once a
  section is fully pointer-ized, a skipped/garbled READ produces unspecified execution, not
  degraded execution. Mitigate with the unsoftened "complete and only specification... MUST be
  followed exactly" framing at both the pointer site and the destination file's opening line,
  exactly as task 44 designed and task 56 already demonstrated working end-to-end.
- **Threshold mis-calibration risk**: 8,000 B is this report's recommendation, not a value derived
  from an existing documented budget constant (none was found — `validate-context-budgets.sh`'s
  tier caps govern a different thing, the additional `context/index.json` entries an *agent*
  loads, not a skill/command body's own always-loaded size). The plan phase should treat this as a
  starting point subject to confirmation, not a fixed requirement.
- **Pilot coordination risk**: even though `` `--all` Mode `` is outside the four named
  instances' territory, `skill-email-cleanup` is itself actively developed (per CLAUDE.md's email
  extension section). Check for any in-flight task touching that file before the pilot lands, at
  implementation time — none was found in `specs/TODO.md` during this research pass, but that pass
  was not exhaustive over every open task.

## Context Extension Recommendations

- **Topic**: mode-gated section loading.
  **Gap**: no existing `context/patterns/*.md` file documents the "READ ... now" pointer mechanism
  as a *named, general* convention — it exists only as two independent applications (task 56, task
  44) with no cross-referencing pattern doc tying them together, and no formal section-marker
  syntax.
  **Recommendation**: this task's own deliverable IS that context file — e.g.
  `context/patterns/mode-gated-section-loading.md` — consolidating the marker syntax, the
  imperative/passive pointer test, the `index-entries.json` registration shape, the
  whole-section-vs-reference-appendix risk distinction, and a pointer to
  `adoption-lint-conventions.md` for the lint's own convention choice. No other gap was found.

## Appendix

### Search queries / commands used

- `find agent-system/extensions/core -maxdepth 2 -type d`; `ls` of `skills/`, `scripts/lint/`,
  `context/patterns/`.
- `grep -n "^## " SKILL.md` and `awk`/`sed`/`wc -c` byte-range measurements against
  `skill-orchestrate/SKILL.md`, `skill-distill/SKILL.md` (memory extension),
  `skill-literature/SKILL.md` (literature extension), `skill-email-cleanup/SKILL.md` (email
  extension), `skill-lean-version/SKILL.md` (lean extension) — confirmed all byte figures cited in
  the task description and in `specs/TODO.md`'s tasks 88/89 reproduce against the live tree.
- Full reads: `context/patterns/adoption-lint-conventions.md`,
  `scripts/lint/lint-task-lookup-adoption.sh` (full script), `context/patterns/thin-wrapper-skill.md`,
  `context/patterns/context-discovery.md` (Rule Loading section), `context/patterns/lit-stage4a-flow.md`
  header, `scripts/verify-deploy.sh` (gate structure, Gate 18), `scripts/tests/run-all.sh` header,
  `context/standards/shell-strict-mode.md` (Class A/B/C), `scripts/validate-context-budgets.sh`
  header (tier-cap derivation — confirmed this governs a different budget class than a skill body's
  own size).
- `specs/TODO.md` entries for tasks 44, 87, 88, 89 (grep + direct read); full read of
  `specs/044_slim_task_command_body/reports/01_command-body-extraction-approach.md` and
  `plans/01_task-command-mode-extraction.md` (fence-interior-trap sections); full read of
  `specs/archive/056_slim_todo_and_orchestrate_command_bodies/summaries/01_command-body-extraction-summary.md`.
- `python3`/`jq` inspection of `index-entries.json` entries for
  `patterns/todo-archival-reference.md` and `patterns/orchestrate-batch-results-template.md` (exact
  registered shape, confirming `load_when.commands` usage and no `manifest.json` edit needed).
- `grep` searches across `agent-system/extensions/**` for `^## Mode:`/`^## .* Mode$` headings to
  identify pilot candidates outside the four named instances (`skill-lean-version`,
  `skill-email-cleanup` located; sizes measured directly).
