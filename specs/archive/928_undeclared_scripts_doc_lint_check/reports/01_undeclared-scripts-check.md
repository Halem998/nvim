# Research Report: Task #928

**Task**: 928 - undeclared_scripts_doc_lint_check
**Started**: 2026-07-27
**Completed**: 2026-07-27
**Effort**: Small (single-file addition + 3 manifest edits + 1 possible follow-up)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` (full read, 1046 lines)
- `agent-system/extensions/core/scripts/skill-base.sh` (lifecycle hook mechanism)
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` / `init.lua` (deploy mechanics)
- `agent-system/extensions/{nix,nvim,literature}/manifest.json`
- `.claude-extensions.json` (live loaded-extension state)
- Live simulation of the proposed check across every extension's `scripts/` tree
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The proposed `check_undeclared_scripts` check is straightforward to add and mirrors
  `check_undeclared_skills` (Rule A) / `check_undeclared_rules` (Rule H) almost exactly, with two
  adjustments: recurse (full relative path matching, already precedented by Rule M's
  `check_flat_category_orphans "scripts"`) and enumerate via `find -type f` rather than a `*.sh`
  glob (to catch `.py`/`.sql`/dotfile entries and skip nothing by extension).
- I independently re-simulated the check across every extension's `scripts/` tree (script,
  not the real bash function, to sanity-check the matching logic before writing the function) and
  confirmed **exactly three findings, matching the task's stated baseline exactly**:
  `nix/nix-context.sh`, `nix/nix-preflight.sh`, `nvim/nvim-context.sh`. No other extension
  (including `literature`, which has the most complex `scripts/` tree — nested `tests/`, a
  `deprecated/` subtree, `.py`/`.sql`/dotfile entries) produces a false positive once the
  `deprecated/` exemption and full-relative-path matching are both applied.
- **DECISION REQUIRED resolved**: I confirmed directly (not inferred) that the loader has **no
  path** that deploys a lifecycle-hook script named in a manifest's top-level `hooks` object.
  `copy_manifest()` deploys only `manifest.json` to `.claude/extensions/<name>/`; `copy_scripts()`
  deploys `provides.scripts` entries flatly to `.claude/scripts/`, never to
  `.claude/extensions/<name>/scripts/`. So the three baseline findings are genuine defects, and
  the fix is to add the three files to `provides.scripts` (not to add a `hooks`-object exclusion).
- **New finding beyond the stated baseline, important for scoping the fix**: even after adding
  the three files to `provides.scripts`, the lifecycle hooks will still not fire at runtime. Two
  independent problems in `skill-base.sh`'s `skill_run_extension_hook`/`skill_get_extension_dir`
  are stacked on top of the non-declaration bug:
  1. `hook_path="${ext_dir}/${hook_script}"` resolves against `.claude/extensions/<name>/`, which
     (per the point above) never receives a `scripts/` subtree from any deploy path — only
     `.claude/scripts/` (flat) ever gets populated.
  2. `skill_get_extension_dir` reads `.claude-extensions.json` via
     `.loaded_extensions[] | select(.task_type == $tt) | .name` — but the live file in this repo
     uses the schema `{"extensions": {"<name>": {...}}, "version": ...}`, which has no
     `loaded_extensions` key at all. The query returns empty for every task type, always.
  I verified this is not merely theoretical: `skill-orchestrate/SKILL.md` calls
  `skill_preflight_update` (which calls `skill_run_extension_hook "preflight" ...`)
  unconditionally for every `/orchestrate` dispatch regardless of task type, so nix/nvim task
  preflight and context-injection hooks are live call sites, not dead code paths — they are simply
  silently no-op-ing today, and would keep silently no-op-ing after only the manifest fix. This is
  exactly the failure class the task's own "WHY THIS MATTERS" section warns about, one layer
  removed. See "Recommendation" below for suggested scoping.

## Context & Scope

Researched: how to add a disk-driven undeclared-scripts check to
`agent-system/extensions/core/scripts/check-extension-docs.sh`, mirroring the existing
`check_undeclared_skills` (Rule A) and `check_undeclared_rules` (Rule H) checks, per the
SOURCE-STORE RULE (`agent-system/extensions/**` is the only editable source; `.claude/**` is a
gitignored deploy artifact and must never be edited directly).

## Findings

### Codebase Patterns

**Existing sibling checks** (`agent-system/extensions/core/scripts/check-extension-docs.sh`):

