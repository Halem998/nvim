# Implementation Plan: Task #24

- **Task**: 24 - Scope Playwright MCP permission allowlist to safe browser tools, solving install-once propagation
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: Task 23 (completed - MCP registration/permission ownership boundary)
- **Research Inputs**: specs/024_scope_playwright_mcp_permission_allowlist/reports/01_scoped-playwright-permission-allowlist.md
- **Artifacts**: plans/01_scoped-playwright-permission-allowlist.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md, mcp-server-ownership.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a deliberately scoped Playwright MCP permission grant so autonomous runs stop stalling on
browser tool prompts, without blanket-allowing arbitrary execution. The grant is a new
`agent-system/extensions/web/settings-fragment.json` enumerating exactly 9 safe browser tools,
wired via a new `merge_targets.settings` block in `agent-system/extensions/web/manifest.json` that
mirrors `nix`/`lean`'s existing shape. That mechanism deploys to `.claude/settings.local.json`
through `process_merge_targets`/`merge_settings` -- a code path entirely separate from
`loader.lua`'s install-once `copy_category("root_files", ...)` -- so it reaches already-initialized
projects on the next load/reload of the `web` extension. Definition of done: the 9 safe tools are
granted, `browser_evaluate` / `browser_file_upload` / `browser_run_code_unsafe` are absent from
every allow list, and the additive merge is demonstrated against a target settings file that
already existed before the merge ran.

### Research Integration

All five load-bearing conclusions from the research report are adopted without modification:

1. **Location**: new `web/settings-fragment.json` + new `merge_targets.settings` block in
   `web/manifest.json`, mirroring `nix`/`lean` exactly (both verified to carry
   `{"source": "settings-fragment.json", "target": ".claude/settings.local.json"}`).
2. **Install-once hazard is resolved by this choice**, not worked around: `merge_targets.settings`
   is processed by `process_merge_targets` in `init.lua`, which calls `merge.lua`'s
   `M.merge_settings` -- an additive, idempotent deep-merge that never overwrites an existing
   scalar and de-duplicates array items via `vim.deep_equal` before appending. The `install_once`
   flag exists only on the `root_files` category descriptor and is checked exclusively inside
   `loader.lua`'s `copy_category`; nothing on the merge path consults it.
3. **Enumeration, not a wildcard**: exactly the 9 safe names. A `mcp__playwright__*` wildcard
   would also grant `browser_evaluate`, `browser_file_upload`, and `browser_run_code_unsafe`,
   defeating the entire point. All 12 names were verified verbatim against the live tool surface.
4. **Document the exception** in `mcp-server-ownership.md` so a later "cleanup" pass does not
   collapse the enumeration into a wildcard the way `lean-lsp`'s was legitimately collapsed.
5. **No `mcpServers` block** in the new fragment (registration is already live via home-manager;
   a settings-file `mcpServers` block is proven inert and would be a sixth instance of an
   already-catalogued anti-pattern).

**Deliberate no-op on a declared file_scope entry**: the task's `file_scope` lists
`agent-system/extensions/core/root-files/settings.json`. Per the research report's Recommendation 4,
this plan **explicitly does not change that file**, and says so rather than silently dropping it.
Two independent reasons: (a) it is the wrong domain owner -- a `mcp__playwright__*` grant is
web-domain-specific today, and a domain-specific grant in core's settings is a boundary violation
per `mcp-server-ownership.md`; (b) it is the install-once file that cannot reach an
already-initialized repo at all, so putting the grant there would not even satisfy the acceptance
criterion. Phase 5 asserts this file is byte-identical to HEAD as a positive check, not an
omission.

**"Keep prompting" needs no rule**: omission from `permissions.allow` already yields a prompt.
No `ask` or `deny` key is to be invented; none is in use anywhere in this codebase.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but was not passed as `roadmap_path` in the delegation context, and
`roadmap_flag` is absent, so no roadmap-review/roadmap-update phases are added. A read-only grep
of ROADMAP.md for `playwright` / `mcp` / `permission` surfaced one loosely adjacent, unrelated
item (a manifest-driven README generator that would emit MCP server sections automatically); this
plan advances no roadmap item and modifies ROADMAP.md not at all.

## Goals & Non-Goals

**Goals**:
- Create `agent-system/extensions/web/settings-fragment.json` granting exactly the 9 safe
  `mcp__playwright__browser_*` tools, with no `mcpServers` key and no wildcard.
