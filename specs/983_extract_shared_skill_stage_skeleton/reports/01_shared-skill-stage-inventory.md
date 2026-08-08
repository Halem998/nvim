# Research Report: Task #983

**Task**: 983 - Extract shared skill stage blocks as imports; route all skills through skill-base.sh.
**Started**: 2026-08-08
**Completed**: 2026-08-08
**Effort**: Large (source-store-wide refactor touching ~91 SKILL.md files + skill-base.sh + a lint script + a dead context doc)
**Dependencies**: None (research-only)
**Sources/Inputs**:
- Codebase reads under `agent-system/extensions/**` (source store — every finding below cites a
  source-store path, per the binding SOURCE-STORE RULE)
- `specs/reviews/review-2026-07-29-agent-system.md` (the review that produced the measured
  duplication claims in the task description)
- Three parallel fork sub-investigations (hard-mode diff, MUST NOT presence, team/domain skills)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The canonical Stage-N skeleton actually in production use is `skill-researcher/SKILL.md`'s
  10-stage layout (Stage 1 → Stage 10, plus a `## Postflight (ALWAYS EXECUTE)` marker and
  `## MUST NOT (Postflight Boundary)` section). **`skill-researcher` itself never sources
  `skill-base.sh`** — every stage is hand-written bash, despite `skill-base.sh` already
  containing a same-named function for nearly every stage.
- `skill-base.sh` has 16 lifecycle functions. Only **7 have any production caller at all**
  outside `skill-orchestrate`/`skill-orchestrate-hard`; **6 have zero production callers
  anywhere** (only referenced in the test suite or in doc comments). The two `/orchestrate`
  engines are the heaviest real consumers of the Stage 2/3/7/8 functions — the direct-invocation
  skills (`skill-researcher`, `skill-planner`, most of `skill-implementer`) do not call them.
- The `.postflight-pending` marker is **not 4 shapes, it is 6** once the full 91-file corpus is
  checked field-by-field: an empty `touch` (2 files), `skill-base.sh`'s own function shape
  (0 live writers), and four JSON heredoc variants distinguished by presence/absence of
  `task_number`, `created`, `stop_hook_active`, and `team_size` (15 / 15 / 5 / 3 files
  respectively). Full breakdown and file lists in Findings.
- Confirmed genuine cross-reference drift: `skill-planner-hard/SKILL.md:405` says "Same as
  `skill-planner` Stage 7a pattern" — **`skill-planner` has no Stage 7a at all** (it jumps
  Stage 7 → Stage 8) and, as a direct consequence, **never propagates `memory_candidates`** to
  `state.json` postflight (a latent functional gap, not just a naming drift).
- `## MUST NOT (Postflight Boundary)` presence: 28/91 files have the exact heading; 32/91 have
  *some* `## MUST NOT` heading. The three core `-hard` skills lack it entirely (lean/cslib `-hard`
  variants do have it, so the gap is core-specific, not `-hard`-general). `skill-orchestrate` has
  a different, unrelated MUST NOT section (`Context Flatness Constraint`); `skill-orchestrate-hard`
  has none. `lint-postflight-boundary.sh` checks patterns only — zero section-presence check.
- The three team skills (`skill-team-research/-plan/-implement`) **already carry** a
  `## MUST NOT (Postflight Boundary)` section (contradicts one framing in the task description),
  but genuinely never call `update-task-status.sh` (100% hand-rolled `state-write.sh`), never
  mention "Task Order", and pass `--regen-todo` only on their postflight write — so TODO.md's
  Task Order block is stale for the run's full duration, confirmed, not just "never updated."
  None has a true inline self-execution fallback — their only degradation path re-delegates
  wholesale to the single-agent skill (`skill-researcher`/`skill-planner`/`skill-implementer`).
- Domain skills: zero of the 17 checked domain `skill-*-{research,implementation,implement}`
  files reference `lit-stage4a-flow.md`, call `memory-retrieve.sh`, or have any `Stage 4a`
  heading — confirmed 0/0/0 across nix, nvim, latex, typst, z3, python, web, email, epi.
  Pairwise near-duplication confirmed: nix/nvim research 81.9% identical lines, nix/nvim
  implementation 85.6%, latex/typst research 89.0%, latex/typst implementation 89.6%. The
  "z3 lost typst's Error Handling section" claim is confirmed (typst/latex both have
  `## Error Handling`; z3, nix, nvim, python do not).
- `skill-nix-implementation` and `skill-neovim-implementation` are the two domain skills that
  already call a `skill-base.sh` function (`skill_propagate_completion_summary`), but their
  overall stage skeleton is a **third, much thinner shape** distinct from both the core skeleton
  and `context/patterns/skill-lifecycle.md`'s prescription — critically, **they never write a
  `.postflight-pending` marker at all**, so they have no premature-termination protection.
