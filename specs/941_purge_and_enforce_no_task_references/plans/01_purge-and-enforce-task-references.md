# Implementation Plan: Task #941

- **Task**: 941 - Purge ephemeral task-management references from deliverables and enforce the rule going forward
- **Status**: [IMPLEMENTING]
- **Effort**: 18 hours
- **Dependencies**: None
- **Research Inputs**: `specs/941_purge_and_enforce_no_task_references/reports/01_purge-and-enforce-no-task-references.md`
- **Artifacts**: plans/01_purge-and-enforce-task-references.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two halves, prevention first. A repo-wide lint script plus a single-source exemption taxonomy
land before any purge; the ~1,228 existing citations across four deliverable trees are then
purged tree-by-tree; the write-time hook flips from advisory PostToolUse to blocking PreToolUse
only as the final phase, against a tree the lint script has already certified clean. Definition
of done: `check-task-references.sh` exits 0 across all four trees, the exemption taxonomy is
documented in exactly one file and consumed by both scripts through one shared library, and the
blocking hook denies a violating write via exit code 2 with test coverage for the deny path and
every exemption category.

### Research Integration

Five research findings are load-bearing constraints here and are not re-derived:

1. **Baseline re-confirmed exactly** (independently re-measured during this planning pass, same
   numbers): `agent-system/extensions/**` 568/167, `.opencode/**` 610/188, `lua/**` 32/13,
   `.memory/**` 18/17 — total 1,228 occurrences / 385 files.
2. **`rules/git-workflow.md` self-trips the hook's own `PHASE_PATTERN`** at its example
   `task 259 phase 2: implement modal semantics evaluator` — the file that *defines* the
   sanctioned commit convention is, today, indistinguishable from a violation. This is the
   taxonomy's primary test case, handled in Phase 1.
3. **Test-suite path corrected**: `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh`
   (declared in `manifest.json` under `provides.scripts`), NOT the `hooks/tests/` path the task
   description names. That path does not exist.
4. **Blocking mechanism settled**: exit code 2, not `permissionDecision: "deny"` — `Write` and
   `Edit` are bare-allow-listed in `settings.json` `permissions.allow`, the exact precondition
   under which `permissionDecision: deny` is documented to be ignored. Matches
   `guard-destructive-git.sh`'s existing precedent.
5. **Agent-contract surface narrowed to 2 files**: only `general-implementation-agent.md` and
   `general-implementation-hard-agent.md`. `meta-builder-agent.md` is structurally forbidden from
   writing outside `specs/**`; `planner-agent.md` / `reviser-agent.md` write only to
   `specs/**/plans/`.

Two additional facts were verified during this planning pass and are NOT in the research report:

6. **The hook's registration lives in `agent-system/extensions/core/merge-sources/settings-hooks.json`**
   (under `hooks.PostToolUse`, matcher `Write|Edit`), not in `root-files/settings.json`. That
   merge-source has no `PreToolUse` key at all — `PreToolUse` entries live in
   `root-files/settings.json`, where `guard-destructive-git.sh` is registered.
7. **The current registration would swallow exit code 2.** It is wrapped as
   `bash .claude/hooks/validate-no-task-references.sh 2>/dev/null || echo '{}'` — the `||` turns
   any non-zero exit into exit 0. `guard-destructive-git.sh` is registered bare
   (`bash .claude/hooks/guard-destructive-git.sh`), which is why its exit-2 block works. The
   blocking flip MUST use the bare form.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `specs/ROADMAP.md` consulted (no `roadmap_path` supplied; `roadmap_flag` false).

## Goals & Non-Goals

**Goals**:
- One repo-wide lint script (`check-task-references.sh`) wired into `verify-deploy.sh`, the core
  manifest, and `settings.local.json` permissions.
- One exemption taxonomy, documented in `rules/no-task-references-in-deliverables.md`, mechanically
  consumed by both the lint script and the hook through a single shared bash library — never
  reimplemented as two regex bodies.
- Zero unexempted task-number citations across `agent-system/extensions/**`, `.opencode/**`,
  `lua/**`, and `.memory/**`.
- `validate-no-task-references.sh` flipped to a blocking PreToolUse gate using exit code 2, with
  test coverage for the deny path and every exemption category.
- The false enforcement claim in `rules/no-task-references-in-deliverables.md` corrected to match
  reality.

**Non-Goals**:
- Touching `specs/**`. It is the only exempt tree and stays exactly as-is.
- Adding the MUST-NOT bullet to extension implementation agents (`neovim-implementation-agent`,
  `nix-implementation-agent`, `email-implementation-agent`). Real gap, out of scope; log as
  follow-up.
- Porting the enforcement machinery (lint script, shared lib, blocking hook) into `.opencode/**`.
  `.opencode/**` is purged as a deliverable tree only; it keeps its own advisory posture.
- Purging the secondary classes (`specs/{NNN}_{slug}/` path citations, `sess_*` literals). They
  are measured and noted but not addressed by this plan's phases; the taxonomy leaves room for a
  follow-up task.
