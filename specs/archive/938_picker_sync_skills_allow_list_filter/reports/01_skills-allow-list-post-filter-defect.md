# Research Report: picker_sync_skills_allow_list_filter

**Task**: 938 - picker_sync_skills_allow_list_filter
**Started**: 2026-07-28
**Completed**: 2026-07-28
**Effort**: Small-to-medium (single-file targeted fix + one added safeguard)
**Dependencies**: None
**Sources/Inputs**: Direct code reading (3 named files), the core `manifest.json`, on-disk
directory shapes under `agent-system/extensions/core/`, an existing `plenary`-style spec
(`scan_spec.lua`) as the harness precedent, a live scratch-tree reproduction, and
`docs/architecture/handoff-schema.md`.
**Artifacts**: This report.
**Standards**: `.claude/rules/artifact-formats.md`, `neovim-lua.md`

## Executive Summary

- **Root cause confirmed, not just read-verified**: `manifest.build_allow_list()` keys
  `allow_list.skills` by skill-**directory** name (e.g. `"skill-orchestrate"`), but
  `sync.sync_scan()`'s allow-list post-filter looks up `allowed[file_info.name]` where
  `file_info.name` is always the **basename** `"SKILL.md"` (set by
  `scan.scan_directory_for_sync()`, `name = vim.fn.fnamemodify(global_file, ":t")`). Every
  lookup is `allowed["SKILL.md"]`, which is never a key, so `artifacts.skills` is unconditionally
  empty.
- **Empirically reproduced** against an isolated scratch tree (never touching the real
  `.claude/` or `agent-system/`): a 2-skill scratch manifest + scratch skill directories fed
  through the real, unmodified `sync.scan_all_artifacts()` returned `skills found: 0`, while
  `commands found: 1` and `agents found: 1` (both flat categories) matched expectations exactly.
  This confirms the defect is real and confirms flat categories are unaffected.
- **Fix precedent already exists in the same function**: the `filter_category == "context"`
  branch already does directory-name matching (extract top-level path segment, look up that
  segment). The task's stated preference — generalize rather than add a third branch — is
  correct and low-risk: every current call site passes `subdir == filter_category`, so the
  `"context"`-specific pattern `/context/(.+)$` generalizes cleanly to
  `/" .. filter_category .. "/(.+)$"` for every category, and for categories with no nested
  directories (agents, commands, rules, hooks — verified below) the generalized top-level-segment
  extraction degenerates to exactly the current basename lookup, so no regression there.
- **Category shape survey (Scope C) is complete**: of the 7 categories that pass
  `filter_category` into the post-filter, **`skills` and `context` are directory-shaped**
  (provides entries name a directory, not a file); **`agents`, `commands`, `rules`, `scripts`,
  `hooks` are flat-file-shaped** (provides entries are exact file basenames, and none of these
  five currently has any on-disk subdirectory nesting). `context` already has correct handling;
  `skills` does not. `docs`, `templates`, `systemd` never receive `filter_category` at all
  (unfiltered by design, out of scope — see "Categories Without a Post-Filter" below).
- **Zero-result detection (Scope D) has a natural, low-false-positive trigger point**: inside
  `sync_scan`, immediately after building `filtered`, if `#results > 0` and `#filtered == 0`
  (allow-list present for this category) that is a total-wipeout signature, essentially never
  a legitimate outcome (a genuinely restrictive but working allow-list still lets *some* declared
  files through). A partial reduction (some files dropped) is normal and must NOT trigger the
  warning — that already happens for extension-provided files sharing a category, and is exactly
  what the allow-list is *for*.

## Context & Scope

Researched task 938's three named files plus the core manifest (`manifest.json`) and the
on-disk directory layout of every category that the sync allow-list post-filter touches, to
confirm or refute a read-verified diagnosis before any fix is planned. No source file was
edited (research phase). A read-only reproduction harness was built and run against an isolated
`vim.fn.tempname()` scratch tree, then deleted; the real `.claude/` and `agent-system/` trees
were never touched or mutated.

## Findings

### 1. Confirmed root cause, with exact code references