- Two conflicting prescriptive docs exist. `context/patterns/skill-lifecycle.md` prescribes a
  0/1-4/5/6-stage layout that literally zero skills follow (confirmed). A second, more accurate
  doc, `context/docs/guides/creating-skills.md` (661 lines), already claims core skills "use
  `skill-base.sh` lifecycle functions directly" — a claim that is **currently false** for
  `skill-researcher`/`skill-planner` but is the *correct target state* this task should produce.
  Neither file is registered in `context/index.json` (unreachable via context-discovery; only
  reachable via a direct `@`-import, which `lit-stage4a-flow.md` already gets from six skills but
  `skill-lifecycle.md` gets from none).

## Context & Scope

Task 983 asks for the `lit-stage4a-flow.md` shared-@-import pattern to be replicated for six
more lifecycle stages, for skills to call existing `skill-base.sh` functions instead of hand-copying
them, for the postflight-marker schema to be unified, for the `-hard`/orchestrate MUST NOT gap to
be closed (with a lint check), for team skills to be routed through `update-task-status.sh`, for
the 12 domain research/implementation skill pairs to collapse onto the shared skeleton (gaining
Stage 4a for free), and for `context/patterns/skill-lifecycle.md` to be rewritten to match reality.
This report is read-only: it establishes the ground truth a planner needs — exact files, exact
line ranges, exact schema variants — for every one of those seven work items and the four
verification-bar claims.

All paths below are source-store paths under `agent-system/extensions/**`, per the binding
SOURCE-STORE RULE — this is where a planner must target edits. `.claude/**` is the deployed,
disposable copy.

## Findings

### 1. The canonical skeleton in production use (`skill-researcher/SKILL.md`)

`agent-system/extensions/core/skills/skill-researcher/SKILL.md` (513 lines) is the closest thing
to a "reference" implementation. Its stage list (`grep -n "^##\|^###"`):

| Stage | Heading | Lines |
|---|---|---|
| 1 | Input Validation | 40-65 |
| 2 | Preflight Status Update | 66-77 |
| 3 | Create Postflight Marker | 78-100 |
| 3a | Read Artifact Number | 102-145 |
| 4a | Memory Retrieval (Auto) — imports `@.claude/context/patterns/lit-stage4a-flow.md` | 147-183 |
| 4 | Prepare Delegation Context | 185-214 |
| 4b | Read and Inject Format Specification | 216-226 |
| 5 | Invoke Subagent | 228-283 |
| 5b | Self-Execution Fallback | 285-294 |
| — | `## Postflight (ALWAYS EXECUTE)` | 296-300 |
| 6 | Parse Subagent Return | 301-320 |
| 6a | Validate Artifact Content | 322-337 |
| 7 | Update Task Status (Postflight) | 339-360 |
| 7a | Propagate Memory Candidates | 362-379 |
| 8 | Link Artifacts | 381-411 |
| 8a | Lifecycle TTS Notification | 413-427 |
| 9 | Cleanup | 429-439 |
| 10 | Return Brief Summary | 441-453 |
| — | `## Error Handling` | 455-470 |
| — | `## MUST NOT (Postflight Boundary)` | 472-490 |
| — | `## Return Format` | 493-513 |

**Critical fact**: `skill-researcher/SKILL.md` has **zero** occurrences of `skill-base.sh`,
`skill_preflight_update`, `skill_create_postflight_marker`, `skill_cleanup`,
`skill_link_artifacts`, `skill_postflight_update`, `skill_validate_artifact`,
`skill_read_metadata`, `skill_read_artifact_number`, `skill_context_injection`, or
`skill_validate_input` (grep confirmed, zero hits). Every stage above is hand-written bash even
though `skill-base.sh` (below) has a same-purpose function for Stages 2, 3, 6a, 7, 8, 9.

`skill-implementer/SKILL.md` (760 lines) uses a similar but not identical numbering (its own
Stage 7 embeds what researcher calls Stage 7 + 7a as "Steps 1-4", plus a continuation loop, Stage
5a/5c, Stage 6b commit-inside-loop, Stage 9 Git Commit as a *separate* stage from Stage 10
Cleanup) — see Finding 3 for its one genuine `skill-base.sh` call site.

### 2. `skill-base.sh`: functions vs. real production callers

`agent-system/extensions/core/scripts/skill-base.sh` (775 lines) defines 16 `skill_*` functions
plus 2 helpers (`skill_get_extension_dir`, `skill_run_extension_hook`):

