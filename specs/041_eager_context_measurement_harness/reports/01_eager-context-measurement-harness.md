# Research Report: Eager Context Measurement Harness

**Task**: eager_context_measurement_harness (`measure-eager-context.sh`)
**Started**: 2026-08-17T17:55:00Z
**Completed**: 2026-08-17T18:05:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (source-store scripts, Lua extension loader, rules frontmatter, prior task artifact), no web search needed
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- A prior, campaign-scoped tool already exists at
  `agent-system/extensions/core/scripts/measure-eager-surface.sh` — built for a different,
  now-completed task ("cut generated CLAUDE.md eager surface") — and it embodies exactly the two
  anti-patterns this new task exists to fix: it measures the **deployed** `.claude/CLAUDE.md` and
  `.claude/rules/*.md`, and it hardcodes a fixed 9-file list rather than deriving eager rules from
  `paths:` frontmatter. It is legitimate prior art (naming/output conventions worth partially
  reusing) but must not be mistaken for satisfying this task.
- The precise assembly algorithm for `.claude/CLAUDE.md` is `generate_claudemd()` in
  `lua/neotex/plugins/ai/shared/extensions/merge.lua:768-879`. It is fully reproducible in bash by
  reading source-store files only — no `nvim --headless` invocation is required, and per a hard
  repo-wide policy (`context/patterns/regeneration-is-manual-only.md`) invoking
  `deploy-headless.sh` from a new automated script would in fact be **out of policy** (only one
  sanctioned automated caller exists, and this script is not it). The harness must therefore
  **model** the concatenation in bash, not shell out to a real regenerate.
- The task's own literal spec for "rules lacking `paths:` frontmatter, or carrying
  `paths: "**/*"`" is **known-incomplete** per a correction already recorded in the repo
  (`specs/archive/054_split_eager_rules_budget/baseline-bytes.md`, "Eager-Context
  Measurement-Harness Correction" section) explicitly addressed to this task: that model
  undercounts eager rules by ~71% because it misses rules gated on `specs/**/*` /
  `.claude/**/*` globs, which match virtually every real session. The harness MUST glob-match each
  rule's `paths:` value against a representative touched-path set (at minimum `specs/**` and
  `.claude/**`), not just check absent-or-universal frontmatter.
- The baseline "~69.9 KB / ~17.5k tokens" figure in the task description is traceable to an exact,
  reproducible number: **70,160 B** (= 17,540 tokens at bytes/4), recorded as the Phase 7
  post-redeploy "whole-prefix" figure in `specs/archive/054_split_eager_rules_budget/baseline-bytes.md`,
  itself matching the prior task 57's own final acceptance measurement. This is the number to
  target for parity, not a fresh invention.
- `@`-imports currently resolve to **zero** eager bytes anywhere in the chain (parent CLAUDE.md,
  repo CLAUDE.md, both `claudemd` merge sources) — confirmed by grep; `context-layers.md` states
  this is deliberate (merge sources use plain backticked paths, never `@`-refs, specifically to
  avoid silent eager inlining). The harness's `@`-import channel will legitimately report 0 today,
  and that is a correct result, not a bug to chase.
- `generate-context-line-counts.sh` establishes the `--check`/`--write` convention to mirror:
  default action, argument-position flag, `--check` reports/exits nonzero on problems,
  `--write` mutates and reports "changed" counts, both modes always operate on `agent-system/extensions/**`
  source files, and the script sources `deploy-root-guard.sh` for `REPO_ROOT`-bypass safety.

## Context & Scope

Scope files per the delegation: `agent-system/extensions/core/scripts/measure-eager-context.sh`
(new) and `agent-system/extensions/core/context/architecture/context-layers.md` (context source,
not necessarily an edit target — see Decisions below on this). All edits target the source store
under `agent-system/extensions/**`; the deployed `.claude/**` tree is a disposable build artifact
this task must never write to or depend on for its answer.