**`lua/neotex/plugins/ai/shared/extensions/manifest.lua`**, `M.build_allow_list()`
(lines 283-294):
```lua
function M.build_allow_list(core_provides)
  local allow_list = {}
  for category, files in pairs(core_provides) do
    if type(files) == "table" then
      allow_list[category] = {}
      for _, filename in ipairs(files) do
        allow_list[category][filename] = true
      end
    end
  end
  return allow_list
end
```
This is generic — it just copies whatever strings appear in `core_provides[category]`. The core
manifest's `provides.skills` array (verified via `agent-system/extensions/core/manifest.json`)
contains **23 directory-name strings**: `skill-fix-it`, `skill-git-workflow`,
`skill-implementer`, `skill-orchestrate`, `skill-orchestrator`, `skill-planner`, … (all 23
confirmed by listing `agent-system/extensions/core/skills/`, which has exactly 23
subdirectories, each named identically to a `provides.skills` entry). So
`allow_list.skills = { ["skill-fix-it"]=true, ["skill-orchestrate"]=true, ... }` — no key is
ever `"SKILL.md"`.

**`lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua`**,
`M.scan_directory_for_sync()` (line 139):
```lua
table.insert(files, {
  name = vim.fn.fnamemodify(global_file, ":t"),
  ...
```
`:t` is the basename modifier. For every skill file (`skills/<dir>/SKILL.md`), `global_file` ends
in `/SKILL.md`, so `name == "SKILL.md"` for all 23 files. (Confirmed on disk: every skill
directory contains exactly one `SKILL.md`, no `.yaml` files — `skill-orchestrator/` additionally
has a stray `SKILL.md.archived`, which the `*.md` glob does not match, so it never enters the
scan at all and is not part of this defect.)

**`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`**, `sync_scan`'s post-filter
(lines 985-1009):
```lua
if allow_list and filter_category and allow_list[filter_category] then
  local allowed = allow_list[filter_category]
  local filtered = {}
  for _, file_info in ipairs(results) do
    if filter_category == "context" then
      -- directory-name prefix match (already correct)
      ...
    else
      -- For other categories, check the filename directly
      if allowed[file_info.name] then
        table.insert(filtered, file_info)
      end
    end
  end
  return filtered
end
```
For `filter_category == "skills"` this falls into the `else` branch and tests
`allowed["SKILL.md"]` for every one of the 23 results — always `nil` — so `filtered` is always
`{}`. `artifacts.skills` (line 1033-1039 builds it from `skills_md`/`skills_yaml`, both scanned
via this same `sync_scan`) is therefore always empty, regardless of how many skills exist on
disk and are correctly declared in the manifest.

**This is silent** exactly as diagnosed: `execute_sync()`'s summary notification always prints
`Skills: 0` alongside nonzero counts for other categories, which reads as "there simply are no
skill changes this run," not as a filter failure.

### 2. Empirical reproduction (Scope A/E) — defect confirmed against a scratch tree

`M.scan_all_artifacts(global_dir, project_dir, config)` is the correct entry point for a
reproduction harness: it is a **public**, pure-scanning function with no interactive
`vim.fn.confirm()` and no file writes (those live in `execute_sync`/`sync_files`, called only
from `M.load_all_globally`, which the harness never calls). `scan_all_artifacts` internally
resolves the core manifest via `get_extension_config(base_dir, global_dir)` →
`ext_config.claude(global_dir)`, whose `global_extensions_dir` is
`global_dir .. "/agent-system/extensions"` (confirmed in
`lua/neotex/plugins/ai/shared/extensions/config.lua:66`) — so a scratch reproduction only needs
to mirror `<scratch>/agent-system/extensions/core/manifest.json` plus matching category
subdirectories under `<scratch>/agent-system/extensions/core/`.

Harness built and run (isolated `vim.fn.tempname()` root, deleted after run, real config
untouched):
```
<scratch>/agent-system/extensions/core/manifest.json   -- provides.skills = {"skill-alpha","skill-beta"}
                                                        -- provides.commands = {"hello.md"}
                                                        -- provides.agents = {"helper-agent.md"}
<scratch>/agent-system/extensions/core/skills/skill-alpha/SKILL.md
<scratch>/agent-system/extensions/core/skills/skill-beta/SKILL.md
<scratch>/agent-system/extensions/core/commands/hello.md
<scratch>/agent-system/extensions/core/agents/helper-agent.md
```
Call: `sync.scan_all_artifacts(scratch, project_dir, { base_dir = ".claude" })`

Observed output (via `nvim --headless -c "luafile ..." -c "qa!"`):
```
skills found (post-filter):   0
commands found (post-filter): 1
agents found (post-filter):   1
expected: skills=2 (BUG: currently 0), commands=1, agents=1
```
This matches the read-verified diagnosis exactly: the flat categories (`commands`, `agents`)
correctly pass 1/1, and `skills` — directory-shaped, 2 real files on disk, correctly declared in
the manifest — passes 0/2. **This is the "before-state" the VERIFICATION GAP asked for.** A
planner/implementer can reuse this exact harness shape as the reproduction step of an
implementation plan, or convert it into a `sync_spec.lua` following the existing
`scan_spec.lua` `describe`/`it`/`before_each`/`after_each` + `vim.fn.tempname()` pattern (that
spec file already exists at
`lua/neotex/plugins/ai/claude/commands/picker/utils/scan_spec.lua` and is the established,
in-repo convention for this exact kind of scratch-tree test — run via `:TestFile`). No
`sync_spec.lua` or `manifest_spec.lua` currently exists; adding one is the natural home for a
permanent regression test.

