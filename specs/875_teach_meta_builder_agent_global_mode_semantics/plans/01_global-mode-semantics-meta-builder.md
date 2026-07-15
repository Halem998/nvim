# Implementation Plan: Task #875

- **Task**: 875 - Teach meta-builder-agent global-mode semantics
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: 873 (committed, [PARTIAL] — its Phase 5 live verification is blocked; see Overview)
- **Research Inputs**: specs/875_teach_meta_builder_agent_global_mode_semantics/reports/01_global-mode-semantics-for-meta-builder.md
- **Artifacts**: plans/01_global-mode-semantics-meta-builder.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`agent-system/extensions/core/agents/meta-builder-agent.md` (1429 lines) has **zero** references to
`target_root`/`mode_target`/`GLOBAL_ROOT` — every read and write path in it is a bare CWD-relative
`specs/...` or `.claude/...` string. Its dependency threads `mode_target`/`target_root` into the
delegation JSON, but this agent never consumes them. This plan makes the agent definition itself
unambiguous about where it reads and writes, by parsing `target_root` in Stage 1 and qualifying every
read/write path against it.

**Why this is load-bearing, not polish.** The dependency's live cross-repo verification never reached
dispatch (blocked by Claude Code's non-interactive workspace-trust dialog), so the upstream
`skill-meta` mitigation — an imperative path-qualification instruction in the Agent prompt — is
**unverified**. This agent is what actually writes task directories. Unmitigated, a cross-repo `/meta`
writes into the foreign repo and leaves `git add specs/` with nothing to stage. This plan therefore
does **not** rely on the upstream prompt imperative being honored: the agent definition must be
correct standalone.

**Definition of done**: every Category B/C/D/E location from the research inventory is corrected in the
source-store file, statically verified, with the manual live-test procedure documented for the user.
Live cross-repo verification is explicitly **out of scope for a success claim** (see Phase 6).

### Research Integration

The research report's per-line classification of all 47+ `specs/`/`.claude/` occurrences into five
categories is **adopted as-is and not re-derived**. Independently re-verified before planning:

| Claim | Verification |
|---|---|
| Source and deploy copies byte-identical | `diff` returned no output |
| Zero `target_root`/`mode_target`/`GLOBAL_ROOT` refs | `grep -c` returned 0 |
| Return-schema line numbers stale (`:138-143`) | Block is at **line 1258** (`## Stage 5: Return Structured JSON`) — ~1120 lines further down, exactly as research reported |
| Stage 0 inventory at `:158-162` | Confirmed exact |
| Script invocations bare-relative | Confirmed: lines 741, 1358, 1364, 1372; `git add specs/` at 1378 |
| Upstream threads the contract | `skill-meta/SKILL.md` lines 104-105 emit `mode_target`/`target_root`; lines 132-134 carry the (unverified) prompt imperative |

**Stale line numbers are a first-class hazard in this plan.** The file grew substantially since the
task description was written. Every phase below instructs locating blocks by **content anchor**, never
by the line numbers cited in the task description (`:26`, `:138-143`, `:158-162`, `:821`, `:1032-1034`,
`:1071-1074`, `:1118-1119`). Line numbers appearing in this plan are as-of-planning conveniences only
and must be re-confirmed by content at edit time.

### Prior Plan Reference

No prior plan for this task. The dependency's plan and summary were consulted during research; its
empirically-proven chained-`cd` convention for `git` is reused verbatim in Phase 5 rather than a new
variant being invented.

### Roadmap Alignment

No ROADMAP.md consulted (not provided in delegation context).

## Goals & Non-Goals

**Goals**:
- Parse `mode_target`/`target_root` in Stage 1 and hold as `$TARGET_ROOT` for the whole run.
- Qualify every read-only inventory operation (Category B) against `$TARGET_ROOT`.
- Retarget task-creation `file_scope`/`affected_area` heuristics (Category C) from `.claude/**` to
  `agent-system/extensions/core/**`.
- Qualify every write/mutate operation (Category D) — script calls, git commit, task-dir renderings,
  return JSON — against `$TARGET_ROOT`.
- Split the conflated SCOPE BOUNDARY (Category E) into an actor/workflow rule and a
  location-correctness rule.
- Verify statically; document the manual live procedure honestly.

**Non-Goals**:
- Editing any file other than `agent-system/extensions/core/agents/meta-builder-agent.md`.
- Editing the deployed `.claude/agents/meta-builder-agent.md` copy (gitignored, regenerated, silently wiped).
- Fixing `generate-todo.sh` or `manage-topics.sh` themselves (not in `file_scope`).
- Removing meta-builder-agent's own Stage 6 git commit in favor of skill-meta's postflight — that is a
  mechanism redesign, explicitly out of scope. Qualify it in place instead.
- Solving extension-aware (non-`core`) file_scope disambiguation — document as a known limitation.
- Any live cross-repo `/meta` test as a **success condition**.
- Touching `specs/state.json` or `specs/TODO.md` (sibling tasks run concurrently).
- Staging or reverting the pre-existing uncommitted edits to `lua/neotex/plugins/editor/which-key.lua`
  and `lua/neotex/plugins/tools/himalaya/utils/cli.lua`.

## Key Decisions

**Decision 1 — Path-qualification strategy: fully-qualified absolute paths as the default; chained
`cd` reserved for `git` only.** This is the single explicit strategy for the whole file.

Rationale, grounded in the verified mechanism facts:
1. **Write/Edit tools ignore shell `cd` entirely.** They need literal qualified paths regardless, so
   `cd` can never be a universal answer.
2. **Bash cwd does not persist across separate Bash tool invocations.** A `cd`-based convention must be
   re-derived correctly in *every* Bash call; one missed re-derivation silently reintroduces the bug.
   Absolute paths carry no cwd dependency and cannot be missed this way.
3. **The failure mode is silent, not loud.** `generate-todo.sh` and `manage-topics.sh` self-resolve
   `PROJECT_ROOT` from `BASH_SOURCE[0]`, not CWD — and `manage-topics.sh` has **no override flag at
   all**. A bare relative invocation without a same-call `cd` regenerates the *wrong* repo's
   `TODO.md`/`state.json` with no error. Absolute invocation (`bash "${TARGET_ROOT}/.claude/scripts/..."`)
   makes `BASH_SOURCE[0]` already rooted at the target, correct unconditionally.
4. **`--state`/`--todo` flags are not sufficient** — they don't fix `PROJECT_ROOT`, which also feeds
   the log path and the `generate-task-order.sh` delegate call. Do not mix them with a possibly
   mismatched `PROJECT_ROOT`.
5. **`git` keeps the chained-`cd` form** because that is the one pattern the dependency already proved
   live at the shell level, and it matches skill-meta's postflight byte-for-byte. Introducing a second
   unverified variant here would be worse than reusing the proven one.

**Decision 2 — Keep the `.claude/` classification keyword (research's flagged judgment call).** The
keyword list that triggers `task_type = "meta"` may keep the literal `".claude/"` string: a user typing
`.claude/` still signals a meta task. Only the *file_scope produced* must change. Add a clarifying
inline note so a future reader does not "fix" this into inconsistency.

**Decision 3 — Category C defaults to `core`, with the limitation documented, not guessed.** The
heuristic has no reliable signal to distinguish core from extension scope without parsing extension
manifests. Document `agent-system/extensions/core/**` as the explicit default and record
extension-aware disambiguation as a known limitation rather than silently guessing wrong.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Live cross-repo test hits the same workspace-trust blocker that stalled the dependency | H | H | Plan does not depend on it. All success criteria are static. Phase 6 documents the manual procedure and requires reporting an attempted-and-blocked test as **NOT OBSERVED**, never inferred as passing. |
| Editing the deployed `.claude/` copy instead of the source store — work silently wiped by next regeneration | H | M | Every phase names the source path explicitly. Phase 6 runs a `diff` that MUST show divergence, proving the edit landed in the source store. |
| Over-qualifying Category A lines (agent's own context loads) breaks the agent's ability to load its own reference material | H | M | Research's classification is exhaustive over all matches. Category A lines stay untouched. Phase 3 explicitly lists the Category A line set as forbidden territory. |
| Stale line numbers cause edits to land in the wrong block | M | H | Content-anchor location mandated in every phase; the `:138-143` → line 1258 discrepancy is the proof this is real. |
| Missed Bash block silently keeps a bare relative script call | H | M | Phase 6 greps for bare `bash .claude/scripts/` with no `${TARGET_ROOT}` prefix; must return zero hits. |
| Reframed SCOPE BOUNDARY read as *loosening* "never implement directly" | M | L | Rule 1 kept explicitly intact and unweakened; Rule 2 is purely additive. Phase 2 verification checks both rules are present and non-contradictory. |
| Concurrent sibling tasks cause state.json/TODO.md conflicts | M | M | This plan touches neither file. No status-sync work in any phase. |
| `validate-meta-write.sh` mistaken for a backstop enforcing target-root correctness | M | M | It only detects literal `.claude/` writes; its `specs/*|*/specs/*` skip matches unconditionally regardless of repo. Phase 2 states this limitation plainly in the reframed text. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 2, 3, 4, 5 |

**Territory note**: all phases edit the *same single file*. Wave 2's phases are dependency-independent
of each other but MUST NOT be dispatched to parallel agents — concurrent edits to one file will
conflict. Execute Wave 2 sequentially (2 → 3 → 4 → 5) in a single agent. The wave table records the
logical dependency graph; the file-territory constraint overrides it for dispatch.

---

### Phase 1: Establish the `$TARGET_ROOT` Contract in Stage 1 [COMPLETED]

**Goal**: Give the rest of the file a variable to qualify paths with. This is the load-bearing
addition — without it, no Category B/C/D fix is expressible.

**Tasks**:
- [ ] Locate the Stage 1 block by content anchor `### Stage 1: Parse Delegation Context` (~line 112).
- [ ] Extend the example delegation JSON to include `"mode_target": "global|local"` and
      `"target_root": "{resolved absolute path}"`, matching the field names skill-meta emits
      (`SKILL.md` lines 104-105) exactly — no renaming, no aliasing.
- [ ] Add an instruction to extract `target_root` and hold it as `$TARGET_ROOT` for the remainder of
      execution, alongside the existing `Validate mode is one of: interactive, prompt, analyze.` line.
- [ ] Add a defensive fallback: if `target_root` is absent from the delegation context (older caller,
      malformed input), resolve `TARGET_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"` and
      note the fallback in the run, rather than silently defaulting to CWD. **CWD must never be the
      fallback** — CWD-as-default is the exact bug this task exists to remove.
- [ ] Add a short, prominent **Path Qualification Convention** block immediately after Stage 1 stating
      Decision 1 in imperative form: absolute `${TARGET_ROOT}`-qualified paths for all Write/Edit and
      all script invocations; chained single-call `cd "$TARGET_ROOT" && ...` for `git` only; and the
      two mechanism facts that force it (Write/Edit ignore `cd`; Bash cwd does not persist across
      separate tool calls).

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/agents/meta-builder-agent.md` — Stage 1 block + new convention block.

**Verification**:
- `grep -n 'target_root\|mode_target\|TARGET_ROOT'` returns hits in the Stage 1 region (was 0 file-wide).
- Field names match `skill-meta/SKILL.md`'s emitted JSON exactly (`diff`-able by eye against lines 104-105).
- The convention block states the absolute-path default AND the `git`-only `cd` exception.
- No CWD-based fallback anywhere in the added text.

---

### Phase 2: Reframe the SCOPE BOUNDARY (Category E) [COMPLETED]

**Goal**: Split one conflated rule into two distinct rules that now have different correct answers.

**Tasks**:
- [ ] Locate by content anchor `**SCOPE BOUNDARY**` in the `## Constraints` section (~line 26) — do
      **not** trust the task description's `:26`.
- [ ] Replace the single conflated sentence with two clearly separate rules:
      - **Rule 1 (actor/workflow, substance unchanged)**: this agent MUST NOT implement system changes
        directly, in either the source store or a deploy tree. It creates TASKS only; all actual file
        creation/modification happens through the `/implement` lifecycle after tasks are created and
        confirmed.
      - **Rule 2 (location-correctness, new)**: `.claude/` under any repo is a gitignored, disposable
        deploy artifact regenerated from the source store (`agent-system/extensions/core/**` plus loaded
        extensions). No agent — including `/implement`-lifecycle agents — should hand-author files
        there; such edits are silently wiped by the next regeneration. Tasks this agent creates whose
        scope is an agent-system change must name `agent-system/extensions/core/**` (or the relevant
        extension's source directory) as their edit target, never `.claude/**`.
- [ ] Add the hook-limitation note: `validate-meta-write.sh` detects only literal `.claude/` writes; its
      `specs/*|*/specs/*` skip pattern matches unconditionally regardless of which repo the path belongs
      to, so it is **not** a backstop for target-root correctness and cannot be one from a PostToolUse
      hook that sees only a `file_path` argument.
- [ ] Update the FORBIDDEN entry `Write any files outside specs/` → `{target_root}/specs/`, so it cannot
      be read as licensing writes to *any* repo's `specs/`.
- [ ] Locate the Critical Requirements MUST NOT list by content anchor `**MUST NOT**:` (~line 1424) and
      apply the same `Modify files outside specs/` → `{target_root}/specs/` qualification.

**Timing**: 40 minutes

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/agents/meta-builder-agent.md` — Constraints section, Critical Requirements list.

**Verification**:
- Both rules present as separate bullets/sentences; Rule 1's "never implement directly" prohibition is
  textually intact and not weakened.
- The hook-limitation note is present.
- No remaining unqualified `outside specs/` phrasing in either list.
- Read the two rules back-to-back: they must not contradict each other.

---

### Phase 3: Qualify Read-Only Inventory Operations (Category B) [COMPLETED]

**Goal**: Make every inventory read report on the **target's** system, not whatever repo the agent's
CWD happens to be.

**Tasks**:
- [ ] Locate `### Interview Stage 0: DetectExistingSystem` by content anchor. Qualify all five commands
      with `${TARGET_ROOT}`:
      `ls "${TARGET_ROOT}/.claude/commands"/*.md`, `find "${TARGET_ROOT}/.claude/skills" -name "SKILL.md"`,
      `ls "${TARGET_ROOT}/.claude/agents"/*.md`, `ls "${TARGET_ROOT}/.claude/rules"/*.md`,
      `jq '.active_projects | length' "${TARGET_ROOT}/specs/state.json"`.
- [ ] Locate Stage 3B Step 2's `jq '.active_projects[] | select(...)' specs/state.json` (~line 1161) by
      content anchor; apply the same qualification.
- [ ] Locate Stage 3C Step 1 (`analyze` mode inventory, ~lines 1206-1226) by content anchor; qualify its
      four component-listing blocks and its `jq -r '.active_projects[]...' specs/state.json`. This is the
      read-only twin of Stage 0 and was **not** named in the task description — it is the same bug class.
- [ ] Fix the Mode-Context Matrix `analyze` row (~line 75). It currently reads
      `@.claude/CLAUDE.md`, `@.claude/context/index.json` — but analyze mode's entire purpose is to
      inventory the **target** system. Static `@`-syntax cannot be parameterized by a runtime variable,
      so rewrite as an explicit runtime instruction: `Read {target_root}/.claude/CLAUDE.md` and
      `Read {target_root}/.claude/context/index.json`. Leaving it as `@`-syntax would silently load the
      agent's **own** deployed copy instead of the target's.
- [ ] **Leave every Category A line untouched** — these are the agent's own reference material
      (`@`-references to component-selection/creating-commands/creating-skills/creating-agents guides,
      templates, formats) and must resolve against the running session's own deployment. Forbidden
      territory for this phase.

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/agents/meta-builder-agent.md` — Stage 0, Stage 3B, Stage 3C, Mode-Context Matrix.

**Verification**:
- Each of the five Stage 0 commands carries `${TARGET_ROOT}`.
- Stage 3B and Stage 3C `jq`/listing calls carry `${TARGET_ROOT}`.
- The analyze row is a runtime `Read {target_root}/...` instruction, not `@`-syntax.
- The Category A `@`-reference set is byte-unchanged (`git diff` shows no touched Category A lines).
- Extract each modified bash block and run `bash -n` for syntax validity.

---

### Phase 4: Retarget Task-Creation Paths to the Source Store (Category C) [COMPLETED]

**Goal**: Tasks this agent creates must name source-store edit targets. A created task pointing at
`.claude/**` would have its work silently wiped by the next regeneration.

**Tasks**:
- [ ] Locate the file-footprint heuristic by content anchor (~line 391, "match domain keywords ...
      against their corresponding `.claude/` subdirectories"). Change the target directory family from
      `.claude/{skills,agents,commands,rules,context}/` to
      `agent-system/extensions/core/{skills,agents,commands,rules,context}/`.
- [ ] Locate the Stage 3.5 "Affected Area" extraction description (~line 421, "Parse for directory
      mentions (.claude/commands/, .claude/skills/, .claude/agents/, etc.)"); apply the same change.
- [ ] Update the two Stage 3.5 worked examples (~lines 429, 435): `affected_area: ".claude/commands/"` →
      `"agent-system/extensions/core/commands/"`, and `".claude/skills/"` →
      `"agent-system/extensions/core/skills/"`.
- [ ] Per Decision 3, add an explicit note that `core` is the documented default and that
      extension-scoped tasks (e.g. an `email`-domain skill living at
      `agent-system/extensions/email/...`) are a **known limitation** requiring human correction —
      the heuristic has no signal to disambiguate without parsing extension manifests. Do not guess.
- [ ] Per Decision 2, **keep** the literal `".claude/"` classification keyword (~line 241) that triggers
      `task_type = "meta"`, and add a brief inline note that the *keyword* stays `.claude/` (a user
      typing it still signals a meta task) even though the *file_scope produced* must be a source-store
      path. This prevents a future reader from "fixing" it into inconsistency.

**Timing**: 40 minutes

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/agents/meta-builder-agent.md` — file-footprint heuristic, Stage 3.5 extraction + examples, Stage 2.5 keyword note.

**Verification**:
- Heuristic and extraction description name `agent-system/extensions/core/**`.
- Both worked examples updated.
- The `core`-default limitation note is present.
- The classification keyword survives with its clarifying note.
- No remaining `affected_area: ".claude/..."` example anywhere (grep).

---

### Phase 5: Qualify Write and Mutate Operations (Category D) [NOT STARTED]

**Goal**: Close the actual silent-wrong-repo-write paths. This is where unmitigated cross-repo `/meta`
corrupts a foreign repo.

**Tasks**:
- [ ] **Script invocations → absolute path (Decision 1)**. Locate by content anchor and convert:
      - `bash .claude/scripts/generate-todo.sh` (~line 741, prose) →
        `bash "${TARGET_ROOT}/.claude/scripts/generate-todo.sh"`.
      - `bash .claude/scripts/manage-topics.sh add "$topic"` (~line 1358) and
        `... set "$task_num" "$batch_topic"` (~line 1364) → absolute form. **`manage-topics.sh` has no
        `--state` override at all** — absolute invocation is the only correctness mechanism available.
      - `bash .claude/scripts/generate-todo.sh` in Stage 6 step 4a (~line 1372) → absolute form.
      - Do **not** add `--state`/`--todo` flags (Decision 1, rationale 4).
- [ ] **Git commit → chained `cd` (Decision 1's single exception)**. Locate Stage 6 "5. Git Commit"
      (~line 1378). Convert `git add specs/` + `git commit -m ...` into a **single chained Bash call**:
      `cd "$TARGET_ROOT" && git add specs/ && git commit -m "meta: create {N} tasks for {domain}"`.
      Mirror skill-meta's postflight form exactly. Add a note that the chain must be one Bash call
      because cwd does not persist across separate invocations.
- [ ] **Keep the Stage 6 commit in place** (Non-Goal). Add a brief note that skill-meta's postflight
      also commits; the later call harmlessly finds nothing staged. Removing it is a mechanism redesign,
      out of scope.
- [ ] **Task-directory creation → explicit qualified example**. The Allowed Tools list documents
      Write-created task directories, but Stage 6's per-task loop (~lines 702-715) has only prose
      comments with no literal `mkdir`/`Write`. Make it concrete with an explicitly
      `${TARGET_ROOT}`-qualified example so the mechanism is not left implicit.
- [ ] **DeliverSummary renderings**. Locate the table rendering `specs/{padded}_{task['slug']}/`
      (~line 821) and the three worked examples (~1032-1034, ~1071-1074, ~1118-1119) by content anchor.
      Add a header line to the DeliverSummary output — e.g. `**Created in**: {target_root} ({mode_target}
      mode)` — giving the reader one unambiguous anchor, and qualify the rendered paths. Rationale: a
      user reading `specs/037_...` while their CWD is a foreign repo will reasonably read it as relative
      to *their* repo, then run `/research 37` there and get a mismatch.
- [ ] **Return JSON**. Locate by content anchor `## Stage 5: Return Structured JSON` — **line 1258**,
      NOT the task description's stale `:138-143`. Update `"path": "specs/TODO.md"` (~line 1271) and any
      sibling artifact paths to render the resolved `{target_root}/specs/...`, so a *caller* parsing the
      return JSON — not just a human reading the summary text — can determine where artifacts landed.

**Timing**: 60 minutes

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/agents/meta-builder-agent.md` — Stage 6 (scripts, git, task-dir loop), DeliverSummary renderings, Stage 5 return JSON.

**Verification**:
- Zero bare `bash .claude/scripts/` invocations remain (grep).
- The git block is a single chained `cd "$TARGET_ROOT" && ...` call.
- DeliverSummary emits a resolved-root header line.
- Return JSON renders `{target_root}`-qualified paths.
- `bash -n` on each modified bash block.

---

### Phase 6: Static Verification and Manual Procedure Documentation [NOT STARTED]

**Goal**: Verify what can actually be observed. Report honestly what cannot.

**Verification honesty contract** (binding): every assertion below is either **OBSERVED** (a command
ran and its output is recorded in the summary) or **NOT OBSERVED**. An assertion that cannot be
observed MUST be reported as NOT OBSERVED and the phase marked **[PARTIAL]** — never inferred,
assumed, or reported as passing. A live cross-repo `/meta` test, if attempted, MUST be reported as
attempted-and-blocked, never as a pass.

**Tasks**:
- [ ] **Source-vs-deploy divergence** (proves the edit landed in the source store):
      `diff agent-system/extensions/core/agents/meta-builder-agent.md .claude/agents/meta-builder-agent.md`
      MUST now show differences. (Pre-edit baseline: identical.)
- [ ] **No bare relative script calls**: grep for `bash .claude/scripts/` without a `${TARGET_ROOT}`
      prefix → MUST be zero hits.
- [ ] **No unqualified state/TODO reads**: grep for bare `specs/state.json` / `specs/TODO.md` not
      preceded by `${TARGET_ROOT}` or `{target_root}` → review each remaining hit; every one must be
      either intentional prose or justified in the summary.
- [ ] **Contract consistency**: `target_root`/`mode_target` field names match `skill-meta/SKILL.md`
      lines 104-105 exactly.
- [ ] **Category A untouched**: `git diff` confirms no Category A `@`-reference line was modified.
- [ ] **No new task-number references** (no-task-references-in-deliverables):
      `grep -rinE '\btasks? [0-9]{2,4}\b' agent-system/extensions/core/agents/meta-builder-agent.md`
      → MUST introduce no new hits.
- [ ] **Bash syntax**: extract every modified bash block, run `bash -n` on each.
- [ ] **Scope discipline**: `git status --short` confirms only the one target file is modified by this
      task. The pre-existing uncommitted edits to `which-key.lua` and `himalaya/utils/cli.lua` MUST
      remain untouched and unstaged. `specs/state.json` and `specs/TODO.md` MUST be unmodified.
- [ ] **Document the manual live procedure** in the summary (NOT as a passing test) — for the user to
      run interactively, mirroring the dependency's recorded procedure:
      1. From a foreign repo's CWD, in an **interactive** Claude Code session (required — a
         non-interactive `claude -p` run cannot clear a fresh workspace's trust dialog), run `/meta`
         with a trivial prompt.
      2. Confirm the created task directory, `state.json` entry, and `TODO.md` update all land under
         `~/.config/nvim/specs/` — **not** the foreign repo's `specs/`.
      3. Confirm the foreign repo's `specs/` (if any) is untouched.
      4. Confirm the DeliverSummary header reports the resolved `target_root`.
      5. Confirm `/meta --local` still resolves to the current repo (the opt-out path).
- [ ] Record in the summary that live cross-repo verification remains **NOT OBSERVED**, blocked by the
      workspace-trust dialog, and is the user's manual step.

**Timing**: 50 minutes

**Depends on**: 2, 3, 4, 5

**Files to modify**:
- None (verification only). Produces the task summary.

**Verification**:
- Every static check above has recorded command output.
- The summary distinguishes OBSERVED from NOT OBSERVED explicitly.
- If any static check fails or cannot run, phase is [PARTIAL], not [COMPLETED].

---

## Testing & Validation

- [ ] `diff` source vs deploy shows divergence (edit landed in source store).
- [ ] Zero bare `bash .claude/scripts/` invocations.
- [ ] Zero unjustified bare `specs/state.json` / `specs/TODO.md` references.
- [ ] `bash -n` passes on every modified bash block.
- [ ] `target_root`/`mode_target` names match the upstream contract exactly.
- [ ] No Category A line modified.
- [ ] No new task-number references in the deliverable.
- [ ] `git status --short` shows only the single target file modified by this task.
- [ ] Both SCOPE BOUNDARY rules present, separate, non-contradictory.
- [ ] Live cross-repo `/meta` test: **NOT a success criterion** — documented as a manual user procedure.

## Artifacts & Outputs

- `agent-system/extensions/core/agents/meta-builder-agent.md` (modified — the only file changed)
- `specs/875_teach_meta_builder_agent_global_mode_semantics/summaries/01_{short-slug}-summary.md`
  — including the OBSERVED / NOT OBSERVED verification table and the manual live-test procedure.

## Rollback/Contingency

Single-file, source-store-only change. To revert:
`git checkout agent-system/extensions/core/agents/meta-builder-agent.md`

The deployed `.claude/` copy is regenerated from source and needs no separate revert. Because the file
is byte-identical to its deploy copy at plan time, the entire diff is attributable to this task, making
a clean revert unambiguous.

**Note**: the working tree has pre-existing uncommitted changes to `lua/neotex/plugins/editor/which-key.lua`
and `lua/neotex/plugins/tools/himalaya/utils/cli.lua`. Any rollback MUST be path-scoped to the single
target file — never `git checkout .`, `git reset --hard`, or `git clean`, all of which would destroy
that unrelated uncommitted work.

**Contingency**: if a phase cannot complete, mark it [PARTIAL] with the specific blocker recorded. The
phases are independently valuable — Phase 1's contract plus any subset of 2-5 is a strict improvement
over the current zero-qualification state, and partial completion never leaves the file in a
self-contradictory state (each phase's edits are internally coherent).