- Add `merge_targets.settings` to `agent-system/extensions/web/manifest.json`, mirroring
  `nix`/`lean`'s shape and key ordering.
- Demonstrate the additive merge against a settings file that **already existed** before the
  merge ran -- the acceptance criterion's explicit requirement.
- Record the enumeration-over-wildcard carve-out in `mcp-server-ownership.md` (and cross-reference
  it from `permission-configuration.md`) so it is not "fixed" away later.
- Leave `agent-system/extensions/core/root-files/settings.json` unchanged, and verify that.

**Non-Goals**:
- Re-deriving the granularity question (settled by `nix`/`lean`/`founder` precedent).
- Registering the Playwright MCP server anywhere (already live at user scope via home-manager).
- Touching `web-implementation-agent.md`'s Playwright tool-list prose or its
  `browser_verify_text_visible` name drift -- a separate sibling task owns that.
- Migrating `founder`'s deck-builder-agent or `present`'s `playwright-verify.mjs` from standalone
  npm Playwright to the MCP server -- a separate sibling task owns that.
- Loading the `web` extension into this repository, or regenerating this repository's `.claude/`
  tree. This repo currently loads `core, email, nvim, nix, memory`; `web` is not among them, and
  making it so is not part of this change.
- Any write whatsoever under a deployed `.claude/**` tree.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer edits a deployed `.claude/**` file (gitignored, disposable, silently wiped on next regeneration) | H | M | Every phase names an absolute `agent-system/extensions/**` target. Phase 5 runs `git status --short -- .claude/` and asserts the deploy tree is untouched. The advisory `validate-meta-write.sh` PostToolUse hook additionally nudges on any `.claude/**` write. |
| Verification performed against a freshly generated settings file, masking the install-once defect the task exists to close | H | M | Phase 3 pre-seeds the fixture's `.claude/settings.local.json` with unrelated pre-existing content **and** a `.claude/settings.json`, then asserts that pre-existing content survives the merge. A fresh-file merge is explicitly not accepted as evidence. |
| A future contributor collapses the 9-item enumeration into `mcp__playwright__*`, reopening the arbitrary-execution / file-upload hole | H | M | Phase 4 records the carve-out inline in `mcp-server-ownership.md` next to its "Wildcard over enumeration" subsection, with a cross-reference from `permission-configuration.md`'s parallel wording. |
| Implementer copies `nix`'s or `founder`'s fragment wholesale, importing their dead `mcpServers` block | M | M | Phase 1 verification asserts the fragment has exactly one top-level key (`permissions`), which fails loudly if an `mcpServers` block is present. |
| Implementer runs `deploy-headless.sh` against this repo to "verify" the change end-to-end | M | L | Regeneration is manual-only with exactly one sanctioned automated caller, which this is not. Phase 3 verifies against an isolated scratch fixture instead, and Phase 5's `git status` assertion catches an accidental redeploy. |
| A task number leaks into a deliverable file outside `specs/**` (the doc note in Phase 4 is the likely site) | M | M | Phase 4 forbids task-number citations and directs the note to reference durable anchors (file and subsection names). Phase 5 runs the repo-wide task-reference lint. |
| `web` not being loaded in a given target project means the grant does not arrive there | L | H | Inherent to the extension system and true of every extension fragment; explicitly out of scope, and NOT the install-once hazard this task addresses (that hazard is "even after reload, the old file is never touched" -- which does not apply on the merge path). |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create the web settings fragment [NOT STARTED]

**Goal**: The 9-tool enumeration exists as a valid, minimal JSON fragment in the source store.

**Tasks**:
- [ ] Write `/home/benjamin/.config/nvim/agent-system/extensions/web/settings-fragment.json` with
      exactly this content (2-space indent, matching `lean`/`nix` fragment style):
      ```json
      {
        "permissions": {
          "allow": [
            "mcp__playwright__browser_navigate",
            "mcp__playwright__browser_snapshot",
            "mcp__playwright__browser_take_screenshot",
            "mcp__playwright__browser_console_messages",
            "mcp__playwright__browser_network_requests",
            "mcp__playwright__browser_click",
            "mcp__playwright__browser_type",
            "mcp__playwright__browser_find",
            "mcp__playwright__browser_wait_for"
          ]
        }
      }
      ```