| Function | Def. line | Nominal stage | Production callers (outside skill-base.sh/tests/doc comments) |
|---|---|---|---|
| `skill_validate_input` | 185 | 1 | **None found** |
| `skill_preflight_update` | 217 | 2 | `skill-orchestrate/SKILL.md` (5 call sites), `skill-orchestrate-hard/SKILL.md` (4 call sites) |
| `skill_create_postflight_marker` | 238 | 3 | **None found** — every skill that writes a marker hand-writes the heredoc |
| `skill_context_injection` | 264 | 4 | **None as a function call** — only referenced in doc comments of `nix-context.sh`/`nvim-context.sh` ("Called by skill_context_injection() in skill-base.sh") but no SKILL.md actually calls it |
| `skill_read_artifact_number` | 286 | 3a | **None found** |
| `skill_read_metadata` | 319 | 6 | **None found** |
| `skill_validate_artifact` | 346 | 6a | **None found** |
| `skill_validate_task_artifacts` | 390 | (whole-dir sweep) | `command-gate-out.sh:133` (one call site) |
| `skill_postflight_update` | 412 | 7 | `skill-orchestrate/SKILL.md` (4 sites), `skill-orchestrate-hard/SKILL.md` (2 sites) |
| `skill_propagate_completion_summary` | 478 | 7 (Steps 2-3) | **Widest real adoption — 8 sites**: `skill-implementer/SKILL.md:493`, `skill-implementer-hard/SKILL.md:431`, `skill-epi-implement/SKILL.md:215`, `skill-neovim-implementation/SKILL.md:97`, `skill-nix-implementation/SKILL.md:97`, `orchestrator-postflight.sh:368`, `skill-orchestrate/SKILL.md:1014`/`:2247`, `skill-orchestrate-hard/SKILL.md:802` |
| `skill_link_artifacts` | 514 | 8 | `skill-orchestrate/SKILL.md:1114`, `skill-orchestrate-hard/SKILL.md:1494` |
| `skill_cleanup` | 553 | 9/10 | **None found in SKILL.md files** (only exercised by `test-skill-base-lifecycle.sh`) |
| `skill_gate_completion_claim` | 592 | (completion-claim gate) | `skill-orchestrate/SKILL.md:987`, `skill-orchestrate-hard/SKILL.md:1383` |
| `skill_corroborate_phase_counts` | 700 | (phase corroboration) | `skill-orchestrate/SKILL.md` (multiple sites, single-task + multi-task MT-4), `skill-orchestrate-hard/SKILL.md` (same) |

**Reading**: `skill-base.sh` is real, well-tested infrastructure (has a dedicated
`test-skill-base-lifecycle.sh` and `test-corroborate-phase-counts.sh`), but its adoption is
**inverted from what the task description implies** — it is not "sourced by only 8 files" in a
uniform way; rather, **6 of 16 functions have never been called in production**, and the
functions that *are* called are called almost exclusively by the two `/orchestrate` engines
(which dispatch on behalf of a task) rather than by the base `/research`, `/plan`, `/implement`
skills a user invokes directly. `skill_propagate_completion_summary` is the one function with
broad, genuine adoption (8 sites spanning core + 2 domain extensions + the orchestrate engines).

Files that actually `source .claude/scripts/skill-base.sh` (excluding 3 doc-only mentions in
`system-overview.md`, `architecture-spec.md`, `creating-skills.md`, and `research-flow-example.md`,
and excluding the file's own self-reference header comment): **9 files** — `skill-epi-implement`,
`skill-nix-implementation`, `skill-neovim-implementation`, `skill-implementer`,
`skill-implementer-hard`, `skill-orchestrate`, `skill-orchestrate-hard`, `orchestrator-postflight.sh`,
`command-gate-out.sh`. (The review's "sourced by only 8 files" is close but the live count today
is 9 — likely drifted slightly since the review was written, or counted `skill-base.sh` itself.)

### 3. The `.postflight-pending` marker: 6 shapes, not 4

`grep -rl "postflight-pending" agent-system/extensions/*/skills/*/SKILL.md` returns **41 files**,
but two of those are false positives for "writes a marker" (see below), and the true picture,
verified field-by-field via direct grep of each heredoc's JSON body, is **6 distinct shapes**:

**Shape 0 — `touch` (empty file, no JSON at all)**: 2 files —
`agent-system/extensions/cslib/skills/skill-pr-review-implementation/SKILL.md:87`,
`agent-system/extensions/cslib/skills/skill-pr-review-research/SKILL.md:61`. Both later `rm -f`
the same path (lines 274 / 235) — a valid marker-existence check but zero metadata inside it.

**Shape S — `skill-base.sh`'s own `skill_create_postflight_marker` shape** (line 238-256 of
`skill-base.sh`): `session_id`, `skill`, `operation`, `reason`, `created`, `stop_hook_active` —
**no `task_number`**. Zero live writers call this function (see Finding 2), so this shape exists
only in `skill-base.sh` itself and is not currently produced by any running skill.

