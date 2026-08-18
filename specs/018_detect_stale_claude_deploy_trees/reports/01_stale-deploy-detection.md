# Research Report: Detect stale .claude/ deploy trees and root-cause the silent staleness

**Task**: 18 - Detect stale .claude/ deploy trees and root-cause the silent staleness
**Started**: 2026-08-18T01:23:00Z
**Completed**: 2026-08-18T01:31:00Z
**Effort**: 5h (estimated)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts/{deploy-headless,verify-deploy,command-gate-in,task-lock,install-extension}.sh, lua/neotex/plugins/ai/shared/extensions/{loader,init,state,manifest}.lua), live filesystem comparison across five consuming repos on this machine (`~/.dotfiles`, `~/Projects/{PersonalWebsite,cslib,BimodalLogic,ModelChecker}`), archived task summaries (980_consolidate_deploy_to_single_engine, 862_fix_loader_symlink_delete_data_loss), `context/patterns/regeneration-is-manual-only.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **No loader/copy-engine defect exists.** Every hypothesis in the delegation (skip-on-exists,
  installed_files-as-authoritative short-circuit, diff-only resync, partial-operation revert) was
  tested against the live source and found false: the copy engine (`loader.copy_category`)
  unconditionally overwrites every category on every load, `manager.load`'s `force=true` bypasses
  only the already-loaded abort (nothing else short-circuits), and `manager.resync_all` calls
  `manager.load(name, {force=true})` for every currently-active extension with no diffing at all.
- **Root cause of the staleness is structural, not a bug**: regeneration is deliberately
  pull-only (`context/patterns/regeneration-is-manual-only.md`) with exactly one narrow automated
  exception (`skill-orchestrate`'s inter-cycle checkpoint). A consuming repo's `.claude/` tree is
  therefore frozen at whatever the source store looked like the last time a human (or that one
  checkpoint) ran `[Reload All]`/`[Regenerate]`/`deploy-headless.sh` in it — indefinitely, with
  zero ambient signal that the source has moved on.
- **The existing detector (`verify-deploy.sh`) cannot close this gap by itself**: it is deployed
  *by* the same pull-only mechanism, so a repo stale enough to lack it cannot self-diagnose with
  it (chicken-and-egg), it is expensive (563 lines, 11 content-diffing gates — not preflight-cheap),
  and its only automated caller is the orchestrator's inter-cycle checkpoint, which no ordinary
  `/research`/`/plan`/`/implement`/`/revise` invocation ever reaches.
- **`/home/benjamin/.dotfiles` is a live, present-day instance of exactly this bug**, independently
  reproducing the delegation's evidence pattern: `.claude-extensions.json` marks `core` `"active"`
  with a full `installed_files` array (298 entries) that *includes* `.claude/scripts/task-lock.sh`,
  yet the deployed tree is missing 26 scripts present in current source (including
  `deploy-headless.sh` and `verify-deploy.sh` themselves) while retaining ~13 files no longer in
  core's manifest. Last full deploy timestamp is ~3 weeks stale relative to this investigation,
  with no intervening resync.
- **Recommended detection design**: stamp each extension's source-store git revision into
  `.claude-extensions.json` at load time (the `source_dir` absolute path is already recorded
  today — this only adds a sibling `source_git_head` field, cheaply computed via
  `git log -1 --format=%H -- <source_dir>`), and add a ~2ms-per-extension check to
  `command-gate-in.sh` (CHECKPOINT 1, sourced by every command) that recomputes the current source
  revision and WARNs (non-blocking) naming `deploy-headless.sh`/`[Reload All]` as the remedy on
  mismatch. This is the cheapest option of the three named in the delegation and sits on the one
  path every ordinary command already crosses before doing any real work — the same path where
  `/revise` originally crashed.

## Context & Scope

Two-part investigation per delegation: (1) determine why a repo's `.claude/` deploy went stale
despite the extension-state manifest (`.claude-extensions.json`) recording `core` as `"active"`
with the stale file listed in `installed_files`; fix if it is a genuine loader defect. (2) design
(not implement — this is the research phase) a staleness-detection mechanism cheap enough for a
normal command preflight, evaluated against the three directions the delegation named without
pre-committing to one.

## Findings

### Codebase Patterns

**The copy engine always overwrites (`lua/neotex/plugins/ai/shared/extensions/loader.lua`).**
`M.copy_category` (the single copier every `provides.*` category flows through since the
11-functions-to-1-descriptor-table refactor) calls `copy_file` for every manifest-declared entry
on every invocation. `copy_file` (loader.lua:54) has exactly three skip conditions: a
`.syncprotect`-listed relative path, a pre-existing symlink at the target (the "symlink guard",
present for agents/commands/rules/skills), and — for `root_files` only —
`INSTALL_ONCE_ROOT_FILES` (`settings.json`/`settings.local.json`, a deliberate one-time-install
carve-out for hand-edited settings). Nothing else is skip-on-exists. `scripts`/`hooks` (the
category the reported bug lives in) has none of these guards beyond `.syncprotect` — every
resync literally re-reads and re-writes every script byte-for-byte from source.

**`installed_files` is write-only bookkeeping, never read as a copy gate.** It is written by
`state_mod.mark_loaded` (state.lua:121) purely for future *unload* (`manager.unload` reads
`get_installed_files` to know what to delete) and for `manager.get_details`'s reporting. No code
path in `manager.load`, `manager.resync_all`, or `loader.copy_category` reads `installed_files`
to decide whether to copy something. The delegation's hypothesis that "`installed_files` is
treated as authoritative and short-circuits re-copy" is false.

**`manager.resync_all` (init.lua:901) has no diffing.** It topologically sorts every currently
`"active"` extension by declared dependency and calls
`manager.load(name, {confirm=false, project_dir=..., force=true})` for each, unconditionally. No
manifest version comparison, no content hash comparison, no per-file mtime comparison — every
declared file in every declared category is re-copied every time this runs. `manager.load`'s
`force` option (init.lua:284-299) bypasses exactly one thing: the "already loaded" early-return
abort (`state_mod.is_loaded(state, name) and not opts.force`). Everything downstream of that
check — the entire copy sequence, merge-target processing, state update — runs unconditionally
regardless of `force`, per the function's own doc comment.

**`deploy-headless.sh`'s default mode is exactly `manager.load('core', {force=true})` then
`manager.resync_all()`** (confirmed by reading its embedded Lua invocation string directly). This
closes the "bootstrap hypothesis" the delegation had already ruled out from the other direction:
not only does the repo under investigation have a `core` entry (ruling out the no-core-entry
bootstrap gap this script's header documents), the script's actual mechanism, if run, provably
overwrites every scripts/hooks entry regardless of what `.claude-extensions.json` says going in.

**Conclusion on Part 1**: the loader is not broken. Given `installed_files` is never consulted as
a copy gate and every copy call is unconditional, the only way a repo ends up with a stale `.claude/`
tree while `.claude-extensions.json` still lists the extension as `"active"` with the stale file
in `installed_files` is that **the deploy mechanism was never re-invoked** after the source store
changed underneath it — which is the system's documented, intentional design
(`context/patterns/regeneration-is-manual-only.md`): "Regeneration: Interactive by Default,
Headless When Driven Deliberately." The document is explicit that a prior revision of itself
wrongly claimed no headless path existed at all — i.e. even the deploy tooling's own history shows
this project has repeatedly under-communicated how deployment actually gets triggered. There is
exactly one sanctioned automated caller of `deploy-headless.sh` (`skill-orchestrate`'s Stage MT-3
step 7, evidence-gated on a dispatched commit touching a declared *critical path*, not "always").
Everything else — a plain `/research`, `/plan`, `/implement`, `/revise`, `/orchestrate` cycle that
never happens to trip that gate, or simply months of not running the picker's `[Reload All]` — is
by design silent. `.claude-extensions.json`'s per-extension `version` field compounds this: it is
the manifest author's version string (`core`'s has stayed `"1.0.0"` across every measured repo,
including the fully-fresh ones), not a content signal, so even `manager.get_status`'s existing
`needs_update` (a bare string compare) never flags drift that doesn't come with a version bump.

**Live reproduction of the reported bug pattern.** `/home/benjamin/.dotfiles` (found by scanning
`~/{,.dotfiles,Projects/*}/.claude-extensions.json` for a `core.installed_files` count in the
delegation's reported neighborhood) independently reproduces every qualitative signature the
delegation described, though the exact digits differ from the original snapshot because both the
source store and the target repos keep moving day to day:
  - `.claude-extensions.json`'s `core` entry: `status` implied active (present in `extensions`),
    298 `installed_files`, `version: "1.0.0"`, `loaded_at: "2026-07-27T10:46:14Z"` — ~3 weeks
    stale relative to this investigation's clock, with `.claude/scripts/task-lock.sh`'s and
    `.claude-extensions.json`'s own mtimes identical (one atomic deploy, no partial-revert
    evidence).
  - Deployed `.claude/scripts/task-lock.sh` is 818 lines vs. the current source's 1673 — and
    critically, `deploy-headless.sh` and `verify-deploy.sh` are **absent from the deployed tree
    AND absent from the recorded `installed_files` array**, meaning the last deploy predates
    those two scripts' addition to `core`'s manifest (they were added by the 980
    consolidate-deploy-to-single-engine work). The loader genuinely never attempted to copy them,
    because it was never re-run since they were added — not because it tried and skipped them.
  - Directory-level diff of top-level `.claude/scripts/*` against current source: 26 files present
    in source but missing from the deployed tree (staleness), and 13 files present in the deployed
    tree but absent from current core source (files that either moved to another extension's
    manifest or were retired from core's `provides.scripts` list since this repo's last sync —
    resync never *removes* entries that fall out of a manifest, only adds/overwrites what's
    currently declared).
  - By contrast, the four other consuming repos checked on this machine (`PersonalWebsite`,
    `cslib`, `BimodalLogic`, `ModelChecker`) all show `task-lock.sh` at exactly 1673 lines
    (byte-identical to source) and both `deploy-headless.sh`/`verify-deploy.sh` present, with
    `loaded_at` timestamps within the last week — i.e. they were deployed *after* the 980 work
    landed. This is strong, repo-count evidence that the discriminator is purely "was this repo
    resynced after the relevant source change," not any per-repo mechanism difference.

**`verify-deploy.sh` cannot be the detection answer as-is.** It is 563 lines implementing eleven
content-diffing gates (`gate0`..`gate10`) — deliberately thorough, deliberately not cheap. Its own
header states its one automated consumer is the orchestrator's inter-cycle checkpoint. It also has
the same bootstrap blind spot as every other deployed artifact: a repo stale enough to need the
warning is, by the same staleness, potentially missing the very script that would produce it (as
`~/.dotfiles` demonstrates for `deploy-headless.sh` and `verify-deploy.sh` together). It is a good
tool for the one place it already runs; it is not the preflight-cheap check this task needs.

**`install-extension.sh`** (named in the task's `file_scope`) is a separate, older, symlink-based
mechanism (skills/agents symlinks + `index.json` merge) rather than the copy-based engine that
`deploy-headless.sh`/the picker's `[Reload All]` drive. It does not appear to be in the resync
path the bug traversed and is not central to either the root-cause finding or the detection
design below; flagged here only because it was in scope and reviewed, not because it needs
changes.

### External Resources

Not applicable — this is a self-contained internal tooling investigation; no external
documentation was consulted.

### Recommendations

**Design for Part 2 — recommended: source-revision stamping + cheap preflight compare.**

This is the cheapest of the three directions the delegation named, and it reuses a building block
that already exists: `state_mod.mark_loaded` (state.lua:121-133) already records
`source_dir = manifest._source_dir` — the absolute filesystem path to the extension's source in
the source-store repo — into every consuming repo's `.claude-extensions.json`, for every
extension, today. This was independently confirmed on both a fresh repo (`~/.config/nvim` itself)
and the stale one (`~/.dotfiles`): both record the identical absolute
`/home/benjamin/.config/nvim/agent-system/extensions/core` path.

Concretely:

1. **Write side (Lua, `state.lua`/`init.lua`)**: at the same point `mark_loaded` stamps
   `source_dir`, also stamp `source_git_head` — the result of
   `git -C <source-store repo root> log -1 --format=%H -- <source_dir's repo-relative path>`
   (or, more simply, `git -C source_dir rev-parse --show-toplevel` to find the repo root, then a
   path-scoped `git log -1`). Measured cost on this machine: ~2ms per extension
   (`time git log -1 --format=%H -- agent-system/extensions/core` → 0.002s real). Gracefully
   degrade to omitting the field (never erroring the load) if `source_dir` is not inside a git
   repository, so this never becomes a load-blocking dependency on git being present/clean.
2. **Read side (bash, `command-gate-in.sh`)**: after task lookup, before or alongside the
   existing task-lock acquisition, add a small, non-blocking check: for each entry in
   `.claude-extensions.json`'s `extensions` object that carries both `source_dir` and
   `source_git_head`, recompute the current path-scoped `git log -1 --format=%H` against
   `source_dir` and compare. On any mismatch, print one WARN line per stale extension naming it
   explicitly and pointing at the remedy (`bash .claude/scripts/deploy-headless.sh` or the
   picker's `[Reload All]`) — never abort the command. An extension whose recorded entry lacks
   `source_git_head` (pre-this-fix deploys, exactly `~/.dotfiles`'s current state) is silently
   skipped rather than flagged, since "unknown" must not read as "confirmed fresh" or trigger a
   false alarm; this is an intentional, honestly-scoped bootstrap gap identical in kind to
   `verify-deploy.sh`'s own — it closes itself automatically the next time that repo is resynced
   for any reason, including specifically to pick up this very fix.
3. Package the read-side logic as a small, standalone script (e.g.
   `check-deploy-freshness.sh`) rather than inlining it, so `command-gate-in.sh` stays focused and
   the check stays independently testable/reproducible, mirroring `verify-deploy.sh`'s own
   "print the command it stands for" ethos but scoped to the one cheap gate rather than all eleven.

**Why this direction over the other two named in the delegation**:
- *"Extend `/refresh` or a doctor check"*: `/refresh` and any doctor-style command are opt-in —
  a user has to think to run them. The delegation's acceptance criterion is "a user running an
  *ordinary* command... receives an actionable warning," which requires the check to sit on a path
  every command already crosses unconditionally. `command-gate-in.sh` is that path (it is
  literally CHECKPOINT 1, sourced by every one of `/research`/`/plan`/`/implement`/`/revise`/
  `/orchestrate` before any real work starts, and is the exact script whose `task-lock.sh`
  dependency crashed in the original bug report). A doctor check remains valuable as a
  *deep-dive* companion (e.g. `verify-deploy.sh` already fills that role) but does not by itself
  satisfy "no signal unless you already suspect a problem."
- *"Per-file hash manifest a preflight can validate cheaply"*: strictly more expensive than a
  single revision stamp for equivalent signal quality at this decision point. Detecting "core's
  source moved since I was last deployed" needs exactly one comparison per extension, not one
  comparison per file; a per-file hash manifest would also have to be generated and stored
  (hundreds of entries per extension, per the file counts measured above: 75+ scripts alone in
  `core`) and kept in sync with every category, multiplying both write-side and read-side cost for
  no additional information this decision needs. It would be the right tool if the eventual UX
  goal were "tell me exactly which files drifted" rather than "tell me a regeneration is due" —
  that finer-grained job is already `verify-deploy.sh`'s, and this design deliberately keeps the
  preflight gate itself binary and cheap, deferring to `verify-deploy.sh --findings` (already
  wired for machine-diffable per-gate findings) for anyone who wants the detail after the WARN
  fires.

**Fix requirement carried from Part 1**: since no loader defect was found, there is no code fix
required to the copy engine itself. The "fix" this task's acceptance criterion calls for is
entirely the detection mechanism above — Part 1's contribution is establishing, with reproduced
live evidence, that this is the correct and complete scope (no separate copy-engine patch is
owed).

## Decisions

- **No loader/copy-engine defect exists**; do not spend implementation effort "fixing" the copy
  path. All four named hypotheses (skip-existing, installed_files-gates-copy, diff-only resync,
  partial revert) were directly falsified by reading `loader.lua`/`init.lua` and are not
  re-litigated in planning.
- **Detection mechanism**: source-revision stamping (`source_git_head`, sibling to the existing
  `source_dir` field) + a cheap `command-gate-in.sh`-level WARN, packaged as a small standalone
  script. This is the direction to carry into `/plan`.
- **`install-extension.sh`** is out of scope for the fix; it is a separate symlink-based mechanism
  not implicated in either the root cause or the detection design.
- **Missing-`source_git_head` entries WARN never**, not even a generic "cannot verify" notice —
  silence is the correct behavior for pre-fix deploys, to avoid a false "everything's fine" read
  and to avoid noise on every command until that repo's next resync closes the gap naturally.

## Risks & Mitigations

- **Git dependency**: the check assumes the recorded `source_dir` is inside a git repository and
  `git` is on `PATH` in the consuming environment's shell. Mitigation: treat any git failure
  (non-repo, git absent, `source_dir` unreadable) as "cannot verify," identical to the
  missing-field case — skip silently, never error the command.
- **False positives from unrelated source-store churn**: scoping the `git log` call to the
  extension's own `source_dir` subpath (not the whole source-store repo's `HEAD`) avoids flagging
  drift when an unrelated part of the source store changes (e.g. a different extension, or `lua/`
  plugin code) — confirmed cheap and correctly scoped in the measurement above.
- **Cross-machine / relocated source store**: `source_dir` is an absolute, machine-local path
  (confirmed: identical across all five repos checked here because they share one workstation's
  `~/.config/nvim`). A consuming repo checked out on a different machine, or one whose source
  store moved, will have a `source_dir` that no longer exists — this is already the same
  "cannot verify, skip silently" path as the git-absent case, so no additional handling is needed,
  but it does mean this design provides no signal cross-machine; that is an acceptable, explicitly
  scoped limitation given the acceptance criterion only requires detection to work for the normal
  single-workstation case reproduced here.
- **Sibling task 9 interaction** (noted in the task description): task 9's 4-orphan-file evidence
  was measured against this same class of stale tree and should be re-measured post-fix against a
  freshly regenerated tree, since orphan files are an expected *symptom* of the pull-only design
  (files removed from a manifest are never deleted by resync) rather than necessarily a
  one-directional-parity defect in `verify-deploy.sh` itself. This report does not re-adjudicate
  task 9; it only confirms the shared staleness substrate task 9's evidence sits on top of.

## Context Extension Recommendations

- **Topic**: staleness-detection design, once implemented, should get a short pointer added
  alongside `context/patterns/regeneration-is-manual-only.md` (e.g. a "Detecting When You're
  Stale" subsection or sibling doc) so future readers of that pattern immediately see both halves:
  "regeneration is manual" and "here is how a stale repo finds out." Leaving the manual-only
  pattern undocumented on this point risks a future contributor re-discovering the same gap this
  task closes.

## Appendix

### Search queries / commands used
- `grep -rn "resync_all\|installed_files" agent-system/extensions/core/scripts/lib/*.sh` (no hits
  in bash; the mechanism is Lua-side)
- `grep -rln "resync_all\|installed_files" --include=*.lua --include=*.sh --include=*.json .`
  → located `lua/neotex/plugins/ai/shared/extensions/{loader,init,state,manifest}.lua`
- Direct reads: `loader.lua` (copy engine), `init.lua:269-975` (`manager.load`,
  `manager.resync_all`), `state.lua` (state read/write, `mark_loaded`)
- `deploy-headless.sh` full read (237 lines) — confirmed default-mode invocation string
- Cross-repo scan: `find ~ -maxdepth 3 -iname ".claude-extensions.json"` →
  `~/.dotfiles`, `~/Projects/{PersonalWebsite,cslib,BimodalLogic,ModelChecker}`
- Per-repo `jq` extraction of `core.{version,loaded_at,installed_files length}` +
  `wc -l .claude/scripts/task-lock.sh` + presence check for `deploy-headless.sh`/`verify-deploy.sh`
  across all five repos
- `comm -23`/`comm -13` diff of `~/.dotfiles/.claude/scripts/*` top-level filenames against
  `agent-system/extensions/core/scripts/*` to quantify missing/orphaned scripts
- `time git log -1 --format=%H -- agent-system/extensions/core` (0.002s) — feasibility check for
  the recommended detection mechanism's per-extension cost
- Read `context/patterns/regeneration-is-manual-only.md` in full (automated-exception scope),
  `context/schemas/orchestrator-handoff-schema.json` and
  `docs/architecture/handoff-schema.md` (for this dispatch's own handoff-writing contract)