- [ ] Do NOT add an `mcpServers` key. Do NOT add `deny`, `ask`, or any other permission tier.
- [ ] Do NOT add a `mcp__playwright__*` wildcard entry alongside the enumeration -- a wildcard
      anywhere in the allow list re-grants the three unsafe tools regardless of what else is listed.

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The safe set is asserted to be exactly 9 tools and the must-keep-prompting
set exactly 3. Confirm at implementation time by re-reading the report's Findings bullet on tool
names and asserting mechanically:
```bash
cd /home/benjamin/.config/nvim
f=agent-system/extensions/web/settings-fragment.json
jq empty "$f"                                             # valid JSON
jq -e '[keys[]] == ["permissions"]' "$f"                  # exactly one top-level key: no mcpServers
jq -e '.permissions.allow | length == 9' "$f"             # exactly 9 entries
jq -e '.permissions.allow | all(startswith("mcp__playwright__browser_"))' "$f"
jq -e '.permissions.allow | any(contains("*")) | not' "$f"  # no wildcard
for t in browser_evaluate browser_file_upload browser_run_code_unsafe; do
  jq -e --arg t "mcp__playwright__$t" '.permissions.allow | index($t) == null' "$f"
done
```
If any assertion fails, correct the fragment before proceeding -- do not proceed to Phase 2 on a
red fragment.

**Files to modify**:
- `agent-system/extensions/web/settings-fragment.json` - NEW; the 9-tool `permissions.allow` grant.

**Verification**:
- Every command in the Scope Hypothesis block above exits 0.
- `git status --short -- agent-system/extensions/web/` shows exactly one new untracked file.

---

### Phase 2: Wire merge_targets.settings into the web manifest [NOT STARTED]

**Goal**: The loader knows to merge the fragment into `.claude/settings.local.json` on every
load/reload of `web`.

**Tasks**:
- [ ] Edit `/home/benjamin/.config/nvim/agent-system/extensions/web/manifest.json`, inserting into
      the existing `merge_targets` object, immediately after the `claudemd` entry and before
      `index` (matching `nix`/`lean` key ordering):
      ```json
      "settings": {
        "source": "settings-fragment.json",
        "target": ".claude/settings.local.json"
      },
      ```
- [ ] Use a textual `Edit`, not a `jq` rewrite -- `jq` reserializes the whole file and would churn
      formatting and key order across the entire manifest.
- [ ] Change nothing else in the manifest: `name`, `version`, `description`, `task_type`,
      `dependencies`, `provides`, `routing`, `routing_agents`, and the other three `merge_targets`
      entries all stay byte-identical.
- [ ] Do NOT add `settings-fragment.json` to `provides.*`. It is a merge source, not a deployed
      file category -- `nix` and `lean` both declare it only under `merge_targets`.

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/web/manifest.json` - add `merge_targets.settings`.

**Verification**:
```bash
cd /home/benjamin/.config/nvim
m=agent-system/extensions/web/manifest.json
jq empty "$m"
jq -e '.merge_targets.settings.source == "settings-fragment.json"' "$m"
jq -e '.merge_targets.settings.target == ".claude/settings.local.json"' "$m"
# declared source must exist, or no settings addition can reach an initialized repo
test -f "agent-system/extensions/web/$(jq -r '.merge_targets.settings.source' "$m")"
# shape parity with the two existing precedents
diff <(jq -S '.merge_targets.settings' agent-system/extensions/nix/manifest.json) \
     <(jq -S '.merge_targets.settings' "$m")
diff <(jq -S '.merge_targets.settings' agent-system/extensions/lean/manifest.json) \
     <(jq -S '.merge_targets.settings' "$m")