- `check_undeclared_skills` (lines 456-472, Rule A) and `check_undeclared_rules` (lines 474-502,
  Rule H) are the two direct precedents: for-loop over disk entries, `jq -e --arg s "$name"
  '.provides.X[]? | select(. == $s)'` membership test, `fail` on miss. Both operate on FLAT
  directories (`skills/skill-*/`, `rules/*.md`) and match by **basename**.
- `check_flat_category_orphans "scripts" "Rule M"` (lines 826-861) is the precedent for
  **recursive, full-relative-path** script matching — its own comment (lines 828-831) already
  states the convention this new check must follow: "an individual provides.scripts entry may
  itself contain a `/`... so entries are matched by their full relative path under the category
  root, not by basename alone." Rule M runs in the opposite direction (deployed file -> declared
  entry, project-wide) and is enumerated via `_git_deployed_files "scripts"` (`git ls-files
  .claude/scripts`) — which is why it structurally cannot see an undeclared, never-deployed
  script; the new check must enumerate the **extension source** tree instead
  (`find "$ext_path/scripts" -type f`), independent of deployment.
- `check_referenced_scripts_declared` (Rule E, lines 682-746) is reference-driven (greps
  `\.(sh|sql)\b` tokens from docs/skills/agents) and explicitly scoped to `.sh`/`.sql` only — this
  is why it misses `.py` entries and any script never mentioned by name in prose, exactly as the
  task description states.
- The per-extension check-registration block is a flat sequential list at lines 967-979 inside the
  main `for ext_path in "$EXT_DIR"/*/; do` loop (line 954). `check_undeclared_skills "$ext_path"`
  and `check_undeclared_rules "$ext_path"` sit adjacent at lines 972-973 — the new call should be
  inserted immediately after those two.
- The rule-letter index comment block (lines 35-53) enumerates A through P in first-introduced
  order; the next unused letter is **Q**.

**Verified simulation** (ad-hoc bash matching the intended function logic, run against the live
tree, not the actual doc-lint script):

```
nix: nix-context.sh
nix: nix-preflight.sh
nvim: nvim-context.sh
```

No other extension — including `literature` (which has `scripts/tests/*` declared with a `tests/`
prefix, `scripts/deprecated/*` correctly undeclared, and a dotfile entry `.zotero-title-sim.py`
correctly declared) — produced a finding. This confirms both the `deprecated/` exemption and the
full-path/all-file-types enumeration are correctly scoped before any code is written.

**Implementation gotcha (not obvious from the sibling checks, found only by directly re-running my
own first draft against the tree and getting universally-wrong output)**: the main loop's `for
ext_path in "$EXT_DIR"/*/; do` passes `ext_path` **with a trailing slash**. String **prefix
removal** (`${script_file#"$ext_path"/scripts/}`) is fooled by this into producing a
double-slash prefix (`.../core//scripts/`) that never matches the single-slash path `find`
actually returns, so the entire declared-set check silently degrades to reporting full absolute
paths as "undeclared" for every single script in every extension. `check_undeclared_skills`/
`check_undeclared_rules` never hit this because they use `$ext_path/skills/"/skill-*/` as a
**glob** (double slashes are harmless in globs and path opens) rather than a **string prefix
strip** (where double slashes are a literal, non-matching, character sequence). The fix is to
normalize the trailing slash away before using it in prefix removal: `ext_path_norm="${ext_path%/}"`
then `rel_path="${script_file#"$ext_path_norm"/scripts/}"`. I confirmed this normalization is what
makes the simulation converge to exactly the 3 expected findings; without it every extension's
entire script tree false-positives.

### Recommended Function

```bash
# Rule Q: Undeclared script files in extension source not in provides.scripts.
#
# Reverse direction of check_manifest_entries' scripts loop (declared-but-missing-on-disk only)
# and of check_referenced_scripts_declared (Rule E, reference-driven, .sh/.sql-only). Mirrors
# check_undeclared_skills (Rule A) / check_undeclared_rules (Rule H) for the scripts category,
# but scripts/ is NOT flat: entries are matched by FULL RELATIVE PATH under scripts/ (provides.
# scripts entries legitimately carry a path prefix, e.g. "lint/lint-postflight-boundary.sh",
# "tests/generate-test-fixtures.py" -- same convention already documented on check_flat_category_
# orphans "scripts" "Rule M"), and enumeration covers EVERY regular file, not a *.sh glob --
# provides.scripts already contains .py/.sql entries and a dotfile entry. scripts/deprecated/ is
# exempt: it holds intentionally-retired, correctly-undeclared, correctly-never-deployed files.
check_undeclared_scripts() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  [[ -d "$ext_path/scripts" ]] || return 0

  # Normalize away a possible trailing slash on ext_path before using it in a string PREFIX
  # STRIP below -- unlike a glob (harmless with a doubled slash), `${var#prefix}` treats "//" as
  # a literal, non-matching sequence and silently fails to strip anything.
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
  done < <(find "$ext_path/scripts" -type f | sort)
}
```

Registration (in the main per-extension loop, immediately after `check_undeclared_rules`):

```bash
      check_undeclared_skills "$ext_path"
      check_undeclared_rules "$ext_path"
      check_undeclared_scripts "$ext_path"
