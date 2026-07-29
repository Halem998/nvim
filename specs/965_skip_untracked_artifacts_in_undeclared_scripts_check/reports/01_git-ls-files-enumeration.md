# Research Report: Task #965

**Task**: 965 - skip_untracked_artifacts_in_undeclared_scripts_check
**Started**: 2026-07-29T00:00:00Z
**Completed**: 2026-07-29T00:00:00Z
**Effort**: small (single-function fix, empirically pre-verified)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/check-extension-docs.sh`
- Empirical bash simulation against the live repo (git ls-files vs find, all extensions)
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `check_undeclared_scripts()` (Rule Q, lines 521-547 of
  `agent-system/extensions/core/scripts/check-extension-docs.sh`) enumerates with
  `find "$ext_path_norm/scripts" -type f`, which walks the working tree and therefore picks up
  gitignored/untracked build artifacts (confirmed live: two `__pycache__/*.pyc` files under the
  `literature` extension's `scripts/` tree cause permanent, unfixable `fail` calls).
- The sibling check `check_flat_category_orphans()` already solves this exact problem via its
  `_git_deployed_files()` helper (line 891), which uses `git -C "$REPO_ROOT" ls-files` instead of
  `find`. The fix for Rule Q is to apply the same enumeration method, not to redesign anything.
- **Critical non-obvious detail, verified empirically**: `git -C "$REPO_ROOT" ls-files <pathspec>`
  always returns **REPO_ROOT-relative** paths (e.g.
  `agent-system/extensions/literature/scripts/.zotero-title-sim.py`), regardless of whether the
  pathspec passed to it is absolute or relative to cwd. This is a different path shape than what
  `find` returned (absolute paths), so the existing prefix-strip
  (`rel_path="${script_file#"$ext_path_norm"/scripts/}"`, using the absolute `ext_path_norm`)
  will silently produce a non-match (empty strip, i.e. `rel_path` stays equal to the full
  REPO_ROOT-relative `script_file`) if reused unchanged with `git ls-files` output. The prefix
  must be re-derived as `ext_path_norm` **relative to `$REPO_ROOT`** (`ext_rel`), not reused as
  the absolute form.
- I simulated the exact proposed replacement (git ls-files enumeration + re-derived REPO_ROOT-
  relative prefix-strip) against the live repo for every extension with a `scripts/` directory:
  only `literature` shows a diff from the current `find`-based output, and that diff is precisely
  the removal of the two spurious `__pycache__/*.pyc` `fail`s — zero new findings introduced,
  zero existing legitimate findings lost. This is a positive control confirming the fix is both
  necessary and correct with no regressions.
- Recommended approach: minimal, surgical replacement of the enumeration line and prefix-strip
  logic only. All other behavior (full relative-path matching, no `*.sh` glob restriction,
  `deprecated/*` exemption, `tests/` non-exemption, trailing-slash normalization of `ext_path`)
  is preserved unchanged.

## Context & Scope

Task 965 requires fixing `check_undeclared_scripts()` so gitignored/untracked runtime artifacts
(CPython `__pycache__/*.pyc` caches observed live under the `literature` extension) no longer
cause a permanent, unfixable hard FAIL in the doc-lint gate `check-extension-docs.sh`. The task
description names the exact already-chosen fix pattern (`_git_deployed_files()`'s `git ls-files`
approach, already used by the sibling `check_flat_category_orphans()`) and explicitly forbids
redesigning it. Scope is limited to `agent-system/extensions/core/scripts/check-extension-docs.sh`
per `file_scope`. Per the source-store/deploy-boundary rule, the edit target is the
`agent-system/extensions/core/**` source-store copy, never the gitignored, disposable
`.claude/**` deploy artifact (runtime invocations reference `.claude/scripts/*`, but that is the
call path, not the edit target).

## Findings

### Codebase Patterns

**Current implementation** (`check_undeclared_scripts`, lines 521-547):

```bash
check_undeclared_scripts() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  [[ -d "$ext_path/scripts" ]] || return 0

  local ext_path_norm="${ext_path%/}"

  local script_file rel_path
  while IFS= read -r script_file; do
    [[ -f "$script_file" ]] || continue
    rel_path="${script_file#"$ext_path_norm"/scripts/}"

    case "$rel_path" in
      deprecated/*) continue ;;
    esac

    if ! jq -e --arg s "$rel_path" '.provides.scripts[]? | select(. == $s)' \
        "$manifest" > /dev/null 2>&1; then
      fail "script file on disk NOT in provides.scripts: scripts/$rel_path"
    fi
  done < <(find "$ext_path_norm/scripts" -type f | sort)
}
```

**Sibling pattern already solving this** (`_git_deployed_files`, lines 888-894):

```bash
# Enumeration method: git ls-files (not find), matching the research audit method -- naturally
# excludes gitignored runtime artifacts (literature-pyenv/venv/, __pycache__/) without extra
# path filtering, since they were never tracked.
_git_deployed_files() {
  local category="$1"
  git -C "$REPO_ROOT" ls-files ".claude/$category" 2>/dev/null
}
```

`REPO_ROOT` is defined at line 82 as `${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}`
— always an absolute path with no trailing slash. `EXT_DIR="${EXT_DIR:-$REPO_ROOT/agent-system/extensions}"`
(line 83), and the caller's loop is `for ext_path in "$EXT_DIR"/*/` (line 1024), so `ext_path`
is always absolute with a trailing slash.

### Path-shape verification (empirical)

Ran `git -C "$REPO_ROOT" ls-files "$REPO_ROOT/agent-system/extensions/literature/scripts"` and
`git -C "$REPO_ROOT" ls-files "agent-system/extensions/literature/scripts"` (absolute vs.
relative pathspec) — **both produce identical, REPO_ROOT-relative output**:

```
agent-system/extensions/literature/scripts/.zotero-title-sim.py
agent-system/extensions/literature/scripts/cite-extract.sh
agent-system/extensions/literature/scripts/deprecated/README.md
...
```

This confirms `git ls-files` output shape is independent of the pathspec's own absolute/relative
form, but is NOT the same shape `find` produced (which mirrors whatever form the search root
argument took — here, always absolute, since `ext_path_norm` is absolute). The task description's
warning to "re-verify this holds against whatever path form `git ls-files` returns... the
prefix-strip logic must be re-derived for the new form, not copied blindly" is therefore correct
and load-bearing — a naive copy-paste of the existing prefix-strip (unmodified, still stripping
the absolute `ext_path_norm` prefix) would silently degrade to reporting every script in every
extension as undeclared (the exact failure mode the existing code comment above the current
`ext_path_norm` line warns about for the trailing-slash case, but here triggered by the prefix's
absolute-vs-relative form instead).

Confirmed live: the two known-bad artifacts exist untracked on disk and are correctly excluded by
`git ls-files`:

```
agent-system/extensions/literature/scripts/__pycache__/literature-decode-font-offset.cpython-313.pyc
agent-system/extensions/literature/scripts/tests/__pycache__/generate-test-fixtures.cpython-313.pyc
```

### Recommendation: minimal replacement

```bash
check_undeclared_scripts() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  [[ -d "$ext_path/scripts" ]] || return 0

  # Trailing-slash normalization: the caller's per-extension loop is `for ext_path in
  # "$EXT_DIR"/*/`, so ext_path carries a trailing slash. Left unstripped, the prefix-strip
  # below would build a double-slash prefix ("ext//scripts/") that never matches what
  # `git ls-files` returns, degrading this check to reporting every script in every extension
  # as undeclared.
  local ext_path_norm="${ext_path%/}"

  # git ls-files (run via `-C "$REPO_ROOT"`) always returns REPO_ROOT-relative paths regardless
  # of whether the pathspec passed to it is absolute or relative -- a different shape than the
  # absolute paths `find` returned. The prefix-strip must therefore be re-derived against
  # ext_path_norm's REPO_ROOT-relative form (ext_rel), not its absolute form.
  local ext_rel="${ext_path_norm#"$REPO_ROOT"/}"

  local script_file rel_path
  while IFS= read -r script_file; do
    [[ -f "$REPO_ROOT/$script_file" ]] || continue
    rel_path="${script_file#"$ext_rel"/scripts/}"

    case "$rel_path" in
      deprecated/*) continue ;;
    esac

    if ! jq -e --arg s "$rel_path" '.provides.scripts[]? | select(. == $s)' \
        "$manifest" > /dev/null 2>&1; then
      fail "script file on disk NOT in provides.scripts: scripts/$rel_path"
    fi
  done < <(git -C "$REPO_ROOT" ls-files "$ext_path_norm/scripts" | sort)
}
```

Changes from current code, precisely scoped:
1. New `ext_rel` local: `ext_path_norm` re-expressed relative to `$REPO_ROOT` (mirrors the
   `_git_deployed_files` pattern's REPO_ROOT-relative assumption).
2. Existence guard changed from `[[ -f "$script_file" ]]` to `[[ -f "$REPO_ROOT/$script_file" ]]`
   because `$script_file` is now REPO_ROOT-relative, not absolute (matches
   `check_flat_category_orphans`'s analogous `full="$REPO_ROOT/$rel"` / `[[ -f "$full" ]]` pattern
   at lines 920/925).
3. Prefix-strip changed from `"${script_file#"$ext_path_norm"/scripts/}"` (absolute prefix) to
   `"${script_file#"$ext_rel"/scripts/}"` (REPO_ROOT-relative prefix) — this is the load-bearing
   re-derivation the task description calls out.
4. Enumeration source changed from `find "$ext_path_norm/scripts" -type f` to
   `git -C "$REPO_ROOT" ls-files "$ext_path_norm/scripts"` — either the absolute or the
   REPO_ROOT-relative form of the pathspec works identically for `git ls-files` (verified above),
   so `$ext_path_norm` (already in scope) can be passed as-is with no extra conversion needed.

Everything else is untouched: no `*.sh` glob is introduced (git ls-files enumerates all regular
tracked file types, matching the "all file types in scope" requirement), the `deprecated/*` case
exemption is unchanged, `tests/` remains non-exempt (no code path treats it specially), and the
trailing-slash normalization comment/line for `ext_path` is preserved verbatim (it is still
needed independent of the enumeration-method change, since `ext_path_norm` is used both in the
`git ls-files` pathspec and to derive `ext_rel`).

### Regression check across all extensions (empirical)

Simulated both the current (`find`-based) and proposed (`git ls-files`-based) logic for every
extension directory containing a `scripts/` tree, diffing the resulting undeclared-script sets:

```
=== literature : DIFF ===
1,2c1
< __pycache__/literature-decode-font-offset.cpython-313.pyc
< tests/__pycache__/generate-test-fixtures.cpython-313.pyc
---
>
=== scan complete ===
```

Only `literature` differs, and the diff is exactly the two known-bad spurious entries being
removed — no extension gains a new false-positive or loses a legitimate finding. This is strong
empirical confirmation the fix is both necessary (reproduces the reported bug under current code)
and correct (eliminates it under the proposed code) with zero collateral impact.

## Decisions

- **Enumeration method**: `git -C "$REPO_ROOT" ls-files "$ext_path_norm/scripts"`, matching
  `_git_deployed_files()`'s established pattern. Not reusing `_git_deployed_files()` itself
  (it is `.claude/$category`-scoped, i.e. deployed-file-driven) — `check_undeclared_scripts` is
  disk/source-driven (extension's own `scripts/` tree), a structurally different input, so a
  new inline `git -C "$REPO_ROOT" ls-files ...` call is correct rather than a shared helper.
- **Prefix-strip re-derivation**: introduce `ext_rel="${ext_path_norm#"$REPO_ROOT"/}"` rather than
  converting `git ls-files` output to absolute paths (e.g. via `realpath` or prefixing
  `$REPO_ROOT/`) — matching REPO_ROOT-relative form on both sides (git output vs. the derived
  prefix) is simpler and mirrors the existing `check_flat_category_orphans` idiom
  (`full="$REPO_ROOT/$rel"`) rather than introducing a new path-normalization dependency.
- **No shared-helper extraction**: this task's scope (file_scope: single file, single function)
  and the explicit "do not redesign" instruction argue against refactoring
  `check_flat_category_orphans`/`_git_deployed_files` to share code with
  `check_undeclared_scripts` in this same change, even though a future consolidation could be
  worth considering (the two checks enumerate different roots — `.claude/$category` vs. an
  extension's own `scripts/` source — so a shared helper would need a root argument anyway).

## Risks & Mitigations

- **Risk**: a `provides.scripts` entry that intentionally names a symlink or non-regular file
  under `scripts/` would now be silently skipped by the `[[ -f "$REPO_ROOT/$script_file" ]]`
  guard if `git ls-files` returns it but it resolves to something other than a plain file.
  **Mitigation**: this exactly mirrors `check_flat_category_orphans`'s existing symlink-handling
  discipline (it explicitly `[[ -L ]]`-skips symlinks before its own `-f` check, deferring them to
  Rule N). No known `provides.scripts` entry is a symlink; if one existed, its behavior is
  unchanged from the current `find`-based code's own `[[ -f "$script_file" ]] || continue` guard
  (identical semantics, only the enumeration source differs).
- **Risk**: `git ls-files` on a bare/detached state, or if `check-extension-docs.sh` is ever run
  outside a git working tree, returns nothing (empty output, matching `_git_deployed_files`'s own
  `2>/dev/null` fallback-to-empty behavior) rather than erroring. **Mitigation**: this is
  consistent with the existing `_git_deployed_files` helper's already-accepted behavior elsewhere
  in the same script; no new failure mode is introduced.
- **Risk**: verification only covered the repository's current tracked-file snapshot, not every
  possible future untracked-artifact shape. **Mitigation**: `git ls-files`'s general property
  (only tracked files, unconditionally excluding everything gitignored or never-added) is a
  structural guarantee independent of which specific artifact type triggers it — the fix
  generalizes to any future untracked-artifact class (venvs, node_modules, build caches), not just
  the two `.pyc` files observed live.

## Context Extension Recommendations

None. This is a narrowly-scoped bug fix in an existing, well-commented function; no new context
documentation gap was identified.

## Appendix

### Commands run

```bash
# Located the two named functions and confirmed line numbers
grep -n "check_undeclared_scripts\|_git_deployed_files\|check_flat_category_orphans" \
  agent-system/extensions/core/scripts/check-extension-docs.sh

# Read the full check_undeclared_scripts (521-547) and _git_deployed_files/
# check_flat_category_orphans (888-931) implementations

# Verified git ls-files path-shape independence of pathspec absolute/relative form
git -C "$REPO_ROOT" ls-files "$REPO_ROOT/agent-system/extensions/literature/scripts"
git -C "$REPO_ROOT" ls-files "agent-system/extensions/literature/scripts"

# Confirmed the two known-bad untracked artifacts exist on disk
find agent-system/extensions/literature/scripts -name "*.pyc" -o -name "__pycache__"

# Reproduced the current bug (find-based enumeration flags the two .pyc files)
# Simulated the proposed fix (git ls-files-based enumeration, re-derived prefix-strip)
# against literature extension: confirmed zero false positives, pycache excluded

# Regression-checked the proposed fix against EVERY extension with a scripts/ tree,
# diffing old (find) vs. new (git ls-files) undeclared-script result sets:
# only literature differs, and only by removing the 2 known-bad entries
```

### File reference

- `agent-system/extensions/core/scripts/check-extension-docs.sh` lines 505-547
  (`check_undeclared_scripts`, Rule Q)
- `agent-system/extensions/core/scripts/check-extension-docs.sh` lines 888-931
  (`_git_deployed_files`, `check_flat_category_orphans`, Rules J/K/M — the already-chosen pattern)
- `agent-system/extensions/core/scripts/check-extension-docs.sh` lines 79-83 (`REPO_ROOT`,
  `EXT_DIR` definitions)
- `agent-system/extensions/core/scripts/check-extension-docs.sh` line 1024 (caller loop,
  `for ext_path in "$EXT_DIR"/*/`)
