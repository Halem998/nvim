# Research Report: Task #58

**Task**: 58 - Add a version-consistency preflight gate to /tag
**Started**: 2026-08-12T21:00:00Z
**Completed**: 2026-08-12T21:17:00Z
**Effort**: 2 hours (per TODO.md estimate)
**Dependencies**: None (SCOPE NOTE in task description rules out fix_return_meta_lifecycle_ordering overlap as spurious)
**Sources/Inputs**: Codebase (skill-tag/SKILL.md, commands/tag.md, check-extension-docs.sh, state-management context), sandboxed shell verification of extraction commands
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is exactly as described: `skill-tag/SKILL.md` Step 3 computes the new tag purely
  from `git describe --tags --abbrev=0`; no step reads any package manifest, so the computed tag
  and the declared package version can silently diverge, and the divergence is only ever caught
  downstream in CI, after the tag has already been pushed.
- A new step must run after Step 3 (which produces `new_version`) and before Step 5's dry-run
  branch (which currently `exit 0`s before any further validation) — the natural insertion point
  is a new **Step 3.5: Validate Version Consistency**, immediately after Step 3 and before Step 4
  (Display Summary), so dry-run, interactive, and `--force` paths all pass through it identically.
- Three ecosystem-general extraction patterns were tested and confirmed working with portable
  `sed`/`grep`/`jq` (no GNU-only `awk` extensions): pyproject.toml `[project]` section, Cargo.toml
  `[package]` section, package.json via `jq -r .version`. setup.cfg `[metadata]` and setup.py
  keyword-argument heuristic were also confirmed. All patterns correctly fall through to "no
  version found" (rather than a false match) on PEP 621 `dynamic = ["version"]` and Cargo
  `version.workspace = true` — both are real "version not statically declared here" cases, not
  errors.
- **Important finding**: the observed real-world failure (ModelChecker) declares its version in
  `code/pyproject.toml`, not a repo-root `pyproject.toml`. A root-only manifest search would have
  missed the exact case this task exists to catch. Manifest discovery needs a bounded-depth
  search from `git rev-parse --show-toplevel`, excluding vendor/build directories, not a root-only
  check.
- Design decision (4) — auto-bump vs. report-and-stop — is deliberately left open per the task
  description; this report surfaces the tradeoff (below) without settling it.
- No existing lint (`check-extension-docs.sh` or any other script under
  `agent-system/extensions/core/scripts/`) enforces parity between `SKILL.md` Step 2/new-step
  content and `commands/tag.md`'s Requirements/Workflow lists — that pairing is currently
  maintained by hand only, confirming design point (6) is a real, unenforced doc-truth gap.

## Context & Scope

Researched the current `/tag` implementation end-to-end (both the source-store skill and its
command doc), surveyed version-declaration file formats for Python, Node, and Rust, and
verified concrete extraction commands in a sandbox against representative fixtures (including
the two "no static version" edge cases: PEP 621 `dynamic`, Cargo `workspace` inheritance). Did
not touch any file scoped for implementation — this is a research-only pass per the SCOPE NOTE
and per delegation contract. Did not attempt to settle design decision (4) (auto-bump vs.
report-and-stop), per the task description's explicit instruction to surface it for the planner.

## Findings

### Codebase Patterns

**`agent-system/extensions/core/skills/skill-tag/SKILL.md`** (source of truth; deploys to
`.claude/skills/skill-tag/SKILL.md`, which is disposable):

- Step 1 (Parse Arguments): sets `increment`, `force`, `dry_run` from `$*` substring matches.
- Step 2 (Validate Git State): four checks only — clean working tree (`git status --porcelain`),
  not detached HEAD (`git rev-parse --abbrev-ref HEAD` != `HEAD`), not behind remote
  (`git fetch` + `git rev-list --count`). No manifest is consulted here or anywhere else in the
  file.
- Step 3 (Compute New Version): `current_version=$(git describe --tags --abbrev=0 ...)`, sed-splits
  major/minor/patch, increments per `$increment`, sets `new_version="v${major}.${minor}.${patch}"`,
  and checks the computed tag doesn't already exist (`git rev-parse "$new_version"`). This is the
  step where `new_version` first becomes available — any consistency check must run at or after
  this point.
- Step 4 (Display Summary): prints `current_version -> new_version`, branch, commit, commits
  since last tag. Purely informational, no gating.