```

Rule-letter index addition (append after the existing P entry, lines ~35-53):

```
#   Q - check_undeclared_scripts            : script file on disk not in provides.scripts
```

Use `fail` (not `advisory`/`orphan_report`), per the task's explicit severity instruction — this
mirrors Rules A/H, both of which already use `fail`.

### Baseline Resolution (the 3 findings)

Both `nix/manifest.json` and `nvim/manifest.json` declare a top-level lifecycle `hooks` object
(distinct from `provides.hooks`) referencing these exact paths, and the files exist on disk but
`provides.scripts` is `[]` in both manifests:

- `agent-system/extensions/nix/manifest.json`: `"hooks": {"preflight": "scripts/nix-preflight.sh",
  "context_injection": "scripts/nix-context.sh"}`, `provides.scripts: []`
- `agent-system/extensions/nvim/manifest.json`: `"hooks": {"context_injection":
  "scripts/nvim-context.sh"}`, `provides.scripts: []`

Fix: add the file names to each extension's `provides.scripts` array:

```json
// nix/manifest.json, provides.scripts
"scripts": ["nix-preflight.sh", "nix-context.sh"]

// nvim/manifest.json, provides.scripts
"scripts": ["nvim-context.sh"]
```

I confirmed this is the correct and sufficient fix **for the doc-lint gate specifically**:
- No other check in `check-extension-docs.sh` will newly fail as a result. `check_deployed_
  script_drift` (Rule F) will emit an `info "script not deployed, skipping drift check"` line
  (not a `fail`) since these three are not currently deployed to `.claude/scripts/`.
- `check_flat_category_orphans "scripts"` (Rule M) is unaffected either way (it only enumerates
  currently-deployed files; these three are not deployed).
- Neither extension is `routing_exempt: true`, so `check_core_deploy_advisory` (Rule O, core-only)
  does not apply.

### Runtime Behavior — Important Scoping Finding (beyond the literal doc-lint ask)

I verified, rather than assumed, whether adding these three files to `provides.scripts` would
also restore the lifecycle hook they are meant to serve. It will not, for two independent,
confirmed reasons:

1. **No deploy path reaches where the hook loader looks.** `skill_run_extension_hook` in
   `agent-system/extensions/core/scripts/skill-base.sh` (lines 80-113) resolves:
   `ext_dir=$(skill_get_extension_dir "$task_type")` -> `.claude/extensions/${ext_name}`, then
   `hook_path="${ext_dir}/${hook_script}"` (e.g. `.claude/extensions/nix/scripts/nix-preflight.sh`).
   But `copy_manifest()` (`lua/neotex/plugins/ai/shared/extensions/loader.lua` /
   `init.lua:476`) deploys **only** `manifest.json` into `.claude/extensions/<name>/` — I confirmed
   this on disk: `.claude/extensions/nix/` contains a single file, `manifest.json`. `copy_scripts()`
   (loader.lua:339-373, called from `init.lua:440`) deploys `provides.scripts` entries to the flat
   `.claude/scripts/` directory instead. So `hook_path` can never exist regardless of whether the
   file is declared in `provides.scripts` — the deploy target and the hook lookup target are two
   different directories.
2. **The hook lookup's own data source query does not match the live schema.**
   `skill_get_extension_dir` (skill-base.sh lines 57-74) queries `.claude-extensions.json` via
   `.loaded_extensions[] | select(.task_type == $tt) | .name`. I read the live
   `.claude-extensions.json` in this repo: its schema is `{"extensions": {"<name>": {...}},
   "version": ...}` — there is no `loaded_extensions` key at all, so this jq query returns empty
   for every `$tt`, unconditionally. (I did not investigate whether this is a stale/superseded
   schema query or whether `.claude-extensions.json`'s shape itself changed; either way, the two
   are currently mismatched.)

This is not a dead code path being fixed defensively: `skill-orchestrate/SKILL.md` calls
`skill_preflight_update "$task_number" "research/plan/implement" "$session_id"` unconditionally on
every `/orchestrate` dispatch cycle regardless of task type (lines 251, 299, 339, 393, 450), and
`skill_preflight_update` internally calls `skill_run_extension_hook "preflight" ...`. So a live
`/orchestrate` run against a `nix`- or `neovim`-typed task silently no-ops both extensions'
declared lifecycle hooks today, and — this is the point worth flagging — **would continue to
silently no-op them after only the `provides.scripts` fix**, because neither of the two problems
above is a declaration problem.

## Decisions

- Use `find "$ext_path/scripts" -type f` (not a `.sh`-only glob) for enumeration, per the task's
  explicit "ALL FILE TYPES" requirement, and exempt `deprecated/*` by relative-path prefix match.
- Match by full relative path under `scripts/`, never basename, per the task's explicit
  requirement and Rule M's existing documented convention.
- Use `fail` (Rules A/H's severity), not `advisory`/`orphan_report`, per the task's explicit
  severity instruction.
- Resolve the DECISION REQUIRED question empirically (traced `copy_manifest`/`copy_scripts` in
  the loader plus `skill_run_extension_hook`/`skill_get_extension_dir` in `skill-base.sh`) rather
  than by inspection of the doc-lint script alone: confirmed no deploy path populates
  `.claude/extensions/<name>/scripts/`, so the three baseline findings are true positives to be
  fixed via `provides.scripts`, not false positives to be silenced via an exclusion.

## Risks & Mitigations

- **Risk**: A planner/implementer stops at "add 3 entries to provides.scripts, doc-lint is green"
  and reports the hooks as fixed, when they are not (per "Runtime Behavior" above). **Mitigation**:
  this report documents both confirmed root causes explicitly so the implementation summary can
  correctly scope what was and was not fixed, and so a follow-up task can be spawned deliberately
  rather than the gap going unnoticed a second time.
- **Risk**: Widening `check_undeclared_scripts`'s enumeration in the future to also assert that
  a `hooks`-object-referenced script is declared could create a coupling between the two
  mechanisms that doesn't currently exist (nothing today requires a `hooks`-referenced path to
  also appear in `provides.scripts` structurally — it only happens to be true for these two
  extensions because both scripts also need directory deployment). Not needed for this task; noted
  only so a future maintainer doesn't conflate the two checks.
- **Mitigation applied to the check itself**: verified the trailing-slash prefix-strip gotcha
  (see "Implementation gotcha" above) with a live simulation before finalizing the function body,
  since it silently produces universal false positives if missed — this exact class of testing
  gap (an emitter that looks correct until run against the full tree) is very close to what the
  task is trying to prevent in the first place.

## Recommendation

1. **In this task's implementation**: add `check_undeclared_scripts` (Rule Q) as specified above,
   register it in the per-extension loop, and add the two manifest edits (nix: 2 entries, nvim: 1
   entry) to `provides.scripts`. This satisfies every explicit requirement in the task description
   and keeps the doc-lint green.
2. **Recommend, but treat as a distinct decision for the planner/user**: whether to also fix
   `skill_get_extension_dir`'s schema query and `skill_run_extension_hook`'s deploy-path
   resolution in the same change, or to spawn a separate follow-up task for it. I lean toward a
   separate follow-up task, because: (a) it touches `skill-base.sh`, a different component than
   the doc-lint script this task's REQUIRED BEHAVIOR section is scoped to; (b) it likely requires
   a design decision (does the hook path move to reading from `.claude/scripts/$(basename
   "$hook_script")`, or does a new deploy step populate `.claude/extensions/<name>/scripts/`
   in parallel with the flat copy — these have different implications for content-drift checking
   and for the `.claude-extensions.json` schema reconciliation) that is out of scope for "add one
   disk-driven doc-lint check." Either way, it should not be silently left unflagged, since leaving
   it unflagged reproduces the exact "looks fixed, still doesn't work" pattern this task exists to
   catch.

## Context Extension Recommendations

None — this is a self-contained fix to an existing, well-documented script; no new context file
category is warranted.

## Appendix

- Searches: direct reads of `check-extension-docs.sh`, `skill-base.sh`, `loader.lua`, `init.lua`;
  `jq`/`find`/`grep` queries against `agent-system/extensions/*/manifest.json` and `*/scripts/`;
  live simulation of the proposed matching logic across all extensions; read of
  `.claude-extensions.json` and `.claude/extensions/{nix,nvim}/` deployed contents;
  `agent-system/extensions/core/docs/architecture/handoff-schema.md` for the handoff JSON schema.