**Shape A — "standard full"** (`task_number` + `created` + `stop_hook_active`, no `team_size`):
**15 files** — `skill-researcher`, `skill-spawn`, `skill-reviser`, `skill-planner`,
`skill-epi-research`, `skill-epi-implement`, `skill-financial-analysis`, `skill-funds`,
`skill-slide-planning`, `skill-slide-critic`, `skill-grant`, `skill-slides`, `skill-timeline`,
`skill-implementer`, `skill-web-implementation`.

**Shape B — "task_number + created, no stop_hook_active"**: **15 files** —
`skill-founder-implement`, `skill-budget`, `skill-web-research`, `skill-deck-plan`,
`skill-deck-research`, `skill-finance`, `skill-analyze`, `skill-founder-plan`, `skill-project`,
`skill-deck-implement`, `skill-meeting`, `skill-founder-spreadsheet`, `skill-legal`,
`skill-strategy`, `skill-market`. (This is a fifth-from-the-task-description shape not called out
in the task's "FOUR incompatible" framing — the founder/present extensions form their own
distinct variant.)

**Shape C — "hard" (`task_number`, no `created`, no `stop_hook_active`)**: **5 files** —
`skill-cslib-research-hard`, `skill-implementer-hard`, `skill-researcher-hard`,
`skill-cslib-implementation-hard`, `skill-planner-hard`. Confirms the task description's claim
that hard-mode skills drop the behavioral `stop_hook_active` field.

**Shape D — "team" (`task_number` + `team_size`, no `created`, no `stop_hook_active`)**:
**3 files** — `skill-team-implement`, `skill-team-plan`, `skill-team-research`. Confirms the
task description's claim exactly.

**False positive** (in the raw 41-file grep, not a true writer): `skill-refresh/SKILL.md` —
this file only *reads/deletes* orphaned `.postflight-pending` markers (`find ... -delete`,
`rm -f specs/.postflight-pending`) as part of its cleanup sweep; it never writes one.

Sample heredocs (representative of Shapes A/C/D), confirming the exact field deltas:

```
# Shape A (skill-researcher, lines 87-98) — full standard
{ "session_id":..., "skill":..., "task_number":N, "operation":..., "reason":...,
  "created":..., "stop_hook_active": false }

# Shape C (skill-implementer-hard) — hard, drops created + stop_hook_active
{ "session_id":..., "skill": "skill-implementer-hard", "task_number":N, "operation": "implement",
  "reason": "Hard-mode implementation in progress: ..." }

# Shape D (skill-team-research) — team, adds team_size, drops created + stop_hook_active
{ "session_id":..., "skill": "skill-team-research", "task_number":N, "operation": "team-research",
  "team_size":N, "reason": "Team research in progress: ..." }
```