# nothing but merge_targets changed
git diff -- "$m" | grep -E '^[+-]' | grep -v '^[+-][+-]'
```
- The three `diff` invocations produce no output.
- The final `git diff` shows only the added `settings` block (4 added lines, no removals other
  than the reformatted line the insertion sits on, if any).

---

### Phase 3: Acceptance verification against a pre-existing settings file [NOT STARTED]

**Goal**: Prove the 9 grants land in a `.claude/settings.local.json` that **already existed**,
that the 3 unsafe tools do not, that pre-existing content survives, and that re-running is
idempotent.

**Why a fixture, not this repo**: this repository's `.claude/settings.local.json` is a deploy
artifact, and `web` is not among its loaded extensions (`core, email, nvim, nix, memory`).
Verifying here would require either loading `web` into this repo or regenerating its deploy tree
-- both out of scope, and regeneration is manual-only. An isolated scratch fixture exercises the
identical `merge.lua` code path with zero blast radius.

**Tasks**:
- [ ] Create a scratch fixture under the session scratchpad directory (NOT `/tmp` directly, NOT
      anywhere under this repo's `.claude/`), e.g. `$SCRATCH/pw-fixture/.claude/`.
- [ ] Pre-seed the fixture so it is unambiguously an *already-initialized* project:
      - `.claude/settings.json` containing some plausible pre-existing content (this file's mere
        existence is what makes the fixture represent the install-once scenario; the merge must
        not touch it).
      - `.claude/settings.local.json` containing pre-existing, unrelated content -- at minimum a
        `permissions.allow` array with an unrelated entry (e.g. `"mcp__nixos__nix"`) and one
        unrelated top-level scalar key, so both the array-append and the never-overwrite-a-scalar
        behaviors are observable.
- [ ] Record a `sha256sum` (or a copy) of both pre-seeded files before merging.
- [ ] Run the real merge path headlessly against the fixture:
      ```bash
      cd /home/benjamin/.config/nvim
      FIX=<absolute fixture path>
      nvim --headless \
        -c "lua local m=require('neotex.plugins.ai.shared.extensions.merge'); \
            local frag=vim.json.decode(table.concat(vim.fn.readfile('$(pwd)/agent-system/extensions/web/settings-fragment.json'),'\n')); \
            local ok,tracked=m.merge_settings('$FIX/.claude/settings.local.json', frag); \
            print('ok='..tostring(ok)); print(vim.inspect(tracked))" \
        -c "qa!"
      ```
- [ ] Run the exact same command a **second** time to exercise idempotency.
- [ ] Optional, best-effort end-to-end tier (attempt it; if it fails for environment reasons,
      record the reason in the summary and rely on the merge-level evidence above, which covers
      the acceptance semantics on its own): a full isolated load,
      `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.init').manager.load('web', {project_dir='$FIX', confirm=false})" -c "qa!"`.
      This must target the fixture's `project_dir` only. Under no circumstances run it (or
      `deploy-headless.sh`) against `/home/benjamin/.config/nvim`.

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the merge is additive, non-overwriting, and
de-duplicating. Confirm mechanically rather than by reading `merge.lua`:
```bash
t="$FIX/.claude/settings.local.json"
jq empty "$t"
# all 9 present
for n in navigate snapshot take_screenshot console_messages network_requests click type find wait_for; do
  jq -e --arg t "mcp__playwright__browser_$n" '.permissions.allow | index($t) != null' "$t"
done
# none of the 3 unsafe tools anywhere in the file, in any allow list, in any form
grep -E 'browser_evaluate|browser_file_upload|browser_run_code_unsafe' "$t" && exit 1 || true
# no wildcard smuggled in
grep -F 'mcp__playwright__*' "$t" && exit 1 || true
# pre-existing content survived
jq -e '.permissions.allow | index("mcp__nixos__nix") != null' "$t"
# idempotent: exactly one occurrence of each granted name after the second run
jq -e '[.permissions.allow[] | select(startswith("mcp__playwright__"))] | length == 9' "$t"
# the pre-existing .claude/settings.json was never touched
sha256sum -c <(printf '%s  %s\n' "$PRE_SETTINGS_SHA" "$FIX/.claude/settings.json")
```

**Files to modify**:
- None in the repository. Fixture files live in the scratchpad and are not committed.

**Verification**:
- Every assertion in the Scope Hypothesis block exits 0, after the **second** merge run.
- `git status --short` inside `/home/benjamin/.config/nvim` shows no change attributable to this
  phase (fixture is outside the repo).
- Record in the summary: the fixture path, the pre-seeded content, the `tracked` table the merge
  returned, and the post-merge `permissions.allow` contents.

---

### Phase 4: Record the enumeration-over-wildcard exception [NOT STARTED]

**Goal**: The deliberate deviation from the codebase's general "prefer a wildcard" guidance is
documented at the exact point a future maintainer would otherwise "fix" it away.

**Tasks**:
- [ ] Edit `/home/benjamin/.config/nvim/agent-system/extensions/core/context/patterns/mcp-server-ownership.md`:
      add a short subsection immediately after the existing `### Wildcard over enumeration`
      subsection (before `## Composition`) stating the carve-out. It must say: when a server
      intentionally splits its tool surface into a safe/always-allow tier and an
      unsafe/always-prompt tier, a wildcard cannot express that split and enumeration is
      **required**, not merely tolerated. Name the Playwright fragment
      (`agent-system/extensions/web/settings-fragment.json`) as the worked example, name the three
      tools that must keep prompting (`browser_evaluate`, `browser_file_upload`,
      `browser_run_code_unsafe`), and state explicitly that collapsing that enumeration into
      `mcp__playwright__*` would reopen an arbitrary-execution and file-upload hole.
