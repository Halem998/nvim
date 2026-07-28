# Implementation Plan: picker_sync_skills_allow_list_filter

- **Task**: 938 - picker_sync_skills_allow_list_filter
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/938_picker_sync_skills_allow_list_filter/reports/01_skills-allow-list-post-filter-defect.md`
- **Artifacts**: plans/01_skills-allow-list-filter-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  `.claude/rules/neovim-lua.md`, `.claude/rules/no-task-references-in-deliverables.md`
- **Type**: neovim
- **Lean Intent**: false

## Overview

The picker sync's allow-list post-filter in `sync_scan()` (inside `M.scan_all_artifacts`,
`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`) looks up
`allowed[file_info.name]` — a **basename** — against an allow-list keyed by the strings in the
core manifest's `provides.<category>` array. For `skills`, those strings are **directory** names
(`skill-orchestrate`, …) while every scanned file's basename is the literal `"SKILL.md"`, so the
filter returns an empty set and no skill is ever deployed. The fix generalizes the existing
`filter_category == "context"` directory-matching branch — which already solves exactly this
shape — so it applies to every category, with a basename fallback that preserves today's
behavior wherever the generalized match does not apply. The task additionally requires a
zero-result defect detector so this class of silent wipeout is never invisible again, a
permanent regression spec, and one deliberate end-to-end redeploy.

Definition of done: the defect is empirically reproduced and then empirically un-reproduced
against a scratch tree; all 23 `provides.skills` entries land in `.claude/skills/` after one
deliberate redeploy; the two previously hand-corrected orchestrator skills are byte-identical to
their source-store originals afterwards; and a total allow-list wipeout emits a WARN.

### Research Integration

Integrated from `reports/01_skills-allow-list-post-filter-defect.md`:
- Root cause confirmed empirically (scratch-tree run: `skills found: 0`, `commands found: 1`,
  `agents found: 1`), not merely read-verified. That run is the required before-state.
- `M.scan_all_artifacts(global_dir, project_dir, config)` is a pure, public, non-mutating entry
  point (writes live in `execute_sync`/`sync_files`, reached only via `M.load_all_globally`), so
  it is the safe reproduction/regression entry point.
- Scratch trees must mirror `<scratch>/agent-system/extensions/core/manifest.json` plus category
  subdirectories, because `get_extension_config()` resolves `global_extensions_dir` to
  `global_dir .. "/agent-system/extensions"`.
- Category survey: `skills` and `context` are directory-shaped; `agents`, `commands`, `rules`,
  `hooks`, `scripts` are flat-file-shaped; `docs`, `templates`, `systemd` receive no
  `filter_category` at all and stay unfiltered by design.
- `scripts/tests/*.sh` and `scripts/lint/*.sh` exist on disk but are absent from
  `provides.scripts`. Same *symptom family*, different *mechanism* (undeclared, not mis-keyed).
  Explicitly out of scope here — recorded as a follow-up candidate, not folded in.
- Zero-result detector should trigger only on total wipeout (`#results > 0 and #filtered == 0`),
  non-blocking, via the already-required `helpers.notify`.
- `scan_spec.lua` is the sole in-repo precedent for scratch-tree specs
  (`describe`/`it`/`before_each`/`after_each` + `vim.fn.tempname()`); no `sync_spec.lua` exists.

**One material correction to the research, carried into Phase 3.** The report asserts the
invariant "every call site that passes a `filter_category` also passes that same string as the
`subdir` argument" and recommends anchoring the generalized match on `filter_category`. That
invariant is **false** at one call site: `artifacts.agents = sync_scan(agents_subdir, "*.md",
true, nil, "agents")`, where `agents_subdir` is `(config and config.agents_subdir) or "agents"`
and resolves to `"agent/subagents"` for `base_dir == ".opencode"` (see
`lua/neotex/plugins/ai/shared/extensions/config.lua` and the assertions in
`lua/neotex/plugins/ai/shared/picker/config_spec.lua`). Anchoring on `filter_category` would
build the pattern `/agents/(.+)$`, which cannot match a path under `agent/subagents/`, silently
dropping every OpenCode agent — a brand-new instance of the very defect being fixed. The plan
therefore anchors on the **`subdir`** argument (in scope inside `sync_scan`, and always the
directory actually scanned) and requires a basename fallback when the match fails.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` was not provided in the delegation context and no roadmap phases were
requested; no roadmap items are claimed by this plan.

## Goals & Non-Goals

**Goals**:
- Reproduce the skills-drop defect against an isolated scratch tree and record the before-state
  (scope item A).
- Fix the allow-list post-filter so directory-shaped categories match on directory name, without
  changing `context` behavior and without weakening the allow-list into a pass-through (item B).
- Establish by inspection which categories are directory-shaped rather than assuming `skills` is
  unique (item C).
- Make a total allow-list wipeout non-silent via a non-blocking WARN (item D).
- Verify end to end against a scratch tree, then perform exactly one deliberate redeploy and
  confirm every `provides.skills` entry lands in `.claude/skills/`, with the hand-corrected
  orchestrator skills not reverted (item E).
- Leave a permanent regression spec so the defect cannot silently return.

**Non-Goals**:
- Editing `agent-system/extensions/**` or `.claude/**` by hand. The single deliberate redeploy in
  Phase 6 writes `.claude/` through the sanctioned deploy process only.
- Declaring `scripts/tests/*.sh` / `scripts/lint/*.sh` in `provides.scripts`, or otherwise
  resolving that omission — a product decision, recorded as a follow-up.
- Wiring `docs`, `templates`, or `systemd` into the allow-list. They are unfiltered by design and
  read only from core sources.
- Any change to `manifest.build_allow_list()` keying, or to `scan_directory_for_sync()`'s `name`
  field. Both are correct for their own consumers; the mismatch is resolved at the lookup site.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Anchoring the generalized match on `filter_category` silently drops all OpenCode agents (`agents_subdir == "agent/subagents"`) | H | H if research followed verbatim | Anchor on the `subdir` argument instead; Phase 3 verification asserts a simulated `agents_subdir = "agent/subagents"` case still passes |
| A future call site where the generalized pattern does not match causes another silent total drop | H | M | Mandatory basename fallback when the match fails (degrades to today's behavior), plus the Phase 4 wipeout detector as the safety net, plus an explicit invariant comment at the branch |
| `context` behavior changes as a side effect | H | L | Phase 3 verification includes an explicit `context`-shaped scratch case asserting byte-identical selection to pre-change behavior; the match construction and leftmost-`match` semantics are preserved verbatim |
| Zero-result detector fires on legitimate partial exclusions, training users to ignore it | M | M | Trigger strictly on `#results > 0 and #filtered == 0`; Phase 4 verification includes a partial-exclusion case asserting no warning |
| A `subdir` containing Lua pattern magic characters corrupts the match | M | L | Escape the interpolated `subdir` with `vim.pesc()` before building the pattern |
| The deliberate redeploy reverts the hand-corrected orchestrator skills to stale content | H | L | Phase 6 diffs both `SKILL.md` files against their `agent-system/extensions/core/skills/…` sources before AND after the redeploy; a post-redeploy diff must be empty |
| Reproduction fails, i.e. the diagnosis does not hold | H | L (already reproduced once in research) | Phase 1 is a hard gate: if reproduction fails, STOP, record that the diagnosis did not hold, and do not force the fix |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 3 and 4 edit the same region of
`sync.lua` and are deliberately serialized.

---

### Phase 1: Reproduce the defect against a scratch tree [COMPLETED]

**Goal**: Empirically observe and record the before-state — skills dropped to zero while flat
categories pass — without touching the live `.claude/` or `agent-system/` trees.

**Tasks**:
- [x] Write a self-contained reproduction script under the session scratchpad directory that
      builds an isolated tree rooted at `vim.fn.tempname()` containing
      `agent-system/extensions/core/manifest.json` (with `provides.skills` naming two skill
      directories, `provides.commands` one flat `.md`, `provides.agents` one flat `.md`) plus the
      matching `skills/<dir>/SKILL.md`, `commands/*.md`, and `agents/*.md` files.
- [x] Call the unmodified public `M.scan_all_artifacts(scratch_root, project_dir, { base_dir =
      ".claude" })` and print post-filter counts for `skills`, `commands`, and `agents`.
- [x] Run headless (`nvim --headless -c "luafile <script>" -c "qa!"`) and capture the output
      verbatim as the recorded before-state.
- [x] Have the script delete its own scratch tree on exit.
- [x] **HARD GATE**: if skills do NOT come back zero, STOP the task, record in the summary that
      the read-verified diagnosis did not hold, and do not proceed to Phase 3. *(gate passed:
      captured output was `REPRO_RESULT skills=0 commands=1 agents=1`, matching the hypothesis
      exactly)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Hypothesis — the run reports `skills: 0`, `commands: 1`, `agents: 1`.
Confirm by reading the actual captured stdout, not by assuming the research report's numbers;
record whatever is observed. Any other result triggers the hard gate above.

**Files to modify**:
- Session scratchpad reproduction script (temporary, not a repository file) - new
- No repository source file is edited in this phase

**Verification**:
- The captured headless output is pasted verbatim into the phase's progress notes.
- `git status --short` shows no modification under `lua/`, `agent-system/`, or `.claude/`.

---

### Phase 2: Category shape survey [COMPLETED]

**Goal**: Establish by inspection — not assumption — which categories passed into the post-filter
are directory-shaped versus flat-file-shaped, so the fix's blast radius is known before it lands
(scope item C).

**Tasks**:
- [x] Enumerate every `sync_scan(...)` invocation in `M.scan_all_artifacts` and record, for each,
      the `subdir` argument and the `filter_category` argument (including the ones that pass
      `nil`).
- [x] For each category that receives a non-nil `filter_category`, read the corresponding
      `provides.<category>` array in `agent-system/extensions/core/manifest.json` and classify the
      entries as directory names or file basenames.
- [x] Cross-check each classification against the on-disk layout under
      `agent-system/extensions/core/<category>/` (does the entry name a directory or a file?).
- [x] Record explicitly which call sites have `subdir ~= filter_category` — this set determines
      why the fix anchors on `subdir`.
- [x] Record the `scripts/tests/` + `scripts/lint/` undeclared-file finding as an out-of-scope
      follow-up candidate; do not act on it.

**Survey results** (re-derived from current source and manifest at implementation time; confirms
the plan's hypothesis exactly — 7 categories, 2 directory-shaped, 1 `subdir ~= filter_category`
call site):

| `subdir` arg | `filter_category` | `provides.<cat>` entry shape | Classification |
|---|---|---|---|
| `"commands"` | `"commands"` | e.g. `"errors.md"` (matches on-disk file) | flat |
| `agents_subdir` (`"agents"` for `.claude`; `"agent/subagents"` for `.opencode`) | `"agents"` | e.g. `"planner-agent.md"` (matches on-disk file) | flat |
| `"skills"` (x2: `*.md`, `*.yaml`) | `"skills"` | e.g. `"skill-orchestrate"` (matches on-disk **directory**, file is `skill-orchestrate/SKILL.md`) | **directory** |
| `"hooks"` | `"hooks"` | e.g. `"guard-destructive-git.sh"` (matches on-disk file) | flat |
| `"scripts"` | `"scripts"` | e.g. `"archive-task.sh"` (matches on-disk file) | flat |
| `"rules"` | `"rules"` | e.g. `"git-workflow.md"` (matches on-disk file) | flat |
| `"context"` (x3: `*.md`, `*.json`, `*.yaml`) | `"context"` | e.g. `"formats"`, `"architecture"` (on-disk **directories**; plus a few flat files like `"README.md"`, `"routing.md"`) | **directory** (mixed with a handful of flat top-level files, already handled by the pre-existing `context` special case) |

Categories scanned with `filter_category == nil` (unfiltered by design, out of this survey's
scope): the one-off OpenCode `orchestrator.md` scan, `templates` (x2), `docs`, `systemd` (x2),
`lib`, `tests`, `settings.json`. Confirms 7 filter_category-bearing categories total: `commands`,
`agents`, `skills`, `hooks`, `scripts`, `rules`, `context`.

**`subdir ~= filter_category` set**: exactly one call site — `artifacts.agents = sync_scan(agents_subdir, "*.md", true, nil, "agents")`, where `agents_subdir` resolves to the literal string `"agent/subagents"` for OpenCode (`config.agents_subdir` from `shared/extensions/config.lua`'s `M.opencode()` preset), diverging from the literal `filter_category` string `"agents"`. No other call site diverges.

**Out-of-scope follow-up candidate** (re-verified at implementation time; corrects a stale
premise in the research integration above): `scripts/tests/*.sh` (3 files) and
`scripts/lint/*.sh` (2 files) exist on disk under `agent-system/extensions/core/scripts/` and
ARE now declared in `provides.scripts` — as path-prefixed strings (`"tests/test-census-count.sh"`,
`"lint/lint-contract-compliance.sh"`, etc.), not the bare `"undeclared"` state the research
report assumed. A live, read-only `M.scan_all_artifacts` call against the real repo confirms
these 5 files still do not sync today (`scripts` count = 62 = exactly the flat top-level scripts,
zero nested files pass). This is because neither half of the Phase 3 fix matches a full
relative-path provides key: the subdir-anchored directory match would need `allowed["tests"]`
(only the full string `"tests/test-census-count.sh"` is a key, not the bare `"tests"` segment),
and the basename fallback would need `allowed["test-census-count.sh"]` (only the prefixed form is
a key). This is a third, distinct mismatch mechanism (full relative path vs. basename-only
lookup) — different from both the directory-name mechanism (skills) and the flat-basename
mechanism (agents/commands/etc.) this task fixes, and the fix in Phase 3 does not resolve it.
Left out of scope per the plan's Non-Goals; recorded precisely here and in the Phase 6 summary as
a follow-up candidate, corrected from the research's "absent" framing to "declared but still
excluded by a third mismatch mechanism."

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: Hypothesis — exactly 7 categories receive a non-nil `filter_category`; of
those, `skills` and `context` are directory-shaped and `agents`, `commands`, `rules`, `hooks`,
`scripts` are flat; and exactly one call site has `subdir ~= filter_category` (the OpenCode
`agents_subdir` case). Confirm by re-deriving all three counts from the current source and
manifest at implementation time and recording any divergence, rather than restating these
numbers. Divergence widens Phase 3's test matrix; it does not by itself block the fix.

**Files to modify**:
- None (read-only survey; findings are recorded in the phase notes and carried into the summary)

**Verification**:
- A written table exists covering every `filter_category`-bearing call site with its `subdir`,
  its `provides` entry shape, and its directory-vs-flat classification.
- The `subdir ~= filter_category` set is enumerated explicitly.

---

### Phase 3: Generalize the allow-list post-filter [COMPLETED]

**Goal**: Replace the `filter_category == "context"` special case with a single generalized
directory-name rule anchored on the scanned `subdir`, with a basename fallback, so `skills`
matches correctly and every other category's behavior is preserved (scope item B).

**Tasks**:
- [x] In `sync_scan`'s allow-list post-filter, remove the `filter_category == "context"` branch
      and its `else` basename branch, replacing both with one rule: extract the relative path via
      `file_info.global_path:match("/" .. vim.pesc(subdir) .. "/(.+)$")`, take its first path
      segment as `top_dir`, and admit the file when `allowed[top_dir]` is set.
- [x] Add the basename fallback: when the match yields no `rel_path` (or no `top_dir`), fall back
      to the current `allowed[file_info.name]` check so a call site whose `subdir` does not appear
      in the path degrades to today's behavior instead of dropping everything.
- [x] Escape the interpolated `subdir` with `vim.pesc()` (it may contain `/` and must never be
      interpreted as a Lua pattern).
- [x] Add a comment at the branch stating the anchor invariant explicitly: the pattern is built
      from `subdir`, not `filter_category`, because they diverge for OpenCode agents
      (`agents_subdir == "agent/subagents"`), and the basename fallback exists so a future
      divergence degrades rather than silently wipes the category.
- [x] Keep the surrounding `if allow_list and filter_category and allow_list[filter_category]`
      guard and the `return filtered` shape unchanged — the allow-list must not become a
      pass-through. *(verified: an undeclared skill dir and an undeclared command file were added
      to the Phase 3 harness scratch tree and confirmed excluded)*
- [x] Re-run the Phase 1 harness against the same scratch shape and confirm skills now pass.
      *(2 declared skills now pass, was 0; commands=1, agents=1 unchanged)*
- [x] Extend the harness with a `context`-shaped case (a nested `context/<dir>/file.md` plus a
      flat top-level file declared in `provides.context`) and confirm selection is unchanged
      from the pre-fix behavior. *(2 files pass: 1 nested under a declared directory, 1 flat
      top-level; an undeclared nested directory is excluded)*
- [x] Extend the harness with a simulated OpenCode case (`config.agents_subdir =
      "agent/subagents"`, files under `agent/subagents/*.md`, `filter_category "agents"`) and
      confirm agents still pass. *(1 declared OpenCode agent passes)*
- [x] Honor Lua standards: 2-space indent, ~100-char lines, snake_case, no task-number references
      in any file outside `specs/**`.

**Verification results**: all three scratch-tree harness cases (`skills_and_flat_claude`,
`context_selection_unchanged`, `opencode_agents_subdir_divergence`) pass. Module loads headless.
`git diff --stat` confirms exactly one file modified under `lua/`:
`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (no `M.`-prefixed signature
changed — `sync_scan` remains a file-local closure). `scan_spec.lua` still passes 19/19.

**Timing**: 1 hour

**Depends on**: 1, 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Hypothesis — this is a single-file, single-function change confined to
`sync.lua`'s `sync_scan` post-filter, with no change to any externally visible signature
(`sync_scan` is a file-local closure). Confirm at implementation time by checking `git diff
--stat` shows exactly one modified file and that no `M.`-prefixed signature changed; if the change
must reach `manifest.lua` or `scan.lua`, stop and re-scope rather than widening silently.

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - generalize the allow-list
  post-filter inside `sync_scan`; add the anchor-invariant comment and the basename fallback

**Verification**:
- Module loads: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.operations.sync')" -c "qa!"` exits clean.
- Harness: skills case now returns the declared count (was 0); commands and agents unchanged.
- Harness: `context` case selection identical to the pre-fix run.
- Harness: simulated `agent/subagents` case still returns its declared agents.
- Existing `lua/neotex/plugins/ai/claude/commands/picker/utils/scan_spec.lua` still passes.

---

### Phase 4: Zero-result wipeout detector [COMPLETED]

**Goal**: Make a total allow-list wipeout non-silent — the signature that would have caught this
defect years earlier (scope item D).

**Tasks**:
- [x] Inside `sync_scan`, immediately after `filtered` is built and before `return filtered`, add
      the check: if `#results > 0 and #filtered == 0`, emit a non-blocking `helpers.notify(...,
      "WARN")`.
- [x] Word the message so it names the category, the dropped count, and the actionable cause:
      that a working allow-list still passes some declared files through, so a total wipeout means
      the lookup key (directory name vs. basename) likely does not match the `provides.<category>`
      entries. Do not reference task numbers (the file lives outside `specs/**`).
- [x] Confirm the detector never mutates state, never blocks the scan, and never changes the
      returned value — it reports only.
- [x] Use the already-required `helpers` module; add no new dependency.
- [x] Verify no false positive on partial exclusion: a scratch case where some files are declared
      and some are not must produce a non-empty `filtered` and no warning.
- [x] Verify the true-positive path by temporarily feeding the harness a manifest whose
      `provides.skills` entries match nothing on disk, confirming exactly one WARN fires.

**Verification results**: three scratch-tree cases via a `helpers.notify` capture stub —
`normal_all_declared_present` (0 warnings), `partial_exclusion_no_warning` (1 skill admitted, 0
warnings), `total_wipeout_one_warning` (0 skills admitted, exactly 1 WARN naming `skills` and the
dropped count `1`). Module still loads headless; no repository file outside `sync.lua` (plus this
plan) was touched.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Hypothesis — after Phase 3, no currently-shipping category triggers the
detector during a real scan. Confirm during the Phase 6 redeploy: any WARN observed there is a
genuine finding to investigate, not detector noise to suppress.

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - add the wipeout detector
  inside `sync_scan`

**Verification**:
- Partial-exclusion scratch case: non-empty result, zero warnings.
- Total-wipeout scratch case: exactly one WARN naming the category and the dropped count.
- Normal scratch case (all declared files present): zero warnings.
- Module still loads headless.

---

### Phase 5: Permanent regression spec [NOT STARTED]

**Goal**: Codify the scratch-tree reproduction as an in-repo spec so the defect and the detector
are both covered by the test suite going forward.

**Tasks**:
- [ ] Create `lua/neotex/plugins/ai/claude/commands/picker/operations/sync_spec.lua` following the
      existing `scan_spec.lua` convention: `describe`/`it`/`before_each`/`after_each`,
      `vim.fn.tempname()` + `vim.fn.mkdir(..., "p")` + `vim.fn.writefile`, tearing the scratch
      tree down in `after_each`.
- [ ] Add a case asserting directory-shaped `skills` entries are admitted (the regression guard
      for this defect).
- [ ] Add a case asserting flat categories (`commands`, `agents`) are unchanged.
- [ ] Add a case asserting `context`'s directory-shaped selection still works.
- [ ] Add a case covering the `subdir ~= filter_category` shape (`agents_subdir =
      "agent/subagents"`).
- [ ] Add a case asserting a file absent from `provides` is still excluded — the allow-list is not
      a pass-through.
- [ ] Wrap fallible scratch-tree setup/teardown operations in `pcall` per repository standards.
- [ ] Ensure the spec never reads or writes the real `.claude/` or `agent-system/` trees, and
      contains no task-number references.

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Hypothesis — no `sync_spec.lua` exists today, so this is a new file rather
than an extension of an existing one. Confirm with a targeted search before writing; if one now
exists, extend it instead of creating a second.

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync_spec.lua` - new regression spec

**Verification**:
- `:TestFile` on the new spec passes all cases.
- Deliberately reverting the Phase 3 change locally makes the skills case fail (the spec actually
  guards the defect); restore the fix afterwards.
- `scan_spec.lua` still passes.

---

### Phase 6: End-to-end verification and one deliberate redeploy [NOT STARTED]

**Goal**: Verify the fix end to end against a scratch tree, then perform exactly one deliberate
redeploy and confirm every declared skill lands in `.claude/skills/` with the hand-corrected
orchestrator skills intact (scope item E).

**Tasks**:
- [ ] Re-run the full scratch-tree harness one final time against the finished code; record the
      after-state counts next to the Phase 1 before-state.
- [ ] Record the pre-redeploy state of `.claude/skills/`: the list of skill directories present
      and, for `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md`, a `diff`
      against `agent-system/extensions/core/skills/skill-orchestrate{,-hard}/SKILL.md`.
- [ ] Perform ONE deliberate redeploy through the sanctioned deploy process (the picker's
      "Load Core" / `load_all_globally` path). This is the only sanctioned write to `.claude/` in
      this task.
- [ ] Confirm every entry in `provides.skills` now has a corresponding
      `.claude/skills/<entry>/SKILL.md` present; enumerate any missing entry explicitly rather
      than reporting a bare count.
- [ ] Re-diff `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md` against their
      source-store originals; both diffs MUST be empty. A non-empty diff means the redeploy
      reverted hand-corrected content — stop and report rather than re-hand-correcting.
- [ ] Confirm the Phase 4 detector produced no WARN during the redeploy; if it did, treat it as a
      genuine finding and report the category rather than suppressing the warning.
- [ ] Confirm no unintended writes: `git status --short` scoped to `lua/` and `agent-system/`
      shows only the intended `sync.lua` and `sync_spec.lua` changes.
- [ ] Record in the summary the out-of-scope follow-up candidate from Phase 2
      (`scripts/tests/*.sh` and `scripts/lint/*.sh` absent from `provides.scripts`).

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Hypothesis — `provides.skills` contains 23 entries and all 23 land in
`.claude/skills/`. Confirm by re-reading `provides.skills` from
`agent-system/extensions/core/manifest.json` at implementation time and comparing the resolved
set against the on-disk `.claude/skills/` directories entry by entry; report the actual count
observed rather than the asserted one.

**Files to modify**:
- `.claude/skills/**` - written by the deploy process only, never hand-edited
- No repository source file is edited in this phase

**Verification**:
- After-state scratch counts recorded alongside the Phase 1 before-state, showing the flip.
- Every `provides.skills` entry resolves to a present `.claude/skills/<entry>/SKILL.md`.
- Both orchestrator `SKILL.md` diffs against the source store are empty post-redeploy.
- Zero detector warnings during the redeploy (or a reported, investigated finding).
- Full gate set for the repository: module loads headless, `scan_spec.lua` and `sync_spec.lua`
  both pass, and `git status --short` shows no unintended modification.

---

## Testing & Validation

- [ ] Phase 1 before-state captured verbatim from a headless scratch-tree run.
- [ ] Skills case flips from empty to the declared count after the fix.
- [ ] `context` selection is unchanged from pre-fix behavior.
- [ ] Flat categories (`commands`, `agents`, `rules`, `hooks`, `scripts`) are unchanged.
- [ ] The `subdir ~= filter_category` case (`agent/subagents`) still passes its agents.
- [ ] An undeclared file is still excluded — the allow-list is not a pass-through.
- [ ] Wipeout detector: fires once on total wipeout, never on partial exclusion.
- [ ] `sync_spec.lua` passes via `:TestFile`; reverting the fix makes it fail.
- [ ] `scan_spec.lua` still passes.
- [ ] Module loads headless: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.operations.sync')" -c "qa!"`.
- [ ] Post-redeploy: all `provides.skills` entries present in `.claude/skills/`; both orchestrator
      skill diffs empty.

## Artifacts & Outputs

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - generalized allow-list
  post-filter plus zero-result wipeout detector
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync_spec.lua` - new regression spec
- `.claude/skills/**` - refreshed by the single deliberate redeploy (deploy artifact, not
  hand-authored)
- `specs/938_picker_sync_skills_allow_list_filter/summaries/01_*-summary.md` - execution summary
  recording the before-state, the after-state, the category survey table, and the out-of-scope
  `provides.scripts` follow-up candidate

## Rollback/Contingency

- The source change is confined to one function in one file; `git revert` of the Phase 3/4
  commits restores the previous behavior exactly (skills silently dropped, which is the current
  status quo — no data loss either way, since the filter only ever excludes from a copy set).
- If Phase 1 reproduction fails, stop before any edit: record that the read-verified diagnosis did
  not hold and leave the codebase untouched. Nothing to roll back.
- If the Phase 6 redeploy produces a non-empty diff on either orchestrator `SKILL.md`, stop
  immediately, do not hand-correct the deployed file, and report — a revert of the source-side
  change plus re-running the deploy restores the prior deployed state, and the hand-corrected
  content remains recoverable from git history.
- The wipeout detector is report-only and can be removed independently of the filter fix if it
  proves noisy, without affecting correctness.