**Cleanup blocks**: `grep -rl "rm -f.*postflight-pending" agent-system/extensions/*/skills/*/SKILL.md`
returns the same 41 files (three `rm -f` lines each, removing `.postflight-pending`,
`.postflight-loop-guard`, `.return-meta.json` — matching `skill_cleanup`'s body exactly). Zero of
these call `skill_cleanup` itself.

**Raw preflight calls**: `grep -rl "update-task-status.sh preflight" agent-system/extensions/*/skills/*/SKILL.md`
returns **17 files**: `skill-researcher`, `skill-researcher-hard`, `skill-cslib-research-hard`,
`skill-cslib-implementation-hard`, `skill-pr-implementation`, `skill-pr-review-implementation`,
`skill-pr-review-research`, `skill-financial-analysis`, `skill-lean-implementation-hard`,
`skill-lean-implementation`, `skill-lean-research-hard`, `skill-implementer-hard`,
`skill-planner`, `skill-implementer`, `skill-planner-hard`, `skill-orchestrate-hard`,
`skill-orchestrate` (the last two call the raw script directly in some branches even though they
also call `skill_preflight_update` in others — see Finding 2's orchestrate call-site list; the
two are not mutually exclusive within one file).

**TTS blocks** (`lifecycle-notify.sh`): `grep -rl` returns exactly **11 files** —
`skill-researcher`, `skill-cslib-research-hard`, `skill-reviser`, `skill-pr-review-implementation`,
`skill-pr-review-research`, `skill-implementer`, `skill-cslib-implementation-hard`,
`skill-implementer-hard`, `skill-planner`, `skill-researcher-hard`, `skill-planner-hard`. All 11
use the identical `if [ -f ".claude/scripts/lifecycle-notify.sh" ]; then bash ... "$STATE_STATUS" &; fi`
shape — no variant divergence observed here (unlike the marker), so this stage is a clean
extraction candidate as-is.

### 4. Cross-reference drift ("Same as skill-X Stage N")

Three `grep -rn "[Ss]ame as skill-"` hits in core skills:

- `skill-researcher-hard/SKILL.md:256` — "Same as `skill-researcher` Stage 7a." → **valid**:
  `skill-researcher` Stage 7a exists at line 362 ("Propagate Memory Candidates").
- `skill-researcher-hard/SKILL.md:262` (approx.) — "Same as `skill-researcher` Stage 8" → **valid**:
  Stage 8 ("Link Artifacts") exists at line 381.
- `skill-planner-hard/SKILL.md:405` — "Same as `skill-planner` Stage 7a pattern." → **DRIFTED**:
  `skill-planner/SKILL.md`'s actual stage list is `1, 2, 3, 3a, 4a, 4, 4b, 5, 5b, 6, 6a, 7, 8, 8a,
  9, 10, 11` — **there is no Stage 7a**. `skill-planner` jumps directly from Stage 7 ("Update Task
  Status (Postflight)", line 360) to Stage 8 ("Link Artifacts", line 374) with no memory-candidate
  propagation step at all. Grepping `memory_candidates` in `skill-planner/SKILL.md` returns zero
  hits.

**Consequence beyond naming**: this is not purely cosmetic. `skill-planner` never reads or
propagates `memory_candidates` from `.return-meta.json` to `state.json` at all — if
`planner-agent` emits memory candidates per its own contract, they are silently dropped today.
A shared Stage 7a `@`-import (or `skill_propagate_completion_summary`-style function call) would
fix both the drifted cross-reference *and* this functional gap in the same change, since
`skill-planner` would gain the propagation logic it currently lacks.

### 5. `## MUST NOT (Postflight Boundary)` section presence

Scanned all 91 `SKILL.md` files. **28/91** have the exact heading `## MUST NOT (Postflight
Boundary)`; **32/91** have some `## MUST NOT` heading (4 files have a bare `## MUST NOT` without
the "(Postflight Boundary)" qualifier, in the `filetypes` extension).

- **Confirmed**: `skill-researcher-hard`, `skill-implementer-hard`, `skill-planner-hard` (all
  three core `-hard` skills) have **zero** MUST NOT section of any kind. This is not a
  `-hard`-general pattern — `skill-lean-implementation-hard`, `skill-lean-research-hard` (lean
  extension), and `skill-cslib-implementation-hard` (cslib extension) **do** carry the section.
  The gap is specific to the three core hard skills.
- **Confirmed**: `skill-orchestrate-hard` has zero MUST NOT section of any kind.
  `skill-orchestrate` has a MUST NOT section, but a different one:
  `## MUST NOT (Context Flatness Constraint)` at `skill-orchestrate/SKILL.md:2541` (forbids
  reading reports/plans/summaries/handoffs mid-loop — an unrelated concern to the postflight
  boundary). So `skill-orchestrate` lacks the Postflight-Boundary-specific contract entirely, and
  `skill-orchestrate-hard` lacks any MUST NOT contract at all.
- **Corrected framing**: the three team skills (`skill-team-research/-plan/-implement`) **already
  have** `## MUST NOT (Postflight Boundary)` — `skill-team-research` at line 640,
  `skill-team-plan` at ~604, `skill-team-implement` at line 674 (which additionally carries a
  *second*, distinct section `## MUST NOT (Pre-Delegation Boundary)` at line 698). The task
  description's framing that team skills need this section restored does not hold; what does
  hold (see Finding 6) is the state-write mechanism and Task Order gaps.
- The 28 holders span core (`skill-implementer`, `skill-meta`, `skill-planner`, `skill-researcher`,
  `skill-reviser`, `skill-spawn`, `skill-team-implement`, `skill-team-plan`, `skill-team-research`)
  and implementation-side skills across cslib, epidemiology, founder, latex, lean, nix, nvim,
  python, typst, web, z3.

### 6. `lint-postflight-boundary.sh`: pattern-only, no section-presence check

`agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` (172 lines): extracts a
"postflight section" via `awk` (matching `### Stage [6-9]`/`Stage 1[0-9]` headings or prose like
"Parse.*Return"/"Postflight Status"), strips the `## MUST NOT` block and doc-note lines, then
greps the remainder for build commands (`lake build|nvim --headless|pnpm build|npm run
build|cargo build|cargo test|pytest|nix build|nix flake check|typst compile|pdflatex|latexmk`),
`grep` on source-file paths, and `mcp__*` tool references (`check_postflight_violations()`,
lines 64-122). **There is no assertion anywhere in the script that a `## MUST NOT` heading
exists** — `does_skill_delegate()` (line 58) only skips non-delegating skills; a delegating skill
with zero MUST NOT section and zero prohibited patterns in its postflight body **passes
silently**. This is the mechanism behind the task description's "checks patterns, not section
presence" claim, confirmed exactly.

Its scan roots are hardcoded to the **deployed** tree: `$PROJECT_ROOT/.claude/skills` and
`$PROJECT_ROOT/.claude/extensions` (line 49) — not `agent-system/extensions/**`. It is not
currently wired into `agent-system/extensions/core/scripts/verify-deploy.sh` (grep returns no
hit); its only other reference besides its own file and `postflight-tool-restrictions.md` is
`check-extension-docs.sh` and `manifest.json`/`lib/common.sh` path listings. A planner adding a
section-presence check must edit the **source-store** copy at
`agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh`, and verification will
require a fresh deploy before `.claude/scripts/lint/lint-postflight-boundary.sh` reflects the
change (consistent with the source-store/deploy boundary rule — scanning the deployed tree is
the established convention for a post-deploy lint, not itself a bug).

### 7. Team skills: state-write mechanics, Task Order, Stage 5b

All three read/write via **hand-rolled `state-write.sh` jq merges**, never
`update-task-status.sh`:

| Skill | Preflight write | Postflight write | `--regen-todo` |
|---|---|---|---|
| `skill-team-research` (658 lines) | Stage 2, `state-write.sh`, lines ~84-93 | Stage 10, lines ~472-503 | Only on the postflight call (line ~497-503) |
| `skill-team-plan` (622 lines) | Stage 2, lines ~91-100 | postflight, lines ~458-480 | Only postflight |
| `skill-team-implement` (713 lines) | Stage 2, line ~97 | Stage 12, lines ~491-513 | Only postflight |

Zero matches for "Task Order" in any of the three files (grep -n "Task Order" → no hits). Since
`update-task-status.sh` is the script that maintains TODO.md's Task Order block and none of the
three call it, and `--regen-todo` is only passed at the postflight write, **TODO.md's Task Order
is stale for the entire duration of a team run** — not merely "never updated," but genuinely
out of sync between preflight and postflight.

None has a true Stage-5b-style inline self-execution fallback. Each has a "Stage 4a: Fallback to
Single Agent" (`skill-team-research:137-146`, `skill-team-plan:143-151`,
`skill-team-implement:149-160`) that **re-delegates entirely to the corresponding single-agent
skill** (`skill-researcher`/`skill-planner`/`skill-implementer` via the `Skill` tool) rather than
doing inline work and writing `.return-meta.json` itself. Note also a naming collision:
`skill-team-plan`'s own "Stage 5b" heading (line 188) is "Load Research Context" — unrelated to
the canonical skeleton's Stage 5b concept — so any shared Stage 5b import must not assume the
stage-number is free for reuse in that file.