## Findings

### 1. How `.claude/CLAUDE.md` is actually assembled (the crux)

The generation logic lives in `lua/neotex/plugins/ai/shared/extensions/merge.lua`,
`function M.generate_claudemd(project_dir, config)` (lines 768-879). `lua/neotex/plugins/ai/claude/extensions/merge.lua`
is a 62-line back-compat re-export shim that delegates to the shared module; the shared file is
canonical. Algorithm, read directly from source:

1. Read `state.extensions` from the project's extension-state file (`root_state_file` in config,
   which resolves to `.claude-extensions.json` at the **project root**, confirmed by
   `state.lua:73-75`'s `get_state_path`). `M.list_loaded(state)` (state.lua:227-236) collects every
   extension whose `status == "active"` and returns them **sorted alphabetically**.
2. Build `ordered_names`: walk the sorted list once to pull `"core"` to the front (a no-op in
   practice since `"core"` already sorts first alphabetically among this repo's currently-active
   set: `core, email, literature, memory, nix, nvim`), then append the remaining sorted names.
3. For each extension in that order, read its `manifest.json`'s `merge_targets.claudemd`. If
   present, resolve `source` relative to the extension's own directory
   (`agent-system/extensions/<ext>/<source>`) and read that file's content as one fragment.
   Two source shapes exist across the six currently-active extensions (verified by direct read of
   each manifest's `merge_targets.claudemd.source` field):
   - **Shape (a)** — `merge-sources/claudemd.md`: `core`, `literature`.
   - **Shape (b)** — `EXTENSION.md` (extension root): `email`, `memory`, `nix`, `nvim`.
   (`check-extension-docs.sh`'s `claudemd_source_for()` helper, lines 736-759, documents and
   relies on this exact same manifest-authoritative two-shape distinction — do not hardcode
   either shape name; always resolve via `.merge_targets.claudemd.source`.)
4. If `core` is among the loaded extensions, additionally look for
   `agent-system/extensions/core/templates/claudemd-header.md` (confirmed present) and prepend it
   as the first `parts` entry.
5. Each fragment is right-trimmed (`gsub("%s+$", "")`) and joined with the others (header first,
   then fragments in `ordered_names` order) via `"\n\n"`, with a single trailing `"\n"` appended to
   the whole output. This join logic is exactly reproducible in bash: `printf` each trimmed file
   with `\n\n` separators plus a final newline.
6. The result is written to `target_path`, resolved as `project_dir/<mt.target>` from the first
   extension found declaring a `merge_targets.claudemd.target` (in this repo, every extension
   agrees on `.claude/CLAUDE.md`).

**Why the harness must not invoke a real regenerate.** `scripts/deploy-headless.sh` is the
sanctioned headless entry point to this same logic (it drives `manager.resync_all`/`manager.wipe`
via `nvim --headless`), but `context/patterns/regeneration-is-manual-only.md` states explicitly:
"The exact and only sanctioned automated call site: `skill-orchestrate`'s Stage MT-3 step 7 ...
No other automated caller is sanctioned by this subsection... this carve-out explicitly does NOT
license any other automated caller." A new `measure-eager-context.sh` that shells out to
`deploy-headless.sh` (even against a scratch/temp copy) would be exactly the kind of new automated
caller that document forbids without its own recorded exception. This is precisely consistent with
the task's own phrasing — "PREDICTS ... plus a fresh regenerate" — the harness computes what a
regenerate *would* produce by replicating the algorithm above in bash against source-store files
directly, never by actually running one. This is the single most important design constraint for
the implementer to internalize; getting it wrong (adding a `deploy-headless.sh` call) is both a
policy violation and reintroduces the exact deployed-tree dependency the task exists to eliminate.

Practical bash replication:
```bash
# 1. Read active extensions, sorted, core first (core already sorts first today)
jq -r '.extensions | to_entries[] | select(.value.status=="active") | .key' .claude-extensions.json | sort
# 2. For each, resolve its claudemd source
jq -r '.merge_targets.claudemd.source // empty' agent-system/extensions/<ext>/manifest.json
# 3. Concatenate: header (if core loaded) + each trimmed fragment, joined by blank lines
```
No `nvim` invocation, no dependency on `.claude-extensions.json` matching what's deployed — this
state file is itself part of the source-of-truth project root (not inside `.claude/`), so reading
it is legitimate and not a "measure the deployed tree" violation.

### 2. `@`-import resolution rule and current resolution status

Confirmed against `context/architecture/context-layers.md`'s "Eager vs. Lazy Loading Channels"
section (channel 2, lines 139-151): an `@path` reference inside a CLAUDE.md file resolves
**relative to the containing file's directory**. From within `.claude/CLAUDE.md`, `@context/...`
resolves (to `.claude/context/...`) and loads eagerly; `@.claude/...` resolves to the nonexistent
`.claude/.claude/...` and silently loads nothing — no error surfaces to a file's reader, making a
broken ref indistinguishable from a working one by inspection alone. This is exactly the
"RESOLVING vs. dangling" distinction the task asks the harness to detect: **existence of the
resolved target on disk is the only reliable test** — there is no other signal.

Grepped for literal `@`-references across the full parent chain and both currently-loaded
shape-(a) merge sources (`~/.config/CLAUDE.md`, this repo's `CLAUDE.md`,
`agent-system/extensions/core/merge-sources/claudemd.md`,
`agent-system/extensions/literature/merge-sources/claudemd.md`): **zero matches**. This is
deliberate, not an oversight — `context-layers.md` states generated-CLAUDE.md merge sources "use
plain backticked paths, never `@`-refs" specifically because of the directory-relative trap above.
The harness's `@`-import channel should therefore currently report **0 B / 0 files**, and that is
the correct, expected result to assert in any acceptance check — not evidence the channel logic is
unexercised or broken.

Detection algorithm for the harness (channel is currently empty, but must still be implemented
generally, since a future merge source could add one): for each line in the modeled parent-chain
and generated-CLAUDE.md content, match a `@`-prefixed path token, resolve it relative to the
**containing file's own directory** (not the repo root, not `.claude/`), test `[[ -f ... ]]`,
and only count bytes for a target that exists. Report a separate line for any `@`-ref found that
does NOT resolve (0 bytes contributed, but worth surfacing so a future added ref is visible in the
harness's own report rather than silently inert).

### 3. Rules `paths:` frontmatter channel — the corrected model

`context-layers.md` channel 3 (lines 153-189) confirms the native-harness mechanism
independently of any curated `@`-import list: "A file under `.claude/rules/` with no `paths:` YAML
frontmatter is injected eagerly for every session. A rule with a `paths:` glob is deferred until a
touched or referenced path matches the glob." CLAUDE.md's own "Rules References" section
(root `.claude/CLAUDE.md`, reproduced in this conversation's system context) states the same
independence explicitly: "`.claude/rules/*.md` files are additionally auto-loaded natively by the
Claude Code harness whenever a touched or referenced path matches their own YAML `paths:`
frontmatter glob — a mechanism completely independent of this `@`-import list."

**Current frontmatter census** (read directly from every source-store rule file,
`agent-system/extensions/*/rules/*.md`, `paths:` line only):

| Extension | Rule file | `paths:` value | Class |
|---|---|---|---|
| core | `no-task-references-in-deliverables.md` | *(absent)* | always-eager (omission) |
| core | `source-store-deploy-boundary.md` | *(absent)* | always-eager (omission) |
| core | `pr-prohibition.md` | `"**/*"` | always-eager (universal glob) |
| core | `artifact-formats.md` | `specs/**/*` | matches `specs/**` |
| core | `state-management.md` | `specs/**/*` | matches `specs/**` |
| core | `git-workflow.md` | `["specs/**/*", ".claude/**/*"]` | matches `specs/**` OR `.claude/**` |
| core | `error-handling.md` | `.claude/**/*` | matches `.claude/**` only |
| core | `workflows.md` | `.claude/**/*` | matches `.claude/**` only |
| core | `plan-format-enforcement.md` | `specs/**/plans/**` | narrow (only plan-file touches) |
| core | `project-overview-detection.md` | `.claude/context/repo/project-overview.md` | narrow (single file) |
| cslib | `cslib-lint-fix.md`, `cslib.md` | `"**/*.lean"` | narrow, extension-gated |
| lean | `lean4.md`, `plan-compliance.md` | `"**/*.lean"` | narrow, extension-gated |
| latex | `latex.md` | `"**/*.tex"` | narrow, extension-gated |
| nix | `nix.md` | `["**/*.nix"]` | narrow, extension-gated |
| nvim | `neovim-lua.md` | `["lua/**/*.lua", "after/**/*.lua", "*.lua"]` | narrow, extension-gated |
| web | `web-astro.md` | `["src/**/*.astro", ...]` | narrow, extension-gated |

**This is the exact correction the harness must implement**, recorded verbatim in
`specs/archive/054_split_eager_rules_budget/baseline-bytes.md` under
"### Eager-Context Measurement-Harness Correction" and addressed explicitly to this task:

> "Handed over verbatim for the eager-context measurement-harness task: its stated model (rules
> lacking `paths:` frontmatter or carrying `paths: '**/*'`) catches only 8,863 B of the (pre-task)
> measured 30,518 B, missing `git-workflow.md`, `artifact-formats.md`, and `state-management.md`
> (21,655 B combined, ~71% under-count) because those are gated on `specs/**/*` / `.claude/**/*`
> globs that DO match a real session's touched paths. The harness must glob-MATCH each rule's
> `paths:` value against a representative touched-path set (at minimum `specs/**` and
> `.claude/**`), not merely check for absent-or-universal frontmatter."

**A subtlety the implementer must resolve explicitly, not silently**: applying "at minimum
`specs/**` and `.claude/**`" literally would ALSO catch `error-handling.md` and `workflows.md`
(both gated on `.claude/**/*` alone), which the prior task's own "six-rule" historical baseline
did *not* include (its own header comment describes the six as "loaded unconditionally on any
`specs/**`**-touching** session" — i.e. it used `specs/**` alone as the representative set, not
`.claude/**`). The correction note's "at minimum" phrasing is a forward-looking widening of the
representative set, not a restatement of the historical six. **Recommendation**: the harness
should not hardcode either the six-file list or a single implicit touched-path set. It should
accept/document an explicit representative-path-set parameter (defaulting to `specs/**,.claude/**`
per the correction's literal "at minimum" wording) and glob-match every rule's `paths:` value
against it via bash `[[ path == pattern ]]` glob matching (after normalizing a JSON-array
`paths:` value to its member globs), reporting each matched rule individually so a reader can see
*why* a given rule counted as eager rather than trusting a hardcoded list. Doing so means the
harness's own output will differ from (specifically: exceed) `measure-eager-surface.sh`'s
hardcoded six-rule figure by `error-handling.md` + `workflows.md`'s combined bytes — this is a
correct divergence to state plainly in the harness's own header comment, not a bug to reconcile
away.

Extension-gated rules (cslib, lean, latex, nix, nvim, web) are keyed to file-content-type globs
(`*.lean`, `*.tex`, `*.nix`, `*.lua`, `*.astro`/`*.ts`/`*.tsx`) that a `specs/**`/`.claude/**`
representative touched-path set will never match — correctly excluded from the eager total by the
same glob-match logic, with no special-casing needed.

### 4. `generate-context-line-counts.sh` conventions to mirror

Read in full (`agent-system/extensions/core/scripts/generate-context-line-counts.sh`, 223 lines).
The contract to replicate:

- **Argument parsing**: `MODE="check"` default; `--write` sets write mode; `--check` or no
  argument is explicit check mode; anything else prints a `Usage:` line to stderr and exits 2.
- **Root resolution**: `[[ -n "${REPO_ROOT:-}" ]] || . "$(dirname "${BASH_SOURCE[0]}")/deploy-root-guard.sh" || exit 1`
  immediately, then `REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"`
  — the same "REPO_ROOT-bypass" pattern documented in `regeneration-is-manual-only.md`'s
  "Root-Resolution Guard for Core Scripts" section, required so a deliberate source-store
  invocation (`REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh`)
  works without tripping the guard, exactly as this script's own header comment (lines 45-49)
  documents for itself.
- **`--check` output**: per-item info/fail lines, then a `=== Summary (check mode) ===` block with
  named totals, ending `CHECK FAILED: ...` (exit 1) or `CHECK PASSED: ...` (exit 0).
- **`--write` output**: same per-item lines, a `changed` count added to the summary, ending exit 0
  unless an unfixable problem (missing source file) remains, in which case exit 1.
- Every numeric total is tracked as a named bash accumulator variable and printed in the final
  summary block — no JSON is emitted by `generate-context-line-counts.sh` itself; it is a plain
  stdout report tool with `--write` as its only side-effecting mode (writing corrected values back
  into the same `index-entries.json` sources it read, never a separate baseline snapshot file).

**Divergence from this precedent that the task explicitly requires**: `generate-context-line-counts.sh`'s
`--write` mode corrects data *in place*; this task instead asks for `--write` to "record a baseline
snapshot for later drift comparison" — i.e. `--write` writes a **new** JSON artifact (a snapshot),
not an in-place correction of the measured files themselves (there is nothing to "correct" in rule
byte counts — they are what they are; the drift-comparison need is what changes). This is closer
in *behavior* to `measure-eager-surface.sh`'s `--baseline <path>`/`--compare <path>` pair (which
already writes a timestamped JSON snapshot and prints a before/after delta table), but the task
explicitly asks for `--check`/`--write` **naming**, matching `generate-context-line-counts.sh`'s
flag vocabulary rather than `measure-eager-surface.sh`'s. Recommendation: adopt
`generate-context-line-counts.sh`'s flag names and exit-code contract (`--check` default,
reports+exits nonzero if any volatile-file violation is flagged; `--write` performs the same
measurement and additionally writes a snapshot JSON, analogous in **content shape** to
`measure-eager-surface.sh`'s `write_json()` — per-source `{label, path, bytes, tokens_est}` array
plus a total — but reachable via the `--check`/`--write` flag vocabulary this task specifies, not
`--baseline`/`--compare`). A `--compare <path>` third mode mirroring `measure-eager-surface.sh`'s
delta table is reasonable to add as a bonus (not requested, but is a natural drift-detection UX
extension the sibling script already validates); the two required modes are `--check` and
`--write` as literally specified.

### 5. Provenance of the ~69.9 KB / ~17.5k token baseline (reproducible)

Traced to `specs/archive/054_split_eager_rules_budget/baseline-bytes.md`, "Phase 7: Redeploy,
Re-Measure, and Final Accounting" section. The canonical measurement command (same file, top):

```bash
cat ~/.config/CLAUDE.md ~/.config/nvim/CLAUDE.md .claude/CLAUDE.md \
    .claude/rules/git-workflow.md .claude/rules/artifact-formats.md \
    .claude/rules/state-management.md .claude/rules/pr-prohibition.md \
    .claude/rules/source-store-deploy-boundary.md \
    .claude/rules/no-task-references-in-deliverables.md | wc -c
```

Post-redeploy result table (that file, "Post-redeploy re-measurement"): whole-prefix
**70,160 B**, down from a pre-cut baseline of 80,808 B. `70,160 / 4 = 17,540` tokens — an exact
match to the task description's "~17.5k tokens" figure; "~69.9 KB" is evidently a loose rounding
of the same 70,160 B figure (70,160 B ≈ 68.5 KiB at 1024 B/KiB, or 70.16 KB at 1000 B/KB — neither
convention lands on exactly "69.9", but no other candidate figure anywhere in the repo is close;
this is unambiguously the intended source). Separately, `context-layers.md`'s own channel-3
"Eager budget ceiling" bullet (added by the same task) restates the same figures: six-rule class
total 23,547 B, whole-prefix 70,160 B.

**Reproducibility caveat, directly relevant to this harness's design**: that 70,160 B figure was
measured **against the deployed tree, post-redeploy** — it is the number this task's harness must
be able to *predict without a redeploy having just happened*. The whole reason this new harness
exists is that the deployed tree "routinely lags the source store" (task description), so a
naive `cat .claude/CLAUDE.md .claude/rules/*.md | wc -c` re-run today would silently diverge from
this 70,160 B figure the moment any source-store rule or merge-source edit lands without an
intervening redeploy — exactly the staleness this task is designed to eliminate as a dependency.

**Provenance of "predicted ~9.5k tokens after"**: not found recorded anywhere in the repo as a
citable figure (no report, plan, or context file states a 9.5k-token post-normalization target).
It reads as a stated *target* for a not-yet-scoped future normalization pass, supplied directly in
this task's own description rather than derived from an existing document. Nothing in the codebase
contradicts or corroborates it as a specific number; the report cannot cite a source for it beyond
the task description itself.

## Decisions

- **Do not invoke `deploy-headless.sh` (or any `nvim --headless` call) from `measure-eager-context.sh`.**
  Model the `generate_claudemd()` concatenation algorithm directly in bash against source-store
  files, per Finding 1. This is both the literal instruction ("PREDICTS ... never by measuring the
  live tree") and a hard policy requirement (`regeneration-is-manual-only.md`'s single-sanctioned-caller
  rule, which this new script is not covered by).
- **Read `.claude-extensions.json` at the project root** (not `.claude/`) to determine the active
  extension set and merge order — this file is itself source-of-truth state, not a deployed
  artifact, so reading it does not violate the source-store-only constraint.
- **Do not hardcode the six-rule list or the nine-file list from `measure-eager-surface.sh`.**
  Derive the eager rule set dynamically from every source-store `agent-system/extensions/*/rules/*.md`
  file's `paths:` frontmatter (absent, `"**/*"`, or glob-matching a documented representative
  touched-path set — default `specs/**,.claude/**` per the Finding-3 correction), and state the
  chosen representative-path-set explicitly in output so a reader can audit the classification.