I also hand-traced the proposed generalized fix (see Finding 4) against this same scratch data
before recommending it: extracting the top-level path segment after `/skills/` yields
`"skill-alpha"` / `"skill-beta"`, both present in `allow_list.skills` — so the fix, applied to
this scratch tree, would flip the result to `skills found: 2`. For `commands`/`agents`, the same
generalized extraction on a file directly under the category subdir (no nesting) yields the
basename itself (`"hello.md"`, `"helper-agent.md"`), identical to the current lookup — no
regression.

### 3. Category shape survey (Scope C) — enumerated

Categories that pass `filter_category` into `sync_scan`'s post-filter (verified via the 7 call
sites in `M.scan_all_artifacts`, lines 1016-1058):

| Category | `provides` entry shape (verified) | On-disk nesting under `extensions/core/<cat>/` | Currently broken? |
|----------|-----------------------------------|--------------------------------------------------|--------------------|
| `commands` | Flat `.md` basenames (18 entries, e.g. `errors.md`) | None (no subdirs) | No |
| `agents` | Flat `.md` basenames (11 entries) | None (no subdirs) | No |
| `rules` | Flat `.md` basenames (10 entries, e.g. `artifact-formats.md`) | None (no subdirs) | No |
| `hooks` | Flat `.sh` basenames (19 entries) | None (no subdirs) | No |
| `scripts` | Flat `.sh` basenames (67 entries) | **Yes** — `scripts/tests/` and `scripts/lint/` exist on disk with 5 `.sh` files total, none of which appear in `provides.scripts` | No (see note below — different defect shape) |
| `skills` | **Directory names**, no extension (23 entries, e.g. `skill-orchestrate`) | Yes — every entry is a directory containing `SKILL.md` | **Yes — confirmed defect** |
| `context` | **Mixed**: some flat top-level files (`README.md`, `routing.md`, `validation.md`, `index.schema.json`) AND directory names (`architecture`, `patterns`, `contracts`, etc.) | Yes | No — already has bespoke correct handling (the `filter_category == "context"` branch) |

**`scripts` note**: `scripts/tests/*.sh` (3 files: `test-validate-no-task-references.sh`,
`test-orchestrate-triage-classify.sh`, `test-census-count.sh`) and `scripts/lint/*.sh` (2 files:
`lint-contract-compliance.sh`, `lint-postflight-boundary.sh`) are on disk but not declared in
`provides.scripts` at all. This is **not** the directory-vs-basename mismatch pattern (their
basenames are checked correctly by the current basename lookup, and correctly fail to match
because they are absent from the list, not because the lookup key is wrong). It reads as an
intentional omission — dev-only test/lint infrastructure not meant for deployment — but it is
worth flagging to the planner as a candidate for the zero-result-style visibility work in Finding
5, since it is the same *symptom family* (declared-but-silently-dropped) even though the
*mechanism* differs from the skills bug. Recommend noting it, not silently folding it into the
same fix, since folding it in either means declaring them in `provides.scripts` (deploying
dev-only test infra to every child repo) or explicitly documenting the omission — a product
decision, not a mechanical filter fix.

**Categories without a post-filter at all** (`docs`, `templates`, `systemd` — called via
`sync_scan("docs", "*.md")` etc. with no 5th argument, so `filter_category` is `nil`): these are
scanned unfiltered by design. This is a pre-existing, deliberate omission, not part of this
defect: `aggregate_extension_artifacts()`'s blocklist table (manifest.lua lines 236-245) doesn't
even have `docs`/`templates`/`systemd` keys, and all three read exclusively from
`core_source_base` (`extensions/core/…`), which is already scoped to core content only — there
is no extension-bleed risk to filter against. Recommend leaving these three categories
unfiltered; wiring them into the allow-list would be scope creep beyond what task 938 asks for
and beyond what "weakening the allow-list into a pass-through" warns against (they are already a
pass-through, safely, for a different reason).

### 4. Generalize-vs-third-branch (Scope B): generalize, confirmed low-risk