### 8. Domain skill pairwise duplication and Stage 4a absence

17 domain files checked (`nix`, `neovim`, `latex`, `typst`, `z3`, `python`, `web` ×2 each, plus
`skill-email-implementation`, `skill-epi-research`, `skill-epi-implement`): **zero** reference
`@.claude/context/patterns/lit-stage4a-flow.md`, **zero** call `memory-retrieve.sh`, **zero**
have any `Stage 4a` heading. This confirms the claim that `--lit`/`--clean`/memory injection
silently do nothing for every non-core, non-cslib task type.

Pairwise near-duplication (method: `diff -y --suppress-common-lines | wc -l` = differing-line
count; identical% = (total − diff) / total):

| Pair | Total lines | Differing lines | Identical % |
|---|---|---|---|
| `skill-nix-research` vs `skill-neovim-research` | 83 | 15 | 81.9% |
| `skill-nix-implementation` vs `skill-neovim-implementation` | 132 | 19 | 85.6% |
| `skill-latex-research` vs `skill-typst-research` | 73 | 8 | 89.0% |
| `skill-latex-implementation` vs `skill-typst-implementation` | 96 | 10 | 89.6% |
| `skill-z3-research` vs `skill-typst-research` | 62 | 20 | 67.7% |
| `skill-python-research` vs `skill-z3-research` | 62 | 9 | 85.5% (z3/python are closer clones of each other than of typst) |

`## Error Handling` section presence: **present** in `skill-typst-research`,
`skill-typst-implementation`, `skill-latex-research`, `skill-latex-implementation` (all at line
60); **absent** in `skill-z3-research`, `skill-z3-implementation`, `skill-python-research`,
`skill-python-implementation`, `skill-nix-research`, `skill-nix-implementation`,
`skill-neovim-research`, `skill-neovim-implementation`. Confirms "z3 lost typst's Error Handling
section" and shows the gap is wider (nix/nvim/python also lack it).