- **Token estimate is `bytes / 4`**, applied per-source and to the grand total, per the task's own
  explicit spec — no tokenizer dependency, matching the existing repo convention of treating
  bytes/4 as the standing token-estimate heuristic (used identically in the task description's own
  "~17.5k tokens" = 70,160/4 derivation).
- **Volatile-file flag, not silent inclusion**: implement as an explicit deny-list check
  (`specs/TODO.md`, `specs/state.json`, `specs/errors.json`, extensible) run against every
  `@`-import target and every merge-source/rule path considered; if any resolves-and-is-volatile,
  emit a loud `FLAG:` line and make it contribute to a nonzero `--check` exit code rather than
  silently counting its bytes into the eager total. Today this class is empty (no `@`-imports
  resolve anywhere in the chain, per Finding 2), so this is a forward-looking guard, not a fix for
  a currently-observed violation.
- **`--check`/`--write` naming and exit-code contract follow `generate-context-line-counts.sh`**
  (Finding 4), with `--write`'s *effect* (write a timestamped snapshot JSON for later drift
  comparison) following `measure-eager-surface.sh`'s `write_json()`/`--baseline` shape instead,
  since that is the behavior this task's description explicitly asks for ("`--write` records a
  baseline snapshot for later drift comparison").
- **`context/architecture/context-layers.md` is a read-only evidentiary source for this task, not
  necessarily an edit target** — the delegation's "Scope files" list includes it, but nothing in
  the task description asks for a *change* to that file; its channel-inventory content (already
  quoted verbatim above) is exactly what the new script's own header-comment documentation should
  cite/restate for a future reader, not modify. Flag this for the planner: if the plan finds no
  concrete edit needed there, note it as "consulted, not modified" rather than force a cosmetic
  change to satisfy a scope-files checklist.