- Step 5 (Execute Based on Mode): the dry-run branch is a literal `if [ "$dry_run" = true ]; then
  ... exit 0; fi` that runs *before* the Force/Interactive branches. This confirms requirement
  (5)'s ordering note precisely: today, nothing after Step 4 runs in a dry-run invocation, so any
  new gate placed at or after Step 5 would never fire for `--dry-run`. The gate must be inserted
  strictly before Step 5's dry-run branch — i.e., between Step 3 and Step 4, or as part of Step 4
  itself before it prints — to be exercised by `--dry-run`.
- Step 5 continues with Force Mode (skip confirmation, go to Step 6) and Interactive Mode
  (`AskUserQuestion` confirmation).
- Step 6 (Create and Push Tag): `git tag "$new_version"` then `git push origin "$new_version"`.
  These are the two operations the task requires the gate to precede.
- Step 7 (Update state.json): writes `.deployment_versions.last_deployed` /
  `deployment_history` via `jq`. Not implicated by this task.
- "Error Handling" section documents three failure transcripts (Dirty Working Tree, Behind
  Remote, Tag Already Exists) in a consistent `=== Section ===` / `Error: ...` / (blank) /
  `Resolution: ...` shape. A new "Version Mismatch" transcript following the same shape is the
  natural style match for requirement (1)'s "actionable message naming both versions and the file
  to edit."

**`agent-system/extensions/core/commands/tag.md`**:

- "Workflow" section (7 numbered steps, lines ~48-56) mirrors `SKILL.md`'s Step 1/2 through
  Step 7, one line each, with no step for the new gate.
- "Requirements" section (lines ~60-65) is a flat bullet list of exactly the four conditions
  Step 2 checks today: clean working tree, on a branch, up-to-date with remote, no existing tag
  with computed version. It does not currently list anything about declared-version consistency.
- This confirms design point (6) literally: the "Requirements list … currently lists the same
  four conditions as Step 2" claim in the task description is accurate, and there is no fifth
  entry for the computed-tag-exists check either (interesting: Step 3's "tag already exists"
  check *is* listed in Requirements, so Requirements already mixes Step 2 and Step 3 concerns —
  precedent exists for a Requirements-list entry to correspond to a check that isn't literally in
  "Step 2" by name, which supports appending a version-consistency line here without needing a
  Step-2-only framing).

### Doc-Truth Enforcement (or lack thereof)

`agent-system/extensions/core/scripts/check-extension-docs.sh` is the repo's doc-lint script (36
lettered checks A–V). Its checks (`E`: script referenced in docs but undeclared in
`provides.scripts`; `K`: deployed command with no `provides.commands` source; etc.) operate at
the *manifest/deploy* level — file existence, symlink integrity, drift between deployed and
source copies, index-entry accuracy. None of them compare prose content *within* a single skill's
steps against its paired command doc's Requirements/Workflow lists. Grepping the whole
`agent-system/` and `.claude/` trees for any script or check referencing "version-consistency",
"declared version", or similar turned up nothing — this task is not adding a gate check to an
existing pattern, it is establishing a new one. That means decision (6) — whether to update
`tag.md`'s Requirements/Workflow — is purely an authoring-discipline question for this task's
implementation; there is no separate lint to satisfy or extend, and none is proposed here (out of
scope per the file_scope, which covers only the two skill-tag/tag.md files).

### External Resources — Ecosystem Version-Source Survey