### 9. `skill-nix-implementation`/`skill-neovim-implementation`: a third, thinner skeleton shape

`agent-system/extensions/nix/skills/skill-nix-implementation/SKILL.md` (132 lines) is notable:
it is the closest any domain skill gets to using `skill-base.sh` (its Stage 6 sources
`skill-base.sh` and calls `skill_propagate_completion_summary` — line 95-97), but its overall
stage numbering diverges completely from both the core skeleton and
`context/patterns/skill-lifecycle.md`:

```
Stage 1 Input Validation → Stage 2 Preflight Status Update → Stage 3 Prepare Delegation Context
→ Stage 4 Invoke Subagent → Stage 4b Self-Execution Fallback → [Postflight] → Stage 5 Parse
Subagent Return → Stage 6 Update Task Status → Stage 7 Link Artifacts → Stage 8 Git Commit →
Stage 9 Return Brief Summary
```

There is **no Stage 3 "Create Postflight Marker" at all** — confirmed by its absence from the
41-file `.postflight-pending`-writer list in Finding 3. This domain skill has **no premature-
termination protection whatsoever**. There is also no Stage 3a (artifact numbering), no Stage 4a
(memory/literature), and no Stage 8a (TTS). `skill-neovim-implementation` mirrors this shape
exactly (also calls `skill_propagate_completion_summary`, also has no marker stage).

### 10. Two conflicting prescriptive docs; neither is indexed

**`agent-system/extensions/core/context/patterns/skill-lifecycle.md`** (197 lines) prescribes a
`### 0. Preflight Status Update` / `### 1-4. ...` / `### 5. Postflight Status Update` / `### 6.
Return Propagation` layout under a "Skill Structure > Section Organization" heading (lines
65-86). **Zero of the 91 skills use this numbering** — every actual skill uses the `Stage
N`/`Stage Na` convention documented in Findings 1/3/9 above. This doc also references
`@.claude/context/patterns/inline-status-update.md` (which exists,
`agent-system/extensions/core/context/patterns/inline-status-update.md`) as the canonical
pattern — but no skill's actual Stage 2/7 blocks resemble that file's prescription either; they
match `postflight-tool-restrictions.md`'s "Correct Postflight (skill-researcher pattern)" example
(lines 92-111 of that file) far more closely.

**`agent-system/extensions/core/docs/guides/creating-skills.md`** (661 lines) is a *second*,
more accurate-to-intent prescription: its "Using skill-base.sh in Extension Skills" section
(line 78+) documents a function table (`skill_preflight_update()` → Stage 2, etc.) and a
"Pattern A" example claiming **"Core skills (skill-researcher, skill-planner, skill-implementer,
etc.) use `skill-base.sh` lifecycle functions directly"** (line ~224). This claim is **false
today** (Finding 1 disproves it for `skill-researcher`), but it is the *correct target state* for
this refactor — a planner should treat `creating-skills.md`'s prescription as the aspirational
skeleton to make real, while `skill-lifecycle.md`'s different, unused 0/1-4/5/6 numbering should
be retired/rewritten per the task's item 7.

Neither file appears in `agent-system/extensions/core/context/index.json` or any
`index-entries.json` (`grep -c "skill-lifecycle\|lit-stage4a"` on all index files → 0 hits both).
Both are reachable only via direct `@`-import from a skill body. `lit-stage4a-flow.md` gets this
`@`-import from six skills already (by design, per its own header). `skill-lifecycle.md` gets it
from none — it is genuinely dead documentation today, consistent with the review's "deployed but
absent from index — unreachable by any agent" finding.

## Decisions

None — this is a research-only report. No source-store files were modified.

## Risks & Mitigations

- **Risk**: Unifying the postflight-marker schema (item 2) touches 41+ files across 8 extensions
  (core, cslib, epidemiology, founder, present, web, and the 2 `touch`-only cslib pr-review
  skills) — a mechanical but wide-blast-radius change. **Mitigation**: since `skill_cleanup` only
  ever `rm -f`s the file by path (never reads its contents) and `orchestrate-recover-outcome.sh`
  is the only real *reader* of marker contents (via `.return-meta.json`, not the marker itself —
  confirmed the marker is consulted only for staleness/existence, e.g. by `skill-refresh`'s
  `-mmin +60` check), schema unification is lower-risk than it looks: no consumer currently
  branches on which fields are present. A planner can pick the fullest schema (Shape A: +
  `task_number`, `created`, `stop_hook_active`) as the target without a compatibility shim.