## Risks & Mitigations

- **Risk**: silently reproducing `measure-eager-surface.sh`'s deployed-tree/hardcoded-list
  approach under a new filename, defeating the task's entire purpose. **Mitigation**: Finding 1 and
  Finding 3 give the concrete alternative algorithm (read source-store state + manifests directly;
  glob-match `paths:` dynamically); the plan should cite both by name.
- **Risk**: the "representative touched-path set" choice is inherently a policy decision (which
  paths count as "a real session"), not a fact the codebase states unambiguously — the historical
  six-rule baseline and the correction note's "at minimum" wording actually disagree on whether
  `.claude/**`-only-gated rules count. **Mitigation**: make the set an explicit, documented,
  overridable parameter in the script rather than an unstated assumption; default to the
  correction note's literal `specs/**,.claude/**` and note in the script's own header comment that
  this default is *wider* than (and will therefore report a higher eager total than)
  `measure-eager-surface.sh`'s historical six-rule figure, by design.
- **Risk**: reporting "~9.5k tokens predicted after" as if it were a verified/reproducible number.
  **Mitigation**: Finding 5 confirms this figure has no citable source in the repo; the planner/
  implementer should treat it as an externally-supplied target for a future normalization pass,
  not something the harness itself needs to reproduce or validate — the harness's job is measuring
  the *current* predicted state and flagging drift, not asserting the 9.5k figure is correct.

