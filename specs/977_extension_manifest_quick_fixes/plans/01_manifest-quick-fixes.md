# Implementation Plan: Extension Manifest Quick-Fix Batch

- **Task**: 977 - Extension manifest quick-fix batch (keyword_overrides shape, mcpServers casing, dead weight)
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: 976 (sequencing only; not blocking)
- **Research Inputs**: specs/977_extension_manifest_quick_fixes/reports/01_manifest-quick-fixes-verification.md
- **Artifacts**: plans/01_manifest-quick-fixes.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Five independently-verified extension-manifest defects share one file surface
(`agent-system/extensions/*/manifest.json` plus two settings fragments and one binary asset), so
they are executed as one batch of small, separately-verifiable phases. Two are correctness bugs
that mean a declared feature has never worked (`literature`'s `keyword_overrides` JSON shape;
`epidemiology`'s snake_case `mcp_servers` key); two are dead-weight removals (a 3 MB unreferenced
`.pptx`; an unused `literature` -> `filetypes` dependency that cascades through `cslib` and
`lean`); one activates four orphaned `mcp_servers` declarations and sweeps the vestigial empty
stubs. Definition of done: every item applied in the source store, every verification-bar
assertion in the task description passing, and `verify-deploy.sh --findings` producing no finding
line absent from the pre-change baseline.

### Research Integration

The research report verified all five items against the live repo and is treated as authoritative
for the following, which this plan does not re-litigate:

- Item 1's crash is real and reproduced (`Cannot index string with string "keywords"`, exit 5),
  swallowed by the consumer's `2>/dev/null`. Target shape:
  `{"meta": {"keywords": ["literature","zotero","bibliography","citation"]}}`, no `aliases`.
- Item 2: `lean` and `nix` fragments are the correct camelCase reference pattern; the loader
  deep-merges with no key translation, so the wrong key name silently lands verbatim.
- Item 3: the `.pptx` is 3,046,296 bytes, ~82% of the `present` extension (the review's "76%" is
  imprecise but the qualitative claim holds), and `grep -rl` finds zero references outside the
  file itself.
- Item 4: exactly one `filetypes` mention exists in the whole `literature` extension — the
  dependency declaration itself.