All four commands below were run in a sandbox against representative fixture files and confirmed
working with POSIX-portable `sed`/`grep`/`jq` (no GNU-`awk`-only 3-arg `match()`, which is not
guaranteed portable across `awk` implementations a contributor's shell might have).

**Python — `pyproject.toml`** (PEP 621 `[project]` table):
```bash
sed -n '/^\[project\]/,/^\[/p' pyproject.toml \
  | grep -m1 '^version[[:space:]]*=' \
  | sed -E 's/^version[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/'
```
Verified: extracts `1.3.0` from a `[project]` table containing `version = "1.3.0"` even when a
later `[tool.poetry]` table in the same file declares a *different* version (`9.9.9`) — the
`sed` range confines matching to the `[project]` section, avoiding a false match against Poetry's
legacy `[tool.poetry].version` field. Poetry-only projects (no `[project]` table, only
`[tool.poetry]`) would need a second pass scoped to `[tool.poetry]` if that convention is to be
supported — noted for the planner as an optional second pyproject variant, not implemented here.

**Python — PEP 621 dynamic version** (`dynamic = ["version"]`, version supplied at build time by
`setuptools-scm`/`hatch-vcs`/etc.): the same `[project]`-scoped extraction correctly returns
empty, because no `version = "..."` line exists in the section. This is semantically the same as
"no declared version found" — and arguably *more* correct to treat that way, since a
`setuptools-scm`-managed project derives its version *from* git tags/describe, making a
tag-vs-manifest consistency check circular for that specific configuration. Verified in sandbox.

**Python — `setup.cfg`** (`[metadata]` section, unquoted value):
```bash
sed -n '/^\[metadata\]/,/^\[/p' setup.cfg \
  | grep -m1 '^version[[:space:]]*=' \
  | sed -E 's/^version[[:space:]]*=[[:space:]]*([^ ]*).*/\1/'
```
Verified: extracts `3.2.1` from `version = 3.2.1` under `[metadata]`.

**Python — `setup.py`** (no reliable static-parse guarantee; version is a Python expression
inside a `setup(...)` call and can be a variable, an `os.environ` read, an import from a
`_version.py`, etc.): a best-effort literal-string heuristic —
```bash
grep -m1 -E "version[[:space:]]*=[[:space:]]*['\"]" setup.py \
  | sed -E "s/.*version[[:space:]]*=[[:space:]]*['\"]([^'\"]*)['\"].*/\1/"
```
Verified against a literal `version="4.5.6"` kwarg. This heuristic will correctly find nothing
(not a false positive) for any `setup.py` that computes its version programmatically —
important, since a wrong extraction here is worse than a missed one (a false "declared version"
could trigger a spurious gate failure on a perfectly good release). Recommend treating a
non-match here the same as "no version declared" rather than erroring, given the heuristic's
known blind spot.

**Node — `package.json`**:
```bash
jq -r '.version // empty' package.json
```
Verified: extracts `2.1.0`. This is the only one of the five formats with a real parser
(`jq`) already a hard dependency elsewhere in `skill-tag/SKILL.md` itself (Step 7 uses `jq`
already), so no new tool dependency is introduced.

**Rust — `Cargo.toml`** (`[package]` table):
```bash
sed -n '/^\[package\]/,/^\[/p' Cargo.toml \
  | grep -m1 '^version[[:space:]]*=' \
  | sed -E 's/^version[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/'
```
Verified: extracts `0.4.2`.

**Rust — workspace-inherited version** (`version.workspace = true` instead of a literal string,
Cargo's workspace-inheritance feature): verified the same extraction correctly returns empty,
because `grep -m1 '^version[[:space:]]*='` does not match `version.workspace = true` (the `.` after
`version` breaks the anchored pattern before reaching `=`). This is exactly the desired outcome —
the actual version lives in a workspace-root `Cargo.toml` this file doesn't identify by path in
general, so "no version found here" is the honest answer, not a bug to fix by chasing the
workspace root.

**Lua/Nix and "no manifest" case**: confirmed no plausible manifest file exists for either
ecosystem in typical layouts (Lua has no standard package-manifest-with-version convention in
this repo's own `lua/neotex/` tree; Nix flakes do not carry a semantic version field in
`flake.nix` by convention). No extraction pattern applies; these fall through to the explicit
"no declared version found" branch by construction — no special-casing needed for these
ecosystems specifically.

### Critical Structural Finding: Manifest Location Is Not Reliably Repo Root

The task's own "OBSERVED FAILURE" section states the ModelChecker repo's manifest is
`code/pyproject.toml` — a **subdirectory**, not the repo root. This is not a hypothetical edge
case; it is the exact repo and exact failure this task exists to prevent. A version-source
detector that only checks `$(git rev-parse --show-toplevel)/pyproject.toml` (etc.) would find
nothing in that repo and silently fall into the "no version declared, skipping" branch — passing
the gate on the very failure it was built to catch.

Implications for the planner:
- Manifest discovery needs to search from the repo root with **bounded depth** (e.g., root plus
  one or two levels down), not root-only and not fully recursive.
- A fully recursive, unbounded search is unsafe for Node repos specifically: `package.json` files
  proliferate inside `node_modules/` by the thousands. Any recursive search MUST exclude at least
  `node_modules`, `.git`, `dist`, `build`, `target`, `__pycache__`, `.venv`, `venv` (this list is
  not exhaustive; the planner should treat it as a starting point, not a final one).
- `find "$repo_root" -maxdepth 2 -not -path '*/node_modules/*' -not -path '*/.git/*' \( -name pyproject.toml -o -name package.json -o -name Cargo.toml -o -name setup.cfg -o -name setup.py \)` is
  a plausible starting shape; verified `find -maxdepth` semantics are portable GNU/BSD, unlike
  some other `find` flags. Not verified end-to-end against a real multi-file monorepo in this
  research pass — flagging as a planning-phase implementation detail, not a settled design.
- If more than one manifest file is found (e.g., both a root `package.json` for tooling and a
  `code/pyproject.toml` for the actual release artifact), the planner needs to decide: check all
  found manifests for mutual consistency with the tag, or prioritize by some ecosystem order.
  Not settled here — surfaced for the planning phase.

### Recommendations

1. **Insertion point**: add a new step (suggest "Step 3.5: Validate Version Consistency" or
   renumber to Step 4 and shift the rest) immediately after Step 3 (`new_version` is known) and
   before Step 4's Display Summary / Step 5's dry-run branch. This is the only placement that
   satisfies requirement (5) (dry-run must exercise the check) given Step 5's current `exit 0`
   ordering.
2. **Version comparison**: strip the `v` prefix from `new_version` before comparing to the
   manifest string (`new_version_bare="${new_version#v}"`), since none of the five surveyed
   manifest formats use a `v`-prefixed version convention. Comparison should probably be exact
   string equality on the bare version for a first cut; pre-release/build-metadata suffixes
   (`1.3.0-rc1`, `1.3.0+build5`) are a known nuance not resolved here — flag for the planner
   rather than silently deciding a normalization rule.
3. **Error message shape** (requirement 1): mirror the existing `Error: ... / (blank) /
   Resolution: ...` transcript convention already used for the three documented failure modes.
   Must name (a) the computed tag version, (b) the declared manifest version, and (c) the
   manifest file path found, e.g.:
   ```
   Error: Declared package version (1.3.0) does not match computed tag (v1.3.1).

   Declared in: code/pyproject.toml (version = "1.3.0")
   Computed tag: v1.3.1 (patch release from v1.3.0)

   Resolution: Update the version in code/pyproject.toml to 1.3.1, commit, then re-run /tag.
   ```
4. **No-manifest-found notice** (requirement 3): print a visible, distinctly-worded line — not
   silence, not an error — e.g. `No declared package version found (checked pyproject.toml,
   setup.cfg, setup.py, package.json, Cargo.toml near repo root). Skipping version-consistency
   check.` This must appear in both dry-run and real-run transcripts identically, since dry-run's
   entire value proposition here is showing the user what checks did/didn't run.
5. **Design decision (4) — explicitly NOT settled here**, per task instructions. Tradeoffs for
   the planner:
   - **Report-and-stop** (fail closed, print the mismatch, exit 1, let the user edit the manifest
     and re-run): matches `/tag`'s existing failure philosophy exactly — every other Step 2/3
     failure mode (dirty tree, detached HEAD, behind remote, tag exists) is report-and-stop, none
     auto-fixes. Keeps `/tag`'s blast radius to "tagging and pushing" only, consistent with its
     documented purpose and its `user-only` status. Does not need a new commit step or new
     write-access to arbitrary manifest files.
   - **Auto-bump**: would need to (a) parse-and-rewrite the manifest's version field in place
     (a fundamentally different operation from parsing — safe editing of TOML/JSON with exact
     formatting preservation is nontrivial, especially for `setup.py`'s free-form Python), (b)
     create a commit for that change before `git tag` can point at a commit where the two agree,
     which either requires a second `git push` before the tag push (widening the "already pushed,
     now need to clean up" risk window this task exists to shrink) or bundling the bump into the
     same commit users are tagging (surprising side effect from a command whose name and
     documented job is "tag", not "release-prep"), and (c) decide which manifest to bump when
     multiple are found. Auto-bump is strictly more capable but strictly more complex and higher-
     risk; report-and-stop is the smaller, safer, more consistent-with-existing-precedent change.
   - This report takes no position beyond flagging report-and-stop as *lower risk given /tag's
     existing conventions*, per the task description's own framing — the planning phase should
     make and record the actual decision.
6. **Doc parity (decision 6)**: recommend updating both the Requirements list (append a fifth
   bullet, following the existing precedent that Requirements already mixes Step 2 and Step 3
   concerns) and the Workflow list (insert a new numbered line between current items 2 and 3) in
   `commands/tag.md`, so the documented contract names the gate. No existing lint enforces this
   pairing (see Doc-Truth Enforcement finding above), so this is a manual authoring requirement
   for whichever implementation phase touches these files, not something a script will catch if
   skipped.

## Decisions

- No design decisions were made in this research pass beyond confirming the technical feasibility
  and portability of the extraction commands above (all verified in a sandbox). Design decision
  (4) (auto-bump vs. report-and-stop) is explicitly deferred to planning, per task instructions.
- Recommend the gate's insertion point be a new step immediately after current Step 3, not a
  modification of Step 2 or Step 5, based on the `new_version` dependency and the dry-run
  ordering constraint documented above.

## Risks & Mitigations

- **Risk**: naive root-only manifest search misses subdirectory manifests (as in the real
  observed failure). **Mitigation**: bounded-depth search with vendor-dir exclusions, per the
  "Critical Structural Finding" section above.
- **Risk**: `setup.py`'s free-form Python version expression can't be reliably statically parsed.
  **Mitigation**: treat non-match as "no version declared" (fail open to skip, not fail closed to
  error) — a missed check is safer than a false-positive block on a legitimate release.
- **Risk**: multiple manifests present (monorepo, or tooling `package.json` alongside a Python
  release manifest) could disagree with each other, not just with the tag. **Mitigation**: not
  resolved here; the planner should decide whether to check all found manifests or use a priority
  order, and whether cross-manifest disagreement (independent of the tag) is in scope at all.
- **Risk**: pre-release/build-metadata suffixes cause false-positive mismatches on otherwise
  correct releases. **Mitigation**: flagged for planning; not resolved here.
- **Risk**: doc parity (tag.md Requirements/Workflow) drifts from the implemented gate if the
  implementer forgets to update it, since no lint currently catches this. **Mitigation**: explicit
  recommendation above; implementation-phase checklist item.

## Context Extension Recommendations

- **Topic**: Ecosystem version-manifest detection patterns (pyproject.toml/setup.cfg/setup.py/
  package.json/Cargo.toml extraction).
- **Gap**: No existing context file under `.claude/context/` documents portable shell patterns
  for reading a package's declared version across ecosystems. This knowledge was derived fresh
  in this research pass via sandbox verification.
- **Recommendation**: after implementation, consider a short context file (e.g. under
  `agent-system/extensions/core/context/patterns/` or similar) capturing the verified extraction
  commands from this report, since `/tag` is unlikely to be the last place in this cross-repo
  agent system that needs to answer "what version does this package declare" — this is a
  meta-task-appropriate observation, not a general-task one, matching this task's `task_type:
  meta`.

## Appendix

- Files read: `agent-system/extensions/core/skills/skill-tag/SKILL.md`,
  `agent-system/extensions/core/commands/tag.md`,
  `agent-system/extensions/core/scripts/check-extension-docs.sh` (header/rule-index portion),
  `agent-system/extensions/web/context/project/web/domain/web-reference.md` (deployment_versions
  schema, for context only — not implicated by this task).
- Searches run: repo-wide grep for `pyproject.toml`/`Cargo.toml`/`package.json` references (no
  existing version-manifest-parsing infrastructure found anywhere in `agent-system/` or
  `.claude/`); repo-wide grep for `version-consistency`/`version_source`/`declared version`
  (nothing found — confirms this is new territory); repo-wide grep for `doc-truth` (nothing —
  the term is task-author's own framing, not an existing repo convention); repo-wide grep for
  `deployment_versions` (found only in `skill-tag/SKILL.md` Step 7 and the web extension's
  documentation of that same schema — unaffected by this task).
- Sandbox verification: five extraction commands (pyproject.toml `[project]`, pyproject.toml
  `dynamic`, Cargo.toml `[package]`, Cargo.toml `version.workspace = true`, setup.cfg
  `[metadata]`, setup.py heuristic, package.json via `jq`) run against fixture files in
  `/tmp/claude-1000/.../scratchpad/vertest/`; all behaved as documented above.
