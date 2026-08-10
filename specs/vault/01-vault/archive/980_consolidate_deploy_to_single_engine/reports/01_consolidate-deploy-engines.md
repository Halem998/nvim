# Research Report: Task #980

**Task**: 980 - consolidate_deploy_to_single_engine
**Started**: 2026-08-05T00:00:00Z
**Completed**: 2026-08-05T00:00:00Z
**Effort**: Large (structural consolidation, subsumes two abandoned tasks)
**Dependencies**: Task 966 (verify-deploy baseline/delta semantics) — COMPLETED, constraint satisfied
**Sources/Inputs**: Codebase (lua/neotex/plugins/ai/shared/extensions/**, lua/neotex/plugins/ai/claude/commands/picker/**, agent-system/extensions/core/scripts/deploy-headless.sh), specs/reviews/review-2026-07-29-agent-system.md, specs/state.json (task 958/970 descriptions)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All six root causes from the review are independently confirmed with fresh file:line evidence gathered directly (not just re-cited from the review). No claim in the task description needed correction; several are even more precisely locatable than the description's "~line N" approximations.
- Engine A (`lua/neotex/plugins/ai/shared/extensions/init.lua` + `loader.lua`) already contains most of the raw material needed: `manager.regenerate` (init.lua:972-1035) is a working wipe-safe reload loop, `settings_backup.lua` is a correct-shaped backup/restore module, and `manager.reload`/the picker's "Reload All" already implement a working (if destructive) per-extension and bulk unload+load cycle. The gap is wiring, not missing mechanism.
- Engine B (`sync.lua`'s `load_all_globally`, invoked by `deploy-headless.sh`) is confirmed as the sole path `deploy-headless.sh` drives, confirmed to never call any `loader_mod.copy_*` function, and confirmed to apply an allow-list post-filter keyed by top path segment (`sync.lua:1006-1016`) against a manifest that declares full relative paths for `scripts`/`hooks` — this silently drops subdirectory entries.
- The `is_load_all` dead-producer bug is confirmed: `picker/init.lua` has 5 live consumer sites (lines 111, 352, 376, 400, 424) but `entries.lua`'s `create_special_entries` (955-988) creates only `is_help` and `is_reload_all` — never `is_load_all`. The picker path is genuinely unreachable via keyboard, not merely deprecated.
- `settings_backup.restore` (settings_backup.lua:78-104) is confirmed called strictly after the `manager.load` loop inside `manager.regenerate` (init.lua:1025, after the loop at 998-1017), confirmed to never clear its staging directory after a successful restore, and `settings_backup.backup` is confirmed to have zero callers anywhere in `lua/`.
- The 11 `copy_*` functions are enumerated precisely: `copy_simple_files`, `copy_skill_dirs`, `copy_context_dirs`, `copy_scripts`, `copy_hooks`, `copy_systemd`, `copy_docs`, `copy_templates`, `copy_root_files`, `copy_manifest`, `copy_data_dirs`. Symlink guard (the `symlink_skipped_count` 4th return value) exists in exactly 2 of them (`copy_simple_files`, `copy_skill_dirs`); the other 9 return only `(copied_files, created_dirs, skipped_count)` — except `copy_manifest` (2 return values, no `skipped_count` at all) and `copy_data_dirs` (2 return values, entirely different parameter shape: no `target_dir`/`protected_paths`, uses `project_dir` instead). `preserve_perms` is hardcoded per-category rather than derived from a shared rule: `true` for scripts and hooks, `false` for context/systemd/docs/templates/root_files, and file-extension-conditional (`.sh` check) only inside `copy_simple_files`.
- `verify.lua`'s `verify_extension` (359-499) is confirmed to check only `agents`, `skills`, `rules`, `context`, section-injection, index-merge, and opencode.json-merge — zero references to `scripts`, `hooks`, `docs`, `templates`, `systemd`, or `root_files`, confirming the exact gap named in the task.
- Recommended approach: implement the task's WORK items 1-7 largely as written; the plan's biggest design decision is HOW `manager.regenerate` reconciles with the existing `manager.reload`-based "Reload All" bulk path already in the picker (both accomplish similar outcomes via different mechanisms — the plan should pick one canonical bulk-resync entry point and make the other call into it, not maintain two).

## Context & Scope

Researched the two independent deploy engines writing `.claude/`/`.opencode/` in this repo, per
task 980's WORK items 1-7, to ground an implementation plan in verified file:line evidence
(supplementing, not just re-trusting, `specs/reviews/review-2026-07-29-agent-system.md`'s
deploy-pipeline section). Read task 958 and 970's full descriptions (both `abandoned`, subsumed
by this task) to capture their verification bars. Did not write any code — this is research
only, informing the forthcoming `/plan 980`.

## Findings

### Codebase Patterns

**Engine A — manifest-driven loader (`lua/neotex/plugins/ai/shared/extensions/`)**

- `manager.load` (`init.lua:236-597`): hard-aborts on already-loaded at line 253-254
  (`if state_mod.is_loaded(state, extension_name) then return false, "Extension already loaded: " .. extension_name end`).
  No `force`/resync parameter exists today — `opts` only recognizes `confirm`, `project_dir`,
  `force` (referenced at line 316 but only propagated to *dependency* loads, never consulted to
  bypass this abort itself), and `_loading_stack`.
- The copy sequence inside `manager.load`'s `pcall` block (lines 402-519) calls, in order:
  `copy_simple_files` (agents, commands, rules — 3 calls with different `category` args),
  `copy_skill_dirs`, `copy_context_dirs`, `copy_scripts`, `copy_hooks`, `copy_docs`,
  `copy_templates`, `copy_systemd`, `copy_root_files`, `copy_manifest`, `copy_data_dirs`. This
  sequence is idempotent/overwrite-safe by construction for everything except
  `INSTALL_ONCE_ROOT_FILES` (settings.json/settings.local.json, correctly skip-if-exists) — so a
  `force` mode that skips only the line-253 abort and re-runs this same sequence is
  low-risk.
- `manager.reload` (`init.lua:788-812`) already exists: unload-then-load for one extension,
  no confirm. The picker's per-extension "Reload" choice (`picker/init.lua:316`,
  `exts.reload(ext.name, {})`) already calls it. This is the "destructive unload/reload"
  workaround the task description references — it works today for a single extension via the
  picker, just not headlessly or in a non-destructive form.
- The picker's "Reload All" bulk entry (`picker/init.lua:127-260`) independently reimplements a
  topological unload-all-then-load-all cycle (Kahn's algorithm at 172-202) using `exts.unload`
  and `exts.load` directly — NOT `manager.reload` and NOT `manager.regenerate`. This is a third
  distinct code path accomplishing a similar "resync everything" outcome. Any consolidation plan
  needs to decide whether "Reload All" should be rewired to call `manager.regenerate` (simpler,
  fewer paths) or left as-is (it already works and doesn't wipe `base_dir`, so it survives
  mid-operation crashes better than a wipe+regenerate would).
- `manager.regenerate` (`init.lua:943-1035`, extensively pre-documented in its own docstring
  comment) is a working reference implementation of "reconstruct `base_dir` from the surviving
  root-level manifest": reads `state_mod.read`, collects `active_names`, resets in-memory/on-disk
  state to empty (line 989), then calls `manager.load` per extension (re-checking state each
  iteration to avoid spurious "already loaded" on dependency-pulled-in extensions, lines
  998-1017). **Zero callers** confirmed via repo-wide grep — only its own definition and a usage
  comment inside `settings_backup.lua`'s header reference it.
- **The settings-ordering bug** (task claim 4) is confirmed exactly: `manager.regenerate` calls
  `settings_backup.restore(project_dir, config)` at line 1025, strictly AFTER the `for _, extension_name in ipairs(active_names) do ... manager.load(...) end` loop (lines 998-1017) that
  performs the settings-fragment merge (each `manager.load` call regenerates `CLAUDE.md`,
  `opencode.json`, and merges settings fragments via `process_merge_targets`, called inside the
  same `pcall` block at line 518). So a staged settings backup from BEFORE the wipe overwrites
  the fresh post-load merge — any settings fragment merged newly during this regenerate pass
  (e.g., a new hook registration) is silently discarded by the restore.
- **The staging-dir leak** (task claim 4) is confirmed: `settings_backup.restore`
  (`settings_backup.lua:78-104`) reads from `staging_dir` and writes into `base_dir`, but never
  deletes or clears `staging_dir` on success. Every subsequent `manager.regenerate` call (even
  outside a wipe sequence, since `restore` is unconditionally invoked) will find the same stale
  backup and silently re-apply it.
- `settings_backup.backup` (`settings_backup.lua:46-68`) has **zero callers** confirmed via
  repo-wide grep of `lua/` — the intended sequence documented in the module's own header comment
  (`backup -> rm -rf base_dir -> regenerate -> restore`) has never had its first step wired to
  anything. `M.has_backup` and `M.staging_path` are similarly uncalled outside the module itself.
- `.syncprotect` (`loader.lua:16-44`, `load_syncprotect`) is confirmed to be **overwrite
  protection only**: it builds a `{[path]=true}` set consulted inside `copy_file` (skip-if-
  protected) and inside `manager.unload`'s removal filter (skip-if-protected). There is no
  snapshot/restore capability anywhere referencing `.syncprotect` — a `rm -rf base_dir` wipe
  would delete every syncprotect-listed path (e.g. `context/repo/project-overview.md`) with no
  mechanism to bring it back, confirming task claim: "it is currently overwrite-protection only,
  so a wipe would lose context/repo/project-overview.md."

**The 11 `copy_*` functions — internal divergence (task claim 6), fully enumerated**

| Function | Return arity | Symlink guard? | `preserve_perms` |
|---|---|---|---|
| `copy_simple_files` (146-187) | 4 (`files, dirs, skipped, symlink_skipped`) | Yes | `filename:match("%.sh$")` (conditional) |
| `copy_skill_dirs` (210-262) | 4 | Yes | `file_rel_path:match("%.sh$")` (conditional) |
| `copy_context_dirs` (273-329) | 3 | No | `false` (hardcoded) |
| `copy_scripts` (339-373) | 3 | No | `true` (hardcoded) |
| `copy_hooks` (383-418) | 3 | No | `true` (hardcoded) |
| `copy_systemd` (428-462) | 3 | No | `false` (hardcoded) |
| `copy_docs` (472-527) | 3 | No | `false` (hardcoded) |
| `copy_templates` (537-571) | 3 | No | `false` (hardcoded) |
| `copy_root_files` (602-641) | 3 | No | `false` (hardcoded); has bespoke `INSTALL_ONCE_ROOT_FILES` branch not present anywhere else |
| `copy_manifest` (650-679) | 2 (`files, dirs` — no `skipped_count` at all) | No | `false`; different signature (`extension_name` param, no `protected_paths` param) |
| `copy_data_dirs` (688+) | 2 (`copied_files, created_dirs`) | Not applicable | N/A; entirely different signature (`project_dir` not `target_dir`, no `protected_paths`) — merge-copy semantics for user data, correctly distinct in kind from the other 10 |

This confirms the task's "symlink guard in only 2 of 11" and "return arity differs" claims with
exact evidence, and additionally surfaces that `copy_manifest` silently has no `.syncprotect`
awareness at all (its call site at `init.lua:476` passes no `protected_paths` argument — the
function signature doesn't accept one).

**Engine B — glob+allow-list sync (`picker/operations/sync.lua`)**

- `deploy-headless.sh` (`agent-system/extensions/core/scripts/deploy-headless.sh:8`, `:163`,
  `:175`) is confirmed to call `sync.load_all_globally(nil)` exclusively — the only Lua entry
  point it ever invokes, stubbing `vim.fn.confirm` to auto-select the full-deploy choice. It has
  zero calls to `loader_mod`/`manager.*` at any point in the file.
- `M.load_all_globally` (`sync.lua:1208+`) calls `M.scan_all_artifacts` which builds per-category
  file lists via a local `sync_scan` closure (~890-1045). For `scripts` and `hooks`
  specifically (`sync.lua:1090`, `:1076`), `sync_scan` is called with `filter_category` set,
  triggering the allow-list post-filter block at lines 1001-1042 (task description's cited
  "~1001-1016" is the exact `top_dir` extraction/match logic; the block runs through 1042 total).
- The allow-list post-filter (1001-1042) computes `rel_path` relative to `subdir` (e.g.
  `scripts/`), then `top_dir = rel_path:match("^([^/]+)")` — the FIRST path segment only — and
  checks `allowed[top_dir]`. Since `provides.scripts` in the core manifest declares full relative
  paths (verified: `manifest.json:94` starts a `scripts` array whose entries include
  `lib/*.sh`, `tests/*.sh` subpaths, not bare top-level filenames), `top_dir` for any
  `scripts/lib/foo.sh` resolves to the literal string `"lib"`, which is never itself a key in
  `allowed` (the allow-list keys are the declared entries verbatim, e.g. `"lib/foo.sh"`, not
  `"lib"`). Every `scripts/lib/*.sh` and `scripts/tests/*.sh` entry is therefore dropped by this
  filter on every call, fresh deploy or resync alike — confirming task claim 2 exactly, and
  confirming the code's own "Zero-result wipeout detector" (1022-1039) as a self-aware guard that
  fires a `WARN` (not a hard failure) when this happens, which is why the defect is silent rather
  than blocking.
- The correction of the mis-diagnosis (task claim 2's "corrects the mis-diagnosis recorded in
  `no-task-references-in-deliverables.md`") is independently confirmed: that rule file's
  "Discovered deploy-mechanism gap" section attributes the missing-scripts symptom to
  `manager.load()` skipping `copy_scripts`/`copy_manifest` "for already-loaded extensions" — but
  `deploy-headless.sh` never calls `manager.load`/`copy_scripts` at all (it calls
  `sync.load_all_globally`, Engine B, entirely disjoint code). The true mechanism is the
  allow-list top-segment mismatch above, which fires identically on a from-scratch deploy (no
  "already loaded" state exists yet) — matching task 970's own observation ("symptom 2... even on
  a FRESH deploy").
- `is_load_all` dead producer (task claim 3) confirmed: `picker/init.lua` reads
  `selection.value.is_load_all` at lines 111 (Enter-key handler, would call
  `sync.load_all_globally(config)` directly if reached), 352, 376, 400, 424 (four `<C-l>`-style
  keymap guards). `entries.lua`'s `M.create_special_entries` (955-988) inserts exactly two
  special entries: `is_help` (961-972) and `is_reload_all` (975-985) — no `is_load_all` entry is
  ever constructed. The picker menu item that remediation docs describe ("Load Core" / "Sync
  all") does not exist in the current UI; only "[Reload All]" (wipe-and-reload *already loaded*
  extensions, not a fresh/full sync) is reachable.
- `verify.lua`'s `M.verify_extension` (359-499) coverage gap confirmed by function inventory:
  `verify_agents` (68), `verify_skills` (96), `verify_rules` (124), `verify_context` (156),
  `verify_section_injection` (196), `verify_index_merge` (260), `verify_opencode_json_merge`
  (292) — seven verification functions, none named/referencing `scripts`, `hooks`, `docs`,
  `templates`, `systemd`, or `root_files`. `manager.load` calls `verify_mod.verify_extension` at
  `init.lua:591` after every load, so today's post-load verification structurally cannot catch a
  scripts/hooks/docs/templates/systemd/root_files propagation defect — exactly the categories
  both subsumed tasks (958, 970) observed breaking.

**Downstream stale-prose surface (WORK item 7)**

Confirmed via repo-wide grep for `"Load Core"`, `"Sync all"`, `"load_all_globally"`, and the
stale path `lua/neotex/shared/extensions/`: the following source-store files contain
remediation instructions or comments referencing the current (soon-to-be-retired) "Load Core /
Sync all" picker flow or `load_all_globally` and will need updating once `deploy-headless.sh` is
rewired: `agent-system/extensions/core/scripts/deploy-root-guard.sh` (line 26, user-facing error
message), `agent-system/extensions/core/scripts/check-extension-docs.sh` (6 separate advisory
strings at lines ~206, 310, 325, 412, 438, 445, 496, 1025, 1334 — the largest concentration),
`agent-system/extensions/core/scripts/deploy-headless.sh` (its own header comments, which will
need to describe whichever new entry point replaces `load_all_globally`),
`agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (documents
`load_all_globally` as *the* headless path — this doc's entire "Automated Exception" framing is
built around today's mechanism and needs a rewrite, not just a find-replace),
`agent-system/extensions/core/rules/no-task-references-in-deliverables.md` (the mis-diagnosis
itself, confirmed above), plus `orchestrate-batch-admit.sh`, `generate-context-line-counts.sh`,
`task-lock.sh`, `docs/README.md`, `context/patterns/batch-orchestration-guardrails.md`,
`context/standards/task-management.md`, and `merge-sources/claudemd.md` (lower-priority
mentions, need a grep-and-check pass but likely only 1-2 lines each). No occurrences of the
stale `lua/neotex/shared/extensions/init.lua` path were found in the current source store during
this scan (search-in-progress note: the task description names this as a known stale reference;
a targeted grep for that exact string turned up nothing in `agent-system/extensions/core/**`
during this pass — worth a final `grep -r "shared/extensions"` sweep at implementation time to
confirm no docs still cite it, since the review's finding may reference a doc outside the core
extension tree, e.g. an archived report).

**Test coverage gap**

No existing test file under `agent-system/extensions/core/scripts/tests/` references
sync/loader/deploy/verify by name (confirmed via targeted find) — the verification bar's core
requirement ("a test declaring a new script under `scripts/lib/` runs the real headless deploy
against a scratch tree") has no scaffold to extend; it will need to be authored from scratch,
likely following the pattern of `deploy-headless.sh`'s own stub-and-invoke technique
(`vim.fn.confirm` stubbed, headless `nvim` subprocess against a scratch git repo).

### External Resources

Not applicable — this is a pure codebase-internal consolidation task with no external library or
API surface; no web research was performed.

### Recommendations

1. **Engine A force/resync mode (WORK 1)**: add `opts.force` handling to `manager.load` that
   bypasses only the line-253 `already loaded` abort — the rest of the function (dependency
   resolution, copy sequence, state write, verification) is already idempotent/overwrite-safe
   given `INSTALL_ONCE_ROOT_FILES`'s existing skip-if-exists guard, so no additional idempotency
   work should be needed inside the copy functions themselves once they're collapsed (WORK 5).
2. **Rewire `deploy-headless.sh` (WORK 2)**: retarget it at `manager.regenerate` (or an
   unload-all/load-all sequence built on the existing "Reload All" Kahn's-algorithm code, promoted
   out of the picker into a reusable `manager`-level function so both the interactive picker and
   the headless script share one implementation — avoiding a *third* independent bulk-resync
   code path). Recommend picking `manager.regenerate` as canonical since it already exists,
   already integrates with `settings_backup`, and its docstring already describes the intended
   wipe sequence — but its settings-ordering bug (finding above) must be fixed first (WORK 3),
   or the newly-rewired headless path will inherit the same silent-settings-loss defect it's
   meant to fix.
3. **Fix settings ordering + staging leak + wire `backup` (WORK 3)**: move the
   `settings_backup.restore` call in `manager.regenerate` to run BEFORE the `manager.load` loop
   (restore stale settings first, so that the loop's `process_merge_targets` merge runs against
   already-restored settings and any new hook registrations land on top), and add an explicit
   `settings_backup.clear`/staging-dir removal at the end of a successful restore (or as a
   separate step invoked by the `--wipe` sequence after restore completes). Wire
   `settings_backup.backup` as the explicit first step of the new `--wipe` flag's sequence
   (`backup -> rm -rf base_dir -> regenerate -> restore -> re-apply settings fragments -> clear
   staging`), matching the task description's exact ordering.
4. **`.syncprotect` snapshot/restore (WORK 4)**: extend `settings_backup.lua` (or a sibling
   module reusing its staging-dir pattern) to snapshot every `.syncprotect`-listed path before a
   wipe and restore them after, alongside the two settings files — same staging directory, same
   lifecycle, avoids inventing a second mechanism.
5. **Table-driven copier (WORK 5)**: the divergence table above gives the exact shape needed —
   collapse to one function taking `{category, source_subdir, target_subdir, recursive,
   preserve_perms, install_once}` (as the task specifies) plus a uniform 4-value return
   `(copied_files, created_dirs, skipped_count, symlink_skipped_count)` for every category
   including `copy_manifest` and `copy_data_dirs`, which will need their bespoke logic (realpath
   self-load skip; merge-copy-only-if-absent) expressed as additional per-category flags rather
   than being left as one-off exceptions.
6. **`verify.lua` extension (WORK 6)**: add one verification function per currently-uncovered
   category (`scripts`, `hooks`, `docs`, `templates`, `systemd`, `root_files`) following the
   existing `verify_rules`/`verify_context` pattern (declared-vs-deployed presence), then add
   content-hash equality (existing functions appear to be presence-only, not hash-comparing —
   worth confirming during planning whether any current `verify_*` function already hashes
   content, since the task's bar requires "content-hash equality for a deliberately-staled
   deployed SKILL.md" and `verify_skills` should be checked for this before assuming it's new
   work).
7. **Prose corrections (WORK 7)**: the file list above is the concrete edit set;
   `regeneration-is-manual-only.md` needs the largest rewrite since its "Automated Exception"
   section is entirely framed around `load_all_globally` as the mechanism, not just a name
   substitution.

## Decisions

- Confirmed (not re-derived from the review alone) via direct file reads: all six root causes,
  the `is_load_all` dead-producer gap, the settings-ordering bug, the staging-dir leak, the
  zero-caller status of `manager.regenerate` and `settings_backup.backup`, the exact 11-function
  divergence table, and the allow-list top-segment mismatch mechanism.
- Recommend the plan treat "Reload All"'s existing Kahn's-algorithm bulk unload/load
  (`picker/init.lua:127-260`) as a THIRD mechanism to consolidate, not just Engine A vs Engine B
  — it currently duplicates what `manager.regenerate` should do, just without the wipe. The plan
  should decide whether to retire this picker-local reimplementation in favor of calling a
  shared `manager`-level bulk-resync function (recommended), or explicitly keep it as a
  non-wiping alternative to `--wipe` regeneration with a documented rationale for why both exist.
- No task-number citations appear in the recommendations above; all references use function
  names, file paths, and line numbers per the deliverable rule.

## Risks & Mitigations

- **Risk**: rewiring `deploy-headless.sh` to `manager.regenerate` changes its semantics from
  "sync only declared-but-missing/changed files" (Engine B, additive-leaning) to "wipe and fully
  reconstruct" (Engine A regenerate, described in the task as gated behind an explicit `--wipe`
  flag). **Mitigation**: the task description already separates a default force-resync mode (WORK
  1, non-destructive) from the `--wipe` flag (WORK 2, explicitly opt-in and destructive) — the
  plan should preserve that distinction so `deploy-headless.sh`'s default (no-flag) invocation
  stays non-destructive and behaviorally close to today's intent, with `--wipe` as the new,
  clearly-labeled full-reconstruction mode.
- **Risk**: extending `verify.lua` to new categories, per the binding sequencing rationale in the
  task description, must not create new standing failures now that task 966 (verify-deploy
  baseline/delta semantics) is COMPLETED — the plan should use whatever baseline/delta mechanism
  966 introduced so the newly-covered categories don't fail every existing deploy on day one.
  This report did not investigate task 966's implementation in depth (out of scope for this
  research pass); the planner should read task 966's plan/summary directly before designing WORK
  6.
- **Risk**: collapsing 11 functions into one table-driven copier risks behavior regressions for
  `copy_manifest` (realpath self-load skip) and `copy_data_dirs` (merge-copy, different base
  path) since both are meaningfully different in kind, not just configuration, from the other 9.
  **Mitigation**: treat these two as either explicit exceptions with clear naming, or express
  their special-casing as additional table fields (`self_load_skip`, `merge_copy_only`,
  `target_is_project_root`) rather than forcing a false uniformity.

## Context Extension Recommendations

- **Topic**: Deploy engine architecture (post-consolidation).
- **Gap**: No context file currently documents the deploy pipeline's shape for future agents
  once this task lands — `regeneration-is-manual-only.md` is the closest existing doc but is
  scoped narrowly to the headless-vs-interactive distinction, not the engine architecture itself.
- **Recommendation**: after implementation, consider a new or substantially-revised context file
  (candidate location: `agent-system/extensions/core/context/patterns/` or
  `architecture/`) describing the single consolidated engine, the table-driven copier contract,
  and the wipe/regenerate/force-resync trilogy, so future agents don't need to re-derive this
  from source reading as this report did.

## Appendix

- Search queries / greps used: `grep -n "already.loaded\|function manager.load"`,
  `grep -n "manager.regenerate\|settings_backup"`, `grep -n "load_all_globally\|is_load_all\|is_reload_all"`,
  `grep -rln "Load Core\|Sync all\|load_all_globally\|lua/neotex/shared/extensions"`,
  `python3 -c "json.load(...)"` against `agent-system/extensions/core/manifest.json` to enumerate
  `provides.*` category keys.
- Files read in full or substantial part: `lua/neotex/plugins/ai/shared/extensions/init.lua`
  (lines 228-1039), `lua/neotex/plugins/ai/shared/extensions/loader.lua` (lines 1-950, via
  targeted greps and one large contiguous read of 263-950), `lua/neotex/plugins/ai/shared/extensions/settings_backup.lua`
  (full, 114 lines), `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (lines
  960-1260), `lua/neotex/plugins/ai/claude/commands/picker/init.lua` (lines 95-353),
  `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` (lines 930-1010),
  `lua/neotex/plugins/ai/shared/extensions/verify.lua` (function inventory via grep),
  `agent-system/extensions/core/scripts/deploy-headless.sh` (header + invocation lines),
  `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (first ~55
  lines), `specs/reviews/review-2026-07-29-agent-system.md` (full), task 958 and 970 full
  descriptions from `specs/state.json`.