- Item 5 judgment call, RESOLVED: `founder`, `filetypes`, `memory` get real
  `settings-fragment.json` + `merge_targets.settings`; `present`'s `mcp_servers.superdoc` block is
  DELETED (referenced nowhere in `present`'s own material).
- Item 5 stub counts: 7 empty `mcp_servers: {}`, and 16 (not 13) empty `hooks: {}` repo-wide. The
  research recommends cleaning all 16 rather than reconstructing the review's exclusion arithmetic;
  this plan adopts that recommendation.

Two facts confirmed during planning that the report does not state, both bearing on Phase 6/7 risk:

- `manifest.mcp_servers` **does** have a live consumer, but a display-only, nil-safe one: the
  extension picker previewer (`lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua`
  and `lua/neotex/plugins/ai/shared/extensions/picker.lua`) guards with `if details and
  details.mcp_servers then` before `pairs(...)`. Removing a block or an empty stub cannot error;
  it only removes a preview line.
- Manifest schema requires only `name`, `version`, `description`
  (`lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua`), so `mcp_servers` and `hooks` are
  optional and may be deleted outright rather than left as `{}`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context and no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Make the `literature` keyword-override mechanism actually resolve `literature`/`zotero`/
  `bibliography`/`citation` to `meta`, with the consumer jq exiting 0.
- Make the `epidemiology` `rmcp` server actually installable through the settings merge.
- Remove ~3 MB of dead weight from the `present` extension's recursive context copy.
- Stop `literature` from force-loading `filetypes` (and thereby stop the `cslib` -> `lean` ->
  `literature` -> `filetypes` cascade).
- Activate the three genuinely-used orphaned `mcp_servers` declarations, delete the one dead
  declaration, and remove every empty `mcp_servers: {}` / `hooks: {}` stub.
- Leave `verify-deploy.sh` and `check-extension-docs.sh` with no finding absent from the
  pre-change baseline.

**Non-Goals**:
- Adding a new `check-extension-docs.sh` rule that fails on `mcp_servers` without a
  `merge_targets.settings` route. The research recommends it; it is a separate follow-up, not part
  of this batch.
- Redeploying `.claude/` or re-running the extension loader. All edits target the source store;
  the deploy artifact regenerates on the user's next sync.
- Reconciling the review's literal "13 empty hooks" count against the repo's actual 16. All 16 are
  cleaned; the arithmetic is recorded in this plan and need not be reproduced.
- Any change to `provides.*` in any manifest. `settings-fragment.json` is referenced through
  `merge_targets.settings`, never through `provides` (verified against `lean` and `nix`).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A repo loading `literature` silently relies on `filetypes` being cascade-installed, and loses it (item 4) | M | L | Research found zero content references. Phase 5 re-confirms the single-hit grep before editing and adds a changelog note to `literature/EXTENSION.md` telling any such repo to load `filetypes` explicitly. |
| New `founder` fragment activates `FIRECRAWL_API_KEY` env passthrough that was previously inert (item 5) | M | M | Copy the env block verbatim from the existing `mcp_servers` declaration — no new secret is introduced, only activation of an already-declared passthrough. Record this explicitly in the phase output so the change is not silent. |
| New fragments introduce MCP servers into a user's `settings.local.json` that were not there before | M | H (by design) | This is the intended fix, exactly analogous to `lean`/`nix`. Mitigation is disclosure, not prevention: Phase 6 must name each server added per extension in its commit message. |
| Deleting the `.pptx` changes the deploy footprint and could perturb a currently-clean `verify-deploy.sh` | M | L | Phase 1 captures a `--findings` baseline; Phase 4 re-runs `--findings` immediately after the deletion and diffs; Phase 8 gates on the full comparison. |
| Two phases both edit `literature/manifest.json` (items 1 and 4) and a third sweeps it again (stubs) | L | M | Serialized by dependency: Phase 5 depends on Phase 2, Phase 7 depends on 2, 5, and 6. No two phases in the same wave touch the same file. |
| A task-number citation leaks into a deliverable (e.g. the item-4 changelog note) | M | M | Every phase that writes outside `specs/**` states the constraint inline; the blocking PreToolUse hook is the backstop, not the plan. Use durable anchors (manifest path, field name, extension name). |
| Edits land in `.claude/**` instead of the source store | H | L | Every phase names absolute `agent-system/extensions/**` paths. `.claude/**` is a gitignored disposable deploy artifact and must never be edited. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 6 | 1 |
| 3 | 5 | 2 |
| 4 | 7 | 2, 5, 6 |
| 5 | 8 | 3, 4, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Capture Clean-Tree Baseline [COMPLETED]

- **Goal:** Record the exact pre-change findings set of both gates so every later phase can prove
  it introduced no new finding, rather than merely asserting "still passes".
- **Tasks:**
  - [x] Run `bash .claude/scripts/verify-deploy.sh --findings --quiet` from the repo root; capture
        stdout and the exit code. *(completed: exit 0, zero FINDING lines)*
  - [x] Run `bash .claude/scripts/check-extension-docs.sh --quiet`; capture stdout and exit code.
        *(completed: exit 0, all extensions PASS, 39 pre-existing advisories unrelated to
        PASS/FAIL)*
  - [x] Record `du -sb agent-system/extensions/present` and
        `du -sh agent-system/extensions/present` as the item-3 before-measurement.
        *(completed: 3723821 bytes / 4.0M)*
  - [x] Write all three captures to
        `specs/977_extension_manifest_quick_fixes/baseline-verify-deploy.txt` (a task-directory
        scratch artifact, not a deliverable). *(completed)*
  - [x] Confirm the baseline matches the stated repo state: `verify-deploy.sh` exits 0 with zero
        FINDING lines. If it does NOT, stop and report — the "no new findings" bar is meaningless
        against a dirty baseline, and proceeding would silently absorb a pre-existing failure.
        *(completed: confirmed clean)*
- **Timing:** 15 minutes
- **Depends on:** none
- **Verification Tier:** prose
- **Scope Hypothesis:** The delegation asserts `verify-deploy.sh` currently exits 0 with ZERO
  findings. Confirm by running it with `--findings` and asserting both exit code 0 and an empty
  FINDING-line set before any edit is made.
- **Files to modify:**
  - `specs/977_extension_manifest_quick_fixes/baseline-verify-deploy.txt` - new scratch capture
- **Verification:**
  - Baseline file exists, is non-empty, and records exit code 0 for both gates.

---

### Phase 2: Reshape literature keyword_overrides [COMPLETED]

- **Goal:** Give `literature/manifest.json` the object-valued `keyword_overrides` shape the
  consumer in `core/commands/task.md` requires, so the four keywords resolve to `meta` instead of
  crashing jq into a swallowed error.
- **Tasks:**
  - [x] Read the current `keyword_overrides` block in
        `agent-system/extensions/literature/manifest.json` and confirm it still has string values.
        *(completed: confirmed exactly 4 string-valued keys)*
  - [x] Replace it with
        `{"meta": {"keywords": ["literature", "zotero", "bibliography", "citation"]}}`. Do not add
        an `aliases` array — none of the four terms needs remapping from another resolved type.
        *(completed)*
  - [x] Confirm the file is still valid JSON (`jq empty`). *(completed)*
  - [x] Cross-check the resulting shape against the two known-correct siblings,
        `agent-system/extensions/cslib/manifest.json` and
        `agent-system/extensions/email/manifest.json`. *(completed: shape matches)*
- **Timing:** 20 minutes
- **Depends on:** 1
- **Verification Tier:** interface
- **Scope Hypothesis:** Exactly four keywords (`literature`, `zotero`, `bibliography`, `citation`)
  currently map to `meta` as bare strings. Confirm by reading `.keyword_overrides` before the edit
  and asserting the key set is exactly those four; if the live manifest differs, carry the actual
  key set into the reshaped `keywords` array rather than the planned one.
- **Files to modify:**
  - `agent-system/extensions/literature/manifest.json` - reshape `keyword_overrides` to the
    `{"<task_type>": {"keywords": [...]}}` form
- **Verification:**
  - Run the consumer pattern directly and assert exit 0 with no stderr:
    ```bash
    jq -r --arg desc "i need to search zotero for a citation" '
      .keyword_overrides // {} | to_entries[] |
      select(.value.keywords[]? as $kw | ($desc | test("\\b" + $kw + "\\b"))) |
      .key' agent-system/extensions/literature/manifest.json
    ```
    Expected: prints `meta`, exit 0. Run it WITHOUT `2>/dev/null` so a regression is visible.
  - Repeat with a description containing `literature` and one containing `bibliography`; both must
    print `meta` at exit 0.
  - Negative check: a description containing none of the four keywords prints nothing, exit 0.

---

### Phase 3: Fix epidemiology settings-fragment key casing [COMPLETED]

- **Goal:** Rename the fragment's top-level `mcp_servers` key to `mcpServers` so the deep-merge
  lands the `rmcp` server where Claude Code actually reads it.
- **Tasks:**
  - [x] Edit `agent-system/extensions/epidemiology/settings-fragment.json`, renaming the top-level
        `mcp_servers` key to `mcpServers`. Leave the nested `rmcp` server object byte-identical.
        *(completed)*
  - [x] Confirm valid JSON (`jq empty`) and that no other key in the file changed. *(completed)*
  - [x] Confirm `epidemiology/manifest.json` already routes this fragment via
        `merge_targets.settings`; if it does not, add the route mirroring `lean`/`nix`
        (`{"source": "settings-fragment.json", "target": ".claude/settings.local.json"}`) — a
        correctly-cased fragment that is never merged fixes nothing.
        *(completed: route already present, no manifest edit needed)*
- **Timing:** 20 minutes
- **Depends on:** 1
- **Verification Tier:** interface
- **Files to modify:**
  - `agent-system/extensions/epidemiology/settings-fragment.json` - `mcp_servers` -> `mcpServers`
  - `agent-system/extensions/epidemiology/manifest.json` - only if the `merge_targets.settings`
    route is found to be missing
- **Verification:**
  - `jq 'has("mcpServers") and (has("mcp_servers") | not)'` on the fragment returns `true`.
  - Scratch merge test in the scratchpad directory (never against the real
    `.claude/settings.local.json`): deep-merge the fragment into a copy of a settings file and
    assert the `rmcp` entry appears under `.mcpServers.rmcp`, e.g.
    ```bash
    jq -s '.[0] * .[1] | .mcpServers.rmcp' /tmp/.../scratch-settings.json \
      agent-system/extensions/epidemiology/settings-fragment.json
    ```
    Expected: the `{"command": "uvx", "args": ["rmcp"]}` object, not `null`.
  - Shape parity: the fragment's top-level key set matches `lean`/`nix` conventions (`mcpServers`,
    optionally `permissions`).