- Editing `.claude/**`. It is a gitignored deploy artifact; every agent-system edit targets
  `agent-system/extensions/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Blocking hook ships against a tree that is not actually clean | H | M | Phase 15 is gated on `check-task-references.sh` exiting 0 as a literal precondition, re-run at the start of the phase, not assumed from earlier phases |
| Lint script and hook drift into divergent regex logic | H | H | Both `source` one shared library (`scripts/lib/task-reference-patterns.sh`); neither defines `TASK_PATTERN`, `PHASE_PATTERN`, or exemption logic locally. Phase 15 removes the hook's inline copies |
| Purge silently deletes provenance carrying real explanatory weight | M | H | Every purge phase converts per the triage buckets; deletion of a parenthetical is permitted only when the surrounding prose already states the mechanism, and must be noted in the phase's commit body |
| Rewriting `git-workflow.md`'s examples breaks the convention it teaches | M | M | Phase 1 handles that file as its own reviewed sub-step with an explicit decision recorded in the taxonomy, not folded into a bulk purge |
| Self-modification hazard: this task edits hooks, `verify-deploy.sh`, manifest, and settings — a broken intermediate state can brick the orchestrator | H | M | Phase 2 and Phase 15 are `atomic-batch`; a headless redeploy + `verify-deploy.sh` run is an explicit checkpoint after each (see "Redeploy checkpoints" below) |
| Exit code 2 swallowed by the `\|\| echo '{}'` registration wrapper | H | H | Explicitly called out in Phase 15: registration must be the bare form, mirroring `guard-destructive-git.sh` |
| `.memory/**` write path bypasses `Write`/`Edit` (Bash heredoc) so the hook cannot see it | M | M | Phase 15 empirically verifies `skill-todo`'s live harvest write path before claiming `.memory/**` coverage; if it is a heredoc, the gap is documented in the rule, not silently assumed closed |

### Redeploy checkpoints (self-modification hazard)

`.claude/**` is regenerated from `agent-system/extensions/**`. Three consequences bind this plan:

- **After Phase 2**: `.claude/scripts/check-task-references.sh` does not exist until a deploy runs.
  Purge phases (4-14) therefore verify against the **source** copy at
  `agent-system/extensions/core/scripts/check-task-references.sh` with an explicit
  `REPO_ROOT=$(pwd)` override, exactly as `check-extension-docs.sh` documents for source-store
  invocation. A deploy is a checkpoint, not a blocker, for those phases.
- **Before Phase 15's verification**: run `bash agent-system/extensions/core/scripts/deploy-headless.sh`
  (or the user's `<leader>al` regeneration), then
  `bash agent-system/extensions/core/scripts/verify-deploy.sh` to confirm gate 4 exists and passes
  and that the new PreToolUse registration reached `.claude/settings.json`.
- **After Phase 15**: the blocking gate is live for every subsequent `Write`/`Edit` in the session.
  If the taxonomy has a false positive, further work in this repo is blocked until the shared
  library is corrected. This is why the flip is last and why the taxonomy is validated against
  real content across eleven purge phases first.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 | 2 |
| 4 | 15 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 |

Phases within the same wave can execute in parallel. Wave 3's twelve phases have deliberately
disjoint file territories (each phase's "Files to modify" enumerates its exclusive tree slice);
no two wave-3 phases may edit the same file.

**Phase-count justification vs. the research report's 13**: this plan uses 15. Two of the
research's proposed phases exceeded the one-agent-run bound and were split, and nothing was
merged:
- Research phase 4 (`core/{docs,scripts,skills,commands,agents,rules,hooks,merge-sources}`,
  205 occ / 53 files) → Phases 5 and 6 here.
- Research phase 10 (`.opencode/context/`, 210 occ / 50 files) → Phases 12 and 13 here.
Additionally, the research's phase 3/12/13 mapping is preserved with the taxonomy work
(research P2+P5) split across Phase 1 (taxonomy + shared library + `git-workflow.md` resolution)
and Phase 3 (Enforcement-section rewrite + agent contracts), because the Enforcement section
cannot truthfully describe the lint gate until Phase 2 has created it.

---

### Phase 1: Exemption taxonomy and shared pattern library [COMPLETED]

- **Goal:** Establish the single source of truth for what counts as a citation and what is
  exempt, as (a) a documented taxonomy table in the rule file and (b) one sourced bash library
  that both consumers will use. Resolve the `git-workflow.md` self-trip as the taxonomy's first
  real test case.

- **Tasks:**
  - [x] Create `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` exporting,
        as the ONLY definitions anywhere in the repo:
        - `TASK_SEP`, `TASK_PATTERN`, `PHASE_PATTERN` — copied verbatim from the current
          `hooks/validate-no-task-references.sh` (do not re-derive; the alternation-not-
          bracket-class rationale in that file's comment must come across too).
        - `is_exempt_path <path>` — returns 0 for `specs/*|*/specs/*`, mirroring the hook's
          existing `case` statement.
        - `strip_exempt_regions <<< "$content"` — emits the content with exempted lines removed,
          per the marker convention below. This is the function that prevents divergence: neither
          consumer implements exemption logic itself.
  - [x] Define the exemption marker convention in the library and document it in the rule:
        - Block form: a line containing `task-ref-ok:begin` opens an exempt region; a line
          containing `task-ref-ok:end` closes it. Comment syntax is irrelevant (markdown
          `<!-- -->`, shell `#`, Lua `--`) — the token is matched as a substring.
        - Inline form: a line containing `task-ref-ok` is itself exempt.
        - Both forms REQUIRE a trailing reason naming the taxonomy category.
  - [x] Add an `## Exemption Taxonomy` section to
        `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` as a table with
        columns Category / Verdict / Marker required? / Example, covering exactly five rows:
        1. `specs/**` artifacts — path-level exemption, no marker, unchanged.
        2. Git commit-message convention examples — **convert to placeholders**
           (`task {N}: {action}`, `task {N} phase {P}: {phase_name}`); a single genuinely-rendered
           example per convention may keep concrete numbers inside a `task-ref-ok:begin/end`
           region with reason `canonical rendered commit-message example`.
        3. Command-usage examples (`/research 7, 22-24, 59`, `/learn --task 142`) — **keep
           concrete numbers**, because the flag takes a number and a placeholder makes the example
           unusable; marker required, reason `command-usage example`.
        4. Quoted historical anti-patterns (a rule or doc displaying a real past violation as a
           negative example) — **keep verbatim**, marker required, reason
           `quoted historical anti-pattern`.
        5. Placeholder-bearing prose (`{N}`, `{NNN}`, `MM`) — not matched by `TASK_PATTERN` at all;
           recorded as a **constraint on future pattern changes** (never broaden the
           digit-requirement), not an exemption.
  - [x] Apply the taxonomy to `agent-system/extensions/core/rules/git-workflow.md` (3 occurrences):
        convert the `Examples` block's `task 334: create LaTeX documentation for Logos system`
        and `task 259 phase 2: implement modal semantics evaluator` and `todo: archive 3 completed
        tasks (336, 337, 338)` to the placeholder form already used by the `Standard Actions`
        table, then wrap the single retained rendered example in a `task-ref-ok:begin/end` region
        with reason `canonical rendered commit-message example`.
        **Decision recorded, not deferred**: category 2 converts to placeholders; it does not get
        a blanket path exemption. A path-scoped allowlist was rejected — it would grant whole-file
        immunity to files that also contain real violations.
        *(deviation: altered — the plan named `todo: archive 3 completed tasks (336, 337, 338)`
        as one of the 3 occurrences, but that string does not match `TASK_PATTERN` (a `(`
        follows the separator, not a digit); the actual 3rd match was `task 334: complete
        research` in the Single-Task Operations example, a different section than the named
        `Examples` block. Converted the actual matching occurrence to placeholder form, and also
        genericized the named-but-non-matching archive line for consistency with the Standard
        Actions table above it.)*
  - [x] Apply the taxonomy to
        `agent-system/extensions/core/rules/no-task-references-in-deliverables.md`'s own
        `**Before** (observed anti-pattern, illustrative only)` fenced block (2 occurrences):
        wrap in `task-ref-ok:begin/end` with reason `quoted historical anti-pattern`.

- **Timing:** 1.5 hours
- **Depends on:** none
- **Verification Tier:** local
- **Commit Mode:** atomic-batch
- **Scope Hypothesis:** Asserts 3 occurrences in `rules/git-workflow.md` and 2 in
  `rules/no-task-references-in-deliverables.md`. Confirm before editing with
  `grep -cEi "$TASK_PATTERN" agent-system/extensions/core/rules/git-workflow.md` (expect 3) and
  the same against the rule file (expect 2); if either differs, reconcile against the current
  file content before proceeding — both files are actively edited.

- **Files to modify**:
  - `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` — new; sole home of
    `TASK_SEP`/`TASK_PATTERN`/`PHASE_PATTERN`/`is_exempt_path`/`strip_exempt_regions`
  - `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` — add
    `## Exemption Taxonomy`; mark the existing Before-block
  - `agent-system/extensions/core/rules/git-workflow.md` — convert Examples to placeholders,
    mark the one retained rendered example
  - `agent-system/extensions/core/manifest.json` — add `lib/task-reference-patterns.sh` to
    `provides.scripts`

- **Verification**:
  - `bash -n agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` passes.
  - Sourcing the library in a subshell and echoing `$TASK_PATTERN` reproduces the hook's current
    pattern byte-for-byte: diff the library's assignment line against the hook's.
  - `grep -cEi "$PHASE_PATTERN" agent-system/extensions/core/rules/git-workflow.md` reports 0
    outside the marked region; feeding the file through `strip_exempt_regions` then grepping
    reports 0 total.
  - Same check on `rules/no-task-references-in-deliverables.md`: 0 after `strip_exempt_regions`.

---

### Phase 2: check-task-references.sh and its four wiring points [COMPLETED]

- **Goal:** A repo-wide audit script that consumes the Phase 1 library, plus every declaration and
  registration that makes it a real gate rather than a loose file.

- **Tasks:**
  - [x] Author `agent-system/extensions/core/scripts/check-task-references.sh`, following
        `check-extension-docs.sh` as the structural precedent: `set -uo pipefail`, `info()`/`fail()`
        helpers, a `FAILURES` counter, `REPO_ROOT` resolution via `deploy-root-guard.sh` with the
        documented `REPO_ROOT=$(pwd)` source-store override.
  - [x] Source `lib/task-reference-patterns.sh`; define NO patterns and NO exemption logic locally.
        If the library is missing, exit 2 with an actionable message — never fall back to an
        inline pattern.
  - [x] Enumerate candidate files via `git ls-files` per tree root, one root at a time:
        `agent-system/extensions`, `.opencode`, `lua`, `.memory`. All four are git-tracked
        (verified: 1049 / 1232 / 411 / 38 tracked files respectively), so `git ls-files` is
        uniform and naturally excludes gitignored runtime artifacts. Skip any path for which
        `is_exempt_path` returns 0.
  - [x] For each file: pipe its content through `strip_exempt_regions`, then grep the remainder
        with `PHASE_PATTERN` and `TASK_PATTERN`. Report `path:line:matched-text` per finding.
  - [x] **Exit codes** (document in the script header, matching `check-extension-docs.sh`'s
        header style):
        - `0` — no unexempted citations in any scanned tree.
        - `1` — one or more unexempted citations found.
        - `2` — environment/usage error (shared library missing, `git` unavailable, unknown flag).
          Distinct from `1` so a broken script is never mistaken for a clean tree.
  - [x] **`--quiet` flag**: `[[ "${1:-}" == "--quiet" ]]` gate, mirroring `check-extension-docs.sh`.
        Suppresses per-finding lines; emits only the one-line per-tree summary and sets the exit
        code. Any other argument exits 2.
  - [x] **Declare in `agent-system/extensions/core/manifest.json`**: add `check-task-references.sh`
        to `provides.scripts` (alphabetical; it sorts immediately before `check-extension-docs.sh`).
        *(deviation: altered — the plan's parenthetical was itself inaccurate: true alphabetical
        order places `check-task-references.sh` between `check-runtime-file-tracking.sh` and
        `check-vault-threshold.sh` ('check-e' < 'check-r' < 'check-t' < 'check-v'), not
        immediately before `check-extension-docs.sh`. Inserted at the correct alphabetical
        position instead, consistent with the array's existing strict ordering.)*
  - [x] **Wire into `agent-system/extensions/core/scripts/verify-deploy.sh`** as gate `4`,
        immediately after the existing `3. Doc-lint (check-extension-docs.sh --quiet)` block and
        before the summary. Copy that block's structure exactly, including its
        `[SKIP] $TARGET is a deploy consumer, not the source store` guard on
        `[ ! -d "$TARGET/agent-system/extensions" ]`, its
        `[ ! -x ] && [ ! -f ]` not-deployed `fail`, and its
        `(cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-task-references.sh" --quiet ...)`
        invocation form. Gate text: `4. Task-reference lint (check-task-references.sh --quiet)`.
  - [x] **Permission entries in `agent-system/extensions/core/root-files/settings.local.json`**:
        three parallel entries mirroring the `check-extension-docs.sh` trio exactly —
        `"Bash(bash .claude/scripts/check-task-references.sh)"`,
        `"Bash(bash .claude/scripts/check-task-references.sh --quiet)"`,
        `"Bash(bash /home/benjamin/.config/nvim/.claude/scripts/check-task-references.sh)"`.
  - [x] Run the script once against the live tree and record the first real baseline. If it
        reports a category the Phase 1 taxonomy miscategorized, amend the taxonomy table in the
        rule file — the rule file only. Never patch around it in the script.
        *(completed: baseline is 1223 occurrences across 4 trees — agent-system/extensions 563,
        .opencode 610, lua 32, .memory 18 — exactly 5 below the research's pre-Phase-1 1,228
        total, matching Phase 1's 5 purged occurrences. No taxonomy miscategorization observed.)*

- **Timing:** 2 hours
- **Depends on:** 1
- **Verification Tier:** interface
- **Commit Mode:** atomic-batch
- **Scope Hypothesis:** Asserts the script's first run reports ~1,228 occurrences across 385
  files (568/167, 610/188, 32/13, 18/17 by tree). Confirm by comparing the script's per-tree
  summary against the raw
  `grep -rEi "$TASK_PATTERN" <tree> | wc -l` figure for each tree. A script total materially
  *below* the raw grep total means `strip_exempt_regions` is over-exempting and must be
  investigated before any purge phase runs.

- **Files to modify**:
  - `agent-system/extensions/core/scripts/check-task-references.sh` — new
  - `agent-system/extensions/core/manifest.json` — `provides.scripts` entry
  - `agent-system/extensions/core/scripts/verify-deploy.sh` — new gate 4
  - `agent-system/extensions/core/root-files/settings.local.json` — three permission entries

- **Verification**:
  - `bash -n` passes on both the new script and the edited `verify-deploy.sh`.
  - `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh --quiet`
    exits 1 and prints a summary (non-zero is CORRECT here — the tree is dirty).
  - Passing an unknown flag exits 2; temporarily renaming the shared library makes it exit 2, not 1.
  - `jq -e '.provides.scripts | index("check-task-references.sh")' agent-system/extensions/core/manifest.json`
    succeeds.
  - `grep -c 'check-task-references.sh' agent-system/extensions/core/root-files/settings.local.json`
    reports 3.
  - `bash agent-system/extensions/core/scripts/check-extension-docs.sh` still exits 0 (the new
    manifest entry must not trip Rule Q / Rule M).

---

### Phase 3: Agent contracts and the rule's Enforcement section [COMPLETED]

- **Goal:** Make the rule's second-layer enforcement claim true by adding the MUST-NOT bullet to
  the two core agents that actually author files outside `specs/**`, and rewrite the Enforcement
  section to describe the posture that now exists.

- **Tasks:**
  - [x] Append a MUST-NOT bullet to `agent-system/extensions/core/agents/general-implementation-agent.md`,
        as the next-numbered item after the existing `source-store-deploy-boundary.md` bullet in
        its `**MUST NOT**:` list. Reuse the cslib wording verbatim:
        `Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see .claude/rules/no-task-references-in-deliverables.md; reference durable anchors (filenames, section headings) instead`
  - [x] Same bullet, same insertion point, in
        `agent-system/extensions/core/agents/general-implementation-hard-agent.md`.
  - [x] Rewrite the `## Enforcement` section of
        `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` to three
        accurate layers:
        - **Repo-wide lint gate**: `check-task-references.sh`, exits non-zero on findings, wired
          as gate 4 of `verify-deploy.sh`.
        - **Write-time gate**: `validate-no-task-references.sh`, currently advisory PostToolUse
          (state this as the present truth; Phase 15 updates this one bullet).
        - **Agent contracts**: name the four files that carry the bullet —
          `general-implementation-agent.md`, `general-implementation-hard-agent.md`,
          `cslib-implementation-agent.md`, `cslib-implementation-hard-agent.md` — replacing the
          current vague and false "implementation agents that author files outside specs/**
          include a MUST NOT rule ... (see agent files below)".
  - [x] In the same section, state the tree boundary unambiguously: `specs/**` is the ONLY exempt
        tree; `agent-system/extensions/**`, `.opencode/**`, `lua/**`, and `.memory/**` are all
        deliverables subject to the rule.
  - [x] Record the known gap as a named follow-up in the rule (no task number — cite the agent
        filenames): extension implementation agents (`neovim-implementation-agent`,
        `nix-implementation-agent`, `email-implementation-agent`) also author outside `specs/**`
        and do not yet carry the bullet.

- **Timing:** 0.75 hours
- **Depends on:** 2
- **Verification Tier:** prose
- **Scope Hypothesis:** Asserts both target agent files currently contain **zero** task-number
  citations (verified this planning pass — only `planner-hard-agent.md` 1,
  `spawn-agent.md` 4, `meta-builder-agent.md` 13, `planner-agent.md` 2 do). Confirm with
  `grep -cEi "$TASK_PATTERN" agent-system/extensions/core/agents/general-implementation*agent.md`
  before editing; a non-zero count means the file changed and the purge scope for Phase 6 must be
  re-checked for overlap.

- **Files to modify**:
  - `agent-system/extensions/core/agents/general-implementation-agent.md` — one MUST NOT bullet
  - `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — same bullet
  - `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` —
    `## Enforcement` rewrite

- **Verification**:
  - `grep -c 'no-task-references-in-deliverables.md' ` on each of the two agent files reports ≥1.
  - The rule's Enforcement section no longer contains the string `(see agent files below)`.
  - The three named agent filenames appear literally in the rewritten Enforcement section.
  - The added bullets introduce no new citation: the new bullet text uses `"task N"` / `"tasks N-M"`
    with letter placeholders, which `TASK_PATTERN` does not match (it requires `[0-9]+`).

---

### Phase 4: Purge `agent-system/extensions/core/context/` [NOT STARTED]

- **Goal:** Clear the largest single subdirectory of the source store.
- **Character:** High judgment. Docs/context prose; each site needs a real
  PROVENANCE / ILLUSTRATIVE / SANCTIONED call.

- **Tasks:**
  - [ ] Enumerate sites with the Phase 2 script scoped to this tree.
  - [ ] Triage each: PROVENANCE → durable anchor (sibling filename, section heading, mechanism
        name, or a plain statement of the verified fact); ILLUSTRATIVE → documented placeholder
        (`task {N}`, `specs/{NNN}_{SLUG}/`, `sess_{timestamp}_{random}`); SANCTIONED → leave and
        add the marker with its reason.
  - [ ] Never delete a parenthetical that carries explanatory weight — convert it.

- **Timing:** 1.5 hours
- **Depends on:** 2
- **Verification Tier:** prose
- **Scope Hypothesis:** 147 occurrences / 31 files (sub-breakdown: `patterns/` 49/9,
  `orchestration/` 30/5, `formats/` 28/5, `workflows/` 18/2, `standards/` 12/4, remainder 10/6).
  Confirm with
  `grep -rcEi "$TASK_PATTERN" agent-system/extensions/core/context/ | awk -F: '{s+=$2} END {print s}'`
  before starting.
- **Files to modify**: all files under `agent-system/extensions/core/context/` reported by the scan.
- **Verification**: `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh`
  reports **0** findings under `agent-system/extensions/core/context/`. Expected delta: 147 → 0.

---

### Phase 5: Purge `agent-system/extensions/core/{docs,scripts}/` [NOT STARTED]

- **Goal:** Clear the two largest remaining core subdirectories.
- **Character:** Mixed. `docs/` is prose triage; `scripts/` citations are inside shell comments
  and are largely mechanical, but the edit must stay inside the comment.

- **Tasks:**
  - [ ] Triage and convert per the Phase 4 bucket rules.
  - [ ] For `scripts/`, confirm every changed hunk lies inside a `#` comment — do not touch
        executable lines. Note that `scripts/census-count.sh` references the hook's own regex in
        a comment; that reference must survive the edit intact.

- **Timing:** 1.5 hours
- **Depends on:** 2
- **Verification Tier:** local
- **Scope Hypothesis:** 121 occurrences / 24 files (`docs/` 70/12, `scripts/` 51/12). Confirm with
  `grep -rcEi "$TASK_PATTERN" agent-system/extensions/core/docs/ agent-system/extensions/core/scripts/ | awk -F: '{s+=$2} END {print s}'`.
- **Files to modify**: files under `agent-system/extensions/core/docs/` and
  `agent-system/extensions/core/scripts/` reported by the scan. **Excludes**
  `scripts/check-task-references.sh` and `scripts/lib/task-reference-patterns.sh` (created in
  Phases 1-2, already clean).
- **Verification**: scan reports 0 under both subdirectories (expected delta 121 → 0), and
  `bash -n` passes on every modified `.sh` file.

---

### Phase 6: Purge `agent-system/extensions/core/{skills,commands,agents,rules,hooks,merge-sources}/` [NOT STARTED]

- **Goal:** Clear the remaining core subdirectories, including both originally-named occurrences.
- **Character:** High judgment; contains the two sites the task description names explicitly.

- **Tasks:**
  - [ ] Handle the two named occurrences first, anchored on their quoted strings (both files are
        actively edited — re-confirm before editing):
        1. `commands/orchestrate.md`, cross-batch defense-in-depth passage of the runtime
           wave-split check — the parenthetical of the form
           `` `/orchestrate 785,787` where task 785 and task 787 were each created independently) have no creation-time ``.
           Prefer generic placeholders over real numbers; if the surrounding prose already conveys
           the cross-batch mechanism, restate without an example.
        2. `skills/skill-orchestrate/SKILL.md`, Stage 2 loop-guard fresh-start branch — the comment
           `` # Fresh start: create guard atomically via init-marker (task 808). A plain ``.
           Pure provenance; the durable anchor is the mechanism name (init-marker's mkdir-gate plus
           tmp-mv payload), which the surrounding comment already describes.
  - [ ] Triage and convert the remainder per the Phase 4 bucket rules.

- **Timing:** 1.5 hours
- **Depends on:** 2
- **Verification Tier:** prose
- **Scope Hypothesis:** 84 occurrences / 29 files, derived as the 205/53 core-non-context total
  minus the four files already owned by earlier phases (`rules/git-workflow.md` 3 and
  `rules/no-task-references-in-deliverables.md` 2 → Phase 1; the two
  `general-implementation*agent.md` files → Phase 3, contributing 0 citations) and minus
  `docs/`+`scripts/` (121/24 → Phase 5). Residual by subdirectory: `commands/` 28/7,
  `skills/` 25/11, `agents/` 20/4 (`meta-builder-agent.md` 13, `spawn-agent.md` 4,
  `planner-agent.md` 2, `planner-hard-agent.md` 1), `rules/artifact-formats.md` 1,
  `hooks/` 3/3, `merge-sources/` 2/1. Confirm the residual by running the Phase 2 script scoped
  to core and subtracting the phases already green.
- **Files to modify**: files under `agent-system/extensions/core/{skills,commands,agents,rules,hooks,merge-sources}/`
  reported by the scan. **Excludes** `rules/git-workflow.md`, `rules/no-task-references-in-deliverables.md`,
  `agents/general-implementation-agent.md`, `agents/general-implementation-hard-agent.md`.
- **Verification**: scan reports 0 under all six subdirectories (expected delta 84 → 0). Neither
  named occurrence's file still matches `TASK_PATTERN`. `bash -n` passes on
  `hooks/*.sh` if any hook file was edited.

---

### Phase 7: Purge `agent-system/extensions/literature/` [NOT STARTED]

- **Goal:** Clear the largest non-core extension.
- **Character:** Medium judgment; mostly docs and skill prose.

- **Tasks:**
  - [ ] Triage and convert per the Phase 4 bucket rules.

- **Timing:** 1.25 hours
- **Depends on:** 2
- **Verification Tier:** prose
- **Scope Hypothesis:** 94 occurrences / 26 files. Confirm with
  `grep -rcEi "$TASK_PATTERN" agent-system/extensions/literature/ | awk -F: '{s+=$2} END {print s}'`.
- **Files to modify**: files under `agent-system/extensions/literature/` reported by the scan.
- **Verification**: scan reports 0 under `agent-system/extensions/literature/`. Expected delta 94 → 0.

---

### Phase 8: Purge remaining `agent-system/extensions/` extensions [NOT STARTED]

- **Goal:** Clear the ten remaining non-core, non-literature extensions.
- **Character:** Mostly mechanical — many files carry a single provenance citation each — but the
  `email/` extension's citations sit in domain docs where the mechanism reference matters.

- **Tasks:**
  - [ ] Triage and convert per the Phase 4 bucket rules across `cslib`, `email`, `formal`,
        `founder`, `lean`, `memory`, `nix`, `nvim`, `present`, `web`.
  - [ ] `email/`'s known citation cluster (`tasks 823-824-827` in the index-freshness discussion)
        is the exact case the rule's own **After** example demonstrates — convert to the
        `wrapper-contracts.md` section reference, not a deletion.

- **Timing:** 1.25 hours
- **Depends on:** 2
- **Verification Tier:** prose
- **Scope Hypothesis:** 122 occurrences / 57 files (`email` 38/9, `founder` 21/20, `present` 18/6,
  `cslib` 11/3, `memory` 11/3, `web` 9/4, `nvim` 5/3, `formal` 4/4, `lean` 3/3, `nix` 2/2).
  Confirm as the `agent-system/extensions/` total (568) minus `core` (352) minus `literature` (94).
- **Files to modify**: files under those ten extension directories reported by the scan.
- **Verification**: scan reports 0 across `agent-system/extensions/` in its entirety once Phases
  4-8 are all green. Expected delta for this phase: 122 → 0.

---

### Phase 9: Purge `lua/**` [NOT STARTED]

- **Goal:** Clear the Neovim configuration tree.
- **Character:** **Mechanical/scriptable.** Almost entirely bare provenance comments; a scripted
  pass followed by agent review of the diff is appropriate here, unlike Phases 4-8.

- **Tasks:**
  - [ ] Convert each provenance comment to a durable anchor. Known shapes:
        `-- See: Task #41 - fix_leanls_lsp_client_exit_error`,
        `-- Per task 56: NO single-letter action mappings in email reader`,
        `--- Toggle all threads expand/collapse (Task #88)` (three further `Task #88` comments in
        `lua/neotex/plugins/tools/himalaya/config/ui.lua`).
  - [ ] Where the comment's only content is the task number, the durable form is the behavioral
        statement itself (`-- NO single-letter action mappings in email reader` stands alone);
        where the number qualifies a real constraint, name the constraint.
  - [ ] Confirm every changed hunk is inside a `--` comment. No executable Lua changes.

- **Timing:** 0.75 hours
- **Depends on:** 2
- **Verification Tier:** prose
- **Scope Hypothesis:** 32 occurrences / 13 files. Confirm with
  `grep -rcEi "$TASK_PATTERN" lua/ | awk -F: '{s+=$2} END {print s}'`.
- **Files to modify**: the 13 files under `lua/` reported by the scan.
- **Verification**: scan reports 0 under `lua/` (expected delta 32 → 0). Every modified module
  still loads: `nvim --headless -c "lua require('<module>')" -c "q"` for each edited module, per
  the neovim-lua rule's verification convention.

---

### Phase 10: Purge `.memory/**` [NOT STARTED]

- **Goal:** Clear the memory vault. `.memory/**` is deliverables — settled decision, not
  re-litigated, and NOT added to the exemption list.
- **Character:** **Mechanical.** Agent-authored memory bodies, one or two citations each.

- **Tasks:**
  - [ ] Convert provenance in each memory body to a durable anchor. A memory that says
        "discovered during task N" becomes a statement of what was discovered plus the durable
        artifact/mechanism it concerns.
  - [ ] Do not alter memory frontmatter/metadata semantics; only the prose body.
  - [ ] Record the standing hazard for Phase 15: the vault re-accumulates citations unless the
        write-time gate covers the path memories are actually written through.

- **Timing:** 0.75 hours
- **Depends on:** 2
- **Verification Tier:** prose
- **Scope Hypothesis:** 18 occurrences / 17 files, all in `10-Memories/*.md` bodies. Confirm with
  `grep -rcEi "$TASK_PATTERN" .memory/ | awk -F: '{s+=$2} END {print s}'`.
- **Files to modify**: the 17 files under `.memory/` reported by the scan.
- **Verification**: scan reports 0 under `.memory/` (expected delta 18 → 0). `memory-index.json`
  validate-on-read still regenerates cleanly (no structural change was made, so this is a
  no-regression check).

---

### Phase 11: Purge `.opencode/extensions/core/` [NOT STARTED]

- **Goal:** Clear the largest single `.opencode` subdirectory.
- **Character:** High judgment. **Edited directly in place** — `.opencode/**` is a git-tracked,
  hand-maintained port, NOT generated from `agent-system/`. Do not route these fixes through
  `agent-system/`.
- **Note:** Many sites mirror ones already fixed in Phases 4-6. Reuse the same durable anchors for
  parity, but re-triage each site — the port has drifted and is not a byte-copy.

- **Tasks:**
  - [ ] Triage and convert per the Phase 4 bucket rules.

- **Timing:** 1.5 hours
- **Depends on:** 2
- **Verification Tier:** prose
- **Scope Hypothesis:** 199 occurrences / 50 files. Confirm with
  `grep -rcEi "$TASK_PATTERN" .opencode/extensions/core/ | awk -F: '{s+=$2} END {print s}'`.
- **Files to modify**: files under `.opencode/extensions/core/` reported by the scan.
- **Verification**: scan reports 0 under `.opencode/extensions/core/`. Expected delta 199 → 0.

---

### Phase 12: Purge remaining `.opencode/extensions/` extensions [NOT STARTED]

- **Goal:** Clear the eight non-core `.opencode` extensions.
- **Character:** **Mostly mechanical** — small per-file counts, largely mirroring Phase 8.

- **Tasks:**
  - [ ] Triage and convert across `formal`, `founder`, `lean`, `memory`, `nix`, `nvim`, `present`,
        `web`.

- **Timing:** 1 hour
- **Depends on:** 2
- **Verification Tier:** prose
- **Scope Hypothesis:** 76 occurrences / 45 files (`founder` 20/19, `present` 18/6, `web` 13/6,
  `memory` 11/3, `nvim` 5/3, `formal` 4/4, `nix` 4/3, `lean` 1/1). Confirm as the
  `.opencode/extensions/` total (275) minus `core` (199).
- **Files to modify**: files under those eight `.opencode/extensions/` directories reported by the scan.
- **Verification**: scan reports 0 across `.opencode/extensions/` in its entirety once Phases 11-12
  are green. Expected delta for this phase: 76 → 0.

---

### Phase 13: Purge `.opencode/context/{core,formats}/` [NOT STARTED]

- **Goal:** Clear the two largest `.opencode/context` subdirectories.
- **Character:** High judgment; context prose.

- **Tasks:**
  - [ ] Triage and convert per the Phase 4 bucket rules.

- **Timing:** 1.25 hours
- **Depends on:** 2
- **Verification Tier:** prose
- **Scope Hypothesis:** 104 occurrences / 26 files (`core/` 72/19, `formats/` 32/7). Confirm with
  `grep -rcEi "$TASK_PATTERN" .opencode/context/core/ .opencode/context/formats/ | awk -F: '{s+=$2} END {print s}'`.
- **Files to modify**: files under `.opencode/context/core/` and `.opencode/context/formats/`
  reported by the scan.
- **Verification**: scan reports 0 under both subdirectories. Expected delta 104 → 0.

---

### Phase 14: Purge the rest of `.opencode/**` [NOT STARTED]

- **Goal:** Clear every remaining `.opencode` subdirectory.
- **Character:** Mixed — `context/orchestration` and `context/patterns` need judgment; `scripts`,
  `hooks`, `rules` are comment-level and mechanical.

- **Tasks:**
  - [ ] Triage and convert across `.opencode/context/{orchestration,patterns,standards,workflows,architecture,meta,project,reference,templates}/`
        and `.opencode/{docs,skills,agent,commands,scripts,hooks,rules}/`.
  - [ ] `.opencode/hooks/` contains the port's own copy of the advisory hook — purge its comment
        citations only. Do NOT port the blocking flip here (explicit Non-Goal).
  - [ ] Confirm shell edits stay inside `#` comments.

- **Timing:** 1.5 hours
- **Depends on:** 2
- **Verification Tier:** local
- **Scope Hypothesis:** 229 occurrences / 63 files — `.opencode/context` residual 106/24
  (`orchestration` 30/5, `patterns` 29/6, `workflows` 18/2, `standards` 12/4, and 5 single-file
  subdirectories totalling 10/6, plus `architecture` 2/1) plus `.opencode/{docs,skills,agent,commands,scripts,hooks,rules}`
  123/39. Confirm as the `.opencode/` total (610) minus `extensions/` (275) minus
  `context/{core,formats}` (104).
- **Files to modify**: all remaining `.opencode/` files reported by the scan.
- **Verification**: scan reports 0 across `.opencode/` in its entirety (expected delta 229 → 0),
  and `bash -n` passes on every modified `.sh` file.

---

### Phase 15: Flip the write-time hook to blocking [NOT STARTED]

- **Goal:** Convert `validate-no-task-references.sh` from an advisory PostToolUse hook to a
  blocking PreToolUse gate using exit code 2, with full test coverage. This is the last phase and
  must run against a tree the lint script has already certified clean.

- **Precondition (a literal gate, re-run at the start of this phase — not inherited from earlier
  phases):**
  `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh` exits **0**.
  If it exits 1, stop and re-open the phase whose tree still reports findings. A blocking gate is
  never switched on against a known-dirty tree.

- **Tasks:**
  - [ ] Rewrite `agent-system/extensions/core/hooks/validate-no-task-references.sh`:
        - Source `lib/task-reference-patterns.sh`; **delete** the inline `TASK_SEP`,
          `TASK_PATTERN`, `PHASE_PATTERN` assignments and the inline `case "$FILE" in specs/*|*/specs/*)`
          block, replacing them with `is_exempt_path` and `strip_exempt_regions` calls. After this
          phase, no pattern is defined outside the shared library.
        - Parse PreToolUse input (`.tool_input.file_path`, `.tool_input.content // .tool_input.new_string`)
          — the same shape the current PostToolUse parser reads, with the same `CLAUDE_TOOL_INPUT`
          env fallback.
        - On a match: write the guidance message to **stderr** and `exit 2`.
          **Use exit code 2, NOT `permissionDecision: "deny"`** — `settings.json`'s
          `permissions.allow` contains bare `"Write"` and `"Edit"` entries, the documented
          precondition under which `permissionDecision: deny` is ignored. This mirrors
          `guard-destructive-git.sh`, which blocks via exit 2 for exactly this reason.
        - On no match, or on an unresolvable `file_path`, or on empty content: exit 0 silently.
        - If the shared library cannot be sourced, exit 0 with a stderr warning — a broken guard
          must fail open, never block every write in the repo.
  - [ ] **Registration** — two edits, and the wrapper form is load-bearing:
        - Remove the `validate-no-task-references.sh` entry from `hooks.PostToolUse`'s
          `Write|Edit` matcher in `agent-system/extensions/core/merge-sources/settings-hooks.json`
          (leave `validate-handoff-location.sh` and `validate-meta-write.sh` in place).
        - Add a `PreToolUse` entry with matcher `Write|Edit` to
          `agent-system/extensions/core/root-files/settings.json`, using the **bare** command form
          `bash .claude/hooks/validate-no-task-references.sh` — exactly as
          `guard-destructive-git.sh` is registered there.
          **MUST NOT** use the `2>/dev/null || echo '{}'` wrapper the PostToolUse registration
          uses: the `||` converts exit 2 into exit 0 and silently disables the block. This is the
          single most likely way this phase ships broken.
  - [ ] **Extend `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh`**
        (the CORRECTED path; the task description's `hooks/tests/` path does not exist). Preserve
        its existing convention: `pass()`/`fail()`/`info()` helpers, `mktemp -d` isolation, the
        hook driven as a real subprocess via a synthetic JSON payload on stdin, never instrumented.
        Add:
        - **Deny-path assertions**: replace/extend the `additionalContext`-presence assertion with
          an **exit-code** assertion. Every existing positive fixture must now assert exit 2 and
          non-empty stderr; every negative fixture must assert exit 0.
        - **One fixture per exemption category** (the suite currently has zero):
          1. `specs/**` path exemption (2 fixtures exist; keep, re-assert on exit code).
          2. Commit-convention example in a `task-ref-ok:begin/end` region → exit 0.
          3. **The `git-workflow.md` self-hit as an explicit named test case**: content containing
             `task 259 phase 2: implement modal semantics evaluator` inside a marked region → exit
             0; the identical line *unmarked* → exit 2. This pair is the taxonomy's regression
             anchor — the file defining the sanctioned convention must not be indistinguishable
             from a violation.
          4. Command-usage example (`/research 7, 22-24, 59`) marked → exit 0; unmarked → exit 2.
          5. Quoted historical anti-pattern marked → exit 0.
          6. Placeholder-bearing prose (`task {N}`, `specs/{NNN}_{SLUG}/`) with no marker → exit 0
             (guards against a future pattern broadening that would catch placeholders).
        - **Shared-library-missing fixture**: hook exits 0 (fail-open), not 2.
  - [ ] **Empirically verify `.memory/**` write-path coverage before claiming it.** `memory-harvest.sh`
        writes via a Bash heredoc (`cat > "$mem_file" <<MEMEOF`), which a `Write|Edit`-matcher
        PreToolUse hook structurally cannot see — but that script documents itself as presently
        uncalled. Inspect `skill-todo`'s inline harvest logic (the live path) and determine whether
        it uses the `Write` tool or a heredoc. If it is a heredoc, record the gap explicitly in the
        rule's Enforcement section as an uncovered write path; do not silently claim coverage.
  - [ ] Update the **Write-time gate** bullet in the rule's `## Enforcement` section (written in
        Phase 3) from "advisory PostToolUse" to "blocking PreToolUse, exit code 2", and record the
        `.memory/**` finding from the previous task.
  - [ ] Redeploy and verify: `bash agent-system/extensions/core/scripts/deploy-headless.sh`, then
        `bash agent-system/extensions/core/scripts/verify-deploy.sh` — gate 4 must exist and pass,
        and gate 2 (hook registrations) must show the PreToolUse entry present exactly once.

- **Timing:** 2.5 hours
- **Depends on:** 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
- **Verification Tier:** full
- **Commit Mode:** atomic-batch
- **Scope Hypothesis:** Asserts the test suite currently has 10 positive, 7 negative, 2
  `specs/**`-exemption, and 2 degenerate-input fixtures, and zero exemption-category fixtures.
  Confirm by counting `pass`/`fail` call sites and reading the fixture list before editing; the
  suite is 139 lines today and is actively edited.

- **Files to modify**:
  - `agent-system/extensions/core/hooks/validate-no-task-references.sh` — PreToolUse + exit 2 +
    library sourcing, inline patterns deleted
  - `agent-system/extensions/core/merge-sources/settings-hooks.json` — remove the PostToolUse entry
  - `agent-system/extensions/core/root-files/settings.json` — add the bare PreToolUse entry
  - `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` — exit-code
    assertions + one fixture per exemption category + the `git-workflow.md` self-hit pair
  - `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` — Enforcement
    write-time-gate bullet + `.memory/**` coverage finding

- **Verification**:
  - `bash agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` exits 0
    with every new fixture reporting PASS.
  - `grep -c 'TASK_PATTERN=' agent-system/extensions/core/hooks/validate-no-task-references.sh`
    reports **0** — the pattern lives only in the shared library.
  - The PreToolUse registration in `root-files/settings.json` contains no `||` and no `2>/dev/null`.
  - `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh --quiet`
    exits **0** across all four trees.
  - `bash agent-system/extensions/core/scripts/verify-deploy.sh` reports PASS on gates 1-4.
  - Live smoke test: attempt a `Write` of a scratch file (outside `specs/**`) containing an
    unmarked `task 123` — the tool call is blocked; the same content inside a
    `task-ref-ok:begin/end` region writes successfully.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` exits 0.
- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh` exits 0
      across `agent-system/extensions/**`, `.opencode/**`, `lua/**`, `.memory/**`.
- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0 (no new manifest
      or drift failures introduced by the two new scripts).
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh` reports PASS on gates 1-4.
- [ ] `bash -n` passes on every modified `.sh` file.
- [ ] Every modified Lua module loads headlessly.
- [ ] Live smoke test of the blocking gate (deny path and marked-exempt path).
- [ ] `specs/**` is untouched: `git status --short specs/` shows only this task's own artifacts.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` (new — shared library)
- `agent-system/extensions/core/scripts/check-task-references.sh` (new — repo-wide lint)
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` (exemption taxonomy +
  rewritten Enforcement section)
- `agent-system/extensions/core/hooks/validate-no-task-references.sh` (blocking PreToolUse, exit 2)
- `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` (extended suite)
- `agent-system/extensions/core/manifest.json`, `scripts/verify-deploy.sh`,
  `root-files/settings.json`, `root-files/settings.local.json`,
  `merge-sources/settings-hooks.json` (wiring)
- ~385 deliverable files across four trees with citations converted to durable anchors
- `specs/941_purge_and_enforce_no_task_references/summaries/01_purge-and-enforce-task-references-summary.md`

## Rollback/Contingency

- Every phase commits independently (`per-substep` except the three `atomic-batch` phases), so any
  single tree's purge is revertible with `git revert` of that phase's commit without disturbing
  the others.
- **If the blocking gate false-positives after Phase 15** and blocks legitimate work: the fastest
  safe rollback is to revert the `root-files/settings.json` PreToolUse entry and redeploy, which
  returns the repo to an ungated state without touching the purge. Correct the taxonomy in the
  shared library, then re-apply.
- **Never** roll back by weakening `TASK_PATTERN` — an over-broad pattern is a taxonomy problem
  fixed in `strip_exempt_regions` and the rule's taxonomy table, not a pattern problem.
- Because this task edits orchestrator-critical paths, run `git-snapshot.sh 941` before any
  intentional destructive rollback; the `guard-destructive-git.sh` hook blocks `git reset --hard`
  on a dirty tree without one.

## Deliverable Rule Compliance

This plan lives under `specs/**` and may cite task 941. Its **deliverables** must not: every file
this plan touches outside `specs/**` must reference durable anchors (filenames, section headings,
mechanism names) rather than this task's number. Commit messages are exempt and use the sanctioned
`task 941: ...` convention.