- [ ] State the accepted cost honestly: this enumeration inherits exactly the drift weakness the
      preceding subsection describes -- a newly added safe Playwright tool will prompt until the
      list is updated. That is the deliberate price of keeping the unsafe tier prompting.
- [ ] Edit `/home/benjamin/.config/nvim/agent-system/extensions/core/docs/guides/permission-configuration.md`:
      the "Prefer a wildcard over an enumeration" paragraph currently states the rule with no
      carve-out. Add a one-sentence pointer to the new subsection in `mcp-server-ownership.md` so
      the two documents cannot drift into contradiction. Do not restate the carve-out's content
      here -- point to it.
- [ ] Edit `/home/benjamin/.config/nvim/agent-system/extensions/web/README.md`: add
      `settings-fragment.json` to the `## Architecture` directory tree (alongside `manifest.json`,
      `EXTENSION.md`, `index-entries.json`, `README.md`) with a one-line comment such as
      `# Scoped MCP permission grants (merged into .claude/settings.local.json)`. This also clears
      the doc-lint's README-older-than-manifest drift warning that Phase 2's manifest edit
      otherwise introduces.
- [ ] **Binding constraint**: none of these three files may cite a task number ("task 24",
      "tasks 25-26", "(task N)"). All three live outside `specs/**`. Reference durable anchors
      instead -- the fragment's file path, the `### Wildcard over enumeration` subsection name,
      the tool names themselves.
- [ ] Do not add the `web` extension to `mcp-server-ownership.md`'s "Known gaps" table. That table
      lists extensions carrying a dead `mcpServers` block; the new fragment deliberately has none.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` - new carve-out
  subsection after `### Wildcard over enumeration`.
- `agent-system/extensions/core/docs/guides/permission-configuration.md` - one-sentence pointer to
  the carve-out.
- `agent-system/extensions/web/README.md` - `settings-fragment.json` added to the architecture tree.

**Verification**:
- `git diff` on all three files shows changes confined to prose/markdown regions -- no code fences
  altered, no unrelated sections touched.