The existing `context` branch is structurally identical to what `skills` needs:
```lua
if filter_category == "context" then
  local rel_path = file_info.global_path:match("/context/(.+)$")
  if rel_path then
    local top_dir = rel_path:match("^([^/]+)")
    if top_dir and allowed[top_dir] then
      table.insert(filtered, file_info)
    end
  end
else
  if allowed[file_info.name] then
    table.insert(filtered, file_info)
  end
end
```
Every call site that passes a `filter_category` also passes that same string as the `subdir`
argument (verified across all 7 `sync_scan(...)` invocations with a non-nil `filter_category`:
`"commands"`/`"commands"`, `"agents"`/`agents_subdir`... — agents_subdir varies for `.opencode`
but is still the actual scan subdir, so the invariant holds — `"skills"`/`"skills"` (twice, for
`.md` and `.yaml`), `"hooks"`/`"hooks"`, `"scripts"`/`"scripts"`, `"rules"`/`"rules"`,
`"context"`/`"context"` (three times)). That means the hardcoded `"/context/"` substring in the
match pattern can be replaced with the dynamic `"/" .. filter_category .. "/"` and the special
case collapses into the single general rule:

```lua
local rel_path = file_info.global_path:match("/" .. filter_category .. "/(.+)$")
if rel_path then
  local top_dir = rel_path:match("^([^/]+)")
  if top_dir and allowed[top_dir] then
    table.insert(filtered, file_info)
  end
end
```
applied uniformly, with the `else` (pure-basename) branch removed entirely. For every currently-
flat category (`commands`, `agents`, `rules`, `hooks`) this generalized rule reduces to the
existing basename check, because a top-level file's `rel_path` (the text after
`/<category>/`) contains no `/`, so `top_dir == rel_path == file_info.name` exactly — verified by
hand-tracing the scratch-tree `hello.md` and `helper-agent.md` cases above. For `context` it
produces byte-identical results to today (only the anchor string changed from a literal to a
variable holding the same value at every call site). For `skills` it correctly extracts
`skill-alpha`/`skill-beta` (or the real `skill-orchestrate` etc.) as the lookup key instead of
`"SKILL.md"`.

This satisfies the task's explicit preference ("prefer generalizing the existing branch over
adding a third parallel one if that can be done without changing context behavior") and is
verified not to change `context` behavior or regress any currently-flat category, since none of
them has on-disk nesting today. `scripts`' two nested subdirectories (`tests/`, `lint/`) are
unaffected either way (their basenames are absent from `provides.scripts` regardless of which
lookup key — basename or top-level-segment — is tried, since `"tests"`/`"lint"` are equally
absent from that list).

### 5. Zero-result detection design (Scope D)

Recommend adding the check inside `sync_scan`, right after the `filtered` array is built and
just before its `return filtered` (i.e., the same place regardless of whether Finding 4's
generalization or a narrower fix is chosen):

```lua
if allow_list and filter_category and allow_list[filter_category] then
  local allowed = allow_list[filter_category]
  local filtered = { ... }  -- built as above

  if #results > 0 and #filtered == 0 then
    helpers.notify(
      string.format(
        "Sync allow-list filter dropped ALL %d scanned '%s' file(s) -- this is a defect "
          .. "signature (a working allow-list still passes some declared files through), "
          .. "not a legitimate empty category. Check that manifest.json's provides.%s "
          .. "entries match the actual lookup key (directory name vs. basename) used for "
          .. "this category's files.",
        #results, filter_category, filter_category
      ),
      "WARN"
    )
  end

  return filtered
end
```
Design rationale:
- **Trigger condition is `#results > 0 and #filtered == 0`** (total wipeout), not "any files
  dropped." A category correctly excluding *some* files (e.g. an extension-provided skill or
  command sharing the same on-disk category that isn't in the core allow-list) is completely
  normal — that is the allow-list's entire purpose — and must not warn. Only "the filter found
  candidates but the category came back completely empty" is a reliable defect signature; the
  repro in Finding 2 is exactly this shape (`2 -> 0`), and no false positive was observed for any
  of the currently-correct categories during that same run.
- **Non-blocking**, matching every other post-sync diagnostic already in this file
  (`run_contract_drift_validator`, `audit_synced_content`, the "No global artifacts found" /
  "already in sync" notices) — it reports, it never prevents the sync or mutates anything.
  `helpers` is already required at the top of `sync.lua` (line 15), so no new dependency.
- **Placed at scan time** (inside `sync_scan`, called from `scan_all_artifacts`), so it fires
  before any file is written — the earliest possible point, and it fires identically whether
  `scan_all_artifacts` is invoked via the interactive `load_all_globally` picker action or via a
  future headless/test caller (like the reproduction harness in Finding 2), which is exactly what
  "would have caught the bug years earlier" requires.