---

### Phase 4: Delete the unreferenced PowerPoint template [NOT STARTED]

- **Goal:** Remove ~3 MB of dead weight that the `present` extension's recursive context copy
  carries into every deploy.
- **Tasks:**
  - [ ] Re-confirm zero references immediately before deleting:
        `grep -rl "UCSF_ZSFG_Template_16x9" agent-system/` must return only the file itself (or
        nothing, if binary matching is skipped). If any other file matches, STOP and report rather
        than deleting.
  - [ ] Re-confirm the sibling `present/context/project/present/talk/index.json` `pptx-project`
        entry's `files` array does not list the `.pptx`.
  - [ ] Delete
        `agent-system/extensions/present/context/project/present/talk/templates/pptx-project/UCSF_ZSFG_Template_16x9.pptx`
        via `git rm` (the file is git-tracked; a bare `rm` leaves the deletion unstaged and easy to
        lose).
  - [ ] Do NOT edit any manifest or index for this item — the file was never declared as an
        individually-tracked asset.
- **Timing:** 20 minutes
- **Depends on:** 1
- **Verification Tier:** interface
- **Scope Hypothesis:** The file is 3,046,296 bytes and the only ~3 MB item in the `present` tree;
  deleting it drops the extension's `du -sh` by ~3 MB. Confirm by comparing `du -sb
  agent-system/extensions/present` against the Phase 1 baseline capture and asserting the delta
  equals the file's recorded byte size.
- **Files to modify:**
  - `agent-system/extensions/present/context/project/present/talk/templates/pptx-project/UCSF_ZSFG_Template_16x9.pptx` - deleted
- **Verification:**
  - `du -sh agent-system/extensions/present` drops by ~3 MB versus the Phase 1 baseline; `du -sb`
    delta equals 3,046,296 bytes (or the actual recorded size).
  - `bash .claude/scripts/check-extension-docs.sh --quiet` still passes for `present`.
  - `bash .claude/scripts/verify-deploy.sh --findings --quiet` produces no FINDING line absent from
    the Phase 1 baseline (this is the deploy-footprint-affecting item, so the diff is run here and
    not deferred to Phase 8).

---

### Phase 5: Drop the literature -> filetypes dependency [NOT STARTED]

- **Goal:** Stop `literature` from force-loading a ~380 KB unrelated extension, and stop the
  `cslib` -> `lean` -> `literature` -> `filetypes` cascade.
- **Tasks:**
  - [ ] Re-run `grep -rn filetypes agent-system/extensions/literature/` and confirm the only hit is
        the manifest's own `dependencies` array. If more hits appear, STOP and report — a real code
        reference invalidates the premise.
  - [ ] Also grep the `literature` tree for `superdoc`, `openpyxl`, `docx`, `xlsx` and confirm zero
        hits (an indirect use of `filetypes` capabilities under a different name).
  - [ ] Edit `agent-system/extensions/literature/manifest.json`, changing `dependencies` from
        `["core", "filetypes"]` to `["core"]`.
  - [ ] Add a short changelog/behavior note to `agent-system/extensions/literature/EXTENSION.md`
        (or the extension's README if EXTENSION.md has no changelog section) stating that
        `filetypes` is no longer a transitive dependency and that a repo relying on it must load
        `filetypes` explicitly. **Reference durable anchors only** — name the manifest field
        (`dependencies`) and the extension names. Do NOT cite a task number: this file lives
        outside `specs/**` and a blocking PreToolUse hook will reject the write.
  - [ ] Re-confirm the cascade is broken: `jq '.dependencies'` across `cslib`, `lean`,
        `literature`, `filetypes` shows no path from `cslib` to `filetypes`.
- **Timing:** 30 minutes
- **Depends on:** 2
- **Verification Tier:** full
- **Scope Hypothesis:** `grep -rn filetypes agent-system/extensions/literature/` returns exactly one
  hit (the manifest's own declaration). Confirm by running the grep and asserting a line count of 1
  before making the edit.
- **Files to modify:**
  - `agent-system/extensions/literature/manifest.json` - `dependencies` -> `["core"]`
  - `agent-system/extensions/literature/EXTENSION.md` - behavior-change note (no task numbers)
- **Verification:**
  - `jq -r '.dependencies[]' agent-system/extensions/literature/manifest.json` prints only `core`.
  - `grep -rn filetypes agent-system/extensions/literature/` returns zero hits.
  - `bash .claude/scripts/check-extension-docs.sh --quiet` passes for `literature`, `lean`,
    `cslib`, and `filetypes`.
  - `bash .claude/scripts/verify-deploy.sh --findings --quiet` shows no FINDING line absent from the
    Phase 1 baseline (this is the deploy-cascade-affecting item).
  - `grep -nE "task [0-9]+|tasks [0-9]+|Task #[0-9]+" agent-system/extensions/literature/EXTENSION.md`
    returns nothing.

---

### Phase 6: Resolve the four orphaned mcp_servers blocks [NOT STARTED]

- **Goal:** Activate the three `mcp_servers` declarations whose tools the extension actually uses,
  and delete the one that nothing references.
- **Tasks:**
  - [ ] For each of `founder`, `filetypes`, `memory`: create
        `agent-system/extensions/<ext>/settings-fragment.json` with a top-level **camelCase**
        `mcpServers` object carrying that manifest's existing server definitions **verbatim**
        (including `founder`'s `FIRECRAWL_API_KEY` env passthrough and `memory`'s
        `OBSIDIAN_WS_PORT`). Mirror the structure of
        `agent-system/extensions/lean/settings-fragment.json`.
  - [ ] For each of the three, add a `merge_targets.settings` entry to its `manifest.json`:
        `{"source": "settings-fragment.json", "target": ".claude/settings.local.json"}` — the same
        target every working settings merge uses. Do NOT add a `provides` entry; fragments are
        routed through `merge_targets` only (verified against `lean` and `nix`).
  - [ ] Add a `permissions.allow` array to a fragment only where concrete `mcp__*` tool names are
        actually referenced in that extension's own material. `founder` references
        `mcp__firecrawl__scrape|crawl|map|extract` and `mcp__sec-edgar__*`; `filetypes` and `memory`
        reference their servers by name only, so their fragments carry `mcpServers` alone.
        `permissions` is optional in this schema — do not invent tool names to fill it.
  - [ ] Remove the now-redundant top-level `mcp_servers` block from each of the three manifests, OR
        leave it as the picker's display source — pick ONE convention, apply it to all three, and
        state which in the phase output. Recommended: keep it, since the picker previewer reads
        `manifest.mcp_servers` to show users which servers an extension installs, and the fragment
        is the merge path rather than a replacement for that display.
  - [ ] Delete the entire top-level `mcp_servers` block from
        `agent-system/extensions/present/manifest.json`. Do NOT create a fragment for `present` —
        `superdoc` is referenced nowhere in `present`'s agents, skills, context, or README.
  - [ ] Confirm all four manifests and all three new fragments are valid JSON (`jq empty`).
- **Timing:** 45 minutes
- **Depends on:** 1
- **Verification Tier:** interface
- **Scope Hypothesis:** Exactly four extensions declare a non-empty top-level `mcp_servers` with no
  `merge_targets.settings` route: `founder`, `filetypes`, `memory`, `present`. Confirm at
  implementation time with a repo-wide scan of `agent-system/extensions/*/manifest.json` asserting
  a non-empty `.mcp_servers` and an absent `.merge_targets.settings`; the result must be exactly
  that set. `lean` and `nix` have non-empty `mcp_servers` but already carry the route and are out
  of scope.
- **Files to modify:**
  - `agent-system/extensions/founder/settings-fragment.json` - new (`sec-edgar`, `firecrawl`)
  - `agent-system/extensions/founder/manifest.json` - add `merge_targets.settings`
  - `agent-system/extensions/filetypes/settings-fragment.json` - new (`superdoc`, `openpyxl`)
  - `agent-system/extensions/filetypes/manifest.json` - add `merge_targets.settings`
  - `agent-system/extensions/memory/settings-fragment.json` - new (`obsidian-memory`)
  - `agent-system/extensions/memory/manifest.json` - add `merge_targets.settings`
  - `agent-system/extensions/present/manifest.json` - delete the `mcp_servers` block
- **Verification:**
  - For each of the three: `jq '.merge_targets.settings'` is non-null and its `source` file exists
    on disk; the fragment's top-level key set contains `mcpServers` and does NOT contain
    `mcp_servers`.
  - Server-set parity: for each of the three, the fragment's `.mcpServers | keys` equals the
    manifest's `.mcp_servers | keys` (no server silently dropped or renamed in transcription).
  - `jq 'has("mcp_servers")' agent-system/extensions/present/manifest.json` returns `false`.
  - Scratch merge test (scratchpad only, never the real settings file): deep-merging each new
    fragment into a copy of a settings file yields the expected `.mcpServers.<server>` entries.
  - `bash .claude/scripts/check-extension-docs.sh --quiet` passes for all four extensions.
  - The commit message names each server added per extension, so the settings-surface change is
    disclosed rather than silent.

---

### Phase 7: Sweep vestigial empty manifest stubs [NOT STARTED]

- **Goal:** Remove every empty `mcp_servers: {}` and `hooks: {}` object across the extension
  manifests, leaving no manifest carrying a meaningless stub.
- **Tasks:**
  - [ ] Enumerate live, do not trust the plan's counts:
        ```bash
        for f in agent-system/extensions/*/manifest.json; do
          [ "$(jq -c '.mcp_servers // "ABSENT"' "$f")" = "{}" ] && echo "mcp_servers: $f"
          [ "$(jq -c '.hooks // "ABSENT"' "$f")" = "{}" ] && echo "hooks: $f"
        done
        ```
  - [ ] Delete each empty object outright (`del(.mcp_servers)` / `del(.hooks)`) rather than
        replacing it with `null`. Both fields are optional — the manifest schema requires only
        `name`, `version`, `description`.
  - [ ] Include `core`, `literature`, and `epidemiology` in the sweep. The review's "thirteen"
        figure excluded them; the research recommends cleaning all of them for consistency, and
        doing so costs nothing since items 1/2/4 already touch two of the three.
  - [ ] Preserve each manifest's existing key ordering and formatting style as far as the editing
        method allows; if using `jq`, confirm the diff shows only the intended deletion.
  - [ ] Confirm every touched manifest is valid JSON (`jq empty`).
- **Timing:** 30 minutes
- **Depends on:** 2, 5, 6
- **Verification Tier:** interface
- **Scope Hypothesis:** 7 manifests carry an empty `mcp_servers: {}` (`cslib`, `latex`, `nvim`,
  `python`, `typst`, `web`, `z3`) and 16 carry an empty `hooks: {}` (`core`, `cslib`,
  `epidemiology`, `filetypes`, `formal`, `founder`, `latex`, `lean`, `literature`, `memory`,
  `present`, `python`, `slidev`, `typst`, `web`, `z3`) — note 16, NOT the review's 13. Confirm with
  the enumeration loop above before editing and use its actual output as the work list; do not
  hard-code these lists.
- **Files to modify:**
  - `agent-system/extensions/*/manifest.json` - delete empty `mcp_servers` / `hooks` objects, per
    the live enumeration
- **Verification:**
  - Re-run the enumeration loop; it produces zero output.
  - Every touched manifest passes `jq empty`.
  - `git diff --stat` shows only the intended manifests, and `git diff` shows only deletions of the
    two stub fields (no reordering or reformatting churn beyond what the editing method requires).
  - `bash .claude/scripts/check-extension-docs.sh --quiet` passes for all extensions.

---

### Phase 8: Final Gate and Baseline Comparison [NOT STARTED]

- **Goal:** Prove the whole batch leaves both gates no worse than the Phase 1 baseline and that
  every verification-bar assertion from the task description holds simultaneously.
- **Tasks:**
  - [ ] Run `bash .claude/scripts/check-extension-docs.sh` (not `--quiet`) across all extensions;
        assert exit 0.
  - [ ] Run `bash .claude/scripts/verify-deploy.sh --findings --quiet`; diff its FINDING lines
        against the Phase 1 baseline capture. Assert the new set is a subset of the baseline set
        (zero new findings). Any new finding blocks completion.
  - [ ] Re-run all four task-description verification-bar assertions end to end: the consumer jq
        against the reshaped `literature` manifest (exit 0, no stderr); the `epidemiology` scratch
        settings merge landing under `mcpServers`; the `present` `du -sh` drop of ~3 MB with
        `check-extension-docs.sh` still passing for `present`; and no manifest retaining an empty
        `mcp_servers`/`hooks` object.
  - [ ] Run the repo-wide task-reference lint
        (`bash .claude/scripts/check-task-references.sh`) and confirm no new finding from this
        batch's writes outside `specs/**` (specifically `literature/EXTENSION.md`).
  - [ ] Confirm no file under `.claude/**` was modified by this batch: `git status --short` and the
        accumulated `modified_files` list must contain only `agent-system/extensions/**` and
        `specs/**` paths.
  - [ ] Delete the Phase 1 scratch baseline file, or leave it in the task directory as provenance —
        state which in the summary.
- **Timing:** 30 minutes
- **Depends on:** 3, 4, 7
- **Verification Tier:** full
- **Files to modify:**
  - None (verification only), except optional removal of the Phase 1 scratch baseline file
- **Verification:**
  - Both gates exit 0.
  - The post-change FINDING set is a subset of the baseline FINDING set.
  - All four verification-bar assertions pass in one run.
  - No `.claude/**` path appears in the change set.

## Testing & Validation

- [ ] Consumer jq against `literature/manifest.json` exits 0 with no stderr and prints `meta` for
      descriptions containing `literature`, `zotero`, `bibliography`, or `citation`.
- [ ] `epidemiology/settings-fragment.json` merges `rmcp` under `.mcpServers` in a scratch merge.
- [ ] `du -sh agent-system/extensions/present` drops by ~3 MB; `check-extension-docs.sh` passes for
      `present`.
- [ ] `literature/manifest.json` `dependencies` is `["core"]`; zero `filetypes` references remain
      in the `literature` tree.
- [ ] `founder`, `filetypes`, `memory` each have a camelCase `settings-fragment.json` routed by
      `merge_targets.settings`, with server sets matching their manifest declarations.
- [ ] `present/manifest.json` has no `mcp_servers` key.
- [ ] Zero manifests retain an empty `mcp_servers: {}` or `hooks: {}`.
- [ ] Every touched JSON file passes `jq empty`.
- [ ] `check-extension-docs.sh` exits 0 for all extensions.
- [ ] `verify-deploy.sh --findings` produces no FINDING line absent from the Phase 1 baseline.
- [ ] No file under `.claude/**` modified; no task-number citation in any file outside `specs/**`.

## Artifacts & Outputs

- `specs/977_extension_manifest_quick_fixes/plans/01_manifest-quick-fixes.md` (this plan)
- `specs/977_extension_manifest_quick_fixes/baseline-verify-deploy.txt` (Phase 1 scratch baseline)
- `specs/977_extension_manifest_quick_fixes/summaries/01_manifest-quick-fixes-summary.md`
- Source-store edits under `agent-system/extensions/`: `literature/manifest.json`,
  `literature/EXTENSION.md`, `epidemiology/settings-fragment.json`,
  `founder/{manifest.json,settings-fragment.json}`,
  `filetypes/{manifest.json,settings-fragment.json}`,
  `memory/{manifest.json,settings-fragment.json}`, `present/manifest.json`, the empty-stub sweep
  across the remaining manifests, and the deletion of
  `present/context/project/present/talk/templates/pptx-project/UCSF_ZSFG_Template_16x9.pptx`

## Rollback/Contingency

Every phase is an independently revertable commit against the source store; `.claude/**` is never
touched, so no deploy rollback is involved.

- **Per-item revert**: `git revert <phase-commit>` restores that item alone. The phases are ordered
  so that no revert leaves a partially-applied item.
- **Item 3 (the `.pptx`)**: restored by `git checkout <pre-deletion-sha> -- <path>` — the file is
  git-tracked, so the 3 MB binary is recoverable from history.
- **Item 4 (dependency drop)**: if a repo turns out to depend on the `filetypes` cascade, the fix is
  to load `filetypes` explicitly in that repo rather than to restore the dependency; restoring it
  re-introduces the cascade for every `cslib`/`lean` consumer.
- **Item 5 (new fragments)**: if a new fragment introduces an unwanted MCP server into a user's
  `settings.local.json`, remove the `merge_targets.settings` entry (which stops future merges) and
  unmerge the server from the deployed settings file; the fragment itself can stay.
- **Blocking condition**: if the Phase 1 baseline is NOT clean, stop before any edit and report.
  If Phase 8's findings diff shows a new finding, do not mark the task complete — mark the
  offending phase `[PARTIAL]` and report the diff.