- The new subsection sits between `### Wildcard over enumeration` and `## Composition`:
  `grep -n '^### \|^## ' agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
  confirms the ordering.
- `grep -nEi '\btasks? +[0-9]+' <each of the three files>` returns nothing.
- All three named tools appear in the new subsection:
  `grep -c 'browser_evaluate\|browser_file_upload\|browser_run_code_unsafe'` is non-zero.

---

### Phase 5: Final gates and no-collateral-change assertions [NOT STARTED]

**Goal**: The repository-wide gates pass, the deploy tree is untouched, and
`core/root-files/settings.json` is confirmed unchanged.

**Tasks**:
- [ ] Run the doc-lint with an explicit source-store override:
      `cd /home/benjamin/.config/nvim && REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`
      and confirm no new FAIL attributable to `web` or `core`. Pre-existing failures/advisories
      unrelated to this change are recorded, not fixed here.
- [ ] Run the repo-wide task-reference lint:
      `cd /home/benjamin/.config/nvim && bash .claude/scripts/check-task-references.sh` (or its
      source-store equivalent) and confirm it exits 0.
- [ ] Assert `core/root-files/settings.json` is byte-identical to HEAD:
      `git diff --quiet -- agent-system/extensions/core/root-files/settings.json && echo UNCHANGED`
      This is the positive confirmation that the plan's deliberate no-op on that declared
      `file_scope` entry held.
- [ ] Assert the deployed tree was never written: `git status --short -- .claude/` produces no
      output attributable to this task, and no `.claude/settings*.json` was edited by hand.
- [ ] Assert no `mcp__playwright__*` wildcard exists anywhere in the source store:
      `grep -rn 'mcp__playwright__\*' agent-system/extensions/ || echo "no wildcard"`.
- [ ] Assert the 3 unsafe tools are granted nowhere in the source store:
      `grep -rnE 'mcp__playwright__(browser_evaluate|browser_file_upload|browser_run_code_unsafe)' agent-system/extensions/ || echo "none granted"`.
- [ ] Write the implementation summary, recording: the fixture path and pre-seed contents from
      Phase 3, the merge's `tracked` return value, the idempotency result from the second run, and
      the explicit statement that `core/root-files/settings.json` was intentionally left unchanged
      with the two-part rationale from the Overview.

**Timing**: 0.25 hours

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Files to modify**:
- `specs/024_scope_playwright_mcp_permission_allowlist/summaries/01_scoped-playwright-permission-allowlist-summary.md`
  - NEW; the implementation summary.

**Verification**:
- Doc-lint reports no new FAIL for `web` or `core`.
- Task-reference lint exits 0.
- Both `grep` assertions print their "no wildcard" / "none granted" fallback message.
- `git diff --quiet` on `core/root-files/settings.json` prints `UNCHANGED`.
- `git status --short` shows exactly: one new file (`web/settings-fragment.json`), three modified
  files (`web/manifest.json`, `web/README.md`, plus the two core docs), and the `specs/**`
  artifacts. Nothing under `.claude/`.

---

## Testing & Validation

- [ ] `jq empty` passes on `web/settings-fragment.json` and `web/manifest.json`.
- [ ] The fragment has exactly one top-level key (`permissions`) -- no `mcpServers`, no `ask`, no
      `deny`.
- [ ] `permissions.allow` has exactly 9 entries, all prefixed `mcp__playwright__browser_`, no
      wildcard.
- [ ] `browser_evaluate`, `browser_file_upload`, and `browser_run_code_unsafe` appear in no allow
      list anywhere in `agent-system/extensions/**`.
- [ ] `merge_targets.settings` in `web/manifest.json` is structurally identical to `nix`'s and
      `lean`'s, and its declared `source` file exists on disk.
- [ ] Merging the fragment into a **pre-existing** `.claude/settings.local.json` in a fixture
      project that also has a **pre-existing** `.claude/settings.json` yields all 9 grants while
      preserving the pre-existing allow-list entry and leaving `settings.json` byte-identical.
- [ ] Re-running the merge produces no duplicate entries (exactly 9 `mcp__playwright__*` entries
      after two runs).
- [ ] `check-extension-docs.sh` reports no new FAIL for `web` or `core`.
- [ ] `check-task-references.sh` exits 0.
- [ ] `agent-system/extensions/core/root-files/settings.json` is unchanged from HEAD.
- [ ] No file under any `.claude/**` deploy tree was created or modified.

## Artifacts & Outputs

- `agent-system/extensions/web/settings-fragment.json` (new) - the 9-tool permission enumeration.
- `agent-system/extensions/web/manifest.json` (modified) - `merge_targets.settings` block.
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` (modified) - the
  documented enumeration-over-wildcard carve-out.
- `agent-system/extensions/core/docs/guides/permission-configuration.md` (modified) - pointer to
  the carve-out.
- `agent-system/extensions/web/README.md` (modified) - architecture tree entry.
- `specs/024_scope_playwright_mcp_permission_allowlist/plans/01_scoped-playwright-permission-allowlist.md`
  (this file).
- `specs/024_scope_playwright_mcp_permission_allowlist/summaries/01_scoped-playwright-permission-allowlist-summary.md`
  (new, Phase 5).
- Transient, uncommitted: the scratchpad fixture project from Phase 3.

## Rollback/Contingency

Every change is confined to five source-store files, none of which any other component reads at
build or run time except through the extension loader:

- **Fragment + manifest**: `git checkout -- agent-system/extensions/web/manifest.json` and
  `rm agent-system/extensions/web/settings-fragment.json`. With the `merge_targets.settings` block
  removed, the loader simply skips the settings merge for `web`; nothing else in the manifest
  depends on it.
- **Already-merged targets**: the merge is tracked, so `manager.unload("web")` reverses exactly
  what was added and nothing more. Since the merge is additive and never overwrites an existing
  scalar, an un-reversed merge in a fixture leaves stale-but-harmless allow entries; deleting the
  fixture directory is sufficient there.
- **Doc edits**: `git checkout --` on the three markdown files. They are prose-only with no
  consumers that parse them mechanically.
- **This repository's deploy tree**: never written by this task, so there is nothing to roll back
  under `.claude/`. If a stray deploy write is discovered, the correct response is to leave it
  (the tree is disposable and regenerated from source) and re-apply the edit to the source store,
  not to hand-repair `.claude/`.

Contingency if Phase 3's headless verification cannot run (no `nvim` available, module load
failure): do NOT substitute a fresh-file merge or a hand-simulated merge as evidence -- both mask
the exact defect the acceptance criterion targets. Mark Phase 3 `[BLOCKED]` with the concrete
failure output, leave Phases 1, 2, and 4 committed (they are independently correct and inert
without a load), and record the blocker in the summary.
