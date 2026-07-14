# Research Report: Rule Drift Check for Extension Lint

**Task**: 861 - Add a deployed-vs-source content drift check for extension rules in check-extension-docs.sh
**Started**: 2026-07-14
**Completed**: 2026-07-14
**Effort**: Small (mirrors an existing, well-understood pattern)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.claude/scripts/check-extension-docs.sh`, `.claude/extensions/*/manifest.json`,
  `lua/neotex/plugins/ai/shared/extensions/loader.lua`, `.claude/docs/guides/creating-extensions.md`
- Live filesystem inspection: `.claude/rules/`, `.claude/agents/`, `.claude/commands/`,
  `.claude/context/`, `.claude/skills/` (symlink vs. copy census)
**Artifacts**: This report
**Standards**: report-format.md, artifact-formats.md

## Executive Summary

- `check_deployed_script_drift` is a ~24-line function with a simple, reusable shape: enumerate
  `manifest.provides.scripts`, resolve deployed (`$REPO_ROOT/.claude/scripts/$name`) and source
  (`$ext_path/scripts/$name`) paths, skip (info, never fail) when the deployed copy is absent,
  and `cmp -s` the two when both exist. `check_deployed_rule_drift` should be a near-verbatim
  copy of this function with `scripts` swapped for `rules`.
- The two deployed copies of `check-extension-docs.sh` (`.claude/scripts/` and
  `.claude/extensions/core/scripts/`) are currently byte-identical — no pre-existing drift to
  clean up before this change lands.
- **No live rule drift exists today.** All 8 currently-deployed `provides.rules` entries
  (all from `core`, plus `nix.md` and `neovim-lua.md`) match their extension source exactly. The
  motivating case — `core/rules/pr-prohibition.md` accumulating 35 undeployed lines — was already
  fixed by a prior commit (`c679fd543`, "meta: add disk->manifest reverse check for extension
  rules") that added `check_undeclared_rules` (the reverse/registration check). This task's drift
  check is the complementary forward-direction guard: it prevents the *next* occurrence of the
  same failure mode now that all rules are properly registered and therefore overwritten by the
  loader on every sync.
- **Deployment mechanism is copy, not symlink, for every currently-deployed rule.** Every file
  under `.claude/rules/` is a regular file (0 symlinks). This makes `provides.rules` fully exposed
  to the drift risk the check is meant to catch — unlike `provides.agents`, `provides.commands`,
  and `provides.skills`, which contain a mix of copies and symlinks (see below), where symlinked
  entries are structurally immune to drift.
- The same deployed-vs-source asymmetry **does** apply to `provides.agents` and
  `provides.commands` (for their copied — non-symlinked — subset), and in principle to
  `provides.context`, but `context` entries can be directories requiring recursive comparison,
  not single files. Recommendation: implement `check_deployed_rule_drift` now as a close mirror
  of the script check (matches the task's file scope and the existing pattern exactly); treat a
  shared parameterized helper covering rules+scripts+commands+agents as a follow-up, and leave
  `context` out of any such helper because its recursive-directory shape is genuinely different.
- Self-referential hazard confirmed: `check-extension-docs.sh` itself is declared in `core`'s
  `provides.scripts` (`"check-extension-docs.sh"` is present in
  `.claude/extensions/core/manifest.json`'s `provides.scripts` array), so `check_deployed_script_drift`
  already treats the script's own two deployed copies as a drift-checkable pair. Any edit to this
  task's target file must be written identically to both `.claude/scripts/check-extension-docs.sh`
  and `.claude/extensions/core/scripts/check-extension-docs.sh`, or the script will fail its own
  next run.

## Context & Scope

The task asks for a new `check_deployed_rule_drift` function in `check-extension-docs.sh`,
mirroring the existing `check_deployed_script_drift`, plus an evaluation of whether the same
deployed-vs-source drift risk applies to `provides.agents`, `provides.commands`, and
`provides.context`, and whether a single parameterized helper is warranted over near-duplicate
functions.

## Findings

### Codebase Patterns

#### `check_deployed_script_drift` structure (the pattern to mirror)

Located at `.claude/scripts/check-extension-docs.sh:146-170` (identical in
`.claude/extensions/core/scripts/check-extension-docs.sh`):

```bash
check_deployed_script_drift() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  local scripts
  scripts=$(jq -r '.provides.scripts[]? // empty' "$manifest" 2>/dev/null)
  local s deployed source
  for s in $scripts; do
    deployed="$REPO_ROOT/.claude/scripts/$s"
    source="$ext_path/scripts/$s"

    if [[ ! -f "$deployed" ]]; then
      info "script not deployed, skipping drift check: $s"
      continue
    fi
    if [[ ! -f "$source" ]]; then
      # Already reported by check_manifest_entries; do not double-report here.
      continue
    fi

    if ! cmp -s "$deployed" "$source"; then
      fail "deployed script content drift (deployed != extension source): scripts/$s"
    fi
  done
}
```

Key mechanics, all directly reusable for rules:
- **Enumeration**: `jq -r '.provides.<category>[]? // empty' "$manifest"` over the current
  extension's manifest (the function is called once per extension inside the `for ext_path in
  "$EXT_DIR"/*/` loop at line 531, alongside the other per-extension checks at lines 546-554).
- **Path resolution**: deployed = `$REPO_ROOT/.claude/<category>/<name>` (flat, no subdirectory
  nesting); source = `$ext_path/<category>/<name>` (also flat). Both `scripts/` and `rules/`
  entries are stored as flat filenames in `provides.*` (confirmed: `provides.rules` entries in
  every manifest surveyed are bare filenames like `"pr-prohibition.md"`, never paths with `/`).
- **Comparison**: `cmp -s "$deployed" "$source"` — byte-for-byte, silent, exit-status-only.
- **Reporting contract**: three outcomes only —
  1. deployed absent -> `info` (never fail) — extension not installed in this repo, expected.
  2. source absent -> silent `continue` — already reported by `check_manifest_entries`'s forward
     existence check (lines 98-105 for rules), avoiding double-reporting.
  3. both present but differ -> `fail` (increments `$FAILURES`, sets
     `EXTENSION_STATUS[$CURRENT_EXT]=FAIL`, contributing to the script's overall exit-code
     contract at lines 587-593: exit 1 if `$FAILURES > 0`, else exit 0).
- **Wiring**: called from the per-extension dispatch block (`.claude/scripts/check-extension-docs.sh:544-558`),
  gated behind `jq empty "$manifest" 2>/dev/null` (valid-JSON check), alongside
  `check_manifest_entries`, `check_deployed_script_drift`, `check_routing_block`,
  `check_undeclared_skills`, `check_undeclared_rules`, `check_routing_consistency`,
  `check_deployed_skill_agents`, `check_readme_vs_manifest`, `check_referenced_scripts_declared`.
  A new `check_deployed_rule_drift "$ext_path"` call belongs in this same list, most naturally
  placed adjacent to `check_undeclared_rules` (the sibling rules-category check) or adjacent to
  `check_deployed_script_drift` (the sibling drift check) — either position is correct since the
  block is a flat sequence with no ordering dependency between checks.

#### Two-copy identity verification

`diff .claude/scripts/check-extension-docs.sh .claude/extensions/core/scripts/check-extension-docs.sh`
produces no output — the files are byte-identical (593 lines each). No existing drift to reconcile
before adding the new check.

#### Manifest survey: `provides.*` counts and deployment convention per category

Surveyed all 20 extensions under `.claude/extensions/*/manifest.json`
(core, cslib, email, epidemiology, filetypes, formal, founder, latex, lean, literature, memory,
nix, nvim, present, python, slidev, typst, web, z3, plus a stray `README.md` in the extensions
directory that is not an extension). Category totals across all manifests:

| Category | Extensions declaring it | Total entries (sum) | Deployed-path convention | Deployment mechanism |
|----------|--------------------------|----------------------|---------------------------|------------------------|
| `agents` | 16 | ~74 | `.claude/agents/<name>.md` (flat; `agents_subdir` override exists for OpenCode's `agent/subagents` layout, per `loader.lua:148`) | **Mixed**: mostly copy; 7 of 30 deployed agent files are symlinks (all `cslib` + 2 `pr-review-*` agents) pointing into their extension source |
| `commands` | 10 | ~46 | `.claude/commands/<name>.md` (flat) | **Mixed**: mostly copy; 3 of 30 deployed command files are symlinks (`pr.md`, `vet.md` -> cslib source; `zotero.md` -> **dangling**, see note below) |
| `rules` | 8 | 16 | `.claude/rules/<name>.md` (flat) | **Copy only** — 0 symlinks found among the 11 files in `.claude/rules/` |
| `context` | 20 (all) | ~40 | `.claude/context/<entry>` where `<entry>` may be a file (e.g. `README.md`) or a directory (e.g. `project/your-domain`, `contracts`), copied recursively via `copy_context_dirs()` | **Copy only** — 0 symlinks found anywhere under `.claude/context/` |
| `scripts` | 4 (core, email, lean, literature) | 75 | `.claude/scripts/<name>` (flat) | Copy (this is the category the existing check already covers) |
| `skills` | 16 | ~74 | `.claude/skills/<name>/` (directory, recursive via `copy_skill_dirs()`) | **Mixed**: 10 of 45 deployed skill directories are symlinks (cslib's 5 skills, `skill-literature`, `skill-zotero` [dangling], `skill-pr-implementation`, `skill-pr-review-implementation`, `skill-pr-review-research`) |
| `hooks` | 3 (core, email) | 17 | `.claude/hooks/<name>` | Copy (`copy_hooks()`) |

**Deployment mechanism confirmed at the code level**: `loader.lua`'s `copy_simple_files()`
(used for `agents`, `commands`, `rules` — see the function's own doc comment at
`loader.lua:126`, "Copy simple files (agents, commands, rules)") and `copy_context_dirs()` (for
`context`) both call the shared `copy_file()` helper (`loader.lua:54-82`), which does
`helpers.read_file(source_path)` then `helpers.write_file(target_path, content)`
(`vim.fn.writefile`, which follows symlinks and writes through to the link target rather than
replacing the link). This means:
- **Symlinked entries can never drift** — reading and writing through a symlink whose target
  *is* the source file is a self-referential no-op; source and "deployed" are the same inode.
  This is presumably why `cslib`, `pr-review-*`, and `literature`'s deployed agents/commands/skills
  are set up as symlinks in the first place (eliminates the sync/overwrite hazard entirely for
  those entries, at the cost of coupling the deployed copy 1:1 to a single extension source with
  no possibility of a repo-local hotfix).
- **Copied entries are always exposed to drift** — every `rules` entry, most `agents`/`commands`
  entries, and every `context` entry go through byte-for-byte overwrite-on-sync, so any of them
  can silently accumulate undeployed local edits exactly as `pr-prohibition.md` did.

**Aside (out of this task's scope, surfaced incidentally by the symlink census)**: `.claude/commands/zotero.md`
and `.claude/skills/skill-zotero` are dangling symlinks pointing at
`.claude/extensions/zotero/...`, which no longer exists — the `zotero` extension was absorbed
into `literature` (per `.claude/CLAUDE.md`'s "Literature Extension" section: "Absorbs the former
zotero extension"). These are orphaned deployment artifacts, not a drift-check gap; a drift check
would not catch this because `-f` and `-e` tests both fail (broken symlinks are not regular
files), matching the "deployed absent, skip" branch of the pattern. Worth a separate cleanup task
if desired, but not part of this task's file scope.

#### `provides.rules` empirical drift census (the task's core empirical payload)

Enumerated every extension's `provides.rules` and checked deployed-vs-source for each entry where
both exist:

| Extension | Rule | Deployed exists? | Source exists? | Result |
|-----------|------|-------------------|------------------|--------|
| core | `artifact-formats.md` | yes | yes | MATCH |
| core | `error-handling.md` | yes | yes | MATCH |
| core | `git-workflow.md` | yes | yes | MATCH |
| core | `plan-format-enforcement.md` | yes | yes | MATCH |
| core | `pr-prohibition.md` | yes | yes | MATCH (previously drifted 35 lines; already reconciled) |
| core | `state-management.md` | yes | yes | MATCH |
| core | `workflows.md` | yes | yes | MATCH |
| core | `project-overview-detection.md` | yes | yes | MATCH |
| cslib | `cslib.md` | no | yes | not deployed (expected — cslib not installed's rules dir has this, but no deployed copy in this repo) |
| cslib | `cslib-lint-fix.md` | no | yes | not deployed |
| latex | `latex.md` | no | yes | not deployed |
| lean | `lean4.md` | no | yes | not deployed |
| lean | `plan-compliance.md` | no | yes | not deployed |
| nix | `nix.md` | yes | yes | MATCH |
| nvim | `neovim-lua.md` | yes | yes | MATCH |
| web | `web-astro.md` | no | yes | not deployed |

**Result: zero current drift.** Every rule that is both declared in `provides.rules` and
currently deployed matches its extension source byte-for-byte. This confirms the check being
added is purely preventive (guards against future silent drift) rather than needed to surface an
existing, uncaught defect — the one known historical instance was already fixed by the separate
`check_undeclared_rules` addition in commit `c679fd543`.

### Parameterization Question — Evidence and Recommendation

**Do the categories share path-resolution logic?**
- `rules`, `scripts`, and `commands` are structurally identical for this purpose: flat filename
  entries in `provides.<category>`, deployed at `$REPO_ROOT/.claude/<category>/<name>`, sourced
  at `$ext_path/<category>/<name>`. A single helper parameterized only by category name would
  work unmodified for all three: `check_deployed_content_drift() { local ext_path=$1 category=$2 ...}`.
- `agents` is *almost* identical but has one real wrinkle: `copy_simple_files()` supports an
  `agents_subdir` override (`loader.lua:148`, used for OpenCode's `.opencode/agent/subagents/`
  layout vs. Claude Code's flat `.claude/agents/`). A parameterized helper would need an optional
  fourth argument for this, but that is a small, contained addition — not a fundamentally
  different resolution shape.
- `context` is genuinely different: entries can be either a single file or a directory
  (`copy_context_dirs()` recurses — see `loader.lua:242-291` and the doc comment's own example,
  `"context": ["project/your-domain"]`, which is a directory). A drift check for `context` would
  need to either recursively `diff -rq` directory entries or enumerate files within each entry
  before comparing — this is materially more logic than `cmp -s` on a single path, and mixing it
  into a single-file-oriented helper via more `if [[ -d ]]` branching would make the "helper"
  wider than the sum of its per-category call sites.

**Recommendation**: implement `check_deployed_rule_drift` now as a close mirror of
`check_deployed_script_drift` (matches this task's file scope, matches the existing established
pattern exactly, smallest possible diff, zero risk of behavior regression in the already-shipped
script check). Treat "extract a shared `check_deployed_content_drift(ext_path, category)` helper
covering `rules` + `scripts` + `commands` (+ `agents` with a subdir parameter)" as a reasonable
**follow-up**, not part of this task — three to four near-duplicate ~15-line functions is not
egregious duplication, and premature parameterization before `commands`/`agents` drift checks are
actually requested would add abstraction with no second caller yet. Do **not** fold `context`
into any such helper; its recursive-directory semantics warrant a distinct function if/when a
context drift check is requested.

### Self-Referential Hazard

Confirmed: `"check-extension-docs.sh"` is present in `.claude/extensions/core/manifest.json`'s
`provides.scripts` array. This means `check_deployed_script_drift`, on every run, already
compares `.claude/scripts/check-extension-docs.sh` against
`.claude/extensions/core/scripts/check-extension-docs.sh` and will `fail` if they differ.

**Correct edit procedure for this task**: any change to the script's logic (including adding
`check_deployed_rule_drift`) must be written identically to both:
- `.claude/scripts/check-extension-docs.sh` (deployed)
- `.claude/extensions/core/scripts/check-extension-docs.sh` (extension source)

The simplest safe sequence is: edit one copy fully, verify it, then overwrite the other with
identical content (e.g. `cp` one onto the other, or apply the identical edit twice) — never land
the edit in only one location, or the script's own next run will report a `FAIL: deployed script
content drift ... scripts/check-extension-docs.sh` against itself.

## Decisions

- Add `check_deployed_rule_drift()` as a near-verbatim mirror of `check_deployed_script_drift()`,
  substituting `rules` for `scripts` throughout (function body, path variables, info/fail message
  text). Same three-way outcome contract: deployed-absent -> info/skip, source-absent -> silent
  continue (already reported by `check_manifest_entries`), both-present-and-differ -> fail.
- Wire the new function into the per-extension dispatch list at
  `.claude/scripts/check-extension-docs.sh:544-558`, alongside the other `provides.rules`-related
  check (`check_undeclared_rules`).
- Do not implement a parameterized cross-category helper in this task; keep the four
  drift-check functions (existing script check + new rule check, and any future
  agents/commands checks) as intentionally near-duplicate, easy-to-audit functions. Revisit
  parameterization only if/when a third or fourth category drift check is actually requested.
- Do not implement a `context` drift check in this task — its recursive file-or-directory
  resolution shape is a different problem and out of the stated file scope.
- Edit must be applied identically to both `.claude/scripts/check-extension-docs.sh` and
  `.claude/extensions/core/scripts/check-extension-docs.sh` in the same change, per the
  self-referential hazard above.

## Risks & Mitigations

- **Risk**: forgetting to sync the second copy of `check-extension-docs.sh`, causing the script
  to fail against itself on the very next run. **Mitigation**: documented explicitly above;
  implementer should `diff` the two copies as a final verification step before considering the
  task done, matching how this research verified they started identical.
- **Risk**: false positives against dangling symlinks (e.g. a future `provides.rules` entry
  deployed as a broken symlink). **Mitigation**: none needed — `[[ ! -f "$deployed" ]]` already
  returns true for a dangling symlink (fails the `-f` regular-file test), so it correctly falls
  into the "not deployed, skip" branch rather than being misread as content drift.
- **Risk**: none identified regarding false negatives — `cmp -s` correctly detects any byte-level
  difference regardless of symlink status on either side (it dereferences symlinks by default).

## Context Extension Recommendations

None — this is a self-contained lint-script change fully covered by the existing
`check-extension-docs.sh` doc comment block (lines 1-19) and the "Field Reference" table in
`.claude/docs/guides/creating-extensions.md`. No new context files are warranted.

## Appendix

### Search queries / commands used
- `diff` of the two `check-extension-docs.sh` copies (confirmed identical)
- `jq -r '.provides | to_entries[] | "\(.key): \(.value | length)"'` over all 20 extension
  manifests
- Symlink census: `find ... -type l` / per-file `[[ -L ]]` checks across `.claude/rules/`,
  `.claude/agents/`, `.claude/commands/`, `.claude/context/`, `.claude/skills/`
- Per-entry `provides.rules` deployed-vs-source `cmp -s` loop (the empirical drift census)
- `grep`/`Read` of `loader.lua`'s `copy_file`, `copy_simple_files`, `copy_context_dirs` to confirm
  the copy-vs-symlink deployment mechanism at the code level
- Confirmed `check-extension-docs.sh` self-registration via
  `jq -r '.provides.scripts[]?' core/manifest.json | grep check-extension`

### References
- `.claude/scripts/check-extension-docs.sh` (and its identical extension-source twin)
- `.claude/extensions/*/manifest.json` (20 extensions surveyed)
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` (copy/deploy mechanism)
- `.claude/docs/guides/creating-extensions.md` (manifest schema reference)
- Prior fix: commit `c679fd543`, "meta: add disk->manifest reverse check for extension rules"
  (added `check_undeclared_rules`, the reverse-direction registration check that fixed the
  `pr-prohibition.md` motivating case)