## Context Extension Recommendations

- **Topic**: utility script inventory completeness. **Gap**:
  `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` (the doc CLAUDE.md
  points to for "standalone scripts not invoked as part of the normal research/plan/implement/postflight
  lifecycle") has no entry for `measure-eager-surface.sh`, even though that script already exists
  and is exactly this kind of standalone reporting tool. **Recommendation**: when
  `measure-eager-context.sh` is implemented, add both it and (if still desired to keep) its
  predecessor to that inventory doc in the same pass, so this gap is not left to a third
  discovery.

## Appendix

- Files read directly: `agent-system/extensions/core/scripts/generate-context-line-counts.sh`,
  `agent-system/extensions/core/scripts/measure-eager-surface.sh`,
  `agent-system/extensions/core/scripts/deploy-headless.sh`,
  `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`,
  `agent-system/extensions/core/context/architecture/context-layers.md`,
  `lua/neotex/plugins/ai/shared/extensions/merge.lua` (lines 760-895),
  `lua/neotex/plugins/ai/shared/extensions/state.lua` (lines 73-96, 227-236),
  `lua/neotex/plugins/ai/claude/extensions/merge.lua`,
  `specs/archive/054_split_eager_rules_budget/baseline-bytes.md` (full file),
  every `agent-system/extensions/*/rules/*.md` frontmatter block, `.claude-extensions.json`,
  every active extension's `manifest.json` `.merge_targets.claudemd` field.
- Grep queries used: `@`-reference search across parent CLAUDE.md / repo CLAUDE.md / both
  shape-(a) merge sources (zero matches, confirming Finding 2); `generate_claudemd` cross-repo
  search to locate the assembly function; `69.9 / 17.5k / 9.5k` search across `specs/**` to locate
  baseline provenance.