- **Risk**: Collapsing the 12 domain skill-pairs onto the shared skeleton (item 5) will add a
  `.postflight-pending` marker stage to `skill-nix-implementation`/`skill-neovim-implementation`
  where none exists today — a *behavior change*, not just a dedup, since these two currently have
  zero premature-termination protection. **Mitigation**: flag this explicitly as an intentional
  fix-while-refactoring, not an incidental side effect, so it isn't lost in review.
- **Risk**: `skill-planner`'s missing Stage 7a (Finding 4) is a pre-existing functional gap
  (dropped memory candidates), not purely a documentation drift. **Mitigation**: a planner should
  treat "give skill-planner a real Stage 7a" as an explicit deliverable of the shared-import work,
  not assume the drifted cross-reference is merely cosmetic.
- **Risk**: Team skills' `state-write.sh`-only approach (item 4) may be deliberate — team skills
  update three parallel synthesis/teammate artifacts and might have working reasons to avoid
  `update-task-status.sh`'s single-task assumptions. **Mitigation**: a planner should read
  `update-task-status.sh`'s script body (not covered by this report) before assuming a drop-in
  replacement is safe, particularly for the `--regen-todo` timing gap identified in Finding 7.

## Context Extension Recommendations

- **Topic**: Skill lifecycle skeleton drift is real and current documentation actively
  misrepresents it in two different, non-overlapping directions.
  **Gap**: no single doc describes the ACTUAL 10-13-stage `Stage N`/`Stage Na` convention used by
  `skill-researcher`/`skill-implementer`/`skill-planner` today.
  **Recommendation**: this is exactly item 7 of the task's WORK TO RESEARCH — rewrite
  `agent-system/extensions/core/context/patterns/skill-lifecycle.md` to document the Stage-N
  skeleton skills actually use (per Finding 1), reconcile it with `creating-skills.md`'s
  `skill-base.sh`-function-table framing (Finding 10) rather than maintaining two separate
  prescriptions, and register the rewritten file in `context/index.json` so it stops being
  unreachable dead documentation.

## Appendix

### Search queries / commands used

- `find agent-system/extensions -iname SKILL.md | wc -l` → 91
- `grep -n "^skill_[a-z_]*()" agent-system/extensions/core/scripts/skill-base.sh` → 16 functions
- `grep -rl "postflight-pending" agent-system/extensions/*/skills/*/SKILL.md` → 41 (incl. 1 false
  positive, `skill-refresh`, which only deletes markers)
- Per-file heredoc field probe: `sed -n '/postflight-pending.*<<\|cat > .*postflight-pending/,/^EOF/p' <file> | grep -c '"task_number"\|"created"\|"stop_hook_active"\|"team_size"'`
- `grep -rl "update-task-status.sh preflight" agent-system/extensions/*/skills/*/SKILL.md` → 17
- `grep -rl "lifecycle-notify.sh" agent-system/extensions/*/skills/*/SKILL.md` → 11
- `grep -rln "source.*skill-base\.sh" agent-system/extensions/` → 14 hits, 9 real (non-doc) sourcing sites
- Per-function caller probe: `grep -rn "\b<fn>\b" agent-system/extensions --include="*.sh" --include="SKILL.md" | grep -v skill-base.sh | grep -v core/docs`
- `grep -rn "[Ss]ame as skill-" agent-system/extensions/core/skills/` → 3 hits (2 valid, 1 drifted)
- `grep -n "^## MUST NOT" <every SKILL.md>` → 28/91 exact "(Postflight Boundary)", 32/91 any MUST NOT
- Three parallel fork sub-investigations covering: (a) hard-mode `diff -u` percentage estimates
  and the `lint-postflight-boundary.sh` full read; (b) full-corpus MUST NOT presence table; (c)
  team-skill state-write/Task Order/Stage-5b analysis and domain-skill pairwise `diff -y`
  percentages — all findings above cross-validated directly against source files by the primary
  research pass.

### References

- `agent-system/extensions/core/scripts/skill-base.sh`
- `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` (the model to replicate)
- `agent-system/extensions/core/context/patterns/skill-lifecycle.md` (to be rewritten)
- `agent-system/extensions/core/docs/guides/creating-skills.md` (conflicting, more-accurate prescription)
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`
- `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh`
- `agent-system/extensions/core/skills/skill-researcher/SKILL.md`,
  `skill-planner/SKILL.md`, `skill-implementer/SKILL.md`, and their `-hard` variants
- `agent-system/extensions/core/skills/skill-team-research/SKILL.md`,
  `skill-team-plan/SKILL.md`, `skill-team-implement/SKILL.md`
- `agent-system/extensions/{nix,nvim,latex,typst,z3,python,web,epidemiology}/skills/*/SKILL.md`
- `specs/reviews/review-2026-07-29-agent-system.md` (source of the measured-duplication claims)