## Decisions

- Recommend the **generalized single-branch** fix over a third parallel branch, per Finding 4 —
  it is provably behavior-preserving for every currently-correct category and fixes `skills`.
- Recommend leaving `docs`/`templates`/`systemd` unfiltered (no `filter_category` added) — this
  is a pre-existing, safe design choice unrelated to the reported defect, and wiring them in
  would be unrequested scope expansion.
- Recommend flagging (not silently fixing) the `scripts/tests/` and `scripts/lint/` omission
  from `provides.scripts` as a separate, narrower, product-decision item for the planner to
  triage — it shares the "declared coverage doesn't match reality" symptom family but not the
  directory-vs-basename mechanism, and folding an undeclared-dev-infra decision into a filter-
  logic bugfix risks scope creep.
- Recommend the zero-result detector trigger on total wipeout only (`#results>0 and
  #filtered==0`), not partial reduction, to avoid false positives on ordinary allow-list
  exclusions.

## Risks & Mitigations

- **Risk**: generalizing the match pattern to use `filter_category` as the anchor string assumes
  `subdir == filter_category` holds at every call site forever. **Mitigation**: this invariant is
  verified for all 7 current call sites (Finding 4); a planner/implementer should add a comment
  next to the generalized branch stating this invariant explicitly, and/or an `assert`/defensive
  fallback (e.g., if the match fails, fall back to the basename check) so a future call site that
  violates the invariant degrades to today's basename behavior rather than silently dropping
  everything again.
- **Risk**: a deliberate redeploy (Scope E) after the fix must confirm the previously
  hand-corrected orchestrator skills (`skill-orchestrate`, `skill-orchestrate-hard`, called out
  in the task description as "found stale by hundreds of lines") land correctly and are not
  reverted to a stale version by the newly-fixed sync. **Mitigation**: the implementer should
  diff those two `SKILL.md` files pre- and post-redeploy against their source-store originals in
  `agent-system/extensions/core/skills/skill-orchestrate{,-hard}/SKILL.md` — since the source
  store is presumably already up to date (that is *why* they were hand-corrected to match it),
  a correct redeploy should reproduce the hand-corrected content byte-for-byte, not something
  older. Verify this explicitly rather than assuming.
- **Risk**: this task's file scope is `sync.lua`, `manifest.lua`, `scan.lua` only. The
  `scripts/tests`+`scripts/lint` omission finding and the "docs/templates/systemd unfiltered by
  design" finding both live in files already in scope for reading but any *fix* to either would
  be outside the stated defect (allow-list drops skills) — flagged as informational for the
  planner to explicitly accept/reject as separate follow-up items, not silently rolled in.

## Appendix

### Reproduction harness (reusable, read-only against real config)

Full script (already run and cleaned up; safe to re-run, self-contained, deletes its own scratch
tree):
```
/tmp/claude-1000/-home-benjamin--config-nvim/5b392e1d-79f6-497b-b0e1-40d1210fe466/scratchpad/repro_skills_filter.lua
```
Invocation used:
```bash
nvim --headless -c "luafile <path-above>" -c "qa!"
```
Output observed:
```
=== REPRODUCTION RESULT ===
skills found (post-filter):   0
commands found (post-filter): 1
agents found (post-filter):   1
expected: skills=2 (BUG: currently 0), commands=1, agents=1
```

### Files read (verbatim-quoted in Findings above)

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (full file, 1614 lines)
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` (full file, 297 lines)
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` (full file, 304 lines)
- `agent-system/extensions/core/manifest.json` (`provides` section, all 12 categories)
- `lua/neotex/plugins/ai/shared/extensions/config.lua` (full file, 90 lines — `global_extensions_dir` resolution)
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan_spec.lua` (existing test harness precedent)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (orchestrator handoff schema, for this report's own handoff write)

### Existing test infrastructure note

No `sync_spec.lua` or `manifest_spec.lua` currently exists anywhere in the repo (verified via
targeted search). `scan_spec.lua` is the sole precedent and uses plain `describe`/`it`/
`before_each`/`after_each` with `vim.fn.tempname()` + `vim.fn.mkdir(..., "p")` + `vim.fn.writefile`,
run via `:TestFile`/`:TestSuite`. The planner should consider adding a `sync_spec.lua` (or
extending `manifest_spec.lua` if one is created) that codifies the scratch-tree shape from the
Appendix's reproduction script as a permanent regression test for this defect, following that
exact established convention.
